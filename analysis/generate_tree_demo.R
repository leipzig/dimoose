# generateTree() with its three methods on a small made-up shark matrix.
# Run from the repository root: Rscript analysis/generate_tree_demo.R
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(quiet = TRUE)
} else {
  library(dimoose)
}

sharks <- data.frame(
  family = c("Carcharhinidae", "Sphyrnidae", "Lamnidae", "Carcharhinidae", "Sphyrnidae",
             "Lamnidae", "Carcharhinidae", "Sphyrnidae", "Lamnidae", "Carcharhinidae"),
  head_shape = c("pointed", "hammer", "pointed", "pointed", "hammer",
                 "pointed", "pointed", "hammer", "pointed", "pointed"),
  fin_type = c("rounded", "rounded", "pointed", "rounded", "rounded",
               "pointed", "rounded", "rounded", "pointed", "rounded"),
  body_size = c("large", "medium", "large", "medium", "medium",
                "large", "large", "medium", "large", "medium"),
  stringsAsFactors = TRUE
)

cat("1. rpart with the defaults (minsplit = 2, minbucket = 1, cp = 0)\n")
fit <- generateTree(sharks, "family")
print(fit)
print(keyFromRpart(fit, "Three shark families")$leads)

cat("\n   The same with rpart's own defaults, which make no split on ten rows\n")
print(generateTree(sharks, "family", params = list(control = rpart::rpart.control())))

cat("\n   One row per family, as in a character matrix\n")
matrix <- unique(sharks[c("family", "head_shape", "fin_type")])
print(keyFromRpart(generateTree(matrix, "family"))$leads)
matrix$family <- as.character(matrix$family)
print(keyFromMatrix(matrix, taxon = "family")$leads[c("Statement", "Choice", "Character", "Next", "Taxon")])

if (requireNamespace("randomForest", quietly = TRUE)) {
  cat("\n2. randomForest\n")
  set.seed(1)
  print(generateTree(sharks, "family", "randomForest"))
}

if (requireNamespace("gbm", quietly = TRUE)) {
  cat("\n3. gbm (multinomial, since family is a factor)\n")
  set.seed(1)
  boosted <- suppressWarnings(generateTree(sharks, "family", "gbm",
    params = list(n.trees = 10, interaction.depth = 1, n.minobsinnode = 1, bag.fraction = 0.7, cv.folds = 0)))
  print(boosted)
}
