#' Check a key's species names against GBIF
#'
#' Looks up the scientific name of every result in the key in the
#' [GBIF Backbone Taxonomy](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
#' and reports names that are misspelled, that are synonyms of a name GBIF
#' now accepts, or that GBIF does not know. A result written as
#' `"Common name (Genus species)"` is checked by the name in parentheses;
#' other results are checked when they look like a scientific name.
#'
#' This needs an internet connection: one request to GBIF per name, and one
#' more for each synonym.
#'
#' @param key A [dimoose] key.
#' @param kingdom Optional kingdom ("Plantae", "Animalia", "Fungi", ...),
#'   which helps GBIF tell apart names that are used in more than one
#'   kingdom.
#' @return A data frame with one row per name checked: `Taxon` (as in the
#'   key), `name` (the scientific name checked), `status` (`"ok"`,
#'   `"misspelled"`, `"synonym"`, `"not found"`, or `"unchecked"` when GBIF
#'   could not be reached), `gbif` (the name GBIF matched), `accepted` (the
#'   name GBIF accepts for it), `genus`, `family` and `order` (from GBIF's
#'   classification, used by [identifyPhotos()]) and `note` (what to fix, in
#'   words).
#' @seealso `keyFromSpreadsheet(checkNames = TRUE)`, which runs this check
#'   and reports problems by spreadsheet row.
#' @examples
#' \donttest{
#' checkNames(montanaKey(), kingdom = "Plantae")
#' }
#' @export
checkNames <- function(key, kingdom = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
  name <- scientificPart(taxa)
  bare <- is.na(name)
  name[bare] <- taxa[bare]
  keep <- !bare | isScientificName(name)
  taxa <- taxa[keep]; name <- name[keep]
  out <- data.frame(Taxon = taxa, name = name, status = rep("unchecked", length(name)), gbif = NA_character_,
                    accepted = NA_character_, genus = NA_character_, family = NA_character_, order = NA_character_,
                    note = "", stringsAsFactors = FALSE)
  failed <- character()
  for (i in seq_along(name)) {
    res <- tryCatch({
      m <- gbifMatch(name[i], kingdom)
      acc <- if (identical(m$status, "SYNONYM") && !is.null(m$acceptedUsageKey)) gbifAccepted(m$acceptedUsageKey) else m$canonicalName
      list(m = m, acc = acc)
    }, error = function(e) { failed <<- c(failed, conditionMessage(e)); NULL })
    if (is.null(res)) next
    m <- res$m
    type <- if (is.null(m$matchType)) "NONE" else m$matchType
    if (type %in% c("NONE", "HIGHERRANK")) {
      out$status[i] <- "not found"
      out$note[i] <- paste0(name[i], " is not in GBIF",
                            if (type == "HIGHERRANK" && !is.null(m$canonicalName)) paste0("; GBIF knows only ", m$canonicalName))
      next
    }
    out$gbif[i] <- m$canonicalName
    out$accepted[i] <- res$acc
    for (r in c("genus", "family", "order")) if (!is.null(m[[r]])) out[[r]][i] <- m[[r]]
    synonym <- identical(m$status, "SYNONYM")
    if (type == "FUZZY") {
      out$status[i] <- "misspelled"
      out$note[i] <- paste0(name[i], " is not in GBIF; did you mean ", m$canonicalName, "?",
                            if (synonym) paste0(" (GBIF accepts ", res$acc, " for it)"))
    } else if (synonym) {
      out$status[i] <- "synonym"
      out$note[i] <- paste0(name[i], " is a synonym; GBIF accepts ", res$acc)
    } else {
      out$status[i] <- "ok"
    }
  }
  if (length(failed)) {
    warning(sprintf("Could not check %d name%s with GBIF: %s", length(failed), if (length(failed) == 1) "" else "s",
                    failed[1]), call. = FALSE)
  }
  out
}

