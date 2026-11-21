# A sniglet key with crops, cut by the fake vision model ("PNG1", "PNG2", ...).
sugFixture <- function() {
  fv <- fakeVisionModel(syntheticVision(n_labels = 6, per_label = 3, k = 4, p = 9, d = 8))
  v <- fv$sv
  s <- discoverSniglets(v$patches, k = 4)
  scores <- snigletScores(v$patches, s$centroids)
  key <- keyFromSniglets(scores, v$images, s, method = "rpart")
  key <- patchExemplars(fv$model, key, v$images)
  list(fv = fv, images = v$images, sniglets = s, scores = scores, key = key)
}

# A model that answers from a list of replies, in turn, and records what it was asked.
scriptedModel <- function(replies) {
  seen <- new.env()
  seen$prompts <- character(); seen$images <- list()
  fn <- function(images, prompt) {
    seen$prompts <- c(seen$prompts, prompt)
    seen$images <- c(seen$images, list(images))
    r <- replies[[length(seen$prompts)]]
    if (inherits(r, "condition")) stop(r)
    r
  }
  list(fn = fn, seen = seen)
}

reply <- function(name, definition = "What to look for.") {
  sprintf('{"name": "%s", "definition": "%s"}', name, definition)
}

test_that("suggestions come back as a names table that renameSniglets takes", {
  f <- sugFixture()
  used <- snigletNames(f$key)
  used <- used$sniglet[used$used]
  m <- scriptedModel(lapply(seq_along(used), function(i) reply(paste("texture", letters[i]), paste0("Definition ", i, "."))))
  out <- suggestSnigletNames(f$key, m$fn)
  expect_named(out, c("sniglet", "name", "definition", "status", "note"))
  expect_equal(out$sniglet, used)
  expect_equal(out$name, paste("texture", letters[seq_along(used)]))
  expect_equal(out$definition, paste0("Definition ", seq_along(used), "."))
  expect_true(all(out$status == "ok"))
  expect_length(m$seen$prompts, length(used))                 # one call per sniglet the key uses

  k <- renameSniglets(f$key, out)
  n <- snigletNames(k)
  expect_equal(n$name[match(used, n$sniglet)], out$name)
  expect_equal(n$definition[match(used, n$sniglet)], out$definition)
  expect_true(any(grepl("^Has texture a", k$leads$Character)))
  expect_length(k$validate(), 0)
  expect_equal(snigletNames(f$key)$name, snigletNames(f$key)$sniglet)   # nothing is renamed until you say so
})

test_that("the model sees the example crops first, then the crops of the Lacks leads", {
  f <- sugFixture()
  w <- snigletWord(f$key$leads$Feature[1])
  m <- scriptedModel(list(reply("a ribbed surface")))
  suggestSnigletNames(f$key, m$fn, sniglets = w, examples = 2, contrast = 3)
  pics <- m$seen$images[[1]]
  roles <- vapply(pics, `[[`, "", "role")
  expect_equal(roles[1:2], c("example", "example"))
  expect_true(all(roles[-(1:2)] == "contrast"))
  expect_true(sum(roles == "contrast") >= 1 && sum(roles == "contrast") <= 3)
  expect_true(all(vapply(pics, `[[`, "", "mediaType") == "image/png"))
  ex <- f$key$features$exemplars[[match(paste0("sniglet:", w), f$key$features$id)]]
  expect_equal(vapply(pics[1:2], `[[`, "", "data"), ex$png[1:2])
  p <- m$seen$prompts[1]
  expect_match(p, "The first 2 crops all show one visual feature")
  expect_match(p, "did not find that feature")
  expect_match(p, "one to 3 words")
  expect_match(p, '{"name": "...", "definition": "..."}', fixed = TRUE)
  # the classes are named so that the model can be told not to use them
  expect_match(p, "None of these may appear in the name: .*L1")
  # every coined word is off limits, but a model would not come up with one, so the prompt does not list them
  others <- setdiff(snigletNames(f$key)$sniglet, w)
  expect_false(any(vapply(others, function(x) grepl(x, p, fixed = TRUE), logical(1))))
  m <- scriptedModel(list(reply(others[1]), reply("a ribbed surface")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = w)
  expect_equal(out$name, "a ribbed surface")
  expect_match(m$seen$prompts[2], "another feature already has that name")
})

test_that("a name that is taken is asked for again, then numbered", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])[1:2]
  m <- scriptedModel(list(reply("peeling bark"), reply("Peeling Bark"), reply("a toothed edge")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = used)
  expect_equal(out$name, c("peeling bark", "a toothed edge"))
  expect_equal(out$status, c("ok", "ok"))
  expect_match(m$seen$prompts[2], "already taken by other features.*peeling bark")
  expect_match(m$seen$prompts[3], 'Your previous answer "Peeling Bark" cannot be used: another feature already has that name')

  m <- scriptedModel(list(reply("peeling bark"), reply("peeling bark"), reply("peeling bark", "Bark in strips.")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = used, retries = 1)
  expect_equal(out$name, c("peeling bark", "peeling bark 2"))
  expect_equal(out$status, c("ok", "suffixed"))
  expect_equal(out$definition[2], "Bark in strips.")
  expect_match(out$note[2], "already taken")
  expect_s3_class(renameSniglets(f$key, out), "dimoose")

  # a name another sniglet already has (not in this batch) is taken too
  named <- renameSniglets(f$key, stats::setNames("a waxy bloom", used[1]))
  m <- scriptedModel(list(reply("a waxy bloom"), reply("a matt surface")))
  out <- suggestSnigletNames(named, m$fn, sniglets = used[2])
  expect_equal(out$name, "a matt surface")
})

