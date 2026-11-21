#' How quickly a key gets to a result
#'
#' Counts the steps (couplets answered) it takes to reach each result of a
#' key and compares the average with the fewest steps any key could need.
#'
#' A key is a code: each result is spelled by the leads chosen on the way to
#' it. `bound` is the expected number of steps of the best key there could
#' be for the same taxa and the same `weights`, among keys whose couplets
#' have no more leads than the largest couplet of this key (`maxLeads`). It
#' is found by Huffman's construction, which joins the rarest taxa first, so
#' it is a number of steps that a key can really reach: 3 for eight equally
#' common taxa and couplets of two leads, about 3.55 for eleven. No key can
#' do better, however its characters are chosen. `efficiency` is
#' `bound / expectedSteps`: 1 for a key that could not be shorter, and lower
#' the more steps the key takes than it would have to. Real keys rarely
#' reach 1, because the characters that would split the taxa evenly may not
#' exist.
#'
#' When some taxa are met more often than others (`weights`), a good key
#' asks few questions before reaching the common ones, and the bound takes
#' the weights into account in the same way.
#'
#' In a key that has a few large couplets among many small ones (a
#' PhyloTree key has couplets of 2 and of 87 leads), the best key is allowed
#' the largest couplet everywhere, so the bound is far below what the key
#' does and `efficiency` is low. Three more numbers describe such keys
#' without that comparison. `entropy` is the Shannon entropy of the weights
#' in bits (`log2` of the number of taxa when they are equally common): the
#' information a key has to gather. A couplet with `k` leads can give up to
#' `log2(k)` bits, and `bitsPerStep` is the average of that over the steps
#' this key takes (1 for a key of two-lead couplets). `capacityUsed` is
#' `entropy / (bitsPerStep * expectedSteps)`: the share of the information
#' its couplets could give that the key needs. It is 1 when every couplet
#' splits what reaches it evenly, whatever its size, and it is not a
#' comparison with a shorter key.
#'
#' Two cases need a rule:
#'
#' * A taxon that keys out at several terminal leads counts once: its steps
#'   are the mean over its leads, as if its specimens were split evenly
#'   among them, and its weight is not multiplied by the number of leads.
#' * A couplet reached from several leads (a reticulate key) is counted by
#'   its shortest route from the first couplet, so `steps` is the fewest
#'   steps in which a result can be reached. `depth` is the longest route.
#'
#' Leads in couplets that cannot be reached from the first couplet, and
#' terminal leads that name no taxon, are left out of the averages.
#'
#' @param key A [dimoose] key.
#' @param weights How common each taxon is: a numeric vector whose names
#'   are the key's results as written in its `Taxon` column, such as the
#'   output of [occurrenceWeights()]. They need not sum to 1, and names
#'   that are not in the key are ignored. Taxa that are missing from it or
#'   `NA` count as 0, with a warning. A vector without names is an error,
#'   as is a name that is there twice. `NULL` (the default) treats all taxa
#'   as equally common.
#' @return A list with
#'   * `taxa`: a data frame with one row per taxon: `Taxon`, `leads` (how
#'     many terminal leads end in it), `steps` (mean over those leads),
#'     `minSteps`, `maxSteps` and `weight` (its share of the weights, summing
#'     to 1);
#'   * `leads`: a data frame with one row per terminal lead: `Lead` (its
#'     label, e.g. `"7b"`), `Statement`, `Choice`, `Taxon` and `steps`;
#'   * `meanLeadSteps`: mean steps over terminal leads;
#'   * `meanTaxonSteps`: mean steps over taxa;
#'   * `expectedSteps`: mean steps over taxa weighted by `weight` (the same
#'     as `meanTaxonSteps` without `weights`);
#'   * `bound`: the expected steps of the best possible key to these taxa
#'     with these weights and couplets of at most `maxLeads` leads;
#'   * `efficiency`: `bound / expectedSteps`, above 0 and at most 1 (`NA`
#'     for a key to a single taxon, which needs no steps);
#'   * `entropy`: the Shannon entropy of `weight`, in bits;
#'   * `bitsPerStep`: the most a step of this key can tell, on average
#'     (1 when every couplet has two leads);
#'   * `capacityUsed`: `entropy / (bitsPerStep * expectedSteps)`, at most 1;
#'   * `maxLeads`: the number of leads in the key's largest couplet;
#'   * `depth`: the longest route to a result, in steps.
#' @seealso `summary()` on a key, which reports the aggregates;
#'   [occurrenceWeights()] for weights from GBIF.
#' @examples
#' q <- keyQuality(arachnidaKey())
#' q$taxa
#' q$expectedSteps
#' q$bound
#' q$efficiency
#'
#' # spiders and mites are met far more often than the other orders
#' common <- c(Araneae = 50, Acari = 40, Opiliones = 5, Scorpiones = 3)
#' suppressWarnings(keyQuality(arachnidaKey(), common))$expectedSteps
#' @export
keyQuality <- function(key, weights = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  check <- checkLeads(leads)
  depths <- qualCoupletDepths(leads, check)
  label <- leadLabels(leads)

  at <- match(leads$Statement, check$couplets)
  terminal <- which(leads$Next == "-" & !is.na(depths$shortest[at]))
  leadTable <- data.frame(
    Lead = label[terminal], Statement = leads$Statement[terminal], Choice = leads$Choice[terminal],
    Taxon = leads$Taxon[terminal], steps = depths$shortest[at[terminal]] + 1,
    stringsAsFactors = FALSE
  )
  named <- leadTable[nzchar(leadTable$Taxon), , drop = FALSE]
  taxon <- unique(named$Taxon)
  byTaxon <- split(named$steps, factor(named$Taxon, levels = taxon))
  taxa <- data.frame(
    Taxon = taxon,
    leads = as.integer(lengths(byTaxon)),
    steps = vapply(byTaxon, mean, 0),
    minSteps = vapply(byTaxon, min, 0),
    maxSteps = vapply(byTaxon, max, 0),
    stringsAsFactors = FALSE
  )
  taxa$weight <- qualWeights(taxon, weights)
  rownames(taxa) <- NULL

  size <- as.numeric(table(factor(leads$Statement, levels = check$couplets)))
  reached <- !is.na(depths$shortest)
  maxLeads <- if (any(reached)) as.integer(max(size[reached])) else 0L
  none <- nrow(taxa) == 0
  expected <- if (none) NA_real_ else sum(taxa$weight * taxa$steps)
  p <- taxa$weight[taxa$weight > 0]
  entropy <- if (none) NA_real_ else -sum(p * log2(p))
  # The chance of coming through each couplet, with a taxon's weight split
  # evenly among its leads; the bits its leads could tell apart are log2(size)
  bitsPerStep <- NA_real_
  if (!none) {
    share <- taxa$weight[match(named$Taxon, taxon)] / taxa$leads[match(named$Taxon, taxon)]
    visit <- qualVisitProbability(match(named$Statement, check$couplets), share, depths)
    bitsPerStep <- sum(visit * log2(pmax(size, 1))) / sum(visit)
  }
  bound <- if (none) NA_real_ else qualOptimalSteps(taxa$weight, maxLeads)
  capacity <- if (none || !isTRUE(bitsPerStep > 0)) NA_real_ else min(1, entropy / (bitsPerStep * expected))
  list(
    taxa = taxa,
    leads = leadTable,
    meanLeadSteps = if (nrow(named)) mean(named$steps) else NA_real_,
    meanTaxonSteps = if (none) NA_real_ else mean(taxa$steps),
    expectedSteps = expected,
    bound = bound,
    efficiency = if (is.na(bound) || bound <= 0) NA_real_ else min(1, bound / expected),
    entropy = entropy,
    bitsPerStep = bitsPerStep,
    capacityUsed = capacity,
    maxLeads = maxLeads,
    depth = if (length(terminal)) as.integer(max(depths$longest[at[terminal]]) + 1) else 0L
  )
}

