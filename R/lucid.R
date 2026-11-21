# Lucid (lucidcentral.org): matrix keys as Builder CSV, LIF3 and SDD, and
# pathway (dichotomous) keys as Lucid Phoenix XML, CSV, text and SDD. Shared
# helpers (tdwgInput(), tdwgData() ...) are in R/sdd.R.

# ---- helpers -------------------------------------------------------------------

# Which Lucid format a file is in, from its extension and first bytes
tdwgLucidFormat <- function(file) {
  if (!file.exists(file)) stop("File ", file, " not found", call. = FALSE)
  ext <- tolower(sub("^.*\\.", "", basename(file)))
  if (ext %in% c("lif3", "lpxk", "csv", "lif")) return(ext)
  if (ext == "txt") return("text")
  head <- rawToChar(readBin(file, "raw", min(file.size(file), 4000)))
  if (!validUTF8(head)) head <- iconv(head, "latin1", "UTF-8", sub = "")
  if (grepl("<lif3_key", head, fixed = TRUE)) return("lif3")
  if (grepl("<PhoenixKey", head, fixed = TRUE)) return("lpxk")
  if (grepl("<Datasets", head, fixed = TRUE)) return("sdd")
  if (grepl("[..", head, fixed = TRUE)) return("lif")
  if (grepl("^\\s*<", head)) return("xml")
  "csv"
}

# The last element of a colon-separated Lucid path, or the whole path where
# the last element alone would be ambiguous
tdwgLucidNames <- function(paths, fullNames = FALSE) {
  if (fullNames) return(paths)
  short <- trimws(sub("^.*:", "", paths))
  ambiguous <- short %in% short[duplicated(short)] | !nzchar(short)
  short[ambiguous] <- paths[ambiguous]
  short
}

tdwgLucidSafe <- function(x) gsub(":", " -", tdwgSquish(x), fixed = TRUE)

# Cells of one multistate character from a states x taxa table of Lucid scores
tdwgLucidCells <- function(score, states, scores, sep, inapplicable) {
  vapply(seq_len(ncol(score)), function(i) {
    s <- score[, i]
    has <- s %in% scores
    # every state "uncertain" says nothing about the taxon
    if (any(has) && !all(s[has] == 3)) return(paste(states[has], collapse = sep))
    if (any(s == 6)) inapplicable else NA_character_
  }, character(1))
}

# ---- matrix keys -------------------------------------------------------------------

