# The ONNX backend, embeddings in files and the browser export. Everything
# here runs without Python and without the network, except the last tests,
# which need a model folder in DIMOOSE_ONNX_MODEL (see skipUnlessOnnx()).

# A stand-in for onnxModel(): the fake vision model plus what an ONNX model's
# spec and files say.
fakeOnnxModel <- function(encoder = NULL, d = 8) {
  fv <- fakeVisionModel(syntheticVision(d = d))
  m <- fv$model
  m$spec <- c(m$spec, list(backend = "onnx", precision = "int8",
                           image_mean = "0.48145466,0.4578275,0.40821073", image_std = "0.26862954,0.26130258,0.27577711"))
  if (!is.null(encoder)) m$files <- list(image = encoder, imageUrl = "https://huggingface.co/org/model/resolve/main/onnx/vision_model_quantized.onnx")
  list(model = m, calls = fv$calls)
}

smallKey <- function() {
  keyFromLeads(data.frame(
    Statement = c(1, 1, 2, 2),
    Choice = c("a", "b", "a", "b"),
    Character = c("Leaves compound", "Leaves simple", "Bark white", "Bark brown"),
    Next = c(NA, 2, NA, NA),
    Taxon = c("Box elder (Acer negundo)", NA, "Paper birch (Betula papyrifera)", "the brown one"),
    stringsAsFactors = FALSE), desc = "Three trees")
}

test_that("half-precision floats convert both ways", {
  x <- c(0, 1, -1, 0.5, 0.1, -0.33333, 2^-14, 2^-20, 65504, 1e-9, 1e6, -1e6)
  back <- onxFromHalf(onxToHalf(x))
  expect_equal(back[1:4], c(0, 1, -1, 0.5))
  expect_equal(back[5:6], x[5:6], tolerance = 1e-3)
  expect_equal(back[7:9], x[7:9])
  expect_equal(back[10], 0)
  expect_equal(back[11:12], c(Inf, -Inf))
  expect_true(is.nan(onxFromHalf(onxToHalf(NA_real_))))
  # known bit patterns
  expect_equal(onxToHalf(c(1, -2, 65504, 2^-24)), c(15360L, 49152L, 31743L, 1L))
  expect_true(all(onxToHalf(runif(100, -1, 1)) %in% 0:65535))
})

test_that("embeddings survive a round trip through a file", {
  skip_if_not_installed("jsonlite")
  sv <- syntheticVision(per_label = 2)
  emb <- list(image = sv$image, patches = sv$patches)
  attr(emb$patches, "tiles") <- c(2L, 4L)
  attr(emb$patches, "empty") <- c(minDetail = 8, minFill = 0.5)
  file <- tempfile(fileext = ".safetensors")
  expect_equal(saveEmbeddings(emb, file), file)
  back <- loadEmbeddings(file)
  expect_named(back, c("image", "patches"))
  expect_equal(dim(back$patches), dim(emb$patches))
  expect_equal(rownames(back$image), rownames(emb$image))
  expect_equal(dimnames(back$patches)[[1]], dimnames(emb$patches)[[1]])
  expect_equal(back$image, emb$image, tolerance = 1e-6)
  expect_equal(unclass(back$patches), unclass(emb$patches), tolerance = 1e-6, ignore_attr = TRUE)
  expect_equal(attr(back$patches, "tiles"), c(2L, 4L))
  expect_equal(attr(back$patches, "empty"), c(minDetail = 8, minFill = 0.5))
  expect_null(attr(back, "model"))

  # 16-bit floats: half the size, cosines the same to three decimals
  half <- tempfile(fileext = ".safetensors")
  saveEmbeddings(emb, half, precision = "float16", model = fakeVisionModel(sv)$model)
  expect_lt(file.size(half), 0.6 * file.size(file))
  b16 <- loadEmbeddings(half)
  expect_equal(b16$image, emb$image, tolerance = 1e-3)
  expect_lt(max(abs(b16$patches - emb$patches)), 1e-3)
  expect_equal(attr(b16, "model")$arch, "ViT-B-32")

  # a NULL entry (embedImages(patches = FALSE)) is left out
  saveEmbeddings(list(image = sv$image, patches = NULL), file)
  expect_named(loadEmbeddings(file), "image")
})

test_that("a single matrix comes back as a matrix, with its texts as row names", {
  skip_if_not_installed("jsonlite")
  texts <- c("a photo of Acer negundo.", "a \"quoted\" text, with a comma", "Bläuling — café", "")
  m <- matrix(seq_len(12) / 7, 4, 3, dimnames = list(texts, NULL))
  file <- tempfile()
  saveEmbeddings(m, file)
  back <- loadEmbeddings(file)
  expect_true(is.matrix(back))
  expect_equal(rownames(back), texts)
  expect_equal(back, m, tolerance = 1e-6)
  # a plain vector too
  saveEmbeddings(c(a = 1, b = 2.5), file)
  expect_equal(loadEmbeddings(file), c(a = 1, b = 2.5))
})

test_that("the file is laid out as safetensors: header length, JSON header, row-major numbers", {
  skip_if_not_installed("jsonlite")
  m <- matrix(c(1, 2, 3, 4, 5, 6), 2, 3, dimnames = list(c("r1", "r2"), NULL))   # rows 1 3 5 and 2 4 6
  file <- tempfile()
  saveEmbeddings(list(first = m, second = m[1, , drop = FALSE] * 10), file)
  bytes <- readBin(file, "raw", file.size(file))
  n <- readBin(bytes[1:4], "integer", size = 4, endian = "little")
  expect_equal(bytes[5:8], as.raw(c(0, 0, 0, 0)))
  expect_equal(n %% 8, 0)
  header <- jsonlite::fromJSON(rawToChar(bytes[9:(8 + n)]), simplifyVector = FALSE)
  expect_equal(header$first$dtype, "F32")
  expect_equal(unlist(header$first$shape), c(2, 3))
  expect_equal(unlist(header$first$data_offsets), c(0, 24))
  expect_equal(unlist(header$second$data_offsets), c(24, 36))
  expect_equal(header[["__metadata__"]]$format, "dimoose-embeddings")
  expect_true(all(vapply(header[["__metadata__"]], is.character, logical(1))))   # safetensors metadata is strings only
  data <- bytes[(9 + n):length(bytes)]
  expect_equal(readBin(data, "numeric", 9, size = 4, endian = "little"), c(1, 3, 5, 2, 4, 6, 10, 30, 50))
  # offsets are written as plain integers even when large
  big <- matrix(0, 300, 512)
  saveEmbeddings(list(a = big, b = big), file)
  head <- rawToChar(readBin(file, "raw", 600)[9:500])
  expect_false(grepl("e+", head, fixed = TRUE))
  expect_match(head, "614400,1228800", fixed = TRUE)
})

