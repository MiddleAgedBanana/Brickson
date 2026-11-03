#!/usr/bin/env bash
# TEMPORARY probe, 2026-11-03, removed by the next commit: what loads the
# iPad simulator on GitHub's Mac machines. Phase 1 boots the iPad, builds,
# and launches the app every minute for 17 minutes after boot, watching the
# simulator's processes. Phase 2 erases it, boots it again and runs the
# whole iPad UI suite with the lock-screen wallpaper extensions paused.
# Everything it writes lands in build/TestResults/probe, which the
# workflow uploads.
set -uo pipefail
cd "$(dirname "$0")/.."
out=build/TestResults/probe
mkdir -p "$out"
derived=build/DerivedData
xcodegen generate --quiet
oldest="$(xcodebuild -project Brickson.xcodeproj -target Brickson -showBuildSettings -json |
    /usr/bin/python3 -c 'import json,sys; t=sys.stdin.read(); print(json.loads(t[t.find("["):])[0]["buildSettings"]["IPHONEOS_DEPLOYMENT_TARGET"])')"
newest="$(xcrun --sdk iphonesimulator --show-sdk-version)"
udid="$(xcrun simctl list devices available --json |
    /usr/bin/python3 -I scripts/choose-simulator.py --family ipad --min "$oldest" --max "$newest")"
echo "probe: iPad $udid, deployment target $oldest, SDK $newest"
sysctl -n hw.ncpu hw.memsize machdep.cpu.brand_string 2>/dev/null | tee "$out/machine.txt"

posterboard_log() {
    local name="$1"
    xcrun simctl spawn "$udid" log show --last 30m --style compact \
        --predicate 'process CONTAINS[c] "poster" OR subsystem CONTAINS[c] "poster" OR (process == "dasd" AND eventMessage CONTAINS[c] "poster")' \
        > "$out/$name-posterboard.log" 2>&1 &
    local pid=$!
    ( sleep 180; kill "$pid" 2>/dev/null ) &
    wait "$pid" 2>/dev/null
    echo "probe: $name log lines $(wc -l < "$out/$name-posterboard.log")"
    xcrun simctl spawn "$udid" launchctl list > "$out/$name-launchctl.txt" 2>&1 || true
}

keyboard() {
    xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false
    xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
}

app="$derived/Build/Products/Debug-iphonesimulator/Brickson.app"

# Phase 1: no pausing, no XCTest.
xcrun simctl shutdown "$udid" 2>/dev/null
xcrun simctl boot "$udid"
booted=$SECONDS
date -u +"probe: phase 1 boot %H:%M:%S"
xcrun simctl bootstatus "$udid" -b >/dev/null
date -u +"probe: phase 1 booted %H:%M:%S"
/usr/bin/python3 -I scripts/simulator-load.py watch --udid "$udid" --out "$out/phase1-load.txt" &
watcher=$!
keyboard
xcodebuild -project Brickson.xcodeproj -scheme Brickson-UI -destination "id=$udid" \
    -derivedDataPath "$derived" -quiet build-for-testing > "$out/build.txt" 2>&1
date -u +"probe: built %H:%M:%S (status $?)"
xcrun simctl install "$udid" "$app"
while [ $((SECONDS - booted)) -lt 1020 ]; do
    xcrun simctl launch "$udid" family.avery.brickson --fresh-test-storage >/dev/null
    sleep 50
    xcrun simctl terminate "$udid" family.avery.brickson >/dev/null 2>&1
    sleep 5
done
kill "$watcher"; wait "$watcher"
date -u +"probe: phase 1 done %H:%M:%S"
posterboard_log phase1
xcrun simctl shutdown "$udid"

# Phase 2: a fresh device, the posters paused, the whole iPad UI suite.
xcrun simctl erase "$udid"
xcrun simctl boot "$udid"
date -u +"probe: phase 2 boot %H:%M:%S"
xcrun simctl bootstatus "$udid" -b >/dev/null
date -u +"probe: phase 2 booted %H:%M:%S"
/usr/bin/python3 -I scripts/simulator-load.py watch --udid "$udid" --out "$out/phase2-load.txt" --pause-posters &
watcher=$!
keyboard
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" family.avery.brickson --fresh-test-storage >/dev/null
sleep 15
xcrun simctl terminate "$udid" family.avery.brickson >/dev/null 2>&1
xcodebuild -project Brickson.xcodeproj -scheme Brickson-UI -destination "id=$udid" \
    -derivedDataPath "$derived" -resultBundlePath build/TestResults/ui-ipad.xcresult \
    -collect-test-diagnostics never test-without-building > "$out/phase2-xcodebuild.txt" 2>&1
date -u +"probe: phase 2 tests done %H:%M:%S (status $?)"
kill "$watcher"; wait "$watcher"
posterboard_log phase2
xcrun simctl shutdown "$udid"
grep -E "Executed [0-9]+ tests" "$out/phase2-xcodebuild.txt" | tail -1
tail -25 "$out/phase1-load.txt"
tail -25 "$out/phase2-load.txt"
exit 0
