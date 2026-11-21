writeSheet <- function(lines, dir = withr::local_tempdir(.local_envir = parent.frame())) {
  f <- file.path(dir, "key.csv")
  con <- file(f, "w", encoding = "UTF-8")
  writeLines(lines, con)
  close(con)
  f
}
sheet <- c(
  "Couplet,Question,Description,Goes to,Species",
  "1,Leaf type?,Leaves compound.,2,",
  "1,Leaf type?,Leaves simple.,,Quaking aspen (Populus tremuloides)",
  "2,Leaflets?,\"Leaflets 3–5, coarsely toothed.\",,Box elder (Acer negundo)",
  "2,Leaflets?,Leaflets 5 to 7.,,Green ash (Fraxinus pennsylvanica)"
)

test_that("keyFromSpreadsheet reads a plain sheet and letters the leads", {
  k <- keyFromSpreadsheet(writeSheet(sheet), desc = "Tiny")
  expect_s3_class(k, "dimoose")
  expect_equal(k$desc, "Tiny")
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2"))
  expect_equal(l$Choice, c("a", "b", "a", "b"))
  expect_equal(l$Next, c("2", "-", "-", "-"))
  expect_equal(l$Character[3], "Leaflets 3–5, coarsely toothed.")
  expect_equal(l$Question[1], "Leaf type?")
  expect_length(k$validate(), 0)
})

test_that("column names are matched loosely and dimoose names work too", {
  loose <- sub("^Couplet,Question,Description,Goes to,Species", " couplet ,QUESTION,description,goes_to,Species", sheet)
  expect_equal(keyFromSpreadsheet(writeSheet(loose))$leads$Next, c("2", "-", "-", "-"))
  native <- sub("^Couplet,Question,Description,Goes to,Species", "Statement,Question,Character,Next,Taxon", sheet)
  native[3] <- sub(",,Quaking", ",-,Quaking", native[3])
  expect_equal(keyFromSpreadsheet(writeSheet(native))$leads$Taxon[2], "Quaking aspen (Populus tremuloides)")
})

test_that("an Excel byte-order mark, blank rows and stray spaces are ignored", {
  f <- writeSheet(c(paste0("﻿", sheet[1]), sheet[2:3], ",,,,", paste0(" ", sheet[4], " "), sheet[5]))
  k <- keyFromSpreadsheet(f)
  expect_equal(nrow(k$leads), 4)
  expect_equal(k$leads$Statement[3], "2")
})

test_that("given Choice letters are kept", {
  withChoice <- c("Couplet,Choice,Description,Goes to,Species",
                  "1,x,Leaves compound.,,A (Aa aa)", "1,y,Leaves simple.,,B (Bb bb)")
  expect_equal(keyFromSpreadsheet(writeSheet(withChoice))$leads$Choice, c("x", "y"))
})

test_that("mistakes are reported by spreadsheet row", {
  bad <- sheet; bad[2] <- "1,Leaf type?,Leaves compound.,12,"
  expect_error(keyFromSpreadsheet(writeSheet(bad)), "Row 2 goes to couplet 12, which is not in the sheet")
  bad <- sheet; bad[4] <- "2,Leaflets?,Leaflets 3.,,"
  expect_error(keyFromSpreadsheet(writeSheet(bad)), "Row 4 has neither")
  bad <- sheet; bad[5] <- "2,Leaflets?,Leaflets 5.,1,Green ash (Fraxinus pennsylvanica)"
  expect_error(keyFromSpreadsheet(writeSheet(bad)), "Row 5 has both")
  expect_error(keyFromSpreadsheet(writeSheet(sub("Description", "Words", sheet))), "Description")
  expect_error(keyFromSpreadsheet(file.path(tempdir(), "no-such-file.csv")), "not found")
})

