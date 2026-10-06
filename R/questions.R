#' Prompts for a vocabulary of visual features
#'
#' @param vocabulary Data frame with `feature` and `opposite` columns (and an
#'   optional `region`, `"y0,y1,x0,x1"` fractions).
#' @param template Text with `{x}` where the feature goes, e.g.
#'   `"a pickup truck with {x}"`.
#' @return A character vector: the feature prompt then the opposite prompt
#'   for each row, in order. Embed these with [embedTexts()] and pass the
#'   result to [keyFromClusters()].
#' @examples
#' v <- data.frame(feature = c("round lights", "a flat hood"),
#'                 opposite = c("square lights", "a curved hood"))
#' vocabularyPrompts(v, "a truck with {x}")
#' @export
vocabularyPrompts <- function(vocabulary, template = "{x}") {
  stopifnot(all(c("feature", "opposite") %in% names(vocabulary)))
  fill <- function(x) sub("{x}", x, template, fixed = TRUE)
  c(rbind(vapply(vocabulary$feature, fill, ""), vapply(vocabulary$opposite, fill, "")))
}

slug <- function(x) gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(x)))

#' Build a key by clustering classes and describing each split
#'
#' Classes are clustered on the mean embedding of their images (Ward's
#' method), giving a binary tree. Each split is then described by the
#' vocabulary pair that best separates its two sides: the pair maximising
#' |(L.yes - L.no) - (R.yes - R.no)| over the side means, not used above
#' that split. The "Has feature" lead goes to the side the feature scores
#' higher on. Machine answers use the same two prompts.
#'
#' @param image `images x d` matrix of unit-length image embeddings.
#' @param images [imageSet()] data frame, one row per row of `image`.
#' @param vocabulary As in [vocabularyPrompts()].
#' @param textEmb Text embeddings of `vocabularyPrompts(vocabulary, template)`,
#'   rows named by prompt (as [embedTexts()] returns them).
#' @param template Must match the one used to make `textEmb`.
#' @param order Optional function of a character vector of labels returning
#'   a number; at each split the child with the smaller value comes first.
#' @param maxPerSide Most images per side used for the side means.
#' @param calibrate `"none"` (threshold 0) or `"midpoint"` (halfway between
#'   the two sides' mean scores).
#' @param desc,meta Title and metadata.
#' @return A [dimoose] key with `clip_text_pair` features.
#' @export
keyFromClusters <- function(image, images, vocabulary, textEmb, template = "{x}", order = NULL,
                            maxPerSide = 10, calibrate = c("none", "midpoint"),
                            desc = "Key generated from image clusters", meta = NULL) {
  calibrate <- match.arg(calibrate)
  stopifnot(nrow(image) == nrow(images))
  if (anyDuplicated(slug(vocabulary$feature))) stop("Vocabulary features must have distinct names", call. = FALSE)
  prompts <- vocabularyPrompts(vocabulary, template)
  missing <- setdiff(prompts, rownames(textEmb))
  if (length(missing)) stop("`textEmb` lacks rows for ", length(missing), " prompt(s), e.g. ", missing[1], call. = FALSE)
  yesP <- prompts[c(TRUE, FALSE)]; noP <- prompts[c(FALSE, TRUE)]
  labels <- images$label
  ulab <- sort(unique(labels))
  if (length(ulab) < 2) stop("Need at least two labels", call. = FALSE)
  means <- t(vapply(ulab, function(l) colMeans(image[labels == l, , drop = FALSE]), numeric(ncol(image))))
  means <- means / sqrt(rowSums(means^2))
  hc <- stats::hclust(stats::dist(means), method = "ward.D2")

  leavesOf <- function(nd) if (!is.null(nd$leaf)) nd$leaf else unlist(lapply(nd$kids, leavesOf))
  node <- function(i) if (i < 0) list(leaf = -i) else {
    kids <- list(node(hc$merge[i, 1]), node(hc$merge[i, 2]))
    if (!is.null(order)) {
      key <- vapply(kids, function(k) order(ulab[leavesOf(k)]), numeric(1))
      kids <- kids[base::order(key)]
    }
    list(kids = kids)
  }

  sideMean <- function(labIdx) {
    rows <- which(labels %in% ulab[labIdx])[seq_len(min(maxPerSide, sum(labels %in% ulab[labIdx])))]
    colMeans(image[rows, , drop = FALSE])
  }
  rows <- list(); counter <- 0L; featUsed <- integer()
  build <- function(nd, used) {
    if (!is.null(nd$leaf)) return(list(leaf = ulab[nd$leaf]))
    L <- leavesOf(nd$kids[[1]]); R <- leavesOf(nd$kids[[2]])
    lm <- sideMean(L); rm <- sideMean(R)
    sL <- as.numeric(lm %*% t(textEmb[yesP, , drop = FALSE])) - as.numeric(lm %*% t(textEmb[noP, , drop = FALSE]))
    sR <- as.numeric(rm %*% t(textEmb[yesP, , drop = FALSE])) - as.numeric(rm %*% t(textEmb[noP, , drop = FALSE]))
    forward <- sL - sR
    cand <- setdiff(seq_along(yesP), used)
    if (!length(cand)) cand <- seq_along(yesP)
    j <- cand[which.max(abs(forward[cand]))]
    hasSide <- if (forward[j] >= 0) 1 else 2
    featUsed <<- union(featUsed, j)
    counter <<- counter + 1L
    id <- as.character(counter)
    kidsOrdered <- if (hasSide == 1) nd$kids else rev(nd$kids)
    built <- lapply(kidsOrdered, build, used = c(used, j))
    thr <- if (calibrate == "midpoint") (sL[j] + sR[j]) / 2 else 0
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"),
      Character = c(paste("Has", vocabulary$feature[j]), paste("Has", vocabulary$opposite[j])),
      Next = vapply(built, function(b) if (is.null(b$leaf)) b$id else "-", ""),
      Taxon = vapply(built, function(b) if (is.null(b$leaf)) "" else b$leaf, ""),
      Question = paste0("Does it have ", vocabulary$feature[j], "?"),
      Feature = paste0("text:", slug(vocabulary$feature[j])), Test = c(">", "<="), Threshold = thr,
      stringsAsFactors = FALSE)
    list(id = id)
  }
  build(node(nrow(hc$merge)), integer())
  leads <- do.call(rbind, rows[base::order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  used <- sort(featUsed)
  features <- featureTable(
    id = paste0("text:", slug(vocabulary$feature[used])), kind = "clip_text_pair",
    label = vocabulary$feature[used], prompt = yesP[used], negative_prompt = noP[used],
    region = if (is.null(vocabulary$region)) NA else vocabulary$region[used]
  )
  if (is.null(meta)) meta <- data.frame(key = "node_label", value = "Question", stringsAsFactors = FALSE)
  keyFromLeads(leads, desc, meta, features = features)
}
