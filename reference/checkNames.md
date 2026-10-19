# Check a key's species names against GBIF

Looks up the scientific name of every result in the key in the [GBIF
Backbone
Taxonomy](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
and reports names that are misspelled, that are synonyms of a name GBIF
now accepts, or that GBIF does not know. A result written as
`"Common name (Genus species)"` is checked by the name in parentheses;
other results are checked when they look like a scientific name.

## Usage

``` r
checkNames(key, kingdom = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- kingdom:

  Optional kingdom ("Plantae", "Animalia", "Fungi", ...), which helps
  GBIF tell apart names that are used in more than one kingdom.

## Value

A data frame with one row per name checked: `Taxon` (as in the key),
`name` (the scientific name checked), `status` (`"ok"`, `"misspelled"`,
`"synonym"`, `"not found"`, or `"unchecked"` when GBIF could not be
reached), `gbif` (the name GBIF matched), `accepted` (the name GBIF
accepts for it), `genus`, `family` and `order` (from GBIF's
classification, used by
[`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md))
and `note` (what to fix, in words).

## Details

This needs an internet connection: one request to GBIF per name, and one
more for each synonym.

## See also

`keyFromSpreadsheet(checkNames = TRUE)`, which runs this check and
reports problems by spreadsheet row.

## Examples

``` r
# \donttest{
checkNames(montanaKey(), kingdom = "Plantae")
#>                                           Taxon                   name status
#> 1                      Box elder (Acer negundo)           Acer negundo     ok
#> 2            Green ash (Fraxinus pennsylvanica) Fraxinus pennsylvanica     ok
#> 3           Rocky Mountain maple (Acer glabrum)           Acer glabrum     ok
#> 4                  Bur oak (Quercus macrocarpa)     Quercus macrocarpa     ok
#> 5         Peachleaf willow (Salix amygdaloides)     Salix amygdaloides     ok
#> 6  Narrowleaf cottonwood (Populus angustifolia)   Populus angustifolia     ok
#> 7           Quaking aspen (Populus tremuloides)    Populus tremuloides     ok
#> 8         Plains cottonwood (Populus deltoides)      Populus deltoides     ok
#> 9        Black cottonwood (Populus trichocarpa)    Populus trichocarpa     ok
#> 10              Paper birch (Betula papyrifera)      Betula papyrifera     ok
#> 11            Water birch (Betula occidentalis)    Betula occidentalis     ok
#>                      gbif               accepted    genus      family
#> 1            Acer negundo           Acer negundo     Acer Sapindaceae
#> 2  Fraxinus pennsylvanica Fraxinus pennsylvanica Fraxinus    Oleaceae
#> 3            Acer glabrum           Acer glabrum     Acer Sapindaceae
#> 4      Quercus macrocarpa     Quercus macrocarpa  Quercus    Fagaceae
#> 5      Salix amygdaloides     Salix amygdaloides    Salix  Salicaceae
#> 6    Populus angustifolia   Populus angustifolia  Populus  Salicaceae
#> 7     Populus tremuloides    Populus tremuloides  Populus  Salicaceae
#> 8       Populus deltoides      Populus deltoides  Populus  Salicaceae
#> 9     Populus trichocarpa    Populus trichocarpa  Populus  Salicaceae
#> 10      Betula papyrifera      Betula papyrifera   Betula  Betulaceae
#> 11    Betula occidentalis    Betula occidentalis   Betula  Betulaceae
#>           order note
#> 1    Sapindales     
#> 2      Lamiales     
#> 3    Sapindales     
#> 4       Fagales     
#> 5  Malpighiales     
#> 6  Malpighiales     
#> 7  Malpighiales     
#> 8  Malpighiales     
#> 9  Malpighiales     
#> 10      Fagales     
#> 11      Fagales     
# }
```
