#' Invent pronounceable names
#'
#' Random words made of consonant onsets, vowels and codas. They name
#' sniglets: visual features that have no English name (as fordera does).
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

#' Discover sniglets by clustering patch embeddings
#'
#' A sniglet is a visual feature that a model found and that has no name of
#' its own, so moose coins one for it (`"dulmzil"`). This function runs
#' k-means on every patch embedding of every image and keeps the unit length
#' centroids as the definitions of `k` sniglets. An image "has" a sniglet
#' when one of its patches is close to that centroid (see [snigletScores()]).
#' Once you have looked at what a sniglet picks out, give it a real name with
#' [renameSniglets()].
#'
#' @param patches A numeric array `images x regions x dimensions` (unit length
#'   rows), e.g. `embedImages(...)$patches`; `dimnames(patches)[[1]]` are the
#'   image ids. Rows that are all zero are empty regions and are ignored.
#' @param k Number of sniglets.
#' @param seed Seed for k-means and for [inventNames()].
#' @param nstart Random starts for [stats::kmeans()].
#' @param exemplars Number of example regions to record per sniglet, each
#'   from a different image.
#' @return An object of class `mooseSniglets`: `sniglets` (data frame with
#'   `id`, `sniglet` (the coined word), `name` (what people see; the coined
#'   word until renamed) and `definition`), `centroids` (`k x d`, rows named
#'   by coined word), `exemplars` (data frame `sniglet`, `image`, `patch`,
#'   `score`: the best-matching region of each of the best-matching images),
#'   `best` (for every image, the region that matches each sniglet best) and
#'   `tiles` (the tiling of the regions, see [embedImages()]).
#' @examples
#' set.seed(1)
#' patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
#' norms <- sqrt(apply(patches^2, c(1, 2), sum))
#' patches <- sweep(patches, c(1, 2), norms, "/")
#' dimnames(patches) <- list(letters[1:5], NULL, NULL)
#' discoverSniglets(patches, k = 3)$sniglets
#' @export
discoverSniglets <- function(patches, k = 40, seed = 1, nstart = 10, exemplars = 4) {
  stopifnot(is.array(patches), length(dim(patches)) == 3)
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  ids <- dimnames(patches)[[1]]
  if (is.null(ids)) ids <- as.character(seq_len(n))
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d) # row = patch within image, image-major
  blank <- rowSums(X != 0) == 0                     # empty background tiles (see embedImages)
  if (sum(!blank) <= k) stop("`k` must be smaller than the number of regions with any detail (", sum(!blank), ")", call. = FALSE)
  set.seed(seed)
  km <- stats::kmeans(X[!blank, , drop = FALSE], centers = k, nstart = nstart, iter.max = 100)
  centroids <- km$centers / sqrt(rowSums(km$centers^2))
  nm <- inventNames(k, seed = seed)
  rownames(centroids) <- nm
  sims <- X %*% t(centroids)
  sims[blank, ] <- -Inf
  # for every image, the region that matches each sniglet best, and how well
  best <- matrix(0L, n, k, dimnames = list(ids, nm)); bestScore <- matrix(0, n, k, dimnames = list(ids, nm))
  for (i in seq_len(n)) {
    block <- sims[(i - 1) * p + seq_len(p), , drop = FALSE]
    best[i, ] <- max.col(t(block), ties.method = "first")
    bestScore[i, ] <- block[cbind(best[i, ], seq_len(k))]
  }
  bestScore[!is.finite(bestScore)] <- 0
  # exemplars: the best region of each of the best-matching images, so that
  # they show what different images have in common
  ex <- do.call(rbind, lapply(seq_len(k), function(j) {
    top <- order(bestScore[, j], decreasing = TRUE)[seq_len(min(exemplars, n))]
    data.frame(sniglet = nm[j], image = ids[top], patch = best[top, j], score = bestScore[top, j], stringsAsFactors = FALSE)
  }))
  rownames(ex) <- NULL
  tiles <- attr(patches, "tiles")
  empty <- attr(patches, "empty")
  structure(list(sniglets = data.frame(id = seq_len(k), sniglet = nm, name = nm, definition = NA_character_,
                                       stringsAsFactors = FALSE),
                 centroids = centroids, exemplars = ex, best = best,
                 tiles = if (is.null(tiles)) integer(0) else as.integer(tiles), empty = empty), class = "mooseSniglets")
}