test_that("bad input and bad files are refused in plain words", {
  skip_if_not_installed("jsonlite")
  expect_error(saveEmbeddings(list(1, 2), tempfile()), "distinct names")
  expect_error(saveEmbeddings(list(a = "x"), tempfile()), "not numeric")
  expect_error(saveEmbeddings(list(), tempfile()), "numeric array")
  expect_error(loadEmbeddings(tempfile()), "No such file")
  junk <- tempfile(); writeLines("this is not a tensor file at all", junk)
  expect_error(loadEmbeddings(junk), "not a safetensors file")
  # a file cut short
  file <- tempfile(); saveEmbeddings(matrix(1, 4, 4), file)
  bytes <- readBin(file, "raw", file.size(file))
  writeBin(bytes[seq_len(length(bytes) - 8)], file)
  expect_error(loadEmbeddings(file), "cut short")
})

test_that("32-bit numbers come back exactly, and awkward values and names survive", {
  skip_if_not_installed("jsonlite")
  file <- tempfile()
  asFloat <- function(v) readBin(writeBin(as.numeric(v), raw(), size = 4), "numeric", length(v), size = 4)
  set.seed(3)
  m <- matrix(asFloat(rnorm(60)), 12, 5)                   # what a model returns: 32-bit floats held as doubles
  saveEmbeddings(m, file)
  expect_identical(loadEmbeddings(file), m)
  # other doubles are rounded to the nearest float, not otherwise changed
  d <- matrix(rnorm(60), 12, 5)
  saveEmbeddings(d, file)
  expect_identical(as.vector(loadEmbeddings(file)), asFloat(d))
  # missing and infinite values, and numbers too large for the precision
  odd <- matrix(c(NA, NaN, Inf, -Inf, 1, 1e40), 2, 3)
  saveEmbeddings(odd, file)
  expect_equal(as.vector(loadEmbeddings(file)), c(NaN, NaN, Inf, -Inf, 1, Inf))
  saveEmbeddings(odd, file, precision = "float16")
  expect_equal(as.vector(loadEmbeddings(file)), c(NaN, NaN, Inf, -Inf, 1, Inf))
  # no rows, one row, integers, a data frame, more than three dimensions
  saveEmbeddings(matrix(numeric(0), 0, 5), file); expect_equal(dim(loadEmbeddings(file)), c(0L, 5L))
  saveEmbeddings(m[1, , drop = FALSE], file); expect_equal(dim(loadEmbeddings(file)), c(1L, 5L))
  saveEmbeddings(matrix(1:6, 2), file); expect_equal(loadEmbeddings(file), matrix(as.numeric(1:6), 2))
  saveEmbeddings(data.frame(a = 1:2, b = c(0.5, 0.25), row.names = c("x", "y")), file)
  expect_equal(loadEmbeddings(file), matrix(c(1, 2, 0.5, 0.25), 2, dimnames = list(c("x", "y"), NULL)))
  a <- array(asFloat(rnorm(48)), c(2, 3, 4, 2)); saveEmbeddings(a, file); expect_identical(loadEmbeddings(file), a)
  # patch tokens have no tiling: an empty `tiles` stays empty
  tok <- array(0.5, c(2, 3, 4)); attr(tok, "tiles") <- integer(0)
  saveEmbeddings(list(patches = tok), file); expect_identical(attr(loadEmbeddings(file)$patches, "tiles"), integer(0))
  # names: other scripts, an emoji, quotes and backslashes, a missing and a repeated name, Latin-1 strings
  names <- c("Bläuling — café", "ヒノキ", "Quercus × hispanica", "\U0001F34C banana", "a\"b\\c\n", NA, "twice", "twice")
  saveEmbeddings(matrix(1:16, 8, dimnames = list(names, NULL)), file)
  expect_identical(rownames(loadEmbeddings(file)), names)
  latin <- iconv(c("Bläuling", "café"), "UTF-8", "latin1")
  saveEmbeddings(matrix(1:4, 2, dimnames = list(latin, NULL)), file)
  expect_identical(rownames(loadEmbeddings(file)), c("Bläuling", "café"))
  saveEmbeddings(list("bläu" = m, "日本" = m), file)
  expect_named(loadEmbeddings(file), c("bläu", "日本"))
  # the header is UTF-8 whatever the session's encoding
  bytes <- readBin(file, "raw", file.size(file))
  n <- readBin(bytes[1:4], "integer", size = 4, endian = "little")
  expect_true(validUTF8(rawToChar(bytes[9:(8 + n)])))
})

test_that("the model's details stay with embeddings that are loaded and saved again", {
  skip_if_not_installed("jsonlite")
  sv <- syntheticVision(per_label = 1)
  file <- tempfile()
  saveEmbeddings(list(image = sv$image), file, model = fakeVisionModel(sv)$model)
  again <- tempfile()
  saveEmbeddings(loadEmbeddings(file), again, precision = "float16")
  expect_equal(attr(loadEmbeddings(again), "model"), attr(loadEmbeddings(file), "model"))
  expect_equal(attr(loadEmbeddings(again), "model")$arch, "ViT-B-32")
  saveEmbeddings(sv$image, file, model = fakeVisionModel(sv)$model)      # a single matrix carries it too
  saveEmbeddings(loadEmbeddings(file), again)
  expect_equal(attr(loadEmbeddings(again), "model")$arch, "ViT-B-32")
  saveEmbeddings(sv$image, again)                                         # and none is invented
  expect_null(attr(loadEmbeddings(again), "model"))
})

test_that("files from other programs are read, and files that are not safetensors are refused", {
  skip_if_not_installed("jsonlite")
  # as Python's safetensors writes them: no dimoose metadata, 64-bit floats, arrays named in any order
  write <- function(header, data) {
    file <- tempfile(); con <- file(file, "wb"); on.exit(close(con))
    h <- charToRaw(header)
    writeBin(c(length(h), 0L), con, size = 4, endian = "little"); writeBin(h, con); writeBin(data, con)
    file
  }
  data <- c(writeBin(c(1.5, 2.5, 3.5, 4.5, 5.5, 6.5), raw(), size = 8, endian = "little"), writeBin(c(7, 8), raw(), size = 4, endian = "little"))
  back <- loadEmbeddings(write('{"b":{"dtype":"F32","shape":[2],"data_offsets":[48,56]},"a":{"dtype":"F64","shape":[2,3],"data_offsets":[0,48]}}', data))
  expect_equal(back$a, matrix(c(1.5, 2.5, 3.5, 4.5, 5.5, 6.5), 2, 3, byrow = TRUE))
  expect_equal(back$b, c(7, 8))
  expect_null(attr(back, "model"))
  expect_error(loadEmbeddings(write('{"a":{"dtype":"I64","shape":[1],"data_offsets":[0,8]}}', as.raw(1:8))), "type I64")
  expect_error(loadEmbeddings(write("[1,2,3] ", raw(0))), "header is not a JSON object")
  expect_error(loadEmbeddings(write('{"a":{"shape":[2]}}   ', raw(0))), "lacks a dtype")
  expect_error(loadEmbeddings(write('{"a":{"dtype":"F32","shape":[2],"data_offsets":[8,0]}}', as.raw(1:8))), "ends before it begins")
  expect_error(loadEmbeddings(write('{"__metadata__":{"x":"y"}} ', raw(0))), "holds no arrays")
  expect_error(loadEmbeddings(write('{"a":{"dtype":"F32","shape":[3],"data_offsets":[0,8]}}', as.raw(1:8))), "has 2 numbers, not the 3")
  empty <- tempfile(); file.create(empty)
  expect_error(loadEmbeddings(empty), "not a safetensors file")
  expect_error(loadEmbeddings(tempdir()), "is a folder")
  expect_error(saveEmbeddings(matrix(1, 2, 2), tempdir()), "is a folder")
  expect_error(saveEmbeddings(matrix(1, 2, 2), file.path(tempfile(), "x.safetensors")), "No such folder")
  expect_error(saveEmbeddings(matrix(TRUE, 2, 2), tempfile()), "not numeric")
  expect_error(saveEmbeddings(NULL, tempfile()), "numeric array")
  expect_error(saveEmbeddings(matrix(1, 2, 2), tempfile(), model = list(spec = list())), "vision model")
})

