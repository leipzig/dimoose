test_that("featureTable builds the standard columns", {
  f <- featureTable(id = c("term:a", "text:b"), kind = c("centroid_patch_max", "clip_text_pair"),
    prompt = c(NA, "a photo with b"), negative_prompt = c(NA, "a photo with not b"),
    embedding = list(c(1, 0), NULL))
  expect_equal(names(f), c("id", "kind", "label", "prompt", "negative_prompt", "region", "embedding", "exemplars"))
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