#' @rdname discoverSniglets
#' @param ... Passed to [discoverSniglets()].
#' @details `discoverTerms()`, `termScores()` and `keyFromTerms()` are the
#'   earlier names of [discoverSniglets()], [snigletScores()] and
#'   [keyFromSniglets()], and still work.
#' @export
discoverTerms <- function(...) discoverSniglets(...)

#' Score images against sniglets
#'
#' @param patches As in [discoverSniglets()].
#' @param centroids A `k x d` matrix of sniglet centroids (unit rows), e.g.
#'   `discoverSniglets(...)$centroids`.
#' @return An `images x sniglets` matrix: for each sniglet, the highest cosine
#'   similarity between the centroid and any patch of the image. Columns are
#'   named by the coined words, whatever the sniglets have been renamed to.
#' @export
snigletScores <- function(patches, centroids) {
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d)
  sims <- X %*% t(centroids)
  out <- t(vapply(seq_len(n), function(i) apply(sims[(i - 1) * p + seq_len(p), , drop = FALSE], 2, max), numeric(nrow(centroids))))
  if (nrow(centroids) == 1) out <- matrix(out, n, 1)
  dimnames(out) <- list(dimnames(patches)[[1]], rownames(centroids))
  out
}

#' @rdname snigletScores
#' @export
termScores <- function(patches, centroids) snigletScores(patches, centroids)

