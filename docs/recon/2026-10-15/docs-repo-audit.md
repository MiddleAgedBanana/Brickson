# Documentation, repository, website and privacy recon — Brickson (worktree at `9362eca`, checked 2026-10-15)

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Method: read AGENTS.md and every file in docs/, README.md, .github/, design/brand/README.md, site/; `git log/ls-files/rev-list`; `gh` GET calls only; `curl` of both live pages. Nothing written, nothing built. Everything below is **verified** unless marked *Inference*.

Two environment notes: (1) the shared worktree has an **uncommitted modification to `scripts/test.sh`** (+6/−3: selects the simulator by `deviceTypeIdentifier` instead of name) made by another agent during this session; I did not touch it. (2) `git fetch --prune` removed three stale *local* remote-tracking refs; the remote itself has only `main`.

---

## (a) Stale or untrue statements (file:line → correction)

**docs/HANDOFF.md (474 lines)**
- :7–11 "State on 2026-10-10: the starting files" is still the top-level state heading; ten merged PRs later, the real state lives in the appended sections :298–474. → Dated "State as of 2026-10-14, commit 9362eca" front page (see c).
- :35–36 "Nothing was built or run where it was written" and :38 "GitHub CI … is the only evidence so far" → contradicted by :332–335, :383–386, :402–403, :414–415, :426–427, :440–441, :468–470 (113 unit cases + 8 UI tests on the owner's Mac, Xcode 27.0/iOS 27.0, iPad Pro 13-inch M5 simulator, 2026-10-12/13).
- :61 "Not yet run by the owner on a Mac" → partly stale: suites have run on the owner's Mac (agent-driven). Still unrecorded: a *person* pressing ⌘R, seeing Home and hearing a phrase; no physical device.
- :82–85 "Whether Pages' Source is set to GitHub Actions could not be seen" → Pages API: `build_type: "workflow"`, `https_enforced: true`.
- :86–87 "Not yet seen live" → live since 2026-10-10 10:35 (run 38045416071); redesign live 2026-10-13 17:04; live HTML/CSS byte-identical to `site/`.
- :70–71 "README → *The website*" → README's heading is now "Website development" (README.md:146); no "The website" section exists after `aaab65f`.
- :99–101 "the String Catalog fills itself as Xcode builds. Two strings are not in it yet" → the committed `Brickson/Resources/Localizable.xcstrings` has **zero keys** (`"strings" : {}`); nothing is in the catalog in the repository. The two unlocalized literals are real: `SpeechRateSteps.swift:27` (`"Normal"` / `"\(percent)% of normal"`) and `SpeechService.swift:192` (`previewSample`).
- :189–191 "CodeQL's default setup analyses only the workflow files" (also **docs/DECISIONS.md:319–321** "and nothing else", **README.md:135**, **AGENTS.md** Gotcha "CodeQL scans the workflow files, not the Swift code") → since 2026-10-13T17:05:36Z default setup's languages are `["actions","python"]` (PR #9 added `scripts/*.py`); PR #11's checks include "Analyze (python)" (43 rules). "Not Swift" remains true. → "the workflow files and the Python scripts in `scripts/`".
- :193–195 failed Swift configuration "stays until the owner deletes it" → the API still returns three `/language:swift` analyses with `error: "unsuccessful execution"` (main @ `ab787be`, 2026-10-10 09:04–09:09). *Inference:* not deleted (deleting the configuration removes its analyses). The Tool status page has no API.
- :200–212 "Not yet seen working" → still unverifiable by API (Copilot settings page, AI-credit usage); the Dependabot/CodeQL item waits for a second Dependabot PR (none since #7; monthly schedule).
- :261–295 "Record of changes" stops at 2026-10-12; the nine later commits on main (`eb11592`, `cc4ed4e`, `367e21f`, `aaab65f`, `3d278d0`, `6c53608`, `8dfadd1`, `890f73a`, `2ac2bf6`) have narrative sections (:298–474) but no rows and cite no hashes. Two record formats for one history.
- :443 "## UI-test infrastructure follow-up — October 13, 2026" → level-2 heading and prose date, unlike the "### … — 2026-10-12" sections before it; it outranks "Website redesign"'s subsections by accident.
- :311 "`PaletteTests` reads the actual website CSS" → that is the Python class `PaletteTests` in `scripts/test-site.py:11`, a name collision with the Swift `PaletteTests` invariant 6 names. Suggest renaming the Python class (`WebsitePaletteTests`).
- Still true, re-verified: :37–38 CI = Xcode 26.6 (17F113), iOS 26.5 runtime, iPad Pro 13-inch sim `A2011F14…`; :127 icon is a placeholder (AppIcon-1024.png, 7,200 B, white bubble on blue, unchanged since `a1f8cfa`; md5 ≠ design/brand/brickson-app-icon.png) and README.md:119, design/brand/README.md:12–13 agree; :128–129 no license (no LICENSE in `git ls-files`, GitHub `licenseInfo: null`; README.md:168–171 agrees); :186–188 ruleset matches (see e); :445–453 run 38435645095 = `run_attempt 2`, UI job failed in both attempts, Unit green — matches the API. All 20 commit hashes HANDOFF cites that I sampled are ancestors of `origin/main`.

**Cross-file title citations**
- AGENTS.md:344 and `.github/skills/code-review/SKILL.md:25, :88` cite HANDOFF "*Known gaps*"; the heading is "Known gaps in this first version" (HANDOFF.md:89). Rename the heading to "Known gaps".
- README.md:138 links `[Code scanning](docs/DECISIONS.md)`; HANDOFF.md:197, :209, :295 cite "*Code scanning*". It is a bold run-in label (DECISIONS.md:319) inside "Reviews, updates and GitHub settings", not a heading → promote to `###` or cite the parent.
- Every other cited title exists exactly: AGENTS.md (Non-negotiable invariants, Code Review Rules, Not findings, Communication never fails, Dwell and gaze safety, Data, privacy and platform, Tests, workflows and the rules themselves, Design rules for dwell, switch and pointer input, Workflow rules, Build and test, Gotchas, The privacy policy is a promise, Skills); DECISIONS (App identity, Orientations, Versioned storage, No iCloud sync in 1.0, The screen stays awake, Starter phrases, Home version 0 is a stand-in, Background audio, Price not decided, Reviews, updates and GitHub settings); LESSONS (Storage, Time, Swift concurrency, Never roll back a cascade delete, Timers use ContinuousClock, Add stored fields with their feature, Test with the real software keyboard, Never open the project in Xcode from an agent); HANDOFF (What the app does today, Checks that need a real device, Next steps, in order). Code comments cite 9 titles (project.yml:22,64,76; PhraseLibrarySchema.swift:10,15,41,69; PhraseLibraryStore.swift:48; ScreenWakePolicy.swift:11; SpeechService.swift:400; SpokenUtteranceTracker.swift:41; AppBundleTests.swift:68; HomeView.swift:63 "Words never break" = a bold bullet, acceptable) — all resolve.
- Markdown links: 32 links across 15 tracked `.md` files; **zero broken relative links**.

**Other files**
- `.github/copilot-instructions.md:42–44` exception = "developer's name and support email on the website pages in site/" only; **narrower than AGENTS.md:300–312** (founder note in README.md and site/index.html, DECISIONS/HANDOFF record). AGENTS.md wins by copilot-instructions.md:11–12, but Copilot may flag README.md:24–32 on any README change. Add one sentence.
- AGENTS.md "Where things are" (:35–51) omits docs/GETTING_STARTED.md, docs/NAME_AVAILABILITY.md, design/brand/README.md.
- README.md:94 `python3 scripts/test-site.py` — on the owner's Mac `python3` is aliased in interactive shells (AGENTS.md Gotchas) → `command python3 …` or a note.
- DECISIONS.md:22 / project.yml:25 `APP_BUNDLE_ID: family.avery.brickson` contains the owner's first name; outside AGENTS.md's listed exception; public and immutable after first upload → decide at next step 4 (it already says "final APP_BUNDLE_ID").
- AGENTS.md:60 "Codex reviews every push" — consistent with API: `chatgpt-codex-connector[bot]` summary on #9, #10, #11 and review threads on #9, #10; Copilot (`copilot-pull-request-reviewer[bot]`) reviewed #9, #10, #11; nothing on Dependabot #7 (as DECISIONS.md:273–278 says).
- Price statements about Brickson: **none** (only "free" for GitHub Pages/Actions in pages.yml:2, tests.yml:2; Xcode/Apple accounts in GETTING_STARTED.md:3,75,96; Copilot pricing DECISIONS.md:269–270; `scripts/test-site.py:84` pins the support page against free/paid).

**Private-reference instructions a contributor cannot act on**
- docs/PORTING.md:9–11 ("Before porting any piece, read in the reference repository: docs/HANDOFF.md → *Decided but NOT built*, *Known limits and issues*, docs/SUCCESSOR-HANDOFF.md") — no fallback stated in PORTING (LESSONS.md:15–17 gives one).
- docs/PORTING.md:36 "Build D24 and D25 here" — D24/D25 appear nowhere else in the repository (D27/D28 are explained in LESSONS.md:23–27, :128–133). Unactionable without access.
- docs/PORTING.md:59–61, :91–94 (reference's `docs/ACCESSIBILITY.md`, `FamilyVoiceTests/SnapReach/`, `docs/snap-return/`) — "knowledge, not code" that has not been copied here; DECISIONS.md:155 "(its D2)".
- PORTING "Still to port" (:63–89): nothing forbidden by hard stops as written (BackupService = file export; CaregiverSetupView is family setup, not alerts). Port-order table is accurate: step 1 alarm not ported (HomeView.swift:308–311; no AttentionAlertPlayer/AttentionTone), step 2 editing/backup absent, step 3 three fills only (`Palette.swift` + 3 colorsets). One oddity: `SpeechService.swift:191–216` already carries Settings voice-sample/rate-step logic for a Settings screen that does not exist (step 7).
- LESSONS.md: no rule contradicted by the code; LESSONS:54–56 (`seedIfEmpty` takes `save:`) matches StarterLibrary.swift:51–54.

## (b) Owner's still-open checklist (HANDOFF.md:214–238)

| Step | Status | Evidence |
|---|---|---|
| 1 Publish website, Pages source = Actions | **Done** | Pages `build_type: workflow`; "Publish website" runs: designed failure 2026-10-10 06:35 (blank check), success 10-10 10:35, 10-12 15:57, 10-13 17:04 (30 s). Live = committed (diff). "Opens on a phone" = owner's eyes, unrecorded. |
| 2 Run the app on a Mac; tests once | **Partly** | Suites green on the owner's Mac (HANDOFF:468–470), run by agents. No record of a person running the app; `DEVELOPMENT_TEAM` empty so no device build possible. |
| 3 Review starter phrases | **Not done** | `StarterPhrases.json` still has "Wait a moment, please." (:12), "Give me a moment to answer." (:51), "Please move me." (:41); DECISIONS.md:171 still "a draft to review". |
| 4 Developer account; `DEVELOPMENT_TEAM`, final bundle ID | **Not done** | project.yml:26 `DEVELOPMENT_TEAM: ""`; :25 unchanged; NAME_AVAILABILITY.md:49 (confirm title in the ASC account) also open. |
| 5 GitHub settings; delete failed Swift config | **Settings done; deletion unverifiable** | Ruleset matches all 8 rows (see e); Copilot auto-review, AI Scan, Dependabot alerts + security updates all observed on. Swift analyses still listed → *Inference:* not deleted. |
| 6–8 Port steps | **Not started** | greps above; PORTING table unchanged. |

Owner decisions parked in "Known gaps" and still open: license; the `fatalError` fallback screen (HANDOFF:120–126; `PhraseLibraryStore.swift:62`); seeder refill after a full delete (:117–119; `StarterLibrary.swift:51,110,120`); Privacy row (:130–132); installing the design/brand icon (:127).

**All 15 "Known gaps" bullets are still true**, verified in code: scrolling grid (`HomeView.swift:255–257`, columns 3/2 at :39); no Get Attention; no typing/editing/Settings/voice choice/backup (no TextField/SettingsView/edit/backup symbols); Personal Voice asked at start (`SpeechService.swift:156,163–166`); empty catalog + two literals; VoiceOver sentences name Get Attention (`AudioSafetyPolicy.swift:86–89`); `OffMainThreadCallbackTests` has one test (:14); audio session never deactivated (`SpeechService.swift:359,367` only `setActive(true)`); announcements untested; `watchForMissedFinish` (`SpeechService.swift:288`) untested (no test references it); seeder refills; fatalError; icon; license; Privacy row.

## (c) Proposed HANDOFF restructure

Per docs/archive/README.md:7–10, first snapshot the whole file to `docs/archive/2026-10-16-before-handoff-restructure/docs/HANDOFF.md` and add the table row (taken from `9362eca`; code change: none). Then:

**`docs/HANDOFF.md` — front page, target ≤150 lines, titles kept where other files cite them**
1. `# Handoff` — the two-line preamble (:1–5) + "**State as of 2026-10-14, commit `9362eca` (PR #11).**"
2. `## What the app does today` (cited by SKILL.md:25) — :13–23, updated.
3. `## Verification` — three dated lines: CI on `main` (`9362eca`: 113 unit cases + website/runner checks, 8 UI tests; Xcode 26.6/iOS 26.5 iPad Pro 13-inch; ~10 min); owner's Mac (2026-10-13: 113 + 8 on Xcode 27.0/iOS 27.0, by an agent; no person has run the app); physical device: none. One line on what no test sees; one line on the UI flake history with a pointer to the log.
4. `## Known gaps` (renamed; AGENTS.md:344 and SKILL.md:88 already use this title) — the 15 bullets, each tagged "(owner decides)" or "(port step N)".
5. `## Next steps, in order` — owner items with status, then agent items.
6. `## Checks that need a real device` (cited by SKILL.md:80) — table unchanged.
7. `## Repository, CI and website status` — ruleset verified date, CodeQL languages, AI Scan, Pages + Effective date, Dependabot; replaces :64–88 and :134–212 (whose settled facts already live in DECISIONS "Reviews, updates and GitHub settings").
8. `## History` — one line pointing to the log.

**`docs/HANDOFF-LOG.md` — appendix (new):** the "Record of changes" table (:261–295) plus one row per later section (:298–474), newest first: Date | Commit(s)/PR | Change | Verified on | Not verified. Keep narrative only where the table cannot hold it (PR #9's verification configurations, PR #11's failure analysis). Rule: each PR adds one row and edits front-page lines in place; nothing is appended to the front page.

Same-PR edits: HANDOFF:70–71 → "README → *Website development*"; `.github/pull_request_template.md:35` → "docs/HANDOFF.md (front page) and docs/HANDOFF-LOG.md (one row)"; AGENTS.md "Where things are" add the log, GETTING_STARTED and NAME_AVAILABILITY; README.md:17/:51/:128/:163 links stay valid.

## (d) Privacy and release-readiness gaps, ranked

1. **No in-app privacy link (App Review 5.1.1(i); AGENTS.md:200–203).** No Settings screen, no `SFSafariViewController` anywhere (grep). Needs a minimal Settings/About screen before step 7 or as part of it.
2. **Policy sentences the app cannot keep yet** (AGENTS.md:192–199: delete or match at release; each deletion moves the Effective date): `site/privacy/index.html:49` typed message persists; `:50` "text size" setting (voice and rate *are* stored — `SpeechService.swift:56,60,84` UserDefaults — text size is not a setting); `:52` and `:105` delete in the app; `:65`, `:107` backups you export (step 2); `:67–68` recorded phrases; `:69–77` caregiver alerts (local-network code = invariant 9; owner decision pending); `:78–79` Siri and Shortcuts; `:111` Get Attention and caregiver alerting (step 1); `:104` "every optional feature above". The summary `:41` and the "never collects" list `:81–87` are true today.
3. **App Store Connect inputs.** Privacy policy URL and support URL: live. Nutrition label implied by `PrivacyInfo.xcprivacy`: **Data Not Collected** (no collected types, tracking false, one required-reason API UserDefaults `CA92.1`), pinned by `AppBundleTests.swift:97–107`; export compliance false pinned (:89–91). Still to prepare: App Review notes for background audio (DECISIONS.md:140–142) and the unexplained Personal Voice system prompt (DECISIONS.md:226–236), age rating/category, screenshots, the Privacy row. If the owner picks an organization account, the policy's "made by the owner's name… 'we' and 'us' mean the owner's name" (`:44`) must match the legal entity.
4. **Code rules the policy depends on, and whether a test pins them.** `cloudKitDatabase: .none` at `PhraseLibraryStore.swift:25` and `:52` — **not pinned** (no test references cloudKit/ModelConfiguration). No iCloud capability: no entitlements file, no `entitlements` in project.yml — not pinned. Keychain: zero references — not pinned (acceptable). Crash messages: the only `fatalError`/`precondition`/`assert` is `PhraseLibraryStore.swift:62` `fatalError("Unable to create any phrase library: \(error)")`, interpolating a SwiftData error, never phrase text — complies with AGENTS.md:187–190. All seven `logger.error` sites interpolate errors only. Suggest a `PrivacyPromisesTests` pinning the container configuration (needs a small seam) and the absence of entitlements.
5. **Effective date** "October 12, 2026" (`:39`) committed and live; last wording change `280889b`; PR #9 left policy content byte-identical (HANDOFF:306–307). README.md:158 rule applies to any future deletion.
6. **Support page for App Review eyes.** "An iPhone and iPad app being built" (`index.html:28`) and "In development for iPhone and iPad." (`:33`, pinned by `test-site.py:81`) must change at release or the support URL contradicts the listing. "This address is not for emergencies." (`:57`) is good. Name and email on both pages (`index.html:57,66`; `privacy:44,99,117,120`) are the authorized ones (AGENTS.md:300–304). No FAQ — thin but sufficient for a contact requirement.
7. Low: "Children" (`:101`) vs age rating (4+, not "Made for Kids"); GDPR text (`:97–99`) fine.

## (e) GitHub facts (verified 2026-10-15)

| Item | Value |
|---|---|
| Pages | enabled, Source = GitHub Actions (`build_type: workflow`), HTTPS enforced; last Publish run 38435645080 success 2026-10-13 17:04 (30 s); live `last-modified` 2026-10-13 17:04:21 GMT; HTML+CSS identical to `site/`; no `<script>`, no external assets (all local 200); 3 external links in the policy (Apple ×2, GitHub) |
| Ruleset "Protect main" | id 24934283, active, ~DEFAULT_BRANCH; deletion + non_fast_forward; PR: 0 approvals, merge commits only, thread resolution required; required checks "Unit tests", "UI tests" (strict off); CodeQL errors / high_or_higher; Copilot review on (push off, drafts off); bypass RepositoryRole admin, PR only → **matches all 8 rows of DECISIONS.md:397–406** |
| CI "Tests" on main | 11 runs (10-10→10-14): **10 success, 1 failure** (`b25331d`, 10-13: attempt 1 UI "simulator not found" exit 70; attempt 2 UI audit timeout −56; Unit green both). Wall-clock 5m45s–10m51s, median ≈9m50s; parallel jobs Unit 8–10 min, UI 8.5–10.5 min; latest `9362eca` Unit 9m48s / UI 8m35s. Main failure rate 1/11 (≈9%), both causes simulator/infra. PR runs: cancellations are concurrency on new pushes; PR #9 head `8dfadd1` needed attempt 2 (audit timeout) |
| Other workflows | CodeQL default setup ≈1 min (actions 17 rules + python 43 rules, 0 results; weekly Tue 13:43 UTC); Copilot review ≈3 min; AI Scan ≈45 s per push |
| Code scanning | default setup `configured`, languages [actions, python] (python added 2026-10-13T17:05:36Z); 0 open alerts; 3 errored swift analyses from 2026-10-10 still listed |
| Dependabot / secrets | alerts enabled, automated security fixes enabled (not paused); 0 Dependabot alerts; 0 secret-scanning alerts; one Dependabot PR (#7) so far |
| PRs / issues | 11 PRs, all merged, 0 open; 0 issues ever; Issues, Discussions, Projects on; Wiki off |
| Branches | origin has only `main`; nothing to delete |
| Metadata | description "[Work in Progress] Giving control to those with ALS. Made for iPad and iPhone." followed by a personal dedication; homepage set; 11 topics (one misspelled: `augmentive-communication`); custom social preview present (1280×640 JPEG, 187,936 B = `site/assets/social-preview.jpg`); license none; 0 stars/forks; created 2026-10-10 |
| Repo size | pack 3.69 MiB; largest blobs: `site/assets/conversation.png` 2,123 KB (removed from tree, stays in history), `design/brand/brickson-app-icon.png` 807 KB, `brickson-mark-transparent.png` 291 KB, `conversation.jpg` 284 KB, `social-preview.jpg` 184 KB; HANDOFF.md/AGENTS.md ≈20 versions each at 25–34 KB |

## Public-repository hygiene (item 4)
- Emails in tracked files: only `the published support address` on the two site pages (authorized). Commit metadata: 11 commits authored with the owner's name and the published support address, 12 with a GitHub noreply address; the owner may prefer the noreply address for future commits.
- Names: "the owner's name" in site pages, README founder note, AGENTS.md:306–308, DECISIONS.md:47, HANDOFF.md:392,422 — all inside the recorded exception. `family.avery.brickson` (project.yml:25) is outside it. "Brick Son" is the Siri alias. No other family/health details; no private owner documents were ever committed (72 paths in all history; the only removed one is `site/assets/conversation.png`).
- Secrets: none (token/key/private-key/password patterns: zero hits; 0 secret-scanning alerts; no `.env`, no entitlements, `DEVELOPMENT_TEAM` empty).
- License: none → all rights reserved. Consequence: outside contributors receive no license and grant nothing explicit (no CLA); App Store distribution is unaffected (owner's copyright). Decide before accepting any outside PR. README:168–171, HANDOFF:128–129 and GitHub agree today.
- `.gitignore`: covers `*.xcodeproj/`, `build/`, `DerivedData/`, `*.xcresult`, `xcuserdata/`, `.swiftpm/`, `.DS_Store`, `.claude/settings.local.json`, `.remember/`, `.agents/`, `.claude/skills/`. `.claude/worktrees/` is ignored only via the per-machine `.git/info/exclude:7` (not committed) → add it. Not ignored: `.env*`, `*.xcarchive`, `*.ipa`, `*.dSYM`, `.vscode/`, `.idea/`, and private owner documents (suggest an ignored `private/` folder convention).
- Large binaries: the 2.1 MB PNG persists in history; rewriting is forbidden (ruleset + AGENTS) and unnecessary at 3.7 MiB total.

## Website (item 7)
Both live pages fetched and diffed against `site/`: identical (index.html, privacy/index.html, style.css); no scripts; no external fonts/assets (`scripts/test-site.py:53–61` pins this; CSS has no `url(`/`@import`); Effective October 12, 2026 live. Support-page concerns listed in (d)6.