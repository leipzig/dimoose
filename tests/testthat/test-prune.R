taxaOf <- function(key) {
  l <- key$leads
  unique(l$Taxon[l$Next == "-" & nzchar(l$Taxon)])
}

# Every couplet has at least two leads and they do not all go to one place.
expectSplits <- function(key) {
  l <- key$leads
  dest <- ifelse(l$Next == "-", paste("taxon", l$Taxon), l$Next)
  n <- tapply(dest, l$Statement, function(x) length(unique(x)))
  expect_true(all(n >= 2))
  expect_length(key$validate(), 0)
}

tinyLeads <- function() {
  data.frame(
    Statement = c("1", "1", "2", "2", "3", "3", "4", "4"),
    Choice = rep(c("a", "b"), 4),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings",
                  "Scales on wings", "No scales", "Jumps", "Does not jump"),
    Next = c("2", "4", "-", "3", "-", "-", "-", "-"),
    Taxon = c("", "", "Diptera", "", "Lepidoptera", "Hymenoptera", "Siphonaptera", "Zygentoma"),
    Question = rep(c("Wings?", "How many wings?", "Wing surface?", "Jumping?"), each = 2),
    Image = c("wing", "nowing", "fly", "", "moth;wing", "wasp", "flea", ""),
    TaxonUrl = c("", "", "http://x/diptera", "", "http://x/lepidoptera", "http://x/hymenoptera", "http://x/flea", ""),
    Page = 1:8,
    stringsAsFactors = FALSE
  )
}

tinyKey <- function() {
  ids <- c("wing", "nowing", "fly", "moth", "wasp", "flea")
  meta <- data.frame(key = c("citation", paste0("image_", ids)),
                     value = c("A tiny key", paste0("data:image/png;base64,", ids)), stringsAsFactors = FALSE)
  keyFromLeads(tinyLeads(), "Tiny insects", meta)
}

test_that("pruneKey() keeps the named taxa and collapses a couplet left with one lead", {
  k <- pruneKey(tinyKey(), drop = "Hymenoptera")
  expect_s3_class(k, "dimoose")
  expect_setequal(taxaOf(k), c("Diptera", "Lepidoptera", "Siphonaptera", "Zygentoma"))
  expectSplits(k)
  l <- k$leads
  # couplet 3 is gone; lead 2b now ends in Lepidoptera and keeps its URL
  expect_false("3" %in% l$Statement)
  b <- l[l$Statement == "2" & l$Choice == "b", ]
  expect_equal(b$Next, "-")
  expect_equal(b$Taxon, "Lepidoptera")
  expect_equal(b$TaxonUrl, "http://x/lepidoptera")
  expect_equal(b$Note, "Scales on wings")
  expect_equal(b$Character, "Four wings")
  # optional and unknown columns survive
  expect_true(all(c("Question", "Image", "TaxonUrl", "Page") %in% names(l)))
  expect_equal(b$Page, 4L)
  expect_equal(k$desc, "Tiny insects")
  expect_equal(k$taxa$submitted_name, taxaOf(k))
})

test_that("pruneKey() drops embedded images that no lead shows any more", {
  k <- pruneKey(tinyKey(), drop = "Hymenoptera")
  # the wasp photo went with its lead; the moth and wing photos of the
  # collapsed lead 3a are now shown by lead 2b, which took its place
  expect_false("image_wasp" %in% k$meta$key)
  expect_true(all(c("citation", "image_wing", "image_nowing", "image_fly", "image_flea", "image_moth") %in% k$meta$key))
  expect_equal(k$leads$Image[k$leads$Statement == "2" & k$leads$Choice == "b"], "moth;wing")

  m <- pruneKey(montanaKey(), keep = "Populus")
  expect_setequal(setdiff(m$meta$key, c("citation", "pruned_note")),
                  paste0("image_", unique(unlist(strsplit(m$leads$Image[nzchar(m$leads$Image)], ";")))))
  expect_lt(nrow(m$meta), nrow(montanaKey()$meta))
})

test_that("the note of a collapsed couplet can be appended or discarded", {
  k <- pruneKey(tinyKey(), drop = "Hymenoptera", note = "append")
  expect_null(k$leads$Note)
  expect_equal(k$leads$Character[k$leads$Statement == "2" & k$leads$Choice == "b"], "Four wings [Scales on wings]")
  k <- pruneKey(tinyKey(), drop = "Hymenoptera", note = "none")
  expect_null(k$leads$Note)
  expect_equal(k$leads$Character[k$leads$Statement == "2" & k$leads$Choice == "b"], "Four wings")
})

test_that("chains of collapses and a collapsing root are handled", {
  # dropping the wingless taxa removes couplet 4 and then the root
  k <- pruneKey(tinyKey(), keep = c("Diptera", "Lepidoptera", "Hymenoptera"))
  expectSplits(k)
  expect_setequal(k$leads$Statement, c("2", "3"))
  expect_equal(metaValue(k$meta, "pruned_note"), "Wings present")

  # Lepidoptera and Zygentoma: 3 collapses into 2b, 2 into 1a, 4 into 1b
  k <- pruneKey(tinyKey(), keep = c("Lepidoptera", "Zygentoma"))
  expectSplits(k)
  l <- k$leads
  expect_equal(l$Statement, c("1", "1"))
  expect_equal(l$Taxon, c("Lepidoptera", "Zygentoma"))
  expect_equal(l$Note, c("Four wings; Scales on wings", "Does not jump"))
  expect_true(is.na(metaValue(k$meta, "pruned_note")))

  # a chain that ends at the root
  k <- pruneKey(tinyKey(), keep = c("Lepidoptera", "Hymenoptera"))
  expectSplits(k)
  expect_equal(k$leads$Statement, c("3", "3"))
  expect_equal(metaValue(k$meta, "pruned_note"), "Wings present; Four wings")
})

test_that("pruning to one taxon or to none is an error", {
  expect_error(pruneKey(tinyKey(), keep = "Diptera"), "Only one taxon is left.*Diptera")
  expect_error(suppressWarnings(pruneKey(tinyKey(), keep = "Coleoptera")), "No taxon of the key is left")
  expect_error(pruneKey(tinyKey(), drop = taxaOf(tinyKey())), "No taxon of the key is left")
  expect_warning(pruneKey(tinyKey(), keep = c("Diptera", "Zygentoma", "Coleoptera")), "matched no taxon.*Coleoptera")
  expect_warning(pruneKey(tinyKey(), drop = "Coleoptera"), "`drop` matched no taxon")
  expect_error(pruneKey(tinyLeads(), keep = "Diptera"), "dimoose object")
})

test_that("pruneKey() with nothing to remove returns an equivalent key", {
  k <- pruneKey(tinyKey())
  expect_equal(k$leads, tinyKey()$leads)
  expect_equal(k$meta, tinyKey()$meta)
})

test_that("renumber = TRUE numbers the couplets in reading order", {
  k <- pruneKey(tinyKey(), drop = "Diptera", renumber = TRUE)
  expectSplits(k)
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2", "3", "3"))
  # 1a skipped couplet 2 and goes to the old couplet 3, now 2
  expect_equal(l$Next, c("2", "3", "-", "-", "-", "-"))
  expect_equal(l$Taxon[3:6], c("Lepidoptera", "Hymenoptera", "Siphonaptera", "Zygentoma"))

  s <- pruneKey(sharkKey(), keep = c("Squalidae", "Lamnidae", "Alopiidae", "Carcharhinidae"), renumber = TRUE)
  expectSplits(s)
  expect_equal(unique(s$leads$Statement), as.character(seq_len(3)))
  nx <- s$leads$Next[s$leads$Next != "-"]
  expect_true(all(as.integer(nx) > as.integer(s$leads$Statement[s$leads$Next != "-"])))
  # FishBase's Prev column follows the new numbers
  expect_equal(s$leads$Prev[s$leads$Statement == "1"], c("1", "1"))
  expect_true(all(s$leads$Prev %in% s$leads$Statement))
})

test_that("a couplet reached from several leads is collapsed for all of them", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3", "4", "4"),
    Choice = rep(c("a", "b"), 4),
    Character = paste("character", 1:8),
    Next = c("2", "3", "-", "4", "-", "4", "-", "-"),
    Taxon = c("", "", "A", "", "B", "", "C", "D"),
    stringsAsFactors = FALSE
  )
  dag <- keyFromLeads(leads, "DAG")
  expect_length(dag$validate(), 0)
  k <- pruneKey(dag, drop = "D")
  expectSplits(k)
  l <- k$leads
  expect_equal(l$Next, c("2", "3", "-", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "", "A", "C", "B", "C"))
  expect_equal(l$Note, c("", "", "", "character 7", "", "character 7"))

  # dropping C and D removes the shared couplet's parents' leads altogether
  k <- pruneKey(dag, drop = c("C", "D"))
  expectSplits(k)
  expect_equal(k$leads$Taxon, c("A", "B"))

  # C is now reached directly from 1a as well as through couplet 3
  k <- pruneKey(dag, drop = c("A", "D"))
  expectSplits(k)
  expect_equal(k$leads$Statement, c("1", "1", "3", "3"))
  expect_equal(k$leads$Taxon, c("C", "", "B", "C"))
  expect_equal(k$leads$Note[1], "character 4; character 7")
})

test_that("a couplet whose leads all end in the same place is collapsed", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3"), Choice = rep(c("a", "b"), 3),
    Character = paste("character", 1:6),
    Next = c("2", "-", "-", "3", "-", "-"), Taxon = c("", "A", "B", "", "B", "C"),
    stringsAsFactors = FALSE
  )
  key <- keyFromLeads(leads, "B twice")
  expect_length(key$validate(), 0)
  # without C, couplet 3 collapses and both leads of couplet 2 end in B
  k <- pruneKey(key, drop = "C")
  expectSplits(k)
  expect_equal(k$leads$Statement, c("1", "1"))
  expect_equal(k$leads$Taxon, c("B", "A"))
  # neither of couplet 2's alternative leads is a character of B
  expect_true(is.null(k$leads$Note) || all(k$leads$Note == ""))
})

test_that("a taxon at several terminal leads is kept at all of them", {
  a <- arachnidaKey()
  expect_equal(sum(a$leads$Taxon == "Schizomida"), 2)
  k <- pruneKey(a, drop = c("Uropygi", "Amblypygi"))
  expectSplits(k)
  expect_equal(sum(k$leads$Taxon == "Schizomida"), 2)
  expect_false(any(c("6", "10") %in% k$leads$Statement))
  expect_true("Page" %in% names(k$leads))

  k <- pruneKey(a, keep = c("Schizomida", "Araneae"))
  expectSplits(k)
  expect_setequal(taxaOf(k), c("Schizomida", "Araneae"))
  expect_equal(nrow(k$leads), 2)
})

