# The R side of the vision layer, run against fakeVisionModel() so it needs
# no Python; test-vision-python.R covers the real model.

test_that("visionModel wraps the Python model and its spec", {
  skip_if_not_installed("reticulate")
  fv <- fakeVisionModel()
  local_mocked_bindings(pyVision = function() fv$model$mod)
  m <- visionModel(weights = "w.pt", name = "ViT-B-16", pretrained = "laion")
  expect_s3_class(m, "mooseVisionModel")
  expect_equal(fv$calls$load_model[[1]], list(name = "ViT-B-16", pretrained = "laion", weights = "w.pt"))
  expect_equal(m$spec$arch, "ViT-B-32")
})

test_that("a vision model prints its architecture and size", {
  m <- fakeVisionModel()$model
  expect_output(print(m), "<moose vision model> ViT-B-32 (open_clip), 8 dimensions", fixed = TRUE)
  expect_output(expect_invisible(print(m)))
})

test_that("modelMeta turns the spec into model_ rows and drops NULL entries", {
  meta <- modelMeta(fakeVisionModel()$model)
  expect_named(meta, c("key", "value"))
  expect_equal(meta$key, c("model_library", "model_arch", "model_pretrained", "model_image_size", "model_dim"))
  expect_equal(meta$value[meta$key == "model_dim"], "8")
})

test_that("embedImages names rows by file and passes region and patches through", {
  fv <- fakeVisionModel()
  paths <- c("/pics/L1.png", "/pics/L3.jpg")
  e <- embedImages(fv$model, paths)
  expect_equal(rownames(e$image), c("L1", "L3"))
  expect_equal(unname(e$image), unname(fv$sv$image[c("L1", "L3"), ]))
  expect_equal(dimnames(e$patches)[[1]], c("L1", "L3"))
  expect_equal(dim(e$patches), c(2, 9, 8))

  e2 <- embedImages(fv$model, paths, region = c(0, 0.5, 0, 1), patches = FALSE)
  expect_null(e2$patches)
  expect_equal(fv$calls$embed_images[[2]]$region, c(0, 0.5, 0, 1))
  expect_false(fv$calls$embed_images[[2]]$patches)
})

test_that("embedTexts names rows by text", {
  fv <- fakeVisionModel()
  m <- embedTexts(fv$model, c("a red bar", "a blue bar"))
  expect_equal(rownames(m), c("a red bar", "a blue bar"))
  expect_equal(dim(m), c(2, 8))
})

test_that("scoreImages on a term key matches featureScores on the patches", {
  fv <- fakeVisionModel()
  sv <- fv$sv
  terms <- discoverTerms(sv$patches, k = 4, seed = 1)
  key <- keyFromTerms(termScores(sv$patches, terms$centroids), sv$images, terms, quantile = 0.5)
  s <- scoreImages(key, fv$model, sv$images$path)
  expect_equal(colnames(s), key$features$id)
  expect_equal(rownames(s), sv$images$id)
  expect_equal(s, featureScores(key, patches = sv$patches))
  # Only the whole images are embedded; no text features, so no text calls
  expect_length(fv$calls$embed_images, 1)
  expect_length(fv$calls$embed_texts, 0)
  expect_equal(classify(key, s)$result, sv$images$label)
})

test_that("scoreImages embeds once per crop region for text features", {
  fv <- fakeVisionModel()
  sv <- fv$sv
  vocab <- data.frame(
    feature = c("a red bar", "a blue bar", "a green bar"),
    opposite = c("no red bar", "no blue bar", "no green bar"),
    region = c(NA, "0,0.5,0,1", "0,0.5,0,1"), stringsAsFactors = FALSE
  )
  template <- "an image with {x}"
  txt <- embedTexts(fv$model, vocabularyPrompts(vocab, template))
  key <- keyFromClusters(sv$image, sv$images, vocab, txt, template = template)
  fv$calls$embed_images <- list()

  s <- scoreImages(key, fv$model, sv$images$path)
  expect_equal(colnames(s), key$features$id)
  regions <- lapply(fv$calls$embed_images, `[[`, "region")
  expect_null(regions[[1]])
  expect_true(all(vapply(regions[-1], identical, TRUE, c(0, 0.5, 0, 1))))
  expect_lte(length(regions), 2)

  # Same numbers as featureScores on the matching embeddings
  f <- key$features
  cropped <- sv$image[, rev(seq_len(ncol(sv$image)))]
  for (j in seq_len(nrow(f))) {
    emb <- if (is.na(f$region[j])) sv$image else cropped
    expected <- emb %*% txt[f$prompt[j], ] - emb %*% txt[f$negative_prompt[j], ]
    expect_equal(unname(s[, j]), as.numeric(expected))
  }
})

test_that("scoreImages needs a features table", {
  expect_error(scoreImages(arachnidaKey(), fakeVisionModel()$model, "x.png"), "no features table")
})

test_that("patchExemplars attaches crops to features, meta and leads", {
  fv <- fakeVisionModel()
  sv <- fv$sv
  terms <- discoverTerms(sv$patches, k = 4, seed = 1, exemplars = 2)
  key <- keyFromTerms(termScores(sv$patches, terms$centroids), sv$images, terms, quantile = 0.5)
  out <- patchExemplars(fv$model, key, sv$images, pad = 10, size = 32)
  expect_identical(out, key)

  f <- key$features
  ex <- f$exemplars[[1]]
  expect_equal(ex$png, c("PNG1", "PNG2"))
  # Python gets file paths and zero-based patch indices
  first <- fv$calls$exemplar_pngs[[1]]
  expect_equal(first$paths, sv$images$path[match(ex$image, sv$images$id)])
  expect_equal(first$patch_indices, ex$patch - 1L)
  expect_equal(c(first$pad, first$size), c(10, 32))

  meta <- key$meta
  imageRows <- meta[startsWith(meta$key, "image_"), ]
  # two glossary crops per sniglet, plus each lead's own example crops
  expect_equal(sum(!startsWith(imageRows$key, "image_lead_")), 2 * nrow(f))
  expect_true(all(startsWith(imageRows$value, "data:image/png;base64,PNG")))
  expect_true("model_arch" %in% meta$key)

  leads <- key$leads
  # both sides of a couplet show crops: "Has" what it has, "Lacks" what its
  # images have instead
  expect_true(all(nzchar(leads$Image[nzchar(leads$Examples)])))
  expect_true(all(nzchar(leads$Image[leads$Test == ">"])))
  expect_true(any(startsWith(imageRows$key, "image_lead_")))
  expect_length(key$validate(), 0)
})
