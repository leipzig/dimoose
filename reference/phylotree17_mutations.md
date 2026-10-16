# PhyloTree Build 17 mutations, one per row

The mutations of every haplogroup in
[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md),
one row per mutation, in the order Haplogrep lists them, with the bases
before and after worked out by following the tree from the RSRS.

## Usage

``` r
phylotree17_mutations
```

## Format

A data frame with 13,384 rows and 6 columns:

- haplogroup:

  Haplogroup whose branch carries the mutation.

- notation:

  The mutation as written by Haplogrep.

- position:

  Position in the RSRS/rCRS coordinates.

- type:

  `transition`, `transversion`, `back-mutation`, `insertion` or
  `deletion`.

- ancestral:

  Base before the mutation (for a reverted insertion, the inserted
  sequence); `NA` for insertions.

- derived:

  Base after the mutation, or the inserted sequence; `NA` for deletions
  and reverted insertions.

## Source

See
[phylotree17](https://leipzig.github.io/dimoose/reference/phylotree17.md).

## Details

Seven back-mutations revert a position that nothing earlier on their
path changes (six `16233C!`, e.g. in `D4c1b1`, and `D5a2` `1438A!`); for
those the written base is taken as the result.

## Examples

``` r
table(phylotree17_mutations$type)
#> 
#>    transition  transversion back-mutation     insertion      deletion 
#>         11268           533          1182           130           271 
phylotree17_mutations[phylotree17_mutations$haplogroup == "J1c", ]
#>      haplogroup notation position       type ancestral derived
#> 9463        J1c     185A      185 transition         G       A
#> 9464        J1c     228A      228 transition         G       A
#> 9465        J1c   14798C    14798 transition         T       C
```
