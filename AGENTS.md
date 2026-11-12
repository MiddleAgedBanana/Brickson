# Brickson — Agent Briefing

Read this before changing anything. It is the one shared briefing for every
agent working here: Codex and Antigravity read it directly, and Claude Code
loads it through `CLAUDE.md` (which contains only `@AGENTS.md`). Put
instructions here, not in an agent-specific file, so every agent gets the
same rules.

**Read all of it.** Codex reads only the first 32 KiB of `AGENTS.md` by
default and drops the rest without saying so (OpenAI's
[`project_doc_max_bytes`](https://developers.openai.com/codex/agent-configuration/agents-md)),
and Antigravity reads only the first 24,000 bytes of a rule file. So the
rules that protect the people using Brickson, the review rules and the
workflow come first, through *Working with the owner*, and
`scripts/test-docs.py` fails if they end past 32 KiB (docs/DECISIONS.md,
"AGENTS.md puts first what Codex reads"). The sections after *Working
with the owner*, and the parts of docs/AGENT-REFERENCE.md they send you
to, bind every agent just the same: if your copy of this file ends before
*Gotchas*, as Antigravity's does, read the rest from the repository
(`cat AGENTS.md`) before changing anything.

## What this is and what's at stake

Brickson is an iPhone and iPad app that speaks for
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

Before planning the app's direction, read docs/AGENT-REFERENCE.md,
*Direction*.

"Choose the boring, reliable option" governs **how** you build: proven
APIs, plain testable types, no clever indirection. It does not govern
**how much** the app does. The bar is an app that does its job better than
any AAC app on the App Store, with the polish of an app used by millions.
Every feature is judged by one question: does this make communication
faster, clearer or more reliable for the person, on the input method they
actually use?

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
    shrink targets below the profile's floor to avoid it. The floor is
    that of the profile the window takes: where a window cannot hold the
    floors an answer asks for without scrolling, Home takes the largest
    smaller profile it holds, touch's last, with every floor of the one
    taken (owner, 2026-10-30; docs/DECISIONS.md, "Sizes that follow how
    the screen is reached"). Where even touch's sizes scroll, a dwell,
    switch, head or gaze answer still breaks this invariant there
    (docs/HANDOFF.md, *Known gaps*). Every size comes
    from the tested layout engine. A library a family has grown may scroll
    at the floor. Nothing reflows when the keyboard appears.
12. **The screen never locks while Brickson is open** (`ScreenWakePolicy`).
    Many people using it cannot unlock their device.

## The privacy policy is a promise

The public privacy policy (`site/privacy/index.html`, live at
https://middleagedbanana.github.io/Brickson/privacy/) says what the app does
with people's data, and App Review and privacy law hold the app to it. A
change that makes any sentence in it untrue updates the page, its
Effective date and the in-app copy (once there is one) in the same pull
request. Code rules that keep it true:

- SwiftData opens with `cloudKitDatabase: .none`, and the app has no iCloud
  capability. With iCloud on, SwiftData syncs by itself.
- Never put a person's phrase, draft or category text, or an error that may
  contain it, in `fatalError`, `precondition`, `assert` or any other crash
  message. Crash reports can reach the developer.
- Store nothing in the Keychain. It survives deleting the app, and the
  policy says deleting the app removes what it stored.
- Recorded phrases, caregiver alerts and Siri and Shortcuts have no
  section in the policy, because 1.0 does not ship them. Before building
  one, read docs/AGENT-REFERENCE.md, *Planned privacy sections*.
- Settings gets a Privacy row, because App Review Guideline 5.1.1(i)
  requires the policy to be easy to reach inside the app. It shows the
  policy inside the app and opens the web page in an in-app sheet
  (`SFSafariViewController`) rather than Safari, so a stray activation
  never takes the person out of Brickson.

## Layout on every device and window

Before layout work, read docs/AGENT-REFERENCE.md, *Layout background*.

- **Lay out from the space available**, never from the device. Sizes and
  arrangements come from the window's size, its size classes, its safe
  areas and Dynamic Type, through standard SwiftUI containers and
  navigation. Never choose an interface by device model, by the screen's
  physical size or from a table of devices; an iPhone, an iPad and a
  resized iPad window are the same app given different room.
- **One tested layout engine turns that space into frames**
  (invariant 11). It takes the space, the input profile, the text size and
  the library's shape, and nothing that names a device.
- **iPhone Duo is more of the same space.** Its inner display has iPad
  size classes and ignores the iPhone's supported orientations, and when
  it is partially folded the fold and the camera are reserved regions in
  the space available, never a device check. One layout serves every
  pose, and the hinge drives nothing (docs/DECISIONS.md, "iPhone Duo").

## Apple's current frameworks first

The owner's rule (2026-10-22): build on the frameworks Apple is investing
in for the future, not the ones it is leaving behind, so nothing has to be
moved later, when moving it is harder.

- **Use the current framework for each job:** SwiftUI, not UIKit;
  SwiftData, not Core Data; Swift Testing, not XCTest; App Intents, not
  SiriKit; Observation, not Combine or `ObservableObject`; Swift
  concurrency, not Dispatch, where it keeps the same guarantees. Within a
  framework, use its current Swift API rather than an older one, and
  never a deprecated one.
- **A legacy framework or API only when no current one does the job with
  no loss**, and every such use is listed, with its reason, in
  docs/DECISIONS.md, "Apple's current frameworks first". A pull request
  that adds one adds its row; one that removes the last use removes it.
- **"No loss" includes what the person relies on:** an ordering
  guarantee, a measurement's precision, a test's strength, a behaviour
  the person sees. Swapping working code for a newer API that weakens one
  of these is not a migration.
- **Imports say what a file uses.** A file that uses UIKit's own types
  imports UIKit by name, even where `import SwiftUI` or `import XCTest`
  would bring it in; a file that uses none does not import it. SwiftUI's
  bridges to UIKit (`UIHostingController`, `UIViewControllerRepresentable`)
  and its modifiers typed with UIKit values (`keyboardType`) are SwiftUI's
  own API. The list in docs/DECISIONS.md, not a search for imports, is
  the complete record.
- **A test that drives no app uses Swift Testing**, in the unit tests,
  even when what it checks lives with the UI tests (compile that file into
  both targets in `project.yml`). XCTest is for UI automation only.
- Look APIs up first (*Apple documentation: look it up, don't recall it*).
  Before moving to a new major Xcode, read docs/AGENT-REFERENCE.md,
  *New major Xcode*.

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
- **Target floors are physical, set without a device table.** Each
  profile's floors are physical sizes (a visual angle at the profile's
  viewing distance), converted to points at the densest supported screen's
  points per inch (about 163, on the 326 ppi screens at 2x), so they hold
  everywhere and no code names a device (docs/DECISIONS.md, "Layouts from
  the space available"). Before sizing a profile, read
  docs/AGENT-REFERENCE.md, *Reference gaze measurements*. The
  switch and head floors, and which profile Family Setup's answer gives,
  are in docs/DECISIONS.md, "Sizes that follow how the screen is
  reached".
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
- **Score chains with the one chain engine.** `ChainEngine` (in
  `BricksonUITests`, compiled into both test targets) follows held
  activations from every start; a new screen becomes a surface for it,
  like `HomeChains` and `SettingsChains`, never another nearest-control
  script (docs/DECISIONS.md, "One chain engine for dwell safety").

## Code Review Rules

Every reviewer reads this section. The rules live here;
`.github/skills/code-review/SKILL.md` only says how to apply them. It
cites sections of AGENTS.md by title, so renaming one means updating the
skill too. Flag a change that does any of the following, name the
invariant, and show the path from a real input to the failure.

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
- An interface or a size chosen by device model, by the screen's physical
  size, from a table of devices, by interface orientation or by
  `userInterfaceIdiom`, instead of from the space available (*Layout on
  every device and window*).

### Data, privacy and platform

- Anything that deletes or rewrites a person's own words in a repair,
  migration or import (invariant 7).
- Network code, accounts, analytics, cloud sync, a third-party package or
  SDK, or a new data type in the privacy manifest (invariant 9).
- A closure a framework may call off the main thread that is main-actor
  isolated by default: under Swift 6 it crashes at runtime. Safe path:
  `@Sendable` or `nonisolated`, with a test in `OffMainThreadCallbackTests`.
- A new use of a legacy framework or API (UIKit, Core Data, XCTest
  outside UI automation, SiriKit, Combine, Dispatch, a deprecated API)
  with no row in docs/DECISIONS.md, "Apple's current frameworks first",
  or where a current one does the same job with no loss (*Apple's current
  frameworks first*).
- Elapsed time measured with `Date` instead of `ContinuousClock`.
- A colour pair not pinned in `PaletteTests` (invariant 6).
- A change that makes a sentence of the privacy policy untrue without
  updating `site/privacy/index.html` and its Effective date in the same
  pull request, or that breaks a code rule in *The privacy policy is a
  promise*: SwiftData opened without `cloudKitDatabase: .none`, a person's
  words in a crash message, anything stored in the Keychain.
- Personal names, email addresses, or health or family details in a
  committed file: the repository is public. The owner's exceptions, each
  only for what it names: the developer's name and support email on the
  website's pages in `site/` (Apple requires them); the short "Why
  Brickson?" founder note in `README.md` and `site/index.html`,
  attributed to Avery Dedmon (his brother invented the name as a
  teenager, it is still a family joke, his brother died of ALS, and Avery
  builds the app in his memory), and its record in `docs/DECISIONS.md`
  and `docs/HANDOFF.md` (2026-10-12); Avery Dedmon's copyright
  attribution in `LICENSE.md` and the README's license notice, and its
  record (2026-10-27); and, by Avery's decision of 2026-11-08, Avery's
  own name, their brother's first name, their own email addresses and
  the Claude session links, anywhere in the repository, its commits and
  its pull requests (docs/DECISIONS.md, "Personal details stay out of
  the repository", *Avery's decision of 2026-11-08*). None of them
  permits other family identities, the brother's medical or hospice
  details, phrases, device or settings, quotes from family
  conversations, private documents or the Mac's account name.
- Text anywhere that says what Brickson costs (an amount, "free" or
  "paid") before docs/DECISIONS.md records the owner's decision ("Price
  not decided"). "Free" about something else, such as Xcode or GitHub
  Pages, is fine.

### Tests, workflows and the rules themselves

- A test that cannot fail, a test filter that runs no tests, a weakened
  assertion, an unexplained skip, or a `withKnownIssue` that is not strict
  or names no decision (*Build and test*; docs/LESSONS.md, "A check that
  cannot fail is not a check").
- A workflow change that lets pull request code reach secrets or a token
  that can write to the repository (`pull_request_target`, wider
  `permissions`), or that puts text from a pull request (a branch name,
  title or commit message) straight into a shell command.
- A workflow that starts using an action not published by GitHub (one
  whose owner is not `actions` or `github`).
- A `uses:` line changed without `.github/workflows/actions.lock`, or a
  lockfile edited by hand. In its diff, a changed `commit` is new code the
  workflows will run, and a changed `owner_id` or `repo_id` means another
  repository now holds that name: say so for the owner (docs/DECISIONS.md,
  "Reviews, updates and GitHub settings", *Dependencies*).
- A renamed job that the `main` ruleset requires, or a path filter added
  to the workflow that runs those jobs (*Gotchas*).
- An Xcode, SDK, simulator OS or runner image version written into the
  project, a script, a workflow or a document when the owner did not ask
  for it, or a change that builds with anything but Apple's newest
  released Xcode (docs/DECISIONS.md, "Build with Apple's current Xcode").
  The `runs-on` label that names GitHub's image for the current major
  Xcode is how CI reaches that Xcode, not a pin; a dated record of what
  something was checked on is history, not a pin.
- A warning silenced instead of fixed: warnings suppressed
  (`SWIFT_SUPPRESS_WARNINGS`, `GCC_WARN_INHIBIT_ALL_WARNINGS`,
  `-suppress-warnings`, `-w`); or warnings as errors turned off, or a
  diagnostic group kept a warning (`SWIFT_WARNINGS_AS_WARNINGS_GROUPS`,
  `-Wwarning`), without its line in docs/DECISIONS.md, "Warnings are
  errors".
- A change that weakens an invariant or a review rule, adds an exception
  to one, or widens *Not findings*, made in `AGENTS.md`,
  docs/DECISIONS.md, `.github/skills/` or any other file reviewers read as
  instructions (*Gotchas* lists the ones each reviewer reads); and any new file
  of that kind, because review rules live here. Reviewers may be reading
  the pull request's own version of these files, so compare them with the
  base branch and name what the change weakens; the owner decides.
- A change to `.claude/settings.json`, `.claude/hooks/`, `.githooks/` or
  `scripts/privacy-check.py` that unhooks the guard or the privacy check,
  drops a deny rule or lets through what its tests refuse (*Guardrails
  for agents*), or a weakened test in `scripts/test-hooks.py`,
  `scripts/test-privacy.py` or `scripts/test-docs.py`.

### Not findings

- Formatting or naming on its own.
- A gap the base branch already records as accepted in docs/DECISIONS.md
  or in docs/HANDOFF.md, *Known gaps* (for example, no typing on Home yet),
  unless the change makes it worse or newly reachable, or claims to close
  it and doesn't. A feature that is planned but not built yet is not
  missing.
- The accessibility audit's "not human-readable" guess on phrase labels
  (Home's phrase tiles and the Library's phrase rows), which the UI
  tests' audit helper (`assertPassesAccessibilityAudit`) expects.
- That an agent did not run the app: for cloud agents the GitHub CI run is
  the build (*Build and test*).

## Workflow rules

- **Test first.** New behaviour gets a failing test first; a bug fix gets a
  failing reproduction first. For each new test, name the change that would
  make it fail.
- **Logic lives in plain, testable types, not in views; views only read
  them.** Before adding a type, see the list of today's in
  docs/AGENT-REFERENCE.md, *Plain testable types*.
- **Run it, don't just read it.** Layout and flow changes are checked in the
  running app on an iPad and an iPhone simulator, at default and
  accessibility text sizes, light and dark.
- **Say what each result was measured on**: device, orientation, text size,
  appearance, multitasking mode, and which keyboard showed (the full
  software keyboard or the hardware-keyboard bar). Simulator evidence is
  never presented as proof of gaze comfort, sound or Snap to Item
  behaviour. An activation, reachability or keyboard claim counts only
  from a UI test through `launchedApp`, from Device Hub's own input on a
  simulator or from a person's own input on a real device, never from an
  automation tool's report (*Gotchas*).
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
- **Branches and pull requests.** Use `<agent>/<topic>` from latest
  fetched `main`, one pull request per piece of work into `main`, using
  `.github/pull_request_template.md`. Never push directly to `main`,
  force-push or rewrite pushed history. The owner merges. Incorporate
  moved `main` with a merge commit; never rebase. Preserve the first two
  attribution lines exactly when editing an existing pull request body.
- **Before every push**, rerun the appropriate test script for the change,
  and `python3 scripts/privacy-check.py --outgoing` (with no list, as in
  a cloud thread given none, `--outgoing --no-list`, and say in the pull
  request that the list was not checked); check a pull
  request's text or a comment with `--text -` before posting it. Never
  repeat what it finds (docs/DECISIONS.md, "Personal details stay out of
  the repository"). Batch completed commits into one push: each push
  cancels in-flight CI.
- **Document every change** where a fresh agent will find it, in the same
  pull request: one new file in `docs/log/` (what changed, why, how it was
  verified, what was not; the template is `docs/log/README.md`), the lines
  of `docs/HANDOFF.md` your change makes untrue edited in place (never
  appended to), this file for any new rule or gotcha, `docs/DECISIONS.md`
  for decisions, `docs/ROADMAP.md` when an item starts, lands or moves
  and when the change moves a gate of its quality bar (that gate's Today
  line), `README.md` when setup or behaviour changes. Record reversals and their
  reasons, so the next agent does not redo what was undone. Before a
  rewrite that removes information from HANDOFF or this file, snapshot the
  old version (`docs/archive/README.md`).
  If this briefing or the documentation is wrong, record the problem and
  propose its correction in the work log; do not silently work around it.
- **Keep evidence where later work finds it.** Evidence that later work
  needs (prototypes, screenshots, logs, receipts) goes in a git-ignored
  folder inside the worktree or under `docs/log/`, never in `/tmp` and
  never only in a chat (a `/tmp` prototype was lost on 2026-10-27).
- **Rules that also live further down** (*Where things are*). The
  reference app, FamilyVoice (`MiddleAgedBanana/ALS-app`, private), is
  reference only: never push to it or open a pull request on it. Where a
  session loads its own `AGENTS.md`, this file wins, and `docs/recon/`
  never overrides this file or `docs/DECISIONS.md`. Read the sections of
  `docs/LESSONS.md` that touch your work; it carries the reference app's
  rules, so follow it without access to that app. A feature that changes
  what a person sees or hears starts with a work file in `docs/work/`. A
  pull request that adopts, changes or drops an accessibility feature or
  API in `docs/ACCESSIBILITY.md`'s map edits its row there, and the
  website's accessibility page where its words become untrue; that page
  says only what is in place and how it was checked, never "works with"
  before a real-device check.
- **Start of a session:** `git status`, `git log --oneline -15`, then
  `git fetch origin`. Read `AGENTS.md`, `docs/HANDOFF.md`,
  `docs/DECISIONS.md` and the newest `docs/log/` records from the fetched
  `origin/main`, before changing anything. Another agent may have landed
  work since; the repository is the shared source of truth.
- **Use the tools you have.** At every session start, read your own
  build, simulator and device tool list (a build tool on the owner's
  Mac, Remote Control, a connected folder) and use available tools.
  Never infer inability to build or run from a handoff or earlier
  thread: a cloud session reaching the Mac can (*Build and test*).

## Working with the owner

The owner is new to programming. Explain in plain words, without talking
down: say what a thing is and why it matters before how. Make routine
decisions yourself, state them, and keep going; ask only about real
trade-offs, batched, with a recommendation. When something needs the owner
to run a command on their Mac, give the exact command and what success
looks like.

## Build and test

The full rules, which govern, are in docs/AGENT-REFERENCE.md, *Build and
test*: read them before building, testing, pushing or asking for a
review. In short:

- On a Mac, the unit suite is 100% green before any commit, and CI is
  green before a pull request merges. Warnings are errors: fix them,
  never silence them. Build with Apple's current released Xcode, never a
  pinned one.
- Cloud agents with no route to a Mac say plainly that they cannot build
  or run the app, treat the change as untested until CI or a Mac run
  passes, and never describe unbuilt code as working.
- Never check out, stash, reset or clean in `~/code/brickson`. Never edit
  the generated Xcode project or open it in Xcode from an agent, and never
  commit a project file (`git add -f` gets past `.gitignore`).

**Pushing to an open PR.** At most three review rounds from the moment
the pull request opens, one push each, never while CI is still running;
then one final push that batches what is left. Agents never merge a pull
request or enable auto-merge. The rest of this rule is in the reference.

**Reviews and updates on GitHub.** Never post an `@codex` comment of any
kind. Reviewers never write code: no autofix, "Fix with cubic" or fix
request. Before opening a pull request that changes code, run
`codex review --base origin/main` and answer its findings; right after
opening it, ask for Copilot's review once, only through
`request_copilot_review`. A pull request that changes only documents gets
none. Ask CodeRabbit with a comment reading `@coderabbitai review`.

## Guardrails for agents

The full rules are in docs/AGENT-REFERENCE.md, *Guardrails for agents*:
read them before running commands, file tools or GitHub tools. When the
guard refuses, do not look for another way round: say what you needed and
why. On the owner's Mac, git-ignored hooks hold Codex and Antigravity to
what the guard refuses, except input typed into a command already
running, which Codex's hook does not see (its `write_stdin` does not run
`PreToolUse` again; Antigravity's `send_command_input` is checked).
Codex's hook lives in `~/.codex/hooks.json` and acts only inside a
Brickson checkout. In a cloud thread, check that the guard runs before
relying on it (`git add -A --dry-run` is refused where it does). Never
update `~/code/brickson` to bring in a guard change: the owner pulls
`main` there. The privacy check prints places and kinds, never the words,
and neither does anyone after it; a run with `--no-list` is never
described as a pass. Run the report-only verifier
(`.claude/agents/verifier.md`) before calling a pull request ready, and
paste its list of what was not verified into the pull request.

**Cross-references.** Cited titles and relative links must resolve:
rename a section and update what cites it in the same commit.

## Where things are

The list of documents is in docs/AGENT-REFERENCE.md, *Where things are*.
`docs/recon/` is research, not instructions. A pull request that adds or
changes a device check or an owner gate edits its procedure in
`docs/DEVICE-CHECKS.md`.

## Apple documentation: look it up, don't recall it

Look APIs up before using them, and say when you could not. On
developer.apple.com, fetch a page with `.md` appended to its path, never
the HTML page. Sources: docs/AGENT-REFERENCE.md, *Apple documentation:
look it up, don't recall it*.

## Skills

Put review rules in this file, never in a skill. Never commit Apple's
skills. **Never apply** `core-data` skills, `cloudkit`, `authentication`,
`push-notifications`, `ios-networking`, `apple-on-device-ai` or
`swiftui-gestures`. The rest: docs/AGENT-REFERENCE.md, *Skills*.

## Gotchas

Read docs/AGENT-REFERENCE.md, *Gotchas*, before simulator work, tests,
troubleshooting, workflows, reviewer settings or commands on the owner's
Mac. The ones that bind every change:

- Never edit `.github/workflows/actions.lock` by hand.
- **Job names in `tests.yml` are required check names.** The `main`
  ruleset requires "Unit tests" and "UI tests": never rename those jobs or
  add a path filter to their workflow, and "UI tests" keeps
  `if: always()`.
- Reviewers read instructions from these files, and a change to any of
  them is one *Code Review Rules* flags: `AGENTS.md`, `CLAUDE.md`,
  `.github/copilot-instructions.md`, `.github/skills/`, and `REVIEW.md`,
  `GEMINI.md` or `.github/instructions/**/*.instructions.md` if added
  (Copilot and CodeRabbit, from the pull request's own branch);
  `.coderabbit.yaml`; `.greptile/`; and `cubic.yaml`, which cubic takes
  from `main` only.
- **A just-started simulator is slow, and the first UI test pays for it.**
  Never put a call to a system service that can be slow on the main
  thread at launch (docs/DECISIONS.md, "The voice list never holds up
  launch").
- **Accessibility frames do not prove visible words fit.** Keep the
  rendered-label regression beside reachability and audits.
- **Audit only a still screen.** Before an audit, speech and anything
  else that changes the screen by itself must be over or unable to
  happen; a wait is not a retry.
- **CI results can be read without a Mac.** Read the result bundle's app
  and runner logs before blaming the machine for a UI failure.
- Choose arrangements in a plain type and place each view once:
  `ViewThatFits` failed Apple's audit around text here.
- A Remote Control session stops after about 60 idle minutes: run
  anything longer detached, and keep a background check that ends within
  45 minutes.
- Never move the build to Xcode's JSON project format outside the pull
  request planned in docs/DECISIONS.md, "Xcode's JSON project format".
