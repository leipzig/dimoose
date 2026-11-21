# Package index

## Keys

The dimoose key object and the ways to write or read one.

- [`dimoose`](https://leipzig.github.io/dimoose/reference/dimoose.md) :
  A dichotomous key
- [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
  : Build a key from a spreadsheet
- [`keyToSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyToSpreadsheet.md)
  : Write a key as a spreadsheet
- [`keyFromText()`](https://leipzig.github.io/dimoose/reference/keyFromText.md)
  : Read a key written as plain text
- [`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md)
  : Parse a key written as plain text into a table of leads
- [`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)
  : Build a dimoose key from a table of leads
- [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)
  : Check a key's species names against GBIF

## Exchange formats

Character matrices and keys in the formats of other identification
software: SDD (the TDWG standard), DELTA, Lucid and Xper.

- [`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
  [`writeSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md)
  : Read and write SDD (TDWG Structured Descriptive Data)
- [`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md)
  [`writeSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md)
  : Read and write a dichotomous key stored in SDD
- [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md)
  [`writeDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md)
  : Read and write DELTA datasets
- [`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
  [`writeLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md)
  : Read and write Lucid matrix keys
- [`readLucidKey()`](https://leipzig.github.io/dimoose/reference/readLucidKey.md)
  [`writeLucidKey()`](https://leipzig.github.io/dimoose/reference/readLucidKey.md)
  : Read and write Lucid pathway (dichotomous) keys
- [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md)
  [`writeXper()`](https://leipzig.github.io/dimoose/reference/readXper.md)
  : Read and write Xper2 / Xper3 knowledge bases

## FishBase

- [`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md)
  : Import a dichotomous key from FishBase
- [`parseFishbase()`](https://leipzig.github.io/dimoose/reference/parseFishbase.md)
  : Build a dimoose object from FishBase key pages
- [`rawhtml`](https://leipzig.github.io/dimoose/reference/rawhtml.md) :
  Raw FishBase key tables

## Building keys from a matrix

A key generated from a table of taxa and their characters.

- [`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
  : Build a dimoose key from a character matrix
- [`vibrioMatrix()`](https://leipzig.github.io/dimoose/reference/vibrioMatrix.md)
  : The vibrio dataset as a character matrix
- [`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md)
  : Generate a tree from a feature matrix
- [`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)
  : Build a dimoose key from a classification tree

## Pruning and merging

Cut a key down to some taxa or to a place, or join two keys.

- [`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md)
  : Prune a key to some of its taxa
- [`regionalKey()`](https://leipzig.github.io/dimoose/reference/regionalKey.md)
  : A key to the taxa recorded in a place
- [`mergeKeys()`](https://leipzig.github.io/dimoose/reference/mergeKeys.md)
  : Graft one key onto a result of another

## Quality

How many steps a key takes, and how common each taxon is.

- [`keyQuality()`](https://leipzig.github.io/dimoose/reference/keyQuality.md)
  : How quickly a key gets to a result
- [`occurrenceWeights()`](https://leipzig.github.io/dimoose/reference/occurrenceWeights.md)
  : How common each taxon of a key is, from GBIF occurrence records

## Show and share a key

The interactive page (wizard), diagrams and tree formats.

- [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
  : Export an interactive dichotomous key
- [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  : Draw a key as a box diagram
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

## Vision: models and embeddings

Vision models (PyTorch or ONNX Runtime), photos and their embeddings.

- [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)
  : Load a vision model for embedding images
- [`onnxModel()`](https://leipzig.github.io/dimoose/reference/onnxModel.md)
  : Load a vision model that runs on ONNX Runtime, without PyTorch
- [`onnxCache()`](https://leipzig.github.io/dimoose/reference/onnxCache.md)
  : Folder where dimoose keeps downloaded and converted ONNX models
- [`exportOnnxModel()`](https://leipzig.github.io/dimoose/reference/exportOnnxModel.md)
  : Convert an open_clip model to ONNX
- [`exportBrowserModel()`](https://leipzig.github.io/dimoose/reference/exportBrowserModel.md)
  : Write what a web page needs to identify photos with a key's species
- [`modelMeta()`](https://leipzig.github.io/dimoose/reference/modelMeta.md)
  : Model details as metadata rows
- [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  : A set of labelled images
- [`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md)
  : Embed images in a key's metadata
- [`imageMime()`](https://leipzig.github.io/dimoose/reference/imageMime.md)
  : MIME type of an image file from its first bytes
- [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md)
  : Embed images
- [`embedTexts()`](https://leipzig.github.io/dimoose/reference/embedTexts.md)
  : Embed texts
- [`saveEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md)
  [`loadEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md)
  : Save embeddings to a file, and read them back

## Vision: keys from photos

- [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  [`discoverTerms()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  : Discover sniglets by clustering patch embeddings
- [`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
  [`termScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md)
  : Score images against sniglets
- [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
  [`keyFromTerms()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md)
  : Build a key from sniglet scores
- [`snigletNames()`](https://leipzig.github.io/dimoose/reference/snigletNames.md)
  : Names of a key's sniglets
- [`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
  : Rename sniglets
- [`suggestSnigletNames()`](https://leipzig.github.io/dimoose/reference/suggestSnigletNames.md)
  : Have a vision-language model suggest names for sniglets
- [`claudeNamer()`](https://leipzig.github.io/dimoose/reference/claudeNamer.md)
  : A sniglet namer that asks Claude
- [`inventNames()`](https://leipzig.github.io/dimoose/reference/inventNames.md)
  : Invent pronounceable names
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

## Benchmark

Identification measured on field photos from iNaturalist.

- [`inatPhotos()`](https://leipzig.github.io/dimoose/reference/inatPhotos.md)
  : Download a balanced sample of iNaturalist photos
- [`splitByObservation()`](https://leipzig.github.io/dimoose/reference/splitByObservation.md)
  : Split photos into training and test sets by observation
- [`benchmarkKey()`](https://leipzig.github.io/dimoose/reference/benchmarkKey.md)
  : Benchmark identification on field photos

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
