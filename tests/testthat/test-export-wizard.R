sharks <- function() sharkKey()
count <- function(html, pattern) lengths(regmatches(html, gregexpr(pattern, html, fixed = TRUE)))

tinyKey <- function(leads) {
  df <- data.frame(Statement = "1", Choice = "a", Character = "x", Taxon = "A",
                   pSt = "", pCh = "", stringsAsFactors = FALSE)
  dimoose$new(df, "Tiny key", leads = leads)
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
  plain <- dimoose$new(m$df, m$desc)
  expect_equal(count(exportWizard(plain), "class=\"taxon\""), 24)
})

test_that("order is deprecated: \"original\" is silent, \"parsimony\" warns and points to keyFromMatrix()", {
  plain <- exportWizard(sharks())
  expect_identical(expect_silent(exportWizard(sharks(), order = "original")), plain)
  expect_warning(html <- exportWizard(sharks(), order = "parsimony"),
                 "deprecated and ignored.*keyFromMatrix\\(characters = \\).*Cost")
  expect_identical(html, plain)
  expect_error(exportWizard(sharks(), order = "random"), "should be one of")
  # positional calls written for the old signature still work
  expect_identical(exportWizard(sharks(), NULL, TRUE, "original", NULL, TRUE), plain)
})

test_that("bad input fails clearly", {
  expect_error(exportWizard(list()), "dimoose object")
  expect_error(exportWizard(), "Give a `key`, a `matrix`, or both")
  expect_warning(exportWizard(sharks(), characters = data.frame(Character = "x")), "ignored without one")
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
  expect_match(html, sprintf("<h2 id=\"h-c-1\" tabindex=\"-1\">%s <span class=\"num\">Couplet 1</span>", q), fixed = TRUE)
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

test_that("a sniglet lead is marked so that its example crops choose it", {
  html <- exportWizard(glossaryKey())
  expect_match(html, "<li class=\"lead examples\"><a class=\"choose\"", fixed = TRUE)
  expect_match(html, "<a class=\"gloss\" href=\"#g-", fixed = TRUE)
  # an ordinary key keeps plain leads: its figures zoom or open their link
  plain <- exportWizard(sharkKey())
  expect_match(plain, "<li class=\"lead\">", fixed = TRUE)
  expect_false(grepl("lead examples", plain, fixed = TRUE))
})

test_that("a glossary crop the key already stores is embedded once", {
  key <- glossaryKey()
  f <- key$features
  coined <- snigletWord(f$id[1])
  cpng <- tempfile(fileext = ".png"); png::writePNG(array(runif(8 * 8 * 3), c(8, 8, 3)), cpng)
  b64 <- base64enc::base64encode(cpng)
  f$exemplars[[1]]$png[1] <- b64
  key$features <- f
  key$meta <- rbind(key$meta, data.frame(key = paste0("image_", coined, "_1"),
                                         value = paste0("data:image/png;base64,", b64), stringsAsFactors = FALSE))
  html <- exportWizard(key)
  expect_equal(lengths(regmatches(html, gregexpr(b64, html, fixed = TRUE))), 1)
  expect_match(html, sprintf("background-image:var(--img-%s_1)", coined), fixed = TRUE)
  # a crop that differs from the stored one is still shown as itself
  f$exemplars[[1]]$png[1] <- base64enc::base64encode(charToRaw("other"))
  key$features <- f
  expect_match(exportWizard(key), "background-image:url(&quot;data:image/png;base64,b3RoZXI=", fixed = TRUE)
})

test_that("the wizard script follows in-page links itself", {
  # Preview panes and sandboxed frames ignore "#..." navigation, so the page
  # must not depend on location.hash changing to move between couplets.
  js <- paste(readLines(system.file("wizard", "wizard.js", package = "dimoose"), warn = FALSE), collapse = "\n")
  expect_false(grepl("location.hash\\s*=", js))
  expect_match(js, "ev.preventDefault();\n    var st = top();", fixed = TRUE)
  expect_match(js, "    go(anchor);\n  });", fixed = TRUE)
  # history may be unavailable there too: the page still moves
  expect_match(js, "} catch (e) { /* no history here (sandboxed frame): the page still moves */ }\n    update(true);", fixed = TRUE)
})

# ---- not sure, hook --------------------------------------------------------------

test_that("the plain document carries no not-sure buttons; the script adds them", {
  html <- exportWizard(sharks())
  body <- sub("<script>.*", "", html)
  expect_false(grepl("unsure", sub("<style>.*?</style>", "", body)))
  expect_match(html, "unsure-btn", fixed = TRUE)
  expect_match(html, "<section class=\"couplet\" id=\"c-1\" aria-labelledby=\"h-c-1\" data-name=\"Couplet 1\">", fixed = TRUE)
  expect_match(html, "u if you are not sure", fixed = TRUE)
  # the remaining count and the trail are announced
  expect_match(html, "id=\"mk-left\" aria-live=\"polite\"", fixed = TRUE)
  expect_match(html, "id=\"mk-trail\" aria-label=\"Choices so far\" aria-live=\"polite\"", fixed = TRUE)
})

test_that("the page script defines the documented window.dimoose hook", {
  js <- paste(readLines(system.file("wizard", "wizard.js", package = "dimoose"), warn = FALSE), collapse = "\n")
  hook <- regmatches(js, regexpr("win\\.dimoose = \\{.*?\n  \\};", js))
  expect_length(hook, 1)
  for (member in c("taxa:", "highlight:", "goToTaxon:", "state:", "onChange:")) expect_match(hook, member, fixed = TRUE)
})

# ---- character matrix --------------------------------------------------------------

insectKey <- function() {
  keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "Silverfish", "Fly", "Bee"),
    stringsAsFactors = FALSE
  ), "A tiny key")
}
insectMatrix <- function() {
  data.frame(
    Taxon = c("Silverfish", "Fly", "bee", "Ant <queen>"),
    Wings = c("absent", "present", "present", " present / absent "),
    Sting = c("absent", "absent", "present", NA),
    stringsAsFactors = FALSE
  )
}
insectCharacters <- function() {
  data.frame(Character = c("Wings", "Sting", "Not in the matrix"), Cost = c(5, 1, 0),
             Needs = c("", "hand lens", "x"), Season = c("summer, autumn", "", ""), stringsAsFactors = FALSE)
}

