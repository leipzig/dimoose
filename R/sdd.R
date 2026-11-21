# TDWG SDD (Structured Descriptive Data) and the Xper dialect of it, plus the
# helpers shared with R/delta.R and R/lucid.R (all prefixed `tdwg`).

# ---- shared helpers ------------------------------------------------------------

tdwgTypes <- c("categorical", "ordered", "integer", "real", "text")

# One or more spaces, tabs or line breaks become one space
tdwgSquish <- function(x) trimws(gsub("[[:space:]]+", " ", x))

tdwgXmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}

tdwgFormatNumber <- function(x) {
  format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE, digits = 15)
}

tdwgNumberPattern <- "-?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)"

# Parse one numeric value or range written the DELTA way: "5", "2-8",
# "2-5-8" (the middle value is the mean or median) and, with rare extremes in
# parentheses, "(1-)2-8(-12)". Returns c(omin, min, mid, max, omax) or NULL.
tdwgParseRange <- function(x) {
  n <- tdwgNumberPattern
  pattern <- sprintf("^(?:\\((%s)-\\))?(%s)(?:-(%s))?(?:-(%s))?(?:\\(-(%s)\\))?$", n, n, n, n, n)
  m <- regmatches(x, regexec(pattern, gsub(" ", "", x, fixed = TRUE), perl = TRUE))[[1]]
  if (!length(m)) return(NULL)
  v <- suppressWarnings(as.numeric(m[-1]))
  normal <- v[2:4][!is.na(v[2:4])]
  c(omin = v[1], min = normal[1], mid = if (length(normal) == 3) normal[2] else NA_real_,
    max = normal[length(normal)], omax = v[5])
}

tdwgFormatRange <- function(omin = NA, min = NA, mid = NA, max = NA, omax = NA) {
  if (is.na(min)) min <- max
  if (is.na(max)) max <- min
  if (is.na(min)) {
    if (is.na(mid)) return(NA_character_)
    min <- max <- mid
    mid <- NA
  }
  f <- tdwgFormatNumber
  out <- if (min == max && is.na(mid)) f(min) else paste(c(f(min), if (!is.na(mid)) f(mid), f(max)), collapse = "-")
  if (!is.na(omin) && omin != min) out <- paste0("(", f(omin), "-)", out)
  if (!is.na(omax) && omax != max) out <- paste0(out, "(-", f(omax), ")")
  out
}

# The smallest range that covers every alternative in a cell ("5/10-15");
# NULL if any of them is not a number or range.
tdwgCellRange <- function(cell, sep = "/") {
  parts <- lapply(trimws(strsplit(cell, sep, fixed = TRUE)[[1]]), tdwgParseRange)
  if (!length(parts) || any(vapply(parts, is.null, logical(1)))) return(NULL)
  if (length(parts) == 1) return(parts[[1]])
  p <- do.call(rbind, parts)
  c(omin = if (all(is.na(p[, "omin"]))) NA_real_ else min(p[, c("omin", "min")], na.rm = TRUE),
    min = min(p[, "min"]), mid = NA_real_, max = max(p[, "max"]),
    omax = if (all(is.na(p[, "omax"]))) NA_real_ else max(p[, c("omax", "max")], na.rm = TRUE))
}

# A state name cannot contain the separator that lists several states in a cell
tdwgCleanStates <- function(states, sep = "/") {
  bad <- grepl(sep, states, fixed = TRUE)
  if (any(bad)) {
    other <- if (sep == "|") "/" else "|"
    states[bad] <- gsub(sep, other, states[bad], fixed = TRUE)
    attr(states, "replaced") <- sum(bad)
  }
  states
}

tdwgWarnReplaced <- function(n, sep) {
  if (n > 0) {
    warning(sprintf(paste0("%d state name(s) contain \"%s\", which separates the states in a cell; ",
                           "it was replaced by \"%s\" (use `sep` to pick another separator)"),
                    n, sep, if (sep == "|") "/" else "|"), call. = FALSE)
  }
}

tdwgUnique <- function(x) {
  dup <- duplicated(x)
  if (!any(dup)) return(x)
  count <- stats::ave(seq_along(x), x, FUN = seq_along)
  x[dup] <- paste0(x[dup], " (", count[dup], ")")
  if (anyDuplicated(x)) make.unique(x, sep = " ") else x
}

tdwgMeta <- function(...) {
  values <- list(...)
  values <- values[!vapply(values, function(v) length(v) == 0 || is.na(v[1]) || !nzchar(v[1]), logical(1))]
  data.frame(key = names(values), value = vapply(values, function(v) as.character(v[1]), character(1)),
             stringsAsFactors = FALSE, row.names = NULL)
}

tdwgMetaGet <- function(meta, key) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(NULL)
  value <- as.character(meta$value[meta$key == key])
  if (length(value) && !is.na(value[1]) && nzchar(value[1])) value[1] else NULL
}

# What every reader returns
tdwgData <- function(matrix, characters, taxa, meta) {
  rownames(matrix) <- rownames(characters) <- rownames(taxa) <- NULL
  structure(list(matrix = matrix, characters = characters, taxa = taxa, meta = meta), class = "tdwgData")
}

# Assemble the matrix data frame from a list of columns (one character vector
# per character)
tdwgMatrix <- function(taxa, cells, names, taxon = "Taxon") {
  m <- data.frame(taxa, stringsAsFactors = FALSE)
  names(m) <- taxon
  for (j in seq_along(names)) m[[names[j]]] <- cells[[j]]
  m
}

#' @export
print.tdwgData <- function(x, ...) {
  types <- table(factor(x$characters$Type, levels = tdwgTypes))
  types <- types[types > 0]
  title <- tdwgMetaGet(x$meta, "title")
  format <- tdwgMetaGet(x$meta, "format")
  cat("Character data", if (!is.null(title)) paste0("\"", title, "\""),
      if (!is.null(format)) paste0("(", format, ")"), "\n")
  cat(sprintf("  %d taxa x %d characters", nrow(x$matrix), nrow(x$characters)),
      if (length(types)) paste0("(", paste(types, names(types), collapse = ", "), ")"), "\n")
  cat("  $matrix, $characters, $taxa, $meta\n")
  invisible(x)
}

