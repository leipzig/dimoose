# Benchmark on field photos: the eleven native broadleaf trees of Montana
# (montanaKey()), about 20 research-grade iNaturalist observations each,
# identified with BioCLIP 2. Run from the package root:
#
#   Rscript analysis/inat-benchmark/run.R              # the sample in manifest.csv
#   Rscript analysis/inat-benchmark/run.R --resample   # draw a new sample from iNaturalist
#   Rscript analysis/inat-benchmark/run.R --seed=2     # another split (and other sniglets) of the same photos;
#                                                      # results go to seed-2/, not over the ones here
#
# It needs the network (iNaturalist, and the Hugging Face Hub the first time
# the model is used) and dimoose's Python environment (see ?visionModel).
#
# The photos are kept OUTSIDE the repository, in R's user cache folder; only
# the manifest (which observation and photo, whose, under which licence) and
# the results are written here. With a manifest.csv present the same photos
# are used again (and downloaded again if the cache is empty).
#
# Three things are measured:
#   names   BioCLIP 2 ranks the key's eleven species for each photo from their
#           scientific names (suggestSpecies / identifyPhotos). Nothing is
#           learned from the photos, so every photo is a test photo.
#   build   A photo key is built from 70% of each species' observations
#           (sniglets + rpart) and followed by machine for the other 30%.
#   names on the build route's test photos, for a like-for-like comparison.
# The build route is then repeated over ten splits (seeds seed, ..., seed + 9)
# to show how much one split of 66 test photos can mislead.
suppressMessages(if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) pkgload::load_all(".", quiet = TRUE) else library(dimoose))
args <- commandArgs(TRUE)
here <- "analysis/inat-benchmark"
cache <- file.path(tools::R_user_dir("dimoose", "cache"), "inat-benchmark")
perSpecies <- 20
seed <- 1
given <- grep("^--seed=", args, value = TRUE)
if (length(given)) seed <- as.integer(sub("^--seed=", "", given[1]))
if (is.na(seed)) stop("--seed= needs a whole number")
repeats <- 10
modelName <- "bioclip-2"
started <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")

key <- montanaKey()
manifestFile <- file.path(here, "manifest.csv")
# results of the first seed sit beside the script; any other seed gets a folder of its own
out <- if (seed == 1) here else file.path(here, paste0("seed-", seed))
dir.create(out, showWarnings = FALSE)
if (file.exists(manifestFile) && !"--resample" %in% args) {
  manifest <- read.csv(manifestFile, stringsAsFactors = FALSE)
  manifest$path <- file.path(cache, manifest$file)
  ua <- httr::user_agent("R httr client sampling photos for an identification benchmark")
  for (r in which(!file.exists(manifest$path))) {
    dir.create(dirname(manifest$path[r]), recursive = TRUE, showWarnings = FALSE)
    Sys.sleep(1)
    httr::stop_for_status(httr::GET(manifest$url[r], httr::write_disk(manifest$path[r], overwrite = TRUE), ua, httr::timeout(120)))
  }
  cat("using the", nrow(manifest), "photos listed in", manifestFile, "\n")
} else {
  manifest <- inatPhotos(key, n = perSpecies, dir = cache, seed = seed)
  write.csv(manifest[, setdiff(names(manifest), "path")], manifestFile, row.names = FALSE)
  cat("drew", nrow(manifest), "photos from iNaturalist; manifest written to", manifestFile, "\n")
}
print(table(manifest$taxon))

model <- visionModel(name = modelName)
print(model)

# the genus, family and order of each species, for identifyPhotos' fall-back (GBIF)
lineage <- tryCatch(checkNames(key, kingdom = "Plantae"), error = function(e) { message("no lineage: ", conditionMessage(e)); NULL })
if (!is.null(lineage) && !all(c("genus", "family", "order") %in% names(lineage))) lineage <- NULL

t0 <- Sys.time()
byName <- benchmarkKey(key, manifest, model, route = "names", top = 3, lineage = lineage)
cat("\nnames route (", format(round(Sys.time() - t0, 1)), ")\n", sep = ""); print(byName)

# the build route over `repeats` splits; the photos are embedded once. `built` is the first split (seed `seed`).
t0 <- Sys.time()
built <- benchmarkKey(model, manifest, test = 0.3, seed = seed, k = 40, tiles = 4, method = "rpart", reps = repeats)
cat("\nbuild route (", format(round(Sys.time() - t0, 1)), ")\n", sep = ""); print(built)

# the names route on the build route's test photos only
same <- byName$results[byName$results$id %in% built$results$id, ]
sameTop <- vapply(1:3, function(k) mean(!is.na(same$rank) & same$rank <= k), numeric(1))

