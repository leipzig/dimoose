# The Python packages the vision layer needs, from inst/python/requirements.txt.
pythonRequirements <- function() {
  req <- readLines(system.file("python", "requirements.txt", package = "moose"), warn = FALSE)
  req <- trimws(sub("#.*$", "", req))
  req[nzchar(req)]
}

pyVision <- local({
  mod <- NULL
  function() {
    if (!requireNamespace("reticulate", quietly = TRUE)) {
      stop("Install the reticulate package to embed images", call. = FALSE)
    }
    if (is.null(mod)) {
      # Declare what we need, so that reticulate (>= 1.41) can provide a Python
      # with these packages when the user has not chosen one. It has no effect
      # on a Python the user chose (use_python(), RETICULATE_PYTHON, ...).
      if (utils::packageVersion("reticulate") >= "1.41.0" && !reticulate::py_available(initialize = FALSE)) {
        reticulate::py_require(pythonRequirements())
      }
      mod <<- tryCatch(
        reticulate::import_from_path("moose_vision", path = system.file("python", package = "moose"), convert = TRUE),
        error = function(e) {
          cfg <- tryCatch(reticulate::py_config()$python, error = function(e) "unknown")
          stop("Could not load moose's Python code with the Python at ", cfg, ":\n", conditionMessage(e),
               "\nIt needs the Python packages ", paste(pythonRequirements(), collapse = ", "), ". Install them there with\n",
               "  reticulate::py_install(c(", paste0("\"", pythonRequirements(), "\"", collapse = ", "), "))\n",
               "or let reticulate provide a Python: restart R without RETICULATE_PYTHON set and without the `python` argument.",
               call. = FALSE)
        })
    }
    mod
  }
})

#' Load a vision model for embedding images
#'
#' Uses Python's open_clip through reticulate. You do not need to install
#' anything in Python yourself: the first call sets up a private Python with
#' the packages moose needs (`torch`, `open_clip_torch`, `pillow`, `numpy`)
#' and reuses it afterwards. That first call downloads them, which takes a
#' few minutes. This needs reticulate 1.41 or later.
#'
#' To use a Python of your own instead, give its path in `python`, or select
#' it with [reticulate::use_python()], [reticulate::use_virtualenv()] or the
#' `RETICULATE_PYTHON` environment variable before the first call, and install
#' the packages there with
#' `reticulate::py_install(c("torch", "open_clip_torch", "pillow", "numpy"))`.
#'
#' @section Other models, including BioCLIP:
#' Any open_clip model whose image side is a vision transformer works. The
#' key builders only see its embeddings, so nothing else changes.
#'
#' * `visionModel(name = "bioclip")` loads
#'   [BioCLIP](https://imageomics.github.io/bioclip/) and
#'   `visionModel(name = "bioclip-2")` BioCLIP 2, models trained on images of
#'   organisms, from the Hugging Face Hub. They are downloaded on first use.
#' * `name = "hf-hub:<organisation>/<model>"` loads any other open_clip model
#'   on the Hub, and `name = "local-dir:<folder>"` a copy you have downloaded
#'   (the folder holds the model's `open_clip_config.json` and weights file).
#' * `name` and `pretrained` together select one of open_clip's built-in
#'   models, e.g. `name = "ViT-B-16", pretrained = "laion2b_s34b_b88k"`.
#'
#' A key can only be followed with the model it was built with: use the same
#' model for [embedImages()] and later for [scoreImages()].
#'
#' BioCLIP's text side was trained on names of organisms, not on descriptions
#' of what they look like. It suits sniglets ([discoverSniglets()]), which use
#' images only, better than vocabulary questions ([keyFromClusters()]).
#'
#' @param weights Local checkpoint file: OpenAI's `ViT-B-32.pt`, or an
#'   open_clip checkpoint for the architecture `name`. If `NULL`, the weights
#'   are downloaded.
#' @param name The model: an open_clip architecture name, `"bioclip"`,
#'   `"bioclip-2"`, `"hf-hub:<organisation>/<model>"` or
#'   `"local-dir:<folder>"` (see below).
#' @param pretrained open_clip's tag for the weights to download for an
#'   architecture `name`; not used for the other kinds of `name`.
#' @param python Optional path to the Python executable to use (passed to
#'   [reticulate::use_python()]).
#' @return An object of class `mooseVisionModel` with `py` (the Python model)
#'   and `spec` (library, architecture, weights SHA-256, image size, ...).
#' @examples
#' \dontrun{
#' model <- visionModel()                    # CLIP ViT-B/32
#' model <- visionModel(name = "bioclip")    # BioCLIP, for photos of organisms
#' }
#' @export
visionModel <- function(weights = NULL, name = "ViT-B-32", pretrained = "openai", python = NULL) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Install the reticulate package to embed images", call. = FALSE)
  }
  if (!is.null(python)) reticulate::use_python(python, required = TRUE)
  known <- c(bioclip = "hf-hub:imageomics/bioclip", "bioclip-2" = "hf-hub:imageomics/bioclip-2")
  if (tolower(name) %in% names(known)) name <- known[[tolower(name)]]
  mod <- pyVision()
  py <- mod$load_model(name = name, pretrained = pretrained, weights = weights)
  structure(list(py = py, mod = mod, spec = py$spec), class = "mooseVisionModel")
}

