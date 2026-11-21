#' Export an interactive dichotomous key
#'
#' Writes a dimoose key as a single self-contained HTML page. With JavaScript
#' on, the page steps through the key one couplet at a time, keeps a trail of
#' the choices made (each one clickable to go back to it) and supports the
#' browser's Back button. Without JavaScript, the same page is the full key
#' with every lead hyperlinked to its next couplet or taxon. Each taxon gets
#' a result section listing the characters on its path, and a map of the
#' key shows where the user is (see `map`).
#'
#' The key is checked first: leads pointing at missing couplets, terminal
#' leads without a taxon, couplets with fewer than two leads and couplets
#' that cannot be reached from the first one are reported as warnings and
#' marked in the page.
#'
#' @section Not sure:
#' Every couplet has an "I'm not sure" button (keys `u` or `?`). It follows
#' all leads of the couplet at once. The page then asks the questions of one
#' branch at a time, lists the branches still open (click one to answer it
#' next), and counts and marks on the map the taxa possible in any of them.
#' Each answer narrows its own branch. If the reader stays unsure to the end,
#' the page lists every result that is left. Back undoes one step at a time.
#' The address of the page records the open branches (`#open=c-3,c-9`), so a
#' reload or a shared link returns to the same place; the trail of choices
#' comes back too when the browser restores the page's history entry.
#'
#' @section Picking characters in any order:
#' With `matrix`, the page gains a second way in: a list of the characters of
#' the matrix, to answer in any order. Picking a state removes the taxa that
#' do not have it. A taxon with several states (`"a/b"`) fits any of them, and
#' a taxon whose state is unknown (`NA`) fits all. The characters that still
#' separate the remaining taxa are listed first: cheapest first when
#' `characters` gives a `Cost`, then those that leave the fewest taxa on
#' average. Taxa of the matrix are matched to the key's taxa by name (ignoring
#' case), so the remaining taxa link to their result sections and show on the
#' map, and the page offers to continue step by step from the couplet they all
#' share. Without JavaScript the matrix is a plain table. The two ways are
#' otherwise independent: answers given step by step do not filter the
#' character list. With `key = NULL` the page is the character list alone.
#'
#' @section Offline use:
#' The page itself needs no connection once it is open, but a browser will not
#' reopen a page it cannot fetch. `offline = TRUE` writes four files next to
#' `file`, named after it: a web app manifest (`<name>.webmanifest`), a
#' service worker (`<name>-sw.js`) and two icons (`<name>-icon-192.png`,
#' `<name>-icon-512.png`; the package logo if the rsvg package is installed,
#' otherwise a simple drawn icon). The worker stores the page, the manifest,
#' the icons and the figures the page loads from other sites, so that the
#' page can be installed on a phone ("Add to Home Screen") and opened without
#' signal. Upload all five files to the same folder. Limits:
#'
#' * Browsers run service workers only on `https://` or `http://localhost`. A
#'   page opened from disk (`file://`) works as before but is not installed
#'   and stores nothing.
#' * The page must be opened once with a connection before it works without.
#' * Figures on other sites are fetched when the worker installs and again
#'   when first shown; any that fail are skipped. A site that does not allow
#'   cross-origin requests gives an opaque copy, which browsers count as
#'   several megabytes each against the storage they allow, so a key with
#'   many such figures may not store them all. Figures embedded in the key
#'   (see [imageMeta()]) are part of the page and always available. Full-size
#'   figures and taxon pages that open in a new tab are not stored.
#' * The worker only controls the page it was written for (its scope is the
#'   page's own address), so several keys can share a folder. Serve the page
#'   under its file name; a server that drops the `.html` from addresses puts
#'   the page outside the worker's scope.
#'
#' @section Identifying from a photo:
#' `photoModel` adds an "Identify from a photo" button. The reader takes or
#' picks a photo; the page loads the model and
#' [onnxruntime-web](https://onnxruntime.ai/docs/tutorials/web/) (the program
#' that runs it, version 1.31.1, about 15 MB, from the jsDelivr CDN unless
#' `photoRuntime` says otherwise), prepares the picture as the model's
#' `model.json` says, runs the image encoder in the browser and compares the
#' result with the text embeddings of the key's taxa. The photo never leaves
#' the reader's device. The page then marks the likely taxa on the map, lists
#' the five best with their scores, each linked to its result, and offers to
#' narrow the key to them: the leads that reach none of them are greyed and
#' the count of remaining taxa follows, but every lead still works. The key
#' stays the authority; the photo is a hint.
#'
#' `photoModel` is a folder written by [exportBrowserModel()] for the same
#' key, or the web address of one. The model is not put into the page. A
#' folder is copied next to `file` as `<name>_model/` (so `file` is needed);
#' upload it with the page. A web address is used as it is; a model on
#' another site must allow cross-origin requests. What to expect:
#'
#' * Nothing is downloaded until the reader has chosen a photo, been told the
#'   size and agreed. An int8 BioCLIP encoder is 90 MB; with the runtime that
#'   is about 105 MB on first use. The page shows the progress.
#' * With `offline = TRUE` the service worker keeps the model and the runtime
#'   once they have been fetched, so photos can be identified without a
#'   connection afterwards. That is the same 105 MB or so of storage on the
#'   reader's device, and the first use still needs a connection.
#' * It needs a browser with WebAssembly, and memory: several times the size
#'   of the encoder while it loads. If the browser cannot run the model, runs
#'   out of memory or cannot fetch it, the page says so and the key works as
#'   before. A page opened from disk (`file://`) cannot load the model.
#' * Only the WebAssembly backend is used, on one thread unless the page is
#'   served cross-origin isolated. That suits int8 encoders, which WebGPU
#'   cannot run.
#' * The scores compare the key's taxa with each other and add up to 100%,
#'   so a photo of something that is not in the key still gets a confident
#'   best match. If `model.json` has a `min_similarity`, a best match whose
#'   cosine similarity is under it is shown as "Not much like any taxon of
#'   this key" without a percentage.
#'
#' @section Notes on leads:
#' A `Note` column in the key's leads, as [pruneKey()] writes when it
#' collapses a couplet (the character of the couplet that is no longer asked),
#' is shown under its lead as "Also:" and in the path of each result. A
#' `pruned_note` in the key's meta (the same for a collapsed first couplet) is
#' shown under the title.
#'
#' @section Hook for other scripts:
#' The page defines `window.dimoose` so that another script, for example one
#' that identifies a photo in the browser, can work with the page without
#' knowing how it is built:
#'
#' * `dimoose.taxa`: array of `{ id, name }`, one per result.
#' * `dimoose.highlight(scores, opts)`: `scores` is an object mapping taxon
#'   names or ids to numbers, or an array of `{ taxon, score }`; `null`
#'   clears. Marks those taxa on the map and in every list of candidates and
#'   lists the five best above the key, headed by `opts.label` (default
#'   "Suggested"). Scores all within 0 to 1 are shown as percentages. Returns
#'   the ids it marked, best first.
#' * `dimoose.goToTaxon(nameOrId)`: shows that result; `false` if unknown.
#' * `dimoose.narrow(namesOrIds)`: narrows the key to these taxa (see
#'   'Identifying from a photo'); `null` undoes it. Returns the ids kept.
#' * `dimoose.state()`: `{ shown, open, remaining, picks, narrowed }`, the
#'   section shown, the open branches, the ids of the taxa still possible, the
#'   states picked in the character list and the ids the key is narrowed to
#'   (or `null`).
#' * `dimoose.photo` (only with `photoModel`): `identify(file)`, a promise of
#'   the ranked taxa, and the pure steps `preprocess()` and `score()`.
#' * `dimoose.onChange(fn)`: calls `fn(state)` after every step.
#'
#' @param key A [dimoose] object, e.g. from [importFishbase()]. May be `NULL`
#'   if `matrix` is given.
#' @param file Path of the HTML file to write. If `NULL`, the HTML is returned
#'   as a string instead.
#' @param displayLinks If `TRUE`, show the couplet numbers each lead leads to
#'   and comes from, as in a printed key. If `FALSE`, hide them. Leads stay
#'   clickable either way.
#' @param order Deprecated and ignored. Couplets are always exported in the
#'   key's own order. `"parsimony"` was never implemented; to ask the
#'   questions that are easiest to observe first, build the key with
#'   [keyFromMatrix()] and give the characters a `Cost`.
#' @param title Page title. Defaults to the key's description.
#' @param staticPaths If `TRUE`, write each taxon's path through the key into
#'   the page, so it shows without JavaScript. If `FALSE`, the page builds
#'   the path in the browser when a result is shown, which keeps large keys
#'   (such as [phylotreeKey()] on the whole tree) much smaller. The default
#'   is `TRUE` for keys with up to 1,000 taxa.
#' @param map If `TRUE`, include a map of the key: the whole key drawn as a
#'   tree, marking the current couplet, the path taken so far and the
#'   branches (and number of taxa) still possible. It sits beside the key on
#'   wide screens and behind a Map button on phones.
#' @param matrix Optional character matrix: a data frame with one row per
#'   taxon, the taxon's name in column `taxon` and one column per character.
#'   Cells are states; several states of one taxon are separated by `"/"`;
#'   `NA` is unknown or inapplicable. See 'Picking characters in any order'.
#' @param characters Optional data frame describing the characters of
#'   `matrix`: column `Character` (a column name of `matrix`) and any of
#'   `Cost` (lower is easier to observe), `Season` (when it can be observed)
#'   and `Needs` (e.g. `"hand lens"`).
#' @param taxon Name of the column of `matrix` that holds the taxon names.
#' @param offline If `TRUE`, also write a web app manifest, a service worker
#'   and icons next to `file`, so that the page can be installed and opened
#'   without a connection. Needs `file`. See 'Offline use'.
#' @param photoModel Optional: a folder written by [exportBrowserModel()] for
#'   this key, or the web address (`https://...`) of one. Adds "Identify from
#'   a photo" to the page. See 'Identifying from a photo'.
#' @param photoRuntime Optional web address of a folder holding the `dist`
#'   files of onnxruntime-web (`ort.wasm.min.js`, `ort-wasm-simd-threaded.mjs`
#'   and `.wasm`), to serve them yourself instead of loading them from
#'   jsDelivr. Relative addresses are relative to the page.
#' @return The path to `file`, invisibly, or the HTML as a character string if
#'   `file` is `NULL`. With `offline = TRUE` or a `photoModel` folder the
#'   paths of the other files written are in attribute `"files"`.
#' @seealso [keyFromMatrix()] to build a key from a character matrix.
#' @examples
#' leads <- data.frame(
#'   Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
#'   Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
#'   Next = c("2", "-", "-", "-"), Taxon = c("", "Silverfish", "Fly", "Bee")
#' )
#' key <- keyFromLeads(leads, "A tiny key")
#' html <- exportWizard(key)
#' substr(html, 1, 15)
#'
#' # With a character matrix the reader can also pick characters in any order
#' insects <- data.frame(
#'   Taxon = c("Silverfish", "Fly", "Bee", "Ant"),
#'   Wings = c("absent", "present", "present", "present/absent"),
#'   Sting = c("absent", "absent", "present", NA)
#' )
#' characters <- data.frame(Character = c("Wings", "Sting"), Cost = c(1, 3),
#'                          Needs = c("", "hand lens"))
#' html <- exportWizard(key, matrix = insects, characters = characters)
#'
#' # A matrix alone makes a page with only the character list
#' html <- exportWizard(NULL, matrix = insects, title = "Four insects")
#'
#' # An installable copy that opens without a connection once it is served
#' # over https: the page, a manifest, a service worker and two icons
#' dir <- tempfile("key")
#' dir.create(dir)
#' out <- exportWizard(key, file.path(dir, "insects.html"), offline = TRUE)
#' list.files(dir)
#' unlink(dir, recursive = TRUE)
#' @export
exportWizard <- function(key = NULL, file = NULL, displayLinks = TRUE,
                         order = "original", title = NULL,
                         map = TRUE, staticPaths = NULL,
                         matrix = NULL, characters = NULL, taxon = "Taxon",
                         offline = FALSE, photoModel = NULL, photoRuntime = NULL) {
  order <- match.arg(order, c("original", "parsimony"))
  if (order == "parsimony") {
    warning("`order` is deprecated and ignored: exportWizard() keeps the key's own order. ",
            "To ask the easiest questions first, build the key with ",
            "keyFromMatrix(characters = ) and give the characters a Cost.", call. = FALSE)
  }
  if (is.null(key)) {
    if (is.null(matrix)) stop("Give a `key`, a `matrix`, or both", call. = FALSE)
    leads <- normalizeLeads(data.frame(Statement = character(), stringsAsFactors = FALSE))
    check <- list(root = NA_character_, couplets = character(), missingTarget = logical(),
                  unreachable = character(), problems = character())
    key <- list(desc = NA, meta = NULL, taxa = NULL, features = NULL)
  } else {
    if (!inherits(key, "dimoose")) {
      stop("`key` must be a dimoose object", call. = FALSE)
    }
    leads <- normalizeLeads(key$leads)
    if (nrow(leads) == 0) {
      stop("This key has no leads to export", call. = FALSE)
    }
    check <- checkLeads(leads)
    for (w in check$problems) warning(w, call. = FALSE)
  }
  hasKey <- nrow(leads) > 0
  mx <- if (is.null(matrix)) NULL else wizMatrix(matrix, characters, taxon)
  if (is.null(mx) && !is.null(characters)) {
    warning("`characters` describes the columns of `matrix` and is ignored without one", call. = FALSE)
  }

  if (is.null(title)) {
    title <- if (length(key$desc) == 1 && !is.na(key$desc)) key$desc else if (hasKey) "Dichotomous key" else "Multi-access key"
  }
  nodeLabel <- metaValue(key$meta, "node_label")
  if (is.na(nodeLabel) || !nzchar(nodeLabel)) nodeLabel <- "Couplet"
  if (is.null(staticPaths)) {
    staticPaths <- length(unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])) <= 1000
  }
  images <- embeddedImages(key$meta)

  if (isTRUE(offline) && is.null(file)) {
    warning("offline = TRUE needs `file`: the manifest, service worker and icons are written next to it. ",
            "Returning the page alone.", call. = FALSE)
    offline <- FALSE
  }
  side <- if (isTRUE(offline)) wizOfflineNames(file) else NULL
  photo <- if (is.null(photoModel)) NULL else wizPhotoModel(photoModel, file, photoRuntime, leads)
  if (is.null(photo) && !is.null(photoRuntime)) {
    warning("`photoRuntime` is only used with `photoModel` and is ignored", call. = FALSE)
  }

  html <- renderWizard(leads, check,
    nodeLabel = nodeLabel,
    staticPaths = isTRUE(staticPaths),
    title = title,
    citation = metaValue(key$meta, "citation"),
    taxa = key$taxa,
    images = images,
    displayLinks = displayLinks,
    map = map,
    features = key$features,
    matrix = mx,
    offline = side,
    photo = photo,
    note = metaValue(key$meta, "pruned_note")
  )
  if (is.null(file)) {
    if (!is.null(photo)) wizPhotoMessage(photo, FALSE)
    return(html)
  }
  wizWriteText(html, file)
  written <- character()
  if (!is.null(side)) {
    written <- wizWriteOffline(side, html, title, wizExternalImages(leads, images),
                               keep = if (is.null(photo)) character() else photo$keep,
                               stamp = if (is.null(photo)) "" else photo$stamp)
  }
  if (!is.null(photo)) {
    written <- c(written, wizCopyPhotoModel(photo))
    wizPhotoMessage(photo, isTRUE(offline))
  }
  if (length(written)) attr(file, "files") <- written
  invisible(file)
}

