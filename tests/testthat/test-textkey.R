textKeyFile <- function(name) {
  system.file("extdata", "textkeys", name, package = "dimoose")
}

# Couplet, choice and destination of every lead, as "1a>2"
shape <- function(p) {
  leads <- if (inherits(p, "dimoose")) p$leads else p$leads
  paste0(leads$Statement, leads$Choice, ">", ifelse(leads$Next == "-", leads$Taxon, leads$Next))
}

serious <- function(p) p$problems[p$problems$Kind == "problem", , drop = FALSE]
repairs <- function(p) p$problems[p$problems$Kind == "repair", , drop = FALSE]

insects <- c(
  "1a>2", "1b>Apterygota", "2a>Diptera", "2b>3", "3a>Coleoptera", "3b>Hymenoptera"
)

test_that("a bracketed 1a/1b key with dot leaders becomes a valid key", {
  key <- expect_silent(keyFromText(textKeyFile("trees-bracketed.txt")))
  expect_s3_class(key, "dimoose")
  expect_identical(key$desc, "Key to the Broadleaf Trees of the Cottonwood Bottoms")
  expect_length(key$validate(), 0)
  s <- key$summary()
  expect_equal(c(s$couplets, s$leads, s$taxa), c(8, 16, 9))
  leads <- key$leads
  expect_identical(leads$Next[leads$Statement == "1"], c("2", "4"))
  expect_identical(leads$Taxon[leads$Statement == "6"], c("Betula papyrifera", "Betula occidentalis"))
  expect_equal(nrow(serious(list(problems = attr(key, "problems")))), 0)
})

test_that("authority, common name and page are split from the taxon", {
  leads <- parseTextKey(textKeyFile("trees-bracketed.txt"))$leads
  maple <- leads[leads$Taxon == "Acer glabrum", ]
  expect_identical(maple$Authority, "Torr.")
  expect_identical(maple$CommonName, "Rocky Mountain maple")
  ash <- leads[leads$Taxon == "Fraxinus pennsylvanica", ]
  expect_identical(ash$Authority, "Marshall")
  expect_identical(ash$Page, "118")
  willow <- leads[leads$Taxon == "Salix", ]
  expect_identical(willow$Page, "131")
  # A destination wrapped over two lines, with a subspecies and two authorities
  poplar <- leads[leads$Statement == "8" & leads$Choice == "b", ]
  expect_identical(poplar$Taxon, "Populus balsamifera subsp. trichocarpa")
  expect_identical(poplar$CommonName, "black cottonwood")
  expect_match(poplar$Authority, "Brayshaw")
})

test_that("zoological authorities with a year stay out of the common name", {
  p <- parseTextKey(c(
    "1a. Adipose fin present; spots red ...... Salmo trutta Linnaeus, 1758",
    "1b. Adipose fin present; spots black .... Oncorhynchus mykiss (Walbaum, 1792)",
    "1c. Adipose fin absent .................. Perca flavescens, yellow perch"
  ))
  expect_identical(p$leads$Taxon, c("Salmo trutta", "Oncorhynchus mykiss", "Perca flavescens"))
  expect_identical(p$leads$Authority, c("Linnaeus, 1758", "(Walbaum, 1792)", ""))
  expect_identical(p$leads$CommonName, c("", "", "yellow perch"))
})

test_that("a wrapped line that starts with a number is not taken for a lead", {
  p <- parseTextKey(c(
    "1. Dorsal fins two ................. 2",
    "1. Dorsal fin one; anal fin with",
    "3. spines, the first short ......... Percidae",
    "2. Scales large .................... Cyprinidae",
    "2. Scales small, leaflike lobes",
    "   3 to 5 mm long .................. Salmonidae"
  ))
  expect_identical(shape(p), c("1a>2", "1b>Percidae", "2a>Cyprinidae", "2b>Salmonidae"))
  expect_equal(nrow(p$problems), 0)
})

test_that("wrapped leads are joined, hyphenated words mended, and lines recorded", {
  p <- parseTextKey(textKeyFile("trees-bracketed.txt"))
  lead <- p$leads[p$leads$Statement == "3" & p$leads$Choice == "b", ]
  expect_identical(lead$Character, "Leaflets 5 to 9, finely toothed; fruit a single paddle-shaped samara")
  expect_identical(lead$Line, 10L)
  expect_true(any(p$problems$Type == "dehyphenated" & p$problems$Line == 10))
  # The destination on the last wrapped line
  expect_identical(p$leads$Next[p$leads$Statement == "5"], c("6", "7"))
})

test_that("text can be a file, one string or a vector of lines", {
  file <- textKeyFile("trees-bracketed.txt")
  lines <- readLines(file)
  expect_identical(shape(parseTextKey(lines)), shape(parseTextKey(file)))
  expect_identical(shape(parseTextKey(paste(lines, collapse = "\n"))), shape(parseTextKey(file)))
  expect_identical(shape(parseTextKey(paste(lines, collapse = "\r\n"))), shape(parseTextKey(file)))
  expect_error(parseTextKey(42), "file path")
})

test_that("primes mark the second lead: 1. / 1'.", {
  p <- parseTextKey(c(
    "1.  Wings present .......... 2",
    "1'. Wings absent ........... Apterygota",
    "2.  One pair of wings ...... Diptera",
    "2'. Two pairs of wings ..... 3",
    "3.  Front wings hard ....... Coleoptera",
    "3\u2032. Front wings thin ....... Hymenoptera"
  ))
  expect_identical(shape(p), insects)
  expect_equal(nrow(p$problems), 0)
})

test_that("a dash marks the second lead: 1 / -", {
  for (dash in c("-", "\u2013", "\u2014")) {
    p <- parseTextKey(c(
      "1  Wings present .......... 2",
      paste(dash, " Wings absent ........... Apterygota"),
      "2  One pair of wings ...... Diptera",
      paste(dash, " Two pairs of wings ..... 3"),
      "3  Front wings hard ....... Coleoptera",
      paste(dash, " Front wings thin ....... Hymenoptera")
    ))
    expect_identical(shape(p), insects)
    expect_equal(nrow(serious(p)), 0)
  }
})

test_that("letters in parentheses: 1(a) / 1(b)", {
  p <- parseTextKey(c(
    "1(a) Wings present .......... 2",
    "1(b) Wings absent ........... Apterygota",
    "2(a) One pair of wings ...... Diptera",
    "2(b) Two pairs of wings ..... 3",
    "3(a) Front wings hard ....... Coleoptera",
    "3(b) Front wings thin ....... Hymenoptera"
  ))
  expect_identical(shape(p), insects)
  expect_equal(nrow(p$problems), 0)
})

test_that("A. / AA. lettering", {
  p <- parseTextKey(c(
    "Key to the orders",
    "A.  Wings present .......... B",
    "AA. Wings absent ........... Apterygota",
    "B.  One pair of wings ...... Diptera",
    "BB. Two pairs of wings ..... go to C",
    "C.  Front wings hard ....... Coleoptera",
    "CC. Front wings thin, the hind wings hooked to them; see",
    "    also the sawflies ...... Hymenoptera A. Smith"
  ))
  expect_identical(shape(p), c("Aa>B", "Ab>Apterygota", "Ba>Diptera", "Bb>C", "Ca>Coleoptera", "Cb>Hymenoptera"))
  expect_equal(nrow(serious(p)), 0)
  key <- keyFromText(c("A. Wings present ... B", "AA. Wings absent ... Apterygota",
                       "B. Two wings ... Diptera", "BB. Four wings ... Odonata"))
  expect_length(key$validate(), 0)
})

test_that("a back-reference 3(1). names the couplet it is reached from", {
  text <- c(
    "1.    Wings present .......... 2",
    "1.    Wings absent ........... Apterygota",
    "2(1). One pair of wings ...... Diptera",
    "2.    Two pairs of wings ..... 3",
    "3(2). Front wings hard ....... Coleoptera",
    "3.    Front wings thin ....... Hymenoptera"
  )
  p <- parseTextKey(text)
  expect_identical(shape(p), insects)
  expect_equal(nrow(p$problems), 0)

  text[5] <- "3(1). Front wings hard ....... Coleoptera"
  p <- parseTextKey(text)
  expect_identical(shape(p), insects)
  bad <- serious(p)
  expect_identical(bad$Type, "backref")
  expect_identical(bad$Line, 5L)
})

