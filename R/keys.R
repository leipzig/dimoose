#' Build a moose key from a table of leads
#'
#' The common constructor behind [sharkKey()], [arachnidaKey()],
#' [vibrioKey()] and [phylotreeKey()]: takes one row per lead and returns a
#' [moose] object.
#'
#' @param leads Data frame with columns `Statement` (couplet), `Choice`,
#'   `Character` (the lead's text), `Next` (next couplet, or `"-"` if the lead
#'   ends in a result) and `Taxon` (the result, for terminal leads). Optional
#'   columns `Label`, `Image`, `ImageLink` and `TaxonUrl` are used by
#'   [exportWizard()]; any others are kept.
#' @param desc Title or description of the key.
#' @param meta Key/value data frame of metadata (e.g. `citation`).
#' @param taxa Data frame of results with `submitted_name` and
#'   `matched_name`; by default every taxon matches itself.
#' @param features Optional [featureTable()] for keys a machine can follow
#'   (the leads then also carry `Feature`, `Test` and `Threshold`).
#' @return A [moose] object.
#' @examples
#' leads <- data.frame(
#'   Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
#'   Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
#'   Next = c("2", "-", "-", "-"), Taxon = c("", "Apterygota", "Diptera", "Other")
#' )
#' k <- keyFromLeads(leads, "A tiny key")
#' k
#' k$toNewick()
#' @export
keyFromLeads <- function(leads, desc = NA, meta = NULL, taxa = NULL, features = NULL) {
  if (!is.data.frame(leads)) stop("`leads` must be a data frame", call. = FALSE)
  missing <- setdiff(c("Statement", "Choice", "Character", "Next", "Taxon"), names(leads))
  if (length(missing)) {
    stop("`leads` is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  leads <- as.data.frame(leads, stringsAsFactors = FALSE)
  for (col in c("Statement", "Choice", "Character", "Next", "Taxon")) {
    x <- as.character(leads[[col]])
    x[is.na(x)] <- ""
    leads[[col]] <- x
  }
  leads$Next[leads$Next == ""] <- "-"
  if (is.null(meta)) {
    meta <- data.frame(key = character(), value = character(), stringsAsFactors = FALSE)
  }
  if (is.null(taxa)) {
    tx <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
    taxa <- data.frame(submitted_name = tx, matched_name = tx, stringsAsFactors = FALSE)
  }
  if (!is.null(leads$Threshold)) leads$Threshold <- as.numeric(leads$Threshold)
  moose$new(keyPaths(leads, separateTerms = FALSE), desc, meta, taxa, leads = leads, features = features)
}

#' Build a moose key from a classification tree
#'
#' Converts an [rpart::rpart()] classification tree into a dichotomous key:
#' every split becomes a couplet with two leads, and every leaf a result.
#' Taxa that the tree cannot separate share a leaf and are listed together
#' (`"A / B"`).
#'
#' @param fit An `rpart` object with `method = "class"`, e.g. from
#'   [generateTree()].
#' @param desc Title of the key.
#' @param meta Key/value metadata data frame.
#' @return A [moose] object.
#' @seealso [vibrioKey()]
#' @examples
#' d <- data.frame(
#'   taxon = factor(c("A", "B", "C")),
#'   wings = factor(c("+", "-", "-")),
#'   spots = factor(c("-", "+", "-"))
#' )
#' fit <- generateTree(d, "taxon",
#'   params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0)))
#' keyFromRpart(fit, "Three taxa")$leads
#' @export
keyFromRpart <- function(fit, desc = "Key generated from a classification tree", meta = NULL) {
  if (!inherits(fit, "rpart") || is.null(attr(fit, "ylevels"))) {
    stop("`fit` must be a classification rpart tree", call. = FALSE)
  }
  frame <- fit$frame
  node <- as.integer(rownames(frame))
  leaf <- frame$var == "<leaf>"
  if (all(leaf)) stop("The tree has no splits", call. = FALSE)
  if (is.null(fit$y)) stop("Refit with y = TRUE so leaf members are known", call. = FALSE)
  lab <- gsub("=", ": ", labels(fit, minlength = 0L), fixed = TRUE)
  members <- split(attr(fit, "ylevels")[fit$y], factor(fit$where, levels = seq_len(nrow(frame))))

  internal <- node[!leaf]
  number <- stats::setNames(as.character(seq_along(internal)), internal)
  rows <- lapply(internal, function(n) {
    kids <- match(c(2L * n, 2L * n + 1L), node)
    data.frame(
      Statement = number[[as.character(n)]],
      Choice = c("a", "b"),
      Character = lab[kids],
      Next = ifelse(leaf[kids], "-", number[as.character(node[kids])]),
      Taxon = vapply(kids, function(k) {
        if (!leaf[k]) return("")
        paste(sort(unique(members[[k]])), collapse = " / ")
      }, character(1)),
      stringsAsFactors = FALSE
    )
  })
  keyFromLeads(do.call(rbind, rows), desc, meta)
}

#' Example keys
#'
#' Ready-made [moose] keys built from the datasets that come with moose. All
#' four are ordinary moose objects: they share the same fields (`leads`,
#' `df`, `meta`, `taxa`, `desc`) and methods (`print()`, `summary()`,
#' `validate()`, `toDataTree()`, `toNewick()`) and all work with
#' [exportWizard()].
#'
#' - `sharkKey()`: FishBase key 1, *Key to the families of sharks in the
#'   Western Central Pacific* (Compagno 1998), from saved FishBase pages in
#'   `inst/extdata/fishbase/`; 23 couplets, 24 families.
#' - `arachnidaKey()`: the *Key to the Orders of Arachnida* from Triplehorn &
#'   Johnson (2005), the [arachnida] dataset; 11 couplets, 11 orders
#'   (Schizomida is reached from two couplets).
#' - `vibrioKey()`: a key generated from the [vibrio] consensus matrix of
#'   Noguerola & Blanch (2008) with [keyFromRpart()]. Tests scored `+` or
#'   `(+)` count as positive and `-` or `(-)` as negative; variable (`v`,
#'   `d`) and not determined (`ND`) results are treated as missing, and rpart
#'   routes a species past such a test with surrogate splits, so a species
#'   that varies for a test appears on only one side of it. Species the tests
#'   cannot separate share a result.
#' - [phylotreeKey()]: PhyloTree Build 17.
#'
#' @return A [moose] object.
#' @references
#' Compagno LJV (1998). General remarks. In Carpenter KE, Niem VH (eds.),
#' *FAO species identification guide for fishery purposes. The living marine
#' resources of the Western Central Pacific*, vol. 2, pp. 1196-1207. FAO,
#' Rome. FishBase key 1: <https://www.fishbase.se/keys/description.php?keycode=1>.
#'
#' Triplehorn CA, Johnson NF (2005). *Borror and DeLong's Introduction to the
#' Study of Insects*, 7th ed., chapter 5. Thomson Brooks/Cole. ISBN
#' 0-03-096835-6.
#'
#' Noguerola I, Blanch AR (2008). Identification of *Vibrio* spp. with a set
#' of dichotomous keys. *Journal of Applied Microbiology* 105, 175-185.
#' \doi{10.1111/j.1365-2672.2008.03730.x}
#' @examples
#' sharks <- sharkKey()
#' sharks
#' summary(arachnidaKey())
#' vibrioKey()$validate()
#' \dontrun{
#' exportWizard(sharkKey(), "sharks.html")
#' }
#' @name exampleKeys
NULL

#' @rdname exampleKeys
#' @export
sharkKey <- function() {
  dir <- system.file("extdata", "fishbase", package = "moose")
  parseFishbase(
    file.path(dir, "key1-description.html"),
    file.path(dir, "key1-questions.html"),
    usePhyloService = "none"
  )
}

#' @rdname exampleKeys
#' @export
arachnidaKey <- function() {
  keyFromLeads(
    moose::arachnida,
    desc = "Key to the Orders of Arachnida",
    meta = data.frame(
      key = "citation",
      value = paste(
        "Triplehorn CA, Johnson NF (2005). Borror and DeLong's Introduction to",
        "the Study of Insects, 7th ed., chapter 5. Thomson Brooks/Cole."
      ),
      stringsAsFactors = FALSE
    )
  )
}

#' @rdname exampleKeys
#' @export
vibrioKey <- function() {
  matrix <- moose::vibrio
  score <- function(x) {
    factor(ifelse(x %in% c("+", "(+)"), "+", ifelse(x %in% c("-", "(-)"), "-", NA)), levels = c("+", "-"))
  }
  tests <- names(matrix)[-1]
  data <- data.frame(species = factor(matrix$species), lapply(matrix[tests], score), check.names = FALSE)
  fit <- rpart::rpart(
    stats::reformulate(paste0("`", tests, "`"), response = "species"),
    data = data, method = "class", y = TRUE,
    control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0, xval = 0, maxcompete = 0)
  )
  keyFromRpart(
    fit,
    desc = "Vibrio species (key generated from the Noguerola & Blanch 2008 matrix)",
    meta = data.frame(
      key = "citation",
      value = paste(
        "Noguerola I, Blanch AR (2008). Identification of Vibrio spp. with a set of",
        "dichotomous keys. J Appl Microbiol 105:175-185. Key generated with rpart;",
        "variable and not determined results treated as missing."
      ),
      stringsAsFactors = FALSE
    )
  )
}

#' Key to the Orders of Arachnida
#'
#' The key from Triplehorn & Johnson (2005), *Borror and DeLong's
#' Introduction to the Study of Insects*, 7th ed., chapter 5, as a table of
#' leads (see [keyFromLeads()]); [arachnidaKey()] turns it into a [moose]
#' key. Transcribed by hand from the book.
#'
#' @format A data frame with 22 rows (11 couplets) and 6 columns:
#' \describe{
#'   \item{Statement}{Couplet number.}
#'   \item{Choice}{`a` for the first lead (`1.`), `b` for the second (`1'.`).}
#'   \item{Character}{Text of the lead.}
#'   \item{Next}{Couplet the lead leads to, or `"-"`.}
#'   \item{Taxon}{Order the lead ends in, for terminal leads.}
#'   \item{Page}{Page of the book where that order is treated.}
#' }
#' @source Triplehorn CA, Johnson NF (2005). *Borror and DeLong's
#'   Introduction to the Study of Insects*, 7th ed. Thomson Brooks/Cole.
#'   Transcription: `data-raw/arachnida/` in the package sources.
"arachnida"

#' Vibrio consensus identification matrix
#'
#' Biochemical and growth test results for 74 *Vibrio* taxa from Noguerola &
#' Blanch (2008), one row per taxon. [vibrioKey()] generates a key from it.
#'
#' @format A data frame with 74 rows and 46 columns: `species`, then 45 tests
#'   coded as in the paper: `+` positive, `-` negative, `(+)` / `(-)` mostly
#'   positive / negative, `v` or `d` variable, `ND` not determined (and one
#'   blank cell in the source, `NA`). Tests under the paper's "Acid from" and
#'   "Resistance to" headings are named with that prefix.
#' @source Noguerola I, Blanch AR (2008). Identification of *Vibrio* spp.
#'   with a set of dichotomous keys. *Journal of Applied Microbiology* 105,
#'   175-185. \doi{10.1111/j.1365-2672.2008.03730.x}. Extracted from the
#'   paper's table; see `data-raw/vibrio/` in the package sources.
"vibrio"