test_that("taxa are matched by label, scientific name and genus", {
  taxa <- c("Bur oak (Quercus macrocarpa)", "Quaking aspen (Populus tremuloides)",
            "Plains cottonwood (Populus deltoides)", "Salix", "Betula papyrifera")
  hit <- function(x, ...) taxa[prnMatchTaxa(taxa, x, ...)$taxa]
  expect_equal(hit("Bur oak (Quercus macrocarpa)"), taxa[1])
  expect_equal(hit("quercus  MACROCARPA"), taxa[1])
  expect_equal(hit("White oak (Quercus macrocarpa)"), taxa[1])
  expect_equal(hit("Paper birch (Betula papyrifera)"), taxa[5])
  # a genus stands for its species
  expect_equal(hit("Populus"), taxa[2:3])
  expect_equal(hit("Populus", ranks = "exact"), character())
  # a species keeps its genus only when asked (keep, not drop)
  expect_equal(hit("Salix amygdaloides", genusOfSpecies = TRUE), "Salix")
  expect_equal(hit("Salix amygdaloides", genusOfSpecies = FALSE), character())
  expect_equal(hit("Salix amygdaloides", ranks = "exact", genusOfSpecies = TRUE), character())
  expect_equal(unname(prnMatchTaxa(taxa, c("Salix", "Ulmus"))$used), c(TRUE, FALSE))

  m <- montanaKey()
  k <- pruneKey(m, keep = c("Populus", "Acer glabrum", "Paper birch (Betula papyrifera)"))
  expect_setequal(scientificPart(taxaOf(k)),
                  c("Populus angustifolia", "Populus tremuloides", "Populus deltoides", "Populus trichocarpa",
                    "Acer glabrum", "Betula papyrifera"))
  expect_error(suppressWarnings(pruneKey(m, keep = "Populus", ranks = "exact")), "No taxon")

  leads <- data.frame(Statement = "1", Choice = c("a", "b", "c"), Character = c("x", "y", "z"), Next = "-",
                      Taxon = c("Quercus", "Populus", "Acer"), stringsAsFactors = FALSE)
  genera <- keyFromLeads(leads, "Genera")
  expect_setequal(taxaOf(pruneKey(genera, keep = c("Quercus macrocarpa", "Populus"))), c("Quercus", "Populus"))
  expect_setequal(taxaOf(suppressWarnings(pruneKey(genera, drop = "Quercus macrocarpa"))), c("Quercus", "Populus", "Acer"))
})

test_that("pruning the example keys gives valid keys", {
  for (make in list(sharkKey, arachnidaKey, montanaKey, vibrioKey)) {
    key <- make()
    taxa <- taxaOf(key)
    set.seed(42)
    for (n in unique(pmin(length(taxa), c(2, 3, 5, length(taxa) - 1, length(taxa))))) {
      keep <- sample(taxa, n)
      for (renumber in c(FALSE, TRUE)) {
        k <- pruneKey(key, keep = keep, ranks = "exact", renumber = renumber)
        expect_setequal(taxaOf(k), keep)
        expectSplits(k)
        expect_true(all(setdiff(names(key$leads), "Prev") %in% names(k$leads)))
        expect_equal(k$summary()$taxa, n)
        # still exports
        if (n <= 5 && !renumber) expect_match(exportWizard(k, map = FALSE), "<html", fixed = TRUE)
      }
    }
  }
})

test_that("pruning keeps the machine tests of a key with features consistent", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2"), Choice = rep(c("a", "b"), 2),
    Character = c("f1 high", "f1 low", "f2 high", "f2 low"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "A", "B", "C"),
    Feature = c("f1", "f1", "f2", "f2"), Test = c(">", "<=", ">", "<="), Threshold = c(0.5, 0.5, 0.2, 0.2),
    stringsAsFactors = FALSE
  )
  features <- data.frame(id = c("f1", "f2"), label = c("one", "two"), kind = "score", stringsAsFactors = FALSE)
  key <- keyFromLeads(leads, "Machine key", features = features)
  expect_length(key$validate(), 0)
  k <- pruneKey(key, drop = "A")
  expect_length(k$validate(), 0)
  expect_equal(k$features$id, "f2")
  expect_equal(k$leads$Threshold, c(0.2, 0.2))
  k <- pruneKey(key, drop = "C")
  expect_length(k$validate(), 0)
  expect_equal(k$features$id, "f1")
  expect_equal(k$leads$Taxon, c("B", "A"))
})

# ---- mergeKeys ---------------------------------------------------------------

familyKey <- function() {
  keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2"), Choice = rep(c("a", "b"), 2),
    Character = c("Fruit an acorn", "Fruit not an acorn", "Seeds cottony", "Fruit a samara"),
    Next = c("-", "2", "-", "-"), Taxon = c("Oaks (Fagaceae)", "", "Willows (Salicaceae)", "Sapindaceae"),
    Image = c("acorn", "", "catkin", ""), TaxonUrl = c("", "", "http://x/salicaceae", ""),
    stringsAsFactors = FALSE
  ), "Families", data.frame(key = c("citation", "image_acorn", "image_catkin"),
                            value = c("Family book", "data:image/png;base64,AAAA", "data:image/png;base64,BBBB"),
                            stringsAsFactors = FALSE))
}

generaKey <- function() {
  keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2"), Choice = rep(c("a", "b"), 2),
    Character = c("Buds with one scale", "Buds with several scales", "Petiole flat", "Petiole round"),
    Next = c("-", "2", "-", "-"), Taxon = c("Salix", "", "Aspen", "Cottonwood"),
    Question = rep(c("Bud scales?", "Petiole?"), each = 2), Image = c("bud", "", "catkin", ""),
    stringsAsFactors = FALSE
  ), "Genera of Salicaceae", data.frame(key = c("citation", "image_bud", "image_catkin", "node_label"),
                                        value = c("Genus book", "data:image/png;base64,CCCC",
                                                  "data:image/png;base64,DDDD", "Step"),
                                        stringsAsFactors = FALSE))
}

test_that("mergeKeys() grafts a key onto a result and renumbers", {
  k <- mergeKeys(familyKey(), generaKey(), at = "Salicaceae")
  expect_s3_class(k, "dimoose")
  expect_length(k$validate(), 0)
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2", "3", "3", "4", "4"))
  expect_equal(l$Next, c("-", "2", "3", "-", "-", "4", "-", "-"))
  expect_equal(l$Taxon, c("Oaks (Fagaceae)", "", "", "Sapindaceae", "Salix", "", "Aspen", "Cottonwood"))
  expect_equal(l$Character[3], "Seeds cottony")
  expect_equal(l$TaxonUrl[3], "")
  # a column only one key has is blank for the other
  expect_equal(l$Question, c("", "", "", "", "Bud scales?", "Bud scales?", "Petiole?", "Petiole?"))
  expect_equal(k$desc, "Families")
  expect_setequal(k$taxa$submitted_name, c("Oaks (Fagaceae)", "Sapindaceae", "Salix", "Aspen", "Cottonwood"))
  expect_equal(k$summary()$taxa, 5)
  expect_match(exportWizard(k, map = FALSE), "Buds with one scale", fixed = TRUE)
})

test_that("mergeKeys() combines metadata and keeps clashing images apart", {
  k <- mergeKeys(familyKey(), generaKey(), at = "Willows (Salicaceae)")
  expect_equal(metaValue(k$meta, "citation"), "Family book Willows (Salicaceae): Genus book")
  expect_equal(metaValue(k$meta, "node_label"), "Step")
  expect_equal(metaValue(k$meta, "image_bud"), "data:image/png;base64,CCCC")
  # both keys had an image called catkin, with different pictures
  expect_equal(metaValue(k$meta, "image_catkin"), "data:image/png;base64,BBBB")
  expect_equal(metaValue(k$meta, "image_catkin_2"), "data:image/png;base64,DDDD")
  expect_equal(k$leads$Image[k$leads$Taxon == "Aspen"], "catkin_2")
  expect_equal(k$leads$Image[k$leads$Character == "Seeds cottony"], "catkin")
  expect_false(anyDuplicated(k$meta$key) > 0)
})

test_that("mergeKeys(labels = 'prefix') keeps the key's couplet names", {
  k <- mergeKeys(familyKey(), generaKey(), at = "Salicaceae", labels = "prefix")
  expect_length(k$validate(), 0)
  expect_equal(k$leads$Statement, c("1", "1", "2", "2", "Salicaceae.1", "Salicaceae.1", "Salicaceae.2", "Salicaceae.2"))
  expect_equal(k$leads$Next[3], "Salicaceae.1")
  expect_equal(k$leads$Next[6], "Salicaceae.2")
  k <- mergeKeys(familyKey(), generaKey(), at = "Salicaceae", labels = "prefix", prefix = "S")
  expect_length(k$validate(), 0)
  expect_equal(unique(k$leads$Statement), c("1", "2", "S1", "S2"))
})

test_that("mergeKeys() grafts at every lead that ends in the taxon and checks its input", {
  a <- arachnidaKey()
  k <- mergeKeys(a, generaKey(), at = "Schizomida")
  expect_length(k$validate(), 0)
  expect_false("Schizomida" %in% k$leads$Taxon)
  expect_equal(k$summary()$taxa, 10 + 3)
  expect_equal(k$summary()$couplets, 11 + 2)
  # both leads that ended in Schizomida go to the same couplet
  salixCouplet <- k$leads$Statement[k$leads$Taxon == "Salix"]
  expect_equal(sum(k$leads$Next == salixCouplet), 2)
  expect_true("Page" %in% names(k$leads))

  expect_error(mergeKeys(familyKey(), generaKey(), at = "Rosaceae"), "is not a result of `key`")
  expect_error(mergeKeys(familyKey(), generaKey(), at = c("a", "b")), "one result")
  expect_error(mergeKeys(familyKey(), "x", at = "Salicaceae"), "dimoose object")

  # merging and pruning undo each other
  merged <- mergeKeys(familyKey(), generaKey(), at = "Salicaceae")
  back <- pruneKey(merged, keep = c("Salix", "Aspen", "Cottonwood"), renumber = TRUE)
  expect_equal(back$leads$Character, generaKey()$leads$Character)
  expect_equal(back$leads$Next, generaKey()$leads$Next)
})

# ---- regionalKey -------------------------------------------------------------

fromJson <- function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)

