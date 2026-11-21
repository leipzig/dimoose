"""dimoose's vision backend on ONNX Runtime: no torch.

Offers the same functions as dimoose_vision.py (load_model, embed_images,
embed_texts, patch_box, crop_png, exemplar_pngs), so dimoose's R code uses
either. It needs onnxruntime, numpy, pillow and tokenizers.

A model is a folder in one of two layouts:

- dimoose's own, written by export_onnx.py: `dimoose_onnx.json`,
  `image_encoder[_fp16|_int8].onnx`, `text_encoder[_fp16|_int8].onnx` and
  `tokenizer.json`;
- the transformers.js layout used by ready-made exports on the Hugging Face
  Hub such as Xenova/clip-vit-base-patch32: `config.json`,
  `preprocessor_config.json`, `tokenizer.json`,
  `onnx/vision_model[_fp16|_quantized].onnx` and
  `onnx/text_model[_fp16|_quantized].onnx`.
"""
import html
import json
import os
import re
import unicodedata
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

import dimoose_common as _common
from dimoose_common import tile_boxes, patch_box, crop_png, exemplar_pngs  # noqa: F401

CONFIG = "dimoose_onnx.json"
# file name endings of the three precisions in the transformers.js layout
HUB_SUFFIX = {"fp32": "", "fp16": "_fp16", "int8": "_quantized"}
RESAMPLE = {"nearest": Image.NEAREST, "bilinear": Image.BILINEAR, "bicubic": Image.BICUBIC, "lanczos": Image.LANCZOS}
PIL_RESAMPLE = {0: "nearest", 1: "lanczos", 2: "bilinear", 3: "bicubic"}   # the codes in preprocessor_config.json


@dataclass
class OnnxModel:
    folder: str
    cfg: dict
    image_file: str
    text_file: object
    spec: dict = field(default_factory=dict)
    threads: int = 0
    _image: object = None
    _text: object = None
    _tokenizer: object = None


DAMAGED = ("The file is damaged, most likely a download or a copy that stopped early: delete it and load the model "
           "again (a file from the Hugging Face Hub is then fetched afresh; one written by exportOnnxModel() has to be "
           "written again).")


def _read_json(path):
    """A model folder's JSON file, or an error that names the file and says what to do."""
    try:
        with open(path, encoding="utf-8") as f:
            value = json.load(f)
    except (ValueError, UnicodeDecodeError) as e:
        raise ValueError("%s is not readable JSON (%s). %s" % (path, e, DAMAGED)) from None
    if not isinstance(value, dict):
        raise ValueError("%s is not a JSON object. %s" % (path, DAMAGED))
    return value