# ---- identify from a photo -------------------------------------------------------

# onnxruntime-web, the program that runs the image encoder in the page. The
# version is pinned: the page loads these three files of it.
wizOrt <- list(
  version = "1.31.1",
  files = c("ort.wasm.min.js", "ort-wasm-simd-threaded.mjs", "ort-wasm-simd-threaded.wasm"),
  bytes = 53796 + 24738 + 14848852
)
wizOrtUrl <- function() sprintf("https://cdn.jsdelivr.net/npm/onnxruntime-web@%s/dist/", wizOrt$version)

# Checks `photoModel` (a folder written by exportBrowserModel() or the web
# address of one). Returns what the page and the copy need: `url` (the
# address of the folder as the page sees it), `runtime`, `runtimeBytes`
# (known for the pinned runtime only), `from`/`to`/`files` for a folder to
# copy, `bytes` of the model when known, and `keep`, the addresses
# (the model and the runtime) that the service worker should keep once
# fetched, with `stamp`, a fingerprint of the model. NULL (with a warning) when a
# folder is given but there is no `file` to copy it next to.
wizPhotoModel <- function(photoModel, file, runtime = NULL, leads = NULL) {
  if (!is.character(photoModel) || length(photoModel) != 1 || is.na(photoModel) || !nzchar(photoModel)) {
    stop("`photoModel` must be one folder written by exportBrowserModel(), or the web address of one", call. = FALSE)
  }
  folderUrl <- function(x) paste0(sub("/+$", "", x), "/")
  if (is.null(runtime)) {
    runtime <- wizOrtUrl()
    runtimeBytes <- wizOrt$bytes
  } else {
    if (!is.character(runtime) || length(runtime) != 1 || is.na(runtime) || !nzchar(runtime)) {
      stop("`photoRuntime` must be the web address of a folder with the files of onnxruntime-web", call. = FALSE)
    }
    runtime <- folderUrl(runtime)
    runtimeBytes <- NA_real_
  }
  out <- list(runtime = runtime, runtimeBytes = runtimeBytes, bytes = NA_real_, keep = runtime, stamp = "")
  if (grepl("^https?://", photoModel)) {
    out$url <- folderUrl(sub("model\\.json$", "", photoModel))
    out$keep <- c(out$keep, out$url)
    return(out)
  }
  dir <- if (!dir.exists(photoModel) && basename(photoModel) == "model.json") dirname(photoModel) else photoModel
  manifest <- file.path(dir, "model.json")
  if (!dir.exists(dir) || !file.exists(manifest)) {
    stop("`photoModel` must be a folder written by exportBrowserModel() (with a model.json), or a web address: ",
         photoModel, call. = FALSE)
  }
  text <- paste(readLines(manifest, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("dimoose-browser-model", text, fixed = TRUE)) {
    stop(manifest, " is not a model written by exportBrowserModel()", call. = FALSE)
  }
  files <- c("model.json", list.files(dir, pattern = "\\.(bin|onnx)$"))
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    m <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(m)) stop(manifest, " cannot be read as JSON", call. = FALSE)
    named <- c(m$text_embeddings$file, m$image_encoder$file)
    missing <- named[!file.exists(file.path(dir, named))]
    if (length(missing)) stop("`photoModel` lacks ", paste(missing, collapse = ", "), ", which its model.json names", call. = FALSE)
    files <- c("model.json", named)
    if (!length(m$image_encoder$file) && !length(m$image_encoder$url)) {
      stop(manifest, " names no image encoder (neither a file nor a web address)", call. = FALSE)
    }
    if (length(m$image_encoder$url)) out$keep <- c(out$keep, m$image_encoder$url)
    if (length(m$image_encoder$bytes)) out$bytes <- as.numeric(m$image_encoder$bytes)
    if (!is.null(leads)) {
      labels <- vapply(m$labels, function(l) as.character(l$taxon), "")
      taxa <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
      if (length(taxa) && !any(labels %in% taxa)) {
        warning("`photoModel` was made for another key: none of its ", length(labels),
                " labels is a result of this one, so a photo will highlight nothing. ",
                "Make it with exportBrowserModel() from this key.", call. = FALSE)
      } else if (length(setdiff(taxa, labels))) {
        message(length(setdiff(taxa, labels)), " of ", length(taxa), " results of the key are not in `photoModel` and cannot be suggested from a photo: ",
                paste(utils::head(setdiff(taxa, labels), 5), collapse = ", "), if (length(setdiff(taxa, labels)) > 5) ", ..." else "")
      }
    }
  }
  if (is.null(file)) {
    warning("A `photoModel` folder is copied next to `file`, so it needs `file` (or give a web address). ",
            "Returning the page without photo identification.", call. = FALSE)
    return(NULL)
  }
  if (is.na(out$bytes)) out$bytes <- sum(file.size(file.path(dir, files[grepl("\\.onnx$", files)])))
  folder <- paste0(sub("\\.[^.]*$", "", basename(file)), "_model")
  out$url <- paste0(utils::URLencode(folder, reserved = TRUE), "/")
  out$keep <- c(out$keep, out$url)
  # a model made again gets a new store on the reader's device
  out$stamp <- wizHash(paste(text, paste(file.size(file.path(dir, files)), collapse = " ")))
  out$from <- dir
  out$to <- file.path(dirname(file), folder)
  out$files <- unique(files)
  out
}

