tdwgFixture <- function(...) test_path("fixtures", "tdwg", ...)
tdwgExample <- function(...) {
  system.file("extdata", "tdwg", ..., package = "dimoose", mustWork = TRUE)
}
# Every way through a key: the lead texts from the first couplet to each
# result. Two keys with the same paths are the same key, however their
# couplets are numbered.
tdwgPaths <- function(key) {
  leads <- normalizeLeads(key$leads)
  root <- checkLeads(leads)$root
  walk <- function(couplet, sofar) {
    unlist(lapply(which(leads$Statement == couplet), function(i) {
      here <- paste(c(sofar, leads$Character[i]), collapse = " > ")
      if (leads$Next[i] != "-" && leads$Next[i] %in% leads$Statement) {
        walk(leads$Next[i], here)
      } else {
        paste(here, leads$Taxon[i], sep = " => ")
      }
    }))
  }
  sort(walk(root, character()))
}

test_that("readSDD reads categorical, quantitative and text characters", {
  d <- readSDD(tdwgExample("violets.sdd.xml"))
  expect_s3_class(d, "tdwgData")
  m <- d$matrix
  expect_named(m, c("Taxon", "Aerial stem", "Flower colour", "Stem hairs", "Flower length", "Notes"))
  expect_equal(m$Taxon, c("Viola odorata", "Viola tricolor", "Viola biflora", "Viola palustris"))
  expect_equal(m$`Aerial stem`, c("absent", "present", "present", "absent"))
  # polymorphic codings list the states in the order they are defined
  expect_equal(m$`Flower colour`, c("violet/white", "violet/white/yellow", "yellow", "violet"))
  # NotApplicable and missing are both NA by default
  expect_equal(m$`Stem hairs`, c(NA, "hairy/glabrous", "glabrous", NA))
  # Min-Max, extremes around the UMeth range, and a mean in the middle; DataUnavailable is NA
  expect_equal(m$`Flower length`, c("13-15", "(10-)15-25(-30)", "12-13.5-15", NA))
  expect_equal(m$Notes, c("Flowers strongly scented", NA, "Usually two flowers on a stem", NA))

  ch <- d$characters
  expect_equal(ch$Type, c("categorical", "categorical", "categorical", "real", "text"))
  expect_equal(ch$States[2], "violet/white/yellow")
  expect_equal(ch$Unit[4], "mm")
  expect_equal(ch$InapplicableIf[3], "Aerial stem=absent")
  expect_equal(d$taxa$Detail[1], "Sweet violet")
  expect_equal(d$meta$value[d$meta$key == "title"], "Four violets")
})

test_that("inapplicable, sep and taxon are honoured", {
  d <- readSDD(tdwgExample("violets.sdd.xml"), taxon = "Species", sep = " | ", inapplicable = "n/a")
  expect_equal(names(d$matrix)[1], "Species")
  expect_equal(names(d$taxa)[1], "Species")
  expect_equal(d$matrix$`Stem hairs`, c("n/a", "hairy | glabrous", "glabrous", "n/a"))
  expect_equal(d$characters$States[1], "present | absent")
})

test_that("a Lucid-style SDD file is read: modifiers, status codes, a second dataset", {
  d <- readSDD(tdwgFixture("lucid-export.sdd.xml"), inapplicable = "n/a")
  m <- d$matrix
  expect_equal(m$Taxon, c("Pteridium aquilinum (L.) Kuhn", "Azolla filiculoides Lam.", "Asplenium trichomanes L."))
  # labels are trimmed (" Frond division")
  expect_equal(names(m)[2:5], c("Frond division", "Habitat", "Frond length", "Remarks"))
  # "rare" keeps the state, "misapplied" drops it
  expect_equal(m$`Frond division`, c("once pinnate/2-3 times pinnate", "n/a", "once pinnate"))
  # two <Categorical> for one character are merged; "perhaps" keeps the state
  expect_equal(m$Habitat, c("in soil", "floating on water", "on rock/in soil"))
  expect_equal(m$`Frond length`, c("(30-)60-200(-400)", "1-2.5", NA))
  expect_equal(m$Remarks, c(NA, "Turns red in autumn & winter", NA))
  expect_equal(d$characters$Unit[3], "cm")
  meta <- stats::setNames(d$meta$value, d$meta$key)
  expect_equal(meta[["authors"]], "Ann Author; Ed Editor")
  expect_equal(meta[["copyright"]], "(c) 2006 The test authors")
  expect_equal(meta[["generator"]], "Lucid 3.3")
  expect_error(readSDD(tdwgFixture("lucid-export.sdd.xml"), dataset = 3), "from 1 to 2")
  expect_error(readSDD(tdwgFixture("lucid-export.sdd.xml"), dataset = 2), "no characters")
})

