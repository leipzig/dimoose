test_that("generateTree handles non-syntactic column names", {
  d <- data.frame(
    species = factor(c("A", "B", "C", "A", "B", "C")),
    `Growth at 3% NaCl` = factor(c("+", "-", "-", "+", "-", "-")),
    `Indole (test)` = factor(c("+", "+", "-", "+", "+", "-")),
    check.names = FALSE
  )
  fit <- generateTree(d, "species",
    params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0))
  )
  expect_s3_class(fit, "rpart")
  expect_true(any(c("Growth at 3% NaCl", "Indole (test)") %in% as.character(fit$frame$var)))
})

test_that("generateTree validates its inputs", {
  expect_error(generateTree(list(), "x"), "data frame")
  expect_error(generateTree(data.frame(a = 1), "b"), "column name")
  expect_error(generateTree(data.frame(a = 1), "a", method = "svm"))
})

ensembleData <- function() {
  set.seed(2)
  d <- data.frame(family = factor(sample(c("A", "B", "C"), 150, TRUE)))
  d$fin <- factor(ifelse(d$family == "A", "x", "y"))
  d$head <- factor(ifelse(d$family == "C", "q", "p"))
  d
}

test_that("generateTree fits a random forest", {
  skip_if_not_installed("randomForest")
  fit <- generateTree(ensembleData(), "family", method = "randomForest", params = list(ntree = 20))
  expect_s3_class(fit, "randomForest")
  expect_equal(fit$type, "classification")
})

test_that("generateTree fits gbm on a factor with more than two taxa", {
  skip_if_not_installed("gbm")
  fit <- suppressWarnings(generateTree(ensembleData(), "family", method = "gbm",
    params = list(n.trees = 20, cv.folds = 0)))
  expect_s3_class(fit, "gbm")
  expect_equal(fit$distribution$name, "multinomial")
})

test_that("generateTree uses bernoulli for a 0/1 response", {
  skip_if_not_installed("gbm")
  d <- ensembleData()
  d$family <- as.integer(d$family == "A")
  fit <- generateTree(d, "family", method = "gbm", params = list(n.trees = 20, cv.folds = 0))
  expect_equal(fit$distribution$name, "bernoulli")
})

test_that("generateTree separates a matrix with one row per taxon by default", {
  d <- data.frame(
    taxon = c("A", "B", "C", "D", "E"),
    wings = c("+", "+", "-", "-", "-"),
    spots = c("+", "-", "+", "-", "-"),
    tail = c("long", "long", "short", "short", "long"),
    stringsAsFactors = TRUE
  )
  fit <- generateTree(d, "taxon")
  expect_s3_class(fit, "rpart")
  expect_equal(sum(fit$frame$var == "<leaf>"), 5)

  k <- keyFromRpart(fit)
  expect_length(k$validate(), 0)
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], c("A", "B", "C", "D", "E"))
  expect_equal(summary(k)$couplets, 4)
})

test_that("generateTree still takes its control from params", {
  d <- data.frame(taxon = factor(c("A", "B", "C")), wings = factor(c("+", "-", "-")),
                  spots = factor(c("-", "+", "-")))
  fit <- generateTree(d, "taxon", params = list(control = rpart::rpart.control(minsplit = 20)))
  expect_true(all(fit$frame$var == "<leaf>"))
  expect_error(keyFromRpart(fit), "no splits")
})

test_that("generateTree needs at least one feature", {
  expect_error(generateTree(data.frame(taxon = c("A", "B")), "taxon"), "no feature columns")
})

test_that("a random forest or gbm records the call to generateTree, not the data", {
  skip_if_not_installed("randomForest")
  fit <- generateTree(ensembleData(), "family", method = "randomForest", params = list(ntree = 5))
  expect_equal(as.character(fit$call[[1]]), "generateTree")
  expect_lt(length(utils::capture.output(print(fit))), 20)
  expect_equal(length(stats::predict(fit, ensembleData())), 150)
  # an rpart fit, which does not print its call, is returned as rpart made it
  tree <- generateTree(ensembleData(), "family")
  expect_true(is.data.frame(tree$call$data))
})

test_that("keyFromRpart lists a taxon rpart could not place at every result below", {
  d <- data.frame(taxon = factor(c("A", "B", "C")), w = factor(c(NA, "a", "b")), z = factor(c("1", NA, "2")))
  fit <- generateTree(d, "taxon")
  # A stays at the first split: w is missing for it and so is the surrogate for B
  expect_true(1 %in% fit$where)
  k <- keyFromRpart(fit)
  expect_equal(k$leads$Taxon, c("A / B", "A / C"))
  expect_length(k$validate(), 0)
})

test_that("keyFromRpart keeps an equals sign in a name or a state", {
  d <- data.frame(taxon = c("A", "B", "C"), `a=b` = c("x=1", "y", "y"), `pH>=7` = c("+", "+", "-"),
                  check.names = FALSE, stringsAsFactors = TRUE)
  k <- keyFromRpart(generateTree(d, "taxon"))
  expect_setequal(k$leads$Character, c("a=b: x=1", "a=b: y", "pH>=7: +", "pH>=7: -"))
  # numeric splits keep the form other code reads
  n <- keyFromRpart(generateTree(data.frame(taxon = c("A", "B"), len = c(1, 2.5)), "taxon"))
  expect_equal(n$leads$Character, c("len< 1.75", "len>: 1.75"))
})

test_that("single rpart settings in params are not overridden by the default control", {
  d <- data.frame(taxon = rep(c("A", "B", "C", "D"), each = 10), x = rep(c("p", "p", "q", "q"), each = 10),
                  y = rep(c("u", "v", "u", "v"), each = 10))
  leaves <- function(...) sum(generateTree(d, "taxon", ...)$frame$var == "<leaf>")
  expect_equal(leaves(), 4)
  expect_equal(leaves(params = list(cp = 0.9)), 1)
  expect_equal(leaves(params = list(minsplit = 100)), 1)
  expect_equal(leaves(params = list(maxdepth = 1)), 2)
  fit <- generateTree(d, "taxon", params = list(maxdepth = 1))
  expect_equal(fit$control$maxdepth, 1)
  expect_equal(fit$control$minsplit, 2)
  # a setting on its own wins over the same setting in a control given with it
  both <- generateTree(d, "taxon", params = list(control = rpart::rpart.control(cp = 0), cp = 0.9))
  expect_equal(both$control$cp, 0.9)
})

test_that("generateTree says so when there is nothing to tell apart", {
  expect_error(generateTree(data.frame(t = c("A", "A"), a = c("x", "y")), "t"), "at least two different taxa")
  expect_error(generateTree(data.frame(t = character(), a = character()), "t"), "no rows")
  # a numeric response for a regression tree is not held to that
  fit <- generateTree(data.frame(t = c(1, 1, 1, 1), a = c("x", "x", "y", "y")), "t", params = list(method = "anova"))
  expect_s3_class(fit, "rpart")
})
