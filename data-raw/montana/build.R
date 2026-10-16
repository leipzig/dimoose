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

# Photos: download a 400 px copy of each Wikimedia Commons file listed in
# photos.tsv into inst/extdata/montana/, refusing any whose license on
# Commons no longer matches the recorded one, and write the credits block for
# inst/COPYRIGHTS.
photos <- utils::read.delim("data-raw/montana/photos.tsv", colClasses = "character",
  na.strings = character(), quote = "", encoding = "UTF-8")
dir.create("inst/extdata/montana", showWarnings = FALSE, recursive = TRUE)
ua <- httr::user_agent("dimoose R package data build (https://github.com/leipzig/dimoose)")
for (i in seq_len(nrow(photos))) {
  r <- httr::GET("https://commons.wikimedia.org/w/api.php", ua, query = list(
    action = "query", format = "json", prop = "imageinfo", iiprop = "url|extmetadata",
    iiurlwidth = 400, titles = paste0("File:", photos$file[i])))
  httr::stop_for_status(r)
  info <- jsonlite::fromJSON(httr::content(r, as = "text", encoding = "UTF-8"))$query$pages[[1]]$imageinfo
  license <- info$extmetadata$LicenseShortName$value
  if (!identical(license, photos$license[i])) {
    stop(photos$file[i], ": license on Commons is ", license, ", not ", photos$license[i])
  }
  img <- httr::GET(info$thumburl, ua)
  httr::stop_for_status(img)
  writeBin(httr::content(img, as = "raw"), file.path("inst/extdata/montana", paste0(photos$id[i], ".jpg")))
  Sys.sleep(1)
}
file.copy("data-raw/montana/photos.tsv", "inst/extdata/montana/photos.tsv", overwrite = TRUE)
credits <- paste0("  ", photos$id, ".jpg: ", photos$author, ", ", photos$license, ",\n    ", photos$source_url)
writeLines(c(
  "inst/extdata/montana/",
  sprintf("  %d photographs from Wikimedia Commons, each resized by Wikimedia to", nrow(photos)),
  "  400 px wide; the files are unchanged otherwise. Each remains under its own",
  "  license, separately from the licence of dimoose's code:",
  "", credits
), "data-raw/montana/COPYRIGHTS-photos.txt")

# The key as a plain spreadsheet (inst/extdata/montana/montana-key.csv), which
# montanaKey() reads with keyFromSpreadsheet() and people can copy as a
# template for their own keys.
sheet <- data.frame(
  Couplet = montana$Statement, Choice = montana$Choice, Question = montana$Question,
  Description = montana$Character, `Goes to` = ifelse(montana$Next == "-", "", montana$Next),
  Species = montana$Taxon,
  Photo = vapply(strsplit(montana$Image, ";", fixed = TRUE), function(x) if (length(x)) paste(paste0(x, ".jpg"), collapse = "; ") else "", ""),
  check.names = FALSE, stringsAsFactors = FALSE
)
utils::write.csv(sheet, "inst/extdata/montana/montana-key.csv", row.names = FALSE, fileEncoding = "UTF-8")
