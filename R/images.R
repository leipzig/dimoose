#' A set of labelled images
#'
#' The starting point for automated key generation: one row per photo, with
#' the class (species, model, ...) the photo shows. A key separates the
#' classes, so there must be at least two.
#'
#' @param paths Image files, or a single folder. A folder is searched
#'   (with its subfolders) for image files: png, jpg/jpeg, gif, webp, bmp and
#'   tif/tiff.
#' @param label Class of each image:
#'   * `NULL`: for a folder whose images are in subfolders, the name of the
#'     subfolder each image is in (`pics/cardinal/IMG_01.jpg` is a
#'     `cardinal`); otherwise the file name without its extension;
#'   * a character vector as long as `paths` (for a folder, as long as the
#'     files found, which are sorted by path);
#'   * a function applied to the file names without extensions (e.g.
#'     `function(x) sub("_.*$", "", x)` so that `1967_alt` counts as `1967`).
#' @return A data frame with `id`, `path` and `label`. `id` is the file name
#'   without its extension; when two files share a name, their folder is put
#'   in front (`cardinal_IMG_01`) so that ids are unique.
#' @examples
#' imageSet(c("pics/1967.png", "pics/1967_alt.png"), label = function(x) sub("_.*$", "", x))
#' imageSet(c("pics/cardinal/1.jpg", "pics/robin/1.jpg"), label = c("cardinal", "robin"))
#' \dontrun{
#' imageSet("pics")   # every image under pics/, labelled by subfolder
#' }
#' @export
imageSet <- function(paths, label = NULL) {
  paths <- as.character(paths)
  fromFolder <- length(paths) == 1 && dir.exists(paths)
  if (fromFolder) {
    root <- paths
    paths <- sort(list.files(root, pattern = "\\.(png|jpe?g|gif|webp|bmp|tiff?)$", ignore.case = TRUE,
                             recursive = TRUE, full.names = TRUE))
    if (!length(paths)) stop("No image files found in ", root, call. = FALSE)
  } else if (length(paths) == 1 && !file.exists(paths) && !grepl("\\.[A-Za-z0-9]+$", paths)) {
    stop("No such folder: ", paths, call. = FALSE)
  }
  name <- sub("\\.[^.]+$", "", basename(paths))
  folder <- basename(dirname(paths))
  id <- name
  dup <- id %in% id[duplicated(id)]
  id[dup] <- paste(folder[dup], name[dup], sep = "_")
  id <- make.unique(id, sep = "_")
  lab <- if (is.null(label)) {
    inSubfolder <- if (fromFolder) normalizePath(dirname(paths)) != normalizePath(root) else FALSE
    if (any(inSubfolder) && !all(inSubfolder)) {
      warning("Some images are in subfolders of ", root, " and some are not, so each image is labelled by its file name; ",
              "move the loose images into a class folder, or pass `label`", call. = FALSE)
    }
    if (all(inSubfolder)) folder else name
  } else if (is.function(label)) {
    as.character(label(name))
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
