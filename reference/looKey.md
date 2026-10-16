# Leave-one-out evaluation of a key builder

Leave-one-out evaluation of a key builder

## Usage

``` r
looKey(images, build, score, groups = NULL)
```

## Arguments

- images:

  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  data frame of all images.

- build:

  Function of the training row indices returning a key.

- score:

  Function of (key, test row index) returning a one-row scores matrix
  for that image.

- groups:

  As in
  [`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md).

## Value

As
[`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md).
