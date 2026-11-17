# Home is reached in the right order before SwiftUI sorts it

*2026-11-17. Pull request #PR (`claude/home-order-before-sorting`). A
Claude Code thread on the owner's Mac.*

## What changed and why

Nothing a person sees changes. What VoiceOver, Switch Control and Full
Keyboard Access are offered first on Home is now Yes, No, Emergency and
Get Attention from the first moment Home can be read, not only once
SwiftUI has sorted Home's controls.

`HomeAccessibilityOrderTests` had been failing now and then on CI, always
in its first state, "just opened", on the iPhone and, since 2026-11-17,
the iPad, at the default and the largest text sizes: Home read in screen
order, Phrases and Type before Yes, No and Emergency, and right a moment
later. Pull request #119 made the test read again after a wrong read, and
#125's run 44135506925 (iPhone, part 1) answered the open question: right
0.18 s later, with nothing touched.

**The cause.** The app's own log is in every CI result bundle, and on CI
it prints each tree XCTest reads ("Current tree"). Read side by side:

- The wrong order is not the screen order. It is the order Home's views
  are *declared* in: the regions as `HomeView` stacked them (message,
  safety row, categories, phrases), the compact safety row as its rows
  listed it (Yes, No, Emergency, then Again, Get Attention), and on the
  iPad's one row Emergency, Yes, No, Again, Get Attention. Inside the
  message region even non-controls kept their declared order. The
  accessibility elements were the same objects before and after (same
  ids); only their order changed when SwiftUI applied
  `accessibilitySortPriority`, and with it its ordering by position.
- It is routine on CI and usually unseen. In that run the first tree
  XCTest read was in declared order in 9 of 39 iPhone launches and 2 of
  39 iPad ones (`ui-test-results-*-part1`); every other test simply does
  not check the order. It lasted from the first read for 0.35 s to at
  least 3.9 s, on a Home already drawn and still: in the failing launch,
  first frame at 18:21:56.57, the app idle at 56.94, the first read at
  59.19 still in declared order through 00.82, sorted by 01.01.
- No timing difference set those launches apart: XCTest's first read
  came about 2.05 s after the app first reported idle in all 78. What
  makes SwiftUI late is not known; Apple's documentation of
  `accessibilitySortPriority` says nothing about when it applies.

So the app itself handed this order to an accessibility client, the way
VoiceOver and Switch Control read it, for seconds at a time: not a test
reading in the middle of a layout pass. A person whose first scan started
in that window would have been offered Phrases and Type first.

**The fix.** Make the declared order the reached order, so it is the
same before and after the sort:

- `HomeView` declares its regions in `HomeRegion.allCases` order (safety
  row, message, categories, phrases), each in a stack of its own under
  spacers the height of what stands above it on screen, the same heights
  in the same order as the one column they were in before, so every
  frame is computed the same way.
- The safety row declares its controls in `HomeRegion.safetyRowOrder`
  (Yes, No, Emergency, Get Attention, Again or Speak) and a small layout,
  `SafetyRowLayout`, places each at its slot's frame from the engine, as
  `LibraryQuestionLayout` already places a question screen's views in
  reading order. The rows' stacks are gone from the safety row; the
  categories keep theirs, which were already declared in reading order.
- The sort priorities stay, now given by
  `HomeRegion.sortPriority(inSafetyRow:)`, so the order holds whichever
  SwiftUI uses.

This follows docs/DECISIONS.md, "Home's scan order and names", which now
records it (*2026-11-17*).

## Commits

- `<hash>`: the fix, its unit tests and these documents.

## Verified

The owner's Mac, Xcode 27.2 (27B52), simulators made for this work
(iPhone 17 and iPad Pro 13-inch (M5), iOS 27.2), portrait, light.

- **Test first.** `HomeRegionTests` gains three tests.
  `theSafetyRowIsDeclaredInTheOrderItIsReached` sorts the safety row by
  its priorities and then by place, top to bottom and leading to
  trailing, in every layout `HomeLayoutEngineTests.everyLayout` makes, and
  requires `safetyRowOrder`; with the row declared as before (Again before
  Get Attention) it failed, with this change it passes.
  `homeDeclaresItsRegionsInTheOrderTheyAreReached` fails if
  `HomeRegion`'s cases are put back in screen order.
  `theQuickControlsComeBeforeAgainInTheSafetyRow` pins the first four.
