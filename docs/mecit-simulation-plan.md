# Simulation plan: mixed-effects conditional inference trees (MECITs) on PhyloTree expression data

Draft plan, 2026-09-30. moose lists "build mixed effects conditional inference trees (mecits)" as a capability; this is the study that exercises and validates it, using **simulated** mitochondrial expression data placed on PhyloTree Build 17 (which moose already ships as `phylotree17` and `phylotree17_mutations`).

## The idea in one line

Simulate per-sample expression where **recurrent mutations** (variants that arise independently at many points in the tree) each shift expression by a fixed amount, **on top of** baseline expression that differs between **large haplogroups**; then show that a mixed-effects conditional inference tree recovers the mutation effects as tree splits while absorbing the haplogroup baseline as a random effect — and that ignoring the haplogroup structure gives false splits.

## Why this is the right testbed

- **Two signals that must be separated.** Recurrent mutations are the *fixed, splittable* effect a tree should find; haplogroup membership is a *grouping/confounding* effect that an ordinary tree would wrongly split on. A MECIT (tree for the fixed part + random effects for the grouping) is exactly the tool, and the simulation has ground truth.
- **PhyloTree gives both for free.** From `phylotree17_mutations`:
  - **Recurrent variants are real and abundant.** Position 152 appears on **223** branches, 16311 on **147**, 146 on **132**, plus 16189, 16129, 16362, 150, 709, 16093… and there are **1,182 back-mutations**. These are the textbook homoplasies — the same variant in many unrelated lineages — so a mutation effect genuinely crosses haplogroup boundaries.
  - **Large haplogroups are real groupings.** By leading macro-label the tree has H (1,071 haplogroups), M (685), U (533), D (334), B (322), J (241), T (230), L3 (201), K, R, A, L0, C, L2, N… — natural random-effect levels with very different sizes.
- moose already turns the tree into the mutation-by-haplogroup design matrix the model needs, and ships the data, so the whole study is reproducible from the package.

## Ground-truth generative model

Pick a set of samples by sampling haplogroups from `phylotree17` (e.g. 2,000 samples, each assigned a terminal or internal haplogroup, with realistic class imbalance). For sample *i* in haplogroup *h(i)*:

```
expression_ig  =  mu_g                         # gene baseline
               +  b_{g, macro(h(i))}            # haplogroup random effect (large-group baseline shift)
               +  sum_m  beta_{g,m} * carries(h(i), m)   # recurrent-mutation fixed effects
               +  eps_ig                        # noise
```

- **`carries(h, m)`** = does haplogroup *h*'s path from the root include mutation *m*? This is computed from `phylotree17_mutations` by walking parents — moose's job (see "What moose provides").
- **Recurrent-mutation effects `beta_{g,m}`.** Choose a handful of recurrent positions (e.g. 152, 16311, 146, 16189) and give each a nonzero effect on a few genes. Because these positions recur across the tree, the same effect appears in many unrelated haplogroups — the signal a MECIT should recover as a split, not as a lineage artifact.
- **Large-haplogroup effects `b_{g, macro}`.** Draw a random intercept per macro-haplogroup (H, M, U, L0…) per gene, so each big clade has its own baseline. Optionally a random slope so a mutation's effect differs between clades (the interesting, harder case).
- Simulate tens of genes: some driven by recurrent mutations, some only by haplogroup baseline, some pure noise (negatives).

Everything is a known truth, so every method is scored against it.

## Models compared

For each gene (or jointly, multivariate):

1. **MECIT — `glmertree::lmertree`** (the headline). Partition on **mutation-presence** variables (the `carries` columns) with `ctree`-style conditional inference, and put **`(1 | macro_haplogroup)`** (optionally `(1 + mutation | macro)`) as the random part. Expect: splits on exactly the mutations with nonzero `beta`, and the haplogroup baseline soaked up by the random effect.
2. **Plain conditional inference tree — `partykit::ctree`** on the same mutation variables, no random effect. Expect: it also splits on haplogroup-correlated mutations and invents spurious splits where a big clade's baseline mimics a mutation effect — the failure the MECIT fixes.
3. **Fixed-effects linear model** with mutation terms only, and one with mutation + macro-haplogroup fixed effects (the "control for clade by brute force" baseline).
4. **rpart** (what moose already uses for `keyFromRpart`) on mutation variables, as the naive-tree reference.

## What moose provides (and what to add)

