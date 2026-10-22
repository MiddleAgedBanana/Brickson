# Home's scan order and names

*2026-10-22. Pull request #26, from `claude/project-thread-soi3j3`. The
"Accessibility implementation, first pass" thread, a cloud session that
cannot build or run the app.*

## What changed and why

The first accessibility work after the coverage list
([`2026-10-21-accessibility-coverage.md`](2026-10-21-accessibility-coverage.md),
*Follow-ups*, R0 item 3), built on the Home that PR #22 lays out from the
space it is given. It takes the first three parts of item 3's list: the
order in which assistive technologies reach Home, Home's regions as
containers, and the names Voice Control uses. Decision: docs/DECISIONS.md,
"Home's scan order and names" (new).

What a person notices:

- **Switch Control, Full Keyboard Access and VoiceOver reach Yes, No and
  Emergency first**, then the message with Again, then the categories,
  then the phrases, in every state. Before, they followed the screen from
  the top, so the message and Again came first: with auto scanning, a
  person waited through them before every Yes or No. On screen nothing
  moves.
- **Each of Home's regions is an accessibility container**, so its
  controls are reached together and, with Switch Control's Group Items,
  can be offered as a group (whether Switch Control does is a device
  check).
- **Voice Control and Full Keyboard Access names.** Yes, No, Emergency and
  Again answer to their visible words, listed first; Again also answers to
  "Repeat". No two controls on Home share a name, whichever category
  shows.

How it is built:

- **`HomeRegion`** (new, `Brickson/Home/HomeRegion.swift`): the four
  regions in the order they are reached, each with a fixed accessibility
  sort priority and a test identifier. SwiftUI orders elements of equal
  priority by where they are, which would put the message first, so the
  priorities are what make the order. The library warnings stay outside
  the regions, at the default priority, so they come last.
- **`HomeControlNames`** (new, `Brickson/Home/ControlNames.swift`): the
  fixed controls' visible words and other names, which `HomeView` now
  reads for its labels and `accessibilityInputLabels`; `onHome` lists
  every control on one screen by its names, and `collisions` finds a name
  that two controls answer to, comparing names as Voice Control hears
  them (lower case, no accents, no punctuation). The editing thread can
  use it to warn when a family's phrase collides.
