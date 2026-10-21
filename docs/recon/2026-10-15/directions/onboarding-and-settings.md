# First launch, Settings and voice choice: options memo (direction study "onboarding and Settings")

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Written 2026-10-16. Read-only study: no repository file was edited, nothing was built, nothing was run on a simulator or device. Evidence grades: R = read in the repository; V = Apple documentation or Apple Support text I read (Context7 extracts of developer.apple.com, or fetched support.apple.com / apple.com pages); S = secondary (vendor support pages, press, forum posts, search-result summaries); I = my inference. Sources are paraphrased, not quoted. URLs are in section 10. A copy of this memo is saved outside the repo at a scratch folder on the owner's Mac.

## 0. Bottom line

1. First launch is a collision of four constraints, not a menu (section 2.1). No option satisfies all four. The cheapest way to relax one is a single device experiment, D1, "the deciding experiment": can Personal Voice be switched on after a phrase has already been spoken in the same session, using only a voice-list refresh or a rebuilt synthesizer (the media-services-reset path), with no relaunch?
2. Recommended shape (A4): Home first and always usable; no gate; setup is a place (Settings > Family setup > a short checklist), not a screen anyone must pass. The Personal Voice request comes from a deliberate button on the Voice screen, with its explanation printed on that screen. Until D1 is run, keep today's launch-time request unchanged and make its timing a one-line policy, so either answer is a small change.
3. Voice picker (B3): keep Automatic as the default, add a short explicit list in which Hear and Use are different buttons, make Automatic "sticky" so a person's voice cannot change silently, and detect a revoked Personal Voice instead of trusting a cached voice list.
4. Settings (C): root screen = large Back + start-only Get Attention + one "Family setup" button; configuration one level down; no toggles anywhere; idle time resets to the root, never closes. Text size should be Dynamic Type only, and the privacy policy's "text size" words should go (owner decision). Privacy row: native in-app copy first, web sheet second.
5. Profile (D): the family chooses in Settings and the choice takes effect when Home next appears. Running accessibility states may only suggest, never switch: they are neither necessary nor sufficient (section 5).
6. Smallest first step: a pure `PersonalVoiceGuidance` resolver, a status re-read when the app returns to the foreground, an off-main test for the authorization completion, and the device checks. No screen, no copy and no layout placement are needed (section 8.2).
7. Corrections to earlier text are in section 9. Two matter most: "ten phrases and under a minute" is true only on Apple-Intelligence-capable devices; and an in-context explanation before the Personal Voice prompt conflicts with asking before the first synthesis unless D1 passes.

## 1. What is established, and what the app cannot know

### 1.1 What the code does today (R)

- `SpeechService.init` calls `requestPersonalVoiceAuthorization()` as its last step, and `BricksonApp.init` creates the service, so the request runs at launch before Home is interactive. The completion is `@Sendable`, hops to the main actor, stores `personalVoiceStatus`, and refreshes the voice list. Nothing on screen reads the status. If the system denies the request, nothing is shown (invariants 4 and 5 are met for audio but not for this state).
- Voice choice: `VoiceSelection.select` goes chosen id (if still installed), then the first Personal Voice found (a test pins "own voice first in every language"), then the best-quality non-novelty voice in the app's localization, then lesser fallbacks. `selectedVoiceID == nil` means Automatic. `resolveVoice()` walks candidates until one instantiates. Novelty voices never win Automatic.
- Rate: `speechRate` in UserDefaults, default Apple's default rate, steps of 0.05 (`SpeechRateSteps`), disabled at the ends. `preview(from:)` and `stepRate(_:from:)` speak one fixed English sample ("This is how I will sound.") and absorb a repeat of the same control while its sample plays (`UtteranceSource.preview(VoicePreviewControl)`; controls are slower, faster, previewVoice, voice(id:)). The sample and the rate names are not in the String Catalog yet.
- There is no Settings screen, no first-run state, no `SFSafariViewController`, no use of the Accessibility framework's settings links, and no text-size setting. The privacy policy says the app stores "the voice, speaking speed and text size you chose" (`site/privacy/index.html`, "What stays on your device"); text size is not a setting (docs audit item 2).
- Launch is synchronous: the store opens, seeds, lists voices and asks for Personal Voice inside `App.init` (code audit, launch path).

### 1.2 External facts that decide things

Personal Voice, creation (V unless marked):
- Where: Settings > Accessibility > Personal Voice > Create a Personal Voice. The device needs Face ID, Touch ID or a passcode, and its language must be one Personal Voice supports. Apple's availability page lists English (United States), Mandarin Chinese (China mainland) and Spanish (Mexico).
- A device can hold several Personal Voices. Recording can be paused and resumed; progress is saved. A notification arrives when the voice is ready.
- Apps: Settings > Accessibility > Personal Voice > "Allow Apps to Request to Use" must be on. Authorized AAC apps can speak through the speaker or into calls but cannot capture the audio. "Share Across Devices" keeps an end-to-end-encrypted iCloud copy (needs two-factor authentication) and lets the same Apple Account use the voice on other devices.
- Time: Apple's accessibility page says iOS 26 builds a voice from 10 randomized phrases in under a minute, and allows short three-word phrases if full sentences are hard to read. The iPhone User Guide snippet ties this to iPhone 15 Pro, iPhone 16 and later (S, secondhand); press says it relies on Apple Intelligence; one forum report says an older iPhone still asks for 150 phrases. Otherwise: about 150 phrases, 10 to 20 minutes of reading, then a build of "a few hours to a few days" that needs the device charging and locked (S: AssistiveWare, Tobii Dynavox; reviewers report about 3 to over 24 hours). Apple's own support text mentions overnight processing while charging on Wi-Fi (S, search summary).
- I found nothing about iOS 27 changing Personal Voice.

Personal Voice, API (V unless marked):
- Status values: notDetermined, denied, unsupported, authorized. Apple says the framework also denies the request when the device does not support Personal Voice, so denied can mean "device cannot". `.unsupported` appears on the simulator and non-phone platforms (S, Ben Dodson).
- Apple says personal voices are made available only while the status is authorized (isPersonalVoice trait note). Before authorization Brickson cannot see whether any exist.
- With the master switch off, a request is denied with no question shown (S: forum thread 731532, Dodson). Brickson's own settings page has no Personal Voice entry, so the generic "open app settings" link cannot reach it (S, Dodson).
- `AccessibilitySettings.openSettings(for:)` (iOS 18+, async, throws) opens the Personal Voice > Allow Apps to Request to Use setting through `.personalVoiceAllowAppsToRequestToUse`. Other cases: `.allowAppsToAddAudioToCalls` (18.2), `.assistiveTouch`, `.assistiveTouchDevices`, `.dwellControl` (26), `.captionStyles`. There is no case for Eye Tracking, Switch Control, Head Tracking, Voice Control or voices. `canOpenSettings(for:)` is iOS 26.4 while the app targets 26.0.
- Info.plist key: the Apple pages for the request method and status carry no usage-description key, and DECISIONS says none is needed. A search tool asserted `NSPersonalVoiceUsageDescription` from "general knowledge" with no source. Treat "no key needed" as unverified: look at the system prompt on the first device build.
- Reports (S, weak): a post on iOS 18.0/18.1 betas says speaking before authorization in the same session hides personal voices until relaunch (forum 764814, one post, no replies; the reference app saw the same, unverified in DECISIONS); a Mac post shows "no speech will be generated" when access is missing (757828); a post on iOS 26 betas says a Personal Voice drifted to another language and became unintelligible (792409); another says buffer rendering is unavailable for Personal Voice and background use is unclear (736148).

