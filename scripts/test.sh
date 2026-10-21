#!/usr/bin/env bash
# Builds Brickson and runs its tests. The same script runs on your Mac and
# on GitHub's Mac machines (.github/workflows/tests.yml).
#
#   scripts/test.sh          the unit tests: fast, required before every commit
#   scripts/test.sh ui       the UI tests: launch the real app and drive it
#   scripts/test.sh device   a build for a real iPhone or iPad (no tests).
#                            Without DEVELOPMENT_TEAM in project.yml it builds
#                            unsigned: a check that the code compiles for a
#                            device, with nothing you can install.
#
# Anything after the mode goes to xcodebuild, for example one test (a Swift
# Testing name needs its parentheses):
#
#   scripts/test.sh unit '-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()'
#
# Which simulator. By default the newest iPad Pro 13-inch simulator (any iPad
# if there is none) whose iOS lies between the app's deployment target and
# the SDK of the Xcode in use. It is chosen by device type, never by name, so
# a renamed simulator still counts. To choose another:
#
#   SIMULATOR_FAMILY=iphone scripts/test.sh ui     the newest standard iPhone
#   DESTINATION='platform=iOS Simulator,id=<udid>' scripts/test.sh
#
# The script says which simulator it chose, starts it and waits until it has
# finished starting (a DESTINATION's simulator too). A device this script
# boots is shut down after its run, before the next family starts; a device
# that was already running is left running.
# Before UI tests it turns off the keyboard's minimized bar, so typing tests
# see the full software keyboard people actually use, and launches the app
# once so the first test doesn't pay for a cold simulator.
#
# Every test run keeps its results, with a screenshot of each UI test
# failure, in build/TestResults/<mode>-<family>.xcresult (open it in Xcode),
# and prints how many tests ran. A run in which no test ran fails.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-unit}"
if [ "$#" -gt 0 ]; then
    shift
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is not installed. Install it with: brew install xcodegen" >&2
    exit 1
fi
# Which tools made this run, for anyone reading the log later.
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "XcodeGen: $(xcodegen --version)"

# The Xcode project is generated from project.yml every time, so it always
# matches the files on disk.
xcodegen generate --quiet

project=(-project Brickson.xcodeproj)
# Builds go here rather than Xcode's shared DerivedData folder, so each
# checkout (and each agent's worktree) builds on its own and later steps
# can find what the build wrote. scripts/test-runner.py points both
# folders elsewhere.
derived_data="${DERIVED_DATA_DIR:-build/DerivedData}"
results_dir="${TEST_RESULTS_DIR:-build/TestResults}"
catalog="${STRING_CATALOG:-Brickson/Resources/Localizable.xcstrings}"

# Prints one build setting of the app, as Xcode reads it from the
# generated project; nothing when it is not set.
build_setting() {
    xcodebuild "${project[@]}" -target Brickson -showBuildSettings -json | /usr/bin/python3 -c '
import json, sys
text = sys.stdin.read()
entries = json.loads(text[text.find("["):])
print(next((entry.get("buildSettings", {}).get(sys.argv[1], "") for entry in entries), ""))
' "$1"
}

# Prints the oldest iOS the app runs on: its deployment target
# (IPHONEOS_DEPLOYMENT_TARGET in project.yml). No version is written into
# this script (docs/DECISIONS.md, "Build with Apple's current Xcode").
deployment_target() {
    local value
    value="$(build_setting IPHONEOS_DEPLOYMENT_TARGET)" || return 1
    if [ -z "$value" ]; then
        echo "Could not read IPHONEOS_DEPLOYMENT_TARGET from the project." >&2
        return 1
    fi
    echo "$value"
}

# Prints the id of the newest simulator of a family ("ipad" or "iphone")
# that can run the tests: its iOS is no older than the deployment target
# and no newer than the simulator SDK of the Xcode in use, which cannot run
# a newer simulator. scripts/choose-simulator.py says which it chose.
newest_simulator() {
    # Called inside $(...), where set -e does not stop at a failure, so
    # each step stops the function itself.
    local family="$1" oldest newest
    oldest="$(deployment_target)" || return 1
    newest="$(xcrun --sdk iphonesimulator --show-sdk-version)" || return 1
    xcrun simctl list devices available --json |
        /usr/bin/python3 -I scripts/choose-simulator.py \
            --family "$family" --min "$oldest" --max "$newest"
}

