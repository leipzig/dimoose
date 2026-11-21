#' Prune a key to some of its taxa
#'
#' Keeps only the taxa you name (or removes the ones you name) and tidies up
#' what is left: leads that no longer reach any kept taxon are removed, and a
#' couplet that no longer splits anything is taken out, with the lead that
#' led to it now leading straight to where its one remaining lead went.
#' Collapses are repeated until every couplet again has at least two leads
#' going to different places, so chains of couplets, couplets reached from
#' several leads and the first couplet of the key are all handled.
#'
#' The leads that remain keep their text, their order and (unless
#' `renumber = TRUE`) their couplet names, so every kept taxon is reached by
#' the same leads as before, less the ones that no longer decide anything.
#' Pruning in two steps gives the same key as pruning once to the taxa kept
#' by both.
#'
#' @section Matching taxa:
#' Names are compared without regard to case or extra spaces, and the
#' multiplication sign of a hybrid may be typed as a lower-case `x`
#' (`"Populus x acuminata"`). An entry of `keep` or `drop` matches a taxon of
#' the key when it equals the taxon's whole label
#' (`"Bur oak (Quercus macrocarpa)"`), the scientific name in its
#' parentheses (`"Quercus macrocarpa"`) or the common name before them
#' (`"Bur oak"`); entries may themselves be written with or without a common
#' name.
#'
#' With `ranks = "genus"` (the default) a name also stands for what lies
#' below it, judged by the words the names begin with:
#' * a genus in `keep` or `drop` (`"Populus"`) matches every species of that
#'   genus in the key, and a species (`"Populus balsamifera"`) matches its
#'   subspecies and varieties (`"Populus balsamifera subsp. trichocarpa"`);
#' * a name matches the same name followed by its author
#'   (`"Quercus macrocarpa"` and `"Quercus macrocarpa Michx."`, or
#'   `"Carcharodon carcharias (Linnaeus, 1758)"`), whichever of the two has
#'   the author;
#' * a species in `keep` (`"Quercus macrocarpa"`) keeps a result of the key
#'   that is only its genus (`"Quercus"`), and a subspecies keeps its
#'   species. This is not done for `drop`: removing one species does not
#'   remove its genus.
#'
#' With `ranks = "exact"` only whole labels, scientific names and common
#' names match.
#' Families and higher ranks cannot be told from a name, so a result such as
#' `"Salicaceae"` is matched only by itself, and a synonym is a different
#' name; [regionalKey()] asks GBIF or iNaturalist instead and so works at any
#' rank and through synonyms.
#'
#' @section Shared results:
#' A result that names several taxa the key cannot tell apart, written
#' `"A / B"` as [keyFromRpart()] and [keyFromMatrix()] write them, is treated
#' as the taxa `A` and `B`: each can be kept or dropped by its own name, and
#' when only `A` is kept the result becomes `"A"`. Naming the whole result
#' (`"A / B"`) keeps or drops all of it. (A label with a common name, such as
#' `"Aspen / Popple (Populus tremuloides)"`, is one taxon.)
#'
#' @section What happens to the removed couplet's character:
#' When a couplet is taken out, the text of its one remaining lead still
#' describes the taxa beyond it, and is useful for confirming an
#' identification. With `note = "column"` (the default) it is added to a
#' `Note` column on the lead that now skips the couplet; with
#' `note = "append"` it is added to that lead's `Character` in square
#' brackets, so it shows wherever the key is displayed; with `note = "none"`
#' it is discarded. Whatever `note` is, the removed lead's pictures (`Image`
#' and `ImageLink`) are added to those of the lead that now skips the
#' couplet. When the first couplet of the key is taken out there is no lead
#' to carry the text: it goes in the key's metadata as `pruned_note` (added
#' to any that is already there), and its pictures are left out.
#'
#' @param key A [dimoose] key.
#' @param keep Taxa to keep; all others are removed. `NULL` keeps all.
#' @param drop Taxa to remove (after `keep` has been applied).
#' @param ranks `"genus"` or `"exact"`; see 'Matching taxa'.
#' @param note `"column"`, `"append"` or `"none"`; see 'What happens to the
#'   removed couplet's character'.
#' @param renumber If `TRUE`, number the remaining couplets 1, 2, 3, ... in
#'   reading order (each couplet followed by the couplets its leads go to,
#'   first lead first). If `FALSE`, couplets keep their names.
#' @return A [dimoose] key with the same columns in its leads as `key`
#'   (plus `Note` if a note was written). Embedded images, taxa and features
#'   that no remaining lead uses are left out. It is an error if no result is
#'   left, or only one (a key needs two results to tell apart).
#' @seealso [regionalKey()] to prune to the taxa recorded in a place,
#'   [mergeKeys()] to go the other way.
#' @examples
#' cottonwoods <- pruneKey(montanaKey(), keep = "Populus")
#' cottonwoods
#' cottonwoods$leads[, c("Statement", "Choice", "Next", "Taxon")]
#'
#' # names can be given with or without the common name
#' k <- pruneKey(montanaKey(), drop = c("Acer negundo", "Bur oak (Quercus macrocarpa)"),
#'               renumber = TRUE)
#' k$validate()
#' k$leads$Note
#' @export
pruneKey <- function(key, keep = NULL, drop = NULL, ranks = c("genus", "exact"),
                     note = c("column", "append", "none"), renumber = FALSE) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  ranks <- match.arg(ranks)
  note <- match.arg(note)
  for (arg in c("keep", "drop")) {
    value <- get(arg)
    if (!is.null(value) && !is.character(value) && !is.factor(value)) {
      stop("`", arg, "` must be a character vector of taxon names", call. = FALSE)
    }
  }
  leads <- as.data.frame(key$leads, stringsAsFactors = FALSE)
  if (!nrow(leads)) stop("This key has no leads", call. = FALSE)
  norm <- normalizeLeads(leads)
  leads$Statement <- norm$Statement
  leads$Next <- norm$Next
  leads$Taxon <- norm$Taxon
  hadNote <- !is.null(leads$Note)
  root <- checkLeads(norm)$root
  terminal <- leads$Next == "-"
  labels <- unique(leads$Taxon[terminal & nzchar(leads$Taxon)])
  if (!length(labels)) stop("This key names no taxa", call. = FALSE)

  # A shared result "A / B" is the taxa A and B; `wanted` is per taxon. A
  # whole result is named only by its whole label: matched by rank, "A"
  # would name "A / B" as if that were a subspecies of A.
  members <- prnMembers(labels)
  taxa <- unique(unlist(members))
  inLabel <- function(hitLabels) taxa %in% unlist(members[hitLabels])
  wanted <- rep(TRUE, length(taxa))
  if (!is.null(keep)) {
    byTaxon <- prnMatchTaxa(taxa, keep, ranks, genusOfSpecies = TRUE)
    byLabel <- prnMatchTaxa(labels, keep, "exact")
    prnWarnUnmatched(byTaxon$used | byLabel$used, "keep")
    wanted <- byTaxon$taxa | inLabel(byLabel$taxa)
  }
  if (!is.null(drop)) {
    byTaxon <- prnMatchTaxa(taxa, drop, ranks, genusOfSpecies = FALSE)
    byLabel <- prnMatchTaxa(labels, drop, "exact")
    prnWarnUnmatched(byTaxon$used | byLabel$used, "drop")
    wanted <- wanted & !(byTaxon$taxa | inLabel(byLabel$taxa))
  }
  # what each result is called now: the kept taxa of a shared result
  newLabel <- vapply(seq_along(labels), function(i) {
    ok <- members[[i]] %in% taxa[wanted]
    if (all(ok)) labels[i] else paste(members[[i]][ok], collapse = " / ")
  }, "")
  left <- unique(newLabel[nzchar(newLabel)])
  if (!length(left)) stop("No taxon of the key is left after pruning", call. = FALSE)
  if (length(left) == 1) {
    stop("Only one ", if (length(prnMembers(left)[[1]]) > 1) "result" else "taxon", " is left after pruning (", left,
         "), so there is nothing to key out", call. = FALSE)
  }
  leads$Taxon[terminal] <- ifelse(nzchar(leads$Taxon[terminal]), newLabel[match(leads$Taxon[terminal], labels)], "")

  # Leads that still reach a kept taxon: the kept terminal leads, then every
  # lead into a couplet that has such a lead, until nothing more is added.
  alive <- terminal & nzchar(leads$Taxon)
  repeat {
    more <- !alive & !terminal & leads$Next %in% leads$Statement[alive]
    if (!any(more)) break
    alive <- alive | more
  }
  leads <- leads[alive, , drop = FALSE]
  leads <- leads[leads$Statement %in% prnReachable(leads, root), , drop = FALSE]
  if (!nrow(leads)) stop("No kept taxon can be reached from the first couplet of the key", call. = FALSE)

  collapsed <- prnCollapse(leads, root, note)
  leads <- collapsed$leads
  root <- collapsed$root
  if (!nrow(leads) || length(unique(leads$Statement)) == 0) {
    stop("Only one result can still be reached after pruning, so there is nothing to key out", call. = FALSE)
  }
  # a Note column that says nothing is not added to a key that had none
  if (!hadNote && !is.null(leads$Note) && !any(nzchar(leads$Note))) leads$Note <- NULL
  if (!is.null(leads$Prev)) leads$Prev <- prnPrev(leads, root)
  if (isTRUE(renumber)) leads <- prnRenumber(leads, root)
  rownames(leads) <- NULL

  left <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
  meta <- prnDropImages(key$meta, key$leads, leads)
  if (length(collapsed$rootNotes)) {
    before <- metaValue(meta, "pruned_note")
    meta <- prnSetMeta(meta, "pruned_note", paste(c(if (!is.na(before) && nzchar(before)) before, collapsed$rootNotes),
                                                  collapse = "; "))
  }
  keyFromLeads(leads, key$desc, meta, prnSubsetTaxa(key$taxa, left), prnSubsetFeatures(key$features, leads))
}

