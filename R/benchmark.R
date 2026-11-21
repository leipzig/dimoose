#' Download a balanced sample of iNaturalist photos
#'
#' Collects field photos to test a key with: for each species, `n`
#' observations from [iNaturalist](https://www.inaturalist.org) with an openly
#' licensed photo, the photo files, and a manifest that says where every photo
#' came from, so that a benchmark can be cited and run again.
#'
#' @section How the sample is drawn:
#' The sample depends only on the arguments, not on the day it is drawn:
#'
#' 1. `idBelow` fixes the snapshot: only observations with a smaller id are
#'    considered. When it is `NULL` the newest observation id at the time of
#'    the call is used and recorded in the manifest (`id_below`); give that
#'    value to draw the same sample again later.
#' 2. For each species a pool of up to `pool` observations is collected from
#'    `strata` equal slices of the id range (the newest observations below
#'    each cut), so that the pool spans the years rather than being last
#'    month's photos. Ids follow upload dates, so each slice is a short
#'    stretch of time and the same stretches are used for every species;
#'    raise `strata` (one request each) for an evener spread over the
#'    seasons.
#' 3. From the pool, sorted by id, `n` observations are drawn with `seed`,
#'    taking at most `perObserver` from one observer, so that one person's
#'    many photos of the same tree cannot dominate.
#'
#' Observations that were deleted or lost their research grade since are
#' simply no longer returned, so an old sample can shrink; the photo files
#' already in `dir` are kept and not downloaded again. A photo that cannot be
#' downloaded, or that turns out not to be an image, is left out of the
#' manifest with a warning; it is not replaced by another.
#'
#' @section Which taxon a name means:
#' A name is looked up in iNaturalist's taxon search and must match a taxon's
#' name exactly; a looser match (the search also finds "Oenantheae" and
#' "Oenanthe oenanthe" for "Oenanthe") is never used. A name iNaturalist
#' lists as a synonym resolves to the taxon it now belongs to, with a message.
#' The same name can belong to two taxa (the genus *Oenanthe* is a bird and a
#' plant): then the one whose rank fits the name best and that has the most
#' observations is used, with a warning that lists the candidates and their
#' ids. Give the taxon id instead of the name to choose yourself. The
#' manifest records the id that was used.
#'
#' @section API etiquette:
#' Requests are spaced at least `pause` seconds apart (iNaturalist asks for
#' about one request a second) and identify themselves with a generic
#' User-Agent. Only photos whose own licence is in `licenses` are taken;
#' the manifest keeps each photo's licence and attribution, which the CC BY
#' licences require you to show wherever the photos are.
#'
#' @param taxa The species: scientific names, results written
#'   `"Common name (Genus species)"`, a [dimoose] key (its results are used),
#'   or iNaturalist taxon ids (a numeric vector, named to give the labels).
#' @param n Observations to sample per species.
#' @param place Optional place to restrict the sample to: an iNaturalist
#'   place id, or a name to look up (the best match is used and reported).
#' @param qualityGrade iNaturalist quality grade. `"research"` means the
#'   community agreed on the species.
#' @param licenses Photo licences to accept.
#' @param dir Folder to put the photos and `manifest.csv` in; one subfolder
#'   per species. Keep it outside a package or repository.
#' @param fetch Function `function(url, query)` that performs an API request
#'   and returns the parsed JSON as a list. The default calls the iNaturalist
#'   API; tests give their own.
#' @param download Function `function(url, destfile)` that saves a photo.
#' @param size Photo size: `"small"` (240 px), `"medium"` (500 px), `"large"`
#'   (1024 px) or `"original"`.
#' @param pool,strata Size of the pool the sample is drawn from, and the
#'   number of slices of the id range it is collected from.
#' @param idBelow Only observations with an id below this; see above.
#' @param seed Seed for drawing the sample from the pool.
#' @param perObserver Most observations to take from one observer per species.
#' @param photosPerObservation Most photos to take from one observation.
#' @param query Further parameters for the observation search, e.g.
#'   `list(month = "6,7,8")` for summer photos only.
#' @param pause Least number of seconds between requests.
#' @return The manifest, a data frame with one row per photo: `taxon` (the
#'   label, as given in `taxa`), `scientific_name`, `taxon_id`,
#'   `observation_id`, `photo_id`, `license`, `attribution`, `url`,
#'   `observation_url`, `observed_on`, `file` (relative to `dir`),
#'   `quality_grade`, `place_id`, `id_below` and `retrieved`; plus `path`, the
#'   full file name on this computer, which is not written to
#'   `manifest.csv`. [benchmarkKey()] takes it as its `photos`.
#' @seealso [benchmarkKey()]
#' @examples
#' \dontrun{
#' photos <- inatPhotos(montanaKey(), n = 20, dir = file.path(tempdir(), "inat"))
#' table(photos$taxon)
#' }
#' @export
inatPhotos <- function(taxa, n = 20, place = NULL, qualityGrade = "research", licenses = c("cc0", "cc-by", "cc-by-nc"),
                       dir, fetch = benchInatGet, download = benchDownload, size = "medium", pool = 200, strata = 10,
                       idBelow = NULL, seed = 1, perObserver = 1, photosPerObservation = 1, query = list(), pause = 1) {
  size <- match.arg(size, c("small", "medium", "large", "original"))
  if (missing(dir)) stop("Give `dir`, the folder to put the photos in", call. = FALSE)
  api <- "https://api.inaturalist.org/v1/"
  licenses <- tolower(licenses)
  last <- NULL
  wait <- function() {                         # at most one request every `pause` seconds
    if (!is.null(last) && pause > 0) {
      left <- pause - as.numeric(difftime(Sys.time(), last, units = "secs"))
      if (left > 0) Sys.sleep(left)
    }
    last <<- Sys.time()
  }
  get <- function(path, q) {
    wait()
    r <- fetch(paste0(api, path), q[!vapply(q, is.null, logical(1))])
    if (!is.list(r)) stop("iNaturalist returned something that is not JSON for ", path, call. = FALSE)
    r
  }

  if (inherits(taxa, "dimoose")) taxa <- unique(taxa$leads$Taxon[!is.na(taxa$leads$Taxon) & nzchar(taxa$leads$Taxon)])
  if (is.numeric(taxa)) {
    labels <- if (is.null(names(taxa))) as.character(taxa) else names(taxa)
    taxonId <- as.numeric(taxa); sci <- rep(NA_character_, length(taxa))
  } else {
    labels <- as.character(taxa)
    sci <- scientificPart(labels); sci[is.na(sci)] <- labels[is.na(sci)]
    taxonId <- rep(NA_real_, length(labels))
  }
  if (!length(labels) || anyNA(labels) || any(!nzchar(trimws(labels))) || anyDuplicated(labels)) {
    stop("`taxa` must name each species once", call. = FALSE)
  }
  if (is.numeric(taxa) && (anyNA(taxonId) || any(taxonId <= 0 | taxonId != round(taxonId)))) stop("Taxon ids must be whole numbers", call. = FALSE)
  whole <- function(v, least) is.numeric(v) && length(v) == 1 && !is.na(v) && v >= least
  if (!whole(n, 1)) stop("`n` must be 1 or more", call. = FALSE)
  if (!whole(strata, 1) || !whole(pool, 1)) stop("`pool` and `strata` must be 1 or more", call. = FALSE)
  if (!whole(perObserver, 1) || !whole(photosPerObservation, 1)) stop("`perObserver` and `photosPerObservation` must be 1 or more", call. = FALSE)
  if (!length(licenses) || anyNA(licenses)) stop("Give at least one licence in `licenses`", call. = FALSE)

  placeId <- NULL
  if (!is.null(place)) {
    if (is.numeric(place)) placeId <- place else {
      found <- get("places/autocomplete", list(q = place, per_page = 10))$results
      if (!length(found)) stop("iNaturalist knows no place called ", place, call. = FALSE)
      nm <- vapply(found, function(p) c(p$display_name, p$name, "")[1], "")
      hit <- match(tolower(place), tolower(c(nm, vapply(found, function(p) c(p$name, "")[1], ""))))
      hit <- if (is.na(hit)) 1L else ((hit - 1L) %% length(found)) + 1L
      placeId <- found[[hit]]$id
      message("Place: ", nm[hit], " (iNaturalist place ", placeId, ")")
    }
  }
  if (is.null(idBelow)) {
    newest <- get("observations", list(per_page = 1, order_by = "id", order = "desc"))$results
    if (!length(newest)) stop("Could not find the newest iNaturalist observation", call. = FALSE)
    idBelow <- newest[[1]]$id + 1
  }
  idBelow <- as.numeric(idBelow)

  ext <- function(url) { e <- tolower(sub("^.*\\.([A-Za-z0-9]+)(\\?.*)?$", "\\1", url)); if (e %in% c("jpg", "jpeg", "png", "gif", "webp")) e else "jpg" }
  rows <- list()
  for (t in seq_along(labels)) {
    if (is.na(taxonId[t])) {
      found <- get("taxa", list(q = sci[t], is_active = "true", per_page = 30))$results
      hit <- benchPickTaxon(sci[t], found)
      if (is.null(hit)) {
        warning("iNaturalist has no taxon named ", sci[t], "; it is left out", call. = FALSE)
        next
      }
      taxonId[t] <- hit$id
    } else if (is.na(sci[t])) {
      # a taxon given by its id: ask for its name, so that the folder and the manifest carry it
      known <- tryCatch(get(paste0("taxa/", format(taxonId[t], scientific = FALSE)), list())$results, error = function(e) NULL)
      if (length(known) && is.character(known[[1]]$name)) sci[t] <- known[[1]]$name
    }
    # the pool: the newest observations below each of `strata` cuts of the id range
    cuts <- unique(ceiling(idBelow * rev(seq_len(strata)) / strata))
    each <- min(200, ceiling(pool / length(cuts)))
    obs <- list()
    for (cut in cuts) {
      got <- get("observations", c(list(taxon_id = taxonId[t], quality_grade = qualityGrade, photos = "true",
                                        photo_license = paste(licenses, collapse = ","), place_id = placeId,
                                        id_below = format(cut, scientific = FALSE), order_by = "id", order = "desc",
                                        per_page = each), query))$results
      for (o in got) obs[[as.character(o$id)]] <- o
    }
    obs <- obs[order(as.numeric(names(obs)))]
    usable <- lapply(obs, function(o) {
      ok <- Filter(function(p) !is.null(p$license_code) && tolower(p$license_code) %in% licenses && !is.null(p$url), o$photos)
      utils::head(ok, photosPerObservation)
    })
    obs <- obs[lengths(usable) > 0]; usable <- usable[lengths(usable) > 0]
    if (is.na(sci[t]) && length(obs)) sci[t] <- c(obs[[1]]$taxon$name, labels[t])[1]
    if (is.na(sci[t])) sci[t] <- labels[t]
    # the sample: a seeded shuffle of the pool, taking a few per observer at most
    shuffled <- if (length(obs) > 1) withr::with_seed(seed, sample(length(obs))) else seq_along(obs)
    who <- vapply(obs, function(o) as.character(c(o$user$id, NA)[1]), "")
    pick <- integer()
    for (i in shuffled) {
      if (length(pick) >= n) break
      if (!is.na(who[i]) && sum(who[pick] == who[i], na.rm = TRUE) >= perObserver) next
      pick <- c(pick, i)
    }
    if (length(pick) < n) {
      warning("Only ", length(pick), " of ", n, " observations found for ", labels[t], call. = FALSE)
    }
    folder <- slug(sci[t])
    for (i in sort(pick)) {
      o <- obs[[i]]
      for (p in usable[[i]]) {
        url <- sub("/square\\.", paste0("/", size, "."), p$url)
        rows[[length(rows) + 1]] <- data.frame(
          taxon = labels[t], scientific_name = sci[t], taxon_id = taxonId[t], observation_id = as.numeric(o$id),
          photo_id = as.numeric(p$id), license = tolower(p$license_code), attribution = c(p$attribution, "")[1], url = url,
          observation_url = paste0("https://www.inaturalist.org/observations", "/", format(o$id, scientific = FALSE)),
          observed_on = c(o$observed_on, NA_character_)[1],
          file = file.path(folder, paste0(format(o$id, scientific = FALSE), "_", format(p$id, scientific = FALSE), ".", ext(url))),
          stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(rows)) stop("No photos found for any of the taxa", call. = FALSE)
  manifest <- do.call(rbind, rows)
  manifest$quality_grade <- qualityGrade
  manifest$place_id <- if (is.null(placeId)) NA_real_ else as.numeric(placeId)
  manifest$id_below <- idBelow
  manifest$retrieved <- format(Sys.Date())

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  keep <- rep(TRUE, nrow(manifest))
  for (r in seq_len(nrow(manifest))) {
    dest <- file.path(dir, manifest$file[r])
    # a file from an earlier run is used again, unless it is not an image (a download that was cut short, an error page)
    isImage <- function(f) file.exists(f) && file.size(f) > 0 && !is.na(imageMime(f))
    if (isImage(dest)) next
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    wait()
    ok <- tryCatch({ download(manifest$url[r], dest); if (isImage(dest)) TRUE else "what came back is not an image" },
                   error = function(e) conditionMessage(e))
    if (!isTRUE(ok)) {
      warning("Could not download ", manifest$url[r], if (is.character(ok)) paste0(": ", ok), call. = FALSE)
      if (file.exists(dest)) unlink(dest)
      keep[r] <- FALSE
    }
  }
  manifest <- manifest[keep, , drop = FALSE]
  rownames(manifest) <- NULL
  if (!nrow(manifest)) stop("None of the photos could be downloaded", call. = FALSE)
  utils::write.csv(manifest, file.path(dir, "manifest.csv"), row.names = FALSE)
  manifest$path <- file.path(dir, manifest$file)
  manifest
}

#' Split photos into training and test sets by observation
#'
#' Photos of one observation show the same individual, often seconds apart.
#' Putting one in the training set and another in the test set would make a
#' key look better than it is, so whole observations go to one side.
#'
#' @param observation The observation each photo belongs to. A photo without
#'   one (`NA`) counts as an observation of its own.
#' @param label The class of each photo. The split is made within each class,
#'   so every class keeps about the same share for testing.
#' @param test Share of each class's observations to test with.
#' @param seed Seed for the draw.
#' @return A character vector, `"train"` or `"test"` for each photo. A class
#'   with two or more observations gets at least one on each side; a class
#'   with a single observation goes to the training set. An observation with
#'   photos in several classes stays whole too: all its photos go to the
#'   training set, so nothing in the test set has a sibling in training.
#' @examples
#' obs <- c(1, 1, 2, 3, 4, 5, 5, 6)
#' label <- rep(c("oak", "elm"), each = 4)
#' data.frame(obs, label, split = splitByObservation(obs, label, test = 0.5))
#' @export
splitByObservation <- function(observation, label, test = 0.3, seed = 1) {
  if (length(observation) != length(label)) stop("`observation` and `label` must have one entry per photo", call. = FALSE)
  if (!is.numeric(test) || length(test) != 1 || is.na(test) || test < 0 || test > 1) {
    stop("`test` must be a share between 0 and 1", call. = FALSE)
  }
  label <- as.character(label)
  if (anyNA(label)) stop("Every photo needs a `label`", call. = FALSE)
  observation <- as.character(observation)
  lone <- is.na(observation)
  observation[lone] <- paste0("\rphoto ", which(lone))        # no observation: the photo is its own
  out <- rep("train", length(label))
  if (test == 0 || !length(label)) return(out)
  if (test == 1) return(rep("test", length(label)))
  # drawn within each class, over its observations
  who <- paste(label, observation, sep = "\r")
  withr::with_seed(seed, for (l in sort(unique(label))) {
    obs <- sort(unique(who[label == l]))
    if (length(obs) < 2) next
    nTest <- min(length(obs) - 1L, max(1L, as.integer(round(test * length(obs)))))
    out[who %in% obs[sample(length(obs), nTest)]] <- "test"
  })
  # an observation with photos in two classes may have been drawn to both sides
  both <- intersect(observation[out == "train"], observation[out == "test"])
  out[observation %in% both] <- "train"
  out
}

#' Benchmark identification on field photos
#'
#' Measures how often photos are identified correctly, by one of three
#' routes:
#'
#' * `"names"`: the model ranks the key's own species for each photo from
#'   their names alone ([suggestSpecies()]); nothing is learned from the
#'   photos. With a `lineage` the answers of [identifyPhotos()], which fall
#'   back to the genus, family or order when the species is uncertain, are
#'   scored too.
#' * `"key"`: a key with machine tests (from [keyFromSniglets()] or
#'   [keyFromClusters()]) is followed for each photo ([scoreImages()],
#'   [evaluateKey()]).
#' * `"build"`: a photo key is built from the training photos (sniglets
#'   found in them, then [keyFromSniglets()]) and followed for the test
#'   photos. This is the route to use for "how good a key can be learned
#'   from photos like these".
#'
#' Training and test photos are divided by observation with
#' [splitByObservation()], never photo by photo.
#'
#' @param x A [dimoose] key, or (for `route = "build"`) a [visionModel()].
#' @param photos The photos: the manifest [inatPhotos()] returns, the path of
#'   a `manifest.csv` (give `dir` too), or a data frame with `path` and
#'   `label` and optionally `id` and `observation`. Labels may be the key's
#'   results or just their scientific names. Without an observation column
#'   every photo counts as its own observation.
#' @param model A [visionModel()].
#' @param route `"names"`, `"key"` or `"build"`. By default `"build"` when `x`
#'   is a vision model, `"key"` for a key with machine tests and `"names"`
#'   for any other key.
#' @param top Report the accuracy within this many guesses (`"names"` only: a
#'   key gives one answer).
#' @param test Share of each species' observations to test with. By default
#'   0.3 for `"build"` and all of them for the other routes, which learn
#'   nothing from the photos.
#' @param split Instead of `test`: `"train"` or `"test"` for each photo, e.g.
#'   from [splitByObservation()], to compare routes on the same test photos.
#' @param seed Seed for the split and for finding sniglets.
#' @param reps Number of splits to run. One split of a small sample says
#'   little: six test photos per species move a species' accuracy by 17
#'   points each. With `reps` above 1 the benchmark is repeated with seeds
#'   `seed`, `seed + 1`, ..., each with a new split (and, for `"build"`, a new
#'   key; the photos are embedded once), and the spread is reported. Needs a
#'   `test` share below 1, and no `split`.
#' @param dir The folder the manifest's `file` column is relative to.
#' @param prompt,lineage,confidence As in [identifyPhotos()]. `lineage` is
#'   optional and is never looked up here.
#' @param k,tiles,method For `"build"`: number of sniglets
#'   ([discoverSniglets()]), tiling ([embedImages()]) and tree method
#'   ([keyFromSniglets()]).
#' @param embeddings For `"build"`: the result of [embedImages()] for
#'   `photos`, if you have it already (rows in the same order).
#' @return An object of class `dimooseBenchmark`, a list with
#'   * `route`, `n` (test photos), `nTrain`, `observations` (test observations);
#'   * `accuracy`: share of test photos identified correctly (top-1);
#'   * `interval`: its 95% Wilson interval (`lower`, `upper`), which treats the
#'     test photos as independent draws: read it as the least uncertainty
#'     there is, not all of it;
#'   * `topK`: named vector of the accuracy within 1, ..., `top` guesses;
#'   * `perSpecies`: for each species its number of test photos, `top1` and
#'     (for `"names"`) the accuracy within `top` guesses. Every species of
#'     the photos (and of the key) has a row; one without test photos has
#'     `n = 0` and `NA` accuracies;
#'   * `confusion`: table of actual (rows) against predicted (columns), with
#'     the same species in the same order on both sides, so that the row sums
#'     are the `n` of `perSpecies` and the diagonal holds the correct answers.
#'     Any other answer has a column after them: a leaf that names several
#'     species, and `"<none>"` when a key gave no answer;
#'   * `results`: one row per test photo with `id`, `observation`, `actual`,
#'     `predicted`, `rank` (where the true species came in the ranking) and
#'     `correct`;
#'   * `split`: `"train"` or `"test"` for every photo given;
#'   * with `reps` above 1, all of the above describe the first split, and
#'     there are also `repeats` (one row per split: `rep`, `seed`, `n`,
#'     `nTrain`, `correct`, `accuracy`), `accuracyMean`, `accuracySd` (the
#'     standard deviation between splits) and `accuracyRange`, and
#'     `perSpecies` gains `top1Mean`, the species' accuracy over all splits'
#'     test photos together. The splits share photos, so they are not
#'     independent samples: the spread shows how much one split can mislead,
#'     it is not a standard error;
#'   * `key` (for `"build"`, the key that was built) and `identify` (for
#'     `"names"` with a `lineage`: the [identifyPhotos()] answers with
#'     `correct`, and the shares that were `confident` and `correct`).
#' @seealso [inatPhotos()], [evaluateKey()], [looKey()]
#' @examples
#' \dontrun{
#' key <- montanaKey()
#' photos <- inatPhotos(key, n = 20, dir = file.path(tempdir(), "inat"))
#' model <- visionModel(name = "bioclip-2")
#' benchmarkKey(key, photos, model)                    # species ranked from their names
#' benchmarkKey(model, photos)                         # a key built from 70% of the observations
#' }
#' @export
benchmarkKey <- function(x, photos, model = NULL, route = NULL, top = 3, test = NULL, split = NULL, seed = 1, dir = NULL,
                         prompt = "a photo of %s.", lineage = NULL, confidence = 0.8,
                         k = 40, tiles = 4, method = "rpart", embeddings = NULL, reps = 1) {
  if (!is.numeric(reps) || length(reps) != 1 || is.na(reps) || reps < 1 || reps != round(reps)) stop("`reps` must be a whole number, 1 or more", call. = FALSE)
  if (reps > 1) {
    return(benchRepeat(x, photos, model = model, route = route, top = top, test = test, split = split, seed = seed, dir = dir,
                       prompt = prompt, lineage = lineage, confidence = confidence, k = k, tiles = tiles, method = method,
                       embeddings = embeddings, reps = as.integer(reps)))
  }
  key <- NULL
  if (inherits(x, "dimooseVisionModel")) {
    model <- x
    if (is.null(route)) route <- "build"
  } else if (inherits(x, "dimoose")) {
    key <- x
    if (is.null(route)) route <- if (any(nzchar(normalizeLeads(key$leads)$Feature))) "key" else "names"
  } else {
    stop("`x` must be a dimoose key or a vision model", call. = FALSE)
  }
  route <- match.arg(route, c("names", "key", "build"))
  if (route != "build" && is.null(key)) stop("The \"", route, "\" route needs a key", call. = FALSE)
  if (is.null(model) && !(route == "build" && !is.null(embeddings))) stop("Give `model`, a visionModel()", call. = FALSE)
  photos <- benchPhotos(photos, dir)
  if (route != "build") photos$label <- benchLabels(photos$label, key, strict = route == "names")
  # every species there is to get right: those of the photos, then any others the key ends in
  species <- sort(unique(photos$label))
  if (!is.null(key)) {
    ends <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
    species <- c(species, sort(setdiff(ends[!grepl(" / ", ends, fixed = TRUE)], species)))
  }
  if (is.null(split)) {
    if (is.null(test)) test <- if (route == "build") 0.3 else 1
    split <- splitByObservation(photos$observation, photos$label, test = test, seed = seed)
  } else {
    if (length(split) != nrow(photos) || !all(split %in% c("train", "test"))) {
      stop("`split` must say \"train\" or \"test\" for each photo", call. = FALSE)
    }
    both <- intersect(photos$observation[split == "train"], photos$observation[split == "test"])
    if (length(both)) stop("`split` puts photos of one observation on both sides: ", paste(utils::head(both, 5), collapse = ", "), call. = FALSE)
  }
  isTest <- split == "test"
  if (!any(isTest)) stop("There are no test photos", call. = FALSE)
  tp <- photos[isTest, , drop = FALSE]
  built <- NULL; identify <- NULL

  if (route == "names") {
    taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
    top <- max(1L, min(as.integer(top), length(taxa)))
    ranked <- suggestSpecies(key, model, tp[, c("id", "path")], top = length(taxa), prompt = prompt)
    first <- ranked[ranked$rank == 1, ]
    at <- match(paste(tp$id, tp$label, sep = "\r"), paste(ranked$image, ranked$Taxon, sep = "\r"))
    res <- data.frame(id = tp$id, observation = tp$observation, actual = tp$label,
                      predicted = first$Taxon[match(tp$id, first$image)], rank = ranked$rank[at], stringsAsFactors = FALSE)
    if (!is.null(lineage)) {
      ans <- identifyPhotos(key, model, tp[, c("id", "path")], confidence = confidence, lineage = lineage, prompt = prompt)
      ans <- ans[match(tp$id, ans$image), ]
      ans$actual <- tp$label
      truth <- vapply(seq_len(nrow(ans)), function(i) {
        if (ans$rank[i] == "species") return(ans$actual[i])
        as.character(lineage[[ans$rank[i]]][match(ans$actual[i], lineage$Taxon)])
      }, "")
      ans$correct <- !is.na(truth) & ifelse(ans$rank == "species", !is.na(ans$Taxon) & ans$Taxon == truth, ans$name == truth)
      rownames(ans) <- NULL
      identify <- list(results = ans, confident = mean(ans$confident), correct = mean(ans$correct),
                       correctWhenConfident = if (any(ans$confident)) mean(ans$correct[ans$confident]) else NA_real_,
                       byRank = table(rank = ans$rank, correct = ans$correct))
    }
  } else {
    if (route == "build") {
      if (!any(!isTest)) stop("There are no training photos to build a key from", call. = FALSE)
      emb <- if (is.null(embeddings)) embedImages(model, photos[, c("id", "path")], tiles = tiles) else embeddings
      pt <- emb$patches
      if (is.null(pt) || dim(pt)[1] != nrow(photos)) stop("`embeddings` must hold the patches of every photo, in order", call. = FALSE)
      dimnames(pt)[[1]] <- photos$id
      train <- pt[!isTest, , , drop = FALSE]
      attr(train, "tiles") <- attr(pt, "tiles"); attr(train, "empty") <- attr(pt, "empty")
      filled <- sum(apply(train != 0, c(1, 2), any))
      sn <- discoverSniglets(train, k = max(2L, min(as.integer(k), filled - 1L)), seed = seed)
      scores <- snigletScores(pt, sn$centroids)
      built <- keyFromSniglets(scores[!isTest, , drop = FALSE], photos[!isTest, c("id", "path", "label")], sn, method = method,
                               desc = "Key built from the training photos of a benchmark",
                               meta = if (is.null(model)) NULL else modelMeta(model))
      ev <- evaluateKey(built, scores[isTest, , drop = FALSE], tp$label)
    } else {
      ev <- evaluateKey(key, scoreImages(key, model, tp[, c("id", "path")]), tp$label)
    }
    res <- data.frame(id = tp$id, observation = tp$observation, actual = tp$label, predicted = ev$results$predicted,
                      rank = ifelse(ev$results$correct, 1L, NA_integer_), stringsAsFactors = FALSE)
    top <- 1L
  }
  res$correct <- !is.na(res$predicted) & res$predicted == res$actual
  rownames(res) <- NULL
  # a species without test photos has no accuracy (NA), rather than 0 or NaN
  within <- function(kk, rows = TRUE) if (any(rows)) mean(!is.na(res$rank[rows]) & res$rank[rows] <= kk) else NA_real_
  topK <- stats::setNames(vapply(seq_len(top), within, numeric(1)), paste0("top", seq_len(top)))
  per <- data.frame(Taxon = species, n = as.integer(table(factor(res$actual, species))),
                    top1 = vapply(species, function(s) within(1, res$actual == s), numeric(1)), stringsAsFactors = FALSE)
  if (top > 1) per[[paste0("top", top)]] <- vapply(species, function(s) within(top, res$actual == s), numeric(1))
  rownames(per) <- NULL
  # the same species, in the same order, down and across; other answers after them
  answer <- ifelse(is.na(res$predicted), "<none>", res$predicted)
  other <- sort(setdiff(answer, c(species, "<none>")))
  confusion <- table(actual = factor(res$actual, species),
                     predicted = factor(answer, c(species, other, if ("<none>" %in% answer) "<none>")))
  structure(list(route = route, n = nrow(res), nTrain = sum(!isTest), observations = length(unique(tp$observation)),
                 accuracy = mean(res$correct), interval = benchWilson(sum(res$correct), nrow(res)),
                 topK = topK, perSpecies = per, confusion = confusion,
                 results = res, split = split, key = built, identify = identify,
                 model = if (is.null(model)) NA_character_ else c(model$spec$arch, NA_character_)[1]),
            class = "dimooseBenchmark")
}

#' @export
print.dimooseBenchmark <- function(x, ...) {
  x$perSpecies <- x$perSpecies[!is.na(x$perSpecies$Taxon), , drop = FALSE]
  how <- c(names = "species ranked from their names", key = "key followed by machine",
           build = "key built from the training photos")[[x$route]]
  cat("<dimoose benchmark> ", how, "\n", sep = "")
  cat("  ", x$n, " test photos of ", sum(x$perSpecies$n > 0), " species from ", x$observations, " observations",
      if (x$nTrain > 0) paste0("; ", x$nTrain, " training photos"), "\n", sep = "")
  cat("  ", paste(sprintf("%s %.1f%%", sub("top", "top-", names(x$topK)), 100 * x$topK), collapse = ", "),
      if (!is.null(x$interval)) sprintf(" (top-1: %d of %d, 95%% interval %.1f to %.1f%%)", sum(x$results$correct), x$n,
                                        100 * x$interval[["lower"]], 100 * x$interval[["upper"]]), "\n", sep = "")
  if (!is.null(x$repeats)) {
    cat(sprintf("  %d splits (seeds %s to %s): top-1 mean %.1f%%, standard deviation %.1f, range %.1f to %.1f%%; the lines here are the first split\n",
                nrow(x$repeats), x$repeats$seed[1], x$repeats$seed[nrow(x$repeats)], 100 * x$accuracyMean, 100 * x$accuracySd,
                100 * x$accuracyRange[1], 100 * x$accuracyRange[2]))
  }
  if (!is.null(x$identify)) {
    cat(sprintf("  identifyPhotos: %.1f%% of answers confident; %.1f%% correct at the rank given\n",
                100 * x$identify$confident, 100 * x$identify$correct))
  }
  tested <- x$perSpecies[x$perSpecies$n > 0, , drop = FALSE]
  worst <- tested[order(tested$top1), ][seq_len(min(3, nrow(tested))), ]
  cat("  hardest: ", paste(sprintf("%s (%.0f%% of %d)", worst$Taxon, 100 * worst$top1, worst$n), collapse = "; "), "\n", sep = "")
  if (nrow(tested) < nrow(x$perSpecies)) {
    cat("  no test photos of: ", paste(x$perSpecies$Taxon[x$perSpecies$n == 0], collapse = "; "), "\n", sep = "")
  }
  invisible(x)
}

# ---- internals ---------------------------------------------------------------

# The taxon a name means, among the results of iNaturalist's taxon search:
# one whose name is exactly the name asked for, or failing that one found
# through exactly that name as a synonym. The search itself matches loosely
# and across kingdoms, so its first result is not to be trusted. Several
# exact matches are homonyms: the rank that fits the name comes first, then
# the most observed, and the choice is reported.
benchPickTaxon <- function(name, found) {
  same <- function(a) is.character(a) && length(a) == 1 && identical(tolower(trimws(a)), tolower(trimws(name)))
  found <- Filter(function(x) is.list(x) && !is.null(x$id) && !identical(x$is_active, FALSE), found)
  hit <- Filter(function(x) same(x$name), found)
  synonym <- FALSE
  if (!length(hit)) {
    hit <- Filter(function(x) same(x$matched_term), found)
    synonym <- length(hit) > 0
  }
  if (!length(hit)) return(NULL)
  words <- length(strsplit(trimws(name), "\\s+")[[1]])
  rank <- vapply(hit, function(x) c(x$rank, "")[1], "")
  fits <- if (words == 2) rank == "species" else if (words >= 3) rank %in% c("subspecies", "variety", "form", "hybrid") else rank != "species"
  seen <- vapply(hit, function(x) as.numeric(c(x$observations_count, 0)[1]), numeric(1))
  hit <- hit[order(!fits, -seen)]
  describe <- function(x) paste0(c(x$rank, "taxon")[1], " ", x$name, if (!is.null(x$iconic_taxon_name)) paste0(" in ", x$iconic_taxon_name),
                                 " (id ", format(x$id, scientific = FALSE), ")")
  if (length(hit) > 1) {
    warning(name, " is the name of ", length(hit), " iNaturalist taxa: ", paste(vapply(hit, describe, ""), collapse = "; "),
            ". The first is used; give the taxon id instead of the name to choose another.", call. = FALSE)
  } else if (synonym) {
    message(name, " is known to iNaturalist as ", describe(hit[[1]]))
  }
  hit[[1]]
}

# The 95% Wilson score interval of `correct` right answers out of `n`.
benchWilson <- function(correct, n, level = 0.95) {
  if (!n) return(c(lower = NA_real_, upper = NA_real_))
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- correct / n
  mid <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(lower = max(0, mid - half), upper = min(1, mid + half))
}

# benchmarkKey() over several splits: the first split's result, with the
# accuracy of every split and its spread added.
benchRepeat <- function(x, photos, model, route, test, split, seed, dir, tiles, embeddings, reps, ...) {
  if (!is.null(split)) stop("`reps` draws a new split each time, so `split` cannot be given with it", call. = FALSE)
  building <- inherits(x, "dimooseVisionModel") || identical(route, "build")
  if (is.null(test)) test <- if (building) 0.3 else 1
  if (!is.numeric(test) || length(test) != 1 || is.na(test) || test <= 0 || test >= 1) {
    stop("With `reps`, give a `test` share between 0 and 1: when every photo is a test photo each repeat is the same", call. = FALSE)
  }
  photos <- benchPhotos(photos, dir)
  if (building && is.null(embeddings)) {                       # embed once, not once per split
    vision <- if (inherits(x, "dimooseVisionModel")) x else model
    if (is.null(vision)) stop("Give `model`, a visionModel()", call. = FALSE)
    embeddings <- embedImages(vision, photos[, c("id", "path")], tiles = tiles)
  }
  seeds <- seed + seq_len(reps) - 1
  runs <- lapply(seeds, function(s) benchmarkKey(x, photos, model = model, route = route, test = test, seed = s, tiles = tiles,
                                                 embeddings = embeddings, reps = 1, ...))
  out <- runs[[1]]
  acc <- vapply(runs, function(r) r$accuracy, numeric(1))
  out$repeats <- data.frame(rep = seq_len(reps), seed = seeds, n = vapply(runs, function(r) r$n, numeric(1)),
                            nTrain = vapply(runs, function(r) r$nTrain, numeric(1)),
                            correct = vapply(runs, function(r) sum(r$results$correct), numeric(1)), accuracy = acc)
  out$accuracyMean <- mean(acc); out$accuracySd <- stats::sd(acc); out$accuracyRange <- range(acc)
  all <- do.call(rbind, lapply(runs, function(r) r$results[, c("actual", "correct")]))
  out$perSpecies$top1Mean <- vapply(out$perSpecies$Taxon, function(sp) if (any(all$actual == sp)) mean(all$correct[all$actual == sp]) else NA_real_,
                                    numeric(1))
  out
}

# How dimoose introduces itself to iNaturalist: what the client is, and
# nothing about who runs it.
benchUserAgent <- function() httr::user_agent("R httr client sampling photos for an identification benchmark")

# One GET of the iNaturalist API, parsed. A rate limit (HTTP 429) is waited
# out once.
benchInatGet <- function(url, query) {
  for (attempt in 1:2) {
    r <- httr::GET(url, query = query, benchUserAgent(), httr::timeout(60))
    if (httr::status_code(r) != 429 || attempt == 2) break
    Sys.sleep(60)
  }
  httr::stop_for_status(r, task = "search iNaturalist")
  httr::content(r, as = "parsed", type = "application/json", encoding = "UTF-8")
}

# Save one photo.
benchDownload <- function(url, destfile) {
  r <- httr::GET(url, httr::write_disk(destfile, overwrite = TRUE), benchUserAgent(), httr::timeout(120))
  httr::stop_for_status(r, task = "download a photo")
  invisible(destfile)
}

# Photos in the shape the benchmark works with: id, path, label, observation.
benchPhotos <- function(photos, dir = NULL) {
  if (is.character(photos) && length(photos) == 1) {
    if (!file.exists(photos)) stop("Manifest not found: ", photos, call. = FALSE)
    if (is.null(dir)) dir <- dirname(photos)
    photos <- utils::read.csv(photos, stringsAsFactors = FALSE)
  }
  if (!is.data.frame(photos) || !nrow(photos)) stop("`photos` must be a data frame of photos or a manifest file", call. = FALSE)
  # `[[`, not `$`: a manifest has columns such as id_below and observation_url,
  # which `$id` and `$observation` would quietly match
  label <- if (!is.null(photos[["label"]])) photos[["label"]] else photos[["taxon"]]
  if (is.null(label)) stop("`photos` needs a `label` (or `taxon`) column", call. = FALSE)
  path <- photos[["path"]]
  if (is.null(path)) {
    if (is.null(photos[["file"]]) || is.null(dir)) stop("`photos` needs a `path` column, or a `file` column and `dir`", call. = FALSE)
    path <- file.path(dir, photos[["file"]])
  }
  path <- as.character(path)
  id <- if (!is.null(photos[["id"]])) as.character(photos[["id"]]) else sub("\\.[^.]+$", "", basename(path))
  if (anyDuplicated(id)) stop("Photos must have distinct ids (file names): ", paste(utils::head(unique(id[duplicated(id)]), 5), collapse = ", "), call. = FALSE)
  observation <- if (!is.null(photos[["observation"]])) photos[["observation"]] else
    if (!is.null(photos[["observation_id"]])) photos[["observation_id"]] else id
  if (anyNA(label) || anyNA(path)) stop("Every photo needs a label and a path", call. = FALSE)
  # a photo without an observation is its own; numbers are written out in full (no 1e+08)
  obs <- if (is.numeric(observation)) format(observation, scientific = FALSE, trim = TRUE) else as.character(observation)
  lone <- is.na(observation) | !nzchar(trimws(obs))
  obs[lone] <- paste0("photo ", id[lone])
  data.frame(id = id, path = path, label = as.character(label), observation = obs, stringsAsFactors = FALSE)
}

# The key's result each photo label means: the result itself, or the result
# whose scientific name the label is. Ranking species by name (`strict`)
# needs every label to be one of them; a key that is followed may simply
# lack a species, and then never gets its photos right.
benchLabels <- function(labels, key, strict = TRUE) {
  taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
  sci <- scientificPart(taxa); sci[is.na(sci)] <- taxa[is.na(sci)]
  sci[grepl(" / ", taxa, fixed = TRUE)] <- NA   # a leaf that could not separate several classes is none of them
  own <- scientificPart(labels); own[is.na(own)] <- labels[is.na(own)]
  at <- match(labels, taxa)
  at[is.na(at)] <- match(tolower(own[is.na(at)]), tolower(sci))
  if (anyNA(at)) {
    msg <- paste0("Photos are labelled with something the key does not end in: ",
                  paste(utils::head(unique(labels[is.na(at)]), 5), collapse = ", "))
    if (strict) stop(msg, call. = FALSE)
    warning(msg, "; the key cannot get these right", call. = FALSE)
  }
  ifelse(is.na(at), labels, taxa[at])
}
