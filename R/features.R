#' A table of machine-computable features
#'
#' Keys built from images (see [keyFromTerms()] and [keyFromClusters()]) carry
#' a `features` table that says how a machine computes the score each lead
#' tests. [classify()] walks a key over a matrix of such scores.
#'
#' @param id Feature ids, e.g. `"term:dulmzil"` or `"text:round_headlights"`.
#' @param kind `"centroid_patch_max"` (highest cosine similarity between any
#'   image patch embedding and `embedding`), `"clip_text_pair"` (cosine with
#'   `prompt` minus cosine with `negative_prompt`) or `"external"` (computed
#'   by the user).
#' @param label Name shown to people; defaults to `id`.
#' @param prompt,negative_prompt Texts for `clip_text_pair` features.
#' @param region Crop as `"y0,y1,x0,x1"` fractions, or `NA` for the whole image.
#' @param embedding List of numeric vectors (one per feature), or `NULL`.
#' @param exemplars List of data frames with columns `image`, `patch`,
#'   `score` and optionally `png` (base64) showing what the feature means.
#' @return A data frame with the columns above; `embedding` and `exemplars`
#'   are list columns.
#' @examples
#' featureTable("term:x", "centroid_patch_max", embedding = list(c(1, 0, 0)))
#' @export
featureTable <- function(id, kind, label = id, prompt = NA, negative_prompt = NA, region = NA,
                         embedding = NULL, exemplars = NULL) {
  n <- length(id)
  if (is.null(embedding)) embedding <- vector("list", n)
  if (is.null(exemplars)) exemplars <- vector("list", n)
  stopifnot(length(kind) == n || length(kind) == 1, length(embedding) == n, length(exemplars) == n)
  out <- data.frame(
    id = as.character(id), kind = as.character(rep_len(kind, n)), label = as.character(rep_len(label, n)),
    prompt = as.character(rep_len(prompt, n)), negative_prompt = as.character(rep_len(negative_prompt, n)),
    region = as.character(rep_len(region, n)), stringsAsFactors = FALSE
  )
  out$embedding <- embedding
  out$exemplars <- exemplars
  out
}

# Problems with the Feature/Test/Threshold columns of a lead table, given the
# key's features table (NULL when the key has none).
checkFeatures <- function(leads, features) {
  if (is.null(leads$Feature)) return(character())
  used <- which(!is.na(leads$Feature) & nzchar(leads$Feature))
  if (length(used) == 0) return(character())
  problems <- character()
  if (is.null(features)) {
    return("Leads test features but the key has no features table")
  }
  missing <- setdiff(unique(leads$Feature[used]), features$id)
  if (length(missing)) {
    problems <- c(problems, sprintf("Feature %s is tested by a lead but not in the features table", missing))
  }
  badTest <- used[!leads$Test[used] %in% c(">", "<=")]
  if (length(badTest)) {
    problems <- c(problems, sprintf("Lead %s%s has Test %s; use > or <=", leads$Statement[badTest],
      leads$Choice[badTest], leads$Test[badTest]))
  }
  thr <- suppressWarnings(as.numeric(leads$Threshold[used]))
  if (any(is.na(thr))) {
    problems <- c(problems, sprintf("Lead %s%s has no numeric Threshold",
      leads$Statement[used[is.na(thr)]], leads$Choice[used[is.na(thr)]]))
  }
  for (cp in unique(leads$Statement[used])) {
    i <- used[leads$Statement[used] == cp]
    if (length(i) == 2 && leads$Feature[i[1]] == leads$Feature[i[2]] && leads$Test[i[1]] == leads$Test[i[2]]) {
      problems <- c(problems, sprintf("Couplet %s tests %s with the same Test on both leads; they must be opposite", cp, leads$Feature[i[1]]))
    }
  }
  problems
}
