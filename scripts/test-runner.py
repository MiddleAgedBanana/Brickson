#!/usr/bin/env python3
"""Exercise test.sh's error reporting and simulator choice without booting a
simulator, check the simulator watcher it starts (simulator-load.py), and
check that CI runs it with the newest released Xcode."""
import argparse
import contextlib
import ctypes
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
from unittest import mock

SCRIPT = Path(__file__).resolve().with_name("test.sh")
WORKFLOW = SCRIPT.parent.parent / ".github" / "workflows" / "tests.yml"
WORKFLOWS = WORKFLOW.parent
VERIFY_LOCKFILE = WORKFLOWS / "verify-lockfile.yml"

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


# A stand-in for the Mac's process calls (simulator-load.py's
# ProcessFile): a JSON file the watcher reads afresh for each reading.
RUNTIME_ROOT = ("/Library/Developer/CoreSimulator/Volumes/iOS_24A/Library/Developer/CoreSimulator/"
                "Profiles/Runtimes/iOS 27.0.simruntime/Contents/Resources/RuntimeRoot")
LAUNCHD_SIM = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Resources/bin/launchd_sim"
DEVICES = "/Users/runner/Library/Developer/CoreSimulator/Devices"
EXTENSIONS = f"{RUNTIME_ROOT}/System/Library/ExtensionKit/Extensions"


def launchd_sim_arguments(device):
    return [LAUNCHD_SIM, f"{DEVICES}/{device}/data/var/run/launchd_bootstrap.plist"]


def process_table(times, ticks=0, ended=(), without=(), extra=()):
    """Two simulators, PAD (launchd_sim 100) and OTHER (200), and the Mac,
    with each process's processor time in seconds and the processors'
    busy ticks. A process in `ended` ended before its details were read;
    one in `without` is not listed; `extra` adds rows."""
    rows = [
        (1, 0, "S", "/sbin/launchd", None),
        (100, 1, "S", LAUNCHD_SIM, launchd_sim_arguments("PAD")),
        (110, 100, "S", f"{RUNTIME_ROOT}/System/Library/CoreServices/SpringBoard.app/SpringBoard", None),
        (120, 100, "S", f"{RUNTIME_ROOT}/System/Library/CoreServices/PosterBoard.app/PosterBoard", None),
        (121, 120, "R", f"{EXTENSIONS}/EmojiPosterExtension.appex/EmojiPosterExtension", None),
        (122, 100, "S", f"{EXTENSIONS}/AegirPoster.appex/AegirPoster", None),
        (123, 100, "T", f"{EXTENSIONS}/PhotosPosterProvider.appex/PhotosPosterProvider", None),
        (200, 1, "S", LAUNCHD_SIM, launchd_sim_arguments("OTHER")),
        (221, 200, "R", f"{EXTENSIONS}/EmojiPosterExtension.appex/EmojiPosterExtension", None),
        (300, 1, "S", "/Applications/Example.app/Contents/MacOS/GradientPosterExtension", None),
    ]
    rows = [row for row in rows if row[0] not in without] + list(extra)
    return json.dumps({"ticks": ticks, "processes": [
        [pid, ppid, state, None if pid in ended else times.get(pid, 0.0), path, arguments]
        for pid, ppid, state, path, arguments in rows]})


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


def wait_for(predicate, seconds=10):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.05)
    return False


def end(pid):
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


