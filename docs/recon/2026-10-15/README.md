# Recon sweep, 2026-10-15: where Brickson stands and where it could go

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

**Status: a proposal, not a decision.** Nothing in this file is binding until
the owner moves a choice into `docs/DECISIONS.md`. It was written in one
planning session on the owner's Mac, from a full read of the repository, a
run of the app and its tests on simulators, five reconnaissance reports
and six direction studies by separate agents. The raw reports are in
`docs/recon/2026-10-15/`; this file is the synthesis. Where this file and a
raw report disagree, this file is the considered view and says why.

Nothing was committed. Three small changes discovered on the way were left
in the working tree for the owner to keep or discard (section 9).

---

## 1. The short version

Brickson's foundations are sound. The speech engine survives the silent
switch, interruptions and media-services resets; storage is versioned from
day one; every control is a standard button that speaks on the first
activation; failures show as passive text; every save has a test that makes
it fail; CI runs the suites on every pull request. The code audit found no
verified High-severity defect.

Brickson is not yet an app anyone could rely on. It has no typing, no Get
Attention alarm, no editing, no backup, no Settings and no voice choice, and
nothing has ever run on a real device. The stand-in Home works on an iPad at
the default text size and breaks on an iPhone: "Emergency" hyphenates onto
two lines, two of four categories are hidden behind a sideways scroll, and
the starter library scrolls. At the largest accessibility text size the
phone's Yes, No and Emergency labels are clipped to a bar.

The research is unambiguous about what literate adults with ALS need first:
a text-first app they can learn early and keep as access changes. Typing
with Return-to-speak, a phrase library the family can edit and back up
without an account, a loud Get Attention with a separately placed Stop,
their own voice (Apple's Personal Voice plus their own recordings), use on
phone and FaceTime calls, and then the thing nobody else ships: positions
that never move as the person goes from touch to switch to eyes.

The proposed direction is three releases, with device verification in front
of all of them:

- **R0 "A voice you can rely on"**: everything a person with working hands
  needs daily, on their own iPhone and iPad through TestFlight.
- **R1 "Follows you"**: the profile layout engine (touch, switch, head,
  gaze), the phone as a first-class device, the dwell-safety harness.
- **R2 "Your own words, your own voice"**: recorded phrases, calls, Siri,
  the listener-facing display, and the owner's decision on caregiver alerts.

Section 5 has the detail and the alternatives. Section 7 lists the
decisions only the owner can make, each with a recommended default.

---

## 2. What this sweep did, and what it measured

**Read:** every file in the repository, including the generated project
settings, the tests, the website and the privacy policy.

**Ran, on the owner's Mac (Xcode 27.0, iOS 27.0 simulators; CI uses Xcode
26.6 and iOS 26.5, so these are not the CI configuration):**

- The unit suite: all 13 suites green on an iPad Pro 13-inch (M5) simulator
  created for this session. An `xcodebuild` run leaves the String Catalog
  at zero strings; only the Xcode app fills it (confirmed by the tests
  audit, which also found the command-line tool that can).
- The app on that iPad and on an iPhone 17 simulator, portrait, light and
  dark, at the default text size (Large) and the largest accessibility size
  (AX5). Not covered: landscape, intermediate sizes, Increase Contrast,
  Reduce Transparency, VoiceOver, sound, any input method other than tap.
- One tap flow on the iPad (a phrase speaks; the message row shows it;
  Speaking appears; Again turns on), plus a new UI test proving every
  control keeps exactly its frame across that state change. A first pixel
  comparison had suggested a 3pt shift; it was an artefact of resetting
  the simulator's text size to Medium instead of the default Large. The
  test is the evidence; the screenshots were not.
- A cold-booted simulator showed the app's first frame about 50 seconds
  after launch, the same mechanism behind the first-UI-test timeouts CI
  has seen.

**Delegated:** five reconnaissance reports (code, tests and CI, docs and
repository and privacy, ALS and AAC research, Apple platform APIs), a
layout-engine blueprint, and six direction studies (typing; Get Attention
and the audio session; recorded phrases; editing and backup; onboarding
and Settings; caregiver alerts). Every report separates what it verified
from what it inferred, and cites its sources.

### 2.1 What the simulator showed

| Where | Seen |
|---|---|
| iPad, default size, light | Fits. Phrase tiles 96pt tall, quick controls 64pt, category chips 52pt; the grid uses about half the height; the status area is invisible at the bottom. Works. |
| iPad, AX5, dark | "Emer-gency" hyphenates (rule: words never break). The category row needs a sideways scroll to reach Feelings. Tiles in one row have different heights. |
| iPhone 17, default size (Large), light | "Emer-gency" hyphenates at the default size. The category row clips "Conversation" and hides Feelings. The 8-phrase Basics category scrolls: Hello. and Goodbye. are cut off. |
| iPhone 17, AX5 | The heading breaks mid-word ("Choos / e a"), so do "Again" and "Maybe."; Yes, No and Emergency labels are clipped to a bar; the grid scrolls. Unusable. |
| iPad, after a tap | Message row shows the phrase, Speaking appears, Again turns on, every control keeps its frame (UI test). |

The iPhone findings matter because the briefing calls the phone a
first-class device and CI never runs on one. They are not new rules being
broken by accident: the stand-in Home was never sized for the phone, and
`docs/DECISIONS.md` accepts some of this for the stand-in. What is new is
the measurement, and that the default size on the phone is already past the
breaking point, not only the accessibility sizes.

---

## 3. What people living with ALS need, by stage

Condensed from the research report (`docs/recon/2026-10-15/als-aac-research.md`,
with peer-reviewed and clinical sources). The stages are a planning device,
not a clinical scale; bulbar-onset and limb-onset ALS reach them in a
different order and at different speeds.

