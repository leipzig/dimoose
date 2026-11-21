# Example keys

Ready-made
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) keys
built from the datasets that come with dimoose. All five are ordinary
dimoose objects: they share the same fields (`leads`, `df`, `meta`,
`taxa`, `desc`) and methods
([`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html), `validate()`,
`toDataTree()`,
[`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md))
and all work with
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md).

## Usage

``` r
sharkKey()

arachnidaKey()

vibrioKey(variable = c("both", "missing"))

montanaKey()
```

## Arguments

- variable:

  For `vibrioKey()`: `"both"` (default) keys a species that is variable
  for a test out down both leads; `"missing"` treats variable results as
  missing. See
  [`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md).

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## Details

- `sharkKey()`: FishBase key 1, *Key to the families of sharks in the
  Western Central Pacific* (Compagno 1998), from saved FishBase pages in
  `inst/extdata/fishbase/`; 23 couplets, 24 families.

- `arachnidaKey()`: the *Key to the Orders of Arachnida* from Triplehorn
  & Johnson (2005), the
  [arachnida](https://leipzig.github.io/dimoose/reference/arachnida.md)
  dataset; 11 couplets, 11 orders (Schizomida is reached from two
  couplets).

- `vibrioKey()`: a key generated from the
  [vibrio](https://leipzig.github.io/dimoose/reference/vibrio.md)
  consensus matrix of Noguerola & Blanch (2008) with
  [`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
  (the matrix itself is
  [`vibrioMatrix()`](https://leipzig.github.io/dimoose/reference/vibrioMatrix.md)).
  Tests scored `+` or `(+)` count as positive and `-` or `(-)` as
  negative. With `variable = "both"` (the default) a species that is
  variable for a test (`v`, `d`) is keyed out down both leads of every
  couplet that uses the test, and so is a species the test was not
  determined for (`ND`): 92 couplets, 74 species, 14 of them reached at
  two or three results. With `variable = "missing"` those results are
  treated as missing and the key is an rpart classification tree
  ([`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)),
  which places such a species on one side of the test with surrogate
  splits: 73 couplets, each species at one result, but a strain showing
  the species' other result is keyed out wrongly.

- `montanaKey()`: the native broadleaf trees of Montana, written for
  dimoose (the
  [montana](https://leipzig.github.io/dimoose/reference/montana.md)
  dataset); 10 couplets, 11 species, with photos from Wikimedia Commons.
  It is built with
  [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
  from `inst/extdata/montana/montana-key.csv`, a template for writing
  your own.

- [`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md):
  PhyloTree Build 17.

## References

Compagno LJV (1998). General remarks. In Carpenter KE, Niem VH (eds.),
*FAO species identification guide for fishery purposes. The living
marine resources of the Western Central Pacific*, vol. 2, pp. 1196-1207.
FAO, Rome. FishBase key 1:
<https://www.fishbase.se/keys/description.php?keycode=1>.

Triplehorn CA, Johnson NF (2005). *Borror and DeLong's Introduction to
the Study of Insects*, 7th ed., chapter 5. Thomson Brooks/Cole. ISBN
0-03-096835-6.

Noguerola I, Blanch AR (2008). Identification of *Vibrio* spp. with a
set of dichotomous keys. *Journal of Applied Microbiology* 105, 175-185.
[doi:10.1111/j.1365-2672.2008.03730.x](https://doi.org/10.1111/j.1365-2672.2008.03730.x)

## Examples

``` r
sharks <- sharkKey()
sharks
#> <dimoose key> Key to the families of sharks in the Western Central Pacific.
#>   23 couplets, 46 leads, 24 taxa, up to 12 steps deep (7.5 on average)
summary(arachnidaKey())
#>                            title couplets leads taxa depth problems
#> 1 Key to the Orders of Arachnida       11    22   11     6        0
#>   meanLeadSteps meanTaxonSteps expectedSteps    bound efficiency
#> 1      4.333333       4.227273      4.227273 3.545455  0.8387097
vibrioKey()$validate()
summary(vibrioKey(variable = "missing"))
#>                                                                    title
#> 1 Vibrio species (key generated from the Noguerola & Blanch 2008 matrix)
#>   couplets leads taxa depth problems meanLeadSteps meanTaxonSteps expectedSteps
#> 1       73   146   74    16        0      9.527027       9.527027      9.527027
#>     bound efficiency
#> 1 6.27027   0.658156
if (FALSE) { # \dontrun{
exportWizard(sharkKey(), "sharks.html")
} # }
```
