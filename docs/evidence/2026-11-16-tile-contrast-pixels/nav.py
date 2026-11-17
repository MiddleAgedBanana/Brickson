"""Launch Brickson, tap through labels, and measure every button on the screen reached.

usage: nav.py <udid> <scale> <iphone|ipad> <light|dark> <on|off> <outdir> <name> <step> [<step> ...]
A step is a label to tap, or "@scroll" (swipe up once), "@id:<identifier>"
(tap by identifier), "@type:<text>" (type it) or "@until:<label>" (scroll
until the label shows). <outdir> must be inside this clone's build/ folder;
compile measure.swift beside this script first (see its first lines).
Buttons Home keeps under a cover, at the label and frame they had on Home
at launch, are left out; everything else on screen is measured.
"""
import json, os, re, subprocess, sys, time

USAGE = __doc__.strip().splitlines()[2]
here = os.path.dirname(os.path.abspath(__file__))
build = os.path.realpath(os.path.join(here, "..", "..", "..", "build"))
if len(sys.argv) < 9:
    sys.exit(USAGE)
udid, scale, family, appearance, contrast, outdir, name = sys.argv[1:8]
steps = sys.argv[8:]
if not (re.fullmatch(r"[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}", udid) and scale in ("1", "2", "3")
        and family in ("iphone", "ipad") and appearance in ("light", "dark") and contrast in ("on", "off")
        and re.fullmatch(r"[a-z][a-z-]*", name)
        and all(step and not step.startswith("-") and len(step) < 200 for step in steps)):
    sys.exit(USAGE)
outdir = os.path.realpath(outdir)
if not outdir.startswith(build + os.sep):
    sys.exit("outdir must be inside " + build)
os.makedirs(outdir, exist_ok=True)
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


def buttons(tree):
    return [n for n in elements(tree, []) if n.get("type") == "Button" and n.get("AXLabel")]


def key(n):
    f = n["frame"]
    return (n["AXLabel"], round(f["x"]), round(f["y"]), round(f["width"]), round(f["height"]))


run("xcrun", "simctl", "ui", udid, "appearance", appearance)
run("xcrun", "simctl", "ui", udid, "increase_contrast", "enabled" if contrast == "on" else "disabled")
time.sleep(1)
run("xcrun", "simctl", "launch", "--terminate-running-process", udid, "family.avery.brickson",
    "--fresh-test-storage", "--home-profile=touch", "--uikit-animations=off",
    "-AppleLanguages", "(en)", "-AppleLocale", "en_US")
time.sleep(6)
home = {key(n) for n in buttons(json.loads(run("axe", "describe-ui", "--udid", udid)))}
for step in steps:
    if step == "@scroll":
        run("axe", "gesture", "scroll-up", "--udid", udid)
    elif step.startswith("@id:"):
        run("axe", "tap", "--id=" + step[4:], "--udid", udid)
    elif step.startswith("@type:"):
        run("axe", "type", step[6:], "--udid", udid)
    elif step.startswith("@until:"):
        run("axe", "gesture", "scroll-up", "--until-label=" + step[7:], "--udid", udid)
        run("axe", "gesture", "scroll-up", "--distance", "0.25", "--udid", udid)
    else:
        run("axe", "tap", "--label=" + step, "--udid", udid)
    time.sleep(3)
tree = json.loads(run("axe", "describe-ui", "--udid", udid))
with open(os.path.join(outdir, f"{tag}-tree.json"), "w") as handle:
    json.dump(tree, handle)
png = os.path.join(outdir, f"{tag}.png")
run("xcrun", "simctl", "io", udid, "screenshot", "--type=png", png)
targets = []
for n in buttons(tree):
    f = n["frame"]
    if key(n) not in home and f["width"] >= 44 and f["height"] >= 30:
        targets.append({"name": n["AXLabel"], "x": f["x"], "y": f["y"], "w": f["width"], "h": f["height"], "inset": 4})
if not targets:
    sys.exit(f"{tag}: no buttons beyond Home's on this screen; the steps did not reach it")
tj = os.path.join(outdir, f"{tag}-targets.json")
with open(tj, "w") as handle:
    json.dump(targets, handle, indent=1)
res = json.loads(run(os.path.join(here, "measure"), png, scale, tj))
with open(os.path.join(outdir, f"{tag}-measured.json"), "w") as handle:
    json.dump(res, handle, indent=1, sort_keys=True)
for m in res["targets"]:
    if m["fill"] == m["page"]:
        continue
    print(f"{tag:40} {m['name'][:30]:30} fill {m['fill']} words {m['words']} {m['wordsOnFill']:.2f}:1 "
          f"(solid {m['solidWordPixels']}) page {m['page']} fill/page {m['fillOnPage']:.2f}")
