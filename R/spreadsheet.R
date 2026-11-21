#' Build a key from a spreadsheet
#'
#' Reads a key written in a spreadsheet and saved as CSV (in Excel or
#' Google Sheets: *File > Save as / Download > CSV*). Each row is one lead:
#'
#' - `Couplet`: the couplet's number.
#' - `Description`: what the lead says ("Leaves compound.").
#' - `Goes to`: the couplet this lead leads to, or blank when the lead
#'   ends in a species.
#' - `Species`: the result, for leads that end the key. Write it as
#'   `"Common name (Genus species)"` to have [keyDiagram()] set the
#'   scientific name in italics.
#' - `Choice` (optional): the lead's letter; by default the leads of each
#'   couplet are lettered a, b, c in the order they appear (after z come
#'   aa, ab and so on).
#' - `Question` (optional): what the couplet asks ("Leaf type?"), shown by
#'   [keyDiagram()] and [exportWizard()].
#' - `Photo` (optional): file names of photos to show with the lead,
#'   separated by commas or semicolons; the extension may be left out. A
#'   web address (`https://...`) is kept as a link to the picture instead.
#' - `Note` and `Label` (optional): a remark on the lead, as [pruneKey()]
#'   writes, and a label to show for the lead in place of couplet and
#'   letter. Both are kept in the key's leads as they are.
#'
#' Column names are matched loosely (case, spaces and punctuation do not
#' matter) and dimoose's own names work too: `Statement`, `Character`,
#' `Next`, `Taxon` and `Image`. Other columns are ignored and blank rows are
#' skipped. The photos are embedded in the key, so the wizard and the
#' diagram work offline.
#'
#' The file may be as Excel saves it: with or without a byte-order mark, in
#' UTF-8 or Windows-1252, and with semicolons between the cells, which is
#' what Excel writes where the comma is the decimal mark.
#'
#' The Montana key that comes with dimoose is a ready-made example to copy:
#' `system.file("extdata", "montana", "montana-key.csv", package = "dimoose")`,
#' with its photos in the same folder.
#'
#' @param file Path of the CSV file (UTF-8).
#' @param photos Folder holding the photos named in the `Photo` column; by
#'   default the folder the CSV file is in.
#' @param desc Title of the key.
#' @param meta Optional key/value metadata data frame (e.g. a `citation`
#'   row); the photos are added to it.
#' @param checkNames If `TRUE`, check the species names against GBIF with
#'   [checkNames()] and warn, by spreadsheet row, about names that are
#'   misspelled, outdated synonyms or unknown. Needs an internet connection.
#' @return A [dimoose] key.
#' @seealso [keyToSpreadsheet()] to write a key as such a spreadsheet,
#'   [keyFromLeads()] to build a key from a data frame,
#'   [keyDiagram()] and [exportWizard()] to show it.
#' @examples
#' csv <- system.file("extdata", "montana", "montana-key.csv", package = "dimoose")
#' k <- keyFromSpreadsheet(csv, desc = "Native broadleaf trees of Montana")
#' k
#' keyDiagram(k, tempfile(fileext = ".svg"))
#' @export
keyFromSpreadsheet <- function(file, photos = NULL, desc = NA, meta = NULL, checkNames = FALSE) {
  if (!file.exists(file)) stop("Spreadsheet ", file, " not found", call. = FALSE)
  # Excel saves "CSV UTF-8" with a byte-order mark, and plain "CSV" on Windows
  # as Windows-1252; read either as UTF-8
  text <- rawToChar(readBin(file, "raw", file.size(file)))
  if (!validUTF8(text)) text <- iconv(text, "CP1252", "UTF-8")
  Encoding(text) <- "UTF-8"
  text <- sub("^\ufeff", "", text)
  # A comma inside an unquoted cell shifts every cell after it; catch that
  # before read.csv quietly pads or wraps the row
  countCells <- function(text, sep) {
    con <- textConnection(text)
    on.exit(close(con))
    utils::count.fields(con, sep = sep, quote = "\"", blank.lines.skip = FALSE, comment.char = "")
  }
  # Excel separates cells with semicolons where the comma is the decimal mark
  header <- sub("[\r\n].*$", "", sub("^[\r\n]+", "", text))
  sep <- if (nzchar(header) && countCells(header, ";")[1] > countCells(header, ",")[1]) ";" else ","
  cells <- countCells(text, sep)
  wide <- which(!is.na(cells) & cells > cells[1])
  if (length(wide)) {
    stop(sprintf("Row %d has more cells than the header row; put quotes around a cell that contains a %s",
                 wide[1], if (sep == ";") "semicolon" else "comma"), call. = FALSE)
  }
  sheet <- utils::read.csv(text = text, sep = sep, colClasses = "character", check.names = FALSE,
                           na.strings = character(), strip.white = TRUE, blank.lines.skip = FALSE, encoding = "UTF-8")
  # Match column names loosely: "Goes to", "goes_to" and "GOESTO" are the same
  aliases <- c(couplet = "Statement", statement = "Statement", choice = "Choice",
               description = "Character", character = "Character", goesto = "Next", "next" = "Next",
               species = "Taxon", taxon = "Taxon", question = "Question", photo = "Image", photos = "Image",
               image = "Image", images = "Image", note = "Note", notes = "Note", label = "Label")
  canon <- aliases[gsub("[^a-z]", "", tolower(names(sheet)))]
  keep <- !is.na(canon)
  sheet <- stats::setNames(sheet[keep], canon[keep])
  for (col in c("Statement", "Character")) {
    if (is.null(sheet[[col]])) {
      stop("The spreadsheet needs a ", c(Statement = "Couplet", Character = "Description")[[col]], " column", call. = FALSE)
    }
  }
  for (col in c("Choice", "Next", "Taxon", "Question", "Image")) {
    if (is.null(sheet[[col]])) sheet[[col]] <- rep("", nrow(sheet))
    sheet[[col]] <- trimws(sheet[[col]])
  }
  row <- seq_len(nrow(sheet)) + 1L
  blank <- !nzchar(trimws(do.call(paste0, sheet)))
  sheet <- sheet[!blank, , drop = FALSE]
  row <- row[!blank]
  sheet$Statement <- trimws(sheet$Statement)
  sheet$Next[sheet$Next == "-"] <- ""

  problems <- character()
  both <- nzchar(sheet$Next) & nzchar(sheet$Taxon)
  neither <- !nzchar(sheet$Next) & !nzchar(sheet$Taxon)
  missing <- nzchar(sheet$Next) & !sheet$Next %in% sheet$Statement
  problems <- c(problems,
    sprintf("Row %d has both `Goes to` (%s) and `Species` (%s); a lead does one or the other", row[both], sheet$Next[both], sheet$Taxon[both]),
    sprintf("Row %d has neither `Goes to` nor `Species`", row[neither]),
    sprintf("Row %d goes to couplet %s, which is not in the sheet", row[missing], sheet$Next[missing]))
  if (length(problems)) stop(paste(problems, collapse = "\n"), call. = FALSE)

  # Letter the leads that have no Choice (a to z, then aa, ab, ...), skipping
  # letters already used
  sheet$Choice <- stats::ave(sheet$Choice, sheet$Statement, FUN = function(x) {
    x[!nzchar(x)] <- setdiff(qualChoiceLetters(length(x)), x)[seq_len(sum(!nzchar(x)))]
    x
  })
  # Couplet M lead 11 and couplet M1 lead 1 are different leads that would
  # both be written "M11", so compare couplet and letter, not the two pasted
  again <- which(duplicated(sheet[c("Statement", "Choice")]))
  if (length(again)) {
    first <- which(sheet$Statement == sheet$Statement[again[1]] & sheet$Choice == sheet$Choice[again[1]])[1]
    stop(sprintf("Rows %d and %d are both lead %s; give them different Choice letters",
                 row[first], row[again[1]], paste0(sheet$Statement[again[1]], sheet$Choice[again[1]])), call. = FALSE)
  }
  sheet$Next[!nzchar(sheet$Next)] <- "-"

  if (is.null(meta)) meta <- data.frame(key = character(), value = character(), stringsAsFactors = FALSE)
  # Web addresses stay as they are; everything else names a photo file
  isUrl <- function(x) grepl("^https?://", x)
  photoNames <- function(cell) {
    parts <- trimws(strsplit(cell, ";", fixed = TRUE)[[1]])
    parts <- unlist(lapply(parts, function(x) if (isUrl(x)) x else trimws(strsplit(x, ",", fixed = TRUE)[[1]])))
    parts[nzchar(parts)]
  }
  named <- which(nzchar(sheet$Image))
  linked <- vapply(sheet$Image[named], function(cell) all(isUrl(photoNames(cell))), logical(1))
  for (i in named[linked]) sheet$Image[i] <- paste(photoNames(sheet$Image[i]), collapse = ";")
  named <- named[!linked]
  if (length(named)) {
    if (is.null(photos)) photos <- dirname(file)
    available <- list.files(photos)
    ids <- character()
    paths <- character()
    for (i in named) {
      wanted <- photoNames(sheet$Image[i])
      found <- vapply(wanted, function(w) {
        if (isUrl(w)) return(w)
        hit <- available[available == w | sub("\\.[^.]+$", "", available) == w]
        if (length(hit)) hit[1] else NA_character_
      }, character(1))
      if (anyNA(found)) {
        stop(sprintf("Row %d: photo %s not found in %s", row[i], wanted[is.na(found)][1], photos), call. = FALSE)
      }
      onDisk <- !isUrl(found)
      id <- ifelse(onDisk, sub("\\.[^.]+$", "", found), found)
      sheet$Image[i] <- paste(id, collapse = ";")
      paths <- c(paths, file.path(photos, found[onDisk]))
      ids <- c(ids, id[onDisk])
    }
    first <- !duplicated(ids)
    meta <- rbind(meta, imageMeta(paths[first], ids[first]))
  }

  leads <- sheet[c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image",
                   intersect(c("Note", "Label"), names(sheet)))]
  rownames(leads) <- NULL
  key <- keyFromLeads(leads, desc, meta)
  if (isTRUE(checkNames)) {
    checked <- dimoose::checkNames(key)
    bad <- checked[checked$status %in% c("misspelled", "synonym", "not found"), ]
    if (nrow(bad)) {
      at <- row[match(bad$Taxon, sheet$Taxon)]
      warning("Some species names do not match GBIF:\n",
              paste(paste0("Row ", at, ": ", bad$note)[order(at)], collapse = "\n"), call. = FALSE)
    }
  }
  key
}

