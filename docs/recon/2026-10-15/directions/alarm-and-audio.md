# Get Attention and the shared audio session: options memo

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Planning only. I changed, built and ran nothing in the worktree. Another agent's uncommitted edits to AGENTS.md, `LaunchTests.swift` and `scripts/test.sh` were left alone.

Evidence:
- Brickson's docs and code at `9362eca`.
- The reference app, FamilyVoice. Its repository (`MiddleAgedBanana/ALS-app`) is private; I read it from the owner's local clone at `6a22c1a`.
- Apple's documentation, read through Context7 (`/websites/developer_apple_avfaudio`, `/websites/developer_apple_alarmkit`). No developer.apple.com page was fetched directly.
- About 15 web searches.
- An offline analysis of the reference tone file.

None of this is device evidence. Anything I could not confirm is marked "unverified, device check". The Apple platform audit's two facts are weighed in section 6.

## 1. Summary

**Keep the reference app's core design:**
- a start-only Get Attention;
- a bundled tone that loops on the `.playback` session speech already uses;
- Stop Alert in a different place;
- "speaking never silences the alarm";
- the alarm warnings Brickson already models (`AttentionAlertState`, "Alert failed", "Alert stopped").

**Fix five things the reference got wrong or never checked:**
1. **A silent alarm could not be restarted.** Treat a repeat as "already sounding" only while the live player confirms it is playing, and add a once-a-second health check.
2. **Stop needs a harmless resting occupant.** Never put Stop where Again (or anything else that speaks) comes back after the alarm stops. Brickson's Home has no Clear, so a straight port would break invariant 10.
3. **Speech competes with the tone.** Turn the tone down while a phrase speaks.
4. **Some failures are hidden.** Make the call fallback and private outputs (AirPods, hearing aids) visible, instead of showing "Sounding" over a sound nobody else hears.
5. **Interruption notices are changing.** Feed iOS 26's and iOS 27's interruption notices into one stream of events.

**Audio session:**
- One coordinator that speech and the alarm each hold a claim on (a "lease").
- Keep the session active, as today.
- Change the mode from `.spokenAudio` to `.default`.
- Defer three things until device checks: releasing the session after speech, ducking other apps, and AlarmKit.

**Sound:**
- Port the reference tone in the first pull request.
- Before release, choose a harmonic-rich replacement that doesn't sound like a smoke alarm, by listening tests. Then never change it.

**Beyond sound:**
- No flashing screen.
- Setup advice for Sound Recognition on the caregiver's iPhone or Watch, and for baby monitors.
- Caregiver alerts (a hard stop today) plug into the alarm's state machine later.

## 2. Where things stand

### Brickson today

**`SpeechService`:**
- It sets `.playback` with mode `.spokenAudio` at launch (`configurePlaybackAudioSession`).
- It activates the session before every utterance (`ensurePlaybackAudioSession`) and never deactivates it.
- If activation is refused, during a call for example, it tries again with `.mixWithOthers`. The method returns nothing, so no caller can tell the fallback happened.

**Interruptions and resets:**
- `AudioSessionInterruptionObserver` passes on only the "began" event. Speech then stops and records a cut-off phrase.
- After a media-services reset, `SpeechService` rebuilds the synthesizer and the session configuration. `AudioSafetyMonitor.audioSessionHealthy` stays false until the next activation succeeds.

**`AudioSafetyMonitor`:**
- It watches the volume, and media-services loss and reset.
- A route change only refreshes the volume. Nothing checks where the sound is going.

**`AudioSafetyPolicy` already models the alarm:**
- `AttentionAlertState` has four states: idle, playing, failedToStart, stoppedUnexpectedly.
- Two warnings, `HomeAudioIssue.attentionAlertFailed` ("Alert failed") and `.attentionAlertStopped` ("Alert stopped"), outrank every other warning.
- `AudioAnnouncementPolicy.attentionIssueToAnnounce` gives each its VoiceOver announcement.
- Home's `StatusArea` hard-codes the alarm as `.idle` and posts no alarm announcements yet.

**Background audio:** `UIBackgroundModes` includes `audio`, pinned by `AppBundleTests.speechCanPlayInTheBackground`.

### The reference app: what step 1 would port

**`AttentionAlertPlayer`:**
- An `AVAudioPlayer` loops `AttentionTone.wav` forever, at player volume 1, behind a small `AttentionTonePlayback` protocol.
- `start()` does nothing while the player's own stored state says `.playing`.
- These stop it with `.stoppedUnexpectedly`:
  - an interruption;
  - loss of the old output (`.oldDeviceUnavailable`);
  - loss or reset of media services.
- A generation counter ignores late callbacks from a discarded player.
- `failureSequence` drives the announcements.
- Its observers hard-code `AVAudioSession.sharedInstance()`.

**Placement** (`HomeChromePolicy`, `MessageBarAction`, `QuickControl.order`):
- Stop Alert takes the message row's trailing slot, whose usual occupant is Clear.
- While the alarm sounds, that slot shows only Stop Alert, and Again's slot is empty.
- In portrait, Get Attention sits under Again's empty slot, so a look drifting up from "Sounding" does not land on Stop.
- Get Attention's visible title changes to "Sounding". Its accessibility label stays "Get Attention", with the value "Sounding".
- The control is black text on attention orange, about 9.5:1.

**Speech during the alarm:** speaking never stops the alarm (`HomeView.speakPhrase`); the two sounds simply play together.

**Settings:**
- Settings had its own start-only Get Attention.
- Stop was only on Home.
- Settings' idle reset waited while the alarm sounded.
- The owner approved an exception there: Settings' Get Attention may be the nearest control after Settings is opened by mistake.

