# The quality bar: gates every release passes before App Review

*2026-10-30. Pull request #72 (`claude/project-thread-qohc42`). A cloud
thread working on documents only; the app was not built or run.*

## What changed and why

The owner set the standard for Brickson on 2026-10-30, in two messages:
the app must be complete and feel ready before it is ever submitted for
review, and the owner will not put their name on something they would
not recommend to someone, which today they would not. The owner took up
"designed rather than assembled" as the way to say what is missing.

[`docs/ROADMAP.md`](../ROADMAP.md), *The quality bar*, now turns that
standard into 29 gates that every release, starting with R0, passes
before App Review. Each gate says what passes and who checks it: CI, a
thread, the owner on their own iPhone and iPad, or the TestFlight
testers. A gate passes only with a `docs/log/` record of what passed, on
what and when, and the last gate is the owner's own yes. They are
grouped as:

- **It never lets the person down** (Q1 to Q5): every check green,
  including a warning-free Release build; no open dwell hazard (five
  are open, all already in docs/HANDOFF.md, *Known gaps*: the three
  R0's *Release gate* named, Again nearest Stop's empty well in a
  library with fewer than three everyday categories, and iPhone Duo's
  AX5 chain from Family Setup); every floor named; every device check
  the release touches, sound first; no crash and no hang.
- **It feels right in the hand** (Q6 to Q10): the default voice
  speaking within half a second (the median of ten activations), a
  first frame within 400 ms and an app that comes back as it was, a whole day
  with the screen on (an unplugged run by the owner and a run attached
  to the Mac by a thread), the owner living with the build, every
  window and pose.
- **Hours under Switch Control, Eye Tracking, a head pointer and dwell**
  (Q11 to Q14): two hours per input method on a mounted iPad with a
  fixed script and a count of every unmeant activation; Snap to Item and
  Dwell measured; floors that miss fewer than 1 in 20 meant activations;
  every input method reaching the same app, with Yes, No and Emergency
  first in Switch Control's scan.
- **Every screen looks designed** (Q15 to Q21): drawn before built and
  built as drawn, Apple's Human Interface Guidelines screen by screen,
  system components measured, nothing tuned by eye, every word chosen,
  finished edges, and the owner's eye.
- **Accessible by Apple's own measure** (Q22 and Q23): Apple's audit on
  every screen and state, and every Accessibility Nutrition Label earned
  by Apple's criteria.
- **Complete, and true** (Q24 to Q26): nothing half-made, the first five
  minutes for someone new, and every word outside the app true.
- **People, then the owner's answer** (Q27 to Q29): the pilot, a
  comparison with the apps families use today, and "Would I recommend
  this to someone?"

