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

The third round, Codex's code review of `0fd0fbc` (four findings). Each
was reproduced by a test that failed before its fix:

- **Release assets** (Codex): `gh release create` given files, and
  `gh release upload`, send whole files to GitHub, which the guard did
  not read (it reads a gist's files). An asset is often an archive whose
  contents it cannot read, and agents make no releases, so the guard
  refuses an upload, by gh or by a request to GitHub's uploads host. A
  release's title and notes are still read.
- **One quoted word vouching for another** (Codex): the guard decided
  whether a `$` was text from every quoted word in the command, so in
  `echo '$BODY'; gh pr comment 12 --body "$BODY"` the quoted one let
  the shell's value of `BODY` through. A value whose text also appears
  built elsewhere in the command now counts as built.
- **The list where `XDG_CONFIG_HOME` puts it** (Codex): the checker
  reads the list from there when that is an absolute path, while the
  Read and Edit deny rules name only `~/.config/brickson`. The guard now
  also runs before the file tools (Read, Edit, MultiEdit, Write,
  NotebookEdit, Grep, Glob) and refuses them the list's folder at both
  places, and Grep a folder that holds it. Commands that name that
  folder, or the config folder around it, are refused there as they
  were at the default place.
- **A hook turned off just before a push** (Codex): the guard read the
  hook and its setting before the whole command ran, so
  `git config core.hooksPath /dev/null && git push` and
  `chmod -x .githooks/pre-push && git push` passed it. A push is now
  refused after a command in the same call that changes the hooks'
  setting (`core.hooksPath`, the `core` section, an included file),
  checks out another branch or commit, or writes, removes or changes
  the mode of anything in `.githooks`, git's own folder, git's settings
  files or `scripts/privacy-check.py`, or a file the guard cannot place.
  That also refuses `git checkout main && git push origin HEAD:feature`,
  which an older guard test allowed: the test now expects the refusal,
  and a renamed branch (`git branch -m`), which keeps its files, takes
  its place for a push that names its destination.

The fourth round, CodeRabbit's and Codex's reviews of `9910f78` (three
and five findings; two of CodeRabbit's were lines of this record and of
docs/HANDOFF.md that were not true, now corrected). Each of the six
code findings was reproduced by a test that failed before its fix:

- **A relative read after a `cd`** (CodeRabbit): the guard read a
  command's words as written, so `cd ~/.config/gh && cat ../b*/*`,
  `cd ~/.config/gh/.. && cat b*/*` and `cd ~/.config/gh && grep -r . ..`
  reached the list. Each word is now read from the folder the command
  runs in, as the guard follows `cd`, `pushd`, `env -C` and a subshell,
  `..` and globs included, at both places the list may be. A `cd` into a
  config folder written with `$HOME` or `$XDG_CONFIG_HOME` is followed
  too; any other folder the shell builds stays unknown, as before. Other
  config files stay readable (`cd ~/.config/gh && cat hosts.yml`). A
  recursive read of a folder that holds a config folder (`grep -r . ~`)
  is not refused, and docs/DECISIONS.md now says so.
- **curl's one and three slashes** (Codex): curl takes
  `https:/api.github.com/...` and `https:///api.github.com/...` as the
  same address, which the guard did not see as GitHub's, so a request's
  text went unread. The guard now reads an address as curl does.
- **A message taken from another commit** (Codex): `-C`, `-c`,
  `--fixup` and `--squash` take a commit's message (and `-C` and `-c`
  its author), and `--amend` keeps the last commit's, none of which the
  guard read. It now reads them, and refuses a commit whose source it
  cannot read (built by the shell, or not there yet).
- **A name before a capital S** (Codex): the checker's plural took the
  next word's capital, so a listed name in `NameStore` or
  `NameSettings` was missed, in files, commits and CI alike. A name is
  now also tried without its plural.
- **Base64 spelled with JSON escapes** (Codex): a request file could
  write every letter of a file's base64 as a `\uXXXX` escape, which the
  check for encoded content did not undo. It now reads the run with the
  escapes undone, as GitHub does.
- **A release's tag and a repository's name** (Codex): both are public,
  and the guard did not read them (round three had listed them as a
  limit). `gh release create`'s tag, `gh release edit --tag`, and
  `gh repo create` and `gh repo rename`'s names are now read.

