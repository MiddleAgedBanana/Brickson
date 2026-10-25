# Mac keyboard and Home layout checks

*2026-10-25. Branch `codex/mac-simulator-checks`. Codex, following the
owner's ordered Mac handoff, from main `8316743` (PR #53 merged).*

## What changed and why

This is a measurement record. No app, layout, Settings or existing test
code changes. A temporary, uncommitted UI-test harness gathered the later
Home measurements. Its source has been removed and the launch helper
restored exactly; neither is part of this documentation change.
The keyboard checks below ran. The owner later asked for all independent
simulator and documentation work to continue while formal physical-device
testing waits for a properly mounted setup. The remaining jobs are not
reported as done. This note reaches main through a pull request; the
agent does not push to main or merge it.

### Small-window keyboard probes

Xcode 27.1 (27A9275), XcodeGen 2.46.0, iOS 27.0, iPhone SE (3rd
generation) simulator, portrait, light, English, full-screen app, Bold
Text off. A new test-only simulator was used. Display Zoom was selected
in the simulator's Settings, and each probe reported its actual window.
All four portrait measurements found the full software keyboard, 29 keys.

`KeyboardProbeTests` measures the keyboard in a probe, then relaunches
Home without its keyboard and measures the controls. These are separate
launches. Comparing their frames predicts overlap; it is not a capture
of a keyboard covering Home. Home disables Type in the restricted cases.

| Display Zoom / window | Text | Keyboard height / top | Reserved band limit | Yes, No, Emergency bottom | Again, Get Attention bottom | Check result |
|---|---|---|---|---|---|---|
| Default, 375×667 | Default | 260 / 407pt | 339pt | 178pt | 230pt | PASS |
| Default, 375×667 | AX5 | 260 / 407pt | 339pt | 323pt | 410pt | FAIL: Home's band assertion; keyboard allowance passes |
| Larger Text, 320×568 | Default | 256 / 312pt | 240pt | 222pt | 294pt | FAIL: Home's band assertion; keyboard allowance passes |
| Larger Text, 320×568 | AX5 | 256 / 312pt | 240pt | 323pt | 410pt | FAIL: Home's band assertion; keyboard allowance passes |

The keyboard top includes the prediction row; the accessibility frame
of the letter-key area starts lower. Standard AX5 projects a 3pt overlap
at Again/Get Attention. Zoomed AX5 projects 11pt at Yes/No/Emergency
and 98pt at Again/Get Attention. Zoomed default clears this particular
keyboard by 18pt but exceeds the conservative reserved band by 54pt.
That one keyboard configuration is not enough to reduce the allowance
or enable Type there. No reference or assertion was weakened.

The standard run returned status 65: 4 tests, 1 passed, 1 failed, 2
landscape skips. The zoomed run returned status 65: 4 tests, 0 passed,
2 failed, 2 landscape skips. Phone landscape is deliberately skipped
under the existing orientation decision. The first launch reached the
probe in both runs; no first-launch timeout was reproduced here.

Screenshots of every failed configuration, captured by the tests:

- [Standard AX5 Home](ui-test-evidence/2026-10-25-keyboard-checks/keyboard-se-standard-ax5-home.png)
- [Zoomed default Home](ui-test-evidence/2026-10-25-keyboard-checks/keyboard-se-zoomed-default-home.png)
- [Zoomed AX5 Home](ui-test-evidence/2026-10-25-keyboard-checks/keyboard-se-zoomed-ax5-home.png)

The test's unconditional band assertion fails even where Home already
disables Type. That distinction matters when reading these failures.
Another documentation error was found: the probe covers default and
AX5, not every text size; on phones it covers portrait only. HANDOFF's
wording is corrected with this record.

### Typing on Home at AX5

The same debug build ran on iPhone 17 and iPad Pro 13-inch (M5)
simulators, iOS/iPadOS 27.0, light, standard Display Zoom, full-screen,
English, Bold Text off. AX5 was set with the app's documented launch
argument. The captures show the full docked software keyboard, not its
minimized bar. This was manual simulator inspection, not a new UI test.

