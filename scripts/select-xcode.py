#!/usr/bin/env python3
"""Keeps CI on Apple's current Xcode (docs/DECISIONS.md, "Build with Apple's
current Xcode").

    python3 scripts/select-xcode.py choose   prints the newest released Xcode
                                             installed in /Applications
    python3 scripts/select-xcode.py check    compares the Xcode in use with
                                             Apple's newest release

No Xcode version is written here or in the workflow. `choose` takes the
newest release on the machine and never a beta or release candidate, which
App Store Connect does not accept builds from. Apple's releases feed decides
by build number, and a version newer than the feed's newest release is not
a release; only another build the feed does not list goes by the app's
name, because GitHub keeps a release candidate's name on a build Apple then
released unchanged (Xcode_27.1_Release_Candidate.app held the released 27.1
on 2026-10-21). When the feed cannot decide, `choose` warns on the run.
`check` reads the same feed and warns on the run when the Xcode in use is
behind Apple or newer than its newest release; it never fails the run,
because GitHub adds a new Xcode to its machines some days after Apple
releases it.
Standard library only.
"""
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

FEED = "https://developer.apple.com/news/releases/rss/releases.rss"

# Betas and release candidates, as GitHub and Apple name them: Xcode-beta.app,
# Xcode_27.2_beta_3.app, Xcode_27.2_Release_Candidate.app, Xcode_27.3_RC.app.
PRERELEASE_NAME = re.compile(r"beta|release[ _-]?candidate|[ _-]rc(?:[ _-]?\d+)?\.app$",
                             re.IGNORECASE)
FEED_TITLE = re.compile(r"<title>\s*Xcode (\d+(?:\.\d+)*)( [^(<]*?)? \((\w+)\)\s*</title>")