#' Suggest which of a key's species a photo shows
#'
#' Compares each photo with the names of the key's results and ranks the
#' results by how well they match, so a photo can be checked against the
#' species the key covers. This works best with a model trained on names of
#' organisms, such as BioCLIP 2 (`visionModel(name = "bioclip-2")`): it
#' recognises a species from its scientific name without being shown any
#' examples. Only the key's own species are considered, which makes the
#' answers much more reliable than asking the model to name a species out of
#' all those it knows.
#'
#' Each result is described by its scientific name when it is written as
#' `"Common name (Genus species)"`, and by the whole result otherwise. The
#' probabilities are a softmax over all the key's results with the
#' temperature CLIP models are trained with (cosine similarity times 100).
#'
#' @param key A [dimoose] key.
#' @inheritParams embedImages
#' @param top How many of the best-matching results to return per photo.
#' @param prompt The text each name is put into, with `%s` where the name
#'   goes. The default is the one BioCLIP was trained with.
#' @return A data frame with `top` rows per image: `image` (its id), `rank`,
#'   `Taxon`, `probability` and `similarity` (cosine similarity).
#' @seealso [identifyPhotos()] for one answer per photo, at the genus or
#'   family when the species is uncertain.
#' @examples
#' \dontrun{
#' model <- visionModel(name = "bioclip-2")
#' suggestSpecies(montanaKey(), model, "my-photo.jpg")
#' }
#' @export
suggestSpecies <- function(key, model, paths, top = 3, prompt = "a photo of %s.") {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  prob <- speciesProbabilities(key, model, paths, prompt)
  sim <- attr(prob, "similarity")
  taxa <- colnames(prob)
  top <- min(as.integer(top), length(taxa))
  rows <- lapply(seq_len(nrow(prob)), function(i) {
    o <- order(-prob[i, ])[seq_len(top)]
    data.frame(image = rownames(prob)[i], rank = seq_len(top), Taxon = taxa[o], probability = unname(prob[i, o]),
               similarity = unname(sim[i, o]), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Name what a photo shows, as precisely as the evidence allows
#'
#' Like [suggestSpecies()], compares each photo with the key's own species,
#' but gives one answer per photo: the species when it alone is likely
#' enough, otherwise the genus, family or order whose species together are.
#' A photo of a cottonwood that the model cannot place between the key's two
#' cottonwoods is reported as genus *Populus* rather than as a coin toss
#' between them.
#'
#' The genus, family and order of each species come from GBIF (see
#' [checkNames()]), which needs an internet connection, or from a table you
#' give in `lineage`. Results with no lineage (for example ones named only by
#' a common name) count only as themselves.
#'
#' @inheritParams suggestSpecies
#' @param confidence The probability an answer must reach, between 0 and 1.
#' @param lineage Optional data frame with columns `Taxon` (as in the key),
#'   `genus`, `family` and `order`, such as the output of [checkNames()].
#' @inheritParams checkNames
#' @return A data frame with one row per image: `image`, `name` (the
#'   scientific name of the answer), `rank` (`"species"`, `"genus"`,
#'   `"family"` or `"order"`), `probability`, `confident` (whether
#'   `probability` reaches `confidence`; when nothing does, the answer is the
#'   most likely species) and `Taxon` (the key's result, for species-level
#'   answers).
#' @examples
#' \dontrun{
#' model <- visionModel(name = "bioclip-2")
#' identifyPhotos(montanaKey(), model, "my-tree.jpg", kingdom = "Plantae")
#' }
#' @export
identifyPhotos <- function(key, model, paths, confidence = 0.8, lineage = NULL, kingdom = NULL,
                           prompt = "a photo of %s.") {
  if (!is.numeric(confidence) || length(confidence) != 1 || is.na(confidence) || confidence <= 0 || confidence > 1) {
    stop("`confidence` must be a probability between 0 and 1", call. = FALSE)
  }
  if (!is.null(lineage) && !all(c("Taxon", "genus", "family", "order") %in% names(lineage))) {
    stop("`lineage` needs the columns Taxon, genus, family and order", call. = FALSE)
  }
  prob <- speciesProbabilities(key, model, paths, prompt)
  if (is.null(lineage)) lineage <- checkNames(key, kingdom)
  taxa <- colnames(prob)
  name <- scientificPart(taxa)
  name[is.na(name)] <- taxa[is.na(name)]
  at <- match(taxa, lineage$Taxon)
  groups <- lapply(c(genus = "genus", family = "family", order = "order"), function(r) lineage[[r]][at])
  reach <- function(p) p >= confidence - 1e-9
  rows <- lapply(seq_len(nrow(prob)), function(i) {
    p <- prob[i, ]
    best <- which.max(p)
    answer <- function(nm, rank, pr, ok, taxon) {
      data.frame(image = rownames(prob)[i], name = nm, rank = rank, probability = unname(pr), confident = ok,
                 Taxon = taxon, stringsAsFactors = FALSE)
    }
    if (reach(p[best])) return(answer(name[best], "species", p[best], TRUE, taxa[best]))
    for (r in names(groups)) {
      g <- groups[[r]]
      if (all(is.na(g))) next
      sums <- tapply(p[!is.na(g)], g[!is.na(g)], sum)
      if (reach(max(sums))) return(answer(names(sums)[which.max(sums)], r, max(sums), TRUE, NA_character_))
    }
    answer(name[best], "species", p[best], FALSE, taxa[best])
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# Probability of each of the key's results for each image: an images x
# results matrix (softmax of cosine similarity x 100), with the similarities
# in its "similarity" attribute.
speciesProbabilities <- function(key, model, paths, prompt) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  if (!grepl("%s", prompt, fixed = TRUE)) stop("`prompt` must contain %s where the species name goes", call. = FALSE)
  taxa <- unique(key$leads$Taxon[!is.na(key$leads$Taxon) & nzchar(key$leads$Taxon)])
  if (!length(taxa)) stop("This key names no results", call. = FALSE)
  name <- scientificPart(taxa)
  name[is.na(name)] <- taxa[is.na(name)]
  img <- embedImages(model, paths, patches = FALSE)$image
  txt <- embedTexts(model, sprintf(prompt, name))
  sim <- img %*% t(txt)
  dimnames(sim) <- list(rownames(img), taxa)
  prob <- exp(100 * (sim - apply(sim, 1, max)))
  prob <- prob / rowSums(prob)
  attr(prob, "similarity") <- sim
  prob
}

# The scientific name in results written "Common name (Genus species)", or NA.
scientificPart <- function(taxa) {
  m <- regmatches(taxa, regexec("^(.*\\S)\\s*\\(([^()]+)\\)$", taxa))
  vapply(m, function(x) if (length(x) == 3) trimws(x[3]) else NA_character_, "")
}

# GBIF's best match for a name (https://techdocs.gbif.org/en/openapi/v1/species).
gbifMatch <- function(name, kingdom = NULL) {
  r <- httr::GET("https://api.gbif.org/v1/species/match", query = list(name = name, kingdom = kingdom),
                 dimooseUserAgent(), httr::timeout(30))
  httr::stop_for_status(r, task = "look up a name in GBIF")
  httr::content(r, as = "parsed", type = "application/json", encoding = "UTF-8")
}

# The canonical name of a GBIF usage key.
gbifAccepted <- function(key) {
  r <- httr::GET(paste0("https://api.gbif.org/v1/species/", key), dimooseUserAgent(), httr::timeout(30))
  httr::stop_for_status(r, task = "look up a name in GBIF")
  httr::content(r, as = "parsed", type = "application/json", encoding = "UTF-8")$canonicalName
}
