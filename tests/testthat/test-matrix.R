# Every result a taxon can end at: follows, from the root, each lead that
# accepts one of the taxon's states (all leads if its state is unknown).
resultsFor <- function(leads, states) {
  out <- character()
  todo <- leads$Statement[1]
  done <- character()
  while (length(todo)) {
    at <- todo[1]
    todo <- todo[-1]
    if (at %in% done) next
    done <- c(done, at)
    for (i in which(leads$Statement == at)) {
      mine <- states[[leads$MatrixCharacter[i]]]
      accepted <- strsplit(leads$MatrixStates[i], "/", fixed = TRUE)[[1]]
      if (length(mine) > 0 && !any(mine %in% accepted)) next
      if (leads$Next[i] == "-") out <- c(out, leads$Taxon[i]) else todo <- c(todo, leads$Next[i])
    }
  }
  out
}

expectGuarantee <- function(key, matrix, taxon = "Taxon") {
  m <- genParseMatrix(matrix, taxon)
  for (i in seq_along(m$taxa)) {
    results <- resultsFor(key$leads, lapply(m$states, `[[`, i))
    listed <- vapply(strsplit(results, " / ", fixed = TRUE), function(x) m$taxa[i] %in% x, logical(1))
    expect_gt(length(results), 0)
    expect_true(all(listed), info = m$taxa[i])
  }
}

small <- function() {
  data.frame(
    Taxon = c("A", "B", "C", "D", "E", "F"),
    wings = c("+", "+", "+/-", "-", "-", "-"),
    colour = c("red", "blue", "red/white", "white", "blue", NA),
    spots = c("-", "-", "+", "+/-", "+", "-"),
    stringsAsFactors = FALSE
  )
}

test_that("keyFromMatrix builds a valid key that separates the taxa", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), wings = c("+", "+", "-", "-"), spots = c("+", "-", "+", "-"))
  k <- keyFromMatrix(d, desc = "Four taxa")
  expect_s3_class(k, "dimoose")
  expect_equal(k$desc, "Four taxa")
  expect_length(k$validate(), 0)
  expect_equal(summary(k)$couplets, 3)
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], d$Taxon)
  expect_equal(k$leads$Character[1:2], c("wings: +", "wings: -"))
  expect_equal(k$leads$Question[1], "wings")
  expect_match(exportWizard(k), "wings: +", fixed = TRUE)
})

test_that("a variable taxon is reached down both leads", {
  d <- data.frame(Taxon = c("A", "B", "C"), wings = c("+", "-", "+/-"), spots = c("-", "-", "+"))
  k <- keyFromMatrix(d[c("Taxon", "wings")])
  # wings alone: C cannot be told from A or from B
  expect_setequal(k$leads$Taxon, c("A / C", "B / C"))

  k <- keyFromMatrix(d, characters = data.frame(Character = c("wings", "spots"), Cost = c(1, 100)))
  expect_equal(k$leads$MatrixCharacter[1], "wings")
  expect_equal(sum(k$leads$Taxon == "C"), 2)
  expect_length(k$validate(), 0)
  expectGuarantee(k, d)
})

test_that("every state combination of every taxon ends at that taxon", {
  d <- small()
  k <- keyFromMatrix(d)
  expect_length(k$validate(), 0)
  expectGuarantee(k, d)

  # The same by brute force: each specimen a taxon could be, walked one lead
  # at a time
  m <- genParseMatrix(d)
  all <- lapply(m$states, function(s) unique(unlist(s)))
  for (i in seq_along(m$taxa)) {
    options <- Map(function(mine, any) if (length(mine)) mine else any, lapply(m$states, `[[`, i), all)
    grid <- expand.grid(options, stringsAsFactors = FALSE)
    for (r in seq_len(nrow(grid))) {
      end <- genWalk(k$leads, unlist(grid[r, ]))
      expect_true(m$taxa[i] %in% strsplit(end, " / ", fixed = TRUE)[[1]],
                  info = paste(m$taxa[i], paste(grid[r, ], collapse = " ")))
    }
  }
})

test_that("the guarantee holds for the vibrio matrix", {
  m <- vibrioMatrix()
  expect_equal(dim(m), c(74L, 46L))
  expect_setequal(unlist(m[-1]), c("+", "-", "+/-", NA))
  expect_equal(sum(m[-1] == "+/-", na.rm = TRUE), sum(vibrio[-1] == "v" | vibrio[-1] == "d", na.rm = TRUE))

  k <- vibrioKey()
  expect_length(k$validate(), 0)
  expectGuarantee(k, m)
  # all 74 species are told apart, some at more than one result
  results <- k$leads$Taxon[k$leads$Next == "-"]
  expect_false(any(grepl(" / ", results, fixed = TRUE)))
  expect_setequal(results, vibrio$species)
  expect_gt(length(results), 74)
})

test_that("the rpart route does not give the guarantee, which is why it is not used", {
  m <- vibrioMatrix()
  k <- keyFromMatrix(m, variable = "missing")
  expect_equal(sum(k$leads$Next == "-"), 74)
  variable <- m$Taxon[rowSums(m[-1] == "+/-", na.rm = TRUE) > 0]
  expect_gt(length(variable), 0)
})

test_that("multi-state characters are keyed out one state at a time", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), colour = c("red", "blue", "white", "green"))
  k <- keyFromMatrix(d)
  expect_length(k$validate(), 0)
  expect_equal(summary(k)$couplets, 3)
  expect_true(all(table(k$leads$Statement) == 2))
  expect_equal(k$leads$Character[1:2], c("colour: red", "colour: blue or white or green"))
  expect_equal(k$leads$MatrixStates[2], "blue/white/green")
  expectGuarantee(k, d)

  rp <- keyFromMatrix(d, variable = "missing")
  expect_length(rp$validate(), 0)
  expect_setequal(rp$leads$Taxon[rp$leads$Next == "-"], d$Taxon)
})

test_that("taxa that cannot be separated share a result", {
  d <- data.frame(Taxon = c("A", "B", "C"), wings = c("+", "-", "-"), spots = c("+", "+", "+"))
  for (variable in c("both", "missing")) {
    k <- keyFromMatrix(d, variable = variable)
    expect_setequal(k$leads$Taxon, c("A", "B / C"))
    expect_length(k$validate(), 0)
  }
})