test_that("a large set of embeddings is saved and loaded in reasonable time", {
  skip_if_not_installed("jsonlite")
  skip_on_cran()
  big <- array(0.25, c(1500, 16, 512), dimnames = list(sprintf("photo%05d", 1:1500), NULL, NULL))   # 12 million numbers
  big[1500, 16, 512] <- -1
  file <- tempfile()
  took <- system.time({ saveEmbeddings(list(patches = big), file); back <- loadEmbeddings(file) })[["elapsed"]]
  expect_lt(took, 30)
  expect_gt(file.size(file), 1500 * 16 * 512 * 4)
  expect_identical(back$patches, big)
})

test_that("the embeddings that come with dimoose grow a photo key with no Python", {
  skip_if_not_installed("jsonlite")
  emb <- function(name) system.file("extdata", "embeddings", name, package = "dimoose")
  files <- c("pics-clip-vit-b-32.safetensors", "new-photos-clip-vit-b-32.safetensors", "texts-clip-vit-b-32.safetensors", "montana-bioclip.safetensors")
  expect_true(all(nzchar(emb(files))))
  expect_true(all(file.size(emb(files)) < 700e3))                  # small enough to ship
  # no Python is touched from here on
  local_mocked_bindings(pyVision = function() stop("Python must not be needed"), pyOnnx = function() stop("Python must not be needed"))
  images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
  pics <- loadEmbeddings(emb(files[1]))
  expect_equal(dim(pics$image), c(36L, 512L)); expect_equal(dim(pics$patches), c(36L, 16L, 512L))
  expect_setequal(rownames(pics$image), images$id)
  expect_equal(dimnames(pics$patches)[[1]], rownames(pics$image))
  expect_equal(attr(pics$patches, "tiles"), 4L)
  expect_equal(unname(sqrt(rowSums(pics$image^2))), rep(1, 36), tolerance = 1e-3)
  expect_equal(attr(pics, "model")$arch, "ViT-B-32")
  # the vignette's steps 4 and 5
  images <- images[match(rownames(pics$image), images$id), ]
  sniglets <- discoverSniglets(pics$patches, k = 40)
  scores <- snigletScores(pics$patches, sniglets$centroids)
  key <- keyFromSniglets(scores, images, sniglets, method = "rpart")
  expect_length(key$validate(), 0)
  expect_setequal(unique(key$leads$Taxon[nzchar(key$leads$Taxon) & !is.na(key$leads$Taxon)]), unique(images$label))
  expect_equal(classify(key, scores)$result, images$label)                  # every training photo keys out right
  expect_equal(keyTiles(key), 4L)
  # new photos are scored against the key from their embeddings alone
  new <- loadEmbeddings(emb(files[2]))
  expect_equal(rownames(new$image), paste0("unknown", 1:6))
  got <- classify(key, featureScores(key, patches = new$patches))$result
  truth <- c("banana", "blueberry", "kiwi", "lemon", "pineapple", "strawberry")
  expect_gte(sum(got == truth), 5)
  # questions in words, from the text embeddings
  txt <- loadEmbeddings(emb(files[3]))
  expect_true(is.matrix(txt)); expect_equal(dim(txt), c(14L, 512L))
  vocab <- data.frame(feature = c("a smooth skin", "a round shape", "a yellow colour", "green leaves on top"),
                      opposite = c("a rough skin", "a long shape", "a dark colour", "no leaves"), stringsAsFactors = FALSE)
  template <- "a photo of a fruit with {x}"
  expect_true(all(vocabularyPrompts(vocab, template) %in% rownames(txt)))
  qkey <- keyFromClusters(pics$image, images, vocab, txt, template = template)
  expect_length(qkey$validate(), 0)
  expect_equal(qkey$leads$Character[1:2], c("Has a smooth skin", "Has a rough skin"))
  # naming a photo: compare it with the texts, as suggestSpecies() does
  sim <- new$image %*% t(txt[sprintf("a photo of %s.", truth), ])
  expect_gte(sum(truth[max.col(sim)] == truth), 5)
  # BioCLIP on the Montana trees: each photo is nearest the name of its own species
  mt <- loadEmbeddings(emb(files[4]))
  expect_equal(dim(mt$image), c(14L, 512L)); expect_equal(dim(mt$texts), c(11L, 512L))
  taxa <- unique(montanaKey()$leads$Taxon); taxa <- taxa[!is.na(taxa) & nzchar(taxa)]
  expect_setequal(rownames(mt$texts), sprintf("a photo of %s.", scientificPart(taxa)))
  best <- sub("^a photo of (.*)\\.$", "\\1", rownames(mt$texts)[max.col(mt$image %*% t(mt$texts))])
  named <- !grepl("^feature_", rownames(mt$image))
  species <- tolower(sub(" ", "_", best[named]))
  expect_gte(sum(startsWith(rownames(mt$image)[named], species)), 12)
  expect_match(attr(mt, "model")$arch, "bioclip")
})

test_that("a key is built from loaded embeddings exactly as from fresh ones", {
  skip_if_not_installed("jsonlite")
  sv <- syntheticVision(per_label = 3)
  file <- tempfile()
  saveEmbeddings(list(image = sv$image, patches = sv$patches), file)
  back <- loadEmbeddings(file)
  build <- function(patches) {
    sn <- discoverSniglets(patches, k = 4, nstart = 1, seed = 1)
    scores <- snigletScores(patches, sn$centroids)
    list(key = keyFromSniglets(scores, sv$images, sn, method = "rpart"), scores = scores)
  }
  a <- build(sv$patches); b <- build(back$patches)
  expect_equal(b$scores, a$scores, tolerance = 1e-5)
  expect_equal(b$key$leads$Taxon, a$key$leads$Taxon)
  expect_length(b$key$validate(), 0)
})

