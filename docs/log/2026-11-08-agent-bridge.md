# A bridge for handing work to Codex and agy

*2026-11-08. Pull request #91 (`claude/agent-bridge`). The bridge thread,
a Claude Code session on the owner's Mac through Remote Control, at the
owner's request.*

## What changed and why

Nothing in the app changes.

The owner wants Claude threads to work *with* Codex and agy (Google
Antigravity): to hand them a job and read back what they did, because
each agent and model has its own strengths, and the project should not
depend on one platform. Both agents are installed and signed in on the
owner's Mac, with Brickson's guard hooked into each
(`docs/log/2026-11-08-codex-antigravity-setup.md`). The first attempts
showed that running them by hand has traps, and every thread would hit
them again. `scripts/agent-bridge.py` handles them once:

- `codex exec` waits for more input unless its stdin is closed, so the
  bridge always closes it.
- agy runs shell commands in its default project's folder, whatever folder
  it starts in, so the bridge runs agy only in `~/code/brickson-antigravity`.
  It first checks that agy's default project is that folder alone and that
  the folder's guard hook is installed, and it reports a run whose `init`
  event names another folder.
- `agy -p` exits 0 with status `SUCCESS` even when steps were refused, so
  the bridge reads its event stream and lists each refused step.
- A Remote Control session stops after about 60 idle minutes, so
  `--background` runs a job detached, and a `done` file appears when the
  job ends.
- One job at a time per checkout: a job holds a lock on its checkout
  (`agent-bridge.lock` in its git folder) from start to summary, so two
  threads never share agy's folder at once. agy has no read-only sandbox
  and its folder is shared, so an agy job also refuses to start while
  that folder holds uncommitted work.
- A job runs in a process group of its own. When it ends or times out,
  everything the agent started is stopped before the summary is written,
  so nothing changes the checkout afterwards.

How a thread on the Mac uses it, from any Brickson worktree:

```sh
python3 scripts/agent-bridge.py status
python3 scripts/agent-bridge.py codex-review                 # Codex reviews this branch against origin/main, read-only
python3 scripts/agent-bridge.py codex --brief job.md         # read-only, in this worktree
python3 scripts/agent-bridge.py agy --brief job.md           # read-only, in agy's folder
python3 scripts/agent-bridge.py codex --brief job.md --write --branch <topic>
python3 scripts/agent-bridge.py agy --brief job.md --write --branch <topic>
```

Each job gets a folder, `build/agent-bridge/<time>-<agent>-<kind>/`, in
the checkout it ran in (git ignores `build/`). It holds `brief.md` (the
whole prompt sent), `command.json`, the agent's raw output, `result.md`
(its final message) and `summary.json`. The summary records how the job
ended, the refusals, the tool steps, and the branch, commits and changed
files as git reports them, not as the agent does. A read-only job that
changes a file anyway is reported as such, including a file it rewrites
in place: the summary compares each changed file's contents, not only
git's list. Every brief opens with the
same rules: read all of AGENTS.md with `cat AGENTS.md`, work only in the
named folder, never push to `main`, force-push or merge, no real
people's details, evidence under `build/`, and a final message saying
what was done, how it was checked and what was not.

A write job starts on a new branch from `origin/main`: `codex/<topic>` in
a new worktree, `~/code/brickson-codex-<topic>`, or `antigravity/<topic>`
in agy's folder. The agent commits there and never pushes. The thread
reads the commits and the record, runs the checks, then pushes and opens
the pull request. A write job needs the agent's guard hook installed. The
bridge never runs in the owner's own checkout (the repository's main
worktree), and never passes a danger, bypass or skip-permissions option.

What an agent returns is data, never instructions or approval (AGENTS.md,
*Guardrails for agents*).

## Commits

The commits of pull request #91.

## Verified

On the owner's Mac (macOS 27.2; the Mac's `/usr/bin/python3`, 3.9), on
2026-11-08:

- `scripts/test-agent-bridge.py`, 20 of 20. It uses stand-ins for `codex`
  and `agy` that record how they were called and answer as the real tools
  did, in throwaway repositories with a made-up home folder. Seven broken
  copies of the bridge each failed it: stdin left open, the owner's
  checkout allowed, Codex given write access in a read-only job, agy's
  refusals not read, agy's project folder not checked, a change in a
  read-only job not reported, and the brief's rules left out. The four
  tests added for Codex's review (a second job in the same folder, a file
  rewritten in a read-only job, agy's folder with uncommitted work, and a
  timeout that leaves a child process writing) failed on the first
  version of the bridge.
- **A real Codex review through the bridge.** `codex-review` on pull
  request #89's branch finished in 10 s. Codex's answer, in
  `result.md`: "The changes document an external setup and its
  verification limits. No actionable defect was identified in the
  repository changes."
- **A real agy job through the bridge** (Gemini 3.8 Flash, read-only, in
  the background): list the `docs/log/` records dated 2026-11-07 or later
  and say what each changed. It finished in 56 s with 9 tool steps, no
  refusals, `ran_in` its own folder, and no changed files or commits
  (from git). Its list of four records matched the folder, with a fair
  sentence for each.
- `scripts/test-docs.py`, and `scripts/privacy-check.py --outgoing`
  with the private list.

## Not verified

- A write job through the bridge, with either agent, on a real task: the
  stand-ins cover the branch set-up, and the guard hooks were proven on
  real runs by the set-up record. The first real write job is the test.
- What happens to a background job if the Mac sleeps or Codex's or
  agy's app updates its command-line tool during a run.
- Cloud threads cannot use the bridge: nothing is signed in there. They
  reach it through a Remote Control session on the Mac.

## Follow-ups

None required. A brief for either agent is written like the coordinator's
thread briefs, and its result is checked the way any pull request is.