| Window | Result |
|---|---|
| iPhone 17 portrait, 402×874 | PASS for fixed positions and the required communication controls: Yes, No, Emergency, Get Attention, Speak, Phrases, Type and the field stay above the keyboard. Get Attention and Speak end at 452pt; the prediction row begins at 546pt. FAIL for Put Back's touch reachability with the keyboard up: its frame is y=547–624, behind the keyboard. Clear is above it, ending at 539pt. |
| iPad portrait, 1032×1376 | PASS for fixed positions and clearance: the safety row ends at 346pt, Clear/Put Back at 520pt, well above the full keyboard. Text entry, Clear, Put Back, Return and leaving through Phrases were observed. Return put the message in Home's last-spoken display; this does not prove sound. |
| iPad landscape, 1376×1032 | PASS for fixed positions and clearance: the safety row ends at 346pt and Clear/Put Back at 520pt, above the full keyboard. The draft survives the turn and reopening Type. |

Before/after snapshots match the frames of Yes, No, Emergency, Get
Attention, Phrases, Type and Settings exactly on all three windows.
Speak takes Again's frame. Clear and Put Back take category cells; the
other categories and the phrase tiles keep their frames. The iPad's
Clear/Put Back reachability was also checked with Device Hub's controls.
On the phone, Speak placed the typed words in the last-spoken display
and Phrases dismissed the keyboard. Return on the phone is not verified:
a RocketSim tap reported success without changing the last-spoken
display, and its later iPad taps also reported success without changing
the app; native Device Hub activation did change it. No app-code cause
is established from that automation result.

RocketSim's compact snapshot reported `keyboard=hidden` even in some
captures with visible keys. On the iPad, automated text entry also left
the keyboard hidden. Those intermediate pictures were excluded from
clearance evidence. Device Hub's **Device > Keyboard > Toggle Software
Keyboard** restored it; the final pictures below visibly include it.
Only the final, visible-keyboard snapshots support the clearance claims.

- [iPhone AX5 keyboard and covered Put Back](ui-test-evidence/2026-10-25-keyboard-checks/iphone17-ax5-keyboard.png)
- [iPad AX5 portrait keyboard](ui-test-evidence/2026-10-25-keyboard-checks/ipad-ax5-portrait-full-keyboard.png)
- [iPad AX5 landscape keyboard](ui-test-evidence/2026-10-25-keyboard-checks/ipad-ax5-landscape-full-keyboard.png)
- [Before/after control frames](ui-test-evidence/2026-10-25-keyboard-checks/ax5-frames.json)

Put Back's covered position needs a layout answer; this record does not
move a control or accept an exception. The existing default-size typing
tests do not cover it at AX5. Recheck it with native Device Hub input or
a UI test before choosing a fix; RocketSim's reported activation alone
was not reliable in this run.

### Home at the largest text sizes and with Display Zoom

The same main app code ran on the iPhone 17 and 13-inch iPad simulators,
iOS/iPadOS 27.0, full-screen, English, Bold Text off, in Phrases mode with
no keyboard. Default, AX4 and AX5 are separate launch preferences. Each
Display Zoom configuration was selected in Settings and checked against
the actual app window. The temporary harness measured Basics and Needs,
two starter categories with eight phrases each, from the top of the grid
and after swiping to the bottom. It did not change the app's layout or
weaken an existing assertion. The numbers are in
[the saved measurement file](ui-test-evidence/2026-10-25-home-checks/home-measurements.json)
(raw copy: `build/evidence/2026-10-25/home-measurements.json`). The curated
file contains 70 records. The raw aggregate has 73, including one duplicate
failed AX4 swipe attempt and two earlier open-Duo duplicates; their failures
and limitations remain described here, rather than being counted as passes.

“Whole phrases” counts tiles wholly inside the visible phrase-grid
viewport at the initial scroll position. “Scroll” is the observed vertical
travel of the same tile between top and settled bottom captures. A zero
is credible as no overflow only where all eight tiles fit in the viewport;
it cannot establish a maximum when attempted swipes never moved the grid.

