# Guards for Apple's look

*2026-11-15. Pull request #114 (`claude/project-thread-gnet07`). A Claude
Code cloud thread, chosen by the project's coordinator under the owner's
standing word that objective engineering is the threads' to decide.*

## What changed and why

The owner wants Brickson to read as an app Apple made. Some of what
that takes, from Apple's Human Interface Guidelines and API pages and
from AGENTS.md, can be decided from the code alone, and a check in CI
means code review can never miss a "not Apple" regression of that kind.

`scripts/forbidden-code.py` already failed CI on code AGENTS.md forbids
(*A check for code the app must never contain*). This pull request
extends that check rather than building a second one: same run, same
reports, same tests file. The new rules are in docs/DECISIONS.md, *Guards
for Apple's look*, with what each refuses, the choices made, its scope
and every rule left unguarded with the reason. In short, the app that
ships may not add glass or a material of its own, use a
`PrimitiveButtonStyle` or `trigger()`, let a button repeat while held,
show a picture that is not an SF Symbol, use Ultralight, Thin or Light,
fix a text size, draw circular corners, write an accessibility setting
into the environment, leave a `ButtonStyle` with no press state, set
text in capitals with `.textCase(.uppercase)`, offer a context menu, swipe or drag action, show a
system alert or dialog, use a toggle, make a view pass for a button,
swallow an error in an empty `catch`, time with an old clock, or lift a
control on hover. Each message names the rule, why it matters to the
person using the app, and what to do instead.

Nobody using the app sees or hears anything different: the change is in
a script and its tests, and in documents.

Two places break a rule today, both in Settings. Fixing either would
change what a person sees, so each is a named known exception in the
script and a line of docs/HANDOFF.md, *Known gaps*, for the new design:
`SettingsRowButtonStyle` (a `PrimitiveButtonStyle`, the only kind that
can wrap the system's bordered prominent style, used to redraw the
dimmed look at 4.5:1) and `SettingsPairLabel` (Hear and Use's icons at a
fixed 20 points). An exception the code no longer needs fails the check,
so it leaves with the code.

The rules hold the targets that ship. The experiments' probe app, from
pull request #112, is an application target marked `SKIP_INSTALL: YES`:
Xcode can run it on a device, but it is left out of every archive, so it
never reaches the App Store. It keeps every rule of the first check and
none of these.

AGENTS.md gains one line under *Apple's current frameworks first*, and
*Code Review Rules* now names a new known exception as something to flag.

## Commits

- `2cf9f36` Guard Apple's look in the forbidden-code check (the check
  and its tests)
- `4d1a07f` Record the guards for Apple's look (docs/DECISIONS.md,
  AGENTS.md, docs/HANDOFF.md and this record)
- `ffd9575` This record lists the commits and gains the merge check
  with pull requests #112 and #113.
- `209f33a` answers the first reviews (Codex, CodeRabbit and
  Graphify; Copilot had no quota). Each `ButtonStyle` needs its own
  press state (another style's `isPressed` in the same file no longer
  counts, a view of the file the style names does); the button-trait
  rule reads through a call inside the traits; `trigger()` is a rule of
  its own, so the `PrimitiveButtonStyle` exception cannot excuse one;
  swipe to delete and drag to move are found with a trailing closure;
  a bare `SKIP_INSTALL` counts only where XcodeGen reads it; and
  docs/DECISIONS.md says the two known exceptions are proposed for the
  owner, whose merge accepts them. Declined, with the reason in
  docs/DECISIONS.md: refusing an empty handler for one kind of error,
  which found `DraftStore.write`'s correct handling of a draft already
  removed.
- `a76624b` names Apple's Human Interface Guidelines and
  AGENTS.md as the source of the rules in this record, docs/DECISIONS.md
  and the script.
- `ac209c2` answers cubic's review. A style's own property
  called `isPressed` is no longer its press state (only a read such as
  `configuration.isPressed` is); a fixed size wrapped in `CGFloat(…)` or
  `Double(…)` is found, and so is `UIFont(name:size:)` with a number in
  a file that never scales a font with `UIFontMetrics`; and AGENTS.md's
  line names the custom symbols and the named exceptions.
  Declined, with the reasons in docs/DECISIONS.md: words typed in
  capitals (a script cannot tell them from an acronym), and a fixed
  custom font in a file that scales another (a script cannot follow
  which font `UIFontMetrics` scales).
- `13097b9` merges `main`, which now holds pull requests #112 (the
  probe app) and #113 (colour tokens), with no conflict.
- `890d6fc` answers CodeRabbit's second review. A target that
  names a settings group stays checked, since a group can turn
  `SKIP_INSTALL` back off for a build; a known exception whose file is
  gone is a finding, as one whose code is fixed already was; and a
  comment beside a custom symbol's name no longer hides the name.
- `0a38a91` reads an argument's label in linear time. Its pattern had
  two runs of spaces that could share the same spaces, so a long string
  blanked to spaces made it backtrack (20,000 spaces took over a
  second); SonarCloud flagged it, and a test now bounds it.