Facts added by the coordinator's note (each also in the platform audit, [`docs/recon/2026-10-15/apple-platform.md`](../apple-platform.md)): the `openSettings(for:)` cases `.personalVoiceAllowAppsToRequestToUse` (18), `.allowAppsToAddAudioToCalls` (18.2), `.dwellControl` and `.assistiveTouch` (26); `canOpenSettings(for:)` needs iOS 26.4 while the app targets 26.0, so every deep link also needs its path written out and a visible message if `openSettings` throws; the forum report on asking before the first synthesis is constraint C1 below; and `UISupportsFullScreenInAssistiveAccess` lets a family lock the device to Brickson under Assistive Access without the app re-laying out its controls, which makes "lock the device to Brickson" a text step in the setup help (section 4.5), not a layout change.

### 1.3 What Brickson cannot know (and what that does to the design)

- Before permission is granted, "no Personal Voice yet" and "has one, not allowed" look identical.
- `.denied` has at least three causes: the person refused; the master switch is off (no question was shown); the device cannot make or use one. Whether turning the switch on later returns the status to notDetermined (so a new question can be asked) or leaves it denied is unknown (check D2).
- The only precise moment to say "you have no Personal Voice" is authorized with zero personal voices. I do not know that Apple allows authorization before a voice exists (check D2). If it does not, that state never occurs for the people who most need the message, and the only honest wording is conditional ("if you have not made one yet").
- A chosen Personal Voice can disappear silently (access revoked while the app is suspended; voice deleted). The code already falls to the next voice if instantiation fails, but it trusts a cached list; the Mac report suggests an instantiated but unauthorized voice may produce no sound. That would be a silent failure (invariants 4 and 5). See B.
- No public API reports Eye Tracking or Voice Control (Apple engineer reply on Eye Tracking; open forum threads 835302 and 738581 on Voice Control). More in section 5.

## 2. A. First launch

### 2.1 Four constraints that cannot all hold at once

- C1, ask before the first synthesis. Evidence is weak: one unanswered forum post on an iOS 18.0/18.1 beta, the reference app's unverified observation, and silence from Apple. It is cheap to honor, so I treat it as a real constraint until D1 says otherwise.
- C2, do not ask at launch. Apple's HIG says to avoid permission requests at launch unless the app cannot function without the resource, and to ask when people first reach the feature that needs it; the onboarding page says to put the request in onboarding only when the app needs the data before it can work, and otherwise to ask when people first reach the feature. Brickson speaks in any system voice, so Personal Voice is not required (V, via Context7). App Review's wording on respecting permission settings (not manipulating or forcing consent) points the same way (S, third-party capture of the guideline).
- C3, the first screen speaks. Invariant 2: Emergency is visible on Home in every state and never covered. Any full-screen explanation at launch covers Home, and someone on dwell can be the one opening the app (reinstall, new device, an owner who restores a backup).
- C4, setup must not block speaking. If Home appears at once, someone can tap Yes or a phrase before the explanation has been answered, and then C1's quirk applies to that session.
- C5, the owner's goal: explain before asking, in words the family understands.

| Option | C1 ask before first speech | C2 not at launch | C3 Home and Emergency at once | C4 setup does not block | C5 explains first |
|---|---|---|---|---|---|
| A0 today: ask at launch, no words | yes | no | partly (system alert over Home for a moment) | yes | no |
| A1 ask from a Settings button, words beside it | only if D1 passes | yes | yes | yes | yes, if the family visits |
| A2 one explanation screen before Home | yes | partly | no | no | yes |
| A3 explanation as a state of Home (card in the grid area) | only if Yes/No are not tapped first | partly | yes (phrases hidden until Continue) | partly | yes |
| A4 Setup checklist in Settings, deliberate ask, optional first-run line | only if D1 passes | yes | yes | yes | yes, plus a path back |
| A5 full wizard (voice, rate, profile, sample phrase) | as A2 if gating, as A4 if not | as A2 or A4 | as A2 or A4 | as A2 or A4 | yes |

### 2.2 The options

For each: what the person and family get, invariants, cost (agent working days including tests, excluding device checks and review rounds), risks.

A0. Today: ask at launch, no explanation.
- Early stage (speaks, hands work): sees a system question about Personal Voice before knowing what it is. If no voice exists yet, the request is turned down with no question, and nothing says why. Middle and later (family installs): same; a gaze user's resting pointer can land on "Don't Allow" (I), and the only way back is the system path, which the app never names.
- Invariants: 2 met (Home usable after the alert). 4 and 5 not met for this state (status stored, shown nowhere). 9 fine.
- Cost: none. If a purpose string turns out to exist (unverified), adding one sentence is under a day.
- Risks: unexplained prompt; for people without a voice yet it may spend or stick the one-time question (D2); App Review notes must explain it.

