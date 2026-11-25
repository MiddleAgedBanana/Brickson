# The design review sheet's instructions work the first time

*2026-11-25. Pull request #135 (`claude/design-review-readme`). A Claude
Code thread in the project, on the owner's Mac.*

## What changed and why

Nothing a person using Brickson sees changed: only the instructions for
the design review sheet (docs/DECISIONS.md, "A design review sheet in
debug builds") and one comment in its script.

The owner will run the sheet themself once the new look is designed, so
`scripts/design-review/README.md` has to work from a fresh Mac with
nothing but that page. Four steps it needed were not written down, and
two of its sentences were wrong:

- **A new section, *The first time*,** written for someone new to
  Terminal, with what success looks like at each step: installing AXe
  (`brew install cameroncooke/axe/axe`, the command AXe's own page gives);
  making an iPhone and an iPad simulator for the review alone with
  `xcrun simctl create`, choosing the kinds the tests use, and finding
  each one's UDID again; building the app on the review iPhone with
  `scripts/test.sh` and where the build lands
  (`build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app`);
  and choosing an output folder inside the home folder and outside the
  repository, the only place `review.py` accepts (`output_folder`).
- ***How* now starts, installs on and shuts down each simulator around
  its capture.** The page asked for one booted simulator and then
  captured two devices without saying how to switch, so the iPad capture
  could not run as written. Installing in *How* also means every run
  shows the current build. *An inactive iPad window* says to start the
  iPad again, since *How* now shuts it down.
- **The contrast targets are Brickson's, not Apple's.** The page called
  "words 4.5:1, a control's edge 3:1" Apple's contrast targets. They are
  invariant 6's, and they come from WCAG 2: 4.5:1 for text is Success
  Criterion 1.4.3 and 3:1 for a control's edge is 1.4.11 (read at
  w3.org/TR/WCAG22 on 2026-11-25).
- **`review.py`'s comment named the wrong file.** Its opening comment
  (the module's docstring) said `compose` writes `README.md` beside the
  pictures; the code writes
  `README.generated.md`, as the page says. Only the comment changed.

Choices made here, each small and reversible:

- The page describes which kinds of simulator to make (the newest plain
  iPhone and the newest 13-inch iPad Pro, the kinds
  `scripts/choose-simulator.py` prefers) rather than naming a model, since
  `AGENTS.md` keeps simulator versions out of files.
- The build names the review iPhone (`DESTINATION`), so the owner's build
  never takes a simulator an agent on the same Mac may be testing on.
  `scripts/test.sh` leaves a simulator that was already running running.
- The page never writes out a home folder's path; the script's own message
  names it.

## Commits

- One commit: the page, the comment, this record and docs/HANDOFF.md's
  state paragraph.

## Verified

The steps of *The first time*, but for installing AXe, and the iPhone
half of *How* were run as the page now says them, on the owner's Mac with Xcode 27.2 (27B52),
in a fresh clone of `main` at `27d894c`, by copying each command and
filling in its placeholders:

- **AXe** was already installed (2.1.1, from AXe's own Homebrew tap);
  AXe's page gives `brew install cameroncooke/axe/axe`.
- **Simulators.** `xcrun simctl list devicetypes iPhone` and `iPad`
  listed the kinds newest first. The page's rule chose an iPhone 17; the
  iPad made was an iPad Pro 13-inch (M5), the twin of the "(16GB)" kind
  the rule takes first, which `scripts/choose-simulator.py` ranks the
  same. `xcrun simctl create` made each and printed
  its UDID last, after a note naming the iOS 27.2 runtime it chose (the
  plain one, not iPhone Duo's). The iPad's name, which holds brackets,
  worked inside quotation marks. `xcrun simctl list devices | grep
  "Brickson review"` found both. Both simulators were deleted afterwards.
- **Build.** `xcrun simctl bootstatus <udid> -b` ended with `Finished`,
  and on a second run said `Device already booted, nothing to do.`
  `DESTINATION='platform=iOS Simulator,id=<udid>' scripts/test.sh`
  ended with `All unit tests passed.` (exit 0) after about 16 minutes,
  six of them the repository's checks, and left the simulator running.
  The app was at
  `build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app`.
- **Output folder.** A folder outside the home folder, the repository's
  own `build/review` and the home folder itself were each refused at
  once with the messages the page quotes. A new folder in the home
  folder was made by `capture` and removed afterwards.
- **How, on the iPhone.** `swiftc` and `install` printed nothing;
  `python3 review.py capture <udid> iphone <folder> light` (Homebrew's
  Python 3.15) printed `iphone light: 43 specimens, screens ['alarm',
  'home', 'settings', 'typing']` after 80 seconds; `compose` printed
  `8 pictures, 0 pairs under target` and wrote `README.generated.md`
  beside eight pictures; `shutdown` printed nothing. Only the light
  appearance was taken: the others run the same code.
- **The comment.** `python3 -I scripts/design-review/test_review.py`
  passes (13 tests), and `review.py` with no arguments still prints its
  usage paragraph, the one before the edited one.
- The WCAG numbers were read from the standard (w3.org/TR/WCAG22,
  Success Criteria 1.4.3 and 1.4.11) on 2026-11-25.

## Not verified

- The iPad half of *How* was not run: only its `simctl create` was tried
  (with a name holding brackets, to check the quoting), then deleted.
- A capture of every appearance, and the long build and capture as one
  sitting on a Mac where nothing was installed yet: AXe and XcodeGen were
  already there.
- *An inactive iPad window* was not run; only its first sentence changed.
- Whether closing the simulator's window shuts the simulators down was
  not tried here; the page says only that it can.

## Follow-ups

- `review.py`'s generated page still heads its table "Pairs under Apple's
  contrast targets" (`write_readme`). It is code, so a later change
  should give it the same attribution as the README (Brickson's targets,
  WCAG 1.4.3 and 1.4.11). For any thread.
- *An inactive iPad window* assumes the simulator's window is open and
  says nothing on how to open it. For any thread, on a Mac.
