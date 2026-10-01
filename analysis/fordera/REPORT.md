# Verifying moose's vision keys against fordera

Run 2026-09-30 with `verify.R` in this folder, against a checkout of
[fordera](https://github.com/leipzig/fordera) and OpenAI's CLIP ViT-B/32
(`ViT-B-32.pt`, SHA-256 `40d365…950af`) through moose's Python layer
(open_clip 3.3.0, torch 2.14.1). Nothing from fordera is copied into moose;
the script reads it from `$FORDERA`.

The four checks are V1–V4 from the spec
(`docs/superpowers/specs/2026-09-30-vision-keys-design.md`).

## Results

| Check | Result |
|---|---|
| **V1** moose's patch scores vs fordera's `trait_centroids.npy` | max abs diff **6.4e-06** — PASS |
| **V2** balanced term tree rebuilt from fordera's scores | **identical** to `trait_tree.json`; **26/33** years, **28/33** generations — PASS |
| **V3** from-scratch term key (moose's own k-means, k=40) | train **75.8%** year / **90.9%** gen; LOO (shared terms) 3.0% / 54.5%; LOO (refit terms) 3.0% / 33.3% |
| **V4** question key, machine self-walk | threshold 0: **15.2%** year / **45.5%** gen; midpoint: **48.5%** year / **60.6%** gen |

## Reading

- **V1 confirms the embeddings.** moose's `embedImages()` + `termScores()`
  reproduce fordera's per-image trait presence to 6e-6, so the open_clip
  patch extraction (output tokens, `ln_post`, `proj`, drop CLS) matches
  fordera's hook-based extraction.
- **V2 confirms the tree builder.** Given the same scores, moose's balanced
  builder produces fordera's exact tree and the same 26/33 and 28/33 it
  reports for Experiment 10 on training data. The `Feature`/`Test`/
  `Threshold` lead columns carry the machine key faithfully.
- **V3 is comparable to fordera.** fordera reports 78.8% year / 84.8% gen on
  training data; moose gets 75.8% / 90.9% from its own k-means. The
  difference is expected: R's Hartigan–Wong k-means and sklearn's k-means++
  find different clusters, so the terms and tree differ even though the
  method is the same. The honest leave-one-out numbers are low at the year
  level because the dataset has **one image per class** — holding out a
  year's only image leaves the key with no example of it, so exact-year
  recovery is near chance (1/33). The generation-level LOO (33.3% refit,
  54.5% with fordera's shared-term leakage) is the meaningful figure and
  sits in fordera's reported range (it quotes 61% gen LOO with shared
  terms).
- **V4 improves on fordera, because of the two fixes.** fordera's text-
  question key scores 27% generation accuracy when CLIP walks it. moose's
  gets **60.6%** generation (and 48.5% year) with midpoint calibration — a
  large gain — and even at a fixed 0 threshold it reaches 45.5% generation.
  The two corrections in `keyFromClusters()` explain it:
  1. the "Has feature" lead now points at the side that actually has the
     feature (fordera kept the question wording when the reverse direction
     won, inverting those branches); and
  2. machine answers use the same prompt pair that chose the question
     (fordera chose with "with X" vs "with Y" but answered with "with X" vs
     "without X").
  Calibrating the threshold to the midpoint of the two sides' mean scores,
  rather than a fixed 0, adds the rest.

## Takeaways for a study

- The invented-term route remains the stronger machine key, as fordera
  found, but the gap to text-question keys is much smaller once the two bugs
  are fixed.
- One image per class makes every absolute number optimistic at the leaf
  level; a real study needs several images per taxon (see
  `docs/preprint-plan.md`).
- A domain model (BioCLIP 2) is the natural next step for biological images;
  the same `verify.R` structure applies by swapping the model.

Full numeric results are saved alongside this file as `verify-results.rds`
when the script is run with `MOOSE_VERIFY_OUT` set.
