# Vision keys: building identification keys from images inside moose

Status: draft for review, 2026-09-30. This supersedes the import-only
approach in the project note `cv-key-import-design.md`: instead of reading
fordera's JSON, moose does fordera's whole pipeline itself.

## Goal

Given a folder of labelled images, moose builds a dichotomous key that a
person can follow in the wizard and a machine can follow with `classify()`.

The model it uses is interchangeable. The default is CLIP ViT-B/32 through
open_clip, but anything that yields embeddings will do.

There are two kinds of key, both taken from fordera:

- **Term key.** CLIP patch embeddings are clustered with k-means into visual
  "terms". Each term gets an invented name, and the key asks whether an image
  contains that term.
- **Question key.** Classes are clustered hierarchically on their image
  embeddings. Each split is then described by the pair of plain-language
  features from a vocabulary that best separates its two sides.

## Success criteria

- **V1: embeddings match fordera's.** moose's Python layer reproduces
  fordera's patch scores. Scoring the 33 images against fordera's own
  `trait_centroids.npy` gives `per_image_presence` from `trait_summary.json`
  to within 1e-3.
- **V2: the tree builder matches fordera's.** Given fordera's scores, moose's
  balanced term-tree builder produces exactly fordera's `trait_tree.json`, and
  `classify()` gets 26/33 years and 28/33 generations right.
- **V3: a from-scratch run is comparable.** moose does its own k-means and
  names its own terms. The terms and names will differ from fordera's, since
  k-means runs differently. The report compares training and leave-one-out
  accuracy with fordera's 85% and 61% by generation.
- **V4: the question key is reported.** The report gives the question key's
  machine self-walk accuracy, next to fordera's 27% by generation, with the
  two fixes below.
- **Every existing moose method works on the new keys:** `summary()`,
  `validate()`, `toNewick()`, `toDataTree()` and `exportWizard()`.
- **The package check stays clean.** `R CMD check` passes, and the
  Python-dependent tests skip cleanly when Python isn't available.

## Non-goals

- fordera's scraper, the OCR step that paints out year text, Grad-CAM, the
  ResNet k-NN classifier and the BLIP-generated vocabulary.
- Importing fordera's JSON, and the interchange JSON format. Both are
  possible follow-ups.
- Shipping truck images or model weights in the package. The truck
  illustrations are Street Trucks Magazine's, and the weights are 354 MB.
- Running CLIP in the browser.

## Architecture

There are two layers, and the core never needs Python.

```
images ──► [Python layer, via reticulate]  ──► embeddings (plain R matrices/arrays)
                visionModel(), embedImages(), embedTexts(), patchExemplars()
                                              │
                                              ▼
           [R core, model-free]  discoverTerms() → termScores() → keyFromTerms()
                                 keyFromClusters(vocabulary, textEmb)
                                 classify(), evaluateKey(), looKey()
                                              │
                                              ▼
                               moose key (leads + features) ──► exportWizard()
```

- **Python layer.** This is `inst/python/moose_vision.py`, plus thin R
  wrappers in `R/vision-python.R`. Python does everything that needs the
  model or pixels:
  - loading the model;
  - preprocessing and cropping images;
  - global and patch embeddings;
  - text embeddings;
  - cutting out the patch crops used as exemplars.
- **R core.** This is `R/vision.R`. It works only on numeric matrices, so it
  is testable with synthetic data and can be used with embeddings from any
  source.

## Python layer (`inst/python/moose_vision.py`)

**Dependencies:** `torch`, `open_clip_torch`, `pillow` and `numpy`. They are
installed with pip into any environment. reticulate is only a Suggests
dependency of moose.

**Loading the model.**
- `load_model(name="ViT-B-32", pretrained="openai", weights=None, device="cpu")`
  loads a model through open_clip.
- If `weights` is given, it loads that file with open_clip's OpenAI-checkpoint
  loader.
- The weights' SHA-256 is recorded, so a key can refuse scores computed with
  a different model.
- It returns the model, its preprocessing, the tokenizer and a model spec: a
  dict of library, architecture, pretrained tag, SHA-256, image size and
  embedding dimension.

