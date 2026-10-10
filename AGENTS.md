# Brickson — Agent Briefing

Read this before changing anything. It is the one shared briefing for every
agent working here: Codex and Jules read it directly, and Claude Code loads
it through `CLAUDE.md` (which contains only `@AGENTS.md`). Put instructions
here, not in an agent-specific file, so every agent gets the same rules.

## What this is and what's at stake

Brickson (the working name) is a free iPhone and iPad app that speaks for
people living with ALS, at every stage of the disease. A person chooses a
phrase or types, and the app says it aloud, in their own Personal Voice if
they banked one. It works with every way Apple devices can be controlled:
touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch
with Dwell, head tracking and Eye Tracking. It will be on the App Store. It
has no accounts, no servers, no ads and no analytics.

**The people using it may be unable to speak or move.** A bug here can
leave someone with no way to ask for water, answer a question or call for
help. Correctness and accessibility outrank performance and elegance.

The core idea: **one app that follows a person as the disease progresses,
so they never have to relearn it.** As they move from touch to switches to
their eyes, target sizes, spacing and dwell protection change, but where
each control sits does not.

"Choose the boring, reliable option" governs **how** you build: proven
APIs, plain testable types, no clever indirection. It does not govern
**how much** the app does. The bar is an app that does its job better than
any AAC app on the App Store, with the polish of an app used by millions.
Every feature is judged by one question: does this make communication
faster, clearer or more reliable for the person, on the input method they
actually use?

## Where things are

- **`docs/HANDOFF.md`**: start here. Current state, what is verified and
  how, what to do next.
- **`docs/DECISIONS.md`**: binding decisions, by title. Code comments point
  to them.
- **`docs/LESSONS.md`**: what went wrong in the reference app, and the rule
  each lesson gives. Read the sections that touch your work.
- **`docs/PORTING.md`**: what has come over from the reference app, what is
  next, and how to port a file.
- **`README.md`**: the overview for people, written for a beginner. Keep it
  accurate when behaviour or setup changes.
- **`docs/archive/`**: old versions of rewritten docs.
- **The reference app**, FamilyVoice: `MiddleAgedBanana/ALS-app` at commit
  `6a22c1a`, a **private** repository. **Reference only. Never push to it or
  open pull requests on it.** Without access to it, follow `docs/LESSONS.md`,
  which carries its rules.

## Build and test

```sh
scripts/test.sh          # generate the project, build, run the unit tests
scripts/test.sh ui       # the UI tests: launch the real app and drive it
scripts/test.sh device   # a build for a real device (needs DEVELOPMENT_TEAM)
```

`scripts/test.sh` runs `xcodegen generate` first, then `xcodebuild` on the
newest installed iPad Pro 13-inch simulator (any iPad if there is none).
`DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh`
chooses another. The iPad and the iPhone are both first-class: run both
before a release.

On a Mac, the unit suite must be **100% green before any commit**; for
work made where nothing can be built, CI must be green before the pull
request merges. No exceptions and no unexplained skips. A known limitation is a strict `withKnownIssue`
naming its decision, so it fails when it starts passing.

**GitHub CI** (`.github/workflows/tests.yml`) runs the unit and UI tests on
GitHub's Mac machines for every pull request and every push to `main`. A
pull request merges only when CI is green.

**Reviews and updates on GitHub.** Codex reviews every push to a pull
request. GitHub Copilot reviews each pull request once, when it opens;
the owner can ask again with **Re-request review**. Both review against
*Code Review Rules* below. Dependabot opens one pull request a month for
new versions of the actions in `.github/workflows`, and one at once for a
security fix. The intended repository settings, and why, are in
docs/DECISIONS.md, "Reviews, updates and GitHub settings".

**Cloud agents** without Xcode (Claude Code on the web, Codex cloud, Jules)
cannot build or run anything. Say so plainly, treat the change as untested
until CI or a Mac run passes, and never describe unbuilt code as working.

