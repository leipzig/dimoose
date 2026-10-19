# Package index

## Keys

The dimoose key object and the ways to build one.

- [`dimoose`](https://leipzig.github.io/dimoose/reference/dimoose.md) :
  A dichotomous key
- [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
  : Build a key from a spreadsheet
- [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)
  : Check a key's species names against GBIF
- [`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)
  : Build a dimoose key from a table of leads
- [`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)
  : Build a dimoose key from a classification tree
- [`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md)
  : Generate a tree from a feature matrix

## Show and share a key

- [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  : Draw a key as a box diagram
- [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
  : Export an interactive dichotomous key
- [`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md)
  : Write a key as Newick, with safe labels or node annotations
- [`toIgraph()`](https://leipzig.github.io/dimoose/reference/toIgraph.md)
  : Convert a key to an igraph directed graph
- [`toTreedata()`](https://leipzig.github.io/dimoose/reference/toTreedata.md)
  : Convert a key to a tidytree treedata (for ggtree)
- [`toAuspiceJSON()`](https://leipzig.github.io/dimoose/reference/toAuspiceJSON.md)
  : Export a key as Auspice (Nextstrain) JSON v2

## Example keys and data

- [`sharkKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  [`arachnidaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  [`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  [`montanaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  : Example keys
- [`montana`](https://leipzig.github.io/dimoose/reference/montana.md) :
  Key to the native broadleaf trees of Montana
- [`arachnida`](https://leipzig.github.io/dimoose/reference/arachnida.md)
  : Key to the Orders of Arachnida
- [`vibrio`](https://leipzig.github.io/dimoose/reference/vibrio.md) :
  Vibrio consensus identification matrix
- [`phylotree17`](https://leipzig.github.io/dimoose/reference/phylotree17.md)
  : PhyloTree Build 17: the human mitochondrial DNA phylogeny
- [`phylotree17_mutations`](https://leipzig.github.io/dimoose/reference/phylotree17_mutations.md)
  : PhyloTree Build 17 mutations, one per row
- [`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)
  : Build an identification key from PhyloTree Build 17

## FishBase

- [`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md)
  : Import a dichotomous key from FishBase
- [`parseFishbase()`](https://leipzig.github.io/dimoose/reference/parseFishbase.md)
  : Build a dimoose object from FishBase key pages
- [`rawhtml`](https://leipzig.github.io/dimoose/reference/rawhtml.md) :
  Raw FishBase key tables

## Keys from photos

- [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)
  : Load a vision model for embedding images
- [`modelMeta()`](https://leipzig.github.io/dimoose/reference/modelMeta.md)
  : Model details as metadata rows
- [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
  : Embed images
- [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
  : Embed texts
- [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  : A set of labelled images
- [`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md)
  : Embed images in a key's metadata
- [`imageMime()`](https://leipzig.github.io/dimoose/reference/imageMime.md)
  : MIME type of an image file from its first bytes
- [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  [`discoverTerms()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  : Discover sniglets by clustering patch embeddings
- [`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
  [`termScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
  : Score images against sniglets
- [`snigletNames()`](https://leipzig.github.io/dimoose/reference/snigletNames.md)
  : Names of a key's sniglets
- [`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
  : Rename sniglets
- [`inventNames()`](https://leipzig.github.io/dimoose/reference/inventNames.md)
  : Invent pronounceable names
- [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
  [`keyFromTerms()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
  : Build a key from sniglet scores
- [`vocabularyPrompts()`](https://leipzig.github.io/dimoose/reference/vocabularyPrompts.md)
  : Prompts for a vocabulary of visual features
- [`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md)
  : Build a key by clustering classes and describing each split
- [`patchExemplars()`](https://leipzig.github.io/dimoose/reference/patchExemplars.md)
  : Add example crops to a sniglet key
- [`scoreImages()`](https://leipzig.github.io/dimoose/reference/scoreImages.md)
  : Score new images against a key's features
- [`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md)
  : Suggest which of a key's species a photo shows
- [`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md)
  : Name what a photo shows, as precisely as the evidence allows
- [`featureTable()`](https://leipzig.github.io/dimoose/reference/featureTable.md)
  : A table of machine-computable features
- [`featureScores()`](https://leipzig.github.io/dimoose/reference/featureScores.md)
  : Compute a key's feature scores from embeddings
- [`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
  : Follow a key by machine
- [`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md)
  : Accuracy of a key followed by machine
- [`looKey()`](https://leipzig.github.io/dimoose/reference/looKey.md) :
  Leave-one-out evaluation of a key builder

## Keys from sequences and haplogroups

- [`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md)
  : Build a key from a multiple sequence alignment
- [`alignmentScores()`](https://leipzig.github.io/dimoose/reference/alignmentScores.md)
  : Score aligned sequences against a key built from an alignment
- [`readHaplogrep()`](https://leipzig.github.io/dimoose/reference/readHaplogrep.md)
  : Read a Haplogrep / PhyloTree tree XML
- [`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md)
  : Which mutations each haplogroup carries
- [`macroHaplogroup()`](https://leipzig.github.io/dimoose/reference/macroHaplogroup.md)
  : Macrohaplogroup of a haplogroup
- [`recurrentPositions()`](https://leipzig.github.io/dimoose/reference/recurrentPositions.md)
  : Recurrent (homoplasic) mutation sites

## Mixed-effects trees

- [`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md) :
  Mixed-effects conditional inference trees
- [`keyFromMecit()`](https://leipzig.github.io/dimoose/reference/keyFromMecit.md)
  : Turn a mixed-effects tree into a key
- [`simulateExpression()`](https://leipzig.github.io/dimoose/reference/simulateExpression.md)
  : Simulate expression data on PhyloTree
- [`splitVariables()`](https://leipzig.github.io/dimoose/reference/splitVariables.md)
  : Variables a fitted tree splits on
