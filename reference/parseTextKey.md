# Parse a key written as plain text into a table of leads

The lower-level half of
[`keyFromText()`](https://leipzig.github.io/dimoose/reference/keyFromText.md):
reads the text and returns one row per lead together with everything
that looked wrong, without building a key. Use it to see what the parser
made of a difficult text, fix the text or the table, and then call
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md).

## Usage

``` r
parseTextKey(
  text,
  llm = NULL,
  strict = FALSE,
  layout = c("auto", "bracketed", "indented", "unnumbered"),
  skip = NULL
)
```

## Arguments

- text:

  The key: a file path, one string holding the whole key, or a character
  vector of lines. Give the key alone, without the descriptions before
  and after it.

- llm:

  Optional function for a first pass over messy text; see the section
  below.

- strict:

  If `TRUE`, stop when anything had to be repaired (see Details of
  [`keyFromText()`](https://leipzig.github.io/dimoose/reference/keyFromText.md))
  instead of repairing it. Problems that cannot be repaired are still
  returned in `problems`.

- layout:

  `"auto"` works out the layout from the text. `"indented"` always lets
  a lead without a destination lead to the couplet printed under it;
  `"bracketed"` never does. `"unnumbered"` reads the couplets from the
  indentation alone (or, without indentation, from the order of the
  leads) and takes no number at a line start for a couplet number.

- skip:

  Optional regular expression; lines that match are left out (for
  running heads the parser does not recognise by itself).

## Value

A list of class `textKeyParse` with

- `leads`: data frame with one row per lead: `Statement` (couplet),
  `Choice`, `Character` (the text), `Next` (next couplet, or `"-"`),
  `Taxon`, `Authority`, `CommonName`, `Page` and `Line` (the line the
  lead starts on). Ready for
  [`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md).

- `problems`: data frame with `Line`, `Couplet`, `Lead`, `Kind`
  (`"problem"`, `"repair"` or `"note"`), `Type` and `Message`.

- `title`: the first line above the first lead, or `NA`.

- `layout`: `"bracketed"`, `"indented"`, `"paired"` or `"unnumbered"`.

- `text`: the lines that were parsed (the model's answer when `llm`
  returned text).

When `llm` is used, `Line` is the line of the source text each lead was
found on (`NA` if it could not be found) and `leads$LlmLine` is the line
or row of the model's answer.

## See also

[`keyFromText()`](https://leipzig.github.io/dimoose/reference/keyFromText.md)

## Examples

``` r
# Primes for the second lead, tabs and "go to"
p <- parseTextKey(c(
  "1.  Shell coiled\tgo to 2",
  "1'. Shell of two valves\tBivalvia",
  "2.  Shell with a lid\tLittorina, p. 40",
  "2'. Shell without a lid\tLymnaea"
))
p$leads
#>   Statement Choice           Character Next     Taxon Authority CommonName Page
#> 1         1      a        Shell coiled    2                                    
#> 2         1      b Shell of two valves    -  Bivalvia                          
#> 3         2      a    Shell with a lid    - Littorina                        40
#> 4         2      b Shell without a lid    -   Lymnaea                          
#>   Line
#> 1    1
#> 2    2
#> 3    3
#> 4    4

# A scanned page: what was repaired and what was skipped
scan <- system.file("extdata", "textkeys", "meadow-ocr.txt", package = "dimoose")
p <- parseTextKey(scan)
p
#> <parsed text key> 8 leads in 4 couplets, bracketed layout
#>   Key to the Grasslike Plants of the Wet Meadow
#>   0 problem(s), 2 repair(s), 3 note(s)
#>   line 3: read the label 'l.' as couplet 1 [repaired]
#>   line 15: no dot leaders before the destination; took the trailing 'Scirpus microcarpus' as the taxon [repaired]
p$problems[p$problems$Kind == "repair", c("Line", "Message")]
#>   Line
#> 1    3
#> 2   15
#>                                                                                       Message
#> 1                                                            read the label 'l.' as couplet 1
#> 2 no dot leaders before the destination; took the trailing 'Scirpus microcarpus' as the taxon

# An indented key without couplet numbers, as in older floras
willows <- "
Capsule glabrous.
    Leaves with close serrations, glaucous beneath.  11. S. melanopsis.
    Leaves entire or with distant serrations.
        Styles none.  12. S. exigua.
        Styles evident; aments dense.  16. S. sessilifolia.
Capsule densely pubescent.  17. S. argophylla.
"
parseTextKey(willows)$leads[, c("Statement", "Choice", "Character", "Next", "Taxon")]
#>   Statement Choice                                       Character Next
#> 1         1      a                               Capsule glabrous.    2
#> 2         2      a Leaves with close serrations, glaucous beneath.    -
#> 3         2      b       Leaves entire or with distant serrations.    3
#> 4         3      a                                    Styles none.    -
#> 5         3      b                   Styles evident; aments dense.    -
#> 6         1      b                      Capsule densely pubescent.    -
#>             Taxon
#> 1                
#> 2   S. melanopsis
#> 3                
#> 4       S. exigua
#> 5 S. sessilifolia
#> 6   S. argophylla

# A stand-in for a language model that returns a table
fake <- function(text) {
  data.frame(
    couplet = c(1, 1), lead = c("a", "b"),
    text = c("Wings present", "Wings absent"),
    destination = c("Pterygota", "Apterygota")
  )
}
parseTextKey("1 Wings present ... Pterygota\n1 Wings absent ... Apterygota", llm = fake)$leads
#>   Statement Choice     Character Next      Taxon Authority CommonName Page Line
#> 1         1      a Wings present    -  Pterygota                              1
#> 2         1      b  Wings absent    - Apterygota                              2
#>   LlmLine
#> 1       1
#> 2       2
```
