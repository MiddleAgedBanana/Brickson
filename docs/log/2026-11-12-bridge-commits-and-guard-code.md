# The bridge commits a Codex write job's work, and puts back the guard's code after every agy job

*2026-11-12. This pull request (`claude/project-thread-th5gpm`). A cloud
thread, from a planner thread's brief, for the two follow-ups of
[pull request #99's record](2026-11-12-bridge-safety-gaps.md), and one
line of that record found to be out of date.*

## What changed and why

Nothing in the app changes. `scripts/agent-bridge.py`, which hands a job
to Codex or agy (Google Antigravity) on the owner's Mac, changes in two
ways, and #99's record is corrected in one place.

**A Codex write job's work is committed by the bridge.** Codex's
`workspace-write` sandbox keeps a worktree's git folder read-only on
purpose, so a Codex write job could not commit (found on the Mac on
2026-11-12; #99's record, *Follow-ups*). Of the two ways that record
weighed, this takes the one that loosens nothing: Codex leaves its work
uncommitted, and the bridge, outside the sandbox, commits it after Codex
ends. Codex's write instructions now say so: do not stage or commit,
leave the work uncommitted, and begin the final message with one line of
at most 72 characters that says what the change does. agy's instructions
and behaviour do not change: agy commits by itself.

- Only when Codex exited 0. If it failed, timed out or was stopped,
  nothing is committed, the work stays as it is, and `summary.json`'s new
  `bridge_commit` entry says why.
- Every changed, new or deleted file outside `build/`, as the bridge's
  `changed_files()` reads them from `git status --porcelain -z`, goes into
  one commit on `codex/<topic>`. Files are staged by name with
  `--literal-pathspecs`, so a name such as `:x.txt` or `[ab].txt` is
  staged as itself and never read as a pattern; nothing under `build/` is
  committed. The commit is made before `summary.json` is written, so its
  `commits` lists it, the status is `finished` and the folder is clean.
- Every git call goes through the bridge's own `git()`, with git hooks and
  `core.fsmonitor` off, so nothing an agent left in the checkout (a hook
  in `.githooks/`, where Brickson's `core.hooksPath` points) runs outside
  the sandbox.
- Before the commit, the bridge stages the files and runs the privacy
  check that sits beside it, `scripts/privacy-check.py` in the bridge's
  own checkout, never the copy in the job's checkout, which the agent
  could have edited. It keeps that file's bytes when the job starts, and
  if they changed during the job, it commits nothing. The check runs as
  `--outgoing --text -` on the job's checkout, with the commit message on
  its stdin, in the bridge's environment without GitHub tokens (not the
  job's). If it reports anything, cannot run or has no private list,
  nothing is committed and nothing is left staged; the job ends as
  `finished, but its work is not committed: ...` and exits 1, and the
  check's output, which gives places and kinds only, is kept in the job
  folder as `privacy-check.txt`. So the bridge is no way round the
  guard's rule that a commit holds no personal detail.
- The commit message is the first non-empty line of Codex's final
  message, with Markdown's markers taken off and cut to 72 characters, as
  the subject; the rest as the body; and a last line saying the bridge
  committed it for which job folder. An empty final message gives the
  subject `Work from Codex on codex/<topic>`.
- If Codex did commit by itself (a later Codex may be allowed to), its
  commits stay and the bridge commits only what is left; with nothing
  left, it makes no empty commit (`bridge_commit: nothing to commit`).

*Decision: the bridge commits with signing off*
(`-c commit.gpgsign=false`). The bridge runs unattended on the Mac, where
nobody can answer a signing prompt, and a prompt nobody answers would stop
the job with the work uncommitted. The commit is made with the Mac's own
git name and address, like a commit the thread would make. The thread
reads the commit before it pushes, as it reads every agent's commits.

**The guard's own code in agy's folder is put back after every agy job.**
agy's hook runs the adapter, which runs the guard in agy's folder,
`.claude/hooks/guard.py`, which loads that folder's
`scripts/privacy-check.py` (`PRIVACY_SCRIPT` in the guard;
[set-up record](2026-11-08-codex-antigravity-setup.md), *The adapter, as
installed*). Both are tracked files, so #99's put-back of the
git-ignored hook files did not cover them (#99's record, *Follow-ups*).
Now:

- Before the agent starts (for a write job, after its branch is made),
  the bridge keeps both files' bytes and modes, read without following a
  link. If either is not a plain file, the job is refused.
- After the agent ends, finished, failed, timed out or stopped, read-only
  or write, any of them that differs in the working tree is written back
  without following a link the job left, and `summary.json` gets a new
  `guard_code` entry: `unchanged`, or what changed and whether it was put
  back. The job then ends as `changed the guard's code (...); the bridge
  put it back` and exits 1; if it cannot be put back, it says so, and
  that agy may run a changed guard until it is restored from origin/main.
  The hook and the guard's code are put back in a `finally`, so an error
  in the bridge's own reading of agy's output cannot skip either. A job
  the bridge was told to stop now keeps that in its status after
  `stopped: ...`, where before the stop replaced it.
- A write job whose commits change the guard's code: the commits stay for
  the thread to read, the working tree gets the earlier code back, and the
  job ends saying its commits change the guard's code. agy's folder then
  shows that as an uncommitted change, so the next agy job is refused
  (`require_clean`) until a thread has dealt with those commits. After a
  read-only job that changed the guard's code, the folder is clean again
  and the next job runs with `guard_code: unchanged`.

*Known limit:* the bridge does not compare the guard's code in agy's
folder with origin/main before a job. Code that was already changed
before the bridge kept it is kept and put back as it was.

**#99's record, corrected.** Its first *Not verified* line, the hook file
installed on the Mac, was checked on 2026-11-12, so it now sits under
*Verified*, and its last follow-up, running `status` on the Mac, is
marked done by that same check.

## Commits

The commits of this pull request.

## Verified

In a cloud container (Linux, git 2.43), which cannot run Codex or agy,
with Python 3.13 and with Python 3.9.25, the version of the Mac's
`/usr/bin/python3`:

- `scripts/test-agent-bridge.py`: 52 of 52 on both. Twelve tests are new,
  and each failed on `main`'s bridge (19 failing cases between them). Two
  existing tests check the new write instructions: Codex's fails on
  `main`'s bridge, and agy's pins that agy's instructions do not change.
  The new tests:
  - `test_a_codex_write_jobs_work_is_committed_by_the_bridge`: a stand-in
    Codex changes `AGENTS.md`, deletes a tracked file, adds `:x.txt`,
    `[ab].txt`, `résumé.md`, a name with a tab and `docs/new.md`, and
    leaves evidence under `build/`. One commit on `codex/<topic>` holds
    exactly those changes, its parent is origin/main, nothing under
    `build/` is in it, the folder is clean, `commits` lists it and
    `bridge_commit` names its hash.
  - `test_the_commit_message_comes_from_codexs_final_message`: a Markdown
    heading in bold, a line longer than 72 characters, and an empty final
    message (subject naming the branch).
  - `test_hooks_left_in_the_checkout_never_run_when_the_bridge_commits`:
    `core.hooksPath` set to `.githooks`, and the stand-in leaves
    `pre-commit`, `commit-msg` and `post-commit` there; none runs.
  - `test_nothing_is_committed_when_the_privacy_check_finds_a_private_word`:
    a made-up private list in a made-up home, a listed word in a file and
    in the final message; nothing is committed or left staged, the work
    is still there, and the words appear in no file the bridge wrote and
    nothing it printed.
  - `test_nothing_is_committed_without_a_private_list`.
  - `test_nothing_is_committed_when_the_bridges_own_privacy_check_changed`:
    a copy of the bridge and its privacy check, which the stand-in
    changes during the job.
  - `test_nothing_is_committed_when_codex_does_not_finish`: Codex failed,
    and Codex timed out.
  - `test_codexs_own_commits_stay_and_the_bridge_commits_only_the_rest`.
  - `test_an_agy_job_that_changes_the_guards_code_has_it_put_back`: a
    read-only job that rewrites both files and the guard's mode, one that
    leaves a link in the guard's place, one in which agy failed, and a
    write job; each is put back byte for byte, nothing outside is written,
    and the next job runs with `guard_code: unchanged`.
  - `test_the_guards_code_is_put_back_when_the_bridge_is_stopped`.
  - `test_the_guards_code_is_put_back_even_when_agys_output_cannot_be_read`:
    agy's output is not text, the bridge fails reading it, and both the
    guard's code and the hook are put back.
  - `test_an_agy_write_job_whose_commits_change_the_guards_code`: the
    commit stays, the working tree has the earlier code, and the next agy
    job is refused.
- Broken copies of the new code each failed the tests named: git hooks
  left on in the bridge's git (the hooks test); staging without
  `--literal-pathspecs` (the commit test); skipping the privacy check's
  answer (the private-word and no-list tests); running the job's copy of
  the check instead of the bridge's (the same two); not comparing the
  bridge's check with its bytes at the start (the changed-check test);
  committing after Codex failed or timed out (that test); never putting
  the guard's code back (the four put-back tests); writing it back
  through a link (the put-back test); putting it back outside a `finally`
  (the unreadable-output test); and a stop that hides why the job failed
  (the stopped test). Dropping the bridge's own `build/` filter when it
  stages changed no result, because `changed_files()` already leaves out
  everything under `build/`; the commit test pins that.
- `scripts/test-docs.py`, `scripts/test-hooks.py`,
  `scripts/test-privacy.py`, `scripts/test-runner.py`,
  `scripts/test-select-xcode.py` and `scripts/test-site.py`, and
  `scripts/privacy-check.py --outgoing --no-list`: a cloud thread has no
  private list, so that checked the built-in patterns only.

## Not verified

- A real Codex write job through the new code on the Mac, ending in a
  bridge commit. The stand-in Codex answers as Codex did on 2026-11-08 and
  2026-11-12; the real one's final message may not begin with a one-line
  summary.
- The privacy check before the commit with the owner's real list on the
  Mac; the tests give it a made-up list.
- Whether committing with signing off behaves as expected on the Mac
  (with the Mac's git name and address, and no prompt).
- A real agy job through the new put-back of the guard's code.
- The bridge's git still applies filters that the Mac's own git settings
  define for files a `.gitattributes` names (such as Git LFS); a job
  cannot add such a setting inside Codex's sandbox, and none is set for
  Brickson.

## Follow-ups

- A thread on the Mac runs one small Codex write job through the bridge
  once this merges, and reads its commit and `privacy-check.txt`.
- The bridge stops with a Python error, writing no `done`, when agy's
  output is not UTF-8 text (found while testing the put-back; the guard's
  code and hook are still put back). A later bridge pull request reads it
  with errors replaced.