def version(text):
    """"27" and "27.0.0" compare equal; "27.10" is newer than "27.9"."""
    parts = [int(part) for part in text.split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def describe(app):
    plist = Path(app, "Contents", "version.plist")
    with open(plist, "rb") as file:
        info = plistlib.load(file)
    return info["CFBundleShortVersionString"], info["ProductBuildVersion"]


def choose(applications=Path("/Applications"), feed_text=None):
    """The newest released Xcode in `applications`, as the path of the app
    itself (not a link to it), or None. Apple's feed decides whether a build
    is a release, and a version newer than its newest release is not one;
    any other build it does not list, or every build when the feed could not
    be read, goes by the names of the app and of its links."""
    apps = {}
    for app in sorted(applications.glob("Xcode*.app")):
        apps.setdefault(app.resolve(), []).append(app)
    listed = list(releases(feed_text))
    released = {build for _, _, build, prerelease in listed if not prerelease}
    unreleased = prerelease_builds(feed_text)
    newest = newest_release(feed_text)
    best = None
    for real, names in sorted(apps.items()):
        shown = ", ".join(str(name) for name in names if name != real)
        shown = f"{real} (also {shown})" if shown else str(real)
        try:
            number, build = describe(real)
        except (OSError, KeyError, plistlib.InvalidFileException) as error:
            print(f"  skipped, unreadable ({error}): {shown}", file=sys.stderr)
            continue
        if build in unreleased:
            print(f"  skipped, Apple lists {build} as a prerelease: {shown}",
                  file=sys.stderr)
            continue
        if (build not in released and newest is not None
                and version(number) > newest[0]):
            print(f"  skipped, newer than Apple's newest release ({newest[1]}): "
                  f"{shown}", file=sys.stderr)
            continue
        if build not in released and any(PRERELEASE_NAME.search(name.name)
                                         for name in [real, *names]):
            print(f"  skipped, named as a prerelease: {shown}", file=sys.stderr)
            continue
        print(f"  Xcode {number} ({build}): {shown}", file=sys.stderr)
        rank = (version(number), build)
        if best is None or rank > best[0]:
            best = (rank, real)
    return best[1] if best else None


def active_xcode(xcodebuild_output):
    """(version, build) from `xcodebuild -version`."""
    number = re.search(r"^Xcode (\S+)", xcodebuild_output, re.MULTILINE)
    build = re.search(r"^Build version (\S+)", xcodebuild_output, re.MULTILINE)
    return (number.group(1) if number else "unknown", build.group(1) if build else "unknown")


def releases(feed_text):
    """Every Xcode in Apple's feed: (version, number, build, is_prerelease)."""
    for match in FEED_TITLE.finditer(feed_text or ""):
        number, suffix, build = match.groups()
        yield version(number), number, build, bool(suffix and suffix.strip())


def prerelease_builds(feed_text):
    """Builds Apple lists only as a beta or release candidate. A candidate
    Apple then released unchanged is listed as a release too, and is one."""
    listed = list(releases(feed_text))
    return ({build for _, _, build, prerelease in listed if prerelease}
            - {build for _, _, build, prerelease in listed if not prerelease})


def newest_release(feed_text):
    found = [(rank, number, build) for rank, number, build, prerelease
             in releases(feed_text) if not prerelease]
    return max(found) if found else None


def compare(active, feed_text):
    """("notice" or "warning", message) about the Xcode in use."""
    number, build = active
    using = f"Xcode {number} ({build})"
    if build in prerelease_builds(feed_text):
        return "warning", (f"CI builds with {using}, which Apple lists as a beta or "
                           "release candidate. Builds for the App Store need a release.")
    newest = newest_release(feed_text)
    if newest is None:
        problem = ("could not be read" if feed_text is None
                   else "was read but lists no Xcode release")
        return "warning", (f"CI builds with {using}. Apple's releases feed ({FEED}) "
                           f"{problem}; check Apple's newest Xcode by hand.")
    newest_version, newest_number, newest_build = newest
    latest = f"Xcode {newest_number} ({newest_build})"
    if number != "unknown" and version(number) > newest_version:
        return "warning", (f"CI builds with {using}, newer than Apple's newest "
                           f"release, {latest}, so it is a beta or release "
                           "candidate. Builds for the App Store need a release.")
    # Apple sometimes ships a newer build under the same version number, and
    # a build that cannot be read is treated as behind.
    if (number == "unknown" or version(number) < newest_version
            or (version(number) == newest_version and build != newest_build)):
        return "warning", (f"CI builds with {using}, but Apple's newest release is "
                           f"{latest}. Either GitHub's Mac machine does not have it "
                           "yet, or the runner in .github/workflows/tests.yml needs a "
                           "newer image, or the \"Use the newest released Xcode\" step "
                           "skipped it (its log lists every Xcode installed and why "
                           "each was skipped). docs/DECISIONS.md, \"Build with Apple's "
                           'current Xcode".')
    return "notice", f"CI builds with {using}. Apple's newest release is {latest}."


def fallback_warning(feed_text):
    """The warning `choose` puts on the run when Apple's feed cannot decide,
    or None. Without a release in the feed, a released Xcode that GitHub
    still names as a release candidate is skipped, and CI may build with an
    older one; every job runs `choose`, so every job says so."""
    if newest_release(feed_text) is not None:
        return None
    problem = ("could not be read" if feed_text is None
               else "was read but lists no Xcode release")
    return (f"Apple's releases feed {problem}, so the Xcode was chosen by app "
            "names only. A released Xcode that GitHub names as a release "
            "candidate was skipped, if there is one; the step log lists them.")


def annotate(level, message, stream=sys.stdout):
    """A GitHub annotation on the run, also written to the job's summary.
    GitHub reads workflow commands from both output streams; `choose` uses
    stderr because its stdout is the path the workflow switches to."""
    print(f"::{level} title=Xcode::{message}", file=stream)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as file:
            file.write(f"{'⚠️ ' if level == 'warning' else ''}{message}\n")


def fetch_feed():
    """Apple's releases feed, or None when it cannot be read."""
    fetched = subprocess.run(["curl", "-fsSL", "--max-time", "30", "--retry", "2", FEED],
                             capture_output=True, text=True)
    return fetched.stdout if fetched.returncode == 0 else None


def check():
    output = subprocess.run(["xcodebuild", "-version"], capture_output=True,
                            text=True).stdout
    annotate(*compare(active_xcode(output), fetch_feed()))


def main(arguments):
    if arguments == ["choose"]:
        print("Installed Xcode versions:", file=sys.stderr)
        feed_text = fetch_feed()
        app = choose(feed_text=feed_text)
        warning = fallback_warning(feed_text)
        if warning:
            annotate("warning", warning, sys.stderr)
        if app is None:
            sys.exit("No released Xcode is installed in /Applications.")
        print(app)
    elif arguments == ["check"]:
        check()
    else:
        sys.exit("Use: python3 scripts/select-xcode.py choose|check")


if __name__ == "__main__":
    main(sys.argv[1:])
