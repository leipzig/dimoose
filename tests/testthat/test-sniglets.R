test_that("inventNames are unique, pronounceable and reproducible", {
  a <- inventNames(200, seed = 3)
  expect_length(unique(a), 200)
  expect_true(all(grepl("^[a-z]{4,14}$", a)))
  expect_identical(a, inventNames(200, seed = 3))
  expect_false(identical(a, inventNames(200, seed = 4)))
})

test_that("discoverSniglets finds the planted concepts", {
  v <- syntheticVision(n_labels = 8, k = 4, p = 9, d = 8)
  t <- discoverSniglets(v$patches, k = 4, seed = 1)
  expect_s3_class(t, "mooseSniglets")
  expect_equal(dim(t$centroids), c(4, 8))
  expect_equal(unname(round(sqrt(rowSums(t$centroids^2)), 6)), rep(1, 4))
  sims <- v$concepts %*% t(t$centroids)
  expect_true(all(apply(sims, 1, max) > 0.95))
  expect_equal(nrow(t$exemplars), 16)
  expect_equal(names(t$exemplars), c("sniglet", "image", "patch", "score"))
})

test_that("snigletScores is the max patch cosine per sniglet", {
  v <- syntheticVision()
  t <- discoverSniglets(v$patches, k = 4)
  s <- snigletScores(v$patches, t$centroids)
  expect_equal(dim(s), c(6, 4))
  expect_equal(colnames(s), t$sniglets$sniglet)
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
  expect_equal(l$Feature[1:2], c("sniglet:t1", "sniglet:t1"))
  expect_equal(l$Test[1:2], c(">", "<="))
  expect_equal(l$Threshold[1], 0.5)
  expect_equal(l$Question[1], "t1")
  expect_equal(l$Character[1:2], c("Has t1", "Lacks t1"))
  expect_setequal(l$Taxon[l$Next == "-"], c("A", "B", "C", "D"))
  expect_length(k$validate(), 0)
  expect_equal(k$features$id, c("sniglet:t1", "sniglet:t2", "sniglet:t3"))
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
  expect_true(all(grepl("^sniglet:", k2$leads$Feature)))
})

# A small key on three sniglets t1..t3 (see the hand-worked example above)
snigletFixture <- function() {
  scores <- rbind(A = c(1, 1, 0), B = c(1, 0, 1), C = c(0, 1, 1), D = c(0, 0, 0))
  colnames(scores) <- c("t1", "t2", "t3")
  images <- data.frame(id = rownames(scores), path = "", label = rownames(scores), stringsAsFactors = FALSE)
  s <- structure(list(
    sniglets = data.frame(id = 1:3, sniglet = colnames(scores), name = colnames(scores), definition = NA_character_),
    centroids = diag(3), exemplars = NULL), class = "mooseSniglets")
  rownames(s$centroids) <- colnames(scores)
  list(scores = scores, images = images, sniglets = s, key = keyFromSniglets(scores, images, s, quantile = 0.5))
}

test_that("snigletNames lists coined words, names and which the key uses", {
  f <- snigletFixture()
  n <- snigletNames(f$key)
  expect_equal(names(n), c("sniglet", "name", "definition", "used"))
  expect_equal(n$sniglet, c("t1", "t2", "t3"))
  expect_equal(n$name, n$sniglet)
  expect_equal(n$used, c("sniglet:t1", "sniglet:t2", "sniglet:t3") %in% f$key$leads$Feature)
  expect_equal(names(snigletNames(f$sniglets)), c("sniglet", "name", "definition"))
  expect_error(snigletNames(arachnidaKey()), "no sniglets")
})

test_that("renameSniglets changes what people read and nothing a machine uses", {
  f <- snigletFixture()
  k <- renameSniglets(f$key, c(t1 = "round headlights"), definitions = c(t1 = "Circular lamps"))
  expect_equal(k$leads$Character[1:2], c("Has round headlights", "Lacks round headlights"))
  expect_equal(k$leads$Question[1], "round headlights")
  expect_equal(k$leads$Feature, f$key$leads$Feature)
  expect_equal(k$features$id, f$key$features$id)
  expect_equal(k$features$label[1], "round headlights")
  expect_equal(k$features$definition[1], "Circular lamps")
  expect_length(k$validate(), 0)
  expect_true(any(grepl("Has round headlights", k$df$Character)))        # the path table follows
  # the original key is untouched, and scores named by coined word still classify
  expect_equal(f$key$leads$Character[1], "Has t1")
  expect_equal(classify(k, f$scores)$result, classify(f$key, f$scores)$result)
  expect_equal(classify(k, f$scores)$result, c("A", "B", "C", "D"))
})

