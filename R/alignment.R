#' Build a key from a multiple sequence alignment
#'
#' One command from aligned sequences to a dichotomous key. A phylogeny
#' program builds a tree from the alignment, the tree is rooted and made
#' strictly bifurcating, and every fork becomes a couplet whose two leads are
#' the alignment sites that tell its two clades apart (`"152C 16311T"`
#' against `"152T 16311C"`). Each sequence is a result.
#'
#' Sites are chosen per fork: a site is *diagnostic* when the states seen on
#' one side are never seen on the other. Up to `maxSites` diagnostic sites
#' are listed, those with the least missing data first. If a fork has no diagnostic site, the
#' best-separating one is used and marked `(most)`. If no site separates the
#' two sides, the sequences below it are split by their sites alone,
#' whatever the tree says. Sequences that no site tells apart share a result
#' (`"A / B"`), as do identical sequences. Gaps and ambiguity codes are treated as missing data.
#'
#' The first site of each couplet is also a machine-readable test, so
#' [classify()] can place sequences scored with [alignmentScores()].
#'
#' @param alignment The alignment: a FASTA file, an `ape` `DNAbin`/`AAbin`
#'   object (e.g. from [ape::read.dna()] for Clustal or PHYLIP files), a
#'   `phangorn` `phyDat`, a character matrix with one named row per sequence
#'   and one column per site, or a named character vector of equal-length
#'   strings.
#' @param tool The program that builds the tree:
#'   * `"nj"`, `"bionj"`: neighbour joining in `ape`;
#'   * `"upgma"`, `"parsimony"`, `"ml"`: UPGMA, the parsimony ratchet and
#'     maximum likelihood in `phangorn`;
#'   * `"fasttree"`, `"iqtree"`: the FastTree or IQ-TREE command-line
#'     program, which must be installed.
#' @param tree A tree you built yourself, instead of `tool`: an `ape` `phylo`
#'   object, a Newick file or a Newick string, with the sequence names as tip
#'   labels. It may cover only some of the sequences, and may have
#'   polytomies. This is the way to use any other phylogeny program.
#' @param outgroup Name(s) of the sequence(s) to root on. Without it, a tree
#'   that is not already rooted is rooted at its midpoint. Sequences can be
#'   named in full or by the first word of their FASTA header.
#' @param reference Name of a sequence in the alignment to number sites by
#'   (its ungapped positions; columns where it has a gap are numbered
#'   `"315.1"`, `"315.2"`). By default sites are alignment columns.
#' @param type `"DNA"`, `"AA"`, or `"auto"` to guess from the sequences.
#' @param model Substitution model, passed to the tool: the `model` of
#'   [ape::dist.dna()] for the distance methods (default `"K80"`; `"JTT"`
#'   through [phangorn::dist.ml()] for proteins), the model of
#'   [phangorn::pml_bb()] for `"ml"` (default `"GTR+G(4)"`, or `"LG+G(4)"`
#'   for proteins), or IQ-TREE's `-m` (default: IQ-TREE chooses).
#' @param maxSites Most sites listed in a lead.
#' @param exe Path to the FastTree or IQ-TREE program, if it is not on the
#'   `PATH`.
#' @param args Extra command-line arguments for FastTree or IQ-TREE.
#' @param desc,meta Title and extra metadata of the key.
#' @return A [moose] key. Its `meta` records the tool, the rooting, the tree
#'   in Newick format (`newick`, names quoted where Newick needs it), how many couplets lack a diagnostic site
#'   (`weak_couplets`) and how many do not follow the tree
#'   (`regrouped_couplets`).
#' @seealso [alignmentScores()], [phylotreeKey()], [toNewick()]
#' @examples
#' aln <- c(human = "ACGTACGTACGA", chimp = "ACGTACGTATGA", mouse = "ACCTACATGCGA",
#'          rat   = "ACCTACATGCGT", fish  = "TCCTTCGTACCA")
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   key <- keyFromAlignment(aln, outgroup = "fish")
#'   key$leads[, c("Statement", "Character", "Next", "Taxon")]
#'   classify(key, alignmentScores(key, aln))
#' }
#'
#' # the example files that ship with moose
#' fasta <- system.file("extdata", "aligned.fasta", package = "moose")
#' mtdna <- system.file("extdata", "mtdna.fasta", package = "moose")
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   keyFromAlignment(fasta)
#'   keyFromAlignment(fasta, tree = system.file("extdata", "aligned.nwk", package = "moose"))
#'   keyFromAlignment(mtdna, reference = "H2a2a1", outgroup = "L0a1")
#' }
#' \dontrun{
#' keyFromAlignment(mtdna, tool = "iqtree", outgroup = "L0a1")   # needs IQ-TREE installed
#' }
#' @export
keyFromAlignment <- function(alignment, tool = c("nj", "bionj", "upgma", "parsimony", "ml", "fasttree", "iqtree"),
                             tree = NULL, outgroup = NULL, reference = NULL, type = c("auto", "DNA", "AA"),
                             model = NULL, maxSites = 3, exe = NULL, args = NULL,
                             desc = "Key generated from a sequence alignment", meta = NULL) {
  tool <- match.arg(tool)
  type <- match.arg(type)
  if (!requireNamespace("ape", quietly = TRUE)) stop("Install the ape package to build keys from alignments", call. = FALSE)
  if (!is.numeric(maxSites) || length(maxSites) != 1 || maxSites < 1) stop("`maxSites` must be 1 or more", call. = FALSE)
  if (!is.null(meta) && !(is.data.frame(meta) && all(c("key", "value") %in% names(meta)))) {
    stop("`meta` must be a data frame with columns `key` and `value`", call. = FALSE)
  }
  mat <- alignmentMatrix(alignment)
  if (type == "auto") type <- alignmentType(mat)
  if (type == "DNA") mat[mat == "U"] <- "T"
  if (nrow(mat) < 2) stop("An alignment needs at least two sequences to make a key", call. = FALSE)
  if (!is.null(reference)) reference <- sequenceNames(reference, rownames(mat), "`reference` is")
  if (!is.null(outgroup)) outgroup <- sequenceNames(outgroup, rownames(mat), "`outgroup` is")
  pos <- siteLabels(mat, reference)

  if (is.null(tree)) {
    # identical sequences cannot be told apart, so they share a tip
    seqString <- apply(mat, 1, paste, collapse = "")
    groups <- split(rownames(mat), factor(seqString, levels = unique(seqString)))
    tipNames <- vapply(groups, paste, "", collapse = " / ")
    tipMat <- mat[vapply(groups, `[`, "", 1), , drop = FALSE]
    safe <- paste0("t", seq_len(nrow(tipMat)))
    rownames(tipMat) <- safe
    if (nrow(tipMat) < 2) stop("All sequences in the alignment are identical", call. = FALSE)
    outSafe <- unique(safe[vapply(groups, function(g) any(g %in% outgroup), logical(1))])
    built <- buildTree(tipMat, tool, type, model, exe, args)
    tr <- built$tree
    toolLabel <- built$label; citation <- built$citation
  } else {
    tr <- if (inherits(tree, "phylo")) {
      tree
    } else if (is.character(tree) && length(tree) == 1) {
      if (file.exists(tree)) ape::read.tree(tree) else ape::read.tree(text = tree)
    } else {
      NULL
    }
    if (!inherits(tr, "phylo")) stop("`tree` must be one tree: a phylo object, a Newick file or a Newick string", call. = FALSE)
    if (length(tr$tip.label) < 2) stop("`tree` needs at least two tips", call. = FALSE)
    tipNames <- sequenceNames(tr$tip.label, rownames(mat), "`tree` has tip(s) that are")
    if (anyDuplicated(tipNames)) stop("`tree` has duplicated tip labels", call. = FALSE)
    if (length(setdiff(outgroup, tipNames))) {
      stop("`outgroup` is not in `tree`: ", paste(setdiff(outgroup, tipNames), collapse = ", "), call. = FALSE)
    }
    tipMat <- mat[tipNames, , drop = FALSE]
    safe <- paste0("t", seq_along(tipNames))
    rownames(tipMat) <- safe
    outSafe <- safe[tipNames %in% outgroup]
    tr$tip.label <- safe
    toolLabel <- "user-supplied tree"; citation <- NA_character_
  }
  names(tipNames) <- safe

  tr$node.label <- NULL
  rooted <- rootTree(ape::collapse.singles(tr), outSafe)
  tr <- ape::reorder.phylo(rooted$tree, "postorder")
  ntip <- length(tr$tip.label)
  tipMat <- tipMat[tr$tip.label, , drop = FALSE]      # row i is tip i
  tipNames <- unname(tipNames[tr$tip.label])
  kidsOf <- split(tr$edge[, 2], tr$edge[, 1])
  under <- vector("list", ntip + tr$Nnode)            # tips below each node
  under[seq_len(ntip)] <- as.list(seq_len(ntip))
  for (e in seq_len(nrow(tr$edge))) under[[tr$edge[e, 1]]] <- c(under[[tr$edge[e, 1]]], under[[tr$edge[e, 2]]])

  # one logical tips x sites matrix per state, over the variable sites only
  states <- if (type == "DNA") c("A", "C", "G", "T") else strsplit("ACDEFGHIKLMNPQRSTVWY", "")[[1]]
  known <- matrix(tipMat %in% states, nrow(tipMat))
  variable <- which(vapply(seq_len(ncol(tipMat)), function(j) length(unique(tipMat[known[, j], j])) > 1, logical(1)))
  if (!length(variable)) stop("No site in the alignment separates the sequences", call. = FALSE)
  hasState <- lapply(states, function(s) tipMat[, variable, drop = FALSE] == s)
  names(hasState) <- states
  counts <- function(tips) {
    m <- vapply(hasState, function(h) colSums(h[tips, , drop = FALSE]), numeric(length(variable)))
    dim(m) <- c(length(variable), length(states))
    m
  }

  # Sites separating tip sets A and B: list(cols, a, b, diagnostic, score), or
  # NULL when no site does better than chance.
  separate <- function(A, B) {
    cA <- counts(A); cB <- counts(B)
    pA <- cA / length(A); pB <- cB / length(B)
    toA <- pA > pB; toB <- pB > pA
    acc <- (rowSums(pA * toA) + rowSums(pB * toB)) / 2
    diagnostic <- rowSums(cA > 0 & cB > 0) == 0 & rowSums(cA) > 0 & rowSums(cB) > 0
    pick <- if (any(diagnostic)) {
      d <- which(diagnostic)
      utils::head(d[order(-acc[d], d)], maxSites)
    } else if (max(acc) > 0.5) {
      which.max(acc)
    } else {
      return(NULL)
    }
    list(cols = variable[pick], a = lapply(pick, function(i) states[toA[i, ]]),
         b = lapply(pick, function(i) states[toB[i, ]]), diagnostic = any(diagnostic),
         score = any(diagnostic) + max(acc[pick]))
  }
  # Split tips by the data alone, on the site with the least missing data and
  # then the most even split. Tips with no state there stay with the majority.
  splitByData <- function(tips) {
    cnt <- counts(tips)
    topState <- max.col(cnt, ties.method = "first")
    top <- cnt[cbind(seq_len(nrow(cnt)), topState)]
    total <- rowSums(cnt)
    ok <- which(total - top > 0)
    if (!length(ok)) return(NULL)
    j <- ok[order(-total[ok], -pmin(top[ok], total[ok] - top[ok]))][1]
    inTop <- hasState[[topState[j]]][tips, j]
    hasAny <- Reduce(`|`, lapply(hasState, function(h) h[tips, j]))
    A <- tips[inTop | !hasAny]; B <- tips[!inTop & hasAny]
    list(A = A, B = B, sp = separate(A, B))
  }

  # Walk the tree with an explicit stack (keys of ladder-like trees are deep).
  # A task is a group of sibling nodes, or a set of tips to split by the data.
  rows <- list(); features <- list()
  counter <- 0L; weak <- 0L; regrouped <- 0L; top <- NULL
  leafOf <- function(tips) paste(tipNames[tips], collapse = " / ")
  resolve <- function(task, id = NULL, leaf = NULL) {
    if (is.null(task$parent)) { top <<- if (is.null(id)) "leaf" else id; return(invisible()) }
    rows[[task$parent]]$Next[task$side] <<- if (is.null(id)) "-" else id
    rows[[task$parent]]$Taxon[task$side] <<- if (is.null(id)) leaf else ""
  }
  stack <- list(list(nodes = ntip + 1L))
  while (length(stack)) {
    task <- stack[[length(stack)]]; stack[[length(stack)]] <- NULL
    nodes <- task$nodes
    while (length(nodes) == 1 && nodes > ntip) nodes <- kidsOf[[as.character(nodes)]]
    sp <- NULL
    if (!is.null(task$tips)) {
      d <- if (length(task$tips) > 1) splitByData(task$tips) else NULL
      if (is.null(d)) { resolve(task, leaf = leafOf(task$tips)); next }
      sp <- d$sp
      left <- list(tips = d$A, offTree = task$offTree); right <- list(tips = d$B, offTree = task$offTree)
      if (task$offTree) regrouped <- regrouped + 1L
    } else if (length(nodes) == 1) {
      resolve(task, leaf = leafOf(nodes)); next
    } else {
      sets <- under[nodes]
      if (length(nodes) == 2) {
        i <- 1L; sp <- separate(sets[[1]], sets[[2]])
      } else {
        # a polytomy: split off a child that has a diagnostic site against the
        # rest, if there is one; otherwise let the data group the tips
        cand <- lapply(seq_along(nodes), function(k) separate(sets[[k]], unlist(sets[-k])))
        score <- vapply(cand, function(s) if (is.null(s) || !s$diagnostic) -1 else s$score, 0)
        i <- which.max(score)
        if (score[i] > 0) sp <- cand[[i]]
      }
      if (is.null(sp)) {
        # the sites do not support a fork here: split the tips by the data instead
        stack[[length(stack) + 1]] <- list(tips = unlist(sets), offTree = length(nodes) == 2,
                                           parent = task$parent, side = task$side)
        next
      }
      left <- list(nodes = nodes[i]); right <- list(nodes = nodes[-i])
    }
    counter <- counter + 1L
    id <- as.character(counter)
    if (!sp$diagnostic) weak <- weak + 1L
    lead <- function(sets) {
      txt <- paste(paste0(pos[sp$cols], vapply(sets, paste, "", collapse = "/")), collapse = " ")
      if (sp$diagnostic) txt else paste(txt, "(most)")
    }
    fid <- sprintf("site:%s:%s", pos[sp$cols[1]], paste(sp$a[[1]], collapse = ""))
    features[[fid]] <- paste0(pos[sp$cols[1]], paste(sp$a[[1]], collapse = "/"))
    rows[[id]] <- data.frame(
      Statement = id, Choice = c("a", "b"), Character = c(lead(sp$a), lead(sp$b)), Next = "", Taxon = "",
      Question = paste(if (type == "DNA") "Base at" else "Residue at", pos[sp$cols[1]]),
      Feature = fid, Test = c(">", "<="), Threshold = 0.5, stringsAsFactors = FALSE)
    resolve(task, id = id)
    stack[[length(stack) + 1]] <- c(right, list(parent = id, side = 2L))
    stack[[length(stack) + 1]] <- c(left, list(parent = id, side = 1L))
  }
  if (identical(top, "leaf")) stop("No site in the alignment separates the sequences", call. = FALSE)
  leads <- do.call(rbind, rows)
  rownames(leads) <- NULL
  if (weak > 0) {
    warning(weak, " couplet(s) have no fully diagnostic site; their leads are marked \"(most)\"", call. = FALSE)
  }
  if (regrouped > 0) {
    warning(regrouped, " couplet(s) do not follow the tree: no site supported its fork there, so the sequences were split by their sites instead", call. = FALSE)
  }

  info <- data.frame(
    key = c("node_label", "tool", "rooting", "sequences", "sites", "sequence_type", "weak_couplets", "regrouped_couplets", "notation", "newick"),
    value = c("Couplet", toolLabel, rooted$how, if (is.null(tree)) nrow(mat) else ntip, ncol(mat), type, weak, regrouped,
      paste0("Leads give a site and its state, e.g. 152C; sites are numbered by ",
             if (is.null(reference)) "alignment column" else paste0("position in ", reference),
             ". Gaps and ambiguity codes are treated as missing."),
      newickWithNames(tr, tipNames)),
    stringsAsFactors = FALSE)
  if (!is.null(reference)) info <- rbind(info, data.frame(key = "reference", value = reference, stringsAsFactors = FALSE))
  if (!is.na(citation)) info <- rbind(info, data.frame(key = "citation", value = citation, stringsAsFactors = FALSE))
  if (!is.null(meta)) info <- rbind(info, meta[!meta$key %in% c(info$key, "reference"), c("key", "value")])
  keyFromLeads(leads, desc, info,
    features = featureTable(id = names(features), kind = "external", label = unlist(features, use.names = FALSE)))
}

