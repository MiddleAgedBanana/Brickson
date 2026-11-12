# Stores saved by every schema version, opened by today's build

*2026-11-12. Pull request (`claude/project-thread-cb53df`). The thread
"Test saved data from older versions", from the second follow-up of
[`2026-10-23-emergency-repair.md`](2026-10-23-emergency-repair.md) and
[`2026-10-21-library-core.md`](2026-10-21-library-core.md).*

## What changed and why

A person's phrases live in a SwiftData store on their device. When an
update arrives from the App Store, the new build opens the store the old
build saved. If a schema change has no migration, the store does not
open and the person speaks from the starter phrases until it is fixed;
if a migration is wrong, words can be lost or changed, or phrases can
move on Home, where someone reaches for a place they know (invariants 7
and 8). Until now only stores written and read by the same build were
tested.

The library has had one schema version, `PhraseLibrarySchemaV1`, and its
models are the same in every commit of `main` since the first (all 892
on 2026-11-12, compared with comments and blank lines left out), so
version 1 is the only one to cover.

- **`SavedStoreTests`** (new, unit tests):
  - `everySchemaVersionHasASavedStore` fails while any version in
    `PhraseLibraryMigrationPlan` has no saved store in the test bundle,
    or no record of what it holds (`SavedLibraryStore.all`), and checks
    the app opens its library with the newest version.
  - `aSavedStoreOpensWithEverythingInItsPlace`, for each saved store:
    a copy is opened three times, as three launches, through
    `PhraseLibraryStore.makeContainer` (today's schema and migration
    plan) and `PhraseLibraryLaunch.prepare`. The launch must use the
    store and report nothing; every category and phrase row must come
    back, no more and no fewer, with every value the same and words
    byte for byte; Home's category row, the category Emergency opens
    and every grid must hold the same identities in the same order,
    written out by hand in the test; and the Library's read must match.
    The second launch also adds a phrase through `LibraryEditor`, and
    the third finds it at the end of its grid with nothing else moved.
  - `todaysSchemaWritesTheSavedContents` writes the newest version's
    contents with today's models on every run, opens them as a launch
    does, and keeps the store's files in the run's results as
    attachments. That is where a saved store comes from: made by the
    app on CI, never by hand.
  - `theChecksCatchAChangedWordALostPhraseAndAMovedOne` writes three
    wrong results a migration could give (a word whose bytes changed
    though Swift's `==` calls it equal, a phrase in no category gone, a
    tied phrase moved) and shows the checks tell each from the saved
    store.
