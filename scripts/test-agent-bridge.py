#!/usr/bin/env python3
"""Check scripts/agent-bridge.py with stand-ins for `codex` and `agy`.

Run with python3 scripts/test-agent-bridge.py; standard library only.
scripts/test.sh runs it with the other Python checks, so CI runs it too.
The stand-ins record how they were called (arguments, folder, whether
stdin was closed) and answer the way the real tools did on 2026-11-08, so
no test reaches OpenAI or Google. Each test uses a made-up home folder and
throwaway repositories, never the machine's own settings.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

# An agent that runs the checks inside a bridge job inherits the job's
# no-push settings; this file's throwaway origins need plain git.
for key in [key for key in os.environ if key.startswith(('GIT_CONFIG_KEY_', 'GIT_CONFIG_VALUE_'))
            or key in ('GIT_CONFIG_COUNT', 'GIT_CONFIG_PARAMETERS')]:
    del os.environ[key]
# The bridge's privacy check reads a private list from these; each test
# gives its own made-up list in its made-up home, or none.
for key in ('BRICKSON_PRIVATE_WORDS', 'XDG_CONFIG_HOME'):
    os.environ.pop(key, None)

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / 'scripts' / 'agent-bridge.py'

STUB = r'''#!/usr/bin/env python3
import json, os, stat, sys, time
entry = {'tool': os.path.basename(sys.argv[0]), 'argv': sys.argv[1:], 'cwd': os.getcwd(),
         'stdin_closed': stat.S_ISCHR(os.fstat(0).st_mode)}
with open(os.environ['STUB_LOG'], 'a') as log:
    log.write(json.dumps(entry) + '\n')
mode = os.environ.get('STUB_MODE', '')
args = sys.argv[1:]
if 'work' in mode:
    # A Codex write job's work, left uncommitted: a changed, a deleted and
    # new files, names git escapes or would read as a pathspec, and
    # evidence under build/.
    with open('AGENTS.md', 'a') as changed:
        changed.write('a change from the agent\n')
    os.remove(os.path.join('docs', 'old.md'))
    for name in (':x.txt', '[ab].txt', 'r\u00e9sum\u00e9.md', 'tab\there.txt',
                 os.path.join('docs', 'new.md')):
        with open(name, 'w') as new:
            new.write('new from the agent: ' + os.environ.get('STUB_WORDS', 'plain words') + '\n')
    os.makedirs('build', exist_ok=True)
    with open(os.path.join('build', 'evidence.txt'), 'w') as evidence:
        evidence.write('evidence\n')
if 'selfcommit' in mode:  # a later Codex that may commit by itself
    import subprocess
    with open('self.md', 'w') as own:
        own.write('committed by the agent\n')
    subprocess.run(['git', 'add', 'self.md'], check=True, capture_output=True)
    subprocess.run(['git', 'commit', '-q', '-m', 'Commit made by the agent'], check=True,
                   capture_output=True)
if 'githooks' in mode:  # hooks left where core.hooksPath points
    os.makedirs('.githooks', exist_ok=True)
    for name in ('pre-commit', 'commit-msg', 'post-commit'):
        hook = os.path.join('.githooks', name)
        with open(hook, 'w') as script:
            script.write('#!/bin/sh\necho %s >> "%s/ran"\n' % (name, os.environ['STUB_OUTSIDE']))
        os.chmod(hook, 0o755)
if 'sibling' in mode:  # the bridge's own privacy check, changed during the job
    with open(os.environ['STUB_SIBLING'], 'a') as sibling:
        sibling.write('# changed during the job\n')
if 'guardcode' in mode:  # the guard's own code, which agy's hook runs
    import subprocess
    how = os.environ['STUB_GUARD']
    guard = os.path.join('.claude', 'hooks', 'guard.py')
    privacy = os.path.join('scripts', 'privacy-check.py')
    if how in ('edit', 'commit'):
        for name in (guard, privacy):
            with open(name, 'w') as code:
                code.write('allow everything\n')
        os.chmod(guard, 0o755)
    elif how == 'link':
        outside = os.path.join(os.environ['STUB_OUTSIDE'], 'guard.py')
        with open(outside, 'w') as code:
            code.write('allow everything\n')
        os.remove(guard)
        os.symlink(outside, guard)
    if how == 'commit':
        subprocess.run(['git', 'commit', '-q', '-am', 'Weaken the guard'], check=True,
                       capture_output=True)
if 'badoutput' in mode:  # output the bridge cannot read as text
    sys.stdout.buffer.write(b'\xff\xfe not text\n')
    sys.stdout.flush()
if 'sleep' in mode:
    time.sleep(20)
if 'touch' in mode:
    with open('stray.txt', 'w') as stray:
        stray.write('x\n')
if 'push' in mode:
    import subprocess
    tries = {}
    for name, target in (('origin', 'origin'), ('url', 'https://example.invalid/x.git')):
        pushed = subprocess.run(['git', 'push', target, 'HEAD:refs/heads/from-agent'],
                                capture_output=True, text=True)
        tries[name] = [pushed.returncode, pushed.stderr]
    tries['env'] = {key: os.environ.get(key) for key in
                    ('GH_TOKEN', 'GITHUB_TOKEN', 'GH_CONFIG_DIR', 'BRICKSON_BRIDGE_JOB')}
    with open(os.environ['STUB_LOG'] + '.push', 'w') as record:
        json.dump(tries, record)
if 'overwrite' in mode:
    with open('AGENTS.md', 'w') as tracked:
        tracked.write('rewritten by the agent\n')
if 'checkout' in mode:
    import subprocess
    subprocess.run(['git', 'checkout', '-q', 'HEAD~1'], check=True, capture_output=True)
if 'link' in mode:
    job = os.path.join('build', 'agent-bridge', os.environ['BRICKSON_BRIDGE_JOB'])
    for name in ('result.md', 'summary.json', 'summary.json.partial', 'done'):
        os.symlink(os.path.join(os.environ['STUB_OUTSIDE'], name), os.path.join(job, name))
if 'fsmonitor' in mode:
    import subprocess
    outside = os.environ['STUB_OUTSIDE']
    hook = os.path.join(outside, 'fsmonitor.sh')
    with open(hook, 'w') as script:
        script.write('#!/bin/sh\necho "${GH_TOKEN:-no token}" >> "%s/leak"\n' % outside)
    os.chmod(hook, 0o755)
    subprocess.run(['git', 'config', 'core.fsmonitor', hook], check=True, capture_output=True)
if 'hookspath' in mode:
    import subprocess
    hooks = os.path.abspath(os.path.join('build', 'hooks'))
    os.makedirs(hooks, exist_ok=True)
    hook = os.path.join(hooks, 'post-checkout')
    with open(hook, 'w') as script:
        script.write('#!/bin/sh\necho "${GH_CONFIG_DIR:-none}" >> "%s/ran"\n'
                     % os.environ['STUB_OUTSIDE'])
    os.chmod(hook, 0o755)
    subprocess.run(['git', 'config', 'core.hooksPath', hooks], check=True, capture_output=True)
if 'spawn' in mode:
    import subprocess
    subprocess.Popen(['/bin/sh', '-c', 'sleep 3; echo late > late.txt'])
    time.sleep(20)
if 'onefile' in mode:
    with open(os.environ['STUB_FILE'], 'w') as named:
        named.write('rewritten by the agent\n')
if 'unhook' in mode:
    # Weaken agy's own guard hook, which is git-ignored, so the next agy
    # session would run unguarded (Codex's security review of #91).
    import shutil
    how, outside = os.environ['STUB_UNHOOK'], os.environ.get('STUB_OUTSIDE', '')
    hooks = os.path.join('.agents', 'hooks.json')
    adapter = os.path.join('.agents', 'hooks', 'brickson_guard_adapter.py')
    if how == 'matcher':  # the guard still named, under a matcher that never fires
        with open(hooks) as file:
            config = json.load(file)
        config['brickson-guard']['PreToolUse'][0]['matcher'] = 'no_such_tool'
        with open(hooks, 'w') as file:
            json.dump(config, file)
        with open(adapter, 'w') as file:
            file.write('print("{}")\n')
    elif how == 'link':  # a link to a file outside the folder
        with open(os.path.join(outside, 'hooks.json'), 'w') as file:
            file.write('{"outside": true}\n')
        os.remove(hooks)
        os.symlink(os.path.join(outside, 'hooks.json'), hooks)
    elif how == 'folder-link':  # the whole folder swapped for a link
        os.makedirs(os.path.join(outside, 'hooks'))
        with open(os.path.join(outside, 'hooks.json'), 'w') as file:
            file.write('{"outside": true}\n')
        shutil.rmtree('.agents')
        os.symlink(outside, '.agents')
    elif how == 'remove':
        shutil.rmtree('.agents')
    elif how == 'folder':  # a folder where the file was, which cannot be put back
        os.remove(hooks)
        os.makedirs(os.path.join(hooks, 'inside'))
if 'nested' in mode:  # a repository inside the job's, whose own settings run a command
    import subprocess
    os.makedirs('sub')
    def inner(*args):
        subprocess.run(['git', '-C', 'sub', *args], check=True, capture_output=True)
    inner('init', '-q')
    with open(os.path.join('sub', 'f'), 'w') as tracked:
        tracked.write('hi\n')
    inner('add', 'f')
    inner('-c', 'user.name=x', '-c', 'user.email=x@example.com', 'commit', '-q', '-m', 'inner')
    with open(os.path.join('sub', '.gitattributes'), 'w') as attributes:
        attributes.write('* filter=x\n')
    inner('config', 'filter.x.clean',
          "sh -c 'echo ran >> \"%s/ran\"; cat'" % os.environ['STUB_OUTSIDE'])
    with open(os.path.join('sub', 'f'), 'w') as tracked:  # same size, new time: git reads it
        tracked.write('ho\n')
    os.utime(os.path.join('sub', 'f'), (1900000000, 1900000000))
if 'plantpyc' in mode:
    # A cache of a weakened privacy check, which Python loads without
    # comparing it with the source (an unchecked hash-based .pyc).
    import subprocess
    planted = os.path.join(os.environ['STUB_OUTSIDE'], 'planted.py')
    with open(planted, 'w') as code:
        code.write("WHO = 'planted'\n")
    source = os.path.abspath(os.path.join('scripts', 'privacy-check.py'))
    target = os.path.join(os.environ['STUB_OUTSIDE'], 'cache')
    if os.environ['STUB_PYC'] == 'file':
        target = os.path.join('scripts', '__pycache__')
    os.makedirs(target, exist_ok=True)
    if os.environ['STUB_PYC'] == 'link':
        os.symlink(target, os.path.join('scripts', '__pycache__'))
    subprocess.run([os.environ['STUB_PYTHON'], '-I', '-c',
                    'import importlib.util, os, py_compile, sys; '
                    'name = os.path.basename(importlib.util.cache_from_source(sys.argv[2])); '
                    'py_compile.compile(sys.argv[1], cfile=os.path.join(sys.argv[3], name), '
                    'invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH)',
                    planted, source, target], check=True)
if entry['tool'] == 'codex':
    if args and args[0] == 'review':
        print('No P0 or P1 findings.')
        sys.exit(0)
    if '-o' in args:
        with open(args[args.index('-o') + 1], 'w') as out:
            out.write(os.environ['STUB_ANSWER'] if 'STUB_ANSWER' in os.environ
                      else 'codex final answer\n')
    print(json.dumps({'type': 'thread.started'}))
    if 'blocked' in mode:
        print('ERROR codex_core::tools::router: error=Command blocked by PreToolUse hook: '
              'Stage only your own changes', file=sys.stderr)
    sys.exit(3 if 'fail' in mode else 0)
if args and args[0] == '--version':
    print('stub 1.0')
    sys.exit(0)
cwd = os.environ.get('STUB_AGY_CWD') or os.getcwd()
for event in [{'event': 'init', 'init': {'cwd': cwd}},
              {'event': 'step_update', 'step_update': {'step_type': 'tool', 'state': 'DONE',
               'tool_info': {'name': 'run_command', 'output': 'allowed'}}},
              {'event': 'step_update', 'step_update': {'step_type': 'tool', 'state': 'DONE',
               'tool_info': {'name': 'run_command', 'error': {'message':
               'tool call denied by pre-tool hook: Stage only your own changes'}}}},
              {'event': 'result', 'result': {'status': 'SUCCESS', 'response': 'agy final answer'}}]:
    print(json.dumps(event))
sys.exit(3 if 'fail' in mode else 0)
'''


def git(folder, *args):
    subprocess.run(['git', '-C', str(folder), *args], check=True, capture_output=True,
                   stdin=subprocess.DEVNULL)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name).resolve()
        self.home = base / 'home'
        (self.home / '.codex').mkdir(parents=True)
        (self.home / '.gemini' / 'config' / 'projects').mkdir(parents=True)
        gitconfig = base / 'gitconfig'
        gitconfig.write_text('[user]\n\tname = t\n\temail = t@example.com\n'
                             '[commit]\n\tgpgsign = false\n')
        self.bin = base / 'bin'
        self.bin.mkdir()
        for tool in ('codex', 'agy'):
            path = self.bin / tool
            path.write_text(STUB)
            path.chmod(0o755)
        self.log = base / 'calls.jsonl'
        self.env = {'HOME': str(self.home), 'PATH': f'{self.bin}{os.pathsep}{os.environ["PATH"]}',
                    'STUB_LOG': str(self.log), 'GIT_CONFIG_GLOBAL': str(gitconfig),
                    'GIT_CONFIG_NOSYSTEM': '1'}
        # An origin with a Brickson-shaped main, the owner's checkout, and
        # worktrees beside it, as on the Mac.
        origin, seed = base / 'origin.git', base / 'seed'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(origin)], check=True)
        subprocess.run(['git', 'init', '-q', '-b', 'main', str(seed)], check=True)
        for part in ('.claude/hooks/guard.py', 'scripts/privacy-check.py', 'AGENTS.md',
                     'docs/old.md'):
            (seed / part).parent.mkdir(parents=True, exist_ok=True)
            (seed / part).write_text('# stand-in\n')
        (seed / '.gitignore').write_text('build/\n.agents/\n__pycache__/\n')  # as Brickson's
        env = {**os.environ, **self.env}
        for args in (['add', '.claude', 'scripts', 'AGENTS.md', 'docs', '.gitignore'],
                     ['commit', '-q', '-m', 'start'], ['remote', 'add', 'origin', str(origin)],
                     ['push', '-q', 'origin', 'main']):
            subprocess.run(['git', '-C', str(seed), *args], check=True, env=env, capture_output=True)
        self.owner = self.home / 'code' / 'brickson'
        subprocess.run(['git', 'clone', '-q', str(origin), str(self.owner)], check=True, env=env)
        self.worktree = self.home / 'code' / 'brickson-thread'
        self.agy_folder = self.home / 'code' / 'brickson-antigravity'
        for folder, branch in ((self.worktree, 'claude/thread'), (self.agy_folder, 'antigravity/setup')):
            subprocess.run(['git', '-C', str(self.owner), 'worktree', 'add', '-q', '-b', branch,
                            str(folder), 'origin/main'], check=True, env=env, capture_output=True)
        self.brief = base / 'brief.md'
        self.brief.write_text('List the files in docs/log/.\n')
        self.give_list()

    def tearDown(self):
        self.temp.cleanup()

    def bridge(self, *args, env=None, cwd=None, script=BRIDGE):
        return subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True,
                              env={**os.environ, **self.env, **(env or {})},
                              cwd=str(cwd or self.worktree), timeout=120)

    def calls(self):
        if not self.log.exists():
            return []
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        for call in calls:
            for word in call['argv']:
                for banned in ('danger', 'skip-permissions', 'bypass'):
                    self.assertNotIn(banned, word, call['argv'])
        return calls

    def job_folder(self, result):
        line = next(l for l in result.stdout.splitlines() if l.startswith('Job folder: '))
        return Path(line[len('Job folder: '):])

    def install_codex_hook(self):
        (self.home / '.codex' / 'hooks.json').write_text(json.dumps({'hooks': {'PreToolUse': [
            {'matcher': '*', 'hooks': [{'type': 'command', 'command':
             "python3 '~/.codex/hooks/brickson_guard_adapter.py' --format codex"}]}]}}))

    def point_agy_at(self, folder):
        (self.home / '.gemini' / 'config' / 'projects' / 'default-cli-project.json').write_text(
            json.dumps({'projectResources': {'resources': [
                {'gitFolder': {'folderUri': f'file://{folder}'}}]}}))

    def agy_hook(self):
        """agy's .agents/hooks.json as installed on the Mac
        (docs/log/2026-11-08-codex-antigravity-setup.md), for this folder."""
        adapter = self.agy_folder.resolve() / '.agents' / 'hooks' / 'brickson_guard_adapter.py'
        return {'brickson-guard': {'PreToolUse': [{'matcher': '*', 'hooks': [{
            'type': 'command', 'command': f"python3 '{adapter}' --format antigravity",
            'timeout': 30}]}]}}

    def install_agy_hook(self, text=None):
        # .agents/ is git-ignored here, as on the Mac.
        hooks = self.agy_folder / '.agents' / 'hooks'
        hooks.mkdir(parents=True, exist_ok=True)
        for path in (hooks / 'brickson_guard_adapter.py', hooks.parent / 'hooks.json'):
            if path.is_symlink() or path.exists():
                path.unlink()  # never write through a link an earlier case left
        (hooks / 'brickson_guard_adapter.py').write_text('# the guard adapter, as a stand-in\n')
        (self.agy_folder / '.agents' / 'hooks.json').write_text(
            text if text is not None else json.dumps(self.agy_hook(), indent=2) + '\n')

    def agy_guard_files(self):
        folder = self.agy_folder / '.agents'
        return {name: (folder / name).read_bytes()
                for name in ('hooks.json', 'hooks/brickson_guard_adapter.py')}

    def give_list(self, text='Zorblatt\nQuennick Vashti\n'):
        """A made-up private list in the made-up home, where the privacy
        check looks for one (~/.config/brickson/private-words.txt)."""
        config = self.home / '.config' / 'brickson'
        config.mkdir(parents=True, exist_ok=True)
        (config / 'private-words.txt').write_text(text)
        (config / 'private-words.txt').chmod(0o600)

    def codex_write(self, topic, *extra, mode='work', script=BRIDGE, **env):
        self.install_codex_hook()
        result = self.bridge('codex', '--brief', str(self.brief), '--write', '--branch', topic,
                             *extra, env={'STUB_MODE': mode, **env}, script=script)
        out = self.job_folder(result)
        return (result, self.home / 'code' / f'brickson-codex-{topic}', out,
                json.loads((out / 'summary.json').read_text()))

    def git_out(self, folder, *args):
        return subprocess.run(['git', '-C', str(folder), *args], capture_output=True,
                              check=True).stdout

    def head_files(self, folder):
        return sorted(os.fsdecode(name) for name in
                      self.git_out(folder, 'ls-tree', '-r', '-z', '--name-only', 'HEAD').split(b'\0')
                      if name)

    def staged(self, folder):
        return self.git_out(folder, 'diff', '--cached', '--name-only', '-z')

    def guard_code(self):
        """The guard's own code in agy's folder: bytes, mode and whether a link."""
        files = {}
        for name in ('.claude/hooks/guard.py', 'scripts/privacy-check.py'):
            path = self.agy_folder / name
            files[name] = (path.is_symlink(), path.read_bytes(), path.stat().st_mode & 0o7777)
        return files

    # Codex -------------------------------------------------------------------

    def test_a_codex_job_is_read_only_with_stdin_closed_and_the_brief_wrapped(self):
        result = self.bridge('codex', '--brief', str(self.brief))
        self.assertEqual(result.returncode, 0, result.stderr)
        [call] = self.calls()
        self.assertEqual(call['argv'][:8], ['exec', '--sandbox', 'read-only', '-c',
                                            'approval_policy="never"', '-C', str(self.worktree),
                                            '--json'])
        self.assertTrue(call['stdin_closed'])
        prompt = call['argv'][-1]
        self.assertIn('cat AGENTS.md', prompt)
        self.assertIn('This job is read-only', prompt)
        self.assertIn('List the files in docs/log/.', prompt)
        out = self.job_folder(result)
        self.assertEqual(out.parent, self.worktree / 'build' / 'agent-bridge')
        self.assertEqual((out / 'result.md').read_text(), 'codex final answer\n')
        self.assertEqual((out / 'brief.md').read_text(), prompt)
        summary = json.loads((out / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'finished')
        self.assertTrue((out / 'done').exists())

    def test_the_owners_own_checkout_is_refused(self):
        result = self.bridge('codex', '--brief', str(self.brief), '--worktree', str(self.owner))
        self.assertEqual(result.returncode, 2)
        self.assertIn("owner's own checkout", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_a_folder_that_is_not_brickson_is_refused(self):
        other = Path(self.temp.name) / 'other'
        subprocess.run(['git', 'init', '-q', str(other)], check=True)
        result = self.bridge('codex', '--brief', str(self.brief), '--worktree', str(other))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_a_codex_write_job_needs_the_hook_and_starts_its_own_branch(self):
        refused = self.bridge('codex', '--brief', str(self.brief), '--write', '--branch', 'tests')
        self.assertEqual(refused.returncode, 2)
        self.assertIn('hook', refused.stderr)
        self.assertEqual(self.calls(), [])
        self.install_codex_hook()
        result = self.bridge('codex', '--brief', str(self.brief), '--write', '--branch', 'tests')
        self.assertEqual(result.returncode, 0, result.stderr)
        folder = (self.home / 'code' / 'brickson-codex-tests').resolve()
        [call] = self.calls()
        self.assertEqual(call['argv'][1:3], ['--sandbox', 'workspace-write'])
        self.assertEqual(Path(call['cwd']).resolve(), folder)
        self.assertIn('branch codex/tests', call['argv'][-1])
        self.assertIn('Do not push', call['argv'][-1])
        # Codex's sandbox keeps git's folder read-only: the bridge commits.
        self.assertIn('Do not stage or commit', call['argv'][-1])
        self.assertIn('the bridge commits every changed file outside build/', call['argv'][-1])
        self.assertIn('at most 72 characters', call['argv'][-1])
        self.assertNotIn('Commit your', call['argv'][-1])
        branch = subprocess.run(['git', '-C', str(folder), 'branch', '--show-current'],
                                capture_output=True, text=True).stdout.strip()
        self.assertEqual(branch, 'codex/tests')

    def test_write_needs_a_branch_and_a_branch_needs_write(self):
        self.assertEqual(self.bridge('codex', '--brief', str(self.brief), '--write').returncode, 2)
        self.assertEqual(self.bridge('codex', '--brief', str(self.brief), '--branch', 'x').returncode, 2)
        self.assertEqual(self.bridge('codex', '--brief', str(self.brief), '--write',
                                     '--branch', 'Bad Name').returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_codex_refusals_are_reported(self):
        result = self.bridge('codex', '--brief', str(self.brief), env={'STUB_MODE': 'blocked'})
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(len(summary['refusals']), 1)
        self.assertIn('Stage only your own changes', summary['refusals'][0])

    def test_codex_review_is_read_only_against_the_base(self):
        result = self.bridge('codex-review')
        self.assertEqual(result.returncode, 0, result.stderr)
        [call] = self.calls()
        self.assertEqual(call['argv'], ['review', '-c', 'sandbox_mode="read-only"',
                                        '--base', 'origin/main'])
        self.assertTrue(call['stdin_closed'])
        self.assertEqual((self.job_folder(result) / 'result.md').read_text(),
                         'No P0 or P1 findings.\n')

    # agy -----------------------------------------------------------------------

    def test_agy_runs_only_where_its_project_and_hook_are(self):
        self.point_agy_at(self.owner)
        self.install_agy_hook()
        refused = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(refused.returncode, 2)
        self.assertIn('default project', refused.stderr)
        self.point_agy_at(self.agy_folder)
        (self.agy_folder / '.agents' / 'hooks.json').unlink()
        refused = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(refused.returncode, 2)
        self.assertIn('hook', refused.stderr)
        self.assertEqual(self.calls(), [])

    def test_agy_job_reads_refusals_from_the_stream_not_the_exit(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(result.returncode, 0, result.stderr)
        [call] = self.calls()
        self.assertEqual(Path(call['cwd']).resolve(), self.agy_folder.resolve())
        self.assertTrue(call['stdin_closed'])
        self.assertEqual(call['argv'][0], '-p')
        self.assertIn('--output-format', call['argv'])
        out = self.job_folder(result)
        summary = json.loads((out / 'summary.json').read_text())
        self.assertEqual(summary['agy_status'], 'SUCCESS')
        self.assertEqual(summary['tool_steps'], 2)
        self.assertEqual(len(summary['refusals']), 1)
        self.assertIn('denied by pre-tool hook', summary['refusals'][0])
        self.assertEqual((out / 'result.md').read_text(), 'agy final answer')

    def test_agy_in_the_wrong_folder_is_reported(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief), env={'STUB_AGY_CWD': str(self.owner)})
        self.assertEqual(result.returncode, 1)
        out = self.job_folder(result)
        summary = json.loads((out / 'summary.json').read_text())
        self.assertTrue(summary['status'].startswith('ran in the wrong folder'))
        self.assertTrue((out / 'done').read_text().startswith('ran in the wrong folder'))

    def test_a_change_in_a_read_only_job_is_reported(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief), env={'STUB_MODE': 'touch'})
        self.assertEqual(result.returncode, 1)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'changed files in a read-only job')
        self.assertIn('?? stray.txt', summary['changed_files'])

    def test_agy_needs_exactly_the_guard_hook(self):
        # Every one of these still names the guard's adapter, so the old
        # check, which looked only for its name, let each one through
        # (Codex's security review of #91).
        self.point_agy_at(self.agy_folder)
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()

        def config(change):
            changed = self.agy_hook()
            change(changed)
            return json.dumps(changed)

        def guard(changed):
            return changed['brickson-guard']['PreToolUse'][0]

        def set_matcher(c):
            guard(c)['matcher'] = 'no_such_tool'

        def other_adapter(c):
            guard(c)['hooks'][0]['command'] = guard(c)['hooks'][0]['command'].replace(
                str(self.agy_folder.resolve()), str(outside))

        def answer_dropped(c):
            guard(c)['hooks'][0]['command'] += ' > /dev/null'

        def hook_beside(c):
            c['other'] = {'PreToolUse': [{'matcher': '*', 'hooks': [
                {'type': 'command', 'command': 'echo allow'}]}]}

        def second_hook(c):
            guard(c)['hooks'].append({'type': 'command', 'command': 'echo allow'})

        def no_timeout(c):
            del guard(c)['hooks'][0]['timeout']

        broken = self.agy_hook()['brickson-guard']
        broken['PreToolUse'][0]['matcher'] = 'no_such_tool'
        twice = ('{"brickson-guard": ' + json.dumps(broken) + ', "brickson-guard": '
                 + json.dumps(self.agy_hook()['brickson-guard']) + '}')
        texts = {'a matcher that matches nothing': config(set_matcher),
                 'an adapter outside this folder': config(other_adapter),
                 "the guard's answer thrown away": config(answer_dropped),
                 'a hook beside the guard': config(hook_beside),
                 "a second hook in the guard's entry": config(second_hook),
                 'no timeout': config(no_timeout),
                 'the guard twice, the first one broken': twice}
        for case, text in texts.items():
            with self.subTest(case):
                self.install_agy_hook(text)
                refused = self.bridge('agy', '--brief', str(self.brief))
                self.assertEqual(refused.returncode, 2, refused.stderr)
                self.assertIn('guard hook', refused.stderr)
        hooks_json = self.agy_folder / '.agents' / 'hooks.json'
        adapter = self.agy_folder / '.agents' / 'hooks' / 'brickson_guard_adapter.py'
        (outside / 'hooks.json').write_text(json.dumps(self.agy_hook()))
        (outside / 'adapter.py').write_text('# elsewhere\n')
        for case, path, target in (('hooks.json is a link', hooks_json, outside / 'hooks.json'),
                                   ('the adapter is a link', adapter, outside / 'adapter.py'),
                                   ('the adapter is missing', adapter, None)):
            with self.subTest(case):
                self.install_agy_hook()
                path.unlink()
                if target:
                    path.symlink_to(target)
                refused = self.bridge('agy', '--brief', str(self.brief))
                self.assertEqual(refused.returncode, 2, refused.stderr)
                self.assertIn('guard hook', refused.stderr)
        self.assertEqual(self.calls(), [])
        self.install_agy_hook()
        self.assertEqual(self.bridge('agy', '--brief', str(self.brief)).returncode, 0)

    def test_an_agy_job_that_changes_its_guard_hook_is_reported_and_put_back(self):
        self.point_agy_at(self.agy_folder)
        for how in ('matcher', 'link', 'folder-link', 'remove'):
            with self.subTest(how):
                outside = Path(self.temp.name) / f'outside-{how}'
                outside.mkdir()
                self.install_agy_hook()
                installed = self.agy_guard_files()
                result = self.bridge('agy', '--brief', str(self.brief),
                                     env={'STUB_MODE': 'unhook', 'STUB_UNHOOK': how,
                                          'STUB_OUTSIDE': str(outside)})
                self.assertEqual(result.returncode, 1, result.stderr)
                out = self.job_folder(result)
                summary = json.loads((out / 'summary.json').read_text())
                self.assertTrue(summary['status'].startswith('changed its own guard hook'),
                                summary['status'])
                self.assertIn('put it back', summary['status'])
                self.assertIn('put back', summary['guard_hook'])
                self.assertEqual((out / 'done').read_text(), summary['status'] + '\n')
                for part in ('.agents', '.agents/hooks', '.agents/hooks.json'):
                    self.assertFalse((self.agy_folder / part).is_symlink(), part)
                self.assertEqual(self.agy_guard_files(), installed)
                if how in ('link', 'folder-link'):  # nothing written through the link
                    self.assertEqual((outside / 'hooks.json').read_text(), '{"outside": true}\n')
                    self.assertEqual(sorted(p.name for p in outside.iterdir()),
                                     ['hooks', 'hooks.json'] if how == 'folder-link'
                                     else ['hooks.json'])
                    if how == 'folder-link':
                        self.assertEqual(list((outside / 'hooks').iterdir()), [])
                again = self.bridge('agy', '--brief', str(self.brief))
                self.assertEqual(again.returncode, 0, again.stderr)
                self.assertEqual(json.loads((self.job_folder(again) / 'summary.json')
                                            .read_text())['guard_hook'], 'unchanged')

    def test_an_agy_write_job_that_changes_its_guard_hook_is_reported(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        installed = self.agy_guard_files()
        result = self.bridge('agy', '--brief', str(self.brief), '--write', '--branch', 'docs',
                             env={'STUB_MODE': 'unhook', 'STUB_UNHOOK': 'matcher'})
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertTrue(summary['status'].startswith('changed its own guard hook'))
        self.assertEqual(self.agy_guard_files(), installed)

    def test_a_guard_hook_that_cannot_be_put_back_is_reported_and_stops_the_next_job(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief),
                             env={'STUB_MODE': 'unhook', 'STUB_UNHOOK': 'folder'})
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertIn('could not put it back', summary['status'])
        self.assertIn('unguarded', summary['status'])
        refused = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(refused.returncode, 2, refused.stderr)
        self.assertIn('guard hook', refused.stderr)

    def test_agy_write_job_starts_its_branch_from_origin_main(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief), '--write', '--branch', 'docs')
        self.assertEqual(result.returncode, 0, result.stderr)
        branch = subprocess.run(['git', '-C', str(self.agy_folder), 'branch', '--show-current'],
                                capture_output=True, text=True).stdout.strip()
        self.assertEqual(branch, 'antigravity/docs')
        self.assertIn('branch antigravity/docs', self.calls()[0]['argv'][1])
        self.assertIn('Commit your', self.calls()[0]['argv'][1])  # agy commits by itself
        self.assertNotIn('Do not stage or commit', self.calls()[0]['argv'][1])

    # Both ----------------------------------------------------------------------

    def test_a_job_past_its_time_is_stopped_and_reported(self):
        started = time.time()
        result = self.bridge('codex', '--brief', str(self.brief), '--timeout', '0.02',
                             env={'STUB_MODE': 'sleep'})
        self.assertLess(time.time() - started, 15)
        self.assertEqual(result.returncode, 1)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'timed out')

    def test_background_returns_at_once_and_finishes_later(self):
        started = time.time()
        result = self.bridge('codex', '--brief', str(self.brief), '--background')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(time.time() - started, 10)
        jobs = self.worktree / 'build' / 'agent-bridge'
        for _ in range(60):
            done = list(jobs.glob('*/done')) if jobs.exists() else []
            if done:
                break
            time.sleep(0.5)
        self.assertEqual(len(done), 1)
        self.assertEqual(done[0].read_text(), 'finished\n')

    def test_two_background_jobs_keep_separate_logs(self):
        other = self.home / 'code' / 'brickson-other'
        git(self.owner, 'worktree', 'add', '-q', '-b', 'claude/other', str(other), 'origin/main')
        first = self.bridge('codex', '--brief', str(self.brief), '--background')
        second = self.bridge('codex', '--brief', str(self.brief), '--background', '--worktree', str(other))
        logs = [line.split(' printed in ')[1].split('. Read')[0]
                for line in (first.stdout, second.stdout)]
        self.assertEqual(len(set(logs)), 2, logs)
        jobs = [self.worktree / 'build' / 'agent-bridge', other / 'build' / 'agent-bridge']
        for _ in range(60):
            if all(j.exists() and list(j.glob('*/done')) for j in jobs):
                break
            time.sleep(0.5)
        self.assertTrue(all(len(list(j.glob('*/done'))) == 1 for j in jobs))
        for log in logs:
            self.assertIn('Job folder: ', Path(log).read_text())

    def test_a_second_job_in_the_same_folder_is_refused(self):
        import fcntl
        git_dir = subprocess.run(['git', '-C', str(self.worktree), 'rev-parse', '--absolute-git-dir'],
                                 capture_output=True, text=True, check=True).stdout.strip()
        with open(Path(git_dir) / 'agent-bridge.lock', 'w') as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            busy = self.bridge('codex', '--brief', str(self.brief))
        self.assertEqual(busy.returncode, 2)
        self.assertIn('another bridge job', busy.stderr)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.bridge('codex', '--brief', str(self.brief)).returncode, 0)

    def test_a_file_rewritten_in_a_read_only_job_is_reported(self):
        (self.worktree / 'stray.txt').write_text('the thread\'s own work\n')
        result = self.bridge('codex', '--brief', str(self.brief), env={'STUB_MODE': 'touch'})
        self.assertEqual(result.returncode, 1)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'changed files in a read-only job')

    def test_a_tracked_file_rewritten_in_a_read_only_job_is_reported(self):
        # The thread's own edit to a tracked file is the first status line,
        # which starts with a space (" M AGENTS.md").
        (self.worktree / 'AGENTS.md').write_text('the thread\'s own edit\n')
        result = self.bridge('codex', '--brief', str(self.brief), env={'STUB_MODE': 'overwrite'})
        self.assertEqual(result.returncode, 1)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'changed files in a read-only job')
        self.assertIn(' M AGENTS.md', summary['changed_files'])

    def test_a_file_whose_name_git_escapes_is_still_compared(self):
        # Without -z, git status quotes these names and escapes what is in
        # them ("r\\303\\251sum\\303\\251.md"), so the bridge never found the
        # file to compare (Codex, on #91's cc6069e).
        names = ['r\u00e9sum\u00e9.md', 'say "hi".txt', 'back\\slash.txt', 'tab\there.txt',
                 'line\nbreak.txt']
        for name in names:
            (self.worktree / name).write_text('the thread\'s own work\n')
        quiet = self.bridge('codex', '--brief', str(self.brief))
        self.assertEqual(quiet.returncode, 0, quiet.stderr)
        listed = json.loads((self.job_folder(quiet) / 'summary.json').read_text())['changed_files']
        self.assertEqual(sorted(listed), sorted(f'?? {name}' for name in names))
        for name in names:
            with self.subTest(name=name):
                result = self.bridge('codex', '--brief', str(self.brief),
                                     env={'STUB_MODE': 'onefile', 'STUB_FILE': name})
                self.assertEqual(result.returncode, 1, result.stderr)
                summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
                self.assertEqual(summary['status'], 'changed files in a read-only job')

    def test_a_renamed_file_is_listed_once_and_compared(self):
        # With -z, git writes a rename's original path as a field of its own.
        git(self.worktree, 'mv', 'AGENTS.md', 'agents notes.md')
        result = self.bridge('codex', '--brief', str(self.brief),
                             env={'STUB_MODE': 'onefile', 'STUB_FILE': 'agents notes.md'})
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'changed files in a read-only job')
        self.assertEqual(summary['changed_files'], ['RM AGENTS.md -> agents notes.md'])

    def test_an_agent_cannot_publish(self):
        result = self.bridge('codex', '--brief', str(self.brief),
                             env={'STUB_MODE': 'push', 'GH_TOKEN': 'from-the-thread',
                                  'GITHUB_TOKEN': 'from-the-thread'})
        self.assertEqual(result.returncode, 0, result.stderr)
        tries = json.loads(Path(str(self.log) + '.push').read_text())
        for name in ('origin', 'url'):
            self.assertNotEqual(tries[name][0], 0, name)
            self.assertIn('no-push', tries[name][1], name)
        branches = subprocess.run(['git', '-C', str(self.owner), 'ls-remote', '--heads', 'origin'],
                                  capture_output=True, text=True).stdout
        self.assertNotIn('from-agent', branches)
        env = tries['env']
        self.assertIsNone(env['GH_TOKEN'])
        self.assertIsNone(env['GITHUB_TOKEN'])
        self.assertTrue(env['GH_CONFIG_DIR'].endswith('gh-signed-out'))
        self.assertEqual(list(Path(env['GH_CONFIG_DIR']).iterdir()), [])
        self.assertTrue(env['BRICKSON_BRIDGE_JOB'])

    def test_an_agent_that_cannot_start_still_ends_with_done(self):
        (self.bin / 'codex').unlink()
        result = self.bridge('codex', '--brief', str(self.brief),
                             env={'PATH': f'{self.bin}{os.pathsep}/usr/bin{os.pathsep}/bin'})
        self.assertEqual(result.returncode, 1, result.stderr)
        out = self.job_folder(result)
        self.assertEqual((out / 'done').read_text(), 'failed (exit 127)\n')
        self.assertIn('could not start codex', (out / 'stderr.txt').read_text())

    def test_a_missing_brief_changes_nothing(self):
        self.install_codex_hook()
        result = self.bridge('codex', '--brief', str(self.brief) + '.missing', '--write',
                             '--branch', 'tests')
        self.assertEqual(result.returncode, 2)
        self.assertIn('no such file', result.stderr)
        self.assertFalse((self.home / 'code' / 'brickson-codex-tests').exists())
        self.assertFalse((self.worktree / 'build').exists())
        self.assertEqual(self.calls(), [])

    def test_an_empty_brief_changes_nothing(self):
        self.install_codex_hook()
        result = self.bridge('codex', '--brief', '', '--write', '--branch', 'tests')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('no such file', result.stderr)
        self.assertFalse((self.home / 'code' / 'brickson-codex-tests').exists())
        self.assertFalse((self.worktree / 'build').exists())
        self.assertEqual(self.calls(), [])

    def test_a_read_only_job_that_moves_the_checkout_is_reported(self):
        # Going back a commit changes files without leaving any changed
        # file or new commit behind.
        (self.worktree / 'AGENTS.md').write_text('a newer version\n')
        subprocess.run(['git', '-C', str(self.worktree), 'commit', '-q', '-am', 'newer'],
                       check=True, capture_output=True, env={**os.environ, **self.env})
        result = self.bridge('codex', '--brief', str(self.brief), env={'STUB_MODE': 'checkout'})
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertEqual(summary['status'], 'changed files in a read-only job')

    def test_links_an_agent_leaves_in_its_job_folder_are_never_followed(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        result = self.bridge('agy', '--brief', str(self.brief),
                             env={'STUB_MODE': 'link', 'STUB_OUTSIDE': str(outside)})
        self.assertEqual(sorted(p.name for p in outside.iterdir()), [])
        out = self.job_folder(result)
        for name in ('result.md', 'summary.json', 'done'):
            self.assertFalse((out / name).is_symlink(), name)
        self.assertEqual((out / 'result.md').read_text(), 'agy final answer')
        self.assertEqual(json.loads((out / 'summary.json').read_text())['agent'], 'agy')
        self.assertTrue((out / 'done').read_text())

    def test_a_linked_build_folder_is_refused(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        (self.worktree / 'build').symlink_to(outside)
        result = self.bridge('codex', '--brief', str(self.brief))
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('is a link', result.stderr)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(self.calls(), [])

    def test_a_checkout_with_its_own_push_url_is_refused(self):
        # git pushes to every push URL a remote has, and skips pushInsteadOf
        # for them, so the job's no-push URL would only be added beside it.
        origin = subprocess.run(['git', '-C', str(self.worktree), 'remote', 'get-url', 'origin'],
                                capture_output=True, text=True, check=True).stdout.strip()
        git(self.worktree, 'config', 'remote.origin.pushurl', origin)
        result = self.bridge('codex', '--brief', str(self.brief), env={'STUB_MODE': 'push'})
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('push URL', result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.worktree / 'build').exists())
        branches = subprocess.run(['git', '-C', str(self.owner), 'ls-remote', '--heads', 'origin'],
                                  capture_output=True, text=True).stdout
        self.assertNotIn('from-agent', branches)

    def test_codex_never_writes_its_answer_through_a_link(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        result = self.bridge('codex', '--brief', str(self.brief),
                             env={'STUB_MODE': 'link', 'STUB_OUTSIDE': str(outside)})
        self.assertEqual(sorted(p.name for p in outside.iterdir()), [])
        out = self.job_folder(result)
        self.assertFalse((out / 'result.md').is_symlink())
        self.assertEqual((out / 'result.md').read_text(), 'codex final answer\n')
        git_dir = subprocess.run(['git', '-C', str(self.worktree), 'rev-parse', '--absolute-git-dir'],
                                 capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual([p.name for p in Path(git_dir).iterdir() if 'answer' in p.name], [])

    def test_git_after_a_job_runs_no_callback_with_the_threads_token(self):
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        result = self.bridge('codex', '--brief', str(self.brief),
                             env={'STUB_MODE': 'fsmonitor', 'STUB_OUTSIDE': str(outside),
                                  'GH_TOKEN': 'from-the-thread'})
        self.assertTrue((self.job_folder(result) / 'done').exists(), result.stderr)
        leak = outside / 'leak'
        self.assertFalse(leak.exists() and 'from-the-thread' in leak.read_text())
        self.assertFalse(leak.exists())

    def test_git_hooks_an_agent_sets_never_run_in_the_bridges_git(self):
        # One job points git at a hook of its own under build/; the next
        # write job's worktree add would run it outside any sandbox.
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        self.install_codex_hook()
        first = self.bridge('codex', '--brief', str(self.brief),
                            env={'STUB_MODE': 'hookspath', 'STUB_OUTSIDE': str(outside)})
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.bridge('codex', '--brief', str(self.brief), '--write', '--branch', 'tests',
                             env={'STUB_OUTSIDE': str(outside)})
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertTrue((self.home / 'code' / 'brickson-codex-tests').is_dir())
        self.assertEqual(list(outside.iterdir()), [])

    def test_these_tests_pass_inside_a_job(self):
        # An agent asked to run scripts/test.sh runs this file with the
        # job's no-push settings; its throwaway origins must still work.
        spec = importlib.util.spec_from_file_location('agent_bridge', BRIDGE)
        bridge = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(bridge)
        job = Path(self.temp.name) / 'job'
        job.mkdir()
        result = subprocess.run([sys.executable, '-B', __file__,
                                 'BridgeTests.test_status_names_what_is_installed'],
                                capture_output=True, text=True, timeout=120,
                                env=bridge.job_environment(job))
        self.assertEqual(result.returncode, 0, result.stderr[-2000:])

    def test_agy_refuses_a_folder_with_uncommitted_work(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        (self.agy_folder / 'notes.txt').write_text('someone\'s work\n')
        result = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(result.returncode, 2)
        self.assertIn('uncommitted', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_a_timeout_stops_what_the_agent_started(self):
        result = self.bridge('codex', '--brief', str(self.brief), '--timeout', '0.02',
                             env={'STUB_MODE': 'spawn'})
        self.assertEqual(result.returncode, 1)
        time.sleep(4)
        self.assertFalse((self.worktree / 'late.txt').exists())

    def test_a_bridge_told_to_stop_stops_its_agent_first(self):
        import signal
        bridge = subprocess.Popen([sys.executable, str(BRIDGE), 'codex', '--brief', str(self.brief)],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                  env={**os.environ, **self.env, 'STUB_MODE': 'spawn'},
                                  cwd=str(self.worktree))
        for _ in range(100):  # until the stand-in has started
            if self.log.exists():
                break
            time.sleep(0.1)
        time.sleep(0.5)
        bridge.send_signal(signal.SIGTERM)
        stdout, _ = bridge.communicate(timeout=60)
        self.assertEqual(bridge.returncode, 1)
        out = Path(next(l for l in stdout.splitlines() if l.startswith('Job folder: '))[12:])
        self.assertTrue((out / 'done').read_text().startswith('stopped'))
        time.sleep(4)
        self.assertFalse((self.worktree / 'late.txt').exists())

    # The bridge commits a Codex write job's work -------------------------------

    WORK = [':x.txt', '[ab].txt', 'r\u00e9sum\u00e9.md', 'tab\there.txt', 'docs/new.md']

    def test_a_codex_write_jobs_work_is_committed_by_the_bridge(self):
        result, folder, out, summary = self.codex_write('work')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(summary['status'], 'finished')
        self.assertEqual(len(summary['commits']), 1, summary)
        self.assertTrue(summary['bridge_commit'].startswith('committed '), summary['bridge_commit'])
        self.assertIn(summary['commits'][0].split()[0], summary['bridge_commit'])
        self.assertEqual(summary['changed_files'], [])
        # Every changed, new and deleted file, each staged as itself (a name
        # that reads as a pathspec, or that git escapes), and nothing under build/.
        self.assertEqual(self.head_files(folder), sorted(
            ['.claude/hooks/guard.py', '.gitignore', 'AGENTS.md', 'scripts/privacy-check.py',
             *self.WORK]))
        self.assertIn(b'a change from the agent', self.git_out(folder, 'show', 'HEAD:AGENTS.md'))
        self.assertTrue((folder / 'build' / 'evidence.txt').is_file())
        self.assertEqual(self.git_out(folder, 'status', '--porcelain'), b'')
        self.assertEqual(self.git_out(folder, 'rev-parse', 'HEAD~1'),
                         self.git_out(folder, 'rev-parse', 'origin/main'))
        message = self.git_out(folder, 'log', '-1', '--format=%B').decode().strip().splitlines()
        self.assertEqual(message[0], 'codex final answer')
        self.assertIn(out.name, message[-1])
        self.assertTrue((out / 'privacy-check.txt').read_text())

    def test_the_commit_message_comes_from_codexs_final_message(self):
        long = 'Make ' + 'the words fit ' * 10
        cases = [('a heading', '## **Add the thing**\n\nWhy it matters.\nAnd more.\n',
                  'Add the thing', 'Why it matters.\nAnd more.'),
                 ('a long line', long + '\n', long[:72].rstrip(), None),
                 ('nothing', '', None, None)]
        for number, (case, answer, subject, body) in enumerate(cases):
            with self.subTest(case):
                result, folder, out, summary = self.codex_write(f'message-{number}',
                                                                STUB_ANSWER=answer)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                message = self.git_out(folder, 'log', '-1', '--format=%B').decode().strip()
                lines = message.splitlines()
                self.assertLessEqual(len(lines[0]), 72)
                if subject:
                    self.assertEqual(lines[0], subject)
                else:
                    self.assertIn(f'codex/message-{number}', lines[0])
                if body:
                    self.assertIn(body, message)
                self.assertIn(out.name, lines[-1])

    def test_hooks_left_in_the_checkout_never_run_when_the_bridge_commits(self):
        # Brickson's checkouts point core.hooksPath at .githooks, in the
        # checkout, where the agent can write.
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        git(self.owner, 'config', 'core.hooksPath', '.githooks')
        result, folder, out, summary = self.codex_write('hooks', mode='githooks work',
                                                        STUB_OUTSIDE=str(outside))
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertTrue(summary['bridge_commit'].startswith('committed '), summary)
        self.assertIn('.githooks/pre-commit', self.head_files(folder))
        self.assertEqual(list(outside.iterdir()), [])

    def test_nothing_is_committed_when_the_privacy_check_finds_a_private_word(self):
        cases = [('in a file', {'STUB_WORDS': 'Zorblatt'}),
                 ('in the message', {'STUB_ANSWER': 'Fix the list for Quennick Vashti\n'})]
        for number, (case, env) in enumerate(cases):
            with self.subTest(case):
                result, folder, out, summary = self.codex_write(f'private-{number}', **env)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                self.assertIn('not committed', summary['status'])
                self.assertIn('privacy check', summary['status'])
                self.assertTrue(summary['bridge_commit'].startswith('not committed'), summary)
                self.assertEqual(summary['commits'], [])
                self.assertEqual(self.staged(folder), b'')
                self.assertIn('?? docs/new.md', summary['changed_files'])
                report = (out / 'privacy-check.txt').read_text()
                self.assertIn('Found', report)
                for text in (report, (out / 'summary.json').read_text(), (out / 'done').read_text(),
                             result.stdout, result.stderr):
                    for word in ('Zorblatt', 'Quennick', 'Vashti'):
                        self.assertNotIn(word, text)

    def test_nothing_is_committed_when_the_commits_identity_holds_a_private_word(self):
        # The author and committer the commit would record are read before
        # the branch moves, whether they come from git's settings or, as
        # here, from the bridge's environment.
        cases = [('author name', {'GIT_AUTHOR_NAME': 'Zorblatt'}),
                 ('committer name', {'GIT_COMMITTER_NAME': 'Quennick Vashti'}),
                 ('address', {'GIT_AUTHOR_EMAIL': 'zorblatt@example.com'})]
        for number, (case, env) in enumerate(cases):
            with self.subTest(case):
                topic = f'identity-{number}'
                result, folder, out, summary = self.codex_write(topic, **env)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                self.assertIn('not committed', summary['status'])
                self.assertTrue(summary['bridge_commit'].startswith('not committed'), summary)
                self.assertEqual(summary['commits'], [])
                self.assertEqual(self.git_out(folder, 'rev-parse', f'codex/{topic}'),
                                 self.git_out(folder, 'rev-parse', 'origin/main'))
                self.assertEqual(self.staged(folder), b'')
                self.assertTrue((folder / 'docs' / 'new.md').is_file())
                self.assertIn(b'a change from the agent', (folder / 'AGENTS.md').read_bytes())
                self.assertIn('Found', (out / 'privacy-check.txt').read_text())
                for text in ((out / 'privacy-check.txt').read_text(),
                             (out / 'summary.json').read_text(), (out / 'done').read_text(),
                             result.stdout, result.stderr):
                    for word in ('Zorblatt', 'zorblatt', 'Quennick', 'Vashti'):
                        self.assertNotIn(word, text)

    def test_nothing_is_committed_without_a_private_list(self):
        (self.home / '.config' / 'brickson' / 'private-words.txt').unlink()
        result, folder, out, summary = self.codex_write('no-list')
        self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
        self.assertIn('not committed', summary['status'])
        self.assertEqual(summary['commits'], [])
        self.assertEqual(self.staged(folder), b'')
        self.assertIn('private list', (out / 'privacy-check.txt').read_text())

    def test_nothing_is_committed_when_the_bridges_own_privacy_check_changed(self):
        # The bridge runs the privacy check beside it, never the job's copy,
        # and refuses to commit if that one changed while the job ran.
        copy = Path(self.temp.name) / 'copy' / 'scripts'
        copy.mkdir(parents=True)
        for name in ('agent-bridge.py', 'privacy-check.py'):
            (copy / name).write_bytes((ROOT / 'scripts' / name).read_bytes())
        result, folder, out, summary = self.codex_write(
            'sibling', mode='work sibling', script=copy / 'agent-bridge.py',
            STUB_SIBLING=str(copy / 'privacy-check.py'))
        self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
        self.assertIn('changed during the job', summary['bridge_commit'])
        self.assertIn('not committed', summary['status'])
        self.assertEqual(summary['commits'], [])
        self.assertEqual(self.staged(folder), b'')

    def test_nothing_is_committed_when_codex_does_not_finish(self):
        cases = [('failed', 'work fail', [], 'failed (exit 3)'),
                 ('timed out', 'work sleep', ['--timeout', '0.02'], 'timed out')]
        for number, (case, mode, extra, status) in enumerate(cases):
            with self.subTest(case):
                result, folder, out, summary = self.codex_write(f'unfinished-{number}', *extra,
                                                                mode=mode)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                self.assertTrue(summary['status'].startswith(status), summary['status'])
                self.assertTrue(summary['bridge_commit'].startswith('not committed'), summary)
                self.assertEqual(summary['commits'], [])
                self.assertEqual(self.staged(folder), b'')
                self.assertIn('?? docs/new.md', summary['changed_files'])

    def test_codexs_own_commits_stay_and_the_bridge_commits_only_the_rest(self):
        result, folder, out, summary = self.codex_write('own', mode='selfcommit work')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(len(summary['commits']), 2, summary)
        self.assertTrue(summary['commits'][1].endswith('Commit made by the agent'))
        self.assertTrue(summary['bridge_commit'].startswith('committed '), summary)
        result, folder, out, summary = self.codex_write('own-only', mode='selfcommit')
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(len(summary['commits']), 1, summary)
        self.assertEqual(summary['bridge_commit'], 'nothing to commit')

    def test_a_repository_left_in_the_job_is_never_staged_or_committed(self):
        # git lists a repository inside the job's as one entry; staged, it
        # becomes a link to that repository, and git then runs what that
        # repository's own settings name (here a filter), outside the sandbox.
        outside = Path(self.temp.name) / 'outside'
        outside.mkdir()
        result, folder, out, summary = self.codex_write('nested', mode='nested work',
                                                        STUB_OUTSIDE=str(outside))
        self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual(summary['commits'], [])
        self.assertEqual(self.staged(folder), b'')
        for text in (summary['bridge_commit'], summary['status']):
            self.assertIn('not committed', text)
            self.assertIn('repository or a whole folder', text)
            self.assertIn('sub/', text)
        self.assertIn('?? docs/new.md', summary['changed_files'])

    def test_a_stop_during_the_privacy_check_commits_nothing_and_still_ends_with_done(self):
        import signal
        copy = Path(self.temp.name) / 'copy' / 'scripts'
        copy.mkdir(parents=True)
        (copy / 'agent-bridge.py').write_bytes(BRIDGE.read_bytes())
        started = Path(self.temp.name) / 'check-started'
        (copy / 'privacy-check.py').write_text(
            'import os, time\nopen(os.environ["CHECK_STARTED"], "w").close()\ntime.sleep(60)\n')
        self.install_codex_hook()
        began = time.monotonic()
        bridge = subprocess.Popen([sys.executable, str(copy / 'agent-bridge.py'), 'codex',
                                   '--brief', str(self.brief), '--write', '--branch', 'stop'],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                  env={**os.environ, **self.env, 'STUB_MODE': 'work',
                                       'CHECK_STARTED': str(started)},
                                  cwd=str(self.worktree))
        for _ in range(300):  # until the privacy check is running
            if started.exists():
                break
            time.sleep(0.1)
        self.assertTrue(started.exists())
        bridge.send_signal(signal.SIGTERM)
        stdout, stderr = bridge.communicate(timeout=60)
        self.assertLess(time.monotonic() - began, 40)
        self.assertEqual(bridge.returncode, 1, stderr)
        out = Path(next(l for l in stdout.splitlines() if l.startswith('Job folder: '))[12:])
        summary = json.loads((out / 'summary.json').read_text())
        done = (out / 'done').read_text()
        self.assertEqual(done, summary['status'] + '\n')
        self.assertTrue(done.startswith('stopped'), done)
        self.assertIn('before it committed', done)
        self.assertIn('not committed', summary['bridge_commit'])
        folder = self.home / 'code' / 'brickson-codex-stop'
        self.assertEqual(summary['commits'], [])
        self.assertEqual(self.staged(folder), b'')
        self.assertIn('?? docs/new.md', summary['changed_files'])

    def test_a_bytecode_cache_left_beside_the_guards_code_is_removed(self):
        # guard.py loads scripts/privacy-check.py through Python's loader,
        # which uses a cache in scripts/__pycache__ and, for an unchecked
        # hash-based one, never compares it with the source.
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        load = ('import importlib.util, sys; '
                'spec = importlib.util.spec_from_file_location("privacy_check", sys.argv[1]); '
                'module = importlib.util.module_from_spec(spec); sys.dont_write_bytecode = True; '
                'spec.loader.exec_module(module); print(getattr(module, "WHO", "source"))')
        for number, how in enumerate(('file', 'link')):
            with self.subTest(how):
                outside = Path(self.temp.name) / f'outside-pyc-{number}'
                outside.mkdir()
                result = self.bridge('agy', '--brief', str(self.brief),
                                     env={'STUB_MODE': 'plantpyc', 'STUB_PYC': how,
                                          'STUB_OUTSIDE': str(outside),
                                          'STUB_PYTHON': sys.executable})
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
                self.assertIn('scripts/__pycache__', summary['guard_cache'])
                loaded = subprocess.run([sys.executable, '-I', '-c', load,
                                         str(self.agy_folder / 'scripts' / 'privacy-check.py')],
                                        capture_output=True, text=True, check=True)
                self.assertEqual(loaded.stdout.strip(), 'source')
                self.assertFalse(os.path.lexists(self.agy_folder / 'scripts' / '__pycache__'))
                if how == 'link':  # removed, never followed
                    self.assertTrue(any((outside / 'cache').iterdir()))
                again = self.bridge('agy', '--brief', str(self.brief))
                self.assertEqual(again.returncode, 0, again.stderr)

    # The guard's own code in agy's folder is put back ----------------------------

    def test_an_agy_job_that_changes_the_guards_code_has_it_put_back(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        installed = self.guard_code()
        cases = [('read-only', 'edit', 'guardcode', False),
                 ('a link left in its place', 'link', 'guardcode', False),
                 ('agy failed', 'edit', 'guardcode fail', False),
                 ('a write job', 'edit', 'guardcode', True)]
        for number, (case, how, mode, write) in enumerate(cases):
            with self.subTest(case):
                outside = Path(self.temp.name) / f'outside-{number}'
                outside.mkdir()
                args = ['--write', '--branch', f'guard-{number}'] if write else []
                result = self.bridge('agy', '--brief', str(self.brief), *args,
                                     env={'STUB_MODE': mode, 'STUB_GUARD': how,
                                          'STUB_OUTSIDE': str(outside)})
                self.assertEqual(result.returncode, 1, result.stderr)
                out = self.job_folder(result)
                summary = json.loads((out / 'summary.json').read_text())
                self.assertIn("changed the guard's code", summary['status'])
                self.assertIn('the bridge put it back', summary['status'])
                self.assertIn('put back', summary['guard_code'])
                self.assertEqual((out / 'done').read_text(), summary['status'] + '\n')
                if 'fail' in mode:
                    self.assertEqual(summary['exit_code'], 3)
                self.assertEqual(self.guard_code(), installed)
                if how == 'link':
                    self.assertEqual((outside / 'guard.py').read_text(), 'allow everything\n')
                again = self.bridge('agy', '--brief', str(self.brief))
                self.assertEqual(again.returncode, 0, again.stderr)
                self.assertEqual(json.loads((self.job_folder(again) / 'summary.json')
                                            .read_text())['guard_code'], 'unchanged')

    def test_the_guards_code_is_put_back_when_the_bridge_is_stopped(self):
        import signal
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        installed = self.guard_code()
        bridge = subprocess.Popen([sys.executable, str(BRIDGE), 'agy', '--brief', str(self.brief)],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                  env={**os.environ, **self.env, 'STUB_MODE': 'guardcode spawn',
                                       'STUB_GUARD': 'edit'},
                                  cwd=str(self.worktree))
        for _ in range(100):  # until the stand-in has started
            if self.log.exists():
                break
            time.sleep(0.1)
        time.sleep(0.5)
        bridge.send_signal(signal.SIGTERM)
        stdout, _ = bridge.communicate(timeout=60)
        self.assertEqual(bridge.returncode, 1)
        out = Path(next(l for l in stdout.splitlines() if l.startswith('Job folder: '))[12:])
        done = (out / 'done').read_text()
        self.assertTrue(done.startswith('stopped'), done)
        self.assertIn("changed the guard's code", done)
        self.assertEqual(self.guard_code(), installed)

    def test_a_stop_after_agy_has_exited_still_puts_everything_back(self):
        # The stop arrives during the put-back, after agy has exited: a
        # driver wraps restore_agy_guard so the bridge first sends itself
        # the signal, then puts the hook back.
        import signal
        self.point_agy_at(self.agy_folder)
        driver = Path(self.temp.name) / 'driver.py'
        driver.write_text(
            'import importlib.util, os, signal, sys\n'
            'spec = importlib.util.spec_from_file_location("bridge", sys.argv[1])\n'
            'bridge = importlib.util.module_from_spec(spec)\n'
            'spec.loader.exec_module(bridge)\n'
            'original = bridge.restore_agy_guard\n'
            'def stopped_first(*args):\n'
            '    os.kill(os.getpid(), int(sys.argv[2]))\n'
            '    return original(*args)\n'
            'bridge.restore_agy_guard = stopped_first\n'
            'sys.exit(bridge.main(sys.argv[3:]))\n')
        for number, sig in enumerate((signal.SIGTERM, signal.SIGHUP)):
            with self.subTest(sig.name):
                self.install_agy_hook()
                installed, hook = self.guard_code(), self.agy_guard_files()
                outside = Path(self.temp.name) / f'outside-stop-{number}'
                outside.mkdir()
                result = subprocess.run(
                    [sys.executable, str(driver), str(BRIDGE), str(int(sig)), 'agy', '--brief',
                     str(self.brief)], capture_output=True, text=True, cwd=str(self.worktree),
                    timeout=120, env={**os.environ, **self.env,
                                      'STUB_MODE': 'guardcode plantpyc unhook',
                                      'STUB_GUARD': 'edit', 'STUB_UNHOOK': 'matcher',
                                      'STUB_PYC': 'file', 'STUB_OUTSIDE': str(outside),
                                      'STUB_PYTHON': sys.executable})
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.guard_code(), installed)
                self.assertEqual(self.agy_guard_files(), hook)
                self.assertFalse(os.path.lexists(self.agy_folder / 'scripts' / '__pycache__'))
                out = self.job_folder(result)
                summary = json.loads((out / 'summary.json').read_text())
                self.assertEqual((out / 'done').read_text(), summary['status'] + '\n')
                self.assertTrue(summary['status'].startswith('stopped'), summary['status'])
                self.assertIn("changed the guard's code", summary['status'])

    def test_the_guards_code_is_put_back_even_when_agys_output_cannot_be_read(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        installed, hook = self.guard_code(), self.agy_guard_files()
        result = self.bridge('agy', '--brief', str(self.brief),
                             env={'STUB_MODE': 'guardcode badoutput unhook', 'STUB_GUARD': 'edit',
                                  'STUB_UNHOOK': 'matcher'})
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.guard_code(), installed)
        self.assertEqual(self.agy_guard_files(), hook)

    def test_an_agy_write_job_whose_commits_change_the_guards_code(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        installed = self.guard_code()
        result = self.bridge('agy', '--brief', str(self.brief), '--write', '--branch', 'weaken',
                             env={'STUB_MODE': 'guardcode', 'STUB_GUARD': 'commit'})
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = json.loads((self.job_folder(result) / 'summary.json').read_text())
        self.assertIn("commits change the guard's code", summary['status'])
        self.assertEqual(len(summary['commits']), 1)
        self.assertEqual(self.guard_code(), installed)  # the working tree has the earlier code
        self.assertIn(b' M .claude/hooks/guard.py',
                      self.git_out(self.agy_folder, 'status', '--porcelain'))
        refused = self.bridge('agy', '--brief', str(self.brief))
        self.assertEqual(refused.returncode, 2, refused.stderr)
        self.assertIn('uncommitted', refused.stderr)

    def test_status_names_what_is_installed(self):
        self.point_agy_at(self.agy_folder)
        result = self.bridge('status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('codex guard hook: missing', result.stdout)
        self.assertIn('agy project folders: ~/code/brickson-antigravity', result.stdout)


if __name__ == '__main__':
    unittest.main()