| Window / Display Zoom | Text and appearance | Whole phrases at top / columns | Observed scroll | Check result |
|---|---|---|---|---|
| iPad standard: 1032×1376 portrait, 1376×1032 landscape | Default, AX4, AX5; light | 8 / 4, two rows | 0pt | PASS: both categories fit at every measured size and orientation |
| iPad Larger Text: 774×1032 portrait, 1032×774 landscape | Default, AX4, AX5; light | 8 / 4, two rows | 0pt | PASS: both categories fit at every measured size and orientation |
| Same zoomed iPad windows | AX5; dark | 8 / 4, two rows | 0pt | PASS: both categories fit in both orientations |
| iPhone standard, 402×874 portrait | Default; light | 8 / 3 | 0pt | PASS: both categories fit |
| Same standard iPhone | AX4; light | 6 / 3, two whole rows | 4pt | FAIL for no-scroll fit: the third row extends below the viewport; scrolling reaches it |
| Same standard iPhone | AX5; light | 6 / 3, two whole rows | 52pt | FAIL for no-scroll fit: the third row extends below the viewport; scrolling reaches it |
| iPhone Larger Text, 320×693 portrait | Default; light | 4 / 2, two whole rows | 169pt | FAIL for no-scroll fit: four rows of phrases need scrolling |
| Same zoomed iPhone | AX4; light and dark; Basics and Needs | 0 / 2; viewport only 7pt high, starting at y=651 | NOT ESTABLISHED | FAIL for visible phrase access; Type disabled |
| Same zoomed iPhone | AX5; light and dark; Basics and Needs | 0; grid has 0pt height at y=706, below the 693pt window | NOT ESTABLISHED | FAIL for visible phrase access; Type disabled |

On the zoomed iPad in landscape, Type is disabled at AX4 and AX5. The
phrases still fit. This is a typing-availability result, not evidence of
a keyboard covering Home; the keyboard was not shown in these captures.

On the zoomed iPhone at AX4, the eight-phrase content is 336pt tall but
its visible viewport is only 7pt. Two attempts failed to establish scrolling:
the automated swipes left the phrase frames unchanged. The raw diagnostic
field `measuredMaximumVerticalScroll: 0` therefore means **no movement was
observed**, not a measured maximum of zero or proof that scrolling is
impossible. A later manual long drag supplied no reliable before/after
geometry. The total reachable range remains unmeasured. No whole phrase
was visible at the top, so this is a failed access check regardless of
that unresolved range. A later restricted-window capture run confirms the
7pt AX4 viewport in both appearances and both categories. At AX5 the grid
starts at y=706 with zero height, below the 693pt window; Feelings and
Settings end at y=696, clipping their frames by 3pt, although their labels
remain visible and the safety controls are visible. All eight capture
assertions failed (two sizes, two appearances and two categories); this
run is **not a pass**. Neither restricted size has a whole visible phrase.
The AX5 result does not supply a scroll range.

Screenshots of the phone failures:

- [Standard AX4](ui-test-evidence/2026-10-25-home-checks/iphone17-standard-light-ax4-portrait-Basics-top.png)
- [Standard AX5](ui-test-evidence/2026-10-25-home-checks/iphone17-standard-light-ax5-portrait-Basics-top.png)
- [Zoomed default](ui-test-evidence/2026-10-25-home-checks/iphone17-zoomed-light-default-portrait-Basics-top.png)
- [Zoomed AX4](ui-test-evidence/2026-10-25-home-checks/iphone17-zoomed-restricted-light-ax4-Basics-restricted.png)
- [Zoomed AX5, light](ui-test-evidence/2026-10-25-home-checks/iphone17-zoomed-restricted-light-ax5-Basics-restricted.png)
- [Zoomed AX5, dark](ui-test-evidence/2026-10-25-home-checks/iphone17-zoomed-restricted-dark-ax5-Basics-restricted.png)

These are fit measurements, not new accepted exceptions. R0's touch
profile permits scrolling; a future dwell, switch, head or gaze profile
must fit whole rows at its target floors and needs the fewer-tiles design.
The 7pt viewport needs an arrangement that can show a whole tile; merely
adding a More button would not make one fit. A separate docs-only proposal
will use the completed measurements before any Home code changes.

### iPhone Duo: folded and unfolded

The Duo runs used the iOS 27.1 simulator runtime with Xcode 27.1
(27A9275). The closed pose was verified in Device Hub. Its app window is
466×678pt,
but the measured phrase-grid width is **350pt**; deriving its width by
subtracting two margins from 466 would be wrong. The light, full-screen,
English, Bold Text off measurements below cover Basics and Needs. Each
has eight phrases in three columns, 99pt-tall tiles and 8pt row spacing.

| Text / closed Duo | Grid height | Whole phrases at top | Measured scroll | Check result |
|---|---|---|---|---|
| Default | 310pt | 6, two whole rows | 3pt | FAIL for no-scroll fit; the last row needs 3pt of travel |
| AX4 | 112pt | 3, one whole row | 201pt | FAIL for no-scroll fit; Type disabled |
| AX5 | 64pt | 0, no whole row | 249pt | FAIL for whole-row access; Type disabled |

