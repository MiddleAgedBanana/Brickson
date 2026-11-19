"""Capture the design review sheet in each appearance, measure it, and lay
the captures side by side (docs/DECISIONS.md, "A design review sheet in
debug builds"). Runs on a Mac with Xcode and AXe, against a booted
simulator with a debug build of Brickson installed. README.md beside this
file says how.

usage:
  review.py capture <udid> <iphone|ipad> <outdir> [<appearance> ...]
  review.py screens <udid> <iphone|ipad> <outdir> [<appearance> ...]
  review.py inactive <udid> <outdir> <inactive-light|inactive-dark> <covered-top> <covered-bottom>
  review.py compose <outdir>

capture   sets each appearance on the simulator (all of them when none is
          named), launches the sheet (`--screen=design-review`), checks
          that its readout names the appearance, and photographs it page
          by page, holding a touch on each pressed specimen; then Home,
          Home while typing, Home with the alarm sounding and Settings.
          Every specimen and every button is measured from the pixels.
inactive  the same sheet and screens on an iPad in Windowed Apps, behind
          a Settings window that has the focus and covers Brickson's window
          from `covered-top` to `covered-bottom`, in points. Run `capture` for the same iPad
          first: the sheet's frames come from its `light` run.
screens   takes Home, typing, the alarm and Settings again, into the
          manifests `capture` wrote.
compose   lays every appearance side by side, one picture for each part
          of the sheet and each screen, and writes README.md beside them.

Nothing from outside reaches AXe as an option of its own: every value this
script passes is one of its own constants, a number it worked out, or the
simulator's UDID, which must look like one (test_review.py).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "..", "..", "build", "review", "review-sheet")
BUNDLE = "family.avery.brickson"
UDID = re.compile(r"[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}")
SCALES = {"iphone": 3, "ipad": 2}
FAMILIES = tuple(SCALES)

# Every appearance a capture can be taken in: the settings it needs on top
# of the plain ones, and the words the sheet's readout must show.
PLAIN = {"mode": "light", "contrast": False, "transparency": False, "borders": False,
         "differentiate": False, "bold": False, "text": "large"}
APPEARANCES = {
    "light": {},
    "dark": {"mode": "dark"},
    "light-increase-contrast": {"contrast": True},
    "dark-increase-contrast": {"mode": "dark", "contrast": True},
    "reduce-transparency": {"transparency": True},
    "show-borders": {"borders": True},
    "differentiate-without-colour": {"differentiate": True},
    "bold-text": {"bold": True},
    "largest-text": {"text": "AX5"},
}
INACTIVE = {
    "inactive-light": {},
    "inactive-dark": {"mode": "dark"},
}
TITLES = {
    "light": "Light",
    "dark": "Dark",
    "light-increase-contrast": "Light, Increase Contrast",
    "dark-increase-contrast": "Dark, Increase Contrast",
    "reduce-transparency": "Reduce Transparency",
    "show-borders": "Show Borders",
    "differentiate-without-colour": "Differentiate Without Colour",
    "bold-text": "Bold Text",
    "largest-text": "Largest text (AX5)",
    "inactive-light": "Inactive window, light",
    "inactive-dark": "Inactive window, dark",
}
ROLE_ASSETS = ["AccentColor", "ControlFill", "EmergencyFill", "AttentionFill", "StopFill"]
EXPECTED = (
    [f"review.colour.{a}" for a in ROLE_ASSETS] + ["review.ink.primary", "review.ink.status"]
    + [f"review.spacing.{n}" for n in (2, 4, 6, 8, 12, 16, 24)]
    + [f"review.corner.{c}" for c in ("fixed", "capsule", "concentric")]
    + [f"review.control.{a}.{s}" for a in ROLE_ASSETS for s in ("on", "selected", "off", "pressed")]
    + ["review.tile.AccentColor", "review.tile.EmergencyFill"]
    + [f"review.settings.{a}.{s}" for a in ("AccentColor", "ControlFill") for s in ("on", "off")]
)
TEXT_SIZES = {"large": "large", "AX5": "accessibility-extra-extra-extra-large"}
LAUNCH = ["--fresh-test-storage", "--uikit-animations=off", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
HOME = LAUNCH + ["--home-profile=touch", "--attention-tone=silent"]


def settings_for(name):
    """The plain settings with the appearance's own on top."""
    table = APPEARANCES if name in APPEARANCES else INACTIVE
    return {**PLAIN, **table[name]}


def expected_readout(settings, active=True):
    """The words the sheet's readout shows when the app received
    `settings` (DesignReviewReadoutLine in the app)."""
    return [
        "scheme=" + settings["mode"],
        "contrast=" + ("increased" if settings["contrast"] else "standard"),
        "transparency=" + ("reduced" if settings["transparency"] else "standard"),
        "borders=" + ("on" if settings["borders"] else "off"),
        "differentiate=" + ("on" if settings["differentiate"] else "off"),
        "bold=" + ("on" if settings["bold"] else "off"),
        "text=" + settings["text"],
        "window=" + ("active" if active else "inactive"),
    ]