**Never checked on a device:**
- hearing the tone from the next room;
- Bluetooth outputs;
- understanding speech over the alarm;
- with the alarm sounding, a family member tapping Back to Talking while the person's look rests on Settings' Get Attention, which opens Home with Stop Alert under that look.

### The tone, measured offline

| Property | Value |
|---|---|
| Format | 16-bit mono, 44.1 kHz |
| Loop length | 1.77 s |
| Pattern | three 360 ms bursts 80 ms apart, then 530 ms of silence |
| Each burst | 180 ms near 1000 Hz, then 180 ms near 1300 Hz |
| Overtones | almost pure sine waves; none within 30 dB |
| Peak level | −1.4 dBFS |
| Average (RMS) level | −6.7 dBFS |
| Clipping | none |
| Loop seam | starts and ends on silence, so it loops cleanly |

## 3. What the design must satisfy

**Invariants:**
- **2:** Emergency is always visible, and every phrase speaks on the first activation, even while the alarm sounds.
- **4:** the alarm uses `.playback`. It survives interruptions, route changes and resets. Failures show as passive text in reserved space. It never auto-resumes into a changed route. The app never sets system volume.
- **5:** no silent failures.
- **6:** contrast is measured.
- **9:** no network code.
- **10:**
  - start and stop live in different places;
  - a mode switch never leaves a speaking or alarming control nearest the spot just activated;
  - Get Attention is one activation from every Home state, including while typing.
- **11:** no scrolling on Home for the starter library.
- **12:** the screen never locks.

**Design rules:**
- "An alarm stops only from a separate, differently placed control."
- Family controls stay out of the person's path, and Settings opens with a start-only Get Attention.
- Typing never hides the call for help.
- Controls keep their frames.
- Hazards are fixed by placement, never by timers.

## 4. A. Placement and controls

Every placement judgement here is geometric reasoning. Nothing can be scored until the snap-reach harness exists (port step 8), and how Snap to Item really behaves needs a device.

There are two layers:
- what step 1 can do on Home version 0;
- the slots the layout engine should reserve (steps 4 and 5).

### A1. The Get Attention control

Recommended at every stage:

- **It is a standard, start-only `Button`** (invariant 1).
- **The visible title stays "Get Attention".**
  - The state shows through the icon and a "Sounding" caption or value.
  - Voice Control's name for it then never changes, and the frame never has to fit a second word ("Words never break").
- **It sits in the fixed quick-control area with Emergency, Yes and No.** It is:
  - one activation from every Home state;
  - never in a scrolling region;
  - never under the message text the person reads;
  - never in a corner.
- **It stays enabled while it sounds.**
  - A repeat counts as "already sounding" only while the live player confirms it is playing. This mirrors `SpokenUtteranceTracker.absorbsRepeat(of:synthesizerIsSpeaking:now:)`.
  - If the player stopped without telling the app, the same activation restarts it.
  - This is a check on state, not a timer.
- **Colours: black text on an attention fill, with a dark edge in light mode.**
  - Orange against white is about 2.2:1, under the 3:1 edge rule.
  - Pin both pairs in `PaletteTests`.
  - `whiteTextIsReadableOnEveryFill` runs over every fill in `Palette.assetNames`, so it first needs a text colour per fill.

What Get Attention's spot shows while the alarm sounds:

| Option | What happens | Verdict |
|---|---|---|
| **Stays a live button showing "Sounding"; repeats count as "already sounding" (recommended)** | The spot keeps a harmless target. A silent alarm restarts with the same activation | Yes |
| Nothing | The nearest control becomes a neighbour, and Yes and No speak. Voice Control loses "Get Attention" | No (invariant 10) |
| Passive "Alarm sounding" text | Same as nothing: text is not a target | No |
| A disabled button | Safe under dwell, but a stale "playing" state blocks the restart | No (invariant 5) |

### A2. Where Stop Alert goes

Every candidate faces two questions:
1. While the alarm sounds, what is nearest Get Attention? It must not be Stop.
2. After Stop fires and disappears, what is nearest its spot? It must not speak, alarm, delete or reorder, or switch into a mode that does.

| Option | Nearest Get Attention while it sounds | Nearest Stop's spot after it fires | Verdict |
|---|---|---|---|
| **S1. The reference shape, adapted.** The message bar gets two fixed action slots, Again and Clear. Stop takes Clear's slot while the alarm sounds. The quick row is Yes, No, Get Attention, Emergency: Get Attention sits under Again's slot, Emergency under Stop's. Whether Again stays or hides while it sounds is part of decision 1 | Again above it (repeats the last phrase), or the empty slot if Again is hidden; No; Emergency; a category | Clear (harmless). With no message showing: the empty slot, then Emergency | **Recommended** for Home v0, and as the layout engine's starting point. Adds Clear |
| **S2. A permanent Stop Alert in its own slot**, disabled when nothing sounds | Depends on the slot | Stop itself, disabled | Strong for the layout engine **if** Snap to Item treats disabled buttons as targets (unverified, device check). Otherwise the nearest enabled neighbour decides. Costs a permanent footprint, and a dimmed control families may ask about. Same place in every mode |
| **S3. Stop takes Again's place** (Home v0 has no Clear) | — | Again, which speaks | Rejected (invariant 10). This is what a straight port produces |
| **S4. Stop in the status area** | — | The last row of phrases, which speak | Rejected. The strip is passive text (invariant 4). Reading a warning points at Stop. It sits on the bottom edge |
| **S5. Stop next to or under Get Attention** | Stop | — | Rejected: a look drifting off "Sounding" ends the call for help |

