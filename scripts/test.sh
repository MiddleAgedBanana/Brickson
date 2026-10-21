#!/usr/bin/env bash
# Builds Brickson and runs its tests. The same script runs on your Mac and
# on GitHub's Mac machines (.github/workflows/tests.yml).
#
#   scripts/test.sh          the unit tests: fast, required before every commit
#   scripts/test.sh ui       the UI tests: launch the real app and drive it
#   scripts/test.sh device   a build for a real iPhone or iPad (no tests);
#                            needs DEVELOPMENT_TEAM set in project.yml
#
# By default the tests run on the newest iPad Pro 13-inch simulator that is
# installed (any iPad if there is none). To choose another, for example:
#
#   DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-unit}"

# Before the unit tests: the documents' cross-references resolve, and the
# Claude Code guard in .claude/hooks still blocks what AGENTS.md forbids.
# Both take a second and need no simulator.
if [ "$mode" = unit ]; then
    /usr/bin/python3 scripts/test-docs.py
    /usr/bin/python3 scripts/test-hooks.py
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is not installed. Install it with: brew install xcodegen" >&2
    exit 1
fi
# The Xcode project is generated from project.yml every time, so it always
# matches the files on disk.
xcodegen generate --quiet

# Prints the id of the newest available iPad simulator running iOS 26 or
# later, preferring an iPad Pro 13-inch.
newest_ipad_simulator() {
    xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match or int(match.group(1)) < 26:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        name = device["name"]
        if not name.startswith("iPad"):
            continue
        rank = (name.startswith("iPad Pro 13-inch"), version, name)
        if best is None or rank > best[0]:
            best = (rank, device["udid"])
if best is None:
    sys.exit("No iPad simulator with iOS 26 or later is installed. Add one in Xcode: Settings, Components.")
print(best[1])
'
}

# xcbeautify shortens xcodebuild's very long output when it is installed
# (brew install xcbeautify). Without it the output is complete but long.
run_xcodebuild() {
    if command -v xcbeautify >/dev/null 2>&1; then
        local raw_log status
        raw_log="$(mktemp "${TMPDIR:-/tmp}/brickson-xcodebuild.XXXXXX")"
        if xcodebuild "$@" 2>&1 | tee "$raw_log" | xcbeautify; then
            command rm -f "$raw_log"
        else
            status=$?
            # The formatter omits Xcode's destination details. Preserve them
            # on failure, along with the original nonzero pipeline status.
            echo "xcodebuild failed; complete output follows:" >&2
            cat "$raw_log" >&2
            command rm -f "$raw_log"
            return "$status"
        fi
    else
        xcodebuild "$@"
    fi
}

project=(-project Brickson.xcodeproj)

case "$mode" in
    unit | ui)
        scheme=Brickson
        [ "$mode" = ui ] && scheme=Brickson-UI
        if [ -n "${DESTINATION:-}" ]; then
            destination="$DESTINATION"
        else
            # Start the default simulator and wait until it has finished
            # starting. Left to xcodebuild, the first app launch can come
            # while the simulator is still settling; on GitHub's busy machines
            # it once timed out ("Timed out while launching application via
            # Xcode"). The simulator stays running afterwards. A DESTINATION
            # you choose is left to xcodebuild.
            udid="$(newest_ipad_simulator)"
            echo "Starting the simulator $udid"
            xcrun simctl bootstatus "$udid" -b
            destination="id=$udid"
        fi
        echo "Testing $scheme on: $destination"
        run_xcodebuild "${project[@]}" -scheme "$scheme" \
            -destination "$destination" \
            -collect-test-diagnostics never \
            test
        # Reached only when every test passed: set -e stops the script at a
        # failure, and pipefail keeps xcodebuild's result through xcbeautify.
        if [ "$mode" = ui ]; then
            echo "All UI tests passed."
        else
            echo "All unit tests passed."
        fi
        ;;
    device)
        run_xcodebuild "${project[@]}" -scheme Brickson \
            -destination 'generic/platform=iOS' \
            build
        echo "The device build succeeded."
        ;;
    *)
        echo "Unknown mode \"$mode\". Use: scripts/test.sh [unit|ui|device]" >&2
        exit 2
        ;;
esac