#' Score aligned sequences against a key built from an alignment
#'
#' Computes the tests of a [keyFromAlignment()] key for each sequence, for
#' [classify()]. The sequences must be aligned to the same coordinates the
#' key was built with: the same alignment columns or, for a key built with a
#' `reference`, an alignment that contains that reference sequence.
#'
#' @param key A key from [keyFromAlignment()].
#' @param alignment As in [keyFromAlignment()].
#' @param reference Sequence to number sites by; by default the reference
#'   the key was built with, if any.
#' @return A `sequences x features` matrix: 1 if the sequence has the state
#'   the first lead of a couplet asks for, 0 if it has another state, and
#'   `NA` if it has a gap or an ambiguity code there.
#' @export
alignmentScores <- function(key, alignment, reference = NULL) {
  f <- key$features
  site <- !is.null(f) & grepl("^site:", f$id)
  if (is.null(f) || !any(site)) stop("This key has no sequence-site tests", call. = FALSE)
  mat <- alignmentMatrix(alignment)
  if (is.null(reference)) {
    ref <- key$meta$value[key$meta$key == "reference"]
    if (length(ref)) reference <- ref[1]
  }
  if (!is.null(reference) && !reference %in% rownames(mat)) {
    stop("The key numbers sites by ", reference, ", which is not in this alignment", call. = FALSE)
  }
  type <- key$meta$value[key$meta$key == "sequence_type"]
  type <- if (length(type)) type[1] else alignmentType(mat)
  if (type == "DNA") mat[mat == "U"] <- "T"
  states <- if (type == "DNA") c("A", "C", "G", "T") else strsplit("ACDEFGHIKLMNPQRSTVWY", "")[[1]]
  pos <- siteLabels(mat, reference)
  ids <- f$id[site]
  parts <- regmatches(ids, regexec("^site:(.*):([^:]*)$", ids))
  out <- matrix(NA_real_, nrow(mat), length(ids), dimnames = list(rownames(mat), ids))
  for (j in seq_along(ids)) {
    col <- match(parts[[j]][2], pos)
    if (is.na(col)) stop("Site ", parts[[j]][2], " is not in this alignment", call. = FALSE)
    x <- mat[, col]
    out[, j] <- ifelse(x %in% states, as.numeric(x %in% strsplit(parts[[j]][3], "")[[1]]), NA_real_)
  }
  out
}