#' A key to the taxa recorded in a place
#'
#' Asks [GBIF](https://www.gbif.org) or [iNaturalist](https://www.inaturalist.org)
#' which of the key's taxa have been recorded in a place and prunes the key
#' to those with [pruneKey()]: the key to the trees of Flathead County from
#' a key to the trees of Montana, in one line.
#'
#' Each result of the key is looked up by the scientific name in its
#' parentheses (`"Bur oak (Quercus macrocarpa)"`), or by the whole result
#' when there is none; the taxa of a shared result (`"A / B"`) are looked up
#' one by one, and the result keeps those that are recorded. The key's names
#' need not be the source's: a synonym is counted under the name the source
#' accepts for it, and the result keeps the key's own label. Results at any
#' rank work: a genus or a family counts the records of all its species.
#'
#' The sources are asked one taxon at a time, so a key of 70 taxa takes about
#' 150 requests of GBIF (about half a minute). If a request fails, it is an
#' error that says which taxon was being asked about, and nothing is pruned.
#'
#' @section GBIF:
#' Each name is matched to the GBIF Backbone (`/v1/species/match`) and its
#' occurrences in the place are counted (`/v1/occurrence/search` with
#' `limit=0`), two requests per taxon. A synonym is counted under its
#' accepted name, and a species that GBIF files under one of its subspecies
#' is counted as the species. A name GBIF has in more than one kingdom is
#' settled by `kingdom`, or, for a genus, by taking the accepted genus.
#' Only records with `occurrenceStatus=PRESENT` are counted. `place` can be
#' * a [GADM](https://gadm.org) id, such as `"USA.27.15_1"` for Flathead
#'   County, Montana, or `"USA.27_1"` for Montana (`gadmGid`);
#' * a two-letter country code, such as `"CH"` (`country`);
#' * a polygon in WKT, `"POLYGON((...))"`, with its points anticlockwise
#'   (`geometry`);
#' * a named list of GBIF occurrence search parameters, used as they are,
#'   such as `list(country = "US", stateProvince = "Montana")`;
#' * the name of a region, looked up in GADM (`/v1/geocode/gadm/search`).
#'   Add the regions it lies in after commas to tell places of the same name
#'   apart: `"Flathead County, Montana"`, `"Flathead County, MT"`,
#'   `"Montana, USA"`. A name that still fits several regions, or none, is
#'   an error that lists the regions GADM has with their ids; give the id of
#'   the one you mean. The message printed at the end names the region used.
#'
#' @section iNaturalist:
#' The place is found with `/v1/places/autocomplete` (or give its numeric
#' id). Parts after commas pick among places of one name
#' (`"Lake County, MT"`). When several places match, the one of exactly that
#' name is used (if there are several, a country or state before a county
#' or a park, then the largest), and a message names it and lists the others
#' with their ids, so that you can give the id of another. The species
#' observed in the place are listed with `/v1/observations/species_counts`,
#' 500 a page, counting research-grade observations only. A result of the key
#' is counted by name when a listed species has that name; otherwise it is
#' looked up with `/v1/taxa` (which also finds synonyms) and counts every
#' listed species below it, or, for a subspecies or variety, its own
#' observations. Give `kingdom` to list only that group's species, which
#' saves pages. When the list would take more requests than asking about
#' each taxon (a whole country, with no `kingdom`), a message says so and
#' each taxon's observations in the place are counted with two requests
#' instead. Requests made by the default `fetch` are a second apart, as
#' iNaturalist asks.
#'
#' @param key A [dimoose] key.
#' @param place The place; see the section for the source used.
#' @param source `"gbif"` or `"inat"`.
#' @param minRecords Keep a taxon with at least this many records.
#' @param kingdom For GBIF, the kingdom of the key's taxa (`"Plantae"`,
#'   `"Animalia"`, ...), which tells apart names used in more than one. For
#'   iNaturalist, the name or numeric id of any taxon that contains all the
#'   key's taxa (`"Plantae"`, `"Aves"`).
#' @param unknown What to do with results the source does not know by name
#'   (such as `"Other"`): `"keep"` them, with a warning, or `"drop"` them.
#' @param filters Named list of further search parameters for the count:
#'   for GBIF, occurrence search parameters such as
#'   `list(basisOfRecord = "HUMAN_OBSERVATION", year = "2000,2025")`; for
#'   iNaturalist, observation search parameters such as
#'   `list(quality_grade = "any")`.
#' @param ... Passed to [pruneKey()]: `note` and `renumber`.
#' @param fetch Function that makes a request: called as `fetch(url, query)`
#'   with `query` a named list, it returns the parsed JSON as nested lists.
#'   Replace it to cache or log requests, or to test without a network. The
#'   default asks a busy or unreachable server up to three times.
#' @return A [dimoose] key, pruned. Its attribute `"records"`
#'   (`attr(x, "records")`) is a data frame with a row for every taxon of the
#'   original key: `Taxon`, `name` (the name looked up), `matched` (the name
#'   the source counted it under), `id` (the source's id for that),
#'   `records` (`NA` when the source does not know the name) and `kept`. The
#'   attribute `"place"` says which place was used. When every taxon is kept
#'   the key is returned unpruned. It is an error if the source knows none of
#'   the key's taxa by name, or if fewer than two taxa are left.
#' @examples
#' \donttest{
#' flathead <- regionalKey(montanaKey(), "USA.27.15_1", kingdom = "Plantae")
#' flathead
#' attr(flathead, "records")
#'
#' regionalKey(montanaKey(), "Flathead County", source = "inat", kingdom = "Plantae")
#' }
#' @export
regionalKey <- function(key, place, source = c("gbif", "inat"), minRecords = 1, kingdom = NULL,
                        unknown = c("keep", "drop"), filters = list(), ..., fetch = prnFetch) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  source <- match.arg(source)
  unknown <- match.arg(unknown)
  if (!is.function(fetch)) stop("`fetch` must be a function(url, query)", call. = FALSE)
  if (!is.numeric(minRecords) || length(minRecords) != 1 || is.na(minRecords)) {
    stop("`minRecords` must be one number", call. = FALSE)
  }
  if (!is.list(filters)) stop("`filters` must be a named list", call. = FALSE)
  if (length(filters) && (is.null(names(filters)) || any(!nzchar(names(filters))))) {
    stop("`filters` must be a named list", call. = FALSE)
  }
  leads <- normalizeLeads(key$leads)
  labels <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
  if (!length(labels)) stop("This key names no taxa", call. = FALSE)
  # the taxa of a shared result "A / B" are looked up one by one
  taxa <- unique(unlist(prnMembers(labels)))
  name <- prnSciName(taxa)
  sourceName <- if (source == "gbif") "GBIF" else "iNaturalist"

  if (source == "gbif") {
    where <- prnGbifPlace(place, fetch)
    if (length(taxa) > 30) message(sprintf("Asking GBIF about %d taxa, two requests each", length(taxa)))
    counts <- prnGbifCounts(name, where$query, kingdom, filters, fetch)
  } else {
    where <- prnInatPlace(place, fetch)
    counts <- prnInatCounts(prnStripAuthor(name), where$query, kingdom, filters, fetch)
  }
  known <- !is.na(counts$records)
  kept <- ifelse(known, counts$records >= minRecords, unknown == "keep")
  records <- data.frame(Taxon = taxa, name = name, matched = counts$matched, id = counts$id,
                        records = counts$records, kept = kept, stringsAsFactors = FALSE)
  if (!any(known)) {
    stop(sprintf("%s knows none of the key's %d taxa by name (%s%s), so the key cannot be pruned by its records. %s",
                 sourceName, length(taxa), paste(utils::head(taxa, 5), collapse = ", "), if (length(taxa) > 5) ", ..." else "",
                 "Results must be scientific names, alone or in parentheses after a common name"), call. = FALSE)
  }
  if (any(!known)) {
    warning(sprintf("%s does not know %d of the key's taxa by name, so they were %s: %s", sourceName, sum(!known),
                    if (unknown == "keep") "kept" else "dropped", paste(taxa[!known], collapse = ", ")), call. = FALSE)
  }
  if (!any(kept)) {
    stop(sprintf("None of the key's %d taxa has %s record%s in %s according to %s", length(taxa),
                 format(minRecords), if (minRecords == 1) "" else "s", where$label, sourceName), call. = FALSE)
  }
  if (sum(kept) == 1) {
    stop(sprintf("Only one of the key's taxa is recorded in %s according to %s (%s), so there is nothing to key out",
                 where$label, sourceName, taxa[kept]), call. = FALSE)
  }
  out <- if (all(kept)) key$clone() else pruneKey(key, keep = taxa[kept], ranks = "exact", ...)
  message(sprintf("Kept %d of %d taxa recorded in %s (%s)", sum(kept), length(taxa), where$label, sourceName))
  attr(out, "records") <- records
  attr(out, "place") <- where$label
  out
}

