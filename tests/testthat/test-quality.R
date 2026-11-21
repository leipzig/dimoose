qualLeads <- function(statement, nxt, taxon, choice = NULL) {
  if (is.null(choice)) choice <- stats::ave(statement, statement, FUN = function(x) letters[seq_along(x)])
  data.frame(Statement = statement, Choice = choice, Character = paste("lead", seq_along(statement)),
             Next = nxt, Taxon = taxon, stringsAsFactors = FALSE)
}
# A balanced key to four taxa and a comb (one taxon split off at a time)
balanced <- function() keyFromLeads(qualLeads(c("1", "1", "2", "2", "3", "3"), c("2", "3", "-", "-", "-", "-"),
                                              c("", "", "A", "B", "C", "D")))
comb <- function() keyFromLeads(qualLeads(c("1", "1", "2", "2", "3", "3"), c("-", "2", "-", "3", "-", "-"),
                                          c("A", "", "B", "", "C", "D")))

test_that("a balanced key to four taxa is fully efficient", {
  q <- keyQuality(balanced())
  expect_equal(q$taxa$Taxon, c("A", "B", "C", "D"))
  expect_equal(q$taxa$steps, rep(2, 4))
  expect_equal(q$taxa$weight, rep(0.25, 4))
  expect_equal(q$leads$Lead, c("2a", "2b", "3a", "3b"))
  expect_equal(q$meanLeadSteps, 2)
  expect_equal(q$meanTaxonSteps, 2)
  expect_equal(q$expectedSteps, 2)
  expect_equal(q$entropy, 2)
  expect_equal(q$bitsPerStep, 1)
  expect_equal(q$bound, 2)
  expect_equal(q$efficiency, 1)
  expect_equal(q$capacityUsed, 1)
  expect_equal(q$maxLeads, 2L)
  expect_equal(q$depth, 2L)
})

test_that("a comb takes more steps, unless the taxa split off first are the common ones", {
  q <- keyQuality(comb())
  expect_equal(q$taxa$steps, c(1, 2, 3, 3))
  expect_equal(q$expectedSteps, 2.25)
  expect_equal(q$bound, 2)
  expect_equal(q$efficiency, 2 / 2.25)
  expect_equal(q$depth, 3L)

  w <- keyQuality(comb(), c(D = 1, C = 1, B = 2, A = 4))
  expect_equal(w$taxa$weight, c(0.5, 0.25, 0.125, 0.125))
  expect_equal(w$expectedSteps, 1.75)
  expect_equal(w$bound, 1.75)
  expect_equal(w$efficiency, 1)
  expect_equal(w$meanTaxonSteps, 2.25)
  # the same weights make the balanced key the worse one
  b <- keyQuality(balanced(), c(D = 1, C = 1, B = 2, A = 4))
  expect_equal(b$expectedSteps, 2)
  expect_equal(b$efficiency, 1.75 / 2)
})

test_that("a taxon at several terminal leads counts once, by the mean of its leads", {
  # A keys out at 1a (1 step) and at 3a (3 steps)
  k <- keyFromLeads(qualLeads(c("1", "1", "2", "2", "3", "3"), c("-", "2", "-", "3", "-", "-"),
                              c("A", "", "B", "", "A", "C")))
  q <- keyQuality(k)
  expect_equal(q$taxa$Taxon, c("A", "B", "C"))
  expect_equal(q$taxa$leads, c(2L, 1L, 1L))
  expect_equal(q$taxa$steps, c(2, 2, 3))
  expect_equal(q$taxa$minSteps, c(1, 2, 3))
  expect_equal(q$taxa$maxSteps, c(3, 2, 3))
  expect_equal(q$meanLeadSteps, 9 / 4)
  expect_equal(q$meanTaxonSteps, 7 / 3)
  expect_equal(sum(q$taxa$weight), 1)
  # the best key to three equally common taxa: one at 1 step, two at 2
  expect_equal(q$bound, 5 / 3)
  expect_equal(q$entropy, log2(3))
  expect_equal(q$efficiency, (5 / 3) / (7 / 3))
  # the weight of A is not doubled
  w <- keyQuality(k, c(A = 2, B = 1, C = 1))
  expect_equal(w$taxa$weight, c(0.5, 0.25, 0.25))
  expect_equal(w$expectedSteps, 0.5 * 2 + 0.25 * 2 + 0.25 * 3)
})