# Turn what a writer is given (a matrix data frame, or the list a reader
# returns) into one tidy description: taxon names, one character vector of
# cells per character, and per character its type, states, unit and so on.
tdwgInput <- function(x, characters = NULL, taxon = "Taxon", sep = "/", inapplicable = NULL) {
  taxa <- meta <- NULL
  if (is.data.frame(x)) {
    m <- x
  } else if (is.list(x) && is.data.frame(x$matrix)) {
    m <- x$matrix
    if (is.null(characters)) characters <- x$characters
    taxa <- x$taxa
    meta <- x$meta
  } else {
    stop("`x` must be a character matrix (a data frame) or the list that readSDD(), readDELTA() ",
         "or readLucid() return", call. = FALSE)
  }
  if (!taxon %in% names(m)) stop("The matrix has no taxon column \"", taxon, "\"", call. = FALSE)
  m <- as.data.frame(m, stringsAsFactors = FALSE)
  if (!nrow(m)) stop("The matrix has no rows", call. = FALSE)
  if (anyDuplicated(names(m))) {
    stop("Column name(s) used more than once in the matrix: ",
         paste(unique(names(m)[duplicated(names(m))]), collapse = ", "), call. = FALSE)
  }
  taxonNames <- tdwgSquish(as.character(m[[taxon]]))
  if (anyNA(taxonNames) || any(!nzchar(taxonNames))) stop("Every row of the matrix needs a taxon name", call. = FALSE)
  if (anyDuplicated(taxonNames)) {
    stop("Taxon name(s) used for more than one row: ",
         paste(unique(taxonNames[duplicated(taxonNames)]), collapse = ", "), call. = FALSE)
  }
  cols <- setdiff(names(m), taxon)
  if (!length(cols)) stop("The matrix has no character columns", call. = FALSE)

  info <- function(column, default) {
    if (!is.data.frame(characters) || is.null(characters$Character) || is.null(characters[[column]])) {
      return(rep(default, length(cols)))
    }
    value <- characters[[column]][match(cols, characters$Character)]
    if (is.character(default)) {
      value <- as.character(value)
      value[is.na(value)] <- default
    }
    value
  }
  type <- tolower(info("Type", NA_character_))
  delta <- c(um = "categorical", om = "ordered", "in" = "integer", rn = "real", te = "text")
  type[type %in% names(delta)] <- delta[type[type %in% names(delta)]]
  type[type %in% c("numeric", "quantitative")] <- "real"
  unknown <- !is.na(type) & !type %in% tdwgTypes
  if (any(unknown)) {
    stop("Unknown character type(s): ", paste(unique(type[unknown]), collapse = ", "),
         "; use one of ", paste(tdwgTypes, collapse = ", "), call. = FALSE)
  }
  definedStates <- info("States", "")
  cells <- states <- vector("list", length(cols))
  inapp <- matrix(FALSE, nrow(m), length(cols))
  for (j in seq_along(cols)) {
    v <- m[[cols[j]]]
    if (is.na(type[j])) {
      type[j] <- if (!is.numeric(v)) "categorical" else if (all(v == round(v), na.rm = TRUE)) "integer" else "real"
    }
    if (is.numeric(v)) {
      v <- ifelse(is.na(v), NA_character_, vapply(v, tdwgFormatNumber, character(1)))
    } else {
      v <- trimws(as.character(v))
      v[!is.na(v) & v == ""] <- NA
    }
    if (!is.null(inapplicable) && !is.na(inapplicable)) {
      inapp[, j] <- !is.na(v) & v == inapplicable
      v[inapp[, j]] <- NA
    }
    cells[[j]] <- v
    states[[j]] <- character()
    if (type[j] %in% c("categorical", "ordered")) {
      defined <- trimws(strsplit(definedStates[j], sep, fixed = TRUE)[[1]])
      observed <- trimws(unlist(strsplit(v[!is.na(v)], sep, fixed = TRUE)))
      states[[j]] <- unique(c(defined, observed)[nzchar(c(defined, observed))])
    }
  }
  list(taxa = taxonNames, taxaInfo = taxa, meta = meta, characters = cols, type = type, states = states,
       unit = info("Unit", ""), inapplicableIf = info("InapplicableIf", ""),
       cost = suppressWarnings(as.numeric(info("Cost", NA_real_))), cells = cells, inapplicable = inapp)
}

# The states of one cell, as positions in the character's state list
tdwgCellStates <- function(cell, states, sep = "/") {
  if (is.na(cell)) return(integer())
  match(trimws(strsplit(cell, sep, fixed = TRUE)[[1]]), states)
}

# "Wings=absent/reduced; Habitat=marine" -> list(list(character = , states = ), ...)
# Character names may themselves contain "=" or ";", so the text is read by
# looking for the names the data has. Rules that name a character or state
# the data does not have are dropped with a warning.
tdwgParseRules <- function(text, input, sep = "/") {
  if (is.na(text) || !nzchar(trimws(text))) return(list())
  heads <- paste0(input$characters, "=")
  heads <- heads[order(-nchar(heads))]
  startsRule <- function(x) {
    hit <- heads[startsWith(x, heads)]
    if (length(hit)) hit[1] else NA_character_
  }
  rules <- list()
  rest <- trimws(text)
  while (nzchar(rest)) {
    head <- startsRule(rest)
    after <- if (is.na(head)) rest else substring(rest, nchar(head) + 1)
    # the rule ends where the next one starts: at a "; " followed by a character name
    breaks <- gregexpr("; ", after, fixed = TRUE)[[1]]
    end <- nchar(after) + 1
    for (at in breaks[breaks > 0]) {
      if (!is.na(startsRule(substring(after, at + 2)))) {
        end <- at
        break
      }
    }
    statesText <- substr(after, 1, end - 1)
    rest <- trimws(substring(after, end + 2))
    controlling <- if (is.na(head)) NA else match(substr(head, 1, nchar(head) - 1), input$characters)
    stateIndex <- if (is.na(controlling)) NA else {
      match(trimws(strsplit(statesText, sep, fixed = TRUE)[[1]]), input$states[[controlling]])
    }
    if (is.na(controlling) || anyNA(stateIndex) || !length(stateIndex)) {
      warning("Dependency rule \"", if (is.na(head)) "" else head, statesText,
              "\" names a character or state that is not in the data; left out", call. = FALSE)
      next
    }
    rules[[length(rules) + 1]] <- list(character = controlling, states = stateIndex)
  }
  rules
}

tdwgRuleText <- function(character, states, sep = "/") paste0(character, "=", paste(states, collapse = sep))

# ---- SDD: reading ----------------------------------------------------------------

tdwgReadXml <- function(file) {
  if (!file.exists(file)) stop("File ", file, " not found", call. = FALSE)
  doc <- xml2::read_xml(file)
  xml2::xml_ns_strip(doc)
  doc
}

tdwgSddDataset <- function(doc, dataset = NULL, want = "CodedDescriptions") {
  datasets <- xml2::xml_find_all(doc, "//Dataset")
  if (!length(datasets)) stop("This is not an SDD file: it has no <Dataset> element", call. = FALSE)
  if (!is.null(dataset)) {
    if (!is.numeric(dataset) || dataset < 1 || dataset > length(datasets)) {
      stop(sprintf("`dataset` must be a number from 1 to %d", length(datasets)), call. = FALSE)
    }
    return(datasets[[dataset]])
  }
  has <- vapply(datasets, function(d) length(xml2::xml_find_first(d, paste0("./", want))) > 0, logical(1))
  if (!any(has)) return(NULL)
  datasets[[which(has)[1]]]
}

# The first <Label> of an object's <Representation>
tdwgSddLabel <- function(nodes) {
  tdwgSquish(xml2::xml_text(xml2::xml_find_first(nodes, "./Representation/Label")))
}

