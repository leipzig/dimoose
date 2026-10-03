#' Export an interactive dichotomous key
#'
#' Writes a moose key as a single self-contained HTML page. With JavaScript
#' on, the page steps through the key one couplet at a time, keeps a trail of
#' the choices made (each one clickable to go back to it) and supports the
#' browser's Back button. Without JavaScript, the same page is the full key
#' with every lead hyperlinked to its next couplet or taxon. Each taxon gets
#' a result section listing the characters on its path, and a map of the
#' key shows where the user is (see `map`).
#'
#' The key is checked first: leads pointing at missing couplets, terminal
#' leads without a taxon, couplets with fewer than two leads and couplets
#' that cannot be reached from the first one are reported as warnings and
#' marked in the page.
#'
#' @param moose A [moose] object, e.g. from [importFishbase()].
#' @param file Path of the HTML file to write. If `NULL`, the HTML is returned
#'   as a string instead.
#' @param displayLinks If `TRUE`, show the couplet numbers each lead leads to
#'   and comes from, as in a printed key. If `FALSE`, hide them. Leads stay
#'   clickable either way.
#' @param order Order of couplets. Only `"original"` (the key's own order) is
#'   implemented.
#' @param title Page title. Defaults to the key's description.
#' @param staticPaths If `TRUE`, write each taxon's path through the key into
#'   the page, so it shows without JavaScript. If `FALSE`, the page builds
#'   the path in the browser when a result is shown, which keeps large keys
#'   (such as [phylotreeKey()] on the whole tree) much smaller. The default
#'   is `TRUE` for keys with up to 1,000 taxa.
#' @param map If `TRUE`, include a map of the key: the whole key drawn as a
#'   tree, marking the current couplet, the path taken so far and the
#'   branches (and number of taxa) still possible. It sits beside the key on
#'   wide screens and behind a Map button on phones.
#' @return The path to `file`, invisibly, or the HTML as a character string if
#'   `file` is `NULL`.
#' @examples
#' \dontrun{
#' sharks <- importFishbase(1, usePhyloService = "none")
#' exportWizard(sharks, "sharks.html")
#' }
#' @export
exportWizard <- function(moose, file = NULL, displayLinks = TRUE,
                         order = c("original", "parsimony"), title = NULL,
                         map = TRUE, staticPaths = NULL) {
  order <- match.arg(order)
  if (order == "parsimony") {
    stop("order = \"parsimony\" is not implemented yet; use \"original\"", call. = FALSE)
  }
  if (!inherits(moose, "moose")) {
    stop("`moose` must be a moose object", call. = FALSE)
  }
  leads <- normalizeLeads(moose$leads)
  if (nrow(leads) == 0) {
    stop("This key has no leads to export", call. = FALSE)
  }
  check <- checkLeads(leads)
  for (w in check$problems) warning(w, call. = FALSE)

  if (is.null(title)) {
    title <- if (length(moose$desc) == 1 && !is.na(moose$desc)) moose$desc else "Dichotomous key"
  }
  nodeLabel <- metaValue(moose$meta, "node_label")
  if (is.na(nodeLabel) || !nzchar(nodeLabel)) nodeLabel <- "Couplet"
  if (is.null(staticPaths)) {
    staticPaths <- length(unique(leads$Taxon[leads$Next == "-" & nzchar(leads$Taxon)])) <= 1000
  }
  html <- renderWizard(leads, check,
    nodeLabel = nodeLabel,
    staticPaths = isTRUE(staticPaths),
    title = title,
    citation = metaValue(moose$meta, "citation"),
    taxa = moose$taxa,
    images = embeddedImages(moose$meta),
    displayLinks = displayLinks,
    map = map,
    features = moose$features
  )
  if (is.null(file)) {
    return(html)
  }
  # Write bytes so UTF-8 text survives non-UTF-8 locales
  con <- file(file, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(html)), con)
  invisible(file)
}

# ---- key checks --------------------------------------------------------------

normalizeLeads <- function(leads) {
  for (col in c("Statement", "Choice", "Character", "Next", "Taxon", "Label", "Image", "ImageLink", "TaxonUrl",
                "Question", "Feature", "Test")) {
    if (is.null(leads[[col]])) leads[[col]] <- rep("", nrow(leads))
    x <- as.character(leads[[col]])
    x[is.na(x)] <- ""
    leads[[col]] <- trimws(x)
  }
  if (is.null(leads$Threshold)) leads$Threshold <- rep(NA_real_, nrow(leads))
  leads$Threshold <- suppressWarnings(as.numeric(leads$Threshold))
  leads$Next[leads$Next == ""] <- "-"
  as.data.frame(leads, stringsAsFactors = FALSE)
}

