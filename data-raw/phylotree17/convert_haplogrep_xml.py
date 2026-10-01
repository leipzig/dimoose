#!/usr/bin/env python3
"""Convert Haplogrep 3's PhyloTree Build 17 (RSRS) tree.xml into two TSVs.

Source: https://github.com/genepi/phylotree-rsrs-17, release 17.2
(commit 0e79ddf1b78f7a1b81fb5d607bc31a6ddea7b18b), src/tree.xml and
src/rsrs.fasta, MIT license.

Mutations are copied verbatim (Haplogrep notation) and also parsed into
position / type / ancestral / derived. The ancestral and derived bases are
worked out by following the tree from the RSRS root. A trailing "!" is a
back-mutation: it reverts the most recent change at that position, which may
itself have been a back-mutation ("!!" marks a second reversion and reverts
once as well). The base letter written before "!" is not always the
resulting base (the file uses both conventions), so the result is taken from
the tree instead. Haplogroup names are trimmed of surrounding whitespace.

Usage: convert_haplogrep_xml.py tree.xml rsrs.fasta OUTDIR
"""
import csv
import hashlib
import os
import re
import sys
import xml.etree.ElementTree as ET

EXPECTED = {
    "tree.xml": "6f517e79d3148abee3cb670017caa919f507d531d0493b6bd7f3f83140294de8",
}
PURINES = set("AG")


def fasta(path):
    return "".join(l.strip() for l in open(path, encoding="ascii") if not l.startswith(">")).upper()


def kind(a, b):
    if a in "ACGT" and b in "ACGT":
        return "transition" if (a in PURINES) == (b in PURINES) else "transversion"
    return "substitution"


def main(xml_path, fasta_path, outdir):
    digest = hashlib.sha256(open(xml_path, "rb").read()).hexdigest()
    if digest != EXPECTED["tree.xml"]:
        sys.exit("tree.xml SHA-256 mismatch: %s" % digest)
    ref = fasta(fasta_path)
    root = ET.parse(xml_path).getroot().find("haplogroup")

    os.makedirs(outdir, exist_ok=True)
    hg_f = open(os.path.join(outdir, "phylotree17_haplogroups.tsv"), "w", newline="", encoding="utf-8")
    mu_f = open(os.path.join(outdir, "phylotree17_mutations.tsv"), "w", newline="", encoding="utf-8")
    hg_w = csv.writer(hg_f, delimiter="\t", lineterminator="\n")
    mu_w = csv.writer(mu_f, delimiter="\t", lineterminator="\n")
    hg_w.writerow(["haplogroup", "parent", "depth", "n_subclades", "mutations"])
    mu_w.writerow(["haplogroup", "notation", "position", "type", "ancestral", "derived"])

    seen = set()
    unmatched = []
    # stack of (element, parent name, depth, state, history)
    stack = [(root, "", 0, {}, {})]
    while stack:
        el, parent, depth, state, hist = stack.pop()
        name = el.get("name").strip()
        if name in seen:
            sys.exit("duplicate haplogroup %s" % name)
        seen.add(name)
        state, hist = dict(state), {k: list(v) for k, v in hist.items()}
        det = el.find("details")
        polys = [p.text.strip() for p in (det.findall("poly") if det is not None else []) if p.text and p.text.strip()]
        for poly in polys:
            m = re.fullmatch(r"(\d+)([ACGT])(!*)", poly)
            if m:
                pos, base, bangs = int(m.group(1)), m.group(2), len(m.group(3))
                cur = state.get(pos, ref[pos - 1])
                if bangs:
                    if hist.get(pos):
                        new = hist[pos].pop()
                    else:
                        # Nothing earlier on the path changed this position
                        # (only D4c1b1 16233C! in release 17.2): keep the letter.
                        unmatched.append("%s %s" % (name, poly))
                        new = base
                    mu_w.writerow([name, poly, pos, "back-mutation", cur, new])
                else:
                    new = base
                    mu_w.writerow([name, poly, pos, kind(cur, new), cur, new])
                hist.setdefault(pos, []).append(cur)
                state[pos] = new
                continue
            m = re.fullmatch(r"(\d+)d", poly)
            if m:
                pos = int(m.group(1))
                mu_w.writerow([name, poly, pos, "deletion", state.get(pos, ref[pos - 1]), ""])
                continue
            m = re.fullmatch(r"(\d+)\.(\d+|X)([ACGT]+)(!?)", poly)
            if m:
                pos, seq = int(m.group(1)), m.group(3)
                if m.group(4):
                    mu_w.writerow([name, poly, pos, "back-mutation", seq, ""])
                else:
                    mu_w.writerow([name, poly, pos, "insertion", "", seq])
                continue
            sys.exit("%s: unrecognised mutation %s" % (name, poly))
        kids = el.findall("haplogroup")
        hg_w.writerow([name, parent, depth, len(kids), " ".join(polys)])
        for ch in reversed(kids):
            stack.append((ch, name, depth + 1, state, hist))
    hg_f.close()
    mu_f.close()
    print("wrote %d haplogroups" % len(seen))
    if unmatched:
        print("back-mutations with no earlier change to revert (letter used as result):", ", ".join(unmatched))


if __name__ == "__main__":
    main(*sys.argv[1:4])