test_that("class names and long names are refused", {
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  labels <- c("Quaking aspen (Populus tremuloides)", "Paper birch (Betula papyrifera)")
  m <- scriptedModel(list(reply("quaking aspen leaf"), reply("Populus bark"), reply("a white, papery, peeling, curling bark"),
                          reply("a round leaf")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = w, labels = labels, retries = 3)
  expect_equal(out$name, "a round leaf")
  expect_match(m$seen$prompts[2], "it names a class \\(quaking aspen\\)")
  expect_match(m$seen$prompts[3], "it names a class \\(populus\\)")
  expect_match(m$seen$prompts[4], "more than 3 words")

  # still unusable after the retries: the sniglet keeps its name and the row says why
  m <- scriptedModel(list(reply("paper birch"), reply("betula papyrifera")))
  expect_warning(out <- suggestSnigletNames(f$key, m$fn, sniglets = w, labels = labels, retries = 1), "1 of 1 sniglets")
  expect_equal(out$name, w)
  expect_equal(out$status, "rejected")
  expect_match(out$note, "betula papyrifera.*names a class")
  expect_true(is.na(out$definition))

  expect_equal(sugWordCount("a serrate margin"), 2)
  expect_equal(sugWordCount("an egg-crate grille"), 2)
  expect_null(sugNameProblem("a papery bark", character(), sugBannedWords(labels), 3))   # "paper" alone is not a class
  expect_equal(sugNameProblem("birch-like bark", character(), sugBannedWords("birch"), 3)$kind, "class")
})

test_that("an error for one sniglet does not lose the others", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])
  skip_if(length(used) < 3)
  used <- used[1:3]
  named <- renameSniglets(f$key, stats::setNames("an old name", used[2]), definitions = stats::setNames("An old definition.", used[2]))
  m <- scriptedModel(list(reply("a first name"),
                          simpleError("Anthropic API: rate_limit_error (HTTP 429): slow down, after 4 tries"),
                          reply("a third name")))
  expect_warning(out <- suggestSnigletNames(named, m$fn, sniglets = used), "1 of 3 sniglets")
  expect_equal(out$status, c("ok", "error", "ok"))
  expect_match(out$note[2], "HTTP 429")
  expect_equal(out$name, c("a first name", "an old name", "a third name"))
  # the failed sniglet keeps what it had, so the table is safe to apply as it is
  expect_equal(out$definition[2], "An old definition.")
  k <- renameSniglets(named, out)
  n <- snigletNames(k)
  expect_equal(n$name[match(used, n$sniglet)], out$name)
  expect_equal(n$definition[match(used[2], n$sniglet)], "An old definition.")
})

test_that("replies are read defensively", {
  expect_equal(sugParseReply('{"name": "a serrate margin", "definition": "Teeth along the edge."}'),
               list(name = "a serrate margin", definition = "Teeth along the edge."))
  fenced <- "Here you go:\n```json\n{\n  \"Name\": \"  Peeling bark. \",\n  \"definition\": \"Bark that comes off\\nin strips.\"\n}\n```\nHope that helps!"
  expect_equal(sugParseReply(fenced), list(name = "Peeling bark", definition = "Bark that comes off in strips."))
  # broken JSON (a trailing comma) still gives up its fields
  expect_equal(sugParseReply('{"name": "a \\"netted\\" skin", "definition": "A raised net.",}')$name, 'a "netted" skin')
  expect_equal(sugParseReply("**Name:** a dimpled peel\nDefinition: Small pits all over."),
               list(name = "a dimpled peel", definition = "Small pits all over."))
  expect_true(is.na(sugParseReply('{"name": "a keel"}')$definition))
  expect_error(sugParseReply("I cannot tell what these show."), "no name")
  expect_error(sugParseReply('{"name": ""}'), "no name")

  # an unreadable reply is asked for again
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  m <- scriptedModel(list("Sorry, what?", reply("a keel")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = w)
  expect_equal(out$name, "a keel")
  expect_match(m$seen$prompts[2], "could not be read")
  m <- scriptedModel(list("Sorry, what?", "Still nothing"))
  expect_warning(out <- suggestSnigletNames(f$key, m$fn, sniglets = w, retries = 1), "no usable name")
  expect_equal(out$status, "rejected")
  expect_match(out$note, "no name")
})

test_that("the table is written to the spreadsheet renameSniglets reads", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])
  m <- scriptedModel(lapply(seq_along(used), function(i) reply(paste("shape", letters[i]), "Has a comma, and \"quotes\".")))
  csv <- withr::local_tempfile(fileext = ".csv")
  out <- suggestSnigletNames(f$key, m$fn, file = csv)
  back <- utils::read.csv(csv, stringsAsFactors = FALSE)
  expect_equal(names(back), names(out))
  k <- renameSniglets(f$key, csv)
  n <- snigletNames(k)
  expect_equal(n$name[n$used], out$name)
  expect_equal(n$definition[n$used], out$definition)
  expect_equal(renameSniglets(f$key, out)$leads, k$leads)
})

