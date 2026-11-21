tdwgFixture <- function(...) test_path("fixtures", "tdwg", ...)
tdwgExample <- function(...) {
  system.file("extdata", "tdwg", ..., package = "dimoose", mustWork = TRUE)
}
tdwgWriteDelta <- function(specs = "", chars, items, dir = withr::local_tempdir(.local_envir = parent.frame())) {
  writeLines(specs, file.path(dir, "specs"))
  writeLines(c("*CHARACTER LIST", chars), file.path(dir, "chars"))
  writeLines(c("*ITEM DESCRIPTIONS", items), file.path(dir, "items"))
  dir
}
# The grass fixture is broken on purpose in three places
tdwgReadGrasses <- function(...) {
  suppressWarnings(readDELTA(tdwgFixture("delta"), ...))
}

test_that("readDELTA reads the example dataset", {
  d <- readDELTA(tdwgExample("beetles-delta"))
  expect_s3_class(d, "tdwgData")
  m <- d$matrix
  expect_equal(m$Taxon, c("Aphodius exemplaris", "Carabus fictus", "Lucanus imaginarius"))
  expect_named(m, c("Taxon", "antennal club", "pronotum", "eyes", "frons",
                    "number of lamellae in antennal club", "length", "comments"))
  expect_equal(m$`antennal club`, c("present", "absent", "present"))
  # "2,2/2&3<striped>" and "2,1/2<rare>"
  expect_equal(m$pronotum, c("black/yellow", "red/black", "black"))
  # eyes are implicitly of normal size
  expect_equal(m$eyes, c("of normal size", "very large", "of normal size"))
  # "4,1-3" of an ordered character takes in the state in between; "4,U" is unknown
  expect_equal(m$frons[1], paste("with setae on anterior middle and above eyes", "with setae above eyes only",
                                 "without setae", sep = "/"))
  expect_equal(m$frons[2:3], c("without setae", NA))
  expect_equal(m$`number of lamellae in antennal club`, c("3", NA, "4-6"))
  expect_equal(m$length, c("(4-)5-6.5", "22-28", "30-45(-60)"))
  expect_equal(m$comments, c("common in dung", NA, "possibly two species"))

  ch <- d$characters
  expect_equal(ch$Type, c("categorical", "categorical", "categorical", "ordered", "integer", "real", "text"))
  expect_equal(ch$States[2], "red/black/yellow")
  expect_equal(ch$Unit[6], "mm")
  expect_equal(ch$InapplicableIf[5], "antennal club=absent")
  expect_equal(d$taxa$Comment, c("Smith", "Jones & Brown", "Lee"))
  expect_equal(d$meta$value[d$meta$key == "title"], "Three beetles")
})

test_that("the three files can be given one by one, and dependent characters become inapplicable", {
  dir <- tdwgExample("beetles-delta")
  d <- readDELTA(file.path(dir, "specs"), file.path(dir, "chars"), file.path(dir, "items"),
                 taxon = "Species", inapplicable = "n/a")
  expect_equal(names(d$matrix)[1], "Species")
  # no antennal club, so no lamellae to count
  expect_equal(d$matrix$`number of lamellae in antennal club`, c("3", "n/a", "4-6"))
  expect_identical(readDELTA(dir, inapplicable = "n/a", taxon = "Species")$matrix, d$matrix)
})