| Stage | What the person can still do | How they reach a screen | Communication jobs | What Brickson should offer |
|---|---|---|---|---|
| **Early**: speech slowing (clinicians refer to AAC at 125 words per minute, before intelligibility drops); hands fine | Speak, type, hold a phone | Touch, keyboard, phone | Be understood in noise and on calls; conserve energy; **prepare**: bank a voice and record messages while speech is clear, agree a yes/no signal, learn the app | Personal Voice preference and guidance to create one now (on iOS 26 with an Apple Intelligence device, ten phrases and under a minute; otherwise about 150 phrases and an overnight build); recording of "trademark" phrases in the real voice (the only window to do it); typing with Return-to-speak; editing; backup; calls |
| **Middle**: speech gone; hands usable | Tap, type, hold a stylus | Touch, keyboard | Fast face-to-face conversation; quick interjections; phone and video calls (79% and 85% of AAC users with ALS use them); get attention across the house; the family maintains content | Word and phrase prediction in a fixed strip; history and re-say; quick-fire phrases one activation away; a message row the listener can read; Get Attention with a separate Stop; edit mode; backup; light and dark |
| **Late**: hands weak; head control or a reliable switch movement; maybe non-invasive ventilation | Small, slow movements | Head tracking with dwell, AssistiveTouch, Switch Control scanning | Fewest activations per message; no scrolling; stable positions; call for help; answer yes/no/maybe fast; tolerate fatigue | Stage profiles that change sizes and spacing but never positions (the core promise); scan-friendly grouping with Emergency, Get Attention, Yes and No near the scan origin; dwell-safe placement; a loud local alarm; timeouts that reset screens rather than close them |
| **Very late**: eyes only, or a brain-computer interface; bed-bound; nights | Gaze, sometimes only for part of the day (tracker fatigue is the main barrier, reported by 73% of low users) | Eye Tracking with Dwell and Snap to Item; Switch Control (BCIs appear to iOS as a switch since iOS 26) | Yes, no, maybe, "I don't know", "start over"; pain and body location; position changes; call for help in the dark; keep the partner informed when the tracker fails | A gaze profile whose floors are at least the reference app's (110pt tiles at about 45 cm, which is about 2.7 degrees of visual angle on a 264-ppi iPad; the research's preferred 4 degrees would be about 163pt and fits far fewer windows, see section 5.4); those five answers as tiles; a body and position board in the person's own words; absorbing a repeated dwell on the phrase being spoken; a printable board that mirrors the screen for partner-assisted scanning; a night mode |

Across every stage: the family is the facilitator in 96% of cases and gets
about two hours of training; fewer than half of families receive
communication education; devices are abandoned when setup or calibration
defeats people, when subscriptions or accounts gate speech or backup, and
when layouts move. Voice recognition is an early-stage input only: accuracy
tracks dysarthria. Blinks are unreliable in ALS, so the app must never
assume a gesture; the yes/no signal is chosen per person.

What is table stakes in every serious competitor: free typing with speak
and Return-to-speak; prediction; a phrase bank in categories; quick-fire
interjections; history; a display the partner can read; voice choice
including Personal Voice and a banked voice; Switch Control compatibility;
backup and restore; use on calls; light and dark. Where Brickson can be
better than all of them: position stability across touch, switch, head and
gaze as a design rule; measured dwell safety; no accounts gating speech
(no price is decided); eye-gaze layouts as a first-class profile on an
iPad; the explicit guarantee that Emergency, Get Attention, Yes and No are
one activation away from every state.

---

## 4. What the audits found

### 4.1 Code (ranked; full detail in `code-audit.md`)

No verified High. Three Mediums:

- **A phrase cut off by the system can be recorded as finished**, so no
  "Stopped, Again" appears and VoiceOver hears nothing. The engine treats a
  cut-off correctly only when the synthesizer reports a cancellation; Apple
  forum reports say it sometimes reports a finish instead. The fix is a
  pure rule: decide "cut off" from how much of the sentence was spoken,
  which the engine already tracks word by word. Needs a device check with a
  real incoming call.
- **A library the app cannot read is replaced by the starter phrases with a
  message about saving.** A damaged or newer-format store falls back to an
  in-memory starter library and tells the family "Phrases can't be saved
  right now", when the truth is "your phrases could not be read and were
  not deleted". The obvious family reaction (delete and reinstall) would
  destroy the intact file. The fix is a second issue case with honest copy,
  and a test seam for opening the store.
- **The category row scrolls sideways on every iPhone at the default
  size**, hiding categories with no visible sign. Confirmed on the
  simulator (section 2.1).

Eight Lows worth knowing: a recycled utterance identity can let a stale
callback mis-report the wrong phrase; volume warnings have blind spots
(no refresh when the app returns to the foreground; the volume reading may
not update while the session is inactive); when audio cannot start at all,
the watchdog turns "Audio failed" into a "Stopped, Again" loop; one
notification observer is never removed; the palette test pins the asset
colour, not the tint the tiles actually draw with; a disabled Emergency
control would use the system's dimmed look that failed the audit before
(reachable once categories can be deleted; the fix is to make the
emergency category undeletable, which also settles the re-seeding
question); the spoken "Yes." and the button title "Yes" are separate
catalog keys; Again sits inside the top-right corner margin.

Behaviours with no test that could fail: an interruption naming Again
through the real service; the mixable-session fallback during a call; the
`isPaused` guard in repeat absorption; the watchdog; the stale-voice loop;
the UserDefaults keys and the rate clamp; the absorbed-repeat path; the
persistent-store fallback; `cloudKitDatabase: .none` (a privacy-policy
promise); phrase tie-breaking; the idle-timer wiring; `Text(verbatim:)`
for the person's words; the reserved status slot; most off-main-thread
boundaries; and anything on an iPhone, at any accessibility size, or in
dark mode.