test_that("a couplet reached from several leads is counted once, by its shortest route", {
  # couplet 4 is reached from 1b (1 step) and from 3b (3 steps)
  k <- keyFromLeads(qualLeads(c("1", "1", "1", "2", "2", "3", "3", "4", "4"),
                              c("2", "4", "-", "-", "3", "-", "4", "-", "-"),
                              c("", "", "A", "B", "", "C", "", "D", "E")))
  expect_length(k$validate(), 0)
  q <- keyQuality(k)
  expect_equal(nrow(q$leads), 5)
  expect_equal(q$taxa$Taxon, c("A", "B", "C", "D", "E"))
  expect_equal(q$taxa$steps, c(1, 2, 3, 2, 2))
  expect_equal(q$taxa$leads, rep(1L, 5))
  expect_equal(q$expectedSteps, 2)
  expect_equal(q$depth, 4L)
  expect_equal(q$maxLeads, 3L)
  # steps come through couplet 1 (3 leads) every time, 2 with chance 2/5,
  # 3 with 1/5 and 4 with 2/5
  expect_equal(q$bitsPerStep, (log2(3) + 1) / 2)
  expect_equal(q$capacityUsed, log2(5) / (log2(3) + 1))
  # the best key with couplets of up to three leads: A, B at 1 step, C, D, E at 2
  expect_equal(q$bound, 1.6)
  expect_equal(q$efficiency, 0.8)
  expect_equal(k$summary()$depth, 4L)
})

test_that("couplets with more than two leads are credited with more than one bit", {
  # one couplet with four leads: every taxon in one step, as good as can be
  one <- keyFromLeads(qualLeads(rep("1", 4), rep("-", 4), c("A", "B", "C", "D")))
  q <- keyQuality(one)
  expect_equal(q$expectedSteps, 1)
  expect_equal(q$entropy, 2)
  expect_equal(q$bitsPerStep, 2)
  expect_equal(q$bound, 1)
  expect_equal(q$efficiency, 1)
  expect_equal(q$capacityUsed, 1)
  # three leads, one of them to a couplet of two
  mixed <- keyFromLeads(qualLeads(c("1", "1", "1", "2", "2"), c("-", "-", "2", "-", "-"), c("A", "B", "", "C", "D")))
  m <- keyQuality(mixed)
  expect_equal(m$expectedSteps, 1.5)
  expect_equal(m$bitsPerStep, (log2(3) + 0.5) / 1.5)
  expect_equal(m$capacityUsed, 2 / (log2(3) + 0.5))
  # four taxa cannot be reached in fewer steps with couplets of three leads
  expect_equal(m$bound, 1.5)
  expect_equal(m$efficiency, 1)
})

test_that("efficiency stays above 0 and at most 1 for the example keys and random weights", {
  set.seed(1)
  for (k in list(montanaKey(), sharkKey(), arachnidaKey(), vibrioKey())) {
    q <- keyQuality(k)
    expect_equal(nrow(q$taxa), k$summary()$taxa)
    expect_equal(q$expectedSteps, q$meanTaxonSteps)
    n <- nrow(q$taxa)
    expect_equal(q$entropy, log2(n))
    # equally common taxa and two-lead couplets: the best key is as balanced as n allows
    expect_equal(q$bound, floor(log2(n)) + 2 * (n - 2^floor(log2(n))) / n)
    expect_gte(q$bound, q$entropy)
    expect_lt(q$bound, q$entropy + 1)
    expect_true(q$efficiency > 0 && q$efficiency <= 1)
    expect_true(q$capacityUsed > 0 && q$capacityUsed <= q$efficiency)
    expect_equal(q$depth, max(q$leads$steps))
    for (i in 1:5) {
      w <- stats::setNames(stats::rexp(nrow(q$taxa))^3, q$taxa$Taxon)
      r <- keyQuality(k, w)
      expect_true(r$efficiency > 0 && r$efficiency <= 1)
      expect_gte(r$expectedSteps, r$bound - 1e-9)
      expect_gte(r$bound, r$entropy - 1e-9)
      expect_lt(r$bound, r$entropy + 1)
      expect_lte(r$capacityUsed, 1)
    }
  }
})

