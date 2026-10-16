# Add example crops to a sniglet key

Cuts out the example regions of each sniglet and of each lead, stores
them as PNGs in the key's `features` and `meta`, and points the leads at
them so
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
shows them. A "Has" lead shows the sniglet in the images that take that
lead; a "Lacks" lead shows what its images have instead (see
[`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)).
The glossary shows each sniglet's examples across all the images.

## Usage

``` r
patchExemplars(model, key, images, pad = NULL, size = 96)
```

## Arguments

- model:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md).

- key:

  A key from
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md).

- images:

  The
  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  the key was built from (for file paths).

- pad:

  Pixels of context to show around the region. By default none for
  tiles, and half a patch's width for patch tokens.

- size:

  The crop's output size, px.

## Value

The key, modified in place and returned invisibly.
