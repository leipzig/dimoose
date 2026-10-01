# Vision Keys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let moose build dichotomous keys from labelled images (fordera's two methods, generalized to any embedding model), follow them by machine with `classify()`, and show them in the wizard with a glossary of example crops.

**Architecture:** A model-free R core (`R/features.R`, `R/terms.R`, `R/questions.R`, `R/images.R`) works on plain numeric matrices: it clusters patch embeddings into invented "terms", clusters class embeddings and picks vocabulary questions for each split, and walks keys over score matrices. A thin Python layer (`inst/python/moose_vision.py`, wrapped by `R/vision-python.R` through reticulate) does the only things that need a model or pixels: CLIP image, patch and text embeddings, and patch crops. Keys carry a `features` table so new images can be scored and classified later. The wizard learns to embed each image once, detect image types, show thumbnail strips, use `Question` headings and render a glossary.

**Tech Stack:** R (R6, rpart, stats::kmeans/hclust, base64enc, testthat 3), Python 3 (torch, open_clip_torch, pillow, numpy, pytest), reticulate (Suggests), Playwright for a page check.

**Spec:** `docs/superpowers/specs/2026-09-30-vision-keys-design.md`

## Global Constraints

- moose is an R package checked with `R CMD check --as-cran`; it must stay at status OK. No non-ASCII characters in R source (write `’`-style escapes or avoid).
- reticulate is a **Suggests** dependency only; every R function that needs it calls `requireNamespace("reticulate", quietly = TRUE)` and stops with a clear message otherwise. The core (`features.R`, `terms.R`, `questions.R`, `images.R`) never touches Python.
- No truck images, no fordera outputs and no model weights go into the repository. `*.pt` and `.env*` are git-ignored. Verification scripts read fordera from `Sys.getenv("FORDERA", "~/Documents/fordera")` and weights from `Sys.getenv("MOOSE_CLIP_WEIGHTS")`.
- Python-dependent R tests `skip()` unless reticulate is installed, `MOOSE_CLIP_WEIGHTS` is set and the Python modules import.
- Lead table convention stays: `Statement`, `Choice`, `Character`, `Next` (`"-"` = terminal), `Taxon`; new optional columns `Question`, `Feature`, `Test` (`">"` or `"<="`), `Threshold` (numeric).
- Thresholds use quantile type 7 (numpy's default), so fordera's numbers reproduce.
- The repository is on the user's Mac at `~/Documents/moose` (branch `fix/fishbase-import-and-wizard`); the working copy is `/home/claude/moose`. Edits are written to both (device_commit_files / device_bash). **Commit only when the user has said to**; otherwise leave the work uncommitted and say so. Commit steps below are conditional on that.
- Commit messages end with the attribution lines the session gives (`Co-Authored-By` and `Claude-Session`).
- Work in Python happens in the sandbox (`/home/claude`), where torch 2.14.1, open_clip 3.3.0 and reticulate are installed, with the weights staged at `/home/claude/weights/ViT-B-32.pt` (SHA-256 `40d365715913c9da98579312b702a82c18be219cc2a73407c4526f58eba950af`).

## Review Focus

Inputs the spec implies but which are easy to get wrong; each has a test pinned to the task that owns it.

1. **An image label that appears in only one image, and labels with several images** — `keyFromTerms(method = "balanced")` must treat a label as having a term if *any* of its images does (Task 3 test "label presence is any over its images").
2. **A couplet where no lead's test passes, or both pass** (e.g. a NaN score, or a malformed key) — `classify()` must return `NA` with the path so far, not error or loop (Task 4 test "unresolvable couplet gives NA").
3. **A vocabulary pair whose reverse direction scores higher** — the "Has feature" lead must go to the side that actually has it (Task 6 test "yes lead points at the side that has the feature").
4. **Images that are not 224×224 or not square** — `patch_box()` must map patches back through resize-shorter-side and center-crop (Task 8 pytest "patch_box on a 400x300 image").
5. **Image names with characters that are illegal in CSS identifiers** (`1948-1950`, `H2a+152`) — the wizard's one-copy image embedding must sanitize names and still render (Task 9 test "image names are sanitized for CSS").

---

## File map

| File | Responsibility |
|---|---|
| `R/moose.R` (modify) | `features` field on the `moose` R6 class |
| `R/keys.R` (modify) | `keyFromLeads(features = )` |
| `R/features.R` (new) | `featureTable()`, `checkFeatures()`, `featureScores()`, `classify()`, `evaluateKey()`, `looKey()` |
| `R/images.R` (new) | `imageSet()`, `imageMeta()`, `imageMime()` |
| `R/terms.R` (new) | `inventNames()`, `discoverTerms()`, `termScores()`, `keyFromTerms()` |
| `R/questions.R` (new) | `vocabularyPrompts()`, `keyFromClusters()` |
| `R/vision-python.R` (new) | `visionModel()`, `embedImages()`, `embedTexts()`, `patchExemplars()`, `scoreImages()` |
| `inst/python/moose_vision.py` (new) | model loading, embeddings, patch boxes, crops |
| `tests/python/test_moose_vision.py` (new) | pytest for the Python layer |
| `R/export.R`, `inst/wizard/wizard.css`, `inst/wizard/wizard.js` (modify) | one-copy images, MIME, thumbnails, Question headings, glossary |
| `tests/testthat/test-features.R`, `test-images.R`, `test-terms.R`, `test-questions.R`, `test-vision-python.R` (new); `test-export-wizard.R`, `test-example-keys.R` (modify) | tests |
| `analysis/fordera/verify.R`, `analysis/fordera/REPORT.md` (new) | V1–V4 against fordera |
| `DESCRIPTION`, `NAMESPACE` (roxygen), `.gitignore`, `.Rbuildignore`, `README.md`, `R/moose-package.R` | housekeeping |

A synthetic test helper shared by several tasks lives in `tests/testthat/helper-vision.R` (Task 2).

---

### Task 1: `features` field, lead columns and housekeeping

**Files:**
- Modify: `R/moose.R` (private list, active bindings, `initialize`)
- Modify: `R/keys.R:27-48` (`keyFromLeads`)
- Modify: `R/export.R:88-97` (`normalizeLeads`)
- Create: `R/features.R` (only `featureTable()` and `checkFeatures()` in this task)
- Modify: `DESCRIPTION`, `.gitignore`, `.Rbuildignore`, `R/moose-package.R`
- Test: `tests/testthat/test-features.R`

**Interfaces:**
- Produces: `featureTable(id, kind, label = id, prompt = NA, negative_prompt = NA, region = NA, embedding = NULL, exemplars = NULL)` → data.frame with columns `id, kind, label, prompt, negative_prompt, region` (character) and list columns `embedding`, `exemplars`; `checkFeatures(leads, features)` → character vector of problems; `moose$features` (data.frame or NULL); `keyFromLeads(leads, desc, meta, taxa, features = NULL)`.

- [ ] **Step 1: Write the failing tests**

`tests/testthat/test-features.R`:

```r
test_that("featureTable builds the standard columns", {
  f <- featureTable(id = c("term:a", "text:b"), kind = c("centroid_patch_max", "clip_text_pair"),
    prompt = c(NA, "a photo with b"), negative_prompt = c(NA, "a photo with not b"),
    embedding = list(c(1, 0), NULL))
  expect_equal(names(f), c("id", "kind", "label", "prompt", "negative_prompt", "region", "embedding", "exemplars"))
  expect_equal(f$label, c("term:a", "text:b"))
  expect_equal(f$embedding[[1]], c(1, 0))
  expect_null(f$exemplars[[2]])
})

test_that("keyFromLeads keeps features and validate checks them", {
  leads <- data.frame(
    Statement = c("1", "1"), Choice = c("a", "b"), Character = c("Has x", "Lacks x"),
    Next = c("-", "-"), Taxon = c("A", "B"),
    Feature = c("term:x", "term:x"), Test = c(">", "<="), Threshold = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )
  f <- featureTable("term:x", "centroid_patch_max", embedding = list(c(1, 0)))
  k <- keyFromLeads(leads, "t", features = f)
  expect_s3_class(k$features, "data.frame")
  expect_length(k$validate(), 0)
  expect_type(k$leads$Threshold, "double")

  bad <- leads
  bad$Feature[2] <- "term:y"
  expect_match(keyFromLeads(bad, "t", features = f)$validate(), "term:y", all = FALSE)
  badTest <- leads
  badTest$Test <- c(">", ">")
  expect_match(keyFromLeads(badTest, "t", features = f)$validate(), "opposite", all = FALSE)
  expect_match(keyFromLeads(leads, "t")$validate(), "no features table", all = FALSE)
})

test_that("keys without features validate as before", {
  expect_length(arachnidaKey()$validate(), 0)
  expect_null(arachnidaKey()$features)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /home/claude/moose && Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-features.R")'`
Expected: FAIL, `could not find function "featureTable"`.

- [ ] **Step 3: Add the `features` field to `moose`**

In `R/moose.R`, add `.features = NULL` to `private`, this active binding after `leads`, the `@field` doc line, and the `features` argument:

```r
    features = function(value) {
      if (missing(value)) {
        private$.features
      } else {
        stopifnot(is.null(value) || is.data.frame(value))
        private$.features <- value
        self
      }
    }
```

```r
    #' @param features Optional data frame of machine-readable features (see
    #'   [featureTable()]).
    initialize = function(df, desc = NA, meta = NA, taxa = NA, leads = NULL, features = NULL) {
      private$.df <- df
      private$.desc <- desc
      private$.meta <- meta
      private$.taxa <- taxa
      private$.leads <- leads
      private$.features <- features
    },
```

Add to the class docs: `#' @field features Data frame of features a machine can compute, one per row (see [featureTable()]), or NULL for keys meant only for people.`

Change `validate` to include feature problems:

```r
    validate = function() {
      leads <- normalizeLeads(self$leads)
      problems <- c(checkLeads(leads)$problems, checkFeatures(leads, private$.features))
      if (length(problems)) problems else invisible(character())
    },
```

- [ ] **Step 4: Write `featureTable()` and `checkFeatures()`**

Create `R/features.R`:

```r
#' A table of machine-computable features
#'
#' Keys built from images (see [keyFromTerms()] and [keyFromClusters()]) carry
#' a `features` table that says how a machine computes the score each lead
#' tests. [classify()] walks a key over a matrix of such scores.
#'
#' @param id Feature ids, e.g. `"term:dulmzil"` or `"text:round_headlights"`.
#' @param kind `"centroid_patch_max"` (highest cosine similarity between any
#'   image patch embedding and `embedding`), `"clip_text_pair"` (cosine with
#'   `prompt` minus cosine with `negative_prompt`) or `"external"` (computed
#'   by the user).
#' @param label Name shown to people; defaults to `id`.
#' @param prompt,negative_prompt Texts for `clip_text_pair` features.
#' @param region Crop as `"y0,y1,x0,x1"` fractions, or `NA` for the whole image.
#' @param embedding List of numeric vectors (one per feature), or `NULL`.
#' @param exemplars List of data frames with columns `image`, `patch`,
#'   `score` and optionally `png` (base64) showing what the feature means.
#' @return A data frame with the columns above; `embedding` and `exemplars`
#'   are list columns.
#' @export
featureTable <- function(id, kind, label = id, prompt = NA, negative_prompt = NA, region = NA,
                         embedding = NULL, exemplars = NULL) {
  n <- length(id)
  if (is.null(embedding)) embedding <- vector("list", n)
  if (is.null(exemplars)) exemplars <- vector("list", n)
  stopifnot(length(kind) == n, length(embedding) == n, length(exemplars) == n)
  out <- data.frame(
    id = as.character(id), kind = as.character(kind), label = as.character(rep_len(label, n)),
    prompt = as.character(rep_len(prompt, n)), negative_prompt = as.character(rep_len(negative_prompt, n)),
    region = as.character(rep_len(region, n)), stringsAsFactors = FALSE
  )
  out$embedding <- embedding
  out$exemplars <- exemplars
  out
}

# Problems with the Feature/Test/Threshold columns of a lead table, given the
# key's features table (NULL when the key has none).
checkFeatures <- function(leads, features) {
  if (is.null(leads$Feature)) return(character())
  used <- which(!is.na(leads$Feature) & nzchar(leads$Feature))
  if (length(used) == 0) return(character())
  problems <- character()
  if (is.null(features)) {
    return("Leads test features but the key has no features table")
  }
  missing <- setdiff(unique(leads$Feature[used]), features$id)
  if (length(missing)) {
    problems <- c(problems, sprintf("Feature %s is tested by a lead but not in the features table", missing))
  }
  badTest <- used[!leads$Test[used] %in% c(">", "<=")]
  if (length(badTest)) {
    problems <- c(problems, sprintf("Lead %s%s has Test %s; use > or <=", leads$Statement[badTest],
      leads$Choice[badTest], leads$Test[badTest]))
  }
  thr <- suppressWarnings(as.numeric(leads$Threshold[used]))
  if (any(is.na(thr))) {
    problems <- c(problems, sprintf("Lead %s%s has no numeric Threshold",
      leads$Statement[used[is.na(thr)]], leads$Choice[used[is.na(thr)]]))
  }
  for (cp in unique(leads$Statement[used])) {
    i <- used[leads$Statement[used] == cp]
    if (length(i) == 2 && leads$Feature[i[1]] == leads$Feature[i[2]] && leads$Test[i[1]] == leads$Test[i[2]]) {
      problems <- c(problems, sprintf("Couplet %s tests %s with the same Test on both leads; they must be opposite", cp, leads$Feature[i[1]]))
    }
  }
  problems
}
```

- [ ] **Step 5: Pass `features` through `keyFromLeads()` and keep `Threshold` numeric**

In `R/keys.R`, change the signature and the last line:

```r
keyFromLeads <- function(leads, desc = NA, meta = NULL, taxa = NULL, features = NULL) {
  ...
  if (!is.null(leads$Threshold)) leads$Threshold <- as.numeric(leads$Threshold)
  moose$new(keyPaths(leads, separateTerms = FALSE), desc, meta, taxa, leads = leads, features = features)
}
```

Add `#' @param features Optional [featureTable()] for keys a machine can follow.` to its roxygen block.

In `R/export.R`, `normalizeLeads()` must not turn `Threshold` into text. Change its loop to also cover the new text columns and leave `Threshold` alone:

```r
normalizeLeads <- function(leads) {
  for (col in c("Statement", "Choice", "Character", "Next", "Taxon", "Label", "Image", "ImageLink", "TaxonUrl",
                "Question", "Feature", "Test")) {
    if (is.null(leads[[col]])) leads[[col]] <- rep("", nrow(leads))
    x <- as.character(leads[[col]])
    x[is.na(x)] <- ""
    leads[[col]] <- trimws(x)
  }
  if (is.null(leads$Threshold)) leads$Threshold <- rep(NA_real_, nrow(leads))
  leads$Threshold <- suppressWarnings(as.numeric(leads$Threshold))
  leads$Next[leads$Next == ""] <- "-"
  as.data.frame(leads, stringsAsFactors = FALSE)
}
```

- [ ] **Step 6: Housekeeping**

`DESCRIPTION`: add `jsonlite` and `reticulate` to `Suggests` (alphabetical). `.gitignore`: append

```
# Model weights and local environment files
*.pt
.env
.env.*
```

`.Rbuildignore`: append `^docs$`, `^.*\.pt$`, `^\.env.*$`, `^tests/python$`.

`R/moose-package.R`: nothing new yet (kmeans/hclust come from `stats`, already imported wholesale? check: if `importFrom(stats, ...)` lists specific functions, add `kmeans`, `hclust`, `dist`, `quantile`, `setNames`, `reformulate`).

- [ ] **Step 7: Regenerate docs and run the tests**

Run: `cd /home/claude/moose && Rscript -e 'roxygen2::roxygenise()' && Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-features.R"); testthat::test_file("tests/testthat/test-example-keys.R")'`
Expected: all PASS.

- [ ] **Step 8: Sync to the Mac and (if approved) commit**

Copy changed files to `~/Documents/moose` with `device_commit_files`. If the user has approved committing: `git add -A R DESCRIPTION NAMESPACE man .gitignore .Rbuildignore tests && git commit -m "Add features table and machine-test lead columns"` (plus attribution lines).

---

### Task 2: Image sets, data URIs and a synthetic test helper

**Files:**
- Create: `R/images.R`
- Create: `tests/testthat/helper-vision.R`
- Test: `tests/testthat/test-images.R`

**Interfaces:**
- Produces: `imageSet(paths, label = NULL)` → data.frame `id, path, label`; `imageMime(path)` → `"image/png"` etc. or `NA`; `imageMeta(paths, ids = NULL)` → data.frame `key = "image_<id>", value = "data:<mime>;base64,..."`.
- Helper (tests only): `syntheticVision(n_labels = 6, per_label = 1, k = 4, p = 9, d = 8, seed = 1)` → list `images` (imageSet), `image` (n×d unit rows), `patches` (n×p×d unit rows, built so each label is a mix of `k` planted "concept" vectors), `concepts` (k×d).

- [ ] **Step 1: Write the failing tests**

`tests/testthat/test-images.R`:

```r
test_that("imageSet labels from file names, vectors or functions", {
  paths <- c("/x/1948-1950.png", "/x/1967.png", "/x/1967_alt.png")
  s <- imageSet(paths)
  expect_equal(s$id, c("1948-1950", "1967", "1967_alt"))
  expect_equal(s$label, s$id)
  expect_equal(imageSet(paths, label = function(x) sub("_.*$", "", x))$label, c("1948-1950", "1967", "1967"))
  expect_equal(imageSet(paths, label = c("a", "b", "b"))$label, c("a", "b", "b"))
  expect_error(imageSet(paths, label = c("a", "b")), "length")
})

test_that("imageMime reads magic bytes and imageMeta makes data URIs", {
  png <- tempfile(fileext = ".png")
  png::writePNG(array(runif(4 * 4 * 3), c(4, 4, 3)), png)
  jpg <- tempfile(fileext = ".jpg")
  jpeg::writeJPEG(array(runif(4 * 4 * 3), c(4, 4, 3)), jpg)
  txt <- tempfile(fileext = ".txt"); writeLines("hi", txt)
  expect_equal(imageMime(png), "image/png")
  expect_equal(imageMime(jpg), "image/jpeg")
  expect_true(is.na(imageMime(txt)))
  m <- imageMeta(c(png, jpg), ids = c("a", "b"))
  expect_equal(m$key, c("image_a", "image_b"))
  expect_match(m$value[1], "^data:image/png;base64,")
  expect_match(m$value[2], "^data:image/jpeg;base64,")
  expect_error(imageMeta(txt), "not an image")
})

test_that("the synthetic fixture has the promised shapes", {
  v <- syntheticVision()
  expect_equal(dim(v$patches), c(6, 9, 8))
  expect_equal(nrow(v$images), 6)
  expect_equal(unname(round(sqrt(rowSums(v$image^2)), 6)), rep(1, 6))
})
```

(`png` and `jpeg` are already installed in the sandbox; add both to `Suggests`.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-images.R")'`
Expected: FAIL, `could not find function "imageSet"`.

- [ ] **Step 3: Write `R/images.R`**

```r
#' A set of labelled images
#'
#' @param paths Image files.
#' @param label Class of each image: `NULL` (the file name without its
#'   extension), a character vector as long as `paths`, or a function applied
#'   to those file names (e.g. `function(x) sub("_.*$", "", x)` so that
#'   `1967_alt` counts as `1967`).
#' @return A data frame with `id` (file name without extension), `path` and
#'   `label`.
#' @export
imageSet <- function(paths, label = NULL) {
  paths <- as.character(paths)
  id <- sub("\\.[^.]+$", "", basename(paths))
  lab <- if (is.null(label)) {
    id
  } else if (is.function(label)) {
    as.character(label(id))
  } else {
    if (length(label) != length(paths)) stop("`label` must have one entry per path (length ", length(paths), ")", call. = FALSE)
    as.character(label)
  }
  data.frame(id = id, path = paths, label = lab, stringsAsFactors = FALSE)
}

#' MIME type of an image file from its first bytes
#' @param path One file.
#' @return `"image/png"`, `"image/jpeg"`, `"image/gif"`, `"image/webp"` or `NA`.
#' @export
imageMime <- function(path) {
  b <- readBin(path, "raw", 12)
  hex <- paste(format(b), collapse = "")
  if (startsWith(hex, "89504e47")) return("image/png")
  if (startsWith(hex, "ffd8ff")) return("image/jpeg")
  if (startsWith(hex, "474946")) return("image/gif")
  if (startsWith(hex, "52494646") && substr(hex, 17, 24) == "57454250") return("image/webp")
  NA_character_
}

#' Embed images in a key's metadata
#'
#' Reads image files and returns `image_<id>` rows for a key's `meta`, which
#' [exportWizard()] embeds in the page; leads refer to them by id in their
#' `Image` column (several separated by `;`).
#'
#' @param paths Image files.
#' @param ids Names for the images; default the file names without extension.
#' @return A key/value data frame.
#' @export
imageMeta <- function(paths, ids = NULL) {
  if (is.null(ids)) ids <- sub("\\.[^.]+$", "", basename(paths))
  value <- vapply(paths, function(p) {
    mime <- imageMime(p)
    if (is.na(mime)) stop(basename(p), " is not an image", call. = FALSE)
    paste0("data:", mime, ";base64,", base64enc::base64encode(p))
  }, character(1))
  data.frame(key = paste0("image_", ids), value = unname(value), stringsAsFactors = FALSE)
}
```

- [ ] **Step 4: Write the synthetic fixture**

`tests/testthat/helper-vision.R`:

```r
# Synthetic "embeddings": k planted concept directions in d dimensions. Each
# label gets a fixed subset of concepts; each of its images has patches that
# are noisy copies of those concepts plus noise patches. Labels are "L1".."Ln".
syntheticVision <- function(n_labels = 6, per_label = 1, k = 4, p = 9, d = 8, seed = 1, noise = 0.05) {
  set.seed(seed)
  unit <- function(m) m / sqrt(rowSums(m^2))
  concepts <- unit(matrix(rnorm(k * d), k, d))
  has <- matrix(FALSE, n_labels, k)
  for (i in seq_len(n_labels)) has[i, ] <- as.logical(intToBits(i)[seq_len(k)])
  n <- n_labels * per_label
  patches <- array(0, c(n, p, d))
  image <- matrix(0, n, d)
  ids <- character(n)
  labels <- character(n)
  r <- 0
  for (i in seq_len(n_labels)) for (j in seq_len(per_label)) {
    r <- r + 1
    labels[r] <- paste0("L", i)
    ids[r] <- if (j == 1) labels[r] else paste0(labels[r], "_", j)
    own <- which(has[i, ])
    for (q in seq_len(p)) {
      base <- if (length(own) && q <= length(own)) concepts[own[q], ] else rnorm(d)
      patches[r, q, ] <- base + noise * rnorm(d)
    }
    patches[r, , ] <- unit(patches[r, , ])
    image[r, ] <- colMeans(patches[r, , ])
  }
  image <- unit(image)
  dimnames(patches) <- list(ids, NULL, NULL)
  rownames(image) <- ids
  list(images = data.frame(id = ids, path = paste0("/synthetic/", ids, ".png"), label = labels, stringsAsFactors = FALSE),
       image = image, patches = patches, concepts = concepts, has = has)
}
```

- [ ] **Step 5: Run the tests**

Run: `Rscript -e 'roxygen2::roxygenise(); pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-images.R")'`
Expected: PASS.

- [ ] **Step 6: Sync; commit if approved** — `git commit -m "Add image sets and embedded image metadata"`.

---

### Task 3: Terms (k-means on patches), scores and the term key

**Files:**
- Create: `R/terms.R`
- Test: `tests/testthat/test-terms.R`

**Interfaces:**
- Consumes: `featureTable()`, `keyFromLeads()`, `keyFromRpart()` (exists), `syntheticVision()`.
- Produces:
  - `inventNames(n, seed = 1)` → unique character(n).
  - `discoverTerms(patches, k = 40, seed = 1, nstart = 10, exemplars = 4)` → list of class `mooseTerms`: `terms` (data.frame `id`, `name`), `centroids` (k×d, unit rows, rownames = names), `exemplars` (data.frame `term`, `image`, `patch`, `score`).
  - `termScores(patches, centroids)` → n×k matrix (rownames image ids, colnames term names).
  - `keyFromTerms(scores, images, terms, method = c("balanced", "rpart"), quantile = 0.6, desc, meta = NULL)` → `moose` with `Feature = "term:<name>"`, `Test`, `Threshold`, `Question = <name>`, `Character = "Has <name>"/"Lacks <name>"`, and `features` rows `kind = "centroid_patch_max"`.

- [ ] **Step 1: Write the failing tests**

`tests/testthat/test-terms.R`:

```r
test_that("inventNames are unique, pronounceable and reproducible", {
  a <- inventNames(200, seed = 3)
  expect_length(unique(a), 200)
  expect_true(all(grepl("^[a-z]{4,14}$", a)))
  expect_identical(a, inventNames(200, seed = 3))
  expect_false(identical(a, inventNames(200, seed = 4)))
})

test_that("discoverTerms finds the planted concepts", {
  v <- syntheticVision(k = 4, p = 9, d = 8)
  t <- discoverTerms(v$patches, k = 4, seed = 1)
  expect_s3_class(t, "mooseTerms")
  expect_equal(dim(t$centroids), c(4, 8))
  expect_equal(unname(round(sqrt(rowSums(t$centroids^2)), 6)), rep(1, 4))
  # every planted concept is close to some centroid
  sims <- v$concepts %*% t(t$centroids)
  expect_true(all(apply(sims, 1, max) > 0.95))
  expect_equal(nrow(t$exemplars), 16)
  expect_equal(names(t$exemplars), c("term", "image", "patch", "score"))
})

test_that("termScores is the max patch cosine per term", {
  v <- syntheticVision()
  t <- discoverTerms(v$patches, k = 4)
  s <- termScores(v$patches, t$centroids)
  expect_equal(dim(s), c(6, 4))
  expect_equal(colnames(s), t$terms$name)
  manual <- max(v$patches[2, , ] %*% t$centroids[3, ])
  expect_equal(unname(s[2, 3]), manual)
})

test_that("keyFromTerms balanced reproduces a hand-worked example", {
  # 4 labels, 3 terms; presence after thresholding is fixed by construction
  scores <- rbind(A = c(1, 1, 0), B = c(1, 0, 1), C = c(0, 1, 1), D = c(0, 0, 0))
  colnames(scores) <- c("t1", "t2", "t3")
  images <- data.frame(id = rownames(scores), path = "", label = rownames(scores), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:3, name = colnames(scores)), centroids = diag(3),
                exemplars = data.frame(term = character(), image = character(), patch = integer(), score = numeric()))
  rownames(terms$centroids) <- colnames(scores)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  # threshold 0.5: t1 splits {A,B} vs {C,D} (balance 1), chosen first by id order
  l <- k$leads
  expect_equal(l$Feature[1:2], c("term:t1", "term:t1"))
  expect_equal(l$Test[1:2], c(">", "<="))
  expect_equal(l$Threshold[1], 0.5)
  expect_equal(l$Question[1], "t1")
  expect_equal(l$Character[1:2], c("Has t1", "Lacks t1"))
  expect_setequal(l$Taxon[l$Next == "-"], c("A", "B", "C", "D"))
  expect_length(k$validate(), 0)
  expect_equal(k$features$id, c("term:t1", "term:t2", "term:t3"))
  expect_equal(k$features$embedding[[2]], c(0, 1, 0))
})

test_that("label presence is any over its images", {
  scores <- rbind(A = c(1, 0), A_2 = c(0, 1), B = c(0, 0), C = c(1, 1))
  colnames(scores) <- c("t1", "t2")
  images <- data.frame(id = rownames(scores), path = "", label = c("A", "A", "B", "C"), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:2, name = colnames(scores)), centroids = diag(2), exemplars = NULL)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  # with threshold 0.5 on each column (quantile over 4 images = 0.5), A has both terms
  expect_equal(sum(k$leads$Next == "-"), 3)
  expect_length(k$validate(), 0)
})

test_that("keyFromTerms rpart route works and labels that cannot be split share a leaf", {
  scores <- rbind(A = c(1, 0), B = c(1, 0), C = c(0, 1))
  colnames(scores) <- c("t1", "t2")
  images <- data.frame(id = rownames(scores), path = "", label = rownames(scores), stringsAsFactors = FALSE)
  terms <- list(terms = data.frame(id = 1:2, name = colnames(scores)), centroids = diag(2), exemplars = NULL)
  class(terms) <- "mooseTerms"
  k <- keyFromTerms(scores, images, terms, quantile = 0.5)
  expect_true("A / B" %in% k$leads$Taxon)
  k2 <- keyFromTerms(scores, images, terms, method = "rpart")
  expect_s3_class(k2, "moose")
  expect_true(all(grepl("^term:", k2$leads$Feature)))
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-terms.R")'`
Expected: FAIL, `could not find function "inventNames"`.

- [ ] **Step 3: Write `R/terms.R`**

```r
#' Invent pronounceable names
#'
#' Random words made of consonant onsets, vowels and codas, for naming
#' visual terms that have no English name (as fordera does).
#'
#' @param n Number of names.
#' @param seed Random seed, so the same call gives the same names.
#' @return A character vector of `n` distinct lower-case words.
#' @export
inventNames <- function(n, seed = 1) {
  onsets <- c("b", "d", "f", "g", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z",
              "bl", "br", "dr", "fl", "fr", "gl", "gr", "kl", "kr", "pl", "pr", "sk", "sl", "sm",
              "sn", "sp", "st", "str", "tr", "th", "sh", "ch", "zh")
  vowels <- c("a", "e", "i", "o", "u", "ae", "ai", "au", "ei", "eu", "ia", "ie", "oa", "oi", "ou", "ua", "y")
  codas <- c("", "", "l", "m", "n", "r", "s", "t", "k", "lm", "ld", "nd", "nt", "rk", "rl", "rn",
             "sk", "st", "ss", "ff", "ps", "x", "ng")
  set.seed(seed)
  out <- character()
  while (length(out) < n) {
    syl <- sample(2:3, 1)
    w <- paste0(vapply(seq_len(syl), function(i) {
      paste0(sample(onsets, 1), sample(vowels, 1), sample(codas, 1))
    }, character(1)), collapse = "")
    if (nchar(w) <= 14 && !w %in% out) out <- c(out, w)
  }
  out
}

#' Discover visual terms by clustering patch embeddings
#'
#' Runs k-means on every patch embedding of every image and keeps the unit
#' length centroids as the definitions of `k` invented terms. An image "has"
#' a term when one of its patches is close to that centroid (see
#' [termScores()]).
#'
#' @param patches A numeric array `images x patches x dimensions` (unit length
#'   rows), e.g. `embedImages(...)$patches`; `dimnames(patches)[[1]]` are the
#'   image ids.
#' @param k Number of terms.
#' @param seed Seed for k-means and for [inventNames()].
#' @param nstart Random starts for [stats::kmeans()].
#' @param exemplars Number of best-matching patches to record per term.
#' @return An object of class `mooseTerms`: `terms` (data frame `id`, `name`),
#'   `centroids` (`k x d`, rows named by term) and `exemplars` (data frame
#'   `term`, `image`, `patch`, `score`).
#' @export
discoverTerms <- function(patches, k = 40, seed = 1, nstart = 10, exemplars = 4) {
  stopifnot(is.array(patches), length(dim(patches)) == 3)
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  ids <- dimnames(patches)[[1]]
  if (is.null(ids)) ids <- as.character(seq_len(n))
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d) # row = patch within image, image-major
  set.seed(seed)
  km <- stats::kmeans(X, centers = k, nstart = nstart, iter.max = 100)
  centroids <- km$centers / sqrt(rowSums(km$centers^2))
  names <- inventNames(k, seed = seed)
  rownames(centroids) <- names
  sims <- X %*% t(centroids)
  ex <- do.call(rbind, lapply(seq_len(k), function(j) {
    top <- order(sims[, j], decreasing = TRUE)[seq_len(min(exemplars, nrow(sims)))]
    data.frame(term = names[j], image = ids[(top - 1) %/% p + 1], patch = as.integer((top - 1) %% p + 1),
               score = sims[top, j], stringsAsFactors = FALSE)
  }))
  rownames(ex) <- NULL
  structure(list(terms = data.frame(id = seq_len(k), name = names, stringsAsFactors = FALSE),
                 centroids = centroids, exemplars = ex), class = "mooseTerms")
}

#' Score images against terms
#'
#' @param patches As in [discoverTerms()].
#' @param centroids A `k x d` matrix of term centroids (unit rows), e.g.
#'   `discoverTerms(...)$centroids`.
#' @return An `images x terms` matrix: for each term, the highest cosine
#'   similarity between the centroid and any patch of the image.
#' @export
termScores <- function(patches, centroids) {
  n <- dim(patches)[1]; p <- dim(patches)[2]; d <- dim(patches)[3]
  X <- matrix(aperm(patches, c(2, 1, 3)), n * p, d)
  sims <- X %*% t(centroids)
  out <- t(vapply(seq_len(n), function(i) apply(sims[(i - 1) * p + seq_len(p), , drop = FALSE], 2, max), numeric(nrow(centroids))))
  if (nrow(centroids) == 1) out <- matrix(out, n, 1)
  dimnames(out) <- list(dimnames(patches)[[1]], rownames(centroids))
  out
}

#' Build a key from term scores
#'
#' Each step asks whether the image has one invented term. `method =
#' "balanced"` is fordera's algorithm: a term is present when its score is
#' above the `quantile` of that term's scores over all images; a label has a
#' term if any of its images does; each split uses the unused term that
#' divides the remaining labels most evenly (ties to the earlier term).
#' `method = "rpart"` grows a classification tree on the scores instead, with
#' the split points as thresholds.
#'
#' @param scores `images x terms` matrix from [termScores()].
#' @param images [imageSet()] data frame with one row per row of `scores`.
#' @param terms The `mooseTerms` object the scores were computed with.
#' @param method `"balanced"` or `"rpart"`.
#' @param quantile Presence threshold quantile for `"balanced"`.
#' @param desc,meta Title and metadata of the key.
#' @return A [moose] key whose leads carry `Feature`, `Test`, `Threshold` and
#'   `Question`, and whose `features` table holds the centroids.
#' @export
keyFromTerms <- function(scores, images, terms, method = c("balanced", "rpart"), quantile = 0.6,
                         desc = "Key generated from visual terms", meta = NULL) {
  method <- match.arg(method)
  stopifnot(nrow(scores) == nrow(images), inherits(terms, "mooseTerms"))
  names <- colnames(scores)
  labels <- images$label
  features <- featureTable(
    id = paste0("term:", names), kind = "centroid_patch_max", label = names,
    embedding = lapply(seq_along(names), function(j) unname(terms$centroids[names[j], ])),
    exemplars = lapply(names, function(nm) {
      ex <- terms$exemplars
      if (is.null(ex)) NULL else { r <- ex[ex$term == nm, c("image", "patch", "score")]; rownames(r) <- NULL; r }
    })
  )
  if (method == "rpart") {
    data <- data.frame(label = factor(labels), as.data.frame(scores), check.names = FALSE)
    fit <- rpart::rpart(stats::reformulate(paste0("`", names, "`"), "label"), data = data, method = "class", y = TRUE,
      control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0, xval = 0, maxcompete = 0))
    key <- keyFromRpart(fit, desc, meta)
    leads <- key$leads
    # rpart labels look like "`t1`>=0.5" / "`t1`< 0.5": recover feature, test, threshold
    m <- regmatches(leads$Character, regexec("^`?([^`]+)`?: ?(>=|<|>|<=) ?([-0-9.e]+)$", leads$Character))
    leads$Feature <- paste0("term:", vapply(m, `[`, "", 2))
    op <- vapply(m, `[`, "", 3)
    leads$Threshold <- as.numeric(vapply(m, `[`, "", 4))
    leads$Test <- ifelse(op %in% c(">=", ">"), ">", "<=")
    leads$Threshold[op == ">="] <- leads$Threshold[op == ">="] - 1e-9
    leads$Threshold[op == "<"] <- leads$Threshold[op == "<"] - 1e-9
    leads$Question <- sub("^term:", "", leads$Feature)
    leads$Character <- ifelse(leads$Test == ">", paste("Has", leads$Question), paste("Lacks", leads$Question))
    return(keyFromLeads(leads, desc, meta, features = features))
  }
  thresholds <- apply(scores, 2, stats::quantile, probs = quantile, type = 7, names = FALSE)
  present <- sweep(scores, 2, thresholds, ">")
  ulab <- sort(unique(labels))
  labPresent <- t(vapply(ulab, function(l) apply(present[labels == l, , drop = FALSE], 2, any), logical(ncol(scores))))
  if (ncol(scores) == 1) labPresent <- matrix(labPresent, length(ulab), 1)
  rows <- list(); counter <- 0L
  build <- function(idx, used, depth) {
    if (length(idx) == 1 || depth > 20) return(list(leaf = paste(ulab[idx], collapse = " / ")))
    best <- NULL; bestScore <- -1
    for (j in seq_along(names)) {
      if (j %in% used) next
      yes <- idx[labPresent[idx, j]]; no <- idx[!labPresent[idx, j]]
      if (!length(yes) || !length(no)) next
      bal <- min(length(yes), length(no)) / max(length(yes), length(no))
      if (bal > bestScore) { bestScore <- bal; best <- list(j = j, yes = yes, no = no) }
    }
    if (is.null(best)) return(list(leaf = paste(ulab[idx], collapse = " / ")))
    counter <<- counter + 1L
    id <- as.character(counter)
    kids <- list(build(best$yes, c(used, best$j), depth + 1), build(best$no, c(used, best$j), depth + 1))
    nm <- names[best$j]
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"), Character = c(paste("Has", nm), paste("Lacks", nm)),
      Next = vapply(kids, function(k) if (is.null(k$leaf)) k$id else "-", ""),
      Taxon = vapply(kids, function(k) if (is.null(k$leaf)) "" else k$leaf, ""),
      Question = nm, Feature = paste0("term:", nm), Test = c(">", "<="), Threshold = thresholds[[j <- best$j]],
      stringsAsFactors = FALSE)
    list(id = id)
  }
  top <- build(seq_along(ulab), integer(), 0)
  if (!is.null(top$leaf)) stop("No term separates the labels", call. = FALSE)
  leads <- do.call(rbind, rows[order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  if (is.null(meta)) meta <- data.frame(key = "node_label", value = "Term", stringsAsFactors = FALSE)
  keyFromLeads(leads, desc, meta, features = features)
}
```

Note on numbering: `counter` is incremented when a split is *created*, before its children are built, so couplets are numbered in preorder with the yes branch first, matching the converter used in `verify.R` (Task 10).

Note on rpart labels: `keyFromRpart()` turns `labels(fit)` into `"`t1`: >=0.5"` style strings (it replaces `=` with `: `; rpart writes `>=` for numeric splits). Check the exact text with `keyFromRpart(fit)$leads$Character` when implementing and adjust the regex so the test passes; the regex above accepts `\`t1\`: >=0.5`, `\`t1\`: < 0.5` and the unquoted forms.

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'roxygen2::roxygenise(); pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-terms.R")'`
Expected: PASS. If `discoverTerms` misses a planted concept, raise `nstart` in the test call rather than loosening the threshold.

- [ ] **Step 5: Sync; commit if approved** — `git commit -m "Add invented visual terms and keyFromTerms"`.

---

### Task 4: `classify()`, `evaluateKey()` and `looKey()`

**Files:**
- Modify: `R/features.R`
- Test: `tests/testthat/test-features.R` (append)

**Interfaces:**
- Consumes: `keyFromTerms()`, `termScores()`, `syntheticVision()`.
- Produces:
  - `classify(key, scores)` → data.frame `id`, `result` (NA when unresolved), `path` (lead labels joined by `" "`, e.g. `"1a 2b"`).
  - `evaluateKey(key, scores, labels, groups = NULL)` → list `results` (data.frame `id, actual, predicted, correct, groupCorrect`), `accuracy`, `groupAccuracy` (NA without `groups`), `confusion` (table).
  - `looKey(images, build, score, groups = NULL)` → same shape as `evaluateKey()`; `build(train)` takes row indices and returns a key; `score(key, test)` takes the key and one row index and returns a 1-row scores matrix.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-features.R`:

```r
termFixture <- function() {
  v <- syntheticVision(k = 4)
  t <- discoverTerms(v$patches, k = 4)
  s <- termScores(v$patches, t$centroids)
  list(v = v, t = t, s = s, key = keyFromTerms(s, v$images, t, quantile = 0.5))
}

test_that("classify walks every image to a result and records the path", {
  f <- termFixture()
  r <- classify(f$key, f$s)
  expect_equal(names(r), c("id", "result", "path"))
  expect_equal(r$id, rownames(f$s))
  expect_true(all(r$result %in% f$key$leads$Taxon))
  expect_match(r$path[1], "^1[ab]( [0-9]+[ab])*$")
})

test_that("unresolvable couplet gives NA", {
  f <- termFixture()
  s <- f$s
  s[1, ] <- NA
  r <- classify(f$key, s)
  expect_true(is.na(r$result[1]))
  expect_equal(r$path[1], "")
  bad <- f$key$clone()
  l <- bad$leads; l$Test <- ">"; bad$leads <- l # both leads pass
  expect_true(all(is.na(classify(bad, f$s)$result)))
})

test_that("classify needs every feature column", {
  f <- termFixture()
  expect_error(classify(f$key, f$s[, 1:2]), "missing scores")
})

test_that("evaluateKey reports accuracy and groups", {
  f <- termFixture()
  e <- evaluateKey(f$key, f$s, f$v$images$label, groups = c(L1 = "g1", L2 = "g1", L3 = "g2", L4 = "g2", L5 = "g3", L6 = "g3"))
  expect_equal(e$accuracy, 1)
  expect_equal(e$groupAccuracy, 1)
  expect_s3_class(e$confusion, "table")
  expect_equal(nrow(e$results), 6)
})

test_that("looKey rebuilds without the held-out image", {
  f <- termFixture()
  calls <- 0
  e <- looKey(f$v$images,
    build = function(train) { calls <<- calls + 1; keyFromTerms(f$s[train, , drop = FALSE], f$v$images[train, ], f$t, quantile = 0.5) },
    score = function(key, test) f$s[test, , drop = FALSE])
  expect_equal(calls, 6)
  expect_true(e$accuracy >= 0 && e$accuracy <= 1)
  expect_equal(nrow(e$results), 6)
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-features.R")'`
Expected: FAIL, `could not find function "classify"`.

- [ ] **Step 3: Implement**

Append to `R/features.R`:

```r
#' Follow a key by machine
#'
#' Walks each row of `scores` through `key`: at every couplet the lead whose
#' test (`Feature`, `Test`, `Threshold`) passes is taken. When no lead or
#' more than one passes (for instance on a missing score), the result is `NA`.
#'
#' @param key A [moose] key with `Feature`, `Test` and `Threshold` lead
#'   columns, e.g. from [keyFromTerms()].
#' @param scores A numeric matrix, one row per object, with a column for every
#'   feature id the key tests (see [featureScores()] and [scoreImages()]).
#' @return A data frame with `id` (row names of `scores`), `result` and
#'   `path` (the leads taken, e.g. `"1a 3b"`).
#' @export
classify <- function(key, scores) {
  leads <- normalizeLeads(key$leads)
  needed <- unique(leads$Feature[nzchar(leads$Feature)])
  if (length(needed) == 0) stop("This key has no machine-readable tests", call. = FALSE)
  if (is.null(dim(scores))) scores <- matrix(scores, 1, dimnames = list(NULL, names(scores)))
  missing <- setdiff(needed, colnames(scores))
  if (length(missing)) stop("`scores` is missing scores for: ", paste(missing, collapse = ", "), call. = FALSE)
  root <- checkLeads(leads)$root
  byCouplet <- split(seq_len(nrow(leads)), leads$Statement)
  ids <- rownames(scores); if (is.null(ids)) ids <- as.character(seq_len(nrow(scores)))
  walk <- function(s) {
    cp <- root; path <- character(); seen <- character()
    repeat {
      if (cp %in% seen) return(list(NA_character_, path))
      seen <- c(seen, cp)
      i <- byCouplet[[cp]]
      v <- s[leads$Feature[i]]
      ok <- ifelse(leads$Test[i] == ">", v > leads$Threshold[i], v <= leads$Threshold[i])
      ok[is.na(ok)] <- FALSE
      if (sum(ok) != 1) return(list(NA_character_, path))
      take <- i[ok]
      path <- c(path, paste0(leads$Statement[take], leads$Choice[take]))
      if (leads$Next[take] == "-") return(list(leads$Taxon[take], path))
      cp <- leads$Next[take]
      if (!cp %in% names(byCouplet)) return(list(NA_character_, path))
    }
  }
  res <- lapply(seq_len(nrow(scores)), function(r) walk(scores[r, ]))
  data.frame(id = ids, result = vapply(res, `[[`, "", 1),
             path = vapply(res, function(x) paste(x[[2]], collapse = " "), ""), stringsAsFactors = FALSE)
}

#' Accuracy of a key followed by machine
#'
#' @inheritParams classify
#' @param labels True label of each row of `scores`.
#' @param groups Optional named vector mapping labels to coarser groups (e.g.
#'   model years to generations) for a second accuracy figure.
#' @return A list: `results` (one row per object with `actual`, `predicted`,
#'   `correct`, `groupCorrect`), `accuracy`, `groupAccuracy` and `confusion`.
#' @export
evaluateKey <- function(key, scores, labels, groups = NULL) {
  r <- classify(key, scores)
  r$actual <- as.character(labels)
  r$predicted <- r$result; r$result <- NULL
  r$correct <- !is.na(r$predicted) & r$predicted == r$actual
  r$groupCorrect <- if (is.null(groups)) NA else !is.na(r$predicted) & groups[r$predicted] == groups[r$actual]
  r$groupCorrect[is.na(r$groupCorrect)] <- FALSE
  list(results = r[, c("id", "actual", "predicted", "correct", "groupCorrect", "path")],
       accuracy = mean(r$correct),
       groupAccuracy = if (is.null(groups)) NA_real_ else mean(r$groupCorrect),
       confusion = table(actual = r$actual, predicted = ifelse(is.na(r$predicted), "<none>", r$predicted)))
}

#' Leave-one-out evaluation of a key builder
#'
#' @param images [imageSet()] data frame of all images.
#' @param build Function of the training row indices returning a key.
#' @param score Function of (key, test row index) returning a one-row scores
#'   matrix for that image.
#' @param groups As in [evaluateKey()].
#' @return As [evaluateKey()].
#' @export
looKey <- function(images, build, score, groups = NULL) {
  n <- nrow(images)
  rows <- lapply(seq_len(n), function(i) {
    key <- build(setdiff(seq_len(n), i))
    r <- classify(key, score(key, i))
    data.frame(id = images$id[i], actual = images$label[i], predicted = r$result[1], path = r$path[1], stringsAsFactors = FALSE)
  })
  r <- do.call(rbind, rows)
  r$correct <- !is.na(r$predicted) & r$predicted == r$actual
  r$groupCorrect <- if (is.null(groups)) NA else !is.na(r$predicted) & groups[r$predicted] == groups[r$actual]
  r$groupCorrect[is.na(r$groupCorrect)] <- FALSE
  list(results = r[, c("id", "actual", "predicted", "correct", "groupCorrect", "path")],
       accuracy = mean(r$correct),
       groupAccuracy = if (is.null(groups)) NA_real_ else mean(r$groupCorrect),
       confusion = table(actual = r$actual, predicted = ifelse(is.na(r$predicted), "<none>", r$predicted)))
}
```

- [ ] **Step 4: Run the tests**

Run: `Rscript -e 'roxygen2::roxygenise(); pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-features.R")'`
Expected: PASS.

- [ ] **Step 5: Sync; commit if approved** — `git commit -m "Add classify, evaluateKey and looKey"`.

---

### Task 5: `featureScores()` (scores from embeddings, model-free)

**Files:**
- Modify: `R/features.R`
- Test: `tests/testthat/test-features.R` (append)

**Interfaces:**
- Produces: `featureScores(key, image = NULL, patches = NULL, textEmb = NULL)` → `objects x features` matrix with colnames = feature ids. `image`: n×d unit rows; `patches`: n×p×d; `textEmb`: m×d with rownames = prompt texts (needed for `clip_text_pair` features).

- [ ] **Step 1: Write the failing tests**

```r
test_that("featureScores computes term and text features from embeddings", {
  f <- termFixture()
  s <- featureScores(f$key, patches = f$v$patches)
  expect_equal(colnames(s), f$key$features$id)
  expect_equal(unname(s[, 1]), unname(f$s[, sub("^term:", "", f$key$features$id[1])]))

  textFeat <- featureTable("text:q", "clip_text_pair", prompt = "a thing with q", negative_prompt = "a thing with not q")
  leads <- data.frame(Statement = "1", Choice = c("a", "b"), Character = c("Has q", "Lacks q"), Next = "-",
    Taxon = c("A", "B"), Feature = "text:q", Test = c(">", "<="), Threshold = 0, stringsAsFactors = FALSE)
  k <- keyFromLeads(leads, "t", features = textFeat)
  img <- rbind(x = c(1, 0), y = c(0, 1))
  txt <- rbind(c(1, 0), c(0, 1)); rownames(txt) <- c("a thing with q", "a thing with not q")
  s2 <- featureScores(k, image = img, textEmb = txt)
  expect_equal(unname(s2[, "text:q"]), c(1, -1))
  expect_equal(classify(k, s2)$result, c("A", "B"))
  expect_error(featureScores(k, image = img), "textEmb")
  expect_error(featureScores(f$key, image = img), "patches")
})
```

- [ ] **Step 2: Run to verify failure** — Expected: `could not find function "featureScores"`.

- [ ] **Step 3: Implement**

```r
#' Compute a key's feature scores from embeddings
#'
#' Model-free: give it the embeddings and it applies each feature's rule.
#' `centroid_patch_max` features need `patches`; `clip_text_pair` features
#' need `image` and `textEmb` (rows named by prompt). For `external`
#' features supply the scores yourself.
#'
#' @param key A [moose] key with a `features` table.
#' @param image `objects x d` matrix of image embeddings (unit rows).
#' @param patches `objects x patches x d` array of patch embeddings.
#' @param textEmb `prompts x d` matrix of text embeddings whose row names are
#'   the prompt texts, e.g. from [embedTexts()].
#' @return An `objects x features` matrix with feature ids as column names.
#' @seealso [scoreImages()] for images-to-scores in one call.
#' @export
featureScores <- function(key, image = NULL, patches = NULL, textEmb = NULL) {
  f <- key$features
  if (is.null(f)) stop("This key has no features table", call. = FALSE)
  n <- if (!is.null(image)) nrow(image) else if (!is.null(patches)) dim(patches)[1] else stop("Give `image` or `patches`", call. = FALSE)
  ids <- if (!is.null(image)) rownames(image) else dimnames(patches)[[1]]
  out <- matrix(NA_real_, n, nrow(f), dimnames = list(ids, f$id))
  for (j in seq_len(nrow(f))) {
    kind <- f$kind[j]
    if (kind == "centroid_patch_max") {
      if (is.null(patches)) stop("Feature ", f$id[j], " needs `patches`", call. = FALSE)
      out[, j] <- termScores(patches, matrix(f$embedding[[j]], 1))[, 1]
    } else if (kind == "clip_text_pair") {
      if (is.null(image) || is.null(textEmb)) stop("Feature ", f$id[j], " needs `image` and `textEmb`", call. = FALSE)
      for (p in c(f$prompt[j], f$negative_prompt[j])) if (!p %in% rownames(textEmb)) stop("`textEmb` has no row for the prompt: ", p, call. = FALSE)
      out[, j] <- image %*% textEmb[f$prompt[j], ] - image %*% textEmb[f$negative_prompt[j], ]
    } else if (kind != "external") {
      stop("Unknown feature kind: ", kind, call. = FALSE)
    }
  }
  out
}
```

- [ ] **Step 4: Run the tests** — Expected: PASS.
- [ ] **Step 5: Sync; commit if approved** — `git commit -m "Add featureScores"`.

---

### Task 6: The question key (`keyFromClusters`)

**Files:**
- Create: `R/questions.R`
- Test: `tests/testthat/test-questions.R`

**Interfaces:**
- Produces:
  - `vocabularyPrompts(vocabulary, template = "{x}")` → character vector, `c(rbind(yesPrompts, noPrompts))` (feature then opposite for each pair). `vocabulary` is a data.frame with `feature`, `opposite` and optional `region`.
  - `keyFromClusters(image, images, vocabulary, textEmb, template = "{x}", order = NULL, maxPerSide = 10, calibrate = c("none", "midpoint"), desc, meta = NULL)` → `moose` with `Feature = "text:<slug>"`, `Question = "Does it have <feature>?"`, `Character = "Has <feature>"` (lead a) / `"Has <opposite>"` (lead b), features `kind = "clip_text_pair"` with `prompt`/`negative_prompt` (the yes/no prompts as embedded) and `region`. `order` is a function of a character vector of labels returning a sort key (smallest goes to the first branch).

- [ ] **Step 1: Write the failing tests**

`tests/testthat/test-questions.R`:

```r
vocabFixture <- function() {
  # 4 labels whose image embeddings are built from the text directions, so
  # that question choice is deterministic
  vocab <- data.frame(feature = c("round lights", "a flat hood"), opposite = c("square lights", "a curved hood"),
                      region = c("0.15,0.55,0,1", NA), stringsAsFactors = FALSE)
  prompts <- vocabularyPrompts(vocab, "a truck with {x}")
  txt <- rbind(c(1, 0, 0, 0), c(-1, 0, 0, 0), c(0, 1, 0, 0), c(0, -1, 0, 0))
  rownames(txt) <- prompts
  img <- rbind(A = c(1, 1, 0.1, 0), B = c(1, -1, 0, 0.1), C = c(-1, 1, 0.1, 0), D = c(-1, -1, 0, 0.1))
  img <- img / sqrt(rowSums(img^2))
  images <- data.frame(id = rownames(img), path = "", label = rownames(img), stringsAsFactors = FALSE)
  list(vocab = vocab, prompts = prompts, txt = txt, img = img, images = images)
}

test_that("vocabularyPrompts interleaves feature and opposite", {
  f <- vocabFixture()
  expect_equal(f$prompts, c("a truck with round lights", "a truck with square lights", "a truck with a flat hood", "a truck with a curved hood"))
})

test_that("keyFromClusters builds a valid key with text features", {
  f <- vocabFixture()
  k <- keyFromClusters(f$img, f$images, f$vocab, f$txt, template = "a truck with {x}")
  expect_length(k$validate(), 0)
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], c("A", "B", "C", "D"))
  expect_true(all(k$features$kind == "clip_text_pair"))
  expect_equal(k$features$region[k$features$id == "text:round_lights"], "0.15,0.55,0,1")
  expect_match(k$leads$Question[1], "^Does it have ")
  expect_equal(k$leads$Test[1:2], c(">", "<="))
  s <- featureScores(k, image = f$img, textEmb = f$txt)
  expect_equal(evaluateKey(k, s, f$images$label)$accuracy, 1)
})

test_that("yes lead points at the side that has the feature", {
  f <- vocabFixture()
  # Reverse the embedding of the first pair so the forward direction scores
  # negative on whatever split uses it: the "Has round lights" lead must still
  # lead to the labels whose embedding is positive on axis 1 (A and B).
  txt <- f$txt; txt[1, ] <- c(-1, 0, 0, 0); txt[2, ] <- c(1, 0, 0, 0)
  k <- keyFromClusters(f$img, f$images, f$vocab, txt, template = "a truck with {x}")
  s <- featureScores(k, image = f$img, textEmb = txt)
  r <- classify(k, s)
  expect_equal(r$result, c("A", "B", "C", "D"))
  i <- which(k$leads$Feature == "text:round_lights" & k$leads$Test == ">")[1]
  expect_equal(k$leads$Character[i], "Has round lights")
})

test_that("order puts the smaller key first and midpoint calibration moves the threshold", {
  f <- vocabFixture()
  k <- keyFromClusters(f$img, f$images, f$vocab, f$txt, template = "a truck with {x}",
                       order = function(l) min(match(l, c("D", "C", "B", "A"))), calibrate = "midpoint")
  expect_false(all(k$leads$Threshold == 0))
  expect_length(k$validate(), 0)
})

test_that("a question is not reused below itself", {
  f <- vocabFixture()
  k <- keyFromClusters(f$img, f$images, f$vocab, f$txt, template = "a truck with {x}")
  paths <- strsplit(classify(k, featureScores(k, f$img, textEmb = f$txt))$path, " ")
  for (p in paths) {
    cps <- sub("[ab]$", "", p)
    expect_equal(anyDuplicated(k$leads$Feature[match(cps, k$leads$Statement)]), 0)
  }
})
```

- [ ] **Step 2: Run to verify failure** — Expected: `could not find function "vocabularyPrompts"`.

- [ ] **Step 3: Implement `R/questions.R`**

```r
#' Prompts for a vocabulary of visual features
#'
#' @param vocabulary Data frame with `feature` and `opposite` columns (and an
#'   optional `region`, `"y0,y1,x0,x1"` fractions).
#' @param template Text with `{x}` where the feature goes, e.g.
#'   `"a pickup truck with {x}"`.
#' @return A character vector: the feature prompt then the opposite prompt
#'   for each row, in order. Embed these with [embedTexts()] and pass the
#'   result to [keyFromClusters()].
#' @export
vocabularyPrompts <- function(vocabulary, template = "{x}") {
  stopifnot(all(c("feature", "opposite") %in% names(vocabulary)))
  fill <- function(x) sub("{x}", x, template, fixed = TRUE)
  c(rbind(vapply(vocabulary$feature, fill, ""), vapply(vocabulary$opposite, fill, "")))
}

slug <- function(x) gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(x)))

#' Build a key by clustering classes and describing each split
#'
#' Classes are clustered on the mean embedding of their images (Ward's
#' method), giving a binary tree. Each split is then described by the
#' vocabulary pair that best separates its two sides: the pair maximising
#' |(L.yes - L.no) - (R.yes - R.no)| over the side means, not used above
#' that split. The "Has feature" lead goes to the side the feature scores
#' higher on. Machine answers use the same two prompts.
#'
#' @param image `images x d` matrix of unit-length image embeddings.
#' @param images [imageSet()] data frame, one row per row of `image`.
#' @param vocabulary As in [vocabularyPrompts()].
#' @param textEmb Text embeddings of `vocabularyPrompts(vocabulary, template)`,
#'   rows named by prompt (as [embedTexts()] returns them).
#' @param template Must match the one used to make `textEmb`.
#' @param order Optional function of a character vector of labels returning
#'   a number; at each split the child with the smaller value comes first.
#' @param maxPerSide Most images per side used for the side means.
#' @param calibrate `"none"` (threshold 0) or `"midpoint"` (halfway between
#'   the two sides' mean scores).
#' @param desc,meta Title and metadata.
#' @return A [moose] key with `clip_text_pair` features.
#' @export
keyFromClusters <- function(image, images, vocabulary, textEmb, template = "{x}", order = NULL,
                            maxPerSide = 10, calibrate = c("none", "midpoint"),
                            desc = "Key generated from image clusters", meta = NULL) {
  calibrate <- match.arg(calibrate)
  stopifnot(nrow(image) == nrow(images))
  prompts <- vocabularyPrompts(vocabulary, template)
  missing <- setdiff(prompts, rownames(textEmb))
  if (length(missing)) stop("`textEmb` lacks rows for ", length(missing), " prompt(s), e.g. ", missing[1], call. = FALSE)
  yesP <- prompts[c(TRUE, FALSE)]; noP <- prompts[c(FALSE, TRUE)]
  labels <- images$label
  ulab <- sort(unique(labels))
  means <- t(vapply(ulab, function(l) colMeans(image[labels == l, , drop = FALSE]), numeric(ncol(image))))
  means <- means / sqrt(rowSums(means^2))
  if (length(ulab) < 2) stop("Need at least two labels", call. = FALSE)
  hc <- stats::hclust(stats::dist(means), method = "ward.D2")

  # hclust merge -> nested list of label indices
  node <- function(i) if (i < 0) list(leaf = -i) else {
    kids <- list(node(hc$merge[i, 1]), node(hc$merge[i, 2]))
    if (!is.null(order)) {
      key <- vapply(kids, function(k) order(ulab[leavesOf(k)]), numeric(1))
      kids <- kids[base::order(key)]
    }
    list(kids = kids)
  }
  leavesOf <- function(nd) if (!is.null(nd$leaf)) nd$leaf else unlist(lapply(nd$kids, leavesOf))

  sideMean <- function(labIdx) {
    rows <- which(labels %in% ulab[labIdx])[seq_len(min(maxPerSide, sum(labels %in% ulab[labIdx])))]
    colMeans(image[rows, , drop = FALSE])
  }
  rows <- list(); counter <- 0L; featUsed <- integer()
  build <- function(nd, used) {
    if (!is.null(nd$leaf)) return(list(leaf = ulab[nd$leaf]))
    L <- leavesOf(nd$kids[[1]]); R <- leavesOf(nd$kids[[2]])
    lm <- sideMean(L); rm <- sideMean(R)
    sL <- as.numeric(lm %*% t(textEmb[yesP, , drop = FALSE])) - as.numeric(lm %*% t(textEmb[noP, , drop = FALSE]))
    sR <- as.numeric(rm %*% t(textEmb[yesP, , drop = FALSE])) - as.numeric(rm %*% t(textEmb[noP, , drop = FALSE]))
    forward <- sL - sR
    cand <- setdiff(seq_along(yesP), used)
    if (!length(cand)) cand <- seq_along(yesP)
    j <- cand[which.max(abs(forward[cand]))]
    hasSide <- if (forward[j] >= 0) 1 else 2 # which child has the feature
    featUsed <<- union(featUsed, j)
    counter <<- counter + 1L
    id <- as.character(counter)
    kidsOrdered <- if (hasSide == 1) nd$kids else rev(nd$kids)
    built <- lapply(kidsOrdered, build, used = c(used, j))
    thr <- if (calibrate == "midpoint") (sL[j] + sR[j]) / 2 else 0
    rows[[id]] <<- data.frame(
      Statement = id, Choice = c("a", "b"),
      Character = c(paste("Has", vocabulary$feature[j]), paste("Has", vocabulary$opposite[j])),
      Next = vapply(built, function(b) if (is.null(b$leaf)) b$id else "-", ""),
      Taxon = vapply(built, function(b) if (is.null(b$leaf)) "" else b$leaf, ""),
      Question = paste0("Does it have ", vocabulary$feature[j], "?"),
      Feature = paste0("text:", slug(vocabulary$feature[j])), Test = c(">", "<="), Threshold = thr,
      stringsAsFactors = FALSE)
    list(id = id)
  }
  build(node(nrow(hc$merge)), integer())
  leads <- do.call(rbind, rows[base::order(as.integer(names(rows)))])
  rownames(leads) <- NULL
  used <- sort(featUsed)
  features <- featureTable(
    id = paste0("text:", slug(vocabulary$feature[used])), kind = "clip_text_pair",
    label = vocabulary$feature[used], prompt = yesP[used], negative_prompt = noP[used],
    region = if (is.null(vocabulary$region)) NA else vocabulary$region[used]
  )
  if (is.null(meta)) meta <- data.frame(key = "node_label", value = "Question", stringsAsFactors = FALSE)
  keyFromLeads(leads, desc, meta, features = features)
}
```

Careful: the local `order` argument shadows `base::order`; the code calls `base::order()` explicitly where the sort is meant. If `vocabulary$feature` slugs collide, `featureTable` gets duplicate ids; add `if (anyDuplicated(slug(vocabulary$feature))) stop("Vocabulary features must have distinct names", call. = FALSE)` at the top.

- [ ] **Step 4: Run the tests** — Expected: PASS.
- [ ] **Step 5: Sync; commit if approved** — `git commit -m "Add keyFromClusters: question keys from clustered classes"`.

---

### Task 7: Python layer — `moose_vision.py` with pytest

**Files:**
- Create: `inst/python/moose_vision.py`
- Create: `tests/python/test_moose_vision.py`
- Create: `inst/python/requirements.txt` (`torch`, `open_clip_torch`, `pillow`, `numpy`)

**Interfaces:**
- Produces (Python):
  - `load_model(name="ViT-B-32", pretrained="openai", weights=None, device="cpu") -> VisionModel` with attributes `model`, `preprocess`, `tokenizer`, `spec` (dict: `library`, `arch`, `pretrained`, `weights_sha256` or None, `image_size`, `dim`, `patch_grid`).
  - `embed_images(vm, paths, region=None, patches=True, batch=16) -> dict(image=np.float32[n,d], patches=np.float32[n,p,d] or None)`, all rows unit length.
  - `embed_texts(vm, texts) -> np.float32[m,d]`, unit rows.
  - `patch_box(vm, path, patch_index) -> (x0, y0, x1, y1)` in original pixels, `patch_index` 0-based row-major.
  - `crop_png(path, box, pad=48, size=96) -> str` base64 PNG.
  - `exemplar_pngs(vm, paths, patch_indices, pad=48, size=96) -> list[str]`.

- [ ] **Step 1: Write the failing pytest**

`tests/python/test_moose_vision.py`:

```python
import os, sys, base64, io
import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "inst", "python"))
import moose_vision as mv

WEIGHTS = os.environ.get("MOOSE_CLIP_WEIGHTS")
pytestmark = pytest.mark.skipif(not WEIGHTS, reason="MOOSE_CLIP_WEIGHTS not set")


@pytest.fixture(scope="module")
def vm():
    return mv.load_model(weights=WEIGHTS)


@pytest.fixture(scope="module")
def pics(tmp_path_factory):
    d = tmp_path_factory.mktemp("pics")
    rng = np.random.default_rng(0)
    paths = []
    for i, (w, h) in enumerate([(224, 224), (400, 300), (300, 400)]):
        a = rng.integers(0, 255, (h, w, 3), dtype=np.uint8)
        a[h // 4:h // 2, w // 4:w // 2] = (255, 0, 0)
        p = d / f"p{i}.png"
        Image.fromarray(a).save(p)
        paths.append(str(p))
    return paths


def test_spec(vm):
    assert vm.spec["arch"] == "ViT-B-32"
    assert vm.spec["dim"] == 512
    assert vm.spec["patch_grid"] == 7
    assert vm.spec["weights_sha256"] == "40d365715913c9da98579312b702a82c18be219cc2a73407c4526f58eba950af"


def test_embed_images_shapes_and_norms(vm, pics):
    out = mv.embed_images(vm, pics)
    assert out["image"].shape == (3, 512)
    assert out["patches"].shape == (3, 49, 512)
    assert np.allclose(np.linalg.norm(out["image"], axis=1), 1, atol=1e-4)
    assert np.allclose(np.linalg.norm(out["patches"], axis=2), 1, atol=1e-4)
    assert mv.embed_images(vm, pics, patches=False)["patches"] is None


def test_region_changes_embedding(vm, pics):
    whole = mv.embed_images(vm, pics[:1], patches=False)["image"]
    top = mv.embed_images(vm, pics[:1], region=(0.0, 0.5, 0.0, 1.0), patches=False)["image"]
    assert not np.allclose(whole, top, atol=1e-3)


def test_embed_texts(vm):
    t = mv.embed_texts(vm, ["a red square", "a blue circle"])
    assert t.shape == (2, 512)
    assert np.allclose(np.linalg.norm(t, axis=1), 1, atol=1e-4)
    assert t[0] @ t[1] < 0.99


def test_patch_box_on_a_400x300_image(vm, pics):
    # 400x300: shorter side 300 -> 224 (scale 224/300), then center crop 224 wide
    # from 298.67 wide: offset 37.33 px in the resized image = 50 px original
    x0, y0, x1, y1 = mv.patch_box(vm, pics[1], 0)
    assert abs(x0 - 50) < 1 and y0 == 0
    assert abs((x1 - x0) - 32 * 300 / 224) < 1
    x0, y0, x1, y1 = mv.patch_box(vm, pics[1], 48)
    assert abs(x1 - 350) < 1 and abs(y1 - 300) < 1
    # square image: patch 8 (row 1, col 1) is at 32..64 px
    assert mv.patch_box(vm, pics[0], 8) == (32, 32, 64, 64)


def test_crop_png_and_exemplars(vm, pics):
    b64 = mv.crop_png(pics[0], (32, 32, 64, 64), pad=16, size=48)
    img = Image.open(io.BytesIO(base64.b64decode(b64)))
    assert img.size == (48, 48)
    pngs = mv.exemplar_pngs(vm, [pics[0], pics[1]], [8, 48])
    assert len(pngs) == 2 and all(isinstance(p, str) for p in pngs)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd /home/claude/moose && MOOSE_CLIP_WEIGHTS=/home/claude/weights/ViT-B-32.pt python3 -m pytest tests/python -q`
Expected: FAIL, `ModuleNotFoundError: No module named 'moose_vision'`. (First stage the weights: `device_stage_files` of `/Users/leipzig/Documents/moose/ViT-B-32.pt`, then `mkdir -p /home/claude/weights && cp /mnt/user-data/uploads/moose/ViT-B-32.pt /home/claude/weights/`.)

- [ ] **Step 3: Write `inst/python/moose_vision.py`**

```python
"""Embeddings and crops for moose vision keys.

Everything that needs a model or pixels lives here; moose's R code only ever
sees the numpy arrays these functions return.
"""
import base64
import hashlib
import io
from dataclasses import dataclass, field

import numpy as np
import torch
from PIL import Image

import open_clip


@dataclass
class VisionModel:
    model: object
    preprocess: object
    tokenizer: object
    spec: dict = field(default_factory=dict)


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_model(name="ViT-B-32", pretrained="openai", weights=None, device="cpu"):
    """Load a CLIP model through open_clip.

    `weights` is a local checkpoint (an OpenAI `.pt` file works); without it
    open_clip downloads `pretrained` for `name`.
    """
    if weights:
        model = open_clip.load_openai_model(weights, device=device)
        preprocess = open_clip.image_transform(model.visual.image_size, is_train=False)
    else:
        model, _, preprocess = open_clip.create_model_and_transforms(name, pretrained=pretrained, device=device)
    model.eval()
    tokenizer = open_clip.get_tokenizer(name)
    image_size = model.visual.image_size
    if isinstance(image_size, (tuple, list)):
        image_size = image_size[0]
    patch = model.visual.conv1.kernel_size[0]
    spec = {
        "library": "open_clip " + open_clip.__version__,
        "arch": name,
        "pretrained": pretrained if not weights else "file",
        "weights_sha256": _sha256(weights) if weights else None,
        "image_size": int(image_size),
        "patch_size": int(patch),
        "patch_grid": int(image_size // patch),
        "dim": int(model.text_projection.shape[1]) if hasattr(model, "text_projection") else int(model.visual.output_dim),
        "embedding": "patch_tokens(ln_post, proj)",
    }
    return VisionModel(model, preprocess, tokenizer, spec)


def _open(path, region=None):
    img = Image.open(path).convert("RGB")
    if region is not None:
        y0, y1, x0, x1 = [float(v) for v in region]
        w, h = img.size
        img = img.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    return img


def _unit(a, axis=-1):
    return a / (np.linalg.norm(a, axis=axis, keepdims=True) + 1e-8)


def embed_images(vm, paths, region=None, patches=True, batch=16):
    """Global and (optionally) patch embeddings, unit length, float32."""
    paths = list(paths)
    visual = vm.model.visual
    captured = {}

    def hook(_module, _inputs, output):
        captured["tokens"] = output

    handle = visual.transformer.register_forward_hook(hook) if patches else None
    images, patch_out = [], []
    try:
        with torch.no_grad():
            for start in range(0, len(paths), batch):
                chunk = paths[start:start + batch]
                x = torch.stack([vm.preprocess(_open(p, region)) for p in chunk])
                feats = vm.model.encode_image(x)
                images.append(_unit(feats.float().cpu().numpy()))
                if patches:
                    tok = captured["tokens"]
                    if not getattr(visual.transformer, "batch_first", True):
                        tok = tok.permute(1, 0, 2)  # LND -> NLD
                    tok = visual.ln_post(tok)
                    if visual.proj is not None:
                        tok = tok @ visual.proj
                    tok = tok[:, 1:, :]  # drop the class token
                    patch_out.append(_unit(tok.float().cpu().numpy(), axis=2))
    finally:
        if handle is not None:
            handle.remove()
    return {
        "image": np.concatenate(images).astype(np.float32),
        "patches": np.concatenate(patch_out).astype(np.float32) if patches else None,
    }


def embed_texts(vm, texts):
    texts = list(texts)
    with torch.no_grad():
        t = vm.model.encode_text(vm.tokenizer(texts))
    return _unit(t.float().cpu().numpy()).astype(np.float32)


def patch_box(vm, path, patch_index):
    """Pixel box (x0, y0, x1, y1) in the original image for a 0-based patch index.

    Mirrors open_clip's eval transform: resize the shorter side to image_size,
    then center-crop a square.
    """
    size = vm.spec["image_size"]
    grid = vm.spec["patch_grid"]
    cell = size / grid
    w, h = Image.open(path).size
    scale = size / min(w, h)
    rw, rh = w * scale, h * scale
    offx, offy = (rw - size) / 2, (rh - size) / 2
    row, col = divmod(int(patch_index), grid)
    x0 = (col * cell + offx) / scale
    y0 = (row * cell + offy) / scale
    x1 = ((col + 1) * cell + offx) / scale
    y1 = ((row + 1) * cell + offy) / scale
    r = lambda v: int(round(v))
    return (r(x0), r(y0), r(x1), r(y1))


def crop_png(path, box, pad=48, size=96):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    x0, y0, x1, y1 = box
    crop = img.crop((max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)))
    crop = crop.resize((size, size), Image.BICUBIC)
    buf = io.BytesIO()
    crop.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def exemplar_pngs(vm, paths, patch_indices, pad=48, size=96):
    return [crop_png(p, patch_box(vm, p, int(i)), pad=pad, size=size) for p, i in zip(paths, patch_indices)]
```

If `open_clip.load_openai_model(weights)` refuses a path in the installed version, replace that branch with `model, _, preprocess = open_clip.create_model_and_transforms("ViT-B-32-quickgelu", pretrained=weights)` and set `spec["arch"]` from `name`; the pytest `test_spec` and Task 10's V1 decide whether the embeddings are right.

- [ ] **Step 4: Run the pytest**

Run: `cd /home/claude/moose && MOOSE_CLIP_WEIGHTS=/home/claude/weights/ViT-B-32.pt python3 -m pytest tests/python -q`
Expected: 6 passed. The patch-box arithmetic in the test assumes `Resize(224)` on the shorter side followed by `CenterCrop(224)`; check `vm.preprocess` prints those two transforms and adjust the test's expected numbers only if the transform differs.

- [ ] **Step 5: Sync; commit if approved** — `git commit -m "Add Python vision layer (open_clip embeddings and patch crops)"`.

---

### Task 8: R wrappers over Python (`R/vision-python.R`)

**Files:**
- Create: `R/vision-python.R`
- Test: `tests/testthat/test-vision-python.R`
- Modify: `README.md` (install section)

**Interfaces:**
- Consumes: `moose_vision.py`, `featureScores()`, `imageSet()`, `imageMeta()`.
- Produces:
  - `visionModel(weights = NULL, name = "ViT-B-32", pretrained = "openai", python = NULL)` → list of class `mooseVisionModel`: `py` (reticulate object), `spec` (list).
  - `embedImages(model, paths, region = NULL, patches = TRUE)` → list `image` (n×d, rownames = image ids), `patches` (n×p×d with dimnames[[1]] = ids, or NULL).
  - `embedTexts(model, texts)` → m×d with rownames = texts.
  - `patchExemplars(model, key, images, pad = 48, size = 96)` → the key, with `png` columns filled in `features$exemplars` and `image_<term>_<k>` rows added to `meta` plus `Image` set on each "Has" lead.
  - `scoreImages(key, model, paths)` → `featureScores()` matrix for new images (per-region embeddings for text features).
  - `modelMeta(model)` → data.frame of `model_*` rows for `meta`.

- [ ] **Step 1: Write the failing tests**

`tests/testthat/test-vision-python.R`:

```r
skipUnlessVision <- function() {
  skip_if_not_installed("reticulate")
  w <- Sys.getenv("MOOSE_CLIP_WEIGHTS")
  skip_if(!nzchar(w) || !file.exists(w), "MOOSE_CLIP_WEIGHTS not set")
  skip_if_not(reticulate::py_module_available("open_clip"), "open_clip not installed")
}

testPics <- function(n = 4) {
  dir <- tempfile(); dir.create(dir)
  paths <- character(n)
  for (i in seq_len(n)) {
    a <- array(0.9, c(64, 64, 3))
    a[(i * 6):(i * 6 + 20), 10:50, ] <- c(1, 0, 0)[(i %% 3) + 1]
    paths[i] <- file.path(dir, sprintf("L%d.png", i))
    png::writePNG(a, paths[i])
  }
  paths
}

test_that("visionModel loads and reports its spec", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  expect_s3_class(m, "mooseVisionModel")
  expect_equal(m$spec$dim, 512L)
  expect_equal(modelMeta(m)$key[1], "model_library")
})

test_that("embedImages and embedTexts return named matrices", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  p <- testPics()
  e <- embedImages(m, p)
  expect_equal(dim(e$image), c(4, 512))
  expect_equal(rownames(e$image), c("L1", "L2", "L3", "L4"))
  expect_equal(dim(e$patches), c(4, 49, 512))
  expect_equal(dimnames(e$patches)[[1]], rownames(e$image))
  t <- embedTexts(m, c("a red bar", "a blue bar"))
  expect_equal(rownames(t), c("a red bar", "a blue bar"))
  expect_null(embedImages(m, p, patches = FALSE)$patches)
})

test_that("images to key to classify, with exemplar crops and scores for new images", {
  skipUnlessVision()
  m <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))
  p <- testPics()
  images <- imageSet(p)
  e <- embedImages(m, p)
  terms <- discoverTerms(e$patches, k = 3, seed = 1)
  key <- keyFromTerms(termScores(e$patches, terms$centroids), images, terms, quantile = 0.5)
  key <- patchExemplars(m, key, images)
  expect_true(all(nzchar(key$features$exemplars[[1]]$png)))
  expect_true(any(grepl("^image_", key$meta$key)))
  expect_true(any(nzchar(key$leads$Image)))
  s <- scoreImages(key, m, p)
  expect_equal(colnames(s), key$features$id)
  expect_equal(nrow(classify(key, s)), 4)
  html <- exportWizard(key)
  expect_match(html, "data:image/png;base64,", fixed = TRUE)

  vocab <- data.frame(feature = c("a red bar", "a blue bar"), opposite = c("no red bar", "no blue bar"),
                      region = c(NA, "0,0.5,0,1"), stringsAsFactors = FALSE)
  txt <- embedTexts(m, vocabularyPrompts(vocab, "an image with {x}"))
  qkey <- keyFromClusters(e$image, images, vocab, txt, template = "an image with {x}")
  s2 <- scoreImages(qkey, m, p)
  expect_equal(colnames(s2), qkey$features$id)
  expect_length(qkey$validate(), 0)
})
```

- [ ] **Step 2: Run to verify failure**

Run: `MOOSE_CLIP_WEIGHTS=/home/claude/weights/ViT-B-32.pt Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-vision-python.R")'`
Expected: FAIL, `could not find function "visionModel"`.

- [ ] **Step 3: Implement `R/vision-python.R`**

```r
pyVision <- local({
  mod <- NULL
  function() {
    if (!requireNamespace("reticulate", quietly = TRUE)) {
      stop("Install the reticulate package (and Python with torch and open_clip_torch) to embed images", call. = FALSE)
    }
    if (is.null(mod)) {
      mod <<- reticulate::import_from_path("moose_vision", path = system.file("python", package = "moose"), convert = TRUE)
    }
    mod
  }
})

#' Load a vision model for embedding images
#'
#' Uses Python's open_clip through reticulate. Install the Python side with
#' `pip install -r $(Rscript -e 'cat(system.file("python/requirements.txt", package="moose"))')`.
#'
#' @param weights Local checkpoint file (e.g. OpenAI's `ViT-B-32.pt`); if
#'   `NULL`, open_clip downloads `pretrained` weights for `name`.
#' @param name,pretrained open_clip model name and pretrained tag.
#' @param python Optional path to the Python executable to use (passed to
#'   [reticulate::use_python()]).
#' @return An object of class `mooseVisionModel` with `py` (the Python model)
#'   and `spec` (library, architecture, weights SHA-256, image size, ...).
#' @export
visionModel <- function(weights = NULL, name = "ViT-B-32", pretrained = "openai", python = NULL) {
  if (!is.null(python)) reticulate::use_python(python, required = TRUE)
  py <- pyVision()$load_model(name = name, pretrained = pretrained, weights = weights)
  structure(list(py = py, spec = py$spec), class = "mooseVisionModel")
}

#' @export
print.mooseVisionModel <- function(x, ...) {
  cat("<moose vision model> ", x$spec$arch, " (", x$spec$library, "), ", x$spec$dim, " dimensions\n", sep = "")
  invisible(x)
}

#' Model details as metadata rows
#' @param model A [visionModel()].
#' @return A key/value data frame with `model_*` keys.
#' @export
modelMeta <- function(model) {
  s <- model$spec
  s <- s[!vapply(s, is.null, logical(1))]
  data.frame(key = paste0("model_", names(s)), value = as.character(unlist(s)), stringsAsFactors = FALSE)
}

#' Embed images
#'
#' @param model A [visionModel()].
#' @param paths Image files.
#' @param region Optional crop `c(y0, y1, x0, x1)` as fractions, applied to
#'   every image before embedding.
#' @param patches If `TRUE`, also return per-patch embeddings.
#' @return A list: `image` (`images x d` matrix, rows named by file name
#'   without extension) and `patches` (`images x patches x d` array, or
#'   `NULL`).
#' @export
embedImages <- function(model, paths, region = NULL, patches = TRUE) {
  ids <- sub("\\.[^.]+$", "", basename(paths))
  out <- model$py$embed_images(as.list(as.character(paths)), region = region, patches = patches)
  image <- out$image; rownames(image) <- ids
  pt <- out$patches
  if (!is.null(pt)) dimnames(pt) <- list(ids, NULL, NULL)
  list(image = image, patches = pt)
}

#' Embed texts
#' @inheritParams embedImages
#' @param texts Character vector.
#' @return A `texts x d` matrix with the texts as row names.
#' @export
embedTexts <- function(model, texts) {
  m <- model$py$embed_texts(as.list(as.character(texts)))
  rownames(m) <- texts
  m
}

#' Add example crops to a term key
#'
#' Cuts out the best-matching patch (with some context) for each term's
#' exemplars, stores them as PNGs in the key's `features` and `meta`, and
#' points each "Has term" lead at them so [exportWizard()] shows them.
#'
#' @inheritParams embedImages
#' @param key A key from [keyFromTerms()].
#' @param images The [imageSet()] the key was built from (for file paths).
#' @param pad,size Context around the patch and the crop's output size, px.
#' @return The key, modified in place and returned invisibly.
#' @export
patchExemplars <- function(model, key, images, pad = 48, size = 96) {
  f <- key$features
  meta <- key$meta
  leads <- key$leads
  if (is.null(leads$Image)) leads$Image <- ""
  for (j in seq_len(nrow(f))) {
    ex <- f$exemplars[[j]]
    if (is.null(ex) || nrow(ex) == 0) next
    paths <- images$path[match(ex$image, images$id)]
    ex$png <- unlist(model$py$exemplar_pngs(as.list(paths), as.list(as.integer(ex$patch - 1L)), pad = pad, size = size))
    f$exemplars[[j]] <- ex
    name <- f$label[j]
    ids <- paste0(gsub("[^A-Za-z0-9_-]", "_", name), "_", seq_len(nrow(ex)))
    meta <- rbind(meta, data.frame(key = paste0("image_", ids), value = paste0("data:image/png;base64,", ex$png), stringsAsFactors = FALSE))
    on <- which(leads$Feature == f$id[j] & leads$Test == ">")
    leads$Image[on] <- paste(ids, collapse = ";")
  }
  key$features <- f
  key$meta <- rbind(meta, modelMeta(model)[!modelMeta(model)$key %in% meta$key, ])
  key$leads <- leads
  invisible(key)
}

#' Score new images against a key's features
#'
#' Embeds the images (once per distinct crop region the key's text features
#' use) and applies [featureScores()].
#'
#' @param key A key with a `features` table.
#' @inheritParams embedImages
#' @return An `images x features` matrix for [classify()].
#' @export
scoreImages <- function(key, model, paths) {
  f <- key$features
  if (is.null(f)) stop("This key has no features table", call. = FALSE)
  ids <- sub("\\.[^.]+$", "", basename(paths))
  out <- matrix(NA_real_, length(paths), nrow(f), dimnames = list(ids, f$id))
  needPatches <- any(f$kind == "centroid_patch_max")
  whole <- embedImages(model, paths, patches = needPatches)
  if (needPatches) {
    j <- f$kind == "centroid_patch_max"
    sub <- key$clone(); sub$features <- f[j, ]
    out[, j] <- featureScores(sub, patches = whole$patches)
  }
  text <- which(f$kind == "clip_text_pair")
  if (length(text)) {
    textEmb <- embedTexts(model, unique(c(f$prompt[text], f$negative_prompt[text])))
    regions <- f$region[text]; regions[is.na(regions)] <- ""
    for (r in unique(regions)) {
      jj <- text[regions == r]
      emb <- if (nzchar(r)) embedImages(model, paths, region = as.numeric(strsplit(r, ",")[[1]]), patches = FALSE)$image else whole$image
      sub <- key$clone(); sub$features <- f[jj, ]
      out[, jj] <- featureScores(sub, image = emb, textEmb = textEmb)
    }
  }
  out
}
```

Add `#' @importFrom base64enc base64encode` is already present; no new imports (reticulate is called with `::`). Add to `R/moose-package.R` nothing. `DESCRIPTION` Suggests already has reticulate (Task 1); add `png`, `jpeg` (Task 2).

- [ ] **Step 4: Run the tests**

Run: `MOOSE_CLIP_WEIGHTS=/home/claude/weights/ViT-B-32.pt Rscript -e 'roxygen2::roxygenise(); pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-vision-python.R")'`
Expected: PASS. Then without the variable: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-vision-python.R")'` → all SKIP.

- [ ] **Step 5: README**

Add to `README.md` after the quick start:

```markdown
## Keys from images

moose can build a key from a folder of labelled images, the way
[fordera](https://github.com/leipzig/fordera) does for Ford trucks, with any
model that gives embeddings. The default is CLIP ViT-B/32 through Python's
open_clip:

```sh
pip install -r "$(Rscript -e 'cat(system.file("python/requirements.txt", package="moose"))')"
```

```r
library(moose)
model  <- visionModel("ViT-B-32.pt")            # or visionModel() to download
images <- imageSet(list.files("pics", full.names = TRUE), label = function(x) sub("_.*$", "", x))
emb    <- embedImages(model, images$path)

# 1. Invented terms: k-means on patch embeddings
terms  <- discoverTerms(emb$patches, k = 40)
key    <- keyFromTerms(termScores(emb$patches, terms$centroids), images, terms)
key    <- patchExemplars(model, key, images)     # example crops for the wizard
exportWizard(key, "terms.html")

# 2. Questions from a vocabulary
vocab  <- data.frame(feature = c("round headlights", "a flat hood"),
                     opposite = c("square headlights", "a curved hood"))
txt    <- embedTexts(model, vocabularyPrompts(vocab, "a pickup truck with {x}"))
qkey   <- keyFromClusters(emb$image, images, vocab, txt, template = "a pickup truck with {x}")

# Follow a key by machine
classify(key, scoreImages(key, model, "new.png"))
```

The R side works on plain matrices, so embeddings from any other model can be
passed to `discoverTerms()`, `keyFromTerms()`, `keyFromClusters()` and
`featureScores()` directly.
```

- [ ] **Step 6: Sync; commit if approved** — `git commit -m "Add R wrappers for the Python vision layer"`.

---

### Task 9: Wizard — one-copy images, MIME types, thumbnails, Question headings, glossary

**Files:**
- Modify: `R/export.R` (`embeddedImages`, `figuresHtml`, the couplet heading, the page assembly, `exportWizard` to pass features)
- Modify: `inst/wizard/wizard.css`, `inst/wizard/wizard.js`
- Test: `tests/testthat/test-export-wizard.R` (append), `tests/testthat/test-example-keys.R` (append)

**Interfaces:**
- Consumes: `key$features`, `imageMeta()` data URIs, `Question` lead column.
- Produces: HTML where each embedded image is a CSS custom property `--img-<safe id>` declared once in `<style>`, figures are `<span class="fig" role="img" style="background-image:var(--img-...)">`, couplet `<h2>` shows the Question when present, and a `<section class="glossary" id="glossary">` lists term features with their crops.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-export-wizard.R`:

```r
glossaryKey <- function() {
  v <- syntheticVision(k = 3)
  t <- discoverTerms(v$patches, k = 3)
  key <- keyFromTerms(termScores(v$patches, t$centroids), v$images, t, quantile = 0.5)
  png <- tempfile(fileext = ".png"); png::writePNG(array(runif(8 * 8 * 3), c(8, 8, 3)), png)
  b64 <- base64enc::base64encode(png)
  f <- key$features
  for (j in seq_len(nrow(f))) f$exemplars[[j]]$png <- rep(b64, nrow(f$exemplars[[j]]))
  key$features <- f
  key$meta <- rbind(key$meta, imageMeta(c(png, png), ids = c("1948-1950", "H2a+152")))
  l <- key$leads; l$Image[1] <- "1948-1950;H2a+152"; key$leads <- l
  key
}

test_that("each embedded image appears once and with its own MIME type", {
  key <- glossaryKey()
  html <- exportWizard(key)
  uri <- key$meta$value[key$meta$key == "image_1948-1950"]
  expect_equal(lengths(regmatches(html, gregexpr(uri, html, fixed = TRUE))), 1)
  expect_match(html, "--img-1948-1950:url(\"data:image/png;base64,", fixed = TRUE)
  expect_match(html, "style=\"background-image:var(--img-1948-1950)\"", fixed = TRUE)
})

test_that("image names are sanitized for CSS", {
  html <- exportWizard(glossaryKey())
  expect_match(html, "--img-H2a_152:", fixed = TRUE)
  expect_false(grepl("--img-H2a+152", html, fixed = TRUE))
})

test_that("legacy base64 images without a data: prefix still render as gif", {
  k <- sharkKey()
  k$meta <- rbind(k$meta, data.frame(key = "image_tn_x", value = base64enc::base64encode(charToRaw("GIF89a")), stringsAsFactors = FALSE))
  l <- k$leads; l$Image[1] <- "https://example.org/tn_x.gif"; k$leads <- l
  expect_match(exportWizard(k), "--img-tn_x:url(\"data:image/gif;base64,", fixed = TRUE)
})

test_that("Question is the step heading and the glossary lists terms with crops", {
  key <- glossaryKey()
  html <- exportWizard(key)
  q <- key$leads$Question[1]
  expect_match(html, sprintf("<h2 id=\"h-c-1\" tabindex=\"-1\">%s <span class=\"num\">Term 1</span>", q), fixed = TRUE)
  expect_match(html, "<section class=\"glossary\" id=\"glossary\"", fixed = TRUE)
  expect_match(html, sprintf("id=\"g-%s\"", key$features$label[1]), fixed = TRUE)
  expect_match(html, sprintf("href=\"#g-%s\"", key$features$label[1]), fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr("class=\"fig\"", html))) >= 3 * 4 + 2, TRUE)
})

test_that("keys without features have no glossary", {
  expect_false(grepl("class=\"glossary\"", exportWizard(arachnidaKey()), fixed = TRUE))
})
```

Append to `tests/testthat/test-example-keys.R` a fifth key in the `keys` list:

```r
  terms = function() { v <- syntheticVision(k = 3); t <- discoverTerms(v$patches, k = 3); keyFromTerms(termScores(v$patches, t$centroids), v$images, t, quantile = 0.5) }
```

(The `expect_equal(tree$leafCount, ...)` and newick checks must still pass on it.)

- [ ] **Step 2: Run to verify failure**

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-export-wizard.R")'`
Expected: the new tests FAIL (no `--img-`, no glossary).

- [ ] **Step 3: Implement in `R/export.R`**

Replace `embeddedImages()` and `figuresHtml()`:

```r
# Named vector: image id -> data URI, from meta rows image_<id>. Values that
# are bare base64 (importFishbase(embedImages = TRUE) wrote those) are GIFs.
embeddedImages <- function(meta) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(character())
  rows <- grepl("^image_", meta$key) & !grepl("^image_url_", meta$key)
  v <- as.character(meta$value[rows])
  v <- ifelse(startsWith(v, "data:"), v, paste0("data:image/gif;base64,", v))
  stats::setNames(v, sub("^image_", "", meta$key[rows]))
}

cssName <- function(id) paste0("--img-", gsub("[^A-Za-z0-9_-]", "_", id))

# One <span class="fig"> per embedded image, or an <img> for a URL
figuresHtml <- function(thumbs, fulls, images, alt) {
  if (length(thumbs) == 0) return("")
  items <- vapply(thumbs, function(t) {
    name <- sub("\\.(gif|jpe?g|png|webp)$", "", basename(t), ignore.case = TRUE)
    full <- fulls[basename(fulls) == sub("^tn_", "", basename(t))][1]
    img <- if (!is.na(images[name])) {
      sprintf("<span class=\"fig\" role=\"img\" aria-label=\"%s\" style=\"background-image:var(%s)\"></span>",
        htmlEscape(alt), cssName(name))
    } else {
      sprintf("<img class=\"fig\" src=\"%s\" alt=\"%s\" loading=\"lazy\">", htmlEscape(t), htmlEscape(alt))
    }
    if (is.na(full)) img else {
      sprintf("<a href=\"%s\" target=\"_blank\" rel=\"noopener\" title=\"Open full-size figure\">%s</a>", htmlEscape(full), img)
    }
  }, character(1))
  paste0("<figure class=\"figs\">", paste(items, collapse = ""), "</figure>")
}

# <style> block declaring every embedded image once as a CSS custom property
imageStyle <- function(images) {
  if (length(images) == 0) return("")
  paste0("<style>:root{", paste0(cssName(names(images)), ":url(\"", images, "\")", collapse = ";"), "}</style>\n")
}

# Glossary of the key's term features: name, example crops, where found
glossaryHtml <- function(features, leads, coupletId) {
  if (is.null(features)) return("")
  terms <- which(features$kind == "centroid_patch_max")
  if (length(terms) == 0) return("")
  entries <- vapply(terms, function(j) {
    ex <- features$exemplars[[j]]
    crops <- if (!is.null(ex) && !is.null(ex$png)) paste0(sprintf(
      "<span class=\"fig\" role=\"img\" aria-label=\"%s in %s\" style=\"background-image:url(&quot;data:image/png;base64,%s&quot;)\"></span>",
      htmlEscape(features$label[j]), htmlEscape(ex$image), ex$png), collapse = "") else ""
    where <- if (!is.null(ex)) sprintf("<p class=\"found\">Seen in %s</p>", htmlEscape(paste(unique(ex$image), collapse = ", "))) else ""
    asked <- unique(leads$Statement[leads$Feature == features$id[j]])
    links <- paste(sprintf("<a href=\"#%s\">%s</a>", coupletId(asked), htmlEscape(asked)), collapse = ", ")
    sprintf("<div class=\"term\" id=\"g-%s\"><h3>%s</h3><div class=\"figs\">%s</div>%s<p class=\"found\">Asked at %s</p></div>",
      htmlEscape(features$label[j]), htmlEscape(features$label[j]), crops, where, links)
  }, character(1))
  sprintf("<section class=\"glossary\" id=\"glossary\" aria-labelledby=\"h-glossary\">\n<h2 id=\"h-glossary\" tabindex=\"-1\">Glossary of terms</h2>\n<p>Each term is defined only by the image patches that match it best. \"Has <i>term</i>\" means the specimen has a region that looks like these.</p>\n%s\n</section>",
    paste(entries, collapse = "\n"))
}
```

In `renderWizard()` (add a `features = NULL` argument; `exportWizard()` passes `features = moose$features`):

- Couplet heading: replace the `<h2>` sprintf so that when `leads$Question[idx[1]]` is non-empty the heading is `"%s <span class=\"num\">%s %s</span>"` (question, nodeLabel, cp), else the existing `"%s <span class=\"num\">%s</span>"`.
- Lead text for term leads: after `text` is set, if `nzchar(leads$Feature[i]) && !is.null(features)` and the feature's kind is `centroid_patch_max`, append `sprintf(" <a class=\"gloss\" href=\"#g-%s\" title=\"What does this term look like?\">?</a>", htmlEscape(features$label[match(leads$Feature[i], features$id)]))` to the `.text` span (outside `htmlEscape(text)`).
- Page assembly: insert `imageStyle(images)` right after the existing `<style>...</style>` block in `<head>`, and `glossaryHtml(features, leads, coupletId)` after the taxon sections inside `<main>`.

- [ ] **Step 4: CSS and JS**

`inst/wizard/wizard.css`: replace the three `.figs` rules with

```css
.figs { margin: 0; padding: .6rem; display: flex; flex-wrap: wrap; gap: .4rem; }
.figs a { display: block; }
.fig { display: block; width: 6rem; height: 6rem; border: 1px solid var(--rule); border-radius: 8px; background: #fff center / contain no-repeat; cursor: zoom-in; }
.fig.big { width: 100%; height: 18rem; cursor: zoom-out; }
img.fig { object-fit: contain; }
.gloss { display: inline-block; min-width: 1.4em; margin-left: .3em; text-align: center; border: 1px solid var(--rule); border-radius: 999px; font-size: .8em; text-decoration: none; }
.glossary .term { padding: .75rem 0; border-top: 1px solid var(--rule); }
.glossary .term h3 { margin: 0 0 .25rem; font-family: monospace; }
.glossary .found { margin: .25rem 0 0; color: var(--muted); font-size: .875rem; }
.wizard .glossary { display: none; }
.wizard .glossary.active { display: block; }
```

and in the phone media query replace the two `.figs` lines with `.figs { padding: 0 .9rem .9rem 3.55rem; }` and `.fig { width: 5rem; height: 5rem; }`.

`inst/wizard/wizard.js`:

- `sections` selector: `"main .couplet, main .taxon, main .glossary"`.
- `currentId()`:

```js
  function currentId() {
    var id = decodeURIComponent(location.hash.slice(1));
    if (byId[id]) return id;
    var el = id && doc.getElementById(id);
    if (el && el.closest && el.closest(".glossary")) return "glossary";
    return root;
  }
```

- In `update()`: change `if (last && !step) trail = [];` to `if (last && !step && id !== "glossary") trail = [];`, and after `renderTrail();` add `if (id !== "glossary") renderMap(id);` in place of the bare `renderMap(id);`. After focusing the heading, add:

```js
    if (id === "glossary") {
      var target = doc.getElementById(decodeURIComponent(location.hash.slice(1)));
      if (target && target !== byId[id]) target.scrollIntoView();
    }
```

- Thumbnail toggle, before `update(false)` at the end:

```js
  doc.addEventListener("click", function (ev) {
    var fig = ev.target.closest && ev.target.closest(".fig");
    if (fig && !fig.closest("a")) fig.classList.toggle("big");
  });
```

- [ ] **Step 5: Run the wizard and example-key tests, then look at a page**

Run: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-export-wizard.R"); testthat::test_file("tests/testthat/test-example-keys.R")'`
Expected: PASS.

Then render the synthetic glossary key to `scratchpad/glossary.html`, open it with the Playwright script pattern from earlier (`chromium.launch()`, 400×860 viewport, screenshot) and check: thumbnails in a row, the "?" link opens the glossary, Back returns to the couplet, tapping a thumbnail enlarges it, and no console errors.

- [ ] **Step 6: Sync; commit if approved** — `git commit -m "Wizard: embed images once, thumbnails, question headings and a term glossary"`.

---

### Task 10: Verification against fordera (V1–V4) and the report

**Files:**
- Create: `analysis/fordera/verify.R`, `analysis/fordera/REPORT.md`
- Modify: `analysis/README.md` (one line pointing at the folder)

**Interfaces:**
- Consumes: everything above; fordera files under `$FORDERA` (`outputs/trait_centroids.npy`, `trait_summary.json`, `trait_tree.json`, `data/processed/manifest.json`, `data/processed/*.png`, `src/fordera/describer.py`), weights at `$MOOSE_CLIP_WEIGHTS`.
- Produces: printed V1–V4 results and `REPORT.md`.

- [ ] **Step 1: Stage fordera's inputs into the sandbox**

`device_stage_files` of the six `*_alt.png` images and `outputs/trait_centroids.npy` from `/Users/leipzig/Documents/fordera` (the other files were staged earlier under `/mnt/user-data/uploads/fordera`). Set `FORDERA=/mnt/user-data/uploads/fordera`. Read the `.npy` with Python (`numpy.load`, then write a CSV) or with `reticulate::import("numpy")$load`; the script uses reticulate.

- [ ] **Step 2: Write `analysis/fordera/verify.R`**

```r
# Checks moose's vision keys against fordera's outputs (V1-V4 in the spec).
# Needs: FORDERA (fordera checkout), MOOSE_CLIP_WEIGHTS, Python with torch+open_clip.
suppressMessages(pkgload::load_all(file.path(dirname(dirname(getwd())), "."), quiet = TRUE))
library(jsonlite)
fordera <- Sys.getenv("FORDERA", "~/Documents/fordera")
np <- reticulate::import("numpy")
model <- visionModel(Sys.getenv("MOOSE_CLIP_WEIGHTS"))

man <- fromJSON(file.path(fordera, "data/processed/manifest.json"), simplifyVector = FALSE)
paths <- file.path(fordera, "data/processed", basename(vapply(man, `[[`, "", "processed_path")))
images <- imageSet(paths, label = function(x) sub("_.*$", "", x))
gens <- c("1948-1950" = 1, "1951" = 1, "1952" = 1, "1953" = 2, "1954" = 2, "1955" = 2, "1956" = 2,
          "1957" = 3, "1958" = 3, "1959" = 3, "1960" = 3, "1961" = 4, "1962" = 4, "1963" = 4, "1964" = 4,
          "1965" = 4, "1966" = 4, "1967" = 5, "1968" = 5, "1969" = 5, "1970" = 5, "1971" = 5, "1972" = 5,
          "1973-1975" = 6, "1976-1977" = 6, "1978" = 6, "1979" = 6)
emb <- embedImages(model, paths)

# ---- V1: patch scores against fordera's centroids ----------------------------
cent <- np$load(file.path(fordera, "outputs/trait_centroids.npy"))
ts <- fromJSON(file.path(fordera, "outputs/trait_summary.json"), simplifyVector = FALSE)
rownames(cent) <- unlist(ts$names)
ours <- termScores(emb$patches, cent)
theirs <- t(vapply(man, function(e) unlist(ts$per_image_presence[[e$processed_path]]), numeric(nrow(cent))))
v1 <- max(abs(ours - theirs))
cat(sprintf("V1 max |moose - fordera| patch score: %.2e  (%s)\n", v1, if (v1 < 1e-3) "PASS" else "FAIL"))

# ---- V2: balanced tree from fordera's scores equals trait_tree.json ----------
fterms <- structure(list(terms = data.frame(id = seq_len(nrow(cent)), name = rownames(cent)), centroids = cent, exemplars = NULL), class = "mooseTerms")
k2 <- keyFromTerms(theirs, images, fterms, quantile = 0.6)
tt <- fromJSON(file.path(fordera, "outputs/trait_tree.json"), simplifyVector = FALSE)
rows <- list(); counter <- 0
conv <- function(n) {
  counter <<- counter + 1; id <- as.character(counter)
  kids <- list(n$yes, n$no)
  nx <- vapply(kids, function(k) if (k$type == "leaf") "-" else conv(k), "")
  rows[[id]] <<- data.frame(Statement = id, Choice = c("a", "b"), Next = nx,
    Taxon = vapply(kids, function(k) if (k$type == "leaf") k$label else "", ""), Feature = paste0("term:", n$trait_name))
  id
}
conv(tt)
ref <- do.call(rbind, rows[order(as.integer(names(rows)))]); rownames(ref) <- NULL
same <- identical(ref, k2$leads[, names(ref)])
e2 <- evaluateKey(k2, theirs, images$label, gens)
cat(sprintf("V2 tree identical: %s; year %d/33, generation %d/33 (%s)\n", same, sum(e2$results$correct), sum(e2$results$groupCorrect),
  if (same && sum(e2$results$correct) == 26 && sum(e2$results$groupCorrect) == 28) "PASS" else "FAIL"))

# ---- V3: from scratch ---------------------------------------------------------
terms <- discoverTerms(emb$patches, k = 40, seed = 1)
scores <- termScores(emb$patches, terms$centroids)
k3 <- keyFromTerms(scores, images, terms)
e3 <- evaluateKey(k3, scores, images$label, gens)
loo <- looKey(images, build = function(tr) keyFromTerms(scores[tr, ], images[tr, ], terms), score = function(key, i) scores[i, , drop = FALSE], groups = gens)
looRefit <- looKey(images,
  build = function(tr) { t <- discoverTerms(emb$patches[tr, , , drop = FALSE], k = 40, seed = 1); keyFromTerms(termScores(emb$patches[tr, , , drop = FALSE], t$centroids), images[tr, ], t) },
  score = function(key, i) featureScores(key, patches = emb$patches[i, , , drop = FALSE]), groups = gens)
cat(sprintf("V3 from scratch: train year %.1f%% gen %.1f%%; LOO (shared terms) year %.1f%% gen %.1f%%; LOO (refit terms) year %.1f%% gen %.1f%%\n",
  100 * e3$accuracy, 100 * e3$groupAccuracy, 100 * loo$accuracy, 100 * loo$groupAccuracy, 100 * looRefit$accuracy, 100 * looRefit$groupAccuracy))

# ---- V4: question key ---------------------------------------------------------
src <- readLines(file.path(fordera, "src/fordera/describer.py"))
m <- regmatches(src, regexec('^\\s*\\("([^"]+)", "([^"]+)"\\),', src))
vocab <- do.call(rbind, lapply(Filter(length, m), function(x) data.frame(feature = x[2], opposite = x[3])))
tmpl <- "a pickup truck with {x}"
txt <- embedTexts(model, vocabularyPrompts(vocab, tmpl))
yearOrder <- function(l) min(as.integer(sub("-.*$", "", l)))
k4 <- keyFromClusters(emb$image, images, vocab, txt, template = tmpl, order = yearOrder)
s4 <- scoreImages(k4, model, paths)
e4 <- evaluateKey(k4, s4, images$label, gens)
k4m <- keyFromClusters(emb$image, images, vocab, txt, template = tmpl, order = yearOrder, calibrate = "midpoint")
e4m <- evaluateKey(k4m, scoreImages(k4m, model, paths), images$label, gens)
cat(sprintf("V4 question key self-walk: year %.1f%% gen %.1f%% (threshold 0); year %.1f%% gen %.1f%% (midpoint); fordera 27%% gen\n",
  100 * e4$accuracy, 100 * e4$groupAccuracy, 100 * e4m$accuracy, 100 * e4m$groupAccuracy))
print(head(k4$leads[, c("Statement", "Question", "Character", "Next", "Taxon")], 8))

k3 <- patchExemplars(model, k3, images)
exportWizard(k3, "fordera-terms.html")
exportWizard(k4, "fordera-questions.html")
```

- [ ] **Step 3: Run it**

Run: `cd /home/claude/moose/analysis/fordera && FORDERA=/mnt/user-data/uploads/fordera MOOSE_CLIP_WEIGHTS=/home/claude/weights/ViT-B-32.pt Rscript verify.R`
Expected: `V1 ... PASS`, `V2 ... PASS`, V3 and V4 lines with numbers. If V1 fails, the patch tokens differ from fordera's: compare the hook output against the `clip` package's forward (fordera's `extract_patch_embeddings`), in particular the `batch_first` permute and whether `ln_post` is applied to all tokens, before changing anything else. If V2's tree differs only in tie-breaking, print both lead tables side by side and fix the comparison (`>` vs `>=`) in `keyFromTerms` to match fordera's `balance > best_split_score`.

- [ ] **Step 4: Write `analysis/fordera/REPORT.md`**

Record the four results with the exact numbers printed, the model spec (`modelMeta(model)`), the date, and a short reading: whether the two fixes changed V4, and training vs leave-one-out for V3. Add one line to `analysis/README.md`: `- fordera/: checks of the vision keys against fordera's outputs (needs a fordera checkout and CLIP weights; see REPORT.md).`

- [ ] **Step 5: Full package check**

Run: `cd /home/claude && R CMD build moose && R CMD check --as-cran --no-manual moose_*.tar.gz 2>&1 | tail -25`
Expected: `Status: OK` (or only the pre-existing NOTE about the GPL license version, if R flags it). Fix any new NOTE about undocumented arguments, non-ASCII text or undeclared imports before finishing. Also run the whole test suite: `Rscript -e 'pkgload::load_all(quiet=TRUE); testthat::test_dir("tests/testthat")'`.

- [ ] **Step 6: Sync everything to the Mac; commit if approved** — `git commit -m "Verify vision keys against fordera; report"`. Copy the two rendered wizards into the scratchpad and send them to the user (they contain fordera's images, so do not publish them as artifacts).

---

## Self-review notes

- Spec coverage: data model (T1), image sets and MIME (T2), terms and term key with both methods (T3), classify/evaluate/LOO with `refitTerms` as the two `looKey` call shapes (T4, T10), featureScores (T5), question key with fixes 1 and 2, order, midpoint (T6), Python layer incl. regions, patch boxes and crops (T7), R wrappers incl. per-region scoring and `modelMeta` (T8), all five wizard changes (T9), V1–V4 and report, housekeeping and README (T1, T8, T10). The spec's `inventNames` "no duplicates" and determinism are tested in T3.
- Names used consistently: `featureTable`, `checkFeatures`, `featureScores`, `classify`, `evaluateKey`, `looKey`, `imageSet`, `imageMime`, `imageMeta`, `inventNames`, `discoverTerms`, `termScores`, `keyFromTerms`, `vocabularyPrompts`, `keyFromClusters`, `visionModel`, `modelMeta`, `embedImages`, `embedTexts`, `patchExemplars`, `scoreImages`; Python `load_model`, `embed_images`, `embed_texts`, `patch_box`, `crop_png`, `exemplar_pngs`.
- Review Focus tests: #1 T3 "label presence is any over its images"; #2 T4 "unresolvable couplet gives NA"; #3 T6 "yes lead points at the side that has the feature"; #4 T7 `test_patch_box_on_a_400x300_image`; #5 T9 "image names are sanitized for CSS".
