# Build a dimoose key from a classification tree

Converts an [`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html)
classification tree into a dichotomous key: every split becomes a
couplet with two leads, and every leaf a result. Taxa that the tree
cannot separate share a leaf and are listed together (`"A / B"`).

## Usage

``` r
keyFromRpart(
  fit,
  desc = "Key generated from a classification tree",
  meta = NULL
)
```

## Arguments

- fit:

  An `rpart` object with `method = "class"`, e.g. from
  [`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md).

- desc:

  Title of the key.

- meta:

  Key/value metadata data frame.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## See also

[`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)

## Examples

``` r
d <- data.frame(
  taxon = factor(c("A", "B", "C")),
  wings = factor(c("+", "-", "-")),
  spots = factor(c("-", "+", "-"))
)
fit <- generateTree(d, "taxon",
  params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0)))
keyFromRpart(fit, "Three taxa")$leads
#>   Statement Choice Character Next Taxon
#> 1         1      a  wings: +    -     A
#> 2         1      b  wings: -    2      
#> 3         2      a  spots: +    -     B
#> 4         2      b  spots: -    -     C
```