test_that("the steps agree with the path table of a tree-shaped key", {
  k <- arachnidaKey()
  q <- keyQuality(k)
  perLead <- vapply(seq_len(nrow(q$leads)), function(i) {
    length(pathToLead(normalizeLeads(k$leads), which(leadLabels(normalizeLeads(k$leads)) == q$leads$Lead[i]), "1"))
  }, 0L)
  expect_equal(q$leads$steps, as.numeric(perLead))
  terminal <- k$leads$Taxon[k$leads$Next == "-"]
  expect_equal(q$taxa$leads, as.integer(table(terminal)[q$taxa$Taxon]))
  expect_equal(sum(q$taxa$leads == 2), 1)
})

test_that("weights are matched by name and checked", {
  k <- comb()
  expect_warning(q <- keyQuality(k, c(A = 3, B = 1, Z = 9)), "2 of the key's 4 taxa have no weight and count as 0: C, D")
  expect_equal(q$taxa$weight, c(0.75, 0.25, 0, 0))
  expect_equal(q$expectedSteps, 1.25)
  expect_equal(q$entropy, -(0.75 * log2(0.75) + 0.25 * log2(0.25)))
  # C and D are never met but a key still has to place them: A at 1 step, B at 2
  expect_equal(q$bound, 1.25)
  expect_equal(q$efficiency, 1)
  expect_warning(n <- keyQuality(k, c(A = 1, B = NA, C = 1, D = 2)), "B")
  expect_equal(n$taxa$weight, c(0.25, 0, 0.25, 0.5))
  expect_error(keyQuality(k, c(1, 2, 3, 4)), "named by the key's taxa; this one has no names")
  expect_error(keyQuality(k, c(A = "1", B = "2")), "numeric vector")
  expect_error(keyQuality(k, list(A = 1, B = 2)), "numeric vector")
  expect_error(keyQuality(k, c(A = Inf, B = 1, C = 1, D = 1)), "finite")
  # two values for one taxon: which is meant?
  expect_error(keyQuality(k, c(A = 1, A = 5, B = 1, C = 1, D = 1)), "more than one value for A")
  expect_silent(keyQuality(k, c(A = 1, B = 1, C = 1, D = 1, Z = 1, Z = 2)))
  # names with stray spaces, integers and a table all work
  expect_equal(keyQuality(k, c(" A" = 4L, "B " = 2L, C = 1L, D = 1L))$expectedSteps, 1.75)
  expect_equal(keyQuality(k, table(c("A", "A", "A", "A", "B", "B", "C", "D")))$expectedSteps, 1.75)
  expect_error(keyQuality(k, c(X = 1, Y = 2)), "None of the names")
  expect_error(keyQuality(k, c(A = -1, B = 1, C = 1, D = 1)), "not negative")
  expect_error(keyQuality(k, c(A = 0, B = 0, C = 0, D = 0)), "all 0")
  expect_error(keyQuality(k$leads), "dimoose object")
})

test_that("odd keys do not break it", {
  one <- keyFromLeads(qualLeads(c("1", "1"), c("-", "-"), c("A", "A")))
  q <- keyQuality(one)
  expect_equal(q$expectedSteps, 1)
  expect_equal(q$bound, 0)
  expect_true(is.na(q$efficiency))
  lone <- keyQuality(keyFromLeads(qualLeads("1", "-", "A")))
  expect_equal(lone$expectedSteps, 1)
  expect_equal(lone$bound, 0)
  expect_true(is.na(lone$efficiency) && is.na(lone$capacityUsed))

  empty <- keyQuality(dimoose$new(NULL))
  expect_equal(nrow(empty$taxa), 0)
  expect_equal(nrow(empty$leads), 0)
  expect_true(is.na(empty$expectedSteps))
  expect_equal(empty$depth, 0L)

  # a couplet nothing leads to, and a terminal lead with no taxon, are left out
  stray <- keyFromLeads(qualLeads(c("1", "1", "2", "2", "9", "9"), c("2", "-", "-", "-", "-", "-"),
                                  c("", "A", "B", "", "X", "Y")))
  s <- keyQuality(stray)
  expect_equal(s$taxa$Taxon, c("A", "B"))
  expect_equal(s$leads$Lead, c("1b", "2a", "2b"))
  expect_equal(s$meanLeadSteps, 1.5)

  # a cycle: no longest route, so the shortest stands in for it
  loop <- dimoose$new(NULL, leads = qualLeads(c("1", "1", "2", "2"), c("2", "-", "1", "-"), c("", "A", "", "B")))
  l <- keyQuality(loop)
  expect_equal(l$taxa$steps, c(1, 2))
  expect_equal(l$depth, 2L)
})

