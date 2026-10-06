#!/bin/sh
# Rebuild data/phylotree17.rda and data/phylotree17_mutations.rda from
# Haplogrep 3's PhyloTree Build 17 (RSRS), release 17.2.
# Run from the package root: sh data-raw/phylotree17/build.sh
set -eu
COMMIT=0e79ddf1b78f7a1b81fb5d607bc31a6ddea7b18b
BASE="https://raw.githubusercontent.com/genepi/phylotree-rsrs-17/$COMMIT/src"
WORK="${TMPDIR:-/tmp}/dimoose-phylotree17"
mkdir -p "$WORK"
curl -sSfL -o "$WORK/tree.xml" "$BASE/tree.xml"
curl -sSfL -o "$WORK/rsrs.fasta" "$BASE/rsrs.fasta"
python3 data-raw/phylotree17/convert_haplogrep_xml.py "$WORK/tree.xml" "$WORK/rsrs.fasta" data-raw/phylotree17
Rscript data-raw/phylotree17/build.R