# Display label of each lead: its Label if given, otherwise couplet + choice ("7b")
leadLabels <- function(leads) {
  ifelse(nzchar(leads$Label), leads$Label, paste0(leads$Statement, leads$Choice))
}

# Root couplet, reachability, parents and a list of problems found.
checkLeads <- function(leads) {
  couplets <- unique(leads$Statement)
  label <- leadLabels(leads)
  targets <- leads$Next[leads$Next != "-"]
  problems <- character()

  unreferenced <- setdiff(couplets, targets)
  root <- if (length(unreferenced) > 0) unreferenced[1] else couplets[1]
  if (length(unreferenced) == 0) {
    problems <- c(problems, "Every couplet is the target of some lead (the key has a cycle); starting at the first couplet")
  }

  missingTarget <- leads$Next != "-" & !leads$Next %in% couplets
  for (i in which(missingTarget)) {
    problems <- c(problems, sprintf("Lead %s leads to couplet %s, which is not in the key", label[i], leads$Next[i]))
  }
  noTaxon <- leads$Next == "-" & leads$Taxon == ""
  for (i in which(noTaxon)) {
    problems <- c(problems, sprintf("Lead %s ends the key but names no taxon", label[i]))
  }
  leadCount <- table(factor(leads$Statement, levels = couplets))
  for (cp in names(leadCount)[leadCount < 2]) {
    problems <- c(problems, sprintf("Couplet %s has only one lead", cp))
  }

  reachable <- root
  frontier <- root
  while (length(frontier) > 0) {
    nxt <- leads$Next[leads$Statement %in% frontier]
    nxt <- setdiff(nxt[nxt %in% couplets], reachable)
    reachable <- c(reachable, nxt)
    frontier <- nxt
  }
  unreachable <- setdiff(couplets, reachable)
  if (length(unreachable) > 0) {
    problems <- c(problems, sprintf(
      "Couplet(s) %s cannot be reached from couplet %s",
      paste(unreachable, collapse = ", "), root
    ))
  }

  list(root = root, couplets = couplets, missingTarget = missingTarget,
       unreachable = unreachable, problems = problems)
}

# Lead indices from the root to lead `i`, following the first parent lead of
# each couplet.
pathToLead <- function(leads, i, root, parentLead = match(leads$Statement, leads$Next)) {
  path <- i
  seen <- leads$Statement[i]
  while (leads$Statement[path[1]] != root) {
    parent <- parentLead[path[1]]
    if (is.na(parent) || leads$Statement[parent] %in% seen) break
    seen <- c(seen, leads$Statement[parent])
    path <- c(parent, path)
  }
  path
}

# ---- rendering ---------------------------------------------------------------

htmlEscape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}

metaValue <- function(meta, key) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(NA_character_)
  v <- meta$value[meta$key == key]
  if (length(v) == 0) NA_character_ else as.character(v[1])
}

# Named vector: image id -> data URI, from meta rows image_<id>. Values that
# are bare base64 (importFishbase(embedImages = TRUE) wrote those) are GIFs.
embeddedImages <- function(meta) {
  if (!is.data.frame(meta) || !all(c("key", "value") %in% names(meta))) return(character())
  rows <- grepl("^image_", meta$key) & !grepl("^image_url_", meta$key)
  v <- as.character(meta$value[rows])
  v <- ifelse(startsWith(v, "data:"), v, paste0("data:image/gif;base64,", v))
  stats::setNames(v, sub("^image_", "", meta$key[rows]))
}

cssName <- function(id) paste0("--img-", gsub("[^A-Za-z0-9_-]", "_", id))

# <style> block declaring every embedded image once as a CSS custom property
imageStyle <- function(images) {
  if (length(images) == 0) return("")
  paste0("<style>:root{", paste0(cssName(names(images)), ":url(\"", images, "\")", collapse = ";"), "}</style>\n")
}