test_that("tabs, wide gaps, 'go to' and 'see' all give the destination", {
  p <- parseTextKey(c(
    "1a. Wings present\t2",
    "1b. Wings absent\t\tApterygota",
    "2a. One pair of wings      Diptera",
    "2b. Two pairs of wings; go to 3",
    "3a. Front wings hard (see 4)",
    "3b. Front wings thin . . . . . . Hymenoptera",
    "4a. Body long and narrow ____ Staphylinidae, p. 212",
    "4b. Body rounded \u2026\u2026\u2026 Coccinellidae (lady beetles)"
  ))
  expect_identical(shape(p), c("1a>2", "1b>Apterygota", "2a>Diptera", "2b>3", "3a>4", "3b>Hymenoptera",
                               "4a>Staphylinidae", "4b>Coccinellidae"))
  expect_identical(p$leads$Character[4:5], c("Two pairs of wings", "Front wings hard"))
  expect_identical(p$leads$Page[7], "212")
  expect_identical(p$leads$CommonName[8], "lady beetles")
  expect_equal(nrow(serious(p)), 0)
  expect_equal(nrow(repairs(p)), 0)
})

test_that("page numbers, running heads and blank lines inside a key are skipped", {
  p <- parseTextKey(c(
    "KEY TO THE ORDERS",
    "",
    "1a. Wings present, at least in the",
    "",
    "A FIELD GUIDE TO INSECTS      212",
    "",
    "    adult ..................... 2",
    "1b. Wings absent .............. Apterygota",
    "",
    "- 213 -",
    "Insects of the Valley      214",
    "",
    "2a. One pair of wings ......... Diptera",
    "",
    "Flies are treated in the second volume.",
    "",
    "2b. Two pairs of wings ........",
    "    3",
    "3a. Front wings hard .......... Coleoptera",
    "3b. Front wings thin ..........",
    "    Hymenoptera"
  ))
  expect_identical(shape(p), insects)
  expect_identical(p$leads$Character[1], "Wings present, at least in the adult")
  expect_identical(p$title, "KEY TO THE ORDERS")
  expect_equal(nrow(serious(p)), 0)
  skipped <- p$problems[p$problems$Type == "skipped", ]
  expect_setequal(skipped$Line, c(5, 10, 11, 15))
  expect_true(all(skipped$Kind == "note"))
})

test_that("`skip` leaves out lines the parser would not recognise as noise", {
  text <- c(
    "1a. Wings present, at least in the",
    "Smith and Jones: the insect orders",
    "    adult ..................... Pterygota",
    "1b. Wings absent .............. Apterygota"
  )
  expect_match(parseTextKey(text)$leads$Character[1], "Smith and Jones")
  p <- parseTextKey(text, skip = "^Smith and Jones")
  expect_identical(p$leads$Character[1], "Wings present, at least in the adult")
})

test_that("an indented key links each open lead to the couplet under it", {
  p <- parseTextKey(textKeyFile("conifers-indented.txt"))
  expect_identical(p$layout, "indented")
  expect_equal(nrow(p$problems), 0)
  expect_identical(p$leads$Statement[1:4], c("1", "2", "2", "1"))
  expect_identical(p$leads$Next[p$leads$Statement == "1"], c("2", "3"))
  expect_identical(p$leads$Next[p$leads$Statement == "3"], c("4", "6"))
  expect_identical(p$leads$Line[p$leads$Statement == "3"], c(10L, 16L))
  key <- expect_silent(keyFromText(textKeyFile("conifers-indented.txt")))
  expect_length(key$validate(), 0)
  expect_equal(key$summary()$taxa, 10)
})

test_that("couplets with three leads keep all of them", {
  p <- parseTextKey(textKeyFile("conifers-indented.txt"))
  four <- p$leads[p$leads$Statement == "4", ]
  expect_identical(four$Choice, c("a", "b", "c"))
  expect_identical(four$Next, c("-", "-", "5"))

  p <- parseTextKey(c(
    "1a. Flowers red ...... 2", "1b. Flowers blue ..... Gentiana", "1c. Flowers white .... Anemone",
    "2. Petals four ....... Epilobium", "2'. Petals five ...... Geranium", "2''. Petals six ...... Lilium"
  ))
  expect_identical(shape(p), c("1a>2", "1b>Gentiana", "1c>Anemone", "2a>Epilobium", "2b>Geranium", "2c>Lilium"))
  expect_equal(nrow(p$problems), 0)
})

test_that("a couplet may be reached from several leads", {
  key <- expect_silent(keyFromText(c(
    "1a. Flowers red ............ 2",
    "1b. Flowers blue ........... 3",
    "1c. Flowers white .......... 3",
    "2a. Petals four ............ Epilobium",
    "2b. Petals five ............ 3",
    "3(1,2). Leaves lobed ....... Geranium",
    "3. Leaves entire ........... Gentiana"
  ), "Flowers"))
  expect_length(key$validate(), 0)
  expect_equal(sum(key$leads$Next == "3"), 3)
  expect_equal(sum(key$df$Taxon == "Geranium" & key$df$Statement == "3"), 3)
})

test_that("an indented key without indentation is still read by its numbers", {
  p <- parseTextKey(c(
    "1. Wings present",
    "2. One pair of wings ... Diptera",
    "2. Two pairs of wings",
    "3. Front wings hard ... Coleoptera",
    "3. Front wings thin ... Hymenoptera",
    "1. Wings absent ... Apterygota"
  ))
  expect_identical(shape(p), c("1a>2", "2a>Diptera", "2b>3", "3a>Coleoptera", "3b>Hymenoptera", "1b>Apterygota"))
  expect_equal(nrow(serious(p)), 0)
})

test_that("`layout` decides whether an open lead leads to the couplet under it", {
  text <- c(
    "1. Wings absent ... Apterygota",
    "1. Wings present",
    "2. One pair of wings ... Diptera",
    "2. Two pairs of wings ... Odonata"
  )
  bracketed <- parseTextKey(text)
  expect_identical(serious(bracketed)$Type, c("no_destination", "unreachable"))
  expect_identical(serious(bracketed)$Line, c(2L, 3L))
  # Indentation shows the couplet belongs under the lead
  text[3:4] <- paste0("   ", text[3:4])
  expect_equal(nrow(serious(parseTextKey(text))), 0)
  expect_identical(serious(parseTextKey(text, layout = "bracketed"))$Type, c("no_destination", "unreachable"))
  expect_equal(nrow(serious(parseTextKey(trimws(text), layout = "indented"))), 0)
})

test_that("OCR noise in couplet numbers is repaired and reported", {
  body <- c(
    "%s Wings present .......... 2", "1b. Wings absent ........... Apterygota",
    "2a. Wings two .............. Diptera", "2b. Wings four ............. 3",
    "3a. Front wings hard ....... 4", "3b. Front wings thin ....... 5",
    "4a. Body long .............. 6", "4b. Body round ............. 7",
    "5a. Waist narrow ........... 8", "5b. Waist broad ............ 9",
    "6a. Jaws long .............. Staphylinidae", "6b. Jaws short ............. Silphidae",
    "7a. Spotted ................ Coccinellidae", "7b. Plain .................. Chrysomelidae",
    "8a. Antennae elbowed ....... Formicidae", "8b. Antennae straight ...... %s",
    "9a. Body hairy ............. Apidae", "9b. Body bare .............. Tenthredinidae",
    "%s Wings folded ........... Vespidae", "%s Wings flat ............. Sphecidae"
  )
  clean <- parseTextKey(sprintf(paste(body, collapse = "\n"), "1a.", "10", "10a.", "10b."))
  expect_equal(nrow(clean$problems), 0)

  noisy <- parseTextKey(sprintf(paste(body, collapse = "\n"), "la.", "lO", "1Oa.", "IOb."))
  expect_identical(shape(noisy), shape(clean))
  fixed <- repairs(noisy)
  expect_identical(fixed$Line, c(1L, 16L, 19L, 20L))
  expect_identical(fixed$Type, c("label", "destination", "label", "label"))
  expect_match(fixed$Message[1], "'la.' as couplet 1", fixed = TRUE)
  expect_match(fixed$Message[2], "'lO' as couplet 10", fixed = TRUE)
  expect_equal(nrow(serious(noisy)), 0)
})

