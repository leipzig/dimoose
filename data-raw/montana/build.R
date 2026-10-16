# Build data/montana.rda: a key to the native broadleaf trees of Montana,
# written for dimoose from the sources in data-raw/montana/sources.md. Run
# from the package root:
#
#   Rscript data-raw/montana/build.R
montana <- utils::read.delim("data-raw/montana/leads.tsv", colClasses = "character",
  na.strings = character(), quote = "", encoding = "UTF-8")
stopifnot(identical(names(montana), c("Statement", "Choice", "Character", "Next", "Taxon", "Question", "Image")),
          all(montana$Next[montana$Next != "-"] %in% montana$Statement))
save(montana, file = "data/montana.rda", compress = "xz", version = 2)