test_that("model names resolve to folders and Hugging Face repositories", {
  cache <- tempfile("cache")
  dir <- tempfile("model"); dir.create(dir)
  expect_equal(onxResolve(dir, cache), list(dir = dir))
  expect_equal(onxResolve(paste0("local-dir:", dir), cache), list(dir = dir))
  expect_error(onxResolve("local-dir:/no/such/folder", cache), "No such folder")
  r <- onxResolve("clip-vit-base-patch32", cache)
  expect_equal(r$repo, "Xenova/clip-vit-base-patch32")
  expect_equal(r$dir, file.path(cache, "Xenova--clip-vit-base-patch32"))
  expect_equal(onxResolve("ViT-B-32", cache)$repo, "Xenova/clip-vit-base-patch32")
  expect_equal(onxResolve("hf-hub:org/some-model", cache)$repo, "org/some-model")
  expect_equal(onxResolve("org/some.model_2", cache)$dir, file.path(cache, "org--some.model_2"))
  expect_equal(onxResolve("BioCLIP", cache)$repo, "imageomics/bioclip")
  expect_error(onxResolve("no such model", cache), "exportOnnxModel")
  expect_error(onxResolve(c("a", "b"), cache), "one model name")
  # where exportOnnxModel() writes is where the same name is looked for
  expect_equal(onxExportDir("bioclip", cache = cache), onxResolve("bioclip", cache)$dir)
  expect_equal(onxExportDir("hf-hub:org/m", cache = cache), onxResolve("hf-hub:org/m", cache)$dir)
  expect_equal(basename(onxExportDir("ViT-B-16", "laion2b_s34b_b88k", cache)), "ViT-B-16-laion2b_s34b_b88k")
  # your own conversion of a model with a ready-made copy does not land in that copy's folder
  expect_equal(basename(onxExportDir("ViT-B-32", cache = cache)), "ViT-B-32-openai")
  expect_match(onnxCache(), "onnx$")
  withr::local_options(dimoose.onnx.cache = cache)
  expect_equal(onnxCache(), cache)
})

# A pretend Hub: `files` are the paths a repository has; every request is recorded.
fakeHub <- function(files, content = list()) {
  seen <- character()
  list(
    fetch = function(url, dest) {
      seen <<- c(seen, url)
      path <- sub("^https://huggingface.co/[^/]+/[^/]+/resolve/main/", "", url)
      if (!path %in% files) return(FALSE)
      dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
      writeLines(if (is.null(content[[path]])) "x" else content[[path]], dest)
      TRUE
    },
    seen = function() sub("^https://huggingface.co/", "", seen))
}

test_that("only the files a call needs are downloaded, and only once", {
  skip_if_not_installed("jsonlite")
  tjs <- c("config.json", "preprocessor_config.json", "tokenizer.json", "onnx/vision_model.onnx", "onnx/vision_model_quantized.onnx",
           "onnx/vision_model_fp16.onnx", "onnx/text_model.onnx", "onnx/text_model_quantized.onnx")
  hub <- fakeHub(tjs)
  dir <- tempfile("repo")
  got <- onxFetchRepo("org/m", dir, "int8", "fp32", fetch = hub$fetch, quiet = TRUE)
  expect_equal(got, list(image = "onnx/vision_model_quantized.onnx", text = "onnx/text_model.onnx"))
  expect_setequal(list.files(dir, recursive = TRUE),
                  c("config.json", "preprocessor_config.json", "tokenizer.json", "onnx/vision_model_quantized.onnx", "onnx/text_model.onnx"))
  expect_true(all(grepl("^org/m/resolve/main/", hub$seen())))
  # a second call asks for nothing; another precision asks for one more file
  n <- length(hub$seen())
  onxFetchRepo("org/m", dir, "int8", "fp32", fetch = hub$fetch, quiet = TRUE)
  expect_length(hub$seen(), n)
  onxFetchRepo("org/m", dir, "fp16", "fp32", fetch = hub$fetch, quiet = TRUE)
  expect_equal(hub$seen()[-seq_len(n)], "org/m/resolve/main/onnx/vision_model_fp16.onnx")
  # without texts, the text encoder and tokenizer stay on the Hub
  dir2 <- tempfile("repo")
  got <- onxFetchRepo("org/m", dir2, "fp32", "fp32", text = FALSE, fetch = hub$fetch, quiet = TRUE)
  expect_null(got$text)
  expect_false(any(grepl("text_model|tokenizer", list.files(dir2, recursive = TRUE))))
  said <- capture_messages(onxFetchRepo("org/m", tempfile("repo"), "fp32", "fp32", text = FALSE, fetch = hub$fetch))
  expect_match(said, "Downloading org/m/.*once", all = TRUE)
  # a precision the repository lacks
  expect_error(onxFetchRepo("org/m", dir, "fp32", "fp16", fetch = hub$fetch, quiet = TRUE), "no file onnx/text_model_fp16.onnx")
})

test_that("a repository in dimoose's own layout is read from its dimoose_onnx.json", {
  skip_if_not_installed("jsonlite")
  cfg <- '{"image_encoder": {"fp32": {"file": "image_encoder.onnx"}, "int8": {"file": "image_encoder_int8.onnx"}},
           "text_encoder": {"fp32": {"file": "text_encoder.onnx"}}, "tokenizer": "tokenizer.json"}'
  hub <- fakeHub(c("dimoose_onnx.json", "image_encoder.onnx", "image_encoder_int8.onnx", "text_encoder.onnx", "tokenizer.json"),
                 list("dimoose_onnx.json" = cfg))
  dir <- tempfile("repo")
  got <- onxFetchRepo("me/bioclip-onnx", dir, "int8", "fp32", fetch = hub$fetch, quiet = TRUE)
  expect_equal(got, list(image = "image_encoder_int8.onnx", text = "text_encoder.onnx"))
  expect_setequal(list.files(dir), c("dimoose_onnx.json", "image_encoder_int8.onnx", "text_encoder.onnx", "tokenizer.json"))
  expect_error(onxFetchRepo("me/bioclip-onnx", dir, "fp16", "fp32", fetch = hub$fetch, quiet = TRUE), "no fp16 image encoder; it has: fp32, int8")
})

test_that("a repository without an ONNX model says how to convert it", {
  hub <- fakeHub(c("open_clip_config.json", "open_clip_pytorch_model.bin"))
  dir <- tempfile("repo")
  expect_error(onxFetchRepo("imageomics/bioclip", dir, "fp32", "fp32", fetch = hub$fetch, quiet = TRUE),
               "exportOnnxModel\\(\"hf-hub:imageomics/bioclip\"\\)")
  expect_equal(hub$seen(), paste0("imageomics/bioclip/resolve/main/", c("dimoose_onnx.json", "preprocessor_config.json")))
})