test_that("lost dot leaders and lost full stops are repaired and reported", {
  p <- parseTextKey(c(
    "1a. Wings present 2",
    "1b. Wings absent Apterygota",
    "2a. Wings two, the hind pair reduced to small knobs Diptera",
    "2b. Wings four ............. 3",
    "3a Front wings hard ........ Coleoptera",
    "3b. Front wings thin; hind wings smaller. Apis mellifera L."
  ))
  expect_identical(shape(p), c("1a>2", "1b>Apterygota", "2a>Diptera", "2b>3", "3a>Coleoptera", "3b>Apis mellifera"))
  expect_identical(p$leads$Character[c(1, 3, 6)],
    c("Wings present", "Wings two, the hind pair reduced to small knobs", "Front wings thin; hind wings smaller."))
  fixed <- repairs(p)
  expect_setequal(fixed$Line, c(1, 2, 3, 6))
  expect_true(all(fixed$Type == "destination"))
  expect_equal(nrow(serious(p)), 0)

  # A number that is part of the text is not taken for a destination
  p <- parseTextKey(c("1a. Petals 4 or 5", "1b. Petals 3 .... Trillium"))
  expect_identical(p$leads$Character[1], "Petals 4 or 5")
  expect_identical(serious(p)$Type, "no_destination")
})

test_that("the scanned fixture is repaired, with every repair reported", {
  p <- parseTextKey(textKeyFile("meadow-ocr.txt"))
  expect_identical(shape(p), c("1a>Poaceae", "1b>2", "2a>3", "2b>4", "3a>Scirpus microcarpus", "3b>Carex",
                               "4a>Juncus", "4b>Luzula"))
  expect_identical(repairs(p)$Line, c(3L, 15L))
  expect_identical(repairs(p)$Type, c("label", "destination"))
  expect_equal(nrow(serious(p)), 0)
  expect_match(p$leads$Character[3], "each flower behind a single scale")
  expect_setequal(p$problems$Line[p$problems$Type == "skipped"], c(11, 13))

  expect_warning(key <- keyFromText(textKeyFile("meadow-ocr.txt")), "0 problem\\(s\\) and 2 repair\\(s\\)")
  expect_length(key$validate(), 0)
  expect_identical(attr(key, "problems")$Kind[1:2], c("repair", "repair"))
})

test_that("strict = TRUE stops instead of repairing", {
  expect_error(parseTextKey(textKeyFile("meadow-ocr.txt"), strict = TRUE), "2 repair\\(s\\).*line 3: .*line 15: ")
  expect_error(keyFromText(textKeyFile("meadow-ocr.txt"), strict = TRUE), "repair")
  expect_silent(parseTextKey(textKeyFile("trees-bracketed.txt"), strict = TRUE))
  expect_silent(keyFromText(textKeyFile("trees-bracketed.txt"), strict = TRUE))
})

test_that("problems are reported with their lines and no lead is dropped", {
  text <- c(
    "Key to the orders",
    "",
    "1a. Wings present .......... 2",
    "1b. Wings absent ........... Apterygota",
    "2a. One pair of wings ...... Diptera",
    "2b. Two pairs of wings ..... S",
    "3a. Front wings hard ....... 7",
    "3b. Front wings thin",
    "4a. Body hairy ............. Apidae"
  )
  p <- parseTextKey(text)
  expect_equal(nrow(p$leads), 7)
  bad <- serious(p)
  type <- function(t) bad[bad$Type == t, ]
  expect_identical(type("broken_number")$Line, 6L)
  expect_match(type("broken_number")$Message, "'S' looks like a broken couplet number (5?)", fixed = TRUE)
  expect_identical(type("missing_couplet")$Line, 7L)
  expect_match(type("missing_couplet")$Message, "lead 3a leads to couplet 7")
  expect_identical(type("no_destination")$Line, 8L)
  expect_identical(type("no_destination")$Lead, "3b")
  expect_identical(type("single_lead")$Line, 9L)
  expect_identical(type("single_lead")$Couplet, "4")
  expect_identical(type("unreachable")$Line, c(7L, 9L))
  # The broken destination is kept, not thrown away
  expect_identical(p$leads$Taxon[p$leads$Statement == "2"], c("Diptera", "S"))

  expect_warning(key <- keyFromText(text), "line 8: lead 3b has no destination")
  expect_s3_class(key, "dimoose")
  expect_equal(nrow(key$leads), 7)
  expect_identical(attr(key, "problems"), p$problems)
  expect_true(length(key$validate()) >= 4)
  expect_error(keyFromText(text, strict = TRUE), "problem\\(s\\)")
  # parseTextKey(strict = TRUE) stops for repairs only; these cannot be repaired
  expect_equal(nrow(serious(parseTextKey(text, strict = TRUE))), nrow(bad))
})

test_that("OCR-looking destinations that cannot be repaired safely are problems", {
  p <- parseTextKey(c("1a. Wings present .... l", "1b. Wings absent .... I2", "2a. Small ... Diptera", "2b. Large ... Odonata"))
  bad <- serious(p)
  expect_identical(bad$Line[bad$Type == "broken_number"], c(1L, 2L))
  expect_identical(p$leads$Taxon[1:2], c("l", "I2"))
})

test_that("duplicate leads and cycles are reported", {
  p <- parseTextKey(c("1a. Wings present .... 2", "1a. Wings absent .... Apterygota",
                      "2a. Two wings .... Diptera", "2b. Four wings .... 1"))
  bad <- serious(p)
  expect_identical(bad$Type[bad$Line == 2], "duplicate_lead")
  expect_identical(p$leads$Choice[1:2], c("a", "b"))
  expect_true("cycle" %in% bad$Type)
  expect_identical(bad$Line[bad$Type == "cycle"], c(1L, 4L))
  expect_error(suppressWarnings(keyFromText(c("1a. Wings present .... 2", "1b. Wings absent .... Apterygota",
                                              "2a. Two wings .... Diptera", "2b. Four wings .... 1"))),
               "could not be built.*line 4")
})

test_that("text without leads is an error for keyFromText", {
  p <- parseTextKey("Nothing here looks like a key.\nNot this line either.")
  expect_equal(nrow(p$leads), 0)
  expect_error(keyFromText("Nothing here looks like a key."), "No leads were found")
})

test_that("desc and meta are passed on", {
  meta <- data.frame(key = "citation", value = "Made up for the tests", stringsAsFactors = FALSE)
  key <- keyFromText(textKeyFile("trees-bracketed.txt"), "My trees", meta)
  expect_identical(key$desc, "My trees")
  expect_identical(key$meta$value, "Made up for the tests")
})

test_that("the parse prints a short report", {
  out <- capture.output(print.textKeyParse(parseTextKey(textKeyFile("meadow-ocr.txt"))))
  expect_match(out[1], "8 leads in 4 couplets, bracketed layout")
  expect_true(any(grepl("line 3: read the label 'l.' as couplet 1 [repaired]", out, fixed = TRUE)))
})

# ---- llm ---------------------------------------------------------------------

messy <- c(
  "KEY T0 THE 0RDERS",                                  # 1
  "",                                                   # 2
  "l a ) Wings present ,, at least in the adult .  . 2",  # 3
  "lb ) Wings absent  ~~ Apterygota",                   # 4
  "2 a) One pair of wings;; hind wings reduced to",     # 5
  "knobs ~ Diptera",                                    # 6
  "2 b) Two pairs of wings ~~ 3",                       # 7
  "3a) Front wings hard ~ Coleoptera",                  # 8
  "3b) Front wings thin ~ Hymenoptera"                  # 9
)

test_that("llm returning text: its answer is parsed and tied back to source lines", {
  seen <- NULL
  fake <- function(text) {
    seen <<- text
    paste(
      "1a. Wings present, at least in the adult .... 2",
      "1b. Wings absent .... Apterygota",
      "2a. One pair of wings; hind wings reduced to knobs .... Diptera",
      "2b. Two pairs of wings .... 3",
      "3a. Front wings hard .... Coleoptera",
      "3b. Front wings thin .... Hymenoptera",
      sep = "\n"
    )
  }
  p <- parseTextKey(messy, llm = fake)
  expect_identical(seen, paste(messy, collapse = "\n"))
  expect_identical(shape(p), insects)
  expect_identical(p$leads$Line, c(3L, 4L, 5L, 7L, 8L, 9L))
  expect_identical(p$leads$LlmLine, 1:6)
  expect_equal(nrow(serious(p)), 0)
  key <- expect_silent(keyFromText(messy, "Orders", llm = fake))
  expect_length(key$validate(), 0)
})

