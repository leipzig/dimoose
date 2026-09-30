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