test_that("readXper reads the Xper2 dialect", {
  expect_warning(d <- readXper(tdwgFixture("xper2.sdd.xml")), "replaced by")
  m <- d$matrix
  # the taxon is the label of the coded description
  expect_equal(m$Taxon, c("vache", "mouton", "cheval"))
  # line breaks inside labels are squeezed, duplicate names numbered
  expect_named(m, c("Taxon", "couleur du pelage", "cornes", "forme", "forme (2)", "hauteur au garrot"))
  expect_equal(m$`couleur du pelage`, c("blanc/noir/roux|brun", "blanc", "noir/roux|brun"))
  expect_equal(m$forme, c("droites", "enroul\u00e9es", NA))
  expect_equal(m$`hauteur au garrot`, c("120-150", "60-80.5", "150"))
  expect_equal(d$characters$InapplicableIf[3], "cornes=absentes")
  expect_equal(d$meta$value[d$meta$key == "format"], "SDD, Xper dialect")
  # another separator leaves "roux/brun" alone
  expect_silent(d2 <- readXper(tdwgFixture("xper2.sdd.xml"), sep = ";"))
  expect_equal(d2$matrix$`couleur du pelage`[3], "noir;roux/brun")
})

test_that("readXper reads the Xper3 dialect and refuses other SDD", {
  d <- readXper(tdwgExample("felids-xper3.sdd.xml"))
  expect_equal(d$matrix$`Coat pattern`, c("plain", "striped", "plain/spotted", "spotted"))
  expect_equal(d$matrix$`Shape of the spots`, c(NA, NA, "rosettes", "solid spots"))
  expect_equal(d$characters$InapplicableIf[2], "Coat pattern=plain/striped")
  # Rating5of5 is the most convenient, so the cheapest
  expect_equal(d$characters$Cost, c(1, 3, 4, 2))
  expect_match(d$taxa$Detail[1], "lion")
  expect_error(readXper(tdwgExample("violets.sdd.xml")), "written by Xper")
  expect_s3_class(readXper(tdwgExample("violets.sdd.xml"), strict = FALSE), "tdwgData")
})

