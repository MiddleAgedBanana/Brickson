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
  are open: the three already recorded, Again nearest Stop's empty well
  in a library with fewer than three everyday categories, and iPhone
  Duo's AX5 chain from Family Setup); every floor named; every device
  check the release touches, sound first; no crash and no hang.
- **It feels right in the hand** (Q6 to Q10): the default voice
  speaking within half a second (the median of ten activations), a
  first frame within one second that comes back as it was, a whole day
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

Each gate has a *Today* line for R0 on 2026-10-30, so the distance to
App Review is visible; pull requests that move a gate edit that line,
and AGENTS.md, *Workflow rules*, now says so.

How the bar runs: every gate passes before App Review; before the
external pilot, every gate passes except those that need the pilot
or the final build (Q5's whole TestFlight period, Q9's last seven days,
the testers' sessions in Q11 and Q13, Q27, the pilot itself, Q28 and
Q29), and the owner's
device gates run on the internal TestFlight build first. A thread
writes the step-by-step procedure for each owner gate before the
owner's first device run. A later release reruns the gates its changes
touch, and always Q9, Q21 and Q29. An urgent fix after a release (a
phrase that does not speak, a crash) passes the whole bar too, unless
the owner, when one is needed, decides that this fix goes sooner;
docs/DECISIONS.md records a recommendation for that moment, not a
standing exception.

The decision is recorded in docs/DECISIONS.md, "Every release passes
the quality bar": the bar is the owner's; the gates, their numbers and
who checks each are defaults the owner can change. One gate waits on the
owner: how long the owner lives with each TestFlight build (Q9),
recommended at two weeks before the pilot and seven days on the exact
build before App Review, now a row of *Waiting on the owner*.

What it folds in, already open before today: the three dwell hazards
(Q2), Settings' floors under a larger profile, which were only in a
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

Read on 2026-10-30 as Markdown (the page's path with `.md` appended):

- Human Interface Guidelines: [Layout](https://developer.apple.com/design/human-interface-guidelines/layout),
  [Materials](https://developer.apple.com/design/human-interface-guidelines/materials),
  [Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
  [Color](https://developer.apple.com/design/human-interface-guidelines/color),
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
  and its evaluation criteria for VoiceOver, Voice Control, Larger Text,
  Sufficient Contrast, Dark Interface, Differentiate Without Color Alone
  and Reduced Motion; Apple's iPhone and iPad User Guides for Eye
  Tracking, Head Tracking, AssistiveTouch and Switch Control
  (support.apple.com).
- Performance: [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
  (100 ms for a discrete interaction),
  [Understanding hangs in your app](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app)
  (tools report from 250 ms),
  [Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)
  (time to first frame; no limit in milliseconds is published),
  [Measuring your app's power use with Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)
  (up to 10 hours on the device; zero while charging),
  [Reducing your app's memory use](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use),
  [`ProcessInfo.ThermalState`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum),
  [Acquiring crash reports and diagnostic logs](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)
  (TestFlight testers share crash reports whatever their settings), and
  the WWDC23 session [Analyze hangs with Instruments](https://developer.apple.com/videos/play/wwdc2023/10248/)
  (half a second for a response with no other feedback).
- Release: the [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
  (builds testable for 90 days; "continue distributing builds until all
  issues are resolved"),
  [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers),
  [View tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback),
  the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
  (Before You Submit, 2.1 and 4),
  [App Review](https://developer.apple.com/distribute/app-review/)
  (over 40% of unresolved issues are guideline 2.1),
  [Test your app on compatible devices](https://developer.apple.com/help/app-review/before-submitting-for-review/test-compatible-devices)
  and [Testing a release build](https://developer.apple.com/documentation/xcode/testing-a-release-build).

Two things these pages changed in the draft: Apple publishes no launch
time limit, so Q7's one second is the project's default, beside the
HIG's "a couple of seconds"; and the HIG asks for an increased-contrast
variant of each custom colour, which Brickson's one value per role does
not have, so Q16 asks for the variant or a recorded reason.

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
- The commit after 321810e: CodeRabbit's second review answered (the
  Q5 device-check row names TestFlight's crash feedback), and this
  list corrected to one line per commit.

## Verified

- `python3 scripts/test-docs.py`: 45 tests, OK, in the cloud
  container on 2026-10-30. It checks that every cited section title and
  relative link resolves; it does not check the wording.
- Every quote from Apple in the bar and in docs/DECISIONS.md was
  checked by script against the text copied from its page on
  2026-10-30, word for word apart from typographic apostrophes and
  quotation marks.
- Every *Today* line was checked against `main` at `9fe02ef`: Q22's
  list is the calls to `assertPassesAccessibilityAudit` in
  `BricksonUITests` (Home light and dark at the default size and AX5 in
  `LaunchTests`; Settings, Family Setup and the privacy policy light and
  dark in `SettingsTests`, and again over the larger Home in
  `HomeSizesTests`; the emergency and alarm states, Voice Settings, the
  guides and the step-by-step setup in light only); Q23's is the
  rendered-label checks in `LaunchTests` and `HomeSizesTests`; Q2's
  hazards and Q3's windows are those in docs/HANDOFF.md, *Known gaps*.
- A review pass by a second agent, reading the change cold, found
  contradictions and checks too loose to pass or fail; each was fixed
  before the pull request opened (the urgent-fix rule, the before-pilot
  list, five hazards rather than three, the *Today* lines of Q1, Q3,
  Q22, Q23 and Q29, and pass conditions for Q5, Q6, Q8, Q13 and Q14).

## Not verified

- No app build, device run or gate was run: this pull request changes
  documents only, and CI is the app's check. Only the Python document
  and guard checks above ran.
- No gate has passed. Every *Today* line describes R0 as it stands; none
  is a measurement made by this pull request.
- The numbers the project chose (half a second to the first sound and
  50 ms between releases, eight hours, two hours per input method,
  1 in 20 misses at the floors, three first-time people, the TestFlight
  weeks) are defaults, not measurements; the first device runs may show
  that one should change.

## Follow-ups

- *(owner)* How long to live with each TestFlight build (Q9): the card
  in the thread, or docs/DECISIONS.md, *Waiting on the owner*.
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
