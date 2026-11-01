# The voice list no longer holds up launch

*2026-11-01. Pull request #73 (`claude/project-thread-s4m6t1`). A cloud
thread, "Fix the iPad first-launch CI flake".*

## What changed and why

For weeks the first UI test on GitHub's iPad simulator failed now and
then: the app showed a blank screen, every accessibility query failed
with `kAXErrorServerNotFound`, and a re-run passed. The cause is in the
app, not in CI.

Brickson read the system's list of speech voices on its main thread
while it started, before Home's first frame (`BricksonApp.init` →
`AppAudio.makeForApp` → `SpeechService.init` → `refreshVoices()` →
`AVSpeechSynthesisVoice.speechVoices()`). On a simulator that had just
started, the system's voice service took 12 to 54 seconds to answer
that first request, and in every failed run more than 60. While the
main thread waited, the app sat on its launch screen; XCTest's
automation session, which waits for the app, gave up at 60 seconds,
and the test failed. Once the service had answered once, later reads
took under a tenth of a second, which is why later tests and re-runs
passed.

For a person this is the same failure: an app that takes a minute to
open after the device restarts, when they may need to say something
at once. So the app is fixed, not the test (docs/DECISIONS.md, "The
voice list never holds up launch"):

- **The list is read away from the main thread** and handed back on it
  (`SystemVoiceCatalog.readInstalledVoices(then:)`, through a
  `@concurrent` function). Home draws without waiting for it.
- **A phrase chosen before the list arrives speaks at once,** in the
  system's default voice: with no list there is no voice to ask for,
  and asking the system for a voice by name would wait for the same
  slow service, on the main thread, at the moment the person chose a
  phrase. The chosen voice, or the person's Personal Voice, speaks from
  the first phrase after the list arrives. Nothing asks for a
  confirmation or waits before speaking (invariant 2).
- **One read at a time.** The system's read holds the thread it runs on
  until the service answers, so `SpeechService` keeps one read out; a
  request while it waits (the app coming to the front, the Personal
  Voice answer, the system's voices-changed notice) is read once more
  as soon as it answers. Each list is used as it arrives, filtered by
  the Personal Voice permission as it is then, not when the read began
  (docs/DECISIONS.md, "A Personal Voice is used only while it is
  allowed").

The test step was not changed: the warm-up in `scripts/test.sh` stays
(it also wakes the voice service before the tests), and no test is
retried or loosened.

## How the cause was found

The app's own standard output and error are inside every `.xcresult`,
in the action's diagnostics folder, with the test runner's session log
and `testmanagerd.log`. Earlier investigations (2026-10-21 to 10-27)
had not opened that folder and recorded "no app stack establishing a
cause" (docs/HANDOFF.md, *Verification*). Reading it on Linux:

- `database.sqlite3`, table `Actions`, column `diagnosticsRef`, names
  the folder. Each folder is a `Data/data.<ref>` file (a JSON list of
  its entries: `name`, and `type` 2 for a folder) and a
  `Data/refs.<ref>` file with its children's identifiers in the same
  order: one header byte, then for each child a length byte (65), a
  zero byte and a 64-byte hash. A child's identifier is `0~` followed
  by the hash in URL-safe base64; its contents are `Data/data.<id>`.
  Text is zstd-compressed (it starts with the bytes `28 b5 2f fd`).
- The app's log is `StandardOutputAndStandardError-family.avery.brickson.txt`,
  one section per launch (process), and the runner's is
  `Session-<date>.log`.

```python
# python3 -I diag.py <bundle>.xcresult <out-dir>   (pip install zstandard)
import base64, json, os, sqlite3, sys, zstandard
bundle, out = sys.argv[1], sys.argv[2]
data = os.path.join(bundle, "Data")
def read(name):
    raw = open(os.path.join(data, name), "rb").read()
    if raw[:4] == b"\x28\xb5\x2f\xfd":
        raw = zstandard.ZstdDecompressor().stream_reader(raw).read()
    return raw
def children(ref):
    raw, ids, i = open(os.path.join(data, "refs." + ref), "rb").read(), [], 1
    while i < len(raw):
        size = raw[i]; i += 2
        ids.append("0~" + base64.urlsafe_b64encode(raw[i:i + size - 1]).decode())
        i += size - 1
    return ids
def copy(ref, into):
    os.makedirs(into, exist_ok=True)
    for entry, child in zip(json.loads(read("data." + ref)), children(ref)):
        path = os.path.join(into, os.path.basename(entry["name"]))
        if entry["type"] == 2:
            copy(child, path)
        else:
            open(path, "wb").write(read("data." + child))
for (ref,) in sqlite3.connect(bundle + "/database.sqlite3").execute("select diagnosticsRef from Actions"):
    copy(ref, out)
```

What the logs showed, in all five failed runs read (run 41280020554,
pull request #71's, attempt 1; run 41018793063, #68's, attempt 1; run
40518839570, `main` after a merge; runs 40507811193 and 40224730784,
Codex's website review and Duo reserved-regions branches): every failing launch
logs three lines and then nothing, the audio factory's line, the audio
session's, and the system's "Device does not support personal voice."
(the Personal Voice status read just before the voice list). No reply
from the voice service ("VoiceDBClient") follows, and no "Received
request to exchange capabilities", the automation session starting.
Every passing launch logs the voice service's reply first, then the
automation session within about a second. The runner's log for a
failing launch says "Failed to get automation session for
family.avery.brickson … Timed out while requesting automation session".

How long the first launch of each run waited for the voice list:

| Run | iPad | iPhone |
|---|---|---|
| 41280020554, attempt 1 | more than 60 s, three launches in a row | 35.0 s |
| 41280020554, attempt 2 (passed) | 0.0 s, after the warm-up had woken the service | 54.1 s, a near miss |
| 41018793063, attempt 1 | more than 60 s | 47.1 s |
| 40518839570 | more than 60 s | 34.3 s |
| 40507811193 | more than 60 s | 12.6 s |
| 40224730784 | more than 60 s | 0.0 s |

The iPad's tests run first; the iPhone's start about an hour later, on
a simulator of their own, started then.

In the near miss, the main thread logged nothing for 54.1 seconds
until the voice service answered; the window appeared two seconds
later, the automation session had already given up, and the test still
passed because accessibility came up just after. The warm-up launch
(`scripts/test.sh`) is stopped after 15 seconds, so when the service
needs longer, its request is dropped and the first test meets the same
cold service.

## Commits

- The fix and its tests: `SpeechSynthesizing.swift`,
  `SpeechService.swift`, the test doubles and the new tests.
- This record, docs/DECISIONS.md, docs/HANDOFF.md, AGENTS.md's two
  gotchas and the warm-up's comment in `scripts/test.sh`.

## Verified

This thread runs in the cloud and cannot build with Xcode, so GitHub CI
is the build, and until it passes the change is untested. The cause was
read from the five failed runs' result bundles (above), on Linux.

New tests, and what makes each fail:

- `OffMainThreadCallbackTests.theSystemVoiceListIsReadAwayFromTheMainThread()`:
  gives the system catalog a stand-in reader that reports where it ran.
  Fails if the read runs on the main thread, as `installedVoices()` did,
  including if `@concurrent` is dropped (the project's approachable
  concurrency would then run it on the main actor), or if the list
  never arrives on the main actor.
- `SpeechServiceTests.aPhraseBeforeTheVoiceListArrivesSpeaksAtOnce()`:
  fails if a phrase waits for the list, if it asks for the chosen voice
  before the list says it exists, or if the chosen voice is not used
  once the list arrives.
- `SpeechServiceTests.aChangeWhileTheListIsComingIsReadOnceItArrives()`:
  fails if a second read starts while the first waits, if a change
  asked for meanwhile is never read, if a list that arrives is dropped,
  or if reading stops after the follow-up read.
- `SpeechServiceTests.aListThatArrivesAfterAccessWasTurnedOffLeavesOutThePersonalVoice()`:
  fails if a list is filtered by the Personal Voice permission as it
  was when the read began.

`FakeVoiceCatalog` answers at once unless told to hold its answers, so
every existing speech test runs as before.

## Not verified

- **On a real device:** how long the voice list takes after the device
  restarts, and so how long a phrase may speak in the system's voice
  instead of the chosen one or the person's Personal Voice. Added to
  docs/HANDOFF.md, *Checks that need a real device*.
- **Whether the synthesizer itself waits** for a cold voice service at
  the first phrase, on the main thread. On CI the voice service had
  always answered before the first phrase until now; the first UI tests
  (the fold and Get Attention tests) speak no phrase.
- **After a media-services reset,** each phrase checks its voice on the
  main thread (`voiceIsAvailable`) with the list read before the reset,
  while the restarted service may be slow. Not made worse here (the old
  code read the whole list on the main thread at that moment), and not
  measured.
- Whether CI's next runs are free of the failure. Five failures in the
  runs read, so one green run does not prove it; the next weeks of runs
  on `main` will.
- A Release build. CI builds Debug only.

## Follow-ups

- `scripts/test.sh` runs `xcrun simctl bootstatus <udid> -b` after
  `xcrun simctl boot`. In every log read it printed "Device already
  booted, nothing to do." within two seconds, and the next step (two
  `simctl spawn defaults write`) then took four to six minutes. Whether
  `simctl boot` already waits for the boot to finish was not checked.
  Not this flake's cause. *(the next tests/CI thread)*
- If the first-launch failure comes back with this fix in, read the
  app's log from that run's bundle (above) before changing the warm-up.
  *(whoever sees it)*
