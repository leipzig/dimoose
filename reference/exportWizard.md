# Export an interactive dichotomous key

Writes a dimoose key as a single self-contained HTML page. With
JavaScript on, the page steps through the key one couplet at a time,
keeps a trail of the choices made (each one clickable to go back to it)
and supports the browser's Back button. Without JavaScript, the same
page is the full key with every lead hyperlinked to its next couplet or
taxon. Each taxon gets a result section listing the characters on its
path, and a map of the key shows where the user is (see `map`).

## Usage

``` r
exportWizard(
  key,
  file = NULL,
  displayLinks = TRUE,
  order = c("original", "parsimony"),
  title = NULL,
  map = TRUE,
  staticPaths = NULL
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  object, e.g. from
  [`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md).

- file:

  Path of the HTML file to write. If `NULL`, the HTML is returned as a
  string instead.

- displayLinks:

  If `TRUE`, show the couplet numbers each lead leads to and comes from,
  as in a printed key. If `FALSE`, hide them. Leads stay clickable
  either way.

- order:

  Order of couplets. Only `"original"` (the key's own order) is
  implemented.

- title:

  Page title. Defaults to the key's description.

- map:

  If `TRUE`, include a map of the key: the whole key drawn as a tree,
  marking the current couplet, the path taken so far and the branches
  (and number of taxa) still possible. It sits beside the key on wide
  screens and behind a Map button on phones.

- staticPaths:

  If `TRUE`, write each taxon's path through the key into the page, so
  it shows without JavaScript. If `FALSE`, the page builds the path in
  the browser when a result is shown, which keeps large keys (such as
  [`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)
  on the whole tree) much smaller. The default is `TRUE` for keys with
  up to 1,000 taxa.

## Value

The path to `file`, invisibly, or the HTML as a character string if
`file` is `NULL`.

## Details

The key is checked first: leads pointing at missing couplets, terminal
leads without a taxon, couplets with fewer than two leads and couplets
that cannot be reached from the first one are reported as warnings and
marked in the page.

## Examples

``` r
if (FALSE) { # \dontrun{
sharks <- importFishbase(1, usePhyloService = "none")
exportWizard(sharks, "sharks.html")
} # }
```
