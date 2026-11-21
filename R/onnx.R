# Vision models on ONNX Runtime (no torch), embeddings saved to files, and
# the files a web page needs to identify photos in the browser.

# ---- where models live -------------------------------------------------------

# Ready-made ONNX copies on the Hugging Face Hub of models dimoose names.
# Checked against the torch models on the example photos (cosine 1.0000 for
# the fp32 and fp16 files). There is no official ONNX copy of BioCLIP: convert
# it once with exportOnnxModel().
onxKnown <- function() {
  c("clip-vit-base-patch32" = "Xenova/clip-vit-base-patch32",
    "clip-vit-base-patch16" = "Xenova/clip-vit-base-patch16",
    "vit-b-32" = "Xenova/clip-vit-base-patch32",
    "vit-b-16" = "Xenova/clip-vit-base-patch16",
    "mobileclip-s0" = "Xenova/mobileclip_s0",
    "bioclip" = "imageomics/bioclip",
    "bioclip-2" = "imageomics/bioclip-2")
}

#' Folder where dimoose keeps downloaded and converted ONNX models
#'
#' Models are large (tens to hundreds of megabytes), so they are kept outside
#' your project, in R's per-user cache folder for dimoose. Set the option
#' `dimoose.onnx.cache` to use another folder.
#'
#' @return A path. The folder is not created until a model is stored in it.
#' @examples
#' onnxCache()
#' @export
onnxCache <- function() {
  getOption("dimoose.onnx.cache", file.path(onxUserCache(), "onnx"))
}

# R's per-user cache folder for dimoose; R before 4.0 has no R_user_dir().
onxUserCache <- function() {
  if (getRversion() >= "4.0.0") return(tools::R_user_dir("dimoose", "cache"))
  file.path(path.expand("~"), ".cache", "R", "dimoose")
}

# Wrapped so that tests can stand in for them.
onxUv <- function() unname(Sys.which("uv"))
onxSize <- function(path) file.size(path)

# The folder name of a model in the cache: "Xenova/clip-vit-base-patch32"
# becomes "Xenova--clip-vit-base-patch32".
onxSlug <- function(name) {
  gsub("[^A-Za-z0-9._-]+", "-", gsub("/", "--", sub("^hf-hub:", "", name), fixed = TRUE))
}

onxIsModelDir <- function(dir) {
  dir.exists(dir) && (file.exists(file.path(dir, "dimoose_onnx.json")) || file.exists(file.path(dir, "preprocessor_config.json")))
}

# What `name` refers to: list(dir=) for a folder on this computer, or
# list(repo=, dir=) for a Hugging Face repository and its folder in the cache.
onxResolve <- function(name, cache = onnxCache()) {
  if (!is.character(name) || length(name) != 1 || is.na(name) || !nzchar(name)) {
    stop("`name` must be one model name, folder or Hugging Face repository", call. = FALSE)
  }
  if (startsWith(name, "local-dir:")) {
    dir <- sub("^local-dir:", "", name)
    if (!dir.exists(dir)) stop("No such folder: ", dir, call. = FALSE)
    return(list(dir = dir))
  }
  if (dir.exists(name) && !startsWith(name, "hf-hub:")) return(list(dir = name))
  known <- onxKnown()
  repo <- if (tolower(name) %in% names(known)) known[[tolower(name)]] else sub("^hf-hub:", "", name)
  dir <- file.path(cache, onxSlug(repo))
  if (!grepl("[/:]", name)) {
    # a model converted here with exportOnnxModel(name) comes before the
    # ready-made copy of the same name
    own <- onxExportDir(name, "openai", cache)
    if (onxIsModelDir(own)) return(list(dir = own))
  }
  # BioCLIP's repositories hold the PyTorch model only: a folder under their
  # name was converted here, and none of its files are on the Hub
  if (repo %in% c("imageomics/bioclip", "imageomics/bioclip-2") && onxIsModelDir(dir)) return(list(dir = dir))
  if (grepl("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", repo)) return(list(repo = repo, dir = dir))
  if (onxIsModelDir(dir)) return(list(dir = dir))
  stop("There is no ONNX copy of the model \"", name, "\" on this computer (looked in ", dir, "). ",
       "`name` is a folder with an ONNX model, a Hugging Face repository (\"<organisation>/<model>\") or one of: ",
       paste(names(known), collapse = ", "), ". Convert any other open_clip model once with exportOnnxModel().", call. = FALSE)
}

# Download `url` to `dest`. TRUE when the file is there afterwards, FALSE when
# the server has no such file; any other failure is an error.
onxDownload <- function(url, dest) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  part <- paste0(dest, ".part")
  on.exit(unlink(part), add = TRUE)
  todo <- paste0("The model is fetched from huggingface.co the first time it is used: check the internet connection and ",
                 "try again (files already fetched are kept). On a computer that cannot reach it, copy the model's folder ",
                 "from one that can (it is in onnxCache() there) and give the folder as `name`.")
  r <- tryCatch(httr::GET(url, httr::write_disk(part, overwrite = TRUE), httr::timeout(3600)),
                error = function(e) stop("Could not download ", url, ": ", trimws(conditionMessage(e)), "\n", todo, call. = FALSE))
  code <- httr::status_code(r)
  if (code %in% c(401, 403, 404)) return(FALSE)
  if (code >= 400) stop("Could not download ", url, " (HTTP ", code, ").\n", todo, call. = FALSE)
  # a download that stopped early must not be kept as if it were the file
  expected <- suppressWarnings(as.numeric(httr::headers(r)[["content-length"]]))
  encoded <- !is.null(httr::headers(r)[["content-encoding"]])
  if (length(expected) == 1 && !is.na(expected) && !encoded && !isTRUE(file.size(part) == expected)) {
    stop("The download of ", url, " stopped early (", file.size(part), " of ", expected, " bytes).\n", todo, call. = FALSE)
  }
  file.rename(part, dest)
}

onxReadJson <- function(file) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package", call. = FALSE)
  jsonlite::fromJSON(file, simplifyVector = FALSE)
}

onxHubUrl <- function(repo, file) paste0("https://huggingface.co/", repo, "/resolve/main/", file)

# File name endings of the three precisions in the transformers.js layout.
onxHubSuffix <- function(precision) c(fp32 = "", fp16 = "_fp16", int8 = "_quantized")[[precision]]

# Ready-made int8 image encoders that are poor copies of their model, measured
# on dimoose's example photos against the same repository's fp32 file:
# `stop` for ones that are unusable, `warn` for ones that are rough.
onxInt8Note <- function(repo) {
  if (is.null(repo)) return(NULL)
  switch(repo,
    "Xenova/mobileclip_s0" = list(stop = paste0(
      "The int8 image encoder of Xenova/mobileclip_s0 does not work: its embeddings have nothing to do with the ",
      "model's (cosine 0.09 on average with the fp32 ones). Use precision = \"fp16\" (23 MB) or \"fp32\" (46 MB).")),
    "Xenova/clip-vit-base-patch32" = list(warn = paste0(
      "The ready-made int8 image encoder of Xenova/clip-vit-base-patch32 is a rough copy of the model: on dimoose's ",
      "example photos its embeddings have a cosine of 0.89 on average, and 0.81 at worst, with the full-precision ones ",
      "(the int8 copy exportOnnxModel() writes has 0.998). A key built with it must be followed with it. For a close ",
      "int8 copy convert the model yourself, once, with exportOnnxModel(\"ViT-B-32\"); or use precision = \"fp16\".")),
    NULL)
}

