#' Build a dimoose key from a character matrix
#'
#' Generates a dichotomous key from a taxon-by-character matrix, the form most
#' identification data is kept in (DELTA, Lucid, SDD, a spreadsheet of test
#' results). Unlike a classification tree, the key is built the way a person
#' writes one: a taxon that is variable for a character is keyed out down both
#' leads of every couplet that uses the character.
#'
#' @section The matrix:
#' A plain data frame (or a character matrix with column names) with one row
#' per taxon: a taxon column and one column per character. Cells are state
#' strings (anything else is converted with `as.character()`). A taxon that
#' is variable (polymorphic) for a character lists its states separated by
#' `/`, e.g. `"+/-"` or `"red/white"`. `NA` or an empty cell means unknown or
#' inapplicable. If a taxon has several rows, they are merged and the taxon
#' takes every state seen in any of them. Characters with fewer than two
#' states among the taxa are dropped. Every column other than `taxon` is taken
#' as a character, so leave out columns of notes.
#'
#' @section Numbers and ranges:
#' A key can only ask about states a specimen either shows or does not, so a
#' measurement is used through the ranges that do not overlap. In a column
#' whose cells are all numbers or ranges, as the readers [readDELTA()],
#' [readSDD()], [readLucid()] and [readXper()] write them (`"3"`, `"4-6"`,
#' `"(1-)2-8(-12)"`, taken from the lowest to the highest number in the
#' cell), ranges that overlap or touch are merged into one state named by its
#' extremes: `"3-5"`, `"5-7"` and `"12-20"` give the two states `"3-7"` and
#' `"12-20"`. A character whose ranges all overlap has one state and is
#' dropped. A message says what was merged or dropped. The cells may end in a
#' unit if it is the same in every cell of the column (`"2-8 mm"`,
#' `"5-12 mm"`). Negative numbers are
#' not understood (a `-` is read as "to"). To key a taxon out on part of an
#' overlapping range, cut the measurement into classes yourself and enter the
#' classes as states (`"3/5"` and `"5/7"` leaflets in the example below).
#'
#' If `characters` has a column `Type`, as the tables of those readers do,
#' characters of type `"text"` are not used, the rule above applies to
#' `"integer"` and `"real"` characters only, and `"categorical"` and
#' `"ordered"` characters are always taken as states.
#'
#' @section How the key is built (`variable = "both"`):
#' Every couplet tests one state of one character against the rest: the first
#' lead reads `"Character: state"`, the second `"Character: other or
#' another"`, naming the other states the taxa still in play may show. A
#' character with three or more states is therefore keyed out over several
#' couplets, and every couplet has exactly two leads.
#'
#' A taxon follows the first lead if it can show the state and the second if
#' it can show any other state not already ruled out, so a variable taxon
#' follows both. So does a taxon whose state is unknown (`NA`), since it
#' cannot be ruled out on either side. The guarantee is: whichever of its
#' states a specimen shows for each character, following the key ends at a
#' result that names its taxon.
#'
#' At each step the couplet is chosen like this. For every state of every
#' character, count the taxa that follow the first lead only (`a`) and the
#' second lead only (`b`). The couplet separates `a * b` pairs of taxa; taxa
#' that follow both leads separate nothing. The split with the largest
#' `a * b / Cost` is taken; ties go to the character that comes first in the
#' matrix, then to the state that appears first in its column. With no
#' `Cost`, every character costs 1. A character with `Cost` 2 is thus chosen
#' over one with `Cost` 1 only if it separates more than twice as many pairs.
#'
#' If no split separates a pair, the taxa that are left overlap: one shows
#' `"+"` and another `"+/-"`, or one has 3 to 5 leaflets and another 5 to 7.
#' A couplet can still rule taxa out on one side (`"-"` can only be the
#' second taxon), so the split with the largest `(a + b) / Cost` is taken,
#' provided some taxon is known to show the state and some taxon is known to
#' show another. When no such split is left either, the remaining taxa share
#' a result, written `"A / B"`: with the states observed they cannot be told
#' apart.
#'
#' A group of taxa that is reached by several routes with the same states
#' still open is keyed out once, and couplets that come out the same lead for
#' lead are merged, so a couplet may be the target of more than one lead, and
#' a variable taxon appears at more than one result.
#'
#' If `characters` has a column `InapplicableIf` (`"Other character=state"`
#' or `"Other character=state/state"`, several rules separated by `;`, as
#' written by [readSDD()] and [readDELTA()]), a character is not asked about
#' while a taxon still in play may show one of those states of the other
#' character: the key asks whether there is an aerial stem before it asks
#' whether the stem is hairy. The rule is dropped where it would leave no
#' couplet at all.
#'
#' @section Size of the key:
#' Because variable and unknown taxa follow both leads, the key grows with
#' the number of such cells. Random two-state matrices of 200 taxa and 60
#' characters gave 199 couplets with no unknown cells, about 550 with 30%
#' unknown and about 3400 with 50%. A matrix in which most characters are
#' known for only a few taxa can need a number of couplets that doubles with
#' every character; `maxCouplets` stops such a key with an error rather than
#' running out of memory, and a key with more than ten couplets per taxon
#' comes with a warning. Leave out the characters that are unknown for most
#' taxa, or use `variable = "missing"`.
#'
#' @section `variable = "missing"`:
#' Variable cells are treated as unknown and the key is the classification
#' tree fitted by [rpart::rpart()] (through [keyFromRpart()]), with `Cost`
#' passed as rpart's `cost`. Each taxon then appears at one result, but rpart
#' places a taxon it has no state for with surrogate splits, so a specimen
#' showing the taxon's other state is keyed out wrongly. A taxon rpart cannot
#' place at a split at all is listed at every result below that split (a
#' message says how many such taxa there are). The
#' key is smaller; use it when that matters more than the guarantee above. A
#' lead may name several states (`"Colour: red,white"`). `InapplicableIf` is
#' not used.
#'
#' @param matrix A character matrix: a data frame with one row per taxon (see
#'   'The matrix'), e.g. the `matrix` of [readDELTA()] or [readSDD()].
#' @param taxon Name of the column holding the taxon names.
#' @param characters Optional data frame of character metadata with a column
#'   `Character` (matching column names of `matrix`) and any of `Cost`
#'   (positive number, lower means easier to observe; missing or blank means
#'   1), `Season` (seasons or conditions in which the character can be
#'   observed, separated by `,`, `;` or `/`; blank, `"all"`, `"all year"` or
#'   `"always"` means always), `Needs` (free
#'   text such as `"hand lens"`, copied to the leads), `Type` (see 'Numbers
#'   and ranges') and `InapplicableIf` (see 'How the key is built'). The
#'   `characters` table of [readDELTA()], [readSDD()], [readLucid()] or
#'   [readXper()] can be passed as it is. Characters not listed cost 1 and
#'   can always be observed; rows for characters that are not in `matrix` are
#'   ignored (with a warning if no row matches). If a character has several
#'   rows the first is used, with a warning.
#' @param season Optional character vector. Only characters whose `Season` is
#'   blank or includes one of these (ignoring case) are used, e.g.
#'   `season = "winter"` for a bark and twig key.
#' @param variable `"both"` (default) sends a variable taxon down both leads;
#'   `"missing"` treats variable cells as unknown and fits a classification
#'   tree.
#' @param desc Title of the key.
#' @param meta Key/value metadata data frame.
#' @param maxCouplets For `variable = "both"`: give up with an error once the
#'   key has more couplets than this (see 'Size of the key').
#' @return A [dimoose] object. With `variable = "both"` its leads also carry
#'   `Question` (the character's name), `MatrixCharacter` and `MatrixStates`
#'   (the character and the `/`-separated states the lead accepts) and, if
#'   `characters` has it, `Needs`.
#' @seealso [vibrioKey()], [vibrioMatrix()], [keyFromRpart()], [generateTree()]
#' @examples
#' # Some of Montana's broadleaf trees (see montanaKey() for the key written
#' # by hand). Box elder has 3 to 5 leaflets and green ash 5 to 7, so a leaf
#' # with 5 could be either.
#' trees <- data.frame(
#'   Taxon = c("Box elder", "Green ash", "Rocky Mountain maple", "Bur oak",
#'             "Quaking aspen", "Paper birch", "Water birch"),
#'   `Buds and leaves` = c("opposite", "opposite", "opposite", "alternate",
#'                         "alternate", "alternate", "alternate"),
#'   `Leaf type` = c("compound", "compound", "simple", "simple", "simple",
#'                   "simple", "simple"),
#'   Leaflets = c("3/5", "5/7", NA, NA, NA, NA, NA),
#'   `Leaf lobes` = c(NA, NA, "lobed", "lobed", "not lobed", "not lobed",
#'                    "not lobed"),
#'   Bark = c(NA, NA, NA, NA, "smooth and pale", "white and peeling",
#'            "gray to brown"),
#'   check.names = FALSE
#' )
#' k <- keyFromMatrix(trees, desc = "Some Montana trees")
#' k$leads[c("Statement", "Choice", "Character", "Next", "Taxon")]
#'
#' # Leaves are easy to see but only there in summer; bud arrangement needs a
#' # closer look but works all year
#' characters <- data.frame(
#'   Character = c("Buds and leaves", "Leaf type", "Leaflets", "Leaf lobes", "Bark"),
#'   Cost = c(2, 1, 1, 1, 1),
#'   Season = c("", "summer", "summer", "summer", ""),
#'   Needs = c("a twig in the hand", "", "", "", "")
#' )
#' keyFromMatrix(trees, characters = characters)$leads$Character
#'
#' # A winter key: what bark and buds cannot separate shares a result
#' winter <- keyFromMatrix(trees, characters = characters, season = "winter")
#' winter$leads[c("Character", "Taxon")]
#'
#' # A matrix read from a DELTA data set, with its character table. Body
#' # length is used because the three ranges do not overlap; the comments are
#' # text and are left out.
#' beetles <- readDELTA(system.file("extdata", "tdwg", "beetles-delta", package = "dimoose"))
#' keyFromMatrix(beetles$matrix, characters = beetles$characters)$leads[c("Character", "Taxon")]
#' @export
keyFromMatrix <- function(matrix, taxon = "Taxon", characters = NULL, season = NULL,
                          variable = c("both", "missing"),
                          desc = "Key generated from a character matrix", meta = NULL,
                          maxCouplets = 10000) {
  variable <- match.arg(variable)
  if (!is.numeric(maxCouplets) || length(maxCouplets) != 1 || is.na(maxCouplets) || maxCouplets < 1) {
    stop("`maxCouplets` must be a positive number", call. = FALSE)
  }
  if (!is.null(characters) && (!is.data.frame(characters) || !"Character" %in% names(characters))) {
    stop("`characters` must be a data frame with a column `Character`", call. = FALSE)
  }
  m <- genParseMatrix(matrix, taxon)
  m <- genTypedStates(m, characters)
  info <- genCharacterInfo(m, characters, season)
  if (variable == "missing") {
    return(genRpartKey(m, info, desc, meta))
  }
  keyFromLeads(genPartition(m, info, maxCouplets), desc, meta)
}