# ---- internals ---------------------------------------------------------------

# Any supported alignment as an upper-case character matrix, rows = sequences.
alignmentMatrix <- function(x) {
  mat <- if (inherits(x, "phyDat") || inherits(x, "DNAbin") || inherits(x, "AAbin")) {
    # as.character() only knows these classes once their package is loaded
    pkg <- if (inherits(x, "phyDat")) "phangorn" else "ape"
    if (!requireNamespace(pkg, quietly = TRUE)) stop("Install the ", pkg, " package to read this alignment", call. = FALSE)
    m <- as.character(x)
    if (is.list(m)) {
      if (length(unique(lengths(m))) != 1) stop("The sequences are not all the same length; align them first", call. = FALSE)
      m <- do.call(rbind, m)
    }
    m
  } else if (is.matrix(x)) {
    x
  } else if (is.character(x) && length(x) == 1 && is.null(names(x))) {
    if (!file.exists(x)) stop("Alignment file not found: ", x, call. = FALSE)
    readFastaAlignment(x)
  } else if (is.character(x) && !is.null(names(x))) {
    s <- strsplit(unname(x), "")
    if (length(unique(lengths(s))) != 1) stop("The sequences are not all the same length; align them first", call. = FALSE)
    m <- do.call(rbind, s); rownames(m) <- names(x); m
  } else {
    stop("`alignment` must be a FASTA file, a DNAbin/AAbin/phyDat object, a character matrix or a named character vector", call. = FALSE)
  }
  if (is.null(rownames(mat))) stop("The sequences in `alignment` need names", call. = FALSE)
  if (anyDuplicated(rownames(mat))) {
    stop("Sequence names must be unique; duplicated: ", paste(utils::head(unique(rownames(mat)[duplicated(rownames(mat))]), 5), collapse = ", "), call. = FALSE)
  }
  mat[] <- toupper(mat)
  mat
}

