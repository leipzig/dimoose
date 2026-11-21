# DELTA (DEscription Language for TAxonomy): the classic specs / chars / items
# files. Shared helpers (tdwgInput(), tdwgData() ...) are in R/sdd.R.

# ---- reading -------------------------------------------------------------------

tdwgReadText <- function(file) {
  if (!file.exists(file)) stop("File ", file, " not found", call. = FALSE)
  text <- rawToChar(readBin(file, "raw", file.size(file)))
  # DELTA files mostly come from Windows programs
  if (!validUTF8(text)) {
    # a few bytes mean nothing in Windows-1252; Latin-1 gives every byte a meaning
    converted <- iconv(text, "CP1252", "UTF-8")
    text <- if (is.na(converted)) iconv(text, "latin1", "UTF-8") else converted
  }
  Encoding(text) <- "UTF-8"
  gsub("\r\n?", "\n", sub("^\ufeff", "", text))
}

# Typesetting marks that DELTA programs put in text. They are RTF control
# words, usually closed by an empty pair of braces (\i{}Poa\i0{}), in older
# files also bare (\i0. or \par). Marks that stand for a character become
# that character, breaks become a blank, the others (italics, bold,
# superscript, paragraph settings) are dropped.
tdwgDeltaMarks <- c(endash = "\u2013", emdash = "\u2014", lquote = "\u2018", rquote = "\u2019",
                    ldblquote = "\u201c", rdblquote = "\u201d", bullet = "\u2022", tab = " ", par = " ",
                    line = " ", page = " ", sect = " ")

tdwgDeltaPlain <- function(x) {
  if (!any(grepl("\\", x, fixed = TRUE))) return(tdwgSquish(x))
  for (mark in names(tdwgDeltaMarks)) {
    x <- gsub(paste0("\\\\", mark, "(\\{\\}|(?![A-Za-z]))"), tdwgDeltaMarks[[mark]], x, perl = TRUE)
  }
  # the formatting words real files use, so that a mark run into the next
  # word (\iPoa) only loses the mark
  x <- gsub(paste0("\\\\(nosupersub|super|sub|plain|ulnone|ul|scaps|caps|strike|pard|li|fi|ri|sb|sa|",
                   "qc|ql|qr|qj|fs|cf|lang|[ibuf](?![a-z]))-?[0-9]*(\\{\\})?"), "", x, perl = TRUE)
  x <- gsub("\\\\[A-Za-z]+-?[0-9]*(\\{\\})?", "", x, perl = TRUE)
  x <- gsub("{}", "", x, fixed = TRUE)
  # \{ and \} are braces meant as such
  x <- gsub("\\\\([{}\\\\])", "\\1", x, perl = TRUE)
  tdwgSquish(x)
}

# Split DELTA text into directives: a star at the start of a line or after a
# blank, then a control phrase of up to four upper-case words, then the data.
# Only the first three letters of each word count.
tdwgDeltaKnown <- c("CHARACTER LIST", "ITEM DESCRIPTIONS", "CHARACTER TYPES", "NUMBERS OF STATES",
                    "NUMBER OF CHARACTERS", "MAXIMUM NUMBER OF STATES", "MAXIMUM NUMBER OF ITEMS",
                    "IMPLICIT VALUES", "DEPENDENT CHARACTERS", "INAPPLICABLE CHARACTERS", "HEADING", "SHOW")

tdwgDeltaDirectives <- function(text) {
  starts <- gregexpr("(?<![^\\s])\\*\\s?(?=[A-Z])", text, perl = TRUE)[[1]]
  if (starts[1] == -1) return(list())
  ends <- c(starts[-1] - 1, nchar(text))
  short <- function(phrase) paste(substr(strsplit(phrase, " ", fixed = TRUE)[[1]], 1, 3), collapse = " ")
  known <- vapply(tdwgDeltaKnown, short, character(1))
  out <- list()
  for (i in seq_along(starts)) {
    body <- sub("^\\*\\s?", "", substr(text, starts[i], ends[i]))
    lead <- regmatches(body, regexpr("^[A-Z]+(?:[ \t]+[A-Z]+){0,3}(?=\\s|$)", body, perl = TRUE))
    words <- if (length(lead)) strsplit(lead, "[ \t]+")[[1]] else character()
    for (n in rev(seq_along(words))) {
      hit <- match(paste(substr(words[seq_len(n)], 1, 3), collapse = " "), known)
      if (!is.na(hit)) {
        data <- sub(paste0("^", paste(words[seq_len(n)], collapse = "[ \t]+")), "", body)
        out[[length(out) + 1]] <- list(name = tdwgDeltaKnown[hit], data = data)
        break
      }
    }
  }
  out
}

