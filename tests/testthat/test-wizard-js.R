# Behaviour of the page script (inst/wizard/wizard.js) and of the service
# worker (inst/wizard/sw.js), run in jsdom by tests/js/wizard.test.js.
# Needs node and the jsdom package; skipped without them. To get jsdom without
# touching the repository:
#   mkdir -p "$TMPDIR/dimoose-jsdom" && cd "$TMPDIR/dimoose-jsdom" && npm install jsdom
# or point DIMOOSE_JSDOM (or NODE_PATH) at a node_modules folder that has it.

wizNode <- function() {
  node <- Sys.which("node")
  if (!nzchar(node) && file.exists("/opt/homebrew/bin/node")) node <- "/opt/homebrew/bin/node"
  unname(node)
}

# The node_modules folder that holds jsdom, or "" if there is none
wizJsdom <- function(node) {
  globalRoot <- tryCatch(suppressWarnings(system2("npm", c("root", "-g"), stdout = TRUE, stderr = FALSE)),
                         error = function(e) character())
  candidates <- c(
    Sys.getenv("DIMOOSE_JSDOM"),
    strsplit(Sys.getenv("NODE_PATH"), .Platform$path.sep, fixed = TRUE)[[1]],
    file.path(dirname(tempdir()), "dimoose-jsdom", "node_modules"),
    file.path(Sys.getenv("TMPDIR", "/tmp"), "dimoose-jsdom", "node_modules"),
    file.path("/tmp", "dimoose-jsdom", "node_modules"),
    globalRoot
  )
  for (dir in unique(candidates[nzchar(candidates)])) {
    if (file.exists(file.path(dir, "jsdom", "package.json"))) return(normalizePath(dir))
  }
  ""
}

wizFixtures <- function(dir) {
  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3", "4", "4"),
    Choice = rep(c("a", "b"), 4),
    Character = c("Wings present", "Wings absent", "Two wings", "Four wings",
                  "Narrow waist", "Broad waist", "No wings, long tail", "Jumps"),
    Next = c("2", "4", "-", "3", "-", "-", "-", "-"),
    Taxon = c("", "", "Fly", "", "Ant", "Bee", "Silverfish", "Flea"),
    stringsAsFactors = FALSE
  )
  key <- keyFromLeads(leads, "Five insects")
  insects <- data.frame(
    Taxon = c("Fly", "Ant", "bee", "Silverfish", "Flea", "Moth"),
    Wings = c("present", "present/absent", "present", "absent", "absent", "present"),
    Sting = c("absent", NA, "present", "absent", "absent", "absent"),
    Waist = c("broad", "narrow", "narrow", "broad", "broad", "broad"),
    stringsAsFactors = FALSE
  )
  characters <- data.frame(Character = c("Wings", "Sting", "Waist"), Cost = c(2, 3, 1),
                           Needs = c("", "hand lens", ""), Season = c("", "summer", ""),
                           stringsAsFactors = FALSE)
  exportWizard(key, file.path(dir, "key.html"))
  suppressMessages(exportWizard(key, file.path(dir, "both.html"), matrix = insects, characters = characters))
  exportWizard(NULL, file.path(dir, "matrix.html"), matrix = insects, characters = characters, title = "Insects")
  leads$Image <- c("https://img.example.net/thumbs/a.gif", "https://img.example.net/blocked/b.png;https://img.example.net/missing.gif",
                   rep("", 6))
  exportWizard(keyFromLeads(leads, "Five insects"), file.path(dir, "offline.html"), offline = TRUE)
  # a photo model for the five insects: 4-dimensional text embeddings, one
  # axis each for Fly, Ant, Bee and Silverfish, and Flea between the last two
  model <- wizFakeModel(file.path(dir, "model-src"), c("Fly", "Ant", "Bee", "Silverfish", "Flea", "Not in the key"))
  suppressMessages(exportWizard(key, file.path(dir, "photo.html"), photoModel = model))
  suppressMessages(exportWizard(key, file.path(dir, "photo-offline.html"), photoModel = model, offline = TRUE))
  dir
}

