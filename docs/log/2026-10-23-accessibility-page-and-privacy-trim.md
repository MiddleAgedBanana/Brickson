# The website's accessibility page, and the privacy policy's trim

*2026-10-23. Pull request #40 (`claude/project-thread-wzgid4`). The
"Website accessibility page and privacy trim" thread, a cloud session
that cannot build or run the app.*

## What changed and why

The two website follow-ups of PR #18's record
([`2026-10-21-app-store-and-aso.md`](2026-10-21-app-store-and-aso.md),
*Follow-ups*). Decision: docs/DECISIONS.md, "The website's accessibility
page and the policy's trim" (new).

- **A new page, `site/accessibility/index.html`**, live at
  https://middleagedbanana.github.io/Brickson/accessibility/ once merged.
  It is the Accessibility URL App Store Connect asks for
  (docs/APP-STORE.md, section 4): Apple's Accessibility Nutrition Labels
  have no place for Switch Control, Eye Tracking, Head Tracking, Full
  Keyboard Access or AssistiveTouch, so this page is where a family
  choosing an app for one of them looks. It says, in plain words, what is
  in place today for each input method (touch, VoiceOver, Voice Control,
  Switch Control and Full Keyboard Access, AssistiveTouch with Dwell, Head
  Tracking and Eye Tracking), for reading (Larger Text and Bold Text,
  contrast, Show Borders, not by colour alone, Reduce Motion, Per-App
  Settings), for speech (Personal Voice, a phrase that is cut off) and for
  Get Attention (the alarm, Stop, and when it fails),
  each with how it was checked. Only rows docs/ACCESSIBILITY.md marks *In
  place* are described. Its first lines say that nothing has been checked
  on a real iPhone or iPad, and *Known limits* names what a family would
  meet today (from docs/HANDOFF.md, *Known gaps*). It names no planned
  feature and states no price.
- **Linked from every page**: an "Accessibility" link in each page's
  header, and on the home page a short section, after *Our approach*, in
  the founder note's layout. On phones the header's links now wrap with no
  extra gap between rows; each link keeps its 44-point height.
