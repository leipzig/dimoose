pyVision <- local({
  mod <- NULL
  function() {
    if (!requireNamespace("reticulate", quietly = TRUE)) {
      stop("Install the reticulate package (and Python with torch and open_clip_torch) to embed images", call. = FALSE)
    }
    if (is.null(mod)) {
      mod <<- reticulate::import_from_path("moose_vision", path = system.file("python", package = "moose"), convert = TRUE)
    }
    mod
  }
})

#' Load a vision model for embedding images
#'
#' Uses Python's open_clip through reticulate. Install the Python side with
#' `pip install -r $(Rscript -e 'cat(system.file("python/requirements.txt", package="moose"))')`.
#'
#' @param weights Local checkpoint file (e.g. OpenAI's `ViT-B-32.pt`); if
#'   `NULL`, open_clip downloads `pretrained` weights for `name`.
#' @param name,pretrained open_clip model name and pretrained tag.
#' @param python Optional path to the Python executable to use (passed to
#'   [reticulate::use_python()]).
#' @return An object of class `mooseVisionModel` with `py` (the Python model)
#'   and `spec` (library, architecture, weights SHA-256, image size, ...).
#' @export
visionModel <- function(weights = NULL, name = "ViT-B-32", pretrained = "openai", python = NULL) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Install the reticulate package (and Python with torch and open_clip_torch) to embed images", call. = FALSE)
  }
  if (!is.null(python)) reticulate::use_python(python, required = TRUE)
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
#' @param model A [visionModel()].
#' @param paths Image files, or an [imageSet()] (its `path` column is
#'   embedded and its `id` column names the rows).
#' @param region Optional crop `c(y0, y1, x0, x1)` as fractions, applied to
#'   every image before embedding.
#' @param patches If `TRUE`, also return per-patch embeddings.
#' @return A list: `image` (`images x d` matrix, rows named by image id: the
#'   file name without extension, or the `id` of an [imageSet()]) and `patches` (`images x patches x d` array, or
#'   `NULL`).
#' @export
embedImages <- function(model, paths, region = NULL, patches = TRUE) {
  if (is.data.frame(paths)) {
    ids <- paths$id; paths <- paths$path
  } else {
    ids <- sub("\\.[^.]+$", "", basename(paths))
  }
  out <- model$mod$embed_images(model$py, as.list(as.character(paths)), region = region, patches = patches)
  image <- out$image; rownames(image) <- ids
  pt <- out$patches
  if (!is.null(pt)) dimnames(pt) <- list(ids, NULL, NULL)
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
#' Cuts out the best-matching patch (with some context) for each sniglet's
#' exemplars, stores them as PNGs in the key's `features` and `meta`, and
#' points each "Has ..." lead at them so [exportWizard()] shows them.
#'
#' @inheritParams embedImages
#' @param key A key from [keyFromSniglets()].
#' @param images The [imageSet()] the key was built from (for file paths).
#' @param pad,size Context around the patch and the crop's output size, px.
#' @return The key, modified in place and returned invisibly.
#' @export
patchExemplars <- function(model, key, images, pad = 48, size = 96) {
  f <- key$features
  meta <- key$meta
  leads <- key$leads
  if (is.null(leads$Image)) leads$Image <- ""
  for (j in seq_len(nrow(f))) {
    ex <- f$exemplars[[j]]
    if (is.null(ex) || nrow(ex) == 0) next
    paths <- images$path[match(ex$image, images$id)]
    ex$png <- unlist(model$mod$exemplar_pngs(model$py, as.list(paths), as.list(as.integer(ex$patch - 1L)), pad = pad, size = size))
    f$exemplars[[j]] <- ex
    name <- snigletWord(f$id[j])   # the coined word: stays put when the sniglet is renamed
    ids <- paste0(gsub("[^A-Za-z0-9_-]", "_", name), "_", seq_len(nrow(ex)))
    meta <- rbind(meta, data.frame(key = paste0("image_", ids), value = paste0("data:image/png;base64,", ex$png), stringsAsFactors = FALSE))
    on <- which(leads$Feature == f$id[j] & leads$Test == ">")
    leads$Image[on] <- paste(ids, collapse = ";")
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
  whole <- embedImages(model, paths, patches = needPatches)
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
