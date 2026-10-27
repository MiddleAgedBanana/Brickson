# Website review, accessibility page update, and largest-text layout fixes

*2026-10-27. Pull request (`codex/website-review`). The website review
thread, on a Mac with Xcode 27.1 (27A9275) and an iPhone 17 simulator on
iOS 27.0.*

## What changed and why

Compared the GitHub Pages site (`site/index.html`,
`site/accessibility/index.html` and `site/privacy/index.html`) against
`docs/HANDOFF.md`, `docs/ROADMAP.md`, `docs/ACCESSIBILITY.md` and
`docs/DECISIONS.md`, fixed stale wording and navigation links, checked
every link (internal, fragment, `mailto:` and external), fixed horizontal
overflows at large and largest accessibility text sizes (`200%` and
`310%` / `AX5`), and checked all three pages with VoiceOver in Safari and
in WebKit across light and dark appearances.

- **Navigation and links (`site/index.html`, `site/accessibility/index.html`, `site/privacy/index.html`):**
  - Added `<a href="../#our-story">Why Brickson?</a>` to the header's
    `Main navigation` on the accessibility and privacy pages so all three
    pages offer the same five header links (`Our approach`,
    `Accessibility`, `Why Brickson?`, `Support` and `Privacy`).
  - Added `aria-current="page"` to the `brickson` home link in
    `site/index.html`'s header so VoiceOver reports the current page on
    Home just as it does on Accessibility and Privacy.
  - Wrapped the two plain-text `ajdedmon12@gmail.com` occurrences in
    `site/privacy/index.html` (`Who we are` and `If you contact us`) in
    `<a href="mailto:ajdedmon12@gmail.com">ajdedmon12@gmail.com</a>` to
    match the `Contact` section (`PrivacyPolicyDocument` strips anchor tags
    while keeping their text, so the in-app copy is unchanged).
  - Added `<meta name="text-scale" content="scale">` to all three pages so
    browsers that support OS-level text scaling follow the user's text-size
    preference automatically.
- **Current state on `site/index.html` and `site/accessibility/index.html`:**
  - On `site/index.html`, updated `"made only of Apple's standard buttons"`
    to `"made only of Apple's standard controls"` since Home now includes
    Apple's standard text field for typing alongside standard buttons.
  - On `site/accessibility/index.html` (`Last updated October 27, 2026`),
    updated the summary, *How Brickson is built*, *Touch*, *VoiceOver*,
    *Switch Control and Full Keyboard Access*, *AssistiveTouch with Dwell
    Control, Head Tracking and Eye Tracking*, *Larger Text and Bold Text*
    and *Known limits today* to match `main`:
    - The October 25, 2026 informal handheld look with Eye Tracking on an
      iPhone 17 Pro Max (iOS 27.0.1) while `Type` was chosen (no gaze
      outline on white dimmed phrase and category buttons; outlines on
      coloured buttons and keyboard keys), while stating plainly that no
      controlled check has been done on a real iPhone or iPad yet.
    - Standard controls (buttons and the typing text field), `SettingsAppLink`
      hiding the `Open … Settings` buttons while Assistive Access is on, and
      Apple's accessibility audit running on each Family Setup guide, each
      step of Set Up Step by Step and About in light.
    - Touch slow presses (`0.5s` and `1.5s`), a touch starting on `Yes` and
      sliding onto `No`, and vertical drag cancellation across the phrase
      area (`SlowPressTests`, `PhraseDragTests`).
    - VoiceOver announcements when the typed message cannot be saved or
      restored or when a keystroke is refused because the message is full
      (`DraftStore.refusals`, `HomeStatusLine`).
    - Typing's scan order (`Speak` in `Again`'s place; `Clear` and `Put Back`
      in two category places).
    - Compact vs. regular width neighbours above `Stop`'s place (`Again`, or
      `Speak` while typing, on an iPhone; `Emergency` on an iPad), the top
      band of dimmed top-row phrase buttons bordering `Clear` or `Put Back`
      by nearest centre, `Back to Talking` over `Phrases`, and Settings'
      `Family Setup` / `Set Up Step by Step` row placement and open chains
      (`SettingsRowPlace`, `SettingsOnHomeTests`).
    - `MessageFit` scaling the message with Dynamic Type without breaking its
      widest word, and Settings' gear showing the Large Content Viewer at
      the largest text sizes while Home's other buttons keep it off so a
      slow press still speaks.
    - The October 25, 2026 simulator scroll measurements (13-inch iPad in
      portrait and landscape with Standard and Larger Text Display Zoom;
      iPhone 17 at Standard and Larger Text Display Zoom; 375×667 iPhone SE
      model), keyboard probe measurements (`375×667` and zoomed `320×568`
      iPhone SE, and `Put Back` behind the phone's `AX5` keyboard on
      iPhone 17), and iPhone Duo simulator reserved-region measurements.