# Glossary of the key's sniglets: name, coined word, definition, example
# crops, where found. Anchors use the coined word, which never changes.
glossaryHtml <- function(features, leads, coupletId, images = character()) {
  if (is.null(features)) return("")
  terms <- which(features$kind == "centroid_patch_max")
  if (length(terms) == 0) return("")
  entries <- vapply(terms, function(j) {
    coined <- snigletWord(features$id[j])
    name <- features$label[j]
    ex <- features$exemplars[[j]]
    crops <- if (!is.null(ex) && !is.null(ex$png)) {
      # a crop the page already declares (patchExemplars() stores each one in
      # the key's images) is referenced, not embedded a second time
      uri <- paste0("data:image/png;base64,", ex$png)
      known <- paste0(gsub("[^A-Za-z0-9_-]", "_", coined), "_", seq_along(uri))
      shared <- !is.na(images[known]) & unname(images[known]) == uri
      paste0(sprintf("<span class=\"fig\" role=\"img\" aria-label=\"%s in %s\" style=\"background-image:%s\"></span>",
        htmlEscape(name), htmlEscape(ex$image),
        ifelse(shared, sprintf("var(%s)", cssName(known)), sprintf("url(&quot;%s&quot;)", uri))), collapse = "")
    } else ""
    seen <- if (is.null(ex)) NULL else if (!is.null(ex$label)) unique(ex$label) else unique(ex$image)
    where <- if (length(seen)) sprintf("<p class=\"found\">Seen in %s</p>", htmlEscape(paste(seen, collapse = ", "))) else ""
    asked <- unique(leads$Statement[leads$Feature == features$id[j]])
    links <- paste(sprintf("<a href=\"#%s\">%s</a>", coupletId(asked), htmlEscape(asked)), collapse = ", ")
    def <- if (!is.null(features$definition) && !is.na(features$definition[j])) sprintf("<p class=\"definition\">%s</p>", htmlEscape(features$definition[j])) else ""
    was <- if (!identical(name, coined)) sprintf("<p class=\"found\">Sniglet <code>%s</code></p>", htmlEscape(coined)) else ""
    sprintf("<div class=\"term\" id=\"g-%s\"><h3%s>%s</h3>%s<div class=\"figs\">%s</div>%s%s<p class=\"found\">Asked at %s</p></div>",
      htmlEscape(coined), if (identical(name, coined)) "" else " class=\"named\"", htmlEscape(name), def, crops, where, was, links)
  }, character(1))
  sprintf("<section class=\"glossary\" id=\"glossary\" aria-labelledby=\"h-glossary\">\n<h2 id=\"h-glossary\" tabindex=\"-1\">Glossary of sniglets</h2>\n<p>A sniglet is a visual feature the model found in the images. Each one is defined by the image patches that match it best: \"Has <i>sniglet</i>\" means the specimen has a region that looks like these.</p>\n%s\n</section>",
    paste(entries, collapse = "\n"))
}

splitUrls <- function(x) {
  if (is.na(x) || !nzchar(x)) character() else strsplit(x, ";", fixed = TRUE)[[1]]
}

figuresHtml <- function(thumbs, fulls, images, alt) {
  if (length(thumbs) == 0) return("")
  items <- vapply(thumbs, function(t) {
    name <- sub("\\.(gif|jpe?g|png|webp)$", "", basename(t), ignore.case = TRUE)
    full <- fulls[basename(fulls) == sub("^tn_", "", basename(t))][1]
    img <- if (!is.na(images[name])) {
      sprintf("<span class=\"fig\" role=\"img\" aria-label=\"%s\" style=\"background-image:var(%s)\"></span>",
        htmlEscape(alt), cssName(name))
    } else {
      sprintf("<img class=\"fig\" src=\"%s\" alt=\"%s\" loading=\"lazy\">", htmlEscape(t), htmlEscape(alt))
    }
    if (is.na(full)) img else {
      sprintf("<a href=\"%s\" target=\"_blank\" rel=\"noopener\" title=\"Open full-size figure\">%s</a>", htmlEscape(full), img)
    }
  }, character(1))
  paste0("<figure class=\"figs\">", paste(items, collapse = ""), "</figure>")
}

