"""Launch Brickson, tap through labels, and measure every button on the screen reached.

usage: nav.py <udid> <scale> <family> <light|dark> <on|off> <outdir> <name> <label> [<label> ...]
A label may be "@scroll" to swipe up once in the middle of the screen.
"""
import json, subprocess, sys, time, os

udid, scale, family, appearance, contrast, outdir, name = sys.argv[1:8]
labels = sys.argv[8:]
here = os.path.dirname(os.path.abspath(__file__))
tag = f"{family}-{appearance}-ic-{contrast}-{name}"

def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout

def elements(node, out):
    if isinstance(node, list):
        for c in node: elements(c, out)
        return out
    out.append(node)
    for c in node.get("children", []) or []: elements(c, out)
    return out

run("xcrun", "simctl", "ui", udid, "appearance", appearance)
run("xcrun", "simctl", "ui", udid, "increase_contrast", "enabled" if contrast == "on" else "disabled")
time.sleep(1)
run("xcrun", "simctl", "launch", "--terminate-running-process", udid, "family.avery.brickson",
    "--fresh-test-storage", "--home-profile=touch", "--uikit-animations=off",
    "-AppleLanguages", "(en)", "-AppleLocale", "en_US")
time.sleep(6)
for label in labels:
    if label == "@scroll":
        run("axe", "gesture", "scroll-up", "--udid", udid)
    elif label.startswith("@id:"):
        run("axe", "tap", "--id", label[4:], "--udid", udid)
    elif label.startswith("@type:"):
        run("axe", "type", label[6:], "--udid", udid)
    elif label.startswith("@until:"):
        run("axe", "gesture", "scroll-up", "--until-label", label[7:], "--udid", udid)
        run("axe", "gesture", "scroll-up", "--distance", "0.25", "--udid", udid)
    else:
        run("axe", "tap", "--label", label, "--udid", udid)
    time.sleep(3)
tree = json.loads(run("axe", "describe-ui", "--udid", udid))
json.dump(tree, open(os.path.join(outdir, f"{tag}-tree.json"), "w"))
png = os.path.join(outdir, f"{tag}.png")
run("xcrun", "simctl", "io", udid, "screenshot", "--type=png", png)
# The cover's own buttons: Home's stay in the tree under a cover, so skip
# any button whose frame matches one of Home's slots by label.
home = {"Yes", "No", "Emergency", "Get Attention", "Again", "Phrases", "Type", "Basics", "Needs",
        "Conversation", "Feelings", "Settings"}
targets = []
for n in elements(tree, []):
    lab = n.get("AXLabel")
    if n.get("type") == "Button" and lab and lab not in home and not lab.endswith("."):
        f = n["frame"]
        if f["width"] >= 44 and f["height"] >= 30:
            targets.append({"name": lab, "x": f["x"], "y": f["y"], "w": f["width"], "h": f["height"], "inset": 4})
tj = os.path.join(outdir, f"{tag}-targets.json")
json.dump(targets, open(tj, "w"), indent=1)
res = json.loads(run(os.path.join(here, "measure"), png, scale, tj))
json.dump(res, open(os.path.join(outdir, f"{tag}-measured.json"), "w"), indent=1, sort_keys=True)
for m in res["targets"]:
    if m["fill"] == m["page"]:
        continue
    print(f"{tag:40} {m['name'][:30]:30} fill {m['fill']} words {m['words']} {m['wordsOnFill']:.2f}:1 "
          f"(solid {m['solidWordPixels']}) page {m['page']} fill/page {m['fillOnPage']:.2f}")