#' @export
print.mooseVisionModel <- function(x, ...) {
  cat("<moose vision model> ", x$spec$arch, " (", x$spec$library, "), ", x$spec$dim, " dimensions\n", sep = "")
  invisible(x)
}

#' Model details as metadata rows
#' @param model A [visionModel()].
#' @return A key/value data frame with `model_*` keys.
#' @export
modelMeta <- function(model) {
  s <- model$spec
  s <- s[!vapply(s, is.null, logical(1))]
  data.frame(key = paste0("model_", names(s)), value = as.character(unlist(s)), stringsAsFactors = FALSE)
}

#' Embed images
#'
#' Returns one embedding per image and, for [discoverSniglets()], embeddings
#' of local regions of each image.
#'
#' By default the regions are **tiles**: overlapping windows cut out of the
#' image and embedded one by one, as if each were a whole image. A tile's
#' embedding describes only what is inside it, so tiles find parts and
#' surfaces that different images have in common (a stem end, a dimpled
#' peel). Tiles that are mostly plain background are left out. `tiles = 0` uses the model's own patch tokens instead, which is
#' faster (one pass per image) and is what fordera does, but in the last
#' layer of a CLIP model each token carries much of the whole image, so the
#' features found are less local.
#'
#' @param model A [visionModel()].
#' @param paths Image files, or an [imageSet()] (its `path` column is
#'   embedded and its `id` column names the rows).
#' @param region Optional crop `c(y0, y1, x0, x1)` as fractions, applied to
#'   every image before embedding.
#' @param patches If `TRUE`, also return the local embeddings.
#' @param tiles Size of the grid of tiles: `4` cuts 4 x 4 windows that
#'   overlap their neighbours by half. Several sizes give several scales
#'   (`c(2, 4)`). `0` uses the model's patch tokens.
#' @param minDetail Tiles with less detail than this (standard deviation of
#'   the grey levels, 0 to 255) are treated as empty background and match
#'   nothing.
#' @param minFill In a photo with a plain background (one colour around most
#'   of its border), tiles in which the subject covers less than this share
#'   are treated as empty too, so that features are about the subject and not
#'   about its backdrop. It has no effect on photos without a plain
#'   background.
#' @return A list: `image` (`images x d` matrix, rows named by image id: the
#'   file name without extension, or the `id` of an [imageSet()]) and
#'   `patches` (`images x regions x d` array, or `NULL`), which remembers the
#'   tiling in its `tiles` attribute.
#' @export
embedImages <- function(model, paths, region = NULL, patches = TRUE, tiles = 4, minDetail = 8, minFill = 0.5) {
  if (is.data.frame(paths)) {
    ids <- paths$id; paths <- paths$path
  } else {
    ids <- sub("\\.[^.]+$", "", basename(paths))
  }
  tiles <- as.integer(tiles[!is.na(tiles) & tiles > 0])
  out <- model$mod$embed_images(model$py, as.list(as.character(paths)), region = region, patches = patches,
                                tiles = if (length(tiles)) as.list(tiles) else NULL, min_detail = minDetail,
                                min_fill = minFill)
  image <- out$image; rownames(image) <- ids
  pt <- out$patches
  if (!is.null(pt)) {
    dimnames(pt) <- list(ids, NULL, NULL)
    attr(pt, "tiles") <- tiles
    attr(pt, "empty") <- c(minDetail = minDetail, minFill = minFill)
  }
  list(image = image, patches = pt)
}

