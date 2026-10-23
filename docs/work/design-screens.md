# Screen design reference

*Roadmap: R0 item 9. Owner: the design work, with the Home, typing,
Settings and Library implementation work. Status: spec; drawings need
corrections and the affected flows are not yet ready for implementation.*

## Intent

- **Problem:** implementation work needs one reviewable reference for
  screen states, standard controls, fixed positions and measured colours.
  Drawings alone do not show what a held activation meets next or prove
  that a keyboard leaves communication controls reachable.
- **Outcome:** a specification alongside [DESIGN.md](../DESIGN.md) that
  distinguishes the landed decisions, the drawings and unresolved work.
  This documentation changes no app behaviour.
- **Who and what it affects:** people using touch, VoiceOver, Voice
  Control, Switch Control, Full Keyboard Access, AssistiveTouch with
  Dwell, head tracking or Eye Tracking; Home and the family screens.
- **Constraints:** AGENTS.md's invariants bind. The decisions in
  [DECISIONS.md](../DECISIONS.md), especially "Home's slot plan", "Typing
  is a state of Home", "Settings is a cover with a fixed safety bar" and
  "Solid fills on Home, system glass elsewhere", win over drawings.
- **Open questions:** the concerns below retain their owning work and
  block the affected flow's design gate. No exception to an invariant is
  accepted here, and no app identity or price is decided.

## Spec

### States and positions

For a given window, input profile and text size, the landed slot plan
fixes Home's regions in the order A, C, B, D. A holds the message and
reserved status line, then Phrases above Type at the trailing edge; C
holds Emergency, Yes, No, Again/Speak and Get Attention; B holds Stop
Alert's well, the category slots and Settings at the trailing end; D
holds phrase slots. "Home's slot plan" specifies the compact and regular
arrangements. Text size and the space available may size the frames;
changing state never moves them. The wells are not built in today's app.

| State or transition | Required behaviour and frames | Repeated activation and remaining proof |
|---|---|---|
| Browse, each everyday category | Each phrase speaks on its first activation. Category slots and phrase positions stay fixed; the largest category determines rows. | A repeated category selection changes nothing. A phrase already speaking is absorbed by `SpokenUtteranceTracker`; after it finishes the phrase may speak again. |
| Emergency, from every Home state | Emergency in C opens emergency phrases in D immediately and exits edit mode; no editor opens from an emergency phrase. | Emergency stays in its place, so a repeat selects the same category; the next phrase speaks immediately. Pin this across browse, typing and alarm. |
| Phrase speaking, finished, interrupted or failed | The message remains in A. Speaking and audio warnings use its reserved status line. Again is reachable in C under the future slot plan. | No automatic restart after an interruption; the named reachable retry control starts it. Sound and route recovery require a device. |
| Typing, empty or nonempty draft | Type selects typing; the draft occupies A's message frame, Again's well shows Speak, and Phrases remains above Type. Return is another speak path. | Type and Phrases each select only their own mode, so a repeat stays on that control. Repeated active speech is absorbed. |
| Keyboard shown, hidden or changed | The keyboard covers the lower Home; no frame reflows. Emergency, Get Attention, Yes, No, Speak and Phrases remain above the measured worst-case keyboard. | Hiding the keyboard reveals no speaking control while typing. The zoomed iPad band does not fit the drawing; that state remains blocked. |
| Draft cleared, restored or save failed | Clear and Put Back take separate fixed B slots, away from the draft, Speak and the keyboard edge; failure text uses reserved space. | Clear cannot become Put Back in place. Exact slots and chains past Stop and Settings are unresolved; the drawing is not approval to build them. |
| Alarm sounding or stopped, with browse or typing | Get Attention in C only starts. Stop Alert has a separate B well below Emergency. Phrases can still speak. | Get Attention stays start-only. After Stop's well empties, the drawn chain reaches a category or Emergency, never Settings; verify the implemented geometry for each state. |
| Settings root and every family destination | One full-screen cover keeps the same Back to Talking and start-only Get Attention bar, with reserved passive audio status. Get Attention's well remains empty until Home has Stop. *2026-10-23:* Home has Stop (PR #38); the well stays empty until its chain is scored (docs/DECISIONS.md, "Get Attention and Stop on Home"). | Back closes the cover. Its exact landing target on Home and full chains through family navigation remain unresolved, below. |
| Family Setup and guides | Standard navigation under the safety bar; choices select one value, with clear/reset elsewhere. Privacy shows the bundled policy and separately opens its web sheet. | A repeat after opening Family Setup may snap to another navigation row; the complete entry-to-setting chain must be scored. |
| Voice selection, sample, speed or permission status | Follow landed Settings and Personal Voice decisions. Samples and choices are separate; speed uses fixed choices. On one visit, existing voice rows keep their places, arrivals append, and departed rows become words with no active buttons. | A sample never changes the selected voice. The card's ready-to-turned-off text growth remains an open gap, not a claim of complete frame stability. |
| Ask offered, waiting for iOS, answered, then a new visit | PR #27 builds Ask to Use Personal Voice under `.fromSettings`; the production policy remains `.atLaunch` until D1. Reserve every answer's text; replace the used button with passive text at its size; show no new card button on that visit. Reopening may restore the appropriate settings action. | A second press while waiting asks nothing more; hold Settings' idle reset while iOS asks. The real system-question return chain and device behaviour remain unverified, even though the stand-in UI test checks fixed frames after refusal. |
| Library list, category phrase list, add/edit, save failure, delete/keep/confirm, import/export | Drawings show appearance only. The future flow needs the missing phrase list and Add Phrase route, separate edit mode, reserved failures, Keep in the asking control's place and confirmation away from repeated activation. | Score the whole entry-to-dismissal chain, including return to the original pointer position. No editor/delete/import flow is approved by these drawings; Replace remains refused until safety copies exist. |

