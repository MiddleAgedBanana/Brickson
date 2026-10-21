# Options memo: editing, backup and restore of the phrase library

> **Research snapshot, 2026-10-15/16, committed 2026-10-21.** Written on the owner's Mac against `main` at `9362eca`; local paths and personal details were removed before it was committed. It is research, not instructions: its recommendations are proposals until `docs/DECISIONS.md` records the owner's choice, and where it disagrees with `AGENTS.md`, `docs/DECISIONS.md` or `docs/ROADMAP.md`, those win. Facts about CI, Xcode and simulator versions describe that date.

Prepared 2026-10-16 for the owner, via the coordinator. Planning only: I changed nothing in the repository, built nothing, and did not touch the uncommitted AGENTS.md, LaunchTests and test.sh edits. (git status also shows the untracked synthesis, now [README.md](../README.md), and docs/recon/2026-10-15/; those are not mine.) Working notes and the draft are in the scratchpad (memo-full.md, research-notes.txt); this message is the complete memo.

How to read the evidence tags:
- [repo] read in this worktree.
- [opened] a web page I opened and read.
- [snippet] seen only in a search-result summary, not opened. Treat as a lead, not a fact.
- [Apple docs via Context7] Apple documentation text returned by the Context7 index. I did not fetch developer.apple.com directly (AGENTS.md forbids it).
- [unverified] my own inference. It needs a build, CI or a physical device.

I could not read the reference app, so I do not know what its decisions D24 and D25 say (docs/PORTING.md, step 6: "Build D24 and D25 here"). Someone with access should paste them before the editing screens are designed, in case they contradict anything below.

---

## 1. Short version

1. Smallest safe start, needing no screen and no Home change: a pure "library edit" type that validates every change and is applied in one explicit save; a failure-injection test for every kind of change; a backup codec with its own format name, version number and byte-level round-trip tests; and a SwiftData behaviour test that settles how deletes and failed saves behave on iOS 26. All of that serves any screen we pick later.
2. Where editing lives: put it in a Library reached from Settings (the family area) and leave Home's behaviour alone for 1.0. A Home edit mode is possible later as a thin layer on the same core, but it needs the layout engine and the chain-scoring harness first, cannot edit emergency phrases (they must never open editors), and its editor cannot be an ordinary sheet (a sheet covers Emergency, Yes and No).
3. No PIN or hidden path. What the apps I read do about a lost lock: Proloquo2Go asks a security question and then points to email support; TD Snap's own support page publishes a master code; TouchChat's page says nothing about a lost passcode; a search summary (not verified) says LAMP Words for Life needs a reset. For someone who can only dwell, a PIN pad is itself a typing task, and a forgotten PIN has no good exit. Use placement (family area behind Settings, a large way back), and document Apple's Guided Access as the optional hard lock once it is checked with Eye Tracking on a device.
4. Make the emergency category structurally undeletable, with exactly one such category and at least one phrase in it. That keeps Emergency enabled, makes the refill-an-emptied-library question almost disappear (an empty store can then only mean first launch or storage loss), and simplifies import to "end with exactly one".
5. Backup: one JSON file, internal format name plus integer version, array order as the order, uuids kept, categories and phrases only. Export through a share sheet; import only through the system file picker from inside the family area. Do not register a document type in 1.0 (a file arriving by AirDrop or Files "Open in" could bring up an import question over Home). Merge only appends and is idempotent; import never renames, trims or drops a word; replace is allowed only over a library that holds nothing the person wrote, or after an automatic safety copy.
6. Invariants 3 and 7 collide over "Replace". Invariant 3 allows Replace if the app asks first; invariant 7 says import may never delete the person's own words. The owner has to say which reading is meant (section 5.3). Until then, plan for the safety copy.
7. Two facts from the code audit, which I folded in: the main context's autosave is on by default, so every save must be made explicit before any editing exists (section 4.2); and an undeletable emergency category is weighed as option E1 (section 4.6).
8. Things only a Mac or a device can settle are listed in section 9. The first is whether deleting a category and its phrases is safe to save and to recover from on iOS 26.
9. The owner decisions are in the table in section 8. This short version plus that table can be relayed on its own.

---

## 2. Facts from the repo that separate the options

1. Emergency is load-bearing. [repo] `QuickControlsRow` disables the Emergency button when `CategorySelection.emergency(in:)` finds no category with `isEmergency`. That function returns only the first such category, while `shownInCategoryRow` hides every emergency category. So (a) deleting the emergency category disables Emergency; (b) a second emergency category, from a merge, an import or a hand-edited file, has phrases nobody can reach (not in the row, not what Emergency opens); (c) an emergency category with no phrases opens an empty grid, so Emergency "works" and says nothing. Editing must refuse the first and third; import must end with exactly one, by appending incoming emergency phrases to the existing one.
2. Invariant 3 allows Replace if the app asks first; invariant 7 says "Nothing (repair, migration, import) may delete a person's own words." Replace deletes whatever the person wrote that is not in the backup. Section 5.3 sets out the ways out.
3. The privacy policy makes promises that features could falsify. [repo, site/privacy/index.html]
   - "Delete a phrase or category in Brickson, and it is gone from the app." and "It stays until you delete it in the app or delete the app." An automatic snapshot, or a Recently Deleted list, falsifies these.
   - "If you export a backup, Brickson makes a file with your categories and phrases." Putting settings, the draft message or a device name in the file falsifies it.
   - Registering a document type means AirDropped files land in the app's own Documents/Inbox [Apple docs via Context7, application(_:open:sourceApplication:annotation:)]. That is a second copy of the person's words in app storage that the policy does not mention.
   - Any change updates site/privacy/index.html and its Effective date (currently October 12, 2026) in the same pull request (AGENTS.md, "The privacy policy is a promise").