test_that("writeSDD then readSDD gives the same matrix", {
  m <- data.frame(
    Taxon = c("Apis mellifera", "Bombus terrestris", "Vespula <vulgaris> & co", "Osmia"),
    Hair = c("sparse", "dense", "sparse/absent", NA),
    Sting = c("barbed", "smooth", "-", NA),
    "Body length" = c("12-15", "(11-)14-17(-22)", "11-14-19", "8"),
    Segments = c(12, 12, NA, 13),
    Notes = c("makes \"honey\"", NA, "builds paper nests", NA),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  chars <- data.frame(
    Character = c("Hair", "Body length", "Notes"),
    Type = c("categorical", "real", "text"),
    States = c("absent/sparse/dense", "", ""),
    Unit = c("", "mm", ""),
    stringsAsFactors = FALSE
  )
  f <- withr::local_tempfile(fileext = ".xml")
  expect_identical(writeSDD(m, f, characters = chars, title = "Bees & wasps", inapplicable = "-"), f)

  # a well-formed SDD document in the UBIF namespace
  doc <- xml2::read_xml(f)
  expect_equal(xml2::xml_name(doc), "Datasets")
  expect_equal(unname(xml2::xml_ns(doc)[["d1"]]), "http://rs.tdwg.org/UBIF/2006/")
  expect_length(xml2::xml_find_all(doc, "//d1:CategoricalCharacter"), 2)
  expect_length(xml2::xml_find_all(doc, "//d1:QuantitativeCharacter"), 2)
  expect_length(xml2::xml_find_all(doc, "//d1:Status[@code='NotApplicable']"), 1)

  d <- readSDD(f, inapplicable = "-")
  back <- d$matrix
  expect_equal(back$Taxon, m$Taxon)
  # the order of the states is the declared one, not the one in the cell
  expect_equal(back$Hair, c("sparse", "dense", "absent/sparse", NA))
  expect_equal(back$Sting, m$Sting)
  expect_equal(back$`Body length`, m$`Body length`)
  expect_equal(back$Segments, c("12", "12", NA, "13"))
  expect_equal(back$Notes, m$Notes)
  expect_equal(d$characters$Type, c("categorical", "categorical", "real", "real", "text"))
  expect_equal(d$characters$States[1], "absent/sparse/dense")
  expect_equal(d$characters$Unit[3], "mm")
  expect_equal(d$meta$value[d$meta$key == "title"], "Bees & wasps")

  # writing what was read changes nothing more
  f2 <- withr::local_tempfile(fileext = ".xml")
  writeSDD(d, f2, inapplicable = "-")
  d2 <- readSDD(f2, inapplicable = "-")
  expect_identical(d2$matrix, d$matrix)
  expect_identical(d2$characters, d$characters)
})

test_that("the fixtures survive a round trip through writeSDD", {
  files <- c(tdwgExample("violets.sdd.xml"), tdwgExample("felids-xper3.sdd.xml"),
             tdwgFixture("lucid-export.sdd.xml"))
  for (file in files) {
    d <- readSDD(file, inapplicable = "n/a")
    f <- withr::local_tempfile(fileext = ".xml")
    writeSDD(d, f, inapplicable = "n/a")
    back <- readSDD(f, inapplicable = "n/a")
    expect_identical(back$matrix, d$matrix)
    expect_identical(back$characters[c("Character", "Type", "States", "Unit", "InapplicableIf")],
                     d$characters[c("Character", "Type", "States", "Unit", "InapplicableIf")])
    expect_identical(back$taxa$Detail, d$taxa$Detail)
  }
  x <- readXper(tdwgExample("felids-xper3.sdd.xml"))
  f <- withr::local_tempfile(fileext = ".xml")
  writeXper(x, f)
  back <- readXper(f)
  expect_identical(back$matrix, x$matrix)
  expect_identical(back$characters$Cost, x$characters$Cost)
})

test_that("writeSDD warns about what it cannot write and checks its input", {
  m <- data.frame(Taxon = c("A", "B"), Length = c("about 5", "5/10-15"), stringsAsFactors = FALSE)
  chars <- data.frame(Character = "Length", Type = "real")
  f <- withr::local_tempfile(fileext = ".xml")
  expect_warning(writeSDD(m, f, characters = chars), "Not a number or range")
  # several ranges in a cell are written as the range that covers them
  expect_equal(readSDD(f)$matrix$Length, c(NA, "5-15"))

  rules <- data.frame(Character = "Length", InapplicableIf = "Wings=absent")
  expect_warning(writeSDD(m[1, ], f, characters = rules), "not in the data")
  expect_error(writeSDD(m, f, taxon = "Species"), "no taxon column")
  expect_error(writeSDD(rbind(m, m), f), "more than one row")
  expect_error(writeSDD(m["Taxon"], f), "no character columns")
  expect_error(writeSDD(m, f, characters = data.frame(Character = "Length", Type = "fuzzy")), "Unknown character type")
  expect_error(writeSDD("nonsense", f), "must be a character matrix")
  expect_error(readSDD(file.path(tempdir(), "no-such-file.xml")), "not found")
  writeLines("<notsdd/>", f)
  expect_error(readSDD(f), "not an SDD file")
})

test_that("the print method summarises the data", {
  d <- readSDD(tdwgExample("violets.sdd.xml"))
  expect_output(print.tdwgData(d), "4 taxa x 5 characters \\(3 categorical, 1 real, 1 text\\)")
})

test_that("readSDDKey reads a key, numbering the couplets as in a printed key", {
  k <- readSDDKey(tdwgExample("insects-key.sdd.xml"))
  expect_s3_class(k, "dimoose")
  expect_equal(k$desc, "Key to some orders of insects")
  l <- k$leads
  expect_equal(l$Statement, c("1", "1", "2", "2", "3", "3", "4", "4"))
  expect_equal(l$Choice, rep(c("a", "b"), 4))
  expect_equal(l$Next, c("2", "3", "-", "-", "4", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "", "Siphonaptera", "Zygentoma", "", "Coleoptera", "Diptera", "Lepidoptera"))
  expect_equal(l$Character[1], "Wings absent")
  # the key's question is the first couplet's; a lead's question belongs to the couplet it leads to
  expect_equal(l$Question[c(1, 3, 5, 7)],
               c("Does the insect have wings?", "How is the body flattened?", "What are the forewings like?", ""))
  expect_length(k$validate(), 0)
})

test_that("readSDDKey handles polytomies, subkeys and unfinished keys", {
  file <- tdwgFixture("keys.sdd.xml")
  k <- readSDDKey(file)
  l <- k$leads
  expect_equal(k$desc, "First level key")
  # three leads in the first couplet; the third continues in the subkey
  expect_equal(l$Statement, c("1", "1", "1", "2", "2", "3", "3"))
  expect_equal(l$Choice[1:3], c("a", "b", "c"))
  expect_equal(l$Next, c("2", "-", "3", "-", "-", "-", "-"))
  expect_equal(l$Taxon, c("", "Dianthus", "", "Myosotis", "Gentiana", "Papaver rhoeas L.", "Tulipa"))
  expect_length(k$validate(), 0)

  sub <- readSDDKey(file, key = "k2", desc = "Red ones")
  expect_equal(sub$desc, "Red ones")
  expect_equal(nrow(sub$leads), 2)

  q <- readSDDKey(file, key = 3)
  expect_equal(q$leads$Question[1], "Is the plant mostly green?")
  # the herbaceous lead goes on with key k1, which in turn goes on with k2
  expect_equal(nrow(q$leads), 13)
  expect_true(all(c("Myosotis", "Tulipa") %in% q$leads$Taxon))
  # a subkey that is not in the file is named; a lead that just stops is reported
  expect_true("k9" %in% q$leads$Taxon)
  expect_match(q$validate(), "names no taxon")

  expect_error(readSDDKey(file, key = 4), "from 1 to 3")
  expect_error(readSDDKey(file, key = "nope"), "k1, k2, k3")
  expect_error(readSDDKey(tdwgExample("violets.sdd.xml")), "no identification key")
})

test_that("writeSDDKey then readSDDKey gives the same key", {
  k <- readSDDKey(tdwgExample("insects-key.sdd.xml"))
  f <- withr::local_tempfile(fileext = ".xml")
  expect_identical(writeSDDKey(k, f), f)
  doc <- xml2::read_xml(f)
  expect_length(xml2::xml_find_all(doc, "//d1:IdentificationKey/d1:Leads/d1:Lead"), 8)
  back <- readSDDKey(f)
  expect_identical(back$leads, k$leads)
  expect_equal(back$desc, k$desc)

  # the keys that come with dimoose, whatever their numbering
  for (key in list(sharkKey(), arachnidaKey(), montanaKey())) {
    writeSDDKey(key, f)
    back <- readSDDKey(f)
    expect_equal(tdwgPaths(back), tdwgPaths(key))
    expect_length(back$validate(), 0)
    expect_equal(back$desc, key$desc)
  }
})

test_that("a couplet reached from two leads is written under both", {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3"), Choice = rep(c("a", "b"), 3),
    Character = c("Red", "Blue", "Red and big", "Red and small", "Round", "Square"),
    Next = c("2", "3", "3", "-", "-", "-"), Taxon = c("", "", "", "A", "B", "C"),
    stringsAsFactors = FALSE
  )
  key <- keyFromLeads(leads, "Reticulate")
  f <- withr::local_tempfile(fileext = ".xml")
  writeSDDKey(key, f)
  back <- readSDDKey(f)
  expect_equal(nrow(back$leads), 8)
  expect_equal(tdwgPaths(back), tdwgPaths(key))
})

