# dimoose 0.2.0

* `checkNames()` looks up every scientific name in a key in the GBIF backbone
  taxonomy and reports misspellings ("did you mean *Fraxinus
  pennsylvanica*?"), outdated synonyms ("GBIF accepts *Ulmus rubra*") and
  unknown names, with each name's genus, family and order. It needs an
  internet connection but no extra packages.
* `keyFromSpreadsheet(checkNames = TRUE)` runs that check and warns about
  problems by spreadsheet row.
* `suggestSpecies()` ranks a key's own species against a photo by their
  scientific names, with no example photos needed. It works best with
  BioCLIP 2 (`visionModel(name = "bioclip-2")`).
* `identifyPhotos()` gives one answer per photo: the species when it is likely
  enough, otherwise the genus, family or order whose species together are.
  On the 14 Montana photos with BioCLIP 2 it named 12 to species and the
  other two to the right genus, with no wrong answers.

# dimoose 0.1.2

* `keyDiagram()` also writes `.png` and `.pdf` files when the 'rsvg' package
  is installed.
* With the 'magick' package installed, `keyDiagram()` shrinks thumbnails to
  112 px and `imageMeta()` (and so `keyFromSpreadsheet()`) scales photos down
  to at most 1200 px (`maxSize`), so keys made from camera photos stay small.
  The Montana diagram drops from 1.2 MB to 83 KB.
* `keyDiagram()` sets the part of a result in parentheses in italics only when
  it is a scientific name: parsed by gnparser when 'rgnparser' is installed,
  otherwise a capitalised genus and lower-case epithets. "Willows (several
  species)" stays upright.

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
