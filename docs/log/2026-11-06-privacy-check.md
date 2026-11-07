# A privacy check keeps personal details out of the repository

*2026-11-06. Branch `claude/project-thread-xre66l`. A cloud thread, at the
owner's request through the project's coordinator.*

## What changed and why

The repository is public, and nothing looked for personal details before
they were pushed: `scripts/test-site.py` looks only for words about price.
Now a plain script, with no AI and no outside service, looks for them in
everything a push or a post would publish, and the gates run it before
anything leaves the computer (docs/DECISIONS.md, "Personal details stay
out of the repository", says what it finds, where it runs, what it cannot
catch and what to do when it finds something).

- `scripts/privacy-check.py`: a private list the owner keeps outside the
  repository (a file on the Mac, a GitHub secret, optionally a cloud
  environment variable), plus built-in patterns for email addresses, phone
  numbers, home folders and the place a photo was taken. It reads files,
  file names, the hidden text in pictures, PDFs, sound and video, commit
  messages and signatures, branch and tag names, and a pull request's
  title, description and branch. It prints places and kinds, never the
  words; in CI, counts only. Without the list it refuses to pass.
- `.githooks/pre-push`: git runs the check before every push from a
  checkout that turned it on (`git config core.hooksPath .githooks`).
- `.claude/hooks/guard.py`: before a commit, the guard checks its message,
  staged changes and the files the same command adds; before `gh`, the
  GitHub API, `curl` or a GitHub tool posts text, it checks that text;
  it refuses a push from a checkout whose pushes skip the hook,
  `--no-verify`, text the shell would build from a variable, and any
  command that names the list. `.claude/settings.json` sends the GitHub
  tools that post text (comments, reviews, gists, a new branch) through
  the guard and denies the Read and Edit tools the list's folder.
- CI (prepared, not pushed: a cloud session cannot change a workflow):
  a job of its own, "Privacy check", runs main's own copy of the check
  with the secret, on a machine where nothing from the pull request
  runs, and "Unit tests" waits for it and fails unless it passed.
  `scripts/test-runner.py` holds the workflow to that, and runs the
  steps' scripts on a copy of a repository to show which copy ran and
  with what.
- `scripts/test.sh` runs `scripts/test-privacy.py` before the unit tests,
  after the guard's and the documents' tests.
- AGENTS.md: before every push, run `--outgoing`, and check a pull
  request's text with `--text -`; a weakened privacy test is a review
  finding; *Guardrails for agents* describes the check. The setup guide,
  README, `docs/SDLC.md`, `docs/HANDOFF.md` and the verifier say how to
  run it and how to report it.

Choices made along the way, so the next agent does not redo them:

- **The pre-push hook is the one push gate.** An earlier draft had the
  guard read every push itself; the hook reads exactly what git is about
  to send, works for every agent and for the owner, and the guard only
  makes sure it is on.
- **CI runs main's copy, not the pull request's, in a job of its own.**
  Every run from a branch of this repository gets its secrets, so a pull
  request that changed the checker could print the list, and a value a
  job is given stays in its machine's memory for the whole job. Main's
  copy runs alone in its job, with `env -i` and `python3 -I`, so nothing
  from the pull request runs beside it and nothing from the run's
  environment or the checkout's Python files reaches it but what it
  needs.
- **No allowances and no "allow" mark.** An earlier draft let an entry
  be allowed in some files. Any such mark would be a way round the check
  that a careless edit could add, so the list holds only what may appear
  nowhere, and `--status` shows how many places each entry matches, by
  number, so the owner can lengthen an entry instead.
- **Fails closed.** With no list, the check, the hook and the guard all
  refuse rather than pass; `--no-list` runs the patterns alone and says
  so, and is never reported as a pass.

## The first review, and what it changed

Before the pull request opened, four reviewers read the change (how the
checker reads git, what it misses in text and files, ways round the
guard, and CI, docs and tests), and a second reader tried to reproduce
each finding. About forty were real; each was fixed with a failing test
first, or is now listed under "What it cannot catch":

- **How git is read:** a file name with a space or a quote, or in any
  script, is read whole; git's own error text, which can name a file, is
  never printed; a control byte in a file no longer splits its commit;
  names joined across lines by a change are found (three lines of
  context); `git replace`, merges of three or more branches, tags inside
  tags, a push to an address rather than a remote's name, and what is
  staged but changed again are all read as a push sends them; a push
  from a linked worktree reads the list; a PDF that git takes for text
  is read whole; CI's push run reads its own commit alone.
