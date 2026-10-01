#' Generate a tree from a feature matrix
#'
#' Fits a classification tree (or tree ensemble) with the taxon column as the
#' response and every other column as a feature.
#'
#' @param data A data frame containing the feature matrix.
#' @param target_col Name of the target/response column.
#' @param method `"rpart"`, `"randomForest"` (requires the 'randomForest'
#'   package), or `"gbm"` (requires the 'gbm' package).
#' @param params Optional list of arguments passed to the fitting function,
#'   overriding the defaults.
#' @return A fitted `rpart`, `randomForest` or `gbm` object.
#' @examples
#' features <- data.frame(
#'   family = factor(c("A", "B", "C", "A", "B", "C")),
#'   fin = factor(c("x", "y", "y", "x", "y", "y")),
#'   head = factor(c("p", "p", "q", "p", "p", "q"))
#' )
#' generateTree(features, "family",
#'   params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1))
#' )
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
  formula <- stats::reformulate(
    termlabels = paste0("`", feature_cols, "`"),
    response = as.name(target_col)
  )

  switch(method,
    rpart = {
      defaults <- list(
        method = "class",
        control = rpart::rpart.control(minsplit = 20, minbucket = 7, cp = 0.01)
      )
      do.call(rpart::rpart, c(list(formula = formula, data = data), utils::modifyList(defaults, params)))
    },
    randomForest = {
      defaults <- list(ntree = 500, mtry = floor(sqrt(length(feature_cols))))
      do.call(randomForest::randomForest, c(list(formula = formula, data = data), utils::modifyList(defaults, params)))
    },
    gbm = {
      defaults <- list(
        distribution = "bernoulli", n.trees = 100, interaction.depth = 3,
        shrinkage = 0.1, cv.folds = 5
      )
      do.call(gbm::gbm, c(list(formula = formula, data = data), utils::modifyList(defaults, params)))
    }
  )
}

# Placeholder: load the consensus matrix from Noguerola & Blanch (2008),
# "Identification of Vibrio spp. with a set of dichotomous keys",
# J Appl Microbiol, doi:10.1111/j.1365-2672.2008.03730.x
importVibrio <- function(consensus) {
  consensus
}