#' Build a key from sniglet scores
#'
#' Each step asks whether the image has one sniglet. `method =
#' "balanced"` is fordera's algorithm: a sniglet is present when its score is
#' above the `quantile` of that sniglet's scores over all images; a label has
#' a sniglet if any of its images does; each split uses the unused sniglet
#' that divides the remaining labels most evenly (ties to the earlier one).
#' `method = "rpart"` suits several images per label. It first gives each
#' sniglet one threshold, the cut of its scores that best separates the
#' labels, and then grows a classification tree on has/lacks, so a sniglet
#' means the same thing wherever the key asks about it.
#'
#' @param scores `images x sniglets` matrix from [snigletScores()].
#' @param images [imageSet()] data frame with one row per row of `scores`.
#' @param sniglets The [discoverSniglets()] object the scores were computed
#'   with. Names given with [renameSniglets()] are used in the key.
#' @param method `"balanced"` or `"rpart"`.
#' @param quantile Presence threshold quantile for `"balanced"`.
#' @param desc,meta Title and metadata of the key.
#' @section Both leads describe something:
#' A lead that only says a specimen lacks something gives the reader nothing
#' to look for. Where it can, the "Lacks" lead therefore also names what its
#' images have instead: another sniglet that at least 90% of them have and at
#' most 10% of the other side do (`"Lacks gaithiark; has blienvaurk"`). The
#' machine still tests only the first sniglet. Every lead also records example
#' regions from the images that take it (`Examples`), which
#' [patchExemplars()] turns into crops: for a "Lacks" lead with no such second
#' sniglet, they are the regions that come closest to the missing one.
#'
#' @return A [moose] key whose leads carry `Feature`, `Test`, `Threshold` and
#'   `Question`, and whose `features` table holds the centroids. Feature ids
#'   are `"sniglet:<coined word>"` and never change; `label` is the name
#'   shown, which [renameSniglets()] changes.
#' @export
keyFromSniglets <- function(scores, images, sniglets, method = c("balanced", "rpart"), quantile = 0.6,
                            desc = "Key generated from sniglets", meta = NULL) {
  method <- match.arg(method)
  sniglets <- asSniglets(sniglets)
  stopifnot(nrow(scores) == nrow(images))
  nm <- colnames(scores)
  labels <- images$label
  cent <- sniglets$centroids
  if (is.null(rownames(cent))) rownames(cent) <- sniglets$sniglets$sniglet
  row <- match(nm, sniglets$sniglets$sniglet)
  if (anyNA(row)) stop("`scores` has columns that are not sniglets: ", paste(utils::head(nm[is.na(row)], 5), collapse = ", "), call. = FALSE)
  shown <- sniglets$sniglets$name[row]
  # One threshold per sniglet says which images "have" it, wherever in the key
  # it is asked about. "balanced" uses a quantile of the scores (fordera's
  # rule); "rpart" takes the single cut of the scores that best separates
  # the labels.
  thresholds <- apply(scores, 2, stats::quantile, probs = quantile, type = 7, names = FALSE)
  if (method == "rpart") {
    bucket <- max(1L, min(table(labels)))
    for (j in seq_along(nm)) {
      stump <- rpart::rpart(label ~ x, data = data.frame(label = factor(labels), x = scores[, j]), method = "class",
        control = rpart::rpart.control(maxdepth = 1, minsplit = 2, minbucket = bucket, cp = 0, xval = 0, maxcompete = 0, maxsurrogate = 0))
      if (!is.null(stump$splits) && nrow(stump$splits)) thresholds[j] <- stump$splits[1, "index"]
    }
  }
  names(thresholds) <- nm
  # Example regions for each sniglet: from the images that have it, strongest
  # first, one per label before any second one, so that the examples show
  # what the classes share.
  have <- match(rownames(scores), rownames(sniglets$best))
  exemplarsFor <- function(x) {
    if (is.null(sniglets$best) || is.null(rownames(scores)) || anyNA(have)) {
      ex <- sniglets$exemplars
      if (is.null(ex)) return(NULL)
      r <- ex[ex$sniglet == x, c("image", "patch", "score")]; rownames(r) <- NULL
      return(r)
    }
    want <- if (is.null(sniglets$exemplars)) 4L else max(1L, sum(sniglets$exemplars$sniglet == x))
    sc <- scores[, x]
    strong <- order(sc, decreasing = TRUE)
    strong <- strong[sc[strong] > thresholds[[x]]]
    if (!length(strong)) strong <- which.max(sc)
    first <- strong[!duplicated(labels[strong])]
    pick <- utils::head(c(first, setdiff(strong, first)), want)
    data.frame(image = rownames(scores)[pick], patch = sniglets$best[have[pick], x], score = unname(sc[pick]),
               label = labels[pick], stringsAsFactors = FALSE)
  }
  features <- featureTable(
    id = paste0("sniglet:", nm), kind = "centroid_patch_max", label = shown,
    definition = sniglets$sniglets$definition[row],
    embedding = lapply(seq_along(nm), function(j) unname(cent[nm[j], ])),
    exemplars = lapply(nm, exemplarsFor)
  )
  # the key remembers how its regions were cut, for scoreImages() and patchExemplars()
  withTiles <- function(meta) {
    if (is.null(meta)) meta <- data.frame(key = character(), value = character(), stringsAsFactors = FALSE)
    rbind(meta[!meta$key %in% c("sniglet_tiles", "sniglet_empty"), ],
          data.frame(key = c("sniglet_tiles", "sniglet_empty"),
                     value = c(paste(sniglets$tiles, collapse = ","), paste(sniglets$empty, collapse = ",")), stringsAsFactors = FALSE))
  }
  present <- sweep(scores, 2, thresholds, ">")
  # Both leads of a couplet get example regions from the images that take them.
  # A "Has" lead shows the sniglet in those images. A "Lacks" lead shows what
  # its images have instead: another sniglet that (nearly) all of them have and
  # (nearly) none of the other side does, named in the lead ("Lacks X; has Y"),
  # or, when there is no such sniglet, the regions that come closest to X.
  withExamples <- function(leads) {
    leads$Counter <- ""; leads$Examples <- ""
    if (is.null(sniglets$best) || is.null(rownames(scores)) || anyNA(have)) return(leads)
    want <- if (is.null(sniglets$exemplars)) 4L else max(1L, max(table(sniglets$exemplars$sniglet)))
    examples <- function(group, x) {
      group <- group[order(scores[group, x], decreasing = TRUE)]
      first <- group[!duplicated(labels[group])]
      pick <- utils::head(c(first, setdiff(group, first)), want)
      paste(paste(rownames(scores)[pick], sniglets$best[have[pick], x], sep = "|"), collapse = ";")
    }
    reach <- vector("list", nrow(leads))                 # images that take each lead
    root <- setdiff(leads$Statement, leads$Next)[1]
    queue <- list(list(couplet = root, images = seq_len(nrow(scores))))
    while (length(queue)) {
      now <- queue[[1]]; queue <- queue[-1]
      for (r in which(leads$Statement == now$couplet)) {
        x <- snigletWord(leads$Feature[r])
        if (!x %in% nm) next
        has <- scores[now$images, x] > leads$Threshold[r]
        reach[[r]] <- now$images[if (leads$Test[r] == ">") has else !has]
        if (leads$Next[r] != "-") queue[[length(queue) + 1]] <- list(couplet = leads$Next[r], images = reach[[r]])
      }
    }
    for (couplet in unique(leads$Statement)) {
      rows <- which(leads$Statement == couplet)
      yes <- rows[leads$Test[rows] == ">"]; no <- rows[leads$Test[rows] == "<="]
      if (length(yes) != 1 || length(no) != 1 || !length(reach[[yes]]) || !length(reach[[no]])) next
      x <- snigletWord(leads$Feature[yes])
      leads$Examples[yes] <- examples(reach[[yes]], x)
      gain <- colMeans(present[reach[[no]], , drop = FALSE]) - colMeans(present[reach[[yes]], , drop = FALSE])
      clean <- colMeans(present[reach[[no]], , drop = FALSE]) >= 0.9 & colMeans(present[reach[[yes]], , drop = FALSE]) <= 0.1 & nm != x
      if (any(clean)) {
        y <- nm[clean][which.max(gain[clean])]
        leads$Counter[no] <- paste0("sniglet:", y)
        leads$Examples[no] <- examples(reach[[no]], y)
      } else {
        leads$Examples[no] <- examples(reach[[no]], x)
      }
    }
    leads
  }
  if (method == "rpart") {
    # a tree on has/lacks, so a sniglet means the same thing at every couplet
    data <- data.frame(label = factor(labels), as.data.frame(present + 0), check.names = FALSE)
    fit <- rpart::rpart(stats::reformulate(paste0("`", nm, "`"), "label"), data = data, method = "class", y = TRUE,
      control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0, xval = 0, maxcompete = 0))
    key <- keyFromRpart(fit, desc, meta)
    leads <- key$leads
    # keyFromRpart's Character is labels(fit) with "=" turned into ": ", so an
    # rpart split "t1>=0.5"/"t1< 0.5" arrives as "t1>: 0.5"/"t1< 0.5".
    m <- regmatches(leads$Character, regexec("^(.+?)(>:|<) ?([-0-9.e]+)$", leads$Character))
    feat <- vapply(m, function(x) if (length(x) == 4) x[2] else "", "")
    op <- vapply(m, function(x) if (length(x) == 4) x[3] else "", "")
    leads$Feature <- ifelse(nzchar(feat), paste0("sniglet:", feat), "")
    leads$Test <- ifelse(op == ">:", ">", ifelse(op == "<", "<=", ""))
    leads$Threshold <- unname(thresholds[feat])
    return(keyFromLeads(snigletLeadText(withExamples(leads), features), desc, withTiles(meta), features = features))
  }
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
      Statement = id, Choice = c("a", "b"), Character = "",
      Next = vapply(kids, function(k) if (is.null(k$leaf)) k$id else "-", ""),
      Taxon = vapply(kids, function(k) if (is.null(k$leaf)) "" else k$leaf, ""),
      Question = "", Feature = paste0("sniglet:", x), Test = c(">", "<="), Threshold = thresholds[[best$j]],
      stringsAsFactors = FALSE)
    list(id = id)
  }
  top <- build(seq_along(ulab), integer(), 0)
  if (!is.null(top$leaf)) stop("No sniglet separates the labels", call. = FALSE)
  leads <- do.call(rbind, rows[order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  keyFromLeads(snigletLeadText(withExamples(leads), features), desc, withTiles(meta), features = features)
}

#' @rdname keyFromSniglets
#' @param terms,... `keyFromTerms()` is the earlier name of
#'   `keyFromSniglets()`; its third argument was called `terms`.
#' @export
keyFromTerms <- function(scores, images, terms, ...) keyFromSniglets(scores, images, terms, ...)


#' Names of a key's sniglets
#'
#' Lists the sniglets of a key (or of a [discoverSniglets()] result) with the
#' names they currently go by. This is the table [renameSniglets()] takes:
#' write it to a CSV file, fill in the `name` and `definition` columns, and
#' read it back.
#'
#' @param x A key from [keyFromSniglets()], or a [discoverSniglets()] result.
#' @return A data frame with one row per sniglet:
#'   * `sniglet`: the coined word. It identifies the sniglet and never changes.
#'   * `name`: the name people see. It is the coined word until you rename it.
#'   * `definition`: an optional sentence saying what the sniglet is.
#'   * `used` (keys only): whether the key asks about this sniglet. Only these
#'     need names.
#' @seealso [renameSniglets()]
#' @export
snigletNames <- function(x) {
  if (inherits(x, "moose")) {
    f <- x$features
    rows <- if (is.null(f)) integer() else which(f$kind == "centroid_patch_max")
    if (!length(rows)) stop("This key has no sniglets", call. = FALSE)
    return(data.frame(sniglet = snigletWord(f$id[rows]), name = f$label[rows],
                      definition = if (is.null(f$definition)) NA_character_ else f$definition[rows],
                      used = f$id[rows] %in% x$leads$Feature, stringsAsFactors = FALSE))
  }
  s <- asSniglets(x)$sniglets[, c("sniglet", "name", "definition")]
  rownames(s) <- NULL
  s
}

#' Rename sniglets
#'
#' Sniglets start with coined names (`"dulmzil"`) because nobody has looked at
#' them yet. After looking at what a sniglet picks out (the example crops in
#' the wizard's glossary), give it a real name. The coined word stays as the
#' sniglet's permanent identifier, so scores, machine tests and saved name
#' tables keep working; only the text people read changes: the leads
#' (`"Has round headlights"`), the questions and the glossary.
#'
#' The names table has one row per sniglet you want to rename, with columns
#' `sniglet` (the coined word, or the sniglet's current name), `name` and
#' optionally `definition`. Rules:
#'
#' * a blank `name` puts the coined word back;
#' * no two sniglets may share a name, and a name may not be another
#'   sniglet's coined word;
#' * a `definition` column replaces the definitions of the rows listed
#'   (blank removes one); without the column, definitions are left alone;
#' * a `used` column, as [snigletNames()] returns, is ignored.
#'
#' Names read best as noun phrases (`"an egg-crate grille"`), since leads are
#' written "Has *name*" and "Lacks *name*".
#'
#' @param x A key from [keyFromSniglets()], or a [discoverSniglets()] result
#'   (so that every key built from it afterwards uses the names).
#' @param names The new names: a named character vector
#'   (`c(dulmzil = "an egg-crate grille")`), a names table as described above,
#'   or the path of a CSV file holding one.
#' @param definitions Optional named character vector of definitions, named
#'   like `names`. `names` may be `NULL` to change definitions only.
#' @return A renamed copy of `x`; `x` itself is not changed.
#' @seealso [snigletNames()]
#' @examples
#' set.seed(1)
#' patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
#' patches <- sweep(patches, c(1, 2), sqrt(apply(patches^2, c(1, 2), sum)), "/")
#' s <- discoverSniglets(patches, k = 3)
#' first <- s$sniglets$sniglet[1]
#' s <- renameSniglets(s, stats::setNames("round headlights", first),
#'                     definitions = stats::setNames("Circular lamps in the grille", first))
#' snigletNames(s)
#' @export
renameSniglets <- function(x, names = NULL, definitions = NULL) {
  current <- snigletNames(x)
  what <- if (inherits(x, "moose")) "key" else "set"
  # rows of `current` that the given coined words (or current names) refer to
  find <- function(words) {
    row <- match(words, current$sniglet)
    row[is.na(row)] <- match(words[is.na(row)], current$name)
    if (anyNA(row)) stop("Not a sniglet of this ", what, ": ", paste(utils::head(words[is.na(row)], 5), collapse = ", "), call. = FALSE)
    if (anyDuplicated(row)) stop("A sniglet is listed more than once: ", paste(unique(current$sniglet[row[duplicated(row)]]), collapse = ", "), call. = FALSE)
    row
  }
  blankToNA <- function(v) { v <- trimws(as.character(v)); v[!is.na(v) & !nzchar(v)] <- NA; v }
  tab <- snigletNamesTable(names)
  row <- find(tab$sniglet)
  new <- blankToNA(tab$name)
  new[is.na(new)] <- current$sniglet[row[is.na(new)]]
  name <- current$name; name[row] <- new
  taken <- match(tolower(name), tolower(current$sniglet))
  wrong <- !is.na(taken) & taken != seq_along(name)
  if (any(wrong)) stop("A name cannot be another sniglet's coined word: ", paste(name[wrong], collapse = ", "), call. = FALSE)
  clash <- tolower(name) %in% tolower(name)[duplicated(tolower(name))]
  if (any(clash)) stop("Sniglets cannot share a name: ", paste(unique(name[clash]), collapse = ", "), call. = FALSE)
  definition <- current$definition
  if (!is.null(tab$definition)) definition[row] <- blankToNA(tab$definition)
  if (!is.null(definitions)) {
    if (is.null(names(definitions))) stop("`definitions` must be a named character vector", call. = FALSE)
    definition[find(names(definitions))] <- blankToNA(definitions)
  }

  if (!inherits(x, "moose")) {
    x <- asSniglets(x)
    x$sniglets$name <- name
    x$sniglets$definition <- definition
    return(x)
  }
  f <- x$features
  rows <- which(f$kind == "centroid_patch_max")
  f$label[rows] <- name
  if (is.null(f$definition)) f$definition <- NA_character_
  f$definition[rows] <- definition
  keyFromLeads(snigletLeadText(x$leads, f), x$desc, x$meta, x$taxa, features = f)
}

# ---- internals ---------------------------------------------------------------

# The coined word inside a sniglet feature id ("sniglet:dulmzil"; keys made
# before the rename used "term:dulmzil").
snigletWord <- function(id) sub("^[^:]*:", "", id)

# Write the text of every lead that tests a sniglet from the sniglets' names:
# "Has X", "Lacks X", or "Lacks X; has Y" when the lead names what its images
# have instead (its Counter).
snigletLeadText <- function(leads, features) {
  sn <- features$kind == "centroid_patch_max"
  nameOf <- function(id) features$label[sn][match(id, features$id[sn])]
  name <- nameOf(leads$Feature)
  on <- !is.na(name) & leads$Test %in% c(">", "<=")
  leads$Question[on] <- name[on]
  leads$Character[on] <- paste(ifelse(leads$Test[on] == ">", "Has", "Lacks"), name[on])
  if (!is.null(leads$Counter)) {
    other <- nameOf(leads$Counter)
    both <- on & !is.na(other)
    leads$Character[both] <- paste0(leads$Character[both], "; has ", other[both])
  }
  leads
}

# A names table (sniglet, name[, definition]) from any accepted input.
snigletNamesTable <- function(names) {
  if (is.character(names) && length(names) == 1 && is.null(names(names)) &&
      (file.exists(names) || grepl("\\.[A-Za-z]+$", names))) {
    if (!file.exists(names)) stop("Names file not found: ", names, call. = FALSE)
    names <- utils::read.csv(names, stringsAsFactors = FALSE, colClasses = "character", na.strings = "NA")
  }
  tab <- if (is.data.frame(names)) {
    if (!all(c("sniglet", "name") %in% names(names))) stop("A names table needs columns `sniglet` and `name`", call. = FALSE)
    names[, intersect(c("sniglet", "name", "definition"), names(names)), drop = FALSE]
  } else if (is.character(names) && !is.null(names(names))) {
    data.frame(sniglet = names(names), name = unname(names), stringsAsFactors = FALSE)
  } else if (is.null(names)) {
    data.frame(sniglet = character(), name = character(), stringsAsFactors = FALSE)
  } else {
    stop("`names` must be a named character vector, a names table or a CSV file", call. = FALSE)
  }
  tab$sniglet <- trimws(as.character(tab$sniglet))
  tab
}

# Accept the object discoverTerms() used to return.
asSniglets <- function(x) {
  if (inherits(x, "mooseSniglets")) return(x)
  if (inherits(x, "mooseTerms") && !is.null(x$terms)) {
    ex <- x$exemplars
    if (!is.null(ex) && "term" %in% names(ex)) names(ex)[names(ex) == "term"] <- "sniglet"
    return(structure(list(
      sniglets = data.frame(id = x$terms$id, sniglet = x$terms$name, name = x$terms$name,
                            definition = NA_character_, stringsAsFactors = FALSE),
      centroids = x$centroids, exemplars = ex, tiles = integer(0)), class = "mooseSniglets"))
  }
  stop("Expected the result of discoverSniglets()", call. = FALSE)
}