#' Graft one key onto a result of another
#'
#' Joins two keys end to end: the lead of `key` that ended in the taxon `at`
#' now leads to the first couplet of `subkey`. Use it to put a key to the
#' genera of one family under a key to families, or a regional key under a
#' general one.
#'
#' The leads of the two keys are put in one table (a column that only one of
#' them has is left blank for the other), and so are their metadata, embedded
#' images, taxa and features. `key`'s title is kept; `subkey`'s citation is
#' added to `key`'s. If `at` is the result of several leads, they all lead to
#' the subkey. An embedded image or a feature that the two keys both have
#' under one id, with different contents, is kept apart by giving the
#' subkey's a new id (`_2` is added), with a warning for a feature.
#'
#' @param key A [dimoose] key.
#' @param subkey The [dimoose] key to graft onto it.
#' @param at The result of `key` that `subkey` continues from: its whole
#'   label, the scientific name in its parentheses or the common name before
#'   them (case does not matter).
#'   It is an error if no result, or more than one, has that name; a shared
#'   result is named in full (`"A / B"`).
#' @param labels How to keep couplet names unique. `"renumber"` numbers the
#'   couplets of the merged key 1, 2, 3, ... in reading order, so the
#'   subkey's couplets follow the lead they hang from. `"prefix"` keeps
#'   `key`'s couplet names and puts `prefix` in front of the subkey's.
#' @param prefix Text put in front of the subkey's couplet names with
#'   `labels = "prefix"`; by default the scientific name of `at` and a full
#'   stop (`"Salicaceae.1"`).
#' @return A [dimoose] key.
#' @seealso [pruneKey()]
#' @examples
#' families <- keyFromLeads(data.frame(
#'   Statement = c("1", "1"), Choice = c("a", "b"),
#'   Character = c("Fruit an acorn", "Fruit a capsule releasing cottony seeds"),
#'   Next = "-", Taxon = c("Fagaceae", "Salicaceae")
#' ), "Two families of trees")
#' salicaceae <- keyFromLeads(data.frame(
#'   Statement = c("1", "1"), Choice = c("a", "b"),
#'   Character = c("Buds with one scale", "Buds with several scales"),
#'   Next = "-", Taxon = c("Salix", "Populus")
#' ), "Genera of Salicaceae")
#' both <- mergeKeys(families, salicaceae, at = "Salicaceae")
#' both$leads
#' mergeKeys(families, salicaceae, at = "Salicaceae", labels = "prefix")$leads$Statement
#' @export
mergeKeys <- function(key, subkey, at, labels = c("renumber", "prefix"), prefix = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  if (!inherits(subkey, "dimoose")) stop("`subkey` must be a dimoose object", call. = FALSE)
  if (!is.character(at) || length(at) != 1 || is.na(at) || !nzchar(trimws(at))) {
    stop("`at` must be the name of one result of `key`", call. = FALSE)
  }
  labels <- match.arg(labels)
  main <- prnTidyLeads(key$leads)
  sub <- prnTidyLeads(subkey$leads)
  if (!nrow(sub)) stop("`subkey` has no leads", call. = FALSE)
  mainRoot <- checkLeads(normalizeLeads(main))$root
  subRoot <- checkLeads(normalizeLeads(sub))$root

  # The result to graft at: the one with that whole label, else the one with
  # that scientific name. Several results of one name are not guessed between.
  taxa <- unique(main$Taxon[main$Next == "-" & nzchar(main$Taxon)])
  hit <- taxa[prnNorm(taxa) == prnNorm(at)]
  if (!length(hit)) hit <- taxa[prnMatchTaxa(taxa, at, "exact")$taxa]
  if (!length(hit)) {
    shared <- taxa[vapply(prnMembers(taxa), function(m) length(m) > 1 && prnNorm(at) %in% prnNorm(m), logical(1))]
    if (length(shared)) {
      stop("`at` (", at, ") is one of the taxa of the shared result \"", shared[1],
           "\"; give the whole result to graft there", call. = FALSE)
    }
    stop("`at` (", at, ") is not a result of `key`; its results are: ", paste(taxa, collapse = ", "), call. = FALSE)
  }
  if (length(hit) > 1) {
    stop("`at` (", at, ") is the name of ", length(hit), " results of `key`: ", paste(hit, collapse = "; "),
         ". Give the whole label of one of them", call. = FALSE)
  }
  target <- which(main$Next == "-" & main$Taxon == hit)

  # Make the subkey's couplet names differ from the key's: a prefix, which
  # stays (labels = "prefix") or is renumbered away below.
  if (is.null(prefix)) {
    sci <- scientificPart(hit)
    prefix <- paste0(if (is.na(sci)) hit else sci, ".")
  }
  if (!is.character(prefix) || length(prefix) != 1 || is.na(prefix)) stop("`prefix` must be one string", call. = FALSE)
  rename <- function(x) ifelse(x == "-", "-", paste0(prefix, x))
  while (any(rename(unique(sub$Statement)) %in% main$Statement)) prefix <- paste0(prefix, ".")
  sub$Statement <- rename(sub$Statement)
  sub$Next <- rename(sub$Next)
  if (!is.null(sub$Prev)) sub$Prev <- NULL

  main$Next[target] <- rename(subRoot)
  main$Taxon[target] <- ""
  if (!is.null(main$TaxonUrl)) main$TaxonUrl[target] <- ""

  # Images: the same id with different contents in the two keys would show
  # the wrong picture, so the subkey's image gets a new id, in its metadata
  # (image_<id> and image_url_<id> together) and in its leads. A lead names
  # an image by id or by a file or URL whose name without extension is the
  # id; either way the name is changed.
  mainMeta <- prnMeta(key$meta)
  subMeta <- prnMeta(subkey$meta)
  isImage <- grepl("^image_", subMeta$key)
  imageId <- function(k) sub("^image_(url_)?", "", k)
  differs <- isImage & subMeta$key %in% mainMeta$key &
    !subMeta$value %in% NA & !(subMeta$value == mainMeta$value[match(subMeta$key, mainMeta$key)]) %in% TRUE
  for (id in unique(imageId(subMeta$key[differs]))) {
    taken <- function(x) any(paste0(c("image_", "image_url_"), x) %in% c(mainMeta$key, subMeta$key))
    newId <- paste0(id, "_2")
    while (taken(newId)) newId <- paste0(newId, "_2")
    rows <- isImage & imageId(subMeta$key) == id
    subMeta$key[rows] <- paste0(ifelse(grepl("^image_url_", subMeta$key[rows]), "image_url_", "image_"), newId)
    if (!is.null(sub$Image)) {
      sub$Image <- vapply(as.character(sub$Image), function(x) {
        entries <- trimws(splitUrls(x))
        file <- basename(entries)
        extension <- regmatches(file, regexpr("\\.(gif|jpe?g|png|webp)$", file, ignore.case = TRUE))
        stem <- sub("\\.(gif|jpe?g|png|webp)$", "", file, ignore.case = TRUE)
        same <- stem == id
        entries[same] <- paste0(substr(entries[same], 1, nchar(entries[same]) - nchar(file[same])), newId,
                                substr(file[same], nchar(stem[same]) + 1, nchar(file[same])))
        paste(entries, collapse = ";")
      }, character(1), USE.NAMES = FALSE)
    }
  }
  subCitation <- metaValue(subMeta, "citation")
  if (!is.na(subCitation) && nzchar(subCitation)) {
    mainCitation <- metaValue(mainMeta, "citation")
    both <- if (is.na(mainCitation) || !nzchar(mainCitation)) subCitation else {
      if (identical(mainCitation, subCitation)) mainCitation else paste0(mainCitation, " ", hit, ": ", subCitation)
    }
    mainMeta <- prnSetMeta(mainMeta, "citation", both)
  }
  meta <- rbind(mainMeta, subMeta[!subMeta$key %in% mainMeta$key, , drop = FALSE])
  rownames(meta) <- NULL

  # Features: one id standing for two different features would have the
  # subkey's leads tested against the key's feature, so the subkey's is
  # renamed, in its table and in its leads.
  features <- key$features
  subFeatures <- subkey$features
  if (is.null(features)) {
    features <- subFeatures
  } else if (!is.null(subFeatures)) {
    if (!is.null(features$id) && !is.null(subFeatures$id)) {
      shared <- intersect(names(features), names(subFeatures))
      rowOf <- function(f, id) lapply(f[match(id, f$id), shared, drop = FALSE], function(x) unname(x))
      clash <- Filter(function(id) !identical(rowOf(features, id), rowOf(subFeatures, id)),
                      intersect(subFeatures$id, features$id))
      for (id in clash) {
        newId <- paste0(id, "_2")
        while (newId %in% c(features$id, subFeatures$id)) newId <- paste0(newId, "_2")
        subFeatures$id[subFeatures$id == id] <- newId
        if (!is.null(sub$Feature)) sub$Feature[sub$Feature %in% id] <- newId
      }
      if (length(clash)) {
        warning(sprintf("The two keys define %s differently; the subkey's is renamed %s",
                        paste(clash, collapse = ", "), paste(paste0(clash, "_2"), collapse = ", ")), call. = FALSE)
      }
    }
    features <- prnBind(features, subFeatures)
    if (!is.null(features$id)) features <- features[!duplicated(features$id), , drop = FALSE]
    rownames(features) <- NULL
  }

  if (!is.null(main$Prev)) main$Prev <- NULL
  leads <- prnBind(main, sub)
  if (labels == "renumber") leads <- prnRenumber(leads, mainRoot)
  if (!is.null(key$leads$Prev)) leads$Prev <- prnPrev(leads, if (labels == "renumber") "1" else mainRoot)
  rownames(leads) <- NULL

  left <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
  allTaxa <- NULL
  if (is.data.frame(key$taxa) && is.data.frame(subkey$taxa) &&
      "submitted_name" %in% names(key$taxa) && "submitted_name" %in% names(subkey$taxa)) {
    allTaxa <- prnBind(key$taxa, subkey$taxa)
    allTaxa <- allTaxa[!duplicated(allTaxa$submitted_name) & allTaxa$submitted_name %in% left, , drop = FALSE]
    missingTaxa <- setdiff(left, allTaxa$submitted_name)
    if (length(missingTaxa)) allTaxa <- NULL else rownames(allTaxa) <- NULL
  }
  keyFromLeads(leads, key$desc, meta, allTaxa, features)
}