# A stand-in for GBIF: species/match, occurrence/search and geocode/gadm/search
# answered from canned JSON. Records what was asked.
fakeGbif <- function(counts, synonyms = character()) {
  keys <- stats::setNames(seq_along(counts) + 1000L, names(counts))
  log <- new.env()
  log$calls <- list()
  fetch <- function(url, query = list()) {
    log$calls[[length(log$calls) + 1]] <- list(url = url, query = query)
    if (grepl("species/match$", url)) {
      if (query$name %in% names(synonyms)) {
        return(fromJson(sprintf(
          '{"usageKey": 9999, "acceptedUsageKey": %d, "canonicalName": "%s", "rank": "SPECIES", "status": "SYNONYM", "matchType": "EXACT"}',
          keys[[synonyms[[query$name]]]], query$name)))
      }
      if (!query$name %in% names(keys)) {
        return(fromJson('{"confidence": 100, "matchType": "NONE", "synonym": false}'))
      }
      return(fromJson(sprintf(
        '{"usageKey": %d, "scientificName": "%s L.", "canonicalName": "%s", "rank": "SPECIES", "status": "ACCEPTED", "matchType": "EXACT"}',
        keys[[query$name]], query$name, query$name)))
    }
    if (grepl("occurrence/search$", url)) {
      n <- counts[[match(query$taxonKey, keys)]]
      return(fromJson(sprintf('{"offset": 0, "limit": 0, "endOfRecords": false, "count": %d, "results": [], "facets": []}', n)))
    }
    if (grepl("geocode/gadm/search$", url)) {
      if (query$q == "Flathead") {
        return(fromJson('{"offset":0,"limit":100,"endOfRecords":true,"count":1,"results":[{"id":"USA.27.15_1","name":"Flathead","gadmLevel":2,"type":["County"],"higherRegions":[{"id":"USA","name":"United States"},{"id":"USA.27_1","name":"Montana"}]}]}'))
      }
      if (tolower(query$q) == "montana") {
        return(fromJson('{"count":3,"results":[{"id":"BGR.10_1","name":"Montana","gadmLevel":1,"higherRegions":[{"id":"BGR","name":"Bulgaria"}]},{"id":"USA.27_1","name":"Montana","gadmLevel":1,"variantName":["MT","Mont."],"higherRegions":[{"id":"USA","name":"United States"}]},{"id":"ROU.1.56_1","name":"Rosia Montana","gadmLevel":2,"higherRegions":[{"id":"ROU","name":"Romania"},{"id":"ROU.1_1","name":"Alba"}]}]}'))
      }
      return(fromJson('{"offset":0,"limit":100,"endOfRecords":true,"count":0,"results":[]}'))
    }
    stop("unexpected request: ", url)
  }
  list(fetch = fetch, log = log, keys = keys)
}

montanaCounts <- function() {
  c("Acer negundo" = 0, "Fraxinus pennsylvanica" = 2, "Acer glabrum" = 310, "Quercus macrocarpa" = 0,
    "Salix amygdaloides" = 1, "Populus angustifolia" = 4, "Populus tremuloides" = 93, "Populus deltoides" = 3,
    "Populus trichocarpa" = 60, "Betula papyrifera" = 120, "Betula occidentalis" = 80)
}

test_that("regionalKey() prunes to the taxa GBIF has records of in the place", {
  gbif <- fakeGbif(montanaCounts())
  expect_message(k <- regionalKey(montanaKey(), "USA.27.15_1", kingdom = "Plantae", fetch = gbif$fetch),
                 "Kept 9 of 11 taxa recorded in GADM region USA.27.15_1 \\(GBIF\\)")
  expect_s3_class(k, "dimoose")
  expect_length(k$validate(), 0)
  expect_equal(k$summary()$taxa, 9)
  expect_false(any(grepl("Acer negundo|Quercus", k$leads$Taxon)))

  rec <- attr(k, "records")
  expect_equal(names(rec), c("Taxon", "name", "matched", "id", "records", "kept"))
  expect_equal(nrow(rec), 11)
  expect_equal(rec$records[match(names(montanaCounts()), rec$name)], unname(montanaCounts()))
  expect_equal(rec$kept, rec$records >= 1)
  expect_equal(rec$Taxon[rec$name == "Quercus macrocarpa"], "Bur oak (Quercus macrocarpa)")
  expect_equal(rec$id[rec$name == "Acer negundo"], "1001")
  expect_equal(attr(k, "place"), "GADM region USA.27.15_1")

  # two requests per taxon, with the real GBIF parameter names
  calls <- gbif$log$calls
  expect_length(calls, 22)
  expect_equal(calls[[1]]$url, "https://api.gbif.org/v1/species/match")
  expect_equal(calls[[1]]$query$kingdom, "Plantae")
  occ <- calls[[2]]
  expect_equal(occ$url, "https://api.gbif.org/v1/occurrence/search")
  expect_equal(occ$query$gadmGid, "USA.27.15_1")
  expect_equal(occ$query$limit, 0)
  expect_equal(occ$query$occurrenceStatus, "PRESENT")
  expect_true(occ$query$taxonKey %in% gbif$keys)
})

test_that("minRecords sets how many records a taxon needs", {
  gbif <- fakeGbif(montanaCounts())
  k <- suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", minRecords = 50, fetch = gbif$fetch))
  expect_length(k$validate(), 0)
  expect_setequal(scientificPart(taxaOf(k)),
                  c("Acer glabrum", "Populus tremuloides", "Populus trichocarpa", "Betula papyrifera", "Betula occidentalis"))
  rec <- attr(k, "records")
  expect_equal(sum(rec$kept), 5)
  expect_equal(rec$records[rec$name == "Populus deltoides"], 3)
  expect_false(rec$kept[rec$name == "Populus deltoides"])

  expect_error(suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", minRecords = 1000, fetch = gbif$fetch)),
               "None of the key's 11 taxa has 1000 records")
  expect_error(suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", minRecords = 200, fetch = gbif$fetch)),
               "Only one of the key's taxa.*Acer glabrum")
  expect_error(regionalKey(montanaKey(), "USA.27.15_1", minRecords = NA, fetch = gbif$fetch), "minRecords")
})

test_that("regionalKey() returns the whole key when every taxon is recorded", {
  gbif <- fakeGbif(montanaCounts() + 1)
  k <- suppressMessages(regionalKey(montanaKey(), "USA.27_1", fetch = gbif$fetch))
  expect_equal(k$leads, montanaKey()$leads)
  expect_true(all(attr(k, "records")$kept))
})

test_that("GBIF places: GADM ids, countries, polygons, parameter lists and names", {
  f <- function(url, query = list()) stop("no request expected")
  expect_equal(prnGbifPlace("USA.27.15_1", f)$query, list(gadmGid = "USA.27.15_1"))
  expect_equal(prnGbifPlace("USA", f)$query, list(gadmGid = "USA"))
  expect_equal(prnGbifPlace("CH", f)$query, list(country = "CH"))
  wkt <- "POLYGON((-114.5 48, -113.5 48, -113.5 48.5, -114.5 48.5, -114.5 48))"
  expect_equal(prnGbifPlace(wkt, f)$query, list(geometry = wkt))
  expect_equal(prnGbifPlace(list(country = "US", stateProvince = "Montana"), f)$query,
               list(country = "US", stateProvince = "Montana"))
  expect_error(prnGbifPlace(list("US"), f), "named GBIF occurrence search parameters")
  expect_error(prnGbifPlace(c("a", "b"), f), "one string")

  gbif <- fakeGbif(montanaCounts())
  where <- prnGbifPlace("Flathead County, Montana", gbif$fetch)
  expect_equal(where$query, list(gadmGid = "USA.27.15_1"))
  expect_equal(where$label, "Flathead, Montana, United States (GADM USA.27.15_1)")
  # "Flathead County" finds nothing, so the search is repeated without "County"
  expect_equal(vapply(gbif$log$calls, function(x) x$query$q, ""), c("Flathead County", "Flathead"))
  expect_equal(prnGbifPlace("Montana, United States", gbif$fetch)$query, list(gadmGid = "USA.27_1"))
  expect_equal(prnGbifPlace("montana, usa", gbif$fetch)$query, list(gadmGid = "USA.27_1"))
  expect_error(prnGbifPlace("Montana", gbif$fetch), "could be any of 2 GADM regions.*BGR.10_1.*USA.27_1")
  # the regions GADM does have are listed, with the ids to give instead
  expect_error(prnGbifPlace("Montana, France", gbif$fetch),
               "no GADM region \"Montana\" in \"France\".*Montana, Bulgaria \\(BGR.10_1\\); Montana, United States \\(USA.27_1\\)")
  expect_error(prnGbifPlace("Atlantis", gbif$fetch), "no GADM region called")

  k <- suppressMessages(regionalKey(montanaKey(), "Flathead County, Montana", fetch = gbif$fetch))
  expect_equal(k$summary()$taxa, 9)
  k <- suppressMessages(regionalKey(montanaKey(), list(country = "US", stateProvince = "Montana"),
                                    filters = list(year = "2000,2025"), fetch = gbif$fetch))
  occ <- Filter(function(x) grepl("occurrence", x$url), gbif$log$calls)
  last <- occ[[length(occ)]]$query
  expect_equal(last$stateProvince, "Montana")
  expect_equal(last$year, "2000,2025")
  expect_null(last$gadmGid)
})

test_that("names GBIF does not know are kept or dropped as asked, and synonyms are counted", {
  counts <- montanaCounts()
  gbif <- fakeGbif(counts[names(counts) != "Betula occidentalis"])
  expect_warning(k <- suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", fetch = gbif$fetch)),
                 "GBIF does not know 1 of the key's taxa by name, so they were kept: Water birch")
  rec <- attr(k, "records")
  expect_true(is.na(rec$records[rec$name == "Betula occidentalis"]))
  expect_true(rec$kept[rec$name == "Betula occidentalis"])
  expect_true("Water birch (Betula occidentalis)" %in% k$leads$Taxon)

  expect_warning(k <- suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", unknown = "drop", fetch = gbif$fetch)),
                 "so they were dropped")
  expect_false("Water birch (Betula occidentalis)" %in% k$leads$Taxon)
  expect_length(k$validate(), 0)

  # the key's name is a synonym: counted under the accepted name's key
  names(counts)[names(counts) == "Populus trichocarpa"] <- "Populus balsamifera"
  gbif <- fakeGbif(counts, synonyms = c("Populus trichocarpa" = "Populus balsamifera"))
  k <- suppressMessages(regionalKey(montanaKey(), "USA.27.15_1", fetch = gbif$fetch))
  rec <- attr(k, "records")
  expect_equal(rec$records[rec$name == "Populus trichocarpa"], 60)
  expect_equal(rec$id[rec$name == "Populus trichocarpa"], as.character(gbif$keys[["Populus balsamifera"]]))
})

# A stand-in for iNaturalist: places/autocomplete, taxa and (paged)
# observations/species_counts from canned JSON.
fakeInat <- function(species, pageSize = 500) {
  log <- new.env()
  log$calls <- list()
  taxa <- list(
    Plantae = '{"id": 47126, "name": "Plantae", "rank": "kingdom", "matched_term": "Plantae"}',
    Populus = '{"id": 47566, "name": "Populus", "rank": "genus", "matched_term": "Populus"}',
    Salicaceae = '{"id": 47567, "name": "Salicaceae", "rank": "family", "matched_term": "Salicaceae"}',
    Fagaceae = '{"id": 47852, "name": "Fagaceae", "rank": "family", "matched_term": "Fagaceae"}',
    "Acer negundo" = '{"id": 47726, "name": "Acer negundo", "rank": "species", "matched_term": "Acer negundo"}',
    "Populus trichocarpa" = '{"id": 900, "name": "Populus balsamifera", "rank": "species", "matched_term": "Populus trichocarpa"}'
  )
  fetch <- function(url, query = list()) {
    log$calls[[length(log$calls) + 1]] <- list(url = url, query = query)
    if (grepl("places/autocomplete$", url)) {
      if (query$q == "Nowhere") return(fromJson('{"total_results": 0, "page": 1, "per_page": 20, "results": []}'))
      return(fromJson('{"total_results": 2, "page": 1, "per_page": 20, "results": [{"id": 111, "name": "Flathead Lake", "display_name": "Flathead Lake, MT, US", "place_type": 100}, {"id": 2379, "name": "Flathead", "display_name": "Flathead County, US, MT", "place_type": 9, "admin_level": 20}]}'))
    }
    if (grepl("/taxa$", url)) {
      hit <- taxa[[query$q]]
      # a fuzzy hit for anything else, which must not be taken for a match
      if (is.null(hit)) hit <- '{"id": 1, "name": "Something else", "rank": "species", "matched_term": "something"}'
      return(fromJson(sprintf('{"total_results": 1, "page": 1, "per_page": 30, "results": [%s]}', hit)))
    }
    if (grepl("observations/species_counts$", url)) {
      from <- (query$page - 1) * pageSize + 1
      rows <- if (from > length(species)) character() else species[from:min(length(species), from + pageSize - 1)]
      return(fromJson(sprintf('{"total_results": %d, "page": %d, "per_page": %d, "results": [%s]}',
                              length(species), query$page, pageSize, paste(rows, collapse = ","))))
    }
    stop("unexpected request: ", url)
  }
  list(fetch = fetch, log = log)
}

