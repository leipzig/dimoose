# Copies the example photos into inst/extdata/ from a checkout of the Fruits-360
# dataset (100x100 version), https://github.com/fruits-360/fruits-360-100x100,
# commit c3b8394. CC BY-SA 4.0, (c) 2017- Mihai Oltean.
#
#   FRUITS360=/path/to/fruits-360-100x100 Rscript data-raw/photos/build.R
#
# From each class, seven photos evenly spaced through the sorted file list:
# six go to inst/extdata/pics/<fruit>/ under their own names, and the fourth
# is held out as inst/extdata/new-photos/unknown<n>.jpg.
src <- file.path(Sys.getenv("FRUITS360"), "Training")
classes <- c("Banana 1" = "banana", "Blueberry 1" = "blueberry", "Kiwi 1" = "kiwi",
             "Lemon 1" = "lemon", "Pineapple 1" = "pineapple", "Strawberry 1" = "strawberry")
unlink(c("inst/extdata/pics", "inst/extdata/new-photos"), recursive = TRUE)
dir.create("inst/extdata/new-photos", recursive = TRUE)
for (r in seq_along(classes)) {
  files <- sort(list.files(file.path(src, names(classes)[r])), method = "radix")
  picks <- files[round((0:6) * (length(files) - 1) / 6) + 1]
  dir.create(file.path("inst/extdata/pics", classes[r]), recursive = TRUE)
  for (k in seq_along(picks)) {
    to <- if (k == 4) file.path("inst/extdata/new-photos", sprintf("unknown%d.jpg", r)) else file.path("inst/extdata/pics", classes[r], picks[k])
    file.copy(file.path(src, names(classes)[r], picks[k]), to)
  }
}