test_that("a matrix adds the character list to the key's page", {
  expect_message(html <- exportWizard(insectKey(), matrix = insectMatrix(), characters = insectCharacters()),
                 "1 of 4 taxa of the matrix are not results of the key and get no link: Ant <queen>", fixed = TRUE)
  expect_equal(count(html, "<section class=\"matrix\" id=\"matrix\""), 1)
  expect_match(html, "<button type=\"button\" id=\"mk-pick\" aria-pressed=\"false\">", fixed = TRUE)
  # cheapest character first, with what it needs and when it shows
  expect_match(html, paste0(
    "<thead><tr><th scope=\"col\">Taxon</th>",
    "<th scope=\"col\" data-char=\"Sting\" data-cost=\"1\" data-needs=\"hand lens\">Sting<small>needs hand lens</small></th>",
    "<th scope=\"col\" data-char=\"Wings\" data-cost=\"5\" data-season=\"summer, autumn\">Wings<small>summer, autumn</small></th></tr></thead>"
  ), fixed = TRUE)
  # taxa are matched to the key's results by name, ignoring case; others get their own id
  expect_match(html, "<tr data-taxon=\"t-1\"><th scope=\"row\"><a href=\"#t-1\">Silverfish</a></th><td>absent</td><td>absent</td></tr>", fixed = TRUE)
  expect_match(html, "<tr data-taxon=\"t-3\"><th scope=\"row\"><a href=\"#t-3\">bee</a></th><td>present</td><td>present</td></tr>", fixed = TRUE)
  expect_match(html, "<tr data-taxon=\"m-4\"><th scope=\"row\">Ant &lt;queen&gt;</th><td data-na>?</td><td>present / absent</td></tr>", fixed = TRUE)
  # the key is all still there
  expect_equal(count(html, "class=\"couplet\""), 2)
  expect_match(html, "data-root=\"c-1\"", fixed = TRUE)
})

