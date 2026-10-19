# Changelog

## dimoose 0.2.0

- [`checkNames()`](https://leipzig.github.io/dimoose/reference/checkNames.md)
  looks up every scientific name in a key in the GBIF backbone taxonomy
  and reports misspellings (“did you mean *Fraxinus pennsylvanica*?”),
  outdated synonyms (“GBIF accepts *Ulmus rubra*”) and unknown names,
  with each name’s genus, family and order. It needs an internet
  connection but no extra packages.
- `keyFromSpreadsheet(checkNames = TRUE)` runs that check and warns
  about problems by spreadsheet row.
- [`suggestSpecies()`](https://leipzig.github.io/dimoose/reference/suggestSpecies.md)
  ranks a key’s own species against a photo by their scientific names,
  with no example photos needed. It works best with BioCLIP 2
  (`visionModel(name = "bioclip-2")`).
- [`identifyPhotos()`](https://leipzig.github.io/dimoose/reference/identifyPhotos.md)
  gives one answer per photo: the species when it is likely enough,
  otherwise the genus, family or order whose species together are. On
  the 14 Montana photos with BioCLIP 2 it named 12 to species and the
  other two to the right genus, with no wrong answers.

## dimoose 0.1.2

- [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  also writes `.png` and `.pdf` files when the ‘rsvg’ package is
  installed.
- With the ‘magick’ package installed,
  [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  shrinks thumbnails to 112 px and
  [`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md)
  (and so
  [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md))
  scales photos down to at most 1200 px (`maxSize`), so keys made from
  camera photos stay small. The Montana diagram drops from 1.2 MB to 83
  KB.
- [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  sets the part of a result in parentheses in italics only when it is a
  scientific name: parsed by gnparser when ‘rgnparser’ is installed,
  otherwise a capitalised genus and lower-case epithets. “Willows
  (several species)” stays upright.

## dimoose 0.1.1

- [`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md)
  builds a key from a plain CSV spreadsheet (one row per lead, with
  optional questions and photos) and reports mistakes by spreadsheet
  row.
- [`keyDiagram()`](https://leipzig.github.io/dimoose/reference/keyDiagram.md)
  draws any key as a top-down box diagram (SVG), with photos in the
  result boxes.
- New vignette, “A photo key to Montana’s broadleaf trees”, including
  how to make your own key from a spreadsheet.
- [`montanaKey()`](https://leipzig.github.io/dimoose/reference/exampleKeys.md)
  and the `montana` dataset: a key to the eleven native broadleaf trees
  of Montana with photos from Wikimedia Commons, kept as a spreadsheet
  template in `inst/extdata/montana/`.

## dimoose 0.1.0

- First release.
- Renamed from moose, because CRAN has an unrelated package of that
  name. The key class is now `dimoose` (`dimoose$new()`,
  `inherits(x, "dimoose")`), the S3 classes are `dimooseVisionModel`,
  `dimooseTerms` and `dimooseSniglets`, the vision tests read
  `DIMOOSE_CLIP_WEIGHTS`, and the repository is
  <https://github.com/leipzig/dimoose>. The first argument of
  [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
  is now `key`.
- Dichotomous keys as `dimoose` objects: build them from lead tables
  ([`keyFromLeads()`](https://leipzig.github.io/dimoose/reference/keyFromLeads.md)),
  classification trees
  ([`keyFromRpart()`](https://leipzig.github.io/dimoose/reference/keyFromRpart.md),
  [`generateTree()`](https://leipzig.github.io/dimoose/reference/generateTree.md))
  or FishBase
  ([`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md),
  [`parseFishbase()`](https://leipzig.github.io/dimoose/reference/parseFishbase.md)),
  then validate, summarise and convert them to `data.tree`, Newick,
  igraph, `treedata` and Auspice JSON.
- Example keys and datasets: sharks (FishBase key 1), Arachnida orders,
  *Vibrio* (Noguerola & Blanch 2008) and PhyloTree Build 17.
- [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
  writes a self-contained, mobile-friendly HTML key.
- Automated key generation from photos: sniglets, recurring visual
  features given coined names
  ([`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md),
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md))
  that can be renamed afterwards
  ([`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md));
  vocabulary questions
  ([`keyFromClusters()`](https://leipzig.github.io/dimoose/reference/keyFromClusters.md));
  machine classification and evaluation
  ([`classify()`](https://leipzig.github.io/dimoose/reference/classify.md),
  [`evaluateKey()`](https://leipzig.github.io/dimoose/reference/evaluateKey.md),
  [`looKey()`](https://leipzig.github.io/dimoose/reference/looKey.md));
  and an optional open_clip vision layer through reticulate
  ([`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)),
  including BioCLIP.
- Automated key generation from a multiple sequence alignment
  ([`keyFromAlignment()`](https://leipzig.github.io/dimoose/reference/keyFromAlignment.md)),
  with the tree built by ape, phangorn, FastTree or IQ-TREE.
- Mixed-effects conditional inference trees
  ([`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md),
  [`keyFromMecit()`](https://leipzig.github.io/dimoose/reference/keyFromMecit.md))
  and simulated expression data on PhyloTree
  ([`simulateExpression()`](https://leipzig.github.io/dimoose/reference/simulateExpression.md)).
