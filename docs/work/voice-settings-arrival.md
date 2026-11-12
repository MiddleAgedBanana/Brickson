# Voice Settings, reached with a held look

*Roadmap: R0's quality bar, Q2 (no dwell hazard on any screen), the
item docs/HANDOFF.md, *Known gaps*, names "Not scored yet": Voice
Settings itself, the Personal Voice question, and Family Setup scrolled.
Owner: the thread "Check held looks on Settings' unchecked screens" (a
cloud session; GitHub CI is its build). Status: built, untested in the
app until CI runs it.*

## Intent

- **Problem:** under AssistiveTouch Dwell, head tracking, Eye Tracking or
  Switch Control's auto-select, the pointer is still where the last
  control was when the next screen appears, and a held look can choose
  whatever is now nearest it. Choosing Voice Settings in Family Setup
  opens a screen whose speed choices sit under that spot: on the frames
  CI drew on `main` (run 43180245909, at `3f92a8b`; the captures
  `family-setup-opened-…` and `Voice Settings`), a look held anywhere on
  the row meets "70% of normal speed" on the iPhone 17 at the default
  text size, by nearest centre and by nearest edge, and on the 13-inch
  iPad in portrait by nearest edge (70% and 80%). A speed choice sets how
  Brickson speaks from then on and plays a sample, so a stray dwell in
  Settings changes the person's voice speed without anyone choosing it
  (AGENTS.md, invariant 10). Lower on the screen, Hear plays a voice and
  Use changes it; where the Personal Voice card offers Open Personal
  Voice Settings, it leaves Brickson for the Settings app.
- **Proposed outcome:** a look held after choosing Voice Settings meets a
  control that only goes back to Family Setup, whatever Family Setup had
  scrolled; going back puts the look on the Voice Settings row again, so
  a repeated activation goes back and forth between two controls that
  only open screens and changes nothing.
- **Who and what it affects:** families, mostly on touch, who see one
  more row on Voice Settings and scroll a little further to the speeds
  on a phone; people on dwell, switch, head or gaze who wander into
  Settings. Family Setup's Voice Settings row, Voice Settings
  (`VoiceSettingsView`), `SettingsLanding`, and the tests that score
  Settings (`SettingsChains`, `SettingsOnHomeTests`). Step 3 of Set Up
  Step by Step shows the same voice content and does not change: a look
  reaches it on Next, in the bar at the foot of every step, which stays
  under the look.
- **Constraints:** invariant 1 (a standard `Button` with a label, a
  Settings row's size); invariant 8 (nothing moves while the screen is
  open; the way back's place follows where the row showed, as the
  Library's questions do); invariant 10 (scored by nearest centre and
  nearest edge, with both pointers, by the one chain engine; fixed by
  placement, never by a timer, a decoy or custom pointer code);
  invariant 11 does not apply (Settings, not Home). Words go through the
  String Catalog.
- **Open questions:** none for the owner. The placement follows "The
  Library's question screens" (docs/DECISIONS.md), a default the owner
  can reverse. Whether places in Settings should follow what showed on
  screen at all is the question PR #103 put to the owner for Set Up Step
  by Step; this follows the Library and Go Through Setup Again, and would
  change with them.

## Spec

- **States:**
  - *Voice Settings, opened from Family Setup's Voice Settings row* (its
    only way in). A way back, "Back to Family Setup", takes the row's
    frame as it showed when chosen: the row's frame in Family Setup's
    content less what Family Setup had scrolled, kept within what shows
    (`LibraryQuestionPlace`, with no words). It is at least as tall as the
    row and as wide. Everything the screen had (the "Speaking with …"
    line, the Personal Voice card, Speed, the seven speeds, Voice and the
    voices) follows as one block, unchanged inside, starting where every
    point of the way back and the gap around the row (half a row gap
    above and below) is nearer the way back than a row at the block's
    top, by centre and by edge, with 8 points to spare. Above the way
    back the screen is empty. Nothing moves while the screen is open.
  - *Family Setup:* the Voice Settings row keeps its place, words and
    look; it becomes a `Button` that records where it showed, as Phrases
    and Categories and the Library's asking rows do, and opens Voice
    Settings.
  - *Step 3 of Set Up Step by Step:* unchanged.
- **Input methods:**
  - Touch, VoiceOver, Voice Control, Full Keyboard Access: one more
    button, "Back to Family Setup", which goes back like the standard
    Back button. On a phone the speeds and voices start lower, so a
    family scrolls more to reach them.
  - Dwell, head tracking, Eye Tracking, Switch Control auto-select: a
    look held after choosing the row meets the way back; that returns to
    Family Setup, which keeps its scroll, so the look meets the Voice
    Settings row again; the chain settles. Scored on modelled frames and
    on the frames CI draws.
