# Build a key from a spreadsheet

Reads a key written in a spreadsheet and saved as CSV (in Excel or
Google Sheets: *File \> Save as / Download \> CSV*). Each row is one
lead:

## Usage

``` r
keyFromSpreadsheet(
  file,
  photos = NULL,
  desc = NA,
  meta = NULL,
  checkNames = FALSE
)
```

## Arguments

- file:

  Path of the CSV file (UTF-8).

- photos:

  Folder holding the photos named in the `Photo` column; by default the
  folder the CSV file is in.

- desc:

  Title of the key.

- meta:

  Optional key/value metadata data frame (e.g. a `citation` row); the
  photos are added to it.

- checkNames:

  If `TRUE`, check the species names against GBIF with
  [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)
  and warn, by spreadsheet row, about names that are misspelled,
  outdated synonyms or unknown. Needs an internet connection.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.

## Details

- `Couplet`: the couplet's number.

- `Description`: what the lead says ("Leaves compound.").

- `Goes to`: the couplet this lead leads to, or blank when the lead ends
  in a species.

- `Species`: the result, for leads that end the key. Write it as
  `"Common name (Genus species)"` to have
  [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  set the scientific name in italics.

- `Choice` (optional): the lead's letter; by default the leads of each
  couplet are lettered a, b, c in the order they appear (after z come
  aa, ab and so on).

- `Question` (optional): what the couplet asks ("Leaf type?"), shown by
  [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  and
  [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md).

- `Photo` (optional): file names of photos to show with the lead,
  separated by commas or semicolons; the extension may be left out. A
  web address (`https://...`) is kept as a link to the picture instead.

- `Note` and `Label` (optional): a remark on the lead, as
  [`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md)
  writes, and a label to show for the lead in place of couplet and
  letter. Both are kept in the key's leads as they are.

Column names are matched loosely (case, spaces and punctuation do not
matter) and dimoose's own names work too: `Statement`, `Character`,
`Next`, `Taxon` and `Image`. Other columns are ignored and blank rows
are skipped. The photos are embedded in the key, so the wizard and the
diagram work offline.

The file may be as Excel saves it: with or without a byte-order mark, in
UTF-8 or Windows-1252, and with semicolons between the cells, which is
what Excel writes where the comma is the decimal mark.

The Montana key that comes with dimoose is a ready-made example to copy:
`system.file("extdata", "montana", "montana-key.csv", package = "dimoose")`,
with its photos in the same folder.

## See also

[`keyToSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyToSpreadsheet.md)
to write a key as such a spreadsheet,
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)
to build a key from a data frame,
[`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
and
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
to show it.

## Examples

``` r
csv <- system.file("extdata", "montana", "montana-key.csv", package = "dimoose")
k <- keyFromSpreadsheet(csv, desc = "Native broadleaf trees of Montana")
k
#> <dimoose key> Native broadleaf trees of Montana
#>   10 couplets, 20 leads, 11 taxa, up to 7 steps deep (4.6 on average)
keyDiagram(k, tempfile(fileext = ".svg"))
```
