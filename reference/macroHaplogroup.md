# Macrohaplogroup of a haplogroup

Macrohaplogroup of a haplogroup

## Usage

``` r
macroHaplogroup(
  haplogroup,
  level = c("letter", "depth"),
  depth = 2,
  tree = dimoose::phylotree17
)
```

## Arguments

- haplogroup:

  Haplogroup names.

- level:

  `"letter"` (default) uses the conventional label: `L0` to `L6` for the
  African lineages and the leading letter otherwise (`H2a` is `H`, `U5b`
  is `U`). This is a naming convention, not a clade: for example D sits
  inside M phylogenetically. `"depth"` uses the ancestor at a fixed
  depth from the root, which is a true clade.

- depth:

  For `level = "depth"`, the depth of the ancestor to report;
  haplogroups shallower than that are returned as they are.

- tree:

  Default
  [phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md).

## Value

A character vector the length of `haplogroup`.

## Examples

``` r
macroHaplogroup(c("H2a2a1", "L3e1", "U5b"))
#> [1] "H"  "L3" "U" 
macroHaplogroup("H2a", level = "depth", depth = 3)
#> [1] "L2'3'4'6"
```