test_that("Cost makes a cheap character come first", {
  d <- data.frame(
    Taxon = c("A", "B", "C", "D"),
    dissect = c("x", "x", "y", "y"),
    leaf = c("x", "x", "y", "y"),
    hair = c("x", "y", "x", "y")
  )
  first <- function(...) keyFromMatrix(d, ...)$leads$MatrixCharacter[1]
  # equally good: the first column wins
  expect_equal(first(), "dissect")
  expect_equal(first(characters = data.frame(Character = c("dissect", "leaf"), Cost = c(5, 1))), "leaf")
  expect_equal(first(characters = data.frame(Character = c("dissect", "leaf", "hair"), Cost = c(5, 2, 1))), "hair")
  expect_equal(keyFromMatrix(d, variable = "missing",
    characters = data.frame(Character = c("dissect", "leaf", "hair"), Cost = c(5, 2, 1)))$leads$Character[1], "hair: x")

  # a 1-against-3 split separates 3 pairs, a 2-against-2 split 4: the uneven
  # one is taken only when it is cheap enough (3 / Cost > 4 / 2)
  d$odd <- c("x", "y", "y", "y")
  costs <- function(odd) data.frame(Character = c("dissect", "leaf", "hair", "odd"), Cost = c(2, 2, 2, odd))
  expect_equal(first(characters = costs(1)), "odd")
  expect_equal(first(characters = costs(1.5)), "dissect")
  expect_error(keyFromMatrix(d, characters = costs(0)), "positive")
})

test_that("season keeps the characters that can be observed", {
  d <- data.frame(
    Taxon = c("A", "B", "C", "D"),
    leaf = c("lobed", "lobed", "entire", "entire"),
    flower = c("white", "pink", "white", "pink"),
    bark = c("smooth", "smooth", "furrowed", "peeling"),
    bud = c("sticky", "dry", "dry", "dry")
  )
  chars <- data.frame(
    Character = c("leaf", "flower", "bark", "bud"),
    Season = c("summer, autumn", "Spring", "", "winter,spring"),
    Needs = c("", "", "", "hand lens")
  )
  winter <- keyFromMatrix(d, characters = chars, season = "winter")
  expect_setequal(winter$leads$MatrixCharacter, c("bark", "bud"))
  expect_equal(unique(winter$leads$Needs[winter$leads$MatrixCharacter == "bud"]), "hand lens")
  expect_setequal(winter$leads$Taxon[winter$leads$Next == "-"], d$Taxon)

  spring <- keyFromMatrix(d, characters = chars, season = "spring")
  expect_true(all(spring$leads$MatrixCharacter %in% c("flower", "bark", "bud")))
  summer <- keyFromMatrix(d, characters = chars, season = c("summer", "winter"), variable = "missing")
  expect_false(any(grepl("flower", summer$leads$Character)))

  # bark alone cannot separate A and B
  barkOnly <- keyFromMatrix(d[names(d) != "bud"], characters = chars, season = "winter")
  expect_true("A / B" %in% barkOnly$leads$Taxon)

  expect_error(keyFromMatrix(d[c("Taxon", "leaf", "flower")], characters = chars, season = "winter"),
               "No character")
  expect_warning(keyFromMatrix(d, season = "winter"), "ignored")
})

test_that("a group of taxa reached by two routes is keyed out once", {
  # C and D are variable for f, so both leads of couplet 1 lead on to them
  d <- data.frame(
    Taxon = c("A", "B", "C", "D"),
    f = c("x", "y", "x/y", "x/y"),
    g = c("2", "2", "1", "1"),
    h = c(NA, NA, "p", "q")
  )
  k <- keyFromMatrix(d, characters = data.frame(Character = c("f", "g", "h"), Cost = c(1, 10, 10)))
  expect_length(k$validate(), 0)
  expectGuarantee(k, d)
  expect_equal(k$leads$MatrixCharacter[1], "f")
  h <- unique(k$leads$Statement[k$leads$MatrixCharacter == "h"])
  expect_length(h, 1)
  expect_equal(sum(k$leads$Next == h), 2)
  expect_equal(summary(k)$couplets, 4)
  expect_match(exportWizard(k), "<svg", fixed = TRUE)
})

test_that("overlapping taxa are separated where a state allows it", {
  k <- keyFromMatrix(data.frame(Taxon = c("A", "B"), wings = c("+", "+/-")))
  expect_equal(k$leads$Character, c("wings: +", "wings: -"))
  expect_equal(k$leads$Taxon, c("A / B", "B"))

  d <- data.frame(Taxon = c("Box elder", "Green ash"), Leaflets = c("3/5", "5/7"))
  k <- keyFromMatrix(d)
  expect_length(k$validate(), 0)
  expect_equal(k$leads$Character, c("Leaflets: 3", "Leaflets: 5 or 7", "Leaflets: 5", "Leaflets: 7"))
  expect_equal(genWalk(k$leads, c(Leaflets = "3")), "Box elder")
  expect_equal(genWalk(k$leads, c(Leaflets = "5")), "Box elder / Green ash")
  expect_equal(genWalk(k$leads, c(Leaflets = "7")), "Green ash")
  expectGuarantee(k, d)

  # an unknown state does not make a couplet: C could be anything
  expect_error(keyFromMatrix(data.frame(Taxon = c("A", "C"), wings = c("+", NA), x = c("1", "1"))),
               "No character separates")
})

test_that("a taxon with an unknown state is reached whatever state it shows", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), colour = c("red", "blue", NA, "green"), z = c("1", "1", "1", "2"))
  k <- keyFromMatrix(d)
  expectGuarantee(k, d)
  for (colour in c("red", "blue", "green")) {
    expect_match(genWalk(k$leads, c(colour = colour, z = "1")), "C", fixed = TRUE)
  }
  expect_equal(genWalk(k$leads, c(colour = "red", z = "1")), "A / C")
  expect_true(is.na(genWalk(k$leads, c(colour = "purple", z = "1"))))
  expect_true(is.na(genWalk(k$leads, c(z = "1"))))
})

