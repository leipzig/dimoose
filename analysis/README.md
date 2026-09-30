# Analyses

Exploratory work around moose that is not part of the R package (this folder
is excluded from the package build). Each folder is self-contained: run its
scripts from inside that folder.

| Folder | What it is |
|---|---|
| `borror-keys/` | Dichotomous keys from *Borror and DeLong's Study of Insects*: the Key to the Orders of Arachnida transcribed by hand (`arachnida_key_tree.py`) and drawn as trees in several formats (`tree_formats/`, `visualizations/`), plus automatic key extraction from the book's OCR text (`dichotomous_trees/`) |
| `phylotree/` | PhyloTree Build 17: the Haplogrep XML parsed to Newick/JSON (`phylotree_to_newick.py`), and a comparison of MToolBox's parsed copy with Haplogrep's (`COMPARISON.md`) |
| `vibrio/` | The Vibrio consensus matrix of Noguerola & Blanch (2008): conversion from Excel (`convert_excel.py`) and clustering / decision-tree analyses |
| `table-extraction/` | Extraction of the Vibrio table from page 3 of the Noguerola & Blanch PDF with Sparrow and Qwen2.5-VL |
| `generate_tree_demo.R` | Small demo of `moose::generateTree()`; run from the package root |

## Reference material

The Borror textbook (`borror-the-study-of-insect1.pdf` and its OCR text
`borror-the-study-of-insect1.txt`) and `noguerola2008.pdf` are copyrighted.
They live in `references/` at the repository root, which git ignores; the
scripts in `borror-keys/dichotomous_trees/` and `table-extraction/` read them
from there.

## Sparrow

`table-extraction/` used [Sparrow](https://github.com/katanaml/sparrow), an
open-source tool that extracts structured data from documents with vision
language models. It is not kept in this repository. To re-run the
extraction:

```sh
git clone https://github.com/katanaml/sparrow.git
cd sparrow/sparrow-ml/llm
python3 -m venv venv && . venv/bin/activate
pip install -r requirements_sparrow_parse.txt
```

then run `extract_table.py` (library) or start Sparrow's API and run
`extract_table_api.py` (HTTP, `http://127.0.0.1:8000`).

## Python environments

No virtual environment is kept in the repository. The scripts use pandas,
numpy, scikit-learn, xgboost, matplotlib, graphviz (plus the Graphviz
system package), anytree, treelib, ete3, binarytree, lxml and requests;
install what a script imports into a fresh `python3 -m venv .venv`.
