#!/usr/bin/env python3
"""Exercise test.sh's error reporting and simulator choice without booting a
simulator, check the simulator watcher it starts (simulator-load.py), and
check that CI runs it with the newest released Xcode."""
import argparse
import contextlib
import importlib.util
import io
import itertools
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

SCRIPT = Path(__file__).resolve().with_name("test.sh")
WORKFLOW = SCRIPT.parent.parent / ".github" / "workflows" / "tests.yml"

# Answers the version and build-settings queries from the fixture, and
# records every other xcodebuild run, one line of tab-separated arguments
# each. A build for testing leaves an app, and the strings the compiler
# found, where test.sh looks for them. The test's own body runs last and
# sees the run's last argument, its action, as $action.
FAKE_XCODEBUILD = """\
for argument in "$@"; do
    case "$argument" in
        -showBuildSettings)
            printf '[{"target":"Brickson","buildSettings":{"IPHONEOS_DEPLOYMENT_TARGET":"%s","DEVELOPMENT_TEAM":"%s"}}]\\n' \\
                "$FIXTURE_TARGET" "$FIXTURE_TEAM"
            exit 0 ;;
        -version)
            printf 'Xcode 99.1\\nBuild version 99A1\\n'
            exit 0 ;;
    esac
done
(IFS=$'\\t'; echo "$*") >> "$RUNNER_INVOCATIONS"
action="${!#}"
echo "$action" >> "$RUNNER_EVENTS"
if [ "$action" = build-for-testing ]; then
    app="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/Brickson.app"
    mkdir -p "$app"
    cp "$FIXTURE_INFO_PLIST" "$app/Info.plist"
    if [ "$FIXTURE_STRINGS" = yes ]; then
        objects="$DERIVED_DATA_DIR/Build/Intermediates.noindex/Brickson.build/Debug-iphonesimulator/Brickson.build/Objects-normal/arm64"
        mkdir -p "$objects"
        echo strings > "$objects/HomeView.stringsdata"
    fi
fi
"""

# The simulator list, the selected Xcode's simulator SDK, the result
# summary and the coverage report come from the fixture; every simulator
# and String Catalog command is recorded. Syncing the catalog writes the
# fixture's catalog over the copy it is given, or leaves the copy as it was.
FAKE_XCRUN = """\
case "$*" in
    "simctl list devices available --json") cat "$FIXTURE_DEVICES" ;;
    "--sdk iphonesimulator --show-sdk-version") echo "$FIXTURE_SDK" ;;
    "simctl boot "* | "simctl bootstatus "*" -b" | "simctl shutdown "* | "simctl spawn "* | "simctl install "* | \\
        "simctl terminate "*)
        echo "$*" >> "$RUNNER_SIMCTL"
        case "$2" in
            boot) exit "$FIXTURE_BOOT_STATUS" ;;
            bootstatus) exit "$FIXTURE_BOOTSTATUS_STATUS" ;;
            shutdown) exit "$FIXTURE_SHUTDOWN_STATUS" ;;
        esac ;;
    "simctl launch "*)
        echo "$*" >> "$RUNNER_SIMCTL"
        exit "${FIXTURE_LAUNCH_STATUS:-0}" ;;
    "xcresulttool get test-results summary --path "*)
        [ -n "$FIXTURE_SUMMARY" ] || exit 1
        printf '%s\\n' "$FIXTURE_SUMMARY" ;;
    "xccov view --report --only-targets --json "*)
        [ -n "$FIXTURE_COVERAGE" ] || exit 1
        printf '%s\\n' "$FIXTURE_COVERAGE" ;;
    "xcstringstool sync "*)
        echo "xcstringstool sync" >> "$RUNNER_SIMCTL"
        [ "$FIXTURE_SYNC_STATUS" = 0 ] || exit "$FIXTURE_SYNC_STATUS"
        if [ -n "$FIXTURE_SYNCED_CATALOG" ]; then
            printf '%s' "$FIXTURE_SYNCED_CATALOG" > "$3"
        fi ;;
    *) echo "unexpected: xcrun $*" >&2; exit 1 ;;
esac
"""

# Stands in for scripts/simulator-load.py: records each start and stop
# among the simulator commands, and the test run's pid it was given.
FAKE_SIMULATOR_LOAD = """\
import os, sys
from pathlib import Path
arguments = sys.argv[1:]
def value(name):
    return arguments[arguments.index(name) + 1]
with Path(os.environ["RUNNER_SIMCTL"]).open("a") as log:
    if arguments[0] == "start":
        Path(os.environ["RUNNER_LOAD_PARENT"]).write_text(value("--parent"))
        pausing = "pausing" if "--pause-posters" in arguments else "watching"
        log.write(f"load start {value('--udid')} {pausing} {Path(value('--out')).name}\\n")
        status = int(os.environ.get("FIXTURE_LOAD_START_STATUS", "0"))
        if status == 0:
            print(4242)
        sys.exit(status)
    log.write(f"load stop {value('--pid')} {Path(value('--out')).name}\\n")
    print("Processor time the simulator's processes used while watched: (fixture)")
"""

