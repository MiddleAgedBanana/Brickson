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
compiler warning in either job: xcbeautify, which annotates each one on
the run, annotated none in the unit job; the UI job's 20 annotations are
all one runtime notice, not a compiler warning (*Not verified*).

**Why every configuration.** A Release-only exception would mean the
archive that ships is the one build that may carry warnings. The cost is
that CI never compiles Release (*Not verified*).

**The escape hatch was checked on a compiler.** With Swift 6.4.1 on
Linux (the language version Xcode 27.1 ships), `-warnings-as-errors`
made both an unused value (`[#NoUsage]`) and a deprecated call
(`[#DeprecatedDeclaration]`) errors; adding `-Wwarning
DeprecatedDeclaration` after it kept only the deprecation a warning, and
the same flag placed before `-warnings-as-errors` did nothing. So the
order Xcode passes them in decides whether `SWIFT_WARNINGS_AS_WARNINGS_GROUPS`
works; see *Verified* for what CI showed.

## Commits

- `8b23b68` Treat compiler warnings as errors in every target.
- `45d83e5` A deliberate warning in the app (probe 1).
- The decision, the review rule and this record.

## Verified

Pending: the CI runs on each probe, then the final head.

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
