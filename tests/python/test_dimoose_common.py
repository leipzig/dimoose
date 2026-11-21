"""The parts of the vision code that need no model: tiles, backgrounds, crops."""
import base64, io, os, sys
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "inst", "python"))
import dimoose_common as mc


def test_tile_boxes_overlap_by_half_and_cover_the_image():
    boxes = mc.tile_boxes(300, 200, [2])
    assert boxes == [(0, 0, 200, 133), (100, 0, 300, 133), (0, 67, 200, 200), (100, 67, 300, 200)]
    assert mc.tile_boxes(100, 100, [1]) == [(0, 0, 100, 100)]
    assert len(mc.tile_boxes(640, 480, [2, 4])) == 20


def test_background_is_the_border_colour_or_none():
    a = np.full((80, 80, 3), 240, dtype=np.uint8)
    a[20:60, 20:60] = (200, 30, 30)
    assert np.allclose(mc.background(Image.fromarray(a)), 240)
    noisy = np.random.default_rng(0).integers(0, 255, (80, 80, 3), dtype=np.uint8)
    assert mc.background(Image.fromarray(noisy)) is None


def test_embed_images_with_a_stand_in_model(tmp_path):
    """Tiles are embedded one by one, empty ones are zero, vectors have unit length."""
    a = np.full((120, 120, 3), 255, dtype=np.uint8)
    a[:60, :60] = np.random.default_rng(1).integers(0, 255, (60, 60, 3), dtype=np.uint8)
    p = str(tmp_path / "a.png"); Image.fromarray(a).save(p)
    calls = []

    def forward(images, tokens):
        calls.append((len(images), tokens))
        pooled = np.stack([np.asarray(im.resize((2, 2)), dtype=np.float32).reshape(-1)[:4] + 1 for im in images])
        return pooled, (np.ones((len(images), 9, 4), dtype=np.float32) if tokens else None)

    out = mc.embed_images(forward, [p, p], 3, tiles=[2])
    assert out["image"].shape == (2, 4) and out["patches"].shape == (2, 4, 4)
    norms = np.linalg.norm(out["patches"], axis=2)
    assert norms[0, 3] == 0                      # the bottom-right tile is plain white
    assert abs(norms[0, 0] - 1) < 1e-5
    assert np.allclose(np.linalg.norm(out["image"], axis=1), 1, atol=1e-5)
    tok = mc.embed_images(forward, [p], 3, tiles=None)
    assert tok["patches"].shape == (1, 9, 4)
    assert mc.embed_images(forward, [p], 3, patches=False)["patches"] is None
    try:
        mc.embed_images(forward, [p], 4, tiles=None)
        assert False, "a wrong number of patch tokens must be refused"
    except ValueError as e:
        assert "expected 16 patch tokens" in str(e)


def test_crop_png(tmp_path):
    p = str(tmp_path / "a.png"); Image.new("RGB", (100, 80), (10, 200, 30)).save(p)
    img = Image.open(io.BytesIO(base64.b64decode(mc.crop_png(p, (10, 10, 40, 40), pad=5, size=32))))
    assert img.size == (32, 32)


def test_a_missing_or_unreadable_image_is_named(tmp_path):
    with pytest.raises(ValueError, match="No such image file: .*nothing.jpg"):
        mc.open_image(str(tmp_path / "nothing.jpg"))
    bad = tmp_path / "bad.jpg"
    bad.write_text("this is not a picture")
    with pytest.raises(ValueError, match="bad.jpg could not be read as an image"):
        mc.open_image(str(bad))
    with pytest.raises(ValueError, match="No such image file"):
        mc.open_image(str(tmp_path))                       # a folder


def test_no_images_is_an_error_in_plain_words():
    with pytest.raises(ValueError, match="no images to embed"):
        mc.embed_images(lambda images, tokens: (None, None), [], 7)
