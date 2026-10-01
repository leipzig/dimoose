test_that("simulateExpression returns expression, design and ground truth", {
  sim <- simulateExpression(n = 200, genes = 10, seed = 1)
  expect_equal(dim(sim$expr), c(200, 10))
  expect_equal(nrow(sim$samples), 200)
  expect_true(all(c("sample", "haplogroup", "macro") %in% names(sim$samples)))
  expect_equal(nrow(sim$X), 200)
  expect_true(all(sim$X %in% c(0, 1)))
  expect_equal(dim(sim$truth$beta), c(10, ncol(sim$X)))
  expect_equal(colnames(sim$truth$beta), colnames(sim$X))
  expect_equal(as.vector(table(sim$truth$geneType)[c("mutation", "baseline", "null")]), c(4, 3, 3))
  # only mutation genes have mutation effects, and only on the effect sites
  expect_true(all(sim$truth$beta[sim$truth$geneType != "mutation", ] == 0))
  expect_true(all(sim$truth$beta[, !colnames(sim$X) %in% sim$effectSites] == 0))
  # null genes have no baseline either
  expect_true(all(sim$truth$b[sim$truth$geneType == "null", ] == 0))
})

test_that("simulateExpression is reproducible from its seed", {
  a <- simulateExpression(n = 100, genes = 5, seed = 7)
  b <- simulateExpression(n = 100, genes = 5, seed = 7)
  c <- simulateExpression(n = 100, genes = 5, seed = 8)
  expect_identical(a$expr, b$expr)
  expect_false(identical(a$expr, c$expr))
})

test_that("without noise or baselines, expression is exactly the mutation effects", {
  sim <- simulateExpression(n = 150, genes = 6, noise = 0, macroSD = 0, seed = 3)
  expect_equal(unname(sim$expr), unname(sim$X %*% t(sim$truth$beta)))
  expect_true(all(sim$expr[, sim$truth$geneType == "null"] == 0))
})

test_that("baseline genes are constant within a macrohaplogroup when there is no noise", {
  sim <- simulateExpression(n = 300, genes = 10, noise = 0, seed = 4)
  g <- which(sim$truth$geneType == "baseline")[1]
  spread <- tapply(sim$expr[, g], sim$samples$macro, function(x) diff(range(x)))
  expect_true(all(spread < 1e-12))
})

test_that("decoys include clade markers and the effect sites recur across macrohaplogroups", {
  sim <- simulateExpression(n = 500, genes = 4, seed = 5)
  expect_true(all(sim$effectSites %in% colnames(sim$X)))
  expect_gt(length(sim$markerSites), 0)
  expect_true(all(sim$markerSites %in% colnames(sim$X)))
  carriersByMacro <- colSums(rowsum(sim$X[, sim$effectSites, drop = FALSE], sim$samples$macro) > 0)
  expect_true(all(carriersByMacro >= 2))
})