**Image embeddings.**
- `embed_images(model, paths, region=None, patches=True, batch=16)` returns
  the global embeddings (n × d) and, optionally, the patch tokens (n × p × d).
- The patch tokens are computed exactly as fordera does:
  - patch tokens from the last transformer block;
  - then `ln_post` and `proj`;
  - then the class token is dropped.
- Everything is normalized to unit length.
- `region = (y0, y1, x0, x1)` crops each image, given as fractions, before it
  is preprocessed.

**Text embeddings.** `embed_texts(model, texts)` returns an m × d matrix of
unit-length rows.

**Patch crops.**
- `patch_boxes(path, patch_index, grid)` maps a ViT patch back to
  original-image pixels, taking account of preprocessing (resize the shorter
  side, then center-crop).
- `crop_png(path, box, pad, size)` returns a base64 PNG crop.

**R wrappers.**
- `visionModel(weights = NULL, name = "ViT-B-32", pretrained = "openai", python = NULL)`
- `embedImages(model, paths, region = NULL, patches = TRUE)` returns
  `list(image = matrix, patches = array)`.
- `embedTexts(model, texts)`
- `scoreImages(key, model, paths)` computes every feature in `key$features`
  for new images, so they can be passed to `classify()`.

## R core (`R/vision.R`)

**Image sets.**
- `imageSet(paths, label = NULL)` returns a data frame of `path`, `label` and
  `id`.
- By default the label is the file name without its extension. A function or
  regular expression can derive it instead. For fordera, `sub("_.*$", "", ...)`
  makes `1967_alt` count as 1967.

**Terms.**
- `discoverTerms(patches, k = 40, seed = 1, nstart = 10)` clusters all patch
  vectors with `stats::kmeans` and re-normalizes the centroids.
- Each term gets an invented name from `inventNames(k, seed)`, a phonetic
  generator in the spirit of fordera's (made from onsets, vowels and codas)
  that is reproducible and has no duplicates.
- It returns a terms table:
  - id, name and centroid;
  - the top-4 exemplars, as (image, patch, score).

**Term scores.** `termScores(patches, terms)` gives, for each image and term,
the highest cosine similarity between any of the image's patches and the
term's centroid. The result is an n × k matrix.

**Term key.** `keyFromTerms(scores, images, method = c("balanced", "rpart"), quantile = 0.6)`
- **`balanced`** is fordera's algorithm, exactly:
  - thresholds are per-term quantiles (type 7, like numpy);
  - a label counts as having a term if any of its images does;
  - each split uses the term that divides the labels most evenly, skipping
    terms already used above it;
  - ties go to the first term in id order;
  - the recursion stops at depth 20.
- **`rpart`** routes the scores through `keyFromRpart()`, so the split points
  become the thresholds.

**Question key.** `keyFromClusters(imageEmb, images, vocabulary, textEmb, template = "{feature}", maxPerSide = 10, calibrate = c("none", "midpoint"))`
- **Clustering.** Class means are computed from the normalized image
  embeddings, then clustered with `hclust(method = "ward.D2")`. That equals
  scipy's `ward`.
- **Order.** An optional `order` function sorts the children at each split.
  For the trucks, earliest year goes on the left.
- **Vocabulary.** A data frame with `feature`, `opposite` and an optional
  `region` column.
- **Choosing the question.** Each split takes the highest-scoring pair not
  used above it. A pair's score is (sim_yes − sim_no) on the left mean minus
  the same on the right mean.
- **Fix 1.** The "yes" lead goes to whichever side actually has the feature.
  fordera keeps the question wording when the reverse direction wins, so on
  those splits its "yes" branch is backwards.
- **Fix 2.** Machine answers use the same prompt pair that was used to pick
  the question. fordera picks with "with X" vs "with Y" but answers with
  "with X" vs "without X".
- **Score and threshold.** The score is cos(image, yes) − cos(image, no),
  which is the same as a 2-way softmax at 0.5. With `calibrate = "none"` the
  threshold is 0. With `"midpoint"` it is halfway between the two sides'
  mean scores.

**Machine use.**
- `classify(key, scores)` walks each row of a scores matrix through the key.
  It returns the result and the path taken.
