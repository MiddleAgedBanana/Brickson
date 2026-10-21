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

# Answers the build-settings query with the fixture's deployment target, and
# counts every other xcodebuild run.
FAKE_XCODEBUILD = """\
for argument in "$@"; do
    if [ "$argument" = -showBuildSettings ]; then
        printf '[{"target":"Brickson","buildSettings":{"IPHONEOS_DEPLOYMENT_TARGET":"%s"}}]\\n' "$FIXTURE_TARGET"
        exit 0
    fi
done
echo invoked >> "$RUNNER_INVOCATIONS"
"""

# The simulator list, the selected Xcode's simulator SDK, and booting.
FAKE_XCRUN = """\
case "$*" in
    "simctl list devices available --json") cat "$FIXTURE_DEVICES" ;;
    "--sdk iphonesimulator --show-sdk-version") echo "$FIXTURE_SDK" ;;
    "simctl bootstatus "*" -b") exit 0 ;;
    *) echo "unexpected: xcrun $*" >&2; exit 1 ;;
esac
"""


def run_script(build_body, mode="ui", destination="id=fixture-simulator",
               target="26.0", sdk="27.1", devices=None):
    with tempfile.TemporaryDirectory() as directory:
        for name, body in {
            "xcodegen": "exit 0",
            "xcodebuild": FAKE_XCODEBUILD + build_body,
            "xcrun": FAKE_XCRUN,
            # Model the formatter discarding destination-detail lines.
            "xcbeautify": "cat >/dev/null",
        }.items():
            path = Path(directory, name)
            path.write_text("#!/bin/bash\n" + body + "\n")
            path.chmod(0o755)
        devices_path = Path(directory, "devices.json")
        devices_path.write_text(json.dumps({"devices": devices or {}}))
        environment = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin",
                           RUNNER_INVOCATIONS=f"{directory}/invocations",
                           FIXTURE_DEVICES=str(devices_path),
                           FIXTURE_TARGET=target, FIXTURE_SDK=sdk)
        environment.pop("DESTINATION", None)
        if destination is not None:
            environment["DESTINATION"] = destination
        result = subprocess.run(["/bin/bash", str(SCRIPT), mode],
                                env=environment, capture_output=True, text=True)
        invocations = Path(directory, "invocations")
        result.invocations = (len(invocations.read_text().splitlines())
                              if invocations.exists() else 0)
        return result


def runtime(version):
    return "com.apple.CoreSimulator.SimRuntime.iOS-" + version.replace(".", "-")


def device(name, udid):
    return {"name": name, "udid": udid, "isAvailable": True, "state": "Shutdown"}


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
        result = self.run_script("echo 'assertion failure'\nexit 65")
        self.assertEqual(result.returncode, 65)
        self.assertEqual(result.invocations, 1)
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
