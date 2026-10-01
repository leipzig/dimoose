# Build the package datasets from the TSVs written by
# convert_haplogrep_xml.py. Run from the package root.
hg <- utils::read.delim("data-raw/phylotree17/phylotree17_haplogroups.tsv",
  colClasses = "character", na.strings = character(), quote = "", encoding = "UTF-8")
mu <- utils::read.delim("data-raw/phylotree17/phylotree17_mutations.tsv",
  colClasses = "character", na.strings = character(), quote = "", encoding = "UTF-8")

phylotree17 <- data.frame(
  haplogroup = hg$haplogroup,
  parent = ifelse(hg$parent == "", NA_character_, hg$parent),
  depth = as.integer(hg$depth),
  n_subclades = as.integer(hg$n_subclades),
  mutations = hg$mutations,
  stringsAsFactors = FALSE
)
phylotree17_mutations <- data.frame(
  haplogroup = mu$haplogroup,
  notation = mu$notation,
  position = as.integer(mu$position),
  type = factor(mu$type, levels = c("transition", "transversion", "back-mutation", "insertion", "deletion")),
  ancestral = ifelse(mu$ancestral == "", NA_character_, mu$ancestral),
  derived = ifelse(mu$derived == "", NA_character_, mu$derived),
  stringsAsFactors = FALSE
)
stopifnot(
  !anyDuplicated(phylotree17$haplogroup),
  all(stats::na.omit(phylotree17$parent) %in% phylotree17$haplogroup),
  all(phylotree17_mutations$haplogroup %in% phylotree17$haplogroup),
  !anyNA(phylotree17_mutations$type),
  identical(
    unname(vapply(split(phylotree17_mutations$notation, factor(phylotree17_mutations$haplogroup, levels = phylotree17$haplogroup)), paste, "", collapse = " ")),
    phylotree17$mutations
  )
)
save(phylotree17, file = "data/phylotree17.rda", compress = "xz", version = 2)
save(phylotree17_mutations, file = "data/phylotree17_mutations.rda", compress = "xz", version = 2)