# Prints the id of the simulator DESTINATION names, so the script can wait
# for the same device xcodebuild uses. Its iOS must lie in the same range
# as a simulator chosen by family; a name without OS= gets the newest
# runtime in that range, the one xcodebuild can run. Prints nothing when
# DESTINATION is not a single simulator (a real device, say): xcodebuild
# then chooses.
destination_simulator() {
    local listing oldest newest status=0
    oldest="$(deployment_target)" || return 1
    newest="$(xcrun --sdk iphonesimulator --show-sdk-version)" || return 1
    listing="$(xcrun simctl list devices available --json)" || return 1
    printf '%s' "$listing" |
        /usr/bin/python3 -I scripts/choose-simulator.py --destination "$DESTINATION" \
            --min "$oldest" --max "$newest" ||
        status=$?
    # 3: not a simulator this script can resolve; anything else is an error.
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || return "$status"
}

# Only a successful boot gives this invocation ownership of a simulator.
# Never stop a device that was already running, or use `shutdown all`:
# another agent or the owner may be using it.
owned_simulator=""
simulator_cleanup_failed=0

simulator_state() {
    xcrun simctl list devices available --json | /usr/bin/python3 -I -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for family in devices.values():
    for device in family:
        if device["udid"] == sys.argv[1]:
            print(device["state"])
            sys.exit(0)
sys.exit("Could not read simulator state for " + sys.argv[1])
' "$1"
}

cleanup_simulator() {
    local udid="$owned_simulator"
    [ -n "$udid" ] || return 0
    # A failed shutdown is reported once; don't retry it in the exit trap.
    owned_simulator=""
    echo "Shutting down simulator $udid (booted by this test run)"
    if ! xcrun simctl shutdown "$udid"; then
        simulator_cleanup_failed=1
        echo "Could not shut down simulator $udid; stopping before another family starts." >&2
        return 1
    fi
}

finish() {
    local status=$?
    trap - EXIT
    cleanup_simulator || { [ "$status" -ne 0 ] || status=1; }
    exit "$status"
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Simulators minimize the software keyboard to a bar, as if a hardware
# keyboard were attached. The people using Brickson type on the full
# software keyboard, which covers far more of the screen, so UI tests must
# meet that one (docs/LESSONS.md, "Test with the real software keyboard").
# Typing tests still check the keyboard's height, so a setting that did not
# take effect fails them rather than passing with the bar.
show_full_keyboard() {
    xcrun simctl spawn "$1" defaults write com.apple.keyboard.preferences \
        AutomaticMinimizationEnabled -bool false
    echo "Software keyboard: full size (minimized bar turned off)"
}

# The first launch of the app on a simulator that has just started can be
# very slow. On CI the first UI test has failed that way while every later
# one passed (docs/HANDOFF.md; AGENTS.md, Gotchas), so the app is installed
# and launched once, on test-only storage, before the tests start. This
# only prepares the simulator: no test is retried or skipped, and if the
# warm-up itself fails, the script says so and the tests run anyway, so
# their results show what is wrong.
warm_up() {
    local udid="$1" app bundle_id start
    app="$derived_data/Build/Products/Debug-iphonesimulator/Brickson.app"
    if [ ! -d "$app" ]; then
        echo "warning: no app at $app, so the simulator was not warmed up." >&2
        return 0
    fi
    if ! bundle_id="$(/usr/bin/python3 -I -c '
import plistlib, sys
with open(sys.argv[1], "rb") as file:
    print(plistlib.load(file)["CFBundleIdentifier"])
' "$app/Info.plist")"; then
        echo "warning: could not read the app's bundle identifier, so the simulator was not warmed up." >&2
        return 0
    fi
    start=$SECONDS
    if xcrun simctl install "$udid" "$app" &&
        xcrun simctl launch "$udid" "$bundle_id" --fresh-test-storage >/dev/null; then
        # Long enough to draw its first screen; the first UI test then
        # launches it afresh.
        sleep 15
        xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
        echo "Warm-up: launched Brickson once before the tests ($((SECONDS - start)) s, test-only storage)."
    else
        echo "warning: the warm-up launch failed; the UI tests run anyway." >&2
    fi
}

# Prints how many tests ran, and fails when none did: a filter that matches
# no test (a Swift Testing name without its parentheses, say) otherwise
# reports success. A summary that cannot be read fails the run too, since
# then nothing shows that any test ran.
report_test_count() {
    local summary
    if ! summary="$(xcrun xcresulttool get test-results summary --path "$1" 2>/dev/null)"; then
        echo "error: could not read the test summary in $1, so nothing shows that any test ran." >&2
        return 1
    fi
    printf '%s' "$summary" | /usr/bin/python3 -I -c '
import json, sys
summary = json.load(sys.stdin)
total = summary.get("totalTestCount")
if total is None:
    print("error: the test summary has no test count, so nothing shows that any test ran.", file=sys.stderr)
    sys.exit(1)
counts = ", ".join(f"{summary.get(key, 0)} {label}" for key, label in [
    ("passedTests", "passed"), ("failedTests", "failed"),
    ("skippedTests", "skipped"), ("expectedFailures", "expected failures")])
devices = "; ".join(
    "{} ({} {})".format(entry.get("device", {}).get("deviceName", "?"),
                        entry.get("device", {}).get("platform", ""),
                        entry.get("device", {}).get("osVersion", "?"))
    for entry in summary.get("devicesAndConfigurations", []))
print(f"{total} tests ran" + (f" on {devices}" if devices else "") + f": {counts}.")
if total == 0:
    sys.exit("No tests ran. A filter that matches nothing reports success; a Swift Testing "
             "name needs its parentheses (AGENTS.md, Gotchas).")
'
}

# Prints how much of the app's code the unit tests ran (project.yml turns
# coverage on for the Brickson scheme). Coverage is a guide to what is not
# tested at all, not a target; a run without it only warns.
report_coverage() {
    local report
    if ! report="$(xcrun xccov view --report --only-targets --json "$1" 2>/dev/null)"; then
        echo "warning: could not read code coverage from $1." >&2
        return 0
    fi
    printf '%s' "$report" | /usr/bin/python3 -I -c '
import json, sys
report = json.load(sys.stdin)
targets = report if isinstance(report, list) else report.get("targets", [])
for target in targets:
    if target.get("name", "").split(".")[0] == "Brickson":
        print("Code coverage: the unit tests ran {:.1%} of the app'"'"'s lines ({} of {}).".format(
            target.get("lineCoverage", 0), target.get("coveredLines", "?"),
            target.get("executableLines", "?")))
        break
else:
    print("warning: the coverage report names no Brickson target.", file=sys.stderr)
' || echo "warning: could not read code coverage from $1." >&2
}