tdwgSddMeta <- function(doc, ds, format = "SDD") {
  generator <- xml2::xml_find_first(doc, "//TechnicalMetadata/Generator")
  authors <- xml2::xml_attr(xml2::xml_find_all(ds, "./RevisionData/Creators/Agent"), "ref")
  agents <- xml2::xml_find_all(ds, "./Agents/Agent")
  authorNames <- tdwgSddLabel(agents)[match(authors, xml2::xml_attr(agents, "id"))]
  tdwgMeta(
    format = format,
    title = tdwgSddLabel(ds),
    description = tdwgSquish(xml2::xml_text(xml2::xml_find_first(ds, "./Representation/Detail"))),
    language = xml2::xml_attr(ds, "lang"),
    authors = paste(authorNames[!is.na(authorNames)], collapse = "; "),
    copyright = tdwgSquish(xml2::xml_text(xml2::xml_find_first(ds, "./IPRStatements/IPRStatement[@role='Copyright']/Label"))),
    generator = tdwgSquish(paste(stats::na.omit(c(xml2::xml_attr(generator, "name"), xml2::xml_attr(generator, "version"))),
                                 collapse = " ")),
    created = xml2::xml_attr(xml2::xml_find_first(doc, "//TechnicalMetadata"), "created")
  )
}

tdwgSiPrefix <- c(yotta = "Y", zetta = "Z", exa = "E", peta = "P", tera = "T", giga = "G", mega = "M", kilo = "k",
                  hecto = "h", deca = "da", deci = "d", centi = "c", milli = "m", micro = "\u00b5", nano = "n",
                  pico = "p")