`Brickson.xcodeproj` is generated from `project.yml` and is not committed.
Regenerate after adding, removing or renaming any file. Never edit the
generated project, and never open it in Xcode from an agent.

## Non-negotiable invariants

Tests and reviews enforce these. Numbers match the reference app's, so its
documents can be read alongside.

1. **Every interactive element is a standard SwiftUI `Button`** (or a
   standard system control) with an accessibility label, and a target of at
   least 44×44pt, larger where the active profile sets a higher floor. Never
   gesture-only controls, and never custom input, switch, head or gaze code:
   every Apple input method and VoiceOver find standard buttons through the
   accessibility tree, and that is the whole integration.
2. **Every phrase speaks on the first activation**, by any input method, in
   every profile: no confirm step, no load-then-speak, not even as an opt-in
   setting. Emergency is visible on Home in every state, never inside a
   scrolling region and never covered, including by the software keyboard.
   It switches straight to the emergency phrases and leaves edit mode, and
   emergency phrases never open editors. One pure resolver owns that
   decision, and every tap path goes through it (it arrives with edit mode;
   until then a tile can only speak).
3. **Speaking never changes data.** Every change to a person's phrases sits
   behind an explicit edit mode, and every delete, replace or merge asks
   first: Keep takes the asking control's place, and the confirmation
   appears where a repeated activation cannot reach it.
4. **Audio survives.** Speech and alarms use the `.playback` session so they
   play with the silent switch on (never `AudioServicesPlaySystemSound`),
   and recover from interruptions, route changes and media-services resets.
   Failures the person cannot hear show visibly as passive, layout-reserved
   text that never replaces the message, never adds a dismiss control and
   never moves a target. Observe but never set system volume. After a
   media-services reset, rebuild audio objects but wait for the next user
   action before activating. An interruption keeps the text and names a
   reachable control to retry; never auto-resume into a changed route.
5. **No silent failures.** Every `catch` recovers, shows the person
   something, or both. A failed save never crashes the app and never leaves
   data half-changed, and every save path has a test that makes it fail
   (docs/LESSONS.md, "Never roll back a cascade delete").
6. **Contrast is measured, never eyeballed.** Text at least 4.5:1 (control
   labels are normal-size text under WCAG), control edges at least 3:1, in
   light, dark, Increase Contrast and Reduce Transparency, including system
   components the app shows. White on system red (3.55:1) and on system
   orange (2.2:1) are forbidden. Pin every pair in a unit test
   (`PaletteTests`).
7. **Never put words about a person's condition in their mouth.** Anything
   the app ships may be spoken in someone's own Personal Voice. The starter
   library holds only neutral, practical phrases anyone might choose;
   personal expression is theirs to write. Extra sets are opt-in, never
   seeded. Nothing (repair, migration, import) may delete a person's own
   words.
8. **Position is never a function of usage or time.** No frequency,
   recency or adaptive ordering; fixed column counts; a slot keeps its
   place across categories. Across stage profiles, sizes and spacing may
   change but every control's relative position stays the same. A recents
   zone, if ever built, is fixed in place; only its contents change.
9. **Hard stops (never build):** accounts or login, servers or network
   code, cloud sync (for now: docs/DECISIONS.md), analytics, ads or
   tracking, third-party packages or SDKs, AI-generated replies, custom
   gesture-only interactions, custom eye, head or switch tracking. The
   privacy manifest declares no data collected.
10. **Dwell safety.** In every profile that uses dwell or pointer snapping,
    and for switch auto-select, an activation can repeat while the pointer
    stays put. No control turns into its opposite in place: start and stop
    live in different places. A mode switch never leaves a speaking,
    alarming, position-changing or destructive control nearest the spot
    just activated ("under" means nearest, with Snap to Item), and chains
    of several activations are scored, not only the first. A repeat of the
    phrase still being spoken is absorbed, never delayed
    (`SpokenUtteranceTracker`). Get Attention, Emergency, Yes and No are one
    activation away from every Home state, including while typing. Every
    exception is named, measured and recorded in docs/DECISIONS.md.
