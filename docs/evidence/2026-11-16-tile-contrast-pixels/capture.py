"""Capture Brickson's screens in one appearance and measure them.

usage: capture.py <udid> <scale> <family> <light|dark> <on|off> <outdir>
Sets the simulator's appearance and Increase Contrast, launches Brickson on
fresh test storage at touch's sizes and the default text size, then:
  home     - Home at rest: the phrase tiles, the selected category (Basics)
  pressed  - a touch held on the second phrase tile
  settings - Settings' first screen: Back to Talking
Each screen: a PNG, the accessibility tree (AXe), and measure's JSON.
"""
import json, subprocess, sys, time, os

udid, scale, family, appearance, contrast, outdir = sys.argv[1:7]
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(outdir, exist_ok=True)
tag = f"{family}-{appearance}-ic-{contrast}"
BUNDLE = "family.avery.brickson"

def run(*cmd, check=True):
    return subprocess.run(cmd, check=check, capture_output=True, text=True).stdout

def tree():
    return json.loads(run("axe", "describe-ui", "--udid", udid))

def elements(node, out):
    if isinstance(node, list):
        for c in node: elements(c, out)
        return out
    out.append(node)
    for c in node.get("children", []) or []: elements(c, out)
    return out

def find(t, label, kind="Button"):
    for n in elements(t, []):
        if n.get("type") == kind and n.get("AXLabel") == label:
            return n["frame"]
    return None

def tiles(t):
    return [n for n in elements(t, []) if n.get("type") == "Button" and n.get("AXUniqueId") == "phraseTile"] or \
           [n for n in elements(t, []) if n.get("type") == "Button" and (n.get("AXLabel") or "").endswith(".")]

def shoot(name, targets):
    png = os.path.join(outdir, f"{tag}-{name}.png")
    run("xcrun", "simctl", "io", udid, "screenshot", "--type=png", png)
    tj = os.path.join(outdir, f"{tag}-{name}-targets.json")
    json.dump(targets, open(tj, "w"), indent=1)
    res = json.loads(run(os.path.join(here, "measure"), png, scale, tj))
    json.dump(res, open(os.path.join(outdir, f"{tag}-{name}-measured.json"), "w"), indent=1, sort_keys=True)
    return res

def target(name, f, inset=6):
    return {"name": name, "x": f["x"], "y": f["y"], "w": f["width"], "h": f["height"], "inset": inset}

run("xcrun", "simctl", "ui", udid, "appearance", appearance)
run("xcrun", "simctl", "ui", udid, "increase_contrast", "enabled" if contrast == "on" else "disabled")
time.sleep(1)
run("xcrun", "simctl", "launch", "--terminate-running-process", udid, BUNDLE,
    "--fresh-test-storage", "--home-profile=touch", "--uikit-animations=off",
    "-AppleLanguages", "(en)", "-AppleLocale", "en_US")
time.sleep(6)
results = {}

t = tree()
json.dump(t, open(os.path.join(outdir, f"{tag}-home-tree.json"), "w"))
ts = tiles(t)
targets = [target(f"tile:{n['AXLabel']}", n["frame"]) for n in ts[:3]]
for label in ["Basics", "Needs", "Yes", "Emergency", "Phrases"]:
    f = find(t, label)
    if f: targets.append(target(label, f))
results["home"] = shoot("home", targets)

# A touch held on the second tile while the screenshot is taken.
f = ts[1]["frame"]
cx, cy = f["x"] + f["width"] / 2, f["y"] + f["height"] / 2
run("axe", "touch", "-x", str(cx), "-y", str(cy), "--down", "--udid", udid)
time.sleep(1.0)
results["pressed"] = shoot("pressed", [target(f"pressed:{ts[1]['AXLabel']}", f)])
run("axe", "touch", "-x", str(cx), "-y", str(cy), "--up", "--udid", udid)
time.sleep(3)

run("axe", "tap", "--label", "Settings", "--udid", udid)
time.sleep(3)
t = tree()
json.dump(t, open(os.path.join(outdir, f"{tag}-settings-tree.json"), "w"))
f = find(t, "Back to Talking")
results["settings"] = shoot("settings", [target("Back to Talking", f)] if f else [])

for screen, res in results.items():
    for m in res["targets"]:
        band = ", ".join(f"{b['colour']} {b['onFill']:.2f}/fill {b['onPage']:.2f}/page" for b in m["band"])
        print(f"{tag:28} {screen:8} {m['name'][:26]:26} fill {m['fill']} words {m['words']} {m['wordsOnFill']:.2f}:1 "
              f"(solid px {m['solidWordPixels']}) page {m['page']} fill/page {m['fillOnPage']:.2f} | band {band}")
