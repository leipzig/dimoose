# Convert an open_clip model to ONNX

Runs dimoose's `export_onnx.py` (in the package's `python` folder) to
write a model as ONNX image and text encoders that
[`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md)
runs without PyTorch. The conversion itself needs PyTorch and open_clip,
but only once: the folder it writes can be copied to other computers or
uploaded to a Hugging Face repository and used from there.

## Usage

``` r
exportOnnxModel(
  name = "bioclip",
  pretrained = "openai",
  weights = NULL,
  dir = NULL,
  quantize = c("int8", "fp16"),
  python = NULL,
  run = NULL
)
```

## Arguments

- name:

  The model, as for
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md):
  an open_clip architecture name, `"bioclip"`, `"bioclip-2"`,
  `"hf-hub:<organisation>/<model>"` or `"local-dir:<folder>"`. Only
  models with a vision transformer and open_clip's own CLIP tokenizer
  can be converted.

- pretrained:

  open_clip's tag for the weights of an architecture.

- weights:

  Local checkpoint file instead of a download.

- dir:

  Folder to write to. By default the model's folder in
  [`onnxCache()`](https://leipzig.github.io/dimoose/reference/onnxCache.md),
  where
  [`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md)
  and `visionModel(backend = "onnx")` find it by the same `name`.

- quantize:

  Which smaller copies to write as well: `"int8"`, `"fp16"`, both or
  neither (`character(0)`).

- python:

  The Python to run the script with; it needs the packages in the
  package's `python/requirements.txt` and
  `python/requirements-export.txt`. By default, if the `uv` program is
  installed, `uv` provides a Python with those packages (downloading
  them the first time); otherwise `python3`.

- run:

  For tests: a function `(command, args)` that runs the script and
  returns its exit status.

## Value

The folder, invisibly.

## Details

Each file is checked against the PyTorch model as it is written; the
script prints the files' sizes and how close their embeddings are.

## Files written

- `dimoose_onnx.json`: architecture, image size, patch size, embedding
  dimensions, preprocessing (`resize`, `interpolation`, `crop`,
  `rescale`, `mean`, `std`), the file names and sizes of each precision,
  and the names of the encoders' inputs and outputs.

- `image_encoder.onnx`: input `pixel_values` (`n x 3 x S x S`, float32);
  outputs `image_embeds` (`n x d`, not normalised) and `patch_embeds`
  (`n x g*g x d`, the projected patch tokens).

- `text_encoder.onnx`: input `input_ids` (`n x 77`, int64); output
  `text_embeds` (`n x d`, not normalised).

- `tokenizer.json`: the tokenizer in the Hugging Face `tokenizers`
  format, which transformers.js also reads.

- with `quantize`: `image_encoder_int8.onnx`, `text_encoder_int8.onnx`
  (weights as 8-bit integers, about a quarter of the size) and
  `image_encoder_fp16.onnx`, `text_encoder_fp16.onnx` (16-bit floats,
  half the size, same embeddings).

## Examples

``` r
if (FALSE) { # \dontrun{
exportOnnxModel("bioclip")
model <- onnxModel("bioclip", precision = "int8")
} # }
```