Seven existing core Home tests and the temporary measurement test passed
in the first closed-pose run (8 passes). A second group of 12 existing
Home flows had 7 passes, 1 failure, 2 skips and 2 expected failures. Across
the 19 existing tests that is 14 passes, 1 failure, 2 skips and 2 expected
failures; the temporary measurement is a separate pass. This is not a
fully passing Home suite. The two skips are the Get Attention and Settings
landscape tests, skipped because `UIDevice.userInterfaceIdiom` is phone;
they are not optional probes.

The failure is `GetAttentionOnHomeTests` at default text: Apple's audit
reported partially unsupported Dynamic Type on **Sounding**. This is an
accessibility finding, not audit-service timeout code -56; no retry or
exception was added. Its cause has not been established or fixed.

- [Closed default](ui-test-evidence/2026-10-25-home-checks/duo-closed-light-default-portrait-Basics-top.png)
- [Closed AX4](ui-test-evidence/2026-10-25-home-checks/duo-closed-light-ax4-portrait-Needs-top.png)
- [Closed AX5, top](ui-test-evidence/2026-10-25-home-checks/duo-closed-light-ax5-portrait-Needs-top.png)
- [Closed AX5, after scrolling](ui-test-evidence/2026-10-25-home-checks/duo-closed-light-ax5-portrait-Needs-bottom.png)
- [Sounding audit failure](ui-test-evidence/2026-10-25-home-checks/duo-closed-default-sounding-audit-failure.png)

Device Hub then showed the hinge at 180°, confirming the fully open pose.
The active inner display showed Home at 951×669pt. The default-text
measurement found all eight phrases visible, four columns, no overflow
and no observed scroll. However, XCTest's window APIs contradicted the
same accessibility snapshot: `app.windows` or `app.frame` could return
669×951 while the controls and measured grid corresponded to 951×669.
The XCTest screen PNGs were black captures of the inactive outer display;
RocketSim's active-inner-display PNG did show the app. A black XCTest
capture is therefore not evidence that Home itself was blank.

`XCUIDevice.landscapeLeft` did not change the measured 951×669 window into
669×951, and the temporary harness's expected-window guard failed. That
failure is preserved in `build/TestResults/home-duo-open-measure/ui-destination.xcresult`
and its exported attachments; no assertion was weakened. Existing Home
tests still assume that a phone remains portrait, whereas Duo's inner
display can rotate.

The separate open-pose run of the 19 existing Home tests finished with
**8 passed, 9 failed, 2 skipped and 0 expected failures** (exit status 65).
It is a failed run. The eight passes are both accessibility-order tests,
the first-run hint and all five default-text `TypingOnHomeTests`, including
Clear/Put Back and Speak/Return. Those typing results establish the tested
simulator behavior, not physical-device sound.

| Existing open-Duo group | Result |
|---|---|
| Accessibility order, default and AX5 | 2 PASS |
| Typing on Home, default text | 5 PASS |
| First-run hint | 1 PASS |
| Get Attention, default and AX5 | 2 FAIL |
| Home layout | 1 FAIL |
| Home reachability, both text sizes and requested orientations | 4 FAIL |
| Settings opening, default and AX5 | 2 FAIL |
| Get Attention and Settings landscape cases | 2 SKIP: phone-idiom guard |

The raw log records portrait-orientation waits that did not complete and
controls from a 951×669 layout being tested against a live `app.frame` of
669×951. Those observations explain many reported containment failures;
they do not establish an exhaustive cause for every failure. In addition,
Settings' AX5 nearest-control assertion failed: Home's Settings frame was
nearest Back to Talking by centre, where the test expected Family Setup.
The existing chain assertions also appear in the log. Do not dismiss that
placement finding as a window-API error without checking its actual frames.
No app code, existing assertion or expected-failure rule changed.

The two skipped cases are landscape skips caused by the phone idiom,
not optional probes. While expected for the closed phone, on the open
inner display they leave a rotation-coverage gap in those existing tests.
The subsequent measurements below used native Device Hub rotation and a
temporary helper that preserved the chosen orientation. They do not turn
this failed existing-test run into a pass, and no rerun or waiver is claimed.

Full log: `/private/tmp/brickson-home-duo-open-tests.log`. Result:
`build/TestResults/home-duo-open-tests/ui-destination.xcresult`. Exported
attachments: `build/evidence/2026-10-25/home-duo-open-tests/`.

