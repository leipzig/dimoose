import os, sys, base64, io
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "inst", "python"))
import dimoose_vision as mv

WEIGHTS = os.environ.get("DIMOOSE_CLIP_WEIGHTS")
pytestmark = pytest.mark.skipif(not WEIGHTS, reason="DIMOOSE_CLIP_WEIGHTS not set")


@pytest.fixture(scope="module")
def vm():
    return mv.load_model(weights=WEIGHTS)


@pytest.fixture(scope="module")
def pics(tmp_path_factory):
    d = tmp_path_factory.mktemp("pics")
    rng = np.random.default_rng(0)
    paths = []
    for i, (w, h) in enumerate([(224, 224), (400, 300), (300, 400)]):
        a = rng.integers(0, 255, (h, w, 3), dtype=np.uint8)
        a[h // 4:h // 2, w // 4:w // 2] = (255, 0, 0)
        p = d / f"p{i}.png"
        Image.fromarray(a).save(p)
        paths.append(str(p))
    return paths


def test_spec(vm):
    assert vm.spec["arch"] == "ViT-B-32"
    assert vm.spec["dim"] == 512
    assert vm.spec["patch_grid"] == 7
    assert vm.spec["weights_sha256"] == "40d365715913c9da98579312b702a82c18be219cc2a73407c4526f58eba950af"


def test_embed_images_shapes_and_norms(vm, pics):
    out = mv.embed_images(vm, pics)
    assert out["image"].shape == (3, 512)
    assert out["patches"].shape == (3, 49, 512)
    assert np.allclose(np.linalg.norm(out["image"], axis=1), 1, atol=1e-4)
    assert np.allclose(np.linalg.norm(out["patches"], axis=2), 1, atol=1e-4)
    assert mv.embed_images(vm, pics, patches=False)["patches"] is None


def test_region_changes_embedding(vm, pics):
    whole = mv.embed_images(vm, pics[:1], patches=False)["image"]
    top = mv.embed_images(vm, pics[:1], region=(0.0, 0.5, 0.0, 1.0), patches=False)["image"]
    assert not np.allclose(whole, top, atol=1e-3)


def test_embed_texts(vm):
    t = mv.embed_texts(vm, ["a red square", "a blue circle"])
    assert t.shape == (2, 512)
    assert np.allclose(np.linalg.norm(t, axis=1), 1, atol=1e-4)
    assert t[0] @ t[1] < 0.99


def test_patch_box_on_a_400x300_image(vm, pics):
    x0, y0, x1, y1 = mv.patch_box(vm, pics[1], 0)
    assert abs(x0 - 50) < 1 and y0 == 0
    assert abs((x1 - x0) - 32 * 300 / 224) < 1
    x0, y0, x1, y1 = mv.patch_box(vm, pics[1], 48)
    assert abs(x1 - 350) < 1 and abs(y1 - 300) < 1
    assert mv.patch_box(vm, pics[0], 8) == (32, 32, 64, 64)


def test_crop_png_and_exemplars(vm, pics):
    b64 = mv.crop_png(pics[0], (32, 32, 64, 64), pad=16, size=48)
    img = Image.open(io.BytesIO(base64.b64decode(b64)))
    assert img.size == (48, 48)
    pngs = mv.exemplar_pngs(vm, [pics[0], pics[1]], [8, 48])
    assert len(pngs) == 2 and all(isinstance(p, str) for p in pngs)
