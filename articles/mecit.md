# Mixed-effects conditional inference trees on PhyloTree

A mixed-effects conditional inference tree (MECIT) is a decision tree
for clustered data. It finds splits on candidate variables while a
random effect absorbs differences between clusters. This vignette shows
why that matters for mitochondrial DNA, using expression data simulated
on PhyloTree Build 17.

## The problem: same mutation, many clades

Some mtDNA variants are **recurrent**: the same change arose
independently on many branches of the tree. If such a variant changes
expression, its effect shows up in many unrelated lineages. But lineages
also differ for reasons that have nothing to do with that variant. Each
large haplogroup (H, U, L3, …) has its own background. An ordinary tree
cannot tell the two apart. It happily splits on **clade markers**,
variants that simply track which haplogroup a sample is in, because they
explain the haplogroup backgrounds.

[`recurrentPositions()`](https://leipzig.github.io/dimoose/reference/recurrentPositions.md)
lists the recurrent sites, and
[`haplotypeMatrix()`](https://leipzig.github.io/dimoose/reference/haplotypeMatrix.md)
says which haplogroups carry them. Back-mutations are applied the way
Haplogrep defines them, so a site that is gained and later reverted is
not carried below the reversion:

``` r

library(dimoose)
head(recurrentPositions(), 8)
#>    site n_branches
#> 1   152        223
#> 2 16311        147
#> 3   146        132
#> 4   195        130
#> 5 16189        118
#> 6 16129         94
#> 7 16362         87
#> 8   150         79
haplotypeMatrix(c("H2a2a1", "U5b1", "L0a1b"), sites = c("16362", "150", "16278"))
#>        16362 150 16278
#> H2a2a1     0   0     1
#> U5b1       0   1     1
#> L0a1b      0   0     0
```

## Simulated data with known truth

[`simulateExpression()`](https://leipzig.github.io/dimoose/reference/simulateExpression.md)
samples leaf haplogroups and builds expression in which a few recurrent
sites shift some genes, on top of a random baseline for each
macrohaplogroup. Some genes have only the baseline, and some are pure
noise:

``` r

sim <- simulateExpression(n = 1000, genes = 20, seed = 1)
table(sim$truth$geneType)
#> 
#> mutation baseline     null 
#>        8        6        6
sim$effectSites   # sites that can carry real effects
#> [1] "16362" "150"   "709"   "16093"
sim$markerSites   # clade markers: no effect, but they track the baselines
#> [1] "489"   "10400" "14783" "15043" "2706"  "7028"  "11467" "12308" "12372"
```

## Fitting a MECIT

[`mecit()`](https://leipzig.github.io/dimoose/reference/mecit.md) takes
the response, the candidate split variables and the clusters. The
default method is RE-EM with conditional inference trees (Fu & Simonoff
2015). It alternates a
[`partykit::ctree()`](https://rdrr.io/pkg/partykit/man/ctree.html) on
the response, with the random-effect part removed, and an
[`lme4::lmer()`](https://rdrr.io/pkg/lme4/man/lmer.html) fit with one
level per terminal node. Random effects are estimated before the first
tree, so that tree never sees the haplogroup backgrounds:

``` r

g <- which(sim$truth$geneType == "mutation")[1]
colnames(sim$X)[sim$truth$beta[g, ] != 0]          # the truth
#> [1] "150"

fit <- mecit(sim$expr[, g], sim$X, cluster = sim$samples$macro)
fit
#> <dimoose mecit> ctree
#>   2 strata; splits on: 150
#>   random effects over 30 clusters; converged after 2 iteration(s)
```

The same tree without the random effect also splits on clade markers:

``` r

plain <- mecit(sim$expr[, g], sim$X, cluster = NULL)
splitVariables(plain)
#>  [1] "489"   "16311" "146"   "16189" "152"   "150"   "2706"  "12372" "16362"
#> [10] "16129" "15043"
intersect(splitVariables(plain), sim$markerSites)
#> [1] "489"   "2706"  "12372" "15043"
```

`method = "mob"` fits the model-based version through
[`glmertree::lmertree()`](https://rdrr.io/pkg/glmertree/man/glmertree.html)
(Fokkema et al. 2018).

## A MECIT is a key

A fitted tree turns into a dimoose key. Its couplets ask whether the
sample carries each split site, and its results are expression strata.
The key carries machine-readable tests, so
[`classify()`](https://leipzig.github.io/dimoose/reference/classify.md)
can place new samples from their haplotypes, and
[`exportWizard()`](https://leipzig.github.io/dimoose/reference/exportWizard.md)
draws it:

``` r

key <- keyFromMecit(fit)
key$leads[, c("Statement", "Character", "Next", "Taxon")]
#>   Statement          Character Next                      Taxon
#> 1         1        Carries 150    -  Stratum 3: 1.06 (n = 110)
#> 2         1 Does not carry 150    - Stratum 2: -0.04 (n = 890)
head(classify(key, sim$X))
#>   id                     result path
#> 1 s1 Stratum 2: -0.04 (n = 890)   1b
#> 2 s2 Stratum 2: -0.04 (n = 890)   1b
#> 3 s3  Stratum 3: 1.06 (n = 110)   1a
#> 4 s4 Stratum 2: -0.04 (n = 890)   1b
#> 5 s5 Stratum 2: -0.04 (n = 890)   1b
#> 6 s6 Stratum 2: -0.04 (n = 890)   1b
```

``` r

exportWizard(key, "mecit.html")
```

## Random slopes

When a mutation’s effect differs between macrohaplogroups, give it a
random slope. The slope variables are also entered as fixed effects, so
the random slopes are deviations around a shared slope rather than a
replacement for it:

``` r

fit2 <- mecit(sim$expr[, g], sim$X, sim$samples$macro,
              slope = colnames(sim$X)[sim$truth$beta[g, ] != 0])
splitVariables(fit2)
#> [1] "150"
```

## References

- Sela RJ, Simonoff JS (2012). RE-EM trees: a data mining approach for
  longitudinal and clustered data. *Machine Learning* 86, 169-207.
- Fu W, Simonoff JS (2015). Unbiased regression trees for longitudinal
  and clustered data. *Computational Statistics & Data Analysis* 88,
  53-74.
- Fokkema M, Smits N, Zeileis A, Hothorn T, Kelderman H (2018).
  Detecting treatment-subgroup interactions in clustered data with
  generalized linear mixed-effects model trees. *Behavior Research
  Methods* 50, 2016-2034.
- van Oven M (2015). PhyloTree Build 17: Growing the human mitochondrial
  DNA tree. *Forensic Science International: Genetics Supplement Series*
  5, e392-e394.
