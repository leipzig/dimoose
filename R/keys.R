#' Build a dimoose key from a table of leads
#'
#' The common constructor behind [sharkKey()], [arachnidaKey()],
#' [vibrioKey()] and [phylotreeKey()]: takes one row per lead and returns a
#' [dimoose] object.
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
#' @return A [dimoose] object.
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
  dimoose$new(keyPaths(leads, separateTerms = FALSE), desc, meta, taxa, leads = leads, features = features)
}

#' Build a dimoose key from a classification tree
#'
#' Converts an [rpart::rpart()] classification tree into a dichotomous key:
#' every split becomes a couplet with two leads, and every leaf a result.
#' Taxa that the tree cannot separate share a leaf and are listed together
#' (`"A / B"`). A taxon rpart could not send down either side of a split,
#' because the split's variable is missing for it, is listed at every result
#' below that split.
#'
#' @param fit An `rpart` object with `method = "class"`, e.g. from
#'   [generateTree()].
#' @param desc Title of the key.
#' @param meta Key/value metadata data frame.
#' @return A [dimoose] object.
#' @seealso [keyFromMatrix()], which builds a key straight from a character
#'   matrix and handles variable taxa; [vibrioKey()]
#' @examples
#' d <- data.frame(
#'   taxon = factor(c("A", "B", "C")),
#'   wings = factor(c("+", "-", "-")),
#'   spots = factor(c("-", "+", "-"))
#' )
#' fit <- generateTree(d, "taxon")
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
  # A lead reads "character: state". Only the "=" rpart puts after the
  # character's name is replaced, not one in the name or in a state. (Numeric
  # splits keep their historical form, "x< 2" and "x>: 2".)
  lab <- labels(fit, minlength = 0L)
  asked <- as.character(frame$var)[match(node %/% 2L, node)]
  byState <- !is.na(asked) & startsWith(lab, paste0(asked, "="))
  lab[byState] <- paste0(asked[byState], ": ", substring(lab[byState], nchar(asked[byState]) + 2L))
  lab[!byState] <- gsub("=", ": ", lab[!byState], fixed = TRUE)
  members <- split(attr(fit, "ylevels")[fit$y], factor(fit$where, levels = seq_len(nrow(frame))))
  # rpart leaves a row at a split when the split's variable is missing for it
  # and no surrogate places it. Such a taxon could be on either side, so it
  # is listed at every result below that split.
  for (k in which(leaf)) {
    up <- node[k] %/% 2L
    while (up >= 1L) {
      members[[k]] <- c(members[[k]], members[[match(up, node)]])
      up <- up %/% 2L
    }
  }

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
#' Ready-made [dimoose] keys built from the datasets that come with dimoose. All
#' five are ordinary dimoose objects: they share the same fields (`leads`,
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
#'   Noguerola & Blanch (2008) with [keyFromMatrix()] (the matrix itself is
#'   [vibrioMatrix()]). Tests scored `+` or `(+)` count as positive and `-` or
#'   `(-)` as negative. With `variable = "both"` (the default) a species
#'   that is variable for a test (`v`, `d`) is keyed out down both leads of
#'   every couplet that uses the test, and so is a species the test was not
#'   determined for (`ND`): 92 couplets, 74 species, 14 of them reached at
#'   two or three results. With `variable = "missing"` those results are
#'   treated as missing and the key is an rpart classification tree
#'   ([keyFromRpart()]), which places such a species on one side of the test
#'   with surrogate splits: 73 couplets, each species at one result, but a
#'   strain showing the species' other result is keyed out wrongly.
#' - `montanaKey()`: the native broadleaf trees of Montana, written for
#'   dimoose (the [montana] dataset); 10 couplets, 11 species, with photos
#'   from Wikimedia Commons. It is built with [keyFromSpreadsheet()] from
#'   `inst/extdata/montana/montana-key.csv`, a template for writing your own.
#' - [phylotreeKey()]: PhyloTree Build 17.
#'
#' @param variable For `vibrioKey()`: `"both"` (default) keys a species
#'   that is variable for a test out down both leads; `"missing"` treats
#'   variable results as missing. See [keyFromMatrix()].
#' @return A [dimoose] object.
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
#' summary(vibrioKey(variable = "missing"))
#' \dontrun{
#' exportWizard(sharkKey(), "sharks.html")
#' }
#' @name exampleKeys
NULL

