#' Import a dichotomous key from FishBase
#'
#' Downloads a key from FishBase and converts it into a [dimoose] object. See
#' <https://www.fishbase.se/keys/allkeys.php> for the list of keys and their
#' key codes.
#'
#' @param keycode Numeric or character FishBase key code.
#' @param fishbaseUrl Base URL of the FishBase mirror, with a trailing slash.
#' @param separateTerms If `TRUE`, split each lead's character statement on
#'   `";"` into one row per term.
#' @param usePhyloService Taxonomic name resolution: `"GNA"` verifies terminal
#'   taxa with the Global Names verifier (`taxize::gna_verifier()`, requires
#'   the 'taxize' package); `"none"` skips resolution. `"GNR"` is accepted as
#'   an alias for `"GNA"`. `"TNRS"` is no longer available because
#'   `taxize::tnrs()` is defunct.
#' @param embedImages If `TRUE`, download the key's morphology images and store
#'   them base64-encoded in `meta`. Image URLs are always stored.
#' @return A [dimoose] object.
#' @seealso [parseFishbase()] to build a key from saved HTML pages.
#' @examples
#' \dontrun{
#' sharks <- importFishbase(1)
#' sharks$taxa
#' }
#' @export
importFishbase <- function(keycode,
                           fishbaseUrl = "https://www.fishbase.se/",
                           separateTerms = TRUE,
                           usePhyloService = c("GNA", "GNR", "none", "TNRS"),
                           embedImages = FALSE) {
  usePhyloService <- match.arg(usePhyloService)
  pages <- fetchFishbasePages(keycode, fishbaseUrl)
  parseFishbase(
    pages$description, pages$questions,
    separateTerms = separateTerms,
    usePhyloService = usePhyloService,
    embedImages = embedImages,
    pageUrl = pages$questionsUrl
  )
}

#' Build a dimoose object from FishBase key pages
#'
#' The offline half of [importFishbase()]: parses a FishBase key description
#' page and its questions (couplet) page, both already downloaded.
#'
#' @param description The description page (`keys/description.php`): an
#'   `xml_document`, a file path, or a string of HTML.
#' @param questions The questions page (`keys/questions.php`), in any of the
#'   same forms.
#' @inheritParams importFishbase
#' @param pageUrl URL of the questions page, used to resolve relative image
#'   links.
#' @return A [dimoose] object.
#' @examples
#' \dontrun{
#' parseFishbase("description.html", "questions.html", usePhyloService = "none")
#' }
#' @export
parseFishbase <- function(description, questions,
                          separateTerms = TRUE,
                          usePhyloService = c("GNA", "GNR", "none", "TNRS"),
                          embedImages = FALSE,
                          pageUrl = "https://www.fishbase.se/keys/questions.php") {
  usePhyloService <- match.arg(usePhyloService)
  descDoc <- asHtmlDocument(description)
  keyDoc <- asHtmlDocument(questions)

  info <- parseFishbaseDescription(descDoc)
  keytable <- parseFishbaseKeyTable(keyDoc, pageUrl = pageUrl)
  df <- keyPaths(keytable, separateTerms = separateTerms)

  leaves <- keytable[keytable$Next == "-", , drop = FALSE]
  taxa <- resolveTaxa(leaves$Taxon, service = usePhyloService)

  imageUrls <- fishbaseImageUrls(keyDoc, pageUrl)
  imageNames <- sub("\\.gif$", "", basename(imageUrls), ignore.case = TRUE)
  meta <- data.frame(
    key = c("citation", "transcription", paste0("image_url_", imageNames)),
    value = c(info$citation, info$transcription, imageUrls),
    stringsAsFactors = FALSE
  )
  if (isTRUE(embedImages) && length(imageUrls) > 0) {
    encoded <- vapply(imageUrls, downloadAndEncodeImage, character(1))
    keep <- !is.na(encoded)
    meta <- rbind(meta, data.frame(
      key = paste0("image_", imageNames[keep]),
      value = unname(encoded[keep]),
      stringsAsFactors = FALSE
    ))
  }

  dimoose$new(df, info$desc, meta, taxa, leads = keytable)
}

# ---- internals --------------------------------------------------------------

dimooseUserAgent <- function() {
  httr::user_agent("dimoose R package (https://github.com/leipzig/dimoose)")
}

asHtmlDocument <- function(x) {
  if (inherits(x, "xml_document")) {
    return(x)
  }
  xml2::read_html(x)
}

fetchFishbasePages <- function(keycode, fishbaseUrl) {
  descUrl <- paste0(fishbaseUrl, "keys/description.php?keycode=", keycode)
  descResponse <- httr::GET(descUrl, dimooseUserAgent(), httr::timeout(60))
  httr::stop_for_status(descResponse, task = "download the FishBase key description")

  # FishBase serves the couplets only in response to a form POST
  questionsUrl <- paste0(fishbaseUrl, "keys/questions.php")
  keyResponse <- httr::POST(questionsUrl,
    body = list(keycode = keycode), encode = "form",
    dimooseUserAgent(), httr::timeout(60)
  )
  httr::stop_for_status(keyResponse, task = "download the FishBase key couplets")

  list(
    description = httr::content(descResponse),
    questions = httr::content(keyResponse),
    questionsUrl = questionsUrl
  )
}

