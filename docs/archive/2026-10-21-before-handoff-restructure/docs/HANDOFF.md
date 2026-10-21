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

On 2026-10-12 a review skill was added for Copilot:
`.github/skills/code-review/SKILL.md`, refined from the owner's draft. It
gives the steps of a review; what counts as a finding stays in AGENTS.md
(docs/DECISIONS.md, "Reviews, updates and GitHub settings"). GitHub's
documentation, read from its source files on 2026-10-12, says four
things:

- Copilot code review can use a skill in `.github/skills` without being
  asked, when the skill is relevant to the review.
- A review-focused folder name such as `code-review` makes that likely.
- Copilot reads skills and instructions from the pull request's own
  branch.
- A comment written with a skill's help carries an attribution at its
  bottom that names the skill.

GitHub's changelog of 2026-07-29, seen only in search results, adds that
skills in code review are generally available, Copilot Pro included.
`.github/copilot-instructions.md` also points to the skill; GitHub does
not say whether that line changes anything.

Seen working on PR #8, 2026-10-12:

- GitHub requested a Copilot review as the pull request opened; nobody
  asked for it. The review started 13 seconds after opening and posted
  about five minutes after. (Requested by hand on PR #5, it had reviewed
  at Balanced effort in about three minutes and left one correct Low
  finding, fixed in `dd4bfff`.)
- Copilot used the review skill. Its job log (the pull request's
  `copilot-pull-request-reviewer` check → Details) says it loaded
  instructions and skills from the pull request's branch, read
  `.github/copilot-instructions.md`, `AGENTS.md` and `CLAUDE.md`, and
  invoked the skill (`[skills] ... invoked: name="code-review"`). It left
  no comments of its own, so no comment carried the attribution; the job
  log is where to check.

Also seen on 2026-10-12:

- Dependabot's first grouped pull request arrived: PR #7, which moves
  `tests.yml` from `actions/checkout@v5` to `@v7`. CI passed. It got no
  review from Copilot or Codex, so Dependabot's pull requests are reviewed
  only when the owner requests Copilot by hand (docs/DECISIONS.md, "Reviews,
  updates and GitHub settings").
- The `main` ruleset ("Protect main") matches the table in
  docs/DECISIONS.md, checked through GitHub's API by the agent that set up
  Copilot.
- Code scanning, checked through GitHub's API and job logs: CodeQL's
  default setup analyses only the workflow files, with no alerts so far.
  Its first run, on 2026-10-10, also tried Swift and failed because no
  Xcode project is committed, and GitHub dropped Swift by itself. That
  attempt still shows as an error on the Tool status page (Security and
  quality → Code scanning → Tool status) until the owner deletes it
  there. The decision not to scan Swift with CodeQL, its reasons and when
  to revisit it are in docs/DECISIONS.md,
  "Reviews, updates and GitHub settings", *Code scanning*, which also
  records that AI Scan for pull requests is on.

Not yet seen working, to check after the merge and the settings:

- Insights → Dependency graph → Dependabot shows no configuration error.
- The repository's Copilot code review settings page matches
  docs/DECISIONS.md.
- Copilot AI credits used per review (Settings → Billing → AI usage).
- AI credits used by AI Scan for pull requests, which runs after every
  commit, agents' pushes included, and whether they come out of the
  Copilot Pro allowance (Settings → Billing → AI usage). If they do, the
  owner decides whether to keep AI Scan on (docs/DECISIONS.md, *Code
  scanning*).
- Whether the next Dependabot pull request gets a CodeQL analysis before
  it merges; PR #7 got none.

## Next steps, in order

1. **Owner:** publish the website. In the repository's Settings → Pages,
   set *Source* to **GitHub Actions** if it isn't already, merge the pull
   request that fills in the policy's blanks, then check that the
   "Publish website" run on the Actions tab is green and that both
   addresses open on a phone.
2. **Owner:** open and run the app on a Mac ([local development setup](GETTING_STARTED.md)), and run the tests once (⌘U).
3. **Owner:** review the starter phrases
   (`Brickson/Resources/StarterPhrases.json`). A reviewer noted two
   near-duplicates ("Wait a moment, please." and "Give me a moment to
   answer.") and that "Please move me." could be clearer.
4. **Owner:** choose the developer account (personal or organization).
   Then set `DEVELOPMENT_TEAM` and the final `APP_BUNDLE_ID` in
   `project.yml` (docs/DECISIONS.md, "App identity").
5. **Owner:** apply the GitHub settings in docs/DECISIONS.md, "Reviews,
   updates and GitHub settings", and delete the failed Swift
   configuration on the Tool status page (*Code scanning* there).
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
| 2026-10-12 | `edf26de` | `.github/copilot-instructions.md` no longer states a price for Brickson: the owner has not decided one, and nothing in the project states one | Documentation only |
| 2026-10-12 | `6b2f40c` | DECISIONS and the Dependabot file name the three settings security updates need (dependency graph, Dependabot alerts, Dependabot security updates), all on as of 2026-10-10 (Codex review) | Documentation only; YAML parsed locally |
| 2026-10-12 | `280889b` | Brickson is no longer called free, because the owner has not decided its price: AGENTS.md, README.md, the support page's description and opening line, and the privacy policy's "Who we are" drop the word, and the policy's Effective date is now October 12, 2026. DECISIONS.md "Price not decided" says nothing may state a price until the owner decides | Text and HTML only, checked by a search of the repository; pull request CI. The live pages change only after the merge, when "Publish website" runs |
| 2026-10-12 | `6865f47` | `storekit` taken off AGENTS.md's list of skills never to apply: it came from the reference app and ruled out in-app purchases before a price was decided | Documentation only |
| 2026-10-12 | `82aef90`, `5dfb8f6`, `4f9fe80`, `41f9555`, `b2b6206` | Review skill for Copilot (`.github/skills/code-review/SKILL.md`), refined from the owner's draft: review steps that point to AGENTS.md for every rule instead of restating rules or naming features that are not built yet. `.github/copilot-instructions.md` points to it. AGENTS.md *Code Review Rules* gains checks every reviewer applies: statements of Brickson's price; a new section, *Tests, workflows and the rules themselves*, for tests that cannot fail, workflow changes that expose secrets or a write token, put pull request text into a shell command or add an action not published by GitHub, and changes that weaken the review rules. *Not findings* now excuses only gaps the base branch already records. A change *Code Review Rules* names is reported even when no person is affected yet; only other suspicions a reviewer cannot trace become questions (Codex's review of this pull request). AGENTS.md, DECISIONS.md and README.md say where the skill sits, and DECISIONS.md records that the owner asked for it. AGENTS.md, DECISIONS.md and README.md now say Dependabot's pull requests get no automatic review (PR #7) and that only the owner requests Copilot reviews; README.md says Copilot never sees replies and its headline is not an approval | Documentation only; pull request CI. Copilot's automatic review of this pull request invoked the skill (its job log) |
| 2026-10-12 | `1188f5d`, `8fd22a0`, `5421109`, `c1ea737`, `28f4819` | Why CodeQL does not scan the Swift code: default setup's one Swift attempt failed because no Xcode project is committed, and GitHub dropped Swift by itself; advanced setup would add a Mac job to every pull request for checks that match nothing in today's code and fall behind each new Xcode. docs/DECISIONS.md *Code scanning* corrects two earlier statements (Xcode 27 does not block scanning today; CodeQL announced no Swift mode that skips the build), records that AI Scan for pull requests is on and that Dependabot's first pull request got no CodeQL analysis before merging, and lists when to revisit; the ruleset rows say the same. README.md and AGENTS.md mention the scans, and AGENTS.md gains a gotcha. The failed Swift configuration on the Tool status page is the owner's to delete | Documentation only. Checked 2026-10-12 through GitHub's API and job logs (default setup's languages, the failed job's log, analyses, PR check runs, the ruleset, AI Scan's setting and logs) and GitHub's and CodeQL's documentation sources; pull request CI. Not verified: where AI Scan's AI credits come from, and the 10 to 20 minute estimate for a Swift CodeQL job (never run) |


## Website redesign — 2026-10-12

The homepage now introduces Brickson with an ivory-and-navy palette,
large serif headings and locally stored decorative speech-bubble artwork.
Support and privacy remain at their original addresses. Shared navigation,
a policy contents list, dark appearance, keyboard focus and 44px link
heights make the pages easier to use. The homepage explicitly says the app
is in development; it states no price, release date or download offer.
The existing privacy policy main content, including its Effective date,
was compared byte-for-byte with the base version and is unchanged.

Verification on the owner's Mac:

- `scripts/test-site.py`: three tests pass. `PaletteTests` reads the actual
  website CSS and measures text at 4.5:1 and boundaries at 3:1 in both
  appearances. The palettes are opaque, with no transparency effects.
  Link/asset checks reject missing targets, scripts and outside assets.
  The tests were written first: missing new palette tokens and the absent
  development notice failed before implementation. Each test names the
  regression that makes it fail. CI runs them in the existing Unit tests
  job, without changing its name, trigger or permissions.
- Chromium: both pages at 320, 390, 768 and 1440 CSS pixels, light/dark,
  normal and 200% root text size; no horizontal overflow after fixing
  navigation wrapping and the long contact link. All links have at least
  44px height. Increased-contrast and reduced-motion preferences checked;
  there is no animated content. Keyboard skip link, support navigation,
  policy navigation and policy section anchors work. The support link
  points to the published email address; no email was sent.
- The in-app browser rendered the page, but its 1440px capture was clipped
  to the panel. Playwright Chromium supplied full-page visual checks.
  The concept and final screenshots were compared for headline, hierarchy,
  palette, artwork, spacing and section order. Support wording is more
  specific than the concept and retains the non-emergency notice; dark
  mode presents the artwork on its original ivory background.
- The full app unit suite passed (113 passing cases in the formatted log),
  Xcode 27.0, iOS 27.0, dedicated iPad Pro 13-inch (M5, 16GB) simulator
  named `Brickson Website Checks`. No app UI, orientation, keyboard or
  appearance assertions were made in that unit run. No Swift changed.
- These are browser and simulator checks, not physical-device evidence.
  GitHub CI and Pages deployment are separate checks. The owner merges;
  the live site changes only after merge and a successful Pages workflow.

### Repository social preview — 2026-10-12

The owner requested a GitHub social preview using GitHub's template.
`site/assets/social-preview.jpg` preserves the uploaded 1280×640 JPEG
(about 184 KB). It matches the website's ivory/navy speech-bubble design,
keeps text within the template's safe area and says the app is in development.
Uploaded through repository Settings → General → Social preview, then
reloaded the settings page and verified the image remained displayed.
This repository setting takes effect independently of the Pages deployment;
committing a replacement image alone does not update GitHub's social preview.
No app or website behavior changed in this follow-up.


### Website review fixes — 2026-10-12

Review found that the 2.1 MB hero PNG was unnecessarily large, and the
200% text check had missed headings breaking inside words. The homepage
now uses a local 284 KB JPEG (about 87% smaller). A test caps the hero
download at 400 KiB. Headings no longer allow mid-word wrapping; mobile
type scales and margins and tablet column stacking keep whole words in
view. Chromium reproduced heading overflow with wrapping disabled before
the layout fix; after it, both pages at 320, 390, 768 and 1440 CSS pixels
with 200% root text size have no page or heading overflow. Four website
tests pass. App code is unchanged from the passing 113-case unit run.

### Logo artwork — 2026-10-12

The owner requested an app logo matching the project's purpose. The raster
artwork in `design/brand/` combines a rounded B and a speech-bubble tail:
a 1024×1024 opaque ivory-on-navy app-icon version and a 1254×1254 transparent
navy mark. Dimensions and alpha were verified; the icon was inspected at
64×64. The folder's README records the design brief and generation method.
These are design deliverables; the existing app icon/catalog is unchanged.

### Public README rewrite — 2026-10-12

The README now addresses repository visitors: project purpose, implemented
capabilities versus planned work, design principles, concise build/test
commands, contribution requirements, security reporting and license status.
The detailed first-time Xcode and device-signing instructions are preserved
in `docs/GETTING_STARTED.md`. The README does not adopt a proposed new app
name, promise a price or release date, or claim physical-device validation.
Local Markdown links and command references were checked against the files;
four website tests pass. The full app unit suite also passed again on
Xcode 27.0 / iOS 27.0, using the dedicated iPad Pro 13-inch (M5, 16GB)
simulator. The first attempt lacked sandbox access to CoreSimulator; the
rerun with simulator access passed. No app, project or test code changed.

### Brickson name and short founder note — 2026-10-12

The owner chose to retain Brickson and authorized a public explanation of
its personal origin. After asking for a shorter version, the homepage and
README now use two brief paragraphs, in the words the owner authorized
(docs/DECISIONS.md, "Brand name and founder story"). No detailed fair story or
additional biographical facts are published. The homepage has a Why Brickson?
navigation link and a responsive founder section using existing palette colors.
AGENTS.md and DECISIONS.md now reflect the name choice; no app identifier or
privacy-policy wording changed. `docs/NAME_AVAILABILITY.md` separates fresh
Apple/USPTO/domain checks from the broader research in the owner's supplied
PDF. No registration, purchase, account change or legal clearance is claimed.

Verification: all four website tests and the full app unit suite passed
(Xcode 27 / iOS 27, dedicated iPad Pro 13-inch M5 simulator). The browser
rendered the new note and its anchor navigation; widths 320 and 1440 CSS
pixels had no page overflow. The note was visually inspected in dark mode
and uses existing tested light/dark colors. No physical-device claims.

### Merge main into website branch — 2026-10-12

Resolved README and HANDOFF conflicts after PR #10 landed. Kept the
visitor-facing README and founder note, included the new CodeQL/AI Scan
coverage guidance, and retained both branches’ handoff history. The merged
workflow retains the website test step and main’s CI comments and settings.
Four website tests and the full unit suite passed on the dedicated iPad Pro
13-inch M5 simulator (Xcode 27 / iOS 27) after resolution. No app code changed.

### Founder-note privacy review — 2026-10-12

PR #9 review identified that the general public-repository privacy rule did
not mention the owner's explicit request to publish the founder note.
AGENTS.md now records a narrow exception for the already authorized facts,
the owner's attribution, and the decision/handoff record. Other family identities,
medical details and private documents remain outside the exception. This
implements the owner's publication request without broadening it. No public
story text, app behavior or privacy-policy promise changed.
The full unit suite passed again on the dedicated iPad Pro 13-inch M5
simulator (Xcode 27 / iOS 27); this change is documentation only.

### Privacy layout under enlarged text — 2026-10-12

Reproduced the new review finding at 1100 CSS px with a 200% root font:
the policy heading needed 348px inside a 220px column. The policy layout
now wraps flex columns based on rem-sized content widths, so enlarged text
stacks the columns without depending solely on the fixed viewport breakpoint.
Chromium checks at 320, 390, 768, 1051, 1100, 1280 and 1440px with 200% root
font found no page or heading overflow after the fix. The browser test
surface served an older stylesheet, so verification explicitly replaced
that stylesheet with the exact working-tree CSS before measuring. Four
website tests pass. Policy wording and effective date are unchanged.
The full app unit suite passed on the dedicated iPad Pro 13-inch M5
simulator (Xcode 27 / iOS 27) before committing the layout change.

## UI-test infrastructure follow-up — October 13, 2026

After PR #9 merged at `b25331d`, Tests run `38435645095` failed before
running a UI test: Xcode could not find simulator
`A2011F14-88A1-46AA-999A-FD6FEDCD870B` (exit 70). The unit job passed with
the same Xcode 26.6 and simulator ID on another runner. The unchanged UI
rerun found the simulator and ran all four tests; three passed, but Apple's
accessibility audit threw domain `com.apple.xcode.xctest.accessibilityAudit`,
code `-56`, "Audit failed to complete in time". That timeout had also
occurred on PR #9. The original destination failure's exact cause is not
established: xcbeautify discarded its destination details.

- The test-only `AccessibilityAuditRunner` repeats the complete audit once
  for that exact domain/code. All other errors and a repeated timeout
  propagate. The existing issue handler and `XCTFail` calls stay intact:
  findings from either attempt remain failures. No app behavior changed.
- Four injected-error regression tests cover recovery, persistent timeout,
  unrelated errors and success. Before implementation, the recovery and
  persistent-timeout tests failed; afterwards all four passed.
- `scripts/test.sh` now prints the full raw Xcode output on failure while
  preserving its nonzero exit status. Three shell-fixture tests check
  destination details, assertion failures without automatic reruns, and
  success. The two failure-reporting tests failed before the change and all
  three passed after it. CI runs them in the existing Unit tests job;
  required job names, triggers, permissions and test assertions are intact.
- Local verification: 113 unit tests and all eight UI/regression tests
  passed on Xcode 27.0 / iOS 27.0, dedicated iPad Pro 13-inch (M5, 16GB)
  simulator `F677BB51-0144-4083-8112-3EC0A8838399`. No typing flow was used.
  Physical-device sound and gaze behavior are not covered by these checks.
  GitHub CI on the new pull request remains the merge gate; this does not
  claim a permanent fix for the first runner's unexplained destination
  failure.
