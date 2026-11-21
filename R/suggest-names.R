#' Have a vision-language model suggest names for sniglets
#'
#' A sniglet starts with a coined word (`"dulmzil"`) because nobody has looked
#' at it yet. This function does the first look for you: it shows a
#' vision-language model each sniglet's example crops (and, for contrast,
#' crops from photos in which the sniglet was not found, when there are any)
#' and asks for a short name and a one-sentence definition. The result is a
#' names table for [renameSniglets()], so naming becomes reviewing suggestions
#' instead of writing every name from scratch. Nothing is renamed until you
#' pass the table (or the CSV file) to [renameSniglets()].
#'
#' @section Where the crops come from:
#' * A key that has been through [patchExemplars()] carries its crops, so
#'   nothing else is needed. The contrast crops are those of the key's "Lacks"
#'   leads.
#' * For a key without crops, or a [discoverSniglets()] result, give `vision`
#'   and `images` and the crops are cut for you. For a sniglet set, `scores`
#'   (from [snigletScores()]) adds contrast crops: the best-matching region of
#'   the photos that match the sniglet least.
#' * Or give your own in `crops`.
#'
#' @section What makes a usable name:
#' Each suggestion is checked, and the model is asked again (up to `retries`
#' times, with the reason) when a name
#'
#' * has more than `maxWords` words (a leading "a", "an" or "the" is not
#'   counted);
#' * contains the name of one of the classes (`labels`), also in the plural:
#'   a sniglet is something you can see on a specimen, such as "a serrate
#'   margin", not the species it was found on. For labels written
#'   `"Common name (Genus species)"` the common name, the scientific name and
#'   the genus are all refused, and so is the last word of a common name of
#'   several words ("aspen" of "Quaking aspen", so "aspen bark" is refused),
#'   unless every class ends in it or it is a general word such as "tree" or
#'   "flower";
#' * is already the name or the coined word of another sniglet. Capitals,
#'   punctuation and a leading article make no difference: "Serrate margin"
#'   and "a serrate margin" are the same name;
#' * is no name at all ("unknown", "n/a", or nothing but punctuation).
#'
#' A leading "has" or "lacks" is taken off first, since the key adds its own.
#'
#' If the last answer is still a duplicate it gets a number (`"peeling bark
#' 2"`, status `"suffixed"`). If it still breaks another rule, or the model
#' fails (an API error, a rate limit, a refusal, a reply that cannot be
#' read), the sniglet keeps the name it had and the row says why in `status`
#' and `note`; the other sniglets are not affected.
#'
#' @section Long runs:
#' With `file`, the table is written after every sniglet, so a run that is
#' interrupted or stopped by an error leaves what it had. `resume = TRUE`
#' picks such a file up: sniglets it already has a usable name for (status
#' `"ok"` or `"suffixed"`) are not asked about again, the others are. Without
#' `resume` an existing file is overwritten. The folder of `file` must exist.
#'
#' @param x A key from [keyFromSniglets()], or a [discoverSniglets()] result.
#' @param model The vision-language model: a function `function(images,
#'   prompt)` that returns the model's reply as text. `images` is a list with
#'   one entry per crop, each a list with `data` (the image, base64 encoded),
#'   `mediaType` (e.g. `"image/png"`) and `role` (`"example"` or
#'   `"contrast"`); the examples come first. [claudeNamer()] makes such a
#'   function for the Anthropic API.
#' @param vision,images A [visionModel()] and the [imageSet()] the sniglets
#'   were found in, to cut crops when `x` does not carry them.
#' @param scores Optional `images x sniglets` matrix from [snigletScores()],
#'   used to pick contrast crops for a sniglet set.
#' @param crops Optional crops of your own: a list named by coined word, each
#'   entry either a character vector of examples or a list with `examples`
#'   and `contrast`. A crop is an image file, a `data:` URI or a base64
#'   string.
#' @param sniglets Which sniglets to name (coined words or current names). By
#'   default the ones a key uses, or all of a sniglet set.
#' @param labels The class names, which a sniglet name must not contain. By
#'   default the key's results, or the labels of `images`.
#' @param examples,contrast How many example and contrast crops to show per
#'   sniglet at most.
#' @param maxWords Longest name allowed, in words.
#' @param retries How many times to ask again when a name cannot be used.
#' @param file Optional path of a CSV file to write the table to. It is the
#'   spreadsheet [renameSniglets()] reads: review it, edit the `name` and
#'   `definition` columns, then `renameSniglets(x, file)`. It is written
#'   after every sniglet.
#' @param resume `TRUE` to carry on from an existing `file` instead of
#'   starting again; see "Long runs".
#' @param pause Seconds to wait between sniglets, for APIs with a rate limit.
#' @param size Size in pixels of crops cut with `vision`.
#' @return A data frame with one row per sniglet, in the shape
#'   [renameSniglets()] takes: `sniglet` (the coined word), `name` and
#'   `definition` (the suggestion, or what the sniglet already had when there
#'   is no usable suggestion), followed by `status` (`"ok"`, `"suffixed"`,
#'   `"rejected"`, `"error"` or `"no crops"`) and `note`. [renameSniglets()]
#'   ignores the last two columns.
#' @seealso [claudeNamer()], [renameSniglets()], [snigletNames()]
#' @examples
#' set.seed(1)
#' patches <- array(rnorm(5 * 9 * 8), c(5, 9, 8))
#' patches <- sweep(patches, c(1, 2), sqrt(apply(patches^2, c(1, 2), sum)), "/")
#' s <- discoverSniglets(patches, k = 2)
#' pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
#' crops <- stats::setNames(list(pics$path[1:2], pics$path[3:4]), s$sniglets$sniglet)
#' # a stand-in for a real model, which would look at the crops
#' replies <- c('{"name": "a waxy skin", "definition": "Smooth skin with a dull shine."}',
#'              '{"name": "a ribbed surface", "definition": "Parallel ridges along the fruit."}')
#' asked <- 0
#' fake <- function(images, prompt) { asked <<- asked + 1; replies[asked] }
#' suggestions <- suggestSnigletNames(s, fake, crops = crops, labels = unique(pics$label))
#' suggestions
#' snigletNames(renameSniglets(s, suggestions))
#' @export
suggestSnigletNames <- function(x, model, vision = NULL, images = NULL, scores = NULL, crops = NULL,
                                sniglets = NULL, labels = NULL, examples = 4, contrast = 4, maxWords = 3,
                                retries = 2, file = NULL, pause = 0, size = 96, resume = FALSE) {
  if (!is.function(model)) stop("`model` must be a function of (images, prompt), such as claudeNamer()", call. = FALSE)
  count <- function(v, least) is.numeric(v) && length(v) == 1 && !is.na(v) && v >= least
  if (!count(retries, 0)) stop("`retries` must be 0 or more", call. = FALSE)
  if (!count(maxWords, 1)) stop("`maxWords` must be 1 or more", call. = FALSE)
  if (!count(examples, 1)) stop("`examples` must be 1 or more", call. = FALSE)
  if (!count(contrast, 0)) stop("`contrast` must be 0 or more", call. = FALSE)
  if (!is.null(file) && (!is.character(file) || length(file) != 1 || is.na(file))) stop("`file` must be one file name", call. = FALSE)
  if (isTRUE(resume) && is.null(file)) stop("`resume = TRUE` needs `file`, the table of the run to carry on from", call. = FALSE)
  # found out now, not after the first (billed) answer cannot be written
  if (!is.null(file) && !dir.exists(dirname(file))) stop("The folder of `file` does not exist: ", dirname(file), call. = FALSE)
  retries <- as.integer(retries)
  current <- snigletNames(x)
  isKey <- inherits(x, "dimoose")
  todo <- if (!is.null(sniglets)) {
    row <- match(sniglets, current$sniglet)
    row[is.na(row)] <- match(sniglets[is.na(row)], current$name)
    if (anyNA(row)) stop("Not a sniglet of this ", if (isKey) "key" else "set", ": ",
                         paste(utils::head(sniglets[is.na(row)], 5), collapse = ", "), call. = FALSE)
    unique(row)
  } else if (isKey) which(current$used) else seq_len(nrow(current))
  if (!length(todo)) stop("There are no sniglets to name", call. = FALSE)
  if (is.null(labels)) {
    labels <- if (isKey) x$leads$Taxon[!is.na(x$leads$Taxon) & nzchar(x$leads$Taxon)] else if (!is.null(images)) images$label
  }
  labels <- unique(as.character(labels))
  labels <- unique(trimws(unlist(strsplit(labels[!is.na(labels)], " / ", fixed = TRUE))))   # a leaf of several classes
  labels <- labels[nzchar(labels)]
  banned <- sugBannedWords(labels)
  shown <- sugCrops(x, current$sniglet[todo], vision, images, scores, crops, examples, contrast, size)
  if (!any(vapply(shown, function(s) length(s$examples) > 0, logical(1)))) {
    stop("No example crops to show the model. Run patchExemplars() on the key first, or give `vision` and `images`, or `crops`.",
         call. = FALSE)
  }

  out <- data.frame(sniglet = current$sniglet[todo], name = current$name[todo], definition = current$definition[todo],
                    status = "", note = "", stringsAsFactors = FALSE)
  good <- c("ok", "suffixed")
  if (isTRUE(resume) && file.exists(file)) {
    old <- sugReadTable(file)
    at <- match(out$sniglet, old$sniglet)
    keep <- !is.na(at) & old$status[at] %in% good & !is.na(old$name[at]) & nzchar(old$name[at])
    # a file edited by hand may give two sniglets one name: the first keeps it, the other is asked about again
    keep[keep] <- !duplicated(sugPlain(old$name[at[keep]]))
    out$name[keep] <- old$name[at[keep]]; out$definition[keep] <- old$definition[at[keep]]
    out$status[keep] <- old$status[at[keep]]; out$note[keep] <- old$note[at[keep]]
    if (any(keep)) message(sum(keep), " of ", nrow(out), " sniglets already have a name in ", basename(file),
                           if (all(keep)) "; nothing left to ask" else paste0("; asking about the other ", sum(!keep)))
  }
  save <- function() if (!is.null(file)) sugWriteTable(out, file)
  # names no suggestion may take: every coined word, the names of the other
  # sniglets, and the names given so far in this table
  given <- function(i) out$name[out$status %in% good & seq_len(nrow(out)) != i]
  taken <- function(i) c(current$sniglet[-todo[i]], current$name[-todo[i]], given(i))
  # the ones worth telling the model about: real names, the newest first (a
  # coined word is not something a model would come up with)
  realNames <- function(i) {
    others <- current$name[-todo[i]]
    unique(c(rev(given(i)), others[others != current$sniglet[-todo[i]]]))
  }
  asked <- FALSE
  for (i in seq_along(todo)) {
    if (out$status[i] %in% good) next
    if (asked && pause > 0) Sys.sleep(pause)
    s <- shown[[i]]
    if (!length(s$examples)) { out$status[i] <- "no crops"; out$note[i] <- "no example crops for this sniglet"; save(); next }
    asked <- TRUE
    pics <- c(s$examples, s$contrast)
    feedback <- NULL; last <- NULL; problem <- NULL
    for (attempt in seq_len(retries + 1)) {
      prompt <- sugPrompt(length(s$examples), length(s$contrast), labels, s$from, realNames(i), maxWords, feedback)
      reply <- tryCatch(model(pics, prompt), error = function(e) e)
      if (inherits(reply, "error")) {
        out$status[i] <- "error"; out$note[i] <- conditionMessage(reply)
        break
      }
      last <- tryCatch(sugParseReply(reply), error = function(e) e)
      if (inherits(last, "error")) {
        problem <- list(kind = "unreadable", why = conditionMessage(last))
        feedback <- "Your previous reply could not be read. Answer with the JSON object only."
        last <- NULL
        next
      }
      problem <- sugNameProblem(last$name, taken(i), banned, maxWords)
      if (is.null(problem)) break
      feedback <- sprintf("Your previous answer \"%s\" cannot be used: %s. Give a different name.", last$name, problem$why)
    }
    if (out$status[i] == "error") { save(); next }
    if (is.null(problem)) {
      out$name[i] <- last$name; out$definition[i] <- last$definition; out$status[i] <- "ok"
    } else if (problem$kind == "taken") {
      n <- 2
      while (sugPlain(paste(last$name, n)) %in% sugPlain(taken(i))) n <- n + 1
      out$name[i] <- paste(last$name, n); out$definition[i] <- last$definition
      out$status[i] <- "suffixed"; out$note[i] <- paste0("\"", last$name, "\" was already taken")
    } else {
      out$status[i] <- "rejected"
      out$note[i] <- if (is.null(last)) problem$why else paste0("\"", last$name, "\": ", problem$why)
    }
    save()
  }
  failed <- !out$status %in% c("ok", "suffixed")
  if (any(failed)) {
    warning(sum(failed), " of ", nrow(out), " sniglets got no usable name and keep the one they had; see `status` and `note`",
            call. = FALSE)
  }
  save()
  out
}

