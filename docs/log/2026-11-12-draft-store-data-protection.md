# DraftStore Data Protection Class Upgrade

**Date:** 2026-11-12
**Issue:** Unsafe Data Protection Class for Typed Drafts (`Brickson/Typing/DraftStore.swift`)

## What changed

- In `DraftFile.write(_:)` (`Brickson/Typing/DraftStore.swift`), changed Data write options from:
  `options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]`
  to:
  `options: [.atomic, .completeFileProtection]`.
- Updated code comment to document that typed drafts are encrypted with complete protection when the device is locked.
- Added a unit test in `BricksonTests/DraftStoreTests.swift`: `writingDraftUsesCompleteFileProtection()` testing write and readback as well as checking `FileProtectionType.complete` where supported by the filesystem attributes.

## Why

- Using `.completeFileProtectionUntilFirstUserAuthentication` leaves stored files decrypted in flash memory once the device has been unlocked after boot, even if the device subsequently locks.
- An attacker with physical possession of a locked device could potentially extract sensitive, unencrypted communication drafts.
- Upgrading to `.completeFileProtection` ensures iOS encrypts `draft.txt` with keys derived from the user's passcode and wiped from memory whenever the device is locked, aligning with the privacy policy's promise that draft files remain encrypted when the device is locked.

## Verification

- `python3 scripts/test-docs.py` passed (57 tests).
- `python3 scripts/test-privacy.py` passed (151 tests).
- `python3 scripts/privacy-check.py --outgoing --no-list` passed.
- Unit and UI test suites require macOS / Xcode environment per AGENTS.md ("Cloud agents with no route to a Mac cannot build or run the app or its Xcode tests; the Python checks run anywhere... Say so plainly, treat the change as untested until CI or a Mac run passes, and never describe unbuilt code as working"). Swift changes remain to be verified by CI.