test_that("photos named in the sheet are embedded from the folder", {
  dir <- withr::local_tempdir()
  pics <- list.files(system.file("extdata", "montana", package = "dimoose"), pattern = "\\.jpg$", full.names = TRUE)[1:2]
  file.copy(pics, file.path(dir, c("one.jpg", "two.jpg")))
  withPhoto <- c(paste0(sheet[1], ",Photo"), paste0(sheet[2], ","), paste0(sheet[3], ",one.jpg"),
                 paste0(sheet[4], ",\"one, two\""), paste0(sheet[5], ","))
  k <- keyFromSpreadsheet(writeSheet(withPhoto, dir))
  expect_equal(k$leads$Image, c("", "one", "one;two", ""))
  expect_setequal(k$meta$key[startsWith(k$meta$key, "image_")], c("image_one", "image_two"))
  expect_equal(lengths(regmatches(keyDiagram(k), gregexpr("class=\"kd-thumb\"", keyDiagram(k)))), 2)

  missingPhoto <- withPhoto; missingPhoto[3] <- paste0(sheet[3], ",three.jpg")
  expect_error(keyFromSpreadsheet(writeSheet(missingPhoto, dir)), "Row 3: photo three.jpg not found")
  other <- withr::local_tempdir()
  expect_error(keyFromSpreadsheet(writeSheet(withPhoto, other)), "not found")
  expect_equal(keyFromSpreadsheet(writeSheet(withPhoto, other), photos = dir)$leads$Image[3], "one;two")
})

test_that("the bundled Montana template is a spreadsheet for keyFromSpreadsheet", {
  csv <- system.file("extdata", "montana", "montana-key.csv", package = "dimoose")
  expect_true(file.exists(csv))
  expect_equal(names(utils::read.csv(csv, check.names = FALSE, nrows = 1)),
               c("Couplet", "Choice", "Question", "Description", "Goes to", "Species", "Photo"))
  k <- keyFromSpreadsheet(csv)
  m <- dimoose::montana
  cols <- c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image")
  expect_equal(k$leads[cols], m[cols], ignore_attr = TRUE)
})

test_that("a CSV saved by Windows Excel (Windows-1252) is read correctly", {
  f <- file.path(withr::local_tempdir(), "key.csv")
  lines <- c(sheet[1], "1,Leaf type?,Leaves compound.,2,", "1,Leaf type?,Leaves simple.,,A (Aa aa)",
             "2,Leaflets?,Leaflets 3\x965.,,B (Bb bb)", "2,Leaflets?,Leaflets 5 to 7 \xe9.,,C (Cc cc)")
  writeBin(charToRaw(paste0(paste(lines, collapse = "\r\n"), "\r\n")), f)
  l <- keyFromSpreadsheet(f)$leads
  expect_equal(l$Character[3:4], c("Leaflets 3–5.", "Leaflets 5 to 7 é."))
  expect_equal(l$Taxon[4], "C (Cc cc)")
})

test_that("a comma inside an unquoted cell is reported by row", {
  extra <- sheet; extra[4] <- "2,Leaflets?,Leaflets 3, coarsely toothed.,,Box elder (Acer negundo)"
  expect_error(keyFromSpreadsheet(writeSheet(extra)), "Row 4 has more cells than the header")
  trailing <- c(paste0(sheet[1], ",,"), paste0(sheet[2:5], ",,"))
  trailing[4] <- "2,Leaflets?,Leaflets 3,,Yew, a conifer,,"
  expect_error(keyFromSpreadsheet(writeSheet(trailing)), "Row 4 has more cells than the header")
})

test_that("rows are numbered as in the spreadsheet even after blank lines", {
  gappy <- c(sheet[1:3], "", "", sheet[4], "2,Leaflets?,Leaflets 5.,9,")
  expect_error(keyFromSpreadsheet(writeSheet(gappy)), "Row 7 goes to couplet 9")
})

test_that("blank Choice letters are filled and repeated ones are refused", {
  partial <- c("Couplet,Choice,Description,Goes to,Species",
               "1,a,Leaves compound.,2,", "1,,Leaves simple.,,A (Aa aa)",
               "2,,Leaflets 3.,,B (Bb bb)", "2,b,Leaflets 5.,,C (Cc cc)")
  expect_equal(keyFromSpreadsheet(writeSheet(partial))$leads$Choice, c("a", "b", "a", "b"))
  twice <- partial; twice[3] <- "1,a,Leaves simple.,,A (Aa aa)"
  expect_error(keyFromSpreadsheet(writeSheet(twice)), "Rows 2 and 3 are both lead 1a")
})