# The String Catalog holds every string people see, ready for translation.
# Xcode's editor fills it in as it builds; xcodebuild does not. So after a
# unit-test build the script brings a copy up to date from the strings the
# compiler found (SWIFT_EMIT_LOC_STRINGS in project.yml). On a Mac it
# writes the result into the catalog, to commit with the change. On CI
# (CI=true) a catalog that does not match the code fails the run, with the
# difference printed so it can be applied without a Mac.
check_string_catalog() {
    local strings_data folder synced
    strings_data=("$derived_data"/Build/Intermediates.noindex/Brickson.build/*-iphonesimulator/Brickson.build/Objects-normal/*/*.stringsdata)
    if [ ! -e "${strings_data[0]}" ]; then
        echo "The build left no strings for the String Catalog (.stringsdata files), so it could not be checked." >&2
        return 1
    fi
    folder="$(mktemp -d "${TMPDIR:-/tmp}/brickson-strings.XXXXXX")" || return 1
    synced="$folder/Localizable.xcstrings"
    command cp "$catalog" "$synced" || return 1
    if ! xcrun xcstringstool sync "$synced" --stringsdata "${strings_data[@]}"; then
        echo "xcstringstool could not bring the String Catalog up to date." >&2
        return 1
    fi
    if cmp -s "$catalog" "$synced"; then
        echo "String Catalog: up to date with the code."
    elif [ "${CI:-}" = true ]; then
        echo "The String Catalog ($catalog) does not match the code. The up-to-date catalog differs like this:" >&2
        diff -u "$catalog" "$synced" >&2 || true
        echo "Run scripts/test.sh on a Mac and commit $catalog, or apply the difference above." >&2
        command rm -rf "$folder"
        return 1
    else
        command cp "$synced" "$catalog" || return 1
        echo "String Catalog: updated $catalog from the code. Commit it with your change."
    fi
    command rm -rf "$folder"
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

# Runs the tests of $scheme on one simulator: the newest of a family
# ("ipad" or "iphone"), or the one DESTINATION names ("destination").
# Called after || below, where set -e no longer stops a failing step, so
# every step returns its own failure.
run_tests_on_simulator() {
    local family="$1" udid destination state status=0 catalog_status=0
    local results="$results_dir/$mode-$family.xcresult"
    # Remove the last run's bundle first, so a run that stops before
    # testing never leaves an old bundle that looks like its result.
    # (xcodebuild also will not write over one.)
    command rm -rf "$results" || return 1
    if [ "$family" = destination ]; then
        udid="$(destination_simulator)" || return 1
        # The same simulator, by id, for the wait and the build.
        if [ -n "$udid" ]; then
            destination="id=$udid"
        else
            destination="$DESTINATION"
        fi
    else
        udid="$(newest_simulator "$family")" || return 1
        destination="id=$udid"
    fi
    if [ -n "$udid" ]; then
        state="$(simulator_state "$udid")" || return 1
        case "$state" in
            Shutdown)
                xcrun simctl boot "$udid" || return 1
                owned_simulator="$udid"
                ;;
            Booted | Booting) ;;
            *)
                echo "Simulator $udid is $state; wait for it to finish before testing." >&2
                return 1
                ;;
        esac
        # Start the simulator and wait until it has finished starting.
        # Left to xcodebuild, the first app launch can come while the
        # simulator is still settling; on GitHub's busy machines it once
        # timed out ("Timed out while launching application via Xcode").
        echo "Starting the simulator $udid and waiting for it"
        xcrun simctl bootstatus "$udid" -b || return 1
        if [ "$mode" = ui ]; then
            show_full_keyboard "$udid" || return 1
        fi
    fi
    # Build first and test after, so the log shows which of the two failed,
    # and UI tests can warm the simulator up in between.
    echo "Building $scheme for testing on: $destination"
    run_xcodebuild "${project[@]}" -scheme "$scheme" \
        -destination "$destination" \
        -derivedDataPath "$derived_data" \
        "${extra_arguments[@]+"${extra_arguments[@]}"}" \
        build-for-testing || return $?
    if [ "$mode" = ui ] && [ -n "$udid" ]; then
        warm_up "$udid"
    fi
    # The tests run even when the catalog is out of date, so one run shows
    # both.
    if [ "$mode" = unit ] && [ -n "$udid" ]; then
        check_string_catalog || catalog_status=$?
    fi
    echo "Testing $scheme on: $destination"
    mkdir -p "$results_dir" || return 1
    run_xcodebuild "${project[@]}" -scheme "$scheme" \
        -destination "$destination" \
        -derivedDataPath "$derived_data" \
        -resultBundlePath "$results" \
        -collect-test-diagnostics never \
        "${extra_arguments[@]+"${extra_arguments[@]}"}" \
        test-without-building || status=$?
    echo "Test results, with screenshots of any UI test failure: $results"
    if [ "$status" -ne 0 ]; then
        # Still say how far the run got; the test failure decides the result.
        report_test_count "$results" || true
        return "$status"
    fi
    report_test_count "$results" || return 1
    if [ "$mode" = unit ]; then
        report_coverage "$results"
    fi
    return "$catalog_status"
}

