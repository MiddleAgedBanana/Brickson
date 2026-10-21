# Recorded phrases ("message banking"): options memo for Brickson

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Date 2026-10-16. Read-only study: nothing was edited, built, or run on a simulator. Worktree: `the repository root (a planning worktree on the owner's Mac)`.

Evidence tags: **(A)** Apple documentation or Apple support page, read this session (API pages through the Context7 index of Apple docs, never fetched from developer.apple.com directly). **(R)** another page I read. **(S)** search-result summary only (page returned 403, a certificate error, or an unreadable PDF). **(F)** forum report, no Apple reply. **(I)** my inference or estimate. **(Sib)** the sibling reports under `docs/recon/2026-10-15/` ([`README.md`](../README.md), `docs/recon/2026-10-15/*.md`), which are untracked and unreviewed. Bracketed numbers are in the source list at the end.

---

## 1. Bottom line

- **Build it, in stages. Do not choose Option A as the default.** Stage 1: make a recording a stored, backed-up file that Brickson plays with exactly the speech engine's rules (B-core), and accept audio made elsewhere (C). Stage 2: record inside the app (B-record), after real-device checks. Stage 3, only if families ask: a separate Messages area for long legacy messages (D).
- **Why that order.** The closing window is per person, not per release, and people can bank today with free tools (myMessageBanking, Voice Memos) and bring the files later. Import needs no microphone permission, no audio-session category change and no policy sentence about the microphone. In-app recording is the only part that can hurt speech (category flips, phone calls, silent takes), and it adds the least that Voice Memos does not already do.
- **Is the recon's R2 too late?** For the in-app recorder, no, provided guidance ships now and import by R1. If nothing exists before R2, it is too late for anyone diagnosed this year.
- **The code that matters most is not recording.** It is turning `SpeechService` into one playback coordinator. `repeatLast()` re-synthesizes `lastSpokenText`, so Again would speak a recorded phrase in the synthetic voice. `SpokenUtteranceTracker.repeatWindow` is 20 s and is refreshed only by word callbacks. `audioPlayerDidFinishPlaying` is not called on interruption (A). That refactor is needed by Get Attention anyway.
- **Smallest first step** (details in section 9): a guidance page, the coordinator seam built with the Get Attention port, a backup manifest with a versioned file list, and a throwaway device spike once `DEVELOPMENT_TEAM` is set. **Not** a V2 schema yet; LESSONS ("Add stored fields with their feature") forbids it.

---

## 2. The two facts the coordinator added, checked

