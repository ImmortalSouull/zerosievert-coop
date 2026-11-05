"""Checks mod/hooks.txt against the decompiled game (work/decomp/CodeEntries) after a game update.

Reports hooks whose target code entry is gone and findreplace hooks whose FIND text is no longer there
(the build would fail on those). Usage: python tools/check_hooks.py [-v]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(os.path.dirname(ROOT), "zerosievert-coop-work")
DECOMP = os.path.join(WORK, "decomp", "CodeEntries")


def parse_hooks(path):
    lines = open(path, encoding="utf-8").read().replace("\r\n", "\n").split("\n")
    hooks, i = [], 0
    while i < len(lines):
        if not lines[i].startswith("### "):
            i += 1
            continue
        op, code = lines[i][4:].split(" ")[:2]
        body, j = [], i + 1
        while j < len(lines) and lines[j] != "<<<END":
            body.append(lines[j])
            j += 1
        hooks.append({"op": op, "code": code, "body": body, "line": i + 1})
        i = j + 1
    return hooks


def main():
    verbose = "-v" in sys.argv
    hooks = parse_hooks(os.path.join(ROOT, "mod", "hooks.txt"))
    own = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "mod", "gml"))}
    bad = 0
    for h in hooks:
        path = os.path.join(DECOMP, h["code"] + ".gml")
        if h["code"] in own:
            continue
        if not os.path.exists(path):
            print(f"MISSING  line {h['line']:4}  {h['op']:11} {h['code']}")
            bad += 1
            continue
        if h["op"] != "findreplace":
            continue
        src = open(path, encoding="utf-8").read().replace("\r\n", "\n")
        f, r = h["body"].index("<<<FIND"), h["body"].index("<<<REPLACE")
        find = "\n".join(h["body"][f + 1:r])
        if find not in src:
            print(f"NOFIND   line {h['line']:4}  {h['code']}")
            if verbose:
                print("         " + find.replace("\n", "\n         "))
            bad += 1
    print(f"{len(hooks)} hooks, {bad} broken")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
