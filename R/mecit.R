#' Mixed-effects conditional inference trees
#'
#' Fits a tree that partitions observations on candidate split variables (for
#' example which mutations each sample carries, from [haplotypeMatrix()])
#' while a random effect absorbs differences between clusters (for example
#' macrohaplogroups, from [macroHaplogroup()]). Without the random effect, a
#' tree also splits on variables that merely track the clusters, such as
#' clade-defining markers; with it, those differences are removed before the
#' tree looks for splits.
#'
#' `method = "ctree"` (the default) is the RE-EM algorithm of Sela & Simonoff
#' (2012) with conditional inference trees, as proposed by Fu & Simonoff
#' (2015). It alternates between (1) a [partykit::ctree()] on the response
#' minus the current random-effect contribution and (2) a linear mixed model
#' ([lme4::lmer()]) with one fixed effect per terminal node plus the random
#' effects, until the random effects stop changing. `method = "mob"` uses
#' model-based partitioning through [glmertree::lmertree()] (Fokkema et al.
#' 2018). In both, `ranefstart = TRUE` estimates the random effects from an
#' intercept-only mixed model before the first tree, which keeps that tree from
#' splitting on cluster-level variables.
#'
#' With `cluster = NULL` the result is a plain conditional inference tree, the
#' baseline a mixed-effects tree is compared with.
#'
#' @param y Numeric response, one value per observation.
#' @param partition Matrix or data frame of candidate split variables, one row
#'   per observation, with column names (which may be non-syntactic, like
#'   `"16311"`).
#' @param cluster Cluster of each observation, or `NULL` for no random
#'   effect.
#' @param method `"ctree"` or `"mob"`.
#' @param slope Optional names of `partition` columns to give random slopes
#'   within clusters, as in `(1 + slope | cluster)`.
#' @param alpha Significance level for splitting (Bonferroni-adjusted over
#'   the candidate variables).
#' @param minbucket Smallest allowed terminal node.
#' @param maxdepth Maximum tree depth.
#' @param ranefstart If `TRUE`, start from random effects estimated without a
#'   tree.
#' @param abstol,maxit Convergence tolerance and the maximum number of
#'   iterations. For `"ctree"` the tolerance is on the largest change in any
#'   observation's random-effect contribution; for `"mob"` it is passed to
#'   [glmertree::lmertree()], where it applies to the change in log-likelihood.
#' @return An object of class `mecit`: `tree` (a partykit tree), `lmer` (the
#'   final mixed model, or `NULL`), `strata` (data frame of `node`, `mean`
#'   and `n`; `mean` is the stratum level net of random effects), `node`
#'   (terminal node of each observation), `ranef` (random-effect
#'   contribution of each observation), `method`, `iterations` and
#'   `converged`.
#' @references
#' Sela RJ, Simonoff JS (2012). RE-EM trees: a data mining approach for
#' longitudinal and clustered data. *Machine Learning* 86, 169-207.
#' \doi{10.1007/s10994-011-5258-3}
#'
#' Fu W, Simonoff JS (2015). Unbiased regression trees for longitudinal and
#' clustered data. *Computational Statistics & Data Analysis* 88, 53-74.
#' \doi{10.1016/j.csda.2015.02.004}
#'
#' Fokkema M, Smits N, Zeileis A, Hothorn T, Kelderman H (2018). Detecting
#' treatment-subgroup interactions in clustered data with generalized linear
#' mixed-effects model trees. *Behavior Research Methods* 50, 2016-2034.
#' \doi{10.3758/s13428-017-0971-x}
#' @seealso [splitVariables()], [keyFromMecit()], [simulateExpression()]
#' @examples
#' \dontrun{
#' sim <- simulateExpression(n = 600, genes = 6)
#' fit <- mecit(sim$expr[, 1], sim$X, sim$samples$macro)
#' fit
#' exportWizard(keyFromMecit(fit), "mecit.html")
#' }
#' @export
mecit <- function(y, partition, cluster = NULL, method = c("ctree", "mob"), slope = NULL,
                  alpha = 0.05, minbucket = 20L, maxdepth = Inf, ranefstart = TRUE,
                  abstol = 1e-3, maxit = 50L) {
  method <- match.arg(method)
  if (!requireNamespace("partykit", quietly = TRUE)) stop("Install the partykit package to fit trees", call. = FALSE)
  if (!is.null(cluster) && !requireNamespace("lme4", quietly = TRUE)) {
    stop("Install the lme4 package to fit random effects", call. = FALSE)
  }
  if (is.null(colnames(partition))) stop("`partition` needs column names", call. = FALSE)
  X <- as.data.frame(partition, stringsAsFactors = FALSE, optional = TRUE)
  if (length(y) != nrow(X)) stop("`y` and `partition` must have the same number of rows", call. = FALSE)
  if (!is.null(cluster) && length(cluster) != nrow(X)) {
    stop("`cluster` must have one entry per row of `partition`", call. = FALSE)
  }
  if (anyNA(y) || anyNA(X) || (!is.null(cluster) && anyNA(cluster))) {
    stop("`y`, `partition` and `cluster` must not have missing values", call. = FALSE)
  }
  orig <- colnames(partition)
  if (length(slope) && !all(slope %in% orig)) {
    stop("`slope` names column(s) not in `partition`: ", paste(setdiff(slope, orig), collapse = ", "), call. = FALSE)
  }
  # syntactic names that cannot collide with the internal columns
  reserved <- c("y_", "ystar_", "cluster_", "node_")
  safe <- make.names(c(reserved, orig), unique = TRUE)[-seq_along(reserved)]
  names(X) <- safe
  d <- data.frame(y_ = as.numeric(y), X, check.names = FALSE)
  treeFormula <- stats::reformulate(paste0("`", safe, "`"), response = "ystar_")
  control <- partykit::ctree_control(alpha = alpha, minbucket = minbucket, maxdepth = maxdepth)
  out <- list(method = if (is.null(cluster)) "ctree (no random effects)" else method,
              names = stats::setNames(orig, safe), slope = slope, lmer = NULL,
              iterations = 0L, converged = TRUE)

  if (is.null(cluster)) {
    d$ystar_ <- d$y_
    tree <- partykit::ctree(treeFormula, data = d, control = control)
    re <- rep(0, nrow(d))
  } else {
    d$cluster_ <- factor(cluster)
    slopeSafe <- paste0("`", safe[match(slope, orig)], "`")
    reTerm <- if (length(slope)) sprintf("(1 + %s | cluster_)", paste(slopeSafe, collapse = " + ")) else "(1 | cluster_)"
    # Random slopes are deviations around a fixed slope; without the fixed term
    # the random slopes would absorb the whole effect before the tree sees it.
    slopeFixed <- if (length(slope)) paste0(" + ", paste(slopeSafe, collapse = " + ")) else ""
    reContrib <- function(m) stats::predict(m) - stats::predict(m, re.form = NA)
    fitLmer <- function(f) suppressMessages(lme4::lmer(stats::as.formula(f), data = d, REML = TRUE,
      control = lme4::lmerControl(check.rankX = "silent.drop.cols")))

    if (method == "mob") {
      if (!requireNamespace("glmertree", quietly = TRUE)) stop("Install the glmertree package for method = \"mob\"", call. = FALSE)
      if (length(slope)) stop("Random slopes are supported with method = \"ctree\"", call. = FALSE)
      f <- stats::as.formula(paste("y_ ~ 1 | cluster_ |", paste0("`", safe, "`", collapse = " + ")))
      fit <- suppressMessages(glmertree::lmertree(f, data = d, ranefstart = if (ranefstart) TRUE else NULL,
        abstol = abstol, maxit = maxit, alpha = alpha, minsize = minbucket, maxdepth = maxdepth))
      tree <- fit$tree
      out$lmer <- fit$lmer
      re <- reContrib(fit$lmer)
      out$iterations <- as.integer(fit$iterations)
      # lmertree stops on convergence, on oscillation, or at maxit; it does
      # not record which, so reaching maxit is reported as not converged
      out$converged <- fit$iterations < maxit
    } else {
      re <- if (ranefstart) reContrib(fitLmer(paste0("y_ ~ 1", slopeFixed, " + ", reTerm))) else rep(0, nrow(d))
      out$converged <- FALSE
      for (it in seq_len(maxit)) {
        d$ystar_ <- d$y_ - re
        tree <- partykit::ctree(treeFormula, data = d, control = control)
        d$node_ <- factor(stats::predict(tree, newdata = d, type = "node"))
        fixed <- if (nlevels(d$node_) > 1) "y_ ~ 0 + node_" else "y_ ~ 1"
        m <- fitLmer(paste0(fixed, slopeFixed, " + ", reTerm))
        newRe <- reContrib(m)
        delta <- max(abs(newRe - re))
        re <- newRe
        out$iterations <- it
        if (delta < abstol) { out$converged <- TRUE; break }
      }
      out$lmer <- m
    }
  }
  node <- as.integer(stats::predict(tree, newdata = d, type = "node"))
  level <- d$y_ - re
  out$tree <- tree
  out$node <- node
  out$ranef <- re
  out$strata <- data.frame(node = sort(unique(node)),
                           mean = as.numeric(tapply(level, node, mean)),
                           n = as.integer(table(node)))
  structure(out, class = "mecit")
}