test_that("onnxModel fetches the model, loads it and reports where its files are", {
  skip_if_not_installed("reticulate")
  skip_if_not_installed("jsonlite")
  loaded <- NULL
  local_mocked_bindings(pyOnnx = function() list(load_model = function(folder, precision, text_precision, threads) {
    loaded <<- list(folder = folder, precision = precision, text_precision = text_precision, threads = threads)
    list(spec = list(library = "onnxruntime 1", arch = "openai/clip-vit-base-patch32", dim = 512L, layout = "transformers.js", precision = precision),
         image_file = file.path(folder, "onnx", "vision_model_quantized.onnx"), text_file = NULL)
  }))
  hub <- fakeHub(c("config.json", "preprocessor_config.json", "tokenizer.json", "onnx/vision_model_quantized.onnx", "onnx/text_model_quantized.onnx"))
  cache <- tempfile("cache")
  # the ready-made int8 file is a rough copy of the model, and says so
  expect_warning(m <- suppressMessages(onnxModel(precision = "int8", cache = cache, fetch = hub$fetch, threads = 2)),
                 "rough copy.*exportOnnxModel\\(\"ViT-B-32\"\\)")
  expect_s3_class(m, "dimooseVisionModel")
  expect_equal(basename(loaded$folder), "Xenova--clip-vit-base-patch32")
  expect_equal(loaded[c("precision", "text_precision", "threads")], list(precision = "int8", text_precision = "int8", threads = 2L))
  expect_equal(m$files$repo, "Xenova/clip-vit-base-patch32")
  expect_equal(m$files$imageUrl, "https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/onnx/vision_model_quantized.onnx")
  expect_match(m$files$image, "vision_model_quantized.onnx$")
  # the ready-made export goes by open_clip's name for the same weights
  expect_equal(m$spec$arch, "ViT-B-32")
  expect_equal(m$spec$repository, "Xenova/clip-vit-base-patch32")
  expect_output(print(m), "ViT-B-32 \\(onnxruntime 1\\), 512 dimensions")
  expect_true(all(c("model_arch", "model_precision") %in% modelMeta(m)$key))
  # a local folder needs no fetch; a folder that is not a model is refused before Python is touched
  dir <- tempfile("model"); dir.create(dir); writeLines("{}", file.path(dir, "dimoose_onnx.json"))
  m2 <- onnxModel(dir, fetch = function(...) stop("no download for a local folder"))
  expect_null(m2$files$repo); expect_null(m2$files$imageUrl)
  empty <- tempfile("empty"); dir.create(empty)
  expect_error(onnxModel(empty), "not an ONNX model folder")
  expect_error(onnxModel(precision = "int4"), "should be one of")
  expect_error(onnxModel(dir, threads = "many"), "`threads` must be a number")
  expect_error(onnxModel(dir, threads = NA), "`threads` must be a number")
  # the other precisions of the ready-made model do not warn
  full <- fakeHub(c("config.json", "preprocessor_config.json", "tokenizer.json", "onnx/vision_model.onnx", "onnx/text_model.onnx"))
  expect_no_warning(suppressMessages(onnxModel(precision = "fp32", cache = tempfile("cache"), fetch = full$fetch)))
})

test_that("a ready-made int8 encoder that does not work is refused before anything is downloaded", {
  skip_if_not_installed("reticulate")
  local_mocked_bindings(pyOnnx = function() stop("Python must not be reached"))
  asked <- 0
  expect_error(onnxModel("mobileclip-s0", precision = "int8", cache = tempfile("cache"), fetch = function(...) { asked <<- asked + 1; FALSE }),
               "does not work.*fp16")
  expect_equal(asked, 0)
  expect_null(onxInt8Note("org/some-model")); expect_null(onxInt8Note(NULL))
})

test_that("a model converted here comes before the ready-made copy of the same name", {
  cache <- tempfile("cache")
  # nothing converted: the ready-made copy
  expect_equal(onxResolve("ViT-B-32", cache)$repo, "Xenova/clip-vit-base-patch32")
  expect_equal(onxNameFor("ViT-B-32", cache = cache), "ViT-B-32")
  # exportOnnxModel("ViT-B-32") writes here; the same name then means that folder
  own <- onxExportDir("ViT-B-32", cache = cache)
  dir.create(own, recursive = TRUE); writeLines("{}", file.path(own, "dimoose_onnx.json"))
  expect_equal(onxResolve("ViT-B-32", cache), list(dir = own))
  expect_equal(onxNameFor("ViT-B-32", cache = cache), own)
  # the long name still means the ready-made copy, and an explicit repository is never redirected
  expect_equal(onxResolve("clip-vit-base-patch32", cache)$repo, "Xenova/clip-vit-base-patch32")
  expect_equal(onxResolve("Xenova/clip-vit-base-patch32", cache)$repo, "Xenova/clip-vit-base-patch32")
  # BioCLIP's repository has no ONNX files: a converted folder is a local model,
  # so nothing is looked for on the Hub and no page is pointed at a file that is not there
  expect_equal(onxResolve("bioclip", cache)$repo, "imageomics/bioclip")
  bio <- onxExportDir("bioclip", cache = cache)
  dir.create(bio); writeLines("{}", file.path(bio, "dimoose_onnx.json"))
  expect_equal(onxResolve("bioclip", cache), list(dir = bio))
  expect_equal(onxResolve("hf-hub:imageomics/bioclip", cache), list(dir = bio))
  skip_if_not_installed("reticulate")
  local_mocked_bindings(pyOnnx = function() list(load_model = function(folder, precision, text_precision, threads) {
    list(spec = list(arch = "hf-hub:imageomics/bioclip", dim = 512L, layout = "dimoose"), image_file = file.path(folder, "image_encoder.onnx"), text_file = NULL)
  }))
  m <- onnxModel("bioclip", cache = cache, fetch = function(...) stop("nothing to download for a converted model"))
  expect_null(m$files$repo); expect_null(m$files$imageUrl); expect_null(m$spec$repository)
})

test_that("a Python without onnxruntime, and a download that fails, say what to do", {
  said <- onxPythonAdvice("it has no Python package onnxruntime", pythonRequirements("onnx"), "/some/python")
  expect_match(said, "/some/python", fixed = TRUE)
  expect_match(said, "no Python package onnxruntime", fixed = TRUE)
  expect_match(said, "reticulate::py_install\\(c\\(\"onnxruntime")
  expect_match(said, "without RETICULATE_PYTHON")
  skip_if_not_installed("httr")
  # nothing listens on this port: the same failure as being offline
  dest <- file.path(tempfile("dl"), "model.onnx")
  expect_error(onxDownload("http://127.0.0.1:9/org/m/resolve/main/model.onnx", dest),
               "Could not download http://127.0.0.1:9/.*check the internet connection.*copy the model's folder")
  expect_false(file.exists(dest)); expect_false(file.exists(paste0(dest, ".part")))
  expect_error(onxFetchRepo("org/m", tempfile("repo"), "fp32", "fp32", quiet = TRUE,
                            fetch = function(url, dest) onxDownload(sub("https://huggingface.co", "http://127.0.0.1:9", url), dest)),
               "check the internet connection")
})

