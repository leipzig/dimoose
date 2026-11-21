#' Read a key written as plain text
#'
#' Most identification keys exist only as printed text: floras, monographs,
#' scans in the Biodiversity Heritage Library. `keyFromText()` reads such a
#' key, one lead at a time (couplet, lead, text and destination), builds a
#' [dimoose] key with [keyFromLeads()] and checks it with `$validate()`.
#' [parseTextKey()] is the lower-level half that returns the lead table and
#' the list of problems without building the key.
#'
#' @details
#' Layouts that are recognised:
#'
#' * Bracketed keys, where the leads of a couplet stand together:
#'   `1a.`/`1b.`, `1.`/`1'.` (primes), `1.`/`1.`, `1`/`-` (a dash for the
#'   second lead), `1(a)`/`1(b)`, `(1)`/`(1)`, Roman numerals `II.`,
#'   `A.`/`AA.` or `a.`/`aa.` lettering, and labels with a back-reference
#'   such as `3(1).` (couplet 3, reached from couplet 1). The second lead
#'   may also be marked `+`, or carry no label at all: a new paragraph, as
#'   in many older entomological keys, or a line of its own with dot
#'   leaders under a complete lead.
#' * Indented (yoked) keys, where the second lead of a couplet comes much
#'   later and a lead without a destination leads to the couplet printed
#'   under it.
#' * Indented keys without any couplet numbers, as in most older floras:
#'   the leads of a couplet share an indent, and a lead ends in a name,
#'   often with its number in the flora (`... long-acuminate. 1. S. nigra.`).
#'   The couplets are made from the indentation and numbered in order.
#'   Plain OCR text usually loses the indentation. The couplets are then
#'   worked out from the order of the leads, which works when every couplet
#'   has exactly two leads: a lead without a name opens the next couplet,
#'   a lead with a name is followed by the second lead of the nearest
#'   couplet still lacking one. This is reported as a repair; if the leads
#'   do not pair off, the key is refused with the line where the pairing
#'   breaks. One key at a time: a second heading in the text stops the
#'   reading there.
#' * Paired keys, where every lead has its own number and names its
#'   alternative in parentheses (`1 (8) ...` and further down `8 (1) ...`).
#'   The two are put together as one couplet, named after the lower number.
#' * Couplets with three or more leads, and couplets reached from several
#'   leads.
#'
#' The destination is whatever follows dot leaders, a tab, a run of three
#' or more spaces, a colon before a number (`lobed: 5`) or a spaced dash
#' (`a large tree -- Quercus alba`): a couplet number (also `go to 5`,
#' `see 5`, `(5)`, `> 5`) or a taxon. A taxon may carry an authority, a
#' common name (in parentheses, or in front of the scientific name) and a
#' page number (`Salix, p. 212`, `HEMIPTERA (Page 76)`, `Culicidae, 96`);
#' the genus may be abbreviated (`S. alba L.`). These go to the
#' `Authority`, `CommonName` and `Page` columns of the lead table. A number
#' in parentheses after a name (`Pinus. (7).`) is taken for its page or
#' list number, not for a couplet. Lead text may wrap over several lines,
#' with the destination on the last one; words hyphenated at a line end are
#' joined, and blank lines, page numbers, running heads and figure captions
#' in between are skipped, as are footnotes. Text in two columns side by
#' side (as `pdftotext -layout` gives it) is read column by column; this
#' is reported as a repair. Markdown emphasis and tables are read as plain
#' text.
#'
#' Scanned text is repaired where that is safe: `l`, `I` or `|` read as 1
#' and `O` as 0 in couplet numbers, labels that lost their full stop,
#' labels garbled beyond reading where only one couplet can be meant
#' (`V0.` between 9 and 11), and destinations that lost their dot leaders
#' (`... each year. 11.`, `... leaves flat. Abies.`). Text with two or more
#' spaces between all words, as many scans have, is recognised, and only
#' clearly wider gaps count as gaps there. Every repair is reported, and
#' with `strict = TRUE` the function stops instead of repairing.
#'
#' Nothing is dropped silently. A lead without a destination, a couplet
#' with one lead, a destination couplet that does not exist, a destination
#' that is probably a broken number (`S` for 5), a jump in the couplet
#' numbers, a label that stands alone on its line, text that looks like a
#' lead without a label and similar faults are reported with the line they
#' are on. `keyFromText()` gives one warning that lists them and attaches
#' the full table to the key as `attr(key, "problems")`. Text that was
#' passed over (running heads, descriptions between leads) is listed there
#' as notes.
#'
#' What a scan has lost cannot be put back: a couplet number misread as
#' another number that also exists in the key gives a wrong link without a
#' warning, and leads whose labels the scan put in a column of their own
#' are reported as lost, not recovered. Check a key read from a scan
#' against the page. Not handled: keys without numbers that are not
#' indented and have couplets of three or more leads, keys that mix
#' letters and unnumbered leads (Gray's Manual), keys divided by section
#' headings that stand for leads (`A.`, `*`, `**` in Britton & Brown), and
#' text in more than two columns.
#'
#' @section A first pass by a language model:
#' For badly scanned keys, `llm` can be a function that takes the whole text
#' as one string and returns either cleaned-up key text (one lead per line,
#' in any layout above), a data frame with columns `couplet`, `lead`,
#' `text` and `destination`, or the same as JSON (an array of leads; needs
#' the jsonlite package). Markdown code fences around the answer are taken
#' off. You write that function; dimoose calls no model or API itself. What
#' comes back is not trusted: it goes through the same checks, and each lead
#' is compared with the source, so a lead whose words or taxon do not occur
#' in the source, a destination that is not on the lines of its lead in the
#' source (two names swapped, a lead sent to another couplet), or a lead the
#' model left out, is reported with the line of the source it belongs to
#' (a lead that is not in the source at all has no such line; the message
#' then names the line or row of the model's answer). The title is taken
#' from the source, not from the answer.
#' An answer that cannot be read (cut-off JSON, prose without leads, an
#' empty table) is an error; nothing is taken from it.
#'
#' @param text The key: a file path, one string holding the whole key, or a
#'   character vector of lines. Give the key alone, without the descriptions
#'   before and after it.
#' @param desc Title of the key. By default the first line above the first
#'   lead is used, if there is one.
#' @param meta Key/value data frame of metadata (e.g. `citation`), passed to
#'   [keyFromLeads()].
#' @param llm Optional function for a first pass over messy text; see the
#'   section below.
#' @param strict If `TRUE`, stop when anything had to be repaired or any
#'   problem was found, instead of warning.
#' @param ... Further arguments for [parseTextKey()] (`layout`, `skip`).
#' @return A [dimoose] key. `attr(key, "problems")` is a data frame of
#'   problems, repairs and notes (see [parseTextKey()]).
#' @seealso [parseTextKey()], [keyFromLeads()]
#' @examples
#' # A bracketed key with dot leaders, wrapped leads and authorities
#' file <- system.file("extdata", "textkeys", "trees-bracketed.txt", package = "dimoose")
#' cat(readLines(file, n = 8), sep = "\n")
#' trees <- keyFromText(file)
#' trees
#' trees$leads[, c("Statement", "Choice", "Next", "Taxon", "CommonName")]
#'
#' # An indented key, given as a string
#' conifers <- keyFromText(system.file("extdata", "textkeys", "conifers-indented.txt",
#'   package = "dimoose"))
#' conifers$toNewick()
#'
#' # Problems are reported with their line and attached to the key
#' broken <- "1a. Wings present .... 2
#' 1b. Wings absent .... Apterygota
#' 2a. Two wings .... Diptera
#' 2b. Four wings"
#' k <- suppressWarnings(keyFromText(broken, "Insects"))
#' attr(k, "problems")[, c("Line", "Lead", "Kind", "Message")]
#'
#' \dontrun{
#' # A first pass by a language model. Any function(text) will do; this one
#' # calls a chat API and asks for one lead per line.
#' askModel <- function(text) {
#'   prompt <- paste(
#'     "This is a scanned identification key. Rewrite it with one lead per",
#'     "line as '<couplet><letter>. <text> .... <destination>'. Do not add,",
#'     "drop or reword leads.\n\n", text
#'   )
#'   response <- httr::POST(
#'     "https://api.example.com/v1/messages",
#'     httr::add_headers(Authorization = paste("Bearer", Sys.getenv("MODEL_API_KEY"))),
#'     body = list(model = "some-model", messages = list(list(role = "user", content = prompt))),
#'     encode = "json"
#'   )
#'   httr::content(response)$content[[1]]$text
#' }
#' key <- keyFromText("scanned-key.txt", llm = askModel)
#' attr(key, "problems")
#' }
#' @export
keyFromText <- function(text, desc = NA, meta = NULL, llm = NULL, strict = FALSE, ...) {
  parsed <- parseTextKey(text, llm = llm, strict = strict, ...)
  problems <- parsed$problems
  if (nrow(parsed$leads) == 0) {
    why <- problems$Message[problems$Kind == "problem"]
    stop("No leads were found in the text. A lead starts with a couplet number or letter, ",
         "e.g. '1a. Leaves compound .... 2'",
         if (length(why)) paste0("\n", paste0("  ", why, collapse = "\n")), call. = FALSE)
  }
  if (length(desc) == 1 && is.na(desc) && !is.na(parsed$title)) desc <- parsed$title

  serious <- problems[problems$Kind == "problem", , drop = FALSE]
  if (isTRUE(strict) && nrow(serious)) {
    stop("The key has ", nrow(serious), " problem(s):\n", txtFormatProblems(serious), call. = FALSE)
  }
  key <- tryCatch(
    keyFromLeads(parsed$leads, desc, meta),
    error = function(e) {
      stop("The key could not be built: ", conditionMessage(e),
           if (nrow(serious)) paste0("\nProblems found while reading it:\n", txtFormatProblems(serious)),
           "\nSee parseTextKey() for the lead table.", call. = FALSE)
    }
  )

  # Anything $validate() finds that the parser did not already report
  found <- key$validate()
  types <- c("not in the key" = "missing_couplet", "names no taxon" = "no_destination",
             "only one lead" = "single_lead", "cannot be reached" = "unreachable", "cycle" = "cycle")
  for (msg in found) {
    type <- types[vapply(names(types), function(p) grepl(p, msg, fixed = TRUE), logical(1))]
    if (length(type) && type[1] %in% problems$Type) next
    problems <- rbind(problems, txtProblemRow(NA_integer_, "", "", "problem", "validate", msg))
  }
  rownames(problems) <- NULL
  serious <- problems[problems$Kind == "problem", , drop = FALSE]
  if (isTRUE(strict) && nrow(serious)) {
    stop("The key has ", nrow(serious), " problem(s):\n", txtFormatProblems(serious), call. = FALSE)
  }

  attr(key, "problems") <- problems
  report <- problems[problems$Kind %in% c("problem", "repair"), , drop = FALSE]
  if (nrow(report)) {
    warning(sprintf(
      "%d problem(s) and %d repair(s) while reading the key; see attr(key, \"problems\"):\n%s",
      sum(report$Kind == "problem"), sum(report$Kind == "repair"), txtFormatProblems(report)
    ), call. = FALSE)
  }
  key
}

#' Parse a key written as plain text into a table of leads
#'
#' The lower-level half of [keyFromText()]: reads the text and returns one
#' row per lead together with everything that looked wrong, without building
#' a key. Use it to see what the parser made of a difficult text, fix the
#' text or the table, and then call [keyFromLeads()].
#'
#' @inheritParams keyFromText
#' @param strict If `TRUE`, stop when anything had to be repaired (see
#'   Details of [keyFromText()]) instead of repairing it. Problems that
#'   cannot be repaired are still returned in `problems`.
#' @param layout `"auto"` works out the layout from the text. `"indented"`
#'   always lets a lead without a destination lead to the couplet printed
#'   under it; `"bracketed"` never does. `"unnumbered"` reads the couplets
#'   from the indentation alone (or, without indentation, from the order of
#'   the leads) and takes no number at a line start for a couplet number.
#' @param skip Optional regular expression; lines that match are left out
#'   (for running heads the parser does not recognise by itself).
#' @return A list of class `textKeyParse` with
#'   * `leads`: data frame with one row per lead: `Statement` (couplet),
#'     `Choice`, `Character` (the text), `Next` (next couplet, or `"-"`),
#'     `Taxon`, `Authority`, `CommonName`, `Page` and `Line` (the line the
#'     lead starts on). Ready for [keyFromLeads()].
#'   * `problems`: data frame with `Line`, `Couplet`, `Lead`, `Kind`
#'     (`"problem"`, `"repair"` or `"note"`), `Type` and `Message`.
#'   * `title`: the first line above the first lead, or `NA`.
#'   * `layout`: `"bracketed"`, `"indented"`, `"paired"` or `"unnumbered"`.
#'   * `text`: the lines that were parsed (the model's answer when `llm`
#'     returned text).
#'
#'   When `llm` is used, `Line` is the line of the source text each lead was
#'   found on (`NA` if it could not be found) and `leads$LlmLine` is the
#'   line or row of the model's answer.
#' @seealso [keyFromText()]
#' @examples
#' # Primes for the second lead, tabs and "go to"
#' p <- parseTextKey(c(
#'   "1.  Shell coiled\tgo to 2",
#'   "1'. Shell of two valves\tBivalvia",
#'   "2.  Shell with a lid\tLittorina, p. 40",
#'   "2'. Shell without a lid\tLymnaea"
#' ))
#' p$leads
#'
#' # A scanned page: what was repaired and what was skipped
#' scan <- system.file("extdata", "textkeys", "meadow-ocr.txt", package = "dimoose")
#' p <- parseTextKey(scan)
#' p
#' p$problems[p$problems$Kind == "repair", c("Line", "Message")]
#'
#' # An indented key without couplet numbers, as in older floras
#' willows <- "
#' Capsule glabrous.
#'     Leaves with close serrations, glaucous beneath.  11. S. melanopsis.
#'     Leaves entire or with distant serrations.
#'         Styles none.  12. S. exigua.
#'         Styles evident; aments dense.  16. S. sessilifolia.
#' Capsule densely pubescent.  17. S. argophylla.
#' "
#' parseTextKey(willows)$leads[, c("Statement", "Choice", "Character", "Next", "Taxon")]
#'
#' # A stand-in for a language model that returns a table
#' fake <- function(text) {
#'   data.frame(
#'     couplet = c(1, 1), lead = c("a", "b"),
#'     text = c("Wings present", "Wings absent"),
#'     destination = c("Pterygota", "Apterygota")
#'   )
#' }
#' parseTextKey("1 Wings present ... Pterygota\n1 Wings absent ... Apterygota", llm = fake)$leads
#' @export
parseTextKey <- function(text, llm = NULL, strict = FALSE,
                         layout = c("auto", "bracketed", "indented", "unnumbered"), skip = NULL) {
  layout <- match.arg(layout)
  if (!is.null(llm) && !is.function(llm)) stop("`llm` must be a function(text) or NULL", call. = FALSE)
  src <- txtReadLines(text)
  if (!is.null(skip)) {
    ok <- is.character(skip) && length(skip) == 1 && !is.na(skip) &&
      !inherits(suppressWarnings(try(grepl(skip, "", perl = TRUE), silent = TRUE)), "try-error")
    if (!ok) stop("`skip` must be one regular expression (a string), e.g. \"^Flora of\"", call. = FALSE)
  }
  res <- if (is.null(llm)) txtParseLines(src, layout, skip) else txtParseLlm(src, llm, layout, skip)
  if (nrow(res$leads) == 0 && !any(res$problems$Kind == "problem")) {
    res$problems <- rbind(
      txtProblemRow(NA_integer_, "", "", "problem", "no_leads", paste(
        "no leads were found: no line starts with a couplet number or letter, and the text is not an",
        "indented key whose leads end in a name")),
      res$problems)
    rownames(res$problems) <- NULL
  }
  repairs <- res$problems[res$problems$Kind == "repair", , drop = FALSE]
  if (isTRUE(strict) && nrow(repairs)) {
    stop("The text needs ", nrow(repairs), " repair(s), and `strict = TRUE`:\n",
         txtFormatProblems(repairs), call. = FALSE)
  }
  res
}

