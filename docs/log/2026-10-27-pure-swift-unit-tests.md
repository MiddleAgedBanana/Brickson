# Pure-Swift unit tests for layout, chain scoring and helpers

*2026-10-27. Pull request #64 (`codex/pure-swift-unit-tests`). Agent.*

## What changed and why

Added 18 deterministic Swift Testing (`@Test`) unit tests and extended one
existing test suite across seven test files to pin existing pure-Swift behaviour
in the layout engine, the chain-scoring engine, and supporting model types,
with no changes to production code (docs/DECISIONS.md, "The layout engine",
"One chain engine for dwell safety", and "Apple's current frameworks first"):

- **`BricksonTests/Layout/HomeLayoutEngineTests.swift`** (6 tests):
  - `safetyRowGapReflectsOneRowTwoRowAndDividedSafetyRows`: pins
    `HomeLayout.safetyRowGap` across regular one-row (`nil`), compact
    two-row (`8pt`), `.phrasesOnly` (`8pt`), and horizontally divided
    safety rows (`> 8pt`).
  - `categoryRowGapsFollowTheThreeArrangements`: pins
    `HomeLayout.categoryRowGaps` across `.band` (`[8]`), `.threeColumns`
    (`[8]`), and `.twoColumns` (`[8, 8]`).
  - `boundsHeightAllocationAndHorizontalGapHelpersPinOccupiedAndAllocatedFrames`:
    pins `bounds(of:)`, `height(of:)`, `allocation(_:)`, and
    `horizontalGaps(in:)` on occupied and allocated frames, including empty
    slot lists and single-slot rows.
  - `gridHandlesEmptyColumnFramesScrollOffsetsAndShortfall`: pins
    `HomeLayout.Grid` when initialized with empty `columnFrames` (defaults
    to 1 column and 1 row at `tileSize == .zero`, `tileFrames.isEmpty`,
    `scrollOffset` clamped to `0`), as well as `reflow(in:phraseCount:)` and
    `scrollOffset(for:)` on scrolling grids.
  - `spaceReservedRegionsGetterAndSetterClassifyDivisionsAndOcclusions`:
    pins `HomeLayout.Space.reservedRegions` getter and setter classification
    of full-span bands vs. edge/corner occlusions, plus `Region.isDivision`
    and `Region.isOcclusion`.
  - `slotDescriptionNamesEverySlot`: pins `HomeLayout.Slot.description` for
    all 14 slots in `HomeLayout.Slot.all`.
- **`BricksonTests/Layout/HomeReservedRegionTests.swift`** (5 tests):
  - `unsatisfiableReservationsReportTheirSpecificIssues`: pins
    `HomeReservedLayout.Issue` failure paths (`.insufficientControlSpace` on
    compact, `.phrasesOnly`, and narrow-lane regular vertical divisions;
    `.insufficientPhraseWidth`; `.controlCannotAvoidRegion`;
    `.wellEnvelopeCannotBePreserved`; and `.divisionCrossesScrollingViewport`)
    along with `backToTalking` floor invariants.
  - `horizontalDivisionBetweenThreeColumnCategoryRowsPushesDownSecondRow`:
    pins `.threeColumns` category row splitting across a horizontal
    division.
  - `verticalDivisionChoosesFourOrTwoPhraseColumnsFromLaneWidth`: pins 4 vs.
    2 phrase columns when a vertical division splits Region D with wide vs.
    narrow Bold Text lanes.
  - `phraseGridTrimsOcclusionsOnAllFourEdgesAndControlClearanceFallsBackToZero`:
    pins top, bottom, leading, and trailing edge-occlusion trimming on
    Region D's viewport and the `0pt` clearance fallback in `fitOcclusions`.
  - `wellEnvelopeDirectEdgeCasesHold`: pins `HomeWellEnvelope.preserves(_:_:)`
    directly across zero-size wells, downward `.again` shifts, competing
    controls moving closer than the well's category, and one-row safety row
    `excludesAgain` checks.
