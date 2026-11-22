#!/usr/bin/env python3
"""Watches one simulator's processes while its tests run, and writes down
which of them use the machine's processors.

    simulator-load.py start --udid <udid> --out <file> --parent <pid>
                            [--pause-posters] [--background]
                            [--claim-file <file> [--started-file <file>]]
    simulator-load.py settle --out <file> [--limit <seconds>]
    simulator-load.py restore --udid <udid> --out <file> [--pid <pid>]
    simulator-load.py stop --pid <pid> --out <file>

`start` starts a watcher in the background, waits for it to begin
watching (or, on a Mac too busy to start it in time, leaves it to begin)
and prints its pid; `stop` stops it, waits for its summary and prints it.
scripts/test.sh starts one for each simulator it tests on, before it
starts the simulator, so the record covers the simulator's first minutes.
Given --claim-file, the watcher pauses and lowers nothing until that file
exists: scripts/test.sh creates it once it has started the simulator
itself, and the --started-file once the simulator has finished starting
(below). Files, not a command: on GitHub's machines a program started
during the simulator's start took up to eleven minutes to begin, while
the watcher, already running, kept its lines five to nine seconds apart.
`settle` waits, before the tests, until the Mac is no longer busy with
the simulator's start (see "Waiting for the Mac to settle" below), and
`restore` then returns the simulator's processes to normal priority and
checks that they are there (see "The simulator's start in the
background" below).

Every five seconds the watcher reads the Mac's process list, finds the
processes the simulator runs (everything started under that device's
launchd_sim), and writes one line: the time, how much processor time the
simulator and the whole Mac used since the last line, the Mac's load, how
long reading the list took, how much of a processor GitHub's agent used
(below), and the simulator's busiest processes. When
it is stopped (SIGTERM or SIGINT) it writes the processes that used the
most time over the whole run, lets any process it paused run again,
returns any it still holds in the background to normal priority,
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

Waiting for the Mac to settle. A simulator that starts for the first
time, as every simulator on GitHub's machines does, starts hundreds of
background tasks: indexing, widgets, wallpapers, health, news and the
rest. On GitHub's Mac (three processors) they kept every processor busy,
with 400 to 550 tasks waiting for one, for a quarter of an hour and more,
and the UI tests started five minutes into it. In the 320 UI test jobs
from 2026-11-12 to 2026-11-19, a test step never stalled while the load
was under 250, and stalled 50 times above it; tests that started with
the load under 150 failed once in 10,504 runs, and those that started
above 350 about eight times in a thousand
(docs/log/2026-11-19-ui-tests-wait-for-a-settled-mac.md). So `settle`
reads the load every five seconds and returns once three readings in a
row are under 50 for each of the Mac's processors (150 on GitHub's), or
after --limit seconds (twenty minutes unless given), saying which in the
log and in the record. It only waits: it never fails a run, and a Mac
that does not settle is tested anyway, with a warning. The load is the
one-minute average of tasks running or waiting for a processor
(os.getloadavg), the "load" of each of the record's lines. It leaves out
tasks in the background band, so with --udid, on a simulator held there
(below), each reading adds the simulator's own threads running or
waiting, averaged over a minute in the same way.

The simulator's start in the background. GitHub cancelled Mac test jobs
by itself 8.5 to 13 minutes after their simulator began to start: its
agent on the machine (the runner program, Runner.Listener, which keeps
the job's session with GitHub) had requests time out after 100 seconds,
lost its session and cancelled the job as it shut down. In all five
such jobs whose timeline could be read, the build had run for under 20
seconds: the Mac was swamped by the simulator's own start, within
seconds of it (docs/log/2026-11-22-simulator-start-in-the-background.md).
So with --background, once claimed, the watcher puts the simulator's
processes in macOS's background band (setpriority with
PRIO_DARWIN_PROCESS and PRIO_DARWIN_BG, as `taskpolicy -b` does): its
launchd_sim first, which every later process of the simulator is
started from and takes the band from, and every process under it, at
each reading, so one that started after the first batch is lowered
within a second. It begins once the --started-file exists or LOWER_AFTER
seconds after the claim, whichever comes first: held in the band from the
boot itself, a first start on the owner's Mac had not finished after
almost seven minutes (on Apple silicon the system runs background work
on the efficiency cores when it can), where it takes about 19 seconds
at normal priority; and in the jobs GitHub cancelled, its agent kept in
touch for the first three to four and a half minutes. In that band a process runs, reads and writes, and uses
the network only when nothing outside it is waiting to, so GitHub's
agent, the build and the watcher come first, and the start-up work
still gets every moment they leave. iOS itself runs about two thirds of
a started simulator's processes in that band; this adds the rest for
the start-up only. `restore`, after `settle` and before the first test,
tells the watcher to stop lowering, waits for it to say it has, then
returns launchd_sim and every process under it to normal priority, in
passes until a pass finds no process it had not returned (so one started
during a pass is returned too). It then reads launchd_sim, SpringBoard
and backboardd back, which iOS never runs in the background, and says
what it found in the log and the record. Returning a process clears only
the setting this script made, so a process iOS runs in the background
stays there, as it does on any start: on the owner's Mac, every process
of a settled simulator read back at the priority it had before a round
trip. When the return cannot be confirmed (launchd_sim not found, a
process that could not be returned, or one of the three still in the
background), `restore` fails, and scripts/test.sh stops before the
tests rather than test on a throttled simulator (docs/DECISIONS.md,
"Tests", 2026-11-22). Only a simulator this run started is ever lowered,
as only its wallpaper extensions are paused.

GitHub's agent. Each line also says how much of a processor GitHub's
agent (Runner.Listener) used since the last line, its task's priority
and how many of its threads were running or waiting for a processor,
and the watcher's first lines name the agent's processes and their
priority; on a Mac that runs no agent, nothing is said. They are found
by the kernel's name for them, never by their arguments, which can hold
the agent's credentials.
"""
import argparse
import ctypes
import json
import math
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