INFO_PLIST = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>fixture.brickson</string>
</dict></plist>
"""


CATALOG = '{\n  "sourceLanguage" : "en",\n  "strings" : {\n\n  },\n  "version" : "1.0"\n}\n'
SYNCED_CATALOG = CATALOG.replace('"strings" : {\n\n  }', '"strings" : {\n    "Yes" : {\n\n    }\n  }')

# What xccov reports for the app target.
COVERAGE = json.dumps([{"name": "Brickson.app", "lineCoverage": 0.4567,
                        "coveredLines": 457, "executableLines": 1000}])


def summary(total, passed=None, failed=0):
    """An xcresulttool summary of a run of `total` tests on one iPad."""
    return json.dumps({
        "totalTestCount": total,
        "passedTests": total - failed if passed is None else passed,
        "failedTests": failed, "skippedTests": 0, "expectedFailures": 0,
        "devicesAndConfigurations": [{"device": {
            "deviceName": "iPad Pro 13-inch (M5)", "platform": "iOS Simulator",
            "osVersion": "27.1"}}],
    })


def lines(path):
    return path.read_text().splitlines() if path.exists() else []


def run_script(build_body, mode="ui", destination="id=fixture-simulator",
               target="26.0", sdk="27.1", devices=None, team="",
               test_summary=summary(3), family=None, arguments=(),
               coverage=COVERAGE, strings=True, synced_catalog=None,
               sync_status=0, on_ci=True, boot_status=0,
               bootstatus_status=0, shutdown_status=0, docs_status=0, hooks_status=0):
    with tempfile.TemporaryDirectory() as directory:
        # Exercise the exact checked-in runner and selector in an isolated
        # checkout. Preflights are dependencies, like the mocked Apple tools:
        # verify their order and failures here; run their real suites once in
        # the unit gate, with its normal PATH (including gh for alias reads).
        fixture_scripts = Path(directory, "repo", "scripts")
        fixture_scripts.mkdir(parents=True)
        for name in ("test.sh", "choose-simulator.py"):
            (fixture_scripts / name).write_bytes((SCRIPT.parent / name).read_bytes())
        (fixture_scripts / "simulator-load.py").write_text(FAKE_SIMULATOR_LOAD)
        for name, status in (("docs", docs_status), ("hooks", hooks_status)):
            (fixture_scripts / f"test-{name}.py").write_text(
                "import os, sys\nfrom pathlib import Path\n"
                'with Path(os.environ["RUNNER_EVENTS"]).open("a") as log:\n'
                f"    log.write({name!r} + '\\n')\n"
                f"sys.exit({status})\n")
        for name, body in {
            "xcodegen": 'if [ "${1:-}" = --version ]; then echo "Version: 9.9.9"; fi',
            "xcodebuild": FAKE_XCODEBUILD + build_body,
            "xcrun": FAKE_XCRUN,
            # Model the formatter discarding destination-detail lines.
            "xcbeautify": "cat >/dev/null",
            # The warm-up waits for the app; the tests need not.
            "sleep": 'echo "sleep $*" >> "$RUNNER_SIMCTL"',
        }.items():
            path = Path(directory, name)
            path.write_text("#!/bin/bash\n" + body + "\n")
            path.chmod(0o755)
        devices_path = Path(directory, "devices.json")
        devices_path.write_text(json.dumps({"devices": devices or {}}))
        plist_path = Path(directory, "Info.plist")
        plist_path.write_text(INFO_PLIST)
        catalog_path = Path(directory, "Localizable.xcstrings")
        catalog_path.write_text(CATALOG)
        environment = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin",
                           RUNNER_INVOCATIONS=f"{directory}/invocations",
                           RUNNER_EVENTS=f"{directory}/events",
                           RUNNER_SIMCTL=f"{directory}/simctl",
                           RUNNER_LOAD_PARENT=f"{directory}/load-parent",
                           FIXTURE_DEVICES=str(devices_path),
                           FIXTURE_INFO_PLIST=str(plist_path),
                           FIXTURE_TARGET=target, FIXTURE_SDK=sdk,
                           FIXTURE_TEAM=team, FIXTURE_SUMMARY=test_summary or "",
                           FIXTURE_COVERAGE=coverage or "",
                           FIXTURE_STRINGS="yes" if strings else "no",
                           FIXTURE_SYNCED_CATALOG=synced_catalog or "",
                           FIXTURE_SYNC_STATUS=str(sync_status),
                           FIXTURE_BOOT_STATUS=str(boot_status),
                           FIXTURE_BOOTSTATUS_STATUS=str(bootstatus_status),
                           FIXTURE_SHUTDOWN_STATUS=str(shutdown_status),
                           CI="true" if on_ci else "",
                           STRING_CATALOG=str(catalog_path),
                           DERIVED_DATA_DIR=f"{directory}/DerivedData",
                           TEST_RESULTS_DIR=f"{directory}/TestResults")
        for name in ("DESTINATION", "SIMULATOR_FAMILY"):
            environment.pop(name, None)
        if destination is not None:
            environment["DESTINATION"] = destination
        if family is not None:
            environment["SIMULATOR_FAMILY"] = family
        stale = Path(directory, "TestResults", f"{mode}-ipad.xcresult", "stale")
        stale.parent.mkdir(parents=True)
        stale.write_text("from an earlier run")
        stale_record = Path(directory, "TestResults", "simulator-load-ipad.txt")
        stale_record.write_text("from an earlier run")
        result = subprocess.run(["/bin/bash", str(fixture_scripts / "test.sh"), mode, *arguments],
                                env=environment, capture_output=True, text=True)
        result.events = lines(Path(directory, "events"))
        result.preflights = [event for event in result.events if event in ("docs", "hooks")]
        result.calls = lines(Path(directory, "invocations"))
        result.invocations = len(result.calls)
        result.simctl = lines(Path(directory, "simctl"))
        result.stale_bundle_kept = stale.exists()
        result.stale_record_kept = stale_record.exists()
        result.results_dir = f"{directory}/TestResults"
        result.catalog = catalog_path.read_text()
        return result


def runtime(version):
    return "com.apple.CoreSimulator.SimRuntime.iOS-" + version.replace(".", "-")


def device(name, udid, kind=None, state="Shutdown"):
    """A simulator as simctl lists it. Its type comes from its name unless
    given: "iPad Pro 13-inch (M5)" is of type iPad-Pro-13-inch-M5."""
    if kind is None:
        kind = re.sub(r"[^A-Za-z0-9]+", "-", name).strip("-")
    return {"name": name, "udid": udid, "isAvailable": True, "state": state,
            "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType." + kind}


def arguments_of(call):
    return call.split("\t")


def actions(result):
    """Each xcodebuild run's action and -destination, in order."""
    found = []
    for call in result.calls:
        words = arguments_of(call)
        destination = words[words.index("-destination") + 1] if "-destination" in words else None
        found.append((words[-1], destination))
    return found


class PreflightTests(unittest.TestCase):
    # Removing or reordering a preflight, or swallowing its exit status,
    # fails these tests; the real suites run once in scripts/test.sh unit.
    def test_unit_preflights_run_in_order_before_building(self):
        result = run_script("exit 0", mode="unit")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.events, ["docs", "hooks",
                                         "build-for-testing", "test-without-building"])
        self.assertEqual([name for name, _ in actions(result)],
                         ["build-for-testing", "test-without-building"])

    def test_each_preflight_failure_stops_before_the_build(self):
        for docs_status, hooks_status, expected in [(37, 0, ["docs"]),
                                                    (0, 42, ["docs", "hooks"])]:
            with self.subTest(docs=docs_status, hooks=hooks_status):
                result = run_script("exit 0", mode="unit",
                                    docs_status=docs_status, hooks_status=hooks_status)
                self.assertEqual(result.returncode, docs_status or hooks_status)
                self.assertEqual(result.events, expected)
                self.assertEqual(result.calls, [])
                self.assertNotIn("All unit tests passed.", result.stdout)

    def test_other_modes_do_not_repeat_unit_preflights(self):
        for mode in ["ui", "device"]:
            with self.subTest(mode=mode):
                result = run_script("exit 0", mode=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.preflights, [])
                self.assertGreater(result.invocations, 0)


class RunnerTests(unittest.TestCase):
    def run_script(self, build_body):
        return run_script(build_body)

    # Removing the raw-log fallback hides the reason and fails this test.
    def test_failed_build_preserves_status_and_destination_details(self):
        result = self.run_script(
            "echo 'Unavailable destination: iOS runtime is not installed' >&2\nexit 70")
        self.assertEqual(result.returncode, 70)
        self.assertIn("Unavailable destination: iOS runtime is not installed",
                      result.stdout + result.stderr)
        self.assertNotIn("All UI tests passed.", result.stdout)

    # Ignoring xcodebuild's result or retrying assertion failures fails this.
    def test_test_failure_is_not_retried_or_called_success(self):
        result = self.run_script(
            'if [ "$action" = test-without-building ]; then echo "assertion failure"; exit 65; fi')
        self.assertEqual(result.returncode, 65)
        self.assertEqual([name for name, _ in actions(result)],
                         ["build-for-testing", "test-without-building"])
        self.assertEqual((result.stdout + result.stderr).count("assertion failure"), 1)
        self.assertNotIn("All UI tests passed.", result.stdout)

    def test_success_still_reports_success(self):
        result = self.run_script("exit 0")
        self.assertEqual(result.returncode, 0)
        self.assertIn("All UI tests passed.", result.stdout)


