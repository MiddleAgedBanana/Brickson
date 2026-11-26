# Who reviews when, and what happens when the index is full

*2026-11-26. Pull request #136 (`claude/project-thread-xfyeby`). Claude,
in a cloud project thread with no Mac.*

## What changed and why

Nothing changes for a person using Brickson. For the people and agents
working on it, the rules for asking reviewers now match what each
reviewer actually does, each reviewer's settings drop what no longer
works, and the decision index has a rule for the day it fills up.

- **When an agent asks each reviewer** (`AGENTS.md`, "Reviews and
  updates on GitHub"). CodeRabbit is asked once, after a round's last
  push, and never again within the hour, because its plan gives one
  review an hour and a second ask spends it on a head that is about to
  change. cubic reviews by itself when a pull request opens and after
  each push, as it did on #133 and #134 with no ask, so it is asked with
  `@cubic-dev-ai review this PR` only if it has not reviewed. Greptile
  is never asked: it reviews once, when a pull request opens. A Copilot
  request that fails for lack of credits is still said in the pull
  request and the thread and never retried, and now none is asked for
  until the next month, since GitHub's Copilot billing documentation
  says the allowance resets on the 1st. `AGENTS.md` goes from 32,683 to
  32,759 bytes, under its 32,768-byte limit.
- **cubic skips the same records as the others.** `cubic.yaml` gains
  `reviews.ignore.files` with the three patterns `.coderabbit.yaml` and
  `.greptile/config.json` already skip (`docs/archive/**` and the JSON
  and text evidence files). cubic's documentation
  (docs.cubic.dev, "cubic.yaml") describes the setting and says file
  filters apply to requested reviews too. cubic reads `cubic.yaml` from
  `main` only, so it takes effect after this merges. Its comment now
  says cubic reviews by itself, and `docs/DECISIONS.md`'s `cubic.yaml`
  bullet, `docs/SDLC.md`, `docs/HANDOFF.md` and the index's
  *Code review* line say the same.
- **CodeRabbit's settings lose two dead keys.** CodeRabbit's published
  schema (`coderabbit.ai/integrations/schema.v2.json`) marks both
  `reviews.pre_merge_checks.docstrings` and
  `reviews.finishing_touches.docstrings` "Deprecated. This setting has
  no effect", so both are gone, and the comment says why docstring
  generation is no longer listed among the switches kept off.
- `docs/SDLC.md`'s reviewer sentence said Greptile reviews as far as
  its plan allows and cubic once the owner installs it; it now says
  when each reviews and when an agent asks, as `AGENTS.md` does.
- **docs/DECISIONS.md, *Code review*,** gains "2026-11-26: who reviews
  when, and when an agent asks": what each of the eight reviewers does
  now, quoting its own words on the pull requests (CodeRabbit's
  one-an-hour footer and Gitar's trial footer on #135, Copilot's quota
  message on #132, Graphify's pause notice on #130 to #133), and why
  each is asked only when it can answer.
- **When the decision index reaches its limit** (docs/DECISIONS.md, new
  entry of that name). The index stays under 15 KiB: a change that
  would pass it first shortens long lines, then moves whole lines,
  superseded ones first and then the oldest, to
  `docs/DECISIONS-INDEX-ARCHIVE.md`, beside the index rather than in
  `docs/archive/`, which all three reviewers skip. The limit never
  rises and no line is dropped. The archive does not exist yet: the
  index is at 14,189 bytes, room for about ten more lines.
- `scripts/test-docs.py` reads the archive when it exists:
  `decision_index_problems` takes it, every decision needs exactly one
  line across both files, the archive's lines and `see "Title"`
  pointers are checked like the index's, the index must name the
  archive once it holds a line, only the index counts against the
  limit, and the failure at the limit says to move superseded lines,
  then the oldest, and never to raise the limit. Six new tests in
  `DecisionIndexTests`.
- The "A check keeps it true" bullet of "A one-line index of every
  decision" lost its garbled "in either case" (it meant either letter
  case) and its overlong line, and names the archive.
- `docs/DECISIONS-INDEX.md` has the new decision's line and the
  *Code review* line brought up to date.
- `docs/HANDOFF.md`: the state names #135 as merged and `main` at
  `4744efc`, lists this pull request as open, and the reviewer
  paragraph says what each reviewer does now.

## For the owner to decide

*Code Review Rules* asks the owner to decide every change to the rules
reviewers read, to their settings and to `scripts/test-docs.py`. This
pull request makes four:

- the ask rule in `AGENTS.md`: CodeRabbit once a round, cubic only if
  it has not reviewed, no ask to Greptile, and no Copilot request until
  the next month after one fails for credits (it asks reviewers less
  often; it weakens no invariant or review rule);
- `cubic.yaml`'s skip list (cubic stops reviewing the archive and the
  evidence files, as the other two already do);
- the two removed `.coderabbit.yaml` keys (no effect today, per
  CodeRabbit's schema);
- the index-archive decision and the `scripts/test-docs.py` change that
  enforces it (the check gains rules; none is dropped).

## Commits

- `5bb036a`: the ask rule in `AGENTS.md`, `cubic.yaml`,
  `.coderabbit.yaml`, `docs/SDLC.md` and the *Code review* bullet.
- `a2355d2`: the index-limit decision, the archive support in
  `scripts/test-docs.py` and its tests, the fixed bullet, the two index
  lines, docs/HANDOFF.md and this record.
- The third commit, after a report-only check of the branch: cubic
  reviews by itself (it had been written as reviewing only on request),
  the Copilot "never retried" rule kept, the limit message names
  superseded lines first, and this record lists what the owner
  decides.

## Verified

In the cloud session (Linux, no Mac):

- `python3 scripts/test-docs.py` runs 78 tests. With the archive left
  out of `decision_index_problems`, each of the five tests that build an
  archive failed, so none passes without the new code.
- The other Python checks of *Build and test*, and the privacy check
  on the outgoing commits with `--no-list` (no private list in a cloud
  session) and on the pull request text.
- Each new test fails when the rule it covers is taken out of
  `decision_index_problems`, and both reviewer settings files validate
  against their published schemas with no errors.
- That cubic reviews by itself, from its reviews on #133 and #134,
  which no comment asked for; and the Copilot reset date against
  GitHub's Copilot billing documentation.
- The two docstring keys against CodeRabbit's schema, and
  `reviews.ignore.files` against cubic's documentation, both read on
  2026-11-26.

## Not verified

- No Swift build or test ran here; no app code changed. CI is the
  build.
- cubic's skip list works only from `main`, so this pull request's own
  cubic review does not show it.
- That CodeRabbit accepts the trimmed settings shows only in its review
  of this pull request.

## Follow-ups

- `AGENTS.md` has 9 bytes left under its 32 KiB limit: the next rule
  added there needs a trim first, with its snapshot in `docs/archive/`.
- The index has about 1,171 bytes left; the first change that passes
  15 KiB creates the archive, as the new decision says.
- After 2026-11-29, check what Gitar posts once its trial ends, and
  correct docs/DECISIONS.md and docs/HANDOFF.md if it differs.
- Copilot reviews resume from 2026-12-01.