test_that("writeSDD can store a matrix and a key in one file", {
  d <- readSDD(tdwgExample("violets.sdd.xml"))
  k <- readSDDKey(tdwgExample("insects-key.sdd.xml"))
  f <- withr::local_tempfile(fileext = ".xml")
  writeSDD(d, f, key = k)
  both <- readSDD(f)
  expect_identical(both$matrix, d$matrix)
  expect_equal(both$meta$value[both$meta$key == "keys"], "1")
  expect_identical(readSDDKey(f)$leads, k$leads)
  expect_error(writeSDD(d, f, key = "not a key"), "must be a dimoose key")
})

test_that("a matrix read from SDD feeds keyFromMatrix", {
  skip_if_not(exists("keyFromMatrix", mode = "function"), "keyFromMatrix() is not there yet")
  d <- readSDD(tdwgExample("felids-xper3.sdd.xml"))
  k <- keyFromMatrix(d$matrix, taxon = "Taxon")
  expect_s3_class(k, "dimoose")
})

# ---- found when reading real third-party files ---------------------------------------

# A Lucid Builder export in miniature: rules on a node that groups characters,
# character nodes without an id, and the four modifiers the Builder defines
tdwgLucidSdd <- function(coded) {
  f <- withr::local_tempfile(fileext = ".sdd", .local_envir = parent.frame())
  state <- function(id, label) sprintf("<StateDefinition id=\"%s\"><Representation><Label>%s</Label></Representation></StateDefinition>", id, label)
  character <- function(id, label, states) {
    c(sprintf("<CategoricalCharacter id=\"%s\"><Representation><Label>%s</Label></Representation><States>", id, label),
      states, "</States></CategoricalCharacter>")
  }
  modifier <- function(id, label, class) {
    sprintf("<Modifier id=\"%s\"><Representation><Label>%s</Label></Representation><ModifierClass>%s</ModifierClass></Modifier>",
            id, label, class)
  }
  writeLines(c(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<Datasets xmlns=\"http://rs.tdwg.org/UBIF/2006/\">",
    "<TechnicalMetadata created=\"2014-01-01T00:00:00\"><Generator name=\"Lucid3 Builder\" version=\"3.4\"/></TechnicalMetadata>",
    "<Dataset xml:lang=\"en\"><Representation><Label>Flies</Label></Representation>",
    "<TaxonNames>",
    "<TaxonName id=\"t1\"><Representation><Label>Fly one</Label></Representation></TaxonName>",
    "<TaxonName id=\"t2\"><Representation><Label>Fly two</Label></Representation></TaxonName>",
    "</TaxonNames>",
    "<DescriptiveConcepts>",
    "<DescriptiveConcept id=\"dc0\"><Representation><Label>Modifiers</Label></Representation><Modifiers>",
    modifier("mod1", "rarely", "Frequency"), modifier("mod2", "uncertain", "Certainty"),
    modifier("mod3", "misinterpreted", "TreatAsMisinterpretation"), modifier("mod4", "unscoped", "OtherModifierClass"),
    "</Modifiers></DescriptiveConcept>",
    "<DescriptiveConcept id=\"dc1\"><Representation><Label>Male terminalia</Label></Representation></DescriptiveConcept>",
    "</DescriptiveConcepts>",
    "<Characters>",
    character("c1", "sex", c(state("s1", "female"), state("s2", "male"))),
    character("c2", "wings", c(state("s3", "clear"), state("s4", "dark"))),
    character("c3", "epandrium", c(state("s5", "split"), state("s6", "entire"))),
    character("c4", "prongs", c(state("s7", "free"), state("s8", "connected"))),
    character("c5", "prong tips", c(state("s9", "blunt"), state("s10", "pointed"))),
    "</Characters>",
    "<CharacterTrees><CharacterTree id=\"ct1\"><Representation><Label>Tree</Label></Representation><Nodes>",
    "<CharNode><Character ref=\"c1\"/></CharNode>",
    "<CharNode><Character ref=\"c2\"/></CharNode>",
    "<Node id=\"cn1\"><DependencyRules><OnlyApplicableIf><State ref=\"s2\"/></OnlyApplicableIf>",
    "<InapplicableIf><State ref=\"s1\"/></InapplicableIf></DependencyRules><DescriptiveConcept ref=\"dc1\"/></Node>",
    "<CharNode><Parent ref=\"cn1\"/><Character ref=\"c3\"/></CharNode>",
    "<CharNode><Parent ref=\"cn1\"/><Character ref=\"c4\"/></CharNode>",
    "<CharNode><Parent ref=\"cn1\"/><DependencyRules><InapplicableIf><State ref=\"s8\"/></InapplicableIf></DependencyRules>",
    "<Character ref=\"c5\"/></CharNode>",
    "</Nodes></CharacterTree></CharacterTrees>",
    "<CodedDescriptions>", coded, "</CodedDescriptions>",
    "</Dataset></Datasets>"
  ), f)
  f
}

