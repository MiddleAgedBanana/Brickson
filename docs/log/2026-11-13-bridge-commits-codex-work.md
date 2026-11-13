# The bridge commits a Codex write job's work, and puts agy's guard code back

*2026-11-13. Branch `claude/project-thread-rgqoqf`. A cloud thread, from
the coordinator's brief, for the two bridge follow-ups that pull request
#99 left ([record](2026-11-12-bridge-safety-gaps.md), *Follow-ups*), and
one stale line in that record.*

## What changed and why

Nothing in the app changes. `scripts/agent-bridge.py`, which hands a job
to Codex or agy (Google Antigravity) on the owner's Mac, closes the two
gaps #99's record left for the next bridge pull request.

**The bridge commits a Codex write job's work.** A Codex write job could
not commit: the bridge makes `~/code/brickson-codex-<topic>` a git
worktree, whose git folder sits inside the owner's checkout's `.git`, and
Codex's `workspace-write` sandbox keeps that folder read-only on purpose
(found on the Mac on 2026-11-12, job `20261112T054316Z-codex-write`).
Of the two ways #99's record named, this takes the one that loosens
nothing:

- Codex's brief now tells it to leave its work uncommitted, and to begin
  its final message with one line under 72 characters that says what the
  change does. agy's brief is unchanged: it has no sandbox and commits
  itself.
- Once the job has **finished** (exit 0, not timed out, not stopped), the
  bridge, outside the sandbox, stages every changed, deleted or new file
  outside `build/` by name and makes one commit on `codex/<topic>`, with
  Codex's final message as the commit message and a last line naming the
  bridge and the job. The worktree was clean when the job began (the
  bridge refuses it otherwise), so every such file is the job's. Names
  are read literally (`--literal-pathspecs`), so a file named like a
  pathspec, such as `:!AGENTS.md`, is committed itself and never leaves
  another file out. The bridge's own git still runs with git hooks and
  `core.fsmonitor` off and without the thread's GitHub tokens, so nothing
  the job set can run there. The commit is unsigned (`--no-gpg-sign`):
  nobody is there to answer a signing prompt, as for an agent's own
  commits on the Mac ([record](2026-11-07-workflow-lockfile.md)). Nothing
  is pushed; the thread checks the commit, runs the privacy check before
  its push as for any push, and pushes.
- A job that failed, timed out or was stopped is not committed: its
  changes stay in the worktree for the thread to read. A job that changed
  nothing makes no commit. If the commit itself fails, the job ends as
  `finished, but the bridge could not commit its work (...)`, exits 1,
  and leaves the changes staged.
- `summary.json` has a new `bridge_commit` entry for Codex write jobs:
  `made <hash>`, `nothing to commit`, or `not made: ...` with the reason.

**agy's guard code is put back after every job.** agy's adapter runs the
guard in agy's folder, `.claude/hooks/guard.py`, which git tracks, and the
guard runs `scripts/privacy-check.py` there. A job that changed either
weakened the guard for the next agy session: a read-only job's change was
reported and the next job refused, but never put back, and a write job
could commit a weaker guard on its branch, which agy's folder keeps
checked out for the next job. Now:

