# Write what a web page needs to identify photos with a key's species

Photo identification as
[`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md)
and
[`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md)
do it has two halves: the names of the key's results are embedded as
texts, and the photo is embedded as an image and compared with them. The
text half can be done ahead of time, here; a web page then needs only
the image encoder to identify a photo on the visitor's own device, with
no server and no upload. This function writes the files such a page
loads.

## Usage

``` r
exportBrowserModel(
  key,
  model,
  dir,
  encoder = NULL,
  prompt = "a photo of %s.",
  textEmb = NULL
)
```

## Arguments

- key:

  A key whose results are the labels.

- model:

  The
  [`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md)
  (or
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md))
  to embed the labels with. It must be the model the image encoder
  belongs to.

- dir:

  Folder to write to; created if needed.

- encoder:

  The image encoder for the page: `NULL` copies the image encoder of
  `model` (which must then be an
  [`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md));
  `"hub"` points the page at that file on the Hugging Face Hub instead
  of copying it (for a model that came from there); a file path copies
  that file; a web address (`https://...`) is written to the manifest as
  it is.

- prompt:

  The text each name is put into, with `%s` where the name goes, as in
  [`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md).

- textEmb:

  Optional text embeddings made earlier, a matrix whose row names are
  the prompts (from
  [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
  or
  [`loadEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md));
  the labels are then not embedded again.

## Value

The path of `model.json`, invisibly.

## Files written to `dir`

**`model.json`**, the manifest (UTF-8 JSON):

- `format`: `"dimoose-browser-model"`; `version`: `1`.

- `key`: `desc` (the key's description) and `taxa` (the number of
  labels).

- `model`: `arch`, `pretrained`, `dim` (embedding dimensions),
  `library`.

- `image_encoder`: `file` (a file name in `dir`, or `null`), `url` (a
  web address, or `null`; one of the two is set), `bytes`, `precision`
  (`"int8"`, `"fp16"`, `"fp32"` or `null` if unknown), `input` (the
  input's name, `"pixel_values"`), `input_type` (`"float32"`),
  `input_shape` (`[1, 3, S, S]`), `output` (the output to read,
  `"image_embeds"`), `normalized` (`false`: divide the output by its
  length).

- `preprocess`, how to turn a photo into the input: `resize`
  (`"shortest"`: scale so the shorter side is `resize_to` pixels,
  keeping the shape), `interpolation` (`"bicubic"`), `crop` (`"center"`:
  cut the middle `image_size` x `image_size` square), `rescale`
  (multiply the 0-255 values by this, 1/255), `mean` and `std` (per
  channel: subtract, then divide), `layout` (`"NCHW"`), `channels`
  (`"RGB"`).

- `text_embeddings`: `file` (`"text_embeddings.bin"`), `dtype`
  (`"float32"`), `byte_order` (`"little"`), `shape` (`[labels, dim]`),
  `order` (`"row-major"`: label by label), `normalized` (`true`),
  `prompt` (the template).

- `labels`: one object per row of the text embeddings, in order: `taxon`
  (the result as the key's leads write it, which is what to look up in
  the key), `name` (the name put into the prompt: the scientific name
  when the result has one) and `prompt` (the text that was embedded).

- `logit_scale`: `100`.

**`text_embeddings.bin`**: `labels x dim` 32-bit little-endian floats
and nothing else, row by row; in JavaScript,
`new Float32Array(await (await fetch(url)).arrayBuffer())`.

**`image_encoder.onnx`**: the image encoder, unless the manifest gives a
`url` instead.

## What the page does

Prepare the photo as `preprocess` says, run the image encoder (for
example with onnxruntime-web), divide `image_embeds` by its length to
get `v`, and take the dot product of `v` with each row of the text
embeddings. The probability of each label is the softmax of
`logit_scale` times those dot products, which is what
[`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md)
computes.

## Size

The image encoder is the download that matters. Use an `"int8"` encoder
for the web: 96 MB for CLIP ViT-B/32 and 90 MB for BioCLIP as
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md)
writes them, against about 350 MB unquantised, with the same answers on
dimoose's example photos (BioCLIP 2, a larger model, is 310 MB even so).
Where that is still too much, `"mobileclip-s0"` at `"fp16"` is 23 MB,
but it is a general model that does not know species names as BioCLIP
does. The text embeddings are tiny (2 KB per label), and are best made
with the `"fp32"` text encoder:
`onnxModel(name, precision = "int8", textPrecision = "fp32")`.

## Tested with onnxruntime-web

The `"int8"`, `"fp16"` and `"fp32"` encoders that
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md)
writes for CLIP ViT-B/32 and BioCLIP were run in onnxruntime-web 1.31.1
on its WebAssembly backend (under Node.js) from folders this function
wrote, with the 14 Montana example photos prepared as `preprocess` says.
All three load and run there. Against the same file run in Python the
lowest cosine of the embeddings was 0.9996 for `"int8"` and 1.0000 for
`"fp16"` and `"fp32"`, and the most likely label was the same for every
photo. The `"int8"` files hold 8-bit weights that are turned back into
floats when the model loads, so they use no integer arithmetic a runtime
might lack. The WebGPU backend was not tested.

Ready-made `_quantized` files from the Hub (`encoder = "hub"` with an
`"int8"` model) are quantised differently, with integer arithmetic. That
of `Xenova/clip-vit-base-patch32` had a lowest cosine of 0.85 with the
`"fp32"` embeddings on the same backend and gave another most likely
label for 5 of the 14 photos; its `"fp16"` file had 1.0000. Point a page
at the `"fp16"` file, or copy in an `"int8"` encoder from
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md).

How the photo is resized matters more than the encoder's precision.
`preprocess$interpolation` names the filter the model was trained with
(bicubic, with smoothing when a photo is made smaller, as the Python
library Pillow does it). With BioCLIP on the Montana photos, resizing
with a bilinear filter instead gave embeddings with a cosine of 0.93 to
0.98 (0.97 on average) with the right ones, and nearest-neighbour 0.84
to 0.95.

## See also

[`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md),
[`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md),
[`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md).

## Examples

``` r
if (FALSE) { # \dontrun{
model <- onnxModel("bioclip", precision = "int8", textPrecision = "fp32")
exportBrowserModel(montanaKey(), model, "site/model")
list.files("site/model")   # image_encoder.onnx, model.json, text_embeddings.bin
} # }
```