test_that("couplet M lead 11 and couplet M1 lead 1 are not taken for the same lead", {
  # as in the full PhyloTree key, where both would be written "M11"
  two <- c("Couplet,Choice,Description,Goes to,Species",
           "M,11,215G,M1,", "M,2,318C,,M2", "M1,1,813G,,M1a", "M1,2,6671C,,M1b")
  l <- keyFromSpreadsheet(writeSheet(two))$leads
  expect_equal(paste(l$Statement, l$Choice), c("M 11", "M 2", "M1 1", "M1 2"))
  twice <- c(two, "M1,1,again,,M1c")
  expect_error(keyFromSpreadsheet(writeSheet(twice)), "Rows 4 and 6 are both lead M11")
})

test_that("a couplet with more than 26 leads is lettered on past z", {
  many <- c("Couplet,Description,Goes to,Species", sprintf("1,State %d,,Taxon %d", 1:30, 1:30))
  l <- keyFromSpreadsheet(writeSheet(many))$leads
  expect_equal(l$Choice, c(letters, "aa", "ab", "ac", "ad"))
  expect_equal(qualChoiceLetters(2), letters)
  expect_equal(qualChoiceLetters(703)[c(27, 702, 703)], c("aa", "zz", "aaa"))
  # letters already given are skipped
  some <- c("Couplet,Choice,Description,Goes to,Species", "1,aa,x,,A", sprintf("1,,State %d,,Taxon %d", 1:27, 1:27))
  expect_equal(keyFromSpreadsheet(writeSheet(some))$leads$Choice, c("aa", letters, "ab"))
})

test_that("a sheet Excel saved with semicolons between the cells is read", {
  semi <- c("Couplet;Question;Description;Goes to;Species",
            "1;Leaf type?;Leaves compound.;2;",
            "1;Leaf type?;Leaves simple, toothed.;;Quaking aspen (Populus tremuloides)",
            "2;Leaflets?;\"Leaflets 3; coarsely toothed.\";;Box elder (Acer negundo)",
            "2;Leaflets?;Leaflets 5 to 7.;;Green ash (Fraxinus pennsylvanica)")
  l <- keyFromSpreadsheet(writeSheet(semi))$leads
  expect_equal(l$Next, c("2", "-", "-", "-"))
  expect_equal(l$Character[2:3], c("Leaves simple, toothed.", "Leaflets 3; coarsely toothed."))
  expect_equal(l$Taxon[4], "Green ash (Fraxinus pennsylvanica)")
  bad <- semi; bad[4] <- "2;Leaflets?;Leaflets 3; coarsely toothed.;;Box elder (Acer negundo)"
  expect_error(keyFromSpreadsheet(writeSheet(bad)), "Row 4 has more cells than the header row; put quotes around a cell that contains a semicolon")
  # a comma-separated sheet with a semicolon in its header is still comma-separated
  comma <- sub("Question", "\"Question; or hint\"", sheet)
  expect_equal(nrow(keyFromSpreadsheet(writeSheet(comma))$leads), 4)
})

test_that("reading a sheet leaves no connection open", {
  before <- nrow(showConnections())
  for (i in 1:3) keyFromSpreadsheet(writeSheet(sheet))
  expect_equal(nrow(showConnections()), before)
})

test_that("Note and Label columns are read when the sheet has them", {
  noted <- c("Couplet,Description,Goes to,Species,Note,Label",
             "1,Leaves compound.,,A (Aa aa),Was couplet 3.,first", "1,Leaves simple.,,B (Bb bb),,")
  l <- keyFromSpreadsheet(writeSheet(noted))$leads
  expect_equal(l$Note, c("Was couplet 3.", ""))
  expect_equal(l$Label, c("first", ""))
  expect_false(any(c("Note", "Label") %in% names(keyFromSpreadsheet(writeSheet(sheet))$leads)))
})

# ---- keyToSpreadsheet --------------------------------------------------------

