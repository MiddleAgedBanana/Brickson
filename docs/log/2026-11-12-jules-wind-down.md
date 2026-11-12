# Jules taken out of the documents

*2026-11-12. Pull request #95 (`claude/project-thread-vdyi4c`). A Claude
Code cloud thread, from the owner's message of 2026-11-12 asking for the
documents to be updated now that Google is shutting Jules down.*

## What changed and why

Jules, Google's cloud coding agent, is going away. Google's changelog
(https://jules.google/docs/changelog/, the entry "Jules Turndown",
October 29, 2026, read on 2026-11-12) says sessions could be finished
until November 11, 2026, that Jules is read-only after that until the end
of the year, and that it winds down on December 31, 2026. Its lessons go
into Google Antigravity, which Brickson already uses on the owner's Mac
(`docs/log/2026-11-08-codex-antigravity-setup.md`).

So the documents that guide current work no longer name Jules as one of
Brickson's agents. Nothing in the app changes.

- **AGENTS.md.** The introduction named Codex and Jules as the agents
  that read the file directly; it now names Codex and Antigravity, which
  reads it as a rule file (its first 24,000 bytes, with a pointer rule on
  the Mac that has it read the rest: the setup record above). *Build and
  test* no longer lists Jules among the cloud agents with no route to a
  Mac. *Guardrails for agents* said Codex, Jules and the owner are held
  to the guard's rules by review; it now says that on the owner's Mac
  git-ignored hooks hold Codex and Antigravity to what the guard refuses,
  and that elsewhere Codex and the owner are held by review, as
  docs/HANDOFF.md already said since 2026-11-08.
- **docs/SDLC.md.** The agents it names are Claude Code, Codex and
  Antigravity. The cloud agents with no Xcode are Codex cloud and a
  Claude Code session with no route to the owner's Mac (AGENTS.md says
  such a session that reaches the Mac builds there). Claude Code hooks
  bind Codex and Antigravity only on the owner's Mac.
- **docs/DECISIONS.md**, "AGENTS.md puts first what Codex reads". The
  open question of which other readers cut AGENTS.md at 32 KiB no longer
  names Jules.
- **`.claude/hooks/guard.py`.** Only its opening description changes, in
  the same words as AGENTS.md. No rule, test or behaviour changes.
- **docs/HANDOFF.md.** The agents bullet under *Repository, CI and
  website* says Jules is gone and that no agent took over a role of its,
  and no longer says "once #91 merges": #91 merged on 2026-11-08.

No role of Jules's needed a successor. It was named as a reader of
AGENTS.md, as a cloud agent that cannot build, as an agent the guard does
not cover, and in an open question about how much of AGENTS.md it reads;
each of those sentences simply loses it. Dated records in `docs/log/` and
`docs/recon/` keep their mentions, as history.

AGENTS.md grows from 83,050 to 83,195 bytes. Six of those bytes are in
the sections Codex must read, which now end at byte 32,119 of the 32,768
`scripts/test-docs.py` allows; the rest are in *Guardrails for agents*,
after them. The cut at 24,000 bytes where Antigravity stops reading rule
files still falls inside *Code Review Rules*, as before; the trim that
fixes it is already the next agents' item in docs/HANDOFF.md,
*Repository, CI and website*, and is not part of this change.

## Commits

One commit for the edits and this record; see the pull request's commit
list.

## Verified

In a Claude Code cloud session on Linux, with Python 3.13 (no Xcode; this
change has no Swift):

- `python3 scripts/test-docs.py`, `python3 scripts/test-hooks.py` and
  `python3 scripts/test-privacy.py` passed (counts in the pull request).
- `python3 scripts/privacy-check.py --outgoing --no-list` found nothing.
  This cloud session has no private list, so only the built-in patterns
  were checked; CI's "Privacy check" job checks with the list.
- `git grep -i jules` finds Jules only in `docs/log/`, `docs/recon/` and
  docs/HANDOFF.md's line saying it is gone.
- Google's shutdown dates were read from Google's own changelog, above.

## Not verified

- Nothing was built or run: the change is to documents and one Python
  docstring. CI on the pull request is the build.
- Whether Codex's review on GitHub or Codex cloud cut AGENTS.md at 32 KiB
  is still not documented (docs/DECISIONS.md, "AGENTS.md puts first what
  Codex reads").

## Follow-ups

- Pull request #94, opened by Jules on 2026-11-12 (UTC), is reviewed like
  any other pull request; this change does not touch it.
- After December 31, 2026, the owner may remove the Jules GitHub app's
  access to the repository in GitHub's settings, since nothing will use
  it.
- Trimming AGENTS.md so the sections Codex must read fit in Antigravity's
  24,000 bytes stays the next agents' item in docs/HANDOFF.md.
