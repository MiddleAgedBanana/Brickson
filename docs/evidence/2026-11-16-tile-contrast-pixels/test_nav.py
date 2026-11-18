"""Checks that no step nav.py is given can reach AXe as an option.

Run: python3 -I docs/evidence/2026-11-16-tile-contrast-pixels/test_nav.py
SonarCloud found (pull request #119) that an "@type:" step lost its prefix
after the dash check, so "@type:--udid=X" handed AXe "--udid=X" as an
option. Passing typed text as an argument again fails
`testTypedTextNeverBecomesAnArgument`.
"""
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("nav", os.path.join(HERE, "nav.py"))
nav = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nav)

UDID = "AD7452D4-A1D2-4225-B94E-EE6049D0C948"


class StepTests(unittest.TestCase):
    def testTypedTextNeverBecomesAnArgument(self):
        for text in ("--udid=X", "-h", "Open the window", "--stdin"):
            commands = nav.step_commands("@type:" + text, UDID)
            self.assertEqual(commands, [(["axe", "type", "--stdin", "--udid", UDID], text)])

    def testLabelsAndIdentifiersAreValuesOfTheirOption(self):
        self.assertEqual(nav.step_commands("Settings", UDID),
                         [(["axe", "tap", "--label=Settings", "--udid", UDID], None)])
        self.assertEqual(nav.step_commands("@id:--udid=X", UDID),
                         [(["axe", "tap", "--id=--udid=X", "--udid", UDID], None)])
        until = nav.step_commands("@until:Normal speed", UDID)
        self.assertEqual(until[0], (["axe", "gesture", "scroll-up", "--until-label=Normal speed", "--udid", UDID], None))

    def testEveryArgumentAStepAddsIsTheValueOfAnOption(self):
        for step in ("Settings", "@id:x", "@until:y", "@type:--udid=X", "@scroll", "Family Setup"):
            for arguments, _ in nav.step_commands(step, UDID):
                for argument in arguments:
                    known = argument in ("axe", "tap", "type", "gesture", "scroll-up", "--stdin",
                                         "--udid", UDID, "--distance", "0.25")
                    self.assertTrue(known or argument.startswith(("--label=", "--id=", "--until-label=")),
                                    f"{step!r} puts {argument!r} in AXe's arguments")

    def testDashLedOrEmptyStepsAreRefused(self):
        for step in ("", "-x", "--udid=X", "@id:", "@type:", "@until:", "x" * 200):
            self.assertFalse(nav.valid_step(step), step)
        for step in ("Settings", "@type:--udid=X", "@scroll", "@id:libraryCategory0"):
            self.assertTrue(nav.valid_step(step), step)


if __name__ == "__main__":
    unittest.main()