# Copies the model next to the page; files already there with the same size
# and no older than the source are left alone (the encoder is large).
wizCopyPhotoModel <- function(photo) {
  if (is.null(photo$from)) return(character())
  dir.create(photo$to, showWarnings = FALSE, recursive = TRUE)
  from <- file.path(photo$from, photo$files)
  to <- file.path(photo$to, photo$files)
  same <- normalizePath(from) == normalizePath(to, mustWork = FALSE)
  fresh <- file.exists(to) & file.size(to) == file.size(from) & file.mtime(to) >= file.mtime(from)
  todo <- !same & (is.na(fresh) | !fresh)
  ok <- file.copy(from[todo], to[todo], overwrite = TRUE, copy.date = TRUE)
  if (!all(ok)) stop("Could not copy the model to ", photo$to, call. = FALSE)
  to
}

wizPhotoMessage <- function(photo, offline) {
  mb <- function(x) paste(format(round(x / 1e6), big.mark = ","), "MB")
  model <- if (is.na(photo$bytes)) "the model" else paste0("the model (", mb(photo$bytes), ")")
  runtime <- if (is.na(photo$runtimeBytes)) "onnxruntime-web" else paste0("onnxruntime-web ", wizOrt$version, " (", mb(photo$runtimeBytes), ")")
  total <- photo$bytes + photo$runtimeBytes
  message(
    if (!is.null(photo$to)) paste0("The model was copied to ", photo$to, ": upload that folder with the page. "),
    "The first time a reader identifies a photo, the page downloads ", model, " and ", runtime,
    if (!is.na(total)) paste0(", ", mb(total), " in all"), ", after asking.",
    if (offline) paste0(" With offline = TRUE the service worker then keeps them",
                        if (!is.na(total)) paste0(" (", mb(total), " of storage on the reader's device)"),
                        ", so photos can be identified without a connection afterwards.")
  )
}

# Write bytes so UTF-8 text survives non-UTF-8 locales
wizWriteText <- function(text, file) {
  con <- file(file, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(text)), con)
  invisible(file)
}

# ---- character matrix --------------------------------------------------------

# Checks a character matrix and its optional character table. Returns
# list(taxa, characters, cells, cost, season, needs): `cells` is a character
# matrix (taxa x characters) of trimmed state strings, NA where unknown;
# characters are ordered cheapest first when costs are given.
wizMatrix <- function(matrix, characters = NULL, taxon = "Taxon") {
  if (!is.data.frame(matrix)) stop("`matrix` must be a data frame with one row per taxon", call. = FALSE)
  if (!is.character(taxon) || length(taxon) != 1 || !taxon %in% names(matrix)) {
    stop("`taxon` must name the column of `matrix` that holds the taxon names", call. = FALSE)
  }
  name <- trimws(as.character(matrix[[taxon]]))
  if (length(name) == 0) stop("`matrix` has no rows", call. = FALSE)
  if (anyNA(name) || any(!nzchar(name))) stop("`matrix` has rows with no taxon name", call. = FALSE)
  if (anyDuplicated(name)) {
    stop("`matrix` lists a taxon more than once: ", paste(unique(name[duplicated(name)]), collapse = ", "),
         ". Give a variable taxon one row, with its states separated by \"/\".", call. = FALSE)
  }
  chars <- setdiff(names(matrix), taxon)
  if (length(chars) == 0) stop("`matrix` has no character columns", call. = FALSE)
  cells <- vapply(chars, function(ch) {
    x <- trimws(as.character(matrix[[ch]]))
    x[!is.na(x) & !nzchar(gsub("[/[:space:]]", "", x))] <- NA
    x
  }, character(length(name)))
  cells <- base::matrix(cells, nrow = length(name), dimnames = list(name, chars))

  cost <- rep(NA_real_, length(chars))
  season <- needs <- rep("", length(chars))
  if (!is.null(characters)) {
    if (!is.data.frame(characters) || !"Character" %in% names(characters)) {
      stop("`characters` must be a data frame with a column `Character`", call. = FALSE)
    }
    row <- match(chars, trimws(as.character(characters$Character)))
    text <- function(col) {
      if (is.null(characters[[col]])) return(rep("", length(chars)))
      x <- trimws(as.character(characters[[col]])[row])
      x[is.na(x)] <- ""
      x
    }
    if (!is.null(characters$Cost)) cost <- suppressWarnings(as.numeric(characters$Cost))[row]
    season <- text("Season")
    needs <- text("Needs")
  }
  o <- order(cost, na.last = TRUE)   # stable: matrix order among equal costs
  list(taxa = name, characters = chars[o], cells = cells[, o, drop = FALSE],
       cost = cost[o], season = season[o], needs = needs[o])
}

