#' A set of labelled images
#'
#' @param paths Image files.
#' @param label Class of each image: `NULL` (the file name without its
#'   extension), a character vector as long as `paths`, or a function applied
#'   to those file names (e.g. `function(x) sub("_.*$", "", x)` so that
#'   `1967_alt` counts as `1967`).
#' @return A data frame with `id` (file name without extension), `path` and
#'   `label`.
#' @examples
#' imageSet(c("pics/1967.png", "pics/1967_alt.png"), label = function(x) sub("_.*$", "", x))
#' @export
imageSet <- function(paths, label = NULL) {
  paths <- as.character(paths)
  id <- sub("\\.[^.]+$", "", basename(paths))
  lab <- if (is.null(label)) {
    id
  } else if (is.function(label)) {
    as.character(label(id))
  } else {
    if (length(label) != length(paths)) stop("`label` must have one entry per path (length ", length(paths), ")", call. = FALSE)
    as.character(label)
  }
  data.frame(id = id, path = paths, label = lab, stringsAsFactors = FALSE)
}

#' MIME type of an image file from its first bytes
#' @param path One file.
#' @return `"image/png"`, `"image/jpeg"`, `"image/gif"`, `"image/webp"` or `NA`.
#' @export
imageMime <- function(path) {
  b <- readBin(path, "raw", 12)
  hex <- paste(format(b), collapse = "")
  if (startsWith(hex, "89504e47")) return("image/png")
  if (startsWith(hex, "ffd8ff")) return("image/jpeg")
  if (startsWith(hex, "474946")) return("image/gif")
  if (startsWith(hex, "52494646") && substr(hex, 17, 24) == "57454250") return("image/webp")
  NA_character_
}

#' Embed images in a key's metadata
#'
#' Reads image files and returns `image_<id>` rows for a key's `meta`, which
#' [exportWizard()] embeds in the page (each image once); leads refer to them
#' by id in their `Image` column (several separated by `;`).
#'
#' @param paths Image files.
#' @param ids Names for the images; default the file names without extension.
#' @return A key/value data frame.
#' @export
imageMeta <- function(paths, ids = NULL) {
  if (is.null(ids)) ids <- sub("\\.[^.]+$", "", basename(paths))
  value <- vapply(paths, function(p) {
    mime <- imageMime(p)
    if (is.na(mime)) stop(basename(p), " is not an image", call. = FALSE)
    paste0("data:", mime, ";base64,", base64enc::base64encode(p))
  }, character(1))
  data.frame(key = paste0("image_", ids), value = unname(value), stringsAsFactors = FALSE)
}
