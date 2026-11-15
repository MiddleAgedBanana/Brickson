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

The rules hold the targets that ship. The experiments' probe app in pull
request #112 is an application target marked `SKIP_INSTALL: YES`, never
installed, so it keeps every rule of the first check and none of these,
whichever pull request merges first.

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
- The commit after it answers cubic's review. A style's own property
  called `isPressed` is no longer its press state (only a read such as
  `configuration.isPressed` is); a fixed size wrapped in `CGFloat(…)` or
  `Double(…)` is found, and so is `UIFont(name:size:)` with a number in
  a file that never scales a font with `UIFontMetrics`; and AGENTS.md's
  line names the custom symbols and the named exceptions.
  Declined, with the reasons in docs/DECISIONS.md: words typed in
  capitals (a script cannot tell them from an acronym), and a fixed
  custom font in a file that scales another (a script cannot follow
  which font `UIFontMetrics` scales).

## Verified

In this cloud session, which cannot build Swift:

- `python3 scripts/test-forbidden-code.py`: every test passes, including
  the new ones. Each new rule has lines that break it, one way each,
  found on their line; the nearest code that keeps it, passing; the same
  lines in comments and strings, ignored; the known exceptions excusing
  only their rule in their type; a stale exception found; a never
  installed app target held to the first check only; picture files found
  outside the app icon and custom symbols. Removing any rule or any
  alternative of a rule's pattern fails at least one test.
- `python3 scripts/forbidden-code.py` over this checkout: nothing found,
  and the copy-of-the-repository test plants three look slips in
  `HomeView.swift` and finds exactly them, then removes one known
  exception's code and finds the stale exception.
- The branch merged with pull request #112 (the probe app) and with pull
  request #113 (colour tokens), each in a scratch worktree, with no
  conflict: the check, its tests and the documentation tests pass in
  both. Held to these rules, the probe app's own files would break five
  of them in 24 places (toggles, glass, a hover lift, fixed sizes, views
  passed off as buttons), which is why a never installed app is left out.
- The documentation, hook, privacy, runner, agent bridge, site and Xcode
  selection checks listed in AGENTS.md, *Build and test*.

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