- **Nothing moved.** A probe (never committed) read every element's type,
  label, identifier and frame, and took a screenshot, on Home just opened,
  typing and with the alarm sounding, at the default and the largest text
  size, before and after the change. iPhone: every element of the app
  identical; the only differences were the system keyboard's own (its
  slide-to-type introduction showed on one run). Screenshots identical but
  for the clock; while typing, identical above the keyboard. iPad: every
  control, region and text identical; screenshots identical but for the
  clock and, while typing at the largest text, the field's blinking
  cursor. One accessibility element differed: the phrase grid's scroll
  bar, which the starter library never shows ("1 page"), ended 2 points
  lower at the default text size, just opened and with the alarm
  sounding (not while typing, not at the largest text). The grid's own
  frame did not change.
- RESULTS-PLACEHOLDER

## Not verified

- A real device: whether VoiceOver or Switch Control on a person's iPad
  or iPhone ever met the old declared order, and how long SwiftUI takes
  there (docs/HANDOFF.md, *Checks that need a real device*, already holds
  the scan order's device check).
- The failure was never reproduced on the Mac, here or before (61
  launches on 2026-11-16, 22 more here, some with CI's two-second wait
  before the first read): its baseline is CI's own logs. The local runs
  below show the fix does not break the order; CI's runs on this pull
  request are where the declared-order reads show up, and the method
  below finds them.
- Why the scroll bar's accessibility frame on the iPad moved 2 points.
- Landscape, Bold Text, dark mode, rest boards, the late stage's sizes and
  iPhone Duo's windows were not compared frame by frame; the engine's
  frames and the layout tests on CI cover them.

## Finding a declared-order read in a CI result bundle

```sh
xcrun xcresulttool export diagnostics --path ui-iphone-part1.xcresult --output-path diag
```

`StandardOutputAndStandardError-family.avery.brickson.txt` holds each
"Current tree:" XCTest printed. The message region tells a tree read
before SwiftUI sorted it, whatever order its controls are in: its hidden
placeholder lines are declared before Phrases and Type, so in declared
order Phrases and Type are its last two children, while sorted they come
right after the message. This prints the first tree of every launch:

```python
# python3 -I first-trees.py <StandardOutputAndStandardError-...txt>
import re, sys
lines = open(sys.argv[1], errors="replace").read().split("\n")
seen = set()
for i, line in enumerate(lines):
    m = re.match(r"^\S+ (\S+)\+0000 Brickson\[(\d+):.*Current tree:", line)
    if not m or m.group(2) in seen:
        continue
    regions, message, depth, buttons = [], [], None, []
    for body in lines[i + 1:i + 400]:
        if re.match(r"^\d{4}-", body):
            break
        indent = len(body) - len(body.lstrip())
        r = re.search(r"identifier: 'homeRegion\.(\w+)'", body)
        if r:
            regions.append(r.group(1))
            depth = indent if r.group(1) == "message" else None
            continue
        if depth is not None and indent == depth + 2:
            message.append(body.split(",")[0].strip())
        b = re.search(r"Button, 0x[0-9a-f]+(?:, identifier: '[^']*')?, label: '([^']*)'", body)
        if b and regions:
            buttons.append(b.group(1))
    if regions:
        seen.add(m.group(2))
        state = "declared order" if message[-1:] == ["Button"] else "sorted"
        print(m.group(1), m.group(2), state, ",".join(regions), ",".join(buttons[:7]))
```

## Follow-ups

- When this pull request's CI has run, count its declared-order first
  reads with the script above and check the controls were in order in
  each. *(this thread)*
- Pull request #122 changes the UI tests' waits; this one changes no UI
  test and neither touches `HomeAccessibilityOrderTests.swift`. Both edit
  `docs/HANDOFF.md` and `docs/DECISIONS.md` in different places.
  *(whichever lands second: merge `main` and recheck those two files)*
