# My own verified findings (2026-10-15, owner's Mac, Xcode 27.0, iOS 27.0 simulators)

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Measured on: "Brickson Recon iPad" = iPad Pro 13-inch (M5, 16GB) simulator, portrait;
"Brickson Recon iPhone" = iPhone 17 simulator, portrait. Light unless stated. No keyboard
(the app has no typing yet). Simulator only: nothing here is evidence about sound, gaze,
dwell or Snap to Item.

## Build and tests
- Unit suite: all 13 suites green on the recon iPad (`DESTINATION=id=... scripts/test.sh unit`).
- `xcodebuild` leaves `Brickson/Resources/Localizable.xcstrings` at 0 strings; only an Xcode IDE
  build fills a String Catalog. English works because keys fall back to themselves.
- `scripts/test.sh` could not pick a simulator on this Mac: the only iOS simulator was named
  "Brickson Website Checks" and the script filtered on names starting with "iPad". Fixed to
  filter on `deviceTypeIdentifier`; the selector now finds it (verified with the same JSON).
- The iOS 26.5 runtime is not installed here (its devices show as unavailable); CI uses Xcode
  26.6 + iOS 26.5. Local = iOS 27.0 only.
- Cold-booted iPhone simulator: first frame about 50 s after launch (log: scene connected
  19:12:53, launch 19:12:03; `nw_activity ... duration 50371ms`). Two early screenshots were
  blank. Same mechanism as the CI first-UI-test timeouts in HANDOFF.

## Home v0 as rendered
- iPad default: fits with the grid using about half the height; tiles 96pt, quick controls 64pt,
  category chips 52pt. Status area invisible at the bottom. Works.
- iPad AX5 dark: "Emer-gency" hyphenates (design rule "Words never break"); the category row
  scrolls horizontally (Feelings off screen); tiles in one row have different heights.
- iPhone 17 default: "Emer-gency" hyphenates even at the default size; category row scrolls
  (Conversation clipped, Feelings off screen); the phrase grid scrolls for the 8-phrase Basics
  category (Hello./Goodbye. clipped). So the starter library scrolls on an iPhone today.
- iPhone 17 AX5: heading breaks mid-word ("Choos / e a"), "Ag / ain", "May / be."; Yes, No and
  Emergency labels clip to a bar; Needs clipped. Unusable at AX5 on the phone.
- iPad, after tapping "Wait a moment, please.": the spoken text shows, Speaking appears, Again
  turns on. A pixel comparison first suggested every control moved up 3pt in the spoken state;
  the new UI test `testControlsKeepTheirFramesWhenAPhraseSpeaks` (passes, 8.5 s) shows the
  accessibility frames are identical. The pixel shift was my own artefact: I had reset the
  simulator with `simctl ui content_size medium`, and the default Dynamic Type size is Large,
  so the second screenshot was one text step smaller. GOTCHA for AGENTS.md. The iPhone
  "default" screenshot was therefore taken at Medium; its findings hold a fortiori at Large.
- Not covered here: landscape (simctl cannot rotate), intermediate text sizes, Increase
  Contrast, Reduce Transparency, VoiceOver, sound.

## Repository
- App icon in the asset catalog is still the placeholder white bubble on blue; the navy "B"
  mark in design/brand is not installed.
- A leftover codex worktree on the owner's Mac sits on the merged branch
  codex/ui-test-infrastructure (owner's, not touched).
- Simulator log noise: "Device does not support personal voice" (expected in a simulator),
  VoiceDB decoding errors (Apple-side).

## Strategic observations (from reading everything)
- The port order in PORTING.md is organised around the reference app's files, not around the
  person's stages. The roadmap should be stage-led and release-led, and then map each release
  to port steps.
- The two largest gaps for daily reliance on touch are typing and Get Attention; for everyone,
  editing + backup + Settings/voice picker; for later stages, the profile layout engine.
- Nothing has run on a physical device; the dwell design rests on unverified Snap to Item
  premises. A device lane belongs at the front of the plan, not the end.
- The privacy policy already describes recorded phrases, caregiver alerts and Siri; each is a
  decision the owner must make before release 1 (build or delete the section).
- Personal Voice: the single most time-sensitive thing for an early-stage person is to bank
  their voice while speech is clear. The app should say so in onboarding.