test_that("without a matrix the page has no character list", {
  html <- exportWizard(insectKey())
  expect_false(grepl("id=\"matrix\"|id=\"mk-pick\"|<table", html))
})

test_that("a matrix alone makes a page of its own", {
  html <- expect_silent(exportWizard(NULL, matrix = insectMatrix()))
  expect_match(html, "<title>Multi-access key</title>", fixed = TRUE)
  expect_match(html, "<body data-root=\"matrix\">", fixed = TRUE)
  expect_equal(count(html, "class=\"couplet\""), 0)
  expect_false(grepl("id=\"mk-mode\"|id=\"mk-pick\"|id=\"mk-map\"|class=\"hint\"", html))
  expect_match(html, "<button type=\"button\" id=\"mk-back\" disabled>", fixed = TRUE)
  expect_match(html, "<a href=\"#matrix\" id=\"mk-restart\">", fixed = TRUE)
  expect_match(html, "<tr data-taxon=\"m-1\"><th scope=\"row\">Silverfish</th>", fixed = TRUE)
  expect_match(html, "2 characters, 4 taxa. ", fixed = TRUE)
  expect_match(exportWizard(NULL, matrix = insectMatrix(), title = "Insects"), "<h1>Insects</h1>", fixed = TRUE)
  f <- withr::local_tempfile(fileext = ".html")
  expect_identical(exportWizard(NULL, f, matrix = insectMatrix()), f)
  expect_true(file.exists(f))
})

test_that("the matrix is checked", {
  m <- insectMatrix()
  expect_error(exportWizard(NULL, matrix = as.matrix(m)), "must be a data frame")
  expect_error(exportWizard(NULL, matrix = m, taxon = "Species"), "must name the column")
  expect_error(exportWizard(NULL, matrix = m["Taxon"]), "no character columns")
  expect_error(exportWizard(NULL, matrix = rbind(m, m[1, ])), "more than once: Silverfish")
  expect_error(exportWizard(NULL, matrix = transform(m, Taxon = c("A", NA, "C", "D"))), "no taxon name")
  expect_error(exportWizard(NULL, matrix = m, characters = data.frame(Name = "Wings")), "column `Character`")
  names(m)[1] <- "Species"
  expect_match(exportWizard(NULL, matrix = m, taxon = "Species"), "<th scope=\"row\">Silverfish</th>", fixed = TRUE)
})

test_that("wizMatrix trims cells, keeps unknowns and orders characters by cost", {
  m <- data.frame(Taxon = c("A", "B"), x = c(" a ", ""), y = factor(c("p/q", "/")), z = c(1, NA))
  mx <- wizMatrix(m, data.frame(Character = c("z", "x"), Cost = c(1, 2)))
  expect_equal(mx$characters, c("z", "x", "y"))          # no cost: last
  expect_equal(mx$cost, c(1, 2, NA))
  expect_equal(unname(mx$cells[, "x"]), c("a", NA))
  expect_equal(unname(mx$cells[, "y"]), c("p/q", NA))
  expect_equal(unname(mx$cells[, "z"]), c("1", NA))
  expect_equal(wizMatrix(m)$characters, c("x", "y", "z"))  # no costs: the matrix's order
})

# ---- offline copy ---------------------------------------------------------------------

