# Reviewers configured in the repository, cubic added, CI hardened

*2026-11-07. Pull request #85 (`claude/project-thread-cguht9`). The
thread "Harden CI and add CodeRabbit and cubic config", in a cloud
session, from the consultant's brief of 2026-11-06 and the owner's
answer to it.*

## What changed and why

Nothing in the app changes. This is about who reviews Brickson's pull
requests and what GitHub's machines may run.

The consultant's brief of 2026-11-06 made seven recommendations. The
owner agreed to all of them but one: rather than replace Greptile with
cubic, keep Greptile and add cubic, because reviewers built on
different models see different things, and one can stand in when
another is out of credits ("a roster"). docs/DECISIONS.md, *Code
review*, records the decision and *Dependencies* the hardening.

- **`.coderabbit.yaml`.** CodeRabbit's settings, from the brief's draft
  with one gap closed: the draft left "fix CI" on, a finishing touch
  that writes code, is on by default and comes with the plan
  open-source projects get. All six code-writing finishing touches are
  off; so are the docstring coverage warning and LanguageTool's prose
  style suggestions, each a conversation to resolve with nothing to
  fix. `inheritance: false` makes the file the whole configuration, so
  anything set on CodeRabbit's website stops applying; what the website
  held could not be read (*Not verified*).
- **`cubic.yaml`.** cubic's settings: review on open and each push,
  never approve, never resolve its own threads, never write the pull
  request description (agents keep its first two lines), never write
  code. cubic reads the file from `main` only, so it applies from the
  merge on.
- **`.greptile/`.** The brief's fallback draft, kept because the owner
  kept Greptile: the one-credit Base review once per pull request, no
  style comments, `AGENTS.md` named as the rules. Its config reference
  confirms every key and value; the archive pattern is written
  `docs/archive/**`, the form the reference shows, rather than the
  draft's `docs/archive/`.
- **AGENTS.md**, "Reviews and updates on GitHub": the roster, how to ask
  each reviewer, and a new rule that reviewers never write the code and
  no agent asks one to. Some of CodeRabbit's commands that commit have
  no setting to turn them off, so the rule holds them. A new gotcha
  says which branch each reviewer reads its instructions from: cubic's
  is `main`, the others' the pull request's own.
- **`persist-credentials: false`** on all four checkouts, in
  `tests.yml` and `pages.yml`. No step uses the token after checkout
  (no script runs `git` against GitHub), and nothing uploaded includes
  the checkout, so this closes a door rather than a leak.
  `scripts/test-runner.py` fails a checkout, in a workflow or in a
  local action one runs, that does not set it under its own `with:`,
  and fails any line naming `actions/checkout` that is not a step its
  reader read, in the forms a workflow is written in (*Verified*).
- **`.github/workflows/dependency-review.yml`**, GitHub's own
  dependency review on every pull request, without a checkout (the
  action reads the change through GitHub's API). Not a required check.
- **Settings for the owner** (docs/HANDOFF.md, "Next steps, in order",
  item 9): install cubic on Brickson alone; allow only GitHub's actions
  and the owner's own (GitHub's choice for the first always allows the
  second);
  and, optionally, turn off training in ChatGPT, Codex and Greptile.

### The review, and what it changed

Codex and CodeRabbit reviewed; cubic is not installed yet, and
Greptile did not review (it was out of credits when last checked, on
2026-11-06).

- **Codex** asked for the owner's approval of `.greptile/`, a new file
  reviewers read as instructions: it is listed among the owner's
  decisions in the pull request. It then found the hardening recorded
  but not on the branch at `64827e8`: true then, because the workflow
  commit was still on its way from the Mac (*Commits*).
- **CodeRabbit** found five things, all real, all fixed in one push:
  - The step reader missed valid forms: a comment after `steps:`, an
    anchored `steps:`, and a list at the key's own depth, so the
    checkout test could pass without seeing a checkout. The reader now
    reads them, and a form it still cannot read fails the test rather
    than slipping past (the second check, below).
  - A quoted `uses:` was not read as a checkout, and
    `persist-credentials` counted anywhere in the step; now quotes are
    dropped, and only the key directly under the step's own `with:`
    counts.
  - The allowlist setting does not make Actions GitHub-only: GitHub
    documents that "Allow MiddleAgedBanana, and select
    non-MiddleAgedBanana" always allows the owner's own actions.
    docs/DECISIONS.md, *Dependencies*, and the owner's step now say so;
    *Code Review Rules* still flags any action not published by GitHub.
  - cubic resolves a thread by itself when it judges a later commit
    fixed it (`resolve_threads_when_addressed`, default true). It is now
    false, so the agent answers each finding and resolves it.
  - *Commits* below named no hashes, which `docs/log/README.md` asks
    for.
