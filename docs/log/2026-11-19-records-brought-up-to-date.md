# The records brought up to date

*2026-11-19. Pull request #127 (`claude/project-thread-zsjz76`). A Claude Code
cloud thread, which cannot build or run the app. Documents only.*

## What changed and why

Nothing a person using Brickson sees or hears changes. The documents the
next agent starts from had fallen behind what merged, and a few named
things a public repository should not.

- **docs/HANDOFF.md.** The state line at the top was from 2026-10-23; it
  now names `main`'s head and the open pull requests. "Install cubic" is
  marked done (its app has reviewed since #114). The known gap "no test
  pins `cloudKitDatabase: .none`" is gone: `PhraseLibraryTests`'
  `theAppsStoreNeverSyncs` pins it, and `scripts/forbidden-code.py`
  refuses CloudKit and an iCloud capability in the app. The reviewer
  paragraph names Gitar, Graphify and SonarQube Cloud.
- **docs/DECISIONS.md.**
  - *Code review* gains a dated entry: the owner said on 2026-11-16
    that every review bot on the pull requests is theirs, and Gitar,
    Graphify and SonarQube Cloud are described beside the five already
    there. The ruleset row's list of reviewers whose conversations must
    be resolved names all eight. Nothing about who asks which reviewer
    changes.
  - *Age rating answers* records Apple's two new questions.
  - A new decision, "Text people read is in American English" (below).
- **docs/APP-STORE.md, section 6.** Apple added two age-rating questions
  on 2026-11-16, Shared Location and Dating and Relationships, which
  every app must have answered by 2027-01-12 (Apple's news of 2026-11-02,
  read 2026-11-19). Brickson answers No to both: it has no location code
  (`git grep` finds no CoreLocation in `Brickson/`) and no such feature.
  Re-answer if caregiver alerts ever share a location.
- **American English.** AGENTS.md's rule for words people see now says
  they are in American English, and docs/DECISIONS.md says why and what
  it covers: the app's own text and its App Store text, never a person's
  own words, and not code or documents. The one exception is the name of
  the disease in the UK and Australian store text, which docs/ASO.md
  already plans. A search of the String Catalog (388 keys), the starter
  phrases, `Info.plist` and the App Store text drafts (docs/ASO.md, *The
  store text*, and docs/APP-STORE.md's notes for App Review) found no
  British spelling. The website's accessibility page has some
  (*Follow-ups*).
- **docs/ROADMAP.md.** Localization no longer waits for a sync check
  that CI already runs, and the hold on Xcode's JSON project format now
  says what docs/DECISIONS.md says: a release after Xcode 27.2, either a
  27.2 fix release or 27.3 (only betas of 27.3 so far).
- **docs/ACCESSIBILITY.md.** The row for `HoverEffectGroup`,
  `hoverEffect(in:isEnabled:body:)`, `pointerStyle(_:)` and
  `pointerVisibility(_:)` said SwiftUI 18.0. Apple's documentation lists
  none of them for iOS or iPadOS (visionOS, and macOS for the two pointer
  modifiers), so the row says so. Nothing in the app used them.
- **docs/EXPERIMENTS.md.** SIM-1 (b) asked an agent to render a preview
  in Xcode's canvas, which needs the project open in Xcode, and AGENTS.md
  never lets an agent open it; that step is now the owner's. The run
  sheet's question IDs are its own, grouped by topic (accessibility,
  design, other communication apps), and no longer described by where
  the research was kept.
- **Older records, corrected.** Nine earlier `docs/log/` files, one
  work file, five passages of docs/DECISIONS.md and one each of
  docs/HANDOFF.md and docs/ACCESSIBILITY.md pointed to notes kept
  outside the repository, or to what a tool's plan costs, which this
  public repository does not hold. Each is a correction of that mistake,
  which docs/log/README.md allows in a merged entry ("correct a mistake
  in it"), not a later change; this file records it. What each says
  about Brickson and the work is unchanged. One detail goes with the
  wording: the 2026-11-13 entry now says that two readers and a check
  stopped before they finished, but no longer why, because the reason it
  gave was the tool's plan.

## Commits

On `claude/project-thread-zsjz76`: `d07d433`, the records brought up to
date; then the answers to the first review round (this file's *Older
records, corrected*, and Gitar's "Approved" label in docs/DECISIONS.md);
then this file's pull request number and the three pull requests opened
since in docs/HANDOFF.md's state line; then `main` brought in after #128
merged, with the state line moved to it and a known gap for a drawing
test that failed twice on this branch's third push.

## Verified

- On the cloud thread (Linux): `python3 scripts/test-docs.py`,
  `scripts/test-hooks.py`, `scripts/test-privacy.py` and
  `scripts/test-forbidden-code.py`, with the result in the pull request.
- GitHub CI on the second push: "Unit tests" and all six UI test parts
  passed, after one re-run of an iPad part whose accessibility audit
  timed out and a unit job cancelled on a slow runner; the pull request
  has the details.
- `AGENTS.md` stays under the 32 KiB that Codex reads.
- Apple's pages read on 2026-11-19: the age-rating news item, the
  releases feed (Xcode 27.3 beta 2 the newest Xcode, 27.2 the newest
  release), and the four hover and pointer API pages.

## Not verified

- No build or test of the app: none was needed for documents, and a
  cloud thread cannot run one. CI is the build.
- The privacy check ran without the private list, which this thread does
  not have, so it checked the built-in patterns only.
- Graphify's one review per pull request was counted on #112, #114, #116,
  #117 and #119 only.

## Follow-ups

- **Two lines of docs/EXPERIMENTS.md**, one each in SIM-2 and SIM-3, still
  name a step of planning kept outside the repository. They are left as
  they were, because pull request #115 changes the lines next to them;
  #115, or the next change to the run sheet after it merges, words them
  like the rest.
  *(#115's thread)*
- **The website's accessibility page** (`site/accessibility/index.html`)
  uses British spellings, 12 words on 12 lines: "colours" twice under
  *Contrast, Dark Mode and Increase Contrast*; "neighbouring" and
  "colour" under *Show Borders*; "colour" in the heading *Not by colour
  alone* and its text; "colour" and "colours" under *Get Attention and
  Stop*; and "coloured", "centre" twice and "colour" under *Known limits
  today*. They become "colors", "neighboring", "color", "colored" and
  "center" with the next change to the website. *(the next website
  change)*
