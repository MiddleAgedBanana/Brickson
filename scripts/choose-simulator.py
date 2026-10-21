#!/usr/bin/env python3
"""Chooses the simulator scripts/test.sh runs on. Standard library only.

Reads `xcrun simctl list devices available --json` on standard input and
prints the chosen simulator's id. A line saying which one it chose, and why,
goes to standard error so it reaches the log.

    choose-simulator.py --family ipad|iphone [--min 26.0] [--max 26.5]
    choose-simulator.py --destination 'platform=iOS Simulator,name=iPhone 17'

`--family` picks a device by its type, never its name: a simulator can be
renamed ("Brickson Website Checks" is an iPad Pro 13-inch by type), and on
some Macs every simulator has a custom name. `--min` is the app's
deployment target and `--max` the iOS SDK of the Xcode in use: Xcode cannot
run tests on a runtime newer than its own SDK, and the app cannot install on
one older than its deployment target.

`--destination` finds the simulator an xcodebuild destination names, by
`id=` or by `name=` (with `OS=` if given, otherwise the newest runtime), so
the script waits for the same device the build uses. It exits 3 when the
destination is not one simulator (a real device, `generic/platform=...`).

Exit status: 0 chosen, 1 nothing suitable is installed, 2 bad arguments,
3 the destination is not a simulator this script can resolve.
"""
import argparse
import json
import re
import sys

NOT_A_SIMULATOR = 3

# What each family prefers, by device type identifier. The 13-inch iPad Pro
# is the largest screen and the reference app's primary device; the
# newest standard iPhone is the most common phone shape.
FAMILIES = {
    "ipad": "com.apple.CoreSimulator.SimDeviceType.iPad",
    "iphone": "com.apple.CoreSimulator.SimDeviceType.iPhone",
}
DISPLAY_NAMES = {"ipad": "iPad", "iphone": "iPhone"}


def version_tuple(text):
    """`26.5` or `26.5.1` as a comparable tuple; None if it isn't a version."""
    match = re.fullmatch(r"(\d+)(?:\.(\d+))?(?:\.(\d+))?", text.strip())
    if not match:
        return None
    return tuple(int(part or 0) for part in match.groups())


def runtime_version(runtime):
    """The iOS version of a runtime key such as
    `com.apple.CoreSimulator.SimRuntime.iOS-26-5`; None for other platforms."""
    match = re.search(r"\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    if not match:
        return None
    return tuple(int(part or 0) for part in match.groups())


def describe_version(version):
    major, minor, patch = version
    return f"{major}.{minor}" + (f".{patch}" if patch else "")


def ios_devices(listing):
    """Every available iOS simulator as (device, runtime version)."""
    for runtime, entries in listing.get("devices", {}).items():
        version = runtime_version(runtime)
        if version is None:
            continue
        for device in entries:
            if device.get("isAvailable", True):
                yield device, version


def rank(device, version, family):
    """Higher is better: the preferred model, its newest generation, the
    newest runtime, then the udid so the choice is stable (names are free
    text, and "M10" sorts before "M4")."""
    kind = device.get("deviceTypeIdentifier", "").rsplit(".", 1)[-1]
    if family == "ipad":
        preferred = kind.startswith("iPad-Pro-13-inch")
        chip = re.search(r"-M(\d+)", kind)
        generation = int(chip.group(1)) if chip else 0
    else:
        # The standard model ("iPhone-17"), not Pro, Max, Air or e.
        standard = re.fullmatch(r"iPhone-(\d+)", kind)
        preferred = standard is not None
        generation = int(standard.group(1)) if standard else 0
    return (preferred, generation, version, device["udid"])


def choose_by_family(listing, family, minimum, maximum):
    prefix = FAMILIES[family]
    candidates = [
        (device, version)
        for device, version in ios_devices(listing)
        if device.get("deviceTypeIdentifier", "").startswith(prefix + "-")
        and (minimum is None or version >= minimum)
        and (maximum is None or version <= maximum)
    ]
    if not candidates:
        wanted = f"{DISPLAY_NAMES[family]} simulator"
        if minimum is not None and maximum is not None:
            wanted += f" with iOS {describe_version(minimum)} to {describe_version(maximum)}"
        elif minimum is not None:
            wanted += f" with iOS {describe_version(minimum)} or later"
        elif maximum is not None:
            wanted += f" with iOS {describe_version(maximum)} or earlier"
        sys.exit(f"No {wanted} is installed. Add one in Xcode: Settings, Components "
                 "for the runtime, then Window, Devices and Simulators.")
    device, version = max(candidates, key=lambda item: rank(*item, family))
    return device, version


def parse_destination(text):
    fields = {}
    for part in text.split(","):
        key, separator, value = part.partition("=")
        if separator:
            fields[key.strip()] = value.strip()
    return fields


def choose_by_destination(listing, destination):
    fields = parse_destination(destination)
    # Without a platform, xcodebuild also accepts a real device's id or
    # name; only an explicit simulator destination that matches nothing is
    # an error here.
    explicit = fields.get("platform") == "iOS Simulator"
    if "platform" in fields and not explicit:
        return None
    devices = list(ios_devices(listing))
    if "id" in fields:
        for device, version in devices:
            if device["udid"] == fields["id"]:
                return device, version
        if explicit:
            sys.exit(f"No available iOS simulator has the id {fields['id']}.")
        return None
    if "name" in fields:
        named = [(device, version) for device, version in devices
                 if device["name"] == fields["name"]]
        wanted_os = fields.get("OS", "latest")
        if wanted_os != "latest":
            # "26.5" matches 26.5 and 26.5.1; "26" matches every 26.x.
            parts = version_tuple(wanted_os)
            given = len(wanted_os.split("."))
            named = [(device, version) for device, version in named
                     if parts is not None and version[:given] == parts[:given]]
        if not named:
            if not explicit:
                return None
            sys.exit(f"No available iOS simulator is named \"{fields['name']}\""
                     + (f" with iOS {wanted_os}" if wanted_os != "latest" else "") + ".")
        # The newest runtime, as xcodebuild does for a name without OS.
        return max(named, key=lambda item: (item[1], item[0]["udid"]))
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--family", choices=sorted(FAMILIES))
    group.add_argument("--destination")
    parser.add_argument("--min", help="oldest iOS version allowed, e.g. 26.0")
    parser.add_argument("--max", help="newest iOS version allowed, e.g. 26.5")
    arguments = parser.parse_args()

    limits = {}
    for name in ("min", "max"):
        text = getattr(arguments, name)
        if text:
            limits[name] = version_tuple(text)
            if limits[name] is None:
                parser.error(f"--{name} must be a version such as 26.5, not {text!r}")

    listing = json.load(sys.stdin)
    if arguments.destination is not None:
        chosen = choose_by_destination(listing, arguments.destination)
        if chosen is None:
            return NOT_A_SIMULATOR
        reason = "named by DESTINATION"
    else:
        chosen = choose_by_family(listing, arguments.family, limits.get("min"), limits.get("max"))
        reason = f"newest {arguments.family} by device type"
    device, version = chosen
    kind = device.get("deviceTypeIdentifier", "unknown type").rsplit(".", 1)[-1]
    print(device["udid"])
    print(f"Simulator: {device['name']} ({kind}), iOS {describe_version(version)}, "
          f"id {device['udid']} ({reason})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
