# Build data/arachnida.rda: the Key to the Orders of Arachnida from Triplehorn
# & Johnson (2005), Borror and DeLong's Introduction to the Study of Insects,
# 7th ed., chapter 5, as transcribed in arachnida_key.txt (one lead per line,
# in the book's couplet notation). Run from the package root.
lines <- readLines("data-raw/arachnida/arachnida_key.txt", encoding = "UTF-8")
m <- regmatches(lines, regexec("^(\\d+)('?)(\\((\\d+'?)\\))?\\.\\s+(.*)$", lines))
stopifnot(all(lengths(m) == 6))
statement <- vapply(m, `[`, "", 2)
choice <- ifelse(vapply(m, `[`, "", 3) == "'", "b", "a")
text <- vapply(m, `[`, "", 6)

goto <- regmatches(text, regexec("^(.*\\S)\\s+(\\d+)$", text))
terminal <- regmatches(text, regexec("^(.*\\S)\\s+([A-Z][a-z]+)\\s+p\\.\\s*(\\d+)$", text))
isTerminal <- lengths(terminal) == 4
isGoto <- lengths(goto) == 3 & !isTerminal
stopifnot(all(isGoto | isTerminal), !any(isGoto & isTerminal))

arachnida <- data.frame(
  Statement = statement,
  Choice = choice,
  Character = ifelse(isGoto, vapply(goto, `[`, "", 2), vapply(terminal, function(x) if (length(x)) x[2] else "", "")),
  Next = ifelse(isGoto, vapply(goto, function(x) if (length(x)) x[3] else "", ""), "-"),
  Taxon = ifelse(isTerminal, vapply(terminal, function(x) if (length(x)) x[3] else "", ""), ""),
  Page = ifelse(isTerminal, as.integer(vapply(terminal, function(x) if (length(x)) x[4] else NA_character_, "")), NA_integer_),
  stringsAsFactors = FALSE
)
stopifnot(nrow(arachnida) == 22, all(arachnida$Next[arachnida$Next != "-"] %in% arachnida$Statement))
save(arachnida, file = "data/arachnida.rda", compress = "xz", version = 2)