# Make sure the files of a Hub model that this call needs are in `dir`,
# downloading the missing ones with `fetch(url, dest)`. Returns the paths of
# the model's files inside the repository (image, text).
onxFetchRepo <- function(repo, dir, precision, textPrecision, text = TRUE, fetch = onxDownload, quiet = FALSE) {
  get <- function(file, required = TRUE, say = !quiet) {
    dest <- file.path(dir, file)
    if (file.exists(dest)) return(TRUE)
    if (say) message("Downloading ", repo, "/", file, " (once; kept in ", dir, ")")
    ok <- isTRUE(fetch(onxHubUrl(repo, file), dest))
    if (!ok && required) {
      stop("The Hugging Face repository ", repo, " has no file ", file, call. = FALSE)
    }
    ok
  }
  # which layout the repository has: asked quietly, since one of the two files is not there
  if (!onxIsModelDir(dir) && !get("dimoose_onnx.json", required = FALSE, say = FALSE) &&
      !get("preprocessor_config.json", required = FALSE, say = FALSE)) {
    stop("The Hugging Face repository ", repo, " holds no ONNX model that dimoose can read (it has neither ",
         "dimoose_onnx.json nor preprocessor_config.json), or it cannot be reached. ",
         "Convert the model once with exportOnnxModel(\"hf-hub:", repo, "\"); that needs Python with torch, but only once.",
         call. = FALSE)
  }
  if (file.exists(file.path(dir, "dimoose_onnx.json"))) {
    cfg <- onxReadJson(file.path(dir, "dimoose_onnx.json"))
    pick <- function(which, p) {
      f <- cfg[[which]][[p]]$file
      if (is.null(f)) stop(repo, " has no ", p, " ", sub("_", " ", which), "; it has: ", paste(names(cfg[[which]]), collapse = ", "), call. = FALSE)
      f
    }
    image <- pick("image_encoder", precision)
    get(image)
    textFile <- NULL
    if (text && length(cfg$text_encoder)) {
      textFile <- pick("text_encoder", textPrecision)
      get(textFile)
      if (!is.null(cfg$tokenizer)) get(cfg$tokenizer)
    }
  } else {
    get("config.json", required = FALSE, say = FALSE)
    image <- paste0("onnx/vision_model", onxHubSuffix(precision), ".onnx")
    get(image)
    textFile <- NULL
    if (text) {
      textFile <- paste0("onnx/text_model", onxHubSuffix(textPrecision), ".onnx")
      get(textFile)
      get("tokenizer.json")
    }
  }
  list(image = image, text = textFile)
}

# ---- the model ---------------------------------------------------------------

pyOnnx <- local({
  mod <- NULL
  function() {
    if (!requireNamespace("reticulate", quietly = TRUE)) {
      stop("Install the reticulate package to embed images", call. = FALSE)
    }
    if (is.null(mod)) {
      req <- pythonRequirements("onnx")
      if (utils::packageVersion("reticulate") >= "1.41.0" && !reticulate::py_available(initialize = FALSE)) {
        reticulate::py_require(req)
      }
      fail <- function(why) {
        stop(onxPythonAdvice(why, req, tryCatch(reticulate::py_config()$python, error = function(e) "unknown")), call. = FALSE)
      }
      loaded <- tryCatch(
        reticulate::import_from_path("dimoose_onnx", path = system.file("python", package = "dimoose"), convert = TRUE),
        error = function(e) fail(conditionMessage(e)))
      # the module imports onnxruntime and tokenizers only when a model is
      # opened; ask now, so that a Python without them gets the advice above
      lacking <- onxMissingModules(c("onnxruntime", "tokenizers"))
      if (length(lacking)) fail(paste0("it has no Python package ", paste(lacking, collapse = " or ")))
      mod <<- loaded
    }
    mod
  }
})

# What to tell someone whose Python cannot run the ONNX backend.
onxPythonAdvice <- function(why, req, python) {
  paste0("Could not load dimoose's ONNX code with the Python at ", python, ":\n", why,
         "\nIt needs the Python packages ", paste(req, collapse = ", "), ". Install them there with\n",
         "  reticulate::py_install(c(", paste0("\"", req, "\"", collapse = ", "), "))\n",
         "or let reticulate provide a Python: restart R without RETICULATE_PYTHON set and without the `python` argument.")
}

# Which of these Python modules the Python in use lacks. Wrapped for tests.
onxMissingModules <- function(modules) {
  modules[!vapply(modules, function(m) isTRUE(tryCatch(reticulate::py_module_available(m), error = function(e) FALSE)), logical(1))]
}

