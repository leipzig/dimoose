# A stand-in for the iNaturalist API: two species with 30 observations each,
# answered the way /v1/taxa and /v1/observations answer. Records every call.
# What a download leaves behind: something imageMime() takes for a PNG.
fakePhoto <- function(destfile, what = "x") writeBin(c(as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)), charToRaw(what)), destfile)

fakeInat <- function() {
  calls <- new.env(); calls$log <- list(); calls$downloads <- character()
  taxa <- list(list(id = 11, name = "Populus tremuloides", is_active = TRUE),
               list(id = 12, name = "Populus tremula", is_active = TRUE),
               list(id = 22, name = "Acer negundo", is_active = TRUE))
  obsOf <- function(taxonId) {
    ids <- seq(taxonId * 1000 + 10, by = 30, length.out = 30)
    lapply(seq_along(ids), function(i) {
      lic <- c("cc-by", "cc-by-nc", "cc0")[(i %% 3) + 1]
      photos <- list(list(id = ids[i] * 10 + 1, license_code = if (i %% 7 == 0) NULL else lic,
                          url = sprintf("https://photos.example/photos/%d/square.jpg", ids[i] * 10 + 1),
                          attribution = sprintf("(c) observer %d, some rights reserved", i %% 10)),
                     list(id = ids[i] * 10 + 2, license_code = "cc-by",
                          url = sprintf("https://photos.example/photos/%d/square.jpeg", ids[i] * 10 + 2),
                          attribution = "(c) someone, some rights reserved (CC BY)"))
      list(id = ids[i], observed_on = sprintf("2020-%02d-15", (i %% 12) + 1), user = list(id = i %% 10),
           taxon = list(id = taxonId, name = taxa[[match(taxonId, c(11, 12, 22))]]$name), photos = photos)
    })
  }
  fetch <- function(url, query) {
    calls$log[[length(calls$log) + 1]] <- list(url = url, query = query)
    what <- sub("^https://api.inaturalist.org/v1/", "", url)
    if (what == "taxa") {
      return(list(results = Filter(function(t) grepl(tolower(query$q), tolower(t$name), fixed = TRUE), rev(taxa))))
    }
    if (startsWith(what, "taxa/")) {
      return(list(results = Filter(function(t) t$id == as.numeric(sub("taxa/", "", what)), taxa)))
    }
    if (what == "places/autocomplete") {
      return(list(results = list(list(id = 7, name = "Montana", display_name = "Montana, US"),
                                 list(id = 8, name = "Montana City", display_name = "Montana City, MT, US"))))
    }
    if (is.null(query$taxon_id)) return(list(results = list(list(id = 99999))))
    obs <- obsOf(query$taxon_id)
    obs <- Filter(function(o) o$id < as.numeric(query$id_below), obs)
    obs <- obs[order(-vapply(obs, function(o) o$id, numeric(1)))]
    list(results = utils::head(obs, query$per_page))
  }
  download <- function(url, destfile) {
    calls$downloads <- c(calls$downloads, url)
    if (grepl("FAIL", url)) stop("HTTP 404")
    fakePhoto(destfile, url)
  }
  list(fetch = fetch, download = download, calls = calls)
}

