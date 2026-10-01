vocabFixture <- function() {
  vocab <- data.frame(feature = c("round lights", "a flat hood"), opposite = c("square lights", "a curved hood"),
                      region = c("0.15,0.55,0,1", NA), stringsAsFactors = FALSE)
  prompts <- vocabularyPrompts(vocab, "a truck with {x}")
  txt <- rbind(c(1, 0, 0, 0), c(-1, 0, 0, 0), c(0, 1, 0, 0), c(0, -1, 0, 0))
  rownames(txt) <- prompts
  img <- rbind(A = c(1, 1, 0.1, 0), B = c(1, -1, 0, 0.1), C = c(-1, 1, 0.1, 0), D = c(-1, -1, 0, 0.1))
  img <- img / sqrt(rowSums(img^2))
  images <- data.frame(id = rownames(img), path = "", label = rownames(img), stringsAsFactors = FALSE)
  list(vocab = vocab, prompts = prompts, txt = txt, img = img, images = images)
}

test_that("vocabularyPrompts interleaves feature and opposite", {
  f <- vocabFixture()
  expect_equal(f$prompts, c("a truck with round lights", "a truck with square lights", "a truck with a flat hood", "a truck with a curved hood"))
})

test_that("keyFromClusters builds a valid key with text features", {
  f <- vocabFixture()
  k <- keyFromClusters(f$img, f$images, f$vocab, f$txt, template = "a truck with {x}")
  expect_length(k$validate(), 0)
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], c("A", "B", "C", "D"))
  expect_true(all(k$features$kind == "clip_text_pair"))
  expect_equal(k$features$region[k$features$id == "text:round_lights"], "0.15,0.55,0,1")
  expect_match(k$leads$Question[1], "^Does it have ")
  expect_equal(k$leads$Test[1:2], c(">", "<="))
  s <- featureScores(k, image = f$img, textEmb = f$txt)
  expect_equal(evaluateKey(k, s, f$images$label)$accuracy, 1)
})

test_that("yes lead points at the side that has the feature", {
  f <- vocabFixture()
  txt <- f$txt; txt[1, ] <- c(-1, 0, 0, 0); txt[2, ] <- c(1, 0, 0, 0)
  k <- keyFromClusters(f$img, f$images, f$vocab, txt, template = "a truck with {x}")
  s <- featureScores(k, image = f$img, textEmb = txt)
  r <- classify(k, s)
  expect_equal(r$result, c("A", "B", "C", "D"))
  i <- which(k$leads$Feature == "text:round_lights" & k$leads$Test == ">")[1]
  expect_equal(k$leads$Character[i], "Has round lights")
})

test_that("order puts the smaller key first and midpoint calibration moves the threshold", {
  f <- vocabFixture()
  # Asymmetric embeddings so the two sides' mean scores don't cancel at 0.
  img <- rbind(A = c(1, 1, 0.1, 0), B = c(1, -0.2, 0, 0.1), C = c(-0.2, 1, 0.1, 0), D = c(-0.2, -0.2, 0, 0.1))
  img <- img / sqrt(rowSums(img^2))
  k <- keyFromClusters(img, f$images, f$vocab, f$txt, template = "a truck with {x}",
                       order = function(l) min(match(l, c("D", "C", "B", "A"))), calibrate = "midpoint")
  expect_false(all(k$leads$Threshold == 0))
  expect_length(k$validate(), 0)
})

test_that("a question is not reused below itself", {
  f <- vocabFixture()
  k <- keyFromClusters(f$img, f$images, f$vocab, f$txt, template = "a truck with {x}")
  paths <- strsplit(classify(k, featureScores(k, f$img, textEmb = f$txt))$path, " ")
  for (p in paths) {
    cps <- sub("[ab]$", "", p)
    expect_equal(anyDuplicated(k$leads$Feature[match(cps, k$leads$Statement)]), 0)
  }
})
