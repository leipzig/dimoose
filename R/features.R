#' A table of machine-computable features
#'
#' Keys built from images (see [keyFromTerms()] and [keyFromClusters()]) carry
#' a `features` table that says how a machine computes the score each lead
#' tests. [classify()] walks a key over a matrix of such scores.
#'
#' @param id Feature ids, e.g. `"sniglet:dulmzil"` or `"text:round_headlights"`.
#' @param kind `"centroid_patch_max"` (highest cosine similarity between any
#'   image patch embedding and `embedding`), `"clip_text_pair"` (cosine with
#'   `prompt` minus cosine with `negative_prompt`) or `"external"` (computed
#'   by the user).
#' @param label Name shown to people; defaults to `id`.
#' @param prompt,negative_prompt Texts for `clip_text_pair` features.
#' @param region Crop as `"y0,y1,x0,x1"` fractions, or `NA` for the whole image.
#' @param definition Optional sentence saying what the feature is, shown in
#'   the wizard's glossary (see [renameSniglets()]).
#' @param embedding List of numeric vectors (one per feature), or `NULL`.
#' @param exemplars List of data frames with columns `image`, `patch`,
#'   `score` and optionally `png` (base64) showing what the feature means.
#' @return A data frame with the columns above; `embedding` and `exemplars`
#'   are list columns.
#' @examples
#' featureTable("sniglet:x", "centroid_patch_max", embedding = list(c(1, 0, 0)))
#' @export
featureTable <- function(id, kind, label = id, prompt = NA, negative_prompt = NA, region = NA,
                         embedding = NULL, exemplars = NULL, definition = NA) {
  n <- length(id)
  if (is.null(embedding)) embedding <- vector("list", n)
  if (is.null(exemplars)) exemplars <- vector("list", n)
  stopifnot(length(kind) == n || length(kind) == 1, length(embedding) == n, length(exemplars) == n)
  out <- data.frame(
    id = as.character(id), kind = as.character(rep_len(kind, n)), label = as.character(rep_len(label, n)),
    prompt = as.character(rep_len(prompt, n)), negative_prompt = as.character(rep_len(negative_prompt, n)),
    region = as.character(rep_len(region, n)), definition = as.character(rep_len(definition, n)),
    stringsAsFactors = FALSE
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
    if (length(i) == 2 && leads$Feature[i[1]] != leads$Feature[i[2]]) {
      problems <- c(problems, sprintf("Couplet %s tests two different features (%s, %s); both leads of a couplet must test the same feature",
        cp, leads$Feature[i[1]], leads$Feature[i[2]]))
    }
  }
  problems
}

#' Follow a key by machine
#'
#' Walks each row of `scores` through `key`: at every couplet the lead whose
#' test (`Feature`, `Test`, `Threshold`) passes is taken. When no lead or
#' more than one passes (for instance on a missing score), the result is `NA`.
#'
#' @param key A [dimoose] key with `Feature`, `Test` and `Threshold` lead
#'   columns, e.g. from [keyFromTerms()].
#' @param scores A numeric matrix, one row per object, with a column for every
#'   feature id the key tests (see [featureScores()] and [scoreImages()]).
#' @return A data frame with `id` (row names of `scores`), `result` and
#'   `path` (the leads taken, e.g. `"1a 3b"`).
#' @export
classify <- function(key, scores) {
  leads <- normalizeLeads(key$leads)
  needed <- unique(leads$Feature[nzchar(leads$Feature)])
  if (length(needed) == 0) stop("This key has no machine-readable tests", call. = FALSE)
  if (is.null(dim(scores))) scores <- matrix(scores, 1, dimnames = list(NULL, names(scores)))
  # Score columns may be keyed by feature id (featureScores/scoreImages), by a
  # sniglet's coined word (snigletScores output) or by the feature's label;
  # map them to ids so any of these works.
  f <- key$features
  if (!is.null(f)) {
    alias <- c(stats::setNames(f$id, sub("^[^:]*:", "", f$id)), stats::setNames(f$id, f$label))
    alias <- alias[!duplicated(names(alias))]
    hit <- colnames(scores) %in% names(alias) & !colnames(scores) %in% f$id
    colnames(scores)[hit] <- alias[colnames(scores)[hit]]
  }
  missing <- setdiff(needed, colnames(scores))
  if (length(missing)) stop("`scores` is missing scores for: ", paste(missing, collapse = ", "), call. = FALSE)
  root <- checkLeads(leads)$root
  byCouplet <- split(seq_len(nrow(leads)), leads$Statement)
  ids <- rownames(scores); if (is.null(ids)) ids <- as.character(seq_len(nrow(scores)))
  walk <- function(s) {
    cp <- root; path <- character(); seen <- character()
    repeat {
      if (cp %in% seen) return(list(NA_character_, path))
      seen <- c(seen, cp)
      i <- byCouplet[[cp]]
      v <- s[leads$Feature[i]]
      ok <- ifelse(leads$Test[i] == ">", v > leads$Threshold[i], v <= leads$Threshold[i])
      ok[is.na(ok)] <- FALSE
      if (sum(ok) != 1) return(list(NA_character_, path))
      take <- i[ok]
      path <- c(path, paste0(leads$Statement[take], leads$Choice[take]))
      if (leads$Next[take] == "-") return(list(leads$Taxon[take], path))
      cp <- leads$Next[take]
      if (!cp %in% names(byCouplet)) return(list(NA_character_, path))
    }
  }
  res <- lapply(seq_len(nrow(scores)), function(r) walk(stats::setNames(scores[r, ], colnames(scores))))
  data.frame(id = ids, result = vapply(res, `[[`, "", 1),
             path = vapply(res, function(x) paste(x[[2]], collapse = " "), ""), stringsAsFactors = FALSE)
}