inatSpecies <- function() {
  row <- function(count, id, name, ancestors) {
    sprintf('{"count": %d, "taxon": {"id": %d, "name": "%s", "rank": "species", "ancestor_ids": [48460, 47126, %s, %d]}}',
            count, id, name, ancestors, id)
  }
  c(row(760, 59524, "Xerophyllum tenax", "47329"),
    row(310, 101, "Acer glabrum", "47727"),
    row(93, 102, "Populus tremuloides", "47567, 47566"),
    row(41, 900, "Populus balsamifera", "47567, 47566"),
    row(12, 103, "Betula papyrifera", "47851"),
    row(9, 104, "Betula occidentalis", "47851"),
    row(4, 105, "Populus angustifolia", "47567, 47566"),
    row(2, 106, "Salix amygdaloides", "47567, 47568"),
    row(1, 107, "Fraxinus pennsylvanica", "47700"),
    row(1, 108, "Quercus macrocarpa", "47852, 47851"))
}

test_that("regionalKey(source = 'inat') resolves the place and counts species", {
  inat <- fakeInat(inatSpecies())
  expect_message(
    expect_warning(
      k <- regionalKey(montanaKey(), "Flathead County", source = "inat", kingdom = "Plantae", fetch = inat$fetch),
      "iNaturalist does not know 1 of the key's taxa.*Plains cottonwood"),
    "Using iNaturalist place Flathead County, US, MT \\(id 2379\\)")
  expect_length(k$validate(), 0)
  rec <- attr(k, "records")
  get <- function(nm) rec$records[rec$name == nm]
  expect_equal(get("Acer glabrum"), 310)
  expect_equal(get("Populus tremuloides"), 93)
  # found under the name iNaturalist uses for it
  expect_equal(get("Populus trichocarpa"), 41)
  expect_equal(rec$matched[rec$name == "Populus trichocarpa"], "Populus balsamifera")
  # known to iNaturalist, not on the place's list
  expect_equal(get("Acer negundo"), 0)
  expect_false(rec$kept[rec$name == "Acer negundo"])
  # the lookup returned some other taxon: unknown, kept
  expect_true(is.na(get("Populus deltoides")))
  expect_true(rec$kept[rec$name == "Populus deltoides"])
  expect_equal(sum(rec$kept), 10)
  expect_match(attr(k, "place"), "Flathead County, US, MT (iNaturalist place 2379)", fixed = TRUE)

  counts <- Filter(function(x) grepl("species_counts", x$url), inat$log$calls)
  expect_length(counts, 1)
  q <- counts[[1]]$query
  expect_equal(q$place_id, "2379")
  expect_equal(q$quality_grade, "research")
  expect_equal(q$taxon_id, "47126")
  expect_equal(q$per_page, 500)
  expect_equal(q$page, 1)
})

test_that("iNaturalist species lists are read page by page", {
  inat <- fakeInat(inatSpecies(), pageSize = 3)
  k <- suppressWarnings(suppressMessages(
    regionalKey(montanaKey(), 2379, source = "inat", minRecords = 5, unknown = "drop",
                filters = list(quality_grade = "any"), fetch = inat$fetch)))
  counts <- Filter(function(x) grepl("species_counts", x$url), inat$log$calls)
  expect_equal(vapply(counts, function(x) x$query$page, 0), 1:4)
  expect_equal(counts[[1]]$query$quality_grade, "any")
  expect_null(counts[[1]]$query$taxon_id)
  expect_false(any(grepl("places", vapply(inat$log$calls, function(x) x$url, ""))))
  expect_setequal(scientificPart(taxaOf(k)),
                  c("Acer glabrum", "Populus tremuloides", "Populus trichocarpa", "Betula papyrifera", "Betula occidentalis"))
  expect_length(k$validate(), 0)
})

test_that("iNaturalist counts a family or genus by the species below it", {
  inat <- fakeInat(inatSpecies())
  out <- prnInatCounts(c("Salicaceae", "Populus", "Fagaceae", "Betula papyrifera", "Other"),
                       list(place_id = "2379"), NULL, list(), inat$fetch)
  expect_equal(out$records, c(93 + 41 + 4 + 2, 93 + 41 + 4, 1, 12, NA))
  expect_equal(out$id, c("47567", "47566", "47852", "103", NA))
  expect_error(prnInatPlace("Nowhere", inat$fetch), "knows no place")
  expect_error(prnInatCounts("Populus", list(place_id = "1"), "Animalia", list(), inat$fetch), "knows no taxon")
})

test_that("regionalKey() checks its arguments", {
  f <- function(url, query = list()) stop("no request expected")
  expect_error(regionalKey("x", "USA", fetch = f), "dimoose object")
  expect_error(regionalKey(montanaKey(), "USA", source = "ebird", fetch = f), "should be one of")
  expect_error(regionalKey(montanaKey(), "USA", fetch = "x"), "must be a function")
  expect_error(regionalKey(montanaKey(), "USA", filters = "x", fetch = f), "named list")
})

test_that("regionalKey() works against GBIF for Flathead County, Montana", {
  skip_on_cran()
  skip_if_offline()
  skip_if_unreachable("https://api.gbif.org/v1/species/match?name=Acer")
  k <- suppressMessages(regionalKey(montanaKey(), "Flathead County, Montana", kingdom = "Plantae"))
  expect_length(k$validate(), 0)
  rec <- attr(k, "records")
  expect_equal(nrow(rec), 11)
  expect_false(anyNA(rec$records))
  expect_match(attr(k, "place"), "USA.27.15_1", fixed = TRUE)
  # quaking aspen is common in Flathead County
  expect_true(rec$kept[rec$name == "Populus tremuloides"])
  expect_gt(rec$records[rec$name == "Populus tremuloides"], 10)
  expect_equal(k$summary()$taxa, sum(rec$kept))
})

test_that("regionalKey() works against iNaturalist for Flathead County, Montana", {
  skip_on_cran()
  skip_if_offline()
  skip_if_unreachable("https://api.inaturalist.org/v1/places/autocomplete?q=Flathead")
  k <- suppressMessages(regionalKey(montanaKey(), "Flathead County", source = "inat", kingdom = "Plantae"))
  expect_length(k$validate(), 0)
  rec <- attr(k, "records")
  expect_equal(nrow(rec), 11)
  expect_match(attr(k, "place"), "2379", fixed = TRUE)
  expect_true(rec$kept[rec$name == "Populus tremuloides"])
  expect_equal(k$summary()$taxa, sum(rec$kept))
})

# ---- review: invariants of pruneKey over every dataset key -------------------

# The taxa a key names: the taxa of a shared result "A / B" one by one.
taxaIn <- function(key) unique(unlist(strsplit(taxaOf(key), " / ", fixed = TRUE)))

# Every way from the first couplet to a result, as the leads taken
# (couplet and choice) and the taxon reached.
routes <- function(key) {
  l <- normalizeLeads(key$leads)
  root <- checkLeads(l)$root
  by <- split(seq_len(nrow(l)), l$Statement)
  out <- list()
  walk <- function(cp, taken) {
    for (i in by[[cp]]) {
      now <- c(taken, paste(l$Statement[i], l$Choice[i], sep = "|"))
      if (l$Next[i] == "-") {
        for (taxon in strsplit(l$Taxon[i], " / ", fixed = TRUE)[[1]]) out[[length(out) + 1]] <<- list(taxon = taxon, leads = now)
      } else {
        walk(l$Next[i], now)
      }
    }
  }
  walk(root, character())
  out
}

noteOf <- function(leads) if (is.null(leads$Note)) rep("", nrow(leads)) else leads$Note

# What must hold of pruneKey(key, keep): the key validates and names exactly
# the kept taxa, every couplet still splits, each kept taxon is reached by
# the leads it was reached by before (less the leads that are gone), the
# surviving leads say what they said, and pruning again changes nothing.
expectPruned <- function(key, keep, note = "column") {
  pruned <- pruneKey(key, keep = keep, ranks = "exact", note = note)
  expectSplits(pruned)
  expect_setequal(taxaIn(pruned), keep)
  l <- pruned$leads
  left <- paste(l$Statement, l$Choice, sep = "|")
  before <- Filter(function(r) r$taxon %in% keep, routes(key))
  sign <- function(rs, only = NULL) {
    unique(vapply(rs, function(r) paste(c(r$taxon, if (is.null(only)) r$leads else r$leads[r$leads %in% only]), collapse = " > "), ""))
  }
  expect_setequal(sign(routes(pruned)), sign(before, left))
  if (note != "append") {
    was <- key$leads
    expect_equal(l$Character, was$Character[match(left, paste(was$Statement, was$Choice, sep = "|"))])
  }
  again <- pruneKey(pruned, keep = keep, ranks = "exact", note = note)
  expect_identical(again$leads, pruned$leads)
  expect_identical(prnMeta(again$meta), prnMeta(pruned$meta))
  invisible(pruned)
}

# pruning to A and then to B is pruning to the taxa in both
expectComposes <- function(key, a, b) {
  both <- intersect(a, b)
  twice <- pruneKey(pruneKey(key, keep = a, ranks = "exact"), keep = both, ranks = "exact")
  once <- pruneKey(key, keep = both, ranks = "exact")
  x <- twice$leads
  y <- once$leads
  expect_identical(x[setdiff(names(x), "Note")], y[setdiff(names(y), "Note")])
  expect_identical(noteOf(x), noteOf(y))
  expect_identical(prnMeta(twice$meta), prnMeta(once$meta))
}