- **`BricksonTests/Layout/HomeLayoutEngineFontTests.swift`** (3 tests):
  - `lineChoiceDropsIconBeforeShrinkingAndStepsDownWhenNeeded`: pins
    `LabelFont.lineChoice` icon dropping, size stepping, fallback when even
    the smallest size overflows, and empty `sizes`.
  - `choiceDropsIconBeforeShrinkingWhenIconWrappingExceedsHeight`: pins
    `LabelFont.choice` dropping the icon at the person's text size before
    stepping down font sizes when icon width forces an extra wrapped line,
    plus empty `sizes`.
  - `everyTextStyleAndWeightResolvesPositiveMetrics`: pins
    `LabelFont.Style` (`.title2`, `.title3`, `.headline`, `.body`,
    `.callout`, `.subheadline`) and `LabelFont.Weight` (`.regular`,
    `.medium`, `.semibold`, `.bold`) across `lineHeight` and `wordWidths`.
- **`BricksonTests/ChainEngineTests.swift`** (1 test):
  - `chainEngineEdgeCasesDescriptionsAndChainHelpersHold`: pins
    `NearestRule.nearest(to:in:)` on empty control arrays and zero-size
    rectangles, `ChainStep`, `ChainOutcome`, and `Chain` `description`
    formatting, `ChainMap.chains(from:)` when a start state is missing from
    `states`, `HomeChains.Transition.Step.description` across all cases, and
    `HomeChains.name(of:categories:)` across emergency, typing, and sounding
    states.
- **`BricksonTests/SettingsIdleClockTests.swift`** (2 tests):
  - `settingsActivityTracksResetCountAndHolds`: pins `SettingsActivity`
    `recordActivity()`, `setHold(_:_:)`, `resetCount`, and `resetIfDue()`.
  - `guidedSetupStepOrdersFiveStepsAndStopsAtReady`: pins `GuidedSetupStep`
    count, step numbers (`number`), and `next` progression stopping at `ready`.
- **`BricksonTests/LibraryRulesTests.swift`** (1 test):
  - `everyLibraryEditRejectionCaseHasANonEmptyUserFacingMessage`: pins
    `LibraryEditRejection.message` across all 11 rejection cases.
- **`BricksonTests/CategorySelectionTests.swift`** (1 test extended):
  - `theLastCellHoldsEveryCategoryFromThereOn`: pins
    `CategorySelection.inCell(_:of:cells:)` across empty, non-overflowing,
    overflowing, and negative/out-of-range cell indices.

## Commits

- Pure-Swift unit tests for layout, chain scoring, and model helpers, plus
  `docs/HANDOFF.md` and this log entry.

## Verified

- Ran `scripts/test.sh unit` on macOS with Xcode 27.1 (27A9275) on the
  iPad Pro 13-inch (M5) simulator (`F677BB51-0144-4083-8112-3EC0A8838399`,
  iOS 27.0):
  - 45 documentation, site, and runner tests passed.
  - 124 agent guardrail hook tests passed.
  - 799 native unit tests ran: 790 passed, 0 failed, 1 skipped (existing
    issue #19 crash-probe skip), 8 strict expected failures.
  - `Localizable.xcstrings` remained up to date with the code.
  - App line coverage increased from 71.2% to 72.1% (7,136 of 9,903 lines).
- What would make the new tests fail:
  - Changing `HomeLayout.safetyRowGap`, `categoryRowGaps`, `bounds(of:)`,
    `height(of:)`, `allocation(_:)`, `horizontalGaps(in:)`, `Grid` empty
    column handling (1 column / 1 row fallback) or scroll offset clamping,
    `Space.reservedRegions` classification, or `Slot.description`.
  - Changing `HomeReservedLayout` issue reporting for the five satisfiable/unsatisfiable
    failure paths, `.threeColumns` horizontal division splitting, vertical division
    4-vs-2 column selection, viewport edge-occlusion trimming, `fitOcclusions`
    clearance fallback, or `HomeWellEnvelope.preserves(_:_:)`.
  - Changing `LabelFont.lineChoice` or `LabelFont.choice` icon-before-shrink
    ordering or `Style`/`Weight` font resolution.
  - Changing `NearestRule`, `ChainMap`, or `HomeChains` state naming and
    step descriptions.
  - Changing `SettingsActivity.recordActivity()`, `setHold(_:_:)`, or
    `resetIfDue()`; `GuidedSetupStep.number` or `next`;
    `LibraryEditRejection.message`; or `CategorySelection.inCell(_:of:cells:)`.

## Not verified

- UI automation suites (`scripts/test.sh ui`) and physical-device checks
  were not run in this unit-test-only pull request; CI runs both the unit
  and UI suites on the pull request.

## Follow-ups

- None.
