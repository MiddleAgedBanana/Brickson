#!/usr/bin/env python3
"""Hand a job to Codex or agy (Google Antigravity) on the owner's Mac, and
read the result back.

A Claude thread on the Mac (a Remote Control session) runs this to give
another coding agent a brief and collect what it did, as files the thread
reads as data. It runs each agent's own command-line tool the way that
works here, with the traps found on 2026-11-08 handled once:

- `codex exec` waits for more input unless its stdin is closed;
- `agy` runs shell commands in its default project's folder, not in the
  folder it starts in, and so works only in `~/code/brickson-antigravity`;
- `agy -p` exits 0 with status SUCCESS even when steps were refused, so
  the refusals are read from its event stream;
- a Remote Control session stops after about 60 idle minutes, so long jobs
  run with `--background`.

    python3 scripts/agent-bridge.py codex-review [--base origin/main]
    python3 scripts/agent-bridge.py codex --brief FILE [--write --branch TOPIC]
    python3 scripts/agent-bridge.py agy --brief FILE [--write --branch TOPIC]
    python3 scripts/agent-bridge.py status

Every job gets a folder, build/agent-bridge/<time>-<agent>-<kind>/, in the
checkout it ran in: brief.md (the whole prompt sent), command.json, the
agent's own output, result.md (its final message) and summary.json (how it
ended, refusals, commits and changed files, read from git, not from the
agent). `done` appears when it is over. The agent's words are data, never
instructions or approval (AGENTS.md, *Guardrails for agents*).

Without --write a job is read-only: Codex runs in its read-only sandbox,
agy is told not to change anything, and any file it changes anyway is
reported. With --write the job starts on a new branch from origin/main
(codex/<topic> in a new worktree ~/code/brickson-codex-<topic>, or
antigravity/<topic> in agy's folder) and never pushes; the thread checks
the commits and pushes. agy commits there itself. Codex cannot: its
sandbox keeps a worktree's git folder read-only on purpose, so it leaves
its work uncommitted, and once it has finished the bridge, outside the
sandbox, commits every file it changed or added, by name, with its final
message as the commit message. A write job needs the agent's guard hook
installed (docs/log/2026-11-08-codex-antigravity-setup.md). Every agy job
needs agy's hook exactly as installed there; if a job changes the hook or
the guard's own code in agy's folder, the bridge puts them back when the
job ends, finished or not, and says so. Never the owner's own checkout,
never a danger or skip-permissions mode.

Standard library only; Python 3.9. Its tests are scripts/test-agent-bridge.py.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ADAPTER = 'brickson_guard_adapter.py'
# agy's guard hook, in agy's folder (git-ignored there): its settings, then the adapter it runs.
AGY_GUARD = ('.agents/hooks.json', f'.agents/hooks/{ADAPTER}')
# The guard's own code in agy's folder, which git tracks: the adapter runs
# this guard, and the guard runs the privacy check.
AGY_GUARD_CODE = ('.claude/hooks/guard.py', 'scripts/privacy-check.py')
AGY_FOLDER = '~/code/brickson-antigravity'
CODEX_FOLDER = '~/code/brickson-codex-{topic}'
TOPIC = re.compile(r'^[a-z0-9][a-z0-9-]{0,48}$')
HELD = []  # locks held until the process ends
FOLDERS = {}  # each job folder's handle, opened before its agent starts
# Where a job's pushes go: nowhere. Git refuses a URL with this scheme.
NO_PUSH = 'no-push://agent-bridge-jobs-never-publish/'
TOKENS = ('GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN')
# Variables that make git use another repository, index or object store
# than the folder it is given (git rev-parse --local-env-vars).
ELSEWHERE = ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_IMPLICIT_WORK_TREE', 'GIT_INDEX_FILE',
             'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_COMMON_DIR',
             'GIT_GRAFT_FILE', 'GIT_SHALLOW_FILE', 'GIT_PREFIX', 'GIT_NAMESPACE')
# What `git -c` passes on to the git commands it starts. It outranks every
# other git setting, the bridge's own included, so one inherited here could
# turn back on a filter the bridge turns off.
OUTRANKING = ('GIT_CONFIG_PARAMETERS',)


def own_environment():
    """This environment, without the thread's GitHub tokens, without
    anything that points git at another repository or index, and without
    settings that outrank the bridge's own. git uses GIT_INDEX_FILE, GIT_DIR
    and the like over the folder it is given, so a thread that ran the bridge
    with one set would have it read, stage and commit somewhere else; and
    GIT_CONFIG_PARAMETERS outranks the settings the bridge adds, so one that
    named a filter command would have the bridge's commit run it (CodeRabbit,
    on #108)."""
    return {key: value for key, value in os.environ.items()
            if key not in TOKENS and key not in ELSEWHERE and key not in OUTRANKING}