# The expected steps of the best key to taxa with probabilities `p` whose
# couplets have at most `arity` leads: Huffman's construction, which joins
# the `arity` least likely groups into one couplet until one group is left.
# Each joining adds a step for everything in the new group, so the expected
# steps are the sum of the joined groups' probabilities. Groups of
# probability 0 are added first so that the last couplet made (the first
# one asked) is a full one.
qualOptimalSteps <- function(p, arity) {
  n <- length(p)
  if (n <= 1) return(0)
  arity <- max(2, arity)
  if (arity >= n) return(sum(p))
  pad <- (arity - 1 - (n - 1) %% (arity - 1)) %% (arity - 1)
  leaf <- c(rep(0, pad), sort(p))
  joins <- (length(leaf) - 1) / (arity - 1)
  # `leaf` and the groups made so far (`node`) are both in rising order, so
  # the least likely group is always at the front of one of the two
  node <- numeric(joins)
  i <- 1
  j <- 1
  steps <- 0
  for (made in seq_len(joins)) {
    total <- 0
    for (pick in seq_len(arity)) {
      if (j >= made || (i <= length(leaf) && leaf[i] <= node[j])) {
        total <- total + leaf[i]
        i <- i + 1
      } else {
        total <- total + node[j]
        j <- j + 1
      }
    }
    node[made] <- total
    steps <- steps + total
  }
  steps
}

