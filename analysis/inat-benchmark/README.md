# Field-photo benchmark: Montana broadleaf trees on iNaturalist photos

A first check of dimoose's photo identification on field photos rather than
studio crops. One small sample of photos and one model. Read the limits
before quoting a number.

## What was run

- **When:** 19 November 2026. The sample was drawn from the iNaturalist API
  that morning and first run 11:08 to 11:21 MST. The files here are from a
  second run of the same script on the same photos, 16:12 to 16:24 MST
  (`run-info.txt`), which added the repeated splits and gave the first run's
  predictions and confusion tables again, byte for byte. A third run with
  `--seed=2`, 16:24 to 16:36, is in `seed-2/`.
- **Script:** `Rscript analysis/inat-benchmark/run.R`, from the package root,
  with the working tree as it was that day (dimoose 0.2.0 plus the
  uncommitted `inatPhotos()`, `benchmarkKey()` and `splitByObservation()`).
  `--seed=2` gives another split of the same photos.
- **Species:** the eleven results of `montanaKey()`, the native broadleaf
  trees of Montana.
- **Photos:** 220, one photo from each of 220 research-grade observations,
  20 per species, from anywhere in the species' range (no place filter), no
  two observations of a species by the same observer. `inatPhotos(key, n = 20,
  seed = 1)` with its defaults: `medium` size (500 px), licences CC0 (12
  photos), CC BY (27) and CC BY-NC (181), pool of up to 200 observations per
  species from 10 slices of the id range below `id_below = 415646417`.
- **Model:** BioCLIP 2 (`visionModel(name = "bioclip-2")`,
  `hf-hub:imageomics/bioclip-2`, open_clip 3.3.0), on a laptop.
- **Lineage** for `identifyPhotos()`: GBIF, through `checkNames(key, kingdom =
  "Plantae")`.

Three things were measured with `benchmarkKey()`:

1. **names**: BioCLIP 2 ranks the key's eleven species for each photo from
   their scientific names (`suggestSpecies()`). Nothing is learned from the
   photos, so all 220 are test photos. `identifyPhotos()` (confidence 0.8),
   which answers with a genus or family when no species is likely enough, was
   scored on the same photos.
2. **build**: a photo key was built from 70% of each species' observations
   (154 photos: 4 x 4 tiles, 40 sniglets, `keyFromSniglets(method = "rpart")`)
   and followed by machine for the other 30% (66 photos, 6 per species). The
   split is by observation (`splitByObservation()`, seed 1); with one photo
   per observation that is also a split by photo.
3. **names on the 66 test photos of the build route**, read off the first
   result, for a like-for-like comparison.

The build route was then repeated over ten splits (seeds 1 to 10; the photos
are embedded once, and each split finds its own sniglets and builds its own
key), because 66 test photos are few.

## Results

Seed 1 (the files in this folder):

| Route | Test photos | Top-1 | 95% Wilson interval | Top-2 | Top-3 |
|---|---|---|---|---|---|
| names, all photos | 220 | 97.3% (214) | 94.2 to 98.7% | 100% | 100% |
| names, the build route's test photos | 66 | 100% (66) | 94.5 to 100% | 100% | 100% |
| build: sniglet key from 154 training photos | 66 | 71.2% (47) | 59.4 to 80.7% | n/a | n/a |

The intervals treat the test photos as independent draws from one population
of photos. They say nothing about the limits below (training-set overlap,
which species, which kind of photo), so read them as the least uncertainty
there is.

**The build route over ten splits** (`results-repeats.csv`): top-1 between
62.1% and 75.8% (41 to 50 of 66), mean 67.3%, standard deviation between
splits 4.2 points. The 71.2% of seed 1 is the second best of the ten, so
quote the mean, about two in three, rather than the first split. The splits
share photos, so the spread is not a standard error.

**Seed 2** (`seed-2/`, the same 220 photos, another split):

| Route | Test photos | Top-1 | 95% Wilson interval |
|---|---|---|---|
| names, all photos | 220 | 97.3% (214) | 94.2 to 98.7% |
| names, the build route's test photos | 66 | 95.5% (63) | 87.5 to 98.4% |
| build: sniglet key from 154 training photos | 66 | 62.1% (41) | 50.1 to 72.9% |