#' Read and write SDD (TDWG Structured Descriptive Data)
#'
#' SDD is the XML standard of TDWG (Biodiversity Information Standards) for
#' descriptive data: characters and their states, the taxa, and how each
#' taxon is coded for each character. `readSDD()` turns an SDD file into a
#' character matrix, `writeSDD()` writes one. Both follow SDD 1.1 (the
#' `http://rs.tdwg.org/UBIF/2006/` schema), which is what Lucid, Xper2/Xper3
#' and DELTA tools export.
#'
#' @section The character matrix:
#' A plain data frame with one row per taxon, the taxon names in a column
#' (`Taxon` by default) and one column per character. Cells are text:
#'
#' - a state name, or several separated by `sep` when the taxon is variable
#'   (`"red/yellow"`);
#' - for numeric characters a value or range written the way DELTA and floras
#'   write it: `"5"`, `"2.3-7.9"`, `"2.3-5.1-7.9"` (the middle value is the
#'   mean or median) and, with rare extremes, `"(1-)2-8(-12)"`;
#' - for text characters the text;
#' - `NA` when the character is unknown, not coded or not applicable (give
#'   `inapplicable` to tell "not applicable" apart).
#'
#' @section What is read from SDD:
#' Categorical, quantitative and text characters, in the order of the
#' `<Characters>` list; the coded descriptions (`<SummaryData>`) of each
#' taxon; `<Status>` codes (`NotApplicable` becomes `inapplicable`, the
#' others `NA`); the dependency rules of the character tree (`InapplicableIf`,
#' `OnlyApplicableIf`); and observation-convenience ratings, which become a
#' `Cost` from 1 (easy) to 5. A taxon with several descriptions gets one row,
#' with the states of all of them. States scored with a "misinterpretation"
#' modifier (Lucid's way of catching a common mistake) are not taken as
#' states of the taxon, and states scored with the modifier the Lucid Builder
#' labels "unscoped" make the cell "not applicable" (the Builder defines that
#' modifier in every SDD file it writes; none of the real exports dimoose
#' was checked against uses it, so how it is attached to a score is assumed
#' to be the same as for the other modifiers). Other modifiers (rarely,
#' uncertain) are ignored and the state kept, so a character whose states
#' are all "uncertain" for a taxon lists all of them. Dependency rules are
#' read from the character itself and from the groups of the character tree
#' it sits in. Quantitative measures map to the range text as follows:
#' `Min`/`Max` are the ends of the range, unless `UMethLower`/`UMethUpper`
#' are given too, in which case those are the normal range and `Min`/`Max`
#' the extremes in parentheses; `Mean` (or `Median`, `Mode`) is the middle
#' value. Other statistics (`SD`, `N`) are dropped.
#'
#' Not read: sample data (`<SampleData>` of individual specimens), media,
#' natural-language descriptions, taxon hierarchies, and text in more than
#' one language (the first label of each object is used).
#'
#' @param file Path of the SDD file to read or write.
#' @param taxon Name of the taxon column of the matrix.
#' @param sep Separator between the states of a variable taxon in one cell.
#' @param inapplicable For readers, the cell value to give "not applicable"
#'   (default `NA`, the same as unknown). For writers, the cell value that
#'   means "not applicable" (default `NULL`: none).
#' @param dataset Which `<Dataset>` of the file to read, by position; by
#'   default the first one that has coded descriptions (or, for
#'   `readSDDKey()`, identification keys).
#' @return `readSDD()` returns a list of class `tdwgData` with
#'
#' - `matrix`: the character matrix;
#' - `characters`: one row per character with `Character` (the column
#'   name), `Type` (`"categorical"`, `"ordered"`, `"integer"`, `"real"` or
#'   `"text"`; SDD itself only tells categorical, real and text apart),
#'   `States` (all defined states, separated by `sep`), `Unit`,
#'   `InapplicableIf` (`"Other character=state/state"`: the character does
#'   not apply when the other character has one of these states; several
#'   rules are separated by `;`), `Cost` when the file has ratings, and `Id`;
#' - `taxa`: `Taxon`, `Detail` and `Id`;
#' - `meta`: key/value data frame (`title`, `description`, `language`,
#'   `authors`, `copyright`, `generator`, `created`, and `keys`, the number of
#'   identification keys in the file, see [readSDDKey()]).
#'
#' `writeSDD()` returns `file`, invisibly.
#' @seealso [readSDDKey()] for dichotomous keys stored in SDD, [readXper()],
#'   [readLucid()], [readDELTA()].
#' @references Hagedorn, G., Thiele, K., Morris, R. & Heidorn, P. B. (2005).
#'   Structured Descriptive Data (SDD) w3c-xml-schema, version 1.0.
#'   <https://www.tdwg.org/standards/sdd/>
#' @examples
#' f <- system.file("extdata", "tdwg", "violets.sdd.xml", package = "dimoose")
#' d <- readSDD(f)
#' d
#' d$matrix
#' d$characters[, c("Character", "Type", "States", "Unit")]
#'
#' # write a matrix of your own
#' m <- data.frame(
#'   Taxon = c("Apis mellifera", "Bombus terrestris", "Vespula vulgaris"),
#'   Hair = c("sparse", "dense", "sparse/absent"),
#'   "Body length" = c("12-15", "(11-)14-17(-22)", NA),
#'   check.names = FALSE
#' )
#' chars <- data.frame(Character = "Body length", Type = "real", Unit = "mm")
#' out <- writeSDD(m, tempfile(fileext = ".xml"), characters = chars, title = "Three wasps and bees")
#' readSDD(out)$matrix
#' @export
readSDD <- function(file, taxon = "Taxon", sep = "/", inapplicable = NA, dataset = NULL) {
  doc <- tdwgReadXml(file)
  ds <- tdwgSddDataset(doc, dataset, "CodedDescriptions")
  if (is.null(ds)) {
    ds <- tdwgSddDataset(doc, NULL, "Characters")
    if (is.null(ds)) {
      stop("This SDD file has no characters or coded descriptions",
           if (length(xml2::xml_find_first(doc, "//IdentificationKey"))) "; it does have a key, see readSDDKey()",
           call. = FALSE)
    }
  }
  inapplicable <- as.character(inapplicable)

  # characters and their states
  charNodes <- xml2::xml_find_all(ds, "./Characters/*[@id]")
  if (!length(charNodes)) stop("This SDD file defines no characters", call. = FALSE)
  charId <- xml2::xml_attr(charNodes, "id")
  kind <- xml2::xml_name(charNodes)
  type <- ifelse(kind == "CategoricalCharacter", "categorical", ifelse(kind == "QuantitativeCharacter", "real", "text"))
  charName <- tdwgSddLabel(charNodes)
  charName[is.na(charName) | charName == ""] <- charId[is.na(charName) | charName == ""]
  charName <- tdwgUnique(charName)
  states <- vector("list", length(charNodes))
  stateIds <- vector("list", length(charNodes))
  replaced <- 0
  unit <- rep("", length(charNodes))
  for (j in seq_along(charNodes)) {
    if (type[j] == "categorical") {
      nodes <- xml2::xml_find_all(charNodes[[j]], "./States/StateDefinition")
      labels <- tdwgCleanStates(tdwgSddLabel(nodes), sep)
      if (!is.null(attr(labels, "replaced"))) replaced <- replaced + attr(labels, "replaced")
      states[[j]] <- tdwgUnique(as.vector(labels))
      stateIds[[j]] <- xml2::xml_attr(nodes, "id")
    } else if (type[j] == "real") {
      label <- tdwgSquish(xml2::xml_text(xml2::xml_find_first(charNodes[[j]], "./MeasurementUnit/Label")))
      prefix <- tdwgSquish(xml2::xml_text(xml2::xml_find_first(charNodes[[j]], "./Default/MeasurementUnitPrefix")))
      if (!is.na(label)) {
        unit[j] <- paste0(if (!is.na(prefix) && prefix %in% names(tdwgSiPrefix)) tdwgSiPrefix[[prefix]] else "", label)
      }
    }
  }
  tdwgWarnReplaced(replaced, sep)
  stateChar <- rep(seq_along(charNodes), lengths(stateIds))
  allStateIds <- unlist(stateIds)
  allStates <- unlist(states)

  # taxa
  taxonNodes <- xml2::xml_find_all(ds, "./TaxonNames/TaxonName")
  taxonId <- xml2::xml_attr(taxonNodes, "id")
  taxonLabel <- tdwgSddLabel(taxonNodes)
  taxonDetail <- tdwgSquish(xml2::xml_text(xml2::xml_find_first(taxonNodes, "./Representation/Detail")))

  misapplied <- xml2::xml_attr(
    xml2::xml_find_all(doc, "//Modifier[ModifierClass='TreatAsMisinterpretation']"), "id")
  # Lucid's "not scoped" score has no modifier class of its own in SDD: the
  # Lucid Builder defines a modifier labelled "unscoped" for it
  other <- xml2::xml_find_all(doc, "//Modifier[ModifierClass='OtherModifierClass']")
  unscoped <- xml2::xml_attr(other, "id")[tolower(tdwgSddLabel(other)) %in% "unscoped"]

  # coded descriptions; Xper2 names the taxon in the description's own label
  descriptions <- xml2::xml_find_all(ds, "./CodedDescriptions/CodedDescription")
  scope <- xml2::xml_attr(xml2::xml_find_first(descriptions, "./Scope/TaxonName"), "ref")
  rowName <- taxonLabel[match(scope, taxonId)]
  ownLabel <- tdwgSddLabel(descriptions)
  rowName[is.na(rowName)] <- ownLabel[is.na(rowName)]
  rowName[is.na(rowName) | rowName == ""] <- xml2::xml_attr(descriptions, "id")[is.na(rowName) | rowName == ""]
  rows <- unique(c(rowName, if (!length(descriptions)) taxonLabel))
  # per cell: the state positions (categorical) or the text
  picked <- matrix(list(integer()), length(rows), length(charNodes))
  text <- matrix(NA_character_, length(rows), length(charNodes))
  notApplicable <- matrix(FALSE, length(rows), length(charNodes))
  for (d in seq_along(descriptions)) {
    i <- match(rowName[d], rows)
    for (node in xml2::xml_find_all(descriptions[[d]], "./SummaryData/*[@ref]")) {
      j <- match(xml2::xml_attr(node, "ref"), charId)
      if (is.na(j)) next
      status <- xml2::xml_attr(xml2::xml_find_first(node, "./Status"), "code")
      if (identical(status, "NotApplicable")) notApplicable[i, j] <- TRUE
      what <- xml2::xml_name(node)
      if (what == "Categorical") {
        stateNodes <- xml2::xml_find_all(node, "./State")
        refs <- xml2::xml_attr(stateNodes, "ref")
        if (length(c(misapplied, unscoped)) && length(stateNodes)) {
          modifiers <- lapply(stateNodes, function(s) xml2::xml_attr(xml2::xml_find_all(s, "./Modifier"), "ref"))
          outside <- vapply(modifiers, function(m) any(m %in% unscoped), logical(1))
          if (any(outside)) notApplicable[i, j] <- TRUE
          refs <- refs[!outside & !vapply(modifiers, function(m) any(m %in% misapplied), logical(1))]
        }
        found <- match(refs, stateIds[[j]])
        picked[[i, j]] <- sort(unique(c(picked[[i, j]], found[!is.na(found)])))
      } else if (what == "Quantitative") {
        measures <- xml2::xml_find_all(node, "./Measure")
        value <- suppressWarnings(as.numeric(xml2::xml_attr(measures, "value")))
        names(value) <- xml2::xml_attr(measures, "type")
        get <- function(...) {
          v <- value[names(value) %in% c(...)]
          if (length(v) && !is.na(v[1])) v[[1]] else NA_real_
        }
        lower <- get("UMethLower")
        upper <- get("UMethUpper")
        range <- tdwgFormatRange(
          omin = if (is.na(lower)) NA_real_ else get("Min"), min = if (is.na(lower)) get("Min") else lower,
          mid = get("Mean", "Median", "Mode"),
          max = if (is.na(upper)) get("Max") else upper, omax = if (is.na(upper)) NA_real_ else get("Max"))
        if (!is.na(range)) text[i, j] <- if (is.na(text[i, j])) range else paste(text[i, j], range, sep = sep)
      } else if (what == "TextChar") {
        content <- tdwgSquish(xml2::xml_text(xml2::xml_find_first(node, "./Content")))
        if (!is.na(content) && nzchar(content) && is.na(text[i, j])) text[i, j] <- content
      }
    }
  }
  cells <- lapply(seq_along(charNodes), function(j) {
    v <- text[, j]
    if (type[j] == "categorical") {
      v <- vapply(picked[, j], function(p) if (length(p)) paste(states[[j]][p], collapse = sep) else NA_character_,
                  character(1))
    }
    v[is.na(v) & notApplicable[, j]] <- inapplicable
    v
  })

  # dependency rules of the character tree. A rule on a node that groups
  # characters (Lucid writes them there) holds for every character below it.
  rules <- rep("", length(charNodes))
  treeNodes <- xml2::xml_find_all(ds, "./CharacterTrees/CharacterTree/Nodes/*")
  if (length(xml2::xml_find_first(ds, "./CharacterTrees/CharacterTree/Nodes/*/DependencyRules"))) {
    nodeId <- xml2::xml_attr(treeNodes, "id")
    nodeParent <- xml2::xml_attr(xml2::xml_find_first(treeNodes, "./Parent"), "ref")
    nodeChar <- match(xml2::xml_attr(xml2::xml_find_first(treeNodes, "./Character"), "ref"), charId)
    hasRule <- lengths(lapply(treeNodes, function(node) xml2::xml_find_first(node, "./DependencyRules"))) > 0
    ruleStates <- rep(list(integer()), length(charNodes))
    for (n in which(!is.na(nodeChar))) {
      j <- nodeChar[n]
      # the node itself, then the nodes above it
      chain <- n
      repeat {
        parent <- nodeParent[chain[length(chain)]]
        up <- if (is.na(parent)) NA else match(parent, nodeId)
        if (is.na(up) || up %in% chain) break
        chain <- c(chain, up)
      }
      # a character may sit in more than one tree: its rules add up
      at <- ruleStates[[j]]
      for (node in treeNodes[chain[hasRule[chain]]]) {
        refs <- xml2::xml_attr(xml2::xml_find_all(node, "./DependencyRules/InapplicableIf/State"), "ref")
        only <- xml2::xml_attr(xml2::xml_find_all(node, "./DependencyRules/OnlyApplicableIf/State"), "ref")
        for (controlling in unique(stateChar[match(only, allStateIds)])) {
          if (is.na(controlling)) next
          refs <- c(refs, setdiff(stateIds[[controlling]], only))
        }
        at <- c(at, match(refs, allStateIds))
      }
      # in the order of the characters and of their states
      at <- sort(unique(at[!is.na(at) & stateChar[at] != j]))
      ruleStates[[j]] <- at
      if (!length(at)) next
      byChar <- vapply(split(allStates[at], stateChar[at]), paste, character(1), collapse = sep)
      rules[j] <- paste(paste0(charName[as.integer(names(byChar))], "=", byChar), collapse = "; ")
    }
  }

  characters <- data.frame(
    Character = charName, Type = type,
    States = vapply(states, function(s) paste(s, collapse = sep), character(1)),
    Unit = unit, InapplicableIf = rules, stringsAsFactors = FALSE
  )
  # Xper rates how convenient each character is to observe, cell by cell
  rated <- xml2::xml_find_all(
    ds, "./CodedDescriptions/CodedDescription/SummaryData/*[Ratings/Rating[@context='ObservationConvenience']]")
  if (length(rated)) {
    rating <- xml2::xml_attr(
      xml2::xml_find_first(rated, "./Ratings/Rating[@context='ObservationConvenience']"), "rating")
    rating <- suppressWarnings(as.numeric(sub("^Rating([0-9])of5$", "\\1", rating)))
    mean <- tapply(rating, factor(xml2::xml_attr(rated, "ref"), levels = charId), mean, na.rm = TRUE)
    characters$Cost <- as.vector(6 - mean)
  }
  characters$Id <- charId

  at <- match(rows, taxonLabel)
  taxa <- data.frame(Taxon = rows, Detail = taxonDetail[at], Id = taxonId[at], stringsAsFactors = FALSE)
  names(taxa)[1] <- taxon
  meta <- tdwgSddMeta(doc, ds)
  keys <- length(xml2::xml_find_all(doc, "//IdentificationKeys/IdentificationKey"))
  if (keys > 0) meta <- rbind(meta, tdwgMeta(keys = keys))
  tdwgData(tdwgMatrix(rows, cells, charName, taxon), characters, taxa, meta)
}

