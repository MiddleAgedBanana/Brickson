# The docs check reads every title a citation names

*2026-10-23. The pull request from `claude/project-thread-208903`, based
on `main` at `e556042`. The "Docs check gaps" thread, a cloud session
that cannot build Swift: Python and documents only, no Swift code or
`project.yml` changed.*

## What changed and why

`scripts/test-docs.py` fails when a document cites a section that does
not exist (AGENTS.md, *Guardrails for agents*). On 2026-10-23 the iPhone
Duo thread found two gaps in it, and planted bad citations of both kinds
passed:

1. **A quoted title starting with a small letter was skipped.** The
   check treated any quoted text after a file name that did not start
   with a capital as a quoted phrase, not a title, so every citation of
   docs/DECISIONS.md, "iPhone Duo" (ten on `main`) went unchecked.
2. **Only the first title of a citation was read.** In
   docs/DECISIONS.md, "iPhone Duo", *The fold*, the second title was never
   looked up, so a wrong subsection passed. The same was true of lists
   such as "Settings on Home" and "Get Attention and Stop on Home".

Now:

- **Quoted words after a file name and a comma (or an arrow) are a title,
  whatever letter they start with.** Without a comma, only a capital
  marks a title, as before: in code, a comment that ends in a file name
  runs into the string on the next line (`// see docs/DESIGN.md` then
  `"bell.slash.fill"`), and that string is not a title. Text that starts
  with punctuation or a space, a file name, or an owner note such as
  *(R0, a new thread)* is never a title.
- **Three citations quote a file's words rather than name a section.**
  They are listed in a new `QUOTATIONS` set, and each must still appear
  word for word in the cited file. Before, every quotation starting with a
  small letter passed unread; now there are three named ones, and they
  fail if the words change.
- **Every title of a citation is read.** A title after a comma or an
  arrow must be part of a title before it (a subheading, or a bold lead-in
  under it) or a section beside one (under the same parent). A title after
  "and" is checked the way the title before it was, so ASO.md,
  *Screenshots* and *Subtitle* names two sections of ASO.md, and
  "iPhone Duo", *The fold* and *The hinge* would need both in or beside
  iPhone Duo. When a title appears in several places, only the places
  where it fits count for the titles after it, so *Open* (an open question
  in many sections) cannot carry a wrong title through. A title followed
  by a file name in parentheses, *Title* (docs/LESSONS.md), belongs to that
  file and ends the citation. `EXTERNAL` applies to every title; its
  second entry, PORTING.md's *Known limits and issues*, was never read
  before and now is.
- **A lead-in such as "Open: fewer than three everyday categories." is
  cited by its label or by its words** (*Open*, *Fewer than three everyday
  categories*), as HomeShapeTests and the slot-plan citations do.
- **Code inside a quoted title is read**: docs/HANDOFF-LOG.md's
  "`main` ruleset" used to reach the check as "ruleset". A code span is
  kept for this when it holds no quote mark, asterisk or file name, so
  code examples are still never read as citations, and an italic code
  span such as *`Speak`* in an instruction file is still not a bare title.
- **Headings and lead-ins are placed by the same line breaks**, so a
  page separator or line separator pasted into a file cannot move a
  lead-in under the wrong heading.
- **An `EXTERNAL` or `QUOTATIONS` entry nothing cites fails**, so the
  exceptions cannot outlive the citations they were for.
- The check keeps each file's outline once instead of rebuilding it for
  every citation: the script ran in about 2 seconds on Linux instead of
  about 7.

On `main`'s documents the new checker reads 556 titles where the old one
read 501: 13 quoted titles that start with a small letter and 42 titles
after a cited one. It reports one real mistake there, fixed here:
docs/DECISIONS.md, "Get Attention", *Open* (cited in docs/HANDOFF.md and
`2026-10-23-get-attention-on-home.md`) named no section, because that
open question was marked `*Open:*` in italics. It is now `**Open:**`, as
every other open question in docs/DECISIONS.md is; the words are
unchanged.

docs/work/personal-voice.md is also reworded, though it was not wrong: it
named *Closures a framework may call off the main thread* after a
docs/DECISIONS.md citation, with docs/LESSONS.md in parentheses after it.
An early version of this change misread that title as a DECISIONS one;
the final check ends the citation there instead, and the line now cites
docs/LESSONS.md first, so the title is checked.

AGENTS.md, *Guardrails for agents*, "Cross-references", says how titles
after the first and quotations are read. No entry in docs/DECISIONS.md:
nothing about the app changed.

## Commits

See this branch's pull request.

## Verified

Linux cloud session, Python 3.13:

- `python3 scripts/test-docs.py`: 45 tests passed (34 before). Each
  behaviour above was checked by undoing it in a copy of the script and
  running the tests: every undo but one failed at least one test. The
  exception is the unused-entry check, which fails only when an entry is
  unused; adding a stale `EXTERNAL` entry failed it.
- `python3 scripts/test-hooks.py`: 124 tests passed (unchanged).
- Planted bad citations, in a copy of this branch's documents, run with
  `main`'s checker and with the new one. `main`'s checker passed all five;
  the new one failed each: renaming the heading iPhone Duo (13 citations
  reported), renaming The fold (5), "iPhone Duo", *Where the grid still
  scrolls* in docs/ROADMAP.md (a real subsection under another section),
  a wrong second title in an "and" list in docs/HANDOFF.md, and
  "Get Attention", *Open*, *What a held activation meets* in
  docs/HANDOFF.md (a real section reached through an ambiguous title).
- Every heading list the old and new checker read is identical on every
  Markdown file of this branch, and each file's old set of titles is
  contained in the new one (31 extra short forms, all from "Label: words"
  lead-ins).
- Before the first push, two reviewers working apart from this thread
  tried to break the change. They found one real bug (an ambiguous title
  could carry a wrong one through), three ways ordinary text would have
  failed (a string after a comment in code, owner notes and titles of
  another file after "and", italic code in instruction files) and wrong
  counts in a draft of this record. All are fixed above, each with a test.

## Not verified

- GitHub CI on this branch, which runs both scripts in the Unit tests job
  (`scripts/test.sh`), was not yet seen when this was written.
- A title written before its file name, *Title* (docs/LESSONS.md), is
  still not read, and neither is a lowercase quoted title with no comma
  after the file name (docs/DECISIONS.md "iPhone Duo").

## Follow-ups

None required. A title written before its file name could be read in a
later pull request if that form becomes common.