# All early returns after boot go through cleanup, including failed
# preparation, builds, tests and result summaries. Keep the original test
# failure when cleanup also fails. The exit trap covers interrupted runs.
run_tests() {
    local status=0
    run_tests_on_simulator "$1" || status=$?
    cleanup_simulator || { [ "$status" -ne 0 ] || status=1; }
    return "$status"
}

case "$mode" in
    unit | ui)
        scheme=Brickson
        [ "$mode" = ui ] && scheme=Brickson-UI
        extra_arguments=("$@")
        if [ -n "${DESTINATION:-}" ]; then
            families=destination
        elif [ -n "${SIMULATOR_FAMILY:-}" ]; then
            case "$SIMULATOR_FAMILY" in
                ipad | iphone) families="$SIMULATOR_FAMILY" ;;
                *)
                    echo "SIMULATOR_FAMILY must be ipad or iphone, not \"$SIMULATOR_FAMILY\"." >&2
                    exit 2
                    ;;
            esac
        elif [ "$mode" = ui ]; then
            # The iPad and the iPhone are both first-class (AGENTS.md), and
            # layouts differ most between them, so UI tests run on both.
            families="ipad iphone"
        else
            families=ipad
        fi
        # Each family runs even when an earlier one failed, so one run shows
        # everything that is wrong. The script fails with the first failure.
        status=0
        for family in $families; do
            run_tests "$family" || {
                result=$?
                echo "The $mode run failed on the $family simulator (status $result)." >&2
                [ "$status" -ne 0 ] || status=$result
            }
            [ "$simulator_cleanup_failed" -eq 0 ] || break
        done
        [ "$status" -eq 0 ] || exit "$status"
        if [ "$mode" = ui ]; then
            echo "All UI tests passed."
        else
            echo "All unit tests passed."
        fi
        ;;
    device)
        signing=""
        if [ -z "$(build_setting DEVELOPMENT_TEAM)" ]; then
            echo "No DEVELOPMENT_TEAM in project.yml: building without signing. This checks the code compiles for a device; nothing installable is made."
            signing="CODE_SIGNING_ALLOWED=NO"
        fi
        run_xcodebuild "${project[@]}" -scheme Brickson \
            -destination 'generic/platform=iOS' \
            -derivedDataPath "$derived_data" \
            ${signing:+"$signing"} \
            "$@" \
            build
        echo "The device build succeeded."
        ;;
    *)
        echo "Unknown mode \"$mode\". Use: scripts/test.sh [unit|ui|device] [xcodebuild arguments]" >&2
        exit 2
        ;;
esac
