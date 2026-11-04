# Device procedures written, and Copilot out of the reviews

*2026-11-04. Branch `claude/project-thread-iio26z`. A Claude Code cloud
thread, which cannot build or run anything.*

## What changed and why

- **[`docs/DEVICE-CHECKS.md`](../DEVICE-CHECKS.md), new.** The
  step-by-step procedure, with what passes, for every row of
  docs/HANDOFF.md, *Checks that need a real device* (52 rows), and every
  gate of docs/ROADMAP.md, *The quality bar*, that the owner checks or
  answers. docs/ROADMAP.md, *The quality bar*, required them before the
  owner's first device run, and docs/HANDOFF.md named it the next job.
  It follows the 2026-10-26 Settings procedure
  ([`log/2026-10-26-settings-simulator-checks.md`](2026-10-26-settings-simulator-checks.md)),
  which stays the detailed steps for Settings by a stray dwell.
  - The checks already waiting come first (F1 to F4): Snap to Item and
    Dwell measured (Q12), the three dwell hazards (Q2), the floors on a
    device (Q13), and Settings by a stray dwell.
  - Every step is marked **Owner** (by hand: every assistive input
    method, everything by ear, every judgment), **Agent** (a thread from
    the owner's Mac over Remote Control: Brickson's UI tests through
    `launchedApp`, Instruments, `devicectl`) or **Thread** (reading what
    a session produced).
  - A *Coverage* table maps every row and gate to its procedure.
  - Procedure choices made here, each reversible: Fallback Action Tap
    during dwell trials (as on 2026-10-26); 60 activations for F3, so
    Q13's "fewer than 1 in 20" is at most 2 misses; F1 tries Dwell
    Control off first, so a resting look can be read without firing;
    Q8's iPad day as four hours at touch's answer and four with Eye
    Tracking; a development build answers a row early, and the gate
    passes when the same steps pass on the build that ships.
  - In place elsewhere: docs/HANDOFF.md's owner steps 2 and 4, its
    table's introduction and its next step for agents point to the new
    file, and step 8 (Codex reading all of `AGENTS.md`) is marked done
    on the owner's Mac; docs/ROADMAP.md's *How it is kept* names the
    file; AGENTS.md, *Where things are*, lists it with the rule that a
    pull request changing a device check or owner gate edits its
    procedure; docs/SDLC.md's Test stage asks for the procedure.
  - Corrected, from Apple's pages: docs/ROADMAP.md, Q8, read the thermal
    state "from the Energy Impact gauge"; Apple puts the device's thermal
    condition in the Energy Impact view's timeline.
- **Copilot is out of the reviews.** The owner's AI credits ran out on
  pull request #78 and the subscription ends on 2026-11-09, and the
  owner's instructions for this project say there is no Copilot review.
  Pull request #76 had let an agent ask for one Copilot review per pull
  request. This reverses that:
  - `.claude/hooks/guard.py` refuses every Copilot review and Copilot
    task again, by any tool; the record of requests
    (`.git/brickson-copilot-reviews.json`) and the hook that wrote it
    are gone, and an old record file can be deleted.
  - `.claude/settings.json` denies `request_copilot_review` outright
    again and has no PostToolUse hook.
  - `scripts/test-hooks.py` tests the refusal, by every tool name and
    through `gh` and the API, instead of the allowance.
  - AGENTS.md, *Build and test* ("Reviews and updates on GitHub") and
    *Guardrails for agents*, docs/DECISIONS.md, "Reviews, updates and
    GitHub settings", docs/SDLC.md and docs/HANDOFF.md say Codex,
    CodeRabbit and Greptile review, and Copilot does not.
    `.github/copilot-instructions.md` and `.github/skills/code-review/`
    stay: they cost nothing and serve again if Copilot returns.

## What agents can run on a device

The study of 2026-11-04 ("Can agents test Brickson on a real iPhone or
iPad?", a document in the project) found, and this pull request
rechecked against Apple's pages:

- **An agent can:** run Brickson's own UI tests on the owner's paired
  device from the Mac (`xcodebuild` with `-destination
  'platform=iOS,id=…'`, which `scripts/test.sh` passes through, Apple's
  TN2339); record App Launch, Hangs and Allocations with Instruments; read
  the memory gauge and Energy Impact in Xcode; install, launch and end
  apps and copy crash logs with `devicectl`. These are evidence under
  AGENTS.md, *Workflow rules*.
- **Nothing automated can:** turn on or drive Eye Tracking, Head
  Tracking, Switch Control, AssistiveTouch Dwell, Voice Control or Full
  Keyboard Access. XCTest delivers touches straight to the app; Apple
  says Switch Control, VoiceOver and Voice Control "isn't available on
  Simulator"; Eye and Head Tracking need a face at the camera. The one
  exception is VoiceOver: `XCUIVoiceOverService` (iOS 27) drives it
  from a UI test, and Apple's pages do not say whether it works on a
  device.
- **XCUIDevice has no lock button** (its buttons are home, volume up and
  down, action and camera), so locking stays the owner's.
- **Device Hub turns off the camera and microphone.** Apple: "You can't
  access the camera or microphone while interacting with a physical
  device in Device Hub." The procedures say never to view a device there
  during a session that uses either.
- The study's findings on third-party tools (Mobile Next, Appium,
  Maestro, AXe and others, and cloud device farms) were not rechecked:
  the procedures use none of them.