#' @export
print.textKeyParse <- function(x, ...) {
  cat(sprintf("<parsed text key> %d leads in %d couplets, %s layout\n",
    nrow(x$leads), length(unique(x$leads$Statement)), x$layout))
  if (!is.na(x$title)) cat("  ", x$title, "\n", sep = "")
  p <- x$problems
  cat(sprintf("  %d problem(s), %d repair(s), %d note(s)\n",
    sum(p$Kind == "problem"), sum(p$Kind == "repair"), sum(p$Kind == "note")))
  show <- p[p$Kind %in% c("problem", "repair"), , drop = FALSE]
  if (nrow(show)) cat(txtFormatProblems(show, max = 25), "\n", sep = "")
  invisible(x)
}

# ---- reading and cleaning lines ----------------------------------------------

txtReadLines <- function(text) {
  if (inherits(text, "connection")) {
    return(txtSplitLines(readLines(text, warn = FALSE, encoding = "UTF-8")))
  }
  if (!is.character(text) || length(text) == 0) {
    stop("`text` must be a file path, a string or a character vector of lines", call. = FALSE)
  }
  oneLine <- length(text) == 1 && !is.na(text) && !grepl("\n", text, fixed = TRUE) && nchar(text) < 1024
  isPath <- oneLine && file.exists(text) && !dir.exists(text)
  if (oneLine && !isPath && dir.exists(text)) {
    stop("`text` is a folder, not a file: ", text, call. = FALSE)
  }
  if (oneLine && !isPath && grepl("^\\S+\\.(txt|text|md|ocr|csv|tsv)$", text, ignore.case = TRUE)) {
    stop("File not found: ", text, call. = FALSE)
  }
  if (isPath) text <- readLines(text, warn = FALSE, encoding = "UTF-8")
  txtSplitLines(text)
}

# One element per line; a form feed (page break) counts as a blank line
txtSplitLines <- function(text) {
  text <- enc2utf8(as.character(text))
  text[is.na(text)] <- ""
  # a byte order mark, zero-width spaces and soft hyphens are not text
  text <- gsub("[\ufeff\u200b\u00ad]", "", text)
  text <- gsub("\f", "\n\n\n", text, fixed = TRUE)
  unlist(lapply(text, function(s) {
    parts <- strsplit(s, "\r\n|\n|\r")[[1]]
    if (length(parts)) parts else ""
  }), use.names = FALSE)
}

# Typographic variants to plain characters; leading tabs to spaces so that
# indentation can be measured. Tabs inside a line are kept: they separate the
# text from its destination.
txtCleanLines <- function(x) {
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("\u2026", "...", x, fixed = TRUE)
  x <- gsub("[\u00b7\u2022\u2219\u22c5]", ".", x)
  x <- gsub("[\u2032\u2019\u2018\u02b9\u00b4`]", "'", x)
  x <- gsub("\u2033", "''", x, fixed = TRUE)
  lead <- regmatches(x, regexpr("^[ \t]*", x))
  x <- paste0(strrep(" ", nchar(gsub("\t", "        ", lead, fixed = TRUE))), substring(x, nchar(lead) + 1))
  x <- sub("[ \t]+$", "", x)
  txtTightenSpaces(txtPlainLabels(x))
}

# Markup and label styles that are turned into the plain ones before reading:
# Markdown emphasis and tables, labels in parentheses "(1)", and Roman
# numerals "II." for the couplets.
txtPlainLabels <- function(x) {
  # **1a.** Leaves ... *Acer rubrum*
  x <- gsub("**", "", x, fixed = TRUE)
  x <- gsub("(?<![A-Za-z0-9*])\\*([^*\\s][^*]*[^*\\s]|[^*\\s])\\*(?![A-Za-z0-9*])", "\\1", x, perl = TRUE)
  # | 1 | Leaves opposite | 2 |
  row <- grepl("^\\s*\\|.*\\|\\s*$", x)
  if (sum(row) >= 3) {
    rule <- row & grepl("^[\\s|:-]+$", x, perl = TRUE)
    x[rule] <- ""
    cells <- row & !rule
    x[cells] <- gsub("\\s*\\|\\s*", "\t", sub("\\s*\\|\\s*$", "", sub("^\\s*\\|\\s*", "", x[cells])))
  }
  # (1) Leaves ...  ->  1. Leaves ...
  paren <- grepl("^\\s*\\([0-9]{1,3}[a-hA-H]?'{0,2}\\)\\s+[A-Z]", x)
  plain <- grepl("^\\s*[0-9]{1,3}[a-hA-H]?'{0,2}[.)]\\s+[A-Z]", x)
  if (sum(paren) >= 2 && sum(paren) > sum(plain)) {
    x[paren] <- sub("^(\\s*)\\(([0-9]{1,3}[a-hA-H]?'{0,2})\\)", "\\1\\2.", x[paren])
  }
  # II. Leaves ... IV  ->  2. Leaves ... 4
  romanRe <- "^(\\s*)([IVXL]{1,7})([.)])(\\s+\\S.*)$"
  m <- regmatches(x, regexec(romanRe, x))
  has <- lengths(m) > 0
  if (sum(has) >= 3) {
    value <- vapply(m[has], function(g) suppressWarnings(as.integer(utils::as.roman(g[3]))), integer(1))
    arabic <- grepl("^\\s*[0-9]{1,3}[a-hA-H]?[.)]\\s", x)
    # really Roman: II, III, IV, V ... occur, not only the I that a scan makes of 1
    if (!anyNA(value) && sum(value >= 2L) >= 2 && sum(has) > sum(arabic)) {
      rest <- vapply(m[has], function(g) g[5], "")
      end <- regmatches(rest, regexec("^(.*(?:[._][ \t]*){2,}|.*\t|.*\\s{3,})([IVXL]{1,7})\\.?$", rest))
      for (j in which(lengths(end) > 0)) {
        to <- suppressWarnings(as.integer(utils::as.roman(end[[j]][3])))
        if (!is.na(to)) rest[j] <- paste0(end[[j]][2], to)
      }
      x[has] <- paste0(vapply(m[has], function(g) g[2], ""), value, vapply(m[has], function(g) g[4], ""), rest)
    }
  }
  x
}

# Some scans put two or more spaces between all words (justified print read
# by OCR). There a gap only means something when it is clearly wider than the
# usual one: the usual gaps become one space and the wide ones three.
# `attr(, "loose")` says whether that was done.
txtTightenSpaces <- function(x) {
  body <- sub("^ +", "", x)
  runs <- unlist(lapply(gregexpr(" +", body), function(m) if (m[1] > 0) attr(m, "match.length")))
  loose <- length(runs) >= 20 && mean(runs >= 2) > 0.5
  if (loose) {
    usual <- as.integer(names(which.max(table(runs[runs >= 2]))))
    indent <- regmatches(x, regexpr("^ *", x))
    m <- gregexpr(" +", body)
    regmatches(body, m) <- lapply(m, function(g) {
      if (g[1] < 0) return(character())
      len <- attr(g, "match.length")
      # a justified line is stretched as a whole: judge by its narrowest gap
      wide <- 2L * max(usual, if (length(len) >= 3) min(len) else 0L) + 1L
      ifelse(len >= wide, "   ", " ")
    })
    x <- paste0(indent, body)
  }
  attr(x, "loose") <- loose
  x
}

txtDashes <- "-\u2013\u2014\u2212"

# Dot leaders (two or more dots or underscores, possibly spaced) or a tab
txtLeaderRe <- "[ \t]*(?:(?:[._][ \t]*){2,}|\t[ \t]*)"

txtProblemRow <- function(line, couplet, lead, kind, type, message) {
  data.frame(Line = as.integer(line), Couplet = couplet, Lead = lead, Kind = kind,
             Type = type, Message = message, stringsAsFactors = FALSE)
}

txtFormatProblems <- function(problems, max = 15) {
  n <- nrow(problems)
  shown <- utils::head(problems, max)
  where <- ifelse(is.na(shown$Line), "", paste0("line ", shown$Line, ": "))
  out <- paste0("  ", where, shown$Message, ifelse(shown$Kind == "repair", " [repaired]", ""))
  if (n > max) out <- c(out, sprintf("  ... and %d more", n - max))
  paste(out, collapse = "\n")
}

# Collects problems, repairs and notes; `lead` is the index of the lead they
# belong to (0 if none), turned into a label once choices are known.
txtCollector <- function() {
  rows <- list()
  list(
    add = function(line, lead, kind, type, message) {
      rows[[length(rows) + 1]] <<- list(line = line, lead = lead, kind = kind, type = type, message = message)
    },
    get = function() rows
  )
}

# ---- recognising lead labels -------------------------------------------------

# What each line would be if it started a lead. `kind` is "num", "dash",
# "letter" or "".
txtLabelTable <- function(x) {
  n <- length(x)
  out <- data.frame(
    kind = rep("", n), indent = nchar(regmatches(x, regexpr("^ *", x))),
    numRaw = "", k = NA_integer_, ocr = FALSE, strong = FALSE, punct = "",
    letter = "", primes = 0L, backref = "", rest = "", written = "",
    stringsAsFactors = FALSE
  )
  numRe <- paste0(
    "^(\\s*)([0-9]{4}|[0-9lI|Oo]{1,3})",
    "(?:\\s?\\(([a-hA-H])\\)|([a-hA-H])(?![A-Za-z]))?",
    "\\s?('{1,3}|\\*{1,3})?",
    "(?:\\s?\\(\\s*([0-9lIO|]{1,3}(?:\\s*(?:,|;|and|or|&)\\s*[0-9lIO|]{1,3})*)\\s*\\))?",
    "('{1,3})?([.):]{0,2})(?:\\s+(\\S.*))?$"
  )
  m <- regmatches(x, regexec(numRe, x, perl = TRUE))
  for (i in which(lengths(m) > 0)) {
    g <- m[[i]]
    g[is.na(g)] <- ""
    if (!nzchar(g[10])) next
    clean <- chartr("lI|Oo", "11100", g[3])
    if (grepl("^0", clean)) next
    out$kind[i] <- "num"
    out$numRaw[i] <- g[3]
    out$k[i] <- as.integer(clean)
    out$ocr[i] <- clean != g[3]
    out$letter[i] <- tolower(paste0(g[4], g[5]))
    out$primes[i] <- nchar(g[6]) + nchar(g[8])
    out$backref[i] <- g[7]
    out$punct[i] <- g[9]
    out$strong[i] <- any(nzchar(g[4:9]))
    out$rest[i] <- sub("^[.,;:*\\s]+(?=[A-Za-z(])", "", g[10], perl = TRUE)
    if (!nzchar(out$rest[i])) out$rest[i] <- g[10]
  }
  dashRe <- paste0("^(\\s*)([", txtDashes, "+]{1,2})\\s+(\\S.*)$")
  m <- regmatches(x, regexec(dashRe, x, perl = TRUE))
  for (i in which(lengths(m) > 0 & out$kind == "")) {
    out$kind[i] <- "dash"
    out$rest[i] <- m[[i]][4]
  }
  # "A." / "AA.", and in lower case "a." / "aa." (Jordan & Evermann)
  m <- regmatches(x, regexec("^(\\s*)([A-Za-z])(\\2*)\\s?[.)]\\s+(\\S.*)$", x, perl = TRUE))
  for (i in which(lengths(m) > 0 & out$kind == "")) {
    out$kind[i] <- "letter"
    out$numRaw[i] <- m[[i]][3]
    out$k[i] <- match(toupper(m[[i]][3]), LETTERS)
    out$primes[i] <- nchar(m[[i]][4])
    out$strong[i] <- TRUE
    out$rest[i] <- m[[i]][5]
  }
  trimmed <- trimws(x)
  has <- out$kind != ""
  out$written[has] <- trimws(substring(trimmed[has], 1, nchar(trimmed[has]) - nchar(out$rest[has])))
  out
}

# A page or list reference at the end of a lead: "(Page 76)", ", p. 25."
txtPageRefRe <- "[,;]?\\s*\\(?\\s*(?:pp?\\.|pg\\.?|pag[a-z])\\s*([0-9]{1,4})\\s*\\)?\\.?$"
# A number in parentheses at the end: "(7)." A page or list number after a
# name, the next couplet after plain text.
txtParenNumRe <- "\\s*\\(\\s*([0-9]{1,4})[^\\s()0-9]?\\s*\\)?[.,]?$"

# A name and its page with only a comma between them, as many older keys
# end a lead: "Rhyphidae, 157." A scan may garble the page ("Tipulidae, Si."),
# which is accepted after a family name only.
txtNamePageRe <- paste0(
  "(?<![A-Za-z])([A-Z][A-Za-z]{3,})\\s?,\\s+(?:pt\\.\\s+)?",
  "([0-9]{1,4}|[0-9lIOoSsBZin|]{1,3})\\.?$")

txtNamePage <- function(s) {
  m <- regmatches(s, regexec(paste0("^(.*?)\\s*", txtNamePageRe), s, perl = TRUE))[[1]]
  if (!length(m) || m[3] %in% txtCommonWords) return(NULL)
  garbled <- !grepl("^[0-9]+$", m[4])
  if (garbled && !grepl("(?:id[a-z]{1,2}|ace[a-z]{1,2}|in[a-z]e)$", m[3], ignore.case = TRUE, perl = TRUE)) return(NULL)
  list(text = trimws(m[2]), name = m[3], page = if (grepl("^[0-9]+$", m[4])) m[4] else "", written = m[4])
}

# Does this lead already have its destination? Decides whether text after a
# blank line still belongs to it. "leaders" is certain; "weak" rests on a wide
# gap or a trailing number, which ordinary text can have too.
txtCompleteness <- function(parts) {
  last <- parts[length(parts)]
  after <- sub(paste0("^.*", txtLeaderRe), "", parts, perl = TRUE)
  hasLeader <- grepl(txtLeaderRe, parts, perl = TRUE)
  if (any(hasLeader & nzchar(trimws(after)))) return("leaders")
  if (grepl(paste0("[a-z][", txtDashes, "]$"), last, perl = TRUE)) return("open")
  weak <- grepl("\\S\\s{3,}\\S", last) || grepl("\\s[0-9]{1,3}\\.?$", last) ||
    grepl("\\D\\s+(?:[\u2014\u2013\u2192\u21d2]|-{1,2}>|--)\\s+.*[A-Z]", last, perl = TRUE) ||
    grepl(txtPageRefRe, last, perl = TRUE, ignore.case = TRUE) || grepl(txtParenNumRe, last, perl = TRUE) ||
    (grepl(",", last, fixed = TRUE) && !is.null(txtNamePage(last)))
  # "... lobe-like Amoeba proteus Leidy 1878." : a name closes the lead
  if (!weak && grepl("[a-z0-9]\\.$", last) && grepl("(?:[A-Z][a-z]+|[.;:,] [A-Z]\\.) [a-z]{3,}", last, perl = TRUE)) {
    weak <- !is.null(txtTrailingTaxon(last))
  }
  if (weak) "weak" else "open"
}

txtComplete <- function(parts) txtCompleteness(parts) != "open"