class SimulatorLoadTests(unittest.TestCase):
    """scripts/simulator-load.py pauses the lock-screen wallpaper
    extensions of the one simulator it watches and nothing else, records
    the processor time each of its processes used, and never outlives the
    test run (docs/log/2026-11-03-ui-test-stall.md,
    docs/log/2026-11-04-watcher-without-ps.md)."""

    def setUp(self):
        self.module = simulator_load()
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.processes = self.folder / "processes.json"
        self.times({})
        self.record = self.folder / "record.txt"

    def times(self, times, **options):
        self.processes.write_text(process_table(times, **options))

    def watch(self, pause_posters):
        self.kills, self.now = [], 0.0
        out = self.record.open("w")
        self.addCleanup(out.close)
        self.system = self.module.ProcessFile(str(self.processes))
        return self.module.Watch("PAD", out, pause_posters, self.system,
                                 clock=lambda: self.now,
                                 kill=lambda pid, number: self.kills.append((pid, number)))

    def arguments(self, **options):
        values = dict(udid="PAD", out=str(self.record), pause_posters=True,
                      processes=str(self.processes), parent=os.getpid())
        values.update(options)
        return argparse.Namespace(**values)

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

    # Each process is listed first and read in detail after, so it can end
    # in between. Pausing or counting one whose details are gone, or
    # raising (the watcher would die without its summary, as it did before
    # Copilot's review of pull request #76), fails this test; so does
    # taking a simulator whose launchd_sim's arguments can no longer be
    # read (it is stopping) for a running one.
    def test_a_process_that_ends_while_it_is_read_is_left_out(self):
        watcher = self.watch(pause_posters=True)
        self.times({110: 1.0}, ended=(121,))
        watcher.sample()
        self.now = 5.0
        self.times({110: 2.0}, ended=(121,))
        watcher.sample()
        self.assertEqual(self.kills, [(122, signal.SIGSTOP)])
        self.assertTrue(self.record.read_text().splitlines()[-1].endswith("| SpringBoard 20%"))
        watcher = self.watch(pause_posters=True)
        self.processes.write_text(process_table({}).replace(
            json.dumps(launchd_sim_arguments("PAD")), "null"))
        watcher.sample()
        self.assertEqual(self.kills, [])
        self.assertIn("the simulator PAD is not running", self.record.read_text())

    # Reading launchd_sim's arguments, which reads that process's own
    # memory, on every reading instead of once, or not finding the
    # simulator again once it has started over under a new launchd_sim,
    # fails this test.
    def test_the_simulator_is_found_once_and_again_after_it_starts_over(self):
        watcher = self.watch(pause_posters=True)
        read = []
        arguments = self.system.arguments
        self.system.arguments = lambda pid: read.append(pid) or arguments(pid)
        watcher.sample()
        watcher.sample()
        self.assertEqual(read, [100])
        restarted = [(150, 1, "S", LAUNCHD_SIM, launchd_sim_arguments("PAD")),
                     (151, 150, "R", f"{EXTENSIONS}/AegirPoster.appex/AegirPoster", None)]
        self.times({}, without=(100, 110, 120, 121, 122, 123), extra=restarted)
        watcher.sample()
        self.assertEqual(read, [100, 200, 150])
        self.assertEqual(self.kills, [(121, signal.SIGSTOP), (122, signal.SIGSTOP),
                                      (151, signal.SIGSTOP)])

    # Leaving the extensions stopped when the watcher stops, resuming any
    # other process, stopping at a process that is already gone, or not
    # naming the ones that had ended fails this test: a simulator that is not shut down after its run (a failed
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
        self.assertIn("Resumed 1 of them; 1 had already ended: 121.", self.record.read_text())

    # A watcher that stops without resuming what it paused, or resumes
    # only after "Stopped." (when `stop` no longer waits), fails this test.
    def test_the_watcher_resumes_what_it_paused_before_it_says_stopped(self):
        for number in (signal.SIGTERM, signal.SIGINT):
            self.addCleanup(signal.signal, number, signal.getsignal(number))
        kills = []
        self.assertEqual(self.module.watch(self.arguments(), parent_alive=lambda pid: False,
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
    # this simulator's, counting a new process under an old one's pid as
    # the old one, reading the Mac's busy time from anything but its
    # processors' counters (or tripping when a counter wraps), or a list
    # time that leaves out any part of the reading (listing, the details,
    # the processors' counts), fails this test.
    def test_each_line_reports_the_time_used_since_the_last(self):
        watcher = self.watch(pause_posters=False)

        def taking(call, seconds):
            def slow(*arguments):
                self.now += seconds
                return call(*arguments)
            return slow

        # A reading takes 0.2 s to list, 0.01 s for each of the
        # simulator's six processes and 0.05 s to count: 0.31 s.
        self.system.table = taking(self.system.table, 0.2)
        self.system.details = taking(self.system.details, 0.01)
        self.system.processor_ticks = taking(self.system.processor_ticks, 0.05)
        self.times({121: 60.0, 110: 3660.0, 221: 30.0, 300: 86400.0, 122: 7.0},
                   ticks=2**32 - 250)
        watcher.sample()
        self.now = 5.0
        reused = [(122, 100, "S", f"{EXTENSIONS}/KaleidoscopePoster.appex/KaleidoscopePoster", None)]
        self.times({121: 65.0, 110: 3660.5, 221: 32.5, 300: 86402.5, 122: 1.5},
                   ticks=800, without=(122,), extra=reused)
        watcher.sample()
        line = self.record.read_text().splitlines()[-1]
        # The newcomer under 122 counts 1.5 s over the 5.25 s from the
        # first list, which it was not in, to its own reading: 29%.
        self.assertRegex(line, r" simulator +139% mac +210% load +[\d.]+ list 0\.31 s \| ")
        self.assertTrue(line.endswith("| EmojiPosterExtension 100%, KaleidoscopePoster 29%, "
                                      "SpringBoard 10%"), line)
        watcher.summary()
        self.assertIn("     5.0 s  EmojiPosterExtension", self.record.read_text())

    # A reading reads each process's time at its own moment, and on a
    # starved Mac one reading took 13.67 s (run 41757279440's iPhone).
    # Counting every process over the time between the two lines' ends,
    # as the watcher did until then, put the simulator at 845% of a
    # three-processor Mac in the line after it. Counting a process over
    # anything but the time between its own two readings, or a new one
    # over the time since the last line ended rather than since its list
    # was read, fails this test.
    def test_a_slow_reading_does_not_swell_the_next_line(self):
        watcher = self.watch(pause_posters=False)
        details = self.system.details
        # Processors' worth each one uses, and when it started. The
        # newcomer starts during the first reading, after its list.
        rates, started = {121: 1.0, 124: 0.5}, {121: -100.0, 124: 3.0}
        step = [2.0]

        def reading(pid):
            self.now += step[0]
            found = details(pid)
            if found is None or pid not in rates:
                return found
            return (rates[pid] * (self.now - started[pid]), found[1])

        self.system.details = reading
        # Listed at 0, then its six processes read 2 s apart: 121 at 8,
        # the reading over at 12.
        watcher.sample()
        step[0], self.now = 0.0, 15.0
        newcomer = [(124, 100, "R", f"{EXTENSIONS}/KaleidoscopePoster.appex/KaleidoscopePoster", None)]
        self.times({}, extra=newcomer)
        watcher.sample()
        line = self.record.read_text().splitlines()[-1]
        # 121: 7 s over its own 7 s. 124: 6 s over the 15 s since the list
        # it was not in, the longest it can have run unseen. Over the 3 s
        # since the last line ended they were 233% and 200%.
        self.assertRegex(line, r" simulator +140% ")
        self.assertTrue(line.endswith("| EmojiPosterExtension 100%, KaleidoscopePoster 40%"), line)
        watcher.summary()
        record = self.record.read_text()
        self.assertIn("     7.0 s  EmojiPosterExtension", record)
        self.assertIn("     6.0 s  KaleidoscopePoster", record)

    # A check between lines (a reading made only to find new wallpaper
    # extensions) that misses a new one, writes a line of its own, or
    # moves the time the next line counts from fails this test; so does a
    # "paused" line that does not say how much processor time the
    # extension had used.
    def test_a_check_between_lines_pauses_new_extensions_and_leaves_the_line_alone(self):
        watcher = self.watch(pause_posters=True)
        watcher.sample()
        written = len(self.record.read_text().splitlines())
        self.now = 1.0
        newcomer = [(124, 120, "R", f"{EXTENSIONS}/KaleidoscopePoster.appex/KaleidoscopePoster", None)]
        self.times({124: 2.5}, extra=newcomer)
        watcher.sample(line=False)
        self.assertEqual(self.kills[-1], (124, signal.SIGSTOP))
        lines = self.record.read_text().splitlines()
        self.assertEqual(len(lines), written + 1, lines)
        self.assertRegex(lines[-1], r"\A\d\d:\d\d:\d\d paused KaleidoscopePoster \(124\) "
                                    r"after 2\.5 s of processor time\Z")
        self.now = 5.0
        self.times({124: 2.5, 110: 1.0}, extra=newcomer)
        watcher.sample()
        # Over the five seconds since the last line: counted from the
        # check instead, SpringBoard would be 25% and the newcomer nothing.
        line = self.record.read_text().splitlines()[-1]
        self.assertRegex(line, r" simulator +70% ")
        self.assertTrue(line.endswith("| KaleidoscopePoster 50%, SpringBoard 20%"), line)

    # A simulator that starts while watched gets a line at the first
    # reading that finds it, its processes counted from the reading that
    # found it not running. Raising there (the watcher would stop) or
    # writing no line fails this test.
    def test_a_simulator_that_starts_while_watched_is_counted_from_then(self):
        watcher = self.watch(pause_posters=False)
        self.times({}, without=(100,))
        watcher.sample()
        self.now = 5.0
        self.times({110: 1.0})
        watcher.sample()
        line = self.record.read_text().splitlines()[-1]
        self.assertTrue(line.endswith("| SpringBoard 20%"), line)

    # A check while the simulator is not running writes nothing: saying so
    # every second would bury the record's lines.
    def test_a_check_while_the_simulator_is_not_running_writes_nothing(self):
        watcher = self.watch(pause_posters=True)
        self.times({}, without=(100,))
        watcher.sample()
        watcher.sample(line=False)
        lines = self.record.read_text().splitlines()
        self.assertEqual(len(lines), 1, lines)
        self.assertRegex(lines[0], r"the simulator PAD is not running\Z")

    # While pausing, the watcher looks for new wallpaper extensions every
    # second, between its five-second lines. Looking only when it writes a
    # line, as it did before 2026-11-04, fails this test. The extensions
    # here are this test's own children, since the watcher pauses them for
    # real.
    def test_a_new_extension_is_paused_at_the_next_check_not_the_next_line(self):
        children = [subprocess.Popen(["sleep", "60"]) for _ in range(2)]
        for child in children:
            self.addCleanup(child.wait)
            self.addCleanup(end, child.pid)
        rows = [(child.pid, 100, "S", f"{EXTENSIONS}/{name}.appex/{name}", None)
                for child, name in zip(children, ("AegirPoster", "MercuryPosterExtension"))]

        def stopped(child):
            pid, status = os.waitpid(child.pid, os.WNOHANG | os.WUNTRACED)
            return pid == child.pid and os.WIFSTOPPED(status)

        self.times({}, without=(121, 122), extra=rows[:1])
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(os.getpid()), "--pause-posters",
                                  "--processes", str(self.processes))
        self.assertEqual(started.returncode, 0, started.stderr)
        pid = int(started.stdout.split()[0])
        self.addCleanup(end, pid)
        self.assertTrue(wait_for(lambda: stopped(children[0])), self.record.read_text())
        self.times({}, without=(121, 122), extra=rows)
        added = time.monotonic()
        self.assertTrue(wait_for(lambda: stopped(children[1])), self.record.read_text())
        self.assertLess(time.monotonic() - added, 3.0, self.record.read_text())
        stop = self.run_script("stop", "--pid", str(pid), "--out", str(self.record))
        self.assertEqual(stop.returncode, 0, stop.stderr)
        self.assertIn("Resumed 2 of them.", self.record.read_text())

    def run_script(self, *arguments):
        return subprocess.run([sys.executable, "-I", str(SCRIPT.with_name("simulator-load.py")),
                               *arguments], capture_output=True, text=True, timeout=60)

    # `start` returning before the watcher is watching, or not seeing that
    # it is, `stop` returning before its summary is written, a first line
    # that does not say when the watcher began, or a summary that does not
    # say how much processor time the watcher itself used, fails this test.
    # (Without --pause-posters: the stand-in's pids may be real processes
    # here.)
    def test_start_waits_for_the_watcher_and_stop_for_its_summary(self):
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(os.getpid()), "--processes", str(self.processes))
        self.assertEqual(started.returncode, 0, started.stderr)
        self.assertNotIn("has not begun", started.stderr)
        pid = int(started.stdout)
        self.assertRegex(self.record.read_text(), r"\AWatching simulator PAD, from \d\d:\d\d:\d\d\n")
        stopped = self.run_script("stop", "--pid", str(pid), "--out", str(self.record))
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(self.record.read_text().splitlines()[-1], "Stopped.")
        self.assertIn("Processor time the simulator's processes used while watched:", stopped.stdout)
        self.assertRegex(stopped.stdout, r"\nProcessor time the watcher itself used: \d+\.\d s\n")

    # A Mac busy starting a simulator can take longer than `start` waits
    # to start Python: on GitHub's machine (run 41656480638) the iPad's
    # watcher had not written its first line after 15 s, `start` killed
    # it, nothing was paused and the iPad stalled again. Killing a watcher
    # that is still starting, or reporting it as not started, fails this
    # test. (wait=0: the watcher cannot have begun when `start` decides.)
    def test_a_watcher_slow_to_start_is_left_to_start(self):
        printed, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(errors):
            status = self.module.start(self.arguments(pause_posters=False), wait=0)
        self.assertEqual(status, 0, errors.getvalue())
        pid = int(printed.getvalue())
        self.addCleanup(end, pid)
        self.assertIn("has not begun watching within 0 s; it is left to start", errors.getvalue())
        self.assertTrue(wait_for(
            lambda: self.record.read_text().startswith("Watching simulator PAD, from ")),
            self.record.read_text())
        stopped = self.run_script("stop", "--pid", str(pid), "--out", str(self.record))
        self.assertEqual(stopped.returncode, 0, stopped.stderr)
        self.assertEqual(self.record.read_text().splitlines()[-1], "Stopped.")

    # A watcher that ends before it begins (here its arguments are refused)
    # reported as started, as a watcher left to start would be, fails this
    # test.
    def test_a_watcher_that_ends_before_it_begins_is_reported_as_not_started(self):
        printed, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(errors):
            status = self.module.start(self.arguments(pause_posters=False, parent="not-a-pid"),
                                       wait=10)
        self.assertEqual(status, 1, errors.getvalue())
        self.assertEqual(printed.getvalue(), "")
        self.assertIn("stopped as it started (status 2)", errors.getvalue())

    # `stop` reporting a watcher that never began (ended by `stop` while
    # still starting) as one that did not finish its record, which hides
    # that nothing was paused, fails this test.
    def test_stop_says_when_the_watcher_never_began(self):
        starting = subprocess.Popen(["/bin/sleep", "30"])
        self.addCleanup(starting.wait)
        self.addCleanup(end, starting.pid)
        self.record.write_text("")
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors):
            status = self.module.stop(argparse.Namespace(pid=starting.pid, out=str(self.record)),
                                      wait=0.5)
        self.assertEqual(status, 1)
        self.assertIn("never began watching, so nothing was paused", errors.getvalue())

    # The watcher's stderr is its record. Opened without appending, an
    # error it writes after its lines (here a process list it cannot
    # parse) lands at the start and overwrites them; that fails this test.
    def test_the_watchers_own_errors_follow_its_lines(self):
        self.processes.write_text("{")
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(os.getpid()), "--processes", str(self.processes))
        self.assertEqual(started.returncode, 0, started.stderr)
        pid = int(started.stdout)
        self.addCleanup(end, pid)
        self.assertTrue(wait_for(lambda: "JSONDecodeError" in self.record.read_text()),
                        self.record.read_text())
        lines = self.record.read_text().splitlines()
        self.assertTrue(lines[0].startswith("Watching simulator PAD, from "), lines)
        self.assertIn("Traceback (most recent call last):", lines[1:])

    # A watcher that keeps running after the test run is gone (killed, say)
    # would go on pausing processes of simulators other runs start; that
    # fails this test.
    def test_the_watcher_stops_when_the_test_run_is_gone(self):
        gone = subprocess.Popen(["/bin/sh", "-c", "exit 0"])
        gone.wait()
        started = self.run_script("start", "--udid", "PAD", "--out", str(self.record),
                                  "--parent", str(gone.pid), "--processes", str(self.processes))
        self.assertEqual(started.returncode, 0, started.stderr)
        self.assertTrue(wait_for(
            lambda: self.record.read_text().splitlines()[-1:] == ["Stopped."]),
            self.record.read_text())
        self.assertIn(f"The test run ({gone.pid}) is gone.", self.record.read_text())

    # A process list the watcher cannot read must cost it one reading, not
    # the run: an error that escapes ends the watcher, so it pauses nothing
    # more and `stop` finds no summary, and a failure written without its
    # time cannot be placed against the test log. Either fails this test.
    def test_a_process_list_that_cannot_be_read_is_written_down_and_the_watcher_carries_on(self):
        self.processes.unlink()
        for number in (signal.SIGTERM, signal.SIGINT):
            self.addCleanup(signal.signal, number, signal.getsignal(number))
        self.assertEqual(self.module.watch(self.arguments(), parent_alive=lambda pid: False), 0)
        lines = self.record.read_text().splitlines()
        self.assertTrue(any(re.match(r"\d\d:\d\d:\d\d could not read the process list: ", line)
                            and "No such file" in line for line in lines), lines)
        self.assertEqual(lines[-1], "Stopped.")

    # The structures are read straight from the kernel's bytes, so a field
    # of the wrong size shifts every field after it. A size that differs
    # from xnu's bsd/sys/proc_info.h (struct proc_bsdshortinfo, 64 bytes;
    # struct proc_taskinfo, 96) or mach/mach_time.h, or a field the watcher
    # reads at another place or of another length, fails this test.
    def test_the_structures_have_the_kernels_sizes(self):
        sizes = {name: ctypes.sizeof(getattr(self.module, name))
                 for name in ("ShortInfo", "TaskInfo", "Timebase")}
        self.assertEqual(sizes, {"ShortInfo": 64, "TaskInfo": 96, "Timebase": 8})
        # Where each field the watcher reads starts, and how long it is:
        # padding can hide a field that is too short from the sizes alone.
        fields = {name: (getattr(structure, name).offset, getattr(structure, name).size)
                  for structure, names in ((self.module.ShortInfo, ("ppid", "status", "comm")),
                                           (self.module.TaskInfo, ("total_user", "total_system")),
                                           (self.module.Timebase, ("numer", "denom")))
                  for name in names}
        self.assertEqual(fields, {"ppid": (4, 4), "status": (12, 4), "comm": (16, 16),
                                  "total_user": (16, 8), "total_system": (24, 8),
                                  "numer": (0, 4), "denom": (4, 4)})


