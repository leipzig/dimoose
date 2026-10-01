# MECITs on simulated PhyloTree expression data

Reproduce with `Rscript analysis/mecit/run.R` from the package root (about 1.5
minutes). Raw results are in `results.csv` and `results-slopes.csv`, and the
summaries are in `summary.rds`. `example-mecit.html` is the wizard for one fitted tree.

## Design

`simulateExpression()` samples 1,000 leaf haplogroups uniformly from PhyloTree
Build 17 and builds 20 genes, split into three groups:

- **mutation** genes (40%): shifted by 1–2 of the effect sites (16362, 150, 709,
  16093), plus a macrohaplogroup baseline. These are recurrent sites, carried
  by 5–18% of leaves across many macrohaplogroups.
- **baseline** genes (30%): the macrohaplogroup baseline only, with no mutation
  effect.
- **null** genes: noise only.

Candidate split variables are the effect sites plus decoys:

- the most recurrent sites that are not effect sites (152, 16311, 146, 16189, ...);
- the clade markers of the four largest macrohaplogroups.

The clade markers have no effect, but they track the baselines, which is the
confound a MECIT is meant to remove.

The grid is effect ∈ {0.5, 1, 2} SD × macro SD ∈ {0.5, 1, 2} × 2 seeds, giving
18 scenarios and 360 genes. "Power" is the fraction of a gene's true sites the
method splits on (or calls significant). "False splits" counts any other
variable it uses.

| method | what it is |
|---|---|
| MECIT (ctree) | `mecit()`: RE-EM with conditional inference trees (Fu & Simonoff 2015), random intercept per macrohaplogroup |
| MECIT (mob) | `mecit(method = "mob")`: `glmertree::lmertree` (Fokkema et al. 2018) |
| ctree | the same tree with no random effect |
| rpart | CART, minbucket 20, cp 0.01 |
| LM + macro | `lm(y ~ factor(macro) + X)`, Bonferroni p < 0.05 / #sites |
| LM | `lm(y ~ X)`, Bonferroni |

## Results

**Mutation genes** (mean over all scenarios)

| method | power | false splits / gene | clade-marker splits / gene |
|---|---:|---:|---:|
| MECIT (ctree) | 0.83 | **0.00** | **0.00** |
| MECIT (mob) | 0.73 | 0.06 | 0.00 |
| ctree | 0.86 | 6.78 | 3.24 |
| rpart | 0.79 | 5.43 | 2.85 |
| LM + macro | 0.93 | 0.06 | 0.06 |
| LM | 0.83 | 4.42 | 2.19 |

**Baseline genes** (no real mutation effect): fraction of genes with any false
split or call

| method | genes with a false split | false splits / gene |
|---|---:|---:|
| MECIT (ctree) | **0%** | 0.00 |
| MECIT (mob) | 0% | 0.00 |
| ctree | 100% | 6.69 |
| rpart | 100% | 5.64 |
| LM + macro | 0% | 0.00 |
| LM | 92% | 4.44 |

On null genes no method made a false split, apart from LM (8%).

**Power by effect size** (MECIT (ctree); same at every macro SD for effect ≥ 1)

| effect (SD) | macro SD 0.5 | 1 | 2 |
|---:|---:|---:|---:|
| 0.5 | 0.56 | 0.44 | 0.44 |
| 1 | 1.00 | 1.00 | 1.00 |
| 2 | 1.00 | 1.00 | 1.00 |

Plain ctree's false splits grow with baseline strength: 3.8, 7.2 and 9.4 per
gene at macro SD 0.5, 1 and 2. MECIT's stay at zero.

**Random slopes** (effect 1, macro SD 1, slope SD 1: each site's effect varies
by macrohaplogroup; 2 seeds)

| method | power | false splits | marker splits |
|---|---:|---:|---:|
| MECIT (ctree), intercept only | 0.91 | 0.06 | 0.00 |
| MECIT (ctree), slopes on true sites | 1.00 | 0.00 | 0.00 |
| ctree | 0.91 | 7.38 | 3.69 |

## Interpretation

- **Among tree methods, only the MECIT controls the clade-marker confound.** Plain ctree and rpart split
  on every baseline gene and use 3 clade markers per mutation gene on average.
  That is the failure mode the random effect removes.
- **Its trees are not over-fit.** MECIT (ctree) made no false splits in all 360 gene fits. Because
  `ranefstart = TRUE`, the first tree never sees the haplogroup backgrounds.
- **It is conservative at small effects.** At 0.5 SD it finds 44–56% of true sites, against 78% for
  LM + macro. The ctree significance test is a strict gate. Raising `alpha` trades
  some of that conservatism for power.
- **`mob` is lower-powered here.** At 0.5 SD it finds 22–34% of true sites.
- **LM + macro is a strong comparator** when the candidate sites and the
  model are right. It gives no tree, though: no strata, no interactions, no key to
  follow. The MECIT delivers comparable error control *and* a dichotomous key
  (`keyFromMecit()`).
- **Random slopes help when effects vary by lineage.** They recover full power, and
  intercept-only fits still control false splits.

## Notes on the setup

- **Effect sites.** Sites like 152, 16311, 146 and 16189 are the most recurrent in
  PhyloTree, but they are poor effect sites: in RSRS orientation most leaves
  carry them because deep branches gained them (16311 is an L3 marker), so they
  behave like clade markers. The defaults are therefore recurrent sites carried
  by 5–18% of leaves. The common sites are kept as decoys.
- **LM + macro term order.** It must be fitted as `y ~ factor(macro) + X`.
  With `y ~ X + factor(macro)`, clade markers collinear with the macro dummies
  keep their coefficients and the macro dummies are the ones dropped as aliased.
  This produced a spurious 50% false-call rate on baseline genes in an earlier run.

## References

- Sela RJ, Simonoff JS (2012). RE-EM trees: a data mining approach for
  longitudinal and clustered data. *Machine Learning* 86, 169–207.
  doi:10.1007/s10994-011-5258-3
- Fu W, Simonoff JS (2015). Unbiased regression trees for longitudinal and
  clustered data. *Computational Statistics & Data Analysis* 88, 53–74.
  doi:10.1016/j.csda.2015.02.004
- Fokkema M, Smits N, Zeileis A, Hothorn T, Kelderman H (2018). Detecting
  treatment-subgroup interactions in clustered data with generalized linear
  mixed-effects model trees. *Behavior Research Methods* 50, 2016–2034.
  doi:10.3758/s13428-017-0971-x