# ---- pruning internals -------------------------------------------------------

# How names are compared: lower case, single spaces, and the hybrid sign
# written one way ("Populus x acuminata", "Populus ×acuminata" and
# "Populus × acuminata" are the same name).
prnNorm <- function(x) {
  x <- as.character(x)
  x <- gsub("\u00d7", " \u00d7 ", x, fixed = TRUE)
  x <- gsub("(^|\\s)x(?=\\s)", "\\1\u00d7", x, perl = TRUE)
  tolower(gsub("\\s+", " ", trimws(x)))
}

# The scientific name of each label: what is in its parentheses
# ("Bur oak (Quercus macrocarpa)"), unless that is the author of a name
# ("Carcharodon carcharias (Linnaeus, 1758)"), else the whole label.
prnSciName <- function(x) {
  x <- as.character(x)
  s <- scientificPart(x)
  author <- !is.na(s) & grepl("^\\S*[.,]( |$)|&|[0-9]{4}| ex ", s)
  s[author] <- NA
  s[is.na(s)] <- x[is.na(s)]
  s
}

# A name without its author: everything from the first word (after the first)
# that opens a parenthesis or is an abbreviated or dated author ("Michx.",
# "L.", "A.Gray", "Linnaeus,") is left out.
prnStripAuthor <- function(x) {
  vapply(strsplit(trimws(as.character(x)), "\\s+"), function(w) {
    if (length(w) < 2) return(paste(w, collapse = " "))
    author <- which(grepl("^\\(|^[A-Z][[:alpha:]'.-]*[.,]$|^[A-Z]\\.[A-Z]|^&$", w))
    author <- author[author > 1]
    if (length(author)) paste(w[seq_len(author[1] - 1)], collapse = " ") else paste(w, collapse = " ")
  }, "")
}

# The taxa of each result label: "A / B" is A and B. A label that ends in a
# scientific name in parentheses and has no other is one taxon, whatever
# slashes its common name has.
prnMembers <- function(labels) {
  lapply(labels, function(x) {
    parts <- trimws(strsplit(x, " / ", fixed = TRUE)[[1]])
    parts <- unique(parts[nzchar(parts)])
    if (length(parts) < 2) return(x)
    if (!is.na(scientificPart(x)) && !any(grepl("(", parts[-length(parts)], fixed = TRUE))) return(x)
    parts
  })
}

# Every shorter run of whole words each string begins with ("a b c" gives
# "a" and "a b"), as a data frame of the string's index and the run.
prnWordPrefixes <- function(x) {
  words <- strsplit(x, " ", fixed = TRUE)
  n <- pmax(lengths(words) - 1L, 0L)
  data.frame(i = rep(seq_along(x), n),
             prefix = as.character(unlist(lapply(words[n > 0], function(w) Reduce(paste, w[-length(w)], accumulate = TRUE)))),
             stringsAsFactors = FALSE)
}

