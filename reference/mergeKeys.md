# Graft one key onto a result of another

Joins two keys end to end: the lead of `key` that ended in the taxon
`at` now leads to the first couplet of `subkey`. Use it to put a key to
the genera of one family under a key to families, or a regional key
under a general one.

## Usage

``` r
mergeKeys(key, subkey, at, labels = c("renumber", "prefix"), prefix = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- subkey:

  The [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key to graft onto it.

- at:

  The result of `key` that `subkey` continues from: its whole label, the
  scientific name in its parentheses or the common name before them
  (case does not matter). It is an error if no result, or more than one,
  has that name; a shared result is named in full (`"A / B"`).

- labels:

  How to keep couplet names unique. `"renumber"` numbers the couplets of
  the merged key 1, 2, 3, ... in reading order, so the subkey's couplets
  follow the lead they hang from. `"prefix"` keeps `key`'s couplet names
  and puts `prefix` in front of the subkey's.

- prefix:

  Text put in front of the subkey's couplet names with
  `labels = "prefix"`; by default the scientific name of `at` and a full
  stop (`"Salicaceae.1"`).

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.

## Details

The leads of the two keys are put in one table (a column that only one
of them has is left blank for the other), and so are their metadata,
embedded images, taxa and features. `key`'s title is kept; `subkey`'s
citation is added to `key`'s. If `at` is the result of several leads,
they all lead to the subkey. An embedded image or a feature that the two
keys both have under one id, with different contents, is kept apart by
giving the subkey's a new id (`_2` is added), with a warning for a
feature.

## See also

[`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md)

## Examples

``` r
families <- keyFromLeads(data.frame(
  Statement = c("1", "1"), Choice = c("a", "b"),
  Character = c("Fruit an acorn", "Fruit a capsule releasing cottony seeds"),
  Next = "-", Taxon = c("Fagaceae", "Salicaceae")
), "Two families of trees")
salicaceae <- keyFromLeads(data.frame(
  Statement = c("1", "1"), Choice = c("a", "b"),
  Character = c("Buds with one scale", "Buds with several scales"),
  Next = "-", Taxon = c("Salix", "Populus")
), "Genera of Salicaceae")
both <- mergeKeys(families, salicaceae, at = "Salicaceae")
both$leads
#>   Statement Choice                               Character Next    Taxon
#> 1         1      a                          Fruit an acorn    - Fagaceae
#> 2         1      b Fruit a capsule releasing cottony seeds    2         
#> 3         2      a                     Buds with one scale    -    Salix
#> 4         2      b                Buds with several scales    -  Populus
mergeKeys(families, salicaceae, at = "Salicaceae", labels = "prefix")$leads$Statement
#> [1] "1"            "1"            "Salicaceae.1" "Salicaceae.1"
```
