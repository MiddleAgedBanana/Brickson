# Copilot instructions for Brickson

Brickson is an iPhone and iPad app that speaks for people living with
ALS. A person chooses a phrase or types, and the app says it aloud. The
people using it may be unable to speak or move, so a bug can leave someone
with no way to ask for help. Correctness and accessibility come before
performance and elegance.

`AGENTS.md` in the repository root is the briefing for every agent and
reviewer here, Copilot included. Review pull requests against its
"Non-negotiable invariants" and "Code Review Rules" sections. If this file
and `AGENTS.md` ever disagree, `AGENTS.md` wins.

## Reviewing pull requests

- When reviewing pull requests, use the code-review skill at
  `.github/skills/code-review/SKILL.md`.
- Put first anything that could stop a person communicating: a phrase that
  needs more than one activation to speak, Emergency, Get Attention, Yes or
  No out of reach, a crash, a failure nobody can see or hear, or a person's
  words lost. Accessibility comes next, then everything else.
- Name the `AGENTS.md` invariant or rule a finding breaks, and show the
  path from a real input to the failure. A change that "Code Review Rules"
  names is a finding even when no person is affected yet; for any other
  suspicion you cannot trace, ask a question instead of reporting a bug.
- Don't comment on formatting or naming alone.
- Write plainly. The owner is new to programming.

## Facts that prevent wrong suggestions

- Swift 6 and SwiftUI, iOS and iPadOS 26 or later, Apple's frameworks only.
  Never suggest a package, an SDK or a network service.
- `Brickson.xcodeproj` is generated from `project.yml` by XcodeGen and is
  not committed. Changes go in `project.yml`.
- Don't try to build or run the app: your review machine runs Linux, and
  Xcode needs a Mac. The build is the Tests workflow
  (`.github/workflows/tests.yml`), which runs the unit and UI tests on
  GitHub's Mac machines for every pull request.
- Words people see go through the String Catalog. Phrase and category names
  are a person's own words: shown with `Text(verbatim:)`, never translated
  or reworded.
- The repository is public. Flag names, email addresses, and health or
  family details in any committed file, except the developer's name and
  support email on the website pages in `site/`, which Apple requires, and
  the short founder note the owner authorized in `README.md` and
  `site/index.html` (with its record in `docs/DECISIONS.md` and the
  handoff), exactly as `AGENTS.md`, *Data, privacy and platform*,
  describes it.
