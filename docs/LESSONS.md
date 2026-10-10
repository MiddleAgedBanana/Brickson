# Lessons from the reference app

Brickson starts from what was learned building **FamilyVoice**, an earlier
communication app for one person with ALS (repository
`MiddleAgedBanana/ALS-app`, read at commit `6a22c1a`; it is reference only,
and nothing is ever pushed to it). Each lesson below says what happened
there and the rule Brickson follows because of it. "D" numbers are
FamilyVoice's decision records (`docs/fixes/DECISIONS.md` in that
repository).

Read the sections that touch your work before you start it.
`docs/PORTING.md` names, for each port step, the part of the reference app
it comes from; the lessons below are grouped by subject.

The reference repository is **private**. Agents and contributors without
access to it can still follow every rule here; the file paths and "D"
numbers are for those who can read it.

## Storage

### Never roll back a cascade delete

In FamilyVoice, deleting a category cascaded to its phrases. When the save
failed and the code called `ModelContext.rollback()`, SwiftData crashed
("Unexpected backing data for snapshot creation"), on disk and in memory
(D28, never fixed). A full disk would have closed the app and left the
person without a voice until someone reopened it.

**Rule.** The category-to-phrase relationship uses `.nullify`, and code that
deletes a category deletes its phrases explicitly in the same save. Neither
half of that is proven yet: FamilyVoice never built it, so the first delete
ported must show, with a failure-injection test, that a failed save can be
undone without a crash.

Inserting in a separate `ModelContext` that is simply discarded on failure
is safe (the seeder does this). **Deleting** that way is not proven: in
FamilyVoice's D28 experiments, a delete saved from a separate context made
the main context crash the next time it read the deleted phrase ("This
model instance was invalidated…"). Any delete through a separate context
needs a test that reads through the main context after the save, and every
view must drop its references to deleted items first.

Every mutation path (add, rename, move, delete, merge, replace, seed,
migrate) gets a test that makes the save throw and checks: no crash,
nothing half-changed, something shown to the person. A save failure never
crashes the app.

### Test every rollback path

D28 was found only because one test injected a failure into a phrase
delete and someone tried the same for a category. FamilyVoice had four
`rollback()` sites; three were never tested.

**Rule.** Failure-injection tests are written when a mutation is written,
before any screen depends on it. `PhraseLibrarySeeder.seedIfEmpty` takes a
`save` parameter for exactly this.

### Commit a crash reproduction, disabled

Swift Testing's `withKnownIssue` cannot catch a crash, so the D28
reproduction lived only in a note, and the suite stayed green.

**Rule.** Commit a crashing reproduction anyway, disabled with
`.disabled("…")` naming the issue, and open a GitHub issue for it.

### Version the schema from the first release

FamilyVoice had no `VersionedSchema`, so any change to a stored model would
have had no safe migration path.

**Rule.** Every stored model lives in a versioned schema
(`PhraseLibrarySchemaV1`) with a migration plan. A stored property is never
changed in place; a new schema version is added instead.

### Add stored fields with their feature

FamilyVoice stored a `recordingFileName` on every phrase for a recording
feature that was never built.

**Rule.** A stored field arrives in the same change as the feature that
reads and writes it, in a new schema version.

### Seed only neutral words, and never repair someone's words away

FamilyVoice's first starter phrases included self-deprecating text about
the user's condition. Removing it from existing libraries and old backups
needed a complex fingerprint repair.

**Rule.** The starter library holds only neutral, practical phrases anyone
might choose (invariant 7). Extra sets are opt-in additions, never seeded.
Nothing (repair, migration, import) may delete a person's own words.

## Time

### Timers use ContinuousClock

Settings' idle reset, edit mode's timeout and speech repeat absorption all
measured elapsed time with `Date`. Changing the clock (time zone, manual
change, network correction) could postpone the idle reset or keep edit mode
on, where phrase tiles open editors instead of speaking.

**Rule.** Elapsed time is measured with `ContinuousClock.Instant`. Pure
logic types take `now:` as a parameter and never read a clock themselves.
Framework callbacks stamp `ContinuousClock.now` before hopping to the main
actor. `Date` is only for times people read. Tests start from one `now`
and add offsets, so switching back to `Date` fails to compile.
(`SpokenUtteranceTracker` already follows this.)

## Swift concurrency

### Closures a framework may call off the main thread

With the project's default main-actor isolation, a closure handed to a
framework silently becomes main-actor isolated. When the framework calls it
from another thread, Swift 6 crashes the app at run time. FamilyVoice
crashed this way from a `UIColor { traits in … }` colour provider that
SwiftUI resolved on its render thread.

**Rule.** Any closure a framework may call on another thread is `@Sendable`
or lives in a `nonisolated` method or extension. Notification observers use
`queue: .main` plus `MainActor.assumeIsolated`; delegate methods are
`nonisolated` and hop with `Task { @MainActor in … }`. Each such callback
gets a test in `OffMainThreadCallbackTests` that calls it from a
background task.

## Typing and the keyboard

### Test with the real software keyboard

iPad simulators shrink the keyboard to a thin bar by default. Typing checks
passed with that bar, but with the full software keyboard in landscape on
the user's iPad, the keyboard covered Speak, Get Attention, Yes and No (D27,
never fixed).