A1. Home first; the request comes from a "Use my Personal Voice" button on Settings > Family setup > Voice, with three plain lines above it (TD Talk's flow: Settings > Voice > Manage > Activate > Continue > Allow).
- Early: the person or family reads three lines, taps once, the system asks, it works. A person who never opens Settings stays on a system voice (a safe fallback that loses the early-stage window). Middle and later: the family does it once; the person never meets a prompt.
- Invariants: 1, 2 (Home never covered), 4 and 5 (a visible line for every status), 10 (the ask button sits away from Hear and Use; the system alert follows a deliberate tap).
- Cost: 2 to 4 days once a Voice screen exists (resolver, an authorization seam, tests). Cannot ship before Settings (recon R0 item 7).
- Risks: C1 unless D1 passes; discoverability.

A2. One explanation screen before Home, first launch only ("Brickson can speak in your own Personal Voice"), a standard Continue, then the system question, then Home; a separate "Not now" that never asks.
- Early: clearest explanation, read once. Later stages: on a restored or new device the screen may return; a gaze user alone at first launch faces a gate of two large buttons.
- Invariants: 2 not met while the screen is up (no Emergency, no phrases). 1 met.
- Cost: 3 to 5 days (launch state, a stored flag, a UI-test launch argument, AX5 layout on iPhone and iPad).
- Risks: breaks C3 and C4; HIG treats onboarding as optional and skippable; wasted on people with no voice yet; a single "Continue" with no way out invites the "forced consent" reading.

A3. The explanation as a state of Home: the phrase-grid area shows one card (three short lines, Continue, Not now) while Yes, No, Emergency, the category row, the message row and the status area keep their frames and stay live. Choosing any category, Emergency included, or Not now replaces the card with phrases.
- Same experience as A2, but Emergency, Yes and No work at once; phrases take one extra activation on first launch only.
- Invariants: 2 (Emergency live, not covered), 8 and "controls keep their frames" (must be proven with the existing frames test), 11 (the card must not scroll at AX5, so three lines is the limit). Whether a tile-less first screen offends "every phrase speaks on the first activation" and "position is never a function of time" is arguable; I would not ship it without the owner's reading.
- Cost: 5 to 8 days (new Home state, frames and AX tests on both devices).
- Risks: Yes or No can speak before Continue (C1); a second Home state to keep safe forever.

A4. Setup is a place, not a gate. Settings > Family setup opens a short checklist (Voice, Check the sound, Test Get Attention once it exists, How the screen is reached, Back up). The Personal Voice request belongs to the Voice step. Optionally, on first run only, the message row's empty-state line gains a second sentence pointing to Settings (the row already reserves two lines, so no frame changes).
- Early: a person with working hands can do everything alone; the Voice step carries the bank-it-now guidance. Middle: the family finishes the list in one sitting, in any order. Later: the same list is the re-setup path after a new device, a moved eye tracker or an OS update.
- Invariants: 2 (Home untouched), 3 (the checklist writes only through explicit buttons), 4 and 5, 10 (entry is two levels from Home; leave-the-app buttons only on step screens), 11, 12.
- Cost: 4 to 7 days on top of Settings.
- Risks: discoverability (research: families often get little or no setup help; devices are abandoned when setup defeats them); checklist flags to store and test; C1 unless D1 passes.

A5. Full wizard (voice, speaking rate, profile or input method, a sample phrase).
- Gating fails C3 and C4. Non-gating it is A4 with more steps. The profile step cannot be real before the R1 layout engine, and the other apps' first-run steps (a name, data sharing, sign-in) are things Brickson does not have, so most steps would be empty.
- Cost: 1 to 2 weeks. Risk: length, against what the research says about family training time.

Competitors, for context (S): Proloquo4Text's first run asks to start, a name, a voice and a data-sharing choice, and finds Personal Voice later under its voice settings. Spoken shows only curated voices during onboarding as a temporary choice, asks for Personal Voice access when you first open the app if you have one, and requires an account. TD Talk asks only when you press Activate in its Voice settings. TD Snap asks on first open after a voice exists. In the pages I read, only TD Talk's Activate-then-Continue step puts an app screen before the system question.

### 2.3 Re-asking after a denial: one resolver, one button

`PersonalVoiceGuidance` (pure, tested) chooses what the Voice screen says and the single button it offers. The screen reads the status on appear and on every return to the foreground.

| Status read | Voice-list evidence | Passive line on the Voice screen | The one button |
|---|---|---|---|
| notDetermined | none | Brickson has not asked to use a Personal Voice yet. | "Use my Personal Voice" (calls the request; the system question follows) |
| denied | none | Brickson cannot use a Personal Voice right now. The switch may be off, you may have said no, or this device may not support it. | "Open Personal Voice settings" (`openSettings(for: .personalVoiceAllowAppsToRequestToUse)`); if it throws, show the path as text |
| authorized | one or more | Speaking in your Personal Voice, (name). With two or more: choose which. | "Hear" |
| authorized | none | Allowed, but no Personal Voice was found on this device. It may still be building. | the bank-it-now guidance (2.4) |
| unsupported | none | (nothing) | (nothing) |

Rules: every status has visible text (invariant 5). `openSettings` throws, so the path is always also written out ("Settings > Accessibility > Personal Voice"). `canOpenSettings` needs 26.4, so do not rely on it at a 26.0 target. The button leaves the app: it lives only on the Voice screen, two levels from Home and far from Hear and Use, with a line saying it opens the Settings app. How a gaze or switch user returns is unknown (D3); the family does this step. On a denied-to-authorized change the screen refreshes the voice list and does not speak by itself.

### 2.4 "Bank it now": the time-critical message

When to show it, only on the Voice screen, never on Home, never spoken, no dismiss control (it disappears once a Personal Voice exists):

| Status | Personal Voice found | Device language in Apple's list | Show |
|---|---|---|---|
| authorized | none | yes | the card, precise wording |
| notDetermined or denied | unknown | yes | the card, conditional wording ("if you have not made one yet") |
| any | any | no | nothing (an unsupported language gets no nagging) |
| authorized | one or more | any | nothing, except a one-line Share Across Devices tip |

Facts the copy must get right: the exact path; that Apple builds the voice and Brickson never hears or keeps the recordings (this matches the privacy policy's own sentences); 10 phrases and about a minute only on Apple-Intelligence-capable devices, otherwise about 150 phrases (10 to 20 minutes, can be paused) and a build that takes hours and needs the device charging and locked; the passcode or biometric requirement; and the collision with invariant 12: Brickson keeps the screen awake while visible, so the overnight build needs the device locked with the side button, or Brickson sent to the background (Home Screen) so the screen can lock by itself. Do not state a cost. Do not name vendors. Do not imply prognosis: the ALS Association's own slides list reluctance to give in to the disease among the reasons people refuse devices, so the tone is preparation and choice.

Draft copy for review by a speech-language pathologist and the owner (my wording, not a quotation from anyone):

> Your own voice. Apple can build a voice that sounds like you, on this device. It is easiest while your speech is clear. Brickson never hears or keeps your recordings.
> On newer iPhones and iPads (iOS 26 with Apple Intelligence) you read 10 short phrases and the voice is ready in about a minute. On other supported devices you read about 150 phrases, 10 to 20 minutes, in as many sittings as you like, and the device builds the voice overnight while it is charging and locked. While Brickson is open the screen stays on, so press the side button to lock it, or go to the Home Screen.
> Start in Settings > Accessibility > Personal Voice > Create a Personal Voice. Then turn on Allow Apps to Request to Use and come back here. Turn on Share Across Devices to use the voice on your other iPhone or iPad.
> A speech-language pathologist can help you record your own phrases and look at other ways to save your voice.

What this leaves out on purpose: recorded phrases (message banking; the recorded-phrases study), other voice-banking services (the ALS Association's 2024 webinar suggests doing Apple's and another service for safety; a vendor-neutral page on the website is a better home than the app), and Live Speech (Apple's triple-click type-to-speak, which can use the same voice in any app and into calls). Live Speech belongs in the family-setup text as a second, system-level way to speak, not as a Brickson feature.

Open question the card depends on: does `.personalVoiceAllowAppsToRequestToUse` land on the Personal Voice page that also holds "Create a Personal Voice"? Apple's own two sentences put both on that page, so one button can serve both the re-ask path and this card (D3).

### 2.5 The deciding experiment (D1) and what it decides

On a device that already has a Personal Voice, with Allow Apps to Request to Use on, install a build that does not ask at launch and has one temporary button that does:
1. Tap a phrase (speaks in a system voice).
2. Press the temporary button and allow.
3. Record: does `availableVoicesDidChangeNotification` fire; is the Personal Voice in `speechVoices()`; does a new phrase speak in it?
4. If not, rebuild the synthesizer exactly as the media-services-reset path does (new `AVSpeechSynthesizer`, delegate re-attached) while idle, refresh, speak again.
5. If still not, relaunch and speak again.
Record OS, device, whether it is an Apple-Intelligence device.

| Outcome | Decision |
|---|---|
| Works after a refresh | Ask in context (A1 or A4) is safe. Drop C1. |
| Works after a rebuilt synthesizer | Ask in context, and rebuild on grant when idle (reuse the reset code; defer if a phrase is playing). |
| Only after relaunch | Keep the launch-time request (A0) and add the explanation afterwards on the Voice screen; or ask in context and show "close and reopen Brickson" as text. Either way, record it in DECISIONS. |

D2 to D12 in section 7 are cheap companions run in the same session.

## 3. B. The voice picker

### 3.1 Options

| | B1 Automatic only | B2 Full list with samples (the reference app's picker) | B3 Automatic plus a short list, Hear and Use apart (recommended) |
|---|---|---|---|
| What the family gets | One status line, the current voice's name, Hear, and rate steps. Nothing to get wrong. | Every voice, each row plays a sample and selects. English alone has dozens, many near-duplicates. | Now speaking; Automatic; your Personal Voice(s); the best five other voices for the app's language with quality labels; a "More voices" screen. |
| Early / middle / late | Early: cannot compare or override. Middle and late: stable. | Early: most choice. Family can mis-pick; long scroll. | Early: can compare and keep their own voice. Middle and late: set once, stays. |
| Dwell | No list to hit. | A row both speaks and changes a setting, rows are adjacent: a pointer sweeping rows changes the voice (a setting change nearest to text the person reads). The existing per-control absorption stops a stutter, not a change. | Hear never changes anything; Use is a separate button; the selected row is marked by a check and the Selected trait; choosing the selected row again changes nothing. |
| Cost (days, with tests) | 1 to 2 | 4 to 7 (port `VoicePickerView`: structure kept, geometry retuned) | 3 to 5 after Settings exists |
| Main risk | Two Personal Voices cannot be told apart; a bad Automatic cannot be overridden. | Scrolling; accidental choice. | More states to test; curation rules (which five) need a pinned test. |

Invariants for all three: 1 (standard Buttons), 3 (a voice change is an explicit action on a Settings screen), 5 (every status has text), 6 (colours from Palette, pinned in `PaletteTests`), 10 (below), 11 (not on Home).

### 3.2 What the picker has to get right

a. Automatic can change a person's voice without telling anyone. `select` takes the first Personal Voice in whatever order the system lists them. Apple allows several per device, the API exposes no creation date, and the list order is undocumented (I). A second voice made by a family member, or a Premium voice finishing its download, can change what Automatic means between two launches. A voice is identity. Fix: sticky Automatic. Remember the resolved Personal Voice's id in one new key (for example `automaticVoiceID`), keep using it while it exists, and show a passive line on the Voice screen when it changes. Keep the existing key names `selectedVoiceID` and `speechRate`, and pin them with a test (the code audit found no test for the keys or the rate clamp). A test fails if a second Personal Voice appearing flips Automatic.

b. A revoked or stale Personal Voice must not mean silence. Apple documents that personal voices are available only while authorized; a Mac forum post shows an unauthorized call producing no speech. `resolveVoice` trusts a cached list and falls back only when instantiation returns nil. Fix: re-read the status on foreground (first step); skip a Personal Voice candidate unless the status is authorized; when the chosen voice is a Personal Voice and access is gone, speak with the next-best voice and show a passive line in Settings > Voice. This needs a voice-factory seam (the code audit asks for one) and device check D4, because the simulator cannot show it.

c. Preview and rate controls. Keep `preview` and `stepRate` as they are (repeats of one control are absorbed while its sample plays). Add: Reset to Normal in a different place from Slower and Faster; the rate shown in words ("Normal", "70% of normal"); Slower and Faster disabled at the ends (already coded). Hear speaks and changes nothing; Use applies and plays the sample once. What remains: a lingering look can still step the rate once per sample length until the end of its range; whether a held look re-fires at all is already a device check in HANDOFF.

d. Better system voices. There is no API to download them. The family downloads Enhanced or Premium voices in the system's voice settings (Apple's iPhone guide places voice choice under Settings > Accessibility > Read & Speak on iOS 26; an older Apple article says Enhanced voices exceed 100 MB and want Wi-Fi; the exact menu is a device check). Brickson shows quality labels ("Standard", "Enhanced", "Premium") and, when the best installed voice for the language is Standard, one passive hint with the path. The list refreshes through `availableVoicesDidChangeNotification` with no network code in Brickson.

e. Banked voices from other services. Brickson can speak only in voices the system lists. WWDC23 session notes describe speech-synthesis provider extensions whose voices join the system list; I could not confirm that another app's voice is visible to Brickson (D10). Cloud voices such as those in Predictable need network code and accounts: out under invariant 9.

f. Novelty voices: leave them out of every list in 1.0, with no toggle (AGENTS Gotchas: keep them out of Automatic).

g. Language. Filter system voices by the app's localization (primary subtag, as `select` does). Show Personal Voices regardless, labelled with their language, with a passive line if a Personal Voice's language differs from the app's (I: voices are built per language; I do not know how a mismatch sounds). Keep the pinned test "own voice first in every language". The fixed sample sentence and the rate names must move into the String Catalog before this screen ships.

h. Button names must be unique. Two buttons with the same name already confused Voice Control and the UI tests on Home (DECISIONS, "Home version 0"). Per-row buttons are named with the voice ("Hear Samantha", "Use Samantha"), and a collision test in the style of the reference app's `VoiceControlLabels` covers the list.

## 4. C. Settings for every input method

### 4.1 Skeleton

- Level 0, Settings root (the safe start). Three controls and nothing else, so a resting look finds nothing harmful: a large "Back to Home" (the standard system Back stays; never hide it), Get Attention (start-only, arrives with the alarm; Stop lives somewhere else per the alarm design), and "Family setup". Sizes come from the active profile's floors.
- Level 1, "Family setup" (one screen below): Setup checklist (A4), Voice, Phrases (Back up, Restore, Restore starter phrases; edit mode belongs to the editing study), Reaching the screen (input-method help; later Layout), Calls (later), Privacy, About.
- "A screen below" has two readings: further down the same screen (needs scrolling, which is expensive under dwell and switch input) or one navigation level deeper. I recommend the second: the root stays nearly empty and a resting look finds nothing harmful, and the configuration list is reached by one deliberate activation of "Family setup" instead of by scrolling.
- Level 2: the screens behind those rows. Buttons that leave the app ("Open Personal Voice settings", Dwell Control, AssistiveTouch) exist only here, never on levels 0 or 1.
- Idle: after a stretch without activity Settings returns to level 0 and stops any playing sample; it never closes onto Home (LESSONS, "A timeout never closes a screen onto speaking controls"). The reference app's old value was 90 seconds; use that as a starting point and tune on a device. Activity is recorded from controls, navigation changes and scrolling, never from a screen-wide gesture. A pure `SettingsIdlePolicy` taking `now:` on `ContinuousClock`; tests fail if it dismisses Settings or reads `Date`.

### 4.2 Which settings exist in 1.0

| Setting | Stored as | Notes |
|---|---|---|
| Voice | `selectedVoiceID` (nil = Automatic); new `automaticVoiceID` | section 3 |
| Speaking rate | `speechRate` | Slower, Faster, Reset to Normal |
| Setup progress and the first-run line | a few UserDefaults flags | nothing safety-relevant; losing them is harmless |
| Back up, Restore, Restore starter phrases | actions, not settings | owned by the editing and backup study; every one asks first, Keep takes the asking control's place (invariant 3) |
| Privacy | row | section 4.4 |
| About | version and build, "What Brickson does and does not do", the support site | the does-not list: no call to emergency services (the policy already says it), no recording of your Personal Voice, no network, no accounts, does not set up Eye Tracking, Switch Control or Personal Voice for you |
| Layout (profile) | R1 | not in R0: a row that does nothing is a dead end for App Review and a hazard for dwell |
| Get Attention sound | not in 1.0 | one bundled tone; volume is the system's (observe, never set); a read-only volume line helps the family |
| Text size | none | Dynamic Type only; see the owner decisions |

Deliberately not settings: the screen staying awake (invariant 12; touch users could follow normal Auto-Lock, but DECISIONS leaves that for the profiles, so no switch in 1.0); confirm-before-speak, even as an opt-in (invariant 2; if a removed safety setting ever existed its key would be purged at launch, per LESSONS); dwell time, Snap to Item, calibration and scan speed (the system's, which Brickson can only describe); any ordering by use, recency or prediction of position (invariant 8); accounts, sync, analytics and AI replies (invariant 9); automatic profile switching (section 5); a Settings passcode or hold-to-open (time-based guards are banned; Guided Access is the system's answer); a dark-mode override (follows the system, measured in both).

### 4.3 System components, contrast and dwell

- The reference app measured system components and found a destructive button at 2.71:1, field borders at 1.37:1, placeholder text at 1.72:1, gray headings at 3.28:1, and white on system red at 3.55:1 (LESSONS). A `Form` brings gray section headers and footers, `Toggle`s, pickers and red destructive text.
- Split by reach. Anything the person's pointer can reach in a few activations (the root, Voice) uses large custom rows made of standard Buttons with Palette colours. Deeper family screens start with native `List` or `Form`, are measured in light, dark, Increase Contrast and Reduce Transparency, and are replaced only where a number fails, with the numbers recorded in DECISIONS.
- No `Toggle` anywhere: it turns into its opposite in place (invariant 10). Two-state settings become two selection rows (choosing the chosen one changes nothing) or separate "Turn on" and "Turn off" buttons in different places. No drag-only controls; the rate uses steps.
- Confirmations use an in-app view where Keep takes the asking control's place, not the system alert, whose destructive red failed and whose placement cannot be set.
- If Brickson declares Accessibility Nutrition Labels (VoiceOver, Voice Control, Larger Text, Sufficient Contrast, Dark Interface, Differentiate Without Color Alone, Reduced Motion), Apple's rule as the platform audit reads it is that common tasks including first launch and Settings must work with that feature (S/M). Settings and the checklist therefore need those tests too.

### 4.4 Privacy row: three ways

| | What it is | Gains | Risks |
|---|---|---|---|
| P1 | `SFSafariViewController` straight from the row (what AGENTS.md literally names) | Least code; always the live policy | Its Done button sits top-leading (2017 source; iOS 26 unconfirmed), the default Eye Tracking recalibration corner; one forum post reports a very small hit area inside a SwiftUI sheet; a system component whose contrast I cannot change and must measure (invariant 6); a web page of links is "reading is pointing" territory; expected to show a browser error offline |
| P2 (recommended) | Native in-app copy of the policy as the main path (static bundled text, large Back, no links), plus one clearly labelled button, "Open the web version", that presents the sheet | Works offline; still a link in the app for 5.1.1(i); the corner risk sits behind a deliberate tap; the policy is readable at AX sizes | Two copies to keep equal: add a script or CI check that fails when the bundled text or its Effective date differs from `site/privacy/index.html` (the repo already runs Python site tests); 1 to 3 days |
| P3 | Native copy only, no web link | Simplest, offline | A privacy-policy link is what the guideline asks for (S): likely insufficient |

### 4.5 "Reaching the screen": the rewrite of `CaregiverSetupView`

What the app can and cannot do (V): it cannot turn on or calibrate Eye Tracking, Switch Control, Head Tracking, Voice Control, Guided Access or Assistive Access. It can open the Personal Voice switch, Add Audio in Calls (18.2), Dwell Control, AssistiveTouch and AssistiveTouch Devices (26). Everything else is plain text with the Settings path. Paths to confirm on a device before text ships: Eye Tracking (press and vendors say Settings > Accessibility > Eye Tracking; Apple's own page was not readable), Switch Control, Head Tracking (Apple's iPad guide puts it under Switch Control; a third-party iOS 26 guide lists a separate entry), Dwell Control (Settings > Accessibility > Touch > AssistiveTouch), Guided Access.

Content per method: one line on what it is; where its switch is; what Brickson does (nothing special: standard buttons); the hot-corner warning (top-left recalibration by default); and, for locking the device to Brickson, Guided Access (triple-click, disable areas; Apple's Guided Access also disables emergency features during a session, per the research report) and the Assistive Access full-screen key the platform audit recommends. Do not recommend dwell times or Snap to Item values without evidence: no source I read supports a number, and the HANDOFF device checks cover it. Include Live Speech as a second, system-level way to speak.

### 4.6 Dependencies and ordering

- Get Attention comes first (recon order): Settings opens on it. If Settings is pulled earlier, ship the root with Back and Family setup only, and reserve the slot so the alarm arriving moves nothing.
- Where the Settings button sits on Home is a placement decision for the slot model (layout blueprint): a standard Button labelled Settings, not in a corner, not nearest a speaking tile, same slot in every profile.
- The String Catalog must hold the sample sentence, the rate names and every new string; only the Xcode app fills the catalog (tests audit).
- Settings must exist before A1 or A4 can ship, and before submission anyway (no in-app privacy link today, HANDOFF known gap).
- Settings is checked on an iPhone as well as an iPad, at the default and the largest accessibility text size, light and dark, with Increase Contrast and Reduce Transparency, before it counts as done; CI runs only the iPad today.
- Tests first, each naming the change that makes it fail; every new save path (voice id, flags) gets a failure-injection test per invariant 5; new UserDefaults keys need a test with an injected suite.

## 5. D. Profile selection (touch, switch, head, gaze)

### 5.1 What the system tells an app

| Signal | Reports | Where it misleads |
|---|---|---|
| `UIAccessibility.isSwitchControlRunning` (change notification; SwiftUI environment mirror) | Switch Control is on | Apple's iPad guide configures Head Tracking inside Switch Control, so head pointing and switch scanning set the same flag but want different layouts (large dwell targets versus scan order). Brain-computer interfaces reach iOS as a switch from iOS 26 (research report). |
| `isAssistiveTouchRunning` (change notification) | AssistiveTouch is on | A vendor guide says Eye Tracking switches AssistiveTouch on, so it is true for gaze; it is also true for a touch user with the on-screen menu or a mouse user. I do not know whether every dwell setup sets it. |
| `isVoiceOverRunning`, `isGuidedAccessEnabled` | VoiceOver; Guided Access | not input profiles |
| nothing found | Eye Tracking; Voice Control; the iOS 26 Head Tracking pointer; Full Keyboard Access (not exhaustively checked) | An Apple engineer's reply says there is no supported way to integrate with Eye Tracking and that standard controls need nothing; two open forum threads show no Voice Control flag. |

The states are not necessary (Eye Tracking and Voice Control are invisible) and not sufficient (the two that exist are ambiguous), and their change notifications can arrive mid-session. Reading pointer movement to guess the device would be custom input code, which invariant 1 forbids. That is evidence, not just a rule, for "suggest, never switch".

### 5.2 Options

| | What happens | Person and family | Invariants | Cost | Risks |
|---|---|---|---|---|---|
| D0 | No profile choice in R0; touch sizes only | Nothing to choose; a gaze user cannot use R0 anyway | 8 and 11 trivially | none | none; do not ship a row that does nothing |
| D1 | The family chooses in Settings ("How does the person reach the screen?", four large choices), applied when Home next appears | Predictable; family needs to know to do it, so the setup checklist asks | 8 (positions fixed, sizes change), 10, 11 | profile row S once the R1 layout engine exists | wrong or forgotten choice (default is touch) |
| D2 | Detect running states and switch the layout automatically | Looks effortless | 8 held, 10 broken | S | see 5.3; reject |
| D3 | D1 plus a passive suggestion line on the "Reaching the screen" screen only ("Switch Control is on. Use the Switch layout?" with a start-only button) | Helps families who forget; never touches Home | as D1 | resolver S (pure `ProfileSuggestion(runningStates:current:)`), device check D9 | a suggestion may be wrong; only ever suggest larger, never smaller |
| D4 | A Bigger/Smaller control on Home | Quick | 10 broken: a layout-changing control in the person's path | S | reject |

### 5.3 What the person sees when a layout switches under them

- Tiles and controls grow or shrink around a resting pointer. The control nearest the pointer changes identity, so a speaking or alarming control can end up nearest the spot just activated (invariant 10, "a mode switch never leaves..."). Snap to Item jumps to a different element. If the family toggles AssistiveTouch or a notification fires mid-session, the layout can flap.
- Mistakes are asymmetric: wrongly small is unsafe for gaze, wrongly large is only slow. LESSONS already counts text-size changes, merges and reorders as hazards; a profile change is one.
- The same hazard exists inside Settings if a profile choice re-lays out Settings itself under the pointer. Remedy: record the choice at once but apply it when Home next appears, and let Settings keep the sizes it opened with.
- What the person sees on return: the same arrangement at new sizes. Positions do not move; sizes do. A non-interactive miniature on the profile screen, drawn from the layout engine's own frames, would let a family see it first (optional).

Recommendation D: D1 with the D3 resolver, no profile row until R1.

## 6. Other things that shape these choices

### 6.1 App Review and the store

- A reviewer opens the app on a device with no Personal Voice, on iPad or iPhone. Home must speak at once and every Settings row must work (no dead rows). Review notes: how the Personal Voice question is reached (A0: unsolicited at launch; A1/A4: from a button on the Voice screen), the background-audio demonstration already in DECISIONS, and that Emergency does not call anyone.
- 5.1.1(i): a privacy-policy link inside the app, easily reached (today there is none). 5.1.1 on permission settings: do not manipulate or force consent, and give a path for people who decline; Brickson's path is the system voice, and any pre-prompt screen needs a real "Not now". Quoted only via third-party captures (S); read Apple's guideline page by hand.
- Accessibility Nutrition Labels are voluntary now and expected to become required (S/M); a claim requires common tasks, including first launch and Settings, to work with that feature.
- No medical claims in the copy; the bank-it-now text is informational and attributed to Apple's feature.

### 6.2 Privacy-policy consequences (same pull request as the code, with a new Effective date)

- "Text size you chose" is not true today. Delete the words if text size stays Dynamic Type only.
- Setup flags, the voice id and the rate are settings stored on the device: already covered.
- The Personal Voice paragraphs already match the proposed copy (Apple holds the voice; Brickson receives neither the recordings nor the voice; access can be withdrawn in Settings).
- If the web sheet opens the GitHub-hosted policy, the policy's "This web page" paragraph already describes GitHub's logging. Consider one clause saying the in-app web version loads from there.
- Later: Add Audio in Calls and Siri each need their own sentence (platform audit).

### 6.3 What the research says about families (research report, secondary)

Family members act as the facilitator in 96 percent of cases and get about two hours of training; fewer than half of families receive communication education; 46 percent of US respondents got setup help from a speech-language pathologist; devices end up unused in a corner when setup or calibration defeats people; reviewers asked for head tracking to be off by default and called intrusive alerts annoying; and buried settings are on the research report's design-against list. This supports a short, resumable checklist inside Settings over a long first-run wizard, and no alerts or prompts the person did not ask for.

## 7. Device checks (nothing here has been run)

Record each result in HANDOFF's "Checks that need a real device" with device, OS, settings and date.

| ID | Check | Decides |
|---|---|---|
| D1 | The deciding experiment (section 2.5): speak a phrase, then grant Personal Voice; does the voice appear and speak after refresh, after a rebuilt synthesizer, or only after relaunch? | whether to ask in context (A1/A4) or keep the launch request |
| D2 | Provenance of denied: first launch with the Allow Apps switch off (what status, any question?); then create a voice, turn the switch on, return (status? does a request now ask?); is the switch visible before any voice exists; can authorization be granted with zero voices? Also whether Brickson then needs its own entry switched on in the app list (Dodson says it may appear enabled while the master is off). | the conditional versus precise wording; whether a launch-time request can burn the question |
| D3 | Where `.personalVoiceAllowAppsToRequestToUse` lands (the page that also has Create a Personal Voice?); same for `.dwellControl`, `.assistiveTouch`; and how a switch, dwell or gaze user gets back to Brickson (status-bar back link? app switcher?) | one button for two jobs; where the leave-the-app buttons may sit |
| D4 | Revocation: choose a Personal Voice, switch access off while Brickson is suspended, relaunch; does `speechVoices()` drop it, does `AVSpeechSynthesisVoice(identifier:)` still return it, does speaking give sound, silence or a finish callback? Also delete the voice. | the revoked-voice fallback (3.2b) |
| D5 | Two Personal Voices: is the list order stable across launches; are identifiers stable after relaunch, a restore, and Share Across Devices to a second device? | sticky Automatic (3.2a) |
| D6 | Personal Voice with the device locked or Brickson backgrounded (already in the recon) | the background-audio review note |
| D7 | `SFSafariViewController` on iPad and iPhone, iOS 26: where Done sits and how big its hit area is; contrast in four conditions; offline behaviour; whether links inside navigate away | the Privacy row (P1 versus P2) |
| D8 | Share Across Devices: does the second device need its own Allow Apps switch and its own request from Brickson? | the "make it on the phone now, use it on the gaze iPad later" advice |
| D9 | Log `isSwitchControlRunning`, `isAssistiveTouchRunning`, `isGuidedAccessEnabled`, `isVoiceOverRunning` under Eye Tracking, Head Tracking, Dwell Control, Switch Control (scanning and head), Voice Control, AssistiveTouch with touch, and a mouse; do change notifications fire mid-session? | the suggestion resolver (D3) |
| D10 | Install a banked-voice app that ships a speech-synthesis provider extension, if one exists; does its voice appear in Brickson's list? | whether banked voices are reachable without network code |
| D11 | Create a Personal Voice on an Apple-Intelligence device and on an older supported one: number of phrases, time, whether the build needs lock and charging, whether Brickson open in the foreground blocks it | the exact bank-it-now numbers |
| D12 | Voice download path and size on the installed iOS; does Brickson's list refresh without relaunch? | the "better voices" hint text |

## 8. Recommendation

### 8.1 The package

- A: Home first, no gate. Setup is a checklist in Settings (A4). Ask for Personal Voice from a deliberate button on the Voice screen with the words beside it, once D1 allows; until then keep the launch-time request and make its timing a one-line policy. Add the bank-it-now card and the re-ask resolver to the Voice screen.
- B: B3 with sticky Automatic and a revoked-voice fallback. Novelty voices hidden, language-filtered, quality-labelled.
- C: root with Back, Get Attention and Family setup; no toggles; custom large rows for what a pointer can reach, native rows deeper only where measured; Privacy as P2; Dynamic Type only; idle resets to the root.
- D: the family chooses, applied when Home next appears, suggestions only, row waits for R1.

What each stage gets:

| Stage | First launch | Setup and Settings | Voice |
|---|---|---|---|
| Early: speaks, hands work | Home speaks at once; optional one-line pointer to Settings | Can do the checklist alone | Automatic now; bank-it-now card; Personal Voice chosen when it exists |
| Middle: hands usable | Same | Family finishes the checklist once | Voice and rate chosen and kept |
| Late: switch or head | Family sets it up | Root is large and nearly empty; deep screens are family-only | Unchanged; Automatic does not drift |
| Very late: gaze | Family sets it up | Reached rarely; idle returns to the root | Unchanged; a revoked voice falls back visibly |

### 8.2 Smallest first step that keeps every option open (about 2 to 3 days, no screen, no copy, no layout)

1. `PersonalVoiceGuidance`, a pure `nonisolated` type taking status, Personal Voice count, device-language support and best system quality, and returning the line and the one action in sections 2.3 and 2.4. Tests name their failures: it fails if denied stops offering the Settings action, if authorized with none stops offering the card, if an unsupported language shows the card, if notDetermined offers the Settings link instead of asking.
2. A small authorization seam in `SpeechService` (read status, request) and a re-read of the status plus a voice-list refresh when the scene becomes active. A test with a fake provider that changes between two foregrounds fails if the second read is dropped.
3. A case in `OffMainThreadCallbackTests` that calls the authorization completion from a detached task (an open HANDOFF gap).
4. A `PersonalVoiceAskPolicy` value (`.atLaunch` today) with a test pinning today's behaviour, so D1's answer is a one-line change with its tests.
5. Tests pinning the existing keys `selectedVoiceID` and `speechRate` and the rate clamp (injected UserDefaults suite).
6. Add D1 to D12 to HANDOFF's device table and run D1 to D5 with the first device build (needs the team id; recon step zero).

### 8.3 Decisions only the owner can make

| Decision | Recommended default | Why |
|---|---|---|
| When Brickson asks for Personal Voice | Keep the launch request for now; move to a deliberate Voice-screen button if D1 shows a refresh or rebuilt synthesizer works | HIG favours asking in context; the only evidence for asking first is weak and one experiment settles it |
| Anything at first launch | Nothing that gates. Optional: one extra sentence in the message row's empty state pointing to Settings, first run only | Keeps Emergency and phrases at once; costs no layout |
| Wizard | No wizard; a resumable checklist | Research on family training time; most wizard steps are empty for an app with no accounts |
| Voice picker scope | B3 (Automatic, short list, Hear and Use apart, sticky Automatic, novelty hidden) | Safest for dwell; keeps identity stable |
| Text size | Dynamic Type only; delete "text size" from the policy and bump the Effective date in the Settings pull request | An in-app size control is a layout hazard; the words are untrue today |
| Privacy row | P2: native copy plus a labelled web button | Offline, readable, keeps the Done-corner risk behind a tap; AGENTS.md text would then say so |
| Settings idle reset | Back to the root after 90 seconds, tuned on a device | The reference app's own number, now resetting instead of closing |
| Profile | Family chooses; applies when Home next appears; suggestions only; no row before R1 | Section 5 |
| Screen wake for touch | Unchanged in 1.0 | DECISIONS leaves it for profiles |
| Bank-it-now copy | Review the draft with a speech-language pathologist and the owner; show only for supported device languages; no vendor names, no costs | Tone matters; the language list will change |
| Mention of other banking services | One neutral sentence in the app; a vendor-neutral page on the website | Keeps the app free of endorsements |
| Live Speech and Add Audio in Calls | Live Speech as family-setup text now; a Calls row later with the microphone-injection study | Separate studies own them |
| Guided Access and Assistive Access guidance | Text in the setup help; the Assistive Access full-screen key as its own decision | Platform audit |
| Running the deciding experiment | Yes, on the first device build | Settles A before code is written |

Each adopted default becomes a DECISIONS entry (suggested titles: "Personal Voice is asked from Settings", "Settings structure", "Voice choice") and each changed policy sentence a same-pull-request edit with a new Effective date.

## 9. Corrections and flags for the coordinator

1. [README.md](../README.md), section 3, "Early" row, says iOS 26 needs ten phrases and under a minute. That holds on Apple-Intelligence-capable devices (the iPhone User Guide snippet names iPhone 15 Pro, iPhone 16 and later; secondhand). Other supported devices (Apple's support page says iPhone 12 and later, and newer iPads) still need about 150 phrases and an overnight build. The research report already says "on Apple-Intelligence devices" once; the synthesis dropped it.
2. Recon section 5.3 item 7 ("a short in-context explanation before the Personal Voice prompt") and section 4.4 move 2 ("keep asking before the first synthesis") cannot both hold in one launch sequence while Home must speak at once. Only D1 resolves it (section 2).
3. `docs/DECISIONS.md`, "Personal Voice permission is asked at launch, for now", says no Info.plist key is needed. Apple's pages I could read carry no such key, but one search tool asserted `NSPersonalVoiceUsageDescription` without a source. Treat it as unverified; check the prompt on a device.
4. The privacy policy's "text size you chose" (docs audit item 2) is an owner decision, not a typo fix.
5. AGENTS.md names `SFSafariViewController` for the Privacy row. Its Done button position is a possible hot-corner collision and the Privacy row is a system component to measure; if the owner adopts P2, the AGENTS.md sentence should say native copy plus a sheet (the owner decides edits to AGENTS.md).
6. I did not fetch developer.apple.com directly, as briefed. Apple developer text came through Context7 extracts; support.apple.com and apple.com pages came through fetches. Not read: the body of the iPhone User Guide "Record your Personal Voice" page (navigation only), the ALS Association "FYI: Voice Preservation" page (403) and its "10 Things" PDF (unreadable), Apple's App Review Guidelines (third-party captures only), and any iOS 27 change to Personal Voice (nothing found).

## 10. Sources

Apple, documentation read through Context7 extracts (not fetched directly):
- https://developer.apple.com/documentation/accessibility/accessibilitysettings/opensettings(for:) and .../accessibilitysettings/feature
- https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/requestpersonalvoiceauthorization(completionhandler:)
- https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/personalvoiceauthorizationstatus-swift.type.property
- https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/traits/ispersonalvoice
- https://developer.apple.com/design/human-interface-guidelines/privacy (Requesting permission) and .../onboarding (Additional requests)
- App Review Guidelines (official, not fetched): https://developer.apple.com/app-store/review/guidelines/ ; third-party capture used: https://conductatlas.com/platform/apple/apple-app-store-review-guidelines/apps-must-respect-user-permission-settings/ ; 5.1.1(i) wording via https://www.iubenda.com/en/help/401-privacy-policy-for-ios-macos-apps-apple-app-store-review-guidelines
- Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels (search summary)

Apple, support and marketing pages fetched:
- https://support.apple.com/en-us/104993 (Create a Personal Voice)
- https://www.apple.com/accessibility/features/ (10 phrases, under a minute, three-word phrases, AAC apps)
- https://www.apple.com/ios/feature-availability/ (Personal Voice languages)
- Seen only as search summaries: https://support.apple.com/guide/iphone/record-your-personal-voice-iph51936468d/ios ; https://support.apple.com/en-us/105018 (Live Speech) ; https://support.apple.com/guide/iphone/hear-whats-on-the-screen-or-typed-iph96b214f0/ios ; https://support.apple.com/en-us/111798 ; https://support.apple.com/en-asia/guide/ipad/use-switch-control-ipadab57642f/13.0 (Head Tracking under Switch Control)

Forums, blogs and notes (secondary):
- https://bendodson.com/weblog/2024/04/03/using-your-personal-voice-in-an-ios-app/
- https://wwdcnotes.com/documentation/wwdc23-10033-extend-speech-synthesis-with-personal-and-custom-voices/
- Apple Developer Forums, via search summaries: threads 731532, 757828, 736148, 792409, 835302, 738581, 756628, 766870, 659486; 764814 via the platform audit
- https://9to5mac.com/2026/03/19/ios-26-made-one-of-iphones-wildest-most-unique-features-a-lot-better/
- https://dev.classmethod.jp/articles/wwdc17-customize-done-button/ (Done button side, 2017)
- https://spokenaac.com/blog/iphone-eye-tracking-for-aac/

AAC apps:
- https://www.assistiveware.com/support/proloquo4text/adjust-speech-output/apple-personal-voice ; https://support.ablenetinc.com/speech-app/proloquo4text/get-started/
- https://spokenaac.com/aac-apps-with-personal-voice/ ; https://spokenaac.com/help/can-i-use-apple-personal-voice-in-spoken/ ; https://support.ablenetinc.com/speech-app/spoken/get-started/
- https://us.tobiidynavox.com/blogs/support-articles/how-do-i-use-an-apple-personal-voice-in-td-talk-on-my-td-pilot
- https://apps.apple.com/app/id404445007 (Predictable) ; https://elevenlabs.io/blog/preserving-identity-at-scale-elevenlabs-voices-now-in-predictable

ALS organizations:
- https://teamgleason.org/pals-resource/voice-message-banking/ ; https://teamgleason.org/apple/
- https://www.als.org/sites/default/files/2025-04/Voice%20Preservation%20Handout%202025.pdf ; https://www.als.org/navigating-als/resources/fyi-voice-preservation (search summary only)

In the repository (read): AGENTS.md; docs/DECISIONS.md; docs/PORTING.md; docs/HANDOFF.md; docs/LESSONS.md; site/privacy/index.html; Brickson/Speech/SpeechService.swift, VoiceSelection.swift, SpeechRateSteps.swift, SpokenUtteranceTracker.swift; Brickson/App/BricksonApp.swift; Brickson/Home/HomeView.swift; BricksonTests/VoiceSelectionTests.swift; [README.md](../README.md) and docs/recon/2026-10-15/ ([apple-platform.md](../apple-platform.md), [als-aac-research.md](../als-aac-research.md), [code-audit.md](../code-audit.md), [docs-repo-audit.md](../docs-repo-audit.md)).