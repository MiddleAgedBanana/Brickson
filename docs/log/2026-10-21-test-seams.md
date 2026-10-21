# Test seams and CI evidence

*2026-10-21. Pull request #13 (`claude/project-thread-ieeqg5`), built on
#12. The "Test seams and CI evidence" thread.*

## What changed and why

Nothing a person using Brickson sees: a release build behaves exactly as
before. What changed is how far a green CI run can be trusted, so the
other work streams can rely on it.

- **`scripts/test.sh`** chooses simulators by device type, never by name
  (`scripts/choose-simulator.py`). UI tests run on the newest iPad Pro
  13-inch and then the newest standard iPhone; a failure on one still
  runs the other. `SIMULATOR_FAMILY=ipad|iphone` runs one family. A
  `DESTINATION` simulator is started and waited for by id, like the
  default one (before, only the default was). Each run prints the Xcode
  and XcodeGen versions, builds for testing and then tests, keeps a fresh
  result bundle per simulator in `build/TestResults/<mode>-<family>.xcresult`,
  prints how many tests ran, and fails when none did. Arguments after the
  mode go to `xcodebuild`. Before UI tests it turns off the keyboard's
  minimized bar and launches the app once on test-only storage (a
  warm-up), because the first UI test after a simulator starts failed on
  CI on 2026-10-21 ("kAXErrorServerNotFound") while every later test
  passed. Nothing is retried or skipped. `scripts/test.sh device` builds
  unsigned, and says so, when project.yml names no team.
- **`LaunchOptions`** (`Brickson/App/LaunchOptions.swift`): launch
  arguments, read in debug builds only. `--test-storage` puts the
  library, settings and files in a test-only folder (inside the app's
  temporary folder) and the `BricksonTestStorage` settings suite;
  `--fresh-test-storage` erases them first. `--short-timeouts` gives idle
  timers short limits through `AppTimeouts` (`\.appTimeouts` in the
  environment). `--screen=keyboard-probe` is parsed for the typing work,
  which wires it up. Misspelt options are logged. `launch.settings` is
  the `UserDefaults` other code should take, so tests never read the
  person's settings; `launch.filesDirectory` is where app files go.
- **UI test helpers** (`BricksonUITests/LaunchHelpers.swift`):
  `launchedApp(textSize:appearance:orientation:storage:arguments:waitsForHome:)`,
  `assertReachable`, `attachCapture` (screenshot, accessibility tree and
  every button's frame as JSON, kept in the result bundle), and
  `assertPassesAccessibilityAudit`, moved out of `LaunchTests` with the
  same expected phrase-tile guess.
- **New UI tests.** `HomeReachabilityTests` walks Home through three
  states (just opened, the emergency phrases showing, a phrase just
  spoken) at the default and AX5 text sizes, in portrait and landscape,
  and checks Yes, No, Emergency and Again each exist, can be activated,
  lie wholly on screen and are at least 44pt (invariants 1, 2 and 10).
  `LaunchTests` adds audits in dark mode and with the emergency phrases
  showing, and two gate tests: the message placeholder must grow at AX5,
  and Home's background must darken in dark mode, so the AX5 and dark
  tests cannot quietly test the defaults.

## Commits

- `726c019` Choose test simulators by type, test UI on iPad and iPhone,
  keep results
- `6ce6f2a` Let UI tests run the app on test-only storage with short idle
  limits
- `7de818e` Share one UI-test launch helper and check Home's controls in
  every state
- `5b1d038` Describe the new test script, launch helper and simulator
  choice (AGENTS.md, README.md, docs/DECISIONS.md, docs/HANDOFF.md)
- `53436bf` Record the test seams change in docs/log (this file).
- After CI's first full run and the reviews (2026-10-21, later the same
  day): the dark-mode gate reads the median of the whole screenshot
  instead of one pixel, which read white in dark mode on both devices;
  the iPhone's audit findings on the stand-in Home are recorded as strict
  expected failures (docs/DECISIONS.md, "Home version 0 is a stand-in");
  the iPhone's landscape tests check it stays portrait; a `DESTINATION`
  simulator must fall in the deployment-target-to-SDK range; an
  unreadable test summary fails the run; an earlier result bundle is
  removed before anything can fail; unit runs print coverage and check the
  String Catalog; `PaletteTests` uses `UITraitCollection(mutations:)`.

## Original verification (before the Mac diagnosis)

- Written on a cloud machine that cannot build Swift. The Swift changes
  are untested until this pull request's CI runs; read its latest run.
- The initial `python3 scripts/test-runner.py` run (33 tests, 22 new) passed
  on Linux with bash 5. Follow-up commits brought this to 46 tests at
  `6e6cbcc`; the Mac lifecycle fix brings it to 51. Each new assertion was
  seen failing under a
  deliberate break: dropping the warm-up, the iPhone run, the keyboard
  step, the `--fresh-test-storage` argument, or the zero-test check.
- What would make the new Swift tests fail: `LaunchOptionsTests`, a
  release-style `.standard` reaching the test folder, erasing kept
  storage, or DEBUG no longer set for tests; `HomeReachabilityTests`, a
  quick control moved off screen, covered or under 44pt in any of the
  twelve state, size and orientation combinations; the gate tests, the
  text-size argument or requested appearance not taking effect.

## Original limits (superseded where the Mac diagnosis has evidence)

- Nothing ran on macOS outside CI, including `scripts/test.sh` on
  macOS's bash 3.2.
- Whether the warm-up launch stops the first-UI-test failure. It only
  pays a cold simulator's first-launch cost before the tests; watch the
  next few CI runs.
- Landscape on the iPhone: the app is portrait-only there, so those runs
  check that turning the phone changes nothing. Real orientation changes,
  iPhone Duo's poses and windowed iPad sizes are not covered.
- Nothing here is evidence about Eye Tracking, Switch Control, dwell or
  sound (docs/HANDOFF.md, "Checks that need a real device").

## Follow-ups

- This thread, next in the same stream: commit the String Catalog CI
  produces; treat warnings as errors once CI builds clean; one `tests.yml`
  change for the owner to paste that uploads `build/TestResults` from
  both jobs.
- The Mac follow-up removes `expectKnownPhoneHomeAuditFindings` and fixes
  the exposed layout and harness defects; see the diagnosis record.
- The Mac follow-up wires `launch.settings` into the current SpeechService;
  a later AppAudio wrapper must preserve that injection. Typing thread:
  switch on
  `launch.startScreen == .keyboardProbe`, and keep drafts under
  `launch.filesDirectory`.
- The Mac follow-up adds strict AX5 audits in both appearances. The
  reachability tests still verify that turning the iPhone to landscape
  leaves its portrait layout intact; iPad tests exercise both orientations.

## Mac follow-up

The earlier claim that changing the brightness sample solved dark mode
was not supported by a passing run. Both screenshots remained light at
`6e6cbcc`. [The diagnosis record](2026-10-21-ui-test-diagnosis.md) documents
that reproduction, the debug appearance correction, strict audit fixes,
speech settings injection, simulator lifecycle tests and final validation.
