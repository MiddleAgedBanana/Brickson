### Hosted checks on 2026-10-25

Tests run [40224730784](https://github.com/MiddleAgedBanana/Brickson/actions/runs/40224730784), head `132263011a870645e2c63903a17d22065702d703`, completed with **Unit PASS and UI FAIL**. The UI job failed with exit 65; it was not canceled, and its result upload succeeded.

| Check | Total | Passed | Failed | Skipped | Expected failures |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unit | 769 | 760 | 0 | 1 | 8 |
| UI — iPad | 51 | 45 | 1 | 2 | 3 |
| UI — iPhone | 51 | 43 | 0 | 6 | 2 |

The unit catalog check passed; hosted unit coverage was 70.4% (6,876 of 9,769 lines). This dated run used Xcode 27.1 (27A9275), XcodeGen 2.46.0 and the selected iPad Pro 13-inch (M5) and iPhone 17 simulators on iOS 27.0.

The iPad's first `GetAttentionOnHomeTests/testTheAlarmStartsAndStopsAtDefaultText()` failed after 81.903 seconds at `LaunchHelpers.swift:93`, before any alarm action. Retained logs show an app-foreground notification, a 60.032-second automation-session timeout, then failed AX idle monitoring and three Yes-button snapshot requests ending in `Error getting main window kAXErrorServerNotFound`.

Artifact `12612143704` retains video showing SpringBoard early, then a blank white Brickson canvas with no Home controls in the reviewed 15-second, 30-second and final media samples. These are frames decoded from the recording. Its reported duration is 39.667 seconds (174 frames; final decoded PTS 35.788 seconds), so it does not establish continuous blankness throughout the 81.903-second test or an exact image at the failure instant.

App and runner stdout were retained, but no app crash report, hang sample or symbolicated app-thread stack was recovered. The issue's 107 unsymbolicated addresses are failure-reporting source context, not a sampled app thread. The script requests `-collect-test-diagnostics never`; absent diagnostics do not establish that no crash or hang occurred. This confirms a blank-canvas startup symptom together with automation/AX failure; it does not establish the cause or justify a product-code fix. The UI gate remains failed.

[15-second media sample](blank-startup-15s.png), [final media frame](blank-startup-final.png), and [curated provenance](results.json). The reviewed 30-second frame is byte-identical to the 15-second sample.
