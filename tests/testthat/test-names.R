# GBIF's answers for the names in these tests, as /v1/species/match gives them
fakeGbif <- function(name, kingdom = NULL) {
  switch(name,
    "Populus tremuloides" = list(matchType = "EXACT", status = "ACCEPTED", canonicalName = "Populus tremuloides"),
    "Fraxinus pensylvanica" = list(matchType = "FUZZY", status = "ACCEPTED", canonicalName = "Fraxinus pennsylvanica"),
    "Ulmus fulva" = list(matchType = "EXACT", status = "SYNONYM", canonicalName = "Ulmus fulva", acceptedUsageKey = 5361867),
    "Acer negundo" = list(matchType = "EXACT", status = "ACCEPTED", canonicalName = "Acer negundo"),
    "Xyzzy plugh" = list(matchType = "NONE"),
    "Populus nonesuch" = list(matchType = "HIGHERRANK", status = "ACCEPTED", canonicalName = "Populus"),
    stop("unexpected name ", name))
}
fakeAccepted <- function(key) c("5361867" = "Ulmus rubra")[[as.character(key)]]

namesKey <- function(taxa) {
  n <- length(taxa)
  leads <- data.frame(Statement = as.character(rep(seq_len(n - 1), each = 2)), Choice = rep(c("a", "b"), n - 1),
                      Character = paste("lead", seq_len(2 * (n - 1))), stringsAsFactors = FALSE)
  leads$Next <- "-"; leads$Taxon <- ""
  a <- seq(1, 2 * (n - 1), 2); b <- a + 1
  leads$Next[b[-length(b)]] <- as.character(seq_len(n - 1)[-1])
  leads$Taxon[a] <- taxa[-n]; leads$Taxon[b[length(b)]] <- taxa[n]
  keyFromLeads(leads)
}

test_that("checkNames reports misspellings, synonyms and unknown names", {
  local_mocked_bindings(gbifMatch = fakeGbif, gbifAccepted = fakeAccepted)
  k <- namesKey(c("Quaking aspen (Populus tremuloides)", "Green ash (Fraxinus pensylvanica)",
                  "Slippery elm (Ulmus fulva)", "Xyzzy plugh", "Populus nonesuch", "box elder"))
  out <- checkNames(k)
  expect_equal(out$name, c("Populus tremuloides", "Fraxinus pensylvanica", "Ulmus fulva", "Xyzzy plugh", "Populus nonesuch"))
  expect_equal(out$status, c("ok", "misspelled", "synonym", "not found", "not found"))
  expect_equal(out$gbif, c("Populus tremuloides", "Fraxinus pennsylvanica", "Ulmus fulva", NA, NA))
  expect_equal(out$accepted, c("Populus tremuloides", "Fraxinus pennsylvanica", "Ulmus rubra", NA, NA))
  expect_equal(out$Taxon[3], "Slippery elm (Ulmus fulva)")
  expect_match(out$note[2], "did you mean Fraxinus pennsylvanica", fixed = TRUE)
  expect_match(out$note[3], "GBIF accepts Ulmus rubra", fixed = TRUE)
})

test_that("checkNames passes the kingdom to GBIF", {
  seen <- NULL
  local_mocked_bindings(gbifMatch = function(name, kingdom = NULL) { seen <<- kingdom; fakeGbif(name) })
  checkNames(namesKey(c("Acer negundo", "Populus tremuloides")), kingdom = "Plantae")
  expect_equal(seen, "Plantae")
})

test_that("checkNames warns and marks names unchecked when GBIF cannot be reached", {
  local_mocked_bindings(gbifMatch = function(name, kingdom = NULL) stop("Timeout was reached"))
  expect_warning(out <- checkNames(namesKey(c("Acer negundo", "Populus tremuloides"))), "Could not check 2 names with GBIF")
  expect_equal(out$status, c("unchecked", "unchecked"))
})