test_that("offline = TRUE writes a manifest, a service worker and icons next to the page", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "shark key.html")
  out <- exportWizard(sharks(), f, offline = TRUE)
  expect_equal(as.vector(out), f)
  expect_setequal(list.files(dir), c("shark key.html", "shark key.webmanifest", "shark key-sw.js",
                                     "shark key-icon-192.png", "shark key-icon-512.png"))
  expect_setequal(basename(attr(out, "files")), setdiff(list.files(dir), "shark key.html"))

  html <- paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(html, "<link rel=\"manifest\" href=\"shark%20key.webmanifest\">", fixed = TRUE)
  expect_match(html, "<link rel=\"apple-touch-icon\" href=\"shark%20key-icon-192.png\">", fixed = TRUE)
  expect_match(html, " data-sw=\"shark%20key-sw.js\" data-sw-scope=\"./shark%20key.html\"", fixed = TRUE)
  expect_match(html, "navigator.serviceWorker.register(swFile", fixed = TRUE)

  manifest <- paste(readLines(file.path(dir, "shark key.webmanifest"), warn = FALSE), collapse = "\n")
  expect_match(manifest, "\"name\": \"Key to the families of sharks", fixed = TRUE)
  expect_match(manifest, "\"start_url\": \"./shark%20key.html\"", fixed = TRUE)
  expect_match(manifest, "\"display\": \"standalone\"", fixed = TRUE)
  expect_match(manifest, "{\"src\": \"shark%20key-icon-512.png\", \"sizes\": \"512x512\", \"type\": \"image/png\"", fixed = TRUE)
  skip_if_not_installed("jsonlite")
  parsed <- jsonlite::fromJSON(manifest)
  expect_equal(parsed$icons$sizes, c("192x192", "512x512"))
  expect_equal(parsed$scope, "./shark%20key.html")
})

test_that("the service worker precaches the page, its files and the outside figures", {
  dir <- withr::local_tempdir()
  exportWizard(sharks(), file.path(dir, "sharks.html"), offline = TRUE)
  sw <- paste(readLines(file.path(dir, "sharks-sw.js"), warn = FALSE), collapse = "\n")
  expect_false(grepl("__[A-Z]+__", sw))
  expect_match(sw, "var PRECACHE = [\"sharks.html\", \"sharks.webmanifest\", \"sharks-icon-192.png\", \"sharks-icon-512.png\"];", fixed = TRUE)
  expect_match(sw, "var PAGE = \"sharks.html\";", fixed = TRUE)
  expect_match(sw, "var PREFIX = \"dimoose-sharks-\";", fixed = TRUE)
  external <- regmatches(sw, regexpr("var EXTERNAL = \\[[^]]*\\]", sw))
  expect_match(external, "\"https://www.fishbase.se/images/thumbnails/morphpic/tn_1term1.gif\"", fixed = TRUE)
  expect_equal(count(external, "https://"), length(unique(unlist(strsplit(sharks()$leads$Image, ";")))))

  # the cache is named after the page's content: a changed key gets a new one
  cacheName <- function(file) regmatches(x <- paste(readLines(file, warn = FALSE), collapse = "\n"), regexpr("var CACHE = \"[^\"]+\"", x))
  first <- cacheName(file.path(dir, "sharks-sw.js"))
  exportWizard(sharks(), file.path(dir, "sharks.html"), offline = TRUE)
  expect_identical(cacheName(file.path(dir, "sharks-sw.js")), first)
  exportWizard(sharks(), file.path(dir, "sharks.html"), offline = TRUE, title = "Another title")
  expect_false(identical(cacheName(file.path(dir, "sharks-sw.js")), first))
})

