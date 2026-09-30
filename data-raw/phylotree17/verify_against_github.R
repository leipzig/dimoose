# Check that the shipped phylotree17 data match Haplogrep's tree.xml on GitHub.
# Parses the XML independently of convert_haplogrep_xml.py (with xml2) and
# compares every haplogroup's name, parent, subclade order and mutation list.
# Run from the package root:  Rscript data-raw/phylotree17/verify_against_github.R [ref]
# `ref` defaults to the pinned release commit; pass "main" to check the latest.
args <- commandArgs(trailingOnly = TRUE)
ref <- if (length(args)) args[1] else "0e79ddf1b78f7a1b81fb5d607bc31a6ddea7b18b"
url <- sprintf("https://raw.githubusercontent.com/genepi/phylotree-rsrs-17/%s/src/tree.xml", ref)

xml <- xml2::read_xml(url)
nodes <- xml2::xml_find_all(xml, "//haplogroup")
name <- trimws(xml2::xml_attr(nodes, "name"))
parent <- vapply(nodes, function(n) {
  p <- xml2::xml_parent(n)
  if (xml2::xml_name(p) == "haplogroup") trimws(xml2::xml_attr(p, "name")) else NA_character_
}, character(1))
mutations <- vapply(nodes, function(n) {
  polys <- xml2::xml_text(xml2::xml_find_all(n, "./details/poly"))
  paste(trimws(polys[nzchar(trimws(polys))]), collapse = " ")
}, character(1))
github <- data.frame(haplogroup = name, parent = parent, mutations = mutations, stringsAsFactors = FALSE)

load("data/phylotree17.rda")
load("data/phylotree17_mutations.rda")
ours <- phylotree17

report <- function(label, ok, detail = NULL) {
  cat(sprintf("%-58s %s\n", label, if (ok) "OK" else "DIFFERS"))
  if (!ok && length(detail)) cat("  e.g.", head(detail, 5), "\n")
  ok
}
m <- match(ours$haplogroup, github$haplogroup)
checks <- c(
  report(sprintf("same number of haplogroups (%d)", nrow(github)), nrow(ours) == nrow(github)),
  report("same haplogroup names", setequal(ours$haplogroup, github$haplogroup),
    c(setdiff(github$haplogroup, ours$haplogroup), setdiff(ours$haplogroup, github$haplogroup))),
  report("same order (document order = preorder)", identical(ours$haplogroup, github$haplogroup)),
  report("same parent for every haplogroup", identical(ours$parent, github$parent[m]),
    ours$haplogroup[which(ours$parent != github$parent[m])]),
  report("same mutations, verbatim and in order", identical(ours$mutations, github$mutations[m]),
    ours$haplogroup[which(ours$mutations != github$mutations[m])]),
  report("mutation table rebuilds the same lists",
    identical(unname(vapply(split(phylotree17_mutations$notation,
      factor(phylotree17_mutations$haplogroup, levels = ours$haplogroup)), paste, "", collapse = " ")),
      github$mutations[m])),
  report("subclade counts match", identical(ours$n_subclades,
    as.integer(table(factor(github$parent, levels = github$haplogroup))[ours$haplogroup])))
)
cat(sprintf("\nGitHub ref: %s\n%s\n", ref, if (all(checks)) "phylotree17 matches GitHub exactly." else "phylotree17 does NOT match GitHub."))
quit(status = if (all(checks)) 0 else 1)