- **Colours:** none new (a standard Settings row).
- **Privacy policy:** no sentence changes.
- **Screens:** in Figma, the section
  [Voice Settings, reached with a held look](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=228-698):
  [today on the iPhone 17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=228-699)
  (the row's place over 70%),
  [the way back placed, iPhone 17](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=228-724)
  and
  [the way back placed, 13-inch iPad in portrait](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f?node-id=228-743),
  each at the default text size, drawn from the frames CI read. The owner
  accepts them by merging.
- **Concerns:**
  - *Reading is pointing.* Voice Settings' own words (Speed and its
    sentence, Voice) sit just above controls that change the speed or
    the voice, as they do today. A look resting on those words is a
    separate path from the one this fixes; recorded as a follow-up.
  - *The Personal Voice question* is not scored. Its Ask button shows
    only under `PersonalVoiceAskPolicy.fromSettings`, which no build
    people use has: Brickson asks at launch, for now, until device check
    D1 decides (docs/DECISIONS.md, "Personal Voice permission is asked at
    launch, for now"). iOS's question shows only on a device that
    supports Personal Voice, and where a look rests after answering it is
    where iOS put its buttons, so scoring it needs a real device; added
    to D1's row in docs/DEVICE-CHECKS.md.
  - *Family Setup scrolled* is covered for the Voice Settings row. The
    other rows that open guides open screens the chains do not follow
    yet (Settings' other screens); Set Up Step by Step scrolled is PR
    #103's follow-up and the owner's question there.

## Plan

- **Files that change:** `BricksonUITests/SettingsChains.swift` (Voice
  Settings as a screen of the Settings surface, its controls' effects and
  a kind of hazard of its own), `BricksonUITests/ChainEngine.swift` (an
  effect for leaving Brickson), `BricksonUITests/SettingsOnHomeTests.swift`
  (read Voice Settings where its row shows, and from a scrolled Family
  Setup), `BricksonTests/VoiceSettingsChainsTests.swift` (new),
  `Brickson/Settings/VoiceSettingsView.swift`,
  `Brickson/Settings/FamilySetupView.swift`,
  `Brickson/Settings/SettingsView.swift` (`SettingsLanding.voiceRow`),
  `Brickson/Settings/SettingsComponents.swift` (comments),
  `Brickson/Layout/LibraryQuestionPlace.swift` (a row that showed only
  in part: the choices start clear of all of it, which the sweep
  across Family Setup's scrolls found; the Library's questions take the
  same rule), `BricksonTests/Layout/LibraryQuestionPlaceTests.swift`,
  `Brickson/Resources/Localizable.xcstrings` (the new words), and the
  records: docs/DECISIONS.md, docs/HANDOFF.md,
  docs/ROADMAP.md, docs/DEVICE-CHECKS.md, a `docs/log/` record.
- **Order of work:** one pull request. Tests first: the chain surface
  learns Voice Settings and a unit test finds the hazard on `main`'s CI
  frames; a second finds none once the screen is placed, across CI's five
  windows and every scroll of Family Setup, and a third shows why the
  place follows the scroll. Then the placement, then the UI tests that
  read the running app. Built on PR #103 (the check-in card), which
  changes the same Settings files and was waiting on its CI: this
  branch merges `main` once #103 has landed, before the pull request
  opens.
- **Risks:** the UI jobs' time (the iPad job took 87 of its 90 minutes on
  one of #103's runs): reading Voice Settings adds one screen to the
  chain runs where its row shows, and one short test; Family Setup not
  keeping its scroll on the way back would break the chain's settling,
  so the UI test checks the row is back under the way back.
- **Proof:**
  - `VoiceSettingsChainsTests.theScreenAsOnMainMeetsASpeed`: fails if the
    surface cannot see the hazard (as before this change, when Family
    Setup's row led nowhere the chains followed).
  - `VoiceSettingsChainsTests.noHeldLookActsOnTheVoice`: fails with the
    way back at the top of the screen or the content not moved down.
  - `VoiceSettingsChainsTests.placedFromTheContentAScrolledRowMeetsBackToTalking`:
    fails if the way back's place ignored Family Setup's scroll and no
    hazard followed, which would mean the scroll test proves nothing.
  - `LibraryQuestionPlaceTests.aRowPastTheFootKeepsTheChoicesClearOfAllOfIt`:
    fails with the choices placed clear of the way back alone, as before
    this change.
  - `SettingsOnHomeTests`: Voice Settings read where its row shows,
    scored with every other Settings screen (fails on any hazard, a new
    kind `actsOnTheVoice` among them), the way back checked in the row's
    place, and the row back under it after going back; and
    `testVoiceSettingsFromAScrolledFamilySetup` at the largest text,
    where Family Setup scrolls on both devices.
  - Device check: where a pointer really rests and how Snap to Item
    picks, as for every Settings screen (docs/DEVICE-CHECKS.md).