test_that("crops are cut for a sniglet set, with contrast from the photos that match least", {
  f <- sugFixture()
  before <- length(f$fv$calls$exemplar_pngs)
  w <- f$sniglets$sniglets$sniglet[1:2]
  m <- scriptedModel(list(reply("a first name"), reply("a second name")))
  out <- suggestSnigletNames(f$sniglets, m$fn, vision = f$fv$model, images = f$images, scores = f$scores,
                             sniglets = w, examples = 3, contrast = 2)
  expect_equal(out$sniglet, w)
  expect_equal(out$status, c("ok", "ok"))
  calls <- f$fv$calls$exemplar_pngs[-seq_len(before)]
  expect_length(calls, 4)                                     # examples and contrast, for two sniglets
  ex <- f$sniglets$exemplars[f$sniglets$exemplars$sniglet == w[1], ][1:3, ]
  expect_equal(basename(calls[[1]]$paths), paste0(ex$image, ".png"))
  expect_equal(calls[[1]]$patch_indices, ex$patch - 1L)       # zero-based for Python
  low <- names(sort(f$scores[, w[1]]))
  low <- setdiff(low, ex$image)[1:2]
  expect_equal(basename(calls[[2]]$paths), paste0(low, ".png"))
  expect_equal(calls[[2]]$patch_indices, unname(f$sniglets$best[low, w[1]]) - 1L)
  expect_equal(vapply(m$seen$images[[1]], `[[`, "", "role"), c(rep("example", 3), rep("contrast", 2)))
  expect_match(m$seen$prompts[1], "None of these may appear in the name: L1; L2")   # labels of the image set
  s <- renameSniglets(f$sniglets, out)
  expect_equal(snigletNames(s)$name[1:2], c("a first name", "a second name"))

  # without crops there is nothing to show
  expect_error(suggestSnigletNames(f$sniglets, m$fn), "No example crops")
  expect_error(suggestSnigletNames(f$sniglets, "claude"), "must be a function")
  expect_error(suggestSnigletNames(f$sniglets, m$fn, sniglets = "nope"), "Not a sniglet")
})

test_that("your own crops can be files, data URIs or base64", {
  f <- sugFixture()
  w <- f$sniglets$sniglets$sniglet[1:2]
  pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
  crops <- stats::setNames(list(list(examples = pics$path[1], contrast = "data:image/jpeg;base64,QUJD"), "iVBORw0KGgo="), w)
  m <- scriptedModel(list(reply("a first name"), reply("a second name")))
  expect_warning(out <- suggestSnigletNames(f$sniglets, m$fn, crops = crops, sniglets = f$sniglets$sniglets$sniglet[1:3]), "1 of 3")
  expect_equal(out$status, c("ok", "ok", "no crops"))
  one <- m$seen$images[[1]]
  expect_equal(one[[1]]$mediaType, imageMime(pics$path[1]))
  expect_equal(one[[1]]$data, base64enc::base64encode(pics$path[1]))
  expect_equal(one[[2]], list(data = "QUJD", mediaType = "image/jpeg", role = "contrast"))
  expect_equal(m$seen$images[[2]][[1]], list(data = "iVBORw0KGgo=", mediaType = "image/png", role = "example"))
  expect_error(suggestSnigletNames(f$sniglets, m$fn, crops = list(zz = "x")), "not a sniglet")
  expect_error(suggestSnigletNames(f$sniglets, m$fn, crops = stats::setNames(list("no/such/file.png"), w[1])), "not found")
})

# ---- claudeNamer: the request it builds and how it reads the answers. No
# request is ever sent: sugPost() is replaced, and the key is a made-up one.

test_that("claudeNamer builds the Messages API request and returns the reply's text", {
  skip_if_not_installed("jsonlite")
  sent <- list()
  local_mocked_bindings(sugPost = function(url, headers, json, timeout) {
    sent[[length(sent) + 1]] <<- list(url = url, headers = headers, body = jsonlite::fromJSON(json, simplifyVector = FALSE))
    list(status = 200L, retryAfter = NA_real_,
         text = '{"type":"message","stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\\"name\\": \\"a keel\\", \\"definition\\": \\"A ridge.\\"}"}]}')
  })
  namer <- claudeNamer(apiKey = "not-a-real-key")
  images <- list(list(data = "QUJD", mediaType = "image/png", role = "example"),
                 list(data = "REVG", mediaType = "image/jpeg", role = "contrast"))
  expect_equal(namer(images, "Name it."), '{"name": "a keel", "definition": "A ridge."}')
  expect_length(sent, 1)
  s <- sent[[1]]
  expect_equal(s$url, "https://api.anthropic.com/v1/messages")
  expect_equal(s$headers, c("x-api-key" = "not-a-real-key", "anthropic-version" = "2023-06-01", "content-type" = "application/json"))
  expect_equal(s$body$model, "claude-opus-5-5")
  expect_equal(s$body$max_tokens, 16000)
  expect_null(s$body$output_config)
  expect_length(s$body$messages, 1)
  expect_equal(s$body$messages[[1]]$role, "user")
  content <- s$body$messages[[1]]$content
  expect_equal(content[[1]], list(type = "image", source = list(type = "base64", media_type = "image/png", data = "QUJD")))
  expect_equal(content[[2]]$source$media_type, "image/jpeg")
  expect_equal(content[[3]], list(type = "text", text = "Name it."))

  claudeNamer(model = "some-model", apiKey = "not-a-real-key", maxTokens = 500, effort = "low")(images[1], "Again.")
  expect_equal(sent[[2]]$body$model, "some-model")
  expect_equal(sent[[2]]$body$max_tokens, 500)
  expect_equal(sent[[2]]$body$output_config, list(effort = "low"))
  expect_length(sent[[2]]$body$messages[[1]]$content, 2)       # a single image is still a list
})