test_that("readSDD applies the rules of a group of characters to the characters in it", {
  f <- tdwgLucidSdd(c(
    "<CodedDescription id=\"D1\"><Representation><Label>Fly one</Label></Representation><Scope><TaxonName ref=\"t1\"/></Scope>",
    "<SummaryData><Categorical ref=\"c1\"><State ref=\"s2\"/></Categorical></SummaryData></CodedDescription>"
  ))
  d <- readSDD(f)
  # (a real Lucid export of 149 characters has 6 such rules that cover 39 characters)
  expect_equal(d$characters$InapplicableIf, c("", "", "sex=female", "sex=female", "sex=female; prongs=connected"))
  # the same rules after a round trip, through SDD and through DELTA
  out <- withr::local_tempfile(fileext = ".xml")
  writeSDD(d, out)
  expect_equal(readSDD(out)$characters$InapplicableIf, d$characters$InapplicableIf)
  expect_equal(readDELTA(dirname(writeDELTA(d, withr::local_tempdir())[1]))$characters$InapplicableIf,
               d$characters$InapplicableIf)
})

test_that("readSDD gives rules one order, whatever order the file lists the states in", {
  f <- tdwgLucidSdd(character())
  text <- readLines(f)
  at <- grep("<InapplicableIf><State ref=\"s8\"/>", text, fixed = TRUE)
  text[at] <- sub("<State ref=\"s8\"/>", "<State ref=\"s4\"/><State ref=\"s8\"/><State ref=\"s3\"/>", text[at], fixed = TRUE)
  writeLines(text, f)
  expect_equal(readSDD(f)$characters$InapplicableIf[5], "sex=female; wings=clear/dark; prongs=connected")
})

