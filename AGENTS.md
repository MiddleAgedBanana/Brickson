# Brickson — Agent Briefing

Read this before changing anything. It is the one shared briefing for every
agent working here: Codex and Jules read it directly, and Claude Code loads
it through `CLAUDE.md` (which contains only `@AGENTS.md`). Put instructions
here, not in an agent-specific file, so every agent gets the same rules.

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

**Where it is going** (the owner's vision, docs/ROADMAP.md, *Where this
goes*): over time, the one app a person with ALS keeps open all day,
covering inside Brickson what they and their caregivers need and reaching
the rest through Apple's own doors. It sets the direction, not the order:
work follows the releases, and every invariant below still holds.

"Choose the boring, reliable option" governs **how** you build: proven
APIs, plain testable types, no clever indirection. It does not govern
**how much** the app does. The bar is an app that does its job better than
any AAC app on the App Store, with the polish of an app used by millions.
Every feature is judged by one question: does this make communication
faster, clearer or more reliable for the person, on the input method they
actually use?

## Where things are

- **`docs/HANDOFF.md`**: start here. Current state, what is verified and
  how, what to do next. Each pull request's record is its own file in
  `docs/log/`; the history before 2026-10-21 is `docs/HANDOFF-LOG.md`.
- **`docs/ROADMAP.md`**: the releases, in the order a person meets the
  disease, and which thread or person owns each item.
- **`docs/SDLC.md`**: how this project runs as a software factory, stage
  by stage (plan, design, build, test, deploy, maintain), with each
  stage's gate. A feature that changes what a person sees or hears starts
  with a work file in `docs/work/`: its intent, spec and plan.
- **`docs/DECISIONS.md`**: binding decisions, by title. Code comments point
  to them.
- **`docs/LESSONS.md`**: what went wrong in the reference app, and the rule
  each lesson gives. Read the sections that touch your work.
