#' Simulate expression data on PhyloTree
#'
#' Simulates per-sample expression for a set of genes, where recurrent
#' mutations (variants that arise independently on many branches) shift
#' expression by fixed amounts on top of a baseline that differs between
#' macrohaplogroups. It is the ground truth for testing [mecit()]: a good
#' method finds the mutation effects as splits and does not split on clade
#' markers that only track the macrohaplogroup baselines.
#'
#' Samples are drawn uniformly from the leaf haplogroups of [phylotree17],
#' so their macrohaplogroups are as unbalanced as the tree itself (H is far
#' more common than L5). For sample *i* and gene *g*:
#'
#' `expr[i, g] = b[g, macro(i)] + sum_s beta[g, s] * X[i, s] + slope + noise`
#'
#' Genes come in three kinds: `"mutation"` genes have a baseline and one or
#' more mutation effects, `"baseline"` genes have only the macrohaplogroup
#' baseline, and `"null"` genes are pure noise.
#'
#' The default effect sites (16362, 150, 709, 16093) are highly recurrent
#' but carried by a minority of lineages across many macrohaplogroups. The
#' most-cited recurrent sites (152, 16311, 146, 16189) are poor effect sites
#' in RSRS orientation: they are also on deep branches (16311 is an L3
#' marker), so most lineages carry them and carrying them largely tracks
#' clade membership. They are included as decoys instead.
#'
#' @param n Number of samples.
#' @param genes Number of genes.
#' @param effectSites Sites that can carry mutation effects.
#' @param propMutation,propBaseline Proportions of mutation and baseline
#'   genes; the rest are null.
#' @param sitesPerGene Possible numbers of effect sites per mutation gene.
#' @param effect Size of each mutation effect (its sign is random).
#' @param macroSD Standard deviation of the macrohaplogroup baselines.
#' @param slopeSD If positive, each mutation effect also varies between
#'   macrohaplogroups with this standard deviation (a random slope).
#' @param noise Residual standard deviation.
#' @param decoys Extra candidate split sites with no effect. By default the
#'   most recurrent other sites plus the markers of the four most common
#'   macrohaplogroups in the sample.
#' @param macroLevel Passed to [macroHaplogroup()] as `level`.
#' @param seed Random seed.
#' @return A list with `expr` (samples x genes), `samples` (data frame of
#'   `sample`, `haplogroup`, `macro`), `X` (samples x sites, 0/1, from
#'   [haplotypeMatrix()]), `truth` (`beta`, genes x sites; `b`, genes x
#'   macrohaplogroups; `geneType`; and `slope` when `slopeSD > 0`),
#'   `effectSites`, `markerSites` and `decoySites`.
#' @seealso [mecit()], [haplotypeMatrix()]
#' @examples
#' sim <- simulateExpression(n = 300, genes = 10)
#' table(sim$truth$geneType)
#' @export
simulateExpression <- function(n = 1000, genes = 20, effectSites = c("16362", "150", "709", "16093"),
                               propMutation = 0.4, propBaseline = 0.3, sitesPerGene = 1:2,
                               effect = 1, macroSD = 1, slopeSD = 0, noise = 1, decoys = NULL,
                               macroLevel = "letter", seed = 1) {
  set.seed(seed)
  tree <- moose::phylotree17
  leaves <- tree$haplogroup[tree$n_subclades == 0]
  hap <- sample(leaves, n, replace = TRUE)
  macro <- macroHaplogroup(hap, level = macroLevel)
  ids <- paste0("s", seq_len(n))

  topMacros <- names(sort(table(macro), decreasing = TRUE))[seq_len(min(4, length(unique(macro))))]
  markerSites <- setdiff(cladeMarkerSites(intersect(topMacros, tree$haplogroup)), effectSites)
  if (is.null(decoys)) {
    common <- utils::head(setdiff(recurrentPositions(min_branches = 50)$site, effectSites), 6)
    decoys <- unique(c(common, markerSites))
  }
  decoys <- setdiff(decoys, effectSites)
  sites <- unique(c(effectSites, decoys))
  X <- haplotypeMatrix(hap, sites)
  rownames(X) <- ids

  nMut <- round(genes * propMutation)
  nBase <- round(genes * propBaseline)
  geneType <- factor(rep(c("mutation", "baseline", "null"), c(nMut, nBase, genes - nMut - nBase)),
                     levels = c("mutation", "baseline", "null"))
  geneNames <- paste0("gene", seq_len(genes))
  macros <- sort(unique(macro))

  beta <- matrix(0, genes, length(sites), dimnames = list(geneNames, sites))
  for (g in which(geneType == "mutation")) {
    k <- sitesPerGene[sample.int(length(sitesPerGene), 1)]
    s <- sample(effectSites, min(k, length(effectSites)))
    beta[g, s] <- effect * sample(c(-1, 1), length(s), replace = TRUE)
  }
  b <- matrix(0, genes, length(macros), dimnames = list(geneNames, macros))
  hasBase <- geneType != "null"
  b[hasBase, ] <- stats::rnorm(sum(hasBase) * length(macros), 0, macroSD)

  expr <- matrix(0, n, genes, dimnames = list(ids, geneNames))
  slope <- NULL
  if (slopeSD > 0) slope <- array(0, c(genes, length(macros), length(sites)), dimnames = list(geneNames, macros, sites))
  for (g in seq_len(genes)) {
    mu <- b[g, macro] + as.vector(X %*% beta[g, ])
    if (slopeSD > 0 && geneType[g] == "mutation") {
      s <- sites[beta[g, ] != 0]
      dev <- matrix(stats::rnorm(length(macros) * length(s), 0, slopeSD), length(macros), length(s),
                    dimnames = list(macros, s))
      slope[g, , s] <- dev
      mu <- mu + rowSums(X[, s, drop = FALSE] * dev[macro, , drop = FALSE])
    }
    expr[, g] <- mu + stats::rnorm(n, 0, noise)
  }

  truth <- list(beta = beta, b = b, geneType = geneType)
  if (!is.null(slope)) truth$slope <- slope
  list(expr = expr,
       samples = data.frame(sample = ids, haplogroup = hap, macro = macro, stringsAsFactors = FALSE),
       X = X, truth = truth, effectSites = effectSites, markerSites = markerSites,
       decoySites = decoys)
}