test_that("eight taxa: a balanced key is as short as a key can be, a caterpillar is not", {
  balanced8 <- keyFromLeads(qualLeads(as.character(rep(1:7, each = 2)), c("2", "3", "4", "5", "6", "7", rep("-", 8)),
                                      c(rep("", 6), LETTERS[1:8])))
  q <- keyQuality(balanced8)
  expect_equal(q$taxa$steps, rep(3, 8))
  expect_equal(q$expectedSteps, 3)
  expect_equal(q$bound, 3)
  expect_equal(q$efficiency, 1)
  expect_equal(q$capacityUsed, 1)

  # one taxon split off at each couplet: 1, 2, ..., 6, 7, 7 steps
  caterpillar <- keyFromLeads(qualLeads(as.character(rep(1:7, each = 2)),
                                        c(rbind("-", as.character(2:7)), "-", "-"),
                                        c(rbind(LETTERS[1:6], ""), "G", "H")))
  q <- keyQuality(caterpillar)
  expect_equal(q$taxa$steps, c(1:7, 7))
  expect_equal(q$expectedSteps, 35 / 8)
  expect_equal(q$bound, 3)
  expect_equal(q$efficiency, 24 / 35)
  expect_equal(q$depth, 7L)
  # it is the best key there is when each taxon is twice as common as the next
  w <- stats::setNames(c(2^(6:0), 1), LETTERS[1:8])
  q <- keyQuality(caterpillar, w)
  expect_equal(q$expectedSteps, sum(w * c(1:7, 7)) / sum(w))
  expect_equal(q$bound, q$expectedSteps)
  expect_equal(q$bound, q$entropy)
  expect_equal(q$efficiency, 1)
})

test_that("the bound is the expected steps of the best key (Huffman), whatever the couplet size", {
  # the textbook example: lengths 2, 2, 2, 3, 3
  expect_equal(qualOptimalSteps(c(0.4, 0.2, 0.2, 0.1, 0.1), 2), 2.2)
  expect_equal(qualOptimalSteps(c(0.1, 0.4, 0.2, 0.1, 0.2), 2), 2.2)
  # couplets of three: five taxa fill the tree, four leave a lead unused
  expect_equal(qualOptimalSteps(rep(0.2, 5), 3), 1.6)
  expect_equal(qualOptimalSteps(rep(0.25, 4), 3), 1.5)
  expect_equal(qualOptimalSteps(c(0.7, 0.1, 0.1, 0.1), 3), 1.2)
  # as many leads as taxa, or more: one step
  expect_equal(qualOptimalSteps(rep(0.25, 4), 4), 1)
  expect_equal(qualOptimalSteps(rep(0.25, 4), 87), 1)
  expect_equal(qualOptimalSteps(1, 2), 0)
  expect_equal(qualOptimalSteps(numeric(), 2), 0)
  # a taxon that is never met still has to be in the key
  expect_equal(qualOptimalSteps(c(1, 0), 2), 1)
  expect_equal(qualOptimalSteps(c(0.5, 0.5, 0, 0), 2), 1.5)
  # equally common taxa, two-lead couplets: as balanced as n allows
  for (n in c(2, 3, 7, 8, 11, 100, 1000)) {
    expect_equal(qualOptimalSteps(rep(1 / n, n), 2), floor(log2(n)) + 2 * (n - 2^floor(log2(n))) / n)
  }
  # never below the entropy in units of the largest couplet, and less than a step above it
  set.seed(2)
  for (arity in c(2, 3, 5)) {
    p <- stats::rexp(40)
    p <- p / sum(p)
    h <- -sum(p * log(p, arity))
    expect_gte(qualOptimalSteps(p, arity), h)
    expect_lt(qualOptimalSteps(p, arity), h + 1)
  }
})