#' Load a vision model that runs on ONNX Runtime, without PyTorch
#'
#' The light way to embed images and texts: the Python side needs only
#' `onnxruntime`, `numpy`, `pillow` and `tokenizers` (about 150 MB installed,
#' against 0.8 GB to several GB for PyTorch, depending on the platform). The
#' result is used exactly like a [visionModel()]: with [embedImages()],
#' [embedTexts()], [scoreImages()], [suggestSpecies()] and the rest.
#' `visionModel(backend = "onnx")` calls this function.
#'
#' @section Where models come from:
#' `name` is one of
#'
#' * a folder on your computer that holds an ONNX model (also written
#'   `"local-dir:<folder>"`), in either layout described below;
#' * a Hugging Face repository, `"<organisation>/<model>"` or
#'   `"hf-hub:<organisation>/<model>"`. The files that are needed are
#'   downloaded once into [onnxCache()] and reused; nothing is downloaded when
#'   they are already there;
#' * `"clip-vit-base-patch32"` (the default; CLIP ViT-B/32, the same weights as
#'   `visionModel()`) or `"clip-vit-base-patch16"`: the ready-made exports
#'   `Xenova/clip-vit-base-patch32` and `Xenova/clip-vit-base-patch16` on the
#'   Hub;
#' * `"mobileclip-s0"`: Apple's MobileCLIP-S0 (`Xenova/mobileclip_s0`), a
#'   small model for phones. Its image encoder is 46 MB at `"fp32"` and 23 MB
#'   at `"fp16"`. Its `"int8"` file is refused: its embeddings are wrong
#'   (measured: cosine 0.09 on average with the `"fp32"` ones);
#' * `"bioclip"`, `"bioclip-2"` or any other model you have converted with
#'   [exportOnnxModel()]. There is no official ONNX copy of BioCLIP on the
#'   Hub, so it has to be converted once on a computer with PyTorch; the
#'   converted folder can then be copied to computers without it.
#'
#' @section Precision and size:
#' Each encoder comes in up to three precisions. Measured on dimoose's 55
#' example photos against the PyTorch model (CLIP ViT-B/32 image encoder):
#'
#' | `precision` | image encoder | cosine with PyTorch (lowest) |
#' |---|---|---|
#' | `"fp32"` | 352 MB | 1.0000 |
#' | `"fp16"` | 176 MB | 1.0000 |
#' | `"int8"`, converted by [exportOnnxModel()] | 96 MB | 0.998 |
#' | `"int8"`, `Xenova/clip-vit-base-patch32` (`_quantized`) | 89 MB | 0.81 |
#'
#' `"fp16"` halves the download but runs up to three times slower on a CPU
#' than `"fp32"`. BioCLIP converted by [exportOnnxModel()] is 345, 173 and
#' 89 MB, with cosines of 1.0000, 1.0000 and 0.998 (BioCLIP 2, a larger
#' model, is about 1217, 609 and 310 MB); on the Montana example photos all
#' three precisions name the same species. A key must be followed with the
#' model **and precision** it was built with when the precision is `"int8"`:
#' its embeddings differ slightly from the others'. The ready-made `"int8"`
#' file of `Xenova/clip-vit-base-patch32` is a much rougher copy (0.89 on
#' average), so `onnxModel()` warns when it is used; to get the close one,
#' convert the model yourself with `exportOnnxModel("ViT-B-32")`. A model you
#' have converted is used in place of the ready-made copy of the same name.
#'
#' The patch tokens of an `"int8"` encoder (`embedImages(tiles = 0)`) are
#' less faithful than its image embeddings: with BioCLIP the lowest cosine
#' of a token with the `"fp32"` one was 0.86. Use tiles, or a higher
#' precision, to find sniglets with patch tokens.
#'
#' @section Layouts of a model folder:
#' dimoose's own layout, written by [exportOnnxModel()]: `dimoose_onnx.json`
#' (architecture, image size, preprocessing constants, file names),
#' `image_encoder.onnx`, `text_encoder.onnx`, their `_fp16` and `_int8`
#' copies, and `tokenizer.json`. Its image encoder also returns the model's
#' patch tokens, so `embedImages(tiles = 0)` works.
#'
#' The transformers.js layout of ready-made exports on the Hub: `config.json`,
#' `preprocessor_config.json`, `tokenizer.json`,
#' `onnx/vision_model[_fp16|_quantized].onnx` and
#' `onnx/text_model[_fp16|_quantized].onnx`. These give one embedding per
#' image and no patch tokens: tiles (the default of [embedImages()]) work,
#' `tiles = 0` does not.
#'
#' @param name The model: a folder, a Hugging Face repository or a known name
#'   (see below).
#' @param precision `"fp32"`, `"fp16"` or `"int8"`: which copy of the image
#'   encoder to use.
#' @param textPrecision The same for the text encoder; by default as
#'   `precision`.
#' @param text If `FALSE`, the text encoder is not downloaded (about 250 MB
#'   less at `"fp32"`). [embedTexts()] then fails; sniglet keys do not need it.
#' @param cache Folder for downloaded models.
#' @param python Optional path to the Python executable to use (passed to
#'   [reticulate::use_python()]).
#' @param threads Number of CPU threads for ONNX Runtime; `0` lets it choose.
#'
#' @section When something goes wrong:
#' * *Could not download ...*: the model is fetched from huggingface.co the
#'   first time only. Files that arrived are kept, so calling again continues
#'   where it stopped. A computer that cannot reach the Hub can be given the
#'   model's folder, copied from [onnxCache()] on one that can, as `name`.
#' * *... is not a readable ONNX model*: a model file is damaged, usually a
#'   download or copy that stopped early. Delete the file named in the
#'   message and load the model again; a file from the Hub is fetched afresh.
#' * *Could not load dimoose's ONNX code*: the Python in use lacks
#'   `onnxruntime` or `tokenizers`. The message gives the
#'   `reticulate::py_install()` call that installs them.
#' @param fetch For tests: a function `(url, dest)` that downloads a file and
#'   returns `TRUE`, or `FALSE` if there is no such file.
#' @return An object of class `dimooseVisionModel`, as [visionModel()] returns,
#'   with a `files` entry: the model's folder (`dir`), its image and text
#'   encoder files (`image`, `text`) and, for a model from the Hub, its
#'   repository (`repo`) and the web address of the image encoder (`imageUrl`).
#' @seealso [exportOnnxModel()] to convert a model, [exportBrowserModel()] to
#'   use one in a web page, [saveEmbeddings()] to need no Python at all.
#' @examples
#' \dontrun{
#' model <- onnxModel()                              # CLIP ViT-B/32, downloaded once
#' model <- onnxModel(precision = "fp16")            # half the download
#' images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
#' emb <- embedImages(model, images)
#'
#' exportOnnxModel("bioclip")                        # once, needs PyTorch
#' model <- onnxModel("bioclip")                     # afterwards, without it
#' }
#' @export
onnxModel <- function(name = "clip-vit-base-patch32", precision = c("fp32", "fp16", "int8"), textPrecision = precision,
                      text = TRUE, cache = onnxCache(), python = NULL, threads = 0, fetch = NULL) {
  precision <- match.arg(precision)
  textPrecision <- match.arg(textPrecision, c("fp32", "fp16", "int8"))
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Install the reticulate package to embed images", call. = FALSE)
  }
  if (!is.numeric(threads) || length(threads) != 1 || is.na(threads) || threads < 0) {
    stop("`threads` must be a number of CPU threads, or 0 to let ONNX Runtime choose", call. = FALSE)
  }
  where <- onxResolve(name, cache)
  files <- list(dir = where$dir, repo = where$repo)
  if (precision == "int8") {
    note <- onxInt8Note(where$repo)
    if (!is.null(note$stop)) stop(note$stop, call. = FALSE)
    if (!is.null(note$warn)) warning(note$warn, call. = FALSE)
  }
  if (!is.null(where$repo)) {
    got <- onxFetchRepo(where$repo, where$dir, precision, textPrecision, text = text,
                        fetch = if (is.null(fetch)) onxDownload else fetch)
    files$imageUrl <- onxHubUrl(where$repo, got$image)
  } else if (!onxIsModelDir(where$dir)) {
    stop(where$dir, " is not an ONNX model folder: it has neither dimoose_onnx.json (written by exportOnnxModel()) ",
         "nor preprocessor_config.json (the transformers.js layout)", call. = FALSE)
  }
  if (!is.null(python)) reticulate::use_python(python, required = TRUE)
  mod <- pyOnnx()
  py <- mod$load_model(normalizePath(where$dir), precision = precision, text_precision = textPrecision, threads = as.integer(threads))
  spec <- py$spec
  if (!is.null(where$repo)) {
    spec$repository <- where$repo
    # the ready-made exports are the models open_clip calls ViT-B-32 and
    # ViT-B-16 (openai): the same name, so that keys built with one backend
    # are followed with the other without a warning
    same <- c("Xenova/clip-vit-base-patch32" = "ViT-B-32", "Xenova/clip-vit-base-patch16" = "ViT-B-16")
    if (where$repo %in% names(same) && !identical(spec$layout, "dimoose")) spec$arch <- same[[where$repo]]
    if (identical(spec$arch, basename(where$dir))) spec$arch <- where$repo      # a repository that does not name its model
  }
  files$image <- py$image_file
  files$text <- py$text_file
  structure(list(py = py, mod = mod, spec = spec, files = files), class = "dimooseVisionModel")
}