readFastaAlignment <- function(file) {
  lines <- readLines(file, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  head <- startsWith(lines, ">")
  if (!length(lines) || !head[1]) {
    stop(basename(file), " is not a FASTA file; read other formats with ape::read.dna() and pass the result", call. = FALSE)
  }
  seqs <- vapply(split(lines[!head], cumsum(head)[!head]), function(z) gsub("\\s", "", paste(z, collapse = "")), "")
  names <- trimws(sub("^>", "", lines[head]))
  if (length(seqs) != length(names)) stop("Some FASTA records in ", basename(file), " have no sequence", call. = FALSE)
  s <- strsplit(unname(seqs), "")
  if (length(unique(lengths(s))) != 1) stop("The sequences are not all the same length; align them first", call. = FALSE)
  m <- do.call(rbind, s); rownames(m) <- names
  m
}

alignmentType <- function(mat) {
  x <- mat[!mat %in% c("-", "?", ".")]
  if (length(x) && mean(x %in% c("A", "C", "G", "T", "U", "N")) >= 0.9) "DNA" else "AA"
}

# Site names: alignment columns, or positions in a reference sequence, with
# columns where the reference has a gap numbered 315.1, 315.2, ...
siteLabels <- function(mat, reference = NULL) {
  if (is.null(reference)) return(as.character(seq_len(ncol(mat))))
  has <- !mat[reference, ] %in% c("-", ".")
  at <- cumsum(has)
  ins <- stats::ave(seq_along(has), at, FUN = seq_along) - ifelse(at == 0, 0L, 1L)
  ifelse(has, as.character(at), paste0(at, ".", ins))
}

findProgram <- function(exe, candidates, what) {
  if (!is.null(exe)) {
    if (!nzchar(Sys.which(exe)) && !file.exists(exe)) stop(what, " not found at ", exe, call. = FALSE)
    return(exe)
  }
  found <- Sys.which(candidates)
  found <- found[nzchar(found)]
  if (!length(found)) stop(what, " is not installed or not on the PATH (looked for ", paste(candidates, collapse = ", "), "); give its path in `exe`", call. = FALSE)
  unname(found[1])
}

# Build an unrooted or rooted tree from a tips x sites matrix with safe names.
buildTree <- function(mat, tool, type, model, exe, args) {
  needPhangorn <- function() {
    if (!requireNamespace("phangorn", quietly = TRUE)) stop("Install the phangorn package for tool = \"", tool, "\"", call. = FALSE)
  }
  n <- nrow(mat)
  if (n == 2) {
    return(list(tree = ape::read.tree(text = sprintf("(%s:1,%s:1);", rownames(mat)[1], rownames(mat)[2])),
                label = "two sequences (no tree needed)", citation = NA_character_))
  }
  apeCite <- "Paradis E, Schliep K (2019). ape 5.0. Bioinformatics 35:526-528."
  phangornCite <- "Schliep KP (2011). phangorn: phylogenetic analysis in R. Bioinformatics 27:592-593."
  distances <- function() {
    d <- if (type == "DNA") {
      ape::dist.dna(ape::as.DNAbin(tolower(mat)), model = if (is.null(model)) "K80" else model, pairwise.deletion = TRUE)
    } else {
      needPhangorn()
      phangorn::dist.ml(phangorn::phyDat(mat, type = "AA"), model = if (is.null(model)) "JTT" else model)
    }
    if (anyNA(d) || any(!is.finite(d))) {
      stop("Some sequences are too different (or share too few sites) for a distance; try model = \"raw\" or another `tool`", call. = FALSE)
    }
    d
  }
  phy <- function() { needPhangorn(); phangorn::phyDat(mat, type = type) }
  switch(tool,
    nj = list(tree = ape::nj(distances()), label = "neighbour joining (ape::nj)",
              citation = paste("Saitou N, Nei M (1987). The neighbor-joining method. Mol Biol Evol 4:406-425.", apeCite)),
    bionj = list(tree = ape::bionj(distances()), label = "BIONJ (ape::bionj)",
                 citation = paste("Gascuel O (1997). BIONJ. Mol Biol Evol 14:685-695.", apeCite)),
    upgma = { needPhangorn(); list(tree = phangorn::upgma(distances()), label = "UPGMA (phangorn::upgma)", citation = phangornCite) },
    parsimony = {
      p <- phy()
      t <- phangorn::pratchet(p, trace = 0, all = FALSE)
      list(tree = phangorn::acctran(t, p), label = "parsimony ratchet (phangorn::pratchet)", citation = phangornCite)
    },
    ml = {
      p <- phy()
      if (is.null(model)) model <- if (type == "DNA") "GTR+G(4)" else "LG+G(4)"
      fit <- phangorn::pml_bb(p, model = model, rearrangement = "NNI", control = phangorn::pml.control(trace = 0))
      list(tree = fit$tree, label = paste0("maximum likelihood (phangorn::pml_bb, ", model, ")"),
           citation = phangornCite)
    },
    fasttree = {
      prog <- findProgram(exe, c("FastTree", "fasttree", "FastTreeMP"), "FastTree")
      dir <- tempfile("moose-fasttree"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE))
      aln <- file.path(dir, "aln.fasta"); out <- file.path(dir, "tree.nwk")
      writeFastaAlignment(mat, aln)
      status <- system2(prog, c(if (type == "DNA") "-nt", "-quiet", args, shQuote(aln)), stdout = out, stderr = file.path(dir, "log.txt"))
      if (status != 0 || !file.exists(out) || file.size(out) == 0) {
        stop("FastTree failed:\n", paste(utils::tail(readLines(file.path(dir, "log.txt"), warn = FALSE), 10), collapse = "\n"), call. = FALSE)
      }
      list(tree = ape::read.tree(out), label = "FastTree",
           citation = "Price MN, Dehal PS, Arkin AP (2010). FastTree 2. PLoS ONE 5:e9490.")
    },
    iqtree = {
      prog <- findProgram(exe, c("iqtree3", "iqtree2", "iqtree"), "IQ-TREE")
      dir <- tempfile("moose-iqtree"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE))
      aln <- file.path(dir, "aln.fasta"); prefix <- file.path(dir, "run")
      writeFastaAlignment(mat, aln)
      status <- system2(prog, c("-s", shQuote(aln), "-pre", shQuote(prefix), "-quiet", "-redo",
                                if (!is.null(model)) c("-m", shQuote(model)), args),
                        stdout = file.path(dir, "out.txt"), stderr = file.path(dir, "err.txt"))
      treefile <- paste0(prefix, ".treefile")
      if (status != 0 || !file.exists(treefile)) {
        log <- unlist(lapply(file.path(dir, c("out.txt", "err.txt")), function(f) if (file.exists(f)) readLines(f, warn = FALSE)))
        stop("IQ-TREE failed:\n", paste(utils::tail(log, 10), collapse = "\n"), call. = FALSE)
      }
      list(tree = ape::read.tree(treefile), label = paste0("IQ-TREE", if (!is.null(model)) paste0(" (", model, ")")),
           citation = "Minh BQ et al. (2020). IQ-TREE 2. Mol Biol Evol 37:1530-1534.")
    })
}