# The Mac has settled once its load has been under this many for each of
# its processors on this many readings in a row, INTERVAL apart; `settle`
# waits no longer than SETTLE_LIMIT seconds unless told, and says how far
# it is every SETTLE_SAYS. The measurements behind the numbers are in the
# module's description.
SETTLED_LOAD = 50.0
SETTLED_READINGS = 3
SETTLE_LIMIT = 20 * 60.0
SETTLE_SAYS = 60.0

# macOS's background band (bsd/sys/resource.h): setpriority's
# PRIO_DARWIN_PROCESS with PRIO_DARWIN_BG puts a process in it, and 0
# takes it out. A task in it reads back at priority MAXPRI_THROTTLE
# (osfmk/kern/sched.h), 4, the lowest a user's task runs at.
PRIO_DARWIN_PROCESS = 4
PRIO_DARWIN_BG = 0x1000
BACKGROUND_PRIORITY = 4
# What `restore` reads back after returning the simulator's processes:
# none of them is ever in the background band on its own.
NEVER_IN_BACKGROUND = (LAUNCHD_SIM, "SpringBoard", "backboardd")
# `restore` goes over the simulator's processes until a pass finds none it
# had not returned, at most this many times.
RESTORE_PASSES = 5
# GitHub's agent, by the kernel's names for its two programs (at most 16
# characters): the listener holds the job's session, the worker runs the
# steps.
AGENT = ("Runner.Listener", "Runner.Worker")
# Lowering begins at most this many seconds after the claim: three times a
# first start of the iPad simulator on the owner's Mac (19 s), and under
# half the time GitHub's agent kept in touch in the jobs it cancelled.
LOWER_AFTER = 60.0
# The lines the watcher writes when it is claimed and when it stops
# lowering, which `restore` waits for.
CLAIMED = "this run started the simulator"
STOPPED_LOWERING = "stopped putting the simulator's processes in the background"


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

    def state(self, pid):
        """A process's processor time so far in seconds, its task's
        priority and how many of its threads are running or waiting for a
        processor; None once it has ended (or if another user runs it)."""
        task, length = self.task, ctypes.sizeof(self.task)
        if self.lib.proc_pidinfo(pid, self.PROC_PIDTASKINFO, 0, ctypes.byref(task), length) != length:
            return None
        return ((task.total_user + task.total_system) * self.seconds_per_unit,
                task.priority, task.numrunning)

    @staticmethod
    def set_background(pid, background):
        """Puts a process in macOS's background band, or takes it out.
        Raises ProcessLookupError once it has ended, and another OSError
        when it cannot be changed."""
        os.setpriority(PRIO_DARWIN_PROCESS, pid, PRIO_DARWIN_BG if background else 0)

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
    ticks, "processes": [[pid, ppid, state, seconds, path, arguments
    (, priority, running)], ...], "refuse": [pid, ...]}. A process whose
    seconds are null ended before its details were read; one in "refuse"
    cannot have its priority changed. Each change of priority is added to
    <file>.background ("on <pid>" or "off <pid>"), which every stand-in
    reads, as the kernel would keep it, so a watcher and a `restore` run
    as separate programs see the same simulator."""

    ticks_per_second = 100

    def __init__(self, path):
        self.path, self.rows, self.ticks, self.refused = path, {}, 0, set()
        self.changes = path + ".background"

    def table(self):
        with open(self.path, encoding="utf-8") as file:
            data = json.load(file)
        self.rows = {row[0]: row for row in data["processes"]}
        self.ticks = data["ticks"]
        self.refused = set(data.get("refuse", []))
        return {pid: (row[1], "T" in row[2], name_of(row[4])[:16]) for pid, row in self.rows.items()}

    def arguments(self, pid):
        return self.rows[pid][5] if pid in self.rows else None

    def details(self, pid):
        row = self.rows.get(pid)
        return None if row is None or row[3] is None else (row[3], row[4])

    def lowered(self):
        """The pids in the background band now, from the changes so far."""
        found = set()
        try:
            with open(self.changes, encoding="utf-8") as file:
                for line in file:
                    change, pid = line.split()
                    (found.add if change == "on" else found.discard)(int(pid))
        except FileNotFoundError:
            pass
        return found

    def state(self, pid):
        row = self.rows.get(pid)
        if row is None or row[3] is None:
            return None
        priority = row[6] if len(row) > 6 else 31
        running = row[7] if len(row) > 7 else 0
        return (row[3], BACKGROUND_PRIORITY if pid in self.lowered() else priority, running)

    def set_background(self, pid, background):
        self.table()  # As the kernel would, it knows the processes running now.
        row = self.rows.get(pid)
        if row is None or row[3] is None:
            raise ProcessLookupError(pid, "No such process")
        if pid in self.refused:
            raise PermissionError(1, "Operation not permitted")
        with open(self.changes, "a", encoding="utf-8") as file:
            file.write(f"{'on' if background else 'off'} {pid}\n")

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


def find_root(system, table, udid):
    """The pid of the simulator's own launchd, whose arguments name the
    device's folder; None while the device is not running."""
    for pid, (_, _, name) in table.items():
        if name == LAUNCHD_SIM:
            arguments = system.arguments(pid)
            if arguments and f"/{udid}/" in " ".join(arguments):
                return pid
    return None