test_that("readDELTA copes with a realistic dataset", {
  expect_warning(expect_warning(expect_warning(
    d <- readDELTA(tdwgFixture("delta"), inapplicable = "n/a"),
    "1 attribute\\(s\\) could not be read"), "replaced by"), "2 state number\\(s\\)")
  m <- d$matrix
  # typesetting marks and authorities are taken off the names; Windows-1252 is read
  expect_equal(m$Taxon, c("Echinochloa", "Bambusa", "Chloris", "Chloris (2)", "Zea", "Bro\u00f6mus"))
  expect_equal(d$taxa$Comment[c(1, 2, 4)], c("P. Beauv.", "Schreber <1789>", "awned form"))
  # comments are dropped from character names, and duplicates numbered
  expect_equal(d$characters$Character,
               c("including", "culms", "culms (2)", "ligule", "ligule (2)", "awns", "awns (2)", "awns (3)",
                 "Inflorescence", "leaf blades", "spikelets", "notes"))
  expect_equal(d$characters$Type,
               c("text", "real", "categorical", "categorical", "ordered", "categorical", "categorical", "integer",
                 "categorical", "categorical", "real", "text"))
  expect_equal(d$characters$Unit[c(2, 11)], c("cm high", "mm long"))
  # a state description wrapped over two lines, with "and/or" in it
  expect_equal(d$characters$States[7], "straight and|or flexuous/geniculate/hooked")
  expect_equal(d$characters$States[4], "present/absent")
  expect_equal(d$characters$InapplicableIf[c(5, 7, 8)],
               c("ligule=absent", "awns=present/reduced to a mucro", "awns=present/reduced to a mucro"))

  # text characters take the comment, which may run over lines
  expect_equal(m$including, c("Ornithospermum Dumoulin, Tema Adans.", NA, NA, NA, NA, NA))
  expect_equal(m$notes[1:2], c("Metcalfe 1960; this project", "bamboos"))
  # numeric values are kept as written; U is unknown, - not applicable
  expect_equal(m$culms, c("40-360", "(200-)500-3500", "10-300", "10-300", NA, NA))
  expect_equal(m$spikelets, c("2.3-7", "10-45-80(-110)", "1.5/3-4", "1.5/3-4", "n/a", "6"))
  # V is every state
  expect_equal(m$`culms (2)`[3], "woody and persistent/herbaceous")
  # implicit values: 4,1 for a ligule not mentioned; 6,2:1 gives "present" to a bare "6"
  expect_equal(m$ligule, c("present", "absent", "present", "present", "present", "present"))
  expect_equal(m$awns, c("present", "present", "reduced to a mucro", "present", "absent", "absent"))
  # a comment before the value ("5<when present,>,3"); no ligule so no ligule form;
  # an ordered range 1-3; the variant item's own "5,2/4"; an explicit "-"; state 7 does not exist
  expect_equal(m$`ligule (2)`,
               c("a fringe of hairs", "n/a", "an unfringed membrane/a fringed membrane/a fringe of hairs",
                 "a fringed membrane/a rim of minute papillae", "n/a", NA))
  # a comment holding a numero and a slash does not break the item; awns present or
  # reduced makes the awn characters inapplicable unless they are coded
  # (an explicit "7,U" does not make them applicable)
  expect_equal(m$`awns (2)`, c("straight and|or flexuous/hooked", "n/a", "n/a", "geniculate", "geniculate", NA))
  expect_equal(m$`awns (3)`, c("1-3", "n/a", "n/a", "3", NA, NA))
  # nested comments; an unordered range 1-3 is just its two ends; "1&2"
  expect_equal(m$Inflorescence, c("a panicle", "a panicle/a spike", "a spike", "a spike", "a panicle", NA))
  expect_equal(m$`leaf blades`, c("narrow/medium", "broad", "narrow/broad", "narrow/broad", "broad", "medium"))
})

test_that("comments can be kept in names", {
  d <- tdwgReadGrasses(comments = TRUE)
  expect_equal(d$characters$Character[c(3, 4, 12)],
               c("culms <whether woody or herbaceous>", "<adaxial> ligule <presence>", "<notes>"))
  expect_equal(d$matrix$Taxon[1], "Echinochloa <P. Beauv.>")
  expect_match(d$characters$States[4], "<consistently> present <<implicit>>", fixed = TRUE)
})

test_that("a dataset in one file without a character list reads too", {
  d <- readDELTA(tdwgFixture("onefile.dlt"))
  expect_equal(d$matrix$Taxon, c("First taxon", "Second taxon"))
  expect_named(d$matrix, c("Taxon", paste("Character", 1:4)))
  expect_equal(d$matrix$`Character 2`, c("1/3", "2"))
  expect_equal(d$matrix$`Character 3`, c("4", "5-9"))
  expect_equal(d$matrix$`Character 4`, c("hello", NA))
  expect_equal(d$characters$States[1:2], c("1/2", "1/2/3"))
  expect_equal(d$characters$Type, c("categorical", "categorical", "integer", "text"))
})