11. **No scrolling on Home for the starter library** in any dwell, switch,
    head or gaze profile on any supported device and window, and never
    shrink targets below the profile's floor to avoid it. Every size comes
    from the tested layout engine. A library a family has grown may scroll
    at the floor. Nothing reflows when the keyboard appears.
12. **The screen never locks while Brickson is open** (`ScreenWakePolicy`).
    Many people using it cannot unlock their device.

## Design rules for dwell, switch and pointer input

These hold for every profile in which a resting pointer or a scan can
activate something (AssistiveTouch Dwell, head tracking, Eye Tracking,
Switch Control auto-select). They come from the reference app, which was
built for Eye Tracking.

- **Wherever a pointer rests can activate.** Reading is pointing. Large
  targets, generous spacing, and no harmful control (speaks, alarms,
  deletes, reorders, changes a setting) nearest to text the person reads or
  empty space they rest on.
- **Scrolling is expensive** for dwell, head and switch users (several
  activations through the AssistiveTouch menu), and nearly free for touch.
- **Target floors are physical.** Each profile sets its floors from viewing
  distance and visual angle, computed in physical size per device. For gaze
  at about 45 cm the reference used phrase tiles of at least 110pt, quick
  controls of at least 88pt and categories of at least 72pt.
- **Keep corners clear.** Dwell hot corners (top-left starts Eye Tracking
  recalibration by default), window controls and the home indicator. Never
  hide a standard Back button to clear a corner; guide people to move the
  hot corner instead.
- **Family controls stay out of the person's path.** Settings opens on a
  large way back and a start-only Get Attention, with configuration a screen
  below; edit mode ends itself when idle; timeouts reset screens, never
  close them.
- **Words never break.** Labels shrink only as much as needed, drop a
  decorative icon before shrinking words, and never render below their
  default size.
- **Typing never hides the call for help.** Emergency, Get Attention, Yes,
  No, Speak and the way out sit above the worst-case software keyboard from
  the moment typing opens; nothing reflows; Return speaks as an extra path.
- **An alarm stops only from a separate, differently placed control.**
- **Controls keep their frames across every state of a screen**, including
  keyboard show and hide.
- **Fix hazards with placement**, never with time-based input guards, decoy
  buttons or custom pointer code. Keep standard Back, Close and swipe
  navigation.

## Code Review Rules

Every reviewer reads this section: Codex code review looks for this
heading, GitHub Copilot code review reads this whole file (and
`.github/copilot-instructions.md`) from the pull request's own branch, and
Claude Code reads it through `CLAUDE.md`. Flag a change that does any of
the following, name the invariant, and show the path from a real input to
the failure.

### Communication never fails

- A phrase that needs a second activation, a confirmation or a load before
  it speaks (invariant 2). Safe path: speak at once; a repeat of the phrase
  still being spoken is absorbed by `SpokenUtteranceTracker`.
- Emergency, Get Attention, Yes or No more than one activation from any
  Home state, or anything that can cover them: a scroll view, a sheet, the
  software keyboard (invariants 2 and 10).
- A failure the person cannot hear that shows nothing, or a `catch` that
  only logs (invariants 4 and 5).
- A save path with no test that makes the save fail, or
  `ModelContext.rollback()` after a delete that cascades (invariant 5;
  docs/LESSONS.md, "Never roll back a cascade delete").

### Dwell and gaze safety

- A control that turns into its opposite in place, or a mode switch that
  leaves a speaking, alarming, destructive or position-changing control
  nearest the spot just activated (invariant 10). Safe path: start and stop
  in different places, fixed by placement, never by timers, decoy buttons
  or custom pointer code.
- An order that depends on usage or time, or a column count that changes
  with content (invariant 8).
- New scrolling on Home for the starter library, a target below its
  profile's floor, or a layout that moves when the keyboard appears
  (invariant 11).

### Data, privacy and platform