test_that("visionModel(backend = \"onnx\") hands over to onnxModel", {
  skip_if_not_installed("reticulate")
  seen <- NULL
  local_mocked_bindings(onnxModel = function(name, precision, python = NULL, ...) { seen <<- list(name = name, precision = precision); "model" })
  cache <- tempfile("cache")
  withr::local_options(dimoose.onnx.cache = cache)
  expect_equal(visionModel(backend = "onnx"), "model")
  expect_equal(seen, list(name = "ViT-B-32", precision = "fp32"))
  visionModel(name = "bioclip", backend = "onnx", precision = "int8")
  expect_equal(seen, list(name = "bioclip", precision = "int8"))
  visionModel(name = "hf-hub:org/m", backend = "onnx"); expect_equal(seen$name, "hf-hub:org/m")
  dir <- tempfile("model"); dir.create(dir)
  visionModel(name = dir, backend = "onnx"); expect_equal(seen$name, dir)
  visionModel(dir, backend = "onnx"); expect_equal(seen$name, dir)          # a folder as the first argument
  # other weights of a built-in architecture: only if they were converted
  expect_error(visionModel(name = "ViT-B-16", pretrained = "laion2b_s34b_b88k", backend = "onnx"),
               "exportOnnxModel\\(\"ViT-B-16\", pretrained = \"laion2b_s34b_b88k\"\\)")
  made <- onxExportDir("ViT-B-16", "laion2b_s34b_b88k", cache); dir.create(made, recursive = TRUE)
  writeLines("{}", file.path(made, "dimoose_onnx.json"))
  visionModel(name = "ViT-B-16", pretrained = "laion2b_s34b_b88k", backend = "onnx"); expect_equal(seen$name, made)
  expect_error(visionModel(weights = tempfile(fileext = ".pt"), backend = "onnx"), "exportOnnxModel")
  expect_error(visionModel(backend = "tensorflow"), "should be one of")
})

test_that("exportOnnxModel runs the export script with the model's arguments", {
  cache <- tempfile("cache")
  withr::local_options(dimoose.onnx.cache = cache)
  ran <- NULL
  ok <- function(command, args) {
    ran <<- list(command = command, args = args)
    writeLines("{}", file.path(args[which(args == "--out") + 1], "dimoose_onnx.json"))
    0L
  }
  dir <- exportOnnxModel("bioclip", python = "/some/python", run = ok)
  expect_equal(normalizePath(dir), normalizePath(file.path(cache, "imageomics--bioclip")))
  expect_equal(ran$command, "/some/python")
  expect_equal(basename(ran$args[1]), "export_onnx.py")
  expect_true(file.exists(ran$args[1]))
  expect_equal(ran$args[which(ran$args == "--model") + 1], "hf-hub:imageomics/bioclip")
  expect_equal(ran$args[which(ran$args == "--quantize") + 1:2], c("int8", "fp16"))
  out <- tempfile("out")
  w <- tempfile(fileext = ".pt"); writeLines("w", w)
  exportOnnxModel("ViT-B-32", weights = w, dir = out, quantize = character(0), python = "py", run = ok)
  expect_false("--quantize" %in% ran$args)
  expect_equal(ran$args[which(ran$args == "--weights") + 1], normalizePath(w))
  expect_equal(ran$args[which(ran$args == "--out") + 1], normalizePath(out))
  # without `python`, uv provides one with both requirements files (when uv is installed)
  local_mocked_bindings(onxUv = function() "/usr/local/bin/uv")
  exportOnnxModel("bioclip", dir = out, run = ok)
  expect_equal(ran$command, "/usr/local/bin/uv")
  expect_equal(ran$args[1:2], c("run", "--no-project"))
  expect_equal(basename(ran$args[which(ran$args == "--with-requirements") + 1]), c("requirements.txt", "requirements-export.txt"))
  expect_error(exportOnnxModel("bioclip", dir = tempfile("fail"), python = "py", run = function(command, args) 1L), "conversion failed")
})

test_that("the ONNX backend's requirements leave out torch", {
  req <- pythonRequirements("onnx")
  expect_setequal(sub("[=<>~!].*$", "", req), c("onnxruntime", "tokenizers", "pillow", "numpy"))
  expect_true(file.exists(system.file("python", "requirements-export.txt", package = "dimoose")))
  expect_true(file.exists(system.file("python", "export_onnx.py", package = "dimoose")))
})

test_that("exportBrowserModel writes the encoder, the text embeddings and a manifest that describes them", {
  skip_if_not_installed("jsonlite")
  encoder <- tempfile(fileext = ".onnx"); writeBin(as.raw(1:200), encoder)
  fm <- fakeOnnxModel(encoder)
  key <- smallKey()
  dir <- file.path(tempfile("site"), "model")
  out <- exportBrowserModel(key, fm$model, dir)
  expect_equal(out, file.path(dir, "model.json"))
  expect_setequal(list.files(dir), c("image_encoder.onnx", "model.json", "text_embeddings.bin"))
  expect_equal(readBin(file.path(dir, "image_encoder.onnx"), "raw", 300), as.raw(1:200))
  man <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  expect_equal(man$format, "dimoose-browser-model")
  expect_equal(man$version, 1)
  expect_equal(man$key, list(desc = "Three trees", taxa = 3L))
  expect_equal(man$model$dim, 8)
  expect_equal(man$image_encoder[c("file", "bytes", "precision", "input", "output", "normalized")],
               list(file = "image_encoder.onnx", bytes = 200L, precision = "int8", input = "pixel_values", output = "image_embeds", normalized = FALSE))
  expect_null(man$image_encoder$url)
  expect_equal(unlist(man$image_encoder$input_shape), c(1, 3, 224, 224))
  expect_equal(unlist(man$preprocess$mean), c(0.48145466, 0.4578275, 0.40821073))
  expect_equal(unlist(man$preprocess$std), c(0.26862954, 0.26130258, 0.27577711))
  expect_equal(man$preprocess[c("image_size", "resize", "resize_to", "interpolation", "crop", "layout", "channels")],
               list(image_size = 224L, resize = "shortest", resize_to = 224L, interpolation = "bicubic", crop = "center", layout = "NCHW", channels = "RGB"))
  expect_equal(man$preprocess$rescale, 1 / 255)
  expect_equal(man$logit_scale, 100)
  # the labels are the key's results, in the order of the embeddings' rows;
  # the scientific name goes into the prompt when the result has one
  expect_equal(vapply(man$labels, function(l) l$taxon, ""), c("Box elder (Acer negundo)", "Paper birch (Betula papyrifera)", "the brown one"))
  expect_equal(vapply(man$labels, function(l) l$name, ""), c("Acer negundo", "Betula papyrifera", "the brown one"))
  prompts <- vapply(man$labels, function(l) l$prompt, "")
  expect_equal(prompts, c("a photo of Acer negundo.", "a photo of Betula papyrifera.", "a photo of the brown one."))
  expect_equal(fm$calls$embed_texts[[1]], prompts)
  te <- man$text_embeddings
  expect_equal(te[c("file", "dtype", "byte_order", "order", "normalized", "prompt")],
               list(file = "text_embeddings.bin", dtype = "float32", byte_order = "little", order = "row-major", normalized = TRUE, prompt = "a photo of %s."))
  expect_equal(unlist(te$shape), c(3, 8))
  # the binary file is exactly shape[1] x shape[2] float32, row by row
  bin <- file.path(dir, "text_embeddings.bin")
  expect_equal(file.size(bin), 3 * 8 * 4)
  got <- matrix(readBin(bin, "numeric", 24, size = 4, endian = "little"), 3, 8, byrow = TRUE)
  expect_equal(got, unname(embedTexts(fm$model, prompts)), tolerance = 1e-6)
  expect_equal(rowSums(got^2), c(1, 1, 1), tolerance = 1e-5)
})

