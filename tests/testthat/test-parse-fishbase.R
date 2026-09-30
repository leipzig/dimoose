fixture <- function(name) test_path("fixtures", name)

sharks <- function(...) {
  parseFishbase(
    fixture("fishbaseDescription.html"),
    fixture("fishbaseDetail.html"),
    usePhyloService = "none",
    ...
  )
}

test_that("description page yields plain strings", {
  info <- moose:::parseFishbaseDescription(xml2::read_html(fixture("fishbaseDescription.html")))
  expect_identical(info$desc, "Key to the families of sharks in the Western Central Pacific.")
  expect_type(info$citation, "character")
  expect_match(info$citation, "^Compagno")
})

test_that("key table is found by its header row, not by position", {
  kt <- moose:::parseFishbaseKeyTable(xml2::read_html(fixture("fishbaseDetail.html")))
  expect_named(kt, c("Statement", "Choice", "Character", "Next", "Prev", "Taxon", "Image", "ImageLink", "TaxonUrl"))
  expect_match(kt$Image[1], "^https://www.fishbase.se/images/thumbnails/morphpic/tn_1term1.gif$")
  expect_identical(kt$ImageLink[1], "https://www.fishbase.se/keys/pic/1term1.gif")
  expect_match(kt$TaxonUrl[kt$Taxon == "Squatinidae"], "specieslist.php")
  expect_equal(nrow(kt), 46)
  expect_identical(kt$Statement[1:2], c("1", "1"))
  expect_identical(kt$Choice[1:2], c("a", "b"))
  expect_identical(kt$Next[1:2], c("2", "5"))
  expect_identical(kt$Taxon[kt$Statement == "4"], c("Echinorhinidae", "Squalidae"))
})

test_that("parseFishbase builds a moose object from saved pages", {
  m <- sharks()
  expect_s3_class(m, "moose")
  expect_identical(m$desc, "Key to the families of sharks in the Western Central Pacific.")
  expect_true(all(c("Statement", "Choice", "Character", "Taxon", "pSt", "pCh") %in% names(m$df)))
  expect_true(all(c("Squatinidae", "Pristiophoridae", "Echinorhinidae") %in% m$df$Taxon))
  expect_false(any(grepl("^\\s|\\s$", m$df$Character)))
  expect_true(all(c("submitted_name", "matched_name") %in% names(m$taxa)))
  expect_identical(m$taxa$matched_name, m$taxa$submitted_name)
})

test_that("every path starts at the root couplet", {
  m <- sharks()
  roots <- m$df[m$df$pSt == "", ]
  expect_true(all(roots$Statement == "1"))
  expect_setequal(unique(m$df$Taxon), unique(m$taxa$submitted_name))
})

test_that("separateTerms controls splitting on ';'", {
  split <- sharks(separateTerms = TRUE)$df
  whole <- sharks(separateTerms = FALSE)$df
  expect_gt(nrow(split), nrow(whole))
  expect_false(any(grepl(";", split$Character, fixed = TRUE)))
})

test_that("morphology image URLs are captured and absolute", {
  meta <- sharks()$meta
  urls <- meta$value[startsWith(meta$key, "image_url_")]
  expect_gt(length(urls), 0)
  expect_true(all(startsWith(urls, "https://www.fishbase.se/images/")))
  expect_false(anyDuplicated(urls) > 0)
})

test_that("toDataTree works without dplyr attached", {
  tree <- sharks(separateTerms = FALSE)$toDataTree()
  expect_s3_class(tree, "Node")
})

test_that("a couplet reached from two leads yields one path per parent", {
  kt <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3"),
    Choice = c("a", "b", "a", "b", "a", "b"),
    Character = c("x", "y", "p", "q", "m", "n"),
    Next = c("2", "3", "-", "-", "2", "-"),
    Prev = c("1", "1", "1", "1", "1", "1"),
    Taxon = c("", "", "A", "B", "", "C"),
    stringsAsFactors = FALSE
  )
  paths <- moose:::keyPaths(kt)
  a <- paths[paths$Taxon == "A", ]
  expect_setequal(a$pSt[a$Statement == "2"], c("1", "3"))
})

test_that("cycles are reported instead of recursing forever", {
  kt <- data.frame(
    Statement = c("1", "1", "2", "2"),
    Choice = c("a", "b", "a", "b"),
    Character = c("x", "y", "p", "q"),
    Next = c("2", "-", "1", "-"),
    Prev = c("", "", "", ""),
    Taxon = c("", "A", "", "B"),
    stringsAsFactors = FALSE
  )
  expect_error(moose:::keyPaths(kt), "Cycle")
})