#### Active inner display after native rotation

Device Hub's native Rotate Right and **Controls > Rotate Left** actions
changed the active window between 951×669pt (wide) and 669×951pt (tall).
The later temporary harness preserved that native orientation instead of
issuing `XCUIDevice`'s ineffective orientation request. It measured Basics
and Needs, light, English, full-screen, Bold Text off, in Phrases mode with
no keyboard. The actual grid widths were 835pt wide and 637pt tall.

| Fully open, 180° | Text | Whole phrases at top / columns | Observed scroll | Fit result |
|---|---|---|---|---|
| Wide, 951×669 | Default and AX4 | 8 / 4 | 0pt | PASS: both categories fit |
| Wide, 951×669 | AX5 | 4 / 4, one whole row | 10pt | FAIL for no-scroll fit: the second row extends 10pt below the viewport |
| Tall, 669×951 | Default, AX4 and AX5 | 8 / 3 | 0pt | PASS for grid fit; fold placement is a separate check |

Device Hub's partial pose was then independently read through RocketSim's
hinge state: **130°**, not an assumed half-angle. The same two active-window
sizes were measured with these results:

| Partly folded, 130° | Text and appearance | Whole phrases at top / columns | Observed scroll | Fit result |
|---|---|---|---|---|
| Tall, 669×951 | Default and AX5; light | 8 / 3 | 0pt | PASS for grid fit |
| Wide, 951×669 | Default; dark | 8 / 4 | 0pt | PASS for grid fit |
| Wide, 951×669 | AX5; dark | 4 / 4, one whole row | 10pt | FAIL for no-scroll fit |

The native rotation and active-display captures answer the missing
simulator poses; they do not establish that Home avoids the fold. In the
wide rendering the fold crosses **No, Conversation, Please and Hello**.
In the tall AX5 rendering it appears in the gap below Again/Get Attention.
That one gap is not a proof of safe placement at other sizes, nor a check
of `ReservedRegion`, the camera's inactive region, Snap to Item or physical
folding behavior. The tall layout still has three phrase columns; the
owner's fold-layout requirements remain Wave 3 item 6's code work.
No label was observed breaking mid-word in these kept active AX5
captures. The wide bottom row is partly clipped until it scrolls, as the
10pt measurement records. This visual check is limited to the captured
states, not a complete rendered-word test of every phrase and pose.

- [Open wide AX5, active display](ui-test-evidence/2026-10-25-home-checks/duo-open-wide-ax5-basics-active-display.png)
- [Open wide AX5, fold](ui-test-evidence/2026-10-25-home-checks/duo-open-wide-ax5-fold.png)
- [Open tall AX5, active display](ui-test-evidence/2026-10-25-home-checks/duo-open-tall-ax5-basics-active-display.png)
- [Open tall AX5, fold](ui-test-evidence/2026-10-25-home-checks/duo-open-tall-ax5-fold.png)
- [Partial wide AX5, dark active display](ui-test-evidence/2026-10-25-home-checks/duo-partial-wide-ax5-dark-active-display.png)
- [Partial wide AX5, dark fold](ui-test-evidence/2026-10-25-home-checks/duo-partial-wide-ax5-dark-fold.png)

Raw exports remain in `build/evidence/2026-10-25/`, under
`home-duo-open-native-wide`, `home-duo-open-native-tall`,
`home-duo-book-native-tall` and `home-duo-book-native-wide-dark`.

An independent evidence check compared 36 earlier non-Duo measurement
JSONs with their accessibility trees: the recorded window and grid frames
matched. That cross-check does not resolve the open-Duo window-API or
inactive-display screenshot discrepancy.

### First-launch flake: three cold local boots

On the iPhone 17 simulator, iOS 27.0, three separate simulator boots ran
`HomeAccessibilityOrderTests/testQuickControlsComeFirstInEveryStateAtDefaultText`
directly through `xcodebuild`, without the script's app warm-up or a manual
app warm-up. The installed app and test bundles were reused; these were
cold boots, not three fresh installations. Each run passed its one test
with zero failures, skips or expected failures (3/3 passing attempts).
The selected test reads Home's full accessibility snapshot immediately
after the launch helper finds Yes, the path of the historical first-test
`kAXErrorServerNotFound` failure.

