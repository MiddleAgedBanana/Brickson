#!/usr/bin/env python3
"""Exercise test.sh's error reporting and simulator choice without booting a
simulator, and check that CI runs it with the newest released Xcode."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
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
        result = subprocess.run(["/bin/bash", str(fixture_scripts / "test.sh"), mode, *arguments],
                                env=environment, capture_output=True, text=True)
        result.events = lines(Path(directory, "events"))
        result.preflights = [event for event in result.events if event in ("docs", "hooks")]
        result.calls = lines(Path(directory, "invocations"))
        result.invocations = len(result.calls)
        result.simctl = lines(Path(directory, "simctl"))
        result.stale_bundle_kept = stale.exists()
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
            "simctl spawn PAD defaults write com.apple.keyboard.preferences "
            "AutomaticMinimizationEnabled -bool false",
            "simctl spawn PAD defaults write com.apple.keyboard.preferences "
            "DidShowContinuousPathIntroduction -bool true",
            "simctl install PAD " + result.results_dir.replace(
                "TestResults", "DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app"),
            "simctl launch PAD fixture.brickson --fresh-test-storage",
            "sleep 15",
            "simctl terminate PAD fixture.brickson",
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

    # Writing an Xcode version or app path into the workflow fails this test.
    def test_the_workflow_names_no_xcode_version(self):
        pinned = [line.strip() for line in WORKFLOW.read_text().splitlines()
                  if not line.lstrip().startswith("#")
                  and re.search(r"Xcode_\d|DEVELOPER_DIR|xcode-version", line)]
        self.assertEqual(pinned, [])


if __name__ == "__main__":
    unittest.main()