#' A sniglet namer that asks Claude
#'
#' Makes the `model` function [suggestSnigletNames()] needs from the
#' [Anthropic Messages API](https://platform.claude.com/docs/en/api/messages):
#' each call sends one sniglet's crops and the prompt, and returns the text of
#' the reply. Every call is billed to the API key's account; one call is made
#' per sniglet, plus one for every name that has to be asked for again.
#'
#' A rate limit (HTTP 429), an overloaded service (529) or a server or
#' connection error is tried again up to `retries` times, waiting as long as
#' the API asks. Any other error stops that one call with the API's message,
#' which [suggestSnigletNames()] reports for that sniglet before carrying on
#' with the next. So does a reply the model declined to give (stop reason
#' `"refusal"`) and one that ran out of tokens (`"max_tokens"`).
#'
#' @section Images:
#' The API takes JPEG, PNG, GIF and WebP images of at most 5 MB each (as
#' base64; some platforms allow more), and reads small images poorly. With the
#' \pkg{magick} package installed, crops larger than 2000 pixels or 5 MB are
#' scaled down before they are sent and crops smaller than 200 pixels are
#' enlarged. Without it they are sent as they are, and a crop over 5 MB stops
#' that call with a message. A call with more than 100 images is refused, and
#' with many large crops each is scaled down further so that the request stays
#' under the API's 32 MB.
#'
#' @param model The model to ask. It has to accept images.
#' @param apiKey The API key. By default the `ANTHROPIC_API_KEY` environment
#'   variable.
#' @param maxTokens The most tokens a reply may use. Current models think
#'   before they answer and the thinking counts, so leave room for it; only
#'   the tokens actually used are billed.
#' @param effort Optional effort level (`"low"`, `"medium"`, `"high"`, ...)
#'   for models that take one; `"low"` is plenty for naming and costs less. By
#'   default it is not sent and the model's own default applies.
#' @param retries How many times to try again after a rate limit or a server
#'   error.
#' @param timeout Seconds to wait for a reply.
#' @param url The API endpoint.
#' @param fallback `TRUE` to let the API answer with another model when the
#'   one asked declines (its safety classifiers can misjudge a harmless
#'   photo). This sends `fallbacks = "default"` with the beta header
#'   `server-side-fallback-2026-07-01`, which the Anthropic API takes but not
#'   every platform that serves Claude; by default it is not sent and a
#'   declined request is reported on that sniglet's row.
#' @return A function `function(images, prompt)` returning the reply's text.
#' @seealso [suggestSnigletNames()]
#' @examples
#' \dontrun{
#' # needs an API key in ANTHROPIC_API_KEY; the calls are billed to it
#' key <- patchExemplars(vision, key, images)
#' suggestSnigletNames(key, claudeNamer(), file = "names.csv")
#' # ... review names.csv ...
#' key <- renameSniglets(key, "names.csv")
#' }
#' @export
claudeNamer <- function(model = "claude-opus-5-5", apiKey = Sys.getenv("ANTHROPIC_API_KEY"), maxTokens = 16000,
                        effort = NULL, retries = 3, timeout = 120, url = "https://api.anthropic.com/v1/messages",
                        fallback = FALSE) {
  force(model); force(apiKey); force(maxTokens); force(effort); force(retries); force(timeout); force(url); force(fallback)
  if (!is.character(apiKey) || length(apiKey) != 1 || is.na(apiKey) || !nzchar(apiKey)) {
    stop("No API key: set the ANTHROPIC_API_KEY environment variable or give `apiKey`", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install the jsonlite package to use claudeNamer()", call. = FALSE)
  if (!is.character(model) || length(model) != 1 || is.na(model) || !nzchar(model)) stop("`model` must be one model id", call. = FALSE)
  if (!is.numeric(maxTokens) || length(maxTokens) != 1 || is.na(maxTokens) || maxTokens < 1) stop("`maxTokens` must be a positive number", call. = FALSE)
  if (!is.numeric(retries) || length(retries) != 1 || is.na(retries) || retries < 0) stop("`retries` must be 0 or more", call. = FALSE)
  if (!is.null(effort) && (!is.character(effort) || length(effort) != 1 || is.na(effort))) stop("`effort` must be one word, such as \"low\"", call. = FALSE)
  if (!is.logical(fallback) || length(fallback) != 1 || is.na(fallback)) stop("`fallback` must be TRUE or FALSE", call. = FALSE)
  maxTokens <- as.integer(maxTokens)
  function(images, prompt) {
    if (length(images) > sugMaxImages) {
      stop("Anthropic API: ", length(images), " images in one request, and it takes ", sugMaxImages,
           " at most; lower `examples` and `contrast`", call. = FALSE)
    }
    # each image under its own limit, and all of them together under the limit of one request
    images <- lapply(images, sugFitImage, most = min(sugMaxBase64, floor(sugMaxRequest / max(1L, length(images)))))
    content <- c(
      lapply(images, function(im) list(type = "image", source = list(type = "base64", media_type = im$mediaType, data = im$data))),
      list(list(type = "text", text = prompt)))
    body <- list(model = model, max_tokens = maxTokens,
                 messages = list(list(role = "user", content = content)))
    if (!is.null(effort)) body$output_config <- list(effort = effort)
    headers <- c("x-api-key" = apiKey, "anthropic-version" = "2023-06-01", "content-type" = "application/json")
    if (fallback) {                            # a declined request is run again on the model the API recommends
      body$fallbacks <- "default"
      headers <- c(headers, "anthropic-beta" = "server-side-fallback-2026-07-01")
    }
    json <- as.character(jsonlite::toJSON(body, auto_unbox = TRUE))
    for (attempt in seq_len(retries + 1)) {
      r <- tryCatch(sugPost(url, headers, json, timeout),
                    error = function(e) list(status = 0L, text = "", retryAfter = NA_real_, failure = conditionMessage(e)))
      if (r$status >= 200 && r$status < 300) return(sugReplyText(r$text))
      again <- r$status %in% c(0L, 408L, 429L) || r$status >= 500
      what <- if (r$status == 0L) paste0("could not reach the API (", r$failure, ")") else sugApiError(r$status, r$text)
      if (!again || attempt > retries) {
        stop("Anthropic API: ", what, if (again && retries > 0) paste0(", after ", attempt, " tries"), call. = FALSE)
      }
      wait <- suppressWarnings(as.numeric(r$retryAfter))
      if (length(wait) != 1 || is.na(wait) || wait < 0) wait <- 2^attempt
      sugSleep(min(wait, 60))
    }
  }
}

# ---- internals ---------------------------------------------------------------

# One POST to the API. A function of its own so that tests can stand in for
# the network. Returns the status, the body as text and the Retry-After header.
sugPost <- function(url, headers, json, timeout) {
  r <- httr::POST(url, httr::add_headers(.headers = headers), body = json, httr::timeout(timeout))
  after <- httr::headers(r)[["retry-after"]]
  list(status = httr::status_code(r), text = httr::content(r, as = "text", encoding = "UTF-8"),
       retryAfter = if (is.null(after)) NA_real_ else after)
}

# Waiting between tries, also replaceable in tests.
sugSleep <- function(seconds) Sys.sleep(seconds)

# What went wrong, from an error response: "rate_limit_error (HTTP 429): ...".
sugApiError <- function(status, text) {
  err <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE)$error, error = function(e) NULL)
  if (is.list(err) && !is.null(err$message)) return(paste0(err$type, " (HTTP ", status, "): ", err$message))
  paste0("HTTP ", status, if (nzchar(text)) paste0(": ", substr(text, 1, 200)))
}