#' Read and write Lucid matrix keys
#'
#' Lucid (Identic / Lucidcentral) is a widely used commercial program for
#' interactive matrix keys: "entities" (taxa) scored for the states of
#' "features" (characters). `readLucid()` reads a key exported from the Lucid
#' Builder into a character matrix (see [readSDD()] for the convention) and
#' `writeLucid()` writes a matrix in a form the Builder imports.
#'
#' @section Formats:
#' Lucid has several export formats, and they are not equally well
#' documented:
#'
#' - **`"csv"`** (Lucid Builder: *File > Export Key* and *Import Key*,
#'   file type CSV). Documented in the Lucid Builder help, which also offers
#'   a small example key with its CSV export: the first row holds the
#'   entities, every further row one state named `Feature:State` (a
#'   colon-separated path through the feature tree), and the cells hold the
#'   scores 0 absent, 1 present, 2 rarely present, 3 uncertain, 4 present by
#'   misinterpretation, 5 rarely present by misinterpretation, 6 not scoped.
#'   A numeric feature is one row named `Feature#` with cells
#'   `score type:rare low:low:high:rare high`, or a plain `0` when it is not
#'   scored. This is the format `writeLucid()` writes by default, and the
#'   documented way to get a matrix **into** Lucid. Use `entities = "rows"`
#'   for the Builder's "transposed" variant.
#' - **`"sdd"`**: Lucid exports matrix keys as SDD, the TDWG standard; the
#'   file is read with [readSDD()] and written with [writeSDD()].
#' - **`"lif3"`** (Lucid Interchange Format 3, `.lif3`): an XML file. Lucid
#'   publishes no schema or description of it beyond saying that it is XML,
#'   so `readLucid()` reads it as far as real exported files show how:
#'   features, states and entities (`<item>`), the feature and entity trees,
#'   and the multistate scores. This was checked against four published keys
#'   (Lucid 3 and Lucid 4 exports), one of which was also published as SDD:
#'   the two readings agree in all 3454 scores. Those files only use the
#'   scores 1 (present) and 3 (uncertain); the scores 2, 4, 5 and 6 are taken
#'   to mean what they mean in CSV, as they do in the Builder's own key
#'   files, which store scores in the same elements. No real LIF3 file with
#'   numeric scores was found: they are read when they are laid out as in the
#'   Builder's own key files (`<scored_data>` with `omin`, `nmin`, `nmax`,
#'   `omax`), and otherwise left out with a warning. **Units, dependencies,
#'   text scores, subsets and media of a LIF3 file are not read** (a warning
#'   says so when the file has dependencies or text scores), and dimoose does
#'   not write LIF3; export CSV or SDD from the Builder when you need those.
#' - **LIF** (Lucid 2, `.lif`, a sectioned text file) and the Builder's
#'   **"XML Dataset"** are not publicly specified; `readLucid()` stops and
#'   asks for a CSV or SDD export instead of guessing.
#'
#' @section Scores:
#' By default a taxon gets a state when it is scored present (1), rarely
#' present (2) or uncertain (3) for it; states scored only "by
#' misinterpretation" are left out, because the taxon does not really have
#' them. A feature for which every state of a taxon is uncertain, or nothing
#' is scored, gives `NA`; "not scoped" gives `inapplicable`. `writeLucid()`
#' writes 1 for every state in a cell and 0 otherwise, and 6 for cells equal
#' to `inapplicable`.
#'
#' For numeric features the Lucid help gives the layout of the cell but not
#' the values its score type can take. The one real export at hand uses 1
#' for a scored range and a plain `0` for a feature that is not scored, and
#' that is all `writeLucid()` writes: `1:rare low:low:high:rare high` for a
#' value or range, `0` for `NA`. A numeric cell equal to `inapplicable` is
#' also written as `0`, with a warning, because no score for "not scoped" is
#' documented for numeric features. On reading, type 1 gives the range, 0
#' gives `NA`, 6 is taken as "not scoped" by analogy with the multistate
#' scores, and any other type gives `NA` with a warning.
#'
#' Text characters cannot be stored in a Lucid matrix and are left out with a
#' warning. Colons in names are replaced, because Lucid reads them as steps
#' of a path; data that was read from Lucid keeps its paths (the `Path`
#' columns of `characters` and `taxa`). Units of numeric features are not
#' part of the CSV format. No file written by dimoose has been imported
#' into the Lucid Builder.
#'
#' @param file Path of the file to read or write.
#' @param format `"csv"`, `"sdd"` or (reading only) `"lif3"`; by default
#'   worked out from the file.
#' @param entities For CSV: whether the entities (taxa) are the `"columns"`
#'   (Lucid's default) or the `"rows"` (its "transposed" export).
#' @param scores Which Lucid scores mean that the taxon has the state.
#' @param fullNames If `TRUE`, name characters and taxa by their whole path
#'   in Lucid's feature and entity trees (`"Flowers:Petals:Colour"`) rather
#'   than by the last step (`"Colour"`). Names that would be ambiguous are
#'   always given in full.
#' @inheritParams readSDD
#' @return `readLucid()` returns a `tdwgData` list like [readSDD()]: `matrix`,
#'   `characters` (`Character`, `Type`, `States`, `Unit`, `Path`), `taxa`
#'   (`Taxon`, `Path`) and `meta`. `writeLucid()` returns `file`, invisibly.
#' @references Lucid Builder help, "CSV (Comma Separated Value) Files" and
#'   "Importing and Exporting", <https://help.lucidcentral.org/lucid/>.
#' @seealso [readLucidKey()] for Lucid pathway (dichotomous) keys,
#'   [readSDD()], [readDELTA()].
#' @examples
#' f <- system.file("extdata", "tdwg", "bears-lucid.csv", package = "dimoose")
#' d <- readLucid(f)
#' d$matrix
#' d$characters
#'
#' out <- writeLucid(d, tempfile(fileext = ".csv"))
#' readLines(out)
#' identical(readLucid(out)$matrix, d$matrix)
#' @export
readLucid <- function(file, format = NULL, taxon = "Taxon", sep = "/", inapplicable = NA,
                      entities = c("columns", "rows"), scores = c(1, 2, 3), fullNames = FALSE) {
  entities <- match.arg(entities)
  if (is.null(format)) format <- tdwgLucidFormat(file)
  format <- tolower(format)
  inapplicable <- as.character(inapplicable)
  if (format == "sdd") {
    d <- readSDD(file, taxon = taxon, sep = sep, inapplicable = inapplicable)
    d$meta$value[d$meta$key == "format"] <- "Lucid, SDD"
    return(d)
  }
  if (format == "csv") return(tdwgReadLucidCsv(file, taxon, sep, inapplicable, entities, scores, fullNames))
  if (format == "lif3") return(tdwgReadLif3(file, taxon, sep, inapplicable, scores, fullNames))
  if (format == "lpxk") stop("This is a Lucid pathway key; read it with readLucidKey()", call. = FALSE)
  if (format == "lif") {
    stop("This looks like a LIF file of Lucid 2. That text format is not publicly specified, so dimoose ",
         "does not read it: import it into the Lucid Builder and export CSV or SDD", call. = FALSE)
  }
  stop("Lucid format \"", format, "\" is not supported (the Builder's \"XML Dataset\" is not publicly ",
       "specified); export the key as CSV or SDD from the Lucid Builder", call. = FALSE)
}

