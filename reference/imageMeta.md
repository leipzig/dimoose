# Embed images in a key's metadata

Reads image files and returns `image_<id>` rows for a key's `meta`,
which
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
embeds in the page (each image once); leads refer to them by id in their
`Image` column (several separated by `;`).

## Usage

``` r
imageMeta(paths, ids = NULL)
```

## Arguments

- paths:

  Image files.

- ids:

  Names for the images; default the file names without extension.

## Value

A key/value data frame.
