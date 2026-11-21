"""The ONNX Runtime backend.

The first tests need only numpy, pillow and tokenizers. The others need a
model folder in DIMOOSE_ONNX_MODEL (written by export_onnx.py, or a copy of
Xenova/clip-vit-base-patch32); with DIMOOSE_CLIP_WEIGHTS and torch as well,
the ONNX embeddings are compared with the torch ones.
"""
import json, os, sys
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "inst", "python"))
mo = pytest.importorskip("dimoose_onnx")

MODEL = os.environ.get("DIMOOSE_ONNX_MODEL")
WEIGHTS = os.environ.get("DIMOOSE_CLIP_WEIGHTS")
needs_model = pytest.mark.skipif(not MODEL, reason="DIMOOSE_ONNX_MODEL not set")
PICS = os.path.join(os.path.dirname(__file__), "..", "..", "inst", "extdata", "pics")

CFG = {"image_size": 224, "preprocess": {"resize": "shortest", "interpolation": "bicubic", "crop": "center",
                                         "mean": [0.5, 0.5, 0.5], "std": [0.25, 0.25, 0.25]}}


def test_preprocess_resizes_the_short_side_and_cuts_the_middle():
    a = np.zeros((300, 600, 3), dtype=np.uint8)
    a[:, 200:400] = 255                                   # a white band in the middle third
    x = mo.preprocess(Image.fromarray(a), CFG)
    assert x.shape == (3, 224, 224) and x.dtype == np.float32
    # after scaling to 448 x 224 the middle 224 columns are cut: white in the middle, black at the sides
    assert np.allclose(x[:, :, 100:124], (1 - 0.5) / 0.25, atol=1e-3)
    assert np.allclose(x[:, :, :20], (0 - 0.5) / 0.25, atol=1e-3)
    # an image of the right size is only normalised
    g = np.full((224, 224, 3), 127, dtype=np.uint8)
    assert np.allclose(mo.preprocess(Image.fromarray(g), CFG), (127 / 255 - 0.5) / 0.25, atol=1e-6)


def test_tokenize_pads_and_cuts_like_open_clip():
    tokenizers = pytest.importorskip("tokenizers")
    from tokenizers import Tokenizer, models, pre_tokenizers, processors
    vocab = {"<s>": 0, "</s>": 1, "a": 2, "b": 3, "[UNK]": 4}
    t = Tokenizer(models.WordLevel(vocab, unk_token="[UNK]"))
    t.pre_tokenizer = pre_tokenizers.Whitespace()
    t.post_processor = processors.TemplateProcessing(single="<s> $A </s>", special_tokens=[("<s>", 0), ("</s>", 1)])
    ids = mo.tokenize(t, ["a b", "a " * 20, "b &amp;amp; a"], context_length=6, eot_id=1, pad_id=9)
    assert ids.dtype == np.int64 and ids.shape == (3, 6)
    assert ids[0].tolist() == [0, 2, 3, 1, 9, 9]           # padded after the end token
    assert ids[1].tolist() == [0, 2, 2, 2, 2, 1]           # cut, and the end token kept
    assert ids[2].tolist() == [0, 3, 4, 2, 1, 9]           # "&amp;amp;" is unescaped to "&" first


def test_a_transformers_js_folder_is_described_from_its_config_files(tmp_path):
    (tmp_path / "onnx").mkdir()
    for f in ("vision_model.onnx", "vision_model_quantized.onnx", "text_model.onnx"):
        (tmp_path / "onnx" / f).write_bytes(b"x")
    (tmp_path / "tokenizer.json").write_text("{}")
    (tmp_path / "preprocessor_config.json").write_text(json.dumps({
        "crop_size": {"height": 224, "width": 224}, "size": {"shortest_edge": 256}, "resample": 2,
        "image_mean": [0.1, 0.2, 0.3], "image_std": [0.4, 0.5, 0.6], "do_normalize": True}))
    (tmp_path / "config.json").write_text(json.dumps({"projection_dim": 512, "vision_config": {"patch_size": 16}}))
    cfg = mo.read_config(str(tmp_path))
    assert cfg["layout"] == "transformers.js"
    assert cfg["image_size"] == 224 and cfg["patch_grid"] == 14 and cfg["dim"] == 512
    assert cfg["preprocess"]["resize_to"] == 256 and cfg["preprocess"]["interpolation"] == "bilinear"
    assert cfg["preprocess"]["mean"] == [0.1, 0.2, 0.3]
    assert sorted(cfg["image_encoder"]) == ["fp32", "int8"]
    assert cfg["image_encoder"]["int8"]["file"] == "onnx/vision_model_quantized.onnx"
    assert list(cfg["text_encoder"]) == ["fp32"]
    assert cfg["outputs"]["patches"] is None
    with pytest.raises(ValueError, match="no fp16 image encoder"):
        mo._pick(cfg, "image_encoder", "fp16", str(tmp_path))


