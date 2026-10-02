# Checks moose's vision keys against fordera's outputs (V1-V4 in the spec).
# Needs: FORDERA (fordera checkout), MOOSE_CLIP_WEIGHTS, Python with torch+open_clip.
# Run from the package root with pkgload, or adjust the load path below.
suppressMessages(pkgload::load_all(Sys.getenv("MOOSE_PKG", "."), quiet = TRUE))
library(jsonlite)
fordera <- Sys.getenv("FORDERA", "~/Documents/fordera")
np <- reticulate::import("numpy")
model <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))

man <- fromJSON(file.path(fordera, "data/processed/manifest.json"), simplifyVector = FALSE)
paths <- file.path(fordera, "data/processed", basename(vapply(man, function(e) e$processed_path, "")))
images <- imageSet(paths, label = function(x) sub("_.*$", "", x))
gens <- c("1948-1950" = 1, "1951" = 1, "1952" = 1, "1953" = 2, "1954" = 2, "1955" = 2, "1956" = 2,
          "1957" = 3, "1958" = 3, "1959" = 3, "1960" = 3, "1961" = 4, "1962" = 4, "1963" = 4, "1964" = 4,
          "1965" = 4, "1966" = 4, "1967" = 5, "1968" = 5, "1969" = 5, "1970" = 5, "1971" = 5, "1972" = 5,
          "1973-1975" = 6, "1976-1977" = 6, "1978" = 6, "1979" = 6)
emb <- embedImages(model, paths)

# ---- V1: patch scores against fordera's centroids ----------------------------
cent <- np$load(file.path(fordera, "outputs/trait_centroids.npy"))
ts <- fromJSON(file.path(fordera, "outputs/trait_summary.json"), simplifyVector = FALSE)
rownames(cent) <- unlist(ts$names)
ours <- snigletScores(emb$patches, cent)
theirs <- t(vapply(man, function(e) unlist(ts$per_image_presence[[e$processed_path]]), numeric(nrow(cent))))
colnames(theirs) <- rownames(cent); rownames(theirs) <- images$id
v1 <- max(abs(ours - theirs))
cat(sprintf("V1 max |moose - fordera| patch score: %.2e  (%s)\n", v1, if (v1 < 1e-3) "PASS" else "FAIL"))

# ---- V2: balanced tree from fordera's scores equals trait_tree.json ----------
fterms <- structure(list(sniglets = data.frame(id = seq_len(nrow(cent)), sniglet = rownames(cent), name = rownames(cent), definition = NA_character_), centroids = cent, exemplars = NULL), class = "mooseSniglets")
k2 <- keyFromSniglets(theirs, images, fterms, quantile = 0.6)
tt <- fromJSON(file.path(fordera, "outputs/trait_tree.json"), simplifyVector = FALSE)
rows <- list(); counter <- 0
conv <- function(n) {
  counter <<- counter + 1; id <- as.character(counter)
  kids <- list(n$yes, n$no)
  nx <- vapply(kids, function(k) if (k$type == "leaf") "-" else conv(k), "")
  rows[[id]] <<- data.frame(Statement = id, Choice = c("a", "b"), Next = nx,
    Taxon = vapply(kids, function(k) if (k$type == "leaf") k$label else "", ""), Feature = paste0("sniglet:", n$trait_name))
  id
}
conv(tt)
ref <- do.call(rbind, rows[order(as.integer(names(rows)))]); rownames(ref) <- NULL
same <- identical(ref, k2$leads[, names(ref)])
e2 <- evaluateKey(k2, theirs, images$label, gens)
cat(sprintf("V2 tree identical: %s; year %d/33, generation %d/33 (%s)\n", same, sum(e2$results$correct), sum(e2$results$groupCorrect),
  if (same && sum(e2$results$correct) == 26 && sum(e2$results$groupCorrect) == 28) "PASS" else "CHECK"))

# ---- V3: from scratch ---------------------------------------------------------
terms <- discoverSniglets(emb$patches, k = 40, seed = 1)
scores <- snigletScores(emb$patches, terms$centroids)
k3 <- keyFromSniglets(scores, images, terms)
e3 <- evaluateKey(k3, scores, images$label, gens)
loo <- looKey(images, build = function(tr) keyFromSniglets(scores[tr, ], images[tr, ], terms), score = function(key, i) scores[i, , drop = FALSE], groups = gens)
looRefit <- looKey(images,
  build = function(tr) { t <- discoverSniglets(emb$patches[tr, , , drop = FALSE], k = 40, seed = 1); keyFromSniglets(snigletScores(emb$patches[tr, , , drop = FALSE], t$centroids), images[tr, ], t) },
  score = function(key, i) featureScores(key, patches = emb$patches[i, , , drop = FALSE]), groups = gens)
cat(sprintf("V3 from scratch: train year %.1f%% gen %.1f%%; LOO (shared terms) year %.1f%% gen %.1f%%; LOO (refit terms) year %.1f%% gen %.1f%%\n",
  100 * e3$accuracy, 100 * e3$groupAccuracy, 100 * loo$accuracy, 100 * loo$groupAccuracy, 100 * looRefit$accuracy, 100 * looRefit$groupAccuracy))

# ---- V4: question key ---------------------------------------------------------
src <- readLines(file.path(fordera, "src/fordera/describer.py"))
m <- regmatches(src, regexec('^\\s*\\("([^"]+)", "([^"]+)"\\),', src))
vocab <- do.call(rbind, lapply(Filter(length, m), function(x) data.frame(feature = x[2], opposite = x[3], stringsAsFactors = FALSE)))
tmpl <- "a pickup truck with {x}"
txt <- embedTexts(model, vocabularyPrompts(vocab, tmpl))
yearOrder <- function(l) min(as.integer(sub("-.*$", "", l)))
k4 <- keyFromClusters(emb$image, images, vocab, txt, template = tmpl, order = yearOrder)
s4 <- scoreImages(k4, model, paths)
e4 <- evaluateKey(k4, s4, images$label, gens)
k4m <- keyFromClusters(emb$image, images, vocab, txt, template = tmpl, order = yearOrder, calibrate = "midpoint")
e4m <- evaluateKey(k4m, scoreImages(k4m, model, paths), images$label, gens)
cat(sprintf("V4 question key self-walk: year %.1f%% gen %.1f%% (threshold 0); year %.1f%% gen %.1f%% (midpoint); fordera 27%% gen\n",
  100 * e4$accuracy, 100 * e4$groupAccuracy, 100 * e4m$accuracy, 100 * e4m$groupAccuracy))

k3 <- patchExemplars(model, k3, images)
if (nzchar(Sys.getenv("MOOSE_WRITE_HTML"))) {
  exportWizard(k3, "fordera-sniglets.html")
  exportWizard(k4, "fordera-questions.html")
}
saveRDS(list(v1 = v1, v2_same = same, v2 = e2, v3 = e3, loo = loo, looRefit = looRefit, v4 = e4, v4m = e4m,
  spec = modelMeta(model)), Sys.getenv("MOOSE_VERIFY_OUT", "verify-results.rds"))