test_that("readSDD tells Lucid's score modifiers apart", {
  f <- tdwgLucidSdd(c(
    "<CodedDescription id=\"D1\"><Representation><Label>Fly one</Label></Representation><Scope><TaxonName ref=\"t1\"/></Scope><SummaryData>",
    "<Categorical ref=\"c1\"><State ref=\"s1\"><Modifier ref=\"mod1\"/></State><State ref=\"s2\"/></Categorical>",
    "<Categorical ref=\"c2\"><State ref=\"s3\"><Modifier ref=\"mod3\"/></State><State ref=\"s4\"/></Categorical>",
    "<Categorical ref=\"c3\"><State ref=\"s5\"><Modifier ref=\"mod4\"/></State><State ref=\"s6\"><Modifier ref=\"mod4\"/></State></Categorical>",
    "<Categorical ref=\"c4\"><State ref=\"s7\"><Modifier ref=\"mod2\"/></State><State ref=\"s8\"><Modifier ref=\"mod2\"/></State></Categorical>",
    "</SummaryData></CodedDescription>"
  ))
  m <- readSDD(f, inapplicable = "n/a")$matrix
  # rarely: the taxon has the state
  expect_equal(m$sex[1], "female/male")
  # misinterpreted: it has not
  expect_equal(m$wings[1], "dark")
  # unscoped is Lucid's "not scoped": not applicable, not a state of the taxon
  expect_equal(m$epandrium[1], "n/a")
  expect_true(is.na(readSDD(f)$matrix$epandrium[1]))
  # uncertain: the states are kept
  expect_equal(m$prongs[1], "free/connected")
})

