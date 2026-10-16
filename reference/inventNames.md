# Invent pronounceable names

Random words made of consonant onsets, vowels and codas. They name
sniglets: visual features that have no English name (as fordera does).

## Usage

``` r
inventNames(n, seed = 1)
```

## Arguments

- n:

  Number of names.

- seed:

  Random seed, so the same call gives the same names. The global random
  number generator state is left unchanged.

## Value

A character vector of `n` distinct lower-case words.

## Examples

``` r
inventNames(5)
#> [1] "gaithiark"     "treuxraikbluk" "zhuprierl"     "glirreur"     
#> [5] "glienglaund"  
```