# The matrix as a section of the page: a plain table, which the page script
# reads and turns into the list of characters to pick from. `ids` gives the
# id of every taxon (the key's result section, or its own).
wizMatrixHtml <- function(mx, ids, linked) {
  note <- function(j) {
    bits <- c(if (nzchar(mx$needs[j])) paste("needs", mx$needs[j]), if (nzchar(mx$season[j])) mx$season[j])
    if (length(bits)) sprintf("<small>%s</small>", htmlEscape(paste(bits, collapse = " \u00b7 "))) else ""
  }
  head <- vapply(seq_along(mx$characters), function(j) {
    sprintf("<th scope=\"col\" data-char=\"%s\"%s%s%s>%s%s</th>",
      htmlEscape(mx$characters[j]),
      if (is.na(mx$cost[j])) "" else sprintf(" data-cost=\"%s\"", format(mx$cost[j], scientific = FALSE, trim = TRUE)),
      if (nzchar(mx$season[j])) sprintf(" data-season=\"%s\"", htmlEscape(mx$season[j])) else "",
      if (nzchar(mx$needs[j])) sprintf(" data-needs=\"%s\"", htmlEscape(mx$needs[j])) else "",
      htmlEscape(mx$characters[j]), note(j))
  }, character(1))
  rows <- vapply(seq_along(mx$taxa), function(i) {
    x <- mx$cells[i, ]
    cells <- ifelse(is.na(x), "<td data-na>?</td>", paste0("<td>", htmlEscape(x), "</td>"))
    name <- htmlEscape(mx$taxa[i])
    sprintf("<tr data-taxon=\"%s\"><th scope=\"row\">%s</th>%s</tr>", ids[i],
      if (linked[i]) sprintf("<a href=\"#%s\">%s</a>", ids[i], name) else name,
      paste(cells, collapse = ""))
  }, character(1))
  paste0(
    "<section class=\"matrix\" id=\"matrix\" aria-labelledby=\"h-matrix\">\n",
    "<h2 id=\"h-matrix\" tabindex=\"-1\">Pick any character you can see</h2>\n",
    "<p class=\"intro\">The table gives the state of each character in each taxon. ",
    "States separated by &quot;/&quot; both occur in the taxon; &quot;?&quot; is unknown or does not apply. ",
    "Strike out the taxa that do not fit what you see.</p>\n",
    "<details class=\"matrix-table\" open>\n<summary>The whole table</summary>\n<div class=\"table-scroll\">\n",
    "<table class=\"cmatrix\">\n<thead><tr><th scope=\"col\">Taxon</th>", paste(head, collapse = ""), "</tr></thead>\n",
    "<tbody>\n", paste(rows, collapse = "\n"), "\n</tbody>\n</table>\n</div>\n</details>\n</section>"
  )
}

# ---- offline copy --------------------------------------------------------------

wizJsonString <- function(x) {
  x <- gsub("\\", "\\\\", enc2utf8(x), fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  x <- gsub("<", "\\u003c", x, fixed = TRUE)
  paste0("\"", x, "\"")
}

# A short fingerprint of a text, so that a changed page gets a new cache
wizHash <- function(x) {
  b <- as.numeric(charToRaw(enc2utf8(x)))
  sprintf("%08x%06x", as.integer(sum(b * (seq_along(b) %% 65521 + 1)) %% 2147483629), length(b) %% 16777216)
}

# Names of the files written next to the page, as paths and as the relative
# addresses the page and the worker use
wizOfflineNames <- function(file) {
  page <- basename(file)
  base <- sub("\\.[^.]*$", "", page)
  names <- c(manifest = paste0(base, ".webmanifest"), sw = paste0(base, "-sw.js"),
             icon192 = paste0(base, "-icon-192.png"), icon512 = paste0(base, "-icon-512.png"))
  url <- function(x) utils::URLencode(x, reserved = TRUE)
  # a page called index.html is usually served as its folder
  index <- tolower(page) %in% c("index.html", "index.htm")
  list(dir = dirname(file), page = page, base = base, files = names,
       url = c(page = url(page), vapply(names, url, "")),
       scope = if (index) "./" else paste0("./", url(page)))
}

wizWriteOffline <- function(side, html, title, external = character(), keep = character(), stamp = "") {
  path <- function(x) file.path(side$dir, side$files[[x]])
  icon <- function(size) list(src = side$url[[paste0("icon", size)]], size = size)
  manifest <- paste0(
    "{\n",
    "  \"name\": ", wizJsonString(title), ",\n",
    "  \"short_name\": ", wizJsonString(if (nchar(title) > 12) side$base else title), ",\n",
    "  \"description\": ", wizJsonString(paste("Identification key:", title)), ",\n",
    "  \"start_url\": ", wizJsonString(side$scope), ",\n",
    "  \"scope\": ", wizJsonString(side$scope), ",\n",
    "  \"display\": \"standalone\",\n",
    "  \"background_color\": \"#f6f3eb\",\n",
    "  \"theme_color\": \"#1d6b58\",\n",
    "  \"icons\": [\n",
    paste(vapply(c(192, 512), function(size) {
      sprintf("    {\"src\": %s, \"sizes\": \"%dx%d\", \"type\": \"image/png\", \"purpose\": \"any\"}",
        wizJsonString(icon(size)$src), size, size)
    }, ""), collapse = ",\n"),
    "\n  ]\n}\n"
  )
  wizWriteText(manifest, path("manifest"))
  wizIcon(path("icon192"), 192)
  wizIcon(path("icon512"), 512)

  sw <- paste(readLines(system.file("wizard", "sw.js", package = "dimoose"), warn = FALSE), collapse = "\n")
  prefix <- paste0("dimoose-", gsub("[^A-Za-z0-9_-]", "_", side$base), "-")
  array <- function(x) paste(wizJsonString(x), collapse = ", ")
  fill <- c(
    "\"__CACHE__\"" = wizJsonString(paste0(prefix, wizHash(paste(html, paste(external, collapse = "\n"))))),
    "\"__PREFIX__\"" = wizJsonString(prefix),
    "\"__KEPT__\"" = wizJsonString(paste0(prefix, "kept-", stamp)),
    "\"__PAGE__\"" = wizJsonString(side$url[["page"]]),
    "[/*__PRECACHE__*/]" = paste0("[", array(unname(side$url[c("page", "manifest", "icon192", "icon512")])), "]"),
    "[/*__EXTERNAL__*/]" = paste0("[", if (length(external)) array(external) else "", "]"),
    "[/*__KEEP__*/]" = paste0("[", if (length(keep)) array(unique(keep)) else "", "]")
  )
  for (token in names(fill)) sw <- sub(token, fill[[token]], sw, fixed = TRUE)
  wizWriteText(paste0(sw, "\n"), path("sw"))
  unname(vapply(names(side$files), path, ""))
}

# Figures the page loads from other sites (those not embedded in the key)
wizExternalImages <- function(leads, images) {
  urls <- unique(unlist(lapply(leads$Image, splitUrls)))
  if (length(urls) == 0) return(character())
  name <- sub("\\.(gif|jpe?g|png|webp)$", "", basename(urls), ignore.case = TRUE)
  urls[grepl("^https?://", urls) & !name %in% names(images)]
}

# App icon: the package logo when it can be drawn (needs rsvg), otherwise a
# plain drawn one.
wizIcon <- function(file, size) {
  logo <- c(system.file("help", "figures", "logo.svg", package = "dimoose"),
            system.file("man", "figures", "logo.svg", package = "dimoose"))
  logo <- logo[nzchar(logo)]
  if (length(logo) > 0 && requireNamespace("rsvg", quietly = TRUE)) {
    ok <- tryCatch({
      rsvg::rsvg_png(logo[1], file, width = size, height = size)
      file.exists(file) && file.size(file) > 0
    }, error = function(e) FALSE)
    if (ok) return(invisible(file))
  }
  wizDrawnIcon(file, size)
}

# A forking branch (one couplet, two leads) in the page's colours, written as
# a PNG with base R only.
wizDrawnIcon <- function(file, size) {
  u <- (seq_len(size) - 0.5) / size
  x <- base::matrix(u, size, size, byrow = TRUE)
  y <- base::matrix(u, size, size)
  w <- 0.035
  dot <- function(cx, cy, r = 0.085) (x - cx)^2 + (y - cy)^2 < r^2
  glyph <- (abs(x - 0.5) < w & y > 0.55 & y < 0.76) |
    (abs(y - 0.55) < w & x > 0.28 - w & x < 0.72 + w) |
    ((abs(x - 0.28) < w | abs(x - 0.72) < w) & y > 0.3 & y < 0.55) |
    dot(0.28, 0.27) | dot(0.72, 0.27) | dot(0.5, 0.76)
  rgb <- array(rep(c(0x1d, 0x6b, 0x58), each = size * size), c(size, size, 3))
  for (k in 1:3) rgb[, , k][glyph] <- c(0xf6, 0xf3, 0xeb)[k]
  wizWritePng(rgb, file)
}

# Minimal PNG writer: `rgb` is a rows x columns x 3 array of 0..255.
wizWritePng <- function(rgb, file) {
  h <- dim(rgb)[1]
  w <- dim(rgb)[2]
  # each scanline: filter byte 0, then R G B per pixel
  lines <- vapply(seq_len(h), function(i) c(0, as.vector(t(rgb[i, , ]))), numeric(1 + 3 * w))
  be32 <- function(n) as.raw(c(n %/% 16777216, (n %/% 65536) %% 256, (n %/% 256) %% 256, n %% 256))
  chunk <- function(type, data) {
    body <- c(charToRaw(type), data)
    c(be32(length(data)), body, wizCrc32(body))
  }
  png <- c(
    as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)),
    chunk("IHDR", c(be32(w), be32(h), as.raw(c(8, 2, 0, 0, 0)))),
    chunk("IDAT", memCompress(as.raw(as.vector(lines)), "gzip")),
    chunk("IEND", raw())
  )
  writeBin(png, file)
  invisible(file)
}