txtTitleWords <- function(s) {
  words <- strsplit(gsub("[^A-Za-z ]", " ", s), " +")[[1]]
  words <- words[nchar(words) >= 4]
  if (length(words) > 0 && all(grepl("^[A-Z]", words))) length(words) else 0L
}

txtTitleCase <- function(s) txtTitleWords(s) > 0

# A label so garbled that no number can be read from it ("V0." for 10, "IB."
# for 12, "0." for 6): one to three characters, a full stop, then a capital.
txtJunkLabel <- function(x) {
  m <- regmatches(x, regexec("^\\s*([0-9A-Za-z|!]{1,3})\\.\\s+[^A-Za-z0-9(]*([A-Z(].*)$", x, perl = TRUE))
  ok <- lengths(m) > 0
  token <- rest <- rep("", length(x))
  token[ok] <- vapply(m[ok], function(g) g[2], "")
  rest[ok] <- vapply(m[ok], function(g) g[3], "")
  looksLikeDigits <- grepl("[0-9]", token) | grepl("^[lI|!OoSsBZzgqiTtDQ]+$", token)
  # "AA." and "BB." are section letters, not numbers
  ok <- ok & looksLikeDigits & !grepl("^([A-HJ-NP-Z])\\1+$", token)
  list(is = ok, token = ifelse(ok, token, ""), rest = ifelse(ok, rest, ""))
}

# ---- pass 1: lines to leads --------------------------------------------------

# `implicit`: the second lead of each couplet has no label of its own and
# simply starts a new paragraph (common in older entomological keys).
txtScan <- function(x, skip, notes, implicit = FALSE) {
  n <- length(x)
  lab <- txtLabelTable(x)
  junk <- txtJunkLabel(x)
  blank <- !nzchar(trimws(x))
  roman <- paste0("^\\s*[\\[(", txtDashes, "]\\s*[ivxlc]{1,7}\\s*[\\])", txtDashes, "]\\s*$")
  pageNum <- grepl(paste0(
    "^\\s*[\\[(]?\\s*(?:[", txtDashes, "]\\s*)?(?:(?:page|pg\\.?|p\\.)\\s*)?[0-9]{1,4}\\s*(?:[",
    txtDashes, "]\\s*)?[\\])]?\\s*$"), x, ignore.case = TRUE, perl = TRUE) |
    grepl(roman, x, ignore.case = TRUE, perl = TRUE) |
    # a signature mark and the page number at the foot of a page: "(8)  65"
    grepl("^\\s*\\(\\s*[0-9]{1,2}\\s*\\)\\s+[0-9]{1,4}\\s*$", x)
  # a footnote: "* Chionea, a wingless tipulid, has ..."
  footnote <- grepl("^\\s*(?:[*\u2020\u2021\u00a7]+|\\([*\u2020]\\))\\s*[A-Za-z]", x, perl = TRUE)
  # the end of a lead: dot leaders and a number or name, or a name and its page
  endsLikeLead <- grepl(paste0(txtLeaderRe, "(?:[0-9]{1,3}|[A-Z][a-z]{3,}[a-z ,.0-9]*)\\.?$"), x, perl = TRUE) |
    (grepl(txtNamePageRe, x, perl = TRUE) & !vapply(x, function(s) is.null(txtNamePage(s)), logical(1), USE.NAMES = FALSE))
  digitsOnly <- grepl("^\\s*[0-9]{1,3}\\.?\\s*$", x)
  letterCount <- nchar(gsub("[^A-Z]", "", x))
  caps <- !grepl("[a-z]", x) & letterCount >= 4
  capsWords <- lengths(regmatches(x, gregexpr("[A-Z]{2,}", x)))
  startNum <- grepl("^\\s*[0-9]{1,4}\\s{3,}\\S", x)
  endNum <- grepl("\\S\\s{3,}[0-9]{1,4}\\s*$", x)
  startNumAny <- grepl("^\\W*[0-9]{1,4}\\s+\\S", x)
  endNumAny <- grepl("\\S[.,]?\\s+[0-9]{1,4}\\s*$", x)
  hasLeaders <- grepl(txtLeaderRe, x, perl = TRUE)
  # a whole lead on one line: capitalised text, dot leaders, a destination
  ownLeaders <- grepl(paste0("^\\s*[A-Z][^.]*[a-z)][^.]*(?:[._][ \t]*){3,}\\s*(?:[0-9]{1,3}|[A-Z][A-Za-z]{2,}.*)$"), x, perl = TRUE)
  # "Trees of the Northern United States 23", "188 SALICACEAE"
  headWords <- vapply(x, function(s) {
    txtTitleWords(sub("[.,]?\\s+[0-9]{1,4}\\s*$", "", sub("^\\W*[0-9]{1,4}\\s+", "", s)))
  }, integer(1), USE.NAMES = FALSE)
  skipped <- if (is.null(skip)) rep(FALSE, n) else grepl(skip, x, perl = TRUE) & !blank
  nameRe <- "^\\s*(?:[A-Z][A-Za-z]{4,}(?:\\s+[A-Z]{5,})?|[A-Z][a-z]{3,}(?:\\s+[a-z]{3,})?)\\.?"
  nameLine <- grepl(paste0(
    "^\\s*[A-Z][a-z]{3,}(?:\\s+(?:[A-Z(&][A-Za-z.&)]*|and|et|ex))*\\.?(?:", txtParenNumRe, ")?$"), x, perl = TRUE) &
    !sub("^\\s*([A-Za-z]+).*$", "\\1", x) %in% txtCommonWords
  destLine <- grepl(paste0(nameRe, txtPageRefRe), x, perl = TRUE, ignore.case = FALSE) |
    grepl(paste0(nameRe, "\\s*\\(\\s*(?:[Pp]ag[a-z]|[Pp]\\.)\\s*[0-9]{1,4}\\s*\\)\\.?$"), x, perl = TRUE) |
    grepl(paste0(nameRe, "\\s*\\(\\s*[0-9]{1,4}[^\\s()0-9]?\\s*\\)[.,]?$"), x, perl = TRUE)

  # Numbers or letters? Bare numbers ("1  Leaves ...") or punctuated ones?
  usable <- !blank & !skipped
  nStrong <- sum(lab$kind == "num" & lab$strong & !lab$ocr & usable)
  nBare <- sum(lab$kind == "num" & !lab$strong & !lab$ocr & grepl("^[A-Z]", lab$rest) & usable)
  nLetter <- sum(lab$kind == "letter" & usable)
  scheme <- if (nLetter > nStrong + nBare) "letter" else "number"
  bareScheme <- nBare > nStrong

  # the number on the next punctuated label below each line: a jump in the
  # numbering is believed when the numbering goes on from there
  strongAt <- which(lab$kind == "num" & lab$strong & !lab$ocr & usable)
  nextStrong <- function(i) {
    later <- strongAt[strongAt > i]
    if (length(later)) lab$k[later[1]] else NA_integer_
  }
  loneLabel <- grepl("^\\s*[0-9lI|]{1,3}\\s?\\(\\s*[0-9lI|]{1,3}\\s*\\)\\s*$", x) |
    grepl("^\\s*[0-9]\\s[0-9]\\s?\\(\\s*[0-9]{1,3}\\s*\\)\\s*$", x) |
    grepl("^\\s*[0-9]{1,3}[a-h]'?[.)]?\\s*$", x)
  figure <- grepl("^\\s*(?:FIG|Fig|Fie|PLATE|Plate)S?\\.?\\s*[0-9]", x, perl = TRUE)

  leads <- list()
  count <- integer()          # leads seen so far, by couplet
  seen <- character()         # "couplet/primes" of letter-scheme labels
  maxSeen <- 0L
  gap <- TRUE
  title <- NA_character_
  preamble <- integer()
  strays <- 0L                # unlabelled paragraphs after a finished first lead
  inFootnote <- FALSE
  # Text passed over in a key whose second leads have no label: if it ends
  # like a lead, a third lead of the couplet may have been lost
  passedOver <- function(i, cur) {
    if (!implicit || !endsLikeLead[i]) return(invisible())
    notes$add(i, 0L, "problem", "unlabelled_lead", sprintf(
      "the text passed over above this line ends like a lead ('%s'); couplet %s may have another lead that was not read",
      substr(trimws(x[i]), 1, 60), leads[[cur]]$couplet))
  }

  startLead <- function(i, couplet, k, kind, rest = lab$rest[i]) {
    leads[[length(leads) + 1]] <<- list(
      couplet = couplet, k = k, letter = if (kind == "num") lab$letter[i] else "",
      primes = if (kind %in% c("num", "letter")) lab$primes[i] else 0L,
      backref = if (kind == "num") lab$backref[i] else "", indent = lab$indent[i],
      line = i, parts = rest, kind = kind
    )
    count[couplet] <<- if (is.na(count[couplet])) 1L else count[couplet] + 1L
    maxSeen <<- max(maxSeen, k)
    gap <<- FALSE
  }

  for (i in seq_len(n)) {
    if (blank[i]) { gap <- TRUE; inFootnote <- FALSE; next }
    if (skipped[i]) {
      notes$add(i, 0L, "note", "skipped", "skipped: matches `skip`")
      gap <- TRUE
      next
    }
    if (length(leads) > 0 && ((gap && footnote[i]) || inFootnote)) {
      notes$add(i, 0L, "note", "skipped", sprintf("skipped a footnote: '%s'", substr(trimws(x[i]), 1, 60)))
      inFootnote <- TRUE
      next
    }
    cur <- length(leads)
    state <- if (cur > 0) txtCompleteness(leads[[cur]]$parts) else "open"
    if (cur > 0 && state == "open" && isTRUE(leads[[cur]]$closed)) state <- "weak"
    open <- cur > 0 && state == "open"
    kind <- lab$kind[i]
    header <- caps[i] && (startNum[i] || endNum[i] || ((startNumAny[i] || endNumAny[i]) && (gap || !open)))

    # A lead label?
    if (scheme == "number" && kind == "num" && !header) {
      k <- lab$k[i]
      id <- as.character(k)
      curK <- if (cur > 0) leads[[cur]]$k else 0L
      expected <- k == curK || k == maxSeen + 1L || (!is.na(count[id]) && count[id] == 1L)
      capital <- grepl("^[A-Z(]", lab$rest[i])
      if (lab$ocr[i]) {
        if ((nzchar(lab$punct[i]) || (capital && !open && !nzchar(lab$letter[i]))) && expected) {
          notes$add(i, cur + 1L, "repair", "label",
            sprintf("read the label '%s' as couplet %d", lab$written[i], k))
          startLead(i, id, k, "num")
          next
        }
      } else if (k > 999L && !expected) {
        # a year at the start of a line, not couplet 1913
      } else if (lab$strong[i]) {
        # "3. spines" in the middle of an unfinished lead is wrapped text
        wrapped <- open && !gap && !expected && grepl("^[a-z]", lab$rest[i])
        # "10." where the second lead of couplet 19 is due: one digit misread
        if (!expected && cur > 0 && k < maxSeen && count[leads[[cur]]$couplet] == 1L && state != "open" &&
            nchar(k) == nchar(curK) && sum(strsplit(as.character(k), "")[[1]] != strsplit(as.character(curK), "")[[1]]) == 1L &&
            !identical(nextStrong(i), k)) {
          notes$add(i, cur + 1L, "repair", "label", sprintf(
            "read the label '%s' as couplet %d (one digit off, and that couplet still lacks its second lead)",
            lab$written[i], curK))
          startLead(i, as.character(curK), curK, "num")
          next
        }
        jump <- maxSeen > 0L && k > maxSeen + 5L
        if (jump && k <= maxSeen + 60L && isTRUE(nextStrong(i) %in% c(k, k + 1L))) {
          notes$add(i, cur + 1L, "problem", "numbers_jump", sprintf(
            "the couplet numbers jump from %d to %d; the leads in between were not found", maxSeen, k))
          jump <- FALSE
        }
        if (!wrapped && !jump) { startLead(i, id, k, "num"); next }
      } else if (capital && bareScheme) {
        runningHead <- gap && startNum[i] && txtTitleCase(lab$rest[i]) && !grepl(txtLeaderRe, lab$rest[i], perl = TRUE)
        if (k <= maxSeen + 1L && !(runningHead && !expected)) { startLead(i, id, k, "num"); next }
      } else if (capital && expected && !open) {
        notes$add(i, cur + 1L, "repair", "label",
          sprintf("read '%s' without a full stop as the label of couplet %d", lab$written[i], k))
        startLead(i, id, k, "num")
        next
      }
    } else if (kind == "dash" && cur > 0 && !pageNum[i]) {
      target <- cur
      for (j in rev(seq_len(cur))) {
        if (leads[[j]]$indent == lab$indent[i]) { target <- j; break }
      }
      id <- leads[[target]]$couplet
      dashed <- any(vapply(leads, function(l) l$couplet == id && l$kind == "dash", logical(1)))
      if (count[id] == 1L || dashed) { startLead(i, id, leads[[target]]$k, "dash"); next }
    } else if (scheme == "letter" && kind == "letter") {
      key <- paste(lab$numRaw[i], lab$primes[i])
      # "B." a second time is the second lead of B (Gray's Manual), as long
      # as B is the couplet being read and has only one lead so far
      again <- key %in% seen && cur > 0 && leads[[cur]]$couplet == lab$numRaw[i] && count[lab$numRaw[i]] == 1L &&
        (gap || !open)
      if (lab$k[i] <= maxSeen + 1L && (!key %in% seen || again)) {
        seen <- c(seen, key)
        startLead(i, lab$numRaw[i], lab$k[i], "letter")
        next
      }
    }

    # In a lettered key, one or two letters and a stop (or a dash the scan made
    # of it) before a capital, where no known label fits: "Jf." for "f.",
    # "g-" for "g.", "t." for "i.". Read as the lead that is due there, if the
    # lead above is finished; reported either way.
    if (scheme == "letter" && cur > 0 && grepl("^\\s*[A-Za-z]{1,2}\\s?[.)-]\\s+[A-Z]", x[i]) && !pageNum[i] && !header) {
      token <- sub("^\\s*([A-Za-z]{1,2})\\s?[.)-].*$", "\\1", x[i])
      rest <- sub("^\\s*[A-Za-z]{1,2}\\s?[.)-]\\s+", "", x[i])
      last <- leads[[cur]]$parts[length(leads[[cur]]$parts)]
      finished <- state != "open" || grepl("[a-z)]\\.$", last)
      curId <- leads[[cur]]$couplet
      lower <- grepl("^[a-z]", curId)
      target <- NULL
      if (finished && state != "open" && count[curId] == 1L && grepl(curId, token, ignore.case = TRUE)) {
        target <- list(id = curId, k = leads[[cur]]$k, primes = 1L)
      } else if (finished && state == "open" && maxSeen < 26L) {
        # the lead above opens a couplet: this is its first lead
        id <- if (lower) letters[maxSeen + 1L] else LETTERS[maxSeen + 1L]
        target <- list(id = id, k = maxSeen + 1L, primes = 0L)
      } else if (finished && state != "open") {
        # the second lead of the nearest couplet above that still has one lead
        waiting <- names(count)[count == 1L]
        waiting <- waiting[waiting != curId]
        hit <- waiting[vapply(waiting, function(w) grepl(w, token, ignore.case = TRUE), logical(1))]
        if (length(hit)) target <- list(id = hit[length(hit)], k = match(toupper(hit[length(hit)]), LETTERS), primes = 1L)
      }
      if (!is.null(target)) {
        notes$add(i, cur + 1L, "repair", "label", sprintf(
          "read the label '%s' as %s%s (not a label of this key as it stands, but that is the lead due here)",
          token, target$id, if (target$primes > 0) target$id else ""))
        startLead(i, target$id, target$k, "junk", rest)
        leads[[length(leads)]]$primes <- target$primes
        seen <- c(seen, paste(target$id, target$primes))
        next
      }
      notes$add(i, 0L, "problem", "label_unread", sprintf(
        "'%s' at the start of line %d looks like a lead label that could not be placed; the line was read as part of the lead above",
        token, i))
    }

    # A label too garbled to read a number from, at the start of a paragraph
    # or after a finished lead: the second lead of the couplet that still has
    # only one, else the couplet that comes next.
    if (scheme == "number" && !bareScheme && junk$is[i] && cur > 0 && (gap || !open) &&
        !header && !pageNum[i]) {
      curId <- leads[[cur]]$couplet
      target <- NA_integer_
      if (count[curId] == 1L && state != "open") {
        target <- leads[[cur]]$k
      } else if (count[curId] >= 2L && state != "open" && leads[[cur]]$k == maxSeen &&
                 nchar(junk$token[i]) == nchar(maxSeen + 1L)) {
        target <- maxSeen + 1L
      }
      if (!is.na(target)) {
        notes$add(i, cur + 1L, "repair", "label",
          sprintf("read the label '%s.' as couplet %d (it is not a number, but that is the couplet due here)",
                  junk$token[i], target))
        startLead(i, as.character(target), target, "junk", junk$rest[i])
        next
      }
    }

    # A label that stands alone: its text is somewhere else and cannot be
    # put back
    if (loneLabel[i] && scheme == "number") {
      notes$add(i, 0L, "problem", "lone_label", sprintf(
        "the label '%s' stands alone on its line; the text of that lead was not found", trimws(x[i])))
      gap <- TRUE
      next
    }
    if (figure[i] && cur > 0) {
      notes$add(i, 0L, "note", "skipped", sprintf("skipped a figure caption: '%s'", substr(trimws(x[i]), 1, 60)))
      if (state == "open") leads[[cur]]$closed <- TRUE
      gap <- TRUE
      next
    }

    # Page numbers and running heads
    if (pageNum[i] && !(digitsOnly[i] && cur > 0 && !gap && open)) {
      notes$add(i, 0L, "note", "skipped", sprintf("skipped a page number: '%s'", trimws(x[i])))
      gap <- TRUE
      next
    }
    numberedHead <- !hasLeaders[i] && (startNumAny[i] || endNumAny[i]) &&
      (headWords[i] >= 3L || (headWords[i] >= 2L && !open))
    # one capitalised word after an unfinished lead is its destination
    capsHead <- caps[i] && !(open && capsWords[i] < 2L)
    if (header || (gap && cur > 0 && (capsHead || numberedHead))) {
      notes$add(i, 0L, "note", "skipped", sprintf("skipped a running head: '%s'", trimws(x[i])))
      gap <- TRUE
      next
    }

    # Text before the first lead, stray text, or the rest of a wrapped lead
    if (cur == 0) {
      preamble <- c(preamble, i)
      next
    }
    # "1. Flowers red ... 2" and under it "Flowers white ... 3": the lead
    # above has its destination after dot leaders, and this line has dot
    # leaders and a destination of its own, so it is a further lead
    if (!gap && state == "leaders" && ownLeaders[i] && kind == "" && !pageNum[i] &&
        leads[[cur]]$kind %in% c("num", "letter", "implicit") && !isTRUE(leads[[cur]]$sealed)) {
      notes$add(i, cur + 1L, "note", "layout", sprintf(
        "no label; read as a further lead of couplet %s because the lead above it is complete", leads[[cur]]$couplet))
      startLead(i, leads[[cur]]$couplet, leads[[cur]]$k, "implicit", sub("^[^A-Za-z0-9(]+", "", trimws(x[i])))
      next
    }
    if (implicit && !gap && !open && !destLine[i] && count[leads[[cur]]$couplet] == 1L &&
        leads[[cur]]$kind == "num" && grepl("^[^A-Za-z0-9]{0,2}[A-Z]", trimws(x[i])) && !isTRUE(leads[[cur]]$sealed)) {
      startLead(i, leads[[cur]]$couplet, leads[[cur]]$k, "implicit", sub("^[^A-Za-z0-9(]+", "", trimws(x[i])))
      next
    }
    if (gap && !open) {
      line <- trimws(x[i])
      curId <- leads[[cur]]$couplet
      sealed <- isTRUE(leads[[cur]]$sealed)
      # a name with its page on a line of its own ("ORTHOPTERA   (Page 13)"),
      # or the end of the lead with its dot leaders ("Family Amoebidae . . 5")
      ending <- destLine[i] || (nameLine[i] && !isTRUE(leads[[cur]]$closed)) || (!implicit && hasLeaders[i] && grepl(paste0(txtLeaderRe, "\\S"), x[i], perl = TRUE) &&
        !isTRUE(leads[[cur]]$closed))
      if (state == "weak" && ending && !sealed) {
        leads[[cur]]$parts <- c(leads[[cur]]$parts, line)
        if (nameLine[i]) leads[[cur]]$closed <- TRUE
        gap <- FALSE
        next
      }
      paragraph <- grepl("^[^A-Za-z0-9]{0,2}[A-Z]", line)
      if (paragraph && count[curId] == 1L && scheme == "number" && leads[[cur]]$kind == "num") {
        strays <- strays + 1L
        if (implicit) {
          startLead(i, curId, leads[[cur]]$k, "implicit", sub("^[^A-Za-z0-9(]+", "", line))
          next
        }
      }
      # a sentence that goes on in lower case after a blank line
      if (state == "weak" && grepl("^[a-z]", line) && !sealed) {
        leads[[cur]]$parts <- c(leads[[cur]]$parts, line)
        gap <- FALSE
        next
      }
      # text that ends like a lead ("Leaves alternate. 9.") is a lead that
      # lost its label
      leadLike <- grepl("[a-z)][.,]\\s+[0-9]{1,3}\\.?$", line) ||
        grepl(paste0("[a-z)]\\.\\s+[A-Z][a-z]{3,}\\.?", txtParenNumRe), line, perl = TRUE) ||
        (hasLeaders[i] && grepl(paste0(txtLeaderRe, "(?:[0-9]{1,3}|[A-Z][a-z]+)\\.?$"), line, perl = TRUE))
      if (leadLike && !implicit) {
        notes$add(i, 0L, "problem", "unlabelled_lead", sprintf(
          "skipped text that looks like a lead without a label: '%s'", substr(line, 1, 60)))
      } else {
        notes$add(i, 0L, "note", "skipped",
          sprintf("skipped text between leads: '%s'", substr(line, 1, 60)))
      }
      # the rest of that paragraph is not part of the lead either
      leads[[cur]]$sealed <- TRUE
      passedOver(i, cur)
      next
    }
    if (isTRUE(leads[[cur]]$sealed)) {
      notes$add(i, 0L, "note", "skipped",
        sprintf("skipped text between leads: '%s'", substr(trimws(x[i]), 1, 60)))
      passedOver(i, cur)
      next
    }
    leads[[cur]]$parts <- c(leads[[cur]]$parts, trimws(x[i]))
    # a paragraph that is only a name ("Dinamoeba Leidy.") ends the lead
    if (gap && nameLine[i]) leads[[cur]]$closed <- TRUE
    gap <- FALSE
  }
  # The title: the last line above the key that says "key" (with the lines of
  # its paragraph), else the first line
  preamble <- preamble[!pageNum[preamble]]
  if (length(preamble)) {
    named <- preamble[grepl("\\bkey\\b", x[preamble], ignore.case = TRUE) & nchar(trimws(x[preamble])) <= 150]
    if (length(named)) {
      from <- named[length(named)]
      to <- from
      while (to < n && (to + 1L) %in% preamble && to - from < 2L) to <- to + 1L
      title <- gsub("\\s+", " ", paste(trimws(x[from:to]), collapse = " "))
      if (nchar(title) > 150) title <- gsub("\\s+", " ", trimws(x[from]))
    } else if (nchar(trimws(x[preamble[1]])) <= 150) {
      title <- gsub("\\s+", " ", trimws(x[preamble[1]]))
    }
  }
  if (length(preamble) > 1) {
    notes$add(preamble[2], 0L, "note", "skipped",
      sprintf("%d line(s) above the first lead were not read as leads", length(preamble) - 1L))
  }
  list(leads = leads, scheme = scheme, title = title, strays = strays)
}