# The probability of coming through each couplet on the way to a result,
# given the probability `share` of ending at a lead of couplet `at`. Each
# couplet passes its probability up to the couplet it is first reached from.
qualVisitProbability <- function(at, share, depths) {
  visit <- numeric(length(depths$shortest))
  own <- tapply(share, at, sum)
  visit[as.integer(names(own))] <- own
  deepest <- suppressWarnings(max(depths$shortest, na.rm = TRUE))
  for (d in rev(seq_len(max(deepest, 0)))) {
    here <- which(depths$shortest == d)
    up <- tapply(visit[here], depths$parent[here], sum)
    visit[as.integer(names(up))] <- visit[as.integer(names(up))] + up
  }
  visit
}

# Steps from the root to each couplet (0 for the root, NA when it cannot be
# reached): `shortest` over all routes and `longest` over all routes, and the
# `parent` couplet on a shortest route. A key with a cycle has no longest
# route; `longest` is then the shortest.
qualCoupletDepths <- function(leads, check) {
  couplets <- check$couplets
  n <- length(couplets)
  shortest <- rep(NA_real_, n)
  parent <- rep(NA_integer_, n)
  if (n == 0) return(list(shortest = shortest, longest = shortest, parent = parent))
  from <- match(leads$Statement, couplets)
  to <- match(leads$Next, couplets)
  edge <- leads$Next != "-" & !is.na(to)
  from <- from[edge]
  to <- to[edge]

  root <- match(check$root, couplets)
  shortest[root] <- 0
  frontier <- root
  while (length(frontier)) {
    out <- which(from %in% frontier & is.na(shortest[to]))
    nxt <- unique(to[out])
    parent[nxt] <- from[out[match(nxt, to[out])]]
    shortest[nxt] <- shortest[frontier[1]] + 1
    frontier <- nxt
  }

  # Longest route: push each couplet's depth along its leads until nothing
  # changes. In a key without cycles that takes at most one pass per couplet.
  longest <- rep(NA_real_, n)
  longest[root] <- 0
  settled <- FALSE
  for (pass in seq_len(n + 1)) {
    reach <- longest[from] + 1
    known <- !is.na(reach) & to != root
    if (!any(known)) {
      settled <- TRUE
      break
    }
    best <- tapply(reach[known], to[known], max)
    target <- as.integer(names(best))
    better <- is.na(longest[target]) | best > longest[target]
    if (!any(better)) {
      settled <- TRUE
      break
    }
    longest[target[better]] <- best[better]
  }
  if (!settled) longest <- shortest
  list(shortest = shortest, longest = longest, parent = parent)
}

