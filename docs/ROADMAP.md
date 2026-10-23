# Roadmap

What Brickson builds, in what order, and who is building each part. It is
led by what a person living with ALS needs at each stage of the disease,
not by the order of the reference app's files ([`docs/PORTING.md`](PORTING.md)
stays the checklist of what can be reused).

**Status: decided on 2026-10-21, by default.** The releases and their
order come from the research sweep of 2026-10-15
([`docs/recon/2026-10-15/README.md`](recon/2026-10-15/README.md), sections
5 to 7). The owner asked that day to focus on building and leave the
logistics to the project, so they stand unless the owner objects; the few
questions that are the owner's are in [`docs/DECISIONS.md`](DECISIONS.md),
*Waiting on the owner*. Each pull request that starts, lands or moves an
item edits its row here, in place.

## The goal

In the owner's words (2026-10-21): the best option on the App Store for
people with ALS, in every aspect; a highly polished iPhone and iPad app,
ready for the App Store and meeting or exceeding its optimization (ASO)
requirements; using Apple's capabilities and accessibility features so a
person can live as normally as possible as ALS takes more of their
movement; always built with the Xcode Apple currently recommends; and
interfaces built around the space available and the system's own layouts,
with standard SwiftUI containers, never screens made for one device.

Every item below is judged by AGENTS.md's question: does this make
communication faster, clearer or more reliable for the person, on the
input method they actually use?

## How the order was chosen

- **In the order a person meets the disease.** People usually start on
  touch, with working hands, while speech slows; then lose speech; then
  move to a switch, their head or their eyes. Brickson's promise is that
  the app they learn early is the app they keep.
- **A device before each step depends on the one before.** Nothing has run
  on a real iPhone or iPad yet, and sound, dwell and Snap to Item cannot be
  judged on a simulator.
- **Foundations before screens.** Each feature lands first as plain,
  tested logic with no screen change, then on screen once the layout that
  holds it is settled.

## Step zero: a device (owner)

Before R0's features are judged, Brickson runs on the owner's own iPhone
and iPad and the owner works through the table in
[`docs/HANDOFF.md`](HANDOFF.md), *Checks that need a real device*. This
needs the Team ID in `project.yml` (`DEVELOPMENT_TEAM`, from the personal
membership the owner chose on 2026-10-10; docs/DECISIONS.md, *App identity*) and, before anything is uploaded, the
final bundle identifier.

## R0 "A voice you can rely on"

**For whom:** a person who can still use their hands, and their family.
**Done when:** they could use Brickson every day on their own iPhone and
iPad through TestFlight, and every row of the device-check table that R0
touches has a recorded result.

**Release gate.** No build goes to App Review until: the R0 items below
are complete, including item 11's TestFlight pilot; the device checks they
touch are logged in `docs/log/`; UI tests are green on an iPhone and an
iPad at the default and largest text sizes, light and dark; and the
privacy policy, README and website say only what the build does. A
stand-in Home would likely fail App Review's completeness and minimum
functionality guidelines (2.1 and 4.2). That pilot is the one external
TestFlight group before the gate passes, and it goes out once items 1 to
10 are complete and the rest of the gate holds.