- Anything that deletes or rewrites a person's own words in a repair,
  migration or import (invariant 7).
- Network code, accounts, analytics, cloud sync, a third-party package or
  SDK, or a new data type in the privacy manifest (invariant 9).
- A closure a framework may call off the main thread that is main-actor
  isolated by default: under Swift 6 it crashes at runtime. Safe path:
  `@Sendable` or `nonisolated`, with a test in `OffMainThreadCallbackTests`.
- Elapsed time measured with `Date` instead of `ContinuousClock`.
- A colour pair not pinned in `PaletteTests` (invariant 6).
- Personal names, email addresses, or health or family details in a
  committed file: the repository is public.

### Not findings

- Formatting or naming on its own.
- A gap already recorded as accepted in docs/DECISIONS.md or in
  docs/HANDOFF.md, *Known gaps* (for example, no Get Attention yet), unless
  the change makes it worse.
- The accessibility audit's "not human-readable" guess on phrase-tile
  labels, which `LaunchTests` expects.
- That an agent did not run the app: for cloud agents the GitHub CI run is
  the build (*Build and test*).

## Workflow rules

- **Test first.** New behaviour gets a failing test first; a bug fix gets a
  failing reproduction first. For each new test, name the change that would
  make it fail.
- **Logic lives in plain, testable types**, not in views: today
  `SpokenUtteranceTracker`, `VoiceSelection`, `SpeechRateSteps`,
  `AudioSafetyPolicy`, `ScreenWakePolicy`, `CategorySelection`,
  `StarterLibrary`, `PhraseLibrarySeeder`. Views only read them.
- **Run it, don't just read it.** Layout and flow changes are checked in the
  running app on an iPad and an iPhone simulator, at default and
  accessibility text sizes, light and dark.
- **Say what each result was measured on**: device, orientation, text size,
  appearance, multitasking mode, and which keyboard showed (the full
  software keyboard or the hardware-keyboard bar). Simulator evidence is
  never presented as proof of gaze comfort, sound or Snap to Item
  behaviour.
- **Time is `ContinuousClock`.** Elapsed time uses `ContinuousClock.Instant`;
  pure types take `now:` and never read a clock; `Date` is only for times
  people read (docs/LESSONS.md, "Timers use ContinuousClock").
- **Swift 6, strict concurrency, default main-actor isolation**
  (`project.yml`). Any closure a framework may call on another thread is
  `@Sendable` or lives in a `nonisolated` method or extension, and gets a
  test in `OffMainThreadCallbackTests`. Notification observers use
  `queue: .main` plus `MainActor.assumeIsolated`.
- **Words people see go through the String Catalog**:
  `LocalizedStringKey` in views, `String(localized:)` elsewhere. A
  person's own words (phrase and category names) are shown with
  `Text(verbatim:)`, never translated.
- **One task per commit**, with a plain descriptive message.
- **Stage only your own changes** (`git add <paths>`, never `git add -A`).
  Never touch someone else's uncommitted work or stashes.
- **Branches and pull requests.** Work on a branch named `<agent>/<topic>`
  and open a pull request into `main` using
  `.github/pull_request_template.md`. Never push to `main` directly, never
  force-push, never rewrite pushed history. The owner merges.
- **Document every change** where a fresh agent will find it, in the same
  pull request: `docs/HANDOFF.md` (what changed, why, how it was verified,
  what was not), this file for any new rule or gotcha, `docs/DECISIONS.md`
  for decisions, `README.md` when setup or behaviour changes. Record
  reversals and their reasons, so the next agent does not redo what was
  undone. Before a rewrite that removes information from HANDOFF or this
  file, snapshot the old version (`docs/archive/README.md`).
- **Start of a session:** `git status`, `git log --oneline -15`, then read
  `docs/HANDOFF.md`. Another agent may have landed work since.

## Working with the owner

The owner is new to programming. Explain in plain words, without talking
down: say what a thing is and why it matters before how. Make routine
decisions yourself, state them, and keep going; ask only about real
trade-offs, batched, with a recommendation. When something needs the owner
to run a command on their Mac, give the exact command and what success
looks like.