- **Largest-text layout fixes (`site/style.css`):**
  - Removed `overflow-wrap: normal` from `h1, h2, h3` so headings inherit
    `overflow-wrap: break-word` from `body` and wrap words wider than narrow
    columns at `200%` and `310%` (`AX5`) text sizes instead of overflowing
    horizontally.
  - Changed `.wrap`'s horizontal margin from `min(8vw, 8rem)` (and `4rem` at
    narrow widths) to `min(8vw, 128px)` (and `64px`), keeping the exact same
    margin at the default 16px root font size while preventing horizontal
    margins from growing to nearly 400px at `310%` text size.
  - Updated `.skip`, `.site-name`, `.button`, `.principles` and `.help-grid`
    so narrow viewports (`320px` and `390px`) and flex/grid containers wrap
    cleanly without horizontal scrolling at `200%` and `310%` text sizes, and
    converted the `@media` breakpoints to `rem` (`65.625rem` and `45rem`).
- **Docs (`docs/ACCESSIBILITY.md`, `docs/DECISIONS.md`, `docs/HANDOFF.md`):**
  - Updated the `Accessibility URL` row in `docs/ACCESSIBILITY.md`, noted in
    `docs/DECISIONS.md` that typing's kept message landed on 2026-10-24, and
    updated `docs/HANDOFF.md` in place.

## Commits

- The commit on `codex/website-review`: website review, accessibility page
  update, largest-text CSS fixes, and documentation updates.

## Verified

- `python3 scripts/test-site.py` (7 tests), `python3 scripts/test-docs.py`
  (45 tests), `python3 scripts/test-hooks.py` (124 tests),
  `python3 scripts/test-runner.py` (54 tests) and
  `python3 scripts/test-select-xcode.py` all passed.
- Every internal link, fragment target (`#id`) and `mailto:` link across
  `site/index.html`, `site/accessibility/index.html` and
  `site/privacy/index.html` resolved; all three external links in
  `site/privacy/index.html` (`https://support.apple.com/en-us/104993`,
  `https://www.apple.com/legal/privacy/` and
  `https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement`)
  returned HTTP 200.
- Rendered all three pages in WebKit (`WKWebView` on macOS,
  `build/website-review/webkit/webkit-layout-receipt.json`) across 4
  viewport widths (`1280`, `1000`, `390` and `320` points) × 4 text/zoom
  scales (`100%`, `200%` text, `310%` / `AX5` text and `200%` page zoom) ×
  2 appearances (`light` and `dark`) = 96 checks. Before the `site/style.css`
  fixes, 26 of the 96 checks failed with horizontal overflow at `200%` and
  `310%` text sizes; after the fixes, all 96 checks passed with zero
  horizontal overflows (`scrollWidth <= clientWidth`), every visible link at
  least 44 points tall, and 18 PNG snapshots saved under
  `build/website-review/webkit/`.
- Opened all three pages in MobileSafari (`com.apple.mobilesafari`) on the
  iPhone 17 simulator (iOS 27.0, Xcode 27.1 `27A9275`) at the default and
  `AX5` text sizes with `XCUIDevice.shared.voiceOverService` enabled,
  capturing the full WebKit accessibility element trees, link frames,
  VoiceOver spoken utterances (`moveForward()` / `currentSpeech()`) and
  screenshots in `build/website-review/safari-voiceover/` and
  `build/website-review/safari-voiceover-complete/`. Every heading level
  (`h1` -> `h2` -> `h3`), landmark (`banner`, `Main navigation`,
  `Page sections` / `Policy sections`, `main`, `content information`), list
  item and link label was exposed in order with `Horizontal scroll bar, 1 page`.
- Ran Lighthouse mobile accessibility, best-practices, SEO and
  agentic-browsing audits and captured full accessibility-tree snapshots on
  all three pages via Chrome DevTools MCP
  (`build/website-review/a11y-trees/`): 100/100 across all four categories
  on every page, with zero console errors or accessibility issues.
- Ran `scripts/test.sh unit` on the Mac (Xcode 27.1 `27A9275`, iPad Pro
  13-inch (M5) simulator, iOS 27.0), including `PrivacyPolicyDocumentTests`
  against the updated `site/privacy/index.html`.

## Not verified

- The live GitHub Pages site (`https://middleagedbanana.github.io/Brickson/`):
  updates publish after the pull request merges to `main`.
- VoiceOver in Safari on a physical iPhone or iPad.

## Follow-ups

- Update `site/accessibility/index.html` and its `Last updated` date as each
  physical-device check in `docs/HANDOFF.md` (*Checks that need a real
  device*) is completed. *(whoever records the device check)*