# ---- pass 2: text and destination of each lead -------------------------------

# Join wrapped lines; a word hyphenated at a line end is put back together.
txtJoin <- function(parts) {
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return(list(text = "", joined = 0L))
  out <- parts[1]
  joined <- 0L
  for (p in parts[-1]) {
    if (grepl("[a-z]-$", out) && grepl("^[a-z]", p)) {
      out <- paste0(sub("-$", "", out), p)
      joined <- joined + 1L
    } else {
      out <- paste(out, p)
    }
  }
  list(text = out, joined = joined)
}

# Take a page or list reference off the end of a string
txtTakePage <- function(s) {
  m <- regmatches(s, regexec(paste0("^(.*?)", txtPageRefRe), s, perl = TRUE, ignore.case = TRUE))[[1]]
  if (length(m) && nzchar(trimws(m[2]))) list(text = trimws(m[2]), page = m[3]) else list(text = s, page = "")
}

# Split a lead's lines into text and destination: at the last dot leaders or
# tab; failing that at a colon before a number ("lobed: 5"), a spaced dash
# ("large tree -- Quercus alba") or the last wide gap.
txtSplitLead <- function(parts) {
  hasLeader <- grepl(txtLeaderRe, parts, perl = TRUE)
  n <- length(parts)
  if (any(hasLeader)) {
    j <- max(which(hasLeader))
    m <- gregexpr(txtLeaderRe, parts[j], perl = TRUE)[[1]]
    start <- m[length(m)]
    len <- attr(m, "match.length")[length(m)]
    before <- substr(parts[j], 1, start - 1)
    after <- substring(parts[j], start + len)
    text <- txtJoin(c(parts[seq_len(j - 1)], before))
    dest <- txtJoin(c(after, parts[-seq_len(j)]))
    if (nzchar(trimws(dest$text)) || j == n) {
      return(list(text = text$text, dest = dest$text, sep = "leaders", page = "", joined = text$joined + dest$joined))
    }
  }
  whole <- txtJoin(parts)
  s <- whole$text
  out <- function(text, dest, sep, page = "") {
    list(text = trimws(text), dest = trimws(dest), sep = sep, page = page, joined = whole$joined)
  }
  m <- regmatches(s, regexec(
    "^(.*[^\\s:]):\\s*((?:(?:[Gg]o\\s*to|[Ss]ee)\\s+)?(?:(?:couplet|lead|step)\\s*)?[0-9lIO|]{1,3})\\.?$", s, perl = TRUE))[[1]]
  if (length(m)) return(out(m[2], m[3], "mark"))
  # "... twigs glabrous. > 3": an arrow before the next couplet
  m <- regmatches(s, regexec("^(.*[a-z).;])\\s+(?:>|\u203a|=>)\\s*([0-9]{1,4})\\.?$", s, perl = TRUE))[[1]]
  if (length(m)) return(out(m[2], m[3], "mark"))
  m <- regmatches(s, regexec(paste0(
    "^(.*[^\\s0-9])\\s+(?:[\u2014\u2013\u2192\u21d2]|-{1,2}>|--)\\s+((?:[0-9]{1,3}|[^\u2014\u2013]{0,70}[A-Z][^\u2014\u2013]{0,70}))$"),
    s, perl = TRUE))[[1]]
  if (length(m)) return(out(m[2], m[3], "mark"))

  page <- txtTakePage(s)
  s <- page$text
  paren <- regmatches(s, regexec(paste0("^(.*\\S)", txtParenNumRe), s, perl = TRUE))[[1]]
  if (length(paren)) s <- paren[2]
  m <- regmatches(s, regexec("^(.*\\S)\\s{3,}(\\S.{0,79})$", s))[[1]]
  if (!length(m)) m <- regmatches(s, regexec("^(.*\\S)\\s{2,}([0-9]{1,3}\\.?)$", s))[[1]]
  if (length(m)) {
    # "... leaves.   Pinus.   (7)." : the number in parentheses is a page or
    # list number; after a bare number it would be noise
    return(out(m[2], m[3], "gap", if (length(paren)) paren[3] else page$page))
  }
  if (length(paren)) {
    named <- txtTrailingTaxon(s, bare = TRUE)
    if (!is.null(named)) return(out(named$text, named$dest, "lost", paren[3]))
    return(out(s, paren[3], "paren", page$page))
  }
  # "... discal cell present. Rhyphidae, 157." : a name and its page
  named <- txtNamePage(s)
  if (!is.null(named) && nzchar(named$text)) return(out(named$text, named$name, "lost", named$page))
  out(s, "", "none", page$page)
}

# "... go to 5" / "... see 5" at the end of a lead with no leaders
txtTrailingGoto <- function(text, scheme) {
  target <- if (scheme == "letter") "([A-Z])" else "([0-9lIO|]{1,3})"
  re <- paste0("^(.*?)[\\s.,;:(\\[\u2014\u2013>-]+(?:[Gg]o\\s*to|[Ss]ee|[Pp]roceed to|[Cc]ontinue to)\\s+",
               "(?:(?:couplet|lead|step|no\\.?)\\s*)?", target, "[)\\]]?\\.?$")
  m <- regmatches(text, regexec(re, text, perl = TRUE))[[1]]
  if (length(m)) list(text = trimws(m[2]), dest = m[3]) else NULL
}

# A lead that ends in a bare number, e.g. "Leaves compound 4". `afterStop`
# says whether the number follows a full stop, comma or the like ("... each
# year. 11."), which is how keys without dot leaders set off the destination.
txtTrailingNumber <- function(text) {
  m <- regmatches(text, regexec("^(.*\\S)\\s+([0-9]{1,3})\\.?$", text))[[1]]
  if (!length(m)) return(NULL)
  afterStop <- grepl("[.,;:)]$", m[2])
  before <- sub("[.,;:]+$", "", m[2])
  prev <- tolower(sub("^.*\\s", "", before))
  notDestination <- c("to", "or", "than", "of", "about", "usually", "mostly", "and", "with", "x",
                      "least", "most", "in", "by", "ca", "ca.", "over", "under", "exceeding")
  if (prev %in% notDestination || grepl(paste0("[0-9", txtDashes, "\u00d7]$"), prev, perl = TRUE)) return(NULL)
  list(text = trimws(if (grepl("[.)]$", m[2])) m[2] else before), dest = m[3], afterStop = afterStop)
}

# A name set in capitals (an order, a family); a scan may get one letter of
# it in lower case: "LEPmOPTERA"
txtCapsNameRe <- "(?:[A-Z]{5,}|[A-Z]{2,}[a-z][A-Z]{2,})(?<=[A-Za-z]{5})"

# Words that start a clause of a lead, not a genus
txtCommonWords <- c(
  "Leaves", "Leaf", "Leaflets", "Flowers", "Flower", "Fruit", "Fruits", "Stems", "Stem", "Plants",
  "Plant", "Petals", "Sepals", "Bark", "Twigs", "Buds", "Needles", "Cones", "Seeds", "Capsule",
  "Body", "Fins", "Wings", "Legs", "Head", "Tail", "Shell", "Not", "Without", "With", "Both", "All",
  "Some", "Most", "Each", "Never", "Usually", "Often", "Trees", "Tree", "Shrubs", "Shrub", "Herbs",
  "Blades", "Margins", "Spines", "Scales", "Hairs", "Roots", "Branches", "Inflorescence",
  "Spikelets", "Achene", "Achenes", "Pods", "Berries", "Catkins", "Male", "Female", "Upper",
  "Lower", "Mouth", "Eyes", "Antennae", "Abdomen", "Thorax", "Color", "Colour", "Length", "Size"
)