#' Embed texts
#' @inheritParams embedImages
#' @param texts Character vector.
#' @return A `texts x d` matrix with the texts as row names.
#' @export
embedTexts <- function(model, texts) {
  m <- model$mod$embed_texts(model$py, as.list(as.character(texts)))
  rownames(m) <- texts
  m
}

#' Add example crops to a sniglet key
#'
#' Cuts out the example regions of each sniglet and of each lead, stores them
#' as PNGs in the key's `features` and `meta`, and points the leads at them
#' so [exportWizard()] shows them. A "Has" lead shows the sniglet in the
#' images that take that lead; a "Lacks" lead shows what its images have
#' instead (see [keyFromSniglets()]). The glossary shows each sniglet's
#' examples across all the images.
#'
#' @inheritParams embedImages
#' @param key A key from [keyFromSniglets()].
#' @param images The [imageSet()] the key was built from (for file paths).
#' @param pad Pixels of context to show around the region. By default none
#'   for tiles, and half a patch's width for patch tokens.
#' @param size The crop's output size, px.
#' @return The key, modified in place and returned invisibly.
#' @export
patchExemplars <- function(model, key, images, pad = NULL, size = 96) {
  tiles <- keyTiles(key)
  f <- key$features
  meta <- key$meta
  leads <- key$leads
  if (is.null(leads$Image)) leads$Image <- ""
  for (j in seq_len(nrow(f))) {
    ex <- f$exemplars[[j]]
    if (is.null(ex) || nrow(ex) == 0) next
    paths <- images$path[match(ex$image, images$id)]
    ex$png <- unlist(model$mod$exemplar_pngs(model$py, as.list(paths), as.list(as.integer(ex$patch - 1L)), pad = pad, size = size,
                                             tiles = if (length(tiles)) as.list(tiles) else NULL))
    f$exemplars[[j]] <- ex
    name <- snigletWord(f$id[j])   # the coined word: stays put when the sniglet is renamed
    ids <- paste0(gsub("[^A-Za-z0-9_-]", "_", name), "_", seq_len(nrow(ex)))
    meta <- rbind(meta, data.frame(key = paste0("image_", ids), value = paste0("data:image/png;base64,", ex$png), stringsAsFactors = FALSE))
    on <- which(leads$Feature == f$id[j] & leads$Test == ">")
    leads$Image[on] <- paste(ids, collapse = ";")
  }
  # leads with their own example regions (both the "Has" and the "Lacks" side)
  for (r in which(!is.null(leads$Examples) & nzchar(if (is.null(leads$Examples)) "" else leads$Examples))) {
    ex <- do.call(rbind, strsplit(strsplit(leads$Examples[r], ";", fixed = TRUE)[[1]], "|", fixed = TRUE))
    paths <- images$path[match(ex[, 1], images$id)]
    if (anyNA(paths)) next
    png <- unlist(model$mod$exemplar_pngs(model$py, as.list(paths), as.list(as.integer(ex[, 2]) - 1L), pad = pad, size = size,
                                          tiles = if (length(tiles)) as.list(tiles) else NULL))
    ids <- paste0("lead_", gsub("[^A-Za-z0-9_-]", "_", paste0(leads$Statement[r], leads$Choice[r])), "_", seq_along(png))
    meta <- rbind(meta[!meta$key %in% paste0("image_", ids), ],
                  data.frame(key = paste0("image_", ids), value = paste0("data:image/png;base64,", png), stringsAsFactors = FALSE))
    leads$Image[r] <- paste(ids, collapse = ";")
  }
  key$features <- f
  mm <- modelMeta(model)
  key$meta <- rbind(meta, mm[!mm$key %in% meta$key, ])
  key$leads <- leads
  invisible(key)
}