# A folder laid out as exportBrowserModel() writes it, with a made-up encoder
wizFakeModel <- function(dir, taxa, size = 2) {
  dir.create(dir, showWarnings = FALSE)
  emb <- rbind(c(1, 0, 0, 0), c(0, 1, 0, 0), c(0, 0, 1, 0), c(0, 0, 0, 1), c(0, 0, 0.6, 0.8), c(0.5, 0.5, 0.5, 0.5))[seq_along(taxa), , drop = FALSE]
  writeBin(as.numeric(t(emb)), file.path(dir, "text_embeddings.bin"), size = 4, endian = "little")
  writeBin(as.raw(1:64), file.path(dir, "image_encoder.onnx"))
  labels <- paste0("{\"taxon\": \"", taxa, "\", \"name\": \"", taxa, "\", \"prompt\": \"a photo of ", taxa, ".\"}", collapse = ",\n")
  writeLines(sprintf('{
  "format": "dimoose-browser-model", "version": 1,
  "image_encoder": {"file": "image_encoder.onnx", "url": null, "bytes": 2500000, "precision": "int8",
    "input": "pixel_values", "input_type": "float32", "input_shape": [1, 3, %d, %d], "output": "image_embeds", "normalized": false},
  "preprocess": {"image_size": %d, "resize": "shortest", "resize_to": %d, "interpolation": "bicubic", "crop": "center",
    "rescale": 0.00392156862745098, "mean": [0.5, 0.5, 0.5], "std": [0.5, 0.25, 1], "layout": "NCHW", "channels": "RGB"},
  "text_embeddings": {"file": "text_embeddings.bin", "dtype": "float32", "byte_order": "little", "shape": [%d, 4],
    "order": "row-major", "normalized": true, "prompt": "a photo of %%s."},
  "labels": [%s],
  "logit_scale": 100
}', size, size, size, size, length(taxa), labels), file.path(dir, "model.json"))
  dir
}

test_that("the wizard and the service worker behave in a browser (jsdom)", {
  node <- wizNode()
  skip_if(!nzchar(node), "node is not installed")
  modules <- wizJsdom(node)
  skip_if(!nzchar(modules), "the jsdom package for node is not installed")
  script <- test_path("..", "js", "wizard.test.js")
  skip_if(!file.exists(script), "tests/js/wizard.test.js is not here")

  dir <- withr::local_tempdir()
  wizFixtures(dir)
  out <- withr::with_envvar(c(NODE_PATH = modules), suppressWarnings(
    system2(node, c(shQuote(normalizePath(script)), shQuote(dir)), stdout = TRUE, stderr = TRUE)
  ))
  status <- attr(out, "status")
  expect_true(is.null(status) || status == 0, label = paste(c("node ran the tests:", out), collapse = "\n"))
  lines <- strsplit(grep("^(ok|not ok)\t", out, value = TRUE), "\t", fixed = TRUE)
  expect_gt(length(lines), 25)
  for (line in lines) {
    expect_true(line[1] == "ok", label = paste0("[js] ", line[2], if (length(line) > 2) paste0(": ", line[3]) else ""))
  }
})

test_that("the page script and the service worker are plain ES5", {
  # no arrow functions, let/const, template strings or classes: the page must
  # run in old browsers on old phones
  for (f in c("wizard.js", "sw.js")) {
    js <- readLines(system.file("wizard", f, package = "dimoose"), warn = FALSE)
    code <- sub("//.*$", "", js)
    expect_false(any(grepl("=>|`|^\\s*(let|const|class)\\s|\\b(async|await)\\b", code)), label = paste(f, "uses only ES5 syntax"))
  }
  node <- wizNode()
  skip_if(!nzchar(node), "node is not installed")
  for (f in c("wizard.js", "sw.js")) {
    status <- suppressWarnings(system2(node, c("--check", shQuote(system.file("wizard", f, package = "dimoose"))),
                                       stdout = FALSE, stderr = FALSE))
    expect_equal(status, 0, label = paste(f, "parses"))
  }
})