def root_first(root, family):
    """The simulator's processes with its launchd_sim first: a process
    started under it while the rest are changed takes its band from it."""
    return [root] + sorted(family - {root})


class Watch:
    def __init__(self, udid, out, pause_posters, system, clock=time.monotonic, kill=os.kill,
                 background=False, claimed=True, started=True):
        self.udid, self.out, self.pause_posters = udid, out, pause_posters
        self.system, self.clock, self.kill = system, clock, kill
        self.root = None  # the simulator's launchd_sim, once found
        # The last line's processes, the processors' counts and when they
        # were read, and when its process list was read.
        self.before, self.ticks, self.at, self.listed = None, None, None, None
        self.totals = {}  # name -> cpu seconds used while watched
        self.paused = set()
        # Pausing and lowering wait until the run says it started the
        # simulator itself (claim), lowering until it has started too, or
        # LOWER_AFTER seconds after the claim; it ends when `restore` asks.
        self.background, self.claimed, self.lowering = background, claimed, background
        self.started, self.claimed_at = started, None
        self.lowered, self.refused = set(), set()
        # GitHub's agent's listener at the last line: (pid, cpu seconds,
        # when read); and whether its processes have been named.
        self.agent, self.agent_named = None, False

    def write(self, line):
        self.out.write(line + "\n")
        self.out.flush()

    def simulator_root(self, table):
        """The pid of the simulator's own launchd (find_root). Reading a
        process's arguments reads its memory, so they are read once: the
        launchd_sim found stays the simulator's while it runs, and a new
        one is looked for only once it has gone."""
        if self.root in table and table[self.root][2] == LAUNCHD_SIM:
            return self.root
        self.root = find_root(self.system, table, self.udid)
        return self.root

    def claim(self):
        """This run started the simulator: pausing begins, and lowering
        once it has started or LOWER_AFTER seconds from now."""
        if self.claimed:
            return
        self.claimed, self.claimed_at = True, self.clock()
        plans = []
        if self.pause_posters:
            plans.append("pausing its lock-screen wallpaper extensions")
        if self.background:
            plans.append("running its processes in the background until the tests, from when "
                         f"it has started or in {LOWER_AFTER:.0f} s")
        self.write(f"{clock_time()} {CLAIMED}" + (": " + " and ".join(plans) if plans else ""))

    def mark_started(self):
        """The simulator has finished starting (simctl bootstatus)."""
        if self.started:
            return
        self.started = True
        self.write(f"{clock_time()} the simulator has finished starting")

    def may_lower(self):
        if not (self.claimed and self.lowering):
            return False
        return self.started or (self.claimed_at is not None
                                and self.clock() - self.claimed_at >= LOWER_AFTER)

    def stop_lowering(self):
        """Puts no more processes in the background (`restore` returns
        the ones already there), and says so for `restore`."""
        self.lowering = False
        self.write(f"{clock_time()} {STOPPED_LOWERING} (it had put {len(self.lowered)} there)")

    def lower(self, root, family, table, stamp):
        """Puts every process of the simulator not yet lowered in the
        background band, its launchd_sim first."""
        first, count = not self.lowered, 0
        for pid in root_first(root, family):
            if pid in self.lowered or pid in self.refused:
                continue
            try:
                self.system.set_background(pid, True)
            except ProcessLookupError:
                continue  # It ended after the list was read.
            except OSError as error:
                self.refused.add(pid)
                self.write(f"{stamp} could not put {table[pid][2]} ({pid}) in the background: {error}")
                continue
            self.lowered.add(pid)
            count += 1
        if first and count:
            why = "" if self.claimed_at is None else (
                " (it had started)" if self.started else
                f" ({self.clock() - self.claimed_at:.0f} s after the claim, before it had started)")
            self.write(f"{stamp} put {count} of the simulator's processes in the background, "
                       f"its launchd_sim first{why}")

    def return_lowered(self):
        """Returns every process this watcher lowered to normal priority,
        when it stops before `restore` has: a run that ends early never
        leaves a simulator in the background."""
        if not self.lowering or not self.lowered:
            return
        self.lowering = False
        # Everything running under the simulator now, its launchd_sim
        # first, since a process started after the last reading took the
        # band from its parent; then any recorded one not under it.
        try:
            table = self.system.table()
            root = self.simulator_root(table)
        except OSError:
            root = None
        current = root_first(root, descendants(root, table)) if root is not None else []
        ordered = current + sorted(self.lowered - set(current))
        returned = 0
        for pid in ordered:
            try:
                self.system.set_background(pid, False)
            except ProcessLookupError:
                continue
            except OSError as error:
                self.write(f"could not return process {pid} to normal priority: {error}")
                continue
            returned += 1
        self.write(f"Returned {returned} of the simulator's processes to normal priority (it had "
                   f"put {len(self.lowered)} in the background), as the watcher stopped before "
                   "the tests.")

    def agent_field(self, table, now):
        """GitHub's agent's listener: its share of a processor since the
        last line, its task's priority and its threads running or waiting
        for a processor, as a field of the line; empty where no agent
        runs. The first time it is found, a line names the agent's
        processes and their priority."""
        state = getattr(self.system, "state", None)
        agents = {pid: name for pid, (_, _, name) in table.items() if name in AGENT}
        if state is None or not agents:
            return ""
        if not self.agent_named:
            self.agent_named = True
            named = []
            for pid, name in sorted(agents.items(), key=lambda item: (AGENT.index(item[1]), item[0])):
                found = state(pid)
                if found is not None:
                    named.append(f"{name} ({pid}) at priority {found[1]}")
            if named:
                self.write(f"{clock_time()} GitHub's agent: " + ", ".join(named))
        listener = min((pid for pid, name in agents.items() if name == AGENT[0]), default=None)
        found = state(listener) if listener is not None else None
        if found is None:
            return ""
        seconds, priority, running = found
        share = ""
        if self.agent and self.agent[0] == listener:
            share = f" {100 * (seconds - self.agent[1]) / max(now - self.agent[2], 1e-6):.0f}%"
        self.agent = (listener, seconds, now)
        return f" agent{share} at {priority}, {running} running"

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
            family = descendants(root, table)
            if self.may_lower():
                self.lower(root, family, table, clock_time())
            for pid in sorted(family):
                details = self.system.details(pid)
                # None: it ended after the list was read.
                if details is not None:
                    processes[pid] = (table[pid][1],) + details + (self.clock(),)
        ticks = self.system.processor_ticks() if line else None
        now = self.clock()
        stamp = clock_time()
        agent = self.agent_field(table, now) if line else ""
        if root is None:
            if line:
                self.write(f"{stamp} the simulator {self.udid} is not running")
                self.before, self.ticks, self.at, self.listed = {}, ticks, now, began
            return
        if self.pause_posters and self.claimed:
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
                f"mac {100 * busy / elapsed:4.0f}% load {load:5.1f} list {now - began:4.2f} s{agent} | "
                + ", ".join(f"{name} {100 * share:.0f}%" for name, share in busiest))
        self.before, self.ticks, self.at, self.listed = processes, ticks, now, began

    def summary(self):
        self.write("Processor time the simulator's processes used while watched:")
        for name, seconds in sorted(self.totals.items(), key=lambda item: -item[1])[:20]:
            self.write(f"  {seconds:8.1f} s  {name}")
        if self.pause_posters and self.claimed:
            self.write(f"Paused {len(self.paused)} lock-screen wallpaper extension processes.")
        if self.background and self.claimed:
            self.write(f"Put {len(self.lowered)} of the simulator's processes in the background "
                       "while it started.")

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
    stopping, stop_lowering = [], []
    background = getattr(arguments, "background", False)
    claim_file = getattr(arguments, "claim_file", None)
    started_file = getattr(arguments, "started_file", None)

    def stop_watching(*_):
        stopping.append(True)

    # Installed before the first line, which `restore` waits for before
    # it signals: the signal would end a watcher that had not installed
    # its handler.
    signal.signal(signal.SIGTERM, stop_watching)
    signal.signal(signal.SIGINT, stop_watching)
    signal.signal(signal.SIGUSR1, lambda *_: stop_lowering.append(True))
    system = ProcessFile(arguments.processes) if arguments.processes else MacProcesses()
    with open(arguments.out, "a", encoding="utf-8") as out:
        watcher = Watch(arguments.udid, out, arguments.pause_posters, system, kill=kill,
                        background=background, claimed=claim_file is None,
                        started=claim_file is None or started_file is None)
        plans = []
        if arguments.pause_posters:
            plans.append("pausing lock-screen wallpaper extensions")
        if background:
            plans.append("running its processes in the background until the tests")
        # The time it began: on a busy Mac that can be long after `start`.
        watcher.write(f"Watching simulator {arguments.udid}"
                      + ((", once this run has started it, " if claim_file else ", ")
                         + " and ".join(plans) if plans else "")
                      + f", from {clock_time()}")
        # Pausing and lowering need a reading between lines.
        every = CHECK if arguments.pause_posters or background else INTERVAL
        next_line = time.monotonic()
        answered = set()
        while not stopping:
            if claim_file and not watcher.claimed and os.path.exists(claim_file):
                watcher.claim()
            if started_file and watcher.claimed and not watcher.started and os.path.exists(started_file):
                watcher.mark_started()
            if stop_lowering and "stopped" not in answered:
                answered.add("stopped")
                watcher.stop_lowering()
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
                # Asked to stop lowering: answered at once, as `restore`
                # waits for it.
                if stop_lowering and "stopped" not in answered:
                    break
                time.sleep(0.2)
        watcher.summary()
        watcher.resume()
        watcher.return_lowered()
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
    if getattr(arguments, "background", False):
        command.append("--background")
    if getattr(arguments, "claim_file", None):
        command += ["--claim-file", arguments.claim_file]
    if getattr(arguments, "started_file", None):
        command += ["--started-file", arguments.started_file]
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


