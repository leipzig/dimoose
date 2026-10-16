#' Draw a key as a box diagram
#'
#' Draws a dimoose key top-down as an SVG picture, the way keys are often
#' drawn on paper: each couplet is a blue box holding its question, its leads
#' are blue boxes below it, and every lead either continues to the next
#' couplet or ends in a green box naming the result. A result written as
#' `"Common name (Genus species)"` is drawn on two lines with the scientific
#' name in italics.
#'
#' A couplet reached from more than one lead is drawn once, under the first
#' of them; the other leads get a dashed line to it.
#'
#' @param key A [dimoose] key.
#' @param file Optional path of an `.svg` file to write.
#' @param images If `TRUE`, show a thumbnail in a result's box when the
#'   terminal lead names an image (`Image` column) that is embedded in the
#'   key's `meta` (see [imageMeta()]).
#' @param title Heading drawn above the tree; by default the key's `desc`.
#'   Use `NA` for none.
#' @return The SVG as a single string, invisibly when `file` is given.
#' @seealso [exportWizard()] for an interactive version of the key.
#' @examples
#' keyDiagram(arachnidaKey(), tempfile(fileext = ".svg"))
#' @export
keyDiagram <- function(key, file = NULL, images = TRUE, title = NULL) {
  if (!inherits(key, "dimoose")) stop("`key` must be a dimoose object", call. = FALSE)
  leads <- normalizeLeads(key$leads)
  check <- checkLeads(leads)
  label <- leadLabels(leads)
  pics <- if (isTRUE(images)) embeddedImages(key$meta) else character()
  if (is.null(title)) {
    title <- if (length(key$desc) == 1 && !is.na(key$desc) && nzchar(key$desc)) as.character(key$desc) else NA
  }

  boxW <- 190; gapX <- 16; gapY <- 28; pad <- 8; lineH <- 16; thumbH <- 64; margin <- 20
  wrap <- function(x) {
    out <- strwrap(x, width = 26)
    if (length(out)) out else ""
  }
  box <- function(kind, lines, style = rep("", length(lines)), thumb = NA_character_, kids = list(), id = NA_character_) {
    h <- 2 * pad + length(lines) * lineH + if (!is.na(thumb)) thumbH else 0
    w <- if (length(kids)) max(boxW, sum(vapply(kids, `[[`, 0, "w")) + gapX * (length(kids) - 1)) else boxW
    list(kind = kind, lines = lines, style = style, thumb = thumb, kids = kids, id = id, h = h, w = w)
  }

  drawn <- character()
  shared <- list()
  taxonBox <- function(i) {
    tx <- leads$Taxon[i]
    m <- regmatches(tx, regexec("^(.*\\S)\\s*\\(([^()]+)\\)$", tx))[[1]]
    if (length(m) == 3) {
      common <- wrap(m[2]); sci <- wrap(m[3])
      lines <- c(common, sci); style <- c(rep("bold", length(common)), rep("italic", length(sci)))
    } else {
      lines <- wrap(tx); style <- rep("bold", length(lines))
    }
    ids <- splitUrls(leads$Image[i])
    found <- ids[ids %in% names(pics)]
    box("kd-taxon", lines, style, thumb = if (length(found)) pics[[found[1]]] else NA_character_)
  }
  couplet <- function(cp) {
    drawn <<- c(drawn, cp)
    rows <- which(leads$Statement == cp)
    q <- leads$Question[rows][nzchar(leads$Question[rows])]
    text <- paste0(cp, ". ", if (length(q)) q[1] else paste("Couplet", cp))
    kids <- lapply(rows, function(i) {
      nx <- leads$Next[i]
      child <- list()
      if (nx == "-") {
        if (nzchar(leads$Taxon[i])) child <- list(taxonBox(i))
      } else if (nx %in% check$couplets && !nx %in% drawn) {
        child <- list(couplet(nx))
      } else if (nx %in% drawn) {
        shared[[length(shared) + 1]] <<- list(lead = i, to = nx)
      }
      box("kd-lead", wrap(paste0(label[i], ". ", leads$Character[i])), kids = child, id = as.character(i))
    })
    box("kd-question", wrap(text), rep("bold", length(wrap(text))), kids = kids, id = cp)
  }
  root <- couplet(check$root)

  # Place every box: each subtree gets its own width, children left to right
  top0 <- margin + if (!is.na(title)) 40 else 0
  rects <- character(); texts <- character(); links <- character()
  pos <- list()
  place <- function(n, left, top) {
    x <- left + (n$w - boxW) / 2
    pos[[paste(n$kind, n$id)]] <<- c(x = x, y = top, h = n$h)
    rects <<- c(rects, sprintf(
      "<rect class=\"%s\" x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" rx=\"4\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>",
      n$kind, x, top, boxW, n$h, if (n$kind == "kd-taxon") "#dcfce7" else "#dbeafe",
      if (n$kind == "kd-taxon") "#166534" else "#1e3a8a"))
    y <- top + pad
    if (!is.na(n$thumb)) {
      rects <<- c(rects, sprintf(
        "<image class=\"kd-thumb\" href=\"%s\" x=\"%.1f\" y=\"%.1f\" width=\"56\" height=\"56\" preserveAspectRatio=\"xMidYMid slice\"/>",
        n$thumb, x + (boxW - 56) / 2, y))
      y <- y + thumbH
    }
    for (k in seq_along(n$lines)) {
      attr <- switch(n$style[k], bold = " font-weight=\"bold\"", italic = " font-style=\"italic\"", "")
      texts <<- c(texts, sprintf("<text class=\"kd-text\" x=\"%.1f\" y=\"%.1f\" text-anchor=\"middle\" font-size=\"13\"%s>%s</text>",
        x + boxW / 2, y + k * lineH - 4, attr, htmlEscape(n$lines[k])))
    }
    if (length(n$kids)) {
      total <- sum(vapply(n$kids, `[[`, 0, "w")) + gapX * (length(n$kids) - 1)
      cl <- left + (n$w - total) / 2
      childTop <- top + n$h + gapY
      for (kid in n$kids) {
        cx <- cl + kid$w / 2
        links <<- c(links, sprintf("<path class=\"kd-link\" d=\"M%.1f %.1fV%.1fH%.1fV%.1f\" fill=\"none\" stroke=\"#333\" stroke-width=\"1.2\"/>",
          x + boxW / 2, top + n$h, top + n$h + gapY / 2, cx, childTop))
        place(kid, cl, childTop)
        cl <- cl + kid$w + gapX
      }
    }
  }
  place(root, margin, top0)
  for (s in shared) {
    a <- pos[[paste("kd-lead", s$lead)]]
    b <- pos[[paste("kd-question", s$to)]]
    x1 <- a[["x"]] + boxW / 2; y1 <- a[["y"]] + a[["h"]]
    x2 <- b[["x"]] + boxW / 2; y2 <- b[["y"]]
    links <- c(links, sprintf("<path class=\"kd-shared\" d=\"M%.1f %.1fC%.1f %.1f %.1f %.1f %.1f %.1f\" fill=\"none\" stroke=\"#333\" stroke-width=\"1.2\" stroke-dasharray=\"5 4\"/>",
      x1, y1, x1, y1 + 60, x2, y2 - 60, x2, y2))
  }

  width <- ceiling(root$w + 2 * margin)
  height <- ceiling(max(vapply(pos, function(p) p[["y"]] + p[["h"]], 0)) + margin)
  svg <- paste0(
    sprintf("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" font-family=\"Helvetica, Arial, sans-serif\">\n",
      width, height, width, height),
    if (!is.na(title)) paste0("<title>", htmlEscape(title), "</title>\n"),
    "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n",
    if (!is.na(title)) sprintf("<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"middle\" font-size=\"20\" font-weight=\"bold\">%s</text>\n",
      width / 2, margin + 20, htmlEscape(title)),
    paste(links, collapse = "\n"), "\n",
    paste(rects, collapse = "\n"), "\n",
    paste(texts, collapse = "\n"), "\n",
    "</svg>\n"
  )
  if (is.null(file)) return(svg)
  con <- file(file, "w", encoding = "UTF-8")
  on.exit(close(con))
  writeLines(c("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", sub("\n$", "", svg)), con)
  invisible(svg)
}
