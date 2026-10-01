test_that("phylotree17 is a consistent tree in preorder", {
  expect_equal(nrow(phylotree17), 5435)
  expect_identical(phylotree17$haplogroup[1], "mtMRCA")
  expect_true(is.na(phylotree17$parent[1]))
  expect_false(anyDuplicated(phylotree17$haplogroup) > 0)
  pos <- match(phylotree17$parent, phylotree17$haplogroup)
  expect_true(all(pos[-1] < seq_len(nrow(phylotree17))[-1]))
  expect_identical(phylotree17$depth[-1], phylotree17$depth[pos[-1]] + 1L)
  kids <- as.integer(table(factor(phylotree17$parent, levels = phylotree17$haplogroup)))
  expect_identical(phylotree17$n_subclades, kids)
  expect_setequal(phylotree17$haplogroup[phylotree17$parent %in% "mtMRCA"], c("L0", "L1'2'3'4'5'6"))
})

test_that("the mutation table rebuilds the mutation strings", {
  rebuilt <- vapply(split(phylotree17_mutations$notation,
    factor(phylotree17_mutations$haplogroup, levels = phylotree17$haplogroup)), paste, "", collapse = " ")
  expect_identical(unname(rebuilt), phylotree17$mutations)
  expect_equal(nrow(phylotree17_mutations), 13384)
  subs <- phylotree17_mutations$type %in% c("transition", "transversion", "back-mutation") &
    !grepl(".", phylotree17_mutations$notation, fixed = TRUE)
  expect_false(any(phylotree17_mutations$ancestral[subs] == phylotree17_mutations$derived[subs]))
})

test_that("known haplogroups are as in PhyloTree Build 17", {
  hg <- function(x) phylotree17[phylotree17$haplogroup == x, ]
  expect_identical(hg("H2a2a1")$mutations, "263A")
  expect_identical(hg("H2a2a1")$parent, "H2a2a")
  expect_identical(hg("J1c")$mutations, "185A 228A 14798C")
  mu <- phylotree17_mutations
  back <- mu[mu$haplogroup %in% c("L5b", "L5b1a") & mu$position == 182, ]
  expect_identical(back$derived, c("C", "T"))
  expect_true(all(back$type == "back-mutation"))
  expect_true(any(Encoding(phylotree17$haplogroup) == "UTF-8"))
  expect_true("M4’’67" %in% phylotree17$haplogroup)
})

test_that("phylotreeKey builds a key from any subtree", {
  k <- phylotreeKey("H2a2a")
  expect_s3_class(k, "moose")
  leads <- k$leads
  expect_identical(unique(leads$Statement), c("H2a2a", "H2a2a1"))
  expect_identical(leads$Label[leads$Statement == "H2a2a"], c("H2a2a1", "H2a2a2", "H2a2a*"))
  expect_identical(leads$Next[leads$Label == "H2a2a1"], "H2a2a1")
  expect_identical(leads$Character[leads$Label == "H2a2a1"], "263A")
  expect_setequal(leads$Taxon[leads$Next == "-"], c("H2a2a2", "H2a2a*", "H2a2a1*", paste0("H2a2a1", letters[1:8])))

  plain <- phylotreeKey("H2a2a", paragroups = FALSE)
  expect_false(any(grepl("*", plain$leads$Taxon, fixed = TRUE)))

  shallow <- phylotreeKey(maxDepth = 2)
  expect_setequal(unique(shallow$leads$Statement), c("mtMRCA", "L0", "L1'2'3'4'5'6"))

  expect_error(phylotreeKey("not-a-haplogroup"), "haplogroup")
  expect_error(phylotreeKey("H2a2a1a"), "no subclades")
})

test_that("haplogroup keys export with haplogroup headings and unique ids", {
  html <- exportWizard(phylotreeKey("H2a2a"))
  expect_match(html, ">Haplogroup <span class=\"num\">H2a2a1</span>", fixed = TRUE)
  expect_match(html, ">H2a2a1*</h2>", fixed = TRUE)
  ids <- regmatches(html, gregexpr("<section class=\"(couplet|taxon)\" id=\"[^\"]+\"", html))[[1]]
  expect_false(anyDuplicated(ids) > 0)
})

test_that("names that sanitize to the same id get distinct sections", {
  leads <- data.frame(
    Statement = c("R", "R", "M4'67", "M4'67", "M4\"67", "M4\"67"),
    Choice = c("1", "2", "1", "2", "1", "2"),
    Character = c("x", "y", "p", "q", "m", "n"),
    Next = c("M4'67", "M4\"67", "-", "-", "-", "-"),
    Taxon = c("", "", "A", "B", "C", "D"),
    stringsAsFactors = FALSE
  )
  df <- data.frame(Statement = "R", Choice = "1", Character = "x", Taxon = "A", pSt = "", pCh = "", stringsAsFactors = FALSE)
  html <- exportWizard(moose$new(df, "Collision test", leads = leads))
  ids <- sub(".*id=\"([^\"]+)\"", "\\1", regmatches(html, gregexpr("<section class=\"couplet\" id=\"[^\"]+\"", html))[[1]])
  expect_length(ids, 3)
  expect_false(anyDuplicated(ids) > 0)
  hrefs <- sub(".*href=\"#([^\"]+)\"", "\\1", regmatches(html, gregexpr("class=\"choose\" href=\"#c-[^\"]+\"", html))[[1]])
  expect_setequal(hrefs, ids[-1])
})

test_that("non-ASCII names survive export in any locale", {
  f <- withr::local_tempfile(fileext = ".html")
  exportWizard(phylotreeKey("M4’’67"), f)
  html <- rawToChar(readBin(f, "raw", file.size(f)))
  Encoding(html) <- "UTF-8"
  expect_true(grepl("M4’’67*", html, fixed = TRUE))
  expect_false(grepl("<U+2019>", html, fixed = TRUE))
})
