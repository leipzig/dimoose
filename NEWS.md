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
* Keys from images: invented visual terms (`discoverTerms()`,
  `keyFromTerms()`), vocabulary questions (`keyFromClusters()`), machine
  classification and evaluation (`classify()`, `evaluateKey()`, `looKey()`),
  and an optional open_clip vision layer through reticulate.