# Each taxon's share of the weights (summing to 1); equal shares without
# weights.
qualWeights <- function(taxon, weights) {
  n <- length(taxon)
  if (n == 0) return(numeric())
  if (is.null(weights)) return(rep(1 / n, n))
  if (!is.numeric(weights) || length(dim(weights)) > 1) {
    stop("`weights` must be a numeric vector named by the key's taxa", call. = FALSE)
  }
  if (is.null(names(weights))) {
    stop("`weights` must be a numeric vector named by the key's taxa; this one has no names", call. = FALSE)
  }
  names(weights) <- trimws(names(weights))
  twice <- unique(names(weights)[duplicated(names(weights)) & names(weights) %in% taxon])
  if (length(twice)) {
    stop("`weights` has more than one value for ", paste(utils::head(twice, 5), collapse = ", "),
         if (length(twice) > 5) ", ...", call. = FALSE)
  }
  w <- unname(weights[match(taxon, names(weights))])
  absent <- is.na(w)
  if (all(absent)) stop("None of the names of `weights` is a taxon of the key", call. = FALSE)
  if (any(absent)) {
    warning(sprintf("%d of the key's %d taxa have no weight and count as 0: %s", sum(absent), n,
                    paste(utils::head(taxon[absent], 5), collapse = ", ")),
            if (sum(absent) > 5) ", ...", call. = FALSE)
    w[absent] <- 0
  }
  if (any(w < 0) || any(!is.finite(w))) stop("`weights` must be finite and not negative", call. = FALSE)
  if (sum(w) <= 0) stop("`weights` are all 0 for the key's taxa", call. = FALSE)
  w / sum(w)
}

