# Convert a key to an igraph directed graph

Unlike
[`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md)
and `toDataTree()`, which use a spanning tree, this keeps the key's true
structure: a couplet reached from several leads has several incoming
edges. Each edge carries the lead's `label` and `Character` text;
vertices are couplets and taxa.

## Usage

``` r
toIgraph(key)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

## Value

An
[igraph::igraph](https://r.igraph.org/reference/aaa-igraph-package.html)
directed graph.

## Examples

``` r
if (FALSE) { # \dontrun{
g <- toIgraph(arachnidaKey())
igraph::vcount(g)
} # }
```