tdwgReadLucidCsv <- function(file, taxon, sep, inapplicable, entities, scores, fullNames) {
  text <- tdwgReadText(file)
  table <- utils::read.csv(text = text, header = FALSE, colClasses = "character", na.strings = character(),
                           check.names = FALSE, strip.white = TRUE, encoding = "UTF-8")
  table <- as.matrix(table)
  dimnames(table) <- NULL
  if (entities == "rows") table <- t(table)
  if (nrow(table) < 2 || ncol(table) < 2) stop("The CSV file holds no scores", call. = FALSE)
  table <- table[c(TRUE, nzchar(table[-1, 1])), c(TRUE, nzchar(table[1, -1])), drop = FALSE]
  entityPath <- table[1, -1]
  rowPath <- table[-1, 1]
  cell <- table[-1, -1, drop = FALSE]

  numeric <- endsWith(rowPath, "#")
  hasColon <- grepl(":", rowPath, fixed = TRUE)
  featurePath <- ifelse(numeric, sub("#$", "", rowPath), ifelse(hasColon, sub(":[^:]*$", "", rowPath), rowPath))
  state <- ifelse(numeric, NA, ifelse(hasColon, trimws(sub("^.*:", "", rowPath)), "present"))
  cleaned <- tdwgCleanStates(state[!numeric], sep)
  tdwgWarnReplaced(if (is.null(attr(cleaned, "replaced"))) 0 else attr(cleaned, "replaced"), sep)
  state[!numeric] <- as.vector(cleaned)
  features <- unique(featurePath)
  isNumeric <- numeric[match(features, featurePath)]
  states <- lapply(features, function(f) state[featurePath == f & !numeric])
  oddTypes <- character()
  cells <- lapply(seq_along(features), function(j) {
    rows <- which(featurePath == features[j])
    if (isNumeric[j]) {
      return(vapply(strsplit(cell[rows[1], ], ":", fixed = TRUE), function(p) {
        v <- suppressWarnings(as.numeric(p))
        # a numeric feature that is not scored is a plain 0
        if (!length(v) || is.na(v[1]) || v[1] == 0) return(NA_character_)
        if (v[1] == 6) return(inapplicable)
        if (v[1] != 1) {
          oddTypes <<- c(oddTypes, p[1])
          return(NA_character_)
        }
        if (length(v) < 5 || anyNA(v[3:4])) return(NA_character_)
        tdwgFormatRange(omin = v[2], min = v[3], max = v[4], omax = v[5])
      }, character(1)))
    }
    score <- suppressWarnings(matrix(as.numeric(cell[rows, , drop = FALSE]), nrow = length(rows)))
    score[is.na(score)] <- 0
    tdwgLucidCells(score, states[[j]], scores, sep, inapplicable)
  })
  if (length(oddTypes)) {
    warning("Numeric score(s) of type ", paste(sort(unique(oddTypes)), collapse = ", "), " read as unknown: the Lucid help ",
            "does not say what the score type of a numeric feature can be, and only type 1 is known from a ",
            "real export", call. = FALSE)
  }
  names <- tdwgUnique(tdwgLucidNames(features, fullNames))
  taxa <- tdwgUnique(tdwgLucidNames(entityPath, fullNames))
  characters <- data.frame(
    Character = names, Type = ifelse(isNumeric, "real", "categorical"),
    States = vapply(states, paste, character(1), collapse = sep), Unit = "", Path = features,
    stringsAsFactors = FALSE
  )
  taxaInfo <- data.frame(Taxon = taxa, Path = entityPath, stringsAsFactors = FALSE)
  names(taxaInfo)[1] <- taxon
  tdwgData(tdwgMatrix(taxa, cells, names, taxon), characters, taxaInfo, tdwgMeta(format = "Lucid, CSV"))
}

