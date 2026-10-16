# Discover sniglets by clustering patch embeddings

A sniglet is a visual feature that a model found and that has no name of
its own, so dimoose coins one for it (`"dulmzil"`). This function runs
k-means on every patch embedding of every image and keeps the unit
length centroids as the definitions of `k` sniglets. An image "has" a
sniglet when one of its patches is close to that centroid (see
[`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)).
Once you have looked at what a sniglet picks out, give it a real name
with
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md).

## Usage

``` r
discoverSniglets(patches, k = 40, seed = 1, nstart = 10, exemplars = 4)

discoverTerms(...)
```

## Arguments

- patches:

  A numeric array `images x regions x dimensions` (unit length rows),
  e.g. `embedImages(...)$patches`; `dimnames(patches)[[1]]` are the
  image ids. Rows that are all zero are empty regions and are ignored.

- k:

  Number of sniglets.

- seed:

  Seed for k-means and for
  [`inventNames()`](https://leipzig.github.io/dimoose/reference/inventNames.md).

- nstart:

  Random starts for
  [`stats::kmeans()`](https://rdrr.io/r/stats/kmeans.html).

- exemplars:

  Number of example regions to record per sniglet, each from a different
  image.

- ...:

  Passed to `discoverSniglets()`.

## Value

An object of class `dimooseSniglets`: `sniglets` (data frame with `id`,
`sniglet` (the coined word), `name` (what people see; the coined word
until renamed) and `definition`), `centroids` (`k x d`, rows named by
coined word), `exemplars` (data frame `sniglet`, `image`, `patch`,
`score`: the best-matching region of each of the best-matching images),
`best` (for every image, the region that matches each sniglet best) and
`tiles` (the tiling of the regions, see
[`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)).

## Details

`discoverTerms()`,
[`termScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
and
[`keyFromTerms()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
are the earlier names of `discoverSniglets()`,
[`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
and
[`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
and still work.

## Examples

``` r
set.seed(1)
patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
norms <- sqrt(apply(patches^2, c(1, 2), sum))
patches <- sweep(patches, c(1, 2), norms, "/")
dimnames(patches) <- list(letters[1:5], NULL, NULL)
discoverSniglets(patches, k = 3)$sniglets
#>   id       sniglet          name definition
#> 1  1     gaithiark     gaithiark       <NA>
#> 2  2 treuxraikbluk treuxraikbluk       <NA>
#> 3  3     zhuprierl     zhuprierl       <NA>
```