# A lead that ends in a scientific name with nothing in front of it, e.g.
# "Leaves simple Acer glabrum Torr.", "... leaves flat. Abies." or
# "... Crickets ORTHOPTERA"
txtTrailingTaxon <- function(text, bare = FALSE) {
  # `bare`: a list number followed, so one capitalised word after a sentence
  # is a name even without a full stop of its own ("... ranks. Taxodium (2).")
  if (bare) {
    m <- regmatches(text, regexec("^(.*[a-z)]\\.)\\s+([A-Z][a-z]{3,})\\.?$", text, perl = TRUE))[[1]]
    if (length(m) && !m[3] %in% txtCommonWords) return(list(text = m[2], dest = m[3]))
  }
  # a name in capitals: an order, a family
  m <- regmatches(text, regexec(paste0("^(.*[a-z)][.,;:]?)\\s+(", txtCapsNameRe, "(?:\\s+", txtCapsNameRe, ")?)\\.?$"),
                                text, perl = TRUE))[[1]]
  if (length(m)) return(list(text = m[2], dest = m[3]))
  # a sentence, then one capitalised word with its own full stop
  m <- regmatches(text, regexec("^(.*[a-z)]\\.)\\s+([A-Z][a-z]{3,})\\.$", text, perl = TRUE))[[1]]
  if (length(m) && !m[3] %in% txtCommonWords) return(list(text = m[2], dest = m[3]))
  # a sentence, then a genus with its author: "... spicules. Dinamoeba Leidy."
  m <- regmatches(text, regexec(
    "^(.*[a-z)]\\.)\\s+([A-Z][a-z]{3,}(?:\\s+(?:[A-Z(&][A-Za-z.&)]*|and|et|ex))+)\\.?$", text, perl = TRUE))[[1]]
  if (length(m) && !sub(" .*$", "", m[3]) %in% txtCommonWords) return(list(text = m[2], dest = m[3]))
  family <- "[A-Z][a-z]+(?:aceae|idae|inae|ales|oideae|iformes)"
  species <- paste0(
    "(?:[A-Z][a-z]{2,}|(?<=[.;:,] )[A-Z]\\.)\\s+(?:[x\u00d7]\\s+)?[a-z][a-z-]{2,}(?:\\s+(?:var|subsp|ssp|f)\\.\\s+[a-z-]+)?",
    "(?:\\s+[(A-Z&][^\\s]*|\\s+(?:ex|et|and|de|van|von)(?=\\s)|,?\\s+\\(?1[5-9][0-9]{2}\\)?)*"
  )
  extras <- "(?:\\s+\\([^()]*\\))?(?:,?\\s+(?:p|pp)\\.\\s*[0-9]+)?"
  re <- paste0("^(.*?[^\\s.;:,])([.;:,]?)\\s+((?:", family, "|", species, "|[A-Z][a-z]{2,})", extras, ")\\.?$")
  m <- regmatches(text, regexec(re, text, perl = TRUE))[[1]]
  if (!length(m)) return(NULL)
  words <- strsplit(m[4], "\\s+")[[1]]
  if (words[1] %in% txtCommonWords) return(NULL)
  oneWord <- length(words) == 1 && !grepl(paste0("^", family, "$"), words[1], perl = TRUE)
  if (oneWord && m[3] == ".") return(NULL)
  list(text = paste0(m[2], if (m[3] == ".") "." else ""), dest = m[4])
}

# Split "Acer glabrum Torr. (Rocky Mountain maple), p. 14" into its parts
txtSplitName <- function(x) {
  out <- list(taxon = x, authority = "", common = "", page = "")
  x <- gsub("\\s+", " ", trimws(x))
  m <- regmatches(x, regexec("^(.*?)[,;]?\\s*\\(?\\b(?:pp?|pg|page)\\.?\\s*([0-9]+)\\)?\\.?$", x,
                             perl = TRUE, ignore.case = TRUE))[[1]]
  if (length(m) && nzchar(m[2])) {
    out$page <- m[3]
    x <- trimws(m[2])
  } else if (!is.null(named <- txtNamePage(x)) && !nzchar(named$text)) {
    # "Simuliidae, 144": the page after a comma
    out$page <- named$page
    x <- named$name
  } else {
    # "Pinus. (7)." : a list or page number in parentheses after the name
    m <- regmatches(x, regexec(paste0("^(.*[A-Za-z]\\.?)", txtParenNumRe), x, perl = TRUE))[[1]]
    if (length(m)) {
      out$page <- m[3]
      x <- trimws(m[2])
    }
  }
  # the number of the species in the flora: "12. S. exigua"
  x <- sub("^[0-9]{1,3}[.,]\\s+(?=[A-Z])", "", x, perl = TRUE)
  m <- regmatches(x, regexec("^(.*\\S)\\s*\\(([^().0-9]*)\\)$", x))[[1]]
  if (length(m) && grepl("^[a-z][a-z' -]*$", m[2]) && grepl("^[A-Z][a-z]+(?: [a-z-]+)?$", trimws(m[3]))) {
    # "flies (Diptera)": the scientific name is the one in parentheses
    out$common <- m[2]
    x <- trimws(m[3])
  } else if (length(m)) {
    out$common <- trimws(m[3])
    x <- m[2]
  } else {
    m <- regmatches(x, regexec("^([A-Z][a-z]+\\s+[a-z][a-z-]+[^,]*),\\s+([^0-9]+)$", x))[[1]]
    if (length(m)) {
      out$common <- m[3]
      x <- m[2]
    }
  }
  # a common name in front: "southern live oak Quercus virginiana", "Earwigs DERMAPTERA"
  m <- regmatches(x, regexec("^([a-z][a-z' -]*[a-z])\\s+([A-Z][a-z]+\\s+[a-z][a-z-]{2,}(?:\\s.*)?)$", x))[[1]]
  # "Swamp chestnut oak Quercus prinus": the common name may start with a capital
  if (!length(m)) {
    m <- regmatches(x, regexec("^([A-Z][a-z'-]+(?:\\s[a-z][a-z'-]*)+)\\s+([A-Z][a-z]+\\s+[a-z][a-z-]{2,}(?:\\s.*)?)$", x))[[1]]
  }
  if (!length(m)) {
    m <- regmatches(x, regexec(paste0("^([A-Za-z][A-Za-z', -]*[a-z])\\s+(", txtCapsNameRe, ")\\.?$"), x, perl = TRUE))[[1]]
  }
  if (length(m) && !nzchar(out$common)) {
    out$common <- m[2]
    x <- m[3]
  }
  tok <- strsplit(x, "\\s+")[[1]]
  isAuthor <- function(t) grepl("^[(A-Z&]", t) || t %in% c("ex", "et", "de", "van", "von")
  if (length(tok) >= 3 && grepl("^(?:[A-Z][a-z]+|[A-Z]\\.)$", tok[1]) && grepl("^[a-z][a-z-]+$", tok[2]) && isAuthor(tok[3])) {
    name <- tok[1:2]
    rest <- tok[-(1:2)]
    rank <- which(rest %in% c("var.", "subsp.", "ssp.", "f.", "forma", "subvar."))
    rank <- rank[rank < length(rest)]
    if (length(rank) && grepl("^[a-z][a-z-]+$", rest[rank[1] + 1])) {
      name <- c(name, rest[rank[1] + 0:1])
      rest <- rest[-(rank[1] + 0:1)]
    }
    x <- paste(name, collapse = " ")
    out$authority <- paste(rest, collapse = " ")
  } else if (length(tok) >= 2 && grepl("^[A-Z][a-z]+$", tok[1]) && grepl("^\\(?[A-Z][A-Za-z]*\\.", tok[2])) {
    x <- tok[1]
    out$authority <- paste(tok[-1], collapse = " ")
  } else if (grepl("[a-z]\\.$", x) && !grepl("\\s[A-Za-z]{1,5}\\.$", x)) {
    x <- sub("\\.$", "", x)
  }
  if (length(tok) == 1) x <- sub("[.,]$", "", x)
  # "S. nigra." : an abbreviated genus keeps its stop, the epithet loses it
  if (grepl("^[A-Z]\\. [a-z-]+[.,]$", x)) x <- sub("[.,]$", "", x)
  out$taxon <- x
  out
}

# Work out what a destination string is: a couplet or a taxon.
# Returns next ("" if a taxon), the taxon parts, and a repair or problem note.
txtDestination <- function(dest, ownK, scheme, couplets) {
  out <- list(nxt = "", taxon = "", authority = "", common = "", page = "", repair = NULL, problem = NULL)
  d <- trimws(gsub("^[\\s._]+|[\\s_]+$", "", dest, perl = TRUE))
  # "> 2", "-> Quercus alba": an arrow in front of the destination
  d <- sub("^(?:[>\u2192\u21d2\u203a\u25b6]|[=-]{1,2}>)\\s*(?=[0-9A-Za-z(])", "", d, perl = TRUE)
  if (!nzchar(d)) return(out)
  prefix <- "^\\(?\\s*(?:(?:[Gg]o\\s*to|[Ss]ee|[Pp]roceed to|[Cc]ontinue to|to)\\s+)?(?:(?:couplet|lead|step|no\\.?)\\s*)?"
  if (scheme == "letter") {
    m <- regmatches(d, regexec(paste0(prefix, "([A-Z])\\s*\\)?\\.?$"), d, perl = TRUE))[[1]]
    if (length(m)) {
      out$nxt <- m[2]
      return(out)
    }
  } else {
    m <- regmatches(d, regexec(paste0(prefix, "([0-9]{4}|[0-9lIiO|]{1,3})\\s*\\)?\\.?$"), d, perl = TRUE))[[1]]
    if (length(m)) {
      tok <- m[2]
      if (grepl("^[0-9]+$", tok)) {
        out$nxt <- as.character(as.integer(tok))
        return(out)
      }
      fixed <- as.integer(chartr("lIi|O", "11110", tok))
      if (!grepl("^0", chartr("lIi|O", "11110", tok)) && fixed > ownK && as.character(fixed) %in% couplets) {
        out$nxt <- as.character(fixed)
        out$repair <- sprintf("read the destination '%s' as couplet %d", tok, fixed)
        return(out)
      }
      out$taxon <- d
      out$problem <- sprintf("the destination '%s' looks like a broken couplet number (%d?)", d, fixed)
      return(out)
    }
    if (nchar(d) <= 3 && !grepl("\\s", d) && (grepl("[0-9]", d) || grepl("^[lIOoSsBZzgq|!\\]\\[]+$", d, perl = TRUE))) {
      guess <- chartr("lI|!OoSsBZzgq][", "111100558229911", d)
      out$taxon <- d
      out$problem <- sprintf("the destination '%s' looks like a broken couplet number%s", d,
        if (grepl("^[0-9]+$", guess)) paste0(" (", guess, "?)") else "")
      return(out)
    }
  }
  d <- sub("^(?:[Gg]o\\s*to|[Ss]ee)\\s+", "", d, perl = TRUE)
  # a group name and then the couplet: "Class Rhizopoda . . 2", "(SUBULICORNIA) 17"
  m <- regmatches(d, regexec("^(.*[A-Za-z)])[\\s._]+([0-9]{1,3})\\.?$", d, perl = TRUE))[[1]]
  if (scheme == "number" && length(m) && as.integer(m[3]) > ownK &&
      (as.character(as.integer(m[3])) %in% couplets || grepl("^\\(.*\\)$", trimws(m[2]))) &&
      !grepl("\\b(?:pp?|pg|page)\\.?$", m[2], ignore.case = TRUE, perl = TRUE)) {
    out$nxt <- as.character(as.integer(m[3]))
    out$label <- trimws(m[2])
    return(out)
  }
  name <- txtSplitName(d)
  out$taxon <- name$taxon
  out$authority <- name$authority
  out$common <- name$common
  out$page <- name$page
  out
}

# ---- pass 3: choices, destinations and checks --------------------------------

