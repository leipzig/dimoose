# A sniglet namer that asks Claude

Makes the `model` function
[`suggestSnigletNames()`](https://leipzig.github.io/dimoose/reference/suggestSnigletNames.md)
needs from the [Anthropic Messages
API](https://platform.claude.com/docs/en/api/messages): each call sends
one sniglet's crops and the prompt, and returns the text of the reply.
Every call is billed to the API key's account; one call is made per
sniglet, plus one for every name that has to be asked for again.

## Usage

``` r
claudeNamer(
  model = "claude-opus-5-5",
  apiKey = Sys.getenv("ANTHROPIC_API_KEY"),
  maxTokens = 16000,
  effort = NULL,
  retries = 3,
  timeout = 120,
  url = "https://api.anthropic.com/v1/messages",
  fallback = FALSE
)
```

## Arguments

- model:

  The model to ask. It has to accept images.

- apiKey:

  The API key. By default the `ANTHROPIC_API_KEY` environment variable.

- maxTokens:

  The most tokens a reply may use. Current models think before they
  answer and the thinking counts, so leave room for it; only the tokens
  actually used are billed.

- effort:

  Optional effort level (`"low"`, `"medium"`, `"high"`, ...) for models
  that take one; `"low"` is plenty for naming and costs less. By default
  it is not sent and the model's own default applies.

- retries:

  How many times to try again after a rate limit or a server error.

- timeout:

  Seconds to wait for a reply.

- url:

  The API endpoint.

- fallback:

  `TRUE` to let the API answer with another model when the one asked
  declines (its safety classifiers can misjudge a harmless photo). This
  sends `fallbacks = "default"` with the beta header
  `server-side-fallback-2026-07-01`, which the Anthropic API takes but
  not every platform that serves Claude; by default it is not sent and a
  declined request is reported on that sniglet's row.

## Value

A function `function(images, prompt)` returning the reply's text.

## Details

A rate limit (HTTP 429), an overloaded service (529) or a server or
connection error is tried again up to `retries` times, waiting as long
as the API asks. Any other error stops that one call with the API's
message, which
[`suggestSnigletNames()`](https://leipzig.github.io/dimoose/reference/suggestSnigletNames.md)
reports for that sniglet before carrying on with the next. So does a
reply the model declined to give (stop reason `"refusal"`) and one that
ran out of tokens (`"max_tokens"`).

## Images

The API takes JPEG, PNG, GIF and WebP images of at most 5 MB each (as
base64; some platforms allow more), and reads small images poorly. With
the magick package installed, crops larger than 2000 pixels or 5 MB are
scaled down before they are sent and crops smaller than 200 pixels are
enlarged. Without it they are sent as they are, and a crop over 5 MB
stops that call with a message. A call with more than 100 images is
refused, and with many large crops each is scaled down further so that
the request stays under the API's 32 MB.

## See also

[`suggestSnigletNames()`](https://leipzig.github.io/dimoose/reference/suggestSnigletNames.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# needs an API key in ANTHROPIC_API_KEY; the calls are billed to it
key <- patchExemplars(vision, key, images)
suggestSnigletNames(key, claudeNamer(), file = "names.csv")
# ... review names.csv ...
key <- renameSniglets(key, "names.csv")
} # }
```
