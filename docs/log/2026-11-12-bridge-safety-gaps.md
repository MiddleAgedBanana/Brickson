# Two safety gaps in the agent bridge closed, and its briefs kept out of the docs check

*2026-11-12. Pull request #99 (`claude/project-thread-36u0wr`). A cloud
thread, from the coordinator's brief, for the two findings pull request
#91 declined after its final push and left "for the next bridge pull
request to record", and one more the coordinator passed on from a thread
on the Mac.*

## What changed and why

Nothing in the app changes. `scripts/agent-bridge.py`, which hands a job
to Codex or agy (Google Antigravity) on the owner's Mac, closes two gaps
that reviewers found on #91 after its last push
([record](2026-11-08-agent-bridge.md)).

**agy's guard hook must be exactly the one installed, and is put back
after every job.** agy is held to Brickson's guard by a hook file in its
folder, `~/code/brickson-antigravity/.agents/hooks.json`, which runs the
guard's adapter, `.agents/hooks/brickson_guard_adapter.py`, before every
tool. The whole `.agents/` folder is git-ignored, so git never shows a
change to it. The bridge used to check only that the file *named* the
adapter, so a job could rewrite it to keep the name under a matcher that
matches no tool, and the next agy session, with agy's own GitHub
connection, would run unguarded (Codex's security review of `d7e713c`).
Now:

- Before every agy job, the bridge reads both files without following a
  link anywhere below agy's folder, and refuses the job unless the hook
  file is exactly what the set-up installed
  ([its text](2026-11-08-codex-antigravity-setup.md)): matcher `*`, type
  `command`, `python3 '<agy's folder>/.agents/hooks/brickson_guard_adapter.py' --format antigravity`,
  timeout 30, and nothing else. It compares the file's meaning, not its
  spacing, and refuses a key written twice, which the bridge and agy
  could each read differently. The adapter must be there as a plain file.
- It keeps both files' bytes before the job. After the job, if either
  changed, it writes them back without following a link the job left,
  making `.agents/` or `.agents/hooks/` again if the job removed them or
  put a link in their place (the link is removed, never followed). The
  job then ends as `changed its own guard hook (...); the bridge put it
  back`, and exits 1, for read-only and write jobs alike. If they cannot
  be put back (the job left a folder where the file was), the job ends
  saying so, that agy may run unguarded until the hook is reinstalled,
  and the next agy job is refused until it is. `summary.json` has a new
  `guard_hook` entry: `unchanged`, or what was changed and whether it was
  put back.
- `python3 scripts/agent-bridge.py status` says `agy guard hook:
  installed` only for the exact hook, and otherwise what is wrong.

The adapter is covered as well as the hook file: a job that rewrote the
adapter to let everything through would weaken the guard in the same
way. Codex's own hook file, `~/.codex/hooks.json`, is still checked only
for the adapter's name: it is outside every folder Codex's sandboxes let
a job write, and Codex runs a new or changed hook only after the owner
trusts it ([set-up record](2026-11-08-codex-antigravity-setup.md)).

**File names git escapes are now compared.** A read-only job must not
change a file, so the bridge compares the contents of every changed or
new file before and after the job. It read their names from `git status
--porcelain`, which puts a name in quotes and escapes what is in it when
it holds letters outside ASCII, quotes, backslashes or control
characters (`résumé.md` became `"r\303\251sum\303\251.md"`). The bridge
took off the quotes but not the escapes, so it never found the file, and
a read-only job that rewrote someone's uncommitted `résumé.md` ended as
`finished` (Codex, on `cc6069e`). Now it reads `git status --porcelain
-z`, where git writes each name exactly as it is on disk and ends it with
a NUL, and a rename's original name comes as a field of its own. File
names are read as bytes, so a name that is not text cannot stop the
bridge. `summary.json`'s `changed_files` now shows names as they are
(`?? résumé.md`), and a rename as `R  old -> new`, without quotes.

**The docs check reads only the repository's own files.**
`scripts/test-docs.py` used to read every file under the checkout,
ignored ones included, so a bridge job's `brief.md` under
`build/agent-bridge/`, which may cite a section that does not exist yet,
failed the check on the Mac (not on CI, where `build/` is empty when the
check runs). It now lists files with `git ls-files --cached --others
--exclude-standard`: every committed file and every new one not yet
added, and nothing git ignores (`build/`, the `xcode-skills/` folder of
Apple's exported skills). On this checkout it reads the same 425 files
as before.

## Commits

The commits of pull request #99.

## Verified

In a cloud container (Linux, git 2.43), with Python 3.13 and with
Python 3.9.25, the version of the Mac's `/usr/bin/python3`:

- `scripts/test-agent-bridge.py`: 40 of 40 on both. Six tests are new,
  and each failed on `main`'s bridge (19 failures across their cases):
  - `test_agy_needs_exactly_the_guard_hook`: ten hook files, each still
    naming the adapter (a matcher that matches nothing, an adapter outside
    the folder, the guard's answer thrown away, a hook beside the guard, a
    second hook in its entry, no timeout, the key written twice with the
    first copy broken, the hook file or the adapter a link, the adapter
    missing), each refused before agy starts.
  - `test_an_agy_job_that_changes_its_guard_hook_is_reported_and_put_back`:
    a stand-in agy that rewrites the matcher and the adapter, swaps the
    hook file or the whole `.agents/` folder for a link to a folder
    outside, or deletes `.agents/`. Each job ends as changed and put back,
    both files are byte for byte as installed, nothing outside is written,
    and the next job runs with `guard_hook: unchanged`.
  - `test_an_agy_write_job_that_changes_its_guard_hook_is_reported`.
  - `test_a_guard_hook_that_cannot_be_put_back_is_reported_and_stops_the_next_job`:
    a folder left where the hook file was.
  - `test_a_file_whose_name_git_escapes_is_still_compared`: `résumé.md`,
    `say "hi".txt`, a backslash, a tab and a line break in a name, each
    rewritten in its own read-only job and each reported; untouched, they
    are listed by their real names and the job finishes.
  - `test_a_renamed_file_is_listed_once_and_compared`: a staged rename,
    rewritten, is listed once as `RM AGENTS.md -> agents notes.md`.
- `scripts/test-docs.py`: 58 of 58 on both Pythons. The new
  `test_only_the_repositorys_own_files_are_read` makes a throwaway
  repository with a committed file, a deleted one, a new one not yet
  added, a brief under an ignored `build/` and a skill under an ignored
  `xcode-skills/`, and expects only the committed and the new file; it
  failed on `main`'s check, which walked the folder.
- Eight broken copies of the new code each failed the tests named:
  never putting the hook back (the four put-back tests); checking only
  the adapter's name (the exact-hook cases but the links, the missing
  adapter and the duplicate key); allowing a key twice (that case); writing back through
  a link (the link case); not making a removed or linked folder again
  (those two cases); reading through links (the two link cases); reading
  status without `-z` (both name tests); and not reading a rename's
  original name (the rename test).
- `scripts/test-runner.py`, `scripts/test-hooks.py` and
  `scripts/test-privacy.py`, and
  `scripts/privacy-check.py --outgoing --no-list`: a cloud thread has no
  private list, so that checked the built-in patterns only. This pull
  request adds no check to `scripts/test.sh`, so `scripts/test-runner.py`
  needs no new stand-in.
- GitHub CI runs these tests on macOS with `/usr/bin/python3`, Apple's
  Python 3.9, through `scripts/test.sh`.
- **The hook file installed on the Mac**, against the exact text the
  bridge now requires. This line was first under *Not verified*, which
  was a mistake in this record: the check was made at 05:58 UTC on
  2026-11-12, before this pull request merged at 08:06 UTC, and pull
  request #109 corrected the line. On 2026-11-12, in a throwaway worktree of
  this branch at its last commit, `117ab61` (removed afterwards), a thread
  on the Mac ran `python3 scripts/agent-bridge.py status`, which printed
  `agy guard hook: installed` and `codex guard hook: installed`, with
  agy's folder present, codex-cli 0.167.2 and agy 1.5.3.

## Not verified

- A real agy job through the new code; the stand-ins answer as agy did on
  2026-11-08.
- Whether agy reads its hook file again during a job. If it does, the
  steps a job takes after changing its hook may run unguarded within that
  same job; the bridge then reports the job and puts the hook back, and
  the job's no-push settings still apply.
- Folder repair after a job leaves something other than a link or nothing
  in place of `.agents/` or `.agents/hooks/` (a plain file, say): the
  bridge reports that it could not put the hook back, and refuses the next
  agy job, but does not move what is there.
- When the bridge puts back a removed `.agents/`, only the hook and the
  adapter come back; anything else the job deleted there (such as
  installed skills) does not.

## Follow-ups

- **A Codex write job cannot commit** (the next bridge pull request;
  found by a thread on the Mac on 2026-11-12, job
  `20261112T054316Z-codex-write`: 85 s, stopped at `index.lock`, no
  commits). The bridge makes `~/code/brickson-codex-<topic>` a git
  worktree, whose git folder is inside the owner's checkout's `.git`.
  Codex's `workspace-write` sandbox keeps `.git` and a worktree's git
  folder read-only on purpose, on macOS as on Linux, and `--add-dir`
  does not lift it: openai/codex issue 14338 (open) and its duplicate
  23661, read 2026-11-12. Making the shared `.git` writable instead would
  let the agent change the owner's checkout's branches, settings and git
  hooks, which the sandbox exists to stop. Not tried from this cloud
  thread, which cannot run Codex. Two ways to weigh, each to be measured
  on the Mac's Codex first: Codex leaves its work uncommitted and the
  bridge, outside the sandbox, commits the files git shows as changed
  (the agent's final message as the commit message, the privacy check
  first); or a separate clone instead of a worktree, with only that
  clone's `.git` named as a writable root (reported to work by naming
  `.git` itself, but also reported to lose to the read-only rule in
  recent Codex). The first loosens nothing.
- **The guard's own code in agy's folder** (for the coordinator). The
  adapter runs the guard in agy's folder, `.claude/hooks/guard.py`, which
  git tracks. A read-only job that changes it is reported and the next
  job refused until the folder is clean, but the bridge does not put it
  back; and a write job could commit a weakened guard on its branch, which
  agy's folder keeps checked out for the next read-only job. Found while
  making this change; outside the two findings this pull request was for.
- Done: a thread on the Mac ran `status` and saw `agy guard hook:
  installed` (on 2026-11-12, in a worktree of this branch at `117ab61`;
  *Verified*).
