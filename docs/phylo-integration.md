# Integrating moose with phylogenetic tree libraries

Checked 2026-09-30. Versions come from GitHub, r-universe, Bioconductor and PyPI; CRAN was not reachable from the sandbox, so CRAN dates are unverified. Rows marked (T) were tested with small Newick inputs that exercise what moose produces: quoted labels with spaces, commas and parentheses, `''` escapes, quoted internal labels, single-child nodes and polytomies.

## What moose produces

A key is a lead table (`Statement`, `Choice`, `Character`, `Next`, `Taxon`). As a tree it has these properties, and they decide which libraries fit:

- Internal nodes are couplets and need labels (the couplet id). The lead text belongs to the *edge*, not the node.
- Couplets can have more than two leads (PhyloTree steps have up to 87).
- A couplet can be reached from more than one lead, so strictly it is a DAG; `toNewick()` and `toDataTree()` use a spanning tree.
- The same taxon can sit at several leaves.
- Labels contain spaces, `+`, parentheses and apostrophes (`H2a+152  16311`, `L2'3'4'6`), so `toNewick()` quotes them.
- There are no branch lengths.

## R

| Library | Version, status | Formats | Internal labels, annotations | Single-child / n-ary | Quoted labels | Drawing |
|---|---|---|---|---|---|---|
| **ape** | 5.8-3 (2026-06); CRAN | Newick, Nexus; no NHX | `node.label` only; comments dropped (T) | both OK; `collapse.singles()` | **weak (T):** quotes kept inside the label, `''` becomes `NA`, `write.tree` turns spaces into `_` and `, : ; ( )` into `-` | `plot.phylo`, `nodelabels`, `edgelabels` |
| **treeio** | 1.36.0 (Bioc 3.23, 2026-04) | reads Newick, NHX, BEAST/MrBayes Nexus, PhyloXML, jplace, jtree, Nextstrain JSON; writes `write.beast`, `write.beast.newick`, `write.jtree`, `write.jplace` | `treedata` = phylo + tibble keyed by node | as ape (`read.newick` wraps `ape::read.tree`) | inherits ape; `read.nhx` strips spaces and quotes | none; feeds ggtree |
| **tidytree** | 0.4.8; CRAN | `as_tibble(phylo)` ↔ `as.phylo` / `as.treedata` | tidy parent/node/label table; `full_join` by node | generic edges | n/a | none |
| **ggtree** | 4.2.0 (Bioc 3.23) | viz only | `geom_nodelab`, `geom_tiplab`, `%<+%` joins data by `node`; edge labels via `geom_label(aes(x = branch, label = ...))` | singletons unsupported per maintainer | via ape | many layouts, `collapse`, `geom_hilight` |
| **castor** | 1.8.7 (2026-08); CRAN | fast `read_tree` / `write_tree` | node labels **and edge labels** (`[...]`) | both OK | `interpret_quotes`, `write_tree(quoting = -1)` | none |
| **data.tree** | 1.1.0 (2023); CRAN, stable | R6 `Node`; `ToNewick`, `as.phylo`, `as.igraph`, `ToDataFrameNetwork` | arbitrary fields | any arity; one parent | n/a | Graphviz via DiagrammeR |
| **igraph** | 2.x; CRAN | graphml, gml, dot, edge lists | vertex and edge attributes | **DAGs OK** (T) | free strings | basic |
| **ggraph** | 2.2.x; CRAN | viz only | edge labels in `geom_edge_link/elbow` | `dendrogram`/`tree` layouts; **`sugiyama` for DAGs** | n/a | ggplot2 |
| phytools 2.6-9, phangorn 3.0, TreeTools 2.4, phylobase 0.8.12, RNeXML 2.4.11 | CRAN | built on ape's `phylo` (RNeXML adds NeXML I/O) | as ape | as ape | as ape | comparative plots (phytools) |
| collapsibleTree | CRAN | takes a `data.tree` Node | n/a | n/a | n/a | interactive d3 collapsible tree widget |

No R package reads Haplogrep or PhyloTree files; the closest is MTseeker, which shells out to Java Haplogrep.

## Python