- **`HomeView`**: `.homeRegion(_:)` on the message block, the quick
  controls, the categories and the phrase grid (`.contain`, the sort
  priority and the identifier, after each region's frame); input labels on
  Yes, No, Emergency and Again.
- **String Catalog**: "Repeat", added by hand with its comment, since a
  cloud session cannot run the catalog sync.

Documents: docs/ACCESSIBILITY.md (the Voice Control, Switch Control and
brain-computer interface map rows; Switch Control scanning, scanning
groups, `accessibilityElement(children:)`, `accessibilitySortPriority`,
`accessibilityRespondsToUserInteraction`, `accessibilityInputLabels` and
name collisions; a line saying rows change with each pull request);
docs/DECISIONS.md (the new entry and its row in *Decided by default*);
docs/HANDOFF.md (what the app does, the pointer to these follow-ups, and a
device check); docs/ROADMAP.md (item 3's status); AGENTS.md (the two new
plain types in *Workflow rules*).

## Commits

- The code and its tests: `HomeRegion`, `HomeControlNames`, `HomeView`'s
  regions and input labels, the catalog entry, `HomeRegionTests`,
  `ControlNamesTests`, `HomeNameCollisionTests`,
  `HomeAccessibilityOrderTests`.
- The records: this file and the documents above.
- A merge of PR #22's branch after it took in `main` (PR #23) and began
  measuring labels under Bold Text; then this record's CI results and
  follow-ups.

## Verified

Nothing was built or run on a Mac; GitHub CI is the build (AGENTS.md,
*Build and test*).

- **GitHub CI on `dc4dda3`** (the two commits on PR #22's branch at
  `9cf0e76`, before the merge above), built with Xcode 27.1: the unit
  tests passed, `HomeRegionTests`, `ControlNamesTests` and
  `HomeNameCollisionTests` among them. The UI tests ran 24 on an iPad Pro
  13-inch (M5) and an iPhone 17 simulator, both iOS 27.0: 20 passed, 4
  skipped (the opt-in keyboard probe), none failed.
  `HomeAccessibilityOrderTests` passed on both, at the default and the
  largest text size, portrait. Codex's review and the security scan
  found nothing. The run after the merge above is on the pull request.

- **Linux Swift 6.3.3** (a throwaway package outside the repository, Swift
  6 language mode, main-actor default isolation, a stand-in for
  `String(localized:)`): `HomeRegion`, `HomeControlNames`,
  `HomeRegionTests` and `ControlNamesTests` compiled and their 11 tests
  passed. Each of these changes made at least one of them fail: the
  message region's priority above the quick controls'; the phrase region
  at the default priority; two regions sharing an identifier; the visible
  words listed after the other names; names compared with their case;
  one control's repeated name counted as a collision; the category row
  left out of `onHome`; names with nothing to say compared; Emergency
  left out of the fixed controls.
- **The starter library**, checked with a short script before
  `HomeNameCollisionTests` existed: no collision in any of the five
  category states.
- **`HomeAccessibilityOrderTests`** type-checked on Linux against
  stand-ins for the XCTest types it uses before it ran on CI.
- New tests and what would make them fail: `HomeRegionTests` (a region
  reached before the quick controls, two regions tied, a region at the
  default priority, a shared identifier); `ControlNamesTests` (a fixed
  control whose names do not start with its visible words, an empty or
  repeated name, a change to the decided names, and the comparison rules
  above); `HomeNameCollisionTests` (a starter phrase, category or fixed
  control name that sounds the same as another control on the same
  screen); `HomeAccessibilityOrderTests` (anything before Yes, No and
  Emergency, Again or a category out of place, a phrase tile before the
  categories, or a control outside its region, in each category, with
  the emergency phrases and after a phrase is spoken, at the default and
  largest text sizes, portrait, on the iPad and the iPhone CI runs).

## Not verified

- **That XCTest reads the order VoiceOver and Switch Control use.**
  `HomeAccessibilityOrderTests` walks the accessibility tree XCTest
  receives from the app, which Apple does not document as the order
  assistive technologies step through. The VoiceOver walk with
  `XCUIVoiceOverService` (iOS 27, item 2's follow-up) and the device
  check below are the evidence for that.
- **Switch Control groups.** Whether a SwiftUI `.contain` container
  becomes a Switch Control scan group is not documented; a device check
  (docs/HANDOFF.md, *Checks that need a real device*).
- **What is said on entering a region.** The regions have no spoken
  labels; whether VoiceOver or Switch Control's speech should announce
  one is for the device check.
- **Voice Control** with "Repeat", "Show names" and the collision rules:
  how Voice Control matches names (case, punctuation, iOS 27's flexible
  names) is inferred, not documented; device check.
- Landscape and windowed iPads are not in the order test; regions are
  reached by priority there too, and controls inside a region in their
  order on screen.

## Follow-ups

For the next accessibility thread, the rest of item 3's list, in this
order (each from docs/ACCESSIBILITY.md, section 6, unless named):

1. **Bold Text in the narrowest slots.** PR #22 now measures labels at
   the heavier weight SwiftUI draws with Bold Text on
   (`LabelFont.legible`, checked by `StarterLabelFitTests`), but checks
   the starter labels' fit in their narrowest slots with Bold Text off
   only (docs/log/2026-10-21-phone-layout.md, *Not verified*). Extend
   that check to Bold Text on.
2. **The Large Content Viewer** (`accessibilityShowsLargeContentViewer()`)
   on every Home control whose label the fitting type shrinks
   (`FittedLabel`'s `minimumScaleFactor`), so a person at an accessibility
   text size can touch and hold to read it large. Check that lifting the
   finger still activates the control only once.
3. **Show Borders**: `HomeButtonStyle` draws a border inside its frame
   when the setting is on, with the border colour pinned in
   `PaletteTests`. Read Apple's page for the current SwiftUI value first
   (`accessibilityShowButtonShapes` and UIKit's `buttonShapesEnabled` are
   deprecated).
4. **`@ScaledMetric` for non-text sizes** on Home (paddings, gaps, corner
   radius, the label inset) and no Dynamic Type cap, kept inside
   `HomeShape`'s floors so nothing scrolls that does not already.
5. **The motion policy** (Reduce Motion, and Prefer Cross-Fade
   Transitions behind `#available(iOS 26.4, *)` with UIKit's value before)
   when the first custom transition arrives: likely Settings' cover from
   PR #23. Reduce Bright Effects: pressed and alarm styles stay steady,
   with item 4.
6. **After the device check:** labels on the regions if VoiceOver or
   Switch Control needs them, and `accessibilityRespondsToUserInteraction`
   on passive text only if the cursor stops on it.

For the thread that puts Get Attention and Stop on Home (R0 item 4): add
their names to `HomeControlNames.fixed`, decide whether "Help" belongs to
Get Attention, and keep them in region C; the collision and order tests
then cover them. For the editing thread (R0 item 6): use
`HomeControlNames.collisions` to warn about a family's phrase or category
that collides, never renaming it.