test_that("llm returning a table of couplet, lead, text, destination", {
  fake <- function(text) {
    data.frame(
      couplet = c(1, 1, 2, 2, 3, 3),
      lead = c("a", "b", "a", "b", "a", "b"),
      text = c("Wings present, at least in the adult", "Wings absent",
               "One pair of wings; hind wings reduced to knobs", "Two pairs of wings",
               "Front wings hard", "Front wings thin"),
      destination = c("2", "Apterygota", "Diptera", "go to 3", "Coleoptera", "Hymenoptera")
    )
  }
  p <- parseTextKey(messy, llm = fake)
  expect_identical(shape(p), insects)
  expect_identical(p$leads$Line, c(3L, 4L, 5L, 7L, 8L, 9L))
  expect_equal(nrow(serious(p)), 0)

  # Lead-table column names work too, and choices are filled in when missing
  fake2 <- function(text) {
    data.frame(Statement = c("1", "1"), Character = c("Wings present", "Wings absent"),
               Next = c("-", "-"), Taxon = c("Diptera", "Apterygota"))
  }
  p <- parseTextKey(messy[1:4], llm = fake2)
  expect_identical(shape(p), c("1a>Diptera", "1b>Apterygota"))
})

test_that("the model's mistakes are caught and reported by source line", {
  fake <- function(text) {
    paste(
      "1a. Wings present, at least in the adult .... 2",
      "1b. Wings absent .... Apterygota",
      "2a. One pair of wings; hind wings reduced to knobs .... Siphonaptera",   # invented taxon
      "2b. Two pairs of wings .... 4",                                          # wrong couplet
      "3a. Elytra meeting along a straight suture over the abdomen .... Coleoptera",  # invented text
      sep = "\n"                                                                # and 3b left out
    )
  }
  p <- parseTextKey(messy, llm = fake)
  bad <- serious(p)
  type <- function(t) bad[bad$Type == t, ]
  expect_identical(type("llm_taxon")$Line, 5L)
  expect_match(type("llm_taxon")$Message, "Siphonaptera")
  expect_identical(type("missing_couplet")$Line, 7L)
  expect_identical(type("llm_text")$Line, 8L)
  expect_identical(type("single_lead")$Couplet, "3")
  expect_match(type("llm_lost_leads")$Message, "returned 5 lead\\(s\\) but 6 line\\(s\\).*line\\(s\\) 9")

  expect_warning(key <- keyFromText(messy, llm = fake), "Siphonaptera")
  expect_true(length(key$validate()) > 0)
  expect_true(all(c("llm_taxon", "llm_text", "llm_lost_leads") %in% attr(key, "problems")$Type))
  expect_error(keyFromText(messy, llm = fake, strict = TRUE), "problem")
})

test_that("a table from the model is checked like any other key", {
  fake <- function(text) {
    data.frame(couplet = c("1", "1", "2"), lead = c("a", "b", "a"),
               text = c("Wings present", "Wings absent", "One pair of wings"),
               destination = c("2", "", "Diptera"))
  }
  p <- parseTextKey(messy, llm = fake)
  bad <- serious(p)
  expect_true(all(c("no_destination", "single_lead") %in% bad$Type))
  expect_identical(bad$Line[bad$Type == "no_destination"], 4L)
})

test_that("unusable answers from llm are errors", {
  expect_error(parseTextKey(messy, llm = function(text) stop("rate limit")), "`llm` failed: rate limit")
  expect_error(parseTextKey(messy, llm = function(text) NULL), "must return text")
  expect_error(parseTextKey(messy, llm = function(text) ""), "must return text")
  expect_error(parseTextKey(messy, llm = function(text) "I could not read this."), "No leads were found")
  expect_error(parseTextKey(messy, llm = function(text) data.frame(a = 1)), "needs the columns")
  expect_error(parseTextKey(messy, llm = "claude"), "must be a function")
})

# ---- real published keys (public domain; sources in the fixture headers) -----

realKey <- function(name, ...) {
  parseTextKey(test_path("fixtures", "textkeys", name), skip = "^#", ...)
}
# "couplet>destination" of every lead, in reading order
links <- function(p) {
  paste0(p$leads$Statement, ">", ifelse(p$leads$Next != "-", p$leads$Next, p$leads$Taxon))
}

test_that("Schaffner 1914: sentence-end destinations, list numbers and garbled labels in double-spaced OCR", {
  p <- realKey("schaffner-1914-winter.txt")
  expect_identical(p$layout, "bracketed")
  expect_identical(p$title, "KEY TO THE GENERA OF TREES IN THE WINTER CONDITION.")
  # read from the printed key; "11>18" is the scan's own misprint of 13
  expect_identical(links(p), c(
    "1>2", "1>11", "2>3", "2>8", "3>Pinus", "3>4", "4>5", "4>7", "5>Abies", "5>6", "6>Tsuga", "6>Picea",
    "7>Thuja", "7>Libocedrus", "7>Chamaecyparis", "7>Juniperus", "8>Ilex", "8>9", "9>Quercus", "9>10",
    "10>Rhododendron", "10>Kalmia", "10>Persea", "11>12", "11>18", "12>Larix", "12>Ginkgo",
    "13>Taxodium", "13>14", "14>15", "14>72", "15>16"
  ))
  # the list number after the genus goes to Page, not to Next
  expect_identical(p$leads$Page[p$leads$Taxon == "Pinus"], "7")
  expect_identical(p$leads$Page[p$leads$Taxon == "Kalmia"], "67")
  expect_false(any(grepl("  ", p$leads$Character)))
  # labels the scan garbled ("0." for 6, "V0." for 10, "IB." for 12) are repairs, each with its line
  labels <- p$problems[p$problems$Type == "label", ]
  expect_identical(labels$Kind, rep("repair", 3))
  expect_match(labels$Message, "'0\\.' as couplet 6|'V0\\.' as couplet 10|'IB\\.' as couplet 12")
  expect_false(anyNA(labels$Line))
  # the misprinted 18 shows up as a problem, as does couplet 13 that nothing leads to
  bad <- serious(p)
  expect_true(any(bad$Type == "missing_couplet" & grepl("couplet 18", bad$Message)))
  expect_true(any(bad$Type == "unreachable" & bad$Couplet == "13"))
  # page furniture is skipped and said so
  skipped <- p$problems$Message[p$problems$Type == "skipped"]
  expect_true(any(grepl("Trees of the Northern United States 23", skipped)))
  expect_true(any(grepl("page number: '\\(22\\)'", skipped)))
})

test_that("Brues & Melander 1915: second leads without a label, names in capitals with a page", {
  p <- realKey("brues-melander-1915-orders.txt")
  expect_identical(links(p), c(
    "1>2", "1>29", "2>3", "2>11", "3>4", "3>10", "4>5", "4>HEMIPTERA", "5>6", "5>HOMOPTERA", "6>ISOPTERA",
    "6>7", "7>8", "7>STREPSIPTERA", "8>9", "8>ORTHOPTERA", "9>MANTOIDEA", "9>BLATTOIDEA", "10>DERMAPTERA",
    "10>COLEOPTERA", "11>12", "11>27", "12>THYSANOPTERA", "12>13", "13>14", "13>16", "14>15",
    "14>PLECOPTERA", "15>TRICHOPTERA", "15>MEGALOPTERA", "16>17"
  ))
  expect_identical(p$leads$Page[p$leads$Taxon == "ORTHOPTERA"], "13")
  expect_identical(p$leads$CommonName[p$leads$Taxon == "ORTHOPTERA"], "Grasshoppers, Katydids, Crickets")
  expect_true(any(p$problems$Type == "layout" & grepl("no label", p$problems$Message)))
  # couplets beyond the excerpt are reported, not invented
  expect_setequal(serious(p)$Type, c("missing_couplet", "single_lead"))
  expect_true(any(grepl("Key to the Orders of Insects", p$problems$Message[p$problems$Type == "skipped"])))
})

test_that("Ward & Whipple 1918: paired leads '1 (8)' are put together; lost labels are reported", {
  p <- realKey("ward-whipple-1918-sarcodina.txt")
  expect_identical(p$layout, "paired")
  l <- p$leads
  dest <- function(line) {
    i <- which(grepl(line, l$Character, fixed = TRUE))[1]
    if (l$Next[i] != "-") l$Next[i] else l$Taxon[i]
  }
  # leads 5 (6) and 6 (5) are one couplet, as are 7/8 and 9/10
  expect_identical(l$Statement[grepl("^Body (and pseudopodia bristling|smooth)", l$Character)], c("5", "5"))
  expect_identical(dest("Pseudo podia without axial"), "2")
  expect_identical(dest("One family recognized"), "5")
  expect_identical(dest("Body smooth, without spicules"), "7")
  expect_identical(dest("Body and pseudopodia bristling"), "Dinamoeba mirabilis")
  expect_identical(dest("Pseudopodia lobe-like"), "Amoeba proteus")
  expect_identical(dest("With shells"), "22")
  # the species descriptions and figure captions are not part of any lead
  expect_false(any(grepl("Very changeable|FIG\\.", l$Character)))
  bad <- serious(p)
  # on the second page the scan put six labels in a column of their own
  expect_identical(sum(bad$Type == "lone_label"), 6L)
  expect_false(anyNA(bad$Line[bad$Type == "lone_label"]))
  expect_true(any(bad$Type == "numbers_jump" & grepl("from 12 to 19", bad$Message)))
  # "n" for 11
  expect_true(any(bad$Type == "odd_destination" & grepl("'n'", bad$Message)))
})