roundTrip <- function(key, dir = withr::local_tempdir(.local_envir = parent.frame()), ...) {
  keyFromSpreadsheet(suppressMessages(keyToSpreadsheet(key, file.path(dir, "key.csv"))), ...)
}
core <- c("Statement", "Choice", "Character", "Next", "Taxon")

test_that("keyToSpreadsheet writes the template's columns and returns the file", {
  f <- file.path(withr::local_tempdir(), "sub", "key.csv")
  expect_invisible(suppressMessages(out <- keyToSpreadsheet(arachnidaKey(), f)))
  expect_equal(out, f)
  written <- utils::read.csv(f, check.names = FALSE, colClasses = "character", fileEncoding = "UTF-8-BOM")
  template <- system.file("extdata", "montana", "montana-key.csv", package = "dimoose")
  expect_equal(names(written), names(utils::read.csv(template, check.names = FALSE, nrows = 1)))
  expect_equal(nrow(written), nrow(arachnidaKey()$leads))
  expect_equal(written$`Goes to`[1:3], c("2", "3", ""))
  expect_error(keyToSpreadsheet(arachnidaKey()$leads, f), "dimoose object")
  expect_error(keyToSpreadsheet(dimoose$new(NULL), f), "no leads")
})

test_that("the Montana key survives the round trip, photos included", {
  dir <- withr::local_tempdir()
  m <- montanaKey()
  k <- roundTrip(m, dir)
  expect_equal(k$leads[c(core, "Question", "Image")], m$leads[c(core, "Question", "Image")], ignore_attr = TRUE)
  photos <- m$meta[startsWith(m$meta$key, "image_"), ]
  expect_setequal(sub("\\.jpg$", "", list.files(dir, pattern = "\\.jpg$")), sub("^image_", "", photos$key))
  back <- k$meta[startsWith(k$meta$key, "image_"), ]
  expect_equal(back$value[match(photos$key, back$key)], photos$value)
  expect_length(k$validate(), 0)
})

test_that("photos go to the folder asked for and existing files are kept", {
  dir <- withr::local_tempdir()
  pics <- file.path(dir, "pics")
  f <- suppressMessages(keyToSpreadsheet(montanaKey(), file.path(dir, "key.csv"), photos = pics))
  expect_equal(list.files(dir), c("key.csv", "pics"))
  expect_length(list.files(pics), 14)
  expect_error(keyFromSpreadsheet(f), "not found")
  expect_equal(keyFromSpreadsheet(f, photos = pics)$leads$Image, montanaKey()$leads$Image)

  # same bytes: nothing to say; different bytes: the file there is kept
  expect_no_message(keyToSpreadsheet(montanaKey(), f, photos = pics))
  mine <- file.path(pics, "acer_negundo_leaf.jpg")
  file.copy(file.path(pics, "acer_glabrum_leaf.jpg"), mine, overwrite = TRUE)
  before <- unname(tools::md5sum(mine))
  expect_message(keyToSpreadsheet(montanaKey(), f, photos = pics), "Kept the acer_negundo_leaf.jpg already in")
  expect_equal(unname(tools::md5sum(mine)), before)
})

test_that("the shark key survives the round trip, with its pictures as web addresses", {
  s <- sharkKey()
  f <- file.path(withr::local_tempdir(), "key.csv")
  expect_message(keyToSpreadsheet(s, f), "Not written to the spreadsheet: the leads' ImageLink, TaxonUrl columns")
  k <- keyFromSpreadsheet(f)
  expect_equal(k$leads[c(core, "Image")], s$leads[c(core, "Image")], ignore_attr = TRUE)
  expect_match(k$leads$Image[1], "^https://www.fishbase.se/")
  expect_equal(list.files(dirname(f)), "key.csv")
  expect_equal(k$summary()[-1], s$summary()[-1])
})

