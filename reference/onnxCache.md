# Folder where dimoose keeps downloaded and converted ONNX models

Models are large (tens to hundreds of megabytes), so they are kept
outside your project, in R's per-user cache folder for dimoose. Set the
option `dimoose.onnx.cache` to use another folder.

## Usage

``` r
onnxCache()
```

## Value

A path. The folder is not created until a model is stored in it.

## Examples

``` r
onnxCache()
#> [1] "/home/runner/.cache/R/dimoose/onnx"
```
