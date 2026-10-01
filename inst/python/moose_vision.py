"""Embeddings and crops for moose vision keys.

Everything that needs a model or pixels lives here; moose's R code only ever
sees the numpy arrays these functions return.
"""
import base64
import hashlib
import io
from dataclasses import dataclass, field

import numpy as np
import torch
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


def load_model(name="ViT-B-32", pretrained="openai", weights=None, device="cpu"):
    """Load a CLIP model through open_clip.

    `weights` is a local checkpoint (an OpenAI `.pt` file works); without it
    open_clip downloads `pretrained` for `name`.
    """
    if weights:
        model = open_clip.load_openai_model(weights, device=device)
        preprocess = open_clip.image_transform(model.visual.image_size, is_train=False)
    else:
        model, _, preprocess = open_clip.create_model_and_transforms(name, pretrained=pretrained, device=device)
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
        "pretrained": pretrained if not weights else "file",
        "weights_sha256": _sha256(weights) if weights else None,
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


def embed_images(vm, paths, region=None, patches=True, batch=16):
    """Global and (optionally) patch embeddings, unit length, float32.

    Patch tokens are open_clip's output tokens (ln_post applied, class token
    dropped), projected with ``visual.proj`` so they share the image space,
    matching fordera's patch extraction.
    """
    paths = list(paths)
    visual = vm.model.visual
    images, patch_out = [], []
    with torch.no_grad():
        for start in range(0, len(paths), batch):
            chunk = paths[start:start + batch]
            x = torch.stack([vm.preprocess(_open(p, region)) for p in chunk])
            pooled, tokens = visual(x)
            images.append(_unit(pooled.float().cpu().numpy()))
            if patches:
                if visual.proj is not None:
                    tokens = tokens @ visual.proj
                patch_out.append(_unit(tokens.float().cpu().numpy(), axis=2))
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


def exemplar_pngs(vm, paths, patch_indices, pad=48, size=96):
    return [crop_png(p, patch_box(vm, p, int(i)), pad=pad, size=size) for p, i in zip(paths, patch_indices)]
