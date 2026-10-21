# Brickson layout engine and input profiles: blueprint (port step 4)

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Design only. Nothing was built or run: I had no shell and no simulator. Every number below is hand arithmetic from stated assumptions, labelled as such, and the matrix tests in section 7 replace it. Facts I could not confirm are in section 10.

## 0. Read this first

### 0.1 The brief's two gaze figures do not reconcile

The message said gaze targets are about 4 degrees, "about 110 pt at 45 cm on an iPad". Those are different sizes.

- 110 pt on a 264 ppi iPad (132 pt/in, 5.197 pt/mm) is 21.2 mm. At 450 mm that is **2.69 degrees**.
- 4 degrees at 450 mm is 31.4 mm, about **163 pt**. 110 pt is 4 degrees only at about 30 cm.
- My searches did not find a 4 degree figure.
  - Meta's eye-gaze design guidance says at least 3.0 degrees.
  - A university study kept every component at 2 degrees or more.
  - Applied gaze work treats about 1 degree as the accuracy floor.
  - None is an AAC study.

**What I did.**

- Floor: AGENTS.md's numbers (110, 88, 72 pt at about 45 cm). They are binding text.
- Preferred size: 4 degrees. The engine grows targets toward it when the window has room, and never below the floor.
- The engine stores each target as `TargetSpec(floor:, preferred:)`, both as visual angle. If the owner wants 4 degrees as the floor, that is a one-row data change.

What each reading means, by hand (rows from section 6):

| Reading | Gaze starter library fits without scrolling on |
|---|---|
| Floors 111/90/74 pt (reference) | every iPad except the mini in landscape |
| Floors 164/135/111 pt (4 degrees) | only iPad Pro 13 and Air 13 (both orientations), and 11-inch iPads in portrait. The 11-inch landscape, iPad 9th gen landscape and mini fail, and typing above the keyboard fails on 11-inch landscape. |

The owner should decide this with the table in front of them (section 9, item 1).

### 0.2 The smallest supported phones fail with the original plan

| Phone | Spare height at default text, touch floors, E band dropped | With an E band reserved |
|---|---|---|
| iPhone SE 2/3 (375×667) | **27 pt over** | 85 pt over |
| SE with Display Zoom (320×568) | **48 pt over**, and 125 over if three columns cannot hold the longest word | worse |
| iPhone 12/13 mini | 47 pt spare | 11 pt over |
| Every other supported phone | 115 to 140 pt spare | 58 to 82 pt spare |

- A reserved utility band (E) costs 55 to 58 pt on every phone, so it is **out of the default map**.
- I did not place Settings, Edit or Done. Section 4.6 says why and what any later placement must pass.
- SE-class screens still fail, and typing above the keyboard fails on them too (section 6). This is an owner decision (section 9, item 3).
  - Recommended: SE-class phones are not offered the switch profile. They use compact floors, which are never below 44 pt.
  - The alternative is touch with a scrolling grid, plus a named typing exception.

### 0.3 The iPhone 17 findings from the simulator run

These are the coordinator's observations. I did not reproduce them, but they match the stand-in code.

| Observation | Cause in the stand-in | Design response | Named test |
|---|---|---|---|
| "Emergency" hyphenates at default text size | Three equal buttons share 370 pt, about 115 pt each, with a `.title3` label and an icon (`HomeView.swift` lines 154 to 202). | On compact phones Emergency sits in a two-slot row, about 180 pt wide. `WordFit` keeps a single word whole, drops the icon first, and never goes below `.large`. Single-word labels get `lineLimit(1)`, so a too-wide word shows as truncation, not a break. | `WordFitTests.emergencyKeepsItsWordWholeInItsPhoneSlotAtDefaultSize`, `LayoutMatrixTests.everyStarterLabelFitsItsSlotOnEveryDeviceClass` |
| The category row scrolls sideways | `ScrollView(.horizontal)` (line 216) | The category band has a fixed capacity of 4 starter categories plus a pinned Stop Alert cell. Only grown libraries scroll, and the plan says so. | `LayoutMatrixTests.noHomeRegionScrollsForTheStarterLibraryWhereAProfileIsOffered` |
| The 8-phrase Basics category scrolls | Two columns, `minHeight: 96`, inside a `ScrollView` (lines 38 to 41, 255 to 268) | Phrase grid is 3×3 on compact phones. By hand it fits with 115 to 140 pt spare on an iPhone 17, 16, 15, 14, 13 or 12. | `LayoutMatrixTests.starterLibraryFitsWithoutScrollingOnEveryOfferedPhone`, plus a UI capture asserting the last tile is hittable with no scroll view |
| At the largest accessibility size, quick-control labels clip to a bar | Fixed `minHeight: 64`, no fitting (lines 192 to 202) | `WordFit` steps each label down toward `.large`. Only the message block grows with Dynamic Type. | `WordFitTests.quickControlLabelsStepDownInsteadOfClippingAtAX5`, plus the existing accessibility audit's clipped-text check at AX5 |

**Hyphenation cannot be seen by XCUITest.** The accessibility label stays "Emergency" whatever is drawn. The engine prevents it structurally, the audit catches truncation, and a person has to look at a screenshot. Record that review in HANDOFF.

## 1. What exists today (the facts that bind)

Absolute root: `the repository root (a planning worktree on the owner's Mac)`.

- `Brickson/Home/HomeView.swift`:
  - A `VStack(spacing: 16)` of `MessageRow`, `QuickControlsRow`, `CategoryRow`, `PhraseGrid` and `StatusArea`.
  - Literal sizes throughout (64, 88, 96, 52).
  - `columnCount: horizontalSizeClass == .regular ? 3 : 2`.
  - Two `ScrollView`s: the category row and the grid.
  - Again sits beside the message text. DECISIONS accepts that for the stand-in only.
  - The message row reserves two lines. `StatusArea` reserves the tallest short warning.
- `Brickson/Home/CategorySelection.swift`: pure and reusable (`shownInCategoryRow`).
- `Brickson/Speech/AudioSafetyPolicy.swift`: the typing recovery copy says "Choose Phrases, then choose Again", and `AudioSafetyPolicyTests` asserts it never says "Speak".
  - The way out of typing is therefore named **Phrases**.
  - Again is not on the typing screen.
