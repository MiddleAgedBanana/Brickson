# SonarQube Cloud's four code scanning alerts, answered

*2026-11-17. Pull request #124 (`claude/project-thread-6sgsgg`). A
Claude cloud thread, which cannot build or run the app; an agent on the
owner's Mac read the alerts through GitHub's API.*

## What changed and why

GitHub's code scanning page held four open alerts, all from SonarQube
Cloud, all "argument injection" in the Python helper scripts, none in
the app. Each was checked against the code (docs/DECISIONS.md,
"SonarQube Cloud's alerts", has the verdicts and the reasons):

- `scripts/privacy-check.py` (alert 7): the folder it named was safe,
  but a `--commits` range that starts with a dash reached `git log` as
  an option: `--commits=--output=<file>` emptied that file before the
  check stopped (reproduced on `main` before the fix). Such a range is
  now refused before git runs, and the folder is resolved to an
  absolute path first.
- `scripts/forbidden-code.py` (alert 4): the same safe folder path,
  now resolved to an absolute path too.
- `scripts/agent-bridge.py` (alerts 5 and 6): false positives, for the
  owner to dismiss on GitHub with their reasons. An agent's dismissal
  through the owner's `gh` on the Mac was refused by Claude Code's
  permission check there, and was not tried another way. The bridge is
  not changed here: draft pull requests #108 and #109 rewrite it, and
  nothing in it needs a change for these two.

docs/DECISIONS.md also gains the rule for how a script hands an outside
value to another program, and how to answer the next alert of this kind
once, so the same answer is not given alert by alert. HANDOFF and the
README now say that SonarQube Cloud scans the repository too.

## Commits

- `4b32ea8` Refuse a --commits range that starts with a dash, and give
  git absolute folders (the fixes and their tests).
- The commit after it adds this record, the DECISIONS section and the
  HANDOFF and README lines.

## Verified

- Read on 2026-11-17 through GitHub's API from the owner's Mac: four
  open code scanning alerts (4 to 7), all from SonarCloud, each with one
  instance, on `main`; CodeQL (Actions and Python) reported none on
  `main` or on pull requests #122 and #123. SonarQube Cloud's own API
  showed the same four as its only open vulnerabilities on `main`.
- On `main` before the fix, in a throwaway repository on Linux,
  `python3 scripts/privacy-check.py --no-list '--commits=--output=written.txt'`
  created `written.txt` and then stopped with exit status 2; git 2.43
  also showed that
  `git -C --version status` treats `--version` as a folder.
- New tests, each run first against `main`'s code and seen to fail:
  - `test_a_range_that_starts_with_a_dash_is_refused_before_git_reads_it`
    (`scripts/test-privacy.py`) fails if the dash check is removed: git
    writes the file and the refusal is missing.
  - `test_git_is_given_the_repository_as_an_absolute_folder`
    (`scripts/test-privacy.py`) and
    `test_git_is_given_the_checkout_as_an_absolute_folder`
    (`scripts/test-forbidden-code.py`) fail if `resolve()` is removed:
    git is given the relative folder.
- The repository's Python checks, on Linux in this cloud session, all
  passing: `test-docs.py`, `test-hooks.py`, `test-privacy.py`,
  `test-forbidden-code.py`, `test-runner.py`, `test-agent-bridge.py`,
  `test-site.py`, `test-select-xcode.py`, `forbidden-code.py` over the
  repository, and `privacy-check.py --outgoing --no-list` (no private
  list here, so the built-in patterns only).

## Not verified

- Whether SonarQube Cloud closes alerts 4 and 7 once this reaches
  `main`. Its analysis did not flag the bridge's own `git -C`, whose
  folder is resolved first, so it probably will; if not, they are
  dismissed with the reason in docs/DECISIONS.md.
- The app was not built: this changes no Swift. CI runs the Python
  checks on a Mac.
- That a dismissal on GitHub reaches SonarQube Cloud: its documentation
  says so; read the two issues' status there after the owner dismisses.

## Follow-ups

- The owner dismisses alerts 5 and 6 (owner).
- After the merge, read alerts 4 and 7 again; dismiss either that is
  still open, with the reason in docs/DECISIONS.md (this thread, or the
  next thread that touches code scanning).