[Cold-run summaries](ui-test-evidence/2026-10-25-home-checks/cold-launches.json)
preserve the results. The raw summary is
`build/evidence/2026-10-25/cold-launches.json`; local logs are
`/private/tmp/brickson-cold-iphone-1.log`,
`/private/tmp/brickson-cold-iphone-2.log` and
`/private/tmp/brickson-cold-iphone-3.log`.

**PASS for these three local attempts; flake cause unresolved.** No startup
timeout or `kAXErrorServerNotFound` reproduced. The raw summaries retain audio
session runtime warnings; these runs do not establish their relation to
the older CI failure. No app fix is justified by a non-reproduction, and
no sleep, timeout, retry or assertion changed.

### What the completed simulator pass leaves open

The requested independent size, scroll, closed/open/partial-Duo and cold-
boot observations are recorded above. Failing fit, audit and existing-Duo
checks remain failures. No app or test assertion was changed to clear them.

Remaining checks are Put Back's covered AX5 phone position with native
input; iPad and Duo windowing, Split View and whether a second app window
opens; the reserved-fold/camera APIs and exact fold placement; and controlled
physical-device input, sound, call handoff and folding checks. The existing
open-Duo landscape skips and geometry-query discrepancy also remain test
coverage gaps. The fewer-tiles proposal is a separate docs-only job based
on these measurements, not an implementation in this record.


## Commits

- `dad5760`: the initial keyboard/AX5 evidence record, affected HANDOFF
  lines and the owner's stricter JSON-trial timing in DECISIONS.
- This follow-up adds the later Home, native Duo and cold-boot measurements,
  the limited physical-device observation and their evidence. No app code,
  temporary measurement source or generated project is committed.

### Informal physical-iPhone observation

After the initial simulator record, the current main app code (`8316743`)
was built, signed with the existing development identity and installed on
a physical iPhone 17 Pro Max, iOS 27.0.1. Device app and process inventories
confirmed installation and launch of Brickson 0.1.0 (1). Signing settings
were command-line arguments only; no project setting changed. This is
installation evidence, not a communication or gaze test pass.

The owner then reported that, while Type was selected, Maybe and the
other phrase/category controls that had turned white showed no gaze
outline: the grey arrow remained over them. Looking at coloured controls
such as Settings, and at individual keyboard keys, did produce an outline.
The supplied screenshot shows the arrow inside Maybe with no additional
outline around that tile.

**Conditions and limit:** the phone was handheld, not mounted; position,
calibration, settings and repeated trials were not controlled. This does
not establish that every disabled control is excluded from snapping, that
it shelters a resting pointer from nearby enabled controls, or that the
Clear/Put Back states are safe. The owner explicitly deferred formal
device testing until a proper setup is available. Keep those checks open;
continue work that does not need a person testing the iPhone.

## Verified

**Main refresh after the measurements:** PR #56 merged as `6d040d5` while
this record was being finished. Its source is incorporated by a merge
commit, preserving its new Settings placement and the owner's accepted
chain limits. The measurements above remain a dated record of app code
`8316743`, before that change; the old Duo Settings finding has not been
rescored on the new app. The native gate on the refreshed source passed:
740 tests, 731 passed, 0 failed, the existing issue #19 skip and 8 strict
expected failures. Coverage is 67.7%; the String Catalog is unchanged.
The result is
`build/TestResults/post-alarm-docs-unit/unit-destination.xcresult`; log
`/private/tmp/brickson-post-alarm-docs-unit.log`. Relative to refreshed
`main`, this PR changes no app or test source.

The two keyboard runs used:

```sh
DESTINATION='platform=iOS Simulator,id=<test-simulator>' \
  TEST_RESULTS_DIR=build/TestResults/<configuration> \
  scripts/test.sh ui '-only-testing:BricksonUITests/KeyboardProbeTests'
```

Local result bundles, relative to the test worktree:

- `build/TestResults/keyboard-se-standard/ui-destination.xcresult`
- `build/TestResults/keyboard-se-zoomed/ui-destination.xcresult`

Their full logs were saved at `/private/tmp/brickson-keyboard-se-standard.log`
and `/private/tmp/brickson-keyboard-se-zoomed.log`. Attachments were exported
under `build/evidence/2026-10-25/`. The committed screenshots and frame
file above preserve the relevant evidence beyond those local folders.

