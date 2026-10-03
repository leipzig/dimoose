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