Structural advice before the next features: put a protocol over the
synthesizer and the audio session (the alarm will share both); give the
session one owner and decide the "release after speech" question with the
alarm; build the one tile-action resolver now with today's three cases so
edit mode arrives as one more input; reserve a Stop slot (typed messages
will need it); turn off the main context's autosave before editing so every
save is explicit and failure-injectable; decide phrase provenance (starter
versus the person's own) before version 1 ships, because every later
version migrates from it; plan a launch state that can show a screen while
the store opens.

### 4.2 Tests, scripts and CI (`tests-ci-audit.md`)

Every committed test can fail for the reason it claims, with four weak
spots: the off-main-thread test calls the handler directly rather than
through the real KVO closure; two audio-policy tests restate their inputs;
the speech-service tests build a real synthesizer inside the app process
and share the simulator's persisted store and defaults with the app itself
(harmless today, a trap once Settings and editing persist things).

Infrastructure that upcoming features need and do not have, in order of
leverage:

1. **Launch options for UI tests** (an in-memory seeded store, a fresh
   defaults suite, short timeouts, text size and appearance): the one seam
   that typing, editing and Settings tests all need; without it the first
   editing test that deletes "Hello." breaks every later run.
2. **A protocol over the synthesizer**, injected sleep for the watchdog,
   injected defaults and permission request: pays off the untested watchdog
   and off-main gaps and is needed before the alarm shares the session.
3. **Boot wait when a destination is given**: the script only waits for the
   simulator to finish starting on its default path, so every agent run
   with an explicit destination gets the known flake back.
4. **Result bundles and screenshots uploaded from CI**, and the Xcode
   version pinned in the workflow (the macOS image's default can move to
   Xcode 27 under the project).
5. **A launch helper with text size and appearance**, the accessibility
   audit per state and per size, hittability checks on Yes, No and
   Emergency, and taps on Yes and a category.
6. **An iPhone run as a second step of the existing UI job**, keeping the
   required check names.
7. **The String Catalog**: sync it once with `xcstringstool sync` (Xcode
   27 ships it) and commit, then diff it in CI so a new user-facing string
   without a catalog entry fails the pull request. Today the owner's first
   build in Xcode will produce a surprise diff of 25 entries.
8. Project settings: pin the Xcode version XcodeGen writes so Xcode stops
   offering "recommended settings"; fix the one deprecation warning and
   then treat warnings as errors; turn coverage on for information.
9. The dwell-chain engine can be written in the test target against
   hand-made frames now, before the layout engine exists.

### 4.3 Documentation, repository and privacy (`docs-repo-audit.md`)

The repository is in good order: no secrets, no personal data beyond the
recorded exception, no broken links, the website live and byte-identical
to the committed files, the `main` ruleset matching every row of the
decision record, CI green on 10 of 11 runs on `main` (the one failure was
simulator infrastructure), runs taking 6 to 11 minutes.

Statements that are now stale or wrong, **not corrected in this sweep** so
the owner decides:

- `docs/HANDOFF.md` still opens with "State on 2026-10-10" and "nothing was
  built or run"; later sections record suites passing on the owner's Mac.
  The file has become a 474-line log. A front page of about 150 lines plus
  a separate log is proposed in the docs report, with an archive snapshot
  first.
- CodeQL now scans the Python scripts in `scripts/` as well as the
  workflow files (default setup added Python by itself on 2026-10-13);
  AGENTS.md, README.md, DECISIONS.md and HANDOFF.md all say "workflow files
  only".
- AGENTS.md and the review skill cite a HANDOFF section called "Known gaps";
  the heading is "Known gaps in this first version".
- The Python website test class is named `PaletteTests`, the same name as
  the Swift contrast suite the invariants cite.
- `.github/copilot-instructions.md` states a narrower privacy exception
  than AGENTS.md (it omits the authorised founder note), so Copilot may
  flag the README on any change.
- `.claude/worktrees/` is ignored only by a per-machine exclude file, not
  by `.gitignore`.
- The bundle identifier contains the owner's first name; it is public and
  cannot change after the first App Store upload, so it belongs on the
  owner's decision list.
- README points to a "The website" section that is now "Website
  development".

Owner checklist status (from the HANDOFF next steps): website published
and Pages source set, done; app run on a Mac, done by agents but never by
a person; starter phrases, not reviewed; developer account and team ID,
not set; GitHub settings applied, done; the failed Swift CodeQL
configuration, apparently not deleted.

Privacy and release readiness, ranked: no in-app privacy link yet (App
Review requires one); the policy describes six things the app does not do
yet (a persisting typed message, a text-size setting, deleting in the app,
exported backups, recorded phrases, caregiver alerts, Siri), each of which
a release must build or delete; `cloudKitDatabase: .none` and the absence
of an iCloud entitlement are promises with no test; App Store Connect will
need an age rating, a category decision, review notes for background audio
and the unexplained Personal Voice prompt, and Accessibility Nutrition
Labels (voluntary now, mandatory later); the support page says "in
development" and must change at release.

### 4.4 Apple platform (`apple-platform.md`)

Checked against Apple's documentation (which, it turns out, serves clean
Markdown with availability metadata when `.md` is appended to a page's
path; the briefing says those pages are unreadable shells, and that is
worth correcting). The five highest-payoff moves:

1. **Be heard on phone and FaceTime calls** through iOS 18.2's microphone
   injection ("Add Audio in Calls"): an Apple-supported path built for AAC
   apps, with a usage string, a per-app permission and a system switch the
   person turns on once. The older `mixToTelephonyUplink` is reported not
   to work. Needs a device check with a real call on both ends and a
   sentence in the privacy policy.
