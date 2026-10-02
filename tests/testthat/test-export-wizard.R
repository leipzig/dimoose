sharks <- function() sharkKey()
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

test_that("the map draws every couplet and taxon, linked to the sections", {
  html <- exportWizard(sharks())
  svg <- regmatches(html, regexpr("<svg class=\"keymap\".*?</svg>", html))
  expect_length(svg, 1)
  expect_equal(count(svg, "class=\"mnode mcouplet\""), 23)
  expect_equal(count(svg, "class=\"mnode mleaf\""), 24)
  expect_equal(count(svg, "class=\"medge\""), 46)
  targets <- sub(".*href=\"#([^\"]+)\"", "\\1", regmatches(svg, gregexpr("class=\"mnode[^\"]*\" href=\"#[^\"]+\"", svg))[[1]])
  sections <- sub(".*id=\"([^\"]+)\"", "\\1", regmatches(html, gregexpr("<section class=\"(couplet|taxon)\" id=\"[^\"]+\"", html))[[1]])
  expect_setequal(targets, sections)
  # map node classes must not collide with section classes hidden in step mode
  expect_false(grepl("class=\"mnode couplet\"|class=\"mnode taxon\"", svg))
  expect_match(html, "id=\"mk-maptoggle\"", fixed = TRUE)
})

test_that("map = FALSE leaves the map out", {
  html <- exportWizard(sharks(), map = FALSE)
  expect_false(grepl("<svg class=\"keymap\"|id=\"mk-maptoggle\"|<aside class=\"map\"", html))
})

test_that("a couplet reached from two leads is drawn once with a dashed cross-link", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3"),
    Choice = c("a", "b", "a", "b", "a", "b"),
    Character = c("x", "y", "p", "q", "m", "n"),
    Next = c("2", "3", "-", "-", "2", "-"),
    Taxon = c("", "", "A", "B", "", "C"),
    stringsAsFactors = FALSE
  )
  svg <- regmatches(html <- exportWizard(tinyKey(leads)), regexpr("<svg class=\"keymap\".*?</svg>", html))
  expect_equal(count(svg, "data-id=\"c-2\""), 1)
  expect_equal(count(svg, "class=\"medge cross\""), 1)
  expect_match(svg, "class=\"medge cross\" data-from=\"c-3\" data-to=\"c-2\"", fixed = TRUE)
})

glossaryKey <- function() {
  v <- syntheticVision(k = 3)
  t <- discoverTerms(v$patches, k = 3)
  key <- keyFromTerms(termScores(v$patches, t$centroids), v$images, t, quantile = 0.5)
  cpng <- tempfile(fileext = ".png"); png::writePNG(array(0.5, c(8, 8, 3)), cpng)
  cb64 <- base64enc::base64encode(cpng)
  f <- key$features
  for (j in seq_len(nrow(f))) f$exemplars[[j]]$png <- rep(cb64, nrow(f$exemplars[[j]]))
  key$features <- f
  ipng1 <- tempfile(fileext = ".png"); png::writePNG(array(runif(8 * 8 * 3), c(8, 8, 3)), ipng1)
  ipng2 <- tempfile(fileext = ".png"); png::writePNG(array(runif(8 * 8 * 3), c(8, 8, 3)), ipng2)
  key$meta <- rbind(key$meta, imageMeta(c(ipng1, ipng2), ids = c("1948-1950", "H2a+152")))
  l <- key$leads; l$Image[1] <- "1948-1950;H2a+152"; key$leads <- l
  key
}

test_that("each embedded image appears once and with its own MIME type", {
  key <- glossaryKey()
  html <- exportWizard(key)
  uri <- key$meta$value[key$meta$key == "image_1948-1950"]
  expect_equal(lengths(regmatches(html, gregexpr(uri, html, fixed = TRUE))), 1)
  expect_match(html, "--img-1948-1950:url(\"data:image/png;base64,", fixed = TRUE)
  expect_match(html, "style=\"background-image:var(--img-1948-1950)\"", fixed = TRUE)
})

test_that("image names are sanitized for CSS", {
  html <- exportWizard(glossaryKey())
  expect_match(html, "--img-H2a_152:", fixed = TRUE)
  expect_false(grepl("--img-H2a+152", html, fixed = TRUE))
})

test_that("legacy base64 images without a data: prefix still render as gif", {
  k <- sharkKey()
  k$meta <- rbind(k$meta, data.frame(key = "image_tn_x", value = base64enc::base64encode(charToRaw("GIF89a")), stringsAsFactors = FALSE))
  l <- k$leads; l$Image[1] <- "https://example.org/tn_x.gif"; k$leads <- l
  expect_match(exportWizard(k), "--img-tn_x:url(\"data:image/gif;base64,", fixed = TRUE)
})

test_that("Question is the step heading and the glossary lists terms with crops", {
  key <- glossaryKey()
  html <- exportWizard(key)
  q <- key$leads$Question[1]
  expect_match(html, sprintf("<h2 id=\"h-c-1\" tabindex=\"-1\">%s <span class=\"num\">Sniglet 1</span>", q), fixed = TRUE)
  expect_match(html, "<section class=\"glossary\" id=\"glossary\"", fixed = TRUE)
  expect_match(html, sprintf("id=\"g-%s\"", key$features$label[1]), fixed = TRUE)
  expect_match(html, sprintf("href=\"#g-%s\"", key$features$label[1]), fixed = TRUE)
})

test_that("keys without features have no glossary", {
  expect_false(grepl("class=\"glossary\"", exportWizard(arachnidaKey()), fixed = TRUE))
})

test_that("a renamed sniglet shows its new name, its definition and its coined word", {
  key <- glossaryKey()
  coined <- key$leads$Question[1]
  renamed <- renameSniglets(key, stats::setNames("round headlights", coined),
                            definitions = stats::setNames("Circular lamps <in> the grille", coined))
  html <- exportWizard(renamed)
  expect_match(html, "Has round headlights", fixed = TRUE)
  expect_match(html, "<h3 class=\"named\">round headlights</h3><p class=\"definition\">Circular lamps &lt;in&gt; the grille</p>", fixed = TRUE)
  expect_match(html, sprintf("Sniglet <code>%s</code>", coined), fixed = TRUE)
  expect_match(html, sprintf("id=\"g-%s\"", coined), fixed = TRUE)      # the anchor keeps the coined word
  expect_false(grepl(paste("Has", coined), html, fixed = TRUE))
})
