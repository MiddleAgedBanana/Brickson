# A privacy check keeps personal details out of the repository

*2026-11-07. Pull request #86 (`claude/project-thread-xre66l`). A cloud
thread, at the owner's request through the project's coordinator.*

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

## Reviews on the pull request

The first round, on `f5b3093`: CodeRabbit (four findings and a nitpick)
and Codex's code review (five findings). Each was reproduced first, and
each fix that is not a documentation fix has a test that failed before
it:

- **Where git finds the hook** (CodeRabbit): git runs `.githooks` from
  the checkout a push is made from, not from the branch it names, so
  from a checkout of a branch made before the check reached main, a push
  of a newer branch that has the hook goes out unchecked too. The
  hook's comment, docs/DECISIONS.md, AGENTS.md and docs/HANDOFF.md said
  "the branch being pushed"; they now say the checkout. The guard
  already refused such a push, as it reads the checkout's own hook; a
  test now pushes a branch that has the hook from a checkout of one that
  has none, and the refusal names the branch checked out. `--status`
  there now says that branch has no hook and to merge `origin/main`,
  instead of telling to turn on a setting that is already on. Declined:
  a hook kept outside the repository, the same for every branch, which
  no review or test would see and which would go stale.
- **The folder that holds the list** (CodeRabbit): `grep -r . ~/.config`,
  `find ~/.config -type f -exec cat {} +` and `cd ~/.config && cat b*/*`
  passed the guard, and Claude Code's Read deny rules do not cover a
  read that does not name the file. The guard now refuses a command
  that names a config folder itself (`~/.config`, `$XDG_CONFIG_HOME`,
  quoted or not, with or without a trailing slash) or a glob that could
  name it, the list's folder or the list (`~/.c*/b*/*`); other config
  folders and files stay allowed.
- **This record** (CodeRabbit): dated the day the pull request opened,
  with its number.
- **The workflow tests** (CodeRabbit): a missing "Privacy check" job or
  step fails with a message naming it, not with an error from `next()`
  or a `KeyError`. Git's location variables (`GIT_DIR` and the rest),
  inherited from a hook or a shell, would point the tests' git commands
  at the caller's checkout; the three test scripts now clear them.
- **Text that is not UTF-8** (Codex): a commit's or a push's patch was
  read as UTF-8 with its other bytes replaced, so an accented name in a
  Windows Latin file, found when the file was read whole, was missed in
  the commit that added it. A patch line that is not UTF-8 is now read
  both ways, as the whole file is.
- **Where a push goes** (Codex): a remote's tracking refs record what its
  fetch address held, but a remote with a `pushurl` pushes elsewhere, so
  its commits were left out of a push to a repository that may never
  have had them. Only remotes that fetch from where the push goes are
  left out now.
- **File content in base64** (Codex): `gh api` to the Contents API
  (`content`) or a Git blob takes a file in base64, which the guard read
  as letters. Base64 in text a command or tool publishes is now decoded
  and its bytes read as a file. Across the repository's 474 text files,
  decoding every run found nothing with a made-up list.
- **A gist with no file** (Codex): `gh gist create` given no file reads
  stdin, which the guard did not check; it now reads it as it reads an
  explicit `-`, so a here-document is checked and a pipe refused.
- **A draft's file name** (Codex): `--text FILE` printed the file's name
  even when it held a finding; such a draft is now named by its number.

The second round, Codex's code review of `bcc123c` (four findings; its
security review found nothing). Each was reproduced by a test that
failed before its fix:

- **A commit aimed at another checkout** (Codex): `git --git-dir=…
  --work-tree=… commit`, and the same through `GIT_DIR`, `GIT_WORK_TREE`,
  `GIT_INDEX_FILE` or `core.worktree`, commits another repository's or
  index's staged changes, while the guard read those of the folder the
  command runs in. Following every such choice into the checker would
  be a lot of new code for something agents need not do, so the guard
  refuses such a commit and says to use `git -C` or `cd`, which it
  follows.
- **A file name in a Contents API address** (Codex): `PUT
  /repos/{owner}/{repo}/contents/{path}` publishes the file under the
  path in its address, which the guard did not read, for `gh api` or
  `curl`. A write's path there is now checked as published text; reads
  are not.
- **Names split by `\n` or `\t`** (Codex): JSON writes a line break or a
  tab between two words as `\n` or `\t`, so a request body, or a JSON or
  code file, could hold a listed name as `First\nLast` unseen. The
  checker's second reading of a line now reads those escapes as spaces,
  for files and commits as well as the guard's requests.
- **An address in a commit's name** (Codex): the name an author,
  committer or tagger signs with was checked against the list only, so
  an address, a phone number or a home folder there passed. The name
  now gets every rule text gets; the address alone keeps the support
  address's allowance.