# ---- SDD: writing ----------------------------------------------------------------

tdwgSddRepresentation <- function(label, detail = NULL, indent = "") {
  c(paste0(indent, "<Representation>"),
    paste0(indent, "  <Label>", tdwgXmlEscape(label), "</Label>"),
    if (!is.null(detail) && !is.na(detail) && nzchar(detail)) {
      paste0(indent, "  <Detail>", tdwgXmlEscape(detail), "</Detail>")
    },
    paste0(indent, "</Representation>"))
}

# The whole document around the body of one dataset
tdwgSddDocument <- function(title, body, lang = "en", detail = NULL, generator = "dimoose") {
  version <- tryCatch(as.character(utils::packageVersion("dimoose")), error = function(e) "0")
  c("<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    paste0("<Datasets xmlns=\"http://rs.tdwg.org/UBIF/2006/\" ",
           "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" ",
           "xsi:schemaLocation=\"http://rs.tdwg.org/UBIF/2006/ http://rs.tdwg.org/UBIF/2006/Schema/1.1/SDD.xsd\">"),
    paste0("  <TechnicalMetadata created=\"", format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "\">"),
    paste0("    <Generator name=\"", tdwgXmlEscape(generator), "\" version=\"", version, "\"/>"),
    "  </TechnicalMetadata>",
    paste0("  <Dataset xml:lang=\"", tdwgXmlEscape(lang), "\">"),
    tdwgSddRepresentation(title, detail, "    "),
    body,
    "  </Dataset>",
    "</Datasets>")
}

tdwgSddTaxa <- function(names, detail = NULL) {
  if (!length(names)) return(character())
  c("    <TaxonNames>",
    unlist(lapply(seq_along(names), function(i) {
      c(paste0("      <TaxonName id=\"t", i, "\">"),
        tdwgSddRepresentation(names[i], if (!is.null(detail)) detail[i], "        "),
        "      </TaxonName>")
    })),
    "    </TaxonNames>")
}

