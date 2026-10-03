tinyLeads <- function() {
  data.frame(
    Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "Apterygota", "Diptera", "Other"),
    stringsAsFactors = FALSE
  )
}

test_that("desc is read only", {
  k <- keyFromLeads(tinyLeads(), "Tiny")
  expect_equal(k$desc, "Tiny")
  expect_error(k$desc <- "Other", "read only")
  expect_equal(k$desc, "Tiny")
})

test_that("data frame fields accept data frames and reject anything else", {
  k <- keyFromLeads(tinyLeads(), "Tiny")
  meta <- data.frame(key = "citation", value = "Me (2026)", stringsAsFactors = FALSE)
  k$meta <- meta
  expect_equal(k$meta, meta)
  taxa <- data.frame(submitted_name = "Diptera", matched_name = "Diptera", stringsAsFactors = FALSE)
  k$taxa <- taxa
  expect_equal(k$taxa, taxa)
  df <- k$df
  k$df <- df[1:2, ]
  expect_equal(nrow(k$df), 2)
  leads <- tinyLeads()
  leads$Taxon[4] <- "Hymenoptera"
  k$leads <- leads
  expect_equal(k$leads$Taxon[4], "Hymenoptera")

  for (field in c("df", "meta", "taxa", "leads")) {
    expect_error(k[[field]] <- list(a = 1), info = field)
    expect_error(k[[field]] <- data.frame(), info = field)
  }
})

test_that("features accepts a data frame or NULL", {
  k <- keyFromLeads(tinyLeads())
  f <- featureTable("term:x", "external")
  k$features <- f
  expect_equal(k$features$id, "term:x")
  k$features <- NULL
  expect_null(k$features)
  expect_error(k$features <- "term:x")
})

test_that("leads are rebuilt from the path table when not given", {
  k <- arachnidaKey()
  rebuilt <- moose$new(k$df, "Arachnida")
  cols <- c("Statement", "Choice", "Next", "Taxon")
  ord <- function(x) x[order(as.numeric(x$Statement), x$Choice), cols]
  expect_equal(ord(rebuilt$leads), ord(k$leads), ignore_attr = TRUE)
  expect_equal(rebuilt$summary()[c("couplets", "leads", "taxa")], k$summary()[c("couplets", "leads", "taxa")])
})

test_that("a key without a path table has no leads", {
  empty <- moose$new(NULL)
  expect_equal(nrow(empty$leads), 0)
  expect_named(empty$leads, c("Statement", "Choice", "Character", "Next", "Taxon"))
})

test_that("print shows the title, counts and problems", {
  expect_output(print(keyFromLeads(tinyLeads(), "Tiny")), "<moose key> Tiny\n  2 couplets, 4 leads, 3 taxa, up to 2 steps deep")
  expect_output(print(keyFromLeads(tinyLeads())), "(untitled)", fixed = TRUE)

  broken <- tinyLeads()
  broken$Next[2] <- "9"
  broken$Taxon[2] <- ""
  k <- keyFromLeads(broken, "Broken")
  expect_output(print(k), "1 problem(s): see $validate()", fixed = TRUE)
  expect_match(k$validate(), "couplet 9", all = FALSE)
  expect_output(expect_invisible(print(k)))
})

test_that("validate returns nothing, invisibly, for a sound key", {
  expect_invisible(keyFromLeads(tinyLeads())$validate())
  expect_length(keyFromLeads(tinyLeads())$validate(), 0)
})

test_that("summary() dispatches to the summary method", {
  k <- keyFromLeads(tinyLeads(), "Tiny")
  s <- summary(k)
  expect_equal(s, k$summary())
  expect_equal(s$depth, 2L)
  expect_equal(s$problems, 0L)
})

test_that("rawhtml downloads a key's description and couplet table", {
  dir <- system.file("extdata", "fishbase", package = "moose")
  fetched <- NULL
  local_mocked_bindings(fetchFishbasePages = function(keycode, fishbaseUrl) {
    fetched <<- list(keycode = keycode, fishbaseUrl = fishbaseUrl)
    list(
      description = xml2::read_html(file.path(dir, "key1-description.html")),
      questions = xml2::read_html(file.path(dir, "key1-questions.html")),
      questionsUrl = paste0(fishbaseUrl, "keys/questions.php")
    )
  })
  r <- rawhtml$new(1, fishbaseUrl = "https://example.org/")
  expect_equal(fetched, list(keycode = 1, fishbaseUrl = "https://example.org/"))
  expect_match(r$desc, "shark", ignore.case = TRUE)
  expect_true(all(c("Statement", "Choice", "Character", "Next", "Taxon") %in% names(r$df)))
  expect_equal(nrow(r$df), nrow(sharkKey()$leads))
  expect_error(r$desc <- "x", "read only")
  expect_error(r$df <- data.frame())
  r$df <- r$df[1:2, ]
  expect_equal(nrow(r$df), 2)
  expect_output(print(r), "Statement")
})
