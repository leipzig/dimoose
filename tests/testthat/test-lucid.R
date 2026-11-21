tdwgFixture <- function(...) test_path("fixtures", "tdwg", ...)
tdwgExample <- function(...) {
  system.file("extdata", "tdwg", ..., package = "dimoose", mustWork = TRUE)
}
tdwgTempFile <- function(lines, ext, env = parent.frame()) {
  f <- withr::local_tempfile(fileext = ext, .local_envir = env)
  writeLines(lines, f)
  f
}

test_that("readLucid reads a Builder CSV export", {
  d <- readLucid(tdwgExample("bears-lucid.csv"))
  expect_s3_class(d, "tdwgData")
  m <- d$matrix
  # the last step of each path is the name
  expect_equal(m$Taxon, c("Ursus arctos", "Ursus maritimus", "Ursus americanus", "Ailuropoda melanoleuca"))
  expect_named(m, c("Taxon", "Colour", "Shoulder hump", "Diet", "Head and body length"))
  # 1 common and 2 rare both count
  expect_equal(m$Colour, c("brown", "white", "brown/black", "white/black"))
  expect_equal(m$`Shoulder hump`, c("present", "absent", "absent", "absent"))
  # 3 uncertain counts too
  expect_equal(m$Diet, c("mixed/mostly plants", "mostly meat", "mixed", "mostly plants"))
  # type:outside low:low:high:outside high
  expect_equal(m$`Head and body length`, c("(1.4-)1.7-2.8(-3)", "(1.8-)2-2.5(-2.8)", "(1.2-)1.3-1.9", "1.2-1.9"))
  expect_equal(d$characters$Type, c("categorical", "categorical", "categorical", "real"))
  expect_equal(d$characters$States[1], "white/brown/black")
  expect_equal(d$characters$Path, c("Coat:Colour", "Shoulder hump", "Diet", "Body:Head and body length"))
  expect_equal(d$taxa$Path[1], "Ursidae:Ursus:Ursus arctos")

  full <- readLucid(tdwgExample("bears-lucid.csv"), fullNames = TRUE, scores = 1)
  expect_equal(names(full$matrix)[2], "Coat:Colour")
  expect_equal(full$matrix$Taxon[4], "Ursidae:Ailuropoda:Ailuropoda melanoleuca")
  # only "common" counts now
  expect_equal(full$matrix$`Coat:Colour`[3], "black")
  expect_equal(full$matrix$Diet[1], "mixed")
})

test_that("Lucid scores are told apart", {
  f <- tdwgTempFile(c(
    ",A,B,C,D,E",
    "Wings:present,1,4,3,6,0",
    "Wings:absent,0,1,3,6,0",
    "Legs:six,5,2,,1,1",
    "Legs:eight,1,0,,3,0",
    "Tail:Length#,1:2:2:2:2,3:0:0:0:0,6:0:0:0:0,0,4:1:1:9:9",
    "Flies,1,0,0,1,1"
  ), ".csv")
  # the help does not list the score types of a numeric feature: only 1 (and
  # the plain 0 of a feature that is not scored) are known from a real export
  expect_warning(d <- readLucid(f, inapplicable = "n/a"), "type 3, 4 read as unknown")
  # misinterpretations are not states of the taxon; all uncertain is unknown; 6 is not scoped
  expect_equal(d$matrix$Wings, c("present", "absent", NA, "n/a", NA))
  expect_equal(d$matrix$Legs, c("eight", "six", NA, "six/eight", "six"))
  # only a normal numeric score gives a value
  expect_equal(d$matrix$Length, c("2", NA, "n/a", NA, NA))
  # a row without a colon is a feature that is simply present
  expect_equal(d$matrix$Flies, c("present", NA, NA, "present", "present"))
  expect_equal(d$characters$Path[3], "Tail:Length")

  # with misinterpretations counted
  d <- suppressWarnings(readLucid(f, scores = 1:5))
  expect_equal(d$matrix$Wings[2], "present/absent")
  expect_equal(d$matrix$Legs[1], "six/eight")
})

