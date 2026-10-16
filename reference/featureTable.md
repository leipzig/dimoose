# A table of machine-computable features

Keys built from images (see
[`keyFromTerms()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
and
[`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md))
carry a `features` table that says how a machine computes the score each
lead tests.
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
walks a key over a matrix of such scores.

## Usage

``` r
featureTable(
  id,
  kind,
  label = id,
  prompt = NA,
  negative_prompt = NA,
  region = NA,
  embedding = NULL,
  exemplars = NULL,
  definition = NA
)
```

## Arguments

- id:

  Feature ids, e.g. `"sniglet:dulmzil"` or `"text:round_headlights"`.

- kind:

  `"centroid_patch_max"` (highest cosine similarity between any image
  patch embedding and `embedding`), `"clip_text_pair"` (cosine with
  `prompt` minus cosine with `negative_prompt`) or `"external"`
  (computed by the user).

- label:

  Name shown to people; defaults to `id`.

- prompt, negative_prompt:

  Texts for `clip_text_pair` features.

- region:

  Crop as `"y0,y1,x0,x1"` fractions, or `NA` for the whole image.

- embedding:

  List of numeric vectors (one per feature), or `NULL`.

- exemplars:

  List of data frames with columns `image`, `patch`, `score` and
  optionally `png` (base64) showing what the feature means.

- definition:

  Optional sentence saying what the feature is, shown in the wizard's
  glossary (see
  [`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)).

## Value

A data frame with the columns above; `embedding` and `exemplars` are
list columns.

## Examples

``` r
featureTable("sniglet:x", "centroid_patch_max", embedding = list(c(1, 0, 0)))
#>          id               kind     label prompt negative_prompt region
#> 1 sniglet:x centroid_patch_max sniglet:x   <NA>            <NA>   <NA>
#>   definition embedding exemplars
#> 1       <NA>   1, 0, 0      NULL
```