All five Python suites passed: documentation 45, hooks 124, site 7,
runner 54, Xcode selection 21 (251 total). The full local unit gate
(`CI=true scripts/test.sh unit`, on the same 13-inch iPad simulator)
passed: 728 tests, 720 passed, 0 failed, the existing issue #19 skip and
7 strict expected failures. The String Catalog is unchanged. The result
is `build/TestResults/mac-checks-unit/unit-destination.xcresult`; the
full log is `/private/tmp/brickson-mac-checks-unit.log`. Hosted CI is
pending on the follow-up when this record is prepared; the initial hosted
run was cancelled after its unit job passed. The temporary measurement
source has been removed and the launch helper restored exactly. The fresh
final native gate on that restored source also passed: 728 tests, 720
passed, 0 failed, 1 existing issue #19 skip and 7 strict expected failures,
with the String Catalog unchanged. Its result is
`build/TestResults/mac-checks-final-unit/unit-destination.xcresult`; log
`/private/tmp/brickson-mac-checks-final-unit.log`. No new app behavior or
committed regression test is claimed.

## Not verified

| Ordered handoff check | Status / next step |
|---|---|
| Real iPhone: targeting or scanning stops on dimmed tiles/categories while typing | DEFERRED for controlled testing. The informal handheld observation above is recorded, without a pass/fail conclusion. |
| Home at AX4/AX5 and Display Zoom, scroll amounts | MEASURED for the iPad matrix, standard iPhone and zoomed default iPhone. Restricted zoomed AX4/AX5 captures fail whole-phrase access in light and dark; their maximum scroll ranges remain unestablished. |
| iPhone Duo folded and unfolded Home tests in Device Hub | RUN WITH FAILURES. Closed: 14 existing passes, 1 audit failure, 2 landscape skips, 2 expected failures, plus the measurement pass. Open: 8 passes, 9 failures, 2 landscape skips, 0 expected failures. Native open and 130° partial measurements are complete for the sizes above; wide AX5 scrolls 10pt and the fold crosses controls. |
| Calls and Add Audio in Calls on a physical iPhone | NOT RUN; needs a device and the owner. |
| First-launch flake diagnosis | NOT REPRODUCED in 3 separate local cold boots without app warm-up; selected first-snapshot test passes 3/3. Cause unresolved; no app fix. |
| Fewer-tiles proposal | NEXT as a separate docs-only job. The completed measurements establish whole-row capacity; restricted zoomed windows and closed Duo AX5 first need an arrangement that can show a whole tile. Scroll-range limits remain explicit above. |
| Wave 3 item 6 | NEXT as a separate implementation PR. PR #56 merged after these measurements, clearing the owner's alarm-path prerequisite. This record changes no Settings or Home code. |
| JSON project trial | DEFERRED. The owner now requires released Xcode 27.2 and its first fix release before even the trial. Apple's releases and system-requirements pages, read 2026-10-25, list 27.2 RC and stable 27.1. XcodeGen stays in place. |

No physical-device sound, Switch Control, Dwell, Eye Tracking or Snap to
Item safety, or Phone handoff is established. Dark appearance is covered
by the zoomed iPad AX5 Home measurements, the restricted zoomed-phone
AX4/AX5 captures and partial-Duo wide default/AX5 measurements. The other
completed Home measurements are light. AX3, other languages, iPad floating/split keyboards
and windowed apps were not included. App identity, price and App Store
Connect account are unchanged.

## Follow-ups

1. **Owner, deferred until a mounted setup is ready:** on a real iPhone, enter Type and
   observe whether accessibility targeting stops on the dimmed phrase
   tiles and categories, or skips them toward Clear/Put Back. Record the
   exact Apple input method, OS, text size, Display Zoom and result. The
   device-check table in HANDOFF keeps the rest of the procedure.
2. **Next Mac pass:** reproduce Put Back's AX5 keyboard coverage with
   native input; investigate the Sounding audit finding and the existing
   Duo window/rotation test failures before choosing any small fix. Keep
   the restricted zoomed-phone scroll-range limits explicit. Windowing,
   second-window and reserved-fold/camera checks remain separate. PR #56
   has now merged; use its Settings placement and accepted chain limits
   as the starting point for the separate Wave 3 item 6 job.
3. **First-launch work:** no code change from the three passing cold
   attempts. Preserve a reproduction and investigate before choosing a
   fix; deterministic safety-band, rotation and audit findings are separate.

Apple sources for the deferred toolchain check:
[releases](https://developer.apple.com/news/releases/) and
[system requirements](https://developer.apple.com/xcode/system-requirements/).