test_that("the matrix is read as documented", {
  d <- data.frame(
    species = c("A", "A", "B", "C"),
    wings = c("+", "-", "-", " + "),
    n = c(1, 1, 2, 3),
    blank = c("", NA, "", ""),
    same = "x",
    stringsAsFactors = TRUE
  )
  m <- genParseMatrix(d, "species")
  expect_equal(m$taxa, c("A", "B", "C"))
  expect_equal(m$states$wings, list(c("+", "-"), "-", "+"))
  expect_equal(m$states$n, list("1", "2", "3"))
  expect_equal(genCharacterInfo(m)$Character, c("wings", "n"))

  k <- keyFromMatrix(d, taxon = "species")
  expect_length(k$validate(), 0)
  expectGuarantee(k, d, "species")
})

test_that("keyFromMatrix rejects bad input", {
  d <- data.frame(Taxon = c("A", "B"), wings = c("+", "-"))
  expect_error(keyFromMatrix(list()), "data frame")
  expect_error(keyFromMatrix(d, taxon = "species"), "column")
  expect_error(keyFromMatrix(d["Taxon"]), "no character columns")
  expect_error(keyFromMatrix(d[1, ]), "two taxa")
  expect_error(keyFromMatrix(data.frame(Taxon = c("A", NA), wings = c("+", "-"))), "no taxon name")
  expect_error(keyFromMatrix(d, characters = data.frame(Name = "wings")), "Character")
  expect_error(keyFromMatrix(d, variable = "neither"))
  for (variable in c("both", "missing")) {
    expect_error(keyFromMatrix(data.frame(Taxon = c("A", "B"), wings = c("+", "+"), x = c("+/-", "+/-")),
                               variable = variable), "No character separates")
  }
})

test_that("the documented Montana example works", {
  trees <- data.frame(
    Taxon = c("Box elder", "Green ash", "Rocky Mountain maple", "Bur oak",
              "Quaking aspen", "Paper birch", "Water birch"),
    `Buds and leaves` = c("opposite", "opposite", "opposite", "alternate", "alternate", "alternate", "alternate"),
    `Leaf type` = c("compound", "compound", "simple", "simple", "simple", "simple", "simple"),
    Leaflets = c("3/5", "5/7", NA, NA, NA, NA, NA),
    `Leaf lobes` = c(NA, NA, "lobed", "lobed", "not lobed", "not lobed", "not lobed"),
    Bark = c(NA, NA, NA, NA, "smooth and pale", "white and peeling", "gray to brown"),
    check.names = FALSE
  )
  characters <- data.frame(
    Character = c("Buds and leaves", "Leaf type", "Leaflets", "Leaf lobes", "Bark"),
    Cost = c(2, 1, 1, 1, 1),
    Season = c("", "summer", "summer", "summer", ""),
    Needs = c("a twig in the hand", "", "", "", "")
  )
  k <- keyFromMatrix(trees, characters = characters)
  expect_length(k$validate(), 0)
  expectGuarantee(k, trees)
  # 5 leaflets fits both box elder and green ash, 3 only box elder
  specimen <- c(`Buds and leaves` = "opposite", `Leaf type` = "compound", Leaflets = "5")
  expect_equal(genWalk(k$leads, specimen), "Box elder / Green ash")
  specimen["Leaflets"] <- "3"
  expect_equal(genWalk(k$leads, specimen), "Box elder")

  winter <- keyFromMatrix(trees, characters = characters, season = "winter")
  expect_setequal(winter$leads$MatrixCharacter, c("Buds and leaves", "Bark"))
  expect_length(winter$validate(), 0)
  expectGuarantee(winter, trees)
})

test_that("the guarantee holds on random matrices with variable and unknown cells", {
  withr::local_seed(1)
  built <- 0
  for (r in 1:60) {
    n <- sample(3:8, 1)
    p <- sample(1:4, 1)
    cell <- function() {
      vapply(seq_len(n), function(i) {
        if (stats::runif(1) < 0.15) return(NA_character_)
        paste(sample(c("a", "b", "c"), sample(1:2, 1, prob = c(0.7, 0.3))), collapse = "/")
      }, character(1))
    }
    d <- data.frame(Taxon = paste0("T", seq_len(n)), replicate(p, cell(), simplify = FALSE))
    names(d)[-1] <- paste0("c", seq_len(p))
    costs <- data.frame(Character = names(d)[-1], Cost = sample(1:3, p, replace = TRUE))
    k <- tryCatch(keyFromMatrix(d, characters = costs), error = function(e) {
      if (!grepl("No character separates", conditionMessage(e))) stop(e)
      NULL
    })
    if (is.null(k)) next
    built <- built + 1
    expect_length(k$validate(), 0)
    m <- genParseMatrix(d)
    all <- lapply(m$states, function(s) unique(unlist(s)))
    ok <- TRUE
    for (i in seq_len(n)) {
      options <- Map(function(mine, any) if (length(mine)) mine else any, lapply(m$states, `[[`, i), all)
      grid <- expand.grid(options, stringsAsFactors = FALSE)
      for (q in seq_len(nrow(grid))) {
        end <- genWalk(k$leads, unlist(grid[q, , drop = FALSE]))
        ok <- ok && !is.na(end) && m$taxa[i] %in% strsplit(end, " / ", fixed = TRUE)[[1]]
      }
    }
    expect_true(ok, info = paste("matrix", r))
  }
  expect_gt(built, 50)
})

# ---- review: an independent check of the guarantee ---------------------------