# The text of a successful Messages API response.
sugReplyText <- function(text) {
  msg <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(msg) || is.null(msg$content)) stop("Anthropic API: the response was not a message", call. = FALSE)
  if (identical(msg$type, "error")) stop("Anthropic API: ", sugApiError(200L, text), call. = FALSE)
  if (identical(msg$stop_reason, "refusal")) {
    category <- if (is.list(msg$stop_details) && is.character(msg$stop_details$category)) msg$stop_details$category[1]
    stop("Anthropic API: the model declined to answer", if (length(category)) paste0(" (", category, ")"), call. = FALSE)
  }
  # a reply cut off by the token limit is half a JSON object at best
  if (identical(msg$stop_reason, "max_tokens")) {
    stop("Anthropic API: the reply ran out of tokens before it was finished, so raise `maxTokens`", call. = FALSE)
  }
  parts <- vapply(msg$content, function(b) if (is.list(b) && identical(b$type, "text") && is.character(b$text)) b$text[1] else "", "")
  reply <- trimws(paste(parts[nzchar(parts)], collapse = "\n"))
  if (!nzchar(reply)) stop("Anthropic API: the reply had no text", call. = FALSE)
  reply
}

# An image for the model, from a file, a data: URI or a base64 string. The
# media type is read from the image's first bytes when they say what it is,
# because an API refuses an image whose declared type is not its real one.
sugImage <- function(x, role) {
  mime <- "image/png"
  if (is.raw(x)) {
    data <- base64enc::base64encode(x)
  } else if (grepl("^data:", x)) {
    mime <- tolower(sub("^data:([^;,]*).*$", "\\1", x))
    data <- sub("^data:[^,]*,", "", x)
  } else if (nchar(x) < 1000 && dir.exists(x)) {
    stop("A crop must be an image file, not a folder: ", x, call. = FALSE)
  } else if (nchar(x) < 1000 && file.exists(x)) {
    mime <- imageMime(x)
    if (is.na(mime)) stop(basename(x), " is not a JPEG, PNG, GIF or WebP image", call. = FALSE)
    data <- base64enc::base64encode(x)
  } else if (nchar(x) < 1000 && grepl("[/\\\\.]", x) && !grepl("^[A-Za-z0-9+/=]+$", x)) {
    stop("Crop file not found: ", x, call. = FALSE)
  } else {
    data <- x
  }
  data <- gsub("\\s", "", data)
  real <- sugSniff(data)
  if (!is.na(real)) mime <- real
  if (!mime %in% sugMediaTypes) stop("A crop is ", mime, "; a model takes JPEG, PNG, GIF and WebP images", call. = FALSE)
  list(data = data, mediaType = mime, role = role)
}

