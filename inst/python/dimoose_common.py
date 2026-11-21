"""Pixels, tiles and crops shared by dimoose's two vision backends.

Nothing here needs a model library: only numpy and pillow. The torch backend
(dimoose_vision.py) and the ONNX Runtime backend (dimoose_onnx.py) each supply
a `forward` function that turns a list of PIL images into embeddings; the
tiling, the rule for empty tiles and the crops are the same for both.
"""
import base64
import hashlib
import io
import os

import numpy as np
from PIL import Image


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def open_image(path, region=None):
    path = os.path.expanduser(str(path))
    if not os.path.isfile(path):
        raise ValueError("No such image file: %s" % path)
    try:
        img = Image.open(path).convert("RGB")
    except Exception as e:   # not an image, or one cut short
        raise ValueError("%s could not be read as an image (%s)" % (path, e)) from None
    if region is not None:
        y0, y1, x0, x1 = [float(v) for v in region]
        w, h = img.size
        img = img.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    return img


def unit(a, axis=-1):
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


def background(im, tolerance=24, agree=0.7):
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


def embed_images(forward, paths, patch_grid, region=None, patches=True, batch=16, tiles=None, min_detail=8.0, min_fill=0.5):
    """Global and (optionally) local embeddings, unit length, float32.

    `forward(images, tokens)` embeds a list of PIL images: it returns the
    pooled embeddings (n x d) and, if `tokens` is true, the projected patch
    tokens (n x grid^2 x d), otherwise None.

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
    if not paths:
        raise ValueError("there are no images to embed")
    tiles = [int(t) for t in tiles] if tiles else None
    want_tokens = bool(patches) and not tiles
    images, patch_out = [], []
    for start in range(0, len(paths), batch):
        chunk = [open_image(p, region) for p in paths[start:start + batch]]
        pooled, tokens = forward(chunk, want_tokens)
        images.append(unit(np.asarray(pooled, dtype=np.float32)))
        if want_tokens:
            if tokens.shape[1] != patch_grid * patch_grid:
                raise ValueError(
                    "expected %d patch tokens but got %d; this model/version "
                    "returns tokens in a shape dimoose does not handle" % (patch_grid * patch_grid, tokens.shape[1]))
            patch_out.append(unit(np.asarray(tokens, dtype=np.float32), axis=2))
        elif patches:
            for im in chunk:
                crops = [im.crop(box) for box in tile_boxes(im.size[0], im.size[1], tiles)]
                detail = np.array([np.asarray(c.convert("L"), dtype=np.float32).std() for c in crops])
                bg = background(im)
                fill = np.ones(len(crops)) if bg is None else np.array(
                    [(np.abs(np.asarray(c, dtype=np.int16) - bg) > 24).any(axis=2).mean() for c in crops])
                emb = []
                for t0 in range(0, len(crops), 64):
                    pooled_t, _ = forward(crops[t0:t0 + 64], False)
                    emb.append(unit(np.asarray(pooled_t, dtype=np.float32)))
                emb = np.concatenate(emb)
                emb[(detail < float(min_detail)) | (fill < float(min_fill))] = 0.0
                patch_out.append(emb[None])
    return {
        "image": np.concatenate(images).astype(np.float32),
        "patches": np.concatenate(patch_out).astype(np.float32) if patches else None,
    }


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