test_that("a sniglet can be renamed again by either name, and un-named", {
  f <- snigletFixture()
  k <- renameSniglets(f$key, c(t1 = "round headlights"))
  k2 <- renameSniglets(k, c("round headlights" = "round lamps"))
  expect_equal(snigletNames(k2)$name[1], "round lamps")
  k3 <- renameSniglets(k2, c(t1 = ""))
  expect_equal(snigletNames(k3)$name, c("t1", "t2", "t3"))
  expect_equal(k3$leads$Character, f$key$leads$Character)
})

test_that("a names table round-trips through a CSV file", {
  f <- snigletFixture()
  tab <- snigletNames(f$key)
  tab$name[tab$sniglet == "t1"] <- "round headlights"
  tab$definition[tab$sniglet == "t1"] <- "Circular lamps, either side of the grille"
  csv <- tempfile(fileext = ".csv")
  utils::write.csv(tab, csv, row.names = FALSE)
  k <- renameSniglets(f$key, csv)
  expect_equal(snigletNames(k)[, 1:3], tab[, 1:3])
  expect_equal(renameSniglets(f$key, tab)$leads, k$leads)
  # a table without a definition column leaves definitions alone
  k2 <- renameSniglets(k, data.frame(sniglet = "t1", name = "headlamps"))
  expect_equal(snigletNames(k2)$definition[1], "Circular lamps, either side of the grille")
  expect_error(renameSniglets(f$key, data.frame(a = 1)), "sniglet")
  expect_error(renameSniglets(f$key, "no-such.csv"), "not found")
})

test_that("names must be unique and must refer to real sniglets", {
  f <- snigletFixture()
  expect_error(renameSniglets(f$key, c(t1 = "lamp", t2 = "Lamp")), "share a name")
  expect_error(renameSniglets(f$key, c(t1 = "t2")), "coined word")
  expect_error(renameSniglets(f$key, c(zz = "lamp")), "zz")
  expect_error(renameSniglets(f$key, c(t1 = "a", t1 = "b")), "more than once")
  expect_error(renameSniglets(f$key, c("lamp")), "named character vector")
  swap <- renameSniglets(renameSniglets(f$key, c(t1 = "a", t2 = "b")), c(a = "b", b = "a"))
  expect_equal(snigletNames(swap)$name[1:2], c("b", "a"))
})

test_that("names given before the key is built carry into it", {
  f <- snigletFixture()
  s <- renameSniglets(f$sniglets, c(t1 = "round headlights"), definitions = c(t2 = "A flat hood"))
  expect_equal(snigletNames(s)$name, c("round headlights", "t2", "t3"))
  k <- keyFromSniglets(f$scores, f$images, s, quantile = 0.5)
  expect_equal(k$leads$Character[1], "Has round headlights")
  expect_equal(k$features$definition[2], "A flat hood")
  k2 <- keyFromSniglets(f$scores, f$images, s, method = "rpart")
  expect_true(any(grepl("round headlights$", k2$leads$Character)))
  expect_true(all(grepl("^sniglet:", k2$leads$Feature)))
})

test_that("the earlier names still work", {
  v <- syntheticVision()
  t <- discoverTerms(v$patches, k = 4)
  s <- termScores(v$patches, t$centroids)
  k <- keyFromTerms(s, v$images, t, quantile = 0.5)
  expect_s3_class(k, "moose")
  old <- structure(list(terms = data.frame(id = 1:4, name = colnames(s)), centroids = t$centroids,
                        exemplars = stats::setNames(t$exemplars, c("term", "image", "patch", "score"))), class = "mooseTerms")
  expect_equal(keyFromTerms(s, v$images, old, quantile = 0.5)$leads, k$leads)
})