#' The vibrio dataset as a character matrix
#'
#' Recodes the [vibrio] consensus matrix of Noguerola & Blanch (2008) into the
#' character matrix [keyFromMatrix()] takes: `+` and `(+)` (mostly positive)
#' become `"+"`, `-` and `(-)` become `"-"`, the variable results `v` and `d`
#' become `"+/-"`, and `ND` (not determined) and the one blank cell become
#' `NA`.
#'
#' @return A data frame with 74 rows: `Taxon`, then the 45 tests.
#' @seealso [vibrioKey()]
#' @examples
#' m <- vibrioMatrix()
#' m[1:4, 1:4]
#' table(unlist(m[-1]), useNA = "ifany")
#' @export
vibrioMatrix <- function() {
  raw <- dimoose::vibrio
  score <- function(x) {
    ifelse(x %in% c("+", "(+)"), "+",
      ifelse(x %in% c("-", "(-)"), "-",
        ifelse(x %in% c("v", "d"), "+/-", NA_character_)))
  }
  data.frame(Taxon = raw$species, lapply(raw[-1], score), check.names = FALSE, stringsAsFactors = FALSE)
}

# ---- matrix helpers ----------------------------------------------------------

# Checks a character matrix and returns list(taxa, characters, states), where
# states[[character]][[i]] holds the states of taxon i (character(0) if
# unknown). Rows of the same taxon are merged.
genParseMatrix <- function(matrix, taxon = "Taxon") {
  if (is.matrix(matrix) && !is.null(colnames(matrix))) {
    matrix <- as.data.frame(matrix, stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!is.data.frame(matrix)) stop("`matrix` must be a data frame", call. = FALSE)
  if (anyDuplicated(names(matrix))) {
    stop("`matrix` has more than one column named: ",
         paste(unique(names(matrix)[duplicated(names(matrix))]), collapse = ", "), call. = FALSE)
  }
  if (!is.character(taxon) || length(taxon) != 1 || !taxon %in% names(matrix)) {
    stop("`taxon` must be the name of a column of `matrix`", call. = FALSE)
  }
  name <- trimws(as.character(matrix[[taxon]]))
  if (anyNA(name) || any(!nzchar(name))) {
    stop("`matrix` has rows with no taxon name", call. = FALSE)
  }
  chars <- setdiff(names(matrix), taxon)
  if (length(chars) == 0) stop("`matrix` has no character columns", call. = FALSE)
  nested <- chars[!vapply(chars, function(ch) is.atomic(matrix[[ch]]) || is.factor(matrix[[ch]]), logical(1))]
  if (length(nested)) {
    stop("`matrix` column(s) must hold one value per row: ", paste(nested, collapse = ", "), call. = FALSE)
  }
  taxa <- unique(name)
  row <- match(name, taxa)
  states <- lapply(chars, function(ch) {
    cells <- strsplit(as.character(matrix[[ch]]), "/", fixed = TRUE)
    cells <- lapply(cells, function(s) {
      s <- trimws(s)
      s[!is.na(s) & nzchar(s)]
    })
    unname(lapply(split(cells, factor(row, levels = seq_along(taxa))), function(x) unique(unlist(x))))
  })
  names(states) <- chars
  list(taxa = taxa, characters = chars, states = states)
}

# Which characters to use and what they cost: a data frame with Character,
# Cost and Needs, in matrix order. Applies `season` and drops characters with
# fewer than two states.
genCharacterInfo <- function(m, characters = NULL, season = NULL) {
  info <- data.frame(Character = m$characters, Cost = rep(1, length(m$characters)), Season = "", Needs = "",
                     InapplicableIf = "", stringsAsFactors = FALSE)
  if (!is.null(characters)) {
    if (!is.data.frame(characters) || !"Character" %in% names(characters)) {
      stop("`characters` must be a data frame with a column `Character`", call. = FALSE)
    }
    listed <- trimws(as.character(characters[["Character"]]))
    at <- match(info$Character, listed)
    twice <- unique(listed[duplicated(listed) & listed %in% info$Character])
    if (length(twice)) {
      warning("`characters` has more than one row for: ", paste(twice, collapse = ", "),
              ". The first row of each is used.", call. = FALSE)
    }
    if (nrow(characters) > 0 && nrow(info) > 0 && all(is.na(at)) && !any(listed %in% m$dropped)) {
      warning("No row of `characters` names a column of `matrix`, so it has no effect", call. = FALSE)
    }
    if ("Cost" %in% names(characters)) {
      given <- trimws(as.character(characters[["Cost"]]))
      given[!is.na(given) & !nzchar(given)] <- NA
      cost <- suppressWarnings(as.numeric(given))
      if (any(!is.na(cost) & (cost <= 0 | !is.finite(cost))) || any(is.na(cost) != is.na(given))) {
        stop("`Cost` in `characters` must be positive numbers", call. = FALSE)
      }
      info$Cost <- ifelse(is.na(cost[at]), 1, cost[at])
    }
    for (col in intersect(c("Season", "Needs", "InapplicableIf"), names(characters))) {
      x <- trimws(as.character(characters[[col]]))[at]
      info[[col]] <- ifelse(is.na(x), "", x)
    }
  }
  if (!is.null(season)) {
    if (!is.character(season) || length(season) == 0 || anyNA(season) || any(!nzchar(trimws(season)))) {
      stop("`season` must be one or more season names", call. = FALSE)
    }
    if (is.null(characters) || !"Season" %in% names(characters)) {
      warning("`season` is ignored: `characters` has no `Season` column", call. = FALSE)
    } else {
      wanted <- tolower(trimws(as.character(season)))
      always <- c("all", "all year", "all seasons", "always", "any", "year-round", "year round")
      observable <- vapply(strsplit(tolower(info$Season), "[,;/]"), function(s) {
        s <- trimws(s)
        s <- s[nzchar(s)]
        length(s) == 0 || any(s %in% c(wanted, always))
      }, logical(1))
      info <- info[observable, , drop = FALSE]
      if (nrow(info) == 0) {
        stop("No character can be observed in season: ", paste(season, collapse = ", "), call. = FALSE)
      }
    }
  }
  informative <- vapply(info$Character, function(ch) length(unique(unlist(m$states[[ch]]))) > 1, logical(1))
  info <- info[informative, , drop = FALSE]
  rownames(info) <- NULL
  info
}

# The lead table of the key for `variable = "both"`: recursive partition in
# which a taxon follows every lead it could show. A sub-key is identified by
# the taxa still in play and the character states not yet ruled out on the way
# there; each is keyed out once (`couplets` remembers them) and reused.
genPartition <- function(m, info, maxCouplets = 10000) {
  n <- length(m$taxa)
  if (n < 2) stop("`matrix` must have at least two taxa", call. = FALSE)

  # One candidate split per character state (a "column"). has[i, j]: taxon i
  # is known to show state j; known[i, j]: its state for that character is
  # known at all.
  colChar <- integer()
  colState <- character()
  has <- list()
  known <- list()
  for (k in seq_len(nrow(info))) {
    st <- m$states[[info$Character[k]]]
    for (s in unique(unlist(st))) {
      colChar <- c(colChar, k)
      colState <- c(colState, s)
      has[[length(has) + 1]] <- vapply(st, function(x) s %in% x, logical(1))
      known[[length(known) + 1]] <- lengths(st) > 0
    }
  }
  if (length(has) == 0) stop("No character separates the taxa", call. = FALSE)
  has <- do.call(cbind, has)
  known <- do.call(cbind, known)
  cost <- info$Cost[colChar]
  # sameChar[j, k]: column j belongs to character k
  sameChar <- outer(colChar, seq_len(nrow(info)), "==") * 1
  # blockers[[k]]: the columns (states of another character) that make
  # character k inapplicable
  blockers <- genBlockers(info, colChar, colState)
  dependent <- which(lengths(blockers) > 0)
  # A sub-key's name: which taxa and which columns, as hex digits (a plain
  # list of numbers is too long a name for an environment with many taxa)
  bits <- function(set, size) {
    x <- logical(8 * ceiling(size / 8))
    x[set] <- TRUE
    paste(as.character(packBits(x)), collapse = "")
  }

  couplets <- new.env(parent = emptyenv())
  rows <- list()

  # Leads still to be followed: list(idx, live, slot, side). Kept as a stack
  # rather than followed by recursion, which a key hundreds of couplets deep
  # would overflow. The first lead of a couplet is followed to its end before
  # the second, so couplets are numbered in the order a reader meets them.
  todo <- list()

  # Returns list(Next, Taxon) for the lead that arrives at taxa `idx` with the
  # states `live` (logical, one per column) not yet ruled out. If that takes
  # a new couplet, its two leads are added to `todo`.
  visit <- function(idx, live) {
    result <- function() list(Next = "-", Taxon = paste(sort(m$taxa[idx]), collapse = " / "))
    if (length(idx) == 1) return(result())
    shows <- has[idx, , drop = FALSE]
    shows[, !live] <- FALSE
    # how many of its character's remaining states each taxon shows
    nStates <- (shows %*% sameChar)[, colChar, drop = FALSE]
    only <- shows & nStates == 1
    never <- known[idx, , drop = FALSE] & !has[idx, , drop = FALSE]
    a <- colSums(only)
    b <- colSums(never)
    # A couplet must name a state some taxon shows, leave another state for
    # its second lead, and rule out at least one taxon on one side
    usable <- live & colSums(shows) > 0 & colSums(nStates - shows) > 0 & (a > 0 | b > 0)
    if (!any(usable)) return(result())
    # A character that does not apply to a taxon still in play has to wait,
    # unless nothing else is left to ask
    blocked <- dependent[vapply(blockers[dependent], function(cols) any(shows[, cols]), logical(1))]
    if (length(blocked)) {
      waiting <- usable & !(colChar %in% blocked)
      if (any(waiting)) usable <- waiting else blocked <- integer()
    }
    # Only characters with two or more states still shown can be asked about
    # from here on, so they are all that tells this sub-key from another
    open <- ((colSums(shows) > 0) %*% sameChar)[colChar] > 1
    id <- paste(bits(idx, n), bits(which(live & open), length(live)), paste(blocked, collapse = ","))
    if (!is.null(couplets[[id]])) return(list(Next = couplets[[id]], Taxon = ""))

    score <- ifelse(usable, a * b / cost, -1)
    if (max(score) <= 0) score <- ifelse(usable, (a + b) / cost, -1)
    j <- which.max(score)
    k <- colChar[j]

    slot <- length(rows) + 1L
    if (slot > maxCouplets) {
      stop("The key has more than ", maxCouplets, " couplets and was given up. A taxon with a variable or ",
           "unknown state follows both leads, so a matrix with many such cells needs a very large key. ",
           "Leave out characters that are unknown for most taxa, use variable = \"missing\", ",
           "or raise `maxCouplets`.", call. = FALSE)
    }
    number <- as.character(slot)
    couplets[[id]] <- number
    first <- !never[, j]
    second <- !only[, j]
    # The second lead takes every other state its taxa may show: all that are
    # left if one of them is unknown for the character
    others <- live & colChar == k
    others[j] <- FALSE
    if (all(known[idx[second], j])) others <- others & colSums(shows[second, , drop = FALSE]) > 0
    rows[[slot]] <<- list(
      Statement = number, Choice = c("a", "b"),
      Character = paste0(info$Character[k], ": ", c(colState[j], paste(colState[others], collapse = " or "))),
      Next = c("", ""), Taxon = c("", ""),
      Question = info$Character[k],
      MatrixCharacter = info$Character[k],
      MatrixStates = c(colState[j], paste(colState[others], collapse = "/")),
      Needs = info$Needs[k]
    )
    liveSecond <- live
    liveSecond[j] <- FALSE
    todo[[length(todo) + 1]] <<- list(idx = idx[second], live = liveSecond, slot = slot, side = 2L)
    todo[[length(todo) + 1]] <<- list(idx = idx[first], live = live & colChar != k, slot = slot, side = 1L)
    list(Next = number, Taxon = "")
  }

  root <- visit(seq_len(n), rep(TRUE, ncol(has)))
  while (length(todo)) {
    lead <- todo[[length(todo)]]
    todo[[length(todo)]] <- NULL
    end <- visit(lead$idx, lead$live)
    rows[[lead$slot]]$Next[lead$side] <- end$Next
    rows[[lead$slot]]$Taxon[lead$side] <- end$Taxon
  }
  if (root$Next == "-") stop("No character separates the taxa", call. = FALSE)
  leads <- do.call(rbind, lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
  if (!any(nzchar(leads$Needs))) leads$Needs <- NULL
  rownames(leads) <- NULL
  leads <- genMergeCouplets(leads)
  size <- length(unique(leads$Statement))
  if (size > 10 * n) {
    warning("The key has ", size, " couplets for ", n, " taxa. A taxon with a variable or unknown state ",
            "follows both leads, so a matrix with many such cells gives a large key. Leave out characters ",
            "that are unknown for most taxa, or use variable = \"missing\".", call. = FALSE)
  }
  leads
}

# Sub-keys reached with different states still open can come out the same,
# lead for lead. Keeps the first of each set of identical couplets, points
# the leads of the others at it (which can make further couplets identical,
# hence the loop) and renumbers the couplets in reading order.
genMergeCouplets <- function(leads) {
  repeat {
    statement <- unique(leads$Statement)
    text <- paste(leads$Choice, leads$Character, leads$Next, leads$Taxon, sep = "\r")
    signature <- vapply(split(text, factor(leads$Statement, levels = statement)), paste, character(1), collapse = "\n")
    kept <- statement[match(signature, signature)]
    if (all(kept == statement)) break
    leads <- leads[leads$Statement %in% kept, , drop = FALSE]
    onward <- leads$Next != "-"
    leads$Next[onward] <- kept[match(leads$Next[onward], statement)]
  }
  if (nrow(leads) == 2 * length(unique(leads$Statement)) &&
      identical(unique(leads$Statement), as.character(seq_len(nrow(leads) / 2)))) {
    return(leads)
  }
  # reading order: a couplet, then all that its first lead leads to, then its
  # second lead
  order <- character()
  todo <- leads$Statement[1]
  while (length(todo)) {
    at <- todo[1]
    todo <- todo[-1]
    if (at %in% order) next
    order <- c(order, at)
    nexts <- leads$Next[leads$Statement == at]
    todo <- c(nexts[nexts != "-"], todo)
  }
  leads <- leads[order(match(leads$Statement, order)), , drop = FALSE]
  leads$Statement <- as.character(match(leads$Statement, order))
  onward <- leads$Next != "-"
  leads$Next[onward] <- as.character(match(leads$Next[onward], order))
  rownames(leads) <- NULL
  leads
}

# For each character of `info`, the columns of the partition (states of
# another character) under which it does not apply, from InapplicableIf rules
# written "Other character=state/state; Another=state". Rules that name a
# character or state the key does not use are skipped.
genBlockers <- function(info, colChar, colState) {
  lapply(seq_len(nrow(info)), function(k) {
    rules <- trimws(strsplit(info$InapplicableIf[k], ";", fixed = TRUE)[[1]])
    cols <- integer()
    for (rule in rules[nzchar(rules)]) {
      # the controlling character is the longest name the rule starts with
      names <- info$Character[startsWith(rule, paste0(info$Character, "="))]
      if (length(names) == 0) next
      other <- names[which.max(nchar(names))]
      states <- trimws(strsplit(substring(rule, nchar(other) + 2), "/", fixed = TRUE)[[1]])
      cols <- c(cols, which(colChar == match(other, info$Character) & colState %in% states))
    }
    unique(cols[colChar[cols] != k])
  })
}

# Applies the `Type` column of `characters` and turns numeric ranges into
# states. Text characters are left out; in a numeric character (typed
# "integer" or "real", or untyped with nothing but numbers and ranges in its
# cells) ranges that overlap or touch become one state named by its extremes.
# Returns `m` with `states` recoded, text characters removed (their names in
# `dropped`), and says what it did in a message.
genTypedStates <- function(m, characters = NULL) {
  type <- rep("", length(m$characters))
  if (!is.null(characters) && "Type" %in% names(characters)) {
    type <- tolower(trimws(as.character(characters[["Type"]])))[match(m$characters, trimws(as.character(characters[["Character"]])))]
    type[is.na(type)] <- ""
  }
  numericTypes <- c("integer", "real", "numeric", "quantitative", "in", "rn")
  notes <- character()
  text <- type %in% c("text", "te")
  for (k in which(!text & type %in% c("", numericTypes))) {
    ch <- m$characters[k]
    states <- unique(unlist(m$states[[ch]]))
    if (length(states) == 0) next
    range <- genRange(states)
    unit <- ""
    if (anyNA(range)) {
      # "2-8 mm": numbers followed by the same unit in every cell
      measured <- genUnit(states)
      if (!is.null(measured) && !anyNA(genRange(measured$value))) {
        range <- genRange(measured$value)
        unit <- paste0(if (grepl("^[[:alpha:]]", measured$unit)) " ", measured$unit)
      }
    }
    if (anyNA(range)) {
      if (type[k] != "") {
        text[k] <- TRUE
        notes <- c(notes, paste0("  ", ch, ": not used, \"", states[is.na(range[, 1])][1], "\" is not a number or a range"))
      }
      next
    }
    # sweep through the ranges from the lowest; a range that starts at or
    # below the highest value so far belongs to the same state
    o <- order(range[, 1], range[, 2])
    group <- integer(length(states))
    group[o] <- cumsum(c(TRUE, range[o, 1][-1] > cummax(range[o, 2])[-length(o)]))
    if (!anyDuplicated(group)) next
    label <- vapply(split(seq_along(states), group), function(i) {
      if (length(i) == 1) return(states[i])
      ends <- format(c(min(range[i, 1]), max(range[i, 2])), trim = TRUE, drop0trailing = TRUE, digits = 15)
      paste0(if (ends[1] == ends[2]) ends[1] else paste(ends, collapse = "-"), unit)
    }, character(1))
    m$states[[ch]] <- lapply(m$states[[ch]], function(s) unique(unname(label[as.character(group[match(s, states)])])))
    notes <- c(notes, if (length(label) == 1) {
      paste0("  ", ch, ": not used, its ranges all overlap (", label, ")")
    } else {
      paste0("  ", ch, ": overlapping ranges merged, giving the states ", paste(label, collapse = ", "))
    })
  }
  if (any(type %in% c("text", "te"))) {
    notes <- c(paste0("  not used, text: ", paste(m$characters[type %in% c("text", "te")], collapse = ", ")), notes)
  }
  if (length(notes)) message("Characters of the matrix:\n", paste(notes, collapse = "\n"))
  m$dropped <- m$characters[text]
  m$states <- m$states[!text]
  m$characters <- m$characters[!text]
  if (length(m$characters) == 0) stop("`matrix` has no character a key can use", call. = FALSE)
  m
}

# The lowest and highest number in each string of `x`, written as a number or
# a range ("3", "4-6", "(1-)2-8(-12)", "2.5 - 4"); NA for anything else.
genRange <- function(x) {
  ok <- grepl("^[0-9().\u2013\u2212 -]*[0-9][0-9().\u2013\u2212 -]*$", x)
  out <- matrix(NA_real_, length(x), 2)
  for (i in which(ok)) {
    v <- suppressWarnings(as.numeric(regmatches(x[i], gregexpr("[0-9]+\\.?[0-9]*|\\.[0-9]+", x[i]))[[1]]))
    if (length(v) && !anyNA(v)) out[i, ] <- range(v)
  }
  out
}

# Splits strings such as "2-8 mm" into the number or range and the unit
# after it. NULL unless every string ends in the same unit.
genUnit <- function(x) {
  parts <- regmatches(x, regexec("^(.*[0-9)])[[:space:]]*([[:alpha:]%\u00b0\u00b5][^0-9()]*)$", x))
  if (any(lengths(parts) != 3)) return(NULL)
  unit <- trimws(vapply(parts, `[`, character(1), 3))
  if (length(unique(unit)) != 1) return(NULL)
  list(value = vapply(parts, `[`, character(1), 2), unit = unit[1])
}

# The key for `variable = "missing"`: variable cells become NA and rpart fits
# a classification tree.
genRpartKey <- function(m, info, desc, meta) {
  if (length(m$taxa) < 2) stop("`matrix` must have at least two taxa", call. = FALSE)
  columns <- lapply(info$Character, function(ch) {
    st <- m$states[[ch]]
    single <- lengths(st) == 1
    x <- rep(NA_character_, length(st))
    x[single] <- unlist(st[single])
    factor(x, levels = unique(unlist(st)))
  })
  names(columns) <- info$Character
  # With variable cells gone a character may have no two states left
  keep <- vapply(columns, function(x) length(unique(x[!is.na(x)])) > 1, logical(1))
  if (!any(keep)) stop("No character separates the taxa", call. = FALSE)
  columns <- columns[keep]
  info <- info[keep, , drop = FALSE]
  if (any(grepl("`", info$Character, fixed = TRUE))) {
    stop("variable = \"missing\" cannot use a character with a backtick in its name: ",
         paste(info$Character[grepl("`", info$Character, fixed = TRUE)], collapse = ", "), call. = FALSE)
  }
  # The response gets a name no character has; `~ .` then takes every other
  # column whatever its name
  response <- make.unique(c(info$Character, "Taxon..response"))[nrow(info) + 1]
  data <- data.frame(factor(m$taxa, levels = m$taxa), columns, check.names = FALSE)
  names(data)[1] <- response
  fit <- rpart::rpart(
    stats::as.formula(paste0("`", response, "` ~ .")),
    data = data, method = "class", y = TRUE, cost = info$Cost,
    control = rpart::rpart.control(minsplit = 2, minbucket = 1, cp = 0, xval = 0, maxcompete = 0)
  )
  if (all(fit$frame$var == "<leaf>")) stop("No character separates the taxa", call. = FALSE)
  key <- keyFromRpart(fit, desc, meta)
  # rpart leaves out a taxon with no single known state at all. It could be
  # anything, so it is listed at every result.
  left <- m$taxa[as.integer(fit$na.action)]
  stuck <- sum(fit$frame$var[fit$where] != "<leaf>") + length(left)
  if (stuck > 0) {
    message("variable = \"missing\": ", stuck, if (stuck == 1) " taxon" else " taxa", " could not be placed at a ",
            "couplet whose character is unknown or variable for ", if (stuck == 1) "it" else "them",
            " and ", if (stuck == 1) "is" else "are", " listed at every result below it. ",
            "variable = \"both\" keys such taxa out.")
  }
  if (length(left) == 0) return(key)
  leads <- key$leads
  for (i in which(leads$Next == "-")) {
    leads$Taxon[i] <- paste(sort(c(strsplit(leads$Taxon[i], " / ", fixed = TRUE)[[1]], left)), collapse = " / ")
  }
  keyFromLeads(leads, desc, meta)
}

# Follows a key made by keyFromMatrix(variable = "both") for a specimen and
# returns the result it ends at. `observed` is a named character vector: the
# state the specimen shows for each character. NA if the key asks for a
# character that is not in `observed` or a state no lead accepts.
genWalk <- function(leads, observed) {
  at <- leads$Statement[1]
  repeat {
    rows <- which(leads$Statement == at)
    state <- observed[leads$MatrixCharacter[rows[1]]]
    if (is.na(state)) return(NA_character_)
    accepts <- vapply(strsplit(leads$MatrixStates[rows], "/", fixed = TRUE), function(s) state %in% s, logical(1))
    if (!any(accepts)) return(NA_character_)
    lead <- rows[which(accepts)[1]]
    if (leads$Next[lead] == "-") return(leads$Taxon[lead])
    at <- leads$Next[lead]
  }
}
