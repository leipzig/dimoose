# ---- Newick, hardened and annotated -----------------------------------------

#' Write a key as Newick, with safe labels or node annotations
#'
#' The [moose] method `$toNewick()` writes quoted Newick, which is correct but
#' which several parsers (ape, scikit-bio, toytree) mangle. This wrapper adds
#' two options for interoperating with the wider phylogenetics ecosystem.
#'
#' @param key A [moose] key.
#' @param labels `"quoted"` (the default, identical to `key$toNewick()`) or
#'   `"safe"`, which replaces every label with an ASCII id (`n<couplet>` for
#'   couplets, `t<n>` for taxa) and returns the mapping in a side table, so
#'   fragile parsers never see spaces or punctuation. The real text travels in
#'   the companion table (this is also the Newick-plus-table shape Taxonium
#'   reads).
#' @param annotate `"none"` (default), `"nhx"` or `"beast"`: attach each lead's
#'   `Character` text to the node it leads to, as an NHX
#'   (`[&&NHX:lead=...]`) or BEAST-style (`[&lead=...]`) comment. Values are
#'   sanitized (`, : ; = " [ ]` and newlines removed) because Newick comments
#'   cannot carry them. Only one of `labels = "safe"` or `annotate` applies at
#'   a time; `annotate` wins if both are given.
#' @return For `labels = "quoted"` or any `annotate`, a single Newick string.
#'   For `labels = "safe"` with `annotate = "none"`, a list of `newick` (the
#'   string) and `labels` (a data frame of `id` and `label`).
#' @seealso [toTreedata()], [toAuspiceJSON()]
#' @examples
#' k <- arachnidaKey()
#' cat(toNewick(k, annotate = "nhx"))
#' @export
toNewick <- function(key, labels = c("quoted", "safe"), annotate = c("none", "nhx", "beast")) {
  labels <- match.arg(labels)
  annotate <- match.arg(annotate)
  if (!inherits(key, "moose")) stop("`key` must be a moose object", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  check <- checkLeads(leads)
  lab <- leadLabels(leads)

  if (annotate == "none" && labels == "quoted") return(key$toNewick())

  quote <- function(x) {
    if (grepl("^[A-Za-z0-9_.*-]+$", x)) x else paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
  }
  sanitize <- function(x) trimws(gsub("[,:;=\"\\[\\]\n\r]", " ", x, perl = TRUE))

  # Safe-id mode: ascii ids plus a side table
  coupletIds <- stats::setNames(paste0("n", seq_along(check$couplets)), check$couplets)
  taxonNames <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
  taxonIds <- stats::setNames(paste0("t", seq_along(taxonNames)), taxonNames)
  mapping <- rbind(
    data.frame(id = unname(coupletIds), label = names(coupletIds), kind = "couplet", stringsAsFactors = FALSE),
    data.frame(id = unname(taxonIds), label = names(taxonIds), kind = "taxon", stringsAsFactors = FALSE)
  )

  byCouplet <- split(seq_len(nrow(leads)), factor(leads$Statement, levels = check$couplets))
  placed <- new.env()
  emit <- function(cp) {
    assign(cp, TRUE, envir = placed)
    kids <- character()
    for (i in byCouplet[[cp]]) {
      nx <- leads$Next[i]
      ann <- ""
      if (annotate != "none" && nzchar(leads$Character[i])) {
        v <- sanitize(leads$Character[i])
        ann <- if (annotate == "nhx") sprintf("[&&NHX:lead=%s]", v) else sprintf("[&lead=\"%s\"]", v)
      }
      if (nx == "-") {
        tx <- if (nzchar(leads$Taxon[i])) leads$Taxon[i] else lab[i]
        node <- if (labels == "safe") taxonIds[[tx]] else quote(tx)
        kids <- c(kids, paste0(node, ann))
      } else if (nx %in% check$couplets && !exists(nx, envir = placed, inherits = FALSE)) {
        kids <- c(kids, paste0(emit(nx), ann))
      }
    }
    self <- if (labels == "safe") coupletIds[[cp]] else quote(cp)
    paste0(if (length(kids)) paste0("(", paste(kids, collapse = ","), ")") else "", self)
  }
  newick <- paste0(emit(check$root), ";")
  if (labels == "safe" && annotate == "none") list(newick = newick, labels = mapping) else newick
}

# ---- igraph (DAG-faithful) ---------------------------------------------------

#' Convert a key to an igraph directed graph
#'
#' Unlike `toNewick()` and `toDataTree()`, which use a spanning tree, this
#' keeps the key's true structure: a couplet reached from several leads has
#' several incoming edges. Each edge carries the lead's `label` and
#' `Character` text; vertices are couplets and taxa.
#'
#' @param key A [moose] key.
#' @return An [igraph::igraph] directed graph.
#' @examples
#' \dontrun{
#' g <- toIgraph(arachnidaKey())
#' igraph::vcount(g)
#' }
#' @export
toIgraph <- function(key) {
  if (!requireNamespace("igraph", quietly = TRUE)) stop("Install the igraph package", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  lab <- leadLabels(leads)
  from <- leads$Statement
  to <- ifelse(leads$Next == "-", ifelse(nzchar(leads$Taxon), leads$Taxon, lab), leads$Next)
  edges <- data.frame(from = from, to = to, lead = lab, character = leads$Character, stringsAsFactors = FALSE)
  verts <- unique(c(from, to))
  terminal <- leads$Next == "-"
  vtype <- ifelse(verts %in% leads$Statement, "couplet", "taxon")
  igraph::graph_from_data_frame(edges, directed = TRUE, vertices = data.frame(name = verts, type = vtype, stringsAsFactors = FALSE))
}

# ---- tidytree / treedata for ggtree -----------------------------------------

#' Convert a key to a tidytree treedata (for ggtree)
#'
#' Builds a `treedata` object whose tree is the key's spanning tree and whose
#' node data carries each lead's `Character`, `Choice` and `Taxon`. The data
#' of a child node describes the edge into it, so in ggtree you draw lead text
#' on branches with `geom_label(aes(x = branch, label = Character))` and join
#' your own data by the `node` column (never by label, since taxa repeat).
#'
#' @param key A [moose] key.
#' @return A [tidytree::treedata] object.
#' @seealso [toNewick()], [toIgraph()]
#' @examples
#' \dontrun{
#' td <- toTreedata(arachnidaKey())
#' library(ggtree)
#' ggtree(td) + geom_tiplab() + geom_label(aes(x = branch, label = Character))
#' }
#' @export
toTreedata <- function(key) {
  if (!requireNamespace("tidytree", quietly = TRUE)) stop("Install the tidytree package", call. = FALSE)
  if (!requireNamespace("ape", quietly = TRUE)) stop("Install the ape package", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  check <- checkLeads(leads)
  lab <- leadLabels(leads)

  # Build a spanning tree: each couplet placed once (under its first parent),
  # each terminal lead a tip. Nodes get integer ids: tips first, then internal.
  byCouplet <- split(seq_len(nrow(leads)), factor(leads$Statement, levels = check$couplets))
  placed <- new.env()
  tips <- list(); internals <- list(); edges <- list()
  nodeData <- list()
  nextId <- 0L
  newId <- function() { nextId <<- nextId + 1L; nextId }

  build <- function(cp) {
    assign(cp, TRUE, envir = placed)
    childIds <- integer()
    for (i in byCouplet[[cp]]) {
      nx <- leads$Next[i]
      info <- list(Character = leads$Character[i], Choice = leads$Choice[i], Lead = lab[i])
      if (nx == "-") {
        name <- if (nzchar(leads$Taxon[i])) leads$Taxon[i] else lab[i]
        id <- newId(); tips[[length(tips) + 1]] <<- list(id = id, name = name)
        nodeData[[as.character(id)]] <<- c(info, list(Taxon = leads$Taxon[i]))
        childIds <- c(childIds, id)
      } else if (nx %in% check$couplets && !exists(nx, envir = placed, inherits = FALSE)) {
        id <- build(nx)
        nodeData[[as.character(id)]] <<- c(info, list(Taxon = ""))
        childIds <- c(childIds, id)
      }
    }
    me <- newId(); internals[[length(internals) + 1]] <<- list(id = me, name = cp)
    for (cid in childIds) edges[[length(edges) + 1]] <<- c(me, cid)
    me
  }
  root <- build(check$root)

  # ape expects tips numbered 1..Ntip, then internal nodes. Renumber.
  tipIds <- vapply(tips, `[[`, integer(1), "id")
  intIds <- vapply(internals, `[[`, integer(1), "id")
  remap <- stats::setNames(c(seq_along(tipIds), length(tipIds) + seq_along(intIds)), c(tipIds, intIds))
  edge <- t(vapply(edges, function(e) c(remap[[as.character(e[1])]], remap[[as.character(e[2])]]), integer(2)))
  phy <- list(
    edge = edge,
    tip.label = vapply(tips, `[[`, character(1), "name"),
    node.label = vapply(internals, `[[`, character(1), "name"),
    Nnode = length(internals)
  )
  class(phy) <- "phylo"

  dat <- data.frame(node = unname(remap[names(nodeData)]),
    Character = vapply(nodeData, function(x) x$Character, ""),
    Choice = vapply(nodeData, function(x) x$Choice, ""),
    Lead = vapply(nodeData, function(x) x$Lead, ""),
    Taxon = vapply(nodeData, function(x) x$Taxon, ""),
    stringsAsFactors = FALSE)
  tidytree::treedata(phylo = phy, data = tibble::as_tibble(dat))
}

# ---- Auspice JSON v2 ---------------------------------------------------------

#' Export a key as Auspice (Nextstrain) JSON v2
#'
#' Writes the key's spanning tree as an Auspice v2 dataset, which the
#' Nextstrain viewer and auspice.us can display. Node names are made unique
#' and space-free (required by the schema); the original labels and each
#' lead's text are kept in `node_attrs`. `div` is the depth from the root.
#'
#' @param key A [moose] key.
#' @param title Dataset title; defaults to the key's description.
#' @param file Optional path to write to; if `NULL`, the JSON is returned as a
#'   string.
#' @return The JSON string (invisibly if written to `file`).
#' @seealso [toNewick()], [toTreedata()]
#' @examples
#' js <- toAuspiceJSON(phylotreeKey("H2a"))
#' @export
toAuspiceJSON <- function(key, title = NULL, file = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  check <- checkLeads(leads)
  lab <- leadLabels(leads)
  if (is.null(title)) title <- if (length(key$desc) == 1 && !is.na(key$desc)) as.character(key$desc) else "moose key"

  used <- new.env()
  uniqueName <- function(x) {
    base <- gsub("[^A-Za-z0-9._-]", "_", x)
    if (!nzchar(base)) base <- "node"
    name <- base; k <- 1
    while (exists(name, envir = used, inherits = FALSE)) { k <- k + 1; name <- paste0(base, "_", k) }
    assign(name, TRUE, envir = used)
    name
  }

  byCouplet <- split(seq_len(nrow(leads)), factor(leads$Statement, levels = check$couplets))
  placed <- new.env()
  node <- function(cp, div, labelText, origName) {
    assign(cp, TRUE, envir = placed)
    children <- list()
    for (i in byCouplet[[cp]]) {
      nx <- leads$Next[i]
      if (nx == "-") {
        tx <- if (nzchar(leads$Taxon[i])) leads$Taxon[i] else lab[i]
        children[[length(children) + 1]] <- list(
          name = uniqueName(tx),
          node_attrs = list(div = div + 1, original_name = list(value = tx), lead = list(value = leads$Character[i]))
        )
      } else if (nx %in% check$couplets && !exists(nx, envir = placed, inherits = FALSE)) {
        children[[length(children) + 1]] <- node(nx, div + 1, leads$Character[i], nx)
      }
    }
    out <- list(name = uniqueName(origName),
      node_attrs = list(div = div, original_name = list(value = origName)))
    if (nzchar(labelText)) out$node_attrs$lead <- list(value = labelText)
    if (length(children)) out$children <- children
    out
  }
  tree <- node(check$root, 0, "", check$root)
  doc <- list(
    version = "v2",
    meta = list(title = title, panels = list("tree"),
      colorings = list(list(key = "lead", title = "Lead", type = "categorical"))),
    tree = tree
  )
  js <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (is.null(file)) return(as.character(js))
  writeLines(js, file)
  invisible(as.character(js))
}

# ---- Haplogrep / PhyloTree XML reader ---------------------------------------

#' Read a Haplogrep / PhyloTree tree XML
#'
#' Parses the nested `<haplogroup>` XML that Haplogrep distributes (for
#' example `phylotree-rcrs-17`'s `tree.xml`) into the same data frame shape as
#' [phylotree17], so any Haplogrep tree can be loaded, not just the bundled
#' snapshot. Each haplogroup's `<details><poly>` entries become its mutations.
#'
#' @param file Path to the tree XML.
#' @param key If `TRUE`, return a [moose] key built with [keyFromLeads()]
#'   instead of the data frame.
#' @return A data frame with `haplogroup`, `parent`, `depth`, `n_subclades`
#'   and `mutations`, or a [moose] object if `key = TRUE`.
#' @seealso [phylotree17], [phylotreeKey()]
#' @examples
#' \dontrun{
#' tree <- readHaplogrep("tree.xml")
#' }
#' @export
readHaplogrep <- function(file, key = FALSE) {
  if (!requireNamespace("xml2", quietly = TRUE)) stop("Install the xml2 package", call. = FALSE)
  doc <- xml2::read_xml(file)
  rows <- list()
  visit <- function(nd, parent, depth) {
    name <- xml2::xml_attr(nd, "name")
    polys <- xml2::xml_text(xml2::xml_find_all(nd, "./details/poly"))
    kids <- xml2::xml_find_all(nd, "./haplogroup")
    rows[[length(rows) + 1]] <<- data.frame(
      haplogroup = name, parent = parent, depth = depth,
      n_subclades = length(kids), mutations = paste(polys, collapse = " "),
      stringsAsFactors = FALSE)
    for (k in kids) visit(k, name, depth + 1)
  }
  for (top in xml2::xml_find_all(doc, "./haplogroup")) visit(top, NA_character_, 0L)
  tree <- do.call(rbind, rows)
  rownames(tree) <- NULL
  if (!key) return(tree)

  steps <- tree$haplogroup[tree$haplogroup %in% tree$parent]
  partsFor <- function(h) tree[tree$parent %in% h & !is.na(tree$parent), , drop = FALSE]
  leadRows <- lapply(steps, function(h) {
    kids <- partsFor(h)
    kidIsStep <- kids$haplogroup %in% steps
    data.frame(Statement = h, Choice = as.character(seq_len(nrow(kids))),
      Character = ifelse(nzchar(kids$mutations), kids$mutations, "No defining mutations"),
      Next = ifelse(kidIsStep, kids$haplogroup, "-"),
      Taxon = ifelse(kidIsStep, "", kids$haplogroup), Label = kids$haplogroup,
      stringsAsFactors = FALSE)
  })
  leads <- do.call(rbind, leadRows)
  rownames(leads) <- NULL
  keyFromLeads(leads, "PhyloTree (from Haplogrep XML)",
    meta = data.frame(key = "node_label", value = "Haplogroup", stringsAsFactors = FALSE))
}

# data.tree reserves words like "children", "name", "parent"; it renames a
# node that uses one (with a warning). We pick a safe node name ourselves and
# keep the real name in the node's `label` field. Also avoids collisions with
# siblings already added.
dataTreeSafeName <- function(name, parent = NULL) {
  reserved <- c("name", "parent", "children", "root", "AddChild", "Get", "Set",
                "leaves", "leafCount", "count", "level", "height", "isLeaf", "isRoot",
                "path", "position", "totalCount", "averageBranchingFactor")
  nm <- name
  if (nm %in% reserved) nm <- paste0(nm, "_node")
  if (!is.null(parent)) {
    taken <- names(parent$children)
    base <- nm; k <- 1L
    while (nm %in% taken) { k <- k + 1L; nm <- paste0(base, "_", k) }
  }
  nm
}