- **The privacy policy, trimmed.** The sections "If you turn on recorded
  phrases", "If you turn on caregiver alerts" and "If you use Siri and
  Shortcuts" are deleted, because R0, the first release, ships none of
  them (docs/ROADMAP.md, *Left out of R0 on purpose*; docs/APP-STORE.md,
  section 3, "Delete the section for 1.0"). Sentences that leaned on
  them changed: the summary's "such as backups you make and features you
  choose to use" is now "such as backups you make and emails you send
  us"; the Emergencies paragraph's "Only Get Attention can alert a
  caregiver's device, and only if you turn on caregiver alerts" became
  "They never call emergency services or send anyone a message"; and
  *Your choices* now names the optional features left ("such as Personal
  Voice and backups"). "Brickson works with Apple's accessibility
  features, such as Eye Tracking, Switch Control and Voice Control" became
  "If you use Apple's accessibility features, such as Eye Tracking, Switch
  Control or Voice Control, iOS runs them": no device check has been done
  (APP-STORE.md, section 3), and the accessibility page is where what is
  checked is said. Effective date: October 23, 2026. The app shows the
  same file inside Settings (docs/DECISIONS.md, "The privacy policy ships
  inside the app"), so the in-app copy changed with it.
- **Tests** (`scripts/test-site.py`, run by CI's unit job): every page
  links to the accessibility page through a real `href` (read by an HTML
  parser, so a `data-href` or a link within the page does not count); no
  page says "free" or "paid"; every
  page has a language, a title, a viewport, one `h1`, one `main`, and a
  skip link that lands on it.
- **Docs**: AGENTS.md (*Where things are* and *The privacy policy is a
  promise*), docs/DECISIONS.md, docs/APP-STORE.md (sections 1, 3, 4 and
  13), docs/ACCESSIBILITY.md (the Accessibility URL row, the App Shortcuts
  row, *Keeping this list current*), docs/ROADMAP.md (item 10 and two R2
  lines that cited the deleted Siri and caregiver sections), docs/HANDOFF.md
  and README.md.

### The deleted sections, word for word

Kept here so the pull request that ships one of these features starts
from them (AGENTS.md, *The privacy policy is a promise*). They are what
`site/privacy/index.html` said before this change. The Siri section
describes Siri saying the person's own phrases and iOS seeing their
words, which R2's plan no longer allows (fixed phrases only, no phrase
words in App Shortcuts): rewrite it to match what ships.

```html
<h2 id="if-you-turn-on-recorded-phrases">If you turn on recorded phrases</h2>
<p>Brickson uses the microphone only while you record a phrase, and only after you allow it. While it records, Brickson shows that it is recording, and iOS shows its own indicator. Recordings are saved on your device with your phrases and are included in backups you export. They are never sent to us. You can turn off microphone access in Settings &gt; Privacy &amp; Security &gt; Microphone. That stops new recordings; recordings you already made stay until you delete them in Brickson.</p>
<h2 id="if-you-turn-on-caregiver-alerts">If you turn on caregiver alerts</h2>
<p>Caregiver alerts are off until you turn them on. When they are on, Get Attention also sends an alert to Brickson on a caregiver's iPhone or iPad. This works only while both devices are on the same local network, such as your home Wi-Fi. An alert can fail to arrive, so don't rely on it alone.</p>
<ul>
<li>iOS asks your permission before Brickson can use your local network.</li>
<li>The alert says that you need attention, and shows the name you gave this device in Brickson.</li>
<li>It goes straight from your device to the caregiver's device, encrypted. It never goes over the internet, and we cannot see it.</li>
<li>To find each other, the two devices announce Brickson on the network. Other devices on the same network can see that Brickson is there, but not your name.</li>
<li>To stop, turn caregiver alerts off in Brickson, or turn off Brickson's switch in Settings &gt; Privacy &amp; Security &gt; Local Network. Brickson still speaks either way.</li>
</ul>
<h2 id="if-you-use-siri-and-shortcuts">If you use Siri and Shortcuts</h2>
<p>You can ask Siri to say one of your phrases, or use your phrases in the Shortcuts app. To make this work, Brickson lets iOS see the words of your phrases. When you use Siri, it may send your request, and details such as shortcut names, to Apple. Apple handles that, including whether it is used to improve Siri, under its <a href="https://www.apple.com/legal/privacy/data/en/ask-siri-dictation/">Siri privacy policy</a>. We never receive it. Shortcuts you make stay in the Shortcuts app, even after you delete Brickson, until you delete them there.</p>
```

## Commits

- `a32344c`: the website tests, first, failing until the page exists.
- `59ca4df`: the accessibility page, the home page's section, the header
  links and their styles.
- `f97b03d`: the privacy policy's trim and Effective date.
- The commit after it: this record, and the AGENTS.md, DECISIONS,
  APP-STORE, ACCESSIBILITY, ROADMAP, HANDOFF and README lines.
- A merge of `main` (PR #37), then the review fix: CodeRabbit found that
  the link test's pattern also matched `data-href`, which no visitor can
  follow; it now reads each anchor's `href` with an HTML parser.
- A merge of `main` (PR #38, Get Attention and Stop on Home), `6bb430a`,
  keeping `main`'s Get Attention row in docs/APP-STORE.md, section 3. Then
  the lines #38 made untrue or incomplete here: the accessibility page
  names Get Attention and Stop, with Home's new order, names, audit and
  known limits, each with how it is checked; docs/ACCESSIBILITY.md's audit
  row adds Home while Get Attention sounds; Get Attention leaves the list
  of policy sentences not yet true, in docs/DECISIONS.md and
  docs/HANDOFF.md; and the follow-up for the page is done.

## Verified

Website and documents only; no Swift changed. On the cloud machine:

- `python3 scripts/test-site.py` passed (7 tests). Before the page
  existed, the new link test failed ("site/accessibility/index.html is
  missing"). The changes that would make each new test fail: removing a
  page's Accessibility link, the word "free" on any page, or a page
  without `lang`, a title, one `h1`, one `main` or a skip link to it.
  After the review fix, two edits were tried and each made the link test
  fail: the policy's Accessibility link changed to `data-href`, and the
  accessibility page's own header link removed (its links within the
  page no longer count).
- The three pages, served with `python3 -m http.server`, were rendered in
  Chromium (Playwright) at 1280, 1000 and 390 points wide, light and dark:
  no page scrolls sideways, the home page's new section matches the
  founder note's layout, and the headers wrap cleanly on a phone.
- Every sentence of the accessibility page and of the trimmed policy was
  checked by three independent read-only reviews: one against the code
  and tests on this branch before PR #38 was merged into it (file and line
  for each claim), one against Apple's pages for each feature's name and
  Settings path (Apple's iPhone and iPad User Guides for iOS 27, the
  Human Interface Guidelines, and
  `performAccessibilityAudit`, whose default includes a contrast check),
  and one adversarial review of the trim. What they found was fixed
  before the pull request: the audits' real coverage (light and dark on
  Home, Settings' first screen, Family Setup and the privacy policy;
  light only on the emergency phrases and Voice Settings; none yet on
  Settings' guides, Set Up Step by Step or About, now also in
  docs/ACCESSIBILITY.md's audit row); the message's place in the order;
  the check mark that a label drops when room is short; Bold Text not yet
  measured on phrase tiles; the screenshot read-back at the largest size
  only; a chosen voice taking priority over a Personal Voice; Apple's name
  "Dwell Control"; the wider scrolling limit; and checks that are a
  reading of the code, not a test.
- GitHub CI on the pull request: the unit job runs `scripts/test-site.py`
  and `PrivacyPolicyDocumentTests` (the in-app copy loses no word of the
  trimmed page); the UI job opens the policy in Settings (`SettingsTests`).
  The run's result is in the pull request. Its first complete run, on
  `f0af640`, passed every unit test and the iPhone's 37 UI tests; on the
  iPad, one test failed before its body ran: the test runner could not
  close the app left by the test before it ("Failed to terminate",
  `HomeAccessibilityOrderTests`, the largest-text case), a test this pull
  request does not touch. The merge of PR #38 started a new run.
- After the merge of PR #38, on the cloud machine:
  `python3 scripts/test-site.py` passed again (7 tests), and every
  sentence the merge changed on the accessibility page was read again
  against #38's code and tests (`GetAttentionOnHomeTests`,
  `HomeAccessibilityOrderTests`, `HomeReachabilityTests`,
  `HomeShapeTests`, `ControlNamesTests`; docs/DECISIONS.md, "Get
  Attention and Stop on Home"), with the file and line for each claim, by
  two read-only checks and a third that tried to refute what they
  proposed.

## Not verified

- The pages as GitHub Pages serves them: they publish only after the
  merge. Check https://middleagedbanana.github.io/Brickson/accessibility/
  and the policy's Effective date once the "Publish website" run is green.
- The pages with VoiceOver, Voice Control or a switch, and in Safari on
  an iPhone or iPad: rendered in Chromium only.
- The in-app policy screen with the trimmed text was not looked at; CI's
  UI tests open it and audit it.
- Whether Settings > Accessibility > Personal Voice lets a person stop
  one app, as the policy's Personal Voice section says (unchanged here):
  Apple's pages read on 2026-10-23 document only Allow Apps to Request to
  Use, the switch for every app.
- Every claim on the accessibility page rests on simulator tests or the
  code; nothing has run on a device (docs/HANDOFF.md, *Checks that need a
  real device*).

## Follow-ups

- **Each device check** adds its device, iOS version and date to the
  accessibility page, and a row that becomes true there (AGENTS.md, *Where
  things are*). *(whoever records the check)*
- **Typing on Home** updates the policy's "it only learns which button
  you chose" to cover words typed and dictated, and says that Apple
  handles Dictation under its own policy. *(the typing thread)*
- **App Store Connect**: enter the Accessibility URL when the version
  page is filled in (docs/APP-STORE.md, section 1, step 13). *(owner)*
- `.github/workflows/pages.yml`'s opening comment lists two pages; it
  could name the third. Cosmetic, and only the owner can commit workflow
  files. *(owner, optional)*