# Title, citation and transcription note from the first table of the
# description page, as plain strings.
parseFishbaseDescription <- function(doc) {
  tables <- rvest::html_nodes(doc, "table")
  if (length(tables) == 0) {
    stop("No table found in the FishBase key description page", call. = FALSE)
  }
  cells <- trimws(as.character(rvest::html_table(tables[[1]], header = FALSE)[[1]]))
  list(desc = cells[1], citation = cells[2], transcription = cells[3])
}

# One row per lead: Statement (couplet number), Choice (a/b/...), Character,
# Next (couplet it leads to, or "-" for a terminal lead), Prev, Taxon, plus
# absolute URLs from the lead's Link cell: Image (thumbnails, ";"-separated),
# ImageLink (full-size figures) and TaxonUrl (FishBase species list or key).
parseFishbaseKeyTable <- function(doc, pageUrl = "https://www.fishbase.se/keys/questions.php") {
  tables <- rvest::html_nodes(doc, "table")
  if (length(tables) == 0) {
    stop("No table found in the FishBase key page", call. = FALSE)
  }
  raw <- rvest::html_table(tables[[1]], header = FALSE, convert = FALSE)
  header <- which(trimws(raw[[1]]) == "Couplet")[1]
  if (is.na(header)) {
    stop("Could not find the 'Couplet' header row in the FishBase key table", call. = FALSE)
  }
  keep <- seq_len(nrow(raw)) > header
  body <- raw[keep, , drop = FALSE]
  names(body) <- trimws(unlist(raw[header, ], use.names = FALSE))

  required <- c("Couplet", "Character", "Next", "Prev", "Link")
  missing <- setdiff(required, names(body))
  if (length(missing) > 0) {
    stop("FishBase key table is missing column(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  links <- linkCellUrls(tables[[1]], nrow(raw), match("Link", names(body)), pageUrl)

  couplet <- strsplit(trimws(body$Couplet), "\\s+")
  data.frame(
    Statement = vapply(couplet, function(x) x[1], character(1)),
    Choice = vapply(couplet, function(x) if (length(x) >= 2) x[2] else "", character(1)),
    Character = trimws(body$Character),
    Next = trimws(body$Next),
    Prev = gsub("[()]", "", trimws(body$Prev)),
    Taxon = cleanTaxon(body$Link),
    Image = links$Image[keep],
    ImageLink = links$ImageLink[keep],
    TaxonUrl = links$TaxonUrl[keep],
    stringsAsFactors = FALSE
  )
}

# URLs found in the Link cell of each table row. Rows whose <tr> count does
# not match the parsed table (unexpected markup) get empty strings.
linkCellUrls <- function(table, nrows, linkCol, pageUrl) {
  empty <- rep("", nrows)
  out <- list(Image = empty, ImageLink = empty, TaxonUrl = empty)
  rows <- rvest::html_nodes(table, "tr")
  if (length(rows) != nrows || is.na(linkCol)) {
    return(out)
  }
  absolute <- function(x) {
    x <- x[!is.na(x) & nzchar(x)]
    if (length(x) == 0) character() else unique(xml2::url_absolute(x, pageUrl))
  }
  for (i in seq_len(nrows)) {
    cells <- rvest::html_nodes(rows[[i]], "td")
    if (length(cells) < linkCol) next
    cell <- cells[[linkCol]]
    img <- absolute(rvest::html_attr(rvest::html_nodes(cell, "img"), "src"))
    href <- absolute(rvest::html_attr(rvest::html_nodes(cell, "a"), "href"))
    isFigure <- grepl("\\.(gif|jpe?g|png)$", href, ignore.case = TRUE)
    out$Image[i] <- paste(img, collapse = ";")
    out$ImageLink[i] <- paste(href[isFigure], collapse = ";")
    out$TaxonUrl[i] <- if (any(!isFigure)) href[!isFigure][1] else ""
  }
  out
}

# "Echinorhinidae, Key" -> "Echinorhinidae"
cleanTaxon <- function(x) {
  x <- trimws(ifelse(is.na(x), "", x))
  x <- sub(",?\\s*Key$", "", x)
  trimws(gsub(",", "", x))
}

# For every terminal lead, walk back to the root and emit the leads on the
# path. Columns: Statement, Choice, Character, Taxon, pSt, pCh, where pSt/pCh
# identify the lead that points at this lead's couplet ("" at the root).
# A couplet reached from more than one lead contributes one path per parent.
keyPaths <- function(keytable, separateTerms = TRUE) {
  n <- nrow(keytable)
  empty <- data.frame(
    Statement = character(), Choice = character(), Character = character(),
    Taxon = character(), pSt = character(), pCh = character(),
    stringsAsFactors = FALSE
  )
  if (n == 0) return(empty)
  stmt <- as.character(keytable$Statement)
  nxt <- as.character(keytable$Next)
  parentsOf <- split(seq_len(n), factor(nxt, levels = unique(stmt)))

  # Every path from the root to lead i, as vectors of lead indices. Walks up
  # with an explicit stack, so deep keys do not exhaust R's call stack.
  pathsTo <- function(i) {
    done <- list()
    stack <- list(i)
    while (length(stack)) {
      path <- stack[[length(stack)]]; stack[[length(stack)]] <- NULL
      parents <- parentsOf[[stmt[path[1]]]]
      if (length(parents) == 0) { done[[length(done) + 1]] <- path; next }
      for (p in rev(parents)) {
        if (stmt[p] %in% stmt[path]) {
          stop("Cycle in key: couplet ", stmt[p], " is reachable from itself", call. = FALSE)
        }
        stack[[length(stack) + 1]] <- c(p, path)
      }
    }
    done
  }

  leaves <- which(nxt == "-")
  paths <- list()
  taxa <- character()
  for (leaf in leaves) {
    found <- pathsTo(leaf)
    paths <- c(paths, found)
    taxa <- c(taxa, rep(keytable$Taxon[leaf], length(found)))
  }
  if (length(paths) == 0) return(empty)

  lead <- unlist(paths)
  prev <- unlist(lapply(paths, function(path) c(NA, path[-length(path)])))
  taxon <- rep(taxa, lengths(paths))
  terms <- as.list(as.character(keytable$Character))
  if (separateTerms) {
    terms <- lapply(strsplit(as.character(keytable$Character), ";", fixed = TRUE), trimws)
    terms[lengths(terms) == 0] <- ""
  }
  reps <- lengths(terms)[lead]
  out <- data.frame(
    Statement = rep(stmt[lead], reps),
    Choice = rep(as.character(keytable$Choice)[lead], reps),
    Character = unlist(terms[lead], use.names = FALSE),
    Taxon = rep(taxon, reps),
    pSt = rep(ifelse(is.na(prev), "", stmt[prev]), reps),
    pCh = rep(ifelse(is.na(prev), "", as.character(keytable$Choice)[prev]), reps),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

# One row per unique submitted name. matched_name falls back to the submitted
# name when resolution is skipped, unavailable, or finds no match.
resolveTaxa <- function(taxa, service = c("GNA", "GNR", "none", "TNRS")) {
  service <- match.arg(service)
  if (service == "TNRS") {
    stop("usePhyloService = \"TNRS\" is no longer available: taxize::tnrs() is defunct ",
      "because the Phylotastic TNRS service shut down. Use \"GNA\" or \"none\".",
      call. = FALSE
    )
  }
  taxa <- unique(taxa[!is.na(taxa) & nzchar(taxa)])
  out <- data.frame(
    submitted_name = taxa,
    matched_name = taxa,
    current_name = rep(NA_character_, length(taxa)),
    match_type = rep(NA_character_, length(taxa)),
    data_source = rep(NA_character_, length(taxa)),
    stringsAsFactors = FALSE
  )
  if (service == "none" || length(taxa) == 0) {
    return(out)
  }
  if (!requireNamespace("taxize", quietly = TRUE)) {
    warning("Package 'taxize' is not installed; skipping taxonomic name resolution.",
      call. = FALSE
    )
    return(out)
  }
  verified <- tryCatch(
    taxize::gna_verifier(taxa),
    error = function(e) {
      warning("Taxonomic name resolution failed: ", conditionMessage(e), call. = FALSE)
      NULL
    }
  )
  if (is.null(verified) || nrow(verified) == 0) {
    return(out)
  }
  idx <- match(out$submitted_name, verified$submittedName)
  canonical <- as.character(verified$matchedCanonicalSimple[idx])
  found <- !is.na(canonical) & nzchar(canonical)
  out$matched_name[found] <- canonical[found]
  out$current_name <- as.character(verified$currentCanonicalSimple[idx])
  out$match_type <- as.character(verified$matchType[idx])
  out$data_source <- as.character(verified$dataSourceTitleShort[idx])
  out
}

fishbaseImageUrls <- function(doc, pageUrl) {
  src <- rvest::html_attr(rvest::html_nodes(doc, "img"), "src")
  src <- unique(src[!is.na(src) & grepl("morphpic/.*\\.gif$", src, ignore.case = TRUE)])
  xml2::url_absolute(src, pageUrl)
}

# Base64-encoded image, or NA on failure.
downloadAndEncodeImage <- function(url) {
  tryCatch(
    {
      response <- httr::GET(url, dimooseUserAgent(), httr::timeout(30))
      if (httr::status_code(response) != 200) {
        warning("Failed to download image: ", url, call. = FALSE)
        return(NA_character_)
      }
      base64enc::base64encode(httr::content(response, as = "raw"))
    },
    error = function(e) {
      warning("Failed to download image: ", url, call. = FALSE)
      NA_character_
    }
  )
}
