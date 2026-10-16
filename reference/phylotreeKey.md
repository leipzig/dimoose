# Build an identification key from PhyloTree Build 17

Turns
[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
or the part of it below `root`, into a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.
Each haplogroup with subclades becomes a step at which the user picks
the subclade whose defining mutations the sample carries. With
`paragroups = TRUE` every step also offers "none of these", which
identifies the paragroup, written as in PhyloTree with a trailing `*`
(e.g. `H2a*`).

## Usage

``` r
phylotreeKey(root = "mtMRCA", paragroups = TRUE, maxDepth = Inf)
```

## Arguments

- root:

  Haplogroup to start from; the default, `"mtMRCA"`, is the whole tree.

- paragroups:

  If `TRUE`, add a "none of these" choice to every step.

- maxDepth:

  Maximum number of steps below `root`. Haplogroups at that depth become
  results even if they have subclades.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object whose `leads` have a `Label` column with the haplogroup names.

## Details

The whole tree gives a very large key (2,420 steps and 5,435 possible
results with paragroups), so for
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
a subtree or a `maxDepth` is usually more practical.

## See also

[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)

## Examples

``` r
h2a <- phylotreeKey("H2a")
head(h2a$leads)
#>   Statement Choice                   Character Next Taxon Label
#> 1       H2a      1                 951A 16354T H2a1        H2a1
#> 2       H2a      2                        750A H2a2        H2a2
#> 3       H2a      3              10810C! 16274A H2a3        H2a3
#> 4       H2a      4                      11140T    -  H2a4  H2a4
#> 5       H2a      5                      13708A H2a5        H2a5
#> 6       H2a      6 None of the subclades above    -  H2a*  H2a*
if (FALSE) { # \dontrun{
exportWizard(phylotreeKey("U5"), "u5.html")
exportWizard(phylotreeKey(maxDepth = 6), "macrohaplogroups.html")
} # }
```
