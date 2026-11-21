# Contributing to dimoose

Thank you for helping. Bug reports, keys that fail to import, ideas and
pull requests are all welcome.

## Reporting a problem

Open an issue at <https://github.com/leipzig/dimoose/issues>. It helps
to include:

- what you ran, as a small example that can be pasted into R. For a key,
  the lead table (`key$leads`) or the spreadsheet rows are usually
  enough;
- what you expected and what happened instead, with the full error
  message;
- the output of
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).

For a FishBase key that imports wrongly, give its key number
(`importFishbase(<number>)`).

Please do not post photos or data you are not allowed to share.

## Proposing a change

For anything larger than a small fix, open an issue first so we can
agree on the approach before you spend time on it.

1.  Fork the repository and make a branch from `master`.

2.  Install the development dependencies:

    ``` r

    install.packages(c("remotes", "devtools"))
    remotes::install_deps(dependencies = TRUE)
    ```

3.  Make the change, with a test and documentation (see below).

4.  Run the checks:

    ``` r

    devtools::document()   # regenerates man/ and NAMESPACE from the roxygen comments
    devtools::test()
    devtools::check()
    ```

5.  Add a line to the top of `NEWS.md` saying what changed, in words a
    user of the package would recognise.

6.  Open a pull request. The checks run on Linux, macOS and Windows
    (`.github/workflows/R-CMD-check.yaml`).

## Code style

- Base R where it is enough; a new dependency needs a good reason.
  Packages that only one feature needs go in `Suggests` and are checked
  for with [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html),
  with a message saying what to install.
- Function and argument names are camelCase
  ([`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md),
  [`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)),
  to match the existing interface.
- Call other packages as `pkg::fun()`.
- Error messages say what is wrong and what to do about it, in plain
  words, and name the row or lead when there is one
  (`"Row 4 has neither`Goes to`nor`Species`"`). Use
  `stop(..., call. = FALSE)`,
  [`warning()`](https://rdrr.io/r/base/warning.html) and
  [`message()`](https://rdrr.io/r/base/message.html), not
  [`cat()`](https://rdrr.io/r/base/cat.html) or
  [`print()`](https://rdrr.io/r/base/print.html), outside print methods.
- Comments explain why, not what.

## Documentation

Documentation is written as roxygen2 comments with Markdown, above each
function in `R/`. Do not edit `man/` or `NAMESPACE` by hand. Every
exported function needs a description of what it returns (`@return`) and
an example that runs without the network or optional software; wrap the
ones that cannot in `\dontrun{}` or use `@examplesIf`.

The website (<https://leipzig.github.io/dimoose/>) is built from the
repository by `.github/workflows/pkgdown.yaml`; `_pkgdown.yml` lists the
reference sections, so a new exported function has to be added there.

## Tests

Tests use testthat (3rd edition) and live in `tests/testthat/`.

- Tests must pass with no internet connection and without Python. Logic
  that handles downloaded data is tested on saved pages or injected data
  (see `test-parse-fishbase.R` and `fakeVisionModel()` in
  `helper-fake-vision.R`).

- A test that really calls a web service starts with `skip_on_cran()`
  and `skip_if_unreachable(url)` (`helper-network.R`). These are skipped
  on GitHub Actions, which sets `NOT_CRAN=false`; run them yourself
  before changing import code:

  ``` r

  Sys.setenv(NOT_CRAN = "true")
  devtools::test(filter = "fishbase|names")
  ```

- A test that needs an optional package starts with
  `skip_if_not_installed()`.

- The tests of the real vision model run only when
  `DIMOOSE_CLIP_WEIGHTS` points to a weights file (see
  `test-vision-python.R`).

## The page for people who do not use R

`webr/` holds a static page that runs the spreadsheet-to-wizard path in
the browser with [webR](https://docs.r-wasm.org/webr/latest/). Build and
try it with:

``` sh
Rscript webr/build.R            # writes webr/_site and checks it on the Montana key
python3 -m http.server --directory webr/_site 8000
```

The page loads only the R files listed in `webr/build.R`. If you change
[`keyFromSpreadsheet()`](https://leipzig.github.io/dimoose/reference/keyFromSpreadsheet.md),
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
or what they call, run the build again: it fails if those files have
come to need code from another file or another package.

## Data and photos

Third-party data and photos need a licence that allows redistribution,
and an entry in `inst/COPYRIGHTS` (and in `photos.tsv` for the Montana
photos) giving the source, author and licence.

## Conduct

Be kind and assume good faith. Harassment and personal attacks are not
accepted in issues, pull requests or any other project space; report
problems to the maintainer (address in `DESCRIPTION`).

## Licence

By contributing you agree that your contribution is distributed under
the package’s licence (GPL; see `DESCRIPTION`).
