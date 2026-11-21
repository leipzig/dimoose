# dimoose 0.3.0 (development version)

## Breaking changes

* `mecit()`, `keyFromMecit()`, `splitVariables()` and `simulateExpression()`
  have moved to the companion package
  [mecit](https://github.com/leipzig/mecit), with their vignette and
  simulation study. `haplotypeMatrix()`, `recurrentPositions()` and
  `macroHaplogroup()` stay in dimoose.
* `vibrioKey()` gains `variable = c("both", "missing")` and now defaults to
  `"both"`: species with variable or undetermined test results are reached
  down both leads (92 couplets instead of 73; 14 species have two or three
  results). `vibrioKey(variable = "missing")` returns the previous
  rpart-based key unchanged.
* `generateTree()` now defaults to
  `rpart.control(minsplit = 2, minbucket = 1, cp = 0)`; rpart's own defaults
  made no split on a matrix with one row per taxon.
* `exportWizard(order = )` is deprecated and ignored; `"parsimony"` (never
  implemented) now warns instead of stopping. To ask the easiest questions
  first, build the key with `keyFromMatrix(characters = )` and give the
  characters a `Cost`.
* The licence is now stated as `GPL (>= 3)`; it was the unversioned `GPL`.

## Reading keys and matrices

* `keyFromText()` reads keys written as plain text (bracketed or indented
  layouts; `1a`/`1b`, primes, dashes, `A.`/`AA.`, back-references such as
  `3(1).`; dot leaders, tabs or gaps before the destination; wrapped leads,
  page headers) and builds a checked dimoose key.
* `parseTextKey()` returns the lead table and a report of problems, repairs
  and notes, each with its line number; `strict = TRUE` stops instead of
  repairing OCR noise.
* Both accept `llm`, a user-supplied function for a first pass over messy
  scans; its answer is checked against the source and mistakes are reported
  by line. dimoose calls no model itself.
* Example text keys are in `inst/extdata/textkeys/`.
* `readSDD()` and `writeSDD()` read and write TDWG SDD 1.1 (Structured
  Descriptive Data) as a character matrix: categorical, quantitative and text
  characters, variable taxa, not-applicable codings, dependency rules and
  ratings.
* `readSDDKey()` and `writeSDDKey()` read and write dichotomous keys stored
  in SDD (`<IdentificationKey>`), following subkeys; `writeSDD(key = )`
  stores a matrix and a key in one file.
* `readDELTA()` and `writeDELTA()` read and write DELTA datasets (specs,
  chars and items files), including implicit values, dependent characters,
  variant items and comments.
* `readLucid()` and `writeLucid()` exchange matrix keys with Lucid through
  the Builder's CSV format and SDD; `readLucid()` also reads the multistate
  scores of LIF3 files.
* `readLucidKey()` and `writeLucidKey()` read and write Lucid pathway keys as
  Lucid Phoenix XML (.lpxk), CSV, text and SDD.
* `readXper()` and `writeXper()` exchange knowledge bases with Xper2/Xper3
  through their SDD export.
* Small example files for these formats are in `inst/extdata/tdwg/`. Files
  written by dimoose have not yet been opened in Lucid, Xper or a DELTA
  program.
* `keyToSpreadsheet()` writes a key as the CSV that `keyFromSpreadsheet()`
  reads, with embedded photos written out as files, so imported or generated
  keys can be edited by hand and read back.
* `keyFromSpreadsheet()` keeps web addresses in the `Photo` column as links,
  and a `#` in a cell no longer hides the rest of the row from the
  too-many-cells check.

## Keys from a character matrix

* `keyFromMatrix()` builds a key from a taxon-by-character matrix. A taxon
  that is variable for a character (`"+/-"`) or unknown (`NA`) is keyed out
  down both leads of every couplet that uses it, so every state a specimen
  can show ends at its taxon. Multi-state characters are keyed out one state
  at a time; taxa that cannot be separated share a result.
* `keyFromMatrix()` takes an optional `characters` table: `Cost` makes cheap
  characters come first (the split with the most separated pairs of taxa per
  unit cost is chosen), and `season` keeps only characters observable in that
  season, e.g. `season = "winter"` for a bark and twig key.
* `vibrioMatrix()` returns the `vibrio` dataset as a character matrix for
  `keyFromMatrix()`.

## Pruning, merging and quality

* `pruneKey()` keeps or drops named taxa, removes dead leads and collapses
  couplets that no longer split anything, optionally renumbering in reading
  order; the confirming character of a collapsed couplet is kept in a `Note`
  column.
* `regionalKey()` prunes a key to the taxa recorded in a place according to
  GBIF (GADM region, country, polygon or place name) or iNaturalist, with a
  minimum record count and an auditable table of counts in
  `attr(x, "records")`.
* `mergeKeys()` grafts one key onto a terminal taxon of another, combining
  leads, metadata, images, taxa and features.
* `summary()` on a key now reports how quickly it reaches a result: mean
  steps over terminal leads and over taxa, expected steps weighted by how
  common each taxon is (`summary(key, weights = )`), the steps the best
  possible key to the same taxa would need (`bound`) and an efficiency ratio;
  `print()` shows the mean steps.
* `keyQuality()` returns the detail: steps per taxon and per terminal lead,
  bound, efficiency, entropy and bits per step, for keys with multi-lead
  couplets, taxa keyed out more than once and reticulate keys.
* `occurrenceWeights()` counts GBIF occurrence records per taxon of a key,
  optionally within a country or GADM region, for use as weights.

## The interactive page

* `exportWizard()`: every couplet has an "I'm not sure" choice (keys `u` or
  `?`) that follows all its leads; the page tracks the open branches, counts
  and maps the taxa possible in any of them, and lists the candidates if the
  reader stays unsure. Back undoes one step, and the address records the open
  branches.
* `exportWizard(matrix = , characters = )`: with a character matrix the page
  also offers "pick any character you can see", cheapest characters first,
  with variable (`"a/b"`) and unknown (`NA`) states handled;
  `exportWizard(NULL, matrix = )` makes a multi-access page without a key.
* `exportWizard(offline = TRUE)` writes a web app manifest, a service worker
  and icons next to the page, so the key can be installed on a phone and
  opened without a connection (needs https or localhost).
* The exported page defines `window.dimoose` (`taxa`, `highlight()`,
  `goToTaxon()`, `state()`, `onChange()`) so other scripts, such as
  in-browser photo identification, can mark likely taxa on the map and in
  candidate lists.
* `exportWizard(photoModel = )`, given a folder written by
  `exportBrowserModel()`, adds "Identify from a photo": the image encoder
  runs in the reader's browser with onnxruntime-web, the photo never leaves
  the device, and the page marks the likely taxa and offers to narrow the key
  to them. The model is downloaded only after the reader agrees.
* The wizard's remaining-taxa count is now correct for keys where a couplet
  is reached from more than one lead, and is computed without the map.
* A web page turns a key spreadsheet (CSV, with optional photos) into the
  interactive wizard without installing R: R runs in the browser through
  webR. It is built by `webr/build.R` and published with the website at
  <https://leipzig.github.io/dimoose/webr/>.

## Keys from photos

* `visionModel(backend = "onnx")` and `onnxModel()` embed images and texts
  with ONNX Runtime instead of PyTorch, a much smaller Python install, with
  the same embeddings on the example photos. CLIP ViT-B/32 is downloaded
  ready-made from the Hugging Face Hub; `precision = "fp16"` or `"int8"`
  picks a smaller copy.
* `exportOnnxModel()` converts BioCLIP, BioCLIP 2 and other open_clip models
  to ONNX once (image and text encoders, tokenizer, optional int8 and fp16
  copies), for use without PyTorch afterwards.
* `saveEmbeddings()` and `loadEmbeddings()` keep embeddings in a small
  safetensors file, so keys can be built and scored from precomputed
  embeddings with no Python at all.
* `exportBrowserModel()` writes what a web page needs to identify photos on
  the visitor's device: an image encoder, its preprocessing constants, and
  text embeddings of a key's species.
* `suggestSnigletNames()` has a vision-language model propose a name and a
  one-sentence definition for each sniglet from its example crops, and
  returns the names table `renameSniglets()` takes (or writes it as the CSV
  it reads), so naming becomes reviewing suggestions. Names are kept short,
  distinct and descriptive: class and species names are refused.
* `claudeNamer()` is a ready-made model for `suggestSnigletNames()` that asks
  Claude through the Anthropic Messages API (needs an API key; calls are
  billed to it). It has been tested against a stand-in for the API only.
* `inatPhotos()` downloads a balanced, reproducible sample of research-grade,
  openly licensed iNaturalist photos for a set of species, with a manifest
  (observation, photo, licence, attribution, URL) so a benchmark can be cited
  and re-run.
* `benchmarkKey()` measures identification on field photos (top-1 and top-k
  accuracy, per-species accuracy, confusion table) for species ranked by
  name, for a key followed by machine, or for a photo key built from the
  training photos; `splitByObservation()` keeps every observation on one side
  of the train/test split.
* New `analysis/inat-benchmark/`: a first benchmark on 220 iNaturalist photos
  of the eleven Montana broadleaf trees with BioCLIP 2 (script, manifest,
  results and limits).
* The Python tests skip instead of failing where PyTorch is not installed.

## Documentation and infrastructure

* New vignette, "From a published key to a field key": a text key is read,
  checked, cut down to a county, measured and exported for offline use.
* The README no longer lists features the package does not have (YAML,
  lexical analysis), and describes the ones added here.
* `citation("dimoose")` now gives how to cite the package, plus PhyloTree
  Build 17 and FishBase for users of those data.
* The package is checked on Linux, macOS and Windows with GitHub Actions
  (replacing Travis; `.travis.yml` is removed), and test coverage is reported
  to Codecov; added `CONTRIBUTING.md` and `codemeta.json`.

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