# LIF3 as real exported files show it: <items> lists features, states and
# entities; <trees> holds the feature tree (states under features) and the
# entity tree; <descriptions><container type='normal'> holds, per state, the
# entities scored for it.
tdwgReadLif3 <- function(file, taxon, sep, inapplicable, scores, fullNames) {
  doc <- tdwgReadXml(file)
  if (xml2::xml_name(xml2::xml_root(doc)) != "lif3_key") stop("This is not a LIF3 file", call. = FALSE)
  items <- xml2::xml_find_all(doc, "/lif3_key/items/item")
  id <- xml2::xml_attr(items, "item_id")
  itemName <- tdwgSquish(xml2::xml_attr(items, "name"))
  itemType <- xml2::xml_attr(items, "item_type")
  tree <- function(type) {
    nodes <- xml2::xml_find_all(doc, sprintf("/lif3_key/trees/tree[@type='%s']/treenode", type))
    data.frame(id = xml2::xml_attr(nodes, "item_id"), parent = xml2::xml_attr(nodes, "parent_id"),
               stringsAsFactors = FALSE)
  }
  path <- function(nodes) {
    vapply(nodes$id, function(node) {
      steps <- character()
      while (!is.na(node) && node %in% nodes$id && length(steps) < 100) {
        steps <- c(itemName[match(node, id)], steps)
        node <- nodes$parent[match(node, nodes$id)]
      }
      paste(steps, collapse = ":")
    }, character(1))
  }
  featureTree <- tree("feature")
  entityTree <- tree("entity")
  featureTree$type <- itemType[match(featureTree$id, id)]
  featureTree$path <- path(featureTree)
  entityTree$path <- path(entityTree)

  scoring <- xml2::xml_find_all(doc, "/lif3_key/descriptions/container[@type='normal']/scoring_item")
  scored <- lapply(scoring, function(s) {
    nodes <- xml2::xml_find_all(s, "./scored_item")
    data.frame(state = rep(xml2::xml_attr(s, "item_id"), length(nodes)), entity = xml2::xml_attr(nodes, "item_id"),
               value = suppressWarnings(as.numeric(xml2::xml_attr(nodes, "value"))), stringsAsFactors = FALSE)
  })
  scored <- if (length(scored)) do.call(rbind, scored) else {
    data.frame(state = character(), entity = character(), value = numeric(), stringsAsFactors = FALSE)
  }
  if (any(!scored$value %in% 0:6)) {
    warning("Score(s) other than 0 to 6 in this LIF3 file are not known Lucid scores and are ignored: ",
            paste(utils::head(unique(scored$value[!scored$value %in% 0:6]), 5), collapse = ", "), call. = FALSE)
  }
  # Numeric scores. No real LIF3 file with numeric scores was at hand; Lucid's
  # own key files store them as <scored_data omin= nmin= nmax= omax=> under
  # the same scoring_item / scored_item elements, so that layout is read and
  # anything else is reported, not guessed at.
  numericItems <- xml2::xml_find_all(doc, "/lif3_key/descriptions/container[@type='numeric']/*")
  numericData <- xml2::xml_find_all(
    doc, "/lif3_key/descriptions/container[@type='numeric']/scoring_item/scored_item/scored_data[@nmin and @nmax]")
  measured <- data.frame(
    feature = xml2::xml_attr(xml2::xml_parent(xml2::xml_parent(numericData)), "item_id"),
    entity = xml2::xml_attr(xml2::xml_parent(numericData), "item_id"),
    type = xml2::xml_attr(numericData, "score_type"), stringsAsFactors = FALSE
  )
  for (a in c("omin", "nmin", "nmax", "omax")) {
    measured[[a]] <- suppressWarnings(as.numeric(xml2::xml_attr(numericData, a)))
  }
  if (length(numericItems) && !nrow(measured)) {
    warning("This LIF3 file has numeric scores in a layout dimoose does not know, so they are not read ",
            "(LIF3 is not publicly documented); export CSV or SDD from the Lucid Builder to get them", call. = FALSE)
  }
  unread <- c(dependencies = "dependency", dependencies = "dependencies", "text scores" = "text")
  has <- vapply(unread, function(type) {
    length(xml2::xml_find_first(doc, sprintf("/lif3_key/descriptions/container[@type='%s']/*", type))) > 0
  }, logical(1))
  if (any(has)) {
    warning("This LIF3 file has ", paste(unique(names(unread)[has]), collapse = " and "),
            ", which are not read (LIF3 is not publicly documented); export SDD from the Lucid Builder to get them",
            call. = FALSE)
  }

  # taxa: the entities at the tips of the entity tree, and any others that are scored
  keep <- !entityTree$id %in% entityTree$parent | entityTree$id %in% c(scored$entity, measured$entity)
  entity <- entityTree[keep, ]
  # characters: features with states under them; a feature with nothing under it is numeric
  isState <- featureTree$type == "state"
  parentOfState <- unique(featureTree$parent[isState])
  hasChildren <- featureTree$id %in% featureTree$parent
  feature <- featureTree[!isState & (featureTree$id %in% parentOfState | !hasChildren), ]
  if (!nrow(feature) || !nrow(entity)) stop("The LIF3 file holds no features or no entities", call. = FALSE)
  replaced <- 0
  states <- vector("list", nrow(feature))
  cells <- lapply(seq_len(nrow(feature)), function(j) {
    stateId <- featureTree$id[isState & featureTree$parent == feature$id[j]]
    if (!length(stateId)) {
      mine <- measured[measured$feature == feature$id[j] & measured$type %in% "1", ]
      at <- match(entity$id, mine$entity)
      return(vapply(at, function(k) {
        if (is.na(k)) return(NA_character_)
        tdwgFormatRange(omin = mine$omin[k], min = mine$nmin[k], max = mine$nmax[k], omax = mine$omax[k])
      }, character(1)))
    }
    labels <- tdwgCleanStates(itemName[match(stateId, id)], sep)
    if (!is.null(attr(labels, "replaced"))) replaced <<- replaced + attr(labels, "replaced")
    states[[j]] <<- tdwgUnique(as.vector(labels))
    score <- matrix(0, length(stateId), nrow(entity))
    mine <- scored[scored$state %in% stateId & scored$entity %in% entity$id, ]
    score[cbind(match(mine$state, stateId), match(mine$entity, entity$id))] <- mine$value
    score[is.na(score)] <- 0
    tdwgLucidCells(score, states[[j]], scores, sep, inapplicable)
  })
  tdwgWarnReplaced(replaced, sep)
  names <- tdwgUnique(tdwgLucidNames(feature$path, fullNames))
  taxa <- tdwgUnique(tdwgLucidNames(entity$path, fullNames))
  characters <- data.frame(
    Character = names, Type = ifelse(lengths(states) > 0, "categorical", "real"),
    States = vapply(states, paste, character(1), collapse = sep), Unit = "", Path = feature$path,
    stringsAsFactors = FALSE
  )
  taxaInfo <- data.frame(Taxon = taxa, Path = entity$path, stringsAsFactors = FALSE)
  names(taxaInfo)[1] <- taxon
  property <- function(key) {
    xml2::xml_attr(xml2::xml_find_first(doc, sprintf("/lif3_key/properties/property[@key='%s']", key)), "value")
  }
  title <- property("key_title")
  if (is.na(title) || !nzchar(title)) title <- gsub("_", " ", property("compile_key_title"))
  meta <- tdwgMeta(format = "Lucid, LIF3", title = title, description = property("key_description"),
                   authors = property("key_authors"))
  tdwgData(tdwgMatrix(taxa, cells, names, taxon), characters, taxaInfo, meta)
}