## Apple documentation: look it up, don't recall it

Training data is not current enough for this app. Look APIs up before
using them, and say when you could not.

- Context7 MCP, where available: `/websites/developer_apple_swiftui`,
  `/websites/developer_apple_accessibility`,
  `/websites/developer_apple_appintents`.
- The Sosumi MCP (`searchAppleDocumentation`, `fetchAppleVideoTranscript`)
  adds full-text search and WWDC transcripts.
- The Xcode MCP's `DocumentationSearch`, read-only.
- **Do not fetch developer.apple.com pages directly.** They are JavaScript
  shells and look empty rather than failing.

## Skills

Skills are installed per machine (`.agents/skills/`, with `.claude/skills/`
symlinks), and both folders are ignored by git. Where they exist:
`swiftui-pro` leads for SwiftUI, `swiftdata-pro` for SwiftData,
`swift-concurrency` for concurrency, `swift-testing-expert` for tests,
`ios-accessibility` for accessibility, `app-intents` for Siri and
Shortcuts. **Never apply** `core-data` skills (this app uses SwiftData),
`cloudkit`, `authentication`, `push-notifications`, `ios-networking`,
`storekit` or `apple-on-device-ai` (hard stops), or `swiftui-gestures`
(invariant 1).

## Gotchas

- **The simulator keyboard is minimized by default.** Show the full
  software keyboard before any typing test:
  `xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false`
  (write `true` to restore the bar).
- **Display Zoom is lost whenever a simulator restarts**, and `xcodebuild`
  shuts down a simulator it booted itself. Boot the simulator yourself, set
  the configuration in a prepare step, and check the window size before
  trusting a measurement.
- **Rotation and text size on simulators:** `simctl` cannot rotate; set
  `XCUIDevice.shared.orientation` in a UI test. Set Dynamic Type per launch
  with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- **One simulator per agent**, addressed with `-destination 'id=<udid>'`.
  Parallel simulators cause false UI-test timeouts. If every `simctl` call
  hangs, `xcrun simctl shutdown all` clears it, but stops every agent's
  simulators.
- **Swift Testing and `-only-testing:`**: include the function's
  parentheses (`-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()`);
  without them `xcodebuild` runs 0 tests and reports success. In zsh, pass
  several flags as an array, not one string.
- **A failing `xcodebuild test` can sit for minutes collecting
  diagnostics**; `scripts/test.sh` passes `-collect-test-diagnostics never`.
- **Simulator audio is unreliable.** Every sound check needs a real device.
- **A crash cannot be a known issue.** `withKnownIssue` does not survive a
  crash; commit the reproduction disabled, naming its issue.
- **Lazy Forms unload rows far off screen**, so a missing element in a UI
  test can mean "scrolled", not "gone".
- **Inspecting the store:** `sqlite3 <app container>/Library/Application Support/default.store`,
  after relaunching the app to flush its write-ahead log.
- **Simulator novelty voices** (Bells, Boing and others) are deliberately
  excluded from automatic voice choice. Don't "fix" it.
- **On the owner's Mac**, the interactive shell aliases `rm`, `cp`,
  `grep` and `python3` (`cp` asks before overwriting and can hang a
  script). Scripts are not affected; in a typed command, use
  `command cp` and so on.
- **Job names in `tests.yml` are required check names.** The `main`
  ruleset requires "Unit tests" and "UI tests" by name (docs/DECISIONS.md,
  "Reviews, updates and GitHub settings"). Renaming a job, or adding a path
  filter to the workflow, leaves every pull request waiting for a check
  that never arrives until the owner updates the ruleset.
- **Copilot code review reads instructions from the pull request's own
  branch**: `AGENTS.md`, `CLAUDE.md` and `.github/copilot-instructions.md`.
  A change to *Code Review Rules* applies to the review of the pull request
  that makes it.
