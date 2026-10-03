# Looks for open_clip without importing it: importing it here would load torch
# before moose's Python module can make torch use its own fast maths library
# (see inst/python/moose_vision.py), and every test would run many times slower.
hasOpenClip <- function() {
  isTRUE(tryCatch(reticulate::py_eval("__import__('importlib.util').util.find_spec('open_clip') is not None"),
                  error = function(e) FALSE))
}

skipUnlessVision <- function() {
  skip_if_not_installed("reticulate")
  w <- Sys.getenv("MOOSE_CLIP_WEIGHTS")
  skip_if(!nzchar(w) || !file.exists(w), "MOOSE_CLIP_WEIGHTS not set")
  # declare the requirements first, as visionModel() does, so that a Python
  # provided by reticulate has them
  if (!reticulate::py_available(initialize = FALSE)) reticulate::py_require(pythonRequirements())
  skip_if_not(hasOpenClip(), "open_clip not installed")
}

testPics <- function(n = 4) {
  dir <- tempfile(); dir.create(dir)
  paths <- character(n)
  for (i in seq_len(n)) {
    a <- array(0.9, c(64, 64, 3))
    a[(i * 6):(i * 6 + 20), 10:50, ] <- c(1, 0, 0)[(i %% 3) + 1]
    paths[i] <- file.path(dir, sprintf("L%d.png", i))
    png::writePNG(a, paths[i])
  }
  paths
}

test_that("visionModel loads and reports its spec", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  expect_s3_class(m, "mooseVisionModel")
  expect_equal(m$spec$dim, 512L)
  expect_equal(modelMeta(m)$key[1], "model_library")
})

test_that("embedImages and embedTexts return named matrices", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  p <- testPics()
  e <- embedImages(m, p)
  expect_equal(dim(e$image), c(4, 512))
  expect_equal(rownames(e$image), c("L1", "L2", "L3", "L4"))
  # by default the local regions are 4 x 4 tiles; tiles = 0 gives the model's patch tokens
  expect_equal(dim(e$patches), c(4, 16, 512))
  expect_equal(attr(e$patches, "tiles"), 4L)
  expect_equal(dimnames(e$patches)[[1]], rownames(e$image))
  expect_equal(dim(embedImages(m, p, tiles = c(2, 3))$patches), c(4, 13, 512))
  tok <- embedImages(m, p, tiles = 0)
  expect_equal(dim(tok$patches), c(4, 49, 512))
  expect_length(attr(tok$patches, "tiles"), 0)
  # plain background tiles are blanked: the test pictures are grey outside the bar
  norms <- sqrt(apply(e$patches^2, c(1, 2), sum))
  expect_true(any(norms == 0))
  expect_true(all(abs(norms[norms > 0] - 1) < 1e-4))
  t <- embedTexts(m, c("a red bar", "a blue bar"))
  expect_equal(rownames(t), c("a red bar", "a blue bar"))
  expect_null(embedImages(m, p, patches = FALSE)$patches)
  # an imageSet names the rows by its ids, which stay unique across folders
  set <- imageSet(p); set$id <- paste0("x_", set$id)
  expect_equal(rownames(embedImages(m, set, patches = FALSE)$image), set$id)
})

test_that("images to key to classify, with exemplar crops and scores for new images", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  p <- testPics()
  images <- imageSet(p)
  e <- embedImages(m, p)
  terms <- discoverTerms(e$patches, k = 3, seed = 1)
  key <- keyFromTerms(termScores(e$patches, terms$centroids), images, terms, quantile = 0.5)
  key <- patchExemplars(m, key, images)
  expect_true(all(nzchar(key$features$exemplars[[1]]$png)))
  expect_true(any(grepl("^image_", key$meta$key)))
  expect_true(any(nzchar(key$leads$Image)))
  expect_equal(key$meta$value[key$meta$key == "sniglet_tiles"], "4")
  s <- scoreImages(key, m, p)
  # scoring the training images again reproduces the scores the key was built on
  expect_equal(unname(s), unname(termScores(e$patches, terms$centroids)), tolerance = 1e-5)
  tokKey <- keyFromTerms(termScores(embedImages(m, p, tiles = 0)$patches, discoverTerms(embedImages(m, p, tiles = 0)$patches, k = 3)$centroids),
                         images, discoverTerms(embedImages(m, p, tiles = 0)$patches, k = 3), quantile = 0.5)
  expect_equal(tokKey$meta$value[tokKey$meta$key == "sniglet_tiles"], "")
  expect_equal(dim(scoreImages(tokKey, m, p)), c(4L, 3L))
  expect_equal(colnames(s), key$features$id)
  expect_equal(nrow(classify(key, s)), 4)
  html <- exportWizard(key)
  expect_match(html, "data:image/png;base64,", fixed = TRUE)

  vocab <- data.frame(feature = c("a red bar", "a blue bar"), opposite = c("no red bar", "no blue bar"),
                      region = c(NA, "0,0.5,0,1"), stringsAsFactors = FALSE)
  txt <- embedTexts(m, vocabularyPrompts(vocab, "an image with {x}"))
  qkey <- keyFromClusters(e$image, images, vocab, txt, template = "an image with {x}")
  s2 <- scoreImages(qkey, m, p)
  expect_equal(colnames(s2), qkey$features$id)
  expect_length(qkey$validate(), 0)
})

