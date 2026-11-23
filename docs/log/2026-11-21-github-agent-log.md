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
  shows "Job cancellation request ... received" and *First trouble
  renewing* is none: the hold was renewed every minute up to the
  request, and goes on being renewed after it. This is what an ordinary
  cancel wrote on GitHub's Mac (below): the request came four times in
  three seconds, and "Successfully renew job" 14 seconds before it and
  48 seconds after. For a job nobody cancelled, nothing in this
  repository can stop that: the next step is a report to GitHub with
  the run's and the job's ids.
- **The agent lost its session with GitHub** when the lines end with
  "Runner session is invalid", "Non-retriable exception" and "Shutting
  down JobDispatcher ... cancel any running job", after requests that
  "timed out after 100 seconds". The job's hold may still be renewed,
  and there is no cancellation request: the agent cancels the job
  itself as it shuts down. This is what the cancel GitHub made by
  itself during this pull request wrote (below).
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
- **The upload waits for it, on a Mac that may be very busy, so it
  starts almost nothing.** GitHub gives a cancelled job's remaining
  steps five minutes ("cancellation timeout 5 minutes") and then stops
  the job, losing whatever has not been uploaded, the job's own log
  included. On a busy Mac starting a program can take seconds: the
  first version of this script started about forty, and in this pull
  request's deliberate cancel (below) it kept the upload from finishing
  in two jobs of five. Now, where the agent's folder is where GitHub
  keeps it (`/Users/runner/actions-runner/cached`, found there in every
  job that kept its results), it starts two programs: `sysctl` for the
  load, and one `awk` that reads every log, removes secrets and writes
  the file; the rest is the shell's own. A job cancelled before its
  results folder existed also starts `mkdir`. `ps` runs only when the folder is elsewhere, reads
  program names only, and is stopped after 30 seconds (one `ps` took
  about 160 seconds on these machines: docs/DECISIONS.md, "Tests",
  2026-11-04). A test fails if it starts any other program.
- When no folder is found it says where it looked, what those folders
  hold, and which running programs have "runner" in their own name, so
  the next change can point it at the right place.
- Only the agent's own timestamped lines are matched. The Worker log
  also holds the job's whole description, the pull request's text
  included, and the agent's note "Force kill process on cancellation"
  for every program a step starts; the first version copied both.

## What the deliberate cancel showed

The pull request's first run (44914822022, commit `c8d5c17`) was
cancelled by its second push, at 14:38 UTC on 2026-11-21, with five
iPad and iPhone UI jobs building and two waiting for a machine. The
step ran in all five.

- **The agent's folder** is `/Users/runner/actions-runner/cached` on
  GitHub's Mac image (macos27, runner 2.338.2), in each of the three
  jobs that kept their results. It was found without `ps`.
- **An ordinary cancel** reads as described above: "Job cancellation
  request ... received, cancellation timeout 5 minutes." four times,
  "Send job cancellation message to worker", renewals before and after,
  no trouble renewing. In the Worker log: "Cancellation/Shutdown message
  received.", "Cancel current running step.", then "Caught cancellation
  exception from step: System.OperationCanceledException: The operation
  was canceled." (the line the job's own log shows), 28 seconds later.
- **It cost too much.** The Macs' load was 320 to 445 on three
  processors as the steps were stopped. The first version's step took
  62, 113, 124 and 221 seconds in four jobs, and in the fifth (iPad,
  part 3) it had not finished when GitHub stopped the job 4 minutes 56
  seconds after the cancel. That job and the 221-second one uploaded no
  results and kept no log at all. In the fastest job, 28 seconds passed
  between the step's start and the script's first line, and the rest
  of its forty programs took about 30 seconds more. Hence the rewrite
  above.

## A cancel GitHub made by itself, captured

During the run of the third commit (44916610210, `d8d2975`), "UI tests
on iPad, part 1 of 3" was cancelled with no push and nobody cancelling,
ten minutes after its simulator began to start, like the thirteen
before it. Its record (in `ui-test-results-ipad-part1`):

- Load 812 on three processors. The simulator's own record began only
  at 15:09:47, ten minutes after it was started, as in the thirteen.
- The job's hold was renewed at 14:59, 15:00, 15:01 and 15:02. At
  15:06:38 a renewal "timed out after 100 seconds", and at 15:06:46 so
  did the agent's request for its next message from GitHub. At 15:09:21
  both "timed out after 00:01:40" again and were retried; at 15:09:29
  the hold was renewed, but the request for messages "failed. HTTP
  Status: BadRequest", and at 15:09:30: "Runner session is invalid",
  "Non-retriable exception", "Shutting down JobDispatcher. Make sure
  all WorkerDispatcher has finished.", "Ensure WorkerDispatcher for job
  ... run to finish, cancel any running job." and "Send job
  cancellation message to worker".
