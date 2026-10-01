# MToolBox `phylotree_r17.pickle` vs Haplogrep `phylotree17.xml`

Outcome: moose ships Haplogrep 3's copy (`phylotree-rsrs-17` release 17.2) as
`phylotree17`; see `data-raw/phylotree17/` in the package sources.

Compared 2026-09-30 with `compare_mtoolbox_haplogrep.py` (this folder). Full
per-haplogroup results are in `mtoolbox_vs_haplogrep_comparison.csv`.

**Sources**

- **MToolBox:** `MToolBox/data/phylotree_r17.pickle`, commit `b52269e`,
  converted with `mtoolbox/convert_mtoolbox_pickle.py` (a restricted
  unpickler, so no code from the file runs) to `mtoolbox/mtoolbox_*.tsv`.
- **Haplogrep:** `phylotree17.xml` from trichelab/MTseekerData
  (`inst/extdata/haplogrep_data/phylotree/`), master `225633641`, SHA-256
  `23073a75…`. `phylotree_to_newick.py` read this file, and
  `phylotree_mutations.json` is exactly its mutation lists: 5,434 haplogroups,
  every one except the root H2a2a1, which has none. `phylotree.json` is a stale
  one-node file.

## How the comparison works

The two files are oriented differently:

- **Haplogrep's XML** is rooted at H2a2a1, the rCRS haplogroup. The branch
  from H2a2a1 up to the L0 / L1'2'3'4'5'6 split is written in reverse, and a
  trailing `!` means "undo the last change at this position". It also has an
  extra node on that branch, `L2'3'4'6+`, which shifts the states above it up
  by one name.
- **MToolBox** is rooted at the RSRS. Its internal `RCRS` constant is
  identical to its `chrRSRS.fa`.

So the script rebuilds every haplogroup's full haplotype, meaning its
differences from rCRS, from each file. It then compares those haplotypes, and
compares parents after re-rooting the XML between L0 and L1'2'3'4'5'6. It
skips the positions PhyloTree doesn't use for classification: 309, 315,
515–524, 3107, 16182, 16183, 16193 and 16519.

## Results

| | Count |
|---|---|
| Haplogroups (Haplogrep / MToolBox) | 5,434 / 5,447 |
| Matched by name | 5,410: 5,179 exact, 231 after mapping `+` → `_` |
| Only in one file | 24 Haplogrep, 37 MToolBox |
| Same parent | 5,322 of 5,410 |
| Same haplotype | 3,870 of 5,410 |

**Names.** Most of the unmatched names are the same unnamed branches under
each tool's placeholder label:

- Haplogrep writes `H10+(16093)` and `A2+(64)+@153`.
- MToolBox writes `H10_s6` and `A2_s3_153!`.

77 of the 88 parent mismatches are only this naming difference.

**What explains the 1,540 haplotype differences.** Each difference is
inherited by every descendant, so a handful of causes account for most of
them:

| Likely cause | Haplogroups affected |
|---|---|
| MToolBox omits PhyloTree's unstable (parenthesized) mutations, e.g. J1c `(185A) (228A)`, K1a `(16093C)` | 1,314 |
| MToolBox omits insertions of unspecified length, e.g. `573.XC` and `5899.XC` | 228 |
| An unstable position is handled differently in each file | 23 |
| MToolBox has no H2a2a1 (the rCRS haplogroup, defined by G263A in PhyloTree's own HTML). H2a2a1a hangs directly off H2a2a, and H2a2a1b–h sit under H2a2a1a instead of beside it | 9 |
| Other | 10 |

**The 10 "other" haplogroups**

- **W3a1d, A26, L5b2:** the XML has one extra substitution each (10398G,
  13650T and 7972G, respectively).
- **C4a1a1, C4a1a1a (2232) and L5a1 and subclades (455):** MToolBox has an
  extra inserted base.
- **L1c2a2:** MToolBox mis-parsed `5899.1C!` as the insertion `CD!`, so the
  reversion is lost.

## Takeaways

- The two files describe the same tree. Structure agrees apart from the
  H2a2a1 placement and the placeholder names.
- MToolBox's copy is missing most of PhyloTree's unstable mutations and all
  insertions of unspecified length. That's reasonable for MToolBox's
  classification algorithm, but it makes the MToolBox copy less complete as a
  reference for PhyloTree itself.
- The Haplogrep XML is the more faithful copy of PhyloTree, but only once
  its rCRS-rooted orientation, `!` semantics and the `L2'3'4'6+` node are
  handled. Its placeholder names contain spaces, parentheses and `@`, which
  is why the Newick in `phylotree.txt` doesn't parse.