test_that("a taxon with all the weight still needs a step, and one three-lead couplet is the best there is", {
  three <- keyFromLeads(qualLeads(c("1", "1", "1"), rep("-", 3), c("A", "B", "C")))
  q <- keyQuality(three, c(A = 1, B = 0, C = 0))
  expect_equal(q$entropy, 0)
  expect_equal(q$bound, 1)
  expect_equal(q$efficiency, 1)
  # the largest couplet that counts is one that can be reached
  stray <- keyFromLeads(qualLeads(c("1", "1", "2", "2", "9", "9", "9"), c("2", "-", "-", "-", "-", "-", "-"),
                                  c("", "A", "B", "C", "X", "Y", "Z")))
  expect_equal(keyQuality(stray)$maxLeads, 2L)
  expect_equal(keyQuality(stray)$bound, 5 / 3)
})

test_that("a PhyloTree key, with couplets of many sizes, is measured quickly", {
  k <- phylotreeKey("H2a")
  q <- keyQuality(k)
  expect_equal(q$maxLeads, max(table(k$leads$Statement)))
  expect_equal(q$bound, qualOptimalSteps(q$taxa$weight, q$maxLeads))
  expect_gte(q$expectedSteps, q$bound)
  expect_true(q$efficiency > 0 && q$efficiency < 1)
  expect_true(q$capacityUsed > q$efficiency && q$capacityUsed <= 1)
  expect_gt(q$bitsPerStep, 1)
})

# ---- occurrenceWeights -------------------------------------------------------

# A stand-in for GBIF: `species` maps a name to its match, `counts` a taxon
# key to its number of records. Calls are recorded in `calls`.
fakeGbif <- function(species, counts) {
  calls <- list()
  fetch <- function(url, query) {
    calls[[length(calls) + 1]] <<- list(url = url, query = query)
    if (grepl("species/match$", url)) {
      hit <- species[[query$name]]
      if (is.null(hit)) list(matchType = "NONE") else hit
    } else if (grepl("occurrence/search$", url)) {
      list(offset = 0, limit = 0, endOfRecords = FALSE, count = counts[[as.character(query$taxonKey)]], results = list())
    } else {
      stop("unexpected URL ", url)
    }
  }
  list(fetch = fetch, calls = function() calls)
}
treeLeads <- function() {
  qualLeads(c("1", "1", "2", "2", "3", "3"), c("-", "2", "-", "3", "-", "-"),
            c("Box elder (Acer negundo)", "", "Green ash (Fraxinus pennsylvanica)", "", "Quercus macrocarpa", "unidentified willows"))
}
treeSpecies <- list(
  "Acer negundo" = list(usageKey = 3189866, matchType = "EXACT", status = "ACCEPTED"),
  "Fraxinus pennsylvanica" = list(usageKey = 111, acceptedUsageKey = 3172338, matchType = "EXACT", status = "SYNONYM"),
  "Quercus macrocarpa" = list(usageKey = 2878130, matchType = "FUZZY", status = "ACCEPTED")
)
treeCounts <- list("3189866" = 600, "3172338" = 300, "2878130" = 100)

test_that("occurrenceWeights counts each taxon by its scientific name", {
  gbif <- fakeGbif(treeSpecies, treeCounts)
  expect_warning(w <- occurrenceWeights(keyFromLeads(treeLeads()), fetch = gbif$fetch),
                 "1 result without a scientific name not counted: unidentified willows")
  expect_equal(w, c("Box elder (Acer negundo)" = 600, "Green ash (Fraxinus pennsylvanica)" = 300,
                    "Quercus macrocarpa" = 100, "unidentified willows" = NA))
  calls <- gbif$calls()
  expect_length(calls, 6)
  expect_equal(calls[[1]], list(url = "https://api.gbif.org/v1/species/match", query = list(name = "Acer negundo")))
  expect_equal(calls[[2]], list(url = "https://api.gbif.org/v1/occurrence/search",
                                query = list(taxonKey = 3189866, limit = 0)))
  # a synonym is counted by the name GBIF accepts
  expect_equal(calls[[4]]$query$taxonKey, 3172338)
})

