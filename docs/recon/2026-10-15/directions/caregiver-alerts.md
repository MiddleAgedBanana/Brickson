# Options memo: reaching a caregiver who is out of earshot

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Prepared 2026-10-16 for the owner. Planning only: read-only, nothing built or run, no device evidence. Repo root: the repository root (a planning worktree on the owner's Mac). Files read in full: AGENTS.md, docs/DECISIONS.md, PORTING.md, HANDOFF.md, LESSONS.md, site/privacy/index.html, Brickson/Resources/PrivacyInfo.xcprivacy, project.yml, Brickson/Speech/AudioSafetyPolicy.swift, .github/copilot-instructions.md.

Evidence tags: [repo]; [Apple doc] (read through Context7, never fetched from developer.apple.com; the Wi-Fi Aware overview was the German-localised copy, translated by me); [Apple Support]; [community] (forum or mailing-list reports, not clinical advice); [third-party]; [reasoned] (my inference); [unverified]. Web sources are paraphrased. Cost sizes are guesses relative to the Get Attention alarm port (S, the next step in HANDOFF): M is about 3 of those, L about 8, XL more or blocked on Apple.

## 1. The answer in brief

- Sound alone (A) helps only someone near, awake and listening. A closed door, sleep or distance defeats it. It is the only thing Brickson can promise today, and the alarm is not even ported yet.
- Whether a built-in alert can reach a sleeping caregiver turns on one fact: iOS has no background mode for local-network messages (the UIBackgroundModes list has audio, Bluetooth, location, voip, push-to-talk, remote-notification and others, but nothing for LAN traffic) [Apple doc]. A caregiver's phone that is locked, pocketed or has Brickson closed will not receive a local-network alert unless Apple grants special entitlements. What is documented to work is a caregiver station: a spare iPad or iPhone, plugged in, with Brickson open in front.
- The Shortcuts route (B) needs no network code in Brickson. It reaches caregivers who are away from home, with an ordinary text or call. But the family builds the chain, it starts from a different control (two or more activations), and Brickson cannot see whether it worked.
- Wi-Fi Aware (the platform-audit fact): only partly right. See section 7, C.0.
- An Apple Watch app (D) cannot be built to receive Brickson's network traffic. Watch haptics come free through B.
- Recommendation: 1.0 is A plus E (sound only, caregiver-alerts section deleted from the policy, plus a family guide to outside call systems). Later: B-lite first, then C1 behind a recorded invariant-9 exception, only after a two-device experiment. C2 and D are not planned. Owner decisions are in section 11.

## 2. How alerting works today (context)

- Community reports: a switch the person can still use drives a small wireless transmitter, and the caregiver keeps a receiver that rings or vibrates (extra plug-in receivers exist). One family used a pressure-activated alarm loud enough to hear several rooms away. Baby monitors carry sound, but some families refuse them for privacy. Wireless chimes fail through thick stone walls. Ordinary doorbell buttons become too hard to press. When nothing can be pressed, families put an eye-gaze device's alarm or typed message in front of the person at night. An ALS Association assistive-technology specialist called an easy call bell for eye-movement-only users an unmet need. [community]
- Care facilities: a US assistive-technology centre thread describes a resident who could no longer press the wireless pendant. The system relied on facility Wi-Fi, and aides carried iPads and were not always near a station. Facility networks are often not the family's to configure, so Wi-Fi-based designs can fail there. [community]
- AAC vendors: Smartbox Grid's Smart Buttons are reported to run an environment-control alarm command or an instant-SMS command [third-party, search snippet, not re-read]. Tobii Dynavox's training catalogue lists a TD Snap topic on alerting a caregiver on the I-13 and I-16 (title only; I could not read it). I found no documentation of a built-in remote-caregiver alert in Grid 3 or Communicator. Treat that as unknown, not absent.
- Apple: the Watch gets the iPhone's notifications only when the iPhone is locked or asleep, and the Watch is unlocked and connected [Apple Support]. Find My is a lost-device tool. Emergency SOS contacts emergency services, which the policy says Brickson never does.
- Pattern: what families use is a separate, simple loud or vibrating receiver, or a message through something caregivers already carry.

## 3. Rules every option meets (verbatim)

- Invariant 9: "**Hard stops (never build):** accounts or login, servers or network code, cloud sync (for now: docs/DECISIONS.md), analytics, ads or tracking, third-party packages or SDKs, AI-generated replies, custom gesture-only interactions, custom eye, head or switch tracking. The privacy manifest declares no data collected."
- AGENTS.md, privacy policy section: "caregiver alerts advertise a random service name and send the device name only inside the encrypted alert;" and "Caregiver alerts need network code, which invariant 9 forbids; the owner decides before they are built." Also "Store nothing in the Keychain. It survives deleting the app, and the policy says deleting the app removes what it stored."
- DECISIONS, "No servers, accounts, ads or analytics": "*Invariant 9.* Everything stays on the device." DECISIONS, "Background audio": "never play silent audio to keep the app alive".
- Invariant 4: "Speech and alarms use the `.playback` session so they play with the silent switch on (never `AudioServicesPlaySystemSound`), and recover from interruptions, route changes and media-services resets. Failures the person cannot hear show visibly as passive, layout-reserved text that never replaces the message, never adds a dismiss control and never moves a target. Observe but never set system volume. ... An interruption keeps the text and names a reachable control to retry; never auto-resume into a changed route."
- Invariant 10: "Get Attention, Emergency, Yes and No are one activation away from every Home state, including while typing." Design rule: "An alarm stops only from a separate, differently placed control."
- Invariant 12: "The screen never locks while Brickson is open (`ScreenWakePolicy`)."
- Current policy section ("If you turn on caregiver alerts", site/privacy/index.html lines 69-77) promises: off until turned on; iOS asks permission for the local network; the alert says you need attention and shows the device name; "It goes straight from your device to the caregiver's device, encrypted. It never goes over the internet, and we cannot see it."; devices "announce Brickson on the network", visible to others but "not your name"; works "only while both devices are on the same local network, such as your home Wi-Fi"; "An alert can fail to arrive, so don't rely on it alone."; stop by the Brickson toggle or the Local Network switch. Line 111 adds: "Only Get Attention can alert a caregiver's device, and only if you turn on caregiver alerts."
- Status today: no Get Attention alarm is ported [HANDOFF]. The "Get Attention heard from the next room, on the speaker and over Bluetooth" check is still open. Most of the app (layout engine, Home, typing, editing, Settings) is also not built [PORTING].

## 4. At a glance

| | Caregiver needs | Reaches a sleeping or distant caregiver? | Network code in Brickson | Invariant 9 | Cost | Person can see a failure? |
|---|---|---|---|---|---|---|
| A sound | nothing | no; only within earshot | none | untouched | S plus device checks | no |
| B Shortcuts chain | a phone, ideally a Watch | yes, even away from home, if the text or call gets through | none | spirit kept | S-M code, M testing | no; Brickson cannot see the outcome |
| C1 station | spare device, Brickson open, plugged in | only the station's room; it must be loud there | yes | needs a recorded exception | L | yes, by design |
| C2 pocket phone | any iPhone | yes, only if Apple approves entitlements and it works | yes, plus an extension | needs the exception | XL plus Apple | partly |
| D Watch app | Apple Watch | no; routes through the iPhone anyway | n/a | new platform decision | XL | no |
| E sound only | n/a | no | none | untouched | S | n/a |

## 5. Option A: sound only (the baseline for every option)

**What they get.** The person gets a loud repeating sound from their own device in one activation. The caregiver hears it if within earshot. Nothing on the caregiver's side.

**Covers / misses.**
- Covers an awake caregiver in the same or an adjacent open-door room.
- Misses a closed door, sleep, earplugs or hearing loss, outdoors, running water or a TV, and a device in a bag or case.
- Rough audibility yardsticks, estimates only, none measured by me:
  - A phone speaker measured 102 dBA "from the bottom" and 93 dBA "from the side" at an unstated distance [third-party review].
  - Open-air sound loses about 6 dB per doubling of distance [reasoned].
  - Fire codes ask for 75 dBA at the pillow, tested with the bedroom door closed [third-party, SF Fire FAQ quoting NFPA 72], and a low-frequency (520 Hz) signal in sleeping areas.
  - A hollow-core interior door is roughly STC 25 [third-party vendor figures].
  - Conclusion: plausible for an awake person next door with the door open; not shown for a sleeper behind a closed door. Measure on devices (it is already a HANDOFF check).
- Brickson observes volume but never sets it. A low-volume warning already exists (threshold 0.2, `AudioSafetyPolicy`). The person never learns whether anyone heard.

**Cheap amplifiers and their route questions.**
- A Bluetooth or AirPlay speaker in the caregiver's room would be the app's only output, so the person's spoken phrases would also come out in the caregiver's room.
- Losing that route mid-alarm (the speaker auto-powers off or goes out of range) collides with invariant 4's "never auto-resume into a changed route". Owner and alarm-design decision: keep sounding on the device speaker, or stop and show text.
- A baby monitor or intercom by the person is a zero-code relay that families already use, though some refuse it for privacy [community].
- An independent call bell (switch, transmitter, receiver) is outside Brickson and is what most families rely on.

**Invariants.** 4 (quoted above), the alarm-stop design rule, and 12. Invariant 10's "A mode switch never leaves a speaking, alarming, position-changing or destructive control nearest the spot just activated" governs where Stop Alert sits.

**Policy.** No change. The policy already says Get Attention "make[s] sound on your device" and never calls emergency services.

**Cost.** S for the alarm, which is already planned. S-M for route-loss handling, tests and a device matrix: speaker, Bluetooth, silent switch, call interruption.

**Failure modes.** Inaudible with no signal back to the person. Mitigation is the existing passive audio warnings plus a family-guide test: stand where the caregiver sleeps and listen.

## 6. Option B: system-integrated alerts, no Brickson network code

**What they get.** Brickson offers a "Start Get Attention" App Intent. The family builds a shortcut: Brickson's action, then Send Message or Call a contact, then optionally a Home scene (smart plug siren or light) via Shortcuts' own Home action. The person runs it from somewhere reachable; the caregiver gets an ordinary text or call, on the Watch too, even when away from home.

**How the person reaches it.**
- AssistiveTouch can run a shortcut from a custom action (single tap, double tap, long press) or a top-level menu icon [community, TidBITS; not re-verified on Apple's page].
- Other candidates: a Siri phrase, a Control Center or Lock Screen control, the Action Button on iPhone. Reachability per input method (dwell, switch, Voice Control) is a device check.
- Apple documents an automation setting that runs without asking [Apple Support].
- Two limits:
  - I found no automation trigger that fires on Brickson's own Get Attention button, so Brickson's tile cannot launch the chain. In-app Get Attention stays one activation for the sound only.
  - Apple's `RunSystemShortcutIntent` works only in widgets, not in app UI [Apple doc].
- Brickson's button must not open a `shortcuts://` URL. That brings Shortcuts to the front, which puts another app's controls under a resting gaze (invariant 10).
- Apple's Messages compose sheet is operated by the person, who taps Send; an app cannot send for them [Apple doc]. So no in-app silent send either.

**Caregiver side (zero code).**
- Contacts has Emergency Bypass for a contact's ringtone and text tone, letting that contact's sound through silent mode and Focus [Apple Support].
- Messages Repeat Alerts repeats an alert (reported up to 10 times, about 2 minutes apart) [third-party].
- The Watch receives it only when the iPhone is locked or asleep and the Watch is worn and unlocked [Apple Support].

**Mechanics to verify.**
- Starting the alarm from a shortcut while Brickson is not in front likely needs the intent to conform to `AudioPlaybackIntent` [Apple doc exists; whether required is unverified]. `authenticationPolicy` defaults to always allowed, so an intent can run while locked [Apple doc].
- Silent Send Message depends on the "Show When Run" setting [Apple release notes, via search]. A forum report says an automation did not send while the phone was locked [community].
- An iPad can message through iMessage with an Apple Account; SMS probably needs an iPhone forwarding texts [reasoned, unverified].
- Brickson cannot see whether the message went [reasoned]. Brickson must not use the HomeKit framework itself; Shortcuts does that part. (App Review has historically expected HomeKit-using apps to be about home automation [third-party, 2014-era coverage].)

**Per-state notes.**
- Person's device locked: the intent may run, but Shortcuts steps may want an unlock [community].
- Caregiver silent or in Focus: bypassed only if Emergency Bypass is set.
- Caregiver away from home: works over cellular or internet through Apple or the carrier; C does not.
- Messaging or Wi-Fi down: fails silently from Brickson's view.

**Is invariant 9's spirit kept?** Yes. The app never touches the network and no Brickson data leaves it. The message text and phone number live in the family's shortcut, never in Brickson.

**Invariants touched.**
- 9 (not triggered).
- 10: a dwell resting on the AssistiveTouch icon can run a family-built shortcut repeatedly and text the caregiver many times, because shortcuts have no repeat protection.
- 5, "No silent failures", applies to Brickson's code only; this failure is outside the app. Say so plainly in the guide.

**Policy.**
- The "Siri and Shortcuts" section currently says Brickson lets iOS see the words of phrases. If only a Get Attention action ships, reword it. Say Brickson offers the Get Attention action; any message or light a shortcut triggers is Shortcuts, Messages and Apple, not Brickson; and no phrase words or phone numbers pass through Brickson.
- Line 111's "Only Get Attention can alert a caregiver's device" needs rewording.
- The privacy label is unchanged.

**Cost.** S-M for the intent, tests and `AppBundleTests` pins. M for device testing across input methods and a written recipe. Risk: every family's chain differs and nobody sees it fail, so the guide must insist on a test routine.

## 7. Option C: alert built into the app, local network only

**What they get.** Get Attention also sends a small encrypted alert to a paired Brickson on a caregiver device. The device shows or sounds a loud repeating alert and can acknowledge. The person sees "heard" or "not reachable".

### C.0 The platform-audit note, checked

What I can confirm [Apple doc]:
- iOS 26 has a Wi-Fi Aware framework: entitlement `com.apple.developer.wifi-aware` with `Publish` and `Subscribe`, services declared under `WiFiAwareServices` in Info.plist, and no Wi-Fi network, router or internet needed.
- Pairing is through DeviceDiscoveryUI (a PIN step) or AccessorySetupKit, which is aimed at hardware accessories [third-party write-up]. Paired devices persist as `WAPairedDevice`.
- Devices: iPhone 12 and later [Apple TN3111]. The iPad list (10th generation and later, mini 6 and later, Air 4 and later, Pro 11-inch 3rd and later, Pro 12.9-inch 5th and later) comes from a MacRumors report, not an Apple table. Test `WACapabilities.supportedFeatures`.

What the audit overstated:
- Apple's overview says an app can connect to paired devices while it is running, in the foreground or the background, and can be run through existing mechanisms such as BackgroundTasks. That is not wake-on-connect. Nothing I found says an incoming Wi-Fi Aware connection launches a suspended or killed app. BackgroundTasks is opportunistic [reasoned]. Write it as "works while the app is running; wake-on-connect undocumented; verify on two devices."
- "Any local-network use needs NSLocalNetworkUsageDescription and NSBonjourServices" is right for the Bonjour path [Apple TN3179]. DeviceDiscoveryUI's page says people do not have to authorize full local-network access because the system manages the connection. Treat the keys and the prompt as known for Bonjour and unknown for the picker and Wi-Fi Aware paths. That is a device check.
- Wi-Fi Aware needs no router, so the policy's "same local network, such as your home Wi-Fi" would be untrue if it is the transport. Note only: network code is a hard stop.

### C.1 Background reality, per state of the caregiver's device

| State | C1 station on Bonjour or app-service | C1 over Wi-Fi Aware | C2 Local Push plus Critical Alerts |
|---|---|---|---|
| Brickson in front, screen on | works [Apple doc] | works | works |
| Behind another app or Home | fails: app suspended, listener and Bonjour registration lost [Apple TN2277, DTS answers; old but consistent] | connection works "while running"; no documented wake [Apple doc] | extension keeps the link by design [Apple doc]; device check |
| Screen locked | same as behind another app | same | works by design; sound only if Critical Alerts is granted and allowed |
| App killed (swipe or iOS) | fails | undocumented | undocumented for swipe-away; device check |
| Low Power Mode | foreground keeps running; auto-lock may shorten [unverified] | unverified | unverified |
| Wi-Fi off | fails | needs the Wi-Fi radio on, not a router | fails; works only on the Wi-Fi names registered |
| Silent switch and Focus | in-app `.playback` sound plays; Focus filters notifications, not app audio [repo rule plus reasoning; test] | same | ordinary notification sound is muted by the silent switch; Time Sensitive passes Focus but not the switch; Critical passes both [third-party tables] |

Sender (the person's device):
- Works while Brickson is open, which the wake policy already keeps true.
- Fails if Brickson is backgrounded or locked (the Get Attention button is not visible then anyway).
- Fails if Wi-Fi is off or the networks are isolated (guest or facility Wi-Fi).

**C2 requirements** [Apple doc unless noted]:
- The `app-push-provider` network-extension entitlement, requested through Apple's page; approval odds and timing are unpublished [community].
- An extension target.
- An SSID list the extension is launched on.
- A "local server" for the extension to connect to; here that would be the person's Brickson listening [reasoned, untested].
- Critical Alerts, a second entitlement by request, for the silent switch. Apple grants it only for health, safety, security and emergency uses, and reviews take days to weeks [third-party].
- A paid developer team; `DEVELOPMENT_TEAM` is still empty [repo].

**Bluetooth variant, which is not "network code" by the letter.**
- The caregiver app scans in the background for one service UUID, which needs `bluetooth-central` and a Bluetooth permission string [Apple doc].
- The system relaunches a system-terminated app on a matching event (TN3115). A user force-quit app is not relaunched [community, Apple engineer].
- Range is short, scans are reported to stall at times, and the policy would change from "local network" to Bluetooth.
- Tricks to stay alive are out: silent audio is forbidden by DECISIONS and risks App Review guideline 2.5.4 [community].
- BLE is the only entitlement-free way to wake a sleeping phone. The owner decides if it counts as relaxing the rule's spirit.

### C.2 Transport choices

| Option | Keys and prompts | Router | Notes |
|---|---|---|---|
| Bonjour plus Network.framework | `NSLocalNetworkUsageDescription`, `NSBonjourServices`, prompt on first use [Apple TN3179]; denied shows as `NWPath.UnsatisfiedReason.localNetworkDenied` [Apple doc] | shared Wi-Fi | all iOS 26 devices; works on home Wi-Fi, fails on isolated guest or facility Wi-Fi; the instance name defaults to the device name unless set, so set a random one [Apple doc]; `includePeerToPeer` costs power and Apple warns an idle listener can be timed out [Apple doc] |
| DeviceDiscoveryUI app service (`DevicePicker`, `NWListener(applicationService:)`) | system picker and encrypted link; Apple says full local-network authorisation is not needed [Apple doc] | shared network | documented examples are Apple TV and Watch with iPhone; reconnection without the picker, iPhone-to-iPad behaviour and unattended stations are unverified; test first |
| Wi-Fi Aware | entitlement plus Info.plist; system pairing | none | newer hardware only; background wake undocumented |
| Multipeer Connectivity | n/a | n/a | deprecated in Xcode 27 [Apple TN3151, TN3213]; do not use |

### C.3 Pairing without accounts, trust, and what "encrypted" means

- System-managed pairing (the pickers) leaves Brickson holding no secret, so the Keychain rule, backups and key leaks stop being our problem.
- App-managed pairing means a 256-bit secret shared at pairing. It lives in a protected file, readable while the device is locked, excluded from backups and from the backup export, and not in the Keychain. Apple's documented TLS-identity route stores the identity in the Keychain [Apple doc], which AGENTS.md forbids. So use a pre-shared key or sealed messages, not self-signed TLS certificates [reasoned].
- Do not use bare trust-on-first-use. Any device on the LAN that shows up first could pair. Use a confirmation code shown on one device and typed or compared on the other; a short code alone is weak against offline guessing.
- "Encrypted" should mean the following. Messages are sealed with an authenticated cipher (CryptoKit, an Apple framework) under the pairing key. Each has a counter so replays are rejected, and anything unreadable is dropped. The device name travels inside the sealed part. Use counters, not wall-clock timestamps across two devices (AGENTS.md: time is `ContinuousClock`).
- What an onlooker on the same network still sees: that Brickson is present, which two devices talk, and message size and timing. The policy should say so. No forward secrecy unless a fresh key exchange is added.

### C.4 How the person knows, and what the caregiver does

- Send a heartbeat while Brickson is open and caregiver alerts are on, so a dead link shows before an emergency.
- Show problems as text in Home's reserved status slot. That slot is built from invisible copies of every `HomeAudioIssue` case, so new cases (link down, alert not confirmed, caregiver volume low, local network blocked) must keep the reserved height, with layout tests (invariant 11). Quote invariant 4: "passive, layout-reserved text that never replaces the message, never adds a dismiss control and never moves a target."
- The receiver's heartbeat reply carries its output volume and audio-session health (mirroring the existing 0.2 threshold), so the sender can show "Caregiver device may be silent".
- After Get Attention the receiver sends an acknowledgment; with no ack in a window the sender shows "No answer". A first successful test alert must be required at setup.
- Local sound comes first and never waits for the network. Repeats of one alert episode are absorbed, like `SpokenUtteranceTracker`, so a resting gaze does not flood the caregiver.
- The station shows full-screen: a large repeating alert, an "I'm coming" control, and a separately placed stop-sound control (per the design rule). Reaching station mode must be family-only, in Settings.
- Open decision: does a remote ack stop the person's alarm? Recommended default is no: show a passive "Caregiver heard you".

### C.5 Collisions beyond invariant 9

- The AGENTS.md privacy bullet and Code Review Rules ("Network code, accounts, analytics, cloud sync, a third-party package or SDK, or a new data type in the privacy manifest (invariant 9)") would flag it until narrowed; every reviewer will flag the exception by design and the owner decides.
- `.github/copilot-instructions.md`: "Never suggest a package, an SDK or a network service."
- DECISIONS "Code scanning" names network code such as caregiver alerts as a trigger to revisit Swift CodeQL, which costs a Mac job per pull request.
- `project.yml` says `ITSAppUsesNonExemptEncryption: false`, "(none at all today)". Re-check the export answer when TLS or CryptoKit arrive. Apple's key text says NO is for no encryption or only exempt encryption; I have not read the exemption overview [Apple doc], so assert nothing.
- `AppBundleTests` pins Info.plist and the privacy manifest. New keys need new pins.
- Swift 6 callbacks: every Network callback is off the main thread and needs a test in `OffMainThreadCallbackTests`. The iOS 26 structured-concurrency APIs help.
- Review-notes burden: App Review cannot test with one device. Provide steps or a video.

### C.6 Policy and privacy label

- Sentences that become untrue by transport:
  - "iOS asks your permission..." (the picker may not prompt).
  - "same local network" (Wi-Fi Aware).
  - The Local Network switch (it may not exist).
  - "announce Brickson on the network" (the service type reveals Brickson, which matches the policy; the instance name must be random).
- Add that alerts arrive only while the caregiver's device has Brickson open in front (C1) and that the heartbeat shows link problems. Without this the policy is untrue by omission.
- Privacy label: by Apple's definition data is "collected" when it leaves the device in a way the developer or partners can access it longer than needed to serve a request [third-party forum quoting Apple, not re-read]. A device-to-device alert the developer never sees stays "Data Not Collected". Any file-timestamp or similar required-reason API used by new code needs a manifest reason [reasoned].

### C.7 Draft DECISIONS.md exception (to be decided, not added)

"Caregiver alerts on the local network (exception to invariant 9). Invariant 9 forbids 'servers or network code'. This entry allows only: code that advertises and finds the paired caregiver device on the local network or a direct Wi-Fi link and exchanges three small sealed messages (alert, acknowledgment, heartbeat). The only server allowed is the listener inside the receiving Brickson. Still forbidden: any internet connection, push services, CloudKit, analytics, accounts, third-party packages, Keychain storage. Conditions: off until turned on; the local sound never waits for the network; failures show as passive text (invariant 4); the policy section is true word for word; `AppBundleTests` pins the keys; reviewed every release."

### C.8 Cost and risk

- C1: L, plus hardware testing that cannot be automated (two devices, several router types, isolation, Low Power Mode, Wi-Fi off).
- C2: XL, plus waiting on Apple.
- Trust cost: the promise moves from "nothing leaves" to "alerts leave only to a device you paired, never over the internet". An alert that silently fails is worse than none (false reassurance), so ship only with heartbeat, ack and a required test.

## 8. Option D: Apple Watch

- A Brickson Watch app cannot use Network framework, Bonjour or sockets, except while streaming audio, during a CallKit VoIP call, or as an app-service listener for an Apple TV app [Apple TN3135]. The simulator always allows low-level networking, so it would mislead.
- A Watch app would have to get alerts from the paired iPhone app, which is suspended when locked (same wall as C2).
- Extended runtime sessions run for a limited time and mostly must start while the app is active [Apple doc].
- A watchOS target is a new platform, which DECISIONS "Minimum iOS 26, iPhone and iPad" does not allow today.
- The Watch benefits free through B (mirrored messages when the iPhone is locked) [Apple Support].
- Verdict: no Watch app.

## 9. Option E: nothing beyond sound in 1.0, with a documented later path

- Delete from site/privacy/index.html:
  - the whole "If you turn on caregiver alerts" section (lines 69-77);
  - line 111's final sentence, "Only Get Attention can alert a caregiver's device, and only if you turn on caregiver alerts.";
  - then bump the Effective date (line 39).
- Decide separately whether the "Siri and Shortcuts" section stays; that depends on whether B's intent ships.
- Update AGENTS.md's three-planned-features bullet and HANDOFF.
- Add an in-app static line: "Get Attention makes sound on this device. It does not contact anyone."
- Ship a family guide: outside call systems, a baby monitor, the A device checks, and the B recipe as documentation only.
- Documented later path: this memo's section 10.
- Cost: S. No invariant is touched.

## 10. Recommendation

**1.0:** E plus A. Port the alarm, run the next-room and Bluetooth device checks, delete the policy section, ship the family guide. Do not build or promise anything that reaches a caregiver.

**Later, in order:**
1. B-lite: a "Start Get Attention" intent, reworded Siri and Shortcuts policy section, and a tested recipe (AssistiveTouch, Emergency Bypass, optional Home scene).
2. C1 behind a recorded exception, after a throwaway two-device experiment outside the repo. Answer, on real devices: does the picker reconnect without a tap, does a prompt appear, does an incoming connection wake a backgrounded app, and what does a family's router do.
3. Prefer system-managed pairing if the experiment allows it.
4. Not planned: C2, D, Multipeer, CloudKit or push.

**Set aside (considered):** push through Apple's servers or ours (hard stop). CloudKit subscription push [Apple doc] avoids our server but needs iCloud sign-in and internet, and contradicts "No iCloud sync in 1.0" and the policy's "never goes over the internet". Emergency SOS. Silent-audio keep-alive.

## 11. Owner decisions, with recommended defaults

1. Ship any caregiver alert in 1.0? Default: no (E plus A).
2. Is a local-only exception to invariant 9 acceptable in principle? Default: yes for C1 only, recorded as C.7, after the experiment.
3. Allow a throwaway two-device experiment outside this repo when 1.0's core is done? Default: yes, later.
4. Station (C1) or pocket phone (C2)? Default: station only; never promise pocket delivery.
5. Request Apple's entitlements now (Local Push, Critical Alerts)? Default: no; they need a paid team and a described feature.
6. Does a remote acknowledgment stop the person's alarm? Default: no; show "Caregiver heard you".
7. Pairing and secrets: Keychain exception or not? Default: no Keychain; system-managed pairing if possible, otherwise a protected file excluded from backups.
8. Heartbeat and required test alert when alerts are on? Default: yes.
9. B-lite intent: 1.0 or 1.1? Default: 1.1; documentation only in 1.0.
10. If a Bluetooth speaker route drops mid-alarm: keep sounding on the device speaker or stop? Default: keep sounding and show text (needs the alarm direction's agreement).
11. Count Bluetooth wake as relaxing invariant 9's spirit? Default: yes; do not build without a decision.
12. Watch app? Default: no.

## 12. Not verified

- Wi-Fi Aware wake-on-connect.
- Picker reconnection and prompt behaviour.
- Local Push and Critical Alerts approvals.
- Shortcuts silent send and locked-device behaviour.
- Low Power Mode effects.
- Export-compliance answer.
- iPad SMS forwarding.
- The Tobii and Smartbox features (snippets only).
- Any iOS 27 changes (one search found none for these topics).
- The current App Review text for HomeKit and 2.5.4 (read only via secondary sources).

## 13. Sources

Repo: AGENTS.md; docs/DECISIONS.md; docs/HANDOFF.md; docs/PORTING.md; docs/LESSONS.md; site/privacy/index.html; Brickson/Resources/PrivacyInfo.xcprivacy; project.yml; Brickson/Speech/AudioSafetyPolicy.swift; .github/copilot-instructions.md.

Apple docs (via Context7):
- https://developer.apple.com/documentation/wifiaware (overview; paired devices; background statement)
- https://developer.apple.com/documentation/wifiaware/connecting-paired-devices
- https://developer.apple.com/documentation/wifiaware/building-peer-to-peer-apps
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.wifi-aware
- https://developer.apple.com/documentation/devicediscoveryui
- https://developer.apple.com/documentation/devicediscoveryui/devicepicker
- https://developer.apple.com/documentation/accessorysetupkit
- https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- https://developer.apple.com/documentation/technotes/tn3111-ios-wifi-api-overview
- https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos
- https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules
- https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api
- https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework
- https://developer.apple.com/documentation/network/nwlistener/service-swift.struct/init(applicationservice:)
- https://developer.apple.com/documentation/network/nwlistener/service-swift.struct/init(name:type:domain:txtrecord:)-1lb30
- https://developer.apple.com/documentation/network/nwparameters/includepeertopeer
- https://developer.apple.com/documentation/network/nwpath/unsatisfiedreason-swift.enum/localnetworkdenied
- https://developer.apple.com/documentation/network/creating-an-identity-for-local-network-tls
- https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol
- https://developer.apple.com/documentation/networkextension/local-push-connectivity
- https://developer.apple.com/documentation/networkextension/neapppushprovider
- https://developer.apple.com/documentation/networkextension/maintaining-a-reliable-network-connection
- https://developer.apple.com/videos/play/wwdc2020/10113/
- https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes
- https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals(withservices:options:)
- https://developer.apple.com/documentation/appintents/audioplaybackintent
- https://developer.apple.com/documentation/appintents/runsystemshortcutintent
- https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy-1r9kh
- https://developer.apple.com/documentation/watchkit/wkextendedruntimesession
- https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- https://developer.apple.com/documentation/cloudkit/ckquerysubscription
- https://developer.apple.com/documentation/messageui

Apple Support:
- https://support.apple.com/en-us/108369 (Watch versus iPhone notifications)
- https://support.apple.com/guide/shortcuts/intro-to-automation-shortcuts-apd690170742/ios (run without asking)
- https://support.apple.com/guide/shortcuts/run-a-shortcut-from-a-url-apd624386f42/ios
- https://support.apple.com/en-us/101583 (Send Message and "Show When Run")
- https://support.apple.com/en-us/108127 and https://support.apple.com/guide/iphone/allow-or-silence-notifications-for-a-focus-iph21d43af5b/ios (Emergency Bypass)

Community and third-party:
- https://tidbits.com/2022/07/22/use-assistivetouch-for-customizable-shortcuts-on-the-iphone-and-ipad/
- https://discussions.apple.com/thread/255141835 (locked-phone automation)
- https://www.tekrevue.com/tip/repeat-alerts-iphone/
- https://www.alsforums.com/community/threads/easy-to-press-call-system.44905/post-468852
- https://community.at3center.net/t/83ykvpl/call-systems-in-facilities?r=q6y1mrl
- https://alsa.simplelists.com/at/cache/6386627/2.html (ALS Association assistive-technology list; seen in search results, no longer loads)
- https://drexel.edu/~/media/Files/medicine/drexel-pdfs/student-life/drexcel-eog-based-alert-system-for-aphonic-als-patients.ashx?la=en
- https://learn.tobiidynavox.com/catalog/info/id:957 (snippet only)
- https://thinksmartbox.com/?p=21091 (snippet only)
- https://sf-fire.org/fire-alarm-sleeping-area-upgrade-faq
- https://www.iclarified.com/98881/speaker-volume-test-iphone-17-pro-max-vs-iphone-16-pro-max
- https://commercial-acoustics.com/case-studies/door-flanking-demising-walls-stc-test/
- https://www.macrumors.com/2025/06/21/ios-26-adding-two-new-wi-fi-features/
- https://dev.to/arshtechpro/wwdc-2025-wi-fi-aware-framework-revolutionizing-device-to-device-communication-on-ios-115m
- https://www.wwdcnotes.com/notes/wwdc21/10091
- https://newly.app/articles/critical-alerts-entitlement
- Apple developer forum threads, search snippets only: https://developer.apple.com/forums/thread/840808, /685454, /772637 (suspension), /739307 (Bluetooth force-quit), /819261 (Local Push entitlement), /794822 (Critical Alerts), /787775 (Wi-Fi Aware devices), /667097 (privacy "collect"), /672329 (guideline 2.5.4)
- https://developer.apple.com/library/prerelease/mac/technotes/tn2277/_index.html (TN2277)