# CRC-32 of a raw vector as 4 bytes, kept in two 16-bit halves because R's
# bitwise functions work on signed 32-bit integers.
wizCrc32 <- function(bytes) {
  tab <- vapply(0:255, function(n) {
    hi <- 0L
    lo <- n
    for (k in 1:8) {
      odd <- bitwAnd(lo, 1L) == 1L
      lo <- bitwOr(bitwShiftR(lo, 1L), bitwShiftL(bitwAnd(hi, 1L), 15L))
      hi <- bitwShiftR(hi, 1L)
      if (odd) {
        hi <- bitwXor(hi, 0xEDB8L)
        lo <- bitwXor(lo, 0x8320L)
      }
    }
    c(hi, lo)
  }, integer(2))
  hi <- 0xFFFFL
  lo <- 0xFFFFL
  for (b in as.integer(bytes)) {
    i <- bitwAnd(bitwXor(lo, b), 255L) + 1L
    lo <- bitwXor(tab[2, i], bitwOr(bitwShiftR(lo, 8L), bitwShiftL(bitwAnd(hi, 255L), 8L)))
    hi <- bitwXor(tab[1, i], bitwShiftR(hi, 8L))
  }
  hi <- bitwXor(hi, 0xFFFFL)
  lo <- bitwXor(lo, 0xFFFFL)
  as.raw(c(hi %/% 256L, hi %% 256L, lo %/% 256L, lo %% 256L))
}

# ---- key checks --------------------------------------------------------------

normalizeLeads <- function(leads) {
  for (col in c("Statement", "Choice", "Character", "Next", "Taxon", "Label", "Image", "ImageLink", "TaxonUrl",
                "Question", "Feature", "Test")) {
    if (is.null(leads[[col]])) leads[[col]] <- rep("", nrow(leads))
    x <- as.character(leads[[col]])
    x[is.na(x)] <- ""
    leads[[col]] <- trimws(x)
  }
  if (is.null(leads$Threshold)) leads$Threshold <- rep(NA_real_, nrow(leads))
  leads$Threshold <- suppressWarnings(as.numeric(leads$Threshold))
  leads$Next[leads$Next == ""] <- "-"
  as.data.frame(leads, stringsAsFactors = FALSE)
}

# Display label of each lead: its Label if given, otherwise couplet + choice ("7b")
leadLabels <- function(leads) {
  ifelse(nzchar(leads$Label), leads$Label, paste0(leads$Statement, leads$Choice))
}

# Root couplet, reachability, parents and a list of problems found.
checkLeads <- function(leads) {
  couplets <- unique(leads$Statement)
  label <- leadLabels(leads)
  targets <- leads$Next[leads$Next != "-"]
  problems <- character()

  unreferenced <- setdiff(couplets, targets)
  root <- if (length(unreferenced) > 0) unreferenced[1] else couplets[1]
  if (length(unreferenced) == 0) {
    problems <- c(problems, "Every couplet is the target of some lead (the key has a cycle); starting at the first couplet")
  }

  missingTarget <- leads$Next != "-" & !leads$Next %in% couplets
  for (i in which(missingTarget)) {
    problems <- c(problems, sprintf("Lead %s leads to couplet %s, which is not in the key", label[i], leads$Next[i]))
  }
  noTaxon <- leads$Next == "-" & leads$Taxon == ""
  for (i in which(noTaxon)) {
    problems <- c(problems, sprintf("Lead %s ends the key but names no taxon", label[i]))
  }
  leadCount <- table(factor(leads$Statement, levels = couplets))
  for (cp in names(leadCount)[leadCount < 2]) {
    problems <- c(problems, sprintf("Couplet %s has only one lead", cp))
  }

  reachable <- root
  frontier <- root
  while (length(frontier) > 0) {
    nxt <- leads$Next[leads$Statement %in% frontier]
    nxt <- setdiff(nxt[nxt %in% couplets], reachable)
    reachable <- c(reachable, nxt)
    frontier <- nxt
  }
  unreachable <- setdiff(couplets, reachable)
  if (length(unreachable) > 0) {
    problems <- c(problems, sprintf(
      "Couplet(s) %s cannot be reached from couplet %s",
      paste(unreachable, collapse = ", "), root
    ))
  }

  list(root = root, couplets = couplets, missingTarget = missingTarget,
       unreachable = unreachable, problems = problems)
}

# Lead indices from the root to lead `i`, following the first parent lead of
# each couplet.
pathToLead <- function(leads, i, root, parentLead = match(leads$Statement, leads$Next)) {
  path <- i
  seen <- leads$Statement[i]
  while (leads$Statement[path[1]] != root) {
    parent <- parentLead[path[1]]
    if (is.na(parent) || leads$Statement[parent] %in% seen) break
    seen <- c(seen, leads$Statement[parent])
    path <- c(parent, path)
  }
  path
}

# ---- rendering ---------------------------------------------------------------

htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}

metaValue <- function(meta, key) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(NA_character_)
  v <- meta$value[meta$key == key]
  if (length(v) == 0) NA_character_ else as.character(v[1])
}

# Named vector: image id -> data URI, from meta rows image_<id>. Values that
# are bare base64 (importFishbase(embedImages = TRUE) wrote those) are GIFs.
embeddedImages <- function(meta) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(character())
  rows <- grepl("^image_", meta$key) & !grepl("^image_url_", meta$key)
  v <- as.character(meta$value[rows])
  v <- ifelse(startsWith(v, "data:"), v, paste0("data:image/gif;base64,", v))
  stats::setNames(v, sub("^image_", "", meta$key[rows]))
}

cssName <- function(id) paste0("--img-", gsub("[^A-Za-z0-9_-]", "_", id))

# <style> block declaring every embedded image once as a CSS custom property
imageStyle <- function(images) {
  if (length(images) == 0) return("")
  paste0("<style>:root{", paste0(cssName(names(images)), ":url(\"", images, "\")", collapse = ";"), "}</style>\n")
}