test_that("the Arachnida key and a generated key survive the round trip", {
  a <- arachnidaKey()
  expect_message(k <- keyFromSpreadsheet(keyToSpreadsheet(a, file.path(withr::local_tempdir(), "a.csv"))), "Page")
  expect_equal(k$leads[core], a$leads[core], ignore_attr = TRUE)
  expect_true(all(k$leads$Question == "") && all(k$leads$Image == ""))

  v <- vibrioKey()
  expect_equal(roundTrip(v)$leads[core], v$leads[core], ignore_attr = TRUE)

  d <- data.frame(taxon = factor(c("A", "B", "C")), wings = factor(c("+", "-", "-")), spots = factor(c("-", "+", "-")))
  fit <- generateTree(d, "taxon", params = list(control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0)))
  g <- keyFromRpart(fit, "Three taxa")
  expect_equal(roundTrip(g)$leads[core], g$leads[core], ignore_attr = TRUE)
  expect_equal(roundTrip(g)$toNewick(), g$toNewick())
})

test_that("accents, commas, quotes, hashes and odd labels survive the round trip", {
  leads <- data.frame(
    Statement = c("I", "I", "I", "II", "II"), Choice = c("a", "b", "c", "x", "y"),
    Character = c("Feuilles oppos\u00e9es, 3\u20135 folioles", "Says \"hairy\", but is not", "Scales # 4, or more",
                  "\u8449\u306f\u5bfe\u751f", "It's 5' tall; rarely more"),
    Next = c("II", "-", "-", "-", "-"),
    Taxon = c("", "\u00c9rable \u00e0 sucre (Acer saccharum)", "Smith's \"oak\", so called", "\u30ab\u30a8\u30c7", "Ash, green"),
    Question = c("Feuilles, ou \"leaves\"?", "Feuilles, ou \"leaves\"?", "Feuilles, ou \"leaves\"?", "", ""),
    stringsAsFactors = FALSE
  )
  key <- keyFromLeads(leads, "Odd cells")
  f <- keyToSpreadsheet(key, file.path(withr::local_tempdir(), "odd.csv"))
  expect_true(validUTF8(rawToChar(readBin(f, "raw", file.size(f)))))
  k <- keyFromSpreadsheet(f)
  expect_equal(k$leads[c(core, "Question")], leads[c(core, "Question")], ignore_attr = TRUE)
  expect_equal(Encoding(k$leads$Taxon[2]), "UTF-8")
})

test_that("a photo the key does not hold is left out with a warning", {
  leads <- montanaKey()$leads
  leads$Image[1] <- "no_such_photo"
  key <- keyFromLeads(leads, meta = montanaKey()$meta)
  dir <- withr::local_tempdir()
  expect_warning(f <- suppressMessages(keyToSpreadsheet(key, file.path(dir, "key.csv"))), "no_such_photo")
  expect_equal(keyFromSpreadsheet(f)$leads$Image[1], "")
})

test_that("web addresses in the Photo column are kept beside photo files", {
  dir <- withr::local_tempdir()
  pic <- list.files(system.file("extdata", "montana", package = "dimoose"), pattern = "\\.jpg$", full.names = TRUE)[1]
  file.copy(pic, file.path(dir, "one.jpg"))
  withPhoto <- c(paste0(sheet[1], ",Photo"), paste0(sheet[2], ",https://example.org/a.gif"),
                 paste0(sheet[3], ",\"one; https://example.org/b,c.gif\""), paste0(sheet[4], ","), paste0(sheet[5], ","))
  k <- keyFromSpreadsheet(writeSheet(withPhoto, dir))
  expect_equal(k$leads$Image[1:2], c("https://example.org/a.gif", "one;https://example.org/b,c.gif"))
  expect_equal(k$meta$key, "image_one")
  expect_equal(roundTrip(k)$leads$Image, k$leads$Image)
})