# `raw`: one row per lead with couplet, k, letter, primes, backref, indent,
# line, text, dest, sep ("leaders", "gap", "given" or "none") and kind.
txtFinish <- function(raw, scheme, layout, notes, paired = FALSE) {
  n <- nrow(raw)
  couplets <- unique(raw$couplet)
  if (is.null(raw$page)) raw$page <- rep("", n)
  # In a paired key ("1 (8)" / "8 (1)") a destination names a lead, which
  # stands for the couplet that lead belongs to
  alias <- character()
  if (paired) {
    alias <- raw$couplet
    names(alias) <- as.character(raw$k)
    alias <- alias[!duplicated(names(alias))]
  }

  # Choice letters: the printed letter, else by primes, else in order
  choice <- character(n)
  for (cp in couplets) {
    used <- character()
    for (i in which(raw$couplet == cp)) {
      free <- setdiff(c(letters, paste0("z", 1:50)), used)
      want <- if (nzchar(raw$letter[i])) raw$letter[i] else if (raw$primes[i] > 0) letters[raw$primes[i] + 1] else free[1]
      if (want %in% used) {
        notes$add(raw$line[i], i, "problem", "duplicate_lead",
          sprintf("lead %s%s appears twice; the second one is kept as %s%s", cp, want, cp, free[1]))
        want <- free[1]
      }
      choice[i] <- want
      used <- c(used, want)
    }
  }

  first <- !duplicated(raw$couplet)
  positions <- split(seq_len(n), factor(raw$couplet, levels = couplets))
  scattered <- any(vapply(positions, function(p) any(diff(p) != 1), logical(1)))
  # A key is indented when its couplets are split up and many leads have no
  # destination of their own; a few couplets out of order in a scan are not
  # enough
  noDest <- !nzchar(trimws(raw$dest)) & raw$sep %in% c("none", "given")
  heads <- which(noDest & c(first[-1], FALSE) & c(raw$couplet[-1], "") != raw$couplet)
  # not those that merely lost their dot leaders ("... each year. 11.")
  ends <- vapply(gsub("\\s+", " ", raw$text[heads]), function(t) {
    !is.null(txtTrailingNumber(t)) || !is.null(txtTrailingTaxon(t))
  }, logical(1), USE.NAMES = FALSE)
  heads <- heads[!ends]
  indented <- paired || layout == "indented" ||
    (layout == "auto" && scattered && length(heads) >= max(2, 0.2 * n))

  nxt <- character(n)
  taxon <- authority <- common <- character(n)
  page <- raw$page
  text <- gsub("\\s+", " ", raw$text)
  known <- if (paired) names(alias) else couplets
  resolve <- function(i, dest) {
    d <- txtDestination(dest, raw$k[i], scheme, known)
    nxt[i] <<- if (nzchar(d$nxt) && d$nxt %in% names(alias)) alias[[d$nxt]] else d$nxt
    taxon[i] <<- d$taxon
    authority[i] <<- d$authority
    common[i] <<- d$common
    if (nzchar(d$page)) page[i] <<- d$page
    # a group name printed before the couplet number stays with the text
    if (!is.null(d$label)) text[i] <<- trimws(paste(text[i], d$label))
    if (!is.null(d$repair)) notes$add(raw$line[i], i, "repair", "destination", d$repair)
    if (!is.null(d$problem)) notes$add(raw$line[i], i, "problem", "broken_number", d$problem)
  }
  for (i in seq_len(n)) {
    if (nzchar(trimws(raw$dest[i]))) {
      resolve(i, raw$dest[i])
    } else if (raw$sep[i] == "none") {
      found <- txtTrailingGoto(text[i], scheme)
      if (!is.null(found)) {
        text[i] <- found$text
        resolve(i, found$dest)
      }
    }
  }
  # Leads still without a destination. In order: a number set off by a full
  # stop or comma ("... each year. 11."), a trailing number that is a couplet
  # of the key, the couplet printed underneath (indented keys), and a name at
  # the end of the text. All but the third are repairs and are reported.
  lostNumber <- function(i, strongOnly) {
    if (raw$sep[i] != "none" || scheme != "number") return(FALSE)
    found <- txtTrailingNumber(text[i])
    if (is.null(found)) return(FALSE)
    num <- as.character(as.integer(found$dest))
    isCouplet <- num %in% known && !identical(alias[num][[1]], raw$couplet[i]) && num != raw$couplet[i]
    ahead <- found$afterStop && as.integer(num) > raw$k[i]
    if (strongOnly && !(found$afterStop && (isCouplet || ahead))) return(FALSE)
    if (!strongOnly && !isCouplet) return(FALSE)
    text[i] <<- found$text
    nxt[i] <<- if (num %in% names(alias)) alias[[num]] else num
    notes$add(raw$line[i], i, "repair", "destination",
      sprintf("no dot leaders before the destination; took the trailing '%s' as the next couplet", found$dest))
    TRUE
  }
  # "... sheathed joints C." : in a lettered key, a couplet letter further on
  lostLetter <- function(i) {
    if (raw$sep[i] != "none" || scheme != "letter") return(FALSE)
    m <- regmatches(text[i], regexec("^(.*[a-z)][.,;]?)\\s+([A-Z])\\.?$", text[i], perl = TRUE))[[1]]
    if (!length(m) || !m[3] %in% known || match(m[3], LETTERS) <= raw$k[i]) return(FALSE)
    text[i] <<- m[2]
    nxt[i] <<- m[3]
    notes$add(raw$line[i], i, "repair", "destination",
      sprintf("no dot leaders before the destination; took the trailing '%s' as the next couplet", m[3]))
    TRUE
  }
  for (i in which(!nzchar(nxt) & !nzchar(taxon))) {
    if (lostLetter(i)) next
    if (lostNumber(i, strongOnly = TRUE)) next
    if (lostNumber(i, strongOnly = FALSE)) next
    under <- i < n && first[i + 1] && raw$couplet[i + 1] != raw$couplet[i] &&
      (!paired || raw$k[i + 1] == raw$k[i] + 1L)
    if (under && layout != "bracketed" && (indented || raw$indent[i + 1] > raw$indent[i])) {
      nxt[i] <- raw$couplet[i + 1]
      indented <- TRUE
      next
    }
    if (raw$sep[i] != "none") next
    found <- txtTrailingTaxon(text[i])
    if (!is.null(found)) {
      text[i] <- found$text
      resolve(i, found$dest)
      notes$add(raw$line[i], i, "repair", "destination",
        sprintf("no dot leaders before the destination; took the trailing '%s' as the taxon", found$dest))
    }
  }
  # Where most leads lost their dot leaders, a trailing number further on in
  # the key is a destination too, even if that couplet is not in the text
  repaired <- sum(vapply(notes$get(), function(r) r$type == "destination" && grepl("next couplet", r$message), logical(1)))
  if (scheme == "number" && repaired >= 3) {
    for (i in which(!nzchar(nxt) & !nzchar(taxon) & raw$sep == "none")) {
      found <- txtTrailingNumber(text[i])
      if (is.null(found) || as.integer(found$dest) <= raw$k[i]) next
      text[i] <- found$text
      nxt[i] <- as.character(as.integer(found$dest))
      notes$add(raw$line[i], i, "repair", "destination",
        sprintf("no dot leaders before the destination; took the trailing '%s' as the next couplet", found$dest))
    }
  }
  for (i in which(raw$sep == "lost" & nzchar(taxon))) {
    notes$add(raw$line[i], i, "repair", "destination",
      sprintf("no dot leaders before the destination; took the trailing '%s' as the taxon", taxon[i]))
  }
  for (i in which(raw$sep == "paren" & nzchar(nxt))) {
    notes$add(raw$line[i], i, "note", "destination",
      sprintf("took the number in parentheses at the end, (%s), as the next couplet", raw$dest[i]))
  }

  # ---- checks ----
  flagged <- function() {
    unlist(lapply(notes$get(), function(r) if (r$type == "broken_number") r$lead))
  }
  label <- paste0(raw$couplet, choice)
  for (i in which(!nzchar(trimws(text)))) {
    notes$add(raw$line[i], i, "problem", "no_text", sprintf("lead %s has no text", label[i]))
  }
  for (i in which(!nzchar(nxt) & !nzchar(taxon))) {
    notes$add(raw$line[i], i, "problem", "no_destination",
      sprintf("lead %s has no destination (no couplet or taxon after the text)", label[i]))
  }
  for (i in which(nzchar(taxon) & (nchar(taxon) > 100 | lengths(strsplit(taxon, "\\s+")) > 12))) {
    notes$add(raw$line[i], i, "problem", "long_destination",
      sprintf("the destination of lead %s is very long; text after the lead may have been read as part of it", label[i]))
  }
  for (i in which(nzchar(taxon) & !grepl("[A-Za-z]{3}", taxon) & !seq_len(n) %in% flagged())) {
    notes$add(raw$line[i], i, "problem", "odd_destination",
      sprintf("the destination of lead %s, '%s', is neither a couplet nor a name", label[i], taxon[i]))
  }
  for (i in which(nzchar(nxt) & !nxt %in% couplets)) {
    notes$add(raw$line[i], i, "problem", "missing_couplet",
      sprintf("lead %s leads to couplet %s, which is not in the key", label[i], nxt[i]))
  }
  for (cp in couplets[lengths(positions) < 2]) {
    i <- positions[[cp]][1]
    notes$add(raw$line[i], i, "problem", "single_lead", sprintf("couplet %s has only one lead", cp))
  }
  for (i in which(nzchar(raw$backref) & !paired)) {
    from <- chartr("lI|O", "1110", strsplit(gsub("[^0-9lIO|]+", " ", raw$backref[i]), " +")[[1]])
    from <- as.character(suppressWarnings(as.integer(from[nzchar(from)])))
    lost <- from[!vapply(from, function(f) any(raw$couplet == f & nxt == raw$couplet[i]), logical(1))]
    if (length(lost)) {
      notes$add(raw$line[i], i, "problem", "backref", sprintf(
        "couplet %s says it is reached from couplet %s, but no lead of couplet %s leads to it",
        raw$couplet[i], paste(lost, collapse = ", "), paste(lost, collapse = ", ")))
    }
  }
  # Leads that lead back to their own couplet, and couplets nothing leads to
  reach <- function(from) {
    seenCp <- from
    frontier <- from
    while (length(frontier)) {
      step <- setdiff(nxt[raw$couplet %in% frontier & nzchar(nxt)], seenCp)
      step <- step[step %in% couplets]
      seenCp <- c(seenCp, step)
      frontier <- step
    }
    seenCp
  }
  # Only couplets left after peeling off those that lead nowhere further can
  # be part of a cycle
  core <- couplets
  repeat {
    out <- unique(raw$couplet[nzchar(nxt) & nxt %in% core & raw$couplet %in% core])
    if (length(out) == length(core)) break
    core <- out
  }
  for (i in which(nzchar(nxt) & nxt %in% core & raw$couplet %in% core)) {
    if (raw$couplet[i] %in% reach(nxt[i])) {
      notes$add(raw$line[i], i, "problem", "cycle",
        sprintf("lead %s leads to couplet %s, which leads back to couplet %s (a cycle)", label[i], nxt[i], raw$couplet[i]))
    }
  }
  if (n > 0) {
    cut <- setdiff(couplets, reach(couplets[1]))
    # name only where the break is: a couplet no lead leads to, not everything
    # that hangs below it
    led <- unique(nxt[nzchar(nxt) & raw$couplet != nxt])
    top <- setdiff(cut, led)
    if (length(cut) && !length(top)) top <- cut[1]
    for (cp in top) {
      i <- positions[[cp]][1]
      notes$add(raw$line[i], i, "problem", "unreachable",
        sprintf("couplet %s cannot be reached from couplet %s", cp, couplets[1]))
    }
  }

  leads <- data.frame(
    Statement = raw$couplet, Choice = choice, Character = trimws(text),
    Next = ifelse(nzchar(nxt), nxt, "-"), Taxon = taxon, Authority = authority,
    CommonName = common, Page = page, Line = as.integer(raw$line), stringsAsFactors = FALSE
  )
  list(leads = leads, layout = if (paired) "paired" else if (indented) "indented" else "bracketed")
}

txtProblemTable <- function(notes, leads) {
  rows <- notes$get()
  if (!length(rows)) {
    return(txtProblemRow(integer(), character(), character(), character(), character(), character()))
  }
  lead <- vapply(rows, function(r) as.integer(r$lead), integer(1))
  ok <- lead > 0 & lead <= nrow(leads)
  out <- txtProblemRow(
    vapply(rows, function(r) as.integer(r$line), integer(1)),
    ifelse(ok, leads$Statement[pmax(lead, 1)], ""),
    ifelse(ok, paste0(leads$Statement[pmax(lead, 1)], leads$Choice[pmax(lead, 1)]), ""),
    vapply(rows, function(r) r$kind, ""), vapply(rows, function(r) r$type, ""),
    vapply(rows, function(r) r$message, "")
  )
  out$.lead <- ifelse(ok, lead, NA_integer_)
  out <- out[order(match(out$Kind, c("problem", "repair", "note")), out$Line), , drop = FALSE]
  rownames(out) <- NULL
  out
}

txtResult <- function(leads, problems, title, layout, text) {
  problems$.lead <- NULL
  structure(list(leads = leads, problems = problems, title = title, layout = layout, text = text),
            class = "textKeyParse")
}

# Are these leads from a paired key, where every lead has its own number and
# names its alternative in parentheses: "1 (8) ..." and later "8 (1) ..."?
txtPartners <- function(leads) {
  k <- vapply(leads, function(l) l$k, 0L)
  backref <- vapply(leads, function(l) l$backref, "")
  partner <- suppressWarnings(as.integer(chartr("lI|O", "1110", backref)))
  if (length(k) < 4 || mean(!is.na(partner)) < 0.6 || mean(!duplicated(k) & !k %in% k[duplicated(k)]) < 0.8) {
    return(NULL)
  }
  partner
}

# ---- keys without couplet numbers ---------------------------------------------

# "12. S. exigua", "IV. Longifoliae", "4. Gentiana": the number of a species,
# genus or section in the flora, followed by its name. In an indented key
# without couplet numbers this is how a lead ends.
# A scan may read the full stops as commas and the genus letter as two
# ("4. VF'. angustifolia", "12, S. Cutleri").
txtFloraNameRe <- paste0(
  "(?:[0-9]{1,3}|[IVXLC]{1,6})[.,]\\s*",
  "(?:[A-Z][A-Za-z']{0,2}[.,]\\s*[A-Za-z'-]+(?:\\s[a-z-]+)?|[A-Z][A-Za-z-]+)")
# ... at the end of a line, with the page it may carry: "8. Phalarideae (p. 25)"
txtFloraEndRe <- paste0(txtFloraNameRe, "(?:\\s*\\(\\s*pp?\\.\\s*[^()]{1,5}\\))?[.,; ]*$")

# Does the text look like a key without couplet numbers? TRUE when no line
# starts with a couplet label, or when most of the numbers that start a line
# are followed by nothing but a name.
txtLooksUnnumbered <- function(x) {
  lab <- txtLabelTable(x)
  nonblank <- nzchar(trimws(x))
  labels <- which(lab$kind %in% c("num", "letter") & lab$strong & nonblank)
  nameOnly <- grepl(paste0("^\\s*", txtFloraEndRe), x, perl = TRUE)
  ends <- grepl(paste0("[a-z0-9)][.,;]?\\s+", txtFloraEndRe), x, perl = TRUE) | nameOnly |
    grepl(paste0("[A-Za-z]{4}", txtPageRefRe), x, perl = TRUE)
  if (sum(ends) < 3) return(FALSE)
  realLabels <- setdiff(labels, which(nameOnly))
  length(realLabels) < 2 || length(realLabels) < 0.25 * sum(ends)
}

