# Concentric corners: the rule and the shapes, with tests

*2026-11-17. Pull request #121 (`claude/project-thread-ogpi2e`). A
Claude Code cloud thread, for the owner.*

## What changed and why

Nothing a person sees. Apple's current design nests rounded shapes
concentrically: a shape inside another takes the outer corner's radius
less the room between them, so the curves share a centre, as a sheet's
corners follow the screen's (WWDC25, *Get to know the new design
system*; *Adopting Liquid Glass*). Home's controls draw one fixed
12-point corner whatever their window. This adds the foundation the
app's coming look is built from, and leaves every screen as it is
(docs/DECISIONS.md, "Concentric corners"):

- `CornerRule` (`Brickson/Layout/CornerRule.swift`): Apple's three kinds
  of corner, fixed, capsule and concentric, as plain numbers. A
  concentric corner never goes below a minimum, 12 points, today's
  corner, so a tile deep in a grid is never square; a ring inside a tile
  takes the tile's minimum less its inset and stays concentric with it.
- `CornerRule.Kind.shape` and `concentricContainer(radius:)`
  (`Brickson/Home/CornerShapes.swift`): each kind drawn with SwiftUI's
  own shapes, `ConcentricRectangle` with `.concentric(minimum:)` for the
  concentric one, which takes its radius from the window or the nearest
  container shape. No code works out a window's radius or names a
  device.

Which control takes which kind is the owner's look, so nothing adopts
them yet.

## Commits

- `2ffd4bf` The rule, the shapes and both test suites.
- `b98c05a` This record, the decision and the handoff's gap.
- `aabf3c6` From review: the capsule's drawing test, and the handoff
  naming which controls draw a fixed corner today.
- A merge of `main`, so the UI tests run in their new parts.
- The commit that records CI's first result here.
- From review: every drawing test fails on a blank drawing. Before, the
  capsule's could pass one, since a blank drawing is closest to the
  roundest candidate and every candidate from the capsule's radius up
  draws the capsule. The check compiled without warnings in a Linux
  probe and failed a blank drawing there with its message.

## Verified

- `CornerRuleTests`, 12 tests, run on Linux with Swift 6.4.2 in a
  scratch package outside the repository (the rule and
  `HomeButtonLook` with their plain Foundation dependencies, default
  main-actor isolation as the app builds): all passed, no warnings. Each
  fails when the rule breaks, tried by changing the code and running
  again: without the minimum, 6 tests fail (a deep corner, a ring's
  concentricity, the nested example, each kind's radius, the capsule
  limit, nothing square); with a ring's minimum not reduced, 3 fail;
  without the capsule limit on a fixed corner, 1 fails.
- CI's unit job on the first push (`b98c05a`): every unit test passed,
  among them `CornerRuleTests` and the first five `CornerShapesTests`,
  so SwiftUI drew each concentric corner at the radius the rule gives,
  to half a point: 30 points 10 points in, the minimum 32 and 56 points
  in, and a ring 6 points less than its tile both ways. `ImageRenderer`
  passes the container shape on. The drawing tests add about 19 seconds
  to the unit run. The capsule's drawing test came in the second push
  and runs there first.
- The Python checks: `test-docs`, `test-hooks`, `test-privacy`,
  `test-forbidden-code`, `test-runner`, `test-agent-bridge`, `test-site`
  and `test-select-xcode` all passed, and `forbidden-code.py` found
  nothing.
- Apple's documentation, read 2026-11-17 in its Markdown form:
  `ConcentricRectangle`, `Edge.Corner.Style`, `concentric(minimum:)`,
  `containerShape(_:)`, `RoundedRectangularShape`, `Capsule.init(style:)`,
  `RoundedRectangle.init(cornerRadius:style:)`, `ImageRenderer` and
  `AnyShape`; all available from iOS 26.0, the deployment target. The
  WWDC25 session's words were read from its transcript.

## Not verified

- Nothing was built for iOS in this session, which cannot compile
  SwiftUI: CI is the build of record for `CornerShapes.swift` and
  `CornerShapesTests`.
- Which curve `ConcentricRectangle` draws, continuous or circular: the
  measure accepts either and says which matched in a failure message.
- What SwiftUI does with a different room across than down; the rule is
  written for even padding (docs/DECISIONS.md, "Concentric corners").
- Anything on a device or in the running app: no screen uses the
  shapes.

## Follow-ups

- The owner's design of the app's look chooses which controls take
  which kind of corner, and whether the minimum stays 12 points.
- The change that adopts the shapes checks that every label stays clear
  of a larger curve, that each target floor holds at a rounder corner,
  and, if it pads a shape unevenly, what SwiftUI draws then
  (docs/HANDOFF.md, *Known gaps*).