#' Write a key as a spreadsheet
#'
#' Writes a key as the CSV file that [keyFromSpreadsheet()] reads, so that a
#' key imported from FishBase or generated from data can be opened in Excel
#' or Google Sheets, edited by hand and read back. The columns are those of
#' the Montana template: `Couplet`, `Choice`, `Question`, `Description`,
#' `Goes to`, `Species` and `Photo`, followed by `Note` and `Label` when
#' the key's leads have them (a pruned key has notes, see [pruneKey()]; a
#' PhyloTree key has labels).
#'
#' Photos embedded in the key (see [imageMeta()]) are written as image files
#' into `photos`, named by their ids, and the `Photo` column names those
#' files. A file of that name that is already there with different contents
#' is left alone and used as it is, so writing a key back next to its
#' original photos does not replace them with the smaller embedded copies.
#' Pictures a lead refers to by web address stay web addresses.
#'
#' Reading the file back gives the same leads and the same photo ids. The
#' exceptions are small: a photo id that cannot be a file name (it has a
#' `/`, `:`, comma or the like in it, or differs from another only by
#' capitals) is changed, with a message; a line break inside a cell comes
#' back as a plain line feed whatever it was; and leads without a `Choice`
#' are lettered.
#'
#' A spreadsheet holds only those columns. Anything else in the key's
#' leads (for example the taxon links of a FishBase key, or the tests of a
#' key a machine can follow) is not written, and a message says which
#' columns were left out; the title and citation are not written either, so
#' pass `desc` and `meta` again to [keyFromSpreadsheet()].
#'
#' @param key A [dimoose] key.
#' @param file Path of the CSV file to write (UTF-8).
#' @param photos Folder to write the key's embedded photos into; by default
#'   the folder the CSV file is in. It is created if needed.
#' @param bom Start the file with a byte-order mark? Excel needs one to
#'   show accented and other non-English letters correctly when the file is
#'   opened by double-clicking; Google Sheets and [keyFromSpreadsheet()]
#'   read the file either way. Use `FALSE` for programs that do not expect
#'   one.
#' @return `file`, invisibly, so the result can go straight to
#'   [keyFromSpreadsheet()].
#' @seealso [keyFromSpreadsheet()]
#' @examples
#' dir <- tempfile("key")
#' dir.create(dir)
#' csv <- keyToSpreadsheet(montanaKey(), file.path(dir, "montana.csv"))
#' list.files(dir)
#' # ... edit the file in a spreadsheet program, then read it back
#' again <- keyFromSpreadsheet(csv, desc = "Montana trees, edited")
#' identical(again$leads$Character, montanaKey()$leads$Character)
#' @export
keyToSpreadsheet <- function(key, file, photos = NULL, bom = TRUE) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  if (!is.character(file) || length(file) != 1 || is.na(file) || !nzchar(file)) {
    stop("`file` must be the path of the CSV file to write", call. = FALSE)
  }
  raw <- key$leads
  leads <- normalizeLeads(raw)
  if (nrow(leads) == 0) stop("This key has no leads to write", call. = FALSE)
  if (is.null(photos)) photos <- dirname(file)

  # Each embedded photo becomes a file; the Photo cell names it
  embedded <- embeddedImages(key$meta)
  written <- character()
  missing <- character()
  photoCell <- vapply(leads$Image, function(cell) {
    ids <- trimws(splitUrls(cell))
    ids <- ids[nzchar(ids)]
    names <- vapply(ids, function(id) {
      if (grepl("^https?://", id)) return(id)
      if (!id %in% names(embedded)) {
        missing <<- c(missing, id)
        return(NA_character_)
      }
      if (is.na(written[id])) written[id] <<- qualPhotoFile(id, embedded[[id]], photos, written)
      written[[id]]
    }, character(1))
    paste(names[!is.na(names)], collapse = "; ")
  }, character(1), USE.NAMES = FALSE)
  if (length(missing)) {
    warning("Photo(s) not embedded in the key, so left out of the spreadsheet: ",
            paste(unique(missing), collapse = ", "), call. = FALSE)
  }
  renamed <- names(written) != sub("\\.[^.]+$", "", written)
  if (any(renamed)) {
    message("Photo ids that cannot be file names were changed: ",
            paste(sprintf("%s is now %s", names(written)[renamed], sub("\\.[^.]+$", "", written[renamed])), collapse = ", "))
  }

  sheet <- data.frame(
    Couplet = leads$Statement, Choice = leads$Choice, Question = leads$Question, Description = leads$Character,
    `Goes to` = ifelse(leads$Next == "-", "", leads$Next), Species = leads$Taxon, Photo = photoCell,
    check.names = FALSE, stringsAsFactors = FALSE
  )
  # Remarks (pruneKey() writes them) and lead labels, when the key has any
  kept <- c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image", "Prev")
  for (col in c("Note", "Label")) {
    x <- if (is.null(raw[[col]])) "" else as.character(raw[[col]])
    x[is.na(x)] <- ""
    if (any(nzchar(trimws(x)))) {
      sheet[[col]] <- trimws(x)
      kept <- c(kept, col)
    }
  }
  # Every cell in quotes, so commas, quotes and line breaks inside one are
  # safe; line breaks are written as "\n", which is how they are read back
  cell <- function(x) {
    x <- gsub("\r\n?", "\n", enc2utf8(x))
    paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  }
  lines <- c(paste(cell(names(sheet)), collapse = ","), do.call(paste, c(lapply(sheet, cell), sep = ",")))
  if (isTRUE(bom)) lines[1] <- paste0("\ufeff", lines[1])
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  con <- base::file(file, "wb")
  on.exit(close(con))
  writeLines(enc2utf8(lines), con, sep = "\n", useBytes = TRUE)

  extra <- setdiff(names(raw), kept)
  extra <- extra[vapply(extra, function(col) any(!is.na(raw[[col]]) & nzchar(as.character(raw[[col]]))), logical(1))]
  if (length(extra)) {
    message("Not written to the spreadsheet: the leads' ", paste(extra, collapse = ", "), " column",
            if (length(extra) == 1) "" else "s")
  }
  invisible(file)
}