def readout_matches(readout, settings, active=True):
    words = (readout or "").split()
    return all(word in words for word in expected_readout(settings, active))


def setting_commands(udid, settings):
    """The commands that put the simulator in `settings`: Apple's
    devicectl for what it offers, the accessibility defaults for Bold Text
    and Differentiate Without Colour, which it does not."""
    on = lambda value: "on" if value else "off"
    return [
        ["xcrun", "devicectl", "device", "settings", "appearance", "--device", udid,
         "--mode", settings["mode"], "--increase-contrast", on(settings["contrast"]),
         "--reduce-transparency", on(settings["transparency"]), "--show-borders", on(settings["borders"]),
         "--text-size", TEXT_SIZES[settings["text"]],
         "--larger-accessibility-sizes", on(settings["text"] != "large")],
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "com.apple.Accessibility",
         "EnhancedTextLegibilityEnabled", "-bool", "true" if settings["bold"] else "false"],
        ["xcrun", "simctl", "spawn", udid, "defaults", "write", "com.apple.Accessibility",
         "DifferentiateWithoutColor", "-bool", "true" if settings["differentiate"] else "false"],
    ]


def run(*cmd, stdin=None, check=True):
    return subprocess.run(cmd, check=check, capture_output=True, text=True, input=stdin).stdout


def elements(node, out):
    if isinstance(node, list):
        for child in node:
            elements(child, out)
        return out
    out.append(node)
    for child in node.get("children", []) or []:
        elements(child, out)
    return out


def frame_of(node):
    f = node["frame"]
    return {"x": f["x"], "y": f["y"], "w": f["width"], "h": f["height"]}


def fully_inside(frame, top, bottom, width):
    return frame["y"] >= top and frame["y"] + frame["h"] <= bottom and frame["x"] >= 0 and frame["x"] + frame["w"] <= width


def kind_of(identifier):
    """What a specimen's reading means: words on a fill, words on the
    screen, or a shape with no words."""
    part = identifier.split(".")[1]
    return {"ink": "ink", "spacing": "shape", "corner": "shape"}.get(part, "fill")


def verdicts(kind, reading):
    """Each pair the README holds to a target, as (what, ratio, target)."""
    if not reading:
        return []
    pairs = []
    if kind in ("fill", "ink"):
        pairs.append(("words", reading["wordsOnFill"], 4.5))
    if kind in ("fill", "shape"):
        pairs.append(("edge", reading["edgeOnPage"], 3.0))
    return pairs


def shown(ratio, target):
    """A ratio as the sheet prints it: two decimals, or four where two
    would round a pair that misses its target up to the target."""
    text = f"{ratio:.2f}"
    return f"{ratio:.4f}" if ratio < target and float(text) >= target else text


def caption(kind, reading):
    if not reading:
        return ["not measured"], False
    lines, fails = [], False
    for what, ratio, target in verdicts(kind, reading):
        under = ratio < target
        fails = fails or under
        colours = f"{reading['words']} on {reading['fill']}" if what == "words" else f"{reading['edge']} on {reading['page']}"
        lines.append(f"{what} {shown(ratio, target)}:1{' under ' + str(target) if under else ''}  {colours}")
    if len(reading.get("foregrounds", [])) > 1:
        lines.append("also drawn: " + ", ".join(f["colour"] for f in reading["foregrounds"][1:]))
    return lines, fails


class Simulator:
    def __init__(self, udid, family, outdir):
        # The usual scale until `calibrate` reads it from a capture.
        self.udid, self.family, self.scale = udid, family, SCALES[family]
        self.outdir = outdir

    def apply(self, settings):
        for command in setting_commands(self.udid, settings):
            run(*command)
        time.sleep(2)

    def launch(self, arguments):
        run("xcrun", "simctl", "launch", "--terminate-running-process", self.udid, BUNDLE, *arguments)

    def tree(self):
        return elements(json.loads(run("axe", "describe-ui", "--udid", self.udid)), [])

    def screenshot(self, name):
        path = os.path.join(self.outdir, name + ".png")
        run("xcrun", "simctl", "io", self.udid, "screenshot", "--type=png", path)
        return path

    def calibrate(self, window, png):
        """Pixels per point, from a capture of the whole window: never
        assumed from the device, which can be 2x or 3x."""
        width = png_size(png)[0]
        scale = width / window["width"]
        if abs(scale - round(scale)) > 0.01 or round(scale) not in (1, 2, 3):
            sys.exit(f"{png}: {width} pixels for {window['width']} points is no screen scale")
        self.scale = round(scale)
        os.remove(png)

    def measure(self, png, targets):
        if not targets:
            return {}
        path = png[:-4] + "-targets.json"
        with open(path, "w") as handle:
            json.dump(targets, handle, indent=1)
        return {m["name"]: m for m in json.loads(run(TOOL, "measure", png, str(self.scale), path))}

    def wait_for(self, predicate, seconds=30):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                nodes = self.tree()
            except (subprocess.CalledProcessError, json.JSONDecodeError):
                nodes = []
            if predicate(nodes):
                return nodes
            time.sleep(1)
        return None


