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
#'   couplet are lettered a, b, c in the order they appear.
#' - `Question` (optional): what the couplet asks ("Leaf type?"), shown by
#'   [keyDiagram()] and [exportWizard()].
#' - `Photo` (optional): file names of photos to show with the lead,
#'   separated by commas or semicolons; the extension may be left out.
#'
#' Column names are matched loosely (case, spaces and punctuation do not
#' matter) and dimoose's own names work too: `Statement`, `Character`,
#' `Next`, `Taxon` and `Image`. Blank rows are skipped. The photos are
#' embedded in the key, so the wizard and the diagram work offline.
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
#' @return A [dimoose] key.
#' @seealso [keyFromLeads()] to build a key from a data frame,
#'   [keyDiagram()] and [exportWizard()] to show it.
#' @examples
#' csv <- system.file("extdata", "montana", "montana-key.csv", package = "dimoose")
#' k <- keyFromSpreadsheet(csv, desc = "Native broadleaf trees of Montana")
#' k
#' keyDiagram(k, tempfile(fileext = ".svg"))
#' @export
keyFromSpreadsheet <- function(file, photos = NULL, desc = NA, meta = NULL) {
  if (!file.exists(file)) stop("Spreadsheet ", file, " not found", call. = FALSE)
  # Excel saves "CSV UTF-8" with a byte-order mark, and plain "CSV" on Windows
  # as Windows-1252; read either as UTF-8
  text <- rawToChar(readBin(file, "raw", file.size(file)))
  if (!validUTF8(text)) text <- iconv(text, "CP1252", "UTF-8")
  Encoding(text) <- "UTF-8"
  text <- sub("^\ufeff", "", text)
  # A comma inside an unquoted cell shifts every cell after it; catch that
  # before read.csv quietly pads or wraps the row
  cells <- utils::count.fields(textConnection(text), sep = ",", quote = "\"", blank.lines.skip = FALSE)
  wide <- which(!is.na(cells) & cells > cells[1])
  if (length(wide)) {
    stop(sprintf("Row %d has more cells than the header row; put quotes around a cell that contains a comma",
                 wide[1]), call. = FALSE)
  }
  sheet <- utils::read.csv(text = text, colClasses = "character", check.names = FALSE, na.strings = character(),
                           strip.white = TRUE, blank.lines.skip = FALSE, encoding = "UTF-8")
  # Match column names loosely: "Goes to", "goes_to" and "GOESTO" are the same
  aliases <- c(couplet = "Statement", statement = "Statement", choice = "Choice",
               description = "Character", character = "Character", goesto = "Next", "next" = "Next",
               species = "Taxon", taxon = "Taxon", question = "Question", photo = "Image", photos = "Image",
               image = "Image", images = "Image")
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

  # Letter the leads that have no Choice, skipping letters already used
  sheet$Choice <- stats::ave(sheet$Choice, sheet$Statement, FUN = function(x) {
    x[!nzchar(x)] <- setdiff(letters, x)[seq_len(sum(!nzchar(x)))]
    x
  })
  lead <- paste0(sheet$Statement, sheet$Choice)
  again <- which(duplicated(lead))
  if (length(again)) {
    first <- match(lead[again[1]], lead)
    stop(sprintf("Rows %d and %d are both lead %s; give them different Choice letters",
                 row[first], row[again[1]], lead[again[1]]), call. = FALSE)
  }
  sheet$Next[!nzchar(sheet$Next)] <- "-"

  if (is.null(meta)) meta <- data.frame(key = character(), value = character(), stringsAsFactors = FALSE)
  named <- which(nzchar(sheet$Image))
  if (length(named)) {
    if (is.null(photos)) photos <- dirname(file)
    available <- list.files(photos)
    ids <- character()
    paths <- character()
    for (i in named) {
      wanted <- trimws(strsplit(sheet$Image[i], "[,;]")[[1]])
      wanted <- wanted[nzchar(wanted)]
      found <- vapply(wanted, function(w) {
        hit <- available[available == w | sub("\\.[^.]+$", "", available) == w]
        if (length(hit)) hit[1] else NA_character_
      }, character(1))
      if (anyNA(found)) {
        stop(sprintf("Row %d: photo %s not found in %s", row[i], wanted[is.na(found)][1], photos), call. = FALSE)
      }
      id <- sub("\\.[^.]+$", "", found)
      sheet$Image[i] <- paste(id, collapse = ";")
      paths <- c(paths, file.path(photos, found))
      ids <- c(ids, id)
    }
    first <- !duplicated(ids)
    meta <- rbind(meta, imageMeta(paths[first], ids[first]))
  }

  leads <- sheet[c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image")]
  rownames(leads) <- NULL
  keyFromLeads(leads, desc, meta)
}