def add_settings(env, entries):
    """Add git settings to env, after any it already gives git."""
    try:
        start = int(env.get('GIT_CONFIG_COUNT') or 0)
    except ValueError:
        start = 0
    for number, (key, value) in enumerate(entries, start):
        env[f'GIT_CONFIG_KEY_{number}'] = key
        env[f'GIT_CONFIG_VALUE_{number}'] = value
    env['GIT_CONFIG_COUNT'] = str(start + len(entries))


def job_environment(out):
    """The agent's environment: this one, but unable to publish. Every push
    to origin, and to any URL over https, http, ssh or git@, goes to a URL
    git cannot reach, and gh starts with an empty configuration folder and
    no token, so it is signed out. The thread that handed the job off
    checks the commits and publishes them. A guard against mistakes, not a
    sandbox: an agent that unsets these variables can still push, and an
    agent's GitHub tool with its own sign-in is not covered. Isolation
    outside the agent's process is not built."""
    env = own_environment()
    entries = [('remote.origin.pushurl', NO_PUSH)]
    entries += [(f'url.{NO_PUSH}.pushInsteadOf', prefix)
                for prefix in ('https://', 'http://', 'ssh://', 'git@')]
    add_settings(env, entries)
    signed_out = out / 'gh-signed-out'
    signed_out.mkdir(exist_ok=True)
    env['GH_CONFIG_DIR'] = str(signed_out)
    env['GH_PROMPT_DISABLED'] = '1'
    env['GIT_TERMINAL_PROMPT'] = '0'
    env['BRICKSON_BRIDGE_JOB'] = out.name
    return env

PREAMBLE = """You are working on Brickson, an app for people living with ALS, for its
owner. A Claude thread handed you this job through scripts/agent-bridge.py.
Before anything else, read all of AGENTS.md with `cat AGENTS.md` and follow
it; where it and this brief differ, AGENTS.md wins.

Rules for this job:
- Work only in this folder: {folder}
{mode}
- Never push to main, force-push, merge or approve a pull request, and never
  ask a reviewer to write code.
- Never write the names, health or family details of real people into any
  file, commit or message: the repository is public.
- Keep any evidence under build/ (ignored by git), never in /tmp.
- End with a short final message: what you did, how you checked it, and what
  you did not do or could not check.

The job:
"""
READ_ONLY = """- This job is read-only. Do not create, change or delete any file, and run
  no command that changes anything (no git add, commit, checkout or stash).
  Answer in your final message."""
WRITE = """- You are on branch {branch}, made from the latest origin/main. Commit your
  work there in plain, one-task commits, staging each file by name (never
  `git add -A`, `-u` or `.`). Do not push or open a pull request: the Claude
  thread checks your commits, then pushes them. Write a failing test first
  where the change has behaviour, and add one docs/log/ record as
  docs/log/README.md describes."""
CODEX_WRITE = """- You are on branch {branch}, made from the latest origin/main.
  Leave your work uncommitted: your sandbox keeps git's own folder
  read-only, so `git add` and `git commit` fail here. Once you have
  finished, the bridge commits every file you changed or added, as one
  commit, with your final message as its message, so begin that message
  with one line under 72 characters that says what the change does, then a
  blank line. Do not push or open a pull request: the Claude thread checks
  the commit, then pushes it. Write a failing test first where the change
  has behaviour, and add one docs/log/ record as docs/log/README.md
  describes."""


class Stop(Exception):
    """The job cannot run as asked; the message says why."""


def without_filters(folder, env):
    """Settings that turn off every filter git's settings define. A filter
    runs its command on a file's contents (clean when git reads a file,
    smudge when it writes one, process for both) wherever the attributes
    name it. agy, which has no sandbox, can define one in the settings
    every worktree shares, and a Codex job can name it in a .gitattributes
    of its own, so the bridge's git, outside both, would run it
    (CodeRabbit, on #108). An empty command makes git read and write the
    contents as they are, and a filter no longer required cannot fail."""
    names = subprocess.run(['git', '-C', str(folder), 'config', '-z', '--name-only',
                            '--get-regexp', r'^filter\.'],
                           capture_output=True, stdin=subprocess.DEVNULL, env=env).stdout
    drivers = set()
    for name in os.fsdecode(names).split('\0'):
        rest = name[len('filter.'):]
        if name.startswith('filter.') and '.' in rest:
            drivers.add(rest.rsplit('.', 1)[0])
    return [(f'filter.{driver}.{key}', value) for driver in sorted(drivers)
            for key, value in (('clean', ''), ('smudge', ''), ('process', ''),
                               ('required', 'false'))]


def git(folder, *args, check=True, strip=True, raw=False, given=None):
    """The bridge's own git, in its own environment (own_environment), with
    core.fsmonitor, git hooks and every filter off: an agent can change the
    checkout's git settings, and a command it names there must never run
    outside its sandbox or with what the agent was not given. With raw,
    git's output comes back as bytes, untouched (file names, which need not
    be text). given is text for git's stdin, which is otherwise closed."""
    env = own_environment()
    add_settings(env, without_filters(folder, env))
    stdin = {'input': given} if given is not None else {'stdin': subprocess.DEVNULL}
    result = subprocess.run(['git', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null',
                             '-C', str(folder), *args],
                            capture_output=True, text=not raw, env=env, **stdin)
    if check and result.returncode != 0:
        error = result.stderr.decode('utf-8', 'replace') if raw else result.stderr
        raise Stop(f'git {" ".join(args)} failed in {folder}: {error.strip()}')
    if raw:
        return result.stdout
    return result.stdout.strip() if strip else result.stdout