#' Convert an open_clip model to ONNX
#'
#' Runs dimoose's `export_onnx.py` (in the package's `python` folder) to write
#' a model as ONNX image and text encoders that [onnxModel()] runs without
#' PyTorch. The conversion itself needs PyTorch and open_clip, but only once:
#' the folder it writes can be copied to other computers or uploaded to a
#' Hugging Face repository and used from there.
#'
#' Each file is checked against the PyTorch model as it is written; the
#' script prints the files' sizes and how close their embeddings are.
#'
#' @section Files written:
#' * `dimoose_onnx.json`: architecture, image size, patch size, embedding
#'   dimensions, preprocessing (`resize`, `interpolation`, `crop`, `rescale`,
#'   `mean`, `std`), the file names and sizes of each precision, and the names
#'   of the encoders' inputs and outputs.
#' * `image_encoder.onnx`: input `pixel_values` (`n x 3 x S x S`, float32);
#'   outputs `image_embeds` (`n x d`, not normalised) and `patch_embeds`
#'   (`n x g*g x d`, the projected patch tokens).
#' * `text_encoder.onnx`: input `input_ids` (`n x 77`, int64); output
#'   `text_embeds` (`n x d`, not normalised).
#' * `tokenizer.json`: the tokenizer in the Hugging Face `tokenizers` format,
#'   which transformers.js also reads.
#' * with `quantize`: `image_encoder_int8.onnx`, `text_encoder_int8.onnx`
#'   (weights as 8-bit integers, about a quarter of the size) and
#'   `image_encoder_fp16.onnx`, `text_encoder_fp16.onnx` (16-bit floats, half
#'   the size, same embeddings).
#'
#' @param name The model, as for [visionModel()]: an open_clip architecture
#'   name, `"bioclip"`, `"bioclip-2"`, `"hf-hub:<organisation>/<model>"` or
#'   `"local-dir:<folder>"`. Only models with a vision transformer and
#'   open_clip's own CLIP tokenizer can be converted.
#' @param pretrained open_clip's tag for the weights of an architecture.
#' @param weights Local checkpoint file instead of a download.
#' @param dir Folder to write to. By default the model's folder in
#'   [onnxCache()], where [onnxModel()] and `visionModel(backend = "onnx")`
#'   find it by the same `name`.
#' @param quantize Which smaller copies to write as well: `"int8"`, `"fp16"`,
#'   both or neither (`character(0)`).
#' @param python The Python to run the script with; it needs the packages in
#'   the package's `python/requirements.txt` and
#'   `python/requirements-export.txt`. By default, if the `uv` program is
#'   installed, `uv` provides a Python with those packages (downloading them
#'   the first time); otherwise `python3`.
#' @param run For tests: a function `(command, args)` that runs the script and
#'   returns its exit status.
#' @return The folder, invisibly.
#' @examples
#' \dontrun{
#' exportOnnxModel("bioclip")
#' model <- onnxModel("bioclip", precision = "int8")
#' }
#' @export
exportOnnxModel <- function(name = "bioclip", pretrained = "openai", weights = NULL, dir = NULL,
                            quantize = c("int8", "fp16"), python = NULL, run = NULL) {
  if (length(quantize)) quantize <- match.arg(quantize, c("int8", "fp16"), several.ok = TRUE)
  torchNames <- c(bioclip = "hf-hub:imageomics/bioclip", "bioclip-2" = "hf-hub:imageomics/bioclip-2")
  model <- if (tolower(name) %in% names(torchNames)) torchNames[[tolower(name)]] else name
  if (is.null(dir)) dir <- onxExportDir(name, pretrained)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  pydir <- system.file("python", package = "dimoose")
  args <- c(file.path(pydir, "export_onnx.py"), "--model", model, "--pretrained", pretrained, "--out", normalizePath(dir))
  if (!is.null(weights)) args <- c(args, "--weights", normalizePath(weights))
  if (length(quantize)) args <- c(args, "--quantize", quantize)
  command <- python
  if (is.null(command)) {
    uv <- onxUv()
    if (nzchar(uv)) {
      command <- uv
      args <- c("run", "--no-project", "--with-requirements", file.path(pydir, "requirements.txt"),
                "--with-requirements", file.path(pydir, "requirements-export.txt"), "python", args)
    } else {
      command <- "python3"
    }
  }
  if (is.null(run)) run <- function(command, args) system2(command, shQuote(args))
  status <- run(command, args)
  if (!identical(as.integer(status), 0L) || !file.exists(file.path(dir, "dimoose_onnx.json"))) {
    stop("The conversion failed (", command, " ", paste(utils::head(args, 3), collapse = " "), " ...). ",
         "It needs Python with the packages in ", file.path(pydir, "requirements.txt"), " and ",
         file.path(pydir, "requirements-export.txt"), "; give that Python's path in `python`.", call. = FALSE)
  }
  invisible(dir)
}

# Where exportOnnxModel() writes a model by default, which is where
# onxResolve() looks for the same name.
onxExportDir <- function(name, pretrained = "openai", cache = onnxCache()) {
  # BioCLIP goes by its repository, so that "bioclip" and
  # "hf-hub:imageomics/bioclip" are one folder. The models with a ready-made
  # copy on the Hub get a folder of their own, apart from that copy's.
  known <- onxKnown()
  if (grepl("^bioclip", name, ignore.case = TRUE) && tolower(name) %in% names(known)) {
    return(file.path(cache, onxSlug(known[[tolower(name)]])))
  }
  if (startsWith(name, "hf-hub:")) return(file.path(cache, onxSlug(name)))
  if (startsWith(name, "local-dir:")) return(file.path(cache, onxSlug(basename(sub("^local-dir:", "", name)))))
  file.path(cache, onxSlug(paste0(name, "-", pretrained)))
}

# The `name` for onnxModel() that visionModel(name, pretrained, backend =
# "onnx") means.
onxNameFor <- function(name, pretrained = "openai", cache = onnxCache()) {
  if (dir.exists(name) || grepl("^(hf-hub|local-dir):", name) || grepl("/", name, fixed = TRUE)) return(name)
  # a model you converted yourself comes before the ready-made copy of the
  # same name: exportOnnxModel("ViT-B-32") is then what "ViT-B-32" means
  dir <- onxExportDir(name, pretrained, cache)
  if (onxIsModelDir(dir)) return(dir)
  if (tolower(name) %in% names(onxKnown()) && (identical(pretrained, "openai") || grepl("bioclip", name, ignore.case = TRUE))) return(name)
  if (!onxIsModelDir(dir)) {
    stop("There is no ONNX copy of ", name, " (", pretrained, ") on this computer (looked in ", dir, "). Convert it once with ",
         "exportOnnxModel(\"", name, "\", pretrained = \"", pretrained, "\"); that needs Python with torch, but only once.", call. = FALSE)
  }
  dir
}

# ---- embeddings in files -----------------------------------------------------

