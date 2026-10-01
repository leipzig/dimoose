#' Invent pronounceable names
#'
#' Random words made of consonant onsets, vowels and codas, for naming
#' visual terms that have no English name (as fordera does).
#'
#' @param n Number of names.
#' @param seed Random seed, so the same call gives the same names.
#' @return A character vector of `n` distinct lower-case words.
#' @examples
#' inventNames(5)
#' @export
inventNames <- function(n, seed = 1) {
  onsets <- c("b", "d", "f", "g", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z",
              "bl", "br", "dr", "fl", "fr", "gl", "gr", "kl", "kr", "pl", "pr", "sk", "sl", "sm",
              "sn", "sp", "st", "str", "tr", "th", "sh", "ch", "zh")
  vowels <- c("a", "e", "i", "o", "u", "ae", "ai", "au", "ei", "eu", "ia", "ie", "oa", "oi", "ou", "ua", "y")
  codas <- c("", "", "l", "m", "n", "r", "s", "t", "k", "lm", "ld", "nd", "nt", "rk", "rl", "rn",
             "sk", "st", "ss", "ff", "ps", "x", "ng")
  set.seed(seed)
  out <- character()
  while (length(out) < n) {
    syl <- sample(2:3, 1)
    w <- paste0(vapply(seq_len(syl), function(i) {
      paste0(sample(onsets, 1), sample(vowels, 1), sample(codas, 1))
    }, character(1)), collapse = "")
    if (nchar(w) <= 14 && !w %in% out) out <- c(out, w)
  }
  out
}

#' Discover visual terms by clustering patch embeddings
#'
#' Runs k-means on every patch embedding of every image and keeps the unit
#' length centroids as the definitions of `k` invented terms. An image "has"
#' a term when one of its patches is close to that centroid (see
#' [termScores()]).
#'
#' @param patches A numeric array `images x patches x dimensions` (unit length
#'   rows), e.g. `embedImages(...)$patches`; `dimnames(patches)[[1]]` are the
#'   image ids.
#' @param k Number of terms.
#' @param seed Seed for k-means and for [inventNames()].
#' @param nstart Random starts for [stats::kmeans()].
#' @param exemplars Number of best-matching patches to record per term.
#' @return An object of class `mooseTerms`: `terms` (data frame `id`, `name`),
#'   `centroids` (`k x d`, rows named by term) and `exemplars` (data frame
#'   `term`, `image`, `patch`, `score`).
#' @examples
#' set.seed(1)
#' patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
#' norms <- sqrt(apply(patches^2, c(1, 2), sum))
#' patches <- sweep(patches, c(1, 2), norms, "/")
#' dimnames(patches) <- list(letters[1:5], NULL, NULL)
#' discoverTerms(patches, k = 3)$terms
#' @export
discoverTerms <- function(patches, k = 40, seed = 1, nstart = 10, exemplars = 4) {
  stopifnot(is.array(patches), length(dim(patches)) == 3)
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  ids <- dimnames(patches)[[1]]
  if (is.null(ids)) ids <- as.character(seq_len(n))
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d) # row = patch within image, image-major
  set.seed(seed)
  km <- stats::kmeans(X, centers = k, nstart = nstart, iter.max = 100)
  centroids <- km$centers / sqrt(rowSums(km$centers^2))
  nm <- inventNames(k, seed = seed)
  rownames(centroids) <- nm
  sims <- X %*% t(centroids)
  ex <- do.call(rbind, lapply(seq_len(k), function(j) {
    top <- order(sims[, j], decreasing = TRUE)[seq_len(min(exemplars, nrow(sims)))]
    data.frame(term = nm[j], image = ids[(top - 1) %/% p + 1], patch = as.integer((top - 1) %% p + 1),
               score = sims[top, j], stringsAsFactors = FALSE)
  }))
  rownames(ex) <- NULL
  structure(list(terms = data.frame(id = seq_len(k), name = nm, stringsAsFactors = FALSE),
                 centroids = centroids, exemplars = ex), class = "mooseTerms")
}

#' Score images against terms
#'
#' @param patches As in [discoverTerms()].
#' @param centroids A `k x d` matrix of term centroids (unit rows), e.g.
#'   `discoverTerms(...)$centroids`.
#' @return An `images x terms` matrix: for each term, the highest cosine
#'   similarity between the centroid and any patch of the image.
#' @export
termScores <- function(patches, centroids) {
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d)
  sims <- X %*% t(centroids)
  out <- t(vapply(seq_len(n), function(i) apply(sims[(i - 1) * p + seq_len(p), , drop = FALSE], 2, max), numeric(nrow(centroids))))
  if (nrow(centroids) == 1) out <- matrix(out, n, 1)
  dimnames(out) <- list(dimnames(patches)[[1]], rownames(centroids))
  out
}