**What S1 means on Home v0:**
- The message row becomes the text plus two slots, each a quarter of the width.
- On iPad the columns line up: Again over Get Attention, and Clear or Stop over Emergency.
- On iPhone the quick controls take two rows. That is a recorded v0 gap, because CI tests only the iPad.
- Clear needs a "message on screen" state of its own, separate from `lastSpokenText`, because Again and `phraseStartCount` depend on `lastSpokenText`.

**Again while the alarm sounds** (part of decision 1):

- **Keep Again (recommended).**
  - The recovery text "Stopped — Again" stays true. `SpeechRecoveryAction`'s own rule is that recovery text never names a control the current mode has removed.
  - The person can repeat a phrase for the caregiver who arrives.
  - The cost: a control that speaks sits directly above "Sounding", so a look drifting up repeats the last phrase.
- **Hide Again (the reference, measured on its own layout).**
  - An empty slot sits above "Sounding".
  - But a phrase cut off during the alarm, for example by the missed-finish watchdog, would name a missing Again. It needs a new `SpeechRecoveryAction` case, its text, and a test.

**What each stage gets with S1:**
- **Touch:** Get Attention and Stop are one tap each, far apart. Stray starts are rare.
- **Switch Control:** the geometry rules become scan-order rules.
  - Get Attention comes early in the scan.
  - Stop is never the item scanned straight after Get Attention.
  - Whatever takes Stop's place in the scan after it disappears is harmless.
  - Auto-select repeats the way dwell does.
  - Scan order is scored in step 8.
- **Head pointer and gaze:** with Snap to Item, "nearest" decides everything. Two risks remain:
  - a look resting near the end of the message could snap to Again, or beyond it to Stop;
  - the re-fire chain (A3).
- **Caregiver:** one "Stop Alert", always in the same place in the message bar.

**Cost:** medium.
- Restructure the message row.
- Add Clear, with its own message state.
- Make the quick row four controls, in two rows on the iPhone.
- Add a UI test.
- Record the unscored layout in docs/DECISIONS.md, "Home version 0 is a stand-in" (owner decision).

S2 is decided in the layout engine, after its device check.

### A3. Repeats, a silent alarm, and the re-fire chain

1. **Repeats while the tone sounds are absorbed.** That is state, not a timer.
2. **A stale "playing" state.**
   - The reference treats a repeat as "already sounding" whenever its own stored state says `.playing`.
   - If the player stops with no callback, the screen says "Sounding" over silence, and the person's next activation is swallowed.
   - The fix has two parts:
     - Absorb only while `AVAudioPlayer.isPlaying` is true.
     - Add the backstop speech already has (`watchForMissedFinish`). While the state says playing, check the live player once a second. If it has stopped and nobody asked, record `.stoppedUnexpectedly`, which shows the warning and makes the announcement. That is a health check, not an input guard.
3. **The re-fire chain.**
   - A caregiver taps Stop while the person's look still rests on Get Attention.
   - If Dwell fires again on a resting pointer, the alarm restarts.
   - Placement cannot fix a look that rests on the control itself, and timers are not allowed.
   - HANDOFF already lists the open question ("Whether a lingering look re-fires a dwell").
   - If a device shows it happens: accept it, record it in DECISIONS, and teach it in setup ("look away, then Stop").

### A4. Reach for the person and the caregiver

- **The person must be able to stop it with every input method.** They need to cancel their own stray starts.
- **Bigger is not safer.** A larger Stop for the caregiver also gives Snap to Item a larger area to catch the person's stray looks.
  - Recommended: Stop at the profile's quick-control size floor, no larger.
  - Make it obvious instead through its words ("Stop Alert"), its icon (`bell.slash.fill`) and the attention fill.
- **On a locked device, or with the app in the background, there is no Stop** in this design.
  - A caregiver unlocks the device, or presses the volume buttons.
  - `AudioSafetyMonitor` then reports "Volume low". The alarm still counts as playing, at zero volume, so the person's next Get Attention does nothing. The warning is the only clue.
- **Later options:**
  - a lock-screen Stop through Now Playing controls. This also lets headphone and Control Center buttons stop it.
  - a Siri or Shortcuts "Stop alert", as part of the planned Siri feature;
  - AlarmKit's system Stop.

### A5. Typing, edit mode, Settings

**Typing (step 5):**
- Get Attention and Stop sit above the worst-case keyboard from the moment typing opens (docs/LESSONS.md, "Test with the real software keyboard"). The reference's D27 left both covered.
- Under S1, Stop takes the message bar's trailing slot in every mode, so Stop never moves.
  - While typing, that slot's usual occupant is the way out of typing, Phrases.
  - While the alarm sounds, Stop replaces Phrases; after Stop, the slot shows Phrases again.
  - That makes a chain to score: Stop, then Phrases, then Clear. This is the reference's shape.
  - If it scores badly, the alternative is S2 everywhere, once its device check passes.
- Return never stops the alarm.

**Edit mode (step 6):**
- Under S1, the slot's usual occupant is Done Editing, which raises the same chain question.
- Starting the alarm changes no data and doesn't leave edit mode. Emergency does that.

**Settings (step 7):**
- Its opening screen has its own start-only Get Attention.
- Stop stays on Home only, as in the reference, or also goes in Settings' safety bar (a later decision).
- Settings' idle reset waits while the alarm sounds.
- Home's Stop must never sit where Settings' Get Attention sits. Otherwise closing Settings puts Stop under the person's resting look (the reference's unchecked hazard).
- Settings' Get Attention being nearest after a stray open needs its own owner decision. The reference's exception is not recorded in Brickson's DECISIONS.

### A6. Speaking during the alarm

