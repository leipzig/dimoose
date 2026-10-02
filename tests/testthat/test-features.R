test_that("featureTable builds the standard columns", {
  f <- featureTable(id = c("term:a", "text:b"), kind = c("centroid_patch_max", "clip_text_pair"),
    prompt = c(NA, "a photo with b"), negative_prompt = c(NA, "a photo with not b"),
    embedding = list(c(1, 0), NULL))
  expect_equal(names(f), c("id", "kind", "label", "prompt", "negative_prompt", "region", "definition", "embedding", "exemplars"))
  expect_equal(f$label, c("term:a", "text:b"))
  expect_equal(f$embedding[[1]], c(1, 0))
  expect_null(f$exemplars[[2]])
})

test_that("keyFromLeads keeps features and validate checks them", {
  leads <- data.frame(
    Statement = c("1", "1"), Choice = c("a", "b"), Character = c("Has x", "Lacks x"),
    Next = c("-", "-"), Taxon = c("A", "B"),
    Feature = c("term:x", "term:x"), Test = c(">", "<="), Threshold = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )
  f <- featureTable("term:x", "centroid_patch_max", embedding = list(c(1, 0)))
  k <- keyFromLeads(leads, "t", features = f)
  expect_s3_class(k$features, "data.frame")
  expect_length(k$validate(), 0)
  expect_type(k$leads$Threshold, "double")

  bad <- leads
  bad$Feature[2] <- "term:y"
  expect_match(keyFromLeads(bad, "t", features = f)$validate(), "term:y", all = FALSE)
  badTest <- leads
  badTest$Test <- c(">", ">")
  expect_match(keyFromLeads(badTest, "t", features = f)$validate(), "opposite", all = FALSE)
  expect_match(keyFromLeads(leads, "t")$validate(), "no features table", all = FALSE)
})

test_that("keys without features validate as before", {
  expect_length(arachnidaKey()$validate(), 0)
  expect_null(arachnidaKey()$features)
})

termFixture <- function() {
  v <- syntheticVision(k = 4)
  t <- discoverTerms(v$patches, k = 4)
  s <- termScores(v$patches, t$centroids)
  list(v = v, t = t, s = s, key = keyFromTerms(s, v$images, t, quantile = 0.5))
}

test_that("classify walks every image to a result and records the path", {
  f <- termFixture()
  r <- classify(f$key, f$s)
  expect_equal(names(r), c("id", "result", "path"))
  expect_equal(r$id, rownames(f$s))
  expect_true(all(r$result %in% f$key$leads$Taxon))
  expect_match(r$path[1], "^1[ab]( [0-9]+[ab])*$")
})

test_that("unresolvable couplet gives NA", {
  f <- termFixture()
  s <- f$s
  s[1, ] <- NA
  r <- classify(f$key, s)
  expect_true(is.na(r$result[1]))
  expect_equal(r$path[1], "")
  bad <- f$key$clone()
  l <- bad$leads; l$Test <- ">"; bad$leads <- l
  expect_true(all(is.na(classify(bad, f$s)$result)))
})

test_that("classify needs every feature column", {
  f <- termFixture()
  expect_error(classify(f$key, f$s[, 1:2]), "missing scores")
})

test_that("evaluateKey reports accuracy and groups", {
  f <- termFixture()
  e <- evaluateKey(f$key, f$s, f$v$images$label, groups = c(L1 = "g1", L2 = "g1", L3 = "g2", L4 = "g2", L5 = "g3", L6 = "g3"))
  expect_equal(e$accuracy, 1)
  expect_equal(e$groupAccuracy, 1)
  expect_s3_class(e$confusion, "table")
  expect_equal(nrow(e$results), 6)
})

test_that("looKey rebuilds without the held-out image", {
  f <- termFixture()
  calls <- 0
  e <- looKey(f$v$images,
    build = function(train) { calls <<- calls + 1; keyFromTerms(f$s[train, , drop = FALSE], f$v$images[train, ], f$t, quantile = 0.5) },
    score = function(key, test) f$s[test, , drop = FALSE])
  expect_equal(calls, 6)
  expect_true(e$accuracy >= 0 && e$accuracy <= 1)
  expect_equal(nrow(e$results), 6)
})

test_that("featureScores computes term and text features from embeddings", {
  f <- termFixture()
  s <- featureScores(f$key, patches = f$v$patches)
  expect_equal(colnames(s), f$key$features$id)
  expect_equal(unname(s[, 1]), unname(f$s[, sub("^sniglet:", "", f$key$features$id[1])]))

  textFeat <- featureTable("text:q", "clip_text_pair", prompt = "a thing with q", negative_prompt = "a thing with not q")
  leads <- data.frame(Statement = "1", Choice = c("a", "b"), Character = c("Has q", "Lacks q"), Next = "-",
    Taxon = c("A", "B"), Feature = "text:q", Test = c(">", "<="), Threshold = 0, stringsAsFactors = FALSE)
  k <- keyFromLeads(leads, "t", features = textFeat)
  img <- rbind(x = c(1, 0), y = c(0, 1))
  txt <- rbind(c(1, 0), c(0, 1)); rownames(txt) <- c("a thing with q", "a thing with not q")
  s2 <- featureScores(k, image = img, textEmb = txt)
  expect_equal(unname(s2[, "text:q"]), c(1, -1))
  expect_equal(classify(k, s2)$result, c("A", "B"))
  expect_error(featureScores(k, image = img), "textEmb")
  expect_error(featureScores(f$key, image = img), "patches")
})

test_that("validate flags a couplet whose two leads test different features", {
  leads <- data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("Has x", "Lacks y"),
    Next = c("-", "-"), Taxon = c("A", "B"), Feature = c("term:x", "term:y"),
    Test = c(">", "<="), Threshold = c(0.5, 0.5), stringsAsFactors = FALSE)
  f <- featureTable(c("term:x", "term:y"), "centroid_patch_max", embedding = list(c(1, 0), c(0, 1)))
  expect_match(keyFromLeads(leads, "t", features = f)$validate(), "different features", all = FALSE)
})