test_that("embedded figures are not listed for the worker; index.html is served as its folder", {
  k <- sharkKey()
  k$meta <- rbind(k$meta, data.frame(key = "image_tn_1term1", value = base64enc::base64encode(charToRaw("GIF89a")), stringsAsFactors = FALSE))
  expect_false("https://www.fishbase.se/images/thumbnails/morphpic/tn_1term1.gif" %in%
                 wizExternalImages(normalizeLeads(k$leads), embeddedImages(k$meta)))
  expect_length(wizExternalImages(normalizeLeads(insectKey()$leads), character()), 0)
  dir <- withr::local_tempdir()
  exportWizard(insectKey(), file.path(dir, "index.html"), offline = TRUE)
  expect_match(paste(readLines(file.path(dir, "index.html"), warn = FALSE), collapse = "\n"), "data-sw=\"index-sw.js\" data-sw-scope=\"./\"", fixed = TRUE)
  expect_match(paste(readLines(file.path(dir, "index.webmanifest"), warn = FALSE), collapse = "\n"), "\"start_url\": \"./\"", fixed = TRUE)
  expect_match(paste(readLines(file.path(dir, "index-sw.js"), warn = FALSE), collapse = "\n"), "var EXTERNAL = [];", fixed = TRUE)
})

test_that("the single-file page is unchanged without offline, and no side files are written", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "sharks.html")
  out <- exportWizard(sharks(), f)
  expect_identical(out, f)
  expect_null(attr(out, "files"))
  expect_equal(list.files(dir), "sharks.html")
  html <- paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_false(grepl("rel=\"manifest\"|data-sw=|id=\"mk-offline\"|apple-touch-icon", html))
  expect_identical(exportWizard(sharks(), f, offline = FALSE), f)
  expect_equal(list.files(dir), "sharks.html")
})

test_that("offline = TRUE without a file warns, returns the plain page and writes nothing", {
  before <- list.files(getwd())
  expect_warning(html <- exportWizard(sharks(), offline = TRUE), "offline = TRUE needs `file`")
  expect_identical(html, exportWizard(sharks()))
  expect_false(grepl("rel=\"manifest\"|data-sw=", html))
  expect_identical(list.files(getwd()), before)
})

test_that("the icons are valid PNGs of the sizes the manifest names", {
  dir <- withr::local_tempdir()
  exportWizard(insectKey(), file.path(dir, "k.html"), offline = TRUE)
  signature <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
  for (size in c(192, 512)) {
    bytes <- readBin(file.path(dir, sprintf("k-icon-%d.png", size)), "raw", 32)
    expect_identical(bytes[1:8], signature)
    expect_identical(rawToChar(bytes[13:16]), "IHDR")
    expect_equal(sum(as.integer(bytes[17:20]) * 256^(3:0)), size)   # width
    expect_equal(sum(as.integer(bytes[21:24]) * 256^(3:0)), size)   # height
  }
})

test_that("the icon drawn without rsvg is a PNG other software reads", {
  expect_identical(wizCrc32(charToRaw("123456789")), as.raw(c(0xcb, 0xf4, 0x39, 0x26)))   # the standard check value
  expect_identical(wizCrc32(charToRaw("IEND")), as.raw(c(0xae, 0x42, 0x60, 0x82)))
  f <- withr::local_tempfile(fileext = ".png")
  wizDrawnIcon(f, 64)
  skip_if_not_installed("png")
  img <- png::readPNG(f)
  expect_equal(dim(img), c(64, 64, 3))
  expect_equal(img[1, 1, ], c(0x1d, 0x6b, 0x58) / 255)             # background
  expect_equal(img[round(64 * 0.27), round(64 * 0.28), ], c(0xf6, 0xf3, 0xeb) / 255)   # a tip of the fork
  expect_lt(mean(img[, , 1] > 0.9), 0.25)                           # mostly background
})

test_that("strings written into the manifest and the worker are escaped", {
  expect_identical(wizJsonString("a \"b\" \\ </script>\n"), "\"a \\\"b\\\" \\\\ \\u003c/script>\\n\"")
  expect_false(identical(wizHash("a"), wizHash("b")))
  expect_identical(wizHash("abc"), wizHash("abc"))
})

# ---- notes on leads -----------------------------------------------------------