#' @rdname readLucid
#' @param x A character matrix (data frame), or the list returned by
#'   `readLucid()`, [readSDD()], [readDELTA()] or [readXper()].
#' @param characters Optional data frame describing the characters
#'   (`Character`, `Type`, `States`, `Unit`); see [writeSDD()].
#' @param title Title of the dataset (SDD only).
#' @export
writeLucid <- function(x, file, format = c("csv", "sdd"), characters = NULL, taxon = "Taxon", sep = "/",
                       inapplicable = NULL, entities = c("columns", "rows"), title = NULL) {
  if (identical(tolower(format[1]), "lif3") || identical(tolower(format[1]), "lif")) {
    stop("dimoose does not write LIF or LIF3: Lucid publishes no specification of them. ",
         "Write \"csv\", which the Lucid Builder imports, or \"sdd\"", call. = FALSE)
  }
  format <- match.arg(format)
  entities <- match.arg(entities)
  if (format == "sdd") {
    return(writeSDD(x, file, characters = characters, taxon = taxon, title = title, sep = sep,
                    inapplicable = inapplicable))
  }
  input <- tdwgInput(x, characters, taxon, sep, inapplicable)
  # the paths through Lucid's feature and entity trees, if the data came from Lucid
  path <- function(info, names, key) {
    safe <- tdwgLucidSafe(names)
    if (!is.data.frame(info) || is.null(info$Path) || is.null(info[[key]])) return(safe)
    known <- as.character(info$Path[match(names, info[[key]])])
    ifelse(is.na(known) | !nzchar(known), safe, known)
  }
  if (is.null(characters) && !is.data.frame(x)) characters <- x$characters
  featurePath <- path(characters, input$characters, "Character")
  entityPath <- path(input$taxaInfo, input$taxa, taxon)
  isText <- input$type == "text"
  if (all(isText)) stop("Nothing to write: the matrix has only text characters", call. = FALSE)
  if (any(isText)) {
    warning("Lucid has no text characters; left out: ", paste(input$characters[isText], collapse = ", "),
            call. = FALSE)
  }
  labels <- character()
  rows <- list()
  skipped <- unscoped <- character()
  for (j in which(!isText)) {
    feature <- featurePath[j]
    if (input$type[j] %in% c("categorical", "ordered")) {
      for (s in seq_along(input$states[[j]])) {
        has <- vapply(input$cells[[j]], function(cell) s %in% tdwgCellStates(cell, input$states[[j]], sep), logical(1))
        labels <- c(labels, paste0(feature, ":", tdwgLucidSafe(input$states[[j]][s])))
        rows[[length(rows) + 1]] <- ifelse(input$inapplicable[, j], "6", ifelse(has, "1", "0"))
      }
    } else {
      labels <- c(labels, paste0(feature, "#"))
      rows[[length(rows) + 1]] <- vapply(seq_along(input$taxa), function(i) {
        cell <- input$cells[[j]][i]
        # as the Lucid Builder writes a numeric feature that is not scored
        if (input$inapplicable[i, j]) {
          unscoped <<- c(unscoped, sprintf("%s, %s", input$taxa[i], input$characters[j]))
          return("0")
        }
        if (is.na(cell)) return("0")
        r <- tdwgCellRange(cell, sep)
        if (is.null(r)) {
          skipped <<- c(skipped, sprintf("%s, %s: \"%s\"", input$taxa[i], input$characters[j], cell))
          return("0")
        }
        low <- if (is.na(r[["omin"]])) r[["min"]] else r[["omin"]]
        high <- if (is.na(r[["omax"]])) r[["max"]] else r[["omax"]]
        paste(c("1", vapply(c(low, r[["min"]], r[["max"]], high), tdwgFormatNumber, character(1))), collapse = ":")
      }, character(1))
    }
  }
  if (length(skipped)) {
    warning("Not a number or range, so written as not scored: ", paste(utils::head(skipped, 5), collapse = "; "),
            if (length(skipped) > 5) sprintf(" and %d more", length(skipped) - 5), call. = FALSE)
  }
  if (length(unscoped)) {
    warning("\"Not applicable\" cannot be written for a numeric feature (Lucid documents no score for it), ",
            "so written as not scored: ", paste(utils::head(unscoped, 5), collapse = "; "),
            if (length(unscoped) > 5) sprintf(" and %d more", length(unscoped) - 5), call. = FALSE)
  }
  # quoted as the Lucid Builder writes it: the names are, the first cell and
  # the scores are not
  quote <- function(x) paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
  table <- rbind(c("", quote(entityPath)), cbind(quote(labels), do.call(rbind, rows)))
  if (entities == "rows") table <- t(table)
  tdwgWriteLines(apply(table, 1, paste, collapse = ","), file)
}

