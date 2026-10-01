#!/usr/bin/env python3
"""Convert MToolBox's PhyloTree Build 17 pickle into two TSV tables.

Source: MToolBox (Calabrese et al. 2014), MToolBox/data/phylotree_r17.pickle,
pinned to commit b52269e98c694d3e4ba25eb80f27b74b48985ddb. The pickle is a
Python 2 dict mapping haplogroup name -> classifier.datatypes.Haplogroup
(or MetaGroup), each with a parent and a list of defining mutations.

The file is loaded with a restricted unpickler that only accepts the nine
names the file references and maps MToolBox's classes to inert stand-ins, so
no code from the file is executed and MToolBox itself is not needed.

Usage: convert_mtoolbox_pickle.py phylotree_r17.pickle OUTDIR
Writes OUTDIR/phylotree17_haplogroups.tsv and OUTDIR/phylotree17_mutations.tsv
"""
import csv
import hashlib
import os
import pickle
import re
import sys

EXPECTED_SHA256 = "c192cea8e8f6093f2d0a4c51ff5831b00c3c7918588acd778315541416f5d3ea"
ROOT = "mt-MRCA"


class Inert:
    def __setstate__(self, state):
        if isinstance(state, dict):
            self.__dict__.update(state)
        else:
            self.__dict__["_state"] = state


ALLOWED = {name: type(name, (Inert,), {}) for name in
           ["Haplogroup", "MetaGroup", "Transition", "Transversion",
            "Retromutation", "Insertion", "Deletion"]}


def _reconstructor(cls, base, state):
    if not (isinstance(cls, type) and issubclass(cls, Inert)) or base is not object or state is not None:
        raise pickle.UnpicklingError("unexpected reconstructor call")
    return cls.__new__(cls)


class SafeUnpickler(pickle.Unpickler):
    def find_class(self, module, name):
        if module == "classifier.datatypes" and name in ALLOWED:
            return ALLOWED[name]
        if (module, name) == ("copy_reg", "_reconstructor"):
            return _reconstructor
        if (module, name) == ("__builtin__", "object"):
            return object
        raise pickle.UnpicklingError("refusing %s.%s" % (module, name))


def natural_key(name):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", name)]


def mutation_row(m):
    """(type, position, base, end, notation) for one MToolBox mutation object."""
    kind = type(m).__name__
    if kind == "Transition":
        return "transition", m.start, m.change, "", "%d%s" % (m.start, m.change)
    if kind == "Transversion":
        return "transversion", m.start, m.change, "", "%d%s" % (m.start, m.change)
    if kind == "Retromutation":
        return "back-mutation", m.start, m.change, "", "%d%s!" % (m.start, m.change)
    if kind == "Insertion":
        return "insertion", m.start, m.seq, "", "%d.%s" % (m.start, m.seq)
    if kind == "Deletion":
        note = "%dd" % m.start if m.start == m.end else "%d-%dd" % (m.start, m.end)
        return "deletion", m.start, "", m.end, note
    raise ValueError("unknown mutation type %s" % kind)


def main(path, outdir):
    raw = open(path, "rb").read()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SHA256:
        sys.exit("SHA-256 mismatch: got %s, expected %s" % (digest, EXPECTED_SHA256))
    with open(path, "rb") as f:
        tree = SafeUnpickler(f, encoding="latin1").load()

    children = {ROOT: []}
    for name, hg in tree.items():
        parent = hg.parent.name if hg.parent is not None else ROOT
        if parent != ROOT and parent not in tree:
            sys.exit("parent %s of %s is not in the tree" % (parent, name))
        children.setdefault(parent, []).append(name)
    for kids in children.values():
        kids.sort(key=natural_key)

    os.makedirs(outdir, exist_ok=True)
    hg_out = open(os.path.join(outdir, "phylotree17_haplogroups.tsv"), "w", newline="")
    mu_out = open(os.path.join(outdir, "phylotree17_mutations.tsv"), "w", newline="")
    hg_w = csv.writer(hg_out, delimiter="\t", lineterminator="\n")
    mu_w = csv.writer(mu_out, delimiter="\t", lineterminator="\n")
    hg_w.writerow(["haplogroup", "parent", "depth", "n_subclades", "metagroup", "mutations"])
    mu_w.writerow(["haplogroup", "position", "type", "base", "end", "notation"])

    # preorder walk, iterative to avoid recursion limits
    stack = [(ROOT, "", 0)]
    seen = set()
    while stack:
        name, parent, depth = stack.pop()
        if name in seen:
            sys.exit("cycle at %s" % name)
        seen.add(name)
        hg = tree.get(name)
        rows = [mutation_row(m) for m in (hg.pos_list if hg is not None else [])]
        hg_w.writerow([name, parent, depth, len(children.get(name, [])),
                       "TRUE" if hg is not None and type(hg).__name__ == "MetaGroup" else "FALSE",
                       " ".join(r[4] for r in rows)])
        for r in rows:
            mu_w.writerow([name, r[1], r[0], r[2], r[3], r[4]])
        for kid in reversed(children.get(name, [])):
            stack.append((kid, name, depth + 1))
    hg_out.close()
    mu_out.close()
    if len(seen) != len(tree) + 1:
        sys.exit("walked %d haplogroups, expected %d" % (len(seen), len(tree) + 1))
    print("wrote %d haplogroups" % len(seen))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
