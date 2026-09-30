#' Import a dichotomous key from FishBase
#'
#' Downloads a key from FishBase and converts it into a [moose] object. See
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
#' @return A [moose] object.
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

#' Build a moose object from FishBase key pages
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
#' @return A [moose] object.
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

  moose$new(df, info$desc, meta, taxa, leads = keytable)
}

# ---- internals --------------------------------------------------------------

mooseUserAgent <- function() {
  httr::user_agent("moose R package (https://github.com/leipzig/moose)")
}

asHtmlDocument <- function(x) {
  if (inherits(x, "xml_document")) {
    return(x)
  }
  xml2::read_html(x)
}

fetchFishbasePages <- function(keycode, fishbaseUrl) {
  descUrl <- paste0(fishbaseUrl, "keys/description.php?keycode=", keycode)
  descResponse <- httr::GET(descUrl, mooseUserAgent(), httr::timeout(60))
  httr::stop_for_status(descResponse, task = "download the FishBase key description")

  # FishBase serves the couplets only in response to a form POST
  questionsUrl <- paste0(fishbaseUrl, "keys/questions.php")
  keyResponse <- httr::POST(questionsUrl,
    body = list(keycode = keycode), encode = "form",
    mooseUserAgent(), httr::timeout(60)
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
  leadRows <- function(stmt, choice) {
    rows <- keytable[keytable$Statement == stmt & keytable$Choice == choice,
      c("Statement", "Choice", "Character"),
      drop = FALSE
    ]
    if (separateTerms && nrow(rows) > 0) {
      parts <- strsplit(rows$Character, ";", fixed = TRUE)
      parts[lengths(parts) == 0] <- ""
      rows <- data.frame(
        Statement = rep(rows$Statement, lengths(parts)),
        Choice = rep(rows$Choice, lengths(parts)),
        Character = trimws(unlist(parts)),
        stringsAsFactors = FALSE
      )
    }
    rownames(rows) <- NULL
    rows
  }

  walk <- function(taxon, stmt, choice, visited) {
    if (stmt %in% visited) {
      stop("Cycle in key: couplet ", stmt, " is reachable from itself", call. = FALSE)
    }
    trait <- leadRows(stmt, choice)
    trait$Taxon <- rep(taxon, nrow(trait))
    parents <- keytable[keytable$Next == stmt, c("Statement", "Choice"), drop = FALSE]
    if (nrow(parents) == 0) {
      trait$pSt <- rep("", nrow(trait))
      trait$pCh <- rep("", nrow(trait))
      return(trait)
    }
    paths <- lapply(seq_len(nrow(parents)), function(i) {
      here <- trait
      here$pSt <- rep(parents$Statement[i], nrow(here))
      here$pCh <- rep(parents$Choice[i], nrow(here))
      rbind(walk(taxon, parents$Statement[i], parents$Choice[i], c(visited, stmt)), here)
    })
    do.call(rbind, paths)
  }

  leaves <- keytable[keytable$Next == "-", , drop = FALSE]
  out <- do.call(rbind, Map(walk, leaves$Taxon, leaves$Statement, leaves$Choice,
    MoreArgs = list(visited = character())
  ))
  if (is.null(out)) {
    out <- data.frame(
      Statement = character(), Choice = character(), Character = character(),
      Taxon = character(), pSt = character(), pCh = character(),
      stringsAsFactors = FALSE
    )
  }
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
      response <- httr::GET(url, mooseUserAgent(), httr::timeout(30))
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