# Replace comments (text in angle brackets, which may be nested) by
# placeholders, so that slashes, blanks and numeros inside them cannot be
# mistaken for DELTA syntax. In the character list and in item names a
# bracket only delimits a comment when it stands at a word boundary
# (`strict`); among the attributes every bracket does. A bracket without a
# partner is left as it is.
tdwgDeltaMask <- function(text, strict = FALSE) {
  if (!strict) return(tdwgDeltaMaskAll(text))
  pattern <- "(?<![^\\s<>\002])<[^<>]*>(?![^\\s<>/\001.,;:)])"
  store <- character()
  repeat {
    m <- gregexpr(pattern, text, perl = TRUE)
    if (m[[1]][1] == -1) break
    found <- regmatches(text, m)[[1]]
    regmatches(text, m) <- list(paste0("\001", length(store) + seq_along(found), "\002"))
    store <- c(store, found)
  }
  list(text = text, store = store)
}

# The same for text in which every bracket counts. Item descriptions run to
# megabytes, so this pairs the brackets in one pass over the bytes ("<" and
# ">" are single bytes in UTF-8) instead of rewriting the text once per level
# of nesting. Each outermost comment becomes one placeholder; the comments
# nested in it stay in its stored text.
tdwgDeltaMaskAll <- function(text) {
  bytes <- charToRaw(enc2utf8(text))
  at <- which(bytes == as.raw(0x3c) | bytes == as.raw(0x3e))
  if (!length(at)) return(list(text = text, store = character()))
  opens <- bytes[at] == as.raw(0x3c)
  from <- to <- integer(length(at))
  n <- 0L
  stack <- integer(length(at))
  depth <- 0L
  for (k in seq_along(at)) {
    if (opens[k]) {
      depth <- depth + 1L
      stack[depth] <- at[k]
    } else if (depth > 0L) {
      # a closed pair inside a bracket that never closes is still a comment,
      # so every pair is noted and the nested ones are dropped afterwards
      n <- n + 1L
      from[n] <- stack[depth]
      to[n] <- at[k]
      depth <- depth - 1L
    }
  }
  if (n == 0L) return(list(text = text, store = character()))
  from <- from[seq_len(n)]
  to <- to[seq_len(n)]
  o <- order(from)
  from <- from[o]
  to <- to[o]
  outer <- to > cummax(c(0L, to[-n]))
  from <- from[outer]
  to <- to[outer]
  piece <- function(a, b) {
    out <- if (b < a) "" else rawToChar(bytes[a:b])
    Encoding(out) <- "UTF-8"
    out
  }
  store <- unlist(Map(piece, from, to), use.names = FALSE)
  between <- unlist(Map(piece, c(1L, to + 1L), c(from - 1L, length(bytes))), use.names = FALSE)
  marks <- c(paste0("\001", seq_along(store), "\002"), "")
  list(text = paste0(between, marks, collapse = ""), store = store)
}

# Put the comments back (`keep`) or drop them
tdwgDeltaUnmask <- function(x, store, keep = FALSE) {
  if (!keep) return(gsub("\001[0-9]+\002", "", x))
  repeat {
    m <- gregexpr("\001[0-9]+\002", x)
    if (all(vapply(m, function(v) v[1] == -1, logical(1)))) break
    regmatches(x, m) <- lapply(regmatches(x, m), function(p) store[as.integer(gsub("[\001\002]", "", p))])
  }
  x
}

# The text of the comments in each element of `x`, without their outer
# brackets; several comments are joined with "; ". Comments nested in a
# comment keep their brackets, or are dropped with `nested = FALSE` (they
# are the DELTA way of writing a note that is never to be printed).
tdwgDeltaComment <- function(x, store, nested = TRUE) {
  marks <- regmatches(x, gregexpr("\001[0-9]+\002", x))
  vapply(marks, function(found) {
    if (!length(found)) return("")
    text <- tdwgDeltaUnmask(found, store, keep = TRUE)
    text <- substr(text, 2, nchar(text) - 1)
    if (!nested) {
      repeat {
        shorter <- gsub("<[^<>]*>", "", text)
        if (identical(shorter, text)) break
        text <- shorter
      }
    }
    text <- tdwgSquish(text)
    paste(text[nzchar(text)], collapse = "; ")
  }, character(1))
}

