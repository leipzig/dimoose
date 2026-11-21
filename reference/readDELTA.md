# Read and write DELTA datasets

DELTA (DEscription Language for TAxonomy, Dallwitz 1980) is the oldest
and still widely used text format for descriptive data, and a TDWG
standard. A dataset is classically three files: `specs` (how many
characters there are and of which type), `chars` (the character list
with the states) and `items` (the taxa, each with its attributes).
`readDELTA()` reads them into a character matrix (see
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
for the convention), `writeDELTA()` writes a matrix as the three files.

## Usage

``` r
readDELTA(
  specs,
  chars = NULL,
  items = NULL,
  taxon = "Taxon",
  sep = "/",
  inapplicable = NA,
  comments = FALSE
)

writeDELTA(
  x,
  dir,
  characters = NULL,
  taxon = "Taxon",
  sep = "/",
  inapplicable = NULL,
  title = NULL,
  files = c(specs = "specs", chars = "chars", items = "items")
)
```

## Arguments

- specs:

  Path of the `specs` file, or of a folder holding files named `specs`,
  `chars` and `items` (any extension, any case).

- chars, items:

  Paths of the `chars` and `items` files. May be left out when `specs`
  is a folder, or a single file holding everything.

- taxon:

  Name of the taxon column of the matrix.

- sep:

  Separator between the states of a variable taxon in one cell.

- inapplicable:

  For readers, the cell value to give "not applicable" (default `NA`,
  the same as unknown). For writers, the cell value that means "not
  applicable" (default `NULL`: none).

- comments:

  If `TRUE`, keep the comments in the names of characters, states and
  taxa (`"pronotum <colour>"`).