renderWizard <- function(leads, check, title, citation, taxa, images, displayLinks, map = TRUE,
                         nodeLabel = "Couplet", staticPaths = TRUE, features = NULL) {
  label <- leadLabels(leads)
  # Section ids: sanitized names, made unique (e.g. M4'67 and M4"67)
  ids <- paste0("c-", gsub("[^A-Za-z0-9_-]", "_", check$couplets))
  ids <- ifelse(duplicated(ids) | duplicated(ids, fromLast = TRUE), paste0(ids, "-", seq_along(ids)), ids)
  names(ids) <- check$couplets
  coupletId <- function(cp) unname(ids[cp])

  terminal <- which(leads$Next == "-" & leads$Taxon != "")
  taxonNames <- unique(leads$Taxon[terminal])
  taxonId <- stats::setNames(paste0("t-", seq_along(taxonNames)), taxonNames)

  # Couplet sections
  coupletHtml <- vapply(check$couplets, function(cp) {
    idx <- which(leads$Statement == cp)
    parents <- which(leads$Next == cp)
    from <- if (length(parents) > 0) {
      sprintf(" <span class=\"from\">from %s</span>", paste(sprintf(
        "<a href=\"#%s\">%s</a>", coupletId(leads$Statement[parents]),
        htmlEscape(ifelse(label[parents] == cp, leads$Statement[parents], label[parents]))
      ), collapse = ", "))
    } else {
      ""
    }
    leadItems <- vapply(idx, function(i) {
      text <- if (nzchar(leads$Character[i])) leads$Character[i] else "(no description)"
      if (leads$Next[i] == "-") {
        if (nzchar(leads$Taxon[i])) {
          href <- paste0("#", taxonId[[leads$Taxon[i]]])
          dest <- paste0("&rarr; ", htmlEscape(leads$Taxon[i]))
        } else {
          href <- NA
          dest <- "no taxon given"
        }
      } else if (check$missingTarget[i]) {
        href <- NA
        dest <- sprintf("&rarr; couplet %s (missing from key)", htmlEscape(leads$Next[i]))
      } else {
        href <- paste0("#", coupletId(leads$Next[i]))
        dest <- paste0("&rarr; ", htmlEscape(leads$Next[i]))
      }
      inner <- sprintf(
        "<span class=\"letter\" aria-hidden=\"true\">%s</span><span class=\"text\">%s</span><span class=\"dest\">%s</span>",
        if (nzchar(leads$Choice[i])) htmlEscape(leads$Choice[i]) else "&bull;", htmlEscape(text), dest
      )
      choose <- if (is.na(href)) {
        sprintf("<span class=\"choose broken\" data-lead=\"%s\">%s</span>", htmlEscape(label[i]), inner)
      } else {
        sprintf("<a class=\"choose\" href=\"%s\" data-lead=\"%s\">%s</a>", href, htmlEscape(label[i]), inner)
      }
      figs <- figuresHtml(splitUrls(leads$Image[i]), splitUrls(leads$ImageLink[i]), images,
        paste("Figure for lead", label[i]))
      gloss <- ""
      if (!is.null(features) && nzchar(leads$Feature[i])) {
        fr <- match(leads$Feature[i], features$id)
        if (!is.na(fr) && features$kind[fr] == "centroid_patch_max") {
          gloss <- sprintf("<a class=\"gloss\" href=\"#g-%s\" title=\"What is this? See the glossary\" aria-label=\"Glossary entry for this sniglet\">?</a>",
            htmlEscape(snigletWord(features$id[fr])))
        }
      }
      sprintf("<li class=\"lead%s\">%s%s%s</li>", if (nzchar(gloss)) " examples" else "", choose, gloss, figs)
    }, character(1))
    id <- coupletId(cp)
    q <- if (!is.null(leads$Question)) leads$Question[idx[1]] else ""
    heading <- if (!is.null(q) && nzchar(q)) {
      sprintf("%s <span class=\"num\">%s %s</span>", htmlEscape(q), htmlEscape(nodeLabel), htmlEscape(cp))
    } else {
      sprintf("%s <span class=\"num\">%s</span>", htmlEscape(nodeLabel), htmlEscape(cp))
    }
    sprintf(
      "<section class=\"couplet\" id=\"%s\" aria-labelledby=\"h-%s\">\n<h2 id=\"h-%s\" tabindex=\"-1\">%s%s</h2>\n<ul class=\"leads\">\n%s\n</ul>\n</section>",
      id, id, id, heading, from, paste(leadItems, collapse = "\n")
    )
  }, character(1))

  # Taxon result sections
  parentLead <- match(leads$Statement, leads$Next)
  terminalsOf <- split(terminal, factor(leads$Taxon[terminal], levels = taxonNames))
  taxaRow <- if (is.data.frame(taxa) && "submitted_name" %in% names(taxa)) match(taxonNames, taxa$submitted_name) else rep(NA, length(taxonNames))
  names(taxaRow) <- taxonNames
  taxonHtml <- vapply(taxonNames, function(tx) {
    i <- terminalsOf[[tx]][1]
    steps <- if (staticPaths) {
      path <- pathToLead(leads, i, check$root, parentLead)
      vapply(path, function(p) {
        sprintf("<li><a class=\"step\" href=\"#%s\">%s</a>%s</li>",
          coupletId(leads$Statement[p]), htmlEscape(label[p]), htmlEscape(leads$Character[p]))
      }, character(1))
    } else {
      "<li class=\"pending\">The path through the key appears here when the page script runs.</li>"
    }
    verified <- ""
    if (!is.na(taxaRow[[tx]]) && "matched_name" %in% names(taxa)) {
      row <- taxa[taxaRow[[tx]], , drop = FALSE]
      if (nrow(row) > 0 && !is.na(row$matched_name[1]) && row$matched_name[1] != tx) {
        src <- if (!is.null(row$data_source) && !is.na(row$data_source[1])) paste0(" (", row$data_source[1], ")") else ""
        verified <- sprintf("<p class=\"verified\">Accepted name: %s%s</p>", htmlEscape(row$matched_name[1]), htmlEscape(src))
      }
    }
    others <- terminalsOf[[tx]]
    alsoVia <- if (length(others) > 1) {
      sprintf("<p class=\"verified\">Also reached from lead %s.</p>", htmlEscape(paste(label[others[-1]], collapse = ", ")))
    } else {
      ""
    }
    url <- leads$TaxonUrl[i]
    link <- if (nzchar(url)) sprintf("<a href=\"%s\" target=\"_blank\" rel=\"noopener\">More on FishBase</a>", htmlEscape(url)) else ""
    id <- taxonId[[tx]]
    sprintf(
      "<section class=\"taxon\" id=\"%s\" aria-labelledby=\"h-%s\">\n<p class=\"eyebrow\">Identified as</p>\n<h2 id=\"h-%s\" tabindex=\"-1\">%s</h2>\n%s%s<h3>Path through the key</h3>\n<ol class=\"diagnosis\"%s>\n%s\n</ol>\n<p class=\"actions\"><a href=\"#%s\">Identify another specimen</a>%s</p>\n</section>",
      id, id, id, htmlEscape(tx), verified, alsoVia, if (staticPaths) "" else " data-auto=\"1\"",
      paste(steps, collapse = "\n"), coupletId(check$root), link
    )
  }, character(1))

  warningsHtml <- if (length(check$problems) > 0) {
    sprintf("<div class=\"warnings\" role=\"note\"><strong>Problems found in this key</strong><ul>%s</ul></div>",
      paste0("<li>", htmlEscape(check$problems), "</li>", collapse = ""))
  } else {
    ""
  }
  citationHtml <- if (!is.na(citation) && nzchar(citation)) sprintf("<p class=\"cite\">%s</p>", htmlEscape(citation)) else ""

  mapHtml <- if (isTRUE(map)) renderMap(leads, check, coupletId, taxonId, nodeLabel) else ""

  css <- paste(readLines(system.file("wizard", "wizard.css", package = "moose"), warn = FALSE), collapse = "\n")
  js <- paste(readLines(system.file("wizard", "wizard.js", package = "moose"), warn = FALSE), collapse = "\n")

  paste0(
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n",
    "<meta name=\"theme-color\" content=\"#f6f3eb\" media=\"(prefers-color-scheme: light)\">\n",
    "<meta name=\"theme-color\" content=\"#131a1b\" media=\"(prefers-color-scheme: dark)\">\n",
    "<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n",
    "<meta name=\"mobile-web-app-capable\" content=\"yes\">\n",
    "<meta name=\"generator\" content=\"moose ", utils::packageVersion("moose"), "\">\n",
    "<title>", htmlEscape(title), "</title>\n<style>\n", css, "\n</style>\n", imageStyle(images), "</head>\n",
    "<body data-root=\"", coupletId(check$root), "\"", if (!isTRUE(displayLinks)) " class=\"nolinks\"" else "", ">\n",
    "<header class=\"masthead\">\n<p class=\"eyebrow\">Dichotomous key</p>\n<h1>", htmlEscape(title), "</h1>\n", citationHtml, "\n",
    "<nav class=\"toolbar\" aria-label=\"Key navigation\">",
    "<button type=\"button\" id=\"mk-back\" disabled>&larr; Back</button>",
    "<a href=\"#", coupletId(check$root), "\" id=\"mk-restart\">Start over</a>",
    "<span class=\"spacer\"></span>",
    if (isTRUE(map)) "<button type=\"button\" id=\"mk-maptoggle\" aria-controls=\"mk-map\" aria-expanded=\"false\">Map</button>" else "",
    "<button type=\"button\" id=\"mk-mode\" aria-pressed=\"false\"><span class=\"long\">Show full key</span><span class=\"short\">Full key</span></button></nav>\n",
    "<ol class=\"trail\" id=\"mk-trail\" aria-label=\"Choices so far\" aria-live=\"polite\"></ol>\n</header>\n",
    "<div class=\"columns", if (isTRUE(map)) " has-map" else "", "\">\n", mapHtml,
    "<main>\n", warningsHtml, "\n", paste(coupletHtml, collapse = "\n"), "\n",
    if (length(taxonHtml) > 0) "<h2 class=\"group\">Taxa</h2>\n" else "",
    paste(taxonHtml, collapse = "\n"), "\n", glossaryHtml(features, leads, coupletId, images), "\n</main>\n</div>\n",
    "<footer><p>", length(check$couplets), if (nodeLabel == "Couplet") " couplets, " else " steps, ",
    length(taxonNames), if (nodeLabel == "Couplet") " taxa. " else " possible results. ",
    "<span class=\"hint\">Press a, b (or 1, 2) to choose a lead. </span>",
    "Generated by the moose R package.</p></footer>\n",
    "<script>\n", js, "\n</script>\n</body>\n</html>\n"
  )
}