# A random key in which a couplet can be reached from several leads, a taxon
# from several results, and a couplet can have three leads; with photos.
randomKey <- function(nCouplets, nTaxa, share = 0.3) {
  rows <- list()
  for (cp in seq_len(nCouplets)) {
    for (choice in letters[seq_len(if (stats::runif(1) < 0.2) 3 else 2)]) {
      rows[[length(rows) + 1]] <- data.frame(
        Statement = as.character(cp), Choice = choice, Character = paste0("c", cp, choice), Next = "-", Taxon = "",
        Image = if (stats::runif(1) < 0.5) paste0("img", cp, choice) else "", stringsAsFactors = FALSE)
    }
  }
  l <- do.call(rbind, rows)
  for (cp in seq_len(nCouplets)[-1]) {
    free <- which(l$Next == "-" & as.integer(l$Statement) < cp)
    if (length(free)) l$Next[free[sample.int(length(free), 1)]] <- as.character(cp)
  }
  for (i in which(l$Next == "-")) {
    later <- setdiff(seq_len(nCouplets), seq_len(as.integer(l$Statement[i])))
    if (length(later) && stats::runif(1) < share) {
      l$Next[i] <- as.character(later[sample.int(length(later), 1)])
    } else {
      l$Taxon[i] <- paste0("X", sample.int(nTaxa, 1))
    }
  }
  ids <- unique(l$Image[nzchar(l$Image)])
  keyFromLeads(l, "Random key", data.frame(key = paste0("image_", ids), value = paste0("data:image/png;base64,", ids),
                                           stringsAsFactors = FALSE))
}

sharedMatrixKey <- function() {
  keyFromMatrix(data.frame(
    Taxon = c("A", "B", "C", "D", "E", "F"),
    wings = c("x", "x", "y", "y", "y", "z"), legs = c("p", "p", "p", "q", "q", "q"), eyes = c("m", "m", "m", "n", "n", "n"),
    stringsAsFactors = FALSE))
}

# A key that splits off one taxon at each couplet.
namesKey <- function(taxa) {
  n <- length(taxa)
  leads <- data.frame(
    Statement = rep(as.character(seq_len(n - 1)), each = 2), Choice = rep(c("a", "b"), n - 1),
    Character = paste("character", seq_len(2 * (n - 1))), Next = "-", Taxon = "", stringsAsFactors = FALSE)
  leads$Taxon[leads$Choice == "a"] <- taxa[seq_len(n - 1)]
  leads$Next[leads$Choice == "b"] <- c(as.character(seq_len(n - 1)[-1]), "-")
  leads$Taxon[nrow(leads)] <- taxa[n]
  keyFromLeads(leads, "Names")
}

test_that("pruning any dataset key to any of its taxa keeps the key's invariants", {
  withr::local_seed(20261119)
  keys <- list(shark = sharkKey(), arachnida = arachnidaKey(), montana = montanaKey(), vibrioBoth = vibrioKey(),
               vibrioMissing = vibrioKey("missing"), H2a = phylotreeKey("H2a"), shared = sharedMatrixKey())
  expect_true(any(grepl(" / ", taxaOf(keys$shared), fixed = TRUE)))
  for (name in names(keys)) {
    key <- keys[[name]]
    taxa <- taxaIn(key)
    for (run in 1:6) {
      a <- taxa[sample.int(length(taxa), sample(2:(length(taxa) - 1), 1))]
      # pruning to the two taxa of one shared result leaves nothing to key out
      one <- tryCatch(pruneKey(key, keep = a, ranks = "exact"), error = function(e) e)
      if (inherits(one, "error")) {
        expect_match(conditionMessage(one), "^Only one", info = name)
        next
      }
      expectPruned(key, a, note = c("column", "append", "none")[run %% 3 + 1])
      b <- taxa[sample.int(length(taxa), sample(2:length(taxa), 1))]
      if (length(intersect(a, b)) < 2) next
      if (inherits(tryCatch(pruneKey(key, keep = intersect(a, b), ranks = "exact"), error = function(e) e), "error")) next
      expectComposes(key, a, b)
      renumbered <- pruneKey(key, keep = a, ranks = "exact", renumber = TRUE)
      expectSplits(renumbered)
      expect_setequal(taxaIn(renumbered), a)
      expect_equal(unique(renumbered$leads$Statement), as.character(seq_along(unique(renumbered$leads$Statement))))
    }
  }
})

test_that("the invariants hold when couplets are reached from several leads", {
  withr::local_seed(4)
  tried <- 0
  for (i in 1:60) {
    key <- randomKey(sample(5:25, 1), sample(4:12, 1), share = stats::runif(1, 0.2, 0.5))
    taxa <- taxaIn(key)
    if (length(key$validate()) || length(taxa) < 3) next
    for (run in 1:3) {
      a <- taxa[sample.int(length(taxa), sample(2:(length(taxa) - 1), 1))]
      b <- taxa[sample.int(length(taxa), sample(2:length(taxa), 1))]
      if (length(intersect(a, b)) < 2) next
      tried <- tried + 1
      expectPruned(key, a)
      expectComposes(key, a, b)
      # an embedded image is kept exactly when a lead still shows it
      p <- pruneKey(key, keep = a, ranks = "exact")
      shown <- unique(unlist(strsplit(p$leads$Image[nzchar(p$leads$Image)], ";", fixed = TRUE)))
      expect_setequal(sub("^image_", "", grep("^image_", p$meta$key, value = TRUE)), shown)
    }
  }
  expect_gt(tried, 50)
})

test_that("pruning twice adds to the note of the first couplet instead of replacing it", {
  # before the fix the second prune overwrote pruned_note
  once <- pruneKey(montanaKey(), keep = c("Populus deltoides", "Populus angustifolia"))
  step <- pruneKey(montanaKey(), keep = "Populus")
  expect_true(nzchar(metaValue(step$meta, "pruned_note")))
  twice <- pruneKey(step, keep = c("Populus deltoides", "Populus angustifolia"))
  expect_equal(metaValue(twice$meta, "pruned_note"), metaValue(once$meta, "pruned_note"))
  expect_match(metaValue(twice$meta, "pruned_note"), metaValue(step$meta, "pruned_note"), fixed = TRUE)
  expect_equal(noteOf(twice$leads), noteOf(once$leads))
  # no Note column is added when there is nothing to say
  k <- keyFromLeads(data.frame(Statement = c("1", "1", "2", "2"), Choice = rep(c("a", "b"), 2), Character = letters[1:4],
                               Next = c("-", "2", "-", "-"), Taxon = c("A", "", "A", "B")), "k")
  expect_null(pruneKey(k, keep = c("A", "B"))$leads$Note)
})

test_that("a note true of every lead of a collapsed couplet is passed on", {
  # 2a and 2b both end in X once Y is gone (2b through couplet 3, whose lead
  # 3a says 'scaly'); couplet 2 goes, and nothing its leads say is a
  # character of X. Couplet 4 has one lead left, and that is one.
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3", "4", "4"), Choice = rep(c("a", "b"), 4),
    Character = c("big", "small", "red", "blue", "scaly", "smooth", "hairy", "bald"),
    Next = c("2", "-", "4", "3", "4", "-", "-", "-"), Taxon = c("", "Z", "", "", "", "Y", "X", "W"),
    Image = c("", "", "red", "", "scaly", "", "hairy", ""), ImageLink = c("", "", "", "", "", "", "http://x/hairy.png", ""),
    stringsAsFactors = FALSE)
  key <- keyFromLeads(leads, "k", data.frame(key = paste0("image_", c("red", "scaly", "hairy")), value = "data:image/png;base64,AA"))
  k <- pruneKey(key, keep = c("X", "Z"))
  expect_equal(k$leads$Taxon, c("X", "Z"))
  # 'hairy' is said on both ways through; 'red', 'blue' and 'scaly' are not
  expect_equal(k$leads$Note, c("hairy", ""))
  expect_equal(k$leads$Image, c("hairy", ""))
  expect_equal(k$leads$ImageLink, c("http://x/hairy.png", ""))
  expect_setequal(k$meta$key, "image_hairy")
  # the same in two steps
  two <- pruneKey(pruneKey(key, keep = c("X", "Z", "W")), keep = c("X", "Z"))
  expect_equal(two$leads, k$leads)
  expect_equal(pruneKey(key, keep = c("X", "Z"), note = "append")$leads$Character, c("big [hairy]", "small"))
  expect_equal(pruneKey(key, keep = c("X", "Z"), note = "none")$leads$Character, c("big", "small"))
  # notes of several collapsed couplets are one list, not brackets in brackets
  chain <- keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2", "3", "3"), Choice = rep(c("a", "b"), 3), Character = c("a", "b", "c", "d", "e", "f"),
    Next = c("2", "-", "3", "-", "-", "-"), Taxon = c("", "P", "", "Q", "R", "S")), "chain")
  expect_equal(pruneKey(chain, keep = c("P", "R"), note = "append")$leads$Character, c("a [c; e]", "b"))
  expect_equal(pruneKey(chain, keep = c("P", "R"))$leads$Note, c("c; e", ""))
})

test_that("photos of a collapsed lead go to the lead that takes its place", {
  leads <- tinyLeads()
  leads$ImageLink <- c("", "", "", "http://x/four.png", "http://x/moth.png", "", "", "")
  key <- keyFromLeads(leads, "Tiny insects", tinyKey()$meta)
  k <- pruneKey(key, drop = "Hymenoptera", note = "none")
  b <- k$leads[k$leads$Statement == "2" & k$leads$Choice == "b", ]
  expect_equal(b$Image, "moth;wing")
  expect_equal(b$ImageLink, "http://x/four.png;http://x/moth.png")
  expect_true("image_moth" %in% k$meta$key)
  # a first couplet that goes has no lead to hand them to
  k <- pruneKey(key, keep = c("Siphonaptera", "Zygentoma"))
  expect_equal(k$leads$Image, c("flea", ""))
  expect_false("image_nowing" %in% k$meta$key)
})

test_that("a shared result is the taxa it names", {
  key <- sharedMatrixKey()
  expect_setequal(taxaOf(key), c("A / B", "C", "D / E", "F"))
  # only A kept: the result becomes "A"
  k <- pruneKey(key, keep = c("A", "C", "F"))
  expect_setequal(taxaOf(k), c("A", "C", "F"))
  expectSplits(k)
  expect_setequal(taxaOf(pruneKey(key, drop = c("B", "D", "F"))), c("A", "C", "E"))
  # the whole result by its label
  expect_setequal(taxaOf(pruneKey(key, keep = c("A / B", "C"))), c("A / B", "C"))
  expect_setequal(taxaOf(pruneKey(key, drop = "D / E")), c("A / B", "C", "F"))
  expect_setequal(taxaOf(pruneKey(key, keep = c("a", "b", "E", "f"))), c("A / B", "E", "F"))
  # the two taxa of one result cannot be keyed out
  expect_error(pruneKey(key, keep = c("A", "B")), "Only one result is left after pruning \\(A / B\\)")
  expect_error(pruneKey(key, keep = "A"), "Only one taxon is left after pruning \\(A\\)")
  expect_warning(pruneKey(key, keep = c("A", "C", "Z")), "matched no taxon of the key: Z")
  # a slash in a common name does not make two taxa
  named <- keyFromLeads(data.frame(Statement = c("1", "1", "2", "2"), Choice = rep(c("a", "b"), 2), Character = letters[1:4],
                                   Next = c("-", "2", "-", "-"),
                                   Taxon = c("Aspen / Popple (Populus tremuloides)", "", "Salix", "Betula")), "k")
  expect_setequal(taxaOf(pruneKey(named, keep = c("Populus tremuloides", "Salix"))),
                  c("Aspen / Popple (Populus tremuloides)", "Salix"))
  # (an entry is read by the scientific name in its parentheses, so this names the one taxon)
  expect_error(pruneKey(named, keep = "Popple (Populus tremuloides)"),
               "Only one taxon is left after pruning \\(Aspen / Popple \\(Populus tremuloides\\)\\)")
  expect_error(suppressWarnings(pruneKey(named, keep = "Popple")), "No taxon of the key is left")
  # one taxon of a shared result is not taken for a rank above the result
  genera <- namesKey(c("Acer / Betula", "Acer negundo / Acer glabrum", "Salix", "Populus"))
  expect_setequal(taxaOf(pruneKey(genera, keep = c("Acer", "Salix"))), c("Acer", "Acer negundo / Acer glabrum", "Salix"))
  expect_setequal(taxaOf(pruneKey(genera, drop = "Acer negundo")), c("Acer / Betula", "Acer glabrum", "Salix", "Populus"))
})

