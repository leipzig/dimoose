# Prompts for a vocabulary of visual features

Prompts for a vocabulary of visual features

## Usage

``` r
vocabularyPrompts(vocabulary, template = "{x}")
```

## Arguments

- vocabulary:

  Data frame with `feature` and `opposite` columns (and an optional
  `region`, `"y0,y1,x0,x1"` fractions).

- template:

  Text with `{x}` where the feature goes, e.g.
  `"a pickup truck with {x}"`.

## Value

A character vector: the feature prompt then the opposite prompt for each
row, in order. Embed these with
[`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
and pass the result to
[`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md).

## Examples

``` r
v <- data.frame(feature = c("round lights", "a flat hood"),
                opposite = c("square lights", "a curved hood"))
vocabularyPrompts(v, "a truck with {x}")
#> [1] "a truck with round lights"  "a truck with square lights"
#> [3] "a truck with a flat hood"   "a truck with a curved hood"
```
