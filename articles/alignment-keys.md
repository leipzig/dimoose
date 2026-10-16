# Automated key generation from a sequence alignment

**Automated key generation** builds a dichotomous key from data instead
of from a person’s judgement.
[`vignette("vision-keys")`](https://leipzig.github.io/dimoose/articles/vision-keys.md)
starts from photos. This vignette starts from a multiple sequence
alignment (MSA) and needs one command:

``` r

library(dimoose)
fasta <- system.file("extdata", "aligned.fasta", package = "dimoose")   # or the path of your own file
key <- keyFromAlignment(fasta)
```

``` r

exportWizard(key, "key.html")
```

dimoose ships two example alignments, so that every command here runs as
written:

- `aligned.fasta`: 15 wood mouse cytochrome *b* sequences (the
  `woodmouse` data of the `ape` package), with a tree of them in
  `aligned.nwk`;
- `mtdna.fasta`: whole human mitochondrial genomes for 14 haplogroups.

## What the command does

1.  **Reads the alignment**: a FASTA file, or an object from `ape` or
    `phangorn`.
2.  **Builds a tree** with a phylogeny program. The default is neighbour
    joining in `ape`. `tool =` selects another.
3.  **Roots the tree** on an outgroup you name, or at its midpoint.
4.  **Turns every fork into a couplet.** The two leads of a couplet are
    the alignment sites that tell the two sides of the fork apart,
    written as the site and its state: `106G 35G` against `106A 35A`.
    Each sequence is a result.

The sequences must already be aligned. To align them first, use a
program such as MAFFT or MUSCLE.

## An example

The key built above from `aligned.fasta`, the 15 wood mouse sequences:

``` r

key
#> <dimoose key> Key generated from a sequence alignment
#>   14 couplets, 28 leads, 15 taxa, up to 6 steps deep
head(key$leads[, c("Statement", "Character", "Next", "Taxon")], 8)
#>   Statement      Character Next   Taxon
#> 1         1       106G 35G    2        
#> 2         1       106A 35A    3        
#> 3         2 201T 234C 297G    -   No305
#> 4         2 201C 234T 297A    - No1114S
#> 5         3   72T 96A 318T    4        
#> 6         3   72C 96C 318C   11        
#> 7         4      477A 837G    5        
#> 8         4      477G 837A    7
```

Read it like any key. At couplet 1, look at sites 106 and 35 of your
sequence: `G` at both sends you to couplet 2, `A` at both to couplet 3.

The key records how it was made, including the tree itself:

``` r

meta <- setNames(key$meta$value, key$meta$key)
meta[c("tool", "rooting", "sequences", "sites", "weak_couplets")]
#>                          tool                       rooting 
#> "neighbour joining (ape::nj)"                    "midpoint" 
#>                     sequences                         sites 
#>                          "15"                         "965" 
#>                 weak_couplets 
#>                           "0"
substr(meta[["newick"]], 1, 60)
#> [1] "((No305:0.006631975209,No1114S:0.008893932008):0.00186751795"
```

It is an ordinary dimoose key, so the wizard and the phylogenetics
exports work on it:

``` r

exportWizard(key, "woodmouse.html")
toTreedata(key)                      # for ggtree
```

## Choosing the phylogeny program

``` r

keyFromAlignment(aln, tool = "nj")          # neighbour joining (ape), the default
keyFromAlignment(aln, tool = "bionj")       # BIONJ (ape)
keyFromAlignment(aln, tool = "upgma")       # UPGMA (phangorn)
keyFromAlignment(aln, tool = "parsimony")   # parsimony ratchet (phangorn)
keyFromAlignment(aln, tool = "ml")          # maximum likelihood (phangorn)
keyFromAlignment(aln, tool = "fasttree")    # the FastTree program
keyFromAlignment(aln, tool = "iqtree")      # the IQ-TREE program
```

`"fasttree"` and `"iqtree"` run the command-line program, which must be
installed. dimoose looks for it on the `PATH`; give its location in
`exe` if it is elsewhere, and extra options in `args`. `model` sets the
substitution model for the tools that take one.

For any other program, build the tree yourself and hand it over. Its tip
labels must be the sequence names. Polytomies are resolved by the sites:

``` r

newick <- system.file("extdata", "aligned.nwk", package = "dimoose")    # e.g. RAxML's bestTree file
keyFromAlignment(fasta, tree = newick)
#> <dimoose key> Key generated from a sequence alignment
#>   14 couplets, 28 leads, 15 taxa, up to 6 steps deep
```

## Rooting

A key starts at the root, so where the tree is rooted decides the first
question. Name an outgroup when you have one:

``` r

data(Laurasiatherian, package = "phangorn")
mammals <- suppressWarnings(keyFromAlignment(Laurasiatherian, outgroup = "Platypus"))
mammals$leads[1:2, c("Character", "Next", "Taxon")]
#>              Character Next    Taxon
#> 1 30C/T 34A/C/T 157A/G    2         
#> 2         30A 34G 157T    - Platypus
```

Without an outgroup, an unrooted tree is rooted at its midpoint.

## Numbering sites

By default a site is its column in the alignment. To use the coordinates
of one sequence instead, name it as the `reference`. Columns where the
reference has a gap are numbered as insertions (`2156.1`).

`mtdna.fasta` holds whole mitochondrial genomes for 14 human
haplogroups. One of them, H2a2a1, is the haplogroup of the rCRS, the
standard reference for human mitochondrial DNA, so numbering by it gives
the usual coordinates. L0a1 belongs to the earliest branch of the tree,
which makes it the outgroup:

``` r

mtdna <- system.file("extdata", "mtdna.fasta", package = "dimoose")
mt <- keyFromAlignment(mtdna, reference = "H2a2a1", outgroup = "L0a1")
mt
#> <dimoose key> Key generated from a sequence alignment
#>   13 couplets, 26 leads, 14 taxa, up to 10 steps deep
mt$leads[1:8, c("Statement", "Character", "Next", "Taxon")]
#>   Statement          Character Next Taxon
#> 1         1       93A 95A 236T    2      
#> 2         1       93G 95C 236C    -  L0a1
#> 3         2     151C 182C 186C    3      
#> 4         2     151T 182T 186A    - L1c2a
#> 5         3    195T 769G 1018G    4      
#> 6         3    195C 769A 1018A    -  L2a1
#> 7         4 8701A 9540T 10873T    5      
#> 8         4 8701G 9540C 10873C   12
```

Couplet 4 splits on 8701, 9540 and 10873, the sites that define
macrohaplogroup N, and the other leads are likewise mutations PhyloTree
lists for those branches.

These 14 sequences are not from individuals. Each is rebuilt from
PhyloTree Build 17: the root sequence with the mutations on the path to
that haplogroup applied (see `data-raw/alignments/build.R` in the
source).

## When a fork has no clean difference

A site is *diagnostic* for a fork when the states on one side never
occur on the other. A fork can lack such a site, because of homoplasy or
because the tree is wrong there. dimoose then uses the site that
separates the two sides best, marks the leads `(most)`, and warns:

``` r

mammals <- keyFromAlignment(Laurasiatherian, outgroup = "Platypus")
#> Warning: 1 couplet(s) have no fully diagnostic site; their leads are marked
#> "(most)"
grep("(most)", mammals$leads$Character, fixed = TRUE, value = TRUE)
#> [1] "1026C (most)" "1026T (most)"
```

If no site separates the two sides of a fork at all, dimoose stops
following the tree there and splits those sequences by their sites
alone, with a warning. Sequences that no site can tell apart share a
result (`"A / B"`), as do identical sequences. Gaps and ambiguity codes
count as missing data and are never used as a state.

## Identifying a sequence

The key can be followed by machine.
[`alignmentScores()`](https://leipzig.github.io/dimoose/reference/alignmentScores.md)
reads off the sites the key tests, and
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
walks the key. The new sequences must be aligned to the same coordinates
as the key:

``` r

classify(key, alignmentScores(key, fasta))[1:4, ]
#>        id  result           path
#> 1   No305   No305          1a 2a
#> 2   No304   No304 1b 3a 4a 5a 6a
#> 3   No306   No306    1b 3a 4a 5b
#> 4 No0906S No0906S 1b 3a 4b 7b 9b
```

Each couplet is tested on its first listed site. A sequence with a gap
or an ambiguity code at that site gets no result (`NA`).