# <Characters>, <CharacterTrees> and <CodedDescriptions> for a tdwgInput()
tdwgSddMatrix <- function(input, sep = "/") {
  nChar <- length(input$characters)
  # SDD does not allow a categorical character without states
  stateless <- input$type %in% c("categorical", "ordered") & lengths(input$states) == 0
  if (any(stateless)) {
    warning("Character(s) without any state written as text characters: ",
            paste(input$characters[stateless], collapse = ", "), call. = FALSE)
    input$type[stateless] <- "text"
  }
  charId <- paste0("c", seq_len(nChar))
  offset <- c(0, cumsum(lengths(input$states)))
  stateId <- lapply(seq_len(nChar), function(j) paste0("s", offset[j] + seq_along(input$states[[j]])))

  out <- "    <Characters>"
  for (j in seq_len(nChar)) {
    label <- tdwgSddRepresentation(input$characters[j], indent = "        ")
    if (input$type[j] %in% c("categorical", "ordered")) {
      out <- c(out, paste0("      <CategoricalCharacter id=\"", charId[j], "\">"), label, "        <States>",
               unlist(lapply(seq_along(input$states[[j]]), function(s) {
                 c(paste0("          <StateDefinition id=\"", stateId[[j]][s], "\">"),
                   tdwgSddRepresentation(input$states[[j]][s], indent = "            "),
                   "          </StateDefinition>")
               })),
               "        </States>", "      </CategoricalCharacter>")
    } else if (input$type[j] == "text") {
      out <- c(out, paste0("      <TextCharacter id=\"", charId[j], "\">"), label, "      </TextCharacter>")
    } else {
      out <- c(out, paste0("      <QuantitativeCharacter id=\"", charId[j], "\">"), label,
               if (nzchar(input$unit[j])) {
                 c("        <MeasurementUnit>",
                   paste0("          <Label role=\"Abbrev\">", tdwgXmlEscape(input$unit[j]), "</Label>"),
                   "        </MeasurementUnit>")
               },
               "      </QuantitativeCharacter>")
    }
  }
  out <- c(out, "    </Characters>", "    <CharacterTrees>", "      <CharacterTree id=\"ct1\">",
           tdwgSddRepresentation("Order of and dependencies between characters", indent = "        "),
           "        <ShouldContainAllCharacters>true</ShouldContainAllCharacters>", "        <Nodes>")
  for (j in seq_len(nChar)) {
    rules <- tdwgParseRules(input$inapplicableIf[j], input, sep)
    refs <- unlist(lapply(rules, function(r) stateId[[r$character]][r$states]))
    out <- c(out, "          <CharNode>",
             if (length(refs)) {
               c("            <DependencyRules>", "              <InapplicableIf>",
                 paste0("                <State ref=\"", refs, "\"/>"),
                 "              </InapplicableIf>", "            </DependencyRules>")
             },
             paste0("            <Character ref=\"", charId[j], "\"/>"), "          </CharNode>")
  }
  out <- c(out, "        </Nodes>", "      </CharacterTree>", "    </CharacterTrees>", "    <CodedDescriptions>")

  rateable <- !is.na(input$cost) & input$cost >= 1 & input$cost <= 5
  rating <- ifelse(rateable, sprintf(paste0("            <Ratings><Rating context=\"ObservationConvenience\" ",
                                            "rating=\"Rating%dof5\"/></Ratings>"), 6 - round(input$cost)), NA)
  skipped <- character()
  for (i in seq_along(input$taxa)) {
    out <- c(out, paste0("      <CodedDescription id=\"D", i, "\">"),
             tdwgSddRepresentation(input$taxa[i], indent = "        "),
             "        <Scope>", paste0("          <TaxonName ref=\"t", i, "\"/>"), "        </Scope>")
    opened <- length(out)
    for (j in seq_len(nChar)) {
      cell <- input$cells[[j]][i]
      element <- if (input$type[j] %in% c("categorical", "ordered")) "Categorical" else
        if (input$type[j] == "text") "TextChar" else "Quantitative"
      inner <- NULL
      if (input$inapplicable[i, j]) {
        inner <- "            <Status code=\"NotApplicable\"/>"
      } else if (is.na(cell)) {
        next
      } else if (element == "Categorical") {
        at <- tdwgCellStates(cell, input$states[[j]], sep)
        inner <- paste0("            <State ref=\"", stateId[[j]][at], "\"/>")
      } else if (element == "TextChar") {
        inner <- paste0("            <Content>", tdwgXmlEscape(cell), "</Content>")
      } else {
        r <- tdwgCellRange(cell, sep)
        if (is.null(r)) {
          skipped <- c(skipped, sprintf("%s, %s: \"%s\"", input$taxa[i], input$characters[j], cell))
          next
        }
        measure <- function(type, value) {
          if (is.na(value)) return(NULL)
          paste0("            <Measure type=\"", type, "\" value=\"", tdwgFormatNumber(value), "\"/>")
        }
        extremes <- !is.na(r[["omin"]]) || !is.na(r[["omax"]])
        inner <- c(measure("Min", if (is.na(r[["omin"]])) r[["min"]] else r[["omin"]]),
                   if (extremes) measure("UMethLower", r[["min"]]),
                   measure("Mean", r[["mid"]]),
                   if (extremes) measure("UMethUpper", r[["max"]]),
                   measure("Max", if (is.na(r[["omax"]])) r[["max"]] else r[["omax"]]))
      }
      out <- c(out, paste0("          <", element, " ref=\"", charId[j], "\">"),
               if (!is.na(rating[j]) && element != "TextChar") rating[j], inner,
               paste0("          </", element, ">"))
    }
    # <SummaryData> must not be empty: a taxon with nothing coded has none
    if (length(out) > opened) {
      out <- c(out[seq_len(opened)], "        <SummaryData>", out[-seq_len(opened)], "        </SummaryData>")
    }
    out <- c(out, "      </CodedDescription>")
  }
  if (length(skipped)) {
    warning("Not a number or range, so left out of the SDD file: ",
            paste(utils::head(skipped, 5), collapse = "; "),
            if (length(skipped) > 5) sprintf(" and %d more", length(skipped) - 5), call. = FALSE)
  }
  c(out, "    </CodedDescriptions>")
}

# <IdentificationKeys> for a table of leads; `taxonId` maps taxon names to ids
tdwgSddKey <- function(leads, title, taxonId) {
  leads <- normalizeLeads(leads)
  root <- checkLeads(leads)$root
  first <- match(unique(leads$Statement), leads$Statement)
  question <- stats::setNames(leads$Question[first], leads$Statement[first])
  out <- c("    <IdentificationKeys>", "      <IdentificationKey id=\"k1\">",
           tdwgSddRepresentation(title, indent = "        "),
           if (nzchar(question[[root]])) {
             paste0("        <Question><Text>", tdwgXmlEscape(question[[root]]), "</Text></Question>")
           },
           "        <Leads>")
  counter <- 0
  body <- character()
  # A couplet reached from two leads is written once under each of them: an SDD
  # lead has only one parent.
  emit <- function(couplet, parent, path) {
    rows <- which(leads$Statement == couplet)
    ids <- counter + seq_along(rows)
    counter <<- counter + length(rows)
    goesOn <- leads$Next[rows] != "-" & leads$Next[rows] %in% leads$Statement & !leads$Next[rows] %in% path
    for (k in seq_along(rows)) {
      r <- rows[k]
      nextQuestion <- if (goesOn[k]) question[[leads$Next[r]]] else ""
      body <<- c(body, paste0("          <Lead id=\"L", ids[k], "\">"),
                 if (!is.na(parent)) paste0("            <Parent ref=\"L", parent, "\"/>"),
                 paste0("            <Statement>", tdwgXmlEscape(leads$Character[r]), "</Statement>"),
                 if (nzchar(nextQuestion)) {
                   paste0("            <Question><Text>", tdwgXmlEscape(nextQuestion), "</Text></Question>")
                 },
                 if (!goesOn[k] && nzchar(leads$Taxon[r])) {
                   paste0("            <TaxonName ref=\"", taxonId[[leads$Taxon[r]]], "\"/>")
                 },
                 "          </Lead>")
    }
    for (k in which(goesOn)) emit(leads$Next[rows[k]], ids[k], c(path, leads$Next[rows[k]]))
  }
  emit(root, NA, root)
  c(out, body, "        </Leads>", "      </IdentificationKey>", "    </IdentificationKeys>")
}

