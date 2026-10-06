#!/usr/bin/env python3
"""Compare MToolBox's PhyloTree Build 17 pickle with Haplogrep's phylotree17.xml.

Positions PhyloTree excludes from classification (309, 315, 515-524, 3107,
16182, 16183, 16193, 16519) are left out of the haplotype comparison.

The Haplogrep XML (the source of phylotree_mutations.json) is rooted at the
rCRS haplogroup H2a2a1, so the branch from H2a2a1 up to the L0 / L1'2'3'4'5'6
split is written in reverse. MToolBox's tree is rooted at the RSRS. To compare
without depending on either orientation, the full haplotype of every
haplogroup (its differences from rCRS: substitutions, insertions, deleted
positions) is rebuilt from each source, and the XML is re-rooted between L0
and L1'2'3'4'5'6 to compare parents.

Usage: compare_mtoolbox_haplogrep.py phylotree17.xml haplogroups.tsv mutations.tsv rCRS.fa RSRS.fa OUTDIR [UNSTABLE]
(haplogroups.tsv / mutations.tsv: mtoolbox/mtoolbox_*.tsv, written by
mtoolbox/convert_mtoolbox_pickle.py from MToolBox's phylotree_r17.pickle;
UNSTABLE is an optional whitespace-separated list of the positions PhyloTree
prints in parentheses, used to explain differences)
Writes OUTDIR/comparison.csv and prints a summary.
"""
import collections
import csv
import re
import sys
import xml.etree.ElementTree as ET


def fasta(path):
    return "".join(l.strip() for l in open(path) if not l.startswith(">")).upper()


# Positions PhyloTree does not use for classification (mutational hotspots and
# the rCRS 3107 placeholder); RSRS also has placeholders (N) at 523-524.
IGNORED = {309, 315, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 3107, 16182, 16183, 16193, 16519}


def norm_name(name):
    """Canonical form for matching Haplogrep '+' names to MToolBox '_' names:
    '+' -> '_', and spaces, parentheses, '@' and '!' dropped."""
    return re.sub(r"[\s()@!]", "", name).replace("+", "_")


class Haplotype:
    def __init__(self, subs=None, ins=None, dels=None, hist=None):
        self.subs = dict(subs or {})
        self.ins = set(ins or ())
        self.dels = set(dels or ())
        # position -> earlier bases along the path, for Haplogrep's "!" (undo)
        self.hist = {p: list(v) for p, v in (hist or {}).items()}

    def copy(self):
        return Haplotype(self.subs, self.ins, self.dels, self.hist)

    def tokens(self):
        out = {"%d%s" % (p, b) for p, b in self.subs.items() if p not in IGNORED}
        out |= {"%d.%s" % (p, s) for p, s in self.ins if p not in IGNORED}
        out |= {"%dd" % p for p in self.dels if p not in IGNORED}
        return out


def classify(only_x, only_m, unstable):
    """Likely cause of each haplotype difference."""
    causes = set()
    pos = lambda t: int(re.match(r"\d+", t).group())
    x_ins = {(pos(t), t.split(".", 1)[1]) for t in only_x if "." in t}
    m_ins = {(pos(t), t.split(".", 1)[1]) for t in only_m if "." in t}
    for t in only_x:
        if ".X" in t:
            causes.add("insertion of unspecified length (.X) missing in MToolBox")
        elif "." in t and any(p == pos(t) for p, _ in m_ins):
            causes.add("multi-base insertion written differently")
        elif pos(t) in unstable:
            causes.add("unstable (parenthesized) mutation missing in MToolBox")
        else:
            causes.add("other")
    for t in only_m:
        if t in ("263G", "15314A"):
            causes.add("H2a2a1 missing in MToolBox")
        elif "." in t and any(p == pos(t) for p, _ in x_ins):
            causes.add("multi-base insertion written differently")
        elif pos(t) in unstable:
            causes.add("unstable (parenthesized) mutation handled differently")
        else:
            causes.add("other")
    return sorted(causes)


