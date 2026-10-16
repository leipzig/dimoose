# Key to the native broadleaf trees of Montana

A dichotomous key to the eleven native broadleaf (hardwood) trees of
Montana, as a table of leads (see
[`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md));
[`montanaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
turns it into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key
with photos. Written for dimoose: native status was checked in the
Montana Field Guide and USDA PLANTS, and every couplet's characters come
from Montana Field Guide or Virginia Tech Dendrology descriptions.
Common hackberry is left out because the Montana Field Guide gives its
origin in Montana as undetermined.

## Usage

``` r
montana
```

## Format

A data frame with 20 rows (10 couplets) and 7 character columns:

- Statement:

  Couplet number.

- Choice:

  `a` or `b`.

- Character:

  Text of the lead.

- Next:

  Couplet the lead leads to, or `"-"`.

- Taxon:

  For terminal leads, `"Common name (Genus species)"`.

- Question:

  What the couplet asks, e.g. `"Leaf type?"`.

- Image:

  Ids of the photos in `inst/extdata/montana/` shown with the lead,
  separated by `;`.

## Source

Montana Field Guide, Montana Natural Heritage Program and Montana Fish,
Wildlife & Parks, <https://fieldguide.mt.gov>; USDA PLANTS Database,
<https://plants.usda.gov>; Virginia Tech Dendrology fact sheets,
<https://dendro.cnre.vt.edu>. The page for each species and the source
of each couplet are listed in `data-raw/montana/sources.md` in the
package sources.
