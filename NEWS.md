# moose 0.1.0

* First release.
* Dichotomous keys as `moose` objects: build them from lead tables
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