# ---- key map -----------------------------------------------------------------

# Inline SVG drawing of the key as a tree: couplets at their depth from the
# root (left to right), terminal leads as named leaves on the right. A couplet
# reached from more than one lead is drawn once; the extra links are dashed.
# Every node links to its section and carries data attributes the page script
# uses to mark the current position, the path so far and what is still ahead.
renderMap <- function(leads, check, coupletId, taxonId, nodeLabel = "Couplet") {
  label <- leadLabels(leads)
  # Long couplet names (e.g. haplogroups) do not fit inside a node: draw small
  # nodes and show names only along the user's path (see wizard.css).
  named <- max(nchar(check$couplets)) > 3
  rowH <- 20
  pad <- 14
  r <- if (named) 4.5 else 8.5

  nodes <- list()
  edges <- list()
  extra <- list()
  placed <- character()
  row <- 0

  visit <- function(cp, depth, anc) {
    placed <<- c(placed, cp)
    me <- coupletId(cp)
    ys <- numeric()
    for (i in which(leads$Statement == cp)) {
      nx <- leads$Next[i]
      if (nx == "-") {
        if (!nzchar(leads$Taxon[i])) next
        row <<- row + 1
        key <- paste0("L", i)
        nodes[[key]] <<- list(kind = "leaf", target = taxonId[[leads$Taxon[i]]], x = depth + 1, y = row,
                              label = leads$Taxon[i], anc = c(anc, me))
        edges[[length(edges) + 1]] <<- list(from = me, to = key, lead = label[i], text = leads$Character[i])
        ys <- c(ys, row)
      } else if (nx %in% check$couplets && !nx %in% placed) {
        ys <- c(ys, visit(nx, depth + 1, c(anc, me)))
        edges[[length(edges) + 1]] <<- list(from = me, to = coupletId(nx), lead = label[i], text = leads$Character[i])
      } else if (nx %in% placed) {
        extra[[length(extra) + 1]] <<- list(from = me, to = coupletId(nx), lead = label[i], text = leads$Character[i])
      }
    }
    if (length(ys) == 0) {
      row <<- row + 1
      ys <- row
    }
    y <- (min(ys) + max(ys)) / 2
    nodes[[me]] <<- list(kind = "couplet", target = me, x = depth, y = y, label = cp, anc = anc)
    y
  }
  visit(check$root, 0, character())

  leafNodes <- Filter(function(n) n$kind == "leaf", nodes)
  labelW <- if (length(leafNodes)) max(nchar(vapply(leafNodes, `[[`, "", "label"))) * 6.4 + 14 else 0
  depth <- max(1, vapply(nodes, `[[`, 0, "x"))
  # Narrow the columns (down to 20px) so typical keys fit a ~400px panel
  colW <- max(20, min(30, (400 - labelW - 2 * pad - r) / depth))
  px <- function(n) pad + r + n$x * colW
  py <- function(n) pad + (n$y - 1) * rowH
  width <- ceiling(pad + r + depth * colW + labelW + pad)
  height <- ceiling(2 * pad + (row - 1) * rowH)

  edgeSvg <- vapply(edges, function(e) {
    a <- nodes[[e$from]]
    b <- nodes[[e$to]]
    endX <- px(b) - if (b$kind == "couplet") r else 3.5
    sprintf(
      "<path class=\"medge\" data-from=\"%s\" data-to=\"%s\" d=\"M%.1f %.1fV%.1fH%.1f\"><title>%s %s</title></path>",
      e$from, b$target, px(a), py(a), py(b), endX,
      htmlEscape(e$lead), htmlEscape(e$text)
    )
  }, character(1))
  extraSvg <- vapply(extra, function(e) {
    a <- nodes[[e$from]]
    b <- nodes[[e$to]]
    sprintf(
      "<path class=\"medge cross\" data-from=\"%s\" data-to=\"%s\" d=\"M%.1f %.1fL%.1f %.1f\"><title>%s %s (also leads to couplet %s)</title></path>",
      e$from, e$to, px(a), py(a), px(b), py(b),
      htmlEscape(e$lead), htmlEscape(e$text), htmlEscape(b$label)
    )
  }, character(1))
  nodeSvg <- vapply(names(nodes), function(k) {
    n <- nodes[[k]]
    anc <- if (length(n$anc)) n$anc[length(n$anc)] else ""
    if (n$kind == "couplet") {
      sprintf(
        "<a class=\"mnode mcouplet\" href=\"#%s\" data-id=\"%s\" data-p=\"%s\" data-x=\"%.0f\" data-y=\"%.0f\" aria-label=\"%s %s\"><circle cx=\"%.1f\" cy=\"%.1f\" r=\"%.1f\"/><text x=\"%.1f\" y=\"%.1f\">%s</text></a>",
        n$target, n$target, anc, px(n), py(n), htmlEscape(nodeLabel), htmlEscape(n$label),
        px(n), py(n), r, if (named) px(n) + 6 else px(n), if (named) py(n) - 6 else py(n) + 3.2, htmlEscape(n$label)
      )
    } else {
      sprintf(
        "<a class=\"mnode mleaf\" href=\"#%s\" data-id=\"%s\" data-p=\"%s\" data-x=\"%.0f\" data-y=\"%.0f\" aria-label=\"%s\"><circle cx=\"%.1f\" cy=\"%.1f\" r=\"3.5\"/><text x=\"%.1f\" y=\"%.1f\">%s</text></a>",
        n$target, n$target, anc, px(n), py(n), htmlEscape(n$label),
        px(n), py(n), px(n) + 8, py(n) + 3.5, htmlEscape(n$label)
      )
    }
  }, character(1))

  nTaxa <- length(unique(vapply(leafNodes, `[[`, "", "target")))
  paste0(
    "<aside class=\"map\" id=\"mk-map\" aria-label=\"Map of the key\">\n",
    "<div class=\"map-head\"><span class=\"eyebrow\">Map of the key</span>",
    "<span class=\"map-count\" id=\"mk-left\" aria-live=\"polite\">", nTaxa, " taxa</span></div>\n",
    "<div class=\"map-scroll\" id=\"mk-map-scroll\">\n",
    sprintf("<svg class=\"keymap%s\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" xmlns=\"http://www.w3.org/2000/svg\">\n", if (named) " named" else "", width, height, width, height),
    "<g class=\"edges\">", paste(c(edgeSvg, extraSvg), collapse = ""), "</g>\n",
    "<g class=\"nodes\">", paste(nodeSvg, collapse = ""), "</g>\n</svg>\n</div>\n",
    "<p class=\"map-legend\"><span class=\"k here\"></span>You are here <span class=\"k done\"></span>Your path <span class=\"k ahead\"></span>Still possible</p>\n",
    "</aside>\n"
  )
}
