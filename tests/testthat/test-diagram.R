count <- function(svg, cls) lengths(regmatches(svg, gregexpr(paste0("class=\"", cls, "\""), svg)))
tiny <- function() data.frame(
  Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
  Character = c("Leaves compound", "Leaves simple & small", "Leaflets 3–5", "Leaflets <9>"),
  Next = c("2", "-", "-", "-"),
  Taxon = c("", "Quaking aspen (Populus tremuloides)", "Box elder (Acer negundo)", "Green ash (Fraxinus pennsylvanica)"),
  Question = c("Leaf type?", "Leaf type?", "Leaflets?", "Leaflets?"), stringsAsFactors = FALSE)

test_that("keyDiagram draws one box per couplet, lead and result", {
  svg <- keyDiagram(keyFromLeads(tiny(), "Tiny"))
  expect_match(svg, "^<svg")
  expect_equal(count(svg, "kd-question"), 2)
  expect_equal(count(svg, "kd-lead"), 4)
  expect_equal(count(svg, "kd-taxon"), 3)
  expect_match(svg, "Leaf type?", fixed = TRUE)
  expect_match(svg, "1a.", fixed = TRUE)
  expect_match(svg, "<title>Tiny</title>|>Tiny<", perl = TRUE)
})

test_that("keyDiagram escapes text and italicises the scientific name", {
  svg <- keyDiagram(keyFromLeads(tiny()))
  expect_match(svg, "simple &amp; small", fixed = TRUE)
  expect_match(svg, "&lt;9&gt;", fixed = TRUE)
  expect_false(grepl("<9>", svg, fixed = TRUE))
  expect_match(svg, "font-style=\"italic\"[^>]*>Populus tremuloides<", perl = TRUE)
})