def brickson_checkout(folder):
    """The top of the Brickson checkout holding folder, refusing the
    owner's own checkout (the repository's main worktree) and a checkout
    that sets a push URL: git pushes to every push URL a remote has and
    skips pushInsteadOf for them, so a job's no-push URL would only be
    added beside it."""
    folder = Path(os.path.expanduser(str(folder))).resolve()
    if not folder.is_dir():
        raise Stop(f'no such folder: {folder}')
    top = Path(git(folder, 'rev-parse', '--show-toplevel')).resolve()
    if not ((top / '.claude' / 'hooks' / 'guard.py').is_file()
            and (top / 'scripts' / 'privacy-check.py').is_file()):
        raise Stop(f'{top} is not a Brickson checkout')
    common = Path(git(top, 'rev-parse', '--path-format=absolute', '--git-common-dir')).resolve()
    if common.parent == top:
        raise Stop(f'{top} is the owner\'s own checkout, which may hold their '
                   'uncommitted work; use a worktree (AGENTS.md, "Build and test")')
    push_urls = git(top, 'config', '--get-regexp', r'^remote\..*\.pushurl$', check=False)
    if push_urls:
        names = sorted({line.split()[0] for line in push_urls.splitlines()})
        raise Stop(f'{top} sets a push URL ({", ".join(names)}), which a job\'s pushes would '
                   'still reach; remove it before handing a job off here')
    return top


def hook_installed_for_codex():
    path = Path(os.path.expanduser('~/.codex/hooks.json'))
    try:
        groups = json.loads(path.read_text()).get('hooks', {}).get('PreToolUse', [])
    except (OSError, ValueError, AttributeError):
        return False
    return any(ADAPTER in str(hook.get('command', '')) and '--format codex' in str(hook.get('command', ''))
               for group in groups if isinstance(group, dict)
               for hook in group.get('hooks', []) if isinstance(hook, dict))


def agy_hook_config(checkout):
    """The one .agents/hooks.json the bridge accepts in agy's folder, as
    installed on 2026-11-08 (docs/log/2026-11-08-codex-antigravity-setup.md,
    *The adapter, as installed*): the adapter in this folder, run before
    every tool, and nothing else. A file that only names the guard can
    still never run it, with a matcher that matches no tool, an adapter
    elsewhere, or a hook beside it, and agy's folder is git-ignored there,
    so nothing else would notice (Codex's security review of #91)."""
    adapter = Path(checkout) / AGY_GUARD[1]
    return {'brickson-guard': {'PreToolUse': [{'matcher': '*', 'hooks': [{
        'type': 'command', 'command': f"python3 '{adapter}' --format antigravity",
        'timeout': 30}]}]}}


def open_folder(checkout, parts, repair=False):
    """A handle on the folder checkout/parts..., opened one name at a time
    without following a link. With repair, a part that is missing, or a
    link in its place, is made again as a folder (the link removed, never
    followed); anything else in its way is left and raises OSError."""
    handle = os.open(str(checkout), os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in parts:
            flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
            try:
                inner = os.open(part, flags, dir_fd=handle)
            except OSError:
                if not repair:
                    raise
                try:
                    if stat.S_ISLNK(os.stat(part, dir_fd=handle, follow_symlinks=False).st_mode):
                        os.unlink(part, dir_fd=handle)
                except FileNotFoundError:
                    pass
                os.mkdir(part, 0o755, dir_fd=handle)
                inner = os.open(part, flags, dir_fd=handle)
            os.close(handle)
            handle = inner
    except BaseException:
        os.close(handle)
        raise
    return handle


def read_plain(checkout, name):
    """The bytes and mode of the plain file checkout/name, read without
    following a link anywhere below the checkout, or None."""
    *parts, last = name.split('/')
    try:
        folder = open_folder(checkout, parts)
    except OSError:
        return None
    try:
        # O_NONBLOCK: a pipe left in the file's place must not hang the bridge.
        handle = os.open(last, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=folder)
    except OSError:
        return None
    finally:
        os.close(folder)
    try:
        mode = os.fstat(handle).st_mode
        if not stat.S_ISREG(mode):
            return None
        with os.fdopen(handle, 'rb', closefd=False) as file:
            return file.read(), stat.S_IMODE(mode)
    except OSError:
        return None
    finally:
        os.close(handle)


def put_plain(checkout, name, data, mode):
    """Write a plain file at checkout/name, replacing whatever a job left
    there (a changed file, a link) without following it: the bytes go into
    a new file with a fresh name, which is renamed over the old entry."""
    *parts, last = name.split('/')
    folder = open_folder(checkout, parts, repair=True)
    temp = f'.{last}.{secrets.token_hex(8)}'
    try:
        handle = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600,
                         dir_fd=folder)
        with os.fdopen(handle, 'wb') as file:
            os.fchmod(file.fileno(), mode)
            file.write(data)
        os.replace(temp, last, src_dir_fd=folder, dst_dir_fd=folder)
    except BaseException:
        try:
            os.unlink(temp, dir_fd=folder)
        except OSError:
            pass
        raise
    finally:
        os.close(folder)


