# Split photos into training and test sets by observation

Photos of one observation show the same individual, often seconds apart.
Putting one in the training set and another in the test set would make a
key look better than it is, so whole observations go to one side.

## Usage

``` r
splitByObservation(observation, label, test = 0.3, seed = 1)
```

## Arguments

- observation:

  The observation each photo belongs to. A photo without one (`NA`)
  counts as an observation of its own.

- label:

  The class of each photo. The split is made within each class, so every
  class keeps about the same share for testing.

- test:

  Share of each class's observations to test with.

- seed:

  Seed for the draw.

## Value

A character vector, `"train"` or `"test"` for each photo. A class with
two or more observations gets at least one on each side; a class with a
single observation goes to the training set. An observation with photos
in several classes stays whole too: all its photos go to the training
set, so nothing in the test set has a sibling in training.

## Examples

``` r
obs <- c(1, 1, 2, 3, 4, 5, 5, 6)
label <- rep(c("oak", "elm"), each = 4)
data.frame(obs, label, split = splitByObservation(obs, label, test = 0.5))
#>   obs label split
#> 1   1   oak  test
#> 2   1   oak  test
#> 3   2   oak train
#> 4   3   oak  test
#> 5   4   elm  test
#> 6   5   elm  test
#> 7   5   elm  test
#> 8   6   elm train
```