def readout_of(nodes):
    for node in nodes:
        if node.get("AXUniqueId") == "review.readout":
            return node.get("AXLabel")
    return None


def capture_sheet(sim, name, settings):
    sim.launch(LAUNCH + ["--screen=design-review"])
    nodes = sim.wait_for(lambda n: readout_of(n) is not None)
    readout = readout_of(nodes or [])
    if not readout_matches(readout, settings):
        sys.exit(f"{name}: the sheet's readout is {readout!r}, not {' '.join(expected_readout(settings))}; nothing saved")
    window = next(n for n in nodes if n.get("type") == "Application")["frame"]
    sim.calibrate(window, sim.screenshot(f"{name}-scale"))
    readout_frame = frame_of(next(n for n in nodes if n.get("AXUniqueId") == "review.readout"))
    top = readout_frame["y"]
    bottom = window["height"] - 20
    specimens, pages, last, partial = {}, [], None, {}
    for page in range(60):
        nodes, png = still(sim, f"{name}-sheet-{page:02d}")
        signature = positions(nodes)
        if signature == last:
            break
        last = signature
        visible = {n["AXUniqueId"]: frame_of(n) for n in nodes
                   if (n.get("AXUniqueId") or "").startswith("review.") and n["AXUniqueId"] != "review.readout"
                   and fully_inside(frame_of(n), top, bottom, window["width"])}
        for n in nodes:
            identifier, f = n.get("AXUniqueId") or "", frame_of(n)
            if identifier.startswith("review.") and identifier not in visible and identifier != "review.readout":
                shown = min(f["y"] + f["h"], bottom) - max(f["y"], top)
                if shown > partial.get(identifier, (0,))[0]:
                    clipped = dict(f, y=max(f["y"], top), h=shown)
                    partial[identifier] = (shown, png, clipped)
        fresh = {i: f for i, f in visible.items() if i not in specimens and not i.endswith(".pressed")}
        for identifier, measured in sim.measure(png, [dict(name=i, **f) for i, f in fresh.items()]).items():
            specimens[identifier] = {"image": png, "frame": measured["frame"], "reading": measured.get("reading")}
        for identifier, f in visible.items():
            if identifier.endswith(".pressed") and identifier not in specimens:
                specimens[identifier] = press(sim, f"{name}-pressed-{len(specimens):02d}", identifier, f)
        pages.append(png)
        if all(i in specimens for i in EXPECTED):
            break
        run("axe", "gesture", "scroll-up", "--distance", "0.3", "--udid", sim.udid)
    # A specimen taller than the screen never shows whole: it is measured
    # where most of it shows, and marked so.
    for identifier, (shown, png, clipped) in partial.items():
        if identifier not in specimens and not identifier.endswith(".pressed"):
            measured = sim.measure(png, [dict(name=identifier, **clipped)])[identifier]
            specimens[identifier] = {"image": png, "frame": measured["frame"], "reading": measured.get("reading"), "clipped": True}
    missing = sorted(i for i in EXPECTED if i not in specimens)
    if missing:
        sys.exit(f"{name}: the sheet never showed {', '.join(missing)}; nothing saved")
    return {"readout": readout, "readoutFrame": readout_frame, "pages": pages, "specimens": specimens, "missing": missing}


def positions(nodes):
    return [(n.get("AXUniqueId"), round(n["frame"]["y"], 1)) for n in nodes if (n.get("AXUniqueId") or "").startswith("review.")]


def still(sim, shot):
    """The screen once it has stopped moving: the tree read twice the
    same, the screenshot, and the tree read the same once more, so every
    frame belongs to the pixels it is measured on."""
    for _ in range(10):
        before = sim.tree()
        time.sleep(0.8)
        middle = sim.tree()
        if positions(before) != positions(middle):
            continue
        png = sim.screenshot(shot)
        if positions(sim.tree()) == positions(middle):
            return middle, png
    sys.exit(f"{shot}: the screen never stopped moving")


def press(sim, shot, identifier, frame):
    x, y = frame["x"] + frame["w"] / 2, frame["y"] + frame["h"] / 2
    run("axe", "touch", "-x", f"{x:.1f}", "-y", f"{y:.1f}", "--down", "--udid", sim.udid)
    time.sleep(1.0)
    try:
        png = sim.screenshot(shot)
        measured = sim.measure(png, [dict(name=identifier, **frame)])[identifier]
    finally:
        run("axe", "touch", "-x", f"{x:.1f}", "-y", f"{y:.1f}", "--up", "--udid", sim.udid)
        time.sleep(1.0)
    return {"image": png, "frame": measured["frame"], "reading": measured.get("reading")}


def keyboard_top(nodes):
    """Where Apple's keyboard starts, or nil while none shows."""
    tops = [n["frame"]["y"] for n in nodes if n.get("AXUniqueId") == "inputView" and n["frame"]["height"] > 0]
    return min(tops) if tops else None


def key_of(node):
    f = node["frame"]
    return (node.get("AXLabel"), round(f["x"]), round(f["y"]), round(f["width"]), round(f["height"]))


