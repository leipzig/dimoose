# Export a key as Auspice (Nextstrain) JSON v2

Writes the key's spanning tree as an Auspice v2 dataset, which the
Nextstrain viewer and auspice.us can display. Node names are made unique
and space-free (required by the schema); the original labels and each
lead's text are kept in `node_attrs`. `div` is the depth from the root.

## Usage

``` r
toAuspiceJSON(key, title = NULL, file = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- title:

  Dataset title; defaults to the key's description.

- file:

  Optional path to write to; if `NULL`, the JSON is returned as a
  string.

## Value

The JSON string (invisibly if written to `file`).

## See also

[`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md),
[`toTreedata()`](https://leipzig.github.io/dimoose/reference/toTreedata.md)

## Examples

``` r
js <- toAuspiceJSON(phylotreeKey("H2a"))
```