# Follows the key for every specimen a taxon could be, keeping track of the
# states each answer leaves possible. Returns one line per problem: a specimen
# no lead accepts, or a result that does not name the taxon.
routeProblems <- function(key, matrix, taxon = "Taxon") {
  leads <- key$leads
  chars <- setdiff(names(matrix), taxon)
  cell <- function(x) {
    if (is.na(x)) return(character())
    s <- trimws(strsplit(as.character(x), "/", fixed = TRUE)[[1]])
    s[nzchar(s)]
  }
  universe <- lapply(chars, function(ch) unique(unlist(lapply(matrix[[ch]], cell))))
  names(universe) <- chars
  problems <- character()
  for (t in unique(as.character(matrix[[taxon]]))) {
    rows <- which(matrix[[taxon]] == t)
    possible <- lapply(chars, function(ch) {
      s <- unique(unlist(lapply(matrix[[ch]][rows], cell)))
      if (length(s)) s else universe[[ch]]
    })
    names(possible) <- chars
    todo <- list(list(at = leads$Statement[1], possible = possible))
    while (length(todo)) {
      now <- todo[[1]]
      todo <- todo[-1]
      r <- which(leads$Statement == now$at)
      ch <- leads$MatrixCharacter[r[1]]
      accepted <- strsplit(leads$MatrixStates[r], "/", fixed = TRUE)
      mine <- now$possible[[ch]]
      if (!all(mine %in% unlist(accepted))) problems <- c(problems, paste(t, "is stuck at couplet", now$at))
      for (i in seq_along(r)) {
        left <- intersect(mine, accepted[[i]])
        if (length(left) == 0) next
        if (leads$Next[r[i]] == "-") {
          if (!t %in% strsplit(leads$Taxon[r[i]], " / ", fixed = TRUE)[[1]]) {
            problems <- c(problems, paste(t, "ends at", leads$Taxon[r[i]]))
          }
        } else {
          onward <- now$possible
          onward[[ch]] <- left
          todo <- c(todo, list(list(at = leads$Next[r[i]], possible = onward)))
        }
      }
    }
  }
  unique(problems)
}

# Number of couplets that repeat an earlier one lead for lead, sub-keys included
repeatedCouplets <- function(leads) {
  seen <- list()
  text <- function(statement) {
    if (!is.null(seen[[statement]])) return(seen[[statement]])
    r <- which(leads$Statement == statement)
    out <- paste(vapply(r, function(i) {
      paste(leads$Character[i], if (leads$Next[i] == "-") leads$Taxon[i] else paste0("{", text(leads$Next[i]), "}"))
    }, character(1)), collapse = "|")
    seen[[statement]] <<- out
    out
  }
  sum(duplicated(vapply(unique(leads$Statement), text, character(1))))
}

randomMatrix <- function(n, p, states = c("a", "b", "c"), unknown = 0.2) {
  d <- data.frame(Taxon = paste0("T", seq_len(n)), stringsAsFactors = FALSE)
  for (j in seq_len(p)) {
    d[[paste0("c", j)]] <- vapply(seq_len(n), function(i) {
      if (stats::runif(1) < unknown) return(NA_character_)
      paste(sample(states, sample(1:2, 1, prob = c(0.6, 0.4))), collapse = "/")
    }, character(1))
  }
  d
}

test_that("an independent walk finds every specimen at its taxon, and no pair is left together needlessly", {
  expect_length(routeProblems(vibrioKey(), vibrioMatrix()), 0)
  # the checker does find faults: a key that forgets C is variable
  d <- data.frame(Taxon = c("A", "B", "C"), wings = c("+", "-", "+/-"), spots = c("-", "-", "+"))
  wrong <- keyFromLeads(data.frame(
    Statement = c("1", "1", "2", "2"), Choice = c("a", "b"),
    Character = c("wings: +", "wings: -", "spots: -", "spots: +"), Next = c("-", "2", "-", "-"),
    Taxon = c("A", "", "B", "C"), MatrixCharacter = c("wings", "wings", "spots", "spots"),
    MatrixStates = c("+", "-", "-", "+")
  ))
  expect_equal(routeProblems(wrong, d), "C ends at A")
  expect_equal(routeProblems(keyFromMatrix(d), d[c(1, 3, 2), ]), character())
  d$spots[2] <- "?"
  expect_equal(routeProblems(wrong, d), c("B is stuck at couplet 2", "C ends at A"))

  withr::local_seed(42)
  built <- 0
  for (r in 1:150) {
    d <- randomMatrix(sample(2:10, 1), sample(1:5, 1), letters[1:sample(2:5, 1)])
    costs <- data.frame(Character = names(d)[-1], Cost = sample(c(1, 2, 5), ncol(d) - 1, replace = TRUE))
    k <- tryCatch(keyFromMatrix(d, characters = costs), error = function(e) {
      if (!grepl("No character separates", conditionMessage(e))) stop(e)
      NULL
    })
    if (is.null(k)) next
    built <- built + 1
    expect_length(k$validate(), 0)
    expect_length(routeProblems(k, d), 0)
    expect_equal(repeatedCouplets(k$leads), 0, info = paste("matrix", r))
    expect_equal(unique(k$leads$Statement), as.character(seq_len(nrow(k$leads) / 2)))
    # two taxa with no state in common for some character never share a result
    m <- genParseMatrix(d)
    together <- strsplit(k$leads$Taxon[k$leads$Next == "-"], " / ", fixed = TRUE)
    apart <- TRUE
    for (g in together[lengths(together) > 1]) {
      pairs <- utils::combn(match(g, m$taxa), 2)
      for (q in seq_len(ncol(pairs))) for (ch in m$characters) {
        one <- m$states[[ch]][[pairs[1, q]]]
        two <- m$states[[ch]][[pairs[2, q]]]
        if (length(one) && length(two) && !length(intersect(one, two))) apart <- FALSE
      }
    }
    expect_true(apart, info = paste("matrix", r))
  }
  expect_gt(built, 130)
})

test_that("couplets that come out the same are merged and the key renumbered", {
  # couplets for T1 and T3 used to be written twice, once under each route
  d <- data.frame(
    Taxon = c("T1", "T2", "T3", "T4"),
    c1 = c("c/a", "c", "a/c", "a/b"),
    c2 = c(NA, NA, "b/c", "b/a"),
    c3 = c("b", "c", NA, "b/a"),
    c4 = c("a/c", "a", "b/a", "b/c")
  )
  k <- keyFromMatrix(d)
  expect_equal(repeatedCouplets(k$leads), 0)
  expect_equal(unique(k$leads$Statement), as.character(seq_len(nrow(k$leads) / 2)))
  expect_length(k$validate(), 0)
  expect_length(routeProblems(k, d), 0)

  leads <- data.frame(
    Statement = c("1", "1", "2", "2", "3", "3", "4", "4"), Choice = c("a", "b"),
    Character = c("f: x", "f: y", "g: 1", "g: 2", "h: p", "h: q", "h: p", "h: q"),
    Next = c("2", "4", "3", "-", "-", "-", "-", "-"),
    Taxon = c("", "", "", "A", "C", "D", "C", "D"), stringsAsFactors = FALSE
  )
  merged <- genMergeCouplets(leads)
  expect_equal(merged$Statement, c("1", "1", "2", "2", "3", "3"))
  expect_equal(merged$Next, c("2", "3", "3", "-", "-", "-"))
  expect_identical(genMergeCouplets(merged), merged)
})