test_that("claudeNamer waits out rate limits and reports other errors", {
  skip_if_not_installed("jsonlite")
  ok <- list(status = 200L, retryAfter = NA_real_, text = '{"stop_reason":"end_turn","content":[{"type":"text","text":"fine"}]}')
  limited <- list(status = 429L, retryAfter = "7", text = '{"type":"error","error":{"type":"rate_limit_error","message":"Slow down."}}')
  answers <- list(); waits <- numeric(); calls <- 0
  local_mocked_bindings(
    sugPost = function(url, headers, json, timeout) {
      calls <<- calls + 1
      a <- answers[[calls]]
      if (inherits(a, "condition")) stop(a)
      a
    },
    sugSleep = function(seconds) waits <<- c(waits, seconds))
  namer <- claudeNamer(apiKey = "not-a-real-key", retries = 2)
  pics <- list(list(data = "QUJD", mediaType = "image/png", role = "example"))

  answers <- list(limited, list(status = 529L, retryAfter = NA_real_, text = ""), ok)
  expect_equal(namer(pics, "p"), "fine")
  expect_equal(waits, c(7, 4))                                 # Retry-After, then a back-off

  answers <- list(limited, limited, limited); calls <- 0; waits <- numeric()
  expect_error(namer(pics, "p"), "rate_limit_error \\(HTTP 429\\): Slow down., after 3 tries")
  expect_length(waits, 2)

  answers <- list(list(status = 401L, retryAfter = NA_real_,
                       text = '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}')); calls <- 0
  expect_error(namer(pics, "p"), "authentication_error \\(HTTP 401\\): invalid x-api-key$")
  expect_equal(calls, 1)                                       # not tried again

  answers <- list(simpleError("Could not resolve host"), ok); calls <- 0
  expect_equal(namer(pics, "p"), "fine")

  answers <- list(list(status = 200L, retryAfter = NA_real_, text = '{"stop_reason":"refusal","content":[]}')); calls <- 0
  expect_error(namer(pics, "p"), "declined")
  answers <- list(list(status = 200L, retryAfter = NA_real_, text = '{"stop_reason":"max_tokens","content":[{"type":"thinking","thinking":""}]}')); calls <- 0
  expect_error(namer(pics, "p"), "raise `maxTokens`")
  # a refusal says which kind, even when it comes with text; a reply cut off mid-answer is not passed on as if whole
  answers <- list(list(status = 200L, retryAfter = NA_real_,
                       text = '{"stop_reason":"refusal","stop_details":{"type":"refusal","category":"bio"},"content":[{"type":"text","text":"I cannot."}]}')); calls <- 0
  expect_error(namer(pics, "p"), "declined to answer \\(bio\\)")
  answers <- list(list(status = 200L, retryAfter = NA_real_,
                       text = '{"stop_reason":"max_tokens","content":[{"type":"text","text":"{\\"name\\": \\"a keel\\", \\"definition\\": \\"A rid"}]}')); calls <- 0
  expect_error(namer(pics, "p"), "ran out of tokens")
  expect_equal(calls, 1)
  # a Retry-After that is a date or nonsense falls back on the back-off; a long one is capped
  answers <- list(modifyList(limited, list(retryAfter = "Wed, 21 Oct 2026 07:28:00 GMT")), modifyList(limited, list(retryAfter = "3600")), ok)
  calls <- 0; waits <- numeric()
  expect_equal(namer(pics, "p"), "fine")
  expect_equal(waits, c(2, 60))
  expect_error(claudeNamer(apiKey = "not-a-real-key", retries = -1), "retries")
  expect_error(claudeNamer(apiKey = "not-a-real-key", maxTokens = 0), "maxTokens")
  expect_error(claudeNamer(apiKey = NA_character_), "No API key")
  answers <- list(list(status = 200L, retryAfter = NA_real_, text = "<html>proxy</html>")); calls <- 0
  expect_error(namer(pics, "p"), "not a message")
})

