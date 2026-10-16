# Draw a key as a box diagram

Draws a dimoose key top-down as an SVG picture, the way keys are often
drawn on paper: each couplet is a blue box holding its question, its
leads are blue boxes below it, and every lead either continues to the
next couplet or ends in a green box naming the result. A result written
as `"Common name (Genus species)"` is drawn on two lines with the
scientific name in italics.

## Usage

``` r
keyDiagram(key, file = NULL, images = TRUE, title = NULL)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  key.

- file:

  Optional file to write: `.svg`, or `.png` and `.pdf` when the 'rsvg'
  package is installed.

- images:

  If `TRUE`, show a thumbnail in a result's box when the terminal lead
  names an image (`Image` column) that is embedded in the key's `meta`
  (see
  [`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md)).

- title:

  Heading drawn above the tree; by default the key's `desc`. Use `NA`
  for none.

## Value

The SVG as a single string, invisibly when `file` is given.

## Details

Thumbnails are shrunk to 112 pixels when the 'magick' package is
installed, which keeps diagrams of keys with large photos small. When
'rgnparser' and its 'gnparser' program are installed, only text that
parses as a scientific name is set in italics.

A couplet reached from more than one lead is drawn once, under the first
of them; the other leads get a dashed line to it.

## See also

[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
for an interactive version of the key.

## Examples

``` r
keyDiagram(arachnidaKey(), tempfile(fileext = ".svg"))
```
