# Handoff

The current state of Brickson and what to do next. **Start every session
here**, after `git status` and `git log --oneline -15`. Each pull request
edits this page in place and writes its record in [`docs/log/`](log/README.md);
nothing is appended here. Plan: [`docs/ROADMAP.md`](ROADMAP.md). How the
project runs: [`docs/SDLC.md`](SDLC.md).

**State as of 2026-10-23: PR #14 (the library core), PR #33 (Settings
on Home), PR #35 (Show Borders on Home) and PR #17 (agent guardrails)
are merged; PR #17 landed as `7bff8f0`.**
Ten threads are working in parallel on the first release, R0.

## What the app does today

What it is written to do (*Verification* says how much has been seen). A
Home with the message and, beside it, Phrases above Type; a safety row
in one row on regular widths (Emergency, Yes, No, Again and Get
Attention) and two on compact ones (Yes, No and Emergency; Again and Get
Attention, Get Attention directly under Emergency); everyday categories
with Stop's well at their leading top and Settings at their trailing
end, and tiles from a neutral starter set, every frame from the layout
engine, from the space the window gives it (docs/DECISIONS.md, "The
layout engine", *Home on the engine*, and "Get Attention and Stop on
Home"). Its sizes follow Family Setup's answer to how the screen is
reached, switched on when the owner chose the largest sizes that fit
(2026-10-30; docs/DECISIONS.md, "Sizes that follow how the screen is
reached", *Switched on by the owner*): touch's for touch, Voice
Control and someone helping, larger ones for Switch Control, Head
Tracking and Eye Tracking, the largest any answer needs, and Eye
Tracking's until anyone answers, wherever the window holds them
without scrolling, else smaller ones, touch's last; nothing changes
place, and new sizes show as Settings closes. By the engine, every
phone tested keeps touch's sizes at every text size, and every iPad in
portrait takes Eye Tracking's (head tracking's on the iPad mini with
Bold Text). `HomeSizesTests` checks a person's first launch at those
sizes, with Apple's audit and the drawn words (passed on CI's iPad and
iPhone simulators, #70); the other UI tests ask for touch's. A family
can choose a rest board in Set Up Step by Step's second step, "Which
phrases does Home show?": Home then shows only that category's phrases
and Emergency's, dims the other categories in their places, asks for
the late stage's sizes (proposed), and grows Yes, No, Emergency, Again
and Get Attention toward 4 degrees of the person's view while the
tiles stay as tall, as the window has room. By the engine, with the
starter library's boards of six and eight phrases, every iPad in
portrait but the iPad mini, and the 13-inch iPad in landscape, take
the late stage's sizes, and phones touch's (head tracking's on the Pro
Max with a board of six) (docs/DECISIONS.md, "The late-stage profile";
`HomeRestBoardTests` checks a board of six in the app, and Apple's
audit and the drawn words on a board of eight, on CI's iPad and iPhone
simulators, #74 and #75).
Four category buttons that never scroll sideways, and three
phrase columns on every iPhone at its standard Display Zoom (two on 375
and 390-point phones with Bold Text). A tile
speaks at once, in the person's Personal Voice when one exists and is
allowed (in the system's voice while the voice list is being read,
which nothing waits for: docs/DECISIONS.md, "The voice list never holds
up launch"); the sentence stays on screen in the message's reserved lines,
and a longer message scrolls inside them. The phrase grid keeps native
pan cancellation even when its tiles fit, so a deliberate vertical drag
can bounce only its content rather than speak. Static Home controls stay
fixed, and fitting tiles must return to their frames when the drag
settles; a press that wobbles a few points still speaks, and a sideways
slide says the phrase it began on, as a slide on Yes says Yes
(docs/DECISIONS.md, "Phrase-grid drag cancellation", with why a drag
once spoke). Type opens Apple's keyboard
with the message being typed in the message's place: Speak, in Again's
place, or Return says the whole message and keeps it; Phrases goes back
to the phrases and keeps it too; Clear and Put Back take two category
cells while the other categories and the phrase tiles are dimmed in
place; Emergency leaves typing for the emergency phrases; nothing moves
when the keyboard shows. The message is kept on the device across
launches until it is cleared (docs/DECISIONS.md, "Typing on Home"). No label breaks a
word: each drops its icon first, then shrinks only as far as it must,
never below the default size, in lines of whole words. A phrase the system cuts off (a call, Siri, lost
headphones) shows "Stopped" with Again to repeat it. Emergency opens the
emergency phrases and says nothing. VoiceOver, Switch Control and Full
Keyboard Access reach Yes, No, Emergency and Get Attention first, then
Again, the message, Phrases and Type, Stop while it shows, the categories
and Settings, and the phrases, each region as a group, and Voice Control also takes
"Repeat" for Again and "Help" for Get Attention (docs/DECISIONS.md,
"Home's scan order and names" and "Settings on Home"). Get Attention
starts the alarm at once and only starts it; while it sounds, Stop shows
in its own well, never nearest Get Attention, and the status line says
"Sounding" (docs/DECISIONS.md, "Get Attention and Stop on Home").
Settings, for the family (a
full-screen cover with Back to Talking, Family Setup, Voice Settings,
guides to Apple's own features, the privacy policy and step-by-step
setup), opens from Home's Settings button. The guides cover reaching
the screen (touch, Voice Control, Switch Control with its switches and
timing, Eye Tracking, eye trackers for iPad, Head Tracking), keeping
Brickson open (Guided Access, Assistive Access, screen lock), calls,
Siri and shortcuts (Live Speech, also on Apple Watch, Vocal Shortcuts,
Listen for Atypical Speech, the Action button), and the Accessibility
Shortcut, Zoom and Share Accessibility Settings, each checked against
Apple's user guides on 2026-10-23. Brickson asks for full screen in
Assistive Access, and inside it the guides give written Settings paths
instead of links (docs/DECISIONS.md, "Accessibility API coverage").
Until Family Setup has been opened once, Home's message area says where
setup is. Settings' Back to Talking sits over Home's Phrases, so a look
still resting on it when Settings closes meets Phrases, which does
nothing while the phrases show. Settings' Family Setup row is placed
from Home's frames, and Family Setup opens with Set Up Step by Step in
its frame, so a look held on the row meets a row that only opens the
next screen. Its first step opens with Learn About Each Way in that
frame, whose guide opens as a cover of its own with Done where Back to
Talking is, and starts its answers below every place a look can be
resting on the way in; Next only moves on, and the check-in card's Go
Through Setup Again answers the check-in and opens the first step with
Learn About Each Way in its own frame (docs/DECISIONS.md, "The first
step's own rows"). The card's three buttons are full-width rows, so no
word breaks at the largest text size (2026-11-12, untested until CI
runs it; `--check-in-due` makes the card show in tests). It says
what the answers do to Home's sizes, and where iOS reports Switch
Control or VoiceOver on, which answer may fit, choosing nothing. The
exception is on narrow windows at the largest text sizes: by centre, a
look at the row's top trailing corner meets Back to Talking and closes
Settings onto Home's Emergency (nothing is said; modelled;
docs/DECISIONS.md, "Settings' first row, placed from Home's frames").
Family Setup's Phrases and Categories opens the Library (2026-11-05):
a family adds, changes, moves and deletes phrases and categories,
changes a category's picture, exports a backup through the share sheet
and restores one from the file picker, adding to the library or
replacing it where that removes nothing the person wrote. No edit or
backup takes a library from three or four everyday categories to more
or fewer; a damaged or hand-made store already outside them can still be
edited, but never taken farther out (2026-11-12). An everyday category with
fewer than four phrases, as a new one starts, is dimmed on Home until
it has four, and its screen says how many more; Emergency is never
dimmed. No edit or backup takes a category, Emergency included, from
four or more phrases to fewer than four, or an Emergency or rest board
already short of four farther under (docs/DECISIONS.md, "Four
phrases in every category"). A phrase cannot take the name of Yes, No,
Emergency or Get Attention, "Help" included: the editor asks for another
word. A phrase saved with words another control on Home answers to, such
as "Stop", or a category name a phrase also has, is kept as written,
with a note that Voice Control may ask which one is meant, and a restore
that brings such a name says so too; a category name a Home control has
is still refused (docs/DECISIONS.md, "Phrases named like Home's
controls"). Each delete, move, picture and
restore asks on a screen of its own, with the way back where the row
that asked was and the choices well clear of it, and the chain engine
scores the Library's screens, on the controls each window shows, all
but three editors that open with Save dimmed (docs/DECISIONS.md, "The
Library in Settings" and "The Library's question screens").
"Speaking", "Sounding", audio failures, very low volume and a typed
message that cannot be saved or restored share one passive status line
under the message, in space always kept for it, and
VoiceOver announces the warnings, every failed or cut-off alarm
included. If the
library cannot be saved, the app speaks from a filled in-memory library
and says changes will not be kept. If saved phrases exist but cannot be
opened or read, the file is left untouched and a second warning says so
and warns against deleting the app. A saved library damaged so that
Emergency has nothing to open gets the starter emergency phrases back at
launch, added after what is already there, and an emergency category
whose identity an earlier category shares gets a new one, with nothing of
the person's changed or moved (docs/DECISIONS.md, "The emergency category
is always there") ([`log/2026-10-23-emergency-repair.md`](log/2026-10-23-emergency-repair.md)).
Editing and backup are the tested library core
([`log/2026-10-21-library-core.md`](log/2026-10-21-library-core.md)),
reached from the Library's screens above
([`log/2026-11-05-library-screen.md`](log/2026-11-05-library-screen.md)).
The screen never locks. Ported code:
[`docs/PORTING.md`](PORTING.md).

The design reference and its specification are in [DESIGN.md](DESIGN.md)
and [work/design-screens.md](work/design-screens.md). PR #20's
[reconciliation record](log/2026-10-22-design-reconciliation.md) preserves
the landed slot decisions and lists drawings, placement questions and
measurements still pending before implementation follows them. The local
unit gate passed all 460 tests on iPad Pro 13-inch (M5), iOS 27.0, with
Xcode 27.1 (27A9275); PR #20 landed in `d79d836`.

## Verification

- **Pure-Swift unit test coverage, 2026-10-27**, Xcode 27.1 (27A9275),
  iPad Pro 13-inch (M5) simulator, iOS 27.0: 18 new Swift Testing unit tests
  and one extended suite across `HomeLayoutEngineTests`, `HomeReservedRegionTests`,
  `HomeLayoutEngineFontTests`, `ChainEngineTests`,
  `SettingsIdleClockTests`, `LibraryRulesTests` and
  `CategorySelectionTests` pin pure-Swift helpers and edge cases in the
  layout engine (`HomeLayout`, `HomeReservedLayout`, `HomeWellEnvelope`,
  `LabelFont`), the chain-scoring engine (`ChainEngine`, `HomeChains`),
  `SettingsActivity`, `GuidedSetupStep`, `LibraryEditRejection` and
  `CategorySelection.inCell` without modifying production code. The full local
  unit gate passed 799 native unit cases (790 passed, zero failed, one
  existing #19 skip and eight strict expected failures), 45 docs/site/runner
  tests and 124 hook tests, with an unchanged String Catalog and 72.1%
  app line coverage (7,136 of 9,903 lines)
  ([`log/2026-10-27-pure-swift-unit-tests.md`](log/2026-10-27-pure-swift-unit-tests.md)).

- **App Store listing drafts (`docs/ASO.md` and `docs/APP-STORE.md`), 2026-10-27:**
  updated the store-text drafts (`Name`, `Subtitle`, `Keywords`, `Promotional text`,
  `Description` and `What's New`), the screenshot table and the App Review notes
  template to use `[App Name]` as a placeholder until the final name is
  confirmed in App Store Connect, with no price or cost words. Removed the five
  `[needs: …]` tags from the description draft for features now built on `main`
  (`Get Attention`, `layout engine`, `word fitting`, `typing` and `voice choice
  in Settings`), added a clean 1.0 paste-ready description block with the four
  remaining items omitted (three unbuilt features: profiles, editing, and
  backup; and one verification gate: real-device checks of each input method),
  and drafted a concrete first `What's New` entry. Checked character and byte
  counts against Apple's limits and verified with `python3 scripts/test-docs.py`
  (45 tests).
  [Record](log/2026-10-27-app-store-listing-drafts.md).

- **Accessibility reference audit (`docs/ACCESSIBILITY.md`), 2026-10-27:**
  confirmed every API and feature row in `docs/ACCESSIBILITY.md` against
  `developer.apple.com` (reading `.md` symbol pages and the framework update
  pages for `Accessibility`, `SwiftUI`, `UIKit`, `AVFAudio`, `AppIntents` and
  `XCUIAutomation`) and independent accessibility references. Corrected stale
  API names, minimum iOS versions and `main` implementation statuses (including
  `.spokenAudio` mode, `UIConversationContext` / `UITextInputDelegate`,
  `AccessibilitySettings.showBordersEnabled`, per-case `AccessibilitySettings.Feature`
  versions, `hoverEffect`, `accessibilityInputLabels`, Voice Settings,
  `accessibilityValue` / `accessibilityHint`, `DraftIssue` announcements and
  Dictation), and added a *New since this list was written* section covering 18
  Apple additions across iOS 18, iOS 26 and iOS 27. Follow-ups added:
  real-device check of `.default` audio session behavior when another app speaks,
  and evaluating `AccessibilitySettings.Feature.assistiveTouchDevices`
  for the setup guide. Verified with `python3 scripts/test-docs.py` (45 tests).
  [Record](log/2026-10-27-accessibility-reference-audit.md).

- **Mac Home and keyboard checks, 2026-10-25**, main `8316743`, Xcode 27.1
  (27A9275), iOS 27.0: on a 375×667 iPhone SE simulator the default-text
  keyboard probe passed and AX5 failed Home's conservative band check;
  with Larger Text Display Zoom (verified 320×568), both failed that
  check. All four keyboard-allowance measurements passed with the full
  software keyboard. Type is already disabled in those restricted cases.
  Manual AX5 typing on iPhone 17 and 13-inch iPad, portrait and also iPad
  landscape, kept the required communication controls fixed and above
  the full keyboard. Put Back was behind the phone's keyboard. No device
  check passed. The current app was subsequently installed and launched
  on a physical iPhone; the owner's informal handheld observation found
  no outline on white disabled tiles, with outlines on keyboard keys and
  coloured controls. Formal device testing is deferred until a mounted
  setup is ready; independent Mac work continues at the owner's request.
  The Home matrix found all eight starter phrases fitting on the 13-inch
  iPad at default/AX4/AX5, standard and Larger Text Display Zoom, in both
  orientations. Standard iPhone AX4/AX5 scrolls 4/52pt. Its zoomed 320×693
  window scrolls 169pt at default. A later native sample measured 329pt
  at AX4 through its 7pt-high grid, with no whole tile at either end;
  at AX5 the grid has zero height below the window. Those access checks
  fail ([AX4 result and images](evidence/2026-10-25-duo-design/phone-zoom-ax4-scroll-results.json)).
  Default zoom was restored and verified at 402×874 before cleanup.
  Duo's closed/open Home runs include failures; native Device Hub also
  covered both inner orientations and a 130° partial pose. Three separate
  cold iPhone boots passed the historical first-snapshot test without app
  warm-up; the flake was not reproduced or fixed.
  [Measurements, failures, limits and screenshots](log/2026-10-25-mac-keyboard-checks.md).

- **PR #17 main refresh, 2026-10-23:** merged library main `48bcf73`
  without rebasing. Nine new guard/documentation findings are corrected;
  the xargs optional-argument finding was rejected against GNU documentation
  because its suggested change broke a valid existing safeguard. The local
  unit script passed 591 native tests with the existing issue #19 skip,
  124 hook tests and 34 documentation tests; the catalog is unchanged.
  Xcode 27.1 (27A9275), iPad Pro 13-inch (M5), iOS 27.0.
  Five further findings on `227cda9` cover merge-queue requests, shell
  recursion/stdin, curl option clusters and CDPATH directory selection.
  All five failing reproductions now pass, as does the full refreshed
  local gate above. A further eight findings on `e98e95a` now have focused
  fixes, alongside the clean main `b6be682` refresh. The refreshed full
  local gate passed, including the inherited current-framework tests.
  Seven findings on `62b79b5` now cover implicit client configuration,
  send-pack, translated shell strings, abbreviated staging options, link
  labels and exact path spelling; their focused reproductions and the
  full local unit gate pass.
  Main `f34e8ae` (Settings on Home) is merged in. The old hosted unit
  job failed before Swift tests because the runner fixture hid gh from
  repeated guard-suite runs. The harness now isolates preflight dependencies
  and checks their ordering and failures; the real unit gate still runs
  both full suites. All 54 runner tests and the refreshed local unit gate
  pass. Eight further findings on `f3bfb0b` now have failing-first
  reproductions and fixes for command operands, branch changes, upload
  bodies and escaped reference labels; all 114 hook and 32 docs tests pass.
  Main `d654cef` (Show Borders on Home) is merged without conflicts.
  Its device-check caveats remain intact. Seven further findings on
  `7e64ecf` tighten runtime operands, branch renames, review flag clusters
  and escaped reference titles; the verifier now completes its report with
  CI pending. Six findings on `9845a0d` now cover expanded push operands,
  Wget/curl URL sources, decoded Copilot endpoints, trap actions and exact
  fragment case; their regressions fail before correction and pass after it.
  Main `43cea55` (PRs #39 and #37), then `412f4cf` (PR #38), are merged
  by merge commits. Eight findings on `a4ed3d9` reproduce but are
  declined, past the two-round fix cap, as ways round a guard against
  mistakes, and one on `571c8fc` is a refusal of a harmless command; the
  record lists them, with `git add ..` and `source` first for a later
  guard pull request.
  PR #17 has since merged as `7bff8f0`.
  [Guardrail record](log/2026-10-22-agent-guardrail-reconciliation.md).

- **PR #14 reconciliation, 2026-10-22:** incorporates main `cc35c30`, the
  invisible-text Emergency correction and the bounded category-name fix.
  Standalone invisible decorations no longer create duplicate names;
  composed names and stored/imported bytes remain intact. All 56 pure
  library tests pass. The fresh full native unit gate passed 560 tests,
  zero failures and one existing issue #19 crash-probe skip (561 total);
  the String Catalog is unchanged. Full local UI on `7ec516f` completed
  with 34 passed, one speech-wait failure and four existing probe skips
  per device, alongside the known host-audio limitation. Hosted CI on
  that head passed 560 units (one existing skip) and all 35 enabled UI
  tests per device (four existing probe skips). All 21 existing review
  conversations are resolved. The earlier Codex review was still running
  at that measurement; the final head has since passed and merged.
  The PR #32 main refresh passed the same 560-unit native gate with one
  existing skip and an unchanged catalog. The older AX5 audit finding
  remains unexplained. The owner later enabled auto-merge. The
  PR #29's CI-artifact documentation is now merged from main `cc35c30`;
  its fresh local gate passed 560 units with the existing issue #19 skip
  and unchanged catalog. Final-head CI `39887840347` on `f45a33a` passed
  560 native tests with the existing issue #19 skip, plus all 35 enabled
  UI tests on each of iPad and iPhone (four existing probe skips each).
  PR #14 then merged automatically into `48bcf73`; all 21 conversations
  were resolved.
  [reconciliation record](log/2026-10-22-library-reconciliation.md)
  preserves toolchain/device details, complete history and remaining checks.

- **GitHub CI** since PR #12 (merged 2026-10-21) builds with Apple's
  newest released Xcode, chosen on GitHub's `xcode-27` image (27.1,
  27A9275, on 2026-10-21), and tests on an iPad Pro 13-inch (M5)
  simulator on iOS 27.0
  ([`log/2026-10-21-toolchain.md`](log/2026-10-21-toolchain.md)); the
  image's other iOS runtime, 27.1, holds only iPhone Duo. On 2026-10-30
  CI was still on 27.1: Apple released Xcode 27.2 (27B52) on 2026-10-29,
  but GitHub's image held only its release candidate, and CI moves by
  itself once GitHub installs the release and Apple's releases feed
  lists it
  ([`log/2026-10-30-xcode-27-2.md`](log/2026-10-30-xcode-27-2.md)). Since
  PR #13 the UI tests run on the newest iPad Pro 13-inch and the
  newest standard iPhone, after a warm-up launch, and fail when no test
  ran ([`log/2026-10-21-test-seams.md`](log/2026-10-21-test-seams.md));
  since 2026-11-03 each family runs as a job of its own, at the same
  time.
  Since PR #28 each job keeps `build/TestResults` as a download on the
  run's page for 14 days, passed or failed, unless the job stopped
  before its tests started (a build failure leaves no bundle)
  ([`log/2026-10-22-ci-test-results.md`](log/2026-10-22-ci-test-results.md)).
  Since PR #39 (2026-10-23) a compiler warning in any target fails the
  build (docs/DECISIONS.md, "Warnings are errors";
  [`log/2026-10-23-warnings-as-errors.md`](log/2026-10-23-warnings-as-errors.md)).
  Since the chain engine (2026-10-23) every UI run follows the chains of
  held activations through Settings' first screens on each simulator and
  attaches what it finds (`settings-chains-…`; docs/DECISIONS.md, "One
  chain engine for dwell safety").
  Since the keyboard allowance (2026-10-23) every UI run measures Apple's
  keyboard in each orientation at the default and largest text sizes,
  and fails if it is taller than `KeyboardAllowance` keeps room for or
  if Home's safety row reaches below that room
  ([`log/2026-10-23-keyboard-allowance.md`](log/2026-10-23-keyboard-allowance.md)).
  Before PR #12, CI used Xcode 26.6 and iOS 26.5; 10 of 11 runs on
  `9362eca` were green, and the failure was simulator infrastructure.
- **The owner's Mac, 2026-10-30**, Xcode 27.2 (27B52, Swift 6.4.2, iOS
  27.2 SDK), main `23c1ac4` in a separate clone: the app, unit tests and
  UI tests built for the simulator, and the app for a device in Release,
  with no compiler warning or error; the unit suite passed on an iPad Pro
  13-inch (M5), iOS 27.2 (24B8117): 799 ran, 790 passed, 1 skipped
  (issue #19), 8 expected failures, catalog unchanged. The UI tests and
  the iPhone Duo simulator were not run on 27.2. Of the Mac's two iOS
  27.2 runtimes, 24B91016s holds only iPhone Duo and 24B8117 every other
  iPhone and iPad ([`log/2026-10-30-xcode-27-2.md`](log/2026-10-30-xcode-27-2.md)).
- **A Mac, 2026-10-21** (PR #13's diagnosis), iPhone 17 and iPad Pro
  13-inch (M5) simulators on iOS 27.0: 17 UI tests passed on each, with
  strict accessibility audits in light and dark, Home's controls
  reachable and in fixed frames at the default and AX5 text sizes, and
  the quick-control words read back whole from screenshots at AX5; 136
  unit tests passed
  ([`log/2026-10-21-ui-test-diagnosis.md`](log/2026-10-21-ui-test-diagnosis.md)).
- **The owner's Mac, 2026-10-12 to 2026-10-16**, Xcode 27.0, iOS 27.0
  simulators, run by agents: 113 unit cases and 8 UI tests green on an
  iPad Pro 13-inch (M5). The app was also run on iPad and iPhone 17
  simulators at the default and largest text sizes, which found the phone
  problems under *Known gaps* (docs/recon/2026-10-15/README.md, 2.1). No
  person has yet run the app and heard a phrase on record.
- **Physical device, 2026-10-25:** the current app installed and launched
  on an iPhone 17 Pro Max, iOS 27.0.1. The owner supplied an informal
  handheld gaze observation, recorded with its limits in
  [the Mac check record](log/2026-10-25-mac-keyboard-checks.md).
  No controlled device check has passed. Formal testing waits for a
  mounted setup; see *Checks that need a real device*.
- **No test sees** VoiceOver announcements being posted, the message's
  scroll reset, the missed-callback watchdog on a physical device (it is
  unit-tested with fakes), or sound. A later temporary simulator trace
  observed 232 real-synthesizer watchdog checks over 239 seconds: progress
  reached the tracker, but the system stayed speaking/unpaused without a
  finish/cancel callback. Three isolated AV controls also timed out without
  Brickson's wrapper; cause remains unidentified, with no audio or wait
  change ([diagnostic](evidence/2026-10-25-duo-design/speech-diagnostic/README.md)). Windowed iPad
  sizes are untested. The 2026-10-25 Mac run checked Duo closed, open,
  partially open and rotated, with recorded failures and test-framework
  limits ([record](log/2026-10-25-mac-keyboard-checks.md)). Later item 6
  measurements queried the reserved regions and reached both native
  Split View panes. The item 6 Spec and scoped drawings are linked, and
  earlier PR #58 head `35bed06` has a green
  [hosted run](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40244703180):
  777 unit cases and 51 UI cases per standard family completed. The AX3
  capacity correction passes 778 native unit cases (769 passed, zero
  failed, one existing #19 skip and eight strict expected failures), with
  a current catalog and 71.2% coverage. Two focused light/dark native
  probes show eight whole Basics tiles after returning 4pt of optional
  category growth; 59 of 60 modeled static layouts remain exactly
  unchanged. Its full standard UI run completed 51 cases per family, with
  one failed AX5 Speaking-wait case each and no other unexpected assertion
  ([receipt](evidence/2026-10-25-duo-design/ax3-growth-ui-results.json)). Earlier complete local
  runs failed one Speaking-wait case per family; unchanged main reproduces
  it on the same iPad, with cause unresolved. Default/AX5 captures were inspected on both
  families; representative Duo active-display captures were also inspected
  ([design record](log/2026-10-25-duo-fold-design.md)). The first UI test
  intermittently showed a blank canvas and failed AX startup on CI despite
  PR #13's warm-up launch, and local cold controls passed
  ([follow-up and recovered CI frame](log/2026-10-25-native-ax5-typing.md)).
  The cause, found on 2026-11-01 in the app's own log inside each failed
  run's result bundle: the app read the voice list on its main thread
  before its first frame, and a just-started simulator's voice service
  took more than 60 seconds to answer, so XCTest's automation session
  gave up. Since #73 the list is read away from the main thread
  (docs/DECISIONS.md, "The voice list never holds up launch"). Its first
  CI run passed, and on the iPhone simulator the first three launches
  were driven while the voice service had not yet answered; one green
  run does not prove the failure gone
  ([cause, evidence and how to read the app's log](log/2026-11-01-voice-list-off-launch.md)).
  Apple's accessibility audit never sees
  Home's "Speaking" line: audits wait for speech to finish, because one
  that ran while the line left reported text with no element (issue #30,
  [`log/2026-10-22-audit-still-screen.md`](log/2026-10-22-audit-still-screen.md)).

## Known gaps

Each names who closes it: *(owner)*, the thread working on it, or the
release in docs/ROADMAP.md when no thread has it yet.

- Home's larger sizes (2026-10-30) have not been tried by a person on
  a device: the switch and head floors are proposals, and no phone holds
  more than touch's sizes, so a gaze, head or switch answer on a phone
  gets touch's (docs/DECISIONS.md, "Sizes that follow how the screen is
  reached", *The fallback, the owner's choice*). Settings' Back to
  Talking keeps touch's frame under the larger sizes, smaller than their
  floors, an exception to invariant 1 the owner accepted on 2026-10-30
  (same section, *Back to Talking keeps touch's frame*). Which floors
  Settings' other controls hold under a larger profile is not recorded:
  its rows keep a 64-point minimum height in every profile
  (`SettingsMetrics.rowHeight`), the navigation bar's standard Back
  buttons keep the system's size, and the guide's Done sits in Back to
  Talking's frame; the next Settings thread measures them and puts them
  to the owner (docs/ROADMAP.md, *The quality bar*, Q3).
  *(device checks, before any build goes to App Review: docs/ROADMAP.md,
  *The quality bar*, Q3 and Q13)* The rest board's late-stage sizes
  (2026-11-01) are proposals too: their 136-point floors and the safety
  row's growth toward 4 degrees rest on a study with a phone's camera
  and people without ALS, not Apple's Eye Tracking. Where the board has
  as many rows as every category (four columns, and a board of eight
  phrases on a phone), its safety row grows out of the tiles (302 points
  tall on the 13-inch iPad in portrait, where every category's are 350;
  92 on the iPhone 17 with Basics, where they are 111), and on the
  iPhone 17 Pro Max a board of six takes head tracking's sizes, which
  make its tiles 110 points tall where touch's with every category are
  138 (with a board of eight it keeps touch's, and its tiles are 108);
  the owner can cap the growth or keep touch's there (docs/DECISIONS.md,
  "The late-stage profile", *Where the board's sizes hold*).
  *(device checks: docs/ROADMAP.md, *The quality bar*, Q11 and Q13; then
  the owner)* At
  touch's sizes, by the engine's model the phrase grid still scrolls (invariant 11) on
  phones smaller than the Pro Max at AX5, on the iPhone 17 at AX3 with
  Bold Text, on a 375×667 phone at every size (at the default size by
  half a point, since typing came to Home), on 320pt windows at every
  size, and on compact windows 667pt tall at AX3; with typing on Home it
  no longer does on the iPad mini and a zoomed 13-inch iPad in landscape
  at AX5, or on regular windows 667pt tall at AX3 (docs/DECISIONS.md,
  "Typing on Home", *Where the starter library fits, measured*).
  The 2026-10-25 simulator measurements replace Duo's outer-display
  prediction: it scrolls 3pt at default, 201pt at AX4 and 249pt at AX5;
  AX5 cannot show a whole tile even after scrolling. The zoomed iPhone
  320×693 grid is only 7pt high at AX4 and zero-height at AX5. These
  restricted windows need an arrangement that can show a whole row;
  paging alone cannot make one fit. What remains needs fewer tiles to a screen: drawn in
  Figma as R1's direction, pages of whole rows with "More, 1 of 2" in
  the grid's last slot (docs/work/typing-on-home.md, *Fewer tiles to a
  screen*), not built, because touch's sizes may scroll. The
  [measured fewer-tiles proposal](recon/2026-10-25-fewer-home-tiles.md)
  now records current whole-row capacities, More's slot cost and windows
  where no complete row fits; it changes no code or release boundary.
  *(R0 item 3, before App Review: docs/ROADMAP.md, *The quality bar*,
  Q3; then the owner)*
- The slot plan has no answer yet for more than four everyday categories
  (docs/DECISIONS.md, "Home's slot plan", *Open*), so editing and import
  refuse a fifth (docs/DECISIONS.md, "Three or four everyday
  categories"). Only a store made some other way could hold one; Home
  keeps the fourth and later ones in the fourth cell, which scrolls
  (docs/DECISIONS.md, "Get Attention and Stop on Home"). *(the layout
  engine, a new thread)*
- A library with fewer than three everyday categories can leave Again,
  which speaks, nearest Stop's empty well: the cell under the well can be
  empty (docs/DECISIONS.md, "Get Attention and Stop on Home"; a strict
  known issue in `HomeLayoutEngineTests`). Since 2026-11-05 no edit or
  import can leave fewer than three, the owner's rule (docs/DECISIONS.md,
  "Three or four everyday categories"), so the hazard is out of reach of
  every library Brickson writes; the layout still has no answer for one,
  should a store ever hold one, so it stays on docs/ROADMAP.md, *The
  quality bar*, Q2. *(the owner, after the Snap to Item check, or the
  layout engine)*
- The top of Stop's well is nearest Again, 10 to 12pt above it (up to
  30.5pt where the categories sit lower), which speaks: by the stand-in's model about 10 to 40% of the well by nearest
  centre and about 40% by nearest edge. On the engine's frames Again is
  above it on every width; Yes, two rows up, never is, as the categories
  sit lower where the safety row is short (`HomeLayout.wellDrop`). A
  look resting there after Stop, or on the empty well, could repeat the
  last message. Open, not accepted; the same
  device check as the message hazard decides it (docs/DECISIONS.md, "Get
  Attention and Stop on Home"; a strict known issue in
  `HomeLayoutEngineTests`). It is the only hazard the chain engine finds
  in Home's states
  (`HomeLayoutEngineTests.noChainOnTheEnginesFramesMeetsAHazardButStopsWell`).
  Since typing came to Home (2026-10-24) it is gone on regular widths,
  where Emergency is above the well; on compact widths, while typing,
  Again's slot shows Speak, which says the typed message
  (docs/DECISIONS.md, "Typing on Home"). *(owner if it stays)*
- An alarm warning nobody acts on ("Alert stopped", "Alert failed") keeps
  Home's status line until Get Attention sounds again, so a later cut-off
  phrase, low volume or failed session shows second; VoiceOver still
  hears each (docs/DECISIONS.md, "Get Attention and Stop on Home").
  *(the next audio thread)*
- The rendered-label UI test reads only the quick controls back from
  screenshots, not the categories, whose words now keep 6pt from their
  sides like Emergency's, out of the selection ring's reach
  (docs/DECISIONS.md, "The layout engine", *Home on the engine*).
  *(the next accessibility thread)*
- A Get Attention tone started while the audio session could not be
  activated shows "Sounding" with no warning once a later activation
  succeeds (a phrase, or a retry whose new tone then fails to start),
  though nothing has shown it is heard with the silent switch on
  (docs/DECISIONS.md, "Get Attention", *Open*). *(the next audio thread,
  after a device check)*
- Yes and No border the message (12pt away), so a look resting on it
  can speak one of them. Reduced, not removed: Again no longer shares the
  message's edge, and by the model about 56% of the message is nearest a
  control that speaks by centre and 50% by edge on every window
  (Emergency is nearest the rest), down from about 61 to 67% with Again
  in the first row and 89 to 95% before that, on phones. Recorded as an open hazard, not
  an accepted exception (docs/DECISIONS.md, "Home's slot plan" and
  "Settings on Home"): a device check (Snap to Item by nearest centre or
  nearest edge) decides whether placement can remove it, or its measured
  cost goes to the owner before a dwell, switch, head or gaze profile
  ships. On the layout engine's frames without Phrases and Type it was
  at most 57% by centre and 51% by edge. Since typing came to Home
  (2026-10-24), Phrases and Type are beside the message, as the slot
  plan places them, and it is up to 97% by centre and 89% by edge on
  compact widths, 68% and 62% on regular ones; no placement inside the
  slot plan removes it. **Owner question, before any build goes to App
  Review or the external TestFlight pilot (docs/ROADMAP.md, *The quality
  bar*, Q2):** accept that as a
  named exception to invariant 10, or ask for another placement
  (docs/DECISIONS.md, "The layout engine", *Home on the engine*; "Typing
  on Home" left it as it was). *(the owner, before any build goes to App Review or the external pilot)*
- While typing, by nearest centre, a look resting in the top band of a
  dimmed phrase tile in the grid's top row (up to about 40% of its
  height on iPads, a fifth on phones), or between two of them, is nearer
  Clear's or Put Back's centre than its own tile's, so it can meet one of
  them, which change the message unasked
  (neither loses words: Put Back only brings back what Clear took, and
  Clear can be undone once). By nearest edge nothing is met: the empty
  grid's finding by both rules went when the tiles stayed in place,
  dimmed, except over the empty cells of an Emergency with fewer than
  four phrases (the next item). Open, not accepted, pinned strict in `HomeLayoutEngineTests`
  (docs/DECISIONS.md, "Typing on Home", *Open: by centre, dimmed phrases border Clear and Put Back*). *(owner, before any build goes to App Review or the external pilot)*
- A category with fewer phrases than Home's widest grid has columns
  (four), which the Library lets a family make, is dimmed on Home and
  never shows, and the Library keeps four in a category once it has
  them (docs/DECISIONS.md, "Four phrases in every category", the
  owner's decision of 2026-11-05).
  Three things stay open. Emergency is never dimmed, so an Emergency
  already short of four (no edit can make one, or take one farther
  under) shows its empty cells,
  where a look meets Clear or Put Back while typing and a phrase that
  speaks while browsing; scored, pinned as two strict known issues in
  `HomeLayoutEngineTests` (*Emergency with fewer than four*), and the
  Library tells the family to add phrases. A rest board already short
  of four does the same, measured on 448 windows and pinned in
  `LateStageProfileTests`; no edit or Set Up makes one, but a chosen
  category deleted and later restored from an older backup that held it
  short comes back as the board (*Open: a rest board with fewer than
  four*). Both are on docs/ROADMAP.md, *The quality bar*, Q2, for the
  owner's decision. And the dimming, like
  typing's, assumes Snap to Item stops on a dimmed control, unmeasured
  until docs/DEVICE-CHECKS.md, I8 and B2. *(the owner; the device
  checks)*
- A restored backup can hold a phrase the editor matches to "Yes",
  "No", "Emergency", "Get Attention" or "Help" and refuses:
  a backup's words are never changed. It is expected to cost a Voice
  Control user a second command for that control while the phrase shows:
  the exception to invariant 10 the owner chose on 2026-11-06
  (docs/DECISIONS.md, "Phrases named like Home's controls"). A hand-made
  backup can give a category such a name too, at that cost on every
  board, which follows from the same rule, though the question the owner
  answered named phrases. Both are unmeasured until device check I2.
  *(the device check)*
- On a phone at the largest text sizes the keyboard covers Save and the
  line under it on the Library's editors (iPhone 17, AX5, 2026-11-05).
  Save puts the keyboard away when its line carries a note or a refusal,
  but the line then starts at the screen's foot: Edit Phrase shows
  "Saved. Another", New Phrase "Added “Stop.” to", and the rest is a
  scroll away, a refusal's reason too, past the part of the screen
  Settings keeps. A plain
  "Saved." or "Added" stays behind the keyboard, and Save itself takes a
  scroll or Return to reach. *(the next library thread)*
- No typing on Home where the keyboard's room reaches the safety row:
  320pt windows at every size, a 375×667 phone from AX3, and the iPad
  mini and a zoomed 13-inch iPad in landscape from AX3. There Type is
  dimmed, with a VoiceOver hint saying why, so the keyboard never covers
  Emergency, Yes, No, Speak or Get Attention on entry. If the room goes
  while typing, the intended behavior is to put the keyboard away while
  typing stays on and the phrases stay dimmed (`HomeLayout.offersTyping`;
  docs/DECISIONS.md, "Typing on Home", *The keyboard's room, measured*).
  A native Duo AX3 tall-to-wide transition instead left the keyboard
  visible on both `35bed06` and the local capacity candidate. A private
  baseline-only trace reports focus false at the settled wide observation;
  the keyboard remains visible. Cause is unresolved and no focus fix is claimed
  ([record](log/2026-10-25-duo-fold-design.md)). The keyboards on these windows are
  not measured (the room is the tallest keyboard measured on their
  shape), so measuring them may give typing back; offering it with the
  covered controls two activations away would be an exception for the
  owner. *(Codex's keyboard check, then the owner)*
- A label with a word too wide for its slot even at the default text size
  is cut short with an ellipsis when it is one word, but in a phrase of
  several words that word can wrap mid-word. No starter label has one
  (`StarterLabelFitTests`). Since 2026-11-05 a family can save a phrase
  with one, with a note that it can wrap on the narrowest screens: the
  owner's choice (docs/DECISIONS.md, "Words wider than Home's narrowest
  buttons"). A category name with one is refused, by editing and import.
  *(accepted by the owner; the layout engine, if it ever gives such a
  word room)*
- At the largest text size some Settings rows hold a word wider than a
  row's room for words, so it breaks mid-word (AGENTS.md, "Words never
  break"): on CI's iPhone 17, "Accessibility" in More Accessibility
  Settings and "Categories" in Phrases and Categories; on a 375-point
  phone, "Shortcuts" and "Reaching" too. Measured from word widths and
  a capture's row geometry, not yet read from captures of those rows.
  The check-in card's rows, which broke the same way side by side, are
  full-width since 2026-11-12 and read whole on CI (`SettingsTests`;
  [`log/2026-11-12-check-in-card.md`](log/2026-11-12-check-in-card.md)).
  *(the next Settings thread)*
- On windows under 345pt with Bold Text, the message beside Phrases and
  Type is too narrow for "understand.", which can break there; since
  typing came to Home (2026-10-24) this is Home's (docs/DECISIONS.md,
  "The layout engine", *The message on the narrowest windows*; "Typing on
  Home"). 320pt windows need their own arrangement. *(the layout engine,
  a new thread)*
- The running app's frames are not compared with the engine's point by
  point: the UI tests check what the engine predicts for CI's iPhone and
  iPad (fits, on screen, fixed places), not each frame
  ([`log/2026-10-24-home-on-the-layout-engine.md`](log/2026-10-24-home-on-the-layout-engine.md)).
  *(Wave 3 item 5, or a Mac thread)*
- Settings' Back to Talking broke "Talking" across two lines ("Talk-",
  "ing") on CI's iPhone at the largest text size (PR #33's captures).
  Since 2026-10-24 it takes Phrases' frame and a `FittedLabel` in the
  categories' font, which keeps words whole, drops the icon first and
  takes two lines where it must (docs/DECISIONS.md, "Typing on Home");
  no test reads its rendered words back yet. *(the next accessibility
  pass: add it to the rendered-label test)*
- The rendered-label tests read the five English quick-control labels
  (Yes, No, Emergency, Get Attention, Again), and, on an iPad in
  portrait at Home's larger sizes, Phrases, Type and the everyday
  categories (`HomeSizesTests`), and on rest boards of six and eight
  phrases, on CI's iPhone and iPad, the quick controls and every
  everyday category, dimmed or not (`HomeRestBoardTests`); never a
  phrase tile, and nothing at
  AX3. `StarterLabelFitTests` measures every starter label against its
  narrowest slot instead. *(Accessibility coverage checklist)*
- The Get Attention tone is the reference app's placeholder; a
  harmonic-rich replacement and its level under speech need a listening
  check on a device (docs/DECISIONS.md, "Get Attention"). *(owner, with a
  device build)*
- In dark mode, iPad multitasking can lift a window's background from
  black to the elevated gray. Against `#1C1C1E` (a commonly reported
  value, not read from Apple) the accent, control and Emergency fills
  come to 2.84 to 2.96:1, under invariant 6's 3:1. Since 2026-11-02
  every Home button draws a white border in dark mode, and `PaletteTests`
  measures it against the lifted screen (4.5:1 or better), so no button's
  fill meets that screen. The message field's 2pt border is still the
  control fill there (2.84:1 against `#1C1C1E`); `PaletteTests` does not
  measure it. *(the next accessibility thread)*
- iPad windows the person can resize have two gaps besides being
  untested (*Verification*). No scene has a minimum window size, though
  docs/LESSONS.md, "Windows need a minimum size", asks for one derived
  from the safety controls at the largest text size: `BricksonApp`'s
  `WindowGroup` sets no minimum frame and no `windowResizability`, and
  the reference's `WindowSizePolicy` was not ported (docs/PORTING.md,
  *Port and generalize*). And nothing scores a look resting through a
  resize: Home takes three columns or five from the window's width
  (`HomeLayout.isRegular`: five where each of five columns gets 122
  points, 132 with Bold Text), so dragging an iPad window's edge across that width moves
  controls under a look that has not moved. That is the kind of hazard
  iPhone Duo's changed-window finding is (R0 item 13), and only iPhone
  Duo's windows were checked for it. Its score belongs in the chain
  engine, as a surface for windows that change, never a new script
  (AGENTS.md, *Design rules for dwell, switch and pointer input*, "Score
  chains with the one chain engine"); how iPadOS moves a pointer when a
  window is resized is not known until a device shows it (*Checks that
  need a real device*). Found
  2026-11-03 from the owner's consultant notes
  ([log](log/2026-11-03-agents-md-for-codex.md)). *(R0, docs/ROADMAP.md,
  *The quality bar*, Q10; no thread has it yet)*
- Typing on Home (since 2026-10-24) has automated coverage on CI's iPad and
  iPhone simulators, in portrait, at the default text size, with the full
  software keyboard (`TypingOnHomeTests`); `KeyboardProbeTests` checks the
  safety row against the keyboard's room at default and AX5, in portrait
  and, on iPad, landscape. Manual AX5 checks on the owner's Mac
  (2026-10-25) kept the required communication controls above the full
  keyboard on iPhone 17 and the 13-inch iPad in both iPad orientations.
  Put Back was covered on the phone (y=547–624, keyboard top 546).
  A later native-input check on app code `6d040d5` reproduced that
  coverage; Clear emptied the field, but Put Back remained behind the
  full keyboard. The visible software Return key submitted the message,
  and reopening Type retained the draft. This proves visible state,
  not sound ([follow-up](log/2026-10-25-native-ax5-typing.md)). That record
  landed in [PR #59](https://github.com/MiddleAgedBanana/Brickson/pull/59),
  now merged as `e568aa7`; its `0d87ae1` hosted unit/UI checks passed.
  Put Back's
  placement still needs a layout answer. On iPad, Clear and Put Back
  were observed, and Device Hub checked their reachability. Native
  Device Hub activation of Return changed the last-spoken display.
  [Record and screenshots](log/2026-10-25-mac-keyboard-checks.md).
  The later item 6 probes also measured default-text full-screen Duo
  typing in both axes with the full US English keyboard; the core controls,
  Clear and Put Back were geometrically uncovered. AX5 Type was unavailable.
  [Receipts](evidence/2026-10-25-duo-design/native-frame-comparison.md).
  Not checked: windowed iPad/Duo keyboards, the iPad's floating and split
  keyboards, other languages (`KeyboardAllowance`'s *Not covered yet* in
  docs/DECISIONS.md, "Typing is a state of Home"), and on a real device
  whether the cursor and keyboard come at once when Type is chosen by
  Switch Control, Voice Control or a dwell, what a look slipping off the
  keyboard's top row meets, and Return among the letter keys for dwell
  users (docs/DECISIONS.md, "Return speaks"; the checks in
  [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md)).
  The status line's "Message not saved", "Message not restored" and
  "Message full" are unit-tested only. The 2026-10-25 keyboard probes
  measured 375×667 and its zoomed 320×568 window, at default and AX5.
  Standard AX5 projects a 3pt keyboard overlap at Again/Get Attention;
  zoomed AX5 projects larger overlaps. Zoomed default clears the keyboard
  measured by 18pt but fails the conservative band, so that one result
  does not establish that Type can be enabled. Probe and Home are separate
  launches; no actual keyboard covered Home in these restricted states.
  The device checks are in *Checks that need a real device*. *(Codex on
  the owner's Mac, then the owner's devices)*
- The Library's screens (docs/DECISIONS.md, "The Library in Settings")
  leave these open. The share sheet cannot hold Settings' idle reset, so
  a reset can return Settings to its root behind it. The chain engine
  does not follow past the share sheet or the file picker, nor where a
  look rests after the picker closes, nor into New Phrase, New Category
  and Rename Category, whose Save is dimmed until a family member types
  ("The Library's question screens", *Not scored*). The Figma drawings
  of a category's rows, Delete, Change Picture and the Restore question
  show the first version, before the chain engine moved them
  ([work file](work/library-screen.md), *What building it changed*).
  Whether the file picker reads a backup from iCloud Drive, and the share
  sheet's AirDrop and Mail, need a device (*Checks that need a real
  device*). A Replace that would remove the person's own words is
  refused; a safety-copy exception is not adopted and requires the
  owner's decision before implementation (docs/DECISIONS.md, "Replacing
  the library"). *(R0 item 6 follow-ups; the device checks, the owner)*
- `rollback()` crashes SwiftData after deletes, even without a cascade
  (issue #19, seen with Xcode 26.6 on iOS 26.5). Brickson never calls it.
  Run once on 2026-11-05, the reproduction passed with Xcode 27.2 on an
  iOS 27.2 simulator, in memory; not on a store on disk, a device, or
  iOS 26 with this Xcode. It stays disabled and the rule stands, because
  Brickson also runs on iOS 26. The result is on issue #19. *(nothing
  left for the probe)*
- On the owner's Mac, on the iPhone simulator, the app sometimes reports
  no idle for over a minute after Save on New Category, so
  `LibraryTests.testCategoriesStayBetweenThreeAndFour` runs past
  Settings' 90-second reset and fails. Run five times each on 2026-11-06,
  unchanged `main` and PR #82's branch both failed once and ran slow
  once; it has not failed on CI. Cause unknown
  ([`log/2026-11-05-phrases-named-like-controls.md`](log/2026-11-05-phrases-named-like-controls.md)).
  *(a Mac thread)*
- GitHub's `xcode-27` machines do not all run one image while a new one
  rolls out, so one run's jobs can differ and a re-run can land on
  another image. On 2026-11-06, PR #82's jobs ran on image 20261104.0337,
  which has Xcode 27.2 and iOS 27.2, and on 20261026.0314, which has only
  27.2's release candidate, so `scripts/select-xcode.py` skipped it and
  took 27.1 with iOS 27.0. Nothing is pinned, on purpose
  (docs/DECISIONS.md, "Build with Apple's current Xcode"), and nothing
  needs changing: it ends when GitHub finishes the rollout. On the newer
  image `HomeAccessibilityOrderTests.testQuickControlsComeFirstInEveryStateAtDefaultText`
  failed once on the iPhone, just opened, reading Phrases and Type before
  Yes and No. It has passed on the Mac's iOS 27.2 each time, and on
  PR #82's last commit, with all three jobs on the newer image. If it
  fails again on that image, it is intermittent, and pull requests will
  meet it once every machine has the image. *(the next thread whose CI
  shows it)*
- Settings' Get Attention place is still empty, although AGENTS.md's
  design rules say "Settings opens on a large way back and a start-only
  Get Attention". Scored on 2026-10-24, Get Attention there would sound
  the alarm unasked on every window, 2 to 5 chains each, mostly from the
  standard Back button just under that place, so it was not added.
  Keeping it out, adding it anyway or finding a place first is the
  owner's decision (docs/DECISIONS.md, "Get Attention in Settings' bar:
  the owner decides"); the AGENTS.md wording for keeping it out is
  proposed in
  [`log/2026-10-24-settings-chains.md`](log/2026-10-24-settings-chains.md).
  Settings' sound line stays at the foot of the cover, where its nearest
  controls are the rows a screen has scrolled to its lower edge, some of
  which speak a sample or change a setting; a place whose neighbours do
  neither comes with Get Attention's, if it comes. *(the owner, then a
  new thread)*
- Chains of activations through Settings' screens are scored on its
  first screens and on Set Up Step by Step's first two steps
  (`SettingsOnHomeTests` with the chain engine, on CI's iPad and
  iPhone; docs/DECISIONS.md, "One chain engine for dwell safety"). The
  steps after the second (the voice, turning on what was chosen,
  keeping Brickson open, the summary) are not followed: a look held on
  Next walks into them unscored, as it did into every step after the
  first before 2026-11-01. Since 2026-10-30 no hazard is open on the
  scored screens in the models: a held look no longer saves a setup
  answer or closes Settings under the look, on CI's windows or on 630
  swept ones, and `SettingsOnHomeTests` fails on any (docs/DECISIONS.md,
  "The first step's own rows"); each of the second step's choices lies
  where a look resting on Next meets Next again (docs/DECISIONS.md, "The
  late-stage profile", *Where the second step's choices start*).
  Settings' Family Setup row is placed from Home's frames, Set Up Step
  by Step takes its frame in Family Setup, and Learn About Each Way
  takes that frame on the first step; its guide opens as a cover of its
  own with Done in Back to Talking's frame, the answers start below
  every place a look can be resting on the way in, and Next only moves
  on (the check-in card's Go Through Setup Again answers the check-in
  instead, and opens the first step with Learn About Each Way in its
  frame). A device check says whether it binds. Since 2026-11-12 the
  card's rows are scored too, where the card shows without scrolling
  (`SettingsChainsTests`, and `SettingsOnHomeTests` with
  `--check-in-due`; untested in the app until CI runs that change):
  once the card is answered, the first step Set Up Step by Step opens
  on that visit starts its answers below where the card's rows were,
  so on CI's windows its first screenful shows no answer. Go Through
  Setup Again's step takes the place the button showed in as it was
  chosen, however far Family Setup had scrolled, as the Library's
  questions do, and the model scores it scrolled; Set Up Step by Step
  still takes its row's place in the content, so with Family Setup
  scrolled a look can rest elsewhere on its step, and whether it
  should follow Go Through Setup Again is the next Settings thread's to
  decide ([`log/2026-11-12-check-in-card.md`](log/2026-11-12-check-in-card.md);
  docs/DECISIONS.md, "The first step's own rows", *Where Go Through
  Setup Again showed, scrolled or not*). On narrow or short windows at large text
  sizes the first step's first screenful shows no answer, so a family
  scrolls to answer. On a phone the second step's first screenful shows
  only the choices that can sit under its words without meeting a look
  on Next (Every Category and the first category on the iPhone 17 at the
  default size, none at AX3 and larger, where the words fill it), and
  the rest start below the bar, past a gap, where the family scrolls to
  them. On short, very wide windows (wider than about 1300
  points and at most 667 tall, at the default text size), Home's
  Settings lies as near Back to Talking as the row, as before. If
  Settings' first screen has been scrolled when its row is chosen,
  which only happens where its content is taller than the screen, Set
  Up Step by Step takes the row's place in the content, not on the
  screen; placing it from the scroll position would make a place depend
  on what the person did (invariant 8). The 2026-10-26 Mac check measured
  matching unscrolled AX3 row frames in light and dark, in both iPad
  orientations and phone portrait. On the phone at AX5, a 90pt root scroll
  reproduced the gap: the old row centre became empty space on Family
  Setup. Physical held-look checks remain unverified; the
  [record includes screenshots and a mounted-device procedure](log/2026-10-26-settings-simulator-checks.md).
  *(a device check, then the next Settings thread)*
  Not scored yet: the chain through iOS's Personal Voice question once
  the Ask button shows (after answering, the look rests where the
  question's button was, over whatever Voice Settings has there); Voice
  Settings itself, where a look held after Family Setup's Voice Settings
  row can rest over choices that play a sample and set a voice or a
  speed; resting over the check-in card's own words; Family Setup
  scrolled before a row other than Go Through Setup Again is chosen,
  the card's other rows on the phone at the largest text size included,
  where the card lies below the first screenful; the first step's guide
  scrolled; and Settings' other screens.
  Since 2026-10-30, answers change Home's sizes as Settings closes;
  Settings' first screens over a larger Home are scored
  (`ProfileChoiceTests`), and `HomeSizesTests` audits them over the
  larger Home a person's first launch has (passed on CI, #70);
  the screens above are not
  ([`log/2026-10-21-settings-and-first-run.md`](log/2026-10-21-settings-and-first-run.md),
  follow-up 10). *(Settings' other screens: a new thread)*
- CI compiles only the Debug configuration. Warnings are errors in
  Release too, and code under `#if DEBUG` compiles differently there, so
  a warning only Release sees would first stop an archive. The Release
  build for a device compiled unsigned on the owner's Mac on 2026-11-05,
  with no warnings ([`log/2026-11-05-phrases-named-like-controls.md`](log/2026-11-05-phrases-named-like-controls.md)).
  Before the first archive, run
  `scripts/test.sh device -configuration Release` on
  the Mac again ([`log/2026-10-23-warnings-as-errors.md`](log/2026-10-23-warnings-as-errors.md)).
  *(the owner's Mac, or an agent on it)*
- English only. `scripts/test.sh unit` brings the String Catalog up to
  date (xcodebuild alone does not), and CI fails when the committed one
  is stale. The voice sample sentence in `SpeechService` is not in it
  yet (Voice Settings no longer shows `SpeechRateSteps`' rate names). *(Test seams and CI evidence)*
- No off-main test reaches the real KVO closure (the volume handler is
  called directly). The synthesizer and tone-player delegates, the
  Personal Voice answer (the closure handed to the system, built by
  `SystemPersonalVoice.forwardingAnswer`, and the answer awaited through
  `SpeechService`) and a session notice are tested from a background
  thread, and the voice list is tested to be read away from the main
  thread (docs/LESSONS.md). *(R0, item 4)*
- The audio session stays active after speech, so other apps' audio does
  not resume by itself. This is a decision, not an oversight
  (docs/DECISIONS.md, "Background audio"); `.releaseWhenIdle` waits on a
  device check. *(owner, with a device build)*
- If SwiftData cannot create even an in-memory library, the app stops
  (`fatalError` in `PhraseLibraryStore.openForApp`). *(owner)*
- `cloudKitDatabase: .none` and the absence of an iCloud capability are
  privacy-policy promises no test pins. *(Test seams and CI evidence)*
- Personal Voice permission is still asked at first launch without
  explanation. Voice Settings' explained Ask button is built
  (docs/DECISIONS.md, "Asking for Personal Voice from Voice Settings") but
  shows only under `.fromSettings`, which waits for device check D1; a
  debug build launched with `--personal-voice=ask-from-settings` is the
  build D1 needs. If D1 passes, the switch is the first line of
  `AppAudio.personalVoiceAskPolicy(for:)` ("Personal Voice permission is
  asked at launch, for now"). *(owner, with a device build; then an
  agent)*
- Words that get longer while Voice Settings is open still push what is
  below them down: the Personal Voice card going from ready to turned
  off (docs/DECISIONS.md, "Voice Settings keeps its places while it is
  open"). When Automatic moves to another Personal Voice
  because the kept one is gone, no line says so yet
  ([`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md),
  *Follow-ups*). *(the next Settings thread)*
- Every sentence of the privacy policy describes something built since
  the Library (2026-11-05) built editing and exported backups
  (docs/APP-STORE.md, section 3, lists each sentence). The sections for recorded phrases, caregiver alerts and
  Siri and Shortcuts, which 1.0 does not ship, were deleted on 2026-10-23
  ([`log/2026-10-23-accessibility-page-and-privacy-trim.md`](log/2026-10-23-accessibility-page-and-privacy-trim.md)
  keeps their words). *(App Store readiness and ASO)*
- iPhone Duo: Wave 3 item 6 now allocates Home from typed fold and
  camera rectangles, including inactive regions, with even phrase lanes.
  In six native simulator poses, strict checks found no fold/camera
  intersection in static Home controls or geometrically cropped tiles;
  32 full AX tile/camera intersections remain off the AX5 browsing
  viewport. Clipping is not physical Snap proof. Browsing shows eight
  whole tiles at default text in all four full-screen open rotations,
  and four at AX5 (trailing content 14–82pt). Closed shows six at default
  (3pt trailing extent) and none at AX5 (249pt extent). Later bounded native Basics/light probes
  established actual top-to-bottom travel of 82pt in one wide AX5 window,
  14pt in one tall AX5 window and 8pt in the paired default pane, each
  after actual movement and aligned endpoints. These are three samples,
  not maxima for every pose/category ([measurements](evidence/2026-10-25-duo-design/measured-scroll-results.json)). The measured pane inputs produce eight/zero whole
  tiles at default/AX5 in the earlier pure pane fixtures. The later native
  paired left pane shows six/zero, with a newly returned inactive bottom
  occlusion; original active-display captures are in the implementation
  record. Other pane arrangements remain unverified. Default inner-display typing keeps the core
  controls, Clear and Put Back above the full US English keyboard;
  AX5 Type is unavailable. Settings' root Back stays within Phrases,
  but AX5 rows still intersect the fold. The original current19-case Home
  checks fail in closed/open poses (1/9 failed cases respectively).
  Native Family Setup's standard Back is trailing; its AX5 chain reaches
  Back to Talking and Get Attention. Unchanged main reproduces that exact
  path, outside the accepted first-step-only scope. The
  [native comparison](evidence/2026-10-25-duo-design/native-settings-chain-results.json)
  retains it as an open baseline failure. A [changed-window diagnostic](evidence/2026-10-25-duo-design/transition-report.md)
  finds added hazards under hypothetical pointer-coordinate maps;
  actual platform mapping is unknown, so that gate has not passed.
  PR #58's review scope is fold/camera allocation, the measured AX3
  capacity correction and the verified drag-to-speech repair; it does not
  close every Duo release gate.
  Settings/setup remain broader R0-13 work;
  no new exception is accepted. The
  [implementation record](log/2026-10-25-duo-fold-design.md) and
  [native comparison](evidence/2026-10-25-duo-design/native-frame-comparison.md)
  distinguish native measurements from the illustrative Settings model.
  The [earlier Mac record](log/2026-10-25-mac-keyboard-checks.md) preserves
  app `8316743`'s failures before PR #56. Earlier local standard UI suites
  fail the same Speaking-wait case also reproduced on main; their cause
  is unresolved and the failed suites are retained. Earlier `35bed06`
  has green hosted unit/UI checks. The AX3 growth correction
  passes 778 native unit cases and two focused light/dark probes; its
  full standard UI run completed 51 cases per family with one failed
  AX5 Speaking-wait case each. Retained typing from tall to wide
  leaves the keyboard visible on baseline and candidate; a baseline-only
  trace also reports focus false. This separate failure remains unresolved.
  Physical testing stays deferred;
  CI still has no Duo family and screenshots are required from April 2027
  (docs/DECISIONS.md, "iPhone Duo"). *(R0 item 13 / Wave 3 item 6)*
- **Open, outside PR #58:** the private AX5 capacity alternative is
  unselected and is not part of the shared app; automatic keyboard
  dismissal after a tall-to-wide Duo turn still fails; Put Back remains
  covered by the phone's AX5 keyboard. (The intermittent startup flake's
  cause was found on 2026-11-01 and fixed by #73: *Verification*.) The
  drag investigation first found a reflected XCTest coordinate and
  passing long paths; a later verified
  80pt tile-start drag proved a shared-app bug by speaking on release.
  Its cause was found on 2026-11-11: a Button speaks on lift unless the
  scroll view takes the touch over, which a fitting grid's disabled
  scroll view never did (docs/DECISIONS.md, "Phrase-grid drag
  cancellation", *Why a drag spoke*).
  The repair keeps native pan handling even when tiles fit, using the
  same standard Buttons and ScrollView with no fitting-content disable
  and `.scrollBounceBehavior(.always)`. Removing the disable alone failed.
  The recovered private AX5 source also reproduces the original gutter
  failure; only these two scroll modifiers change its light/dark result
  to passing. Its full flow/suite and capacity design remain unselected
  and unverified. [Failures, source recovery and bounded passes](log/2026-10-25-duo-fold-design.md#pr-58-continuation-and-drag-investigation-2026-10-26).
  Before the extra batch, selected runs passed all seven cases on each of
  Duo, iPad and iPhone: the five `PhraseDragTests` cases (including the
  1.5s hold, first taps and static/fitting settled frames) plus two existing
  slow-press cases, with no skips or expected failures. The pre-extra-batch
  unit gate passed 778 total: 769 passed, zero failed, one existing #19
  skip and eight strict expected failures; catalog current with `CI=true`,
  coverage 71.1% (7,026/9,875). The later pre-extra-batch hosted checks
  pass units and all 56 UI cases per family (iPad 51 passed / 0 failed /
  2 skipped / 3 expected; iPhone 48 / 0 / 6 / 2). Complete local UI on
  `4c02a0c` ran 56 per family but each failed only the old AX5 Speaking waits
  (iPad 50 / 1 / 2 / 3; iPhone 47 / 1 / 6 / 2). PR #58 is still a draft:
  the owner authorized one extra repair batch after two post-green fix
  pushes, for the missing renderer initial-region top inset and a native
  test that must prove all eight tiles fit before its unconditional
  settled-frame comparison. [Intent, Spec and Plan](work/layout-engine.md#owner-authorized-renderer-and-fitting-test-review-batch)
  preceded implementation. P1's native default-text light/dark iPad
  reproduction fails both cases with eight intended assertions: Phrases
  y40 instead of the independently expected y62 crosses a synthetic
  y52–62 band, while Settings' Back is y62. [Original images, frame JSON
  and provenance](log/2026-10-25-duo-fold-design.md#extra-batch-rendered-red-result-and-unverified-implementation)
  distinguish this fixture from an actual OS pose. The renderer now
  consumes the allocated first inset through a standard spacer; P2 now
  requires actual fit in the default light/dark native cases and compares
  their settled tiles unconditionally. The affected final-source iPad
  selection passes 10/10 without skips or expected failures; seven runtime
  audio-session diagnostics are retained. Ordinary zero-inset frames
  match exactly across 40 light/dark comparisons. A 1pt clipped-viewport
  App variant passes with the fit flags off and fails before input with
  them on, proving the guard; all 153 Swift/project-source hashes were
  restored. [Green and mutation evidence](log/2026-10-25-duo-fold-design.md#extra-batch-ipad-green-and-fitting-guard-proof).
  The affected final iPhone selection also passes 10/10 with retained
  runtime audio diagnostics. Extra-batch full units pass 781 total:
  772 passed, zero failed, one existing #19 skip and eight strict expected
  failures; catalog current under `CI=true`, coverage 71.2% (7,054/9,903).
  The final affected Duo selection passes 7/7, zero failures/skips/expected
  failures, with seven retained runtime audio warnings, on the actual
  OS-reported opposite tall open/flat window (180 degrees), without a
  synthetic reservation fixture. Coordinate and default fitting guards
  passed; all 153 source hashes match final and all three owned simulators
  are shut down. At this recorded pre-push checkpoint only new-head hosted
  CI and review resolution remain pending after the single authorized
  push; live PR checks/review state provide the subsequent result. These
  selections are not new full ordinary UI runs; no Release/device proof
  is inferred. Two Greptile conversations
  remain open, Codex review is running and security review completed with
  no reported findings at this checkpoint. The extra batch needs its own
  final-source gates; current-head PR checks govern review readiness. The recovered
  private source is preserved in ignored `build/recovered-private-source.tar.gz`,
  with all 87 restored App hashes verified inside the archive. Engine
  geometry, floors and capacity are unchanged; the renderer is corrected
  to consume those allocations. No input-profile rule or
  release exception is accepted.
- The app icon is a placeholder; `design/brand/` is not installed. *(Release chores, R0 item 11)*
- Siri's alternative name "Brick Son" (`INAlternativeAppNames`) has no
  effect yet: Apple applies it only to apps with Siri support, which
  Brickson does not have (docs/DECISIONS.md, "App identity"). *(R2 Siri
  and Shortcuts)*
- The bundle identifier contains the owner's first name and is permanent
  after the first upload. *(owner)*

## Next steps, in order

For the owner (the remaining questions are listed in docs/DECISIONS.md,
*Waiting on the owner*, and every one a release needs in
docs/ROADMAP.md, *The quality bar*, Q24):

1. Answer the few questions that are yours, in docs/DECISIONS.md,
   *Waiting on the owner*: the final name (and with it the bundle
   identifier), the price, how the name is said, and your EU trader
   status (needed before the App Store release in the EU). Before any
   build goes to the external TestFlight pilot or App Review, every
   dwell hazard in docs/ROADMAP.md, *The quality bar*, Q2 (seven today,
   plus iPhone Duo's changed-window finding) must be gone, or accepted
   by you. Six wait on your answer, once the
   Snap to Item device check (Q12) has measured them: whether Yes and No
   may border the message, the top of Stop's well nearest Again, and
   dimmed phrases bordering Clear and Put Back (*Known gaps*), and three
   your rules of 2026-11-05 put out of reach of every edit, which a
   damaged or hand-made store, or for a rest board one rare restore, can
   still show: an Emergency or a rest board already short of four
   phrases, and fewer than three everyday categories. The other
   one, iPhone Duo's chain from Family Setup at the largest text size,
   comes to you only if a thread cannot remove it by placement. So does
   the changed-window finding (a look resting
   on iPhone Duo before the window changes meets Get Attention, Speak,
   No or Clear after it), once a device has shown how the pointer really
   moves when the window changes (R0 item 13; *Known gaps*). Also before
   then: whether Get Attention goes in
   Settings' bar (docs/DECISIONS.md, "Get Attention in Settings' bar:
   the owner decides"); and, once a thread has measured them, Settings'
   floors under a larger profile (Q3). (How long you use each TestFlight
   build yourself is answered: two weeks before the pilot, seven days
   on the build sent to App Review, your choice on 2026-11-01.)
   Everything App Store Connect will ask, in order, is in
   [docs/APP-STORE.md](APP-STORE.md), section 1.
2. Read docs/ROADMAP.md, *The quality bar*: the 29 gates every release
   passes before App Review, your "would I recommend this to someone?"
   last. Each says who checks it. The ones marked owner are yours: the
   device gates on your own iPhone and iPad with the build that will
   ship, from TestFlight once the App Store Connect record exists (a
   build from step 4 lets you rehearse them but passes none), and the
   rest as written answers. The step-by-step procedure for each, with
   what passes and which steps an agent runs from your Mac, is
   [docs/DEVICE-CHECKS.md](DEVICE-CHECKS.md).
3. Run the app once yourself and hear a phrase ([local setup](GETTING_STARTED.md)).
4. Put your Team ID in `project.yml` (`DEVELOPMENT_TEAM`), then run the app
   on your iPhone and iPad and work through *Checks that need a real
   device* with [docs/DEVICE-CHECKS.md](DEVICE-CHECKS.md), starting with
   its first two sessions: Snap to Item and Dwell measured, the three
   dwell hazards and Settings by a stray dwell, then the floors. Before
   them, an agent can run Brickson's UI tests on each device from your
   Mac (its A1): plug the device in, unlock it, write "go" in the
   thread, and stay near for the device's passcode.
5. Review the starter phrases (`Brickson/Resources/StarterPhrases.json`): two
   are near duplicates, and "Please move me." could be clearer.
   Also, after each merge that changes the guard or
   `.claude/settings.json` (as #90 did), bring your main checkout up to
   date, because Mac sessions run its copy of the guard (AGENTS.md,
   *Guardrails for agents*): `git -C ~/code/brickson pull --ff-only`
   while it is on `main` with nothing uncommitted. Success: it ends
   with "Fast-forward" or "Already up to date".
6. You can delete the `xcode-skills` folder in `~/code/brickson`: its
   skills are installed where agents load them.
7. The privacy check is on main (pull request #86, merged 2026-11-08),
   with its private list on your Mac and its GitHub secret set, one
   entry each, as you decided (docs/DECISIONS.md, "Personal details
   stay out of the repository", *Avery's decision of 2026-11-08*). The
   push check in `~/code/brickson` (`git config core.hooksPath
   .githooks`, a setting of your checkout that its worktrees share)
   needs your yes before an agent there turns it on. Your choice too:
   whether cloud sessions get the list, in the project's settings. When
   the list changes, the secret must be set again; an agent on your Mac
   can do both (the same decision, its setup part). Without the secret,
   "Privacy check", and with it "Unit tests", fails on every pull
   request from a branch of this repository; one GitHub gives no
   secrets (from a fork, or Dependabot's) checks the built-in patterns
   only, and says so.
8. Done on your Mac on 2026-11-04; for another Mac: let Codex read all
   of `AGENTS.md`. By default
   it reads only the first 32 KiB, and the file is about 69 KB
   (docs/DECISIONS.md, "AGENTS.md puts first what Codex reads"). In
   Terminal, run this one line; it adds the setting at the top of
   Codex's settings file, creating the file if needed, and changes
   nothing if a line of the file already sets it, however the name is
   written (a line starting with `#` is a comment and sets nothing):
   `f=~/.codex/config.toml; mkdir -p ~/.codex; touch "$f"; command grep -Eq "^[[:space:]]*(\"project_doc_max_bytes\"|'project_doc_max_bytes'|project_doc_max_bytes)[[:space:]]*=" "$f" || { printf 'project_doc_max_bytes = 131072\n' | cat - "$f" > "$f.new" && command mv "$f.new" "$f"; }`
   Success: `command grep -n project_doc_max_bytes ~/.codex/config.toml`
   prints a line reading `1:project_doc_max_bytes = 131072` (if your
   file already set it, it prints your own line instead; any number
   larger than the file, about 69,000 bytes today, works). Codex reads
   it when a new session starts.
9. Settings for the reviewers and GitHub's machines, from 2026-11-07
   (docs/DECISIONS.md, *Code review* and *Dependencies*), once that
   pull request has merged:
   - **Install cubic** from
     [its Marketplace page](https://github.com/marketplace/cubic-ai-code-reviews):
     sign in at cubic.dev with GitHub, and give its app **Only select
     repositories**, with Brickson alone. Success: the next pull request
     gets a review from `cubic-dev-ai`.
   - **Allow only GitHub's actions (and your own):** done. GitHub's API
     showed it on 2026-11-07, with "Allow actions created by GitHub"
     ticked and nothing else.
   - **Leave CodeRabbit's "Autofix" box unticked** if its comment on a
     pull request ever shows one (`.coderabbit.yaml` removed it): it
     has CodeRabbit write commits itself, and reviewers here never
     write the code.
   - **Optional, your choice:** turn off training on your work in
     ChatGPT (Settings → Data controls → "Improve the model for
     everyone") and in Codex's own settings ("Include environments", at
     chatgpt.com/codex/cloud/settings/general), and in Greptile
     (Settings → Organization → Data & Privacy → "Help us improve
     Greptile").

For agents: no build goes to App Review until every gate of
docs/ROADMAP.md, *The quality bar*, has passed, the owner's answer last
(owner, 2026-10-30), unless the owner decides that one urgent fix goes
sooner (docs/DECISIONS.md, "Every release passes the quality bar"); a
pull request that moves a gate edits its *Today*
line. The device procedures are written
([docs/DEVICE-CHECKS.md](DEVICE-CHECKS.md), 2026-11-04): the next device
work is the owner's first two sessions there, for which a thread makes the
look-target sheet and, when the owner writes "go" with a device on the
cable, runs A1 over Remote Control; its record lists what else it
leaves ([`log/2026-11-04-device-procedures.md`](log/2026-11-04-device-procedures.md),
*Follow-ups*). R0 in [docs/ROADMAP.md](ROADMAP.md), in order; the owner's
long-term vision, the direction behind it, is its *Where this goes*.
The next pull requests, in order, with which may run side by side and
which change Home, are its
[Wave 3](ROADMAP.md#wave-3-the-next-pull-requests-in-order) (planned
2026-10-23): items 1 to 5 and 7 to 9 are built (item 8's sizes on since
2026-10-30; item 9, the late-stage profile and the rest board, on
2026-11-01, [`log/2026-11-01-late-stage-profile.md`](log/2026-11-01-late-stage-profile.md),
*Follow-ups*, and its boards of eight phrases on 2026-11-02,
[`log/2026-11-02-rest-boards-of-eight.md`](log/2026-11-02-rest-boards-of-eight.md),
*Follow-ups*), typing on Home (item 5) on
2026-10-24 ([`log/2026-10-24-typing-on-home.md`](log/2026-10-24-typing-on-home.md),
*Follow-ups*); next on Home is item 6, iPhone Duo in every pose. Its Mac
design pass has started after PR #56 merged. The continuation in
[the layout-engine work file](work/layout-engine.md#item-6-fold-and-camera-design-2026-10-25)
now uses queried fold/camera rectangles and native left/right Split View
measurements. The earlier horizontal-scrolling owner blocker is
withdrawn: the measured full-screen tall phrase viewport is below the
division. Right-pane AX5 still leaves no whole phrase tile visible.
The scoped 84-state drawings are complete, with an outward whole-point
fold allowance after a strict native overlap failure. The local engine
passed the earlier 777-case unit gate, including six test-helper
regressions and the native mode-word inset correction; `35bed06` also has
51 UI cases per standard family in a green hosted run. The AX3
correction returns only optional category growth after final lane/camera
allocation: its 778-case native unit gate and two focused light/dark
probes pass, with eight whole Basics tiles and unchanged root Back. Its
full standard UI run completed all 51 cases per family with one failed
AX5 Speaking-wait case each and no other unexpected assertion. Earlier complete and selected local
Speaking-wait failures remain recorded with cause unresolved.
The [word-floor receipt](evidence/2026-10-25-duo-design/native-mode-word-results.json)
retains that separate failing reproduction and unit gate. AX5 capacity
remains open; retained typing from tall to wide also leaves the keyboard
visible on baseline and candidate; the baseline-only trace reports focus
false. No font, spacing,
floor or placement rule changed.
Representative Duo active-display checks show the AX5 and Settings gaps;
the paired left pane shows six/zero whole tiles at default/AX5.
Changed-window diagnostics expose added paths under unverified
coordinate maps, so folding safety has not passed. PR #58's narrow
fold/camera and AX3 correction, including the drag-to-speech repair,
can be reviewed separately after its current-head checks pass; that is
not a release-readiness claim.
No new exception is accepted. Existing AX5 Settings row/fold intersections remain broader
R0-13 gaps, explicitly shown in the drawings. The
same-app second-window attempt remains inconclusive; the temporary
XCTest windowing probe skipped. Physical checks remain deferred.
Its item 2, the chain engine, is built; a change
that moves a control keeps its tests passing. Item 7 scored Get
Attention in Settings' bar, which would sound the alarm unasked, for the
owner to decide, and built a fix for the chain that saves a setup
answer, held until Back to Talking is placed over harmless controls:
item 5 placed it over Phrases, and the fix still sounds the alarm
through its guide, so it stays held for the next Settings thread
(docs/DECISIONS.md, "Typing on Home", "One chain engine for dwell
safety" and "Get Attention in Settings' bar: the owner decides"). On
2026-10-25 it placed Settings' first row from Home's frames, with Set Up
Step by Step in its frame, which ends Settings closing under a look on
CI's windows (modelled, and measured by PR #56's first CI run), except
a phone at its largest text size, where the first step's own rows are
next; on 630 swept windows (modelled) it ends the closings through
Settings' first screen and Family Setup, but the sweep does not draw
the first step
(docs/DECISIONS.md, "Settings' first row, placed from Home's frames").
On 2026-10-30 it placed the first step's own rows: Learn About Each Way
in Set Up Step by Step's frame, its guide a cover with Done in Back to
Talking's frame, the answers below every place a look can be resting,
and Next only moving on, which ends, modelled on CI's windows and on
the 630 swept ones now drawn through the first step, both the closing
on the phone at its largest size and every held look that saved a
setup answer; untested until CI runs it (docs/DECISIONS.md, "The first
step's own rows").
Every change follows AGENTS.md, *Apple's current frameworks first*: the
legacy uses kept, and the moves still planned with who owns each, are in
docs/DECISIONS.md under that title
([`log/2026-10-23-current-frameworks.md`](log/2026-10-23-current-frameworks.md)).
The library core landed with PR #14, and the launch repair that keeps
Emergency working after it; the Library's screens, export and restore
landed on 2026-11-05 ([`log/2026-11-05-library-screen.md`](log/2026-11-05-library-screen.md),
*Follow-ups*, whose first two, the short category and phrases named like
Home's controls, are built:
[`log/2026-11-05-four-phrases.md`](log/2026-11-05-four-phrases.md) and
[`log/2026-11-05-phrases-named-like-controls.md`](log/2026-11-05-phrases-named-like-controls.md),
and so is its library already outside the bounds, which no edit now
takes farther out:
[`log/2026-11-12-no-farther-out.md`](log/2026-11-12-no-farther-out.md)).
The rollback probe was run on 2026-11-05 (*Known gaps*). What is left from the *Follow-ups* in
[`log/2026-10-23-emergency-repair.md`](log/2026-10-23-emergency-repair.md)
is, in order, stores from every
schema version and safety copies, each a pull request of its own. Calls (R0 item 8) wait for a device build. Files under
`.github/workflows` are committed by the owner (docs/SDLC.md, *Deploy*). The toolchain's follow-ups
(Xcode's recommended settings, iOS 27 APIs behind `#available`) are in
[`log/2026-10-21-toolchain.md`](log/2026-10-21-toolchain.md). Xcode's
JSON project format is planned, not adopted: the owner's 2026-10-25
handoff requires released Xcode 27.2 and its first fix release before
the trial on the owner's Mac starts. The first half is met: Apple
released 27.2 on 2026-10-29 and the owner's Mac has it; the trial starts
when 27.2's first fix release (27.2.1 or 27.3) is out. XcodeGen stays until the gates hold (docs/DECISIONS.md, "Xcode's
JSON project format"). iPhone
Duo is R0 item 13: the earlier closed/open/partly folded/rotated failures
remain in the [Mac record](log/2026-10-25-mac-keyboard-checks.md); item 6's
[reserved-region implementation](log/2026-10-25-duo-fold-design.md) adds
native geometry and unit evidence while broader Settings/setup, windowing
and physical checks remain open.
PR #56 has cleared the owner's alarm-path merge prerequisite for Wave 3
item 6; its implementation now uses these measured spaces
([`log/2026-10-23-iphone-duo-readiness.md`](log/2026-10-23-iphone-duo-readiness.md), *Follow-ups*);
recheck the minimum iOS against its two rules whenever Apple's next major
release drops devices (docs/DECISIONS.md, "Minimum iOS, iPhone and
iPad").
Get Attention and Stop are on Home; what is left of that work (Settings'
Get Attention, the real tone, the windows that now scroll) is in
[`log/2026-10-23-get-attention-on-home.md`](log/2026-10-23-get-attention-on-home.md),
*Follow-ups*, and the rest of the speech work's list in
[`log/2026-10-21-speech-and-get-attention.md`](log/2026-10-21-speech-and-get-attention.md). Voice Settings' explained Ask button is built; switching the app to
asking from Settings waits for device check D1, and what the Voice
screen still lacks is in
[`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md),
*Follow-ups*.
Every accessibility API in the map of Apple features by ALS stage has a
row in [`ACCESSIBILITY.md`](ACCESSIBILITY.md), with its release and
roadmap item; what each R0 item picks up from it, in order, is in
[`log/2026-10-21-accessibility-coverage.md`](log/2026-10-21-accessibility-coverage.md),
*Follow-ups*. Item 3's scan order, regions and Voice Control names are
done, and so is Home's border under Show Borders, drawn in dark mode
with the setting off too since 2026-11-02 (pull request #74); the Large Content
Viewer stays off Home's controls other than Settings' gear, because on
simulators a slow press with it spoke nothing (docs/DECISIONS.md, "Show
Borders and the Large Content Viewer on Home";
[`log/2026-10-23-large-content-and-iphone-duo.md`](log/2026-10-23-large-content-and-iphone-duo.md)).
What is left of item 3's list, in order, is in
[`log/2026-10-23-show-borders-and-large-content.md`](log/2026-10-23-show-borders-and-large-content.md),
*Follow-ups*, except the Large Content Viewer in its item 5, now settled.
The layout engine, Wave 3's item 3 in [docs/ROADMAP.md](ROADMAP.md), is
built, and Home is on it (item 4; docs/work/layout-engine.md and
[`log/2026-10-24-home-on-the-layout-engine.md`](log/2026-10-24-home-on-the-layout-engine.md),
*Follow-ups*); item 5, typing, brought the slot plan's Phrases and
Type and its one-row C ([`log/2026-10-24-typing-on-home.md`](log/2026-10-24-typing-on-home.md));
input profiles came with item 8 (2026-10-30,
[`log/2026-10-30-sizes-that-follow-reach.md`](log/2026-10-30-sizes-that-follow-reach.md);
switched on the same day, [`log/2026-10-30-sizes-switched-on.md`](log/2026-10-30-sizes-switched-on.md)), and the late-stage profile with the rest board with item 9 (2026-11-01), both before R0's first
App Review build (owner, 2026-10-30); the phone on its side waits until
that build has gone to App Review. The earlier order is in
[`log/2026-10-21-phone-layout.md`](log/2026-10-21-phone-layout.md).

## Checks that need a real device

Simulators cannot show these. Each row's step-by-step procedure, with
what passes and who runs each step, is in
[docs/DEVICE-CHECKS.md](DEVICE-CHECKS.md), whose *Coverage* maps every
row. Record each result in a `docs/log/` file (device, OS version,
settings, date) and summarise it here.

| Check | What it decides |
|---|---|
| Speech plays with the silent switch on, and after a phone call | Audio session handling (invariant 4) |
| A phrase cut off by a call shows "Stopped, Again" | The cut-off rule (code audit M1) |
| D1: with no question at launch, a Personal Voice allowed after a phrase has been spoken speaks in the next phrase, after a voice-list refresh, a rebuilt synthesizer or only a relaunch (docs/recon/2026-10-15/directions/onboarding-and-settings.md, 2.5). Run from Xcode with `--personal-voice=ask-from-settings` added to the scheme's arguments (Product > Scheme > Edit Scheme > Run > Arguments), and ask with Voice Settings' Ask to Use Personal Voice | Whether the app may switch to `PersonalVoiceAskPolicy.fromSettings` (docs/DECISIONS.md, "Personal Voice permission is asked at launch, for now") |
| In the same run: iOS's question appears over Voice Settings, which is still there after a wait of over 90 seconds; after Allow or Don't Allow the card shows the answer, "Answered. …" sits where the button was, nothing below the card moved, and Open Personal Voice Settings appears only after leaving and reopening Voice Settings | "Asking for Personal Voice from Voice Settings" |
| D4: Personal Voice access turned off in the Settings app while Brickson waits in the background; on return a phrase speaks in another voice, and turning access back on brings the Personal Voice back | "A Personal Voice is used only while it is allowed" |
| Restart the device, then open Brickson at once: Home appears without waiting; a phrase chosen straight away speaks at once (in the system's voice if the voice list has not arrived); how long the list takes; the first phrase after it is in the chosen voice or Personal Voice; whether that first phrase itself waits | "The voice list never holds up launch" |
| D5: with two Personal Voices, the order the system lists them in, and whether each keeps its identifier across a relaunch, a restore and Share Across Devices | "Automatic keeps the person's Personal Voice" |
| Personal Voice appears and is chosen once permission is given, and keeps speaking after the screen locks | Voice choice and when to ask |
| Opening Settings by a stray dwell, and leaving it by Back to Talking, lands on nothing that speaks or alarms (`SettingsOnHomeTests` scores it on the simulator's frames); the idle reset under real dwell. Physical iPad and iPhone checks remain unverified; use the [2026-10-26 mounted-device procedure](log/2026-10-26-settings-simulator-checks.md#environment-and-settings-for-the-physical-run), including the phone at AX5. | Settings' safety bar and root (docs/DECISIONS.md, "Settings is a cover with a fixed safety bar") |
| Each Family Setup guide's steps match the device, on iOS 26 and iOS 27, iPhone, iPad and (Live Speech) Apple Watch, and Brickson works inside Guided Access and Assistive Access | Family Setup's guides ([`log/2026-10-23-apples-doors-in-family-setup.md`](log/2026-10-23-apples-doors-in-family-setup.md)) |
| Open Personal Voice Settings and Open Dwell Control Settings open the right page | `AccessibilitySettings.openSettings(for:)` |
| Each input method reaches every control: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking, Eye Tracking | That standard buttons are the whole integration (invariant 1) |
| A Switch Control double activation does not make a phrase stutter | Repeat absorption (invariant 10) |
| How far Snap to Item jumps, and whether the pointer stays on an activated control or follows the gaze | Spacing and placement for dwell profiles, and which of the chain engine's findings bind: it scores both pointers at any distance, and "Settings closes under the look" needs the pointer to follow the gaze (docs/DECISIONS.md, "One chain engine for dwell safety") |
| Whether Snap to Item and Dwell pick a target by its nearest centre or its nearest edge, and which control a look resting on the message selects | What removes "Yes and No border the message" (docs/DECISIONS.md, "Settings on Home"), and "the top of Stop's well is nearest Again" ("Get Attention and Stop on Home") |
| Whether a lingering look re-fires a dwell | How much repeat protection matters |
| Whether Snap to Item ignores controls scrolled off screen, or wholly under the navigation bar | Whether scrolling can keep family controls out of reach, and whether the chain engine may keep scoring only the controls in the window and leave out a Library row the bar covers |
| What the real software keyboard covers in each orientation (CI measures the simulator's on every UI run; a device, other languages and windowed iPads are not measured), that a third-party keyboard never appears in Brickson, and typing checks 1–8 in [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md) | `KeyboardAllowance`'s references, the typing layout (docs/LESSONS.md, "Test with the real software keyboard"), the word row, Return under dwell, and whether Brickson needs its own keyboard |
| Typing on Home by touch, Switch Control, Voice Control ("Tap Type"), Full Keyboard Access and Dwell with Snap to Item: Type brings the cursor and Apple's keyboard at once; Speak and Return say the message; Clear, then Put Back; Phrases puts the keyboard away and keeps the message; a look slipping off the keyboard's top row meets nothing that speaks or changes the message; Snap to Item stops on the dimmed phrase tiles and categories while typing; and, on an iPhone SE with Display Zoom and at AX3 without it, where Type is dimmed, whether the real keyboard would cover Speak or Get Attention | docs/DECISIONS.md, "Typing on Home" (*The keyboard's room, measured*; *Open: by centre, dimmed phrases border Clear and Put Back*) and "Return speaks" |
| Get Attention heard from the next room, on the speaker and over Bluetooth | The alarm's sound and level, and the replacement tone |
| A phrase spoken while Get Attention sounds is understood over the tone at 0.32 | `AttentionAlertStatus.toneVolumeWhileSpeaking` |
| A phone call, Siri and another app's alarm during a phrase and during Get Attention: each stops and shows "Stopped — Again" or "Alert stopped", and nothing restarts by itself, on iOS 26 and iOS 27 | Interruption handling and the iOS 27 notices (docs/DECISIONS.md, "Audio session notices") |
| Lock the device during a long phrase and while Get Attention sounds: both carry on | Background audio, before the App Review notes promise it |
| Get Attention from Home's own control, by touch, Dwell with Snap to Item, Switch Control and Voice Control ("Tap Help"): it sounds with the silent switch on; a look held on Get Attention never stops it; a look still resting where Stop was after Stop meets a category; with Switch Control's Auto Tap, where the cursor goes once Stop's element leaves | "Get Attention and Stop on Home" (`GetAttentionOnHomeTests` scores the simulator's frames) |
| Whether a voice reports its final word before finishing, and whether the system reports a cut-off phrase as finished | How often "A phrase the system cuts off" relies on its 3-second window |
| Unplugging headphones during a phrase and during Get Attention | Output loss: speech carries on, the alarm stops and says so |
| Whether the tone player ever reads as not playing for a moment while it plays (route changes, Bluetooth) | Whether the once-a-second health check needs a second look before stopping the alarm |
| Comfortable dwell time and movement tolerance | Setup recommendations per profile |
| Each profile's floors on an iPad with a person using Eye Tracking, Head Tracking and Switch Control's point scanning, at the default text size and AX3, and the rest board's late-stage sizes with Eye Tracking | Whether the switch and head floors proposed in docs/DECISIONS.md, "Sizes that follow how the screen is reached", and the late stage's floors and 4-degree growth proposed in "The late-stage profile", hold, before the larger sizes reach App Review |
| Whether Guided Access works together with Eye Tracking | Setup recommendations |
| Which phrases people reach for, and how many categories can be scanned by eye | The starter library |
| "Open Brickson" by Siri and Voice Control, said by a few people, and how VoiceOver reads the icon | `APP_SPOKEN_NAME` and the alternative names |
| With VoiceOver on, a cut-off phrase or very low volume is announced once, in full, without moving focus | Home's audio announcements (invariant 4) |
| A volume change made while Brickson was in the background shows when it returns | The volume warning (code audit L2) |
| Buttons under Increase Contrast and Reduce Transparency, measured on the rendered pixels | Contrast of system components (invariant 6) |
| The screen never dims or locks during a long session | `ScreenWakePolicy` (invariant 12) |
| On a folding iPhone, open, partially folded and closed, and in Stage Manager, Slide Over and iPhone Mirroring windows: nothing safety-critical is hidden or split, nothing a person uses sits in the fold, Dwell keeps working as the phone folds and unfolds, Eye Tracking and Head Tracking (which Apple says work only fully open) come back when it opens fully with nothing moved, and whether the inner camera's reserved region covers the area that goes dark while either is on (the iPhone Duo simulator shows the layout first: R0 item 13; Wave 3 item 6) | Layouts from the space available; docs/DECISIONS.md, "iPhone Duo" |
| On an iPad with Brickson in a window you can resize (Stage Manager), with Eye Tracking and with AssistiveTouch Dwell, each with Snap to Item on: drag the window's edge across the width where Home switches between three and five columns, and record where the pointer is during and after the resize, whether it stays put or follows the gaze, and what it would activate when it comes to rest | Whether the chain engine needs a surface for iPad windows that change, and which pointer it scores (*Known gaps*; docs/ROADMAP.md, *The quality bar*, Q10) |
| Eye Tracking and Dwell on an external display | Whether gaze profiles hold off the built-in screen |
| Switch Control with Auto Scanning, Group Items on and off, and Auto Tap: the scan steps to Emergency, Yes and No from every Home state, and whether Home's regions become scan groups | Scan order and grouping (docs/ACCESSIBILITY.md, section 1) |
| With VoiceOver, Switch Control (item and group scanning) and Full Keyboard Access, Home is reached as Yes, No, Emergency, Get Attention, Again, then the message, Phrases and Type, Stop while it shows, the categories and Settings, the phrases, in every state; what each says on entering a region; whether the cursor stops on the message or the status line; Voice Control's "Show names" shows each control's visible words and "Tap Repeat" presses Again | "Home's scan order and names": the order, unlabelled regions, and whether `accessibilityRespondsToUserInteraction` is needed |
| With VoiceOver on, a phrase tile with and without the `startsMediaSession` trait: does VoiceOver stay quiet while the phrase speaks | Whether phrase tiles carry the trait (R0 item 4) |
| Brickson inside Assistive Access with `UISupportsFullScreenInAssistiveAccess`: its window size (all the space above the Back button), whether Eye Tracking and Switch Control work there, and that the guides show no Open … Settings button and say to leave Assistive Access first | Assistive Access support (R0 item 7; Wave 3 item 1) |
| Guided Access with each input method, and with a short Display Auto-Lock while Brickson keeps the screen awake | Setup advice, and invariant 12 under Guided Access |
| Which of the VoiceOver, Switch Control and AssistiveTouch flags each input method turns on | Profile suggestions (R1) |
| With a real finger at an accessibility text size, in the shipped build: press Yes slowly (about half a second) and lift, then a phrase tile; then hold Yes, slide onto No and lift, and hold a phrase tile, slide onto the next and lift; where every phrase fits, press a phrase tile, slide up about a finger's width and lift, then press one and slide sideways on it and lift (docs/DECISIONS.md, "Phrase-grid drag cancellation"); also with Touch Accommodations' Hold Duration on, and with AssistiveTouch Dwell. Each press speaks; a slide says the control it began on or nothing, never the next; the slide up says nothing, and the sideways slide says its phrase. In a window where Settings shows its gear alone (iPhone Duo's outer display with Bold Text on is one; [`log/2026-10-23-settings-on-home.md`](log/2026-10-23-settings-on-home.md)): tap the gear (Settings opens); hold it until its large copy shows and lift, and record whether Settings opened (opening means a real finger is not swallowed as XCTest's touch was); hold it and slide onto each control beside, above and below it, and lift: Settings opens or nothing happens, never anything else; dwell on it; and press Yes and a phrase tile slowly there: each speaks. The simulator results these confirm are in [`log/2026-10-23-large-content-and-iphone-duo.md`](log/2026-10-23-large-content-and-iphone-duo.md) | That Home speaks on a slow real press and a slide never says the next control; from the gear, whether a real finger's held press is swallowed as XCTest's was, and whether the gear keeps the viewer (docs/DECISIONS.md, "Show Borders and the Large Content Viewer on Home") |
| Show Borders on, in light and dark, with and without Increase Contrast, and Show Borders off in dark: every Home control shows its border, a press thickens it, a selected category and Emergency show their inner ring, measured on the rendered pixels; Settings' system buttons show theirs | "Show Borders and the Large Content Viewer on Home"; Show Borders on Settings and setup |
| In the build that ships: the time from an activation completing to a phrase's first sound, read frame by frame from a screen recording with sound, as the median of ten activations each for the default voice and a Personal Voice | docs/ROADMAP.md, *The quality bar*, Q6 (the default voice's median within half a second) |
| A cold launch's time to first frame with Instruments' App Launch template on the oldest device at hand (within 400 ms); Brickson reopening on Home with the typed message after the system ended it in the background; no flash at launch before Home, in light or dark mode | Q7 |
| 100 activations with the Hangs instrument at 100 ms on the oldest device at hand, and the device's Hang Detection (Settings > Developer > Hang Detection, at its shortest threshold) on through the TestFlight period; a thread reads the crash reports in Xcode's Crashes organizer and the crash feedback testers send through that period, and every crash and hang found is fixed | Q5 |
| Eight hours on the iPad with Brickson in front under Guided Access, and four on the iPhone, unplugged, with a Performance Trace in Power Profiler mode: the screen never dims or locks, everything works at the end, battery used per hour at touch's and Eye Tracking's setup, and no `EXC_RESOURCE` or `JetsamEvent` report for Brickson in Analytics Data; then, attached to Xcode on the Mac, memory out of the gauge's warning region with no growth across 100 phrases, and the thermal state never serious | Q8 |
| Two hours each on the mounted iPad with Eye Tracking and Dwell with Snap to Item, Head Tracking with Dwell, Switch Control's auto scanning and its Gliding Cursor (point scanning), and half an hour each on the iPhone with Switch Control and Eye Tracking, following Q11's script: every activation not meant and where the pointer rested before it, activations per common task, recalibrations and rests | Q11, and invariant 10 over hours rather than one activation |
| Export a Backup to Files, iCloud Drive, AirDrop and Mail, and restore it on the other device from iCloud Drive and the Files app; a `.json` file that is not a backup is refused; the share sheet left open past Settings' idle time changes nothing | The Library's backups (docs/DECISIONS.md, "Exporting and restoring a backup") |
| With a phrase saved as "Again", or a restored "Help", "Yes" or category named "Yes": what Voice Control does on "Tap Again", "Tap Help" and "Tap Yes", with Flexible Item Names off and on, on "Tap Help" and "Tap Yes" while typing, that with only "Help me." and "Yes, please." showing each takes one command, and that "Tap Get Attention" still sounds the alarm at once | docs/DECISIONS.md, "Phrases named like Home's controls" |
| Editing phrases and categories with Voice Control (pictures by name), Switch Control, Full Keyboard Access and Dwell with Snap to Item; a look held on Delete for Good, and resting under the lowest asking rows; and a look resting on a category dimmed on Home for having fewer than four phrases | The Library's question screens; docs/DECISIONS.md, "Four phrases in every category" |

## Repository, CI and website

- The `main` ruleset matched docs/DECISIONS.md on 2026-10-15 (GitHub's
  API); its required checks are "Unit tests" and "UI tests".
  The unit job allows 60 minutes. The UI job allowed 120 for both
  device families and took about 105; since 2026-11-03 each family has
  a job of its own with 90 minutes, and "UI tests" is a job that passes
  only when both passed (docs/DECISIONS.md, "Tests"). Four iPad
  runs in a row stalled because iOS's lock-screen wallpaper prewarm
  starved the simulator; since then
  `scripts/test.sh` pauses those extensions on a simulator it started
  and writes `simulator-load-<family>.txt` beside each result bundle:
  read it first if a stall comes back
  ([`log/2026-11-03-ui-test-stall.md`](log/2026-11-03-ui-test-stall.md)).
  Since 2026-11-04 the watcher reads processes with the Mac's own calls,
  never `ps`, which a starved Mac left it blind to for minutes, and
  while pausing it looks for new extension instances every second: iOS
  starts new ones during the prewarm even with the first ones paused (49
  on the iPhone in the probe run, where one test's 10 s wait ran out
  inside that burst). Each "paused" line says what the instance had
  used
  ([`log/2026-11-04-watcher-without-ps.md`](log/2026-11-04-watcher-without-ps.md)). Home's
  layout test uses bounded live queries while retaining every tile's
  visibility and position checks. After incorporating `main` at `d79d836`,
  its audit helper also keeps issue-time captures and native XCTest
  findings. CI reported an unidentified AX5/light text-accessibility
  finding; the unchanged focused local test passed, but no cause is
  established. A temporary contrast defect failed as expected and retained
  issue-time and native evidence; its app mutation was removed. Final
  units passed 460/460; iPad and iPhone UI each passed 33 tests with four
  existing probe skips on the tree incorporating `d79d836`. A further
  merge incorporates `main` at `479175d` (PR #31): its still-screen waits
  and two runner tests remain alongside the diagnostic captures and native
  findings. Its unit gate passed 460/460 with the catalog unchanged;
  both combined UI suites completed with 34 passed, one failed and four
  existing skips per device. The AX5 light/dark Speaking waits failed,
  with the status visibly still present and CoreAudio startup errors in
  the iPad app logs. Focused local checks reproduced the known host-audio
  limitation. Exact-head CI on `f1f7954` passed 460 units and 35 enabled UI
  tests per device (four existing probe skips); the owner merged PR #32
  as `313de2c`. No host audio service or setting was changed.
  Earlier-head CI also failed, with its native audit evidence now retained
  ([`log/2026-10-22-ci-home-test.md`](log/2026-10-22-ci-home-test.md)).
- The unit job took 36 to 39 minutes on 2026-10-30 under its old
  limit of 40; the dwell chain sweeps were most of it. The chain engine
  now costs about half as much with the same results: the job's next
  two runs took 24.4 and 28.2 minutes, and the limit is 60
  ([record](log/2026-10-30-unit-test-time.md)). The Settings sweep's
  remaining cost was `SetupAnswersPlace`; since 2026-11-05 it halves and
  reads a frame across the answers' width by its corners, with the same
  results on the tests' shapes and within a hair of rounding on thirds
  of a point ([record](log/2026-11-05-library-screen.md)).
- CodeQL scans the workflow files and the Python scripts, not the Swift
  code, on purpose (docs/DECISIONS.md, *Code scanning*); the failed Swift
  attempt of 2026-10-10 was deleted from the Tool status page on 2026-11-08.
  The root [SECURITY.md](../SECURITY.md) gives Codex Security context for
  the app, tooling and website from the existing rules and decisions;
  [.github/SECURITY.md](../.github/SECURITY.md) remains the private-reporting
  policy. This is review context, not evidence of a completed scan
  ([record](log/2026-11-08-security-policy.md)).
- Since 2026-11-07 no checkout keeps the job's token, and a "Dependency
  review" job on every pull request fails one that brings in an action
  with a known security advisory; it is not a required check
  (docs/DECISIONS.md, *Dependencies*). `.github/workflows/actions.lock`
  now holds the commit of every action the workflows run, and a
  "Verify lockfile" job checks it on every pull request, also not a
  required check. A pull request that adds a workflow or changes a
  `uses:` line runs `gh actions-lock` on the owner's Mac (AGENTS.md,
  *Gotchas*; [record](log/2026-11-07-workflow-lockfile.md)).
- Open PR pushes now follow AGENTS.md, "Pushing to an open PR": [rule and verification](log/2026-10-23-open-pr-push-policy.md).
- The docs cross-reference check reads every title a citation names,
  quoted titles starting with a small letter and titles after the first
  included: [record](log/2026-10-23-docs-check-gaps.md).
- Codex reviews every push to a pull request; Copilot reviews a pull
  request that changes code once, when the agent asks right after
  opening it, its local Codex review answered (since 2026-11-08; AI
  Scan is off since that day);
  Greptile reviews when a pull request opens, as far as its free plan's
  credits allow; cubic, once the owner installs its app, reviews when
  one opens and after each push; CodeRabbit reviews only when a comment
  asks, `@coderabbitai review`, since the owner's trial ended. Since
  2026-11-07 each one's settings are in the repository
  (`.coderabbit.yaml`, `cubic.yaml`, `.greptile/`), with every feature
  that writes code and has a setting turned off, and AGENTS.md's rule
  holds the rest (docs/DECISIONS.md, *Code review*).
  None reviews Dependabot's pull requests by itself. The AI credits
  Copilot's reviews use show only in Settings → Billing → AI usage;
  the owner budgets 35 to 50 reviews a month (docs/DECISIONS.md,
  *Code review*).
- The [website](https://middleagedbanana.github.io/Brickson/), its
  [privacy policy](https://middleagedbanana.github.io/Brickson/privacy/)
  (Effective October 24, 2026, since typing came to Home; the page since PR #40) and its
  [accessibility page](https://middleagedbanana.github.io/Brickson/accessibility/)
  (since PR #40; the App Store's Accessibility URL, updated 2026-10-27 for
  current Home, Settings and simulator checks, with Largest Text layout fixes
  and a Safari VoiceOver walk on iOS 27.0:
  [`log/2026-10-27-website-review.md`](log/2026-10-27-website-review.md)) publish after each
  merge; on 2026-10-15 the first two matched `site/` byte for byte. The
  support page's "in development" lines change at release, and the
  accessibility page changes with every device check and every row of
  `docs/ACCESSIBILITY.md` that changes what it says.
- On the owner's Mac, Antigravity's only Brickson folder is
  `~/code/brickson-antigravity`, and since 2026-11-08 local, git-ignored
  hooks hold Antigravity and Codex to what the guard below refuses
  (Codex not for input typed into a command already running). Since #91
  merged (2026-11-08), a thread on the Mac hands them a job and reads the
  result with `scripts/agent-bridge.py`
  ([`log/2026-11-08-codex-antigravity-setup.md`](log/2026-11-08-codex-antigravity-setup.md)).
  Its jobs cannot push by mistake, but that is a guard, not a sandbox: an
  agent that unsets the job's no-push settings can still push, and
  isolation outside the agent is not built
  ([record](log/2026-11-08-agent-bridge.md), *Known limits*). Since #99,
  an agy job runs only with agy's hook exactly as installed, and if the
  job changes the hook, the bridge puts it back and the job fails; the
  guard's own code in agy's folder is not put back
  ([record](log/2026-11-12-bridge-safety-gaps.md)). A Codex write job
  cannot commit yet: Codex keeps a worktree's git folder read-only in its
  sandbox on purpose, and `--add-dir` does not change that (found on the
  Mac on 2026-11-12); the next bridge pull request settles how its work
  gets committed (same record, *Follow-ups*).
  Jules, Google's cloud coding agent, is no longer one of Brickson's
  agents: Google made it read-only after 2026-11-11 and shuts it down on
  2026-12-31, so the documents no longer name it, and no other agent
  took over a role of its
  ([record](log/2026-11-12-jules-wind-down.md)).
- Claude Code sessions with one repository run a guard before Bash and
  the selected GitHub tools named in `.claude/settings.json`
  (`.claude/hooks/guard.py`; AGENTS.md, *Guardrails for agents*). Repository
  hooks are not loaded in multi-repository cloud sessions, and on
  2026-11-03 they were not loaded in a Brickson cloud thread with only
  this repository cloned (AGENTS.md, *Guardrails for agents*). The guard
  refuses `git add -A`, force pushes, pushes to `main`, merges, approvals
  and Copilot reviews and tasks asked for by a Copilot tool, `gh`, the
  REST API, a GitHub tool's reviewer or assignee field or a GraphQL agent
  assignment, except one review per pull request through
  `request_copilot_review`, which it records after it runs; an
  `@copilot` mention and other GraphQL requests are held by AGENTS.md
  alone. It also refuses a commit or a post that holds a
  personal detail, a push from a checkout whose pushes skip the privacy
  hook or whose branch has none, and a command or file tool that names
  the private list or the config folder that holds it.
  The privacy check (`scripts/privacy-check.py`) runs in git's pre-push
  hook, in the guard, by hand and in CI's "Privacy check" job, which
  "Unit tests" waits for (docs/DECISIONS.md,
  "Personal details stay out of the repository";
  [`log/2026-11-07-privacy-check.md`](log/2026-11-07-privacy-check.md)).
  Its six follow-ups from #86's last review are closed: RTF formatting,
  a block in minified HTML, and a PDF line of level text no longer hide a
  list word (text a PDF rotates still can, when it is shown in pieces
  after other text), an XMP place near zero degrees is found, and the
  guard reads HTTPie's standalone `@file` body and refuses
  `gh pr create --fill`
  ([`log/2026-11-08-privacy-check-follow-ups.md`](log/2026-11-08-privacy-check-follow-ups.md)).
  Next for agents, in a pull request of its own: trim AGENTS.md (81 KB)
  without losing a rule, with a snapshot in `docs/archive/` first, moving
  long reference material (much of *Gotchas*, the Mac route under
  *Build and test*) into a document it points to, and bringing the
  sections Codex must read (32 KB today, under the 32 KiB it reads) to
  within the first 24,000 bytes, where Antigravity stops reading rule
  files (the coordinator's target, 2026-11-08).
  `scripts/test.sh` runs the guard's tests, the docs cross-reference
  check (`scripts/test-docs.py`) and the privacy check's tests
  (`scripts/test-privacy.py`) before the unit tests.
  New issues start from the "Something went wrong" form; blank issues are
  off. Record: [`docs/log/2026-10-21-agent-guardrails.md`](log/2026-10-21-agent-guardrails.md).
  The review fixes cover configured and wildcard pushes, alternate Git
  repositories, wrapper arguments, failed directory changes, attached
  approval/Copilot options, API payload files and unquoted backtick
  commands spanning several words. Later review fixes cover `env` directory
  options, API URL fragments, all-tree commit pathspecs, repository syncs
  and Copilot task aliases; the docs checker also validates reference links.
  AGENTS.md also records
  the owner's shared workflow habits for session context, merge commits,
  attribution and testing before batched pushes. The reconciled branch's
  local unit gate passed 460 tests with no failures or skips on an iPad Pro
  13-inch (M5), iOS 27.0, using Xcode 27.1 (27A9275); the String Catalog
  was unchanged. Full UI suites on that iPad and an iPhone 17 each passed
  33 tests, with no failures and four unchanged opt-in keyboard-probe skips.
  The interrupted iPhone setup was resumed as a complete family run.
  Merge `4415827` incorporates documentation-only `d79d836`; its fresh
  unit gate passed all 460 tests, with the same app and test sources. CI on
  `7d6b3e1` passed units and the iPhone UI suite but hit an iPad
  app-termination failure. Both result bundles were retained; current-head
  green CI remains required. The later guard/parser and coverage wording
  corrections passed a fresh native unit gate: all 460 unit tests, 41 hook
  tests and 16 documentation tests passed; the catalog stayed unchanged.
  A later blockquoted-reference correction also passed a fresh native
  gate: 460 unit, 41 hook and 18 documentation tests, unchanged catalog.
  Main's `479175d` audit-timing fix is now included without conflicts;
  its fresh gate passed 460 unit, 41 hook and 18 docs tests, with the
  catalog unchanged. Final-head CI/review remain pending.
  The earlier local UI counts precede that audit-helper change.
  Nine further verified findings now pass 48 hook and 19 documentation
  tests: exclusion-only pathspecs, xargs operands, merge-status reads,
  word-internal hashes, child HOME, inherited gh repository flags,
  angle-bracket links, hook error handling and the report-only verifier's
  catalog command. Their fresh native gate passed 460 unit tests, with
  no failures/skips and an unchanged catalog; final-head CI is pending.
  CI on `3c379f1` passed all 460 units and 35 enabled UI tests per device
  (four existing opt-in probe skips). A final nine-finding parser batch
  includes 57 hook and 20 docs tests. Main `313de2c` is incorporated;
  the combined gate passed all 460 native units, 57 hook tests and 20
  docs tests with the catalog unchanged. New-head CI remains pending. It distinguishes executed commands from here-document data,
  actual API writes from prose/read requests, and code blocks from links.
  Five later findings add checked shell here-strings, contextual Git aliases,
  conservative curl-config refusal, GraphQL approval checks and repository-bound
  documentation links. The final gate passed 460 native unit, 61 hook and
  21 docs tests with the catalog unchanged; new-head CI is pending.
  Eleven more reproduced command-form/code-example findings passed the final
  gate: 460 native unit, 71 hook and 22 docs tests, with an unchanged catalog.
  Main `cc35c30` is incorporated. Eight further findings cover pending-review
  approvals, curl uploads, Git digit flags, gh aliases, persistent shell
  environment, citation code examples, repeated heading anchors and the
  verifier's staged snapshot. The final local gate passed 460 native unit,
  76 hook and 24 docs tests with the catalog unchanged.
  New-head CI remains pending.
  Eight later findings cover separate curl operations, protected REST writes,
  subshell scope, ANSI-C quoting, full heredoc delimiters, wrapper clusters,
  encoded relative links and Setext headings. All eight reproduced before
  correction. The full unit script passed 460 native tests; the final
  guard/docs checks passed 82 and 26 tests. The catalog is unchanged.
  The owner re-enabled auto-merge on both PRs; #14 has since merged,
  and #17 has since merged as `7bff8f0`.
  Reconciliation and verification: [`log/2026-10-22-agent-guardrail-reconciliation.md`](log/2026-10-22-agent-guardrail-reconciliation.md).

## History

Before 2026-10-21: [`docs/HANDOFF-LOG.md`](HANDOFF-LOG.md). Since: one file
per pull request in [`docs/log/`](log/README.md). The research behind the
roadmap: [`docs/recon/`](recon/README.md).