@unittest.skipUnless(sys.platform == "darwin",
                     "the Mac's process calls exist only on a Mac; CI's unit job runs these on one")
class MacProcessesTests(unittest.TestCase):
    """The process calls the watcher makes on a Mac read what /bin/ps reads,
    give processor time in seconds, and start no process
    (docs/log/2026-11-04-watcher-without-ps.md)."""

    def setUp(self):
        self.module = simulator_load()
        self.system = self.module.MacProcesses()

    def child(self, *command):
        process = subprocess.Popen(command)
        self.addCleanup(process.wait)
        self.addCleanup(end, process.pid)
        return process

    # Reading a field from the wrong place, the wrong process's details,
    # a stopped process as running, another user's process (launchd's) not
    # at all, or a process's arguments wrongly, fails this test.
    def test_each_process_reads_as_ps_reads_it(self):
        sleeper = self.child("/bin/sleep", "60")
        os.kill(sleeper.pid, signal.SIGSTOP)
        self.assertTrue(wait_for(lambda: self.system.table().get(sleeper.pid, (0, False))[1]))
        table = self.system.table()
        self.assertEqual(table[sleeper.pid], (os.getpid(), True, "sleep"))
        self.assertFalse(table[os.getpid()][1])
        self.assertEqual(table[1][2], "launchd")
        self.assertEqual(self.system.arguments(sleeper.pid), ["/bin/sleep", "60"])
        _, path = self.system.details(sleeper.pid)
        self.assertEqual(os.path.realpath(path), os.path.realpath("/bin/sleep"))
        ppid, state, command = subprocess.run(
            ["/bin/ps", "-o", "ppid=,stat=,comm=", "-p", str(sleeper.pid)],
            capture_output=True, text=True, check=True).stdout.split(None, 2)
        self.assertEqual((int(ppid), "T" in state, os.path.basename(command.strip())),
                         (os.getpid(), True, "sleep"))

    # Task times are in Mach time units, which are not nanoseconds on Apple
    # silicon. Reading them as nanoseconds, or the processors' busy time
    # from a copy that does not grow with the work done (host_statistics
    # gave the same counts before and after this test's half second of work
    # on GitHub's machine, run 41748946044), fails this test.
    def test_processor_time_is_in_seconds(self):
        # More asks than the kernel answers afresh in a second
        # (HOST_STATISTICS_MAX_REQUESTS, 10), so a copy would be caught
        # however few other programs are asking.
        for _ in range(12):
            self.system.processor_ticks()
        own, used, ticks = (self.system.details(os.getpid())[0], time.process_time(),
                            self.system.processor_ticks())
        deadline = time.process_time() + 0.3
        while time.process_time() < deadline:
            pass
        own = self.system.details(os.getpid())[0] - own
        used = time.process_time() - used
        busy = sum((after - before) % 2**32 for after, before
                   in zip(self.system.processor_ticks(), ticks)) / self.system.ticks_per_second
        self.assertAlmostEqual(own, used, delta=0.25 * used)
        self.assertGreater(busy, 0.5 * used)

    # A process that has ended has no details: reading something for it
    # anyway (a reused buffer's last contents, say) fails this test.
    def test_an_ended_process_has_no_details(self):
        finished = subprocess.Popen(["/usr/bin/true"])
        finished.wait()
        self.assertIsNone(self.system.details(finished.pid))
        self.assertNotIn(finished.pid, self.system.table())

    # Starting a process to read anything (going back to ps, whose
    # time-outs left the watcher blind for minutes on GitHub's machines)
    # fails this test. Each call a reading makes runs, on this process
    # (CI boots no simulator before this test, so a reading alone would
    # not reach launchd_sim's arguments or a process's details), and then
    # a whole reading: a simulator that is not running is said to be not
    # running.
    def test_a_reading_starts_no_process(self):
        expected = subprocess.run(["/bin/ps", "-ww", "-o", "args=", "-p", str(os.getpid())],
                                  capture_output=True, text=True, check=True).stdout.strip()
        refuse = mock.Mock(side_effect=AssertionError("the watcher started a process"))
        with tempfile.TemporaryFile("w+") as out, \
                mock.patch.object(subprocess, "Popen", refuse), \
                mock.patch.object(os, "posix_spawn", refuse), \
                mock.patch.object(os, "fork", refuse), \
                mock.patch.object(os, "system", refuse):
            self.assertIn(os.getpid(), self.system.table())
            self.assertEqual(" ".join(self.system.arguments(os.getpid())), expected)
            self.assertIsNotNone(self.system.details(os.getpid()))
            self.assertTrue(self.system.processor_ticks())
            watcher = self.module.Watch("NO-SUCH-SIMULATOR", out, True, self.system)
            watcher.sample()
            out.seek(0)
            self.assertRegex(out.read(), r"\A\d\d:\d\d:\d\d the simulator NO-SUCH-SIMULATOR is not running\n\Z")
        refuse.assert_not_called()

    # scripts/test.sh runs the watcher with the Mac's own /usr/bin/python3,
    # which can be older than the python3 running these tests (3.9 on
    # GitHub's machines). A call or syntax that interpreter lacks, or a
    # process call that fails on a real Mac, fails this test: the record
    # would end in a traceback or say the list could not be read.
    def test_the_watcher_runs_under_the_macs_own_python(self):
        with tempfile.TemporaryDirectory() as folder:
            record = Path(folder) / "simulator-load.txt"
            command = ["/usr/bin/python3", "-I", str(SCRIPT.with_name("simulator-load.py"))]
            started = subprocess.run(
                command + ["start", "--udid", "NO-SUCH-SIMULATOR", "--out", str(record),
                           "--parent", str(os.getpid()), "--pause-posters"],
                capture_output=True, text=True, timeout=120)
            self.assertEqual(started.returncode, 0, started.stderr)
            pid = int(started.stdout.split()[0])
            self.addCleanup(end, pid)
            self.assertTrue(wait_for(lambda: "is not running" in record.read_text(), seconds=30),
                            record.read_text())
            stopped = subprocess.run(command + ["stop", "--pid", str(pid), "--out", str(record)],
                                     capture_output=True, text=True, timeout=120)
            text = record.read_text()
            self.assertEqual(stopped.returncode, 0, stopped.stderr + text)
            self.assertEqual(text.splitlines()[-1], "Stopped.")
            self.assertNotIn("Traceback", text)
            self.assertNotIn("could not read", text)


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


