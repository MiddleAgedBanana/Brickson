# The design review sheet

A picture of every visual building block Brickson has, drawn by the app
itself in each appearance a person can choose, with the contrast of each
pair measured from the pixels. The new design is judged from it, and its
colours are picked from it by eye (docs/DECISIONS.md, "A design review
sheet in debug builds").

What is drawn is the app's own: `DesignReviewScreen`, a screen that only
debug builds have, opened with the launch argument
`--screen=design-review`. It shows each colour token with the words
drawn on it, primary ink on the screen, the spacing scale, the three kinds
of corner, Home's controls in each state and Settings' rows. At its top
it prints the settings the app received, so every capture says which
appearance it is.

## What it takes

A Mac with Apple's current Xcode, [AXe](https://github.com/cameroncooke/AXe)
on the `PATH`, and one booted simulator with a debug build of Brickson
installed (`scripts/test.sh` builds one; `xcrun simctl install <udid>
<path to Brickson.app>` installs it). Use a simulator made for this, not
one you use for other work: the script changes its appearance and
accessibility settings and puts them back to plain ones at the end.

## How

```sh
cd scripts/design-review
xcrun swiftc -O -parse-as-library ReviewPixels.swift ReviewSheetTool.swift -o ../../build/review/review-sheet
python3 review.py capture <iPhone udid> iphone <output folder>
python3 review.py capture <iPad udid> ipad <output folder>
python3 review.py compose <output folder>
```

Each `capture` takes about two minutes for each appearance: light, dark,
both with Increase Contrast, Reduce Transparency, Show Borders,
Differentiate Without Colour, Bold Text and the largest text size. Name
appearances after the family to take only those. It refuses to save a
capture whose readout does not show the appearance it set.

`compose` writes one picture for each part of the sheet and each screen,
for each device (`iphone-colours.png`, `ipad-screen-home.png` and so on),
and `README.generated.md`, which lists them and every pair under Apple's
contrast targets: words 4.5:1, a control's edge 3:1 (AGENTS.md, invariant
6).

## An inactive iPad window

An iPad window is inactive when another app's window has the focus, which
takes Windowed Apps (Settings, Multitasking & Gestures). After the iPad's
`capture`, turn Windowed Apps on, open Brickson's window full size, and
put the Settings app's window over its lower part, then:

```sh
python3 review.py inactive <iPad udid> <output folder> inactive-light <top of the Settings window> <its bottom>
python3 review.py inactive <iPad udid> <output folder> inactive-dark <top of the Settings window> <its bottom>
```

The top and bottom are in points. In Windowed Apps AXe reads only the
focused app, and its coordinates are that app's window's, so arrange the
windows by dragging their top edge and corner from the window that has
the focus. The script reads the sheet's top line a point at a time (`axe
describe-ui --point`), refuses a capture whose line does not say
`window=inactive` in the appearance it set, finds where the sheet sits
from a specimen's straight edges, and measures the specimens above the
Settings window, clear of the shadow a focused window casts on what is
behind it (140 points above it). It also takes the sheet, Home and
Settings with Brickson's window active and inactive, and counts the
pixels that differ in those rows. Erase the simulator, or turn Full
Screen Apps back on, before capturing anything else.

## How a pair is measured

`ReviewMeasure.read` (`ReviewPixels.swift`, tested in
`BricksonTests/ReviewPixelsTests.swift`) reads one specimen's frame in
the capture, converted to sRGB: the fill is the commonest colour more than
6 points inside its edge (past any ring), the words the colour there that
stands out most from it, the edge the commonest colour of the outermost
1.5 points that is not the screen, and the screen the commonest colour 3
to 8 points outside. Ratios are WCAG 2's, as `PaletteTests` computes them.
`test_review.py` checks the script's own logic: `python3 -I test_review.py`.