def test_a_folder_without_a_model_is_refused(tmp_path):
    with pytest.raises(ValueError, match="not an ONNX model folder"):
        mo.load_model(str(tmp_path))


@pytest.fixture(scope="module")
def vm():
    pytest.importorskip("onnxruntime")
    return mo.load_model(MODEL)


@pytest.fixture(scope="module")
def pics():
    import glob
    return sorted(glob.glob(os.path.join(PICS, "*", "*.jpg")))[::6]


@needs_model
def test_spec_and_embeddings(vm, pics):
    assert vm.spec["backend"] == "onnx" and vm.spec["image_size"] >= 224
    assert len(vm.spec["image_mean"].split(",")) == 3
    d = vm.spec["dim"]
    out = mo.embed_images(vm, pics, tiles=[2])
    assert out["image"].shape == (len(pics), d) and out["patches"].shape == (len(pics), 4, d)
    assert np.allclose(np.linalg.norm(out["image"], axis=1), 1, atol=1e-4)
    assert mo.embed_images(vm, pics[:1], patches=False)["patches"] is None
    whole = mo.embed_images(vm, pics[:1], patches=False)["image"]
    top = mo.embed_images(vm, pics[:1], region=(0.0, 0.5, 0.0, 1.0), patches=False)["image"]
    assert not np.allclose(whole, top, atol=1e-3)


@needs_model
def test_patch_tokens_only_from_a_model_that_has_them(vm, pics):
    if vm.cfg["outputs"]["patches"]:
        g = vm.spec["patch_grid"]
        tok = mo.embed_images(vm, pics[:2], tiles=None)["patches"]
        assert tok.shape == (2, g * g, vm.spec["dim"])
        assert np.allclose(np.linalg.norm(tok, axis=2), 1, atol=1e-4)
    else:
        with pytest.raises(ValueError, match="no patch tokens"):
            mo.embed_images(vm, pics[:2], tiles=None)


@needs_model
def test_texts_match_their_photos(vm, pics):
    labels = [os.path.basename(os.path.dirname(p)) for p in pics]
    names = sorted(set(labels))
    t = mo.embed_texts(vm, ["a photo of a %s" % n for n in names])
    assert t.shape == (len(names), vm.spec["dim"])
    assert np.allclose(np.linalg.norm(t, axis=1), 1, atol=1e-4)
    img = mo.embed_images(vm, pics, patches=False)["image"]
    guess = [names[i] for i in (img @ t.T).argmax(1)]
    if "bioclip" not in vm.spec["arch"].lower():           # BioCLIP knows species names, not "banana"
        assert sum(g == l for g, l in zip(guess, labels)) >= len(labels) - 1
    long = mo.embed_texts(vm, ["leaf " * 300])              # longer than the context: cut, not an error
    assert long.shape == (1, vm.spec["dim"])


@needs_model
@pytest.mark.skipif(not WEIGHTS, reason="DIMOOSE_CLIP_WEIGHTS not set")
def test_onnx_embeddings_equal_the_torch_ones(vm, pics):
    """Only meaningful when DIMOOSE_ONNX_MODEL is a copy of the DIMOOSE_CLIP_WEIGHTS model (CLIP ViT-B/32)."""
    pytest.importorskip("torch")
    import dimoose_vision as mv
    ref = mv.load_model(weights=WEIGHTS)
    if ref.spec["dim"] != vm.spec["dim"] or ref.spec["patch_size"] != vm.spec["patch_size"]:
        pytest.skip("the ONNX model is not the model of DIMOOSE_CLIP_WEIGHTS")
    a = mo.embed_images(vm, pics, tiles=[2]); b = mv.embed_images(ref, pics, tiles=[2])
    assert (a["image"] * b["image"]).sum(1).min() > 0.99
    live = np.linalg.norm(b["patches"], axis=2) > 0
    assert ((np.linalg.norm(a["patches"], axis=2) > 0) == live).all()
    assert (a["patches"] * b["patches"]).sum(2)[live].min() > 0.99
    texts = ["a photo of a banana", "a photo of Acer negundo.", "It's a 3-lobed leaf, isn't it?"]
    assert (mo.embed_texts(vm, texts) * mv.embed_texts(ref, texts)).sum(1).min() > 0.99


