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
#' two sides at all, they share a result (`"A / B"`), as do identical
#' sequences. Gaps and ambiguity codes are treated as missing data.
#'
#' The first site of each couplet is also a machine-readable test, so
#' [classify()] can place sequences scored with [scoreAlignment()].
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
#'   labels. This is the way to use any other phylogeny program.
#' @param outgroup Name(s) of the sequence(s) to root on. Without it, a tree
#'   that is not already rooted is rooted at its midpoint.
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
#'   in Newick format (`newick`) and how many couplets lack a diagnostic
#'   site.
#' @seealso [scoreAlignment()], [phylotreeKey()], [toNewick()]
#' @examples
#' aln <- c(human = "ACGTACGTACGA", chimp = "ACGTACGTATGA", mouse = "ACCTACATGCGA",
#'          rat   = "ACCTACATGCGT", fish  = "TCCTTCGTACCA")
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   key <- keyFromAlignment(aln, outgroup = "fish")
#'   key$leads[, c("Statement", "Character", "Next", "Taxon")]
#'   classify(key, scoreAlignment(key, aln))
#' }
#' \dontrun{
#' keyFromAlignment("aligned.fasta", tool = "iqtree", outgroup = "NC_012920")
#' }
#' @export
keyFromAlignment <- function(alignment, tool = c("nj", "bionj", "upgma", "parsimony", "ml", "fasttree", "iqtree"),
                             tree = NULL, outgroup = NULL, reference = NULL, type = c("auto", "DNA", "AA"),
                             model = NULL, maxSites = 3, exe = NULL, args = NULL,
                             desc = "Key generated from a sequence alignment", meta = NULL) {
  tool <- match.arg(tool)
  type <- match.arg(type)
  if (!requireNamespace("ape", quietly = TRUE)) stop("Install the ape package to build keys from alignments", call. = FALSE)
  mat <- alignmentMatrix(alignment)
  if (type == "auto") type <- alignmentType(mat)
  if (type == "DNA") mat[mat == "U"] <- "T"
  if (nrow(mat) < 2) stop("An alignment needs at least two sequences to make a key", call. = FALSE)
  if (!is.null(reference) && !reference %in% rownames(mat)) stop("`reference` is not a sequence in the alignment: ", reference, call. = FALSE)
  if (length(setdiff(outgroup, rownames(mat)))) {
    stop("`outgroup` is not in the alignment: ", paste(setdiff(outgroup, rownames(mat)), collapse = ", "), call. = FALSE)
  }
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
    tr <- if (inherits(tree, "phylo")) tree else if (file.exists(tree)) ape::read.tree(tree) else ape::read.tree(text = tree)
    if (!inherits(tr, "phylo")) stop("`tree` is not a single tree", call. = FALSE)
    unknown <- setdiff(tr$tip.label, rownames(mat))
    if (length(unknown)) {
      stop("`tree` has tip(s) that are not sequences in the alignment: ", paste(utils::head(unknown, 5), collapse = ", "), call. = FALSE)
    }
    if (anyDuplicated(tr$tip.label)) stop("`tree` has duplicated tip labels", call. = FALSE)
    tipNames <- tr$tip.label
    tipMat <- mat[tipNames, , drop = FALSE]
    safe <- paste0("t", seq_along(tipNames))
    rownames(tipMat) <- safe
    outSafe <- safe[tipNames %in% outgroup]
    tr$tip.label <- safe
    toolLabel <- "user-supplied tree"; citation <- NA_character_
  }
  names(tipNames) <- safe

  rooted <- rootTree(tr, outSafe)
  tr <- ape::multi2di(rooted$tree, random = FALSE)

  # one logical tips x sites matrix per state, over the variable sites only
  states <- if (type == "DNA") c("A", "C", "G", "T") else strsplit("ACDEFGHIKLMNPQRSTVWY", "")[[1]]
  known <- matrix(tipMat %in% states, nrow(tipMat), dimnames = dimnames(tipMat))
  variable <- which(vapply(seq_len(ncol(tipMat)), function(j) length(unique(tipMat[known[, j], j])) > 1, logical(1)))
  hasState <- lapply(states, function(s) tipMat[, variable, drop = FALSE] == s)
  names(hasState) <- states

  ntip <- length(tr$tip.label)
  kidsOf <- split(tr$edge[, 2], tr$edge[, 1])
  tipsUnder <- function(node) if (node <= ntip) tr$tip.label[node] else unlist(lapply(kidsOf[[as.character(node)]], tipsUnder))

  # Sites separating tip sets A and B: list(cols, a, b, diagnostic), or NULL
  separate <- function(A, B) {
    if (!length(variable)) return(NULL)
    cA <- vapply(hasState, function(m) colSums(m[A, , drop = FALSE]), numeric(length(variable)))
    cB <- vapply(hasState, function(m) colSums(m[B, , drop = FALSE]), numeric(length(variable)))
    dim(cA) <- dim(cB) <- c(length(variable), length(states))
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
         b = lapply(pick, function(i) states[toB[i, ]]), diagnostic = any(diagnostic))
  }

  rows <- list(); counter <- 0L; weak <- 0L; features <- list()
  leafOf <- function(tips) paste(tipNames[tips], collapse = " / ")
  walk <- function(node) {
    if (node <= ntip) return(list(leaf = leafOf(tr$tip.label[node])))
    kids <- kidsOf[[as.character(node)]]
    A <- tipsUnder(kids[1]); B <- tipsUnder(kids[2])
    sp <- separate(A, B)
    if (is.null(sp)) return(list(leaf = leafOf(c(A, B))))
    counter <<- counter + 1L
    id <- as.character(counter)
    if (!sp$diagnostic) weak <<- weak + 1L
    lead <- function(sets) {
      txt <- paste(paste0(pos[sp$cols], vapply(sets, paste, "", collapse = "/")), collapse = " ")
      if (sp$diagnostic) txt else paste(txt, "(most)")
    }
    fid <- sprintf("site:%s:%s", pos[sp$cols[1]], paste(sp$a[[1]], collapse = ""))
    features[[fid]] <<- paste0(pos[sp$cols[1]], paste(sp$a[[1]], collapse = "/"))
    built <- lapply(kids, walk)
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"), Character = c(lead(sp$a), lead(sp$b)),
      Next = vapply(built, function(k) if (is.null(k$leaf)) k$id else "-", ""),
      Taxon = vapply(built, function(k) if (is.null(k$leaf)) "" else k$leaf, ""),
      Question = paste(if (type == "DNA") "Base at" else "Residue at", pos[sp$cols[1]]),
      Feature = fid, Test = c(">", "<="), Threshold = 0.5, stringsAsFactors = FALSE)
    list(id = id)
  }
  top <- walk(ntip + 1L)
  if (!is.null(top$leaf)) stop("No site in the alignment separates the sequences", call. = FALSE)
  leads <- do.call(rbind, rows[order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  if (weak > 0) {
    warning(weak, " couplet(s) have no fully diagnostic site; their leads are marked \"(most)\"", call. = FALSE)
  }

  named <- tr; named$tip.label <- unname(tipNames[tr$tip.label])
  info <- data.frame(
    key = c("node_label", "tool", "rooting", "sequences", "sites", "sequence_type", "weak_couplets", "notation", "newick"),
    value = c("Couplet", toolLabel, rooted$how, nrow(mat), ncol(mat), type, weak,
      paste0("Leads give a site and its state, e.g. 152C; sites are numbered by ",
             if (is.null(reference)) "alignment column" else paste0("position in ", reference),
             ". Gaps and ambiguity codes are treated as missing."),
      ape::write.tree(named)),
    stringsAsFactors = FALSE)
  if (!is.null(reference)) info <- rbind(info, data.frame(key = "reference", value = reference, stringsAsFactors = FALSE))
  if (!is.na(citation)) info <- rbind(info, data.frame(key = "citation", value = citation, stringsAsFactors = FALSE))
  if (!is.null(meta)) info <- rbind(meta, info[!info$key %in% meta$key, ])
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
scoreAlignment <- function(key, alignment, reference = NULL) {
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
    if (length(outgroup) > 1 && !ape::is.monophyletic(ape::unroot(tr), outgroup)) {
      stop("The `outgroup` sequences do not form one group in the tree; name a single outgroup sequence", call. = FALSE)
    }
    return(list(tree = ape::root(tr, outgroup = outgroup, resolve.root = TRUE), how = "outgroup"))
  }
  if (ape::is.rooted(tr)) return(list(tree = tr, how = "as rooted by the tool"))
  if (length(tr$tip.label) < 3) return(list(tree = tr, how = "none needed"))
  if (requireNamespace("phangorn", quietly = TRUE) && !is.null(tr$edge.length)) {
    return(list(tree = phangorn::midpoint(tr), how = "midpoint"))
  }
  # without phangorn: root on the tip farthest, on average, from the others
  far <- if (is.null(tr$edge.length)) tr$tip.label[1] else names(which.max(rowMeans(ape::cophenetic.phylo(tr))))
  list(tree = ape::root(tr, outgroup = far, resolve.root = TRUE), how = paste("on the most distant sequence (install phangorn for midpoint rooting)"))
}