test_that("names match through authors, subspecies, hybrid signs and case", {
  taxa <- c("Bur oak (Quercus macrocarpa)", "Quercus alba L.", "Carcharodon carcharias (Linnaeus, 1758)",
            "Populus balsamifera subsp. trichocarpa", "Populus × acuminata", "Populus", "Salicaceae",
            "×Cupressocyparis leylandii", "Acer negundo var. interius",
            "Árbol de Júpiter (Lagerstroemia indica)", "ACER GLABRUM", "Vibrio cholerae O1", "Vibrio cholerae non-O1", "Other")
  key <- namesKey(taxa)
  expect_length(key$validate(), 0)
  kept <- function(...) taxaOf(pruneKey(key, ...))
  # case, and a name whose author the key gives
  expect_setequal(kept(keep = c("quercus MACROCARPA", "Quercus alba")), taxa[1:2])
  # an author in parentheses is not a scientific name in parentheses
  expect_equal(prnSciName(taxa[c(1, 3)]), c("Quercus macrocarpa", "Carcharodon carcharias (Linnaeus, 1758)"))
  # a species keeps its subspecies, and (for keep) the genus-only result
  expect_setequal(kept(keep = c("Carcharodon carcharias", "Populus balsamifera")), taxa[c(3, 4, 6)])
  expect_setequal(kept(keep = c("Acer negundo", "acer glabrum", "LAGERSTROEMIA INDICA")), taxa[c(9, 10, 11)])
  # the hybrid sign typed as x, and in front of a genus
  expect_setequal(kept(keep = c("Populus x acuminata", "Cupressocyparis", "Other")), taxa[c(5, 6, 8, 14)])
  expect_setequal(kept(keep = "Populus"), taxa[4:6])
  # names that only begin alike are different taxa
  expect_setequal(kept(keep = c("Vibrio cholerae O1", "Other")), taxa[c(12, 14)])
  expect_setequal(kept(keep = "Vibrio cholerae"), taxa[12:13])
  # drop: a name given with its author, where the key has none; no genus is dropped for a species
  expect_false("Bur oak (Quercus macrocarpa)" %in% kept(drop = "Quercus macrocarpa Michx."))
  expect_true("Populus" %in% suppressWarnings(kept(drop = "Populus tremuloides")))
  expect_warning(kept(drop = "Populus tremuloides"), "matched no taxon")
  # ranks = "exact": whole labels and scientific names only
  expect_error(suppressWarnings(pruneKey(key, keep = c("Quercus alba", "Carcharodon carcharias"), ranks = "exact")),
               "No taxon of the key is left")
  expect_setequal(kept(keep = c("Quercus alba L.", "quercus macrocarpa", "populus × acuminata"), ranks = "exact"),
                  taxa[c(1, 2, 5)])
  # duplicates, blanks and factors are fine; other types are not names
  expect_setequal(kept(keep = c("Other", "Other", NA, "", "Salicaceae")), taxa[c(7, 14)])
  expect_setequal(kept(keep = factor(c("Other", "Salicaceae"))), taxa[c(7, 14)])
  expect_error(pruneKey(key, keep = 1:3), "`keep` must be a character vector")
  expect_error(pruneKey(key, drop = list("Other")), "`drop` must be a character vector")
  expect_error(pruneKey(key, keep = character()), "No taxon of the key is left")
})

test_that("pruning a large key does not take time that grows with its square", {
  skip_on_cran()
  # a balanced key to 4096 taxa: 4095 couplets, of which about half collapse
  n <- 4096
  couplet <- seq_len(n - 1)
  leads <- data.frame(Statement = rep(as.character(couplet), each = 2), Choice = rep(c("a", "b"), n - 1),
                      Character = paste("character", seq_len(2 * (n - 1))), stringsAsFactors = FALSE)
  child <- as.vector(rbind(2 * couplet, 2 * couplet + 1))
  leads$Next <- ifelse(child < n, as.character(child), "-")
  leads$Taxon <- ifelse(child < n, "", paste("Genus", paste0("species", child)))
  key <- keyFromLeads(leads, "Large")
  taxa <- taxaOf(key)
  keep <- taxa[seq(1, n, by = 2)]
  # took 16 s when every collapse went through the whole table again
  time <- system.time(k <- pruneKey(key, keep = keep, renumber = TRUE))[["elapsed"]]
  expect_lt(time, 8)
  expect_setequal(taxaOf(k), keep)
  expectSplits(k)
  expect_equal(nrow(k$leads), 2 * (length(keep) - 1))

  # a key 400 couplets deep, pruned to its two ends
  deep <- namesKey(paste("Taxon", 1:401))
  k <- pruneKey(deep, keep = c("Taxon 1", "Taxon 401"))
  expect_equal(k$leads$Taxon, c("Taxon 1", "Taxon 401"))
  expect_equal(length(strsplit(k$leads$Note[2], "; ", fixed = TRUE)[[1]]), 399)
})

test_that("the whole PhyloTree key prunes to 50 haplogroups", {
  skip_on_cran()
  key <- phylotreeKey()
  taxa <- taxaOf(key)
  expect_gt(length(taxa), 5000)
  withr::local_seed(2)
  keep <- sample(taxa, 50)
  time <- system.time(k <- pruneKey(key, keep = keep, ranks = "exact"))[["elapsed"]]
  expect_lt(time, 5)
  expect_setequal(taxaOf(k), keep)
  expectSplits(k)
})

# ---- review: mergeKeys -------------------------------------------------------

test_that("mergeKeys() does not guess between results of one name", {
  key <- namesKey(c("Bur oak (Quercus macrocarpa)", "Mossycup oak (Quercus macrocarpa)", "Quercus alba", "A / B"))
  # used to graft at both
  expect_error(mergeKeys(key, generaKey(), at = "Quercus macrocarpa"),
               "is the name of 2 results of `key`: Bur oak \\(Quercus macrocarpa\\); Mossycup oak \\(Quercus macrocarpa\\)")
  m <- mergeKeys(key, generaKey(), at = "mossycup oak (Quercus macrocarpa)")
  expect_length(m$validate(), 0)
  expect_true("Bur oak (Quercus macrocarpa)" %in% taxaOf(m))
  expect_false("Mossycup oak (Quercus macrocarpa)" %in% taxaOf(m))
  # a whole label wins over the same name in another label's parentheses
  key2 <- namesKey(c("Bur oak (Quercus macrocarpa)", "Quercus macrocarpa", "Quercus alba"))
  expect_true("Bur oak (Quercus macrocarpa)" %in% taxaOf(mergeKeys(key2, generaKey(), at = "Quercus macrocarpa")))
  expect_error(mergeKeys(key, generaKey(), at = "A"), "one of the taxa of the shared result \"A / B\"")
  expect_length(mergeKeys(key, generaKey(), at = "A / B")$validate(), 0)
  expect_error(mergeKeys(key, generaKey(), at = " "), "one result")
})

test_that("mergeKeys() renames a clashing image everywhere it is named", {
  meta <- function(data, url) data.frame(key = c("image_fig1", "image_url_fig1", "image_fig2"),
                                         value = c(data, url, "data:image/png;base64,SAME"), stringsAsFactors = FALSE)
  main <- keyFromLeads(data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("x", "y"), Next = "-",
                                  Taxon = c("Salicaceae", "Fagaceae"), Image = c("fig1", "fig2")), "Main",
                       meta("data:image/png;base64,AAAA", "http://main/fig1.png"))
  sub <- keyFromLeads(data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("p", "q"), Next = "-",
                                 Taxon = c("Salix", "Populus"),
                                 Image = c("http://sub/img/fig1.png;fig2", "fig1;http://sub/img/tn_fig1.gif"),
                                 ImageLink = c("http://sub/full/fig1.png", "")), "Sub",
                      meta("data:image/png;base64,BBBB", "http://sub/fig1.png"))
  m <- mergeKeys(main, sub, at = "Salicaceae")
  expect_length(m$validate(), 0)
  value <- function(k) m$meta$value[m$meta$key == k]
  # the picture and its address keep one id (the address used to get fig1_2_2)
  expect_setequal(m$meta$key, c("image_fig1", "image_url_fig1", "image_fig2", "image_fig1_2", "image_url_fig1_2"))
  expect_equal(value("image_fig1"), "data:image/png;base64,AAAA")
  expect_equal(value("image_fig1_2"), "data:image/png;base64,BBBB")
  expect_equal(value("image_url_fig1_2"), "http://sub/fig1.png")
  # the subkey's leads name the renamed image, whether by id or by file;
  # fig2 is the same picture in both keys and tn_fig1 is another image
  expect_equal(m$leads$Image[m$leads$Taxon == "Salix"], "http://sub/img/fig1_2.png;fig2")
  expect_equal(m$leads$Image[m$leads$Taxon == "Populus"], "fig1_2;http://sub/img/tn_fig1.gif")
  expect_equal(m$leads$Image[m$leads$Taxon == "Fagaceae"], "fig2")
  # (fig1 is still shown by the key's lead that now goes to the subkey)
  expect_setequal(prnImageIds(m$leads), c("fig1", "fig1_2", "fig2", "tn_fig1"))
  # a key grafted onto itself has no clashes, and is a valid key
  self <- mergeKeys(montanaKey(), montanaKey(), at = "Quercus macrocarpa")
  expect_length(self$validate(), 0)
  expect_equal(nrow(self$meta), nrow(montanaKey()$meta))
  expect_equal(nrow(self$leads), 2 * nrow(montanaKey()$leads))
  expect_equal(self$summary()$taxa, 11)
})

