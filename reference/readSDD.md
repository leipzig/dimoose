# Read and write SDD (TDWG Structured Descriptive Data)

SDD is the XML standard of TDWG (Biodiversity Information Standards) for
descriptive data: characters and their states, the taxa, and how each
taxon is coded for each character. `readSDD()` turns an SDD file into a
character matrix, `writeSDD()` writes one. Both follow SDD 1.1 (the
`http://rs.tdwg.org/UBIF/2006/` schema), which is what Lucid,
Xper2/Xper3 and DELTA tools export.

## Usage

``` r
readSDD(file, taxon = "Taxon", sep = "/", inapplicable = NA, dataset = NULL)

writeSDD(
  x,
  file,
  characters = NULL,
  taxon = "Taxon",
  title = NULL,
  sep = "/",
  inapplicable = NULL,
  lang = "en",
  key = NULL
)
```

## Arguments

- file:

  Path of the SDD file to read or write.

- taxon:

  Name of the taxon column of the matrix.

- sep:

  Separator between the states of a variable taxon in one cell.

- inapplicable:

  For readers, the cell value to give "not applicable" (default `NA`,
  the same as unknown). For writers, the cell value that means "not
  applicable" (default `NULL`: none).

- dataset:

  Which `<Dataset>` of the file to read, by position; by default the
  first one that has coded descriptions (or, for
  [`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md),
  identification keys).

- x:

  A character matrix (data frame), or the list returned by `readSDD()`,
  [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md),
  [`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
  or
  [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md).

- characters:

  Optional data frame describing the characters: a `Character` column
  matching the matrix's column names and any of `Type`, `States` (to fix
  the order of the states or list states no taxon has), `Unit`,
  `InapplicableIf` and `Cost`. By default taken from `x` if `x` is a
  reader's result; otherwise numeric columns are written as numeric
  characters and all others as categorical ones.

- title:

  Title of the dataset; by default the `title` in the metadata of `x`.

- lang:

  Language of the labels, as an `xml:lang` code.

- key:

  Optional
  [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
  to store in the same file as an SDD identification key (see
  [`writeSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md)).

## Value

`readSDD()` returns a list of class `tdwgData` with

- `matrix`: the character matrix;

- `characters`: one row per character with `Character` (the column
  name), `Type` (`"categorical"`, `"ordered"`, `"integer"`, `"real"` or
  `"text"`; SDD itself only tells categorical, real and text apart),
  `States` (all defined states, separated by `sep`), `Unit`,
  `InapplicableIf` (`"Other character=state/state"`: the character does
  not apply when the other character has one of these states; several
  rules are separated by `;`), `Cost` when the file has ratings, and
  `Id`;

- `taxa`: `Taxon`, `Detail` and `Id`;

- `meta`: key/value data frame (`title`, `description`, `language`,
  `authors`, `copyright`, `generator`, `created`, and `keys`, the number
  of identification keys in the file, see
  [`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md)).

`writeSDD()` returns `file`, invisibly.

## The character matrix

A plain data frame with one row per taxon, the taxon names in a column
(`Taxon` by default) and one column per character. Cells are text:

- a state name, or several separated by `sep` when the taxon is variable
  (`"red/yellow"`);

- for numeric characters a value or range written the way DELTA and
  floras write it: `"5"`, `"2.3-7.9"`, `"2.3-5.1-7.9"` (the middle value
  is the mean or median) and, with rare extremes, `"(1-)2-8(-12)"`;

- for text characters the text;

- `NA` when the character is unknown, not coded or not applicable (give
  `inapplicable` to tell "not applicable" apart).

## What is read from SDD

Categorical, quantitative and text characters, in the order of the
`<Characters>` list; the coded descriptions (`<SummaryData>`) of each
taxon; `<Status>` codes (`NotApplicable` becomes `inapplicable`, the
others `NA`); the dependency rules of the character tree
(`InapplicableIf`, `OnlyApplicableIf`); and observation-convenience
ratings, which become a `Cost` from 1 (easy) to 5. A taxon with several
descriptions gets one row, with the states of all of them. States scored
with a "misinterpretation" modifier (Lucid's way of catching a common
mistake) are not taken as states of the taxon, and states scored with
the modifier the Lucid Builder labels "unscoped" make the cell "not
applicable" (the Builder defines that modifier in every SDD file it
writes; none of the real exports dimoose was checked against uses it, so
how it is attached to a score is assumed to be the same as for the other
modifiers). Other modifiers (rarely, uncertain) are ignored and the
state kept, so a character whose states are all "uncertain" for a taxon
lists all of them. Dependency rules are read from the character itself
and from the groups of the character tree it sits in. Quantitative
measures map to the range text as follows: `Min`/`Max` are the ends of
the range, unless `UMethLower`/`UMethUpper` are given too, in which case
those are the normal range and `Min`/`Max` the extremes in parentheses;
`Mean` (or `Median`, `Mode`) is the middle value. Other statistics
(`SD`, `N`) are dropped.

Not read: sample data (`<SampleData>` of individual specimens), media,
natural-language descriptions, taxon hierarchies, and text in more than
one language (the first label of each object is used).

## What is written

A complete, schema-valid SDD 1.1 document with the taxon names, the
characters, a character tree holding the dependency rules, and one coded
description per taxon. `NA` cells are left out (SDD reads a missing
coding as unknown), cells equal to `inapplicable` get the status
`NotApplicable`. A `Cost` from 1 to 5 is written as an
observation-convenience rating, as Xper3 does. `"ordered"` characters
are written as categorical ones and `"integer"` as quantitative ones, so
those two types come back as `"categorical"` and `"real"`. Of a cell
listing several numeric ranges (`"5/10-15"`) the overall range is
written, and numbers are written as numbers (`"0.40"` comes back as
`"0.4"`). A categorical character for which no taxon has a state is
written as a text character, with a warning, because SDD does not allow
a categorical character without states. Files written from the real
datasets dimoose was tried on (DELTA, Lucid and Xper exports of up to
969 taxa) all validate against the SDD 1.1 schema; none has been
imported into Lucid or Xper.

## References

Hagedorn, G., Thiele, K., Morris, R. & Heidorn, P. B. (2005). Structured
Descriptive Data (SDD) w3c-xml-schema, version 1.0.
<https://www.tdwg.org/standards/sdd/>

## See also

[`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md)
for dichotomous keys stored in SDD,
[`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md),
[`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md),
[`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md).

## Examples

``` r
f <- system.file("extdata", "tdwg", "violets.sdd.xml", package = "dimoose")
d <- readSDD(f)
d
#> Character data "Four violets" (SDD) 
#>   4 taxa x 5 characters (3 categorical, 1 real, 1 text) 
#>   $matrix, $characters, $taxa, $meta
d$matrix
#>             Taxon Aerial stem       Flower colour     Stem hairs
#> 1   Viola odorata      absent        violet/white           <NA>
#> 2  Viola tricolor     present violet/white/yellow hairy/glabrous
#> 3   Viola biflora     present              yellow       glabrous
#> 4 Viola palustris      absent              violet           <NA>
#>     Flower length                         Notes
#> 1           13-15      Flowers strongly scented
#> 2 (10-)15-25(-30)                          <NA>
#> 3      12-13.5-15 Usually two flowers on a stem
#> 4            <NA>                          <NA>
d$characters[, c("Character", "Type", "States", "Unit")]
#>       Character        Type              States Unit
#> 1   Aerial stem categorical      present/absent     
#> 2 Flower colour categorical violet/white/yellow     
#> 3    Stem hairs categorical      hairy/glabrous     
#> 4 Flower length        real                       mm
#> 5         Notes        text                         

# write a matrix of your own
m <- data.frame(
  Taxon = c("Apis mellifera", "Bombus terrestris", "Vespula vulgaris"),
  Hair = c("sparse", "dense", "sparse/absent"),
  "Body length" = c("12-15", "(11-)14-17(-22)", NA),
  check.names = FALSE
)
chars <- data.frame(Character = "Body length", Type = "real", Unit = "mm")
out <- writeSDD(m, tempfile(fileext = ".xml"), characters = chars, title = "Three wasps and bees")
readSDD(out)$matrix
#>               Taxon          Hair     Body length
#> 1    Apis mellifera        sparse           12-15
#> 2 Bombus terrestris         dense (11-)14-17(-22)
#> 3  Vespula vulgaris sparse/absent            <NA>
```
