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
   docs/DECISIONS.md, "iPhone Duo" (ten of them) went unchecked.
2. **Only the first title of a citation was read.** In
   docs/DECISIONS.md, "iPhone Duo", *The fold*, the second title was never
   looked up, so a wrong subsection passed. The same was true of lists
   such as "Settings on Home" and "Get Attention and Stop on Home".

Now:

- **Quoted words after a file name are a title, whatever letter they
  start with.** Text that starts with punctuation or a space is still not
  a title: that is what the pattern finds between quote marks around file
  names in code, such as `("docs/HANDOFF.md", "README.md")`. Three
  citations quote a file's words rather than name a section; they are
  listed in a new `QUOTATIONS` set, and each must still appear word for
  word in the cited file. Before, unchecked quotations were an open
  exception; now there are three named ones that still fail if the words
  change.
- **Every title of a citation is read.** A title after a comma or an
  arrow must be a part of a title before it (a subheading, or a bold
  lead-in under it) or a section beside one (under the same parent). A
  title after "and" is checked the way the title before it was, so
  ASO.md, *Screenshots* and *Subtitle* names two sections of ASO.md, and
  "iPhone Duo", *The fold* and *The hinge* would need both under iPhone
  Duo. `EXTERNAL` applies to every title; its second entry, PORTING.md's
  *Known limits and issues*, was never read before and now is.
- **A lead-in such as "Open: fewer than three everyday categories." is
  cited by its label or by its words** (*Open*, *Fewer than three everyday
  categories*), as HomeShapeTests and the slot-plan citations do.
- **Code inside a quoted title is read**: docs/HANDOFF-LOG.md's
  "`main` ruleset" used to reach the check as "ruleset". A code span is
  kept for this when it holds no quote mark, asterisk or file name, so
  code examples are still never read as citations.
- **An `EXTERNAL` or `QUOTATIONS` entry nothing cites fails**, so the
  exceptions cannot outlive the citations they were for.
- The check keeps each file's outline once instead of rebuilding it for
  every citation: the script ran in about 3 seconds on Linux instead of
  about 7.

On `main` it now reads 557 titles instead of 502: 13 quoted titles that
start with a small letter and 42 titles after a cited one. It caught two
real citations, fixed here:

- docs/DECISIONS.md, "Get Attention", *Open* (in docs/HANDOFF.md and
  `2026-10-23-get-attention-on-home.md`): the open question there was
  marked `*Open:*` in italics, so no section was named Open. It is now
  `**Open:**`, as every other open question in docs/DECISIONS.md is. The
  words are unchanged.
- docs/work/personal-voice.md named a docs/LESSONS.md section after a
  docs/DECISIONS.md citation, with the file in parentheses after it. It
  now cites docs/LESSONS.md, *Closures a framework may call off the main
  thread* in the usual order, so that citation is checked too.

AGENTS.md, *Guardrails for agents*, "Cross-references", says how titles
after the first and quotations are read. No entry in docs/DECISIONS.md:
nothing about the app changed.

## Commits

See this branch's pull request.

## Verified

Linux cloud session, Python 3.13:

- `python3 scripts/test-docs.py`: 42 tests passed (34 before). Of the
  eight new ones, seven failed against `main`'s checker before the fix;
  the eighth, quote marks around file names in code, passed before and
  guards against reading those as titles now. Restoring the capital-letter
  skip fails `test_a_quoted_title_may_start_with_a_small_letter`; reading
  only the first title fails `test_a_title_after_a_cited_title_must_be_part_of_it`.
- `python3 scripts/test-hooks.py`: 124 tests passed (unchanged).
- Planted bad citations, in a copy of this branch's documents, run with
  `main`'s checker and with the new one: renaming the heading iPhone Duo
  (old check passes, new check reports all ten citations); renaming
  The fold (old passes, new reports three); citing a real subsection under
  the wrong section, "iPhone Duo", *Where the grid still scrolls* (old
  passes, new reports it); a wrong second title in an "and" list in
  docs/HANDOFF.md (old passes, new reports it).
- Every heading list the old and new checker read is identical on every
  Markdown file, and each file's old set of titles is contained in the
  new one (31 extra short forms, all from "Label: words" lead-ins).

## Not verified

- GitHub CI on this branch, which runs both scripts in the Unit tests job
  (`scripts/test.sh`), was not yet seen when this was written.
- Nothing reads a title cited before its file name, as in
  *Title* (docs/LESSONS.md); such a citation is still unchecked.

## Follow-ups

None required. A title written before its file name, as above, could be
read in a later pull request if it becomes common.
