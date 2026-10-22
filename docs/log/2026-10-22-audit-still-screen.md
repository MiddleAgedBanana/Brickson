# Accessibility audits wait for a still screen

*2026-10-22. Pull request #31 (`claude/project-thread-5ubwzx`). Thread
"Flaky UI tests in CI", a cloud session that cannot build or run Swift.
Fixes issue #30.*

## What changed and why

An accessibility audit in the UI tests failed on some CI runs and passed
on others, on the same app code: `LaunchTests.testLargestTextKeepsQuickControlWordsVisible`,
"Accessibility audit (AX5, light; type 2): Potentially inaccessible text
on no element" (issue #30). The cause is the test's timing, not the app.

The audit ran while Home was still changing by itself. After Yes is
tapped, Home shows "Speaking" under the message until the voice finishes.
On the failing run the simulator's voice took about 3.3 seconds to say
"Yes.", and the test reached the audit 3.1 seconds after the tap, so the
"Speaking" line left the screen in the first moments of the audit.
Apple's audit compares the text it finds in screenshots with the
accessibility tree, and the two are not read at the same instant (Apple
does not document this; the evidence below shows it). Text that leaves
in between is in the screenshot and not in the tree, and is reported as
text with no element, which is the finding. Whenever "Speaking" was
drawn, it had its accessibility element.

The fix makes every audit start on a still screen:

- `AccessibilityAuditRunner.perform(settle:_:)` runs a settle step before
  the audit, and again before its one retry after an audit-service
  timeout. Two new tests pin the order (`AccessibilityAuditRunnerTests`).
- `assertPassesAccessibilityAudit` settles with the new
  `waitForSpeechToFinish` (LaunchHelpers.swift), which waits until Home's
  "Speaking" line is gone. It returns at once when nothing is speaking,
  and fails if "Speaking" still shows after 30 seconds: speech that never
  ends is a failure of its own (invariant 4).
- The AX5 test also waits for speech to finish right after Again turns
  on, so its captures and word checks for "phrase spoken", over a second
  of work, sit between the last change on screen and the audit.
- AGENTS.md, *Gotchas*: "Audit only a still screen", and "CI results can
  be read without a Mac" (how this diagnosis was done). HANDOFF,
  *Verification*: the audit no longer looks at "Speaking".

No audit type, finding filter or retry changed. The finding was never
discarded: it came from auditing a moving screen, and the audit still
reports everything it finds on a still one.

Issue #30 guessed that text is drawn for a moment without an element
while the spoken message settles at AX5. The recording does not show
that: the message "Yes." had its own element in the same capture, and the
only change on screen near the audit was "Speaking" leaving.

## Evidence

