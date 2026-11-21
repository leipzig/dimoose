# Export an interactive dichotomous key

Writes a dimoose key as a single self-contained HTML page. With
JavaScript on, the page steps through the key one couplet at a time,
keeps a trail of the choices made (each one clickable to go back to it)
and supports the browser's Back button. Without JavaScript, the same
page is the full key with every lead hyperlinked to its next couplet or
taxon. Each taxon gets a result section listing the characters on its
path, and a map of the key shows where the user is (see `map`).

## Usage

``` r
exportWizard(
  key = NULL,
  file = NULL,
  displayLinks = TRUE,
  order = "original",
  title = NULL,
  map = TRUE,
  staticPaths = NULL,
  matrix = NULL,
  characters = NULL,
  taxon = "Taxon",
  offline = FALSE,
  photoModel = NULL,
  photoRuntime = NULL
)
```

## Arguments

- key:

  A [dimoose](https://leipzig.github.io/dimoose/reference/dimoose.md)
  object, e.g. from
  [`importFishbase()`](https://leipzig.github.io/dimoose/reference/importFishbase.md).
  May be `NULL` if `matrix` is given.

- file:

  Path of the HTML file to write. If `NULL`, the HTML is returned as a
  string instead.

- displayLinks:

  If `TRUE`, show the couplet numbers each lead leads to and comes from,
  as in a printed key. If `FALSE`, hide them. Leads stay clickable
  either way.

- order:

  Deprecated and ignored. Couplets are always exported in the key's own
  order. `"parsimony"` was never implemented; to ask the questions that
  are easiest to observe first, build the key with
  [`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
  and give the characters a `Cost`.

- title:

  Page title. Defaults to the key's description.

- map:

  If `TRUE`, include a map of the key: the whole key drawn as a tree,
  marking the current couplet, the path taken so far and the branches
  (and number of taxa) still possible. It sits beside the key on wide
  screens and behind a Map button on phones.

- staticPaths:

  If `TRUE`, write each taxon's path through the key into the page, so
  it shows without JavaScript. If `FALSE`, the page builds the path in
  the browser when a result is shown, which keeps large keys (such as
  [`phylotreeKey()`](https://leipzig.github.io/dimoose/reference/phylotreeKey.md)
  on the whole tree) much smaller. The default is `TRUE` for keys with
  up to 1,000 taxa.

- matrix:

  Optional character matrix: a data frame with one row per taxon, the
  taxon's name in column `taxon` and one column per character. Cells are
  states; several states of one taxon are separated by `"/"`; `NA` is
  unknown or inapplicable. See 'Picking characters in any order'.

- characters:

  Optional data frame describing the characters of `matrix`: column
  `Character` (a column name of `matrix`) and any of `Cost` (lower is
  easier to observe), `Season` (when it can be observed) and `Needs`
  (e.g. `"hand lens"`).

- taxon:

  Name of the column of `matrix` that holds the taxon names.

- offline:

  If `TRUE`, also write a web app manifest, a service worker and icons
  next to `file`, so that the page can be installed and opened without a
  connection. Needs `file`. See 'Offline use'.

- photoModel:

  Optional: a folder written by
  [`exportBrowserModel()`](https://leipzig.github.io/dimoose/reference/exportBrowserModel.md)
  for this key, or the web address (`https://...`) of one. Adds
  "Identify from a photo" to the page. See 'Identifying from a photo'.

- photoRuntime:

  Optional web address of a folder holding the `dist` files of
  onnxruntime-web (`ort.wasm.min.js`, `ort-wasm-simd-threaded.mjs` and
  `.wasm`), to serve them yourself instead of loading them from
  jsDelivr. Relative addresses are relative to the page.

## Value

The path to `file`, invisibly, or the HTML as a character string if
`file` is `NULL`. With `offline = TRUE` or a `photoModel` folder the
paths of the other files written are in attribute `"files"`.

## Details

The key is checked first: leads pointing at missing couplets, terminal
leads without a taxon, couplets with fewer than two leads and couplets
that cannot be reached from the first one are reported as warnings and
marked in the page.

## Not sure

Every couplet has an "I'm not sure" button (keys `u` or `?`). It follows
all leads of the couplet at once. The page then asks the questions of
one branch at a time, lists the branches still open (click one to answer
it next), and counts and marks on the map the taxa possible in any of
them. Each answer narrows its own branch. If the reader stays unsure to
the end, the page lists every result that is left. Back undoes one step
at a time. The address of the page records the open branches
(`#open=c-3,c-9`), so a reload or a shared link returns to the same
place; the trail of choices comes back too when the browser restores the
page's history entry.

## Picking characters in any order

With `matrix`, the page gains a second way in: a list of the characters
of the matrix, to answer in any order. Picking a state removes the taxa
that do not have it. A taxon with several states (`"a/b"`) fits any of
them, and a taxon whose state is unknown (`NA`) fits all. The characters
that still separate the remaining taxa are listed first: cheapest first
when `characters` gives a `Cost`, then those that leave the fewest taxa
on average. Taxa of the matrix are matched to the key's taxa by name
(ignoring case), so the remaining taxa link to their result sections and
show on the map, and the page offers to continue step by step from the
couplet they all share. Without JavaScript the matrix is a plain table.
The two ways are otherwise independent: answers given step by step do
not filter the character list. With `key = NULL` the page is the
character list alone.

## Offline use

The page itself needs no connection once it is open, but a browser will
not reopen a page it cannot fetch. `offline = TRUE` writes four files
next to `file`, named after it: a web app manifest
(`<name>.webmanifest`), a service worker (`<name>-sw.js`) and two icons
(`<name>-icon-192.png`, `<name>-icon-512.png`; the package logo if the
rsvg package is installed, otherwise a simple drawn icon). The worker
stores the page, the manifest, the icons and the figures the page loads
from other sites, so that the page can be installed on a phone ("Add to
Home Screen") and opened without signal. Upload all five files to the
same folder. Limits:

- Browsers run service workers only on `https://` or `http://localhost`.
  A page opened from disk (`file://`) works as before but is not
  installed and stores nothing.

- The page must be opened once with a connection before it works
  without.

- Figures on other sites are fetched when the worker installs and again
  when first shown; any that fail are skipped. A site that does not
  allow cross-origin requests gives an opaque copy, which browsers count
  as several megabytes each against the storage they allow, so a key
  with many such figures may not store them all. Figures embedded in the
  key (see
  [`imageMeta()`](https://leipzig.github.io/dimoose/reference/imageMeta.md))
  are part of the page and always available. Full-size figures and taxon
  pages that open in a new tab are not stored.

- The worker only controls the page it was written for (its scope is the
  page's own address), so several keys can share a folder. Serve the
  page under its file name; a server that drops the `.html` from
  addresses puts the page outside the worker's scope.

## Identifying from a photo

`photoModel` adds an "Identify from a photo" button. The reader takes or
picks a photo; the page loads the model and
[onnxruntime-web](https://onnxruntime.ai/docs/tutorials/web/) (the
program that runs it, version 1.31.1, about 15 MB, from the jsDelivr CDN
unless `photoRuntime` says otherwise), prepares the picture as the
model's `model.json` says, runs the image encoder in the browser and
compares the result with the text embeddings of the key's taxa. The
photo never leaves the reader's device. The page then marks the likely
taxa on the map, lists the five best with their scores, each linked to
its result, and offers to narrow the key to them: the leads that reach
none of them are greyed and the count of remaining taxa follows, but
every lead still works. The key stays the authority; the photo is a
hint.

`photoModel` is a folder written by
[`exportBrowserModel()`](https://leipzig.github.io/dimoose/reference/exportBrowserModel.md)
for the same key, or the web address of one. The model is not put into
the page. A folder is copied next to `file` as `<name>_model/` (so
`file` is needed); upload it with the page. A web address is used as it
is; a model on another site must allow cross-origin requests. What to
expect:

- Nothing is downloaded until the reader has chosen a photo, been told
  the size and agreed. An int8 BioCLIP encoder is 90 MB; with the
  runtime that is about 105 MB on first use. The page shows the
  progress.

- With `offline = TRUE` the service worker keeps the model and the
  runtime once they have been fetched, so photos can be identified
  without a connection afterwards. That is the same 105 MB or so of
  storage on the reader's device, and the first use still needs a
  connection.

- It needs a browser with WebAssembly, and memory: several times the
  size of the encoder while it loads. If the browser cannot run the
  model, runs out of memory or cannot fetch it, the page says so and the
  key works as before. A page opened from disk (`file://`) cannot load
  the model.

- Only the WebAssembly backend is used, on one thread unless the page is
  served cross-origin isolated. That suits int8 encoders, which WebGPU
  cannot run.

- The scores compare the key's taxa with each other and add up to 100%,
  so a photo of something that is not in the key still gets a confident
  best match. If `model.json` has a `min_similarity`, a best match whose
  cosine similarity is under it is shown as "Not much like any taxon of
  this key" without a percentage.

## Notes on leads

A `Note` column in the key's leads, as
[`pruneKey()`](https://leipzig.github.io/dimoose/reference/pruneKey.md)
writes when it collapses a couplet (the character of the couplet that is
no longer asked), is shown under its lead as "Also:" and in the path of
each result. A `pruned_note` in the key's meta (the same for a collapsed
first couplet) is shown under the title.

## Hook for other scripts

The page defines `window.dimoose` so that another script, for example
one that identifies a photo in the browser, can work with the page
without knowing how it is built:

- `dimoose.taxa`: array of `{ id, name }`, one per result.

- `dimoose.highlight(scores, opts)`: `scores` is an object mapping taxon
  names or ids to numbers, or an array of `{ taxon, score }`; `null`
  clears. Marks those taxa on the map and in every list of candidates
  and lists the five best above the key, headed by `opts.label` (default
  "Suggested"). Scores all within 0 to 1 are shown as percentages.
  Returns the ids it marked, best first.

- `dimoose.goToTaxon(nameOrId)`: shows that result; `false` if unknown.

- `dimoose.narrow(namesOrIds)`: narrows the key to these taxa (see
  'Identifying from a photo'); `null` undoes it. Returns the ids kept.

- `dimoose.state()`: `{ shown, open, remaining, picks, narrowed }`, the
  section shown, the open branches, the ids of the taxa still possible,
  the states picked in the character list and the ids the key is
  narrowed to (or `null`).

- `dimoose.photo` (only with `photoModel`): `identify(file)`, a promise
  of the ranked taxa, and the pure steps `preprocess()` and `score()`.

- `dimoose.onChange(fn)`: calls `fn(state)` after every step.

## See also

[`keyFromMatrix()`](https://leipzig.github.io/dimoose/reference/keyFromMatrix.md)
to build a key from a character matrix.

## Examples

``` r
leads <- data.frame(
  Statement = c("1", "1", "2", "2"), Choice = c("a", "b", "a", "b"),
  Character = c("Wings present", "Wings absent", "Two wings", "Four wings"),
  Next = c("2", "-", "-", "-"), Taxon = c("", "Silverfish", "Fly", "Bee")
)
key <- keyFromLeads(leads, "A tiny key")
html <- exportWizard(key)
substr(html, 1, 15)
#> [1] "<!doctype html>"

# With a character matrix the reader can also pick characters in any order
insects <- data.frame(
  Taxon = c("Silverfish", "Fly", "Bee", "Ant"),
  Wings = c("absent", "present", "present", "present/absent"),
  Sting = c("absent", "absent", "present", NA)
)
characters <- data.frame(Character = c("Wings", "Sting"), Cost = c(1, 3),
                         Needs = c("", "hand lens"))
html <- exportWizard(key, matrix = insects, characters = characters)
#> 1 of 4 taxa of the matrix are not results of the key and get no link: Ant

# A matrix alone makes a page with only the character list
html <- exportWizard(NULL, matrix = insects, title = "Four insects")

# An installable copy that opens without a connection once it is served
# over https: the page, a manifest, a service worker and two icons
dir <- tempfile("key")
dir.create(dir)
out <- exportWizard(key, file.path(dir, "insects.html"), offline = TRUE)
list.files(dir)
#> [1] "insects-icon-192.png" "insects-icon-512.png" "insects-sw.js"       
#> [4] "insects.html"         "insects.webmanifest" 
unlink(dir, recursive = TRUE)
```
