# Save embeddings to a file, and read them back

Embedding images needs a vision model, and so Python; using embeddings
does not. `saveEmbeddings()` writes what
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
or
[`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
returned to one small file, and `loadEmbeddings()` reads it back as it
was, row names and tiling included, on a computer with no Python at all.
Everything dimoose does after embedding
([`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md),
[`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md),
[`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
[`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md),
[`featureScores()`](https://leipzig.github.io/dimoose/reference/featureScores.md),
...) works from the loaded embeddings.

## Usage

``` r
saveEmbeddings(x, file, precision = c("float32", "float16"), model = NULL)

loadEmbeddings(file)
```

## Arguments

- x:

  A numeric matrix or array, or a list of them such as
  [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
  returns (entries that are `NULL` are left out).

- file:

  File to write or read; `.safetensors` is the usual ending.

- precision:

  `"float32"`, or `"float16"` for a file half the size. Embeddings have
  unit length, so 16-bit floats change cosine similarities only in the
  fourth decimal place.

- model:

  Optional
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)
  the embeddings were made with; its details are stored in the file.
  Embeddings from `loadEmbeddings()` keep the model they were loaded
  with when saved again.

## Value

`saveEmbeddings()` returns `file`, invisibly. `loadEmbeddings()` returns
what was saved: a matrix or array, or a list of them. If the file
records a model, its details are in the result's `model` attribute.

## File format

The file is in the
[safetensors](https://huggingface.co/docs/safetensors) format, which
Python (`safetensors.numpy.load_file()`), JavaScript and other languages
read too:

- 8 bytes: the length `N` of the header in bytes, an unsigned 64-bit
  little-endian integer;

- `N` bytes: the header, one JSON object in UTF-8, padded with spaces so
  that `N` is a multiple of 8. It has one entry per array, in the order
  the arrays are stored, named `image` and `patches` (for
  [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)),
  `embeddings` (for a single matrix) or by the names of the list given.
  Each entry has `dtype` (`"F32"` or `"F16"`), `shape` (the dimensions,
  e.g. `[36, 512]`) and `data_offsets` (`[begin, end]`: the array's
  first byte and the byte after its last, counted from the end of the
  header);

- the arrays' numbers, one array after another with nothing between
  them, in row-major (C) order: an `images x d` matrix is stored image
  by image, an `images x tiles x d` array image by image and tile by
  tile.

Numbers are IEEE 754 floats of 4 bytes (`"F32"`) or 2 bytes (`"F16"`),
and always little-endian, whatever the computer that writes or reads the
file.

The header's `__metadata__` entry is an object of strings: `format`
(`"dimoose-embeddings"`), `version` (`"1"`), `single` (`"true"` when `x`
was one array and not a list, so that it is read back as one),
`rownames.<array>` (a JSON array of the row names: image ids or texts;
other dimensions' names are not kept), `tiles.<array>` and
`empty.<array>` (the tiling and the rule for empty tiles, see
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md),
as numbers separated by commas) and `model` (a JSON object with the
model's details, if there is a model).

`loadEmbeddings()` also reads safetensors files written by other
programs, as long as their arrays are 16-, 32- or 64-bit floats.

## Precision

R keeps numbers as 64-bit floats and the file holds 32-bit ones (about 7
significant digits). Vision models compute in 32 bits, so what
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
and
[`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
return is saved and read back exactly; other numbers come back rounded
to the nearest 32-bit float. With `precision = "float16"` every number
is rounded to about 3 significant digits: unit-length embeddings change
by at most 0.0005 per coordinate. Numbers too large for the chosen
precision become `Inf`, and `NA` is read back as `NaN`.

## Embeddings that come with dimoose

The embeddings of the package's example photos are in its
`extdata/embeddings` folder, so the examples can be followed with no
Python: `pics-clip-vit-b-32.safetensors` (the 36 fruit photos in
`extdata/pics`, whole photos and 4 x 4 tiles),
`new-photos-clip-vit-b-32.safetensors` (the 6 photos in
`extdata/new-photos`), `texts-clip-vit-b-32.safetensors` (the prompts of
the vision vignette) and `montana-bioclip.safetensors` (the tree photos
in `extdata/montana` and the names of
[`montanaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)'s
species, embedded with BioCLIP). The folder's `README.md` says how each
was made.

## Examples

``` r
# stand-ins for embedImages(model, images): 3 images, 2 tiles each, 4 dimensions
emb <- list(image = matrix(rnorm(12), 3, 4, dimnames = list(c("a", "b", "c"), NULL)),
            patches = array(rnorm(24), c(3, 2, 4), dimnames = list(c("a", "b", "c"), NULL, NULL)))
attr(emb$patches, "tiles") <- 1L
file <- tempfile(fileext = ".safetensors")
saveEmbeddings(emb, file)
back <- loadEmbeddings(file)
all.equal(back$image, emb$image, tolerance = 1e-6)
#> [1] TRUE
rownames(back$image)
#> [1] "a" "b" "c"
attr(back$patches, "tiles")
#> [1] 1

# the example photos' embeddings, made with CLIP ViT-B/32: a key with no Python
pics <- loadEmbeddings(system.file("extdata", "embeddings", "pics-clip-vit-b-32.safetensors",
                                   package = "dimoose"))
dim(pics$patches)
#> [1]  36  16 512
attr(pics, "model")$arch
#> [1] "ViT-B-32"
images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
sniglets <- discoverSniglets(pics$patches, k = 40)
scores <- snigletScores(pics$patches, sniglets$centroids)
keyFromSniglets(scores, images, sniglets, method = "rpart")
#> <dimoose key> Key generated from sniglets
#>   5 couplets, 10 leads, 6 taxa, up to 4 steps deep (2.8 on average)
```
