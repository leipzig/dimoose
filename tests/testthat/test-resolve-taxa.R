test_that("TNRS gives a clear error", {
  expect_error(dimoose:::resolveTaxa("Lamnidae", "TNRS"), "defunct")
})

test_that("'none' passes names through and drops duplicates", {
  out <- dimoose:::resolveTaxa(c("Lamnidae", "Lamnidae", "Sphyrnidae"), "none")
  expect_identical(out$submitted_name, c("Lamnidae", "Sphyrnidae"))
  expect_identical(out$matched_name, out$submitted_name)
})

test_that("gna_verifier columns are mapped back by submitted name", {
  skip_if_not_installed("taxize")
  skip_if_not("gna_verifier" %in% getNamespaceExports("taxize"))
  local_mocked_bindings(
    gna_verifier = function(names, ...) {
      data.frame(
        submittedName = c("Sphyrnidae", "Lamnidea"),
        matchedCanonicalSimple = c("Sphyrnidae", "Lamnidae"),
        currentCanonicalSimple = c("Sphyrnidae", "Lamnidae"),
        matchType = c("Exact", "Fuzzy"),
        dataSourceTitleShort = c("Catalogue of Life", "Catalogue of Life"),
        stringsAsFactors = FALSE
      )
    },
    .package = "taxize"
  )
  out <- dimoose:::resolveTaxa(c("Lamnidea", "Sphyrnidae", "Nomatchidae"), "GNA")
  expect_identical(out$matched_name, c("Lamnidae", "Sphyrnidae", "Nomatchidae"))
  expect_identical(out$match_type, c("Fuzzy", "Exact", NA))
})

test_that("a failing verifier warns and falls back to submitted names", {
  skip_if_not_installed("taxize")
  skip_if_not("gna_verifier" %in% getNamespaceExports("taxize"))
  local_mocked_bindings(
    gna_verifier = function(names, ...) stop("service unavailable"),
    .package = "taxize"
  )
  expect_warning(out <- dimoose:::resolveTaxa("Lamnidae", "GNA"), "service unavailable")
  expect_identical(out$matched_name, "Lamnidae")
})

test_that("GNR is accepted as an alias for GNA", {
  expect_silent(dimoose:::resolveTaxa(character(), "GNR"))
})
