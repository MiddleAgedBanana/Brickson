# The privacy check's six follow-ups, Avery's decision and the push cap

*2026-11-08. Pull request #88 (`claude/project-thread-55xakt`).
A thread on the owner's Mac, from the project's coordinator.*

## What changed and why

Pull request #86 added the privacy check (docs/DECISIONS.md, "Personal
details stay out of the repository"). After its review loop closed,
Codex found six narrow gaps, each reproduced and answered on #86 and
listed in its *Follow-ups*. Each now has a test that failed first:

- **RTF formatting hid a list word.** A control word (`\b`, `\i`, a font
  change) or a group's braces between a name's words, or inside one, and
  a writer's line wrapping, kept its letters apart. The check now also
  reads RTF as a reader shows it: control words, braces and wrapping
  removed and joined within a paragraph, and apart at `\par`, `\line`,
  `\tab`, `\cell` and the like, so the paragraph before a name written in
  lowercase is not part of it. `\uN` and `\'hh` stay, for folding to read
  as the accent they stand for. A file is RTF when a line starts with
  `{\rtf` and its version, as a whole file does, or when its path ends
  `.rtf`, so a change to one is read this way too; text that only
  mentions RTF is not read so, as its line breaks would then join words
  (Codex's review 4503213922).
- **`gh pr create --fill` published unread text.** With `--head`, gh
  writes the title and body from local commits it does not push, so the
  privacy hook never read them, and the guard read only the options it
  was given. The guard now refuses gh's autofill (`--fill`, `-f`,
  `--fill-first`, `--fill-verbose`, in a cluster such as `-df`, and as
  `--fill=true`) and asks for `--title` and `--body` or `--body-file`,
  which it reads (4503213927). An old guard test listed
  `gh pr create --fill` among commands that only read; it now names
  `gh pr create --title t --body b` there instead, which is what that
  test is for (creating a pull request is not merging one).
- **An XMP place near zero degrees was missed.** The pattern took the
  first digit of a coordinate, so `0,26.7N` (within a degree of the
  equator) or a padded `005,30.5N` read as no place. Now any number but
  zero in the value is a place (a rational's denominator, the `/1` a
  tool's text copy writes, is not one), and zeros alone still pass, as a
  camera with no fix writes them (4503283734).
- **HTTPie's standalone `@file` body was not read.**
  `http POST <api url> @payload.json` sends the file as the body, as if
  from stdin (HTTPie's parser, `_parse_items` and `_body_from_file`,
  read from its source on GitHub), and with no method HTTPie then posts
  it (`_guess_method`). The guard now reads that file through the same
  bounded reader as curl's `-d @file`, refuses one it cannot read (a
  missing file), and counts it as a body when it decides the method
  (Codex's review of `e7803fb`, answered on #86).
- **Minified HTML joined paragraphs.** With every tag removed,
  `<p>intro</p><p>first <b>last</b></p>` reads `introfirst last`, so a
  lowercase two-word entry after a block was missed. The markup reading
  now runs a second time with an HTML block's tags (paragraphs, headings,
  lists, tables, breaks and the other blocks, in any case) as line
  breaks, and inline tags still joined (4504097336). `HTML_BREAK`
  matches a name's end rather than looking ahead to it, so code scanning
  does not read it as a tag filter that misses capitals (the existing
  test for that pattern rule covers it).
- **A PDF line's pieces after another line were missed.** The check
  dropped the positioning operators, so it read a page either as one run
  (joining the line above to a name) or piece by piece (splitting a name
  shown in three pieces). It now also reads each content stream line by
  line: a piece is on the same line as the one before when no `T*`, `'`
  or `"` came between them and the line matrix (`BT`, `Tm`, `Td`, `TD`)
  puts it at the same height, so a move along a line keeps it there
  (4504140744). The two older readings stay.

Every new reading is added beside the ones before it, never in their
place, so nothing the check found before goes unfound.

Three more changes, from the coordinator, in this pull request because
they edit the same files:

- **Avery's decision of 2026-11-08**, recorded in docs/DECISIONS.md
  under the privacy decision, and summed up in AGENTS.md, *Code Review
  Rules*: Avery's own name, their brother's first name and their own
  email addresses may appear in the repository, its commits and its
  pull requests; the Claude session links in commits and pull requests
  stay; the brother's medical and hospice details, phrases, device and
  settings, family conversations and the Mac's account name stay out;
  and the private list stays at one entry, because Avery does not want
  sensitive details written into any stored list. The AGENTS.md bullet
  that lists the owner's exceptions was tightened at the same time, so
  the part of AGENTS.md Codex must read stays under its 32 KiB
  (`scripts/test-docs.py`).
- **The review push cap** (AGENTS.md, *Build and test*, "Pushing to an
  open PR"): rounds now count from the moment a pull request opens, at
  most three, one push each, none while CI is still running, then one
  final push that batches what is left. The cap used to count from the
  first green run, which never applied to #86: it was first green at its
  fourteenth push. This tightens a review rule, so the owner decides
  whether it stands.
- **A security review from Codex** (AGENTS.md, *Build and test*,
  "Reviews and updates on GitHub"): a pull request that changes privacy
  or a workflow asks for one, once, with a comment reading
  `@codex security review`, the only `@codex` command an agent writes.
  Avery approved it on 2026-11-08 ("yes to all three", on the Codex
  decisions the coordinator put to them).

## Commits

See the pull request; one commit for the checks and their tests, one for
the documents.

## Verified

On the owner's Mac (macOS 27.2, `/usr/bin/python3` 3.9.6), in a
throwaway clone with the push hook on:

- `scripts/test-privacy.py`: all tests pass. The new tests failed before
  their fixes (27 failures and 12 errors across the four new reader
  tests). With each fix undone in a copy of the script, its test fails:
  the RTF reading off, RTF known by its content alone (a change to a
  file is then missed) or by its path alone (an RTF file named
  otherwise is missed), any mention of `{\rtf` taken for RTF (words
  joined across a document's lines), `\par` or `\tab` read as nothing, `\uN`
  stripped as a control word; the HTML block reading off; the PDF line
  reading off, a move along a line read as a new line, the quote
  operators not moving to the next line; the old first-digit XMP rule,
  any digit counted (zeros found as a place), and a rational's
  denominator counted.
- `scripts/test-hooks.py`: all tests pass. The two new tests failed
  before the fix (10 autofill commands allowed; 5 HTTPie commands
  allowed, a missing file among them).
- `scripts/test-docs.py`, `scripts/test-runner.py` and
  `python3 scripts/privacy-check.py --outgoing` (with the owner's list),
  as the pull request says.

## Not verified

- No app code changed, so no build or Xcode test ran; CI runs the unit
  and UI tests as usual.
- The readers were tested on files built in the tests, not on files
  from TextEdit, Word, a browser's saved page or a PDF writer; the PDF
  reading of rotated text (where a move along a line changes its
  height) still has the two older readings only.
- HTTPie itself was not run: its behaviour was read from its source.
- `gh pr create --fill` was not run; the refusal is the guard's alone.

## Follow-ups

- The coordinator asked that AGENTS.md be trimmed where no rule is lost.
  Beyond the one bullet above, that is left for its own pull request:
  moving long reference material (much of *Gotchas*, the Mac route under
  *Build and test*) into a document AGENTS.md points to needs a snapshot
  in `docs/archive/` first (AGENTS.md, *Workflow rules*), and a review of
  its own. Its target: the sections Codex must read within the first
  24,000 bytes, where Antigravity stops reading rule files (32,113 bytes
  today). Owner: a later thread, after this one merges
  (docs/HANDOFF.md, the guardrails paragraph).
- The push check in `~/code/brickson` and the cloud list stay Avery's
  choices (docs/HANDOFF.md, *Next steps, in order*, item 8).