REPOSITORY = SCRIPT.parent.parent
STEPS_KEY = re.compile(r"steps:\s*(&[^\s#]+\s*)?(#.*)?")
USES = re.compile(r"""uses:\s*["']?([^\s#"']+)""")
WITH_KEY = re.compile(r"with:\s*(&[^\s#]+\s*)?(#.*)?")
NO_TOKEN = re.compile(r"""persist-credentials:\s*(["']?)(?i:false)\1\s*(#.*)?""")
FLOW_NO_TOKEN = re.compile(r"""with:\s*(&[^\s#]+\s*)?\{([^{}"']*,)?\s*"""
                           r"""persist-credentials\s*:\s*(["']?)(?i:false)\3\s*[,}]""")
# actions/checkout in any spelling GitHub may accept: any case, a backslash
# or a doubled slash, spaces; but not another action whose name holds it.
CHECKOUT = re.compile(r"(?<![\w.-])actions\s*[/\\]+\s*checkout(?![\w.-])", re.I)
LOCKED_PATH = re.compile(r"\s+'(\.github/workflows/[^']+)':\s*")
LOCKED_ACTION = re.compile(r"\s+- '([^']+)'\s*")


def workflow_steps(text):
    """Every step of every job, as (number, column, line) triples: the
    line's number in the file, the column where its text starts (for a
    step's first line, after its `- `) and the line stripped, leaving out
    blank lines and whole-line comments. A step starts at a `- ` item
    under a `steps:` key (which may carry an anchor or a comment), at the
    key's own depth or deeper, and runs to the next item at that depth or
    the end of the steps. Flow lists (`steps: [...]`) and other forms are
    not read; unread_checkouts reports a checkout written in one."""
    steps, current, steps_indent, item_indent = [], None, None, None
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        is_item = stripped == "-" or stripped.startswith("- ")
        if steps_indent is not None and (
                indent < steps_indent or (indent == steps_indent and not is_item)):
            steps_indent, item_indent, current = None, None, None
        if steps_indent is None and STEPS_KEY.fullmatch(stripped):
            steps_indent = indent
        elif steps_indent is not None and is_item and item_indent in (None, indent):
            item_indent = indent
            content = stripped[1:].lstrip()
            current = [(number, indent + len(stripped) - len(content), content)] if content else []
            steps.append(current)
        elif current is not None:
            current.append((number, indent, stripped))
    return steps


