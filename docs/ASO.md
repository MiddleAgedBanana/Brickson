# App Store search and store text (ASO)

ASO, App Store Optimization, means choosing the words on the product page so
that the people who need Brickson find it when they search, and understand
it in the few seconds they look at it. This file holds the research and the
drafts. What App Store Connect asks for, and the owner's checklist, are in
[APP-STORE.md](APP-STORE.md).

**Status (2026-10-27):** drafts, updated against the current `main` build.
Nothing has been entered in App Store Connect. Every store-text draft below
uses `[App Name]` as a placeholder for the app name until the final name is
confirmed in App Store Connect (docs/DECISIONS.md, *Waiting on the owner*; the
working name is Brickson, retained publicly on 2026-10-12, and *If the name is
taken* has the fallbacks). Nothing here states a price: the price is not
decided (docs/DECISIONS.md, "Price not decided"), so no draft mentions any
price or cost word.

## Contents

- [How App Store search works](#how-app-store-search-works)
- [What people search for](#what-people-search-for)
- [Competitors](#competitors)
- [The store text](#the-store-text)
- [Screenshots](#screenshots)
- [Other English-speaking stores](#other-english-speaking-stores)
- [Ratings](#ratings)
- [If the name is taken](#if-the-name-is-taken)
- [After launch](#after-launch)

## How App Store search works

From Apple's [App Store
search](https://developer.apple.com/app-store/search/) and [app
information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
pages, read 2026-10-21:

- **Searched fields:** the app name (up to 30 characters), the subtitle (up
  to 30 characters), the keyword field (up to 100 bytes, words separated by
  commas), the developer name and the in-app purchase names. The
  description is **not** searched; it is for people, not the search engine.
- Search also weighs how people respond: downloads, ratings and how often
  people who search a word open the app. A new app starts with none of this,
  so the words in the name and subtitle matter most at launch.
- **Keyword rules:** no spaces after commas (they waste bytes); don't repeat
  a word already in the name or subtitle; singular is enough in most cases;
  no other apps' names, no trademarks the developer doesn't own, no
  unrelated popular words (Guideline 2.3.7). Keywords are per App Store
  localization, so each English locale gets its own 100 bytes.
- **Accessibility Nutrition Labels** are shown on the product page and,
  Apple says, help people find apps that support the features they need
  (APP-STORE.md, section 4). Most competitors have declared none.
- Name, subtitle and keywords can only change with a new version, except
  that the promotional text (170 characters) can change at any time.

## What people search for

Searched with Apple's public search API on 2026-10-21, US store unless
marked, top results only. "Served well" means the top results are apps a
person with ALS could use to speak.

| Search | What came up | Served well? | Use it in |
| --- | --- | --- | --- |
| `aac` | Weave Chat, Proloquo, Fast AAC, TouchChat, Visual Choices | Yes, crowded | name |
| `als` | Sign-language (ASL) apps, ALS Social, Defeat ALS | No: "ALS" is mistaken for ASL | name (US) |
| `als communication` | ALS Key Medical Information, Proloquo4Text, Yes or No Communication | Weakly | name + keywords |
| `mnd` (US) | Make-up and dance apps, MND SIP | No | keywords |
| `mnd` (UK, AU) | MND PRISM, SpeakUnique, BlinkTalker | Weakly | name (UK, AU) |
| `motor neurone disease` (UK) | Parkinson's and neurology guides | No | keywords (UK, AU) |
| `als` (UK) | iResus, iALS, resuscitation apps | No: means Advanced Life Support | avoid in UK name |
| `augmentative communication` | Visuals2Go, Leeloo, Weave Chat, Spoken | Yes, mostly for children | keywords |
| `text to speech` | Speechify, NaturalReader, Speak4Me (readers) | Crowded, mostly readers | subtitle |
| `speak for me` | Speak4Me, Speak For Me | Yes | keywords (`speak`) |
| `nonverbal` | Fast AAC, Vocable, Visuals2Go | Yes | keywords |
| `communication board` | Visuals2Go, ChatterBoards, CommBoards, Proloquo | Yes, for children | keywords (`board`) |
| `communication aid` (UK) | Twinkl Symbols, Grid Player, ChatterBoards | Yes | keywords (UK, AU) |
| `eye gaze` | Eye Gaze Communication Board, Vocable, Eye Type, Jabberwocky | Weakly: small, old apps | keywords |
| `eye tracking` | Eye-training and test apps | No | not until device checks |
| `switch access` | Profile switchers, Skwitch, EZ-Switch | Weakly | keywords (`switch`) |
| `personal voice` | Voice generators and AI apps | No | keywords (`voice`) |
| `speech assistant` | Speech Assistant AAC (two apps), CommBoards | Yes | keywords |
| `type to speak` | Text to Speech!, Speak4Me, Type2Talk | Yes | keywords (`type`) |
| `voice banking` | Bank apps | No | skip |
| `dysarthria` | Speech-therapy apps | No | skip |

What this says:

- **"AAC" next to the condition** is the clearest name. "ALS" alone pulls
  sign-language apps in the US, and resuscitation apps in the UK.
- **Nobody owns "ALS", "MND", "eye gaze" or "personal voice".** The apps
  that come up are small, old, or unrelated. A new app with these words in
  its name or keywords has a real chance there.
- **"AAC" and "text to speech" are crowded** by large, well-rated apps; we
  include them for relevance, not to win them at launch.
- **Words we must not use yet:** "Eye Tracking", "Switch Control" and
  similar claims, until each input method has been checked on a real device
  (APP-STORE.md, section 4). The keyword `eye` and `gaze` describe what the
  app is for; the description must not claim it works until it is checked.

## Competitors

The apps that come up for the searches above (US store, 2026-10-21; first
genre is the primary category). "Labels" means Accessibility Nutrition
Labels declared on the product page.

| App | Developer | Category | Ratings | Subtitle | Labels |
| --- | --- | --- | --- | --- | --- |
| Proloquo2Go AAC | AssistiveWare | Education, Medical | 12,227 (4.8) | Tap symbols. Type words. Speak | No |
| Proloquo4Text AAC | AssistiveWare | Education, Medical | 934 (4.7) | Text-to-speech communication | Yes |
| Weave Chat AAC | Weave Chat | Education, Medical | 537 (4.7) | Dynamic & Customizable AAC App | Yes |
| Avaz AAC | AVAZ | Education, Medical | 316 (4.1) | Flexible Speech Language Tool | No |
| Spoken - Tap to Talk AAC | Spoken | Health & Fitness, Medical | 160 (4.3) | Natural Voice Text to Speech | Yes |
| Talk For Me | an individual developer | Utilities | 120 (4.3) | Communication Made Simple | Yes |
| Speech Assistant AAC | an individual developer | Medical, Education | 104 (4.5) | Text to Speech Communication | No |
| TouchChat Discover / HD | PRC | Education, Medical | 101 / 36 | | Yes |
| LAMP Words For Life Discover | PRC | Education, Medical | 23 (3.6) | Motor Learning-Based AAC | Yes |
| CoughDrop | MAVWARE | Education, Medical | 63 (3.7) | | No |
| Vocable AAC | WillowRoot Apps | Medical, Utilities | 61 (4.5) | Hands-free text-to-speech | No |
| Jabberwocky AAC | Swiftable | Medical, Productivity | 27 (4.2) | Touch-Free Text to Speech | No (last update 2020) |
| 9 Gaze | See Vision | Medical | 22 (4.6) | | No |
| Speak4Me | Miro Consulting | Utilities, Productivity | 13,680 (4.5) | Read aloud voice for PDF audio | Yes |
| Yes or No Communication | an individual developer | Utilities | 11 (4.5) | Rudimentary AAC | No (last update 2017) |
| Eye Type AAC | Su-Kam | Medical, Utilities | 5 (2.6) | Text-to-Speech Keyboard | No |

What this says:

- **The big AAC apps are built around symbols for children** (Education
  first). Apps for adults who type or choose phrases are smaller, and the
  hands-free ones (Vocable, Jabberwocky, Eye Type, 9 Gaze) are thinly rated
  or not updated. That is the gap Brickson is built for.
- **Half have declared no accessibility labels**, including the largest.
  Declaring Brickson's labels honestly, once each feature is built and
  checked, sets it apart where it matters most.
- **Utilities is a normal home** for speaking apps (Talk For Me, Speak4Me,
  Yes or No), which supports the category default (APP-STORE.md, section 5).

## The store text

All drafts are in English (U.S.). Other stores are under *Other
English-speaking stores*. Counts were measured with a script. Every draft uses
`[App Name]` as the placeholder for the app name (8 characters when replaced
with the working name).

### Name (30 characters)

**`[App Name]: AAC for ALS`** (23 characters with `[App Name]`, 21 characters
with an 8-character brand name). The brand, then what it is and who it is for,
in the two words people search for. Keep `[App Name]` first so the name stays
the brand when it is shortened under the icon.

### Subtitle (30 characters)

**For 1.0: `Phrases and text to speech`** (26 characters). It adds the
second most searched phrase and says plainly what the app does, without
promising anything 1.0 does not have.

**Once stage profiles ship (R1): `Text to speech at every stage`** (29
characters). It keeps the same searched phrase and adds the idea of the app
(it follows the person through the disease) without naming the disease
twice. Before profiles exist it would promise more than the build does, so
it waits; the subtitle can change with any new version.

Other options: `Phrases that speak at once` (26), `Speak with phrases you choose`
(29).

### Keywords (100 bytes)

```
communication,nonverbal,speak,talk,voice,eye,gaze,switch,assistive,augmentative,board,mnd,type
```

94 bytes (comma-separated, no spaces after commas, no plurals of words already
included, no category names or competitor names). Words already in the name
and subtitle (`[App Name]`, `aac`, `for`, `als`, `phrases`, `and`, `text`,
`to`, `speech`; `at`, `every` and `stage` with the R1 subtitle) are left out,
because Apple already combines them with these. `mnd` stays because some US
caregivers use it.

Once the R1 subtitle `Text to speech at every stage` ships, `phrase` moves
from the subtitle into the keyword field (96 bytes):

```
communication,phrase,nonverbal,speak,talk,voice,eye,gaze,switch,assistive,augmentative,board,mnd
```

### Promotional text (170 characters, can change any time)

> Choose a phrase and [App Name] says it at once, in your own Personal Voice
> if you made one. Yes, No and Emergency are always on screen, and the
> buttons never move.

163 characters with `[App Name]` (161 characters with an 8-character brand
name). Change it for each release to say what is new, and never put a price
in it.

### Description (4,000 characters)

The master draft below is 2,013 characters with `[App Name]` (and the
`[needs: …]` tags), or 1,813 characters when the tags are stripped. **Every
line tagged `[needs: …]` may only go in once that feature is in the build
being submitted**: Guideline 2.3.1 rejects descriptions that claim what the
app doesn't do. Remove the tags before pasting. Text with no tag describes
what is built on `main` today (Home on the layout engine, whole-word fitting,
Get Attention and Stop, Typing with draft persistence, and Voice Settings with
Personal Voice).

```
[App Name] speaks for you. Choose a phrase and your iPhone or iPad says it out loud, at once, in your own Personal Voice if you have made one.

[App Name] is built for people living with ALS (also called MND), at every stage. [needs: profiles (R1); until then end the paragraph here] As the way you use your device changes, from touch to switches to your eyes, the buttons can grow and spread out, but they never move. You never have to learn a new layout.

SPEAKS THE FIRST TIME
• Every phrase speaks on the first tap, with no extra step to confirm.
• Yes, No and Emergency are always on screen.
• Emergency opens a set of urgent phrases straight away.
• The sentence stays on screen in large type, so the person you are talking to can read it too. Again repeats it.
• Get Attention plays a loud tone until someone stops it, from a separate button.

WORKS THE WAY YOU DO
• Every button is a standard button, so [App Name] works with the ways Apple devices can be controlled: touch, Switch Control, Voice Control, Full Keyboard Access, Dwell, head tracking and Eye Tracking. [needs: device checks of each input method]
• Large buttons and generous spacing, sized from the space on your screen.
• Words never break in the middle, and text follows the size you set for your device.
• Speech plays even with the silent switch on, and keeps playing if the screen locks.
• The screen stays on while [App Name] is open, so you are never locked out.

YOUR WORDS, YOUR VOICE
• Starts with a set of everyday phrases: basics, needs, conversation, feelings and emergency.
• Type anything and [App Name] says it. Your message is kept if the app closes.
• Add, change and arrange your own phrases with your family. Changes are made in a separate edit mode, so speaking never changes your phrases. [needs: editing]
• Save a backup of your phrases to Files. [needs: backup]
• Uses your Personal Voice when you allow it. Or choose any voice on your device, and set the speaking speed that suits you.

PRIVATE BY DESIGN
• No account. No ads. No tracking.
• Your phrases stay on your device. [App Name] has no servers and never sends your words anywhere.

A NOTE ON SAFETY
[App Name] does not call anyone. Emergency shows phrases for the people nearby. Please keep another way to call for help, and a simple backup way to communicate, such as a letter board.

[App Name] is a communication app. It does not diagnose or treat any condition.
```

If 1.0 is submitted before profiles (R1), the real-device input checks, the
phrase editor screens, or the backup screens land, paste this 1,354-character
version with those four `[needs: …]` items omitted so every line is true of
the build today:

```
[App Name] speaks for you. Choose a phrase and your iPhone or iPad says it out loud, at once, in your own Personal Voice if you have made one.

[App Name] is built for people living with ALS (also called MND). Every button stays in the same place, so you never have to learn a new layout.

SPEAKS THE FIRST TIME
• Every phrase speaks on the first tap, with no extra step to confirm.
• Yes, No and Emergency are always on screen.
• Emergency opens a set of urgent phrases straight away.
• The sentence stays on screen in large type, so the person you are talking to can read it too. Again repeats it.
• Get Attention plays a loud tone until someone stops it, from a separate button.

WORKS THE WAY YOU DO
• Large buttons and generous spacing, sized from the space on your screen.
• Words never break in the middle, and text follows the size you set for your device.
• Speech plays even with the silent switch on, and keeps playing if the screen locks.
• The screen stays on while [App Name] is open, so you are never locked out.

YOUR WORDS, YOUR VOICE
• Starts with a set of everyday phrases: basics, needs, conversation, feelings and emergency.
• Type anything and [App Name] says it. Your message is kept if the app closes.
• Uses your Personal Voice when you allow it. Or choose any voice on your device, and set the speaking speed that suits you.

PRIVATE BY DESIGN
• No account. No ads. No tracking.
• Your phrases stay on your device. [App Name] has no servers and never sends your words anywhere.

A NOTE ON SAFETY
[App Name] does not call anyone. Emergency shows phrases for the people nearby. Please keep another way to call for help, and a simple backup way to communicate, such as a letter board.

[App Name] is a communication app. It does not diagnose or treat any condition.
```

Notes on the draft:

- The starter categories listed (`Basics`, `Needs`, `Conversation`, `Feelings`
  and `Emergency`) match `StarterPhrases.json` in the repository today.
- "Feelings" names a category, not words about anyone's condition
  (AGENTS.md, invariant 7). Check its phrases before release.
- The safety note answers what a reviewer, or a family, will ask first:
  Emergency doesn't dial anyone.
- "Does not diagnose or treat" keeps the app clear of medical claims
  (Guideline 1.4.1). It does not say whether the app is or isn't a medical
  device; that is not ours to declare in store text (APP-STORE.md,
  section 2).

### What's New

App Store Connect does not show a *What's New in this Version* field on version
1.0; it requires one (up to 4,000 characters) starting with the first update
after launch, and Guideline 2.3.12 requires user-facing changes to be listed
clearly in order of importance, never "bug fixes and improvements" alone.

**First update entry (1.1, 355 characters with tags; 300 characters without
tags — remove any line whose feature is already in 1.0 or not in 1.1):**

```
• Add, change and arrange your own phrases and categories in a separate edit mode, so speaking never changes your words. [needs: editing]
• Save a backup of your phrases to Files and restore it on another device. [needs: backup]
• Choose a stage profile in Settings to make buttons and spacing larger as your reach changes, without moving where anything sits. [needs: profiles (R1)]
```

**First release summary (for TestFlight *What to Test* or launch notes, 466
characters):**

```
First release of [App Name].
• Speak everyday phrases with one tap in Basics, Needs, Conversation, Feelings and Emergency.
• Yes, No, Emergency, Again and Get Attention (with a separate Stop button) stay on screen.
• Type anything to speak aloud, with your draft saved on your device until you clear it.
• Choose your Personal Voice or any voice on your device, and set your speaking speed in Settings.
• Everything runs on your device with no account, no ads and no tracking.
```

### Support and marketing URLs

- Support URL: https://middleagedbanana.github.io/Brickson/
- Privacy policy URL: https://middleagedbanana.github.io/Brickson/privacy/
- Marketing URL: leave empty, or the same home page.

## Screenshots

Specifications are in APP-STORE.md, section 9. The plan: five screenshots,
the same story on iPhone and iPad, each with a short caption above a real
capture of the app. Captions use large type that passes the contrast rules
(AGENTS.md, invariant 6), and each one is a full sentence a person can read
at a glance.

| # | Caption | What the capture shows | Waits for |
| --- | --- | --- | --- |
| 1 | Choose a phrase. [App Name] says it. | Home with the message row showing a spoken phrase | Built on `main` (capture when app icon lands) |
| 2 | Yes, No and Emergency are always there. | Home with the safety row in view, Emergency phrases open | Built on `main` (capture when app icon lands) |
| 3 | Type anything, and it speaks. | Typing on Home with Apple's keyboard up and the safety row above it | Built on `main` (capture when app icon lands) |
| 4 | Buttons grow with you. They never move. | Two captures side by side: default and a larger profile, same positions | Profiles (R1; for 1.0 use "Large text, large buttons." at AX3/AX5) |
| 5 | Your own voice, your own words. | Voice settings with Personal Voice chosen, or the phrase editor | Voice settings built on `main`; phrase editor waits for editing |

- Until profiles exist (R1), number 4 becomes "Large text, large buttons."
  with Home at a large accessibility text size.
- Order the iPad set landscape-first if the iPad layout reads better there;
  decide when the iPad layout is final.
- iPhone Duo gets the same story twice, on the outer and the inner display
  (sizes in APP-STORE.md, section 9), from the first submission: required
  from April 2027, and it earns the "optimized for iPhone Duo" badge
  (docs/DECISIONS.md, "iPhone Duo").
- One set in light appearance. A dark set is not needed; the page shows one
  set per device size.
- The capture is the real app on a simulator at the sizes in APP-STORE.md.
  Captions and the background are added afterwards; nothing inside the app
  frame is drawn or changed.

### App preview (optional, later)

A 20 to 25 second screen recording, no music needed, captions on screen
(Apple autoplays previews muted):

1. (0 to 4 s) Home. A phrase is chosen; the message appears and is spoken.
   Caption: "One tap. It speaks."
2. (4 to 9 s) Emergency, then an urgent phrase. Caption: "Emergency is
   always on screen."
3. (9 to 15 s) Typing a short sentence, then Speak. Caption: "Type
   anything."
4. (15 to 21 s) The same Home in a larger profile. Caption: "Bigger when you
   need it. Never moved."
5. (21 to 25 s) [App Name]'s name and icon.

Record it with Switch Control or Dwell on screen only after those are
checked on a real device. Spoken narration needs a caption track or on-screen
text, so the preview is usable by people who can't hear it (APP-STORE.md,
section 4, Captions).

## Other English-speaking stores

People in the UK, Ireland, Australia and New Zealand say **MND** (motor
neurone disease), and "ALS" in the UK store means Advanced Life Support.
Canada and the US say ALS. Each storefront reads its own App Store
localization (APP-STORE.md, section 10), so:

| Locale | Stores | Name | Subtitle | Keywords |
| --- | --- | --- | --- | --- |
| English (U.S.) | US | `[App Name]: AAC for ALS` | `Phrases and text to speech` | as above |
| English (Canada) | Canada | `[App Name]: AAC for ALS` | `Phrases and text to speech` | as US |
| English (U.K.) | UK, Ireland | `[App Name]: AAC for MND` | `Phrases and text to speech` | below |
| English (Australia) | Australia, New Zealand | `[App Name]: AAC for MND` | `Phrases and text to speech` | below |

UK and Australia keywords (99 bytes):

```
communication,aid,motor,neurone,nonverbal,speak,talk,voice,eye,gaze,switch,assistive,als,board,type
```

The subtitle changes to `Text to speech at every stage` in every locale
once profiles ship (see *Subtitle*).

In the UK and Australian descriptions, the second paragraph begins "[App Name]
is built for people living with MND (also called ALS)". The rest of the text
is the same; British spelling needs no other change in this draft.

Searched 2026-10-21: `mnd` in the UK and Australia returns MND PRISM,
SpeakUnique and BlinkTalker; `aac` returns the same big apps as the US, plus
Grid Player and Twinkl Symbols in the UK.

## Ratings

Ratings help search, but asking at the wrong moment can put a pop-up in
front of someone who is trying to speak.

- **Never ask automatically.** No `requestReview` on Home or during
  communication, ever: a review prompt is a sheet over the controls a
  person may need (AGENTS.md, invariants 2 and 10). Apple's own guidance is
  to ask at a natural pause; [App Name] has none on Home.
- **A "Rate [App Name]" row in Settings**, below the family controls, opens
  the App Store's write-review page
  (`https://apps.apple.com/app/id<APP_ID>?action=write-review`) for whoever
  chooses it. Needs the app's Apple ID, which exists only after the record is
  created (Settings and first run thread).
- Reply to reviews in App Store Connect. A family's report of something
  going wrong is a bug report: answer it and fix it.

## If the name is taken

Apple refuses a name another app already uses. The checks so far are in
[NAME_AVAILABILITY.md](NAME_AVAILABILITY.md) (12 October 2026: no app or
developer named Brickson in the US, UK, Canada or Australia stores, and no
US trademark). The EU, UK and Canadian trademark registers were not checked;
TMview (https://www.tmdn.org/tmview/) blocks automated searches, and the
owner can search it for the working name in a browser in about five minutes.

If App Store Connect says the planned `[App Name]: AAC for ALS` is in use,
try, in order:

1. `[App Name] AAC` (12 characters with an 8-character brand name)
2. `[App Name]: AAC Voice` (19 characters with an 8-character brand name)

Apple checks the whole name, so `[App Name]: AAC for ALS` may be available
even when plain `[App Name]` is taken; try the planned name first.

The name on the Home Screen comes from the build (`CFBundleDisplayName`), not
from App Store Connect, and can stay `[App Name]` either way.

## After launch

- **Custom product pages:** extra versions of the product page,
  each with its own screenshots and promotional text, that can be linked
  from a website or a clinic's handout (for example, one for speech
  therapists, one for families). Later.
- **Product page optimization:** tests different icons or screenshots on a
  share of visitors. Only useful once the app has steady traffic.
- **In-app events:** not planned; they suit apps with time-limited events.
- Review the search table above every few months with the same searches.