# What a model takes, and the limits of the Anthropic API that claudeNamer()
# keeps to: images per request (the limit of the models with the smallest
# context window), base64 characters per image (5 MB, the lowest limit of any
# platform), and the pixel sizes between which an image is sent as it is (over
# 20 images in a request none may be larger than 2000 pixels, and images under
# 200 pixels are read poorly).
sugMediaTypes <- c("image/jpeg", "image/png", "image/gif", "image/webp")
sugMaxImages <- 100L
sugMaxBase64 <- 5 * 1024^2
sugMaxRequest <- 28 * 1024^2      # a request may be 32 MB in all; the rest is left for the prompt and the JSON around it
sugMaxPixels <- 2000L
sugMinPixels <- 200L

# The media type of base64 image data from its first bytes, or NA.
sugSniff <- function(data) {
  head <- substr(data, 1, 24)
  if (nchar(head) < 24 || !grepl("^[A-Za-z0-9+/]+$", head)) return(NA_character_)
  b <- tryCatch(base64enc::base64decode(head), error = function(e) raw())
  hex <- paste(format(as.hexmode(as.integer(b)), width = 2), collapse = "")
  if (startsWith(hex, "89504e47")) return("image/png")
  if (startsWith(hex, "ffd8ff")) return("image/jpeg")
  if (startsWith(hex, "474946")) return("image/gif")
  if (startsWith(hex, "52494646") && substr(hex, 17, 24) == "57454250") return("image/webp")
  NA_character_
}