writeFastaAlignment <- function(mat, file) {
  writeLines(as.vector(rbind(paste0(">", rownames(mat)), apply(mat, 1, paste, collapse = ""))), file)
}

# Root on an outgroup, keep an existing root, or root at the midpoint.
rootTree <- function(tr, outgroup) {
  if (length(outgroup)) {
    if (length(outgroup) == length(tr$tip.label)) stop("`outgroup` cannot be every sequence", call. = FALSE)
    rooted <- tryCatch(ape::root(tr, outgroup = outgroup, resolve.root = TRUE), error = function(e) NULL)
    if (is.null(rooted)) {
      stop("The `outgroup` sequences do not form one group in the tree; name a single outgroup sequence", call. = FALSE)
    }
    return(list(tree = rooted, how = "outgroup"))
  }
  if (ape::is.rooted(tr)) return(list(tree = tr, how = "as rooted by the tool"))
  if (length(tr$tip.label) < 3 || tr$Nnode == 1) return(list(tree = tr, how = "none needed"))
  how <- "midpoint"
  if (is.null(tr$edge.length)) {
    tr <- ape::compute.brlen(tr, 1); how <- "midpoint, counting each branch as one step"
  }
  if (requireNamespace("phangorn", quietly = TRUE)) return(list(tree = phangorn::midpoint(tr), how = how))
  # without phangorn: root on the tip farthest, on average, from the others
  far <- names(which.max(rowMeans(ape::cophenetic.phylo(tr))))
  list(tree = ape::root(tr, outgroup = far, resolve.root = TRUE), how = "on the most distant sequence (install phangorn for midpoint rooting)")
}