#' How common each taxon of a key is, from GBIF occurrence records
#'
#' Counts the occurrence records [GBIF](https://www.gbif.org) holds for each
#' result of a key, optionally within a country or region. The counts can be
#' given to [keyQuality()] or `summary()` as `weights`, to see how many
#' steps the key takes for the taxa people actually meet.
#'
#' A result written as `"Common name (Genus species)"` is looked up by the
#' name in parentheses; other results by the result itself when it looks
#' like a scientific name, which includes genera and families (`"Salix"`,
#' `"Salix sp."` and `"Salix spp."` all count the genus) and names followed
#' by their author (`"Puma concolor (Linnaeus, 1771)"`). A result that
#' lists several taxa the key does not separate, written `"A / B"` as
#' [keyFromRpart()] and [keyFromMatrix()] write them, gets the sum of their
#' counts. Each name is matched to the GBIF Backbone Taxonomy, and the
#' records of the name GBIF accepts for it are counted, so a synonym gets
#' the count of its accepted name. This makes two requests to GBIF per
#' name, one name at a time; after three failed requests in a row the rest
#' are not tried.
#'
#' A name that GBIF knows in more than one kingdom (`"Morus"` is a mulberry
#' and a gannet) is not counted unless `kingdom` says which is meant.
#'
#' Occurrence counts measure how often a taxon is recorded, which follows
#' how conspicuous and how popular with observers it is as well as how
#' common it is. A taxon with no records gets a weight of 0 and so does not
#' count towards the expected steps at all.
#'
#' @param key A [dimoose] key.
#' @param region Where to count: `NULL` for the whole world, a two-letter
#'   ISO country code (`"US"`), or a [GADM](https://gadm.org) id for a
#'   country, state or county (`"USA.27_1"` is Montana). Anything else is
#'   an error. GBIF answers 0 for a GADM id it does not have, so when no
#'   taxon has a record in the region a warning asks to check it.
#' @param source Where the counts come from; only `"gbif"` for now.
#' @param fetch The function that asks GBIF: called as `fetch(url, query)`
#'   with a named list of query parameters, it returns the parsed JSON
#'   answer as a list. Replace it to use cached answers or to test without
#'   a connection.
#' @param kingdom Optional kingdom ("Plantae", "Animalia", ...), which helps
#'   GBIF tell apart names that are used in more than one kingdom.
#' @return A numeric vector of record counts named by the key's results (as
#'   in its `Taxon` column), `NA` for results that have no scientific name,
#'   that GBIF does not know or cannot tell apart, or whose request failed
#'   (each with a warning).
#' @seealso [keyQuality()], [checkNames()]
#' @examples
#' # canned answers in place of GBIF, to show the shape of `fetch`
#' counts <- c("Acer negundo" = 61000, "Fraxinus pennsylvanica" = 48000)
#' canned <- function(url, query) {
#'   if (grepl("species/match", url)) {
#'     list(usageKey = match(query$name, names(counts)), matchType = "EXACT")
#'   } else {
#'     list(count = unname(counts[query$taxonKey]))
#'   }
#' }
#' leads <- data.frame(
#'   Statement = "1", Choice = c("a", "b"), Character = c("Leaflets 3.", "Leaflets 5 to 7."),
#'   Next = "-", Taxon = c("Box elder (Acer negundo)", "Green ash (Fraxinus pennsylvanica)")
#' )
#' occurrenceWeights(keyFromLeads(leads), fetch = canned)
#' \donttest{
#' k <- montanaKey()
#' w <- occurrenceWeights(k, region = "USA.27_1", kingdom = "Plantae")
#' w
#' summary(k, weights = w)
#' }
#' @export
occurrenceWeights <- function(key, region = NULL, source = "gbif", fetch = qualGbifFetch, kingdom = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  source <- match.arg(source, "gbif")
  if (!is.function(fetch)) stop("`fetch` must be a function of a URL and a list of query parameters", call. = FALSE)
  where <- qualRegionQuery(region)
  leads <- normalizeLeads(key$leads)
  taxa <- unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])
  # a result may list several taxa ("A / B"); it gets the sum of their counts
  parts <- lapply(strsplit(taxa, " / ", fixed = TRUE), function(x) qualLookupName(trimws(x)))

  # one answer per name: its count, or NA and why
  count <- numeric()
  why <- character()
  failure <- character()
  inARow <- 0
  for (name in unique(stats::na.omit(unlist(parts)))) {
    if (inARow >= 3) {
      count[name] <- NA_real_
      why[name] <- "not tried"
      next
    }
    res <- tryCatch({
      m <- fetch("https://api.gbif.org/v1/species/match", qualDropNull(list(name = name, kingdom = kingdom)))
      type <- if (is.null(m$matchType)) "NONE" else m$matchType
      taxonKey <- if (!is.null(m$acceptedUsageKey)) m$acceptedUsageKey else m$usageKey
      # GBIF calls a genus that also has a species-rank entry of the same
      # name a HIGHERRANK match; it is the genus asked for all the same
      itself <- !is.null(m$canonicalName) && identical(tolower(m$canonicalName), tolower(name))
      if (type == "NONE" && !is.null(m$note) && grepl("Multiple equal matches", m$note, fixed = TRUE)) {
        list(count = NA_real_, why = "ambiguous")
      } else if (type == "NONE" || (type == "HIGHERRANK" && !itself) || is.null(taxonKey)) {
        list(count = NA_real_, why = "unknown")
      } else {
        found <- fetch("https://api.gbif.org/v1/occurrence/search", c(list(taxonKey = taxonKey, limit = 0), where))
        if (is.null(found$count)) stop("GBIF's answer for ", name, " has no count")
        list(count = as.numeric(found$count), why = "")
      }
    }, error = function(e) {
      failure <<- c(failure, conditionMessage(e))
      list(count = NA_real_, why = "failed")
    })
    inARow <- if (res$why == "failed") inARow + 1 else 0
    count[name] <- res$count
    why[name] <- res$why
  }
  counts <- vapply(parts, function(x) if (anyNA(x)) NA_real_ else sum(count[x]), numeric(1))
  names(counts) <- taxa

  some <- function(x) paste0(paste(utils::head(x, 5), collapse = ", "), if (length(x) > 5) ", ..." else "")
  noName <- taxa[vapply(parts, anyNA, logical(1))]
  if (length(noName)) {
    warning(sprintf("%d result%s without a scientific name not counted: %s", length(noName),
                    if (length(noName) == 1) "" else "s", some(noName)), call. = FALSE)
  }
  unknown <- names(why)[why == "unknown"]
  if (length(unknown)) warning("Not in GBIF, so not counted: ", some(unknown), call. = FALSE)
  ambiguous <- names(why)[why == "ambiguous"]
  if (length(ambiguous)) {
    warning("GBIF knows more than one taxon by this name, so not counted (say which with `kingdom`): ",
            some(ambiguous), call. = FALSE)
  }
  failed <- sum(why %in% c("failed", "not tried"))
  if (failed) {
    warning(sprintf("Could not get the count of %d name%s from GBIF: %s", failed, if (failed == 1) "" else "s", failure[1]),
            if (any(why == "not tried")) "; gave up after 3 failed requests in a row", call. = FALSE)
  }
  if (length(where) && any(!is.na(counts)) && all(counts[!is.na(counts)] == 0)) {
    warning("GBIF has no records of these taxa in ", where[[1]], "; check that it is the region meant", call. = FALSE)
  }
  counts
}