# Glossary of the key's sniglets: name, coined word, definition, example
# crops, where found. Anchors use the coined word, which never changes.
glossaryHtml <- function(features, leads, coupletId, images = character()) {
  if (is.null(features)) return("")
  terms <- which(features$kind == "centroid_patch_max")
  if (length(terms) == 0) return("")
  entries <- vapply(terms, function(j) {
    coined <- snigletWord(features$id[j])
    name <- features$label[j]
    ex <- features$exemplars[[j]]
    crops <- if (!is.null(ex) && !is.null(ex$png)) {
      # a crop the page already declares (patchExemplars() stores each one in
      # the key's images) is referenced, not embedded a second time
      uri <- paste0("data:image/png;base64,", ex$png)
      known <- paste0(gsub("[^A-Za-z0-9_-]", "_", coined), "_", seq_along(uri))
      shared <- !is.na(images[known]) & unname(images[known]) == uri
      paste0(sprintf("<span class=\"fig\" role=\"img\" aria-label=\"%s in %s\" style=\"background-image:%s\"></span>",
        htmlEscape(name), htmlEscape(ex$image),
        ifelse(shared, sprintf("var(%s)", cssName(known)), sprintf("url(&quot;%s&quot;)", uri))), collapse = "")
    } else ""
    seen <- if (is.null(ex)) NULL else if (!is.null(ex$label)) unique(ex$label) else unique(ex$image)
    where <- if (length(seen)) sprintf("<p class=\"found\">Seen in %s</p>", htmlEscape(paste(seen, collapse = ", "))) else ""
    asked <- unique(leads$Statement[leads$Feature == features$id[j]])
    links <- paste(sprintf("<a href=\"#%s\">%s</a>", coupletId(asked), htmlEscape(asked)), collapse = ", ")
    def <- if (!is.null(features$definition) && !is.na(features$definition[j])) sprintf("<p class=\"definition\">%s</p>", htmlEscape(features$definition[j])) else ""
    was <- if (!identical(name, coined)) sprintf("<p class=\"found\">Sniglet <code>%s</code></p>", htmlEscape(coined)) else ""
    sprintf("<div class=\"term\" id=\"g-%s\"><h3%s>%s</h3>%s<div class=\"figs\">%s</div>%s%s<p class=\"found\">Asked at %s</p></div>",
      htmlEscape(coined), if (identical(name, coined)) "" else " class=\"named\"", htmlEscape(name), def, crops, where, was, links)
  }, character(1))
  sprintf("<section class=\"glossary\" id=\"glossary\" aria-labelledby=\"h-glossary\">\n<h2 id=\"h-glossary\" tabindex=\"-1\">Glossary of sniglets</h2>\n<p>A sniglet is a visual feature the model found in the images. Each one is defined by the image patches that match it best: \"Has <i>sniglet</i>\" means the specimen has a region that looks like these.</p>\n%s\n</section>",
    paste(entries, collapse = "\n"))
}

splitUrls <- function(x) {
  if (is.na(x) || !nzchar(x)) character() else strsplit(x, ";", fixed = TRUE)[[1]]
}

figuresHtml <- function(thumbs, fulls, images, alt) {
  if (length(thumbs) == 0) return("")
  items <- vapply(thumbs, function(t) {
    name <- sub("\\.(gif|jpe?g|png|webp)$", "", basename(t), ignore.case = TRUE)
    full <- fulls[basename(fulls) == sub("^tn_", "", basename(t))][1]
    img <- if (!is.na(images[name])) {
      sprintf("<span class=\"fig\" role=\"img\" aria-label=\"%s\" style=\"background-image:var(%s)\"></span>",
        htmlEscape(alt), cssName(name))
    } else {
      sprintf("<img class=\"fig\" src=\"%s\" alt=\"%s\" loading=\"lazy\">", htmlEscape(t), htmlEscape(alt))
    }
    if (is.na(full)) img else {
      sprintf("<a href=\"%s\" target=\"_blank\" rel=\"noopener\" title=\"Open full-size figure\">%s</a>", htmlEscape(full), img)
    }
  }, character(1))
  paste0("<figure class=\"figs\">", paste(items, collapse = ""), "</figure>")
}

