# Have a vision-language model suggest names for sniglets

A sniglet starts with a coined word (`"dulmzil"`) because nobody has
looked at it yet. This function does the first look for you: it shows a
vision-language model each sniglet's example crops (and, for contrast,
crops from photos in which the sniglet was not found, when there are
any) and asks for a short name and a one-sentence definition. The result
is a names table for
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md),
so naming becomes reviewing suggestions instead of writing every name
from scratch. Nothing is renamed until you pass the table (or the CSV
file) to
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md).

## Usage

``` r
suggestSnigletNames(
  x,
  model,
  vision = NULL,
  images = NULL,
  scores = NULL,
  crops = NULL,
  sniglets = NULL,
  labels = NULL,
  examples = 4,
  contrast = 4,
  maxWords = 3,
  retries = 2,
  file = NULL,
  pause = 0,
  size = 96,
  resume = FALSE
)
```

## Arguments

- x:

  A key from
  [`keyFromSniglets()`](https://leipzig.github.io/dimoose/reference/keyFromSniglets.md),
  or a
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  result.

- model:

  The vision-language model: a function `function(images, prompt)` that
  returns the model's reply as text. `images` is a list with one entry
  per crop, each a list with `data` (the image, base64 encoded),
  `mediaType` (e.g. `"image/png"`) and `role` (`"example"` or
  `"contrast"`); the examples come first.
  [`claudeNamer()`](https://leipzig.github.io/dimoose/reference/claudeNamer.md)
  makes such a function for the Anthropic API.

- vision, images:

  A
  [`visionModel()`](https://leipzig.github.io/dimoose/reference/visionModel.md)
  and the
  [`imageSet()`](https://leipzig.github.io/dimoose/reference/imageSet.md)
  the sniglets were found in, to cut crops when `x` does not carry them.

- scores:

  Optional `images x sniglets` matrix from
  [`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md),
  used to pick contrast crops for a sniglet set.

- crops:

  Optional crops of your own: a list named by coined word, each entry
  either a character vector of examples or a list with `examples` and
  `contrast`. A crop is an image file, a `data:` URI or a base64 string.

- sniglets:

  Which sniglets to name (coined words or current names). By default the
  ones a key uses, or all of a sniglet set.

- labels:

  The class names, which a sniglet name must not contain. By default the
  key's results, or the labels of `images`.

- examples, contrast:

  How many example and contrast crops to show per sniglet at most.

- maxWords:

  Longest name allowed, in words.

- retries:

  How many times to ask again when a name cannot be used.

- file:

  Optional path of a CSV file to write the table to. It is the
  spreadsheet
  [`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
  reads: review it, edit the `name` and `definition` columns, then
  `renameSniglets(x, file)`. It is written after every sniglet.

- pause:

  Seconds to wait between sniglets, for APIs with a rate limit.

- size:

  Size in pixels of crops cut with `vision`.

- resume:

  `TRUE` to carry on from an existing `file` instead of starting again;
  see "Long runs".

## Value

A data frame with one row per sniglet, in the shape
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
takes: `sniglet` (the coined word), `name` and `definition` (the
suggestion, or what the sniglet already had when there is no usable
suggestion), followed by `status` (`"ok"`, `"suffixed"`, `"rejected"`,
`"error"` or `"no crops"`) and `note`.
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md)
ignores the last two columns.

## Where the crops come from

- A key that has been through
  [`patchExemplars()`](https://leipzig.github.io/dimoose/reference/patchExemplars.md)
  carries its crops, so nothing else is needed. The contrast crops are
  those of the key's "Lacks" leads.

- For a key without crops, or a
  [`discoverSniglets()`](https://leipzig.github.io/dimoose/reference/discoverSniglets.md)
  result, give `vision` and `images` and the crops are cut for you. For
  a sniglet set, `scores` (from
  [`snigletScores()`](https://leipzig.github.io/dimoose/reference/snigletScores.md))
  adds contrast crops: the best-matching region of the photos that match
  the sniglet least.

- Or give your own in `crops`.

## What makes a usable name

Each suggestion is checked, and the model is asked again (up to
`retries` times, with the reason) when a name

- has more than `maxWords` words (a leading "a", "an" or "the" is not
  counted);

- contains the name of one of the classes (`labels`), also in the
  plural: a sniglet is something you can see on a specimen, such as "a
  serrate margin", not the species it was found on. For labels written
  `"Common name (Genus species)"` the common name, the scientific name
  and the genus are all refused, and so is the last word of a common
  name of several words ("aspen" of "Quaking aspen", so "aspen bark" is
  refused), unless every class ends in it or it is a general word such
  as "tree" or "flower";

- is already the name or the coined word of another sniglet. Capitals,
  punctuation and a leading article make no difference: "Serrate margin"
  and "a serrate margin" are the same name;

- is no name at all ("unknown", "n/a", or nothing but punctuation).

A leading "has" or "lacks" is taken off first, since the key adds its
own.

If the last answer is still a duplicate it gets a number
(`"peeling bark 2"`, status `"suffixed"`). If it still breaks another
rule, or the model fails (an API error, a rate limit, a refusal, a reply
that cannot be read), the sniglet keeps the name it had and the row says
why in `status` and `note`; the other sniglets are not affected.

## Long runs

With `file`, the table is written after every sniglet, so a run that is
interrupted or stopped by an error leaves what it had. `resume = TRUE`
picks such a file up: sniglets it already has a usable name for (status
`"ok"` or `"suffixed"`) are not asked about again, the others are.
Without `resume` an existing file is overwritten. The folder of `file`
must exist.

## See also

[`claudeNamer()`](https://leipzig.github.io/dimoose/reference/claudeNamer.md),
[`renameSniglets()`](https://leipzig.github.io/dimoose/reference/renameSniglets.md),
[`snigletNames()`](https://leipzig.github.io/dimoose/reference/snigletNames.md)

## Examples

``` r
set.seed(1)
patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
patches <- sweep(patches, c(1, 2), sqrt(apply(patches^2, c(1, 2), sum)), "/")
s <- discoverSniglets(patches, k = 2)
pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
crops <- stats::setNames(list(pics$path[1:2], pics$path[3:4]), s$sniglets$sniglet)
# a stand-in for a real model, which would look at the crops
replies <- c('{"name": "a waxy skin", "definition": "Smooth skin with a dull shine."}',
             '{"name": "a ribbed surface", "definition": "Parallel ridges along the fruit."}')
asked <- 0
fake <- function(images, prompt) { asked <<- asked + 1; replies[asked] }
suggestions <- suggestSnigletNames(s, fake, crops = crops, labels = unique(pics$label))
suggestions
#>         sniglet             name                       definition status note
#> 1     gaithiark      a waxy skin   Smooth skin with a dull shine.     ok     
#> 2 treuxraikbluk a ribbed surface Parallel ridges along the fruit.     ok     
snigletNames(renameSniglets(s, suggestions))
#>         sniglet             name                       definition
#> 1     gaithiark      a waxy skin   Smooth skin with a dull shine.
#> 2 treuxraikbluk a ribbed surface Parallel ridges along the fruit.
```