test_that("mergeKeys() keeps the features of both keys apart", {
  machine <- function(taxa, feature, features) {
    keyFromLeads(data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("high", "low"), Next = "-",
                            Taxon = taxa, Feature = feature, Test = c(">", "<="), Threshold = c(0.5, 0.5)),
                 "Machine", features = features)
  }
  f1 <- featureTable(c("f:a", "f:b"), "centroid_patch_max", embedding = list(c(1, 0), c(0, 1)))
  f2 <- featureTable(c("f:a", "g:c"), "text", prompt = c("p1", "p2"))
  main <- machine(c("Salicaceae", "Fagaceae"), "f:a", f1)
  # the subkey tests a feature of its own
  m <- suppressWarnings(mergeKeys(main, machine(c("Salix", "Populus"), "g:c", f2), at = "Salicaceae"))
  expect_length(m$validate(), 0)
  expect_equal(m$features$id, c("f:a", "f:b", "f:a_2", "g:c"))
  expect_equal(m$features$kind, c("centroid_patch_max", "centroid_patch_max", "text", "text"))
  expect_equal(m$features$embedding[[1]], c(1, 0))
  expect_null(m$features$embedding[[4]])
  # the subkey tests a feature that the key defines differently under the
  # same id: its leads must not be scored with the key's feature
  expect_warning(m <- mergeKeys(main, machine(c("Salix", "Populus"), "f:a", f2), at = "Salicaceae"),
                 "define f:a differently; the subkey's is renamed f:a_2")
  expect_length(m$validate(), 0)
  expect_equal(m$leads$Feature, c("f:a", "f:a", "f:a_2", "f:a_2"))
  expect_equal(m$features$prompt[m$features$id == "f:a_2"], "p1")
  # the same feature in both keys is listed once, without a warning
  expect_silent(m <- mergeKeys(main, machine(c("Salix", "Populus"), "f:b", f1), at = "Salicaceae"))
  expect_equal(m$features$id, c("f:a", "f:b"))
  expect_length(m$validate(), 0)
  # pruning the merged key leaves the features its leads still test
  expect_equal(pruneKey(m, keep = c("Salix", "Populus"))$features$id, "f:b")
})

# ---- review: regionalKey -----------------------------------------------------

test_that("the taxa of a shared result are looked up one by one", {
  key <- namesKey(c("Acer negundo / Acer glabrum", "Quercus macrocarpa", "Populus tremuloides / Populus deltoides",
                    "Betula papyrifera"))
  gbif <- fakeGbif(c("Acer negundo" = 0, "Acer glabrum" = 5, "Quercus macrocarpa" = 0, "Populus tremuloides" = 9,
                     "Populus deltoides" = 2, "Betula papyrifera" = 1))
  k <- suppressMessages(regionalKey(key, "USA.27.15_1", fetch = gbif$fetch))
  rec <- attr(k, "records")
  expect_equal(rec$Taxon, c("Acer negundo", "Acer glabrum", "Quercus macrocarpa", "Populus tremuloides",
                            "Populus deltoides", "Betula papyrifera"))
  expect_equal(rec$records, c(0, 5, 0, 9, 2, 1))
  expect_setequal(taxaOf(k), c("Acer glabrum", "Populus tremuloides / Populus deltoides", "Betula papyrifera"))
  expect_length(k$validate(), 0)
})

test_that("a key whose results are no names the source knows is an error, not an unpruned key", {
  gbif <- fakeGbif(montanaCounts())
  expect_error(suppressMessages(regionalKey(vibrioKey(), "CH", fetch = gbif$fetch)),
               "GBIF knows none of the key's 74 taxa by name .*Results must be scientific names")
})

test_that("a request that fails part of the way says where, and nothing is pruned", {
  gbif <- fakeGbif(montanaCounts())
  asked <- 0
  failing <- function(url, query = list()) {
    asked <<- asked + 1
    if (asked == 6) stop("Service Unavailable (HTTP 503).")
    gbif$fetch(url, query)
  }
  expect_error(regionalKey(montanaKey(), "USA.27.15_1", fetch = failing),
               "failed while asking GBIF about Acer glabrum \\(taxon 3 of 11\\), so nothing was pruned: Service Unavailable")
  inat <- fakeInat(inatSpecies())
  failing <- function(url, query = list()) {
    if (grepl("species_counts", url)) stop("Too Many Requests (HTTP 429).")
    inat$fetch(url, query)
  }
  expect_error(suppressMessages(regionalKey(montanaKey(), 2379, source = "inat", fetch = failing)),
               "failed while listing the species iNaturalist has for the place \\(page 1\\).*HTTP 429")
})

# an httr response with a JSON body, for prnFetch(get = )
fakeResponse <- function(status, body = "{}", headers = list()) {
  structure(list(url = "http://example.org", status_code = status,
                 headers = structure(c(list(`content-type` = "application/json"), headers), class = c("insensitive", "list")),
                 content = charToRaw(body)), class = "response")
}

test_that("the default fetch asks a busy or unreachable server again", {
  waits <- numeric()
  wait <- function(s) waits <<- c(waits, s)
  answers <- list(fakeResponse(429, headers = list(`retry-after` = "2")), fakeResponse(503), fakeResponse(200, '{"count": 7}'))
  n <- 0
  get <- function(url, ...) {
    n <<- n + 1
    answers[[n]]
  }
  expect_equal(prnFetch("https://api.gbif.org/v1/occurrence/search", list(limit = 0, taxonKey = NULL), wait = wait, get = get),
               list(count = 7))
  expect_equal(n, 3)
  # the wait the server asked for, then twice the first default wait
  expect_equal(waits, c(2, 10))
  # still failing after three tries: the HTTP error
  n <- 0
  answers <- list(fakeResponse(503), fakeResponse(503), fakeResponse(503))
  expect_error(prnFetch("https://api.gbif.org/v1/x", wait = wait, get = get), "503")
  expect_equal(n, 3)
  # not found is not asked again
  n <- 0
  answers <- list(fakeResponse(404))
  expect_error(prnFetch("https://api.gbif.org/v1/x", wait = wait, get = get), "404")
  expect_equal(n, 1)
  # no connection: tried again, then an error naming the host
  n <- 0
  get <- function(url, ...) {
    n <<- n + 1
    stop("Timeout was reached")
  }
  expect_error(prnFetch("https://api.gbif.org/v1/x", wait = wait, get = get), "Could not reach api.gbif.org: Timeout was reached")
  expect_equal(n, 3)
  # iNaturalist is asked no faster than once a second
  waits <- numeric()
  get <- function(url, ...) fakeResponse(200, '{"results": []}')
  prnFetch("https://api.inaturalist.org/v1/taxa", wait = wait, get = get)
  expect_equal(waits, 1)
})

test_that("GBIF matches that are not a plain accepted name are counted as the taxon meant", {
  # a genus GBIF has several equal matches for (as it has for Betula)
  genus <- fromJson('{"matchType": "NONE", "note": "Multiple equal matches for Betula", "alternatives": [
    {"usageKey": 9596658, "canonicalName": "Betula", "rank": "SPECIES", "status": "ACCEPTED", "kingdom": "Plantae"},
    {"usageKey": 2875008, "canonicalName": "Betula", "rank": "GENUS", "status": "ACCEPTED", "kingdom": "Plantae"},
    {"usageKey": 3258247, "canonicalName": "Betula", "rank": "GENUS", "status": "SYNONYM", "kingdom": "Animalia"},
    {"usageKey": 7607352, "canonicalName": "Berula", "rank": "GENUS", "status": "ACCEPTED", "kingdom": "Plantae"}]}')
  expect_equal(prnGbifUsage(genus, "Betula"), list(id = 2875008L, name = "Betula"))
  # two accepted genera of that name cannot be told apart without `kingdom`
  genus$alternatives[[3]]$status <- "ACCEPTED"
  expect_null(prnGbifUsage(genus, "Betula"))
  expect_null(prnGbifUsage(fromJson('{"matchType": "NONE", "alternatives": [{"usageKey": 1, "canonicalName": "Otter"}]}'), "Other"))
  expect_null(prnGbifUsage(fromJson('{"matchType": "HIGHERRANK", "usageKey": 6, "canonicalName": "Plantae"}'), "Acer nonesuch"))
  # a synonym: the accepted name's key
  synonym <- fromJson('{"usageKey": 3806052, "acceptedUsageKey": 6362904, "canonicalName": "Populus balsamifera trichocarpa",
    "rank": "SUBSPECIES", "status": "SYNONYM", "matchType": "EXACT", "species": "Populus trichocarpa", "speciesKey": 6362904}')
  expect_equal(prnGbifUsage(synonym, "Populus balsamifera subsp. trichocarpa"),
               list(id = 6362904L, name = "Populus balsamifera trichocarpa"))
  # a species name GBIF files under a subspecies (Negundo aceroides, under
  # Acer negundo subsp. negundo) is counted as the species
  filed <- fromJson('{"usageKey": 6359242, "acceptedUsageKey": 6359254, "canonicalName": "Negundo aceroides",
    "rank": "SPECIES", "status": "SYNONYM", "matchType": "EXACT", "species": "Acer negundo", "speciesKey": 3189866}')
  expect_equal(prnGbifUsage(filed, "Negundo aceroides"), list(id = 3189866L, name = "Acer negundo"))

  # through regionalKey: the genus is known, and counted under its key
  log <- list()
  fetch <- function(url, query = list()) {
    log[[length(log) + 1]] <<- query
    if (grepl("species/match$", url)) {
      if (query$name == "Betula") return(genus0)
      return(fromJson(sprintf('{"usageKey": %d, "canonicalName": "%s", "rank": "FAMILY", "status": "ACCEPTED", "matchType": "EXACT"}',
                              nchar(query$name), query$name)))
    }
    fromJson(sprintf('{"count": %d}', if (query$taxonKey == 2875008) 70L else 3L))
  }
  genus0 <- genus
  genus0$alternatives[[3]]$status <- "SYNONYM"
  k <- suppressMessages(regionalKey(namesKey(c("Birches (Betula)", "Salicaceae", "Fagaceae")), "USA.27.15_1", minRecords = 2,
                                    unknown = "drop", fetch = fetch))
  rec <- attr(k, "records")
  expect_equal(rec$id[rec$name == "Betula"], "2875008")
  expect_equal(rec$records[rec$name == "Betula"], 70)
  expect_equal(log[[1]]$verbose, "true")
})

# GADM search that answers anything with regions of other names
fakeGbifNear <- function() {
  function(url, query = list()) {
    fromJson('{"results":[{"id":"BGR.10_1","name":"Montana","higherRegions":[{"id":"BGR","name":"Bulgaria"}]},{"id":"USA.27_1","name":"Montana","higherRegions":[{"id":"USA","name":"United States"}]}]}')
  }
}

test_that("a GADM region can be told apart by an abbreviation GADM lists", {
  gbif <- fakeGbif(montanaCounts())
  # "MT" is no name or id of a region Flathead lies in; GADM lists it as
  # another name of Montana. This used to be an error.
  where <- prnGbifPlace("Flathead County, MT", gbif$fetch)
  expect_equal(where$query, list(gadmGid = "USA.27.15_1"))
  expect_equal(prnGbifPlace("Flathead County, MT, USA", gbif$fetch)$query, list(gadmGid = "USA.27.15_1"))
  expect_equal(prnGbifPlace("Flathead, US", gbif$fetch)$query, list(gadmGid = "USA.27.15_1"))
  expect_equal(prnGbifPlace("Montana, U.S.A.", gbif$fetch)$query, list(gadmGid = "USA.27_1"))
  expect_error(prnGbifPlace("Flathead County, Idaho", gbif$fetch),
               "no GADM region \"Flathead County\" in \"Idaho\". It knows: Flathead, Montana, United States \\(USA.27.15_1\\)")
  # no region of that name: the nearest are listed
  expect_error(prnGbifPlace("Montan", fakeGbifNear()), "no GADM region called \"Montan\". The nearest names are: Montana, Bulgaria \\(BGR.10_1\\)")
  expect_message(k <- regionalKey(montanaKey(), "Flathead County, MT", fetch = gbif$fetch),
                 "recorded in Flathead, Montana, United States \\(GADM USA.27.15_1\\)")
  expect_equal(k$summary()$taxa, 9)
})

