# Read and write Lucid matrix keys

Lucid (Identic / Lucidcentral) is a widely used commercial program for
interactive matrix keys: "entities" (taxa) scored for the states of
"features" (characters). `readLucid()` reads a key exported from the
Lucid Builder into a character matrix (see
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
for the convention) and `writeLucid()` writes a matrix in a form the
Builder imports.

## Usage

``` r
readLucid(
  file,
  format = NULL,
  taxon = "Taxon",
  sep = "/",
  inapplicable = NA,
  entities = c("columns", "rows"),
  scores = c(1, 2, 3),
  fullNames = FALSE
)

writeLucid(
  x,
  file,
  format = c("csv", "sdd"),
  characters = NULL,
  taxon = "Taxon",
  sep = "/",
  inapplicable = NULL,
  entities = c("columns", "rows"),
  title = NULL
)
```

## Arguments

- file:

  Path of the file to read or write.

- format:

  `"csv"`, `"sdd"` or (reading only) `"lif3"`; by default worked out
  from the file.

- taxon:

  Name of the taxon column of the matrix.

- sep:

  Separator between the states of a variable taxon in one cell.

- inapplicable:

  For readers, the cell value to give "not applicable" (default `NA`,
  the same as unknown). For writers, the cell value that means "not
  applicable" (default `NULL`: none).

- entities:

  For CSV: whether the entities (taxa) are the `"columns"` (Lucid's
  default) or the `"rows"` (its "transposed" export).

- scores:

  Which Lucid scores mean that the taxon has the state.

- fullNames:

  If `TRUE`, name characters and taxa by their whole path in Lucid's
  feature and entity trees (`"Flowers:Petals:Colour"`) rather than by
  the last step (`"Colour"`). Names that would be ambiguous are always
  given in full.

