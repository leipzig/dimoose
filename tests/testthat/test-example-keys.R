keys <- list(
  sharks = sharkKey,
  arachnida = arachnidaKey,
  vibrio = vibrioKey,
  phylotree = function() phylotreeKey("H2a"),
  terms = function() { v <- syntheticVision(k = 3); t <- discoverTerms(v$patches, k = 3); keyFromTerms(termScores(v$patches, t$centroids), v$images, t, quantile = 0.5) }
)

for (name in names(keys)) {
  test_that(paste(name, "is a dimoose key with the common fields and methods"), {
    k <- keys[[name]]()
    expect_s3_class(k, "dimoose")

    expect_true(all(c("Statement", "Choice", "Character", "Next", "Taxon") %in% names(k$leads)))
    expect_true(all(c("Statement", "Choice", "Character", "Taxon", "pSt", "pCh") %in% names(k$df)))
    expect_true(all(c("submitted_name", "matched_name") %in% names(k$taxa)))
    expect_true(is.data.frame(k$meta))
    expect_type(k$desc, "character")

    expect_length(k$validate(), 0)

    s <- summary(k)
    expect_s3_class(s, "data.frame")
    expect_gt(s$couplets, 0)
    expect_gt(s$taxa, 1)
    expect_equal(s$problems, 0)
    expect_output(print(k), "<dimoose key>")

    tree <- k$toDataTree()
    expect_s3_class(tree, "Node")
    expect_equal(tree$leafCount, sum(k$leads$Next == "-"))

    nwk <- k$toNewick()
    expect_match(nwk, ";$")
    expect_equal(lengths(regmatches(nwk, gregexpr("(", nwk, fixed = TRUE))),
                 lengths(regmatches(nwk, gregexpr(")", nwk, fixed = TRUE))))

    html <- exportWizard(k)
    expect_match(html, "<svg class=\"keymap", fixed = TRUE)
    expect_equal(lengths(regmatches(html, gregexpr("class=\"taxon\"", html, fixed = TRUE))), s$taxa)
  })
}

test_that("the example keys have the expected size", {
  expect_equal(summary(sharkKey())[c("couplets", "taxa")], data.frame(couplets = 23L, taxa = 24L))
  expect_equal(summary(arachnidaKey())[c("couplets", "taxa")], data.frame(couplets = 11L, taxa = 11L))
  expect_equal(sum(arachnida$Next == "-"), 12)
  v <- vibrioKey()
  expect_equal(summary(v)$couplets, sum(v$leads$Next != "-") + 1)
})

test_that("vibrioKey reaches every species", {
  v <- vibrioKey()
  reached <- unlist(strsplit(v$leads$Taxon[v$leads$Next == "-"], " / ", fixed = TRUE))
  expect_setequal(reached, vibrio$species)
})

test_that("toNewick quotes labels that need it", {
  leads <- data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("x", "y"),
    Next = c("-", "-"), Taxon = c("L2'3'4", "H2a+152  16311"), stringsAsFactors = FALSE)
  expect_identical(keyFromLeads(leads)$toNewick(), "('L2''3''4','H2a+152  16311')1;")
})

test_that("keyFromLeads and keyFromRpart reject bad input", {
  expect_error(keyFromLeads(data.frame(a = 1)), "missing column")
  expect_error(keyFromRpart(lm(1 ~ 1)), "rpart")
})
