# Read a key written as plain text

Most identification keys exist only as printed text: floras, monographs,
scans in the Biodiversity Heritage Library. `keyFromText()` reads such a
key, one lead at a time (couplet, lead, text and destination), builds a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
with
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)
and checks it with `$validate()`.
[`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md)
is the lower-level half that returns the lead table and the list of
problems without building the key.

## Usage

``` r
keyFromText(text, desc = NA, meta = NULL, llm = NULL, strict = FALSE, ...)
```

## Arguments

- text:

  The key: a file path, one string holding the whole key, or a character
  vector of lines. Give the key alone, without the descriptions before
  and after it.

- desc:

  Title of the key. By default the first line above the first lead is
  used, if there is one.

- meta:

  Key/value data frame of metadata (e.g. `citation`), passed to
  [`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md).

- llm:

  Optional function for a first pass over messy text; see the section
  below.

- strict:

  If `TRUE`, stop when anything had to be repaired or any problem was
  found, instead of warning.

- ...:

  Further arguments for
  [`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md)
  (`layout`, `skip`).

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.
`attr(key, "problems")` is a data frame of problems, repairs and notes
(see
[`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md)).

## Details

Layouts that are recognised:

- Bracketed keys, where the leads of a couplet stand together:
  `1a.`/`1b.`, `1.`/`1'.` (primes), `1.`/`1.`, `1`/`-` (a dash for the
  second lead), `1(a)`/`1(b)`, `(1)`/`(1)`, Roman numerals `II.`,
  `A.`/`AA.` or `a.`/`aa.` lettering, and labels with a back-reference
  such as `3(1).` (couplet 3, reached from couplet 1). The second lead
  may also be marked `+`, or carry no label at all: a new paragraph, as
  in many older entomological keys, or a line of its own with dot
  leaders under a complete lead.

- Indented (yoked) keys, where the second lead of a couplet comes much
  later and a lead without a destination leads to the couplet printed
  under it.

- Indented keys without any couplet numbers, as in most older floras:
  the leads of a couplet share an indent, and a lead ends in a name,
  often with its number in the flora
  (`... long-acuminate. 1. S. nigra.`). The couplets are made from the
  indentation and numbered in order. Plain OCR text usually loses the
  indentation. The couplets are then worked out from the order of the
  leads, which works when every couplet has exactly two leads: a lead
  without a name opens the next couplet, a lead with a name is followed
  by the second lead of the nearest couplet still lacking one. This is
  reported as a repair; if the leads do not pair off, the key is refused
  with the line where the pairing breaks. One key at a time: a second
  heading in the text stops the reading there.

- Paired keys, where every lead has its own number and names its
  alternative in parentheses (`1 (8) ...` and further down `8 (1) ...`).
  The two are put together as one couplet, named after the lower number.

- Couplets with three or more leads, and couplets reached from several
  leads.

The destination is whatever follows dot leaders, a tab, a run of three
or more spaces, a colon before a number (`lobed: 5`) or a spaced dash
(`a large tree -- Quercus alba`): a couplet number (also `go to 5`,
`see 5`, `(5)`, `> 5`) or a taxon. A taxon may carry an authority, a
common name (in parentheses, or in front of the scientific name) and a
page number (`Salix, p. 212`, `HEMIPTERA (Page 76)`, `Culicidae, 96`);
the genus may be abbreviated (`S. alba L.`). These go to the
`Authority`, `CommonName` and `Page` columns of the lead table. A number
in parentheses after a name (`Pinus. (7).`) is taken for its page or
list number, not for a couplet. Lead text may wrap over several lines,
with the destination on the last one; words hyphenated at a line end are
joined, and blank lines, page numbers, running heads and figure captions
in between are skipped, as are footnotes. Text in two columns side by
side (as `pdftotext -layout` gives it) is read column by column; this is
reported as a repair. Markdown emphasis and tables are read as plain
text.

Scanned text is repaired where that is safe: `l`, `I` or `|` read as 1
and `O` as 0 in couplet numbers, labels that lost their full stop,
labels garbled beyond reading where only one couplet can be meant (`V0.`
between 9 and 11), and destinations that lost their dot leaders
(`... each year. 11.`, `... leaves flat. Abies.`). Text with two or more
spaces between all words, as many scans have, is recognised, and only
clearly wider gaps count as gaps there. Every repair is reported, and
with `strict = TRUE` the function stops instead of repairing.

Nothing is dropped silently. A lead without a destination, a couplet
with one lead, a destination couplet that does not exist, a destination
that is probably a broken number (`S` for 5), a jump in the couplet
numbers, a label that stands alone on its line, text that looks like a
lead without a label and similar faults are reported with the line they
are on. `keyFromText()` gives one warning that lists them and attaches
the full table to the key as `attr(key, "problems")`. Text that was
passed over (running heads, descriptions between leads) is listed there
as notes.

