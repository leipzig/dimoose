# moose <img src="man/figures/logo.svg" align="right" height="139" alt="moose logo" />

An R package to manage dichotomous keys.

## Dichotomous keys

Dichotomous keys are bifurcating trees that are often used in species identification. More precisely, dichotomous keys are binary categorical decision trees with unique leaves. They have been a staple of taxonomic identification for centuries — Lamarck's *Flore française* (1778) is often credited with popularizing the form — and remain in everyday use in field guides and laboratory manuals today.

### Relationship to phylogenetic trees

Despite their different uses, phylogenetic trees are similar to dichotomous keys:
- the paths are traversed using mutation "decisions" instead of visible phenotypes
- all points on a phylogenetic tree represent an organism that actually existed (instead of a group of possibilities)

Moose supports phylogenetic trees in which the mutations are known, such as PhyloTree, and ships PhyloTree Build 17 (the human mitochondrial DNA phylogeny, as distributed by Haplogrep 3).

## Package methods

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

```r
library(moose)
sharks <- sharkKey()
summary(sharks)
exportWizard(sharks, "sharks.html")   # an interactive, self-contained wizard
```

There are vignettes on the package basics, example applications, and [building keys from images](vignettes/vision-keys.Rmd).

## Included datasets

Four example keys ship with the package. They come from very different sources and are built in different ways, but they are all ordinary moose objects: they share the same fields (`leads`, `df`, `meta`, `taxa`, `desc`) and methods (`print()`, `summary()`, `validate()`, `toDataTree()`, `toNewick()`) and all work with `exportWizard()` and the phylogenetics exports.

### Sharks — `sharkKey()`

FishBase key 1, the *Key to the families of sharks in the Western Central Pacific* (Compagno 1998), parsed from saved FishBase pages in `inst/extdata/fishbase/`. A classic, human-authored morphological key: **23 couplets, 24 families**. It carries guide-image links, so the exported wizard shows a figure at each lead. This is the key the `importFishbase()` / `parseFishbase()` machinery produces from a live or saved FishBase page.

### Arachnids — `arachnidaKey()` (dataset `arachnida`)

The *Key to the Orders of Arachnida* from Triplehorn & Johnson (2005), *Borror and DeLong's Introduction to the Study of Insects*, 7th ed., transcribed by hand (see `data-raw/arachnida/`). **11 couplets, 11 orders** (Schizomida is reached from two couplets, so it is a small DAG rather than a strict tree). The `arachnida` dataset is the underlying table of leads; `keyFromLeads()` turns it into the key.

### Vibrio — `vibrioKey()` (dataset `vibrio`)

A key **generated** from a biochemical consensus matrix rather than written by a person. The `vibrio` dataset is the identification matrix of Noguerola & Blanch (2008), **74 taxa × 45 tests** (`+`/`-`/`(+)`/`(-)`/`v`/`ND`). `vibrioKey()` scores the tests, fits an `rpart` classification tree, and converts it with `keyFromRpart()` into a **73-couplet** key reaching all 74 species. Species the tests cannot separate share a result. This is the template for turning any feature matrix into a dichotomous key.

### PhyloTree — `phylotreeKey()` (datasets `phylotree17`, `phylotree17_mutations`)

PhyloTree Build 17, the human mitochondrial DNA phylogeny (van Oven 2015), as distributed by Haplogrep 3: **5,435 haplogroups** and **13,384 mutations**. `phylotree17` is one row per haplogroup (name, parent, depth, subclade count, mutations); `phylotree17_mutations` is one row per mutation (position, type, ancestral/derived base). `phylotreeKey()` turns the tree, or any subtree, into a key whose "characters" are the defining mutations — for example `phylotreeKey("H2a")`. The full tree is large (2,420 steps), so a subtree or a `maxDepth` is usually more practical for the wizard. This is the "phylogenetic tree as a key" case, where the decisions are mutations rather than visible phenotypes.

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

FishBase key import is made possible by the work of Scott Chamberlain and Carl Boettiger on rOpenSci's `rfishbase` and the R tooling for FishBase data.

The image-based key work builds on the [Imageomics Institute](https://imageomics.osu.edu/) and the NSF HDR-BGNN (Harnessing the Data Revolution — Biology-Guided Neural Networks) effort, whose BioCLIP and TreeOfLife models make domain-specific biological embeddings possible.

Karl Broman's R Package Primer was useful in this process.
