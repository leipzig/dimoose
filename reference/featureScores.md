# Compute a key's feature scores from embeddings

Model-free: give it the embeddings and it applies each feature's rule.
`centroid_patch_max` features need `patches`; `clip_text_pair` features
need `image` and `textEmb` (rows named by prompt). For `external`
features supply the scores yourself.

## Usage

``` r
featureScores(key, image = NULL, patches = NULL, textEmb = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key with a `features` table.

- image:

  `objects x d` matrix of image embeddings (unit rows).

- patches:

  `objects x patches x d` array of patch embeddings.

- textEmb:

  `prompts x d` matrix of text embeddings whose row names are the prompt
  texts, e.g. from
  [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md).

## Value

An `objects x features` matrix with feature ids as column names.

## See also

[`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md)
for images-to-scores in one call.