test_that("inatPhotos draws a balanced, reproducible sample and writes a manifest", {
  api <- fakeInat()
  dir <- withr::local_tempdir()
  taxa <- c("Quaking aspen (Populus tremuloides)", "Acer negundo")
  m <- inatPhotos(taxa, n = 5, dir = dir, fetch = api$fetch, download = api$download, pause = 0)
  expect_equal(as.vector(table(m$taxon)[taxa]), c(5L, 5L))
  expect_named(m, c("taxon", "scientific_name", "taxon_id", "observation_id", "photo_id", "license", "attribution", "url",
                    "observation_url", "observed_on", "file", "quality_grade", "place_id", "id_below", "retrieved", "path"))
  expect_equal(unique(m$scientific_name), c("Populus tremuloides", "Acer negundo"))
  expect_equal(unique(m$taxon_id), c(11, 22))                  # the exact name, not "Populus tremula"
  expect_true(all(m$license %in% c("cc0", "cc-by", "cc-by-nc")))
  expect_equal(anyDuplicated(m$observation_id), 0L)            # one photo per observation
  expect_true(all(grepl("/medium\\.jpe?g$", m$url)))
  expect_equal(m$observation_url, paste0("https://www.inaturalist.org/observations/", m$observation_id))
  expect_true(all(m$id_below == 1e5))                          # newest id + 1, recorded for next time
  expect_equal(m$file[1], file.path("populus_tremuloides", sprintf("%d_%d.jpg", m$observation_id[1], m$photo_id[1])))
  expect_true(all(file.exists(m$path)))
  # at most one observation per observer and species
  who <- sub("^\\(c\\) (observer \\d+|someone).*$", "\\1", m$attribution)
  expect_equal(max(table(m$taxon, who)[, setdiff(unique(who), "someone"), drop = FALSE]), 1L)

  # the manifest on disk is the same, without this computer's paths
  disk <- utils::read.csv(file.path(dir, "manifest.csv"), stringsAsFactors = FALSE)
  expect_equal(names(disk), setdiff(names(m), "path"))
  expect_equal(disk$observation_id, m$observation_id)
  expect_equal(disk$attribution, m$attribution)

  # what was asked of the API
  q <- Filter(function(c) !is.null(c$query$taxon_id), api$calls$log)
  expect_length(q, 20)                                         # ten slices of the id range for each species
  expect_equal(q[[1]]$query$quality_grade, "research")
  expect_equal(q[[1]]$query$photo_license, "cc0,cc-by,cc-by-nc")
  expect_equal(q[[1]]$query$order_by, "id")
  expect_equal(q[[1]]$query$photos, "true")
  expect_equal(q[[1]]$query$per_page, 20)
  expect_equal(vapply(q[1:10], function(c) c$query$id_below, ""), format(1e4 * (10:1), scientific = FALSE, trim = TRUE))
  expect_null(q[[1]]$query$place_id)
  expect_true(all(startsWith(api$calls$downloads, "https://photos.example/photos/")))

  # the same arguments give the same sample, and photos already there are not fetched again
  n <- length(api$calls$downloads)
  again <- inatPhotos(taxa, n = 5, dir = dir, fetch = api$fetch, download = api$download, pause = 0, idBelow = m$id_below[1])
  expect_equal(again$observation_id, m$observation_id)
  expect_length(api$calls$downloads, n)
  other <- inatPhotos(taxa, n = 5, dir = dir, fetch = api$fetch, download = api$download, pause = 0, seed = 2)
  expect_false(identical(other$observation_id, m$observation_id))
  # an earlier snapshot only sees older observations
  early <- inatPhotos(taxa[1], n = 3, dir = dir, fetch = api$fetch, download = api$download, pause = 0, idBelow = 11300)
  expect_true(all(early$observation_id < 11300))
})

test_that("inatPhotos honours licences, places, extra parameters and the per-observer limit", {
  api <- fakeInat()
  dir <- withr::local_tempdir()
  expect_warning(expect_message(
    m <- inatPhotos(c(aspen = 11), n = 30, dir = dir, fetch = api$fetch, download = api$download, pause = 0,
                    licenses = "cc0", place = "Montana", size = "large", perObserver = Inf, photosPerObservation = 2,
                    query = list(month = "6,7,8")),
    "Montana, US \\(iNaturalist place 7\\)"), "Only 6 of 30 observations found for aspen")
  # the pool is the 20 newest observations; 6 of them have a cc0 photo. The
  # second photo of each observation is cc-by and is left out.
  expect_true(all(m$license == "cc0"))
  expect_equal(nrow(m), 6)
  expect_equal(unique(m$taxon), "aspen")
  expect_equal(unique(m$scientific_name), "Populus tremuloides")   # asked of the API, as only an id was given
  expect_equal(unique(dirname(m$file)), "populus_tremuloides")
  expect_equal(unique(m$place_id), 7)
  expect_true(all(grepl("/large\\.jpg$", m$url)))
  q <- Filter(function(c) !is.null(c$query$taxon_id), api$calls$log)[[1]]$query
  expect_equal(q$place_id, 7)
  expect_equal(q$month, "6,7,8")
  expect_equal(q$photo_license, "cc0")
  expect_false(any(vapply(api$calls$log, function(c) grepl("/taxa$", c$url), logical(1))))   # no name to search for
  expect_equal(sum(vapply(api$calls$log, function(c) grepl("/taxa/11$", c$url), logical(1))), 1)

  # with a limit of one per observer, ten observers give at most ten observations
  suppressWarnings(m1 <- inatPhotos(c(aspen = 11), n = 30, dir = dir, fetch = api$fetch, download = api$download, pause = 0))
  expect_lte(nrow(m1), 10)
  m2 <- inatPhotos(c(aspen = 11), n = 12, dir = dir, fetch = api$fetch, download = api$download, pause = 0,
                   perObserver = 2, photosPerObservation = 2)
  expect_equal(length(unique(m2$observation_id)), 12)
  expect_gt(nrow(m2), 12)                                      # two photos from most observations
})

