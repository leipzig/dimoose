# Convert a key to a tidytree treedata (for ggtree)

Builds a `treedata` object whose tree is the key's spanning tree and
whose node data carries each lead's `Character`, `Choice` and `Taxon`.
The data of a child node describes the edge into it, so in ggtree you
draw lead text on branches with
`geom_label(aes(x = branch, label = Character))` and join your own data
by the `node` column (never by label, since taxa repeat).

## Usage

``` r
toTreedata(key)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

## Value

A [tidytree::treedata](https://rdrr.io/pkg/tidytree/man/treedata.html)
object.

## See also

[`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md),
[`toIgraph()`](https://leipzig.github.io/dimoose/reference/toIgraph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
td <- toTreedata(arachnidaKey())
library(ggtree)
ggtree(td) + geom_tiplab() + geom_label(aes(x = branch, label = Character))
} # }
```