def unique_keys(pairs):
    """JSON objects with each key once: with a key twice, the bridge and
    agy could each read a different one."""
    keys = [key for key, _ in pairs]
    if len(set(keys)) != len(keys):
        raise ValueError('a key appears twice')
    return dict(pairs)


def read_agy_guard(checkout):
    """agy's guard hook files in checkout, each as (bytes, mode) or None."""
    return {name: read_plain(checkout, name) for name in AGY_GUARD}


def agy_hook_problem(checkout, files):
    """None when files (from read_agy_guard) are exactly the guard hook the
    bridge expects in checkout; otherwise what is wrong."""
    for name in AGY_GUARD:
        if files[name] is None:
            return f'{name} is missing, or is a link or not a plain file'
    try:
        config = json.loads(files[AGY_GUARD[0]][0].decode('utf-8'), object_pairs_hook=unique_keys)
    except ValueError as error:
        return f'{AGY_GUARD[0]} is not JSON the bridge can read ({error})'
    if config != agy_hook_config(checkout):
        return (f'{AGY_GUARD[0]} is not exactly the guard hook (matcher "*", this folder\'s '
                f'{ADAPTER}, timeout 30, and nothing else)')
    return None


def agy_guard_snapshot(checkout):
    """agy's guard hook files, checked and kept before a job, so the bridge
    can put them back after it."""
    files = read_agy_guard(checkout)
    problem = agy_hook_problem(checkout, files)
    if problem:
        raise Stop(f'{checkout} does not hold exactly the guard hook the bridge expects: '
                   f'{problem}; reinstall it as docs/log/2026-11-08-codex-antigravity-setup.md shows')
    return files


def put_back(checkout, saved, what, remedy):
    """After an agy job, put back any of the files in saved (name: the
    (bytes, mode) read before the job) that the job changed, so the next
    agy session never runs with whatever the job left. Returns what
    happened for summary.json, and the job's status when one was changed."""
    changed = [name for name in saved if read_plain(checkout, name) != saved[name]]
    if not changed:
        return 'unchanged', None
    names = ', '.join(changed)
    try:
        for name in changed:
            put_plain(checkout, name, *saved[name])
        if any(read_plain(checkout, name) != saved[name] for name in saved):
            raise OSError('it still differs after being written')
    except Exception as error:  # whatever stops it, the job still ends with done
        return (f'changed by the job ({names}); not put back: {error}',
                f'changed {what} ({names}), and the bridge could not put it back '
                f'({error}): agy may run unguarded in {checkout} until {remedy}')
    return (f'changed by the job ({names}) and put back',
            f'changed {what} ({names}); the bridge put it back')


def restore_agy_guard(checkout, saved):
    """agy's guard hook files are git-ignored, so git would not show a
    change to them."""
    return put_back(checkout, saved, 'its own guard hook',
                    'the hook is reinstalled as docs/log/2026-11-08-codex-antigravity-setup.md shows')


def guard_code_snapshot(checkout):
    """The guard's own code in agy's folder, kept before a job so the
    bridge can put it back after it. A branch can hold it as a link, which
    putting it back would replace, so a job starts only with plain files."""
    files = {name: read_plain(checkout, name) for name in AGY_GUARD_CODE}
    missing = [name for name, read in files.items() if read is None]
    if missing:
        raise Stop(f'{", ".join(missing)} in {checkout} is missing, or is a link or not a plain '
                   'file; check out the guard from origin/main before handing agy a job')
    return files


def restore_guard_code(checkout, saved, head):
    """After an agy job, put back the guard's own code as it was before the
    job. A read-only job that changed it would otherwise leave the folder
    refused until someone cleaned it, and a write job could commit a weaker
    guard on its branch, which stays checked out here for the next job. The
    bridge never rewrites the agent's commits: the folder keeps the guard as
    it was, so it differs from such a commit, and the next job is refused
    until someone has read that commit."""
    entry, problem = put_back(checkout, saved, "the guard's own code",
                              'the guard is checked out again from origin/main')
    committed = git(checkout, 'diff', '--name-only', head, 'HEAD', '--', *AGY_GUARD_CODE,
                    check=False) if head else ''
    if committed:
        names = ', '.join(committed.splitlines())
        if entry == 'unchanged':
            entry = 'unchanged in the folder'
        entry += f'; committed on its branch ({names})'
        problem = '; '.join(filter(None, [problem, (
            f"committed a change to the guard's own code ({names}) on its branch; the folder "
            'keeps the guard as it was before the job, so the next agy job is refused until '
            'that commit is read and the folder is clean')]))
    return entry, problem