test_that("the file starts with a byte-order mark for Excel unless told otherwise", {
  dir <- withr::local_tempdir()
  key <- keyFromLeads(data.frame(Statement = "1", Choice = c("a", "b"), Character = c("Feuilles oppos\u00e9es", "\u8449"),
                                 Next = "-", Taxon = c("\u00c9rable", "\u30ab\u30a8\u30c7"), stringsAsFactors = FALSE))
  f <- keyToSpreadsheet(key, file.path(dir, "bom.csv"))
  expect_equal(readBin(f, "raw", 4), as.raw(c(0xef, 0xbb, 0xbf, 0x22)))
  g <- keyToSpreadsheet(key, file.path(dir, "plain.csv"), bom = FALSE)
  expect_equal(readBin(g, "raw", 1), as.raw(0x22))
  expect_equal(file.size(f), file.size(g) + 3)
  for (path in c(f, g)) {
    l <- keyFromSpreadsheet(path)$leads
    expect_equal(l$Statement, c("1", "1"))
    expect_equal(l$Character, key$leads$Character)
    expect_equal(l$Taxon, key$leads$Taxon)
  }
  # what Excel does with it: same cells, CRLF line ends, Windows-1252 when saved as plain CSV
  excel <- c("Couplet,Choice,Question,Description,Goes to,Species,Photo", "1,a,,Feuilles oppos\xe9es,,\xc9rable,",
             "1,b,,Feuilles altern\xe9es,,Ch\xeane,")
  h <- file.path(dir, "excel.csv")
  writeBin(charToRaw(paste0(paste(excel, collapse = "\r\n"), "\r\n")), h)
  expect_equal(keyFromSpreadsheet(h)$leads$Taxon, c("\u00c9rable", "Ch\u00eane"))
})

test_that("every example key, a matrix key and a pruned key survive the round trip", {
  keys <- list(vibrioKey("missing"), keyFromMatrix(vibrioMatrix()), phylotreeKey("H2a"),
               pruneKey(montanaKey(), drop = c("Acer negundo", "Bur oak (Quercus macrocarpa)"), renumber = TRUE))
  for (key in keys) {
    k <- roundTrip(key)
    expect_equal(k$leads[core], normalizeLeads(key$leads)[core], ignore_attr = TRUE)
    expect_equal(k$summary()[-1], key$summary()[-1])
    # and writing what was read gives the same file
    dir <- withr::local_tempdir()
    first <- suppressMessages(keyToSpreadsheet(key, file.path(dir, "one.csv")))
    second <- suppressMessages(keyToSpreadsheet(keyFromSpreadsheet(first), file.path(dir, "two.csv")))
    expect_equal(readLines(second), readLines(first))
  }
})

test_that("the notes of a pruned key and the labels of a PhyloTree key are written and read back", {
  p <- pruneKey(montanaKey(), keep = "Populus")
  expect_true(any(nzchar(p$leads$Note)))
  f <- file.path(withr::local_tempdir(), "pruned.csv")
  expect_no_message(keyToSpreadsheet(p, f))
  expect_equal(names(utils::read.csv(f, check.names = FALSE, fileEncoding = "UTF-8-BOM")),
               c("Couplet", "Choice", "Question", "Description", "Goes to", "Species", "Photo", "Note"))
  k <- keyFromSpreadsheet(f)
  expect_equal(k$leads$Note, p$leads$Note)
  expect_equal(k$leads[c(core, "Image")], p$leads[c(core, "Image")], ignore_attr = TRUE)

  h <- phylotreeKey("H2a")
  expect_no_message(g <- keyToSpreadsheet(h, file.path(withr::local_tempdir(), "h2a.csv")))
  back <- keyFromSpreadsheet(g)
  expect_equal(back$leads$Label, h$leads$Label)
  expect_equal(leadLabels(normalizeLeads(back$leads)), leadLabels(normalizeLeads(h$leads)))
})

test_that("the full PhyloTree key survives the round trip", {
  skip_on_cran()
  h <- phylotreeKey()
  k <- roundTrip(h)
  expect_equal(k$leads[c(core, "Label")], h$leads[c(core, "Label")], ignore_attr = TRUE)
})

test_that("line breaks, tabs and cells a spreadsheet might take for something else survive", {
  leads <- data.frame(
    Statement = c("01", "01", "02", "02"), Choice = c("a", "b", "a", "b"),
    Character = c("Leaves compound,\nwith 3 leaflets", "=SUM(A1)", "tab\there", "1e5"),
    Next = c("02", "-", "-", "-"), Taxon = c("", "Two\nlines", "NA", "TRUE"),
    Question = c("One\n\"quoted\" line?", "One\n\"quoted\" line?", "", ""), stringsAsFactors = FALSE
  )
  k <- roundTrip(keyFromLeads(leads))
  expect_equal(k$leads[c(core, "Question")], leads[c(core, "Question")], ignore_attr = TRUE)
  # a Windows line break inside a cell comes back as a line feed
  leads$Character[1] <- "Leaves compound,\r\nwith 3 leaflets"
  expect_equal(roundTrip(keyFromLeads(leads))$leads$Character[1], "Leaves compound,\nwith 3 leaflets")
})

