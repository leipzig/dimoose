# PhyloTree Build 17: the human mitochondrial DNA phylogeny

The 5,435 haplogroups of PhyloTree Build 17 (van Oven 2015) as
distributed by Haplogrep 3 (release 17.2 of `phylotree-rsrs-17`), one
row per haplogroup, rooted at `mtMRCA`. Use
[`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)
to turn the tree, or part of it, into an identification key, and
[phylotree17_mutations](https://leipzig.github.io/dimoose/reference/phylotree17_mutations.md)
for the mutations one per row.

## Usage

``` r
phylotree17
```

## Format

A data frame with 5,435 rows and 5 columns:

- haplogroup:

  Haplogroup name.

- parent:

  Name of the parent haplogroup (`NA` for `mtMRCA`).

- depth:

  Number of branches from `mtMRCA`.

- n_subclades:

  Number of direct subclades.

- mutations:

  Space-separated mutations of the branch leading to this haplogroup, as
  written by Haplogrep.

## Source

Haplogrep 3 tree `phylotree-rsrs-17`, release 17.2, commit
`0e79ddf1b78f7a1b81fb5d607bc31a6ddea7b18b`, `src/tree.xml`
(<https://github.com/genepi/phylotree-rsrs-17>), MIT license. The
conversion and a script that checks these data against GitHub are in
`data-raw/phylotree17/` in the package sources.

## Details

Rows are in the order of Haplogrep's `tree.xml`, which is preorder (each
haplogroup directly before its subclades). Names and mutations are
Haplogrep's, verbatim: names such as `H2a+152 16311` or `K1b1+(16093)`
label branches that PhyloTree leaves unnamed, and two names (`M4’’67`,
`M4’’67+16311!`) contain the Unicode character U+2019. Haplogrep's
trailing space on one name is trimmed.

Mutations are in RSRS orientation: each is the state on the branch
leading to the haplogroup. `16362C` is a substitution (position and
derived base), `263G!` a back-mutation (it reverts the latest change at
that position; `!!` marks a second reversion), `315.1C` or `5899.XC` an
insertion (`X`: unspecified length) and `249d` a deletion. Unlike some
other copies (e.g. MToolBox's), PhyloTree's unstable mutations, which
PhyloTree prints in parentheses, are included; the parentheses are not
recorded.

## References

van Oven M (2015). PhyloTree Build 17: Growing the human mitochondrial
DNA tree. *Forensic Science International: Genetics Supplement Series*
5, e392-e394.
[doi:10.1016/j.fsigss.2015.09.155](https://doi.org/10.1016/j.fsigss.2015.09.155)

Schönherr S, Weissensteiner H, Kronenberg F, Forer L (2023). Haplogrep
3 - an interactive haplogroup classification and analysis platform.
*Nucleic Acids Research* 51, W263-W268.
[doi:10.1093/nar/gkad284](https://doi.org/10.1093/nar/gkad284)

## See also

[phylotree17_mutations](https://leipzig.github.io/dimoose/reference/phylotree17_mutations.md),
[`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)

## Examples

``` r
head(phylotree17)
#>    haplogroup      parent depth n_subclades
#> 1      mtMRCA        <NA>     0           2
#> 2          L0      mtMRCA     1           2
#> 3 L0a'b'f'g'k          L0     2           2
#> 4   L0a'b'f'g L0a'b'f'g'k     3           2
#> 5     L0a'b'g   L0a'b'f'g     4           2
#> 6       L0a'g     L0a'b'g     5           2
#>                                                       mutations
#> 1                                                              
#> 2 263A 1048T 3516A 5442C 6185C 9042T 9347G 10589A 12007A 12720G
#> 3                                       189G 4586C 9818T 16172C
#> 4          73A 185A 195T 263G! 2245G 5603T 11641G 15136T 15431A
#> 5                         93G 95C 236C 8428T 8566G 9755A 16148T
#> 6                                                 11176A 16188G
phylotree17[phylotree17$parent %in% "H2a2a", ]
#>      haplogroup parent depth n_subclades   mutations
#> 3007     H2a2a1  H2a2a    16           8        263A
#> 3016     H2a2a2  H2a2a    16           0 152T! 6716G
```