# Which of `taxa` (labels of a key) do the entries of `wanted` name? Returns
# list(taxa = logical per taxon, used = logical per entry of wanted). With
# ranks = "genus" a name also matches the names that begin with it (a genus
# its species, a species its subspecies, a name the same name with its
# author); with genusOfSpecies, an entry also matches the taxon it begins
# with (a species keeps its genus).
prnMatchTaxa <- function(taxa, wanted, ranks = "genus", genusOfSpecies = FALSE) {
  wanted <- as.character(wanted)
  wanted <- wanted[!is.na(wanted) & nzchar(trimws(wanted))]
  bare <- function(x) sub("^\u00d7 ", "", prnNorm(x))
  label <- prnNorm(taxa); sci <- bare(prnSciName(taxa))
  wLabel <- prnNorm(wanted); wSci <- bare(prnSciName(wanted))
  hit <- label %in% c(wLabel, wSci) | sci %in% c(wLabel, wSci)
  used <- wLabel %in% c(label, sci) | wSci %in% c(label, sci)
  # the common name alone: what a label has before its last parentheses
  # (parentheses that hold an author are part of the name)
  common <- sub("\\s*\\([^()]*\\)$", "", label)
  common[common == label | !nzchar(common) | prnSciName(taxa) == as.character(taxa)] <- NA
  hit <- hit | common %in% wLabel
  used <- used | wLabel %in% common
  if (ranks == "genus" && length(wanted) && length(taxa)) {
    # the same name, one of them with its author
    sciBare <- bare(prnStripAuthor(prnSciName(taxa)))
    wBare <- bare(prnStripAuthor(prnSciName(wanted)))
    hit <- hit | sciBare %in% wSci | sci %in% wBare
    used <- used | wSci %in% sciBare | wBare %in% sci
    # a taxon below an entry: its name begins with the entry's words
    below <- prnWordPrefixes(sci)
    under <- below$prefix %in% c(wSci, wBare)
    hit[below$i[under]] <- TRUE
    used <- used | wSci %in% below$prefix | wBare %in% below$prefix
    if (genusOfSpecies) {
      above <- prnWordPrefixes(wSci)
      over <- above$prefix %in% sci
      used[above$i[over]] <- TRUE
      hit <- hit | sci %in% above$prefix[over]
    }
  }
  list(taxa = hit, used = stats::setNames(used, wanted))
}

prnWarnUnmatched <- function(used, arg) {
  miss <- names(used)[!used]
  if (length(miss)) {
    warning(sprintf("%d name%s in `%s` matched no taxon of the key: %s", length(miss),
                    if (length(miss) == 1) "" else "s", arg, paste(miss, collapse = ", ")), call. = FALSE)
  }
  invisible(NULL)
}

# Couplets that can be reached from `root`.
prnReachable <- function(leads, root) {
  reachable <- root
  frontier <- root
  while (length(frontier)) {
    nxt <- leads$Next[leads$Statement %in% frontier]
    nxt <- setdiff(nxt[nxt != "-"], reachable)
    reachable <- c(reachable, nxt)
    frontier <- nxt
  }
  reachable
}

# The couplets reachable from `root` (an index into `kids`, a list of the
# couplets each couplet's leads go to), each after the couplets below it.
prnPostOrder <- function(kids, root) {
  seen <- rep(FALSE, length(kids))
  out <- integer(length(kids))
  done <- 0L
  stack <- integer(64)
  at <- integer(64)
  depth <- 1L
  stack[1] <- root
  at[1] <- 0L
  seen[root] <- TRUE
  while (depth > 0L) {
    cp <- stack[depth]
    at[depth] <- at[depth] + 1L
    if (at[depth] > length(kids[[cp]])) {
      done <- done + 1L
      out[done] <- cp
      depth <- depth - 1L
      next
    }
    kid <- kids[[cp]][at[depth]]
    if (seen[kid]) next
    seen[kid] <- TRUE
    depth <- depth + 1L
    if (depth > length(stack)) {
      stack <- c(stack, integer(length(stack)))
      at <- c(at, integer(length(at)))
    }
    stack[depth] <- kid
    at[depth] <- 0L
  }
  out[seq_len(done)]
}

# Take out every couplet whose leads all go to the same place (usually a
# couplet left with one lead). Leads into it take over that destination, and
# are handed what is true of everything beyond it: the text and pictures of
# a sole remaining lead, or, of several leads to one place, only the notes
# and pictures they all carry (their own texts differ, and say nothing).
# Couplets are settled from the ends of the key towards its start, so each
# is looked at once, after everything below it.
prnCollapse <- function(leads, root, note) {
  n <- nrow(leads)
  text <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x
  }
  # notes are lists of statements, written joined by "; "
  items <- function(x) if (nzchar(x)) strsplit(x, "; ", fixed = TRUE)[[1]] else character()
  common <- function(x) if (length(x) == 1) x[[1]] else Reduce(intersect, x)
  couplets <- unique(leads$Statement)
  couplet <- match(leads$Statement, couplets)
  rowsOf <- split(seq_len(n), couplet)
  nxt <- leads$Next
  to <- match(nxt, couplets)             # NA for a result
  taxon <- leads$Taxon
  character <- text(leads$Character)
  oldNote <- if (is.null(leads$Note)) rep("", n) else text(leads$Note)
  added <- vector("list", n)             # statements handed to each lead
  url <- if (is.null(leads$TaxonUrl)) NULL else leads$TaxonUrl
  image <- if (is.null(leads$Image)) NULL else text(leads$Image)
  link <- if (is.null(leads$ImageLink)) NULL else text(leads$ImageLink)
  notesOf <- function(i, own) c(if (own) items(character[i]), items(oldNote[i]), added[[i]])

  kids <- lapply(rowsOf, function(r) unique(to[r][!is.na(to[r])]))
  gone <- rep(FALSE, n)
  heir <- rep(NA_integer_, length(couplets))    # a lead of each collapsed couplet, for where it goes
  handNotes <- vector("list", length(couplets)) # what each collapsed couplet hands on
  handImage <- handLink <- vector("list", length(couplets))
  for (cp in prnPostOrder(kids, match(root, couplets))) {
    rows <- rowsOf[[cp]]
    for (i in rows[!is.na(to[rows])]) {
      below <- to[i]
      l <- heir[below]
      if (is.na(l)) next
      if (length(handNotes[[below]])) added[[i]] <- c(added[[i]], handNotes[[below]])
      if (!is.null(image)) image[i] <- paste(unique(c(splitUrls(image[i]), handImage[[below]])), collapse = ";")
      if (!is.null(link)) link[i] <- paste(unique(c(splitUrls(link[i]), handLink[[below]])), collapse = ";")
      nxt[i] <- nxt[l]
      to[i] <- to[l]
      taxon[i] <- taxon[l]
      if (!is.null(url)) url[i] <- url[l]
    }
    dest <- ifelse(nxt[rows] == "-", paste0("-\r", taxon[rows]), nxt[rows])
    if (length(unique(dest)) > 1) next
    heir[cp] <- rows[1]
    sole <- length(rows) == 1
    # (a list element is set with [<- so that an empty value does not remove it)
    if (note != "none") handNotes[cp] <- list(common(lapply(rows, notesOf, own = sole)))
    if (!is.null(image)) handImage[cp] <- list(common(lapply(image[rows], splitUrls)))
    if (!is.null(link)) handLink[cp] <- list(common(lapply(link[rows], splitUrls)))
    gone[rows] <- TRUE
  }

  rootNotes <- character()
  first <- match(root, couplets)
  if (!is.na(heir[first])) {
    l <- heir[first]
    if (nxt[l] == "-") return(list(leads = leads[0, , drop = FALSE], root = NA_character_, rootNotes = rootNotes))
    root <- nxt[l]
    if (length(handNotes[[first]])) rootNotes <- paste(handNotes[[first]], collapse = "; ")
  }
  leads$Next <- nxt
  leads$Taxon <- taxon
  if (!is.null(url)) leads$TaxonUrl <- url
  if (!is.null(image)) leads$Image[!gone] <- image[!gone]
  if (!is.null(link)) leads$ImageLink[!gone] <- link[!gone]
  more <- lengths(added) > 0
  if (note == "column" && (any(more) || !is.null(leads$Note))) {
    oldNote[more] <- vapply(which(more), function(i) paste(notesOf(i, own = FALSE), collapse = "; "), "")
    leads$Note <- oldNote
  } else if (note == "append" && any(more)) {
    leads$Character[more] <- paste0(character[more], " [", vapply(added[more], paste, "", collapse = "; "), "]")
  }
  list(leads = leads[!gone, , drop = FALSE], root = root, rootNotes = rootNotes)
}

# The Prev column of FishBase keys: the couplet each couplet is reached from
# (the first, for a couplet reached from several); the root names itself.
prnPrev <- function(leads, root) {
  from <- leads$Statement[match(leads$Statement, leads$Next)]
  ifelse(is.na(from), leads$Statement, from)
}

