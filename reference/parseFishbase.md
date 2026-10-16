# Build a dimoose object from FishBase key pages

The offline half of
[`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md):
parses a FishBase key description page and its questions (couplet) page,
both already downloaded.

## Usage

``` r
parseFishbase(
  description,
  questions,
  separateTerms = TRUE,
  usePhyloService = c("GNA", "GNR", "none", "TNRS"),
  embedImages = FALSE,
  pageUrl = "https://www.fishbase.se/keys/questions.php"
)
```

## Arguments

- description:

  The description page (`keys/description.php`): an `xml_document`, a
  file path, or a string of HTML.

- questions:

  The questions page (`keys/questions.php`), in any of the same forms.

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

- pageUrl:

  URL of the questions page, used to resolve relative image links.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
parseFishbase("description.html", "questions.html", usePhyloService = "none")
} # }
```
