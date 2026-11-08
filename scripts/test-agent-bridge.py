#!/usr/bin/env python3
"""Check scripts/agent-bridge.py with stand-ins for `codex` and `agy`.

Run with python3 scripts/test-agent-bridge.py; standard library only.
scripts/test.sh runs it with the other Python checks, so CI runs it too.
The stand-ins record how they were called (arguments, folder, whether
stdin was closed) and answer the way the real tools did on 2026-11-08, so
no test reaches OpenAI or Google. Each test uses a made-up home folder and
throwaway repositories, never the machine's own settings.
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

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
if 'sleep' in mode:
    time.sleep(20)
if 'touch' in mode:
    with open('stray.txt', 'w') as stray:
        stray.write('x\n')
if 'overwrite' in mode:
    with open('AGENTS.md', 'w') as tracked:
        tracked.write('rewritten by the agent\n')
if 'spawn' in mode:
    import subprocess
    subprocess.Popen(['/bin/sh', '-c', 'sleep 3; echo late > late.txt'])
    time.sleep(20)
if entry['tool'] == 'codex':
    if args and args[0] == 'review':
        print('No P0 or P1 findings.')
        sys.exit(0)
    if '-o' in args:
        with open(args[args.index('-o') + 1], 'w') as out:
            out.write('codex final answer\n')
    print(json.dumps({'type': 'thread.started'}))
    if 'blocked' in mode:
        print('ERROR codex_core::tools::router: error=Command blocked by PreToolUse hook: '
              'Stage only your own changes', file=sys.stderr)
    sys.exit(0)
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
        for part in ('.claude/hooks/guard.py', 'scripts/privacy-check.py', 'AGENTS.md'):
            (seed / part).parent.mkdir(parents=True, exist_ok=True)
            (seed / part).write_text('# stand-in\n')
        (seed / '.gitignore').write_text('build/\n.agents/\n')
        env = {**os.environ, **self.env}
        for args in (['add', '.claude', 'scripts', 'AGENTS.md', '.gitignore'],
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

    def tearDown(self):
        self.temp.cleanup()

    def bridge(self, *args, env=None, cwd=None):
        return subprocess.run([sys.executable, str(BRIDGE), *args], capture_output=True, text=True,
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

    def install_agy_hook(self):
        (self.agy_folder / '.agents').mkdir(exist_ok=True)
        (self.agy_folder / '.agents' / 'hooks.json').write_text(json.dumps({'brickson-guard': {
            'PreToolUse': [{'matcher': '*', 'hooks': [{'command':
            "python3 'x/.agents/hooks/brickson_guard_adapter.py' --format antigravity"}]}]}}))
        (self.agy_folder / '.git').exists()  # .agents/ is untracked here, as on the Mac

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

    def test_agy_write_job_starts_its_branch_from_origin_main(self):
        self.point_agy_at(self.agy_folder)
        self.install_agy_hook()
        result = self.bridge('agy', '--brief', str(self.brief), '--write', '--branch', 'docs')
        self.assertEqual(result.returncode, 0, result.stderr)
        branch = subprocess.run(['git', '-C', str(self.agy_folder), 'branch', '--show-current'],
                                capture_output=True, text=True).stdout.strip()
        self.assertEqual(branch, 'antigravity/docs')
        self.assertIn('branch antigravity/docs', self.calls()[0]['argv'][1])

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

    def test_status_names_what_is_installed(self):
        self.point_agy_at(self.agy_folder)
        result = self.bridge('status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('codex guard hook: missing', result.stdout)
        self.assertIn('agy project folders: ~/code/brickson-antigravity', result.stdout)


if __name__ == '__main__':
    unittest.main()