| # | Item | What it delivers | Owner | Status (2026-10-21) |
|---|---|---|---|---|
| 1 | Current toolchain | CI and the Mac build with Apple's newest released Xcode; the minimum iOS decided | Toolchain and iOS version targets | Landed with PR #12 on 2026-10-21: CI builds with Apple's newest released Xcode, and the minimum iOS is 26.0, decided from two rules |
| 2 | Test seams and CI evidence | Launch options for UI tests (in-memory library, fresh settings, text size, appearance), an iPhone run in the UI tests job, result bundles from CI, the String Catalog synced and checked | Test seams and CI evidence | Launch options, UI tests on iPad then iPhone, kept result bundles and the String Catalog check landed with PR #13 on 2026-10-21; since PR #28 (2026-10-22) each CI job keeps its result bundles as a download for 14 days ([`log/2026-10-22-ci-test-results.md`](log/2026-10-22-ci-test-results.md)) |
| 3 | An honest Home on both devices | Words never break, every category visible, the starter library without scrolling, sized from the space available rather than the device model | Phone layout and word fitting, then a new thread for the wells and the engine | Labels that fit themselves, four categories that never scroll sideways, three phone columns and Home's slot plan in the Phone layout pull request; Home's scan order (quick controls first, regions as containers) and Voice Control names in the accessibility first pass ([`log/2026-10-22-home-scan-order-and-names.md`](log/2026-10-22-home-scan-order-and-names.md)); the wells, the rest of item 3's accessibility list, and no scrolling on small phones at large text, are still to build |
| 4 | Get Attention and a sturdier speech engine | A start-only alarm with Stop elsewhere; one owner for the audio session; the code audit's speech fixes (M1, L1, L3, L4) | Speech engine and Get Attention | In progress; on-screen placement builds the wells of DECISIONS.md, "Home's slot plan" |
| 5 | Typing | A composer that does not care which keyboard feeds it, a draft that survives, a probe that measures the real keyboard; then typing on Home under a safety band the keyboard never covers | Typing foundation, then a new thread | Foundation built on 2026-10-21 (`MessageComposer`, `DraftStore`, the keyboard probe; [`log/2026-10-21-typing-foundation.md`](log/2026-10-21-typing-foundation.md)); typing on Home waits for items 3 and 9 and gets a fresh thread |
| 6 | Editing and backup | One validated edit applied in one explicit save, a failure test for every save, an emergency category that cannot be deleted, fixed identities for starter phrases, a versioned backup file | Library editing and backup format | Core in progress; the Library screen waits for item 7 |
| 7 | Settings and first run | Settings root (a large Back, a start-only Get Attention, Family setup), the voice picker and Personal Voice guidance, the in-app Privacy row, family setup including Guided Access and Assistive Access advice | Settings and first run | Built 2026-10-21 ([`log/2026-10-21-settings-and-first-run.md`](log/2026-10-21-settings-and-first-run.md)), from the first-run design and [`onboarding-and-settings.md`](recon/2026-10-15/directions/onboarding-and-settings.md); its choices are recorded in DECISIONS.md as decided defaults. Home's Settings button is built (2026-10-23, [`log/2026-10-23-settings-on-home.md`](log/2026-10-23-settings-on-home.md)). Left for later: Get Attention in Settings (with Stop on Home). Asking for Personal Voice from Settings is built (2026-10-22, [`log/2026-10-22-voice-screen.md`](log/2026-10-22-voice-screen.md)) and switches on after device check D1 |
| 8 | Being heard on calls | Speech added to phone and FaceTime calls through Apple's "Add Audio in Calls" path, if a device check passes | None, on purpose | Held until the owner has a device build (see below) |
| 9 | Screens designed in Figma | Home, typing, alarm, Settings, voice and library screens from Apple's iOS 27 UI kit, positions shown not to move, measured colour tokens | Figma and Claude Design screens | Reference drawings and [specification](work/design-screens.md) recorded; corrections and open placement questions remain ([record](log/2026-10-22-design-reconciliation.md)); item 3's landed slot decisions bind |
| 10 | App Store readiness | Apple's current requirements, store text with no price words, accessibility and privacy labels, screenshots, review notes, the privacy policy's unbuilt sections built or deleted | App Store readiness and ASO | In progress (`docs/APP-STORE.md`, `docs/ASO.md`) |
| 11 | Release chores | The brand icon installed, a license decision, the App Store Connect record (after the name is confirmed), TestFlight to the owner and a small group that includes a person living with ALS and a speech-language pathologist | Owner, with items 9 and 10 | Waiting on decisions |
| 12 | Plan and maintain | This roadmap, the decisions list, the handoff, the way of working ([`docs/SDLC.md`](SDLC.md)) | Roadmap, decisions and repo review | Landed with PR #15; each pull request keeps its own rows current |

**Left out of R0 on purpose:** stage profiles, prediction, recorded
phrases, Siri and Shortcuts, caregiver alerts and the listener display.
Each is better built on R0's foundations than before them.

## R1 "Follows you"

**For whom:** a person moving from touch to a switch, their head or their
eyes. **Done when:** a person can change input method without relearning
where anything is, and the dwell-safety scoring passes for every profile.

- **The profile layout engine.** One pure function from the space
  available, the input profile, the text size and the library's shape to
  a frame for every slot, with standard buttons placed at those frames.
  Profiles (touch, keyboard and Voice Control, switch including
  brain-computer interfaces, head, gaze, and a late-stage profile with
  fewer, larger targets that serves as the map's Yes/No mode and rest
  board) change sizes and spacing only; every control keeps its place. The 2026-10-15 blueprint
  ([`layout-blueprint.md`](recon/2026-10-15/layout-blueprint.md)) is the
  starting design, but it keys some numbers to a table of devices; the
  owner's 2026-10-21 rule asks for layouts from available space instead
  (DECISIONS.md, "Layouts from the space available").
- **Dwell-safety scoring.** Chains of repeated activations scored for every
  state, under both pointer models, with each exception named
  (invariant 10; [`docs/LESSONS.md`](LESSONS.md), "Score chains, not single hops").
- **The phone as a first-class device**, including whether it keeps
  portrait only (iOS 27 and foldable iPhones bring new orientations and
  window shapes; DECISIONS.md, "Orientations").