| Option | Person | Caregiver | Invariants | Cost and risk |
|---|---|---|---|---|
| Both at full volume (the reference) | Phrases compete with a tone right in the middle of speech's frequencies | Full tone | 2 and 10 hold | No cost. Whether speech can be understood over it was never checked |
| **Turn the tone down while a phrase speaks (recommended)** | Phrases are clear | The tone continues, about 10 dB quieter. The exact level comes from the device check | Only the app's own player volume changes; system volume is untouched (4). Speaking never silences the alarm (10) | Small. Risk: the tone staying quiet if speech gets stuck. Avoid it by setting the volume from `SpeechService.isSpeaking`, so every ending restores it: a finish, a cancel, the missed-finish watchdog, an interruption or a reset |
| Pause the tone while speaking | Clean speech | Silence for as long as the person talks. A long typed message silences the call | Weakens the alarm | Small |
| Stop the alarm when speech starts | — | A stray tile ends the call for help | Breaks the reference's rule (10) | Rejected |

## 5. B. The sound

The person's stage barely changes the sound. What matters is how far away the caregiver is and how well they hear, and the person's own comfort. They cannot move away from a loud device on a mount about 45 cm from them.

**B1. Port the reference tone as is.**
- **For:** a known, already-tested file. No design time and no cost.
- **Invariant 4:** the tone plays on `.playback`. Whether it is actually heard is the next-room check.
- **Against:** a pure tone near 1–1.3 kHz is easy to lose:
  - behind a closed door, under a TV or a running tap, or in a "dead spot" in a room;
  - and it is hard to tell where it is coming from.
- **Against:** three pulses then a pause is the grouping of the smoke-alarm evacuation signal, "temporal-three" (NFPA 72 and ISO 8201; commonly 0.5 s on and 0.5 s off three times, then 1.5 s off, timing not re-checked here).
  - The reference's tone is faster and uses two pitches, but someone in another room could still think a smoke alarm is going off.
  - Test it with family listeners.
- **Verdict:** use it for the first pull request.

**B2. A harmonic-rich replacement (recommended before release).**
- **The brief:**
  - a base pitch of 400–1000 Hz;
  - several overtones up to about 4 kHz, within about 15 dB of each other. That is the shape IEC 60601-1-8 requires of medical alarm pulses: a fundamental of 150–1000 Hz with at least four harmonics in 300–4000 Hz (secondary sources).
  - a rhythm that matches none of these:
    - temporal-three (fire);
    - temporal-four (carbon monoxide);
    - the 10-pulse IEC high-priority burst, used by ventilators, BiPAP machines and pumps that many people with ALS have at home;
    - phone ringtones.
- **Why:**
  - Overtones keep the sound audible when a wall, a door, a small speaker or hearing loss removes some frequencies, and they make it easier to locate.
  - A lower base pitch carries better through walls.
  - Harmonic-rich does not have to mean shrill.
- **Invariant 4:** whether it is heard is decided by the next-room check.
- **Freeze it once it ships.** Families may train Sound Recognition on it (section 7).
- **Cost:**
  - Small engineering: swap the file, and add a unit test that pins its measured properties.
  - The real cost is the owner's listening test.

**B3. Repeated speech ("Please come here").**
- **For:** it tells the caregiver who is calling.
- **Invariants:** 7 (neutral words only), and 2 and 10 (it must never stop or delay a phrase).
- **Against:**
  - Speech carries through walls worse than a tone.
  - It needs the one synthesizer, which phrases also use. A phrase would cancel the call, breaking "speaking never silences the alarm". A second synthesizer is untested.
  - Personal Voice cannot be recorded to a file: Apple says apps can't capture speech made with a Personal Voice, and the privacy policy repeats this. A looped recording would have to use a standard voice.
- **Cost:** medium, about 2–3 days (a second synthesizer or a pre-recorded standard-voice clip, and mixing it with phrases), plus device checks.
- **Verdict:** not as the alarm. Perhaps later, as an occasional spoken line between tone cycles (owner decision).

**B4. A choice of tones (Settings, step 7).**
- It respects the person's choice, but every choice must pass the next-room test.
- It is a safety-relevant setting (docs/LESSONS.md, "Purge removed safety settings").
- Changing it breaks any Sound Recognition training.
- **Cost:** small to medium, 1–2 days once Settings exists, plus a next-room check for each tone.
- **Default:** one tone in 1.0.

**B5. System sounds and notifications: rejected.**
- `AudioServicesPlaySystemSound` obeys the silent switch, which invariant 4 forbids.
- Notification sounds need permission and obey Focus.
- Critical alerts need a special entitlement from Apple.
- AlarmKit is covered in section 6, C4.

**Getting louder over time:**
- **Rejected:** a volume ramp. The player already runs at volume 1 and the app never sets system volume, so a ramp can only make the first seconds quieter. That is the wrong way round for a call for help.
- **Possible:** more urgent pulses after, say, a minute unanswered. It would use `ContinuousClock`, with the current time passed in. It means a second sound to design and test.
- **Default:** a constant sound.

**Volume:**
- The app can only watch the volume. Home shows "Volume low" below 0.2, a provisional threshold.
- Proposals:
  - choose the threshold from the next-room check;
  - consider a higher threshold while the alarm sounds;
  - show the current volume beside Settings' alarm test.
- Setup advice:
  - keep the media volume high (on an iPhone, Brickson follows the media volume, not the ringer);
  - Guided Access can turn the volume buttons off (unverified).

## 6. C. The audio session

### C1. Keep the session active (today)

- **What people get, at every stage:**
  - no extra delay before a phrase;
  - the alarm never waits for activation.