- **What text and files are read for:** a list word written without its
  accents, across HTML tags or a Markdown link, or after an acronym;
  phone numbers at the end of a sentence, with no-break spaces, any dash
  or an extension; home folders after a compiler flag; addresses in
  underscore emphasis; PDFs whatever their bytes (hex and UTF-16 strings,
  page text through each font's ToUnicode map), ZIP-based documents,
  GIF comments, MP3 and MP4 tags, compressed XMP, pictures embedded as
  `data:` addresses, UTF-16 and Windows Latin text; and exactly parsed
  fields get the full text rules. Crafted files no longer slow the
  check down quadratically.
- **The guard:** a file the same command writes and then publishes or
  commits; unquoted here-documents with `$` or backticks; stdin from
  anything but the command's own here-document; process substitution;
  commit trailers, authors and abbreviated options; `gh`'s short option
  clusters, labels and gists; an add run in another folder, or forced
  past `.gitignore`; `declare -x`; commands that print the whole
  environment. It no longer refuses escaped `` \` `` and `\$` in double
  quotes, `gh api -f body=@...`, GraphQL reads, or JSON request files
  with backticks. Its tests no longer depend on the machine's global
  git configuration.
- **CI and docs:** the workflow test counts every way of naming the
  secrets; the docs now say that a change to the workflow file itself
  can reach the secret before anyone reads it, that GitHub's secret is
  best kept one entry per line (each line is then hidden in logs, which
  a base64 secret's decoded words are not), how to set it on GitHub's
  website without the command-line tool, and that a cloud thread needs
  both the variable and the setup line or neither.

Declined: a time limit for crafted files (only their quadratic parts were
fixed), and non-UTF-8 file names on Linux (a Mac cannot make one; they
fail closed in commits).

## The second review, and what it changed

On 2026-11-07, before the pull request opened, the fixed change was read
again the same way (git, text and files, the guard, and CI, docs and
tests), and each finding was reproduced before it was fixed. All were
real; each was fixed with a failing test first, unless it is a
documentation fix:

- **How git is read:** a branch made before the check reached main has
  no hook, and git skips it without a word; the hook's comment and
  docs/DECISIONS.md now say so and say to merge `origin/main` first.
  Committing a conflicted merge reads only what its resolution adds,
  not everything main brought (it could run past the guard's time
  limit). `--outgoing` reads files left in conflict whole instead of
  failing on git's combined diff. A staged picture named like `0:x.png`
  is read. git's `log.showSignature` and `log.showRoot` settings no
  longer shift or hide what commits hold. A push to an address spelled
  differently from `origin`'s is matched to it. Refusing a commit's
  message no longer tells the agent to amend a commit that was never
  made.
- **What text and files are read for:** a phone number beside an en or
  em dash (a regression of the first round), or written with HTML
  entities, invisible characters or percent escapes (`tel:%2B1…`);
  Pages, Keynote and Numbers documents, whose text is in Snappy-compressed
  protocol-buffer records (the first round only guessed broken runs from
  them); PDF pages encoded with ASCII85 or ASCII hex before Flate (as
  reportlab writes them); the XMP and IPTC ImageMagick keeps in a PNG,
  and IPTC in a JPEG; a video's 3GPP place; `data:` addresses wrapped
  with `&#10;`; accents written as RTF escapes; a name followed by a
  contraction (`'ll`, `'d`); an address followed by `--`. A long
  document is no longer cut off at 4 MB per entry: one 64 MB budget
  covers the whole file, as the docs said. `--status` counts the
  matches the full check finds (accents, markup), not only exact ones.
  Three negative tests that could not fail for the rule they named were
  rewritten, and each rule's mutation now fails the suite.
- **The guard:** a commit message or pull request body written as
  `"$(cat <<'EOF' … EOF)"` holding an apostrophe or a quoted phrase was
  refused for the wrong reason, and backticks in literal text were read
  as commands; both are now read as text. `2>/dev/null` and other
  redirections were taken for git's own arguments (which also let
  `git push 2>&1 | tail -3` through on main). It now also reads: a
  redirection after `( … )`; a copy writing only its destination; a
  script's own `-` (`privacy-check.py --text - < body.md`) as the
  script's, not inline code; gh's `new` aliases and `reopen --comment`;
  a GraphQL request's variables as variables; `gh api --input -` from
  the command's own here-document; `git add --f`; a gist's file names;
  and the author and committer git will use, configured ones included.
  It refuses a commit in the same command as a change to its index
  (`git apply --cached`, `git am`, `git stash pop`) or as a
  `git config` that sets the identity, a git command in a folder the
  shell computes, and a push from a branch made before the check reached
  main, saying to merge `origin/main`.
