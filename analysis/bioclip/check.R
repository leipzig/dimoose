# Checks dimoose's photo keys with the real BioCLIP weights, which are downloaded
# from the Hugging Face Hub on first use (about 600 MB for BioCLIP, 1.7 GB for
# BioCLIP 2). Run from the package root:
#
#   Rscript analysis/bioclip/check.R            # BioCLIP
#   Rscript analysis/bioclip/check.R bioclip-2  # BioCLIP 2
#
# It builds a key from the example photos, follows it for the held-out photos
# and prints what it found.
suppressMessages(if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) pkgload::load_all(".", quiet = TRUE) else library(dimoose))
name <- commandArgs(TRUE)[1]; if (is.na(name)) name <- "bioclip"
model <- visionModel(name = name)
print(model)
str(model$spec[c("arch", "pretrained", "image_size", "patch_size", "patch_grid", "dim")])

images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
t0 <- Sys.time()
emb <- embedImages(model, images)
cat("embedded", nrow(images), "photos in", format(Sys.time() - t0), "; regions:", paste(dim(emb$patches), collapse = " x "), "\n")
sniglets <- discoverSniglets(emb$patches)
scores <- snigletScores(emb$patches, sniglets$centroids)
key <- keyFromSniglets(scores, images, sniglets, method = "rpart")
print(key)
print(key$leads[, c("Statement", "Character", "Next", "Taxon")])
loo <- looKey(images, build = function(train) keyFromSniglets(scores[train, ], images[train, ], sniglets, method = "rpart"),
              score = function(key, i) scores[i, , drop = FALSE])
cat("leave-one-out accuracy:", round(loo$accuracy, 3), "\n")
new <- list.files(system.file("extdata", "new-photos", package = "dimoose"), full.names = TRUE)
r <- classify(key, scoreImages(key, model, new))
r$expected <- c("banana", "blueberry", "kiwi", "lemon", "pineapple", "strawberry")
print(r)
key <- patchExemplars(model, key, images)
out <- file.path(tempdir(), paste0(name, "-key.html"))
exportWizard(key, out)
cat("wizard written to", out, "\n")
cat(if (all(dim(emb$image) == c(nrow(images), model$spec$dim)) && length(key$validate()) == 0) "CHECK PASSED" else "CHECK FAILED", "\n")