- **The cost to other apps:** music or a podcast that the first phrase interrupted stays paused.
- **Invariants:** 2 and 4 hold.
- **Cost:** none.
- **Risk:** it is unkind to other apps. It does not keep the app alive in the background, because iOS suspends an app that isn't playing anything.

### C2. Release the session when idle (`.notifyOthersOnDeactivation`)

- **What people get:** music resumes between phrases. That helps touch-stage people who also use the device for music or podcasts.
- **The alarm must hold a lease.** Apple: "Deactivating an audio session with running audio objects stops the objects, makes the session inactive, and returns an isBusy error." A release while the alarm plays would silently kill it.
- **Risks:**
  - Activation runs on the main thread before every phrase, adding time (invariant 2).
  - The first syllable may be clipped over Bluetooth (unverified, device check).
- **On iOS 27,** `DeactivationContext.source == .app` lets the app ignore its own release.
- **Cost:** medium, plus device checks.

### C3. Duck other apps (`.duckOthers`)

- **What people get:** a phrase plays over quieter music.
- **Apple's limit:** "Set this option on a temporary basis only. Don't use it to duck the audio of other apps for more than a few seconds."
- **It needs C2,** because the ducking ends only when the session deactivates.
- **It makes the session mixable,** which is wrong for an alarm that sounds for minutes. The alarm would have to reconfigure the session while it is active.
- **Cost:** medium to large.
- **Verdict:** not for 1.0.

### C4. AlarmKit for the alarm

AlarmKit is new in iOS and iPadOS 26. It shows prominent system alarms that override Focus and the silent switch. Its timer "starts immediately, runs for the duration, and then alerts". It needs an `NSAlarmKitUsageDescription` string and an authorization prompt; if the person refuses, nothing can be scheduled.

- **For:**
  - The system owns the sound, so it would survive Brickson crashing or being suspended.
  - It gives the caregiver a system Stop on the Lock Screen.
- **Against:**
  - The system draws the alert and its Stop, so Brickson can't control where Stop sits (invariant 10).
  - Unverified, device check: whether the alert covers Emergency on a phone in use (invariant 2), whether a near-zero timer is allowed, how long it rings, and its sound limits.
  - It is a second alarm path to keep in step with the first.
- **Cost:** large.
- **Verdict:** defer. Revisit if devices show the app's own alarm dying, or caregivers need a lock-screen Stop.

### Across all four

**Mode: change `.spokenAudio` to `.default`** (from the Apple platform audit).
- Apple says `.spokenAudio` means "your app should pause, rather than duck, its audio if another app plays a spoken audio prompt".
  - For the alarm: a navigation or workout prompt in another app could stop it.
  - For a phrase: it is cut off instead of briefly turned down.
- There is one session with one mode, so change both.
- **Cost:** small. Pin it with a unit test; it also needs a device check.

**Interruptions** (from the Apple platform audit).
- iOS 27 deprecates `interruptionNotification` in favour of three newer notices:
  - `didBecomeInactiveNotification`, whose `DeactivationContext` says whether the app or the system caused it, and why;
  - `didBecomeActiveNotification`;
  - `resumptionRecommendationNotification` (`.shouldResume` or `.shouldNotResume`).
- Apple says these "don't get out of sync when the system can't deliver an end event".
- **Recommended: one `AudioSessionEvents` adapter.**
  - It takes an injected NotificationCenter and object, as `AudioSafetyMonitor` does.
  - It sends the same app-level events to `SpeechService` and to the alarm.
  - It replaces `AudioSessionInterruptionObserver` and the reference's duplicate observers.
  - It uses one source of notices per OS version, so nothing is announced twice. The app's own deactivations are not failures.
- **The CI problem.** CI builds with Xcode 26.6 and tests on iOS 26.5; the owner's Mac has Xcode 27 and iOS 27. The new notices exist only in the iOS 27 SDK.
  - Keep the deprecated notice for now: deprecated does not mean removed.
  - Whether iOS 27 still posts it is a check on the owner's iOS 27 simulator or a device.
  - Add the iOS 27 branch behind `#if compiler(>=6.4)` and `if #available(iOS 27, *)` once CI builds with Xcode 27.
- **Auto-resume default: no,** even when iOS recommends resuming. "Alert stopped" shows, and one activation restarts it. That is invariant 4's "names a reachable control to retry". The owner decides.

**Calls:**
- During a call, iOS refuses a session that won't mix with others. Today's fallback then activates with `.mixWithOthers`.
- Where the tone plays then is unverified (device check). It may be the earpiece on an iPhone call, and the iPad speaker during FaceTime.
- **Make the fallback visible:**
  - Activation returns an outcome: exclusive, shared with higher-priority audio, or failed.
  - "Shared" shows a new warning, "Audio shared" (12 characters). Its full sentence says another app, such as a call, is using the sound and Get Attention may be quiet.
  - It invents no cause, following `stoppedAlertCopyDoesNotInventACause`.
- The alarm never tries to interrupt a call: it can't.
- An incoming call interrupts the alarm, and "Alert stopped" shows.
- `.playAndRecord` cannot help: it fails during calls and brings in the microphone.
- Related, for speech rather than the alarm: `AVSpeechSynthesizer.mixToTelephonyUplink` (iOS 13 and later) "specifies whether to send synthesized speech to an active call". Live Speech offers the same for typed words.

**Media-services reset:**
- Rebuild the player at the next start. The state becomes `.stoppedUnexpectedly`.
- Wait for the person's next activation before activating anything. This is Apple's rule, recorded in DECISIONS.
- The monitor stays unhealthy until an activation succeeds. "Alert stopped" already outranks "Audio failed".
- **Cost:** small. Test it with an injected NotificationCenter.