# ---- pathway keys ------------------------------------------------------------------

#' Read and write Lucid pathway (dichotomous) keys
#'
#' The Lucid Builder also makes "pathway" keys: ordinary dichotomous keys of
#' couplets and leads (the successor of the stand-alone Lucid Phoenix).
#' `readLucidKey()` reads one of its exports into a [dimoose] key and
#' `writeLucidKey()` writes a dimoose key in the same forms. All four are
#' described in the Lucid Builder help ("Pathway key exports"):
#'
#' - **`"lpxk"`**, Lucid Phoenix XML: `<PhoenixKey>` with the taxa as
#'   `<Identity>` elements and the couplets as `<Step>` elements holding
#'   `<Lead>`s whose `goto` names the next step or the taxon. The step's
#'   `text` becomes the couplet's `Question`, an identity's `url` the
#'   `TaxonUrl`. Filters (`<FilterItem>`) and icons are not read or written.
#' - **`"csv"`**: one line per lead, `couplet,"lead text",next couplet or
#'   taxon`.
#' - **`"text"`**: the same with blanks instead of commas, as printed in a
#'   paper.
#' - **`"sdd"`**: SDD with an identification key; see [readSDDKey()].
#'
#' In the CSV and text forms the last field is read as a couplet when it
#' matches a couplet number and as a taxon otherwise, so `writeLucidKey()`
#' refuses to write a key in which a taxon is named like a couplet. These
#' two forms hold neither the title of the key nor questions, links or
#' images. The CSV, text and Phoenix XML forms follow the examples printed
#' in the Lucid help; no file exported by the Lucid Builder itself was
#' available to check them against, and no file written by dimoose has been
#' imported into the Builder.
#'
#' @param file Path of the file to read or write.
#' @param format `"lpxk"`, `"csv"`, `"text"` or `"sdd"`; when reading, by
#'   default worked out from the file.
#' @param desc Title of the key; by default the title in the file, if any.
#' @param key A [dimoose] key.
#' @return `readLucidKey()` returns a [dimoose] key; `writeLucidKey()`
#'   returns `file`, invisibly.
#' @references Lucid Builder help, "Pathway key exports",
#'   <https://help.lucidcentral.org/lucid/pathway-key-exports/>.
#' @seealso [readLucid()] for Lucid matrix keys, [readSDDKey()],
#'   [keyFromSpreadsheet()].
#' @examples
#' f <- system.file("extdata", "tdwg", "insects.lpxk", package = "dimoose")
#' k <- readLucidKey(f)
#' k
#' k$leads[, c("Statement", "Choice", "Character", "Next", "Taxon")]
#'
#' out <- writeLucidKey(k, tempfile(fileext = ".csv"), format = "csv")
#' readLines(out)
#' @export
readLucidKey <- function(file, format = NULL, desc = NULL) {
  if (is.null(format)) format <- tdwgLucidFormat(file)
  format <- tolower(format)
  if (format == "sdd") return(readSDDKey(file, desc = desc))
  if (format == "lpxk") {
    doc <- tdwgReadXml(file)
    root <- xml2::xml_root(doc)
    if (xml2::xml_name(root) != "PhoenixKey") stop("This is not a Lucid Phoenix XML key", call. = FALSE)
    identity <- xml2::xml_find_all(root, "./Identity")
    identityId <- xml2::xml_attr(identity, "id")
    steps <- xml2::xml_find_all(root, "./Steps/Step")
    if (!length(steps)) stop("The key has no steps", call. = FALSE)
    stepId <- xml2::xml_attr(steps, "id")
    first <- match(xml2::xml_attr(xml2::xml_find_first(root, "./Steps"), "firstStepID"), stepId)
    order <- if (is.na(first)) seq_along(steps) else c(first, setdiff(seq_along(steps), first))
    number <- stats::setNames(as.character(seq_along(order)), stepId[order])
    leads <- do.call(rbind, lapply(order, function(s) {
      nodes <- xml2::xml_find_all(steps[[s]], "./Lead")
      goto <- xml2::xml_attr(nodes, "goto")
      goto[is.na(goto)] <- ""
      toStep <- goto %in% stepId
      who <- match(goto, identityId)
      url <- xml2::xml_attr(identity, "url")[who]
      question <- xml2::xml_attr(steps[[s]], "text")
      data.frame(
        Statement = rep(number[[stepId[s]]], length(nodes)),
        Choice = if (length(nodes) <= 26) letters[seq_along(nodes)] else as.character(seq_along(nodes)),
        Character = tdwgSquish(xml2::xml_text(xml2::xml_find_first(nodes, "./Text"))),
        Next = ifelse(toStep, unname(number[goto]), "-"),
        Taxon = ifelse(toStep, "", ifelse(is.na(who), goto, tdwgSquish(xml2::xml_attr(identity, "name")[who]))),
        Question = rep(if (is.na(question)) "" else tdwgSquish(question), length(nodes)),
        TaxonUrl = ifelse(is.na(url), "", url),
        stringsAsFactors = FALSE
      )
    }))
    if (is.null(desc)) desc <- xml2::xml_attr(root, "title")
    meta <- tdwgMeta(format = "Lucid Phoenix XML", generator = xml2::xml_attr(root, "CreatedIn"))
  } else if (format %in% c("csv", "text")) {
    lines <- strsplit(tdwgReadText(file), "\n", fixed = TRUE)[[1]]
    lines <- gsub("[\u201c\u201d]", "\"", lines[nzchar(trimws(lines))])
    if (format == "csv") {
      table <- utils::read.csv(text = paste(lines, collapse = "\n"), header = FALSE, colClasses = "character",
                               na.strings = character(), strip.white = TRUE, encoding = "UTF-8")
      if (ncol(table) < 3) stop("A Lucid pathway CSV has three columns: couplet, lead, next couplet or taxon",
                                call. = FALSE)
      fields <- data.frame(couplet = table[[1]], lead = table[[2]], goto = table[[3]], stringsAsFactors = FALSE)
    } else {
      m <- regmatches(lines, regexec("^\\s*(\\S+)\\s+\"(.*)\"\\s*(.*?)\\s*$", lines, perl = TRUE))
      if (any(lengths(m) == 0)) {
        stop("Line(s) not of the form  1 \"lead text\" 2 : ", paste(utils::head(which(lengths(m) == 0), 5), collapse = ", "),
             call. = FALSE)
      }
      fields <- data.frame(couplet = vapply(m, `[`, character(1), 2), lead = vapply(m, `[`, character(1), 3),
                           goto = vapply(m, `[`, character(1), 4), stringsAsFactors = FALSE)
    }
    fields$couplet <- trimws(fields$couplet)
    fields$goto <- trimws(fields$goto)
    toCouplet <- fields$goto %in% fields$couplet
    choice <- stats::ave(seq_along(fields$couplet), fields$couplet, FUN = seq_along)
    leads <- data.frame(
      Statement = fields$couplet, Choice = ifelse(choice <= 26, letters[pmin(choice, 26)], as.character(choice)),
      Character = tdwgSquish(fields$lead), Next = ifelse(toCouplet, fields$goto, "-"),
      Taxon = ifelse(toCouplet, "", fields$goto), stringsAsFactors = FALSE
    )
    meta <- tdwgMeta(format = paste("Lucid pathway key,", format))
  } else {
    stop("Format \"", format, "\" is not a Lucid pathway key format; use \"lpxk\", \"csv\", \"text\" or \"sdd\"",
         call. = FALSE)
  }
  if (!is.null(leads$Question) && !any(nzchar(leads$Question))) leads$Question <- NULL
  if (!is.null(leads$TaxonUrl) && !any(nzchar(leads$TaxonUrl))) leads$TaxonUrl <- NULL
  rownames(leads) <- NULL
  keyFromLeads(leads, if (is.null(desc) || is.na(desc) || !nzchar(desc)) NA else desc, meta = meta)
}