tdwgKeyTaxa <- function(key) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose key", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  unique(leads$Taxon[nzchar(leads$Taxon) & (leads$Next == "-" | !leads$Next %in% leads$Statement)])
}

tdwgWriteLines <- function(lines, file) {
  con <- file(file, "w", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(enc2utf8(lines), con, useBytes = TRUE)
  invisible(file)
}

#' @rdname readSDD
#' @param x A character matrix (data frame), or the list returned by
#'   `readSDD()`, [readDELTA()], [readLucid()] or [readXper()].
#' @param characters Optional data frame describing the characters: a
#'   `Character` column matching the matrix's column names and any of
#'   `Type`, `States` (to fix the order of the states or list states no taxon
#'   has), `Unit`, `InapplicableIf` and `Cost`. By default taken from `x` if
#'   `x` is a reader's result; otherwise numeric columns are written as
#'   numeric characters and all others as categorical ones.
#' @param title Title of the dataset; by default the `title` in the
#'   metadata of `x`.
#' @param lang Language of the labels, as an `xml:lang` code.
#' @param key Optional [dimoose] key to store in the same file as an SDD
#'   identification key (see [writeSDDKey()]).
#' @section What is written:
#' A complete, schema-valid SDD 1.1 document with the taxon names, the
#' characters, a character tree holding the dependency rules, and one coded
#' description per taxon. `NA` cells are left out (SDD reads a missing
#' coding as unknown), cells equal to `inapplicable` get the status
#' `NotApplicable`. A `Cost` from 1 to 5 is written as an
#' observation-convenience rating, as Xper3 does. `"ordered"` characters are
#' written as categorical ones and `"integer"` as quantitative ones, so those
#' two types come back as `"categorical"` and `"real"`. Of a cell listing
#' several numeric ranges (`"5/10-15"`) the overall range is written, and
#' numbers are written as numbers (`"0.40"` comes back as `"0.4"`). A
#' categorical character for which no taxon has a state is written as a text
#' character, with a warning, because SDD does not allow a categorical
#' character without states. Files written from the real datasets dimoose
#' was tried on (DELTA, Lucid and Xper exports of up to 969 taxa) all
#' validate against the SDD 1.1 schema; none has been imported into Lucid
#' or Xper.
#' @export
writeSDD <- function(x, file, characters = NULL, taxon = "Taxon", title = NULL, sep = "/",
                     inapplicable = NULL, lang = "en", key = NULL) {
  tdwgWriteSDD(x, file, characters, taxon, title, sep, inapplicable, lang, key, generator = "dimoose")
}

tdwgWriteSDD <- function(x, file, characters, taxon, title, sep, inapplicable, lang, key, generator) {
  input <- tdwgInput(x, characters, taxon, sep, inapplicable)
  if (is.null(title)) title <- tdwgMetaGet(input$meta, "title")
  if (is.null(title)) title <- "Character matrix"
  taxa <- input$taxa
  detail <- NULL
  if (is.data.frame(input$taxaInfo) && !is.null(input$taxaInfo$Detail) && taxon %in% names(input$taxaInfo)) {
    detail <- as.character(input$taxaInfo$Detail[match(taxa, input$taxaInfo[[taxon]])])
  }
  keyBody <- NULL
  if (!is.null(key)) {
    extra <- setdiff(tdwgKeyTaxa(key), taxa)
    taxa <- c(taxa, extra)
    if (!is.null(detail)) detail <- c(detail, rep(NA, length(extra)))
    keyTitle <- if (is.null(key$desc) || is.na(key$desc)) title else as.character(key$desc)
    keyBody <- tdwgSddKey(key$leads, keyTitle, stats::setNames(paste0("t", seq_along(taxa)), taxa))
  }
  body <- c(tdwgSddTaxa(taxa, detail), tdwgSddMatrix(input, sep), keyBody)
  tdwgWriteLines(tdwgSddDocument(title, body, lang, tdwgMetaGet(input$meta, "description"), generator), file)
}

# ---- SDD: identification keys ------------------------------------------------------

#' Read and write a dichotomous key stored in SDD
#'
#' Besides character matrices, an SDD file can hold ready-made
#' identification keys (`<IdentificationKey>` elements): a tree of leads,
#' each with a statement and either further leads, a taxon or a pointer to
#' another key in the file. `readSDDKey()` reads one into a [dimoose] key,
#' `writeSDDKey()` stores a dimoose key that way. Lucid's pathway-key
#' builder exports this form.
#'
#' In SDD the leads form a tree (each lead names its parent lead) and are
#' not numbered. On reading, the leads that share a parent become a couplet
#' and the couplets are numbered in the usual order of a printed key (the
#' first lead of couplet 1 goes to couplet 2, and so on). A lead that points
#' to another key of the same file (`<Subkey>`) continues with that key's
#' first couplet, so a key split over several SDD keys comes back as one. A
#' question on a lead (or on the key itself) becomes the `Question` of the
#' couplet it leads to. A lead that ends without a taxon is kept, and
#' reported by `key$validate()`.
#'
#' On writing, a couplet that is reached from more than one lead
#' (a reticulate key) is written out once under each of them, because an SDD
#' lead can have only one parent. Images and links attached to leads or taxa
#' (`Image`, `TaxonUrl`) and other extra columns of the key are not written.
#'
#' @param file Path of the SDD file.
#' @param key For `readSDDKey()`, which key of the file to read: its
#'   position or its `id`. For `writeSDDKey()`, the [dimoose] key to write.
#' @param desc Title of the key; by default the key's label in the file.
#' @param dataset Which `<Dataset>` of the file to read, by position; by
#'   default the first one that holds a key.
#' @param title Title of the SDD dataset; by default the key's description.
#' @param lang Language of the text, as an `xml:lang` code.
#' @return `readSDDKey()` returns a [dimoose] key; `writeSDDKey()` returns
#'   `file`, invisibly.
#' @seealso [readSDD()] for the character matrix of an SDD file,
#'   [readLucidKey()] for Lucid's own pathway-key formats.
#' @examples
#' f <- system.file("extdata", "tdwg", "insects-key.sdd.xml", package = "dimoose")
#' k <- readSDDKey(f)
#' k
#' k$leads[, c("Statement", "Choice", "Character", "Next", "Taxon")]
#'
#' out <- writeSDDKey(sharkKey(), tempfile(fileext = ".xml"))
#' readSDDKey(out)
#' @export
readSDDKey <- function(file, key = 1, desc = NULL, dataset = NULL) {
  doc <- tdwgReadXml(file)
  ds <- tdwgSddDataset(doc, dataset, "IdentificationKeys")
  keys <- if (is.null(ds)) list() else xml2::xml_find_all(ds, "./IdentificationKeys/IdentificationKey")
  if (!length(keys)) stop("This SDD file has no identification key", call. = FALSE)
  keyIds <- xml2::xml_attr(keys, "id")
  at <- if (is.numeric(key)) key else match(as.character(key), keyIds)
  if (length(at) != 1 || is.na(at) || at < 1 || at > length(keys)) {
    stop(sprintf("`key` must be a number from 1 to %d or one of the ids %s", length(keys),
                 paste(keyIds, collapse = ", ")), call. = FALSE)
  }
  taxonNodes <- xml2::xml_find_all(ds, "./TaxonNames/TaxonName")
  taxonLabel <- stats::setNames(tdwgSddLabel(taxonNodes), xml2::xml_attr(taxonNodes, "id"))
  keyLabel <- tdwgSddLabel(keys)
  text <- function(nodes, path) {
    x <- tdwgSquish(xml2::xml_text(xml2::xml_find_first(nodes, path)))
    x[is.na(x)] <- ""
    x
  }
  tables <- lapply(keys, function(k) {
    nodes <- xml2::xml_find_all(k, "./Leads/Lead")
    data.frame(
      id = xml2::xml_attr(nodes, "id"),
      parent = xml2::xml_attr(xml2::xml_find_first(nodes, "./Parent"), "ref"),
      statement = text(nodes, "./Statement"),
      question = text(nodes, "./Question/Text"),
      taxon = xml2::xml_attr(xml2::xml_find_first(nodes, "./TaxonName"), "ref"),
      subkey = xml2::xml_attr(xml2::xml_find_first(nodes, "./Subkey"), "ref"),
      stringsAsFactors = FALSE
    )
  })
  keyQuestion <- text(keys, "./Question/Text")

  rows <- list()
  couplets <- 0
  expand <- function(k, parent, question, open) {
    tab <- tables[[k]]
    members <- if (is.na(parent)) which(is.na(tab$parent)) else which(!is.na(tab$parent) & tab$parent == parent)
    couplets <<- couplets + 1
    me <- couplets
    slot <- length(rows) + seq_along(members)
    rows[slot] <<- list(NULL)
    for (n in seq_along(members)) {
      j <- members[n]
      taxon <- if (is.na(tab$taxon[j])) "" else unname(taxonLabel[tab$taxon[j]])
      if (is.na(taxon)) taxon <- tab$taxon[j]
      target <- "-"
      sub <- match(tab$subkey[j], keyIds)
      if (!is.na(tab$id[j]) && any(tab$parent == tab$id[j], na.rm = TRUE)) {
        target <- expand(k, tab$id[j], tab$question[j], open)
      } else if (!is.na(sub) && !sub %in% open && any(is.na(tables[[sub]]$parent))) {
        target <- expand(sub, NA, keyQuestion[sub], c(open, sub))
      } else if (!is.na(tab$subkey[j]) && !nzchar(taxon)) {
        taxon <- if (is.na(sub)) tab$subkey[j] else keyLabel[sub]
      }
      rows[[slot[n]]] <<- data.frame(
        Statement = me, Choice = if (n <= 26) letters[n] else as.character(n),
        Character = tab$statement[j], Next = as.character(target), Taxon = taxon, Question = question,
        stringsAsFactors = FALSE
      )
    }
    me
  }
  if (!any(is.na(tables[[at]]$parent))) stop("The key has no leads", call. = FALSE)
  expand(at, NA, keyQuestion[at], at)
  leads <- do.call(rbind, rows)
  leads <- leads[order(leads$Statement), ]
  leads$Statement <- as.character(leads$Statement)
  rownames(leads) <- NULL
  if (!any(nzchar(leads$Question))) leads$Question <- NULL
  if (is.null(desc)) desc <- keyLabel[at]
  keyFromLeads(leads, desc, meta = tdwgSddMeta(doc, ds))
}

#' @rdname readSDDKey
#' @export
writeSDDKey <- function(key, file, title = NULL, lang = "en") {
  taxa <- tdwgKeyTaxa(key)
  desc <- if (is.null(key$desc) || is.na(key$desc)) "Identification key" else as.character(key$desc)
  if (is.null(title)) title <- desc
  body <- c(tdwgSddTaxa(taxa), tdwgSddKey(key$leads, desc, stats::setNames(paste0("t", seq_along(taxa)), taxa)))
  tdwgWriteLines(tdwgSddDocument(title, body, lang), file)
}

# ---- Xper ---------------------------------------------------------------------

#' Read and write Xper2 / Xper3 knowledge bases
#'
#' Xper3 (and its desktop predecessor Xper2) keep a knowledge base of taxa
#' ("items") described by characters ("descriptors"). Their documented
#' interchange format is SDD: export the knowledge base as SDD from Xper, and
#' import an SDD file written by `writeXper()` there. Xper's own storage
#' format is not publicly specified, so dimoose does not try to read or write
#' it; these two functions read and write the SDD dialect that Xper
#' produces.
#'
#' Compared with plain [readSDD()], the Xper dialect has a few habits that
#' are handled here: Xper2 names each taxon in the label of its coded
#' description rather than in a taxon list; the dependencies between
#' characters are `InapplicableIf` rules in a single character tree; and
#' every coding carries an observation-convenience rating, which is read as
#' the character's `Cost` (1 = easy to 5 = hard). `readXper()` stops if the
#' file was not written by Xper, unless `strict = FALSE`.
#'
#' @inheritParams readSDD
#' @param strict If `TRUE`, stop when the file does not say it was generated
#'   by Xper.
#' @return `readXper()` returns the same `tdwgData` list as [readSDD()];
#'   `writeXper()` returns `file`, invisibly.
#' @seealso [readSDD()], [writeSDD()].
#' @references Vignes-Lebbe, R., Chesselet, P. & Diep Thi, M.-H. (2016).
#'   Xper3: new tools for collaborating, training and transmitting knowledge
#'   on botanical phenotypes. In: *Botanists of the twenty-first century*,
#'   UNESCO. <https://www.xper3.fr/>
#' @examples
#' f <- system.file("extdata", "tdwg", "felids-xper3.sdd.xml", package = "dimoose")
#' d <- readXper(f)
#' d$matrix
#' d$characters[, c("Character", "InapplicableIf", "Cost")]
#'
#' out <- writeXper(d, tempfile(fileext = ".sdd.xml"))
#' identical(readXper(out)$matrix, d$matrix)
#' @export
readXper <- function(file, taxon = "Taxon", sep = "/", inapplicable = NA, strict = TRUE) {
  d <- readSDD(file, taxon = taxon, sep = sep, inapplicable = inapplicable)
  generator <- tdwgMetaGet(d$meta, "generator")
  if (strict && (is.null(generator) || !grepl("xper", generator, ignore.case = TRUE))) {
    stop("This SDD file does not say it was written by Xper (generator: ",
         if (is.null(generator)) "none" else generator, "); use readSDD(), or strict = FALSE", call. = FALSE)
  }
  d$meta$value[d$meta$key == "format"] <- "SDD, Xper dialect"
  d
}

#' @rdname readXper
#' @export
writeXper <- function(x, file, characters = NULL, taxon = "Taxon", title = NULL, sep = "/",
                      inapplicable = NULL, lang = "en") {
  tdwgWriteSDD(x, file, characters, taxon, title, sep, inapplicable, lang, key = NULL,
               generator = "dimoose (Xper dialect)")
}
