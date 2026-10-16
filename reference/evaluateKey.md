# Accuracy of a key followed by machine

Accuracy of a key followed by machine

## Usage

``` r
evaluateKey(key, scores, labels, groups = NULL)
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

- labels:

  True label of each row of `scores`.

- groups:

  Optional named vector mapping labels to coarser groups (e.g. model
  years to generations) for a second accuracy figure.

## Value

A list: `results` (one row per object with `actual`, `predicted`,
`correct`, `groupCorrect`), `accuracy`, `groupAccuracy` and `confusion`.