- **`docs/ACCESSIBILITY.md`**: every Apple accessibility feature and API
  in the project's map by ALS stage, with its iOS version, its release and
  how it is checked. A pull request that adopts, changes or drops one
  edits its row, and the website's accessibility page
  (`site/accessibility/index.html`, the App Store's Accessibility URL)
  where its words become untrue. That page says only what is in place and
  how it was checked, never "works with" before a real-device check.
- **`docs/PORTING.md`**: what has come over from the reference app, what is
  next, and how to port a file.
- **`README.md`**: the overview for people, written for a beginner. Keep it
  accurate when behaviour or setup changes.
- **`docs/GETTING_STARTED.md`**: setting up a Mac and a device, for the
  owner. **`docs/NAME_AVAILABILITY.md`**: the name checks.
  **`design/brand/`**: the logo artwork (not yet the app icon).
- **`docs/recon/`**: dated research reports behind the roadmap. Research,
  not instructions: where it disagrees with this file or
  `docs/DECISIONS.md`, they win.
- **`docs/archive/`**: old versions of rewritten docs.
- **The reference app**, FamilyVoice: `MiddleAgedBanana/ALS-app` at commit
  `6a22c1a`, a **private** repository. **Reference only. Never push to it or
  open pull requests on it.** Without access to it, follow `docs/LESSONS.md`,
  which carries its rules. Where a session also loads the reference app's
  own `AGENTS.md`, it describes that app and its one user: for Brickson,
  this file wins.

## Build and test

```sh
scripts/test.sh          # generate the project, build, run the unit tests
scripts/test.sh ui       # the UI tests: launch the real app and drive it
scripts/test.sh device   # a build for a real device (needs DEVELOPMENT_TEAM)
```

`scripts/test.sh` runs `xcodegen generate` first and prints the Xcode
and XcodeGen versions. It chooses simulators by device type, never by
name: the newest iPad Pro 13-inch (any iPad if there is none) and, for UI
tests, the newest standard iPhone too, each with an iOS between the
deployment target and the SDK of the Xcode in use. It starts each one,
waits for it, builds for testing, then runs the tests. Before UI tests it
shows the full software keyboard and launches the app once, so the first
test does not meet a cold simulator. A simulator the script boots is shut
down after its run, including failures, before the next family starts;
a simulator already running is left running. `SIMULATOR_FAMILY=iphone` runs one
family; `DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh`
names one simulator, which is started and waited for too. Anything after
the mode goes to `xcodebuild`
(`scripts/test.sh unit '-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()'`).
Each run keeps its result bundle, with screenshots of UI-test failures and
the captures UI tests attach, in `build/TestResults/<mode>-<family>.xcresult`,
and prints how many tests ran; a run in which no test ran, or whose count
cannot be read, fails. A unit run also prints the app's code coverage and
brings `Brickson/Resources/Localizable.xcstrings` up to date with the code
(`xcstringstool sync` over the strings the build found); commit the
updated catalog with your change. On CI a catalog that does not match the
code fails the run and prints the difference. The iPad and the iPhone are
both first-class: UI tests run on both every time.

On a Mac, the unit suite must be **100% green before any commit**; for
work made where nothing can be built, CI must be green before the pull
request merges. No exceptions and no unexplained skips. A known limitation is a strict `withKnownIssue`
naming its decision, so it fails when it starts passing.

**Warnings are errors** in every target and build configuration
(`project.yml`; docs/DECISIONS.md, "Warnings are errors"): a compiler
warning fails the build, on CI and on a Mac. Fix the code it names;
never silence it. CI builds Debug only: before an archive,
`scripts/test.sh device -configuration Release` on a Mac shows any
warning only the Release build sees (code under `#if DEBUG` differs).

**GitHub CI** (`.github/workflows/tests.yml`) runs the unit and UI tests on
GitHub's Mac machines for every pull request and every push to `main`.
Each job keeps `build/TestResults` (the result bundles above) as a
download on the run's page for 14 days, passed or failed: the artifacts
`unit-test-results` and `ui-test-results`. A job that stops before its
tests start (choosing Xcode, XcodeGen, a build failure) writes no
bundle, so that job has no artifact, only a warning. A
pull request merges only when CI is green.

**Build with Apple's current Xcode, never a pinned one** (owner,
2026-10-21; docs/DECISIONS.md, "Build with Apple's current Xcode"). The
toolchain is Apple's newest Xcode release (not a beta) with its SDKs and
Swift compiler, on the owner's Mac and on CI. Never write an Xcode, SDK,
simulator or runner version into the project, a script, a workflow or a
document unless the owner asks for it: documents say "the current Xcode
release". Look up what is current on Apple's releases page
(https://developer.apple.com/news/releases/) and Xcode's system
requirements (https://developer.apple.com/xcode/system-requirements/),
never from memory. CI picks the newest released Xcode on GitHub's machine
(`scripts/select-xcode.py`) and warns on the run when Apple has a newer
one. The deployment target, the oldest iOS the app runs on, is a separate
product decision, set by two rules: every device that can use eye
tracking runs the app, and every accessibility API in the ALS-stage map
stays reachable, behind `#available` when newer (docs/DECISIONS.md,
"Minimum iOS, iPhone and iPad").

**Reviews and updates on GitHub.** Codex reviews every push to a pull
request that a person or agent opens, and GitHub Copilot reviews each such
pull request once, when it opens. Neither reviews Dependabot's pull
requests by itself. Each Copilot review spends the owner's monthly AI
credits, so only the owner requests one (**Re-request review**, or a
Dependabot pull request): agents never add Copilot as a reviewer unless
the owner asks. Both review against *Code Review Rules* below. GitHub's AI
Scan also posts security findings after each push to such a pull request;
answer them like review comments. It skips Dependabot's pull requests and
those from forks, and CodeQL did not analyse Dependabot's first one before
it merged, so treat a Dependabot pull request as not security-reviewed
until the owner reads it or requests Copilot (docs/DECISIONS.md, *Code
scanning*). Dependabot opens one pull request a month for new versions of
the actions in `.github/workflows`, and one at once for a security fix.
The intended repository settings, and why, are in docs/DECISIONS.md,
"Reviews, updates and GitHub settings".

**Pushing to an open PR.** Once CI is green, push again only if CI fails,
a reviewer finds a real bug or a rule violation, or `main` moved and must
be merged in. Batch cosmetic, wording and style findings into one otherwise
needed push, or answer them in words and resolve the thread; never one
push per finding. After the first green run, apply the existing
[stop after two rounds rule](docs/log/2026-10-22-agent-guardrail-reconciliation.md#main-refresh-and-declined-findings-2026-10-23)
as a limit of two fix pushes. A PR with owner-enabled auto-merge merges
itself on green once its other merge requirements are met: after the final
push, stop and let it. Agents never enable auto-merge or merge a PR.

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
- Three planned features have no section in the policy, because 1.0
  does not ship them: recorded phrases, caregiver alerts and Siri and
  Shortcuts. Their sections were deleted on 2026-10-23, and their words
  are kept in `docs/log/2026-10-23-accessibility-page-and-privacy-trim.md`.
  The pull request that ships one adds its section back, and the feature
  matches it: recordings stay on the device; caregiver alerts advertise a
  random service name and send the device name only inside the encrypted
  alert; App Shortcut phrases and parameters never contain phrase words.
  Caregiver alerts need network code, which invariant 9 forbids; the owner
  decides before they are built.
- Settings gets a Privacy row, because App Review Guideline 5.1.1(i)
  requires the policy to be easy to reach inside the app. It shows the
  policy inside the app and opens the web page in an in-app sheet
  (`SFSafariViewController`) rather than Safari, so a stray activation
  never takes the person out of Brickson.

## Layout on every device and window

The owner's goal (2026-10-21), in Apple's words: "For SwiftUI development,
standard layout and navigation primitives remain the appropriate default,
using adaptive layouts and standard SwiftUI containers, instead of
building device-specific interfaces."

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
- **Look it up first** (*Apple documentation: look it up, don't recall
  it*). The pull request that moves Brickson to a new major Xcode also
  reads what Apple has newly replaced, and rechecks every row of the
  exceptions list.

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
  the space available"). For gaze at about 45 cm the reference used phrase
  tiles of at least 110pt, quick controls of at least 88pt and categories
  of at least 72pt, sized on a 13-inch iPad (about 132 points per inch);
  held at the densest screen they are about 136, 109 and 89pt.
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
heading, GitHub Copilot code review reads this file and
`.github/copilot-instructions.md` from the pull request's own branch
(*Gotchas*), and Claude Code reads it through `CLAUDE.md`. Copilot is also
given review steps in `.github/skills/code-review/SKILL.md`, which GitHub
says it uses when they are relevant. The rules live here, and the skill
only says how to apply them; it cites sections of this file by title, so
renaming one means updating the skill too. Flag a change that does any of
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
  committed file: the repository is public. The developer's name and
  support email on the website pages in `site/` are the exception: Apple
  requires them, and the owner chose to publish them. On 2026-10-12 the
  owner also explicitly authorized the short "Why Brickson?" founder note
  in `README.md` and `site/index.html`, attributed to Avery Dedmon: his
  brother invented the name as a teenager, it remains a family joke more
  than twenty years later, his brother died of ALS, and Avery is building
  the app in his memory. Documentation of that name/publication decision
  in `docs/DECISIONS.md` and `docs/HANDOFF.md` is also permitted. This is
  a specific exception for those facts and attribution, not permission
  to publish other family identities, medical details or private documents.
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
  instructions (*Gotchas* lists the ones Copilot reads); and any new file
  of that kind, because review rules live here. Reviewers may be reading
  the pull request's own version of these files, so compare them with the
  base branch and name what the change weakens; the owner decides.
- A change to `.claude/settings.json` or `.claude/hooks/` that unhooks
  the guard, drops a deny rule or lets through a call its tests deny
  (*Guardrails for agents*), or a weakened test in `scripts/test-hooks.py`
  or `scripts/test-docs.py`.

### Not findings

- Formatting or naming on its own.
- A gap the base branch already records as accepted in docs/DECISIONS.md
  or in docs/HANDOFF.md, *Known gaps* (for example, no typing on Home yet),
  unless the change makes it worse or newly reachable, or claims to close
  it and doesn't. A feature that is planned but not built yet is not
  missing.
- The accessibility audit's "not human-readable" guess on phrase-tile
  labels, which the UI tests' audit helper
  (`assertPassesAccessibilityAudit`) expects.
- That an agent did not run the app: for cloud agents the GitHub CI run is
  the build (*Build and test*).

## Workflow rules

- **Test first.** New behaviour gets a failing test first; a bug fix gets a
  failing reproduction first. For each new test, name the change that would
  make it fail.
- **Logic lives in plain, testable types**, not in views: today
  `SpokenUtteranceTracker`, `VoiceSelection`, `SpeechRateSteps`,
  `AudioSafetyPolicy`, `AttentionAlertStatus`, `AudioSessionEventMapping`,
  `AudioSessionLeasePolicy`, `ScreenWakePolicy`, `CategorySelection`,
  `StarterLibrary`, `PhraseLibrarySeeder`, `MessageComposer`,
  `DraftStore`, `SettingsIdleClock`, `SetupRecord`, `CheckInPolicy`,
  `VoiceList`, `PersonalVoiceGuidance`, `PrivacyPolicyDocument`,
  `SpeedChoice`, `WordFit`, `HomeShape`, `HomeRegion`, `HomeControlNames`,
  `HomeStatusLine`, `HomeButtonLook`, `LibrarySnapshot`, `LibraryEdit`,
  `LibraryRules`, `LibraryImport`, `LibraryEditor`, `BackupCodec`,
  `EmergencyRepair`, `SettingsRootColumns`, `KeyboardAllowance`.
  Views only read them.
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
  from the latest fetched `main`, with one pull request per piece of work,
  and open it into `main` using
  `.github/pull_request_template.md`. Never push to `main` directly, never
  force-push, never rewrite pushed history. The owner merges.
  When `main` moves, incorporate it with a merge commit; never rebase.
  When editing an existing pull request body, preserve its first two
  attribution lines exactly.
- **Before every push**, rerun the appropriate test script for the change.
  Batch completed commits into one push: each push cancels in-flight CI.
- **Document every change** where a fresh agent will find it, in the same
  pull request: one new file in `docs/log/` (what changed, why, how it was
  verified, what was not; the template is `docs/log/README.md`), the lines
  of `docs/HANDOFF.md` your change makes untrue edited in place (never
  appended to), this file for any new rule or gotcha, `docs/DECISIONS.md`
  for decisions, `docs/ROADMAP.md` when an item starts, lands or moves,
  `README.md` when setup or behaviour changes. Record reversals and their
  reasons, so the next agent does not redo what was undone. Before a
  rewrite that removes information from HANDOFF or this file, snapshot the
  old version (`docs/archive/README.md`).
  If this briefing or the documentation is wrong, record the problem and
  propose its correction in the work log; do not silently work around it.
- **Start of a session:** `git status`, `git log --oneline -15`, then
  `git fetch origin`. Read `AGENTS.md`, `docs/HANDOFF.md`,
  `docs/DECISIONS.md` and the newest `docs/log/` records from the fetched
  `origin/main`, before changing anything. Another agent may have landed
  work since; the repository is the shared source of truth.

## Guardrails for agents

Agents push and open pull requests as the owner's GitHub account, so
GitHub itself cannot tell an agent's merge from the owner's. The rules
above are backed by checks wherever a check can run:

- **The guard.** `.claude/settings.json` runs `.claude/hooks/guard.py`
  before every Bash command and before the GitHub tools that can merge or
  write. It refuses, with the rule it breaks: `git add -A`, `--all`, `-u`
  or `.` and `git commit -a`; force pushes and any push that updates
  `main`; merging, auto-merging or approving a pull request (`gh`, the
  GitHub API or a GitHub tool); the Copilot actions that spend the owner's
  credits; and a GitHub tool writing a file onto `main`. The same settings
  deny the merge and Copilot tools outright. When the guard refuses, do
  not look for another way round: say in the thread what you needed and
  why. It is a guard against mistakes, not a sandbox, and it covers
  Claude Code only; Codex, Jules and the owner are held to the same rules
  by review. Both policy hooks use `onFailure: "block"`, so a startup
  error, crash, invalid output or timeout blocks the original action in
  Claude Code 2.1.295 or later. Older or unknown runtimes do not establish
  that protection; confirm the runtime and hook reload before relying on it.
- **Where the guard runs.** Claude Code reads a repository's hooks and
  permission rules in a session with one repository. A cloud session that
  clones several repositories reads only plugin settings from them, so
  there the guard does not run and these rules are yours alone to keep.
- **Its tests.** `scripts/test-hooks.py` feeds the guard the calls it must
  refuse and the ones it must let through; `scripts/test.sh` runs it
  before the unit tests, so CI runs it. A new rule gets a test first.
- **Cross-references.** `scripts/test-docs.py`, run the same way, fails
  when a section cited by title (a file name, then the title in quotes or
  italics) or a relative link no longer resolves. In this file, the
  review skill and `.github/copilot-instructions.md`, an italic title on
  its own must name a real section. Rename a section and update what cites it in the same commit.
- **The verifier.** `.claude/agents/verifier.md` is a report-only
  subagent: it runs the Python checks, reads the branch's CI run and says
  what was and was not verified. Run it before calling a pull request
  ready, and paste its *Not verified* list into the pull request.
- **Issues.** `.github/ISSUE_TEMPLATE/something-went-wrong.yml` is the
  bug form, with a warning that issues are public. Blank issues are off.

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
- **developer.apple.com in Markdown:** its HTML pages are JavaScript
  shells that look empty rather than failing, but the same page with
  `.md` appended to its path returns Markdown with availability metadata
  (for example `https://developer.apple.com/documentation/swiftui/button.md`,
  checked 2026-10-21). Fetch that form, never the HTML page.

## Skills

Skills are installed per machine (`.agents/skills/`, with `.claude/skills/`
symlinks), and both folders are ignored by git. Committed skills live in
`.github/skills/`: `code-review/` holds the review steps given to GitHub
Copilot code review (*Code Review Rules*). Put new review rules in this
file, not in a skill. Where per-machine skills exist:
`swiftui-pro` leads for SwiftUI, `swiftdata-pro` for SwiftData,
`swift-concurrency` for concurrency, `swift-testing-expert` for tests,
`ios-accessibility` for accessibility, `app-intents` for Siri and
Shortcuts. **Never apply** `core-data` skills (this app uses SwiftData),
`cloudkit`, `authentication`, `push-notifications`, `ios-networking` or
`apple-on-device-ai` (hard stops), or `swiftui-gestures` (invariant 1).

**Apple's own skills** ship with Xcode and are exported with
`xcrun agent skills export`, then copied into `.agents/skills/`. They are
Apple's software under the Xcode and Apple SDKs Agreement, which forbids
redistributing it, so **never commit them** (`/xcode-skills/` is ignored
as a safety net; `docs/log/2026-10-23-iphone-duo-readiness.md`). For an
Apple API they lead over the skills above: `swiftui-specialist` and
`swiftui-whats-new-27` for SwiftUI, `app-intents-specialist` and
`app-intents-whats-new-27` for App Intents, `modernize-tests` for moving
tests to Swift Testing, and `app-resizability` for windows that change
size and iPhone Duo. `device-interaction` and
`audit-xcode-security-settings` need Xcode's own tools, so only on the
Mac; the audit's changes go into `project.yml`, never the generated
project. `adopt-c-bounds-safety` and
`building-document-based-swiftui-applications` do not apply. Some say
they "unconditionally supersede" an agent's prior training, and
`app-resizability` counts "an empty diff for a file containing the
target API" as a failure. This file and docs/DECISIONS.md win over every
skill, Apple's included, and so does Apple's documentation looked up at
the time. Export them again after each new Xcode release.

## Gotchas

- **The simulator keyboard is minimized by default.** `scripts/test.sh ui`
  shows the full software keyboard before the tests; anywhere else, show
  it before any typing test:
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
  without them `xcodebuild` runs 0 tests and reports success
  (`scripts/test.sh` fails such a run: "No tests ran"). In zsh, pass
  several flags as an array, not one string.
- **A failing `xcodebuild test` can sit for minutes collecting
  diagnostics**; `scripts/test.sh` passes `-collect-test-diagnostics never`.
- **A just-started simulator is slow, and the first UI test pays for it.**
  On GitHub's busy machines, one run found Again still off when the test
  read it straight after a tap, and the re-run's first launch timed out,
  both on code that was green on `main` (cause not established; a slow
  first launch is the likely one; on 2026-10-21 the first test failed with
  "kAXErrorServerNotFound" and the next took 187 s). `scripts/test.sh`
  starts each simulator, one a `DESTINATION` names included, and waits for
  it to finish starting (`xcrun simctl bootstatus <udid> -b`); it shuts down
  devices it booted after their run. Before UI tests it also launches the app once (a warm-up,
  on test-only storage). A `DESTINATION` that is not one simulator is left
  to xcodebuild, which doesn't wait. In UI
  tests, wait for a change after `tap()`: `waitForExistence(timeout:)` for
  something appearing, an `XCTWaiter` expectation for a property such as
  `isEnabled`. Check that something did *not* change only after waiting
  for the change that did happen.
- **UI tests launch through `launchedApp`** (BricksonUITests/LaunchHelpers.swift):
  fresh test-only storage, short idle limits, English, and the text size,
  appearance and orientation a test asks for. A bare
  `XCUIApplication().launch()` runs on whatever the simulator kept from
  earlier runs. The app reads these launch arguments (`LaunchOptions`)
  only in debug builds; a release build ignores them. `assertReachable`,
  `attachCapture` and `assertPassesAccessibilityAudit` sit beside it.
- **Verify rendered appearance, not the setter's readback.** Command-line
  simulator runs on Xcode 27.1 reported `XCUIDevice.appearance == .dark`
  while the app stayed light. `launchedApp` uses debug-only
  `--appearance=light|dark`, applied by `preferredColorScheme`; ordinary
  and release launches follow the system. Keep the independent screenshot
  gate. Its sample is the empty gutter between Yes and No, not a median
  dominated by constant-colour tiles. Evidence and reproductions:
  `docs/log/2026-10-21-ui-test-diagnosis.md`.
- **Accessibility frames do not prove visible words fit.** On PR #13,
  both complete UI suites passed while AX5 phone screenshots showed
  clipped Yes, No, Emergency and Again labels. Keep the rendered-label
  regression alongside reachability and audits: it recognizes each
  button screenshot without language correction or supplied expected
  words. Inspect its kept captures when it fails; a complete accessibility
  label is not evidence that the text was drawn completely.
  Vision's accurate mode also misread a clear `No` as `ON`; the fast mode
  read it and rejected the old clipped captures. Keep whole-word matching
  (case-insensitive), with no language correction or recognition hints.
  The recognizer lives in `RenderedWords` (Vision's `RecognizeTextRequest`).
  The unit tests run it on kept whole and clipped captures
  (`RenderedWordsTests`, `BricksonTests/RenderedLabels`) and pin its
  settings, so a change that stops it reading whole words, accepts part
  of one, or turns on correction or hints fails there first.
- **Measuring the keyboard:** `KeyboardProbeTests` runs on every UI run.
  For each orientation and text size it opens a debug-only probe screen
  (`--screen=keyboard-probe`) instead of Home, prints one
  `KEYBOARD-PROBE {json}` line, and fails if the keyboard reaches above
  the room `KeyboardAllowance` keeps for the window (add the measurement
  to `KeyboardAllowanceTests` and raise that shape's reference). It then
  opens Home in the same window, prints `KEYBOARD-BAND {json}` and fails
  if Yes, No, Emergency, Again or Get Attention ends below the
  allowance's limit. It also fails, after printing, if the simulator
  shows the keyboard bar instead of the full keyboard. xcbeautify hides
  printed lines from passing tests, so read the JSON attached to each
  test in the result (Xcode's Report navigator, or the `.xcresult`
  database on Linux), or run `xcodebuild` without xcbeautify. Say which
  simulator and iOS version the numbers came from.
- **Simulator audio is unreliable.** Every sound check needs a real device.
- **Apple's accessibility audit can time out on CI** with domain
  `com.apple.xcode.xctest.accessibilityAudit`, code `-56`. The UI suite
  retries the full audit once for that error only; a second timeout still
  fails. Findings already reported with `XCTFail` remain failures. Never
  retry or discard an accessibility finding to make CI green.
- **Audit only a still screen.** Apple's audit reads a screenshot and the
  accessibility tree a moment apart, so text that leaves the screen in
  between is reported as "Potentially inaccessible text" on no element.
  Home's "Speaking" line did that on CI, leaving as the simulator's voice
  finished just after an audit began (issue #30). The audit helper first
  waits for speech to finish (`waitForSpeechToFinish`); anything else
  that changes the screen by itself (Settings' idle reset under
  `--short-timeouts`, an alarm that ends) must be over, or unable to
  happen, before an audit. A wait is not a retry: the finding came from
  auditing a moving screen, not from the app.
- **`ViewThatFits` fails Apple's audit around text.** The audit grows
  the text and compares each text with itself, and `ViewThatFits` swaps
  one view for another: labels built with it were reported as clipped or
  as not following Dynamic Type (docs/DECISIONS.md, *Home's stand-in
  layout*), and on PR #33 Settings' root, built with one, was reported as
  clipped text belonging to no element on the phone. Choose arrangements
  in a plain type and place each view once (`WordFit`,
  `SettingsRootColumns`).
- **CI results can be read without a Mac.** A failed UI test's result
  keeps a screen recording of the whole test, and each `.xcresult` has a
  `database.sqlite3` listing every activity and attachment with its time
  and its file in `Data/` (`data.<id>`). Images and recordings are stored
  as they are; text and JSON are zstd-compressed. `sqlite3` (or Python),
  `zstd` and `ffmpeg` read them on Linux; how it was done for issue #30 is
  in `docs/log/2026-10-22-audit-still-screen.md`.
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
- **Cloud agents cannot change `.github/workflows/`.** On 2026-10-21 a
  cloud session's `git push` of `tests.yml` was refused ("refusing to
  allow an OAuth App to create or update workflow ... without `workflow`
  scope"), and so was the GitHub MCP's file update ("Insufficient scope").
  Push the rest, and give the owner the workflow file's full new text to
  commit with their own account (GitHub's web editor on the branch, or an
  agent on their Mac).
- **CodeQL scans the workflow files and the Python scripts in `scripts/`,
  not the Swift code, on purpose.**
  Default setup cannot build Swift without a committed Xcode project, so
  adding Swift to it fails again; turning CodeQL off blocks every
  merge while the ruleset requires CodeQL results. docs/DECISIONS.md,
  "Reviews, updates and GitHub settings", *Code scanning*, says why and
  when to revisit.
- **Copilot code review reads its instructions from the pull request's
  own branch** (GitHub's documentation, checked 2026-10-12): `AGENTS.md`,
  `CLAUDE.md`, `.github/copilot-instructions.md` and the skills in
  `.github/skills/`, and also `REVIEW.md`, `GEMINI.md` and
  `.github/instructions/**/*.instructions.md` if one is added. A change to
  any of them applies to the review of the pull request that makes it.