- *Cancellation request*: none. *First trouble renewing*: none (the
  timeouts are not the renewal's own error lines).

So it is neither a cancel GitHub's service asked for nor a lost hold on
the job: the starved agent lost its session with GitHub's service, and
cancelled the job itself as it shut down. The cause is the Mac's load
in the first ten minutes, which is ours to cut. The rewritten script's
step took 19 seconds there and the results were uploaded.

## The rewrite under a cancel

A separate run of the third commit, started by hand on the branch
(44916772349, so the pull request's own run went on), was cancelled on
purpose with three UI jobs in their tests, at loads of 135 to 554. The
step took 5, 4 and 65 seconds, found the agent without `ps` and copied
no pull request text, and all three jobs uploaded their results.

## Commits

- `c8d5c17`: the script, its tests (`scripts/test-runner.py`,
  `GitHubAgentLogTests`) and the workflow step, with Codex's local
  review answered.
- `064d303`: this record, `docs/HANDOFF.md` (the cancelled-jobs
  bullet, and the state line, which still listed pull requests that
  have merged as open) and `README.md`, *Tests*.
- `d8d2975`: the script rewritten to start two programs and to match
  only the agent's timestamped lines, its tests, and what the
  deliberate cancel showed.
- `f3378f7`: a base64 token with no dots is removed as well (Gitar's
  review). `c915a2e`: the script, this record and its test say that a
  job cancelled before its results folder existed also starts `mkdir`
  (the report-only verifier). The next commit: the cancel GitHub made by
  itself, and the rewrite under a cancel, in these records.

## Verified

- On the owner's Mac (macOS, `/bin/bash` 3.2, the shell GitHub's Mac
  jobs run it with): `python3 scripts/test-runner.py`, 136 tests, OK,
  12 of them new; `test-docs`, `test-hooks`, `test-privacy`,
  `test-forbidden-code`, `test-agent-bridge`, `test-site` and
  `test-select-xcode`, all OK. `scripts/test.sh unit` with Xcode 27.2 on
  an iPad Pro 13-inch simulator, iOS 27.2: 1093 tests, 1080 passed, none
  failed, 1 skipped, 12 expected failures (this pull request changes no
  app code).
- Each new test was seen to fail when its rule was broken on purpose:
  matching the worker's lines in one case only, ending with status 3,
  no `ps` search, `always()` for `cancelled()` in one job, the script
  not executable, `ps` with no time limit, no removal of secrets, `ps`
  before the known folders, reading programs' arguments, matching lines
  that are not the agent's own, and starting one more program. The
  awk's UTC time was checked against `date -u` on leap days and year
  ends from 1970 to 2100.
- On GitHub's Macs: the first version (*What the deliberate cancel
  showed*), and the rewrite under a deliberate cancel and under a
  cancel GitHub made by itself (*The rewrite under a cancel*, *A cancel
  GitHub made by itself, captured*).
- The report-only verifier (`.claude/agents/verifier.md`) on the owner's
  Mac: every `scripts/test-*.py` suite passed on `f3378f7`, the privacy
  check passed with the private list read, and `shellcheck` was clean.
- `codex review --base origin/main` on the owner's Mac before the pull
  request opened: four findings. Fixed: `ps` could hold up the results
  upload (known folders first, time limits); raw lines could carry a
  secret into a public download (secrets removed, no arguments). Done:
  this record. Declined: that a runner shutdown skips the step, which
  no step can avoid (above), and which the thirteen jobs were not.

## Not verified

- Whether every cancel GitHub makes by itself is this one: one has been
  captured.
- `f3378f7` and the commits after it on GitHub's CI.
- On Linux: the script's Linux fallbacks (`/proc/loadavg`, `getconf`)
  and GNU or mawk `awk` have not run. The Mac jobs are the only ones
  that run the script.

## Follow-ups

- **Cut the Mac's load in a job's first ten minutes,** so GitHub's agent
  stays in touch: the fixes in the 2026-11-19 record's *Follow-ups*, in
  its order *(the owner chooses whether a thread takes it up)*.
- **The next job GitHub cancels by itself:** download its results, read
  `github-agent-log.txt` as above, and record in docs/HANDOFF.md,
  *Known gaps*, whether it was the same. If GitHub's service asked for
  that cancel, report it to GitHub with the run's and the job's ids. If
  that job kept no results, check how long the capture step took in its
  log: a step that still costs the upload goes after "Keep the test
  results", printing to the job's log only *(the next thread on CI,
  with the owner)*.