- **CI and docs:** a value a GitHub job is given stays in its machine's
  memory for the whole job, so later steps in the unit job, which run the
  pull request's own scripts, could have read the list; it now reaches
  a job of its own, "Privacy check", on a separate machine where nothing
  from the pull request runs, and "Unit tests" waits for it and fails
  unless it passed. The workflow names main as `refs/remotes/origin/main`
  (a tag named `origin/main` would come first), and its test counts the
  secrets on every line, comments included. A `#` after an entry now
  starts a note instead of joining the entry. `--status` with no list
  fails and says so last. A number in a `tel:`, `sms:`, `callto:` or
  `facetime:` link is found without separators. The docs now say what a
  cloud thread with no list does before a push (`--outgoing --no-list`,
  said in the pull request), which phone numbers the check cannot tell
  from other numbers, that GitHub hides a secret line by line, that an
  edited pull request description is read only on the next push, where
  the cloud variable goes, and to turn off TextEdit's automatic spelling
  correction before writing the list.

Declined: finding phone numbers with no separators, seven-digit local
numbers and numbers written the national way outside North America
anywhere in text, which would match ids, versions and dates; they are
listed under what it cannot catch, and a phone link's number is found
however it is written.

## Commits

The commits of this branch, from the one after `0250270` (main when it
started).

## Verified

In this cloud thread (Linux, Python 3.13, git 2.43), last on 2026-11-07,
after main (with the reviewer roster) was merged in:

- `python3 scripts/test-privacy.py`: 126 tests, OK. Every test added
  for the second review failed before its fix. On 2026-11-06, ten
  deliberate breakages of the checker each failed it (every address
  allowed, no home-folder, phone or photo-location findings, no second
  pass over escaped text, names shown in place of a hidden label, no
  plural, no word boundary, commit signatures skipped, CI printing
  places); on 2026-11-07, each rule the second review added, broken in
  turn (the email edges, UTF-16 controls, markup, PDF gaps and
  ActualText, ZIP, entry, Exif, XP, MP4, ID3, GIF and JPEG comments,
  phone edges, folded phones, contractions, RTF bytes and their order
  with JSON escapes, Snappy copies, IPTC datasets, a zero place), failed
  it.
- `python3 scripts/test-hooks.py`, with a made-up list: 167 tests, OK.
  Run against the guard as it was before the second review's fixes, the
  13 tests added for them and the 2 they extended all failed (49
  failures); the ten breakages of the guard's privacy rules from
  2026-11-06 each failed it.
- `python3 scripts/test-runner.py`: 95 tests, OK (5 skipped, as on
  `main`: they read the Mac's processes). The workflow tests ran the
  privacy steps' own scripts in copies of a repository holding a tag
  named `origin/main`: main's copy ran, with `PATH=/usr/bin:/bin`,
  Python's isolated mode and none of the run's other variables; while
  main had no check, the pull request's copy ran without the list; with
  no main fetched, both steps failed. The unit job's result step passed
  only when the privacy job's result was success. The old layout, plain
  `origin/main`, the secrets named in a comment, `if: success()` and a
  result step that passed on anything but failure each failed them.
- `python3 scripts/test-docs.py` (57 tests), `scripts/test-site.py` and
  `scripts/test-select-xcode.py`: OK.
- The CI step's script, run by hand on 2026-11-06 on a copy of a
  repository with the real checker as main's copy and a made-up list
  given as `base64:`: it found the made-up name in a file, a commit and
  a pull request's description, printed three findings as one count,
  and exited 1.
- `python3 scripts/privacy-check.py --no-list`: no finding in the 607
  tracked files. `--history --no-list`: three uses of the published
  support address in one old commit's log record, which docs/DECISIONS.md
  records. `--outgoing`, with a scratch list kept outside the
  repository: nothing found in this branch's commits.
- The checker, its tests, the guard, the hook tests and the runner tests
  parse as Python 3.9 (`ast.parse(..., feature_version=(3, 9))`), the
  Python the owner's Mac and its git hooks use.

## Not verified

- Nothing ran on a Mac: not the hook under the Mac's own Python 3.9, not
  `scripts/test.sh`, not the guard in a Claude Code session on the Mac.
  CI runs the Python checks on GitHub's Mac.
- The CI step has not run on GitHub: the workflow change waits for the
  owner to commit it, and until the owner adds the secret it fails by
  design. GitHub's masking of the secret was not tested; the check never
  prints the list either way.
- Whether a cloud environment's setup script line turns the hook on in
  the thread's clone was not tried; AGENTS.md also tells a cloud thread
  to turn it on in its own clone when `--status` reads a list.
- The check was not run with the owner's own list: only the owner has
  it. Their `--status` shows whether any entry already matches the
  repository.

## Follow-ups

- The owner: write the list, set the GitHub secret, decide on the cloud
  variable, commit the workflow change, and turn the hook on in
  `~/code/brickson` (docs/HANDOFF.md, *Next steps, in order*).
- Any agent: run `--outgoing` before every push, and `--text -` on a
  pull request's description before posting it.