test_that("the encoder can be another file or a web address, and texts can be embedded ahead", {
  skip_if_not_installed("jsonlite")
  encoder <- tempfile(fileext = ".onnx"); writeBin(as.raw(1:10), encoder)
  fm <- fakeOnnxModel(encoder)
  key <- smallKey()
  read <- function(dir) jsonlite::fromJSON(file.path(dir, "model.json"), simplifyVector = FALSE)
  # on the Hub: nothing is copied
  dir <- tempfile("site")
  exportBrowserModel(key, fm$model, dir, encoder = "hub")
  expect_setequal(list.files(dir), c("model.json", "text_embeddings.bin"))
  man <- read(dir)
  expect_null(man$image_encoder$file)
  expect_equal(man$image_encoder$url, "https://huggingface.co/org/model/resolve/main/onnx/vision_model_quantized.onnx")
  expect_equal(man$image_encoder$precision, "int8")
  # any address: its precision and size are not known
  exportBrowserModel(key, fm$model, dir, encoder = "https://example.org/enc.onnx", prompt = "%s")
  man <- read(dir)
  expect_equal(man$image_encoder$url, "https://example.org/enc.onnx")
  expect_null(man$image_encoder$precision); expect_null(man$image_encoder$bytes)
  expect_equal(man$labels[[1]]$prompt, "Acer negundo")
  # another file, with a model that has no encoder file of its own (a torch model)
  torch <- fakeOnnxModel()
  other <- tempfile(fileext = ".onnx"); writeBin(as.raw(1:50), other)
  dir2 <- tempfile("site")
  exportBrowserModel(key, torch$model, dir2, encoder = other)
  expect_equal(file.size(file.path(dir2, "image_encoder.onnx")), 50)
  expect_equal(read(dir2)$image_encoder$bytes, 50)
  expect_error(exportBrowserModel(key, torch$model, tempfile()), "not an ONNX model")
  expect_error(exportBrowserModel(key, torch$model, tempfile(), encoder = "hub"), "did not come from the Hugging Face Hub")
  expect_error(exportBrowserModel(key, torch$model, tempfile(), encoder = "/no/such/file.onnx"), "No such image encoder file")
  # embeddings made earlier are used as they are, in the labels' order
  prompts <- sprintf("a photo of %s.", c("Acer negundo", "Betula papyrifera", "the brown one"))
  ahead <- embedTexts(fm$model, rev(prompts))
  n <- length(fm$calls$embed_texts)
  dir3 <- tempfile("site")
  exportBrowserModel(key, fm$model, dir3, textEmb = ahead)
  expect_length(fm$calls$embed_texts, n)
  got <- matrix(readBin(file.path(dir3, "text_embeddings.bin"), "numeric", 24, size = 4, endian = "little"), 3, 8, byrow = TRUE)
  expect_equal(got, unname(ahead[prompts, ]), tolerance = 1e-6)
  expect_error(exportBrowserModel(key, fm$model, tempfile(), textEmb = ahead[1:2, ]), "lacks rows for 1 prompt")
  expect_error(exportBrowserModel(key, fm$model, tempfile(), textEmb = cbind(ahead, 0)), "9 dimensions, but the model has 8")
})

test_that("the manifest is UTF-8, and one label or two labels with one name keep its shape", {
  skip_if_not_installed("jsonlite")
  encoder <- tempfile(fileext = ".onnx"); writeBin(as.raw(1:10), encoder)
  fm <- fakeOnnxModel(encoder)
  mk <- function(taxa, desc) keyFromLeads(data.frame(Statement = c(1, 1), Choice = c("a", "b"), Character = c("x", "y"), Next = NA,
                                                     Taxon = taxa, stringsAsFactors = FALSE), desc = desc)
  read <- function(dir) jsonlite::fromJSON(file.path(dir, "model.json"), simplifyVector = FALSE)
  taxa <- c("Bläuling (Polyommatus icarus)", "ヒノキ \U0001F34C \"quoted\" \\ back")
  dir <- tempfile("site")
  exportBrowserModel(mk(taxa, "Schlüssel — für Bläulinge"), fm$model, dir)
  bytes <- readBin(file.path(dir, "model.json"), "raw", 1e5)
  expect_true(validUTF8(rawToChar(bytes)))
  expect_equal(bytes[1], charToRaw("{"))                                   # no byte order mark
  man <- read(dir)
  expect_equal(man$key$desc, "Schlüssel — für Bläulinge")
  expect_equal(vapply(man$labels, function(l) l$taxon, ""), taxa)
  expect_equal(man$labels[[2]]$prompt, paste0("a photo of ", taxa[2], "."))
  # two results with one scientific name: two labels and two rows, both the same
  exportBrowserModel(mk(c("Box elder (Acer negundo)", "Manitoba maple (Acer negundo)"), "k"), fm$model, dir)
  man <- read(dir)
  expect_equal(unlist(man$text_embeddings$shape), c(2, 8)); expect_length(man$labels, 2)
  rows <- matrix(readBin(file.path(dir, "text_embeddings.bin"), "numeric", 16, size = 4, endian = "little"), 2, 8, byrow = TRUE)
  expect_equal(rows[1, ], rows[2, ])
  # one label: shape, labels, mean and std are still arrays in the JSON
  exportBrowserModel(mk(c("only one", "only one"), "k"), fm$model, dir)
  text <- paste(readLines(file.path(dir, "model.json"), encoding = "UTF-8"), collapse = "")
  expect_match(text, "\"shape\": \\[1, 8\\]")
  expect_match(text, "\"labels\": \\[\\s*\\{")
  expect_match(text, "\"input_shape\": \\[1, 3, 224, 224\\]")
  expect_equal(file.size(file.path(dir, "text_embeddings.bin")), 8 * 4)
  # every documented field is there, and nothing else
  man <- read(dir)
  expect_named(man, c("format", "version", "key", "model", "image_encoder", "preprocess", "text_embeddings", "labels", "logit_scale"))
  expect_named(man$key, c("desc", "taxa"))
  expect_named(man$model, c("arch", "pretrained", "dim", "library"))
  expect_named(man$image_encoder, c("file", "url", "bytes", "precision", "input", "input_type", "input_shape", "output", "normalized"))
  expect_named(man$preprocess, c("image_size", "resize", "resize_to", "interpolation", "crop", "rescale", "mean", "std", "layout", "channels"))
  expect_named(man$text_embeddings, c("file", "dtype", "byte_order", "shape", "order", "normalized", "prompt"))
  expect_named(man$labels[[1]], c("taxon", "name", "prompt"))
})

