#!/usr/bin/env python3
"""Exercise test.sh's error reporting without booting a simulator."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name("test.sh")


class RunnerTests(unittest.TestCase):
    def run_script(self, build_body):
        with tempfile.TemporaryDirectory() as directory:
            for name, body in {
                "xcodegen": "exit 0",
                "xcodebuild": 'echo invoked >> "$RUNNER_INVOCATIONS"\n' + build_body,
                # Model the formatter discarding destination-detail lines.
                "xcbeautify": "cat >/dev/null",
            }.items():
                path = Path(directory, name)
                path.write_text("#!/bin/bash\n" + body + "\n")
                path.chmod(0o755)
            environment = dict(os.environ, PATH=f"{directory}:/usr/bin:/bin",
                               DESTINATION="id=fixture-simulator",
                               RUNNER_INVOCATIONS=f"{directory}/invocations")
            result = subprocess.run(["/bin/bash", str(SCRIPT), "ui"],
                                    env=environment, capture_output=True, text=True)
            result.invocations = len(Path(directory, "invocations").read_text().splitlines())
            return result

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


if __name__ == "__main__":
    unittest.main()