**Background and lock screen:**
- The alarm keeps sounding through lock and app switches. That is allowed, and wanted: guideline 2.5.4 lists audio playback as a background purpose, and the tone is audible and started by the person.
- App Review notes: "Choose Get Attention, then lock the device: it keeps sounding until Stop Alert is chosen in Brickson."
- When the app comes back to the foreground, it runs the health check.
- No lock-screen controls by default.

**Output routes:**
- **The built-in speaker cannot be forced.** `.defaultToSpeaker` and `overrideOutputAudioPort(.speaker)` require `.playAndRecord`. That brings in the microphone, fails during calls, and would contradict the privacy policy's sentence about the microphone.
- **So warn instead.** Show a route warning whenever the output isn't the built-in speaker. It helps speech as well as the alarm.
  - Short text per output type, each within 16 characters: "On headphones", "On Bluetooth", "On hearing aids" (`.bluetoothLE`), "On AirPlay".
  - The full sentence names the device.
  - Urgent while the alarm sounds; informational otherwise.
- **How to read invariant 4 here.**
  - "Never auto-resume into a changed route" most naturally means: never restart by itself, after a stop, into a different output.
  - On that reading, carrying on through a route change is not a resume, and neither case below needs an exception.
  - If it also covers carrying on, both cases need a named exception.
  - Decision 3 settles the reading and both answers.
- **The old device disappears** (a Bluetooth speaker switched off).
  - The reference stops and shows "Alert stopped". Carrying on through the built-in speaker puts the sound in the room.
  - Recommended: carry on.
- **A new private device appears** (AirPods connect).
  - iOS moves the sound into the person's ears while the screen says "Sounding".
  - Recommended: carry on and show the urgent route warning. Stopping helps nobody.
- **Built until decided:** the reference's behaviour. It stops when the old device disappears, and carries on, now with the warning, when a new one appears.
- **Setup advice for MFi hearing aids:** Accessibility → Hearing Devices → Audio Routing → Media: Never Hearing Devices. Reports vary, so this is a device check.

## 7. D. Beyond sound

- **Haptics:** useless for a caregiver in another room, and most iPads have no haptic motor anyway.
- **A flashing screen: no.**
  - Risk of seizures: WCAG 2.3.1 allows at most three flashes per second.
  - It disturbs the person.
  - Its effect on Eye Tracking is unknown.
  - It must never obscure Emergency.
  - Instead: a steady, high-contrast "Sounding" state that can be seen across a room.
- **A flashing camera light:** marginal. Most iPads have no flash, and on a mounted device it faces the mount.
- **Sound Recognition, with no code in Brickson.**
  - A caregiver trains their own iPhone, or their Apple Watch through it, on a custom alarm. They then get a notification and a tap on the wrist.
  - Apple warns not to rely on it in emergencies.
  - It needs a tone that never changes.
- **An audio baby monitor:** also no code. It carries both the alarm and the person's speech. Setup guidance.
- **Grid 3:** it triggers a plug-in EasyWave alarm in the carer's room, and Smartbox says not to rely on it alone. Hardware integration is out of scope.
- **Caregiver alerts over the local network:** a hard stop today (invariant 9); the owner decides before they are built.
  - They would plug into the alarm's state-machine transitions.
  - Give start and stop events a "source" now, so a caregiver's device could send "stop" later.
  - The privacy policy section already describes them.

**How other products compare:**
- TD Snap: users add their own "Alert Bell" button with a one-shot doorbell sound.
- Grid 3: an external alarm (above).
- Proloquo4Text: I found no documented attention alarm (one search).
- Apple's Live Speech: speaks typed words and phrases, including into calls and FaceTime. It has no attention alarm.
- None of them offers a looping, start-only alarm with a separate Stop.

## 8. E. Testing

### Pure types that never read a clock

**`AttentionAlertStatus`,** a value type like `SpeechInterruptionStatus`.
- Events in:
  - a start request, passing in whether the live player is playing;
  - the start's result;
  - a stop request;
  - an unexpected stop, from an interruption, a reset, a lost output, a player event or the health check;
  - speech starting and ending.
- Out: the state, `failureSequence`, the tone's volume, and the next action.
- Tests:
  - `aRepeatWhileTheTonePlaysIsAbsorbed`.
  - `aRepeatAfterTheTonePlayerStoppedSilentlyRestartsIt`. This fails under the reference's rule.
  - `theHealthCheckReportsASilentStopOnce`.
  - The reference's tests, ported:
    - a late callback from an old player can't stop the new one;
    - a stop doesn't erase a failed start;
    - interruptions, resets and a lost output while playing show "Alert stopped";
    - while idle, they change nothing.
  - `theToneDucksWhileAPhraseSpeaksAndRestoresOnEveryEnd`, including the watchdog path.

**`AudioSessionLeasePolicy`:**
- `keepActiveNeverDeactivates`.
- `theSessionIsNeverReleasedWhileTheAlarmLeaseIsHeld`.

**Also:**
- the activation outcome: `aMixedActivationIsVisible`;
- the mapping from output type to warning text;
- the new warnings and their ranking in `AudioSafetyPolicy`.

**Two existing tests need changing:**
- **`compactStatusCopyFitsAReservedStrip`** lists its cases by hand, so a new warning would slip past it. Run it over `HomeAudioIssue.allCases`.
- **`acuteFailuresRequestUrgentAnnouncements`** lists only the urgent cases, on purpose. Over `allCases` it would fail on `.lowOutputVolume` and on an informational route warning.
  - Instead, check every case's urgency in one test, with a `switch` that has no `default`.
  - Then a new case fails to compile until someone decides its urgency.

### Test seams

