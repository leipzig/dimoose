"""Embeddings and crops for dimoose vision keys.

Everything that needs a model or pixels lives here; dimoose's R code only ever
sees the numpy arrays these functions return.
"""
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
import open_clip

import dimoose_common as _common
# The parts that need no model are shared with the ONNX backend; they keep
# their names here, where the R code and the tests look for them.
from dimoose_common import (tile_boxes, patch_box, crop_png, exemplar_pngs, sha256 as _sha256,  # noqa: F401
                            open_image as _open, unit as _unit, background as _background)


@dataclass
class VisionModel:
    model: object
    preprocess: object
    tokenizer: object
    spec: dict = field(default_factory=dict)


def _is_torchscript(path):
    """OpenAI's original CLIP checkpoints are TorchScript archives."""
    try:
        torch.jit.load(path, map_location="cpu")
        return True
    except Exception:
        return False


def _quick_gelu(name, pretrained):
    """Whether the `pretrained` weights of the architecture `name` were trained
    with OpenAI's QuickGELU activation.

    OpenAI's own weights were, but open_clip builds "ViT-B-32" and the other
    plain architecture names with the standard GELU and only warns about the
    mismatch. The model then loads and runs, with embeddings that are not
    CLIP's (measured on dimoose's example photos: cosine 0.94 to 0.98 with the
    right ones), so the activation has to be asked for.
    """
    try:
        cfg = open_clip.get_pretrained_cfg(name, pretrained) or {}
    except Exception:
        cfg = {}
    return bool(cfg.get("quick_gelu", False))


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
        model, _, preprocess = open_clip.create_model_and_transforms(
            name, pretrained=pretrained, device=device, force_quick_gelu=_quick_gelu(name, pretrained))
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
    # how images are prepared, so that another runtime (ONNX, a browser) can
    # prepare them the same way; as text, since every spec entry is one value
    norm = [t for t in getattr(preprocess, "transforms", []) if hasattr(t, "mean") and hasattr(t, "std")]
    if norm:
        spec["image_mean"] = ",".join("%.8g" % float(v) for v in norm[0].mean)
        spec["image_std"] = ",".join("%.8g" % float(v) for v in norm[0].std)
    return VisionModel(model, preprocess, tokenizer, spec)


def _forward(vm):
    """The function dimoose_common.embed_images needs: PIL images in, pooled
    embeddings and (optionally) projected patch tokens out, as numpy arrays."""
    visual = vm.model.visual

    def forward(images, tokens):
        with torch.no_grad():
            pooled, tok = visual(torch.stack([vm.preprocess(im) for im in images]))
            if not tokens:
                return pooled.float().cpu().numpy(), None
            if visual.proj is not None and tok.shape[1] == vm.spec["patch_grid"] ** 2:
                tok = tok @ visual.proj
            return pooled.float().cpu().numpy(), tok.float().cpu().numpy()
    return forward


def embed_images(vm, paths, region=None, patches=True, batch=16, tiles=None, min_detail=8.0, min_fill=0.5):
    """Global and (optionally) local embeddings, unit length, float32.

    The local embeddings are tiles (each cut out and embedded as an image of
    its own) or, without `tiles`, the model's projected patch tokens; see
    dimoose_common.embed_images.
    """
    return _common.embed_images(_forward(vm), paths, vm.spec["patch_grid"], region=region, patches=patches,
                                batch=batch, tiles=tiles, min_detail=min_detail, min_fill=min_fill)


def embed_texts(vm, texts):
    texts = list(texts)
    with torch.no_grad():
        t = vm.model.encode_text(vm.tokenizer(texts))
    return _unit(t.float().cpu().numpy()).astype(np.float32)