**Rule.** Every simulator used for typing tests shows the full keyboard:

```sh
xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false
```

Every keyboard test fails unless the software keyboard is visible, and
every keyboard result says which keyboard showed. Emergency, Get Attention,
Yes, No, Speak and the way out of typing sit above the worst-case keyboard
on every device and orientation from the moment typing opens.

### The return key must speak

The typing field was a vertical-axis `TextField` with `.submitLabel(.done)`.
Its return key inserted a newline instead: nothing was spoken, the keyboard
stayed up, and the newline was later spoken as a pause.

**Rule.** Pin the return key's behaviour with a UI test on the software
keyboard. Return speaks, as an extra path; Speak stays the main one.

### Lay out against a measured keyboard

There is no documented way to know the keyboard's height before it
appears, and keyboard-attached toolbars come and go with it.

**Rule.** The typing layout uses a measured worst-case keyboard height per
device class and orientation, kept as test data and re-measured each OS
release, so nothing moves when the keyboard appears. Safety controls never
live in keyboard toolbars.

## Layout and measuring

### Positions are a pure function of their inputs

On one iPad, a launch-time banner could flip the category band from four
rows to five, moving every category between launches.

**Rule.** Positions depend only on window size, profile, text size and the
library. Banners and warnings get reserved space and never feed the layout
(Home's status area is last for this reason).

### Measure the running app, not a proxy

Text-width estimates and assumed chrome heights were wrong in the unsafe
direction: a test passed while the real grid scrolled.

**Rule.** Layout gates are running-app captures, not estimates. Layout-engine
inputs come from measured running-app values.

### A check that cannot fail is not a check

Captures clipped every frame to the window, so "the last row is on screen"
was true even when the grid scrolled. Several protections could be removed
without any test failing.

**Rule.** For each new test, name the change that would make it fail and
try it once. Avoid defaulted safety arguments; wire safety behaviour
through named constants or pure types.

### The device matrix must include the real windows

The test matrix lacked the zoomed window the user actually had, so it
scrolled while the docs said it did not. Full Screen Apps and Windowed Apps
also lay out differently (different bottom insets), and Display Zoom is
forgotten whenever a simulator restarts.

**Rule.** The layout matrix covers every Display Zoom variant, both
orientations, each multitasking mode, default and accessibility text sizes,
and library sizes from empty to large. Any measurement that depends on
device configuration sets it in a prepare step and fails unless the window
is the expected size. Every result records its configuration.

### Apply a change only where it was measured

A copy change scored only at the largest text size also applied at the
default size, where it made things worse.

**Rule.** Parameterize text and layout tests over every Dynamic Type size,
and capture at least default, xxxLarge, AX1, AX3 and AX5.

### Words never break

SwiftUI hyphenates or truncates words that are wider than their line
("Don|e", "C…").

**Rule.** Labels shrink only as much as needed, drop a decorative icon
before shrinking words, and never render below their default size.

### Windows need a minimum size

Short iPad windows cut off Emergency and Get Attention.

**Rule.** Windowed and Stage Manager sizes are part of the matrix; a minimum
window size is derived from the safety controls at the largest text size.

### The phone is a first-class device

FamilyVoice's phone layout was second-class and was locked to portrait
because Emergency fell off screen in landscape. Earlier in ALS, a phone is
often the main device.

**Rule.** The phone gets a first-class layout from the layout engine, and
the UI tests run on an iPhone simulator before every release.

### In-process snapshots have blind spots

`ImageRenderer` does not draw native scroll content, Forms or sheets.

**Rule.** Use in-process renders only for pure SwiftUI geometry; use
running-app captures for everything else.

## Dwell, switch and pointer safety

### Score chains, not single hops

In edit mode a resting look could chain: a phrase tile opened the editor,
Delete Phrase was nearest, then the confirmation was nearest. A UI test
that checked one tile passed.

**Rule.** Dwell-safety scoring follows chains of several activations from
every start point, under both pointer models (the pointer stays on the
activated control, or returns to the gaze point), including a look
returning to where it started.

### Anything that moves things is a hazard

Merging a backup was first called harmless, but it adds categories and
moves cells. A held look on Move Later walked a category to the end of the
list.

**Rule.** Merge, reorder, text-size changes and entering edit mode count as
hazards, alongside speaking, alarming and deleting. Reorder controls are
never nearest the control that opened them, and are disabled at the ends of
the list.

### A timeout never closes a screen onto speaking controls

Settings used to close itself after 90 seconds idle, landing Home's
speaking tiles under a resting look.

**Rule.** A timeout may return a screen to its safe start, never dismiss it.

### Instant transitions must be verified

A safety argument depended on a navigation pop being instant, which no API
promises.

**Rule.** Verify such claims in the running app, frame by frame.

### No screen-wide gestures for bookkeeping

A screen-wide tap observer used to record activity blocked native Form
navigation.

**Rule.** Record activity from controls, navigation changes and scrolling.

### Unverified assumptions about Snap to Item

Two designs assumed Snap to Item ignores controls scrolled off screen. No
Apple documentation says so, and it was never checked on a device.

**Rule.** Check such premises on a device before building on them, and
score designs under both answers.

### One resolver per safety decision

Emergency then Edit turned every emergency tile into an editor, because the
guard worked in one order only.

**Rule.** Each safety decision lives in one pure resolver that every input
path calls, tested in both orders of every mode change.

### Purge removed safety settings

A removed "confirm before speaking" setting had its stored key purged on
launch, so no later setting could inherit it.

**Rule.** When a safety-relevant setting is removed, purge its key on
launch with a test, and never reuse key names.

## Native feel and system components

### Start native; deviate only for a measured failure

Each customization in FamilyVoice was justified alone (gaze sizes,
contrast), but together they made the app feel less native than a stock
iOS app. Hiding the standard Back button broke navigation and was
reverted.

**Rule.** Start from standard components, navigation, Liquid Glass and
Dynamic Type. Deviate only for a measured failure recorded in
`docs/DECISIONS.md` with its numbers, as narrowly as the failure. Never
hide standard Back or Close.

### Measure system components too

System dialogs and fields failed measured checks: a destructive button at
2.71:1, field borders at 1.37:1, placeholder text at 1.72:1, gray headings
at 3.28:1. White on system red is 3.55:1.

**Rule.** Measure every system component the app presents in light, dark,
Increase Contrast and Reduce Transparency. Where one fails, replace it with
an in-app control using measured colours.

## Process

### Claims must name their evidence

"Stays clear of the keyboard" was geometry plus runs with the keyboard bar;
"checked physically" was a calculation.

**Rule.** Every claim names its evidence (unit test, simulator run with its
configuration, or physical device) and its date. Simulator evidence is
never presented as proof of gaze comfort, sound or Snap to Item behaviour.
Cite symbols and test names, not line numbers.

### Green means a clean checkout

A "green" run once included another agent's uncommitted tests.

**Rule.** Report results only from a clean checkout of the exact commit,
naming the simulator and its configuration. CI on GitHub does this.

### Machine load causes false failures

Parallel simulators caused UI-query timeouts, and XCTest sometimes stalled
about 60 seconds, long enough for a real app timeout to fire.

**Rule.** One simulator per agent, addressed by id. Tests near a timeout
report elapsed time in their failure message. UI tests get a launch
argument that shortens app timeouts, and one test keeps the real limit.

### Never open the project in Xcode from an agent

An agent's Xcode tool rewrote the project file with "recommended settings"
that broke the build.

**Rule.** The Xcode project is generated from `project.yml` and is not
committed. Agents never open it in Xcode.

### One chain engine, not five scripts

The same nearest-control logic was rewritten five times, with different
rules.

**Rule.** Build one chain engine in the test target, and add new screens as
new surfaces, not new scripts.

### Trades are not fixes

A written acceptance bar kept every accepted cost visible.

**Rule.** Record every accepted cost in `docs/DECISIONS.md` with its
numbers and who accepted it. Integrate fixes that interact together.

## Research to keep

Keep categories plus a fixed-column grid with static positions. Paged
layouts with larger targets had 35% fewer errors than a single page (Anson
et al., 2016), and static menus beat adaptive ones (Findlater & McGrenere,
2004; Mitchell & Shneiderman, 1989). No controlled study covers literate
adults with ALS, so category count and wording are decided with users and
families.
