# Benchmark identification on field photos

Measures how often photos are identified correctly, by one of three
routes:

## Usage

``` r
benchmarkKey(
  x,
  photos,
  model = NULL,
  route = NULL,
  top = 3,
  test = NULL,
  split = NULL,
  seed = 1,
  dir = NULL,
  prompt = "a photo of %s.",
  lineage = NULL,
  confidence = 0.8,
  k = 40,
  tiles = 4,
  method = "rpart",
  embeddings = NULL,
  reps = 1
)
```

## Arguments

- x:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key, or (for `route = "build"`) a
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- photos:

  The photos: the manifest
  [`inatPhotos()`](https://leipzig.github.io/dimoose/reference/inatPhotos.md)
  returns, the path of a `manifest.csv` (give `dir` too), or a data
  frame with `path` and `label` and optionally `id` and `observation`.
  Labels may be the key's results or just their scientific names.
  Without an observation column every photo counts as its own
  observation.

- model:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- route:

  `"names"`, `"key"` or `"build"`. By default `"build"` when `x` is a
  vision model, `"key"` for a key with machine tests and `"names"` for
  any other key.

- top:

  Report the accuracy within this many guesses (`"names"` only: a key
  gives one answer).

- test:

  Share of each species' observations to test with. By default 0.3 for
  `"build"` and all of them for the other routes, which learn nothing
  from the photos.

- split:

  Instead of `test`: `"train"` or `"test"` for each photo, e.g. from
  [`splitByObservation()`](https://leipzig.github.io/dimoose/reference/splitByObservation.md),
  to compare routes on the same test photos.

- seed:

  Seed for the split and for finding sniglets.

- dir:

  The folder the manifest's `file` column is relative to.

- prompt, lineage, confidence:

  As in
  [`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md).
  `lineage` is optional and is never looked up here.

- k, tiles, method:

  For `"build"`: number of sniglets
  ([`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)),
  tiling
  ([`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md))
  and tree method
  ([`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)).

- embeddings:

  For `"build"`: the result of
  [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
  for `photos`, if you have it already (rows in the same order).

- reps:

  Number of splits to run. One split of a small sample says little: six
  test photos per species move a species' accuracy by 17 points each.
  With `reps` above 1 the benchmark is repeated with seeds `seed`,
  `seed + 1`, ..., each with a new split (and, for `"build"`, a new key;
  the photos are embedded once), and the spread is reported. Needs a
  `test` share below 1, and no `split`.

## Value

An object of class `dimooseBenchmark`, a list with

- `route`, `n` (test photos), `nTrain`, `observations` (test
  observations);

- `accuracy`: share of test photos identified correctly (top-1);

- `interval`: its 95% Wilson interval (`lower`, `upper`), which treats
  the test photos as independent draws: read it as the least uncertainty
  there is, not all of it;

- `topK`: named vector of the accuracy within 1, ..., `top` guesses;

- `perSpecies`: for each species its number of test photos, `top1` and
  (for `"names"`) the accuracy within `top` guesses. Every species of
  the photos (and of the key) has a row; one without test photos has
  `n = 0` and `NA` accuracies;

- `confusion`: table of actual (rows) against predicted (columns), with
  the same species in the same order on both sides, so that the row sums
  are the `n` of `perSpecies` and the diagonal holds the correct
  answers. Any other answer has a column after them: a leaf that names
  several species, and `"<none>"` when a key gave no answer;

- `results`: one row per test photo with `id`, `observation`, `actual`,
  `predicted`, `rank` (where the true species came in the ranking) and
  `correct`;

- `split`: `"train"` or `"test"` for every photo given;

- with `reps` above 1, all of the above describe the first split, and
  there are also `repeats` (one row per split: `rep`, `seed`, `n`,
  `nTrain`, `correct`, `accuracy`), `accuracyMean`, `accuracySd` (the
  standard deviation between splits) and `accuracyRange`, and
  `perSpecies` gains `top1Mean`, the species' accuracy over all splits'
  test photos together. The splits share photos, so they are not
  independent samples: the spread shows how much one split can mislead,
  it is not a standard error;

- `key` (for `"build"`, the key that was built) and `identify` (for
  `"names"` with a `lineage`: the
  [`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md)
  answers with `correct`, and the shares that were `confident` and
  `correct`).

## Details

- `"names"`: the model ranks the key's own species for each photo from
  their names alone
  ([`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md));
  nothing is learned from the photos. With a `lineage` the answers of
  [`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md),
  which fall back to the genus, family or order when the species is
  uncertain, are scored too.

- `"key"`: a key with machine tests (from
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
  or
  [`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md))
  is followed for each photo
  ([`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md),
  [`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md)).

- `"build"`: a photo key is built from the training photos (sniglets
  found in them, then
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md))
  and followed for the test photos. This is the route to use for "how
  good a key can be learned from photos like these".

Training and test photos are divided by observation with
[`splitByObservation()`](https://leipzig.github.io/dimoose/reference/splitByObservation.md),
never photo by photo.

## See also

[`inatPhotos()`](https://leipzig.github.io/dimoose/reference/inatPhotos.md),
[`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md),
[`looKey()`](https://leipzig.github.io/dimoose/reference/looKey.md)

## Examples

``` r
if (FALSE) { # \dontrun{
key <- montanaKey()
photos <- inatPhotos(key, n = 20, dir = file.path(tempdir(), "inat"))
model <- visionModel(name = "bioclip-2")
benchmarkKey(key, photos, model)                    # species ranked from their names
benchmarkKey(model, photos)                         # a key built from 70% of the observations
} # }
```