test_that("abbreviated directives and missing terminating slashes are understood", {
  dir <- tdwgWriteDelta(
    specs = c("*NUM OF CHA 2", "*CHA TYP 2,RN"),
    chars = c("#1. colour/", "  1. red/", "  2. blue", "#2. size/ cm/"),
    items = c("# One/ 1,1 2,3.5", "# Two/", "1,2 2,-1-4")
  )
  d <- readDELTA(dir)
  expect_equal(d$matrix$colour, c("red", "blue"))
  expect_equal(d$matrix$size, c("3.5", "-1-4"))
  expect_equal(d$characters$Unit[2], "cm")
})

test_that("readDELTA says so when the files are not DELTA", {
  dir <- withr::local_tempdir()
  expect_error(readDELTA(dir), "needs files named chars and items")
  f <- file.path(dir, "plain.txt")
  writeLines("just some text", f)
  expect_error(readDELTA(f), "do not look like DELTA")
  expect_error(readDELTA(file.path(dir, "missing")), "not found")
})

test_that("writeDELTA then readDELTA gives the same matrix", {
  m <- data.frame(
    Taxon = c("Apis mellifera", "Bombus terrestris", "Vespula vulgaris", "Osmia"),
    Hair = c("sparse", "dense", "sparse/absent", NA),
    Sting = c("barbed", "smooth", "-", NA),
    Size = c("small", "small/large", "medium", "small"),
    "Body length" = c("12-15", "(11-)14-17(-22)", "11-14-19", "8"),
    Segments = c(12, 12, NA, 13),
    Notes = c("makes honey <a lot>", NA, "builds paper nests", NA),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  chars <- data.frame(
    Character = c("Hair", "Sting", "Size", "Body length", "Notes"),
    Type = c("categorical", "categorical", "ordered", "real", "text"),
    States = c("absent/sparse/dense", "", "small/medium/large", "", ""),
    Unit = c("", "", "", "mm", ""),
    InapplicableIf = c("", "Hair=absent", "", "", ""),
    stringsAsFactors = FALSE
  )
  dir <- file.path(withr::local_tempdir(), "bees")
  paths <- writeDELTA(m, dir, characters = chars, inapplicable = "-", title = "Bees and wasps")
  expect_named(paths, c("specs", "chars", "items"))
  expect_true(all(file.exists(paths)))

  specs <- readLines(paths[["specs"]])
  expect_true("*NUMBER OF CHARACTERS 6" %in% specs)
  expect_true("*MAXIMUM NUMBER OF STATES 3" %in% specs)
  expect_true("*CHARACTER TYPES 3,OM 4,RN 5,IN 6,TE" %in% specs)
  expect_true("*NUMBERS OF STATES 1,3 3,3" %in% specs)
  expect_true("*DEPENDENT CHARACTERS 1,1:2" %in% specs)
  chars_txt <- readLines(paths[["chars"]])
  expect_true(all(c("#1. Hair/", "       1. absent/", "#4. Body length/ mm/") %in% chars_txt))
  items <- readLines(paths[["items"]])
  expect_true("# Vespula vulgaris/" %in% items)
  expect_true("1,1/2 2,- 3,2 4,11-14-19 6<builds paper nests>" %in% items)

  d <- readDELTA(dir, inapplicable = "-")
  back <- d$matrix
  expect_equal(back$Taxon, m$Taxon)
  expect_equal(back$Hair, c("sparse", "dense", "absent/sparse", NA))
  expect_equal(back$Sting, m$Sting)
  # an ordered character polymorphic for its ends is written 1/3, not 1-3
  expect_equal(back$Size, m$Size)
  expect_equal(back$`Body length`, m$`Body length`)
  expect_equal(back$Segments, c("12", "12", NA, "13"))
  # brackets that pair up inside a text are a comment within the comment
  expect_equal(back$Notes, m$Notes)
  expect_equal(d$characters$Type, c("categorical", "categorical", "ordered", "real", "integer", "text"))
  expect_equal(d$characters$InapplicableIf[2], "Hair=absent")
  expect_equal(d$characters$Unit[4], "mm")
  expect_equal(d$meta$value[d$meta$key == "title"], "Bees and wasps")

  # once read, writing and reading again changes nothing
  again <- readDELTA(dirname(writeDELTA(d, file.path(dir, "again"), inapplicable = "-")[1]), inapplicable = "-")
  expect_identical(again$matrix, d$matrix)
  expect_identical(again$characters, d$characters)
})

test_that("the fixtures survive a round trip through writeDELTA", {
  for (d in list(readDELTA(tdwgExample("beetles-delta"), inapplicable = "n/a"),
                 tdwgReadGrasses(inapplicable = "n/a"))) {
    dir <- withr::local_tempdir()
    writeDELTA(d, dir, inapplicable = "n/a", files = c(specs = "specs.txt", chars = "CHARS", items = "items.dat"))
    back <- readDELTA(dir, inapplicable = "n/a")
    expect_identical(back$matrix, d$matrix)
    expect_identical(back$characters, d$characters)
  }
})

test_that("DELTA and SDD carry the same matrix", {
  d <- readDELTA(tdwgExample("beetles-delta"), inapplicable = "n/a")
  f <- withr::local_tempfile(fileext = ".xml")
  writeSDD(d, f, inapplicable = "n/a")
  s <- readSDD(f, inapplicable = "n/a")
  expect_identical(s$matrix, d$matrix)
  expect_identical(s$characters$InapplicableIf, d$characters$InapplicableIf)
  dir <- withr::local_tempdir()
  writeDELTA(s, dir, inapplicable = "n/a")
  expect_identical(readDELTA(dir, inapplicable = "n/a")$matrix, d$matrix)
})

test_that("writeDELTA copes with awkward cells", {
  m <- data.frame(Taxon = c("A", "B"), Length = c("about 5", "5/10-15"), Empty = NA_character_,
                  stringsAsFactors = FALSE)
  chars <- data.frame(Character = "Length", Type = "real")
  dir <- withr::local_tempdir()
  expect_warning(writeDELTA(m, dir, characters = chars), "without any state")
  items <- readLines(file.path(dir, "items"))
  # not a number, so written as a comment; alternatives stay alternatives
  expect_true(all(c("1<about 5>", "1,5/10-15") %in% items))
  d <- readDELTA(dir)
  expect_equal(d$matrix$Length, c(NA, "5/10-15"))
  expect_equal(d$characters$Type, c("real", "text"))
  expect_error(writeDELTA(m, dir, files = c("a", "b")), "must name")
})

test_that("a matrix read from DELTA feeds keyFromMatrix", {
  skip_if_not(exists("keyFromMatrix", mode = "function"), "keyFromMatrix() is not there yet")
  d <- readDELTA(tdwgExample("beetles-delta"))
  k <- keyFromMatrix(d$matrix, taxon = "Taxon")
  expect_s3_class(k, "dimoose")
})

# ---- found when reading real third-party datasets ----------------------------------

test_that("typesetting marks of real DELTA files are removed or turned into characters", {
  expect_equal(tdwgDeltaPlain("\\i{}Poa\\i0{} L."), "Poa L.")
  # bare marks, as older files have them
  expect_equal(tdwgDeltaPlain("Rydb.\\i\\par{} Taraxacum"), "Rydb. Taraxacum")
  expect_equal(tdwgDeltaPlain("\\i{}Dryas\\i0, \\i{}Oxyria\\i0."), "Dryas, Oxyria.")
  expect_equal(tdwgDeltaPlain("C\\sub{}4\\nosupersub{} type"), "C4 type")
  expect_equal(tdwgDeltaPlain("a\\endash{}b \\emdash{} \\ldblquote{}c\\rdblquote"), "a\u2013b \u2014 \u201cc\u201d")
  expect_equal(tdwgDeltaPlain("\\par{}\\li0{}\\fi0{}\\sb0{}Text \\b{}bold\\b0{} end"), "Text bold end")
  expect_equal(tdwgDeltaPlain("polyprotein \\{3' region\\}"), "polyprotein {3' region}")
  # a mark run into the next word only loses the mark
  expect_equal(tdwgDeltaPlain("\\iLedum{} x"), "Ledum x")
  expect_equal(tdwgDeltaPlain(c(NA, "plain  text ")), c(NA, "plain text"))
})

test_that("names are tidy once the typesetting marks are gone", {
  # "\i{}Poa alpina \i0{}" used to leave a blank at the end, and the same name
  # written twice with and without it then stopped every writer
  dir <- tdwgWriteDelta(
    specs = "*CHARACTER TYPES 1,TE",
    chars = c("#1. <<af1 ag2>> <common name>/", "#2. <<af2>> <habit>/", "  1. tufted/", "  2. creeping \\i{}or\\i0{}  mat-forming/"),
    items = c("# \\i{}Poa alpina \\i0{}/", "1<alpine  \\b{}meadow-grass\\b0{}> 2,1",
              "# \\i{}Poa alpina\\i0{} var. \\i{}vivipara \\i0{} <L.>/", "2,2",
              "# \\i{}Huperzia selago \\i0{} var. \\i{}selago\\i0{}/", "2,1")
  )
  d <- readDELTA(file.path(dir, "specs"), file.path(dir, "chars"), file.path(dir, "items"))
  expect_equal(d$matrix$Taxon, c("Poa alpina", "Poa alpina var. vivipara", "Huperzia selago var. selago"))
  expect_equal(d$taxa$Comment, c("", "L.", ""))
  # a name that is only comments: the comment, without the notes nested in it
  expect_named(d$matrix, c("Taxon", "common name", "habit"))
  expect_equal(d$characters$States[2], "tufted/creeping or mat-forming")
  expect_equal(d$matrix$habit, c("tufted", "creeping or mat-forming", "tufted"))
  out <- writeDELTA(d, withr::local_tempdir())
  expect_identical(readDELTA(dirname(out[1]))$matrix, d$matrix)
  kept <- readDELTA(file.path(dir, "specs"), file.path(dir, "chars"), file.path(dir, "items"), comments = TRUE)
  expect_equal(names(kept$matrix)[2:3], c("<<af1 ag2>> <common name>", "<<af2>> <habit>"))
})

test_that("the title is found in the headings real datasets have", {
  title <- function(show) {
    f <- withr::local_tempfile()
    writeLines(c(show, "*ITEM DESCRIPTIONS", "# A/ 1,1"), f)
    d <- readDELTA(f)
    d$meta$value[d$meta$key == "title"]
  }
  expect_equal(title("*SHOW ~ Grass Genera - specifications."), "Grass Genera")
  expect_equal(title("*SHOW Combined Arctic flowering plants - specifications. 6 January 1998"),
               "Combined Arctic flowering plants")
  expect_equal(title("*SHOW ~ Virus specifications. Edited 26th Jan 1996."), "Virus")
  expect_equal(title("*SHOW ~ Test Data Set - specs"), "Test Data Set")
  expect_equal(title("*SHOW ~ \\i{}Poa\\i0{} of the world \\endash{} item descriptions"), "Poa of the world")
})

test_that("\"and\" binds more loosely than \"to\" in a multistate attribute", {
  dir <- tdwgWriteDelta(
    specs = "*CHARACTER TYPES 1,OM", chars = c("#1. size/", " 1. tiny/", " 2. small/", " 3. medium/", " 4. large/", " 5. huge/"),
    items = c("# A/ 1,1-2&4", "# B/ 1,1&3-5", "# C/ 1,2/4-5")
  )
  d <- readDELTA(dir)
  expect_equal(d$matrix$size, c("tiny/small/large", "tiny/medium/large/huge", "small/large/huge"))
})

test_that("nested and unmatched comment brackets in items are told apart", {
  dir <- tdwgWriteDelta(
    specs = "*CHARACTER TYPES 3,TE 4,IN",
    chars = c("#1. a/", " 1. x/", " 2. y/", "#2. b/", " 1. p/", " 2. q/", "#3. notes/", "#4. n/"),
    items = c("# T1 <Auth. <1900> ex B.>/", "1,1<<10%> rarely, see #2 / 3>/2 2<when present,>,2 3<first><second <inner>> 4,3-5<or more>",
              "# T2/", "1,2 3<a (b)> 2,1")
  )
  d <- readDELTA(dir)
  expect_equal(d$matrix$Taxon, c("T1", "T2"))
  expect_equal(d$taxa$Comment[1], "Auth. <1900> ex B.")
  expect_equal(d$matrix$a, c("x/y", "y"))
  expect_equal(d$matrix$b, c("q", "p"))
  expect_equal(d$matrix$notes, c("first; second <inner>", "a (b)"))
  expect_equal(d$matrix$n, c("3-5", NA))
  masked <- tdwgDeltaMask("a <b <c> d> e <f g> h> <i", strict = FALSE)
  expect_equal(masked$store, c("<b <c> d>", "<f g>"))
  expect_equal(tdwgDeltaUnmask(masked$text, masked$store, keep = TRUE), "a <b <c> d> e <f g> h> <i")
  expect_equal(tdwgDeltaUnmask(masked$text, masked$store), "a  e  h> <i")
  expect_equal(tdwgDeltaMask("no comments", strict = FALSE)$store, character())
})

test_that("megabytes of item descriptions are read in seconds", {
  skip_on_cran()
  # reading used to take time quadratic in the size of the items file: a real
  # dataset of 2.7 MB (969 viruses) took more than three minutes
  item <- function(i) {
    c(sprintf("# Taxon %d <Author %d>/", i, i),
      paste(sprintf("%d,%d<comment <nested %d> with words, slashes / and r\u00e9sum\u00e9>", 1:40, 1 + (i + 1:40) %% 2, i), collapse = " "))
  }
  dir <- tdwgWriteDelta(chars = sprintf("#%d. character %d/ 1. yes/ 2. no/", 1:40, 1:40), items = unlist(lapply(1:500, item)))
  expect_gt(file.size(file.path(dir, "items")), 1.2e6)
  elapsed <- system.time(d <- readDELTA(dir))[["elapsed"]]
  expect_equal(dim(d$matrix), c(500L, 41L))
  expect_equal(d$matrix[[2]][1:3], c("yes", "no", "yes"))
  expect_false(anyNA(d$matrix))
  expect_lt(elapsed, 30)
})

test_that("a file in neither UTF-8 nor Windows-1252 is still read", {
  f <- withr::local_tempfile()
  # 0x81 means nothing in Windows-1252
  writeBin(c(charToRaw("*ITEM DESCRIPTIONS\n# Caf"), as.raw(0xe9), charToRaw(" x"), as.raw(0x81), charToRaw("/\n1,1\n")), f)
  d <- readDELTA(f)
  expect_match(d$matrix$Taxon, "^Caf\u00e9 x")
  expect_equal(d$matrix[[2]], "1")
})

test_that("writeDELTA keeps text from being read as DELTA syntax", {
  m <- data.frame(
    Taxon = c("Aus bus *SHOW me", "Cus #2. dus", "Eus / fus /"),
    "Ratio head + body / tail" = c("long", "short", "long"),
    Notes = c("see *SHOW and #5. five/ six", "nested <like <this>> one", "odd > bracket < here"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  chars <- data.frame(Character = "Notes", Type = "text", stringsAsFactors = FALSE)
  title <- paste(rep("A very long title of a dataset", 6), collapse = ", ")
  out <- writeDELTA(m, withr::local_tempdir(), characters = chars, title = title)
  lines <- unlist(lapply(out, readLines))
  expect_true(all(nchar(lines) <= 78))
  # no star or numero where DELTA would read a directive, a character or an item
  # (the nine stars left are the directives the three files are made of)
  expect_equal(sum(grepl("(^|\\s)\\*", lines)), 9)
  expect_equal(sum(grepl("^#", readLines(out[["items"]]))), 3)
  d <- readDELTA(dirname(out[1]))
  expect_equal(d$matrix$Taxon, c("Aus bus (*)SHOW me", "Cus (#)2. dus", "Eus /fus"))
  expect_named(d$matrix, c("Taxon", "Ratio head + body /tail", "Notes"))
  expect_equal(d$matrix[[2]], m[[2]])
  # brackets that pair up stay as they are, others become parentheses
  expect_equal(d$matrix$Notes, c("see (*)SHOW and #5. five/ six", "nested <like <this>> one", "odd ) bracket ( here"))
  expect_equal(d$meta$value[d$meta$key == "title"], title)
})

test_that("the writers refuse a matrix without rows or with a column name used twice", {
  m <- data.frame(Taxon = c("A", "B"), X = c("a", "b"), X = c("c", "d"), check.names = FALSE)
  expect_error(writeDELTA(m, withr::local_tempdir()), "used more than once in the matrix: X")
  expect_error(writeDELTA(m[0, 1:2], withr::local_tempdir()), "no rows")
})
