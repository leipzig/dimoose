# Rename sniglets

Sniglets start with coined names (`"dulmzil"`) because nobody has looked
at them yet. After looking at what a sniglet picks out (the example
crops in the wizard's glossary), give it a real name. The coined word
stays as the sniglet's permanent identifier, so scores, machine tests
and saved name tables keep working; only the text people read changes:
the leads (`"Has round headlights"`), the questions and the glossary.

## Usage

``` r
renameSniglets(x, names = NULL, definitions = NULL)
```

## Arguments

- x:

  A key from
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
  or a
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  result (so that every key built from it afterwards uses the names).

- names:

  The new names: a named character vector
  (`c(dulmzil = "an egg-crate grille")`), a names table as described
  above, or the path of a CSV file holding one.

- definitions:

  Optional named character vector of definitions, named like `names`.
  `names` may be `NULL` to change definitions only.

## Value

A renamed copy of `x`; `x` itself is not changed.

## Details

The names table has one row per sniglet you want to rename, with columns
`sniglet` (the coined word, or the sniglet's current name), `name` and
optionally `definition`. Rules:

- a blank `name` puts the coined word back;

- no two sniglets may share a name, and a name may not be another
  sniglet's coined word;

- a `definition` column replaces the definitions of the rows listed
  (blank removes one); without the column, definitions are left alone;

- a `used` column, as
  [`snigletNames()`](https://leipzig.github.io/dimoose/reference/snigletNames.md)
  returns, is ignored.

Names read best as noun phrases (`"an egg-crate grille"`), since leads
are written "Has *name*" and "Lacks *name*".

## See also

[`snigletNames()`](https://leipzig.github.io/dimoose/reference/snigletNames.md)

## Examples

``` r
set.seed(1)
patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
patches <- sweep(patches, c(1, 2), sqrt(apply(patches^2, c(1, 2), sum)), "/")
s <- discoverSniglets(patches, k = 3)
first <- s$sniglets$sniglet[1]
s <- renameSniglets(s, stats::setNames("round headlights", first),
                    definitions = stats::setNames("Circular lamps in the grille", first))
snigletNames(s)
#>         sniglet             name                   definition
#> 1     gaithiark round headlights Circular lamps in the grille
#> 2 treuxraikbluk    treuxraikbluk                         <NA>
#> 3     zhuprierl        zhuprierl                         <NA>
```
