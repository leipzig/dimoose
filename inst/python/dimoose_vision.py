"""Embeddings and crops for dimoose vision keys.

Everything that needs a model or pixels lives here; dimoose's R code only ever
sees the numpy arrays these functions return.
"""
import base64
import hashlib
import io
from dataclasses import dataclass, field

import os
import sys

import numpy as np

# When Python runs inside R on Linux, R's reference BLAS is already loaded and
# its symbols would shadow the fast BLAS that torch ships, making the model
# tens of times slower. RTLD_DEEPBIND makes torch prefer its own symbols.
_flags = sys.getdlopenflags() if hasattr(sys, "getdlopenflags") else None
if _flags is not None and sys.platform.startswith("linux") and "torch" not in sys.modules:
    sys.setdlopenflags(_flags | os.RTLD_DEEPBIND)
try:
    import torch
finally:
    if _flags is not None:
        sys.setdlopenflags(_flags)
from PIL import Image

import open_clip


@dataclass
class VisionModel:
    model: object
    preprocess: object
    tokenizer: object
    spec: dict = field(default_factory=dict)


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _is_torchscript(path):
    """OpenAI's original CLIP checkpoints are TorchScript archives."""
    try:
        torch.jit.load(path, map_location="cpu")
        return True
    except Exception:
        return False