- **Who chooses the profile**: the family, in Settings; accessibility
  features the system reports may suggest a profile, never switch it.
- **Recorded phrases, first two stages**: playing a recording attached to
  a phrase, and importing recordings a person made elsewhere (Voice Memos
  or a message-banking service), through the playback coordinator built
  with the alarm. No microphone yet.
- **A printable board** that mirrors the screen, for partner-assisted
  scanning when the device is not at hand.

## R2 "Your own words, your own voice"

- **The in-app recorder** for message banking, after device checks show
  recording cannot disturb speech or calls.
- **Prediction and history** as fixed strips whose contents change but
  whose places do not (invariant 8).
- **Siri and Shortcuts** with fixed phrases only ("Emergency in Brickson",
  "Get attention in Brickson"); no phrase words in App Shortcuts, as the
  privacy policy promises.
- **The listener display**: large text turned toward the person listening.
- **Caregiver alerts**, by the owner's decision. The recommended path:
  1.0 makes sound only and the policy's caregiver-alerts section is
  deleted; later a Shortcuts hand-off; a local-network caregiver station
  only behind a recorded exception to invariant 9, after an experiment
  ([`directions/caregiver-alerts.md`](recon/2026-10-15/directions/caregiver-alerts.md)).

## Waiting, not yet in a release

Worth building, each starting with a work file once R2's foundations are
in: a watch app, a start-only Get Attention control for Control Center and
the Action button, an on-device partner view, custom VoiceOver rotors,
pronunciation of names, and keyboard shortcuts
([`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md); docs/DECISIONS.md,
"Accessibility API coverage"). HomeKit tiles are not on this list: they
would control devices beyond the iPhone or iPad, so they wait on the
owner's decision under invariant 9, as caregiver alerts do.

## All the time

- The test infrastructure list in
  [`tests-ci-audit.md`](recon/2026-10-15/tests-ci-audit.md), section 4.2 of
  the synthesis.
- Moving to each new Xcode release when Apple ships it, through a pull
  request (docs/DECISIONS.md, "Build with Apple's current Xcode").
- Localization through the String Catalog, once its sync check is in CI.
- The device-check log: every result recorded with what it was measured on.
- The documents: each pull request edits the handoff's front page in
  place and adds one file to `docs/log/`.

## Never

AGENTS.md invariant 9's hard stops: accounts or login, servers or network
code, cloud sync (for now), analytics, ads or tracking, third-party
packages or SDKs, AI-generated replies, gesture-only controls, and custom
eye, head or switch tracking. Nothing anywhere states a price for
Brickson until the owner decides one (docs/DECISIONS.md, "Price not
decided").

## Repo review, 2026-10-21

The repository was reviewed against the owner's goal for layouts keyed to
devices, App Store and ASO gaps, and the way of working
([`docs/recon/2026-10-21/repo-review.md`](recon/2026-10-21/repo-review.md):
71 findings, each with an owner, not yet checked by a second reviewer).
Each owning piece of work checks its findings before acting. The biggest:

- The layout blueprint reads the screen and a table of devices; the
  engine must take only the window's space (now a rule: AGENTS.md, *Layout
  on every device and window*). *(the layout engine, a new thread)*
- iPhone Duo and other folding or resizable windows are not planned for,
  and App Store submissions will need iPhone Duo screenshots from April
  2027 (App Store Connect release notes, 2026-10-15). *(the layout engine, a new thread; App Store readiness and ASO)*
- Since PR #28 (2026-10-22) each CI job keeps its result bundles for 14
  days, and since PR #31 a cloud agent can read them on Linux (AGENTS.md,
  *Gotchas*), but only by hand: no script yet lists and extracts a
  result's attachments. *(Test seams and CI evidence)*
- No release or TestFlight runbook, and no plan for version and build
  numbers. *(App Store readiness and ASO; Toolchain and iOS version
  targets)*
- The app icon is a placeholder, with no layered Liquid Glass icon.
  *(Release chores, item 11: owner-approved artwork, then Icon Composer on a Mac)*
- Nothing technical stops an agent merging or pushing to `main`; the
  owner's merge is the gate only by rule. *(Project guardrails)*

Accessibility API coverage was checked against Apple's documentation on
2026-10-21: [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md) gives every API
in the map its release and roadmap item.
Apple's design guidelines and Liquid Glass adoption were reviewed on
2026-10-21 (`docs/DESIGN.md`, *Apple's guidelines and Liquid Glass*).

## Held on purpose

- **R0 item 8, calls.** Held since 2026-10-21 until Brickson runs on the
  owner's own iPhone. Before a thread starts it needs three things: the
  microphone usage text the system shows when Brickson asks, a sentence in
  the privacy policy saying what happens to the call's audio, and a device
  check with a real call heard on both ends.