def uses_line(step):
    """The number of a step's own `uses:` line and what it names, quotes
    and comment removed, or (None, "")."""
    column = step[0][1] if step else 0
    for number, col, line in step:
        found = USES.match(line) if col == column else None
        if found:
            return number, found.group(1)
    return None, ""


def step_uses(step):
    return uses_line(step)[1]


def step_keeps_no_token(step):
    """True when `persist-credentials` is false directly under the step's
    own `with:`, or in its own flow `with: {...}`, and nowhere else counts."""
    column = step[0][1] if step else 0
    inside, child = False, None
    for _, col, line in step:
        if col <= column:
            if col == column and FLOW_NO_TOKEN.match(line):
                return True
            inside, child = col == column and WITH_KEY.fullmatch(line) is not None, None
        elif inside:
            child = col if child is None else child
            if col == child and NO_TOKEN.fullmatch(line):
                return True
    return False


def checkout_steps(text):
    return [step for step in workflow_steps(text) if CHECKOUT.search(step_uses(step))]


def unread_checkouts(text):
    """The numbers of the lines that name actions/checkout, outside
    whole-line comments, but are not the `uses:` line of a step read as a
    checkout: a checkout in a form workflow_steps does not read (a flow
    list, an anchor or alias, a quoted key, a block scalar), or text that
    only names it. Lines, not counts, are compared, so a step read where
    none runs cannot stand in for one that was not read. The reader guards
    against mistakes, not against a file written to fool it."""
    named = {number for number, line in enumerate(text.splitlines(), 1)
             if not line.lstrip().startswith("#") and CHECKOUT.search(line)}
    return sorted(named - {uses_line(step)[0] for step in checkout_steps(text)})


