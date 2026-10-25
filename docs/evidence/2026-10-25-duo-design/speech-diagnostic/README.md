# Separate speech-status timeout diagnostic

2026-10-25, Xcode 27.1 (27A9275), iPad Pro 13-inch (M5, 16GB) simulator,
iOS 27.0. This investigates the ordinary UI gate's post-activation Speaking
timeout. It does not reproduce or explain the historical first-launch
blank screen. No production behavior or assertion changed.

## Observed results

| Observation | Result |
|---|---|
| Instrumented Brickson, AX5/light, portrait, English, fresh test storage | **Timeout reproduced.** Native Device Hub input selected Emergency and then Yes. The tracker remained active; 232 watchdog checks continued over 239.256 seconds. The system reported speaking/unpaused and the speech lease remained held. Progress was enqueued, delivered, identity-matched and received; no finish or cancel callback entered the relay. |
| Direct AV control, app-managed playback session | **Timeout reproduced.** Category/activation succeeded, start/progress arrived, and samples 1–35 remained speaking/unpaused without finish/cancel. |
| Direct AV control, system-managed separate session | **Timeout reproduced.** Start/progress arrived; samples 1–35 remained speaking/unpaused without finish/cancel. |
| Direct AV control, playback session with nil utterance voice | **Timeout reproduced.** Start/progress arrived; samples 1–35 remained speaking/unpaused without finish/cancel. Nil does not identify the voice the system actually used. |

[Results and hashes](results.json), [app trace](app-trace.txt), and the
unmodified [visible Speaking capture](ipad-speaking.png) retain the data.
The three control traces are [playback](playback-trace.txt),
[system-managed](system-managed-trace.txt), and [nil voice](nil-voice-trace.txt).
Control trace files omit line-end whitespace; results retain both original
and curated hashes. Scalar fields and ordering are unchanged, and raw local
originals remain retained. The PNG and control source are unchanged.
The first two resolved the simulator's system Samantha identifier; no
Personal Voice was requested or logged. Thirty-six samples include the
initial second-zero sample before speaking became true.

The diagnostic hooks emitted only monotonic time, tokens, event kinds,
offsets and booleans. Both temporary app-source files were restored
byte-for-byte, the ordinary app was rebuilt/reinstalled, the temporary
control app was removed, and only the simulator booted for this diagnostic
was shut down. No physical device was operated. A MobileBuildMCP tap that
returned success without a screen change is not counted as an activation.

## What this establishes and what it does not

The direct control reproduces the raw system state without Brickson's
tracker, callback relay, Home layout, SwiftData or coordinator. Stale
Home/AX state alone does not explain this app trace: the main-actor checks
continued while the system flag stayed true. The underlying cause remains
unidentified. This is not proof of an SDK defect or of audible output.

The app diagnostic omitted its actual resolved voice identifier, rate and
activation result. A held lease is not proof that activation succeeded.
Control voice selection follows the same source algorithm, but bundle,
authorization, automatic start, constructor order and lifecycle differ.
All observations share one host/runtime. Instrumentation may affect
timing; no result proves physical-device speech or general runtime behavior.

Apple documents monitoring through flags/delegate events and retaining
the synthesizer in [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer).
Its [finish callback](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate/speechsynthesizer(_:didfinish:))
reports completion. Setting [usesApplicationAudioSession](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession)
to false lets the system manage a separate session; that control is not a
proposed Brickson policy change. No arbitrary timeout, wait extension,
passing expected-failure test or audio-policy change follows from this data.
The original failed full UI runs and unchanged-main reproduction remain failed.

## Reproducing the isolated control

[Source](control-source/Sources/SystemSpeechControlApp.swift),
[copied pure selector](control-source/Sources/VoiceSelection.swift),
[mapping](control-source/Sources/VoiceMapping.swift), and
[XcodeGen spec](control-source/project.yml) are the exact source built for
the control. Generate/build/install this separate app on an owned simulator,
then launch one configuration at a time, capturing stdout:

1. `--audio=playback`
2. `--audio=system-managed`
3. `--audio=playback --voice=nil`

Each launch also used `-AppleLanguages (en) -AppleLocale en_US`. The fixed
neutral test utterance starts automatically; this is not a user-activation
test. The app retains the synthesizer, direct delegate and utterance;
samples seconds 0–35; and stops sampling without sending stop, cancel,
pause, retry or recovery. No package or network code is involved. The
generated project and build products are not committed or adopted by Brickson.