# ---- review: numbers, text and dependent characters --------------------------

test_that("numbers and ranges are read from their lowest to their highest value", {
  expect_equal(genRange(c("3", "4-6", "(1-)2-8(-12)", "12-13.5-15", " 2.5 - 4 ", ".5", "10–20")),
               rbind(c(3, 3), c(4, 6), c(1, 12), c(12, 15), c(2.5, 4), c(0.5, 0.5), c(10, 20)))
  expect_true(all(is.na(genRange(c("2-3 times pinnate", "many", "+", "-", "", "1e3", "()")))))
})

test_that("overlapping numeric ranges are one state, so the key never sets them against each other", {
  d <- data.frame(
    Taxon = c("A", "B", "C", "D"),
    length = c("13-15", "(10-)15-25(-30)", "12-13.5-15", "40-50"),
    lobes = c("3", "3", "4-6", "5"),
    stringsAsFactors = FALSE
  )
  expect_message(k <- keyFromMatrix(d), "length: overlapping ranges merged, giving the states 10-30, 40-50")
  expect_setequal(k$leads$MatrixStates[k$leads$MatrixCharacter == "length"], c("10-30", "40-50"))
  expect_setequal(k$leads$MatrixStates[k$leads$MatrixCharacter == "lobes"], c("3", "4-6"))
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], c("A / B", "C", "D"))
  expect_length(k$validate(), 0)

  # ranges that all overlap say nothing
  expect_message(expect_error(keyFromMatrix(d[1:3, c("Taxon", "length")]), "No character separates"),
                 "length: not used, its ranges all overlap \\(10-30\\)")
  # ranges that touch overlap: 5 leaflets could be either
  expect_message(expect_error(keyFromMatrix(data.frame(Taxon = c("A", "B"), n = c("3-5", "5-7"))), "No character"),
                 "all overlap \\(3-7\\)")
  # ranges that do not overlap are states as they stand, with no message
  expect_no_message(k <- keyFromMatrix(data.frame(Taxon = c("A", "B", "C"), n = c("(4-)5-6.5", "22-28", "30-45(-60)"))))
  expect_setequal(k$leads$MatrixStates[k$leads$Next == "-"], c("(4-)5-6.5", "22-28", "30-45(-60)"))
  # plain numbers and classes written as text are left alone
  expect_no_message(k <- keyFromMatrix(data.frame(Taxon = c("A", "B"), n = c("3/5", "5/7"))))
  expect_equal(k$leads$Character[1:2], c("n: 3", "n: 5 or 7"))
  expect_no_message(keyFromMatrix(data.frame(Taxon = c("A", "B", "C"), n = c("1-2", "2-3", "many"))))
  # a polymorphic numeric cell takes the state of each alternative
  expect_message(k <- keyFromMatrix(data.frame(Taxon = c("A", "B", "C", "D"), n = c("2.3-7", "10-45", "1.5/3-4", "6"),
                                               z = c("1", "1", "1", "2"))), "1.5, 2.3-7, 10-45")
  expect_true("1.5" %in% k$leads$MatrixStates || "A / C" %in% k$leads$Taxon)
  expect_length(k$validate(), 0)
})

test_that("Type in the characters table decides how a column is read", {
  d <- data.frame(
    Taxon = c("A", "B", "C"),
    stage = c("1-2", "2-3", "4"),
    size = c("1-2", "2-3", "4"),
    notes = c("common", "rare", "possibly two species"),
    wings = c("+", "-", "-"),
    stringsAsFactors = FALSE
  )
  types <- data.frame(Character = c("stage", "size", "notes", "wings"),
                      Type = c("ordered", "real", "text", "categorical"))
  expect_message(k <- keyFromMatrix(d, characters = types), "not used, text: notes")
  expect_false("notes" %in% k$leads$MatrixCharacter)
  # "stage" is a set of named classes, "size" a measurement
  both <- keyFromMatrix(d[c("Taxon", "stage")], characters = types)
  expect_setequal(both$leads$Taxon[both$leads$Next == "-"], c("A", "B", "C"))
  suppressMessages(expect_message(size <- keyFromMatrix(d[c("Taxon", "size")], characters = types), "1-3, 4"))
  expect_setequal(size$leads$Taxon, c("A / B", "C"))
  # a measurement that is not a number is left out, not taken for a state
  types$Type[2] <- "integer"
  d$size[3] <- "large"
  expect_message(k <- keyFromMatrix(d, characters = types), "size: not used, \"large\" is not a number or a range")
  expect_false("size" %in% k$leads$MatrixCharacter)
  expect_error(suppressMessages(keyFromMatrix(d[c("Taxon", "notes")], characters = types)), "no character a key can use")
  # the rpart route reads the matrix the same way
  expect_message(rp <- keyFromMatrix(d, characters = types, variable = "missing"), "not used, text: notes")
  expect_false(any(grepl("notes|size", rp$leads$Character)))
})