def main(xml_path, hg_tsv, mu_tsv, rcrs_fa, rsrs_fa, outdir, unstable_path=None):
    unstable = set()
    if unstable_path:
        unstable = {int(x) for x in open(unstable_path).read().split() if int(x) > 10}
    rcrs, rsrs = fasta(rcrs_fa), fasta(rsrs_fa)
    unparsed = collections.Counter()

    # --- Haplogrep XML --------------------------------------------------------
    xparent, xpolys, xorder = {}, {}, []

    def walk(el, par):
        name = el.get("name")
        xparent[name] = par
        xorder.append(name)
        det = el.find("details")
        xpolys[name] = [p.text.strip() for p in (det.findall("poly") if det is not None else [])
                        if p.text and p.text.strip()]
        for ch in el.findall("haplogroup"):
            walk(ch, name)

    xroot = ET.parse(xml_path).getroot().find("haplogroup")
    walk(xroot, None)

    def set_base(h, p, b):
        if b == rcrs[p - 1]:
            h.subs.pop(p, None)
        else:
            h.subs[p] = b

    def apply_xml(h, poly):
        # In Haplogrep's XML "!" undoes the latest change at that position on
        # the path from the root (H2a2a1); the base letter is not the result.
        m = re.fullmatch(r"(\d+)([ACGT])(!?)", poly)
        if m:
            p, b = int(m.group(1)), m.group(2)
            current = h.subs.get(p, rcrs[p - 1])
            if m.group(3):
                if h.hist.get(p):
                    set_base(h, p, h.hist[p].pop())
                else:
                    unparsed["xml back-mutation with nothing to undo"] += 1
                    set_base(h, p, b)
            else:
                h.hist.setdefault(p, []).append(current)
                set_base(h, p, b)
            return
        m = re.fullmatch(r"(\d+)d(!?)", poly)
        if m:
            (h.dels.discard if m.group(2) else h.dels.add)(int(m.group(1)))
            return
        m = re.fullmatch(r"(\d+)\.(\d+|X)([ACGT]+)(!?)", poly)
        if m:
            tok = (int(m.group(1)), ("X" if m.group(2) == "X" else "") + m.group(3))
            (h.ins.discard if m.group(4) else h.ins.add)(tok)
            return
        unparsed["xml " + re.sub(r"\d+", "N", poly)] += 1

    xhap = {xroot.get("name"): Haplotype()}  # H2a2a1 = rCRS
    for name in xorder[1:]:
        h = xhap[xparent[name]].copy()
        for poly in xpolys[name]:
            apply_xml(h, poly)
        xhap[name] = h

    # Haplogrep's XML has an extra node, L2'3'4'6+, on the reversed branch;
    # above it each node holds the state of the next haplogroup up
    # (XML "L2'3'4'6+" = L2'3'4'5'6, XML "L2'3'4'5'6" = L1'2'3'4'5'6).
    if "L2'3'4'6+" in xhap:
        xhap["L1'2'3'4'5'6"], xhap["L2'3'4'5'6"] = xhap["L2'3'4'5'6"], xhap.pop("L2'3'4'6+")
        kids_of_plus = [k for k, v in xparent.items() if v == "L2'3'4'6+"]
        for k in kids_of_plus:
            xparent[k] = xparent["L2'3'4'6+"]
        del xparent["L2'3'4'6+"]
        xorder.remove("L2'3'4'6+")

    # Re-root between L0 and L1'2'3'4'5'6: reverse the chain from H2a2a1 up.
    xphylo = dict(xparent)
    chain = []
    n = "L1'2'3'4'5'6"
    while n is not None:
        chain.append(n)
        n = xparent[n]
    for child, par in zip(chain[1:], chain[:-1]):
        xphylo[child] = par
    xphylo["L1'2'3'4'5'6"] = "mt-MRCA"
    xphylo["L0"] = "mt-MRCA"

    # --- MToolBox (dimoose data) -------------------------------------------------
    mparent = {}
    morder = []
    for r in csv.DictReader(open(hg_tsv), delimiter="\t"):
        mparent[r["haplogroup"]] = r["parent"] or None
        morder.append(r["haplogroup"])
    mmut = collections.defaultdict(list)
    for r in csv.DictReader(open(mu_tsv), delimiter="\t"):
        mmut[r["haplogroup"]].append(r)
    root_subs = {i + 1: rsrs[i] for i in range(len(rsrs)) if rsrs[i] != rcrs[i]}
    mhap = {"mt-MRCA": Haplotype(root_subs)}
    for name in morder[1:]:
        h = mhap[mparent[name]].copy()
        for r in mmut[name]:
            p = int(r["position"])
            if r["type"] in ("transition", "transversion", "back-mutation"):
                if r["base"] == rcrs[p - 1]:
                    h.subs.pop(p, None)
                else:
                    h.subs[p] = r["base"]
            elif r["type"] == "insertion":
                if re.fullmatch(r"[ACGT]+", r["base"]):
                    h.ins.add((p, r["base"]))
                else:
                    unparsed["mtoolbox insertion '%s'" % r["base"]] += 1
            elif r["type"] == "deletion":
                h.dels.update(range(p, int(r["end"]) + 1))
        mhap[name] = h

    # --- compare ---------------------------------------------------------------
    xnames = set(xorder)
    to_m = {}
    m_canon = {}
    for n in morder:
        m_canon.setdefault(norm_name(n), n)
    for n in xorder:
        if n in mparent:
            to_m[n] = n
        elif norm_name(n) in m_canon:
            to_m[n] = m_canon[norm_name(n)]
    matched_m = set(to_m.values())
    only_x = [n for n in xorder if n not in to_m]
    only_m = [n for n in morder if n not in matched_m and n != "mt-MRCA"]

    rows = []
    same_parent = same_hap = 0
    for xn, mn in to_m.items():
        xp = xphylo.get(xn)
        xp_m = to_m.get(xp, xp) if xp != "mt-MRCA" else "mt-MRCA"
        mp = mparent[mn]
        xt, mt = xhap[xn].tokens(), mhap[mn].tokens()
        parent_ok = xp_m == mp
        hap_ok = xt == mt
        same_parent += parent_ok
        same_hap += hap_ok
        if not (parent_ok and hap_ok):
            rows.append({
                "haplogroup_haplogrep": xn, "haplogroup_mtoolbox": mn,
                "status": ";".join(s for s, bad in [("parent differs", not parent_ok), ("haplotype differs", not hap_ok)] if bad),
                "parent_haplogrep": xp_m, "parent_mtoolbox": mp,
                "only_in_haplogrep": " ".join(sorted(xt - mt, key=lambda t: int(re.match(r"\d+", t).group()))),
                "only_in_mtoolbox": " ".join(sorted(mt - xt, key=lambda t: int(re.match(r"\d+", t).group()))),
                "likely_cause": "; ".join(classify(xt - mt, mt - xt, unstable)) if not hap_ok else "",
            })
    for n in only_x:
        rows.append({"haplogroup_haplogrep": n, "haplogroup_mtoolbox": "", "status": "only in Haplogrep XML",
                     "parent_haplogrep": xphylo.get(n), "parent_mtoolbox": "", "only_in_haplogrep": "", "only_in_mtoolbox": "", "likely_cause": ""})
    for n in only_m:
        rows.append({"haplogroup_haplogrep": "", "haplogroup_mtoolbox": n, "status": "only in MToolBox",
                     "parent_haplogrep": "", "parent_mtoolbox": mparent[n], "only_in_haplogrep": "", "only_in_mtoolbox": "", "likely_cause": ""})

    with open(outdir + "/comparison.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # summary
    diff_tokens = collections.Counter()
    for r in rows:
        for t in r["only_in_haplogrep"].split():
            diff_tokens["haplogrep:" + t] += 1
        for t in r["only_in_mtoolbox"].split():
            diff_tokens["mtoolbox:" + t] += 1
    print("Haplogrep XML haplogroups: %d | MToolBox: %d (+ virtual mt-MRCA)" % (len(xorder), len(morder) - 1))
    exact = sum(1 for k, v in to_m.items() if k == v)
    print("matched: %d (%d exact name, %d after '+' -> '_')" % (len(to_m), exact, len(to_m) - exact))
    print("only in Haplogrep: %d | only in MToolBox: %d" % (len(only_x), len(only_m)))
    print("same parent: %d / %d | same haplotype: %d / %d" % (same_parent, len(to_m), same_hap, len(to_m)))
    print("most frequent haplotype differences:", diff_tokens.most_common(15))
    causes = collections.Counter(c for r in rows for c in r["likely_cause"].split("; ") if c)
    print("likely causes (haplogroups):", dict(causes.most_common()))
    print("unparsed:", dict(unparsed))
    return rows, only_x, only_m


if __name__ == "__main__":
    main(*sys.argv[1:8])


def origins(rows_by_name, parent_of):
    """Differences a haplogroup has that its parent does not (where they start)."""
    out = []
    for name, r in rows_by_name.items():
        par = rows_by_name.get(parent_of.get(name), {})
        for side in ("only_in_haplogrep", "only_in_mtoolbox"):
            new = set(r.get(side, "").split()) - set(par.get(side, "").split())
            for t in sorted(new):
                out.append((name, side, t))
    return out
