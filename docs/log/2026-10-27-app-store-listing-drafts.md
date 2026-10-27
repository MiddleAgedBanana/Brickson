# App Store listing drafts — 2026-10-27

## What changed

- **`docs/ASO.md`**:
  - Replaced hardcoded occurrences of the working name inside the store-text
    drafts (`Name`, `Promotional text`, `Description`, `What's New`,
    `Screenshots`, `Other English-speaking stores`, `Ratings` and
    `If the name is taken`) with `[App Name]`, and kept all drafts free of any
    price or cost words.
  - Verified character and byte counts against Apple's App Store Connect and
    App Store Review Guidelines limits:
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
    - **Description (limit 4,000 characters):** removed the five `[needs: …]`
      tags for features now built on `main` (`[needs: Get Attention]`,
      `[needs: layout engine]`, `[needs: word fitting]`, `[needs: typing]` and
      `[needs: voice choice in Settings]`), kept the four remaining `[needs: …]`
      tags (`profiles (R1)`, `device checks of each input method`, `editing`
      and `backup`), and added a clean 1,354-character 1.0 paste-ready
      description block with those four unbuilt items omitted so every line is
      true of the build today (Guideline 2.3.1(a)).
    - **What's New (limit 4,000 characters):** added a concrete first update
      entry (355 characters with tags; 300 characters without tags, Guideline
      2.3.12) and a 466-character first-release summary for TestFlight *What to
      Test* or launch notes.
  - Updated the `Screenshots` table's `Waits for` column for captures whose
    screens are now built on `main` (`Home`, `Typing` and `Voice Settings`).
- **`docs/APP-STORE.md`**:
  - Updated sections 2, 4, 8 and 13 to reflect that `Settings > Privacy`
    (Guideline 5.1.1(i)), Home on the layout engine, whole-word fitting, Get
    Attention and Stop, Typing, and the Personal Voice explanation sheet are
    now built on `main`, and updated the section 8 App Review notes template to
    use `[App Name]`.
- **`docs/HANDOFF.md`**: recorded the update under *Verification*.

## How it was checked

- Checked Apple's [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
  [Creating Your Product Page](https://developer.apple.com/app-store/product-page/),
  [App Store Search](https://developer.apple.com/app-store/search/),
  [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
  and `CFBundleDisplayName` (`https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname.md`),
  plus independent ASO metadata guides.
- Ran `python3 scripts/test-docs.py` (45 tests) and `python3 scripts/test-site.py`
  (7 tests): all passed.

## What is left

- Confirm the final app name and permanent bundle ID before creating the App
  Store Connect record (`docs/DECISIONS.md`, *Waiting on the owner*).
- Remove the remaining `[needs: …]` tags from the master description as phrase
  editing, backup export/import, real-device input checks and R1 stage profiles
  land.