#' Build a key from term scores
#'
#' Each step asks whether the image has one invented term. `method =
#' "balanced"` is fordera's algorithm: a term is present when its score is
#' above the `quantile` of that term's scores over all images; a label has a
#' term if any of its images does; each split uses the unused term that
#' divides the remaining labels most evenly (ties to the earlier term).
#' `method = "rpart"` grows a classification tree on the scores instead, with
#' the split points as thresholds.
#'
#' @param scores `images x terms` matrix from [termScores()].
#' @param images [imageSet()] data frame with one row per row of `scores`.
#' @param terms The `mooseTerms` object the scores were computed with.
#' @param method `"balanced"` or `"rpart"`.
#' @param quantile Presence threshold quantile for `"balanced"`.
#' @param desc,meta Title and metadata of the key.
#' @return A [moose] key whose leads carry `Feature`, `Test`, `Threshold` and
#'   `Question`, and whose `features` table holds the centroids.
#' @export
keyFromTerms <- function(scores, images, terms, method = c("balanced", "rpart"), quantile = 0.6,
                         desc = "Key generated from visual terms", meta = NULL) {
  method <- match.arg(method)
  stopifnot(nrow(scores) == nrow(images), inherits(terms, "mooseTerms"))
  nm <- colnames(scores)
  labels <- images$label
  cent <- terms$centroids
  if (is.null(rownames(cent))) rownames(cent) <- terms$terms$name
  features <- featureTable(
    id = paste0("term:", nm), kind = "centroid_patch_max", label = nm,
    embedding = lapply(seq_along(nm), function(j) unname(cent[nm[j], ])),
    exemplars = lapply(nm, function(x) {
      ex <- terms$exemplars
      if (is.null(ex)) NULL else { r <- ex[ex$term == x, c("image", "patch", "score")]; rownames(r) <- NULL; r }
    })
  )
  if (method == "rpart") {
    data <- data.frame(label = factor(labels), as.data.frame(scores), check.names = FALSE)
    fit <- rpart::rpart(stats::reformulate(paste0("`", nm, "`"), "label"), data = data, method = "class", y = TRUE,
      control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0, xval = 0, maxcompete = 0))
    key <- keyFromRpart(fit, desc, meta)
    leads <- key$leads
    # keyFromRpart's Character is labels(fit) with "=" turned into ": ", so an
    # rpart numeric split "t1>=0.5"/"t1< 0.5" arrives as "t1>: 0.5"/"t1< 0.5".
    m <- regmatches(leads$Character, regexec("^(.+?)(>:|<) ?([-0-9.e]+)$", leads$Character))
    feat <- vapply(m, function(x) if (length(x) == 4) x[2] else "", "")
    op <- vapply(m, function(x) if (length(x) == 4) x[3] else "", "")
    thr <- as.numeric(vapply(m, function(x) if (length(x) == 4) x[4] else NA_character_, NA_character_))
    leads$Feature <- ifelse(nzchar(feat), paste0("term:", feat), "")
    leads$Test <- ifelse(op == ">:", ">", ifelse(op == "<", "<=", ""))
    leads$Threshold <- thr - 1e-9  # ">=t" is "> t-eps"; "< t" is "<= t-eps"
    leads$Question <- ifelse(nzchar(leads$Feature), sub("^term:", "", leads$Feature), "")
    leads$Character <- ifelse(leads$Test == ">", paste("Has", leads$Question),
      ifelse(leads$Test == "<=", paste("Lacks", leads$Question), leads$Character))
    return(keyFromLeads(leads, desc, meta, features = features))
  }
  thresholds <- apply(scores, 2, stats::quantile, probs = quantile, type = 7, names = FALSE)
  present <- sweep(scores, 2, thresholds, ">")
  ulab <- sort(unique(labels))
  labPresent <- t(vapply(ulab, function(l) apply(present[labels == l, , drop = FALSE], 2, any), logical(ncol(scores))))
  if (ncol(scores) == 1) labPresent <- matrix(labPresent, length(ulab), 1)
  rows <- list(); counter <- 0L
  build <- function(idx, used, depth) {
    if (length(idx) == 1 || depth > 20) return(list(leaf = paste(ulab[idx], collapse = " / ")))
    best <- NULL; bestScore <- -1
    for (j in seq_along(nm)) {
      if (j %in% used) next
      yes <- idx[labPresent[idx, j]]; no <- idx[!labPresent[idx, j]]
      if (!length(yes) || !length(no)) next
      bal <- min(length(yes), length(no)) / max(length(yes), length(no))
      if (bal > bestScore) { bestScore <- bal; best <- list(j = j, yes = yes, no = no) }
    }
    if (is.null(best)) return(list(leaf = paste(ulab[idx], collapse = " / ")))
    counter <<- counter + 1L
    id <- as.character(counter)
    kids <- list(build(best$yes, c(used, best$j), depth + 1), build(best$no, c(used, best$j), depth + 1))
    x <- nm[best$j]
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"), Character = c(paste("Has", x), paste("Lacks", x)),
      Next = vapply(kids, function(k) if (is.null(k$leaf)) k$id else "-", ""),
      Taxon = vapply(kids, function(k) if (is.null(k$leaf)) "" else k$leaf, ""),
      Question = x, Feature = paste0("term:", x), Test = c(">", "<="), Threshold = thresholds[[best$j]],
      stringsAsFactors = FALSE)
    list(id = id)
  }
  top <- build(seq_along(ulab), integer(), 0)
  if (!is.null(top$leaf)) stop("No term separates the labels", call. = FALSE)
  leads <- do.call(rbind, rows[order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  if (is.null(meta)) meta <- data.frame(key = "node_label", value = "Term", stringsAsFactors = FALSE)
  keyFromLeads(leads, desc, meta, features = features)
}