Every combination of typing and alarm uses the same Home slots. Emergency
must be checked from each combination, not only from browse. Library
screens remain in the family cover, not an edit mode placed on Home.

### Input methods

All paths use standard SwiftUI Buttons or system controls, with visible
names, accessibility labels and profile target floors. No custom input
recognizer or tracking is introduced.

| Input method | Reach and activation | Check required |
|---|---|---|
| Touch and VoiceOver | Tap a standard control; VoiceOver focuses the control and activates it through the system. | First-activation speech; visible and spoken names; VoiceOver order and warnings without focus changes. |
| Voice Control | Use the visible words first, with declared aliases such as Repeat for Again. | Every Home state has unambiguous names, including user-added words checked for collisions without renaming them. |
| Switch Control | System item/group scanning reaches the standard controls; Home begins with Yes, No and Emergency. | Group Items and Auto Tap on a device; repeated auto-selection follows the chains in the table. |
| Full Keyboard Access | System focus reaches the same controls and activates them; typing also offers Return to speak. | Focus order, reachability and whole labels in every state, without intercepting system input. |
| AssistiveTouch with Dwell | The system pointer selects standard targets and can repeat while resting. | Score nearest-centre and nearest-edge chains, then measure actual snapping and dwell on a device. |
| Head tracking | Apple's pointer reaches the same targets and dwell paths. | Floors, gaps, resting positions and the full chains with the actual system input method. |
| Eye Tracking | Apple's Eye Tracking and Dwell reach the same targets. | Device calibration, Snap to Item, hot corners and reading/resting positions; simulator geometry proves none of these. |

Home's landed scan priorities and regions remain authoritative. The
geometry in DESIGN.md is calculated reference material; it does not
establish VoiceOver order, switch groups or Snap to Item behaviour.

### Invariants, colours and privacy

| AGENTS.md invariant | How the specification keeps it |
|---|---|
| 1, standard controls and targets | Every activation uses a standard control; the engine owns sizes, never a device-specific branch or custom tracking. |
| 2, first activation and Emergency | Phrase speech has no confirmation; Emergency remains in the fixed safety band from every Home state. |
| 3 and 5, edits and failures | Speaking changes no data; family editing and confirmations are explicit, with failure tests for each save and reserved visible errors. |
| 4, audio survives | The shared audio policy owns playback, visible warnings and reachable retry; the design adds no resume behaviour. |
| 6, contrast | Adopt solid role colours only with `PaletteTests` pins; measure system components from rendered captures before accepting glass. |
| 7 and 9, words and privacy | No new starter language, generated replies, storage, network code, accounts or packages. The documentation changes no privacy-policy promise. |
| 8 and 10, positions and dwell | State does not move slots; start/stop and clear/recovery stay apart; all unresolved chains below remain blocked. |
| 11, starter library and keyboard | No smaller profile floor or newly accepted scrolling fallback; the layout engine must resolve the stated fit conflicts. |
| 12, screen wake | `ScreenWakePolicy` remains unchanged; long-session device verification remains required. |

