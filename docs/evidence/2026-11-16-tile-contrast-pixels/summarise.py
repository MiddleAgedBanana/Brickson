"""Gather every measured JSON in this clone's build/pixel and
build/pixel-control into measurements.json beside this script."""
import json, os, re

root = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
rows = []
want = re.compile(r"^(tile:|pressed:|Basics$|Back to Talking$|Touch$|Next$|Normal speed$|Save$)")
name = re.compile(r"(iphone|ipad)-(light|dark)-ic-(on|off)-(.*)-measured\.json$")
for folder, build in (("build/pixel", "main dc11030"),
                      ("build/pixel-control", "control: phraseFill = Color.accentColor")):
    path = os.path.join(root, folder)
    for f in sorted(os.listdir(path)):
        m = name.match(f)
        if not m:
            continue
        family, appearance, contrast, screen = m.groups()
        for t in json.load(open(os.path.join(path, f)))["targets"]:
            if not want.match(t["name"]) or (screen == "setup" and t["name"] == "Touch"):
                continue
            rows.append({
                "build": build, "device": family, "appearance": appearance,
                "increaseContrast": contrast, "screen": screen, "control": t["name"],
                "fill": t["fill"], "words": t["words"], "wordsOnFill": round(t["wordsOnFill"], 2),
                "page": t["page"], "fillOnPage": round(t["fillOnPage"], 2),
                "edgeBand": [{"colour": b["colour"], "share": round(b["share"], 3),
                              "onFill": round(b["onFill"], 2), "onPage": round(b["onPage"], 2)}
                             for b in t["band"]],
            })
out = os.path.join(root, "docs/evidence/2026-11-16-tile-contrast-pixels/measurements.json")
with open(out, "w") as handle:
    json.dump(rows, handle, indent=1)
    handle.write("\n")
main = [r for r in rows if r["build"].startswith("main")]
print(len(rows), "rows,", len(main), "on main")
print("fills on main:", sorted({r["fill"] for r in main}))
print("lowest words on fill:", min(r["wordsOnFill"] for r in main), "lowest fill on page:", min(r["fillOnPage"] for r in main))
rings = [b["onFill"] for r in main if r["control"].startswith("pressed:") and r["appearance"] == "light" for b in r["edgeBand"] if b["colour"] == "#000000"]
print("light pressed ring on fill:", sorted(set(rings)))
print("configurations:", sorted({(r["device"], r["appearance"], r["increaseContrast"]) for r in main}))
