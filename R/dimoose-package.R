#' dimoose: read, build, check, prune and share dichotomous keys
#'
#' A dichotomous key identifies a specimen by a series of choices. dimoose
#' keeps a key as a [dimoose] object, a table of couplets and leads, and
#' provides the tools around it. `key$validate()` checks any key, however it
#' was made.
#'
#' @section Where to start:
#' * **Write a key** in a spreadsheet and read it with [keyFromSpreadsheet()];
#'   [keyToSpreadsheet()] writes any key back out for editing.
#'   [montanaKey()], [sharkKey()], [arachnidaKey()], [vibrioKey()] and
#'   [phylotreeKey()] are example keys.
#' * **Read a key somebody else wrote**: plain text as printed in a flora
#'   ([keyFromText()], [parseTextKey()]), FishBase ([importFishbase()]), or
#'   the keys and character matrices of other identification software
#'   ([readSDD()], [readSDDKey()], [readDELTA()], [readLucid()],
#'   [readLucidKey()], [readXper()], each with a writer).
#' * **Check it**: [checkNames()] looks its names up in GBIF, and `summary()`
#'   and [keyQuality()] say how many steps it takes to reach a result,
#'   optionally weighted by how common each taxon is ([occurrenceWeights()]).
#' * **Cut it down or join keys up**: [pruneKey()] keeps or drops taxa,
#'   [regionalKey()] keeps the taxa recorded in a place, and [mergeKeys()]
#'   grafts one key onto a result of another.
#' * **Generate a key from data**: from a character matrix
#'   ([keyFromMatrix()], or [generateTree()] with [keyFromRpart()]), from a
#'   sequence alignment ([keyFromAlignment()]), or from labelled photos with
#'   a vision model ([visionModel()], [embedImages()], [discoverSniglets()],
#'   [keyFromSniglets()], [keyFromClusters()]). Such keys can be followed by
#'   machine with [classify()] and tested with [evaluateKey()] and
#'   [benchmarkKey()].
#' * **Share it**: [exportWizard()] writes a self-contained web page that
#'   works on a phone, [keyDiagram()] draws a box diagram, and [toNewick()],
#'   [toIgraph()], [toTreedata()] and [toAuspiceJSON()] hand the key to
#'   phylogenetics software.
#'
#' @section Vignettes:
#' * `vignette("montana-hardwoods", package = "dimoose")`: a key written in a
#'   spreadsheet, with photos.
#' * `vignette("published-key", package = "dimoose")`: from a printed key to
#'   a regional key on a phone.
#' * `vignette("vision-keys", package = "dimoose")`: keys from photos.
#' * `vignette("alignment-keys", package = "dimoose")`: keys from aligned
#'   sequences.
#'
#' @section Web services and optional software:
#' Reading, building, checking and exporting keys needs nothing beyond the
#' packages dimoose imports. [checkNames()], [regionalKey()],
#' [occurrenceWeights()], [importFishbase()] and [inatPhotos()] ask public
#' web services (GBIF, iNaturalist, FishBase) and need an internet
#' connection. The vision functions run a model in Python through the
#' reticulate package, which sets Python up on first use;
#' [saveEmbeddings()] and [loadEmbeddings()] let the later steps run without
#' it.
#'
#' @keywords internal
#' @importFrom R6 R6Class
#' @importFrom data.tree Node
"_PACKAGE"
