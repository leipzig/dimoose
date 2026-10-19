# Suggest which of a key's species a photo shows

Compares each photo with the names of the key's results and ranks the
results by how well they match, so a photo can be checked against the
species the key covers. This works best with a model trained on names of
organisms, such as BioCLIP 2 (`visionModel(name = "bioclip-2")`): it
recognises a species from its scientific name without being shown any
examples. Only the key's own species are considered, which makes the
answers much more reliable than asking the model to name a species out
of all those it knows.

## Usage

``` r
suggestSpecies(key, model, paths, top = 3, prompt = "a photo of %s.")
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- model:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- paths:

  Image files, or an
  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  (its `path` column is embedded and its `id` column names the rows).

- top:

  How many of the best-matching results to return per photo.

- prompt:

  The text each name is put into, with `%s` where the name goes. The
  default is the one BioCLIP was trained with.

## Value

A data frame with `top` rows per image: `image` (its id), `rank`,
`Taxon`, `probability` and `similarity` (cosine similarity).

## Details

Each result is described by its scientific name when it is written as
`"Common name (Genus species)"`, and by the whole result otherwise. The
probabilities are a softmax over all the key's results with the
temperature CLIP models are trained with (cosine similarity times 100).

## See also

[`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md)
for one answer per photo, at the genus or family when the species is
uncertain.

## Examples

``` r
if (FALSE) { # \dontrun{
model <- visionModel(name = "bioclip-2")
suggestSpecies(montanaKey(), model, "my-photo.jpg")
} # }
```