| Library | Version | Formats | Annotations | Quoted labels (T) | Drawing |
|---|---|---|---|---|---|
| **ete4** | 4.4.0 (2025-09); ete3 is stagnant | Newick (10 parser variants), NHX | `props` from NHX; `write()` drops the root name unless `format_root_node=True`; a comma in an NHX value becomes `_` | round-trips, including `''` and quoted internal labels | `explore()` in a browser, `render()` to SVG/PDF/PNG |
| **DendroPy** | 5.1.0 (2026-09) | Newick, Nexus, NeXML | parses `[&...]` NHX and BEAST comments; `annotations_as_nhx` on write | round-trips; quoted internal `'couplet 2'` comes back as `couplet_2`; commas inside BEAST values break | ASCII |
| **Biopython Bio.Phylo** | 1.88 (2026-08) | Newick, Nexus, PhyloXML, NeXML, CDAO | comments kept verbatim; numeric internal labels become `confidence`; writes `:0` on every branch when there are no lengths | round-trips; writer escapes `'` | matplotlib, ASCII |
| scikit-bio | 0.7.4 | Newick | **drops comments**; `prune()` collapses single-child nodes | writes `it''s_B` unquoted (bug) | none |
| toytree | 3.0.11 | Newick, Nexus, NHX | features from comments | **breaks** on quoted labels with commas or parentheses | strong (toyplot SVG/HTML) |
| phylotreelib | 2.3.1 | Newick, Nexus | labels belong to branches | fails on quoted labels with commas or parentheses | none |
| anytree | 2.13.0 | not phylogenetic; JSON/dict | arbitrary attributes | n/a | text, DOT, Mermaid |

## JavaScript and web viewers

| Library | Version | Input | Notes |
|---|---|---|---|
| **phylotree.js** | 2.6.0 (2026-03), MIT | Newick (+ HyPhy `{}`), PhyloXML, NeXML, Nexus annotations | quoted, internal-quoted, unary and n-ary all parse (T); NHX comments garble names; all branch lengths set to 1 when none given |
| **phylocanvas.gl** | 1.64.1 (2026-07), MIT | Newick, own JSON | WebGL, built for very large trees |
| **Taxonium** | 2.1.24 (2026-02) | **Newick + CSV/TSV metadata** (first column = node name), JSONL, Auspice JSON | millions of nodes; JSONL rows carry `name`, `parent_id`, `mutations`, `meta_*` |
| **IcyTree** | maintained | Newick, Nexus, PhyloXML, NeXML, extended Newick | BEAST-style annotations; client-side; loads from `?url=` |
| **Auspice** (Nextstrain) | 3.0.0 (2026-09), AGPL-3 | Auspice JSON v2 | node names must be unique with no spaces; `node_attrs.div` or `num_date` required; polytomies and single-child nodes allowed; `branch_attrs.mutations.nuc` entries must match `^[ATCGN-][0-9]+[ATCGN-]$`, so PhyloTree's position-plus-derived-base notation needs the rCRS reference base |
| d3-hierarchy | 3.1.2 | nested `children` or `id`/`parentId` | trees only, single parent |

## Interchange formats

- **Newick:** unquoted labels cannot contain blanks, parentheses, brackets, colons, semicolons or commas, and `_` means a space; quote with `'`, escape as `''`. There is no standard place for edge attributes.
- **NHX** `[&&NHX:k=v:k=v]` after a node: ete4, treeio `read.nhx`, DendroPy, Biopython. Commas in values are unsafe.
- **BEAST-style** `[&k=v,k2="text"]`: treeio `read.beast`, ggtree, IcyTree, DendroPy, toytree. Commas in values broke DendroPy and toytree.
- **Nexus, NeXML, PhyloXML:** widely read; NeXML (RNeXML, DendroPy, Biopython) and PhyloXML carry metadata properly, at the cost of XML.
- **treeio jtree:** JSON with a Newick string using `{n}` node ids and a `data` array keyed by edge; round-trips through treeio.
- **Auspice JSON v2, Taxonium JSONL:** for interactive web viewers; see the table above.

## PhyloTree Build 17 in these terms

Measured on Haplogrep's `phylotree-rcrs-17` 17.3 `tree.xml`: 5,435 haplogroups, maximum depth 31, maximum 86 children at one node, 13,384 mutations. 361 names contain spaces, `+` or parentheses (`H2a+152  16311`, `H2a2a+(16235)`), so they need Newick quoting and break Auspice's no-spaces rule unless renamed. No mutation matches Auspice's nucleotide regex, because PhyloTree gives position and derived base only; the reference base has to be looked up in `rcrs.fasta` from the same release. The Haplogrep tree catalogue (`genepi/haplogrep-trees`) also lists RSRS 17.2, the Forensic Update 1.3 and FamilyTreeDNA's Mitotree (non-commercial licence).

## Recommendations for moose

1. **`toTreedata()` bridge for ggtree.** Build a `tidytree` table from the lead table (parent = `Statement`, node = `Next` or a leaf), attach `Character`, `Choice` and `Taxon` as node data (the data of a child node describes the edge into it), and return `as.treedata()`. ggtree then draws lead text on branches with `geom_label(aes(x = branch, label = Character))`, couplet ids with `geom_nodelab()`, and users join their own data with `%<+%`. Join by `node`, never by label, because taxa repeat across leaves. From `treedata`, `write.beast()` gives annotated Nexus for FigTree and IcyTree, and `write.jtree()` a JSON that round-trips. This is the highest-value item: it plugs moose into the most-used R tree stack with one conversion.