#' @rdname readLucidKey
#' @export
writeLucidKey <- function(key, file, format = c("lpxk", "csv", "text", "sdd")) {
  format <- match.arg(format)
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose key", call. = FALSE)
  if (format == "sdd") return(writeSDDKey(key, file))
  leads <- normalizeLeads(key$leads)
  toCouplet <- leads$Next != "-" & leads$Next %in% leads$Statement
  if (format %in% c("csv", "text")) {
    # the last field of a line is a couplet when it matches a couplet number
    clash <- unique(leads$Taxon[!toCouplet & leads$Taxon %in% leads$Statement])
    if (length(clash)) {
      stop("Taxon name(s) that are also couplet numbers cannot be told apart in Lucid's ", format, " format: ",
           paste(clash, collapse = ", "), "; write \"lpxk\" or \"sdd\" instead", call. = FALSE)
    }
    quoted <- paste0("\"", gsub("\"", if (format == "csv") "\"\"" else "'", leads$Character, fixed = TRUE), "\"")
    goto <- ifelse(toCouplet, leads$Next, leads$Taxon)
    if (format == "csv") {
      needsQuotes <- grepl("[,\"]", goto)
      goto[needsQuotes] <- paste0("\"", gsub("\"", "\"\"", goto[needsQuotes], fixed = TRUE), "\"")
    }
    return(tdwgWriteLines(paste(leads$Statement, quoted, goto, sep = if (format == "csv") "," else " "), file))
  }
  couplets <- unique(leads$Statement)
  root <- checkLeads(leads)$root
  stepId <- stats::setNames(paste0("s", seq_along(couplets) - 1), couplets)
  taxa <- unique(leads$Taxon[!toCouplet & nzchar(leads$Taxon)])
  identityId <- stats::setNames(paste0("i", seq_along(taxa) - 1), taxa)
  url <- leads$TaxonUrl[match(taxa, leads$Taxon)]
  title <- if (is.null(key$desc) || is.na(key$desc)) "" else as.character(key$desc)
  out <- c("<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
           paste0("<PhoenixKey title=\"", tdwgXmlEscape(title), "\" CreatedIn=\"dimoose\">"),
           paste0("  <Identity id=\"", identityId, "\" name=\"", tdwgXmlEscape(taxa), "\" icon=\"\" url=\"",
                  tdwgXmlEscape(url), "\" />")[seq_along(taxa)],
           paste0("  <Steps firstStepID=\"", stepId[[root]], "\">"))
  for (couplet in couplets) {
    rows <- which(leads$Statement == couplet)
    goto <- ifelse(toCouplet[rows], stepId[leads$Next[rows]],
                   ifelse(nzchar(leads$Taxon[rows]), identityId[leads$Taxon[rows]], ""))
    out <- c(out,
             paste0("    <Step id=\"", stepId[[couplet]], "\" text=\"", tdwgXmlEscape(leads$Question[rows[1]]), "\">"),
             paste0("      <Lead stepid=\"", stepId[[couplet]], "\" leadid=\"", stepId[[couplet]], "l",
                    seq_along(rows) - 1, "\" goto=\"", goto, "\">\n        <Text>",
                    tdwgXmlEscape(leads$Character[rows]), "</Text>\n      </Lead>"),
             "    </Step>")
  }
  tdwgWriteLines(c(out, "  </Steps>", "</PhoenixKey>"), file)
}
