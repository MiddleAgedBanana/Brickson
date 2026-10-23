# Get Attention and Stop on Home

*2026-10-23. Pull request #38 (`claude/project-thread-apigc0`). The Get
Attention and Stop on Home thread (a cloud session).*

## What changed and why

The Get Attention alarm (PR #16) had no control on screen, so a person
who cannot speak had no way to call someone into the room from
Brickson. Now (docs/DECISIONS.md, "Get Attention and Stop on Home";
intent, spec and plan in [`work/get-attention-on-home.md`](../work/get-attention-on-home.md)):

- **Get Attention is on Home in every state**, in the safety row's second
  row directly under Emergency, beside Again. One activation starts the
  alarm by any input method; a second one leaves it sounding. It is
  never disabled, answers to "Get Attention" and "Help" with Voice
  Control, and carries the `playsSound` trait.
- **Stop appears only while the alarm sounds**, in a well of its own at
  the categories' leading top, with a category directly under it. It
  shows "Stop" and also answers to "Stop Alert". The well keeps its
  frame, so nothing moves when Stop appears or goes.
- **What a held activation meets.** Stop is never the control nearest
  Get Attention's spot, and after Stop the nearest control is a
  category, which only changes which phrases show (invariant 10), by
  nearest centre and by nearest edge, at every width.
- **The categories take one of three arrangements** from the width
  (`HomeShape.CategoryArrangement`): a band from 584pt of content (630pt
  with Bold Text), three columns from 304pt (328pt), two below that.
  Settings takes the last cell in each. A library with more than four
  everyday categories keeps the rest in the fourth cell, which scrolls
  (none can be made yet).
- **The status line** shows a problem first, then "Sounding" while the
  alarm sounds, then "Speaking" (`HomeStatusLine`), and VoiceOver hears
  every failed or cut-off alarm (`failureSequence`). Home's
  `AudioSafetyPolicy` now reads the alarm's real state instead of idle.
  While Settings covers Home, which has no Get Attention of its own, an
  alarm problem names Back first: "No alert — Back" (review on this pull
  request). VoiceOver hears low volume and a failed session when they
  appear even while the line shows an alarm or speech warning first
  (`AudioSafetyPolicy.ambientIssue`; before, they were announced only
  when the line itself changed).
- **Colours of their own**, measured and pinned: `AttentionFill`
  `#B45309`, `StopFill` `#0F766E`.
- **Scan order:** Yes, No, Emergency, Get Attention, Again; then the
  message; then Stop while it shows, the categories in order, Settings.
  In the band the first category sits below the others' tops, so Stop
  and the first category carry their own sort priorities
  (`HomeRegion.firstInRegion`, `secondInRegion`).
- **A repeat Get Attention never silences a sounding tone.** A tone
  started while the audio session could not be activated is replaced by
  the next Get Attention, to retry the session; it now plays on until
  its replacement has started, so a held look re-firing the control can
  never leave the alarm silent with Stop gone (Codex's review;
  `AttentionAlertPlayer.start()`).
- **A silent stand-in tone for UI tests**: debug launches with
  `--attention-tone=silent` play `SilentAttentionTonePlayback`, so the
  tests sound and stop the real alarm without the simulator's audio.

The cost is height: a phone gives up a quick-control row (72pt at the
default size), a wide window 176pt. CI's windows still fit the starter
library; a 375×667 phone at the default size, and by the model an
11-inch iPad and an iPad mini in landscape, now scroll at the floor
(docs/DECISIONS.md, *Where the grid still scrolls*).

## Commits

- `55d8352`, `d2937ba`, `1411b46`: the work file's intent, spec and plan.
- `89f6fc8`: the tests first: layout and held-look scoring, names,
  fills, the status line's order, the silent tone, and the UI tests for
  sounding and stopping the alarm (with `ScreenControls.swift`, the
  helpers it shares with `SettingsOnHomeTests`).
- `5e2c1d2`: the category cells and Stop's place in the scan order.
- `a3d98d6`: the code.
- `5d916ab`: Get Attention's rendered words at the largest text size,
  and an accessibility audit while the alarm sounds.
- `7216f29`: the `playsSound` trait.
- `0501469`: the docs, with this file.
- `adb930e`, then `a875dee`: an alarm problem over Settings names Back
  first (Codex's review), test first.
- `5a7b0ca`: main merged in (PR #35, Show Borders on Home).
- `214f61c`: the sparse-library gap under Stop, pinned as a strict known
  issue (Codex's review).
- `a1cbf29`: CodeRabbit's review: the message hazard measured with Again
  off its edge, and how Switch Control counts.
- `cae344b`, then `1b537c8`: ambient problems announced from their own
  source (a second review), test first.
- `7e18850`: points across Stop's well scored, its top pinned as a strict
  known issue (a second review).
- `b3b89bb`, `af31926`: the docs that correct what this change made
  untrue elsewhere and record the open hazards.
- `1bca47e`, then `d504853`: a sounding tone is kept until its
  replacement plays (Codex's review), test first.
- The docs commit that records it.

## Verified

A cloud session: nothing was built for iOS or run outside GitHub CI, and
this work is untested until CI passes. On Linux with Swift 6.3.3, the
pure types compiled and their Swift Testing tests passed, two with their
known issues recorded: `HomeShapeTests`
(every content width from 288 to 1400pt in half points, Bold Text on and
off, default and grown line heights), `ControlNamesTests` and
`AudioSafetyPolicyTests` (without its two announcement tests, which need
Apple's Accessibility module), `CategorySelection.inCell`'s cases, and 26 of
`AttentionAlertPlayerTests` (all but the seven that need Apple's audio
frameworks or the speech engine), around stand-ins for the audio
session's types.
Label widths came from Apple's SF Pro font measured with HarfBuzz, which
matched CI within half a point before.

Each new test, and the change that makes it fail, is in the work file's
*Proof*.

## Not verified

- Nothing ran on a simulator or device from this session; CI is the
  build.
- The frames and margins in the work file's table are a model of CI's
  frames; `GetAttentionOnHomeTests` and `SettingsOnHomeTests` check the
  running app on CI's iPad and iPhone only.
- The 11-inch iPad and iPad mini figures are from the model, not seen
  running.
- Whether Dwell and Snap to Item pick a target by nearest centre or
  nearest edge, and the real tone through the silent switch and the lock
  screen from Home's control: device checks (docs/HANDOFF.md, *Checks
  that need a real device*, a new row).
- What VoiceOver does with `playsSound` on Get Attention.

## Follow-ups

1. **Get Attention in Settings' bar.** Home has Stop now, so the place
   can be filled; on wide windows Settings' root puts its note under it,
   so its chain needs scoring first (docs/HANDOFF.md, *Known gaps*).
   *(a new thread)*
2. **The windows that now scroll** (375×667 at the default size; 11-inch
   iPad and iPad mini in landscape): the layout engine finds an
   arrangement that does not scroll, never shrinking below the floors.
   *(the layout engine)*
3. **The slot plan's own C** (one row on wide windows, Get Attention at
   its trailing end) when Phrases and Type are built; Stop then moves
   under Emergency as the slot plan says, and its chain is scored again.
   *(the typing and layout threads)*
4. **More than four everyday categories:** the fourth cell's scroll is
   interim; the engine decides (docs/DECISIONS.md, "Home's slot plan",
   *Open*). *(the layout engine)*
5. **The replacement tone** and its level under speech, after a listening
   check on a device. *(owner, with a device build)*
6. **Fewer than three everyday categories** leave the cell under Stop's
   well empty in some arrangements, so Again can be nearest after Stop
   (docs/DECISIONS.md, "Get Attention and Stop on Home", *Open*). Before
   editing or import can leave fewer than three: keep a category nearest
   the well for every library, or bring the owner a rule that keeps
   three. *(the library thread, with the layout engine)*
7. **The top of Stop's well is nearest Again** (docs/DECISIONS.md, "Get
   Attention and Stop on Home", *Open*): the device check that decides
   the message hazard decides it too, then the layout engine removes it
   or the owner hears its measured cost. *(the layout engine; owner if it
   stays)*
8. **An alarm warning nobody acts on keeps Home's line** over a later
   problem until Get Attention sounds again; VoiceOver hears each. Whether
   a newer problem takes the line is open. *(the next audio thread)*
9. **Typing needs C in one row on wide windows** (or all of C above the
   worst-case keyboard another way) before it comes to Home. *(the typing
   and layout threads)*
10. **A tone kept after a retry shows no warning** once a later
    activation succeeds, though it was started without the session
    (docs/DECISIONS.md, "Get Attention", *Open*): a device check first,
    then a warning of the alarm's own if activation alone does not make
    it heard. *(the next audio thread)*