renderWizard <- function(leads, check, title, citation, taxa, images, displayLinks, map = TRUE,
                         nodeLabel = "Couplet", staticPaths = TRUE, features = NULL,
                         matrix = NULL, offline = NULL, photo = NULL, note = NA_character_) {
  hasKey <- nrow(leads) > 0   # FALSE for a page made from a character matrix alone
  map <- isTRUE(map) && hasKey
  label <- leadLabels(leads)
  # Section ids: sanitized names, made unique (e.g. M4'67 and M4"67)
  ids <- if (hasKey) paste0("c-", gsub("[^A-Za-z0-9_-]", "_", check$couplets)) else character()
  ids <- ifelse(duplicated(ids) | duplicated(ids, fromLast = TRUE), paste0(ids, "-", seq_along(ids)), ids)
  names(ids) <- check$couplets
  coupletId <- function(cp) unname(ids[cp])

  terminal <- which(leads$Next == "-" & leads$Taxon != "")
  taxonNames <- unique(leads$Taxon[terminal])
  taxonId <- stats::setNames(paste0("t-", seq_along(taxonNames))[seq_along(taxonNames)], taxonNames)

  # Notes on leads (pruneKey() writes the character of a collapsed couplet there)
  leadNote <- if (is.null(leads$Note)) rep("", nrow(leads)) else trimws(as.character(leads$Note))
  leadNote[is.na(leadNote)] <- ""
  noteHtml <- ifelse(nzchar(leadNote), sprintf("<span class=\"note\"><b>Also:</b> %s</span>", htmlEscape(leadNote)), "")

  # Couplet sections
  coupletHtml <- vapply(check$couplets, function(cp) {
    idx <- which(leads$Statement == cp)
    parents <- which(leads$Next == cp)
    from <- if (length(parents) > 0) {
      sprintf(" <span class=\"from\">from %s</span>", paste(sprintf(
        "<a href=\"#%s\">%s</a>", coupletId(leads$Statement[parents]),
        htmlEscape(ifelse(label[parents] == cp, leads$Statement[parents], label[parents]))
      ), collapse = ", "))
    } else {
      ""
    }
    leadItems <- vapply(idx, function(i) {
      text <- if (nzchar(leads$Character[i])) leads$Character[i] else "(no description)"
      if (leads$Next[i] == "-") {
        if (nzchar(leads$Taxon[i])) {
          href <- paste0("#", taxonId[[leads$Taxon[i]]])
          dest <- paste0("&rarr; ", htmlEscape(leads$Taxon[i]))
        } else {
          href <- NA
          dest <- "no taxon given"
        }
      } else if (check$missingTarget[i]) {
        href <- NA
        dest <- sprintf("&rarr; couplet %s (missing from key)", htmlEscape(leads$Next[i]))
      } else {
        href <- paste0("#", coupletId(leads$Next[i]))
        dest <- paste0("&rarr; ", htmlEscape(leads$Next[i]))
      }
      inner <- sprintf(
        "<span class=\"letter\" aria-hidden=\"true\">%s</span><span class=\"text\">%s</span>%s<span class=\"dest\">%s</span>",
        if (nzchar(leads$Choice[i])) htmlEscape(leads$Choice[i]) else "&bull;", htmlEscape(text), noteHtml[i], dest
      )
      choose <- if (is.na(href)) {
        sprintf("<span class=\"choose broken\" data-lead=\"%s\">%s</span>", htmlEscape(label[i]), inner)
      } else {
        sprintf("<a class=\"choose\" href=\"%s\" data-lead=\"%s\">%s</a>", href, htmlEscape(label[i]), inner)
      }
      figs <- figuresHtml(splitUrls(leads$Image[i]), splitUrls(leads$ImageLink[i]), images,
        paste("Figure for lead", label[i]))
      gloss <- ""
      if (!is.null(features) && nzchar(leads$Feature[i])) {
        fr <- match(leads$Feature[i], features$id)
        if (!is.na(fr) && features$kind[fr] == "centroid_patch_max") {
          gloss <- sprintf("<a class=\"gloss\" href=\"#g-%s\" title=\"What is this? See the glossary\" aria-label=\"Glossary entry for this sniglet\">?</a>",
            htmlEscape(snigletWord(features$id[fr])))
        }
      }
      sprintf("<li class=\"lead%s\">%s%s%s</li>", if (nzchar(gloss)) " examples" else "", choose, gloss, figs)
    }, character(1))
    id <- coupletId(cp)
    q <- if (!is.null(leads$Question)) leads$Question[idx[1]] else ""
    heading <- if (!is.null(q) && nzchar(q)) {
      sprintf("%s <span class=\"num\">%s %s</span>", htmlEscape(q), htmlEscape(nodeLabel), htmlEscape(cp))
    } else {
      sprintf("%s <span class=\"num\">%s</span>", htmlEscape(nodeLabel), htmlEscape(cp))
    }
    sprintf(
      "<section class=\"couplet\" id=\"%s\" aria-labelledby=\"h-%s\" data-name=\"%s\">\n<h2 id=\"h-%s\" tabindex=\"-1\">%s%s</h2>\n<ul class=\"leads\">\n%s\n</ul>\n</section>",
      id, id, htmlEscape(paste(nodeLabel, cp)), id, heading, from, paste(leadItems, collapse = "\n")
    )
  }, character(1))

  # Taxon result sections
  parentLead <- match(leads$Statement, leads$Next)
  terminalsOf <- split(terminal, factor(leads$Taxon[terminal], levels = taxonNames))
  taxaRow <- if (is.data.frame(taxa) && "submitted_name" %in% names(taxa)) match(taxonNames, taxa$submitted_name) else rep(NA, length(taxonNames))
  names(taxaRow) <- taxonNames
  taxonHtml <- vapply(taxonNames, function(tx) {
    i <- terminalsOf[[tx]][1]
    steps <- if (staticPaths) {
      path <- pathToLead(leads, i, check$root, parentLead)
      vapply(path, function(p) {
        sprintf("<li><a class=\"step\" href=\"#%s\">%s</a>%s%s</li>",
          coupletId(leads$Statement[p]), htmlEscape(label[p]), htmlEscape(leads$Character[p]), noteHtml[p])
      }, character(1))
    } else {
      "<li class=\"pending\">The path through the key appears here when the page script runs.</li>"
    }
    verified <- ""
    if (!is.na(taxaRow[[tx]]) && "matched_name" %in% names(taxa)) {
      row <- taxa[taxaRow[[tx]], , drop = FALSE]
      if (nrow(row) > 0 && !is.na(row$matched_name[1]) && row$matched_name[1] != tx) {
        src <- if (!is.null(row$data_source) && !is.na(row$data_source[1])) paste0(" (", row$data_source[1], ")") else ""
        verified <- sprintf("<p class=\"verified\">Accepted name: %s%s</p>", htmlEscape(row$matched_name[1]), htmlEscape(src))
      }
    }
    others <- terminalsOf[[tx]]
    alsoVia <- if (length(others) > 1) {
      sprintf("<p class=\"verified\">Also reached from lead %s.</p>", htmlEscape(paste(label[others[-1]], collapse = ", ")))
    } else {
      ""
    }
    url <- leads$TaxonUrl[i]
    link <- if (nzchar(url)) sprintf("<a href=\"%s\" target=\"_blank\" rel=\"noopener\">More on FishBase</a>", htmlEscape(url)) else ""
    id <- taxonId[[tx]]
    sprintf(
      "<section class=\"taxon\" id=\"%s\" aria-labelledby=\"h-%s\">\n<p class=\"eyebrow\">Identified as</p>\n<h2 id=\"h-%s\" tabindex=\"-1\">%s</h2>\n%s%s<h3>Path through the key</h3>\n<ol class=\"diagnosis\"%s>\n%s\n</ol>\n<p class=\"actions\"><a href=\"#%s\">Identify another specimen</a>%s</p>\n</section>",
      id, id, id, htmlEscape(tx), verified, alsoVia, if (staticPaths) "" else " data-auto=\"1\"",
      paste(steps, collapse = "\n"), coupletId(check$root), link
    )
  }, character(1))

  warningsHtml <- if (length(check$problems) > 0) {
    sprintf("<div class=\"warnings\" role=\"note\"><strong>Problems found in this key</strong><ul>%s</ul></div>",
      paste0("<li>", htmlEscape(check$problems), "</li>", collapse = ""))
  } else {
    ""
  }
  citationHtml <- if (!is.na(citation) && nzchar(citation)) sprintf("<p class=\"cite\">%s</p>", htmlEscape(citation)) else ""
  if (length(note) == 1 && !is.na(note) && nzchar(note)) {
    citationHtml <- paste0(citationHtml, sprintf("\n<p class=\"pruned\"><span class=\"note\"><b>All taxa of this key:</b> %s</span></p>", htmlEscape(note)))
  }

  mapHtml <- if (map) renderMap(leads, check, coupletId, taxonId, nodeLabel) else ""

  # Character matrix: its taxa are matched to the key's by name, so that they
  # share the result sections and the map
  matrixHtml <- ""
  if (!is.null(matrix)) {
    row <- match(matrix$taxa, taxonNames)
    loose <- match(tolower(matrix$taxa), tolower(trimws(taxonNames)))
    row[is.na(row)] <- loose[is.na(row)]
    if (hasKey && anyNA(row)) {
      message(sum(is.na(row)), " of ", length(row), " taxa of the matrix are not results of the key and get no link: ",
              paste(utils::head(matrix$taxa[is.na(row)], 10), collapse = ", "), if (sum(is.na(row)) > 10) ", ..." else "")
    }
    matrixIds <- ifelse(is.na(row), paste0("m-", seq_along(row)), unname(taxonId)[row])
    matrixHtml <- paste0(if (hasKey) "<h2 class=\"group\">Characters</h2>\n" else "",
                         wizMatrixHtml(matrix, matrixIds, !is.na(row)), "\n")
  }
  rootId <- if (hasKey) coupletId(check$root) else "matrix"
  head <- body <- foot <- ""
  if (!is.null(offline)) {
    head <- sprintf("<link rel=\"manifest\" href=\"%s\">\n<link rel=\"apple-touch-icon\" href=\"%s\">\n<link rel=\"icon\" type=\"image/png\" href=\"%s\">\n",
      offline$url[["manifest"]], offline$url[["icon192"]], offline$url[["icon192"]])
    body <- sprintf(" data-sw=\"%s\" data-sw-scope=\"%s\"", offline$url[["sw"]], offline$scope)
    foot <- "<span id=\"mk-offline\" hidden></span>"
  }
  if (!is.null(photo)) {
    body <- paste0(body, sprintf(" data-photo-model=\"%s\" data-photo-runtime=\"%s\"", htmlEscape(photo$url), htmlEscape(photo$runtime)),
                   if (!is.na(photo$runtimeBytes)) sprintf(" data-photo-runtime-bytes=\"%.0f\"", photo$runtimeBytes) else "")
  }

  css <- paste(readLines(system.file("wizard", "wizard.css", package = "dimoose"), warn = FALSE), collapse = "\n")
  js <- paste(readLines(system.file("wizard", "wizard.js", package = "dimoose"), warn = FALSE), collapse = "\n")

  paste0(
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n",
    "<meta name=\"theme-color\" content=\"#f6f3eb\" media=\"(prefers-color-scheme: light)\">\n",
    "<meta name=\"theme-color\" content=\"#131a1b\" media=\"(prefers-color-scheme: dark)\">\n",
    "<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n",
    "<meta name=\"mobile-web-app-capable\" content=\"yes\">\n",
    "<meta name=\"generator\" content=\"dimoose ", utils::packageVersion("dimoose"), "\">\n",
    "<title>", htmlEscape(title), "</title>\n", head, "<style>\n", css, "\n</style>\n", imageStyle(images), "</head>\n",
    "<body data-root=\"", rootId, "\"", body, if (!isTRUE(displayLinks)) " class=\"nolinks\"" else "", ">\n",
    "<header class=\"masthead\">\n<p class=\"eyebrow\">", if (hasKey) "Dichotomous key" else "Multi-access key", "</p>\n<h1>", htmlEscape(title), "</h1>\n", citationHtml, "\n",
    "<nav class=\"toolbar\" aria-label=\"Key navigation\">",
    "<button type=\"button\" id=\"mk-back\" disabled>&larr; Back</button>",
    "<a href=\"#", rootId, "\" id=\"mk-restart\">Start over</a>",
    "<span class=\"spacer\"></span>",
    if (hasKey && !is.null(matrix)) "<button type=\"button\" id=\"mk-pick\" aria-pressed=\"false\"><span class=\"long\">Pick characters</span><span class=\"short\">Pick</span></button>" else "",
    if (map) "<button type=\"button\" id=\"mk-maptoggle\" aria-controls=\"mk-map\" aria-expanded=\"false\">Map</button>" else "",
    if (hasKey) "<button type=\"button\" id=\"mk-mode\" aria-pressed=\"false\"><span class=\"long\">Show full key</span><span class=\"short\">Full key</span></button>" else "",
    "</nav>\n",
    "<ol class=\"trail\" id=\"mk-trail\" aria-label=\"Choices so far\" aria-live=\"polite\"></ol>\n</header>\n",
    "<div class=\"columns", if (map) " has-map" else "", "\">\n", mapHtml,
    "<main>\n", warningsHtml, "\n", paste(coupletHtml, collapse = "\n"), "\n",
    if (length(taxonHtml) > 0) "<h2 class=\"group\">Taxa</h2>\n" else "",
    paste(taxonHtml, collapse = "\n"), "\n", matrixHtml, glossaryHtml(features, leads, coupletId, images), "\n</main>\n</div>\n",
    "<footer><p>",
    if (hasKey) paste0(length(check$couplets), if (nodeLabel == "Couplet") " couplets, " else " steps, ",
      length(taxonNames), if (nodeLabel == "Couplet") " taxa. " else " possible results. ")
    else paste0(length(matrix$characters), " characters, ", length(matrix$taxa), " taxa. "),
    if (hasKey) "<span class=\"hint\">Press a, b (or 1, 2) to choose a lead, u if you are not sure. </span>" else "",
    foot, "Generated by the dimoose R package.</p></footer>\n",
    "<script>\n", js, "\n</script>\n</body>\n</html>\n"
  )
}