def test_damaged_files_say_which_file_and_what_to_do(tmp_path):
    # a model folder whose JSON is not JSON
    (tmp_path / "preprocessor_config.json").write_text("<html>Sign in</html>")
    with pytest.raises(ValueError, match=r"preprocessor_config.json is not readable JSON.*delete it and load the model again"):
        mo.read_config(str(tmp_path))
    (tmp_path / "dimoose_onnx.json").write_text("[1, 2]")
    with pytest.raises(ValueError, match="dimoose_onnx.json is not a JSON object"):
        mo.read_config(str(tmp_path))
    (tmp_path / "dimoose_onnx.json").write_text("{}")
    with pytest.raises(ValueError, match="does not describe an ONNX model: it lacks arch"):
        mo.read_config(str(tmp_path))


def _folder(tmp_path, files=()):
    """A transformers.js folder with good JSON and the given (bad) model files."""
    (tmp_path / "onnx").mkdir()
    (tmp_path / "preprocessor_config.json").write_text(json.dumps({"crop_size": 224, "size": 224}))
    (tmp_path / "config.json").write_text(json.dumps({"projection_dim": 512, "vision_config": {"patch_size": 32}}))
    for name, content in files:
        (tmp_path / name).write_bytes(content)
    return str(tmp_path)


def test_a_folder_without_its_image_encoder_says_which_file_is_missing(tmp_path):
    with pytest.raises(ValueError, match=r"has no image encoder: there is no onnx/vision_model"):
        mo.load_model(_folder(tmp_path))
    own = tmp_path / "own"
    own.mkdir()
    (own / "dimoose_onnx.json").write_text(json.dumps({
        "arch": "ViT-B-32", "image_size": 224, "preprocess": {"mean": [0, 0, 0], "std": [1, 1, 1]},
        "image_encoder": {"fp32": {"file": "image_encoder.onnx"}}, "inputs": {"image": "pixel_values"},
        "outputs": {"image": "image_embeds"}}))
    with pytest.raises(ValueError, match=r"lacks its fp32 image encoder, image_encoder.onnx"):
        mo.load_model(str(own))
    with pytest.raises(ValueError, match=r"no int8 image encoder; it has: fp32"):
        mo.load_model(str(own), precision="int8")


def test_a_model_file_cut_short_is_reported_as_damaged(tmp_path):
    pytest.importorskip("onnxruntime")
    folder = _folder(tmp_path, [("onnx/vision_model.onnx", b"\x08\x07" + os.urandom(4000))])
    with pytest.raises(ValueError, match=r"vision_model.onnx is not a readable ONNX model .*4002 bytes.*delete it and load the model again"):
        mo.load_model(folder)


def test_a_damaged_tokenizer_is_reported(tmp_path):
    pytest.importorskip("tokenizers")
    folder = _folder(tmp_path, [("tokenizer.json", b"{not json"), ("onnx/text_model.onnx", b"x")])
    cfg = mo.read_config(folder)
    vm = mo.OnnxModel(folder, cfg, None, os.path.join(folder, "onnx", "text_model.onnx"), spec={"dim": 512})
    with pytest.raises(ValueError, match="tokenizer.json is not a readable tokenizer"):
        mo.embed_texts(vm, ["a leaf"])
    vm.text_file = None
    with pytest.raises(ValueError, match="has no text encoder file"):
        mo.embed_texts(vm, ["a leaf"])


def test_clean_text_repairs_what_open_clip_repairs():
    # the repairs open_clip makes through ftfy, done here without it
    assert mo.clean_text("  ‘curly’ “quotes”  ") == "'curly' \"quotes\""
    assert mo.clean_text("ﬁne oﬃce") == "fine office"
    assert mo.clean_text("ｆｕｌｌ　Ｗ１") == "full W1"
    assert mo.clean_text("bom﻿inside bell\x07 del\x7f") == "bominside bell del"
    assert mo.clean_text("&amp;amp; &lt;b&gt;") == "& <b>"
    assert mo.clean_text("café") == "café"
    assert mo.clean_text("") == "" and mo.clean_text(" \t\n") == ""