- `project.yml`: Swift 6, default main-actor isolation.
  - Pure types in this repo are written `nonisolated`.
  - `Brickson/Layout/` is picked up automatically.
  - The UI test target defaults to nonisolated.
- Iphone orientations are portrait only, and `AppBundleTests.theIPhoneIsPortraitOnly` pins that.
- Test conventions:
  - Swift Testing `struct XTests`.
  - Plain loops with messages (`PaletteTests`).
  - Inputs passed in, with `start + offset` for time.
  - Failure injection via parameters (`save:`).
  - Every test names its failure.

## 2. Architecture decision

**One pure function, one thin SwiftUI shim, one test-target chain engine.**

- `HomeLayoutEngine.plan(_:) -> LayoutPlan` is nonisolated and has **no screen-state input**. Frames are identical in browse and typing by construction.
- A `GeometryReader` reads the window size and safe-area insets. A small UIKit reader supplies `nativeBounds`, `nativeScale` and corner insets. A custom nonisolated `Layout` (`SlotLayout`) places standard Buttons at the plan's frames.
- Columns and the slot grid depend on window size and a fixed per-device-class table only. They do not depend on profile, text size or library.
- Profiles change sizes and spacing, never topology.
- The library feeds only the verdict and the grid's scroll extent. It never sets any region's height.

**Why a custom `Layout` and not `.position` or bare `GeometryReader`.**

- `.position` makes every child fill the container.
- Bare `GeometryReader` leaves placement scattered in views, so tests could not pin it.
- `Layout` gives each subview an exact proposal and one place that maps slot to frame.
- `Layout` is iOS 16 and later, and its declaration is `@preconcurrency protocol Layout : Sendable, Animatable`, not main-actor. Under Swift 6 default isolation, `SlotLayout` must be declared `nonisolated`, and its pure part (`SlotPlacement`) gets a test in `OffMainThreadCallbackTests`.

## 3. The profile model

### 3.1 Physical size, per device, without private API

```swift
nonisolated struct Millimetres { var value: Double }
nonisolated struct VisualAngle { var degrees: Double }
nonisolated enum PhysicalSize {
    static func extent(_ angle: VisualAngle, at distance: Millimetres) -> Millimetres   // 2·d·tan(θ/2)
}
nonisolated struct PointsPerMillimetre { var value: Double }   // ppi / (25.4 × nativeScale)
```

- **Points per millimetre = ppi ÷ (25.4 × nativeScale).** `nativeScale` is the native pixel width over the point width, so Display Zoom changes it correctly.
  - Under zoom, a point is physically bigger. A zoomed 6.1 inch iPhone is 320×693 pt with `nativeScale` about 3.66 (an iOS 15 measurement).
  - That gives about 4.95 pt/mm against 6.04 unzoomed.
- Read `nativeBounds` and `nativeScale` from the window scene's screen through a small UIKit reader. Do not use `UIScreen.main`: it is deprecated, and the WWDC26 summary says not to rely on it.
- Do not use SwiftUI `displayScale`. It likely follows `scale`, not `nativeScale`. Unverified, so avoid it.
- **ppi table keyed by native panel pixels** (`NativeScreen(short:, long:)`), not by point size. Point sizes collide: 768×1024 is the iPad mini 5 at 326 ppi and the 6th-gen iPad at 264 ppi.
  - The 12/13 mini draws at 1125×2436 but its panel is 1080×2340, so `nativeScale` is 2.88 and pt/mm is 6.51, not 6.25. Keying by `nativeBounds` gets this right.
- Rows come from published pixel sizes and ppi. All iPads are 264 ppi except the mini (326). iPhones are 326, 458, 460 or 476.
- **Self-check test.** For every row, `hypot(w, h) / ppi` must match the published diagonal within 0.05 in. I checked a dozen rows by hand and all agreed (SE 4.69, iPhone 11 6.06, 12 mini 5.41, 15 6.12, 16 Pro 6.27, iPad Pro 13 13.03, mini 7 8.32). A typo in a pixel size or ppi fails the build.
- **Unknown devices** get the **largest ppi in the table for their idiom**. That makes floors in points larger, never physically smaller. It may produce an honest "does not fit" verdict.
- Rejected: `utsname.machine` model identifiers. They need a row per release, and they ignore Display Zoom.
- Not covered: iPhone Mirroring and iPhone apps hosted on iPad (WWDC26 session 278). Physical size is meaningless there, so use the fallback and flag it.

### 3.2 Profile defaults (proposed; the owner decides distances and angles)

Floors are `max(44 pt, ceil(extent(angle, distance) × ppmm))`. Preferred sizes only drive the distribution step.

| Profile | Distance | Floor angles (tile / quick / category / utility) | Preferred | Gap / harmful gap / margin / corner clear (mm) | Scroll on Home | Pointer or scan scoring |
|---|---|---|---|---|---|---|
| `touch` | 350 | 2.0 / 1.8 / 1.5 / 1.2 | 3.0 / 2.6 / 2.2 / 1.5 | 1.5 / 2.5 / 2.5 / 0 | allowed | no |
| `keyboardAndVoice` | 350 | as touch | as touch | as touch | allowed | no |
| `switchControl` | 350 | **as touch** (nobody aims) | as touch | 1.5 / 2.5 / 2.5 / 0 | never for the starter library | scan models |
| `head` | 500 | 2.3 / 1.9 / 1.6 / 1.6 | 3.2 / 2.7 / 2.2 / 2.2 | 2.5 / 4.0 / 3.0 / 10 | never for the starter library | pointer models |
| `gaze` | 450 | **2.7 / 2.2 / 1.8 / 1.8** | **4.0 / 3.3 / 2.7 / 2.7** | 2.5 / 4.0 / 3.0 / 10 | never for the starter library | pointer models |

Absolute minimums: 44 pt targets, 8 pt gaps, 16 pt margins.

- `switchControl` covers manual scan, auto-scan and the iOS 26 brain-computer-interface path. Apple's BCI HID reference says the device acts as an input device for system features such as Switch Control and AssistiveTouch. The app sees only the accessibility tree, so one profile suffices.
- `keyboardAndVoice` has touch sizes. Its extra rule is that visible label text must equal the accessibility label, so no icon-only controls.
- Eye Tracking: Apple tells people to sit about a foot and a half away, so 450 mm for gaze is right on iPad and on iPhone.