# ---- key map -----------------------------------------------------------------

# Inline SVG drawing of the key as a tree: couplets at their depth from the
# root (left to right), terminal leads as named leaves on the right. A couplet
# reached from more than one lead is drawn once; the extra links are dashed.
# Every node links to its section and carries data attributes the page script
# uses to mark the current position, the path so far and what is still ahead.
renderMap <- function(leads, check, coupletId, taxonId, nodeLabel = "Couplet") {
  label <- leadLabels(leads)
  # Long couplet names (e.g. haplogroups) do not fit inside a node: draw small
  # nodes and show names only along the user's path (see wizard.css).
  named <- max(nchar(check$couplets)) > 3
  rowH <- 20
  pad <- 14
  r <- if (named) 4.5 else 8.5

  nodes <- list()
  edges <- list()
  extra <- list()
  placed <- character()
  row <- 0

  visit <- function(cp, depth, anc) {
    placed <<- c(placed, cp)
    me <- coupletId(cp)
    ys <- numeric()
    for (i in which(leads$Statement == cp)) {
      nx <- leads$Next[i]
      if (nx == "-") {
        if (!nzchar(leads$Taxon[i])) next
        row <<- row + 1
        key <- paste0("L", i)
        nodes[[key]] <<- list(kind = "leaf", target = taxonId[[leads$Taxon[i]]], x = depth + 1, y = row,
                              label = leads$Taxon[i], anc = c(anc, me))
        edges[[length(edges) + 1]] <<- list(from = me, to = key, lead = label[i], text = leads$Character[i])
        ys <- c(ys, row)
      } else if (nx %in% check$couplets && !nx %in% placed) {
        ys <- c(ys, visit(nx, depth + 1, c(anc, me)))
        edges[[length(edges) + 1]] <<- list(from = me, to = coupletId(nx), lead = label[i], text = leads$Character[i])
      } else if (nx %in% placed) {
        extra[[length(extra) + 1]] <<- list(from = me, to = coupletId(nx), lead = label[i], text = leads$Character[i])
      }
    }
    if (length(ys) == 0) {
      row <<- row + 1
      ys <- row
    }
    y <- (min(ys) + max(ys)) / 2
    nodes[[me]] <<- list(kind = "couplet", target = me, x = depth, y = y, label = cp, anc = anc)
    y
  }
  visit(check$root, 0, character())

  leafNodes <- Filter(function(n) n$kind == "leaf", nodes)
  labelW <- if (length(leafNodes)) max(nchar(vapply(leafNodes, `[[`, "", "label"))) * 6.4 + 14 else 0
  depth <- max(1, vapply(nodes, `[[`, 0, "x"))
  # Narrow the columns (down to 20px) so typical keys fit a ~400px panel
  colW <- max(20, min(30, (400 - labelW - 2 * pad - r) / depth))
  px <- function(n) pad + r + n$x * colW
  py <- function(n) pad + (n$y - 1) * rowH
  width <- ceiling(pad + r + depth * colW + labelW + pad)
  height <- ceiling(2 * pad + (row - 1) * rowH)

  edgeSvg <- vapply(edges, function(e) {
    a <- nodes[[e$from]]
    b <- nodes[[e$to]]
    endX <- px(b) - if (b$kind == "couplet") r else 3.5
    sprintf(
      "<path class=\"medge\" data-from=\"%s\" data-to=\"%s\" d=\"M%.1f %.1fV%.1fH%.1f\"><title>%s %s</title></path>",
      e$from, b$target, px(a), py(a), py(b), endX,
      htmlEscape(e$lead), htmlEscape(e$text)
    )
  }, character(1))
  extraSvg <- vapply(extra, function(e) {
    a <- nodes[[e$from]]
    b <- nodes[[e$to]]
    sprintf(
      "<path class=\"medge cross\" data-from=\"%s\" data-to=\"%s\" d=\"M%.1f %.1fL%.1f %.1f\"><title>%s %s (also leads to couplet %s)</title></path>",
      e$from, e$to, px(a), py(a), px(b), py(b),
      htmlEscape(e$lead), htmlEscape(e$text), htmlEscape(b$label)
    )
  }, character(1))
  nodeSvg <- vapply(names(nodes), function(k) {
    n <- nodes[[k]]
    anc <- if (length(n$anc)) n$anc[length(n$anc)] else ""
    if (n$kind == "couplet") {
      sprintf(
        "<a class=\"mnode mcouplet\" href=\"#%s\" data-id=\"%s\" data-p=\"%s\" data-x=\"%.0f\" data-y=\"%.0f\" aria-label=\"%s %s\"><circle cx=\"%.1f\" cy=\"%.1f\" r=\"%.1f\"/><text x=\"%.1f\" y=\"%.1f\">%s</text></a>",
        n$target, n$target, anc, px(n), py(n), htmlEscape(nodeLabel), htmlEscape(n$label),
        px(n), py(n), r, if (named) px(n) + 6 else px(n), if (named) py(n) - 6 else py(n) + 3.2, htmlEscape(n$label)
      )
    } else {
      sprintf(
        "<a class=\"mnode mleaf\" href=\"#%s\" data-id=\"%s\" data-p=\"%s\" data-x=\"%.0f\" data-y=\"%.0f\" aria-label=\"%s\"><circle cx=\"%.1f\" cy=\"%.1f\" r=\"3.5\"/><text x=\"%.1f\" y=\"%.1f\">%s</text></a>",
        n$target, n$target, anc, px(n), py(n), htmlEscape(n$label),
        px(n), py(n), px(n) + 8, py(n) + 3.5, htmlEscape(n$label)
      )
    }
  }, character(1))

  nTaxa <- length(unique(vapply(leafNodes, `[[`, "", "target")))
  paste0(
    "<aside class=\"map\" id=\"mk-map\" aria-label=\"Map of the key\">\n",
    "<div class=\"map-head\"><span class=\"eyebrow\">Map of the key</span>",
    "<span class=\"map-count\" id=\"mk-left\" aria-live=\"polite\">", nTaxa, " taxa</span></div>\n",
    "<div class=\"map-scroll\" id=\"mk-map-scroll\">\n",
    sprintf("<svg class=\"keymap%s\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" xmlns=\"http://www.w3.org/2000/svg\">\n", if (named) " named" else "", width, height, width, height),
    "<g class=\"edges\">", paste(c(edgeSvg, extraSvg), collapse = ""), "</g>\n",
    "<g class=\"nodes\">", paste(nodeSvg, collapse = ""), "</g>\n</svg>\n</div>\n",
    "<p class=\"map-legend\"><span class=\"k here\"></span>You are here <span class=\"k done\"></span>Your path <span class=\"k ahead\"></span>Still possible</p>\n",
    "</aside>\n"
  )
}
