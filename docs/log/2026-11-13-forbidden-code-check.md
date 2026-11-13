# A CI check for code the app must never contain

*2026-11-13. Pull request #111 (`claude/project-thread-e4cng3`). A Claude
Code cloud thread, from the owner's approval, through the project's
coordinator, of the first recommendation of a read-only audit of which
AGENTS.md rules a script could enforce: one CI check, in one pull
request, that fails if the code ever holds something AGENTS.md forbids.*

## What changed and why

AGENTS.md's rules are words. Until now a slip (an `import Network`, a
`UIDevice` check, a third-party package, a workflow given a write token)
was caught only if a reviewer happened to see it. `scripts/forbidden-code.py`
now checks every rule of that kind a script can decide with no judgment,
and the unit-test job fails when the code breaks one. Nobody using
Brickson notices anything; people working on it get a failed check that
names the rule and what to do, before the change can merge. On this
branch's base, `main` at `8c90597`, the check finds nothing.

docs/DECISIONS.md, "A check for code the app must never contain", lists
what it checks, why, how to allow something on purpose, and what it
cannot catch. In short:

- **The app's Swift files** (the sources of every `project.yml` target
  that is not a test, so an extension or framework the app ships too),
  with comments and the words inside strings left out:
  no network code, cloud sync, Keychain, accounts, ads or tracking, and
  none of the frameworks for them; no system sounds or setting the
  volume; no choice by device, screen or orientation; no gestures, hover
  handlers or tracking code; no hidden Back button, navigation bar (even
  one hidden only some of the time) or blocked swipe; no `rollback()`; no
  `ViewThatFits`; SwiftData opened with `cloudKitDatabase: .none`;
  notification observers on the main queue, never with a selector.
  Imports come from a short list, and the legacy frameworks only in the
  files docs/DECISIONS.md's frameworks table names.
- **`project.yml` and the files beside it:** no packages or SDKs; no
  iCloud, push, Sign in with Apple or network capability or key;
  warnings stay errors in every build, a setting for Debug or the
  simulator only included; the deployment target matches the minimum
  iOS.
- **The workflows:** no `pull_request_target` or `workflow_run`; read-only
  permissions in workflows that run a pull request's code (comments on
  one too); no event text in a shell command, directly or through an
  `env` value; only GitHub's own actions and the repository's; no path
  filter on the required checks' workflow, in any form. The same rules
  hold every action the repository keeps, wherever it is.
- **The tests:** known issues strict and citing their decision; every
  skip says why.
- **`CLAUDE.md`** holds only `@AGENTS.md`.

It follows the guard's and the privacy check's pattern: a standard-library
Python script for the Mac's Python 3.9, a test file beside it, and
`scripts/test.sh unit` running the tests before the build. That puts it
inside the required "Unit tests" check without changing a workflow,
which a cloud session cannot push.

Beyond the audit's list, a few rules joined because they are as plain to
check and the app passes them: hover handlers, `AsyncImage`,
`.modelContainer(for:)`, the capability and Info.plist keys, and
background modes that fetch. Routine choices, made by the thread. Where
the check cannot read something it would need to (a `project.yml` that
includes other specs, builds targets from templates or gives a target no
type; permissions given through a YAML alias), it stops with status 2
instead of passing.

Two values SwiftUI's own modifiers take, `UIKeyboardType` and
`UITextContentType`, are not counted as UIKit, because docs/DECISIONS.md,
"Apple's current frameworks first", says modifiers typed with UIKit
values are not legacy. UIKit's own colours count however they are
written, `Color(.systemBackground)` included.

What the approval did not cover, and this pull request does not do: a
Claude Code hook that runs the check after each edit, and any trimming of
AGENTS.md. Every rule keeps its line there.

Files: `scripts/forbidden-code.py` and `scripts/test-forbidden-code.py`
(new); `scripts/test.sh` runs the tests; `scripts/test-runner.py` expects
the new preflight; docs/DECISIONS.md gains the section above and a line
each in *Apple's current frameworks first*, *Warnings are errors* and
*Minimum iOS, iPhone and iPad* saying the check reads them; AGENTS.md's
*Build and test* runs the new tests, and its *Code Review Rules* flag a
weakened check; docs/HANDOFF.md, README.md and docs/SDLC.md list it.

## Commits

One commit for the check, its tests and these records; see the pull
request's commit list.

## Verified