def buttons(nodes, width, height, hidden=frozenset()):
    """The controls a screen shows, each with a name of its own: Brickson's
    controls, and the keys of Apple's keyboard where it shows. Controls the
    keyboard covers, or a cover hides (`hidden`), are left out."""
    found, top = [], keyboard_top(nodes)
    for node in nodes:
        if node.get("type") not in ("Button", "TextField", "TextView") or not (node.get("AXLabel") or node.get("AXUniqueId")):
            continue
        if key_of(node) in hidden:
            continue
        f = frame_of(node)
        if node.get("type") in ("TextField", "TextView"):
            # Home's message field draws its edge this far outside the text
            # field itself (MessageField.inset, Spacing.xSmall).
            f = {"x": f["x"] - FIELD_INSET, "y": f["y"] - FIELD_INSET, "w": f["w"] + 2 * FIELD_INSET, "h": f["h"] + 2 * FIELD_INSET}
        if not fully_inside(f, 0, height, width):
            continue
        in_keyboard = top is not None and f["y"] + f["h"] > top
        if in_keyboard and f["y"] >= top - 1 and f["w"] >= 20 and f["h"] >= 20:
            kind, inset = "key", 3
        elif not in_keyboard and f["w"] >= 44 and f["h"] >= 30:
            kind, inset = "control", review_inset(node)
        else:
            continue
        name = f"{len(found):02d}:{node.get('AXUniqueId') or node.get('AXLabel')}"
        found.append({"name": name, "label": node.get("AXLabel") or node.get("AXUniqueId"), "kind": kind, "inset": inset, **f})
    return found


FIELD_INSET = 6
# How far inside a specimen's edge its fill and words are read: past the
# deepest ring a Home control draws (ReviewMeasure.defaultInset).
SPECIMEN_INSET = 6
# Words typed in the message field for the typing capture: neutral, like
# the starter library's.
TYPED = "Could you open the window?"


def review_inset(node):
    # A text field draws no ring: its words start just inside its edge.
    return FIELD_INSET - 2 if node.get("type") in ("TextField", "TextView") else 6


def capture_screen(sim, name, screen, nodes, hidden=frozenset()):
    window = next(n for n in nodes if n.get("type") == "Application")["frame"]
    png = sim.screenshot(f"{name}-{screen}")
    with open(png[:-4] + "-tree.json", "w") as handle:
        json.dump(nodes, handle)
    targets = buttons(nodes, window["width"], window["height"], hidden)
    measured = sim.measure(png, [dict({k: t[k] for k in ("name", "x", "y", "w", "h", "inset")}, key=t["kind"] == "key") for t in targets])
    return {"image": png, "buttons": [{"label": t["label"], "kind": t["kind"], "inset": t["inset"], **measured[t["name"]]}
                                      for t in targets if t["name"] in measured]}


def has(identifier):
    return lambda nodes: any(n.get("AXUniqueId") == identifier for n in nodes)


def capture_screens(sim, name):
    screens = {}
    sim.launch(HOME)
    nodes = sim.wait_for(has("getAttention"))
    if not nodes:
        sys.exit(f"{name}: Home did not open")
    screens["home"] = capture_screen(sim, name, "home", nodes)
    home = frozenset(key_of(n) for n in nodes if n.get("type") == "Button")
    # The message to show while typing goes in as a kept draft, never
    # typed: keys typed through the simulator count as a hardware keyboard,
    # and iOS then hides its own (DraftFile, test storage).
    container = run("xcrun", "simctl", "get_app_container", sim.udid, BUNDLE, "data").strip()
    drafts = os.path.join(container, "tmp", "BricksonTestStorage", "Typing")
    os.makedirs(drafts, exist_ok=True)
    with open(os.path.join(drafts, "draft.txt"), "w") as handle:
        handle.write(TYPED)
    sim.launch(["--test-storage"] + HOME[1:])
    sim.wait_for(has("getAttention"))
    run("axe", "tap", "--id=type", "--udid", sim.udid)
    nodes = sim.wait_for(lambda n: keyboard_top(n) is not None, seconds=15)
    if not nodes:
        sys.exit(f"{name}: Apple's keyboard did not show for the typing capture; nothing saved")
    time.sleep(1.5)
    screens["typing"] = capture_screen(sim, name, "typing", sim.tree())
    sim.launch(HOME)
    sim.wait_for(has("getAttention"))
    run("axe", "tap", "--id=getAttention", "--udid", sim.udid)
    nodes = sim.wait_for(has("stopAlert"), seconds=10)
    if nodes:
        time.sleep(1)
        screens["alarm"] = capture_screen(sim, name, "alarm", sim.tree())
        run("axe", "tap", "--id=stopAlert", "--udid", sim.udid)
    # Over Home at the sizes Home was captured at, so the controls the
    # cover hides are the ones `home` holds.
    sim.launch(HOME + ["--screen=settings"])
    nodes = sim.wait_for(lambda n: any(x.get("AXLabel") == "Back to Talking" for x in n))
    if nodes:
        time.sleep(1)
        screens["settings"] = capture_screen(sim, name, "settings", sim.tree(), hidden=home)
    return screens


