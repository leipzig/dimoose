#' Which mutations each haplogroup carries
#'
#' Follows every haplogroup's path from the root of the tree and records, for
#' each requested site, whether the haplogroup's haplotype differs from the
#' root (RSRS) there. Back-mutations are applied as Haplogrep defines them
#' (they undo the latest change at that site), so a site gained and later
#' reverted on a lineage is not carried below the reversion. Insertions are
#' tracked as their own sites (`"573.X"`, `"2491.1"`), separate from
#' substitutions at the same position; a deletion counts as carried.
#'
#' @param haplogroups Haplogroup names, one per row of the result; repeats are
#'   allowed (e.g. one per sample).
#' @param sites Sites to report: positions as character (`"16311"`) or
#'   insertion sites (`"573.X"`). Defaults to the sites of
#'   [recurrentPositions()].
#' @param tree,mutations The tree and its mutations; default [phylotree17] and
#'   [phylotree17_mutations]. `tree` needs `haplogroup`, `parent` and `depth`;
#'   `mutations` needs `haplogroup`, `notation`, `position`, `type`,
#'   `ancestral` and `derived`.
#' @return An integer matrix of 0/1, one row per entry of `haplogroups` (row
#'   names are the haplogroups) and one column per site.
#' @seealso [recurrentPositions()], [macroHaplogroup()], [simulateExpression()]
#' @examples
#' haplotypeMatrix(c("H2a2a1", "U5b", "L0a1b"), sites = c("152", "16311", "16278"))
#' @export
haplotypeMatrix <- function(haplogroups, sites = NULL, tree = moose::phylotree17,
                            mutations = moose::phylotree17_mutations) {
  if (is.null(sites)) sites <- recurrentPositions(mutations = mutations)$site
  sites <- as.character(sites)
  unknown <- setdiff(unique(haplogroups), tree$haplogroup)
  if (length(unknown)) {
    stop("Unknown haplogroup(s): ", paste(utils::head(unknown, 5), collapse = ", "), call. = FALSE)
  }
  site <- mutationSite(mutations)
  keep <- site %in% sites
  muts <- mutations[keep, , drop = FALSE]
  muts$site <- site[keep]
  muts$col <- match(muts$site, sites)
  byHaplogroup <- split(seq_len(nrow(muts)), factor(muts$haplogroup, levels = tree$haplogroup))

  nH <- nrow(tree); nS <- length(sites)
  state <- matrix(NA_character_, nH, nS)
  ref <- matrix(NA_character_, nH, nS)
  parentRow <- match(tree$parent, tree$haplogroup)
  isInsertionSite <- grepl(".", sites, fixed = TRUE)
  for (i in order(tree$depth)) {
    p <- parentRow[i]
    if (!is.na(p)) { state[i, ] <- state[p, ]; ref[i, ] <- ref[p, ] }
    for (r in byHaplogroup[[i]]) {
      j <- muts$col[r]
      if (is.na(ref[i, j])) {
        ref[i, j] <- if (isInsertionSite[j] || is.na(muts$ancestral[r])) "" else muts$ancestral[r]
      }
      d <- muts$derived[r]
      state[i, j] <- if (!is.na(d)) d else if (muts$type[r] == "deletion") "d" else ""
    }
  }
  carries <- !is.na(state) & state != ref
  out <- carries[match(haplogroups, tree$haplogroup), , drop = FALSE] * 1L
  dimnames(out) <- list(haplogroups, sites)
  out
}

# Site key of each mutation: the position, or "position.insertion" for insertions
mutationSite <- function(mutations) {
  ins <- grepl(".", mutations$notation, fixed = TRUE)
  ifelse(ins, sub("^([0-9]+\\.[0-9X]+).*$", "\\1", mutations$notation), as.character(mutations$position))
}

#' Recurrent (homoplasic) mutation sites
#'
#' Sites that mutate independently on many branches of the tree, such as
#' 152, 16311 and 16189 in PhyloTree. These are the variants whose effects a
#' tree can find across unrelated lineages.
#'
#' @param min_branches Minimum number of branches (haplogroups) on which the
#'   site mutates.
#' @param types Mutation types to count; by default substitutions and
#'   back-mutations. Insertions and deletions are left out, except that a
#'   reverted insertion counts as a back-mutation at its insertion site
#'   (for example `"5899.1"`).
#' @param mutations Default [phylotree17_mutations].
#' @return A data frame of `site` and `n_branches`, most recurrent first.
#' @examples
#' head(recurrentPositions())
#' @export
recurrentPositions <- function(min_branches = 10, types = c("transition", "transversion", "back-mutation"),
                               mutations = moose::phylotree17_mutations) {
  m <- mutations[mutations$type %in% types, , drop = FALSE]
  site <- mutationSite(m)
  n <- tapply(m$haplogroup, site, function(h) length(unique(h)))
  out <- data.frame(site = names(n), n_branches = as.integer(n), stringsAsFactors = FALSE)
  out <- out[out$n_branches >= min_branches, , drop = FALSE]
  out <- out[order(-out$n_branches, suppressWarnings(as.numeric(out$site))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Macrohaplogroup of a haplogroup
#'
#' @param haplogroup Haplogroup names.
#' @param level `"letter"` (default) uses the conventional label: `L0` to
#'   `L6` for the African lineages and the leading letter otherwise (`H2a` is
#'   `H`, `U5b` is `U`). This is a naming convention, not a clade: for
#'   example D sits inside M phylogenetically. `"depth"` uses the ancestor at
#'   a fixed depth from the root, which is a true clade.
#' @param depth For `level = "depth"`, the depth of the ancestor to report;
#'   haplogroups shallower than that are returned as they are.
#' @param tree Default [phylotree17].
#' @return A character vector the length of `haplogroup`.
#' @examples
#' macroHaplogroup(c("H2a2a1", "L3e1", "U5b"))
#' macroHaplogroup("H2a", level = "depth", depth = 3)
#' @export
macroHaplogroup <- function(haplogroup, level = c("letter", "depth"), depth = 2, tree = moose::phylotree17) {
  level <- match.arg(level)
  if (level == "letter") {
    return(ifelse(grepl("^L[0-9]", haplogroup), sub("^(L[0-9]+).*$", "\\1", haplogroup),
      ifelse(haplogroup == "mtMRCA", haplogroup, substr(haplogroup, 1, 1))))
  }
  unknown <- setdiff(unique(haplogroup), tree$haplogroup)
  if (length(unknown)) {
    stop("Unknown haplogroup(s): ", paste(utils::head(unknown, 5), collapse = ", "), call. = FALSE)
  }
  parent <- stats::setNames(tree$parent, tree$haplogroup)
  dep <- stats::setNames(tree$depth, tree$haplogroup)
  u <- unique(haplogroup)
  anc <- vapply(u, function(h) {
    while (dep[[h]] > depth) h <- parent[[h]]
    h
  }, character(1))
  unname(anc[haplogroup])
}

# Substitution sites on the branches leading into the given haplogroups (the
# markers that define those clades)
cladeMarkerSites <- function(haplogroups, mutations = moose::phylotree17_mutations) {
  m <- mutations[mutations$haplogroup %in% haplogroups & mutations$type %in% c("transition", "transversion"), ]
  unique(mutationSite(m))
}