test_that("keyDiagram writes UTF-8 to file and returns the SVG invisibly", {
  f <- withr::local_tempfile(fileext = ".svg")
  expect_invisible(out <- keyDiagram(keyFromLeads(tiny()), f))
  written <- paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_true(startsWith(written, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
  expect_match(written, "Leaflets 3–5", fixed = TRUE)
  expect_true(grepl(sub("\n$", "", out), written, fixed = TRUE))
  expect_true(startsWith(out, "<svg"))
})

test_that("a couplet reached twice is drawn once with a dashed link", {
  shared <- tiny()
  shared <- rbind(shared, data.frame(Statement = "1", Choice = "c", Character = "Leaves odd",
    Next = "2", Taxon = "", Question = "Leaf type?", stringsAsFactors = FALSE))
  svg <- keyDiagram(keyFromLeads(shared))
  expect_equal(count(svg, "kd-question"), 2)
  expect_equal(count(svg, "kd-lead"), 5)
  expect_equal(count(svg, "kd-shared"), 1)
})

test_that("a result reached from two couplets gets a box at each", {
  k <- arachnidaKey()
  svg <- keyDiagram(k)
  expect_equal(count(svg, "kd-question"), length(unique(k$leads$Statement)))
  expect_equal(count(svg, "kd-taxon"), sum(k$leads$Next == "-"))
  expect_equal(count(svg, "kd-shared"), 0)
})

test_that("keyDiagram copes with polytomies, broken keys and large keys", {
  poly <- data.frame(Statement = "1", Choice = c("a", "b", "c"), Character = c("x", "y", "z"),
                     Next = "-", Taxon = c("A", "B", "C"), stringsAsFactors = FALSE)
  svg <- keyDiagram(keyFromLeads(poly))
  expect_equal(count(svg, "kd-lead"), 3)
  m <- regmatches(svg, gregexpr("<rect class=\"kd-lead\" x=\"([0-9.]+)\" y=\"[0-9.]+\" width=\"([0-9.]+)\"", svg))[[1]]
  x <- as.numeric(sub(".* x=\"([0-9.]+)\".*", "\\1", m)); w <- as.numeric(sub(".*width=\"([0-9.]+)\".*", "\\1", m))
  expect_true(all(diff(sort(x)) >= w[1]))
  broken <- tiny(); broken$Next[2] <- "9"
  expect_no_error(keyDiagram(keyFromLeads(broken)))
  cyc <- tiny(); cyc$Next[3] <- "1"; cyc$Taxon[3] <- ""
  expect_no_error(keyDiagram(dimoose$new(NULL, leads = cyc)))
  t0 <- Sys.time(); big <- keyDiagram(phylotreeKey(maxDepth = 3))
  expect_lt(as.numeric(Sys.time() - t0, units = "secs"), 10)
  expect_gt(as.numeric(sub(".*width=\"([0-9.]+)\".*", "\\1", substr(big, 1, 300))), 1000)
})

test_that("thumbnails come from embedded photos and only when asked", {
  png <- system.file("extdata", "pics", "banana", package = "dimoose")
  path <- list.files(png, full.names = TRUE)[1]
  leads <- tiny(); leads$Image <- c("", "pic", "nosuchid", "")
  k <- keyFromLeads(leads, meta = imageMeta(path, "pic"))
  expect_equal(count(keyDiagram(k), "kd-thumb"), 1)
  expect_equal(count(keyDiagram(k, images = FALSE), "kd-thumb"), 0)
  expect_equal(count(keyDiagram(keyFromLeads(tiny())), "kd-thumb"), 0)
})

test_that("keyDiagram works on every example key", {
  for (k in list(sharkKey(), arachnidaKey(), vibrioKey())) expect_match(keyDiagram(k), "</svg>\n?$")
  expect_error(keyDiagram(list()), "dimoose")
})

test_that("keyDiagram writes PNG and PDF through rsvg and still returns the SVG", {
  skip_if_not_installed("rsvg")
  k <- keyFromLeads(tiny(), "Tiny")
  png <- withr::local_tempfile(fileext = ".png")
  pdf <- withr::local_tempfile(fileext = ".PDF")
  expect_invisible(out <- keyDiagram(k, png))
  expect_true(startsWith(out, "<svg"))
  expect_identical(readBin(png, "raw", 4), as.raw(c(0x89, 0x50, 0x4e, 0x47)))
  keyDiagram(k, pdf)
  expect_identical(rawToChar(readBin(pdf, "raw", 4)), "%PDF")
})

test_that("PNG without rsvg, or an unknown extension, explains what to do", {
  k <- keyFromLeads(tiny())
  local_mocked_bindings(canUse = function(pkg) pkg != "rsvg")
  expect_error(keyDiagram(k, withr::local_tempfile(fileext = ".png")), "install.packages\\(\"rsvg\"\\)")
  expect_error(keyDiagram(k, withr::local_tempfile(fileext = ".gif")), "\\.svg, \\.png or \\.pdf")
})

test_that("thumbnails are shrunk with magick, and embedded as they are without it", {
  skip_if_not_installed("magick")
  k <- montanaKey()
  small <- keyDiagram(k)
  expect_lt(nchar(small), 250000)
  thumbs <- regmatches(small, gregexpr("href=\"data:image/jpeg;base64,[^\"]+\"", small))[[1]]
  expect_length(thumbs, sum(k$leads$Next == "-"))
  img <- magick::image_read(base64enc::base64decode(sub("^href=\"data:image/jpeg;base64,(.*)\"$", "\\1", thumbs[1])))
  expect_lte(max(unlist(magick::image_info(img)[c("width", "height")])), 112)
  local_mocked_bindings(canUse = function(pkg) pkg != "magick")
  expect_gt(nchar(keyDiagram(k)), 1e6)
})

test_that("only real scientific names are set in italics", {
  odd <- tiny()
  odd$Taxon <- c("", "Willows (several species)", "Box elder (Acer negundo)", "Shouting (ACER NEGUNDO)")
  check <- function(svg) {
    expect_match(svg, "font-style=\"italic\"[^>]*>Acer negundo<", perl = TRUE)
    expect_false(grepl("italic\"[^>]*>several species<", svg, perl = TRUE))
    expect_false(grepl("italic\"[^>]*>ACER NEGUNDO<", svg, perl = TRUE))
    expect_match(svg, ">Willows \\(several species\\)<", perl = TRUE)
  }
  local({
    local_mocked_bindings(canUse = function(pkg) pkg != "rgnparser")
    check(keyDiagram(keyFromLeads(odd)))
  })
  skip_if_not_installed("rgnparser")
  skip_if(!nzchar(Sys.which("gnparser")), "gnparser not installed")
  check(keyDiagram(keyFromLeads(odd)))
})