4. Autosave. [Apple docs via Context7, ModelContext.autosaveEnabled] The default is false, but SwiftData sets it to true for the container's `mainContext`, and the context "also calls save() at various times during the lifecycle of windows, scenes, views, and sheets." `BricksonApp` attaches the container with `.modelContainer(container)`, so Home's `@Query` and anything using the environment's context share an autosaving main context. The seeder avoids this by using its own context with autosave off. Consequence: if an edit is applied in the main context and the explicit save then fails, the half-applied change is still pending there and a later sheet dismissal or scene change may save it. See section 4.2.
5. Deletes are unproven on iOS 26. [repo] docs/LESSONS.md says neither half of "`.nullify` plus explicit phrase deletes in one save" is proven, and that a delete saved from a separate context made the main context crash on the next read of the deleted phrase. [snippet] Apple Developer Forums threads report the same family of crash on current systems: "Fatal error on rollback after delete" (https://developer.apple.com/forums/thread/820173: rollback() after deleting a parent that has children, "Unexpected backing data for snapshot creation", Xcode 26.4 and the iOS 26.4 simulator, no resolution seen), and several "model instance was invalidated" reports for objects deleted elsewhere (threads 800316, 771431, 808237). These are risk signals only. [repo] `HomeView` holds `PhraseCategory` objects from `@Query` and reads `category.phrasesInOrder` (the relationship array) inside a `ForEach`, which is the pattern those threads blame. [unverified] That is a candidate crash site the first time something deletes while Home is on screen.
6. Position is not device-independent today. [repo] `PhraseGrid` uses 3 columns in regular width and 2 in compact, so the same `sortOrder` lands in a different cell on an iPad and an iPhone (and on a narrow iPad window). Deleting a phrase also shifts every later tile up the list. Both are questions for port step 4 and the layout-blueprint direction; I name the interface in section 6 and do not solve it.
7. The pre-1.0 window is narrower than it looks. [repo] docs/DECISIONS.md, "Versioned storage", says "never edit V1" with no exception, and every later version must migrate from "whatever 1.0 ships". The app is 0.1.0 and has not shipped, so the owner could record an exception, but only until the first build reaches anyone: a store already on any device (the owner's, a simulator, a TestFlight build; the privacy policy already describes TestFlight) would stop opening, or need a migration, if V1 changed under it. So a new stored field that editing might need (a slot with gaps, a deleted-at marker, a seed marker) is cheap only before that first build, and it is an owner decision with a date, not a free option (owner table, item 17). LESSONS ("Add stored fields with their feature") still applies: add such a field in the same pull request as the feature that reads it. Fixed uuids for starter items are different: the models already have a `uuid`, so that is a change to the bundled data and the seeder, not to V1, and it is safe at any time; stores seeded earlier keep their random uuids and are simply treated as holding the person's own words.
8. The seeder's own comment rejects a stored "already seeded" flag, because a flag can outlive the store (a lost file, the in-memory fallback) and leave an empty board. [repo, StarterLibrary.swift] Any re-seeding option is judged against that.
9. System alerts and confirmation dialogs choose where their buttons go, so "Keep takes the asking control's place" cannot be met with them, and LESSONS measured a system destructive button at 2.71:1 against the 4.5:1 floor. Confirmations are built in the app, inline.
10. Order of work is constrained. Get Attention is not ported (port step 1), Settings is not built (step 7), the layout engine is not built (step 4) and the chain harness is not built (step 8). A Library without Get Attention in its safety bar would be an edit-time hole; the owner already accepted "no Get Attention yet" only for Home version 0.
11. The in-memory fallback. [repo] When the store cannot be opened or filled, Home runs from a filled in-memory library and says changes will not be kept. Edits in that state are possible but pointless, so export must stay available there as the rescue path.

---

## 3. A. Where editing lives

Cost key used throughout: S = one pull request with tests; M = two or three; L = four or more, or it needs a prerequisite that is not built yet (layout engine, Get Attention, chain harness); XL = L plus checks only a device can do. Agent-written and CI-verified; device checks are listed separately.

### A1. Edit mode on Home (the reference app's design; AGENTS.md is already written around it)

What the person sees. The same Home, with a clear "Editing" state that does not rely on colour alone. Phrase tiles open an editor instead of speaking. A toolbar offers Add, Move and Delete. Yes, No, Emergency and Again keep working; Emergency speaks nothing, switches to the emergency phrases and leaves edit mode (invariant 2). The mode ends itself after idle time (measured on `ContinuousClock`).

By stage:
- Early (hands work): best case. The person edits their own words where they see them, in a few taps.
- Middle (switch, head, dwell; family helps): works while the family is present. If they walk away, every ordinary tile is silent until the idle timeout fires. Yes, No, Emergency and Get Attention still work, but the person cannot say anything else. A short timeout loses the family's work; a long one extends the silence.
- Late (gaze only): the worst case. Every tile on the screen becomes "open an editor", and LESSONS ("Score chains, not single hops") records exactly this chain: tile opens editor, Delete Phrase is nearest, then the confirmation is nearest. The chain harness (port step 8) does not exist, so nothing could prove it safe.

Invariants and rules touched:
- 2: tiles stop speaking in edit mode. Allowed only because the invariant says so, and only with one pure resolver tested in both orders (edit then Emergency, Emergency then edit). The reference app got that wrong once (LESSONS, "One resolver per safety decision").
- 8 and 11: the banner and toolbar need space reserved at all times, or tiles move when the mode toggles; the reservation eats grid height that the starter library must fit in without scrolling.
- 10: LESSONS counts entering edit mode, reorder and merge as hazards, alongside speaking and deleting.
- "Typing never hides the call for help": the phrase text field on Home must keep Emergency, Get Attention, Yes, No, Speak and the way out above the worst-case software keyboard.
- The editor cannot be an ordinary sheet. A sheet covers Emergency, Yes and No (invariant 2: "never covered"), so it would have to be inline or a non-modal panel. Extra layout work.
- Emergency phrases never open editors, so they cannot be edited here at all. A second path is needed anyway, which is the strongest argument against A1 alone.

Cost: L to XL. Needs the layout engine, the Home port, a resolver, an edit-session timeout, the chain harness and a keyboard-safe editor.
Reuse: per docs/PORTING.md the reference app's `EditModeTimeout`/`EditModeSession`, `EditSubmission`, `EditToolbar`, `PendingDeletion` and `PhraseEditor` are listed as "almost as-is" [repo, names only; I cannot read them].

If A1 is ever built, the safest framing is to offer it only in the touch profile, where scrolling is cheap and a resting pointer does not activate things, and to keep Library as the only editor in dwell, switch and gaze profiles. Profiles do not exist in code yet.

### A2. A Library screen reached from Settings (Home never changes)

What the person sees. Nothing, unless a family member opens it. Home keeps one behaviour in every state. The family goes Home, Settings (a large way back and a start-only Get Attention at the top, per AGENTS.md), Phrases, then a category, then a phrase editor, a "Move to..." chooser or an inline confirmation. A single "Done" returns to Home in one activation from anywhere in the Library. Settings and the Library open on the category Home was showing, so no extra control is needed on Home.

By stage:
- Early: slower than A1 (more taps), but the person can do it alone with a normal keyboard, dictation and Voice Control, and nothing about Home changes under them.
- Middle: the family edits at their own pace. If they walk away, the person sees a family screen, not a trap: the safety bar (Back plus Get Attention) is on every Library screen, Done is one activation, and the idle policy resets the Library to its first screen but never closes it (AGENTS.md: "timeouts reset screens, never close them"; LESSONS, "A timeout never closes a screen onto speaking controls").
- Late: the gaze user's Home is untouched. The chain from Home to anything destructive is long: Settings, Phrases, category, editor, Delete, then a confirmation in a different place. Each hop is a separate activation at a separate position.

Invariants and rules: 2 satisfied by construction. 3 satisfied (the Library is the explicit mode; every delete, replace and merge asks). 8 untouched, apart from where the Settings entry sits (layout engine). 10: entering Settings is one mode switch from Home; Settings opens on a large Back, so a resting pointer repeats into Back and loops Home and Settings harmlessly. That loop is "a control turns into its opposite in place" in the strict sense, so record it as a named exception in docs/DECISIONS.md or place Back away from the entry control. 11: no reservation on Home. Emergency phrases are editable here.

Cost: M to L (Settings shell, safety bar, list and editor screens, confirmation, Move chooser, idle policy). Prerequisites: Get Attention, Settings shell, layout tokens for family screens. Most of the pure logic in the porting list carries over; only the Home-specific parts (edit-mode resolver, `EditToolbar`) wait.

Risks:
- Slower for a person editing alone in the early stage.
- If the Library draws phrases as Home-shaped tiles that open editors, a person who lands there taps what looks like speech and gets an editor. Prefer plain list rows for categories and phrases, with a small "Home preview" only inside the Move chooser.
- A family member who never finds Settings never edits. The first-run and setup flow (onboarding direction) has to teach it.

### A3. Both, in this order: A2 now, A1 later

Same as A2 for 1.0. A1 becomes a later, optional shortcut that calls the same core, only after the layout engine, the resolver and the chain harness exist. The costs of A1 are the hazard analysis, not the logic.

### Rejected variants

- A pencil button on every Home tile (touch-only convenience): doubles the targets on the screen the person rests on, and under Snap to Item the nearest control to a resting pointer becomes a pencil.
- Long-press, triple-tap or "tap the version number" to enter: gestures are a hard stop (invariant 9) and a time-based guard is forbidden ("Fix hazards with placement, never with time-based input guards").
- A modal alert for "are you sure": the system chooses the button positions (section 2, item 9).

### How the family area is entered without a dwell hazard

- A standard Button on Home, away from phrase tiles, Yes, No, Emergency, Again and the message text the person reads, and out of the corners (the top-left Eye Tracking recalibration corner). The exact position belongs to the layout engine (port step 4). It is not a timer, hold or gesture.
- Its destination opens on a large Back and a start-only Get Attention. Edit tools are one screen further down.
- The Library root lists categories only. Delete never appears on a list row; it appears only inside an editor, and its confirmation follows the placement rule in section 4.4.
- Until the chain harness exists, treat every Library screen as unscored. Keep it short, keep destructive controls two activations away from any entry control, and say so in HANDOFF.

### Is a caregiver "lock" (PIN or hidden path) appropriate?

What other AAC apps do:

| App | Protecting the editor | Lost-lock recovery |
|---|---|---|
| Proloquo2Go | "Restrictions": turning Edit Mode off hides the Edit button; an optional 4-digit PIN protects the Options button; the button can be hidden from iOS Settings [opened] | Security question, then email support [opened] |
| TD Snap | One 4-digit passcode covering Edit Mode, Sync, the top bar and purchases [opened] | A master code is published on the vendor's own support page [opened] |
| TouchChat | Menu Passcode in Settings, plus iPad Settings > TouchChat > Allow Editing, which removes the Menu and Vocab buttons [opened] | Not stated [opened] |
| LAMP Words for Life | Menu passcode [snippet] | A search summary of the Liberator guide says an inaccessible passcode means resetting the app to defaults [snippet, PDF unreadable here] |
| Grid for iPad | Edit mode is a menu action ("Edit grids", then "Finish Editing"); no PIN mentioned [opened] | n/a |
| CoughDrop | Editing means leaving speak mode; no PIN found [snippet] | n/a |

Pattern: the lock is optional, mostly a 4-digit PIN, and the more serious protection is removing the edit controls from the user's path (a switch in iOS Settings). Recovery from a lost PIN is weak everywhere.

Options for Brickson:
- L0, placement only (recommended default). The Library is a screen below Settings, entered by a standard button, nothing time-based. Cost: none beyond A2.
- L1, a switch in the iOS Settings app, "Show Settings button" (a standard Settings bundle plus one `UserDefaults` read; the privacy manifest already declares `UserDefaults`). This is what TouchChat and Proloquo2Go do. No secret to forget, reversible from outside the app. Risk: a family that hides it and forgets how to get it back. Cost: S, and a README and setup-guide line. Not needed for 1.0 unless family testing shows accidental entries.
- L2, Apple's Guided Access with a passcode, which can switch off touch in circled regions [opened, https://support.apple.com/en-us/111795]. No code. Apple's page says nothing about Switch Control, AssistiveTouch or Eye Tracking, and says Crash Detection and Emergency Services are unavailable while it runs. docs/HANDOFF.md already lists "Guided Access with Eye Tracking" as an unchecked device item. Document it only after that check.
- L3, an in-app PIN (not recommended). Hostile to the person: entering digits by gaze, a failure that blocks their own editing early in the disease, and a forgotten PIN whose only exit is deleting the app, which deletes the library (policy: "Deleting the app removes all of it"). Brickson also stores nothing in the Keychain, so the PIN would sit in `UserDefaults` as a speed bump rather than security. A hidden path fails the same way for VoiceOver users and new caregivers.

---

## 4. B. The mutation model

### 4.1 A pure "library edit" type (names are suggestions)

Plain value types that know nothing about SwiftData, so they can be tested without a store:
- `LibrarySnapshot`: ordered categories (uuid, name, symbol, isEmergency), each with ordered phrases (uuid, text). Array order is the order.
- `LibraryEdit`, one case per kind of change: add, rename and re-symbol a category; move a category; delete a category (always together with its phrases); add, edit, move (within or between categories) and delete a phrase; `mergeIn(snapshot)`; `replaceWith(snapshot)`.
- `LibraryEdit.plan(in:)` returns either a rejection with a reason a person can read, or a plan: the resulting snapshot, a description of what changes (for the confirmation text and for tests), and the question that must be asked first (none for add or edit; "delete", "merge" or "replace" otherwise). The plan also says whether it needs a safety copy.
- `LibraryEditor.apply(plan, to: container, save:)` does the SwiftData work and mirrors the seeder's `save:` seam so tests can make the save throw.

Validation rules the type owns for edits made in the Library (each gets a test that fails if the rule is removed). These rules do not apply to import: import never renames, trims or drops words (section 5.3).
- Emergency: exactly one emergency category; it cannot be deleted or un-flagged; its last phrase cannot be deleted (section 4.6). A rejection tells the family why, in text that stays on screen.
- Text: not empty after trimming. Trim only the two ends, only in the editor, and never on import, so a backup round-trips byte for byte. A length limit is a layout decision (a very long tile cannot fit a fixed grid); the typing direction owns long messages.
- Uniqueness: category names unique, case and punctuation insensitive (the starter tests already insist on it for the bundled set). Phrase text unique inside a category. A category may not be named like a Home control ("Yes", "No", "Emergency", "Again"): two buttons with one name confused Voice Control in the reference app (docs/DECISIONS.md, "Home version 0"; the porting list mentions `VoiceControlLabels` collision tests).
- Symbols: chosen from a curated list that a test checks with `UIImage(systemName:)` (the starter test already guards against silent misspellings).
- Order: after any change, sort orders are renumbered 0 to n-1 inside the affected container, so ties from a hand-edited file cannot persist (the existing tie-break in `orderedForDisplay` stays as the fallback).
- Delete a category: its phrases are listed in the plan and deleted explicitly in the same save (`.nullify` rule).

### 4.2 How the plan is applied (the SwiftData question)

Fact from the code audit, confirmed by Apple's documentation: the main context autosaves. So the first rule is that every save is explicit and the main context is never the one being edited.

- B1, a scratch context per edit (recommended to try first). Create `ModelContext(container)` with `autosaveEnabled = false`, fetch what the plan names by uuid, make every change, call `save` once. On failure, drop the context: nothing reached the store and no `rollback()` is needed. This is the seeder's pattern, extended from inserts to updates and deletes. Also, at launch, set `container.mainContext.autosaveEnabled = false` and pin it with a test, so Home's context can never save anything by itself; the main context becomes read-only by convention. Open question (LESSONS says so): after a successful delete saved from a scratch context, does the main context crash when something still holds the deleted object? The mitigation is that views hold uuids and fresh fetches, never model objects, across an edit; `HomeView` as written (section 2, item 5) must change before any delete can run while it is on screen.
- B2, edit in the main context with autosave off, and undo by compensation. Apple's documentation for `rollback()` says it discards pending inserts and deletes and restores changed models [Apple docs via Context7]; the forum reports (section 2, item 5) and LESSONS say it can crash after a delete. So B2 would mean never calling `rollback()` and instead applying a stored inverse edit on failure. More code, more places for a half-change. Keep only if the B1 spike shows scratch-context deletes crash the main context and cannot be made safe.
- `ModelContext.transaction(block:)` is not a way out by itself. Apple's page says it writes pending changes after the closure and throws if the closure or the save fails; it does not say whether in-memory changes revert [Apple docs via Context7]. A third-party write-up [opened, fatbobman.com] says a throwing block skips the save and does not say what happens to the in-memory changes. One forum thread [snippet] says wrapping undo and redo in `transaction` stopped a rollback crash on macOS 26.4. Treat as anecdote; include it in the spike.
- B3, the reversal to keep in mind: make an atomically written JSON file the canonical library and treat SwiftData as a cache, or drop SwiftData. An atomic file replace has no D28-style failure and a backup is just a copy. It costs the versioned-schema work already done, `@Query`, and the later Siri entity plumbing, and it reverses docs/DECISIONS.md, "Versioned storage". Do not start here; consider it only if the spike shows no safe way to delete.
- B4, soft delete ("Recently Deleted"): a delete only sets a marker, a separate screen purges. It cuts how often a hard delete runs, adds undo, and needs a stored field (cheap only before the first build reaches anyone, a V2 schema after; owner table, item 17), a filter in every `@Query`, and a rewrite of the policy sentence "gone from the app". It does not remove the need to get hard deletes right, only to run them less often. The automatic snapshot in section 5.5 gives most of the safety for less.

The test that decides between B1 and B2 is described in section 9.

### 4.3 Failure injection and what the person sees

- One parameterized test per edit kind: make `save` throw, then check nothing changed in the store (counts and order), the main context has no pending changes, the result is the "save failed" outcome and nothing crashed. The test enumerates `LibraryEdit.Kind.allCases`, so adding a kind without a failure test fails the suite. Name of the change that would make it fail: applying edits in the main context, or skipping the explicit delete of a category's phrases.
- The seam throws before SwiftData runs, so it never exercises SwiftData's own failure path. Add at least one real failing save in a test (a store on a temporary directory made read-only or removed) [unverified: I have not run this, so confirm that it makes `save()` throw].
- Also test: a failed `mergeIn` or `replaceWith`; a failed snapshot write (section 5.5) stops a replace from starting; a failed launch repair leaves the app on the in-memory fallback.
- What the person sees: nothing changes on Home, because the main context never held the edit. In the family area, a passive line at a reserved place at the bottom of the editor ("Couldn't save. Nothing was changed."), no dismiss control, no moved targets, with a VoiceOver announcement like the audio warnings. The editor keeps the typed text, and Save is the retry. If the store is volatile (in-memory fallback), the standing "Phrases can't be saved right now" line is shown in the Library too, and Export stays enabled as the rescue path.
- No `catch` that only logs; no phrase text in any log or crash message (the log line may carry the error type, not the text).

### 4.4 Confirmation placement (invariants 3 and 10)

- Inline, built in the app, not a system alert or dialog (the system decides button positions and a system destructive button measured 2.71:1).
- Delete is the asking control. When pressed, its frame becomes Keep (same size, same place), so a repeated activation lands on Keep. The destructive answer ("Delete 'Hello.' for good") appears at a different, fixed place, not adjacent to Keep and not where any earlier control in the chain sat. The question text names the item and the consequences (for a category: "and its 6 phrases").
- After a confirmed delete the editor closes onto a screen whose nearest control to that spot is safe. The chain harness would decide this; until it exists, record it as unscored.
- Destructive colour: new tokens with measured pairs in `PaletteTests`, not white on system red (3.55:1).
- Merge and replace ask the same way, from a summary (section 5.3). Adding a phrase or editing text needs no ask; both are reversible and move nothing.

### 4.5 Reorder

- R-a, Move Earlier and Move Later (the reference design): disabled at the ends, never nearest the control that opened them. Relative commands compound under repeated dwell: LESSONS records a held look walking a category to the end. Bounded harm, but not safe by construction.
- R-b, absolute "Move to..." (recommended default if the Library can show a preview): the editor opens a chooser that draws the category's tiles in Home order, each tile a button "Place before 'Thank you.'", plus "Place at the end". A repeat of the same activation is a no-op only under a condition: the moved phrase's own tile must stay in the chooser as a harmless target ("Keep 'Hello.' here"). Otherwise, after a move, the cell under a resting pointer may hold the non-targetable moved phrase, Snap to Item jumps to a neighbour, and "Place before <neighbour>" moves the phrase again (moving a phrase earlier puts it exactly where the target was). With the condition, whichever cell the pointer rests on after the move is a no-op. Costs one extra screen and a preview component the layout engine would supply anyway. Pick-up and put-down must not be the same control (invariant 10). Treat the default as unscored until the chain harness exists.
- R-c, drag with `.onMove` or drag-and-drop: a standard system control, fine as a touch extra, never the only path (invariant 1, no gesture-only controls).
- Whatever is chosen, deleting a phrase also moves every later tile. That is a position change in its own right; see section 6.

### 4.6 The emergency category, and what to do about re-seeding

Options for the emergency category (the code audit raised E1):
- E0, as it is: deletable, with a launch-time refill whenever the store has no categories. The known gap in docs/HANDOFF.md: a family that deletes everything gets the starter set back at the next launch, and until then Emergency is disabled.
- E1, structurally undeletable (recommended). There is always exactly one emergency category and it keeps at least one phrase. The validator rejects deleting it, un-flagging it, flagging another, or deleting its last phrase; the Library draws it as a pinned row that says why it has no Delete. Effects: `emergencyIsAvailable` can no longer be false through editing; an empty store can only mean first launch or storage loss, which is exactly when refilling everything is right; no "already seeded" flag is needed, so the seeder's comment still holds; import and restore end with exactly one by appending. What it does not remove: corruption can still lose the category, so a launch repair is still needed, and it only appends (below). Costs: the family cannot remove Emergency (it is on Home in every state anyway, invariant 2), cannot empty it (they replace the text instead), and every path that writes the library (edit, merge, replace, restore starter phrases, migration, repair) must enforce the rule, each with a test.
- E2, deletable behind a strong confirmation and recreated automatically: the same states appear for a moment and the family sees a delete that undoes itself. Worse than E1.
- E3, a built-in emergency set kept outside the store (docs/HANDOFF.md records a reviewer suggesting a store-free screen; "a second Home to keep safe"). Strongest against storage failure, largest cost. Not needed if E1 and the in-memory fallback hold.

Options for the refill question, judged against the seeder's comment:
- R1, never re-seed after the first seed: needs a marker. A marker in `UserDefaults` can outlive the store, which the seeder rejects. A marker inside the store (a new model) cannot, but that is a stored field (schema decision).
- R2, re-seed only a store with zero categories (today's rule). Safe once E1 holds, because editing can no longer reach zero categories.
- R3, "Restore starter phrases" in the Library, an explicit append-only action. Needs stable identity for starter items (below).
- R4, a launch repair that appends the starter emergency category when none exists. Additive only, so invariant 7 is satisfied: a repair may add, never delete, rewrite or "fix" a person's words. The reference app's fingerprint repair stays left behind (LESSONS, "Seed only neutral words").

Recommended: E1 + R2 + R4, plus R3 as a Library action. For R3 and for multi-device merges, give the bundled starter categories and phrases fixed uuids in `StarterPhrases.json` (a change to the bundled data and the seeder, not to the schema). Rules: a starter phrase whose text is later changed gets a new uuid; "Restore starter phrases" adds only the missing uuids and never touches an existing item, so an edited starter phrase stays as the person made it. The backup format below can be a superset of the starter file, so one decoder reads both and R3 is "merge the bundled file". A test pins the list of starter uuids so they cannot be regenerated by accident.

Invariant 7 constrains all of this in one sentence: repairs, migrations and imports may add, never delete or rewrite, a person's own words. That is why Replace is the hard case (section 5.3).

---

## 5. C. Backup and restore

### 5.1 What the file holds

One JSON file. Suggested shape (names are suggestions; the two marked permanent must be decided before any real backup exists):

- `format`: a fixed string such as `brickson.library` (permanent). Not derived from the bundle identifier, which can still change before the first upload (docs/DECISIONS.md, "App identity").
- `formatVersion`: an integer (permanent meaning). A decoder that sees a higher number refuses with a passive message and never guesses.
- `categories`: in display order, each with `uuid`, `name`, `symbolName`, `isEmergency` and `phrases`; each phrase has `uuid` and `text`. Array order is the order; stored sort orders are renumbered on import and never trusted from the file, so ties cannot arrive.
- Categories and phrases only. No settings (the policy says a backup holds "your categories and phrases", and settings are per device anyway, since an iPhone and an iPad may use different input methods), no draft message, no device name, no export time (the date goes in the file name, which keeps the bytes deterministic).
- Make it a superset of `StarterPhrases.json`: one decoder, with `uuid` optional so the bundled file still reads (missing uuids get new ones). Either allow a phrase to be a bare string or an object, or convert the starter file to the object form once, before 1.0. The second is simpler.
- Recordings (a later feature; the policy already says recordings are "included in backups you export") do not fit in a flat JSON file. Plan `formatVersion` 2 as a package or archive with the JSON plus audio files. Nothing in version 1 blocks that, as long as the decoder reads the version first.

### 5.2 Export and import mechanics

- Export: a share sheet (`ShareLink`) and/or `fileExporter`. [Apple docs via Context7] `ShareLink` takes any `Transferable`, and Apple's page says Mail, Messages, Notes and AirDrop offer their services for files rather than arbitrary data, so give the type a `FileRepresentation`. `fileExporter(isPresented:items:contentTypes:...)` also takes `Transferable` items and has success, failure and cancel callbacks (a document-based form exists too). Either way the person's words leave only where the family chooses, as the policy says. An exported copy is plain text; say so beside the Export button.
- Import: `fileImporter` from inside the family area only. [Apple docs via Context7] The returned URLs are security scoped: call `startAccessingSecurityScopedResource()` before reading and `stopAccessingSecurityScopedResource()` after. Apple's UIKit sample reads picked URLs through `NSFileCoordinator`; do the same, and map "not downloaded yet" and every decode error to a passive, readable message (invariant 5). Read, decode, validate and summarize without touching the store; only the confirmed step writes.
- Does iCloud Drive need an iCloud capability? Apple's pages say the system picker provides access to local, iCloud and third-party File Provider locations and state no entitlement requirement for the app [Apple docs via Context7]. Forum and Xojo posts say import mode works without the iCloud entitlement, and one asker could not find official confirmation [snippet]. No official statement found. [unverified] Check on a device with a build that has no iCloud capability, and add it to the device-check table. If it needed the capability, AGENTS.md's no-iCloud rule would force a decision.
- Do not register a document type in 1.0. A registered type makes Brickson a choice in "Open in" and in AirDrop, delivered through `application(_:open:)` or `onOpenURL`, and Apple's documentation says such files are placed in the app's Documents/Inbox [Apple docs via Context7]. Any import question that arrives that way can appear over Home and cover Emergency, Yes and No. [unverified] I believe AirDrop between devices on one Apple ID does not ask for acceptance and may open the file in the app that handles it; if that is right, a family sending a backup to the person's own iPad could pop up an import prompt on a gaze device. Check on devices before ever registering a type.
- A custom `UTType` is a separate, smaller step: `UTType(exportedAs:)` plus an Info.plist `UTExportedTypeDeclarations` entry [Apple docs via Context7]. [unverified] A declaration without `CFBundleDocumentTypes` should not make Brickson an "Open in" target. For 1.0 use a plain `.json` file; later declare a type that conforms to `public.json` so old `.json` backups still import. The type identifier is permanent once backups exist (decide it with the owner; derive it from a name the owner controls, not from the bundle identifier).
- Privacy manifest: do not read file modification dates or free disk space for convenience (those are "required reason" API categories); if you need them, add the manifest entries and update `AppBundleTests` in the same pull request [unverified: check Apple's current list]. Counters and names do the job.

### 5.3 What import does to an existing library (invariants 3 and 7)

The collision, stated plainly. Invariant 3: "every delete, replace or merge asks first." Invariant 7: "Nothing (repair, migration, import) may delete a person's own words." A Replace import deletes the current library's words that are not in the file. Reading 7 literally, Replace is forbidden. Three readings, for the owner:
- (a) Replace is allowed only over a library that holds nothing the person wrote: empty, or exactly the unmodified starter set (provable with fixed starter uuids and text). Otherwise only Add.
- (b) Replace is allowed after an automatic safety copy (section 5.5), so no words are destroyed, only moved aside, and the question says so.
- (c) No Replace at all; separate "Start over" flow.

Recommended: (a) and (b) together: free Replace onto nothing-of-the-person's, safety-copy-first Replace otherwise. Needs a sentence added to invariant 7 (the owner edits AGENTS.md; I have not).

| Current library | Add (merge) | Replace |
|---|---|---|
| Empty | same as Replace | Allowed, nothing lost |
| Exactly the unmodified starter | Allowed; identical starter items skipped | Allowed, nothing of the person's is lost |
| Holds the person's own words | Allowed, append only | Only after the safety copy is written; asks first with counts |

A store seeded before fixed starter uuids existed cannot prove it is untouched, so it falls under the third row.

One import procedure (merge, restore and "Restore starter phrases" all use it):
- Categories: match an incoming category to a local one by uuid, then by the emergency flag (every incoming emergency category matches the one local emergency category), then by normalized name (trimmed, case-insensitive; used only for matching, never written back). An unmatched incoming category is appended after the existing ones. This is what stops two family-made "Needs" categories from two devices becoming two "Needs" buttons.
- Phrases inside a matched category: skip an incoming phrase whose exact text (UTF-8 bytes) is already in that category, whatever its uuid. That check is what makes merging idempotent. Otherwise append it at the end, in file order, keeping its uuid unless a local phrase already uses that uuid, in which case it gets a new one.
- Same uuid, different text: the local phrase stays where it is, unchanged. The incoming text is added at the end only if that exact text is not already in the category. Repeating the import then finds it and adds nothing.
- Nothing already on the board moves or changes. LESSONS counts merge as a hazard because it adds categories and moves cells; this removes the "moves" half and not the "adds" half, so it still asks.
- Merge never deletes, so a deletion made on one device does not travel. Say so in the question; to make a device match another exactly, use Replace.
- Import is not editing. Import never renames, trims or drops any of the incoming words, because invariant 7 forbids it (Replace is the one place local words go, and only into the safety copy). The editor's rules (duplicate texts, a category named "Yes", text over the length limit, a symbol name that does not exist) do not apply: such data is kept as it is, with a passive note in the Library, and an unknown symbol name is stored unchanged and replaced by a fallback only when drawn. The one thing import skips is a phrase with no characters at all, which has no words to lose. Structure the app depends on is enforced by adding, never deleting: several emergency categories become one by appending their phrases, and a file with no emergency category leaves the local one alone.

Where and how to ask. On the Restore screen, after the file is read and checked, a summary built from the plan: "This backup has 6 categories and 71 phrases. Your library has 5 and 34. New in the backup: 2 categories, 40 phrases. Same in both: 31. Same phrase, different words: 2." Then the choices. The control that opened the question ("Choose a backup file") is replaced in place by Cancel; Add and Replace sit elsewhere, Replace farthest and enabled only after the safety copy exists. The result screen says what happened ("Added 2 categories and 40 phrases. Nothing was removed or moved.") and its Done sits away from the choices.

### 5.4 Round-trip tests ("byte-lossless", defined)

Two separate properties:
- Text identity: the UTF-8 bytes of every category name and phrase text survive export, import and export again. Compare `Array(text.utf8)`, never `String ==`: Swift treats canonically equivalent strings (one-scalar "é" and "e" plus a combining accent) as equal, so an equality test would pass while a normalizing importer silently changed the bytes.
- Determinism: encoding the same library twice gives identical bytes (sorted keys, a fixed layout, no timestamp inside; the date is in the file name).

Test corpus: both Unicode forms of one accented word, emoji sequences with joiners and skin tones, right-to-left text, tabs and line breaks, U+2028, curly versus straight apostrophes, leading and trailing spaces in imported text (the editor trims, import must not), a very long phrase. Further tests, each with the change that would make it fail:
- export, import into an empty store, export again: equal bytes (fails if the codec trims, normalizes or reorders);
- a higher `formatVersion` or a truncated file: a readable message and an unchanged store; a file with no emergency category, or with two: exactly one afterwards and no phrase lost;
- import keeps duplicates, a category named "Yes", over-long text and an unknown symbol name unchanged (fails if the editor's rules leak into import); only an entirely empty text is skipped;
- merge twice equals merge once, including after a same-uuid-different-text conflict; two family-made "Needs" categories from two devices end as one; merge never changes the position of an existing item;
- a failing save during import or during the safety copy: store unchanged, Replace never starts;
- the bundled starter file decodes through the same decoder.

### 5.5 An automatic local snapshot before import: worth it?

Yes, and it is what makes Replace compatible with invariant 7. It reuses the codec: write the current library as a file in app storage before any Replace, and before deleting a category. The library is tiny (a few tens of kilobytes), so cost is negligible.
- Keep the last few by count, not by age. Name by sequence number, not date, and avoid file-timestamp APIs (section 5.2).
- "Earlier copies" in the Library lists them, restores through the same question flow, and has a "Delete earlier copies" control.
- It falsifies two policy sentences (section 2, item 3). Rewrite them to say Brickson keeps a few earlier copies on the device, how to delete them, and that deleting the app removes them; bump the Effective date; update the in-app copy once there is one. If the owner would rather not touch the policy, the alternative is no Replace over the person's words at all (reading (c)).
- Compared with Recently Deleted (B4), a snapshot needs no schema change and no filter in every query. It is coarser: library level, not per item.

### 5.6 A reminder to back up

Passive text inside Settings or the Library: "12 changes since your last backup", driven by a counter saved on export, not by the clock (no `Date` arithmetic, no new permission). Never on Home (its status area is reserved for audio and library problems and must not compete), never a modal, never a badge the person's pointer can rest on. Optional for 1.0. The device's own iCloud Backup already includes Brickson's data (policy, "Your device's own backups"); the policy is the place that says so.

### 5.7 Open Board Format as an extra, not the backup

I could not read the specification itself: openboardformat.org and the two GitHub repositories showed only a tagline, a gem README and a landing page [opened]. What I have is from third-party implementers. [opened, https://github.com/madfam-org/voxa/pull/35] boards carry `format: "open-board-0.1"`, an id and a name, a 2-D `grid.order` of button ids with `null` for an empty cell, and `load_board` links for folders; an `.obz` is a ZIP with `manifest.json` and `boards/*.obf`; tool-specific data travels in `ext_`-prefixed properties, and the implementer's lossless claim is for its own round trip only. [opened, Cboard blog] OBF covers grid rows, buttons and images.

Judgement: OBF can carry order, text and an id, and its `null` cells match a slot model nicely, but the emergency flag and the uuid would live in `ext_` fields that other apps ignore. It is a good optional export (an escape hatch for a family moving apps, and a hedge against Brickson disappearing), later and export-only first. Importing other apps' boards would bring images, links and actions Brickson does not have, so it is lossy by nature. Cost: M. Not the backup format.

### 5.8 What other AAC apps do for restore

- Smartbox Grid for iPad: restoring a user replaces what is on the device ("Restoring a user will remove your current grid sets and settings"); a user backup needs the same Smartbox account on another device; a single grid set exported from edit mode restores from any account [opened]. A separate "Add from another grid set" merge exists in edit mode [snippet].
- TD Snap on iPad: restore goes through the Setup Wizard as a new user, not an overwrite (2017 article; the page does not say so outright) [opened].
- Proloquo2Go: restore to the current user, the backup's user or a new user; the page says nothing about replace versus merge or a safety copy; automatic iCloud backups keep the most recent backup per user per device [opened]. A page titled "Undo changes by restoring an internal backup" exists [title only].
- TouchChat: manual and automatic Dropbox backup; restore semantics not stated; videos are not included [opened].
Pattern: whole-library restore means replace or create a new user; merging is a separate, explicit page-level action; none documents a safety copy. Brickson has one library per install, so "restore as a new user" is not available; the snapshot is the equivalent.

### 5.9 By stage

- Early (hands work): the person, or a helper, exports a safety copy from their own phone to Files or iCloud Drive and can restore it themselves after changing devices.
- Middle: the family keeps the routine (export after a visit's edits) and does any restore after a device swap.
- Late (gaze only): the family exports and restores. The person never sees an import prompt: import is reachable only from inside the family area, and no file can open Brickson by itself because 1.0 registers no document type.

---

## 6. D. Two devices (an iPhone and an iPad)

Without iCloud sync in 1.0 (docs/DECISIONS.md), the bridge is the file.
- D1, file bridge (default). Export on device A to Files, iCloud Drive or by AirDrop, then on device B open Brickson, go to Settings, Phrases, Restore, and pick the file. Both devices end with the same library in the same order. Settings are not carried, because the devices may use different input methods. Choose Add to combine edits made on both; choose Replace to make B match A exactly.
- Send a backup when the person is not using the receiving device, or use Files and iCloud Drive instead of AirDrop. [unverified] An AirDrop to a device that is on screen may put a system prompt over Brickson; that is the system, not the app.
- D2, whole-device restore: iCloud Backup, a computer backup or device migration carries the app's data to a new device (policy, "Your device's own backups"). Useful for replacing a device, not for keeping two in step.
- D3, iCloud sync after 1.0: the models already follow SwiftData's rules for it (defaults, optional relationships, nothing unique), uuids give identity, and nothing in the backup format blocks it. Conflicts and account states are why it is deferred (docs/DECISIONS.md).

By stage: early, the person may use both devices and moves edits across themselves; middle, the iPad becomes the main device, the phone is for outings, and the family carries edits across by file; late, the mounted iPad is the only device in use and the family's phone holds a copy kept in step by the same export and restore.

"Same positions on both devices" needs these answers, which are the layout engine's, not the editor's:
1. A single source of order. Done: list order in the store, array order in the file.
2. A deterministic map from (library, window, profile) to cells. Today's `PhraseGrid` uses 3 columns in regular width and 2 in compact, so order is shared but cells are not. Either accept "same order, different grid shape", or make the column count a property of the library, not of the device class.
3. What deleting a phrase does to the tiles after it: close the gap (list semantics, what exists) or leave an empty slot (grid semantics, "a slot keeps its place", invariant 8). For someone who has learned where words sit by gaze, a gap is safer; for touch users it looks odd. If gaps are chosen, deletion needs an explicit "Tidy up" command that moves cells, which is itself a hazard and asks.
4. Whether slots are stored. If yes, the backup gains a slot per phrase (a `formatVersion` bump) and the store gains a field. That is one line only before the first build reaches anyone (owner table, item 17); afterwards it is a V2 schema and migration.

What I would do now: keep order-as-array everywhere, and have the pure edit type report, for each delete and move, whether a gap is closed, so either semantics is one switch later. Ask the layout-blueprint direction for answer 3 before the Library's delete flow is built, because it changes what delete, merge and restore mean.

---

## 7. Cost, order and dependencies

| Work item | Cost | Needs first | Notes |
|---|---|---|---|
| SwiftData behaviour tests, autosave pin | S | a Mac or CI | Decides B1, B2 or B3 |
| Pure edit type, planner, validator | M | nothing | No SwiftData, no UI |
| Applier with a failure test per edit kind | M | the behaviour tests | |
| Backup codec, round-trip tests, starter uuids | S to M | nothing for the codec | Names to decide before any UI |
| Get Attention (port step 1 remainder) | M | n/a | Should precede any family screen |
| Settings shell: safety bar, Done, idle policy | M | Get Attention | Port step 7 |
| Library screens: list, editor, confirm, Move chooser | L | layout tokens (step 4), Settings shell | Chain scoring still wanted |
| Export and import screens, question, safety copy | M | codec, Settings shell | Privacy page update in the same PR |
| Restore starter phrases | S | starter uuids | |
| Back-up reminder; iOS-Settings "Show Settings button" | S each | export; none | Optional |
| Home edit mode (A1) | L to XL | layout engine, Home port, resolver, chain harness | Later |
| OBF export | M | codec | Optional |
| Recordings container (format 2) | M to L | recorded-phrases direction | |

Interfaces with the other directions:
- Layout-blueprint: the slot question (section 6), where the Settings entry sits, size tokens for family screens, the preview used by the Move chooser.
- Onboarding: teaching where Settings is; a first-run "restore from a backup" choice, which with Add and Replace rules above is safe to offer before the starter set is touched.
- Recorded phrases: the backup container for audio; snapshot size.
- Typing: a keyboard-safe phrase editor; whether a "keep this typed message as a phrase" control may exist outside the Library (an append-only data change outside an edit mode, so it needs a recorded exception to invariant 3).
- Alarm and audio: Get Attention in every family screen's safety bar.

---

## 8. Recommendation

Build the core first, then put editing in the family area, and leave Home alone for 1.0.

1. Core, no UI: explicit saves and a SwiftData behaviour test; a pure edit type with a validator; a backup codec with byte-level round trips.
2. Make Emergency structurally undeletable (E1), add fixed uuids to the starter set (bundled data and seeder only), keep the seeder's "no categories" rule, and add an append-only repair and a "Restore starter phrases" action.
3. Library under Settings (A2) with inline confirmations, a Move chooser, a safety bar and an idle reset that never closes it. Home edit mode only later and only in a touch profile, if family testing shows the extra convenience is worth the hazard work.
4. Export by share sheet, import only from the file picker inside the family area, Add by default, Replace only over nothing-of-the-person's or after an automatic safety copy.
5. No PIN. L0 by default, L1 and L2 as documented options.

### Smallest first step (needs no screen and no Home change)

Three independent pull requests, none visible to the person:
- 1a. Set the main context's `autosaveEnabled` to false at launch, pinned by a test. Add SwiftData behaviour tests (section 9, S1 to S4), including a real failing save and a disabled crash reproduction for `rollback()` after a delete, committed with an issue number as LESSONS requires. The outcome selects B1, B2 or B3.
- 1b. `LibrarySnapshot`, `LibraryEdit`, the planner and validator, with tests for every rule, written without SwiftData.
- 1c. `BackupCodec` format 1 over `LibrarySnapshot`, with the byte-level round-trip tests and starter-file decoding. It is not wired to any export button, so no backup file exists anywhere and the permanent names can still be decided.

Tests worth writing first, each with what would make it fail:
- Every `LibraryEdit.Kind` has a failing-save test: fails if an edit is applied in the main context, or a category's phrases are not deleted in the same save.
- Main context has no pending changes after a failed edit and `autosaveEnabled` is false: fails if anyone re-enables autosave or edits in the main context.
- The emergency rules (cannot delete, un-flag or empty it; merge and replace end with exactly one): fails if a path forgets the rule.
- Export, import, export is byte-identical for the hard corpus: fails if the codec trims, normalizes or reorders.
- Merge twice equals merge once, merge never moves an existing item, and import keeps what an editor would reject: fails if merge sorts or inserts in the middle, or the editor's rules leak into import.
- A higher `formatVersion` is refused without touching the store: fails if the decoder guesses.

What this step forces: only owner decisions 3 (emergency rule) and 9 (permanent names), and neither blocks it. It chooses nothing about list versus slots (the planner reports whether a gap closes), about Library versus Home edit mode, or about a lock. Written without Xcode it stays untested until CI or a Mac run passes (AGENTS.md, "Cloud agents").

Then, in order: the applier on the winning strategy; Get Attention; the Settings shell; Library screens; export, import and the safety copy with the privacy page update; Restore starter phrases; later A1, OBF and the recordings container.

### Owner decisions, with recommended defaults

| # | Decision | Recommended default | What it unblocks |
|---|---|---|---|
| 1 | Where editing lives | Library under Settings only for 1.0; Home edit mode later, touch profile only | Screens |
| 2 | Caregiver lock | Placement only; document Guided Access after the Eye Tracking device check; optional iOS-Settings switch; no PIN | Settings design |
| 3 | Emergency category | Undeletable, exactly one, last phrase protected | Validator, seeder, import |
| 4 | Refill rules | Keep "no categories means seed everything"; add an append-only repair; add "Restore starter phrases"; no stored flag | HANDOFF known gap |
| 5 | Fixed uuids for starter items | Yes, any time before the first build reaches anyone; data and seeder only, no schema change | Idempotent merges and restore |
| 6 | Reading of invariant 7 for Replace | (a) plus (b): Replace freely over nothing-of-the-person's, otherwise only after a safety copy. The owner edits AGENTS.md | Import design |
| 7 | Automatic safety copies | Yes: before Replace and before deleting a category; keep the last few; deletable; rewrite the two policy sentences and the Effective date | Replace, undo |
| 8 | Backup contents | Categories and phrases only; date in the file name | Policy accuracy |
| 9 | Permanent names | Decide the internal `format` string and what `formatVersion` means before any export UI ships. In 1.0 use a plain `.json` file and register no document type; if a type is ever registered, take its identifier from a name the owner controls, not the bundle identifier | Before any export UI |
| 10 | Import entry | System file picker inside the family area only | Safety over Home |
| 11 | Position after delete; stored slots | Ask layout-blueprint; keep list order meanwhile | Delete, merge, backup v2 |
| 12 | Reorder control | Absolute "Place before" chooser; if too costly, Move Earlier and Move Later with ends disabled, recorded as an accepted cost | Editor design |
| 13 | Order of work | Get Attention before any family screen | Safety bar |
| 14 | Keep-typed-message-as-phrase outside the Library | Not in 1.0; revisit with the typing direction | Invariant 3 exception |
| 15 | Reminder to back up | Passive, counter-based, in Settings only; optional | Export |
| 16 | The reference app's D24 and D25 | Someone with access pastes them here | Screens |
| 17 | When the pre-1.0 window for stored changes closes | The first build that reaches anyone, TestFlight included; record the exception to "never edit V1" in docs/DECISIONS.md until then; decide slots, any seed or deleted-at marker and soft delete before that date | Any new stored field |

---

## 9. What only a Mac, CI or a device can settle

| # | Question | Why it matters | How |
|---|---|---|---|
| S1 | Delete a category and its phrases in a scratch context and save: does the main context fetch correctly and survive a stale object that something still holds? | Decides B1 (LESSONS lists it as unproven) | CI test; if it crashes, commit it disabled |
| S2 | Does `@Query` plus `category.phrasesInOrder` in `HomeView` survive a delete saved elsewhere, or must Home read through fresh fetches? | Home may need a change before any delete | UI test that deletes then reads Home |
| S3 | After a failing save in a scratch context, is the main context clean? After a failing save in the main context, what is pending and does a later autosave write it? | Confirms the explicit-save rule | CI test, including a real failing save (read-only store) |
| S4 | Does `rollback()` after deleting a category with phrases still crash on current iOS 26? Does wrapping in `transaction` change it? | Keeps B2 on or off the table | Disabled reproduction plus issue |
| S5 | Does the file picker import and export through iCloud Drive without an iCloud capability? | AGENTS.md has no iCloud capability | Device build without the capability |
| S6 | Does a custom exported type without document types keep Brickson out of "Open in"? Does same-Apple-ID AirDrop open files by itself? | Decides whether registering a type is ever safe | Two devices |
| S7 | Guided Access together with Eye Tracking, Switch Control, AssistiveTouch Dwell | Whether L2 can be recommended | Device (already in HANDOFF) |
| S8 | Chain scoring of every Library screen under both pointer models | The harness (step 8) is not built | Device plus harness |
| S9 | Voice Control names for the Library's controls and the tiles in the Move chooser | Label collisions | Device |

---

## 10. Sources

Opened pages (read in this session):
- AssistiveWare, hide or show the Edit and Options buttons: https://www.assistiveware.com/support/proloquo2go/protect-recover-and-share-vocabulary/hide-or-show-edit-and-options-buttons
- AssistiveWare, restore a backup: https://www.assistiveware.com/support/proloquo2go/protect-share/restore-backup
- AssistiveWare, recovering after deletion: https://www.assistiveware.com/support/proloquo2go/troubleshooting/deleted
- Tobii Dynavox, TD Snap passcode: https://us.tobiidynavox.com/blogs/support-articles/how-do-i-set-a-passcode-for-the-top-bar-navigation-buttons-in-td-snap%C2%AE
- Tobii Dynavox, keeping someone out of the edit tool: https://ca.tobiidynavox.com/blogs/support-articles/how-do-i-keep-someone-out-of-the-edit-tool
- Tobii Dynavox, TD Snap iPad backup and restore: https://tobiidynavox.com/blogs/support-articles/how-do-i-create-and-restore-a-user-backup-in-td-snap-on-an-ipad
- AbleNet, TouchChat menu passcode: https://support.ablenetinc.com/uncategorized/how-to-set-a-menu-passcode-hide-the-menu-button-in-touchchat/
- AbleNet, TouchChat backup: https://support.ablenetinc.com/speech-apps/how-to-backup-touchchat/
- AbleNet, Grid for iPad backup: https://support.ablenetinc.com/speech-apps/how-to-backup-grid-for-ipad/
- Smartbox, restoring a user in Grid for iPad: https://hub.thinksmartbox.com/?p=1115
- Smartbox, entering edit mode on Grid for iPad: https://hub.thinksmartbox.com/knowledgebase/how-do-i-get-into-edit-mode-on-grid-for-ipad/
- Apple, Guided Access: https://support.apple.com/en-us/111795
- Use Your Loaf, SwiftData saving changes: https://useyourloaf.com/blog/swiftdata-saving-changes/
- fatbobman, transactions in SwiftData: https://fatbobman.com/en/posts/using-transactions-instead-of-save-in-swiftdata-and-core-data/
- Hacking with Swift forum, discarding changes in an editing context: https://www.hackingwithswift.com/forums/articles/how-to-discard-changes-to-a-swiftdata-object-creating-a-new-object/28831
- Voxa pull request describing OBF 0.1 in use: https://github.com/madfam-org/voxa/pull/35
- Cboard on OpenBoard support: https://www.cboard.io/en/blog/2018-06-30-cboard-openboard-support/
- Open Board Format site and repositories (tagline, gem README and landing page only; no specification text): https://www.openboardformat.org/, https://github.com/open-aac/openboardformat, https://github.com/open-aac/obf

Apple documentation text via the Context7 index (developer.apple.com not fetched directly):
- https://developer.apple.com/documentation/swiftdata/modelcontext (save, transaction, rollback, hasChanges)
- https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled
- https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes (delete rules)
- https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29
- https://developer.apple.com/documentation/swiftui/view/fileexporter%28ispresented%3Aitems%3Acontenttypes%3Aoncompletion%3Aoncancellation%3A%29
- https://developer.apple.com/documentation/swiftui/sharelink
- https://developer.apple.com/documentation/swiftui/handling-advanced-document-scenarios (exported type declarations)
- https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller and https://developer.apple.com/documentation/uikit/providing-access-to-directories (security-scoped URLs, file coordination)
- https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application%28_%3Aopen%3Asourceapplication%3Aannotation%3A%29 (AirDrop files go to Documents/Inbox)

Seen only in search-result summaries (leads, not verified): Apple Developer Forums threads 820173 (rollback after delete), 822241 (undo and redo, transaction), 800316, 771431 and 808237 (invalidated instances), 812212 (nullify, fixed in 26.3 per Apple), 731665 (autosave failure, no answer seen) and 108131 (picker without the iCloud entitlement), all at https://developer.apple.com/forums/thread/<number>; the Liberator LAMP Words for Life menu-lock guide (PDF could not be read); CoughDrop speak-mode and edit-mode help articles (Georgia Cyber Academy, Bridging Apps); AbleNet and Smartbox "Add from another grid set"; the Xojo forum thread on importing without the iCloud entitlement.

Not researched (limits): CoughDrop's own documentation, TD Snap's current backup article (the one opened is from 2017), whether Guided Access works with Eye Tracking, and the official OBF specification text.