# Write an embedded photo (a data URI) into `folder` and return its file
# name: the id with the image type's extension, so that reading the sheet
# back gives the same id. Characters that cannot be in a file name, or that
# separate the names in a Photo cell, become "_". A name that is taken by
# another photo of the key (in any capitals: Windows and macOS do not tell
# "Leaf.jpg" from "leaf.jpg") gets a number. A different file of that name
# already in the folder is kept.
qualPhotoFile <- function(id, uri, folder, taken = character()) {
  mime <- sub("^data:([^;,]*).*$", "\\1", uri)
  ext <- switch(mime, "image/jpeg" = "jpg", "image/svg+xml" = "svg", gsub("[^A-Za-z0-9]", "", sub("^image/", "", mime)))
  if (!nzchar(ext)) ext <- "img"
  stem <- gsub("[/\\\\:*?\"<>|,;[:cntrl:]]+", "_", id)
  stem <- sub("^[. ]+", "", sub("[. ]+$", "", stem))
  if (!nzchar(stem)) stem <- "photo"
  name <- paste0(stem, ".", ext)
  n <- 1
  while (tolower(name) %in% tolower(taken)) {
    n <- n + 1
    name <- paste0(stem, "_", n, ".", ext)
  }
  bytes <- base64enc::base64decode(sub("^data:[^,]*,", "", uri))
  dir.create(folder, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(folder, name)
  if (file.exists(path)) {
    same <- file.size(path) == length(bytes) && identical(readBin(path, "raw", length(bytes)), bytes)
    if (!same) message("Kept the ", name, " already in ", folder, " rather than replace it with the key's copy")
    return(name)
  }
  writeBin(bytes, path)
  name
}

# Letters for the leads of a couplet with `n` leads: a to z, then aa, ab, ...
qualChoiceLetters <- function(n) {
  out <- letters
  last <- letters
  while (length(out) < n) {
    last <- paste0(rep(last, each = 26), letters)
    out <- c(out, last)
  }
  out
}