The complete pairs and ratios are in DESIGN.md, *Colour*. Existing fills
are phrase `#0A60D6`, control `#5A6474` and emergency `#C8161E`. The
proposed additions are attention `#B45309`, stop `#0F766E` and field edge
`#767676`, with white control labels, primary ink for passive text and
the documented light/dark field and background pairs. No new colour is
in the app through this PR. Text must reach 4.5:1 and edges 3:1 in light,
dark, Increase Contrast and Reduce Transparency, including system screens.

### Screens and acceptance

The [Figma design file](https://www.figma.com/design/zCYdh8hSJ9ZmrVhtealp8f)
contains the reference groups below, as documented by the design work on
2026-10-21. This reconciliation did not re-open or redraw the file. Exact
frame deep links and corrected captures must be recorded by the owning
screen work before its first implementation commit; the file link and
page/state names identify the existing reference without inventing nodes.

| Figma page and frame groups | State coverage | Acceptance status |
|---|---|---|
| Foundations: colours, type ladder, slot sizes | Light/dark tokens and default/AX5 reference sizes | Computed reference; new palette pins and rendered system measurements pending. |
| Home: iPhone windows, iPad portrait/landscape, comparison frames | Browse, typing and alarm in light/dark and AX5; overlays compare states | Earlier drawings need the corrections listed in DESIGN.md and this spec. Zoomed-keyboard and profile-floor conflicts remain open. |
| Settings and Library: Settings root, Family Setup, Voice | Cover and family navigation on phone and iPad landscape | Root and Voice drawings differ from landed decisions, including PR #27's Ask/answered states; bundled Privacy screen and complete navigation-chain evidence pending. |
| Settings and Library: Library, phrase editor, delete question | Appearance of list, edit and confirmation | Appearance reference only; category phrase list, Add Phrase, import/export and complete safe flow still needed. |

The owner accepts a design by merging its PR. This PR records the
reference and its limits; it does not claim acceptance of withdrawn
frames, a passed design gate for unfinished flows, or device evidence.

### Concerns and owning work

1. **Home/Settings exit:** main's slot plan puts Back to Talking over the
   whole trailing column, where the historical scores tie Phrases and
   Type. DESIGN.md proposes Phrases alone. Keep the binding decision
   unchanged here; the next Home/Settings work must reconcile it, score
   entry/exit and record the correction before relying on that chain.
2. **Message-border hazard:** Yes and No can be nearest the message.
   Main records this as open, not accepted. The layout engine removes it
   by placement or submits its measured cost for an owner decision before
   the slot plan ships with dwell, switch, head or gaze input.
3. **Profile floors and keyboard band:** the drawn phone gaze stack and
   zoomed iPad keyboard band do not fit. The layout engine measures them
   and resolves the conflict; this PR lowers no floor or safety rule.
4. **More categories:** the future B region has no path to a fifth
   everyday category. Editing/import cannot add one until the layout
   engine provides a reachable, fixed arrangement.
5. **Typing Clear/Put Back and family editing:** the owning screens work
   fixes slots and scores full chains, including failures and dismissal.
6. **Voice Settings:** PR #27's Ask state is built but production still
   asks at launch. Before `.fromSettings` ships, complete D1 and score
   the chain through iOS's real question. Longer card words and a passive
   note when Automatic changes Personal Voice remain the next Settings
   work's follow-ups; the historical drawings prove neither.
7. **Artwork and evidence:** design work corrects frames and supplies
   exact links; implementation work pins geometry/colours and measures
   the running app. Physical input and sound checks stay in HANDOFF's
   device table. Release chores own the app icon.

## Plan

This PR is documentation only. DESIGN.md records the reference;
DECISIONS.md records only its solid-fill choice while preserving landed
choices; ROADMAP.md reports partial status; HANDOFF.md points here;
the dated reconciliation log records the evidence.

For each later screen: resolve its concerns, update this spec and its
own work plan, correct/link its frames, add a failing test, then implement
and verify on both simulator families. Keep the complete unit suite green
before committing and the required CI checks green before the owner
merges. No app code or generated Xcode project is changed by this plan.

The proof must fail if a safety control moves or is covered, a first
activation does not speak, a new pair misses contrast, a starter tile
escapes its allowed viewport, a repeat reaches a harmful control, or a
save failure changes data partially. Existing tests cover only their
current stand-in states; future typing/alarm/editor states need their own
reproductions. Device checks establish sound, actual input paths and
pointer behaviour. A green simulator run does not close those concerns.