# Number the couplets 1..n in reading order: depth first from the root,
# leads in order, a couplet reached twice numbered where it is first met.
prnRenumber <- function(leads, root) {
  couplets <- unique(leads$Statement)
  to <- match(leads$Next, couplets)
  kids <- lapply(split(to, factor(leads$Statement, levels = couplets)), function(x) unique(x[!is.na(x)]))
  numbered <- rep(FALSE, length(couplets))
  order <- integer(length(couplets))
  done <- 0L
  stack <- match(root, couplets)
  while (length(stack)) {
    cp <- stack[1]
    stack <- stack[-1]
    if (numbered[cp]) next
    numbered[cp] <- TRUE
    done <- done + 1L
    order[done] <- cp
    stack <- c(kids[[cp]][!numbered[kids[[cp]]]], stack)
  }
  order <- c(order[seq_len(done)], which(!numbered))
  number <- character(length(couplets))
  number[order] <- as.character(seq_along(order))
  leads$Next[!is.na(to)] <- number[to[!is.na(to)]]
  leads$Statement <- number[match(leads$Statement, couplets)]
  if (!is.null(leads$Prev)) leads$Prev <- prnPrev(leads, "1")
  leads <- leads[order(as.integer(leads$Statement)), , drop = FALSE]
  rownames(leads) <- NULL
  leads
}

# A key's meta as a key/value data frame of strings (empty if it has none).
prnMeta <- function(meta) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) {
    return(data.frame(key = character(), value = character(), stringsAsFactors = FALSE))
  }
  data.frame(key = as.character(meta$key), value = as.character(meta$value), stringsAsFactors = FALSE)
}

prnSetMeta <- function(meta, key, value) {
  meta <- prnMeta(meta)
  if (key %in% meta$key) {
    meta$value[meta$key == key] <- value
    meta
  } else {
    rbind(meta, data.frame(key = key, value = value, stringsAsFactors = FALSE))
  }
}

# Ids of the images a lead table shows (the file name without extension of
# each entry of Image, as exportWizard() reads them).
prnImageIds <- function(leads) {
  if (is.null(leads$Image)) return(character())
  x <- as.character(leads$Image)
  x <- unlist(strsplit(x[!is.na(x) & nzchar(x)], ";", fixed = TRUE))
  unique(sub("\\.(gif|jpe?g|png|webp)$", "", basename(trimws(x)), ignore.case = TRUE))
}

# Drop the image_<id> and image_url_<id> rows of meta for images the old leads
# showed and the new ones do not. Images no lead ever showed (such as the
# example crops of features) are left alone.
prnDropImages <- function(meta, oldLeads, newLeads) {
  meta <- prnMeta(meta)
  gone <- setdiff(prnImageIds(oldLeads), prnImageIds(newLeads))
  if (!length(gone)) return(meta)
  out <- meta[!meta$key %in% c(paste0("image_", gone), paste0("image_url_", gone)), , drop = FALSE]
  rownames(out) <- NULL
  out
}

prnSubsetTaxa <- function(taxa, left) {
  if (!is.data.frame(taxa) || !"submitted_name" %in% names(taxa)) return(NULL)
  out <- taxa[taxa$submitted_name %in% left, , drop = FALSE]
  if (!all(left %in% out$submitted_name)) return(NULL)
  rownames(out) <- NULL
  out
}