def capture(udid, family, outdir, names, screens_only=False):
    sim = Simulator(udid, family, None)
    # The full software keyboard, as AGENTS.md's Gotchas ask, for the typing capture.
    for key in ("AutomaticMinimizationEnabled", "DidShowContinuousPathIntroduction"):
        run("xcrun", "simctl", "spawn", udid, "defaults", "write", "com.apple.keyboard.preferences",
            key, "-bool", "false" if key == "AutomaticMinimizationEnabled" else "true")
    try:
        for name in names:
            settings = settings_for(name)
            final = os.path.join(outdir, family, name)
            sim.outdir = begin(final, keep=screens_only)
            sim.apply(settings)
            if screens_only:
                with open(os.path.join(sim.outdir, "manifest.json")) as handle:
                    manifest = json.loads(handle.read().replace(final + os.sep, sim.outdir + os.sep))
                sim.scale = manifest["scale"]
            else:
                manifest = {"family": family, "appearance": name, "settings": settings}
                manifest["sheet"] = capture_sheet(sim, name, settings)
                manifest["scale"] = sim.scale
            manifest["screens"] = capture_screens(sim, name)
            finish(sim.outdir, final, manifest)
            print(f"{family} {name}: {len(manifest['sheet']['specimens'])} specimens, screens {sorted(manifest['screens'])}")
    finally:
        sim.apply(PLAIN)


def begin(final, keep=False):
    """A fresh folder beside `final` for one run, so a run that fails
    leaves the last good one whole: with its files when `keep`."""
    work = final + ".partial"
    shutil.rmtree(work, ignore_errors=True)
    if keep:
        shutil.copytree(final, work)
    else:
        os.makedirs(work)
    return work


def finish(work, final, manifest):
    """The run's manifest, pointing at the files' final place, and the
    folder put where the last run's was."""
    text = json.dumps(manifest, indent=1, sort_keys=True).replace(json.dumps(work + os.sep)[1:-1], json.dumps(final + os.sep)[1:-1])
    with open(os.path.join(work, "manifest.json"), "w") as handle:
        handle.write(text)
    shutil.rmtree(final, ignore_errors=True)
    os.rename(work, final)


# MARK: - The inactive window

def probe(udid, x, y):
    """The element of the app under a point, with its frame in its own
    window. In Windowed Apps AXe's whole tree is another app's, so the
    inactive window is read a point at a time."""
    out = run("axe", "describe-ui", "--point", f"{x:.1f},{y:.1f}", "--udid", udid, check=False)
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


# How far above the focused window its shadow darkens what is behind it, in
# points, measured on the iPad in Windowed Apps: colours there are the
# shadow's, not Brickson's.
SHADOW_ABOVE = 140
# Past the round corner of a specimen (`CornerRule.minimum`), where its
# sides are straight.
CORNER_CLEARANCE = 16


def inactive(udid, outdir, name, covered_top, covered_bottom):
    """The sheet, Home and Settings in an inactive window: an iPad in
    Windowed Apps, with Brickson's window behind a Settings window that has
    the focus and covers its middle, from `covered_top` to `covered_bottom`
    (points). AXe reads only the focused app's tree there, so the sheet is
    read a point at a time (`probe`)."""
    settings = settings_for(name)
    reference = json.load(open(os.path.join(outdir, "ipad", "light", "manifest.json")))
    # Only what the full-screen capture showed on its first page: the
    # inactive window is captured unscrolled.
    first = reference["sheet"]["pages"][0]
    specimens = {i: s for i, s in reference["sheet"]["specimens"].items() if s["image"] == first}
    final = os.path.join(outdir, "ipad", name)
    sim = Simulator(udid, "ipad", begin(final))
    sim.scale = reference["scale"]
    sim.apply(settings)
    # Brickson's own rows above the Settings window, clear of its shadow,
    # below the status bar, whose clock may change.
    bands = ["40", f"{covered_top - SHADOW_ABOVE:.0f}"]
    try:
        result = {"family": "ipad", "appearance": name, "scale": sim.scale, "settings": settings, "screens": {},
                  "covered": [covered_top, covered_bottom]}
        for screen, arguments in (("sheet", LAUNCH + ["--screen=design-review"]), ("home", HOME), ("settings", HOME + ["--screen=settings"])):
            sim.launch(arguments)
            time.sleep(6)
            active = sim.screenshot(f"{name}-{screen}-active")
            run("xcrun", "simctl", "launch", udid, "com.apple.Preferences")
            time.sleep(3)
            png = sim.screenshot(f"{name}-{screen}")
            difference = json.loads(run(TOOL, "diff", active, png, str(sim.scale), *bands))
            result["screens"][screen] = {"image": png, "active": active, "difference": difference, "buttons": []}
            if screen == "sheet":
                result["sheet"] = inactive_sheet(sim, name, png, settings, specimens, covered_top, covered_bottom)
        finish(sim.outdir, final, result)
        print(f"ipad {name}: {len(result['sheet']['specimens'])} specimens; pixels changed by going inactive "
              f"{[(s, v['difference']['pixels']) for s, v in result['screens'].items()]}")
    finally:
        sim.apply(PLAIN)