- **A second check, before the push.** Three agents then tried to make
  the checkout test pass while a checkout kept its token, in forms
  GitHub accepts, and re-read every corrected sentence against its
  source. They found three ways past it: an anchor on a checkout's
  `uses:` with an alias in the other jobs (GitHub's changelog announced
  anchors in workflows on 2025-09-18), a checkout in a local action under
  `.github/actions/`, and a checkout spelled with capitals. The test
  now finds every line that names `actions/checkout`, in any case or
  separator, outside whole-line comments, and fails unless that line is
  the `uses:` of a step it read as a checkout, comparing lines rather
  than counts; it also reads every `action.yml` under `.github` and
  every local action a workflow or action runs. It now also accepts an
  anchored `with:`, a flow `with: { persist-credentials: false }` and
  `False` written in capitals, which it had refused though they keep no
  token. The same agents corrected the cubic comment's reason, "five
  dependencies" (there are six), HANDOFF's "every feature that writes
  code" (only those with a setting), an unsupported "Greptile had no
  credits", and the wording of this record's *Commits* and *Verified*.

### What the brief got wrong or left stale

Checked against the repository at `778a146` (`main` after #84) and the
vendors' own pages on 2026-11-07:

- **CodeRabbit's draft missed `fix_ci`** (above). Its schema lists seven
  finishing-touch keys; the draft had four. `simplify` is off by
  default and is written out anyway.
- **`actions/dependency-review-action@v5` is not a tag.** `v5` exists
  only as a branch; the one v5 tag is `v5.0.0`
  (`a1d282b36b6f3519aa1f3fc636f609c47dddb294`), which the workflow
  names. Floating major tags for that action stop at `v3`.
- **The draft workflow checked out the repository for nothing.** The
  action compares through GitHub's API and reads no local file unless
  given a local `config-file`; with no checkout there is no token to
  persist.
- **checkout no longer writes the token into `.git/config`.** Since
  `actions/checkout` v6 it keeps it in a file under `$RUNNER_TEMP`,
  which Git still reads, so later steps can still use it: the setting
  still matters, the brief's wording of where is stale.
- **cubic has a configuration file**, `cubic.yaml` (the brief left it
  unverified), read from the default branch only.
- **cubic's data terms are mixed.** Its documentation says its model
  providers do not train on the code, and its Marketplace page says the
  code is deleted after review; its terms (section 7.1) let cubic train
  its own AI on customers' code unless a separate agreement says
  otherwise, and its subprocessor list sends review snippets to a
  tracing service. Whether a public repository under a proprietary
  licence is free under its public-repository plan is not stated: the
  documentation ties it to the repository being public.
- **Greptile's `effort: "base"` is a floor, not a cap.** Greptile runs
  the highest tier any of its settings asks for, so the one-credit
  review holds only while the website's default tier is Base or Auto.
- **The docstring warning fired more often than the brief counted.**
  It named pull requests #76, #78, #80, #81 and #82; CodeRabbit's own
  comments show the warning on every pull request from #76 to #83
  (coverage 0 to 77 per cent against its 80 per cent bar), and not on
  #84, which changed only documents.
- **Line numbers.** The brief's citations were at `0250270`; the four
  checkouts are still at `tests.yml:48, 93, 122` and `pages.yml:43` on
  `778a146`. Its other `AGENTS.md` and `docs/DECISIONS.md` line numbers
  moved with #84 and this pull request; nothing here cites them.

## Commits

On `claude/project-thread-cguht9`:

- `b878c47` cubic's and Greptile's settings.
- `c67f1b0` this record, AGENTS.md, DECISIONS, HANDOFF and SDLC.
- `237071e` Greptile's archive pattern.
- `64827e8` CodeRabbit's settings.
- `1fe6098` the checkouts, the dependency review workflow and the
  checkout test.
- `2fb28a7` this record's CodeRabbit and push notes, and HANDOFF's
  step about CodeRabbit's "Autofix" box.
- `d7ced27` the checkout test's fixes, from both rounds (*The review,
  and what it changed*).
- `fe1a1a6` cubic leaves its threads open.
- The commit after `fe1a1a6`: the allowlist wording, the second
  check's corrections and this record of the review.

The cloud session's push of the workflow commit was refused for want
of the `workflow` scope (AGENTS.md, *Gotchas*, still true on
2026-11-07), so a worktree on the owner's Mac, through Remote Control,
applied it and the record's next commit, as `1fe6098` and `2fb28a7`,
and pushed them.

## Verified

- `.coderabbit.yaml` and `cubic.yaml` validate against each vendor's
  JSON schema, downloaded on 2026-11-07
  (`https://www.coderabbit.ai/integrations/schema.v2.json`, sha256
  `53ca372d5bbfefd61e2bad9ab5ef399e69d1e06b07a73221b006d83682a743fa`; `https://www.cubic.dev/schema/cubic-repository-config.schema.json`,
  sha256 `98ed2a1391be41a6310808b8f8517815a7d73e21cb801ade5f9f6db93a24bfaa`), with Python's `jsonschema` 4.26.0. Both
  schemas reject an unquoted `off`, which YAML 1.1 readers take as
  false, so it is quoted in both files.
