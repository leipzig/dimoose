# Score images against sniglets

Score images against sniglets

## Usage

``` r
snigletScores(patches, centroids)

termScores(patches, centroids)
```

## Arguments

- patches:

  As in
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md).

- centroids:

  A `k x d` matrix of sniglet centroids (unit rows), e.g.
  `discoverSniglets(...)$centroids`.

## Value

An `images x sniglets` matrix: for each sniglet, the highest cosine
similarity between the centroid and any patch of the image. Columns are
named by the coined words, whatever the sniglets have been renamed to.
