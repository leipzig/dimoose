#' PhyloTree Build 17: the human mitochondrial DNA phylogeny
#'
#' The 5,435 haplogroups of PhyloTree Build 17 (van Oven 2015) as
#' distributed by Haplogrep 3 (release 17.2 of `phylotree-rsrs-17`), one row
#' per haplogroup, rooted at `mtMRCA`. Use [phylotreeKey()] to turn the tree,
#' or part of it, into an identification key, and [phylotree17_mutations] for
#' the mutations one per row.
#'
#' Rows are in the order of Haplogrep's `tree.xml`, which is preorder (each
#' haplogroup directly before its subclades). Names and mutations are
#' Haplogrep's, verbatim: names such as `H2a+152  16311` or `K1b1+(16093)`
#' label branches that PhyloTree leaves unnamed, and two names (`M4’’67`,
#' `M4’’67+16311!`) contain the Unicode character U+2019. Haplogrep's
#' trailing space on one name is trimmed.
#'
#' Mutations are in RSRS orientation: each is the state on the branch leading
#' to the haplogroup. `16362C` is a substitution (position and derived base),
#' `263G!` a back-mutation (it reverts the latest change at that position;
#' `!!` marks a second reversion), `315.1C` or `5899.XC` an insertion (`X`:
#' unspecified length) and `249d` a deletion. Unlike some other copies (e.g.
#' MToolBox's), PhyloTree's unstable mutations, which PhyloTree prints in
#' parentheses, are included; the parentheses are not recorded.
#'
#' @format A data frame with 5,435 rows and 5 columns:
#' \describe{
#'   \item{haplogroup}{Haplogroup name.}
#'   \item{parent}{Name of the parent haplogroup (`NA` for `mtMRCA`).}
#'   \item{depth}{Number of branches from `mtMRCA`.}
#'   \item{n_subclades}{Number of direct subclades.}
#'   \item{mutations}{Space-separated mutations of the branch leading to this
#'     haplogroup, as written by Haplogrep.}
#' }
#' @source Haplogrep 3 tree `phylotree-rsrs-17`, release 17.2, commit
#'   `0e79ddf1b78f7a1b81fb5d607bc31a6ddea7b18b`, `src/tree.xml`
#'   (<https://github.com/genepi/phylotree-rsrs-17>), MIT license. The
#'   conversion and a script that checks these data against GitHub are in
#'   `data-raw/phylotree17/` in the package sources.
#' @references
#' van Oven M (2015). PhyloTree Build 17: Growing the human mitochondrial DNA
#' tree. *Forensic Science International: Genetics Supplement Series* 5,
#' e392-e394. \doi{10.1016/j.fsigss.2015.09.155}
#'
#' Schönherr S, Weissensteiner H, Kronenberg F, Forer L (2023). Haplogrep 3 -
#' an interactive haplogroup classification and analysis platform.
#' *Nucleic Acids Research* 51, W263-W268. \doi{10.1093/nar/gkad284}
#' @seealso [phylotree17_mutations], [phylotreeKey()]
#' @examples
#' head(phylotree17)
#' phylotree17[phylotree17$parent %in% "H2a2a", ]
"phylotree17"

#' PhyloTree Build 17 mutations, one per row
#'
#' The mutations of every haplogroup in [phylotree17], one row per mutation,
#' in the order Haplogrep lists them, with the bases before and after worked
#' out by following the tree from the RSRS.
#'
#' Seven back-mutations revert a position that nothing earlier on their path
#' changes (six `16233C!`, e.g. in `D4c1b1`, and `D5a2` `1438A!`); for those
#' the written base is taken as the result.
#'
#' @format A data frame with 13,384 rows and 6 columns:
#' \describe{
#'   \item{haplogroup}{Haplogroup whose branch carries the mutation.}
#'   \item{notation}{The mutation as written by Haplogrep.}
#'   \item{position}{Position in the RSRS/rCRS coordinates.}
#'   \item{type}{`transition`, `transversion`, `back-mutation`,
#'     `insertion` or `deletion`.}
#'   \item{ancestral}{Base before the mutation (for a reverted insertion, the
#'     inserted sequence); `NA` for insertions.}
#'   \item{derived}{Base after the mutation, or the inserted sequence; `NA`
#'     for deletions and reverted insertions.}
#' }
#' @source See [phylotree17].
#' @examples
#' table(phylotree17_mutations$type)
#' phylotree17_mutations[phylotree17_mutations$haplogroup == "J1c", ]
"phylotree17_mutations"