# IEEE 754 half precision: numbers to 16-bit patterns (as integers 0..65535)
# and back. Values too large for a half become infinite; NA becomes NaN.
onxToHalf <- function(x) {
  x <- as.numeric(x)
  bits <- integer(length(x))
  nan <- is.na(x)
  sign <- ifelse(!nan & (x < 0 | (x == 0 & 1 / x < 0)), 32768L, 0L)
  a <- abs(x)
  inf <- !nan & a >= 65520                      # rounds up past the largest half
  tiny <- !nan & a < 2^-14                      # subnormal halves, and zero
  norm <- !nan & !inf & !tiny
  bits[tiny] <- as.integer(round(a[tiny] * 2^24))
  e <- floor(log2(a[norm]))
  m <- round((a[norm] / 2^e - 1) * 1024)
  up <- m == 1024
  e[up] <- e[up] + 1; m[up] <- 0
  bits[norm] <- as.integer((e + 15) * 1024 + m)
  bits[inf] <- 31744L
  bits[nan] <- 32256L
  bits + ifelse(nan, 0L, sign)
}

onxFromHalf <- function(bits) {
  sign <- ifelse(bits >= 32768L, -1, 1)
  e <- (bits %/% 1024L) %% 32L
  m <- bits %% 1024L
  out <- ifelse(e == 0L, m * 2^-24, (1 + m / 1024) * 2^(e - 15))
  out[e == 31L] <- ifelse(m[e == 31L] == 0L, Inf, NaN)
  sign * out
}

#' Save embeddings to a file, and read them back
#'
#' Embedding images needs a vision model, and so Python; using embeddings
#' does not. `saveEmbeddings()` writes what [embedImages()] or [embedTexts()]
#' returned to one small file, and `loadEmbeddings()` reads it back as it
#' was, row names and tiling included, on a computer with no Python at all.
#' Everything dimoose does after embedding ([discoverSniglets()],
#' [snigletScores()], [keyFromSniglets()], [keyFromClusters()],
#' [featureScores()], ...) works from the loaded embeddings.
#'
#' @section File format:
#' The file is in the
#' [safetensors](https://huggingface.co/docs/safetensors) format, which
#' Python (`safetensors.numpy.load_file()`), JavaScript and other languages
#' read too:
#'
#' * 8 bytes: the length `N` of the header in bytes, an unsigned 64-bit
#'   little-endian integer;
#' * `N` bytes: the header, one JSON object in UTF-8, padded with spaces so
#'   that `N` is a multiple of 8. It has one entry per array, in the order
#'   the arrays are stored, named `image` and `patches` (for
#'   [embedImages()]), `embeddings` (for a single matrix) or by the names of
#'   the list given. Each entry has `dtype` (`"F32"` or `"F16"`), `shape`
#'   (the dimensions, e.g. `[36, 512]`) and `data_offsets` (`[begin, end]`:
#'   the array's first byte and the byte after its last, counted from the end
#'   of the header);
#' * the arrays' numbers, one array after another with nothing between them,
#'   in row-major (C) order: an `images x d` matrix is stored image by image,
#'   an `images x tiles x d` array image by image and tile by tile.
#'
#' Numbers are IEEE 754 floats of 4 bytes (`"F32"`) or 2 bytes (`"F16"`), and
#' always little-endian, whatever the computer that writes or reads the file.
#'
#' The header's `__metadata__` entry is an object of strings: `format`
#' (`"dimoose-embeddings"`), `version` (`"1"`), `single` (`"true"` when `x`
#' was one array and not a list, so that it is read back as one),
#' `rownames.<array>` (a JSON array of the row names: image ids or texts;
#' other dimensions' names are not kept), `tiles.<array>` and
#' `empty.<array>` (the tiling and the rule for empty tiles, see
#' [embedImages()], as numbers separated by commas) and `model` (a JSON
#' object with the model's details, if there is a model).
#'
#' `loadEmbeddings()` also reads safetensors files written by other programs,
#' as long as their arrays are 16-, 32- or 64-bit floats.
#'
#' @section Precision:
#' R keeps numbers as 64-bit floats and the file holds 32-bit ones (about 7
#' significant digits). Vision models compute in 32 bits, so what
#' [embedImages()] and [embedTexts()] return is saved and read back exactly;
#' other numbers come back rounded to the nearest 32-bit float. With
#' `precision = "float16"` every number is rounded to about 3 significant
#' digits: unit-length embeddings change by at most 0.0005 per coordinate.
#' Numbers too large for the chosen precision become `Inf`, and `NA` is read
#' back as `NaN`.
#'
#' @section Embeddings that come with dimoose:
#' The embeddings of the package's example photos are in its
#' `extdata/embeddings` folder, so the examples can be followed with no
#' Python: `pics-clip-vit-b-32.safetensors` (the 36 fruit photos in
#' `extdata/pics`, whole photos and 4 x 4 tiles),
#' `new-photos-clip-vit-b-32.safetensors` (the 6 photos in
#' `extdata/new-photos`), `texts-clip-vit-b-32.safetensors` (the prompts of
#' the vision vignette) and `montana-bioclip.safetensors` (the tree photos in
#' `extdata/montana` and the names of [montanaKey()]'s species, embedded with
#' BioCLIP). The folder's `README.md` says how each was made.
#'
#' @param x A numeric matrix or array, or a list of them such as
#'   [embedImages()] returns (entries that are `NULL` are left out).
#' @param file File to write or read; `.safetensors` is the usual ending.
#' @param precision `"float32"`, or `"float16"` for a file half the size.
#'   Embeddings have unit length, so 16-bit floats change cosine
#'   similarities only in the fourth decimal place.
#' @param model Optional [visionModel()] the embeddings were made with; its
#'   details are stored in the file. Embeddings from `loadEmbeddings()` keep
#'   the model they were loaded with when saved again.
#' @return `saveEmbeddings()` returns `file`, invisibly. `loadEmbeddings()`
#'   returns what was saved: a matrix or array, or a list of them. If the
#'   file records a model, its details are in the result's `model` attribute.
#' @examples
#' # stand-ins for embedImages(model, images): 3 images, 2 tiles each, 4 dimensions
#' emb <- list(image = matrix(rnorm(12), 3, 4, dimnames = list(c("a", "b", "c"), NULL)),
#'             patches = array(rnorm(24), c(3, 2, 4), dimnames = list(c("a", "b", "c"), NULL, NULL)))
#' attr(emb$patches, "tiles") <- 1L
#' file <- tempfile(fileext = ".safetensors")
#' saveEmbeddings(emb, file)
#' back <- loadEmbeddings(file)
#' all.equal(back$image, emb$image, tolerance = 1e-6)
#' rownames(back$image)
#' attr(back$patches, "tiles")
#'
#' # the example photos' embeddings, made with CLIP ViT-B/32: a key with no Python
#' pics <- loadEmbeddings(system.file("extdata", "embeddings", "pics-clip-vit-b-32.safetensors",
#'                                    package = "dimoose"))
#' dim(pics$patches)
#' attr(pics, "model")$arch
#' images <- imageSet(system.file("extdata", "pics", package = "dimoose"))
#' sniglets <- discoverSniglets(pics$patches, k = 40)
#' scores <- snigletScores(pics$patches, sniglets$centroids)
#' keyFromSniglets(scores, images, sniglets, method = "rpart")
#' @export
saveEmbeddings <- function(x, file, precision = c("float32", "float16"), model = NULL) {
  precision <- match.arg(precision)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package", call. = FALSE)
  if (is.data.frame(x)) x <- as.matrix(x)
  single <- !is.list(x)
  if (single) x <- list(embeddings = x)
  if (!is.null(model) && !inherits(model, "dimooseVisionModel")) {
    stop("`model` must be the vision model the embeddings were made with, from visionModel() or onnxModel()", call. = FALSE)
  }
  # embeddings read by loadEmbeddings() carry their model's details
  kept <- if (single) attr(x[[1]], "model") else attr(x, "model")
  if (!is.list(kept) || is.null(names(kept))) kept <- NULL
  if (!is.character(file) || length(file) != 1 || is.na(file) || !nzchar(file)) stop("`file` must be one file name", call. = FALSE)
  if (dir.exists(file)) stop(file, " is a folder; `file` must be the name of a file", call. = FALSE)
  if (!dir.exists(dirname(file))) stop("No such folder: ", dirname(file), call. = FALSE)
  x <- x[!vapply(x, is.null, logical(1))]
  if (!length(x) || is.null(names(x)) || any(!nzchar(names(x))) || anyDuplicated(names(x))) {
    stop("`x` must be a numeric array or a list of numeric arrays with distinct names", call. = FALSE)
  }
  if (any(names(x) == "__metadata__")) stop("An array cannot be called __metadata__", call. = FALSE)
  json <- function(v) as.character(jsonlite::toJSON(v, auto_unbox = TRUE, digits = NA, null = "null"))
  meta <- list(format = "dimoose-embeddings", version = "1", single = if (single) "true" else "false")
  header <- list()
  chunks <- list()
  offset <- 0
  for (n in names(x)) {
    a <- x[[n]]
    if (!is.numeric(a)) stop("`", n, "` is not numeric", call. = FALSE)
    dims <- if (is.null(dim(a))) length(a) else dim(a)
    values <- if (length(dims) > 1) as.vector(aperm(unclass(a))) else as.vector(a)   # row-major
    raw <- if (precision == "float32") {
      writeBin(as.numeric(values), raw(), size = 4, endian = "little")
    } else {
      bits <- onxToHalf(values)
      writeBin(ifelse(bits >= 32768L, bits - 65536L, bits), raw(), size = 2, endian = "little")
    }
    if (offset + length(raw) > .Machine$integer.max) stop("These embeddings are too large for one file (2 GB)", call. = FALSE)
    header[[n]] <- list(dtype = if (precision == "float32") "F32" else "F16", shape = I(as.integer(dims)),
                        data_offsets = I(as.integer(c(offset, offset + length(raw)))))
    offset <- offset + length(raw)
    chunks[[n]] <- raw
    rn <- if (is.null(dim(a))) names(a) else dimnames(a)[[1]]
    if (!is.null(rn)) meta[[paste0("rownames.", n)]] <- as.character(jsonlite::toJSON(as.character(rn)))
    if (!is.null(attr(a, "tiles"))) meta[[paste0("tiles.", n)]] <- paste(attr(a, "tiles"), collapse = ",")
    if (!is.null(attr(a, "empty"))) meta[[paste0("empty.", n)]] <- paste(attr(a, "empty"), collapse = ",")
  }
  s <- if (!is.null(model)) model$spec else kept
  if (!is.null(s)) {
    s <- s[!vapply(s, is.null, logical(1))]
    meta$model <- json(lapply(s, function(v) if (length(v) == 1) v else paste(v, collapse = ",")))
  }
  head <- charToRaw(enc2utf8(json(c(list("__metadata__" = meta), header))))
  head <- c(head, rep(as.raw(0x20), (8 - length(head) %% 8) %% 8))          # pad with spaces to 8 bytes
  con <- file(file, "wb")
  on.exit(close(con))
  writeBin(c(length(head), 0L), con, size = 4, endian = "little")           # 64-bit length, low word first
  writeBin(head, con)
  for (r in chunks) writeBin(r, con)
  invisible(file)
}

