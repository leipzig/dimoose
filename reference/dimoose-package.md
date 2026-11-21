# dimoose: read, build, check, prune and share dichotomous keys

A dichotomous key identifies a specimen by a series of choices. dimoose
keeps a key as a
[dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
object, a table of couplets and leads, and provides the tools around it.
`key$validate()` checks any key, however it was made.

## Where to start

- **Write a key** in a spreadsheet and read it with
  [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md);
  [`keyToSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyToSpreadsheet.md)
  writes any key back out for editing.
  [`montanaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
  [`sharkKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
  [`arachnidaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md),
  [`vibrioKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  and
  [`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)
  are example keys.

- **Read a key somebody else wrote**: plain text as printed in a flora
  ([`keyFromText()`](https://leipzig.github.io/dimoose/reference/keyFromText.md),
  [`parseTextKey()`](https://leipzig.github.io/dimoose/reference/parseTextKey.md)),
  FishBase
  ([`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md)),
  or the keys and character matrices of other identification software
  ([`readSDD()`](https://leipzig.github.io/dimoose/reference/readSDD.md),
  [`readSDDKey()`](https://leipzig.github.io/dimoose/reference/readSDDKey.md),
  [`readDELTA()`](https://leipzig.github.io/dimoose/reference/readDELTA.md),
  [`readLucid()`](https://leipzig.github.io/dimoose/reference/readLucid.md),
  [`readLucidKey()`](https://leipzig.github.io/dimoose/reference/readLucidKey.md),
  [`readXper()`](https://leipzig.github.io/dimoose/reference/readXper.md),
  each with a writer).

- **Check it**:
  [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)
  looks its names up in GBIF, and
  [`summary()`](https://rdrr.io/r/base/summary.html) and
  [`keyQuality()`](https://leipzig.github.io/dimoose/reference/keyQuality.md)
  say how many steps it takes to reach a result, optionally weighted by
  how common each taxon is
  ([`occurrenceWeights()`](https://leipzig.github.io/dimoose/reference/occurrenceWeights.md)).

- **Cut it down or join keys up**:
  [`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md)
  keeps or drops taxa,
  [`regionalKey()`](https://leipzig.github.io/dimoose/reference/regionalKey.md)
  keeps the taxa recorded in a place, and
  [`mergeKeys()`](https://leipzig.github.io/dimoose/reference/mergeKeys.md)
  grafts one key onto a result of another.

- **Generate a key from data**: from a character matrix
  ([`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md),
  or
  [`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md)
  with
  [`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md)),
  from a sequence alignment
  ([`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md)),
  or from labelled photos with a vision model
  ([`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md),
  [`embedImages()`](https://leipzig.github.io/dimoose/reference/embedImages.md),
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md),
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
  [`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md)).
  Such keys can be followed by machine with
  [`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
  and tested with
  [`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md)
  and
  [`benchmarkKey()`](https://leipzig.github.io/dimoose/reference/benchmarkKey.md).

- **Share it**:
  [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
  writes a self-contained web page that works on a phone,
  [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  draws a box diagram, and
  [`toNewick()`](https://leipzig.github.io/dimoose/reference/toNewick.md),
  [`toIgraph()`](https://leipzig.github.io/dimoose/reference/toIgraph.md),
  [`toTreedata()`](https://leipzig.github.io/dimoose/reference/toTreedata.md)
  and
  [`toAuspiceJSON()`](https://leipzig.github.io/dimoose/reference/toAuspiceJSON.md)
  hand the key to phylogenetics software.

## Vignettes

- [`vignette("montana-hardwoods", package = "dimoose")`](https://leipzig.github.io/dimoose/articles/montana-hardwoods.md):
  a key written in a spreadsheet, with photos.

- [`vignette("published-key", package = "dimoose")`](https://leipzig.github.io/dimoose/articles/published-key.md):
  from a printed key to a regional key on a phone.

- [`vignette("vision-keys", package = "dimoose")`](https://leipzig.github.io/dimoose/articles/vision-keys.md):
  keys from photos.

- [`vignette("alignment-keys", package = "dimoose")`](https://leipzig.github.io/dimoose/articles/alignment-keys.md):
  keys from aligned sequences.

## Web services and optional software

Reading, building, checking and exporting keys needs nothing beyond the
packages dimoose imports.
[`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md),
[`regionalKey()`](https://leipzig.github.io/dimoose/reference/regionalKey.md),
[`occurrenceWeights()`](https://leipzig.github.io/dimoose/reference/occurrenceWeights.md),
[`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md)
and
[`inatPhotos()`](https://leipzig.github.io/dimoose/reference/inatPhotos.md)
ask public web services (GBIF, iNaturalist, FishBase) and need an
internet connection. The vision functions run a model in Python through
the reticulate package, which sets Python up on first use;
[`saveEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md)
and
[`loadEmbeddings()`](https://leipzig.github.io/dimoose/reference/saveEmbeddings.md)
let the later steps run without it.

## See also

Useful links:

- <https://leipzig.github.io/dimoose/>

- <https://github.com/leipzig/dimoose>

- Report bugs at <https://github.com/leipzig/dimoose/issues>

## Author

**Maintainer**: Jeremy Leipzig <leipzig@gmail.com>
([ORCID](https://orcid.org/0000-0001-7224-9620))

Authors:

- Jeremy Leipzig <leipzig@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-7224-9620))