# One image made to fit the API: scaled down when it is larger than the API
# takes, and enlarged when it is so small that a model reads it poorly. This
# needs the magick package; without it the image goes as it is, unless it is
# over the size limit, which is an error. Data that is not an image (as in
# tests) is left alone.
sugFitImage <- function(im, most = sugMaxBase64) {
  tooBig <- nchar(im$data) > most
  hasMagick <- requireNamespace("magick", quietly = TRUE)
  mb <- function(chars) sprintf("%.1f MB", chars / 1024^2)
  limit <- if (most < sugMaxBase64) paste0(mb(most), " (a request of this many images may be 32 MB in all)") else "5 MB"
  if (!hasMagick || is.na(sugSniff(im$data))) {
    if (tooBig) stop("Anthropic API: a crop is ", mb(nchar(im$data)), " as base64 and the limit is ", limit,
                     if (!hasMagick) "; install the magick package to have it scaled down, or give smaller crops", call. = FALSE)
    return(im)
  }
  pic <- tryCatch(magick::image_read(base64enc::base64decode(im$data))[1], error = function(e) NULL)
  if (is.null(pic)) {
    if (tooBig) stop("Anthropic API: a crop is ", mb(nchar(im$data)), " as base64, the limit is ", limit, ", and it could not be read to scale it down", call. = FALSE)
    return(im)
  }
  info <- magick::image_info(pic)
  long <- max(info$width, info$height)
  if (!tooBig && long <= sugMaxPixels && long >= sugMinPixels) return(im)
  if (long > sugMaxPixels) pic <- magick::image_scale(pic, paste0(sugMaxPixels, "x", sugMaxPixels))
  if (long < sugMinPixels) {
    to <- 2L * sugMinPixels
    pic <- magick::image_resize(pic, paste0(to, "x", to))
  }
  # small crops stay PNG (lossless); anything that was too heavy becomes a JPEG
  format <- if (tooBig || long > sugMaxPixels) "jpeg" else "png"
  encode <- function(p, quality = 90) {
    if (format == "jpeg") p <- magick::image_background(p, "white", flatten = TRUE)
    base64enc::base64encode(magick::image_write(p, format = format, quality = quality))
  }
  data <- encode(pic)
  side <- sugMaxPixels
  while (nchar(data) > most && side > 250) {
    format <- "jpeg"; side <- side %/% 2L
    pic <- magick::image_scale(pic, paste0(side, "x", side))
    data <- encode(pic, 85)
  }
  if (nchar(data) > most) stop("Anthropic API: a crop could not be brought under the limit of ", limit, call. = FALSE)
  list(data = data, mediaType = paste0("image/", format), role = im$role)
}

