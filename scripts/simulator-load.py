#!/usr/bin/env python3
"""Watches one simulator's processes while its tests run, and writes down
which of them use the machine's processors.

    simulator-load.py start --udid <udid> --out <file> --parent <pid> [--pause-posters]
    simulator-load.py stop --pid <pid> --out <file>

`start` starts a watcher in the background, waits for it to begin
watching (or, on a Mac too busy to start it in time, leaves it to begin)
and prints its pid; `stop` stops it, waits for its summary and prints it.
scripts/test.sh starts one for each simulator it tests on.

Every few seconds the watcher reads the Mac's process list, finds the processes the
simulator runs (everything started under that device's launchd_sim), and
writes one line: the time, how much processor time the simulator and the
whole Mac used since the last line, the Mac's load, and the simulator's
busiest processes. When it is stopped (SIGTERM or SIGINT) it writes the
processes that used the most time over the whole run, lets any process it
paused run again, then writes "Stopped.".
It also stops by itself once the process named by --parent (the test run)
is gone, so a test run that is killed never leaves it running.

With --pause-posters it also pauses (SIGSTOP) the simulator's lock-screen
wallpaper extensions as they start: processes whose name ends in "Poster",
"PosterExtension" or "PosterProvider" (EmojiPosterExtension, AegirPoster,
PhotosPosterProvider and the like; never PosterBoard itself). Five or
more minutes after a simulator starts, iOS runs a scheduled task that
prewarms the lock-screen wallpaper gallery, and those extensions then
render its pictures for about three minutes. On GitHub's Mac machines
(three processors) that stalled the app under test until UI tests timed
out (docs/log/2026-11-03-ui-test-stall.md). The tests never show the lock
screen. A process is paused rather than ended because iOS would start an
ended one again. When the watcher stops, after the tests, it lets the
paused ones run again (SIGCONT), so a simulator that is not shut down
after its run is not left with them stopped.

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
# How long `start` waits for the watcher to begin, and `stop` for it to end.
# A watcher that has not begun by then is left to begin, not stopped: a Mac
# busy starting a simulator can take longer than this to start Python.
WAIT = 15.0
# How long one process list may take. A slower one is given up on and that
# reading skipped, so a hung ps never holds the watcher. A reading lists
# processes twice, so both together stay shorter than WAIT and `stop`
# still finds the summary.
PS_TIMEOUT = 5.0
STOPPED = "Stopped."


def clock_time():
    """The time of day, in UTC, as each line of the record gives it."""
    return time.strftime("%H:%M:%S", time.gmtime())


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
                            capture_output=True, text=True, check=True, timeout=PS_TIMEOUT).stdout
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
                            capture_output=True, text=True, check=True, timeout=PS_TIMEOUT).stdout
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
        stamp = clock_time()
        # The two lists are read one after the other: a simulator that
        # stopped in between is in the first and not the second.
        if root is None or root not in processes:
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

    def resume(self):
        """Lets every paused process run again. One that has ended since
        needs nothing."""
        resumed, ended = 0, 0
        for pid in sorted(self.paused):
            try:
                self.kill(pid, signal.SIGCONT)
            except ProcessLookupError:
                ended += 1
            except OSError as error:
                self.write(f"could not resume process {pid}: {error}")
            else:
                resumed += 1
        if self.paused:
            self.write(f"Resumed {resumed} of them" + (f"; {ended} had already ended." if ended else "."))


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def watch(arguments, parent_alive=alive, kill=os.kill):
    stopping = []

    def stop_watching(*_):
        stopping.append(True)

    signal.signal(signal.SIGTERM, stop_watching)
    signal.signal(signal.SIGINT, stop_watching)
    with open(arguments.out, "a", encoding="utf-8") as out:
        watcher = Watch(arguments.udid, out, arguments.pause_posters, ps=arguments.ps, kill=kill)
        # The time it began: on a busy Mac that can be long after `start`.
        watcher.write(f"Watching simulator {arguments.udid}"
                      + (", pausing lock-screen wallpaper extensions" if arguments.pause_posters else "")
                      + f", from {clock_time()}")
        while not stopping:
            try:
                watcher.sample()
            except (OSError, subprocess.SubprocessError) as error:
                watcher.write(f"{clock_time()} could not read the process list: {error}")
            deadline = time.monotonic() + INTERVAL
            while not stopping and time.monotonic() < deadline:
                if not parent_alive(arguments.parent):
                    watcher.write(f"The test run ({arguments.parent}) is gone.")
                    stopping.append(True)
                    break
                time.sleep(0.2)
        watcher.summary()
        watcher.resume()
        watcher.write(STOPPED)
    return 0


def began(lines):
    return any(line.startswith("Watching simulator") for line in lines)


def record_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as file:
            return file.read().splitlines()
    except OSError:
        return []


def start(arguments, wait=WAIT):
    """Starts the watcher in the background, waits for it to begin
    watching, and prints its pid. The record starts empty, and the
    watcher's own errors, if any, land in it too.

    A watcher still starting when the wait ends is left to start, and its
    pid printed all the same. On GitHub's Mac machine, just after a
    simulator had started, this command began its wait about 40 s after
    it was run, and the iPad's watcher had not begun 15 s after that (run
    41656480638); stopped then, it paused nothing and the iPad stalled
    again. Once it begins it pauses the extensions already running too,
    and `stop` stops it either way."""
    command = [sys.executable, "-I", os.path.abspath(__file__), "watch",
               "--udid", arguments.udid, "--out", arguments.out,
               "--parent", str(arguments.parent), "--ps", arguments.ps]
    if arguments.pause_posters:
        command.append("--pause-posters")
    try:
        # Emptied, then opened to append: what the watcher writes to its
        # stderr (a traceback, say) lands after its lines, never over them.
        open(arguments.out, "w", encoding="utf-8").close()
        with open(arguments.out, "a", encoding="utf-8") as errors:
            child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=errors, start_new_session=True)
    except OSError as error:
        print(f"The simulator watcher could not start: {error}", file=sys.stderr)
        return 1
    deadline = time.monotonic() + wait
    while True:
        if began(record_lines(arguments.out)):
            print(child.pid)
            return 0
        if child.poll() is not None:
            print(f"The simulator watcher stopped as it started (status {child.returncode}); "
                  f"see {arguments.out}.", file=sys.stderr)
            return 1
        if time.monotonic() >= deadline:
            break
        time.sleep(0.05)
    print(child.pid)
    print(f"The simulator watcher has not begun watching within {wait:.0f} s; it is left to start, "
          f"and its record says when it begins: {arguments.out}", file=sys.stderr)
    return 0


def stop(arguments, wait=WAIT):
    """Stops the watcher, waits for its summary and prints it."""
    try:
        os.kill(arguments.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + wait
    while time.monotonic() < deadline:
        lines = record_lines(arguments.out)
        if lines and lines[-1] == STOPPED:
            break
        time.sleep(0.05)
    else:
        try:
            os.kill(arguments.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        if not began(record_lines(arguments.out)):
            # Left to start by `start` and ended before it began.
            print(f"The simulator watcher never began watching, so nothing was paused; "
                  f"what it wrote is in {arguments.out}.", file=sys.stderr)
        else:
            print(f"The simulator watcher did not finish its record within {wait:.0f} s; "
                  f"what it wrote is in {arguments.out}.", file=sys.stderr)
        return 1
    summary = next((index for index, line in enumerate(lines)
                    if line.startswith("Processor time")), len(lines) - 1)
    print("\n".join(lines[summary:-1]))
    print(f"The whole record: {arguments.out}")
    return 0


def parse(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("start", "watch"):
        command = commands.add_parser(name)
        command.add_argument("--udid", required=True)
        command.add_argument("--out", required=True)
        command.add_argument("--parent", type=int, required=True)
        command.add_argument("--pause-posters", action="store_true")
        # scripts/test-runner.py gives a stand-in for ps.
        command.add_argument("--ps", default="/bin/ps", help=argparse.SUPPRESS)
    stopping = commands.add_parser("stop")
    stopping.add_argument("--pid", type=int, required=True)
    stopping.add_argument("--out", required=True)
    return parser.parse_args(arguments)


def main():
    arguments = parse()
    return {"start": start, "watch": watch, "stop": stop}[arguments.command](arguments)


if __name__ == "__main__":
    sys.exit(main())