def spell(seconds):
    """A wait's length in words: "35 s", "9 min 35 s", "20 min"."""
    minutes, rest = divmod(round(seconds), 60)
    if not minutes:
        return f"{rest} s"
    return f"{minutes} min" + (f" {rest} s" if rest else "")


def one_minute_load():
    """The Mac's count of tasks running or waiting for a processor,
    averaged over the last minute."""
    return os.getloadavg()[0]


def add_to_record(path, line):
    """Adds a line, with its time, to the simulator's record. One short
    line at a time, added to the end: the watcher writes the same file."""
    try:
        with open(path, "a", encoding="utf-8") as record:
            record.write(f"{clock_time()} {line}\n")
    except OSError as error:
        print(f"warning: could not write to {path}: {error}", file=sys.stderr)


def simulator_waiting(system, udid):
    """A function that counts the simulator's threads running or waiting
    for a processor now, or raises OSError; it reads launchd_sim's
    arguments again only once that launchd_sim has gone."""
    found = [None]

    def count():
        table = system.table()
        if not (found[0] in table and table[found[0]][2] == LAUNCHD_SIM):
            found[0] = find_root(system, table, udid)
        if found[0] is None:
            return 0
        total = 0
        for pid in descendants(found[0], table):
            state = system.state(pid)
            if state is not None:
                total += state[2]
        return total
    return count