test_that("matrices from the TDWG readers give keys that hold", {
  skip_if_not_installed("xml2")
  dir <- system.file("extdata", "tdwg", package = "dimoose")
  read <- list(
    beetles = function() readDELTA(file.path(dir, "beetles-delta")),
    violets = function() readSDD(file.path(dir, "violets.sdd.xml")),
    felids = function() readXper(file.path(dir, "felids-xper3.sdd.xml")),
    bears = function() readLucid(file.path(dir, "bears-lucid.csv")),
    grasses = function() readDELTA(test_path("fixtures", "tdwg", "delta"))
  )
  for (name in names(read)) {
    x <- suppressWarnings(read[[name]]())
    k <- suppressMessages(keyFromMatrix(x$matrix, characters = x$characters))
    expect_length(k$validate(), 0)
    text <- x$characters$Character[x$characters$Type == "text"]
    expect_false(any(k$leads$MatrixCharacter %in% text), info = name)
    # every taxon is at a result, with or without the guarantee
    for (variable in c("both", "missing")) {
      k <- suppressMessages(keyFromMatrix(x$matrix, characters = x$characters, variable = variable))
      results <- unlist(strsplit(k$leads$Taxon[k$leads$Next == "-"], " / ", fixed = TRUE))
      expect_setequal(results, x$matrix$Taxon)
    }
  }
  # no lead sets one overlapping measurement against another
  violets <- read$violets()
  expect_message(k <- keyFromMatrix(violets$matrix, characters = violets$characters),
                 "Flower length: not used, its ranges all overlap \\(10-30\\)")
  expect_false("Flower length" %in% k$leads$MatrixCharacter)
  categorical <- violets$matrix[c("Taxon", "Aerial stem", "Flower colour", "Stem hairs")]
  expect_length(routeProblems(k, categorical), 0)
  # body length separates the beetles, as three ranges that do not overlap
  beetles <- suppressWarnings(read$beetles())
  k <- suppressMessages(keyFromMatrix(beetles$matrix[c("Taxon", "length")], characters = beetles$characters))
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], beetles$matrix$Taxon)
})

test_that("a character is not asked about while it may not apply", {
  d <- data.frame(
    Taxon = c("A", "B", "C", "D", "E", "F"),
    stem = c("absent", "present", "present", "present", "present", "present"),
    hairs = c(NA, "hairy", "hairy", "glabrous", "glabrous", "glabrous"),
    leaf = c("x", "x", "y", "x", "y", "z"),
    stringsAsFactors = FALSE
  )
  # on its own merits "hairs" comes first, and a stemless plant is asked about its stem hairs
  rules <- data.frame(Character = c("stem", "hairs", "leaf"), Cost = c(1, 1, 5), InapplicableIf = c("", "stem=absent", NA))
  expect_equal(keyFromMatrix(d, characters = rules[1:2])$leads$MatrixCharacter[1], "hairs")
  k <- keyFromMatrix(d, characters = rules)
  expect_length(k$validate(), 0)
  expect_length(routeProblems(k, d), 0)
  # the stemless taxon A never arrives at a couplet about stem hairs
  leads <- k$leads
  asked <- character()
  todo <- "1"
  while (length(todo)) {
    here <- which(leads$Statement == todo[1])
    todo <- todo[-1]
    ch <- leads$MatrixCharacter[here[1]]
    asked <- c(asked, ch)
    mine <- list(stem = "absent", leaf = "x")[[ch]]
    for (i in here) {
      if (!is.null(mine) && !mine %in% strsplit(leads$MatrixStates[i], "/", fixed = TRUE)[[1]]) next
      if (leads$Next[i] != "-") todo <- c(todo, leads$Next[i])
    }
  }
  expect_false("hairs" %in% asked)
  expect_true("hairs" %in% leads$MatrixCharacter)
  expect_setequal(leads$Taxon[leads$Next == "-"], d$Taxon)

  # several rules and several states; rules about characters that are not there are skipped
  rules$InapplicableIf[2] <- "flower=none; stem=missing/absent"
  expect_equal(keyFromMatrix(d, characters = rules)$leads, k$leads)
  # when the other character cannot be asked about, the rule gives way
  stuck <- data.frame(Taxon = c("A", "B"), stem = c("absent/present", "absent/present"), hairs = c("hairy", "glabrous"))
  k <- keyFromMatrix(stuck, characters = rules)
  expect_equal(k$leads$Taxon, c("A", "B"))
})

# ---- review: the characters table, seasons and other input -------------------

test_that("Cost and Season are read leniently but not wrongly", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), wings = c("+", "+", "-", "-"), spots = c("+", "-", "+", "-"))
  first <- function(...) keyFromMatrix(d, ...)$leads$MatrixCharacter[1]
  # a blank cost, as read from a spreadsheet, is a missing cost
  expect_equal(first(characters = data.frame(Character = c("wings", "spots"), Cost = c("", "0.5"))), "spots")
  expect_equal(first(characters = data.frame(Character = c("wings", "spots"), Cost = c(NA, 0.5))), "spots")
  expect_equal(first(characters = data.frame(Character = "spots", Cost = 0.5)), "spots")
  for (bad in list(c(Inf, 1), c(-1, 1), c(0, 1), c("cheap", "1"))) {
    expect_error(keyFromMatrix(d, characters = data.frame(Character = c("wings", "spots"), Cost = bad)), "positive")
  }
  expect_warning(keyFromMatrix(d, characters = data.frame(Character = c("Wings", "spot"), Cost = c(5, 1))),
                 "No row of `characters` names a column")
  expect_no_warning(keyFromMatrix(d, characters = data.frame(Character = c("spots", "tail"), Cost = c(5, 1))))
  expect_no_warning(keyFromMatrix(d, characters = data.frame(Character = character(), Cost = numeric())))

  seasons <- data.frame(Character = c("wings", "spots"), Season = c("Summer; autumn", "winter"))
  expect_equal(unique(keyFromMatrix(d, characters = seasons, season = "summer")$leads$MatrixCharacter), "wings")
  expect_equal(unique(keyFromMatrix(d, characters = seasons, season = " WINTER")$leads$MatrixCharacter), "spots")
  expect_error(keyFromMatrix(d, characters = seasons, season = character()), "season names")
  expect_error(keyFromMatrix(d, characters = seasons, season = NA), "season names")
  expect_error(keyFromMatrix(d, characters = seasons, season = "spring"), "No character can be observed")
})

test_that("the matrix may be a character matrix, but its columns must be unambiguous", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), wings = c("+", "+", "-", "-"), spots = c("+", "-", "+", "-"))
  expect_equal(keyFromMatrix(as.matrix(d))$leads, keyFromMatrix(d)$leads)
  expect_error(keyFromMatrix(unname(as.matrix(d))), "data frame")
  twice <- stats::setNames(d, c("Taxon", "wings", "wings"))
  expect_error(keyFromMatrix(twice), "more than one column named: wings")
  nested <- d[1:2, ]
  nested$wings <- list(c("+", "-"), "-")
  expect_error(keyFromMatrix(nested), "one value per row: wings")
  expect_error(keyFromMatrix(d, maxCouplets = 0), "maxCouplets")

  # names and states outside ASCII pass through unchanged
  u <- data.frame(Taxon = c("Broömus", "花", "Zea"), `fleur d'été` = c("bleué", "红", "bleué/红"),
                  x = c("1", "1", "2"), check.names = FALSE)
  k <- keyFromMatrix(u)
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], u$Taxon)
  expect_true("fleur d'été: 红" %in% k$leads$Character)
  expect_length(routeProblems(k, u), 0)
})