test_that("the Python requirements come from the bundled requirements file", {
  req <- pythonRequirements()
  expect_setequal(sub("[=<>~!].*$", "", req), c("torch", "open_clip_torch", "pillow", "numpy"))
  expect_false(any(grepl("#", req, fixed = TRUE)))   # comments are not requirements
})

test_that("the documented steps identify the held-out example photos", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  images <- imageSet(system.file("extdata", "pics", package = "moose"))
  emb <- embedImages(m, images)
  sniglets <- discoverSniglets(emb$patches)
  scores <- snigletScores(emb$patches, sniglets$centroids)
  key <- keyFromSniglets(scores, images, sniglets, method = "rpart")
  expect_equal(evaluateKey(key, scores, images$label)$accuracy, 1)
  # every sniglet is asked about once at most on any path, and its examples come from images that have it
  expect_false(any(duplicated(key$leads$Feature[key$leads$Test == ">"])))
  shared <- vapply(key$features$exemplars[snigletNames(key)$used], function(ex) length(unique(ex$label)), 0L)
  expect_true(any(shared > 1))                     # some sniglets are common to several fruits
  # every lead, "Lacks" ones included, gets example crops
  shown <- patchExemplars(m, key$clone(), images)
  expect_true(all(nzchar(shown$leads$Image)))
  expect_true(all(unlist(strsplit(shown$leads$Image, ";")) %in% sub("^image_", "", shown$meta$key)))
  expect_match(exportWizard(shown), "lead_1b_1", fixed = TRUE)
  new <- list.files(system.file("extdata", "new-photos", package = "moose"), full.names = TRUE)
  r <- classify(key, scoreImages(key, m, new))
  expect_gte(sum(r$result == c("banana", "blueberry", "kiwi", "lemon", "pineapple", "strawberry")), 5)
})

# These need Python with open_clip but no downloaded weights: the model is
# built with random weights, laid out like a model repository (as BioCLIP is
# on the Hugging Face Hub: a configuration file and a weights file).
skipUnlessPython <- function() {
  skip_if_not_installed("reticulate")
  # only with a Python the user has chosen: never let a test set one up, which
  # would download several gigabytes
  skip_if(!nzchar(Sys.getenv("RETICULATE_PYTHON")), "RETICULATE_PYTHON not set")
  skip_if_not(hasOpenClip(), "open_clip not installed")
}

test_that("a model repository (the way BioCLIP is distributed) loads and builds keys", {
  skipUnlessPython()
  skip_on_cran()
  dir <- tempfile("repo"); dir.create(dir)
  reticulate::py_run_string(sprintf('
import open_clip, torch, json, os
torch.manual_seed(1)
_m = open_clip.create_model("ViT-B-16", pretrained=None)
torch.save(_m.state_dict(), os.path.join(r"%s", "open_clip_pytorch_model.bin"))
json.dump({"model_cfg": open_clip.get_model_config("ViT-B-16"),
           "preprocess_cfg": {"mean": [0.48145466, 0.4578275, 0.40821073], "std": [0.26862954, 0.26130258, 0.27577711]}},
          open(os.path.join(r"%s", "open_clip_config.json"), "w"))
del _m', dir, dir))
  m <- visionModel(name = paste0("local-dir:", dir))
  expect_equal(m$spec$pretrained, "repository")
  expect_equal(m$spec$patch_size, 16L)             # BioCLIP's architecture: ViT-B/16
  expect_equal(m$spec$dim, 512L)
  images <- imageSet(system.file("extdata", "pics", package = "moose"))[c(1:3, 7:9, 13:15), ]
  emb <- embedImages(m, images, tiles = 2)
  expect_equal(dim(emb$patches), c(9, 4, 512))
  expect_equal(dim(embedImages(m, images[1:2, ], tiles = 0)$patches), c(2, 196, 512))   # 14 x 14 patch tokens
  sniglets <- discoverSniglets(emb$patches, k = 6, nstart = 1)
  scores <- snigletScores(emb$patches, sniglets$centroids)
  key <- patchExemplars(m, keyFromSniglets(scores, images, sniglets, method = "rpart"), images)
  expect_length(key$validate(), 0)
  expect_equal(unname(scoreImages(key, m, images)), unname(scores), tolerance = 1e-5)
  expect_equal(dim(embedTexts(m, c("a", "b"))), c(2L, 512L))
})

test_that("the BioCLIP shortcuts name the Hub repositories", {
  skip_if_not_installed("reticulate")
  # no download is attempted: the model name is resolved before Python is touched
  seen <- NULL
  local_mocked_bindings(pyVision = function() list(load_model = function(name, pretrained, weights) { seen <<- name; list(spec = list()) }))
  visionModel(name = "bioclip"); expect_equal(seen, "hf-hub:imageomics/bioclip")
  visionModel(name = "BioCLIP-2"); expect_equal(seen, "hf-hub:imageomics/bioclip-2")
  visionModel(name = "ViT-B-16"); expect_equal(seen, "ViT-B-16")
})
