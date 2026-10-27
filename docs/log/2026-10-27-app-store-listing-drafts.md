# App Store listing drafts, metadata limits and App Review notes

*2026-10-27. Pull request #62 (`codex/app-store-listing-drafts`). Agent.*

## What changed and why

Updated store-text drafts and App Store guidance across `docs/ASO.md`,
`docs/APP-STORE.md` and `docs/HANDOFF.md` to use `[App Name]` as a placeholder
until the final name is confirmed in App Store Connect, with no price or cost
words (docs/DECISIONS.md, "App Store category" and "Waiting on the owner"):

- **`docs/ASO.md`**:
  - Replaced hardcoded occurrences of the working name inside the store-text
    drafts (`Name`, `Promotional text`, `Description`, `What's New`,
    `Screenshots`, `Other English-speaking stores`, `Ratings` and
    `If the name is taken`) with `[App Name]`.
  - Moved "at every stage" inside the `[needs: profiles]` tag in the master
    description so removing unbuilt tags leaves an accurate statement for 1.0.
  - Specified "any supported voice for your language on your device" across the
    description and release summary blocks, reflecting that `VoiceList.rows`
    filters novelty voices and other languages.
  - Required updating `APP_DISPLAY_NAME` in `project.yml` to the confirmed App
    Store name before archiving the final release build.
  - Verified exact character and byte counts in Python against Apple's App
    Store Connect and App Store Review Guidelines limits:
    - **Name (limit 30 characters):** `[App Name]: AAC for ALS` (23 characters
      with `[App Name]`, 21 characters with an 8-character brand name) for US
      and Canada; `[App Name]: AAC for MND` for UK, Ireland, Australia and New
      Zealand.
    - **Subtitle (limit 30 characters):** `Phrases and text to speech` (26
      characters) for 1.0; `Text to speech at every stage` (29 characters) once
      stage profiles ship in R1.
    - **Keywords (limit 100 bytes):**
      `communication,nonverbal,speak,talk,voice,eye,gaze,switch,assistive,augmentative,board,mnd,type`
      (94 ASCII bytes for US and Canada; 96 bytes once `phrase` moves from the
      1.0 subtitle into keywords in R1; 99 ASCII bytes for UK and Australia).
    - **Promotional text (limit 170 characters):** 163 characters with
      `[App Name]` (161 characters with an 8-character brand name).
    - **Description (limit 4,000 characters):** master draft is 2,449
      characters with tags (2,298 characters when stripped); clean 1.0
      paste-ready block is 1,816 characters with the four unbuilt/unverified
      items omitted so every statement is true of the build today (Guideline
      2.3.1(a)).
    - **What's New (limit 4,000 characters):** first update entry is 382
      characters with tags (326 characters without tags, Guideline 2.3.12);
      first-release summary is 504 characters for TestFlight *What to Test* or
      launch notes.
  - Updated the `Screenshots` table's `Waits for` column for captures whose
    screens are now built on `main` (`Home`, `Typing` and `Voice Settings`).
- **`docs/APP-STORE.md`**:
  - Updated sections 2, 4, 8 and 13 to reflect that `Settings > Family Setup >
    Privacy Policy` (Guideline 5.1.1(i)), Home on the layout engine, whole-word
    fitting, Get Attention and Stop, Typing, and Voice Settings are now built on
    `main`.
  - Updated section 8's App Review notes template on Personal Voice to describe
    the actual first-launch prompt behavior (`AppAudio.personalVoiceAskPolicy(for: nil)`
    asks at launch).
- **`docs/HANDOFF.md`**: recorded the update under *Verification*, distinguishing
  the three unbuilt features from the real-device verification gate.

## Commits

- Commit on `codex/app-store-listing-drafts`: store text drafts, ASO metadata
  reconciliation, App Review notes template, and documentation updates.

## Verified

- Checked Apple's [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
  [Creating Your Product Page](https://developer.apple.com/app-store/product-page/),
  [App Store Search](https://developer.apple.com/app-store/search/),
  [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
  and `CFBundleDisplayName` (`https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname.md`),
  plus independent ASO metadata guides.
- Computed exact character and byte counts using Python against Apple's field
  limits.
- Ran `python3 scripts/test-docs.py` (45 tests) and `python3 scripts/test-site.py`
  (7 tests): all passed.

## Not verified

- Submitting or saving metadata in App Store Connect (requires an active App
  Store Connect record and confirmed developer account).

## Follow-ups

- Confirm the final app name and permanent bundle ID before creating the App
  Store Connect record (`docs/DECISIONS.md`, *Waiting on the owner*).
- Remove the remaining `[needs: …]` tags from the master description as phrase
  editing, backup export/import, real-device input checks and R1 stage profiles
  land.
