# A lockfile for the actions the workflows run

*2026-11-07. Pull request #86 (`claude/project-thread-x2j7ue`). A
thread on the owner's Mac, through Remote Control, from
docs/HANDOFF.md, "Repository, CI and website".*

## What changed and why

Nothing in the app changes. This is about what runs on GitHub's
machines.

A workflow names an action by a tag such as `actions/checkout@v7`, and
GitHub looks up what that tag points to each time it runs. A tag can be
moved, so the code that runs is not promised to be the code anyone
looked at. A lockfile writes down the exact commit, and GitHub then runs
that commit, or refuses to run at all if the tag no longer contains it.
docs/DECISIONS.md, "Reviews, updates and GitHub settings",
*Dependencies*, records the decision.

- **`.github/workflows/actions.lock`**, written by `gh actions-lock`,
  GitHub's own extension of `gh`. It holds seven entries: the six
  actions, and the older `actions/upload-artifact` that
  `actions/upload-pages-artifact` runs.
- **`pages.yml` and `tests.yml`**: the tool narrowed each short tag to
  its full version (`@v7` to `@v7.0.1`). Each pair is one commit, so no
  code that runs changed (*Verified*).
- **`.github/workflows/verify-lockfile.yml`, new.** The handoff left
  this to be decided, and the decision is yes. It runs
  `gh actions-lock --verify` on each pull request and each push to
  `main`. The reason is `pages.yml`: no pull request runs it, so
  without this a stale entry there would first show as a website that
  does not publish. It is GitHub's own sample with this repository's
  names and a time limit. It is not a required check, and has no path
  filter so that it can become one.
- **`scripts/test-runner.py`**: `lockfile_problems` checks, with no
  network and no `gh`, that the lockfile records each action named by a
  step written in plain block form, so a cloud thread can check a
  forgotten lockfile too, and the unit job does. It runs by hand on a
  Mac: `scripts/test.sh` does not run this script. It does not see other
  step forms, a workflow with only `run:` steps, or commits; `--verify`
  checks those. A second test holds `verify-lockfile.yml` to the above:
  it runs on every pull request, with nothing narrowing or skipping it,
  a read-only token, a pinned extension and `--verify`, and no workflow
  uses `--relock` or `--accept-moved`. The handoff did not ask for
  these; the repository's rule is that a workflow rule gets a check
  wherever one can run.
- **`.coderabbit.yaml`.** CodeRabbit skips every `*.lock` by default, so
  it would never have read this file, and GitHub's advice is that "a
  lockfile is only a security control if someone reads the diff". The
  default's pattern comes back as `**/*.lock`; this is the repository's
  only lock file. CodeRabbit says such an override does not restrict
  what it reviews, but also that its patterns decide what it checks out,
  and it does not say the override is left out of that. A checkout of
  lock files alone would lose AGENTS.md, so `**` beside it keeps the
  whole repository.
- **`AGENTS.md`**: the gotcha the handoff asked for, and one review rule
  it did not, because Brickson has no `CODEOWNERS` to do that job.
- **`docs/SDLC.md`**: the owner's paste route for workflow files now
  says a `uses:` change goes through the Mac, because the pencil cannot
  write the lockfile.
- **Comments in `.github/dependabot.yml` and `dependency-review.yml`**:
  Dependabot's pull requests now update the lockfile too, and the actions
  are no longer quite the only dependency: the extension is one, which
  neither watches.
- **docs/HANDOFF.md**, item 9: the owner's "Allow only GitHub's actions"
  step is marked done, because GitHub's API shows it set. The record of
  2026-11-07 said the API refused to show it; from the owner's Mac it
  answers (*Verified*).

Worked in this session's own worktree of the repository, not
`~/code/brickson`. Commits are unsigned (`-c commit.gpgsign=false`): the
signing key needs a passphrase an agent does not have, and `main`'s
ruleset does not require signatures.

## Commits

The commits of pull request #86.

## Verified

On the owner's Mac (macOS 27.2, `gh` 2.103.3, `gh-actions-lock` v0.4.1):

- The extension's release: `gh release view` reports it immutable, and
  `gh release verify v0.4.1 -R github/gh-actions-lock` passed.
- `gh actions-lock` pinned six actions and one transitive one across
  four workflows. `gh actions-lock --verify` reported all four valid,
  and `--verify --json` reported `valid: true` with no findings, so
  neither `fresh-tag` nor `version-ref` applies.
