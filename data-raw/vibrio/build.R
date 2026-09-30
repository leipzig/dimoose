# Build data/vibrio.rda: the consensus identification matrix of Noguerola &
# Blanch (2008), extracted from the paper's table (see analysis/table-extraction
# and analysis/vibrio/convert_excel.py). Run from the package root.
raw <- utils::read.delim("data-raw/vibrio/vibrio.tsv", check.names = FALSE,
  colClasses = "character", na.strings = character(), quote = "")
names(raw)[1] <- "species"
# "Acid from:" and "Resistance to:" are section headings with no values; fold
# them into the names of the tests that follow them.
section <- ""
keep <- character()
for (nm in names(raw)[-1]) {
  if (grepl(":\\s*$", nm)) {
    stopifnot(all(raw[[nm]] == ""))
    section <- sub(":\\s*$", "", nm)
    next
  }
  new <- if (nzchar(section)) paste(section, nm) else nm
  keep[new] <- nm
}
vibrio <- data.frame(species = trimws(raw$species), stringsAsFactors = FALSE)
for (new in names(keep)) {
  x <- trimws(raw[[keep[[new]]]])
  vibrio[[new]] <- ifelse(x == "", NA_character_, x) # one blank cell in the source table
}
codes <- c("+", "-", "(+)", "(-)", "v", "d", "ND")
stopifnot(!anyDuplicated(vibrio$species), all(unlist(vibrio[-1]) %in% c(codes, NA)))
save(vibrio, file = "data/vibrio.rda", compress = "xz", version = 2)