test_that("the transposed CSV (entities as rows) is read", {
  f <- tdwgTempFile(c(
    ",Wings:present,Wings:absent,Size#",
    "Fly,1,0,1:5:5:8:8",
    "Flea,0,1,1:1:1:3:4"
  ), ".csv")
  d <- readLucid(f, entities = "rows")
  expect_equal(d$matrix$Taxon, c("Fly", "Flea"))
  expect_equal(d$matrix$Wings, c("present", "absent"))
  expect_equal(d$matrix$Size, c("5-8", "1-3(-4)"))
})

test_that("writeLucid then readLucid gives the same matrix", {
  m <- data.frame(
    Taxon = c("Apis mellifera", "Bombus terrestris", "Vespula: vulgaris", "Osmia"),
    Hair = c("sparse", "dense", "sparse/absent", NA),
    Sting = c("barbed", "smooth", "-", NA),
    "Body length" = c("12-15", "(11-)14-17(-22)", "11-14-19", "8"),
    Segments = c(12, 12, NA, 13),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  chars <- data.frame(Character = c("Hair", "Body length"), Type = c("categorical", "real"),
                      States = c("absent/sparse/dense", ""), stringsAsFactors = FALSE)
  f <- withr::local_tempfile(fileext = ".csv")
  expect_identical(writeLucid(m, f, characters = chars, inapplicable = "-"), f)
  lines <- readLines(f)
  # quoted as the Lucid Builder does: names are, the first cell and scores are not
  expect_equal(lines[1], ",\"Apis mellifera\",\"Bombus terrestris\",\"Vespula - vulgaris\",\"Osmia\"")
  expect_equal(lines[2], "\"Hair:absent\",0,0,1,0")
  expect_equal(lines[5], "\"Sting:barbed\",1,0,6,0")
  expect_equal(lines[7], "\"Body length#\",1:12:12:15:15,1:11:14:17:22,1:11:11:19:19,1:8:8:8:8")
  # a numeric feature that is not scored is a plain 0
  expect_equal(lines[8], "\"Segments#\",1:12:12:12:12,1:12:12:12:12,0,1:13:13:13:13")

  d <- readLucid(f, inapplicable = "-")
  back <- d$matrix
  expect_equal(back$Taxon, c("Apis mellifera", "Bombus terrestris", "Vespula - vulgaris", "Osmia"))
  expect_equal(back$Hair, c("sparse", "dense", "absent/sparse", NA))
  expect_equal(back$Sting, m$Sting)
  # Lucid has no place for a mean within the range
  expect_equal(back$`Body length`, c("12-15", "(11-)14-17(-22)", "11-19", "8"))
  expect_equal(back$Segments, c("12", "12", NA, "13"))

  # written again, in either orientation, nothing changes
  for (entities in c("columns", "rows")) {
    f2 <- withr::local_tempfile(fileext = ".csv")
    writeLucid(d, f2, inapplicable = "-", entities = entities)
    again <- readLucid(f2, inapplicable = "-", entities = entities)
    expect_identical(again$matrix, d$matrix)
    expect_identical(again$characters, d$characters)
  }
})

test_that("the paths of a Lucid export survive a round trip", {
  d <- readLucid(tdwgExample("bears-lucid.csv"))
  f <- withr::local_tempfile(fileext = ".csv")
  writeLucid(d, f)
  expect_match(readLines(f)[2], "^\"Coat:Colour:white\"")
  back <- readLucid(f)
  expect_identical(back$matrix, d$matrix)
  expect_identical(back$characters, d$characters)
  expect_identical(back$taxa, d$taxa)
})

test_that("writeLucid leaves out what Lucid cannot hold", {
  m <- data.frame(Taxon = c("A", "B"), Colour = c("red", "blue"), Notes = c("x", "y"), Size = c("big", "5"),
                  stringsAsFactors = FALSE)
  chars <- data.frame(Character = c("Notes", "Size"), Type = c("text", "real"))
  f <- withr::local_tempfile(fileext = ".csv")
  expect_warning(expect_warning(writeLucid(m, f, characters = chars), "no text characters"), "Not a number or range")
  d <- readLucid(f)
  expect_named(d$matrix, c("Taxon", "Colour", "Size"))
  expect_equal(d$matrix$Size, c(NA, "5"))
  expect_error(writeLucid(m, f, format = "lif3"), "does not write LIF")
  expect_error(writeLucid(m[c("Taxon", "Notes")], f, characters = chars), "only text characters")
})

test_that("Lucid's SDD export goes through readSDD and writeSDD", {
  d <- readLucid(tdwgFixture("lucid-export.sdd.xml"))
  expect_equal(d$meta$value[d$meta$key == "format"], "Lucid, SDD")
  expect_equal(d$matrix$Habitat, c("in soil", "floating on water", "on rock/in soil"))
  f <- withr::local_tempfile(fileext = ".xml")
  writeLucid(d, f, format = "sdd", title = "Ferns again")
  back <- readLucid(f)
  expect_identical(back$matrix, d$matrix)
  expect_equal(back$meta$value[back$meta$key == "title"], "Ferns again")
})

test_that("readLucid reads the multistate scores of a LIF3 file", {
  expect_warning(d <- readLucid(tdwgFixture("beetles.lif3"), inapplicable = "n/a"), "replaced by")
  m <- d$matrix
  # the tips of the entity tree; the family above Carabus is not a taxon of its own
  expect_equal(m$Taxon, c("Carabus fictus", "Coccinella exemplaris", "Lucanus imaginarius", "Cetonia dubia"))
  expect_equal(d$taxa$Path[1], "Carabidae:Carabus fictus")
  # two features are called Shape, so those keep their path
  expect_named(m, c("Taxon", "Colour", "Body:Shape", "Body length", "Antennae:Shape"))
  # 1 common, 2 rare; 4 and 5 are misinterpretations
  expect_equal(m$Colour, c("black/metallic green", "black/red and|or orange", "black", "metallic green"))
  # both states uncertain is unknown
  expect_equal(m$`Body:Shape`, c("elongate", "oval", "elongate", NA))
  # 3 uncertain beside a real score; 6 is not scoped
  expect_equal(m$`Antennae:Shape`, c("thread-like", "clubbed", "clubbed/elbowed", "n/a"))
  # a feature without states is numeric, and numeric scores are not read
  expect_equal(m$`Body length`, rep(NA_character_, 4))
  expect_equal(d$characters$Type, c("categorical", "categorical", "real", "categorical"))
  expect_equal(d$characters$Path[1], "Body:Colour")
  meta <- stats::setNames(d$meta$value, d$meta$key)
  expect_equal(meta[["title"]], "Key to test beetles")
  expect_equal(meta[["description"]], "A test key")

  # and on to the CSV that the Builder imports
  f <- withr::local_tempfile(fileext = ".csv")
  writeLucid(d, f, inapplicable = "n/a")
  expect_identical(suppressWarnings(readLucid(f, inapplicable = "n/a"))$matrix, d$matrix)
})

test_that("readLucid warns about numeric LIF3 scores and refuses unspecified formats", {
  text <- readLines(tdwgFixture("beetles.lif3"))
  at <- grep("<container type='numeric'>", text, fixed = TRUE)
  f <- tdwgTempFile(append(text, "<scoring_item item_id='13'><unknown/></scoring_item>", at), ".lif3")
  expect_warning(expect_warning(readLucid(f), "replaced by"), "numeric scores in a layout dimoose does not know")

  lif <- tdwgTempFile(c("[..Key Title..]", "My key", "[..Multimedia Directories..]"), ".lif")
  expect_error(readLucid(lif), "not publicly specified")
  other <- tdwgTempFile(c("<?xml version='1.0'?>", "<LucidKey><x/></LucidKey>"), ".xml")
  expect_error(readLucid(other), "export the key as CSV or SDD")
  expect_error(readLucid(tdwgExample("insects.lpxk")), "readLucidKey")
  expect_error(readLucid(file.path(tempdir(), "no-such.csv")), "not found")
  # the content decides when the extension says nothing
  renamed <- withr::local_tempfile(fileext = ".dat")
  file.copy(tdwgFixture("beetles.lif3"), renamed)
  expect_equal(nrow(suppressWarnings(readLucid(renamed))$matrix), 4)
})

test_that("readLucidKey reads Lucid Phoenix XML", {
  k <- readLucidKey(tdwgExample("insects.lpxk"))
  expect_s3_class(k, "dimoose")
  expect_equal(k$desc, "Some orders of insects")
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2", "3", "3", "4", "4"))
  expect_equal(l$Next, c("2", "3", "-", "-", "4", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "", "Siphonaptera", "Zygentoma", "", "Coleoptera", "Diptera", "Lepidoptera"))
  expect_equal(l$Character[5], "Forewings membranous")
  expect_equal(l$Question[c(1, 3)], c("Wings", "Body shape"))
  expect_length(k$validate(), 0)
})

test_that("the first step of a Phoenix key need not come first, and urls are kept", {
  f <- tdwgTempFile(c(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<PhoenixKey title=\"Two\" CreatedIn=\"Lucid Phoenix\">",
    "<Identity id=\"i0\" name=\"Fly\" icon=\"fly.png\" url=\"html/fly.htm\" />",
    "<Identity id=\"i1\" name=\"Bee &amp; wasp\" icon=\"\" url=\"\" />",
    "<Identity id=\"i2\" name=\"Flea\" icon=\"\" url=\"\" />",
    "<Steps firstStepID=\"s7\">",
    "<Step id=\"s3\" text=\"\"><Lead stepid=\"s3\" leadid=\"s3l0\" goto=\"i0\"><Text>Two wings</Text></Lead>",
    "<Lead stepid=\"s3\" leadid=\"s3l1\" goto=\"i1\"><Text>Four wings</Text></Lead></Step>",
    "<Step id=\"s7\" text=\"\"><Lead stepid=\"s7\" leadid=\"s7l0\" goto=\"s3\"><Text>Winged</Text></Lead>",
    "<Lead stepid=\"s7\" leadid=\"s7l1\" goto=\"i2\"><Text>Wingless</Text></Lead></Step>",
    "</Steps></PhoenixKey>"
  ), ".xml")
  k <- readLucidKey(f)
  l <- k$leads
  expect_equal(l$Character, c("Winged", "Wingless", "Two wings", "Four wings"))
  expect_equal(l$Next, c("2", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "Flea", "Fly", "Bee & wasp"))
  expect_equal(l$TaxonUrl, c("", "", "html/fly.htm", ""))
  expect_null(l$Question)
  expect_length(k$validate(), 0)
})

test_that("readLucidKey reads the CSV and text exports", {
  csv <- tdwgTempFile(c(
    "1,\"Wings absent\",2",
    "1,\"Wings present\",3",
    "2,\"Laterally compressed, 1-2 mm long\",Flea",
    "2,\"Dorsoventrally flattened, body 10-15 mm long\",Silverfish",
    "3,\"Forewings membranous\",House fly",
    "3,\"Forewings completely or partly thickened\",Beetle"
  ), ".csv")
  k <- readLucidKey(csv, desc = "Insects")
  expect_equal(k$desc, "Insects")
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2", "3", "3"))
  expect_equal(l$Choice, rep(c("a", "b"), 3))
  expect_equal(l$Next, c("2", "3", "-", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "", "Flea", "Silverfish", "House fly", "Beetle"))
  expect_equal(l$Character[3], "Laterally compressed, 1-2 mm long")
  expect_length(k$validate(), 0)

  # the text export, with the curly quotes a word processor makes of it
  txt <- tdwgTempFile(c(
    "1 \u201cWings absent\u201d 2",
    "1 \"Wings present\" 3",
    "",
    "2 \"Laterally compressed, 1-2 mm long\" Flea",
    "2 \"Dorsoventrally flattened, body 10-15 mm long\" Silverfish",
    "3 \"Forewings membranous\" House fly",
    "3 \"Forewings completely or partly thickened\" Beetle"
  ), ".txt")
  expect_identical(readLucidKey(txt)$leads, l)
  bad <- tdwgTempFile(c("1 \"Wings absent\" 2", "this is not a lead"), ".txt")
  expect_error(readLucidKey(bad), "not of the form")
  expect_error(readLucidKey(csv, format = "lif3"), "not a Lucid pathway key format")
})

test_that("writeLucidKey then readLucidKey gives the same key", {
  k <- readLucidKey(tdwgExample("insects.lpxk"))
  for (format in c("lpxk", "csv", "text", "sdd")) {
    ext <- c(lpxk = ".lpxk", csv = ".csv", text = ".txt", sdd = ".xml")[[format]]
    f <- withr::local_tempfile(fileext = ext)
    expect_identical(writeLucidKey(k, f, format), f)
    back <- readLucidKey(f)
    columns <- if (format %in% c("csv", "text")) setdiff(names(k$leads), "Question") else names(k$leads)
    expect_identical(back$leads[columns], k$leads[columns])
    expect_length(back$validate(), 0)
  }
  # Phoenix XML as the Lucid help describes it
  f <- withr::local_tempfile(fileext = ".lpxk")
  writeLucidKey(k, f)
  doc <- xml2::read_xml(f)
  expect_equal(xml2::xml_name(doc), "PhoenixKey")
  expect_equal(xml2::xml_attr(xml2::xml_find_first(doc, "./Steps"), "firstStepID"), "s0")
  expect_equal(xml2::xml_attr(xml2::xml_find_all(doc, "./Steps/Step[1]/Lead"), "goto"), c("s1", "s2"))
  expect_equal(xml2::xml_attr(xml2::xml_find_all(doc, "./Steps/Step[2]/Lead"), "leadid"), c("s1l0", "s1l1"))
  expect_length(xml2::xml_find_all(doc, "./Identity"), 5)

  # the keys that come with dimoose: awkward characters, many couplets
  for (key in list(sharkKey(), montanaKey())) {
    for (format in c("lpxk", "csv", "text")) {
      f <- withr::local_tempfile(fileext = c(lpxk = ".lpxk", csv = ".csv", text = ".txt")[[format]])
      writeLucidKey(key, f, format)
      back <- readLucidKey(f)
      expect_equal(nrow(back$leads), nrow(key$leads))
      expect_equal(back$leads$Taxon, normalizeLeads(key$leads)$Taxon)
      expect_equal(back$leads$Next == "-", normalizeLeads(key$leads)$Next == "-")
      expect_length(back$validate(), 0)
    }
  }
  expect_error(writeLucidKey("no key", f), "must be a dimoose key")
})

test_that("a matrix read from Lucid feeds keyFromMatrix", {
  skip_if_not(exists("keyFromMatrix", mode = "function"), "keyFromMatrix() is not there yet")
  d <- readLucid(tdwgExample("bears-lucid.csv"))
  k <- keyFromMatrix(d$matrix, taxon = "Taxon")
  expect_s3_class(k, "dimoose")
})

# ---- checked against real Lucid files -------------------------------------------------

test_that("a CSV laid out like the Lucid Builder's own export is read", {
  # the layout of the example export offered in the Lucid help: only the names
  # are quoted, a parent entity is scored like any other, and a numeric feature
  # that is not scored is a plain 0
  f <- tdwgTempFile(c(
    ",\"Taxon 1\",\"Group (parent)\",\"Group (parent):Taxon 2 (child)\",\"Taxon 3\"",
    "\"Shape:round\",1,4,1,2",
    "\"Shape:oval\",2,5,0,0",
    "\"Shape:long\",3,1,2,1",
    "\"Surface (parent):Hairs (child):dense\",0,3,6,0",
    "\"Surface (parent):Hairs (child):sparse\",1,3,6,3",
    "\"Size (numeric)#\",1:10:15:20:30,1:5:10:15:20,1:1:5:10:25,0"
  ), ".csv")
  expect_silent(d <- readLucid(f, inapplicable = "n/a"))
  m <- d$matrix
  expect_equal(m$Taxon, c("Taxon 1", "Group (parent)", "Taxon 2 (child)", "Taxon 3"))
  expect_equal(d$taxa$Path[3], "Group (parent):Taxon 2 (child)")
  expect_equal(m$Shape, c("round/oval/long", "long", "round/long", "round/long"))
  expect_equal(m$`Hairs (child)`, c("sparse", NA, "n/a", NA))
  expect_equal(m$`Size (numeric)`, c("(10-)15-20(-30)", "(5-)10-15(-20)", "(1-)5-10(-25)", NA))

  # written again it has the Builder's quoting and its plain 0
  out <- withr::local_tempfile(fileext = ".csv")
  writeLucid(d, out, inapplicable = "n/a")
  lines <- readLines(out)
  expect_equal(lines[1], readLines(f)[1])
  expect_equal(lines[7], readLines(f)[7])
  expect_equal(lines[5], "\"Surface (parent):Hairs (child):dense\",0,0,6,0")
  expect_identical(readLucid(out, inapplicable = "n/a")$matrix, m)
})

test_that("writeLucid says so when it cannot write \"not applicable\" for a numeric feature", {
  m <- data.frame(Taxon = c("A", "B"), Wings = c("present", "absent"), Span = c("5-7", "-"), stringsAsFactors = FALSE)
  chars <- data.frame(Character = "Span", Type = "real", stringsAsFactors = FALSE)
  f <- withr::local_tempfile(fileext = ".csv")
  expect_warning(writeLucid(m, f, characters = chars, inapplicable = "-"), "cannot be written for a numeric feature.*B, Span")
  expect_equal(readLines(f)[4], "\"Span#\",1:5:5:7:7,0")
  expect_equal(readLucid(f)$matrix$Span, c("5-7", NA))
})

test_that("readLucid reads a published Lucid 4 LIF3 file", {
  # Berry & van Noort (2020), CC0; see fixtures/tdwg/README.md
  expect_warning(d <- readLucid(tdwgFixture("tetractenion.lif3")), "2 state name")
  m <- d$matrix
  expect_equal(dim(m), c(6L, 11L))
  expect_equal(m$Taxon, c("Tetractenion acaule", "Tetractenion ibayaensis", "Tetractenion luteum", "Tetractenion pascali",
                          "Tetractenion pseudolutea", "Tetractenion rosei"))
  expect_equal(names(m)[c(2, 4, 11)], c("Head colour", "Pronotal collar", "Wing venation"))
  expect_false(anyNA(m))
  # hand-checked against the scored_item elements of the file
  expect_equal(m$`Head colour`[c(1, 3, 4, 6)],
               c("mostly white (occiput and|or vertex brown|black)", "mostly yellow (occiput brown|black)",
                 "dark purplish-brown", "reddish-brown"))
  expect_equal(m$`Mesoscutum with keels`, rep(c("distinctly raised on lobes", "only slightly raised on mesoscutal lobes"), c(1, 5)))
  expect_equal(m[1, c("Pronotal collar", "Hind tarsal claw", "Wings with", "Wing venation")],
               data.frame("Pronotal collar" = "with strong carina present", "Hind tarsal claw" = "simple",
                          "Wings with" = "sparser microtrichia", "Wing venation" = "dark", check.names = FALSE))
  expect_equal(d$characters$Type, rep("categorical", 10))
  meta <- stats::setNames(d$meta$value, d$meta$key)
  expect_equal(meta[["title"]], "Identification key to Tetractenion species (Banchinae, Ichneumonidae)")
  expect_match(meta[["authors"]], "van Noort")
  # 60 scores in the file, one state per cell
  expect_equal(sum(lengths(strsplit(unlist(m[-1]), "/", fixed = TRUE))), 60)
})

test_that("LIF3 numeric scores are read only in the layout of Lucid's own key files", {
  text <- readLines(tdwgFixture("beetles.lif3"))
  at <- grep("<container type='numeric'>", text, fixed = TRUE)
  known <- c("<scoring_item item_id='13'>",
             "<scored_item item_id='21'><scored_data score_type='1' unit_prefix='unknown' omin='10' nmin='15' nmax='20' omax='30'/></scored_item>",
             "<scored_item item_id='22'><scored_data score_type='1' unit_prefix='unknown' omin='4' nmin='4' nmax='6.5' omax='6.5'/></scored_item>",
             "<scored_item item_id='23'><scored_data score_type='3' unit_prefix='unknown' omin='1' nmin='1' nmax='2' omax='2'/></scored_item>",
             "</scoring_item>")
  f <- tdwgTempFile(append(text, known, at), ".lif3")
  # the one warning is about a "/" in a state name: nothing is said about the
  # numeric scores when they could be read
  expect_no_warning(readLucid(f, sep = "|"))
  expect_warning(d <- readLucid(f), "replaced by")
  expect_equal(d$matrix$`Body length`, c("(10-)15-20(-30)", "4-6.5", NA, NA))
  expect_equal(d$characters$Type[3], "real")
  # any other layout is reported, not guessed at
  other <- tdwgTempFile(append(text, "<scoring_item item_id='13'><scored_item item_id='21' value='15'/></scoring_item>", at), ".lif3")
  expect_warning(expect_warning(d <- readLucid(other), "replaced by"), "numeric scores in a layout dimoose does not know")
  expect_true(all(is.na(d$matrix$`Body length`)))
})

test_that("readLucid reports what else of a LIF3 file it leaves out", {
  text <- readLines(tdwgFixture("beetles.lif3"))
  at <- grep("<container type='dependencies'>", text, fixed = TRUE)
  f <- tdwgTempFile(append(text, "<scoring_item item_id='3'><scored_item item_id='9' value='1'/></scoring_item>", at), ".lif3")
  expect_warning(expect_warning(readLucid(f), "replaced by"), "has dependencies, which are not read")
  # a score that is not one of Lucid's seven
  at <- grep("<scoring_item item_id='3'>", text, fixed = TRUE)[1]
  f <- tdwgTempFile(append(text, "<scored_item item_id='24' value='9'/>", at), ".lif3")
  expect_warning(expect_warning(readLucid(f), "replaced by"), "other than 0 to 6")
})

test_that("writeLucidKey refuses a CSV or text key that would be read differently", {
  k <- keyFromLeads(data.frame(Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
                               Character = c("winged", "wingless", "large", "small"), Next = c("2", "-", "-", "-"),
                               Taxon = c("", "Flea", "2", "Fly"), stringsAsFactors = FALSE), "Odd")
  f <- withr::local_tempfile(fileext = ".csv")
  expect_error(writeLucidKey(k, f, "csv"), "also couplet numbers.*: 2; write")
  expect_error(writeLucidKey(k, f, "text"), "also couplet numbers")
  expect_false(file.exists(f))
  # the XML forms name taxa and couplets apart
  for (format in c("lpxk", "sdd")) {
    out <- withr::local_tempfile(fileext = ".xml")
    writeLucidKey(k, out, format)
    expect_equal(readLucidKey(out, format)$leads$Taxon, k$leads$Taxon)
  }
})
