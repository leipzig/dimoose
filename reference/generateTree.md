# Generate a tree from a feature matrix

Fits a classification tree (or tree ensemble) with the taxon column as
the response and every other column as a feature.

## Usage

``` r
generateTree(
  data,
  target_col,
  method = c("rpart", "randomForest", "gbm"),
  params = list()
)
```

## Arguments

- data:

  A data frame containing the feature matrix.

- target_col:

  Name of the target/response column.

- method:

  `"rpart"`, `"randomForest"` (requires the 'randomForest' package), or
  `"gbm"` (requires the 'gbm' package; `"multinomial"` distribution
  unless the response is numeric 0/1, which uses `"bernoulli"`).

- params:

  Optional list of arguments passed to the fitting function, overriding
  the defaults.

## Value

A fitted `rpart`, `randomForest` or `gbm` object. For the last two the
`call` is the call to `generateTree()`.

## Details

The rpart defaults are set for identification data, which usually has
one row per taxon: `rpart.control(minsplit = 2, minbucket = 1, cp = 0)`,
so the tree keeps splitting until every taxon is separated. (rpart's own
defaults, `minsplit = 20, minbucket = 7, cp = 0.01`, make no split at
all on such a matrix.) With many specimens per taxon pass your own
`control` in `params` to get a smaller tree, or just the settings to
change, e.g. `params = list(cp = 0.01)` or
`params = list(maxdepth = 3)`.
[`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)
turns the tree into a key;
[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
goes from matrix to key in one step and handles taxa that are variable
for a character.

## Examples

``` r
features <- data.frame(
  family = factor(c("A", "B", "C")),
  fin = factor(c("x", "y", "y")),
  head = factor(c("p", "p", "q"))
)
fit <- generateTree(features, "family")
fit
#> n= 3 
#> 
#> node), split, n, loss, yval, (yprob)
#>       * denotes terminal node
#> 
#> 1) root 3 2 A (0.3333333 0.3333333 0.3333333)  
#>   2) fin=x 1 0 A (1.0000000 0.0000000 0.0000000) *
#>   3) fin=y 2 1 B (0.0000000 0.5000000 0.5000000)  
#>     6) head=p 1 0 B (0.0000000 1.0000000 0.0000000) *
#>     7) head=q 1 0 C (0.0000000 0.0000000 1.0000000) *
keyFromRpart(fit)$leads
#>   Statement Choice Character Next Taxon
#> 1         1      a    fin: x    -     A
#> 2         1      b    fin: y    2      
#> 3         2      a   head: p    -     B
#> 4         2      b   head: q    -     C
```
