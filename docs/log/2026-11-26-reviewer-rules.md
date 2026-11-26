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
  change. cubic is asked with `@cubic-dev-ai review this PR` only if it
  has not reviewed. Greptile is never asked: it reviews once, when a
  pull request opens. After a Copilot request fails for lack of credits,
  the agent says so in the pull request and the thread and asks for none
  until the 1st of the next month. `AGENTS.md` goes from 32,683 to
  32,760 bytes, under its 32,768-byte limit.
- **cubic skips the same records as the others.** `cubic.yaml` gains
  `reviews.ignore.files` with the three patterns `.coderabbit.yaml` and
  `.greptile/config.json` already skip (`docs/archive/**` and the JSON
  and text evidence files). cubic's documentation
  (docs.cubic.dev, "cubic.yaml") describes the setting and says file
  filters apply to requested reviews too. cubic reads `cubic.yaml` from
  `main` only, so it takes effect after this merges.
- **CodeRabbit's settings lose two dead keys.** CodeRabbit's published
  schema (`coderabbit.ai/integrations/schema.v2.json`) marks both
  `reviews.pre_merge_checks.docstrings` and
  `reviews.finishing_touches.docstrings` "Deprecated. This setting has
  no effect", so both are gone, and the comment says why docstring
  generation is no longer listed among the switches kept off.
- `docs/SDLC.md`'s reviewer sentence said cubic reviews by itself and
  Greptile as far as its plan allows; it now matches `AGENTS.md`.
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
  index is at 14,171 bytes, room for about ten more lines.
- `scripts/test-docs.py` reads the archive when it exists:
  `decision_index_problems` takes it, every decision needs exactly one
  line across both files, the archive's lines and `see "Title"`
  pointers are checked like the index's, the index must name the
  archive once it holds a line, only the index counts against the
  limit, and the failure at the limit says to move the oldest lines and
  never to raise the limit. Six new tests in `DecisionIndexTests`.
- The "A check keeps it true" bullet of "A one-line index of every
  decision" lost its garbled "in either case" (it meant either letter
  case) and its overlong line, and names the archive.
- `docs/DECISIONS-INDEX.md` has the new decision's line and the
  *Code review* line brought up to date.
- `docs/HANDOFF.md`: the state names #135 as merged and `main` at
  `4744efc`, lists this pull request as open, and the reviewer
  paragraph says what each reviewer does now.

## Commits

- `5bb036a`: the ask rule in `AGENTS.md`, `cubic.yaml`,
  `.coderabbit.yaml`, `docs/SDLC.md` and the *Code review* bullet.
- The commit that adds this record: the index-limit decision, the
  archive support in `scripts/test-docs.py` and its tests, the fixed
  bullet, the two index lines and docs/HANDOFF.md.

## Verified

In the cloud session (Linux, no Mac):

- `python3 scripts/test-docs.py` runs 78 tests. With the archive left
  out of `decision_index_problems`, each of the five tests that build an
  archive failed, so none passes without the new code.
- The other Python checks of *Build and test*, and the privacy check
  on the outgoing commits with `--no-list` (no private list in a cloud
  session) and on the pull request text.
- The two docstring keys against CodeRabbit's schema, and
  `reviews.ignore.files` against cubic's documentation, both read on
  2026-11-26.

## Not verified

- No Swift build or test ran here; no app code changed. CI is the
  build.
- cubic's skip list works only from `main`, so this pull request's own
  cubic review does not show it.
- Whether cubic also reviews by itself: watched on this pull request and
  noted there.
- That CodeRabbit accepts the trimmed settings shows only in its review
  of this pull request.

## Follow-ups

- `AGENTS.md` has 8 bytes left under its 32 KiB limit: the next rule
  added there needs a trim first, with its snapshot in `docs/archive/`.
- The index has about 1,189 bytes left; the first change that passes
  15 KiB creates the archive, as the new decision says.
- After 2026-11-29, check what Gitar posts once its trial ends, and
  correct docs/DECISIONS.md and docs/HANDOFF.md if it differs.
- Copilot reviews resume from 2026-12-01.
