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
    .taxa = NULL
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
    }
  ),
  public = list(
    #' @description Create a new moose object.
    #' @param df Data frame of leads (see the `df` field).
    #' @param desc Key title or description.
    #' @param meta Key/value metadata data frame.
    #' @param taxa Data frame of terminal taxa.
    initialize = function(df, desc = NA, meta = NA, taxa = NA) {
      private$.df <- df
      private$.desc <- desc
      private$.meta <- meta
      private$.taxa <- taxa
    },
    #' @description Print the description, metadata and lead table.
    #' @param ... Unused.
    print = function(...) {
      print(private$.desc)
      print(private$.meta)
      print(private$.df)
      invisible(self)
    },
    #' @description Convert the key to a [data.tree::Node].
    #' @param includeStatementNodes Not yet implemented.
    #' @param includeLoneLeafNodes Not yet implemented.
    toDataTree = function(includeStatementNodes = FALSE, includeLoneLeafNodes = FALSE) {
      private$.df %>%
        dplyr::select("Statement", "Choice", "Character", "pSt", "pCh") %>%
        dplyr::mutate(name = paste0(.data$Statement, .data$Choice)) %>%
        dplyr::mutate(parent = paste0(.data$pSt, .data$pCh)) %>%
        dplyr::distinct() %>%
        dplyr::select("name", "parent", "Character") %>%
        dplyr::mutate(parent = ifelse(.data$parent == "", "1", .data$parent)) ->
      network
      data.tree::FromDataFrameNetwork(network)
    },
    #' @description Convert the key to a polyclave (multi-access key). Not yet
    #'   implemented: currently returns the lead table unchanged.
    #' @param delim Separator between character terms.
    toPolyclave = function(delim = ";") {
      private$.df
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