class SimulatorChoiceTests(unittest.TestCase):
    """With no DESTINATION, test.sh picks the simulator itself. The range it
    picks from comes from the project and the Xcode in use, never from a
    version written into the script (docs/DECISIONS.md, "Build with Apple's
    current Xcode")."""

    def choose(self, devices, target="26.0", sdk="27.1"):
        result = run_script("exit 0", mode="unit", destination=None,
                            target=target, sdk=sdk, devices=devices)
        return result

    # Dropping the upper bound picks the iOS 27.2 simulator, which an Xcode
    # with the 27.1 SDK cannot run, and fails this test.
    def test_newest_simulator_the_selected_xcode_can_run(self):
        result = self.choose({
            runtime("26.5"): [device("iPad Pro 13-inch (M5)", "OLDER")],
            runtime("27.1"): [device("iPad Pro 13-inch (M5)", "NEWEST-USABLE")],
            runtime("27.2"): [device("iPad Pro 13-inch (M5)", "TOO-NEW")],
        }, sdk="27.1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Testing Brickson on: id=NEWEST-USABLE", result.stdout)

    # A floor written into the script (it used to say 26) refuses this
    # simulator although the project runs on it, and fails this test.
    def test_the_floor_is_the_projects_deployment_target(self):
        result = self.choose({
            runtime("18.6"): [device("iPad Pro 13-inch (M4)", "EIGHTEEN")],
        }, target="18.0", sdk="27.1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Testing Brickson on: id=EIGHTEEN", result.stdout)

    # Choosing a simulator older than the deployment target, or naming a
    # floor other than the project's, fails this test.
    def test_no_simulator_in_range_names_the_range(self):
        result = self.choose({
            runtime("26.5"): [device("iPad Pro 13-inch (M5)", "TOO-OLD")],
        }, target="27.0", sdk="27.1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("iOS 27.0 to 27.1", result.stderr)
        self.assertNotIn("Testing Brickson on:", result.stdout)
        self.assertEqual(result.invocations, 0)

    # Carrying on without a deployment target (a command substitution does
    # not stop at errors under set -e) picks a simulator and fails this test.
    def test_unreadable_deployment_target_stops_the_run(self):
        result = self.choose({
            runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PRO")],
        }, target="")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not read IPHONEOS_DEPLOYMENT_TARGET", result.stderr)
        self.assertNotIn("Testing Brickson on:", result.stdout)
        self.assertEqual(result.invocations, 0)

    # Letting an iPhone stand in for the default iPad fails this test.
    def test_never_chooses_an_iphone(self):
        result = self.choose({
            runtime("27.1"): [device("iPhone 17 Pro", "PHONE")],
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Testing Brickson on:", result.stdout)

    # Ranking any iPad above the 13-inch iPad Pro fails this test.
    def test_prefers_the_13_inch_ipad_pro(self):
        result = self.choose({
            runtime("27.1"): [device("iPad Air 11-inch (M3)", "AIR"),
                              device("iPad Pro 13-inch (M5)", "PRO"),
                              device("iPad mini (A17 Pro)", "MINI"),
                              device("iPhone 17", "PHONE")],
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Testing Brickson on: id=PRO", result.stdout)


IPAD_AND_IPHONE = {
    runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD"),
                      device("iPhone 17", "PHONE")],
}

# The owner's Mac with Xcode 27.2 (2026-10-30): two iOS 27.2 runtimes, one
# for iPhone Duo alone, whose key names the device after the version.
XCODE_27_2_RUNTIMES = {
    runtime("27.0"): [device("iPad Pro 13-inch (M5)", "OLDER-PAD")],
    runtime("27.2"): [device("iPad Pro 13-inch (M5)", "PAD"),
                      device("iPhone 17", "PHONE")],
    runtime("27.2") + "-iPhone19-4": [device("iPhone Duo", "DUO")],
}


class FamilyTests(unittest.TestCase):
    """Which simulators each mode runs on. UI tests run on an iPad and an
    iPhone, both first-class (AGENTS.md, "Build and test")."""

    # Choosing by name skips a renamed simulator (a Mac's own iPad Pro may
    # be called anything) and fails this test.
    def test_a_renamed_simulator_is_chosen_by_its_type(self):
        result = run_script("exit 0", mode="unit", destination=None, devices={
            runtime("27.1"): [device("iPad Air 11-inch (M3)", "AIR"),
                              device("Website checks", "RENAMED", kind="iPad-Pro-13-inch-M5-12GB")],
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Testing Brickson on: id=RENAMED", result.stdout)
        self.assertIn("Simulator: Website checks (iPad-Pro-13-inch-M5-12GB), iOS 27.1", result.stderr)

    # Dropping the iPhone from the default UI run, or stopping after the
    # iPad, fails this test.
    def test_ui_tests_run_on_an_ipad_then_an_iphone(self):
        result = run_script("exit 0", destination=None, devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions(result), [
            ("build-for-testing", "id=PAD"), ("test-without-building", "id=PAD"),
            ("build-for-testing", "id=PHONE"), ("test-without-building", "id=PHONE")])
        self.assertIn("All UI tests passed.", result.stdout)

    # Stopping at the first failure hides what is wrong on the iPhone;
    # reporting success after one fails this test too.
    def test_a_failure_on_the_ipad_still_tests_the_iphone(self):
        result = run_script(
            'if [ "$action" = test-without-building ] && [[ "$*" == *id=PAD* ]]; then exit 65; fi',
            destination=None, devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 65)
        self.assertIn(("test-without-building", "id=PHONE"), actions(result))
        self.assertIn("The ui run failed on the ipad simulator (status 65).", result.stderr)
        self.assertNotIn("All UI tests passed.", result.stdout)

    # Unit tests run once, on the iPad; running them on every family fails
    # this test.
    def test_unit_tests_run_on_the_ipad_only(self):
        result = run_script("exit 0", mode="unit", destination=None, devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([destination for _, destination in actions(result)], ["id=PAD", "id=PAD"])

    # Ranking a Pro, Max, e or older iPhone above the newest standard one
    # fails this test.
    def test_the_iphone_family_is_the_newest_standard_iphone(self):
        result = run_script("exit 0", mode="unit", destination=None, family="iphone", devices={
            runtime("27.1"): [device("iPhone 16", "SIXTEEN"),
                              device("iPhone 17 Pro Max", "PRO-MAX"),
                              device("iPhone 17e", "E"),
                              device("iPhone 17", "SEVENTEEN"),
                              device("iPad Pro 13-inch (M5)", "PAD")],
        })
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Testing Brickson on: id=SEVENTEEN", result.stdout)

    # With Xcode 27.2's two iOS 27.2 runtimes, the default UI run stays on
    # the newest iPad Pro and the standard iPhone. Taking iPhone Duo, the
    # one device on its own runtime, as the iPhone fails this test.
    def test_the_duo_runtime_does_not_change_the_default_simulators(self):
        result = run_script("exit 0", destination=None, sdk="27.2",
                            devices=XCODE_27_2_RUNTIMES)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([destination for _, destination in actions(result)],
                         ["id=PAD", "id=PAD", "id=PHONE", "id=PHONE"])

    # Treating an unknown family as the default fails this test.
    def test_an_unknown_family_is_refused(self):
        result = run_script("exit 0", mode="unit", destination=None, family="android",
                            devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 2)
        self.assertIn("SIMULATOR_FAMILY must be ipad or iphone", result.stderr)
        self.assertEqual(result.invocations, 0)


class DestinationTests(unittest.TestCase):
    """With DESTINATION set, the script waits for, prepares and tests that
    one simulator, by id, so the wait and the build use the same device."""

    # Waiting on one simulator while xcodebuild picks another by name, or
    # skipping the keyboard and warm-up for a named simulator, fails this.
    def test_a_named_simulator_is_prepared_and_tested_by_its_id(self):
        result = run_script("exit 0", destination="platform=iOS Simulator,name=iPhone 17",
                            devices={runtime("26.5"): [device("iPhone 17", "OLDER")],
                                     runtime("27.1"): [device("iPhone 17", "PHONE")]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions(result), [("build-for-testing", "id=PHONE"),
                                           ("test-without-building", "id=PHONE")])
        self.assertEqual(result.simctl[:2], ["simctl boot PHONE", "simctl bootstatus PHONE -b"])
        self.assertIn("simctl spawn PHONE defaults write com.apple.keyboard.preferences "
                      "AutomaticMinimizationEnabled -bool false", result.simctl)
        self.assertIn("simctl spawn PHONE defaults write com.apple.keyboard.preferences "
                      "DidShowContinuousPathIntroduction -bool true", result.simctl)

    # Choosing the newest runtime by name without the SDK's bound picks a
    # simulator the Xcode in use cannot run, and fails this test.
    def test_a_name_without_os_gets_the_newest_runtime_the_xcode_can_run(self):
        result = run_script("exit 0", destination="platform=iOS Simulator,name=iPhone 17",
                            sdk="27.1",
                            devices={runtime("27.1"): [device("iPhone 17", "USABLE")],
                                     runtime("27.2"): [device("iPhone 17", "TOO-NEW")]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions(result)[-1], ("test-without-building", "id=USABLE"))

    # From Xcode 27.2, iPhone Duo has a runtime of its own whose key names
    # the device after the version (seen on the owner's Mac, 2026-10-30).
    # Reading only plain version keys refuses the documented way to run
    # the UI tests on a Duo simulator, and fails this test.
    def test_a_duo_simulator_on_its_own_runtime_is_tested_by_its_id(self):
        result = run_script("exit 0", destination="platform=iOS Simulator,id=DUO",
                            sdk="27.2", devices=XCODE_27_2_RUNTIMES)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions(result)[-1], ("test-without-building", "id=DUO"))
        self.assertIn("iOS 27.2", result.stderr)

    # Testing on a named simulator older than the deployment target, which
    # the app cannot install on, fails this test.
    def test_a_simulator_outside_the_range_is_refused_before_building(self):
        for destination in ("platform=iOS Simulator,name=iPhone 16",
                            "platform=iOS Simulator,id=OLD-PHONE"):
            with self.subTest(destination=destination):
                result = run_script("exit 0", destination=destination, target="26.0",
                                    devices={runtime("18.6"): [device("iPhone 16", "OLD-PHONE")]})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("has iOS 18.6; the tests need iOS 26.0 to 27.1", result.stderr)
                self.assertEqual(result.invocations, 0)

    # A typo in DESTINATION reaching xcodebuild, which then waits and fails
    # far later, fails this test.
    def test_a_missing_simulator_stops_before_building(self):
        result = run_script("exit 0", destination="platform=iOS Simulator,name=iPhone 99",
                            devices=IPAD_AND_IPHONE)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No available iOS simulator is named "iPhone 99"', result.stderr)
        self.assertEqual(result.invocations, 0)

    # Trying to boot a real device as a simulator fails this test.
    def test_a_real_device_is_left_to_xcodebuild(self):
        result = run_script("exit 0", destination="platform=iOS,id=REAL-DEVICE",
                            devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.simctl, [])
        self.assertEqual(actions(result)[-1], ("test-without-building", "platform=iOS,id=REAL-DEVICE"))


class PreparationTests(unittest.TestCase):
    """Before UI tests: the full software keyboard, and one warm-up launch
    of the app on test-only storage."""

    def ui_run(self, build_body="exit 0", **options):
        return run_script(build_body, destination=None,
                          devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]},
                          family="ipad", **options)

    # Dropping either keyboard setting or the warm-up, warming up on the
    # person's own storage, or warming up after the tests, fails this test.
    def test_ui_tests_get_the_full_keyboard_and_a_warm_simulator(self):
        result = self.ui_run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.simctl, [
            "simctl boot PAD",
            "simctl bootstatus PAD -b",
            "load start PAD pausing simulator-load-ipad.txt",
            "simctl spawn PAD defaults write com.apple.keyboard.preferences "
            "AutomaticMinimizationEnabled -bool false",
            "simctl spawn PAD defaults write com.apple.keyboard.preferences "
            "DidShowContinuousPathIntroduction -bool true",
            "simctl install PAD " + result.results_dir.replace(
                "TestResults", "DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app"),
            "simctl launch PAD fixture.brickson --fresh-test-storage",
            "sleep 15",
            "simctl terminate PAD fixture.brickson",
            "load stop 4242 simulator-load-ipad.txt",
            "simctl shutdown PAD",
        ])
        self.assertIn("Warm-up: launched Brickson once before the tests", result.stdout)
        warmed = result.stdout.index("Warm-up:")
        self.assertLess(result.stdout.index("Building Brickson-UI for testing"), warmed)
        self.assertLess(warmed, result.stdout.index("Testing Brickson-UI on: id=PAD"))

    # Unit tests changing the keyboard or launching the app fails this.
    def test_unit_tests_only_wait_for_the_simulator(self):
        result = run_script("exit 0", mode="unit", destination=None, devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call for call in result.simctl if call.startswith("simctl")],
                         ["simctl boot PAD", "simctl bootstatus PAD -b", "simctl shutdown PAD"])

    # A failed warm-up that stops the run, or one that passes silently,
    # fails this test.
    def test_a_failed_warm_up_is_reported_and_the_tests_still_run(self):
        os.environ["FIXTURE_LAUNCH_STATUS"] = "1"
        try:
            result = self.ui_run()
        finally:
            del os.environ["FIXTURE_LAUNCH_STATUS"]
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("the warm-up launch failed", result.stderr)
        self.assertIn(("test-without-building", "id=PAD"), actions(result))

    # Testing after a failed build fails this test.
    def test_a_failed_build_is_not_tested(self):
        result = self.ui_run('if [ "$action" = build-for-testing ]; then exit 65; fi')
        self.assertEqual(result.returncode, 65)
        self.assertEqual([name for name, _ in actions(result)], ["build-for-testing"])
        self.assertNotIn("simctl launch PAD fixture.brickson --fresh-test-storage", result.simctl)


class SimulatorLifecycleTests(unittest.TestCase):
    """Only devices booted by this invocation belong to its cleanup."""

    def phone_run(self, build_body="exit 0", state="Shutdown", **options):
        return run_script(build_body, destination="platform=iOS Simulator,id=PHONE",
                          devices={runtime("27.1"): [device("iPhone 17", "PHONE", state=state)]},
                          **options)

    # Omitting shutdown or waiting until both families finish fails this.
    def test_each_owned_device_stops_before_the_next_family_boots(self):
        result = run_script("exit 0", destination=None, devices=IPAD_AND_IPHONE)
        self.assertEqual(result.returncode, 0, result.stderr)
        lifecycle = [call for call in result.simctl if call.startswith(
            ("simctl boot ", "simctl shutdown "))]
        self.assertEqual(lifecycle, ["simctl boot PAD", "simctl shutdown PAD",
                                     "simctl boot PHONE", "simctl shutdown PHONE"])

    # Early returns after boot must still release only the owned device.
    def test_owned_device_stops_after_preparation_build_test_and_summary_failures(self):
        cases = [
            ("exit 0", {"bootstatus_status": 70}, 1),
            ('if [ "$action" = build-for-testing ]; then exit 65; fi', {}, 65),
            ('if [ "$action" = test-without-building ]; then exit 66; fi', {}, 66),
            ("exit 0", {"test_summary": None}, 1),
        ]
        for body, options, status in cases:
            with self.subTest(body=body, options=options):
                result = self.phone_run(body, **options)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(result.simctl.count("simctl shutdown PHONE"), 1)
                self.assertEqual(result.simctl[-1], "simctl shutdown PHONE")

    # A device already starting/running may belong to another session.
    def test_preexisting_device_is_waited_for_but_never_booted_or_stopped(self):
        for state in ("Booted", "Booting"):
            with self.subTest(state=state):
                result = self.phone_run(state=state)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("simctl bootstatus PHONE -b", result.simctl)
                self.assertNotIn("simctl boot PHONE", result.simctl)
                self.assertNotIn("simctl shutdown PHONE", result.simctl)

    # A boot that fails never gives this invocation ownership of the device.
    def test_failed_boot_does_not_claim_or_shutdown_the_device(self):
        result = self.phone_run(boot_status=70)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("simctl shutdown PHONE", result.simctl)
        self.assertEqual(result.invocations, 0)

    # Ignoring cleanup errors can start two simulators and cause UI timeouts.
    def test_failed_shutdown_fails_the_run_and_does_not_start_another_family(self):
        for body, expected in (("exit 0", 1),
                               ('if [ "$action" = test-without-building ]; then exit 65; fi', 65)):
            with self.subTest(body=body):
                result = run_script(body, destination=None, devices=IPAD_AND_IPHONE,
                                    shutdown_status=70)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(result.simctl.count("simctl shutdown PAD"), 1)
                self.assertNotIn("simctl boot PHONE", result.simctl)
                self.assertNotIn(("build-for-testing", "id=PHONE"), actions(result))
                self.assertIn("Could not shut down simulator PAD", result.stderr)
                self.assertNotIn("All UI tests passed.", result.stdout)


class WatcherTests(unittest.TestCase):
    """test.sh watches each simulator it tests on with
    scripts/simulator-load.py, pausing the lock-screen wallpaper
    extensions only on a simulator it started itself, and stops the
    watcher before the simulator in every way a run can end
    (docs/log/2026-11-03-ui-test-stall.md)."""

    def phone_run(self, build_body="exit 0", state="Shutdown", mode="ui", **options):
        return run_script(build_body, mode=mode, destination="platform=iOS Simulator,id=PHONE",
                          devices={runtime("27.1"): [device("iPhone 17", "PHONE", state=state)]},
                          **options)

    def load_calls(self, result):
        return [call for call in result.simctl if call.startswith(("load ", "simctl boot ",
                                                                   "simctl shutdown "))]

    # Pausing processes of a simulator someone else started, or not
    # pausing them on one this run started, in either mode, fails this test.
    def test_wallpaper_extensions_are_paused_only_on_a_simulator_this_run_started(self):
        for mode in ("ui", "unit"):
            for state, expected in (("Shutdown", "pausing"), ("Booted", "watching")):
                with self.subTest(mode=mode, state=state):
                    result = self.phone_run(state=state, mode=mode)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f"load start PHONE {expected} simulator-load-destination.txt",
                                  result.simctl)
                    self.assertIn("load stop 4242 simulator-load-destination.txt", result.simctl)
                    self.assertIn("Processor time the simulator's processes used while watched",
                                  result.stdout)

    # A watcher left running after its simulator stops, started before the
    # simulator has finished starting, or still started after a failed
    # start, fails this test.
    def test_the_watcher_stops_before_the_simulator_however_the_run_ends(self):
        cases = [
            ('if [ "$action" = build-for-testing ]; then exit 65; fi', {}, 65),
            ('if [ "$action" = test-without-building ]; then exit 66; fi', {}, 66),
            ("exit 0", {"test_summary": None}, 1),
            # Interrupted, as by Control-C or a cancelled CI job: the test
            # run's pid, given to the watcher, is the script itself.
            ('if [ "$action" = test-without-building ]; then kill -TERM "$(cat "$RUNNER_LOAD_PARENT")"; fi',
             {}, 143),
        ]
        for body, options, status in cases:
            with self.subTest(body=body, options=options):
                result = self.phone_run(body, **options)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(self.load_calls(result), [
                    "simctl boot PHONE", "load start PHONE pausing simulator-load-destination.txt",
                    "load stop 4242 simulator-load-destination.txt", "simctl shutdown PHONE"])
                self.assertLess(result.simctl.index("simctl bootstatus PHONE -b"),
                                result.simctl.index("load start PHONE pausing simulator-load-destination.txt"))
        result = self.phone_run(bootstatus_status=70)
        self.assertEqual(self.load_calls(result), ["simctl boot PHONE", "simctl shutdown PHONE"])

    # A watcher that cannot start stopping the tests, or passing silently,
    # fails this test.
    def test_a_watcher_that_does_not_start_is_reported_and_the_tests_still_run(self):
        os.environ["FIXTURE_LOAD_START_STATUS"] = "1"
        try:
            result = self.phone_run()
        finally:
            del os.environ["FIXTURE_LOAD_START_STATUS"]
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("the simulator watcher did not start", result.stderr)
        self.assertIn(("test-without-building", "id=PHONE"), actions(result))
        self.assertFalse(any(call.startswith("load stop") for call in result.simctl))


class EvidenceTests(unittest.TestCase):
    """What a run leaves behind: the tools that made it, a result bundle
    per simulator, and how many tests ran."""

    def unit_run(self, **options):
        return run_script("exit 0", mode="unit", destination=None,
                          devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]},
                          **options)

    # Removing the version lines fails this test.
    def test_the_tool_versions_are_printed(self):
        result = self.unit_run()
        self.assertIn("Xcode: Xcode 99.1 Build version 99A1", result.stdout)
        self.assertIn("XcodeGen: Version: 9.9.9", result.stdout)

    # Arguments after the mode lost, or placed after the action (where
    # xcodebuild reads them as another action), fail this test.
    def test_extra_arguments_reach_the_build_and_the_test_run(self):
        only = "-only-testing:BricksonTests/PaletteTests/theContrastFormulaMatchesWCAG()"
        result = self.unit_run(arguments=(only,))
        self.assertEqual(result.returncode, 0, result.stderr)
        for call in result.calls:
            words = arguments_of(call)
            self.assertIn(only, words)
            self.assertLess(words.index(only), len(words) - 1)

    # Keeping an earlier run's bundle (xcodebuild refuses to write over it)
    # or naming bundles so the iPad and iPhone overwrite each other fails
    # this test.
    def test_each_run_writes_a_fresh_result_bundle_per_simulator(self):
        result = self.unit_run()
        self.assertFalse(result.stale_bundle_kept)
        test_run = arguments_of(result.calls[-1])
        bundle = test_run[test_run.index("-resultBundlePath") + 1]
        self.assertTrue(bundle.endswith("TestResults/unit-ipad.xcresult"), bundle)
        self.assertNotIn("-resultBundlePath", arguments_of(result.calls[0]))

    # Not reporting the count fails this test.
    def test_the_number_of_tests_is_printed(self):
        result = self.unit_run(test_summary=summary(3))
        self.assertIn("3 tests ran on iPad Pro 13-inch (M5) (iOS Simulator 27.1): "
                      "3 passed, 0 failed, 0 skipped, 0 expected failures.", result.stdout)

    # A filter that matches nothing reports success from xcodebuild; letting
    # that through fails this test.
    def test_a_run_in_which_no_test_ran_fails(self):
        result = self.unit_run(test_summary=summary(0))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No tests ran.", result.stderr)
        self.assertNotIn("All unit tests passed.", result.stdout)

    # Returning a test failure before counting hides how far the run got,
    # and fails this test.
    def test_a_failed_run_still_reports_its_count(self):
        result = run_script('if [ "$action" = test-without-building ]; then exit 65; fi',
                            mode="unit", destination=None,
                            devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]},
                            test_summary=summary(3, failed=1))
        self.assertEqual(result.returncode, 65)
        self.assertIn("3 tests ran on iPad Pro 13-inch (M5)", result.stdout)
        self.assertIn("2 passed, 1 failed", result.stdout)

    # A green run whose summary cannot be read shows no evidence that any
    # test ran; passing it fails this test.
    def test_an_unreadable_summary_fails_the_run(self):
        result = self.unit_run(test_summary=None)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not read the test summary", result.stderr)
        self.assertNotIn("All unit tests passed.", result.stdout)

    # Likewise a summary without a count; passing it fails this test.
    def test_a_summary_without_a_count_fails_the_run(self):
        result = self.unit_run(test_summary=json.dumps({"passedTests": 3}))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("the test summary has no test count", result.stderr)

    # Removing the earlier bundle only just before testing leaves it in
    # place when the build fails, where it reads as this run's result, and
    # fails this test.
    def test_a_failed_build_leaves_no_earlier_result_bundle(self):
        result = run_script('if [ "$action" = build-for-testing ]; then exit 65; fi',
                            mode="unit", destination=None,
                            devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]})
        self.assertEqual(result.returncode, 65)
        self.assertFalse(result.stale_bundle_kept)
        self.assertFalse(result.stale_record_kept)