def _varied_strings(n=200):
    import random
    rnd = random.Random(7)
    names = ["Acer negundo", "Acer glabrum var. douglasii", "Populus × canadensis", "Populus tremuloides Michx.",
             "Quercus macrocarpa", "Betula papyrifera Marshall", "Carcharodon carcharias (Linnaeus, 1758)",
             "Rosa × damascena 'Kazanlik'", "×Cupressocyparis leylandii", "Bombus (Pyrobombus) bifarius"]
    fixed = ["", " ", "\t\n", ".", "a  b   c", "line one\nline two", "crlf\r\nline", "Bläuling & café: 12 petals",
             "Ærøskøbing smørrebrød", "Żółć gęślą jaźń",
             "Ελληνικά", "Русский лист",
             "日本語の葉", "한국어", "العربية", "ไทย",
             "İstanbul ıspanak", "straße STRASSE", "ﬁne ﬂower oﬃce", "café", "Ångström",
             "ｆｕｌｌ　ｗｉｄｔｈ", "\U0001F34C banana", "a photo of a \U0001F353 strawberry",
             "\U0001F468‍\U0001F469‍\U0001F467 family", "\U0001F1E8\U0001F1E6 flag", "☃ snowman ❄️",
             "it's the 3rd leaf's lobe, isn't it?", "I'm, you're, we've, they'll, he'd", "‘curly’ “quotes” it’s",
             "«guillemets»", "em—dash en–dash", "ellipsis…", "&amp; &lt;b&gt; &quot;x&quot;", "&amp;amp; twice",
             "<b>bold</b> &amp; html", "&eacute;t&eacute;", "AT&T R&D", "12345 67890", "3.14159", "1,000,000", "$5.00 €4 £3",
             "x² + y³", "½ ¼", "25°C", "H₂O", "e-mail@example.org", "https://example.org/a?b=c&d=e#f",
             "snake_case camelCase kebab-case", "[brackets] {braces} (parens)", "~tilde `backtick` ^caret", "*** stars ***", "---",
             "zero​width", "soft­hyphen", "non breaking", "bom﻿inside", "null\x00char", "esc\x1b[31mred\x1b[0m",
             "line separator", "leaf " * 300, "x " * 200, "a" * 500, "日" * 100, "\U0001F34C" * 150, "ALL CAPS", "MiXeD CaSe",
             "one.two", "a , b", "( a )", "'s", "'", "don't", "DON'T", "rock'n'roll", "l'été", "1st 2nd 3rd", "a1b2c3",
             "v2.0.1-beta+build.5", "COVID-19", "e.g. i.e. etc."]
    out = names + ["a photo of %s." % s for s in names] + [s.upper() for s in names] + fixed
    words = names + ["leaf", "bark", "×", "café", "\U0001F343", "3", "it's", "&amp;", "—"]
    while len(out) < n:
        out.append(" ".join(rnd.choice(words) for _ in range(rnd.randint(1, 12))))
    return out[:n]


@needs_model
def test_token_ids_equal_open_clip_on_varied_strings(vm, monkeypatch):
    """200 strings (names, accents, other scripts, emoji, long and empty texts) get open_clip's token ids,
    also where ftfy is not installed, which is how the ONNX backend usually runs."""
    open_clip = pytest.importorskip("open_clip")
    if not vm.cfg.get("tokenizer"):
        pytest.skip("the model has no tokenizer")
    from tokenizers import Tokenizer
    t = Tokenizer.from_file(os.path.join(vm.folder, vm.cfg["tokenizer"]))
    t.no_padding(); t.no_truncation()
    eot = vm.cfg.get("eot_id") or t.token_to_id("<|endoftext|>")
    strings = _varied_strings()
    assert len(strings) == 200
    want = open_clip.get_tokenizer("ViT-B-32")(strings).numpy()
    monkeypatch.setitem(sys.modules, "ftfy", None)          # `import ftfy` now fails, as on a machine without it
    got = mo.tokenize(t, strings, 77, eot_id=eot, pad_id=0)
    differ = [s for s, a, b in zip(strings, want, got) if not np.array_equal(a, b)]
    assert differ == []


@needs_model
def test_no_texts_and_missing_texts(vm):
    if vm.text_file is None:
        pytest.skip("the model has no text encoder")
    assert mo.embed_texts(vm, []).shape == (0, vm.spec["dim"])
    with pytest.raises(ValueError, match="a text is missing"):
        mo.embed_texts(vm, ["a leaf", None])
    assert mo.embed_texts(vm, [""]).shape == (1, vm.spec["dim"])
