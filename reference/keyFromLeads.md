# Build a dimoose key from a table of leads

The common constructor behind
[`sharkKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
[`arachnidaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
[`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
and
[`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md):
takes one row per lead and returns a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## Usage

``` r
keyFromLeads(leads, desc = NA, meta = NULL, taxa = NULL, features = NULL)
```

## Arguments

- leads:

  Data frame with columns `Statement` (couplet), `Choice`, `Character`
  (the lead's text), `Next` (next couplet, or `"-"` if the lead ends in
  a result) and `Taxon` (the result, for terminal leads). Optional
  columns `Label`, `Image`, `ImageLink` and `TaxonUrl` are used by
  [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md);
  any others are kept.

- desc:

  Title or description of the key.

- meta:

  Key/value data frame of metadata (e.g. `citation`).

- taxa:

  Data frame of results with `submitted_name` and `matched_name`; by
  default every taxon matches itself.

- features:

  Optional
  [`featureTable()`](https://leipzig.github.io/dimoose/reference/featureTable.md)
  for keys a machine can follow (the leads then also carry `Feature`,
  `Test` and `Threshold`).

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## Examples

``` r
leads <- data.frame(
  Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
  Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
  Next = c("2", "-", "-", "-"), Taxon = c("", "Apterygota", "Diptera", "Other")
)
k <- keyFromLeads(leads, "A tiny key")
k
#> <dimoose key> A tiny key
#>   2 couplets, 4 leads, 3 taxa, up to 2 steps deep
k$toNewick()
#> [1] "((Diptera,Other)2,Apterygota)1;"
```
