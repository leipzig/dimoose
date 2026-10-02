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
- **generate keys automatically** from a pile of labelled photos with a vision model (CLIP, or any model that produces embeddings) or from a multiple sequence alignment with a phylogeny program, and **follow those keys by machine**
- produce training data for machine learning using splits
- interoperate with the phylogenetics ecosystem (`ggtree`/`treeio`, `igraph`, Nextstrain/Auspice, Haplogrep)
- metadata slots for provenance and supporting guide images
- perform basic lexical analysis, and specialized data types (single nucleotide variations) of criteria and taxa
- build mixed effects conditional inference trees (mecits)

# Getting started

## Installation

moose is installed from GitHub:

```r
install.packages("remotes")
remotes::install_github("leipzig/moose")
```

That is enough to read, build, check and export keys. Some features use
optional packages, which are only needed if you use that feature:

| Feature | Also needs |
|---|---|
| Keys from a sequence alignment (`keyFromAlignment()`) | `ape`, and `phangorn` for midpoint rooting, UPGMA, parsimony, maximum likelihood and proteins |
| Keys from photos (`visionModel()`, `embedImages()`) | `reticulate`, and Python with open_clip (see [From a pile of photos](#from-a-pile-of-photos)) |
| Phylogenetics exports (`toTreedata()`, `toIgraph()`, `toAuspiceJSON()`) | `tidytree`, `tibble` and `ape`; `igraph`; `jsonlite` |

To install all of the optional R packages at once, and build the vignettes:

```r
remotes::install_github("leipzig/moose", dependencies = TRUE, build_vignettes = TRUE)
```

## A first key

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

# Automated key generation

Most keys are written by people. moose can also generate one from data: from
a multiple sequence alignment, or from a pile of photos. Either way the result
is an ordinary moose key that works with `exportWizard()`, `classify()` and
the phylogenetics exports.

## From a multiple sequence alignment

One command takes aligned sequences to a key. A phylogeny program builds the
tree, moose roots it, and every fork becomes a couplet whose leads are the
alignment sites that tell its two sides apart:

```r
library(moose)
key <- keyFromAlignment("aligned.fasta")           # a FASTA file, or an ape/phangorn object
exportWizard(key, "key.html")

# a runnable example: 15 wood mouse cytochrome b sequences from ape
data(woodmouse, package = "ape")
key <- keyFromAlignment(woodmouse)
head(key$leads[, c("Statement", "Character", "Next", "Taxon")], 4)
#>   Statement      Character Next   Taxon
#> 1         1       106G 35G    2
#> 2         1       106A 35A    3
#> 3         2 201T 234C 297G    -   No305
#> 4         2 201C 234T 297A    - No1114S
```

Options:

- **The phylogeny program** is chosen with `tool`: `"nj"` (the default) and `"bionj"` use
  `ape`; `"upgma"`, `"parsimony"` and `"ml"` use `phangorn`; `"fasttree"` and
  `"iqtree"` run the FastTree or IQ-TREE program if it is installed.
- **A tree from any other program** goes in as `tree = "my.nwk"`.
- **The root** is the `outgroup` you name, or the midpoint.
- **Site numbers** are alignment columns, or positions in a `reference` sequence.
- **New sequences** are placed with `classify(key, alignmentScores(key, new))`.

See the [alignment vignette](vignettes/alignment-keys.Rmd).

## From a pile of photos

You need photos, a label for each one saying what it shows, and Python with
open_clip (CLIP ViT-B/32 by default):

```sh
pip install -r "$(Rscript -e 'cat(system.file("python/requirements.txt", package="moose"))')"
```

Then it is five steps:

```r
library(moose)

# 1. Photos and labels. With one folder per class (pics/cardinal/..., pics/robin/...),
#    each photo is labelled by its folder.
images <- imageSet("pics")
#    Class in the file name:  imageSet("pics", label = function(x) sub("_.*$", "", x))
#    Labels in a table:       imageSet(tab$file, label = tab$species)

# 2. A vision model
model  <- visionModel()                          # or visionModel("ViT-B-32.pt")

# 3. Photos -> embeddings
emb    <- embedImages(model, images)

# 4. Generate sniglets (recurring visual features, each given a coined name)
#    and grow a key on them
sniglets <- discoverSniglets(emb$patches, k = 40)
scores   <- snigletScores(emb$patches, sniglets$centroids)
key      <- keyFromSniglets(scores, images, sniglets, method = "rpart")

# 5. Add example crops and export an interactive page
key    <- patchExemplars(model, key, images)
exportWizard(key, "key.html")

# Identify a new photo with the key
classify(key, scoreImages(key, model, "new.jpg"))
```

With one photo per class, use the default `method = "balanced"` in step 4
(the [fordera](https://github.com/leipzig/fordera) method).

### Sniglets, and renaming them

The features in step 4 are found by the model, by clustering patches of the
photos, so they have no names. moose coins a pronounceable word for each one
(`smeinfisshiesk`, `treuxraikbluk`) and calls these **sniglets**. A lead reads
"Has smeinfisshiesk", and the wizard's glossary shows the image crops that define
it. Once you have looked at the crops, give the sniglets real names:

```r
snigletNames(key)                 # coined word, current name, definition, used by the key?

key <- renameSniglets(key, c(smeinfisshiesk = "an egg-crate grille"),
                      definitions = c(smeinfisshiesk = "A grid of small square openings between the headlights"))

# or name them in a spreadsheet
write.csv(snigletNames(key), "names.csv", row.names = FALSE)   # fill in name and definition
key <- renameSniglets(key, "names.csv")
exportWizard(key, "key.html")     # leads now read "Has an egg-crate grille"
```

The coined word stays as the sniglet's permanent identifier: scores, machine
tests and saved name tables keep working after a rename, and a blank name
puts the coined word back. Only the names of sniglets the key uses matter.

### Questions from a vocabulary

To ask questions in plain words from the start, give a vocabulary of
contrasting features instead:

```r
vocab  <- data.frame(feature = c("round headlights", "a flat hood"),
                     opposite = c("square headlights", "a curved hood"))
txt    <- embedTexts(model, vocabularyPrompts(vocab, "a pickup truck with {x}"))
qkey   <- keyFromClusters(emb$image, images, vocab, txt, template = "a pickup truck with {x}")
```

The [photo vignette](vignettes/vision-keys.Rmd) explains each step, and how
to measure a key's accuracy.

The R side works on plain matrices, so embeddings from any other model (for
example a domain model such as BioCLIP) can be passed to `discoverSniglets()`,
`keyFromSniglets()`, `keyFromClusters()` and `featureScores()` directly, without
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

The bundled PhyloTree Build 17 is taken from [Haplogrep](https://haplogrep.i-med.ac.at/), whose tree files and documentation of PhyloTree's notation made the PhyloTree key possible. Thanks to the Haplogrep authors at the Institute of Genetic Epidemiology, Medical University of Innsbruck:

- Kloss-Brandstätter A, Pacher D, Schönherr S, Weissensteiner H, Binna R, Specht G, Kronenberg F (2011). HaploGrep: a fast and reliable algorithm for automatic classification of mitochondrial DNA haplogroups. *Human Mutation* 32, 25–32. [doi:10.1002/humu.21382](https://doi.org/10.1002/humu.21382)
- Weissensteiner H, Pacher D, Kloss-Brandstätter A, Forer L, Specht G, Bandelt H-J, Kronenberg F, Salas A, Schönherr S (2016). HaploGrep 2: mitochondrial haplogroup classification in the era of high-throughput sequencing. *Nucleic Acids Research* 44, W58–W63.
- Schönherr S, Weissensteiner H, Kronenberg F, Forer L (2023). Haplogrep 3 – an interactive haplogroup classification and analysis platform. *Nucleic Acids Research* 51, W263–W268. [doi:10.1093/nar/gkad284](https://doi.org/10.1093/nar/gkad284)

and to Mannis van Oven for PhyloTree itself.

The image-based key work builds on the [Imageomics Institute](https://imageomics.osu.edu/) and the NSF HDR-BGNN (Harnessing the Data Revolution — Biology-Guided Neural Networks) effort, whose BioCLIP and TreeOfLife models make domain-specific biological embeddings possible.

Karl Broman's R Package Primer was useful in this process.

Moose was built in Whitefish, Montana.
