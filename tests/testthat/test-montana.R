test_that("the montana lead table is a sound key of native trees", {
  m <- dimoose::montana
  expect_named(m, c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image"))
  k <- keyFromLeads(m)
  expect_length(k$validate(), 0)
  taxa <- m$Taxon[m$Next == "-"]
  expect_true(all(grepl("^[A-Z][a-z].* \\([A-Z][a-z]+ [a-z]+\\)$", taxa)))
  expect_false(anyDuplicated(taxa) > 0)
  expect_true(all(c("Quaking aspen (Populus tremuloides)", "Paper birch (Betula papyrifera)") %in% taxa))
  expect_false(any(grepl("Ulmus", taxa)))
  expect_true(all(nzchar(m$Question)))
})