test_that("inatPhotos reports what it cannot find or download", {
  api <- fakeInat()
  dir <- withr::local_tempdir()
  expect_warning(m <- inatPhotos(c("Acer negundo", "Quercus nonexistens"), n = 2, dir = dir, fetch = api$fetch,
                                 download = api$download, pause = 0), "no taxon named Quercus nonexistens")
  expect_equal(unique(m$taxon), "Acer negundo")
  expect_error(suppressWarnings(inatPhotos("Quercus nonexistens", n = 2, dir = dir, fetch = api$fetch, download = api$download, pause = 0)),
               "No photos found")
  broken <- function(url, destfile) if (grepl("/22", url)) stop("HTTP 404") else fakePhoto(destfile)
  dir2 <- withr::local_tempdir()
  w <- character()
  m <- withCallingHandlers(
    inatPhotos(c("Populus tremuloides", "Acer negundo"), n = 2, dir = dir2, fetch = api$fetch, download = broken, pause = 0),
    warning = function(e) { w <<- c(w, conditionMessage(e)); invokeRestart("muffleWarning") })
  expect_length(w, 2)
  expect_match(w[1], "Could not download .*: HTTP 404")
  expect_equal(unique(m$taxon), "Populus tremuloides")
  expect_equal(nrow(utils::read.csv(file.path(dir2, "manifest.csv"))), 2)
  expect_error(inatPhotos(c("a", "a"), dir = dir, fetch = api$fetch, download = api$download), "once")
  expect_error(inatPhotos("a", fetch = api$fetch), "dir")
  expect_error(inatPhotos("Acer negundo", dir = dir, fetch = function(url, query) "<html>", download = api$download, pause = 0), "not JSON")
})

test_that("inatPhotos keeps to the pause between requests", {
  api <- fakeInat()
  dir <- withr::local_tempdir()
  t0 <- Sys.time()
  inatPhotos(c(maple = 22), n = 1, dir = dir, fetch = api$fetch, download = api$download, pause = 0.05, strata = 3, idBelow = 1e5)
  # the taxon's name, three searches and one download: four gaps of at least 0.05 s
  expect_gte(as.numeric(difftime(Sys.time(), t0, units = "secs")), 0.2)
})

test_that("splitByObservation never divides an observation", {
  obs <- rep(1:40, each = 2)
  label <- rep(c("a", "b", "c", "d"), each = 20)
  s <- splitByObservation(obs, label, test = 0.3)
  expect_setequal(s, c("train", "test"))
  expect_length(intersect(obs[s == "train"], obs[s == "test"]), 0)
  expect_equal(as.vector(table(label, s)[, "test"]), rep(6L, 4))   # 3 of 10 observations, 2 photos each
  expect_identical(s, splitByObservation(obs, label, test = 0.3))
  expect_false(identical(s, splitByObservation(obs, label, test = 0.3, seed = 2)))
  expect_equal(unique(splitByObservation(obs, label, test = 1)), "test")
  expect_equal(unique(splitByObservation(obs, label, test = 0)), "train")
  # two observations: one each side; a single observation is trained on
  two <- splitByObservation(c(1, 1, 2), c("a", "a", "a"), test = 0.01)
  expect_setequal(two, c("train", "test"))
  expect_equal(two[1], two[2])
  expect_setequal(splitByObservation(c(1, 2), c("a", "a"), test = 0.99), c("train", "test"))
  expect_equal(splitByObservation(c(1, 1), c("a", "a"), test = 0.5), c("train", "train"))
  expect_error(splitByObservation(1:3, c("a", "b")), "one entry per photo")
  expect_error(splitByObservation(1:2, c("a", "b"), test = 2), "between 0 and 1")
})

# Photos of the synthetic set, as a manifest: label L1 is "Species one (Genus1 one)"
# and so on, and photos 2 and 3 of each label share an observation.
benchFixture <- function(n_labels = 6) {
  fv <- fakeVisionModel(syntheticVision(n_labels = n_labels, per_label = 4, k = 4, p = 9, d = 8))
  im <- fv$sv$images
  num <- as.integer(sub("^L", "", im$label))
  taxa <- sprintf("Species %s (Genus%d %s)", letters[seq_len(n_labels)], (seq_len(n_labels) + 1) %/% 2, letters[seq_len(n_labels)])
  shot <- as.integer(ifelse(grepl("_", im$id), sub("^.*_", "", im$id), "1"))
  photos <- data.frame(id = im$id, path = im$path, label = taxa[num], observation = num * 100 + pmin(shot, 3) - (shot == 3),
                       stringsAsFactors = FALSE)
  leads <- data.frame(Statement = as.character(seq_len(n_labels - 1)), Choice = "a", Character = paste("is", seq_len(n_labels - 1)),
                      Next = "-", Taxon = taxa[-n_labels], stringsAsFactors = FALSE)
  other <- transform(leads, Choice = "b", Character = paste("is not", seq_len(n_labels - 1)),
                     Next = c(as.character(2:(n_labels - 1)), "-"), Taxon = c(rep("", n_labels - 2), taxa[n_labels]))
  key <- keyFromLeads(rbind(leads, other)[order(rep(seq_len(n_labels - 1), 2)), ], "A key to six made-up species")
  # a text side that knows the species: the name of label i embeds as the mean of its photos
  fv$model$mod$embed_texts <- function(py, texts) {
    which <- vapply(unlist(texts), function(t) which(vapply(taxa, function(x) grepl(scientificPart(x), t, fixed = TRUE), logical(1)))[1], 1L)
    m <- t(vapply(which, function(i) colMeans(fv$sv$image[im$label == paste0("L", i), , drop = FALSE]), numeric(ncol(fv$sv$image))))
    unname(m / sqrt(rowSums(m^2)))
  }
  list(fv = fv, photos = photos, key = key, taxa = taxa)
}