- x:

  A character matrix (data frame), or the list returned by
  `readDELTA()`,
  [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
  [`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
  or
  [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md).

- dir:

  Folder to write the three files into; created if needed.

- characters:

  Optional data frame describing the characters (`Character`, `Type`,
  `States`, `Unit`, `InapplicableIf`); see
  [`writeSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md).

- title:

  Title put in the `*SHOW` line of each file.

- files:

  Names of the three files.

## Value

`readDELTA()` returns a `tdwgData` list like
[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
with `matrix`, `characters` (`Character`, `Type`, `States`, `Unit`,
`InapplicableIf`, `Number`), `taxa` (`Taxon`, `Comment`) and `meta`.
`writeDELTA()` returns the paths of the three files, invisibly.

## What is read

The directives `*CHARACTER LIST`, `*ITEM DESCRIPTIONS`,
`*CHARACTER TYPES`, `*NUMBERS OF STATES`, `*NUMBER OF CHARACTERS`,
`*IMPLICIT VALUES` and `*DEPENDENT CHARACTERS`, wherever in the given
files they are (so a dataset kept in one file, or split differently,
reads too); other directives are skipped. Character types are unordered
multistate (`UM`, read as `"categorical"`), ordered multistate (`OM`,
`"ordered"`), integer (`IN`, `"integer"`), real (`RN`, `"real"`) and
text (`TE`, `"text"`).

Attributes follow the DELTA standard: `12,1/2` (state 1 or 2) and
`12,1&2` (1 and 2) both give `"state 1/state 2"`, so the difference
between "or" and "and" is not kept; `13,2-3` is a range, which for an
ordered character includes the states in between; `14,U` is unknown
(`NA`), `15,-` not applicable (`inapplicable`), `16,V` variable (all
states). Numeric values are kept as written, e.g. `"7-8.5"` or
`"(1-)2-3(-4)"`, which is the numeric notation of the matrix convention.
For a text character the cell is the text of the comment
(`7<possibly two species>`). Implicit values are filled in. A dependent
character that is not coded is "not applicable" when its controlling
character only takes the controlling states; the rule itself is kept in
the `InapplicableIf` column of `characters`. Variant items (`#+`) take
the attributes they leave out from their main item, as the standard
says.

Comments (text in angle brackets) are dropped from the names of
characters, states and taxa unless `comments = TRUE`, and from the
attributes of non-text characters; the comment of a taxon name (usually
the authority) is kept in `taxa$Comment`. A name that consists of
nothing but a comment (`#4. <longevity of plants>/`) is that comment.
Typesetting marks (the RTF control words DELTA programs use, such as
`\i{}`, `\b0{}` or `\par{}`) are removed, and those that stand for a
character (`\endash{}`, `\ldblquote{}`) become that character. Files
that are not valid UTF-8 are read as Windows-1252. The obsolete line
sequence numbers are not supported.

The reader was checked against the datasets distributed with Open DELTA
(among them the "Grass Genera" sample, a flora of 506 taxa and a virus
database of 969 taxa) by comparing every coded attribute with a second,
independent parse of the files.

## What is written

`specs` gets the numbers of characters, states and items, the character
types, the numbers of states and the dependent characters; `chars` the
character list; `items` one item per taxon. Every coded cell is written
out (no implicit values are used), `NA` cells are left out, which DELTA
reads as unknown, and cells equal to `inapplicable` are written as `-`.
The states of a variable taxon are joined with `/` ("or"). A numeric
cell that is not a DELTA number or range, and all cells of text
characters, are written as comments. Encoding is UTF-8, and lines are
wrapped at 78 columns wherever they have a blank to break at.

A few things cannot be written as they are, because DELTA would read
them as syntax: angle brackets in a name make a comment (which
`readDELTA()` drops unless `comments = TRUE`); a star or, in a name, a
numero after a blank is put in parentheses (`(*)`, `(#)`); the blank
after a slash in a name is dropped. No file written by dimoose has been
read into a DELTA program (Confor, Intkey, Open DELTA).

## References

Dallwitz, M. J. & Paine, T. A. (1992 onwards). Definition of the DELTA
format. <https://www.delta-intkey.com/www/standard.htm>

## See also

[`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
[`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md).

## Examples

``` r
dir <- system.file("extdata", "tdwg", "beetles-delta", package = "dimoose")
d <- readDELTA(dir)
d
#> Character data "Three beetles" (DELTA) 
#>   3 taxa x 7 characters (3 categorical, 1 ordered, 1 integer, 1 real, 1 text) 
#>   $matrix, $characters, $taxa, $meta
d$matrix
#>                 Taxon antennal club     pronotum           eyes
#> 1 Aphodius exemplaris       present black/yellow of normal size
#> 2      Carabus fictus        absent    red/black     very large
#> 3 Lucanus imaginarius       present        black of normal size
#>                                                                                   frons
#> 1 with setae on anterior middle and above eyes/with setae above eyes only/without setae
#> 2                                                                         without setae
#> 3                                                                                  <NA>
#>   number of lamellae in antennal club     length             comments
#> 1                                   3  (4-)5-6.5       common in dung
#> 2                                <NA>      22-28                 <NA>
#> 3                                 4-6 30-45(-60) possibly two species
d$characters[, c("Character", "Type", "States", "Unit")]
#>                             Character        Type
#> 1                       antennal club categorical
#> 2                            pronotum categorical
#> 3                                eyes categorical
#> 4                               frons     ordered
#> 5 number of lamellae in antennal club     integer
#> 6                              length        real
#> 7                            comments        text
#>                                                                                  States
#> 1                                                                        present/absent
#> 2                                                                      red/black/yellow
#> 3                                                             of normal size/very large
#> 4 with setae on anterior middle and above eyes/with setae above eyes only/without setae
#> 5                                                                                      
#> 6                                                                                      
#> 7                                                                                      
#>   Unit
#> 1     
#> 2     
#> 3     
#> 4     
#> 5     
#> 6   mm
#> 7     

out <- writeDELTA(d, tempfile("delta"))
out
#>                                     specs 
#> "/tmp/RtmpLC0PLY/delta1cae24ef4577/specs" 
#>                                     chars 
#> "/tmp/RtmpLC0PLY/delta1cae24ef4577/chars" 
#>                                     items 
#> "/tmp/RtmpLC0PLY/delta1cae24ef4577/items" 
identical(readDELTA(dirname(out[1]))$matrix, d$matrix)
#> [1] TRUE
```