#' Build an identification key from PhyloTree Build 17
#'
#' Turns [phylotree17], or the part of it below `root`, into a [dimoose] key.
#' Each haplogroup with subclades becomes a step at which the user picks the
#' subclade whose defining mutations the sample carries. With `paragroups =
#' TRUE` every step also offers "none of these", which identifies the
#' paragroup, written as in PhyloTree with a trailing `*` (e.g. `H2a*`).
#'
#' The whole tree gives a very large key (2,420 steps and 5,435 possible
#' results with paragroups), so for [exportWizard()] a subtree or a
#' `maxDepth` is usually more practical.
#'
#' @param root Haplogroup to start from; the default, `"mtMRCA"`, is the
#'   whole tree.
#' @param paragroups If `TRUE`, add a "none of these" choice to every step.
#' @param maxDepth Maximum number of steps below `root`. Haplogroups at that
#'   depth become results even if they have subclades.
#' @return A [dimoose] object whose `leads` have a `Label` column with the
#'   haplogroup names.
#' @seealso [phylotree17], [exportWizard()]
#' @examples
#' h2a <- phylotreeKey("H2a")
#' head(h2a$leads)
#' \dontrun{
#' exportWizard(phylotreeKey("U5"), "u5.html")
#' exportWizard(phylotreeKey(maxDepth = 6), "macrohaplogroups.html")
#' }
#' @export
phylotreeKey <- function(root = "mtMRCA", paragroups = TRUE, maxDepth = Inf) {
  tree <- dimoose::phylotree17
  if (!is.character(root) || length(root) != 1 || !root %in% tree$haplogroup) {
    stop("`root` must be a haplogroup in phylotree17", call. = FALSE)
  }
  if (!is.numeric(maxDepth) || length(maxDepth) != 1 || maxDepth < 1) {
    stop("`maxDepth` must be a number of at least 1", call. = FALSE)
  }

  # The subtree below root, in preorder (phylotree17 is stored in preorder)
  rootRow <- match(root, tree$haplogroup)
  below <- rootRow
  frontier <- root
  while (length(frontier) > 0) {
    kids <- which(tree$parent %in% frontier)
    kids <- kids[tree$depth[kids] - tree$depth[rootRow] <= maxDepth]
    below <- c(below, kids)
    frontier <- tree$haplogroup[kids]
  }
  sub <- tree[sort(below), , drop = FALSE]
  rel <- sub$depth - tree$depth[rootRow]
  hasKids <- sub$haplogroup %in% sub$parent[-1]
  steps <- sub$haplogroup[hasKids & rel < maxDepth]
  if (length(steps) == 0) {
    stop("`", root, "` has no subclades to choose between", call. = FALSE)
  }

  rows <- lapply(steps, function(h) {
    kids <- sub[sub$parent %in% h, , drop = FALSE]
    kidIsStep <- kids$haplogroup %in% steps
    out <- data.frame(
      Statement = h,
      Choice = as.character(seq_len(nrow(kids))),
      Character = ifelse(nzchar(kids$mutations), kids$mutations, "No defining mutations listed"),
      Next = ifelse(kidIsStep, kids$haplogroup, "-"),
      Taxon = ifelse(kidIsStep, "", kids$haplogroup),
      Label = kids$haplogroup,
      stringsAsFactors = FALSE
    )
    if (paragroups) {
      out <- rbind(out, data.frame(
        Statement = h,
        Choice = as.character(nrow(kids) + 1),
        Character = "None of the subclades above",
        Next = "-",
        Taxon = paste0(h, "*"),
        Label = paste0(h, "*"),
        stringsAsFactors = FALSE
      ))
    }
    out
  })
  leads <- do.call(rbind, rows)
  rownames(leads) <- NULL

  meta <- data.frame(
    key = c("citation", "source", "node_label", "notation"),
    value = c(
      "van Oven M (2015). PhyloTree Build 17: Growing the human mitochondrial DNA tree. Forensic Sci Int Genet Suppl Ser 5:e392-e394. Tree as distributed by Haplogrep 3 (Schoenherr et al. 2023).",
      "https://github.com/genepi/phylotree-rsrs-17 (release 17.2), src/tree.xml",
      "Haplogroup",
      "Mutations are in RSRS orientation; ! marks a back-mutation."
    ),
    stringsAsFactors = FALSE
  )
  desc <- if (root == "mtMRCA") {
    "PhyloTree Build 17: human mitochondrial DNA haplogroups"
  } else {
    sprintf("PhyloTree Build 17: haplogroup %s and its subclades", root)
  }
  keyFromLeads(leads, desc, meta)
}