- `.greptile/config.json` and `files.json`: every key and value checked
  against Greptile's configuration reference, read 2026-11-07.
- Action tags read with `git ls-remote` on 2026-11-07: `actions/checkout`
  `v7` and `v7.0.1` both at `3d3c42e5aac5ba805825da76410c181273ba90b1`;
  `actions/dependency-review-action` `v5.0.0` at
  `a1d282b36b6f3519aa1f3fc636f609c47dddb294`; `github/gh-actions-lock`
  `v0.4.1` at `04b7a1a4d00b339dd3ff903bb4d78d4066b2bac7`.
- `scripts/test-runner.py`'s new
  `test_every_checkout_leaves_no_token_behind` failed on the four
  checkouts before they changed, and passes after. After CodeRabbit's
  review, each of these made the workflow tests fail, and each was
  undone: removing the setting from one checkout; moving it to the
  step's own depth; adding a flow-style checkout; adding a workflow
  whose list sits at the depth of `steps:` with a checkout that keeps
  its token; putting back the reader's old order of checks; reading a
  quoted `uses:` with its quotes; and accepting the key at any depth.
  After the second check, so did each of these, on a copy of the
  repository: an anchored checkout aliased in two jobs of `tests.yml`;
  a checkout in a new `.github/actions/setup/action.yml`; a checkout in
  `pages.yml` spelled `Actions/Checkout` without the setting; and, in
  the code, matching the action's name with case, without the
  backslash or without its end, counting whole-line comments,
  comparing counts instead of lines, letting a quoted value in a flow
  `with:` through, matching `false` with case, refusing an anchored
  `with:`, ignoring a flow `with:`, leaving out the actions under
  `.github` or the local actions a step runs, and dropping line
  numbers. Before the code changed, the new and rewritten tests failed
  or errored (the functions they call did not exist yet), and
  `test_every_checkout_leaves_no_token_behind` errored for the same
  reason.
- `scripts/test-docs.py`, `scripts/test-hooks.py` and
  `scripts/test-runner.py` pass.
- CodeRabbit reads `.coderabbit.yaml` from the pull request's branch:
  once the file was pushed (`64827e8`), the run configuration in its
  summary comment on this pull request changed from "Repository UI"
  with no file to "Repository YAML" with this file at that commit, and
  the "Autofix" box (below) left the comment.
- What each reviewer reads, how each is triggered and each one's data
  terms: the vendors' own documentation, schema and terms, read
  2026-11-07, each claim then re-read by a second agent trying to
  refute it.

## Not verified

- What CodeRabbit's website settings held before `.coderabbit.yaml`.
  `@coderabbitai configuration` on this pull request (02:07Z) answered
  only that it would fetch them, and nothing followed. Its summary
  comment showed the one layer it used ("Repository UI"), the Chill
  profile and no configuration file. If the owner changed a setting
  there, the file has to carry it, or it no longer applies.
- Whether CodeRabbit's continuous Autofix mode can still be started
  another way. Before the file, its summary comment carried an
  "Autofix" box ("Keep fixing CodeRabbit findings and required CI, and
  resolving merge conflicts"); with `finishing_touches.autofix` off the
  box is gone (*Verified*), but its documentation does not say whether
  a bare `@coderabbitai autofix` still starts the mode. The rule in
  AGENTS.md, "Reviews and updates on GitHub", holds it: no agent asks,
  and nobody ticks the box if it comes back.
- Nothing was built: no Swift changed. GitHub CI runs on the pull
  request, and the new "Dependency review" job runs on it too.
- cubic is not installed yet, so no cubic review has run, and whether
  its free plan covers this repository is known only once it reviews.
- Whether Greptile's free plan honours `instructions` and `files.json`
  (its pricing page lists custom context under Pro), and when its
  monthly credits come back.
- How much of `AGENTS.md` (over 70 KB) CodeRabbit, Greptile and cubic
  read: none of them documents a limit for guideline files.
- The owner's Actions setting: GitHub's API refuses to show it here.

## Follow-ups

- **The owner's settings** (docs/HANDOFF.md, "Next steps, in order",
  item 9). *(the owner)*
- **The workflow lockfile**, one pull request in a new thread on the
  owner's Mac; its steps are in docs/HANDOFF.md, "Repository, CI and
  website". *(next repository thread)*
- **Whether "Dependency review" becomes a required check.** *(the
  owner, after it has run on a few pull requests)*
- **Measure cubic for two weeks** once installed: reviews per pull
  request, any fair-use refusal, and whether its findings are ones the
  others missed. *(each thread that opens a pull request notes it in its
  record)*