2. **Personal Voice done end to end**: keep asking before the first
   synthesis (a forum report now backs the reference app's observation);
   re-check the status when the app returns to the foreground; when
   denied, show a row that opens the exact Settings switch; never pre-render
   Personal Voice to a file (reported unsupported). Device check: lock the
   device mid-sentence in a Personal Voice.
3. **Typing that never hides the call for help**: ignore the keyboard safe
   area so nothing reflows; a single-line field whose Return speaks (a
   multi-line editor never submits); detect a hardware keyboard to pick the
   bar height versus the measured full keyboard.
4. **Let a family lock the device to Brickson safely**: one Info.plist key
   makes Brickson run full screen under Assistive Access with its own
   measured layout; do not adopt the iOS 26 Assistive Access scene, which
   re-lays out controls. Add Guided Access guidance to family setup.
5. **Audio that always comes back**: the interruption notification the
   engine uses is deprecated from iOS 27 in favour of life-cycle
   notifications that cannot get out of sync; decide the mixing policy
   (today's "spoken audio" mode pauses for other apps' prompts by design)
   together with the alarm.

Risks the code should know about: the session is never deactivated while
non-mixable, so a suspended app gets a delayed interruption on resume that
the observer does not distinguish; iOS 26's bordered buttons became
capsules and their fill opacity is undocumented, so the measured palette
should be confirmed on rendered pixels; iOS 27 says orientation is ignored
in resizable environments and all orientations will soon be required,
which collides with the portrait-only phone decision; App Shortcut phrases
can be extracted by Apple for training, so the "no phrase words in
shortcuts" rule needs fixed phrases and no phrase entity in App Shortcuts;
`canOpenSettings` is iOS 26.4 while the target is 26.0.

---

## 5. Proposed direction

### 5.1 The principle behind the order

Build in the order a person meets the disease, and verify on a device
before each step depends on the previous one. The port order in
`docs/PORTING.md` is organised by the reference app's files; it stays
useful as a checklist of what can be reused, but the roadmap should be led
by the person's needs. Every item below names the port step it absorbs.

### 5.2 Step zero: a device, and the checks only a device can answer

Nothing has run on a physical iPhone or iPad. The dwell design rests on
unverified premises about Snap to Item; the audio design on behaviours the
simulator cannot show. Before R0's features are judged, the owner (or a
tester) runs the app on both devices and works through the device-check
table in HANDOFF, extended with the checks the audits added: a cut-off
during a call shows "Stopped, Again"; a Switch Control double-fire does not
stutter; volume changed in the background is reflected; bordered buttons
under Increase Contrast and Reduce Transparency; the screen really never
locks; the launch-time VoiceOver announcement is heard; Personal Voice
keeps speaking after the screen locks.

This needs the owner's team ID in `project.yml` and a decision on the
developer account (section 7). A free account's installs expire after
seven days, which is unacceptable for someone who relies on the app.

### 5.3 R0: "A voice you can rely on" (touch; the owner's own devices)

Goal: a person with working hands, and their family, could use Brickson
every day. Order inside the release, by value and by dependency:

1. **Test seams and launch options** (section 4.2, items 1 to 4). Half a
   day to two days. Everything after this is tested through them.
2. **Fix what the simulator already shows on the phone** (section 2.1):
   words that break, the category row, the scrolling starter library. A
   `WordFit`-style label type (port step 3) and a first pass of fixed
   slots per window class, phone first. This is not the full layout
   engine; it is the stand-in made honest on both devices, with the
   iPhone added to CI.
3. **Get Attention** (port step 1 remainder). The direction study
   (`directions/alarm-and-audio.md`) read the reference app from the
   owner's local clone and measured its tone. Keep the reference's core:
   a start-only Get Attention in the fixed quick-control area, a bundled
   tone looping on the same session speech uses, Stop Alert in a different
   place, speaking never silences the alarm, and the alarm warnings the
   code already models. Fix five things the reference got wrong or never
   checked: a silent alarm could not be restarted (absorb a repeat only
   while the live player confirms it is playing, and add a once-a-second
   health check, the backstop speech already has); a straight port would
   put Stop where Again returns after the alarm stops, which breaks
   invariant 10 (so the message bar gets two fixed slots, Again and a
   harmless Clear, and Stop takes Clear's slot while the alarm sounds, with
   the quick row Yes, No, Get Attention, Emergency so Get Attention sits
   under Again and Emergency under Stop); the tone competes with speech
   (turn the tone down while a phrase speaks, restored on every ending);
   failures are hidden (make the call fallback and private outputs such as
   AirPods and hearing aids visible as "Audio shared" and route warnings
   instead of "Sounding" over a sound nobody else hears); and interruption
   notices are changing (one events adapter feeding speech and the alarm,
   iOS 26 path now, iOS 27 behind an availability check once CI builds with
   Xcode 27). Audio session: one coordinator that speech and the alarm each
   hold a lease on, kept active as today, mode changed from "spoken audio"
   to default so another app's prompt cannot stop the alarm; releasing after
   speech, ducking other apps and AlarmKit deferred until device checks.
   Sound: port the reference tone in the first pull request; before
   release, choose a harmonic-rich replacement that does not sound like a
   smoke alarm (the reference's three-pulse pattern resembles the fire
   evacuation signal) by listening tests, then never change it, so
   families can train Sound Recognition on it. Beyond sound: no flashing
   screen; setup advice for Sound Recognition on a caregiver's iPhone or
   Watch and for baby monitors. The first pull request changes nothing on
   screen: the state machine, the events adapter, the coordinator, the
   player behind a protocol with off-main tests, the tone with a bundle
   test, the mode change pinned by a test. The second lands the placement
   once the owner settles it, with a UI test driven by a silent fake
   player. Fourteen device checks replace HANDOFF's single Get Attention
   row.