test_that("claudeNamer needs a key, and its errors reach the table one sniglet at a time", {
  skip_if_not_installed("jsonlite")
  expect_error(claudeNamer(apiKey = ""), "No API key")
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])[1:2]
  n <- 0
  local_mocked_bindings(
    sugPost = function(url, headers, json, timeout) {
      n <<- n + 1
      if (n == 1) return(list(status = 400L, retryAfter = NA_real_,
                              text = '{"type":"error","error":{"type":"invalid_request_error","message":"image too small"}}'))
      list(status = 200L, retryAfter = NA_real_,
           text = '{"stop_reason":"end_turn","content":[{"type":"text","text":"```json\\n{\\"name\\": \\"a net of veins\\", \\"definition\\": \\"Veins in a mesh.\\"}\\n```"}]}')
    },
    sugSleep = function(seconds) NULL)
  expect_warning(out <- suggestSnigletNames(f$key, claudeNamer(apiKey = "not-a-real-key"), sniglets = used), "1 of 2")
  expect_equal(out$status, c("error", "ok"))
  expect_match(out$note[1], "invalid_request_error \\(HTTP 400\\): image too small")
  expect_equal(out$name[2], "a net of veins")
  expect_equal(out$definition[2], "Veins in a mesh.")
})

# ---- regression tests from the review

test_that("a name that differs only in its article, capitals or punctuation is the same name", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])[1:3]
  m <- scriptedModel(list(reply("a serrate margin"), reply("Serrate margin"), reply("the serrate-margin")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = used, retries = 0)
  expect_equal(out$name, c("a serrate margin", "Serrate margin 2", "the serrate-margin 3"))
  expect_equal(out$status, c("ok", "suffixed", "suffixed"))
  expect_s3_class(renameSniglets(f$key, out), "dimoose")
  expect_equal(sugNameProblem("Peeling  bark!", "a peeling bark", character(), 3)$kind, "taken")
  expect_null(sugNameProblem("peeling bark", "peeling birch bark", character(), 3))
})

test_that("answers that are not names are refused", {
  for (junk in c("unknown", "N/A", "NA", "???", "none", "I cannot determine", "Sorry, unclear", "42")) {
    expect_equal(sugNameProblem(junk, character(), character(), 3)$kind, "empty", info = junk)
  }
  expect_null(sugNameProblem("an inrolled margin", character(), character(), 3))
  expect_null(sugNameProblem("ivory spots", character(), character(), 3))
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  # nothing, NA, a number, a list and a refusal in prose: each is asked for again, none crashes
  m <- scriptedModel(list(NULL, NA, 42, list(a = 1), "I'm sorry, I can't help with that.", character(0), reply("unknown"), reply("a keel")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = w, retries = 7)
  expect_equal(out$name, "a keel")
  expect_match(m$seen$prompts[8], '"unknown" cannot be used: it is not a name')
  expect_equal(sugParseReply("{'name': 'a keel', 'definition': 'A ridge.'}"), list(name = "a keel", definition = "A ridge."))
  expect_equal(sugParseReply('I think {maybe}:\n{"name": "a keel", "definition": "Has {braces}."} and }')$definition, "Has {braces}.")
  expect_equal(sugParseReply('[{"name": "a keel", "definition": "A ridge."}]')$name, "a keel")
})

test_that("the head of a common name, plurals and short labels count as class names", {
  labels <- c("Quaking aspen (Populus tremuloides)", "Paper birch (Betula papyrifera)", "Plains cottonwood (Populus deltoides)")
  banned <- sugBannedWords(labels)
  expect_true(all(c("aspen", "birch", "cottonwood", "populus", "betula", "quaking aspen") %in% banned))
  expect_false(any(c("paper", "quaking", "plains") %in% banned))
  for (bad in c("aspen bark", "birches", "a cottonwood-like leaf", "Populus bark", "quaking aspens")) {
    expect_equal(sugNameProblem(bad, character(), banned, 3)$kind, "class", info = bad)
  }
  expect_null(sugNameProblem("a papery bark", character(), banned, 3))
  expect_null(sugNameProblem("an aspect ratio", character(), banned, 3))          # "aspen" is not in "aspect"
  # a word every class ends in, or a general one, says nothing about which class it is
  expect_false("beetle" %in% sugBannedWords(c("Stag beetle (Lucanus cervus)", "Rose beetle (Cetonia aurata)")))
  expect_false("flower" %in% sugBannedWords(c("Monkey flower (Erythranthe guttata)", "Paper birch (Betula papyrifera)")))
  expect_equal(sugNameProblem("L1 texture", character(), sugBannedWords(c("L1", "L2", NA)), 3)$kind, "class")
  expect_equal(sugBannedWords(c(NA_character_, NA_character_)), character())
  # a leaf that could not separate two classes names both
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  m <- scriptedModel(list(reply("elm bark"), reply("a furrowed surface")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = w, labels = c("oak / elm", "ash"))
  expect_equal(out$name, "a furrowed surface")
  expect_match(m$seen$prompts[2], "names a class \\(elm\\)")
})

test_that("with many sniglets the names already given still reach the model", {
  f <- sugFixture()
  p <- sugPrompt(2, 0, c("A", "B"), "A", c("a waxy bloom", paste("name", 1:70)), 3)
  expect_match(p, "a waxy bloom", fixed = TRUE)
  used <- with(snigletNames(f$key), sniglet[used])[1:2]
  m <- scriptedModel(list(reply("a waxy bloom"), reply("a matt surface")))
  suggestSnigletNames(f$key, m$fn, sniglets = used)
  expect_match(m$seen$prompts[2], "already taken by other features; choose a different one: a waxy bloom.", fixed = TRUE)
  expect_no_match(m$seen$prompts[1], "already taken")
})

test_that("the table is written as it grows, and a stopped run can be carried on", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])
  skip_if(length(used) < 3)
  csv <- withr::local_tempfile(fileext = ".csv")
  # the third call is stopped the way an interrupt stops it: by a condition that is not an R error
  n <- 0
  stopping <- function(images, prompt) {
    n <<- n + 1
    if (n == 2) stop("HTTP 500")
    if (n == 3) stop(structure(class = c("pulledPlug", "condition"), list(message = "stopped from outside", call = NULL)))
    reply("a first name", "First.")
  }
  ended <- tryCatch(suggestSnigletNames(f$key, stopping, file = csv, retries = 0), pulledPlug = function(e) "stopped")
  expect_equal(ended, "stopped")
  half <- utils::read.csv(csv, stringsAsFactors = FALSE)
  expect_equal(half$sniglet, used)
  expect_equal(half$status[1:2], c("ok", "error"))
  expect_equal(half$name[1], "a first name")
  expect_false(file.exists(paste0(csv, ".part")))
  # half a table is still one renameSniglets() takes
  halfNames <- snigletNames(renameSniglets(f$key, csv))
  expect_equal(halfNames$name[match(used, halfNames$sniglet)], c("a first name", used[-1]))

  # carrying on: the sniglet that has a name is not asked about again, and its name is taken
  m <- scriptedModel(c(list(reply("A first name"), reply("a second name", "Second.")),
                       lapply(seq_along(used)[-(1:2)], function(i) reply(paste("shape", letters[i])))))
  expect_message(out <- suggestSnigletNames(f$key, m$fn, file = csv, resume = TRUE), "1 of .* already have a name")
  expect_length(m$seen$prompts, length(used))                 # one retry for the duplicate, none for the first sniglet
  expect_equal(out$name[1:2], c("a first name", "a second name"))
  expect_equal(out$definition[1:2], c("First.", "Second."))
  expect_true(all(out$status == "ok"))
  expect_equal(utils::read.csv(csv, stringsAsFactors = FALSE)$name, out$name)
  # a finished table asks nothing
  none <- scriptedModel(list())
  expect_message(again <- suggestSnigletNames(f$key, none$fn, file = csv, resume = TRUE), "nothing left to ask")
  expect_equal(again, out)
  expect_length(none$seen$prompts, 0)
  # without resume the file is started again; resume needs a file, and one of the right kind
  m <- scriptedModel(lapply(seq_along(used), function(i) reply(paste("texture", letters[i]))))
  expect_equal(suggestSnigletNames(f$key, m$fn, file = csv)$name, paste("texture", letters[seq_along(used)]))
  expect_error(suggestSnigletNames(f$key, m$fn, resume = TRUE), "needs `file`")
  writeLines(c("a,b", "1,2"), csv)
  expect_error(suggestSnigletNames(f$key, m$fn, file = csv, resume = TRUE), "not a table written by suggestSnigletNames")
})