class DeviceBuildTests(unittest.TestCase):
    """`scripts/test.sh device` builds for a real device: signed when
    project.yml names a team, otherwise unsigned, and says so."""

    # Signing without a team (the build fails for everyone without the
    # owner's account) or saying nothing about it fails this test.
    def test_without_a_team_the_build_is_unsigned_and_says_so(self):
        result = run_script("exit 0", mode="device", destination=None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("No DEVELOPMENT_TEAM", result.stdout)
        self.assertEqual(len(result.calls), 1)
        words = arguments_of(result.calls[0])
        self.assertEqual(words[-1], "build")
        self.assertIn("CODE_SIGNING_ALLOWED=NO", words)
        self.assertEqual(words[words.index("-destination") + 1], "generic/platform=iOS")

    # Turning signing off when a team is set fails this test.
    def test_with_a_team_the_build_is_signed(self):
        result = run_script("exit 0", mode="device", destination=None, team="TEAM123456")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", arguments_of(result.calls[0]))
        self.assertNotIn("No DEVELOPMENT_TEAM", result.stdout)

    # Treating an unknown mode as unit tests fails this test.
    def test_an_unknown_mode_is_refused(self):
        result = run_script("exit 0", mode="uii", destination=None)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Unknown mode "uii"', result.stderr)
        self.assertEqual(result.invocations, 0)


class StringCatalogTests(unittest.TestCase):
    """After a unit-test build, the String Catalog is brought up to date from
    the strings the compiler found: written on a Mac, checked on CI."""

    def unit_run(self, **options):
        return run_script("exit 0", mode="unit", destination=None,
                          devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]},
                          **options)

    # Failing a catalog that matches the code fails this test.
    def test_a_catalog_that_matches_the_code_passes(self):
        result = self.unit_run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("String Catalog: up to date with the code.", result.stdout)
        self.assertEqual(result.catalog, CATALOG)

    # Passing a stale catalog on CI, hiding what differs, or skipping the
    # tests because of it fails this test.
    def test_on_ci_a_stale_catalog_fails_shows_the_difference_and_still_tests(self):
        result = self.unit_run(synced_catalog=SYNCED_CATALOG, on_ci=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match the code", result.stderr)
        self.assertIn('+    "Yes" : {', result.stderr)
        self.assertIn(("test-without-building", "id=PAD"), actions(result))
        self.assertEqual(result.catalog, CATALOG)
        self.assertNotIn("All unit tests passed.", result.stdout)

    # Leaving the catalog stale on a Mac, or failing the run there, fails
    # this test.
    def test_on_a_mac_a_stale_catalog_is_updated_in_place(self):
        result = self.unit_run(synced_catalog=SYNCED_CATALOG, on_ci=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.catalog, SYNCED_CATALOG)
        self.assertIn("Commit it with your change.", result.stdout)

    # A build that emitted no strings (SWIFT_EMIT_LOC_STRINGS turned off,
    # say) passing the check unchecked fails this test.
    def test_no_strings_from_the_build_fails(self):
        result = self.unit_run(strings=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("left no strings for the String Catalog", result.stderr)

    # Ignoring a failed sync fails this test.
    def test_a_failed_sync_fails(self):
        result = self.unit_run(sync_status=64)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not bring the String Catalog up to date", result.stderr)

    # Checking the catalog twice per change (it is the same app build) fails
    # this test.
    def test_ui_runs_leave_the_catalog_alone(self):
        result = run_script("exit 0", destination=None, family="ipad",
                            synced_catalog=SYNCED_CATALOG,
                            devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("xcstringstool sync", result.simctl)


class CoverageTests(unittest.TestCase):
    """Unit runs print how much of the app's code the tests ran."""

    def unit_run(self, **options):
        return run_script("exit 0", mode="unit", destination=None,
                          devices={runtime("27.1"): [device("iPad Pro 13-inch (M5)", "PAD")]},
                          **options)

    # Dropping the coverage line fails this test.
    def test_the_apps_coverage_is_printed(self):
        result = self.unit_run()
        self.assertIn("Code coverage: the unit tests ran 45.7% of the app's lines (457 of 1000).",
                      result.stdout)

    # Failing a green run because coverage could not be read, or saying
    # nothing about it, fails this test.
    def test_unreadable_coverage_only_warns(self):
        result = self.unit_run(coverage=None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("could not read code coverage", result.stderr)


# A stand-in for /bin/ps: it prints the files beside it, `args` for the
# launchd_sim lookup and `table` for the process list.
FAKE_PS = """#!/bin/bash
[ -e "$(dirname "$0")/hang" ] && exec sleep 30
case "$*" in
    "-axww -o pid=,args=") cat "$(dirname "$0")/args" ;;
    "-axww -o pid=,ppid=,stat=,time=,comm=") cat "$(dirname "$0")/table" ;;
    *) echo "unexpected: ps $*" >&2; exit 1 ;;
esac
"""

RUNTIME_ROOT = ("/Library/Developer/CoreSimulator/Volumes/iOS_24A/Library/Developer/CoreSimulator/"
                "Profiles/Runtimes/iOS 27.0.simruntime/Contents/Resources/RuntimeRoot")
LAUNCHD_SIM = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Resources/bin/launchd_sim"
DEVICES = "/Users/runner/Library/Developer/CoreSimulator/Devices"

# Two simulators, PAD (launchd_sim 100) and OTHER (200), and the Mac.
LAUNCHD_SIMS = f"""\
    1 /sbin/launchd
  100 {LAUNCHD_SIM} {DEVICES}/PAD/data/var/run/launchd_bootstrap.plist
  200 {LAUNCHD_SIM} {DEVICES}/OTHER/data/var/run/launchd_bootstrap.plist
"""


def process_table(times):
    """The Mac's process list, with each process's processor time."""
    rows = [
        (1, 0, "Ss", "/sbin/launchd"),
        (100, 1, "Ss", LAUNCHD_SIM),
        (110, 100, "S", f"{RUNTIME_ROOT}/System/Library/CoreServices/SpringBoard.app/SpringBoard"),
        (120, 100, "S", f"{RUNTIME_ROOT}/System/Library/CoreServices/PosterBoard.app/PosterBoard"),
        (121, 120, "R", f"{RUNTIME_ROOT}/System/Library/ExtensionKit/Extensions/"
                        "EmojiPosterExtension.appex/EmojiPosterExtension"),
        (122, 100, "S", f"{RUNTIME_ROOT}/System/Library/ExtensionKit/Extensions/"
                        "AegirPoster.appex/AegirPoster"),
        (123, 100, "T", f"{RUNTIME_ROOT}/System/Library/ExtensionKit/Extensions/"
                        "PhotosPosterProvider.appex/PhotosPosterProvider"),
        (200, 1, "Ss", LAUNCHD_SIM),
        (221, 200, "R", f"{RUNTIME_ROOT}/System/Library/ExtensionKit/Extensions/"
                        "EmojiPosterExtension.appex/EmojiPosterExtension"),
        (300, 1, "S", "/Applications/Example.app/Contents/MacOS/GradientPosterExtension"),
    ]
    return "".join(f"{pid:5} {ppid:5} {state:4} {times.get(pid, '0:00.00'):>10} {path}\n"
                   for pid, ppid, state, path in rows)


def simulator_load():
    """scripts/simulator-load.py as a module, without leaving a
    __pycache__ folder in the checkout."""
    spec = importlib.util.spec_from_file_location(
        "simulator_load", SCRIPT.with_name("simulator-load.py"))
    module = importlib.util.module_from_spec(spec)
    writes, sys.dont_write_bytecode = sys.dont_write_bytecode, True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = writes
    return module


class SimulatorLoadTests(unittest.TestCase):
    """scripts/simulator-load.py pauses the lock-screen wallpaper
    extensions of the one simulator it watches and nothing else, records
    the processor time each of its processes used, and never outlives the
    test run (docs/log/2026-11-03-ui-test-stall.md)."""

    def setUp(self):
        self.module = simulator_load()
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.ps = self.folder / "ps"
        self.ps.write_text(FAKE_PS)
        self.ps.chmod(0o755)
        (self.folder / "args").write_text(LAUNCHD_SIMS)
        self.times({})
        self.record = self.folder / "record.txt"

    def times(self, times):
        (self.folder / "table").write_text(process_table(times))

    def watch(self, pause_posters):
        self.kills, self.now = [], 0.0
        out = self.record.open("w")
        self.addCleanup(out.close)
        return self.module.Watch("PAD", out, pause_posters, ps=str(self.ps),
                                 clock=lambda: self.now,
                                 kill=lambda pid, number: self.kills.append((pid, number)))

    # Matching PosterBoard, pausing another simulator's or the Mac's own
    # processes, pausing one already stopped, or pausing one twice fails
    # this test.
    def test_only_this_simulators_wallpaper_extensions_are_paused_once(self):
        watcher = self.watch(pause_posters=True)
        watcher.sample()
        watcher.sample()
        self.assertEqual(self.kills, [(121, signal.SIGSTOP), (122, signal.SIGSTOP)])
        record = self.record.read_text()
        self.assertIn("paused EmojiPosterExtension (121)", record)
        self.assertIn("paused AegirPoster (122)", record)
        watcher.summary()
        self.assertIn("Paused 2 lock-screen wallpaper extension processes.", self.record.read_text())

    # The simulator's launchd_sim is in the first process list but gone
    # from the second (the simulator stopped or restarted between them).
    # Looking it up in the second list anyway raises, the watcher dies
    # without its summary, and that fails this test (Copilot's review).
    def test_a_simulator_gone_between_the_two_lists_is_not_running(self):
        (self.folder / "table").write_text("".join(
            line for line in process_table({}).splitlines(keepends=True)
            if int(line.split()[0]) in (1, 200, 221, 300)))
        watcher = self.watch(pause_posters=True)
        watcher.sample()
        self.assertEqual(self.kills, [])
        self.assertIn("the simulator PAD is not running", self.record.read_text())

    # Leaving the extensions stopped when the watcher stops, resuming any
    # other process, or stopping at a process that is already gone fails
    # this test: a simulator that is not shut down after its run (a failed
    # shutdown) would keep its wallpaper extensions stopped (Copilot's
    # review).
    def test_the_paused_extensions_run_again_when_the_watcher_stops(self):
        watcher = self.watch(pause_posters=True)
        watcher.sample()
        gone = []

        def kill(pid, number):
            self.kills.append((pid, number))
            if pid in gone:
                raise ProcessLookupError(pid)

        watcher.kill = kill
        gone.append(121)
        watcher.resume()
        self.assertEqual(self.kills, [(121, signal.SIGSTOP), (122, signal.SIGSTOP),
                                      (121, signal.SIGCONT), (122, signal.SIGCONT)])
        self.assertIn("Resumed 1 of them; 1 had already ended.", self.record.read_text())

    # A watcher that stops without resuming what it paused, or resumes
    # only after "Stopped." (when `stop` no longer waits), fails this test.
    def test_the_watcher_resumes_what_it_paused_before_it_says_stopped(self):
        for number in (signal.SIGTERM, signal.SIGINT):
            self.addCleanup(signal.signal, number, signal.getsignal(number))
        arguments = argparse.Namespace(udid="PAD", out=str(self.record), pause_posters=True,
                                       ps=str(self.ps), parent=os.getpid())
        kills = []
        self.assertEqual(self.module.watch(arguments, parent_alive=lambda pid: False,
                                           kill=lambda pid, number: kills.append((pid, number))), 0)
        self.assertEqual(kills, [(121, signal.SIGSTOP), (122, signal.SIGSTOP),
                                 (121, signal.SIGCONT), (122, signal.SIGCONT)])
        lines = self.record.read_text().splitlines()
        self.assertEqual(lines[-1], "Stopped.")
        self.assertIn("Resumed 2 of them.", lines)

    # Pausing anything without --pause-posters fails this test.
    def test_without_pausing_nothing_is_paused(self):
        watcher = self.watch(pause_posters=False)
        watcher.sample()
        watcher.sample()
        self.assertEqual(self.kills, [])

    # Reporting each process's total time instead of the time used since
    # the last line, counting the Mac's or another simulator's processes as
    # this simulator's, or misreading ps's longer times fails this test.
    def test_each_line_reports_the_time_used_since_the_last(self):
        watcher = self.watch(pause_posters=False)
        self.times({121: "1:00.00", 110: "61:00.00", 221: "0:30.00", 300: "1-00:00:00"})
        watcher.sample()
        self.now = 5.0
        self.times({121: "1:05.00", 110: "61:00.50", 221: "0:32.50", 300: "1-00:00:02.50"})
        watcher.sample()
        line = self.record.read_text().splitlines()[-1]
        self.assertRegex(line, r" simulator +110% mac +210% load ")
        self.assertTrue(line.endswith("| EmojiPosterExtension 100%, SpringBoard 10%"), line)
        watcher.summary()
        self.assertIn("     5.0 s  EmojiPosterExtension", self.record.read_text())
        self.assertEqual(self.module.cpu_seconds("1-02:03:04.50"), 93784.5)

    def run_script(self, *arguments):
        return subprocess.run([sys.executable, "-I", str(SCRIPT.with_name("simulator-load.py")),
                               *arguments], capture_output=True, text=True, timeout=60)

    def wait_for(self, predicate, seconds=10):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.05)
        return False

    # `start` returning before the watcher is watching, or not seeing that
    # it is, `stop` returning before its summary is written, or a first
    # line that does not say when the watcher began, fails this test.
    # (Without --pause-posters: the stand-in's pids may be real processes
    # here.)
    def test_start_waits_for_the_watcher_and_stop_for_its_summary(self):
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(os.getpid()), "--ps", str(self.ps))
        self.assertEqual(started.returncode, 0, started.stderr)
        self.assertNotIn("has not begun", started.stderr)
        pid = int(started.stdout)
        self.assertRegex(self.record.read_text(), r"\AWatching simulator PAD, from \d\d:\d\d:\d\d\n")
        stopped = self.run_script("stop", "--pid", str(pid), "--out", str(self.record))
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(self.record.read_text().splitlines()[-1], "Stopped.")
        self.assertIn("Processor time the simulator's processes used while watched:", stopped.stdout)

    # A Mac busy starting a simulator can take longer than `start` waits
    # to start Python: on GitHub's machine (run 41656480638) the iPad's
    # watcher had not written its first line after 15 s, `start` killed
    # it, nothing was paused and the iPad stalled again. Killing a watcher
    # that is still starting, or reporting it as not started, fails this
    # test. (wait=0: the watcher cannot have begun when `start` decides.)
    def test_a_watcher_slow_to_start_is_left_to_start(self):
        arguments = argparse.Namespace(udid="PAD", out=str(self.record), pause_posters=False,
                                       ps=str(self.ps), parent=os.getpid())
        printed, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(errors):
            status = self.module.start(arguments, wait=0)
        self.assertEqual(status, 0, errors.getvalue())
        pid = int(printed.getvalue())
        self.addCleanup(self.end, pid)
        self.assertIn("has not begun watching within 0 s; it is left to start", errors.getvalue())
        self.assertTrue(self.wait_for(
            lambda: self.record.read_text().startswith("Watching simulator PAD, from ")),
            self.record.read_text())
        stopped = self.run_script("stop", "--pid", str(pid), "--out", str(self.record))
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(self.record.read_text().splitlines()[-1], "Stopped.")

    # A watcher that ends before it begins (here its arguments are refused)
    # reported as started, as a watcher left to start would be, fails this
    # test.
    def test_a_watcher_that_ends_before_it_begins_is_reported_as_not_started(self):
        arguments = argparse.Namespace(udid="PAD", out=str(self.record), pause_posters=False,
                                       ps=str(self.ps), parent="not-a-pid")
        printed, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(errors):
            status = self.module.start(arguments, wait=10)
        self.assertEqual(status, 1, errors.getvalue())
        self.assertEqual(printed.getvalue(), "")
        self.assertIn("stopped as it started (status 2)", errors.getvalue())

    # `stop` reporting a watcher that never began (ended by `stop` while
    # still starting) as one that did not finish its record, which hides
    # that nothing was paused, fails this test.
    def test_stop_says_when_the_watcher_never_began(self):
        starting = subprocess.Popen(["/bin/sleep", "30"])
        self.addCleanup(starting.wait)
        self.addCleanup(self.end, starting.pid)
        self.record.write_text("")
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors):
            status = self.module.stop(argparse.Namespace(pid=starting.pid, out=str(self.record)),
                                      wait=0.5)
        self.assertEqual(status, 1)
        self.assertIn("never began watching, so nothing was paused", errors.getvalue())

    # The watcher's stderr is its record. Opened without appending, an
    # error it writes after its lines (here a launchd_sim line it cannot
    # read) lands at the start and overwrites them; that fails this test.
    def test_the_watchers_own_errors_follow_its_lines(self):
        (self.folder / "args").write_text(
            f"x {LAUNCHD_SIM} {DEVICES}/PAD/data/var/run/launchd_bootstrap.plist\n")
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(os.getpid()), "--ps", str(self.ps))
        self.assertEqual(started.returncode, 0, started.stderr)
        pid = int(started.stdout)
        self.addCleanup(self.end, pid)
        self.assertTrue(self.wait_for(lambda: "ValueError" in self.record.read_text()),
                        self.record.read_text())
        lines = self.record.read_text().splitlines()
        self.assertTrue(lines[0].startswith("Watching simulator PAD, from "), lines)
        self.assertIn("Traceback (most recent call last):", lines[1:])

    def end(self, pid):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    # A watcher that keeps running after the test run is gone (killed, say)
    # would go on pausing processes of simulators other runs start; that
    # fails this test.
    def test_the_watcher_stops_when_the_test_run_is_gone(self):
        gone = subprocess.Popen(["/bin/sh", "-c", "exit 0"])
        gone.wait()
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(gone.pid), "--ps", str(self.ps))
        self.assertEqual(started.returncode, 0, started.stderr)
        self.assertTrue(self.wait_for(
            lambda: self.record.read_text().splitlines()[-1:] == ["Stopped."]),
            self.record.read_text())
        self.assertIn(f"The test run ({gone.pid}) is gone.", self.record.read_text())

    # A process list with no time limit, or a time-out the watcher does not
    # catch, leaves a hung ps holding the watcher: it pauses nothing more
    # and `stop` finds no summary. Either fails this test.
    def test_a_process_list_that_hangs_is_given_up_on_and_the_watcher_carries_on(self):
        (self.folder / "hang").touch()
        self.module.PS_TIMEOUT = 0.5
        for number in (signal.SIGTERM, signal.SIGINT):
            self.addCleanup(signal.signal, number, signal.getsignal(number))
        arguments = argparse.Namespace(udid="PAD", out=str(self.record), pause_posters=True,
                                       ps=str(self.ps), parent=os.getpid())
        began = time.monotonic()
        self.assertEqual(self.module.watch(arguments, parent_alive=lambda pid: False), 0)
        self.assertLess(time.monotonic() - began, 10)
        lines = self.record.read_text().splitlines()
        self.assertTrue(any(re.match(r"\d\d:\d\d:\d\d could not read the process list:", line)
                            and "timed out" in line for line in lines), lines)
        self.assertEqual(lines[-1], "Stopped.")
        # A reading lists processes twice; both time-outs must fit in WAIT.
        self.assertLess(2 * simulator_load().PS_TIMEOUT, simulator_load().WAIT)