#' Accuracy of a key followed by machine
#'
#' @inheritParams classify
#' @param labels True label of each row of `scores`.
#' @param groups Optional named vector mapping labels to coarser groups (e.g.
#'   model years to generations) for a second accuracy figure.
#' @return A list: `results` (one row per object with `actual`, `predicted`,
#'   `correct`, `groupCorrect`), `accuracy`, `groupAccuracy` and `confusion`.
#' @export
evaluateKey <- function(key, scores, labels, groups = NULL) {
  r <- classify(key, scores)
  r$actual <- as.character(labels)
  r$predicted <- r$result; r$result <- NULL
  r$correct <- !is.na(r$predicted) & r$predicted == r$actual
  r$groupCorrect <- if (is.null(groups)) NA else !is.na(r$predicted) & groups[r$predicted] == groups[r$actual]
  r$groupCorrect[is.na(r$groupCorrect)] <- FALSE
  list(results = r[, c("id", "actual", "predicted", "correct", "groupCorrect", "path")],
       accuracy = mean(r$correct),
       groupAccuracy = if (is.null(groups)) NA_real_ else mean(r$groupCorrect),
       confusion = table(actual = r$actual, predicted = ifelse(is.na(r$predicted), "<none>", r$predicted)))
}

#' Leave-one-out evaluation of a key builder
#'
#' @param images [imageSet()] data frame of all images.
#' @param build Function of the training row indices returning a key.
#' @param score Function of (key, test row index) returning a one-row scores
#'   matrix for that image.
#' @param groups As in [evaluateKey()].
#' @return As [evaluateKey()].
#' @export
looKey <- function(images, build, score, groups = NULL) {
  n <- nrow(images)
  rows <- lapply(seq_len(n), function(i) {
    key <- build(setdiff(seq_len(n), i))
    r <- classify(key, score(key, i))
    data.frame(id = images$id[i], actual = images$label[i], predicted = r$result[1], path = r$path[1], stringsAsFactors = FALSE)
  })
  r <- do.call(rbind, rows)
  r$correct <- !is.na(r$predicted) & r$predicted == r$actual
  r$groupCorrect <- if (is.null(groups)) NA else !is.na(r$predicted) & groups[r$predicted] == groups[r$actual]
  r$groupCorrect[is.na(r$groupCorrect)] <- FALSE
  list(results = r[, c("id", "actual", "predicted", "correct", "groupCorrect", "path")],
       accuracy = mean(r$correct),
       groupAccuracy = if (is.null(groups)) NA_real_ else mean(r$groupCorrect),
       confusion = table(actual = r$actual, predicted = ifelse(is.na(r$predicted), "<none>", r$predicted)))
}

#' Compute a key's feature scores from embeddings
#'
#' Model-free: give it the embeddings and it applies each feature's rule.
#' `centroid_patch_max` features need `patches`; `clip_text_pair` features
#' need `image` and `textEmb` (rows named by prompt). For `external`
#' features supply the scores yourself.
#'
#' @param key A [dimoose] key with a `features` table.
#' @param image `objects x d` matrix of image embeddings (unit rows).
#' @param patches `objects x patches x d` array of patch embeddings.
#' @param textEmb `prompts x d` matrix of text embeddings whose row names are
#'   the prompt texts, e.g. from [embedTexts()].
#' @return An `objects x features` matrix with feature ids as column names.
#' @seealso [scoreImages()] for images-to-scores in one call.
#' @export
featureScores <- function(key, image = NULL, patches = NULL, textEmb = NULL) {
  f <- key$features
  if (is.null(f)) stop("This key has no features table", call. = FALSE)
  n <- if (!is.null(image)) nrow(image) else if (!is.null(patches)) dim(patches)[1] else stop("Give `image` or `patches`", call. = FALSE)
  ids <- if (!is.null(image)) rownames(image) else dimnames(patches)[[1]]
  out <- matrix(NA_real_, n, nrow(f), dimnames = list(ids, f$id))
  for (j in seq_len(nrow(f))) {
    kind <- f$kind[j]
    if (kind == "centroid_patch_max") {
      if (is.null(patches)) stop("Feature ", f$id[j], " needs `patches`", call. = FALSE)
      out[, j] <- snigletScores(patches, matrix(f$embedding[[j]], 1))[, 1]
    } else if (kind == "clip_text_pair") {
      if (is.null(image) || is.null(textEmb)) stop("Feature ", f$id[j], " needs `image` and `textEmb`", call. = FALSE)
      for (p in c(f$prompt[j], f$negative_prompt[j])) if (!p %in% rownames(textEmb)) stop("`textEmb` has no row for the prompt: ", p, call. = FALSE)
      out[, j] <- image %*% textEmb[f$prompt[j], ] - image %*% textEmb[f$negative_prompt[j], ]
    } else if (kind != "external") {
      stop("Unknown feature kind: ", kind, call. = FALSE)
    }
  }
  out
}
