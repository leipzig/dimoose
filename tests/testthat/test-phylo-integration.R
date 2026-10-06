test_that("toNewick labels = safe uses ascii ids and returns a key for them", {
  leads <- data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("x", "y"),
    Next = c("-", "-"), Taxon = c("L2'3'4", "H2a+152  16311"), stringsAsFactors = FALSE)
  k <- keyFromLeads(leads)
  safe <- toNewick(k, labels = "safe")
  expect_match(safe$newick, ";$")
  expect_false(grepl("'", safe$newick, fixed = TRUE))
  expect_false(grepl("+", safe$newick, fixed = TRUE))
  expect_true(all(c("id", "label") %in% names(safe$labels)))
  expect_true("L2'3'4" %in% safe$labels$label)
  # the quoted default still works and matches the method
  expect_identical(toNewick(k, labels = "quoted"), k$toNewick())
})

test_that("toNewick annotate = nhx and beast attach lead text, sanitized", {
  leads <- data.frame(Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
    Character = c("wings, present", "wings absent", "two wings", "four wings"),
    Next = c("2", "-", "-", "-"), Taxon = c("", "Apterygota", "Diptera", "Other"), stringsAsFactors = FALSE)
  k <- keyFromLeads(leads)
  nhx <- toNewick(k, annotate = "nhx")
  expect_match(nhx, "\\[&&NHX:", perl = TRUE)
  expect_false(grepl("wings, present", nhx, fixed = TRUE)) # comma sanitized
  beast <- toNewick(k, annotate = "beast")
  expect_match(beast, "\\[&", perl = TRUE)
})

test_that("toIgraph gives a directed edge list that keeps multiple parents", {
  skip_if_not_installed("igraph")
  leads <- data.frame(Statement = c("1", "1", "2", "2", "3", "3"), Choice = rep(c("a", "b"), 3),
    Character = letters[1:6], Next = c("2", "3", "-", "3", "-", "-"),
    Taxon = c("", "", "X", "", "Y", "Z"), stringsAsFactors = FALSE)
  k <- keyFromLeads(leads)
  g <- toIgraph(k)
  expect_s3_class(g, "igraph")
  expect_true(igraph::is_directed(g))
  # couplet 3 is reached from both couplet 1 and couplet 2
  expect_equal(sum(igraph::degree(g, mode = "in")[["3"]]), 2)
})

test_that("toDataTree survives a taxon literally named 'children'", {
  leads <- data.frame(Statement = c("1", "1"), Choice = c("a", "b"), Character = c("x", "y"),
    Next = c("-", "-"), Taxon = c("children", "other"), stringsAsFactors = FALSE)
  k <- keyFromLeads(leads)
  expect_warning(tr <- k$toDataTree(), NA)  # no reserved-word warning leaks out
  expect_s3_class(tr, "Node")
  # the reserved name is kept in the node's label, not lost
  expect_true("children" %in% tr$Get("label", filterFun = data.tree::isLeaf))
})

test_that("toTreedata builds a treedata with lead text on nodes", {
  skip_if_not_installed("tidytree")
  k <- arachnidaKey()
  td <- toTreedata(k)
  expect_s4_class(td, "treedata")
  tb <- tidytree::as_tibble(td)
  expect_true(all(c("Character", "Choice") %in% names(tb)))
})

test_that("toAuspiceJSON writes a v2 tree with unique space-free names", {
  skip_if_not_installed("jsonlite")
  k <- phylotreeKey("H2a")
  js <- toAuspiceJSON(k)
  obj <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_equal(obj$version, "v2")
  expect_true(all(c("meta", "tree") %in% names(obj)))
  names <- character()
  walk <- function(n) { names[[length(names) + 1]] <<- n$name; for (c in n$children %||% list()) walk(c) }
  `%||%` <- function(a, b) if (is.null(a)) b else a
  walk(obj$tree)
  expect_false(any(grepl(" ", unlist(names))))
  expect_equal(anyDuplicated(unlist(names)), 0)
})

test_that("readHaplogrep parses nested haplogroup XML into a phylotree key", {
  xml <- paste0(
    '<phylotree>',
    '<haplogroup name="A"><details><poly>263G</poly></details>',
    '<haplogroup name="A1"><details><poly>1234T</poly></details></haplogroup>',
    '<haplogroup name="A2"><details><poly>5678C</poly></details></haplogroup>',
    '</haplogroup></phylotree>')
  f <- tempfile(fileext = ".xml"); writeLines(xml, f)
  tree <- readHaplogrep(f)
  expect_true(all(c("haplogroup", "parent", "mutations") %in% names(tree)))
  expect_setequal(tree$haplogroup, c("A", "A1", "A2"))
  expect_equal(tree$parent[tree$haplogroup == "A1"], "A")
  k <- readHaplogrep(f, key = TRUE)
  expect_s3_class(k, "dimoose")
})