#' @export
print.mecit <- function(x, ...) {
  sv <- splitVariables(x)
  cat("<dimoose mecit> ", x$method, "\n", sep = "")
  cat(sprintf("  %d strata; splits on: %s\n", nrow(x$strata), if (length(sv)) paste(sv, collapse = ", ") else "(none)"))
  if (!is.null(x$lmer)) {
    k <- nlevels(lme4::getME(x$lmer, "flist")[[1]])
    cat(sprintf("  random effects over %d clusters%s; %s after %d iteration(s)\n", k,
      if (length(x$slope)) paste0(" (slopes: ", paste(x$slope, collapse = ", "), ")") else "",
      if (x$converged) "converged" else "not converged", x$iterations))
  }
  invisible(x)
}

#' Variables a fitted tree splits on
#'
#' @param fit A [mecit()] fit.
#' @return The names (as given in `partition`) of the variables used in any
#'   split, in the order they first appear; `character(0)` if the tree has no
#'   splits.
#' @export
splitVariables <- function(fit) {
  tree <- fit$tree
  inner <- setdiff(partykit::nodeids(tree), partykit::nodeids(tree, terminal = TRUE))
  if (length(inner) == 0) return(character(0))
  varids <- unlist(partykit::nodeapply(tree, ids = inner,
    FUN = function(n) partykit::varid_split(partykit::split_node(n))))
  safe <- names(tree$data)[varids]
  unname(unique(fit$names[safe]))
}