test_that("iNaturalist places: which was used, the others, and parts after commas", {
  places <- '{"results": [
    {"id": 1917, "name": "Red Lake", "display_name": "Red Lake County, US, MN"},
    {"id": 585, "name": "Lake", "display_name": "Lake County, SD, US"},
    {"id": 3010, "name": "Lake", "display_name": "Lake County, US, MT"},
    {"id": 99, "name": "Lake County Forest", "display_name": "Lake County Forest, IL, US"}]}'
  asked <- character()
  fetch <- function(url, query = list()) {
    asked <<- c(asked, query$q)
    if (query$q == "Lake County") fromJson(places) else fromJson('{"results": []}')
  }
  # several places of the name: the first is used, and the message lists
  # the others, same-named ones first, with the ids to give instead
  expect_message(where <- prnInatPlace("Lake County", fetch),
                 "Using iNaturalist place Lake County, SD, US \\(id 585\\); 3 other places matched \"Lake County\": Lake County, US, MT \\(id 3010\\); Red Lake County, US, MN \\(id 1917\\).*give its id as `place`")
  expect_equal(where$query, list(place_id = "585"))
  # parts after a comma pick among them (the whole string finds nothing)
  asked <- character()
  expect_silent(where <- prnInatPlace("Lake County, MT", fetch))
  expect_equal(asked, c("Lake County, MT", "Lake County"))
  expect_equal(where$query, list(place_id = "3010"))
  expect_equal(where$label, "Lake County, US, MT (iNaturalist place 3010)")
  expect_equal(prnInatPlace("Lake County, mt, USA", fetch)$query, list(place_id = "3010"))
  expect_error(prnInatPlace("Lake County, Idaho", fetch),
               "no place \"Lake County\" in \"Idaho\". It knows: .*Lake County, US, MT \\(id 3010\\).*Give the id")
  # ids, also large ones given as numbers
  none <- function(url, query = list()) stop("no request expected")
  expect_equal(prnInatPlace(100000, none)$query, list(place_id = "100000"))
  expect_equal(prnInatPlace("2379", none)$query, list(place_id = "2379"))
  expect_error(prnInatPlace(list(1), none), "name or numeric id")
  expect_error(prnInatPlace(NA, none), "name or numeric id")
})

test_that("iNaturalist counts subspecies, hybrids and names with authors", {
  species <- c(
    '{"count": 59, "taxon": {"id": 78699, "name": "Populus trichocarpa", "rank": "species", "rank_level": 10, "ancestor_ids": [47126, 47566, 78699]}}',
    '{"count": 4, "taxon": {"id": 170936, "name": "Populus × acuminata", "rank": "hybrid", "rank_level": 10, "ancestor_ids": [47126, 47566, 170936]}}',
    '{"count": 30, "taxon": {"id": 55, "name": "Salix lasiandra", "rank": "species", "rank_level": 10, "ancestor_ids": [47126, 53453, 55]}}')
  log <- list()
  fetch <- function(url, query = list()) {
    log[[length(log) + 1]] <<- list(url = url, query = query)
    if (grepl("species_counts$", url)) {
      return(fromJson(sprintf('{"total_results": 3, "results": [%s]}', paste(species, collapse = ","))))
    }
    if (grepl("/taxa$", url)) {
      hit <- switch(query$q,
        "Salix lasiandra caudata" = '{"id": 81357, "name": "Salix lasiandra caudata", "rank": "variety", "rank_level": 5, "matched_term": "Salix lasiandra caudata"}',
        "Populus balsamifera trichocarpa" = '{"id": 78699, "name": "Populus trichocarpa", "rank": "species", "rank_level": 10, "matched_term": "Populus balsamifera trichocarpa"}',
        '{"id": 1, "name": "Something else", "rank": "species", "rank_level": 10, "matched_term": "something"}')
      return(fromJson(sprintf('{"results": [%s]}', hit)))
    }
    if (grepl("/observations$", url)) return(fromJson('{"total_results": 8, "results": []}'))
    stop("unexpected request: ", url)
  }
  key <- namesKey(c("Salix lasiandra var. caudata", "Black cottonwood (Populus balsamifera subsp. trichocarpa)",
                    "Populus x acuminata", "Salix lasiandra Benth.", "Quercus alba"))
  expect_warning(k <- suppressMessages(regionalKey(key, 2379, source = "inat", fetch = fetch)), "does not know 1 of the key's taxa.*Quercus alba")
  rec <- attr(k, "records")
  # a variety is not on the species list: its own observations are counted
  expect_equal(rec$records, c(8, 59, 4, 30, NA))
  expect_equal(rec$matched, c("Salix lasiandra caudata", "Populus trichocarpa", "Populus × acuminata", "Salix lasiandra", NA))
  one <- Filter(function(x) grepl("/observations$", x$url), log)
  expect_length(one, 1)
  expect_equal(one[[1]]$query$taxon_id, "81357")
  expect_equal(one[[1]]$query$per_page, 0)
  expect_equal(one[[1]]$query$place_id, "2379")
  expect_equal(one[[1]]$query$quality_grade, "research")
  # the key's own labels are what is kept
  expect_true("Black cottonwood (Populus balsamifera subsp. trichocarpa)" %in% taxaOf(k))
})

# ---- review, second pass -----------------------------------------------------

test_that("a taxon can be named by its common name alone", {
  # used to match nothing: "Bur oak" is neither the label nor the scientific name
  k <- pruneKey(montanaKey(), keep = c("bur oak", "Box elder", "Populus tremuloides"))
  expect_setequal(taxaOf(k), c("Bur oak (Quercus macrocarpa)", "Box elder (Acer negundo)", "Quaking aspen (Populus tremuloides)"))
  expect_false("Bur oak (Quercus macrocarpa)" %in% taxaOf(pruneKey(montanaKey(), drop = "Bur oak", ranks = "exact")))
  # part of a common name is not a name
  expect_warning(pruneKey(montanaKey(), keep = c("oak", "Acer")), "matched no taxon of the key: oak")
  # an author in parentheses leaves no common name before it
  key <- namesKey(c("Carcharodon carcharias (Linnaeus, 1758)", "Lamna nasus", "Isurus"))
  expect_setequal(taxaOf(pruneKey(key, keep = c("Carcharodon carcharias", "Isurus"))),
                  c("Carcharodon carcharias (Linnaeus, 1758)", "Isurus"))
  m <- mergeKeys(montanaKey(), generaKey(), at = "bur oak")
  expect_length(m$validate(), 0)
  expect_false("Bur oak (Quercus macrocarpa)" %in% taxaOf(m))
})

test_that("of several iNaturalist places of one name the state comes before the province or the park", {
  # as iNaturalist answers for "Montana": the Bulgarian province first
  places <- '{"results": [
    {"id": 8242, "name": "Montana", "display_name": "Montana, BG", "admin_level": 10, "bbox_area": 0.69},
    {"id": 16, "name": "Montana", "display_name": "Montana, US", "admin_level": 10, "bbox_area": 55.76},
    {"id": 19912, "name": "Montana", "display_name": "Montana, MT, BG", "admin_level": 20, "bbox_area": 0.17},
    {"id": 71652, "name": "Montana", "display_name": "Montana", "admin_level": null, "bbox_area": 0.00004},
    {"id": 103123, "name": "Rusca Montana", "display_name": "Rusca Montana, CS, RO", "admin_level": 20, "bbox_area": 0.03}]}'
  fetch <- function(url, query = list()) fromJson(places)
  expect_message(where <- prnInatPlace("Montana", fetch),
                 "Using iNaturalist place Montana, US \\(id 16\\); 4 other places matched \"Montana\": Montana, BG \\(id 8242\\); Montana, MT, BG \\(id 19912\\); Montana \\(id 71652\\); Rusca Montana")
  expect_equal(where$query, list(place_id = "16"))
})

test_that("a place with too many species to list is asked about taxon by taxon", {
  # the first page of 500 of 55,794 species; listing the rest would take
  # 111 more requests (it took 209 s for sharkKey() in Australia)
  first <- sprintf('{"count": %d, "taxon": {"id": %d, "name": "Species %d", "rank": "species", "rank_level": 10, "ancestor_ids": [1, %d]}}',
                   600:101, 1000 + 1:500, 1:500, 1000 + 1:500)
  first[1] <- '{"count": 5223, "taxon": {"id": 57819, "name": "Heterodontus portusjacksoni", "rank": "species", "rank_level": 10, "ancestor_ids": [1, 57818, 57819]}}'
  log <- list()
  fetch <- function(url, query = list()) {
    log[[length(log) + 1]] <<- list(url = url, query = query)
    if (grepl("species_counts$", url)) {
      return(fromJson(sprintf('{"total_results": 55794, "page": %d, "per_page": 500, "results": [%s]}', query$page, paste(first, collapse = ","))))
    }
    if (grepl("/taxa$", url)) {
      if (query$q == "Other") return(fromJson('{"results": []}'))
      return(fromJson(sprintf('{"results": [{"id": %d, "name": "%s", "rank": "family", "rank_level": 30, "matched_term": "%s"}]}',
                              nchar(query$q), query$q, query$q)))
    }
    if (grepl("/observations$", url)) return(fromJson(sprintf('{"total_results": %d, "results": []}', 10L * as.integer(query$taxon_id))))
    stop("unexpected request: ", url)
  }
  key <- namesKey(c("Lamnidae", "Heterodontus portusjacksoni", "Squatinidae", "Other"))
  expect_message(
    expect_warning(k <- regionalKey(key, 6744, source = "inat", minRecords = 100, fetch = fetch), "does not know 1 of the key's taxa.*Other"),
    "iNaturalist has 55,794 species for the place, so each of the key's 4 taxa is asked about instead \\(give `kingdom`")
  url <- vapply(log, function(x) x$url, "")
  expect_equal(sum(grepl("species_counts$", url)), 1)
  expect_equal(sum(grepl("/taxa$", url)), 3)
  # a name on the first page is counted from it; the others by their own observations in the place
  rec <- attr(k, "records")
  expect_equal(rec$records, c(80, 5223, 110, NA))
  expect_equal(rec$kept, c(FALSE, TRUE, TRUE, TRUE))
  one <- Filter(function(x) grepl("/observations$", x$url), log)
  expect_equal(vapply(one, function(x) x$query$taxon_id, ""), c("8", "11"))
  expect_equal(one[[1]]$query$place_id, "6744")
  expect_equal(one[[1]]$query$quality_grade, "research")
  expect_equal(one[[1]]$query$per_page, 0)
  # a list that is long but shorter than asking is still read through
  log <- list()
  big <- namesKey(paste("Genus", paste0("species", 1:80)))
  suppressWarnings(suppressMessages(try(regionalKey(big, 6744, source = "inat", fetch = fetch), silent = TRUE)))
  expect_gt(sum(grepl("species_counts$", vapply(log, function(x) x$url, ""))), 1)
})