- `evaluateKey(key, scores, images, groups = NULL)` returns accuracy (overall,
  and by group if `groups` is given, e.g. generations) and a confusion table.
- `looKey(builder, ...)` does leave-one-out evaluation. Each held-out image is
  classified by a key rebuilt without it. `refitTerms = FALSE` matches
  fordera, which leaks the held-out image into the terms. `TRUE` refits the
  terms too, for an honest estimate.

## Data model changes (`R/moose.R`, `R/keys.R`)

**New `features` field on `moose`.** A data frame with one row per feature:

| Column | Meaning |
|---|---|
| `id` | `term:<name>` or `text:<slug>` |
| `kind` | `centroid_patch_max` or `clip_text_pair` |
| `label` | name shown to people |
| `prompt`, `negative_prompt` | for text features |
| `region` | crop, for text features |
| `embedding` | list column of numeric vectors |
| `exemplars` | list column of data frames: image, patch, score, png |

The model spec goes in `meta` under the keys `model_*`.

**Optional lead columns.**
- `Feature`, `Test` (`>` or `<=`) and `Threshold` let a machine follow a lead.
- `Question` gives a step heading. Both leads of a couplet share it (e.g. the
  term's name or the question text).

**Constructor.** `keyFromLeads()` gains a `features` argument.

**`validate()` checks** that:
- every `Feature` exists in `features`;
- both leads of a couplet test the same feature, with opposite tests.

## Wizard changes (`R/export.R`, `inst/wizard/`)

- **Embed each image once.** Images go in the page's stylesheet as CSS
  classes, and each place that uses one references it. This still works
  without JavaScript, and it fixes the 4–5 MB pages.
- **Correct MIME types,** detected from the file's first bytes (PNG, JPEG,
  GIF, WebP).
- **Thumbnail strips** instead of stacked full-width images, with a tap to
  enlarge.
- **`Question` as the step heading** instead of "Term 1".
- **Glossary.** For term keys, a glossary section shows each term's patch
  crops, and each lead links to its term's entry.

## Verification (`analysis/fordera/`, not in the built package)

- `verify.R` runs V1–V4 against `~/Documents/fordera`. It reads the images
  and fordera's outputs from there, and the weights from `ViT-B-32.pt`.
- `REPORT.md` records the results.
- Nothing from fordera is copied into the repo.

## Tests (`tests/testthat/`)

- **R core, with synthetic embeddings:**
  - k-means terms and determinism;
  - `inventNames` is unique and reproducible;
  - the balanced builder on a hand-worked 4-class example;
  - `keyFromClusters` orients leads correctly (fix 1) on a synthetic
    vocabulary;
  - `classify`, `evaluateKey` and `looKey`;
  - `validate()` catches bad features;
  - wizard: each image appears once, MIME types are right, the glossary is
    rendered;
  - every existing moose method runs on vision keys.
- **Python layer:** skipped unless reticulate, torch and open_clip are
  present and `MOOSE_CLIP_WEIGHTS` points to weights. It covers embedding
  shapes and unit norms, region cropping, patch boxes, and a smoke test that
  goes from images to a key to `classify()` on a few generated images.

## Housekeeping

- Add `*.pt` to `.gitignore` and `.Rbuildignore`.
- Add `.env*` to `.gitignore`. These files appeared untracked; I haven't read
  them.
- Add `^docs$` to `.Rbuildignore`.
- `DESCRIPTION`: add `reticulate` and `png` to Suggests.
- README: a "Keys from images" section, with the pip command for the Python
  dependencies.

## Risks

- **k-means differences.** R's k-means (Hartigan–Wong) and sklearn's
  (k-means++ with Lloyd) give different clusters, so V3 compares accuracy
  rather than terms.
- **Compute.** torch on CPU needs about 1 GB of memory for ViT-B/32, and 33
  images take seconds. I'll run the Python layer in my workspace, which gets
  torch from PyPI, with the weights staged there; the shell on your Mac has
  only 3 GB.
- **Overfitting.** With one image per class, every accuracy figure is
  optimistic. The report says so and gives leave-one-out figures alongside.