test_that("a lead's Note is shown under the lead and in the path of its result", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "Silverfish", "Fly", "Bee"),
    Note = c("", "Body <silvery>, three tails", NA, ""),
    stringsAsFactors = FALSE
  )
  html <- exportWizard(keyFromLeads(leads, "Notes"))
  note <- "<span class=\"note\"><b>Also:</b> Body &lt;silvery&gt;, three tails</span>"
  expect_equal(lengths(regmatches(html, gregexpr(note, html, fixed = TRUE))), 2)
  expect_match(html, paste0("<span class=\"text\">Wings absent</span>", note, "<span class=\"dest\">"), fixed = TRUE)
  expect_match(html, paste0("</a>Wings absent", note, "</li>"), fixed = TRUE)
  # leads without a note, and keys without the column, carry none
  expect_equal(lengths(regmatches(html, gregexpr("<span class=\"note\">", html, fixed = TRUE))), 2)
  leads$Note <- NULL
  expect_no_match(exportWizard(keyFromLeads(leads, "Notes")), "<span class=\"note\">", fixed = TRUE)
})

test_that("the note of a collapsed first couplet is shown under the title", {
  leads <- data.frame(
    Statement = c("1", "1"), Choice = c("a", "b"), Character = c("Two wings", "Four wings"),
    Next = c("-", "-"), Taxon = c("Fly", "Bee"), stringsAsFactors = FALSE
  )
  meta <- data.frame(key = "pruned_note", value = "Wings present & clear", stringsAsFactors = FALSE)
  html <- exportWizard(keyFromLeads(leads, "Winged", meta))
  expect_match(html, "<p class=\"pruned\"><span class=\"note\"><b>All taxa of this key:</b> Wings present &amp; clear</span></p>", fixed = TRUE)
  expect_no_match(exportWizard(keyFromLeads(leads, "Winged")), "class=\"pruned\"", fixed = TRUE)
})

test_that("a key pruned by pruneKey() shows the characters of its collapsed couplets", {
  pruned <- pruneKey(montanaKey(), drop = c("Quercus macrocarpa", "Fraxinus pennsylvanica"))
  notes <- pruned$leads$Note[!is.na(pruned$leads$Note) & nzchar(pruned$leads$Note)]
  expect_gt(length(notes), 0)
  html <- exportWizard(pruned)
  for (n in notes) expect_match(html, paste0("<b>Also:</b> ", htmlEscape(n)), fixed = TRUE)
})

# ---- identify from a photo -------------------------------------------------------

# A folder laid out as exportBrowserModel() writes it
fakePhotoModel <- function(dir, taxa = c("Silverfish", "Fly", "Bee"), encoder = "image_encoder.onnx") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  writeBin(as.numeric(diag(length(taxa))), file.path(dir, "text_embeddings.bin"), size = 4, endian = "little")
  if (!is.na(encoder)) writeBin(as.raw(rep(7, 3000)), file.path(dir, "image_encoder.onnx"))
  labels <- paste0("{\"taxon\": \"", taxa, "\", \"name\": \"", taxa, "\", \"prompt\": \"a photo of ", taxa, ".\"}", collapse = ", ")
  writeLines(sprintf(paste0(
    "{\"format\": \"dimoose-browser-model\", \"version\": 1,\n",
    " \"image_encoder\": {\"file\": \"image_encoder.onnx\", \"url\": null, \"bytes\": 3000, \"precision\": \"int8\", \"input\": \"pixel_values\", \"output\": \"image_embeds\"},\n",
    " \"preprocess\": {\"image_size\": 224, \"resize\": \"shortest\", \"resize_to\": 224, \"interpolation\": \"bicubic\", \"crop\": \"center\", \"rescale\": 0.00392156862745098, \"mean\": [0.5, 0.5, 0.5], \"std\": [0.5, 0.5, 0.5]},\n",
    " \"text_embeddings\": {\"file\": \"text_embeddings.bin\", \"dtype\": \"float32\", \"shape\": [%d, %d]},\n",
    " \"labels\": [%s], \"logit_scale\": 100}"), length(taxa), length(taxa), labels), file.path(dir, "model.json"))
  dir
}
photoKey <- function() {
  keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "Silverfish", "Fly", "Bee"), stringsAsFactors = FALSE
  ), "A tiny key")
}
bodyTag <- function(html) regmatches(html, regexpr("<body[^>]*>", html))