- x:

  A character matrix (data frame), or the list returned by
  `readLucid()`,
  [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
  [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md)
  or
  [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md).

- characters:

  Optional data frame describing the characters (`Character`, `Type`,
  `States`, `Unit`); see
  [`writeSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md).

- title:

  Title of the dataset (SDD only).

## Value

`readLucid()` returns a `tdwgData` list like
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md):
`matrix`, `characters` (`Character`, `Type`, `States`, `Unit`, `Path`),
`taxa` (`Taxon`, `Path`) and `meta`. `writeLucid()` returns `file`,
invisibly.

## Formats

Lucid has several export formats, and they are not equally well
documented:

- **`"csv"`** (Lucid Builder: *File \> Export Key* and *Import Key*,
  file type CSV). Documented in the Lucid Builder help, which also
  offers a small example key with its CSV export: the first row holds
  the entities, every further row one state named `Feature:State` (a
  colon-separated path through the feature tree), and the cells hold the
  scores 0 absent, 1 present, 2 rarely present, 3 uncertain, 4 present
  by misinterpretation, 5 rarely present by misinterpretation, 6 not
  scoped. A numeric feature is one row named `Feature#` with cells
  `score type:rare low:low:high:rare high`, or a plain `0` when it is
  not scored. This is the format `writeLucid()` writes by default, and
  the documented way to get a matrix **into** Lucid. Use
  `entities = "rows"` for the Builder's "transposed" variant.

- **`"sdd"`**: Lucid exports matrix keys as SDD, the TDWG standard; the
  file is read with
  [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
  and written with
  [`writeSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md).

- **`"lif3"`** (Lucid Interchange Format 3, `.lif3`): an XML file. Lucid
  publishes no schema or description of it beyond saying that it is XML,
  so `readLucid()` reads it as far as real exported files show how:
  features, states and entities (`<item>`), the feature and entity
  trees, and the multistate scores. This was checked against four
  published keys (Lucid 3 and Lucid 4 exports), one of which was also
  published as SDD: the two readings agree in all 3454 scores. Those
  files only use the scores 1 (present) and 3 (uncertain); the scores 2,
  4, 5 and 6 are taken to mean what they mean in CSV, as they do in the
  Builder's own key files, which store scores in the same elements. No
  real LIF3 file with numeric scores was found: they are read when they
  are laid out as in the Builder's own key files (`<scored_data>` with
  `omin`, `nmin`, `nmax`, `omax`), and otherwise left out with a
  warning. **Units, dependencies, text scores, subsets and media of a
  LIF3 file are not read** (a warning says so when the file has
  dependencies or text scores), and dimoose does not write LIF3; export
  CSV or SDD from the Builder when you need those.

- **LIF** (Lucid 2, `.lif`, a sectioned text file) and the Builder's
  **"XML Dataset"** are not publicly specified; `readLucid()` stops and
  asks for a CSV or SDD export instead of guessing.

## Scores

By default a taxon gets a state when it is scored present (1), rarely
present (2) or uncertain (3) for it; states scored only "by
misinterpretation" are left out, because the taxon does not really have
them. A feature for which every state of a taxon is uncertain, or
nothing is scored, gives `NA`; "not scoped" gives `inapplicable`.
`writeLucid()` writes 1 for every state in a cell and 0 otherwise, and 6
for cells equal to `inapplicable`.

For numeric features the Lucid help gives the layout of the cell but not
the values its score type can take. The one real export at hand uses 1
for a scored range and a plain `0` for a feature that is not scored, and
that is all `writeLucid()` writes: `1:rare low:low:high:rare high` for a
value or range, `0` for `NA`. A numeric cell equal to `inapplicable` is
also written as `0`, with a warning, because no score for "not scoped"
is documented for numeric features. On reading, type 1 gives the range,
0 gives `NA`, 6 is taken as "not scoped" by analogy with the multistate
scores, and any other type gives `NA` with a warning.

Text characters cannot be stored in a Lucid matrix and are left out with
a warning. Colons in names are replaced, because Lucid reads them as
steps of a path; data that was read from Lucid keeps its paths (the
`Path` columns of `characters` and `taxa`). Units of numeric features
are not part of the CSV format. No file written by dimoose has been
imported into the Lucid Builder.

## References

Lucid Builder help, "CSV (Comma Separated Value) Files" and "Importing
and Exporting", <https://help.lucidcentral.org/lucid/>.

## See also

[`readLucidKey()`](https://leipzig.github.io/dimoose/reference/readLucidKey.md)
for Lucid pathway (dichotomous) keys,
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
[`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md).

## Examples

``` r
f <- system.file("extdata", "tdwg", "bears-lucid.csv", package = "dimoose")
d <- readLucid(f)
d$matrix
#>                    Taxon      Colour Shoulder hump                Diet
#> 1           Ursus arctos       brown       present mixed/mostly plants
#> 2        Ursus maritimus       white        absent         mostly meat
#> 3       Ursus americanus brown/black        absent               mixed
#> 4 Ailuropoda melanoleuca white/black        absent       mostly plants
#>   Head and body length
#> 1    (1.4-)1.7-2.8(-3)
#> 2    (1.8-)2-2.5(-2.8)
#> 3        (1.2-)1.3-1.9
#> 4              1.2-1.9
d$characters
#>              Character        Type                          States Unit
#> 1               Colour categorical               white/brown/black     
#> 2        Shoulder hump categorical                  present/absent     
#> 3                 Diet categorical mostly meat/mixed/mostly plants     
#> 4 Head and body length        real                                     
#>                        Path
#> 1               Coat:Colour
#> 2             Shoulder hump
#> 3                      Diet
#> 4 Body:Head and body length

out <- writeLucid(d, tempfile(fileext = ".csv"))
readLines(out)
#>  [1] ",\"Ursidae:Ursus:Ursus arctos\",\"Ursidae:Ursus:Ursus maritimus\",\"Ursidae:Ursus:Ursus americanus\",\"Ursidae:Ailuropoda:Ailuropoda melanoleuca\""
#>  [2] "\"Coat:Colour:white\",0,1,0,1"                                                                                                                     
#>  [3] "\"Coat:Colour:brown\",1,0,1,0"                                                                                                                     
#>  [4] "\"Coat:Colour:black\",0,0,1,1"                                                                                                                     
#>  [5] "\"Shoulder hump:present\",1,0,0,0"                                                                                                                 
#>  [6] "\"Shoulder hump:absent\",0,1,1,1"                                                                                                                  
#>  [7] "\"Diet:mostly meat\",0,1,0,0"                                                                                                                      
#>  [8] "\"Diet:mixed\",1,0,1,0"                                                                                                                            
#>  [9] "\"Diet:mostly plants\",1,0,0,1"                                                                                                                    
#> [10] "\"Body:Head and body length#\",1:1.4:1.7:2.8:3,1:1.8:2:2.5:2.8,1:1.2:1.3:1.9:1.9,1:1.2:1.2:1.9:1.9"                                                
identical(readLucid(out)$matrix, d$matrix)
#> [1] TRUE
```
