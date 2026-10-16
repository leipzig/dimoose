# Embed images in a key's metadata

Reads image files and returns `image_<id>` rows for a key's `meta`,
which
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
embeds in the page (each image once); leads refer to them by id in their
`Image` column (several separated by `;`).

## Usage

``` r
imageMeta(paths, ids = NULL, maxSize = 1200)
```

## Arguments

- paths:

  Image files.

- ids:

  Names for the images; default the file names without extension.

- maxSize:

  Photos larger than this many pixels on their long side are scaled down
  to it when the 'magick' package is installed, so keys made from camera
  photos stay small; without 'magick' they are embedded as they are.

## Value

A key/value data frame.