test_that("photoModel copies the model next to the page and names it and the pinned runtime", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  model <- fakePhotoModel(file.path(dir, "src"))
  expect_message(out <- exportWizard(photoKey(), file.path(dir, "site", "my key.html") |> (\(f) { dir.create(dirname(f)); f })(),
                                     photoModel = model),
                 "copied to .*my key_model.*downloads the model \\(0 MB\\) and onnxruntime-web 1\\.31\\.1 \\(15 MB\\), 15 MB in all, after asking")
  copied <- file.path(dir, "site", "my key_model", c("model.json", "text_embeddings.bin", "image_encoder.onnx"))
  expect_true(all(file.exists(copied)))
  expect_setequal(normalizePath(attr(out, "files")), normalizePath(copied))
  expect_equal(unname(tools::md5sum(copied[3])), unname(tools::md5sum(file.path(model, "image_encoder.onnx"))))
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  body <- bodyTag(html)
  expect_match(body, "data-photo-model=\"my%20key_model/\"", fixed = TRUE)
  expect_match(body, "data-photo-runtime=\"https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/\"", fixed = TRUE)
  expect_match(body, "data-photo-runtime-bytes=\"14927386\"", fixed = TRUE)
  # the model is not in the page, and without JavaScript there is no button
  expect_lt(nchar(html), nchar(exportWizard(photoKey())) + 500)
  expect_no_match(html, "<input", fixed = TRUE)
  # exporting again leaves an unchanged encoder alone
  before <- file.mtime(copied[3])
  suppressMessages(exportWizard(photoKey(), out, photoModel = model))
  expect_equal(file.mtime(copied[3]), before)
})

test_that("photoModel accepts the path of model.json and a web address", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  model <- fakePhotoModel(file.path(dir, "src"))
  suppressMessages(out <- exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = file.path(model, "model.json")))
  expect_true(file.exists(file.path(dir, "k_model", "image_encoder.onnx")))

  for (address in c("https://example.org/models/trees", "https://example.org/models/trees/", "https://example.org/models/trees/model.json")) {
    expect_message(html <- exportWizard(photoKey(), photoModel = address), "downloads the model and onnxruntime-web 1\\.31\\.1 \\(15 MB\\), after asking")
    expect_match(bodyTag(html), "data-photo-model=\"https://example.org/models/trees/\"", fixed = TRUE)
  }
  suppressMessages(out <- exportWizard(photoKey(), file.path(dir, "u.html"), photoModel = "https://example.org/m/"))
  expect_false(dir.exists(file.path(dir, "u_model")))
  expect_null(attr(out, "files"))
})

test_that("without photoModel the page names no model", {
  body <- bodyTag(exportWizard(photoKey()))
  expect_no_match(body, "data-photo", fixed = TRUE)
  expect_warning(exportWizard(photoKey(), photoRuntime = "ort/"), "photoRuntime")
})

test_that("photoRuntime replaces the CDN and its size is then not claimed", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  model <- fakePhotoModel(file.path(dir, "src"))
  expect_message(out <- exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = model, photoRuntime = "ort"),
                 "and onnxruntime-web, after asking")
  body <- bodyTag(paste(readLines(out, warn = FALSE), collapse = "\n"))
  expect_match(body, "data-photo-runtime=\"ort/\"", fixed = TRUE)
  expect_no_match(body, "data-photo-runtime-bytes", fixed = TRUE)
})