def inactive_sheet(sim, name, png, settings, specimens, covered_top, covered_bottom):
    """The readout, checked, and every specimen the Settings window leaves
    whole, measured: where each is comes from its frame in the full-screen
    `light` capture (the window is as wide, so the sheet lays out the same),
    moved by where the window put a specimen found by `probe`."""
    found, readout = {}, None
    for y in range(44, 1376, 8):
        if covered_top <= y <= covered_bottom:
            continue
        for x in (60, 300, 560):
            hit = probe(sim.udid, x, y)
            identifier = (hit or {}).get("AXUniqueId") or ""
            if identifier == "review.readout":
                readout = hit.get("AXLabel")
            elif identifier in specimens and identifier not in found and specimens[identifier]["reading"]["fill"] != specimens[identifier]["reading"]["page"]:
                found[identifier] = (x, y, hit["frame"])
        if readout and len(found) >= 2:
            break
    if not readout_matches(readout, settings, active=False):
        sys.exit(f"{name}: the readout is {readout!r}, not an inactive window in this appearance; nothing kept")
    offset = None
    for identifier, (x, y, inside) in found.items():
        # The colour the inactive window shows there, whatever the palette.
        colour = json.loads(run(TOOL, "colour", png, str(sim.scale), f"{x:.1f}", f"{y:.1f}"))["colour"]
        locate = lambda px, py: json.loads(run(TOOL, "locate", png, str(sim.scale), f"{px:.1f}", f"{py:.1f}", colour))
        try:
            rough = locate(x, y)
            # Again through the middle of its side and clear of its round
            # corners, where the first point may have been near one.
            middle = rough["top"] + (y - rough["top"]) if y - rough["top"] > CORNER_CLEARANCE else rough["top"] + inside["height"] / 2
            left = locate(rough["left"] + 2, middle)["left"]
            top = locate(left + CORNER_CLEARANCE, middle)["top"]
        except subprocess.CalledProcessError:
            continue  # the point fell on its words, not its fill
        # Where the window put the sheet: the fill's edge on the screen, less
        # its frame in the full-screen capture.
        full = specimens[identifier]["frame"]
        if abs(inside["width"] - full["width"]) <= 0.5:
            offset = (left - full["x"], top - full["y"])
            break
    if offset is None:
        sys.exit(f"{name}: no specimen of the sheet could be placed in the inactive window")
    dx, dy = offset
    targets = []
    for identifier, specimen in specimens.items():
        f = specimen["frame"]
        t = {"name": identifier, "x": f["x"] + dx, "y": f["y"] + dy, "w": f["width"], "h": f["height"]}
        # Brickson's window is the one above the Settings window.
        whole = t["y"] >= 40 and t["y"] + t["h"] <= covered_top - SHADOW_ABOVE
        if whole and not identifier.endswith(".pressed"):
            targets.append(t)
    measured = sim.measure(png, targets)
    return {"readout": readout, "offset": [dx, dy], "pages": [png], "missing": [],
            "specimens": {i: {"image": png, "frame": m["frame"], "reading": m.get("reading")} for i, m in measured.items()}}


# MARK: - The side-by-side sheets

ROLES = {"AccentColor": "Phrase", "ControlFill": "Control", "EmergencyFill": "Emergency",
         "AttentionFill": "Get Attention", "StopFill": "Stop"}
STATES = ["on", "selected", "off", "pressed"]
SECTIONS = [
    ("colours", "Colour tokens: the words on each fill, and words on the screen", ("review.colour.", "review.ink.")),
    ("spacing-and-corners", "The spacing scale and the three kinds of corner", ("review.spacing.", "review.corner.")),
    ("home-controls", "Home's controls in each state, and phrase tiles", ("review.control.", "review.tile.")),
    ("settings-rows", "Settings' rows: the system's bordered prominent button", ("review.settings.",)),
]
SCREENS = [
    ("home", "Home at rest"),
    ("typing", "Home while typing, with Apple's keyboard"),
    ("alarm", "Home with Get Attention sounding"),
    ("settings", "Settings' first screen"),
    ("sheet", "The review sheet's first screen"),
]
PADDING = 3


def order_key(identifier):
    parts = identifier.split(".")
    section = next(index for index, (_, _, prefixes) in enumerate(SECTIONS) if identifier.startswith(prefixes))
    group = ["colour", "ink", "spacing", "corner", "control", "tile", "settings"].index(parts[1])
    rest = parts[2:]
    asset = list(ROLES).index(rest[0]) if rest and rest[0] in ROLES else 0
    state = STATES.index(rest[1]) if len(rest) > 1 and rest[1] in STATES else 0
    number = int(rest[0]) if rest and rest[0].isdigit() else 0
    corner = ["fixed", "capsule", "concentric"].index(rest[0]) if parts[1] == "corner" else 0
    ink = ["primary", "status"].index(rest[0]) if parts[1] == "ink" else 0
    return (section, group, asset, state, number, corner, ink)