2. **Harden `toNewick()` for the parsers people actually use.** Quoted labels work in ete4, DendroPy, Biopython and phylotree.js, but ape, scikit-bio, toytree and phylotreelib mangle or reject them (ape is the one most R users will hit first). Add `toNewick(labels = c("quoted", "safe"))`: `"safe"` writes ASCII ids (couplet id, `L<n>` for leaves) and returns the real text in a sidecar table, which is also exactly the Newick-plus-TSV pair Taxonium accepts. Keep `"quoted"` as the default because it is correct Newick. Turn the cross-parser checks above into regression tests (ape, ete4, DendroPy, Biopython are all installable).

3. **Annotations only through a sanitizer.** Lead text in Newick comments is fragile: commas broke BEAST-style parsing in DendroPy and toytree, ete4 rewrote them, and `]` cannot be escaped. If moose offers `toNewick(annotate = c("none", "nhx", "beast"))`, strip or replace `, : ] = "` in values. For lossless transfer prefer plain Newick plus a table keyed by node id (recommendation 2).

4. **`toAuspiceJSON()` for the PhyloTree key.** Auspice and Taxonium are the viewers that handle 5,435-node trees comfortably and are what the mitochondrial community already uses. Requirements: unique, space-free node names (map the 361 awkward names and keep the originals in `node_attrs`), `div` = depth or cumulative mutation count, and mutations rewritten as `ref+pos+alt` using the rCRS reference base from the Haplogrep release, with indels, back-mutations and parenthesised calls routed to `branch_attrs.labels` instead. For ordinary keys, lead text fits `branch_attrs.labels`.

5. **A DAG-faithful export.** Keep the spanning tree for phylo-style exports but add `toIgraph()` as the direct `Statement → Next` edge list. igraph keeps multi-parent structure, writes graphml/gml/dot, and ggraph's `sugiyama` layout draws it; data.tree, d3-hierarchy and anytree cannot represent it. While there, guard `toDataTree()` against data.tree's reserved names: a node called `children` is silently renamed `children2`, and duplicate sibling names break `print()` and `Get()`.

6. **A Haplogrep/PhyloTree XML reader.** Nothing in R reads these files, and the format is simple nested `haplogroup/details/poly` XML, so a small `xml2` reader (the conversion script in `data-raw/phylotree17/` is most of it already) would let users load any Haplogrep tree, not just the bundled snapshot. Leave Mitotree out of shipped data because of its licence.

## Sources

treeio [NEWS](https://docs.ropensci.org/treeio/news/index.html), [write.beast](https://docs.ropensci.org/treeio/reference/write.beast.html), [jtree.R](https://raw.githubusercontent.com/YuLab-SMU/treeio/devel/R/jtree.R), [nhx.R](https://raw.githubusercontent.com/YuLab-SMU/treeio/devel/R/nhx.R); ggtree [manual](https://bioconductor.posit.co/packages/3.23/bioc/manuals/ggtree/man/ggtree.pdf), [treedata book ch. 7](https://yulab-smu.top/treedata-book/chapter7.html), [singleton issue #133](https://github.com/YuLab-SMU/ggtree/issues/133); ape [read.tree](https://search.r-project.org/CRAN/refmans/ape/html/read.tree.html), [write.tree](https://search.r-project.org/CRAN/refmans/ape/html/write.tree.html), [collapse.singles](https://search.r-project.org/CRAN/refmans/ape/html/collapse.singles.html); castor [read_tree](https://rdrr.io/cran/castor/man/read_tree.html), [write_tree](https://rdrr.io/cran/castor/man/write_tree.html); data.tree [ToNewick](https://rdrr.io/cran/data.tree/man/ToNewick.html), [as.phylo.Node](https://rdrr.io/cran/data.tree/man/as.phylo.Node.html); ggraph [layouts](https://ggraph.data-imaginist.com/reference/layout_tbl_graph_igraph.html); [RNeXML](https://ropensci.r-universe.dev/RNeXML); [ete4](https://pypi.org/project/ete4/), [ETE tutorial](https://etetoolkit.github.io/ete/tutorial/tutorial_trees.html); [DendroPy Newick](https://dendropy.org/schemas/newick.html); [Bio.Phylo](https://biopython.org/wiki/Phylo); [scikit-bio TreeNode](https://scikit.bio/docs/latest/generated/skbio.tree.TreeNode.html); [toytree](https://eaton-lab.org/toytree/); [phylotreelib](https://pypi.org/project/phylotreelib/); [phylotree.js](https://github.com/veg/phylotree.js); [phylocanvas.gl](https://www.phylocanvas.gl/docs/methods.html); [Taxonium](https://docs.taxonium.org/en/latest/); [IcyTree](https://icytree.org/); [Auspice schema](https://raw.githubusercontent.com/nextstrain/augur/master/augur/data/schema-export-v2.json); [d3-hierarchy](https://github.com/d3/d3-hierarchy); [haplogrep-trees](https://github.com/genepi/haplogrep-trees); [MTseeker haploMask](https://rdrr.io/github/trichelab/MTseeker/man/haploMask.html).
