# A run sheet for the hands-on experiments, and a probe app to run them

*2026-11-14. Pull request #112 (`claude/project-thread-q8caa6`). A Claude
Code cloud thread in the project, on the owner's choice that day of the
safe way for the experiments: public sources and public API only, no
reverse engineering, no disassembly, no private API.*

## What changed and why

Three research studies on 14 November 2026 (how Apple's accessibility
features really behave, Apple's design language, and the field of AAC and
eye-gaze apps) ended with questions only a running app can answer: does
Snap to Item stop on a dimmed button, how far does it reach, what does a
still look do when the screen changes under it, what does Apple's own
button look like at Brickson's sizes. Nobody using Brickson notices
anything from this pull request. People working on it get two things.

**One ordered run sheet,** [`docs/EXPERIMENTS.md`](../EXPERIMENTS.md).
It keeps every question ID from the studies (A-1 to A-45 and A-1a, B-1
to B-4, D-01 to D-26, the 23 G questions numbered between G-01 and
G-41, and the studies' own unit IDs such as A4-U13) and the device checks F1 to F4 in
[`docs/DEVICE-CHECKS.md`](../DEVICE-CHECKS.md), and sorts them into five
groups: on the simulator only; on a device with a person; with borrowed
hardware; ask Apple first; and wait for the owner's decision. Within each
group the cheapest, most valuable session comes first: Assistive Access
(D-13), control sizes (D-01), shapes (D-24) and the edit sheets (D-22)
lead the simulator group, and Snap to Item on a dimmed button (A-1)
leads the device group. Each session says what it asks, why, the exact
steps, what to write down, and what each possible result means for the
design. Its last table lists every ID with the session that answers it,
so none is lost.

**A probe app,** `BricksonProbe/`: real SwiftUI, a separate application
target that never ships (docs/DECISIONS.md, *A probe app for the
experiments, kept out of Brickson*). It has thirteen stations, one per
kind of question: Snap (every kind of element Snap to Item might or
might not stop on), Rings (distance from a target), Landing (a moved
activation point, hover effects), Changes (a control that appears,
moves, changes words or disappears after a countdown), Groups, Look (a
grid of tiles with sizes, shapes, hover and motion as options), Speech,
Screen, Status (every public accessibility value the app can read),
Typing (what the keyboard actually delivered), Busy (the main thread
held for three seconds), Ruler (a point grid to film the pointer
against) and Styles (Apple's own button styles, sizes and glass). Every
option sits on the probe's first list, never on a station's screen.
Each station logs what happens with its time on the continuous clock,
and the log is shared as text after a session.

Routine choices made by the thread, each reversible:

- The probe is a target in this repository rather than a separate
  project, so CI compiles it with Brickson's settings and
  `scripts/forbidden-code.py` checks it. It has its own bundle
  identifier, `SKIP_INSTALL` on, and the `Brickson` scheme builds it
  only for testing.
- Its words are English, written with `Text(verbatim:)`, and it has no
  String Catalog: only the person running an experiment reads them.
- Questions that would need code the repository forbids in any target
  (touch types, hover events, UIKit's accessibility path) are not in the
  probe; the run sheet lists them under the owner's decisions (OWN-2).
- The run sheet repeats none of the studies' measurements of Apple's
  design kit or their App Store facts; it cites the studies by question
  ID only.

What the request did not cover, and this pull request does not do: run
any experiment, change Home or any screen Brickson ships, or design
anything.

Files: `project.yml` (the `BricksonProbe` target and scheme; the unit
tests compile the probe's logic); `BricksonProbe/` (new);
`BricksonTests/Probe/ProbeLogicTests.swift` (new);
`BricksonTests/OffMainThreadCallbackTests.swift` (one test for the
probe's speech reports); `scripts/test-forbidden-code.py` (its test of
the real repository expected exactly one app; it now names both apps,
checks each has its Swift files, and checks the frameworks table allows
`ProbeSystem`'s UIKit); docs/DECISIONS.md (the new section, and a row
in *Apple's current frameworks first* for the probe's UIKit calls);
`docs/EXPERIMENTS.md` (new); a pointer each in docs/HANDOFF.md,
docs/ROADMAP.md, docs/DEVICE-CHECKS.md and `README.md` (its repository
structure and documentation lists).

## Commits

- `958287a` The probe, its tests, the run sheet and these records.
- The first review round (Codex and CodeRabbit on `958287a`), in one
  push:
  - each station's readout keeps two lines' height from the start, so a
    longer log line never moves the controls being measured;
  - the Rings button and Landing's two buttons are exact-size, outlined
    plain buttons (Apple's bordered style had added padding around the
    size the run sheet quotes), and Rings logs the size it was laid out
    at; Wide and Landing are now 160 by 100 and 100 points, so the row
    fits a phone, and Wide's activation point lands on Landing's centre;
  - the Changes, Landing and Speech rows narrow to fit a phone's width
    instead of running off it;
  - the log keeps lines in the order things happened, so a speech report
    held up while Busy held the main thread goes in at its own time, and
    a full log drops the earliest line (`aLateReportGoesInAtItsOwnTime`,
    `aFullLogDropsTheEarliestLine`: fail if the log appends in arrival
    order or drops by arrival order);
  - Stop speaking drops the utterances still queued, which leave the
    synthesizer without a report, so the probe stops showing that it is
    speaking and asks VoiceOver or Switch Control to resume (before, a
    Stop during the first of three parts left them paused);
  - the speech-report test has a one-minute time limit, so a missing
    report fails it instead of hanging;
  - the run sheet: an edge-measured reach grows the farthest ring by half
    the button's size change, not all of it; every recording stops before
    a Personal Voice speaks; the 18 G numbers the field study does not
    use are named; and it says to reopen the probe if its speech stops,
    which docs/DECISIONS.md lists with the probe's other exceptions.
- The owner's answer, 2026-11-15: docs/DECISIONS.md, *A probe app for
  the experiments, kept out of Brickson*, records that the owner
  accepted the probe's exceptions (asked about five, yes to all, and the
  rest left to the agents as objective coding choices). Its keep-awake
  line had the idle timer backwards; it now says the probe keeps the
  screen on by default and lets the person switch that off.
- Graphify's review of `958287a`: the Status station now logs a value
  that is no longer read (`aReadingNoLongerReadIsLogged`: fails if one
  can vanish without a line), and the shared text turns a tab or line
  break inside a field into a space, so an error's own words cannot
  break a line's four columns (`aTabOrLineBreakInAnEventStaysInItsColumn`:
  fails if the export writes either as it is).
- The second review round (Codex on `8d936bd`): Apple's plain style lets
  only a label's words take a touch, so a dwell inside an exact-size
  button's outline but beside its words could miss. Those buttons now
  use `ProbeExactButtonStyle`, which adds no padding and makes the whole
  outlined shape take a touch. The verifier's read of `8d936bd` also
  found: this log's G range (the run sheet has 23 G questions numbered
  between G-01 and G-41, not G-01 to G-40); the frameworks row and
  `ProbeSystem` saying SwiftUI cannot read whether Switch Control is on
  (it can, and the probe reads UIKit's value beside SwiftUI's to compare
  them); and DEV-11 placing the keep-awake setting on the Screen station
  (it is on the probe's first list). All three are corrected.
- CodeRabbit's second review (on `8d936bd`): the run sheet says to share
  the log before closing a probe whose speech stopped (the log lives only
  in memory); DEV-2 writes down a ring past the iPhone's edge as off
  screen, not a miss; and an unchanged farthest ring is no longer read as
  a centre rule, because beyond 50 points the rings are 50 or 100 points
  apart and a 38-point change can fall between two of them, so the chain
  engine keeps both rules until a result separates them. Its request to
  stop button words shrinking was declined: without it a long word breaks
  mid-word in a phone's narrow slot, so docs/DECISIONS.md now names the
  shrinking as one of the probe's exceptions.
- CodeRabbit's third review (on `1d56aad`): DEV-2 set the chain engine's
  reach at the farthest ring that snapped, but the real reach lies
  between that ring and the next, so scoring only to it could miss a
  control a held look can reach. DEV-2 now records the nearest ring that
  does not snap too and takes the reach from it, keeping the unlimited
  range where every ring on screen snapped.
- CodeRabbit's fourth review (on `ced3cc8`): a ring inside the button
  (the 25-point ring on the 88-point button, the 25- and 50-point rings
  on the 120) puts the look on the button itself, so reading it as "does
  not snap" could set the reach shorter than a farther ring that snapped.
  DEV-2 now skips those rings and takes the ring that does not snap only
  from beyond the farthest that does.

## Verified

In the cloud thread, on Linux, with no Xcode:

- `python3 scripts/test-docs.py`, `test-hooks.py`, `test-privacy.py`,
  `test-forbidden-code.py`, `test-runner.py`, `test-agent-bridge.py`,
  `test-site.py` and `test-select-xcode.py` pass.
- `python3 scripts/forbidden-code.py` finds nothing, the probe
  included. `test-forbidden-code.py` first failed on this branch,
  because its test of the real repository expected one application
  target; that test now names `Brickson` and `BricksonProbe` exactly,
  which is stricter than a count. Its first run flagged `ProbeSystem.swift`'s UIKit use
  before the frameworks table named it; the row was added rather than
  the check changed.
- `python3 scripts/privacy-check.py --outgoing --no-list` and
  `--status`; this session cannot read the private list, so it is not
  a pass of that check.
- Every Apple API the probe uses was looked up in Apple's documentation
  in this session. The three accessibility values Apple lists as newer
  than iOS 26.0, the oldest iOS Brickson supports, are read behind
  `#available`.

The new tests, and the change that would make each fail:

- `ProbeStationTests`: Snap stops being the first station or stops
  carrying A-1; a station with no questions, a mistyped ID (A1 for A-1,
  D-1 for D-01) or the same ID twice; two stations share a title.
- `ProbeLogTests`: a line timed from the wrong instant; a full log that
  drops its newest lines, or stops saying it dropped any; an export not
  oldest first or not tab-separated, or a tab or line break inside an
  event written as it is; Clear leaving lines; seconds printed without
  two decimals.
- `ProbeCountdownTests`: seconds left rounded down, or going below zero.
- `ProbeStatusTests`: an unchanged value logged again, or a value no
  longer read not logged; a group logged under the wrong station; a
  thermal state with no words.
- `ProbeSpeechScriptsTests`: the spoken Voice Control command no longer
  naming the Counter button; the parts no longer making the sentence;
  SSML without its pauses, or with unescaped text.
- `ProbeVisibleTextTests`: a space, no-break space, tab or line break
  shown as itself.
- `ProbeUtteranceTallyTests`: word reports or the longest gap
  miscounted; a report for an utterance with no words.
- `ProbeGeometryTests`: the ring radii, the varied-size checkerboard, or
  the smallest ring target changed from Apple's 44-point minimum.
- `OffMainThreadCallbackTests.probeSpeechReportsCanArriveOnABackgroundThreadInOrder()`:
  the probe's speech delegate made main-actor isolated (it would trap
  under Swift 6 when the synthesizer calls it on its own thread), or
  its stream reordering or dropping a report.

## Not verified

- **Compiled only by CI.** A cloud session cannot build Swift. GitHub
  CI on `958287a` passed (unit tests, which build the probe for testing,
  and the UI tests on an iPhone and an iPad simulator). Each later
  commit counts as untested until CI passes on the pull request's last
  push.
- Whether the exact-size buttons take a touch across their whole
  outline: that needs a dwell or a tap on a device, read in the log.
- The probe has not run on a simulator or a device. Whether each station
  shows what the run sheet says it shows is the Mac session's first job
  ([`EXPERIMENTS.md`](../EXPERIMENTS.md), *What the Mac session does
  next*).
- That the `BricksonProbe` scheme runs on a simulator and on the owner's
  devices with their Team ID.
- That `AssistiveAccess`'s scene and the `.assistiveAccess` preview trait
  behave as Apple's pages describe (D-13 measures exactly that).
- No experiment was run; every result in the run sheet is a prediction
  of what each outcome would mean, not a finding.

## Follow-ups

- The Mac session: build the probe in its own worktree, check each
  station on an iPad and an iPhone simulator, then run Group 1 in order
  ([`EXPERIMENTS.md`](../EXPERIMENTS.md), *What the Mac session does
  next*). The project's coordinator starts it.
- The owner: the device sessions (Group 2, A-1 first) need the Team ID
  already on the owner's list, and a person at the device. Groups 4 and
  5 wait on the owner too.
- When the experiments are done, the owner chooses whether the probe is removed
  or kept (docs/DECISIONS.md, *A probe app for the experiments, kept out
  of Brickson*, "Revisit when").
- No document was found wrong while writing this. Corrections to
  Brickson's documents that the research proposed wait for a documents
  pull request.
