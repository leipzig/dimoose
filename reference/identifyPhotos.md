# Name what a photo shows, as precisely as the evidence allows

Like
[`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md),
compares each photo with the key's own species, but gives one answer per
photo: the species when it alone is likely enough, otherwise the genus,
family or order whose species together are. A photo of a cottonwood that
the model cannot place between the key's two cottonwoods is reported as
genus *Populus* rather than as a coin toss between them.

## Usage

``` r
identifyPhotos(
  key,
  model,
  paths,
  confidence = 0.8,
  lineage = NULL,
  kingdom = NULL,
  prompt = "a photo of %s."
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- model:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- paths:

  Image files, or an
  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  (its `path` column is embedded and its `id` column names the rows).

- confidence:

  The probability an answer must reach, between 0 and 1.

- lineage:

  Optional data frame with columns `Taxon` (as in the key), `genus`,
  `family` and `order`, such as the output of
  [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md).

- kingdom:

  Optional kingdom ("Plantae", "Animalia", "Fungi", ...), which helps
  GBIF tell apart names that are used in more than one kingdom.

- prompt:

  The text each name is put into, with `%s` where the name goes. The
  default is the one BioCLIP was trained with.

## Value

A data frame with one row per image: `image`, `name` (the scientific
name of the answer), `rank` (`"species"`, `"genus"`, `"family"` or
`"order"`), `probability`, `confident` (whether `probability` reaches
`confidence`; when nothing does, the answer is the most likely species)
and `Taxon` (the key's result, for species-level answers).

## Details

The genus, family and order of each species come from GBIF (see
[`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)),
which needs an internet connection, or from a table you give in
`lineage`. Results with no lineage (for example ones named only by a
common name) count only as themselves.

## Examples

``` r
if (FALSE) { # \dontrun{
model <- visionModel(name = "bioclip-2")
identifyPhotos(montanaKey(), model, "my-tree.jpg", kingdom = "Plantae")
} # }
```
