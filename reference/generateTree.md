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

A fitted `rpart`, `randomForest` or `gbm` object.

## Examples

``` r
features <- data.frame(
  family = factor(c("A", "B", "C", "A", "B", "C")),
  fin = factor(c("x", "y", "y", "x", "y", "y")),
  head = factor(c("p", "p", "q", "p", "p", "q"))
)
generateTree(features, "family",
  params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1))
)
#> n= 6 
#> 
#> node), split, n, loss, yval, (yprob)
#>       * denotes terminal node
#> 
#> 1) root 6 4 A (0.3333333 0.3333333 0.3333333)  
#>   2) fin=x 2 0 A (1.0000000 0.0000000 0.0000000) *
#>   3) fin=y 4 2 B (0.0000000 0.5000000 0.5000000)  
#>     6) head=p 2 0 B (0.0000000 1.0000000 0.0000000) *
#>     7) head=q 2 0 C (0.0000000 0.0000000 1.0000000) *
```