prnSubsetFeatures <- function(features, leads) {
  if (is.null(features) || is.null(features$id) || is.null(leads$Feature)) return(features)
  used <- unique(leads$Feature[!is.na(leads$Feature) & nzchar(leads$Feature)])
  out <- features[features$id %in% used, , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Leads with the columns the logic reads cleaned up as normalizeLeads() does,
# and every other column left as it is.
prnTidyLeads <- function(leads) {
  leads <- as.data.frame(leads, stringsAsFactors = FALSE)
  norm <- normalizeLeads(leads)
  for (col in c("Statement", "Next", "Taxon")) leads[[col]] <- norm[[col]]
  leads
}

# rbind for two data frames whose columns differ: a column one lacks is blank
# ("" for text, NA otherwise, NULL in list columns) in its rows.
prnBind <- function(a, b) {
  blank <- function(like, n) {
    if (is.list(like)) return(vector("list", n))
    if (is.character(like) || is.factor(like)) return(rep("", n))
    rep(like[NA_integer_][1], n)
  }
  for (col in setdiff(names(b), names(a))) a[[col]] <- blank(b[[col]], nrow(a))
  for (col in setdiff(names(a), names(b))) b[[col]] <- blank(a[[col]], nrow(b))
  for (col in names(a)) {
    if (is.factor(a[[col]])) a[[col]] <- as.character(a[[col]])
    if (is.factor(b[[col]])) b[[col]] <- as.character(b[[col]])
    if (is.character(a[[col]]) != is.character(b[[col]]) && !is.list(a[[col]]) && !is.list(b[[col]])) {
      a[[col]] <- as.character(a[[col]])
      b[[col]] <- as.character(b[[col]])
    }
  }
  out <- rbind(a, b[names(a)])
  rownames(out) <- NULL
  out
}

# ---- occurrence lookups ------------------------------------------------------

# GET `url` with `query` and return the parsed JSON. iNaturalist asks for
# about a request a second. A server that is busy (HTTP 429), failing (5xx)
# or cannot be reached is asked again, `tries` times in all, after the wait
# it asks for (Retry-After) or 5 and then 10 seconds. `wait` and `get` are
# there to be replaced in tests.
prnFetch <- function(url, query = list(), tries = 3, wait = Sys.sleep, get = httr::GET) {
  query <- query[!vapply(query, is.null, logical(1))]
  host <- sub("^https?://([^/]+).*$", "\\1", url)
  for (try in seq_len(tries)) {
    if (grepl("inaturalist.org", url, fixed = TRUE)) wait(1)
    r <- tryCatch(get(url, query = query, dimooseUserAgent(), httr::timeout(60)), error = function(e) e)
    unreachable <- inherits(r, "error")
    if (!unreachable && httr::status_code(r) != 429 && httr::status_code(r) < 500) break
    if (try == tries) break
    asked <- if (unreachable) NA_real_ else suppressWarnings(as.numeric(c(httr::headers(r)[["retry-after"]], NA)[1]))
    wait(if (is.na(asked)) 5 * try else min(max(asked, 1), 60))
  }
  if (inherits(r, "error")) stop("Could not reach ", host, ": ", conditionMessage(r), call. = FALSE)
  httr::stop_for_status(r, task = paste("ask", host))
  httr::content(r, as = "parsed", type = "application/json", encoding = "UTF-8")
}

# `fetch`, with an error that says what was being asked when it failed.
prnAsk <- function(fetch, url, query, doing) {
  tryCatch(fetch(url, query), error = function(e) {
    stop(sprintf("The request failed while %s, so nothing was pruned: %s", doing, conditionMessage(e)), call. = FALSE)
  })
}

prnGbifApi <- "https://api.gbif.org/v1/"
prnInatApi <- "https://api.inaturalist.org/v1/"

# Turn `place` into GBIF occurrence search parameters and a name to show.
prnGbifPlace <- function(place, fetch) {
  if (is.list(place)) {
    if (!length(place) || is.null(names(place)) || any(!nzchar(names(place)))) {
      stop("A list given as `place` must be named GBIF occurrence search parameters, ",
           "such as list(country = \"US\", stateProvince = \"Montana\")", call. = FALSE)
    }
    label <- paste(sprintf("%s=%s", names(place), vapply(place, function(x) paste(x, collapse = "|"), "")), collapse = ", ")
    return(list(query = place, label = label))
  }
  if (!is.character(place) || length(place) != 1 || is.na(place) || !nzchar(trimws(place))) {
    stop("`place` must be one string or a named list of GBIF search parameters", call. = FALSE)
  }
  place <- trimws(place)
  if (grepl("^(MULTI)?POLYGON", place, ignore.case = TRUE)) {
    return(list(query = list(geometry = place), label = "the polygon given"))
  }
  if (grepl("^[A-Z]{3}(\\.[0-9]+)*(_[0-9]+)?$", place)) {
    return(list(query = list(gadmGid = place), label = paste("GADM region", place)))
  }
  if (grepl("^[A-Z]{2}$", place)) {
    return(list(query = list(country = place), label = paste("country", place)))
  }
  region <- prnGadmSearch(place, fetch)
  above <- vapply(region$higherRegions, function(h) h$name, "")
  list(query = list(gadmGid = region$id),
       label = sprintf("%s (GADM %s)", paste(c(region$name, rev(above)), collapse = ", "), region$id))
}

# Other ways of writing a few countries, by GADM id (GADM itself has only
# the one name, and no two-letter codes).
prnCountryAliases <- list(
  USA = c("us", "usa", "u.s.", "u.s.a.", "united states of america"),
  GBR = c("uk", "u.k.", "gb", "great britain", "britain"),
  CAN = "ca", MEX = "mx", AUS = "au", NZL = "nz", DEU = c("de", "deutschland"), FRA = "fr", CHE = "ch"
)

# Find one GADM region by name. Parts after commas name regions it lies in,
# by GADM's name or id for them or another name GADM lists ("MT" for
# Montana). A word for the kind of region ("Flathead County") is allowed.
prnGadmSearch <- function(place, fetch) {
  parts <- trimws(strsplit(place, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  if (!length(parts)) stop("`place` names no region", call. = FALSE)
  search <- function(q) {
    res <- prnAsk(fetch, paste0(prnGbifApi, "geocode/gadm/search"), list(q = q, limit = 100),
                  paste0("looking up the region \"", q, "\" in GADM"))$results
    if (is.null(res)) list() else res
  }
  called <- function(found, name) {
    found[vapply(found, function(r) prnNorm(name) %in% prnNorm(c(r$name, unlist(r$variantName))), logical(1))]
  }
  describe <- function(r) {
    above <- vapply(r$higherRegions, function(h) h$name, "")
    sprintf("%s (%s)", paste(c(r$name, rev(above)), collapse = ", "), r$id)
  }
  listed <- function(found) {
    paste0(paste(vapply(found[seq_len(min(10, length(found)))], describe, ""), collapse = "; "),
           if (length(found) > 10) "; ..." else "")
  }

  found <- search(parts[1])
  exact <- called(found, parts[1])
  kinds <- "county|parish|borough|district|province|state|department|region|municipality|prefecture|canton"
  short <- sub(paste0("\\s+(", kinds, ")$"), "", parts[1], ignore.case = TRUE)
  if (!length(exact) && short != parts[1]) {
    more <- search(short)
    exact <- called(more, short)
    # "Lake County" is the Lake that is a county, if one is
    kind <- tolower(sub("^.*\\s", "", parts[1]))
    ofKind <- vapply(exact, function(r) kind %in% tolower(unlist(c(r$type, r$englishType))), logical(1))
    if (any(ofKind)) exact <- exact[ofKind]
    if (!length(found)) found <- more
  }
  if (length(exact)) found <- exact
  if (!length(found)) {
    stop("GBIF knows no GADM region called \"", parts[1], "\"; give its GADM id (see https://gadm.org) ",
         "or a list of GBIF search parameters", call. = FALSE)
  }

  # other names of a region that candidates lie in, asked for only when a
  # hint matches no candidate by GADM's own name
  otherNames <- new.env(parent = emptyenv())
  variants <- function(above) {
    if (is.null(otherNames[[above$id]])) {
      same <- Filter(function(r) identical(r$id, above$id), search(above$name))
      otherNames[[above$id]] <- c("", if (length(same)) prnNorm(unlist(same[[1]]$variantName)))
    }
    otherNames[[above$id]]
  }
  liesIn <- function(r, hint, deep) {
    for (above in r$higherRegions) {
      if (hint %in% c(prnNorm(above$name), prnNorm(above$id), prnCountryAliases[[above$id]])) return(TRUE)
      if (deep && hint %in% variants(above)) return(TRUE)
    }
    FALSE
  }
  for (hint in parts[-1]) {
    ok <- vapply(found, liesIn, logical(1), hint = prnNorm(hint), deep = FALSE)
    if (!any(ok) && length(found) <= 60) ok <- vapply(found, liesIn, logical(1), hint = prnNorm(hint), deep = TRUE)
    if (!any(ok)) {
      stop("GBIF knows no GADM region \"", parts[1], "\" in \"", hint, "\". It knows: ", listed(found),
           ". Name the region it lies in as shown, or give the GADM id in brackets as `place`", call. = FALSE)
    }
    found <- found[ok]
  }
  if (length(found) > 1 && !length(exact)) {
    stop("GBIF knows no GADM region called \"", parts[1], "\". The nearest names are: ", listed(found),
         ". Give the name as shown, or the GADM id in brackets as `place`", call. = FALSE)
  }
  if (length(found) > 1) {
    stop("\"", place, "\" could be any of ", length(found), " GADM regions: ", listed(found),
         ". Add the region it lies in after a comma, or give the GADM id in brackets as `place`", call. = FALSE)
  }
  found[[1]]
}

# GBIF's match for a name, as list(id, name), or NULL when it has none. The
# id is the accepted name's when the name is a synonym, and the species' when
# a species name is filed under one of its subspecies (records identified to
# the species would not be counted there). A name GBIF has several equal
# matches for, as it has for many genera ("Betula" is a genus of plants and
# an old one of animals), is settled from the alternatives it lists: the
# accepted one of that exact name, and for a single word not a species.
prnGbifUsage <- function(m, name) {
  type <- if (is.null(m$matchType)) "NONE" else m$matchType
  if (type == "NONE" && length(m$alternatives)) {
    alt <- Filter(function(a) !is.null(a$canonicalName) && !is.null(a$usageKey) &&
                    prnNorm(a$canonicalName) == prnNorm(prnStripAuthor(name)), m$alternatives)
    narrow <- function(alt, keep) if (any(keep)) alt[keep] else alt
    alt <- narrow(alt, vapply(alt, function(a) identical(a$status, "ACCEPTED"), logical(1)))
    if (!grepl(" ", trimws(name), fixed = TRUE)) {
      alt <- narrow(alt, vapply(alt, function(a) !isTRUE(a$rank %in% c("SPECIES", "SUBSPECIES", "VARIETY", "FORM")), logical(1)))
    }
    if (length(alt) != 1) return(NULL)
    m <- alt[[1]]
    type <- "EXACT"
  }
  # HIGHERRANK: GBIF knows only a taxon above the one asked for
  if (type %in% c("NONE", "HIGHERRANK") || is.null(m$usageKey)) return(NULL)
  id <- if (is.null(m$acceptedUsageKey)) m$usageKey else m$acceptedUsageKey
  shown <- if (is.null(m$canonicalName)) m$scientificName else m$canonicalName
  if (identical(m$rank, "SPECIES") && !is.null(m$speciesKey) && !is.null(m$acceptedUsageKey) && m$speciesKey != id) {
    id <- m$speciesKey
    if (!is.null(m$species)) shown <- m$species
  }
  list(id = id, name = shown)
}

# Records of each name in a place, from GBIF: data frame matched, id, records.
prnGbifCounts <- function(name, placeQuery, kingdom, filters, fetch) {
  out <- data.frame(matched = rep(NA_character_, length(name)), id = NA_character_, records = NA_real_,
                    stringsAsFactors = FALSE)
  for (i in seq_along(name)) {
    doing <- sprintf("asking GBIF about %s (taxon %d of %d)", name[i], i, length(name))
    usage <- prnGbifUsage(prnAsk(fetch, paste0(prnGbifApi, "species/match"),
                                 list(name = name[i], kingdom = kingdom, verbose = "true"), doing), name[i])
    if (is.null(usage)) next
    query <- utils::modifyList(c(list(taxonKey = usage$id, occurrenceStatus = "PRESENT"), placeQuery), filters)
    query$limit <- 0
    res <- prnAsk(fetch, paste0(prnGbifApi, "occurrence/search"), query, doing)
    if (is.null(res$count)) stop("GBIF returned no count for ", name[i], call. = FALSE)
    out$matched[i] <- usage$name
    out$id[i] <- as.character(usage$id)
    out$records[i] <- as.numeric(res$count)
  }
  out
}

# Turn `place` into an iNaturalist place_id and a name to show. Parts after
# commas must be among the parts of the place's full name ("Lake County, MT").
prnInatPlace <- function(place, fetch) {
  if (length(place) != 1 || is.na(place) || !(is.numeric(place) || is.character(place)) ||
      !nzchar(trimws(as.character(place)))) {
    stop("`place` must be the name or numeric id of one iNaturalist place", call. = FALSE)
  }
  if (is.numeric(place)) place <- format(place, scientific = FALSE, trim = TRUE)
  place <- trimws(place)
  if (grepl("^[0-9]+$", place)) {
    return(list(query = list(place_id = place), label = paste("iNaturalist place", place)))
  }
  search <- function(q) {
    prnAsk(fetch, paste0(prnInatApi, "places/autocomplete"), list(q = q, per_page = 20),
           paste0("looking up the place \"", q, "\" in iNaturalist"))$results
  }
  parts <- trimws(strsplit(place, ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  res <- search(place)
  wanted <- place
  if (!length(res) && length(parts) > 1) {
    res <- search(parts[1])
    wanted <- parts[1]
  }
  if (!length(res)) stop("iNaturalist knows no place called \"", wanted, "\"", call. = FALSE)
  full <- vapply(res, function(r) if (is.null(r$display_name)) r$name else r$display_name, "")
  short <- vapply(res, function(r) if (is.null(r$name)) "" else r$name, "")
  if (wanted != place) {
    # the places whose full name has every part given after the commas
    usa <- prnCountryAliases$USA
    fits <- vapply(full, function(f) {
      have <- prnNorm(strsplit(f, ",", fixed = TRUE)[[1]])
      if (any(have %in% usa)) have <- c(have, usa)
      all(prnNorm(parts[-1]) %in% have)
    }, logical(1))
    if (!any(fits)) {
      stop("iNaturalist knows no place \"", parts[1], "\" in \"", paste(parts[-1], collapse = ", "), "\". It knows: ",
           paste(sprintf("%s (id %s)", full, vapply(res, function(r) as.character(r$id), "")), collapse = "; "),
           ". Give the id of the one you mean as `place`", call. = FALSE)
    }
    res <- res[fits]; full <- full[fits]; short <- short[fits]
  }
  # the place of exactly that name, else one whose full name starts with it
  # ("Flathead County" for "Flathead County, US, MT"), else the first found
  # Of several of one name, a country or state comes before a county, a
  # town or a park, and a larger place before a smaller one ("Montana" is
  # the state, not the Bulgarian province or a park of that name).
  number <- function(field, missing) {
    vapply(res, function(r) if (is.numeric(r[[field]]) && length(r[[field]]) == 1) as.numeric(r[[field]]) else missing, 0)
  }
  rank <- order(number("admin_level", Inf), -number("bbox_area", 0))
  byRank <- function(i) i[order(match(i, rank))]
  exact <- byRank(which(prnNorm(full) == prnNorm(wanted) | prnNorm(short) == prnNorm(wanted)))
  starts <- byRank(which(startsWith(prnNorm(full), paste0(prnNorm(wanted), ","))))
  pick <- c(exact, starts, 1L)[1]
  id <- vapply(res, function(r) as.character(r$id), "")
  if (length(res) > 1) {
    others <- setdiff(c(exact, starts, seq_along(res)), pick)
    shown <- others[seq_len(min(5, length(others)))]
    message(sprintf("Using iNaturalist place %s (id %s); %d other place%s matched \"%s\": %s%s. To use another, give its id as `place`",
                    full[pick], id[pick], length(others), if (length(others) == 1) "" else "s", place,
                    paste(sprintf("%s (id %s)", full[shown], id[shown]), collapse = "; "),
                    if (length(others) > length(shown)) "; ..." else ""))
  }
  list(query = list(place_id = id[pick]), label = sprintf("%s (iNaturalist place %s)", full[pick], id[pick]))
}

# The iNaturalist taxon a name stands for: its exact name, or a name
# iNaturalist files under another (a synonym). NULL if there is none.
# iNaturalist writes subspecies and varieties without "subsp." or "var.".
prnInatTaxon <- function(name, fetch, within = NULL) {
  unranked <- function(x) gsub(" (subsp|ssp|var|subvar|f|forma)\\.? ", " ", x, ignore.case = TRUE)
  plain <- function(x) prnNorm(unranked(x))
  res <- prnAsk(fetch, paste0(prnInatApi, "taxa"),
                list(q = unranked(trimws(name)), is_active = "true", taxon_id = within, per_page = 30),
                paste("asking iNaturalist about", name))$results
  if (!length(res)) return(NULL)
  nm <- plain(vapply(res, function(r) if (is.null(r$name)) "" else r$name, ""))
  term <- plain(vapply(res, function(r) if (is.null(r$matched_term)) "" else r$matched_term, ""))
  pick <- c(which(nm == plain(name)), which(term == plain(name)))
  if (!length(pick)) NULL else res[[pick[1]]]
}

# Records of each name in a place, from iNaturalist: data frame matched, id,
# records. One species list for the place, then each name counted in it. The
# list has nothing below species, so a subspecies or variety is counted with
# a request of its own; so is every name not on the first page when the list
# is too long to read through.
prnInatCounts <- function(name, placeQuery, kingdom, filters, fetch) {
  within <- NULL
  if (!is.null(kingdom)) {
    if (is.numeric(kingdom) || grepl("^[0-9]+$", kingdom)) {
      within <- format(kingdom, scientific = FALSE, trim = TRUE)
    } else {
      tx <- prnInatTaxon(kingdom, fetch)
      if (is.null(tx)) stop("iNaturalist knows no taxon called \"", kingdom, "\"", call. = FALSE)
      within <- as.character(tx$id)
    }
  }
  base <- utils::modifyList(c(placeQuery, list(quality_grade = "research", taxon_id = within)), filters)
  species <- list()
  page <- 1
  listed <- TRUE
  repeat {
    res <- prnAsk(fetch, paste0(prnInatApi, "observations/species_counts"), c(base, list(per_page = 500, page = page)),
                  sprintf("listing the species iNaturalist has for the place (page %d)", page))
    species <- c(species, res$results)
    total <- if (is.null(res$total_results)) length(species) else res$total_results
    if (!length(res$results) || length(species) >= total) break
    # A place with very many species (a country, with no `kingdom` given)
    # would take more pages than asking about each taxon takes requests.
    if (page == 1 && ceiling((total - length(species)) / length(species)) > 2 * length(name)) {
      listed <- FALSE
      message(sprintf("iNaturalist has %s species for the place, so each of the key's %d taxa is asked about instead%s",
                      format(total, big.mark = ","), length(name),
                      if (is.null(kingdom)) " (give `kingdom` to list fewer)" else ""))
      break
    }
    page <- page + 1
  }
  spName <- prnNorm(vapply(species, function(s) if (is.null(s$taxon$name)) "" else s$taxon$name, ""))
  spShown <- vapply(species, function(s) if (is.null(s$taxon$name)) "" else s$taxon$name, "")
  spId <- vapply(species, function(s) as.character(s$taxon$id), "")
  spCount <- vapply(species, function(s) as.numeric(s$count), 0)
  spAncestors <- lapply(species, function(s) as.character(unlist(s$taxon$ancestor_ids)))

  out <- data.frame(matched = rep(NA_character_, length(name)), id = NA_character_, records = NA_real_,
                    stringsAsFactors = FALSE)
  for (i in seq_along(name)) {
    direct <- which(spName == prnNorm(name[i]))
    if (length(direct)) {
      out$matched[i] <- spShown[direct[1]]
      out$id[i] <- spId[direct[1]]
      out$records[i] <- sum(spCount[direct])
      next
    }
    tx <- prnInatTaxon(name[i], fetch, within)
    if (is.null(tx)) next
    id <- as.character(tx$id)
    out$matched[i] <- tx$name
    out$id[i] <- id
    if (!listed || (!is.null(tx$rank_level) && tx$rank_level < 10)) {
      one <- utils::modifyList(base, list(taxon_id = id, per_page = 0))
      res <- prnAsk(fetch, paste0(prnInatApi, "observations"), one, paste("asking iNaturalist about", name[i]))
      out$records[i] <- if (is.null(res$total_results)) NA_real_ else as.numeric(res$total_results)
    } else {
      below <- spId == id | vapply(spAncestors, function(a) id %in% a, logical(1))
      out$records[i] <- sum(spCount[below])
    }
  }
  out
}