test_that("the counts work as weights", {
  gbif <- fakeGbif(treeSpecies, treeCounts)
  k <- keyFromLeads(treeLeads())
  w <- suppressWarnings(occurrenceWeights(k, fetch = gbif$fetch))
  expect_warning(q <- keyQuality(k, w), "unidentified willows")
  expect_equal(q$taxa$weight, c(0.6, 0.3, 0.1, 0))
  expect_equal(q$expectedSteps, 0.6 + 0.6 + 0.3)
  expect_equal(suppressWarnings(summary(k, weights = w))$expectedSteps, 1.5)
})

test_that("region is sent as a country code or a GADM id, and kingdom with the name", {
  k <- keyFromLeads(treeLeads()[c(1, 3), ] |> transform(Statement = "1", Choice = c("a", "b"), Next = "-"))
  query <- function(...) {
    gbif <- fakeGbif(treeSpecies, treeCounts)
    occurrenceWeights(k, fetch = gbif$fetch, ...)
    gbif$calls()
  }
  expect_equal(query(region = "us")[[2]]$query, list(taxonKey = 3189866, limit = 0, country = "US"))
  expect_equal(query(region = "USA.27_1")[[2]]$query, list(taxonKey = 3189866, limit = 0, gadmGid = "USA.27_1"))
  expect_equal(query(region = "USA")[[2]]$query$gadmGid, "USA")
  # GBIF answers 0 for a GADM id in lower case, so it is sent in capitals
  expect_equal(query(region = " usa.27_1 ")[[2]]$query$gadmGid, "USA.27_1")
  expect_equal(query(region = "USA.27.1_1")[[2]]$query$gadmGid, "USA.27.1_1")
  expect_error(occurrenceWeights(k, region = "Montana", fetch = identity), "two-letter country code .* or a GADM id .*, not MONTANA")
  expect_error(occurrenceWeights(k, region = "USA-MT", fetch = identity), "GADM id")
  expect_equal(query(kingdom = "Plantae")[[1]]$query, list(name = "Acer negundo", kingdom = "Plantae"))
  expect_error(occurrenceWeights(k, region = c("US", "CA"), fetch = identity), "one country code or GADM id")
  expect_error(occurrenceWeights(k, region = "", fetch = identity), "one country code or GADM id")
  expect_error(occurrenceWeights(k, source = "inaturalist"), "should be")
  expect_error(occurrenceWeights(k, fetch = "gbif"), "must be a function")
  expect_error(occurrenceWeights(k$leads), "dimoose object")
})

test_that("names GBIF does not know, or knows only by genus, and failed requests give NA", {
  species <- c(treeSpecies, list("Acer imaginarium" = list(usageKey = 3189834, matchType = "HIGHERRANK", canonicalName = "Acer")))
  leads <- qualLeads(c("1", "1", "1"), c("-", "-", "-"),
                     c("Box elder (Acer negundo)", "Dream maple (Acer imaginarium)", "Nothing (Nullus nullus)"))
  gbif <- fakeGbif(species, treeCounts)
  expect_warning(w <- occurrenceWeights(keyFromLeads(leads), fetch = gbif$fetch),
                 "Not in GBIF, so not counted: Acer imaginarium, Nullus nullus")
  expect_equal(unname(w), c(600, NA, NA))
  expect_length(gbif$calls(), 4)

  down <- function(url, query) if (grepl("occurrence", url)) stop("GBIF is down") else treeSpecies[[query$name]]
  two <- keyFromLeads(qualLeads(c("1", "1"), c("-", "-"), c("Box elder (Acer negundo)", "Quercus macrocarpa")))
  expect_warning(w <- occurrenceWeights(two, fetch = down),
                 "Could not get the count of 2 names from GBIF: GBIF is down")
  expect_true(all(is.na(w)))
  expect_named(w, two$leads$Taxon)
})