def settle(arguments, load=one_minute_load, processors=os.cpu_count, clock=time.monotonic,
           sleep=time.sleep, waiting=None):
    """Waits until the Mac has settled (the module's description says
    what that is and why), or until the limit, and says which in the log
    and in the record. Its status is 0 however the wait ends: the tests
    run either way.

    With --udid, the simulator is held in the background band while it
    waits, and the Mac's load leaves out threads in that band: on pull
    request #132's first CI run the load fell to 21 to 90 while the
    simulator was lowered, every wait ended on its first readings, and
    the start-up work, returned to normal priority, then ran during the
    tests at loads up to 454. So each reading adds the simulator's
    threads running or waiting for a processor, averaged over a minute as
    the load is (an exponential average, five seconds a reading), to the
    load. That counts iOS's own background threads too, which the load
    always left out, so the wait is if anything longer than before."""
    count = processors() or 1
    wanted = SETTLED_LOAD * count
    udid = getattr(arguments, "udid", None)
    if waiting is None and udid:
        system = (ProcessFile(arguments.processes) if getattr(arguments, "processes", None)
                  else MacProcesses())
        waiting = simulator_waiting(system, udid)
    decay = math.exp(-INTERVAL / 60.0)

    def note(line):
        add_to_record(arguments.out, line)

    began = said = clock()
    under, first, average = 0, True, None
    while True:
        try:
            reading = mac = load()
        except OSError as error:
            print(f"warning: the Mac's load could not be read ({error}), so the tests start "
                  "without waiting for it to settle.", file=sys.stderr)
            note(f"the Mac's load could not be read ({error}); the tests run without the wait")
            break
        detail = ""
        if waiting is not None:
            try:
                threads = waiting()
            except OSError as error:
                print(f"warning: the simulator's threads in the background could not be counted "
                      f"({error}), so the wait reads the Mac's load alone.", file=sys.stderr)
                note(f"the simulator's threads in the background could not be counted ({error}); "
                     "the wait reads the load alone")
                waiting = None
            else:
                average = threads if average is None else average * decay + threads * (1 - decay)
                reading = mac + average
                detail = f" (the Mac's {mac:.1f} and {average:.1f} of the simulator's threads in the background)"
        now = clock()
        waited = now - began
        if first:
            first = False
            print(f"Waiting for the Mac to settle before the tests: its load is {reading:.0f}"
                  + (", counting the simulator's threads in the background" if detail else "")
                  + f", and they start once it has stayed under {wanted:.0f} ({SETTLED_LOAD:.0f} "
                  f"for each of its {count} processors), or after {spell(arguments.limit)}.",
                  flush=True)
            note(f"waiting for the Mac to settle before the tests: load {reading:.1f}{detail}, "
                 f"wanted under {wanted:.0f}")
        under = under + 1 if reading < wanted else 0
        if under >= SETTLED_READINGS:
            print(f"The Mac settled after {spell(waited)}: load {reading:.0f}.", flush=True)
            note(f"the Mac settled after {waited:.0f} s: load {reading:.1f}{detail}")
            break
        if waited >= arguments.limit:
            print(f"warning: the Mac had not settled after {spell(waited)} (load {reading:.0f}, "
                  f"wanted under {wanted:.0f}); the tests run anyway.", file=sys.stderr)
            note(f"the Mac had not settled after {waited:.0f} s: load {reading:.1f}{detail}; "
                 "the tests run anyway")
            break
        if now - said >= SETTLE_SAYS:
            said = now
            print(f"  still settling after {spell(waited)}: load {reading:.0f}", flush=True)
        sleep(INTERVAL)
    return 0