def workflow_jobs(text):
    """Each job's id and its lines, without comments. Reads the layout
    tests.yml uses: job ids two spaces in, under a top-level `jobs:`."""
    jobs, current, inside = {}, None, False
    for line in text.splitlines():
        if line.lstrip().startswith("#") or not line.strip():
            continue
        if not line.startswith(" "):
            inside, current = line.rstrip() == "jobs:", None
            continue
        job = re.match(r"  (\S+):\s*$", line)
        if inside and job:
            current = job.group(1)
            jobs[current] = []
        elif inside and current:
            jobs[current].append(line)
    return jobs


class WorkflowTests(unittest.TestCase):
    """CI runs test.sh only after switching to the newest released Xcode,
    and names no Xcode version (docs/DECISIONS.md, "Build with Apple's
    current Xcode")."""

    # Running test.sh on the machine image's default Xcode, as the workflow
    # did before 2026-10-21, fails this test.
    def test_every_job_that_runs_the_tests_first_switches_xcode(self):
        testing = {name: "\n".join(lines)
                   for name, lines in workflow_jobs(WORKFLOW.read_text()).items()
                   if any("scripts/test.sh" in line for line in lines)}
        self.assertTrue(testing, "No job in tests.yml runs scripts/test.sh.")
        for name, body in testing.items():
            with self.subTest(job=name):
                choose = body.find("scripts/select-xcode.py choose")
                switch = body.find("xcode-select --switch", max(choose, 0))
                self.assertTrue(
                    0 <= choose < switch < body.index("scripts/test.sh"),
                    f"Job {name} in .github/workflows/tests.yml runs scripts/test.sh "
                    "without first choosing the newest released Xcode "
                    "(python3 scripts/select-xcode.py choose, then sudo "
                    "xcode-select --switch).")

    # Renaming a job the `main` ruleset requires ("Unit tests", "UI tests"),
    # or making "UI tests" a check that can pass while a family's UI tests
    # failed, were cancelled or never ran, fails this test. "UI tests" is
    # either one job that tests both families, or a job that waits for the
    # family jobs, runs however they ended, and fails unless they passed
    # (docs/DECISIONS.md, "Tests").
    # Renaming a required job, a "UI tests" job without `if: always()`, a
    # family missing, the families run as a matrix (whose one summary
    # result was reported as success with a family that never got a
    # machine), the gate not reading each family's own result or not
    # failing, or the two families' jobs differing in anything but the
    # family fails this test.
    def test_the_required_checks_stay_and_ui_tests_needs_both_families(self):
        jobs = {job: "\n".join(lines) for job, lines in workflow_jobs(WORKFLOW.read_text()).items()}

        def name(body):
            found = re.search(r"^    name: *(.+?) *$", body, re.M)
            return found.group(1) if found else None

        names = [name(body) for body in jobs.values()]
        self.assertEqual(names.count("Unit tests"), 1, names)
        self.assertEqual(names.count("UI tests"), 1, names)
        result = next(body for body in jobs.values() if name(body) == "UI tests")
        if "scripts/test.sh ui" in result:
            self.assertNotIn("SIMULATOR_FAMILY", result)
            return
        needs = re.search(r"^    needs: *\[?([^\]\n]+)\]? *$", result, re.M)
        self.assertIsNotNone(needs, "The UI tests job neither runs the tests nor waits for them.")
        needed = [job.strip() for job in needs.group(1).split(",")]
        self.assertRegex(result, r"(?m)^    if: *(\$\{\{ *)?always\(\)( *\}\})? *$",
                         "Without `if: always()`, a failed family skips the UI tests job, "
                         "and a skipped required check reads as passed.")
        families, steps, variables = {}, set(), []
        for job in needed:
            with self.subTest(job=job):
                body = jobs[job]
                self.assertIn("scripts/test.sh ui", body)
                self.assertNotRegex(body, r"(?m)^    strategy:",
                                    "A matrix reports one result for every family together.")
                family = re.search(r"SIMULATOR_FAMILY: *(\w+) *$", body, re.M)
                self.assertIsNotNone(family, body)
                families[family.group(1)] = job
                variable = re.search(r"(?m)^ +(\w+): *\$\{\{ *needs\." + re.escape(job)
                                     + r"\.result *\}\} *$", result)
                self.assertIsNotNone(variable, f"The UI tests job does not read {job}'s result.")
                self.assertRegex(result, r'"\$' + variable.group(1) + r'" *!= *"?success"?')
                variables.append(variable.group(1))
                display = {"ipad": "iPad", "iphone": "iPhone"}.get(family.group(1), family.group(1))
                steps.add(body.replace(display, "FAMILY").replace(family.group(1), "family"))
        self.assertEqual(set(families), {"ipad", "iphone"})
        self.assertEqual(len(steps), 1, "The families' jobs differ in more than the family.")
        # Run the check itself with every pair of results: it passes only
        # when every family passed, so `&&` for `||`, or one family left
        # out, fails here.
        script = re.search(r"(?m)^( +)run: *\|\n((?:\1 +.*(?:\n|$))+)", result)
        self.assertIsNotNone(script, "The UI tests job has no script to check the results.")
        script = textwrap.dedent(script.group(2))
        outcomes = ["success", "failure", "cancelled", "skipped"]
        for chosen in itertools.product(outcomes, repeat=len(variables)):
            with self.subTest(results=chosen):
                environment = dict(os.environ, **dict(zip(variables, chosen)))
                ran = subprocess.run(["bash", "-c", script], env=environment,
                                     capture_output=True, text=True, timeout=30)
                self.assertEqual(ran.returncode == 0, all(c == "success" for c in chosen),
                                 ran.stdout + ran.stderr)

    # Writing an Xcode version or app path into the workflow fails this test.
    def test_the_workflow_names_no_xcode_version(self):
        pinned = [line.strip() for line in WORKFLOW.read_text().splitlines()
                  if not line.lstrip().startswith("#")
                  and re.search(r"Xcode_\d|DEVELOPER_DIR|xcode-version", line)]
        self.assertEqual(pinned, [])


if __name__ == "__main__":
    unittest.main()