test_that("couplets with names rather than numbers survive the round trip", {
  leads <- data.frame(
    Statement = c("Start", "Start", "Leaf type", "Leaf type", "leaf type", "leaf type"),
    Choice = c("i", "ii", "1", "11", "x", "y"), Character = paste("lead", 1:6),
    Next = c("Leaf type", "leaf type", "-", "-", "-", "-"), Taxon = c("", "", "A", "B", "C", "D"), stringsAsFactors = FALSE
  )
  k <- roundTrip(keyFromLeads(leads))
  expect_equal(k$leads[core], leads[core], ignore_attr = TRUE)
  expect_length(k$validate(), 0)
})

test_that("photo ids come back as they were", {
  pics <- list.files(system.file("extdata", "montana", package = "dimoose"), pattern = "\\.jpg$", full.names = TRUE)[1:4]
  ids <- c("leaf one (a)", "x.y", "bark_2", "Twig-3 [winter]")
  leads <- data.frame(Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"), Character = "c",
                      Next = c("2", "-", "-", "-"), Taxon = c("", "A", "B", "C"),
                      Image = c("leaf one (a)", "x.y;bark_2", "", "Twig-3 [winter];x.y"), stringsAsFactors = FALSE)
  key <- keyFromLeads(leads, meta = imageMeta(pics, ids))
  dir <- withr::local_tempdir()
  expect_no_message(f <- keyToSpreadsheet(key, file.path(dir, "key.csv")))
  expect_setequal(list.files(dir), c("key.csv", "leaf one (a).jpg", "x.y.jpg", "bark_2.jpg", "Twig-3 [winter].jpg"))
  k <- keyFromSpreadsheet(f)
  expect_equal(k$leads$Image, leads$Image)
  expect_equal(embeddedImages(k$meta)[ids], embeddedImages(key$meta)[ids])
})

test_that("a photo id that cannot be a file name is changed, and says so", {
  pics <- list.files(system.file("extdata", "montana", package = "dimoose"), pattern = "\\.jpg$", full.names = TRUE)[1:4]
  ids <- c("a/b", "a_b", "Leaf", "leaf")
  leads <- data.frame(Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"), Character = "c",
                      Next = c("2", "-", "-", "-"), Taxon = c("", "A", "B", "C"), Image = ids, stringsAsFactors = FALSE)
  key <- keyFromLeads(leads, meta = imageMeta(pics, ids))
  dir <- withr::local_tempdir()
  expect_message(f <- keyToSpreadsheet(key, file.path(dir, "key.csv")),
                 "Photo ids that cannot be file names were changed: a/b is now a_b, a_b is now a_b_2, leaf is now leaf_2")
  expect_setequal(list.files(dir), c("key.csv", "a_b.jpg", "a_b_2.jpg", "Leaf.jpg", "leaf_2.jpg"))
  k <- keyFromSpreadsheet(f)
  expect_equal(k$leads$Image, c("a_b", "a_b_2", "Leaf", "leaf_2"))
  # each lead still has its own photo, also where file names differ only by capitals
  expect_equal(unname(embeddedImages(k$meta)[k$leads$Image]), unname(embeddedImages(key$meta)[ids]))
  # from then on the ids stay as they are
  expect_no_message(g <- keyToSpreadsheet(k, file.path(withr::local_tempdir(), "again.csv")))
  expect_equal(keyFromSpreadsheet(g)$leads$Image, k$leads$Image)
  expect_equal(qualPhotoFile("a:b*c?", embeddedImages(key$meta)[[1]], withr::local_tempdir()), "a_b_c_.jpg")
  expect_equal(qualPhotoFile("..", embeddedImages(key$meta)[[1]], withr::local_tempdir()), "photo.jpg")
})
