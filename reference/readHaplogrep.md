# Read a Haplogrep / PhyloTree tree XML

Parses the nested `<haplogroup>` XML that Haplogrep distributes (for
example `phylotree-rcrs-17`'s `tree.xml`) into the same data frame shape
as
[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
so any Haplogrep tree can be loaded, not just the bundled snapshot. Each
haplogroup's `<details><poly>` entries become its mutations.

## Usage

``` r
readHaplogrep(file, key = FALSE)
```

## Arguments

- file:

  Path to the tree XML.

- key:

  If `TRUE`, return a
  [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
  built with
  [`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)
  instead of the data frame.

## Value

A data frame with `haplogroup`, `parent`, `depth`, `n_subclades` and
`mutations`, or a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) object
if `key = TRUE`.

## See also

[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
[`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tree <- readHaplogrep("tree.xml")
} # }
```
