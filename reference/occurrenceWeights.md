# How common each taxon of a key is, from GBIF occurrence records

Counts the occurrence records [GBIF](https://www.gbif.org) holds for
each result of a key, optionally within a country or region. The counts
can be given to
[`keyQuality()`](https://leipzig.github.io/dimoose/reference/keyQuality.md)
or [`summary()`](https://rdrr.io/r/base/summary.html) as `weights`, to
see how many steps the key takes for the taxa people actually meet.

## Usage

``` r
occurrenceWeights(
  key,
  region = NULL,
  source = "gbif",
  fetch = qualGbifFetch,
  kingdom = NULL
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- region:

  Where to count: `NULL` for the whole world, a two-letter ISO country
  code (`"US"`), or a [GADM](https://gadm.org) id for a country, state
  or county (`"USA.27_1"` is Montana). Anything else is an error. GBIF
  answers 0 for a GADM id it does not have, so when no taxon has a
  record in the region a warning asks to check it.

- source:

  Where the counts come from; only `"gbif"` for now.

- fetch:

  The function that asks GBIF: called as `fetch(url, query)` with a
  named list of query parameters, it returns the parsed JSON answer as a
  list. Replace it to use cached answers or to test without a
  connection.

- kingdom:

  Optional kingdom ("Plantae", "Animalia", ...), which helps GBIF tell
  apart names that are used in more than one kingdom.

## Value

A numeric vector of record counts named by the key's results (as in its
`Taxon` column), `NA` for results that have no scientific name, that
GBIF does not know or cannot tell apart, or whose request failed (each
with a warning).

## Details

A result written as `"Common name (Genus species)"` is looked up by the
name in parentheses; other results by the result itself when it looks
like a scientific name, which includes genera and families (`"Salix"`,
`"Salix sp."` and `"Salix spp."` all count the genus) and names followed
by their author (`"Puma concolor (Linnaeus, 1771)"`). A result that
lists several taxa the key does not separate, written `"A / B"` as
[`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)
and
[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
write them, gets the sum of their counts. Each name is matched to the
GBIF Backbone Taxonomy, and the records of the name GBIF accepts for it
are counted, so a synonym gets the count of its accepted name. This
makes two requests to GBIF per name, one name at a time; after three
failed requests in a row the rest are not tried.

A name that GBIF knows in more than one kingdom (`"Morus"` is a mulberry
and a gannet) is not counted unless `kingdom` says which is meant.

Occurrence counts measure how often a taxon is recorded, which follows
how conspicuous and how popular with observers it is as well as how
common it is. A taxon with no records gets a weight of 0 and so does not
count towards the expected steps at all.

## See also

[`keyQuality()`](https://leipzig.github.io/dimoose/reference/keyQuality.md),
[`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)

## Examples

``` r
# canned answers in place of GBIF, to show the shape of `fetch`
counts <- c("Acer negundo" = 61000, "Fraxinus pennsylvanica" = 48000)
canned <- function(url, query) {
  if (grepl("species/match", url)) {
    list(usageKey = match(query$name, names(counts)), matchType = "EXACT")
  } else {
    list(count = unname(counts[query$taxonKey]))
  }
}
leads <- data.frame(
  Statement = "1", Choice = c("a", "b"), Character = c("Leaflets 3.", "Leaflets 5 to 7."),
  Next = "-", Taxon = c("Box elder (Acer negundo)", "Green ash (Fraxinus pennsylvanica)")
)
occurrenceWeights(keyFromLeads(leads), fetch = canned)
#>           Box elder (Acer negundo) Green ash (Fraxinus pennsylvanica) 
#>                              61000                              48000 
# \donttest{
k <- montanaKey()
w <- occurrenceWeights(k, region = "USA.27_1", kingdom = "Plantae")
w
#>                     Box elder (Acer negundo) 
#>                                          397 
#>           Green ash (Fraxinus pennsylvanica) 
#>                                          114 
#>          Rocky Mountain maple (Acer glabrum) 
#>                                         1194 
#>                 Bur oak (Quercus macrocarpa) 
#>                                           14 
#>        Peachleaf willow (Salix amygdaloides) 
#>                                          108 
#> Narrowleaf cottonwood (Populus angustifolia) 
#>                                          127 
#>          Quaking aspen (Populus tremuloides) 
#>                                          929 
#>        Plains cottonwood (Populus deltoides) 
#>                                          203 
#>       Black cottonwood (Populus trichocarpa) 
#>                                          247 
#>              Paper birch (Betula papyrifera) 
#>                                          140 
#>            Water birch (Betula occidentalis) 
#>                                          177 
summary(k, weights = w)
#>                                          title couplets leads taxa depth
#> 1 Key to the native broadleaf trees of Montana       10    20   11     7
#>   problems meanLeadSteps meanTaxonSteps expectedSteps    bound efficiency
#> 1        0      4.636364       4.636364      4.142466 2.826027   0.682209
# }
```