#' Turn a mixed-effects tree into a key
#'
#' Each split becomes a couplet and each terminal node a result, labelled
#' with its stratum level and size. Splits on 0/1 variables read as
#' "Carries 16311" / "Does not carry 16311". The leads carry machine-readable
#' tests on the split variables, so [classify()] can place new samples given
#' their [haplotypeMatrix()], and [exportWizard()] can draw the tree.
#' Splits on factor columns become text-only couplets ("tissue is liver or
#' lung"), which a person can follow but [classify()] cannot; the function
#' warns when the key has any.
#'
#' @param fit A [mecit()] fit.
#' @param desc Title of the key.
#' @param digits Decimal places for stratum levels.
#' @return A [dimoose] key.
#' @export
keyFromMecit <- function(fit, desc = NULL, digits = 2) {
  tree <- fit$tree
  if (length(splitVariables(fit)) == 0) stop("This tree has no splits to turn into a key", call. = FALSE)
  data <- tree$data
  strata <- fit$strata
  leafLabel <- function(id) {
    s <- strata[strata$node == id, ]
    sprintf("Stratum %d: %s (n = %d)", id, formatC(s$mean, format = "f", digits = digits), s$n)
  }
  rows <- list(); counter <- 0L; used <- character(); factorSplits <- FALSE
  walk <- function(nd) {
    if (partykit::is.terminal(nd)) return(list(leaf = leafLabel(partykit::id_node(nd))))
    counter <<- counter + 1L
    id <- as.character(counter)
    sp <- partykit::split_node(nd)
    var <- names(data)[partykit::varid_split(sp)]
    orig <- fit$names[[var]]
    kids <- partykit::kids_node(nd)
    x <- data[[var]]
    if (is.numeric(x)) {
      b <- partykit::breaks_split(sp)
      idx <- partykit::index_split(sp)
      if (is.null(idx)) idx <- 1:2
      right <- partykit::right_split(sp)
      thr <- if (isFALSE(right)) b - 1e-9 else b
      binary <- all(x %in% c(0, 1))
      order <- c(idx[2], idx[1]) # high side first
      text <- if (binary) c(paste("Carries", orig), paste("Does not carry", orig)) else
        c(sprintf("%s > %s", orig, format(b)), sprintf("%s <= %s", orig, format(b)))
      feature <- paste0("var:", orig); test <- c(">", "<="); threshold <- thr
      used <<- union(used, orig)
    } else {
      idx <- partykit::index_split(sp)
      lev <- levels(x)
      # ordered factors split at a break on the level index
      if (is.null(idx)) idx <- ifelse(seq_along(lev) <= partykit::breaks_split(sp), 1L, 2L)
      order <- 1:2
      factorSplits <<- TRUE
      text <- vapply(1:2, function(k) sprintf("%s is %s", orig, paste(lev[!is.na(idx) & idx == k], collapse = " or ")), "")
      feature <- ""; test <- ""; threshold <- NA_real_
    }
    built <- lapply(kids[order], walk)
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"), Character = text,
      Next = vapply(built, function(k) if (is.null(k$leaf)) k$id else "-", ""),
      Taxon = vapply(built, function(k) if (is.null(k$leaf)) "" else k$leaf, ""),
      Question = orig, Feature = feature, Test = test, Threshold = threshold,
      stringsAsFactors = FALSE)
    list(id = id)
  }
  walk(partykit::node_party(tree))
  if (factorSplits) warning("The tree splits on factor variables; those couplets are text-only and classify() cannot follow them", call. = FALSE)
  leads <- do.call(rbind, rows[order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  features <- if (length(used)) featureTable(id = paste0("var:", used), kind = "external", label = used) else NULL
  if (is.null(desc)) desc <- paste("Mixed-effects tree:", fit$method)
  meta <- data.frame(key = c("node_label", "citation"),
    value = c("Split", if (fit$method == "mob") "Fokkema et al. (2018), glmertree" else "Fu & Simonoff (2015), RE-EM with conditional inference trees"),
    stringsAsFactors = FALSE)
  keyFromLeads(leads, desc, meta, features = features)
}