test_that("a region where no taxon has a record is questioned", {
  k <- keyFromLeads(treeLeads()[c(1, 3), ] |> transform(Statement = "1", Choice = c("a", "b"), Next = "-"))
  nowhere <- fakeGbif(treeSpecies, list("3189866" = 0, "3172338" = 0))
  expect_warning(w <- occurrenceWeights(k, region = "USA.99_9", fetch = nowhere$fetch),
                 "GBIF has no records of these taxa in USA.99_9; check")
  expect_equal(unname(w), c(0, 0))
  expect_silent(occurrenceWeights(k, fetch = nowhere$fetch))
  some <- fakeGbif(treeSpecies, list("3189866" = 0, "3172338" = 4))
  expect_silent(occurrenceWeights(k, region = "USA.27_1", fetch = some$fetch))
})

test_that("a genus that GBIF reports as a higher-rank match of itself is counted", {
  # GBIF's answers for "Acer" and "Populus sp." (2026-11): matchType HIGHERRANK, the genus itself
  species <- list(
    Acer = list(usageKey = 3189834, canonicalName = "Acer", rank = "GENUS", matchType = "HIGHERRANK"),
    Populus = list(usageKey = 3040183, canonicalName = "Populus", rank = "GENUS", matchType = "EXACT"),
    Salix = list(usageKey = 3039576, canonicalName = "Salix", rank = "GENUS", matchType = "EXACT"),
    "Acer imaginarium" = list(usageKey = 3189834, canonicalName = "Acer", rank = "GENUS", matchType = "HIGHERRANK")
  )
  gbif <- fakeGbif(species, list("3189834" = 5, "3040183" = 6, "3039576" = 7))
  k <- keyFromLeads(qualLeads(rep("1", 5), rep("-", 5),
                              c("Acer", "Populus sp.", "Willows (Salix spp.)", "Salix spp", "Acer imaginarium")))
  expect_warning(w <- occurrenceWeights(k, fetch = gbif$fetch), "Not in GBIF, so not counted: Acer imaginarium$")
  expect_equal(unname(w), c(5, 6, 7, 7, NA))
  # "sp." and "spp." are not sent, and a name is asked about once
  asked <- vapply(gbif$calls(), function(x) if (is.null(x$query$name)) NA_character_ else x$query$name, "")
  expect_equal(asked[!is.na(asked)], c("Acer", "Populus", "Salix", "Acer imaginarium"))
})

test_that("an author in parentheses is not taken for the name", {
  expect_equal(qualLookupName(c("Puma concolor (Linnaeus, 1771)", "Cougar (Puma concolor)", "Felis concolor",
                                "Abies (Mill.)", "unidentified willows", "Salix sp.", "Oak (Quercus)", "")),
               c("Puma concolor", "Puma concolor", "Felis concolor", "Abies", NA, "Salix", "Quercus", NA))
})

test_that("a result that lists several taxa gets the sum of their counts", {
  gbif <- fakeGbif(treeSpecies, treeCounts)
  k <- keyFromLeads(qualLeads(rep("1", 4), rep("-", 4),
                              c("Acer negundo / Quercus macrocarpa", "Fraxinus pennsylvanica",
                                "Acer negundo / unidentified willows", "Acer negundo / Nullus nullus")))
  w <- suppressWarnings(occurrenceWeights(k, fetch = gbif$fetch))
  expect_equal(unname(w), c(700, 300, NA, NA))
  expect_warning(expect_warning(occurrenceWeights(k, fetch = gbif$fetch),
                                "1 result without a scientific name not counted: Acer negundo / unidentified willows"),
                 "Not in GBIF, so not counted: Nullus nullus")
})

test_that("a name in more than one kingdom is reported as such", {
  morus <- function(url, query) {
    if (grepl("occurrence", url)) return(list(count = 9))
    if (is.null(query$kingdom)) list(matchType = "NONE", note = "Multiple equal matches for Morus", synonym = FALSE)
    else list(usageKey = 1, canonicalName = "Morus", matchType = "EXACT")
  }
  k <- keyFromLeads(qualLeads(c("1", "1"), c("-", "-"), c("Morus", "Mulberries (Morus)")))
  expect_warning(w <- occurrenceWeights(k, fetch = morus), "more than one taxon by this name.*`kingdom`.*: Morus$")
  expect_true(all(is.na(w)))
  expect_equal(unname(occurrenceWeights(k, fetch = morus, kingdom = "Plantae")), c(9, 9))
})