#' Score new images against a key's features
#'
#' Embeds the images (once per distinct crop region the key's text features
#' use) and applies [featureScores()].
#'
#' @param key A key with a `features` table.
#' @inheritParams embedImages
#' @return An `images x features` matrix for [classify()].
#' @export
scoreImages <- function(key, model, paths) {
  f <- key$features
  if (is.null(f)) stop("This key has no features table", call. = FALSE)
  ids <- if (is.data.frame(paths)) paths$id else sub("\\.[^.]+$", "", basename(paths))
  out <- matrix(NA_real_, length(ids), nrow(f), dimnames = list(ids, f$id))
  needPatches <- any(f$kind == "centroid_patch_max")
  dims <- unique(lengths(f$embedding[f$kind == "centroid_patch_max"]))
  if (length(dims) && !all(dims == model$spec$dim)) {
    stop("This key was built with a model of ", paste(dims, collapse = "/"), " dimensions, but this model has ",
         model$spec$dim, "; score images with the model the key was built with", call. = FALSE)
  }
  built <- key$meta$value[key$meta$key == "model_arch"]
  if (length(built) && !identical(built[1], model$spec$arch)) {
    warning("This key was built with the model ", built[1], ", not ", model$spec$arch, "; its tests may not mean the same thing", call. = FALSE)
  }
  empty <- keyEmpty(key)
  whole <- embedImages(model, paths, patches = needPatches, tiles = keyTiles(key),
                       minDetail = empty[["minDetail"]], minFill = empty[["minFill"]])
  if (needPatches) {
    j <- which(f$kind == "centroid_patch_max")
    sub <- key$clone(); sub$features <- f[j, ]
    out[, j] <- featureScores(sub, patches = whole$patches)
  }
  text <- which(f$kind == "clip_text_pair")
  if (length(text)) {
    textEmb <- embedTexts(model, unique(c(f$prompt[text], f$negative_prompt[text])))
    regions <- f$region[text]; regions[is.na(regions)] <- ""
    for (r in unique(regions)) {
      jj <- text[regions == r]
      emb <- if (nzchar(r)) embedImages(model, paths, region = as.numeric(strsplit(r, ",")[[1]]), patches = FALSE)$image else whole$image
      sub <- key$clone(); sub$features <- f[jj, ]
      out[, jj] <- featureScores(sub, image = emb, textEmb = textEmb)
    }
  }
  out
}

# The tiling a key's sniglets were found with: integer grid sizes, or
# integer(0) for the model's patch tokens (also for keys made before tiles).
keyTiles <- function(key) {
  v <- key$meta$value[key$meta$key == "sniglet_tiles"]
  if (!length(v) || !nzchar(v[1])) return(integer(0))
  as.integer(strsplit(v[1], ",", fixed = TRUE)[[1]])
}

# The rule for empty tiles a key's sniglets were found with (see embedImages).
keyEmpty <- function(key) {
  v <- key$meta$value[key$meta$key == "sniglet_empty"]
  out <- c(minDetail = 8, minFill = 0.5)
  if (length(v) && nzchar(v[1])) out[] <- as.numeric(strsplit(v[1], ",", fixed = TRUE)[[1]])
  out
}
