# The room Home keeps for Apple's keyboard

*2026-10-23. Branch `claude/project-thread-o4bpnw`. A cloud thread asked
to bring typing onto Home, which built its prerequisite instead.*

## What changed and why

The thread was asked to bring typing onto Home if ROADMAP items 3 and 9
were done, and otherwise to build the smallest prerequisite. They are not
done. Item 3 still lists the slot plan's other wells and no scrolling on
small windows as left to build, and item 9's screens still have open
placement questions. More to the point, the decision typing waits on,
docs/DECISIONS.md, "Get Attention and Stop on Home", *Open: typing needs
C in one row*, had no measured answer: nobody had said how much room
Home must leave for the keyboard on a window no one had measured, or
whether today's safety row already fits. Typing on Home cannot be built
or reviewed without that number. This pull request supplies it, and
nothing a person sees on Home changes.

- **`KeyboardAllowance`** (`Brickson/Layout`), a plain type: given only
  the window's size, how tall Apple's keyboard may be and where the band
  above it ends (docs/DECISIONS.md, "Typing is a state of Home"). Three
  shapes of window, each with a measured reference keyboard: wider than
  tall (498pt on a 1032pt-tall window), taller than wide (403pt on
  1376pt), and taller than wide but under 600pt wide (328pt on 874pt). A
  window keeps its reference keyboard however short it is, and a taller
  window gets one grown in proportion, never more than the window. Text
  size is not an input: the keyboard measured the same at the default
  and the largest text size. It names no device.
- **`KeyboardProbeTests` runs on every UI run** instead of only when
  asked. In each orientation (portrait only on iPhone) at the default
  and largest text sizes it measures Apple's keyboard on the probe screen
  and fails if the keyboard reaches above the allowance's limit; then it
  opens Home in the same window and fails if Yes, No, Emergency, Again or
  Get Attention ends below that limit. It prints `KEYBOARD-PROBE` and
  `KEYBOARD-BAND` lines and attaches the JSON and a capture of Home.
  The UI tests compile `KeyboardAllowance` too (`project.yml`), so the
  rule they check is the app's own.
- **Keyboards from other apps are refused** (docs/DECISIONS.md,
  "Third-party keyboards refused in 1.0", now built).
  `BricksonAppDelegate` answers `application(_:shouldAllowExtensionPointIdentifier:)`
  with false for `.keyboard` only, handed to SwiftUI by
  `@UIApplicationDelegateAdaptor` in `BricksonApp`. The allowance is
  built on Apple's keyboards, and another app's can be taller; a
  keyboard given Full Access can also send what is typed to its maker.
  Apple's keyboards, dictation and the keyboard features of Switch
  Control and Eye Tracking are part of the system and unaffected. SwiftUI
  has no way to refuse an extension, so this is a UIKit use, recorded in
  docs/DECISIONS.md, "Apple's current frameworks first". Apple's
  documentation (`uiapplicationdelegate/application(_:shouldallowextensionpointidentifier:).md`,
  read 2026-10-23) lists it from iOS 8 and not deprecated, and the
  keyboard as the only extension type an app can refuse.
- **The probe opens through `LaunchOptions` alone.**
  `KeyboardProbeLaunch` and its tests are deleted: `LaunchOptions`
  already parses `--screen=keyboard-probe` (`LaunchOptionsTests`), and
  `BricksonApp` passes its answer to `replacedByKeyboardProbe(when:)`,
  which is the view itself in a release build.

### What main's CI already shows

Home's frames from main's last CI run (39952208907, the `.xcresult`
captures read on Linux), against the allowance:

| Window | Safety row ends (default; largest text) | Band limit |
|---|---|---|
| 13-inch iPad, portrait, 1032×1376 | 326.5; 437.5 | 973 |
| 13-inch iPad, landscape, 1376×1032 | 326.5; 437.5 | 534 |
| iPhone 17, portrait, 402×874 | 308.7; 449.3 | 546 |

So on every window CI tests, today's two-row safety row already ends
above the keyboard. The windows where it does not are shorter wide ones:
the 13-inch iPad with Display Zoom at Larger Text (1032×774, limit 276)
and, by the rule, an iPad mini in landscape (1133×744, limit 246). On
the zoomed iPad even one row ends at 230.5 at the default text size and
341.5 at the largest, so that window at the largest text sizes needs a
named exception or another arrangement (*Follow-ups*). These are in
docs/DECISIONS.md, "Get Attention and Stop on Home", *Open: typing needs
C in one row*.

## Commits

The commits on `claude/project-thread-o4bpnw`, listed in the pull
request: the allowance and its tests; the always-on keyboard check and
the probe's cleanup; refusing other apps' keyboards; the documents.

## Verified

- **This cloud session cannot build or run the app** (no Xcode). The
  change is untested on iOS until GitHub CI passes.
- `KeyboardAllowanceTests` ran on Linux with Swift 6.4.1, in a scratch
  package holding only `KeyboardAllowance.swift` and its tests, in the
  Swift 6 language mode with default main-actor isolation: 6 tests
  passed. Each failed when its rule was broken: the wide reference at
  497, the `max` dropped (a short window gets a proportional keyboard),
  the proportion dropped, the window cap dropped, the narrow width at
  400, and `>=` for wide (a square window counted as wide).
- `BricksonAppDelegateTests` fail if the delegate allows custom
  keyboards, if it refuses every extension, or if `BricksonApp` stops
  handing it to SwiftUI (the third asks the running app's delegate).
  Not run here: they need iOS.
- The frames above were read from main's CI result bundles, not
  measured again.

## Not verified

- Whether CI's simulators show a keyboard within the allowance on this
  branch: the first run of the always-on probe is CI's. The iPhone's
  reference (iPhone 17 Pro, 402×874, top 546) came from the reference
  app on iOS 27.0, not from Brickson. If CI's iPhone keyboard is taller,
  the test says so and the reference rises with a new row in
  `KeyboardAllowanceTests`.
- That SwiftUI forwards `shouldAllowExtensionPointIdentifier` to the
  adaptor's delegate: `theRunningAppRefusesCustomKeyboards` checks it on
  CI. Whether a third-party keyboard is really absent needs a device
  with one installed (docs/HANDOFF.md, *Checks that need a real device*).
- Windowed iPad apps (Split View, Slide Over, Stage Manager, iPadOS's
  resizable windows), the floating and split iPad keyboards, keyboards
  for other languages, a hardware keyboard's bar, and iPhone Duo's
  displays. The rule is conservative for short windows, but none of
  these has been measured.
- Real devices: every number here is from a simulator.
- How much longer the UI job takes: the probe adds two launches per
  test, four tests on the iPad and two on the iPhone.

## Follow-ups

1. **The typing state on Home** *(the next typing thread)*: Phrases and
   Type in A's trailing column, and C in one row wherever its two rows
   end below `KeyboardAllowance`'s limit, chosen from the space by the
   layout, never by device. Then the per-state checks: every control in
   the band reachable with the keyboard up, frames unchanged when it
   shows, and Return speaking once, in UI tests.
2. **The zoomed 13-inch iPad at the largest text sizes** *(the same
   thread)*: one row still ends below the limit. Name and measure the
   exception in docs/DECISIONS.md, or find an arrangement that fits.
3. **More windows** *(a thread on the owner's Mac)*: measure the keyboard
   on an iPad mini, an 11-inch iPad and the largest iPhone, with Display
   Zoom, and in a resizable iPad window, and add each as a row in
   `KeyboardAllowanceTests`.
4. **A device check** *(owner)*: a third-party keyboard does not appear
   in Brickson, and the real keyboard's height on each device.