test_that("Rydberg 1917: an indented key without couplet numbers is read from its indentation", {
  p <- realKey("rydberg-1917-salix-longifoliae.txt")
  expect_identical(p$layout, "unnumbered")
  expect_identical(p$title, "IV. LONGIFOLIAE.")
  expect_identical(links(p), c(
    "1>2", "2>S. melanopsis", "2>3", "3>4", "4>5", "5>S. exigua", "5>S. stenophylla", "4>6", "6>S. interior",
    "6>S. lineari folia", "3>S. sessilifolia", "1>7", "7>S. argophylla", "7>S. macrostachya"
  ))
  expect_identical(nrow(serious(p)), 0L)
  key <- keyFromLeads(p$leads, "Salix sect. Longifoliae")
  expect_identical(key$validate(), character())

  # two pages, a running head in between, the left margin shifting by a column
  p <- realKey("rydberg-1917-salix-cordatae.txt")
  expect_identical(nrow(p$leads), 40L)
  expect_true(all(table(p$leads$Statement) == 2))
  expect_identical(sum(p$leads$Next == "-" & nzchar(p$leads$Taxon)), 20L)
  expect_true(any(grepl("WILLOW FAMILY 189", p$problems$Message[p$problems$Type == "skipped"])))
  # "2<S. S. Barklayi" cannot be read as a name: one problem, on its line
  bad <- serious(p)
  expect_identical(bad$Type, "no_destination")
  expect_match(p$text[bad$Line], "Barklayi")
})

test_that("a key without numbers whose indentation is lost is refused, not guessed", {
  p <- realKey("rydberg-1917-salix-flat.txt")
  expect_identical(nrow(p$leads), 0L)
  expect_identical(serious(p)$Type, "no_indentation")
  expect_error(keyFromText(test_path("fixtures", "textkeys", "rydberg-1917-salix-flat.txt"), skip = "^#"),
               "not indented")
  p <- parseTextKey("Some prose about willows.\nNothing here is a key.")
  expect_identical(serious(p)$Type, "no_leads")
})

# ---- regressions from the review ---------------------------------------------

test_that("a colon or a spaced dash sets off the destination", {
  p <- parseTextKey(c(
    "1. Leaves without teeth: 2",
    "1. Leaves with teeth: 3",
    "    2. Leaves evergreen — live oak Quercus virginiana",
    "    2. Leaves not evergreen — willow oak Quercus phellos",
    "3. Lobes bristle-tipped — northern red oak Quercus rubra",
    "3. Lobes rounded -- white oak Quercus alba",
    "",
    "This key first separates the oaks with entire leaves."
  ))
  # 1b used to be sent to the couplet printed under it (2) instead of 3
  expect_identical(links(p), c("1>2", "1>3", "2>Quercus virginiana", "2>Quercus phellos", "3>Quercus rubra",
                               "3>Quercus alba"))
  expect_identical(p$leads$CommonName[3:6], c("live oak", "willow oak", "northern red oak", "white oak"))
  expect_identical(p$leads$Character[2], "Leaves with teeth")
  expect_identical(p$layout, "bracketed")
  expect_identical(nrow(serious(p)), 0L)
})

test_that("a destination in a table cell may be an abbreviated genus with author and year", {
  p <- parseTextKey(c(
    "1\tClypeus without median carina (China)\tD.", "leioceps Strand, 1913",
    "–\tClypeus with median carina\t2",
    "2\tLamella as long as wide\tD. formosanus Tsuneki & Iida, 1967",
    "–\tLamella longer\tD. albipedigerus Bai & Li, sp. nov."
  ))
  expect_identical(p$leads$Taxon, c("D. leioceps", "", "D. formosanus", "D. albipedigerus"))
  expect_identical(p$leads$Authority[c(1, 3)], c("Strand, 1913", "Tsuneki & Iida, 1967"))
  expect_identical(nrow(serious(p)), 0L)
})

test_that("a number in parentheses is a couplet after plain text and a list number after a name", {
  p <- parseTextKey(c(
    "1 Leaves glabrous (2)", "+ Leaves hairy (3)",
    "2 Fruit a nut. Corylus. (14).", "+ Fruit a samara. Betula (15).",
    "3 Bark white. Populus. (16).", "+ Bark grey. Salix. (17)."
  ))
  expect_identical(p$leads$Next[1], "2")
  expect_identical(p$leads$Taxon[3], "Corylus")
  expect_identical(p$leads$Page[3], "14")
  expect_identical(p$leads$Taxon[5:6], c("Populus", "Salix"))
})

test_that("a few couplets out of order do not turn a bracketed key into an indented one", {
  p <- parseTextKey(c(
    "1. Wings present. 2.", "1. Wings absent. 3.",
    "2. Two wings. Diptera.", "3. Six legs",          # 3 comes too early and lost its destination
    "2. Four wings. Odonata.", "3. Eight legs. Araneae."
  ))
  expect_identical(p$layout, "bracketed")
  # the lead without a destination is a problem; it is not sent on to couplet 2
  expect_identical(p$leads$Next[4], "-")
  expect_true("no_destination" %in% serious(p)$Type)
})

test_that("text that looks like a lead without its label is a problem, not a note", {
  p <- parseTextKey(c(
    "1. Leaves alternate. 2.", "1. Leaves opposite. 3.",
    "2. Leaves simple. Ulmus.", "2. Leaves compound. Juglans.",
    "",
    "Leaves entire. Cornus. (4).",
    "3. Leaves lobed. Acer."
  ))
  bad <- serious(p)
  expect_true("unlabelled_lead" %in% bad$Type)
  expect_identical(bad$Line[bad$Type == "unlabelled_lead"], 6L)
})

test_that("more than 999 couplets are read, and a year at a line start is not a label", {
  n <- 1002L
  big <- unlist(lapply(seq_len(n), function(i) c(
    sprintf("%da. State %d present ........ %s", i, i, if (i < n) i + 1 else "Lastus finalis"),
    sprintf("%db. State %d absent ........ Genus species", i, i)
  )))
  p <- parseTextKey(big)
  expect_identical(nrow(p$leads), 2L * n)
  expect_identical(p$leads$Next[2001], "1002")
  expect_identical(nrow(serious(p)), 0L)

  p <- parseTextKey(c("1. Shell coiled; described by Linnaeus in", "1758. Operculum present .... 2",
                      "1. Shell not coiled .... Patella", "2. Spire tall .... Turritella", "2. Spire low .... Natica"))
  expect_identical(nrow(p$leads), 4L)
})

test_that("a missing file or a folder is an error, not an empty key", {
  expect_error(parseTextKey("no-such-key.txt"), "File not found")
  expect_error(parseTextKey(tempdir()), "folder")
  expect_error(keyFromText(""), "No leads were found")
})

test_that("text in other scripts and encodings is kept", {
  p <- parseTextKey(c(
    "1. Blätter gegenständig … 2", "1′. Blätter wechselständig … Fagus sylvatica L. (Rotbuche)",
    "2. Früchte geflügelt … Acer pseudoplatanus L.", "2′. Früchte nicht geflügelt … Tilia cordata Mill."
  ))
  expect_identical(p$leads$Character[1], "Blätter gegenständig")
  expect_identical(p$leads$CommonName[2], "Rotbuche")
  expect_identical(p$leads$Choice, c("a", "b", "a", "b"))
  latin1 <- iconv("1. Blätter groß .... 2\n1'. Blätter klein .... Abies alba\n2. a .... Picea abies\n2'. b .... Pinus mugo",
                  "UTF-8", "latin1")
  expect_identical(parseTextKey(latin1)$leads$Character[1], "Blätter groß")
})

