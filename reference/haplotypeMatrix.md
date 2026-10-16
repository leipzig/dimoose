# Which mutations each haplogroup carries

Follows every haplogroup's path from the root of the tree and records,
for each requested site, whether the haplogroup's haplotype differs from
the root (RSRS) there. Back-mutations are applied as Haplogrep defines
them (they undo the latest change at that site), so a site gained and
later reverted on a lineage is not carried below the reversion.
Insertions are tracked as their own sites (`"573.X"`, `"2491.1"`),
separate from substitutions at the same position; a deletion counts as
carried.

## Usage

``` r
haplotypeMatrix(
  haplogroups,
  sites = NULL,
  tree = dimoose::phylotree17,
  mutations = dimoose::phylotree17_mutations
)
```

## Arguments

- haplogroups:

  Haplogroup names, one per row of the result; repeats are allowed (e.g.
  one per sample).

- sites:

  Sites to report: positions as character (`"16311"`) or insertion sites
  (`"573.X"`). Defaults to the sites of
  [`recurrentPositions()`](https://leipzig.github.io/dimoose/reference/recurrentPositions.md).

- tree, mutations:

  The tree and its mutations; default
  [phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md)
  and
  [phylotree17_mutations](https://leipzig.github.io/dimoose/reference/phylotree17_mutations.md).
  `tree` needs `haplogroup`, `parent` and `depth`; `mutations` needs
  `haplogroup`, `notation`, `position`, `type`, `ancestral` and
  `derived`.

## Value

An integer matrix of 0/1, one row per entry of `haplogroups` (row names
are the haplogroups) and one column per site.

## See also

[`recurrentPositions()`](https://leipzig.github.io/dimoose/reference/recurrentPositions.md),
[`macroHaplogroup()`](https://leipzig.github.io/dimoose/reference/macroHaplogroup.md),
[`simulateExpression()`](https://leipzig.github.io/dimoose/reference/simulateExpression.md)

## Examples

``` r
haplotypeMatrix(c("H2a2a1", "U5b", "L0a1b"), sites = c("152", "16311", "16278"))
#>        152 16311 16278
#> H2a2a1   1     1     1
#> U5b      1     1     1
#> L0a1b    0     0     0
```