test_that("the names route ranks the key's species and reports top-1, top-k and per-species accuracy", {
  f <- benchFixture()
  b <- benchmarkKey(f$key, f$photos, f$fv$model, top = 3)
  expect_s3_class(b, "dimooseBenchmark")
  expect_equal(b$route, "names")                               # the key has no machine tests
  expect_equal(b$n, 24); expect_equal(b$nTrain, 0)
  expect_equal(b$observations, 18)
  expect_named(b$topK, c("top1", "top2", "top3"))
  expect_true(all(diff(b$topK) >= 0))
  expect_equal(unname(b$topK["top1"]), b$accuracy)
  expect_named(b$results, c("id", "observation", "actual", "predicted", "rank", "correct"))
  expect_equal(b$results$correct, b$results$rank == 1)
  expect_named(b$perSpecies, c("Taxon", "n", "top1", "top3"))
  expect_equal(b$perSpecies$n, rep(4L, 6))
  expect_equal(sum(b$confusion), 24)
  expect_equal(sum(diag(b$confusion[, rownames(b$confusion)[rownames(b$confusion) %in% colnames(b$confusion)], drop = FALSE])) / 24,
               b$accuracy, tolerance = 1e-9)
  # it is suggestSpecies() underneath
  s <- suggestSpecies(f$key, f$fv$model, f$photos[, c("id", "path")], top = 1)
  expect_equal(b$results$predicted, s$Taxon)
  expect_equal(b$accuracy, mean(s$Taxon == f$photos$label))
  expect_gt(b$accuracy, 0.5)                                   # the text side was given the answers
  expect_output(print.dimooseBenchmark(b), "24 test photos of 6 species from 18 observations")
  expect_output(print.dimooseBenchmark(b), "top-1 .*%, top-2 .*%, top-3 ")

  # labels may be bare scientific names; a species the key lacks is an error
  bare <- transform(f$photos, label = scientificPart(label))
  expect_equal(benchmarkKey(f$key, bare, f$fv$model)$results$actual, f$photos$label)
  expect_error(benchmarkKey(f$key, transform(f$photos, label = "Ulmus rubra"), f$fv$model), "does not end in: Ulmus rubra")
})

test_that("a split, a manifest file and a lineage are honoured on the names route", {
  f <- benchFixture()
  split <- splitByObservation(f$photos$observation, f$photos$label, test = 0.34)
  b <- benchmarkKey(f$key, f$photos, f$fv$model, split = split)
  expect_equal(b$n, sum(split == "test"))
  expect_equal(b$results$id, f$photos$id[split == "test"])
  expect_equal(benchmarkKey(f$key, f$photos, f$fv$model, test = 0.34)$results$id, b$results$id)
  leaky <- split; leaky[f$photos$id == "L1_2"] <- "train"; leaky[f$photos$id == "L1_3"] <- "test"
  expect_error(benchmarkKey(f$key, f$photos, f$fv$model, split = leaky), "one observation on both sides")
  expect_error(benchmarkKey(f$key, f$photos, f$fv$model, split = "test"), "for each photo")

  # a manifest as inatPhotos() writes it: taxon, observation_id and file, relative to dir
  dir <- withr::local_tempdir()
  man <- data.frame(taxon = f$photos$label, observation_id = f$photos$observation, file = file.path("x", basename(f$photos$path)),
                    observation_url = "https://www.inaturalist.org/observations/1", id_below = 99)   # not an id, nor an observation
  utils::write.csv(man, file.path(dir, "manifest.csv"), row.names = FALSE)
  bm <- benchmarkKey(f$key, file.path(dir, "manifest.csv"), f$fv$model)
  expect_equal(bm$results$id, f$photos$id)
  expect_equal(bm$results$observation, as.character(f$photos$observation))
  expect_equal(basename(dirname(utils::tail(f$fv$calls$embed_images, 1)[[1]]$paths[1])), "x")
  expect_equal(bm$results$predicted, benchmarkKey(f$key, f$photos, f$fv$model)$results$predicted)

  lineage <- data.frame(Taxon = f$taxa, genus = paste0("Genus", c(1, 1, 2, 2, 3, 3)), family = "Fam", order = "Ord")
  bl <- benchmarkKey(f$key, f$photos, f$fv$model, lineage = lineage, confidence = 0.999)
  ans <- bl$identify$results
  expect_equal(nrow(ans), 24)
  expect_true(all(ans$confident))                              # everything is in order "Ord", if nothing else
  manual <- ifelse(ans$rank == "species", ans$Taxon == ans$actual,
                   ifelse(ans$rank == "genus", ans$name == lineage$genus[match(ans$actual, lineage$Taxon)], TRUE))
  expect_equal(ans$correct, manual)
  expect_equal(bl$identify$correct, mean(manual))
  expect_gte(bl$identify$correct, bl$accuracy)                 # falling back to a higher rank cannot cost accuracy here
  expect_output(print.dimooseBenchmark(bl), "identifyPhotos: 100.0% of answers confident")
})

