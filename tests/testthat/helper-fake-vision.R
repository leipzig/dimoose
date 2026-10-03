# A stand-in for visionModel() that needs no Python: the `mod` functions
# mimic inst/python/moose_vision.py (unnamed arrays, zero-based patch
# indices) but return the embeddings of a syntheticVision() set, looked up by
# file name. Every call is recorded in `calls` so tests can check what the R
# wrappers passed through.
fakeVisionModel <- function(sv = syntheticVision()) {
  calls <- new.env()
  calls$embed_images <- list()
  calls$embed_texts <- list()
  calls$exemplar_pngs <- list()
  calls$load_model <- list()
  ids <- function(paths) sub("\\.[^.]+$", "", basename(unlist(paths)))
  d <- ncol(sv$image)
  spec <- list(library = "open_clip", arch = "ViT-B-32", pretrained = "openai",
               weights_sha256 = NULL, image_size = 224L, dim = d)
  mod <- list(
    load_model = function(name, pretrained, weights) {
      calls$load_model <- c(calls$load_model, list(list(name = name, pretrained = pretrained, weights = weights)))
      list(spec = spec)
    },
    embed_images = function(py, paths, region = NULL, patches = TRUE) {
      calls$embed_images <- c(calls$embed_images, list(list(paths = unlist(paths), region = region, patches = patches)))
      image <- unname(sv$image[ids(paths), , drop = FALSE])
      # A crop sees a different picture: reverse the dimensions so tests can
      # tell cropped embeddings from whole-image ones
      if (!is.null(region)) image <- image[, rev(seq_len(d)), drop = FALSE]
      list(image = image, patches = if (isTRUE(patches)) unname(sv$patches[ids(paths), , , drop = FALSE]) else NULL)
    },
    embed_texts = function(py, texts) {
      calls$embed_texts <- c(calls$embed_texts, list(unlist(texts)))
      m <- t(vapply(unlist(texts), function(x) {
        v <- withr::with_seed(sum(utf8ToInt(x)), stats::rnorm(d))
        v / sqrt(sum(v^2))
      }, numeric(d)))
      unname(m)
    },
    exemplar_pngs = function(py, paths, patch_indices, pad = 48, size = 96) {
      calls$exemplar_pngs <- c(calls$exemplar_pngs, list(list(paths = unlist(paths), patch_indices = unlist(patch_indices), pad = pad, size = size)))
      as.list(paste0("PNG", seq_along(paths)))
    }
  )
  model <- structure(list(py = "fake-py", mod = mod, spec = spec), class = "mooseVisionModel")
  list(model = model, calls = calls, sv = sv)
}
