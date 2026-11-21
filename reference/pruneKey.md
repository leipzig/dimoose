# Prune a key to some of its taxa

Keeps only the taxa you name (or removes the ones you name) and tidies
up what is left: leads that no longer reach any kept taxon are removed,
and a couplet that no longer splits anything is taken out, with the lead
that led to it now leading straight to where its one remaining lead
went. Collapses are repeated until every couplet again has at least two
leads going to different places, so chains of couplets, couplets reached
from several leads and the first couplet of the key are all handled.

## Usage

``` r
pruneKey(
  key,
  keep = NULL,
  drop = NULL,
  ranks = c("genus", "exact"),
  note = c("column", "append", "none"),
  renumber = FALSE
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- keep:

  Taxa to keep; all others are removed. `NULL` keeps all.

- drop:

  Taxa to remove (after `keep` has been applied).

- ranks:

  `"genus"` or `"exact"`; see 'Matching taxa'.

- note:

  `"column"`, `"append"` or `"none"`; see 'What happens to the removed
  couplet's character'.

- renumber:

  If `TRUE`, number the remaining couplets 1, 2, 3, ... in reading order
  (each couplet followed by the couplets its leads go to, first lead
  first). If `FALSE`, couplets keep their names.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
with the same columns in its leads as `key` (plus `Note` if a note was
written). Embedded images, taxa and features that no remaining lead uses
are left out. It is an error if no result is left, or only one (a key
needs two results to tell apart).

## Details

The leads that remain keep their text, their order and (unless
`renumber = TRUE`) their couplet names, so every kept taxon is reached
by the same leads as before, less the ones that no longer decide
anything. Pruning in two steps gives the same key as pruning once to the
taxa kept by both.

## Matching taxa

Names are compared without regard to case or extra spaces, and the
multiplication sign of a hybrid may be typed as a lower-case `x`
(`"Populus x acuminata"`). An entry of `keep` or `drop` matches a taxon
of the key when it equals the taxon's whole label
(`"Bur oak (Quercus macrocarpa)"`), the scientific name in its
parentheses (`"Quercus macrocarpa"`) or the common name before them
(`"Bur oak"`); entries may themselves be written with or without a
common name.

With `ranks = "genus"` (the default) a name also stands for what lies
below it, judged by the words the names begin with:

- a genus in `keep` or `drop` (`"Populus"`) matches every species of
  that genus in the key, and a species (`"Populus balsamifera"`) matches
  its subspecies and varieties
  (`"Populus balsamifera subsp. trichocarpa"`);

- a name matches the same name followed by its author
  (`"Quercus macrocarpa"` and `"Quercus macrocarpa Michx."`, or
  `"Carcharodon carcharias (Linnaeus, 1758)"`), whichever of the two has
  the author;

- a species in `keep` (`"Quercus macrocarpa"`) keeps a result of the key
  that is only its genus (`"Quercus"`), and a subspecies keeps its
  species. This is not done for `drop`: removing one species does not
  remove its genus.

With `ranks = "exact"` only whole labels, scientific names and common
names match. Families and higher ranks cannot be told from a name, so a
result such as `"Salicaceae"` is matched only by itself, and a synonym
is a different name;
[`regionalKey()`](https://leipzig.github.io/dimoose/reference/regionalKey.md)
asks GBIF or iNaturalist instead and so works at any rank and through
synonyms.

## Shared results

A result that names several taxa the key cannot tell apart, written
`"A / B"` as
[`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)
and
[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
write them, is treated as the taxa `A` and `B`: each can be kept or
dropped by its own name, and when only `A` is kept the result becomes
`"A"`. Naming the whole result (`"A / B"`) keeps or drops all of it. (A
label with a common name, such as
`"Aspen / Popple (Populus tremuloides)"`, is one taxon.)

## What happens to the removed couplet's character

When a couplet is taken out, the text of its one remaining lead still
describes the taxa beyond it, and is useful for confirming an
identification. With `note = "column"` (the default) it is added to a
`Note` column on the lead that now skips the couplet; with
`note = "append"` it is added to that lead's `Character` in square
brackets, so it shows wherever the key is displayed; with
`note = "none"` it is discarded. Whatever `note` is, the removed lead's
pictures (`Image` and `ImageLink`) are added to those of the lead that
now skips the couplet. When the first couplet of the key is taken out
there is no lead to carry the text: it goes in the key's metadata as
`pruned_note` (added to any that is already there), and its pictures are
left out.

## See also

[`regionalKey()`](https://leipzig.github.io/dimoose/reference/regionalKey.md)
to prune to the taxa recorded in a place,
[`mergeKeys()`](https://leipzig.github.io/dimoose/reference/mergeKeys.md)
to go the other way.

## Examples

``` r
cottonwoods <- pruneKey(montanaKey(), keep = "Populus")
cottonwoods
#> <dimoose key> Key to the native broadleaf trees of Montana
#>   3 couplets, 6 leads, 4 taxa, up to 3 steps deep (2.2 on average)
cottonwoods$leads[, c("Statement", "Choice", "Next", "Taxon")]
#>   Statement Choice Next                                        Taxon
#> 1         5      a    - Narrowleaf cottonwood (Populus angustifolia)
#> 2         5      b    7                                             
#> 3         7      a    8                                             
#> 4         7      b    -       Black cottonwood (Populus trichocarpa)
#> 5         8      a    -          Quaking aspen (Populus tremuloides)
#> 6         8      b    -        Plains cottonwood (Populus deltoides)

# names can be given with or without the common name
k <- pruneKey(montanaKey(), drop = c("Acer negundo", "Bur oak (Quercus macrocarpa)"),
              renumber = TRUE)
k$validate()
k$leads$Note
#>  [1] "Leaves opposite, with 5 to 7 leaflets with toothed margins."
#>  [2] ""                                                           
#>  [3] ""                                                           
#>  [4] "Leaves not lobed."                                          
#>  [5] ""                                                           
#>  [6] ""                                                           
#>  [7] ""                                                           
#>  [8] ""                                                           
#>  [9] ""                                                           
#> [10] ""                                                           
#> [11] ""                                                           
#> [12] ""                                                           
#> [13] ""                                                           
#> [14] ""                                                           
#> [15] ""                                                           
#> [16] ""                                                           
```