4. **Typing**. The research makes this the most-needed capability. The
   direction study (`directions/typing.md`) read the reference app's
   keyboard probes (iPad Pro 13-inch and iPhone 17 Pro simulators, iOS 27,
   full software keyboard) and did two sums that decide the shape. Typing
   lives on Home, not on its own screen: when typing opens, the keyboard
   takes the place of the categories and tiles, and a band at the top that
   the keyboard never reaches holds the message, Again, Emergency, Get
   Attention, Yes, No, Speak, the way back and the audio-warning space.
   Apple's keyboard decides how tall that band can be in every profile,
   because touch users need Apple's keyboard and invariant 8 keeps every
   control's place the same across profiles; so the room Apple's keyboard
   leaves on the worst screen (a 13-inch iPad with Display Zoom set to
   Larger Text, in landscape) is the room every profile gets: one row of
   88pt controls under the message at the default text size, touching the
   keyboard's edge, and not even that at the largest text size. This rules
   out the reference app's right-hand column of quick controls (the
   keyboard covers its lower half) and means Home's audio warnings, at the
   bottom today, must move into the band. The second sum: an in-app
   keyboard cannot fit ten 44pt keys across any iPhone, so a Brickson
   keyboard is an iPad-only option. Recommendation: Apple's keyboard
   everywhere (iOS 26 added a keyboard dwell timer for Eye Tracking and
   fewer steps for switch typing), a fixed row of Brickson word buttons
   wherever the band has room, and a large-key Brickson keyboard for
   pointer and gaze users on big iPads only if device tests show Apple's
   keyboard is too slow or unsafe there. A single-line field whose Return
   speaks; the draft persists as the policy promises. First step, which
   every option needs: a message composer that does not care which
   keyboard feeds it, a draft store whose save can be made to fail in a
   test, and a UI test that measures the keyboard. The band rule must
   reach the layout-engine design before it is built.
5. **Editing** (port steps 2 and 6). The direction study
   (`directions/editing-and-backup.md`) recommends a Library screen under
   Settings, in the family area, and leaving Home's behaviour alone in 1.0:
   a Home edit mode needs the layout engine and the chain-scoring harness
   first, can never touch emergency phrases, and its editor cannot be a
   sheet (a sheet covers Emergency, Yes and No). No PIN or hidden path: for
   someone who can only dwell, a PIN pad is a typing task with no exit;
   placement and Guided Access do the job. Core first, with no screen: a
   pure "library edit" type that validates every change and applies it in
   one explicit save (the main context's autosave turned off at launch and
   pinned by a test), a failure-injection test per kind of change, and a
   SwiftData behaviour test that settles how deletes and failed saves
   behave on iOS 26. The emergency category becomes structurally
   undeletable (exactly one, never empty), which keeps Emergency enabled
   and all but removes the re-seeding question.
6. **Backup and restore** without an account (same study): one JSON file
   with an internal format name and integer version, array order as the
   order, identities kept; export through the share sheet; import only
   through the file picker inside the family area (no registered document
   type in 1.0, so a file arriving by AirDrop cannot raise a question over
   Home); merge only appends and is idempotent; import never renames, trims
   or drops a word; Replace only over a library holding nothing the person
   wrote, or after an automatic safety copy. Fixed identities for the
   starter items, set before any build reaches a person, make merges and
   "restore starter phrases" idempotent.
7. **Settings and first run**. The direction study
   (`directions/onboarding-and-settings.md`) found that first launch is a
   collision of four constraints (the first screen must speak; Personal
   Voice is best asked before the first synthesis; a person deserves an
   explanation before a system prompt; nothing may gate Home), and no
   option satisfies all four. Its recommended shape: Home first and always
   usable, no gate; setup is a place (Settings, then Family setup, a short
   checklist), not a screen anyone must pass; the Personal Voice request
   comes from a deliberate button on the Voice screen with its explanation
   printed there, and that screen says plainly to create a Personal Voice
   now while speech is clear, and to record your own voice today, outside
   Brickson, with Voice Memos or a free message-banking service, keeping the
   originals and naming each file with its words, because Brickson will
   import them (R1). Until one device experiment answers whether
   Personal Voice can be switched on after a phrase has already been spoken
   in the same session (a voice-list refresh or a rebuilt synthesizer, no
   relaunch), keep today's launch-time request and make its timing a
   one-line policy so either answer is a small change. Voice picker:
   Automatic by default and sticky (a person's voice never changes
   silently), a short explicit list where Hear and Use are different
   buttons, and a check for a revoked Personal Voice rather than trust in a
   cached list. Settings root: a large Back, a start-only Get Attention and
   one Family setup button; configuration one level down; no toggles
   anywhere; idle time resets to the root, never closes. Text size stays
   Dynamic Type only, so the policy's "text size" words go. The Privacy row
   shows native in-app copy first, the web page in a sheet second. The
   family chooses the profile in Settings, effective when Home next
   appears; running accessibility features may suggest, never switch.
   Smallest first step, no screen: a pure Personal Voice guidance resolver,
   a status re-read when the app returns to the foreground, an off-main
   test for the authorization completion, and the device checks.
8. **Calls**: microphone injection (section 4.4, move 1), if the device
   check passes; the policy sentence with it.
9. **Release chores**: the brand icon, a license decision, App Store
   Connect inputs, the privacy policy sections built or deleted, the
   support page's "in development" line, TestFlight to the owner and a
   small group that includes at least one person living with ALS and one
   speech-language pathologist.

What R0 deliberately leaves out: profiles, prediction, recordings, Siri,
caregiver alerts, the listener display. Each is better built on R0's
seams than before them.

### 5.4 R1: "Follows you" (profiles)

