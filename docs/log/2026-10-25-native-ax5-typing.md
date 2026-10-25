# Native AX5 typing follow-up

*2026-10-25. Codex. Documentation and simulator evidence only.*

## What changed and why

Closed the native-input reproduction left by PR #55. The earlier
[Mac record](2026-10-25-mac-keyboard-checks.md) did not establish iPhone
Return, and asked for a native check of covered Put Back before a fix.
This follow-up records both on unchanged app code `6d040d5`, after PR #56.
Main `37c2e0b` supplies the merged PR #55 notes. No app or test changes.

## Verified

Mac, Xcode 27.1 (27A9275); iPhone 17 simulator, iOS 27.0,
402×874pt portrait, Full Screen, AX5, light, test-only storage. The
keyboard was the full US English software keyboard with predictions.
No physical iPhone was operated.

| Check | Result |
|---|---|
| Software Return | **Pass for visible app state.** Entered the neutral test message “Blue kites”; restored the full software keyboard after HID entry hid it; pressed its visible Return key in Device Hub. “Speaking” appeared. Phrases then displayed “Blue kites” as the last-spoken message; reopening Type retained the same draft. This is not evidence of sound. |
| Clear | **Pass for empty field.** With the full keyboard showing, activated Clear. The field emptied, Speak and Clear became disabled, and the full keyboard stayed visible. |
| Put Back while the full keyboard shows | **Fail for visual reachability.** Its y 547–624 frame is behind the keyboard, whose prediction region begins at y 546. It was absent from Device Hub's visible control list after Clear. No activation through a command that bypasses the keyboard was used to claim a pass. |

Evidence under `docs/evidence/2026-10-25-native-ax5-typing/`:

- [Full keyboard before entry](../evidence/2026-10-25-native-ax5-typing/full-keyboard.png).
- [Message after software Return and Phrases](../evidence/2026-10-25-native-ax5-typing/after-return.png).
- [Empty field and covered Put Back after Clear](../evidence/2026-10-25-native-ax5-typing/after-clear.png).
- [Observation record and snapshot frames](../evidence/2026-10-25-native-ax5-typing/observations.json).

RocketSim's compact keyboard summary said hidden even while full keys
were rendered. HID entry also hid the keyboard and briefly exposed
off-screen key coordinates. Those summaries are not the keyboard-fit
measurement. Device Hub's **Device → Keyboard → Toggle Software
Keyboard** restored the full keyboard; its rendered image and
prediction-row frame establish the y 546 top. The native Return action
was performed only after that restoration.

The complete native unit gate passed on identical app/test sources
before this documentation commit: 740 ran, 731 passed, 0 failed, one
existing issue #19 skip and eight strict expected failures; coverage
67.7%, String Catalog unchanged. Result:
`build/TestResults/duo-probe-restored-unit/unit-destination.xcresult`;
log: `/private/tmp/brickson-duo-probe-restored-unit.log`.

## Not verified

- Put Back's functionality with a covering keyboard, a fix for its
  placement, or a complete AX5 UI-suite pass. The failed reachability
  result remains open.
- Sound, real tracking, Snap to Item, Switch Control, mounting/calibration
  or Phone handoff. The informal earlier handheld observation is not a
  controlled device pass; physical checks remain deferred.
- Final-head hosted CI before this PR runs.

## Follow-ups

Use this native failure to give Put Back a layout answer, with an
automated failing reproduction before a fix. Preserve its fixed frames
and score the resulting held activations. No claim that the current
typing layout is fully accessible follows from the two passing actions
above.