Already in moose:
- `phylotree17`, `phylotree17_mutations` — the tree and its per-branch variants.
- `keyFromRpart()` / the lead-table machinery — the tree-to-key path, reused to render any fitted tree as a moose key and wizard.

Small additions this study motivates (all thin, on the existing data):
- **`haplotypeMatrix(haplogroups, positions)`** — a samples × mutations 0/1 matrix giving `carries(h, m)` by walking each haplogroup's path to the root in `phylotree17`/`phylotree17_mutations`. This is the design matrix for every model and is generally useful (it is also what a classifier like Haplogrep uses).
- **`recurrentPositions(min_branches)`** — the positions that occur on at least *n* branches (the homoplasy list; the numbers above come straight from it).
- **`macroHaplogroup(haplogroup)`** — map a haplogroup to its macro-clade (its ancestor at a chosen depth, or leading label), for the random-effect grouping.
- **`simulateExpression(...)`** — the generative model above, returning a tidy data frame plus the stored truth (`beta`, `b`, which genes are null).
- **`mecit(formula, data, cluster=)`** — a thin wrapper over `glmertree::lmertree` that accepts moose's matrices and can hand the fitted tree back to `keyFromRpart`-style rendering so a MECIT is viewable in the wizard. `glmertree`, `partykit`, `lme4` become Suggests.

## Experiments and figures

- **Fig 1.** The generative model: tree with a few recurrent mutations highlighted at their many branch points, and the per-macro baseline — the picture of "same mutation, many clades."
- **Fig 2.** Recovery: for the MECIT vs ctree vs rpart vs LM, true-positive mutation effects found and false splits made, swept over effect size, noise, sample size and class imbalance. The headline: MECIT recovers mutation effects with far fewer false splits than the random-effect-blind trees.
- **Fig 3.** A single fitted MECIT rendered as a moose wizard — splits are mutation presences, leaves are expression strata — showing the capability end to end.
- **Fig 4.** Random-slope case: when a mutation's effect differs between macro-haplogroups, the MECIT's random slopes capture it while a fixed tree splits the clade spuriously.
- **Fig 5.** Calibration: type-I error on the null genes (no mutation effect) — does conditional inference hold its nominal level once the random effect is in?
- **Table 1.** The recurrent positions used, their branch counts, and the assigned effects.

## Expected results

- The MECIT recovers the planted recurrent-mutation effects as splits and controls type-I error on null genes, because the haplogroup random effect removes the clade baseline that otherwise leaks into the tree.
- Plain ctree/rpart over-split, confounding "big clade baseline" with "mutation effect," especially when a recurrent mutation is unevenly distributed across clades.
- The fixed-effects "clade as dummies" model controls the confound too but costs many degrees of freedom and gives no tree; the MECIT matches its control while staying interpretable as a key.

## Risks and honesty

- **This is a simulation.** The claim is about method behavior under a known model, not a biological discovery; say so plainly. Real mt-expression effects are small and tangled with nuclear background — out of scope here.
- **Phylogenetic non-independence.** Even the random intercept per macro-haplogroup does not fully model shared ancestry within a clade; note it, and optionally compare a nested random effect (macro / sub-clade) as a sensitivity analysis.
- **Recurrence vs linkage.** A recurrent position's effect must be separable from the haplogroup-defining variants it travels with; the simulation should include a case where a recurrent mutation is partly confounded with a clade to show the limit.
- **`carries` and back-mutations.** A position can be gained and later reverted (`!`); `haplotypeMatrix` must apply the undo semantics moose already documents, or the design matrix is wrong.

## Deliverables and sequence

1. Add the five helpers above (each small, on existing data) with tests.
2. Implement `simulateExpression()` and store ground truth.
3. Run the method sweep; score recovery and type-I error.
4. Render one MECIT as a wizard (Fig 3).
5. Write up as a methods note / vignette; it pairs naturally with the vision-keys and phylo-integration work as "three things you can do with a moose tree."

This can stand alone or become a section of the broader moose methods paper alongside the BioCLIP 2 vision-keys study (`docs/preprint-plan.md`).

## Sources / tools

- MECIT = mixed-effects regression/conditional-inference trees: `glmertree` (Fokkema, Smits, Zeileis, Hothorn, Kelderman), built on `partykit::ctree` and `lme4`.
- PhyloTree Build 17 data as shipped in moose (`phylotree17`, `phylotree17_mutations`); recurrence counts above computed from `phylotree17_mutations` on 2026-09-30.
