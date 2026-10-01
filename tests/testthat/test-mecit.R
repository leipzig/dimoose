skip_if_no_mecit <- function() {
  skip_if_not_installed("partykit")
  skip_if_not_installed("lme4")
}

# 12 clusters with baselines of -3 or +3. `a` varies within clusters and has a
# real effect; `d` is a cluster-level marker that lines up exactly with the
# baselines (the "clade marker" confound); `e` is noise.
mecitFixture <- function(seed = 1) {
  set.seed(seed)
  nc <- 12; per <- 40; n <- nc * per
  cluster <- rep(paste0("c", seq_len(nc)), each = per)
  base <- rep(rep(c(-3, 3), length.out = nc), each = per)
  a <- rbinom(n, 1, 0.5)
  d <- as.integer(base > 0)
  e <- rbinom(n, 1, 0.5)
  y <- base + 2 * a + rnorm(n)
  list(y = y, X = cbind(a = a, d = d, e = e), cluster = cluster)
}

test_that("mecit splits on the real effect and not on the cluster-level confound", {
  skip_if_no_mecit()
  f <- mecitFixture()
  fit <- mecit(f$y, f$X, f$cluster)
  expect_s3_class(fit, "mecit")
  expect_equal(splitVariables(fit), "a")
  expect_true(fit$converged)
})

test_that("without random effects the same tree also splits on the confound", {
  skip_if_no_mecit()
  f <- mecitFixture()
  plain <- mecit(f$y, f$X, cluster = NULL)
  expect_true(all(c("a", "d") %in% splitVariables(plain)))
  expect_null(plain$lmer)
})

test_that("mecit with method = mob delegates to glmertree and agrees", {
  skip_if_no_mecit()
  skip_if_not_installed("glmertree")
  f <- mecitFixture()
  fit <- mecit(f$y, f$X, f$cluster, method = "mob")
  expect_equal(fit$method, "mob")
  expect_equal(splitVariables(fit), "a")
})

test_that("split variables keep their original, non-syntactic names", {
  skip_if_no_mecit()
  f <- mecitFixture()
  X <- f$X; colnames(X) <- c("16311", "7028", "573.X")
  fit <- mecit(f$y, X, f$cluster)
  expect_equal(splitVariables(fit), "16311")
})

test_that("a tree with no signal has no splits", {
  skip_if_no_mecit()
  f <- mecitFixture()
  set.seed(9)
  fit <- mecit(rnorm(length(f$y)), f$X, f$cluster)
  expect_identical(splitVariables(fit), character(0))
  expect_error(keyFromMecit(fit), "no splits")
})

test_that("random slopes are accepted", {
  skip_if_no_mecit()
  f <- mecitFixture()
  fit <- mecit(f$y, f$X, f$cluster, slope = "a")
  expect_s3_class(fit, "mecit")
  expect_true("a" %in% splitVariables(fit))
})

test_that("mecit checks its inputs", {
  skip_if_no_mecit()
  f <- mecitFixture()
  expect_error(mecit(f$y[-1], f$X, f$cluster), "rows")
  expect_error(mecit(f$y, f$X, f$cluster[-1]), "cluster")
  expect_error(mecit(f$y, f$X, f$cluster, slope = "zz"), "zz")
  y <- f$y; y[1] <- NA
  expect_error(mecit(y, f$X, f$cluster), "missing")
  skip_if_not_installed("glmertree")
  expect_error(mecit(f$y, f$X, f$cluster, method = "mob", slope = "a"), "ctree")
})

test_that("keyFromMecit turns the tree into a key a machine can follow", {
  skip_if_no_mecit()
  f <- mecitFixture()
  X <- f$X; colnames(X) <- c("16311", "7028", "573.X")
  fit <- mecit(f$y, X, f$cluster)
  key <- keyFromMecit(fit)
  expect_s3_class(key, "moose")
  expect_length(key$validate(), 0)
  l <- key$leads
  expect_equal(l$Character[1:2], c("Carries 16311", "Does not carry 16311"))
  expect_equal(l$Test[1:2], c(">", "<="))
  expect_equal(sum(l$Next == "-"), 2)
  expect_match(l$Taxon[l$Next == "-"][1], "^Stratum [0-9]+: ")
  r <- classify(key, X)
  expect_equal(nrow(r), nrow(X))
  expect_true(all(r$result %in% l$Taxon))
  # the stratum a sample lands in matches whether it carries the site
  carriers <- X[, "16311"] == 1
  expect_equal(length(unique(r$result[carriers])), 1)
  expect_false(identical(unique(r$result[carriers]), unique(r$result[!carriers])))
  expect_match(exportWizard(key), "Carries 16311", fixed = TRUE)
})

test_that("print and summary of a mecit fit", {
  skip_if_no_mecit()
  f <- mecitFixture()
  fit <- mecit(f$y, f$X, f$cluster)
  expect_output(print(fit), "<moose mecit>")
  expect_output(print(fit), "splits on: a")
})

test_that("mecit recovers simulated recurrent-mutation effects without clade-marker splits", {
  skip_if_no_mecit()
  sim <- simulateExpression(n = 600, genes = 6, effect = 2, macroSD = 2, noise = 0.5, seed = 2)
  g <- which(sim$truth$geneType == "mutation")[1]
  truthSites <- colnames(sim$X)[sim$truth$beta[g, ] != 0]
  fit <- mecit(sim$expr[, g], sim$X, sim$samples$macro)
  expect_true(all(truthSites %in% splitVariables(fit)))
  expect_false(any(sim$markerSites %in% splitVariables(fit)))
})

test_that("partition columns may share names with mecit's internal columns", {
  skip_if_no_mecit()
  f <- mecitFixture()
  X <- f$X; colnames(X) <- c("y_", "ystar_", "cluster_")
  fit <- mecit(f$y, X, f$cluster)
  expect_equal(splitVariables(fit), "y_")       # the real effect, not the response
  X2 <- f$X; colnames(X2) <- c("node_", "d", "e")
  expect_equal(splitVariables(mecit(f$y, X2, f$cluster)), "node_")
})

test_that("factor splits become text-only couplets with a warning", {
  skip_if_no_mecit()
  f <- mecitFixture()
  X <- data.frame(tissue = factor(ifelse(f$X[, "a"] == 1, sample(c("liver", "lung"), length(f$y), TRUE), "skin")),
                  e = f$X[, "e"])
  fit <- mecit(f$y, X, f$cluster)
  expect_equal(splitVariables(fit), "tissue")
  expect_warning(key <- keyFromMecit(fit), "classify")
  expect_match(key$leads$Character[1], "^tissue is ")
})
