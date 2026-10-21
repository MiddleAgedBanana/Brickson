# App Store readiness and search text

*2026-10-21. Pull request #18 (`claude/project-thread-oxz0iu`). App Store
readiness and ASO thread.*

## What changed and why

- **`docs/APP-STORE.md`** (new): everything App Store Connect will ask for
  Brickson, read from Apple's current pages, with the owner's checklist in
  order: the name and bundle ID, membership, distribution and
  availability, the app record, App Information (including the Digital
  Goods and Services questionnaire), App Privacy, agreements, EU trader
  status, TestFlight (including Beta App Review contact details), the
  version page, Accessibility Nutrition Labels and App Review notes.
  Section 3 checks each sentence of the privacy policy against the build.
  Section 13 lists the changes the app itself needs and which thread owns
  each.
- **`docs/ASO.md`** (new): keyword and competitor research for the US, UK,
  Australian and Canadian stores, and drafts of the name, subtitle,
  keywords, promotional text, description, screenshot captions and app
  preview. Every claim about something not built yet is tagged
  `[needs: …]`, and no draft states a price.
- **`docs/DECISIONS.md`**: two defaults, "App Store category" (Utilities,
  no secondary) and "Age rating answers" (all No or None, 4+).
- **`site/privacy/index.html`**: the settings line listed a text-size
  setting the app does not have; it now says "the voice and speaking speed
  you chose". Effective date moved to October 21, 2026.
- **`docs/HANDOFF.md`**: the policy's Effective date, and pointers to
  APP-STORE.md from *Known gaps* and *Next steps*.

The App Store listing has to be true to the build that is submitted, and
the owner is new to App Store Connect. Gathering Apple's requirements now
lets the other threads build what review needs (the Privacy row, the
review notes, accessibility evidence) before release, not after a
rejection.

## Commits

- `e03c427`: the privacy policy's settings line and Effective date.
- `46a87c9`: APP-STORE.md, ASO.md, the two decisions and this record.
- `cb3dab9`, `4816eeb`, `046a69c`, `38f22f8`: fixes from four rounds of
  Codex review (a personal name in the bundle ID example, distribution and
  availability, TestFlight contact fields, the Duo screenshot condition,
  no live Xcode or SDK versions, the Digital Goods questionnaire, untagged
  claims about voice choice and profiles, the name status, the membership
  type, and the policy's settings sentence).
- `f7382df` and the merge after `38f22f8`: `main` merged in (PRs #12, #13,
  #15).

## Verified

Documentation and one HTML sentence; no Swift changed. GitHub CI ran the
unit and UI tests on the pull request. `scripts/test-site.py`,
`scripts/test-select-xcode.py` and `scripts/test-runner.py` passed on the
cloud machine. Apple's pages were read on 2026-10-21, and each claim cites
its page. Keyword and competitor results came from Apple's public search
API the same day. Character and byte counts of the store text were
measured with a script. Nothing was created or changed in App Store
Connect.

## Not verified

- Trademark registers outside the US (TMview blocks automated searches).
- US state age-assurance dates beyond Texas were found once and not
  checked twice; a lawyer's view is suggested in APP-STORE.md, section 6.
- Every accessibility label and every "works with" claim waits for the
  device checks in docs/HANDOFF.md, *Checks that need a real device*.

## Follow-ups

- A `site/accessibility/` page for the product page's Accessibility URL
  (App Store readiness and ASO, with the website).
- Before release, delete the policy sections for features 1.0 does not
  ship, and mark each row of APP-STORE.md, section 3, true or deleted.
- Screenshots and the app preview wait for Home version 1, typing,
  Settings and profiles (ASO.md, *Screenshots*).
