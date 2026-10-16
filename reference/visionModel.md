# Load a vision model for embedding images

Uses Python's open_clip through reticulate. You do not need to install
anything in Python yourself: the first call sets up a private Python
with the packages dimoose needs (`torch`, `open_clip_torch`, `pillow`,
`numpy`) and reuses it afterwards. That first call downloads them, which
takes a few minutes. This needs reticulate 1.41 or later.

## Usage

``` r
visionModel(
  weights = NULL,
  name = "ViT-B-32",
  pretrained = "openai",
  python = NULL
)
```

## Arguments

- weights:

  Local checkpoint file: OpenAI's `ViT-B-32.pt`, or an open_clip
  checkpoint for the architecture `name`. If `NULL`, the weights are
  downloaded.

- name:

  The model: an open_clip architecture name, `"bioclip"`, `"bioclip-2"`,
  `"hf-hub:<organisation>/<model>"` or `"local-dir:<folder>"` (see
  below).

- pretrained:

  open_clip's tag for the weights to download for an architecture
  `name`; not used for the other kinds of `name`.

- python:

  Optional path to the Python executable to use (passed to
  [`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html)).

## Value

An object of class `dimooseVisionModel` with `py` (the Python model) and
`spec` (library, architecture, weights SHA-256, image size, ...).

## Details

To use a Python of your own instead, give its path in `python`, or
select it with
[`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html),
[`reticulate::use_virtualenv()`](https://rstudio.github.io/reticulate/reference/use_python.html)
or the `RETICULATE_PYTHON` environment variable before the first call,
and install the packages there with
`reticulate::py_install(c("torch", "open_clip_torch", "pillow", "numpy"))`.

## Other models, including BioCLIP

Any open_clip model whose image side is a vision transformer works. The
key builders only see its embeddings, so nothing else changes.

- `visionModel(name = "bioclip")` loads
  [BioCLIP](https://imageomics.github.io/bioclip/) and
  `visionModel(name = "bioclip-2")` BioCLIP 2, models trained on images
  of organisms, from the Hugging Face Hub. They are downloaded on first
  use.

- `name = "hf-hub:<organisation>/<model>"` loads any other open_clip
  model on the Hub, and `name = "local-dir:<folder>"` a copy you have
  downloaded (the folder holds the model's `open_clip_config.json` and
  weights file).

- `name` and `pretrained` together select one of open_clip's built-in
  models, e.g. `name = "ViT-B-16", pretrained = "laion2b_s34b_b88k"`.

A key can only be followed with the model it was built with: use the
same model for
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
and later for
[`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md).

BioCLIP's text side was trained on names of organisms, not on
descriptions of what they look like. It suits sniglets
([`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)),
which use images only, better than vocabulary questions
([`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
model <- visionModel()                    # CLIP ViT-B/32
model <- visionModel(name = "bioclip")    # BioCLIP, for photos of organisms
} # }
```
