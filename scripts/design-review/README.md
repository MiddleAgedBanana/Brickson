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
on the `PATH`, an iPhone and an iPad simulator made for this, and a debug
build of Brickson installed on whichever one is running. Use simulators
made for this, not ones you use for other work: the script changes their
appearance and accessibility settings and puts them back to plain ones at
the end. *The first time*, below, sets all of this up.

## The first time

Type each command into Terminal, in the repository's top folder: the one
`git clone` made, which holds `project.yml` and `scripts/`
([docs/GETTING_STARTED.md](../../docs/GETTING_STARTED.md), step 3). Each
step says what success looks like.

1. **Install AXe**, the tool the script uses to read the screen and
   touch it. This is the command
   [AXe's own page](https://github.com/cameroncooke/AXe) gives; it needs
   Homebrew, as XcodeGen does
   ([docs/GETTING_STARTED.md](../../docs/GETTING_STARTED.md), step 2):

   ```sh
   brew install cameroncooke/axe/axe
   axe --version
   ```

   Success: the last line is AXe's version number, which starts with `v`.
   If AXe was already installed, Homebrew says so, and that is fine too.

2. **Make the two simulators.** List the kinds of iPhone and iPad your
   Xcode can make, newest first:

   ```sh
   xcrun simctl list devicetypes iPhone
   xcrun simctl list devicetypes iPad
   ```

   Each line is one kind: its name, then an identifier in brackets that
   starts with `com.apple`. Choose the kinds the tests use
   (`scripts/choose-simulator.py`): for the iPhone, the first name that is
   "iPhone" and a number with nothing after it (not a Pro, Max, Plus, Air,
   mini, e or Duo); for the iPad, the first name that starts with "iPad Pro
   13-inch". Make each one, writing the name you chose as the list shows
   it, without the `com.apple` identifier, inside the second pair of
   quotation marks:

   ```sh
   xcrun simctl create "Brickson review iPhone" "<the iPhone you chose>"
   xcrun simctl create "Brickson review iPad" "<the iPad you chose>"
   ```

   Success: each ends with the new simulator's UDID, the identifier the
   commands below need: 36 letters, digits and dashes, such as
   `1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D`. Wherever this page says
   `<iPhone udid>` or `<iPad udid>`, put that simulator's UDID. To see
   them again:

   ```sh
   xcrun simctl list devices | grep "Brickson review"
   ```

   Each line is a simulator's name, its UDID in brackets, and whether it
   is booted or shut down. `capture` needs no simulator window open; if
   you open one, leave it open until the captures finish, since closing
   the app that shows it can shut the simulators down.

3. **Build Brickson** on the review iPhone:

   ```sh
   xcrun simctl bootstatus <iPhone udid> -b
   DESTINATION='platform=iOS Simulator,id=<iPhone udid>' scripts/test.sh
   ```

   Success: the first starts the simulator and ends with `Finished` (or
   says the device is already booted); the second builds a debug build,
   runs the repository's checks and the unit tests on it, and ends with
   **All unit tests passed.** It can take a quarter of an hour. It needs
   XcodeGen
   ([docs/GETTING_STARTED.md](../../docs/GETTING_STARTED.md), step 2).
   The app it built is at
   `build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app`
   in the repository, where *How* installs it from. Naming the review
   iPhone (`DESTINATION`) keeps the build off the simulators the tests
   pick for themselves, which an agent on the same Mac may be using.
   Build again whenever the code changes, for example after `git pull`,
   so the sheet shows the app as it is now.

4. **Choose the output folder**, where the pictures go: a new folder
   inside your home folder and outside the repository, for example
   `~/brickson-design-review`. The script makes it. Anywhere else,
   including the repository's own `build/` folder or the home folder
   itself, it stops at once, saying "the output folder must be inside"
   your home folder or "the output folder must be outside the
   repository", and captures nothing. Wherever this page says
   `<output folder>`, write that folder.

## How

From the repository's top folder, build the measuring tool, then
capture each device with only its simulator running, and lay them side
by side:

```sh
cd scripts/design-review
mkdir -p ../../build/review
xcrun swiftc -O -parse-as-library ReviewPixels.swift ReviewSheetTool.swift -o ../../build/review/review-sheet
xcrun simctl bootstatus <iPhone udid> -b
xcrun simctl install <iPhone udid> ../../build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app
python3 review.py capture <iPhone udid> iphone <output folder>
xcrun simctl shutdown <iPhone udid>
xcrun simctl bootstatus <iPad udid> -b
xcrun simctl install <iPad udid> ../../build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app
python3 review.py capture <iPad udid> ipad <output folder>
xcrun simctl shutdown <iPad udid>
python3 review.py compose <output folder>
```

`swiftc`, `install` and `shutdown` print nothing when they work. Each
`capture` prints one line for each appearance it saved, naming the
device, the appearance and how many specimens it measured, and `compose`
ends by saying how many pictures it wrote and how many pairs are under
target. The commands leave Terminal in `scripts/design-review`, where the
commands further down this page run too; `cd ../..` takes it back to the
top folder.

Each `capture` takes about two minutes for each appearance: light, dark,
both with Increase Contrast, Reduce Transparency, Show Borders,
Differentiate Without Colour, Bold Text and the largest text size. Name
appearances after the family to take only those. It refuses to save a
capture whose readout does not show the appearance it set, a sheet that
never showed one of its specimens (`EXPECTED` in `review.py`), or a typing
capture without Apple's keyboard. Each appearance is written to a folder
of its own and replaces the last run's only when it succeeds; `compose`
measures every capture again with the tool as it is, so a better
measurement needs no new captures.

`compose` writes one picture for each part of the sheet and each screen,
for each device (`iphone-colours.png`, `ipad-screen-home.png` and so on),
and `README.generated.md`, which lists them and every pair under
Brickson's targets (AGENTS.md, invariant 6): words 4.5:1 (WCAG 1.4.3), a
control's edge 3:1 (WCAG 1.4.11).

## An inactive iPad window

An iPad window is inactive when another app's window has the focus, which
takes Windowed Apps (Settings, Multitasking & Gestures). After the iPad's
`capture`, start the iPad again
(`xcrun simctl bootstatus <iPad udid> -b`), turn Windowed Apps on, open
Brickson's window full size, and put the Settings app's window over its
lower part, then:

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