The core promise: as a person moves from touch to switch to head to eyes,
sizes and spacing change and positions do not. The layout-engine blueprint
(`layout-blueprint.md`) is a full design: one pure function from window,
device, profile, text size, library shape and a measured worst-case
keyboard height to a frame for every slot plus a verdict (fits; scrolls at
the floor for a grown library; window too small; profile does not fit this
device), with no screen-state input, so browse and typing frames are
identical by construction. A custom SwiftUI layout places standard buttons
at those frames. Profiles (touch, keyboard and Voice Control, switch
including the brain-computer-interface path, head, gaze) change sizes and
spacing only; columns and the slot grid depend on window size and a fixed
device table alone. Target floors are expressed as visual angle at a
viewing distance and converted through a points-per-millimetre table keyed
by native pixels (so Display Zoom is handled), with unknown devices given
the largest density of their kind so floors can only err larger. Dwell
rules are pure functions checked by placement: every rest point (the
message text, the status line, hidden cells, corners, the bottom centre)
has a harmless nearest control; Get Attention and Stop Alert are far apart;
a slot keeps its hazard class in every state; nothing sits in a window
corner or under the home indicator. Stop Alert takes a pinned cell at the
end of the category band, directly above Emergency, so its disappearance
leaves the pointer on a harmless control. A dwell-chain engine in the test
target searches reachable states to depth four under both pointer models
and three scan models, and the named exceptions are asserted as an exact
set. Fourteen commits land the engine unused behind the stand-in and swap
Home in one step.

Three numbers the owner must see before any of it is built:

- **The gaze floor.** The briefing's floors (110, 88 and 72pt at about 45
  cm) are about 2.7, 2.2 and 1.8 degrees on a 264-ppi iPad. Earlier text in
  this sweep, and the research report, equated 4 degrees with 110pt; that
  arithmetic assumed an iPad mini's density and was wrong. With the
  briefing's floors, the starter library fits without scrolling on every
  iPad except the mini in landscape. With 4 degrees as the floor (about
  163pt tiles), it fits only on 13-inch iPads in both orientations and on
  11-inch iPads in portrait. Recommended: the briefing's numbers as the
  floor, 4 degrees as the preferred size the engine grows toward when the
  window has room.
- **The smallest phones.** By hand arithmetic, an iPhone SE at touch floors
  is about 27pt short of fitting the starter library without scrolling at
  the default text size, and a zoomed SE is 48pt short; every other
  supported phone has 115 to 140pt to spare. Typing above the keyboard
  fails on SE-class phones too, and on every phone from about the third
  accessibility size. Recommended: SE-class phones are not offered the
  switch profile and use compact floors never below 44pt; on phones at
  accessibility sizes, pin the message block and safety rows and let the
  grid scroll as a named exception.
- **Gaze and head on phones** are not offered: a gaze layout on an iPhone
  17 would need about 1258pt of height against 874.

The blueprint explains the simulator findings structurally (three equal
quick controls sharing 370pt cannot hold "Emergency" at the title size; the
category row has no fixed capacity; two 96pt columns cannot hold eight
phrases) and answers each with a slot, a label-fitting type that drops the
icon before shrinking and never goes below the default size, and a named
test. One limit: a mid-word break is invisible to UI tests, because the
accessibility label stays "Emergency" whatever is drawn, so a person must
look at a screenshot and record it.

R1 also decides who chooses the profile (the family in Settings, stored per
device, defaulting to the strictest profile the device offers so a person
who can only use their eyes can operate it on first launch; running
accessibility features may suggest, never switch), whether the phone
returns to landscape (iOS 27 may force the question), the minimum window
size on iPad, the viewing distances per profile, which iPad the reference
numbers were tuned on, and the printable board that mirrors the screen for
partner-assisted scanning.

The typing study (section 5.3, step 4) adds one rule the blueprint must
absorb before anything is built: the band that holds the message, the
safety controls, Speak, the way back and the audio warnings is sized by
the room Apple's keyboard leaves on the worst screen, a zoomed 13-inch iPad
in landscape, and the warnings move up from the bottom into it. The
blueprint's regions already put the safety row and the status line above
its keyboard line, so the two agree on shape; the numbers must be measured.

R1 also carries the first two stages of recorded phrases (section 5.5):
playing a recording attached to a phrase, and importing files a person
made elsewhere, through the playback coordinator built with the alarm and
a backup manifest that lists files. Nothing about the microphone yet.

### 5.5 R2: "Your own words, your own voice"