# A name with its comments dropped (or kept); if nothing but a comment is
# there ("#7. <comments>/"), the comment is the name
tdwgDeltaName <- function(x, store, comments = FALSE) {
  plain <- tdwgDeltaPlain(tdwgDeltaUnmask(x, store, keep = comments))
  empty <- !nzchar(plain)
  plain[empty] <- tdwgDeltaPlain(tdwgDeltaComment(x[empty], store, nested = comments))
  plain
}

# "2-3,OM 4,IN" -> data frame of character number and value
tdwgDeltaPairs <- function(data) {
  tokens <- strsplit(trimws(data), "[[:space:]]+")[[1]]
  m <- regmatches(tokens, regexec("^([0-9]+)(?:-([0-9]+))?,(.+)$", tokens, perl = TRUE))
  m <- m[lengths(m) > 0]
  if (!length(m)) return(data.frame(character = integer(), value = character(), stringsAsFactors = FALSE))
  do.call(rbind, lapply(m, function(p) {
    from <- as.integer(p[2])
    to <- if (nzchar(p[3])) as.integer(p[3]) else from
    data.frame(character = seq(from, to), value = p[4], stringsAsFactors = FALSE)
  }))
}

tdwgDeltaCharacters <- function(data, comments = FALSE) {
  masked <- tdwgDeltaMask(data, strict = TRUE)
  blocks <- strsplit(masked$text, "(?<![^\\s])#\\s*(?=[0-9]+\\.)", perl = TRUE)[[1]][-1]
  lapply(blocks, function(block) {
    parts <- trimws(strsplit(block, "/(?=\\s|$)", perl = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    head <- regmatches(parts[1], regexec("^([0-9]+)\\.\\s*([\\s\\S]*)$", parts[1], perl = TRUE))[[1]]
    rest <- parts[-1]
    isState <- grepl("^[0-9]+\\.(\\s|$)", rest)
    list(number = as.integer(head[2]),
         name = tdwgDeltaName(head[3], masked$store, comments),
         states = tdwgDeltaName(sub("^[0-9]+\\.\\s*", "", rest[isState]), masked$store, comments),
         unit = tdwgDeltaName(paste(rest[!isState], collapse = " "), masked$store, FALSE))
  })
}

tdwgDeltaItems <- function(data, comments = FALSE) {
  masked <- tdwgDeltaMask(data, strict = FALSE)
  blocks <- strsplit(masked$text, "(?<![^\\s])#", perl = TRUE)[[1]][-1]
  lapply(blocks, function(block) {
    variant <- startsWith(block, "+")
    if (variant) block <- substring(block, 2)
    slash <- regexpr("/(?=\\s|$)", block, perl = TRUE)
    name <- if (slash > 0) substr(block, 1, slash - 1) else block
    body <- if (slash > 0) substring(block, slash + 1) else ""
    tokens <- strsplit(trimws(body), "[[:space:]]+")[[1]]
    tokens <- tokens[nzchar(tokens)]
    m <- regmatches(tokens, regexec("^([0-9]+)((?:\001[0-9]+\002)*)(?:,(.*))?$", tokens, perl = TRUE))
    ok <- lengths(m) > 0
    list(name = tdwgDeltaName(name, masked$store, comments),
         comment = tdwgDeltaPlain(tdwgDeltaComment(name, masked$store)),
         variant = variant,
         character = as.integer(vapply(m[ok], `[`, character(1), 2)),
         comments = tdwgDeltaPlain(tdwgDeltaComment(vapply(m[ok], `[`, character(1), 3), masked$store)),
         values = tdwgDeltaUnmask(vapply(m[ok], `[`, character(1), 4), masked$store),
         stray = sum(!ok))
  })
}

#' Read and write DELTA datasets
#'
#' DELTA (DEscription Language for TAxonomy, Dallwitz 1980) is the oldest
#' and still widely used text format for descriptive data, and a TDWG
#' standard. A dataset is classically three files: `specs` (how many
#' characters there are and of which type), `chars` (the character list with
#' the states) and `items` (the taxa, each with its attributes).
#' `readDELTA()` reads them into a character matrix (see [readSDD()] for the
#' convention), `writeDELTA()` writes a matrix as the three files.
#'
#' @section What is read:
#' The directives `*CHARACTER LIST`, `*ITEM DESCRIPTIONS`,
#' `*CHARACTER TYPES`, `*NUMBERS OF STATES`, `*NUMBER OF CHARACTERS`,
#' `*IMPLICIT VALUES` and `*DEPENDENT CHARACTERS`, wherever in the given
#' files they are (so a dataset kept in one file, or split differently, reads
#' too); other directives are skipped. Character types are unordered
#' multistate (`UM`, read as `"categorical"`), ordered multistate (`OM`,
#' `"ordered"`), integer (`IN`, `"integer"`), real (`RN`, `"real"`) and text
#' (`TE`, `"text"`).
#'
#' Attributes follow the DELTA standard: `12,1/2` (state 1 or 2) and `12,1&2`
#' (1 and 2) both give `"state 1/state 2"`, so the difference between "or"
#' and "and" is not kept; `13,2-3` is a range, which for
#' an ordered character includes the states in between; `14,U` is unknown
#' (`NA`), `15,-` not applicable (`inapplicable`), `16,V` variable (all
#' states). Numeric values are kept as written, e.g. `"7-8.5"` or
#' `"(1-)2-3(-4)"`, which is the numeric notation of the matrix convention.
#' For a text character the cell is the text of the comment (`7<possibly two
#' species>`). Implicit values are filled in. A dependent character that is
#' not coded is "not applicable" when its controlling character only takes
#' the controlling states; the rule itself is kept in the `InapplicableIf`
#' column of `characters`. Variant items (`#+`) take the attributes they
#' leave out from their main item, as the standard says.
#'
#' Comments (text in angle brackets) are dropped from the names of
#' characters, states and taxa unless `comments = TRUE`, and from the
#' attributes of non-text characters; the comment of a taxon name (usually
#' the authority) is kept in `taxa$Comment`. A name that consists of nothing
#' but a comment (`#4. <longevity of plants>/`) is that comment. Typesetting
#' marks (the RTF control words DELTA programs use, such as `\i{}`, `\b0{}`
#' or `\par{}`) are removed, and those that stand for a character
#' (`\endash{}`, `\ldblquote{}`) become that character. Files that are not
#' valid UTF-8 are read as Windows-1252. The obsolete line sequence numbers
#' are not supported.
#'
#' The reader was checked against the datasets distributed with Open DELTA
#' (among them the "Grass Genera" sample, a flora of 506 taxa and a virus
#' database of 969 taxa) by comparing every coded attribute with a second,
#' independent parse of the files.
#'
#' @param specs Path of the `specs` file, or of a folder holding files
#'   named `specs`, `chars` and `items` (any extension, any case).
#' @param chars,items Paths of the `chars` and `items` files. May be left
#'   out when `specs` is a folder, or a single file holding everything.
#' @param comments If `TRUE`, keep the comments in the names of characters,
#'   states and taxa (`"pronotum <colour>"`).
#' @inheritParams readSDD
#' @return `readDELTA()` returns a `tdwgData` list like [readSDD()], with
#'   `matrix`, `characters` (`Character`, `Type`, `States`, `Unit`,
#'   `InapplicableIf`, `Number`), `taxa` (`Taxon`, `Comment`) and `meta`.
#'   `writeDELTA()` returns the paths of the three files, invisibly.
#' @references Dallwitz, M. J. & Paine, T. A. (1992 onwards). Definition of
#'   the DELTA format. <https://www.delta-intkey.com/www/standard.htm>
#' @seealso [readSDD()], [readLucid()].
#' @examples
#' dir <- system.file("extdata", "tdwg", "beetles-delta", package = "dimoose")
#' d <- readDELTA(dir)
#' d
#' d$matrix
#' d$characters[, c("Character", "Type", "States", "Unit")]
#'
#' out <- writeDELTA(d, tempfile("delta"))
#' out
#' identical(readDELTA(dirname(out[1]))$matrix, d$matrix)
#' @export
readDELTA <- function(specs, chars = NULL, items = NULL, taxon = "Taxon", sep = "/", inapplicable = NA,
                      comments = FALSE) {
  if (length(specs) == 1 && dir.exists(specs)) {
    files <- list.files(specs, full.names = TRUE)
    stem <- tolower(sub("\\.[^.]*$", "", basename(files)))
    found <- files[match(c("specs", "chars", "items"), stem)]
    if (anyNA(found[2:3])) {
      stop("Folder ", specs, " needs files named chars and items (and usually specs)", call. = FALSE)
    }
    files <- found[!is.na(found)]
  } else {
    files <- c(specs, chars, items)
  }
  inapplicable <- as.character(inapplicable)
  directives <- unlist(lapply(files, function(f) tdwgDeltaDirectives(tdwgReadText(f))), recursive = FALSE)
  named <- vapply(directives, function(d) d$name, character(1))
  get <- function(name) {
    paste(vapply(directives[named %in% name], function(d) d$data, character(1)), collapse = "\n")
  }
  if (!"ITEM DESCRIPTIONS" %in% named) {
    stop("No *ITEM DESCRIPTIONS directive found: these do not look like DELTA files", call. = FALSE)
  }
  charList <- tdwgDeltaCharacters(get("CHARACTER LIST"), comments)
  itemList <- tdwgDeltaItems(get("ITEM DESCRIPTIONS"), comments)
  if (!length(itemList)) stop("The item descriptions hold no items", call. = FALSE)
  if (any(vapply(itemList, function(it) it$stray, numeric(1)) > 0)) {
    warning(sprintf("%d attribute(s) could not be read and were skipped",
                    sum(vapply(itemList, function(it) it$stray, numeric(1)))), call. = FALSE)
  }

  declared <- suppressWarnings(as.integer(trimws(get("NUMBER OF CHARACTERS"))))
  nChar <- max(c(declared, vapply(charList, function(ch) ch$number, integer(1)),
                 unlist(lapply(itemList, function(it) it$character))), na.rm = TRUE)
  number <- seq_len(nChar)
  types <- tdwgDeltaPairs(get("CHARACTER TYPES"))
  types <- types[types$character <= nChar, ]
  code <- rep("UM", nChar)
  code[types$character] <- sub("^E", "", toupper(types$value))
  typeNames <- c(UM = "categorical", OM = "ordered", IN = "integer", RN = "real", TE = "text")
  if (any(!code %in% names(typeNames))) {
    warning("Unknown character type(s) read as unordered multistate: ",
            paste(unique(code[!code %in% names(typeNames)]), collapse = ", "), call. = FALSE)
    code[!code %in% names(typeNames)] <- "UM"
  }
  type <- unname(typeNames[code])
  multistate <- code %in% c("UM", "OM")

  # names, states and units: from the character list, or made up without one
  name <- paste("Character", number)
  unit <- rep("", nChar)
  counts <- tdwgDeltaPairs(get("NUMBERS OF STATES"))
  counts <- counts[counts$character <= nChar, ]
  nStates <- rep(2L, nChar)
  nStates[counts$character] <- suppressWarnings(as.integer(counts$value))
  states <- lapply(number, function(j) if (multistate[j]) as.character(seq_len(nStates[j])) else character())
  replaced <- 0
  for (ch in charList) {
    j <- ch$number
    if (nzchar(ch$name)) name[j] <- ch$name
    if (multistate[j]) {
      labels <- tdwgCleanStates(ch$states, sep)
      if (!is.null(attr(labels, "replaced"))) replaced <- replaced + attr(labels, "replaced")
      states[[j]] <- tdwgUnique(as.vector(labels))
    } else {
      unit[j] <- ch$unit
    }
  }
  tdwgWarnReplaced(replaced, sep)
  name <- tdwgUnique(name)

  # the cells: state positions for multistate characters, text for the others
  nItem <- length(itemList)
  picked <- matrix(list(integer()), nItem, nChar)
  text <- matrix(NA_character_, nItem, nChar)
  notApplicable <- coded <- valued <- matrix(FALSE, nItem, nChar)
  badStates <- 0
  for (i in seq_len(nItem)) {
    it <- itemList[[i]]
    for (a in seq_along(it$character)) {
      j <- it$character[a]
      coded[i, j] <- TRUE
      value <- it$values[a]
      if (code[j] == "TE") {
        if (nzchar(it$comments[a])) text[i, j] <- it$comments[a]
        valued[i, j] <- nzchar(it$comments[a])
        next
      }
      if (is.na(value) || !nzchar(value)) next
      valued[i, j] <- TRUE
      alternatives <- strsplit(value, "/", fixed = TRUE)[[1]]
      if (any(alternatives == "-")) notApplicable[i, j] <- TRUE
      alternatives <- alternatives[!alternatives %in% c("-", "U", "")]
      if (multistate[j]) {
        found <- integer()
        for (alt in alternatives) {
          if (alt == "V") {
            found <- c(found, seq_along(states[[j]]))
            next
          }
          # "&" (and) binds more loosely than "-" (to): 1-2&4
          for (part in strsplit(alt, "&", fixed = TRUE)[[1]]) {
            ends <- suppressWarnings(as.integer(strsplit(part, "-", fixed = TRUE)[[1]]))
            if (!length(ends)) ends <- NA_integer_
            found <- c(found, if (code[j] == "OM" && length(ends) > 1 && !anyNA(ends)) seq(min(ends), max(ends)) else ends)
          }
        }
        bad <- is.na(found) | found < 1 | found > length(states[[j]])
        badStates <- badStates + sum(bad)
        picked[[i, j]] <- sort(unique(found[!bad]))
      } else {
        alternatives <- alternatives[alternatives != "V"]
        if (length(alternatives)) text[i, j] <- paste(gsub("&", sep, alternatives, fixed = TRUE), collapse = sep)
      }
    }
  }
  if (badStates > 0) {
    warning(sprintf("%d state number(s) in the items are not states of their character and were skipped",
                    badStates), call. = FALSE)
  }

  # variant items take what they leave out from their main item
  main <- NA
  for (i in seq_len(nItem)) {
    if (!itemList[[i]]$variant) {
      main <- i
    } else if (!is.na(main)) {
      copy <- !coded[i, ]
      picked[i, copy] <- picked[main, copy]
      text[i, copy] <- text[main, copy]
      notApplicable[i, copy] <- notApplicable[main, copy]
      coded[i, copy] <- coded[main, copy]
      valued[i, copy] <- valued[main, copy]
    }
  }

  # implicit values: "c,s:t" gives s to a character left out and t to one
  # written without a value
  implicit <- tdwgDeltaPairs(get("IMPLICIT VALUES"))
  implicit <- implicit[implicit$character <= nChar, ]
  filled <- matrix(FALSE, nItem, nChar)
  for (r in seq_len(nrow(implicit))) {
    j <- implicit$character[r]
    if (!multistate[j]) next
    value <- suppressWarnings(as.integer(strsplit(implicit$value[r], ":", fixed = TRUE)[[1]]))
    for (i in seq_len(nItem)) {
      use <- if (!coded[i, j]) value[1] else if (!valued[i, j] && length(value) > 1) value[2] else NA
      if (!is.na(use) && use >= 1 && use <= length(states[[j]])) {
        picked[[i, j]] <- use
        filled[i, j] <- TRUE
      }
    }
  }

  # dependent characters: "c,s1/s2:d1:d2-d3"
  rules <- rep("", nChar)
  tokens <- strsplit(trimws(get(c("DEPENDENT CHARACTERS", "INAPPLICABLE CHARACTERS"))), "[[:space:]]+")[[1]]
  for (m in regmatches(tokens, regexec("^([0-9]+),([0-9/]+):(.+)$", tokens, perl = TRUE))) {
    if (!length(m)) next
    controlling <- as.integer(m[2])
    if (controlling > nChar || !multistate[controlling]) next
    controllingStates <- as.integer(strsplit(m[3], "/", fixed = TRUE)[[1]])
    controllingStates <- controllingStates[controllingStates >= 1 & controllingStates <= length(states[[controlling]])]
    dependents <- unlist(lapply(strsplit(m[4], ":", fixed = TRUE)[[1]], function(d) {
      ends <- suppressWarnings(as.integer(strsplit(d, "-", fixed = TRUE)[[1]]))
      if (anyNA(ends) || !length(ends)) integer() else seq(ends[1], ends[length(ends)])
    }))
    dependents <- dependents[dependents >= 1 & dependents <= nChar]
    if (!length(controllingStates) || !length(dependents)) next
    rule <- tdwgRuleText(name[controlling], states[[controlling]][controllingStates], sep)
    rules[dependents] <- ifelse(nzchar(rules[dependents]), paste(rules[dependents], rule, sep = "; "), rule)
    for (i in seq_len(nItem)) {
      has <- picked[[i, controlling]]
      if (!length(has) || !all(has %in% controllingStates)) next
      for (d in dependents) {
        if ((length(picked[[i, d]]) || !is.na(text[i, d])) && !filled[i, d]) next
        picked[[i, d]] <- integer()
        text[i, d] <- NA
        notApplicable[i, d] <- TRUE
      }
    }
  }

  cells <- lapply(number, function(j) {
    v <- text[, j]
    if (multistate[j]) {
      v <- vapply(picked[, j], function(p) if (length(p)) paste(states[[j]][p], collapse = sep) else NA_character_,
                  character(1))
    }
    v[is.na(v) & notApplicable[, j]] <- inapplicable
    v
  })
  itemNames <- vapply(itemList, function(it) it$name, character(1))
  itemNames[!nzchar(itemNames)] <- paste("Item", which(!nzchar(itemNames)))
  itemNames <- tdwgUnique(itemNames)
  characters <- data.frame(
    Character = name, Type = type,
    States = vapply(states, function(s) paste(s, collapse = sep), character(1)),
    Unit = unit, InapplicableIf = rules, Number = number, stringsAsFactors = FALSE
  )
  taxa <- data.frame(Taxon = itemNames, Comment = vapply(itemList, function(it) it$comment, character(1)),
                     stringsAsFactors = FALSE)
  names(taxa)[1] <- taxon
  heading <- named %in% c("HEADING", "SHOW")
  title <- if (any(heading)) tdwgSquish(sub("^[~:[:space:]]+", "", directives[[which(heading)[1]]]$data)) else NA
  # "Grass Genera - specifications.", "Virus specifications. Edited 26th Jan 1996."
  title <- sub("[-\u2013:,[:space:]]*\\b(specifications|specs|character list|chars|item descriptions|items)\\b.*$", "",
               tdwgDeltaPlain(title), ignore.case = TRUE)
  tdwgData(tdwgMatrix(itemNames, cells, name, taxon), characters, taxa,
           tdwgMeta(format = "DELTA", title = title))
}

# ---- writing -------------------------------------------------------------------

# Text as it can stand in a DELTA file. A star after a blank starts a
# directive wherever it is, even inside a comment, so it is put in
# parentheses. In a name (`name = TRUE`) a slash before a blank would end
# the name and a numero after a blank would start the next one: the blank
# after the slash is dropped, a slash at the very end too, and the numero is
# put in parentheses.
tdwgDeltaSafe <- function(x, name = TRUE) {
  x <- tdwgSquish(x)
  x <- gsub("(^| )\\*", "\\1(*)", x)
  if (name) {
    x <- gsub("/+$", "", gsub("/ ", "/", x, fixed = TRUE))
    x <- gsub("(^| )#", "\\1(#)", x)
  }
  trimws(x)
}

tdwgDeltaWrap <- function(x, indent = 0) {
  unlist(lapply(x, function(line) {
    if (nchar(line) + indent <= 78) return(paste0(strrep(" ", indent), line))
    strwrap(line, width = 78, indent = indent, exdent = indent)
  }))
}

#' @rdname readDELTA
#' @param x A character matrix (data frame), or the list returned by
#'   `readDELTA()`, [readSDD()], [readLucid()] or [readXper()].
#' @param dir Folder to write the three files into; created if needed.
#' @param characters Optional data frame describing the characters
#'   (`Character`, `Type`, `States`, `Unit`, `InapplicableIf`); see
#'   [writeSDD()].
#' @param title Title put in the `*SHOW` line of each file.
#' @param files Names of the three files.
#' @section What is written:
#' `specs` gets the numbers of characters, states and items, the character
#' types, the numbers of states and the dependent characters; `chars` the
#' character list; `items` one item per taxon. Every coded cell is written
#' out (no implicit values are used), `NA` cells are left out, which DELTA
#' reads as unknown, and cells equal to `inapplicable` are written as `-`.
#' The states of a variable taxon are joined with `/` ("or"). A numeric cell
#' that is not a DELTA number or range, and all cells of text characters,
#' are written as comments. Encoding is UTF-8, and lines are wrapped at 78
#' columns wherever they have a blank to break at.
#'
#' A few things cannot be written as they are, because DELTA would read
#' them as syntax: angle brackets in a name make a comment (which
#' `readDELTA()` drops unless `comments = TRUE`); a star or, in a name, a
#' numero after a blank is put in parentheses (`(*)`, `(#)`); the blank
#' after a slash in a name is dropped. No file written by dimoose has been
#' read into a DELTA program (Confor, Intkey, Open DELTA).
#' @export
writeDELTA <- function(x, dir, characters = NULL, taxon = "Taxon", sep = "/", inapplicable = NULL,
                       title = NULL, files = c(specs = "specs", chars = "chars", items = "items")) {
  input <- tdwgInput(x, characters, taxon, sep, inapplicable)
  if (is.null(names(files))) names(files) <- c("specs", "chars", "items")[seq_along(files)]
  if (!all(c("specs", "chars", "items") %in% names(files))) {
    stop("`files` must name the specs, chars and items files", call. = FALSE)
  }
  if (is.null(title)) title <- tdwgMetaGet(input$meta, "title")
  if (is.null(title)) title <- "Character matrix"
  nChar <- length(input$characters)
  number <- seq_len(nChar)
  code <- unname(c(categorical = "UM", ordered = "OM", integer = "IN", real = "RN", text = "TE")[input$type])
  stateless <- code %in% c("UM", "OM") & lengths(input$states) == 0
  if (any(stateless)) {
    warning("Character(s) without any state written as text characters: ",
            paste(input$characters[stateless], collapse = ", "), call. = FALSE)
    code[stateless] <- "TE"
  }
  multistate <- code %in% c("UM", "OM")
  nStates <- lengths(input$states)

  # dependent characters, grouped by controlling character and states
  dependencies <- list()
  for (j in number) {
    for (rule in tdwgParseRules(input$inapplicableIf[j], input, sep)) {
      id <- paste0(rule$character, ",", paste(sort(rule$states), collapse = "/"))
      dependencies[[id]] <- c(dependencies[[id]], j)
    }
  }
  dependent <- if (length(dependencies)) {
    controlling <- as.integer(sub(",.*$", "", names(dependencies)))
    dependencies <- dependencies[order(controlling, names(dependencies))]
    paste0(names(dependencies), ":", vapply(dependencies, paste, character(1), collapse = ":"))
  }
  directive <- function(name, values) {
    if (!length(values)) return(NULL)
    c("", tdwgDeltaWrap(paste0("*", name, " ", paste(values, collapse = " "))))
  }
  show <- function(what) tdwgDeltaWrap(paste0("*SHOW ~ ", tdwgDeltaSafe(title), " - ", what, "."))
  specs <- c(show("specifications"), "",
             paste("*NUMBER OF CHARACTERS", nChar),
             paste("*MAXIMUM NUMBER OF STATES", max(c(nStates[multistate], 1))),
             paste("*MAXIMUM NUMBER OF ITEMS", length(input$taxa)),
             directive("CHARACTER TYPES", paste0(number, ",", code)[code != "UM"]),
             directive("NUMBERS OF STATES", paste0(number, ",", nStates)[multistate & nStates != 2]),
             directive("DEPENDENT CHARACTERS", dependent))

  chars <- c(show("character list"), "", "*CHARACTER LIST")
  for (j in number) {
    unit <- if (code[j] %in% c("IN", "RN") && nzchar(input$unit[j])) paste0(" ", tdwgDeltaSafe(input$unit[j]), "/") else ""
    chars <- c(chars, tdwgDeltaWrap(paste0("#", j, ". ", tdwgDeltaSafe(input$characters[j]), "/", unit)),
               if (multistate[j]) {
                 tdwgDeltaWrap(paste0(seq_along(input$states[[j]]), ". ", tdwgDeltaSafe(input$states[[j]]), "/"), 7)
               })
  }

  # text as a comment: angle brackets in it are kept when they pair up (they
  # are then comments within the comment), otherwise written as parentheses
  asComment <- function(text) {
    text <- tdwgDeltaSafe(text, name = FALSE)
    side <- utf8ToInt(gsub("[^<>]", "", text)) == utf8ToInt("<")
    depth <- cumsum(ifelse(side, 1, -1))
    if (length(depth) && (any(depth < 0) || depth[length(depth)] != 0)) {
      text <- gsub(">", ")", gsub("<", "(", text, fixed = TRUE), fixed = TRUE)
    }
    paste0("<", text, ">")
  }
  items <- c(show("items"), "", "*ITEM DESCRIPTIONS")
  for (i in seq_along(input$taxa)) {
    attributes <- character()
    for (j in number) {
      cell <- input$cells[[j]][i]
      if (input$inapplicable[i, j]) {
        attributes <- c(attributes, paste0(j, ",-"))
      } else if (is.na(cell)) {
        next
      } else if (multistate[j]) {
        attributes <- c(attributes, paste0(j, ",", paste(sort(unique(tdwgCellStates(cell, input$states[[j]], sep))), collapse = "/")))
      } else if (code[j] == "TE") {
        attributes <- c(attributes, paste0(j, asComment(cell)))
      } else {
        values <- gsub(" ", "", trimws(strsplit(cell, sep, fixed = TRUE)[[1]]), fixed = TRUE)
        numeric <- length(values) && !any(vapply(lapply(values, tdwgParseRange), is.null, logical(1)))
        attributes <- c(attributes, if (numeric) paste0(j, ",", paste(values, collapse = "/")) else paste0(j, asComment(cell)))
      }
    }
    items <- c(items, "", tdwgDeltaWrap(paste0("# ", tdwgDeltaSafe(input$taxa[i]), "/")),
               if (length(attributes)) strwrap(paste(attributes, collapse = " "), width = 78))
  }

  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  paths <- file.path(dir, files[c("specs", "chars", "items")])
  names(paths) <- c("specs", "chars", "items")
  tdwgWriteLines(specs, paths[["specs"]])
  tdwgWriteLines(chars, paths[["chars"]])
  tdwgWriteLines(items, paths[["items"]])
  invisible(paths)
}
