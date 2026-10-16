# dimoose 0.1.1

* `keyFromSpreadsheet()` builds a key from a plain CSV spreadsheet (one row
  per lead, with optional questions and photos) and reports mistakes by
  spreadsheet row.
* `keyDiagram()` draws any key as a top-down box diagram (SVG), with photos
  in the result boxes.
* New vignette, "A photo key to Montana's broadleaf trees", including how to
  make your own key from a spreadsheet.
* `montanaKey()` and the `montana` dataset: a key to the eleven native
  broadleaf trees of Montana with photos from Wikimedia Commons, kept as a
  spreadsheet template in `inst/extdata/montana/`.

# dimoose 0.1.0

* First release.
* Renamed from moose, because CRAN has an unrelated package of that name.
  The key class is now `dimoose` (`dimoose$new()`, `inherits(x, "dimoose")`),
  the S3 classes are `dimooseVisionModel`, `dimooseTerms` and
  `dimooseSniglets`, the vision tests read `DIMOOSE_CLIP_WEIGHTS`, and the
  repository is <https://github.com/leipzig/dimoose>. The first argument of
  `exportWizard()` is now `key`.
* Dichotomous keys as `dimoose` objects: build them from lead tables
  (`keyFromLeads()`), classification trees (`keyFromRpart()`,
  `generateTree()`) or FishBase (`importFishbase()`, `parseFishbase()`), then
  validate, summarise and convert them to `data.tree`, Newick, igraph,
  `treedata` and Auspice JSON.
* Example keys and datasets: sharks (FishBase key 1), Arachnida orders,
  *Vibrio* (Noguerola & Blanch 2008) and PhyloTree Build 17.
* `exportWizard()` writes a self-contained, mobile-friendly HTML key.
* Automated key generation from photos: sniglets, recurring visual features
  given coined names (`discoverSniglets()`, `keyFromSniglets()`) that can be
  renamed afterwards (`renameSniglets()`); vocabulary questions
  (`keyFromClusters()`); machine classification and evaluation (`classify()`,
  `evaluateKey()`, `looKey()`); and an optional open_clip vision layer through
  reticulate (`visionModel()`), including BioCLIP.
* Automated key generation from a multiple sequence alignment
  (`keyFromAlignment()`), with the tree built by ape, phangorn, FastTree or
  IQ-TREE.
* Mixed-effects conditional inference trees (`mecit()`, `keyFromMecit()`) and
  simulated expression data on PhyloTree (`simulateExpression()`).