- **`AttentionTonePlayback`,** from the reference, extended with `isPlaying` and `volume`.
- **`AudioSessionControlling`,** wrapping setting the category, activating, and reading the current route. Tests can then inject a refused activation or an `isBusy` error.
- **An injected NotificationCenter and object** for the events adapter.
- **`OffMainThreadCallbackTests`** for the player's delegate callbacks and the new observers.
- **A launch argument that swaps in a silent fake player.**
  - A UI test can then drive Get Attention, then "Sounding", then Stop Alert.
  - It can check with `XCUIElement.frame` that no frame moves.
- **A bundle test** that the tone file decodes. Once the final tone is chosen, also pin its overtones and check that its pattern isn't the fire alarm's.
- **`PaletteTests` pairs** for the attention fill.
- **iOS 27 notice contents** may not be constructible in tests. Test the adapter's mapping, and leave reading the notices to a device.

### Only a device can show

These rows replace HANDOFF's single Get Attention row:

| Check | What it decides |
|---|---|
| Get Attention heard from the next room, door open and shut, with a TV or tap running there, at full, half and 20% media volume, on iPad and iPhone | The tone, and the alarm's low-volume threshold |
| Get Attention and speech with AirPods, a Bluetooth speaker, wired headphones and MFi hearing aids, including with Audio Routing set to Never Hearing Devices | The route warning and the setup advice |
| Get Attention with the silent switch (or Action button) set to silent, and with a Focus on | That `.playback` ignores both (invariant 4) |
| Get Attention started during a phone call and during FaceTime: whether it plays, where, and whether "Audio shared" appears | The fallback that mixes with the call, for the alarm |
| An incoming call, Siri, and another app's alarm while it sounds: "Alert stopped" appears and one activation restarts it afterwards; on iOS 27, which notices arrive | Interruption handling and no auto-resume |
| A Bluetooth speaker switched off, then AirPods connected, while it sounds | Decision 3 |
| Locking with the side button, and switching apps, while it sounds; then coming back and choosing Stop | Background audio and the 2.5.4 App Review note |
| Developer → Reset Media Services while it sounds | Rebuilding and restarting |
| A listener 1 m away writes down ten phrases spoken over the alarm, with and without the tone turned down | How far to turn the tone down |
| Eye Tracking with Dwell: the person keeps looking at Get Attention while a caregiver taps Stop. Also Switch Control's auto-scan after Stop | The re-fire chain |
| Snap to Item and a disabled button: whether it snaps to it, and whether a dwell on it does nothing | Option S2 |
| Maps speaks a direction while speech and the alarm play, in `.spokenAudio` and in `.default` mode | The mode |
| The first syllable of a phrase over Bluetooth, with the session kept active and with it released after speech | C2, and invariant 2 |
| 30 minutes of alarm on battery | Battery use and heat |

## 9. Recommendation

- **Placement:** S1 on Home v0, with Again kept while the alarm sounds, and Get Attention built as in A1.
- **Sound:**
  - B1 now, B2 before release.
  - A constant level.
  - The tone turned down while speech plays.
- **Session:**
  - C1, behind a lease coordinator;
  - the `.default` mode;
  - a visible call fallback;
  - the route warning;
  - one events adapter.
- **Deferred until device checks:** C2, C3 and C4.
- **Beyond sound:** setup advice only.

Rough cost, in agent days, not counting device checks:

| Work | Days |
|---|---|
| State machine, events adapter, coordinator, player and tone | 1–2 |
| Mode change | under 1 |
| Home v0 placement, Clear with its own message state, StatusArea wiring, palette and UI test | 2–3 |
| "Audio shared" and route warnings | 1–2 |
| Turning the tone down while speech plays | under 1 |

None of this makes a sentence of the privacy policy untrue.

## 10. Smallest first step

### Pull request 1: nothing changes on screen

Test first, and every option stays open.

1. **`AttentionAlertStatus` and its tests.**
2. **The `AudioSessionEvents` adapter, iOS 26 path only.** It handles interruptions, route changes, and media-services loss and reset. `SpeechService` and the player both use it, and it replaces `AudioSessionInterruptionObserver`.
3. **`AudioSessionCoordinator`.**
   - Its lease policy is set to "keep active", so speech behaves exactly as today.
   - It returns an activation outcome.
   - `SpeechService` calls it through an `AudioSessionControlling` seam.
4. **The `AttentionAlertPlayer` port.**
   - Behind the protocol, taking its events from the adapter.
   - Off-main tests for its callbacks.
   - `AttentionTone.wav`, with a bundle test.
5. **The mode change, `.spokenAudio` to `.default`,** as its own commit. A unit test pins it, and it is marked untested on a device.
6. **The two test changes** from section 8.
7. **Documentation:**
   - HANDOFF: what was ported, what is untested, and the new device rows.
   - DECISIONS, "Background audio": the lease design, with the session still kept active.
   - PORTING: the step 1 row.

Home keeps "No Get Attention yet", so no new dwell hazard ships.

### Pull request 2: after the owner settles decision 1

- The Home v0 placement.
- `StatusArea` reading the alarm's state and announcing on `failureSequence`.
- `PaletteTests` for the attention fill.
- A UI test with the fake player.
- The "Audio shared" warning.
- The route warning. If it slips, record both silent failures in HANDOFF *Known gaps* before pull request 2 merges. They are:
  - the call fallback, which shows "Sounding" over a quiet or earpiece-only tone;
  - private outputs, which show "Sounding" over a sound only the person hears.

## 11. Decisions for the owner

