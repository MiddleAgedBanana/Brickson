#!/usr/bin/env python3
"""Finds waits in the UI tests that do not go through the shared helpers
(docs/DECISIONS.md, "Tests", 2026-11-17).

Every wait in the UI tests goes through BricksonUITests/Waiting.swift, with
a limit from BricksonUITests/UIWait.swift. There each wait watches a real
condition, its limit stretches on CI where GitHub's Macs are sometimes
overloaded, and a wait that runs out says how long it waited, against which
limit, and how long its slowest look at the app took. A bare wait (a number
of seconds handed to one of XCTest's own waits, a sleep, or a deadline of
its own) has none of that: on an overloaded Mac it runs out on a working
app, and its failure cannot tell that apart from a broken one.

    python3 scripts/ui-test-waits.py     lists every bare wait, by file and
                                         line; exits 1 if there is one

scripts/test-runner.py runs this on the UI tests (UITestWaitTests).

A gesture's own length (press(forDuration:), thenHoldForDuration:) is not a
wait and is not reported. Comments and the words inside strings are not
read; code inside a string's interpolation is.
"""
import re
import sys
from pathlib import Path

FOLDER = Path(__file__).resolve().parent.parent / "BricksonUITests"

# The helpers themselves: the only files that may wait on XCTest directly or
# name a number of seconds.
HELPERS = frozenset({"UIWait.swift", "Waiting.swift"})

# Files whose bare waits are not converted yet, and how many they hold. A
# file may hold fewer, never more. HomeAccessibilityOrderTests.swift is
# being changed by another pull request (#119); its waits move onto the
# helpers once that one has merged (docs/HANDOFF.md).
NOT_YET_CONVERTED = {"HomeAccessibilityOrderTests.swift": 7}

# What makes a wait bare, each with the words a report gives.
BARE = (
    (re.compile(r"\btimeout\s*:\s*[0-9.]"), "a number of seconds as a timeout"),
    (re.compile(r"\.waitFor(Non)?Existence\s*\("), "XCTest's own wait for an element"),
    (re.compile(r"\bXCTWaiter\b"), "XCTest's waiter"),
    (re.compile(r"\bfulfillment\s*\(\s*of\s*:"), "XCTest's waiter"),
    (re.compile(r"\bwaitForExpectations\s*\("), "XCTest's waiter"),
    (re.compile(r"(?<![\w.])wait\s*\(\s*for\s*:"), "XCTest's waiter"),
    (re.compile(r"\.wait\s*\(\s*for\s*:"), "XCTest's own wait for an element"),
    (re.compile(r"\bexpectation\s*\(\s*for(Notification)?\s*:"), "a predicate expectation"),
    (re.compile(r"\bXCT(NSPredicate|KVO|NSNotification|Darwin)\w*Expectation\b"), "a predicate expectation"),
    (re.compile(r"(?<![\w.])u?sleep\s*\("), "a sleep"),
    (re.compile(r"\b(Thread|Task)\s*\.\s*sleep\b"), "a sleep"),
    (re.compile(r"\.run\s*\(\s*(mode\s*:.*)?until\s*:"), "a run loop held for a time"),
    (re.compile(r"\.(seconds|milliseconds|microseconds|nanoseconds)\s*\(\s*[0-9.]"),
     "a number of seconds as a deadline"),
    (re.compile(r"\b(addingTimeInterval|timeIntervalSinceNow)\b"), "a number of seconds as a deadline"),
)


def code_only(text):
    """`text` with comments and the words of string literals replaced by
    spaces, keeping every line break, so line numbers still match. Code
    inside a string's interpolation is kept."""
    out = []
    i, n = 0, len(text)
    # A stack of what encloses the scan: "code", or a string with its
    # closing quote, or an interpolation with its open-paren depth.
    stack = [("code", 0)]

    def blank(chunk):
        return "".join("\n" if c == "\n" else " " for c in chunk)

    while i < n:
        kind, depth = stack[-1]
        if kind in ('"', '"""'):
            if text.startswith("\\(", i):
                out.append("  ")
                stack.append(("interpolation", 0))
                i += 2
            elif text[i] == "\\":
                out.append(blank(text[i:i + 2]))
                i += 2
            elif text.startswith(kind, i):
                out.append(" " * len(kind))
                stack.pop()
                i += len(kind)
            else:
                out.append(blank(text[i]))
                i += 1
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            out.append(blank(text[i:end]))
            i = end
        elif text.startswith("/*", i):
            level, j = 1, i + 2
            while j < n and level:
                if text.startswith("/*", j):
                    level, j = level + 1, j + 2
                elif text.startswith("*/", j):
                    level, j = level - 1, j + 2
                else:
                    j += 1
            out.append(blank(text[i:j]))
            i = j
        elif text.startswith('"""', i):
            out.append("   ")
            stack.append(('"""', 0))
            i += 3
        elif text[i] == '"':
            out.append(" ")
            stack.append(('"', 0))
            i += 1
        elif kind == "interpolation" and text[i] == "(":
            stack[-1] = (kind, depth + 1)
            out.append("(")
            i += 1
        elif kind == "interpolation" and text[i] == ")":
            if depth == 0:
                stack.pop()
                out.append(" ")
            else:
                stack[-1] = (kind, depth - 1)
                out.append(")")
            i += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def bare_waits(text):
    """(line, what) for each bare wait in Swift source `text`."""
    found = []
    for number, line in enumerate(code_only(text).split("\n"), start=1):
        for pattern, what in BARE:
            if pattern.search(line):
                found.append((number, what))
                break
    return found


def problems(folder=FOLDER, not_yet_converted=None):
    """One line for each bare wait outside the helpers, for each file not
    yet converted that holds more bare waits than it did, and for each such
    file that no longer exists."""
    allowed = NOT_YET_CONVERTED if not_yet_converted is None else not_yet_converted
    found = [f"{name}: listed as not yet converted, but there is no such file; "
             "take it off the list" for name in sorted(allowed) if not (folder / name).is_file()]
    for path in sorted(folder.rglob("*.swift")):
        if path.name in HELPERS:
            continue
        waits = bare_waits(path.read_text(encoding="utf-8"))
        name = path.relative_to(folder).as_posix()
        if name in allowed:
            if len(waits) > allowed[name]:
                found.append(f"{name}: {len(waits)} bare waits, more than the {allowed[name]} "
                             "it held before the helpers; use Waiting.swift's waits")
            continue
        found.extend(f"{name}:{line}: {what}; wait with Waiting.swift and a UIWait limit"
                     for line, what in waits)
    return found


def main():
    found = problems()
    for line in found:
        print(line)
    if found:
        print(f"{len(found)} bare waits in the UI tests (docs/DECISIONS.md, \"Tests\").",
              file=sys.stderr)
        return 1
    print("Every UI test wait goes through Waiting.swift.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
