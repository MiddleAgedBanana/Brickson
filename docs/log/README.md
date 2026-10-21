# Change log, one file per pull request

Every pull request adds **one new file** here and changes no other file
in this folder. Pull requests worked on in parallel then never edit the
same lines, so none of them conflicts with another over the record.
The current state stays on the front page, [`docs/HANDOFF.md`](../HANDOFF.md),
which each pull request edits **in place** where its change makes a line
untrue (AGENTS.md, *Workflow rules*, "Document every change"). History
before 2026-10-21 is in [`docs/HANDOFF-LOG.md`](../HANDOFF-LOG.md).

## Name

`YYYY-MM-DD-<topic>.md`, dated the day the pull request opens, with the
topic taken from the branch or the pull request's title, for example
`2026-10-21-toolchain.md`. Files sort by date, so the newest is last.

## What goes in it

Copy this and fill it in. Write it for an agent arriving with fresh eyes,
and keep the words plain: the owner reads these too.

```markdown
# <What changed, in a few words>

*<Date>. Pull request #<n> (`<branch>`). <Owner, agent or thread>.*

## What changed and why

<What a person using Brickson, or someone working on it, will notice,
and the reason. Name the decision in docs/DECISIONS.md it follows, if any.>

## Commits

<Hashes with one line each, or a range.>

## Verified

<What ran and where: GitHub CI, or a Mac with the current Xcode (say
which version it was), the simulator or device and its iOS version,
orientation, text size, appearance, and which keyboard showed. For a
new test, the change that would make it fail.>

## Not verified

<Everything a reader might assume was checked and wasn't. Device checks
go in docs/HANDOFF.md, "Checks that need a real device", too.>

## Follow-ups

<Work this leaves for later, each with who owns it. Anything that changes
what to do next is also edited into docs/HANDOFF.md, "Next steps, in order".>
```

Keep an entry once its pull request merges: correct a mistake in it, but
record later changes in a new file. Snapshots of rewritten documents go
in [`docs/archive/`](../archive/README.md), not here.
