skip_if_not_installed("ape")

toyAlignment <- c(human = "ACGTACGTACGA", chimp = "ACGTACGTATGA", mouse = "ACCTACATGCGA",
                  rat   = "ACCTACATGCGT", fish  = "TCCTTCGTACCA")

test_that("keyFromAlignment turns an alignment into a key of diagnostic sites", {
  key <- keyFromAlignment(toyAlignment, outgroup = "fish")
  expect_s3_class(key, "moose")
  expect_length(key$validate(), 0)
  l <- key$leads
  expect_equal(length(unique(l$Statement)), 4)
  expect_setequal(l$Taxon[l$Next == "-"], names(toyAlignment))
  # the outgroup splits off first, on the sites only it differs at
  expect_equal(sort(l$Character[l$Statement == "1"]), c("1A 5A 11G", "1T 5T 11C"))
  expect_equal(l$Taxon[l$Statement == "1" & l$Character == "1T 5T 11C"], "fish")
  expect_true(all(c("3C 7A 9G", "3G 7G 9A") %in% l$Character))
  expect_true(all(c("10C", "10T", "12A", "12T") %in% l$Character))
  m <- stats::setNames(key$meta$value, key$meta$key)
  expect_equal(m[["rooting"]], "outgroup")
  expect_equal(m[["weak_couplets"]], "0")
  expect_setequal(ape::read.tree(text = m[["newick"]])$tip.label, names(toyAlignment))
})

test_that("a machine can follow the key, and gaps give no answer", {
  key <- keyFromAlignment(toyAlignment, outgroup = "fish")
  s <- alignmentScores(key, toyAlignment)
  expect_true(all(s %in% c(0, 1)))
  r <- classify(key, s)
  expect_equal(r$result, r$id)
  new <- c(unknown = "ACCTACATGCGT", gappy = "-CCTACATGCGT")
  r2 <- classify(key, alignmentScores(key, new))
  expect_equal(r2$result[1], "rat")
  expect_true(is.na(r2$result[2]))
  expect_match(exportWizard(key), "1T 5T 11C", fixed = TRUE)
})

test_that("the alignment can be a FASTA file, a matrix or a DNAbin", {
  ref <- keyFromAlignment(toyAlignment, outgroup = "fish")$leads
  fa <- tempfile(fileext = ".fasta")
  writeLines(as.vector(rbind(paste0(">", names(toyAlignment)), substr(toyAlignment, 1, 6), substr(toyAlignment, 7, 12))), fa)
  expect_equal(keyFromAlignment(fa, outgroup = "fish")$leads, ref)
  mat <- do.call(rbind, strsplit(tolower(toyAlignment), ""))
  expect_equal(keyFromAlignment(mat, outgroup = "fish")$leads, ref)
  expect_equal(keyFromAlignment(ape::as.DNAbin(mat), outgroup = "fish")$leads, ref)
  txt <- tempfile(fileext = ".txt"); writeLines("CLUSTAL W", txt)
  expect_error(keyFromAlignment(txt), "not a FASTA file")
  expect_error(keyFromAlignment("no-such-file.fasta"), "not found")
})

test_that("identical sequences share a result", {
  aln <- c(toyAlignment, human2 = toyAlignment[["human"]])
  key <- keyFromAlignment(aln, outgroup = "fish")
  expect_true("human / human2" %in% key$leads$Taxon)
  expect_equal(nrow(key$taxa), 5)
  expect_error(keyFromAlignment(c(a = "ACGT", b = "ACGT")), "identical")
})

test_that("sites can be numbered by a reference sequence", {
  mat <- rbind(ref = c("-", "A", "C", "-", "-", "G"), x = c("T", "A", "C", "A", "A", "G"))
  expect_equal(moose:::siteLabels(mat, "ref"), c("0.1", "1", "2", "2.1", "2.2", "3"))
  expect_equal(moose:::siteLabels(mat), as.character(1:6))
  aln <- c(ref = "GC-GTAC", a = "ACTGTAC", b = "ACTGAAC", c = "AC-GAAT")
  key <- keyFromAlignment(aln, reference = "ref", outgroup = "ref")
  expect_true(any(grepl("^site:6:", key$features$id)))    # column 7 is position 6 in ref
  expect_equal(classify(key, alignmentScores(key, aln))$result, names(aln))
  expect_error(alignmentScores(key, aln[-1]), "not in this alignment")
  expect_error(keyFromAlignment(aln, reference = "zz"), "reference")
})

