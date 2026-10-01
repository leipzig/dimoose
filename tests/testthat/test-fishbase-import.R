# Live tests against FishBase. Skipped on CRAN and when offline.

test_that("importFishbase downloads and parses the shark key (keycode 1)", {
  skip_on_cran()
  skip_if_unreachable("https://www.fishbase.se/keys/allkeys.php")

  result <- importFishbase(keycode = 1, usePhyloService = "none")

  expect_s3_class(result, "moose")
  expect_match(result$desc, "shark", ignore.case = TRUE)
  expect_gt(nrow(result$df), 0)
  expect_true(all(c("Statement", "Choice", "Character", "Taxon") %in% names(result$df)))
  expect_true(any(c("Carcharhinidae", "Sphyrnidae", "Lamnidae") %in% result$taxa$submitted_name))
})

test_that("GNA resolution returns matched names for the shark key", {
  skip_on_cran()
  skip_if_unreachable("https://www.fishbase.se/keys/allkeys.php")
  skip_if_unreachable("https://verifier.globalnames.org/api/v1/ping")
  skip_if_not_installed("taxize")

  result <- importFishbase(keycode = 1, usePhyloService = "GNA")
  expect_false(all(is.na(result$taxa$match_type)))
})