- **`BricksonTests/SavedStores/library-v1.0.0.store`**, with the
  `-wal` and `-shm` files beside it: version 1's saved store, written on
  CI by a run of this branch and committed as the app left it
  (*Verified*). The write-ahead log is empty, because SQLite had moved
  everything into the store when the app let it go, and the `-shm` file
  is SQLite's index of that log, which the next opening resets.
  Its contents (`SavedLibraryStore.v1`) are neutral, practical words, and
  what a store gathers that the starter library does not: an accent
  stored as one character and as a letter with a combining mark, a
  skin-tone emoji, Japanese and Arabic, spaces at both ends, a long
  phrase, a category with no phrases yet, sort orders tied and with
  gaps (a restored or hand-edited store), and a phrase in no category
  (only a damaged store has one, and its words are still someone's).
  The rows are written in an order that is not Home's, and the ties are
  set so that a different tie-break shows: compared as bytes instead of
  as Swift compares text, two of Places' phrases change places.
- **docs/DECISIONS.md, "Versioned storage"**: every schema version has a
  saved store, made on CI and never rewritten. `PhraseLibrarySchema.swift`
  says so where a new version is added.

## Making the next version's store

The pull request that adds `PhraseLibrarySchemaV2`:

1. Adds the version, its migration stage and the moved type aliases
   (docs/DECISIONS.md, "Versioned storage").
2. Adds `SavedLibraryStore.v2` to `SavedLibraryStore.all`: version 1's
   rows with the new field's values, and Home's places. It never
   changes `v1` or `library-v1.0.0.store`; where the migration gives
   version 1's rows a value for the new field, the opening test checks
   that value.
3. Pushes. On that run `everySchemaVersionHasASavedStore` fails, as it
   should, and `todaysSchemaWritesTheSavedContents` keeps
   `library-v2.0.0.store` (and `-wal` and `-shm` where SQLite left them)
   in the `unit-test-results` artifact.
4. Takes the files from the artifact. On a Mac, `xcrun xcresulttool
   export attachments --path unit-ipad.xcresult --output-path out`.
   Anywhere, with Python and the `zstandard` package: in
   `unit-ipad.xcresult/database.sqlite3`, table `Attachments`, the rows
   whose `name` starts with `library-v2.0.0.store` give, in
   `xcResultKitPayloadRefId`, the file `Data/data.<id>`; a file that
   starts with the bytes `28 b5 2f fd` is compressed with zstd.
   ```python
   import sqlite3, zstandard
   db = sqlite3.connect('unit-ipad.xcresult/database.sqlite3')
   for name, ref in db.execute("select name, xcResultKitPayloadRefId from Attachments "
                               "where name like 'library-v%.store%'"):
       data = open(f'unit-ipad.xcresult/Data/data.{ref}', 'rb').read()
       if data[:4] == b'\x28\xb5\x2f\xfd':
           data = zstandard.ZstdDecompressor().decompressobj().decompress(data)
       open(name, 'wb').write(data)
   ```
5. Reads the rows back with `sqlite3` to see they are the contents in
   `v2`, runs the privacy check on the files, and commits them, named as
   kept, in `BricksonTests/SavedStores`. The next run passes.

## Commits

On `claude/project-thread-cb53df`; the pull request lists them.

## Verified

Made in a cloud session, which cannot build the app; GitHub CI is the
build and the test run. The runs below were started by hand on the
branch (`workflow_dispatch`), before the pull request opened.

- **The first run** (run 517, `c65d5f2`) did not build: Swift Testing
  called the `#require` in `write(_:to:)` redundant, because its result
  was assigned to an optional and so was read as one, and warnings are
  errors. The category found is now named first, then assigned
  (`a5eceeb`). Its UI jobs, on the same code, passed on both families.
- **The second run** (run 523, `85cd52c`, with `main` merged in), Unit
  tests job: Xcode 27.2 (27B52), iPad Pro 13-inch (M5) simulator, iOS
  27.2 (24B8117). 957 tests ran: 944 passed, 2 failed, 1 skipped and 10
  were expected failures. The two failures were the ones this branch
  expected before its store was committed, so they show both checks
  fail while a version has no store: `everySchemaVersionHasASavedStore`
  ("bundledFiles(of: saved)["store"] != nil") and
  `aSavedStoreOpensWithEverythingInItsPlace` ("files["store"] != nil").
  `todaysSchemaWritesTheSavedContents` passed in 0.145 s, so today's
  schema writes and reopens version 1's contents with Home's places,
  and `theChecksCatchAChangedWordALostPhraseAndAMovedOne` passed in
  0.134 s. The suite took 0.35 s. Its UI jobs were cancelled once the
  unit job had finished, as this change touches no screen; the pull
  request's run runs them.
- **The saved store** came from that run's `unit-test-results`
  artifact (GitHub's digest `sha256:c6dfb56a…`), taken out with the
  Python steps in *Making the next version's store*: `library-v1.0.0.store`
  (77,824 bytes), `-shm` (32,768) and `-wal` (0). Read back with
  Python's `sqlite3`, on a copy: integrity check ok, journal mode WAL,
  model version `1.0.0` in its metadata, 5 categories and 18 phrases,
  each with the identity, words, sort order and category in
  `SavedLibraryStore.v1`, byte for byte (the accent written as a letter
  and a combining mark is stored as `65 cc 81`, the one written as one
  character as `c3 a9`). Beside them, SwiftData's change history holds
  one transaction, naming the app's bundle identifier (public in
  `project.yml`) and its process, Brickson. No other text is in the
  files: no path from the machine that wrote them. The privacy check
  (`--outgoing --no-list`) found nothing in them.
- **The pull request's own run**, the first with the store committed,
  is the one that must be green: the pull request reports it.

## Not verified

- Stores written by an iOS older than CI's: the saved store was written
  by the simulator's iOS on CI. No build has shipped, so no older store
  exists on anyone's device; a store a TestFlight build writes on a real
  device is a later check (*Follow-ups*).
- What SwiftData does when a saved version is edited in place, which
  docs/DECISIONS.md, "Versioned storage", forbids. The saved store was
  written by version 1 as it is, so the opening test opens it against
  any such edit, but no edit was made here to see how it fails.
- A store from a newer build opened by an older one (a downgrade): it is
  reported and kept, never replaced (docs/DECISIONS.md, "An unreadable
  library is reported, never replaced", and
  `PhraseLibraryTests.savedPhrasesThatWillNotOpenAreReported`); this
  pull request adds nothing there.

## Follow-ups

- When version 2 is added: *Making the next version's store*. (Whoever
  adds it.)
- Once a TestFlight build exists, a store it saved on a real device,
  opened by the next build: worth a row in docs/HANDOFF.md, *Checks
  that need a real device*, when TestFlight starts. (Whoever starts
  TestFlight.)
- Safety copies, the last library follow-up of
  [`2026-10-23-emergency-repair.md`](2026-10-23-emergency-repair.md), a
  pull request of its own.
