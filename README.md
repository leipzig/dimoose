# moose <img src="man/figures/logo.svg" align="right" height="139" alt="moose logo" />

An R package to manage dichotomous keys.

Dichotomous keys are bifurcating trees that are often used in species identification. More precisely, dichotomous keys are binary categorical decision trees with unique leaves.

Despite their different uses, phylogenetic trees are similar to dichotomous keys:
- the paths are traversed using mutation "decisions" instead of visible phenotypes
- all points on a phylogenetic tree represent an organism that actually existed (instead of a group of possibilities)

Moose supports phylogenetic trees in which the mutations are known, such as PhyloTree, and ships PhyloTree Build 17 (the human mitochondrial DNA phylogeny, as distributed by Haplogrep 3).

This package provides tools to:
- convert from and to popular formats including consensus matrices, `ape` phylo, `data.tree`, data frames, JSON, YAML, and Newick
- merge and prune dichotomous keys
- generate interactive dichotomous keys ("wizards") as self-contained, mobile-friendly HTML
- **build keys directly from labelled images** with a vision model (CLIP, or any model that produces embeddings), and **follow those keys by machine**
- produce training data for machine learning using splits
- interoperate with the phylogenetics ecosystem (`ggtree`/`treeio`, `igraph`, Nextstrain/Auspice, Haplogrep)
- metadata slots for provenance and supporting guide images
- perform basic lexical analysis, and specialized data types (single nucleotide variations) of criteria and taxa
- build mixed effects conditional inference trees (mecits)

# Getting started

Four example keys ship with the package and share the same methods: `sharkKey()` (FishBase), `arachnidaKey()`, `vibrioKey()` (generated from a consensus matrix), and `phylotreeKey()` (PhyloTree Build 17).

```r
library(moose)
sharks <- sharkKey()
summary(sharks)
exportWizard(sharks, "sharks.html")   # an interactive, self-contained wizard
```

There are vignettes on the package basics, example applications, and [building keys from images](vignettes/vision-keys.Rmd).

# Keys from images

moose can build a key from a folder of labelled images, the way
[fordera](https://github.com/leipzig/fordera) does for Ford trucks, with any
model that gives embeddings. The default is CLIP ViT-B/32 through Python's
open_clip:

```sh
pip install -r "$(Rscript -e 'cat(system.file("python/requirements.txt", package="moose"))')"
```

```r
library(moose)
model  <- visionModel("ViT-B-32.pt")            # or visionModel() to download
images <- imageSet(list.files("pics", full.names = TRUE), label = function(x) sub("_.*$", "", x))
emb    <- embedImages(model, images$path)

# 1. Invented terms: k-means on patch embeddings
terms  <- discoverTerms(emb$patches, k = 40)
key    <- keyFromTerms(termScores(emb$patches, terms$centroids), images, terms)
key    <- patchExemplars(model, key, images)     # example crops for the wizard
exportWizard(key, "terms.html")

# 2. Questions from a vocabulary
vocab  <- data.frame(feature = c("round headlights", "a flat hood"),
                     opposite = c("square headlights", "a curved hood"))
txt    <- embedTexts(model, vocabularyPrompts(vocab, "a pickup truck with {x}"))
qkey   <- keyFromClusters(emb$image, images, vocab, txt, template = "a pickup truck with {x}")

# Follow a key by machine
classify(key, scoreImages(key, model, "new.png"))
```

The R side works on plain matrices, so embeddings from any other model (for
example a domain model such as BioCLIP) can be passed to `discoverTerms()`,
`keyFromTerms()`, `keyFromClusters()` and `featureScores()` directly, without
Python.

# Interoperating with phylogenetics tools

A moose key is a tree, so it can be handed to the usual phylogenetics software:

```r
k <- phylotreeKey("H2a")
toNewick(k)                         # quoted Newick, or labels = "safe" + a sidecar table
toNewick(k, annotate = "nhx")       # lead text as NHX/BEAST comments
toTreedata(k)                       # a tidytree treedata for ggtree
toIgraph(k)                         # a DAG-faithful igraph (keeps shared couplets)
toAuspiceJSON(k)                    # Nextstrain/Auspice v2 JSON
readHaplogrep("tree.xml")           # load any Haplogrep / PhyloTree tree XML
```

# Acknowledgments

Moose is built on phylo4, since it has the closest native resemblance to dichotomous trees but also borrows from data.tree and partykit.

Karl Broman's R Package Primer was useful in this process.