# ---- review: size ------------------------------------------------------------

test_that("a key that would explode is given up with advice", {
  # each character is known for two taxa only, so every couplet doubles the key
  n <- 40
  d <- data.frame(Taxon = paste0("T", seq_len(n)), stringsAsFactors = FALSE)
  for (i in 1:20) {
    x <- rep(NA_character_, n)
    x[2 * i - 1] <- "+"
    x[2 * i] <- "-"
    d[[paste0("c", i)]] <- x
  }
  expect_error(keyFromMatrix(d, maxCouplets = 300), "more than 300 couplets.*unknown for most taxa")
  small <- keyFromMatrix(d[1:6, 1:4], maxCouplets = 7)
  expect_equal(summary(small)$couplets, 7)
  expect_error(keyFromMatrix(d[1:6, 1:4], maxCouplets = 6), "more than 6 couplets")
  expect_s3_class(keyFromMatrix(d, variable = "missing"), "dimoose")
})

test_that("unknown cells grow the key but do not blow it up on a matrix of ordinary shape", {
  withr::local_seed(1)
  n <- 120
  d <- data.frame(Taxon = sprintf("T%03d", seq_len(n)), stringsAsFactors = FALSE)
  for (j in 1:40) {
    x <- sample(c("+", "-"), n, replace = TRUE)
    x[stats::runif(n) < 0.3] <- NA
    d[[paste0("c", j)]] <- x
  }
  k <- keyFromMatrix(d)
  expect_lt(summary(k)$couplets, 5 * n)
  expect_length(k$validate(), 0)
  expect_length(routeProblems(k, d), 0)
})

test_that("many taxa and a long chain of couplets are handled", {
  # 2500 taxa: the name of a sub-key used to be too long for R; taxa with the
  # same states share a result
  withr::local_seed(3)
  n <- 2500
  d <- data.frame(Taxon = paste0("T", seq_len(n)), stringsAsFactors = FALSE)
  for (j in 1:6) d[[paste0("c", j)]] <- sample(c("a", "b", "c"), n, replace = TRUE)
  leads <- genPartition(genParseMatrix(d), genCharacterInfo(genParseMatrix(d)))
  expect_setequal(unlist(strsplit(leads$Taxon[leads$Next == "-"], " / ", fixed = TRUE)), d$Taxon)

  # one character with 300 states gives a key 299 couplets deep
  chain <- data.frame(Taxon = paste0("T", 1:300), state = paste0("s", 1:300))
  leads <- genPartition(genParseMatrix(chain), genCharacterInfo(genParseMatrix(chain)))
  expect_equal(nrow(leads), 598)
  expect_equal(leads$Next[seq(2, 596, by = 2)], as.character(2:299))
})

# ---- review: the rpart route --------------------------------------------------

test_that("variable = \"missing\" loses no taxon", {
  # rpart leaves A at the first split: its state for w is variable, and z,
  # the only surrogate, is unknown for B
  d <- data.frame(Taxon = c("A", "B", "C"), w = c("a/b", "a", "b"), z = c("1", "1/2", "2"))
  k <- keyFromMatrix(d, variable = "missing")
  expect_equal(k$leads$Taxon, c("A / B", "A / C"))
  expect_length(k$validate(), 0)

  withr::local_seed(11)
  for (r in 1:60) {
    d <- randomMatrix(sample(3:9, 1), sample(1:4, 1), unknown = 0.3)
    k <- tryCatch(keyFromMatrix(d, variable = "missing"), error = function(e) {
      if (!grepl("No character separates", conditionMessage(e))) stop(e)
      NULL
    })
    if (is.null(k)) next
    expect_setequal(unlist(strsplit(k$leads$Taxon[k$leads$Next == "-"], " / ", fixed = TRUE)), d$Taxon)
  }
})

test_that("variable = \"missing\" copes with awkward character names and states", {
  d <- data.frame(Taxon = c("A", "B", "C"), `Taxon..response` = c("a", "a", "b"), `pH >= 7 (test)` = c("x=1", "y", "y"),
                  check.names = FALSE)
  k <- keyFromMatrix(d, variable = "missing")
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], d$Taxon)
  expect_true(all(c("Taxon..response: a", "pH >= 7 (test): x=1") %in% k$leads$Character))
  names(d)[2] <- "a`b"
  expect_error(keyFromMatrix(d, variable = "missing"), "backtick")
  expect_s3_class(keyFromMatrix(d), "dimoose")
})

# ---- second review -----------------------------------------------------------

# A specimen of taxon `i` shows one of the taxon's states for each character
# (any state of the character if the taxon's is unknown). Follows the key by
# the text of its leads alone and returns the result, or a note on where no
# lead fitted.
followText <- function(leads, specimen) {
  at <- leads$Statement[1]
  repeat {
    rows <- which(leads$Statement == at)
    text <- leads$Character[rows]
    named <- names(specimen)[vapply(names(specimen), function(ch) all(startsWith(text, paste0(ch, ": "))), logical(1))]
    if (length(rows) != 2 || length(named) == 0) return(paste("no character at couplet", at))
    ch <- named[which.max(nchar(named))]
    first <- substring(text[1], nchar(ch) + 3)
    rest <- strsplit(substring(text[2], nchar(ch) + 3), " or ", fixed = TRUE)[[1]]
    lead <- if (specimen[[ch]] == first) rows[1] else if (specimen[[ch]] %in% rest) rows[2] else NA
    if (is.na(lead)) return(paste("no lead at couplet", at))
    if (leads$Next[lead] == "-") return(leads$Taxon[lead])
    at <- leads$Next[lead]
  }
}

