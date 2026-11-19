# The bridge commits a Codex write job's work, and puts back the guard's code after every agy job

*2026-11-12. Pull request #109 (`claude/project-thread-th5gpm`). A cloud
thread, for the two follow-ups of
[pull request #99's record](2026-11-12-bridge-safety-gaps.md), and one
line of that record found to be out of date. Pull request #108 did the
same work another way; what its review found was brought in here on
2026-11-19 (*Brought over from pull request #108*).*

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
  one commit on `codex/<topic>`, unless one of them is a repository the
  job left inside its worktree, or a folder git lists as one entry (a
  name ending in `/`, a folder that is not a link, or one holding a
  `.git` entry). Then nothing is staged or committed, and the job ends
  saying which (*Three fixes from an independent review*, below). Files
  are staged by name with
  `--literal-pathspecs`, so a name such as `:x.txt` or `[ab].txt` is
  staged as itself and never read as a pattern; nothing under `build/` is
  committed. The commit is made before `summary.json` is written, so its
  `commits` lists it, the status is `finished` and the folder holds no
  change outside `build/`.
- Every git call goes through the bridge's own `git()`, with git hooks,
  `core.fsmonitor` and every filter the settings define off, so no hook
  an agent left in the checkout (in `.githooks/`, where Brickson's
  `core.hooksPath` points), no fsmonitor command it set and no filter it
  named runs outside the sandbox (for filters, and for what is not turned
  off, see *Brought over from pull request #108*). Those settings do not
  reach a
  repository the job left inside its worktree, whose own settings git
  obeys once it is staged; that is why such a repository is never
  staged.
- Before the branch moves, the bridge stages the files, makes the commit
  as an object (`git write-tree`, then `git commit-tree`, with the author
  and committer git gives it from its settings or from `GIT_AUTHOR_*` and
  `GIT_COMMITTER_*`), and runs the privacy check that sits beside it,
  `scripts/privacy-check.py` in the bridge's own checkout, never the copy
  in the job's checkout, which the agent could have edited. It keeps that
  file's bytes when the job starts, and if they changed during the job,
  it commits nothing. The check runs as `--outgoing --commits
  <old>..<new> --text -` on the job's checkout, with the commit message on
  its stdin, in the bridge's environment without GitHub tokens (not the
  job's) and with the same filters off: so it reads the job's staged and
  changed files and its other
  outgoing commits, and the new commit as git keeps it, with its files,
  message, author and committer. Only if it passes does `git update-ref`
  move `codex/<topic>` to that commit, and only from the commit it
  started from; the index already holds the commit's tree, so nothing is
  left to commit. If the check reports anything, cannot run or has no
  private list, the branch does not move, nothing is left staged and the
  work stays in the files; the job ends as `finished, but its work is not
  committed: ...` and exits 1, and the check's output, which gives places
  and kinds only, is kept in the job folder as `privacy-check.txt`. Its
  exit code 1 means a finding, or that the check itself failed, and the
  status says both. So the bridge is no way round the guard's rule that a
  commit holds no personal detail.
- The commit message is the first non-empty line of Codex's final
  message, with Markdown's markers taken off and cut to 72 characters, as
  the subject; the rest as the body; and a last line saying the bridge
  committed it for which job folder. An empty final message gives the
  subject `Work from Codex on codex/<topic>`.
  `commit-tree` keeps the message exactly as checked; `git commit` would
  also have taken trailing spaces off its lines.
- If Codex did commit by itself (a later Codex may be allowed to), its
  commits stay and the bridge commits only what is left; with nothing
  left, it makes no empty commit (`bridge_commit: nothing to commit`).

*Decision: the bridge commits with signing off*
(`git commit-tree --no-gpg-sign`). The bridge runs unattended on the Mac,
where nobody can answer a signing prompt, and a prompt nobody answers would
stop the job with the work uncommitted. The commit is made with the Mac's
own git name and address, like a commit the thread would make, and the
privacy check reads them before the branch moves. The thread
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
  Before the agent starts and again in the same `finally`, the bridge
  removes the bytecode caches beside the guard's code,
  `scripts/__pycache__` and `.claude/hooks/__pycache__`, without following
  a link (a link there is removed); `summary.json`'s `guard_cache` says
  what it removed. If one cannot be removed, the job ends saying so.
  The hook and the guard's code are put back in a `finally`, so an error
  in the bridge's own reading of agy's output cannot skip either, and a
  stop after agy has exited is noted, not fatal, until `done` is written
  (*CodeRabbit's review of the second push*, below). A job the bridge was
  told to stop now keeps that in its status after `stopped: ...`, where
  before the stop replaced it.
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

**Three fixes from an independent review.** No outside reviewer could
review this pull request (each was at its limit), so a separate Claude
subagent reviewed it, against *Code Review Rules*, and showed three faults
by running the bridge with stand-in agents. Each is fixed, test first:

- *A repository left inside a Codex job's worktree.* git lists one as a
  single entry (`sub/`), and the bridge staged it as a link to that
  repository. git then obeyed that repository's own settings, which the
  job wrote, in the bridge's later git calls and the privacy check's: a
  clean filter it named ran outside Codex's sandbox, twice, and the job
  still ended `finished`, with the link committed. The bridge's own
  settings (hooks and fsmonitor off) do not reach it. Now such an entry
  is never staged (above).
- *A bytecode cache beside the guard's code.* guard.py loads
  `scripts/privacy-check.py` through Python's loader, which uses a cache
  in `scripts/__pycache__`, and one made as an unchecked hash-based
  `.pyc` is never compared with its source. A job that left one there
  ended with `guard_code: unchanged`, git ignores the folder, so the next
  job ran, and loading the check as the guard does ran the job's code.
  Putting the source back did not put back what the guard runs. Now the
  bridge removes those caches before and after every agy job (above).
- *A stop while the bridge commits.* Once Codex ended, the bridge's stop
  handling was off, so a stop during the privacy check (up to 15
  minutes) killed the bridge with every file staged and no `summary.json`
  or `done`. Now, for a Codex write job, a stop after the agent ends is
  noted until `done` is written: it ends the privacy check, nothing is
  staged or committed, and the job ends `stopped: the bridge was told to
  stop after Codex finished, before it committed; ...` and exits 1. git
  itself is never cut off, so it leaves no lock; a stop that comes while
  git is moving the branch to the checked commit lets that finish, and the job then
  ends `finished` with the commit made, as if the stop had come just
  after it.

**CodeRabbit's review of the second push.** Two of its three findings
were real, and each is fixed, test first:

- *The commit's author and committer were never checked.* The check read
  the staged files and the message, then `git commit` recorded whatever
  author and committer git took from its settings or from the bridge's
  environment, which no check read: with clean files and
  `GIT_AUTHOR_NAME` set to a word on the private list, the commit was
  made. Now the bridge makes the commit object first, the check reads
  that very commit with `--commits`, and only then does the branch move
  (above). `test_nothing_is_committed_when_the_commits_identity_holds_a_private_word`
  puts a listed word in the author name, in the committer name and in an
  address: in each case the job exits 1, the branch has not moved, the
  files still hold the work, nothing is staged, and no file the bridge
  wrote and nothing it printed holds the word. All three cases failed on
  the bridge before the fix (exit 0, committed), and on a broken copy
  that makes the commit object but leaves `--commits` off.
- *A stop after agy had exited skipped the put-back.* `run()` puts back
  the signal handlers it found, which in an agy job were the defaults, so
  a SIGTERM or SIGHUP after agy had exited ended the bridge at once: the
  hook and the guard's code were not put back, the caches were not
  removed and no `done` was written. Now an agy job notes stops, as a
  Codex write job does, from before `run()` until `finish()` has
  returned, and a noted stop ends the job as `stopped: the bridge was
  told to stop after agy ended; ...`.
  `test_a_stop_after_agy_has_exited_still_puts_everything_back` starts
  the bridge through a small driver that makes the bridge send itself
  SIGTERM, and in a second case SIGHUP, as it begins putting the hook
  back, after a stand-in agy changed the hook and the guard's code and
  left a cache. Everything is put back, the cache is gone, and
  `summary.json` and `done` say the job was stopped. On the bridge before
  the fix the bridge was killed (exit -15) with nothing put back.

**Declined:** its third finding, to move the correction in #99's record
back under *Not verified*, on the grounds that the Mac check came after
#99 merged. It did not: the check was made at 05:58 UTC on 2026-11-12,
four minutes after that branch's last commit `117ab61` (05:54 UTC), and
#99 merged at 08:06 UTC (merge `3f92a8b`). The line was untrue when it
merged, a mistake in that record, which `docs/log/README.md` says to
correct in place; the corrected bullet now says so. CodeRabbit then
checked the times itself and withdrew the finding.

**CodeRabbit's review of the third push.** One finding, real, and
reproduced with the stand-in Codex: `plain_environment()`, the
environment of the bridge's own git and of the privacy check it runs,
took out only the GitHub tokens, so git's own repository variables passed
through, and git obeys them before the `-C <checkout>` the bridge gives
it. A write job started with `GIT_INDEX_FILE` naming the owner checkout's
index ended `finished` with its commit made, but left the job's files
staged in the owner checkout's index, and the job checkout's own index no
longer matched its commit. `job_environment()` had the same gap for the
agent's own git. `main`'s bridge already passed these variables on; a job
cannot set them, since they have to be in the environment of whoever
starts the bridge. Now both take out the fifteen variables git itself
lists as belonging to one repository (`git rev-parse --local-env-vars`,
written out in the bridge as `REPOSITORY_VARIABLES`). A job keeps the
three configuration ones, `GIT_CONFIG`, `GIT_CONFIG_PARAMETERS` and
`GIT_CONFIG_COUNT`, since its no-push settings are added after any
`GIT_CONFIG_COUNT` entries it inherits, as before. Everything else stays,
the author and committer variables among them. Test first:

- `test_git_variables_the_bridge_inherits_never_point_its_git_elsewhere`
  starts a Codex write job with `GIT_INDEX_FILE` naming the owner
  checkout's index, and in a second case with `GIT_DIR` and
  `GIT_WORK_TREE` naming the owner's checkout. In each, the job exits 0
  with its commit on `codex/<topic>` holding the job's files; the owner
  checkout's index is byte for byte what it was, its status is empty and
  its `HEAD` and other branches have not moved; and the job checkout's
  status is empty. On the third push's bridge (`b00d769`) the first case
  failed (the owner's index changed) and the second could not start (the
  bridge took the checkout it was started in for the owner's own, and
  refused).
- `test_a_job_gets_none_of_gits_repository_variables` starts a read-only
  Codex job with the twelve variables that are not configuration set, and
  an inherited `GIT_CONFIG_COUNT` entry. The stand-in agent now logs its
  `GIT_*` variables: none of the twelve reaches it, the inherited entry is
  still entry 0, and the no-push entries follow it. On the third push's
  bridge the job was refused, as above; on a copy with only
  `plain_environment()` fixed, the variables reached the agent; on a copy
  whose jobs also drop the three configuration variables, the inherited
  entry was lost.
- `test_nothing_is_committed_when_the_commits_identity_holds_a_private_word`
  passes unchanged: the identity variables still reach the commit.

This went in as a fourth push. AGENTS.md leaves a real bug found after
the final push to the owner; the owner gave permission on 2026-11-13 to
finish the open threads, and this pull request was allowed one extra
push for late review findings.

**Brought over from pull request #108.** Pull request #108 did this same
work from the same `main` in another way. This pull request is the one
put forward to merge, with #108 to be closed, so on 2026-11-19 its
branch took `main` in again (`606a26b`) and each of the eleven findings
CodeRabbit left on #108 was run against this branch's bridge with the
stand-in agents. Five still happened here and are fixed, test first; four
were already fixed here; two were about #108's record.

Fixed here:

- *A filter the git settings define ran in the bridge's git.* A filter
  runs its command on a file's contents (`clean` when git reads a file
  from the folder, `smudge` when it writes one there, `process` for
  both) wherever an attributes file names it. agy, which has no sandbox,
  can define one in the settings every worktree shares, and a Codex job
  can name it in a `.gitattributes` of its own; the bridge's
  `git status` and `git add`, outside the sandbox, then ran it. Now
  `own_environment()` asks git, before every command of the bridge's own
  git, which filters the settings define for that folder, and turns each
  one off for that command: an empty `clean`, `smudge` and `process`,
  and not `required`, given as `GIT_CONFIG_COUNT` entries, which git
  reads after every settings file. The privacy check the bridge starts
  gets the same entries, so the git it runs applies no filter either.
- *A failed read of the filters was taken as "no filters".* `git config`
  ends 1 when none is set; any other ending now stops the job, before
  the agent starts.
- *A filter set only for the job's branch ran while its worktree was
  made.* The shared settings can turn a filter on for `codex/` branches
  alone (`includeIf "onbranch:codex/"`). Seen from where the bridge
  starts it is off, so nothing turned it off, and `git worktree add`
  filled the new worktree, on its `codex/` branch, with it on. Now the
  worktree is made empty (`--no-checkout`) and the bridge's git fills it
  from inside (`git reset --hard`), where the filter shows. A worktree
  that already exists is moved to the new branch with `git switch -c`,
  which reads its settings while the folder is still on its old branch,
  so such a filter stays off there; a test pins that.
- *A status git could not give read as nothing changed.*
  `changed_files()` passed over a failed `git status`, which prints
  nothing: a Codex write job whose index git could not read ended
  `finished` with `nothing to commit`, exit 0, and agy was started in
  such a folder. Now a failed status stops the caller.
- *A job that left git unreadable ended with no `summary.json` and no
  `done`.* The bridge's git stops when it cannot read which filters to
  turn off, so after a job that broke the settings every worktree shares
  (agy can) the bridge itself stopped, and a caller waiting for `done`
  would have waited for ever. Now the check of the guard's code, the
  bridge's commit and the summary each say what could not be read and go
  on: the job ends `... the bridge could not read the checkout after the
  job (...)`, exits 1, and `summary.json` has `null` for `branch`,
  `commits` and `changed_files`. With it, a job that did not finish says
  so first, then what else went wrong (`failed (exit 3); ...`,
  `timed out; ...`), where before the other problem replaced it; and a
  failure to read the short name of a commit already made no longer
  loses the two files.

Already fixed here, so nothing was ported; each has a test:

- *`GIT_CONFIG_PARAMETERS` outranks what the bridge turns off*, *`GIT_CONFIG`
  points `git config` alone at another file* (where the bridge would look
  for filters, and for a push URL to refuse, and find none) and
  *`GIT_INDEX_FILE` and `GIT_DIR` point git at another index or
  repository*: since `15855e5` the bridge's own git runs without all
  fifteen of git's repository variables, these among them. The last
  already had its test; the first two have new cases.
- *A stopped job's status dropped what else went wrong*: since `8c63b3e`
  the status keeps it after `stopped: ...`, and what could not be read
  now goes the same way.

About #108's record, not its code:

- *Say only what the bridge's git really turns off.* That holds here
  too, so: the bridge's git turns off hooks, `core.fsmonitor` and
  filters, not every setting that can name a command. When it fetches
  `main` before a write job, git still obeys the settings for reaching
  the remote (`core.sshCommand`, a credential helper, a rewritten URL,
  `remote.origin.uploadpack`). Git's settings can be written only from
  outside Codex's sandbox, and agy, which has none, can run any command
  itself, so this is a known limit, not fixed here.
- *Name the pull request and list the commits in the record.* This
  record does both.

CodeRabbit also asked, on #108, for a look at which filters the Mac's
git settings define before the next bridge commit there. A cloud thread
cannot run it; the command is under *Not verified*. Whatever it shows,
the bridge now turns those filters off for its own git.

**The reviews of the fifth push.** cubic left eight findings and
CodeRabbit twelve, one of them the same in both. Each was checked against
the code. Twelve are answered by a change here, the six in the bridge
test first:

- *A job could keep a bytecode cache the bridge never clears* (cubic).
  With `PYTHONPYCACHEPREFIX` set where the bridge starts, Python keeps
  its bytecode under the folder that names and not beside the source, so
  a cache an agy job planted there would outlast the put-back and run in
  place of the restored privacy check. No job's environment carries the
  variable now, so the guard an agent's hook starts uses only the caches
  the bridge clears.
- *Commits that change the guard's code and put it back were reported as
  unchanged* (cubic and CodeRabbit). The bridge compared only where the
  job's commits began and ended. It now also reads every commit the job
  added, a side branch that a merge took nothing from among them, and a
  job whose commits touch the guard's code on the way ends `commits the
  job added change the guard's code (...), though the branch ends with
  the code it began with; read them before they are pushed`. The folder
  is clean then, so the next agy job is not refused.
- *A stop while the agent's processes were being stopped was dropped*
  (cubic). `run()` ignored stop signals for that moment, so a Codex write
  job went on to commit. The stop is now noted there as it is
  afterwards, and the job commits nothing.
- *A failed listing of the job's commits read as no commits*
  (CodeRabbit). The job now says the checkout could not be read, with
  `null` for the three fields, as for every other failed read.
- *A status that said the guard's code was put back after the put-back
  failed* (CodeRabbit), when a job's commits changed the code and left a
  folder where a file was. The sentence about the commits no longer
  claims it.
- *A refusal or a stop that could not unstage the job's files said
  nothing* (CodeRabbit). The bridge clears what it staged with
  `git reset` and did not check it, so when the reset failed the files
  stayed staged and the status said only that the work was not
  committed. The status and `bridge_commit` now say the files may still
  be staged and name the command that clears them. Before the bridge has
  staged anything it adds nothing, since a git that cannot be read is
  what the status already says. This finding was missed when the others
  were answered: the report-only verifier found it unanswered on the
  sixth push, and its fix went in with the seventh (`8068aa1`).
- *The tests' own git* (cubic, and CodeRabbit). The helpers that set up
  and read the made-up checkouts now read the fixture's settings alone,
  and the tests drop git's repository variables before they run git, so
  a runner's fsmonitor or filter, or the index git gives a hook, never
  reaches them. Tests only.
- *This record* (cubic, three findings). The commit list names
  `188e140`, each follow-up says who owns it, and #99's record names the
  merge that brought its commits to `main`.

Not changed, and why:

- *Find the filters and run git with one fixed set of settings*
  (CodeRabbit, as a security finding). Between the bridge reading which
  filters are set and its git starting, another job could add one. Only
  something outside Codex's sandbox can write git's settings, and that
  can already run any command as the same user with the same
  environment, so a filter slipped in there gains nothing; and git has no
  way to turn off a filter it has not been told the name of. A known
  limit. Its conversation is left open, because whether a security
  finding stays a known limit is the owner's decision.
- *A stop while the summary is written* (cubic) and *a stop just before
  the branch moves* (CodeRabbit). Every put-back has run by then, and the
  job ends with `done` either way, saying what happened to its work. A
  check at either place leaves a later instant open all the same.
- *A staged rename whose source the bridge adds again*, *a tracked file
  replaced by a folder of files* and *a tracked file under `build/`
  renamed out of it* (CodeRabbit). The first and last need the agent to
  stage, which Codex's sandbox does not allow, and the last also a
  tracked file under `build/`, which Brickson ignores. In the first two
  the bridge refuses to commit and says so, with the work left in the
  files, though its reason for the second does not fit (*Follow-ups*).
- *A privacy report that cannot be written* (CodeRabbit). When the job's
  folder cannot be written, neither can `summary.json` or `done`, so
  sending the failure to `finish()` would give the caller no result
  either. That reason does not cover the finding's own example, a folder
  left under the report's name, where the rest of the job folder can
  still be written. Either way the bridge ends with Python's own error
  and no `done`; nothing has been committed at that point, and the job's
  files are still staged (*Follow-ups*).
- *agy output that is not text ends with no `done`* (CodeRabbit, outside
  the diff). Already under *Follow-ups*. Reading it with errors replaced
  would also stop the unreadable-output test from pinning the put-back's
  `finally`, so it needs its own test first.

**After the sixth push.** The report-only verifier ran on the sixth push
(`f9e6f03`). It found the unanswered finding above, and that a comment in
`run()` said a stop during the clean-up is never dropped, which does not
hold for a Codex read-only or review job, where nothing reads the note;
the comment now says so (`ab82a2c`). CodeRabbit, having read the answers,
withdrew two of its findings: the staged rename, and the tracked file
under `build/`. On the sixth push it left one finding, marked minor and
outside the diff: staging very many changed files in one `git add` can
pass the operating system's limit on a command's length, and the bridge
then stops with Python's own error and no `done`. Not changed here
(*Follow-ups*). The security finding's conversation waits for the
owner's decision.

**#99's record, corrected.** Its first *Not verified* line, the hook file
installed on the Mac, was checked on 2026-11-12, so it now sits under
*Verified*, and its last follow-up, running `status` on the Mac, is
marked done by that same check. Its *Commits* section now names the
merge that brought them to `main`, `3f92a8b` (cubic, on the fifth push).

## Commits

- `9a01128` Commit a Codex write job's work from the bridge, after the
  privacy check
- `7878f12` Put the guard's own code back after every agy job
- `62b34b3` Record the bridge's commits and guard put-back, and correct
  #99's record
- `d7a3b07` Remove the bytecode caches beside the guard's code around
  every agy job
- `b873c38` Never stage a repository a Codex job leaves inside its
  worktree
- `8cd250b` Keep a stop during the bridge's commit from leaving work
  staged
- `e408f2d` Record the review's three bridge fixes
- `c693f3e` Say what a stop during the bridge's commit really ends as
- `cb60a1b` Merge main into the bridge fixes branch
- `0f7a955` Check the bridge's commit, author and committer included,
  before the branch moves
- `8c63b3e` Note a stop after agy exits, so the put-backs and done still
  happen
- `b2dc55e` Record CodeRabbit's review of the bridge's second push
- `b00d769` Merge main into the bridge fixes branch again (main at
  `8c90597`)
- `15855e5` Keep git's repository variables out of the bridge's git and
  its jobs
- `1dd5e84` Record CodeRabbit's review of the bridge's third push
- `d9e72f1` Say that CodeRabbit withdrew the finding that was declined
- `936c959` Merge main into the bridge fixes branch a third time (main at
  `606a26b`)
- `0f02da6` Turn off every git filter in the bridge's own git
- `775d82f` End every job with done when git cannot be read, and say so
- `17ee831` Pin that a reused worktree runs no filter set for the job's
  branch
- `188e140` Record what was brought over from pull request #108
- `e61e508` Give no job a bytecode cache folder of its own
- `10c4d1c` Name commits that change the guard's code on the way
- `fd35c6c` Note a stop that arrives while the agent's processes are
  stopped
- `0566cc0` Run the bridge tests' own git with the fixture's settings
  alone
- `fda1b56` Never report commits git could not list as none
- `8ab442c` Drop git's repository variables before the bridge tests run
  git
- `b82caee` Never say the guard's code was put back after the put-back
  failed
- `f9e6f03` Record the reviews of the bridge's fifth push
- `8068aa1` Say when a refusal or a stop could not unstage the job's
  files
- `ab82a2c` Say what a noted stop does in each kind of job
- and the commit that records these three here, which cannot name
  itself.

## Verified

In a cloud container (Linux, git 2.43), which cannot run Codex or agy,
with Python 3.13 and with Python 3.9.25, the version of the Mac's
`/usr/bin/python3`:

- `scripts/test-agent-bridge.py`: 73 of 73 on both. Thirty-three tests
  are new. The first twelve each failed on `main`'s bridge (19 failing
  cases between them); the three from the independent review, the two
  from CodeRabbit's review of the second push, the two from its review of
  the third, the eight for what #108's review found and the six from
  the reviews of the fifth push each failed on this branch's bridge
  before its fix. Two
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
  - `test_a_repository_left_in_the_job_is_never_staged_or_committed`: the
    stand-in Codex leaves `sub/`, a repository whose own settings name a
    clean filter that writes outside, beside its other work. The filter
    never runs, nothing is committed or staged, the job exits 1, and
    `bridge_commit` and the status name `sub/`. Before the fix the job
    exited 0 having committed the link.
  - `test_a_stop_during_the_privacy_check_commits_nothing_and_still_ends_with_done`:
    a copy of the bridge beside a check that only sleeps; the bridge is
    sent SIGTERM while the check runs. It exits 1 within seconds, with
    `summary.json` and `done` saying it was stopped before it committed,
    no commit and nothing staged. Before the fix it was killed (exit -15),
    leaving no `done` and every file staged.
  - `test_a_bytecode_cache_left_beside_the_guards_code_is_removed`: the
    stand-in agy leaves an unchecked hash-based `.pyc` of a weakened check
    in `scripts/__pycache__`, and in a second case a link there to a
    folder outside holding one. After the job, loading the check as
    guard.py does gives the real source, the cache (or the link) is gone,
    the outside folder is untouched, and the next job runs. The seed
    repository's `.gitignore` has Brickson's `__pycache__/` line for it.
  - `test_nothing_is_committed_when_the_commits_identity_holds_a_private_word`
    and `test_a_stop_after_agy_has_exited_still_puts_everything_back`
    (*CodeRabbit's review of the second push*).
  - `test_git_variables_the_bridge_inherits_never_point_its_git_elsewhere`
    and `test_a_job_gets_none_of_gits_repository_variables`
    (*CodeRabbit's review of the third push*).
  - `test_no_filter_the_git_settings_define_runs_in_the_bridges_git`: the
    shared settings define a required filter, as `clean` in one case and
    as `process` in the other, and the stand-in Codex names it for every
    file. No filter command runs, and the commit holds the files as the
    job wrote them, `.gitattributes` among them. On the bridge before the
    fix (`d9e72f1`) the command ran in both cases.
  - `test_no_filter_the_bridges_own_environment_names_runs_in_its_git`:
    `GIT_CONFIG_PARAMETERS` naming a `process` filter, and `GIT_CONFIG`
    naming an empty file while the shared settings define a filter. The
    second failed on `d9e72f1`; both fail on a copy whose own git keeps
    git's three configuration variables.
    `test_a_checkout_with_its_own_push_url_is_refused` has a new case
    with `GIT_CONFIG`, which fails on that copy too.
  - `test_the_bridge_stops_when_git_cannot_say_which_filters_are_set`: a
    stand-in git, first on the bridge's `PATH`, fails only the question
    about filters. The bridge exits 2 before Codex starts, and the filter
    the settings define never runs. On a copy that does not look at how
    that question ended, the job ran and so did the filter.
  - `test_a_filter_set_only_for_the_jobs_branch_never_runs_while_its_worktree_is_made`:
    a filter in a file the shared settings include for `codex/` branches
    alone, named for every file in `.git/info/attributes`. Neither of its
    commands runs, and the new worktree holds every file as `main` has
    it. On a copy that makes the worktree with a plain `git worktree
    add`, the `smudge` command ran.
  - `test_a_filter_set_only_for_the_jobs_branch_never_runs_when_a_worktree_is_reused`:
    the same filter, a worktree that already exists on another branch,
    and a `main` that has moved on, so `git switch -c` rewrites a file.
    It fails on `d9e72f1`, whose later git commands ran the filter on the
    new branch; the bridge's code for this did not change.
  - `test_a_status_git_cannot_read_is_never_taken_as_nothing_changed`: the
    stand-in Codex overwrites its worktree's index with bytes git cannot
    read. The job exits 1 as `finished, but its work is not committed:
    the bridge could not read its changes (...)`, with the work still in
    the files; and an agy job in a folder with such an index is refused
    before agy starts. On the bridge before the fix (`0f02da6`), and on a
    copy that again passes over a failed status, the Codex job exited 0
    as `finished`.
  - `test_a_job_that_leaves_git_unable_to_read_its_settings_still_ends_with_done`:
    an agy job that finished, one that failed and a Codex write job each
    break the settings every worktree shares. Each exits 1 with
    `summary.json` and `done`, saying the checkout could not be read; the
    agy jobs also say the job's commits could not be checked for changes
    to the guard's code, which is as it was; the failed one begins
    `failed (exit 3); `; the Codex job's work is still in its files,
    uncommitted. On `0f02da6` each ended with exit 2 and neither file; on
    a copy without the new order of the status, the failed case lost its
    `failed (exit 3)`.
  - `test_a_commit_whose_short_name_git_cannot_give_is_still_reported`: a
    stand-in git fails `rev-parse --short`. The job ends `finished`, with
    the commit named by its full hash. On `0f02da6` it ended with exit 2
    and neither file, the commit made.
  - `test_a_job_never_gets_a_bytecode_cache_folder_of_its_own`: a Codex
    and an agy job started with `PYTHONPYCACHEPREFIX` set; the stand-in
    records that it was not given it. Both cases failed on `188e140`.
  - `test_commits_that_change_the_guards_code_and_put_it_back_are_reported`:
    a stand-in agy commits a change to the guard's code and reverts it,
    or commits it on a side branch that a merge then takes nothing from.
    Each job exits 1 naming both files, with the folder clean. Both
    cases failed on `188e140` (exit 0, `finished`), and the merge case
    fails on a copy that lists the commits with a plain `git log`. On
    git 2.43, `-m` alone also reads the side branch, so no copy pins
    `--full-history` by itself; it stays because git's documented
    default leaves such a branch out.
  - `test_a_stop_while_the_agents_processes_are_cleared_commits_nothing`:
    a driver sends the bridge SIGTERM or SIGHUP as it starts to stop the
    agent's processes after a Codex write job. The job ends `stopped`,
    with nothing committed or staged. On `188e140` both cases exited 0
    with the work committed.
  - `test_commits_git_cannot_list_are_never_reported_as_none`: the
    stand-in Codex commits by itself, and a stand-in git fails `log`.
    The job exits 1 with `commits` null. Before the fix it exited 0 as
    `finished`.
  - `test_a_put_back_that_failed_is_never_followed_by_put_back`: a
    stand-in agy commits a change to the guard's code, then leaves a
    folder where `guard.py` was. The status says the bridge could not
    put the code back and that the commits change it; before the fix it
    went on to say the code was put back.
  - `test_a_refusal_or_stop_that_cannot_unstage_the_jobs_files_says_so`:
    a stand-in git fails the unstage (every `git reset` but the one that
    fills a new worktree). In one case the privacy check refuses the
    commit; in the other a stop arrives once the files are staged, sent
    by the bridge to itself just before the check. The files stay
    staged, and the status and `bridge_commit` say so and name
    `git reset`. On the sixth push's bridge both cases fail: neither
    status says anything about the files.
- The tests' own git: with `GIT_INDEX_FILE` and `GIT_PREFIX` exported,
  the commit test passes; the test file as it was at `0566cc0` ends in
  an error there.
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
  (the stopped test). Removing the caches only before the job, not
  after it, failed the bytecode-cache test (the check loaded the planted
  code). Leaving `--commits` off the check, with the commit object still
  made first, failed the identity test. Starting the privacy check
  without the filters turned off failed four cases of the filter tests:
  the check's own git ran the filter. Dropping the bridge's own
  `build/` filter when it
  stages changed no result, because `changed_files()` already leaves out
  everything under `build/`; the commit test pins that.
- `scripts/test-docs.py`, `scripts/test-hooks.py`,
  `scripts/test-privacy.py`, `scripts/test-forbidden-code.py`,
  `scripts/test-runner.py`, `scripts/test-select-xcode.py` and
  `scripts/test-site.py`, and
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
  (with the Mac's git name and address, and no prompt), and the check of
  the author and committer with the Mac's real git identity and the
  owner's real list. The tests give the identity through `GIT_AUTHOR_*`
  and `GIT_COMMITTER_*`, not git's settings; git takes both the same way
  for `commit-tree` as for `commit`.
- A real agy job through the new put-back of the guard's code.
- Whether Codex's sandbox lets a job write a `.git` folder inside a
  nested repository at all (the stand-in Codex has no sandbox). The
  bridge refuses such a repository either way.
- Removing the caches before the job, on its own: no test plants a cache
  before a job starts.
- Turning filters off with the Mac's own git: that it passes over a
  filter whose commands are empty, as git 2.43 on Linux does, and that
  its `git switch -c` and `git worktree add --no-checkout` behave as
  here. Which filters the Mac's settings define was not looked at
  (CodeRabbit asked, on #108). Check, on the Mac, in `~/code/brickson`:
  `git config --show-origin --get-regexp '^filter\.'`, which prints
  nothing and ends 1 when none is set. The bridge turns off whatever it
  prints; a filter the owner relies on (Git LFS, say) would then not
  apply to a commit the bridge makes. None is set in Brickson's own
  files.
- A real job that leaves git unreadable on the Mac: the tests break the
  shared settings and an index with stand-in agents.
- A private word in the committer's address: the identity test puts one
  in the author's address only.
- A cache planted in `.claude/hooks/__pycache__`: the bytecode-cache test
  plants one in `scripts/__pycache__` only.
- The repository-variables fix with the Mac's own git, whose list of
  those variables may differ from git 2.43's.
- Whether anything on the Mac gives agy's hook `PYTHONPYCACHEPREFIX`
  again after the bridge has dropped it (a shell start-up file that the
  hook's command reads, say). Check, on the Mac, in the shell the bridge
  is started from: `echo "${PYTHONPYCACHEPREFIX:-not set}"`. `not set`
  means the fix changes nothing there.
- A stop that arrives by itself during the clean-up after a real agent:
  the test sends it from inside the bridge at that exact point.
- The reading of a job's commits (`git log --full-history -m`) with the
  Mac's own git.
- A `git reset` that really fails after a refusal: the test makes a
  stand-in git fail it.

## Follow-ups

- A thread on the Mac runs one small Codex write job through the bridge
  once this merges, and reads its commit and `privacy-check.txt`. Owner:
  a thread on the Mac, after the merge.
- The bridge stops with a Python error, writing no `done`, when agy's
  output is not UTF-8 text (found while testing the put-back; the guard's
  code and hook are still put back). Owner: the thread that makes the
  next bridge pull request, which reads it with errors replaced, after
  adding a test of an unreadable output that still pins the put-back's
  `finally`.
- A Codex read-only job and a `codex-review` job have the gap the agy fix
  closed: they note no stops, so a SIGTERM or SIGHUP between the end of
  `run()` and `finish()` ends the bridge with no `done`. Nothing is
  staged or put back in those jobs, so only the `done` file is lost; a
  later bridge pull request notes stops there too. Owner: the same
  thread.
- A stop that lands in the instant between the bridge starting to note
  stops and the agent starting is only noted, so the agent runs its whole
  job and the job is reported as stopped after the agent ended. Nothing
  is lost; the status is not exact. The same holds for a stop that
  arrives while the summary is written, or just before the branch moves
  (*The reviews of the fifth push*). Owner: nobody, unless a status that
  is not exact ever costs something.
- The bridge's git still obeys the settings for reaching a remote when it
  fetches `main` (*Brought over from pull request #108*, the known
  limit). A later bridge pull request could give its fetch fixed
  settings. Owner: the thread that makes the next bridge pull request,
  which decides.
- The bridge refuses to commit, with a reason that does not fit, when a
  job replaces a tracked file with a folder of files; and it refuses when
  an agent that can stage has staged a rename (*The reviews of the fifth
  push*). Owner: the thread that makes the next bridge pull request.
- Whether reading the filters a moment before git runs stays a known
  limit (*The reviews of the fifth push*, the security finding). Owner:
  the owner.
- The bridge stops with a Python error and no `done` when something is
  left in the job folder under a name the bridge writes (a folder named
  `privacy-check.txt`, say), with the job's files still staged when that
  happens after staging; and when so many files changed that one
  `git add` passes the operating system's limit on a command's length,
  with nothing staged (*After the sixth push*). Nothing is committed
  either way. Owner: the thread that makes the next bridge pull request,
  which sends both through the refusal.
- A stop that arrives while a timed-out agy is being stopped is reported
  as arriving after agy ended; and a stop in the instant between the
  agent ending and the bridge starting to note stops can still cut the
  clean-up short, as it could before this pull request. The verifier
  read both in the code and reproduced neither. Owner: the thread that
  makes the next bridge pull request, which decides.