test_that("a photoModel folder needs a file, and a wrong folder fails clearly", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  model <- fakePhotoModel(file.path(dir, "src"))
  expect_warning(html <- exportWizard(photoKey(), photoModel = model), "needs `file`")
  expect_no_match(bodyTag(html), "data-photo", fixed = TRUE)

  expect_error(exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = file.path(dir, "nowhere")), "exportBrowserModel")
  expect_error(exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = c("a", "b")), "one folder")
  other <- file.path(dir, "other")
  dir.create(other)
  writeLines("{\"format\": \"something else\"}", file.path(other, "model.json"))
  expect_error(exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = other), "not a model written by exportBrowserModel")
  unlink(file.path(model, "image_encoder.onnx"))
  expect_error(exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = model), "lacks image_encoder.onnx")
  expect_false(file.exists(file.path(dir, "k.html")))
})

test_that("a model made for another key is warned about; missing taxa are named", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  expect_warning(suppressMessages(exportWizard(photoKey(), file.path(dir, "a.html"),
                                               photoModel = fakePhotoModel(file.path(dir, "m1"), c("Oak", "Ash")))),
                 "made for another key")
  suppressMessages(expect_message(
    exportWizard(photoKey(), file.path(dir, "b.html"), photoModel = fakePhotoModel(file.path(dir, "m2"), c("Fly", "Bee"))),
    "1 of 3 results of the key are not in `photoModel`.*Silverfish"))
})

test_that("with offline = TRUE the worker is told to keep the model and the runtime", {
  skip_if_not_installed("jsonlite")
  dir <- withr::local_tempdir()
  model <- fakePhotoModel(file.path(dir, "src"))
  expect_message(out <- exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = model, offline = TRUE),
                 "With offline = TRUE the service worker then keeps them \\(15 MB of storage on the reader's device\\)")
  expect_length(attr(out, "files"), 7)
  sw <- paste(readLines(file.path(dir, "k-sw.js"), warn = FALSE), collapse = "\n")
  expect_match(sw, "var KEEP = [\"https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/\", \"k_model/\"];", fixed = TRUE)
  expect_match(sw, "var KEPT = \"dimoose-k-kept-[0-9a-f]+\";")
  # the model is fetched on first use, not when the worker installs
  expect_no_match(regmatches(sw, regexpr("var PRECACHE = [^\n]*", sw)), "model", fixed = TRUE)
  # a model made again gets a new store
  fakePhotoModel(file.path(dir, "src"), c("Silverfish", "Fly", "Bee", "Ant"))
  suppressMessages(exportWizard(photoKey(), file.path(dir, "k.html"), photoModel = model, offline = TRUE))
  sw2 <- paste(readLines(file.path(dir, "k-sw.js"), warn = FALSE), collapse = "\n")
  expect_false(identical(regmatches(sw, regexpr("var KEPT = [^\n]*", sw)), regmatches(sw2, regexpr("var KEPT = [^\n]*", sw2))))
  # without a photo model the worker keeps nothing extra
  exportWizard(photoKey(), file.path(dir, "plain.html"), offline = TRUE)
  expect_match(paste(readLines(file.path(dir, "plain-sw.js"), warn = FALSE), collapse = "\n"), "var KEEP = [];", fixed = TRUE)
})

test_that("the page script has the photo steps and the narrowing hook", {
  js <- paste(readLines(system.file("wizard", "wizard.js", package = "dimoose"), warn = FALSE), collapse = "\n")
  for (piece in c("data-photo-model", "ort.wasm.min.js", "executionProviders: [\"wasm\"]", "narrow: setNarrow",
                  "win.dimoose.photo = api", "capture", "image/*")) {
    expect_match(js, piece, fixed = TRUE)
  }
  # no address of a runtime or model is fixed in the script: R gives them
  expect_no_match(js, "jsdelivr", fixed = TRUE)
})