def read_checked(path):
    """A checked file's text, or None when it cannot be read (missing, or
    not UTF-8)."""
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def checked_files(root):
    """The workflows, every action.yml or action.yaml under .github, and
    each local action (`uses: ./path`) that any of them runs, in the order
    found. A local action whose folder holds neither file is listed as its
    action.yml, which does not exist. A file that cannot be read is still
    listed, for checkout_problems to report."""
    github = root / ".github"
    files = list(dict.fromkeys(sorted((github / "workflows").glob("*.y*ml"))
                               + sorted(github.rglob("action.y*ml"))))
    for path in files:  # grows as local actions are found
        for step in workflow_steps(read_checked(path) or ""):
            uses = step_uses(step)
            if uses.startswith("./"):
                folder = root / uses
                action = next((folder / name for name in ("action.yml", "action.yaml")
                               if (folder / name).is_file()), folder / "action.yml")
                if action not in files:
                    files.append(action)
    return files


def checkout_problems(root):
    """What is wrong with the checkouts in each file checked_files lists,
    as (file, line, message) triples in the order found, and how many
    checkouts were read. Each file is checked on its own text, read once;
    one that cannot be read is a problem of its own (line None) and never
    stops the others being checked."""
    problems, checkouts = [], 0
    for path in checked_files(root):
        name = str(path.relative_to(root))
        text = read_checked(path)
        if text is None:
            problems.append((name, None, f"{name} cannot be read: a step runs a local action "
                             "with no action.yml or action.yaml, or the file is not UTF-8."))
            continue
        for line in unread_checkouts(text):
            problems.append((name, line, f"Line {line} of {name} names actions/checkout "
                             "outside a step the reader read: a checkout in a form "
                             "workflow_steps does not know (a flow list, an anchor or alias, "
                             "a quoted key, a block scalar) or text that only names it. Write "
                             "the checkout as a plain block step, or reword the text."))
        for step in checkout_steps(text):
            checkouts += 1
            if not step_keeps_no_token(step):
                line = uses_line(step)[0]
                problems.append((name, line, f"The checkout at line {line} of {name} keeps "
                                 "the job's token: add `persist-credentials: false` under its "
                                 "own `with:`, written out (an alias is not followed)."))
    return problems, checkouts


def locked_workflows(text):
    """What actions.lock records for each workflow, as `gh actions-lock`
    writes it: a quoted path, then one quoted `- 'owner/repo@ref'` per
    action, until the next path or the next top-level key."""
    locked, current = {}, None
    for line in text.splitlines():
        path = LOCKED_PATH.fullmatch(line)
        entry = LOCKED_ACTION.fullmatch(line)
        if not line.startswith(" "):
            current = None
        elif path:
            current = locked.setdefault(path.group(1), set())
        elif entry and current is not None:
            current.add(entry.group(1))
    return locked


def lock_key(uses):
    """The name actions.lock records a step's `uses:` under: lower case,
    without the path of an action in a folder of its repository."""
    name, _, ref = uses.partition("@")
    return "/".join(name.lower().split("/")[:2]) + "@" + ref