test_that("llm: JSON, code fences and broken answers", {
  skip_if_not_installed("jsonlite")
  src <- "1a. Wings present .... 2\n1b. Wings absent .... Apterygota\n2a. Two wings .... Diptera\n2b. Four wings .... Odonata"
  json <- paste0(
    '[{"couplet":1,"lead":"a","text":"Wings present","destination":"2"},',
    '{"couplet":1,"lead":"b","text":"Wings absent","destination":"Apterygota"},',
    '{"couplet":2,"lead":"a","text":"Two wings","destination":"Diptera"},',
    '{"couplet":2,"lead":"b","text":"Four wings","destination":"Odonata"}]'
  )
  p <- parseTextKey(src, llm = function(text) paste0("```json\n", json, "\n```"))
  expect_identical(links(p), c("1>2", "1>Apterygota", "2>Diptera", "2>Odonata"))
  expect_identical(p$leads$Line, 1:4)
  p <- parseTextKey(src, llm = function(text) paste0('{"leads": ', json, "}"))
  expect_identical(nrow(p$leads), 4L)
  # fenced text
  p <- parseTextKey(src, llm = function(text) paste0("```\n", text, "\n```"))
  expect_identical(nrow(p$leads), 4L)
  expect_identical(nrow(serious(p)), 0L)

  expect_error(parseTextKey(src, llm = function(text) substr(json, 1, 60)), "JSON that cannot be read")
  expect_error(parseTextKey(src, llm = function(text) '{"answer": 42}'), "not a list of leads")
  expect_error(parseTextKey(src, llm = function(text) "Sure! Here is your key."), "No leads were found")
  expect_error(parseTextKey(src, llm = function(text) NA_character_), "must return text")
  expect_error(parseTextKey(src, llm = function(text) data.frame(couplet = integer(), lead = character(),
    text = character(), destination = character())), "no rows")
  # NA cells in the table are problems, not a crash
  holes <- function(text) data.frame(couplet = c(1, 1, NA, 2), lead = c("a", "b", "a", NA),
    text = c("Wings present", "Wings absent", NA, "Four wings"), destination = c("2", "Apterygota", "Diptera", NA))
  bad <- serious(parseTextKey(src, llm = holes))
  expect_true(all(c("llm_couplet", "no_text", "no_destination") %in% bad$Type))
})

test_that("llm: a model that swaps destinations is caught although every word is in the source", {
  src <- "1a. Wings present .... 2\n1b. Wings absent .... Apterygota\n2a. Two wings .... Diptera\n2b. Four wings .... Odonata"
  swapped <- function(text) sub("Diptera", "Odonata", sub("Odonata", "Diptera", text, fixed = TRUE), fixed = TRUE)
  expect_identical(swapped(src), sub("Diptera\n2b. Four wings .... Odonata", "Odonata\n2b. Four wings .... Diptera", src, fixed = TRUE))
  bad <- serious(parseTextKey(src, llm = swapped))
  expect_identical(bad$Type, c("llm_destination", "llm_destination"))
  expect_identical(bad$Line, 3:4)
  expect_match(bad$Message[1], "Odonata")

  rerouted <- function(text) sub("Apterygota", "2", text, fixed = TRUE)
  bad <- serious(parseTextKey(src, llm = rerouted))
  expect_identical(bad$Type, "llm_destination")
  expect_identical(bad$Line, 2L)
  # an honest answer raises nothing
  expect_identical(nrow(serious(parseTextKey(src, llm = identity))), 0L)
})

# ---- second review: keys from further printed sources ------------------------

test_that("Williston 1908: a name and its page after a comma, footnotes, section letters, lost first couplets", {
  p <- realKey("williston-1908-diptera-families.txt")
  expect_identical(p$layout, "bracketed")
  # read from the printed table; couplets 1 and 2 have no labels in print, and the third lead of 17 is lost
  expect_identical(shape(p), c(
    "3a>Tipulidse", "3b>4", "4a>Rhyphidse", "4b>5", "5a>Orphnephilidae", "5b>6", "6a>Cecidoinyidae", "6b>7",
    "7a>12", "7b>8", "8a>9", "8b>10", "9a>Chironomidae", "9b>Simuliidse", "10a>Psychodidse", "10b>11",
    "11a>Culicidse", "11b>Dixidse", "12a>Blepharoceridse", "12b>13", "13a>Mycetophilidae", "13b>Bibionidae",
    "14a>18", "14b>15", "15a>25", "15b>16", "16a>Tabanidge", "16b>17", "17a>Acanthomeridae",
    "17b>Stratiomyidse", "18a>Phoridae", "18b>19", "19a>20", "19b>", "20a>Cyrtidae", "20b>21"
  ))
  # "Rhyphidse, 157." is a family and its page, not couplet 157
  expect_identical(p$leads$Page[p$leads$Taxon == "Rhyphidse"], "157")
  expect_identical(p$leads$Page[p$leads$Taxon == "Bibionidae"], "140")
  expect_identical(p$leads$Page[p$leads$Taxon == "Simuliidse"], "144")
  expect_false(any(p$leads$Next %in% c("157", "153", "117", "92", "96", "94", "148", "131", "176", "173", "164", "236", "182")))
  # a footnote and the signature line under it are not part of lead 3a
  expect_false(grepl("Chionea", p$leads$Character[1]))
  skipped <- p$problems$Message[p$problems$Type == "skipped"]
  expect_true(any(grepl("footnote: '\\* Chionea", skipped)))
  expect_true(any(grepl("page number: '\\(8\\) 65'", skipped)))
  # "ii" for 11 is repaired and said so
  expect_true(any(p$problems$Kind == "repair" & grepl("'ii' as couplet 11", p$problems$Message)))
  # the section heading "BB." is not the label of couplet 18
  expect_match(p$leads$Character[p$leads$Statement == "18"][1], "^Antennae apparently two-jointed")
  bad <- serious(p)
  expect_false(anyNA(bad$Line))
  # the unlabelled couplets 1 and 2 and the third lead of couplet 17 are reported, not dropped silently
  expect_match(bad$Message[bad$Type == "missing_start"], "couplets 1 to 2 were not found")
  expect_match(bad$Message[bad$Type == "unlabelled_lead"], "Leptidae.*couplet 17 may have another lead")
  expect_match(p$text[bad$Line[bad$Type == "unlabelled_lead"]], "Leptidae")
  expect_identical(bad$Lead[bad$Type == "no_destination"], "19b")
})

test_that("Britton & Brown 1913, Hitchcock 1935: no numbers and no indentation, couplets from the order of the leads", {
  p <- realKey("britton-brown-1913-verbena.txt")
  expect_identical(p$layout, "unnumbered")
  # read from the printed key, where the indentation shows the couplets
  expect_identical(shape(p), c(
    "1a>2", "2a>3", "3a>4", "4a>V. officinalis", "4b>V. urticifolia", "3b>5", "5a>6", "6a>V. hastata",
    "6b>V. angustifolia", "5b>V. stricta", "2b>V. bracteosa", "1b>7", "7a>V. canadensis", "7b>V. bipinnatifida"
  ))
  expect_identical(nrow(serious(p)), 0L)
  fixed <- repairs(p)
  expect_identical(fixed$Type, c("structure", "destination", "destination"))
  expect_match(fixed$Message[1], "every couplet to have exactly two leads")
  # names the scan put on lines of their own go back to the leads that end in their numbers
  expect_match(fixed$Message[2], "V, canadensis.*stands alone")
  expect_match(p$text[fixed$Line[2]], "canadensis")
  expect_error(parseTextKey(test_path("fixtures", "textkeys", "britton-brown-1913-verbena.txt"), skip = "^#", strict = TRUE),
               "needs 3 repair")
  key <- suppressWarnings(keyFromText(test_path("fixtures", "textkeys", "britton-brown-1913-verbena.txt"), "Verbena", skip = "^#"))
  expect_identical(key$validate(), character())

  p <- realKey("hitchcock-1935-festucoideae.txt")
  expect_identical(p$title, "Key to the tribes of Festucoideae")
  expect_identical(shape(p), c(
    "1a>Bambuseae", "1b>2", "2a>Phalarideae", "2b>3", "3a>Zizanieae", "3b>4", "4a>Oryzeae", "4b>5",
    "5a>Zoysieae", "5b>6", "6a>7", "7a>Hordeae", "7b>Chlorideae", "6b>8", "8a>Agrostideae", "8b>9",
    "9a>Aveneae", "9b>Festuceae"
  ))
  # "8. Phalarideae (p. 25)": the tribe's number is dropped, the page kept
  expect_identical(p$leads$Page[p$leads$Taxon == "Phalarideae"], "25")
  expect_identical(nrow(serious(p)), 0L)
  # specks of the scan at the end of a lead are not its destination
  expect_identical(p$leads$Character[p$leads$Statement == "6" & p$leads$Choice == "b"],
                   "Spikelets pedicellate in open or contracted, sometimes spikelike, panicles, rarely racemes.")
  expect_true(any(grepl("MANUAL OF THE GRASSES OF THE UNITED STATES 17", p$problems$Message[p$problems$Type == "skipped"])))
})

