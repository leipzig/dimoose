# Load a vision model that runs on ONNX Runtime, without PyTorch

The light way to embed images and texts: the Python side needs only
`onnxruntime`, `numpy`, `pillow` and `tokenizers` (about 150 MB
installed, against 0.8 GB to several GB for PyTorch, depending on the
platform). The result is used exactly like a
[`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md):
with
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md),
[`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md),
[`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md),
[`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md)
and the rest. `visionModel(backend = "onnx")` calls this function.

## Usage

``` r
onnxModel(
  name = "clip-vit-base-patch32",
  precision = c("fp32", "fp16", "int8"),
  textPrecision = precision,
  text = TRUE,
  cache = onnxCache(),
  python = NULL,
  threads = 0,
  fetch = NULL
)
```

## Arguments

- name:

  The model: a folder, a Hugging Face repository or a known name (see
  below).

- precision:

  `"fp32"`, `"fp16"` or `"int8"`: which copy of the image encoder to
  use.

- textPrecision:

  The same for the text encoder; by default as `precision`.

- text:

  If `FALSE`, the text encoder is not downloaded (about 250 MB less at
  `"fp32"`).
  [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
  then fails; sniglet keys do not need it.

- cache:

  Folder for downloaded models.

- python:

  Optional path to the Python executable to use (passed to
  [`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html)).

- threads:

  Number of CPU threads for ONNX Runtime; `0` lets it choose.

- fetch:

  For tests: a function `(url, dest)` that downloads a file and returns
  `TRUE`, or `FALSE` if there is no such file.

## Value

An object of class `dimooseVisionModel`, as
[`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)
returns, with a `files` entry: the model's folder (`dir`), its image and
text encoder files (`image`, `text`) and, for a model from the Hub, its
repository (`repo`) and the web address of the image encoder
(`imageUrl`).

## Where models come from

`name` is one of

- a folder on your computer that holds an ONNX model (also written
  `"local-dir:<folder>"`), in either layout described below;

- a Hugging Face repository, `"<organisation>/<model>"` or
  `"hf-hub:<organisation>/<model>"`. The files that are needed are
  downloaded once into
  [`onnxCache()`](https://leipzig.github.io/dimoose/reference/onnxCache.md)
  and reused; nothing is downloaded when they are already there;

- `"clip-vit-base-patch32"` (the default; CLIP ViT-B/32, the same
  weights as
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md))
  or `"clip-vit-base-patch16"`: the ready-made exports
  `Xenova/clip-vit-base-patch32` and `Xenova/clip-vit-base-patch16` on
  the Hub;

- `"mobileclip-s0"`: Apple's MobileCLIP-S0 (`Xenova/mobileclip_s0`), a
  small model for phones. Its image encoder is 46 MB at `"fp32"` and 23
  MB at `"fp16"`. Its `"int8"` file is refused: its embeddings are wrong
  (measured: cosine 0.09 on average with the `"fp32"` ones);

- `"bioclip"`, `"bioclip-2"` or any other model you have converted with
  [`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md).
  There is no official ONNX copy of BioCLIP on the Hub, so it has to be
  converted once on a computer with PyTorch; the converted folder can
  then be copied to computers without it.

## Precision and size

Each encoder comes in up to three precisions. Measured on dimoose's 55
example photos against the PyTorch model (CLIP ViT-B/32 image encoder):

|  |  |  |
|----|----|----|
| `precision` | image encoder | cosine with PyTorch (lowest) |
| `"fp32"` | 352 MB | 1.0000 |
| `"fp16"` | 176 MB | 1.0000 |
| `"int8"`, converted by [`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md) | 96 MB | 0.998 |
| `"int8"`, `Xenova/clip-vit-base-patch32` (`_quantized`) | 89 MB | 0.81 |

`"fp16"` halves the download but runs up to three times slower on a CPU
than `"fp32"`. BioCLIP converted by
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md)
is 345, 173 and 89 MB, with cosines of 1.0000, 1.0000 and 0.998 (BioCLIP
2, a larger model, is about 1217, 609 and 310 MB); on the Montana
example photos all three precisions name the same species. A key must be
followed with the model **and precision** it was built with when the
precision is `"int8"`: its embeddings differ slightly from the others'.
The ready-made `"int8"` file of `Xenova/clip-vit-base-patch32` is a much
rougher copy (0.89 on average), so `onnxModel()` warns when it is used;
to get the close one, convert the model yourself with
`exportOnnxModel("ViT-B-32")`. A model you have converted is used in
place of the ready-made copy of the same name.

The patch tokens of an `"int8"` encoder (`embedImages(tiles = 0)`) are
less faithful than its image embeddings: with BioCLIP the lowest cosine
of a token with the `"fp32"` one was 0.86. Use tiles, or a higher
precision, to find sniglets with patch tokens.

## Layouts of a model folder

dimoose's own layout, written by
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md):
`dimoose_onnx.json` (architecture, image size, preprocessing constants,
file names), `image_encoder.onnx`, `text_encoder.onnx`, their `_fp16`
and `_int8` copies, and `tokenizer.json`. Its image encoder also returns
the model's patch tokens, so `embedImages(tiles = 0)` works.

The transformers.js layout of ready-made exports on the Hub:
`config.json`, `preprocessor_config.json`, `tokenizer.json`,
`onnx/vision_model[_fp16|_quantized].onnx` and
`onnx/text_model[_fp16|_quantized].onnx`. These give one embedding per
image and no patch tokens: tiles (the default of
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md))
work, `tiles = 0` does not.

## When something goes wrong

- *Could not download ...*: the model is fetched from huggingface.co the
  first time only. Files that arrived are kept, so calling again
  continues where it stopped. A computer that cannot reach the Hub can
  be given the model's folder, copied from
  [`onnxCache()`](https://leipzig.github.io/dimoose/reference/onnxCache.md)
  on one that can, as `name`.

- *... is not a readable ONNX model*: a model file is damaged, usually a
  download or copy that stopped early. Delete the file named in the
  message and load the model again; a file from the Hub is fetched
  afresh.

- *Could not load dimoose's ONNX code*: the Python in use lacks
  `onnxruntime` or `tokenizers`. The message gives the
  [`reticulate::py_install()`](https://rstudio.github.io/reticulate/reference/py_install.html)
  call that installs them.

## See also

[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md)
to convert a model,
[`exportBrowserModel()`](https://leipzig.github.io/dimoose/reference/exportBrowserModel.md)
to use one in a web page,
[`saveEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md)
to need no Python at all.

## Examples

``` r
if (FALSE) { # \dontrun{
model <- onnxModel()                              # CLIP ViT-B/32, downloaded once
model <- onnxModel(precision = "fp16")            # half the download
images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
emb <- embedImages(model, images)

exportOnnxModel("bioclip")                        # once, needs PyTorch
model <- onnxModel("bioclip")                     # afterwards, without it
} # }
```