test_that("the build route learns a key from the training observations only", {
  f <- benchFixture()
  n0 <- length(f$fv$calls$embed_images)
  b <- benchmarkKey(f$fv$model, f$photos, k = 4, seed = 1)
  expect_equal(b$route, "build")
  expect_setequal(b$split, c("train", "test"))
  expect_length(intersect(f$photos$observation[b$split == "train"], f$photos$observation[b$split == "test"]), 0)
  expect_equal(b$n + b$nTrain, 24)
  expect_equal(b$n, sum(b$split == "test"))
  expect_s3_class(b$key, "dimoose")
  expect_length(b$key$validate(), 0)
  expect_named(b$topK, "top1")
  expect_equal(names(b$perSpecies), c("Taxon", "n", "top1"))
  expect_equal(sum(b$confusion), b$n)
  expect_length(f$fv$calls$embed_images, n0 + 1)               # every photo embedded once
  # the same numbers by hand: sniglets from the training patches, the key from the training scores
  pt <- f$fv$sv$patches
  train <- b$split == "train"
  sn <- discoverSniglets(pt[train, , , drop = FALSE], k = 4, seed = 1)
  sc <- snigletScores(pt, sn$centroids)
  key <- keyFromSniglets(sc[train, ], f$fv$sv$images[train, ] |> transform(label = f$photos$label[train]), sn, method = "rpart")
  ev <- evaluateKey(key, sc[!train, , drop = FALSE], f$photos$label[!train])
  expect_equal(b$accuracy, ev$accuracy)
  expect_equal(b$results$predicted, ev$results$predicted)
  expect_gt(b$accuracy, 0.5)                                   # the synthetic classes are separable
  # embeddings given: no model needed, nothing embedded
  emb <- list(image = f$fv$sv$image, patches = f$fv$sv$patches)
  b2 <- benchmarkKey(f$fv$model, f$photos, k = 4, embeddings = emb)
  expect_equal(b2$results, b$results)
  expect_length(f$fv$calls$embed_images, n0 + 1)
  expect_error(benchmarkKey(f$fv$model, f$photos, test = 1), "no training photos")
  expect_error(benchmarkKey(f$fv$model, f$photos, route = "names"), "needs a key")
  expect_error(benchmarkKey("key", f$photos), "dimoose key or a vision model")
  expect_error(benchmarkKey(f$key, f$photos), "Give `model`")
})

test_that("the key route follows a key with machine tests for the test photos", {
  f <- benchFixture()
  built <- benchmarkKey(f$fv$model, f$photos, k = 4)
  b <- suppressWarnings(benchmarkKey(built$key, f$photos, f$fv$model, split = built$split))
  expect_equal(b$route, "key")                                 # chosen because the key has machine tests
  expect_equal(b$results$predicted, built$results$predicted)   # scoreImages() gives the scores the key was built on
  expect_equal(b$accuracy, built$accuracy)
  # a species the key never ends in is not an error here: its photos are just never right
  short <- f$photos; short$label[short$label == f$taxa[1]] <- "Species z (Genus9 z)"
  expect_warning(bz <- benchmarkKey(built$key, short, f$fv$model), "does not end in: Species z")
  expect_equal(bz$perSpecies$top1[bz$perSpecies$Taxon == "Species z (Genus9 z)"], 0)
  all <- suppressWarnings(benchmarkKey(built$key, f$photos, f$fv$model))
  expect_equal(all$n, 24)                                      # nothing is learned, so every photo is a test
  ev <- evaluateKey(built$key, scoreImages(built$key, f$fv$model, f$photos[, c("id", "path")]), f$photos$label)
  expect_equal(all$accuracy, ev$accuracy)
  # the same counts as evaluateKey()'s table, laid out with every species down and across
  for (a in rownames(ev$confusion)) for (p in colnames(ev$confusion)) {
    expect_equal(all$confusion[a, p], ev$confusion[a, p], info = paste(a, p))
  }
  expect_equal(sum(all$confusion), sum(ev$confusion))
})

