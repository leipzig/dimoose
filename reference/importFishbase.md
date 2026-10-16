# Import a dichotomous key from FishBase

Downloads a key from FishBase and converts it into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object. See <https://www.fishbase.se/keys/allkeys.php> for the list of
keys and their key codes.

## Usage

``` r
importFishbase(
  keycode,
  fishbaseUrl = "https://www.fishbase.se/",
  separateTerms = TRUE,
  usePhyloService = c("GNA", "GNR", "none", "TNRS"),
  embedImages = FALSE
)
```

## Arguments

- keycode:

  Numeric or character FishBase key code.

- fishbaseUrl:

  Base URL of the FishBase mirror, with a trailing slash.

- separateTerms:

  If `TRUE`, split each lead's character statement on `";"` into one row
  per term.

- usePhyloService:

  Taxonomic name resolution: `"GNA"` verifies terminal taxa with the
  Global Names verifier
  ([`taxize::gna_verifier()`](https://docs.ropensci.org/taxize/reference/gna_verifier.html),
  requires the 'taxize' package); `"none"` skips resolution. `"GNR"` is
  accepted as an alias for `"GNA"`. `"TNRS"` is no longer available
  because
  [`taxize::tnrs()`](https://docs.ropensci.org/taxize/reference/tnrs-defunct.html)
  is defunct.

- embedImages:

  If `TRUE`, download the key's morphology images and store them
  base64-encoded in `meta`. Image URLs are always stored.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## See also

[`parseFishbase()`](https://leipzig.github.io/dimoose/reference/parseFishbase.md)
to build a key from saved HTML pages.

## Examples

``` r
if (FALSE) { # \dontrun{
sharks <- importFishbase(1)
sharks$taxa
} # }
```
