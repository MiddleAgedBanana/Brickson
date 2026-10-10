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
        xcodebuild "$@" 2>&1 | xcbeautify
    else
        xcodebuild "$@"
    fi
}

project=(-project Brickson.xcodeproj)

case "$mode" in
    unit | ui)
        scheme=Brickson
        [ "$mode" = ui ] && scheme=Brickson-UI
        destination="${DESTINATION:-id=$(newest_ipad_simulator)}"
        echo "Testing $scheme on: $destination"
        run_xcodebuild "${project[@]}" -scheme "$scheme" \
            -destination "$destination" \
            -collect-test-diagnostics never \
            test
        ;;
    device)
        run_xcodebuild "${project[@]}" -scheme Brickson \
            -destination 'generic/platform=iOS' \
            build
        ;;
    *)
        echo "Unknown mode \"$mode\". Use: scripts/test.sh [unit|ui|device]" >&2
        exit 2
        ;;
esac