The fifth round: Codex's review of `c6b6909` (four findings), a
follow-up of CodeRabbit's on docs/HANDOFF.md, and an adversarial review
of the same commit by this thread, each of whose findings was
reproduced against `c6b6909` before it counted. Each code finding was
reproduced by a test that failed before its fix:

- **An author given as a pattern** (Codex): `--author` that is not
  `Name <address>` makes git take the identity of the latest commit
  whose author it matches. The guard now finds that commit as git does
  and reads its identity, and refuses a pattern no commit matches.
- **A message file that is not UTF-8** (Codex): a `-F` file in Latin-1
  or Windows-1252 was not read. It is now read in each encoding it may
  be in.
- **A repository named after its folder** (Codex): `gh repo create
  --source` with no name names the repository after the folder, which
  is now read; **`gh issue develop --name`** (Codex) makes a branch on
  GitHub, whose name is now read.
- **Where a read happens**: `cd`'s options (`-P`, `-L`, `-e`, `--`), a
  `cd` to `$HOME` or `$XDG_CONFIG_HOME/..`, `$PWD`, `~+`, a `HOME` the
  command changes, a program's own `-C` (`git -C`, `tar -C`,
  `make --directory`), each part of a `CDPATH`, braces
  (`~/.config/{,}b*/*`) and another case (the Mac's file system finds
  `~/.config/Brickson`) each reached the list unseen. A read is now
  placed as the shell places it.
- **A word no path can hold**: a NUL byte or a lone surrogate crashed
  the guard, which then blocked the call without a reason. Such a word
  is now skipped, and git's output is read whatever its bytes.
- **A reused commit, as git takes it**: the last of `--reset-author`
  and `--no-reset-author` decides (an abbreviation of the second is
  refused), an option's value is never an option (`-m --reset-author`),
  `--author` replaces a reused author, `--amend --squash` keeps the
  amended message, `--amend --fixup` takes nothing from it, and the
  reading no longer follows the command's own log encoding, which made
  git answer in UTF-16, or crashed the guard.
- **A commit after a ref moves**: a reset, checkout, tag, fetch,
  cherry-pick or the like earlier in the same call changes which commit
  a name reaches, or leaves a merge message or a cherry-pick's author,
  after the guard has read them. Such a commit is now refused unless it
  names its source by its full hash. A pending `MERGE_MSG` or
  `SQUASH_MSG`, and during a cherry-pick the picked commit's author, are
  now read.
- **Programs that run a command**: `stdbuf`, `setsid`, `ionice`, `chrt`,
  `taskset`, `caffeinate`, `arch`, `flock`, `watch` and `find -exec` ran
  a git command the guard never saw, so `stdbuf -o0 git add -A` passed
  every rule. The guard now reads the command each one runs.
- **An escaped GitHub host**: curl decodes `%` escapes in a host
  (`api%2egithub.com`), which every API rule missed.
- **More of what gh puts on GitHub**: a fork's name, a topic, a gist
  file's new name, a project's text, an Actions variable (refused from
  stdin, as a gist is), and a name after `-R` at the end of a cluster
  (`gh repo rename -yR o/r name`). The GitHub tools that create a
  repository or a fork now run the guard too.
- **A lone carriage return in base64**: `\u000d` between two parts of
  a run cut it in two, where JSON's `\r` did not.
- **Records that were not true**: docs/HANDOFF.md, item 8, and *Not
  verified* said "Privacy check" fails without the secret on this pull
  request, where main has no check yet; *Verified* said the runner tests
  pass, without saying they ran with the staged workflow in place; and
  AGENTS.md still said the guard refuses every command that reaches the
  list. Each now says what is so.

Before this round was pushed, a second independent check read its new
code the same way, and found that some of it refused ordinary commands,
was slow, or could still be passed. Each finding was reproduced, and
each has a test that failed before its fix:

- **Ordinary commands refused**: a `cd` or `pushd` with a redirection
  (`pushd sub >/dev/null`) lost its folder; reads such as `git branch
  --show-current`, `git remote -v`, `git tag -l`, `git stash list`, a
  fetch, and a checkout of paths while a merge waits (`git checkout
  --theirs a`) all counted as moving a ref, which refused the usual way
  to finish a merge (`git add a && git commit --no-edit`); and
  `git cherry-pick -n` counted as leaving its commit's author. The
  guard now tells a command that moves `HEAD` (a reset, a branch
  checkout, a merge, a commit, a cherry-pick) from one that moves only
  other names (a fetch, a tag, a stash, a note, a reflog entry), and a
  read from either. `find -exec git add {} +` is refused, as before
  with xargs, with a reason that says find fills `{}` in when it runs.
