# Changelog

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
