# Build a dimoose key from a classification tree

Converts an [`rpart::rpart()`](https://rdrr.io/pkg/rpart/man/rpart.html)
classification tree into a dichotomous key: every split becomes a
couplet with two leads, and every leaf a result. Taxa that the tree
cannot separate share a leaf and are listed together (`"A / B"`). A
taxon rpart could not send down either side of a split, because the
split's variable is missing for it, is listed at every result below that
split.

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

[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md),
which builds a key straight from a character matrix and handles variable
taxa;
[`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)

## Examples

``` r
d <- data.frame(
  taxon = factor(c("A", "B", "C")),
  wings = factor(c("+", "-", "-")),
  spots = factor(c("-", "+", "-"))
)
fit <- generateTree(d, "taxon")
keyFromRpart(fit, "Three taxa")$leads
#>   Statement Choice Character Next Taxon
#> 1         1      a  wings: +    -     A
#> 2         1      b  wings: -    2      
#> 3         2      a  spots: +    -     B
#> 4         2      b  spots: -    -     C
```