- `5c686d7` answers cubic's third review. An exception whose
  file is still there but in no target that ships is a finding, and
  this record and docs/DECISIONS.md say the probe app is left out of
  every archive (Xcode can still run it on a device), not that it is
  never installed.
- `e16839d` answers CodeRabbit's third review. It found a handler
  passed alone in parentheses as the default action (taken back by the
  commit after it); the tests' copy of this repository keeps its custom
  symbol sets; and a test shows that code moved with its folder is
  checked at its new place, since an exception names a path. It also
  records in docs/HANDOFF.md that the iPhone's Home order test failed
  on this pull request's second push, with no Swift changed: the
  intermittent failure HANDOFF already described.
- The commit after it takes back that part of `e16839d`. Swift rejects
  `.accessibilityAction({ … })`: the action's kind comes first, and a
  parenthesized argument fills it ("missing argument for parameter #1",
  CodeRabbit's compile of the same signature; not compiled in this
  session). So the clause and its test line guarded code that cannot
  build, and `e16839d`'s entry here was wrong to say that spelling
  leaves the action at its default kind.
  It also updates docs/HANDOFF.md: the iPhone's Home order test failed
  again on `e16839d`, in its default-text case, so it failed on two
  pushes in a row with no Swift changed.
- The last commit, pushed with the owner's word after the final push,
  answers the two findings made after it. A known exception excused
  every break of its rule in its type, so a second fixed text size in
  `SettingsPairLabel` would have passed (Gitar): each now counts its
  breaks, one more is a finding, and a count higher than the code needs
  is a stale exception. And `.accessibilityAction() { … } label: { … }`,
  a named action written with empty parentheses, was reported as a view
  passed off as a button (CodeRabbit): it is now left alone, like the
  same call without them.
- Then `main` came in with pull request #118 (the UI tests run in parts,
  and a simulator that has already shut down counts as cleaned up), and
  one more commit, pushed with the owner's approval, readies the pull
  request to merge. With #118's lines AGENTS.md was 32,883 bytes, past
  the 32 KiB Codex reads and the documentation test's limit; its
  introduction, *Build and test* and *Gotchas* were tightened to 32,349
  bytes, every rule kept (docs/DECISIONS.md, "AGENTS.md puts first what
  Codex reads"), and the introduction no longer says the size test
  covers only the sections Codex must read. The decision's refusal of
  system dialogs now gives its measured reason: a confirmation dialog
  opens with its destructive first item nearest the spot just tapped,
  and on the iPhone directly under it (docs/EXPERIMENTS.md, SIM-13,
  measured in pull request #115).

## Verified

In this cloud session, which cannot build Swift:

- `python3 scripts/test-forbidden-code.py`: every test passes, including
  the new ones. Each new rule has lines that break it, one way each,
  found on their line; the nearest code that keeps it, passing; the same
  lines in comments and strings, ignored; the known exceptions excusing
  only their rule in their type; a stale exception found; an app
  target left out of every archive held to the first check only; picture files found
  outside the app icon and custom symbols. Removing any rule or any
  alternative of a rule's pattern fails at least one test.
- `python3 scripts/forbidden-code.py` over this checkout: nothing found,
  and the copy-of-the-repository test plants three look slips in
  `HomeView.swift` and finds exactly them, then removes one known
  exception's code and finds the stale exception.
- `main`, with pull requests #112 (the probe app) and #113 (colour
  tokens), merged into the branch with no conflict, and the check, its
  tests and the documentation tests pass on the result. Held to these
  rules, the probe app's own files would break five of them in 24 places
  (toggles, glass, a hover lift, fixed sizes, views passed off as
  buttons), which is why an app left out of every archive is left out
  here.
- The documentation, hook, privacy, runner, agent bridge, site and Xcode
  selection checks listed in AGENTS.md, *Build and test*.
- After `main` with #118 came in: all of the above again, on the merged
  result with the shorter AGENTS.md.

## Not verified

- No Swift was built or run here, and none changed. CI's "Unit tests" job
  runs the check's tests before the build; until it passes, treat the
  pull request as untested.
- Whether Snap to Item, Switch Control or Voice Control treat the two
  known exceptions differently from a plain `ButtonStyle` was not
  measured; they predate this change.

## Follow-ups

- The new design settles the two known exceptions,
  then removes them from `KNOWN_EXCEPTIONS` and docs/HANDOFF.md.
- Colour rules (four appearances, semantic colours, no
  typed-in system values) are left to the colour tokens' own tests in
  pull request #113, not guarded here.
- Three edge cases reviewers found in the counting commit, reproduced,
  none changing what the check finds in the app today, for the next pull
  request that touches the check: a known exception with a count of 0 is
  never reported as stale; two nested styles with the same name in one
  file (`A.Style`, `B.Style`) share their code for the press-state rule;
  and a generic constraint (`<S: ButtonStyle>`) is taken for a
  `ButtonStyle` conformance.
