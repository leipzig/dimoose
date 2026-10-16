# Follow a key by machine

Walks each row of `scores` through `key`: at every couplet the lead
whose test (`Feature`, `Test`, `Threshold`) passes is taken. When no
lead or more than one passes (for instance on a missing score), the
result is `NA`.

## Usage

``` r
classify(key, scores)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key with `Feature`, `Test` and `Threshold` lead columns, e.g. from
  [`keyFromTerms()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md).

- scores:

  A numeric matrix, one row per object, with a column for every feature
  id the key tests (see
  [`featureScores()`](https://leipzig.github.io/dimoose/reference/featureScores.md)
  and
  [`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md)).

## Value

A data frame with `id` (row names of `scores`), `result` and `path` (the
leads taken, e.g. `"1a 3b"`).
