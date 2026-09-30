sharks <- function() {
  parseFishbase(
    test_path("fixtures", "fishbaseDescription.html"),
    test_path("fixtures", "fishbaseDetail.html"),
    usePhyloService = "none"
  )
}
count <- function(html, pattern) lengths(regmatches(html, gregexpr(pattern, html, fixed = TRUE)))

tinyKey <- function(leads) {
  df <- data.frame(Statement = "1", Choice = "a", Character = "x", Taxon = "A",
                   pSt = "", pCh = "", stringsAsFactors = FALSE)
  moose$new(df, "Tiny key", leads = leads)
}

test_that("the shark key exports as one self-contained page", {
  html <- expect_silent(exportWizard(sharks()))
  expect_type(html, "character")
  expect_match(html, "^<!doctype html>")
  expect_match(html, "<title>Key to the families of sharks", fixed = TRUE)
  expect_match(html, "name=\"viewport\"", fixed = TRUE)
  expect_equal(count(html, "class=\"couplet\""), 23)
  expect_equal(count(html, "class=\"taxon\""), 24)
  expect_equal(count(html, "class=\"choose\""), 46)
  expect_match(html, "data-root=\"c-1\"", fixed = TRUE)
  expect_false(grepl("<script src=|<link rel=\"stylesheet\"", html))
  expect_match(html, "https://www.fishbase.se/images/thumbnails/morphpic/tn_1term1.gif", fixed = TRUE)
})

test_that("every lead links to an existing couplet or taxon section", {
  html <- exportWizard(sharks())
  ids <- regmatches(html, gregexpr("<section class=\"(couplet|taxon)\" id=\"([^\"]+)\"", html))[[1]]
  ids <- sub(".*id=\"([^\"]+)\"", "\\1", ids)
  hrefs <- regmatches(html, gregexpr("class=\"choose\" href=\"#([^\"]+)\"", html))[[1]]
  hrefs <- sub(".*href=\"#([^\"]+)\"", "\\1", hrefs)
  expect_length(hrefs, 46)
  expect_true(all(hrefs %in% ids))
  expect_true(all(grep("^t-", ids, value = TRUE) %in% hrefs))
})

test_that("taxon sections list the path through the key", {
  html <- exportWizard(sharks())
  squatinidae <- regmatches(html, regexpr("<section class=\"taxon\"[^>]*>\\s*<p class=\"eyebrow\">Identified as</p>\\s*<h2[^>]*>Squatinidae</h2>.*?</section>", html))
  expect_match(squatinidae, ">1a</a>No anal fin.", fixed = TRUE)
  expect_match(squatinidae, ">2a</a>", fixed = TRUE)
  expect_match(squatinidae, "More on FishBase", fixed = TRUE)
})

test_that("exportWizard writes a UTF-8 file and returns its path", {
  f <- withr::local_tempfile(fileext = ".html")
  out <- exportWizard(sharks(), f)
  expect_identical(out, f)
  expect_true(file.exists(f))
  expect_match(paste(readLines(f, encoding = "UTF-8"), collapse = "\n"), "Squatinidae")
})

test_that("displayLinks = FALSE hides couplet numbers", {
  expect_match(exportWizard(sharks(), displayLinks = FALSE), "<body data-root=\"c-1\" class=\"nolinks\">", fixed = TRUE)
})

test_that("text from the key is HTML-escaped", {
  leads <- data.frame(
    Statement = c("1", "1"), Choice = c("a", "b"),
    Character = c("<script>alert(1)</script>", "Fin \"long\" & 'thin'"),
    Next = c("-", "-"), Taxon = c("A<b>", "B"), stringsAsFactors = FALSE
  )
  html <- exportWizard(tinyKey(leads))
  expect_false(grepl("<script>alert", html, fixed = TRUE))
  expect_match(html, "&lt;script&gt;alert(1)&lt;/script&gt;", fixed = TRUE)
  expect_match(html, "Fin &quot;long&quot; &amp; &#39;thin&#39;", fixed = TRUE)
  expect_match(html, ">A&lt;b&gt;</h2>", fixed = TRUE)
})

test_that("problems in the key are warned about and shown", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3"), Choice = c("a", "b", "a", "b", "a"),
    Character = c("x", "y", "p", "q", "orphan"),
    Next = c("2", "9", "-", "-", "-"), Taxon = c("", "", "A", "", "C"),
    stringsAsFactors = FALSE
  )
  msgs <- character()
  html <- withCallingHandlers(exportWizard(tinyKey(leads)),
    warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
  expect_true(any(grepl("1b leads to couplet 9", msgs)))
  expect_true(any(grepl("2b ends the key but names no taxon", msgs)))
  expect_true(any(grepl("Couplet 3 has only one lead", msgs)))
  expect_true(any(grepl("3 cannot be reached", msgs)))
  expect_match(html, "class=\"warnings\"", fixed = TRUE)
  expect_match(html, "missing from key", fixed = TRUE)
})

test_that("leads are rebuilt from paths when a key has no lead table", {
  m <- sharks()
  rebuilt <- leadsFromPaths(m$df)
  original <- m$leads
  key <- function(x) paste(x$Statement, x$Choice, x$Next, x$Taxon)
  expect_setequal(key(rebuilt), key(original))
  plain <- moose$new(m$df, m$desc)
  expect_equal(count(exportWizard(plain), "class=\"taxon\""), 24)
})

test_that("unimplemented options fail clearly", {
  expect_error(exportWizard(sharks(), order = "parsimony"), "not implemented")
  expect_error(exportWizard(list()), "moose object")
})