def load_model(name="ViT-B-32", pretrained="openai", weights=None, device="cpu"):
    """Load a CLIP-style model through open_clip.

    Three sources:
    - `name` is a model repository, "hf-hub:<org>/<model>" on the Hugging Face
      Hub or "local-dir:<folder>" for a downloaded copy: the repository's own
      configuration and weights are used (this is how BioCLIP loads);
    - `weights` is a local checkpoint: an OpenAI `.pt` file, or an open_clip
      checkpoint for the architecture `name`;
    - otherwise open_clip downloads the `pretrained` weights for `name`.
    """
    repository = name.startswith(("hf-hub:", "local-dir:"))
    if repository:
        model, _, preprocess = open_clip.create_model_and_transforms(name, device=device)
        source = "repository"
    elif weights and _is_torchscript(weights):
        model = open_clip.load_openai_model(weights, device=device)
        preprocess = open_clip.image_transform(model.visual.image_size, is_train=False)
        source = "file"
    elif weights:
        model, _, preprocess = open_clip.create_model_and_transforms(name, pretrained=weights, device=device)
        source = "file"
    else:
        model, _, preprocess = open_clip.create_model_and_transforms(name, pretrained=pretrained, device=device)
        source = pretrained if pretrained else "random"
    visual = model.visual
    if not all(hasattr(visual, a) for a in ("conv1", "ln_post", "proj", "output_tokens")):
        raise ValueError(
            "dimoose needs a model whose image tower is an open_clip vision transformer; "
            "%s has a %s" % (name, type(visual).__name__))
    model.eval()
    model.visual.output_tokens = True
    tokenizer = open_clip.get_tokenizer(name)
    image_size = model.visual.image_size
    if isinstance(image_size, (tuple, list)):
        image_size = image_size[0]
    patch = model.visual.conv1.kernel_size[0]
    spec = {
        "library": "open_clip " + open_clip.__version__,
        "arch": name,
        "pretrained": source,
        "weights_sha256": _sha256(weights) if weights and not repository else None,
        "image_size": int(image_size),
        "patch_size": int(patch),
        "patch_grid": int(image_size // patch),
        "dim": int(model.text_projection.shape[1]) if hasattr(model, "text_projection") else int(model.visual.output_dim),
        "embedding": "patch_tokens(ln_post, proj)",
    }
    return VisionModel(model, preprocess, tokenizer, spec)


def _open(path, region=None):
    img = Image.open(path).convert("RGB")
    if region is not None:
        y0, y1, x0, x1 = [float(v) for v in region]
        w, h = img.size
        img = img.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    return img


def _unit(a, axis=-1):
    return a / (np.linalg.norm(a, axis=axis, keepdims=True) + 1e-8)


def tile_boxes(w, h, tiles):
    """Pixel boxes (x0, y0, x1, y1) of the tiles of a w x h image.

    Each entry g of `tiles` adds a g x g grid of windows that overlap their
    neighbours by half, so a part that straddles one window sits inside the
    next. g = 1 is the whole image.
    """
    boxes = []
    for g in tiles:
        g = int(g)
        sx, sy = w / (g + 1), h / (g + 1)
        for r in range(g):
            for c in range(g):
                boxes.append((int(round(c * sx)), int(round(r * sy)),
                              int(round((c + 2) * sx)), int(round((r + 2) * sy))))
    return boxes


def _background(im, tolerance=24, agree=0.7):
    """The colour of a plain background, or None if the image has none.

    A plain background (a studio backdrop, a white page) shows as one colour
    around most of the image's border.
    """
    a = np.asarray(im, dtype=np.int16)
    ring = np.concatenate([a[:2].reshape(-1, 3), a[-2:].reshape(-1, 3), a[:, :2].reshape(-1, 3), a[:, -2:].reshape(-1, 3)])
    colours, counts = np.unique(ring // 16, axis=0, return_counts=True)
    mode = colours[counts.argmax()] * 16 + 8
    near = (np.abs(ring - mode) <= tolerance).all(axis=1)
    if near.mean() < agree:
        return None
    return ring[near].mean(axis=0)


def embed_images(vm, paths, region=None, patches=True, batch=16, tiles=None, min_detail=8.0, min_fill=0.5):
    """Global and (optionally) local embeddings, unit length, float32.

    Local embeddings are one of two things.

    With `tiles` (a list of grid sizes, see tile_boxes), each tile is cut out
    and embedded on its own, as if it were a whole image. The embedding then
    describes only what is inside the tile. Empty tiles get a zero vector,
    which matches nothing: tiles with almost no detail (greyscale standard
    deviation below `min_detail`) and, in an image with a plain background,
    tiles that are less than `min_fill` subject.

    Without `tiles`, they are the model's own patch tokens (ln_post applied,
    class token dropped, projected with ``visual.proj``), matching fordera's
    patch extraction. In the last layer of a CLIP model these tokens carry
    much of the whole image's content, so they are less local than tiles.
    """
    paths = list(paths)
    visual = vm.model.visual
    tiles = [int(t) for t in tiles] if tiles else None
    images, patch_out = [], []
    with torch.no_grad():
        for start in range(0, len(paths), batch):
            chunk = [_open(p, region) for p in paths[start:start + batch]]
            x = torch.stack([vm.preprocess(im) for im in chunk])
            pooled, tokens = visual(x)
            images.append(_unit(pooled.float().cpu().numpy()))
            if patches and not tiles:
                grid = vm.spec["patch_grid"]
                if tokens.shape[1] != grid * grid:
                    raise ValueError(
                        "expected %d patch tokens but got %d; this open_clip model/version "
                        "returns tokens in a shape dimoose does not handle" % (grid * grid, tokens.shape[1]))
                if visual.proj is not None:
                    tokens = tokens @ visual.proj
                patch_out.append(_unit(tokens.float().cpu().numpy(), axis=2))
            elif patches:
                for im in chunk:
                    crops = [im.crop(box) for box in tile_boxes(im.size[0], im.size[1], tiles)]
                    detail = np.array([np.asarray(c.convert("L"), dtype=np.float32).std() for c in crops])
                    bg = _background(im)
                    fill = np.ones(len(crops)) if bg is None else np.array(
                        [(np.abs(np.asarray(c, dtype=np.int16) - bg) > 24).any(axis=2).mean() for c in crops])
                    emb = []
                    for t0 in range(0, len(crops), 64):
                        pooled_t, _ = visual(torch.stack([vm.preprocess(c) for c in crops[t0:t0 + 64]]))
                        emb.append(_unit(pooled_t.float().cpu().numpy()))
                    emb = np.concatenate(emb)
                    emb[(detail < float(min_detail)) | (fill < float(min_fill))] = 0.0
                    patch_out.append(emb[None])
    return {
        "image": np.concatenate(images).astype(np.float32),
        "patches": np.concatenate(patch_out).astype(np.float32) if patches else None,
    }


def embed_texts(vm, texts):
    texts = list(texts)
    with torch.no_grad():
        t = vm.model.encode_text(vm.tokenizer(texts))
    return _unit(t.float().cpu().numpy()).astype(np.float32)


def patch_box(vm, path, patch_index):
    """Pixel box (x0, y0, x1, y1) in the original image for a 0-based patch index.

    Mirrors open_clip's eval transform: resize the shorter side to image_size,
    then center-crop a square.
    """
    size = vm.spec["image_size"]
    grid = vm.spec["patch_grid"]
    cell = size / grid
    w, h = Image.open(path).size
    scale = size / min(w, h)
    rw, rh = w * scale, h * scale
    offx, offy = (rw - size) / 2, (rh - size) / 2
    row, col = divmod(int(patch_index), grid)
    x0 = (col * cell + offx) / scale
    y0 = (row * cell + offy) / scale
    x1 = ((col + 1) * cell + offx) / scale
    y1 = ((row + 1) * cell + offy) / scale
    r = lambda v: int(round(v))
    return (r(x0), r(y0), r(x1), r(y1))


def crop_png(path, box, pad=48, size=96):
    pad, size = int(pad), int(size)
    img = Image.open(path).convert("RGB")
    w, h = img.size
    x0, y0, x1, y1 = (int(v) for v in box)
    crop = img.crop((max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)))
    crop = crop.resize((size, size), Image.BICUBIC)
    buf = io.BytesIO()
    crop.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def exemplar_pngs(vm, paths, patch_indices, pad=None, size=96, tiles=None):
    """PNG crops (base64) of local regions: tiles as they are, patch tokens
    with `pad` pixels of context (by default half the patch's width)."""
    out = []
    for p, i in zip(paths, patch_indices):
        if tiles:
            w, h = Image.open(p).size
            box, margin = tile_boxes(w, h, tiles)[int(i)], 0 if pad is None else pad
        else:
            box = patch_box(vm, p, int(i))
            margin = (box[2] - box[0]) // 2 if pad is None else pad
        out.append(crop_png(p, box, pad=margin, size=size))
    return out