- Each short tag, its full version and the lockfile's commit, read with
  `git ls-remote` on 2026-11-07 (every tag points straight at its commit
  or was peeled to it):

  | Action | Tags | Commit |
  | --- | --- | --- |
  | `actions/checkout` | `v7`, `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
  | `actions/configure-pages` | `v6`, `v6.0.0` | `45bfe0192ca1faeb007ade9deae92b16b8254a0d` |
  | `actions/upload-pages-artifact` | `v5`, `v5.0.0` | `fc324d3547104276b827a68afc52ff2a11cc49c9` |
  | `actions/deploy-pages` | `v5`, `v5.0.1` | `368f82528645a54fb793d4d04e342629a3f51346` |
  | `actions/upload-artifact` | `v7`, `v7.0.2` | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
  | `actions/upload-artifact` (run by `upload-pages-artifact`) | `v7.0.0` | `bbbca2ddaa5d8feaa63e36b76fdaad77386f024f` |
  | `actions/dependency-review-action` | `v5.0.0` | `a1d282b36b6f3519aa1f3fc636f609c47dddb294` |

  `actions/checkout` and `dependency-review-action` also match what the
  record of 2026-11-07 read that morning.
- The owner's setting, from the API on 2026-11-07:
  `actions/permissions` gave `allowed_actions: selected` and
  `sha_pinning_required: false`; `selected-actions` gave
  `github_owned_allowed: true`, `verified_allowed: false` and no
  patterns. `actions/policies` listed none.
- How the lockfile names an action, on a scratch repository:
  `github/codeql-action/init@v4` is recorded as
  `github/codeql-action@v4.39.3` and `Actions/Checkout@v7` as
  `actions/checkout@v7.0.1`, which is what `lock_key` does.
- `scripts/test-runner.py` (95 tests), `scripts/test-docs.py` and
  `scripts/test-hooks.py` pass. Before the lockfile and the workflow
  existed, `test_every_action_a_workflow_runs_is_in_the_lockfile` failed
  and `test_the_lockfile_is_verified_on_every_pull_request` errored.
- On a copy of the repository, each of these changes made the workflow
  tests fail, and each was undone. In the files: a `uses:` line changed
  in `tests.yml` or `pages.yml`; a new workflow with an action; a new
  step; a line, or a whole workflow, removed from the lockfile; the
  lockfile deleted, emptied or written with other quotes. In
  `verify-lockfile.yml`: no pull request trigger; no push to `main`; the
  trigger narrowed by paths or branches; `pull_request_target`; `if:` on
  the job or the check; `continue-on-error` on either; a wider token; a
  second `permissions` block; the job renamed; the extension unpinned or
  pinned to a branch; `--verify-local` or `--no-fix` for `--verify`; the
  check before the install; `--accept-moved` or `--relock` there or in
  another workflow; a checkout that keeps its token. In the code: a
  top-level key not ending a workflow's list; matching an action in any
  workflow's list; comparing with case; keeping the path inside the
  action's repository; checking `./`, `$/` or `docker://` steps; stopping
  at an unreadable workflow, with or without reporting it; skipping one
  silently; leaving out `.yaml` files; an unreadable or empty lockfile
  reading as nothing to report; not counting actions.
- Before the pull request, three separate readers tried to refute it,
  one each for the claims about GitHub, the code and the repository's
  rules. Each finding was checked and fixed here, but one: `lock_key`
  does not lower-case a full commit hash, which only matters to a `uses:`
  written with a hash in capitals, and Brickson names tags.
- GitHub's documentation, read 2026-11-07: *Workflow dependency
  lockfiles*, *Locking action dependencies in a repository's workflows*,
  *Enforcing lockfiles for action dependencies*, *Governing execution of
  GitHub Actions workflows*, the changelog of 2026-10-28, and the
  extension's README, sample workflow, troubleshooting guide and skill;
  CodeRabbit's *Path-based review instructions* for its default ignored
  paths.

## Not verified

- **The first locked run of `pages.yml`.** No pull request runs it. This
  pull request changes that file, so the merge itself starts "Publish
  website": that is the first time its four actions run from the
  lockfile. If it fails, the site stays as it was.
- **Whether the owner's setting matches the locked commits.** The
  handoff said the first locked run shows it. GitHub's documentation says
  it checks the setting against the locked commit; a mismatch would stop
  every workflow at its start. This pull request's own run is that check.
- **What CodeRabbit checks out** with these patterns: its documentation
  does not say, and `**` is there so that it should not matter.
- A real moved tag: nothing here simulated one. What happens then is
  GitHub's documentation, not a test.
- Dependabot's first lockfile update: none has happened yet. Its
  monthly pull request is the first, and it may write a newer lockfile
  format than the pinned extension reads, which fails "Verify lockfile"
  until the pin moves.
- Whether cubic and Greptile read a `.lock` file: neither's documentation
  says, and only CodeRabbit's default was read.
- The "Require lockfile" policy: off, and not tried.
- Nothing was built on the Mac: no Swift changed. GitHub CI is the
  build.

## Follow-ups

- **Whether "Verify lockfile" becomes a required check**, with
  "Dependency review". *(the owner, after both have run on a few pull
  requests)*
- **Whether "Require lockfile" goes on** (docs/DECISIONS.md,
  *Dependencies*). *(the owner)*
- **Moving the extension's pin** when it has a newer release. Nothing
  raises one; AGENTS.md, *Gotchas*, asks the thread that runs it to look.
  *(the next thread that changes a `uses:` line)*
