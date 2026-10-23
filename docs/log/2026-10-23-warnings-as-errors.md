# Compiler warnings are errors in every target

*2026-10-23. Pull request #39 (`claude/project-thread-ixjqgh`). The
"Warnings as errors" thread, a cloud session that cannot build: GitHub CI
is the only build.*

## What changed and why

A warning from the Swift or C compiler now fails the build of the app,
its unit tests and its UI tests, in every build configuration, on CI and
on a Mac. Nothing changes for the person using Brickson. The change that
causes a warning fixes it before it merges, instead of warnings piling
up unread; several of Brickson's rules show up first as one (a
deprecated API, a value computed and never used, code that can never
run). docs/DECISIONS.md, "Warnings are errors", holds the decision, as
reversible, with what to do when a new Xcode adds warnings. It was a
follow-up of the test-seams work
([`2026-10-21-test-seams.md`](2026-10-21-test-seams.md), *Follow-ups*:
"treat warnings as errors once CI builds clean") and of the CI audit
([`tests-ci-audit.md`](../recon/2026-10-15/tests-ci-audit.md), section 6).

- `project.yml`: `SWIFT_TREAT_WARNINGS_AS_ERRORS` and
  `GCC_TREAT_WARNINGS_AS_ERRORS` in the project-wide `settings.base`, so
  every target (and any added later) and both configurations inherit
  them. Strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`, Swift 6
  mode) is unchanged.
- docs/DECISIONS.md, "Warnings are errors", and its row in *Decided by
  default*.
- AGENTS.md: a paragraph in *Build and test*, and a review rule in *Tests,
  workflows and the rules themselves* (a warning silenced instead of
  fixed).
- docs/HANDOFF.md: the CI bullet, and a known gap (CI never compiles the
  Release configuration). docs/ROADMAP.md, *All the time*: moving to a
  new Xcode fixes the warnings it adds.

**There was nothing to fix.** `main`'s last green CI run before this pull
request (run 39903569732 on `f34e8ae`, Xcode 27.1, 27A9275) had no
compiler warning in either job: xcbeautify's annotations on the run
(which showed both probe diagnostics below) held none in the unit job,
and the UI job's 20 are all one runtime notice, not a compiler warning
(*Not verified*).

**Why every configuration.** A Release-only exception would mean the
archive that ships is the one build that may carry warnings. The cost is
that CI never compiles Release (*Not verified*).

**The narrow escape hatch does not work on Xcode 27.1.** Swift's
diagnostic groups (SE-0443) can keep one group a warning while the rest
are errors, and Xcode exposes that as `SWIFT_WARNINGS_AS_WARNINGS_GROUPS`.
With Swift 6.4.1 on Linux (the language version Xcode 27.1 ships),
`-warnings-as-errors` made both an unused value (`[#NoUsage]`) and a
deprecated call (`[#DeprecatedDeclaration]`) errors; `-Wwarning
DeprecatedDeclaration` placed after it kept only the deprecation a
warning, and placed before it did nothing. On CI, Xcode passed the group
before `-warnings-as-errors`, so the group stayed an error (*Verified*,
probe 2). docs/DECISIONS.md, "Warnings are errors", therefore names the
plain escape instead (the setting off for the one target, recorded) and
says to trust the narrow one only after a CI run shows it working.

## Commits

- `8b23b68` Treat compiler warnings as errors in every target.
- `45d83e5` A deliberate warning in the app (probe 1).
- `e0c4c60` The decision and its review rule.
- `334a506` This record, and the HANDOFF and ROADMAP lines.
- `8864b7f` The probe moved into both test targets, with one group kept a
  warning (probe 2).
- The last commit removes every probe and the group, rewrites the escape
  hatch from probe 2's result, and fills in *Verified*.

## Verified

All on GitHub CI (Xcode 27.1, 27A9275, the Debug configuration);
nothing was built anywhere else.

- **Probe 1, the app** (run 39910443378 on `334a506`, unit job
  120271949896): a deliberate unused value in the app failed the build,
  `Brickson/App/WarningsAsErrorsProbe.swift:5:9: error: initialization of
  immutable value 'unusedProbe' was never used ... [#NoUsage]`, then
  `** TEST BUILD FAILED **`, exit 65. The app's `swiftc` line carried
  `-warnings-as-errors`, and so did the unit-test target's. The UI job
  was cancelled by the next push.
- **Probe 2, both test targets and the escape hatch** (run 39912088134 on
  `8864b7f`, with `SWIFT_WARNINGS_AS_WARNINGS_GROUPS: NoUsage`): in the
  unit job (120278580058) `BricksonTests/WarningsAsErrorsProbe.swift`
  failed with a deprecated call (`error: ... [#DeprecatedDeclaration]`)
  and the unused value (`error: ... [#NoUsage]`); in the UI job
  (120278580550) `BricksonUITests/WarningsAsErrorsProbe.swift` failed the
  same two ways, on the iPad and again on the iPhone. The app, with no
  probe left, compiled with the same flags and no diagnostic. So the
  group named there stayed an error: Xcode's driver line reads
  `-Wwarning NoUsage ... -warnings-as-errors`, and the compiler got
  `-Wwarning NoUsage -warnings-as-errors -Wwarning NoUsage
  -warnings-as-errors`, the later flag winning, as on Linux.
- **The final head**, with every probe and the group removed: the pull
  request's last CI run, which must be green before it merges.

## Not verified

- **The Release configuration.** CI builds Debug only. Code under
  `#if DEBUG` (`LaunchOptions.readsLaunchArguments`,
  `KeyboardProbeLaunch`, `KeyboardProbeScreen`) compiles differently in
  Release; read by eye, none of the three would warn there, but nothing
  has compiled it since this change. `scripts/test.sh device
  -configuration Release` on a Mac does (docs/HANDOFF.md, *Known gaps*).
- **Clang.** Brickson has no C, C++ or Objective-C source, so
  `GCC_TREAT_WARNINGS_AS_ERRORS` is set but nothing exercises it.
- **Runtime notices are not compiler warnings.** Every UI run prints
  "AVAudioSession_iOS.mm:978 This method can lead to UI unresponsiveness
  if called on the main thread" (the audio session activated on the main
  thread). It comes from the running app, so this setting does not touch
  it. The asynchronous `AVAudioSession.activate(options:completionHandler:)`
  (iOS 27.0) is already listed with its fallback in
  [`ACCESSIBILITY.md`](../ACCESSIBILITY.md).

## Follow-ups

- Before the first archive: `scripts/test.sh device -configuration
  Release` on the owner's Mac, and fix any warning it shows. *(the
  owner's Mac, or an agent on it)*
- When the minimum iOS reaches 27, the audio session's old interruption
  notice becomes a deprecation error; drop it then, as docs/DECISIONS.md,
  "Audio session notices", already says. *(whoever raises the minimum)*
- The main-thread audio-session notice above. *(the speech thread that
  adopts `activate(options:completionHandler:)`)*
