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
