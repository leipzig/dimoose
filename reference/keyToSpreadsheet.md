# Write a key as a spreadsheet

Writes a key as the CSV file that
[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
reads, so that a key imported from FishBase or generated from data can
be opened in Excel or Google Sheets, edited by hand and read back. The
columns are those of the Montana template: `Couplet`, `Choice`,
`Question`, `Description`, `Goes to`, `Species` and `Photo`, followed by
`Note` and `Label` when the key's leads have them (a pruned key has
notes, see
[`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md);
a PhyloTree key has labels).

## Usage

``` r
keyToSpreadsheet(key, file, photos = NULL, bom = TRUE)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- file:

  Path of the CSV file to write (UTF-8).

- photos:

  Folder to write the key's embedded photos into; by default the folder
  the CSV file is in. It is created if needed.

- bom:

  Start the file with a byte-order mark? Excel needs one to show
  accented and other non-English letters correctly when the file is
  opened by double-clicking; Google Sheets and
  [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
  read the file either way. Use `FALSE` for programs that do not expect
  one.

## Value

`file`, invisibly, so the result can go straight to
[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md).

## Details

Photos embedded in the key (see
[`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md))
are written as image files into `photos`, named by their ids, and the
`Photo` column names those files. A file of that name that is already
there with different contents is left alone and used as it is, so
writing a key back next to its original photos does not replace them
with the smaller embedded copies. Pictures a lead refers to by web
address stay web addresses.

Reading the file back gives the same leads and the same photo ids. The
exceptions are small: a photo id that cannot be a file name (it has a
`/`, `:`, comma or the like in it, or differs from another only by
capitals) is changed, with a message; a line break inside a cell comes
back as a plain line feed whatever it was; and leads without a `Choice`
are lettered.

A spreadsheet holds only those columns. Anything else in the key's leads
(for example the taxon links of a FishBase key, or the tests of a key a
machine can follow) is not written, and a message says which columns
were left out; the title and citation are not written either, so pass
`desc` and `meta` again to
[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md).

## See also

[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)

## Examples

``` r
dir <- tempfile("key")
dir.create(dir)
csv <- keyToSpreadsheet(montanaKey(), file.path(dir, "montana.csv"))
list.files(dir)
#>  [1] "acer_glabrum_leaf.jpg"           "acer_negundo_leaf.jpg"          
#>  [3] "betula_occidentalis_bark.jpg"    "betula_papyrifera_bark.jpg"     
#>  [5] "betula_papyrifera_leaf.jpg"      "feature_flat_petiole.jpg"       
#>  [7] "fraxinus_pennsylvanica_leaf.jpg" "montana.csv"                    
#>  [9] "populus_angustifolia_leaf.jpg"   "populus_deltoides_leaf.jpg"     
#> [11] "populus_tremuloides_bark.jpg"    "populus_trichocarpa_leaf.jpg"   
#> [13] "quercus_macrocarpa_acorn.jpg"    "quercus_macrocarpa_leaf.jpg"    
#> [15] "salix_amygdaloides_leaf.jpg"    
# ... edit the file in a spreadsheet program, then read it back
again <- keyFromSpreadsheet(csv, desc = "Montana trees, edited")
identical(again$leads$Character, montanaKey()$leads$Character)
#> [1] TRUE
```