test_that("writeSDD writes nothing the schema forbids for empty characters and taxa", {
  m <- data.frame(Taxon = c("A", "B", "C"), Colour = NA_character_, Hairs = c("dense", NA, NA),
                  Length = c("about 5", NA, "3"), stringsAsFactors = FALSE)
  chars <- data.frame(Character = "Length", Type = "real", stringsAsFactors = FALSE)
  f <- withr::local_tempfile(fileext = ".xml")
  # a categorical character must have a state, so one without is a text character
  expect_warning(expect_warning(writeSDD(m, f, characters = chars), "without any state written as text characters: Colour"),
                 "Not a number or range")
  doc <- xml2::xml_ns_strip(xml2::read_xml(f))
  expect_length(xml2::xml_find_all(doc, "//States[not(StateDefinition)]"), 0)
  expect_length(xml2::xml_find_all(doc, "//TextCharacter"), 1)
  # <SummaryData> must have something in it: taxon B has nothing coded
  expect_length(xml2::xml_find_all(doc, "//SummaryData[not(*)]"), 0)
  expect_length(xml2::xml_find_all(doc, "//CodedDescription"), 3)
  expect_length(xml2::xml_find_all(doc, "//SummaryData"), 2)
  d <- readSDD(f)
  expect_equal(d$matrix$Taxon, m$Taxon)
  expect_equal(d$matrix$Hairs, m$Hairs)
  expect_equal(d$matrix$Length, c(NA, NA, "3"))
  expect_true(all(is.na(d$matrix$Colour)))
})

test_that("writeSDD refuses a matrix without rows or with a column name used twice", {
  f <- withr::local_tempfile(fileext = ".xml")
  m <- data.frame(Taxon = c("A", "B"), X = c("a", "b"), X = c("c", "d"), check.names = FALSE)
  expect_error(writeSDD(m, f), "used more than once in the matrix: X")
  expect_error(writeSDD(m[0, 1:2], f), "no rows")
  expect_error(writeXper(m[0, 1:2], f), "no rows")
  expect_false(file.exists(f))
})

test_that("an SDD file without a namespace is read (Xper3 1.6 writes such files)", {
  text <- readLines(tdwgExample("felids-xper3.sdd.xml"))
  text <- sub(" xmlns=\"http://rs.tdwg.org/UBIF/2006/\"", "", text, fixed = TRUE)
  text <- sub(" xsi:schemaLocation=\"[^\"]*\"", "", text)
  f <- withr::local_tempfile(fileext = ".xml")
  writeLines(text, f)
  expect_false(any(grepl("rs.tdwg.org/UBIF", readLines(f), fixed = TRUE)))
  expect_identical(readXper(f)$matrix, readXper(tdwgExample("felids-xper3.sdd.xml"))$matrix)
})

test_that("keys with a couplet reached twice, or with many leads, survive SDD", {
  key <- function(...) keyFromLeads(data.frame(..., stringsAsFactors = FALSE), "Test key <&> \"q\" é")
  reticulate <- key(Statement = c(1, 1, 2, 2, 3, 3, 4, 4), Choice = rep(c("a", "b"), 4),
                    Character = c("wings", "no wings", "big", "small", "red", "blue", "hairy", "bald"),
                    Next = c("2", "3", "4", "-", "4", "-", "-", "-"), Taxon = c("", "", "", "B", "", "C", "D", "E"))
  wide <- key(Statement = rep(1, 30), Choice = as.character(1:30), Character = paste("lead", 1:30), Next = "-",
              Taxon = paste("T", 1:30))
  odd <- key(Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
             Character = c("has \"quotes\", commas & <tags>", "résumé — naïve", "lead with, comma", "x"),
             Next = c("2", "-", "-", "-"), Taxon = c("", "Taxon, with comma", "2", "Bee \"the\" <b>&amp;"))
  for (k in list(reticulate, wide, odd, sharkKey(), arachnidaKey(), montanaKey(), vibrioKey())) {
    f <- withr::local_tempfile(fileext = ".xml")
    writeSDDKey(k, f)
    back <- readSDDKey(f)
    expect_identical(tdwgPaths(back), tdwgPaths(k))
    expect_identical(back$desc, k$desc)
    # every lead has one parent, and it is a lead of the same key
    doc <- xml2::xml_ns_strip(xml2::read_xml(f))
    ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//Lead"), "id")
    expect_false(anyDuplicated(ids) > 0)
    expect_true(all(xml2::xml_attr(xml2::xml_find_all(doc, "//Lead/Parent"), "ref") %in% ids))
  }
  # the couplet reached from two leads is written out under each of them
  f <- withr::local_tempfile(fileext = ".xml")
  writeSDDKey(reticulate, f)
  expect_equal(nrow(readSDDKey(f)$leads), 10)
})
