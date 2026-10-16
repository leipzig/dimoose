test_that("the montana lead table is a sound key of native trees", {
  m <- dimoose::montana
  expect_named(m, c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image"))
  k <- keyFromLeads(m)
  expect_length(k$validate(), 0)
  taxa <- m$Taxon[m$Next == "-"]
  expect_true(all(grepl("^[A-Z][a-z].* \\([A-Z][a-z]+ [a-z]+\\)$", taxa)))
  expect_false(anyDuplicated(taxa) > 0)
  expect_true(all(c("Quaking aspen (Populus tremuloides)", "Paper birch (Betula papyrifera)") %in% taxa))
  expect_false(any(grepl("Ulmus", taxa)))
  expect_true(all(nzchar(m$Question)))
})

test_that("every montana photo is credited with an allowed license, and vice versa", {
  dir <- system.file("extdata", "montana", package = "dimoose")
  files <- sub("\\.jpg$", "", list.files(dir, pattern = "\\.jpg$"))
  credits <- utils::read.delim(system.file("extdata", "montana", "photos.tsv", package = "dimoose"),
                               colClasses = "character", quote = "", encoding = "UTF-8")
  expect_setequal(files, credits$id)
  expect_true(all(grepl("^(Public domain|CC0|CC BY( |-SA )[0-9.]+)$", credits$license)))
  expect_true(all(nzchar(credits$author)) && all(startsWith(credits$source_url, "https://commons.wikimedia.org/")))
  expect_lt(sum(file.size(file.path(dir, paste0(files, ".jpg")))), 1.5e6)
})

test_that("every montana species has a photo and every Image id exists", {
  m <- dimoose::montana
  dir <- system.file("extdata", "montana", package = "dimoose")
  ids <- unlist(strsplit(m$Image[nzchar(m$Image)], ";", fixed = TRUE))
  expect_true(all(file.exists(file.path(dir, paste0(ids, ".jpg")))))
  expect_true(all(nzchar(m$Image[m$Next == "-"])))
})

test_that("montanaKey embeds its photos and exports a wizard and a diagram", {
  k <- montanaKey()
  expect_s3_class(k, "dimoose")
  expect_length(k$validate(), 0)
  expect_equal(sum(startsWith(k$meta$key, "image_")), length(list.files(system.file("extdata", "montana", package = "dimoose"), pattern = "\\.jpg$")))
  expect_match(exportWizard(k), "data:image/jpeg;base64,", fixed = TRUE)
  svg <- keyDiagram(k)
  expect_equal(lengths(regmatches(svg, gregexpr("class=\"kd-thumb\"", svg))), sum(k$leads$Next == "-"))
})

test_that("both leads of a couplet contrast the same character when sizes overlap", {
  m <- dimoose::montana
  nine <- m$Character[m$Statement == "9"]
  expect_true(all(grepl("beneath", nine)))
})

test_that("every lead of the montana key shows a photo, not only the results", {
  expect_true(all(nzchar(dimoose::montana$Image)))
})
