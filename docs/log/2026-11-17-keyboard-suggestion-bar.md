# The New Phrase audit meets the keyboard's suggestion bar with its words

*2026-11-17. Pull request #125 (`claude/keyboard-suggestion-bar`). A
Claude thread on the owner's Mac (Xcode 27.2).*

## What changed and why

`LibraryTests.testAPhraseNamedLikeAControlIsSavedWithANote` runs
Apple's accessibility audit on New Phrase with the phrase field focused
and the keyboard up. On CI's iPhone it failed now and then, on one
finding: "Element has no description" on a `TUIPredictionViewCell` at
(0, 546, 134, 44). That cell is one of the three buttons of the
keyboard's suggestion bar, which is Apple's, not Brickson's. It was the
only failing required check on #123 and one of the failures on #122.

Nothing a person sees or hears changes. The test changes:

- Before that audit it looks at the suggestion bar (the element Apple
  labels "Typing Predictions") until every button has a word, for up to
  15 seconds (`waitForKeyboardSuggestions`, in the new
  `BricksonUITests/KeyboardSuggestions.swift`).
- If the first showing of the keyboard has none, it goes back to Basics,
  opens New Phrase again and looks for up to 30 seconds more.
- It then types and audits once, as before. If the bar still has an
  empty button, the test fails with a message that says so and keeps a
  capture of the screen; the audit is not run on Apple's empty bar.
- A keyboard that shows no suggestion buttons for three seconds
  (Predictive Text turned off on a simulator chosen with `DESTINATION`)
  has nothing for the audit to meet, so the test goes straight on to
  it. Codex's review of the branch found that the first version failed
  there.
- Each run keeps a `KEYBOARD-SUGGESTIONS` line in its results saying
  which showing had the words, so CI's result bundles show how often
  the test had to show the keyboard again.

The audit is unchanged: nothing is excused, filtered or retried. The
trade-off, recorded in docs/DECISIONS.md, "Tests" (the 2026-11-16 entry,
corrected): this test no longer audits the empty bar of the keyboard's
first showing on a cold simulator. A named exception for the keyboard's
suggestion cell was the other way, and was not chosen, because it would
let more through the audit.

The same entry and `scripts/ui-test-parts.py` said that running
`KeyboardProbeTests` before `LibraryTests` (`RUNS_AFTER`) fills the bar
first. It does not, and both now say so. The order itself is kept for
now (*Follow-ups*).

### Why a wait alone cannot fix it

Measured on the Mac (Xcode 27.2, iPhone 17, iOS 27.2, portrait, default
text size, light, the full English software keyboard as
`scripts/test.sh ui` sets it), with the test run alone on a simulator
made new or erased just before, looking at the bar's three buttons
every half second:

| Run | Simulator | What the bar's buttons said |
|---|---|---|
| Baseline, test unchanged | made new | no words; the audit failed on the same cell as on CI |
| Sampling after typing "Help" | erased | no words for all 120 seconds; the audit failed |
| Sampling before and after typing | erased | no words for 60 seconds before typing and 20 after; the audit failed |
| Leaving New Phrase and opening it again, then relaunching | erased | no words for 15 seconds on the first showing; "I", "The", "I’m" at once on the second showing and after the relaunch |

So within one showing of the keyboard the empty buttons never fill:
there is nothing to wait for. Typing with XCTest's `typeText` does not
change the words either; with "Help" typed the bar still says "I",
"The", "I’m".

On CI (run 44077136692, #123, iPhone part 2) the bar had no words in
`KeyboardProbeTests`' first test, had "I", "The", "I’m" in its second,
about 34 seconds later in a new launch, and had none again in
`LibraryTests` about two and a half minutes after that. Which is why
the run order does not protect the audit.

## Commits

See the pull request.

## Verified

On the Mac, Xcode 27.2, iOS 27.2 simulators, portrait, default text
size, light, the full English software keyboard, the test run alone
with `scripts/test.sh ui` on a simulator made for that run and deleted
after it:

| Simulator | Runs | Passed | First showing | Second showing |
|---|---|---|---|---|
| iPhone 17 | 8 | 8 | no words after 15 seconds, every time | "I", "The", "I’m" at once, every time |
| iPad Pro 13-inch (M5) | 4 | 4 | no words after 15 seconds, every time | "I", "The", "I’m" at once, every time |
| iPhone 17, Predictive Text turned off | 1 | 1 | no suggestion bar, so the test went straight on to the audit | not needed |

The first six iPhone runs and three iPad runs used the first version
of the helper, before the change for a keyboard with no suggestion
buttons; the rest used the final version. Each run's first showing is
also the failing baseline: the unchanged test audits the screen right
there, and on the iPhone its audit failed on the empty cell in all
three runs in *Why a wait alone cannot fix it* that audited the first
showing. The iPad's audit of an empty bar was not tried.

- `scripts/test.sh` (the unit tests) on an iPad Pro 13-inch (M5)
  simulator made for the run: 1,052 tests, 1,039 passed, none
  failed, 1 skipped and 12 expected failures; the String
  Catalog was unchanged.
- The change merges with #122's and #123's branches without a conflict
  (a trial merge of each, not pushed).
- The Python checks (`scripts/test-docs.py`, `test-hooks.py`,
  `test-privacy.py`, `test-forbidden-code.py`, `test-runner.py`,
  `test-agent-bridge.py`, `test-site.py`, `test-select-xcode.py`).

## Not verified

- CI under load: the runs above are on the Mac, one simulator at a
  time. A slow CI machine could need longer than the 15 seconds before
  the keyboard is shown again, or the second showing could come before
  the keyboard is ready on a slow machine; the pull request's own CI
  run is the first evidence there.
- Why the first showing stays empty. The Mac runs show the effect, not
  its cause inside Apple's keyboard.
- Any other test that audits with the keyboard up. This one is the only
  one that has failed this way; the helper is ready for others.
- A real device.

## Follow-ups

- Drop `RUNS_AFTER` for `LibraryTests` in `scripts/ui-test-parts.py`,
  and its check in `scripts/test-runner.py`, now that the test shows
  the keyboard again itself. Owner: an agent thread, after #122 (which
  changes `scripts/test-runner.py`) has merged.
- Whichever of this pull request and #122 merges second moves the waits
  in `KeyboardSuggestions.swift` and the new lines of `LibraryTests`
  onto #122's shared wait helpers, which `scripts/ui-test-waits.py`
  will ask for. Owner: that pull request's thread.
