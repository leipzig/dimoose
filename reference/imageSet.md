# A set of labelled images

The starting point for automated key generation: one row per photo, with
the class (species, model, ...) the photo shows. A key separates the
classes, so there must be at least two.

## Usage

``` r
imageSet(paths, label = NULL)
```

## Arguments

- paths:

  Image files, or a single folder. A folder is searched (with its
  subfolders) for image files: png, jpg/jpeg, gif, webp, bmp and
  tif/tiff.

- label:

  Class of each image:

  - `NULL`: for a folder whose images are in subfolders, the name of the
    subfolder each image is in (`pics/cardinal/IMG_01.jpg` is a
    `cardinal`); otherwise the file name without its extension;

  - a character vector as long as `paths` (for a folder, as long as the
    files found, which are sorted by path);

  - a function applied to the file names without extensions (e.g.
    `function(x) sub("_.*$", "", x)` so that `1967_alt` counts as
    `1967`).

## Value

A data frame with `id`, `path` and `label`. `id` is the file name
without its extension; when two files share a name, their folder is put
in front (`cardinal_IMG_01`) so that ids are unique.

## Examples

``` r
imageSet(c("pics/1967.png", "pics/1967_alt.png"), label = function(x) sub("_.*$", "", x))
#>         id              path label
#> 1     1967     pics/1967.png  1967
#> 2 1967_alt pics/1967_alt.png  1967
imageSet(c("pics/cardinal/1.jpg", "pics/robin/1.jpg"), label = c("cardinal", "robin"))
#>           id                path    label
#> 1 cardinal_1 pics/cardinal/1.jpg cardinal
#> 2    robin_1    pics/robin/1.jpg    robin
# the example photos that ship with dimoose: one folder per fruit
pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
table(pics$label)
#> 
#>     banana  blueberry       kiwi      lemon  pineapple strawberry 
#>          6          6          6          6          6          6 
```
