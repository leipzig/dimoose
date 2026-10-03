#' A dichotomous key
#'
#' @description
#' An R6 object holding a dichotomous key as a table of the leads on every
#' path from the root to a terminal taxon. Usually created by
#' [importFishbase()] or [parseFishbase()]. See
#' <https://www.fishbase.se/keys/allkeys.php> for FishBase keys.
#'
#' @field desc Key title or description (read-only).
#' @field df Data frame with one row per lead (or per term, if terms were
#'   separated) per terminal taxon, with columns `Statement`, `Choice`,
#'   `Character`, `Taxon`, and `pSt`/`pCh` for the parent lead.
#' @field meta Key/value data frame of metadata (citation, image URLs, ...).
#' @field taxa Data frame of terminal taxa and their resolved names.
#' @field leads Data frame with one row per lead: `Statement`, `Choice`,
#'   `Character`, `Next` (next couplet, or `"-"` if terminal) and `Taxon`,
#'   plus optional `Prev`, `Image`, `ImageLink`, `TaxonUrl`, `Question`,
#'   `Feature`, `Test` and `Threshold`. Derived from `df` when the object
#'   was created without one.
#' @field features Data frame of features a machine can compute, one per
#'   row (see [featureTable()]), or `NULL` for keys meant only for people.
#' @export
moose <- R6::R6Class("moose",
  lock_objects = FALSE,
  lock_class = TRUE,
  portable = TRUE,
  class = TRUE,
  cloneable = TRUE,
  private = list(
    .desc = NA,
    .df = NULL,
    .meta = NULL,
    .taxa = NULL,
    .leads = NULL,
    .features = NULL
  ),
  active = list(
    desc = function(value) {
      if (missing(value)) {
        private$.desc
      } else {
        stop("`$desc` is read only", call. = FALSE)
      }
    },
    df = function(value) {
      if (missing(value)) {
        private$.df
      } else {
        stopifnot(is.data.frame(value), nrow(value) > 0)
        private$.df <- value
        self
      }
    },
    meta = function(value) {
      if (missing(value)) {
        private$.meta
      } else {
        stopifnot(is.data.frame(value), nrow(value) > 0)
        private$.meta <- value
        self
      }
    },
    taxa = function(value) {
      if (missing(value)) {
        private$.taxa
      } else {
        stopifnot(is.data.frame(value), nrow(value) > 0)
        private$.taxa <- value
        self
      }
    },
    leads = function(value) {
      if (missing(value)) {
        if (is.null(private$.leads)) leadsFromPaths(private$.df) else private$.leads
      } else {
        stopifnot(is.data.frame(value), nrow(value) > 0)
        private$.leads <- value
        self
      }
    },
    features = function(value) {
      if (missing(value)) {
        private$.features
      } else {
        stopifnot(is.null(value) || is.data.frame(value))
        private$.features <- value
        self
      }
    }
  ),
  public = list(
    #' @description Create a new moose object.
    #' @param df Data frame of leads (see the `df` field).
    #' @param desc Key title or description.
    #' @param meta Key/value metadata data frame.
    #' @param taxa Data frame of terminal taxa.
    #' @param leads Optional data frame of leads (see the `leads` field).
    #' @param features Optional data frame of machine-readable features (see
    #'   [featureTable()]).
    initialize = function(df, desc = NA, meta = NA, taxa = NA, leads = NULL, features = NULL) {
      private$.df <- df
      private$.desc <- desc
      private$.meta <- meta
      private$.taxa <- taxa
      private$.leads <- leads
      private$.features <- features
    },
    #' @description Print a short overview of the key.
    #' @param ... Unused.
    print = function(...) {
      s <- self$summary()
      cat("<moose key> ", if (is.na(s$title)) "(untitled)" else s$title, "\n", sep = "")
      cat(sprintf("  %d couplets, %d leads, %d taxa, up to %d steps deep\n",
        s$couplets, s$leads, s$taxa, s$depth))
      if (s$problems > 0) cat(sprintf("  %d problem(s): see $validate()\n", s$problems))
      invisible(self)
    },
    #' @description Counts describing the key.
    #' @return A one-row data frame: `title`, `couplets`, `leads`, `taxa`,
    #'   `depth` (longest path in steps) and `problems` (see `validate()`).
    summary = function() {
      leads <- normalizeLeads(self$leads)
      check <- checkLeads(leads)
      parentLead <- match(leads$Statement, leads$Next)
      terminal <- which(leads$Next == "-")
      depth <- if (length(terminal)) max(vapply(terminal, function(i) length(pathToLead(leads, i, check$root, parentLead)), 0L)) else 0L
      data.frame(
        title = if (length(private$.desc) == 1) as.character(private$.desc) else NA_character_,
        couplets = length(check$couplets),
        leads = nrow(leads),
        taxa = length(unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])),
        depth = as.integer(depth),
        problems = length(check$problems),
        stringsAsFactors = FALSE
      )
    },
    #' @description Check the key: leads to missing couplets, terminal leads
    #'   without a taxon, couplets with fewer than two leads, couplets that
    #'   cannot be reached from the first one, and (for keys with features)
    #'   leads whose machine test is missing or inconsistent.
    #' @return A character vector of problems, invisibly if there are none.
    validate = function() {
      leads <- normalizeLeads(self$leads)
      problems <- c(checkLeads(leads)$problems, checkFeatures(leads, private$.features))
      if (length(problems)) problems else invisible(character())
    },
    #' @description Convert the key to a [data.tree::Node]: couplets are
    #'   internal nodes and taxa leaves; each child node carries the `lead`
    #'   label and the `character` text of the lead that leads to it. A
    #'   couplet reached from several leads is attached under the first.
    toDataTree = function() {
      leads <- normalizeLeads(self$leads)
      check <- checkLeads(leads)
      label <- leadLabels(leads)
      root <- data.tree::Node$new(check$root)
      nodes <- list()
      nodes[[check$root]] <- root
      queue <- check$root
      while (length(queue)) {
        cp <- queue[1]
        queue <- queue[-1]
        parent <- nodes[[cp]]
        for (i in which(leads$Statement == cp)) {
          nx <- leads$Next[i]
          if (nx == "-") {
            name <- if (nzchar(leads$Taxon[i])) leads$Taxon[i] else label[i]
            if (name %in% names(parent$children)) name <- paste0(name, " (", label[i], ")")
            parent$AddChild(dataTreeSafeName(name, parent), label = name, lead = label[i], character = leads$Character[i], taxon = TRUE)
          } else if (nx %in% check$couplets && is.null(nodes[[nx]])) {
            nodes[[nx]] <- parent$AddChild(dataTreeSafeName(nx, parent), label = nx, lead = label[i], character = leads$Character[i], taxon = FALSE)
            queue <- c(queue, nx)
          }
        }
      }
      root
    },
    #' @description Write the key's topology in Newick format, with couplets
    #'   as internal node labels and taxa as leaves (labels quoted when
    #'   needed). A couplet reached from several leads is placed under the
    #'   first.
    #' @return A single string ending in `;`.
    toNewick = function() {
      leads <- normalizeLeads(self$leads)
      check <- checkLeads(leads)
      quote <- function(x) {
        if (grepl("^[A-Za-z0-9_.*-]+$", x)) x else paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
      }
      byCouplet <- split(seq_len(nrow(leads)), factor(leads$Statement, levels = check$couplets))
      placed <- new.env()
      newick <- function(cp) {
        assign(cp, TRUE, envir = placed)
        kids <- character()
        for (i in byCouplet[[cp]]) {
          nx <- leads$Next[i]
          if (nx == "-") {
            kids <- c(kids, quote(if (nzchar(leads$Taxon[i])) leads$Taxon[i] else leadLabels(leads[i, ])))
          } else if (nx %in% check$couplets && !exists(nx, envir = placed, inherits = FALSE)) {
            kids <- c(kids, newick(nx))
          }
        }
        paste0(if (length(kids)) paste0("(", paste(kids, collapse = ","), ")") else "", quote(cp))
      }
      paste0(newick(check$root), ";")
    }
  )
)