In this cloud thread, on Linux, with Python 3.9 (the Mac's version):

- `scripts/test-forbidden-code.py`: 86 tests pass. They plant each kind
  of slip in a small fixture checkout and see it found, see the same code
  in a comment or a string ignored, run the check over a copy of this
  checkout with a slip planted in a real file (`HomeView`, a unit test,
  `tests.yml`), and run it over this checkout, which passes.
- Each test can fail. Two sweeps took out one part of the check at a
  time and ran the tests. The last ones ran on the final code. Of 431
  parts of its patterns and lists (every name in every rule, forbidden
  framework, package file, capability key, warning setting and pull
  request event), 418 made a test fail; the other 13 are frameworks the
  app may import, and dropping one only makes the check stricter. All
  169 pieces of its code taken out (each fix undone, each rule's clause
  turned off, each part of how it reads Swift and YAML) made a test
  fail; 13 older ones no longer applied, because round four rewrote the
  code they changed, and its own mutants cover that code. Round four's
  first sweep found nine parts no test held: six gained a test; two that
  no Swift could reach (`#endif` in one pattern, `protocol` in another)
  were removed; and a rule that let a container-typed `.init()` pass
  unflagged was removed, with a test.
- Four review rounds in this thread, before the pull request. In each,
  readers looked for slips the check misses, for false alarms and
  crashes, and for claims and rules these records break. Round one's 27
  findings were each re-checked by a second reader, and all were real;
  rounds two and three found 22 and 33, and round four 25 from three
  readers. Every finding is fixed here with a test. Among them: Swift 6
  imports with an access level (`internal import Network`) or after a
  `;`; extension and framework targets; SwiftData opened through `.init(`
  whose type only the code around it says (a declaration, a typed body
  or closure, an `#if` branch, `Self` in an extension, a ternary, `??`, an
  array of configurations, a type written `SwiftData.ModelConfiguration`);
  a container given `configurations: []`;
  `.toolbar(.hidden, for: .navigationBar)`; Combine through publishers;
  `INFOPLIST_KEY_` settings and keys in `.xcconfig` files; `-Wwarning`,
  `-Wno-` and `compilerFlags` anywhere in `project.yml`; another
  platform's deployment target taken for iOS's; a path written in another letter case;
  YAML written as one-line mappings or lists, with anchors and tags, or
  with a quote inside a plain word; a workflow's event text read through
  `${{ env.X }}` or a multi-line expression; workflows on pull request
  reviews and the merge queue; an action kept outside `.github/`;
  `include:` in `project.yml`; a known issue whose comment interpolates
  a string; raw strings and regex literals; an enum case of Brickson's
  own named `rollback`; an observer on `OperationQueue.main`; and the
  tests the reviews showed could not fail.
- `scripts/forbidden-code.py` over this checkout: "nothing AGENTS.md
  forbids was found". It reads 92 app Swift files, and every use of a
  legacy framework it finds is in a file the frameworks table names.
- `scripts/test-runner.py`: the preflight tests expect the new step
  before the build and see the build skipped when it fails.
- `scripts/test-docs.py`, `scripts/test-hooks.py`,
  `scripts/test-privacy.py`, `scripts/test-agent-bridge.py`,
  `scripts/test-site.py` and `scripts/test-select-xcode.py` pass.

## Not verified

- No Mac run. A cloud session cannot build the app, so the first run of
  `scripts/test.sh unit` with the new step is CI's, on this pull request.
  The pull request is untested until "Unit tests" is green.
- Round four's last two readers (crashes, and these records against the
  rules) and its second-reader check were cut off by a usage limit and
  were not rerun, to save usage. Its 25 findings were fixed without a
  second reader confirming each.
- The check reads Swift with its own small reader, not Apple's compiler.
  Its tests cover comments (nested), strings (multi-line, raw,
  interpolated) and regex literals, but Swift syntax it has never seen
  could hide code from it or show it a word that is not code.
- It reads `project.yml`, the workflows and the plists with a small
  reader of the YAML and XML they use today, not a full parser. A form
  it has never seen could hide a key from it; the forms the reviews tried
  are in its tests.

## Follow-ups

- **The UI tests' row of the frameworks table is incomplete** (docs/HANDOFF.md,
  *Known gaps*). `TypingOnHomeTests` reads `UIDevice`'s idiom for a
  failure message and is not in the row "UIKit types in UI tests";
  `HomeRestBoardTests` imports UIKit and uses none of it, against
  *Imports say what a file uses*. Proposed fix, for the next pull request
  that touches the UI tests: add `TypingOnHomeTests` to the row, drop the
  unused import, then let the check hold the test targets to the table
  too. Owner of the fix: the next UI-test thread.
- A Claude Code hook running the check after edits is the audit's second
  recommendation; it waits for the owner.