The privacy job's checkout names `actions/checkout@v7.0.1`, the version
pull request #87 locks, so whichever of the two merges second needs no
new lockfile entry. A cloud session cannot push `.github/workflows/`,
so the workflow change came to this branch as `privacy-check-workflow.yml`
at the repository's root, and a commit from the owner's Mac moved it
into place.

## The first run on the owner's Mac

Before moving the workflow into place, the agent on the owner's Mac ran
the Python checks at `bcc123c` under the Mac's `/usr/bin/python3`
(Python 3.9.6). `test-privacy.py` (130) and `test-docs.py` (57) passed;
two suites failed, and both would have failed on GitHub's Mac too:

- **`test-hooks.py`: 39 of 171 failed.** The tests gave git an empty
  settings file, so a commit's name and address were git's own guess,
  made from the machine's account and host name, and the guard rightly
  refused that address as a personal detail. On Linux here the host name
  has no dot, so git's guess is not an address and the tests passed.
  With `EMAIL` set to an address like the Mac's guess (git reads it
  before guessing), the 39 failed here too, with the same refusal. The
  tests' settings file now names a made-up person, the variables that
  would name the caller instead (`GIT_AUTHOR_*`, `GIT_COMMITTER_*`,
  `EMAIL`) are cleared, and a new test checks that both the tests and
  the guards they run commit as that person.
- **`test-runner.py`: the privacy step's test.** The check saw
  `SDKROOT`, `CPATH`, `LIBRARY_PATH` and `MANPATH`, which the test does
  not allow. macOS's `/usr/bin/python3` is a stub that starts the
  developer tools' Python through `xcrun`, which sets the SDK's paths
  for the tool it starts (`xcrun(1)`); the step's `env -i` cannot clear
  what is set after it. The test allows the four on macOS only, and
  gives the step its own values for three of them (not `SDKROOT`, which
  could stop a git that is also such a stub), which must never reach
  the check. On Linux the four stay refused.

The pull request's comment on its first CI run said only the four
workflow tests failed. That was all CI could show: "Check the test
script" fails first, and `scripts/test.sh`, which runs the hook tests,
is the step after it, so the hook tests had never run on a Mac.

At `ba6a4c3`, with the two fixes and the workflow in place, every
Python suite passed on the owner's Mac under its `/usr/bin/python3`
(3.9.6): the runner (95), hook (172), privacy (130), docs (57), site
(7) and Xcode-choice (23) tests.

## Commits

The commits of this branch, from the one after `0250270` (main when it
started).

## Verified

In this cloud thread (Linux, Python 3.13, git 2.43), last on 2026-11-07,
after main (with the reviewer roster) was merged in:

- `python3 scripts/test-privacy.py`: 132 tests, OK. Every test added
  for the second review, and for the pull request's two review rounds,
  failed before its fix. On 2026-11-06, ten
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
- `python3 scripts/test-hooks.py`, with a made-up list: 175 tests, OK,
  also with `EMAIL` set to an address like the Mac's guess, which failed
  39 of them before that fix (and with `GIT_AUTHOR_EMAIL` too, at
  `ba6a4c3`). The test added for it fails with no person in the tests'
  settings file. The tests added for the two review rounds each failed
  before their fix.
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
  no main fetched, both steps failed. With `sys.platform` made
  `darwin`, the step's test passed, and failed when the step passed its
  own `CPATH` on to the check. The unit job's result step passed
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
- Run with `GIT_DIR` pointing at another repository, the privacy tests
  as they were committed a commit and a remote there; as they are now,
  that repository is untouched.
- The checker, its tests, the guard, the hook tests and the runner tests
  parse as Python 3.9 (`ast.parse(..., feature_version=(3, 9))`), the
  Python the owner's Mac and its git hooks use.

## Not verified

- On a Mac, only the Python suites ran, last at `ba6a4c3` (*The first
  run on the owner's Mac*); the second review round's fixes have not
  run there yet. Not run on a Mac: the hook on a real push,
  `scripts/test.sh`, the guard in a Claude Code session there. CI runs
  the Python checks on GitHub's Mac.
- The CI step has not run on GitHub: the workflow change waits for the
  commit from the owner's Mac, and until the secret is set it fails by
  design. GitHub's masking of the secret was not tested; the check never
  prints the list either way.
- Whether a cloud environment's setup script line turns the hook on in
  the thread's clone was not tried; AGENTS.md also tells a cloud thread
  to turn it on in its own clone when `--status` reads a list.
- The check was not run with the owner's own list: only the owner has
  it. Their `--status` shows whether any entry already matches the
  repository.

## Follow-ups

- From the owner's Mac, by an agent there: the list, the GitHub secret
  and the workflow change; after the merge, with the owner's yes, the
  hook in `~/code/brickson`. The owner decides on the cloud variable
  (docs/HANDOFF.md, *Next steps, in order*).
- Any agent: run `--outgoing` before every push, and `--text -` on a
  pull request's description before posting it.
