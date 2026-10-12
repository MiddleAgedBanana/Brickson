# Handoff

The current state of Brickson and what to do next. **Start every working
session here**, after `git status` and `git log --oneline -15`. Update this
file at the end of every session (AGENTS.md, "Document every change").

## State on 2026-10-10: the starting files

The first pull request (branch `claude/new-app-scaffold-op8g1g`) adds the
project, the foundations ported from the reference app, a stand-in Home
screen, tests, CI and these documents.

### What the app does today

What it is written to do; the *Verification* section says how much of it
has been seen working. It opens on a Home screen with Yes, No and
Emergency, a row of everyday categories, and phrase tiles from a neutral
starter set. Choosing a tile speaks it at once; the sentence stays on
screen with Again beside it. Emergency switches to the emergency phrases
and says nothing itself. If audio fails or the volume is very low, a short
passive warning appears at the bottom in space that is always kept for it.
If the library cannot be saved or filled, the app runs from a filled
in-memory library and a warning says changes will not be kept.

### What came over from the reference app

See `docs/PORTING.md` → *Ported so far*. In short: the speech engine
(survives the silent switch, interruptions and media-services resets;
Personal Voice preferred; repeat absorption on `ContinuousClock`), audio
safety warnings, the screen-wake policy, and the phrase models, now in a
versioned schema without cascade deletes.

### Verification

- **Written on a cloud machine that cannot compile Swift.** Nothing was
  built or run where it was written.
- **GitHub CI** (`.github/workflows/tests.yml`, `macos-26` runner, Xcode
  26.6, iPad Pro 13-inch simulator on iOS 26.5) is the only evidence so far:
  - **On `5569286`, both jobs are green.** The whole unit suite passes,
    including every test added in review (launch fallback, media-services
    reset, Increase Contrast, the spoken-name keys, announcements and
    phrase starts). All four UI tests pass: Home appears with its quick
    controls and starter phrases, a phrase tap enables Again, Emergency
    opens the emergency phrases and says nothing, and Home passes the
    accessibility audit.
  - The audit flags phrase-tile labels such as "Maybe." as "not
    human-readable". Tile labels are the person's own words, so the audit
    test expects that guess on phrase tiles only (`LaunchTests`); any other
    issue fails it.
  - Not seen by any test: VoiceOver announcements being posted, the
    message's scroll reset, the missed-callback watchdog, and anything
    about sound.
  - On PR #4, the first UI test (`testAPhraseSpeaksOnTheFirstTap`) failed
    twice on app and test code identical to green `main`: once reading
    Again straight after the tap, once timing out while launching the app.
    The cause was not established. `scripts/test.sh` now starts its default
    simulator and waits for it to finish starting, and the test waits up to
    10 s for Again to turn on. The failure was intermittent, so a green run
    afterwards does not prove the fix.
  - Later commits are checked on the pull request; read its latest CI run.
- **Not yet run by the owner on a Mac**, and **no physical-device evidence
  of any kind**. See *Checks that need a real device* below.

### The public website

Apple needs a privacy policy address and a support address before the app
can be listed. Both pages are in `site/`, published by GitHub Pages through
`.github/workflows/pages.yml` ("Publish website"): the policy at
https://middleagedbanana.github.io/Brickson/privacy/ and the support page
at https://middleagedbanana.github.io/Brickson/. README → *The website*
explains how to change them, and AGENTS.md → *The privacy policy is a
promise* lists the code rules that keep the policy true.

- The policy was drafted in the project's Claude Doc "Privacy Policy draft
  for the new ALS app", which also says what to answer in App Store
  Connect ("No, we do not collect data from this app", then Publish). Its
  claims were checked against Apple's and GitHub's documentation on
  2026-10-10. Not a lawyer's review.
- The policy has sections for three features that are not built yet
  (recorded phrases, caregiver alerts, Siri and Shortcuts). Delete any that
  the first release doesn't ship before submitting.
