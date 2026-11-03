#!/usr/bin/env python3
"""Watches one simulator's processes while its tests run, and writes down
which of them use the machine's processors.

    simulator-load.py watch --udid <udid> --out <file> [--pause-posters]

Every few seconds it reads the Mac's process list, finds the processes the
simulator runs (everything started under that device's launchd_sim), and
writes one line: the time, how much processor time the simulator and the
whole Mac used since the last line, the Mac's load, and the simulator's
busiest processes. When it is stopped (SIGTERM or SIGINT) it writes the
processes that used the most time over the whole run.

With --pause-posters it also pauses (SIGSTOP) the simulator's lock-screen
wallpaper extensions as they start: processes whose name ends in "Poster",
"PosterExtension" or "PosterProvider" (EmojiPosterExtension, AegirPoster,
PhotosPosterProvider and the like; never PosterBoard itself). On GitHub's
Mac machines those extensions render hundreds of lock-screen pictures a
few minutes after the simulator starts, which leaves the app under test
with almost no processor time for a minute or more
(docs/log/2026-11-03-ui-test-stall.md). The tests never show the lock
screen. A paused process is left paused; the simulator is shut down after
its run.

Only the processes of the one simulator named by --udid are read or
paused, and only on a Mac: the process list comes from /bin/ps.
"""
import argparse
import os
import re
import signal
import subprocess
import sys
import time

# Names of the lock-screen wallpaper extensions; PosterBoard does not match.
POSTER = re.compile(r"Poster(Extension|Provider)?$")

INTERVAL = 5.0


def cpu_seconds(text):
    """ps's TIME column, [[dd-]hh:]mm:ss.ss, in seconds."""
    days, _, clock = text.rpartition("-")
    seconds = 0.0
    for part in clock.split(":"):
        seconds = seconds * 60 + float(part)
    return seconds + (int(days) * 86400 if days else 0)


def read_processes(ps="/bin/ps"):
    """Every process on the Mac: pid -> (ppid, state, cpu seconds, path).

    `comm` is the executable's path, which may hold spaces (a simulator
    runtime is "iOS 27.0.simruntime"), so it is the last column."""
    output = subprocess.run([ps, "-axww", "-o", "pid=,ppid=,stat=,time=,comm="],
                            capture_output=True, text=True, check=True).stdout
    processes = {}
    for line in output.splitlines():
        parts = line.split(None, 4)
        if len(parts) < 5:
            continue
        try:
            processes[int(parts[0])] = (int(parts[1]), parts[2], cpu_seconds(parts[3]), parts[4])
        except ValueError:
            continue
    return processes


def launchd_sim(udid, ps="/bin/ps"):
    """The pid of the simulator's own launchd, whose arguments name the
    device's folder; None while the device is not running."""
    output = subprocess.run([ps, "-axww", "-o", "pid=,args="],
                            capture_output=True, text=True, check=True).stdout
    for line in output.splitlines():
        pid, _, arguments = line.strip().partition(" ")
        if "launchd_sim" in arguments and f"/{udid}/" in arguments:
            return int(pid)
    return None


def descendants(root, processes):
    """root and every process started under it."""
    children = {}
    for pid, (ppid, *_rest) in processes.items():
        children.setdefault(ppid, []).append(pid)
    found, waiting = set(), [root]
    while waiting:
        pid = waiting.pop()
        if pid in found:
            continue
        found.add(pid)
        waiting.extend(children.get(pid, []))
    return found


def name_of(path):
    return os.path.basename(path.rstrip("/")) or path


def is_poster_extension(path):
    return bool(POSTER.search(name_of(path)))


class Watch:
    def __init__(self, udid, out, pause_posters, ps="/bin/ps", clock=time.monotonic, kill=os.kill):
        self.udid, self.out, self.pause_posters = udid, out, pause_posters
        self.ps, self.clock, self.kill = ps, clock, kill
        self.before, self.at = None, None
        self.totals = {}  # name -> cpu seconds used while watched
        self.paused = set()

    def write(self, line):
        self.out.write(line + "\n")
        self.out.flush()

    def sample(self):
        root = launchd_sim(self.udid, self.ps)
        processes = read_processes(self.ps)
        now = self.clock()
        stamp = time.strftime("%H:%M:%S", time.gmtime())
        if root is None:
            self.write(f"{stamp} the simulator {self.udid} is not running")
            self.before, self.at = processes, now
            return
        simulator = descendants(root, processes)
        if self.pause_posters:
            for pid in sorted(simulator):
                ppid, state, _, path = processes[pid]
                if is_poster_extension(path) and "T" not in state and pid not in self.paused:
                    try:
                        self.kill(pid, signal.SIGSTOP)
                    except OSError as error:
                        self.write(f"{stamp} could not pause {name_of(path)} ({pid}): {error}")
                    else:
                        self.paused.add(pid)
                        self.write(f"{stamp} paused {name_of(path)} ({pid})")
        if self.before is not None:
            elapsed = max(now - self.at, 1e-6)
            used, everything = {}, 0.0
            for pid, (_, _, seconds, path) in processes.items():
                earlier = self.before.get(pid)
                delta = seconds - (earlier[2] if earlier and earlier[3] == path else 0.0)
                if delta <= 0:
                    continue
                everything += delta
                if pid in simulator:
                    name = name_of(path)
                    used[name] = used.get(name, 0.0) + delta
                    self.totals[name] = self.totals.get(name, 0.0) + delta
            load = os.getloadavg()[0] if hasattr(os, "getloadavg") else float("nan")
            busiest = sorted(used.items(), key=lambda item: -item[1])[:6]
            self.write(
                f"{stamp} simulator {100 * sum(used.values()) / elapsed:4.0f}% "
                f"mac {100 * everything / elapsed:4.0f}% load {load:5.1f} | "
                + ", ".join(f"{name} {100 * seconds / elapsed:.0f}%" for name, seconds in busiest))
        self.before, self.at = processes, now

    def summary(self):
        self.write("Processor time the simulator's processes used while watched:")
        for name, seconds in sorted(self.totals.items(), key=lambda item: -item[1])[:20]:
            self.write(f"  {seconds:8.1f} s  {name}")
        if self.pause_posters:
            self.write(f"Paused {len(self.paused)} lock-screen wallpaper extension processes.")


def watch(arguments):
    stopping = []

    def stop(*_):
        stopping.append(True)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with open(arguments.out, "a", encoding="utf-8") as out:
        watcher = Watch(arguments.udid, out, arguments.pause_posters)
        watcher.write(f"Watching simulator {arguments.udid}"
                      + (", pausing lock-screen wallpaper extensions" if arguments.pause_posters else ""))
        while not stopping:
            try:
                watcher.sample()
            except (OSError, subprocess.CalledProcessError) as error:
                watcher.write(f"could not read the process list: {error}")
            deadline = time.monotonic() + INTERVAL
            while not stopping and time.monotonic() < deadline:
                time.sleep(0.2)
        watcher.summary()
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)
    watching = commands.add_parser("watch")
    watching.add_argument("--udid", required=True)
    watching.add_argument("--out", required=True)
    watching.add_argument("--pause-posters", action="store_true")
    arguments = parser.parse_args()
    return watch(arguments)


if __name__ == "__main__":
    sys.exit(main())