# For each coined word in `words`: the example crops, the contrast crops and
# the classes the examples come from.
sugCrops <- function(x, words, vision, images, scores, crops, examples, contrast, size) {
  none <- function() list(examples = list(), contrast = list(), from = character())
  out <- stats::setNames(lapply(words, function(w) none()), words)
  asImages <- function(v, role, n) {
    v <- if (is.raw(v)) list(v) else if (is.list(v)) v else as.list(v)   # one raw image, or several images
    v <- unlist(lapply(v, function(one) if (is.raw(one)) list(one) else as.list(as.character(unlist(one)))), recursive = FALSE)
    v <- v[!vapply(v, function(one) !is.raw(one) && (is.na(one) || !nzchar(trimws(one))), logical(1))]
    lapply(utils::head(v, n), sugImage, role = role)
  }
  isKey <- inherits(x, "dimoose")
  if (isKey) {
    hasPng <- any(vapply(x$features$exemplars, function(e) !is.null(e) && !is.null(e$png), logical(1)))
    if (!hasPng && !is.null(vision) && !is.null(images)) x <- patchExemplars(vision, x$clone(), images, size = size)
    f <- x$features
    emb <- embeddedImages(x$meta)
    for (w in words) {
      j <- match(w, snigletWord(f$id))
      ex <- f$exemplars[[j]]
      if (!is.null(ex) && !is.null(ex$png)) {
        out[[w]]$examples <- asImages(ex$png, "example", examples)
        if (!is.null(ex$label)) out[[w]]$from <- unique(utils::head(ex$label, examples))
      }
      # the crops of this sniglet's "Lacks" leads come from photos without it
      lacks <- which(x$leads$Feature == f$id[j] & x$leads$Test == "<=")
      ids <- unique(trimws(unlist(strsplit(x$leads$Image[lacks], ";", fixed = TRUE))))
      ids <- ids[!is.na(ids) & startsWith(ids, "lead_") & ids %in% names(emb)]
      out[[w]]$contrast <- asImages(unname(emb[ids]), "contrast", contrast)
    }
  } else if (!is.null(vision) && !is.null(images)) {
    s <- asSniglets(x)
    cut <- function(ids, patch) {
      paths <- images$path[match(ids, images$id)]
      ok <- !is.na(paths)
      if (!any(ok)) return(character())
      unlist(vision$mod$exemplar_pngs(vision$py, as.list(paths[ok]), as.list(as.integer(patch[ok]) - 1L), pad = NULL, size = size,
                                      tiles = if (length(s$tiles)) as.list(s$tiles) else NULL))
    }
    for (w in words) {
      ex <- s$exemplars[s$exemplars$sniglet == w, , drop = FALSE]
      ex <- utils::head(ex, examples)
      out[[w]]$examples <- asImages(cut(ex$image, ex$patch), "example", examples)
      out[[w]]$from <- unique(images$label[match(ex$image, images$id)])
      if (!is.null(scores) && !is.null(s$best) && w %in% colnames(scores) && contrast > 0) {
        low <- rownames(scores)[order(scores[, w])]
        low <- utils::head(setdiff(low[low %in% rownames(s$best)], ex$image), contrast)
        out[[w]]$contrast <- asImages(cut(low, s$best[low, w]), "contrast", contrast)
      }
    }
  }
  if (!is.null(crops)) {
    if (is.null(names(crops))) stop("`crops` must be a list named by coined word", call. = FALSE)
    all <- snigletNames(x)
    for (nm in names(crops)) {
      w <- all$sniglet[match(nm, all$sniglet)]
      if (is.na(w)) w <- all$sniglet[match(nm, all$name)]
      if (is.na(w)) stop("`crops` names something that is not a sniglet: ", nm, call. = FALSE)
      if (!w %in% words) next
      given <- crops[[nm]]
      if (!is.list(given)) given <- list(examples = given)
      out[[w]]$examples <- asImages(given$examples, "example", examples)
      out[[w]]$contrast <- asImages(given$contrast, "contrast", contrast)
    }
  }
  unname(out)
}