# The name to look a result up by, or NA when it has none: the name in
# parentheses of "Common name (Genus species)", otherwise the result itself
# when it looks like a scientific name. Parentheses that hold an author
# ("Puma concolor (Linnaeus, 1771)") are dropped, and "Salix sp." or
# "Salix spp." is the genus.
qualLookupName <- function(taxa) {
  genus <- function(x) trimws(sub("\\s+spp?\\.?$", "", x))
  inside <- genus(scientificPart(taxa))
  # an author: the name is what stands before the parentheses
  author <- !is.na(inside) & grepl("[0-9]{4}|,|&|\\.$", inside)
  inside[author] <- NA_character_
  taxa[author] <- sub("\\s*\\([^()]*\\)$", "", taxa[author])
  name <- ifelse(is.na(inside), genus(taxa), inside)
  name[!nzchar(name)] <- NA_character_
  ok <- !is.na(name)
  ok[ok] <- isScientificName(name[ok])
  name[!ok] <- NA_character_
  name
}

# The occurrence search parameter for a region: `country` for a two-letter
# code, `gadmGid` for a GADM id (three letters, then numbered levels).
qualRegionQuery <- function(region) {
  if (is.null(region)) return(list())
  if (!is.character(region) || length(region) != 1 || is.na(region) || !nzchar(trimws(region))) {
    stop("`region` must be one country code or GADM id", call. = FALSE)
  }
  region <- toupper(trimws(region))
  if (grepl("^[A-Z]{2}$", region)) return(list(country = region))
  if (!grepl("^[A-Z]{3}(\\.[0-9]+)*(_[0-9]+)?$", region)) {
    stop("`region` must be a two-letter country code (\"US\") or a GADM id (\"USA.27_1\"), not ", region, call. = FALSE)
  }
  list(gadmGid = region)
}

qualDropNull <- function(x) x[!vapply(x, is.null, logical(1))]

# Ask the GBIF API (https://techdocs.gbif.org/en/openapi/) and parse its JSON.
qualGbifFetch <- function(url, query) {
  r <- httr::GET(url, query = query, dimooseUserAgent(), httr::timeout(30))
  httr::stop_for_status(r, task = "ask GBIF")
  httr::content(r, as = "parsed", type = "application/json", encoding = "UTF-8")
}