# top-1 with its 95% Wilson interval
row <- function(route, n, observations, train, correct, top2, top3) {
  ci <- dimoose:::benchWilson(correct, n)
  data.frame(route = route, model = modelName, seed = seed, test_photos = n, test_observations = observations, train_photos = train,
             correct = correct, top1 = correct / n, top1_lower = ci[["lower"]], top1_upper = ci[["upper"]], top2 = top2, top3 = top3)
}
summary <- rbind(
  row("names (all photos)", byName$n, byName$observations, 0, sum(byName$results$correct), byName$topK[["top2"]], byName$topK[["top3"]]),
  row("names (the build route's test photos)", nrow(same), length(unique(same$observation)), 0, sum(same$correct), sameTop[2], sameTop[3]),
  row("build (sniglet key from the training photos)", built$n, built$observations, built$nTrain, sum(built$results$correct), NA, NA))
write.csv(summary, file.path(out, "results-summary.csv"), row.names = FALSE)

# every split of the build route, then their mean and spread
rp <- built$repeats
ci <- t(vapply(seq_len(nrow(rp)), function(i) dimoose:::benchWilson(rp$correct[i], rp$n[i]), numeric(2)))
rp$top1_lower <- ci[, 1]; rp$top1_upper <- ci[, 2]
write.csv(rp, file.path(out, "results-repeats.csv"), row.names = FALSE)

per <- merge(byName$perSpecies, setNames(built$perSpecies, c("Taxon", "build_n", "build_top1", "build_top1_all_splits")), by = "Taxon", all = TRUE)
names(per)[names(per) %in% c("n", "top1", "top3")] <- c("names_n", "names_top1", "names_top3")
write.csv(per, file.path(out, "results-per-species.csv"), row.names = FALSE)

write.csv(as.data.frame.matrix(byName$confusion), file.path(out, "confusion-names.csv"))
write.csv(as.data.frame.matrix(built$confusion), file.path(out, "confusion-build.csv"))

pred <- merge(
  data.frame(id = byName$results$id, observation_id = byName$results$observation, actual = byName$results$actual,
             names_predicted = byName$results$predicted, names_rank = byName$results$rank, stringsAsFactors = FALSE),
  data.frame(id = built$results$id, build_predicted = built$results$predicted, build_correct = built$results$correct,
             stringsAsFactors = FALSE), by = "id", all.x = TRUE)
pred$split <- built$split[match(pred$id, sub("\\.[^.]+$", "", basename(manifest$file)))]
if (!is.null(byName$identify)) {
  ans <- byName$identify$results
  at <- match(pred$id, ans$image)
  pred$identify_name <- ans$name[at]; pred$identify_rank <- ans$rank[at]
  pred$identify_probability <- round(ans$probability[at], 4); pred$identify_confident <- ans$confident[at]
  pred$identify_correct <- ans$correct[at]
  idf <- data.frame(confidence = 0.8, photos = nrow(ans), confident = byName$identify$confident, correct = byName$identify$correct,
                    correct_when_confident = byName$identify$correctWhenConfident,
                    answered_species = mean(ans$rank == "species"), answered_genus = mean(ans$rank == "genus"),
                    answered_family = mean(ans$rank == "family"), answered_order = mean(ans$rank == "order"))
  write.csv(idf, file.path(out, "results-identify.csv"), row.names = FALSE)
  print(idf)
}
write.csv(pred[order(pred$actual, pred$id), ], file.path(out, "predictions.csv"), row.names = FALSE)

writeLines(c(
  paste("started:", started),
  paste("finished:", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  paste("photos:", nrow(manifest), "from", length(unique(manifest$observation_id)), "observations of",
        length(unique(manifest$taxon)), "species"),
  paste("iNaturalist id_below:", format(manifest$id_below[1], scientific = FALSE), "; seed:", seed, "; retrieved:", manifest$retrieved[1]),
  paste("model:", model$spec$arch, "/", model$spec$library, "/ weights sha256", c(model$spec$weights_sha256, "unknown")[1]),
  paste("lineage for identifyPhotos:", if (is.null(lineage)) "not available" else "GBIF, via checkNames()"),
  paste("built key (first split):", nrow(built$key$leads) / 2, "couplets,", sum(built$key$leads$Next == "-"), "end points"),
  sprintf("build route over %d splits (seeds %d to %d): top-1 mean %.4f, standard deviation %.4f, range %.4f to %.4f",
          repeats, seed, seed + repeats - 1, built$accuracyMean, built$accuracySd, built$accuracyRange[1], built$accuracyRange[2]),
  paste("R:", R.version.string),
  paste("dimoose:", tryCatch(as.character(utils::packageVersion("dimoose")), error = function(e) read.dcf("DESCRIPTION")[1, "Version"]))
), file.path(out, "run-info.txt"))
print(summary)
print(rp)
cat("results written to", out, "\n")
