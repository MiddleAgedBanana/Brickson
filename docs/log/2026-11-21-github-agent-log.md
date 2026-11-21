# Keep what GitHub's agent logged when a Mac job is cancelled

*2026-11-21. Pull request #131 (`claude/github-agent-log`). Claude, in a
project thread, on the owner's Mac.*

## What changed and why

Nothing changes for a person using Brickson. For the people working on
it: from 2026-11-13 to 2026-11-19, thirteen CI jobs (nine "Unit tests",
four iPad UI jobs) were cancelled with only "The operation was
canceled." in their log, and on 2026-11-21 "Unit tests" was cancelled
the same way twice in a row on #130 and once on `main`'s latest run
(kind K in
[`2026-11-19-ui-tests-wait-for-a-settled-mac.md`](2026-11-19-ui-tests-wait-for-a-settled-mac.md);
docs/HANDOFF.md, *Known gaps*). GitHub's agent on the machine (the
runner program that takes the job, runs its steps and renews its hold
on the job every minute) keeps its own log in its `_diag` folder, and
that log says why a job was cancelled. Until now nothing kept it.

Each of the seven Mac jobs in `.github/workflows/tests.yml` now has a
step, "Keep what GitHub's agent logged about the cancelling", that runs
only when the job was cancelled (`if: cancelled()`), just before "Keep
the test results". It runs `scripts/github-agent-log.sh build/TestResults
|| true`, which writes `github-agent-log.txt` beside the result bundles,
so it is in the job's download (`unit-test-results` or
`ui-test-results-<family>-part<n>`), and prints it in the job's log.

### How to read github-agent-log.txt

At the top: the job, run and attempt, the time, the Mac's load and
processors, and the agent's folder. Then, for each of the agent's
`Runner_*.log`, three summary lines, then the lines they come from and
the log's last 40 lines. The wording below is that of GitHub's runner
(`src/Runner.Listener/JobDispatcher.cs` in actions/runner, read
2026-11-21; GitHub's machines ran runner 2.338.2).

- **GitHub's service cancelled the job** when *Cancellation request*
  shows "Job cancellation request ... received" and *Last successful
  renewal* ("Successfully renew job ...") is within about a minute
  before it, with no trouble renewing after that. Nothing in this
  repository can stop that: the next step is a report to GitHub with the
  run's and the job's ids.
- **The agent lost its hold on the job** when *First trouble renewing*
  ("Catch exception during renew", "Retrying lock renewal", "Lock
  renewal has run out of retry", "job is no longer valid") comes before
  the cancel and *Cancellation request* is none. The agent then cancels
  the steps itself and reports the job as abandoned. That is the lead
  of 2026-11-19 (a Mac too busy for the agent), and the fixes in that
  record's *Follow-ups* apply.
- The line that names how the job ended ("finish job request for job
  ... with result: Canceled" or "Abandoned") is written after the job's
  last step, so it is never in the file.
- If GitHub takes the machine away ("Runner will be shutdown",
  "Service requests the hosted runner to shutdown", "deprovisioned"),
  the runner skips every step that is left, so such a job keeps no
  file and no results. The thirteen jobs all uploaded their results
  after the cancel, so none was this.

### Why the script works the way it does

- **It never changes how a job ended.** It only reads, writes one file,
  and always ends 0; the workflow adds `|| true` as well.
- **The results are a public download.** It copies only the lines named
  above and the last 40 lines, never a whole log; it replaces anything
  shaped like a token, credential or signature with `[removed]`; and it
  never reads a program's arguments, because GitHub's agent can be
  started with its credentials in them. The repository variable
  `ACTIONS_RUNNER_DEBUG` is not used: it would put whole agent logs for
  every job, the privacy job's included, into public downloads.
- **The upload waits for it, on a Mac that may be very busy.** One `ps`
  took about 160 seconds on these machines (docs/DECISIONS.md, "Tests",
  2026-11-04), and GitHub gives a cancelled job's remaining steps about
  five minutes ("cancellation timeout 5 minutes") before it stops them.
  So the script tries the agent's known folders
  (`/Users/runner/actions-runner/cached`, then
  `/Users/runner/actions-runner`) before `ps`, gives `ps` 30 seconds and
  reads program names only, and stops after 90 seconds keeping what it
  wrote. In the thirteen jobs the upload after the cancel took up to 49
  seconds.
- When no folder is found it says where it looked, what those folders
  hold, and which running programs have "runner" in their own name, so
  the next change can point it at the right place.

## Commits

- `c8d5c17`: the script, its tests (`scripts/test-runner.py`,
  `GitHubAgentLogTests`) and the workflow step, with Codex's local
  review answered.
- The next commit: this record, `docs/HANDOFF.md` (the cancelled-jobs
  bullet, and the state line, which still listed pull requests that
  have merged as open) and `README.md`, *Tests*.

## Verified

- On the owner's Mac (macOS, `/bin/bash` 3.2, the shell GitHub's Mac
  jobs run it with): `python3 scripts/test-runner.py`, 136 tests, OK,
  12 of them new; `test-docs`, `test-hooks`, `test-privacy`,
  `test-forbidden-code`, `test-agent-bridge`, `test-site` and
  `test-select-xcode`, all OK.
- Each new test was seen to fail when its rule was broken on purpose:
  matching the worker's lines in one case only, ending with status 3,
  no `ps` search, copying the whole log, `always()` for `cancelled()` in
  one job, the script not executable, `ps` with no time limit, no
  removal of secrets, no overall time limit, `ps` before the known
  folders, and reading programs' arguments.
- `codex review --base origin/main` on the owner's Mac before the pull
  request opened: four findings. Fixed: `ps` could hold up the results
  upload (known folders first, time limits); raw lines could carry a
  secret into a public download (secrets removed, no arguments). Done:
  this record. Declined: that a runner shutdown skips the step, which
  no step can avoid (above), and which the thirteen jobs were not.

## Not verified

- On GitHub's machines: where the agent keeps its log, and what an
  ordinary cancel (a newer push cancelling an older run) writes. This
  pull request's own first run is cancelled on purpose by its second
  push to see it; the result goes in the next commit.
- A cancel GitHub makes by itself: none has been captured yet.
- On Linux: the script's Linux fallbacks (`/proc/loadavg`, `getconf`)
  and GNU `sed` have not run. The Mac jobs are the only ones that run
  the script.

## Follow-ups

- **The next job GitHub cancels by itself:** download its results, read
  `github-agent-log.txt` as above, and record which case it was in
  docs/HANDOFF.md, *Known gaps*. If GitHub's service cancelled it,
  report it to GitHub with the run's and the job's ids; if the agent
  lost its hold, take up the fixes in
  [`2026-11-19-ui-tests-wait-for-a-settled-mac.md`](2026-11-19-ui-tests-wait-for-a-settled-mac.md),
  *Follow-ups* *(the next thread on CI)*.
