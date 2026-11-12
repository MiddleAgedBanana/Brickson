# Why the saved message keeps iOS's default file protection

*2026-11-12. Its pull request from `claude/project-thread-1f59xo`. A
Claude Code thread in the cloud, asked by the owner after reviewing pull
request #94. Documents only.*

## What changed and why

Pull request #94 proposed saving the typed message (`draft.txt`) with
complete file protection, so it can be read only while the device is
unlocked. Its review recommended not taking it, and the owner agreed and
asked for the reason to be recorded, so no later tool proposes it again.

- `docs/DECISIONS.md`, "The typed message", gains a bullet: the message
  keeps the default class
  (`.completeFileProtectionUntilFirstUserAuthentication`). The privacy
  policy promises only that iOS encrypts Brickson's storage when the
  device has a passcode, which the default does; the message is read
  once, at launch (`BricksonApp.init`), so a launch while the device is
  locked could not read it under complete protection, Home would show
  "Message not restored", and the next change would replace the saved
  message (`DraftStore`: the first save after a failed restore replaces
  the file).
- `docs/ROADMAP.md`, item 10 (the Siri and Shortcuts work file), now
  lists that case among what the work file settles. Nothing launches
  Brickson while the device is locked today, but R2's actions from Siri
  or the Action button may, and under the default class the same gap
  exists before the first unlock after a restart.

The review also found that #94's test read the protection class only
when the simulator reported one (`if let`), so it could pass checking
nothing, and that the iPhone UI-test failure on #94 was Get Attention's
Stop disappearing late on a slow CI machine (its capture 40 seconds later
shows the alarm stopped), not the change.

## Commits

One commit on `claude/project-thread-1f59xo`: this record and the two
document edits above.

## Verified

- `python3 scripts/test-docs.py`, `python3 scripts/test-privacy.py` and
  `python3 scripts/test-hooks.py` in the cloud thread.
- `python3 scripts/privacy-check.py --outgoing --no-list`: patterns only.
  The private list is not in this cloud thread, so it was not checked.
- That nothing else in the app sets a file protection class: a search of
  `Brickson/`, `project.yml` and the entitlements for protection options
  found only `DraftFile.write`.

## Not verified

- No app code changed, so nothing was built; CI runs as usual.
- Whether R2's actions will in fact start Brickson while the device is
  locked: that is item 10's to find out, on a real device.

## Follow-ups

- Item 10's work file (R2, owner's yes first): restore a message the
  device kept locked once it unlocks, with a test that makes the restore
  fail as a locked device would.
