# Method comparison for mixed-effects conditional inference trees (MECITs)
# on simulated PhyloTree expression data. See REPORT.md.
# Run from the package root:  Rscript analysis/mecit/run.R
suppressMessages(pkgload::load_all(Sys.getenv("DIMOOSE_PKG", "."), quiet = TRUE))
out <- Sys.getenv("MECIT_OUT", "analysis/mecit")

lmFound <- function(y, X, macro = NULL) {
  # macro first, so markers collinear with the macro dummies are the ones aliased
  f <- if (is.null(macro)) stats::lm(y ~ X) else stats::lm(y ~ factor(macro) + X)
  p <- summary(f)$coefficients
  rows <- intersect(paste0("X", colnames(X)), rownames(p))
  sub("^X", "", rows[p[rows, 4] < 0.05 / ncol(X)])
}
rpartFound <- function(y, X) {
  d <- data.frame(y = y, X, check.names = FALSE)
  names(d) <- c("y", make.names(colnames(X)))
  f <- rpart::rpart(y ~ ., d, control = rpart::rpart.control(minbucket = 20, cp = 0.01, xval = 0))
  v <- unique(as.character(f$frame$var[f$frame$var != "<leaf>"]))
  colnames(X)[match(v, make.names(colnames(X)))]
}
methods <- list(
  "MECIT (ctree)" = function(y, X, macro) splitVariables(mecit(y, X, macro)),
  "MECIT (mob)"   = function(y, X, macro) splitVariables(mecit(y, X, macro, method = "mob")),
  "ctree"         = function(y, X, macro) splitVariables(mecit(y, X, NULL)),
  "rpart"         = function(y, X, macro) rpartFound(y, X),
  "LM + macro"    = function(y, X, macro) lmFound(y, X, macro),
  "LM"            = function(y, X, macro) lmFound(y, X)
)

score <- function(sim, found, g) {
  truth <- colnames(sim$X)[sim$truth$beta[g, ] != 0]
  data.frame(geneType = as.character(sim$truth$geneType[g]),
             power = if (length(truth)) mean(truth %in% found) else NA_real_,
             falseSplits = length(setdiff(found, truth)),
             markerSplits = length(intersect(found, sim$markerSites)),
             anyFalse = length(setdiff(found, truth)) > 0)
}

runScenario <- function(effect, macroSD, seed, slopeSD = 0, methodsUsed = methods) {
  sim <- simulateExpression(n = 1000, genes = 20, effect = effect, macroSD = macroSD,
                            slopeSD = slopeSD, seed = seed)
  do.call(rbind, lapply(seq_len(ncol(sim$expr)), function(g) {
    do.call(rbind, lapply(names(methodsUsed), function(m) {
      found <- methodsUsed[[m]](sim$expr[, g], sim$X, sim$samples$macro)
      cbind(data.frame(effect = effect, macroSD = macroSD, slopeSD = slopeSD, seed = seed,
                       gene = g, method = m), score(sim, found, g))
    }))
  }))
}

# ---- Main sweep: effect size x baseline strength x 2 seeds -------------------
grid <- expand.grid(effect = c(0.5, 1, 2), macroSD = c(0.5, 1, 2), seed = 1:2)
t0 <- Sys.time()
res <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  r <- runScenario(grid$effect[i], grid$macroSD[i], grid$seed[i])
  message(sprintf("scenario %d/%d done (%.0fs)", i, nrow(grid), as.numeric(Sys.time() - t0, units = "secs")))
  r
}))
utils::write.csv(res, file.path(out, "results.csv"), row.names = FALSE)

# ---- Random-slope scenario ----------------------------------------------------
slopeMethods <- list(
  "MECIT (ctree)" = methods[["MECIT (ctree)"]],
  "ctree" = methods[["ctree"]]
)
slopeRes <- do.call(rbind, lapply(1:2, function(s) runScenario(1, 1, s, slopeSD = 1, methodsUsed = slopeMethods)))
# oracle random slopes on each gene's true effect sites
slopeOracle <- do.call(rbind, lapply(1:2, function(s) {
  sim <- simulateExpression(n = 1000, genes = 20, effect = 1, macroSD = 1, slopeSD = 1, seed = s)
  do.call(rbind, lapply(which(sim$truth$geneType == "mutation"), function(g) {
    truth <- colnames(sim$X)[sim$truth$beta[g, ] != 0]
    found <- splitVariables(mecit(sim$expr[, g], sim$X, sim$samples$macro, slope = truth))
    cbind(data.frame(effect = 1, macroSD = 1, slopeSD = 1, seed = s, gene = g,
                     method = "MECIT (ctree, slopes)"), score(sim, found, g))
  }))
}))
utils::write.csv(rbind(slopeRes, slopeOracle), file.path(out, "results-slopes.csv"), row.names = FALSE)

# ---- Summaries ----------------------------------------------------------------
summarise <- function(r) {
  mut <- r[r$geneType == "mutation", ]
  nonmut <- r[r$geneType != "mutation", ]
  a <- stats::aggregate(cbind(power, falseSplits, markerSplits) ~ method, mut, mean)
  b <- stats::aggregate(cbind(anyFalse = as.numeric(anyFalse), falseSplits) ~ method + geneType, nonmut, mean)
  list(mutation = a, other = b)
}
s <- summarise(res)
byScenario <- stats::aggregate(cbind(power, falseSplits) ~ method + effect + macroSD,
                               res[res$geneType == "mutation", ], mean)
print(s); print(byScenario)
print(stats::aggregate(cbind(power, falseSplits, markerSplits) ~ method, rbind(slopeRes, slopeOracle)[rbind(slopeRes, slopeOracle)$geneType == "mutation", ], mean))
saveRDS(list(summary = s, byScenario = byScenario), file.path(out, "summary.rds"))

# ---- Example wizard -----------------------------------------------------------
sim <- simulateExpression(n = 1000, genes = 20, seed = 1)
g <- which(sim$truth$geneType == "mutation")[1]
fit <- mecit(sim$expr[, g], sim$X, sim$samples$macro)
exportWizard(keyFromMecit(fit, desc = sprintf("MECIT for simulated %s (true effect sites: %s)",
  colnames(sim$expr)[g], paste(colnames(sim$X)[sim$truth$beta[g, ] != 0], collapse = ", "))),
  file.path(out, "example-mecit.html"))
message("done in ", format(Sys.time() - t0))
