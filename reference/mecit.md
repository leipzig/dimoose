# Mixed-effects conditional inference trees

Fits a tree that partitions observations on candidate split variables
(for example which mutations each sample carries, from
[`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md))
while a random effect absorbs differences between clusters (for example
macrohaplogroups, from
[`macroHaplogroup()`](https://leipzig.github.io/dimoose/reference/macroHaplogroup.md)).
Without the random effect, a tree also splits on variables that merely
track the clusters, such as clade-defining markers; with it, those
differences are removed before the tree looks for splits.

## Usage

``` r
mecit(
  y,
  partition,
  cluster = NULL,
  method = c("ctree", "mob"),
  slope = NULL,
  alpha = 0.05,
  minbucket = 20L,
  maxdepth = Inf,
  ranefstart = TRUE,
  abstol = 0.001,
  maxit = 50L
)
```

## Arguments

- y:

  Numeric response, one value per observation.

- partition:

  Matrix or data frame of candidate split variables, one row per
  observation, with column names (which may be non-syntactic, like
  `"16311"`).

- cluster:

  Cluster of each observation, or `NULL` for no random effect.

- method:

  `"ctree"` or `"mob"`.

- slope:

  Optional names of `partition` columns to give random slopes within
  clusters, as in `(1 + slope | cluster)`.

- alpha:

  Significance level for splitting (Bonferroni-adjusted over the
  candidate variables).

- minbucket:

  Smallest allowed terminal node.

- maxdepth:

  Maximum tree depth.

- ranefstart:

  If `TRUE`, start from random effects estimated without a tree.

- abstol, maxit:

  Convergence tolerance and the maximum number of iterations. For
  `"ctree"` the tolerance is on the largest change in any observation's
  random-effect contribution; for `"mob"` it is passed to
  [`glmertree::lmertree()`](https://rdrr.io/pkg/glmertree/man/glmertree.html),
  where it applies to the change in log-likelihood.

## Value

An object of class `mecit`: `tree` (a partykit tree), `lmer` (the final
mixed model, or `NULL`), `strata` (data frame of `node`, `mean` and `n`;
`mean` is the stratum level net of random effects), `node` (terminal
node of each observation), `ranef` (random-effect contribution of each
observation), `method`, `iterations` and `converged`.

## Details

`method = "ctree"` (the default) is the RE-EM algorithm of Sela &
Simonoff (2012) with conditional inference trees, as proposed by Fu &
Simonoff (2015). It alternates between (1) a
[`partykit::ctree()`](https://rdrr.io/pkg/partykit/man/ctree.html) on
the response minus the current random-effect contribution and (2) a
linear mixed model
([`lme4::lmer()`](https://rdrr.io/pkg/lme4/man/lmer.html)) with one
fixed effect per terminal node plus the random effects, until the random
effects stop changing. `method = "mob"` uses model-based partitioning
through
[`glmertree::lmertree()`](https://rdrr.io/pkg/glmertree/man/glmertree.html)
(Fokkema et al. 2018). In both, `ranefstart = TRUE` estimates the random
effects from an intercept-only mixed model before the first tree, which
keeps that tree from splitting on cluster-level variables.

With `cluster = NULL` the result is a plain conditional inference tree,
the baseline a mixed-effects tree is compared with.

## References

Sela RJ, Simonoff JS (2012). RE-EM trees: a data mining approach for
longitudinal and clustered data. *Machine Learning* 86, 169-207.
[doi:10.1007/s10994-011-5258-3](https://doi.org/10.1007/s10994-011-5258-3)

Fu W, Simonoff JS (2015). Unbiased regression trees for longitudinal and
clustered data. *Computational Statistics & Data Analysis* 88, 53-74.
[doi:10.1016/j.csda.2015.02.004](https://doi.org/10.1016/j.csda.2015.02.004)

Fokkema M, Smits N, Zeileis A, Hothorn T, Kelderman H (2018). Detecting
treatment-subgroup interactions in clustered data with generalized
linear mixed-effects model trees. *Behavior Research Methods* 50,
2016-2034.
[doi:10.3758/s13428-017-0971-x](https://doi.org/10.3758/s13428-017-0971-x)

## See also

[`splitVariables()`](https://leipzig.github.io/dimoose/reference/splitVariables.md),
[`keyFromMecit()`](https://leipzig.github.io/dimoose/reference/keyFromMecit.md),
[`simulateExpression()`](https://leipzig.github.io/dimoose/reference/simulateExpression.md)

## Examples

``` r
if (FALSE) { # \dontrun{
sim <- simulateExpression(n = 600, genes = 6)
fit <- mecit(sim$expr[, 1], sim$X, sim$samples$macro)
fit
exportWizard(keyFromMecit(fit), "mecit.html")
} # }
```
