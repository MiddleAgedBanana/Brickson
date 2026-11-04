#!/usr/bin/env python3
"""Watches one simulator's processes while its tests run, and writes down
which of them use the machine's processors.

    simulator-load.py start --udid <udid> --out <file> --parent <pid> [--pause-posters]
    simulator-load.py stop --pid <pid> --out <file>

`start` starts a watcher in the background, waits for it to begin
watching (or, on a Mac too busy to start it in time, leaves it to begin)
and prints its pid; `stop` stops it, waits for its summary and prints it.
scripts/test.sh starts one for each simulator it tests on.

Every five seconds the watcher reads the Mac's process list, finds the
processes the simulator runs (everything started under that device's
launchd_sim), and writes one line: the time, how much processor time the
simulator and the whole Mac used since the last line, the Mac's load, how
long reading the list took, and the simulator's busiest processes. When
it is stopped (SIGTERM or SIGINT) it writes the processes that used the
most time over the whole run, lets any process it paused run again,
writes how much processor time it used itself, then writes "Stopped.".
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
after its run is not left with them stopped. While pausing, it also
reads the list every second between its lines, so a new extension is
found a second after the last reading rather than up to five: in the
probe run of 2026-11-04 iOS started 49 new ones on GitHub's iPhone and
17 on its iPad, with the first ones paused, and each new one ran flat out
until a reading found it, on processors the tests needed. Each "paused"
line says how much processor time that extension had used.

The process list comes from the Mac's own process calls, made from
Python through ctypes (MacProcesses): libproc's proc_listpids,
proc_pidinfo and proc_pidpath, the sysctl that gives a process's
arguments, and the Mach call that counts each processor's busy time. None
of them starts a process. Until 2026-11-04 the watcher ran /bin/ps twice
a reading instead. While GitHub's Mac was starved, ps ran past its time
limit reading after reading, a ps killed for it still had to end before
the watcher could go on (one reading took about 160 s), and wallpaper
extensions started meanwhile were never paused
(docs/log/2026-11-04-watcher-without-ps.md). Only the processes of the
one simulator named by --udid are read in detail or paused, and only on
a Mac.
"""
import argparse
import ctypes
import json
import os
import re
import signal
import subprocess
import sys
import time

# Names of the lock-screen wallpaper extensions; PosterBoard does not match.
POSTER = re.compile(r"Poster(Extension|Provider)?$")
# The kernel's name for the simulator's own launchd.
LAUNCHD_SIM = "launchd_sim"

# Seconds between the record's lines, and, while pausing, between the
# readings that look for new wallpaper extensions.
INTERVAL = 5.0
CHECK = 1.0
# How long `start` waits for the watcher to begin, and `stop` for it to end.
# A watcher that has not begun by then is left to begin, not stopped: a Mac
# busy starting a simulator can take longer than this to start Python.
WAIT = 15.0
STOPPED = "Stopped."


def clock_time():
    """The time of day, in UTC, as each line of the record gives it."""
    return time.strftime("%H:%M:%S", time.gmtime())


class ShortInfo(ctypes.Structure):
    """struct proc_bsdshortinfo (xnu, bsd/sys/proc_info.h), which the kernel
    gives for any process, whoever runs it."""
    _fields_ = [("pid", ctypes.c_uint32), ("ppid", ctypes.c_uint32), ("pgid", ctypes.c_uint32),
                ("status", ctypes.c_uint32), ("comm", ctypes.c_char * 16),
                ("flags", ctypes.c_uint32), ("uid", ctypes.c_uint32), ("gid", ctypes.c_uint32),
                ("ruid", ctypes.c_uint32), ("rgid", ctypes.c_uint32), ("svuid", ctypes.c_uint32),
                ("svgid", ctypes.c_uint32), ("rfu", ctypes.c_uint32)]


class TaskInfo(ctypes.Structure):
    """struct proc_taskinfo (xnu, bsd/sys/proc_info.h), which the kernel
    gives only for the caller's own user's processes; every simulator's
    are the watcher's user's."""
    _fields_ = ([(name, ctypes.c_uint64) for name in (
                    "virtual_size", "resident_size", "total_user", "total_system",
                    "threads_user", "threads_system")]
                + [(name, ctypes.c_int32) for name in (
                    "policy", "faults", "pageins", "cow_faults", "messages_sent",
                    "messages_received", "syscalls_mach", "syscalls_unix", "csw",
                    "threadnum", "numrunning", "priority")])