test_that("photos need paths, labels and distinct ids", {
  expect_error(benchPhotos(data.frame(path = "a.jpg")), "label")
  expect_error(benchPhotos(data.frame(label = "a", file = "a.jpg")), "`file` column and `dir`")
  expect_error(benchPhotos(data.frame(label = "a", path = c("x/a.jpg", "y/a.jpg"))), "distinct ids")
  expect_error(benchPhotos("no-such-manifest.csv"), "not found")
  p <- benchPhotos(data.frame(taxon = "a", file = "s/1_2.jpg", observation_id = 123456789012), dir = "/photos")
  expect_equal(p, data.frame(id = "1_2", path = "/photos/s/1_2.jpg", label = "a", observation = "123456789012"))
  expect_equal(benchPhotos(data.frame(label = "a", path = c("a.jpg", "b.jpg")))$observation, c("a", "b"))
})

# ---- regression tests from the review

test_that("a name resolves to the taxon of exactly that name, and homonyms are reported", {
  # what /v1/taxa?q=Oenanthe answers: a tribe first, then a bird genus, a species and a plant genus
  found <- list(list(id = 790586, name = "Oenantheae", rank = "tribe", iconic_taxon_name = "Plantae", observations_count = 158416, matched_term = "Oenantheae"),
                list(id = 60128, name = "Oenanthe", rank = "genus", iconic_taxon_name = "Plantae", observations_count = 36006, matched_term = "Oenanthe"),
                list(id = 12822, name = "Oenanthe oenanthe", rank = "species", iconic_taxon_name = "Aves", observations_count = 53236),
                list(id = 980200, name = "Oenanthe", rank = "genus", iconic_taxon_name = "Aves", observations_count = 94163, matched_term = "Oenanthe"))
  expect_warning(hit <- benchPickTaxon("Oenanthe", found),
                 "name of 2 iNaturalist taxa: genus Oenanthe in Aves \\(id 980200\\); genus Oenanthe in Plantae \\(id 60128\\)")
  expect_equal(hit$id, 980200)                                 # the most observed, and said so
  expect_equal(benchPickTaxon("oenanthe OENANTHE", found)$id, 12822)
  expect_null(benchPickTaxon("Oenanth", found))                # never the search's loose first result
  # a binomial means the species, not a section or a hybrid that carries the same words
  found <- list(list(id = 1, name = "Acer negundo", rank = "section", observations_count = 9e5),
                list(id = 47726, name = "Acer negundo", rank = "species", observations_count = 2e5))
  expect_equal(suppressWarnings(benchPickTaxon("Acer negundo", found))$id, 47726)
  # a synonym is followed to the taxon it now belongs to
  found <- list(list(id = 504005, name = "Populus × hastata", rank = "hybrid", matched_term = "Populus balsamifera × trichocarpa"),
                list(id = 78699, name = "Populus trichocarpa", rank = "species", iconic_taxon_name = "Plantae", matched_term = "Populus balsamifera trichocarpa"))
  expect_message(hit <- benchPickTaxon("Populus balsamifera trichocarpa", found), "known to iNaturalist as species Populus trichocarpa in Plantae \\(id 78699\\)")
  expect_equal(hit$id, 78699)
  expect_null(benchPickTaxon("Acer negundo", list()))
  expect_null(benchPickTaxon("Acer negundo", list(list(id = 5, name = "Acer negundo", is_active = FALSE))))

  # through inatPhotos(): the homonym's warning reaches the caller and the id used is in the manifest
  api <- fakeInat()
  fetch <- function(url, query) {
    if (endsWith(url, "/taxa")) return(list(results = list(list(id = 12, name = "Populus tremula", rank = "species", observations_count = 5),
                                                             list(id = 11, name = "Populus tremula", rank = "species", observations_count = 50))))
    api$fetch(url, query)
  }
  dir <- withr::local_tempdir()
  expect_warning(m <- inatPhotos("Populus tremula", n = 2, dir = dir, fetch = fetch, download = api$download, pause = 0), "name of 2 iNaturalist taxa")
  expect_equal(unique(m$taxon_id), 11)
})