def read_config(folder):
    """The model folder's description, in the form export_onnx.py writes it."""
    path = os.path.join(folder, CONFIG)
    if os.path.exists(path):
        cfg = _read_json(path)
        lacking = [k for k in ("arch", "image_size", "preprocess", "image_encoder", "inputs", "outputs") if not cfg.get(k)]
        if lacking:
            raise ValueError("%s does not describe an ONNX model: it lacks %s. Write the folder again with "
                             "exportOnnxModel(), or copy all of it again." % (path, ", ".join(lacking)))
        cfg["layout"] = "dimoose"
        return cfg
    pre = os.path.join(folder, "preprocessor_config.json")
    if not os.path.exists(pre):
        raise ValueError(
            "%s is not an ONNX model folder: it has neither %s (written by dimoose's export_onnx.py) "
            "nor preprocessor_config.json (the transformers.js layout)" % (folder, CONFIG))
    p = _read_json(pre)
    hf = {}
    if os.path.exists(os.path.join(folder, "config.json")):
        hf = _read_json(os.path.join(folder, "config.json"))

    def edge(v, default):
        if isinstance(v, dict):
            v = v.get("shortest_edge", v.get("height", default))
        return int(v if v is not None else default)

    crop = edge(p.get("crop_size"), 224) if p.get("do_center_crop", True) else edge(p.get("size"), 224)
    vision = hf.get("vision_config", {})
    patch = vision.get("patch_size")
    normalise = p.get("do_normalize", True)
    files = lambda stem: {k: {"file": "onnx/%s%s.onnx" % (stem, s)} for k, s in HUB_SUFFIX.items()
                          if os.path.exists(os.path.join(folder, "onnx", "%s%s.onnx" % (stem, s)))}
    return {
        "layout": "transformers.js",
        "arch": hf.get("_name_or_path") or os.path.basename(os.path.normpath(folder)),
        "pretrained": "repository",
        "image_size": crop,
        "patch_size": int(patch) if patch else None,
        "patch_grid": int(crop // patch) if patch else None,
        "dim": hf.get("projection_dim"),
        "context_length": int(hf.get("text_config", {}).get("max_position_embeddings", 77)),
        "logit_scale": 100.0,
        "preprocess": {
            "resize": "shortest" if p.get("do_resize", True) else "none",
            "resize_to": edge(p.get("size"), crop),
            "interpolation": PIL_RESAMPLE.get(p.get("resample", 3), "bicubic"),
            "crop": "center" if p.get("do_center_crop", True) else "none",
            "rescale": p.get("rescale_factor", 1 / 255),
            "mean": p.get("image_mean", [0, 0, 0]) if normalise else [0.0, 0.0, 0.0],
            "std": p.get("image_std", [1, 1, 1]) if normalise else [1.0, 1.0, 1.0],
        },
        "image_encoder": files("vision_model"),
        "text_encoder": files("text_model"),
        "inputs": {"image": "pixel_values", "text": "input_ids"},
        "outputs": {"image": "image_embeds", "patches": None, "text": "text_embeds"},
        "tokenizer": "tokenizer.json" if os.path.exists(os.path.join(folder, "tokenizer.json")) else None,
        "eot_id": None,
        "pad_id": None,
    }


def _pick(cfg, which, precision, folder):
    have = cfg.get(which) or {}
    if precision not in have:
        if not have:
            return None
        raise ValueError("%s has no %s %s; it has: %s" % (folder, precision, which.replace("_", " "), ", ".join(sorted(have))))
    return os.path.join(folder, have[precision]["file"])


def load_model(folder, precision="fp32", text_precision=None, threads=0):
    """Open a model folder. `precision` is "fp32", "fp16" or "int8" and picks
    the image encoder file; `text_precision` (default: the same) the text
    encoder. The text encoder and tokenizer are only read when texts are embedded.
    """
    folder = os.path.abspath(os.path.expanduser(folder))
    cfg = read_config(folder)
    image_file = _pick(cfg, "image_encoder", precision, folder)
    if image_file is None:
        raise ValueError("%s has no image encoder: there is no onnx/vision_model*.onnx file in it. Copy the whole "
                         "model folder again, or give the model's name so that it is downloaded." % folder)
    if not os.path.exists(image_file):
        raise ValueError("%s lacks its %s image encoder, %s. Copy the whole model folder again, or write it again "
                         "with exportOnnxModel()." % (folder, precision, os.path.relpath(image_file, folder)))
    text_file = _pick(cfg, "text_encoder", text_precision or precision, folder)
    vm = OnnxModel(folder, cfg, image_file, text_file, threads=int(threads or 0))
    sess = _image_session(vm)
    dim = cfg.get("dim") or sess.get_outputs()[0].shape[-1]
    import onnxruntime as ort
    vm.spec = {
        "library": "onnxruntime " + ort.__version__,
        "arch": cfg["arch"],
        "pretrained": cfg.get("pretrained"),
        "weights_sha256": cfg.get("weights_sha256"),
        "image_size": int(cfg["image_size"]),
        "patch_size": cfg.get("patch_size"),
        "patch_grid": cfg.get("patch_grid"),
        "dim": int(dim),
        "embedding": "patch_tokens(ln_post, proj)" if cfg["outputs"].get("patches") else "pooled only",
        "backend": "onnx",
        "precision": precision,
        "text_precision": (text_precision or precision) if text_file else None,
        "layout": cfg["layout"],
        # how images are prepared; as text, since every spec entry is one value
        "image_mean": ",".join("%.8g" % float(v) for v in cfg["preprocess"]["mean"]),
        "image_std": ",".join("%.8g" % float(v) for v in cfg["preprocess"]["std"]),
        "image_resize": cfg["preprocess"].get("resize", "shortest"),
        "image_resize_to": int(cfg["preprocess"].get("resize_to", cfg["image_size"])),
        "image_interpolation": cfg["preprocess"].get("interpolation", "bicubic"),
        "image_crop": cfg["preprocess"].get("crop", "center"),
    }
    return vm


def _session(path, threads=0):
    import onnxruntime as ort
    opts = ort.SessionOptions()
    if threads:
        opts.intra_op_num_threads = int(threads)
    opts.log_severity_level = 3
    try:
        return ort.InferenceSession(path, sess_options=opts, providers=["CPUExecutionProvider"])
    except Exception as e:
        reason = str(e).split(" : ")[-1].strip()
        raise ValueError("%s is not a readable ONNX model (%s; the file has %d bytes). %s"
                         % (path, reason, os.path.getsize(path), DAMAGED)) from None


def _image_session(vm):
    if vm._image is None:
        vm._image = _session(vm.image_file, vm.threads)
        names = [o.name for o in vm._image.get_outputs()]
        if vm.cfg["outputs"]["image"] not in names:
            raise ValueError("the image encoder %s has no output named %s (it has %s)"
                             % (vm.image_file, vm.cfg["outputs"]["image"], ", ".join(names)))
        if vm.cfg["outputs"].get("patches") not in names:
            vm.cfg["outputs"]["patches"] = None
    return vm._image


def preprocess(im, cfg):
    """One PIL image as a float32 array [3, S, S], the way open_clip and
    transformers prepare images for a CLIP model: scale the shorter side to
    the model's size, cut the middle square, scale to 0..1, normalise."""
    p = cfg["preprocess"]
    size = int(cfg["image_size"])
    im = im.convert("RGB")
    w, h = im.size
    if p.get("resize", "shortest") == "shortest":
        to = int(p.get("resize_to", size))
        if w <= h:
            nw, nh = to, int(to * h / w)
        else:
            nw, nh = int(to * w / h), to
        if (nw, nh) != (w, h):
            im = im.resize((nw, nh), RESAMPLE[p.get("interpolation", "bicubic")])
        w, h = nw, nh
    if p.get("crop", "center") == "center":
        left, top = int(round((w - size) / 2.0)), int(round((h - size) / 2.0))
        im = im.crop((left, top, left + size, top + size))
    elif im.size != (size, size):
        im = im.resize((size, size), RESAMPLE[p.get("interpolation", "bicubic")])
    a = np.asarray(im, dtype=np.float32) * np.float32(p.get("rescale", 1 / 255))
    a = (a - np.asarray(p["mean"], dtype=np.float32)) / np.asarray(p["std"], dtype=np.float32)
    return np.ascontiguousarray(a.transpose(2, 0, 1))


def _forward(vm):
    sess = _image_session(vm)
    out = vm.cfg["outputs"]
    name = vm.cfg["inputs"]["image"]

    def forward(images, tokens):
        x = np.stack([preprocess(im, vm.cfg) for im in images])
        if tokens:
            if not out.get("patches"):
                raise ValueError(
                    "this ONNX model gives one embedding per image and no patch tokens, so `tiles = 0` "
                    "cannot be used with it; use tiles (the default), or a model written by dimoose's export_onnx.py")
            pooled, tok = sess.run([out["image"], out["patches"]], {name: x})
            return pooled, tok
        return sess.run([out["image"]], {name: x})[0], None
    return forward


def embed_images(vm, paths, region=None, patches=True, batch=16, tiles=None, min_detail=8.0, min_fill=0.5):
    """Global and (optionally) local embeddings, unit length, float32; see
    dimoose_common.embed_images."""
    return _common.embed_images(_forward(vm), paths, vm.spec.get("patch_grid") or 0, region=region, patches=patches,
                                batch=batch, tiles=tiles, min_detail=min_detail, min_fill=min_fill)


# What open_clip's tokenizer repairs in a text before it splits it, through
# the ftfy package (ftfy.fix_text): the same tables, so that a text gives the
# same token ids here, where ftfy is not installed.
_LIGATURES = {ord(a): b for a, b in [
    ("\u0132", "IJ"), ("\u0133", "ij"), ("\u0149", "\u02bcn"), ("\u01f1", "DZ"), ("\u01f2", "Dz"), ("\u01f3", "dz"),
    ("\u01c4", "D\u017d"), ("\u01c5", "D\u017e"), ("\u01c6", "d\u017e"), ("\u01c7", "LJ"), ("\u01c8", "Lj"),
    ("\u01c9", "lj"), ("\u01ca", "NJ"), ("\u01cb", "Nj"), ("\u01cc", "nj"), ("\ufb00", "ff"), ("\ufb01", "fi"),
    ("\ufb02", "fl"), ("\ufb03", "ffi"), ("\ufb04", "ffl"), ("\ufb05", "\u017ft"), ("\ufb06", "st")]}
_WIDTH = {0x3000: " "}
_WIDTH.update({i: unicodedata.normalize("NFKC", chr(i)) for i in range(0xFF01, 0xFFF0)
               if unicodedata.normalize("NFKC", chr(i)) != chr(i)})
_CONTROL = {i: None for i in list(range(0x00, 0x09)) + [0x0B] + list(range(0x0E, 0x20)) + [0x7F]
            + list(range(0x206A, 0x2070)) + [0xFEFF] + list(range(0xFFF9, 0xFFFD))}
_C1 = {}
for _i in range(0x80, 0xA0):
    try:
        _C1[_i] = bytes([_i]).decode("windows-1252")
    except UnicodeDecodeError:
        pass
_ANSI = re.compile("\033\\[((?:\\d|;)*)([a-zA-Z])")
_SINGLE_QUOTE = re.compile("[\u02bc\u2018-\u201b]")
_DOUBLE_QUOTE = re.compile("[\u201c-\u201f]")
_SURROGATE = re.compile("[\ud800-\udfff]")


def clean_text(text):
    """A text as open_clip's tokenizer cleans it before splitting it.

    open_clip passes every text through ftfy.fix_text(), then unescapes HTML
    entities twice and trims it. ftfy is not among this backend's packages, so
    its repairs are done here: curly quotes become straight ones, Latin
    ligatures and full-width letters ordinary letters, control characters and
    the byte order mark go, line breaks become "\\n". With these a text gets
    the token ids open_clip gives it. The one repair left out is ftfy's
    guessing at text decoded in the wrong encoding ("cafÃ©" for "café"); if
    ftfy is installed it is used, and then that is repaired too.
    """
    text = str(text)
    try:
        import ftfy
        text = ftfy.fix_text(text)
    except ImportError:
        if "<" not in text:           # ftfy leaves entities alone in what looks like HTML
            text = html.unescape(text)
        text = _ANSI.sub("", text)
        text = text.translate(_C1).translate(_LIGATURES).translate(_WIDTH)
        text = _DOUBLE_QUOTE.sub('"', _SINGLE_QUOTE.sub("'", text))
        for a in ("\r\n", "\r", "\u2028", "\u2029", "\u0085"):
            text = text.replace(a, "\n")
        text = _SURROGATE.sub("\ufffd", text).translate(_CONTROL)
        text = unicodedata.normalize("NFC", text)
    return html.unescape(html.unescape(text)).strip()


def tokenize(tokenizer, texts, context_length=77, eot_id=None, pad_id=0):
    """Token ids [n, context_length] int64 as open_clip makes them: the text
    cleaned (see clean_text), start and end tokens added, long texts cut
    (keeping the end token), short ones padded."""
    out = np.full((len(texts), context_length), pad_id, dtype=np.int64)
    for i, text in enumerate(texts):
        ids = tokenizer.encode(clean_text(text)).ids
        if len(ids) > context_length:
            ids = ids[:context_length]
            if eot_id is not None:
                ids[-1] = eot_id
        out[i, :len(ids)] = ids
    return out


def _text_parts(vm):
    if vm.text_file is None or not os.path.exists(vm.text_file):
        raise ValueError("%s has no text encoder file, so texts cannot be embedded with it (a model loaded with "
                         "text = FALSE has to be loaded again without it)" % vm.folder)
    if not vm.cfg.get("tokenizer"):
        raise ValueError("%s has no tokenizer.json, so texts cannot be embedded with it" % vm.folder)
    if vm._text is None:
        from tokenizers import Tokenizer
        tok = os.path.join(vm.folder, vm.cfg["tokenizer"])
        if not os.path.exists(tok):
            raise ValueError("%s has no %s, so texts cannot be embedded with it" % (vm.folder, vm.cfg["tokenizer"]))
        try:
            vm._tokenizer = Tokenizer.from_file(tok)
        except Exception as e:
            raise ValueError("%s is not a readable tokenizer (%s). %s" % (tok, e, DAMAGED)) from None
        vm._tokenizer.no_padding()
        vm._tokenizer.no_truncation()
        vm._text = _session(vm.text_file, vm.threads)
    return vm._text, vm._tokenizer


def embed_texts(vm, texts, batch=64):
    texts = list(texts)
    if any(t is None for t in texts):
        raise ValueError("a text is missing (None); every text must be a string")
    sess, tokenizer = _text_parts(vm)
    if not texts:
        return np.zeros((0, int(vm.spec["dim"])), dtype=np.float32)
    cfg = vm.cfg
    eot = cfg.get("eot_id")
    if eot is None:   # CLIP's end token has the largest id of the vocabulary's own tokens
        eot = tokenizer.token_to_id("<|endoftext|>")
    # open_clip pads with 0. CLIP's own text encoder ignores what follows the
    # end token, but others (MobileCLIP) read the padding, so it must be 0.
    pad = cfg.get("pad_id") or 0
    wanted = [i.name for i in sess.get_inputs()]
    out = []
    for start in range(0, len(texts), batch):
        ids = tokenize(tokenizer, texts[start:start + batch], int(cfg.get("context_length", 77)), eot_id=eot, pad_id=pad)
        feed = {cfg["inputs"]["text"]: ids}
        if "attention_mask" in wanted:
            mask = np.zeros_like(ids)
            for r, row in enumerate(ids):
                mask[r, :int(np.argmax(row == eot)) + 1 if (row == eot).any() else len(row)] = 1
            feed["attention_mask"] = mask
        out.append(sess.run([cfg["outputs"]["text"]], feed)[0])
    return _common.unit(np.concatenate(out).astype(np.float32)).astype(np.float32)