def label_of(identifier):
    parts = identifier.split(".")
    rest = parts[2:]
    role = ROLES.get(rest[0], rest[0]) if rest else ""
    return {
        "colour": lambda: f"{role} ({rest[0]})",
        "ink": lambda: {"primary": "Primary ink, message size", "status": "Primary ink, status line"}[rest[0]],
        "spacing": lambda: f"{rest[0]} points",
        "corner": lambda: f"{rest[0].capitalize()} corner",
        "control": lambda: f"{role}, {rest[1]}",
        "tile": lambda: f"{role} tile",
        "settings": lambda: f"{role} row, {rest[1]}",
    }[parts[1]]()


def crop(frame, scale, size):
    """The specimen and a little of the screen round it, in pixels."""
    x0 = max(0, int(round((frame["x"] - PADDING) * scale)))
    y0 = max(0, int(round((frame["y"] - PADDING) * scale)))
    x1 = min(size[0], int(round((frame["x"] + frame["width"] + PADDING) * scale)))
    y1 = min(size[1], int(round((frame["y"] + frame["height"] + PADDING) * scale)))
    return {"x": x0, "y": y0, "width": x1 - x0, "height": y1 - y0}


def png_size(path):
    with open(path, "rb") as handle:
        header = handle.read(24)
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


def manifests(outdir, family):
    found = []
    for name in list(APPEARANCES) + list(INACTIVE):
        path = os.path.join(outdir, family, name, "manifest.json")
        if os.path.exists(path):
            with open(path) as handle:
                manifest = json.load(handle)
            remeasure(manifest)
            found.append(manifest)
    return found


def screen_failures(screen):
    failures = []
    for button in screen.get("buttons", []):
        if button.get("kind") == "key":
            continue
        reading = button.get("reading")
        for what, ratio, target in verdicts("fill", reading):
            if ratio < target:
                failures.append((button.get("label") or button["name"], what, ratio, target, reading))
    return failures


def compose_layout(path, layout, out):
    with open(path, "w") as handle:
        json.dump(layout, handle, indent=1)
    run(TOOL, "compose", path, out)


def remeasure(manifest):
    """Every reading taken again from its capture and frame with the tool
    as it is now, so a better measurement needs no new captures."""
    scale = str(manifest["scale"])
    jobs = {}
    for identifier, specimen in (manifest.get("sheet") or {}).get("specimens", {}).items():
        jobs.setdefault(specimen["image"], []).append((specimen, identifier, SPECIMEN_INSET, False))
    for screen in manifest.get("screens", {}).values():
        for index, button in enumerate(screen.get("buttons", [])):
            inset = button.get("inset") or {"key": 3, "control": 6}.get(button.get("kind"), 6)
            if button.get("name", "").endswith("messageField"):
                inset = FIELD_INSET - 2
            jobs.setdefault(screen["image"], []).append((button, f"{index:03d}", inset, button.get("kind") == "key"))
    for image, items in jobs.items():
        path = image[:-4] + "-remeasure.json"
        with open(path, "w") as handle:
            json.dump([{"name": name, "x": item["frame"]["x"], "y": item["frame"]["y"], "w": item["frame"]["width"],
                        "h": item["frame"]["height"], "inset": inset, "key": key} for item, name, inset, key in items], handle)
        readings = {m["name"]: m.get("reading") for m in json.loads(run(TOOL, "measure", image, scale, path))}
        os.remove(path)
        for item, name, _, _ in items:
            item["reading"] = readings.get(name)


