# A key to the taxa recorded in a place

Asks [GBIF](https://www.gbif.org) or
[iNaturalist](https://www.inaturalist.org) which of the key's taxa have
been recorded in a place and prunes the key to those with
[`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md):
the key to the trees of Flathead County from a key to the trees of
Montana, in one line.

## Usage

``` r
regionalKey(
  key,
  place,
  source = c("gbif", "inat"),
  minRecords = 1,
  kingdom = NULL,
  unknown = c("keep", "drop"),
  filters = list(),
  ...,
  fetch = prnFetch
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- place:

  The place; see the section for the source used.

- source:

  `"gbif"` or `"inat"`.

- minRecords:

  Keep a taxon with at least this many records.

- kingdom:

  For GBIF, the kingdom of the key's taxa (`"Plantae"`, `"Animalia"`,
  ...), which tells apart names used in more than one. For iNaturalist,
  the name or numeric id of any taxon that contains all the key's taxa
  (`"Plantae"`, `"Aves"`).

- unknown:

  What to do with results the source does not know by name (such as
  `"Other"`): `"keep"` them, with a warning, or `"drop"` them.

- filters:

  Named list of further search parameters for the count: for GBIF,
  occurrence search parameters such as
  `list(basisOfRecord = "HUMAN_OBSERVATION", year = "2000,2025")`; for
  iNaturalist, observation search parameters such as
  `list(quality_grade = "any")`.

- ...:

  Passed to
  [`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md):
  `note` and `renumber`.

- fetch:

  Function that makes a request: called as `fetch(url, query)` with
  `query` a named list, it returns the parsed JSON as nested lists.
  Replace it to cache or log requests, or to test without a network. The
  default asks a busy or unreachable server up to three times.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key,
pruned. Its attribute `"records"` (`attr(x, "records")`) is a data frame
with a row for every taxon of the original key: `Taxon`, `name` (the
name looked up), `matched` (the name the source counted it under), `id`
(the source's id for that), `records` (`NA` when the source does not
know the name) and `kept`. The attribute `"place"` says which place was
used. When every taxon is kept the key is returned unpruned. It is an
error if the source knows none of the key's taxa by name, or if fewer
than two taxa are left.

## Details

Each result of the key is looked up by the scientific name in its
parentheses (`"Bur oak (Quercus macrocarpa)"`), or by the whole result
when there is none; the taxa of a shared result (`"A / B"`) are looked
up one by one, and the result keeps those that are recorded. The key's
names need not be the source's: a synonym is counted under the name the
source accepts for it, and the result keeps the key's own label. Results
at any rank work: a genus or a family counts the records of all its
species.

The sources are asked one taxon at a time, so a key of 70 taxa takes
about 150 requests of GBIF (about half a minute). If a request fails, it
is an error that says which taxon was being asked about, and nothing is
pruned.

## GBIF

Each name is matched to the GBIF Backbone (`/v1/species/match`) and its
occurrences in the place are counted (`/v1/occurrence/search` with
`limit=0`), two requests per taxon. A synonym is counted under its
accepted name, and a species that GBIF files under one of its subspecies
is counted as the species. A name GBIF has in more than one kingdom is
settled by `kingdom`, or, for a genus, by taking the accepted genus.
Only records with `occurrenceStatus=PRESENT` are counted. `place` can be

- a [GADM](https://gadm.org) id, such as `"USA.27.15_1"` for Flathead
  County, Montana, or `"USA.27_1"` for Montana (`gadmGid`);

- a two-letter country code, such as `"CH"` (`country`);

- a polygon in WKT, `"POLYGON((...))"`, with its points anticlockwise
  (`geometry`);

- a named list of GBIF occurrence search parameters, used as they are,
  such as `list(country = "US", stateProvince = "Montana")`;

- the name of a region, looked up in GADM (`/v1/geocode/gadm/search`).
  Add the regions it lies in after commas to tell places of the same
  name apart: `"Flathead County, Montana"`, `"Flathead County, MT"`,
  `"Montana, USA"`. A name that still fits several regions, or none, is
  an error that lists the regions GADM has with their ids; give the id
  of the one you mean. The message printed at the end names the region
  used.

## iNaturalist

The place is found with `/v1/places/autocomplete` (or give its numeric
id). Parts after commas pick among places of one name
(`"Lake County, MT"`). When several places match, the one of exactly
that name is used (if there are several, a country or state before a
county or a park, then the largest), and a message names it and lists
the others with their ids, so that you can give the id of another. The
species observed in the place are listed with
`/v1/observations/species_counts`, 500 a page, counting research-grade
observations only. A result of the key is counted by name when a listed
species has that name; otherwise it is looked up with `/v1/taxa` (which
also finds synonyms) and counts every listed species below it, or, for a
subspecies or variety, its own observations. Give `kingdom` to list only
that group's species, which saves pages. When the list would take more
requests than asking about each taxon (a whole country, with no
`kingdom`), a message says so and each taxon's observations in the place
are counted with two requests instead. Requests made by the default
`fetch` are a second apart, as iNaturalist asks.

## Examples

``` r
# \donttest{
flathead <- regionalKey(montanaKey(), "USA.27.15_1", kingdom = "Plantae")
#> Kept 10 of 11 taxa recorded in GADM region USA.27.15_1 (GBIF)
flathead
#> <dimoose key> Key to the native broadleaf trees of Montana
#>   9 couplets, 18 leads, 10 taxa, up to 6 steps deep (4.1 on average)
attr(flathead, "records")
#>                                           Taxon                   name
#> 1                      Box elder (Acer negundo)           Acer negundo
#> 2            Green ash (Fraxinus pennsylvanica) Fraxinus pennsylvanica
#> 3           Rocky Mountain maple (Acer glabrum)           Acer glabrum
#> 4                  Bur oak (Quercus macrocarpa)     Quercus macrocarpa
#> 5         Peachleaf willow (Salix amygdaloides)     Salix amygdaloides
#> 6  Narrowleaf cottonwood (Populus angustifolia)   Populus angustifolia
#> 7           Quaking aspen (Populus tremuloides)    Populus tremuloides
#> 8         Plains cottonwood (Populus deltoides)      Populus deltoides
#> 9        Black cottonwood (Populus trichocarpa)    Populus trichocarpa
#> 10              Paper birch (Betula papyrifera)      Betula papyrifera
#> 11            Water birch (Betula occidentalis)    Betula occidentalis
#>                   matched      id records  kept
#> 1            Acer negundo 3189866      11  TRUE
#> 2  Fraxinus pennsylvanica 3172348       1  TRUE
#> 3            Acer glabrum 3189864     274  TRUE
#> 4      Quercus macrocarpa 2878213       0 FALSE
#> 5      Salix amygdaloides 5372892       4  TRUE
#> 6    Populus angustifolia 3040196       7  TRUE
#> 7     Populus tremuloides 3040215      93  TRUE
#> 8       Populus deltoides 3040232       1  TRUE
#> 9     Populus trichocarpa 6362904      56  TRUE
#> 10      Betula papyrifera 5332120      70  TRUE
#> 11    Betula occidentalis 5332055      13  TRUE

regionalKey(montanaKey(), "Flathead County", source = "inat", kingdom = "Plantae")
#> Kept 7 of 11 taxa recorded in Flathead County, US, MT (iNaturalist place 2379) (iNaturalist)
#> <dimoose key> Key to the native broadleaf trees of Montana
#>   6 couplets, 12 leads, 7 taxa, up to 6 steps deep (3.9 on average)
# }
```