test_that("exportBrowserModel refuses what a page could not use", {
  skip_if_not_installed("jsonlite")
  fm <- fakeOnnxModel(tempfile())
  key <- smallKey()
  expect_error(exportBrowserModel("key", fm$model, tempfile()), "dimoose object")
  expect_error(exportBrowserModel(key, list(), tempfile()), "vision model")
  expect_error(exportBrowserModel(key, fm$model, tempfile(), prompt = "a photo"), "%s")
  plain <- fakeVisionModel()$model        # says nothing about how images are prepared
  expect_error(exportBrowserModel(key, plain, tempfile(), encoder = "https://example.org/e.onnx"), "how images are prepared")
  # one prompt, with one %s; one folder; one encoder that is a file
  expect_error(exportBrowserModel(key, fm$model, tempfile(), prompt = c("a %s", "b %s")), "%s")
  expect_error(exportBrowserModel(key, fm$model, tempfile(), prompt = "100% %s"), "write %% for a percent sign")
  expect_error(exportBrowserModel(key, fm$model, tempfile(), prompt = "%s and %s"), "%s once")
  expect_error(exportBrowserModel(key, fm$model, NULL), "`dir` must be one folder name")
  notDir <- tempfile(); writeLines("x", notDir)
  expect_error(exportBrowserModel(key, fm$model, notDir, encoder = "https://example.org/e.onnx"), "is a file")
  ok <- fakeOnnxModel(notDir)
  expect_error(exportBrowserModel(key, ok$model, tempfile(), encoder = c("a.onnx", "b.onnx")), "`encoder` must be")
  expect_error(exportBrowserModel(key, ok$model, tempfile(), encoder = NA), "`encoder` must be")
  expect_error(exportBrowserModel(key, ok$model, tempfile(), encoder = tempdir()), "No such image encoder file")
  # a text embedding of zeros would put NaN in the file the page reads
  prompts <- sprintf("a photo of %s.", c("Acer negundo", "Betula papyrifera", "the brown one"))
  zero <- embedTexts(ok$model, prompts); zero[2, ] <- 0
  expect_error(exportBrowserModel(key, ok$model, tempfile(), textEmb = zero), "Betula papyrifera.*all zeros")
  # a percent sign in a prompt is written with %%
  d <- tempfile("site"); exportBrowserModel(key, ok$model, d, prompt = "100%% %s")
  expect_equal(jsonlite::fromJSON(file.path(d, "model.json"), simplifyVector = FALSE)$labels[[1]]$prompt, "100% Acer negundo")
  big <- tempfile(fileext = ".onnx")
  local_mocked_bindings(onxSize = function(path) 351e6)
  writeBin(as.raw(1), big)
  expect_message(exportBrowserModel(key, fakeOnnxModel(big)$model, tempfile("site")), "351 MB")
})

# ---- with a real model -------------------------------------------------------
# These need Python with onnxruntime and a model folder: set RETICULATE_PYTHON
# and DIMOOSE_ONNX_MODEL (a folder written by exportOnnxModel(), or a
# downloaded copy of Xenova/clip-vit-base-patch32). Nothing is downloaded.
skipUnlessOnnx <- function() {
  skip_if_not_installed("reticulate")
  skip_if_not_installed("jsonlite")
  dir <- Sys.getenv("DIMOOSE_ONNX_MODEL")
  skip_if(!nzchar(dir) || !dir.exists(dir), "DIMOOSE_ONNX_MODEL not set")
  skip_on_cran()
  skip_if(!nzchar(Sys.getenv("RETICULATE_PYTHON")), "RETICULATE_PYTHON not set")
  has <- isTRUE(tryCatch(reticulate::py_eval("__import__('importlib.util').util.find_spec('onnxruntime') is not None"),
                         error = function(e) FALSE))
  skip_if_not(has, "onnxruntime not installed")
  dir
}

test_that("an ONNX model embeds images and texts like any vision model", {
  dir <- skipUnlessOnnx()
  m <- visionModel(name = dir, backend = "onnx")
  expect_s3_class(m, "dimooseVisionModel")
  expect_equal(m$spec$backend, "onnx")
  expect_true(file.exists(m$files$image))
  images <- imageSet(system.file("extdata", "pics", package = "dimoose"))[c(1:2, 7:8, 13:14), ]
  emb <- embedImages(m, images, tiles = 2)
  expect_equal(dim(emb$image), c(6L, m$spec$dim))
  expect_equal(dim(emb$patches), c(6L, 4L, m$spec$dim))
  expect_equal(rownames(emb$image), images$id)
  expect_equal(unname(sqrt(rowSums(emb$image^2))), rep(1, 6), tolerance = 1e-4)
  t <- embedTexts(m, c("a photo of a banana", "a photo of a kiwi"))
  expect_equal(dim(t), c(2L, m$spec$dim))
  expect_equal(rownames(t), c("a photo of a banana", "a photo of a kiwi"))
  # photos of one fruit are closer to each other than to another fruit
  sim <- emb$image %*% t(emb$image)
  expect_gt(sim[1, 2], sim[1, 3])
  # saved and loaded, the embeddings score a key the same
  file <- tempfile(); saveEmbeddings(emb, file, model = m)
  back <- loadEmbeddings(file)
  expect_equal(back$patches, emb$patches, tolerance = 1e-6)
  expect_equal(attr(back, "model")$arch, m$spec$arch)
  sn <- discoverSniglets(emb$patches, k = 4, nstart = 1)
  scores <- snigletScores(emb$patches, sn$centroids)
  key <- patchExemplars(m, keyFromSniglets(scores, images, sn, method = "rpart"), images)
  expect_length(key$validate(), 0)
  expect_equal(unname(scoreImages(key, m, images)), unname(scores), tolerance = 1e-5)
  # the browser files, with the model's own encoder
  out <- exportBrowserModel(smallKey(), m, tempfile("site"), encoder = "https://example.org/e.onnx")
  man <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  expect_equal(unlist(man$text_embeddings$shape), c(3L, m$spec$dim))
  expect_equal(file.size(file.path(dirname(out), "text_embeddings.bin")), 3 * m$spec$dim * 4)
})

test_that("files download from the Hugging Face Hub, and a missing file is not an error", {
  skip_on_cran()
  skip_if_offline("huggingface.co")
  skip_if_unreachable("https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/preprocessor_config.json")
  skip_if_not_installed("jsonlite")
  dest <- file.path(tempfile("hub"), "preprocessor_config.json")
  expect_true(onxDownload(onxHubUrl("Xenova/clip-vit-base-patch32", "preprocessor_config.json"), dest))
  expect_equal(unlist(onxReadJson(dest)$image_mean), c(0.48145466, 0.4578275, 0.40821073))
  expect_false(file.exists(paste0(dest, ".part")))
  expect_false(onxDownload(onxHubUrl("Xenova/clip-vit-base-patch32", "no-such-file.json"), file.path(dirname(dest), "x.json")))
  expect_false(file.exists(file.path(dirname(dest), "x.json")))
})
