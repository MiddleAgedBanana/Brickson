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
wait and is not reported. Comments and the words inside strings, raw
strings too, are not read; code inside a string's interpolation is. A wait
whose arguments run over several lines is found on the line where it
starts, and two waits on one line count as two.
"""
import re
import sys
from pathlib import Path

FOLDER = Path(__file__).resolve().parent.parent / "BricksonUITests"

# The helpers themselves, at the top of the folder: the only files that may
# wait on XCTest directly or name a number of seconds.
HELPERS = frozenset({"UIWait.swift", "Waiting.swift"})

# Files whose bare waits are not converted yet, and how many they hold. A
# file may hold fewer, never more. HomeAccessibilityOrderTests.swift holds
# the 7 it had before the helpers and the 2 that pull request #119's
# re-read added (a five-second deadline and a quarter-second pause); they
# move onto the helpers in a later pull request (docs/HANDOFF.md).
# KeyboardSuggestions.swift arrived from main with pull request #125's own
# look at the suggestion bar (a deadline and a half-second pause), kept as
# it merged until the same later pull request moves it onto the helpers.
NOT_YET_CONVERTED = {"HomeAccessibilityOrderTests.swift": 9, "KeyboardSuggestions.swift": 2}

# The words a report gives for each kind of bare wait.
SECONDS = "a number of seconds as a timeout"
ELEMENT_WAIT = "XCTest's own wait for an element"
WAITER = "XCTest's waiter"
PREDICATE = "a predicate expectation"
SLEEP = "a sleep"
RUN_LOOP = "a run loop held for a time"
DEADLINE = "a number of seconds as a deadline"

# What makes a wait bare. Each pattern is read across line breaks. Where
# one opens a parenthesis, the wait runs to the parenthesis that closes it,
# and anything else found inside (its timeout, say) is part of that wait.
BARE = (
    (re.compile(r"\btimeout\s*:\s*[0-9.]"), SECONDS),
    (re.compile(r"\.waitFor(Non)?Existence\s*\("), ELEMENT_WAIT),
    (re.compile(r"\bXCTWaiter\b(\s*\(\s*\))?(\s*\.\s*wait\s*\()?"), WAITER),
    (re.compile(r"\bfulfillment\s*\(\s*of\s*:"), WAITER),
    (re.compile(r"\bwaitForExpectations\s*\("), WAITER),
    (re.compile(r"(?<![\w.])wait\s*\(\s*for\s*:"), WAITER),
    (re.compile(r"\.wait\s*\(\s*for\s*:"), ELEMENT_WAIT),
    (re.compile(r"\bexpectation\s*\(\s*for(Notification)?\s*:"), PREDICATE),
    (re.compile(r"\bXCT(NSPredicate|KVO|NSNotification|Darwin)\w*Expectation\b(\s*\()?"), PREDICATE),
    (re.compile(r"(?<![\w.])u?sleep\s*\("), SLEEP),
    (re.compile(r"\b(Thread|Task)\s*\.\s*sleep\b(\s*\()?"), SLEEP),
    (re.compile(r"\.run\s*\(\s*(mode\s*:[^)]*?)?until\s*:"), RUN_LOOP),
    (re.compile(r"\.(seconds|milliseconds|microseconds|nanoseconds)\s*\(\s*[0-9.]"), DEADLINE),
    (re.compile(r"\b(addingTimeInterval|timeIntervalSinceNow)\b"), DEADLINE),
)

# A string's opening quotes, with the number signs of a raw string.
STRING_OPENING = re.compile(r'(#*)("""|")')


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
            # In a raw string (#"...", depth number signs) an escape and an
            # interpolation start with a backslash and the same signs.
            escape = "\\" + "#" * depth
            if text.startswith(escape + "(", i):
                out.append(" " * (len(escape) + 1))
                stack.append(("interpolation", 0))
                i += len(escape) + 1
            elif text.startswith(escape, i):
                out.append(blank(text[i:i + len(escape) + 1]))
                i += len(escape) + 1
            elif text.startswith(kind + "#" * depth, i):
                out.append(" " * (len(kind) + depth))
                stack.pop()
                i += len(kind) + depth
            else:
                out.append(blank(text[i]))
                i += 1
            continue
        opening = STRING_OPENING.match(text, i) if text[i] in '#"' else None
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
        elif opening:
            out.append(" " * (opening.end() - i))
            stack.append((opening.group(2), len(opening.group(1))))
            i = opening.end()
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


def wait_end(code, start, end):
    """Where the wait found at code[start:end] ends: at the parenthesis that
    closes the last one it opens, or at `end` if it opens none."""
    opening = code.rfind("(", start, end)
    if opening < 0:
        return end
    depth = 0
    for i in range(opening, len(code)):
        if code[i] == "(":
            depth += 1
        elif code[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
    return len(code)


def bare_waits(text):
    """(line, what) for each bare wait in Swift source `text`, on the line
    where it starts."""
    code = code_only(text)
    matches = sorted(
        ((m.start(), -wait_end(code, m.start(), m.end()), what)
         for pattern, what in BARE for m in pattern.finditer(code)),
        key=lambda match: match[:2])
    found, covered = [], 0
    for start, negative_end, what in matches:
        if start >= covered:
            found.append((code.count("\n", 0, start) + 1, what))
            covered = -negative_end
    return found


def problems(folder=FOLDER, not_yet_converted=None):
    """One line for each bare wait outside the helpers, for each file not
    yet converted that holds more bare waits than it did, and for each such
    file that no longer exists."""
    allowed = NOT_YET_CONVERTED if not_yet_converted is None else not_yet_converted
    found = [f"{name}: listed as not yet converted, but there is no such file; "
             "take it off the list" for name in sorted(allowed) if not (folder / name).is_file()]
    for path in sorted(folder.rglob("*.swift")):
        if path.parent == folder and path.name in HELPERS:
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
