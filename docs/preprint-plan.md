# Study and preprint plan: machine-authored dichotomous keys for biological images

Draft plan, 2026-09-30. Target: a bioRxiv preprint (Bioinformatics / Evolutionary Biology), with moose as the software and a biological image dataset as the subject. The fordera truck study is the methodological template; this replaces OpenAI CLIP with **BioCLIP 2**, a biology foundation model, and asks the same questions on organisms.

## The question

fordera asked: can a vision-language model write a plain-language dichotomous key from images and then follow its own key? For Ford trucks the answer was "barely" for text questions (27% generation accuracy) but "surprisingly well" for *invented-term* keys built on patch-embedding clusters (61% leave-one-out). This study asks whether that result holds for **biological identification**, the task dichotomous keys were invented for, and whether a **domain foundation model (BioCLIP 2)** closes the gap that a generic model (CLIP) leaves.

Three concrete hypotheses:

- **H1 (domain model helps).** BioCLIP 2 embeddings produce more accurate and more taxonomically coherent keys than OpenAI CLIP on the same images.
- **H2 (invented terms beat text questions for machines).** As in fordera, patch-cluster "invented-term" keys are more machine-followable than CLIP/BioCLIP text-question keys; the gap is smaller with BioCLIP 2.
- **H3 (keys are usable by people).** The text-question keys, though weaker for machines, are legible to humans and align with real diagnostic characters a taxonomist would recognise — tested with a small human trial.

## Why it is novel and bioRxiv-suitable

- Dichotomous keys are the oldest tool in systematics; "can a foundation model write one, and can anyone (person or machine) use it?" is a question the field will recognise.
- BioCLIP 2 is new (NeurIPS 2025) and its emergent trait structure is exactly what a key needs; no one has yet used it to *generate* keys.
- The negative/positive contrast (text keys legible but weak for machines; invented-term keys strong but opaque) is a genuine finding about distilling vision into language, with a biological testbed.
- moose is a released, documented R package, so the work is reproducible end to end.

## Datasets

Pick 2–3 clades where keys matter and images are clean and openly licensed. Candidates:

1. **A hard genus with subtle characters** — e.g. *Carex* (sedges), bumblebees (*Bombus*), or *Plethodon* salamanders. These are where real keys are notoriously hard, so a machine key is a fair test.
2. **A classic teaching key** — orders of aquatic insects, or families of a regional flora — where a ground-truth human key already exists to compare against (moose already ships the arachnida key as this kind of reference).
3. **A fine-grained benachmark subset** — a slice of an existing labelled set so results are comparable to published classification numbers.

Image sources (all with explicit reuse licences; record licence per image):
- **GBIF** media (CC-BY / CC0 research-grade observations).
- **iNaturalist** research-grade (CC-licensed subset only).
- **BIOSCAN / NEON / museum portals** where licensing allows.
- The **TreeOfLife-10M/200M** metadata to align taxa with BioCLIP 2's training (and to note any train/test overlap honestly).