test_that("leads that do not pair off are refused with the line where the pairing breaks", {
  lines <- c(
    "Leaves opposite.",
    "Fruit a samara.  1. A. rubrum.",
    "Fruit a drupe.  2. C. florida.",
    "Leaves alternate.  3. Q. alba.",
    "Leaves whorled.  4. C. speciosa."
  )
  p <- parseTextKey(lines)
  expect_identical(nrow(p$leads), 0L)
  expect_identical(serious(p)$Type, "no_indentation")
  expect_identical(serious(p)$Line, 5L)
  expect_match(serious(p)$Message, "more leads follow")
  p <- parseTextKey(lines[1:4])
  expect_identical(shape(p), c("1a>2", "2a>A. rubrum", "2b>C. florida", "1b>Q. alba"))
  # a last lead without a name
  p <- parseTextKey(c(lines[1:3], "Leaves alternate.", "Bark white.  3. Q. alba.", "Bark dark."))
  expect_identical(nrow(p$leads), 0L)
  expect_match(serious(p)$Message, "does not end in a name")
  # the same leads with their indentation are read from it, three leads to a couplet and all
  p <- parseTextKey(c(lines[1], paste0("    ", lines[2:3]), lines[4:5]))
  expect_identical(shape(p), c("1a>2", "2a>A. rubrum", "2b>C. florida", "1b>Q. alba", "1c>C. speciosa"))
  expect_identical(nrow(repairs(p)), 0L)
})

test_that("Jordan & Evermann 1898: lower-case lettering a/aa with name and number at the end", {
  p <- realKey("jordan-evermann-1898-eleotris.txt")
  expect_identical(p$layout, "indented")
  expect_identical(shape(p), c("aa>b", "ba>c", "ca>d", "da>e", "ea>AMBLYOPSIS", "eb>ABACURUS", "db>PISONIS",
                               "bb>PERNIGER", "ab>PICTUS"))
  expect_identical(p$leads$Page[p$leads$Taxon == "PISONIS"], "2522")
  # the printed key has no "cc."
  expect_identical(serious(p)$Type, "single_lead")
  expect_identical(serious(p)$Couplet, "c")

  # labels the scan garbled ("Jf." and "jf." for f. and ff., "g-" for g.) are read as the leads due there
  p <- realKey("jordan-evermann-1898-gobiidae.txt")
  expect_identical(shape(p), c("aa>b", "ba>c", "ca>LoGLossvs", "bb>d", "da>PHILYPNUs", "db>e", "ea>f",
                               "fa>DORMITATOR", "fb>g", "ga>h", "ha>GUAVINA", "hb>ELEOTRIS", "gb>"))
  labels <- p$problems[p$problems$Type == "label", ]
  expect_identical(labels$Kind, rep("repair", 3))
  expect_match(labels$Message, "'Jf' as f |'jf' as ff |'g' as g ")
  expect_match(p$text[labels$Line], "^(Jf|jf|g-)")
  expect_true(any(grepl("Fishes of North America, 2189", p$problems$Message[p$problems$Type == "skipped"])))
})

test_that("a lettered label that cannot be placed is a problem, not silence", {
  p <- parseTextKey(c(
    "a. Leaves opposite .... b",
    "aa. Leaves alternate .... c",
    "b. Fruit dry .... Acer",
    "Q. Fruit fleshy .... Cornus",
    "c. Bark white .... Betula",
    "cc. Bark dark .... Prunus"
  ))
  bad <- serious(p)
  expect_true("label_unread" %in% bad$Type)
  expect_identical(bad$Line[bad$Type == "label_unread"], 4L)
})

test_that("an arrow before the destination, as in the Flora of North America online", {
  # the layout of a key table copied from floranorthamerica.org; the text is made up
  p <- parseTextKey(c(
    "1\tLeaf blade lobed more than 1/3 of the distance to the midrib.\t> 2",
    "1\tLeaf blade unlobed or shallowly lobed.\t> 3",
    "2\tLeaf blade blue-green, glaucous.\tQuercus laceyi",
    "2\tLeaf blade green; acorn on a peduncle 25-100 mm.\tQuercus robur",
    "3\tNut 30-60 mm.\tQuercus lobata",
    "3\tNut less than 30 mm.\tQuercus stellata"
  ))
  expect_identical(shape(p), c("1a>2", "1b>3", "2a>Quercus laceyi", "2b>Quercus robur", "3a>Quercus lobata",
                               "3b>Quercus stellata"))
  expect_identical(nrow(p$problems), 0L)
  # the same with spaces where the tabs were
  p <- parseTextKey(c(
    "1 Leaf blade lobed more than 1/3 of the distance to the midrib. > 2",
    "1 Leaf blade unlobed or shallowly lobed. > 3",
    "2 Leaf blade blue-green, glaucous. Quercus laceyi",
    "2 Leaf blade green; acorn on a peduncle 25-100 mm. Quercus robur",
    "3 Nut 30-60 mm. Quercus lobata",
    "3 Nut less than 30 mm. Quercus stellata"
  ))
  expect_identical(shape(p)[1:2], c("1a>2", "1b>3"))
  expect_identical(p$leads$Character[2], "Leaf blade unlobed or shallowly lobed.")
  expect_identical(nrow(serious(p)), 0L)
})

test_that("names at the end of a lead: abbreviated genus, authority, common name with a capital", {
  p <- parseTextKey(c(
    "1. Leaves white beneath. Salix alba L.",
    "1. Leaves green beneath. 2",
    "2. Twigs brittle. S. fragilis L.",
    "2. Twigs tough. S. nigra Marsh."
  ))
  expect_identical(shape(p), c("1a>Salix alba", "1b>2", "2a>S. fragilis", "2b>S. nigra"))
  expect_identical(p$leads$Authority, c("L.", "", "L.", "Marsh."))
  expect_identical(nrow(serious(p)), 0L)
  expect_identical(nrow(repairs(p)), 4L)

  p <- parseTextKey(c(
    "1. Leaves with deep lobes — Swamp chestnut oak Quercus prinus",
    "1. Leaves without lobes — willow oak Quercus phellos",
    "2. Two wings .... flies (Diptera)",
    "2. Four wings .... Odonata (dragonflies)"
  ))
  expect_identical(p$leads$Taxon, c("Quercus prinus", "Quercus phellos", "Diptera", "Odonata"))
  expect_identical(p$leads$CommonName, c("Swamp chestnut oak", "willow oak", "flies", "dragonflies"))
})

test_that("unlabelled further leads under a complete lead are read", {
  # the "lead style" example of the Wikipedia article on single-access keys
  p <- parseTextKey(c(
    " 1. Flowers red   ... 2",
    "    Flowers white ... 3",
    "    Flowers blue  ... 4",
    " 2. Leaves entire ... Aus bus",
    "    Leaves lobed ... Aus cus",
    " 3. Stem hairy ... Bus dus",
    "    Stem smooth ... Bus eus",
    " 4. Fruit dry ... Cus fus",
    "    Fruit fleshy ... Cus gus"
  ))
  expect_identical(shape(p), c("1a>2", "1b>3", "1c>4", "2a>Aus bus", "2b>Aus cus", "3a>Bus dus", "3b>Bus eus",
                               "4a>Cus fus", "4b>Cus gus"))
  expect_identical(nrow(serious(p)), 0L)
  expect_identical(sum(p$problems$Type == "layout"), 5L)
  # a wrapped destination is still part of its lead
  p <- parseTextKey(c(
    "1a. Leaves opposite ........ Acer saccharum",
    "    Marshall (sugar maple)",
    "1b. Leaves alternate ....... Quercus alba L."
  ))
  expect_identical(nrow(p$leads), 2L)
  expect_identical(p$leads$CommonName[1], "sugar maple")
})

