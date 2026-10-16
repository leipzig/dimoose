# Recurrent (homoplasic) mutation sites

Sites that mutate independently on many branches of the tree, such as
152, 16311 and 16189 in PhyloTree. These are the variants whose effects
a tree can find across unrelated lineages.

## Usage

``` r
recurrentPositions(
  min_branches = 10,
  types = c("transition", "transversion", "back-mutation"),
  mutations = dimoose::phylotree17_mutations
)
```

## Arguments

- min_branches:

  Minimum number of branches (haplogroups) on which the site mutates.

- types:

  Mutation types to count; by default substitutions and back-mutations.
  Insertions and deletions are left out, except that a reverted
  insertion counts as a back-mutation at its insertion site (for example
  `"5899.1"`).

- mutations:

  Default
  [phylotree17_mutations](https://leipzig.github.io/dimoose/reference/phylotree17_mutations.md).

## Value

A data frame of `site` and `n_branches`, most recurrent first.

## Examples

``` r
head(recurrentPositions())
#>    site n_branches
#> 1   152        223
#> 2 16311        147
#> 3   146        132
#> 4   195        130
#> 5 16189        118
#> 6 16129         94
```
