"""Lists every coop_t("english", "russian") call in mod/gml and the strings missing from mod/lang/strings.tsv.
usage: python tools/lang_extract.py   (prints missing English keys; run before tools/make_lang.py)"""
import csv
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# coop_t("en", "ru") and coop_tf("en {0}", "ru {0}", args...)
RX = re.compile(r'coop_tf?\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*[,)]')


def calls():
    pairs, odd = {}, []
    for f in sorted(glob.glob(os.path.join(ROOT, "mod", "gml", "*.gml"))):
        for i, line in enumerate(open(f, encoding="utf-8")):
            found = list(RX.finditer(line))
            for m in found:
                pairs.setdefault(m.group(1), m.group(2))
            if ("coop_t(" in line or "coop_tf(" in line) and not found and "function coop_t" not in line:
                odd.append("%s:%d: %s" % (os.path.basename(f), i + 1, line.strip()[:120]))
    return pairs, odd


if __name__ == "__main__":
    pairs, odd = calls()
    print(len(pairs), "strings")
    for o in odd:
        print("NOT A LITERAL PAIR:", o)
    tsv = os.path.join(ROOT, "mod", "lang", "strings.tsv")
    have = set()
    if os.path.exists(tsv):
        with open(tsv, encoding="utf-8", newline="") as f:
            have = {r[0] for r in csv.reader(f, delimiter="\t")}
    for en, ru in pairs.items():
        if en not in have:
            print("MISSING\t%s\t%s" % (en, ru))