test_that("Roman numerals, labels in parentheses, Markdown emphasis and tables", {
  want <- c("1a>2", "1b>3", "2a>Acer", "2b>Cornus", "3a>Betula", "3b>Prunus")
  p <- parseTextKey(c("I. Leaves opposite .... II", "I. Leaves alternate .... III", "II. Fruit dry .... Acer",
                      "II. Fruit fleshy .... Cornus", "III. Bark white .... Betula", "III. Bark dark .... Prunus"))
  expect_identical(shape(p), want)
  expect_identical(nrow(p$problems), 0L)
  p <- parseTextKey(c("(1) Leaves opposite .... 2", "(1) Leaves alternate .... 3", "(2) Fruit dry .... Acer",
                      "(2) Fruit fleshy .... Cornus", "(3) Bark white .... Betula", "(3) Bark dark .... Prunus"))
  expect_identical(shape(p), want)
  p <- parseTextKey(c("**1a.** Leaves opposite — go to 2", "**1b.** Leaves alternate — go to 3",
                      "**2a.** Fruit dry — *Acer*", "**2b.** Fruit fleshy — *Cornus*",
                      "**3a.** Bark white — *Betula*", "**3b.** Bark dark — *Prunus*"))
  expect_identical(shape(p), want)
  expect_identical(p$leads$Character[1], "Leaves opposite")
  p <- parseTextKey(c("| Couplet | Lead | Goes to |", "|---|---|---|", "| 1 | Leaves opposite | 2 |",
                      "| 1 | Leaves alternate | 3 |", "| 2 | Fruit dry | Acer |", "| 2 | Fruit fleshy | Cornus |",
                      "| 3 | Bark white | Betula |", "| 3 | Bark dark | Prunus |"))
  expect_identical(shape(p), want)
  # underscores as leaders are not Markdown, and a scan's I for 1 is not a Roman numeral
  p <- parseTextKey(c("1. Leaves opposite ____ Acer", "I. Leaves alternate ____ Quercus"))
  expect_identical(shape(p), c("1a>Acer", "1b>Quercus"))
})

test_that("text in two columns is read column by column, with the line numbers of the text as given", {
  lines <- readLines(textKeyFile("trees-bracketed.txt"))
  one <- parseTextKey(lines)
  half <- ceiling(length(lines) / 2)
  left <- lines[seq_len(half)]
  right <- c(lines[-seq_len(half)], rep("", 2 * half - length(lines)))
  two <- sub("\\s+$", "", paste0(formatC(left, width = -(max(nchar(left)) + 6)), right))
  p <- parseTextKey(two)
  expect_identical(shape(p), shape(one))
  expect_identical(p$leads$Taxon, one$leads$Taxon)
  expect_identical(repairs(p)$Type, "two_columns")
  expect_identical(nrow(serious(p)), 0L)
  # Line is the line of the two-column text
  expect_true(all(p$leads$Line <= length(two)))
  expect_true(all(mapply(function(line, word) grepl(word, two[line], fixed = TRUE), p$leads$Line,
                         sub(" .*$", "", p$leads$Character))))
  expect_error(parseTextKey(two, strict = TRUE), "two columns")

  # destinations set in a column of their own are not a second column of text
  p <- parseTextKey(c(
    "1. Leaves opposite on the twig, simple          2",
    "1. Leaves alternate on the twig, compound       3",
    "2. Fruit a double samara                        Acer rubrum",
    "2. Fruit a drupe, red or black                  Cornus florida",
    "3. Buds clustered at the tip                    Quercus alba",
    "3. Buds single at the tip of twig               Fagus grandifolia"
  ))
  expect_identical(shape(p), c("1a>2", "1b>3", "2a>Acer rubrum", "2b>Cornus florida", "3a>Quercus alba",
                               "3b>Fagus grandifolia"))
  expect_identical(nrow(p$problems), 0L)

  # two leads side by side that cannot be told apart safely are a problem
  p <- parseTextKey(c(
    "1. Leaves opposite .... 2   5. Fruit red .... Ilex",
    "1. Leaves alternate .... 3   5. Fruit black .... Rhamnus"
  ))
  expect_true("two_columns" %in% serious(p)$Type)
})

test_that("a byte order mark, a bad `skip` and odd input do not lose leads or give obscure errors", {
  p <- parseTextKey("﻿1a. Wings present .... 2\r\n1b. Wings absent .... Apterygota\r\n2a. Two wings .... Diptera\r\n2b. Four wings .... Odonata\r\n")
  expect_identical(shape(p), c("1a>2", "1b>Apterygota", "2a>Diptera", "2b>Odonata"))
  expect_identical(nrow(p$problems), 0L)
  expect_error(parseTextKey("1a. A .... 2", skip = "(["), "`skip` must be one regular expression")
  expect_error(parseTextKey("1a. A .... 2", skip = c("a", "b")), "`skip`")
  expect_error(parseTextKey(character()), "`text` must be")
  expect_error(parseTextKey(42), "`text` must be")
  expect_identical(serious(parseTextKey(NA_character_))$Type, "no_leads")
  expect_identical(serious(parseTextKey(c("", "  ", "\t")))$Type, "no_leads")
  one <- parseTextKey("1a. Wings present .... Diptera")
  expect_identical(nrow(one$leads), 1L)
  expect_identical(serious(one)$Type, "single_lead")
})

test_that("a key that starts above couplet 1 says which couplets are missing", {
  p <- parseTextKey(c("3. Fruit dry .... Acer", "3. Fruit fleshy .... 4", "4. Bark white .... Betula", "4. Bark dark .... Prunus"))
  expect_identical(nrow(p$leads), 4L)
  bad <- serious(p)
  expect_identical(bad$Type, "missing_start")
  expect_identical(bad$Line, 1L)
  expect_match(bad$Message, "couplets 1 to 2 were not found")
})

test_that("llm: text only the model wrote, chatter around the answer, leads lost in any layout", {
  src <- c("KEY TO INSECTS", "1 Wings present .... 2", "- Wings absent .... Apterygota", "2 Two wings .... Diptera",
           "- Four wings .... 3", "3 Wings scaly .... Lepidoptera", "- Wings clear .... Hymenoptera")
  # the model drops couplet 3 and sends 2b to a name; the source has no punctuated labels to count
  short <- function(text) "1a. Wings present .... 2\n1b. Wings absent .... Apterygota\n2a. Two wings .... Diptera\n2b. Four wings .... Lepidoptera"
  p <- parseTextKey(src, llm = short)
  bad <- serious(p)
  expect_true("llm_lost_leads" %in% bad$Type)
  expect_match(bad$Message[bad$Type == "llm_lost_leads"], "4 lead\\(s\\) but 6 line\\(s\\).*line\\(s\\) 6, 7")
  expect_identical(bad$Line[bad$Type == "llm_lost_leads"], 6L)
  expect_true("llm_destination" %in% bad$Type)

  # the title is the one in the source, not what the model wrote above its answer
  chatty <- function(text) paste0("Here is the cleaned key:\n\n", paste(src[-1], collapse = "\n"), "\n\nAnything else?")
  p <- parseTextKey(src, llm = chatty)
  expect_identical(p$title, "KEY TO INSECTS")
  expect_identical(nrow(p$leads), 6L)

  # an invented couplet with a one-word text is still caught
  invented <- function(text) {
    data.frame(couplet = c(1, 1, 2, 2, 3, 3, 9, 9), lead = rep(c("a", "b"), 4),
               text = c("Wings present", "Wings absent", "Two wings", "Four wings", "Wings scaly", "Wings clear",
                        "Legs six", "Legs eight"),
               destination = c("2", "Apterygota", "Diptera", "3", "Lepidoptera", "Hymenoptera", "Insecta", "Arachnida"))
  }
  p <- parseTextKey(src, llm = invented)
  bad <- serious(p)
  expect_identical(sum(bad$Type == "llm_text"), 2L)
  expect_identical(sum(bad$Type == "llm_taxon"), 2L)
  expect_true(any(bad$Type == "unreachable" & bad$Couplet == "9"))
  expect_identical(p$leads$Line[1:6], 2:7)
  expect_true(all(is.na(p$leads$Line[7:8])))
  expect_match(bad$Message[bad$Type == "llm_text"], "row [78] of the model's answer")

  # answers that are not leads at all
  expect_error(parseTextKey(src, llm = function(text) '{"error": "cannot read"}'), "not a list of leads")
  expect_error(parseTextKey(src, llm = function(text) '[{"couplet": 1, "text": "Wings present"}]'), "needs the columns")
  expect_error(parseTextKey(src, llm = function(text) '[{"couplet": 1, "lead": "a", "te'), "cannot be read")
  expect_error(parseTextKey(src, llm = function(text) "I cannot help with that."), "No leads were found")
  expect_error(parseTextKey(src, llm = function(text) NULL), "must return text")
  expect_error(parseTextKey(src, llm = function(text) stop("rate limit")), "`llm` failed: rate limit")
  expect_error(parseTextKey(src, llm = function() "x"), "`llm` failed")
  # a missing destination in JSON is a problem on the line of that lead
  p <- parseTextKey(src, llm = function(text) {
    '[{"couplet": 1, "lead": "a", "text": "Wings present", "destination": null},
      {"couplet": 1, "lead": "b", "text": "Wings absent", "destination": "Apterygota"}]'
  })
  bad <- serious(p)
  expect_identical(bad$Line[bad$Type == "no_destination"], 2L)
  expect_true("llm_lost_leads" %in% bad$Type)
})