# Lower-case words and phrases a sniglet name may not contain: each class
# label, and for "Common name (Genus species)" its parts, the genus, and the
# last word of a common name of several words ("aspen" of "Quaking aspen"),
# unless every class ends in that word or it is too general to be a class.
sugBannedWords <- function(labels) {
  labels <- labels[!is.na(labels)]
  if (!length(labels)) return(character())
  sci <- scientificPart(labels)
  common <- ifelse(is.na(sci), NA_character_, trimws(sub("\\s*\\([^()]*\\)$", "", labels)))
  genus <- sub("\\s.*$", "", sci)
  parts <- strsplit(tolower(common[!is.na(common)]), "[^[:alnum:]'-]+")
  last <- vapply(parts, function(p) if (length(p) > 1) p[length(p)] else NA_character_, "")
  last <- last[!is.na(last)]
  if (length(parts) > 1 && length(unique(last)) == 1 && length(last) == length(parts)) last <- character()
  last <- last[nchar(last) >= 3 & !last %in% sugGeneralWords]
  words <- tolower(trimws(c(labels, sci, common, genus, last)))
  unique(words[!is.na(words) & nchar(words) >= 2 & !words %in% c("an", "the")])
}

# Last words of common names that say what kind of thing something is, not
# which: "Monkey flower" does not make "a tubular flower" the name of a class.
sugGeneralWords <- c("tree", "flower", "plant", "grass", "fern", "moss", "lichen", "weed", "bush", "shrub", "vine", "herb",
                     "fish", "bird", "bug", "fly", "leaf", "bark", "berry", "root", "wood", "fruit", "seed", "cone", "mushroom")

# A name as it is compared: lower case, no punctuation, no leading article.
sugPlain <- function(name) {
  p <- trimws(gsub("[^[:alnum:]]+", " ", tolower(name)))
  sub("^(an?|the) +", "", p)
}

# Words in a name, not counting a leading article.
sugWordCount <- function(name) {
  words <- strsplit(trimws(sub("^(an?|the)\\s+", "", trimws(name), ignore.case = TRUE)), "\\s+")[[1]]
  sum(nzchar(words))
}

# Why a suggested name cannot be used (kind and a sentence for the model), or NULL.
sugNameProblem <- function(name, taken, banned, maxWords) {
  plainName <- sugPlain(name)
  if (!grepl("[[:alpha:]]", name) || plainName %in% c("unknown", "unnamed", "none", "null", "na", "n a", "name", "nothing",
                                                       "unclear", "undetermined", "not applicable", "no name") ||
      grepl("^(i|sorry|cannot|unable) ", paste0(plainName, " "))) {      # "I cannot tell", not a name
    return(list(kind = "empty", why = "it is not a name"))
  }
  if (sugWordCount(name) > maxWords) {
    return(list(kind = "long", why = paste0("it has more than ", maxWords, " words")))
  }
  plain <- paste0(" ", gsub("[^[:alnum:]]+", " ", tolower(name)), " ")
  hit <- banned[vapply(banned, function(b) {
    b <- trimws(gsub("[^[:alnum:]]+", " ", b))
    nzchar(b) && any(vapply(paste0(" ", b, c(" ", "s ", "es ")), grepl, logical(1), x = plain, fixed = TRUE))
  }, logical(1))]
  if (length(hit)) {
    return(list(kind = "class", why = paste0("it names a class (", hit[1], ") instead of describing what is visible")))
  }
  if (plainName %in% sugPlain(taken)) return(list(kind = "taken", why = "another feature already has that name"))
  NULL
}

# The names table of a run, read back to carry on from, and written so that
# a half-written file is never left behind.
sugReadTable <- function(file) {
  old <- tryCatch(utils::read.csv(file, stringsAsFactors = FALSE, colClasses = "character", na.strings = character(),
                                  encoding = "UTF-8"),
                  error = function(e) stop("Could not read ", file, " to carry on from: ", conditionMessage(e), call. = FALSE))
  need <- c("sniglet", "name", "status")
  if (!all(need %in% names(old))) {
    stop(basename(file), " is not a table written by suggestSnigletNames(): it has no `", setdiff(need, names(old))[1], "` column", call. = FALSE)
  }
  blank <- function(v) { v <- as.character(v); v[is.na(v)] <- ""; v }
  old$sniglet <- trimws(old$sniglet); old$name <- trimws(blank(old$name)); old$status <- trimws(blank(old$status))
  old$definition <- if (is.null(old$definition)) NA_character_ else ifelse(nzchar(trimws(blank(old$definition))), old$definition, NA_character_)
  old$note <- if (is.null(old$note)) "" else blank(old$note)
  old[!duplicated(old$sniglet), , drop = FALSE]
}