- Before every agy job (after the write job's new branch is made), the
  bridge keeps both files' bytes, reading them without following a link,
  and refuses the job if either is missing or a link.
- When the job ends, however it ends (finished, failed, timed out,
  stopped, or the bridge itself stopping with an error), it puts back
  any of them the job changed, without following a link the job left, as
  #99 does for agy's hook. The job ends as `changed the guard's own code
  (...); the bridge put it back` and exits 1.
- If the job committed a change to either file, the bridge does not
  rewrite the agent's commit: the folder keeps the guard as it was before
  the job, so it differs from that commit, the job ends as `committed a
  change to the guard's own code (...) on its branch; ...`, and the next
  agy job is refused (uncommitted changes) until someone has read that
  commit and cleaned the folder.
- `summary.json` has a new `guard_code` entry, like `guard_hook`.

**A job that did not finish still says so first.** When a job that
failed or timed out also has a problem to report (its guard changed, or
it ran in the wrong folder), its status now starts with `failed (exit
n); ` or `timed out; ` before the problem, where it used to show only the
problem.

**The stale line in #99's record.** Its *Not verified* list said the hook
file installed on the Mac had not been checked against the exact text the
bridge requires. It had: on 2026-11-12, before the merge, a thread on the
Mac ran `python3 scripts/agent-bridge.py status` in a throwaway worktree
of #99's last commit, `117ab61`, and it printed `agy guard hook:
installed` and `codex guard hook: installed`. The line now sits under
*Verified* there, saying it was corrected, and the follow-up asking for
that check says it was done.

## Commits

The commits of this pull request.

## Verified

In a cloud container (Linux, git 2.43), with Python 3.13 and with
Python 3.9.25, the version of the Mac's `/usr/bin/python3`:

- `scripts/test-agent-bridge.py`: 47 of 47 on both. Seven tests are new,
  and each failed on `main`'s bridge, as did the one changed test:
  - `test_the_bridge_commits_a_codex_write_jobs_work_outside_the_sandbox`:
    a stand-in Codex changes `AGENTS.md`, deletes a file and adds three
    (one with a space, one with letters outside ASCII, one named
    `:!AGENTS.md`); the job finishes with one commit on `codex/tests`
    whose parent is `origin/main`, holding exactly those five changes,
    with the final message as its message, and a clean worktree.
  - `test_a_codex_write_job_that_does_not_finish_is_left_uncommitted`:
    one that fails (exit 3) and one that times out, each with no commit
    and its changes left.
  - `test_a_codex_write_job_that_changes_nothing_makes_no_commit`.
  - `test_a_commit_the_bridge_cannot_make_is_reported`: git refuses an
    empty author name; the job ends saying so, exits 1, and writes `done`.
  - `test_an_agy_job_that_changes_the_guards_own_code_is_reported_and_put_back`:
    a stand-in agy rewrites both files, swaps the guard for a link to a
    file outside the folder, or deletes `.claude/` and the privacy check,
    each in a job that finishes and in one that fails (exit 3). Each is
    put back byte for byte, nothing is written through the link, the
    folder is clean, and the next job runs with `guard_code: unchanged`.
  - `test_an_agy_write_job_that_commits_a_weaker_guard_is_reported_and_stops_the_next_job`:
    the folder keeps `origin/main`'s guard, and the next job is refused
    before agy starts.
  - `test_agy_refuses_a_guard_that_is_not_a_plain_file`: a branch that
    holds the guard as a link is refused before agy starts.
  - `test_a_codex_write_job_needs_the_hook_and_starts_its_own_branch`
    now also checks that Codex is told to leave its work uncommitted.
- Eight broken copies of the new code each failed the tests named:
  staging without `--literal-pathspecs` and never committing (the commit
  test and the failed-commit test); committing a job that did not finish
  (that test); a failed commit reported as nothing (that test); never
  putting the guard code back (both put-back tests); not reading what the
  job committed (the write-job test); allowing a linked guard (that
  test); and a failed job's status showing only the problem (the put-back
  test).
- `scripts/test-docs.py`, `scripts/test-runner.py`,
  `scripts/test-hooks.py` and `scripts/test-privacy.py` (results in the
  pull request), and `scripts/privacy-check.py --outgoing --no-list`: a
  cloud thread has no private list, so that checked the built-in
  patterns only.
- GitHub CI runs these tests on macOS with `/usr/bin/python3`, Apple's
  Python 3.9, through `scripts/test.sh`.

## Not verified

- **A real Codex write job through the new code.** The stand-in edits
  files and stops as the real one did on 2026-11-12; whether the real
  Codex, told to leave its work uncommitted, does so without trying a
  commit first, and whether its final message begins with a usable
  summary line, is for the first real write job on the Mac.
- **A real agy job through the new code**, as for #99.
- **A commit on the Mac**: that the owner's git identity is set where the
  bridge runs, and that an unsigned commit is what the owner wants for
  the bridge's commits, as for an agent's own commits there.
- Whether agy or its guard reads `guard.py` again during a job: if so,
  steps a job takes after weakening it may run unguarded within that same
  job. The bridge then reports it and puts it back, and the job's no-push
  settings still apply.
- When a job deletes `.claude/`, only `guard.py` comes back; anything
  else it deleted there (such as `.claude/settings.json`) stays deleted,
  shows as a changed file, and the next job is refused until the folder
  is clean.
- One commit holds a Codex job's whole work. AGENTS.md asks for one task
  per commit; the thread can split it before pushing, and a brief can ask
  for one task per job.

## Follow-ups

- The first real Codex write job on the Mac is the test of this change
  (a thread on the Mac, when the coordinator next hands Codex a write
  job).
