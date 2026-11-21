# dimoose: readiness for rOpenSci software peer review

**Status: nothing has been submitted.** No pre-submission inquiry, review
request or issue has been opened with rOpenSci or anywhere else. This is a
working document for the maintainer, and the inquiry at the end is a draft.

An audit of dimoose against the rOpenSci Dev Guide.

- **Updated** 19 November 2026 for the uncommitted working tree that becomes
  version 0.3.0: the rows marked *(0.3.0)* below were re-read against that
  tree. The measured figures (check status, test counts, coverage) were not
  re-measured; they are still those of commit `1831f44`.

- **Audited:** version 0.2.0 at commit `1831f44`, plus the files added with this
  audit (`.github/workflows/R-CMD-check.yaml`, `.github/workflows/test-coverage.yaml`,
  `codemeta.json`, `CONTRIBUTING.md`, `inst/CITATION`, `webr/`). Work in progress
  in the working tree on other files was not audited.
- **Sources** (fetched 2026-11-19): [Packaging guide](https://devguide.ropensci.org/pkg_building.html),
  [Continuous integration](https://devguide.ropensci.org/pkg_ci.html),
  [Policies: aims and scope](https://devguide.ropensci.org/softwarereview_policies.html),
  [Guide for authors](https://devguide.ropensci.org/softwarereview_author.html), and the
  [pre-submission](https://github.com/ropensci/software-review/blob/main/.github/ISSUE_TEMPLATE/B-submit-a-presubmission-inquiry.md)
  and [submission](https://github.com/ropensci/software-review/blob/main/.github/ISSUE_TEMPLATE/A-submit-software-for-review.md)
  issue templates.
- **Measured locally** (macOS, R 4.6.1, on a clean export of the commit, with
  `NOT_CRAN=false` and no Python configured, as on CI): `R CMD check --no-manual`
  gives `Status: OK`; tests `FAIL 0 | WARN 0 | SKIP 9 | PASS 888`; covr reports
  92.4% line coverage. Linux and Windows results will only be known when the new
  workflow first runs on GitHub.
- **Not run:** `pkgcheck::pkgcheck()` (not installed here). Editors run it on
  every submission, so run it before submitting; see "Before submitting" below.

## Summary

The package is in good technical shape for review: it passes `R CMD check`
cleanly, has a large test suite with high coverage, a pkgdown site, four
vignettes and roxygen2 documentation. The open points, most important first:

1. **Scope.** Not an obvious fit; needs a pre-submission inquiry (draft below).
   The reading, checking, pruning and publishing of keys fits, and 0.3.0
   makes that core much larger (plain-text keys, SDD, DELTA, Lucid and Xper,
   regional keys). The machine-learning parts probably do not fit; the
   mixed-effects trees have moved to a companion package, `mecit`.
2. **Naming.** Functions are camelCase; rOpenSci strongly recommends
   snake_case. A discussion point for the inquiry, not something to change first.
3. **Examples.** About 20 exported functions have no example.
4. **README.** Now has CI and coverage badges, a citation line, a short
   related-software section and a link to `CONTRIBUTING.md` *(0.3.0)*. Still
   missing: a repostatus badge and a code of conduct.
5. **Live web tests are skipped on CI**, where the guide wants them to run.
6. **Licence** is now `GPL (>= 3)` *(0.3.0)*; there is still no licence file
   in the repository.

## Requirements, one by one

Status is **met**, **partly**, **not met**, or **discuss**.

### Scope and fit (Policies 5.2)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Fits one or more package categories | **discuss** | See "Scope fit" below. | Open a pre-submission inquiry before a full submission. |
| General rather than narrow | **met** *(0.3.0)* | Reads keys from plain text (`keyFromText()`), spreadsheets, FishBase, and the keys and matrices of SDD, DELTA, Lucid and Xper (`R/sdd.R`, `R/delta.R`, `R/lucid.R`), and writes those formats. | The files dimoose writes have not been opened in Lucid, Xper or a DELTA program; do that before claiming exchange works both ways. |
| Interactive tools have a reproducible, scriptable route | **met** | The wizard is an output of `exportWizard()`; the browser page in `webr/` calls the same `keyFromSpreadsheet()` and `exportWizard()` and its help text names them. | None. |
| No significant overlap with existing R packages | **discuss** | The README has a short "Related software" section *(0.3.0)* naming `rfishbase`, `taxize`, Lucid, Xper3 and DELTA. CRAN and R-universe were still not searched for other key packages. | Search (`pkgsearch::pkg_search("dichotomous key")`, R-universe) and extend the section with what turns up. |
| Not under review elsewhere, not yet on CRAN | **met** | CRAN has no `dimoose` page (HTTP 404 on 2026-11-19). | Submit to rOpenSci before CRAN, as the policies advise. |

#### Scope fit

The closest categories, with what in the package supports each:

- **data munging** (best fit): "tools for handling data in specific scientific
  formats". An identification key is such a format, and the package's core is
  representing keys (`dimoose`, `keyFromLeads()`), validating them
  (`key$validate()`), and converting them (`toNewick()`, `toTreedata()`,
  `toIgraph()`, `toAuspiceJSON()`, `readHaplogrep()`, `haplotypeMatrix()`).
- **data retrieval**: `importFishbase()` downloads and parses FishBase keys;
  `checkNames()` checks names against the GBIF backbone.
- **field and laboratory reproducibility tools**: "form and data sheet
  generation" for field protocols. `keyFromSpreadsheet()` + `exportWizard()` +
  `keyDiagram()` turn a key kept in a spreadsheet into an offline phone page
  and a printable diagram.
- **data validation and testing**: `key$validate()` and `checkNames()`, a
  smaller part.

Likely to be judged out of scope:

- Keys generated by modelling: `generateTree()`, `keyFromRpart()`,
  `keyFromMatrix()`, `keyFromAlignment()`, and the photo pipeline
  (`visionModel()`, `embedImages()`, `discoverSniglets()`, `keyFromSniglets()`,
  `keyFromClusters()`, `identifyPhotos()`). The data-extraction category says
  "statistical/ML libraries for modelling or prediction are typically not
  included". These could instead fall under the *statistical software* track
  (Machine Learning; Dimensionality Reduction, Clustering and Unsupervised
  Learning), which has its own standards and requires `srr` annotations.
- `mecit()`, `keyFromMecit()` and `simulateExpression()` are no longer part
  of dimoose *(0.3.0)*: they moved to the companion package `mecit`.
- `keyDiagram()`: "data visualization packages are no longer in scope", though
  here it is an export of the key rather than general plotting.

Editors may ask for the package to be split (for example a core key package
and a `dimoose.vision` companion). Decide beforehand whether that would be
acceptable; the inquiry draft below asks the question openly.

### Package name and metadata (Packaging 1.1)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Short, descriptive, lower-case name not used on CRAN or Bioconductor | **met** | `Package: dimoose`; renamed from `moose` because of the CRAN package (README, Installation). | Run `pak::pkg_name_check("dimoose")` once to confirm (not run here). |
| `codemeta.json` at the repository root | **met** (new) | `codemeta.json`, written by hand in CodeMeta 2.0 form from `DESCRIPTION` because `codemetar` is not installed. | Regenerate with `codemetar::write_codemeta()` before submitting and whenever `DESCRIPTION` changes. Its `license` (`GPL-3.0-or-later`) and `version` (0.3.0) were corrected by hand *(0.3.0)*; `softwareSuggestions` still mirrors `DESCRIPTION` as it was read on 19 November 2026. |
| Authors in `Authors@R` with roles and ORCID | **met** | `DESCRIPTION`: one `person()` with roles `aut` and `cre` and an ORCID comment. | None. |
| Authorship of included material is clear | **met** | `Copyright:` field and `inst/COPYRIGHTS` (PhyloTree via Haplogrep, MIT; example pages; Montana photos in `inst/extdata/montana/photos.tsv`). | Consider `cph` entries in `Authors@R` for the Institute of Genetic Epidemiology (PhyloTree files). |

### Platforms (1.2) and continuous integration (CI chapter)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Runs on Windows, macOS and Linux | **partly** | Pure R, no compiled code. Passes on macOS locally. One test is `skip_on_os("windows")` (`tests/testthat/test-alignment.R:107`, a fake shell script standing in for FastTree). | Confirm from the first CI run. |
| Uses CI; all three operating systems when the package has system calls, path handling, text munging or other languages (all apply) | **met** (new) | `.github/workflows/R-CMD-check.yaml`: the r-lib/actions `check-standard` workflow, on push and pull request. The old `.travis.yml` was removed. | None. |
| Tested on release, previous release and development R | **met** (new) | Same workflow: Ubuntu `release`, `devel`, `oldrel-1`; macOS and Windows `release`. | None. |
| Coverage is reported | **partly** (new) | `.github/workflows/test-coverage.yaml` (the r-lib/actions workflow, covr + Codecov). | Add the repository secret `CODECOV_TOKEN` from codecov.io. Without it the upload step fails on pushes to `master`. |
| CI and coverage badges in the README | **met** *(0.3.0)* | `README.md`, under the title: R-CMD-check and Codecov. Both show nothing useful until the workflows have run and the Codecov token is set. | None. |

### Package API (1.3)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| snake_case function and argument names "strongly recommended" | **discuss** | Of the 57 exports, every multi-word name is camelCase (`keyFromSpreadsheet()`, `exportWizard()`); arguments are mixed (`checkNames`, `displayLinks`, but `target_col`, `min_branches`, `negative_prompt`). | Do not rename before asking. Raise it in the inquiry. Whatever the answer, make argument names one style; that inconsistency is the part a reviewer will press on. If a rename is requested, keep the old names as deprecated aliases for a release. |
| `object_verb()` naming, consistent families | **partly** | Clear families exist: `keyFrom*()`, `to*()`, `import*`/`parse*`, `*Scores()`. Verbs come first rather than last. | None needed beyond the naming discussion. |
| No name clashes with base or popular packages | **partly** | No export masks a base function. `checkNames()` is also the name of an argument of `keyFromSpreadsheet()` (handled with `dimoose::checkNames`, `R/spreadsheet.R`), and is close to base R's `check.names`. | Consider renaming the argument if names are revisited. |
| Functions return objects; nothing assigned in the global environment | **met** | `<<-` is used only inside closures (`R/diagram.R`, `R/alignment.R`). | None. |
| Messages via `message()`/`warning()`, not `cat()`/`print()`, outside print methods | **met** | `cat()` and `print()` appear only in print methods (`R/dimoose.R`, `R/vision-python.R`, and the print methods of the new files). | None. |
| Verbosity can be switched off | **met** | The package emits no progress messages. | None. |
| Consistent input checking | **met** | Base R `stop(..., call. = FALSE)` with plain messages throughout, e.g. `keyFromLeads()` (`R/keys.R:29`). | None. |
| Web resources: a user agent is sent | **met** | `dimooseUserAgent()` (`R/import.R:98`) is used for FishBase and GBIF requests. | None. |
| Web resources: the user can override the user agent | **not met** | The string is fixed. | Read it from `getOption("dimoose.user_agent", <default>)` and document the option. |
| Web resources: API errors are reported clearly | **met** | `httr::stop_for_status()` in `R/names.R`; `R/import.R` checks the responses. | None. |
| Web resources: respects the service's terms | **discuss** | `importFishbase()` reads FishBase HTML pages (`R/import.R:109`). | Check FishBase's terms of use and say in the documentation that keys are FishBase content to be cited (the CITATION file now does). The submission form asks you to confirm this. |
| Wrapped external software: installation documented | **met** | README installation table and "From a pile of photos" (Python is set up by reticulate on first use); `keyFromAlignment()` documents FastTree and IQ-TREE. | None. |
| Wrapped external software: a situation-report function | **not met** | Nothing reports which optional pieces (Python and open_clip, FastTree, IQ-TREE, gnparser, magick, rsvg) are available. | Add `dimooseSitrep()` that lists each with found/missing and the install hint. |

### Code style (1.4)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Consistent style | **met** | Base R, `<-` throughout, `pkg::fun()` calls. | Optionally run `lintr::lint_package()`; the long lines (some over 150 characters) will be commented on. |

### CITATION (1.5)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| A `CITATION` file using `bibentry()` | **met** (new) | `inst/CITATION`: the package, plus PhyloTree Build 17 (van Oven 2015) and FishBase for users of those data, as the guide suggests for wrapped resources. Checked with `utils::readCitationFile()`. | If releases are archived on Zenodo, add the concept DOI. |

### README (1.6)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Package name at the top | **met** | `README.md:1`. | None. |
| Badges: CI, coverage, repostatus.org | **partly** *(0.3.0)* | CI and Codecov badges are in. No repostatus badge: the status is the maintainer's to declare, and `codemeta.json` still says `wip`. | The two present are the first two of: `[![R-CMD-check](https://github.com/leipzig/dimoose/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/leipzig/dimoose/actions/workflows/R-CMD-check.yaml)`, `[![Codecov](https://codecov.io/gh/leipzig/dimoose/branch/master/graph/badge.svg)](https://app.codecov.io/gh/leipzig/dimoose)`, `[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)` and the R-universe badge. The author guide says to submit when the status is Active rather than WIP. |
| Short statement of goals, with links to the vignettes | **met** *(0.3.0)* | The opening explains keys; "Package methods" lists only what exported functions do (the claims about YAML, lexical analysis and training splits are gone); "A first key" links the four vignettes. | None. |
| Installation instructions | **met** | R-universe and `remotes::install_github()` (`README.md:32-65`), with a table of optional packages. | None. |
| Brief demonstration | **met** | "A first key" (`README.md:67`). | None. |
| Comparison with similar packages | **partly** *(0.3.0)* | "Related software" names `rfishbase`, `taxize`, Lucid, Xper3 and DELTA in a few lines. | Extend after the search (see Scope). |
| Citation information | **met** *(0.3.0)* | "Citing and contributing": "To cite dimoose, run `citation("dimoose")`." | None. |
| Code of conduct and contribution guidelines | **partly** | `CONTRIBUTING.md` has a short conduct paragraph and is linked from the README *(0.3.0)*; there is no `CODE_OF_CONDUCT.md`. | `usethis::use_code_of_conduct(contact = ...)` with the address you want reports sent to, and link it from the README. |
| README generated from `README.Rmd` (recommended) | **not met** | `README.md` is written by hand, with pasted output. | Optional: `usethis::use_readme_rmd()` so the output cannot go stale. |

### Documentation (1.7)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| roxygen2 with Markdown | **met** | `DESCRIPTION`: `Roxygen: list(markdown = TRUE)`; all of `man/` is generated. | None. |
| Every exported function documented | **met** | At `1831f44`: 57 exports in `NAMESPACE`; 57 `.Rd` files (some functions share a page, and the datasets and the package have their own); `R CMD check` reports no missing documentation. The 0.3.0 tree has 86 exports once the four that moved to `mecit` are taken out; each new one has a roxygen block, but `R CMD check` has not been run on that tree. | Run the check after regenerating `man/`. |
| Every exported function has an example | **not met** | No `\examples` in the help pages of `alignmentScores`, `classify`, `evaluateKey`, `looKey`, `featureScores`, `imageMeta`, `imageMime`, `embedImages`, `embedTexts`, `modelMeta`, `patchExemplars`, `scoreImages`, `keyFromClusters`, `keyFromSniglets`, `snigletNames`, `snigletScores`, `rawhtml`, or the `dimoose` class. Some or all of the example code is inside `\dontrun{}` for `exportWizard`, `importFishbase`, `parseFishbase`, `toIgraph`, `toTreedata`, `readHaplogrep`, `phylotreeKey`, `keyFromAlignment`, `visionModel`, `suggestSpecies`, `identifyPhotos` and the example keys. The functions new in 0.3.0 were not audited for this row; those that need the network, Python or an API key (`regionalKey`, `occurrenceWeights`, `onnxModel`, `exportOnnxModel`, `exportBrowserModel`, `inatPhotos`, `benchmarkKey`, `claudeNamer`) have theirs in `\dontrun{}` or `\donttest{}`. | Add runnable examples. Most need no network: `exportWizard(montanaKey(), tempfile(fileext = ".html"))`; `parseFishbase()` on the saved pages in `inst/extdata/fishbase`; the scoring functions on a tiny synthetic matrix; use `@examplesIf requireNamespace("igraph", quietly = TRUE)` for optional packages. |
| Return value documented for every function | **partly** | No `\value` for `rawhtml` and the `dimoose` class page (methods document theirs). | Add `@return` to `rawhtml()`. |
| Defaults of parameters documented | **partly** | Usually in the text ("by default the folder the CSV file is in"); not checked parameter by parameter. | Review while adding examples. |
| Package-level help page | **met** *(0.3.0)* | `R/dimoose-package.R` is rewritten as an overview with links to the main functions by task and to the vignettes. `man/dimoose-package.Rd` needs regenerating. | None. |
| At least one HTML vignette covering the main functions | **met** | `vignettes/montana-hardwoods.Rmd` (write a key) and `published-key.Rmd` (read, check, prune, measure and export a key; new in 0.3.0), plus `alignment-keys` and `vision-keys`. All four render with `rmarkdown::render()` *(0.3.0)*. | Consider naming the main one `dimoose.Rmd` so pkgdown shows "Get started". |
| Data sources identified in `DESCRIPTION` with a public URL | **partly** | FishBase and PhyloTree/Haplogrep are named with a URL and DOI. GBIF (`checkNames()`, and in 0.3.0 `regionalKey()` and `occurrenceWeights()`) and iNaturalist (`regionalKey(source = "inat")`, `inatPhotos()`) are not. | Add both to `Description` with their URLs, e.g. "checks names and counts occurrence records with 'GBIF' <https://www.gbif.org/> and 'iNaturalist' <https://www.inaturalist.org/>". |
| Cross-links between related functions | **partly** | `@seealso` is used widely; `@family` is not. | Optional: `@family` tags, which also drive pkgdown grouping. |
| No start-up messages | **met** | No `.onAttach()` in `R/`. | None. |
| Example data documented and attributed | **met** | `arachnida`, `vibrio`, `montana`, `phylotree17`, `phylotree17_mutations` have help pages; sources in `inst/COPYRIGHTS`. | None. |

### Documentation website (1.8)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| pkgdown site, deployed automatically, reference grouped | **met** | `_pkgdown.yml` (grouped reference), `.github/workflows/pkgdown.yaml`, <https://leipzig.github.io/dimoose/>. | After acceptance rOpenSci builds the site itself; the extra pages this workflow adds (`montana/`, `webr/`) would need another home. |

### Licence (1.10)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| CRAN- or OSI-accepted licence | **met** *(0.3.0)* | `License: GPL (>= 3)` in `DESCRIPTION`; `codemeta.json` says `GPL-3.0-or-later`. There is no licence file in the repository, so GitHub does not show the licence. | Optional: `usethis::use_gpl_license(version = 3, include_future = TRUE)` adds `LICENSE.md` (and an `.Rbuildignore` line). |

### Testing (1.11)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Passes `R CMD check` on all major platforms | **partly** | `Status: OK` on macOS locally. | Confirm Linux and Windows from CI. |
| Test suite covering the main functionality, including errors | **met** | 23 test files, 205 `test_that()` blocks, 888 passing expectations; many test error messages (`test-spreadsheet.R`, `test-dimoose-class.R`). | None. |
| Coverage of 75% or more | **met** | 92.4% overall. Lowest files: `R/import.R` 72.6% (the live download code), `R/vision-python.R` 77.8% (needs Python), `R/simulate.R` 85.1%. | The first two rise with recorded HTTP responses and a Python CI job, if wanted. |
| testthat | **met** | `Config/testthat/edition: 3`. | None. |
| Tests self-contained | **partly** | Some files define helpers and fixtures at top level (`test-vision-python.R`; `test-alignment.R:1` skips the whole file without `ape`). | Acceptable; move shared helpers into `helper-*.R` if a reviewer asks. |
| API tests skipped on CRAN but run on CI | **not met** | The live tests (`test-fishbase-import.R:4,17`, `test-names.R:71,79`) use `skip_on_cran()` and `skip_if_unreachable()`. The new workflows set `NOT_CRAN=false`, so they are skipped on CI too; this was chosen so that an outage at FishBase or GBIF cannot fail the build. | Either record the responses (`httptest` or `vcr`, both work with httr) so the tests run everywhere without the network, or add a weekly scheduled workflow that runs only the live tests with `NOT_CRAN=true`. Then the guide's wish is met without flaky pull-request checks. |

### Examples (1.12), dependencies (1.13), scaffolding (1.14), version control (1.15)

| Requirement | Status | Evidence | Fix |
|---|---|---|---|
| Examples are run on CI | **met** (new) | `R CMD check` in the workflow runs every example outside `\dontrun{}`. | None. |
| Few dependencies; optional ones in `Suggests` | **partly** | 8 non-base `Imports`; 21 `Suggests`, each guarded (`canUse()`, `requireNamespace()`). `httr`, `rvest` and `xml2` are imported though only `importFishbase()` and `checkNames()` use them, and `rpart` only for `generateTree()`/`vibrioKey()`. | Consider moving `rvest`, `xml2`, `httr` and `rpart` to `Suggests`; the browser page shows the core runs with only `R6`, `data.tree` and `base64enc`. |
| Recommended HTTP, JSON and XML packages | **met** | `httr`, `jsonlite`, `xml2`. | `httr2` is the current recommendation for new code; not required. |
| `Imports` rather than `Depends` | **met** | `Depends: R (>= 3.5.0)` only. | None. |
| Under Git | **met** | <https://github.com/leipzig/dimoose>. | None. |
| NEWS file | **met** | `NEWS.md`, one section per version, user-facing wording. | None. |
| Contribution guidelines | **met** (new) | `CONTRIBUTING.md`, linked from the README *(0.3.0)*. | None. |

## Before submitting

In this order:

1. Push the workflows, add `CODECOV_TOKEN`, and get all five check jobs green.
   The 0.3.0 tree has not been through `R CMD check` on any platform.
2. Regenerate `codemeta.json` with `codemetar` (the licence is now explicit;
   the file was corrected by hand).
3. Add a code of conduct and, when you are ready to call the package active,
   the repostatus badge. Search for related R packages and extend the
   README's related-software section. (Badges, citation line and the section
   itself are in.)
4. Add the missing examples. (The package-level help page is rewritten.)
5. Decide how the live web tests should run on CI (recorded responses or a scheduled job).
6. Install and run `pkgcheck::pkgcheck()` and fix or explain what it reports;
   the submission form asks for the reasons for any failing item.
7. Open the pre-submission inquiry below, and wait for the editors' answer on
   scope and naming before spending time on a rename or a split.

## Draft pre-submission inquiry

To be posted by the maintainer at
<https://github.com/ropensci/software-review/issues/new/choose> using the
"Submit a presubmission inquiry" template, which this follows. It is a draft:
check every statement, and complete the places marked TODO.

---

Submitting Author Name: Jeremy Leipzig
Submitting Author Github Handle: <!--author1-->@leipzig<!--end-author1-->
Repository: <!--repourl-->https://github.com/leipzig/dimoose<!--end-repourl-->
Submission type: <!--submission-type-->Pre-submission<!--end-submission-type-->
Language: <!--language-->en<!--end-language-->

---

- Paste the full DESCRIPTION file inside a code block below:

```
(paste DESCRIPTION here at the time of posting)
```

## Scope

- Please indicate which category or categories this package falls under:

    **Data Lifecycle Packages**

    - [x] data retrieval
    - [ ] data extraction
    - [x] data munging
    - [ ] data deposition
    - [ ] data validation and testing
    - [ ] workflow automation
    - [ ] version control
    - [ ] citation management and bibliometrics
    - [ ] scientific software wrappers
    - [x] field and lab reproducibility tools
    - [ ] database software bindings
    - [ ] geospatial data
    - [ ] translation

- Explain how and why the package falls under these categories (briefly, 1-2
  sentences). Please note any areas you are unsure of:

  dimoose handles one scientific data type, the dichotomous identification key:
  it reads keys from plain text, a spreadsheet, FishBase and the exchange
  formats of other key software (SDD, DELTA, Lucid, Xper), checks them (dead
  ends, unreachable couplets, species names against the GBIF backbone), cuts
  them down to the taxa recorded in a region, converts them to tree formats
  used in phylogenetics (Newick, treedata, igraph, Auspice JSON), and writes
  them out as a self-contained offline web page or a diagram for use in the
  field.

  I am unsure about two things. First, the package also *generates* keys from
  data: from a character matrix, from a sequence alignment and from photo
  embeddings (CLIP/BioCLIP through reticulate or ONNX Runtime). I expect
  these to be outside the data-lifecycle
  categories, and would like to know whether you would prefer them split into
  a separate package, reviewed under the statistical software track, or left
  in and excluded from review. Second, exported functions are camelCase
  (`keyFromSpreadsheet()`, `exportWizard()`). I would like to know whether a
  move to snake_case would be a condition of acceptance before I plan a
  deprecation cycle.

- If submitting a statistical package, have you already incorporated
  documentation of standards into your code via the srr package?

  No. This is not submitted as a statistical package; see the question above.

- Who is the target audience and what are scientific applications of this
  package?

  Taxonomists, field biologists, naturalists and teachers who write or maintain
  identification keys, and people who compile them into regional guides. A key
  kept in a spreadsheet becomes a checked, versionable object, and the same
  source produces the phone wizard, the printed diagram and the tree file.
  Researchers working with decision-tree-like structures in other fields can
  use the same object, for example the human mitochondrial haplogroup tree
  (PhyloTree Build 17 is included).

- Are there other R packages that accomplish the same thing? If so, how does
  yours differ or meet our criteria for best-in-category?

  TODO: confirm with a search of CRAN and R-universe before posting. As far
  as I know there is no R package for representing, validating and publishing
  dichotomous keys. `rfishbase` (rOpenSci) gives access to FishBase tables but,
  as far as I know, not to its identification keys; `taxize` resolves names
  but has no key structure. Interactive key software exists outside R (Lucid,
  Xper3, DELTA/Intkey); dimoose differs in being scriptable and open source,
  and in producing a single offline HTML file.

- (If applicable) Does your package comply with our guidance around Ethics,
  Data Privacy and Human Subjects Research?

  The package collects no personal data. The bundled human mitochondrial tree
  is a published phylogeny of haplogroups, not data about individuals.

- Any other questions or issues we should be aware of?

  `importFishbase()` reads FishBase's public key pages (HTML), sending an
  identifying user agent. TODO: state what FishBase's terms of use say about
  this once checked. The photo-based features need Python, which reticulate
  installs on first use; they are optional and their tests are skipped on CI.

## Use of Generative AI

- [x] Generative AI tools were used to produce some of the material in this submission.

  TODO: describe in your own words. The Git history records AI assistance in
  commit trailers (`Co-Authored-By: Claude ...`), and the CI workflows,
  `CONTRIBUTING.md`, `codemeta.json`, `inst/CITATION`, the `webr/` page and
  this readiness audit were drafted with Claude Code and should be reviewed by
  you before submission.

---