class Timebase(ctypes.Structure):
    """struct mach_timebase_info (mach/mach_time.h): Mach time units to
    nanoseconds, numer / denom."""
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]


class MacProcesses:
    """The Mac's own process calls, through ctypes. Each answers from the
    kernel's tables and none starts a process, so a starved Mac answers as
    soon as the watcher itself is given a moment to run. The only other
    process's memory they read is launchd_sim's arguments, once.

    Values are from xnu's headers (bsd/sys/proc_info.h, bsd/sys/proc.h,
    bsd/sys/sysctl.h, osfmk/mach/processor_info.h and
    osfmk/mach/machine.h)."""

    PROC_ALL_PIDS = 1
    PROC_PIDTASKINFO = 4
    PROC_PIDT_SHORTBSDINFO = 13
    PROC_PIDPATHINFO_MAXSIZE = 4096
    SSTOP = 4  # stopped, as by SIGSTOP
    CTL_KERN, KERN_ARGMAX, KERN_PROCARGS2 = 1, 8, 49
    PROCESSOR_CPU_LOAD_INFO = 2
    CPU_STATE_MAX = 4  # user, system, idle, nice

    def __init__(self, library="/usr/lib/libSystem.B.dylib"):
        lib = ctypes.CDLL(library, use_errno=True)
        for name, result, arguments in (
                ("proc_listpids", ctypes.c_int,
                 [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_int]),
                ("proc_pidinfo", ctypes.c_int,
                 [ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int]),
                ("proc_pidpath", ctypes.c_int, [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]),
                ("sysctl", ctypes.c_int,
                 [ctypes.POINTER(ctypes.c_int), ctypes.c_uint, ctypes.c_void_p,
                  ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p, ctypes.c_size_t]),
                ("mach_host_self", ctypes.c_uint32, []),
                ("host_processor_info", ctypes.c_int,
                 [ctypes.c_uint32, ctypes.c_int, ctypes.POINTER(ctypes.c_uint32),
                  ctypes.POINTER(ctypes.POINTER(ctypes.c_uint32)), ctypes.POINTER(ctypes.c_uint32)]),
                ("vm_deallocate", ctypes.c_int, [ctypes.c_uint32, ctypes.c_size_t, ctypes.c_size_t]),
                ("mach_timebase_info", ctypes.c_int, [ctypes.POINTER(Timebase)])):
            function = getattr(lib, name)
            function.restype, function.argtypes = result, arguments
        self.lib = lib
        timebase = Timebase()
        if lib.mach_timebase_info(ctypes.byref(timebase)) != 0 or not timebase.denom:
            raise OSError("mach_timebase_info failed")
        # Task times are in Mach time units, which are nanoseconds on Intel
        # Macs but not on Apple silicon.
        self.seconds_per_unit = timebase.numer / timebase.denom / 1e9
        self.host = lib.mach_host_self()
        self.task_port = ctypes.c_uint32.in_dll(lib, "mach_task_self_").value
        self.ticks_per_second = os.sysconf("SC_CLK_TCK")
        self.argmax = self.read_argmax()
        self.info, self.task = ShortInfo(), TaskInfo()
        self.path = ctypes.create_string_buffer(self.PROC_PIDPATHINFO_MAXSIZE)

    @staticmethod
    def failure(call):
        number = ctypes.get_errno()
        return OSError(number, f"{call}: {os.strerror(number)}")

    def read_argmax(self):
        names = (ctypes.c_int * 2)(self.CTL_KERN, self.KERN_ARGMAX)
        value, size = ctypes.c_int(0), ctypes.c_size_t(ctypes.sizeof(ctypes.c_int))
        if self.lib.sysctl(names, 2, ctypes.byref(value), ctypes.byref(size), None, 0) != 0:
            raise self.failure("sysctl kern.argmax")
        return value.value

    def table(self):
        """Every process on the Mac: pid -> (ppid, stopped, name), the name
        being the kernel's, at most 16 characters. A process that ends
        after the pids are listed is left out."""
        size = self.lib.proc_listpids(self.PROC_ALL_PIDS, 0, None, 0)
        if size <= 0:
            raise self.failure("proc_listpids")
        while True:
            pids = (ctypes.c_int * (size // ctypes.sizeof(ctypes.c_int) + 64))()
            used = self.lib.proc_listpids(self.PROC_ALL_PIDS, 0, pids, ctypes.sizeof(pids))
            if used <= 0:
                raise self.failure("proc_listpids")
            if used < ctypes.sizeof(pids):
                break
            size = 2 * used  # More processes than room for them: list again.
        table = {}
        info, length = self.info, ctypes.sizeof(self.info)
        for pid in pids[:used // ctypes.sizeof(ctypes.c_int)]:
            if self.lib.proc_pidinfo(pid, self.PROC_PIDT_SHORTBSDINFO, 0,
                                     ctypes.byref(info), length) == length:
                table[pid] = (info.ppid, info.status == self.SSTOP,
                              info.comm.decode(errors="replace"))
        return table

    def arguments(self, pid):
        """A process's arguments, or None once it has ended (or if another
        user runs it)."""
        names = (ctypes.c_int * 3)(self.CTL_KERN, self.KERN_PROCARGS2, pid)
        buffer, size = ctypes.create_string_buffer(self.argmax), ctypes.c_size_t(self.argmax)
        if self.lib.sysctl(names, 3, buffer, ctypes.byref(size), None, 0) != 0 or size.value < 4:
            return None
        raw = buffer.raw[:size.value]
        count = int.from_bytes(raw[:4], sys.byteorder)
        # The number of arguments, the executable's path, the NULs that pad
        # it, then the arguments (and then the environment, not read).
        words = [word for word in raw[4:].split(b"\0")[1:] if word]
        return [word.decode(errors="replace") for word in words[:count]]

    def details(self, pid):
        """A process's processor time so far, in seconds, and its
        executable's path; None once it has ended."""
        task, length = self.task, ctypes.sizeof(self.task)
        if self.lib.proc_pidinfo(pid, self.PROC_PIDTASKINFO, 0, ctypes.byref(task), length) != length:
            return None
        if self.lib.proc_pidpath(pid, self.path, self.PROC_PIDPATHINFO_MAXSIZE) <= 0:
            return None
        return ((task.total_user + task.total_system) * self.seconds_per_unit,
                self.path.value.decode(errors="replace"))

    def processor_ticks(self):
        """How long each of the Mac's processors has been busy: its user,
        system and nice ticks (ticks_per_second a second), processor after
        processor, each a counter that wraps at 2**32.

        From host_processor_info, not host_statistics: to programs that
        are not part of macOS, the watcher among them, the kernel answers
        host_statistics from a copy up to a second old once they have
        asked a few times in that second (osfmk/kern/host.c,
        rate_limit_host_statistics). On GitHub's machine it gave the same
        counts before and after half a second of work."""
        processors, array, length = (ctypes.c_uint32(), ctypes.POINTER(ctypes.c_uint32)(),
                                     ctypes.c_uint32())
        result = self.lib.host_processor_info(self.host, self.PROCESSOR_CPU_LOAD_INFO,
                                              ctypes.byref(processors), ctypes.byref(array),
                                              ctypes.byref(length))
        if result != 0:
            raise OSError(f"host_processor_info: kern_return_t {result}")
        try:
            counts = array[:length.value]
        finally:
            # The kernel hands over memory of its own allocating.
            self.lib.vm_deallocate(self.task_port, ctypes.cast(array, ctypes.c_void_p).value,
                                   length.value * ctypes.sizeof(ctypes.c_uint32))
        ticks = []
        for first in range(0, processors.value * self.CPU_STATE_MAX, self.CPU_STATE_MAX):
            user, system, _, nice = counts[first:first + self.CPU_STATE_MAX]
            ticks += [user, system, nice]
        return tuple(ticks)


class ProcessFile:
    """A stand-in for MacProcesses, for scripts/test-runner.py on any
    machine: a JSON file, read afresh for each reading, of {"ticks": busy
    ticks, "processes": [[pid, ppid, state, seconds, path, arguments],
    ...]}. A process whose seconds are null ended before its details were
    read."""

    ticks_per_second = 100

    def __init__(self, path):
        self.path, self.rows, self.ticks = path, {}, 0

    def table(self):
        with open(self.path, encoding="utf-8") as file:
            data = json.load(file)
        self.rows = {row[0]: row for row in data["processes"]}
        self.ticks = data["ticks"]
        return {pid: (ppid, "T" in state, name_of(path)[:16])
                for pid, ppid, state, _, path, _ in self.rows.values()}

    def arguments(self, pid):
        return self.rows[pid][5] if pid in self.rows else None

    def details(self, pid):
        row = self.rows.get(pid)
        return None if row is None or row[3] is None else (row[3], row[4])

    def processor_ticks(self):
        return (self.ticks, 0, 0)


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
    def __init__(self, udid, out, pause_posters, system, clock=time.monotonic, kill=os.kill):
        self.udid, self.out, self.pause_posters = udid, out, pause_posters
        self.system, self.clock, self.kill = system, clock, kill
        self.root = None  # the simulator's launchd_sim, once found
        # The last line's processes, the processors' counts and when they
        # were read, and when its process list was read.
        self.before, self.ticks, self.at, self.listed = None, None, None, None
        self.totals = {}  # name -> cpu seconds used while watched
        self.paused = set()

    def write(self, line):
        self.out.write(line + "\n")
        self.out.flush()

    def simulator_root(self, table):
        """The pid of the simulator's own launchd, whose arguments name the
        device's folder; None while the device is not running. Reading a
        process's arguments reads its memory, so they are read once: the
        launchd_sim found stays the simulator's while it runs, and a new
        one is looked for only once it has gone."""
        if self.root in table and table[self.root][2] == LAUNCHD_SIM:
            return self.root
        self.root = None
        for pid, (_, _, name) in table.items():
            if name == LAUNCHD_SIM:
                arguments = self.system.arguments(pid)
                if arguments and f"/{self.udid}/" in " ".join(arguments):
                    self.root = pid
                    break
        return self.root

    def sample(self, line=True):
        """Reads the process list and pauses any new wallpaper extension.
        With `line`, it also writes the record's line for the time since
        the last one; a reading without (a check, between lines) leaves
        that line's counts where they were.

        Each process's time is read at its own moment, and on a starved
        Mac a reading can take seconds (13.67 s once, in run
        41757279440), so a line counts each process over the time between
        its own two readings, and a new one over the time since the last
        line's list, which it was not in, was read. Counted over the time
        between the two lines' ends, as until then, the line after that
        reading put the simulator at 845% of a three-processor Mac."""
        began = self.clock()
        table = self.system.table()
        root = self.simulator_root(table)
        processes = {}  # pid -> (stopped, cpu seconds, path, when read)
        if root is not None:
            for pid in sorted(descendants(root, table)):
                details = self.system.details(pid)
                # None: it ended after the list was read.
                if details is not None:
                    processes[pid] = (table[pid][1],) + details + (self.clock(),)
        ticks = self.system.processor_ticks() if line else None
        now = self.clock()
        stamp = clock_time()
        if root is None:
            if line:
                self.write(f"{stamp} the simulator {self.udid} is not running")
                self.before, self.ticks, self.at, self.listed = {}, ticks, now, began
            return
        if self.pause_posters:
            for pid, (stopped, seconds, path, _) in processes.items():
                if is_poster_extension(path) and not stopped and pid not in self.paused:
                    try:
                        self.kill(pid, signal.SIGSTOP)
                    except OSError as error:
                        self.write(f"{stamp} could not pause {name_of(path)} ({pid}): {error}")
                    else:
                        self.paused.add(pid)
                        self.write(f"{stamp} paused {name_of(path)} ({pid}) "
                                   f"after {seconds:.1f} s of processor time")
        if not line:
            return
        if self.before is not None:
            elapsed = max(now - self.at, 1e-6)
            used = {}  # name -> processors' worth used
            for pid, (_, seconds, path, read) in processes.items():
                earlier = self.before.get(pid)
                if earlier and earlier[2] == path:
                    delta, span = seconds - earlier[1], read - earlier[3]
                else:
                    # New, or a new process given an old pid: it counts
                    # from nothing, over the longest it can have run.
                    delta, span = seconds, read - self.listed
                if delta <= 0:
                    continue
                name = name_of(path)
                used[name] = used.get(name, 0.0) + delta / max(span, 1e-6)
                self.totals[name] = self.totals.get(name, 0.0) + delta
            busy = sum((after - before) % 2**32 for after, before
                       in zip(ticks, self.ticks)) / self.system.ticks_per_second
            load = os.getloadavg()[0] if hasattr(os, "getloadavg") else float("nan")
            busiest = sorted(used.items(), key=lambda item: -item[1])[:6]
            self.write(
                f"{stamp} simulator {100 * sum(used.values()):4.0f}% "
                f"mac {100 * busy / elapsed:4.0f}% load {load:5.1f} list {now - began:4.2f} s | "
                + ", ".join(f"{name} {100 * share:.0f}%" for name, share in busiest))
        self.before, self.ticks, self.at, self.listed = processes, ticks, now, began

    def summary(self):
        self.write("Processor time the simulator's processes used while watched:")
        for name, seconds in sorted(self.totals.items(), key=lambda item: -item[1])[:20]:
            self.write(f"  {seconds:8.1f} s  {name}")
        if self.pause_posters:
            self.write(f"Paused {len(self.paused)} lock-screen wallpaper extension processes.")

    def resume(self):
        """Lets every paused process run again. One that has ended since
        needs nothing."""
        resumed, ended = 0, []
        for pid in sorted(self.paused):
            try:
                self.kill(pid, signal.SIGCONT)
            except ProcessLookupError:
                ended.append(pid)
            except OSError as error:
                self.write(f"could not resume process {pid}: {error}")
            else:
                resumed += 1
        if self.paused:
            # Which ones ended, to match against the "paused" lines: in the
            # probe run of 2026-11-04, 49 of the 65 paused on the iPhone had.
            self.write(f"Resumed {resumed} of them" + (
                f"; {len(ended)} had already ended: {', '.join(map(str, ended))}." if ended else "."))


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
    system = ProcessFile(arguments.processes) if arguments.processes else MacProcesses()
    with open(arguments.out, "a", encoding="utf-8") as out:
        watcher = Watch(arguments.udid, out, arguments.pause_posters, system, kill=kill)
        # The time it began: on a busy Mac that can be long after `start`.
        watcher.write(f"Watching simulator {arguments.udid}"
                      + (", pausing lock-screen wallpaper extensions" if arguments.pause_posters else "")
                      + f", from {clock_time()}")
        # Only pausing needs a reading between lines.
        every = CHECK if arguments.pause_posters else INTERVAL
        next_line = time.monotonic()
        while not stopping:
            line = time.monotonic() >= next_line
            if line:
                next_line = time.monotonic() + INTERVAL
            try:
                watcher.sample(line=line)
            except OSError as error:
                watcher.write(f"{clock_time()} could not read the process list: {error}")
            deadline = time.monotonic() + every
            while not stopping and time.monotonic() < deadline:
                if not parent_alive(arguments.parent):
                    watcher.write(f"The test run ({arguments.parent}) is gone.")
                    stopping.append(True)
                    break
                time.sleep(0.2)
        watcher.summary()
        watcher.resume()
        watcher.write(f"Processor time the watcher itself used: {time.process_time():.1f} s")
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
               "--parent", str(arguments.parent)]
    if arguments.pause_posters:
        command.append("--pause-posters")
    if arguments.processes:
        command += ["--processes", arguments.processes]
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
        # scripts/test-runner.py gives a stand-in for the Mac's process
        # calls (ProcessFile).
        command.add_argument("--processes", help=argparse.SUPPRESS)
    stopping = commands.add_parser("stop")
    stopping.add_argument("--pid", type=int, required=True)
    stopping.add_argument("--out", required=True)
    return parser.parse_args(arguments)


def main():
    arguments = parse()
    return {"start": start, "watch": watch, "stop": stop}[arguments.command](arguments)


if __name__ == "__main__":
    sys.exit(main())
