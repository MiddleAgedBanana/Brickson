"""Checks review.py's own logic without a simulator: python3 -I test_review.py"""
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("review", os.path.join(HERE, "review.py"))
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)

UDID = "4A59A6F3-B823-4433-B198-803681309452"


class Readout(unittest.TestCase):
    # The words must be the app's (DesignReviewReadoutLine, pinned in
    # DesignReviewTests): a capture is refused unless they match.
    def test_the_plain_readout_is_the_apps(self):
        self.assertEqual(" ".join(review.expected_readout(review.PLAIN)),
                         "scheme=light contrast=standard transparency=standard borders=off "
                         "differentiate=off bold=off text=large window=active")

    def test_each_appearance_changes_its_own_words(self):
        plain = set(review.expected_readout(review.PLAIN))
        for name in review.APPEARANCES:
            words = set(review.expected_readout(review.settings_for(name)))
            changed = words - plain
            self.assertEqual(len(changed), 0 if name == "light" else (2 if name == "dark-increase-contrast" else 1), name)

    def test_a_readout_missing_a_setting_is_refused(self):
        settings = review.settings_for("bold-text")
        good = " ".join(review.expected_readout(settings)) + " space=402x778"
        self.assertTrue(review.readout_matches(good, settings))
        self.assertFalse(review.readout_matches(good.replace("bold=on", "bold=off"), settings))
        self.assertFalse(review.readout_matches(None, settings))
        self.assertFalse(review.readout_matches(good, settings, active=False))

    def test_the_inactive_window_must_say_so(self):
        settings = review.settings_for("inactive-dark")
        words = review.expected_readout(settings, active=False)
        self.assertIn("window=inactive", words)
        self.assertIn("scheme=dark", words)


class Commands(unittest.TestCase):
    # Every option AXe, devicectl or simctl gets is one of this script's
    # own words or the UDID; nothing else can start with a dash.
    def test_settings_are_set_with_known_words_only(self):
        for name in list(review.APPEARANCES) + list(review.INACTIVE):
            for command in review.setting_commands(UDID, review.settings_for(name)):
                for argument in command:
                    self.assertTrue(argument == UDID or argument in KNOWN, (name, argument))

    def test_the_largest_text_turns_larger_sizes_on(self):
        command = review.setting_commands(UDID, review.settings_for("largest-text"))[0]
        self.assertEqual(command[command.index("--text-size") + 1], "accessibility-extra-extra-extra-large")
        self.assertEqual(command[command.index("--larger-accessibility-sizes") + 1], "on")

    def test_a_malformed_udid_is_refused(self):
        for udid in ("--udid=X", "4a59a6f3-b823-4433-b198-803681309452", ""):
            with self.assertRaises(SystemExit):
                review.main(["review.py", "capture", udid, "iphone", "/tmp/x"])
        with self.assertRaises(SystemExit):
            review.main(["review.py", "capture", UDID, "ipod", "/tmp/x"])
        with self.assertRaises(SystemExit):
            review.main(["review.py", "capture", UDID, "iphone", "/tmp/x", "sepia"])
        with self.assertRaises(SystemExit):
            review.main(["review.py", "inactive", UDID, "/tmp/x", "inactive-light", "-5", "800"])


KNOWN = {
    "xcrun", "devicectl", "device", "settings", "appearance", "--device", "--mode", "light", "dark",
    "--increase-contrast", "--reduce-transparency", "--show-borders", "--text-size", "large",
    "accessibility-extra-extra-extra-large", "--larger-accessibility-sizes", "on", "off",
    "simctl", "spawn", "defaults", "write", "com.apple.Accessibility", "EnhancedTextLegibilityEnabled",
    "DifferentiateWithoutColor", "-bool", "true", "false",
}


class Sheets(unittest.TestCase):
    def test_every_expected_specimen_has_a_place_and_a_label(self):
        self.assertEqual(len(review.EXPECTED), 43)
        self.assertEqual(len(set(review.EXPECTED)), 43)
        keys = sorted(review.EXPECTED, key=review.order_key)
        self.assertEqual(keys[0], "review.colour.AccentColor")
        self.assertEqual(keys[-1], "review.settings.ControlFill.off")
        for identifier in review.EXPECTED:
            self.assertTrue(review.label_of(identifier))
            self.assertTrue(any(identifier.startswith(p) for _, _, prefixes in review.SECTIONS for p in prefixes))

    def test_spacing_sorts_by_size(self):
        steps = [i for i in sorted(review.EXPECTED, key=review.order_key) if ".spacing." in i]
        self.assertEqual([int(i.split(".")[-1]) for i in steps], [2, 4, 6, 8, 12, 16, 24])

    def test_targets_follow_invariant_six(self):
        reading = {"wordsOnFill": 4.49, "edgeOnPage": 2.99, "words": "#FFFFFF", "fill": "#1A7BFF", "edge": "#1A7BFF", "page": "#000000"}
        lines, fails = review.caption("fill", reading)
        self.assertTrue(fails)
        self.assertIn("under 4.5", lines[0])
        self.assertIn("under 3.0", lines[1])
        lines, fails = review.caption("fill", dict(reading, wordsOnFill=4.5, edgeOnPage=3.0))
        self.assertFalse(fails)
        # Words on the screen have no edge of their own; a shape no words.
        self.assertEqual([v[0] for v in review.verdicts("ink", reading)], ["words"])
        self.assertEqual([v[0] for v in review.verdicts("shape", reading)], ["edge"])
        self.assertEqual(review.verdicts("fill", None), [])

    def test_a_crop_stays_inside_its_capture(self):
        crop = review.crop({"x": 2, "y": 2, "width": 50, "height": 20}, 3, (300, 300))
        self.assertEqual((crop["x"], crop["y"]), (0, 0))
        crop = review.crop({"x": 80, "y": 90, "width": 20, "height": 10}, 3, (300, 300))
        self.assertEqual((crop["x"] + crop["width"], crop["y"] + crop["height"]), (300, 300))
        # The specimen and PADDING points of the screen round it, at the
        # capture's own pixels.
        pad = review.PADDING
        crop = review.crop({"x": 20, "y": 20, "width": 20, "height": 10}, 2, (300, 300))
        self.assertEqual(crop, {"x": (20 - pad) * 2, "y": (20 - pad) * 2, "width": (20 + 2 * pad) * 2, "height": (10 + 2 * pad) * 2})


if __name__ == "__main__":
    unittest.main()