#' Raw FishBase key tables
#'
#' @description
#' An R6 object holding a FishBase key's description and its couplet table as
#' downloaded, before conversion to a [moose] object.
#'
#' @field desc Key title (read-only).
#' @field df The key's couplet table: one row per lead, with columns
#'   `Statement`, `Choice`, `Character`, `Next`, `Prev` and `Taxon`.
#' @export
rawhtml <- R6::R6Class("rawhtml",
  lock_objects = FALSE,
  lock_class = TRUE,
  portable = TRUE,
  class = TRUE,
  cloneable = TRUE,
  private = list(
    .desc = NA,
    .df = NULL,
    .meta = NULL
  ),
  active = list(
    desc = function(value) {
      if (missing(value)) {
        private$.desc
      } else {
        stop("`$desc` is read only", call. = FALSE)
      }
    },
    df = function(value) {
      if (missing(value)) {
        private$.df
      } else {
        stopifnot(is.data.frame(value), nrow(value) > 0)
        private$.df <- value
        self
      }
    }
  ),
  public = list(
    #' @description Print the description, table and metadata.
    #' @param ... Unused.
    print = function(...) {
      print(private$.desc)
      print(private$.df)
      print(private$.meta)
      invisible(self)
    },
    #' @description Download a FishBase key.
    #' @param keycode FishBase key code.
    #' @param fishbaseUrl Base URL of the FishBase mirror.
    #' @param separateTerms Ignored; kept for backward compatibility.
    initialize = function(keycode, fishbaseUrl = "https://www.fishbase.se/", separateTerms = TRUE) {
      pages <- fetchFishbasePages(keycode, fishbaseUrl)
      private$.desc <- parseFishbaseDescription(pages$description)$desc
      private$.df <- parseFishbaseKeyTable(pages$questions)
    }
  )
)

# Rebuild a lead table from the path table (`moose$df`): one row per lead,
# with Next taken from the leads whose parent is this lead.
leadsFromPaths <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(data.frame(
      Statement = character(), Choice = character(), Character = character(),
      Next = character(), Taxon = character(), stringsAsFactors = FALSE
    ))
  }
  leadKey <- paste(df$Statement, df$Choice, sep = "\r")
  parentKey <- paste(df$pSt, df$pCh, sep = "\r")
  keys <- unique(leadKey)
  rows <- lapply(keys, function(k) {
    here <- df[leadKey == k, , drop = FALSE]
    children <- unique(df$Statement[parentKey == k])
    terminal <- length(children) == 0
    data.frame(
      Statement = here$Statement[1],
      Choice = here$Choice[1],
      Character = paste(unique(here$Character), collapse = "; "),
      Next = if (terminal) "-" else children[1],
      Taxon = if (terminal) unique(here$Taxon)[1] else "",
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  ord <- order(suppressWarnings(as.numeric(out$Statement)), out$Statement, out$Choice)
  out <- out[ord, , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' @export
summary.moose <- function(object, ...) {
  object$summary()
}