# Match names the user typed (outgroup, reference, tree tips) to sequence
# names: exactly, by the first word of a FASTA header, or with underscores
# standing for spaces, as Newick writes them.
sequenceNames <- function(x, names, what) {
  i <- match(x, names)
  first <- sub("\\s.*$", "", names)
  first[first %in% first[duplicated(first)]] <- NA
  for (alt in list(first, gsub(" ", "_", names, fixed = TRUE), gsub(" ", "_", first, fixed = TRUE))) {
    miss <- is.na(i)
    if (!any(miss)) break
    i[miss] <- match(x[miss], alt)
  }
  if (anyNA(i)) stop(what, " not in the alignment: ", paste(utils::head(x[is.na(i)], 5), collapse = ", "), call. = FALSE)
  names[i]
}

# Newick of a tree whose tips are t1, t2, ... with the real names put back,
# quoted where Newick needs it.
newickWithNames <- function(tr, tipNames) {
  plain <- grepl("^[A-Za-z0-9_.|-]+$", tipNames)
  quoted <- ifelse(plain, tipNames, paste0("'", gsub("'", "''", tipNames, fixed = TRUE), "'"))
  names(quoted) <- tr$tip.label
  s <- ape::write.tree(tr)
  m <- gregexpr("t[0-9]+", s)
  regmatches(s, m) <- list(unname(quoted[regmatches(s, m)[[1]]]))
  s
}