Design choices to decide up front:
- **One image per taxon vs several.** fordera used one per class, which overfits thresholds. Here use **n per taxon** (say 10–50) so leave-one-out and train/test splits are meaningful. This is the single biggest improvement over fordera.
- **Taxonomic levels.** Build keys at genus→species and at family→genus, and report accuracy at each level plus at the next level up (the analogue of fordera's "generation" grouping).
- **Standardised views.** Keep to a consistent view (dorsal habitus, etc.) where the clade has one, as fordera did with front profiles.

## Models

- **BioCLIP 2** (ViT-L/14, `hf-hub:imageomics/bioclip-2`) — primary.
- **OpenAI CLIP ViT-B/32 and ViT-L/14** — baselines (generic model, and a size-matched control).
- Optionally **DINOv2** image embeddings for the invented-term route (no text encoder), to separate "domain knowledge" from "text alignment".

All reached through moose's existing Python layer (`visionModel()` already loads any open_clip model; BioCLIP 2 loads with `create_model_and_transforms("ViT-L-14", pretrained="hf-hub:imageomics/bioclip-2")`, which the layer supports with a one-line addition for hf-hub tags).

## Methods (all already in moose)

1. **Embed** every image: global + patch embeddings (`embedImages()`), per model.
2. **Invented-term keys:** `discoverTerms()` (k-means on patch embeddings) → `keyFromTerms()`. Sweep k and the presence quantile.
3. **Text-question keys:** a vocabulary of candidate characters → `keyFromClusters()`. Two vocabularies:
   - a **generic** one written without seeing the images (the fordera "LLM-authored" analogue), and
   - a **taxonomic** one drawn from the real key's couplet language (does domain wording help?).
4. **Machine evaluation:** `classify()` + `evaluateKey()` for train accuracy; `looKey()` and a held-out test split for honest accuracy, at the taxon level and the parent level.
5. **Human evaluation (H3):** 5–10 participants identify a set of specimens with the generated text-question key; record accuracy and time, and ask them to flag any couplet whose wording is wrong. Compare against the published human key as a ceiling.
6. **Interpretability:** the moose glossary (patch crops per invented term) is the figure that shows *what* each term means; a taxonomist annotates whether terms correspond to real diagnostic structures (sculpturing, setae, venation…).

## Experiments and expected figures

- **Fig 1.** The pipeline (images → embeddings → two key types → human + machine use). Reuse moose's wizard screenshot.
- **Fig 2.** Accuracy matrix: {BioCLIP 2, CLIP-B, CLIP-L, DINOv2} × {invented-term, text-generic, text-taxonomic} × {taxon, parent} × {train, LOO, held-out}. The headline result.
- **Fig 3.** Invented-term glossary for the best model, with a taxonomist's annotations (the "what did it learn" figure).
- **Fig 4.** Human trial: accuracy and time per participant vs the machine on the same key; agreement on which couplets are wrong.
- **Fig 5.** Tree-shape comparison: does the machine key's topology match the accepted phylogeny / the human key? (moose `toNewick()` + a tanglegram, which ties into the phylogenetic-library integration work.)
- **Table 1.** Dataset provenance, licences, counts, train/test splits.

## Predicted results (to be confirmed)

- BioCLIP 2 invented-term keys clearly beat CLIP (H1), with the largest margin at species level where domain features matter.
- Invented-term > text-question for machines across models (H2), but BioCLIP 2's *text* keys do much better than CLIP's, because BioCLIP 2's text tower knows taxonomic language — this is the interesting twist a biology model adds over the truck result.
- Human accuracy with the text keys is high and the flagged-couplet rate is low for BioCLIP 2 (H3), showing the keys are legible even where machines stumble.

## Risks and honesty

- **Train/test leakage with BioCLIP 2.** TreeOfLife-200M is huge; some test taxa were in training. Report this explicitly, prefer taxa or images not in TreeOfLife where possible, and treat BioCLIP 2 numbers as "with prior exposure" vs CLIP's "without".
- **Licence hygiene.** Every image's licence recorded; redistribute only embeddings and crops that the licence permits, never bulk images. moose ships no images.
- **Small-n overfitting.** Fixed by n-per-taxon and held-out splits; always report LOO alongside train.
- **Human trial scope.** Keep it small and descriptive (a usability signal, not a powered study) unless a collaborator can run it properly.

## What moose needs for the study (small)

- A one-line hf-hub tag path in `visionModel()` (BioCLIP 2 loads by `hf-hub:` tag). *(trivial)*
- Train/test split helpers around `looKey()` (a `splitKey()` or a `holdout=` argument). *(small)*
- Batch embedding to disk for large image sets (cache embeddings so sweeps are cheap). *(small)*
- Optional: write the key as treedata/Newick for the tree-shape figure (already planned in the phylogenetic-library integration).

## Deliverables and sequence

1. Pick clades + assemble the licensed image set (the long pole).
2. Add the three small moose helpers above.
3. Run the model × method × level sweep; cache embeddings.
4. Taxonomist annotation of the glossary; small human trial.
5. Write up; release a reproducible repo (code + embeddings + keys, not raw images) and the moose version used.

## Suggested title and authorship

Working title: *"Machine-authored dichotomous keys: can a biology foundation model write a key, and can we read it?"*

Authorship: Jeremy Leipzig, PhD (moose, analysis) plus a systematics collaborator for the clade, the key, and the annotation, and whoever runs the human trial. BioCLIP 2 and TreeOfLife cited per the Imageomics releases.

## Sources

- BioCLIP 2 paper: <https://arxiv.org/abs/2505.23883>
- BioCLIP 2 code: <https://github.com/Imageomics/bioclip-2>
- BioCLIP 2 weights: <https://huggingface.co/imageomics/bioclip-2>
- fordera (method template): <https://github.com/leipzig/fordera>