test_that("names and definitions outside ASCII survive the spreadsheet", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])[1:2]
  csv <- withr::local_tempfile(fileext = ".csv")
  m <- scriptedModel(list(reply("a crénate margin", "Zähne — rounded, with a comma"), reply("an ‘eye’ spot")))
  out <- suggestSnigletNames(f$key, m$fn, sniglets = used, file = csv)
  n <- snigletNames(renameSniglets(f$key, csv))
  expect_equal(n$name[match(used, n$sniglet)], c("a crénate margin", "an ‘eye’ spot"))
  expect_equal(n$definition[match(used[1], n$sniglet)], "Zähne — rounded, with a comma")
  again <- suppressMessages(suggestSnigletNames(f$key, scriptedModel(list())$fn, sniglets = used, file = csv, resume = TRUE))
  expect_equal(again$name, out$name)
})

test_that("arguments and crops that make no sense are refused or skipped, not crashed on", {
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  m <- scriptedModel(list(reply("a keel"), reply("a keel")))
  expect_error(suggestSnigletNames(f$key, m$fn, retries = -1), "retries")
  expect_error(suggestSnigletNames(f$key, m$fn, maxWords = 0), "maxWords")
  expect_error(suggestSnigletNames(f$key, m$fn, examples = 0), "examples")
  # a missing or empty crop is left out
  out <- suggestSnigletNames(f$sniglets, m$fn, sniglets = w, crops = stats::setNames(list(c(NA, "", "iVBORw0KGgo=")), w))
  expect_equal(out$status, "ok")
  expect_length(m$seen$images[[1]], 1)
  expect_error(suggestSnigletNames(f$sniglets, m$fn, sniglets = w, crops = stats::setNames(list(tempdir()), w)), "not a folder")
  expect_error(suggestSnigletNames(f$sniglets, m$fn, sniglets = w, crops = stats::setNames(list("data:image/svg+xml;base64,PHN2Zz48L3N2Zz4="), w)),
               "JPEG, PNG, GIF and WebP")
  # a raw vector is one image
  pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
  bytes <- readBin(pics$path[1], "raw", file.size(pics$path[1]))
  suggestSnigletNames(f$sniglets, m$fn, sniglets = w, crops = stats::setNames(list(list(examples = bytes)), w))
  expect_length(m$seen$images[[2]], 1)
  expect_equal(m$seen$images[[2]][[1]]$mediaType, imageMime(pics$path[1]))
})