#' @rdname saveEmbeddings
#' @export
loadEmbeddings <- function(file) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package", call. = FALSE)
  if (!is.character(file) || length(file) != 1 || is.na(file)) stop("`file` must be one file name", call. = FALSE)
  if (!file.exists(file)) stop("No such file: ", file, call. = FALSE)
  if (dir.exists(file)) stop(file, " is a folder, not a file of embeddings", call. = FALSE)
  size <- file.size(file)
  con <- file(file, "rb")
  on.exit(close(con))
  n <- readBin(con, "integer", 2, size = 4, endian = "little")
  if (length(n) < 2 || is.na(n[1]) || n[2] != 0 || n[1] <= 0 || n[1] + 8 > size) {
    stop(file, " is not a safetensors file", call. = FALSE)
  }
  text <- rawToChar(readBin(con, "raw", n[1]))
  Encoding(text) <- "UTF-8"
  header <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE),
                     error = function(e) stop(file, " is not a safetensors file: its header is not JSON", call. = FALSE))
  if (!is.list(header) || is.null(names(header)) || any(!nzchar(names(header)))) {
    stop(file, " is not a safetensors file: its header is not a JSON object", call. = FALSE)
  }
  data <- readBin(con, "raw", size - 8 - n[1])
  meta <- header[["__metadata__"]]
  header[["__metadata__"]] <- NULL
  if (!length(header)) stop(file, " holds no arrays", call. = FALSE)
  out <- list()
  for (name in names(header)) {
    h <- header[[name]]
    ok <- is.list(h) && is.character(h$dtype) && length(h$dtype) == 1 && length(h$data_offsets) == 2 &&
      all(vapply(c(h$shape, h$data_offsets), function(v) is.numeric(v) && length(v) == 1 && !is.na(v) && v >= 0, logical(1)))
    if (!ok) stop(file, " is not a safetensors file: `", name, "` lacks a dtype, a shape or its data offsets", call. = FALSE)
    dims <- as.integer(unlist(h$shape))
    at <- unlist(h$data_offsets)
    count <- prod(dims)
    if (at[1] > at[2]) stop(file, " is not a safetensors file: `", name, "` ends before it begins", call. = FALSE)
    if (at[2] > length(data)) {
      stop(file, " is cut short: `", name, "` should end at byte ", at[2], " of the data, which has ", length(data), call. = FALSE)
    }
    raw <- data[seq.int(at[1] + 1, length.out = at[2] - at[1])]
    values <- switch(h$dtype,
      F32 = readBin(raw, "numeric", count, size = 4, endian = "little"),
      F64 = readBin(raw, "numeric", count, size = 8, endian = "little"),
      F16 = onxFromHalf(readBin(raw, "integer", count, size = 2, signed = FALSE, endian = "little")),
      stop("`", name, "` in ", file, " has the type ", h$dtype, ", which loadEmbeddings() does not read", call. = FALSE))
    if (length(values) != count) stop("`", name, "` in ", file, " has ", length(values), " numbers, not the ", count, " its shape says", call. = FALSE)
    a <- if (length(dims) > 1) aperm(array(values, rev(dims))) else values
    rn <- meta[[paste0("rownames.", name)]]
    if (!is.null(rn)) {
      rn <- vapply(jsonlite::fromJSON(rn, simplifyVector = FALSE), function(v) if (is.null(v)) NA_character_ else as.character(v), "")
      if (length(dims) > 1) dimnames(a) <- c(list(rn), rep(list(NULL), length(dims) - 1)) else names(a) <- rn
    }
    tiles <- meta[[paste0("tiles.", name)]]
    if (!is.null(tiles)) attr(a, "tiles") <- as.integer(strsplit(tiles, ",", fixed = TRUE)[[1]])
    empty <- meta[[paste0("empty.", name)]]
    if (!is.null(empty)) attr(a, "empty") <- stats::setNames(as.numeric(strsplit(empty, ",", fixed = TRUE)[[1]]), c("minDetail", "minFill"))
    out[[name]] <- a
  }
  if (identical(meta$single, "true") && length(out) == 1) out <- out[[1]]
  if (!is.null(meta$model)) attr(out, "model") <- jsonlite::fromJSON(meta$model, simplifyVector = FALSE)
  out
}

