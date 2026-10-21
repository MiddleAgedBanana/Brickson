# 2026-10-21: App Store readiness and search text

## What changed

- **`docs/APP-STORE.md`** (new): everything App Store Connect will ask for
  Brickson, read from Apple's current pages, with an owner's checklist in
  order: name and bundle ID, membership, the app record, App Information,
  App Privacy, agreements, EU trader status, TestFlight, the version page,
  Accessibility Nutrition Labels and App Review notes. Section 13 lists the
  changes the app itself needs and which thread owns each.
- **`docs/ASO.md`** (new): keyword and competitor research for the US, UK,
  Australian and Canadian stores, and drafts of the name, subtitle,
  keywords, promotional text, description, screenshot captions and app
  preview. No draft states a price.
- **`docs/DECISIONS.md`**: two defaults, "App Store category" (Utilities,
  no secondary) and "Age rating answers" (all No or None, 4+).
- **`site/privacy/index.html`**: the settings line listed a text-size
  setting the app does not have; it now says "the voice and speaking speed
  you chose". Effective date moved to October 21, 2026.

## Why

The App Store listing has to be true to the build that is submitted, and
the owner is new to App Store Connect. Gathering Apple's requirements now
lets the other threads build what review needs (the Privacy row, review
notes, accessibility evidence) before release, not after a rejection.

## How it was checked

Docs only; nothing was built or run, and no Swift changed. Apple's pages
were read on 2026-10-21 and each claim cites its page. Keyword and
competitor results came from Apple's public search API on the same day.
Character and byte counts of the store text were measured with a script.
Nothing was created or changed in App Store Connect.

## Not checked

- Trademark registers outside the US (TMview), which block automated
  searches.
- US state age-assurance dates beyond Texas were found once and not
  checked twice; a lawyer's view is suggested in APP-STORE.md, section 6.
- Every accessibility label and every input-method claim waits for a real
  device check before it is declared or written into the description.