test_that("a download that is not an image is left out, and a broken file from before is fetched again", {
  api <- fakeInat()
  dir <- withr::local_tempdir()
  m <- inatPhotos("Acer negundo", n = 3, dir = dir, fetch = api$fetch, download = api$download, pause = 0, idBelow = 1e5)
  n <- length(api$calls$downloads)
  writeLines("<html>Service unavailable</html>", m$path[2])    # what an interrupted or refused download leaves
  again <- inatPhotos("Acer negundo", n = 3, dir = dir, fetch = api$fetch, download = api$download, pause = 0, idBelow = 1e5)
  expect_length(api$calls$downloads, n + 1)
  expect_equal(imageMime(m$path[2]), "image/png")
  expect_equal(again$file, m$file)
  # a server that answers 200 with a page instead of a photo
  page <- function(url, destfile) if (grepl("/22", url)) writeLines("<html>", destfile) else api$download(url, destfile)
  dir2 <- withr::local_tempdir()
  expect_warning(m2 <- inatPhotos(c("Populus tremuloides", "Acer negundo"), n = 1, dir = dir2, fetch = api$fetch, download = page, pause = 0),
                 "not an image")
  expect_equal(unique(m2$taxon), "Populus tremuloides")
  expect_length(list.files(file.path(dir2, "acer_negundo")), 0)
  expect_error(inatPhotos("Acer negundo", n = 0, dir = dir, fetch = api$fetch, download = api$download), "`n`")
  expect_error(inatPhotos(c(NA, "Acer negundo"), dir = dir, fetch = api$fetch, download = api$download), "once")
  expect_error(inatPhotos(c(a = 1.5), dir = dir, fetch = api$fetch, download = api$download), "whole numbers")
})

test_that("splitByObservation keeps odd observations whole too", {
  # photos without an observation are each their own, not one big observation
  s <- splitByObservation(c(NA, NA, NA, NA, NA, NA), rep("oak", 6), test = 0.5)
  expect_equal(sum(s == "test"), 3)
  # an observation with photos in two classes never ends up on both sides
  obs <- c(1, 1, 2, 3, 4, 5, 6, 7, 8, 9)
  lab <- c("oak", "elm", "oak", "oak", "oak", "oak", "elm", "elm", "elm", "elm")
  for (seed in 1:30) {
    s <- splitByObservation(obs, lab, test = 0.5, seed = seed)
    expect_length(intersect(obs[s == "train"], obs[s == "test"]), 0)
  }
  # factors, numbers too large for a float to print in full, one row, none
  expect_equal(splitByObservation(factor(c("a", "a", "b")), factor(c("x", "x", "x")), test = 0.5)[1:2] |> unique() |> length(), 1L)
  big <- splitByObservation(c(123456789012345, 123456789012345, 123456789012346), rep("x", 3), test = 0.5)
  expect_equal(big[1], big[2]); expect_false(big[3] == big[1])
  expect_equal(splitByObservation(1, "x"), "train")
  expect_equal(splitByObservation(numeric(), character()), character())
  expect_error(splitByObservation(1:2, c("x", NA)), "label")
  # the same seed gives the same split, whatever the order the photos come in
  o <- rep(1:20, each = 2); l <- rep(c("x", "y"), each = 20)
  s1 <- splitByObservation(o, l, seed = 3); idx <- rev(seq_along(o))
  expect_equal(splitByObservation(o[idx], l[idx], seed = 3), s1[idx])
  p <- benchPhotos(data.frame(label = "a", path = c("a.jpg", "b.jpg", "c.jpg"), observation = c(NA, NA, 7)))
  expect_equal(p$observation, c("photo a", "photo b", "7"))
  expect_error(benchPhotos(data.frame(label = c("a", NA), path = c("a.jpg", "b.jpg"))), "label and a path")
})