def compose(outdir):
    readme, failures, keys = [], [], []
    for family in FAMILIES:
        found = manifests(outdir, family)
        if not found:
            continue
        columns = [TITLES[m["appearance"]] for m in found]
        identifiers = sorted({i for m in found for i in (m.get("sheet") or {}).get("specimens", {})}, key=order_key)
        work = os.path.join(outdir, family, "layouts")
        os.makedirs(work, exist_ok=True)
        for key, title, prefixes in SECTIONS:
            rows = []
            for identifier in (i for i in identifiers if i.startswith(prefixes)):
                cells = []
                for m in found:
                    specimen = (m.get("sheet") or {}).get("specimens", {}).get(identifier)
                    if not specimen:
                        cells.append(None)
                        continue
                    lines, fails = caption(kind_of(identifier), specimen.get("reading"))
                    for what, ratio, target in verdicts(kind_of(identifier), specimen.get("reading")):
                        if ratio < target:
                            failures.append((family, TITLES[m["appearance"]], label_of(identifier), what, ratio, target, specimen["reading"]))
                    cells.append({"image": specimen["image"], "crop": crop(specimen["frame"], m["scale"], png_size(specimen["image"])),
                                  "caption": lines, "fails": fails})
                rows.append({"label": label_of(identifier), "cells": cells})
            out = os.path.join(outdir, f"{family}-{key}.png")
            compose_layout(os.path.join(work, key + ".json"), {
                "title": f"{title} ({family})",
                "subtitle": "Real renders from the simulator at their own pixels; ratios measured from those pixels (WCAG 2). Targets: words 4.5:1, edges 3:1.",
                "columns": columns, "rows": rows}, out)
            readme.append((out, f"{title}, on the {family} simulator: one row for each specimen, one column for each appearance."))
        for key, title in SCREENS:
            shots = [(m, m["screens"][key]) for m in found if key in m.get("screens", {})]
            if not shots:
                continue
            rows = []
            for start in range(0, len(shots), 5):
                cells = []
                for m, screen in shots[start:start + 5]:
                    size = png_size(screen["image"])
                    lines = [TITLES[m["appearance"]]]
                    wrong = screen_failures(screen)
                    for button in screen.get("buttons", []):
                        if button.get("kind") == "key" and button.get("reading"):
                            keys.append((family, TITLES[m["appearance"]], button.get("label"), button["reading"]))
                    for label, what, ratio, target, reading in wrong:
                        failures.append((family, TITLES[m["appearance"]], f"{title}: {label}", what, ratio, target, reading))
                    if "difference" in screen:
                        lines.append(f"{screen['difference']['pixels']} pixels differ from the same window active")
                    measured = [b for b in screen.get("buttons", []) if b.get("kind") != "key" and b.get("reading")]
                    if not measured:
                        lines.append("controls not measured")
                    else:
                        lines.append(f"{len(wrong)} measured pairs under target" if wrong else f"all {len(measured)} measured controls at target")
                    cells.append({"image": screen["image"], "crop": {"x": 0, "y": 0, "width": size[0], "height": size[1]},
                                  "caption": lines, "fails": bool(wrong)})
                rows.append({"label": "", "cells": cells})
            out = os.path.join(outdir, f"{family}-screen-{key}.png")
            compose_layout(os.path.join(work, "screen-" + key + ".json"), {
                "title": f"{title} ({family})", "subtitle": "Whole captures at their own pixels, in each appearance.",
                "columns": ["" for _ in range(5)], "rows": rows}, out)
            readme.append((out, f"{title}, on the {family} simulator, in each appearance."))
    write_readme(outdir, readme, failures, keys)


def write_readme(outdir, pictures, failures, keys=()):
    lines = ["# Brickson design review sheet", "",
             "Generated by `scripts/design-review/review.py compose`; the summary at the top is written by hand.", "",
             "## Pictures", ""]
    for path, description in pictures:
        lines.append(f"- `{os.path.basename(path)}`: {description}")
    lines += ["", "## Pairs under Apple's contrast targets", "",
              "Words need 4.5:1 and a control's edge 3:1 against what it sits on (AGENTS.md, invariant 6).", "",
              "| Device | Appearance | What | Pair | Measured | Colours |", "|---|---|---|---|---|---|"]
    for family, appearance, what, pair, ratio, target, reading in failures:
        colours = f"`{reading['words']}` on `{reading['fill']}`" if pair == "words" else f"`{reading['edge']}` on `{reading['page']}`"
        lines.append(f"| {family} | {appearance} | {what} | {pair} | {shown(ratio, target)}:1 (needs {target}) | {colours} |")
    if not failures:
        lines.append("| | | none | | | |")
    lines += ["", "## Apple's keyboard while typing", "",
              "The keys are Apple's, not Brickson's to change; their lowest measured pair in each appearance:", "",
              "| Device | Appearance | Keys measured | Lowest words | Key |", "|---|---|---|---|---|"]
    by_capture = {}
    for family, appearance, label, reading in keys:
        if label == "space":
            continue  # no glyph on it to read
        by_capture.setdefault((family, appearance), []).append((reading["wordsOnFill"], label, reading))
    for (family, appearance), found in by_capture.items():
        ratio, label, reading = min(found, key=lambda item: item[0])
        lines.append(f"| {family} | {appearance} | {len(found)} | {ratio:.2f}:1, `{reading['words']}` on `{reading['fill']}` | {label} |")
    with open(os.path.join(outdir, "README.generated.md"), "w") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"{len(pictures)} pictures, {len(failures)} pairs under target")


def main(argv):
    if len(argv) >= 5 and argv[1] in ("capture", "screens") and UDID.fullmatch(argv[2]) and argv[3] in FAMILIES:
        names = argv[5:] or list(APPEARANCES)
        if all(name in APPEARANCES for name in names):
            return capture(argv[2], argv[3], os.path.abspath(argv[4]), names, screens_only=argv[1] == "screens")
    if len(argv) == 7 and argv[1] == "inactive" and UDID.fullmatch(argv[2]) and argv[4] in INACTIVE and argv[5].isdigit() and argv[6].isdigit():
        return inactive(argv[2], os.path.abspath(argv[3]), argv[4], float(argv[5]), float(argv[6]))
    if len(argv) == 3 and argv[1] == "compose":
        return compose(os.path.abspath(argv[2]))
    sys.exit(__doc__.split("\n\n")[1])


if __name__ == "__main__":
    main(sys.argv)