#' @rdname exampleKeys
#' @export
sharkKey <- function() {
  dir <- system.file("extdata", "fishbase", package = "dimoose")
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
    dimoose::arachnida,
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
vibrioKey <- function(variable = c("both", "missing")) {
  variable <- match.arg(variable)
  keyFromMatrix(
    vibrioMatrix(),
    variable = variable,
    desc = "Vibrio species (key generated from the Noguerola & Blanch 2008 matrix)",
    meta = data.frame(
      key = "citation",
      value = paste(
        "Noguerola I, Blanch AR (2008). Identification of Vibrio spp. with a set of",
        "dichotomous keys. J Appl Microbiol 105:175-185.",
        if (variable == "both") {
          paste("Key generated with dimoose; species with variable or undetermined",
                "results follow both leads.")
        } else {
          "Key generated with rpart; variable and not determined results treated as missing."
        }
      ),
      stringsAsFactors = FALSE
    )
  )
}

#' @rdname exampleKeys
#' @export
montanaKey <- function() {
  keyFromSpreadsheet(
    system.file("extdata", "montana", "montana-key.csv", package = "dimoose"),
    desc = "Key to the native broadleaf trees of Montana",
    meta = data.frame(
      key = "citation",
      value = paste(
        "Key written for dimoose from the Montana Field Guide (Montana Natural Heritage",
        "Program and Montana Fish, Wildlife & Parks), USDA PLANTS and Virginia Tech",
        "Dendrology. Photos from Wikimedia Commons; authors and licenses in the",
        "package's COPYRIGHTS file."
      ),
      stringsAsFactors = FALSE
    )
  )
}

#' Key to the Orders of Arachnida
#'
#' The key from Triplehorn & Johnson (2005), *Borror and DeLong's
#' Introduction to the Study of Insects*, 7th ed., chapter 5, as a table of
#' leads (see [keyFromLeads()]); [arachnidaKey()] turns it into a [dimoose]
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
#' Blanch (2008), one row per taxon. [vibrioKey()] generates a key from it
#' and [vibrioMatrix()] recodes it for [keyFromMatrix()].
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

#' Key to the native broadleaf trees of Montana
#'
#' A dichotomous key to the eleven native broadleaf (hardwood) trees of
#' Montana, as a table of leads (see [keyFromLeads()]); [montanaKey()] turns it
#' into a [dimoose] key with photos. Written for dimoose: native status was
#' checked in the Montana Field Guide and USDA PLANTS, and every couplet's
#' characters come from Montana Field Guide or Virginia Tech Dendrology
#' descriptions. Common hackberry is left out because the Montana Field Guide
#' gives its origin in Montana as undetermined.
#'
#' @format A data frame with 20 rows (10 couplets) and 7 character columns:
#' \describe{
#'   \item{Statement}{Couplet number.}
#'   \item{Choice}{`a` or `b`.}
#'   \item{Character}{Text of the lead.}
#'   \item{Next}{Couplet the lead leads to, or `"-"`.}
#'   \item{Taxon}{For terminal leads, `"Common name (Genus species)"`.}
#'   \item{Question}{What the couplet asks, e.g. `"Leaf type?"`.}
#'   \item{Image}{Ids of the photos in `inst/extdata/montana/` shown with the
#'     lead, separated by `;`.}
#' }
#' @source Montana Field Guide, Montana Natural Heritage Program and Montana
#'   Fish, Wildlife & Parks, <https://fieldguide.mt.gov>; USDA PLANTS
#'   Database, <https://plants.usda.gov>; Virginia Tech Dendrology fact sheets,
#'   <https://dendro.cnre.vt.edu>. The page for each species and the source of
#'   each couplet are listed in `data-raw/montana/sources.md` in the package
#'   sources.
"montana"