1. **Where Get Attention and Stop Alert go on Home v0.**
   - Recommended: the reference shape (S1).
     - A harmless Clear button, with its own "message on screen" state.
     - Stop in Clear's slot while the alarm sounds.
     - The quick row: Yes, No, Get Attention, Emergency.
   - Within it, Again while the alarm sounds:
     - **Keep it (recommended).** The recovery text stays true, and the person can repeat a phrase. The cost is a control that speaks directly above "Sounding".
     - **Hide it.** This is the reference's choice, and it needs a new recovery action and a test.
   - Record the layout, which no harness has scored, in "Home version 0 is a stand-in".
2. **Speaking while the alarm sounds.**
   - Recommended: turn the tone down while a phrase speaks.
   - Alternatives: leave it at full volume, or pause it.
3. **The output changes while the alarm sounds, and how to read invariant 4.**
   - My reading: the rule forbids restarting by itself after a stop. Carrying on through a change is not a resume, so no exception is needed. If you read it as also covering carrying on, both answers below need a named exception.
   - **The old device disappears.** Recommended: carry on through the device's speaker, because sound in the room beats silence. The reference stopped and showed "Alert stopped", and that is what gets built until you decide.
   - **A new private device appears.** Recommended: carry on, and show the urgent route warning.
   - Record the reading and both answers in DECISIONS.
4. **The alarm restarting by itself after a call or Siri.** Recommended: no. "Alert stopped" shows, and one activation restarts it.
5. **Releasing the audio session after speech** (DECISIONS' open question).
   - Recommended: keep it active for 1.0.
   - Build the lease now, so switching later changes one type.
   - Revisit with device data, perhaps for touch users only.
6. **The tone.**
   - Port the reference tone now.
   - Choose the release tone by a listening test of two or three harmonic-rich candidates.
   - Never change it once it ships.
   - Ship one tone in 1.0, with no choice.
7. **Getting more urgent over time.** Recommended: a constant sound.
8. **Settings' Get Attention being nearest after Settings is opened by mistake** (once Settings is built). Recommended: accept it as a named exception, as the reference's owner did.
9. **The re-fire chain, if a device confirms it.** Recommended: accept it, record it, and teach "look away, then Stop".
10. **Stopping from the lock screen or by Siri.** Recommended: not in 1.0.
11. **AlarmKit.** Recommended: not now.
12. **A flashing screen.** Recommended: no.
13. **A time limit on the alarm.** Recommended: none. An unanswered call for help keeps calling.

## 12. Sources

Apple documentation, read through Context7 rather than fetched:
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setactiveoptions/notifyothersondeactivation
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/duckothers
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/interruptspokenaudioandmixwithothers
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/spokenaudio
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/defaulttospeaker
- https://developer.apple.com/documentation/avfaudio/avaudiosession/overrideoutputaudioport(_:)
- https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- https://developer.apple.com/documentation/avfaudio/avaudiosession/resumptionrecommendationnotification
- https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/mixtotelephonyuplink
- https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit
- https://developer.apple.com/documentation/alarmkit/alarmmanager/alarmconfiguration/timer(duration:attributes:appentityidentifier:stopintent:secondaryintent:sound:)

App Review Guidelines, 2.5.4:
- https://developer.apple.com/app-store/review/guidelines/#software-requirements
- The text was confirmed through quotes on Apple's forums, for example https://developer.apple.com/forums/thread/726366

Apple Support:
- Sound Recognition on Apple Watch: https://support.apple.com/guide/watch/ay39m4y6riek/watchos
- Live Speech: https://support.apple.com/105018
- Hearing devices: https://support.apple.com/en-lk/guide/iphone/hearing-devices-iph470b1833/13.0/ios

Hearing aids and iOS:
- https://www.hearingsolutions.philips.com/en-CA/support/troubleshooting/apple-ios-troubleshooting/why-cant-i-stream-sound-from-my-ios-device-to-my-hearing-aids
- https://tidbits.com/2020/05/30/exploring-hearing-aid-integration-in-ios/
- https://forum.hearingtracker.com/t/-/61448/4

Alarm standards (secondary sources):
- IEC 60601-1-8: https://www.mddionline.com/components/audible-alarms-medical-equipment
- IEC 60601-1-8: https://www.digikey.com/en/articles/how-to-properly-implement-audible-alarms-in-medical-monitoring
- NFPA 72 and the 520 Hz signal: https://www.csemag.com/nfpa-72-and-720-code-changes/
- Temporal-three sounders: https://firealarm.com/product/system-sensor-b200s-lf-wh/

Other AAC products and Sound Recognition:
- TD Snap alert bell: https://omazingkidsllc.com/2023/02/05/td-snap-aac-how-to-add-an-alert-bell-to-gain-attention-video-tutorial/
- Grid 3 and EasyWave: https://hub.thinksmartbox.com/knowledgebase/how-do-i-connect-an-eldat-easywave-alarm-with-grid-3/
- Sound Recognition (AbilityNet): https://mcmw.abilitynet.org.uk/how-to-detect-sounds-using-your-iphone-or-ipad-with-ios-17

Files referred to:
- Brickson: `Brickson/Speech/SpeechService.swift`, `Brickson/Speech/AudioSafetyMonitor.swift`, `Brickson/Speech/AudioSafetyPolicy.swift`, `Brickson/Home/HomeView.swift`, `BricksonTests/AudioSafetyPolicyTests.swift`, `BricksonTests/PaletteTests.swift`
- Reference (private repository, read from the owner's local clone at `6a22c1a`): `FamilyVoice/Speech/AttentionAlertPlayer.swift`, `FamilyVoiceTests/AttentionAlertPlayerTests.swift`, `FamilyVoice/Models/HomeChromePolicy.swift`, `FamilyVoice/Models/QuickControl.swift`, `FamilyVoice/Resources/AttentionTone.wav`