def lockfile_problems(root):
    """Each action a workflow's steps name that actions.lock does not
    record for that workflow, as (file, line, message) triples, and how
    many actions were read. A check that needs no network or `gh`, so a
    cloud thread and scripts/test.sh can run it. It covers only what
    workflow_steps reads, and proves nothing about commits: `gh
    actions-lock --verify`, in verify-lockfile.yml, is the real check."""
    name = ".github/workflows/actions.lock"
    text = read_checked(root / name)
    if text is None:
        return [(name, None, f"{name} cannot be read. Run `gh actions-lock`.")], 0
    locked = locked_workflows(text)
    if not locked:
        return [(name, None, f"{name} records no workflows: it is empty, or not in the "
                 "format locked_workflows reads.")], 0
    problems, actions = [], 0
    for path in sorted((root / ".github/workflows").glob("*.y*ml")):
        workflow = str(path.relative_to(root))
        steps = read_checked(path)
        if steps is None:
            problems.append((workflow, None, f"{workflow} cannot be read."))
            continue
        for step in workflow_steps(steps):
            number, uses = uses_line(step)
            if not uses or uses.startswith(("./", "$/", "docker://")):
                continue
            actions += 1
            if lock_key(uses) not in locked.get(workflow, ()):
                problems.append((workflow, number, f"Line {number} of {workflow} uses {uses}, "
                                 f"which {name} does not record for it. Run `gh actions-lock` "
                                 "on the owner's Mac and commit the lockfile with the workflow "
                                 "(AGENTS.md, *Gotchas*)."))
    return problems, actions


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

    # A checkout without `persist-credentials: false`, in a workflow or in
    # a local action one runs, fails this test, and so does any line that
    # names actions/checkout outside a step the reader read. By default
    # actions/checkout leaves the job's token where every later step can
    # read it; no step here needs it (docs/DECISIONS.md, "Reviews, updates
    # and GitHub settings", *Dependencies*).
    def test_every_checkout_leaves_no_token_behind(self):
        problems, checkouts = checkout_problems(REPOSITORY)
        self.assertEqual([message for _, _, message in problems], [])
        self.assertGreater(checkouts, 0, "No workflow checks out the repository.")

    # Reading steps wrongly (missing one, merging two, or losing a line's
    # number or depth) fails this test, so the test above cannot pass by not
    # seeing a checkout. Each job uses a form the reader must know: an
    # indented list under `steps:` with a comment after the key, and a list
    # at the key's own depth under an anchored `steps:`.
    def test_workflow_steps_are_read_one_by_one(self):
        steps = workflow_steps(textwrap.dedent("""\
            jobs:
              one:
                steps:  # the first job
                  # a comment
                  - uses: actions/checkout@v7
                    with:
                      persist-credentials: false
                  - name: Run
                    run: |
                      echo uses: actions/checkout@v7
              two:
                runs-on: ubuntu-latest
                steps: &shared
                - name: Check out
                  uses: "actions/checkout@v7"
                - run: echo two
            """))
        self.assertEqual(steps, [
            [(5, 8, "uses: actions/checkout@v7"), (6, 8, "with:"),
             (7, 10, "persist-credentials: false")],
            [(8, 8, "name: Run"), (9, 8, "run: |"), (10, 10, "echo uses: actions/checkout@v7")],
            [(14, 6, "name: Check out"), (15, 6, 'uses: "actions/checkout@v7"')],
            [(16, 6, "run: echo two")],
        ])

    # Every line that names actions/checkout, in any spelling GitHub may
    # accept, is either the `uses:` line of a step the reader read as a
    # checkout or reported. Reading an anchored, aliased, quoted-key,
    # block-scalar, next-line or flow checkout as checked, or comparing
    # counts rather than lines (a step read inside a block scalar would
    # then balance a flow checkout), fails this test; so does missing a
    # checkout spelled with capitals or a backslash, or reporting a
    # whole-line comment or another action.
    def test_a_checkout_the_reader_cannot_see_is_reported(self):
        text = textwrap.dedent("""\
            jobs:
              plain:
                steps:
                  - uses: actions/checkout@v7  # read
                  - name: Two
                    uses: 'Actions/Checkout@v7'  # read
                  - uses: actions\\checkout@v7  # read
                  - uses: actions/checkout-other@v1
                  # - uses: actions/checkout@v7
              hidden:
                steps:
                  - uses: &checkout actions/checkout@v7  # unread
                  - uses: *checkout
                  - "uses": actions/checkout@v7  # unread
                  - uses: >-
                      actions/checkout@v7  # unread
                  - uses:
                      actions/checkout@v7  # unread
                  - {uses: actions/checkout@v7}  # unread
                  - run: echo actions/checkout  # unread
              flow:
                steps: [uses: actions/checkout@v7]  # unread
              decoy:
                env:
                  NOTE: |
                    steps:
                      - uses: actions/checkout@v7  # read
                        with:
                          persist-credentials: false
                steps: [{uses: actions/checkout@v7}]  # unread
            """)
        lines = text.splitlines()
        marked = {mark: [n for n, line in enumerate(lines, 1) if line.endswith("# " + mark)]
                  for mark in ("read", "unread")}
        self.assertEqual([uses_line(step)[0] for step in checkout_steps(text)], marked["read"])
        self.assertEqual(unread_checkouts(text), marked["unread"])

    # A step counts as keeping no token only when `persist-credentials` is
    # false directly under its own `with:` (which may carry an anchor or be a
    # flow mapping), in any case GitHub reads as false: the key anywhere
    # else, true, an expression, or a `with:` given by alias, fails, and a
    # quoted `uses:` is still read as a checkout.
    def test_a_checkout_keeps_no_token_only_through_its_with(self):
        def step(body):
            steps = workflow_steps("steps:\n" + textwrap.indent(textwrap.dedent(body), "  "))
            self.assertEqual(len(steps), 1)
            return steps[0]

        self.assertEqual(step_uses(step("""\
            - name: Check out
              uses: 'actions/checkout@v7'  # quoted
            """)), "actions/checkout@v7")
        kept = {
            "under with": """\
                - uses: actions/checkout@v7
                  with:
                    fetch-depth: 0
                    persist-credentials: 'false'  # why
                """,
            "with first": """\
                - with:
                    persist-credentials: false
                  uses: actions/checkout@v7
                """,
            "capital false": """\
                - uses: actions/checkout@v7
                  with:
                    persist-credentials: "False"
                """,
            "anchored with": """\
                - uses: actions/checkout@v7
                  with: &no-token  # shared
                    persist-credentials: FALSE
                """,
            "flow with": """\
                - uses: actions/checkout@v7
                  with: { fetch-depth: 0, persist-credentials: false }
                """,
        }
        leaked = {
            "no setting": "- uses: actions/checkout@v7\n",
            "true": """\
                - uses: actions/checkout@v7
                  with:
                    persist-credentials: true
                """,
            "an expression": """\
                - uses: actions/checkout@v7
                  with:
                    persist-credentials: ${{ false }}
                """,
            "at the step's own depth": """\
                - uses: actions/checkout@v7
                  persist-credentials: false
                """,
            "under env": """\
                - uses: actions/checkout@v7
                  env:
                    persist-credentials: false
                """,
            "nested below with": """\
                - uses: actions/checkout@v7
                  with:
                    other:
                      persist-credentials: false
                """,
            "with ended before it": """\
                - uses: actions/checkout@v7
                  with:
                    fetch-depth: 0
                  name: Check out
                  persist-credentials: false
                """,
            "flow with, true": """\
                - uses: actions/checkout@v7
                  with: { persist-credentials: true }
                """,
            "flow with, inside a string": """\
                - uses: actions/checkout@v7
                  with: { note: "a, persist-credentials: false, b" }
                """,
            "with by alias": """\
                - uses: actions/checkout@v7
                  with: *no-token
                """,
            "a capitalised With": """\
                - uses: actions/checkout@v7
                  With:
                    persist-credentials: false
                """,
        }
        for name, body in kept.items():
            with self.subTest(name):
                self.assertTrue(step_keeps_no_token(step(body)))
        for name, body in leaked.items():
            with self.subTest(name):
                self.assertFalse(step_keeps_no_token(step(body)))

    # Leaving out the actions under .github, a local action a workflow or an
    # action runs (`uses: ./path`, with action.yml or action.yaml), or one
    # whose folder holds neither, fails this test.
    def test_local_actions_are_checked_with_the_workflows(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = {
                ".github/workflows/ci.yml": "steps:\n  - uses: ./tools/build\n  - uses: ./missing\n",
                ".github/actions/setup/action.yml":
                    "runs:\n  steps:\n    - uses: ./tools/build\n",
                "tools/build/action.yaml": "runs:\n  steps:\n    - uses: actions/checkout@v7\n",
                "tools/unused/action.yml": "runs:\n  steps:\n    - uses: actions/checkout@v7\n",
            }
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text)
            self.assertEqual([str(path.relative_to(root)) for path in checked_files(root)], [
                ".github/workflows/ci.yml",
                ".github/actions/setup/action.yml",
                "tools/build/action.yaml",
                "missing/action.yml",
            ])

    # Stopping at a file that cannot be read (not UTF-8, or a local action
    # that is missing), reusing the previous file's text for it, or not
    # reporting it, fails this test: each file is checked on its own text,
    # and one that cannot be read is a problem of its own.
    def test_a_file_that_cannot_be_read_is_reported_and_the_rest_checked(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = {
                ".github/workflows/a.yml": b"steps:\n  - uses: \xff\xfe\n",
                ".github/workflows/b.yml":
                    b"steps:\n  - uses: actions/checkout@v7\n  - uses: ./missing\n"
                    b"flow: [actions/checkout@v7]\n",
                ".github/workflows/c.yml":
                    b"steps:\n  - uses: actions/checkout@v7\n"
                    b"    with:\n      persist-credentials: false\n",
            }
            for name, data in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_bytes(data)
            problems, checkouts = checkout_problems(root)
        found = [(name, line, next(kind for kind in ("cannot be read", "outside a step",
                                                     "keeps the job's token")
                                   if kind in message))
                 for name, line, message in problems]
        self.assertEqual(found, [
            (".github/workflows/a.yml", None, "cannot be read"),
            (".github/workflows/b.yml", 4, "outside a step"),
            (".github/workflows/b.yml", 2, "keeps the job's token"),
            ("missing/action.yml", None, "cannot be read"),
        ])
        self.assertEqual(checkouts, 2)

    # Changing a `uses:` line, or adding a workflow or a step that runs an
    # action, without running `gh actions-lock` again fails this test; so
    # does a lockfile that is gone or that this reader no longer reads, and
    # a workflow with no actions read (docs/DECISIONS.md, *Dependencies*).
    def test_every_action_a_workflow_runs_is_in_the_lockfile(self):
        problems, actions = lockfile_problems(REPOSITORY)
        self.assertEqual([message for _, _, message in problems], [])
        self.assertGreater(actions, 0, "No workflow step that runs an action was read.")

    # Matching an action in another workflow's list or under `dependencies:`,
    # comparing names with their case or their path in the action's
    # repository, checking local actions, or stopping at a file that cannot
    # be read, fails this test.
    def test_an_action_the_lockfile_does_not_record_is_reported(self):
        lock = textwrap.dedent("""\
            # Do not edit by hand.
            version: 'v0.0.3'
            workflows:
                '.github/workflows/a.yml':
                    - 'actions/checkout@v7.0.1'
                    - 'github/codeql-action@v4.39.3'
                '.github/workflows/b.yml':
                    - 'actions/upload-artifact@v7.0.0'
            dependencies:
                'actions/deploy-pages@v5.0.0':
                    ref: 'v5.0.0'
                    uses:
                        - 'actions/cache@v4.0.0'
            """)
        self.assertEqual(locked_workflows(lock), {
            ".github/workflows/a.yml": {"actions/checkout@v7.0.1", "github/codeql-action@v4.39.3"},
            ".github/workflows/b.yml": {"actions/upload-artifact@v7.0.0"},
        })
        files = {
            ".github/workflows/actions.lock": lock.encode(),
            ".github/workflows/a.yml": b"""\
steps:
  - uses: Actions/Checkout@v7.0.1
  - uses: github/codeql-action/init@v4.39.3
  - uses: ./tools/build
  - uses: $/tools/build
  - uses: docker://alpine:3
  - run: echo no action here
  - uses: actions/checkout@v7
  - uses: actions/upload-artifact@v7.0.0
  - uses: actions/deploy-pages@v5.0.0
""",
            ".github/workflows/b.yaml": b"steps:\n  - uses: actions/upload-artifact@v7.0.0\n",
            ".github/workflows/c.yml": b"steps:\n  - uses: \xff\xfe\n",
            ".github/workflows/d.yml": b"steps:\n  - run: echo no action here\n",
        }
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name, data in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_bytes(data)
            problems, actions = lockfile_problems(root)
        self.assertEqual([(name, line) for name, line, _ in problems], [
            (".github/workflows/a.yml", 8),
            (".github/workflows/a.yml", 9),
            (".github/workflows/a.yml", 10),
            (".github/workflows/b.yaml", 2),
            (".github/workflows/c.yml", None),
        ])
        self.assertEqual(actions, 6)

    # A lockfile that is missing, not UTF-8, empty, or in a format the
    # reader does not know must not read as "nothing to report".
    def test_a_lockfile_that_cannot_be_read_is_reported(self):
        for name, data in {"missing": None, "not UTF-8": b"\xff\xfe", "empty": b"",
                           "another format": b"workflows:\n  ci: [actions/checkout@v7]\n"}.items():
            with self.subTest(name), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / ".github/workflows").mkdir(parents=True)
                (root / ".github/workflows/a.yml").write_text(
                    "steps:\n  - uses: actions/checkout@v7\n")
                if data is not None:
                    (root / ".github/workflows/actions.lock").write_bytes(data)
                problems, actions = lockfile_problems(root)
                self.assertEqual([(file, line) for file, line, _ in problems],
                                 [(".github/workflows/actions.lock", None)])
                self.assertEqual(actions, 0)

    # Dropping the pull request trigger, adding a path filter (a required
    # check that never arrives leaves every pull request waiting), widening
    # the token, renaming the job, leaving the extension unpinned, checking
    # with --verify-local, which proves no commit, or putting --accept-moved
    # in any workflow fails this test.
    def test_the_lockfile_is_verified_on_every_pull_request(self):
        text = "\n".join(line for line in VERIFY_LOCKFILE.read_text().splitlines()
                         if not line.lstrip().startswith("#"))
        self.assertRegex(text, r"(?m)^on:\n  pull_request: *$")
        self.assertRegex(text, r"(?m)^  push:\n    branches: \[main\] *$")
        self.assertNotRegex(text, r"(?m)^ +(paths|paths-ignore|branches-ignore|types):")
        self.assertRegex(text, r"(?m)^permissions:\n  contents: read\n+\S")
        self.assertEqual(text.count("permissions:"), 1)
        self.assertNotIn("pull_request_target", text)
        jobs = workflow_jobs(text)
        self.assertEqual(len(jobs), 1, jobs)
        body = "\n".join(next(iter(jobs.values())))
        self.assertRegex(body, r"(?m)^    name: Verify lockfile *$")
        install = re.search(
            r"(?m)^ +(- )?run: gh extension install github/gh-actions-lock --pin v\d+\.\d+\.\d+ *$",
            body)
        self.assertIsNotNone(install, "The extension is not installed at a pinned release.")
        verify = re.search(r"(?m)^ +(- )?run: gh actions-lock --verify *$", body)
        self.assertIsNotNone(verify, "The job does not run `gh actions-lock --verify`.")
        self.assertLess(install.start(), verify.start())
        for path in sorted((REPOSITORY / ".github/workflows").glob("*.y*ml")):
            with self.subTest(workflow=path.name):
                self.assertNotIn("--accept-moved", path.read_text())

    # Writing an Xcode version or app path into the workflow fails this test.
    def test_the_workflow_names_no_xcode_version(self):
        pinned = [line.strip() for line in WORKFLOW.read_text().splitlines()
                  if not line.lstrip().startswith("#")
                  and re.search(r"Xcode_\d|DEVELOPER_DIR|xcode-version", line)]
        self.assertEqual(pinned, [])


if __name__ == "__main__":
    unittest.main()
