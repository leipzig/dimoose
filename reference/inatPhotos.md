# Download a balanced sample of iNaturalist photos

Collects field photos to test a key with: for each species, `n`
observations from [iNaturalist](https://www.inaturalist.org) with an
openly licensed photo, the photo files, and a manifest that says where
every photo came from, so that a benchmark can be cited and run again.

## Usage

``` r
inatPhotos(
  taxa,
  n = 20,
  place = NULL,
  qualityGrade = "research",
  licenses = c("cc0", "cc-by", "cc-by-nc"),
  dir,
  fetch = benchInatGet,
  download = benchDownload,
  size = "medium",
  pool = 200,
  strata = 10,
  idBelow = NULL,
  seed = 1,
  perObserver = 1,
  photosPerObservation = 1,
  query = list(),
  pause = 1
)
```

## Arguments

- taxa:

  The species: scientific names, results written
  `"Common name (Genus species)"`, a
  [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
  (its results are used), or iNaturalist taxon ids (a numeric vector,
  named to give the labels).

- n:

  Observations to sample per species.

- place:

  Optional place to restrict the sample to: an iNaturalist place id, or
  a name to look up (the best match is used and reported).

- qualityGrade:

  iNaturalist quality grade. `"research"` means the community agreed on
  the species.

- licenses:

  Photo licences to accept.

- dir:

  Folder to put the photos and `manifest.csv` in; one subfolder per
  species. Keep it outside a package or repository.

- fetch:

  Function `function(url, query)` that performs an API request and
  returns the parsed JSON as a list. The default calls the iNaturalist
  API; tests give their own.

- download:

  Function `function(url, destfile)` that saves a photo.

- size:

  Photo size: `"small"` (240 px), `"medium"` (500 px), `"large"` (1024
  px) or `"original"`.

- pool, strata:

  Size of the pool the sample is drawn from, and the number of slices of
  the id range it is collected from.

- idBelow:

  Only observations with an id below this; see above.

- seed:

  Seed for drawing the sample from the pool.

- perObserver:

  Most observations to take from one observer per species.

- photosPerObservation:

  Most photos to take from one observation.

- query:

  Further parameters for the observation search, e.g.
  `list(month = "6,7,8")` for summer photos only.

- pause:

  Least number of seconds between requests.

## Value

The manifest, a data frame with one row per photo: `taxon` (the label,
as given in `taxa`), `scientific_name`, `taxon_id`, `observation_id`,
`photo_id`, `license`, `attribution`, `url`, `observation_url`,
`observed_on`, `file` (relative to `dir`), `quality_grade`, `place_id`,
`id_below` and `retrieved`; plus `path`, the full file name on this
computer, which is not written to `manifest.csv`.
[`benchmarkKey()`](https://leipzig.github.io/dimoose/reference/benchmarkKey.md)
takes it as its `photos`.

## How the sample is drawn

The sample depends only on the arguments, not on the day it is drawn:

1.  `idBelow` fixes the snapshot: only observations with a smaller id
    are considered. When it is `NULL` the newest observation id at the
    time of the call is used and recorded in the manifest (`id_below`);
    give that value to draw the same sample again later.

2.  For each species a pool of up to `pool` observations is collected
    from `strata` equal slices of the id range (the newest observations
    below each cut), so that the pool spans the years rather than being
    last month's photos. Ids follow upload dates, so each slice is a
    short stretch of time and the same stretches are used for every
    species; raise `strata` (one request each) for an evener spread over
    the seasons.

3.  From the pool, sorted by id, `n` observations are drawn with `seed`,
    taking at most `perObserver` from one observer, so that one person's
    many photos of the same tree cannot dominate.

Observations that were deleted or lost their research grade since are
simply no longer returned, so an old sample can shrink; the photo files
already in `dir` are kept and not downloaded again. A photo that cannot
be downloaded, or that turns out not to be an image, is left out of the
manifest with a warning; it is not replaced by another.

## Which taxon a name means

A name is looked up in iNaturalist's taxon search and must match a
taxon's name exactly; a looser match (the search also finds "Oenantheae"
and "Oenanthe oenanthe" for "Oenanthe") is never used. A name
iNaturalist lists as a synonym resolves to the taxon it now belongs to,
with a message. The same name can belong to two taxa (the genus
*Oenanthe* is a bird and a plant): then the one whose rank fits the name
best and that has the most observations is used, with a warning that
lists the candidates and their ids. Give the taxon id instead of the
name to choose yourself. The manifest records the id that was used.

## API etiquette

Requests are spaced at least `pause` seconds apart (iNaturalist asks for
about one request a second) and identify themselves with a generic
User-Agent. Only photos whose own licence is in `licenses` are taken;
the manifest keeps each photo's licence and attribution, which the CC BY
licences require you to show wherever the photos are.

## See also

[`benchmarkKey()`](https://leipzig.github.io/dimoose/reference/benchmarkKey.md)

## Examples

``` r
if (FALSE) { # \dontrun{
photos <- inatPhotos(montanaKey(), n = 20, dir = file.path(tempdir(), "inat"))
table(photos$taxon)
} # }
```