Each gate has a *Today* line for R0 on 2026-10-30 (Q24's also records
the owner's answer to Q9 of 2026-11-01), so the distance to App Review
is visible; pull requests that move a gate edit that line, and
AGENTS.md, *Workflow rules*, now says so.

How the bar runs: every gate passes before App Review; before the
external pilot, every gate passes except those that need the pilot
or the final build (Q5's crash and hang reports through the whole
TestFlight period, Q9's last seven days, the testers' sessions in Q11
and Q13, Q27, the pilot itself, Q28 and Q29), and the owner's
device gates run on the internal TestFlight build first. The build
submitted is the one the owner and the pilot used for its last seven
days; a build changed after the pilot goes back to both. A thread
writes the step-by-step procedure for each owner gate before the
owner's first device run. A later release reruns the gates its changes
touch, and always Q9, Q21 and Q29. An urgent fix after a release (a
phrase that does not speak, a crash) passes the whole bar too, unless
the owner, when one is needed, decides that this fix goes sooner;
docs/DECISIONS.md records a recommendation for that moment, not a
standing exception.

The decision is recorded in docs/DECISIONS.md, "Every release passes
the quality bar": the bar is the owner's; the gates, their numbers and
who checks each are defaults the owner can change. One gate waited on
the owner: how long the owner lives with each TestFlight build (Q9),
recommended at two weeks before the pilot and seven days on the exact
build before App Review. On 2026-11-01, while this pull request was
open, the owner chose the recommendation on a decision card in the
project thread, and it is recorded as the owner's answer.

What it folds in, already open before today: the five open dwell
hazards (Q2; R0's *Release gate* named three, and the other two were
only in docs/HANDOFF.md, *Known gaps*), Settings' floors under a larger profile, which were only in a
work log's follow-ups and are now also in docs/HANDOFF.md, *Known gaps*
(Q3), the device-check table (Q4, Q12 to Q14), R0 item 9's screens
(Q15) and R0 item 11's pilot (Q27). What it adds: speed and launch, a
whole day with the screen on, long sessions per input method, a design
pass per screen against Apple's pages, first-time people, a comparison
with other AAC apps, and the owner's answer.

Also changed, to keep everything pointing at one bar: R0's *Release
gate* names the bar; docs/APP-STORE.md (section 2 and the TestFlight
runbook) and docs/SDLC.md, *Deploy*, say no build goes to App Review
before it passes; AGENTS.md's pointer to the roadmap names it;
docs/HANDOFF.md adds five device-check rows the bar needs, the owner's
step to read it, and the Settings floors gap; and the roadmap's "Nothing
has run on a real iPhone or iPad yet" now says the app was installed
and launched once on an iPhone on 2026-10-25, with only an informal
look, as docs/HANDOFF.md, *Verification*, records.

## Apple's pages behind the gates

Read on 2026-10-30 and checked again on 2026-11-01. Developer
documentation and Human Interface Guidelines pages were read as
Markdown (the page's path with `.md` appended); the App Store Connect
and App Review help pages, the App Review Guidelines, the App Review
page, the WWDC sessions and the support.apple.com guides have no
Markdown form and were read as their web pages.

- Human Interface Guidelines: [Layout](https://developer.apple.com/design/human-interface-guidelines/layout),
  [Materials](https://developer.apple.com/design/human-interface-guidelines/materials),
  [Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
  [Color](https://developer.apple.com/design/human-interface-guidelines/color),
  [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode),
  [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons),
  [Motion](https://developer.apple.com/design/human-interface-guidelines/motion),
  [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
  (Reduce Motion lives here, not on Motion),
  [Writing](https://developer.apple.com/design/human-interface-guidelines/writing),
  [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
  and [Launching](https://developer.apple.com/design/human-interface-guidelines/launching);
  and [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
  Q16's list is drawn from them.
- Accessibility: [Performing accessibility testing for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app),
  [Performing accessibility audits for your app](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app),
  the [Accessibility Nutrition Labels overview](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)
  and its evaluation criteria for
  [VoiceOver](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria),
  [Voice Control](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-evaluation-criteria),
  [Larger Text](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria),
  [Sufficient Contrast](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria),
  [Dark Interface](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/dark-interface-evaluation-criteria),
  [Differentiate Without Color Alone](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria)
  and [Reduced Motion](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria).
- Apple's user guides (support.apple.com): Eye Tracking on
  [iPad](https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-eyes-ipad2cd35723/ipados)
  and [iPhone](https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-eyes-iph66057d0f6/ios);
  Head Tracking on [iPad](https://support.apple.com/guide/ipad/control-ipad-with-the-movement-of-your-head-ipad06393f31/ipados)
  and [iPhone](https://support.apple.com/guide/iphone/control-iphone-with-the-movement-of-your-head-iph9c3dc17cf/ios);
  AssistiveTouch on [iPad](https://support.apple.com/guide/ipad/use-assistivetouch-ipad9a2466d3/ipados)
  and [iPhone](https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios);
  setting up Switch Control on [iPad](https://support.apple.com/guide/ipad/set-up-and-turn-on-switch-control-ipad93dce3d5/ipados)
  and [iPhone](https://support.apple.com/guide/iphone/set-up-and-turn-on-switch-control-iph400b2f114/ios)
  (Group Items; Focused Item After Tap), and
  [selecting items with it](https://support.apple.com/guide/ipad/select-items-perform-actions-and-more-ipad850ed4e3/ipados)
  (Gliding Cursor, once called point scanning);
  [Multitasking & Gestures settings](https://support.apple.com/guide/ipad/change-multitasking-gestures-settings-ipad-ipad2q9j404h2/ipados)
  (Windowed Apps and Stage Manager; the iPad guide no longer says Split
  View); [Guided Access](https://support.apple.com/guide/ipad/lock-ipad-to-one-app-ipada16d1374/ipados);
  and [the Action button](https://support.apple.com/guide/iphone/use-and-customize-the-action-button-iphe89d61d66/ios),
  which takes the Ring/Silent switch's place on some iPhones.
- Performance: [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
  (100 ms for a discrete interaction),
  [Understanding hangs in your app](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app)
  (most of Apple's tools report from 250 ms; the Hangs instrument can
  be set lower), the WWDC22 session
  [Track down hangs with Xcode and on-device detection](https://developer.apple.com/videos/play/wwdc2022/10082/)
  (Hang Detection's shortest threshold is 250 ms),
  [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)
  (time to first frame; the page names no limit), the WWDC19 session
  [Optimizing App Launch](https://developer.apple.com/videos/play/wwdc2019/423/)
  (a goal of 400 ms to the first frame),
  [Measuring your app's power use with Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)
  (up to 10 hours on the device; overall system power shown as zero
  while charging),
  [Reducing your app's memory use](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use),
  [`ProcessInfo.ThermalState`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)
  and its [`serious`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious)
  case, [Acquiring crash reports and diagnostic logs](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)
  (TestFlight testers share crash reports whatever their settings;
  `JetsamEvent` reports), [`EXC_RESOURCE`](https://developer.apple.com/documentation/xcode/exc_resource),
  and the WWDC23 session [Analyze hangs with Instruments](https://developer.apple.com/videos/play/wwdc2023/10248/)
  (half a second for a response with no other feedback).
- Release: the [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
  (builds testable for 90 days; "continue distributing builds until all
  issues are resolved"),
  [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)
  (a TestFlight Internal Only build cannot be submitted),
  [View tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback),
  the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
  (Before You Submit, 2.1 and 4),
  [App Review](https://developer.apple.com/distribute/app-review/)
  (over 40% of unresolved issues are guideline 2.1),
  [Test your app on compatible devices](https://developer.apple.com/help/app-review/before-submitting-for-review/test-compatible-devices)
  and [Testing a release build](https://developer.apple.com/documentation/xcode/testing-a-release-build).

Four things these pages changed. In the draft: Apple's documentation
gives no launch-time limit, so Q7 first had one second as the project's
default, beside the HIG's "a couple of seconds"; and the HIG asks that
each custom colour have light and dark variants, each with "an
increased contrast option", which Brickson's one value per role, the
same in light and dark, does not have, so Q16 asks for the variants or
a recorded reason. On 2026-11-01: the WWDC19 session's goal of 400 ms
to the first frame replaced Q7's one second, since the bar takes
Apple's number where Apple gives one; and Q14's "Tap Repeat" and "Tap
Help", which had sat among Apple's Voice Control commands, are
Brickson's own extra names for Again and Get Attention, and are now
called that.

### The quotations, checked word for word on 2026-11-01

Each quotation in the bar and in docs/DECISIONS.md, the page it comes
from and the heading it sits under. Every one matched its page word
for word, apart from Apple's curly apostrophes, except where a note
says otherwise.

| Quotation | Page | Under |
|---|---|---|
| "Make improvements to your app and continue distributing builds until all issues are resolved before you submit your app for review" (also in DECISIONS, shortened) | TestFlight overview | the introduction |
| "Apple customers place a high value on products that are simple, refined, innovative, and easy to use" | App Review Guidelines | 4. Design |
| "Switch Control isn't available on Simulator" | Performing accessibility testing for your app | Test with assistive technologies, Switch Control |
| "in a variety of conditions before submitting" | Testing a release build | Overview |
| "regardless of the device settings" | Acquiring crash reports and diagnostic logs | Collect crash reports from TestFlight and the App Store |
| "100 ms is the maximum delay for discrete user interaction before a delay becomes noticeable" | Improving app responsiveness | Write performance tests to ensure main-thread-bound code completes fast |
| "If you have a request-response style interaction, 500 ms without any additional feedback might be OK" | WWDC23, Analyze hangs with Instruments | the transcript, at 5:43 |
| "the time to first frame" | Reducing your app's launch time | Reduce the complexity of your initial views |
| "rendering our first frame within 400 milliseconds" | WWDC19, Optimizing App Launch | the transcript, at about 5:00 |
| "don't want to wait more than a couple of seconds" (also in DECISIONS) | HIG, Launching | Best practices |
| "the device's current orientation and appearance mode" | HIG, Launching | Launch screens |
| "Even temporary flashes of bright content may cause discomfort" | Dark Interface evaluation criteria | Goals; said of a dark interface, so Q7 now pairs it with the HIG's line above for light and dark |
| "reduces performance" | `ProcessInfo.ThermalState.serious` | Discussion |
| "about a foot and a half away from your face" | Eye Tracking user guides, iPad and iPhone | Before you begin |
| "A user can perform all tasks within your app using only Switch Control" | Performing accessibility testing for your app | Diagnose and address accessibility issues; Apple gives it for VoiceOver, Voice Control and Switch Control, and Q14 now says it applies it to the rest |
| "Show names", "Show numbers" | Performing accessibility testing for your app | Test with assistive technologies, Voice Control's commands |
| "Determine layout based on size classes, not device type or orientation" | HIG, Layout | Size classes |
| "Don't use Liquid Glass in the content layer" | HIG, Materials | Liquid Glass |
| "describe gestures correctly on each device" | HIG, Writing | Best practices |
| "almost always" (best to use a verb) | HIG, Writing | Best practices |
| "an increased contrast option" (this record) | HIG, Color | Best practices |
| "placeholder text, empty websites, and other temporary content should be scrubbed" (also in docs/APP-STORE.md) | App Review Guidelines | 2.1 App Completeness |
| "make sure to run an audit for each of the screens in your app" | Performing accessibility audits for your app | Run an audit for every screen |
| "users must be able to complete all of the common tasks of your app using that feature" | Accessibility Nutrition Labels overview | Planning for your responses |
| "eliminating all audit issues that Accessibility Inspector reports doesn't guarantee a fully accessible app" | Performing accessibility audits for your app | Add audits to your UI tests |

## Commits

- f774a1f: the quality bar, its decision, and the lines of the other
  documents that point to it.
- 9c647ae: CodeRabbit's review answered (Q27 named in the before-pilot
  list, no standing urgent-fix exception, the owner's hazard step
  matching Q2, docs/APP-STORE.md's device line, and this record's
  header and *Not verified*).
- 321810e: Codex's review answered. Q3 no longer lets the owner accept
  a window where the starter library scrolls, which would have been a
  new exception to invariant 11; that scrolling is removed before App
  Review.
- 6014a4d: CodeRabbit's second review answered (the Q5 device-check
  row names TestFlight's crash feedback), and this list corrected to
  one line per commit.
- 5baac9b: a final check's findings. R0's *Release
  gate* named three dwell hazards where Q2 names five; Q22's *Today*
  left out the alarm state's audits at AX5 and in the iPad's landscape
  (`GetAttentionOnHomeTests`); and this record listed fewer of the
  checks that ran than it said.
- ea0fd12: CodeRabbit's third review answered.
  docs/HANDOFF.md, docs/APP-STORE.md and docs/SDLC.md said that no
  build goes to App Review before the whole bar passes, without the
  owner's call on one urgent fix that docs/DECISIONS.md and the roadmap
  record; each now points to it.
- 8404f84: the owner's answer to Q9 (2026-11-01) recorded in
  docs/DECISIONS.md, the roadmap's Q9 and Q24, docs/HANDOFF.md and
  docs/APP-STORE.md. The owner said there was no rush and that it could
  go in this pull request, rather than in a follow-up, after CI was
  green.
- 77df227: a full second check on 2026-11-01 of every
  *Today* line against the code, and of every quotation and statement
  about Apple against Apple's pages fetched that day (*Verified*), with
  GitHub Copilot's review of 8404f84. What it corrected: *Today* lines
  that were wrong (Q5's "no device build", Q15's undrawn library
  screens, Q22's emergency-state audits) or left out what a reader
  needs (Q2, Q3, Q7, Q10, Q19, Q20, Q23); Q7's first frame from one
  second to Apple's 400 ms goal; Apple's current names (Silent mode and
  the Action button, Gliding Cursor, Windowed Apps, Xcode's Crashes
  organizer, `EXC_RESOURCE` and `JetsamEvent` reports); a build changed
  after the pilot going back to the pilot and the owner for seven days
  (Q27, Copilot), uploaded as an ordinary build since a TestFlight
  Internal Only build cannot be submitted (Q9); Q29 naming the
  urgent-fix call (Copilot); Q25 checked before the pilot rather than
  by it; the owner's steps in docs/HANDOFF.md asking for the build that
  ships and naming Get Attention in Settings' bar; docs/APP-STORE.md's
  pilot condition and submit step naming the bar; and this record's
  page list, now with every page linked and the quotations' table.
- The commit after 77df227: this record's line on 8404f84's UI tests,
  which said the next push had stopped them; they had finished, with
  the one iPad failure *Verified* now describes.

## Verified

- In the cloud container on 2026-10-30, 2026-10-31 and 2026-11-01, the
  last on the final documents: `python3 scripts/test-docs.py` (45 tests, OK; every cited
  section title and relative link resolves, though it does not check
  the wording), `scripts/test-hooks.py` (124 tests, OK),
  `scripts/test-site.py` (7, OK), `scripts/test-runner.py` (56, OK)
  and `scripts/test-select-xcode.py` (23, OK).
- GitHub CI on 6014a4d (run 41130391375, Xcode 27.1): the unit tests
  passed (823 ran, 0 failed). The UI tests failed once, only in the
  first iPad test, on "kAXErrorServerNotFound" after a 60-second
  automation setup, the startup failure docs/HANDOFF.md records. A
  single re-run of that job passed on the iPad and the iPhone 17.
- GitHub CI on ea0fd12 (run 41152170391): the unit and UI tests passed
  on the first attempt. On 8404f84 (run 41272443216) the unit tests
  passed in 38 minutes, close to the job's 40-minute limit (AGENTS.md,
  *Gotchas*). The UI tests passed on the iPhone 17 (61 ran, 0 failed)
  and failed one iPad test as it launched the app: the test runner could
  not close the app left by the test before it ("Failed to terminate",
  `FoldOffsetUITests`, light mode, the second test of the run). That is
  the failure [the 2026-10-23 record](2026-10-23-accessibility-page-and-privacy-trim.md)
  met on the iPad, in code this pull request does not touch, and its
  cause is not established. The next commit's run tests the same code.
- Every quotation from Apple in the bar, docs/DECISIONS.md and
  docs/APP-STORE.md's changed lines was checked on 2026-10-30 against
  the text copied from its page, and again on 2026-11-01 against each
  page fetched that day: each matches word for word, apart from Apple's
  curly apostrophes (the table above). The second check found two
  phrases set among Apple's that were Brickson's ("Tap Repeat", "Tap
  Help"), one said only of a dark interface ("Even temporary flashes"),
  and one that asks for the release build to be tested, not only built
  ("in a variety of conditions"); each is now worded for what it is.
- On 2026-11-01, 97 statements about what Apple says or how its tools
  and settings work, other than quotations, were checked against the
  same pages: 75 held as written, and the 22 that were partly off (a
  name Apple has since changed, a tool or report named loosely, a
  rule of Brickson's presented as Apple's, a number Apple does give)
  are corrected.
- Every *Today* line was checked against `main` at `9fe02ef` on
  2026-10-30, and again on 2026-11-01 against the same code, by two
  agents reading the tests, the views and the records: of 61 items
  (the 29 *Today* lines, the R0 *Release gate*, and the lines this pull
  request added to docs/HANDOFF.md, docs/DECISIONS.md, docs/APP-STORE.md,
  docs/SDLC.md and AGENTS.md), 40 held, 6 were wrong and 15 left out
  something a reader needs; each is corrected. Q22's list is now every
  call to `assertPassesAccessibilityAudit` in `BricksonUITests` with the
  appearance, text size and device it runs at; Q23's is every
  `RenderedWords` check; Q2's hazards and Q3's windows are those in
  docs/HANDOFF.md, *Known gaps* and *Verification*. A third agent
  checked the documents against each other (counts, gate numbers,
  dates, the owner's answers, the urgent-fix rule) and found 17
  smaller mismatches, also corrected.
- A review pass by a second agent, reading the change cold before the
  pull request opened, found contradictions and checks too loose to
  pass or fail; each was fixed then (the urgent-fix rule, the
  before-pilot list, five hazards rather than three in Q2, the *Today*
  lines of Q1, Q3, Q22, Q23 and Q29, and pass conditions for Q5, Q6,
  Q8, Q13 and Q14), except that docs/HANDOFF.md's owner step and R0's
  *Release gate* still said three hazards until 9c647ae and 5baac9b.

## Not verified

- No app build, device run or gate was run: this pull request changes
  documents only, and CI is the app's check. Outside CI, only the
  Python checks above ran.
- Apple's pages themselves are not kept in the repository (they are
  Apple's); the table above keeps each quotation's page and heading, so
  checking again means fetching that page from the list.
- CI on the final commit is shown on the pull request, not recorded
  here: a record cannot name the result of the commit that adds it.
- No gate has passed. Every *Today* line describes R0 as it stands; none
  is a measurement made by this pull request.
- The numbers the project chose (50 ms between releases, eight hours,
  two hours per input method, 1 in 20 misses at the floors, three
  first-time people), and its use of Apple's half second and 400 ms as
  pass limits, are defaults, not measurements; the first device runs
  may show that one should change.

## Follow-ups

- *(next Settings thread)* Measure which floors Settings' controls hold
  under a larger profile and put it to the owner (Q3).
- *(a docs pass)* The stale "untested until CI runs it" lines (Q26),
  listed in [`2026-10-30-sizes-switched-on.md`](2026-10-30-sizes-switched-on.md),
  *Follow-ups*.
- *(a thread)* Two gates can start now in the cloud, since neither
  waits for a device: Q18, listing every number and colour written
  straight into view code, and Q16, the pass against Apple's
  guidelines screen by screen.
- *(a thread, before the owner's first device run)* Write the
  step-by-step procedure for each owner gate, with what success looks
  like.
- *(each pull request)* Edit a gate's *Today* line when the change
  moves it.