sugWriteTable <- function(out, file) {
  tmp <- paste0(file, ".part")
  utils::write.csv(out, tmp, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  if (!file.rename(tmp, file)) { file.copy(tmp, file, overwrite = TRUE); unlink(tmp) }
  invisible(file)
}

# The request: what the crops are, what a good name is, and the reply format.
sugPrompt <- function(nExamples, nContrast, labels, from, taken, maxWords, feedback = NULL) {
  listed <- function(v, most = 100) paste0(paste(utils::head(v, most), collapse = "; "), if (length(v) > most) "; ...")
  intro <- paste0(
    "These images are small crops cut from photographs by a vision model. ",
    if (nContrast > 0) paste0("The first ", nExamples, if (nExamples == 1) " crop shows" else " crops all show") else
      if (nExamples == 1) "The crop shows" else "All the crops show",
    " one visual feature, which the model uses to tell classes apart in an identification key.",
    if (nContrast > 0) paste0(" The last ", nContrast, if (nContrast == 1) " crop comes" else " crops come",
                              " from photographs in which the model did not find that feature;",
                              if (nContrast == 1) " it is" else " they are", " there for contrast."))
  rules <- c(
    paste0("The name is a noun phrase of one to ", maxWords, " words in lower case that completes \"Has ...\" and \"Lacks ...\", ",
           "for example \"a serrate margin\", \"peeling bark\" or \"round headlights\". ",
           "A leading \"a\", \"an\" or \"the\" does not count as a word."),
    paste0("Describe what is visible: a shape, texture, colour, pattern or part. Where a standard descriptive term exists ",
           "(botanical, zoological or technical), use it."),
    if (length(labels)) paste0("Do not name the species or class the feature is found on. None of these may appear in the name: ",
                               listed(labels), "."),
    if (length(taken)) paste0("These names are already taken by other features; choose a different one: ", listed(taken), "."),
    "The definition is one sentence that says what to look for.")
  paste(c(
    intro,
    if (length(from)) paste0("The example crops come from photographs of: ", listed(from), "."),
    paste0("Name the feature that the ", if (nContrast > 0) "first crops share and the others lack" else "crops share", ", and define it."),
    paste0("- ", rules),
    "Answer with a JSON object only, with no other text: {\"name\": \"...\", \"definition\": \"...\"}",
    feedback), collapse = "\n")
}

# The name and definition in a model's reply. The reply should be a JSON
# object, but models wrap it in code fences or add a sentence, so look for
# the object, and fall back on "Name: ..." lines.
sugParseReply <- function(text) {
  text <- paste(as.character(unlist(text)), collapse = "\n")
  # white space made single, and quotes around the whole of it taken off (but
  # not the closing quote of a definition that ends in a quoted word)
  clean <- function(v) {
    v <- gsub("\\s+", " ", trimws(as.character(v)))
    quote <- c("\"", "'", "`")
    repeat {
      n <- nchar(v); a <- substr(v, 1, 1); z <- substr(v, n, n)
      if (n >= 2 && a %in% quote && a == z) v <- trimws(substr(v, 2, n - 1))
      else if (n >= 1 && a %in% quote && lengths(regmatches(v, gregexpr(a, v, fixed = TRUE))) == 1) v <- trimws(substr(v, 2, n))
      else if (n >= 1 && z %in% quote && lengths(regmatches(v, gregexpr(z, v, fixed = TRUE))) == 1) v <- trimws(substr(v, 1, n - 1))
      else break
    }
    v
  }
  name <- NULL; definition <- NULL
  from <- regexpr("{", text, fixed = TRUE); to <- utils::tail(gregexpr("}", text, fixed = TRUE)[[1]], 1)
  if (from > 0 && to > from) {
    obj <- substr(text, from, to)
    parsed <- if (requireNamespace("jsonlite", quietly = TRUE)) tryCatch(jsonlite::fromJSON(obj, simplifyVector = FALSE), error = function(e) NULL)
    if (is.list(parsed) && length(names(parsed))) {
      names(parsed) <- tolower(names(parsed))
      if (is.character(parsed$name)) name <- parsed$name[1]
      if (is.character(parsed$definition)) definition <- parsed$definition[1]
    }
    field <- function(key) {
      m <- regmatches(obj, regexec(paste0("(?i)\"", key, "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""), obj, perl = TRUE))[[1]]
      # a model may also write the object the way Python prints one, with single quotes
      if (length(m) != 2) m <- regmatches(obj, regexec(paste0("(?i)'", key, "'\\s*:\\s*'((?:[^'\\\\]|\\\\.)*)'"), obj, perl = TRUE))[[1]]
      if (length(m) == 2) gsub("\\\\(.)", "\\1", m[2]) else NULL
    }
    if (is.null(name)) name <- field("name")
    if (is.null(definition)) definition <- field("definition")
  }
  line <- function(key) {
    m <- regmatches(text, regexec(paste0("(?im)^[\\s*_-]*", key, "[\\s*_]*:[\\s*_]*(.+)$"), text, perl = TRUE))[[1]]
    if (length(m) == 2) m[2] else NULL
  }
  if (is.null(name)) name <- line("name")
  if (is.null(definition)) definition <- line("definition")
  name <- if (is.null(name)) "" else sub("[.]+$", "", clean(name))
  # the name completes "Has ..." and "Lacks ...": a model that wrote the verb too gets it taken off
  name <- trimws(sub("^(has|have|having|lacks?|lacking)\\s+", "", name, ignore.case = TRUE))
  if (!nzchar(name)) stop("the reply had no name: ", substr(gsub("\\s+", " ", text), 1, 80), call. = FALSE)
  definition <- if (is.null(definition)) NA_character_ else clean(definition)
  if (!is.na(definition) && !nzchar(definition)) definition <- NA_character_
  list(name = name, definition = definition)
}