- **The in-app recorder** for recorded phrases (message banking), the last
  of three stages the direction study (`directions/recorded-phrases.md`)
  lays out. The study's central point is that the window to record is per
  person, not per release, and people can bank today with free tools
  (Apple's Voice Memos, the free myMessageBanking service) and bring the
  files later. So the guidance ships in R0 (section 5.3, step 7), playback
  of imported recordings ships in R1, and only the microphone, the one part
  that can hurt speech (audio-session category changes, phone calls,
  silent takes), waits for device checks. A recorded phrase plays through
  the same session with the same repeat absorption and interruption
  recovery as speech, and the words are always the fallback. The code that
  matters most is not recording: the speech service must become one
  playback coordinator, because Again re-synthesizes the last text (it
  would say a recorded phrase in the synthetic voice), the repeat window is
  refreshed only by word callbacks, and the audio player's finish callback
  is not called on interruption. That refactor is needed by Get Attention
  anyway, so it is built with the alarm. No schema version 2 until the
  feature that reads it ships. Proxy recordings (a relative's voice) are
  allowed and labelled. A separate area for long legacy messages only if
  families ask.
- **Prediction and history** as fixed strips whose contents change, scored
  for dwell safety like any mode switch.
- **Siri and Shortcuts** with fixed phrases only ("Emergency in Brickson",
  "Get attention in Brickson") as background intents, no phrase entity in
  App Shortcuts, and the policy's Siri section reconciled with the rule.
- **The listener-facing display**: large text turned toward the partner.
- **Caregiver alerts**: the owner's decision (section 7). The direction
  study (`directions/caregiver-alerts.md`) is clear. Sound alone helps only
  someone near, awake and listening. iOS has no background mode for
  local-network messages, so a caregiver's locked or pocketed phone cannot
  receive the local-network alert the policy describes; what is documented
  to work is a caregiver station, a spare device with Brickson open in
  front, plugged in. A Shortcuts hand-off (a "Start Get Attention" App
  Intent that the family chains to a text or call, with Emergency Bypass on
  the caregiver's phone) needs no network code in Brickson and reaches a
  caregiver away from home, but starts from a different control, cannot be
  seen to fail by Brickson, and a resting dwell on it could text repeatedly.
  Pocket delivery would need Apple-granted entitlements (Local Push,
  Critical Alerts). An Apple Watch app cannot receive the traffic. The
  recommendation: 1.0 is sound only, with the policy section and its
  closing sentence deleted and a family guide to outside call systems;
  later the Shortcuts hand-off, then the station only behind a recorded,
  narrow exception to invariant 9 and only after a throwaway two-device
  experiment outside the repository. The memo drafts that exception's
  wording and the heartbeat, acknowledgment and required-test-alert design
  that would make a failed alert visible.

### 5.6 Continuous

The test infrastructure list (section 4.2), the HANDOFF restructure, the
String Catalog, the documentation corrections (section 4.3), CI on both
device families, and a device-check log that records what each result was
measured on.

---

## 6. Alternatives considered

- **Port the reference app in file order** (the current PORTING plan). It
  would reach the same features, but it puts the layout engine before
  typing and editing, which the research ranks lower, and it never forces a
  device check. Rejected as the primary order; kept as the reuse checklist.
- **Profiles first, because they are the differentiator.** Tempting, but a
  layout engine judged on a stand-in with no typing, no alarm and no
  editing would be re-cut three times. R0's features define the slots the
  engine must hold.
- **Skip the phone until the engine exists.** The phone is where early-stage
  people live, and it is already broken at the default size. A cheap fixed
  slot pass now avoids shipping a phone layout that hides categories.
- **Build an in-app gaze keyboard in R0.** Expensive and unverified; the
  system keyboard with the right layout guarantees is the smallest step
  that keeps the option open. The typing study details the trade-off.
- **Adopt the iOS 26 Assistive Access scene.** It would re-lay out controls
  and break the position promise; the full-screen key gets the benefit
  without the cost.

---

## 7. Decisions only the owner can make (each with a recommended default)

| Decision | Recommended default | Why |
|---|---|---|
| Developer account: personal or organisation; set the team ID | A paid personal account now; the organisation question can wait | Free installs expire in seven days; an organisation needs a legal entity and changes the policy's "we" |
| Bundle identifier `family.avery.brickson` | Decide before the first upload; it is public and permanent | It carries the owner's first name, outside the recorded exception |
| License | Decide before accepting outside contributions | Today all rights are reserved; contributors grant nothing |
| Price | No price is decided; keep every text silent on it | Research: subscriptions gating speech are the most resented thing in the category |
| Caregiver alerts | 1.0: sound only, policy section deleted; later the Shortcuts hand-off; a local-network caregiver station only behind a recorded exception, after a two-device experiment; no pocket delivery promised; no Watch app | Network code is a hard stop; a locked phone cannot receive local-network alerts; a silently failing alert is worse than none |
| Audio session release after speech | Keep it active in 1.0 behind a lease coordinator, so switching later changes one type; revisit with device data | Releasing while the alarm plays would silently kill it; activation before every phrase adds delay |
| Audio session mode | Change "spoken audio" to default, pinned by a test, checked on a device | Apple documents spoken-audio mode as pausing for other apps' spoken prompts |
| Get Attention and Stop Alert on Home v0 | The reference shape: Again and a harmless Clear as fixed message-bar slots, Stop in Clear's slot while sounding, quick row Yes, No, Get Attention, Emergency; keep Again while the alarm sounds | A straight port leaves Stop where Again returns, which breaks invariant 10 |
| Speaking while the alarm sounds | Turn the tone down during a phrase, restored on every ending | Speech and a 1 kHz tone compete; silencing the alarm for speech is forbidden |
| Output changes while the alarm sounds | Carry on through the speaker when a Bluetooth device disappears; carry on and warn when AirPods connect; record the reading of "never auto-resume into a changed route" | Sound in the room beats silence; the reference stopped instead |
| Alarm restarting by itself after a call or Siri | No: "Alert stopped" shows and one activation restarts it | Invariant 4 names a reachable control to retry |
| The tone | Port the reference tone now; choose a harmonic-rich release tone by listening test; one tone, no choice, never changed after release; constant level; no time limit | Families may train Sound Recognition on it; an unanswered call keeps calling |
| Re-seeding an emptied library | Make the emergency category structurally undeletable (exactly one, never empty); keep "no categories means seed"; add an append-only repair and "Restore starter phrases" in Settings; fixed identities for starter items | An empty store can then only mean first launch or storage loss |
| Phone landscape | Revisit in R1 with the slot layout; iOS 27 may require it | Portrait-only was a stand-in decision |
| Who picks the profile | The family in Settings; running accessibility features suggest, never switch | A silent size change under a resting gaze is a hazard |
| Where editing lives, and a caregiver lock | A Library screen under Settings in 1.0, Home edit mode later and only for touch; no PIN, placement plus Guided Access | A PIN pad is a typing task with no exit for someone who can only dwell |
| Replace on import versus "nothing deletes a person's words" | Replace freely over a library holding nothing the person wrote; otherwise only after an automatic safety copy; record which reading of invariant 7 is meant | Invariants 3 and 7 pull apart here |
| Personal Voice request timing | Keep the launch-time request until the device experiment shows whether it can come later in the same session | A wrong guess hides the person's own voice until relaunch |
| Text size as a setting | None; Dynamic Type only, and remove "text size" from the policy | One fewer thing to get wrong under dwell |
| Gaze floor | The briefing's 110/88/72pt as the floor; 4 degrees (about 163pt) as the preferred size the engine grows toward | A 4-degree floor fits only 13-inch iPads in both orientations |
| Viewing distances per profile | Touch 350 mm, head 500 mm, gaze 450 mm (Apple says about a foot and a half for Eye Tracking) | The floors in points follow from these |
| SE-class phones | Not offered the switch profile; compact floors never below 44pt | They are about 27pt short of fitting the starter library at touch floors |
| Gaze and head on phones | Not offered | An iPhone 17 would need about 1258pt of height |
| Phones at accessibility text sizes | Pin the message block and safety rows; let the grid scroll as a named exception | Typing above the keyboard fails from about the third accessibility size |
| Stop Alert placement | The pinned cell at the end of the category band, above Emergency | Far from Get Attention; its disappearance leaves the pointer on a harmless control |
| Typing: system keyboard first | Yes: Apple's keyboard everywhere, typing on Home under a top safety band, a fixed word-button row where there is room; a Brickson keyboard only for big iPads and only after device tests | A Brickson keyboard cannot fit ten 44pt keys on any iPhone; the band's height is set by Apple's keyboard on the worst screen |
| Starter phrases | Review the near-duplicates and "Please move me." with an SLP | Open since the first pull request |
| App icon | Install the brand "B" mark | The placeholder is still the icon |
| App Store category | Utilities or Education, not Medical | Medical invites diagnostic scrutiny the app does not warrant |
| Recorded phrases by a proxy voice | Allow, and show whose voice plays | Clinicians endorse proxy banking |
| Recorded phrases: build, and in what order | Yes, staged: guidance now, playback and import in R1, the in-app recorder in R2 after device checks | The window to record is per person, not per release |
| Backup container once recordings exist | A folder of plain files plus a versioned manifest, no zip | Cheap to decide now, expensive to change later |
| Emergency tiles playing recordings | Yes, once loudness parity with speech is measured on a device; the words are always the fallback | A quiet recording of "I can't breathe" is worse than the synthetic voice |

---

## 8. Questions for people with ALS, caregivers and speech-language pathologists

From the research report; phrased so the owner could ask them.

1. When you are tired, do you want fewer, bigger phrases on the Home screen,
   or more phrases behind one extra activation? How many per screen at most?
2. Which five phrases do you use most by day, and which five at night?
3. Which yes/no/maybe signals do you use, and what else belongs on that
   board ("I don't know", "start over", "something's wrong")?
4. For Get Attention: what sound, how loud, for how long, and who should be
   able to stop it? Is a sound that continues until stopped reassuring or
   frightening?
5. Do you want a body-location and pain board, in your own words? What about
   position changes (turn me, lift my head, suction, ventilator)?
6. Would a tile play your recording when one exists and fall back to the
   synthetic voice otherwise, or should they stay visibly separate?
7. Who edits the phrases, how often, on whose device? Would a printed copy
   of the screen help in the bathroom, the car, the emergency room?
8. When the eye tracker fails (light, dry eyes, medication), what do you
   fall back to, and how long before you give up for the day?
9. On calls: what breaks today?
10. How much warning do you want before sizes change for a new profile, and
    should the family or the person make the switch?
11. For SLPs: which milestones time the move from touch to head or switch to
    gaze, and what dwell times do your clients settle on?
12. For SLPs: what must a starter library contain, and never contain?

The typing, recorded-phrases and editing studies each end with their own
short list of questions for the same people (how much a person would type
rather than choose a phrase at each stage; whether to keep the familiar
keyboard or learn one made for eyes or a switch; exact letters or
suggestions to check; which ten utterances to record first; whether a tile
should play a recording with the spoken words as fallback or stay visibly
separate; who edits and whether a printed board helps).

---

## 9. Changes left in the working tree (uncommitted)

1. `scripts/test.sh`: the default simulator is chosen by device type, not
   by name. On this Mac the only iPad simulator had been renamed, and the
   script found nothing. The tests audit proposes a fuller version (an
   iPhone family option, a boot wait when a destination is given, and
   printing the chosen device) that would replace this one.
2. `BricksonUITests/LaunchTests.swift`: a test that every control keeps its
   exact frame when a phrase speaks (passes; 8.5 seconds on the simulator).
3. `AGENTS.md`, Gotchas: `simctl ui content_size` changes text size live;
   the default is Large, not Medium; measure frames with a UI test, not by
   comparing screenshots.
4. This file and `docs/recon/2026-10-15/` (the five reconnaissance
   reports, the layout blueprint, six direction memos and the simulator
   findings, about 590 KB), untracked. The owner decides whether they are
   committed, trimmed or kept out of the repository.

Discovered but not applied, for the owner to decide: the documentation
corrections in section 4.3; the Apple documentation Markdown mirror
(section 4.4); the deprecation warning in `PaletteTests`; the leaked
observer in the speech service.

---

## 10. What this sweep could not establish

- Anything about sound, dwell, Snap to Item, Switch Control or Eye Tracking
  behaviour: simulator only.
- Landscape and iPad multitasking windows: not measured.
- The thread Apple's synthesizer delegate uses, whether Personal Voice keeps
  speaking in the background, whether the cut-off flavour is a finish or a
  cancellation on iOS 26, and whether microphone injection works with the
  current session category: device checks, listed in section 5.2.
- Most of the reference app's own documents. The repository is private,
  but a clone of it sits on the owner's Mac at
  the cited commit; the alarm study read it (reference only, never pushed
  to), the other studies did not know it was there. Its decisions D24 and
  D25, which `docs/PORTING.md` says to build in step 6, were not read in
  this sweep and should be pasted into the editing design before screens
  are drawn.