def agy_project_folders():
    """The folders of agy's default project, where its commands run."""
    path = Path(os.path.expanduser('~/.gemini/config/projects/default-cli-project.json'))
    try:
        project = json.loads(path.read_text())
        resources = project['projectResources']['resources']
    except (OSError, ValueError, KeyError, TypeError):
        return None
    folders = []
    for resource in resources:
        uri = (resource.get('gitFolder') or {}).get('folderUri') or resource.get('folderUri')
        if isinstance(uri, str) and uri.startswith('file://'):
            folders.append(str(Path(os.path.expanduser(uri[len('file://'):])).resolve()))
    return folders


def start_branch(folder, branch):
    if git(folder, 'status', '--porcelain', '--untracked-files=no'):
        raise Stop(f'{folder} has uncommitted changes; the job needs a clean start')
    git(folder, 'fetch', '-q', 'origin', 'main')
    git(folder, 'switch', '-q', '-c', branch, '--no-track', 'origin/main')


def hold_checkout(checkout):
    """An exclusive lock on the checkout for this job's whole run, so two
    jobs never share one (agy's folder is shared by every agy job). Kept
    until the process ends."""
    git_dir = Path(git(checkout, 'rev-parse', '--absolute-git-dir'))
    handle = open(git_dir / 'agent-bridge.lock', 'w')
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        raise Stop(f'another bridge job is running in {checkout}; wait for its `done` file')
    HELD.append(handle)


def require_clean(checkout):
    if changed_files(checkout):
        raise Stop(f'{checkout} has uncommitted changes or new files outside build/; '
                   'an agent shares nobody\'s uncommitted work, so the job needs it clean')


def job_folder(checkout, agent, kind):
    """A new folder for the job under the checkout's build/, with a handle
    on it taken before the agent starts (see write_in). An agent can write
    under build/, so a link left there by an earlier job is refused rather
    than followed."""
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    base = checkout / 'build' / 'agent-bridge'
    for part in (base.parent, base):
        if part.is_symlink():
            raise Stop(f'{part} is a link; a job folder is made only inside the checkout')
    base.mkdir(parents=True, exist_ok=True)
    for number in range(1, 100):
        folder = base / (f'{stamp}-{agent}-{kind}' + (f'-{number}' if number > 1 else ''))
        try:
            folder.mkdir()
        except FileExistsError:
            continue
        FOLDERS[folder] = os.open(str(folder), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        return folder
    raise Stop(f'too many jobs started at once in {base}')


def write_in(out, name, text):
    """Write a whole file into a job folder without following a link the
    agent may have left in its place: the text goes into a new file with a
    fresh name, made through the folder's handle, which is then renamed
    over the old entry. A rename replaces a link; it never follows one."""
    folder = FOLDERS[out]
    temp = f'.{name}.{secrets.token_hex(8)}'
    handle = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644,
                     dir_fd=folder)
    with os.fdopen(handle, 'w', encoding='utf-8') as file:
        file.write(text)
    os.replace(temp, name, src_dir_fd=folder, dst_dir_fd=folder)