test_that("GBIF is not asked again and again when it does not answer", {
  asked <- 0
  down <- function(url, query) {
    asked <<- asked + 1
    stop("Could not resolve host")
  }
  taxa <- paste("Acer", c("negundo", "glabrum", "rubrum", "saccharum", "platanoides", "campestre"))
  k <- keyFromLeads(qualLeads(rep("1", 6), rep("-", 6), taxa))
  expect_warning(w <- occurrenceWeights(k, fetch = down),
                 "Could not get the count of 6 names from GBIF: Could not resolve host; gave up after 3 failed requests in a row")
  expect_equal(asked, 3)
  expect_equal(w, stats::setNames(rep(NA_real_, 6), taxa))
  # failures that are not in a row do not stop it
  asked <- 0
  flaky <- function(url, query) {
    asked <<- asked + 1
    if (grepl("rubrum|glabrum|campestre", query$name %||% "")) stop("timeout")
    if (grepl("match", url)) list(usageKey = 1, matchType = "EXACT") else list(count = 2)
  }
  expect_warning(w <- occurrenceWeights(k, fetch = flaky), "Could not get the count of 3 names from GBIF: timeout$")
  expect_equal(unname(w), c(2, NA, NA, 2, 2, NA))
})

test_that("families and genera are counted too", {
  gbif <- fakeGbif(list(Squatinidae = list(usageKey = 7, matchType = "EXACT"), Acer = list(usageKey = 8, matchType = "EXACT")),
                   list("7" = 12, "8" = 34))
  k <- keyFromLeads(qualLeads(c("1", "1"), c("-", "-"), c("Squatinidae", "Acer")))
  expect_equal(occurrenceWeights(k, fetch = gbif$fetch), c(Squatinidae = 12, Acer = 34))
})

test_that("occurrenceWeights gets counts from GBIF", {
  skip_on_cran()
  skip_if_offline()
  skip_if_unreachable("https://api.gbif.org/v1/species/match?name=Acer")
  k <- keyFromLeads(qualLeads(c("1", "1"), c("-", "-"), c("Box elder (Acer negundo)", "Quaking aspen (Populus tremuloides)")))
  world <- occurrenceWeights(k, kingdom = "Plantae")
  expect_named(world, k$leads$Taxon)
  expect_true(all(world > 1000))
  montana <- occurrenceWeights(k, region = "USA.27_1", kingdom = "Plantae")
  usa <- occurrenceWeights(k, region = "US", kingdom = "Plantae")
  expect_true(all(montana > 0 & montana < usa & usa < world))
  expect_equal(keyQuality(k, montana)$expectedSteps, 1)
})

test_that("occurrenceWeights counts genera, synonyms and names with authors at GBIF", {
  skip_on_cran()
  skip_if_offline()
  skip_if_unreachable("https://api.gbif.org/v1/species/match?name=Acer")
  taxa <- c("Acer", "Populus sp.", "Black cottonwood (Populus trichocarpa)", "Populus balsamifera subsp. trichocarpa",
            "Puma concolor (Linnaeus, 1771)", "Felis concolor", "Nullus nullus")
  k <- keyFromLeads(qualLeads(rep("1", length(taxa)), rep("-", length(taxa)), taxa))
  expect_warning(w <- occurrenceWeights(k, region = "us"), "Not in GBIF, so not counted: Nullus nullus$")
  expect_named(w, taxa)
  expect_true(all(w[1:6] > 1000))
  expect_true(is.na(w[[7]]))
  # the genus has more records than its species; synonyms are counted under the accepted name
  expect_gt(w[["Populus sp."]], w[["Black cottonwood (Populus trichocarpa)"]])
  expect_equal(w[["Puma concolor (Linnaeus, 1771)"]], w[["Felis concolor"]])
})
