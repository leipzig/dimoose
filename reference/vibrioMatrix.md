# The vibrio dataset as a character matrix

Recodes the
[vibrio](https://leipzig.github.io/dimoose/reference/vibrio.md)
consensus matrix of Noguerola & Blanch (2008) into the character matrix
[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
takes: `+` and `(+)` (mostly positive) become `"+"`, `-` and `(-)`
become `"-"`, the variable results `v` and `d` become `"+/-"`, and `ND`
(not determined) and the one blank cell become `NA`.

## Usage

``` r
vibrioMatrix()
```

## Value

A data frame with 74 rows: `Taxon`, then the 45 tests.

## See also

[`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)

## Examples

``` r
m <- vibrioMatrix()
m[1:4, 1:4]
#>             Taxon Arginine dihydrolase (moller) Lysine decarboxylase(Moller)
#> 1     V.aerogenes                             +                            -
#> 2   V.aestuarinus                             +                          +/-
#> 3   V.agarivorans                             -                            -
#> 4 V.alginolyticus                             -                            +
#>   Ornithine decarboxylase(moller)
#> 1                               -
#> 2                               -
#> 3                               -
#> 4                               +
table(unlist(m[-1]), useNA = "ifany")
#> 
#>    +  +/-    - <NA> 
#> 1164  282 1495  389 
```