test_that("the media type sent is the image's real one", {
  skip_if_not_installed("magick")
  pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
  pic <- magick::image_read(pics$path[1])
  as64 <- function(format) base64enc::base64encode(magick::image_write(pic, format = format))
  expect_equal(sugImage(as64("jpeg"), "example")$mediaType, "image/jpeg")
  expect_equal(sugImage(as64("gif"), "example")$mediaType, "image/gif")
  expect_equal(sugImage(as64("webp"), "example")$mediaType, "image/webp")
  expect_equal(sugImage(as64("png"), "example")$mediaType, "image/png")
  # a data URI that says PNG but holds a JPEG would be refused by the API
  expect_equal(sugImage(paste0("data:image/png;base64,", as64("jpeg")), "example")$mediaType, "image/jpeg")
})

test_that("claudeNamer fits images to the API's limits", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("magick")
  sent <- NULL
  local_mocked_bindings(sugPost = function(url, headers, json, timeout) {
    sent <<- jsonlite::fromJSON(json, simplifyVector = FALSE)
    list(status = 200L, retryAfter = NA_real_, text = '{"stop_reason":"end_turn","content":[{"type":"text","text":"fine"}]}')
  })
  namer <- claudeNamer(apiKey = "not-a-real-key")
  size <- function(block) {
    i <- magick::image_info(magick::image_read(base64enc::base64decode(block$source$data)))
    c(i$width, i$height)
  }
  pics <- imageSet(system.file("extdata", "pics", package = "dimoose"))
  small <- magick::image_write(magick::image_scale(magick::image_read(pics$path[1]), "96x96!"), format = "png")
  ok <- magick::image_write(magick::image_scale(magick::image_read(pics$path[1]), "300x300!"), format = "png")
  wide <- magick::image_write(magick::image_scale(magick::image_read(pics$path[1]), "4200x600!"), format = "png")
  namer(list(sugImage(small, "example"), sugImage(ok, "example"), sugImage(wide, "contrast")), "p")
  blocks <- sent$messages[[1]]$content
  expect_true(min(size(blocks[[1]])) >= 200)                   # a 96 px crop is enlarged
  expect_equal(blocks[[1]]$source$media_type, "image/png")
  expect_equal(blocks[[2]]$source$data, base64enc::base64encode(ok))   # one that fits goes untouched
  expect_equal(size(blocks[[3]])[1], 2000)                     # over 2000 px is scaled down, keeping its shape
  expect_true(abs(size(blocks[[3]])[2] - 286) <= 1)
  expect_equal(blocks[[3]]$source$media_type, sugSniff(blocks[[3]]$source$data))

  # over 5 MB as base64: scaled down until it fits
  noise <- withr::with_seed(1, array(stats::runif(1500 * 1400 * 3), c(1500, 1400, 3)))
  big <- sugImage(magick::image_write(magick::image_read(noise), format = "png"), "example")
  expect_gt(nchar(big$data), sugMaxBase64)
  namer(list(big), "p")
  fitted <- sent$messages[[1]]$content[[1]]$source
  expect_lt(nchar(fitted$data), sugMaxBase64)
  expect_equal(fitted$media_type, sugSniff(fitted$data))

  # more images than a request takes: said before anything is sent
  sent <- NULL
  one <- list(data = "QUJD", mediaType = "image/png", role = "example")
  expect_error(namer(rep(list(one), 101), "p"), "101 images in one request")
  expect_null(sent)
  # something that is not an image and too large is an error, not a request the API will refuse
  expect_error(namer(list(list(data = strrep("A", sugMaxBase64 + 4), mediaType = "image/png", role = "example")), "p"), "limit is 5 MB")
  expect_null(sent)
})

test_that("the whole chain runs: build a key, cut crops, ask, write, read back, rename", {
  fv <- fakeVisionModel(syntheticVision(n_labels = 6, per_label = 3, k = 4, p = 9, d = 8))
  v <- fv$sv
  s <- discoverSniglets(v$patches, k = 4)
  key <- keyFromSniglets(snigletScores(v$patches, s$centroids), v$images, s, method = "rpart")
  used <- with(snigletNames(key), sniglet[used])
  csv <- withr::local_tempfile(fileext = ".csv")
  m <- scriptedModel(lapply(seq_along(used), function(i) sprintf("```json\n{\"name\": \"shape %s\", \"definition\": \"Definition %d.\"}\n```", letters[i], i)))
  # the key carries no crops yet: they are cut with the vision model
  out <- suggestSnigletNames(key, m$fn, vision = fv$model, images = v$images, file = csv)
  expect_true(all(out$status == "ok"))
  expect_true(all(lengths(m$seen$images) >= 1))
  expect_equal(unique(unlist(lapply(m$seen$images, function(p) vapply(p, `[[`, "", "role")))), c("example", "contrast"))
  fromTable <- renameSniglets(key, out)
  fromFile <- renameSniglets(key, csv)
  expect_equal(fromTable$leads, fromFile$leads)
  expect_equal(snigletNames(fromFile), snigletNames(fromTable))
  n <- snigletNames(fromFile)
  expect_equal(n$name[n$used], paste("shape", letters[seq_along(used)]))
  expect_equal(n$name[!n$used], n$sniglet[!n$used])            # the ones the key does not ask about keep their coined word
  expect_true(all(grepl("^(Has|Lacks) shape [a-z]", fromFile$leads$Character)))
  expect_length(fromFile$validate(), 0)
  expect_equal(snigletNames(key)$name, snigletNames(key)$sniglet)   # the key given is untouched
})