From run [39835147321](https://github.com/MiddleAgedBanana/Brickson/actions/runs/39835147321)
(PR #29 at `5beb447`, which is `main` at `2895825` plus Markdown), UI
tests job, iPhone 17 simulator, iOS 27.0, Xcode 27.1 (27A9275), portrait,
AX5 text, light appearance, full software keyboard turned on (nothing
typed). Its `ui-test-results` artifact is kept until about 2026-11-05.

Times are the test's own clock, from its activity log:

| Time | What happened |
|---|---|
| 19.98 s | Yes tapped |
| 21.43 s | Again on (the phrase started) |
| 21.69–23.07 s | captures of "AX5, light, phrase spoken" and the four word checks |
| 21.97 s | the captured accessibility tree has one `StaticText` labelled "Speaking", frame (16, 211.3, 206 × 58.7), over the drawn line; the line's eight hidden layout copies are unlabelled |
| 23.07–26.73 s | the audit; it reported the finding at its end |

The xcresult keeps a screen recording of the failed test. Its clock is
within a few tenths of a second of the test's: the taps on Emergency at
17.01 s and Yes at 19.98 s first show at 17.26 s and 20.10 s. The
recording only adds a frame when the screen changes:

- 20.76 s: "Speaking" under "Yes." at AX5.
- 23.41 s: the next frame. "Speaking" is gone; nothing else changed. In
  the test's clock that is about 23.1 to 23.4 s, in the first moments of
  the audit (it began at 23.07 s).
- 24.28 to 25.66 s: the audit's own Dynamic Type pass, stepping the text
  size up from small to AX5.

[`ui-test-evidence/iphone-ax5-audit-race.png`](ui-test-evidence/iphone-ax5-audit-race.png)
shows those three frames, left to right.

The same test's dark pass passed on that run: "Speaking" left at 49.9 s in
the recording, 0.6 seconds before its audit began at 50.47 s. The voice
took about 3.3 seconds in both passes. Across the runs below, the audit
began 2.0 to 5.8 seconds after the tap, so whether "Speaking" left before
or during it depended on how long the simulator's voice took that time,
which is why the failure came and went. Home has no animations (no
`withAnimation`, `.animation` or `.transition` in `Brickson/`), so the
line leaves in a single frame.

How it was read on Linux, for the next time:

```sh
# Every attachment of a test, with its time and its file in Data/
sqlite3 ui-iphone.xcresult/database.sqlite3 "select a.name, a.xcResultKitPayloadRefId, a.timestamp
  from Attachments a join Activities x on a.activity_fk = x.rowid
  join TestCaseRuns r on x.testCaseRun_fk = r.rowid join TestCases c on r.testCase_fk = c.rowid
  where c.name like 'testLargestText%' order by a.timestamp"
# The recording is the attachment named kXCTAttachmentScreenRecording
ffprobe -v error -select_streams v -show_entries frame=pts_time -of csv=p=0 ui-iphone.xcresult/Data/data.<id>
ffmpeg -ss 23.41 -i ui-iphone.xcresult/Data/data.<id> -frames:v 1 frame.png
# Text and JSON attachments are zstd-compressed
zstd -dc ui-iphone.xcresult/Data/data.<id> > tree.txt
```

## Other UI failures in recent runs

Every run of the Tests workflow from 2026-10-21 to this pull request was
read (98 runs, earlier attempts of re-run runs included; 41 were
cancelled). The UI failures that came and went on unchanged code:

| Failure | Seen | Cause and owner |
|---|---|---|
| This audit finding, type 2, in the AX5 test's one audit after "phrase spoken" | 5 device results in 4 run attempts: `31e48f7` (iPhone, light and dark), `9cf0e76` (iPhone, light and dark), `51f3a5f` (iPad and iPhone, light), `5beb447` (iPhone, light) | This pull request |
| "Error getting main window kAXErrorServerNotFound", or a UI query timing out (395 s in `HomeLayoutTests`), always in the first test that launches the app | 8 device results in 7 run attempts of the kAX error, last on 2026-10-21 22:17 (`31e48f7`); the query timeout once, on `1df97d5` | AGENTS.md's known slow first launch; the warm-up launch (32 to 70 s) did not prevent it. Codex on the owner's Mac is rewriting the slow `HomeLayoutTests` query, now the first test to launch the app |
| The UI job cancelled at its 50-minute limit with no test failed | once, `9658b0c` (iPad passed; the iPhone was 10 minutes into its tests) | Codex is raising the limit; setup times under *Follow-ups* |
| "Failed to compute hit point for Button … familySetup … {{inf, inf}, {0.0, 0.0}}" in `SettingsTests.testAnIdleSettingsReturnsToItsFirstScreenAndStaysOpen`, three tap attempts over 7 s | once, iPhone, `51f3a5f` (#27's branch; the iPad passed) | Not established; under *Follow-ups* |

The type-2 finding first appeared on `31e48f7` (2026-10-21 22:17): none in
30 device results before it, 5 in 53 since. That commit changed only the
quick controls' labels, nothing in the status line or speech, and the
audit began 2.0 to 3.1 seconds after the tap before it, as it did after,
so the onset is not explained. Chance is possible: at about one result in ten,
30 clean results in a row come about one time in twenty.

Deterministic failures on work-in-progress branches (audit types 65536
and 131072, layout and appearance checks, keyboard probes, one build
error) were fixed on their branches and are not flakes.

## Commits

- `4b3dc0d`: the settle step, `waitForSpeechToFinish`, the AX5 test's
  wait and the two runner tests.
- The next commit: this record, the evidence image, AGENTS.md's two
  gotchas and HANDOFF's *Verification* line.

## Verified

- Nothing was built or run here: this is a cloud session (AGENTS.md,
  *Build and test*). CI on this pull request is the build and the test.
- The runner and its six tests (`AccessibilityAuditRunner.swift`,
  `AccessibilityAuditRunnerTests.swift`) compiled and passed on Linux
  with Swift 6.3.3 and swift-corelibs-xctest, in a throwaway package with
  the main-actor annotations removed (Linux XCTest rejects a main-actor
  `XCTestCase`; Apple's accepts it, as the unchanged tests already show).
  Mutations, each built fresh: no settle before the audit, 2 failures;
  settle after the audit, 2 failures; no settle before the retry, 1
  failure. `LaunchHelpers.swift` and `LaunchTests.swift` use XCUITest,
  which Linux cannot compile.
- `waitForNonExistence(timeout:)` is documented for Xcode 16.3 and later
  (developer.apple.com, XCUIAutomation, checked 2026-10-22).
- `waitForSpeechToFinish` fails if "Speaking" never leaves, for example
  if the speech watchdog stopped ending phrases the synthesizer never
  reports finished; it has not been seen failing.

## Not verified

- That the flake is gone. It cannot be produced on demand; it needs the
  simulator's voice to finish while an audit runs. The evidence will be CI
  runs without it.
- How the audit pairs its screenshots with the tree. Apple does not
  document it, and two runs failed in both appearances, so any change
  during an audit may be enough. After `waitForSpeechToFinish` nothing on
  Home changes by itself, except perhaps a frame in which the tree no
  longer has "Speaking" and the screen still shows it; the AX5 test keeps
  over a second of work in between, and no other audit follows speech
  today.
- Whether this happens on a device; it was only seen on a simulator.

## Follow-ups

- **Audit "Speaking" on purpose.** No audit sees the line now, and before
  this only some runs did, by chance. A debug-only launch option that
  holds speech in progress would let one audit it at AX5 deterministically.
  *(a test seams thread)*
- **Setup time of the UI job**, measured on the same run: on the iPad,
  `simctl spawn … defaults write` for the full keyboard took 5 min 9 s
  after the simulator reported booted (18:55:39 to 19:00:48 UTC); the
  iPhone's build for testing took 3 min 48 s against the iPad's 52 s; the
  warm-up launches took 70 s and 38 s. The UI step ran 46 minutes of its 50.
  *(whoever takes the job's time limit; Codex on the owner's Mac is
  raising it)*
- **The Family Setup tap with no place to tap** (`51f3a5f`, iPhone). With
  `--short-timeouts`, Settings resets 3 seconds after the last activity,
  also when it is already on its first screen, and every reset rebuilds
  its screens (`.id(activity.resetCount)` in `SettingsView`). A failed tap
  records no activity, so the resets kept coming. All three of XCTest's
  attempts found a "familySetup" button with an infinite frame, which
  looks more like an element left behind by a rebuild than three unlucky
  taps; that run kept no result bundle, so it is not established. A
  leftover element would matter beyond the test, since VoiceOver and
  Switch Control walk the same tree. If it fails again, the kept result
  has the recording and the tree. *(a new thread if it recurs)*
- **A script that lists and extracts a result's attachments on Linux**,
  so cloud threads need not retype the commands above. *(a test seams
  thread)*