test_that("the tables add up: every species has a row, margins match and the interval is Wilson's", {
  f <- benchFixture()
  # species 1 has a single observation, so all of it goes to training and none is tested
  photos <- f$photos
  photos$observation[photos$label == f$taxa[1]] <- "one"
  b <- benchmarkKey(f$key, photos, f$fv$model, test = 0.5, top = 2)
  expect_equal(b$perSpecies$Taxon, sort(f$taxa))
  first <- b$perSpecies[b$perSpecies$Taxon == f$taxa[1], ]
  expect_equal(first$n, 0L)
  expect_true(is.na(first$top1) && is.na(first$top2))          # no test photos is no accuracy, not 0 and not NaN
  expect_false(any(is.nan(unlist(b$perSpecies[, -1]))))
  expect_equal(sum(b$perSpecies$n), b$n)
  expect_equal(sum(b$perSpecies$n * b$perSpecies$top1, na.rm = TRUE) / b$n, b$accuracy)
  # the confusion table: square in the species, rows are what was tested, columns what was answered
  expect_equal(rownames(b$confusion), sort(f$taxa))
  expect_equal(colnames(b$confusion)[seq_along(f$taxa)], sort(f$taxa))
  expect_equal(as.vector(rowSums(b$confusion)), b$perSpecies$n)
  expect_equal(as.vector(colSums(b$confusion)[sort(f$taxa)]), as.vector(table(factor(b$results$predicted, sort(f$taxa)))))
  expect_equal(sum(b$confusion), b$n)
  expect_equal(sum(diag(b$confusion[, sort(f$taxa)])), sum(b$results$correct))
  expect_output(print.dimooseBenchmark(b), "no test photos of: Species a")
  expect_output(print.dimooseBenchmark(b), "test photos of 5 species")

  # top-k by hand from the ranks
  for (kk in 1:2) expect_equal(b$topK[[kk]], mean(b$results$rank <= kk))
  expect_true(all(b$perSpecies$top2 >= b$perSpecies$top1, na.rm = TRUE))

  # Wilson's interval against stats::prop.test (which gives it without the continuity correction)
  for (case in list(c(47, 66), c(214, 220), c(0, 6), c(6, 6), c(1, 1))) {
    ref <- suppressWarnings(stats::prop.test(case[1], case[2], correct = FALSE))$conf.int
    expect_equal(unname(benchWilson(case[1], case[2])), as.vector(ref), tolerance = 1e-8)
  }
  expect_true(all(is.na(benchWilson(0, 0))))
  expect_equal(unname(b$interval), unname(benchWilson(sum(b$results$correct), b$n)))
  expect_output(print.dimooseBenchmark(b), "95% interval")
})

test_that("repeated splits report every split, their mean and their spread", {
  f <- benchFixture()
  n0 <- length(f$fv$calls$embed_images)
  b <- benchmarkKey(f$fv$model, f$photos, k = 4, seed = 5, reps = 4)
  expect_length(f$fv$calls$embed_images, n0 + 1)               # embedded once, not once per split
  expect_equal(b$repeats$seed, 5:8)
  expect_named(b$repeats, c("rep", "seed", "n", "nTrain", "correct", "accuracy"))
  # each row is the single run with that seed, and the object itself is the first
  singles <- lapply(5:8, function(s) benchmarkKey(f$fv$model, f$photos, k = 4, seed = s))
  expect_equal(b$repeats$accuracy, vapply(singles, function(x) x$accuracy, numeric(1)))
  expect_equal(b$repeats$correct / b$repeats$n, b$repeats$accuracy)
  expect_equal(b$results, singles[[1]]$results)
  expect_equal(b$split, singles[[1]]$split)
  expect_equal(b$accuracyMean, mean(b$repeats$accuracy))
  expect_equal(b$accuracySd, stats::sd(b$repeats$accuracy))
  expect_equal(b$accuracyRange, range(b$repeats$accuracy))
  # no split divides an observation, and the splits differ
  splits <- lapply(singles, `[[`, "split")
  for (s in splits) expect_length(intersect(f$photos$observation[s == "train"], f$photos$observation[s == "test"]), 0)
  expect_gt(length(unique(vapply(splits, paste, "", collapse = ""))), 1)
  # per species over all splits' test photos
  all <- do.call(rbind, lapply(singles, `[[`, "results"))
  expect_equal(b$perSpecies$top1Mean, as.vector(tapply(all$correct, factor(all$actual, b$perSpecies$Taxon), mean)))
  expect_output(print.dimooseBenchmark(b), "4 splits \\(seeds 5 to 8\\): top-1 mean")

  # the names route can be repeated when part is held out; with everything tested a repeat is a copy
  bn <- benchmarkKey(f$key, f$photos, f$fv$model, test = 0.34, reps = 2)
  expect_equal(nrow(bn$repeats), 2)
  expect_error(benchmarkKey(f$key, f$photos, f$fv$model, reps = 2), "each repeat is the same")
  expect_error(benchmarkKey(f$fv$model, f$photos, reps = 2, split = b$split), "`split` cannot be given")
  expect_error(benchmarkKey(f$fv$model, f$photos, reps = 0), "`reps`")
  expect_error(benchmarkKey(f$fv$model, f$photos, k = 4, reps = 1.5), "whole number")   # not one split passed off as a repeat
  expect_null(benchmarkKey(f$fv$model, f$photos, k = 4)$repeats)
})