- **Time**: a long JSON body's braces and colons, expanded in every
  folder a command might run in, took the guard 26 seconds, and a
  script of 32 `cd` lines 30, past the hook's 10. Braces in quotes are
  now text, only the parts of an assignment a `:` starts with `~` (or
  `CDPATH`'s) are paths, each path and each git question is answered
  once, and folders are normalised (`sub/..` is the folder itself). A
  script whose `cd` lines, each of which may fail, left more than 128
  folders to follow was refused with a reason that said to join them
  with `&&` (the third check, below, changed both).
- **Readings that could be passed**: `flock` and `watch` options in a
  cluster or abbreviated (`flock -nw 1`, `watch --int 1`, now read as
  getopt reads them, and an unknown one refused); `find`'s `( )`, a
  test's operand spelled like an action (`-name -exec`), and
  `-execdir` (now run in the found file's folder); `chrt` with no
  priority, and `xcrun`, `script`, `setpriv`, `prlimit`, `unshare` and
  `doas`, which run a command; `~` with `HOME` unset (bash takes the
  account's home); a `HOME` set from `~+` or `$PWD`, or by `for`,
  `read`, `printf -v` or `mapfile` (now refused); a number range in
  braces (now every number); a newline or a long first part in braces;
  tar's `-C` in a cluster, as `--dir` or in its old first word;
  `--no-author` and `--no-file`, which undo an earlier option; a
  `MERGE_MSG`, `.mailmap`, `git config`, note or reflog change in the
  same call as the commit that takes it; a value option gh takes that
  the guard read as a switch (`--jq`, `--remove-topic`), so every word a
  publishing gh command is given is now read; `gh repo create --source`
  through a link (gh names it by the path as written), and a NUL there,
  which crashed the guard; and a GitHub host in fullwidth letters or
  with another full stop (`api.github.com。`), which curl maps to the
  ASCII host.

A third independent check then read the code those fixes added, the
same way, and found 21 more. Each was reproduced, and each has a test
that failed before its fix (71 failing cases between them):

- **Ordinary commands refused**: `git pull` counted as leaving a picked
  commit's author, and `git commit --amend --no-edit` as taking a
  pending message, so a pull before a commit, or an amend beside any
  inline code (`python3 -c 'print(1)'`), was refused; inline code that
  names neither git, `HEAD` nor `refs` no longer counts as a write in
  git's folder (a push after it is still refused). Scripts of seven or
  eight `cd` lines, even joined with `&&` or followed by `|| exit 1`,
  passed the limit of 128 folders: a `cd` followed by `|| exit`, or
  after `set -e`, now leaves no second branch, and the limits are 1024
  folders and 400 answers from git. `find -exec sh -c 'script' _ {}`
  and read-only git under find (`git blame {}`) were refused as xargs
  is. `read`, `for` and `printf -v` refused every `GIT_` name
  (`GIT_SHA`), where only the names git reads, and those already set,
  matter. A gist's file path was read as published whole, where gh
  publishes its base name only.
- **Time**: a long body after seven `cd` lines, and a 60 KB word with
  braces, took the guard past its 10 seconds (37 for the second). A
  word is now split at `:` only where a `:` can start a path, once per
  word rather than once per folder; braces stop at 2 MB of text; and
  each part's nested commands are read once. Every reproduction now
  decides in under two seconds here.
- **Readings that could be passed**: an appended assignment
  (`NAME+=value`) before a command hid the command, and `HOME+=` moved
  `~` unseen; `${XDG_CONFIG_HOME:=…}` and `declare -n` set what `read`
  was refused for (now refused too); an abbreviated long option of
  `setpriv`, `unshare` and the other runners took its value as the
  command (now read as getopt reads it); `script -t` takes the next word
  on a Mac and none on Linux (now read both ways); `git checkout
  <branch> --`, `fetch --update-head-ok`, `checkout -b`, `switch -c` and
  a `reset` with no commit were read as leaving `HEAD`; `git tag -a`,
  `--sort`, `--format` and `--column` on a branch or tag,
  `branch --set-upstream-to` and `remote -v update` were read as reads;
  a `.mailmap` checked out before an `--author` pattern went unseen;
  cherry-pick's `-X` options and `--no-cleanup` were read as
  `--no-commit`; `git commit --no-message`, which undoes `-m`, was not
  known; `..` after a link was taken by name, where the system goes
  through the link; a GitHub host in letters that only Unicode's later
  mapping turns into ASCII passed (now read through Unicode's
  compatibility mapping and case folding first); and a number range in
  braces over 4,300 digits crashed the guard.

While fixing these, this thread found one more of its own: the shell's
usual default, `"${XDG_CONFIG_HOME:-$HOME/.config}"`, was read as the
variable alone, so a read through it reached the list wherever the
variable was unset. A default is now read both ways.

What these fixes cost: a commit that reuses another's message or author
is refused after a write whose target the shell builds
(`make > "$LOG"`), and an `--author` pattern after a new branch is made
(`git checkout -b`), since either may change what the commit takes.

What the guard cannot hold without running the command is recorded in
docs/DECISIONS.md, *What it cannot catch*: commits that `cherry-pick`,
`revert`, `merge -m`, `commit-tree` or a rebase make (the hook reads
them before a push), an alias defined earlier in the same call or a
mistyped command `help.autocorrect` runs, a `cd` that `eval` or
`source` runs, `cd -` and `~-`, a `cd` after `set -P`, a link made in
the same command, a word longer than 64 KB and the words past the
1024th (or past 2 MB of text) that braces make, a command run by a
program it does not know as a runner, an `-execdir` inside find's
`( )`, a glob over a link followed by `..`, a GitHub host only curl's
IDNA library maps, inline code that writes in git's folder without
naming it, and base64 of eight bytes or fewer. `return` and zsh's
`setopt errexit` are not read as ending a branch, which can only make
the guard follow more folders, never fewer.

The sixth round, Codex's and CodeRabbit's reviews of `2a7cb7d`, and
three independent checks by this thread of its own fixes:

- **Commit text in another encoding** (Codex): with
  `i18n.logOutputEncoding`, or `i18n.commitEncoding` alone, set to
  Latin-1, `git log` wrote a commit's text in Latin-1, which the check
  read as UTF-8, so a name with an accent went unread. The check now
  asks git for UTF-8.
- **What that fix cost, and what was already missed** (this thread's
  checks): asking for UTF-8 converts from the encoding a commit names,
  and the label can be wrong. `git commit` with `i18n.commitEncoding`
  set to Latin-1 keeps the UTF-8 a terminal types under a Latin-1
  label, which the old reading caught only while the setting was on,
  and the new one missed. A label that misdescribes plain text (UTF-16,
  CP037) made git show nothing, a zero byte ended the message git
  showed, and an encoding's own name was never read. So each commit is
  now read twice: as git shows it in UTF-8, and as git keeps it (`git
  cat-file --batch`), which is what a push sends, with every header but
  the object ids of its tree and parents. A tag's headers are read too,
  and text in UTF-16 is read as UTF-16. Reading several ways first
  reported one name twice, at two columns, so a place several readings
  find is now reported once, at the first reading's column, as a file's
  two readings already were.
- **What the second check found** in that rework: two false refusals
  it caused, both fixed. With `log.showSignature` on, gpg's lines came
  before the commit id the guard asked for, so reusing any signed
  commit was refused; and a merge of the owner's signed tag carries the
  tag (`mergetag`), whose tagger, read as plain text, made the support
  address a finding, so it is now read as a tag is. Older gaps it
  found, also fixed: a signature's armor can hold a comment, now read;
  a second tagger, or a tree or parent line that names no object, went
  unread; an address with a trailing dot or a comment, which git keeps,
  was not taken for one, in the check and the guard (`--author='T
  <address>>'` too, which git cleans); text in UTF-32 went unread (a
  reading without zero bytes is added); and a push of a blob or a tree,
  or of a tag of one, published its files unread, and is now refused.
- **Reused commits and `--author`** (the same checks): `git commit -C`
  takes a commit converted to its own `i18n.commitEncoding`, as it is
  where that names the commit's encoding, so the guard reads a reused
  commit both ways. An `--author` that is not `Name <address>`, which
  round five had the guard look up as git does, is now refused: which
  commit git finds depends on the locale (a pattern's `.` is a byte in
  the C locale and a letter in UTF-8), the log encoding and `.mailmap`,
  and the guard found a different commit than git in each. Giving the
  whole identity is the reliable way; agents commit as the configured
  identity. The tests that an earlier `.mailmap`, note or setting
  changes whom a pattern finds went with it, as there is no pattern
  left to change.
- **What the third check found**: one false refusal the rework
  caused. Reading a signature's header as text read its base64 too,
  where a word may start at a case change, a `/` or a `+`, so an
  ordinary signed commit could hold a list word: the check found an SSH
  signature that did by trying commit times. A signature's base64 is
  now decoded and its bytes read as a binary file's are, which also
  reads the signer's name and address an OpenPGP signature carries
  (checked with a GnuPG signature here), first left as a limit. Older
  gaps it found, also fixed: a committer's or tagger's continuation
  line, and more of a merged tag's tagger line after its time zone; a
  merged tag's type line that names no type; an accented name in
  UTF-32, or in UTF-16 with a letter whose low byte is zero (an emoji);
  and a second address joined to the first by `+`, `%` or `_`, which
  git keeps.
- **What a fourth check found** in those fixes: reading a signature's
  bytes as a binary file's are refused ordinary signatures. A security
  key's SSH signature names its key type, `sk-ssh-ed25519@openssh.com`,
  which read as an address (every address at `openssh.com` itself,
  where OpenSSH writes its names, is now allowed), and Sequoia adds a notation, `salt` in its own
  namespace, `notations.sequoia-pgp.org`, written like an address, to
  every OpenPGP signature. So an
  OpenPGP signature is now read packet by packet: its signer's user ID,
  policy, key server and readable notations' values, not a notation's
  name. An X.509 signature (gpgsm, gitsign) is read element by element,
  which finds a certificate's address that the next element's `0` hid
  from the binary reading. The armor is read more strictly: a BEGIN line
  starts a block afresh, so a clearsigned message's own lines (a name
  alone on one) are no longer taken for its signature; only lines of one
  width after the armor's headers count as base64, so a word among them
  makes the block text; and a last line of padding alone (`==`, as
  OpenSSH's 70 columns can leave) no longer leaves a whole SSH signature
  read as words. An identity's address is also read as text, so an
  address with accents or escapes, or a phone number, is found. Text
  with zero bytes is also read as Windows' Latin without them, for an
  accented name out of step with its bytes. A long merged tag or
  signature (100,000 lines took 25 seconds) and an identity git would
  never write (100,000 ` <` took 87) are now read in time proportional
  to their size.
- **Which encodings a message file is read in** (CodeRabbit):
  docs/DECISIONS.md said "any encoding"; it now names the ones the
  guard reads, and says that a message kept in an encoding
  `i18n.commitEncoding` names is read at the push, where git converts
  it (checked here with a made-up word in ISO-8859-5).
- **CI results that have not happened** (CodeRabbit): docs/HANDOFF.md
  and *Not verified* described this pull request's "Privacy check" job
  as if it ran; until the workflow commit there is no such job, and
  both now say so.

Left as limits, in docs/DECISIONS.md, *What it cannot catch*: a branch
or tag name a push names that is not UTF-8 (file names that are not
UTF-8 were already there); in the guard, an encoding's name a setting
writes into a commit, which the push reads; in an SSH signature, or one
in a format the check does not read field by field, a name or address
that is not a run of eight readable bytes; an OpenPGP notation's name;
and in text, an address joined to another by `+`, `%` or `_`. The two
readings of a message that is not UTF-8 take more than twice as long on
such a history (2000 imported Latin-1 commits: about 22 seconds against 9 at
`2a7cb7d`). UTF-8 history takes about a fifth longer (2000 commits: 1.1
seconds against 0.9), to fetch each stored object; its text is read
again only where it differs from what git shows, which in this
repository's last 30 commits it never did.

The seventh round, CodeRabbit's and Codex's reviews of `87a2b75`, and
two independent checks by this thread of its own fixes:

- **A port names another server** (CodeRabbit): a push to an address
  counted as a remote's whatever its port, so a push to `host:2223` left
  out what a remote fetching from `host:2222` had. A port the scheme
  does not use by default now makes it another address.
- **OpenSSH's names** (CodeRabbit): every address under `openssh.com`
  was allowed; now only those at `openssh.com` itself, where OpenSSH
  writes its names, are.
- **`gh repo create --push`** (Codex) pushes the source folder's
  commits itself (`git push REMOTE HEAD`, or `--mirror` for a bare
  repository, in gh 2.89's source), past the guard's push rules,
  whether or not that checkout runs the hook. The guard refuses it,
  read as gh's flag parser reads it: `--push`, `--push=true` or `=1`,
  the last one written counting, and not after an option that takes
  the next word as its value.
- **What the checks found in those fixes, and around them.** In the
  check: joining an IPv6 host and its port made `[::1]:2222` and
  `[::1:2222]` one address (the address is now kept in parts); `:22`
  counted as no port, but ssh takes the port of an address without one
  from its own settings, so any port written for ssh now counts; and
  over ssh a path that starts in the home of the user who signs in
  (`host:path`, `~/path`) was the same for every user, and one that
  starts at `/` the same as one that does not, so both now keep them
  apart, except on github.com, which names a repository the same way
  whoever signs in. In the guard, gh had more ways to push, or to run
  what the guard did not read, now all refused: an option before a
  command's name, which cobra still reads as that command's (`gh pr
  --squash=true merge 5` merged, and `gh repo --push=true create`
  pushed), except `-R`, `--repo`, `--hostname` and help; `-R`, `--repo`
  or `--hostname` after the names, which gh takes as the value of an
  option before them, so `-d -R --push` pushed and `--title -R
  --body-file f` hid the file (the guard dropped them with the next
  word); a `--push` the shell builds or expands (`$F`, `$(…)`, `"$@"`,
  braces, patterns); `gh repo create` with no words, which asks its
  questions and can push where a terminal answers, and `gh pr create`
  without `--head` under `script`, which asks where to push the branch
  (also under `unbuffer`, which the guard now reads as a wrapper);
  `gh copilot`, the Copilot CLI agent, which can push by itself; an
  alias the same call sets, imports, deletes or writes into gh's
  configuration, which `gh alias list`, read before the call, does not
  see, and an extension, so a gh command is now one of gh's own or an
  alias gh had before the call; and a shell alias the command defines,
  which bash expands on a later line.
- **A sentence that was not true**: docs/DECISIONS.md said a remote's
  address could be written "with or without `.git`", which the check
  does for a host's address only (a local path is the folder it
  resolves to). It now says so.

Left as limits: ssh's settings can send a host's name to another
server, and the check takes github.com to be GitHub's; a program that
gives what it runs a terminal in its own language (`expect`, `socat`,
`ssh -t`) is not read, as an interpreter's code is not.

The eighth round, Codex's and CodeRabbit's reviews of `f704512`, and
an independent check by this thread of its own fix:

- **Text git shows as lines it cannot be read in** (Codex): where
  `.gitattributes` gives a file the `diff` attribute, git shows UTF-16
  as lines of text with zero bytes between the letters, so a list word
  in such a file went unread in commits and pushes, while the
  whole-file reading found it. A change whose lines hold a zero byte,
  or whose first line starts with UTF-16's byte order mark (git shows a
  line of UTF-16 that holds no zero byte as text by itself), now has its
  file read whole, as a binary file's is. Found with it: text in
  UTF-32 went unread in every file, and is now read, with a byte order
  mark or without.
- **What the independent check found** in that fix, each reproduced:
  four older gaps of the same kind, where a change past a file's first
  line holds no zero byte: UTF-16 with a mark and no Latin letters (in
  Chinese, a letter's byte can end git's line, and git shows such a
  file as text with no attribute), UTF-16 with no mark whose first part
  is Latin, a PDF not named `.pdf`, and a picture's base64 in a page,
  wrapped below its `data:` address. A file whose changed lines are not
  UTF-8 is now read whole where the whole-file reading reads it
  otherwise (a binary format, UTF-16 or UTF-32), and so is one whose
  changed lines hold a line of base64 alone. It also found that UTF-32's
  marks start other data too (UTF-16 whose first letter is U+0000, and
  a binary file), which the fix read as UTF-32 and so missed; such data
  is now read as before. A scan of 150,019 files in this cloud container found
  no binary file read as UTF-32, and `--history` reports the same and
  takes the same time.
- **An address off GitHub is what git sends** (CodeRabbit, twice): over
  ssh, a path that starts at `/` counted as the same repository
  whoever signed in, but a server can map each user's paths apart (a
  chroot, or a command it runs for every push); and `app` and
  `app.git` counted as one repository, which a server can hold as two.
  Off GitHub, an address is now a remote's only with the same scheme,
  user, host, port and path, as written, except that git sends
  `ssh://host/~/path` as `~/path`. That also stops counting `host:path`
  and `host:~/path` as one, which such a command can read apart. This
  reverses part of the seventh round, which kept the user only for a
  path in the user's home and dropped a trailing `/` or `.git` on every
  host; on github.com both still name the same repository.
- **gh with a terminal** (Codex's security review, and CodeRabbit):
  `gh issue create --recover state.json`, run with a terminal, published
  the title and body a recovery file holds, which the guard did not
  read; and `unbuffer bash -c 'gh pr create …'` gave gh a terminal the
  guard did not see, as it marked one only for gh run straight under
  `unbuffer`. Given a terminal, gh also asks for any title or body it is
  not given, or opens an editor, and reads the answers from stdin, which
  the guard does not read either. So every gh command given a terminal
  is now refused (it was only `gh pr create` without `--head`), whether
  `script` or `unbuffer` runs it straight or through a shell or another
  program, and so is `--recover` with or without one.
- **`gh extension exec`** (CodeRabbit) ran an extension, which the
  seventh round refused only by its own name. It is refused too.
- **A message's name used twice** (CodeRabbit): the seventh round's
  message for a shell alias a command defines took the name of the
  message for a Git shell alias, so a Git shell alias was refused with
  the other's words. Each now has its own name, and a test fails when
  any name in the guard is defined twice.

The privacy job's checkout names `actions/checkout@v7.0.1`, the version
pull request #87 locks, so whichever of the two merges second needs no
new lockfile entry. A cloud session cannot push `.github/workflows/`,
so the workflow change came to this branch as `privacy-check-workflow.yml`
at the repository's root, for a commit from the owner's Mac to move into
place; until that commit, "Unit tests" fails here on purpose (*Not
verified*).

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

- `python3 scripts/test-privacy.py`: 143 tests, OK. Every test added
  for the second review, and for the pull request's review rounds,
  failed before its fix; for the eighth, the new test of text git shows
  as lines found none of its 9 files in a commit before the fix, the
  test of changes past a file's first line none of its 4, and the
  UTF-32 test failed its 4 cases, and its 2 cases of other data after
  UTF-32's marks with the round's first fix; with each part of the fix
  taken out in turn (the zero byte, the byte order mark, UTF-32 with a
  mark and without one, reading the file whole, the blob's own reading,
  UTF-16 without a mark in it, base64 lines, the marks' fallback), one
  of them failed; and
  the address test got 16 of its 61 cases wrong at `f704512`; for the
  seventh, the address test got 18 of
  its 42 cases wrong at `87a2b75` and 13 with the round's first fix,
  and the `openssh.com` test failed at `87a2b75`; for the sixth, the encoding test failed its 5
  cases against `2a7cb7d`, the stored-object test its 8 against the
  round's first fix, the tests for the second check's findings 10
  against the rework, those for the third check's 13 before their
  fixes, and those for the fourth check's 15 before theirs (and the 2
  deep certificates with the first, too shallow, nesting limit). With
  a real GnuPG signature made here, the signer's address is found in a
  signed commit and a signed tag; with a real SSH signature whose
  base64 held a made-up list word, the push the third check saw
  refused now goes through; a real gpgsm signature holding its
  certificate gives the certificate's address, and one without gives
  only its issuer's names. The fourth check's security-key and Sequoia
  signatures, made by stand-ins that follow each format, now pass. Over this repository's 843
  commits (757 signed), the made-up list finds the same 278 places as at
  `2a7cb7d`, in about the same time (9.6 seconds against 9.3). On 2026-11-06, ten
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
- `python3 scripts/test-hooks.py`, with a made-up list: 217 tests, OK,
  also with `EMAIL` set to an address like the Mac's guess, which failed
  39 of them before that fix (and with `GIT_AUTHOR_EMAIL` too, at
  `ba6a4c3`). The test added for it fails with no person in the tests'
  settings file. The tests added for the three review rounds each failed
  before their fix: for the third, run against the guard and settings
  of `0fd0fbc`, the 4 new tests failed 55 cases between them, and the 2
  settings tests and the branch test that now expects a refusal failed
  too.
  For the fifth, the 4 tests added for Codex's findings failed their 13
  new cases against `c6b6909`, and the 13 tests added or extended for
  the other findings failed 113 cases between them before their fixes;
  the 14 tests added or extended for the second check's findings failed
  92 cases between them against the round's code before those fixes;
  and the 13 tests added or extended for the third check's findings
  failed 71 cases between them against the code before its fixes (one
  of them by crashing the guard). The test for the shell's default
  form failed 7 cases with the default's reading taken out.
  Timed here, the commands that took the guard 26 and 30 seconds take
  under one, a 4 KB JSON body in three folders about 0.1, and the
  third check's 67 reproductions under two each (the slowest 1.8).
  For the fourth, run against `9910f78`: 15 of the 16 new refused reads
  after a `cd` passed (the other was refused for another reason), as did
  the 3 new curl addresses, the 7 tag and repository names, 13 reused
  commits before that test stopped, and 2 of the 3 escaped requests
  (curl's was refused already); in `scripts/test-privacy.py`, the new
  test missed 6 of its 8 names.
  For the eighth, run against `f704512`: the 3 new tests and the 1
  they extended failed 19 cases between them.
  For the seventh, run against `87a2b75`: the 6 new tests failed 48
  cases between them, and the 2 tests they extended 8.
  For the sixth: the encoding test failed 5 cases against `2a7cb7d`;
  against the round's first fix, the reworked pattern test failed 5
  cases, the stored-commit test 5 and the test of places reported once
  and each 1; against the rework, the signed-commit test failed 1 and
  the 5 new address forms 5 (the last run against a copy with the old
  address rule), the 2 joined addresses the third check added failed
  against the address rule before it, and the accented address the
  fourth check added failed without the address read as text.
  Run against the guard as it was before the second review's fixes, the
  13 tests added for them and the 2 they extended all failed (49
  failures); the ten breakages of the guard's privacy rules from
  2026-11-06 each failed it.
- `python3 scripts/test-runner.py`, with `privacy-check-workflow.yml`
  copied over `.github/workflows/tests.yml` (not committed: a cloud
  session cannot push it): 95 tests, OK (5 skipped, as on `main`: they
  read the Mac's processes). As committed, 4 of its workflow tests
  fail, here and on CI, until the owner's commit moves the file into
  place. The workflow tests ran the
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
- `python3 scripts/privacy-check.py --no-list`: no finding in the 608
  tracked files. `--history --no-list`: three uses of the published
  support address in one old commit's log record, which docs/DECISIONS.md
  records. `--outgoing`, with a scratch list kept outside the
  repository: nothing found in this branch's commits.
- Run with `GIT_DIR` pointing at another repository, the privacy tests
  as they were committed a commit and a remote there; as they are now,
  that repository is untouched.
- The checker, its tests, the guard, the hook tests and the runner tests
  parse as Python 3.9 (`ast.parse(..., feature_version=(3, 9))`), the
  Python the owner's Mac and its git hooks use, and every suite also
  passed here under Python 3.9.25.

## Not verified

- On a Mac, only the Python suites ran, last at `ba6a4c3` (*The first
  run on the owner's Mac*); the second to eighth review rounds' fixes
  have not run there yet. `caffeinate`, `arch`, `xcrun` and macOS's
  `script` exist only on a Mac, and `chrt` without a priority only in
  util-linux 2.42 and later: how the guard reads them was checked
  against their manual pages; `flock`, `watch`, `script -c` and `find`
  were run here with harmless commands. How curl maps a fullwidth host
  was checked here (curl 8.5 with libidn2), not on the Mac, whose curl
  may not map it at all. How `|| exit`, `set -e` and `${NAME:-word}`
  behave was checked in bash here, not in the Mac's zsh, which runs the
  agents' commands there. The guard's times were measured on this
  machine only. Not run on a Mac: the hook on a real push,
  `scripts/test.sh`, the guard in a Claude Code session there. CI runs
  the Python checks on GitHub's Mac.
- The CI step has not run on GitHub: the workflow change waits for the
  commit from the owner's Mac, and until then this pull request's
  workflow has no "Privacy check" job and no step that runs the check.
  Once that commit lands, and not before, "Privacy check" will pass
  here without reading anything (main has no check yet), and "Unit
  tests" will run this branch's check on the patterns alone, without
  the list; a run without the secret fails only once the check is on
  main. Until the workflow commit, "Unit tests" fails here on purpose:
  its 4 workflow tests find no privacy job in
  `.github/workflows/tests.yml`.
  GitHub's masking of the secret was not tested; the check never
  prints the list either way.
- gh's questions under `script` were seen here (gh 2.89, with no
  network) as far as the first; the push after them, and `unbuffer`,
  which is not installed here, were read from gh's source and
  `unbuffer`'s manual page.
- The guard before the file tools was fed the calls Claude Code sends
  (`file_path`, `notebook_path`, `path`), not run in a live session.
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
