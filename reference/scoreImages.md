# Score new images against a key's features

Embeds the images (once per distinct crop region the key's text features
use) and applies
[`featureScores()`](https://leipzig.github.io/dimoose/reference/featureScores.md).

## Usage

``` r
scoreImages(key, model, paths)
```

## Arguments

- key:

  A key with a `features` table.

- model:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- paths:

  Image files, or an
  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  (its `path` column is embedded and its `id` column names the rows).

## Value

An `images x features` matrix for
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md).