# A key without numbers: the leads of a couplet share an indent and a lead
# without a destination leads to the deeper couplet under it. Where the
# indentation is lost (most scans), the couplets are worked out from the
# order of the leads alone, which is possible when every couplet has exactly
# two leads: a lead without a name opens a couplet, a lead with a name is
# followed by the second lead of the nearest couplet that still lacks one.
# Returns the `raw` table for txtFinish(), or `why` the text was refused.
txtScanUnnumbered <- function(x, skip, notes) {
  n <- length(x)
  blank <- !nzchar(trimws(x))
  realIndent <- nchar(regmatches(x, regexpr("^ *", x)))
  body <- trimws(x)
  skipped <- if (is.null(skip)) rep(FALSE, n) else grepl(skip, x, perl = TRUE) & !blank
  pageNum <- grepl("^[\\[(]?\\s*[0-9]{1,4}\\s*[\\])]?$", body)
  caps <- !grepl("[a-z]", body) & nchar(gsub("[^A-Z]", "", body)) >= 4
  head <- (caps & grepl("^[0-9]{1,4}\\s|\\s[0-9]{1,4}$", body)) |
    (grepl("^[0-9]{1,4}\\s|\\s[0-9]{1,4}$", body) & vapply(body, txtTitleWords, integer(1), USE.NAMES = FALSE) >= 2 &
       !grepl(txtFloraNameRe, body, perl = TRUE))
  nameOnly <- grepl(paste0("^", txtFloraEndRe), body, perl = TRUE)
  # the rest of a name that the scan put on a line of its own, away from its
  # number: ". V. canadensis."
  orphan <- grepl("^[.,]\\s*[A-Z][A-Za-z']{0,2}[.,]\\s*[A-Za-z'-]+[.,]?$", body, perl = TRUE)
  abbreviation <- "(?:\\b(?:mm|cm|dm|in|ft|ca|var|subsp|ssp|sp|spp|vs|no|nos|diam|fig|pl)|\\s[a-z])\\.$"
  # a lead that ends in the number of its species, the name being elsewhere
  bareNumberRe <- "[a-z)]\\.\\s+([0-9]{1,3})\\.?$"
  ended <- function(parts) {
    last <- parts[length(parts)]
    grepl("[.][ .,]*$", last) && !grepl(abbreviation, last, perl = TRUE, ignore.case = TRUE)
  }
  hasDest <- function(parts) {
    last <- parts[length(parts)]
    # dots with nothing readable after them are specks, not dot leaders
    after <- sub(paste0("^.*", txtLeaderRe), "", last, perl = TRUE)
    leaders <- grepl(txtLeaderRe, last, perl = TRUE) && grepl("[A-Za-z]{3}|[0-9]", after)
    grepl(txtFloraEndRe, last, perl = TRUE) || leaders ||
      grepl(txtPageRefRe, last, perl = TRUE, ignore.case = TRUE) || grepl(bareNumberRe, last, perl = TRUE)
  }

  # `indent`: the indent of each line, or all zero to read the text as flat
  readLeads <- function(indent, quiet = FALSE) {
    say <- function(...) if (!quiet) notes$add(...)
    leads <- list()
    title <- NA_character_
    for (i in seq_len(n)) {
      if (blank[i]) next
      if (skipped[i]) { say(i, 0L, "note", "skipped", "skipped: matches `skip`"); next }
      if (pageNum[i]) { say(i, 0L, "note", "skipped", sprintf("skipped a page number: '%s'", body[i])); next }
      if (head[i]) { say(i, 0L, "note", "skipped", sprintf("skipped a running head: '%s'", body[i])); next }
      cur <- length(leads)
      isTitle <- nameOnly[i] || (grepl("\\bkey\\b", body[i], ignore.case = TRUE) && !grepl("[.]\\s*\\S+$", body[i]))
      if (cur == 0 && is.na(title) && isTitle) {
        title <- gsub("\\s+", " ", body[i])
        next
      }
      if (orphan[i] && cur > 0) {
        waiting <- which(vapply(leads, function(l) grepl(bareNumberRe, l$parts[length(l$parts)], perl = TRUE), logical(1)))
        if (length(waiting)) {
          j <- waiting[1]
          rest <- sub("^[.,]\\s*([A-Z][A-Za-z']{0,2})[.,]\\s*", "\\1. ", body[i], perl = TRUE)
          last <- length(leads[[j]]$parts)
          leads[[j]]$parts[last] <- paste0(sub("\\.?$", "", leads[[j]]$parts[last]), ". ", rest)
          say(i, j, "repair", "destination", sprintf(
            "the name '%s' stands alone on line %d; it was put after the number that ends the lead on line %d",
            body[i], i, leads[[j]]$line))
        } else {
          say(i, 0L, "problem", "lone_name", sprintf(
            "'%s' looks like a name that the scan separated from its lead; it was not used", body[i]))
        }
        next
      }
      line <- sub("^[*\u2020\u2021\u00a7]+\\s*", "", body[i])
      star <- line != body[i]
      # specks the scan left in front of a lead: "., Plants densely ..."
      line <- sub("^[.,;:'^\"]+\\s*(?=[A-Z])", "", line, perl = TRUE)
      if (cur > 0) {
        parts <- leads[[cur]]$parts
        if (nameOnly[i]) {
          if (!hasDest(parts)) {
            # the name of the lead above, set flush right on its own line
            leads[[cur]]$parts <- c(parts, paste0("   ", line))
            next
          }
          # a centred heading: another key starts here
          say(i, 0L, "problem", "second_key", sprintf(
            "'%s' looks like the heading of another key; only the key above it was read. Give each key separately",
            line))
          break
        }
        wraps <- !ended(parts) && !hasDest(parts)
        if (wraps && !star && indent[i] >= leads[[cur]]$indent) {
          leads[[cur]]$parts <- c(parts, line)
          next
        }
        # set far to the right of its lead: a destination or the end of the lead
        if (!hasDest(parts) && indent[i] >= leads[[cur]]$indent + 30L) {
          leads[[cur]]$parts <- c(parts, paste0("   ", line))
          next
        }
      }
      leads[[cur + 1]] <- list(indent = if (star) -1L else indent[i], line = i, parts = line)
    }
    list(leads = leads, title = title)
  }

  read <- readLeads(realIndent, quiet = TRUE)
  ind <- vapply(read$leads, function(l) l$indent, 0L)
  # nearly everything at one indent: the indentation is gone, a few stray
  # spaces do not make a key
  flat <- length(unique(ind)) < 2 || (length(ind) > 6 && max(table(ind)) > 0.8 * length(ind))
  read <- readLeads(if (flat) rep(0L, n) else realIndent)
  leads <- read$leads
  title <- read$title
  m <- length(leads)
  if (m < 2) return(list(raw = NULL, why = "fewer than two leads were found", line = 1L))
  ind <- vapply(leads, function(l) l$indent, 0L)
  couplet <- integer(m)
  parent <- integer(m)
  if (flat) {
    # Couplets from the order of the leads, two leads to a couplet
    has <- vapply(leads, function(l) hasDest(l$parts), logical(1))
    open <- integer()           # couplets that may still get their second lead
    size <- integer()
    extra <- integer()
    for (j in seq_len(m)) {
      if (j == 1L || !has[j - 1L]) {
        size <- c(size, 1L)
        couplet[j] <- length(size)
        open <- c(open, couplet[j])
        if (j > 1L) parent[j] <- j - 1L
        next
      }
      while (length(open) && size[open[length(open)]] >= 2L) open <- open[-length(open)]
      if (!length(open)) {
        extra <- c(extra, j)
        break
      }
      couplet[j] <- open[length(open)]
      size[couplet[j]] <- size[couplet[j]] + 1L
    }
    why <- NULL
    at <- NA_integer_
    if (length(extra)) {
      at <- leads[[extra[1]]]$line
      why <- sprintf(paste(
        "the leads up to line %d pair off into complete couplets, but more leads follow: a couplet above",
        "has three leads, a lead was split in two, or another key starts there"), at)
    } else if (!has[m]) {
      at <- leads[[m]]$line
      why <- sprintf("the last lead (line %d) does not end in a name", at)
    } else if (any(size != 2L)) {
      at <- leads[[which(couplet == which(size != 2L)[1])[1]]]$line
      why <- sprintf(paste(
        "the leads do not pair off: the couplet that starts on line %d has no second lead (a lead may have",
        "lost its name, or two leads were read as one)"), at)
    }
    if (!is.null(why)) return(list(raw = NULL, why = why, line = at))
    notes$add(leads[[1]]$line, 0L, "repair", "structure", paste(
      "the leads have no couplet numbers and no indentation; the couplets were worked out from the order of",
      "the leads, taking every couplet to have exactly two leads. Check the result against the page"))
  } else {
    # Couplets from the indentation. An indent within one column of an open
    # level is that level (scans are never quite straight).
    stack <- data.frame(indent = integer(), couplet = integer())
    nCouplets <- 0L
    for (j in seq_len(m)) {
      stack <- stack[stack$indent <= ind[j] + 1L, , drop = FALSE]
      top <- nrow(stack)
      if (top > 0 && abs(stack$indent[top] - ind[j]) <= 1L) {
        couplet[j] <- stack$couplet[top]
      } else {
        nCouplets <- nCouplets + 1L
        couplet[j] <- nCouplets
        stack <- rbind(stack, data.frame(indent = ind[j], couplet = nCouplets))
        if (j > 1) parent[j] <- j - 1L
      }
    }
  }
  text <- dest <- sep <- page <- character(m)
  joined <- integer(m)
  for (j in seq_len(m)) {
    parts <- leads[[j]]$parts
    child <- which(parent == j)
    found <- txtSplitLead(sub("^ +", "", parts))
    whole <- txtJoin(parts)
    joined[j] <- whole$joined
    floraName <- regmatches(whole$text, regexec(
      paste0("^(.*[a-z0-9)][\\s.,;]*)\\s+(", txtFloraNameRe, ")(?:\\s*\\(\\s*pp?\\.\\s*([^()]{1,5})\\))?[.,; ]*$"),
      whole$text, perl = TRUE))[[1]]
    bare <- regmatches(whole$text, regexec("^(.*[a-z)]\\.)\\s+([0-9]{1,3})\\.?$", whole$text, perl = TRUE))[[1]]
    if (length(floraName)) {
      text[j] <- sub("\\s+([.,;])$", "\\1", trimws(floraName[2]))
      # commas the scan made of full stops: "12, S. Cutleri", "V, canadensis"
      d <- sub("^([0-9IVXLC]+),", "\\1.", sub("^([0-9IVXLC]+[.,]\\s*[A-Z][A-Za-z']{0,2}),", "\\1.", floraName[3]))
      # "VF'. angustifolia": specks read as letters of the genus abbreviation
      dest[j] <- sub("^([0-9IVXLC]+\\.\\s*[A-Z])[A-Za-z']*'[A-Za-z']*\\.", "\\1.", d)
      sep[j] <- "given"
      if (grepl("^[0-9]+$", floraName[4])) page[j] <- floraName[4]
    } else if (length(bare)) {
      text[j] <- bare[2]
      dest[j] <- paste("species", bare[3])
      sep[j] <- "given"
      notes$add(leads[[j]]$line, j, "problem", "name_lost", sprintf(
        "the lead ends in the number %s without a name; the scan may have put the name elsewhere", bare[3]))
    } else if (found$sep %in% c("leaders", "mark", "gap") && grepl("[A-Za-z]{3}|[0-9]", found$dest)) {
      text[j] <- found$text
      dest[j] <- found$dest
      sep[j] <- found$sep
      page[j] <- found$page
    } else {
      # specks at the end of the line are not part of the lead
      text[j] <- sub("(?<=[a-z)])\\s*\\.[\\s.,;:*\u00ab\u00bb'^_-]+(?:[a-z][\\s.,;:*\u00ab\u00bb'^_-]+)?$", ".", whole$text, perl = TRUE)
      sep[j] <- if (length(child)) "given" else "none"
    }
    if (length(child)) {
      if (nzchar(dest[j])) {
        notes$add(leads[[j]]$line, j, "problem", "name_and_couplet", sprintf(
          "the lead on line %d ends in '%s' but more deeply indented leads follow it; they were kept as its couplet",
          leads[[j]]$line, dest[j]))
        text[j] <- paste(text[j], dest[j])
      }
      dest[j] <- as.character(couplet[child[1]])
    }
  }
  raw <- data.frame(
    couplet = as.character(couplet), k = couplet, letter = "", primes = 0L, backref = "",
    indent = pmax(ind, 0L), line = vapply(leads, function(l) l$line, 0L), kind = "indent",
    text = text, dest = dest, sep = sep, page = page, stringsAsFactors = FALSE
  )
  list(raw = raw, title = title, joined = joined, flat = flat)
}

txtParseUnnumbered <- function(src, x, skip) {
  notes <- txtCollector()
  scan <- txtScanUnnumbered(x, skip, notes)
  if (is.null(scan$raw)) return(scan)
  raw <- scan$raw
  if (!scan$flat) {
    notes$add(raw$line[1], 0L, "note", "layout",
      "the leads have no couplet numbers; couplets were made from the indentation and numbered in order")
  }
  for (i in which(scan$joined > 0)) {
    notes$add(raw$line[i], i, "note", "dehyphenated", sprintf("joined %d word(s) hyphenated at a line end", scan$joined[i]))
  }
  done <- txtFinish(raw, "number", "bracketed", notes)
  list(leads = done$leads, problems = txtProblemTable(notes, done$leads), title = scan$title,
       layout = "unnumbered", text = src)
}

# Text set in two columns, as `pdftotext -layout` and some scans give it: a
# gutter of spaces at the same place in nearly all long lines, with leads on
# both sides. Returns the lines of the left column followed by those of the
# right, block by block (a block ends at two blank lines or a page break),
# and the line each came from; NULL if the text is not in two columns.
txtUnColumn <- function(x) {
  if (isTRUE(attr(x, "loose"))) return(NULL)
  n <- length(x)
  nonblank <- nzchar(trimws(x))
  width <- nchar(x)
  w <- max(width, 0L)
  if (sum(nonblank) < 6 || w < 50) return(NULL)
  best <- NULL
  for (p in seq(floor(0.25 * w), ceiling(0.75 * w))) {
    wide <- nonblank & width > p + 3L
    if (sum(wide) < max(4, 0.4 * sum(nonblank))) next
    gutter <- substr(x[wide], p, p + 2L) == "   "
    if (mean(gutter) >= 0.95) best <- c(best, p)
  }
  if (is.null(best)) return(NULL)
  p <- best[ceiling(length(best) / 2)]
  left <- sub("\\s+$", "", substr(x, 1, p))
  right <- substring(x, p + 1L)
  shift <- min(nchar(regmatches(right, regexpr("^ *", right)))[nzchar(trimws(right))])
  right <- sub("\\s+$", "", substring(right, shift + 1L))
  # both sides must read like a key: lead labels, and more than a word or two
  labelled <- function(v) sum(txtLabelTable(v)$kind != "")
  words <- lengths(strsplit(trimws(right[nzchar(right)]), "\\s+"))
  if (labelled(left) < 2 || labelled(right) < 2 || mean(words) < 3) return(NULL)
  # blocks: two blank lines in a row end a page
  blank2 <- !nonblank & c(!nonblank[-1], TRUE)
  block <- cumsum(c(FALSE, blank2[-n]) & !blank2)
  out <- character()
  from <- integer()
  for (b in unique(block)) {
    idx <- which(block == b)
    if (any(nzchar(right[idx]))) {
      out <- c(out, left[idx], "", right[idx], "")
      from <- c(from, idx, idx[length(idx)], idx, idx[length(idx)])
    } else {
      out <- c(out, left[idx])
      from <- c(from, idx)
    }
  }
  attr(out, "loose") <- FALSE
  list(x = out, line = from, at = p)
}

txtParseLines <- function(src, layout = "auto", skip = NULL, keepLeadIndex = FALSE) {
  x <- txtCleanLines(src)
  cols <- txtUnColumn(x)
  res <- txtParseClean(src, if (is.null(cols)) x else cols$x, layout, skip)
  if (!is.null(cols)) {
    # line numbers are those of the text as it was given
    res$leads$Line <- cols$line[res$leads$Line]
    res$problems$Line <- cols$line[res$problems$Line]
    extra <- txtProblemRow(cols$line[1], "", "", "repair", "two_columns", sprintf(
      "the text is set in two columns (gutter at column %d); the left column was read first, then the right", cols$at))
    extra$.lead <- NA_integer_
    res$problems <- rbind(res$problems, extra)
    res$problems <- res$problems[order(match(res$problems$Kind, c("problem", "repair", "note")), res$problems$Line), , drop = FALSE]
    rownames(res$problems) <- NULL
  }
  if (keepLeadIndex) return(res)
  txtResult(res$leads, res$problems, res$title, res$layout, res$text)
}