Points on 264 ppi iPads (132 pt/in, 5.197 pt/mm), iPhone 17 (460 ppi at 3×, 6.04 pt/mm) and SE (326 ppi at 2×, 6.42 pt/mm), tile / quick / category / utility:

| Profile | iPad | iPhone 17 | SE |
|---|---|---|---|
| touch / keyboard+voice / switch | 64 / 58 / 48 / 44 | 74 / 67 / 56 / 45 | 79 / 71 / 59 / 48 |
| head | 105 / 87 / 73 / 73 | n/a | n/a |
| gaze floor | **111 / 90 / 74 / 74** | 129 / 105 / 86 / 86 | n/a |
| gaze if 4 degrees were the floor | 164 / 135 / 111 / 111 | 190 / 160 / 129 / 129 | n/a |

**Calibration assumption.** Pinning "110 pt" to 132 pt/in assumes the reference app's iPad was a 264 ppi model. I could not read that private repository to confirm it. On an iPad mini (163 pt/in), 110 pt is 17.1 mm, 20 percent smaller. The owner should confirm which iPad the reference numbers were tuned on.

### 3.3 Which profile is offered where

A fixed table keyed by device class, decided by the owner. It is **not** derived from the engine's own fit result, which would make column counts depend on a verdict.

- "Offered" means "tested to fit", not "allowed". Nothing is ever blocked. A non-offered choice gets a best-effort plan at floors and a passive notice.
- The shape (columns, rows) is computed at the **strictest offered profile** for the device class. That keeps the touch and gaze layouts on one device identical in topology.

| Device class | Offered | Strictest offered |
|---|---|---|
| Compact-height phone (SE 2/3, any phone under about 700 pt of screen height, zoomed small phones) | touch, keyboard+voice | touch (compact floors, see section 9 item 3) |
| Other phones | touch, keyboard+voice, switch | switch (equal to touch sizes) |
| iPad mini | touch, keyboard+voice, switch | switch (gaze and head fail in landscape) |
| iPad 9th gen, 10th gen, A16, Air 11, Pro 11 | all five | gaze |
| Air 13, Pro 13 | all five | gaze |

- **Gaze and head on phones are an owner decision backed by numbers, not part of the design.** By hand, gaze on an iPhone 17 needs about 1258 pt of height against 874, and three columns cannot fit (3×129 + gaps is about 419 pt against a 364 pt content width).
- Defaults when the person has not chosen: the strictest offered profile for the device, so someone who can only use their eyes can operate it on first launch. Family setup (step 7) lets them choose smaller.

### 3.4 Dwell protection and exclusion zones (checked by placement, never by timers)

`DwellRules` are pure functions over a `LayoutPlan`, used by the engine's diagnostics and by tests:

1. **Rest points have a harmless nearest control.** The rest set is the message text, the status footer, every hidden or reserved cell, the window corners, and the bottom centre.
2. **Start and stop are apart.** Get Attention and Stop Alert are at least two target sizes apart, and neither is nearest to any point of the other.
3. **Harmful pairs use the harmful gap.**
4. **No control in an exclusion zone.** Zones:
   - the four window corners, `cornerClear` square (head and gaze only);
   - the window-controls corner, from measured corner insets (the iPadOS 26 controls sit at top-leading);
   - the home-indicator inset;
   - the bottom reserve, `max(bottom inset, cornerClear)`.
5. **A slot keeps its hazard class in every state.** Aliases (section 4.3) must match.
6. **Activating a control never disables or hides it unless a harmless control is then nearest.** A disabled control hands the pointer to its neighbour. For this reason Speak never disables itself after speaking, and Stop Alert sits above Emergency so its own disappearance leaves the pointer on a harmless control.

## 4. The slot model

### 4.1 Regions (top to bottom), identical in browse and typing

| Region | Browse | Typing |
|---|---|---|
| A: message block | message text, status footer (speaking indicator + audio warnings, one reserved line), `type` slot trailing | the draft field takes the message text's frame. The footer and `type` stay. |
| B: categories | category cells + pinned Stop Alert cell | **all category cells stay enabled**, each exits typing to its own category. Slot 0 is labelled "Phrases". |
| C: safety | Get Attention, Yes, No, Again, Emergency | Speak takes Again's slot. Everything else unchanged. |
| D: phrase grid | tiles | hidden (the keyboard is here) |

- The status footer is **inside A**, above the keyboard line, so warnings stay visible while typing.
- There is no bottom utility band in the default map (section 0.2).
- Typing never shows category buttons as empty cells, so there is no large rest trap in B.

### 4.2 Arrangements by window class

Window class comes from content width and the fixed device table only.

| | Compact (content under about 520 pt, phones) | Regular (iPads, wide windows) |
|---|---|---|
| A | text + `type` trailing | same |
| B | 2×2 category region (scrollable at the floor) plus a pinned tall right-hand Stop Alert cell | 1×4 category region plus a pinned Stop Alert cell at the right end |
| C | row 1: **Get Attention, Emergency**; row 2: Yes, No, Again/Speak | one row: **Get Attention, Yes, No, Again/Speak, Emergency** |
| D | 3 columns, 3 rows capacity | 4 columns; rows from height (3 portrait, fewer when height requires) |

