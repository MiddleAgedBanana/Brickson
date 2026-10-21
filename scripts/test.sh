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

project=(-project Brickson.xcodeproj)

# Prints the oldest iOS the app runs on: its deployment target, as Xcode
# reads it from the generated project (IPHONEOS_DEPLOYMENT_TARGET in
# project.yml). No version is written into this script (docs/DECISIONS.md,
# "Build with Apple's current Xcode").
deployment_target() {
    xcodebuild "${project[@]}" -target Brickson -showBuildSettings -json | /usr/bin/python3 -c '
import json, sys
text = sys.stdin.read()
for entry in json.loads(text[text.find("["):]):
    value = entry.get("buildSettings", {}).get("IPHONEOS_DEPLOYMENT_TARGET")
    if value:
        print(value)
        break
else:
    sys.exit("Could not read IPHONEOS_DEPLOYMENT_TARGET from the project.")
'
}

# Prints the id of the newest available iPad simulator that can run the
# tests, preferring an iPad Pro 13-inch. Its iOS is no older than the
# deployment target and no newer than the simulator SDK of the Xcode in use,
# which cannot run a newer simulator.
newest_ipad_simulator() {
    # Called inside $(...), where set -e does not stop at a failure, so
    # each step stops the function itself.
    local oldest newest
    oldest="$(deployment_target)" || return 1
    newest="$(xcrun --sdk iphonesimulator --show-sdk-version)" || return 1
    xcrun simctl list devices available --json | /usr/bin/python3 -c '
import json, re, sys
def version(text):
    parts = [int(part) for part in re.findall(r"\d+", text)][:3]
    return tuple(parts + [0] * (3 - len(parts)))
oldest, newest = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, entries in devices.items():
    match = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime)
    if not match:
        continue
    runtime_version = version(match.group(1))
    if not version(oldest) <= runtime_version <= version(newest):
        continue
    for device in entries:
        name = device["name"]
        if not name.startswith("iPad"):
            continue
        rank = (name.startswith("iPad Pro 13-inch"), runtime_version, name)
        if best is None or rank > best[0]:
            best = (rank, device["udid"])
if best is None:
    sys.exit(f"No iPad simulator with iOS {oldest} to {newest} is installed. "
             "Add one in Xcode: Settings, Components.")
print(best[1])
' "$oldest" "$newest"
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