# ---- a model for the browser -------------------------------------------------

# How a model prepares images, from its spec: a list for the manifest, or an
# error when the model does not say.
onxPreprocess <- function(spec) {
  nums <- function(v) as.numeric(strsplit(as.character(v), ",", fixed = TRUE)[[1]])
  if (is.null(spec$image_mean) || is.null(spec$image_std) || is.null(spec$image_size)) {
    stop("This model does not say how images are prepared for it (image size, mean and standard deviation), ",
         "so a browser could not prepare photos the same way", call. = FALSE)
  }
  size <- as.integer(spec$image_size)
  list(image_size = size,
       resize = if (is.null(spec$image_resize)) "shortest" else spec$image_resize,
       resize_to = if (is.null(spec$image_resize_to)) size else as.integer(spec$image_resize_to),
       interpolation = if (is.null(spec$image_interpolation)) "bicubic" else spec$image_interpolation,
       crop = if (is.null(spec$image_crop)) "center" else spec$image_crop,
       rescale = 1 / 255,
       mean = nums(spec$image_mean), std = nums(spec$image_std),
       layout = "NCHW", channels = "RGB")
}

#' Write what a web page needs to identify photos with a key's species
#'
#' Photo identification as [suggestSpecies()] and [identifyPhotos()] do it has
#' two halves: the names of the key's results are embedded as texts, and the
#' photo is embedded as an image and compared with them. The text half can be
#' done ahead of time, here; a web page then needs only the image encoder to
#' identify a photo on the visitor's own device, with no server and no
#' upload. This function writes the files such a page loads.
#'
#' @section Files written to `dir`:
#' **`model.json`**, the manifest (UTF-8 JSON):
#'
#' * `format`: `"dimoose-browser-model"`; `version`: `1`.
#' * `key`: `desc` (the key's description) and `taxa` (the number of labels).
#' * `model`: `arch`, `pretrained`, `dim` (embedding dimensions), `library`.
#' * `image_encoder`: `file` (a file name in `dir`, or `null`), `url` (a web
#'   address, or `null`; one of the two is set), `bytes`, `precision`
#'   (`"int8"`, `"fp16"`, `"fp32"` or `null` if unknown), `input` (the input's
#'   name, `"pixel_values"`), `input_type` (`"float32"`), `input_shape`
#'   (`[1, 3, S, S]`), `output` (the output to read, `"image_embeds"`),
#'   `normalized` (`false`: divide the output by its length).
#' * `preprocess`, how to turn a photo into the input: `resize`
#'   (`"shortest"`: scale so the shorter side is `resize_to` pixels, keeping
#'   the shape), `interpolation` (`"bicubic"`), `crop` (`"center"`: cut the
#'   middle `image_size` x `image_size` square), `rescale` (multiply the 0-255
#'   values by this, 1/255), `mean` and `std` (per channel: subtract, then
#'   divide), `layout` (`"NCHW"`), `channels` (`"RGB"`).
#' * `text_embeddings`: `file` (`"text_embeddings.bin"`), `dtype`
#'   (`"float32"`), `byte_order` (`"little"`), `shape` (`[labels, dim]`),
#'   `order` (`"row-major"`: label by label), `normalized` (`true`), `prompt`
#'   (the template).
#' * `labels`: one object per row of the text embeddings, in order: `taxon`
#'   (the result as the key's leads write it, which is what to look up in the
#'   key), `name` (the name put into the prompt: the scientific name when the
#'   result has one) and `prompt` (the text that was embedded).
#' * `logit_scale`: `100`.
#'
#' **`text_embeddings.bin`**: `labels x dim` 32-bit little-endian floats and
#' nothing else, row by row; in JavaScript,
#' `new Float32Array(await (await fetch(url)).arrayBuffer())`.
#'
#' **`image_encoder.onnx`**: the image encoder, unless the manifest gives a
#' `url` instead.
#'
#' @section What the page does:
#' Prepare the photo as `preprocess` says, run the image encoder (for example
#' with onnxruntime-web), divide `image_embeds` by its length to get `v`, and
#' take the dot product of `v` with each row of the text embeddings. The
#' probability of each label is the softmax of `logit_scale` times those dot
#' products, which is what [suggestSpecies()] computes.
#'
#' @section Size:
#' The image encoder is the download that matters. Use an `"int8"` encoder
#' for the web: 96 MB for CLIP ViT-B/32 and 90 MB for BioCLIP as
#' [exportOnnxModel()] writes them, against about 350 MB unquantised, with
#' the same answers on dimoose's example photos (BioCLIP 2, a larger model,
#' is 310 MB even so). Where that is still too much, `"mobileclip-s0"` at
#' `"fp16"` is 23 MB, but it is a general model that does not know species
#' names as BioCLIP does. The text embeddings are tiny
#' (2 KB per label), and are best made with the `"fp32"` text encoder:
#' `onnxModel(name, precision = "int8", textPrecision = "fp32")`.
#'
#' @section Tested with onnxruntime-web:
#' The `"int8"`, `"fp16"` and `"fp32"` encoders that [exportOnnxModel()]
#' writes for CLIP ViT-B/32 and BioCLIP were run in onnxruntime-web 1.31.1 on
#' its WebAssembly backend (under Node.js) from folders this function wrote,
#' with the 14 Montana example photos prepared as `preprocess` says. All
#' three load and run there. Against the same file run in Python the lowest
#' cosine of the embeddings was 0.9996 for `"int8"` and 1.0000 for `"fp16"`
#' and `"fp32"`, and the most likely label was the same for every photo. The
#' `"int8"` files hold 8-bit weights that are turned back into floats when
#' the model loads, so they use no integer arithmetic a runtime might lack.
#' The WebGPU backend was not tested.
#'
#' Ready-made `_quantized` files from the Hub (`encoder = "hub"` with an
#' `"int8"` model) are quantised differently, with integer arithmetic. That
#' of `Xenova/clip-vit-base-patch32` had a lowest cosine of 0.85 with the
#' `"fp32"` embeddings on the same backend and gave another most likely label
#' for 5 of the 14 photos; its `"fp16"` file had 1.0000. Point a page at the
#' `"fp16"` file, or copy in an `"int8"` encoder from [exportOnnxModel()].
#'
#' How the photo is resized matters more than the encoder's precision.
#' `preprocess$interpolation` names the filter the model was trained with
#' (bicubic, with smoothing when a photo is made smaller, as the Python
#' library Pillow does it). With BioCLIP on the Montana photos, resizing with
#' a bilinear filter instead gave embeddings with a cosine of 0.93 to 0.98
#' (0.97 on average) with the right ones, and nearest-neighbour 0.84 to 0.95.
#'
#' @param key A key whose results are the labels.
#' @param model The [onnxModel()] (or [visionModel()]) to embed the labels
#'   with. It must be the model the image encoder belongs to.
#' @param dir Folder to write to; created if needed.
#' @param encoder The image encoder for the page: `NULL` copies the image
#'   encoder of `model` (which must then be an [onnxModel()]); `"hub"` points
#'   the page at that file on the Hugging Face Hub instead of copying it (for
#'   a model that came from there); a file path copies that file; a web
#'   address (`https://...`) is written to the manifest as it is.
#' @param prompt The text each name is put into, with `%s` where the name
#'   goes, as in [suggestSpecies()].
#' @param textEmb Optional text embeddings made earlier, a matrix whose row
#'   names are the prompts (from [embedTexts()] or [loadEmbeddings()]); the
#'   labels are then not embedded again.
#' @return The path of `model.json`, invisibly.
#' @seealso [onnxModel()], [exportOnnxModel()], [suggestSpecies()].
#' @examples
#' \dontrun{
#' model <- onnxModel("bioclip", precision = "int8", textPrecision = "fp32")
#' exportBrowserModel(montanaKey(), model, "site/model")
#' list.files("site/model")   # image_encoder.onnx, model.json, text_embeddings.bin
#' }
#' @export
exportBrowserModel <- function(key, model, dir, encoder = NULL, prompt = "a photo of %s.", textEmb = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  if (!inherits(model, "dimooseVisionModel")) stop("`model` must be a vision model from onnxModel() or visionModel()", call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package", call. = FALSE)
  if (!is.character(prompt) || length(prompt) != 1 || is.na(prompt) || !grepl("%s", prompt, fixed = TRUE)) {
    stop("`prompt` must contain %s where the species name goes", call. = FALSE)
  }
  if (!is.character(dir) || length(dir) != 1 || is.na(dir) || !nzchar(dir)) stop("`dir` must be one folder name", call. = FALSE)
  if (file.exists(dir) && !dir.exists(dir)) stop(dir, " is a file; `dir` must be a folder", call. = FALSE)
  if (!is.null(encoder) && (!is.character(encoder) || length(encoder) != 1 || is.na(encoder) || !nzchar(encoder))) {
    stop("`encoder` must be NULL, \"hub\", one file or one web address", call. = FALSE)
  }
  taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
  if (!length(taxa)) stop("This key names no results", call. = FALSE)
  name <- scientificPart(taxa)
  name[is.na(name)] <- taxa[is.na(name)]
  prompts <- tryCatch(sprintf(prompt, name), error = function(e) {
    stop("`prompt` must contain %s once, where the species name goes, and no other % (write %% for a percent sign)", call. = FALSE)
  })
  pre <- onxPreprocess(model$spec)

  # the image encoder: a file to copy, or an address to point at
  url <- NULL; source <- NULL
  if (is.null(encoder)) {
    source <- model$files$image
    if (is.null(source)) {
      stop("`model` is not an ONNX model, so it has no image encoder file for the page; ",
           "give one in `encoder` (a file or a web address), or use onnxModel()", call. = FALSE)
    }
  } else if (identical(encoder, "hub")) {
    url <- model$files$imageUrl
    if (is.null(url)) stop("`model` did not come from the Hugging Face Hub, so there is no web address for its image encoder", call. = FALSE)
  } else if (grepl("^https?://", encoder)) {
    url <- encoder
  } else {
    source <- encoder
  }
  if (!is.null(source) && (!file.exists(source) || dir.exists(source))) stop("No such image encoder file: ", source, call. = FALSE)
  own <- is.null(encoder) || identical(encoder, "hub")
  bytes <- if (!is.null(source)) onxSize(source) else if (own && !is.null(model$files$image)) onxSize(model$files$image) else NULL

  if (is.null(textEmb)) {
    textEmb <- embedTexts(model, prompts)
  } else {
    missing <- setdiff(prompts, rownames(textEmb))
    if (length(missing)) stop("`textEmb` lacks rows for ", length(missing), " prompt(s), e.g. ", missing[1], call. = FALSE)
    textEmb <- textEmb[prompts, , drop = FALSE]
  }
  if (ncol(textEmb) != model$spec$dim) {
    stop("The text embeddings have ", ncol(textEmb), " dimensions, but the model has ", model$spec$dim, call. = FALSE)
  }
  textEmb <- textEmb / sqrt(rowSums(textEmb^2))
  bad <- which(!is.finite(rowSums(textEmb)))
  if (length(bad)) {
    stop("The text embedding of \"", prompts[bad[1]], "\" is all zeros or not a number, so a page could not compare photos with it",
         call. = FALSE)
  }

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dir)) stop("Could not create the folder ", dir, call. = FALSE)
  if (!is.null(source)) {
    dest <- file.path(dir, "image_encoder.onnx")
    if (normalizePath(source) != normalizePath(dest, mustWork = FALSE)) file.copy(source, dest, overwrite = TRUE)
    if (bytes > 150e6) {
      message("The image encoder is ", round(bytes / 1e6), " MB, a long download for a web page; ",
              "an int8 encoder (onnxModel(precision = \"int8\")) is about a quarter of that")
    }
  }
  writeBin(as.numeric(t(textEmb)), file.path(dir, "text_embeddings.bin"), size = 4, endian = "little")

  s <- model$spec
  manifest <- list(
    format = "dimoose-browser-model",
    version = 1L,
    key = list(desc = if (is.null(key$desc)) NULL else as.character(key$desc)[1], taxa = length(taxa)),
    model = list(arch = s$arch, pretrained = s$pretrained, dim = as.integer(s$dim), library = s$library),
    image_encoder = list(
      file = if (is.null(source)) NULL else "image_encoder.onnx",
      url = url,
      bytes = bytes,
      precision = if (own) s$precision else NULL,
      input = "pixel_values", input_type = "float32",
      input_shape = I(c(1L, 3L, pre$image_size, pre$image_size)),
      output = "image_embeds", normalized = FALSE),
    preprocess = c(pre[c("image_size", "resize", "resize_to", "interpolation", "crop", "rescale")],
                   list(mean = I(pre$mean), std = I(pre$std), layout = pre$layout, channels = pre$channels)),
    text_embeddings = list(file = "text_embeddings.bin", dtype = "float32", byte_order = "little",
                           shape = I(dim(textEmb)), order = "row-major", normalized = TRUE, prompt = prompt),
    labels = lapply(seq_along(taxa), function(i) list(taxon = taxa[i], name = name[i], prompt = prompts[i])),
    logit_scale = 100L)
  out <- file.path(dir, "model.json")
  writeLines(enc2utf8(as.character(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA))),
             out, useBytes = TRUE)
  invisible(out)
}