- **Stop Alert** sits in B's pinned trailing cell, directly above **Emergency** in both arrangements. Stop is far from Get Attention (opposite end), above the keyboard line, and its own disappearance leaves the pointer on Emergency, which is harmless.
- **Get Attention** is the leading slot of C.
- Compact phone widths for the iPhone 17 (370 pt content): the C row 1 slots are about 180 pt wide, B category cells about 117 pt wide, tiles about 117 pt wide.
- Column count is 3 on compact unless the longest starter word at the tile style's default size cannot fit, in which case it is 2. The tile text style is a per-window-class constant chosen so the starter words fit. A pinned test measures it.
- Phrase-grid capacity is `columns × rows`, set by window size. Rows are `min(targetRows, rows that fit at the strictest offered floors)`. A library bigger than capacity scrolls only inside D, at the floor.
- Category capacity is a constant tied to `StarterShape.shownCategories` (4). Category column width has a label budget (about 112 pt on phones, to be pinned by measuring "Conversation" at the label style's default size). Extra categories scroll inside B at the floor; the Stop cell stays pinned.

### 4.3 Slots, hazards, aliases

```swift
nonisolated enum SlotID: Hashable, Sendable {
    case messageText, statusLine, type, draft
    case category(Int), phrases          // phrases aliases category(0) while typing
    case getAttention, yes, no, again, speak, emergency   // speak aliases again
    case stopAlert
    case tile(row: Int, column: Int)
}
nonisolated enum Hazard: CaseIterable, Sendable {
    case speaks, alarms, stopsAlarm, deletes, reorders, merges,
         changesTextSize, entersEditMode, changesSetting, editsDraft
}
```

The last three beyond your list (`stopsAlarm`, `changesSetting`, `editsDraft`) are additions.

| Slot | Hazards |
|---|---|
| `tile`, `yes`, `no`, `again`, `speak` | speaks |
| `getAttention` | alarms |
| `stopAlert` | stopsAlarm |
| `emergency`, `category(i)`, `phrases`, `type` | none (mode switches) |
| `draft` | editsDraft (until a device check says otherwise) |

- **Aliases share a frame and a hazard class**: `phrases` with `category(0)`, `speak` with `again`. `phrases` exits typing to category 0, so a second dwell on that slot is a no-op.
- `draft` replaces the passive message text, which is not a control. That is a named exception (section 4.5).
- **`type` persists in typing with a selected look** (checkmark, Selected trait). It never turns into its opposite. The exit is a different slot.

### 4.4 Scan order and containers

The plan emits `scanOrder`, independent of visual position: `emergency, getAttention, yes, no, again|speak, type, category(0…3)|phrases, stopAlert, tile(…) row-major`. Views apply it with `accessibilitySortPriority`. Each region is an accessibility container.

The UI test checks that the XCUI element order for shared slots is identical across profiles and states. Whether Switch Control follows sort priority and containers is a device check.

### 4.5 Rest points and named exceptions

Hand-checked on the default map:

- **iPhone 17.** Message text points: the nearest controls are `type` and the category cells (harmless). The footer: category cells. The hidden Stop cell: Emergency below, category above (harmless).
- **iPad Pro 13.** Message text: `type` and the category cells. The hidden Stop cell sits over Emergency, 50 pt away, with Settings-sized controls farther.

Exceptions the design cannot remove. The owner must record them in `docs/DECISIONS.md`:

1. Empty cells of the phrase grid have a speaking tile nearest.
2. The blank bottom band (dwell profiles) has the bottom-row tiles nearest.
3. In typing, the draft is the text being read and a control. A second tap on a focused field opens the system edit menu (Select All, Paste, Cut), and the chain engine cannot see that menu. A possible mitigation (focus the field programmatically and ignore hits on it) needs a device check. I did not commit to it.
4. Floating and split keyboards can cover anything on iPad.
5. Window-control snapping: unknown whether Snap to Item reaches the iPadOS 26 close and minimize buttons. This is a device check. Keep message text out of the controls' corner either way.

### 4.6 Reserved and future slots, recents zone

- `SlotMapTests` pins every slot's `(region, row, column)` so the map is append-only.
- I did not place Settings, Edit or Done. Rules for placing them later: harmless-only neighbours, start and stop in different slots (Edit and Done separate), nothing in a corner, nothing under the keyboard line that must be reachable while typing, and a passing chain run.
- Recommended: Edit starts inside Settings, and Settings takes a harmless slot beside `type`.
- A recents zone, if built, is a fixed-capacity band of speaking cells just below C that takes one grid row from D. Only its contents change.

## 5. The engine

### 5.1 Inputs and outputs

```swift
nonisolated struct LayoutInput: Equatable, Sendable {
    var window: WindowGeometry      // size, safeAreaInsets, cornerInsets (window controls), multitasking
    var device: DeviceMetrics       // DeviceClass, pointsPerMillimetre, fullScreenSize
    var profile: InputProfile
    var textSize: DynamicTypeSize
    var text: TextMetrics           // measured line heights at textSize (UIFont, pinned by a test)
    var library: LibraryShape       // shownCategories, largestPhraseCount
    var keyboard: KeyboardAllowance // worst-case docked height for (class, aspect, OS)
    var isRightToLeft: Bool
}
nonisolated struct LayoutPlan: Equatable, Sendable {
    let frames: [SlotID: CGRect]    // every slot incl. alias and typing-only; window coordinates
    let scanOrder: [SlotID]
    let regions: [SlotRegion: CGRect]
    let grid: GridPlan              // columns, rows (capacity), cell, spacing, contentRows, scrolls
    let categoryBand: BandPlan
    let exclusionZones: [ExclusionZone]
    let keyboardLine: CGFloat
    let verdict: LayoutVerdict
    let minimumWindow: CGSize
}
nonisolated enum LayoutVerdict: Equatable, Sendable {
    case fits
    case scrollsAtFloor(Set<SlotRegion>)                       // only .phrases and/or .categories
    case windowTooSmall(minimum: CGSize)                       // a larger window of this device fits
    case profileDoesNotFitDevice(minimum: CGSize, binding: LayoutConstraint)
}
```

- `LayoutInput` has **no typing or screen-state field**. `HomeLayoutEngineTests.theEngineHasNoScreenStateInput` guards it by reflection.
- Orientation is derived from the window's aspect, not from the device. The WWDC26 summary says not to use interface orientation in layout.
- Window position is **not** an input. Position feeding layout would move controls while a window is dragged. The keyboard allowance therefore assumes the full docked height measured up from the window's bottom.
- `profileDoesNotFitDevice` means the profile's minimum exceeds the device's **full screen in the current aspect**. Otherwise it is `windowTooSmall`.
- Below the minimum (`sizeRestrictions` is best effort), Home renders A and C pinned at floors, with B and D in one scroll region. Never below 44 pt.

### 5.2 Pipeline (each step has its own tests)

1. Resolve floors, gaps, margins and corner clear in points. They are the larger of the angle-derived size and the absolute minimum.
2. Choose the **window class**: columns from content width and the strictest offered floors, and arrangements (section 4.2). Rows come from height at those floors.
3. Heights at the active profile's floors. A is from `TextMetrics`, and at least `cornerClear − topInset + target` so trailing controls sit below the corner band. Needed height is `top + A + B + C + D + 3 band gaps + bottomReserve`.
4. **Typing line**: `top + A + B + C + 2 gaps` must be at most `windowHeight − keyboardHeight − gap`. K comes from `KeyboardHeightTable`: measured per (class, aspect), maximum over iOS 26.5 and iOS 27, with a provisional conservative fallback until measured.
5. Verdict: `fits`; or `scrollsAtFloor` if only D or B must scroll and the profile or library allows it; else `windowTooSmall` or `profileDoesNotFitDevice`.
6. Distribute spare height in a fixed order, always within caps:
   - tiles toward preferred;
   - quick controls toward preferred;
   - category and utility toward preferred;
   - gaps up to twice the floor;
   - the remainder to tile height.
7. Build frames top-down. Mirror horizontally when right-to-left.
8. `minimumWindow` is a staircase search over column counts. For each candidate it computes the width needed and the height needed, and returns the smallest-area pair that also passes the typing line. Property tests: a window at or above the minimum fits; one point less in either dimension, with the other at the minimum, does not.

### 5.3 Keyboard

- Put `.ignoresSafeArea(.keyboard)` on the root so the insets the `GeometryReader` reports do not change when the keyboard appears. This is the standard behaviour, but I could not confirm it from the documentation page I fetched. The capture test confirms it.
- Heights per OS release: I found no authoritative figures. Measure, and re-measure each OS.
- Provisional fractions for a placeholder only (my recollection, unverified): phone portrait 0.42, iPad portrait 0.35, iPad landscape 0.52 of screen height.
- Measurement: in probe mode the app reports `UIResponder.keyboardFrameEndUserInfoKey`. A UI test fails if the measured height exceeds the table for the running OS, so a new OS forces a table update.

### 5.4 Labels: `WordFit` (pure, with an injected measure)

```swift
nonisolated struct WordFit {
    struct Candidate: Equatable { var size: DynamicTypeSize; var showsIcon: Bool }
    enum Outcome: Equatable { case fits(Candidate); case doesNotFit(bestEffort: Candidate) }
    static func choose(wanted: DynamicTypeSize, hasIcon: Bool, slot: CGSize,
                       maxLines: Int, measure: (Candidate) -> Measurement) -> Outcome
}
```

- Candidate order: `(wanted, icon)`, `(wanted, no icon)`, then one size at a time down to `min(wanted, .large)`, no icon. Never lower.
- `Measurement` carries the longest word's width, line count and line height at that size, from UIKit, including Bold Text.
- When nothing fits at the default size, the outcome is `doesNotFit`. The label renders at that size and the plan records a diagnostic. A test requires zero diagnostics for the starter library on every device class. For a family's own long word, the future editor warns.
- `FittedLabel` renders with `.dynamicTypeSize(outcome.size)`, `lineLimit(1)` for single words, and no `minimumScaleFactor`.
- I rejected `ViewThatFits` as the decision-maker. It tests ideal size, and for a wrapping `Text` that is the whole line on one line. It cannot see a single too-wide word, and a word wider than the proposal may simply wrap to a taller `Text`. This is my reasoning, not run. `PORTING.md` lists the reference's `WordFit` as portable. If it can be read, port it against these tests. If not, implement this spec.

### 5.5 SwiftUI consumption

```swift
HomeLayoutReader { plan in          // GeometryReader + screen reader + profile store → LayoutInput → plan
    SlotLayout(plan: plan) {
        MessageText().layoutSlot(.messageText)
        TypeButton().layoutSlot(.type)
        /* … every slot … */
        ForEach(tiles) { PhraseTileButton($0).layoutSlot(.tile(row:column:)) }
    }
}
.ignoresSafeArea(.keyboard)
```

- Every control stays a standard `Button` with a label.
- The slot size is passed explicitly from the plan to `FittedLabel`.
- Grown libraries: the grid sits in a `ScrollView` with a nested `SlotLayout` sized to the plan's content height.
- `SlotLayout` is `nonisolated`, holds only value types, and calls the pure `SlotPlacement`.

## 6. Feasibility sketches (hand arithmetic, not run)

Assumptions: A is 100 pt on phones and 102 pt on iPad gaze; safe areas from memory, to be replaced by capture; no E band; B is 2 rows on phones and 1 row on iPad; C is 2 rows on phones and 1 row on iPad; spacing as in section 3.2.

### 6.1 Phones, touch and switch floors, default text

Needed height is `top + A + B + C + D + 3 gaps + bottom`.

| Phone | Needed | Available | Spare | Typing above keyboard (K provisional 0.42 H) |
|---|---|---|---|---|
| SE 2/3, 375×667 | 694 | 667 | **−27** | **−50** |
| SE zoomed, 320×568 | 616 | 568 | **−48** | worse |
| 12/13 mini, 375×812 | 765 | 812 | +47 | 0 |
| 11, 414×896 | 756 | 896 | +140 | +55 |
| 12/13/14/16e, 390×844 | 725 | 844 | +119 | +41 |
| 15/16, 393×852 | 737 | 852 | +115 | +33 |
| 17, 402×874 | 740 | 874 | +134 | +43 |

Text-size effect: only A grows. From my memory of Apple's type scale (the real values come from `TextMetrics`), A grows by roughly 15 pt at xxxLarge, 30 at AX1, 67 at AX3 and 107 at AX5.

- Browse stays inside through AX3 on most phones, and through AX5 on the biggest. It fails on the mini from AX4.
- Typing above the keyboard goes negative from about AX3 on every phone.
- This is the AX5-on-iPhone risk (section 10) and needs an owner decision (section 9, item 7).

### 6.2 iPads, gaze, default text, two readings of the floor

| Window | Floors 111/90/74 (reference) | Floors 164/135/111 (4 degrees) |
|---|---|---|
| Pro 13 and Air 13, portrait | fits | fits |
| Pro 13 and Air 13, landscape | fits | fits, spare 14 and 6 |
| Pro 11, Air 11, A16, portrait | fits | fits |
| Pro 11, Air 11, A16, landscape | fits, spare 94 and 80 | **does not fit** (1 row, capacity 4 < 8), typing line −48 |
| iPad 9th gen, landscape | fits, spare 70 | does not fit |
| mini, portrait | fits, spare 214 | does not fit (capacity 6 < 8) |
| mini, landscape | **does not fit** (capacity 4) | does not fit |

## 7. Test plan

### 7.1 Unit matrix (`BricksonTests/Layout/`)

Axes (all data in `LayoutMatrix.swift`):

- Devices: the rows in section 6, plus zoomed variants.
  - Known: SE zoomed 320×568 (from memory), the 6.1 inch iPhone family zoomed 320×693 (a source measured on iOS 15).
  - Others are marked "to measure".
  - iPhone landscape windows are engine-only rows with expected verdicts, since the app is portrait only. They exist because iOS 27 may deliver resized iPhone scenes.
- Windows: Full Screen, Split View thirds and halves, Slide Over, Windowed or Stage Manager sizes. Slide Over returned in iPadOS 26.1 as single-window, and its sizes are to measure.
- Text: `.large`, `.xxxLarge`, `.accessibility1`, `.accessibility3`, `.accessibility5`.
- Libraries: empty; one category and one phrase; starter (4 shown, largest 8); grown (8 categories, largest 20); large (20 categories, largest 60).
- Profiles: all five.

Assertions, each with its failure condition:

1. Frames sit inside the content rect and enabled frames do not overlap. Fails if an arrangement overflows or aliases are mishandled.
2. Floors are respected per role. Fails if the conversion or distribution shrinks a target.
3. No control intersects an exclusion zone. Fails if `bottomReserve` or corner logic regresses.
4. Safety, Speak and Phrases frames end above the keyboard line. Fails if A, B or C grows without the line check.
5. Shape (columns, rows, slot ids) is identical across profiles, text sizes and libraries on one window. Fails if any of those feeds columns.
6. Relative order of slot centres is identical across profiles. Fails if topology depends on profile.
7. Region heights do not depend on library shape. Fails if B or C height follows category count.
8. Starter library fits where offered, with no `scrollsAtFloor`. Fails when the offered table, floors or shape policy drift.
9. Verdict reasons: `windowTooSmall` versus `profileDoesNotFitDevice` correct for the full-screen size.
10. `minimumWindow` property tests.
11. RTL plan is the mirror of the LTR plan.
12. Every starter label fits its slot at default size on every device class.

### 7.2 Dwell-chain engine (`BricksonTests/Support/DwellChain/`; one engine, not scripts)

```swift
enum PointerModel { case staysOnActivated, returnsToGaze,        // pointer profiles
                    scanRestartsAtFirst, scanResumesAtSelected, scanContinues } // switch; all unverified
enum NearestMetric { case toFrameEdge, toFrameCenter }          // Snap to Item's metric is unverified
```

- **Surface state** includes: shown category (or Emergency), typing, draft non-empty, last spoken, alarm playing, edit mode.
- **Reachable states** by breadth-first search over activations to depth 4. Both orders of every mode change are therefore covered.
- **Starts**: control centres, control-edge samples, **message text, footer, hidden and reserved cells, empty grid cells, window corners and the bottom centre**.
- **Controls**: disabled and hidden controls are treated as absent.
- **Chains**: resting activations to depth 3. The pointer either stays where it was or returns to the starting gaze point.
- **Findings**:
  - Any hazard on step 1 or later (other than the deliberately activated control).
  - A non-idempotent hazard repeating in place.
  - A rest point whose nearest control is harmful.
  - For `speaks` repeating in place, a severity "pending device check".
- The recorded exceptions (section 4.5) are asserted as an **exact** known set, in the strict style the repo uses for `withKnownIssue`. A new trap fails, and a removed one also fails.
- Until step 5 lands a production reducer, the transitions are a test-local table. Then they switch to the real resolver, with a parity test.

### 7.3 Running-app captures (`BricksonUITests/`)

What in-process rendering cannot see:

- Real frames of buttons against the plan's frames (±1 pt).
- No scroll views at Home for the starter library on iPhone 17 and iPad Pro 13.
- The last tile hittable without scrolling.
- Frames unchanged before and after the keyboard appears (full software keyboard; hardware-keyboard bar noted separately).
- Keyboard height against the table.
- Measured safe-area and corner insets per windowing mode.
- `nativeScale` under a zoomed simulator.
- The accessibility audit's clipped-text check at default and AX5.
- Element order across profiles and states (no probe present).

**The probe.** A launch argument `-BricksonLayoutProbe YES` adds one invisible accessibility element with the plan's JSON, only when set.

- It adds nothing in audited, ordered or measured runs.
- `LayoutProbeTests.isOffByDefault` pins that.
- The audit test and the order test assert the probe element does not exist.

**Profile hook.** The profile is read from `UserDefaults`, so a UI test passes it as a launch argument for the profile key. No test-only code path.

### 7.4 What each result records

`MeasurementRecord` (Codable) lists:

- evidence kind (unit fixture, simulator, device);
- device or simulator name, OS, Xcode;
- orientation, window size, safe area and corner insets;
- text size, appearance, multitasking mode, display zoom;
- keyboard (full software, hardware bar, none);
- profile and library;
- commit SHA from a clean checkout, and a human-readable date.

Unit failures include the configuration string. UI captures attach the record. Unit fixtures use committed measured inputs from `BricksonTests/Resources/MeasuredWindows.json`, regenerated by an opt-in capture test. Unmeasured combinations fall back to conservative assumed insets, and their label says "assumed".

### 7.5 The first tests, in write order

| # | Test | Fails if |
|---|---|---|
| 1 | `PhysicalUnitsTests.visualAngleUsesHalfTheAngle` (2.0 degrees at 500 mm is 17.46 mm) | the formula uses tan(θ) or mixes radians and degrees |
| 2 | `ProfileSpecTests.gazeFloorsReproduceTheReferenceNumbersOnA132PtPerInchIPad` (≥ 110/88/72 and within 4 pt) | a distance or angle is edited, or pt/mm is computed wrongly |
| 3 | `PixelDensityTableTests.everyRowMatchesItsPublishedDiagonal` | a pixel size or ppi is mistyped |
| 4 | `DeviceMetricsTests.displayZoomLowersPointsPerMillimetre` | `scale` is used instead of `nativeScale` |
| 5 | `DeviceMetricsTests.unknownDevicesGetTheLargestDensityOfTheirIdiom` | a default smaller than a table row could shrink floors physically |
| 6 | `ProfileSpecTests.switchSizesEqualTouchSizes` and `profilesAreOrderedByDemand` | a profile's floors drift |
| 7 | `SlotMapTests.aSlotKeepsItsHazardClassInEveryState` | Speak is aliased to a harmless slot or Phrases to a harmful one |
| 8 | `SlotMapTests.slotPositionsArePinned` | any slot moves |
| 9 | `HomeLayoutEngineTests.theEngineHasNoScreenStateInput` | someone adds a typing flag |
| 10 | `HomeLayoutEngineTests.shapeIgnoresProfileTextSizeAndLibrary` | columns depend on any of them |
| 11 | `HomeLayoutEngineTests.minimumWindowFitsAndOnePointLessDoesNot` | off-by-one or non-monotone steps |
| 12 | `WordFitTests.emergencyKeepsItsWordWholeInItsPhoneSlotAtDefaultSize` | the label order, or the slot width, regresses |

## 8. Sequencing: replacing the stand-in without a big bang

Every commit keeps the unit suite green. One task per commit. New code is unused until commit 11.

| # | Commit | Notes |
|---|---|---|
| 0 | docs: DECISIONS "Layout engine and input profiles (proposed)", HANDOFF | marks the owner decisions pending |
| 1 | `PhysicalUnits` and tests | |
| 2 | `DeviceMetrics`, density table, `DeviceClass` and tests | |
| 3 | `InputProfile`, `ProfileSpec`, `ProfileAvailability` and tests | |
| 4 | `Slot`, `HomeSlotMap` (hazards, aliases, scan order) and tests | |
| 5 | `LayoutInput`, `TextMetrics`, provisional `KeyboardHeightTable`, `WindowClass` and tests | |
| 6 | `HomeLayoutEngine.plan`, verdicts, `minimumWindow`, engine invariants on iPad Pro 13 and iPhone 17 | |
| 7 | Full `LayoutMatrix`, matrix tests, printed feasibility table | the owner's decision point. Failures become table changes or recorded exceptions. |
| 8 | `WordFit`, `LabelMeasurer`, tests | |
| 9 | Chain engine, test-local surface model, chain tests | |
| 10 | `SlotLayout`, `HomeLayoutReader`, `InputProfileStore`, `LayoutProbe`, off-main and probe-off tests | |
| 11 | `HomeV1` behind `-BricksonHomeV1 YES` (default off), leaf views extracted, capture tests, iPhone UI job, `scripts/test.sh` iPhone option | |
| 12 | **The swap**: `HomeView` is rewritten on the engine, the flag and the old containers are deleted, DECISIONS "Home version 1", HANDOFF, PORTING | `LaunchTests` keep their names (Yes, No, Emergency, Again, Hello.) |
| 13 | Typing (step 5b): draft, Speak, Phrases, keyboard table filled by measurement, D27 tests | |
| 14 | Profile chooser in Settings (step 7) | |

- **What stays**: `CategorySelection`, `Palette`, `MessageRow`'s speech-bound text and its two-line scroll, `StatusArea`'s warnings and announcements, `MessageActionButtonStyle`.
- **What goes**: the `VStack`, both `ScrollView`s on the starter path, `horizontalSizeClass` columns, and every literal 64/88/96/52.
- **CI**: add the iPhone run as a **new job** (for example "UI tests (iPhone)"). Do not use `strategy.matrix` on the existing job: it would rename the required "UI tests" check.
- **Docs**: update DECISIONS (the "Home version 0 is a stand-in" entry becomes "Home version 1" at the swap), HANDOFF, PORTING, README.

## 9. Decisions for the owner (with recommendations)

1. **Gaze floor**: AGENTS.md numbers as the floor and 4 degrees as preferred (recommended), or 4 degrees as the floor. Section 6.2 is the consequence.
2. **Viewing distances**: touch 350 mm, head 500, gaze 450 (Apple says about a foot and a half for Eye Tracking).
3. **SE-class phones**: switch not offered, with compact floors never below 44 pt (recommended); or touch with a scrolling grid and a named typing exception.
4. **Gaze and head not offered on phones.** Numbers in section 3.3.
5. **Phone landscape**: stay portrait only. The engine still returns a verdict for resized scenes.
6. **Profile choice**: stored per device in `UserDefaults`, chosen by the person or caregiver in Settings only. It is a position-changing setting, so never on Home. Default is the strictest offered profile. `UIAccessibility.isSwitchControlRunning` and `isAssistiveTouchRunning` may only suggest in setup. I found no public flag for Eye Tracking, Dwell or head tracking.
7. **Text sizes on phones**: pin A and C, let D scroll at accessibility sizes (a named exception), or cap the message block to one line at accessibility sizes.
8. **Stop Alert** in B's pinned trailing cell above Emergency: accept, or choose another harmless place.
9. **Record the named exceptions** in section 4.5.
10. **Calibration**: confirm the reference app's iPad was a 264 ppi model.

## 10. Risks and unknowns (what I could not verify)

- **Snap to Item.** I found no source for its distance metric, its range or whether it skips disabled controls. The chain engine scores edge and centre, and treats disabled controls as absent.
- **Pointer-return model.** Both models are scored. Whether a lingering look re-fires a dwell is a device check.
- **Switch scan after a select.** Restart, resume or continue: unverified, scored as three models.
- **Keyboard heights.** No authoritative figures found. Measure per OS (26.5 on CI, 27 on the owner's Mac) and use the larger. Floating and split keyboards are an exception. Stage Manager may or may not shift a window for the keyboard.
- **Liquid Glass chrome and window controls.** SwiftUI's `containerCornerOffset(_:sizeToFit:)` is iOS 26 and confirmed. UIKit's `UIView.LayoutRegion.margins(cornerAdaptation:)` and `layoutGuide(for:)` exist, but the `cornerAdaptation` options (`.horizontal`, `.vertical`) came from a forum post and are **not** confirmed. Look them up before use. I found no point sizes for the controls.
- **Hot corners.** Apple's iPad page says hot corners run a chosen action when the cursor rests in a corner, with a different action per corner. I found no trigger size. The default top-left Eye Tracking recalibration comes from AGENTS.md.
- **Window sizing.** TN3192 says `sizeRestrictions.minimumSize` is best effort, rotation is not prevented, and iOS 27 resizes scenes on both platforms (discrete resizing). A forum report says it did not take effect on iPadOS 26. SwiftUI offers `windowResizability(.contentMinSize)`.
- **iOS 27 iPhone.** The WWDC26 summary says iPhone apps are resizable in iPhone Mirroring and when hosted on iPad. Physical size is meaningless there.
- **Display Zoom.** Only the 6.1 inch iPhone zoomed size is sourced. No iPad zoom data found.
- **iPadOS 26 windowing.** Split View and Slide Over were removed in the 26 betas, and Slide Over returned in 26.1. Treat those matrix rows as data that may be inert.
- **Dynamic Type sizes.** The AX growth figures in 6.1 are from memory.
- **`Layout` isolation** under Swift 6 default main-actor isolation: declare `nonisolated`, and test the pure part off-main.
- **Grown libraries.** Past capacity, only D (or B) scrolls at the floor. Whether Snap to Item skips off-screen controls is unverified (HANDOFF device check).
- **Labels.** XCUITest cannot see an in-word break (section 0.3).
- **Calibration device** and **the simulator observations**: not reproducible by me.

Additions for HANDOFF "Checks that need a real device":

- whether Snap to Item snaps to window controls;
- its distance metric;
- what a resting dwell does on a focused text field;
- Switch Control scan behaviour after a select, and whether it follows regions and sort priority;
- hot-corner trigger size;
- keyboard heights and floating behaviour;
- Stage Manager keyboard shifting;
- Display Zoom sizes.

## 11. Files

Existing, to change or consult:

- `Brickson/Home/HomeView.swift` (rewritten at commit 12)
- `Brickson/Home/CategorySelection.swift` (kept)
- `Brickson/Home/Palette.swift` (kept)
- `Brickson/Speech/AudioSafetyPolicy.swift` (its copy fixes the control names)
- `BricksonTests/OffMainThreadCallbackTests.swift` (extended)
- `BricksonUITests/LaunchTests.swift`
- `scripts/test.sh`
- `.github/workflows/tests.yml`
- `docs/DECISIONS.md`, `docs/HANDOFF.md`, `docs/PORTING.md`, `README.md` under the same root

New app files in `Brickson/Layout/`: `PhysicalUnits.swift`, `DeviceMetrics.swift`, `InputProfile.swift`, `ProfileAvailability.swift`, `Slot.swift`, `LayoutInput.swift`, `TextMetrics.swift`, `KeyboardHeightTable.swift`, `WindowClass.swift`, `LayoutPlan.swift`, `HomeLayoutEngine.swift`, `DwellRules.swift`, `WordFit.swift`, `LabelMeasurer.swift`, `FittedLabel.swift`, `SlotLayout.swift`, `HomeLayoutReader.swift`, `InputProfileStore.swift`, `LayoutProbe.swift`. Leaf views go in `.../Brickson/Home/Parts/`.

New test files:

- `.../BricksonTests/Layout/` has one `…Tests.swift` per engine file.
- `.../BricksonTests/Support/LayoutMatrix.swift`.
- `.../BricksonTests/Support/MeasurementRecord.swift`.
- `.../BricksonTests/Support/DwellChain/` holds the chain engine and surface model.
- `.../BricksonTests/Resources/MeasuredWindows.json`.
- `.../BricksonUITests/LayoutCaptureTests.swift`.
- `.../BricksonUITests/KeyboardCaptureTests.swift`.

Sources:

- Device sizes: [useyourloaf iPhone screen sizes](https://www.useyourloaf.com/blog/iphone-17-screen-sizes/), [ios-resolution.com](https://www.ios-resolution.com/)
- Display Zoom data: [zenn.dev table](https://zenn.dev/fsh/articles/0bf22b800d1552)
- Window sizing: [Apple TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key.md), [UIWindowScene sizeRestrictions thread](https://developer.apple.com/forums/thread/812523)
- Window controls: [Adopting the New Window Controls](https://juniperphoton.substack.com/p/adopting-the-new-window-controls), [window controls overlap thread](https://developer.apple.com/forums/thread/789303), [`containerCornerOffset`](https://sosumi.ai/documentation/swiftui/view/containercorneroffset(_:sizetofit:)), [`UIView.LayoutRegion`](https://sosumi.ai/documentation/uikit/uiview/layoutregion), [`UIWindowScene.Geometry`](https://sosumi.ai/documentation/uikit/uiwindowscene/geometry)
- Windowing modes: [Windowed Apps end Split View and Slide Over](https://appleosophy.com/2025/06/11/ipados-26s-windowed-apps-mark-the-end-of-split-view-and-slide-over/)
- WWDC26 session 278: [wwdcindex](https://nonstrict.eu/wwdcindex/wwdc2026/278/)
- SwiftUI and UIKit: [`Layout`](https://sosumi.ai/documentation/swiftui/layout), [`DynamicTypeSize`](https://sosumi.ai/documentation/swiftui/dynamictypesize), [`UIAccessibility`](https://sosumi.ai/documentation/uikit/uiaccessibility)
- Eye Tracking and Dwell: [SlashGear](https://www.slashgear.com/1604020/how-to-enable-eye-tracking-ios18-iphone-ipad), [AbilityNet Eye Tracking](https://mcmw.abilitynet.org.uk/how-to-control-your-device-using-eye-tracking-in-ios-18-on-your-iphone-or-ipad), [Apple AssistiveTouch on iPad](https://support.apple.com/bn-in/guide/ipad/ipad9a2466d3/13.0)
- BCI: [Apple BCI HID reference](https://developer.apple.com/documentation/accessibility/brain-computer-interface-hid-reference-for-connecting-to-apple-platforms.md)
- Gaze target size: [Meta eye-gaze best practices](https://developers.meta.com/horizon/design/eyes-best-practices/)