test_that("keyFromSpreadsheet(checkNames = TRUE) warns by spreadsheet row", {
  local_mocked_bindings(gbifMatch = fakeGbif, gbifAccepted = fakeAccepted)
  lines <- c("Couplet,Description,Goes to,Species",
             "1,Leaves compound.,2,", "1,Leaves simple.,,Quaking aspen (Populus tremuloides)",
             "2,Leaflets 3.,,Slippery elm (Ulmus fulva)", "2,Leaflets 5.,,Green ash (Fraxinus pensylvanica)")
  f <- file.path(withr::local_tempdir(), "key.csv")
  writeLines(lines, f)
  w <- character()
  k <- withCallingHandlers(keyFromSpreadsheet(f, checkNames = TRUE),
                           warning = function(e) { w <<- c(w, conditionMessage(e)); invokeRestart("muffleWarning") })
  expect_s3_class(k, "dimoose")
  expect_length(w, 1)
  expect_match(w, "Row 4: Ulmus fulva is a synonym; GBIF accepts Ulmus rubra", fixed = TRUE)
  expect_match(w, "Row 5: Fraxinus pensylvanica is not in GBIF; did you mean Fraxinus pennsylvanica?", fixed = TRUE)
  expect_silent(keyFromSpreadsheet(f))
})

test_that("checkNames works against the real GBIF", {
  skip_on_cran()
  skip_if_unreachable("https://api.gbif.org/v1/species/match?name=Acer")
  out <- checkNames(namesKey(c("Green ash (Fraxinus pensylvanica)", "Slippery elm (Ulmus fulva)")), kingdom = "Plantae")
  expect_equal(out$status, c("misspelled", "synonym"))
  expect_equal(out$accepted, c("Fraxinus pennsylvanica", "Ulmus rubra"))
})

test_that("the Montana key's names are all accepted by GBIF", {
  skip_on_cran()
  skip_if_unreachable("https://api.gbif.org/v1/species/match?name=Acer")
  out <- checkNames(montanaKey(), kingdom = "Plantae")
  expect_equal(out$status, rep("ok", nrow(out)), label = paste(out$note[out$status != "ok"], collapse = "; "))
})

test_that("suggestSpecies ranks only the key's species, by their scientific names", {
  fv <- fakeVisionModel()
  k <- namesKey(c("Quaking aspen (Populus tremuloides)", "Box elder (Acer negundo)", "Mystery tree"))
  out <- suggestSpecies(k, fv$model, c("/pics/L1.png", "/pics/L2.png"), top = 2)
  expect_equal(fv$calls$embed_texts[[1]], c("a photo of Populus tremuloides.", "a photo of Acer negundo.", "a photo of Mystery tree."))
  expect_named(out, c("image", "rank", "Taxon", "probability", "similarity"))
  expect_equal(out$image, c("L1", "L1", "L2", "L2"))
  expect_equal(out$rank, c(1L, 2L, 1L, 2L))
  expect_true(all(out$Taxon %in% k$leads$Taxon))
  # probabilities are a softmax over all three species, so the top two sum to less than 1
  expect_true(all(tapply(out$probability, out$image, sum) <= 1 + 1e-9))
  expect_true(all(diff(out$probability[1:2]) <= 0))

  emb <- fv$model$mod$embed_images(NULL, list("/pics/L1.png"), patches = FALSE)$image
  txt <- fv$model$mod$embed_texts(NULL, list("a photo of Populus tremuloides.", "a photo of Acer negundo.", "a photo of Mystery tree."))
  sim <- drop(txt %*% emb[1, ])
  expect_equal(out$similarity[1], max(sim))
  expect_equal(out$probability[1], max(exp(100 * sim) / sum(exp(100 * sim))))
})

test_that("suggestSpecies takes its own prompt and needs a key with results", {
  fv <- fakeVisionModel()
  k <- namesKey(c("Quaking aspen (Populus tremuloides)", "Box elder (Acer negundo)"))
  suggestSpecies(k, fv$model, "/pics/L1.png", prompt = "%s")
  expect_equal(fv$calls$embed_texts[[1]], c("Populus tremuloides", "Acer negundo"))
  expect_error(suggestSpecies(k, fv$model, "/pics/L1.png", prompt = "no placeholder"), "%s")
})