1. **`.playAndRecord` fails during a call. Confirmed, high confidence (A).** Apple's `setActive` page: activating a `record` or `playAndRecord` session while another app hosts a call fails with `AVAudioSessionErrorInsufficientPriority`. A `playback` session may activate during a call but cannot capture the call's microphone [23]. It also says deactivating a session with running audio objects stops them and returns `isBusy`.
   - Rule that follows: **the recorder borrows the audio session and gives it back.** (The audio session is the iOS setting that decides how an app's sound is routed and what it may interrupt.) Speaking, recording playback and the alarm always use `.playback` with the existing `.mixWithOthers` fallback in `ensurePlaybackAudioSession()`. `.playAndRecord` exists only from the person's Record press to the end of the take. Every exit path restores `.playback` (section 4, B5).
2. **Personal Voice cannot be rendered to a file.**
   - **Apple's support page (A, read): third-party apps "cannot capture speech from Personal Voice".** This is high confidence at policy level [20].
   - The API-level refusal in `write(_:toBufferCallback:)` is **(F)**: forum thread 736148 reports the console line "Cannot use AVSpeechSynthesizerBufferCallback with Personal Voices, defaulting to output channel", with no Apple reply [40]. Apple's API reference excerpt lists no exception (A) [see source 40 note].
   - Design consequence: a recording can come only from the microphone or from an imported file. **Nothing in this memo depends on the forum report either way.**
   - The same thread reports Personal Voice failing in background playback (F, unverified). If true, recordings are more robust than Personal Voice when the screen locks. It is a device check, not a claim.

---

## 3. What is known

### 3.1 Message banking in practice

- **Definitions.** Message banking records whole words, phrases, stories and sounds in the person's own voice, inflection and intonation. It plays back as recorded and cannot be recombined into new sentences. Voice banking builds a synthetic voice that can say anything but is not a replica [1][9][10]. One speech-language pathologist's answer: message banking is the only way to make personal messages sound like the person's own voice, so it should be encouraged even when the client mainly wants a synthetic voice [9].
- **Timing.** Team Gleason says start as early as possible, and that options remain after speech changes (a relative records, or a voice is built from earlier recordings) [1]. Costello advises recording in real moments rather than at a desk, starting within days of diagnosis (Sib; original handout unreadable to me) [12][50].
- **Why it is tight.** 80 to 95 percent of people with ALS eventually cannot meet daily needs with natural speech, and once intelligibility falls it can fall quickly (R) [14]. In a 2018 survey most patients, family and clinicians had never heard of message banking, and all were interested (R, abstract) [13].
- **Scale.** Boston Children's reports more than 200 people with ALS banking from 150 to more than 4,000 messages (S, program statement) [12].
- **Formats in the field.**
  - Tobii's free Message Bank, run with Boston Children's, takes **WAV** uploads [3], lets you download a **zip** (inner format not stated), and imports into Communicator 5 [2][4].
  - Grid 3 imports mp3, m4a, wav, wma and zips, and **uses the file name as the message text** [5]. Grid for iPad imports MP3 [6].
  - An NHS guide recommends WAV or MP3, says few apps can import banked messages, and warns that messages recorded inside some AAC apps may work only there (S) [8].
- **Evidence quality.** Clinical guidance and one survey. I found no controlled outcome study (searches were limited).
- **Proxy recording** (a relative who sounds similar records) is endorsed by clinicians [1][9]. The recon's default: allow it, and show whose voice plays (Sib).

### 3.2 What Personal Voice cannot do (all from Apple's support page, A/R [20][21][22] unless marked)

- It is for the person's own personal, non-commercial use. A **Legacy Contact cannot access it**. Deleting a voice is permanent. Apps can speak with it but cannot capture it.
- It is stored encrypted on the device. With Share Across Devices, an encrypted copy goes to iCloud.
- iOS 26 setup needs only 10 phrases and under a minute [21]. Languages in the Apple page I fetched (it covered iOS 27): **English (US), Mandarin (mainland China), Spanish (Mexico)** [22]. Anyone else has no own-voice option in Brickson except recordings.
- I did **not** find a source that tests whether a synthetic voice can laugh, emphasize or sing. Clinical sources say a synthetic voice is not a replica and does not carry the person's expressiveness [9]. Treat laughter, in-jokes and singing as unmeasured.

### 3.3 How other apps handle it

- **Proloquo2Go:** in Edit mode, record audio into a button; it replaces the synthesized message for that button; an Actions setting chooses "add to message" or "play right away" [7].
- **Grid for iPad:** Settings, Speech, Message banking: record, import, delete, organise [6].
- **Predictable:** grid items can carry audio recordings and message-banked files (S).
- **Speech Assistant AAC:** claims to play recordings in calls on iOS 18 (Sib, App Store listing).
- **Pattern:** recording per button, in edit mode, with the text kept as the label. Clinicians warn about lock-in, so plain files that leave the app matter.

### 3.4 Platform facts that bound the design

- **Recorder basics.** Recording needs the `record` or `playAndRecord` category (A) [23]. Without permission the recorder captures only silence, so a denied permission looks like a working recorder (A) [24]. A missing `NSMicrophoneUsageDescription` makes the app exit when it touches the microphone (A) [24].
- **`prepareToRecord()` overwrites an existing file at its URL** (A) [25]. A record call that returns false on the first recording after launch is reported by developers; re-creating the recorder after the session is configured fixed it (F) [43].
- **Permission API.** Use the async `AVAudioApplication.requestRecordPermission()`. The older block-based `AVAudioSession` form is documented as possibly calling back on another thread [24], which is the Swift 6 trap in LESSONS.
- **Category switching.**
  - `setCategory` while active causes an immediate route change (A).
  - `defaultToSpeaker` is valid only with `playAndRecord` and is cleared only by changing category (A).
  - `allowBluetoothHFP` is valid only with `record` or `playAndRecord` (A).
  - `.measurement` mode lowers output level (A) [30].
  - iOS 26 adds a high-quality Bluetooth recording option, default mode only and not in the EU (S) [31].
- **Playback facts.** `AVAudioPlayer.volume` is 0 to 1, so a quiet file cannot be boosted at playback (A) [27]. `play()` returns a Bool and `init(contentsOf:)` throws (A). After a media-services reset, rebuild audio objects and wait for user action (A) [28]. iOS 26 adds a resumption recommendation; Brickson must not auto-resume from it (invariant 4) [29].
- **Zip.** iOS has no public API to unzip; an Apple DTS answer says so, and the Compression framework does not know the zip structure (F, from Apple staff) [42]. A coordinator `.forUploading` read can **create** a zip (S) [45]. Third-party guides say the Files app expands zips (S, Apple page not retrieved) [44].
  - Consequence: **hospital zips cannot be imported directly without a hand-written reader. Import means ordinary audio files, after the Files app expands the archive.** A zip backup that Brickson could write but not read back is unacceptable.
- **Calls.** Microphone injection (iOS 18.2+) lets AAC apps add audio to calls; Apple's wording is "synthesized speech" (A) [32]. Whether `AVAudioPlayer` audio is injected is unestablished.
- **Data protection.** The default class for third-party app files is "until first user authentication" (S, ambiguous extraction) [36]. `.complete` would make files unreadable while locked, and the sibling plan has lock-screen Emergency and Get Attention via Siri and the Action button (Sib).
- **Privacy label.** Apple's wording of "collect" is about transmitting data off the device for longer than a request needs (quoted in a forum thread) (F) [41]. Audio kept only on the device is therefore not "collected". The HANDOFF answer "No, we do not collect data" stays, but confirm against App Store Connect Help at submission.
- **App Review.** Guideline 2.5.14 (my recollection of the number; text via the index (A) [35]) requires consent and a clear indication when recording. Guideline 2.5.4 limits background audio to intended purposes, so stop recording when the app leaves the foreground.

### 3.5 What the code does today (symbols, not line numbers)

- `HomeView.PhraseGrid` calls `speech.speak(phrase.text)`. Yes and No call `speak(String(localized:))`; they are **not** `Phrase` rows.
- `SpeechService.repeatLast()` calls `speak(lastSpokenText)`.
- `SpokenUtteranceTracker.repeatWindow` is 20 s; only `recordProgress` refreshes it, from `willSpeakRangeOfSpeechString`. `watchForMissedFinish(of:)` polls `synthesizer.isSpeaking` every second.
- The interruption observer calls `stop()` and `recordInterruption(repeatableSpeechActive:)`. The media-services-reset handler rebuilds the synthesizer. Neither knows about a player.
- `StatusArea` reserves its height from `HomeAudioIssue.allCases`, so any new notice must be a new case with a short compact text.
- `PhraseLibraryStore.openForApp()` returns `isVolatile`; Home exposes `isVolatileStore`.
- `PhraseLibrarySchemaV1` already says a recording field arrives in a new schema version. `PhraseLibraryTests.theFirstSchemaIsVersionOne` asserts one schema and no stages, so it changes when V2 lands.
- `PrivacyInfo.xcprivacy` declares UserDefaults CA92.1 only. `AppBundleTests` pins it. `project.yml` has no microphone key.
- Device builds are blocked while `DEVELOPMENT_TEAM` is empty (Sib). Every device check below waits on the owner's developer-account choice.

---

## 4. The options

Stages used throughout: **Early** (speech clear, hands work; recording window), **Middle** (speech hard to understand; touch, voice, switch), **Late** (gaze, head, scanning; family edits), **After** (the family keeps what remains).

### Option A: do not build it

**What it is.** Delete the policy section "If you turn on recorded phrases", the AGENTS.md bullet in "The privacy policy is a promise", and the HANDOFF line; bump the Effective date. Leave the schema alone.

| Stage | What the person gets |
|---|---|
| Early | Nothing in Brickson. Banking happens in other tools, and what they bank cannot come into Brickson. |
| Middle / Late | Personal Voice (3 languages) or a system voice only. No own-voice hedge if Personal Voice is deleted, denied or unsupported. |
| After | Brickson leaves nothing audible. Personal Voice does not pass to family and apps cannot capture what it says [20]. The voice survives only as ordinary audio files made elsewhere. |

- **What it saves.** The microphone permission, the V2 migration, the backup size problem, call-time audio-session risk, and a policy surface.
- **Invariants.** None touched.
- **Cost.** About half a day of documentation. Reversible later; the cost is paid by people whose speech is changing meanwhile.
- **Risks.**
  - Parity gap with Proloquo2Go, Grid, TD Snap and Predictable [5][6][7].
  - Banked WAVs stranded in other tools.
  - Brickson cannot be where a family keeps the recordings.
- **When A is the right call.** The owner wants 1.0 to be the smallest dependable core and accepts all of the above. Pair it with the guidance page so people at least know to bank elsewhere.
- **Sources.** [1][3][5][6][7][9][20][22].

### Option B: recordings attached to phrases

Three slices that can ship separately: **B-core** (schema V2, file store, playback coordinator, fallback, status case, backup carrying files; files get attached by import, see C), **B-record** (permission, recorder, take review, loudness), **B-harden** (normalization, unattached-recordings list, integrity check).

| Stage | What the person gets |
|---|---|
| Early | Record on the tile's editor (B-record) or import Voice Memos and clinic WAVs. Tiles play their own voice. Backups contain plain audio. In-app capture is slower than a phone's Lock Screen recorder for "real moments". |
| Middle | Banked "I love you", names and jokes play from tiles on any input method. A helper can record for them (proxy), shown as such. Recording new material gets harder; the UI must not pressure it. |
| Late | Playback only, dwell-safe: repeat absorption works on recordings of any length; Again replays the recording; a missing file speaks the words and says so. |
| After | Files are ordinary audio in the backup and the family can keep them without the app. |

**Design (what I would do; alternatives noted).**

**B1. Data.** Schema V2 adds optional fields to `Phrase`, all defaulting to nil, so V1 to V2 is `MigrationStage.lightweight` (A) [33]:
- `recordingFileName` (UUID-based, relative to `Recordings/`).
- `recordingDuration`.
- `recordingByteCount`.
- `recordedAt` (stamped by the app, so no file-timestamp API is needed).
- `recordingVoice` (own, or someone else with an optional typed name).

V1 is never edited and the type aliases move. The migration test needs an **on-disk** V1 store, because an in-memory store starts empty and migrates nothing. Alternative: a separate `Recording` model related 1:1. It is better for several takes per phrase or legacy messages as their own entity, but needs a delete rule, explicit deletion in one save, and more tests. Storing audio bytes in SwiftData with `.externalStorage` is rejected: it couples the voice to a store that can fail to open, and the in-memory fallback would have no audio.

**B2. Files.**
- Store files at `Application Support/Recordings/<UUID>.m4a`, beside the SwiftData store.
- Name files by UUID, never by phrase text (text in a file name leaks into logs, crash reports and Grid-style imports [5]). Store a relative name, not a path.
- Keep the default data-protection class. Do **not** set exclude-from-backup: iCloud and computer backups then carry the recordings to a new device, the second device-transfer path.
- Commit order, so every failure leaves the old recording intact:
  1. Record to `Recordings/.incoming/<new UUID>` (never onto an existing path).
  2. Stop, then validate (opens as `AVAudioFile`, long enough, not silent).
  3. The person previews and activates "Use this recording". Replacing asks first.
  4. Move into `Recordings/`.
  5. Set the fields and save.
  6. Only then delete the replaced file.
- A missing file never clears the reference, so a restore can repair it.
- **No blanket orphan sweep.** Files no phrase references (including takes cut off by a call, a timeout or a crash) are listed as "Unattached recordings" with Play, Attach and Delete (asks). Invariant 7 forbids repairs that delete a person's words.
- Recording is disabled when `isVolatileStore` is true, with a visible reason. Never wipe `Recordings/` when the store is reset.

| Step fails | Result | Person sees |
|---|---|---|
| Write or stop | Old recording untouched; any bytes kept in `.incoming` | "Recording failed" |
| Validate | Take kept as unattached; old untouched | "Recording was silent or too short" |
| Move | Old untouched | "Couldn't save" |
| Save | File stays unattached; fields unchanged | "Couldn't save" |
| Delete the replaced file | One extra unattached file | Listed in Unattached recordings |

**B3. Playback is one coordinator, not a second engine.**
- `SpeechService` (or a successor) owns both the synthesizer and a file player behind two small protocols, so tests can drive them. This also covers the Get Attention tone.
- `lastSpoken` becomes an item (text plus an optional recording reference), so **Again replays the recording**. `phraseStartCount` increments for recordings too.
- Repeat absorption is keyed on the same `UtteranceSource.phrase(text)`, so tile, Again and a resting gaze behave as for speech. Because a player has no word callbacks, the engine feeds `recordProgress` from a one-second tick on `currentTime`, stamped with `ContinuousClock`. Otherwise a recording longer than 20 s restarts under a resting gaze.
- `stop()` stops either source. The interruption observer, the missed-finish watchdog and the reset rebuild all cover the player. `audioPlayerDidFinishPlaying` is not called on interruption (A) [26].
- Decide "finished" versus "cut off" from progress, not from which callback arrived (the code audit's M1 applies, Sib).
- Start is synchronous inside the tap: create the player, `play()`, and on any failure speak the words in the same activation (invariant 2). Playback reuses `ensurePlaybackAudioSession()`.
- A runtime "Recording missing" notice is a new `HomeAudioIssue` case with a short compact text, so it lands in the reserved status height. VoiceOver gets the full sentence, informational priority.
- Illustrative shape of the pure decision, which also keeps the tile-tap resolver for speak versus edit (invariant 2) separate:

```swift
nonisolated struct SpokenItem: Equatable, Sendable {
    let text: String                       // label, message row, fallback voice
    let recording: RecordingReference?
}
nonisolated enum PlaybackStep: Equatable, Sendable {
    case play(RecordingReference)
    case synthesize(String)
}
nonisolated enum PlaybackPlan {
    static func steps(for item: SpokenItem) -> [PlaybackStep]      // recording first, then words
    static func notice(recordingFailed: Bool, anythingStarted: Bool) -> HomeAudioIssue?
}
```

**B4. Message row and labels.**
- The message row shows the phrase text and the existing "Speaking" label, which is always laid out and so moves nothing. For a proxy recording the same slot can say "Recording by <name>".
- The tile's accessibility **label stays the visible text**, so Voice Control's "tap <phrase>" still works. "Recording" (or "recording by <name>") goes in the accessibility **value**. The editor row says "Recorded, 4 seconds".
- Candidate editor labels, each unique for Voice Control: "Record your voice for this phrase", "Stop recording", "Play recording", "Use this recording", "Discard this recording", "Delete recording".

**B5. Recorder and session rule (B-record).**
- Entry only from the editor, only when a pure `RecordingGate` allows: edit mode on, store not volatile, permission granted, nothing sounding, no call.
- Ask permission at the first Record, after one plain sentence, never at launch (the opposite of Personal Voice today).
- If activating `.playAndRecord` throws for any reason (`insufficientPriority` in a call), restore `.playback` at once, show a reserved-height notice, and stay idle.
- **Speech never waits on the recorder.** Any speak, Get Attention or Emergency request stops the recorder synchronously, reasserts `.playback`, and speaks. Closing the take happens off the speaking path.
- All exits run one restore: Stop, discard, maximum length (`ContinuousClock`), interruption, route loss, media reset (rebuild, wait for the next press), the app leaving the foreground, edit mode ending, and Emergency.
- A truncated take (call, timeout, crash) never replaces anything; it stays unattached.
- Create the recorder after the session is configured and active, check `record()`'s result, check permission first (denied means silence), and reject a silent take with a visible message.
- No pre-roll: no microphone use and no level check before Record, because the policy says "only while you record".
- Prefer the built-in microphone; do not rely on Bluetooth HFP for quality.

**B6. Editor under invariant 10.** Positions are illustrative; the rule is "different places".

| State | Controls |
|---|---|
| No recording | Record (place 1) |
| Recording | Stop (place 2, not next to Record). Passive "Recording" text with icon and elapsed time. Passive level bar. Record shown disabled in place 1. |
| Take ready | Play take (3), Use this recording (4), Discard take (5, asks first). While previewing, "Stop playing" is a different control from Play. |
| Replacing | Keep takes Use's place; Replace sits elsewhere |
| Has recording | Play, Record again, Delete recording (asks, Keep in its place) |

- Preview before save is **mandatory**. It contains two device risks: VoiceOver announcements captured by the microphone, and a spoken Voice Control "stop" landing in the take.
- No hold-to-record (a gesture) and no auto-stop on silence.
- Edit mode's idle timeout counts a running recording as activity.
- Emergency phrases never open editors, so recording one goes through the list editor, not the tile.
- The recording indicator uses primary ink plus an icon; any new fill is pinned in `PaletteTests` (never white on system red).

**B7. Backup and transfer.**
- Files must go in the exported backup (the policy already says so). Constraints: a zip that Brickson cannot read back is out [42]; typical email attachment limits (about 25 MB, S) rule out emailing large backups; restore never deletes and asks before replacing.
- My default: a folder of plain files (library file, `Recordings/`, and a manifest with a format version and file list), so a family can open the audio without Brickson. A single custom container is the alternative. Coordinate with the editing-backup study.
- Size arithmetic (I): AAC mono at 64 kbps is about 8 KB/s, so 4,000 five-second messages is about 160 MB. Uncompressed 16-bit 44.1 kHz mono is about 5.3 MB/min, about 1.8 GB for the same set.

**B8. Loudness.**
- `AVAudioPlayer.volume` cannot exceed 1.0, so normalizing means rewriting the file at save or import time (peak-limited gain, a pure and testable function). Without it, recordings may sit audibly below synthesized speech, a flavour of invariant 4.
- Normalization needs sample access, so capturing PCM then encoding AAC is attractive. It may also survive a crash mid-take better than an m4a (I; unverified, device check).
- Keeping a lossless original keeps "double dipping" (building a synthetic voice from banked recordings, as Boston Children's describes [11]) possible outside Brickson. Brickson itself cannot do it (network and third-party hard stops).

**B9. Quick controls, Emergency, proxy.** Yes and No are literal strings, not `Phrase` rows (owner decision 7). Emergency tiles may play recordings only if loudness parity passes (decision 6). Proxy voice is allowed and labelled (decision 5).

**Invariants.**

| # | How B meets it, or what it touches |
|---|---|
| 1 | Every recorder control is a `Button`; the picker and share sheet are system controls; no hold-to-record. |
| 2 | Player created and started in the tap. A failed file speaks the words in the same activation. Emergency pre-empts a recorder. |
| 3 | Recording lives only in the editor. Replace, delete and discard ask; Keep takes the asking control's place. |
| 4 | `.playback` for all playback. Interruption names Again and Again replays the recording. Reset rebuilds and waits for user action. Failures are passive and reserved-height. No auto-resume. No system-volume writes (file-level gain only). |
| 5 | Each commit step has a failure-injection test. |
| 6 | New states pinned in `PaletteTests`. |
| 7 | No shipped recordings or prompts. No automatic deletion of any recording. |
| 8 | Having a recording changes no tile position. No "recent recordings" ordering. |
| 9 | No network, SDK, AI transcription or zip library. |
| 10 | Absorption holds for long recordings. Record and Stop, and preview Play and Stop, sit in different places. The review chain is scored by the chain engine. Long messages stay off Home (Option D). |
| 11, 12 | Home tiles unchanged. The screen stays awake as before. |

**Risks.**
- Audio-session regressions that silence speech.
- Loudness mismatch.
- A partial m4a lost on crash (I).
- SwiftData migration with same-named nested models (needs the on-disk test).
- CI cannot prove recording; the simulator has no reliable microphone or sound.
- Policy drift.
- Pressure to record when speech is tiring.
- DECISIONS "No iCloud sync in 1.0" says sync could be added without a migration. True for models, not for files. Record that caveat when V2 lands.

**Sources.** [1][5][6][7][9][11][12][20][23][24][25][26][27][28][29][30][32][33][36][40][41][42].

### Option C: import recordings made elsewhere

**What it is.** A standard file picker (`fileImporter`, security-scoped URLs, copy at once, release access) takes audio files (WAV, MP3, M4A, CAF, AIFF; whatever Core Audio plays) and attaches each to a phrase.

| Stage | What the person gets |
|---|---|
| Early | Bank today in Voice Memos or myMessageBanking, bring the files in later. This separates the closing window from the release date. |
| Middle | Clinic-banked WAVs become tiles that play in their voice. |
| Late | Family imports proxy recordings. |
| After | Nothing is trapped; the originals stay as ordinary audio. |

**Variants.**
- **C1, attach one file** to a chosen phrase. This is the first slice that exercises V2, the file store, playback, fallback and backup. Smallest, safest.
- **C2, batch import** into a new "Imported" category (never merged into existing categories; a merge is a hazard and asks). It shows a preview of count, total size and durations, then confirms.
  - The file name is only a suggested label. Grid's weakness is that the file name becomes the message text [5].
  - The phrase text must be what the audio says (the fallback speaks it), so the person or family edits it. Never keep the original file name as the storage name; names may contain private words.

**Rules.** Validate each file by opening it (`AVAudioFile`). WMA will not open, so say "convert first". Cap size and length. Keep imported bytes as-is by default. Offer "make louder" (writes a new file) later.

**Invariants.**
- Import is an edit, so edit mode only.
- No microphone, no category change, no new audio-session risk.
- Hard stops are satisfied (the system picker is not network code from Brickson).
- It triggers the DECISIONS "Code scanning" revisit condition (opening files from other apps), though backup restore will trigger it first.

**Policy.** The microphone sentence goes. The section is rewritten around "files you add are copied into Brickson's storage on your device and never uploaded", and may state "Brickson does not use your microphone". `AppBundleTests` can pin the absence of `NSMicrophoneUsageDescription` while import-only.

**Cost.** C1 is inside B-core; C2 is about 4 to 6 days more (I). **Risks.** Format zoo; quality varies (hiss, clipping, very quiet files); text and audio can disagree; thousands of files stress the UI.

**Sources.** [2][3][4][5][6][8][34][42][44].

### Option D: legacy messages (recordings for family, not for daily speech)

**What it is.** Longer recordings for specific people or moments. The person need not be the one who plays them.

| Stage | What the person gets |
|---|---|
| Early | Record messages for later. |
| Middle / Late | Family plays them on occasions. |
| After | The key value; the recordings must be exportable as plain files. |

**Variants.**
- **D1, same mechanism, flagged.** Cheap, but drags long, emotional audio into tiles, categories, the Emergency resolver, Again and a two-line message row.
- **D2, own entity** (title, voice, file, duration, no text fallback) behind its own screen. Cleaner; about 6 to 10 days (I).
- **D3, export only.** Recordings are plain files in the backup and each has a Share or Save to Files action. Nothing new to play.

**Rules that apply to any variant.**
- Anything that plays is a speaking control. Keep long messages off Home's dwell path, with Play and Stop in different places, and no scrubbing gestures.
- If the title is not the transcript, a missing file must not speak the title as if it were the message. It shows a reserved-height notice instead. This needs a "speaks title if the recording is missing" flag.
- Recordings of any length need the progress-tick absorption from B3.

**Invariant 7 here.** Invariant 7 does not apply to what the person records; those are their own words and the app never edits or judges them. It does apply to what Brickson ships around the feature: no scripted prompts about illness or death, no end-of-life category names, no default titles; any suggestion list is neutral and opt-in. The second half of invariant 7 (nothing deletes a person's words) is why there is no orphan sweep and no overwrite on restore.

**Sources.** [1][9][10][11][20].

### Rejected alternatives (one line each)

- Always-on `.playAndRecord`: breaks speaking in calls.
- Pre-rendering Personal Voice to files: not allowed [20].
- A zip backup Brickson cannot read: no unzip API [42].
- A Voice Memos share extension: a new target for little gain.
- On-device transcription to auto-label tiles: the `apple-on-device-ai` skill is on the never-apply list, and it would put machine-made words on tiles.
- Audio bytes in SwiftData: see B1.

---

## 5. Privacy label, manifest, Info.plist, policy

**Info.plist** (via `project.yml` properties). Add `NSMicrophoneUsageDescription`, localized, and pin it in `AppBundleTests`. Suggested text, to match the policy: "Brickson uses the microphone only while you record a phrase in your own voice. Recordings stay on this device." Missing it kills the app on first microphone use (A) [24]. `NSMicrophoneInjectionUsageDescription` (calls, iOS 18.2) is a separate key and decision.

**Privacy manifest.**
- `NSPrivacyCollectedDataTypes` stays empty (audio never leaves the device except in backups the person exports).
- No new required-reason API if the code avoids them: no `attributesOfItem`, no creation or modification date keys, no free-space query. Store size and date in the model; handle write failures where they happen.
- Secondary sources disagree on the disk-space code letters (85F4.1 versus E174.1) [46]. **Do not print a code as fact; read Apple's current "Describing use of required reason API" page if an API becomes unavoidable.** The recon already notes that backup will need reasons (Sib).

**App Store Connect.** The "No, we do not collect data" answer stands, assuming Apple's off-device meaning of "collect" [41]; confirm at submission. In the review notes explain the microphone purpose and that recording stops when the app leaves the foreground.

**The policy page already commits to** (`site/privacy/index.html`, section "If you turn on recorded phrases"): microphone "only while you record a phrase, and only after you allow it"; Brickson "shows that it is recording" and iOS shows its own indicator; recordings are "saved on your device with your phrases and are included in backups you export"; "never sent to us"; turning off microphone access "stops new recordings; recordings you already made stay until you delete them in Brickson."

What that implies for the design:
- The mic is not used before Record: no level check, no pre-roll.
- A visible recording indicator exists, as text and an icon.
- Backups carry files.
- A denied permission must still allow playback and deletion.

**The policy changes in more places than that section.**
- "What stays on your device" needs a recordings bullet.
- "Backups" says the file holds "categories and phrases" and that "anyone who has it can read your phrases". It needs recordings, that the file is unencrypted and can be large, and that email limits apply.
- The heading "If you turn on…" implies a switch. There is none planned (the permission is the switch). Rename it ("If you record phrases") or build a setting.
- Bump the Effective date, update AGENTS.md "The privacy policy is a promise", and update the in-app copy once it exists, all in the same pull request as the code.

---

## 6. Device checks (all need a real device; none done)

| Check | Pass looks like |
|---|---|
| Permission | First Record shows the prompt with the purpose string. Denied: playback and delete still work, Record shows a passive reason plus Open Settings. Revoked while running is handled. |
| Silence guard | A denied or muted take is rejected, not saved. |
| Record level | Peak and RMS for normal speech at 30 and 60 cm on iPhone and iPad (with and without case) set the meter and the normalization target. |
| Loudness parity | Same sentence in Personal Voice, a system voice and a recording at one system volume, SPL meter at 1 m, on speaker, wired, AirPods and a Bluetooth speaker. Decide the target. Check the existing low-volume warning treats them alike. |
| Session choreography | Silent switch on. Route before and after on each output. Output returns to the prior route. Built-in mic chosen. AirPods high-quality mic behaviour (not in EU). |
| Calls | Record refused with `insufficientPriority` during a phone call and FaceTime; speech still audible; category restored. A call arriving mid-take closes and keeps the take and speech works after. Whether the far end hears a played recording with Add Audio in Calls on. |
| Interruptions | Siri, alarm, another app during record and playback: playback shows Again and replays; recording closes the take; nothing auto-resumes. |
| Media reset and route loss | Recordings play on the next press after a reset. Unplug or Bluetooth off mid-playback stops it and names Again. |
| Latency | Tap to first sound for recording versus Personal Voice versus system voice, cold and warm. |
| Lock and background | Lock during playback continues. Play after first unlock works. Behaviour before first unlock is understood. Compare Personal Voice (forum report). |
| Backgrounding and edit mode ending mid-take | Take closed and kept. |
| Crash safety | Kill the app mid-take; is the partial file playable? Decides capture format. |
| VoiceOver and Voice Control while recording | Announcement not captured, or the start is sequenced after it. A spoken "stop" does not ruin the take (mandatory preview contains it). |
| Indicators | The orange microphone indicator and the in-app indicator both show; the policy sentence is true. |
| Scale | 10-minute take (battery, thermal, storage); 4,000-file library (import, export, backup time and size); AirDrop and Files path. |
| Input methods | Record and Stop under switch, head and gaze, scored by the chain engine. |

---

## 7. Tests (each names the change that makes it fail)

- **Play-or-speak plan.** Recording present gives [play, synthesize]; none gives [synthesize]; blank text with a missing file gives no step plus a notice. Fails if the fallback is dropped or the order flips.
- **Again.** Replays the recording. Fails if `lastSpoken` keeps only text.
- **Tracker with ticks.** A 25 s recording is absorbed at 21 s while ticks arrive and restarts after 20 s of silence. Fails if ticks are not forwarded.
- **Fake-player failures.** `init` throws or `play()` returns false: the words speak, the notice is set, the reference stays. Fails if the reference is cleared.
- **Interruption, reset, finish-versus-cut-off.** Player stopped, "Stopped, Again" set, no auto-restart; a finish before the end counts as cut off.
- **`RecordingGate` truth table.**
- **Session choreography** with an `AudioSessioning` fake (the code audit proposes this seam, Sib): activation throwing `insufficientPriority` ends on `.playback` with the notice; every exit path restores `.playback`; a speak request during recording stops the recorder before activation.
- **Commit failure injection**, one per step in the B2 table, asserting old recording intact, nothing half-changed, something shown.
- **Migration.** Open an on-disk V1 store (temporary directory) with the V2 plan; rows and relationships intact; new fields nil.
- **Unattached listing never deletes.**
- **Backup round trip.** Files byte-identical; restore never deletes; replace asks.
- **Off-main tests** for `audioPlayerDidFinishPlaying`, `audioPlayerDecodeErrorDidOccur`, `audioRecorderDidFinishRecording`, `audioRecorderEncodeErrorDidOccur`, and the permission result.
- **`AppBundleTests`.** The mic key present with non-empty text in builds that record (absent in C-only builds); the manifest's collected data empty and its API list as pinned.
- **`PaletteTests`** for new pairs.
- **UI tests** on iPad and iPhone: editor controls keep their frames across states; the "Recording missing" notice appears in the reserved slot without moving anything. No real recording in CI.

---

## 8. Rough cost (working days for someone who knows the code; my estimates, I)

| Slice | Days | Depends on |
|---|---|---|
| Guidance page + README line | 0.5 to 1 | owner approval |
| Playback coordinator (shared with Get Attention) | 4 to 6 | none |
| Backup manifest with a versioned file list (extra) | 2 to 4 | editing-backup study |
| B-core + C1 (V2, store, commit, playback, fallback, status case, tests, migration test) | 8 to 12 | phrase editor (port step 6), coordinator |
| C2 batch import | +4 to 6 | B-core |
| B-record | 10 to 15, plus 2 to 3 for device checks | B-core, device build |
| Loudness normalization | 2 to 4 | PCM capture or a file rewrite |
| D3 / D2 | 1 / 6 to 10 | B-core |
| Option A | 0.5 | none |

---

## 9. Recommendation, smallest first step, owner decisions

**Recommendation.** Option B+C, staged: coordinator, then B-core with C1, then C2, then B-record after device checks, then D only on demand (D3 first). Not A.

**Smallest first step that keeps options open** (no schema change yet):
1. **Guidance page** (owner approves wording; promises no dates): bank now, outside Brickson, using myMessageBanking or Voice Memos; keep the originals; prefer WAV or M4A; name each file with the exact words it says; do not rely on Brickson to import yet. This covers the closing window without code.
2. **Playback coordinator seam**, built with the Get Attention port: `SpokenItem`, an engine protocol per sound source, progress ticks, and interruption, reset and watchdog coverage. The alarm tone is its first tenant. No recordings yet.
3. **Backup manifest** with a format version and a (possibly empty) file list, designed with the editing-backup study. It is expensive to change later.
4. **Device spike**, throwaway and uncommitted, once `DEVELOPMENT_TEAM` is set: tap-to-sound latency, loudness parity, category choreography, call behaviour, lock playback, crash-safe capture. Results go in the HANDOFF device-check table.

**Owner decisions with recommended defaults.**

| # | Decision | Default |
|---|---|---|
| 1 | Build recordings at all | Yes, staged |
| 2 | Order | Files, playback and import first; in-app recorder after device checks; import and playback by R1, recorder R2 |
| 3 | Guidance page now | Yes |
| 4 | In-app capture format | AAC mono 44.1 kHz about 64 kbps; imports kept as given; lossless only if the owner wants double-dipping to stay possible |
| 5 | Proxy recordings | Allow; label the voice (own, or someone else with an optional name); show it in the editor and the message row; value on the tile, never the label |
| 6 | Emergency tiles may play recordings | Yes, once loudness parity passes; words always the fallback; recorded through the list editor |
| 7 | Yes and No recordings | Allowed; implemented as library entries so they get the same editor, backup and fallback; after the first slice |
| 8 | Legacy messages | D3 first; D2 only if families ask; never on Home |
| 9 | Longest tile recording | 30 s (a placeholder to set with a speech-language pathologist); longer goes to the Messages area only |
| 10 | Longest take | 60 s for a tile, 10 minutes for a message, timed with `ContinuousClock` |
| 11 | Backup container | Folder of plain files plus manifest; no zip |
| 12 | Policy | No on/off switch; rename the heading; add the Backups and device-storage sentences; bump the Effective date in the same pull request |
| 13 | Unattached recordings | Listed, never auto-deleted |
| 14 | Questions to ask people with ALS and speech-language pathologists first | Tile plays a recording with a spoken fallback, or stays visibly separate? Which ten utterances first? Are Yes and No wanted? How long before a recording feels like a message? |

---

## 10. What I could not establish

- Anything about sound, latency, loudness, routes, calls or dwell: no device and no build.
- Whether `AVAudioPlayer` audio is injected into calls with Add Audio in Calls on.
- Whether the Files app expands zips (third-party guides only).
- Whether Personal Voice's `write(_:toBufferCallback:)` refusal is real (forum only).
- Whether a partial m4a survives a crash (my inference).
- The Costello 2016 handout, Boston Children's pages, the ALS Association pages and the NHS page: unreadable PDFs, 403s or a certificate error. Their content here comes from search summaries and the sibling report.
- Required-reason code letters (sources disagree).
- The default data-protection class (ambiguous extraction of Apple's guide).
- Controlled outcome evidence for message banking: none found.
- All effort numbers are mine.
- Author discrepancy: the Trinity repository record lists Costello and **Smith** as authors of the 2021 paper [11]; the sibling report says "Costello & Fishman". I used Smith.

---

## Appendix: sources

**Practice and evidence**
- [1] Team Gleason, Voice Preservation (R): https://teamgleason.org/pals-resource/voice-message-banking/
- [2] Tobii Dynavox, What is the Message Bank (R): https://us.tobiidynavox.com/blogs/support-articles/what-is-the-tobii-dynavox-message-bank
- [3] Tobii Dynavox, upload message recordings, WAV (R): https://www.tobiidynavox.com/blogs/support-articles/how-do-i-upload-message-recordings
- [4] Tobii Dynavox, import banked messages (zip) into Communicator 5 (R): https://www.tobiidynavox.com/blogs/support-articles/how-do-i-import-my-banked-messages-into-the-communicator-5-software
- [5] Smartbox, import banked messages into Grid 3 (R): https://hub.thinksmartbox.com/knowledgebase/how-do-i-import-banked-messages-into-grid-3/
- [6] Smartbox, message banking in Grid for iPad (R for the Settings path; MP3 and Dropbox from S): https://hub.thinksmartbox.com/knowledgebase/message-banking/
- [7] AssistiveWare, Proloquo2Go record audio (R): https://www.assistiveware.com/support/proloquo2go/organize/buttons/record-audio and https://www.assistiveware.com/blog/new-in-proloquo2go-6-audio-recording
- [8] NHS Kent and Medway, message banking (S): https://www.ekhuft.nhs.uk/patients-and-visitors/services/radiological-sciences/medical-physics/kmcat/public/voicebanking/message-banking/
- [9] SpeechPathology.com expert answer (R): https://www.speechpathology.com/ask-the-experts/voice-and-message-banking-8577
- [10] AT3 Center, Preserve Your Voice (R): https://at3center.net/2022/05/24/als-awareness-preserve-your-voice/
- [11] Costello and Smith 2021, AAC 37(4):241-250, DOI 10.1080/07434618.2021.2021554 (S): https://www.tara.tcd.ie/items/92a1fb3d-bbd6-4e7e-9fcf-484a2f60de66
- [12] Boston Children's pages and 2016 Costello handout (S, unreadable): https://healthlibrary.childrenshospital.org/node/147997 and https://www.alsmndalliance.org/wp-content/uploads/2016/12/costello-message-banking-handout.pdf
- [13] Oosthuizen, Dada, Bornman and Koul 2018, IJSLP 20(7):756-765 (R, abstract): https://repository.up.ac.za/items/1e8a39cf-07f1-41fc-abb2-f189c8892972
- [14] Beukelman, Fager and Nordness review (R): https://pmc.ncbi.nlm.nih.gov/articles/PMC3096454/

**Apple (support pages read; API pages via the documentation index (A), not fetched from developer.apple.com)**
- [20] Apple Support, Create a Personal Voice (R): https://support.apple.com/HT213878
- [21] Apple Newsroom, May 2025 (R): https://www.apple.com/newsroom/2025/05/apple-unveils-powerful-accessibility-features-coming-later-this-year/
- [22] Apple, iOS feature availability, Personal Voice languages (R, iOS 27 version): https://www.apple.com/ios/feature-availability/
- [23] `AVAudioSession.setActive(_:)`: https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive%3Aerror%3A
- [24] `AVAudioApplication.requestRecordPermission`: https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29
- [25] `AVAudioRecorder.prepareToRecord()`: https://developer.apple.com/documentation/avfaudio/avaudiorecorder/preparetorecord%28%29
- [26] `audioPlayerDidFinishPlaying`: https://developer.apple.com/documentation/avfaudio/avaudioplayerdelegate/audioplayerdidfinishplaying%28_%3Asuccessfully%3A%29
- [27] `AVAudioPlayer.volume`: https://developer.apple.com/documentation/avfaudio/avaudioplayer/volume
- [28] `mediaServicesWereResetNotification`: https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
- [29] Handling audio interruptions: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- [30] Category options and modes: https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/defaulttospeaker
- [31] Bluetooth high-quality recording (S): https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/bluetoothhighqualityrecording.md
- [32] Adding synthesized speech to calls: https://developer.apple.com/documentation/avfaudio/adding-synthesized-speech-to-calls
- [33] SwiftData `MigrationStage`: https://developer.apple.com/documentation/swiftdata/migrationstage
- [34] SwiftUI `fileImporter`: https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aallowsmultipleselection%3Aoncompletion%3A%29
- [35] App Review Guidelines: https://developer.apple.com/app-store/review/guidelines
- [36] Apple Platform Security, data protection classes (S): https://support.apple.com/guide/security/secb010e978a/web

**Forum and secondary**
- [40] (F) Personal Voice and the buffer callback: https://developer.apple.com/forums/thread/736148
- [41] (F) Apple's wording of "collect": https://developer.apple.com/forums/thread/771790
- [42] (F, Apple staff) no public unzip API: https://developer.apple.com/forums/thread/694893
- [43] (F) `record()` false and silent takes: https://developer.apple.com/forums/thread/727129, https://developer.apple.com/forums/thread/721421, https://developer.apple.com/forums/thread/774681
- [44] (S) Files-app zip guide: https://www.slashgear.com/1739167/how-to-unzip-files-on-iphone-ipad-zip
- [45] (S) Creating zips with `.forUploading`: https://medium.com/parable-engineering/how-to-easily-create-zip-files-in-swift-without-third-party-dependencies-a1c36a451ea1
- [46] (S, conflicting) Required-reason codes: https://blakecrosley.com/blog/privacy-manifest-deep-dive and https://techconcepts.org/blog/privacyinfo-xcprivacy-guide-ios-developers
- [50] (Sib) [`docs/recon/2026-10-15/README.md`](../README.md) and [`docs/recon/2026-10-15/als-aac-research.md`](../als-aac-research.md), [`apple-platform.md`](../apple-platform.md), [`code-audit.md`](../code-audit.md), [`docs-repo-audit.md`](../docs-repo-audit.md)

Note on source 40: the API-reference statement "lists no exception" comes from the Context7 index excerpt of Apple's `AVSpeechSynthesizer.write(_:toBufferCallback:toMarkerCallback:)` page, not from a direct fetch.

**Repository files read** (all under the repository root): `AGENTS.md`, `docs/DECISIONS.md`, `docs/LESSONS.md`, `docs/PORTING.md`, `docs/HANDOFF.md`, `site/privacy/index.html`, `project.yml`, `Brickson/Info.plist`, `Brickson/Resources/PrivacyInfo.xcprivacy`, `Brickson/Library/PhraseLibrarySchema.swift`, `Brickson/Library/PhraseLibraryStore.swift`, `Brickson/Library/StarterLibrary.swift`, `Brickson/Speech/SpeechService.swift`, `Brickson/Speech/SpokenUtteranceTracker.swift`, `Brickson/Speech/AudioSafetyMonitor.swift`, `Brickson/Speech/AudioSafetyPolicy.swift`, `Brickson/Home/HomeView.swift`, `Brickson/App/BricksonApp.swift`, `BricksonTests/AppBundleTests.swift`, `BricksonTests/PhraseLibraryTests.swift`, `BricksonTests/SpeechServiceTests.swift`, `BricksonTests/OffMainThreadCallbackTests.swift`.