# ---- regression tests from the second review

test_that("a verb the model added is taken off, and quotes are only taken off in pairs", {
  expect_equal(sugParseReply('{"name": "Has a serrate margin"}')$name, "a serrate margin")
  expect_equal(sugParseReply('{"name": "lacks peeling bark."}')$name, "peeling bark")
  expect_equal(sugParseReply('{"name": "hastate lobes"}')$name, "hastate lobes")             # not the verb
  expect_equal(sugParseReply('{"name": "a keel", "definition": "A ridge, also called a \\"carina\\""}')$definition,
               'A ridge, also called a "carina"')
  expect_equal(sugParseReply('Name: "a keel"\nDefinition: `A ridge.`'), list(name = "a keel", definition = "A ridge."))
  expect_equal(sugParseReply("name: 'a keel")$name, "a keel")                                # a stray quote goes
  f <- sugFixture()
  w <- with(snigletNames(f$key), sniglet[used])[1]
  out <- suggestSnigletNames(f$key, scriptedModel(list(reply("Has a keel")))$fn, sniglets = w)
  expect_equal(out$name, "a keel")
  expect_false(any(grepl("Has has|Lacks has", renameSniglets(f$key, out)$leads$Character)))
})

test_that("a file that cannot be written is found out before the model is asked", {
  f <- sugFixture()
  m <- scriptedModel(list(reply("a keel")))
  expect_error(suggestSnigletNames(f$key, m$fn, file = file.path(tempdir(), "no-such-folder", "names.csv")), "folder of `file` does not exist")
  expect_length(m$seen$prompts, 0)
})

test_that("a resumed file in which two sniglets share a name still gives a table renameSniglets takes", {
  f <- sugFixture()
  used <- with(snigletNames(f$key), sniglet[used])
  skip_if(length(used) < 2)
  csv <- withr::local_tempfile(fileext = ".csv")
  first <- suggestSnigletNames(f$key, scriptedModel(lapply(seq_along(used), function(i) reply(paste("shape", letters[i]))))$fn, file = csv)
  first$name[2] <- "Shape A"                                   # edited by hand into a duplicate of the first
  utils::write.csv(first, csv, row.names = FALSE)
  m <- scriptedModel(list(reply("shape a"), reply("a new shape")))
  out <- suppressMessages(suggestSnigletNames(f$key, m$fn, file = csv, resume = TRUE))
  expect_length(m$seen$prompts, 2)                             # only the second sniglet is asked about, and told the name is taken
  expect_equal(out$name[1:2], c("shape a", "a new shape"))
  expect_s3_class(renameSniglets(f$key, csv), "dimoose")
})

test_that("claudeNamer can ask for a fallback model, and keeps a request of many large crops under 32 MB", {
  skip_if_not_installed("jsonlite")
  sent <- NULL
  local_mocked_bindings(sugPost = function(url, headers, json, timeout) {
    sent <<- list(headers = headers, body = jsonlite::fromJSON(json, simplifyVector = FALSE), size = nchar(json))
    list(status = 200L, retryAfter = NA_real_,
         text = '{"stop_reason":"end_turn","content":[{"type":"fallback"},{"type":"text","text":"fine"}]}')
  })
  pics <- list(list(data = "QUJD", mediaType = "image/png", role = "example"))
  expect_equal(claudeNamer(apiKey = "not-a-real-key", fallback = TRUE)(pics, "p"), "fine")
  expect_equal(sent$body$fallbacks, "default")
  expect_equal(sent$headers[["anthropic-beta"]], "server-side-fallback-2026-07-01")
  claudeNamer(apiKey = "not-a-real-key")(pics, "p")
  expect_null(sent$body$fallbacks)
  expect_false("anthropic-beta" %in% names(sent$headers))
  expect_error(claudeNamer(apiKey = "not-a-real-key", fallback = NA), "fallback")
  expect_error(claudeNamer(apiKey = "not-a-real-key", effort = 3), "effort")

  # eight crops of over 4 MB each fit one by one, but not in one request
  skip_if_not_installed("magick")
  noise <- withr::with_seed(1, array(stats::runif(800 * 700 * 3), c(800, 700, 3)))
  big <- sugImage(magick::image_write(magick::image_read(noise), format = "png"), "example")
  skip_if(nchar(big$data) > sugMaxBase64 || nchar(big$data) * 8 < 32 * 1024^2)
  claudeNamer(apiKey = "not-a-real-key")(rep(list(big), 8), "p")
  expect_lt(sent$size, 32 * 1024^2)
  expect_length(sent$body$messages[[1]]$content, 9)
  claudeNamer(apiKey = "not-a-real-key")(list(big), "p")
  expect_equal(sent$body$messages[[1]]$content[[1]]$source$data, big$data)   # one such crop goes as it is
})