## Apple's pages, checked

Every Apple setting path and tool claim the procedures state was checked
on 2026-11-04 by four checkers, against support.apple.com's iPhone and
iPad guides for iOS 26 and 27 and developer.apple.com in its Markdown
form. Of 88 claims, 60 were confirmed, 12 corrected and 16 not confirmed
by any Apple page. Each claim, its status, Apple's words and the page are
in [`evidence/2026-11-04-device-procedures/apple-claims.json`](../evidence/2026-11-04-device-procedures/apple-claims.json).

Corrections the procedures carry:

- The dwell time is not on Eye Tracking's or Head Tracking's screen: it
  is Settings > Accessibility > Touch > AssistiveTouch > Dwell Control,
  with no unit given. Head Tracking's speed option is Pointer Speed.
- Developer Mode appears once a device has been paired with a Mac;
  after the restart, Enable and the passcode confirm it.
- The 400 ms launch goal is from WWDC19's "Optimizing App Launch", not
  from Apple's launch-time article.
- Point scanning is Switch Control Mode > Gliding Cursor; Apple's pages
  for iOS 26 and 27 have no "Point Mode" setting.
- Full Keyboard Access moves with Tab and Shift-Tab, not the arrow keys,
  in Apple's iPhone and iPad tables.
- Guided Access's start screen is Session Settings (older versions:
  Options).
- The setting is Show Borders, not Button Shapes, on iOS 26 and 27.
- Display Zoom is in Settings > Appearance on iOS 27 and in Settings >
  Display & Brightness on iOS 26.
- Analytics Data names crash reports by the app's name and the time,
  and high-memory terminations `JetsamEvent`.

Not confirmed by Apple, so the procedures say to check on the device:
Snap to Item for a plain mouse; which features the Accessibility
Shortcut lists beyond Switch Control, VoiceOver, Voice Control,
AssistiveTouch, Guided Access and Assistive Access; Eye Tracking on an
external display and under Guided Access; Settings > Developer > Enable
UI Automation (named only by community reports and Appium); `xctrace`'s
device and launch flags; the Hangs instrument's option names and
whether 100 ms is a setting; `XCUIVoiceOverService` on a device; whether
a screen recording keeps an app's sound; stepping a video frame by
frame in Photos (the procedures have a thread do it on the Mac); Switch
Control's Tap Behavior options other than Auto Tap, and the names of
Focused Item After Tap's choices; a list of apps allowed to use a
Personal Voice on iPhone and iPad (Brickson's own guide names one); the
shortest Auto-Lock; and whether accessibility features work in iPhone
Mirroring.

## Commits

- `2acde95` Take Copilot out of the review process and refuse its review
  again.
- The procedures, this record, its evidence and the edits to HANDOFF,
  ROADMAP, AGENTS.md and SDLC.

## Verified

On Linux, in the cloud thread: `scripts/test-hooks.py` (126 tests),
`scripts/test-docs.py` (57), `scripts/test-site.py` (7),
`scripts/test-runner.py` (85, of which the 5 that need a Mac's process
calls skip, as they say) and `scripts/test-select-xcode.py` (23) pass,
and `git diff --check` is clean.
The new hook test, `test_no_agent_requests_copilots_review`, fails with
the guard's Copilot refusal taken out (3 failures), so it can fail.

## Not verified

- **No procedure has been run.** Every row and gate stays as it was:
  no device result exists, and no *Today* line moves.
- Nothing was built: this thread has no Xcode. The change touches no
  Swift code; CI is the build.
- Whether `scripts/test.sh ui` with a device `DESTINATION` runs the whole
  UI suite on a device without changes: read from the script, not run.
- Whether the guard runs in this cloud thread was not relied on; the
  rules were kept by hand (AGENTS.md, *Guardrails for agents*).
- Whether every path is worded exactly as on the owner's iOS version:
  Apple's guides for iOS 26 and 27 were read, not a device's Settings.

## Follow-ups

- **Owner:** the first session (F1 to F4), and A1 on each device by
  writing "go" in a thread with the device on the cable.
- **Thread, before F1:** the look-target sheet from A1's captures or the
  layout engine's frames.
- **Thread, when the procedures need them:** an opt-in UI test that
  makes A3's 100 activations; a probe that reports which accessibility
  flags each input method turns on (I6); a UI test that taps Open
  Personal Voice Settings and Open Dwell Control Settings and reads the
  Settings app (G2); a debug-only log of Personal Voice identifiers for
  P4; the `XCUIVoiceOverService` walk on a device (I4).
- **Thread, after F1:** rescore the chain engine with the measured rule
  and pointer, and put the dwell hazards to the owner (F2 step 4).