test_that("a tree from any other program can be supplied", {
  key <- keyFromAlignment(toyAlignment, tree = "(((human,chimp),(mouse,rat)),fish);")
  expect_equal(key$meta$value[key$meta$key == "tool"], "user-supplied tree")
  r <- classify(key, alignmentScores(key, toyAlignment))
  expect_equal(r$result, r$id)
  expect_error(keyFromAlignment(toyAlignment, tree = "((human,chimp),(mouse,gerbil));"), "gerbil")
  # a tree the sequences do not support gets leads marked "(most)"
  expect_warning(bad <- keyFromAlignment(toyAlignment, tree = "(((human,mouse),(chimp,rat)),fish);"), "diagnostic")
  expect_true(any(grepl("(most)", bad$leads$Character, fixed = TRUE)))
})

test_that("keyFromAlignment checks its inputs", {
  expect_error(keyFromAlignment(c(a = "ACGT", b = "ACG")), "same length")
  expect_error(keyFromAlignment(toyAlignment, outgroup = "shark"), "shark")
  expect_error(keyFromAlignment(toyAlignment[1]), "at least two")
  expect_error(keyFromAlignment(toyAlignment, tool = "fasttree", exe = "/no/such/FastTree"), "not found")
  two <- keyFromAlignment(toyAlignment[c("human", "fish")])
  expect_equal(nrow(two$leads), 2)
})

test_that("the phangorn tools build keys too", {
  skip_if_not_installed("phangorn")
  set.seed(1)
  tr <- ape::rtree(12); tr$edge.length <- tr$edge.length * 0.1
  p <- phangorn::simSeq(tr, l = 400, type = "DNA")
  for (tool in c("upgma", "parsimony")) {
    key <- suppressWarnings(keyFromAlignment(p, tool = tool))
    expect_length(key$validate(), 0)
    expect_equal(nrow(key$taxa), 12)
  }
  aa <- phangorn::simSeq(tr, l = 200, type = "AA")
  key <- suppressWarnings(keyFromAlignment(aa))
  expect_equal(key$meta$value[key$meta$key == "sequence_type"], "AA")
  expect_match(key$leads$Question[1], "^Residue at")
})

test_that("command-line tools are run on the alignment and their tree is read back", {
  skip_on_os("windows")
  newick <- "(((t1:0.1,t2:0.1):0.2,(t3:0.1,t4:0.1):0.2):0.1,t5:0.4);"
  fasttree <- tempfile("FastTree")
  writeLines(c("#!/bin/sh", "for a; do last=$a; done", "grep -c '>' \"$last\" >&2", sprintf("echo '%s'", newick)), fasttree)
  iqtree <- tempfile("iqtree")
  writeLines(c("#!/bin/sh", "while [ $# -gt 0 ]; do if [ \"$1\" = \"-pre\" ]; then pre=$2; fi; shift; done",
               sprintf("echo '%s' > \"$pre.treefile\"", newick)), iqtree)
  Sys.chmod(c(fasttree, iqtree), "755")
  ref <- keyFromAlignment(toyAlignment, tree = "(((human,chimp),(mouse,rat)),fish);")$leads
  k1 <- keyFromAlignment(toyAlignment, tool = "fasttree", exe = fasttree)
  expect_equal(k1$meta$value[k1$meta$key == "tool"], "FastTree")
  expect_equal(k1$leads$Character, ref$Character)
  k2 <- keyFromAlignment(toyAlignment, tool = "iqtree", exe = iqtree, model = "GTR+G")
  expect_equal(k2$leads$Character, ref$Character)
  failing <- tempfile("FastTree"); writeLines(c("#!/bin/sh", "echo 'bad alignment' >&2", "exit 1"), failing); Sys.chmod(failing, "755")
  expect_error(keyFromAlignment(toyAlignment, tool = "fasttree", exe = failing), "bad alignment")
})
