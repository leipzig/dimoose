test_that("inventNames are unique, pronounceable and reproducible", {
  a <- inventNames(200, seed = 3)
  expect_length(unique(a), 200)
  expect_true(all(grepl("^[a-z]{4,14}$", a)))
  expect_identical(a, inventNames(200, seed = 3))
  expect_false(identical(a, inventNames(200, seed = 4)))
})

test_that("discoverTerms finds the planted concepts", {
  v <- syntheticVision(n_labels = 8, k = 4, p = 9, d = 8)
  t <- discoverTerms(v$patches, k = 4, seed = 1)
  expect_s3_class(t, "mooseTerms")
  expect_equal(dim(t$centroids), c(4, 8))
  expect_equal(unname(round(sqrt(rowSums(t$centroids^2)), 6)), rep(1, 4))
  sims <- v$concepts %*% t(t$centroids)
  expect_true(all(apply(sims, 1, max) > 0.95))
  expect_equal(nrow(t$exemplars), 16)
  expect_equal(names(t$exemplars), c("term", "image", "patch", "score"))
})

test_that("termScores is the max patch cosine per term", {
  v <- syntheticVision()
  t <- discoverTerms(v$patches, k = 4)
  s <- termScores(v$patches, t$centroids)
  expect_equal(dim(s), c(6, 4))
  expect_equal(colnames(s), t$terms$name)
  manual <- max(v$patches[2, , ] %*% t$centroids[3, ])
  expect_equal(unname(s[2, 3]), manual)
})

test_that("keyFromTerms balanced reproduces a hand-worked example", {
  scores <- rbind(A = c(1, 1, 0), B = c(1, 0, 1), C = c(0, 1, 1), D = c(0, 0, 0))
  colnames(scores) <- c("t1", "t2", "t3")
  images <- data.frame(id = rownames(scores), path = "", label = rownames(scores), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:3, name = colnames(scores)), centroids = diag(3),
                exemplars = data.frame(term = character(), image = character(), patch = integer(), score = numeric()))
  rownames(terms$centroids) <- colnames(scores)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  l <- k$leads
  expect_equal(l$Feature[1:2], c("term:t1", "term:t1"))
  expect_equal(l$Test[1:2], c(">", "<="))
  expect_equal(l$Threshold[1], 0.5)
  expect_equal(l$Question[1], "t1")
  expect_equal(l$Character[1:2], c("Has t1", "Lacks t1"))
  expect_setequal(l$Taxon[l$Next == "-"], c("A", "B", "C", "D"))
  expect_length(k$validate(), 0)
  expect_equal(k$features$id, c("term:t1", "term:t2", "term:t3"))
  expect_equal(k$features$embedding[[2]], c(0, 1, 0))
})

test_that("label presence is any over its images", {
  # A's two images each have one term; "any over images" makes A present for
  # both, so A (t1,t2), B (none) and C (t1 only) stay separable.
  scores <- rbind(A = c(1, 0), A_2 = c(0, 1), B = c(0, 0), C = c(1, 0))
  colnames(scores) <- c("t1", "t2")
  images <- data.frame(id = rownames(scores), path = "", label = c("A", "A", "B", "C"), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:2, name = colnames(scores)), centroids = diag(2), exemplars = NULL)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  expect_equal(sum(k$leads$Next == "-"), 3)
  expect_length(k$validate(), 0)
})

test_that("keyFromTerms rpart route works and labels that cannot be split share a leaf", {
  scores <- rbind(A = c(1, 0), B = c(1, 0), C = c(0, 1))
  colnames(scores) <- c("t1", "t2")
  images <- data.frame(id = rownames(scores), path = "", label = rownames(scores), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:2, name = colnames(scores)), centroids = diag(2), exemplars = NULL)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  expect_true("A / B" %in% k$leads$Taxon)
  k2 <- keyFromTerms(scores, images, terms, method = "rpart")
  expect_s3_class(k2, "moose")
  expect_true(all(grepl("^term:", k2$leads$Feature)))
})
