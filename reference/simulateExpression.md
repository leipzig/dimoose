# Simulate expression data on PhyloTree

Simulates per-sample expression for a set of genes, where recurrent
mutations (variants that arise independently on many branches) shift
expression by fixed amounts on top of a baseline that differs between
macrohaplogroups. It is the ground truth for testing
[`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md): a
good method finds the mutation effects as splits and does not split on
clade markers that only track the macrohaplogroup baselines.

## Usage

``` r
simulateExpression(
  n = 1000,
  genes = 20,
  effectSites = c("16362", "150", "709", "16093"),
  propMutation = 0.4,
  propBaseline = 0.3,
  sitesPerGene = 1:2,
  effect = 1,
  macroSD = 1,
  slopeSD = 0,
  noise = 1,
  decoys = NULL,
  macroLevel = "letter",
  seed = 1
)
```

## Arguments

- n:

  Number of samples.

- genes:

  Number of genes.

- effectSites:

  Sites that can carry mutation effects.

- propMutation, propBaseline:

  Proportions of mutation and baseline genes; the rest are null.

- sitesPerGene:

  Possible numbers of effect sites per mutation gene.

- effect:

  Size of each mutation effect (its sign is random).

- macroSD:

  Standard deviation of the macrohaplogroup baselines.

- slopeSD:

  If positive, each mutation effect also varies between macrohaplogroups
  with this standard deviation (a random slope).

- noise:

  Residual standard deviation.

- decoys:

  Extra candidate split sites with no effect. By default the most
  recurrent other sites plus the markers of the four most common
  macrohaplogroups in the sample.

- macroLevel:

  Passed to
  [`macroHaplogroup()`](https://leipzig.github.io/dimoose/reference/macroHaplogroup.md)
  as `level`.

- seed:

  Random seed.

## Value

A list with `expr` (samples x genes), `samples` (data frame of `sample`,
`haplogroup`, `macro`), `X` (samples x sites, 0/1, from
[`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md)),
`truth` (`beta`, genes x sites; `b`, genes x macrohaplogroups;
`geneType`; and `slope` when `slopeSD > 0`), `effectSites`,
`markerSites` and `decoySites`.

## Details

Samples are drawn uniformly from the leaf haplogroups of
[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
so their macrohaplogroups are as unbalanced as the tree itself (H is far
more common than L5). For sample *i* and gene *g*:

`expr[i, g] = b[g, macro(i)] + sum_s beta[g, s] * X[i, s] + slope + noise`

Genes come in three kinds: `"mutation"` genes have a baseline and one or
more mutation effects, `"baseline"` genes have only the macrohaplogroup
baseline, and `"null"` genes are pure noise.

The default effect sites (16362, 150, 709, 16093) are highly recurrent
but carried by a minority of lineages across many macrohaplogroups. The
most-cited recurrent sites (152, 16311, 146, 16189) are poor effect
sites in RSRS orientation: they are also on deep branches (16311 is an
L3 marker), so most lineages carry them and carrying them largely tracks
clade membership. They are included as decoys instead.

## See also

[`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md),
[`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md)

## Examples

``` r
sim <- simulateExpression(n = 300, genes = 10)
table(sim$truth$geneType)
#> 
#> mutation baseline     null 
#>        4        3        3 
```