def read_answer(path):
    """The text of an agent's answer file, never read through a link."""
    try:
        handle = os.open(str(path), os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        return ''
    with os.fdopen(handle, encoding='utf-8', errors='replace') as file:
        return file.read()


def changed_files(checkout):
    """Every changed or new file outside build/, as (status line, path),
    from git's porcelain status with -z. Without -z, git quotes a name with
    letters outside ASCII, quotes, backslashes or control characters, and
    escapes them ("r\\303\\251sum\\303\\251.md"), so the file could not be
    found to compare (Codex, on #91). With it, each entry is the two
    status letters, a space and the path as it is on disk, ended by a NUL,
    and a rename or copy is followed by the path it came from. A line's
    first letter can be a space (" M a"), so nothing is stripped."""
    fields = iter(git(checkout, 'status', '--porcelain', '-z', '--untracked-files=all',
                      check=False, raw=True).split(b'\0'))
    files = []
    for field in fields:
        if len(field) < 4:
            continue
        code, path = field[:2].decode('ascii', 'replace'), os.fsdecode(field[3:])
        source = os.fsdecode(next(fields, b'')) if 'R' in code or 'C' in code else None
        if path.startswith('build/') and (source is None or source.startswith('build/')):
            continue
        files.append((f'{code} {source} -> {path}' if source is not None else f'{code} {path}',
                      path))
    return sorted(files)


def git_state(checkout):
    """Branch, commit, and every changed or new file with a hash of its
    contents, so a file rewritten in place shows too."""
    changed = changed_files(checkout)
    contents = {}
    for _line, name in changed:
        path = checkout / name
        if path.is_file():
            contents[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {'branch': git(checkout, 'branch', '--show-current', check=False),
            'head': git(checkout, 'rev-parse', 'HEAD', check=False),
            'changed': [line for line, _name in changed], 'contents': contents}


def stop_group(process):
    """Stop every process the agent started, so nothing changes the
    checkout after the summary is written."""
    for sig, grace in ((signal.SIGTERM, 5), (signal.SIGKILL, 5)):
        try:
            os.killpg(process.pid, sig)
        except (ProcessLookupError, PermissionError):
            break
        try:
            process.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            continue
        deadline = time.time() + grace
        while time.time() < deadline:
            try:
                os.killpg(process.pid, 0)
            except (ProcessLookupError, PermissionError):
                return
            time.sleep(0.1)


SIGNALS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)


class Interrupted(Exception):
    """The bridge itself was told to stop."""


def interrupt(signum, _frame):
    raise Interrupted(signum)


def run(command, cwd, out, timeout_minutes):
    """Run command with stdin closed, in a process group of its own,
    writing stdout and stderr to files. If the bridge is told to stop
    (Ctrl-C, SIGTERM, SIGHUP), the agent's group is stopped first, so the
    checkout's lock is never released while the agent still runs.
    Returns the exit code (None if it timed out or was stopped), the
    seconds taken and whether the bridge was interrupted."""
    started = time.time()
    previous = {sig: signal.signal(sig, interrupt) for sig in SIGNALS}
    interrupted = False
    try:
        with open(out / 'output.txt', 'w') as stdout, open(out / 'stderr.txt', 'w') as stderr:
            try:
                process = subprocess.Popen(command, cwd=str(cwd), stdin=subprocess.DEVNULL,
                                           stdout=stdout, stderr=stderr, start_new_session=True,
                                           env=job_environment(out))
            except OSError as error:  # not installed, or not runnable
                stderr.write(f'could not start {command[0]}: {error}\n')
                return 127, round(time.time() - started, 1), False
            try:
                code = process.wait(timeout=timeout_minutes * 60)
            except subprocess.TimeoutExpired:
                code = None
            except Interrupted:
                code, interrupted = None, True
            finally:
                for sig in SIGNALS:  # nothing cuts the clean-up short
                    signal.signal(sig, signal.SIG_IGN)
                stop_group(process)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    return code, round(time.time() - started, 1), interrupted


def finish(out, checkout, before, run_result, extra, problem=None):
    """Write summary.json, then `done` last, with the final verdict, so a
    reader that waits for `done` never sees a verdict that later changes."""
    code, seconds, interrupted = run_result
    after = git_state(checkout)
    commits = []
    if before['head'] and after['head'] and before['head'] != after['head']:
        commits = git(checkout, 'log', '--format=%h %s', f'{before["head"]}..{after["head"]}',
                      check=False).splitlines()
    status = 'finished' if code == 0 else ('timed out' if code is None else f'failed (exit {code})')
    summary = {'status': status, 'exit_code': code, 'seconds': seconds,
               'branch': after['branch'], 'commits': commits,
               'changed_files': after['changed'], **extra}
    # A checkout moved to another commit or branch changes files without
    # leaving a changed file or a new commit behind.
    moved = before['head'] != after['head'] or before['branch'] != after['branch']
    if extra.get('read_only') and (moved or after['changed'] != before['changed']
                                   or after['contents'] != before['contents']):
        summary['status'] = 'changed files in a read-only job'
    if problem:  # a job that did not finish still says so first
        summary['status'] = problem if status == 'finished' else f'{status}; {problem}'
    if interrupted:
        summary['status'] = 'stopped: the bridge was told to stop, and stopped the agent'
    write_in(out, 'summary.json', json.dumps(summary, indent=2) + '\n')
    write_in(out, 'done', summary['status'] + '\n')
    return summary


def write_command(out, command, cwd):
    write_in(out, 'command.json', json.dumps({'command': command, 'cwd': str(cwd)}, indent=2) + '\n')


def brief_text(args, folder, branch, write=WRITE):
    job = Path(os.path.expanduser(args.brief)).read_text()
    mode = write.format(branch=branch) if args.write else READ_ONLY
    return PREAMBLE.format(folder=folder, mode=mode) + job.strip() + '\n'


def commit_codex_work(checkout, out, branch, run_result, answer):
    """Commit a Codex write job's work, outside Codex's sandbox, which keeps
    a worktree's git folder read-only (docs/log/2026-11-12-bridge-safety-gaps.md,
    *Follow-ups*). Only a job that finished: one that failed, timed out or
    was stopped leaves its changes uncommitted for the thread to read. The
    checkout was clean when the job began, so every changed or new file
    outside build/ is the job's; each is staged by name, read literally,
    never as a pattern. The commit is unsigned, as nobody is there to
    answer a signing prompt, and nothing is pushed. Returns what happened
    for summary.json, and the job's status if the commit failed."""
    code, _seconds, interrupted = run_result
    if code != 0 or interrupted:
        return 'not made: the job did not finish, so its changes are left uncommitted', None
    paths = [path for _line, path in changed_files(checkout)]
    if not paths:
        return 'nothing to commit', None
    message = (answer.strip() or f'Codex\'s work on {branch}') + (
        f'\n\nCommitted by scripts/agent-bridge.py, outside Codex\'s sandbox, for job '
        f'{out.name}.\n')
    try:
        git(checkout, '--literal-pathspecs', 'add', '--', *paths)
        git(checkout, 'commit', '-q', '--no-gpg-sign', '-F', '-', given=message)
    except Stop as error:
        return (f'not made: {error}',
                f'finished, but the bridge could not commit its work ({error}); its changes are '
                'left staged, not committed')
    return f'made {git(checkout, "rev-parse", "--short", "HEAD")}', None


def codex_review(args):
    checkout = brickson_checkout(args.worktree or os.getcwd())
    hold_checkout(checkout)
    out = job_folder(checkout, 'codex', 'review')
    command = ['codex', 'review', '-c', 'sandbox_mode="read-only"', '--base', args.base]
    write_command(out, command, checkout)
    before = git_state(checkout)
    result = run(command, checkout, out, args.timeout)
    write_in(out, 'result.md', (out / 'output.txt').read_text())
    return out, finish(out, checkout, before, result, {'agent': 'codex', 'read_only': True})


def codex_job(args):
    if args.write:
        if not hook_installed_for_codex():
            raise Stop('Codex\'s guard hook is not in ~/.codex/hooks.json; a write job needs it')
        branch = f'codex/{args.branch}'
        folder = Path(os.path.expanduser(args.worktree or CODEX_FOLDER.format(topic=args.branch)))
        if not folder.exists():
            source = brickson_checkout(os.getcwd())
            git(source, 'fetch', '-q', 'origin', 'main')
            git(source, 'worktree', 'add', '-q', '-b', branch, '--no-track', str(folder), 'origin/main')
            checkout = brickson_checkout(folder)
            hold_checkout(checkout)
        else:
            checkout = brickson_checkout(folder)
            hold_checkout(checkout)
            require_clean(checkout)
            start_branch(checkout, branch)
    else:
        branch = None
        checkout = brickson_checkout(args.worktree or os.getcwd())
        hold_checkout(checkout)
    out = job_folder(checkout, 'codex', 'write' if args.write else 'read')
    prompt = brief_text(args, checkout, branch, CODEX_WRITE)
    write_in(out, 'brief.md', prompt)
    # Codex writes its final message itself, through whatever is at the
    # path it is given, so the path is a fresh folder in the checkout's
    # git folder, where Codex's sandbox lets the agent write nothing, and
    # the bridge copies the message into the job folder.
    answer = Path(tempfile.mkdtemp(prefix='agent-bridge-answer-',
                                   dir=git(checkout, 'rev-parse', '--absolute-git-dir')))
    try:
        command = ['codex', 'exec', '--sandbox', 'workspace-write' if args.write else 'read-only',
                   '-c', 'approval_policy="never"', '-C', str(checkout), '--json',
                   '-o', str(answer / 'result.md'), prompt]
        write_command(out, command[:-1] + ['<brief.md>'], checkout)
        before = git_state(checkout)
        result = run(command, checkout, out, args.timeout)
        final = read_answer(answer / 'result.md')
        write_in(out, 'result.md', final)
    finally:
        shutil.rmtree(answer, ignore_errors=True)
    refusals = [line.strip() for line in (out / 'stderr.txt').read_text().splitlines()
                if 'blocked by PreToolUse hook' in line]
    extra = {'agent': 'codex', 'read_only': not args.write, 'refusals': refusals}
    problem = None
    if args.write:
        extra['bridge_commit'], problem = commit_codex_work(checkout, out, branch, result, final)
    return out, finish(out, checkout, before, result, extra, problem)


def agy_job(args):
    checkout = brickson_checkout(args.worktree or AGY_FOLDER)
    folders = agy_project_folders()
    if folders != [str(checkout)]:
        raise Stop(f'agy runs its commands in its default project\'s folder, which is '
                   f'{folders or "unreadable"}, not {checkout}; it must be that folder alone')
    hold_checkout(checkout)
    guard = agy_guard_snapshot(checkout)
    require_clean(checkout)  # agy has no read-only sandbox, and the folder is shared
    branch = None
    if args.write:
        branch = f'antigravity/{args.branch}'
        start_branch(checkout, branch)
    code = guard_code_snapshot(checkout)
    out = job_folder(checkout, 'agy', 'write' if args.write else 'read')
    prompt = brief_text(args, checkout, branch)
    write_in(out, 'brief.md', prompt)
    command = ['agy', '-p', prompt, '--output-format', 'stream-json',
               '--print-timeout', f'{int(args.timeout)}m']
    if args.model:
        command += ['--model', args.model]
    write_command(out, [part if part != prompt else '<brief.md>' for part in command], checkout)
    before = git_state(checkout)
    try:
        result = run(command, checkout, out, args.timeout + 1)
    finally:  # put back what guards agy, however the job ended
        guard_hook, guard_problem = restore_agy_guard(checkout, guard)
        guard_code, code_problem = restore_guard_code(checkout, code, before['head'])
    refusals, steps, response, ran_in, status = [], 0, '', None, None
    for line in (out / 'output.txt').read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('event') == 'init':
            ran_in = (event.get('init') or {}).get('cwd')
        update = event.get('step_update') or {}
        info = update.get('tool_info') or {}
        if update.get('step_type') == 'tool' and update.get('state') == 'DONE':
            steps += 1
            message = (info.get('error') or {}).get('message', '')
            if 'denied' in message or 'hook' in message:
                refusals.append(f'{info.get("name")}: {message}')
        if event.get('event') == 'result':
            response = (event.get('result') or {}).get('response', '')
            status = (event.get('result') or {}).get('status')
    write_in(out, 'result.md', response)
    extra = {'agent': 'agy', 'read_only': not args.write, 'refusals': refusals,
             'tool_steps': steps, 'agy_status': status, 'ran_in': ran_in,
             'guard_hook': guard_hook, 'guard_code': guard_code}
    problems = [problem for problem in (guard_problem, code_problem) if problem]
    if ran_in and Path(ran_in).resolve() != checkout:
        problems.append(f'ran in the wrong folder ({ran_in})')
    return out, finish(out, checkout, before, result, extra, '; '.join(problems) or None)


def status(_args):
    lines = []
    for tool, flag in (('codex', '--version'), ('agy', '--version')):
        try:
            result = subprocess.run([tool, flag], capture_output=True, text=True,
                                    stdin=subprocess.DEVNULL, timeout=30)
            lines.append(f'{tool}: {result.stdout.strip() or result.stderr.strip()}')
        except (OSError, subprocess.TimeoutExpired) as error:
            lines.append(f'{tool}: not available ({error})')
    lines.append('codex guard hook: ' + ('installed' if hook_installed_for_codex() else 'missing'))
    agy = Path(os.path.expanduser(AGY_FOLDER)).resolve()
    lines.append(f'agy folder {AGY_FOLDER}: ' + ('present' if agy.is_dir() else 'missing'))
    problem = agy_hook_problem(agy, read_agy_guard(agy)) if agy.is_dir() else 'no folder'
    lines.append('agy guard hook: ' + (f'missing or changed: {problem}' if problem else 'installed'))
    folders = agy_project_folders()
    lines.append('agy project folders: ' + (', '.join(f.replace(os.path.expanduser('~'), '~')
                                                     for f in folders) if folders else 'unreadable'))
    print('\n'.join(lines))
    return None, None


def parse(argv):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = parser.add_subparsers(dest='kind', required=True)
    review = sub.add_parser('codex-review', help='Codex reviews this branch against a base, read-only')
    review.add_argument('--base', default='origin/main')
    for name in ('codex', 'agy'):
        job = sub.add_parser(name, help=f'give {name} a brief')
        job.add_argument('--brief', required=True, help='a file holding the job')
        job.add_argument('--write', action='store_true', help='let it commit on a new branch')
        job.add_argument('--branch', help='the topic of that branch (with --write)')
        if name == 'agy':
            job.add_argument('--model', help='a model slug from `agy models`')
    sub.add_parser('status', help='what is installed')
    for name, child in sub.choices.items():
        if name != 'status':
            child.add_argument('--worktree', help='the Brickson worktree to work in')
            child.add_argument('--timeout', type=float, default=30, help='minutes (default 30)')
            child.add_argument('--background', action='store_true',
                               help='run detached; read summary.json when `done` appears')
    args = parser.parse_args(argv)
    if getattr(args, 'brief', None) is not None and not Path(os.path.expanduser(args.brief)).is_file():
        parser.error(f'--brief: no such file: {args.brief}')
    if getattr(args, 'write', False) and not (args.branch and TOPIC.match(args.branch)):
        parser.error('--write needs --branch <topic>, lowercase letters, digits and dashes')
    if getattr(args, 'branch', None) and not getattr(args, 'write', False):
        parser.error('--branch is only for --write')
    return args


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    args = parse(argv)
    if getattr(args, 'background', False):
        log = Path(os.path.expanduser('~/.cache/brickson-agent-bridge'))
        log.mkdir(parents=True, exist_ok=True)
        rest = [a for a in argv if a != '--background']
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        handle, path = tempfile.mkstemp(prefix=f'{stamp}-{args.kind}-', suffix='.log', dir=str(log))
        with os.fdopen(handle, 'w') as output:
            subprocess.Popen([sys.executable, os.path.abspath(__file__), *rest],
                             stdin=subprocess.DEVNULL, stdout=output, stderr=output,
                             start_new_session=True, cwd=os.getcwd())
        print(f'Started in the background; its job folder is printed in {path}. '
              'Read summary.json there once `done` appears.')
        return 0
    handlers = {'codex-review': codex_review, 'codex': codex_job, 'agy': agy_job, 'status': status}
    try:
        out, summary = handlers[args.kind](args)
    except Stop as error:
        print(f'agent-bridge: {error}', file=sys.stderr)
        return 2
    if out is not None:
        print(f'Job folder: {out}')
        print(json.dumps(summary, indent=2))
        return 0 if summary['status'] == 'finished' else 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
