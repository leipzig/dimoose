# Build a key from a multiple sequence alignment

One command from aligned sequences to a dichotomous key. A phylogeny
program builds a tree from the alignment, the tree is rooted and made
strictly bifurcating, and every fork becomes a couplet whose two leads
are the alignment sites that tell its two clades apart (`"152C 16311T"`
against `"152T 16311C"`). Each sequence is a result.

## Usage

``` r
keyFromAlignment(
  alignment,
  tool = c("nj", "bionj", "upgma", "parsimony", "ml", "fasttree", "iqtree"),
  tree = NULL,
  outgroup = NULL,
  reference = NULL,
  type = c("auto", "DNA", "AA"),
  model = NULL,
  maxSites = 3,
  exe = NULL,
  args = NULL,
  desc = "Key generated from a sequence alignment",
  meta = NULL
)
```

## Arguments

- alignment:

  The alignment: a FASTA file, an `ape` `DNAbin`/`AAbin` object (e.g.
  from [`ape::read.dna()`](https://rdrr.io/pkg/ape/man/read.dna.html)
  for Clustal or PHYLIP files), a `phangorn` `phyDat`, a character
  matrix with one named row per sequence and one column per site, or a
  named character vector of equal-length strings.

- tool:

  The program that builds the tree:

  - `"nj"`, `"bionj"`: neighbour joining in `ape`;

  - `"upgma"`, `"parsimony"`, `"ml"`: UPGMA, the parsimony ratchet and
    maximum likelihood in `phangorn`;

  - `"fasttree"`, `"iqtree"`: the FastTree or IQ-TREE command-line
    program, which must be installed.

- tree:

  A tree you built yourself, instead of `tool`: an `ape` `phylo` object,
  a Newick file or a Newick string, with the sequence names as tip
  labels. It may cover only some of the sequences, and may have
  polytomies. This is the way to use any other phylogeny program.

- outgroup:

  Name(s) of the sequence(s) to root on. Without it, a tree that is not
  already rooted is rooted at its midpoint. Sequences can be named in
  full or by the first word of their FASTA header.

- reference:

  Name of a sequence in the alignment to number sites by (its ungapped
  positions; columns where it has a gap are numbered `"315.1"`,
  `"315.2"`). By default sites are alignment columns.

- type:

  `"DNA"`, `"AA"`, or `"auto"` to guess from the sequences.

- model:

  Substitution model, passed to the tool: the `model` of
  [`ape::dist.dna()`](https://rdrr.io/pkg/ape/man/dist.dna.html) for the
  distance methods (default `"K80"`; `"JTT"` through
  [`phangorn::dist.ml()`](https://klausvigo.github.io/phangorn/reference/dist.hamming.html)
  for proteins), the model of
  [`phangorn::pml_bb()`](https://klausvigo.github.io/phangorn/reference/pml_bb.html)
  for `"ml"` (default `"GTR+G(4)"`, or `"LG+G(4)"` for proteins), or
  IQ-TREE's `-m` (default: IQ-TREE chooses).

- maxSites:

  Most sites listed in a lead.

- exe:

  Path to the FastTree or IQ-TREE program, if it is not on the `PATH`.

- args:

  Extra command-line arguments for FastTree or IQ-TREE.

- desc, meta:

  Title and extra metadata of the key.

## Value

A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md) key.
Its `meta` records the tool, the rooting, the tree in Newick format
(`newick`, names quoted where Newick needs it), how many couplets lack a
diagnostic site (`weak_couplets`) and how many do not follow the tree
(`regrouped_couplets`).

## Details

Sites are chosen per fork: a site is *diagnostic* when the states seen
on one side are never seen on the other. Up to `maxSites` diagnostic
sites are listed, those with the least missing data first. If a fork has
no diagnostic site, the best-separating one is used and marked `(most)`.
If no site separates the two sides, the sequences below it are split by
their sites alone, whatever the tree says. Sequences that no site tells
apart share a result (`"A / B"`), as do identical sequences. Gaps and
ambiguity codes are treated as missing data.

The first site of each couplet is also a machine-readable test, so
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
can place sequences scored with
[`alignmentScores()`](https://leipzig.github.io/dimoose/reference/alignmentScores.md).

## See also

[`alignmentScores()`](https://leipzig.github.io/dimoose/reference/alignmentScores.md),
[`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md),
[`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md)

## Examples

``` r
aln <- c(human = "ACGTACGTACGA", chimp = "ACGTACGTATGA", mouse = "ACCTACATGCGA",
         rat   = "ACCTACATGCGT", fish  = "TCCTTCGTACCA")
if (requireNamespace("ape", quietly = TRUE)) {
  key <- keyFromAlignment(aln, outgroup = "fish")
  key$leads[, c("Statement", "Character", "Next", "Taxon")]
  classify(key, alignmentScores(key, aln))
}
#>      id result     path
#> 1 human  human 1a 2b 4a
#> 2 chimp  chimp 1a 2b 4b
#> 3 mouse  mouse 1a 2a 3a
#> 4   rat    rat 1a 2a 3b
#> 5  fish   fish       1b

# the example files that ship with dimoose
fasta <- system.file("extdata", "aligned.fasta", package = "dimoose")
mtdna <- system.file("extdata", "mtdna.fasta", package = "dimoose")
if (requireNamespace("ape", quietly = TRUE)) {
  keyFromAlignment(fasta)
  keyFromAlignment(fasta, tree = system.file("extdata", "aligned.nwk", package = "dimoose"))
  keyFromAlignment(mtdna, reference = "H2a2a1", outgroup = "L0a1")
}
#> <dimoose key> Key generated from a sequence alignment
#>   13 couplets, 26 leads, 14 taxa, up to 10 steps deep
if (FALSE) { # \dontrun{
keyFromAlignment(mtdna, tool = "iqtree", outgroup = "L0a1")   # needs IQ-TREE installed
} # }
```
