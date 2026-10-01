# Synthetic "embeddings": k planted concept directions in d dimensions. Each
# label gets a fixed subset of concepts; each of its images has patches that
# are noisy copies of those concepts plus noise patches. Labels are "L1".."Ln".
syntheticVision <- function(n_labels = 6, per_label = 1, k = 4, p = 9, d = 8, seed = 1, noise = 0.05) {
  set.seed(seed)
  unit <- function(m) m / sqrt(rowSums(m^2))
  concepts <- unit(matrix(rnorm(k * d), k, d))
  has <- matrix(FALSE, n_labels, k)
  for (i in seq_len(n_labels)) has[i, ] <- as.logical(intToBits(i)[seq_len(k)])
  n <- n_labels * per_label
  patches <- array(0, c(n, p, d))
  image <- matrix(0, n, d)
  ids <- character(n)
  labels <- character(n)
  r <- 0
  for (i in seq_len(n_labels)) for (j in seq_len(per_label)) {
    r <- r + 1
    labels[r] <- paste0("L", i)
    ids[r] <- if (j == 1) labels[r] else paste0(labels[r], "_", j)
    own <- which(has[i, ])
    for (q in seq_len(p)) {
      base <- if (length(own) && q <= length(own)) concepts[own[q], ] else rnorm(d)
      patches[r, q, ] <- base + noise * rnorm(d)
    }
    patches[r, , ] <- unit(patches[r, , ])
    image[r, ] <- colMeans(patches[r, , ])
  }
  image <- unit(image)
  dimnames(patches) <- list(ids, NULL, NULL)
  rownames(image) <- ids
  list(images = data.frame(id = ids, path = paste0("/synthetic/", ids, ".png"), label = labels, stringsAsFactors = FALSE),
       image = image, patches = patches, concepts = concepts, has = has)
}
