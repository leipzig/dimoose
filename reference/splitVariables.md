# Variables a fitted tree splits on

Variables a fitted tree splits on

## Usage

``` r
splitVariables(fit)
```

## Arguments

- fit:

  A [`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md)
  fit.

## Value

The names (as given in `partition`) of the variables used in any split,
in the order they first appear; `character(0)` if the tree has no
splits.
