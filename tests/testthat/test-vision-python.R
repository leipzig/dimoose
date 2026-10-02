skipUnlessVision <- function() {
  skip_if_not_installed("reticulate")
  w <- Sys.getenv("MOOSE_CLIP_WEIGHTS")
  skip_if(!nzchar(w) || !file.exists(w), "MOOSE_CLIP_WEIGHTS not set")
  # declare the requirements first, as visionModel() does, so that a Python
  # provided by reticulate has them
  if (!reticulate::py_available(initialize = FALSE)) reticulate::py_require(pythonRequirements())
  skip_if_not(reticulate::py_module_available("open_clip"), "open_clip not installed")
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
  expect_equal(dim(e$patches), c(4, 49, 512))
  expect_equal(dimnames(e$patches)[[1]], rownames(e$image))
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
  s <- scoreImages(key, m, p)
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
  expect_setequal(pythonRequirements(), c("torch", "open_clip_torch", "pillow", "numpy"))
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
  new <- list.files(system.file("extdata", "new-photos", package = "moose"), full.names = TRUE)
  r <- classify(key, scoreImages(key, m, new))
  expect_equal(r$result, c("banana", "blueberry", "kiwi", "lemon", "pineapple", "strawberry"))
})
