# Settings row and Family Setup simulator checks

*2026-10-26. Branch `codex/settings-simulator-checks`. Codex.
Documentation and simulator evidence only.*

## What changed and why

Records the AX3 and dark-appearance placement combinations left by PR #56,
the known scrolled-entry gap, and the physical-device checks still required.
App sources are unchanged from main `e568aa7`; no app or test change ships.
The existing placement decision and accepted gaps remain unchanged
(docs/DECISIONS.md, "Settings' first row, placed from Home's frames").

## Commits

This pull request adds the observation record, evidence and handoff links.
The tested app baseline is `e568aa7`; app and test sources are unchanged
in the delivered documentation commit.

## Verified

Mac, Xcode 27.1 (27A9275), XcodeGen 2.46.0; iOS 27.0 simulators:
iPad Pro 13-inch (M5), 1032×1376pt portrait and 1376×1032pt landscape;
iPhone 17, 402×874pt portrait. Full Screen, standard Display Zoom, Bold
Text off, English, fresh test-only storage. No keyboard was opened.
The phone keeps portrait when landscape is requested; those repeated
portrait captures are not landscape coverage.

The installed toolchain matched the newest released Xcode shown by
[Apple's requirements](https://developer.apple.com/xcode/system-requirements/)
and [release list](https://developer.apple.com/news/releases/), cross-checked
with [Xcode Releases](https://xcodereleases.com/) on this date. These version
numbers record the run, not a toolchain pin.

A temporary UI observation harness launched through `launchedApp`, using
`--appearance=light|dark` and the AX3/AX5 launch categories in
[the retained probe](../evidence/2026-10-26-settings-checks/SettingsObservationProbeTests.swift.txt).
It captured each screen and button frames, checked Set Up Step by Step's
leading edge/top/width within 1pt of the root row and height at least the
root's, and rejected another hittable button overlapping that row. Moving
the child row, narrowing it or adding an overlapping control would fail
those assertions. Home's rendered gutter brightness independently checked
appearance; the Settings screenshots were also visually inspected. The
probe was removed and the project regenerated before the unit gate.

| Check | Result |
|---|---|
| iPad AX3, light and dark, portrait | **PASS — row placement.** Root `(x 669.5, y 354, w 346.5, h 78)`; child same x/y/w, height 116.5pt. |
| iPad AX3, light and dark, landscape | **PASS — row placement.** Root `(1013.5, 356, 346.5, 78)`; child same x/y/w, height 116.5pt. |
| iPhone AX3, light and dark, portrait | **PASS — row placement.** Root `(39, 320, 347, 78)`; child same x/y/w, height about 116.33pt. |
| Default/light control, both devices and both iPad orientations | **PASS — row placement.** The same assertions pass; detailed frames are retained below. |
| Settings scrolled before choosing Family Setup, iPhone AX5 dark | **FAIL — known visible-position gap reproduced.** A settled 90pt root scroll moves the row from y 317 to y 227. The child starts at y 317 again. The fixed activation point `(201, 299.33)` becomes empty space, about 17.67pt above the child. Set Up Step by Step is nearest by both centre and edge at that point; this is geometry, not a physical Snap to Item result. |

The AX5 scroll trial selected the ScrollView containing `familySetup`,
used a slow drag with a hold before release, checked a retained offset
and a hittable row, then tapped its recorded centre using a fixed window
coordinate. The row was about 144.67pt tall; the child was about 209.67pt.
The whole old row is not preserved. The nine additional geometry samples
include the full accessibility bounds, including the part behind the
navigation bar; they are not proof those points could activate the old
row, or of a real held-look chain. No repeated activation was sent after
Family Setup opened.

Screenshots, unchanged from the simulator captures:

- iPad AX3 dark: [portrait root](../evidence/2026-10-26-settings-checks/ipad-observation-root-AX3-text-dark-requested-portrait.png), [portrait Family Setup](../evidence/2026-10-26-settings-checks/ipad-observation-family-AX3-text-dark-requested-portrait.png), [landscape root](../evidence/2026-10-26-settings-checks/ipad-observation-root-AX3-text-dark-requested-landscape.png), [landscape Family Setup](../evidence/2026-10-26-settings-checks/ipad-observation-family-AX3-text-dark-requested-landscape.png).
- iPhone AX3 dark: [root](../evidence/2026-10-26-settings-checks/iphone-observation-root-AX3-text-dark-requested-portrait.png), [Family Setup](../evidence/2026-10-26-settings-checks/iphone-observation-family-AX3-text-dark-requested-portrait.png).
- **Failing AX5 scroll case:** [before scrolling](../evidence/2026-10-26-settings-checks/iphone-actual-scroll-root-before-AX5-dark-portrait.png), [immediately before fixed-point entry](../evidence/2026-10-26-settings-checks/iphone-actual-scroll-root-immediately-before-entry-AX5-dark-portrait.png), [Family Setup after entry](../evidence/2026-10-26-settings-checks/iphone-actual-scroll-family-opened-AX5-dark-portrait.png).
- Frame records: [iPad matrix](../evidence/2026-10-26-settings-checks/ipad-observations.json), [iPhone matrix](../evidence/2026-10-26-settings-checks/iphone-observations.json), [corrected scroll trial and image provenance](../evidence/2026-10-26-settings-checks/actual-root-scroll.json), [run results](../evidence/2026-10-26-settings-checks/run-results.json), [environment/provenance](../evidence/2026-10-26-settings-checks/provenance.json).

### Probe limitations and failed attempts

The iPad's initial two probe tests passed. On the phone, the matrix passed,
but the first scroll test failed at Home's first Yes lookup, before
Settings opened, with
`kAXErrorServerNotFound`, following a 60-second automation-session wait.
The retained recording's [last available decoded frame](../evidence/2026-10-26-settings-checks/iphone-startup-failure-final-frame.png)
is blank white; video PTS 66.491667s, not claimed to be the exact failure
instant. Its provenance is retained above. Root cause is unresolved; the
app was not changed to address it.

The original scroll probe, including its one passing phone retry, selected
`app.scrollViews.firstMatch`, which could belong to Home beneath the cover.
**Its zero row offsets are discarded as scroll evidence.** They do not
show that Settings cannot scroll on either device. The corrected probe's
first drag scrolled 286pt and took the row offscreen, so its preconditions
failed and it made no entry attempt ([frame](../evidence/2026-10-26-settings-checks/iphone-overscrolled-probe.png), [record](../evidence/2026-10-26-settings-checks/overscrolled-probe.json)).
The slow-drag corrected run passed its observation preconditions and
captured the known placement failure above. Its [source](../evidence/2026-10-26-settings-checks/SettingsScrolledRootProbeTests.swift.txt)
is retained as text only. The earlier version differed only in its drag:
`start.press(forDuration: 0.1, thenDragTo: end)`, with no specified velocity
or hold before release.

Local result bundles: `build/TestResults/settings-observation-ipad/ui-destination.xcresult`
(two passed), `build/TestResults/settings-observation-iphone/ui-destination.xcresult`
(one matrix passed, one startup failure),
`build/TestResults/settings-observation-iphone-scroll-retry/ui-destination.xcresult`
(one passed, invalid scroll targeting),
`build/TestResults/settings-actual-root-scroll/ui-destination.xcresult`
(one precondition failure), and
`build/TestResults/settings-actual-root-scroll-slow/ui-destination.xcresult`
(one passed). A passing observation test records the known gap; it does
not mean the scrolled placement passes.

### Native and documentation gates

After both temporary compiled probes were removed, the repository unit
script regenerated the project and passed: **740 total, 731 passed,
0 failed, one existing issue #19 crash-probe skip, eight strict expected
failures**. Coverage 67.7%; String Catalog unchanged. Result:
`build/TestResults/settings-docs-unit/unit-destination.xcresult`; private
console log `/private/tmp/brickson-settings-docs-unit.log`.
The app and test sources match `e568aa7` byte for byte. The independent
report-only verifier passed all five Python suites: docs 45, hooks 124,
site 7, runner 54 and Xcode selection 21; `git diff --check` passed.
Hosted CI is reported on the pull request; no hosted result is claimed
by this local record.

## Not verified: physical devices

**iPad held-look check: UNVERIFIED. iPhone held-look check, including
AX5: UNVERIFIED. Both still need a physical device.** No available connected
physical iPad or iPhone was found; the owner requested that these remain
unverified with a reproducible procedure. No pointer-rest observation,
real Snap to Item selection, repeated dwell, sound or comfort result is
claimed. Windowed iPad, Display Zoom, Bold Text and non-English layouts
were not exercised in the simulator matrix. A retained root scroll on
iPad was not exercised by the corrected probe. No AX3 system accessibility
audit or rendered-pixel contrast measurement was run.

### Environment and settings for the physical run

Use a supported iPad and iPhone with the build/commit being checked installed
([local setup](../GETTING_STARTED.md)). Secure the device on a stable mount
about 45cm from the face, with the front camera unobstructed and the face
adequately lit. Start in Full Screen with standard Display Zoom, Bold Text
off and the starter library; record any deliberate variation. Complete Eye
Tracking calibration with the tester, and recalibrate after repositioning
or rotating if needed. Apple gives the positioning and calibration guidance
in its [iPad](https://support.apple.com/guide/ipad/ipad2cd35723/ipados)
and [iPhone](https://support.apple.com/guide/iphone/iph66057d0f6/ios)
guides, including supported-model links. AbleNet also recommends a
consistent mount, tester-led calibration and short sessions with breaks
([trial guidance](https://support.ablenetinc.com/aac-education-and-resources/for-slps/alternative-access/trialing-eye-gaze-for-aac-users/)).

In system Settings, choose Accessibility → Eye Tracking, enable it and
turn **Snap to Item on**. Enable Dwell Control; record the actual dwell
duration, Movement Tolerance, smoothing, hot corners, Auto-Hide and fallback
action. For this repeated-tap trial, use Tap as the dwell fallback; Pause
Dwell would change the sequence. If using an external AssistiveTouch pointer
instead, record its device, Dwell Control and Snap to Item settings and
report that as a separate input-method result. See Apple's [Dwell setup](https://support.apple.com/guide/ipad/use-assistivetouch-ipad9a2466d3/ipados)
and AbleNet's [Eye Tracking setup](https://support.ablenetinc.com/quicktalker-freestyle/how-to/turn-on-eye-tracking/).
Keep settings constant within each comparison and restore changed system
preferences after testing. These are test conditions, not a claim that one
dwell duration fits every person.

### Steps and result criteria

1. Record date, model, OS, installed app commit/build, input method,
   mount/distance, lighting, orientation, actual window size, text size,
   appearance, Display Zoom, Bold Text and the settings above. Begin at AX3
   in dark appearance; no phrase or alarm should already be active.
2. From Home, dwell on Settings. Keep looking at the same screen location
   through the transition and subsequent dwell activations. Record the
   pointer location and highlighted target on Settings' first screen,
   Family Setup and Set Up Step by Step's first step. Distinguish a pointer
   that remains at the gaze point from one that snaps to an item's centre.
3. Repeat on the iPad in portrait and landscape, recalibrating as needed;
   use the phone's supported portrait app orientation. Repeat the phone at
   **AX5, the largest accessibility size**, after enabling Larger
   Accessibility Sizes in system Accessibility → Display & Text Size →
   Larger Text. Apple documents [larger text](https://support.apple.com/guide/iphone/iph3c076905a/ios).
4. Reopen Settings at large text, scroll its first screen while Family
   Setup remains visible, and choose it by dwell. Hold the look at the
   row's **visible pre-navigation spot**; record what occupies it on Family
   Setup and what is actually selected next. Record a settled scroll
   offset, not rubber-band bounce. If the screen cannot retain an offset,
   label that trial “no sustained scroll”; it does not test the gap.
5. Keep screenshot paths for each screen and a video if screenshots omit
   the pointer or highlight. Record every activation in order and repeat
   an unexpected result once under unchanged conditions. Mark each trial
   PASS only for the behavior actually observed; mark unchosen saves,
   closing, speech or alarms FAIL with the sequence and evidence. Leave
   inconclusive trials UNVERIFIED.

The unscrolled target is Set Up Step by Step over the root row. Existing
known hazards remain: a held chain can save a setup answer; on the phone
at AX5 it can close Settings through the first step onto a Home control
that speaks or alarms. Have the separate Stop control available during
the trial. Observe these physically rather than treating the simulator's
nearest-centre/nearest-edge calculations as the pointer's behavior.
Apple's [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)
was read before the operator sources above; the numbered sequence is this
project's test protocol.

## Follow-ups

The next Settings work owns scrolled-entry and first-step placement.
The owner or a device operator still needs to run both physical trials
above and record their results. No compatibility claim is closed by this
simulator report.
