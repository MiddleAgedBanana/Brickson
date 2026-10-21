#!/usr/bin/env python3
"""Exercise select-xcode.py with made-up Xcode installs and feeds; no Mac or
network needed. Run with python3 scripts/test-select-xcode.py."""
import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
SCRIPT = Path(__file__).resolve().with_name("select-xcode.py")
spec = importlib.util.spec_from_file_location("select_xcode", SCRIPT)
select_xcode = importlib.util.module_from_spec(spec)
spec.loader.exec_module(select_xcode)


def install(applications, name, version, build):
    contents = Path(applications, name, "Contents")
    contents.mkdir(parents=True)
    with open(contents / "version.plist", "wb") as file:
        plistlib.dump({"CFBundleShortVersionString": version,
                       "ProductBuildVersion": build}, file)
    return Path(applications, name)


def feed(*titles):
    items = "".join(f"<item><title>{title}</title></item>" for title in titles)
    return f"<?xml version='1.0'?><rss><channel>{items}</channel></rss>"


APPLE_FEED = feed("Xcode 27.2 RC (27B48)", "iOS 27.2 RC (24B115)",
                  "Xcode 27.1 (27A9275)", "Xcode 27.1 beta (27A9269)",
                  "Xcode 27 (27A266a)", "Xcode 26.6 (17F113)")


class ChooseTests(unittest.TestCase):
    """The Xcode CI builds with: the newest release installed."""

    def choose(self, *apps, feed_text=None):
        with tempfile.TemporaryDirectory() as applications:
            for app in apps:
                if isinstance(app, tuple):
                    install(applications, *app)
                else:
                    link, target = app.split(" -> ")
                    Path(applications, link).symlink_to(Path(applications, target))
            chosen = select_xcode.choose(Path(applications), feed_text)
            return chosen.name if chosen else None

    # Sorting versions as text ("27.10" before "27.9") or keeping the runner's
    # default fails this test.
    def test_newest_release_by_version_number(self):
        self.assertEqual(self.choose(("Xcode_26.6.app", "26.6", "17F113"),
                                     ("Xcode_27.9.app", "27.9", "27J1"),
                                     ("Xcode_27.10.app", "27.10", "27K1"),
                                     "Xcode.app -> Xcode_26.6.app"),
                         "Xcode_27.10.app")

    # Choosing a beta or a release candidate, which App Store Connect refuses
    # to accept builds from, fails this test.
    def test_skips_betas_and_release_candidates(self):
        self.assertEqual(self.choose(("Xcode_27.1.app", "27.1", "27A9275"),
                                     ("Xcode_27.2_beta.app", "27.2", "27B5010a"),
                                     ("Xcode_27.2_beta_3.app", "27.2", "27B5040c"),
                                     ("Xcode_27.2_Release_Candidate.app", "27.2", "27B48"),
                                     ("Xcode_27.3_RC.app", "27.3", "27C40"),
                                     ("Xcode-beta.app", "28.0", "28A5001a")),
                         "Xcode_27.1.app")

    # Following a symlink to a beta (Xcode.app -> a beta) fails this test.
    def test_a_link_to_a_beta_is_a_beta(self):
        self.assertEqual(self.choose(("Xcode_27.1.app", "27.1", "27A9275"),
                                     ("Xcode_27.2_beta.app", "27.2", "27B5010a"),
                                     "Xcode.app -> Xcode_27.2_beta.app"),
                         "Xcode_27.1.app")

    # Trusting the name alone, when Apple lists the build only as a release
    # candidate, fails this test.
    def test_skips_a_build_apple_lists_only_as_a_prerelease(self):
        self.assertEqual(self.choose(("Xcode_27.1.app", "27.1", "27A9275"),
                                     ("Xcode_27.2.app", "27.2", "27B48"),
                                     feed_text=APPLE_FEED),
                         "Xcode_27.1.app")

    # Apple often releases a release candidate's build unchanged. Treating it
    # as a prerelease once Apple lists it as a release fails this test.
    def test_a_release_candidate_apple_then_released_is_a_release(self):
        released = feed("Xcode 27.2 (27B48)") + APPLE_FEED
        self.assertEqual(self.choose(("Xcode_27.1.app", "27.1", "27A9275"),
                                     ("Xcode_27.2.app", "27.2", "27B48"),
                                     feed_text=released),
                         "Xcode_27.2.app")

    # Reporting success with nothing to build with fails this test.
    def test_nothing_installed(self):
        self.assertIsNone(self.choose(("Xcode_27.2_beta.app", "27.2", "27B5010a")))


class CheckTests(unittest.TestCase):
    """The comparison with Apple's newest release. It warns, never fails."""

    def check(self, xcodebuild_output, feed_text):
        return select_xcode.compare(select_xcode.active_xcode(xcodebuild_output),
                                    feed_text)

    # Reading a beta or release candidate ("27.2 RC") as Apple's newest
    # release fails this test.
    def test_newest_release_ignores_betas_and_release_candidates(self):
        self.assertEqual(select_xcode.newest_release(APPLE_FEED),
                         ((27, 1), "27.1", "27A9275"))

    # Treating "Xcode 27" and "Xcode 27.0" as different versions fails this.
    def test_whole_number_versions_compare_equal(self):
        self.assertEqual(select_xcode.version("27"), select_xcode.version("27.0.0"))

    # Staying quiet when CI is behind Apple fails this test.
    def test_warns_when_ci_is_behind(self):
        level, message = self.check("Xcode 26.6\nBuild version 17F113\n", APPLE_FEED)
        self.assertEqual(level, "warning")
        self.assertIn("Xcode 26.6 (17F113)", message)
        self.assertIn("Xcode 27.1 (27A9275)", message)

    def test_quiet_notice_when_ci_matches(self):
        level, message = self.check("Xcode 27.1\nBuild version 27A9275\n", APPLE_FEED)
        self.assertEqual(level, "notice")
        self.assertIn("Xcode 27.1 (27A9275)", message)

    # Accepting a build Apple lists as a beta or RC fails this test.
    def test_warns_when_ci_uses_a_prerelease(self):
        level, message = self.check("Xcode 27.2\nBuild version 27B48\n", APPLE_FEED)
        self.assertEqual(level, "warning")
        self.assertIn("beta or release candidate", message)

    # Warning about a release candidate's build after Apple released it
    # unchanged fails this test.
    def test_a_released_candidate_build_is_quiet(self):
        released = feed("Xcode 27.2 (27B48)") + APPLE_FEED
        level, message = self.check("Xcode 27.2\nBuild version 27B48\n", released)
        self.assertEqual(level, "notice", message)

    # Treating an unreadable feed as "up to date" fails this test.
    def test_warns_when_the_feed_cannot_be_read(self):
        level, message = self.check("Xcode 27.1\nBuild version 27A9275\n", None)
        self.assertEqual(level, "warning")
        self.assertIn("Could not read", message)
        level, message = self.check("Xcode 27.1\nBuild version 27A9275\n", "<html>")
        self.assertEqual(level, "warning")


if __name__ == "__main__":
    unittest.main()
