toyTree <- function() {
  tree <- data.frame(haplogroup = c("R", "A", "B", "C"), parent = c(NA, "R", "A", "B"),
                     depth = 0:3, n_subclades = c(1, 1, 1, 0), stringsAsFactors = FALSE)
  muts <- data.frame(
    haplogroup = c("A", "A", "B", "B", "C"),
    notation = c("100T", "200.1A", "100C!", "200.1A!", "300d"),
    position = c(100L, 200L, 100L, 200L, 300L),
    type = c("transition", "insertion", "back-mutation", "back-mutation", "deletion"),
    ancestral = c("C", NA, "T", "A", "G"),
    derived = c("T", "A", "C", NA, NA),
    stringsAsFactors = FALSE)
  list(tree = tree, muts = muts)
}

test_that("haplotypeMatrix follows mutations, reversions, insertions and deletions down the tree", {
  toy <- toyTree()
  X <- haplotypeMatrix(c("R", "A", "B", "C"), sites = c("100", "200.1", "300"),
                       tree = toy$tree, mutations = toy$muts)
  expect_equal(dim(X), c(4, 3))
  expect_equal(colnames(X), c("100", "200.1", "300"))
  expect_equal(unname(X["R", ]), c(0, 0, 0))
  expect_equal(unname(X["A", ]), c(1, 1, 0))
  expect_equal(unname(X["B", ]), c(0, 0, 0)) # 100 reverted, insertion reverted
  expect_equal(unname(X["C", ]), c(0, 0, 1)) # deletion
})

test_that("haplotypeMatrix keeps repeated haplogroups as separate rows", {
  toy <- toyTree()
  X <- haplotypeMatrix(c("A", "A", "C"), sites = "100", tree = toy$tree, mutations = toy$muts)
  expect_equal(nrow(X), 3)
  expect_equal(unname(X[, 1]), c(1, 1, 0))
  expect_error(haplotypeMatrix("Z", sites = "100", tree = toy$tree, mutations = toy$muts), "Z")
})

test_that("haplotypeMatrix on PhyloTree applies Haplogrep's back-mutations", {
  X <- haplotypeMatrix(c("mtMRCA", "L0a", "L0a1+16293G", "L0a1b"), sites = c("16278", "152"))
  expect_equal(unname(X["mtMRCA", ]), c(0, 0))
  expect_equal(unname(X[c("L0a", "L0a1+16293G", "L0a1b"), "16278"]), c(1, 1, 0))
})

test_that("recurrentPositions finds the homoplasic sites", {
  r <- recurrentPositions(min_branches = 50)
  expect_equal(names(r), c("site", "n_branches"))
  expect_equal(r$site[1], "152")
  expect_gte(r$n_branches[1], 200)
  expect_true(all(r$n_branches >= 50))
  expect_false(is.unsorted(rev(r$n_branches)))
  expect_true(all(c("16311", "146", "16189") %in% r$site))
})

test_that("macroHaplogroup groups haplogroups by letter or by depth", {
  expect_equal(macroHaplogroup(c("H2a2a1", "L3e1", "U5b", "mtMRCA", "L1'2'3'4'5'6")),
               c("H", "L3", "U", "mtMRCA", "L1"))
  expect_equal(macroHaplogroup("H2a", level = "depth", depth = 1), "L1'2'3'4'5'6")
  expect_equal(macroHaplogroup("L0", level = "depth", depth = 3), "L0")
  expect_error(macroHaplogroup("notAHaplogroup", level = "depth"), "notAHaplogroup")
})
