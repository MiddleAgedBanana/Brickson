# App Store readiness

Everything the App Store will ask of Brickson, what Brickson should answer,
and what has to be true in the app first. Store search and the store text
itself are in [ASO.md](ASO.md).

Researched on 2026-10-21 from Apple's own pages, linked in each section.
Apple changes these pages often: re-read a page before acting on it, and
update this file when it has changed.

**Status.** Nothing exists in App Store Connect for Brickson yet, and nothing
is created there until the owner confirms the name (docs/DECISIONS.md, "App
identity"). The price is not decided, so nothing here states one
(docs/DECISIONS.md, "Price not decided"). Brickson is a working name; every
draft below works with another name dropped in.

**Who does what.** App Store Connect is a website only the owner can use: the
owner creates the app record, answers the questionnaires, uploads builds and
submits. Agents prepare every answer and every piece of text here, so each
step is copy and paste. Section 1 is the owner's list, in order.

## 1. The owner's checklist, in order

Each step says what it is and why before how. Nothing in steps 1 to 4 is hard
to undo; step 5 is, so it waits for the name.

1. **Confirm the name.** The App Store name is held by whoever creates the
   record first, and a released app keeps its bundle ID forever. Brickson
   looked available on 2026-10-12 (docs/NAME_AVAILABILITY.md); only creating
   the record confirms it.
2. **Choose the permanent bundle ID.** The bundle ID is the app's internal
   name, like `org.example.app`. Customers never see it, but it is public,
   it can never change after the first upload, and today's
   (`APP_BUNDLE_ID` in `project.yml`) contains a personal name. Pick one you are happy
   to keep forever (for example built from a web address you own, or a
   neutral word), and an agent changes `APP_BUNDLE_ID` in `project.yml`.
3. **Check your membership.** Sign in at
   [developer.apple.com/account](https://developer.apple.com/account) →
   Membership details. Check that it says Individual, that the legal name
   shown is one you are happy to have under the app (individuals can't choose
   another), and that auto-renew is on: if the membership lapses, the app
   leaves the store. Copy the **Team ID** from that page and give it to an
   agent for `DEVELOPMENT_TEAM` in `project.yml` (it is not secret).
4. **Decide the price** (docs/DECISIONS.md, "Price not decided"). App Store
   Connect asks for it under Pricing and Availability, and the agreements in
   step 8 depend on it. On the same page, before submitting: keep the
   distribution method **Public** (an app approved for Private distribution
   can never become public), choose the countries and regions (all, unless
   there is a reason not to), confirm the tax category Apple suggests, and
   turn off Mac and Apple Vision Pro availability (section 4)
   ([publishing
   overview](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store),
   [distribution
   methods](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods)).
5. **Register the bundle ID and create the app record** (only after steps 1
   and 2). In [Certificates, Identifiers &
   Profiles](https://developer.apple.com/account/resources/identifiers/list):
   Identifiers → + → App IDs → App → Explicit, enter the bundle ID. Then in
   [App Store Connect](https://appstoreconnect.apple.com) → Apps → + → New App:
   platform iOS (one record covers iPhone and iPad), the name, primary
   language English (U.S.), the bundle ID, and a private SKU such as
   `brickson-001` (letters, numbers, hyphens, periods and underscores; it can't
   change later). If the name is refused, see
   [ASO.md, *If the name is taken*](ASO.md#if-the-name-is-taken).
   ([Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app))
6. **Fill in App Information** (once, for every version), pasting from this
   file: subtitle ([ASO.md](ASO.md#the-store-text)), category (section 5),
   content rights (Brickson shows no third-party content: answer No), age
   rating (section 6), and the privacy policy URL
   `https://middleagedbanana.github.io/Brickson/privacy/`. If the **Digital
   Goods and Services** questionnaire appears, answer it after the price
   decision (step 4): with nothing sold or unlocked inside the app, the
   answer to "Can customers consume digital goods and services in this
   app?" is No. The answers for the European Union lock for 12 months once
   saved
   ([questionnaire](https://developer.apple.com/help/app-store-connect/manage-app-information/complete-the-digital-goods-and-services-questionnaire)).
7. **Answer App Privacy:** "No, we do not collect data from this app", then
   Publish (section 7).
8. **Agreements, tax and banking** (App Store Connect → Business). Which
   agreement and forms apply depends on the price decision in step 4.
9. **Declare EU trader status** (section 11). This is your own legal
   self-assessment; until it is done the app can't be offered in the EU.
10. **Upload a build** from your Mac (Xcode → Product → Archive → Distribute
    App → App Store Connect). An agent prepares the build settings first;
    `CURRENT_PROJECT_VERSION` must go up with every upload.
11. **Test with TestFlight** (section 12): first yourself, then a few people
    living with ALS, family members and a speech-language pathologist.
12. **Fill in the version page,** pasting from [ASO.md](ASO.md): screenshots
    (section 9), promotional text, description, keywords, support URL
    `https://middleagedbanana.github.io/Brickson/`, copyright (the year and
    your legal name, for example "2027 Your Name"; Apple adds ©), and App
    Review information: your name, email and phone (the phone in
    international form, such as +1 555 555 0100), no sign-in, and the notes
    in section 8.
13. **Save draft Accessibility Nutrition Labels** for iPhone and iPad
    (section 4), and add the Accessibility URL if the page exists.
14. **Submit for review** with *Manually release this version*, so nothing
    goes live until you press Release.
15. **After release:** publish the accessibility labels (Apple only allows it
    once a version is live), check the product page on a phone, and put the
    membership renewal date in your calendar.

## 2. Before anything is submitted

The project's release gate holds every external TestFlight build and every
App Review submission until the first release's work is done: today that is
docs/HANDOFF.md, *Next steps* and *Checks that need a real device*, and the
roadmap (docs/ROADMAP.md, when the roadmap's pull request lands) will name it
R0. The App
Store adds these hard requirements, checked against Apple's pages on
2026-10-21:

| Requirement | Brickson today | Source |
|---|---|---|
| Built with the Xcode and SDK that Apple's *Upcoming requirements* page names (when checked on 2026-10-21, it named the release and SDK required since 2026-04-28) | CI and the Mac use the current Xcode (docs/DECISIONS.md, "Build with Apple's current Xcode") | [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) |
| Approved reasons for "required reason" APIs in a privacy manifest (since 2024-05-01) | `PrivacyInfo.xcprivacy` declares UserDefaults reason CA92.1, no tracking, no collected data; `AppBundleTests` pins it | same |
| Answers to the updated age-rating questions (since 2026-01-31) | Drafted in section 6 | same |
| A privacy policy URL, and a link inside the app "in an easily accessible manner" | The URL exists; **the in-app link does not yet** (Settings and first run thread) | [Guideline 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) |
| A support URL that "must lead to actual contact information" | The support page has the contact email | [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) |
| Final versions only: "placeholder text, empty websites, and other temporary content should be scrubbed"; tested on a device | Home is a stand-in, the icon a placeholder, and nothing has run on a device yet | [Guideline 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness) |
| Enough lasting use to be "app-like" | A stand-in Home would risk this; R0 fixes it | [Guideline 4.2](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality) |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in `project.yml` skips the question on every upload | `project.yml` |
| At least one iPhone and one 13-inch iPad screenshot | Plan in section 9 | [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) |

## 3. The privacy policy must match the build

The public policy (`site/privacy/index.html`) is a promise App Review and
privacy law hold the app to, and it describes some features that are not
built yet. Before a build is submitted, every row below must say **true** or
**deleted**, with the page's Effective date and the in-app copy updated in
the same pull request (AGENTS.md, *The privacy policy is a promise*). The
policy also promises that an update's notes will mention a policy change, so
say so in What's New when it happens.

| Policy sentence or section | True of the build? | Before submitting |
|---|---|---|
| Phrases and categories saved on the device | Yes | — |
| "The message you are typing… stays until you clear it" | No: no typing yet | Ship typing with a kept draft, or delete the line |
| "Your settings, such as the voice and speaking speed you chose" | Yes (`SpeechService` stores both) | Fixed on 2026-10-21: the policy no longer mentions a text-size setting, which Brickson does not have |
| Deleting things "in the app" | Not until editing ships | Ship editing, or reword |
| Speech and Personal Voice | Yes | — |
| How you control the app ("works with … Eye Tracking, Switch Control and Voice Control") | The data half is true: Brickson has no input code of its own, so it never receives what those features use. "Works with" is **not yet verified**: nothing has run on a device | Reach every control with each named method on a real iPhone and iPad (docs/HANDOFF.md, *Checks that need a real device*), or reword to "is built to work with" |
| Backups you export | No: no backup yet | Ship backup, or delete the paragraph |
| Your device's own backups (iCloud Backup) | Yes | — |
| If you turn on recorded phrases | Not built; not in R0 | Delete the section for 1.0 |
| If you turn on caregiver alerts | Not built; needs network code, which invariant 9 forbids until the owner decides | Delete the section for 1.0 |
| If you use Siri and Shortcuts | Not built; not in R0 | Delete the section for 1.0 |
| Get Attention | Not until the Speech engine and Get Attention thread lands it | Ship it, or delete the mention |
| Effective date | October 21, 2026 | Move it with every wording change |

## 4. Accessibility Nutrition Labels

**What they are.** A section on the product page where the developer ticks
which of nine accessibility features the app supports, separately for iPhone
and iPad. They show on devices running iOS or iPadOS 26 and later. Apple
says: "Providing Accessibility Nutrition Labels is voluntary for now", and
that they will be required for new apps and updates "over time", with no date
announced as of 2026-10-21
([overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).

**Why they matter more for Brickson than for most apps.** They are the first
thing a family comparing AAC apps can check, and Apple says App Store search
uses them: when a search names a feature, apps that declared it rank as more
relevant. Most AAC competitors have declared nothing (ASO.md, *Competitors*).

**The rule for ticking one.** A person must be able to complete every
"common task" with that feature. Common tasks are the app's main jobs plus
first launch, login, purchase (only if the app sells something) and
settings, including leaving settings without changing anything. There is no
"not applicable": a feature that doesn't apply is left unticked. Don't tick a
feature while a known bug breaks it; App Review can ask for misleading labels
to be fixed. Re-check at every update.

**When.** Answers can be saved as a draft while 1.0 is being prepared, and
published only once a version is live
([manage labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels)).

**Brickson's common tasks for 1.0** (from the release gate in section 2): first launch
(including the Personal Voice question), speak a phrase, Yes and No,
Emergency, Again, Get Attention and Stop Alert, type and speak, edit phrases
(with delete and keep), back up and restore, Settings (voice, privacy, family
setup) and leaving Settings.

| Feature (Apple's criteria) | What has to be true for Brickson | Evidence needed before ticking | Proposed at 1.0 |
|---|---|---|---|
| [Sufficient Contrast](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria): text about 4.5:1, controls 3:1 by default | Invariant 6 already demands it, in light, dark and Increase Contrast, including system components | Every colour pair on every 1.0 screen pinned in `PaletteTests`; a rendered check (Test seams thread) | Yes, once evidence covers every screen |
| [Dark Interface](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria): every common task stays dark in Dark Mode | Colour assets need dark variants; the launch screen already follows the system | UI tests in dark appearance on every screen | Yes, once evidence covers every screen |
| [Differentiate Without Color Alone](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria) | Selected states use a symbol or text as well as colour (the selected category already shows a check mark) | A Grayscale walk-through of every screen | Yes |
| [Larger Text](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria): text grows to at least 200% without overlap or severe truncation | Words never break and never render below their default size (AGENTS.md); phone labels clip at the largest sizes today | UI tests at AX3 and AX5 on iPhone and iPad, screenshots checked by a person | Yes, once the Phone layout and word fitting work lands |
| [Reduced Motion](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria): no problematic motion, or it is replaced when Reduce Motion is on | Get Attention's visual state must not flash or blink; any animation respects Reduce Motion | A review of every animation and symbol effect | Yes |
| [VoiceOver](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria): every common task with VoiceOver alone; Apple asks for skilled testing on every device type | Standard buttons with labels; announcements for audio problems | A skilled VoiceOver run of every task on a real iPhone and a real iPad, logged in `docs/log/` | Only after that run |
| [Voice Control](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-evaluation-criteria): every common task by voice alone; names match visible text; text fields accept dictation | Standard buttons; input labels, if added, start with the visible text | A Voice Control run of every task on a real iPhone and iPad | Only after that run |
| [Captions](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/captions-evaluation-criteria): Apple also accepts "text transcripts of audio-only content, such as… spoken dialogue" | Every phrase Brickson speaks is already shown as text in the message row; every other sound (Get Attention, voice samples) would need visible text too | A check that no sound plays without matching text | Candidate; decide when Get Attention and the voice picker land |
| [Audio Descriptions](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/audio-descriptions-evaluation-criteria): narration of on-screen video | Brickson has no video | — | No |

**Input methods without a label.** Switch Control, Eye Tracking, head
tracking, Full Keyboard Access and AssistiveTouch have no label. Apple's
answer is an optional **Accessibility URL** on the product page, linking to
the developer's own accessibility page. An accessibility URL added before the
first release goes live with it. Proposed: a `site/accessibility/` page that
says, for each input method, what was tested, on which device, and when, and
says plainly where only simulator evidence exists. Until the device checks
in docs/HANDOFF.md are done, the page and the description say "works with"
only for what was checked.

**Mac and Apple Vision Pro.** iPhone and iPad apps are offered on Apple
silicon Macs and Apple Vision Pro unless the developer turns that off in App
Store Connect, and the iPhone and iPad labels would show there too
([availability on Vision
Pro](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)).
docs/DECISIONS.md keeps Mac and Vision Pro off for now, so turn both off in
Pricing and Availability.

## 5. Category

**Decided default (2026-10-21): primary Utilities, no secondary category**
(docs/DECISIONS.md, "App Store category"). Apple's definitions
([Choosing a category](https://developer.apple.com/app-store/categories/)):

- **Utilities:** "Apps that enable the user to solve a problem or complete a
  specific task." Speaking for someone is that.
- **Medical:** "focused on medical education, information management, or
  health reference for patients or healthcare professionals". Brickson is
  none of these.
- **Health & Fitness:** "healthy living, including stress management,
  fitness, and recreational activities". Not Brickson.
- **Education:** "an interactive learning experience on a specific skill or
  subject". Most AAC apps for children choose it (ASO.md), but Brickson
  teaches nothing.

Why Utilities, and why no secondary:

1. **Honesty.** Guideline 2.3.5: "Select the most appropriate category… If
   you're way off base, we may change the category for you."
2. **No medical-device declaration.** Since 2026-03-26, an app offered in
   the US, UK or EEA whose primary *or secondary* category is Medical or
   Health & Fitness must declare whether it is a regulated medical device,
   and the answer shows on the product page
   ([App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information),
   [Declare regulated medical device
   status](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status)).
   For a speech aid that answer is not simple: US rules describe "powered
   communication systems" as a device class, and EU guidance names
   communication software as an example. Utilities keeps Brickson out of a
   legal question an individual developer should not answer alone.
3. **Guideline 5.1.1(ix).** Apps "in highly regulated fields (such as…
   healthcare…)" should come from a legal entity, not an individual. Brickson
   provides no healthcare service, and a non-medical category keeps that
   clear.
4. **Discovery barely depends on it.** People find AAC apps by searching, not
   by browsing a category (ASO.md). Successful individual developers' AAC
   apps sit in Utilities (Talk For Me, SimpleSpeak AAC).
5. **Not Entertainment or Games:** apps in those categories fall under
   parents' Time Allowances in iOS 27.

## 6. Age rating

**What it is.** Every app answers a questionnaire in App Store Connect (App
Information → Age Ratings), and Apple computes the rating. The tiers are 4+,
9+, 13+, 16+ and 18+; an Unrated app can't be published. Apple also computes
ratings for Australia, Brazil, Korea and Vietnam
([values and
definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions),
[set a rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)).
Guideline 2.3.6 asks for honest answers.

**Answers for 1.0, default adopted 2026-10-21** (docs/DECISIONS.md, "Age rating answers"):

| Question | Answer | Why |
|---|---|---|
| Parental Controls | No | Edit mode protects phrases; it does not restrict a child |
| Age Assurance | No, unless the age-assurance work below ships in 1.0 (then Yes; still 4+) | — |
| Unrestricted Web Access | No | The planned Privacy row shows the policy inside the app; if it opens the web version, keep that page's links minimal |
| User-Generated Content | No | Phrases are never shared or published |
| Social Media | No | — |
| Messaging and Chat | No | Brickson speaks aloud; it sends nothing to other users (re-answer if caregiver alerts are ever built) |
| Advertising | No | Invariant 9 |
| Profanity or Crude Humor; Horror or Fear; Alcohol, Tobacco or Drugs | None | Starter phrases contain none (invariant 7) |
| **Medical or Treatment Information** | **None** | Apple means content that "provides diagnoses or guidance on managing medical conditions". Phrases such as "I need my medication." or "I can't breathe." are the person's own words to the people nearby, not guidance. Infrequent would make the app 13+; Frequent 16+ plus the medical-device declaration |
| Health or Wellness Topics | No | No self-care or lifestyle advice |
| Mature or Suggestive Themes; Sexual Content; Graphic Sexual Content | None | — |
| All four violence questions | None | — |
| Gambling; Simulated Gambling; Contests; Loot Boxes | No / None | — |
| Age categories and override | Not Applicable (not Made for Kids, no override) | Made for Kids can never be undone once approved |
| Age Suitability URL | Blank | — |

**Expected result:** 4+ everywhere (Brazil AL, Korea All, Vietnam 00+).
Re-answer whenever a starter phrase set, an in-app web view or caregiver
alerts change what the app contains.

**Age-assurance laws: needs a decision before 1.0 in the US.** Apple says
developers "are responsible for their own age restrictions" and that, where
the law requires it, "you must check the age of the people using your app"
with the Declared Age Range API; App Review does not check this
([Apple: age assurance](https://developer.apple.com/support/age-assurance/)).
Apple announced on 2026-06-03 that Texas law SB 2420 now applies to new Texas
Apple Accounts ([Apple news](https://developer.apple.com/news/?id=sg176nne)).
Research found California's law starting on 2027-01-01 and Utah's and
Louisiana's developer duties in 2027, and no exemption for apps without
accounts or purchases; those dates came from state sources and were not
checked twice. Two things follow:

- **The owner may want a lawyer's view** on whether Brickson must use the
  API, because Apple says compliance is the developer's own responsibility.
- **Any age check must never get in the way of speaking.** Apple's system
  sheet, or a parental-consent block for a "significant update", must never
  cover Emergency, Yes, No or Get Attention, and must never stop someone
  communicating (invariants 2 and 10). If it is needed, the proposed shape is
  a check in Settings or first run, never on Home, built by the Settings and
  first run thread. This is listed in the roadmap's decision register.

## 7. App Privacy (the privacy "nutrition label")

**Answer:** "No, we do not collect data from this app", then Publish.

Apple's definition: data is "collected" when it is transmitted off the
device in a way that lets the developer or a third party access it for longer
than needed to service the request in real time
([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).
Brickson has no network code, so nothing it holds leaves the device through
Brickson. What keeps the answer true:

- No network code, analytics, crash SDK or third-party package (invariant 9).
- SwiftData opens with `cloudKitDatabase: .none` and the app has no iCloud
  capability.
- A backup file the person exports is moved by the person, to a place they
  choose; Brickson does not receive it.
- Personal Voice stays with Apple; Brickson only asks iOS to speak.
- **Any future feature that sends anything off the device** (caregiver
  alerts over the network, sync) re-opens this answer, the privacy policy
  and the privacy manifest in the same pull request.

**Not verified:** whether TestFlight's tester feedback and crash reports, and
App Store crash reports that people choose to share with developers, need any
disclosure. Apple's privacy-details page should be re-read for this before
the first external TestFlight build.

**Purpose strings later features will need** (none today: Personal Voice
needs no Info.plist key): `NSMicrophoneUsageDescription` for recorded
phrases; `NSLocalNetworkUsageDescription` and `NSBonjourServices` for
caregiver alerts. Each needs a plain sentence a reviewer and the person can
understand (guideline 5.1.1(ii)).

## 8. App Review notes

App Review reads these privately. The Notes field takes up to 4,000 bytes
([platform version
information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)).
Guideline 2.3.1(a) asks for new features to be described "with specificity",
and 2.5.4 allows background audio only "for their intended purposes". Paste
this, after deleting every bracketed sentence whose feature is not in the
build (1,812 bytes as drafted):

> Brickson is a communication app (AAC) for people who cannot speak, such as
> people living with ALS. A person chooses a phrase and the device says it
> aloud. Everything stays on the device: there is no account, no sign-in, no
> server and no network code. Touch is enough to test every feature; no Eye
> Tracking or Switch Control setup is needed.
>
> To hear speech: on Home, tap any phrase. It speaks at once and stays on
> screen; Again repeats it.
>
> Personal Voice: at first launch the system asks whether Brickson may use
> your Personal Voice. Allowing or declining both work; if you decline, or
> the device has no Personal Voice, Brickson uses a standard system voice.
> [After the first-run screens ship: the question appears only after Brickson
> explains it, from a button the person chooses, with a "Not now" choice.]
>
> Background audio (UIBackgroundModes: audio, guideline 2.5.4): people who
> cannot speak must be heard even if the device locks mid-sentence. To see
> it: choose a long phrase, then lock the device; speech continues. Brickson
> plays audio only when the person chooses a phrase [or starts Get
> Attention]; it never plays silent audio to stay running.
>
> [Get Attention: tap Get Attention to play a repeating tone that calls
> someone to the room. It plays even with the silent switch on and keeps
> playing while the device is locked, until someone taps Stop Alert, which is
> a separate button in a different place so a resting gaze cannot stop the
> call by accident. It contacts nobody.]
>
> Emergency: shows a set of urgent phrases. It does not call or message
> anyone.
>
> The screen stays on while Brickson is open because many people who use it
> cannot unlock their device.
>
> Brickson provides no healthcare service and makes no medical claims. The
> privacy policy link is in Settings > Privacy. [needs: Settings]

Also: **no sign-in** (leave the demo account empty). Give a phone number App
Review can reach.

**Guidelines that touch Brickson** (quoted from the [App Review
Guidelines](https://developer.apple.com/app-store/review/guidelines/), last
updated 2026-10-16):

- **1.4.1** Medical apps "that could be used for diagnosing or treating
  patients may be reviewed with greater scrutiny". Brickson makes no such
  claim; keep it that way in every word of the store text.
- **2.1** Final versions only; tested on a device; no crashes.
- **2.3.1(a)** Don't promote what the app doesn't offer. The description
  must only describe the build (ASO.md tags every unbuilt claim).
- **2.3.7** No "trademarked terms, popular app names, pricing information,
  or other irrelevant phrases" in metadata; names 30 characters.
- **2.3.8** Metadata suitable for 4+, and the name under the icon similar to
  the store name.
- **2.5.4** Background services only for their intended purpose.
- **2.5.9** Apps must not "alter or disable the functions of standard
  switches, such as the Volume Up/Down and Ring/Silent switches". Brickson
  plays through the silent switch with the `.playback` session, as Apple
  intends, and never sets the volume (invariant 4).
- **4.2** Enough function to be "app-like".
- **5.1.1(i)** The privacy policy in App Store Connect and inside the app.
- **5.1.1(iv)** Respect permission choices and offer an alternative: if
  Personal Voice is declined, the system voice works.
- **5.1.1(ix)** Regulated fields such as healthcare come from organizations;
  see section 5.

**Never ask for a rating on Home.** A system rating prompt can appear over
the controls a person needs and must dismiss. Decided in the roadmap's
register: no automatic prompt; at most a "Rate Brickson" row in Settings that
opens the App Store's write-review page (ASO.md, *Ratings*).

## 9. Screenshots and app preview

From [Screenshot
specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
read 2026-10-21:

- 1 to 10 screenshots per device size, `.png` or `.jpeg`, no transparency.
- **Required today:** at least one for **iPhone with Dynamic Island (medium
  display)** and, because Brickson runs on iPad, one for **iPad 13-inch**.
  Smaller sizes are scaled down from these. Apple accepts the iPhone medium
  sizes 1206 × 2622 or 1179 × 2556 (portrait); the large iPhone sizes
  (for example 1320 × 2868) are optional; the 13-inch iPad takes 2064 × 2752
  portrait or 2752 × 2064 landscape (2048 × 2732 also accepted).
- **iPhone Duo** (Apple's foldable iPhone): outer display 1398 × 2034, inner
  display 2007 × 2853 (or rotated). The screenshot specifications say:
  "Starting in April 2027, screenshots will be required for any app using
  the iOS 27.1 SDK or later" (read 2026-10-21). Whether it applies depends
  on the SDK of the Xcode the build uses, so check that page against the
  current Xcode before each submission (docs/DECISIONS.md, "Build with
  Apple's current Xcode"). A Duo set
  also earns an "optimized for iPhone Duo" badge
  ([Apple news](https://developer.apple.com/news/?id=kkphp5qo)). Brickson's
  iPhone is portrait-only for now; the Duo screenshots must come from a real
  layout on the inner display, so they wait for the orientation decision
  (Phone layout and word fitting thread).
- Guideline 2.3.3: screenshots "should show the app in use", and may carry
  text overlays, "for example, to demonstrate input mechanisms". No price,
  and fictional content only (2.3.9): the starter phrases are fine.
- App previews are optional: up to three per device size, 15 to 30 seconds,
  screen captures of the app itself only, with narration or text overlays
  allowed (2.3.4, [app preview
  specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications)).

The frames, captions and storyboard are in [ASO.md](ASO.md#screenshots).
Capture from the real app on the current Xcode's simulators (a standard
iPhone with a medium display, and the iPad Pro 13-inch), light and dark, at the
default text size, and once at a large accessibility size to show that text
grows. Never use mock-ups.

**App icon.** Today's icon is a placeholder; the brand artwork in
`design/brand/` is ready to install. The icon is best made in Icon Composer, with dark and tinted variants (Figma and Claude Design
screens thread, with release chores).

## 10. Localization

- **1.0 ships the app in English.** Apple doesn't require an app to be
  translated to be offered in a country; the product page lists the
  languages the build contains.
- **App Store text can be localized separately from the app**, in the
  locales Apple lists, including English (U.S.), English (U.K.), English
  (Australia) and English (Canada)
  ([App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations)).
  Each storefront has a default language: the UK and Ireland use English
  (U.K.); Australia and New Zealand use English (Australia); Canada uses
  English (Canada) and French (Canada); the US uses English (U.S.), with
  Spanish (Mexico) and seven other languages also supported there.
- **Proposed for 1.0:** fill English (U.S.), English (U.K.), English
  (Australia) and English (Canada), because people in the UK, Australia and
  New Zealand say **MND**, and "ALS" in the UK store means Advanced Life
  Support (ASO.md, *Other English-speaking stores*).
- Later app languages follow where Personal Voice and good system voices
  exist; the String Catalog is already in place (`Localizable.xcstrings`).

## 11. EU trader status

The EU's Digital Services Act requires Apple to show a trader's address,
phone number and email on EU product pages. Apps without a declared status
are removed from the EU store
([Apple: DSA trader
requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)).
"Apple can't determine whether you're a trader": the developer self-assesses.
Apple quotes the EU: a trader acts "for purposes relating to his or her
trade, business, craft or profession", and someone acting outside their
trade, such as a hobbyist, is unlikely to be one. This is the owner's own
legal call; a trader's contact details become public in the EU.

## 12. TestFlight

From Apple's [TestFlight
overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
and [external
testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers):

- **Internal testers:** up to 100 people who are users on the App Store
  Connect team; no review. On an individual account that is mainly the owner.
- **External testers:** up to 10,000, by email or public link. "The first
  build you submit requires a full review, but later builds for the same
  version might not." A public link can be limited by device and OS, and
  people who join by link show as anonymous.
- **Required test information:** a Beta App Description and a Feedback Email,
  and, for external testing, Beta App Review contact information: first and
  last name, email and phone, and whether sign-in is required (Brickson has
  no accounts, so no demo account is needed)
  ([provide test
  information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information)).
- Each build can be tested for 90 days.
- Testers send feedback and screenshots through TestFlight, and the developer
  sees their sessions and crashes.
- TestFlight needs the app record, so it waits for the name too.

**Runbook, matched to the release gate above (R0 in the roadmap):**

1. Gate: R0 items done, device checks logged in `docs/log/`, UI tests green on
   iPhone and iPad at default and largest text, light and dark; policy,
   README and website say only what the build does.
2. Internal build to the owner's own iPhone and iPad. Run the device checks
   in docs/HANDOFF.md.
3. External group "First testers": a few people living with ALS, family
   members, and a speech-language pathologist. Beta App Description: what
   Brickson is, in two sentences. What to Test: speak a phrase with your usual
   input method; use Emergency, Yes and No; try typing [if built]; tell us
   which input method you use and anything that was hard to reach or
   happened by accident.
4. Fix, re-test, then submit 1.0 to App Review.

## 13. Changes this needs in the app, and who owns them

| Change | Why the store needs it | Owner thread |
|---|---|---|
| In-app Privacy row: the policy text inside the app, plus a way to open the web page | Guideline 5.1.1(i) | Settings and first run |
| Personal Voice explained before the system question, with "Not now" | 5.1.1(iv); a calmer first launch for the reviewer | Settings and first run |
| A replaced bundle ID, and `DEVELOPMENT_TEAM` | Step 2 and 3 of the owner's list | Toolchain, after the owner's answer |
| The brand icon in Icon Composer, with dark and tinted variants | 2.1 (no placeholders) | Figma and Claude Design screens |
| Dark variants for every colour asset; UI tests in dark and at AX3 and AX5; a Grayscale pass | Accessibility labels (section 4) | Test seams and CI evidence; Phone layout and word fitting |
| Get Attention without flashing; Reduce Motion respected | Reduced Motion label | Speech engine and Get Attention |
| A `site/accessibility/` page for the Accessibility URL | Section 4 | App Store readiness and ASO (follow-up) |
| Delete the policy's unbuilt sections before 1.0 | Section 3 | App Store readiness and ASO, at release |
| An age-range check only if needed, never over Home | Section 6 | Settings and first run, after the decision |
| iPhone Duo inner-display layout and screenshots by April 2027 | Section 9 | Phone layout and word fitting |
| No automatic rating prompt anywhere | Section 8 | Everyone |
