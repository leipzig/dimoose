#' Generate a tree from a feature matrix
#'
#' Fits a classification tree (or tree ensemble) with the taxon column as the
#' response and every other column as a feature.
#'
#' The rpart defaults are set for identification data, which usually has one
#' row per taxon: `rpart.control(minsplit = 2, minbucket = 1, cp = 0)`, so the
#' tree keeps splitting until every taxon is separated. (rpart's own defaults,
#' `minsplit = 20, minbucket = 7, cp = 0.01`, make no split at all on such a
#' matrix.) With many specimens per taxon pass your own `control` in `params`
#' to get a smaller tree, or just the settings to change, e.g.
#' `params = list(cp = 0.01)` or `params = list(maxdepth = 3)`. [keyFromRpart()] turns the tree into a key;
#' [keyFromMatrix()] goes from matrix to key in one step and handles taxa that
#' are variable for a character.
#'
#' @param data A data frame containing the feature matrix.
#' @param target_col Name of the target/response column.
#' @param method `"rpart"`, `"randomForest"` (requires the 'randomForest'
#'   package), or `"gbm"` (requires the 'gbm' package; `"multinomial"`
#'   distribution unless the response is numeric 0/1, which uses
#'   `"bernoulli"`).
#' @param params Optional list of arguments passed to the fitting function,
#'   overriding the defaults.
#' @return A fitted `rpart`, `randomForest` or `gbm` object. For the last two
#'   the `call` is the call to `generateTree()`.
#' @examples
#' features <- data.frame(
#'   family = factor(c("A", "B", "C")),
#'   fin = factor(c("x", "y", "y")),
#'   head = factor(c("p", "p", "q"))
#' )
#' fit <- generateTree(features, "family")
#' fit
#' keyFromRpart(fit)$leads
#' @export
generateTree <- function(data, target_col, method = c("rpart", "randomForest", "gbm"),
                         params = list()) {
  method <- match.arg(method)
  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }
  if (!is.character(target_col) || length(target_col) != 1 || !target_col %in% names(data)) {
    stop("target_col must be a column name in data", call. = FALSE)
  }
  if (method != "rpart" && !requireNamespace(method, quietly = TRUE)) {
    stop("method = \"", method, "\" requires the '", method, "' package", call. = FALSE)
  }

  # Backticks keep non-syntactic names such as "Growth at 3% NaCl" intact
  feature_cols <- setdiff(names(data), target_col)
  if (length(feature_cols) == 0) {
    stop("data has no feature columns besides target_col", call. = FALSE)
  }
  formula <- stats::reformulate(
    termlabels = paste0("`", feature_cols, "`"),
    response = as.name(target_col)
  )

  if (nrow(data) == 0) stop("data has no rows", call. = FALSE)
  if (method == "rpart" && identical(if (is.null(params[["method"]])) "class" else params[["method"]], "class") &&
      length(unique(stats::na.omit(data[[target_col]]))) < 2) {
    stop("target_col must hold at least two different taxa", call. = FALSE)
  }

  fit <- switch(method,
    rpart = {
      defaults <- list(
        method = "class",
        control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0)
      )
      args <- utils::modifyList(defaults, params)
      # rpart lets `control` override settings given on their own (cp,
      # minsplit, maxdepth ...), and here there is always a `control`, so
      # they are put into it
      single <- setdiff(intersect(names(args), names(formals(rpart::rpart.control))), "...")
      args$control[single] <- args[single]
      args[single] <- NULL
      do.call(rpart::rpart, c(list(formula = formula, data = data), args))
    },
    randomForest = {
      defaults <- list(ntree = 500, mtry = floor(sqrt(length(feature_cols))))
      do.call(randomForest::randomForest, c(list(formula = formula, data = data), utils::modifyList(defaults, params)))
    },
    gbm = {
      # gbm's "bernoulli" needs a 0/1 response; taxa are a factor, which gbm
      # handles with "multinomial"
      y <- data[[target_col]]
      binary <- is.numeric(y) && all(y %in% c(0, 1))
      if (!binary && !is.factor(y)) data[[target_col]] <- factor(y)
      defaults <- list(
        distribution = if (binary) "bernoulli" else "multinomial", n.trees = 100, interaction.depth = 3,
        shrinkage = 0.1, cv.folds = 5
      )
      do.call(gbm::gbm, c(list(formula = formula, data = data), utils::modifyList(defaults, params)))
    }
  )
  # The fit was made with do.call(), which records the whole data frame (and
  # for gbm the fitting function) as its call, and printing a random forest
  # or gbm prints that. Record the call to generateTree() instead. An rpart
  # fit does not print its call and is returned as rpart made it.
  if (method != "rpart") fit$call <- match.call()
  fit
}
