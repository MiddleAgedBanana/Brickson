#!/usr/bin/env python3
"""Splits the UI tests into parts, so CI can run each part on a machine of
its own at the same time (docs/DECISIONS.md, "Tests"). scripts/test.sh runs
one part when UI_TEST_PART names it:

    UI_TEST_PART=2 SIMULATOR_FAMILY=ipad scripts/test.sh ui

    ui-test-parts.py count            how many parts there are
    ui-test-parts.py arguments <n>    xcodebuild's arguments for part n,
                                      one per line
    ui-test-parts.py describe <n>     which test classes part n runs
    ui-test-parts.py check            every class a part names is a UI
                                      test class, named once

Every part but the last runs the classes it names. The last runs every
other class, so a class added to the UI tests runs there until someone
places it, and no class can be left out of every part. Each class named
here must be a UI test class (a misspelled one would otherwise run in no
part), and named in one part only.

The parts are balanced by how long each class took on GitHub's machines
(docs/log/2026-11-16-ui-test-parts.md has the table): about a third of
the suite's time each. When a class grows a lot, move classes between
parts, or into the last, to keep them even.
"""
import re
import sys
from pathlib import Path

TARGET = "BricksonUITests"
FOLDER = Path(__file__).resolve().parent.parent / TARGET

PARTS = (
    # About 14 minutes of Settings and 4 of Home's sizes and order on a
    # normal day.
    ("SettingsTests", "HomeSizesTests", "HomeAccessibilityOrderTests",
     "KeyboardProbeTests", "SlowPressTests"),
    # About 10 minutes of the Library and 8 of Home's board and reach.
    ("LibraryTests", "HomeRestBoardTests", "HomeReachabilityTests"),
    # The last part runs every class not named above.
)

CLASS = re.compile(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b", re.M)


def test_classes(folder=FOLDER):
    """The XCTestCase classes declared in the UI tests' Swift files, in the
    folder and every folder inside it, as project.yml builds them."""
    found = set()
    for path in sorted(folder.rglob("*.swift")):
        found.update(CLASS.findall(path.read_text(encoding="utf-8")))
    return found


def problems(parts=PARTS, folder=FOLDER):
    """What is wrong with the parts: a class that is no UI test class, or
    one named twice. Empty when they are sound."""
    found, seen, wrong = test_classes(folder), set(), []
    if not found:
        wrong.append(f"No XCTestCase class was found in {folder}.")
    for number, part in enumerate(parts, 1):
        if not part:
            wrong.append(f"Part {number} names no class.")
        for name in part:
            if name not in found:
                wrong.append(f"Part {number} names {name}, which is not a UI test class "
                             f"in {folder.name}.")
            if name in seen:
                wrong.append(f"{name} is named in more than one part.")
            seen.add(name)
    if found and not found - seen:
        wrong.append("Every UI test class is named, so the last part would run nothing.")
    return wrong


def part_number(text, parts=PARTS):
    count = len(parts) + 1
    if not re.fullmatch(r"[1-9]\d*", text or "") or int(text) > count:
        raise ValueError(f"UI_TEST_PART must be a part from 1 to {count}, not \"{text}\".")
    return int(text)


def arguments(number, parts=PARTS):
    """xcodebuild's arguments that run part `number` of the UI tests."""
    if number <= len(parts):
        return [f"-only-testing:{TARGET}/{name}" for name in parts[number - 1]]
    return [f"-skip-testing:{TARGET}/{name}" for part in parts for name in part]


def describe(number, parts=PARTS, folder=FOLDER):
    count = len(parts) + 1
    if number <= len(parts):
        names = parts[number - 1]
    else:
        named = {name for part in parts for name in part}
        names = sorted(test_classes(folder) - named)
    return f"UI tests, part {number} of {count}: " + ", ".join(names)


def unsound():
    """Prints what is wrong with the parts; whether anything was."""
    wrong = problems()
    for line in wrong:
        print(line, file=sys.stderr)
    return bool(wrong)


def main(argv):
    command = argv[0] if argv else ""
    if command == "count" and len(argv) == 1:
        print(len(PARTS) + 1)
        return 0
    if command == "check" and len(argv) == 1:
        if unsound():
            return 1
        print(f"The UI tests' {len(PARTS) + 1} parts are sound.")
        return 0
    if command not in ("arguments", "describe") or len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    if unsound():
        return 1
    try:
        number = part_number(argv[1])
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    print("\n".join(arguments(number)) if command == "arguments" else describe(number))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
