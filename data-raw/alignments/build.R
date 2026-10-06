# Builds the example alignments in inst/extdata/. Run from the package root:
#   Rscript data-raw/alignments/build.R
#
# aligned.fasta, aligned.nwk
#   The woodmouse alignment that ships with ape (15 cytochrome b sequences of
#   Apodemus sylvaticus, 965 sites; Michaux et al. 2003, Molecular Ecology
#   12:685-697), written as FASTA, and a neighbour-joining tree of it.
#
# mtdna.fasta
#   Whole mitochondrial genomes for a few PhyloTree Build 17 haplogroups.
#   These are not sequences of individuals: each is the RSRS root sequence
#   with the mutations on the path to that haplogroup applied, so it is what
#   PhyloTree says the founder of the haplogroup carried. H2a2a1 is the
#   haplogroup of the rCRS, so sites numbered by that sequence are in the
#   usual rCRS coordinates.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
out <- "inst/extdata"

# ---- woodmouse ---------------------------------------------------------------
loadNamespace("ape"); data(woodmouse, package = "ape")
wm <- as.character(woodmouse); wm[] <- toupper(wm)
writeLines(as.vector(rbind(paste0(">", rownames(wm)), apply(wm, 1, paste, collapse = ""))), file.path(out, "aligned.fasta"))
ape::write.tree(ape::nj(ape::dist.dna(woodmouse)), file.path(out, "aligned.nwk"))

# ---- PhyloTree haplogroup sequences --------------------------------------------
# RSRS (Behar et al. 2012) as distributed with the tree dimoose ships, release 17.2
rsrsUrl <- "https://raw.githubusercontent.com/genepi/phylotree-rsrs-17/0e79ddf/src/rsrs.fasta"
rsrsFile <- Sys.getenv("RSRS_FASTA", "")
if (!nzchar(rsrsFile)) { rsrsFile <- tempfile(fileext = ".fasta"); utils::download.file(rsrsUrl, rsrsFile, quiet = TRUE) }
rsrs <- strsplit(paste(readLines(rsrsFile, warn = FALSE)[-1], collapse = ""), "")[[1]]
stopifnot(length(rsrs) == 16569)

haplogroups <- c("L0a1", "L1c2a", "L2a1", "L3e1", "M7a1", "D4a", "A2", "B4a1a", "N1a1", "U5a1", "K1a", "J1c", "T2b", "H2a2a1")
tree <- phylotree17; muts <- phylotree17_mutations
stopifnot(all(haplogroups %in% tree$haplogroup))
pathTo <- function(h) { p <- h; while (!is.na(tree$parent[match(p[1], tree$haplogroup)])) p <- c(tree$parent[match(p[1], tree$haplogroup)], p); p }

mismatches <- 0
build <- function(h) {
  s <- rsrs; ins <- list()
  for (node in pathTo(h)) {
    m <- muts[muts$haplogroup == node, ]
    for (i in seq_len(nrow(m))) {
      note <- m$notation[i]; pos <- m$position[i]
      insertion <- regmatches(note, regexec("^[0-9]+\\.([0-9]+)([ACGT]+)(!*)$", note))[[1]]
      if (length(insertion)) {
        key <- as.character(pos); k <- as.integer(insertion[2])
        cur <- if (is.null(ins[[key]])) character() else ins[[key]]
        if (nzchar(insertion[4])) cur <- cur[seq_len(k - 1)] else cur[k + seq_len(nchar(insertion[3])) - 1] <- strsplit(insertion[3], "")[[1]]
        ins[[key]] <- cur
      } else if (grepl("\\.X", note)) {
        next                                      # insertion of unspecified length
      } else if (m$type[i] == "deletion") {
        s[pos] <- "-"
      } else {
        if (!is.na(m$ancestral[i]) && s[pos] != m$ancestral[i] && s[pos] != "N") mismatches <<- mismatches + 1
        s[pos] <- m$derived[i]
      }
    }
  }
  list(s = s, ins = ins)
}
seqs <- lapply(haplogroups, build); names(seqs) <- haplogroups
message("substitutions whose ancestral base differs from the sequence so far: ", mismatches)

# put the insertions in their own alignment columns, after the site they follow
insPos <- sort(unique(as.integer(unlist(lapply(seqs, function(x) names(x$ins))))))
insLen <- vapply(insPos, function(p) max(vapply(seqs, function(x) length(x$ins[[as.character(p)]]), 0L)), 0L)
aligned <- vapply(seqs, function(x) {
  cols <- as.list(x$s)
  for (j in seq_along(insPos)) {
    got <- x$ins[[as.character(insPos[j])]]
    cols[[insPos[j]]] <- c(x$s[insPos[j]], got, rep("-", insLen[j] - length(got)))
  }
  paste(unlist(cols), collapse = "")
}, "")
stopifnot(length(unique(nchar(aligned))) == 1)
fasta <- unlist(lapply(names(aligned), function(n) c(paste0(">", n), substring(aligned[[n]], seq(1, nchar(aligned[[n]]), 70), pmin(seq(70, nchar(aligned[[n]]) + 69, 70), nchar(aligned[[n]]))))))
writeLines(fasta, file.path(out, "mtdna.fasta"))
message("mtdna.fasta: ", length(aligned), " sequences, ", nchar(aligned[[1]]), " columns; insertions after ", paste(insPos, collapse = ", "))