# The lines are clean (see txtCleanLines); returns leads, problems (with the
# index of the lead each belongs to in `.lead`), title, layout and text.
txtParseClean <- function(src, x, layout = "auto", skip = NULL) {
  unnumbered <- layout == "unnumbered" || (layout == "auto" && txtLooksUnnumbered(x))
  if (unnumbered) {
    res <- txtParseUnnumbered(src, x, skip)
    if (is.null(res$leads)) {
      why <- res$why
      at <- if (is.null(res$line) || is.na(res$line)) 1L else res$line
      # no indentation to go by and the leads do not pair off: say so
      # instead of guessing
      res <- list(
        leads = txtFinish(data.frame(
          couplet = character(), k = integer(), letter = character(), primes = integer(), backref = character(),
          indent = integer(), line = integer(), kind = character(), text = character(), dest = character(),
          sep = character(), page = character(), stringsAsFactors = FALSE), "number", "bracketed", txtCollector())$leads,
        title = NA_character_, layout = "unnumbered", text = src)
      res$problems <- txtProblemRow(at, "", "", "problem", "no_indentation", paste0(
        "this looks like a key without couplet numbers, and its lines are not indented, so the couplets ",
        "cannot be told apart (scanned text often loses the indentation); no leads were read",
        if (!is.null(why)) paste0(". Working them out from the order of the leads failed: ", why) else ""))
      res$problems$.lead <- NA_integer_
    }
    return(res[c("leads", "problems", "title", "layout", "text")])
  }
  if (layout == "unnumbered") layout <- "auto"
  notes <- txtCollector()
  scan <- txtScan(x, skip, notes)
  partner <- txtPartners(scan$leads)
  paired <- !is.null(partner) && layout == "auto"
  # Second leads without a label: most couplets have one lead, each followed
  # by a paragraph that was passed over
  nCouplets <- length(unique(vapply(scan$leads, function(l) l$couplet, "")))
  if (!paired && scan$scheme == "number" && scan$strays >= max(2, ceiling(nCouplets / 2))) {
    notes <- txtCollector()
    scan <- txtScan(x, skip, notes, implicit = TRUE)
    notes$add(scan$leads[[1]]$line, 0L, "note", "layout",
      "the second lead of each couplet has no label; an unlabelled paragraph after a finished lead was read as one")
  }
  if (isTRUE(attr(x, "loose"))) {
    notes$add(1L, 0L, "note", "layout",
      "the words are two or more spaces apart throughout; only clearly wider gaps were read as gaps")
  }
  n <- length(scan$leads)
  # Two leads side by side on one line: text set in two columns
  beside <- grep(paste0(
    txtLeaderRe, "(?:[0-9]{1,3}|[A-Z][A-Za-z. ]{2,40}?)\\s{2,}[0-9]{1,3}[a-h]?['.)]{0,2}\\s+[A-Z].*", txtLeaderRe, "\\S"),
    x, perl = TRUE)
  if (length(beside)) {
    notes$add(beside[1], 0L, "problem", "two_columns", sprintf(
      "%d line(s) seem to hold two leads side by side (text in two columns), the first on line %d; the leads there were run together. Give the columns one after the other",
      length(beside), beside[1]))
  }
  # A key that starts at couplet 3: the couplets before it were not read
  if (n > 0 && !paired && scan$leads[[1]]$k > 1L && scan$leads[[1]]$kind %in% c("num", "letter")) {
    firstK <- scan$leads[[1]]$k
    name <- function(k) if (scan$scheme == "letter") LETTERS[k] else as.character(k)
    notes$add(scan$leads[[1]]$line, 0L, "problem", "missing_start", sprintf(
      "the first couplet that was read is %s; couplet%s not found (if the text above line %d holds %s, the leads there have no labels)",
      name(firstK), if (firstK > 2L) paste0("s ", name(1L), " to ", name(firstK - 1L), " were") else paste0(" ", name(1L), " was"),
      scan$leads[[1]]$line, if (firstK > 2L) "them" else "it"))
  }
  split <- lapply(scan$leads, function(l) txtSplitLead(l$parts))
  field <- function(name, type) vapply(scan$leads, function(l) l[[name]], type)
  raw <- data.frame(
    couplet = field("couplet", ""), k = field("k", 0L), letter = field("letter", ""),
    primes = field("primes", 0L), backref = field("backref", ""), indent = field("indent", 0L),
    line = field("line", 0L), kind = field("kind", ""),
    text = vapply(split, function(s) s$text, ""), dest = vapply(split, function(s) s$dest, ""),
    sep = vapply(split, function(s) s$sep, ""), page = vapply(split, function(s) s$page, ""),
    stringsAsFactors = FALSE
  )
  if (paired) {
    raw$couplet <- as.character(ifelse(is.na(partner), raw$k, pmin(raw$k, partner)))
    notes$add(raw$line[1], 0L, "note", "layout",
      "every lead has its own number and names its alternative in parentheses; the two were put together as one couplet")
  }
  for (i in seq_len(n)) {
    if (split[[i]]$joined > 0) {
      notes$add(raw$line[i], i, "note", "dehyphenated",
        sprintf("joined %d word(s) hyphenated at a line end", split[[i]]$joined))
    }
  }
  done <- txtFinish(raw, scan$scheme, layout, notes, paired)
  problems <- txtProblemTable(notes, done$leads)
  list(leads = done$leads, problems = problems, title = scan$title, layout = done$layout, text = src)
}

# ---- a first pass by a language model ----------------------------------------

# Leads from a table the model returned: couplet, lead, text, destination
# (or the lead-table names Statement, Choice, Character, Next, Taxon).
txtParseTable <- function(tab, layout) {
  names(tab) <- tolower(names(tab))
  pick <- function(...) {
    hit <- intersect(c(...), names(tab))
    if (length(hit)) {
      v <- as.character(tab[[hit[1]]])
      v[is.na(v)] <- ""
      trimws(v)
    } else {
      NULL
    }
  }
  couplet <- pick("couplet", "statement")
  text <- pick("text", "character")
  dest <- pick("destination", "dest")
  if (is.null(dest) && !is.null(pick("next"))) {
    nx <- pick("next")
    tx <- pick("taxon")
    if (is.null(tx)) tx <- rep("", nrow(tab))
    dest <- ifelse(nzchar(nx) & nx != "-", nx, tx)
  }
  if (is.null(couplet) || is.null(text) || is.null(dest)) {
    stop("The table returned by `llm` needs the columns couplet, lead, text and destination; it has: ",
         paste(names(tab), collapse = ", "), call. = FALSE)
  }
  n <- nrow(tab)
  if (n == 0) stop("No leads were found in what `llm` returned (a table with no rows)", call. = FALSE)
  letter <- pick("lead", "choice")
  if (is.null(letter)) letter <- rep("", n)
  primes <- ifelse(grepl("^'+$", letter), nchar(letter), 0L)
  letter <- tolower(gsub("[^A-Za-z]", "", letter))
  letter[nchar(letter) != 1] <- ""
  couplet <- sub("\\.0+$", "", gsub("[.):]+$", "", couplet))
  scheme <- if (n > 0 && all(grepl("^[A-Z]$", couplet))) "letter" else "number"
  k <- if (scheme == "letter") match(couplet, LETTERS) else suppressWarnings(as.integer(couplet))
  notes <- txtCollector()
  for (i in which(is.na(k))) {
    notes$add(i, i, "problem", "llm_couplet", sprintf("row %d of the model's table has the couplet '%s', which is not a number", i, couplet[i]))
  }
  k[is.na(k)] <- 0L
  couplet[!nzchar(couplet)] <- "?"
  raw <- data.frame(
    couplet = couplet, k = as.integer(k), letter = letter, primes = as.integer(primes), backref = "",
    indent = 0L, line = seq_len(n), kind = "num", text = text, dest = dest,
    sep = "given", stringsAsFactors = FALSE
  )
  done <- txtFinish(raw, scheme, if (layout == "auto") "bracketed" else layout, notes)
  list(leads = done$leads, problems = txtProblemTable(notes, done$leads), title = NA_character_,
       layout = done$layout, text = NULL)
}

txtWords <- function(x, min = 4) {
  w <- unlist(strsplit(tolower(gsub("[^A-Za-z]+", " ", x)), " +"))
  w[nchar(w) >= min]
}

# The source line each lead most likely starts on: the line that holds most of
# its first words and its destination, preferring one that starts with its
# couplet number.
txtLocate <- function(leads, src) {
  low <- tolower(src)
  find <- function(i, w) {
    if (!length(w)) return(NA_integer_)
    hits <- vapply(low, function(l) sum(vapply(w, function(v) grepl(v, l, fixed = TRUE), logical(1))), numeric(1),
                   USE.NAMES = FALSE)
    # In the source a 1 may be l, I or |, and a 0 may be O
    number <- gsub("1", "[1lI|]", gsub("0", "[0O]", leads$Statement[i]), fixed = TRUE)
    labelled <- grepl(paste0("^\\s*", number, "\\s?\\(?[a-hA-H]?[^0-9A-Za-z]"), src)
    lettered <- grepl(paste0("^\\s*", number, "\\s?\\(?", leads$Choice[i], "[^0-9A-Za-z]"), src)
    # the label only decides between lines that hold the words equally well:
    # in a key whose second leads are marked "-" it is on the wrong line
    score <- hits + 0.25 * c(hits[-1], 0) + ifelse(hits > 0, 0.4 * labelled + 0.3 * lettered, 0)
    best <- which.max(score)
    enough <- if (labelled[best]) 1 else max(1, floor(length(w) / 3))
    if (hits[best] >= enough) as.integer(best) else NA_integer_
  }
  vapply(seq_len(nrow(leads)), function(i) {
    # by the words of the lead first: the destination is what is being
    # checked, so it only helps out when the words alone find nothing
    own <- unique(utils::head(txtWords(leads$Character[i], 3), 6))
    at <- if (length(own) >= 2) find(i, own) else NA_integer_
    if (is.na(at)) at <- find(i, unique(c(own, txtWords(leads$Taxon[i], 3))))
    at
  }, integer(1))
}

# What a model sends back is often wrapped in a Markdown code fence, and
# often JSON although text was asked for. Fences are taken off; JSON (an
# array of leads, or an object holding one) becomes a data frame.
txtReadAnswer <- function(answer) {
  if (!is.character(answer) || !length(answer)) return(answer)
  answer <- answer[!is.na(answer)]
  lines <- txtSplitLines(answer)
  lines <- lines[!grepl("^\\s*```", lines)]
  body <- trimws(paste(lines, collapse = "\n"))
  if (!grepl("^[\\[{]", body)) return(lines)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("`llm` returned JSON; install the jsonlite package to read it, or have `llm` return ",
         "text or a data frame", call. = FALSE)
  }
  parsed <- tryCatch(jsonlite::fromJSON(body, simplifyDataFrame = TRUE), error = function(e) {
    stop("`llm` returned JSON that cannot be read (", conditionMessage(e), "). ",
         "It may have been cut off; nothing was taken from it", call. = FALSE)
  })
  if (!is.data.frame(parsed) && is.list(parsed)) {
    tables <- Filter(is.data.frame, parsed)
    if (length(tables)) parsed <- tables[[1]]
  }
  if (!is.data.frame(parsed)) {
    stop("`llm` returned JSON that is not a list of leads with couplet, lead, text and destination", call. = FALSE)
  }
  parsed
}

txtParseLlm <- function(src, llm, layout, skip) {
  answer <- tryCatch(llm(paste(src, collapse = "\n")),
    error = function(e) stop("`llm` failed: ", conditionMessage(e), call. = FALSE))
  answer <- txtReadAnswer(answer)
  if (is.data.frame(answer)) {
    res <- txtParseTable(as.data.frame(answer, stringsAsFactors = FALSE), layout)
    unit <- "row"
  } else if (is.character(answer) && length(answer) > 0 && any(nzchar(trimws(answer)))) {
    res <- txtParseLines(txtSplitLines(answer), layout, skip, keepLeadIndex = TRUE)
    unit <- "line"
  } else {
    stop("`llm` must return text (a string or lines) or a data frame with the columns ",
         "couplet, lead, text and destination", call. = FALSE)
  }
  leads <- res$leads
  problems <- res$problems
  if (nrow(leads) == 0) {
    stop("No leads were found in what `llm` returned", call. = FALSE)
  }

  # Where each lead is in the source; problems are reported by that line
  leads$LlmLine <- leads$Line
  leads$Line <- txtLocate(leads, src)
  hasLead <- !is.na(problems$.lead)
  noLead <- !hasLead & !is.na(problems$Line)
  problems$Message[noLead] <- paste0(problems$Message[noLead], " (", unit, " ", problems$Line[noLead], " of the model's answer)")
  problems$Line[noLead] <- NA_integer_
  problems$Line[hasLead] <- leads$Line[problems$.lead[hasLead]]

  # Compare with the source: invented text, invented taxa, lost leads
  srcText <- paste(src, collapse = "\n")
  srcWords <- unique(c(txtWords(srcText), txtWords(gsub("-\\s*\n\\s*", "", srcText))))
  label <- paste0(leads$Statement, leads$Choice)
  extra <- list()
  for (i in seq_len(nrow(leads))) {
    w <- unique(txtWords(leads$Character[i]))
    if (length(w) >= 1 && mean(w %in% srcWords) < 0.5) {
      extra[[length(extra) + 1]] <- txtProblemRow(leads$Line[i], leads$Statement[i], label[i], "problem", "llm_text",
        sprintf("the text of lead %s (%s %d of the model's answer) is not in the source: '%s'",
                label[i], unit, leads$LlmLine[i], substr(leads$Character[i], 1, 60)))
    }
    w <- unique(txtWords(leads$Taxon[i]))
    if (length(w) && !all(w %in% srcWords)) {
      extra[[length(extra) + 1]] <- txtProblemRow(leads$Line[i], leads$Statement[i], label[i], "problem", "llm_taxon",
        sprintf("lead %s (%s %d of the model's answer) ends in '%s', which is not in the source",
                label[i], unit, leads$LlmLine[i], leads$Taxon[i]))
    }
  }
  # The destination must stand on the lines of the source that the lead was
  # found on: a model that swaps two names, or sends a lead to another
  # couplet, uses only words that are in the source
  # (a lead ends where the next one starts, whether the model returned that
  # one or not)
  starts <- grep("^\\s*[0-9lIO|]{1,3}\\s?\\(?[a-hA-H]?\\s?['.)(:]", src)
  plain <- tryCatch(txtParseLines(src, layout, skip), error = function(e) NULL)
  if (is.null(plain)) plain <- list(leads = data.frame(Line = integer()), title = NA_character_)
  located <- sort(unique(c(leads$Line[!is.na(leads$Line)], starts, plain$leads$Line)))
  squash <- function(v) tolower(gsub("[^A-Za-z0-9]+", " ", gsub("-\\s*\n\\s*", "", v)))
  for (i in which(!is.na(leads$Line))) {
    after <- located[located > leads$Line[i]]
    to <- min(if (length(after)) after[1] - 1L else length(src), leads$Line[i] + 12L)
    region <- squash(paste(src[leads$Line[i]:to], collapse = "\n"))
    if (leads$Next[i] != "-") {
      number <- gsub("1", "[1li|]", gsub("0", "[0o]", leads$Next[i]), fixed = TRUE)
      if (grepl("^[0-9]+$", leads$Next[i]) && !grepl(paste0("(^| )", number, "( |$)"), region)) {
        extra[[length(extra) + 1]] <- txtProblemRow(leads$Line[i], leads$Statement[i], label[i], "problem", "llm_destination",
          sprintf("lead %s (%s %d of the model's answer) leads to couplet %s, but that number is not on the lines of this lead in the source; check it",
                  label[i], unit, leads$LlmLine[i], leads$Next[i]))
      }
    } else if (nzchar(leads$Taxon[i])) {
      w <- unique(txtWords(leads$Taxon[i]))
      if (length(w) && all(w %in% srcWords) && !all(vapply(w, function(v) grepl(v, region, fixed = TRUE), logical(1)))) {
        extra[[length(extra) + 1]] <- txtProblemRow(leads$Line[i], leads$Statement[i], label[i], "problem", "llm_destination",
          sprintf("lead %s (%s %d of the model's answer) ends in '%s', but in the source that name is not on the lines of this lead; check it",
                  label[i], unit, leads$LlmLine[i], leads$Taxon[i]))
      }
    }
  }
  # Lines of the source that look like the start of a lead, however rough
  # and the leads found by reading the source without the model
  if (nrow(plain$leads) > nrow(leads)) starts <- sort(unique(c(starts, plain$leads$Line)))
  if (length(starts) > nrow(leads)) {
    unmatched <- setdiff(starts, leads$Line)
    extra[[length(extra) + 1]] <- txtProblemRow(
      if (length(unmatched)) unmatched[1] else NA_integer_, "", "", "problem", "llm_lost_leads",
      sprintf("the model returned %d lead(s) but %d line(s) of the source look like the start of a lead%s",
              nrow(leads), length(starts),
              if (length(unmatched)) paste0("; no lead was matched to line(s) ", paste(unmatched, collapse = ", ")) else ""))
  }
  if (length(extra)) {
    extra <- do.call(rbind, extra)
    extra$.lead <- NA_integer_
    problems <- rbind(problems, extra)
    problems <- problems[order(match(problems$Kind, c("problem", "repair", "note")), problems$Line), , drop = FALSE]
    rownames(problems) <- NULL
  }
  # the title of the source, not what the model wrote above its answer
  title <- plain$title
  txtResult(leads, problems, title, res$layout, if (is.null(res$text)) src else res$text)
}