The names route learns nothing and has no random part, so on all 220 photos
it gave the same answers in every run. Seed 2's ten splits (seeds 2 to 11)
gave 60.6 to 75.8%, mean 66.2%, standard deviation 4.4. Over the eleven
different splits of both runs the built keys got 484 of 726 test photos
right (66.7%).

`identifyPhotos()` at confidence 0.8: 218 of 220 answers were confident; 207
named a species (204 right), 10 a genus (9 right) and 3 a family (3 right),
so 216 of 220 (98.2%) were right at the rank given.

All six misses of the names route had the right species second. Five are
within *Populus* or between *Populus* and *Salix* (`confusion-names.csv`).
The built keys were weakest on plains cottonwood (1 of 6 on the first split,
33% over the ten splits), quaking aspen (52%) and peachleaf willow (55%);
paper birch was best (87%). The first split's key has 41 couplets for 11
species, which is a tree fitted to its training photos more than a key a
person would follow.

## Files

| File | What it holds |
|---|---|
| `run.R` | The script. With `manifest.csv` present it reuses that sample; `--resample` draws a new one; `--seed=2` makes another split and writes to `seed-2/`. |
| `manifest.csv` | One row per photo: species, iNaturalist taxon, observation and photo ids, licence, attribution, photo URL, observation URL, date observed, and the `id_below` and date of the draw. |
| `results-summary.csv` | The first table above, with the counts and the Wilson intervals. |
| `results-repeats.csv` | The build route's ten splits: seed, test and training photos, number right, top-1 and its Wilson interval. |
| `results-per-species.csv` | Per species: test photos and top-1 (and top-3) for both routes, and the build route's top-1 over all ten splits' test photos (`build_top1_all_splits`). |
| `results-identify.csv` | The `identifyPhotos()` shares. |
| `confusion-names.csv`, `confusion-build.csv` | Actual (rows) against predicted (columns); the build table is the first split's. |
| `predictions.csv` | Per photo: the true species, both routes' answers, the rank of the true species, the split and the `identifyPhotos()` answer. |
| `run-info.txt` | Times, sample, model and versions of the run. |
| `seed-2/` | The same result files for `--seed=2` (no manifest: the photos are the same). |

The photos themselves are not in the repository. The script keeps them in R's
user cache folder (`tools::R_user_dir("dimoose", "cache")`) and downloads any
that are missing from the URLs in the manifest. They belong to their
photographers: the `license` and `attribution` columns say under which terms
each may be used and whom to credit.

## Limits

- **BioCLIP 2 has very likely seen photos like these, perhaps these very
  ones.** Its training set, TreeOfLife-200M, is described as drawing on GBIF, which
  includes iNaturalist's research-grade observations.
  Whether any of the 220 photos were in it was not checked. The names route
  is therefore not a test on unseen data, and 97% is an upper estimate of
  what to expect on your own photos. The build route uses the same model's
  embeddings, so it is not free of this either.
- **Small sample, drawn once.** 220 photos from one draw of iNaturalist, 20
  per species, and only 6 test photos per species on the build route: one
  photo there is 17 points of a species' accuracy. The repeated splits show
  how much the split matters (62 to 76% on the same photos); they are new
  divisions of the same 220 photos, not new photos, so they say nothing
  about how another sample would do.
- **Eleven species, chosen in advance.** The model only has to choose among
  the key's own species. Any other tree is outside the test.
- **Research-grade observations with open licences only**, which are the
  easier, better photographed ones, and what an observation shows (leaf, bark,
  whole tree, winter twig) was not controlled.
- **Uneven in season.** The pool comes from ten slices of the id range, which
  are ten short stretches of time, the same for every species. 101 of the 220
  observations were made in June and none in August.
- **Worldwide, not Montana.** The photos come from each species' whole range.
- **One model and one set of settings** (BioCLIP 2; 4 x 4 tiles, 40 sniglets,
  rpart). No other model, no tuning, and no comparison with a person
  following `montanaKey()`.
- **One machine.** The run was repeated on the same laptop and gave the same
  answers, but not on a second machine. The 220-photo sample itself was not
  drawn a second time: drawing it again with the same `id_below` and seed
  should give the same observations unless some have since been deleted or
  lost research grade (a smaller draw of other taxa, made twice that
  afternoon, did come out identical).