- The first publish run (after PR #2 merged) stopped, as designed, because
  the name, email and date were still blanks. They are filled in the
  following pull request. Whether Pages' Source is set to GitHub Actions
  could not be seen from a cloud session.
- Not yet seen live: the pages have only been rendered locally in
  Chromium, at 320, 375 and 1280 px, light and dark.

### Known gaps in this first version

- Home's sizes are plain defaults, not measured gaze, switch or touch
  sizes, and the phrase grid scrolls. Fine for a stand-in, not for a
  release (invariant 11).
- No Get Attention alarm yet, so `AudioSafetyPolicy` runs with the alarm
  always idle.
- No typing, editing, Settings, voice choice or backup.
- Personal Voice permission is asked at first launch without explanation
  (docs/DECISIONS.md).
- English only; the String Catalog fills itself as Xcode builds. Two
  strings are not in it yet: the speech-rate names in `SpeechRateSteps`
  and the voice sample sentence in `SpeechService`.
- The full audio-warning sentences VoiceOver reads mention Get Attention,
  which arrives with port step 1.
- Off-main callbacks: `OffMainThreadCallbackTests` calls the volume
  handler directly, so it would not catch a missing `@Sendable` on the
  real KVO closure. The Personal Voice completion and the synthesizer
  delegate methods have no off-main test yet (docs/LESSONS.md).
- The audio session stays active after speech ends, so other apps' audio
  does not resume by itself (docs/DECISIONS.md, "Background audio").
- Home posts a VoiceOver announcement for each audio problem. Its text and
  priority are unit-tested (`AudioAnnouncementPolicy.announcement`), but
  no test sees the announcement posted: neither the simulator nor UI tests
  run VoiceOver. It is a device check below.
- `SpeechService` has no test seam for the synthesizer itself, so the
  missed-callback watchdog (`watchForMissedFinish`) is untested. A
  protocol over `AVSpeechSynthesizer` would let tests drive it.
- The seeder fills the library whenever it is empty. Once editing exists,
  someone who deletes every category would get the starter set back at
  the next launch. Decide what should happen before porting editing.
- If SwiftData cannot create even an in-memory library, the app stops
  (`fatalError` in `PhraseLibraryStore.openForApp`), as the reference app
  did. A corrupt store or a full disk cannot cause that; only a schema
  error (which every PR's tests would catch) or SwiftData failing outright.
  A screen of Yes, No and emergency phrases that needs no SwiftData was
  suggested in review and not built: it would be a second Home to keep
  safe. The owner decides.
- The app icon is a placeholder (a white speech bubble on blue).
- No license file: the code is public but, without a license, all rights
  are reserved. The owner decides.
- No Privacy row in the app yet. App Review requires a link to the
  privacy policy inside the app (AGENTS.md, *The privacy policy is a
  promise*).

### GitHub reviews and updates (2026-10-10)

The owner bought GitHub Copilot Pro for code review. The repository now
has review rules every reviewer reads (AGENTS.md, *Code Review Rules*), a
short Copilot file pointing at them, a Dependabot configuration for the
workflow actions, and a security policy. The repository settings these
rely on (a `main` ruleset, Copilot's code review settings, Actions and
security switches) are listed with reasons in docs/DECISIONS.md, "Reviews,
updates and GitHub settings"; the owner applies them on GitHub.

Not yet seen working, to check after the merge and the settings:

- Copilot reviews a new pull request by itself once the settings are on.
  Requested by hand on PR #5, it reviewed at Balanced effort in about three
  minutes and left one correct Low finding (fixed in `dd4bfff`).
- Dependabot's first grouped pull request arrives (`tests.yml` uses
  `actions/checkout@v5`, `pages.yml` uses `@v7`), and Insights →
  Dependency graph → Dependabot shows no configuration error.
- Copilot AI credits used per review (Settings → Billing → AI usage).

## Next steps, in order

1. **Owner:** publish the website. In the repository's Settings → Pages,
   set *Source* to **GitHub Actions** if it isn't already, merge the pull
   request that fills in the policy's blanks, then check that the
   "Publish website" run on the Actions tab is green and that both
   addresses open on a phone.
2. **Owner:** open and run the app on a Mac (README → *First time on your
   Mac*), and run the tests once (⌘U).
3. **Owner:** review the starter phrases
   (`Brickson/Resources/StarterPhrases.json`). A reviewer noted two
   near-duplicates ("Wait a moment, please." and "Give me a moment to
   answer.") and that "Please move me." could be clearer.
4. **Owner:** choose the developer account (personal or organization).
   Then set `DEVELOPMENT_TEAM` and the final `APP_BUNDLE_ID` in
   `project.yml` (docs/DECISIONS.md, "App identity").
5. **Owner:** apply the GitHub settings in docs/DECISIONS.md, "Reviews,
   updates and GitHub settings".
6. Port step 1's remainder: the Get Attention alarm (`AttentionAlertPlayer`
   and its tone) with Stop Alert in a different place, and the audio
   warning strip.
7. Port step 2: editing logic and backup, with a failure-injection test for
   every save (docs/LESSONS.md, "Never roll back a cascade delete").
8. Port step 3, then design the generalized layout engine (step 4) before
   replacing Home.

## Checks that need a real device

Simulator runs cannot show any of these. Record each result here with the
device, OS version, settings and date.

| Check | What it decides |
|---|---|
| Speech plays with the silent switch on, and after a phone call | Audio session handling (invariant 4) |
| Personal Voice appears and is chosen once permission is given | Voice choice and when to ask for permission |
| Each input method reaches every control: touch, Voice Control, Switch Control, Full Keyboard Access, AssistiveTouch Dwell, head tracking, Eye Tracking | That standard buttons are the whole integration (invariant 1) |
| How far Snap to Item jumps, and whether the pointer stays on an activated control or follows the gaze | Spacing and placement for dwell profiles |
| Whether a lingering look re-fires a dwell | How much repeat protection matters |
| Whether Snap to Item ignores controls scrolled off screen | Whether scrolling can keep family controls out of reach |
| What the real software keyboard covers in each orientation | The typing layout (docs/LESSONS.md, "Test with the real software keyboard") |
| Get Attention heard from the next room, on the speaker and over Bluetooth | The alarm's sound and level (once ported) |
| Comfortable dwell time and movement tolerance | Setup recommendations per profile |
| Whether Guided Access works together with Eye Tracking | Setup recommendations |
| Which phrases people reach for, and how many categories can be scanned by eye | The starter library |
| "Open Brickson" by Siri and Voice Control, said by a few people, and how VoiceOver reads the icon | `APP_SPOKEN_NAME` and the alternative names |
| With VoiceOver on, a cut-off phrase or very low volume is announced once, in full, without moving focus | Home's audio announcements (invariant 4) |

## Record of changes

| Date | Commit | Change | Verified by |
|---|---|---|---|
| 2026-10-10 | `a1f8cfa`…`d5fecc2` | Starting files: project, speech, storage, stand-in Home, tests, CI, docs | CI: unit green; UI 2 of 4 failed (two "Emergency" buttons; audit) |
| 2026-10-10 | `c60db2a` | One Emergency button on Home (the category row leaves the emergency category out); the audit test names each issue | CI: UI tests pass except the audit |
| 2026-10-10 | `15ff5b1` | Colours written in Xcode's hex form, values pinned by `PaletteTests` (Codex review) | CI: unit green |
| 2026-10-10 | `2b7dc2e` | Create Application Support before opening the store, which silences SwiftData's first-launch errors | CI: unit green |
| 2026-10-10 | `6625580` | The audio warning's space is always kept, with its short text (Codex review) | Pull request CI |
| 2026-10-10 | `56c2c86`…`6fcb744` | Audit expects its phrase-tile label guess and reports every issue; Emergency checked to say nothing; migration plan checked; `test.sh` prints a pass line; README, AGENTS, LESSONS, DECISIONS corrected after review | Pull request CI |
| 2026-10-10 | `0260099` | Long messages scroll at full size instead of shrinking to half (Codex review); the audio-session release is recorded as open | Pull request CI |
| 2026-10-10 | `f9eb42c`, `cb25616` | Again's disabled look keeps readable contrast (audit); the spoken name and Siri's alternative name "Brick Son" | Pull request CI |
| 2026-10-10 | `97906b2` | A store that cannot be filled at launch falls back to a filled in-memory library, so Emergency always has phrases (Codex review) | Pull request CI |
| 2026-10-10 | `9e53ed5` | A media-services reset that cuts off a phrase now names Again on Home, as other interruptions do (Codex review) | Pull request CI |
| 2026-10-10 | `b4c3679` | A synthesizer that goes idle with no callback is reported as a cut-off phrase (Again named), after a half-second grace for a late callback (Codex review) | Compiles on CI; no test seam for the synthesizer yet |
| 2026-10-10 | `2630e6d` | `PaletteTests` checks every pair with Increase Contrast too, and pins primary ink on the screen (Codex review) | Pull request CI |
| 2026-10-10 | `451426c` | VoiceOver announces each audio problem as it happens, with the full sentence; cut-off phrases and audio failures interrupt, low volume waits for VoiceOver to finish (Codex review) | Pull request CI for the announcement text and priority; the posting itself needs a device with VoiceOver |
| 2026-10-10 | `5569286` | Every phrase start, including Again and the same phrase chosen again, shows the message from the top (`SpeechService.phraseStartCount`; Codex review) | Pull request CI for the count (`SpeechServiceTests`); the scroll reset itself is not tested |
| 2026-10-10 | `8be35ce` | CI green on `5569286` recorded; the app stopping if SwiftData cannot start at all is listed as a known gap (Codex review, declined) | Documentation only |
| 2026-10-10 | `7e4e31c`, `6cf534c` | The privacy policy and support pages (`site/`) and the "Publish website" workflow (PR #2); the policy corrected after a fact-check and review | Pages rendered locally in Chromium; workflow not run until merge |
| 2026-10-10 | `f1182d9` | Again shows a press by shrinking slightly instead of fading, so its white label keeps 4.5:1 on the fill while held (Codex review) | CI; no test sees a pressed state |
| 2026-10-10 | `e6335dd` | Reversed the shrink, which drew the label below its default size (Codex review): a press now shows a primary-ink ring inside Again's edge, with the label and fill unchanged | CI; no test sees a pressed state |
| 2026-10-10 | `d881f71` | `PaletteTests` pins the pressed ring: primary ink on the control fill at 3:1 or better in every appearance (Codex review) | CI |
| 2026-10-10 | `d9586f4` | The policy's blanks filled in with the owner's name, contact email and effective date; README, AGENTS.md and this file describe the website | The publish run after PR #2 stopped at the blank check, as designed; the next run needs Pages' Source set to GitHub Actions |
| 2026-10-10 | `6e78f0a` | `scripts/test.sh` starts its default simulator and waits for it to finish starting (`simctl bootstatus -b`) before building and testing, after a UI-test launch timed out on CI with the same code green on `main` | CI; the failure was intermittent, so one green run does not prove the fix |
| 2026-10-10 | `d80f109` | `testAPhraseSpeaksOnTheFirstTap` waits up to 10 s for Again to turn on instead of reading it once straight after the tap | CI; intermittent, as above |
| 2026-10-10 | `ea7a09d` | Review and update setup: *Code Review Rules* in AGENTS.md (read by Codex, Copilot and Claude Code), `.github/copilot-instructions.md`, `.github/dependabot.yml` (GitHub Actions, monthly, grouped, 7-day cooldown), `.github/SECURITY.md`; intended GitHub settings recorded in docs/DECISIONS.md | YAML validated locally; CI green on `ea7a09d`. No Swift changed. Dependabot and Copilot behaviour show only after merge (*GitHub reviews and updates* above) |
| 2026-10-12 | `769350b`, `7103a58` | Main merged in (website, simulator wait). *Code Review Rules* and the Copilot file now treat the developer's name and support email in `site/` as allowed, and flag a change that makes the privacy policy untrue | Documentation only; CI on the pull request |
| 2026-10-12 | `dd4bfff` | The security policy says the reporter can see a private report too (Copilot review) | Documentation only |
| 2026-10-12 | `edf26de` | `.github/copilot-instructions.md` no longer calls Brickson free: the owner has not decided its price, and nothing in the project states one | Documentation only |