What a scan has lost cannot be put back: a couplet number misread as
another number that also exists in the key gives a wrong link without a
warning, and leads whose labels the scan put in a column of their own
are reported as lost, not recovered. Check a key read from a scan
against the page. Not handled: keys without numbers that are not
indented and have couplets of three or more leads, keys that mix letters
and unnumbered leads (Gray's Manual), keys divided by section headings
that stand for leads (`A.`, `*`, `**` in Britton & Brown), and text in
more than two columns.

## A first pass by a language model

For badly scanned keys, `llm` can be a function that takes the whole
text as one string and returns either cleaned-up key text (one lead per
line, in any layout above), a data frame with columns `couplet`, `lead`,
`text` and `destination`, or the same as JSON (an array of leads; needs
the jsonlite package). Markdown code fences around the answer are taken
off. You write that function; dimoose calls no model or API itself. What
comes back is not trusted: it goes through the same checks, and each
lead is compared with the source, so a lead whose words or taxon do not
occur in the source, a destination that is not on the lines of its lead
in the source (two names swapped, a lead sent to another couplet), or a
lead the model left out, is reported with the line of the source it
belongs to (a lead that is not in the source at all has no such line;
the message then names the line or row of the model's answer). The title
is taken from the source, not from the answer. An answer that cannot be
read (cut-off JSON, prose without leads, an empty table) is an error;
nothing is taken from it.

## See also

[`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md),
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)

## Examples

``` r
# A bracketed key with dot leaders, wrapped leads and authorities
file <- system.file("extdata", "textkeys", "trees-bracketed.txt", package = "dimoose")
cat(readLines(file, n = 8), sep = "\n")
#> Key to the Broadleaf Trees of the Cottonwood Bottoms
#> 
#> 1a. Leaves opposite on the twig ........................................ 2
#> 1b. Leaves alternate on the twig ....................................... 4
#> 2a. Leaves simple, palmately lobed, the lobes sharply
#>     toothed ................... Acer glabrum Torr. (Rocky Mountain maple)
#> 2b. Leaves pinnately compound .......................................... 3
#> 3a. Leaflets 3 to 5, coarsely toothed or shallowly lobed; fruit a
trees <- keyFromText(file)
trees
#> <dimoose key> Key to the Broadleaf Trees of the Cottonwood Bottoms
#>   8 couplets, 16 leads, 9 taxa, up to 5 steps deep (3.6 on average)
trees$leads[, c("Statement", "Choice", "Next", "Taxon", "CommonName")]
#>    Statement Choice Next                                  Taxon
#> 1          1      a    2                                       
#> 2          1      b    4                                       
#> 3          2      a    -                           Acer glabrum
#> 4          2      b    3                                       
#> 5          3      a    -                           Acer negundo
#> 6          3      b    -                 Fraxinus pennsylvanica
#> 7          4      a    -                                  Salix
#> 8          4      b    5                                       
#> 9          5      a    6                                       
#> 10         5      b    7                                       
#> 11         6      a    -                      Betula papyrifera
#> 12         6      b    -                    Betula occidentalis
#> 13         7      a    -                    Populus tremuloides
#> 14         7      b    8                                       
#> 15         8      a    -                   Populus angustifolia
#> 16         8      b    - Populus balsamifera subsp. trichocarpa
#>               CommonName
#> 1                       
#> 2                       
#> 3   Rocky Mountain maple
#> 4                       
#> 5               boxelder
#> 6                       
#> 7                       
#> 8                       
#> 9                       
#> 10                      
#> 11           paper birch
#> 12           water birch
#> 13         quaking aspen
#> 14                      
#> 15 narrowleaf cottonwood
#> 16      black cottonwood

# An indented key, given as a string
conifers <- keyFromText(system.file("extdata", "textkeys", "conifers-indented.txt",
  package = "dimoose"))
conifers$toNewick()
#> [1] "(('Juniperus communis','Juniperus scopulorum')2,(('Pinus contorta','Pinus ponderosa',('Pinus flexilis','Pinus albicaulis')5)4,('Larix occidentalis',('Picea engelmannii',('Pseudotsuga menziesii','Abies lasiocarpa')8)7)6)3)1;"

# Problems are reported with their line and attached to the key
broken <- "1a. Wings present .... 2
1b. Wings absent .... Apterygota
2a. Two wings .... Diptera
2b. Four wings"
k <- suppressWarnings(keyFromText(broken, "Insects"))
attr(k, "problems")[, c("Line", "Lead", "Kind", "Message")]
#>   Line Lead    Kind
#> 1    4   2b problem
#>                                                           Message
#> 1 lead 2b has no destination (no couplet or taxon after the text)

if (FALSE) { # \dontrun{
# A first pass by a language model. Any function(text) will do; this one
# calls a chat API and asks for one lead per line.
askModel <- function(text) {
  prompt <- paste(
    "This is a scanned identification key. Rewrite it with one lead per",
    "line as '<couplet><letter>. <text> .... <destination>'. Do not add,",
    "drop or reword leads.\n\n", text
  )
  response <- httr::POST(
    "https://api.example.com/v1/messages",
    httr::add_headers(Authorization = paste("Bearer", Sys.getenv("MODEL_API_KEY"))),
    body = list(model = "some-model", messages = list(list(role = "user", content = prompt))),
    encode = "json"
  )
  httr::content(response)$content[[1]]$text
}
key <- keyFromText("scanned-key.txt", llm = askModel)
attr(key, "problems")
} # }
```
