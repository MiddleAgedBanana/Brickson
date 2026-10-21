# Brickson recon: tests, scripts, CI and project configuration

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Repository paths are relative to the repository root. Nothing in the repository was changed. "Verified" = read in a file, printed by a command, or seen in a CI log; "inference" is marked.

## 0. What was run and the environment facts that matter

- Ran `python3 -I scripts/test-site.py` (4 pass) and `python3 -I scripts/test-runner.py` (3 pass). Did not run `xcodebuild`, `xcodegen` or `simctl`; simulator facts come from `~/Library/Developer/CoreSimulator/Devices/*/device.plist` and `/Library/Developer/CoreSimulator/Volumes/`.
- Local Mac (verified): Xcode 27.0 (27A266a); the only iOS runtime volume is `iOS_24A434` (27.0); SDK iPhoneOS27.0. Available iOS devices are three custom-named ones: `Brickson Website Checks` F677BB51 (type `iPad-Pro-13-inch-M5-16GB`), `Brickson Recon iPad` BCADF15C (same type, state 3 = booted: another agent's), `Brickson Recon iPhone` 2F264B19 (`iPhone-17`). Thirteen stock-named devices (iPhone 17, iPad Pro 13-inch (M5) C2128401, ...) sit on `iOS-26-5`, whose runtime is not installed, so `simctl list devices available` omits them. XcodeGen 2.46.0 is installed locally (`/opt/homebrew/Cellar/xcodegen/2.46.0`) and is also what CI's `brew install` poured (job log).
- CI (verified from run 38525748691 on `main`, 2026-10-14, and the `macos-26` image README, image 20260824.0517.1): Xcode 26.6 (17F113) is the image default; runtimes 26.2/26.4/26.5; `scripts/test.sh` picked `A2011F14…` (26.5 iPad Pro 13-inch (M5)); xcbeautify 3.2.1 is preinstalled; XcodeGen is not (brew install takes 5 s). Unit job 9m48s: boot wait 1m46s (`07:02:42` → `07:04:28`), build+test 6m52s, of which the 113 tests take about 6 s. UI job 8m33s: boot wait 1m57s, build about 5 min, 8 tests in 61 s (`testAPhraseSpeaksOnTheFirstTap` 19.7 s, audit 17.6 s). One compiler warning in the whole build: `'init(traitsFrom:)' was deprecated in iOS 17.0` from `BricksonTests/PaletteTests.swift:25`. The image README's first line announces "Xcode 27 is now available as a public preview" (issue 14404), so the image default can move under the project.
- The worktree has an uncommitted edit by another agent to `scripts/test.sh` (replaces the name filter with a `deviceTypeIdentifier` filter, lines 40-46). My proposal in section 3 subsumes it; the roadmap should not plan it twice.

## 1. Test-by-test audit (can each test fail for the reason it claims?)

Verdicts: **sound** = fails for the stated reason, with a real negative case; **weak** = passes without the property it names.

**BricksonTests/SpeechServiceTests.swift** (sound, but unisolated). `SpeechService()` at :10 and :30 builds a real `AVSpeechSynthesizer` and really speaks "Hello." on the simulator; `stop()` cancels. Each `init` (Brickson/Speech/SpeechService.swift:80-157) also: sets the shared `AVAudioSession` category, registers on `NotificationCenter.default` for `availableVoicesDidChangeNotification` with a token it never removes (:112-118, a leak per instance), creates an `AudioSafetyMonitor()` that KVO-observes the shared session, reads `UserDefaults.standard` (`selectedVoiceID`, `speechRate`, :85-93), and calls `AVSpeechSynthesizer.requestPersonalVoiceAuthorization` (:156, :166). Because the unit bundle runs inside the app (`project.yml:103` `TEST_HOST`), `BricksonApp.init` (Brickson/App/BricksonApp.swift:16-26) has already done all of this once, opened the *persistent* store in the test host's container and seeded it; the suite therefore runs against whatever `UserDefaults` and store the simulator kept from earlier runs. Today nothing writes those keys, so pollution is theoretical; it becomes real with Settings (rate/voice persisted) and editing. CI shows no Personal Voice alert blocks the UI tests, so the simulator answers the request without prompting (inference: it reports `.unsupported`); on a real device the test host would prompt, so device runs of either suite need an interruption monitor or a seam. The assertions themselves are right: `phraseStartCount` would stay at +1 if it only tracked `lastSpokenText` (:14-18), and blank text is correctly not a start (:33-36).

**BricksonTests/AudioSafetyMonitorTests.swift** (sound). Private `NotificationCenter()` and identity objects isolate every test except `aMediaResetDuringAPhraseNamesAgain` (:66-83), which again builds a real `SpeechService` (1.67 s on CI, the slowest unit test) and leaves "Hello." playing on the old synthesizer. Missing negatives: a route-change or reset notification posted with a *different* object is only checked for interruptions (AudioSafetyPolicyTests:186-194), not here.

**BricksonTests/AudioSafetyPolicyTests.swift** (mostly sound). Good parameterization (:145, :240, :256, :314) and real negatives (ended-type and wrong-object notifications :178-194). Two weak ones: `interruptedPhraseStillOffersRecoveryAfterTheSynthesizerStops` (:134-143) only calls `recordInterruption(repeatableSpeechActive: true)`; it never involves the live flag its comment talks about and duplicates the first half of :98-130. `successfulAlertRetryRemovesItsSpecificWarning` (:209-217) checks one static policy state, not a retry. `compactStatusCopyFitsAReservedStrip` (:265-268, 16 characters) is not what reserves the strip (HomeView draws hidden copies of every message, Brickson/Home/HomeView.swift:321-326), so it is a tripwire, not the invariant.

**BricksonTests/SpokenUtteranceTrackerTests.swift** (sound, the best file). One `ContinuousClock.now` at :13 plus offsets; `absorptionExpiresAfterTheRepeatWindowWithoutProgress` (:73-88) pins the boundary at exactly `repeatWindow`; every "must still speak" case is present.

**BricksonTests/PaletteTests.swift** (sound). Loops carry the pair name in the message (:54, :64), so failures name their case; the comment at :47-48 has it backwards (parameterized tests would show each case even when passing). `theContrastFormulaMatchesWCAG` (:114-120) guards the helper. Limits: it measures the asset value, not the rendered `.borderedProminent` fill on iOS 26 (Liquid Glass), and the only running-app contrast check is the audit, on one iPad, light mode, default text size, Basics category only.

**BricksonTests/AppBundleTests.swift** (sound). Reads the built Info.plist and privacy manifest; `theIPhoneIsPortraitOnly` (:69-72) deliberately pins a decision LESSONS wants revisited.

**BricksonTests/PhraseLibraryTests.swift** (sound). Real failure injection through `seedIfEmpty`'s `save:` (:116-128) and `prepare`'s `saveToStore:`/`makeFallback:` (:156-199). Missing: a store whose `fetchCount` throws, and the open question in docs/HANDOFF.md:117-119 (deleting every category reseeds the starter set) has no test defining the intended behaviour.

**BricksonTests/StarterPhrasesTests.swift** (sound, with a hidden coupling). Decodes the bundled JSON and checks symbols exist. Nothing checks that the two literal phrases the UI tests tap ("Hello." BricksonUITests/LaunchTests.swift:39,:47; "I need help now." :75) exist, while docs/HANDOFF.md:222-225 asks the owner to edit that file. Nothing mechanical guards invariant 7 (a short blocklist would be a weak but non-zero tripwire).

**BricksonTests/VoiceSelectionTests.swift**, **SpeechRateStepsTests.swift**, **CategorySelectionTests.swift** (sound). Note `SpeechRateStepsTests:33-37` pins unlocalized English ("Normal"), the known catalog gap.

**BricksonTests/ScreenWakePolicyTests.swift** (sound for the pure type; wiring untested). Nothing checks that `BricksonApp` sets `isIdleTimerDisabled` (Brickson/App/BricksonApp.swift:37-39); a unit test in the host can read `UIApplication.shared.isIdleTimerDisabled`.

**BricksonTests/OffMainThreadCallbackTests.swift** (weak at the boundary it names). It calls `monitor.outputVolumeChangeHandler` (Brickson/Speech/AudioSafetyMonitor.swift:101-103) from a detached task; the real KVO closure at :37-42 is never exercised, so dropping its `@Sendable` would pass (docs/HANDOFF.md:104-107 says so). A trap there would also crash the process rather than fail cleanly. The spin at :25-27 (100 `Task.yield()`s) is a bounded busy-wait with no timeout message. The synthesizer delegate (`SpeechSynthesizerEvents`, SpeechService.swift:379-427) is `private`, so no test can call its `nonisolated` methods off-main; the Personal Voice completion (:166-172) is also untested.

**BricksonUITests/LaunchTests.swift** (four sound tests, narrow scope). `testAPhraseSpeaksOnTheFirstTap` (:45-64) proves one tap leads to `lastSpokenText` being set (Again enabled), i.e. the app *tried* to speak; `testEmergencyShowsTheEmergencyPhrases` (:69-77) proves Emergency says nothing and opens the category; neither checks `isHittable` or that the control is inside the window, so a control pushed off screen still "exists". The audit (:89-107) runs once, on Basics, so `EmergencyFill` tiles are never audited in the running app. No launch arguments are used anywhere (grep of `launchArguments|ProcessInfo` in `BricksonUITests` and `Brickson` is empty), so every UI run uses the simulator's persisted store and defaults.

**BricksonUITests/AccessibilityAuditRunnerTests.swift** (sound). Each test's comment names the change that fails it (:7, :17, :30, :48); the loop at :32-46 does not say which of its two errors failed. The runner (`AccessibilityAuditRunner.swift:6-18`) re-runs the whole audit, so an issue found in attempt one is reported twice rather than hidden.

**scripts/test-runner.py** and **scripts/test-site.py** (sound). The runner fixtures prove exit 70/65 propagate through `tee | xcbeautify` and that a failed test is not re-run. Note they run `test.sh` with `DESTINATION` set, so the simulator-selection branch is never exercised by any test.

No `withKnownIssue`, `.disabled`, `XCTSkip` or `Date()` anywhere in `BricksonTests`, `BricksonUITests` or `Brickson` (grep).

## 2. Coverage by invariant (AGENTS.md:102-243)

1. Standard Buttons, labels, 44pt: audit `.hitRegion`/labels on one screen (LaunchTests:89-107). No test of target floors per profile (none exist yet), nothing on iPhone.
2. First activation speaks; Emergency visible, never scrolled or covered: LaunchTests:45-64 and :69-77; `SpokenUtteranceTracker` tests. Nothing checks Emergency is hittable/in-window, nothing with a keyboard (no typing yet), no resolver test (none exists yet).
3. Speaking never changes data: no test; no editing exists, but no test asserts the store is unchanged after `speak`.
4. Audio survives: AudioSafetyMonitorTests, AudioSafetyPolicyTests, SpeechServiceTests, AppBundleTests `speechCanPlayInTheBackground`. Untested: the watchdog `watchForMissedFinish` (SpeechService.swift:288-305, docs/HANDOFF.md:114-116), `ensurePlaybackAudioSession`'s mixable fallback (:355-374), announcement posting (device only).
5. No silent failures: PhraseLibraryTests failure injections; `catch` sites in SpeechService log and record. No test makes `configurePlaybackAudioSession` fail.
6. Contrast measured: PaletteTests (unit), audit (running app, light only). Dark/Increase Contrast never audited in the running app.
7. Starter words neutral; nothing deletes a person's words: StarterPhrasesTests (structure only); `aLibraryThatHasCategoriesIsLeftAlone` (PhraseLibraryTests:103-112). Content neutrality is owner review only.
8. Position never a function of usage/time: `tiedCategoriesFallBackToNameThenIdentity`, `phrasesKeepTheirStoredOrder`, CategorySelectionTests; `columnCount` (HomeView.swift:40) is untested.
9. Hard stops: `thePrivacyManifestDeclaresNoTrackingAndNoCollection`; no package manifest exists. No test that `cloudKitDatabase: .none` is used for the persistent store (`openForApp` is untested; its in-memory path is).
10. Dwell safety: `SpokenUtteranceTracker` absorption only. No chain/snap scoring, no "one activation from every Home state" check.
11. No Home scrolling for the starter library: no test; the stand-in grid scrolls by design (docs/DECISIONS.md:181-225) and there is no layout engine.
12. Screen never locks: ScreenWakePolicyTests (pure); wiring untested.

What slips past the four UI tests: Yes/No speaking nothing (never tapped); a category tap showing the wrong phrases (never tapped); Emergency moved below the fold or under a scroll view on any device (only `exists`); any iPhone layout regression (CI is iPad only, docs/DECISIONS.md:223-224); clipped or overlapping text at AX sizes, dark-mode or Increase Contrast failures (audit at default size, light); emergency tiles failing contrast; Again repeating the wrong phrase; a regression that makes speech start late but still start; and anything about sound.

## 3. Local versus CI; scripts/test.sh

**Selection logic (scripts/test.sh:29-50).** Filters on `device["name"].startswith("iPad")` (:40-41) and ranks `(name.startswith("iPad Pro 13-inch"), version, name)` (:43). On this Mac every available iOS device is custom-named, so it exits "No iPad simulator with iOS 26 or later is installed" (reproduced with an exact fixture of this Mac's available devices; the committed Python exits 1, the other agent's uncommitted variant and my proposal pick F677BB51). Other failure modes: a renamed device anywhere; the name tie-break sorts "M10" before "M4"; the runtime regex `iOS-(\d+)-(\d+)` is unanchored (harmless today); it never checks `isAvailable` (fine while the `available` flag is passed, wrong if someone drops it); it prints only a udid, so the log never says which model or OS was used (AGENTS.md:365). Filtering on `deviceTypeIdentifier` is more robust: it is the identity Xcode uses, and the M5 13-inch has two type ids (`iPad-Pro-13-inch-M5-16GB` and `-12GB`, both on this Mac), so match the substring `SimDeviceType.iPad-Pro-13-inch`, not the whole id. (The JSON key name was not re-verified with `simctl`; it is the key the other agent's edit relies on and matches the `deviceType` key in `device.plist`.)

Exact replacement for the Python in `newest_ipad_simulator()` (tested with `python3 -I` against the fixture of this Mac and a CI-like list with three iOS 26 runtimes; chooses F677BB51 / A2011F14 for iPad and 2F264B19 / "iPhone 17" for iPhone; ranks the preferred model first, then the newest OS, as the script header at :10-11 promises):

```python
import json, re, sys
family = sys.argv[1] if len(sys.argv) > 1 else "ipad"     # pass "$family" after `python3 -`
kinds = {"ipad": ("SimDeviceType.iPad", "SimDeviceType.iPad-Pro-13-inch"),
         "iphone": ("SimDeviceType.iPhone", "SimDeviceType.iPhone-17")}
family_prefix, preferred = kinds[family]
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    match = re.search(r"\.iOS-(\d+)-(\d+)$", runtime)
    if not match or int(match.group(1)) < 26:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        # Judge by the device type, never the name: a simulator can be renamed
        # ("Brickson Website Checks" is an iPad Pro 13-inch by type).
        kind = device.get("deviceTypeIdentifier", "")
        if not kind.startswith("com.apple.CoreSimulator." + family_prefix):
            continue
        if not device.get("isAvailable", True):
            continue
        # The preferred model first, then the newest OS, then a stable tie-break
        # on udid (names are free text, and "M10" sorts before "M4").
        rank = (preferred in kind, version, device["udid"])
        if best is None or rank > best[0]:
            best = (rank, device)
if best is None:
    sys.exit(f"No {family} simulator with iOS 26 or later is installed. Add one in Xcode: Settings, Components.")
print(best[1]["udid"])
print(f"Chosen: {best[1]['name']} ({best[1]['deviceTypeIdentifier'].rsplit('.', 1)[-1]}, iOS {best[0][1][0]}.{best[0][1][1]})", file=sys.stderr)
```

Invoke it as `python3 - "$family" <<'PY' ... PY` with `family="${SIMULATOR_FAMILY:-ipad}"`; a draft of the surrounding shell passed `bash -n`.

**DESTINATION set (:80-82).** No `bootstatus` wait, so the CI flake the wait was added for (docs/HANDOFF.md:52-59, AGENTS.md:464-476) returns for every agent following "one simulator per agent" with `DESTINATION=id=…`, and for any future iPhone job using `name=`. Smallest change after :81: `case "$destination" in id=*) xcrun simctl bootstatus "${destination#id=}" -b ;; esac`. The tie-break by udid also means the default can land on a simulator another agent booted (BCADF15C is booted now); agents must keep passing `DESTINATION`, and the README's `name=iPhone 17` example (README.md:102) is ambiguous when several runtimes hold that name.

**xcbeautify (:54-72).** Correct: `pipefail` carries xcodebuild's status, the raw log is replayed on failure, the runner tests prove 70 and 65 survive. Two things to know: xcbeautify's output is block-buffered when piped, so on GitHub every build line is stamped at the end (`07:11:20` for the whole compile; inference from the timestamps) and a hung build shows nothing until `timeout-minutes` fires; and the raw log is deleted on success, so a flaky-but-green run leaves no evidence (no `-resultBundlePath`, see section 5).

**Device mode (:107-112).** `generic/platform=iOS` with `CODE_SIGN_STYLE: Automatic` and an empty team (`project.yml:26,41`) fails at signing, so the mode is unusable until the owner sets a team; adding `CODE_SIGNING_ALLOWED=NO` when `DEVELOPMENT_TEAM` is empty would turn it into a "compiles for arm64 device" check CI could run.

**Exit codes.** 1 missing XcodeGen (:21), 2 unknown mode (:115), xcodebuild's own otherwise; `set -euo pipefail` (:14) stops on `xcodegen generate` failure. Sound.

**Gotchas (AGENTS.md:436-500).** `-only-testing` parentheses (:458-459): documented, but the script accepts no extra arguments, so a filtered run bypasses the simulator choice and `-collect-test-diagnostics never` (:97); add `shift; … test "$@"`. Keyboard minimization (:438-441): no prepare step exists; once the udid is known the script can run `xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false` after `bootstatus` (whether it takes effect without a reboot must be checked when the first typing test lands; LESSONS says the test must fail unless the keyboard shows). Display Zoom (:442-445): nothing can set it from the script; the LESSONS rule (docs/LESSONS.md:194-205) needs the UI test to assert `app.windows.firstMatch.frame.size` against the expected size per configuration. One simulator per agent (:454-457): documented only; see DESTINATION above.

**Xcode 27 vs 26.6.** Local runs are Xcode 27.0 / iOS 27.0 (Swift 6.4); CI is 26.6 / iOS 26.5 (Swift 6.3). CI therefore enforces that code compiles against the 26.x SDK (an iOS-27-only API would fail there), while new Swift 6.4 diagnostics can make the owner's Mac red when CI is green. Both directions are acceptable if recorded per AGENTS.md:365; the risk is the image default silently moving to Xcode 27 (README line 3). Pin with `env: DEVELOPER_DIR: /Applications/Xcode_26.6.app` in `tests.yml` and bump deliberately.

## 4. Infrastructure the next port steps need and do not have

- **Synthesizer seam.** `SpeechService` owns a concrete `AVSpeechSynthesizer` (SpeechService.swift:67, :142) and a private delegate (:379-427). Needed: `protocol SpeechSynthesizing` (isSpeaking, isPaused, delegate, speak, stopSpeaking) with `AVSpeechSynthesizer` conforming, `init(synthesizer:makeSynthesizer:)`, the delegate made internal, and an injected `sleep: (Duration) async throws -> Void` for `watchForMissedFinish` (:291, :296) so the watchdog test runs in milliseconds. Also inject `UserDefaults` (:56, :60, :84) and the Personal Voice request (:166). Unlocks: watchdog test, cancel-before-interruption ordering through the real delegate, off-main tests for the delegate and completion, Settings tests without polluting the simulator's defaults.
- **Launch configuration for UI tests.** `BricksonApp.init` (BricksonApp.swift:16-26) reads nothing from `ProcessInfo.arguments`. A pure, tested `LaunchOptions` type (`--ui-testing` → in-memory seeded store, fresh `UserDefaults` suite, short timeouts, fixed appearance/text size) is the one seam typing, editing and Settings UI tests all need; without it, the first editing test that deletes "Hello." breaks every later run on that simulator. Short-timeout argument (docs/LESSONS.md:363-365): no app timeout exists yet, so define the `AppTimeouts` struct now and have `EditModeTimeout`/`SettingsIdlePolicy` read it; one test keeps the real limit.
- **Dynamic Type / appearance launch arguments.** Nothing passes `-UIPreferredContentSizeCategoryName` or an appearance override; add `app.launchArguments` variants in a shared `launchedApp(textSize:appearance:)` helper (LaunchTests:17-22 is the place) and run the audit per variant (docs/LESSONS.md:207-213: default, xxxLarge, AX1, AX3, AX5).
- **Keyboard tests with the full keyboard.** Prepare step in `test.sh` (above) plus a UI assertion that `app.keyboards.firstMatch.frame.height` exceeds the bar height, else fail (docs/LESSONS.md:128-144); the measured worst-case heights per device/orientation become test data for the layout engine.
- **iPhone destination.** Nothing runs on an iPhone (docs/LESSONS.md:231-237, AGENTS.md:65-66). Cheapest: a second step in the existing "UI tests" job, `SIMULATOR_FAMILY=iphone scripts/test.sh ui`, which reuses the job's DerivedData (second build is incremental) and adds roughly a boot (2 min) plus tests; it keeps the required check names untouched (AGENTS.md:494-499). A separate job would need the owner to edit the ruleset before it gates anything.
- **In-process layout matrix harness.** Needs the layout engine as a pure function (port step 4) returning frames per (window size, profile, text size, library); then `BricksonTests` can sweep the matrix (docs/LESSONS.md:194-205) in milliseconds. `ImageRenderer` is only for pure geometry (:239-244).
- **Running-app capture tests.** UI tests that attach `app.screenshot()` and a JSON of every button's label/identifier/frame as `XCTAttachment` with `.keepAlways`, per configuration, exported from the result bundle (`xcrun xcresulttool export attachments`). Requires the result bundle to be kept (section 5).
- **Dwell-chain / snap-reach engine.** Reference harness not ported (docs/PORTING.md:38, :93-94). Architecture: one pure engine in `BricksonTests` consuming the same frame JSON from both sources (layout engine output and captured fixtures), scoring chains under both pointer models (docs/LESSONS.md:248-257, :375-381). Blocked on the layout engine for real sizes; the engine and its unit tests can be written first against hand-made fixtures.
- **Audit per screen.** Extract LaunchTests:93-105 into a `auditCurrentScreen(app, allowing:)` helper now; each new screen adds one test, and Home should also be audited with Emergency open.
- **Result bundles and screenshots.** `xcodebuild test` keeps an `.xcresult` in DerivedData and XCTest's automatic failure screenshots live inside it; CI uploads nothing (`tests.yml:43-44,56-57`). Add `-resultBundlePath "build/TestResults-$mode.xcresult"` (remove it first; xcodebuild refuses to overwrite) and `actions/upload-artifact@v7` with `if: always()` and a short `retention-days` (latest tag v7.0.2, 2026-10-07).

## 5. CI hygiene (`.github/workflows/tests.yml`, `pages.yml`, `dependabot.yml`)

- Concurrency `tests-${{ github.ref }}` with cancel (tests.yml:18-20): works (three cancelled runs on 2026-10-12). On `main` a quick second merge cancels the first merge's run, so a commit cited in HANDOFF can lack its own green run; acceptable, worth knowing.
- Timeouts 40/50 min (:30, :49) against 10-minute runs: bound a hang; fine.
- Caching: not worth it for Homebrew (5 s). The build (5-7 min) is paid twice per run; a `build-for-testing` once plus `test-without-building` per destination would cut a third Mac job's cost, but at today's size the simple duplicate is fine.
- Flakiness: boot wait and the 10 s Again wait are in place; the audit retry is scoped to one error code (AccessibilityAuditRunner.swift:11-12). Gaps: no boot wait with `DESTINATION`; the 15 s launch wait (LaunchTests:20) is the first thing a slow runner trips; no result bundle to diagnose anything after the fact.
- Required checks: job names "Unit tests" and "UI tests" (:28, :47) match docs/DECISIONS.md:400; `main` ruleset verified by a previous agent (docs/HANDOFF.md:186-188).
- Third Mac job cost: public repository, so no minutes billed (GitHub's billing docs, not re-verified here); the real limit is 5 concurrent macOS jobs on Free/Pro (verified on docs.github.com/actions/reference/limits), so three jobs per run queue when two runs overlap.
- Action versions (verified via `gh api … releases/latest`): `actions/checkout@v7` (latest v7.0.1), `configure-pages@v6` (v6.0.0), `upload-pages-artifact@v5` (v5.0.0), `deploy-pages@v5` (v5.0.1): all current. Dependabot monthly, grouped, 7-day cooldown (dependabot.yml:18-25) is sensible; tags not hashes is a recorded decision (docs/DECISIONS.md:315-317).
- Website checks inside "Unit tests" (:39-42): run before the build and take under a second, so they fail fast and cost nothing; the downside is that a CSS contrast failure shows up under the name "Unit tests". Keep, but say so in the step name.
- Unpinned tool: `brew install xcodegen` (:38, :54) takes whatever XcodeGen Homebrew ships; a new release changes the generated project on CI first. Quick mitigation: print `xcodegen --version` in the "Show the Xcode version" step so drift is diagnosable; stronger: pin the formula revision or download a release by checksum.
- For reviewers under "Tests, workflows and the rules themselves" (AGENTS.md:318-343): both workflows use `pull_request` (not `_target`), `permissions: contents: read` (tests.yml:14-15) and page-scoped permissions (pages.yml:23-26), no PR text in shell, only `actions/*`. `pages.yml` also has a correct no-cancel concurrency (:30-32) and a blanks check (:47-52). Nothing to flag.

## 6. project.yml

- Generated project carries `LastUpgradeCheck = 1430` and scheme `LastUpgradeVersion = "1430"` (verified in `Brickson.xcodeproj/project.pbxproj:288` and both `.xcscheme`s), i.e. XcodeGen 2.46's default. Xcode 27 will therefore show "Update to recommended settings" the first time the owner opens it (docs/GETTING_STARTED.md:35-39 tells them to); accepting rewrites the gitignored `.xcodeproj` only, which the next `xcodegen generate` discards, so the owner's local settings silently differ from CI until then (the LESSONS incident, docs/LESSONS.md:367-373). Fix: `options.xcodeVersion: "26.6"` (XcodeGen docs: sets `LastUpgradeCheck`/`LastUpgradeVersion`) and add the settings the prompt would offer so it has nothing to offer. Likely offered (inference): `ENABLE_USER_SCRIPT_SANDBOXING: YES` (no script phases exist, so harmless), `DEAD_CODE_STRIPPING: YES`, `ENABLE_MODULE_VERIFIER: YES`, `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: YES`, `STRING_CATALOG_GENERATE_SYMBOLS: YES`.
- No warnings-as-errors: one warning exists today (PaletteTests.swift:25). `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` is cheap for a 19-file app, but with Xcode 27 locally and 26.6 on CI a new diagnostic on either side blocks one of them; fix the warning first, then enable it for the app target.
- `gatherCoverageData: false` (project.yml:130, :139): coverage as information (not a gate) would show that `watchForMissedFinish`, `openForApp` and `ensurePlaybackAudioSession`'s fallback are unexecuted; enabling it on the `Brickson` scheme and printing `xcrun xccov view --report` in CI costs seconds.
- No test plans: XcodeGen references but does not generate them (docs), so configurations (AX5, dark, `-AppleLanguages`) are better expressed as launch arguments in code, which is also testable.
- `developmentLanguage: en` (:14) → `CFBundleDevelopmentRegion = en`; bundle ids `$(APP_BUNDLE_ID).tests/.uitests` (:102, :116) fine. `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` (:33) also applies to `BricksonTests`, so every `@Test` is main-actor and serialized (fine, slower if suites grow). Deployment target 26.0 (:16, :37) with SDK 27.0 locally is normal; see section 3 for the asymmetry.
- `-derivedDataPath` is not set anywhere, so result bundles, `.stringsdata` and products land in `~/Library/Developer/Xcode/DerivedData/Brickson-<hash>`; a fixed `build/DerivedData` (already gitignored) makes the catalog check below and artifact upload deterministic.

## 7. The empty String Catalog (`Brickson/Resources/Localizable.xcstrings`, 0 strings)

- What the build does: with `SWIFT_EMIT_LOC_STRINGS = YES` (project.yml:44) the compiler writes one `.stringsdata` per file into DerivedData (verified: 17 for the app target in this worktree's DerivedData, e.g. `HomeView.stringsdata` listing "Speaking", "Choose a phrase to speak it.", "Again", "Yes." with its comment). The catalog itself is only updated by the IDE: Apple's docs say choose Product > Build and "Xcode discovers the localizable strings in your app and adds them to string catalogs" (developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog, via Context7); the Xcode 16 notes add that this also happens "when building for testing". Verified locally that `xcodebuild` does not: the other agent's `xcodebuild` run of this exact worktree (DerivedData `Brickson-bfayrd…`, `HomeView.stringsdata` written 19:09) left `Localizable.xcstrings` unmodified (`git status` clean, mtime 18:58). So docs/HANDOFF.md:99 ("fills itself as Xcode builds") is true only for the owner's IDE builds; every agent builds with `xcodebuild`, and the catalog has stayed empty since the first commit. The empty catalog compiles to nothing: the built `Brickson.app` has no `.lproj` folder (verified listing).
- Runtime: `String(localized:)` and `LocalizedStringKey` fall back to the key, which is the English sentence, so English works exactly as written. Nothing breaks today.
- Command-line sync exists: `xcstringstool sync <catalog> --stringsdata <files>` (Xcode 27's tool, `xcstringstool sync --help`). A dry run on a scratch copy against this worktree's app `.stringsdata` produced 25 keys ("Yes.", "No.", "Emergency", "Audio failed", the seven full warning sentences, "No phrases yet.", ...), none for `SpeechRateSteps.description` or `SpeechService.previewSample` (the known gap, docs/HANDOFF.md:99-101). This gives a CI tripwire: sync a copy after the build and `diff` it against the committed catalog; a new user-facing string without a catalog entry fails the PR.
- Risks when a second language arrives: (1) the owner's first ⌘U will rewrite the catalog with 25 "new" entries, an unexpected diff that must be committed, or agents and owner diverge; (2) keys are full English sentences, so copy edits orphan translations (`stale`) silently and the fallback mixes languages with no test; (3) UI tests look up controls by English label (`app.buttons["Yes"]`, LaunchTests:20, :35, :73) and will fail on a non-English simulator unless launched with `-AppleLanguages (en)`; (4) `SpeechService.speechLanguageCode` (:335-337) follows `Bundle.main.preferredLocalizations`, which is correct by design but untested; (5) `AudioSafetyPolicyTests` pin English copy (:56-85), so they must run under `en`.

## 8. Deliverables

### (a) Ranked recommendations (impact first)

1. **`scripts/test.sh:29-50`: replace the name filter with the device-type Python above, add `SIMULATOR_FAMILY`, print the chosen device.** Unblocks every local run on this Mac and any renamed simulator; one agent already started it uncommitted.
2. **`scripts/test.sh:80-82`: boot-wait (and keyboard prepare) when `DESTINATION` is `id=…`.** Removes the known flake for every agent run.
3. **`Brickson/App/BricksonApp.swift:16-26` + new `LaunchOptions` type with unit tests: `--ui-testing` → in-memory seeded store, fresh defaults suite, short timeouts.** Prerequisite for typing, editing and Settings UI tests; without it those tests corrupt each other through the simulator's store.
4. **`Brickson/Speech/SpeechService.swift:67,142,166,288-305,379`: synthesizer protocol, injected sleep, defaults and permission request; delegate made internal.** Pays off the watchdog and off-main gaps recorded in HANDOFF and is needed before the Get Attention alarm shares the session.
5. **`.github/workflows/tests.yml`: `-resultBundlePath` + `actions/upload-artifact@v7` (`if: always()`), and `env: DEVELOPER_DIR: /Applications/Xcode_26.6.app`.** Evidence after failures (screenshots live in the bundle) and no silent toolchain moves.
6. **`BricksonUITests/LaunchTests.swift`: `launchedApp(textSize:appearance:)` helper, audit per state (Emergency open) and per Dynamic Type size, `isHittable` on Yes/No/Emergency, tap Yes and a category.** Closes the largest person-facing blind spots cheaply.
7. **iPhone run as a second step of the existing "UI tests" job** (`SIMULATOR_FAMILY=iphone scripts/test.sh ui`). First-class phone with no ruleset change.
8. **String Catalog: sync once with `xcstringstool sync` and commit; add a CI diff check after the unit build (needs `-derivedDataPath build/DerivedData`).** Prevents the owner's surprise diff and makes "words go through the catalog" (AGENTS.md:378) enforceable.
9. **`project.yml`: `options.xcodeVersion: "26.6"`, add the recommended settings, enable coverage on the `Brickson` scheme; fix `PaletteTests.swift:25` then set `SWIFT_TREAT_WARNINGS_AS_ERRORS` for the app target.**
10. **`OffMainThreadCallbackTests`: exercise the real KVO closure via a KVO-able test double injected into `AudioSafetyMonitor`, add delegate and completion cases; or at minimum type the closure in `AudioSafetyMonitor.swift:40` as an explicit `@Sendable` variable so dropping the attribute fails to compile.**
11. **Build the dwell-chain engine in `BricksonTests` against hand-made frame fixtures now**, so port step 4 lands with its safety scoring instead of after it.

### (b) Quick wins (under an hour each) versus larger work

Quick wins: 1, 2, 5, 9 (each piece), the `xcodegen --version` log line, `shift; test "$@"` pass-through in `test.sh`, a `StarterPhrasesTests` guard (or identifier-based lookup in LaunchTests:28) for the phrases the UI tests tap, a `UIApplication.shared.isIdleTimerDisabled` test for invariant 12's wiring, removing the leaked observer token in `SpeechService.swift:112-118`, `isHittable` assertions, auditing Home with Emergency open, the `CODE_SIGNING_ALLOWED=NO` device compile, deleting or strengthening the two weak `AudioSafetyPolicyTests` cases, naming the failing error in `AccessibilityAuditRunnerTests:32-46`.

Larger: 3 (launch options, half a day with tests), 4 (synthesizer seam, a day), 6 and 7 (a day together), 8 (half a day), the capture harness and layout-matrix harness (depend on port step 4), the chain engine (several days), keyboard tests (depend on typing).

### (c) Dependency note

- Get Attention alarm (port step 1): needs the synthesizer/session seam (4) to test alarm-plus-speech session sharing and the stop-in-a-different-place rule; needs result bundles (5) and audit-per-state (6) because Stop Alert is a new control nearest a hot spot.
- Typing (step 5): needs launch options (3), the keyboard prepare step (2) and full-keyboard assertions, Dynamic Type launch arguments (6), the iPhone run (7), and the measured keyboard heights as test data.
- Editing (steps 2 and 6): needs launch options (3) so UI tests start from a known store, the seeder decision (HANDOFF:117-119) written as a test, failure-injection tests per mutation (pattern already in PhraseLibraryTests), the short-timeout argument for `EditModeTimeout`, and the chain engine (11) for Delete/Keep placement.
- Settings (step 7): needs injected `UserDefaults` and the Personal Voice request seam (4), `SettingsIdlePolicy` on the timeouts struct (3), audit per screen (6).
- Backup (step 2): needs launch options (3) for import tests on a known store and the "nothing deletes a person's words" test pattern; no simulator-specific infrastructure.
- Layout engine (step 4): needs the pure-frames design so the in-process matrix harness and the chain engine consume it; needs running-app captures (5, attachments) to supply measured inputs; needs the iPhone run (7) and the Display Zoom window-size assertion to make the matrix real.