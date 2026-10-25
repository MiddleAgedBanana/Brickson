# Mac keyboard checks and AX5 typing

*2026-10-25. Branch `codex/mac-simulator-checks`. Codex, following the
owner's ordered Mac handoff, from main `8316743` (PR #53 merged).*

## What changed and why

This is a measurement record. No app, layout, test or Settings code changes.
The keyboard checks below ran; the physical-iPhone check needs the owner,
so work stops there in the supplied order. The remaining jobs are not
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

## Commits

One documentation commit: this record, its evidence, the affected
HANDOFF lines and the owner's stricter JSON-trial timing in DECISIONS.
No generated project is committed.

## Verified

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
pending when this record is prepared. There are no new tests, so no
new failing-first claim is made.

## Not verified

| Ordered handoff check | Status / next step |
|---|---|
| Real iPhone: targeting or scanning stops on dimmed tiles/categories while typing | NOT RUN. Needs the owner to operate and observe the physical input method. A discoverable device is not a device result. |
| Home at AX4/AX5 and Display Zoom, scroll amounts | NOT RUN as a separate matrix. Some existing scrolling is visible in the keyboard captures; its total range has not been measured. |
| iPhone Duo folded and unfolded Home tests in Device Hub | NOT RUN; remains after the first device stop point. |
| Calls and Add Audio in Calls on a physical iPhone | NOT RUN; needs a device and the owner. |
| First-launch flake diagnosis | NOT COMPLETED. Neither selected probe run had a launch timeout; no fix is justified by these runs. |
| Fewer-tiles proposal | NOT STARTED. Needs the complete size/scroll measurements. |
| Wave 3 item 6 | NOT STARTED. The owner's alarm-path merge prerequisite still applies. Settings root rows are untouched. |
| JSON project trial | DEFERRED. The owner now requires released Xcode 27.2 and its first fix release before even the trial. Apple's releases and system-requirements pages, read 2026-10-25, list 27.2 RC and stable 27.1. XcodeGen stays in place. |

No physical-device sound, Switch Control, Dwell, Eye Tracking, Snap to
Item or Phone handoff is established. Dark appearance, AX3/AX4, other
languages, iPad floating/split keyboards and windowed apps were not
included. App identity, price and App Store Connect account are unchanged.

## Follow-ups

1. **Owner, the requested stop point:** on a real iPhone, enter Type and
   observe whether accessibility targeting stops on the dimmed phrase
   tiles and categories, or skips them toward Clear/Put Back. Record the
   exact Apple input method, OS, text size, Display Zoom and result. The
   device-check table in HANDOFF keeps the rest of the procedure.
2. **Next Mac pass:** reproduce Put Back's AX5 keyboard coverage with
   native input, then finish the Home size/scroll and Duo measurements
   before proposing fewer tiles. Do not infer a fix from a single keyboard
   configuration or change Settings root rows while their thread works.
3. **First-launch work:** preserve a local reproduction before changing
   app code. A deterministic safety-band failure is not the launch flake.

Apple sources for the deferred toolchain check:
[releases](https://developer.apple.com/news/releases/) and
[system requirements](https://developer.apple.com/xcode/system-requirements/).