def wait_for_line(path, text, wait, pid=None, is_alive=alive):
    """The record's first line holding `text`, once it is written; None
    when `wait` seconds pass first, or the watcher `pid` is gone first."""
    deadline = time.monotonic() + wait
    while True:
        found = next((line for line in record_lines(path) if text in line), None)
        if found is not None:
            return found
        if time.monotonic() >= deadline or (pid is not None and not is_alive(pid)):
            return None
        time.sleep(0.05)


def restore(arguments, system=None, wait=WAIT, is_alive=alive, kill=os.kill):
    """Returns the simulator's processes to normal priority before the
    tests and checks that they are there (the module's description says
    how and why). Status 0 once confirmed, 1 when it cannot be; either way
    the log and the record say what was found."""
    if system is None:
        system = ProcessFile(arguments.processes) if arguments.processes else MacProcesses()

    def say(line, failed=False):
        print(("error: " if failed else "") + line, file=sys.stderr if failed else sys.stdout,
              flush=True)
        add_to_record(arguments.out, line)

    pid = arguments.pid

    def end_watcher(why):
        """Ends the watcher, so it can put nothing in the background after
        the processes are returned: asked first, so it lets the wallpaper
        extensions it paused run again and says "Stopped.", then killed if
        it does not."""
        try:
            kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        if wait_for_line(arguments.out, STOPPED, wait, pid, is_alive) is None and is_alive(pid):
            try:
                kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        say(f"the simulator watcher ({pid}) {why}, so it was stopped; nothing is paused from now on")

    if pid is not None and is_alive(pid):
        # A watcher still starting (`start` leaves one to start) would
        # find the claim and lower the simulator once it began, after the
        # return: it is given time to begin, or ended.
        if wait_for_line(arguments.out, "Watching simulator", wait, pid, is_alive) is None:
            if is_alive(pid):
                try:
                    kill(pid, signal.SIGKILL)  # It has paused and lowered nothing.
                except ProcessLookupError:
                    pass
                say(f"the simulator watcher ({pid}) had not begun within {wait:.0f} s, so it was "
                    "stopped; it had paused and lowered nothing")
        else:
            try:
                kill(pid, signal.SIGUSR1)
            except ProcessLookupError:
                pass
            else:
                if (wait_for_line(arguments.out, STOPPED_LOWERING, wait, pid, is_alive) is None
                        and is_alive(pid)):
                    end_watcher(f"did not say within {wait:.0f} s that it had stopped putting "
                                "processes in the background")
    problems, returned, ended = [], set(), set()
    converged, passes, root = False, 0, None
    try:
        while True:
            table = system.table()
            root = find_root(system, table, arguments.udid)
            if root is None:
                break
            waiting = [found for found in root_first(root, descendants(root, table))
                       if found not in returned and found not in ended]
            if not waiting:
                converged = True
                break
            if passes == RESTORE_PASSES:
                break
            passes += 1
            for found in waiting:
                try:
                    system.set_background(found, False)
                except ProcessLookupError:
                    ended.add(found)
                except OSError as error:
                    ended.add(found)
                    problems.append(f"{table[found][2]} ({found}) could not be returned: {error}")
                else:
                    returned.add(found)
        if root is None:
            problems.append(f"the simulator {arguments.udid}'s launchd_sim was not found")
        elif not converged:
            problems.append(f"after {passes} passes new processes were still appearing")
        readings = []
        if root is not None:
            table = system.table()
            family = descendants(root, table)
            for name in NEVER_IN_BACKGROUND:
                found = [each for each in sorted(family) if table[each][2] == name]
                state = system.state(found[0]) if found else None
                if state is None:
                    if name == LAUNCHD_SIM:
                        problems.append("launchd_sim could not be read back")
                    else:
                        readings.append(f"{name} was not running")
                    continue
                readings.append(f"{name} at {state[1]}")
                if state[1] <= BACKGROUND_PRIORITY:
                    problems.append(f"{name} ({found[0]}) is still in the background")
            states = [system.state(each) for each in family]
            states = [state for state in states if state is not None]
            low = sum(1 for state in states if state[1] <= BACKGROUND_PRIORITY)
    except OSError as error:
        problems.append(f"the process list could not be read: {error}")
        readings, states, low = [], [], 0
    if problems:
        say("could not confirm that the simulator's processes are back at normal priority: "
            + "; ".join(problems) + (" (read back: " + ", ".join(readings) + ")" if readings else ""),
            failed=True)
        return 1
    say(f"returned the simulator's {len(returned)} processes to normal priority in {passes} "
        f"pass{'es' if passes != 1 else ''}, until a pass found none it had not returned"
        + (f" ({len(ended)} had ended)" if ended else "")
        + "; read back: " + ", ".join(readings)
        + f"; {low} of the {len(states)} running now are in the background as iOS runs them")
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
        command.add_argument("--background", action="store_true")
        command.add_argument("--claim-file")
        command.add_argument("--started-file")
        # scripts/test-runner.py gives a stand-in for the Mac's process
        # calls (ProcessFile).
        command.add_argument("--processes", help=argparse.SUPPRESS)
    stopping = commands.add_parser("stop")
    stopping.add_argument("--pid", type=int, required=True)
    stopping.add_argument("--out", required=True)
    restoring = commands.add_parser("restore")
    restoring.add_argument("--udid", required=True)
    restoring.add_argument("--out", required=True)
    restoring.add_argument("--pid", type=int)
    restoring.add_argument("--processes", help=argparse.SUPPRESS)
    settling = commands.add_parser("settle")
    settling.add_argument("--out", required=True)
    settling.add_argument("--limit", type=float, default=SETTLE_LIMIT)
    settling.add_argument("--udid")
    settling.add_argument("--processes", help=argparse.SUPPRESS)
    return parser.parse_args(arguments)


def main():
    arguments = parse()
    return {"start": start, "watch": watch, "stop": stop,
            "settle": settle, "restore": restore}[arguments.command](arguments)


if __name__ == "__main__":
    sys.exit(main())