test_that("random specimens, followed by the wording of the leads, end at their taxon", {
  withr::local_seed(20261119)
  wrong <- character()
  for (run in 1:60) {
    n <- sample(3:9, 1)
    d <- data.frame(Taxon = paste0("T", seq_len(n)), stringsAsFactors = FALSE)
    for (j in seq_len(sample(2:6, 1))) {
      states <- letters[seq_len(sample(2:5, 1))]
      d[[paste0("c", j)]] <- vapply(seq_len(n), function(i) {
        u <- stats::runif(1)
        if (u < 0.3) NA_character_ else if (u < 0.5) paste(sample(states, 2), collapse = "/") else sample(states, 1)
      }, character(1))
    }
    k <- tryCatch(keyFromMatrix(d), error = function(e) NULL)
    if (is.null(k)) next
    cells <- lapply(d[-1], function(x) strsplit(x, "/", fixed = TRUE))
    all <- lapply(cells, function(x) unique(stats::na.omit(unlist(x))))
    for (i in seq_len(n)) for (rep in 1:10) {
      specimen <- lapply(names(cells), function(ch) {
        mine <- cells[[ch]][[i]]
        if (anyNA(mine)) mine <- all[[ch]]
        if (length(mine) == 0) "?" else mine[sample.int(length(mine), 1)]
      })
      names(specimen) <- names(cells)
      end <- followText(k$leads, specimen)
      if (!d$Taxon[i] %in% strsplit(end, " / ", fixed = TRUE)[[1]]) wrong <- c(wrong, paste(run, d$Taxon[i], end))
    }
  }
  expect_equal(wrong, character())
})

test_that("ranges with the same unit in every cell are read as numbers", {
  d <- data.frame(Taxon = c("A", "B", "C", "D"), len = c("2-8 mm", "5-12mm", "20-30 mm", "25 mm"),
                  w = c("1", "2", "1", "2"))
  expect_message(k <- keyFromMatrix(d), "len: overlapping ranges merged, giving the states 2-12 mm, 20-30 mm")
  # A and B overlap in length, so no couplet sets "2-8 mm" against "5-12mm"
  expect_setequal(unique(k$leads$Character[k$leads$MatrixCharacter == "len"]), c("len: 2-12 mm", "len: 20-30 mm"))
  expect_setequal(k$leads$Taxon[k$leads$Next == "-"], d$Taxon)
  # so does a typed column, which used to be left out as "not a number"
  expect_message(typed <- keyFromMatrix(d, characters = data.frame(Character = "len", Type = "real")), "2-12 mm")
  expect_true("len" %in% typed$leads$MatrixCharacter)
  # different units, or words, are states as before
  mixed <- data.frame(Taxon = c("A", "B", "C"), len = c("2-8 mm", "1-2 cm", "20-30 mm"),
                      frond = c("once pinnate", "2-3 times pinnate", "4 times pinnate"))
  expect_no_message(k <- keyFromMatrix(mixed))
  expect_true("len: 1-2 cm" %in% k$leads$Character)
  expect_equal(genUnit(c("30\u00b0", "40-50 \u00b0"))$unit, "\u00b0")
  expect_null(genUnit(c("3", "5 mm")))
  expect_null(genUnit(c("1e3", "2e3")))
})

test_that("the characters table is matched by whole column names and warns about repeated rows", {
  d <- data.frame(Taxon = c("A", "B", "C"), a = c("x", "y", "y"), b = c("p", "p", "q"))
  first <- function(...) keyFromMatrix(d, ...)$leads$MatrixCharacter[1]
  # `Costly` is not `Cost` (data frames match `$` names by their start)
  expect_equal(first(characters = data.frame(Character = c("a", "b"), Costly = c(5, 1))), "a")
  expect_no_warning(keyFromMatrix(d, characters = data.frame(Character = c("a", "b"), Seasonal = c("x", "y"))))
  expect_warning(k <- keyFromMatrix(d, characters = data.frame(Character = c("a", "a", "b"), Cost = c(5, 1, 2))),
                 "more than one row for: a")
  expect_equal(k$leads$MatrixCharacter[1], "b")
})

test_that("Season takes a slash as a separator and 'all year' as always", {
  d <- data.frame(Taxon = c("A", "B", "C"), a = c("x", "y", "y"), b = c("p", "p", "q"))
  used <- function(Season) {
    unique(keyFromMatrix(d, characters = data.frame(Character = c("a", "b"), Season = Season),
                         season = "winter")$leads$MatrixCharacter)
  }
  expect_equal(used(c("summer/winter", "summer")), "a")
  expect_equal(used(c("summer", "All year")), "b")
  expect_setequal(used(c("always", NA)), c("a", "b"))
})

test_that("a key with more than ten couplets per taxon comes with a warning", {
  withr::local_seed(1)
  n <- 40
  d <- data.frame(Taxon = paste0("T", seq_len(n)), stringsAsFactors = FALSE)
  for (j in 1:30) {
    x <- sample(c("+", "-"), n, replace = TRUE)
    x[stats::runif(n) < 0.65] <- NA
    d[[paste0("c", j)]] <- x
  }
  expect_warning(k <- keyFromMatrix(d), "couplets for 40 taxa.*unknown for most taxa")
  expect_gt(summary(k)$couplets, 10 * n)
  expect_no_warning(keyFromMatrix(vibrioMatrix()))
})

test_that("variable = \"missing\" says when taxa could not be placed", {
  bears <- data.frame(
    Taxon = c("Ursus arctos", "Ursus maritimus", "Ursus americanus", "Ailuropoda melanoleuca"),
    Colour = c("brown", "white", "brown/black", "white/black"),
    Hump = c("present", "absent", "absent", "absent"),
    Diet = c("mixed/mostly plants", "mostly meat", "mixed", "mostly plants")
  )
  expect_message(k <- keyFromMatrix(bears, variable = "missing"), "2 taxa could not be placed")
  expect_true(all(grepl("Ursus americanus", k$leads$Taxon[k$leads$Next == "-"])))
  expect_no_message(keyFromMatrix(vibrioMatrix(), variable = "missing"))
  both <- keyFromMatrix(bears)
  expect_setequal(both$leads$Taxon[both$leads$Next == "-"], bears$Taxon)
})
