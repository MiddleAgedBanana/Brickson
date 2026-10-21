#!/usr/bin/env python3
"""Check the Claude Code guard in .claude/hooks/guard.py.

Run with python3 scripts/test-hooks.py; standard library only. scripts/test.sh
runs it before the unit tests, so CI runs it too. Each test feeds the guard
a tool call the way Claude Code does and reads its decision. Removing a rule
from the guard, or loosening one, fails a test here.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GUARD = ROOT / '.claude' / 'hooks' / 'guard.py'
SETTINGS = ROOT / '.claude' / 'settings.json'


def decision(tool_name, tool_input, cwd):
    call = {'hook_event_name': 'PreToolUse', 'tool_name': tool_name,
            'tool_input': tool_input, 'cwd': str(cwd)}
    result = subprocess.run([sys.executable, str(GUARD)], input=json.dumps(call),
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr
    if not result.stdout.strip():
        return None
    return json.loads(result.stdout)['hookSpecificOutput']['permissionDecision']


class GuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # A throwaway repository with a feature branch and a main branch.
        cls.folder = tempfile.TemporaryDirectory()
        cls.repo = Path(cls.folder.name)
        def git(*args):
            subprocess.run(['git', '-C', str(cls.repo), *args], check=True,
                           capture_output=True)
        git('init', '-q', '-b', 'main')
        git('-c', 'user.name=t', '-c', 'user.email=t@example.com',
            'commit', '-q', '--allow-empty', '-m', 'start')
        git('checkout', '-q', '-b', 'claude/topic')

    @classmethod
    def tearDownClass(cls):
        cls.folder.cleanup()

    def bash(self, command, cwd=None):
        return decision('Bash', {'command': command}, cwd or self.repo)

    def assertDenied(self, command, cwd=None):
        self.assertEqual(self.bash(command, cwd), 'deny', command)

    def assertAllowed(self, command, cwd=None):
        self.assertIsNone(self.bash(command, cwd), command)

    def test_staging_everything_is_denied(self):
        for command in ['git add -A', 'git add --all', 'git add .', 'git add -u',
                        'git add -vA', 'git add :/', 'git -C . add -A',
                        'cd docs && git add .', 'git commit -am "x"',
                        'git commit --all -m x', 'git status; git add -A',
                        'FOO=1 command git add --all', 'bash -lc "git add -A"',
                        'echo $(git add -A)']:
            self.assertDenied(command)

    def test_staging_named_paths_is_allowed(self):
        for command in ['git add docs/HANDOFF.md scripts/test-docs.py',
                        'git add -p Brickson/Home/HomeView.swift',
                        'git commit -m "Stop git add -A and gh pr merge"',
                        'git commit -mall', 'git commit --amend -m x',
                        'echo "git add -A"', 'grep -rn "git add -A" AGENTS.md']:
            self.assertAllowed(command)

    def test_force_pushes_are_denied(self):
        for command in ['git push --force origin claude/topic',
                        'git push -f origin claude/topic',
                        'git push --force-with-lease origin claude/topic',
                        'git push origin +claude/topic',
                        'git push -uf origin claude/topic']:
            self.assertDenied(command)

    def test_pushes_to_main_are_denied(self):
        for command in ['git push origin main', 'git push origin HEAD:main',
                        'git push origin claude/topic:refs/heads/main',
                        'git push origin --delete main', 'git push --all origin',
                        'git push --mirror origin', 'git push -u origin main']:
            self.assertDenied(command)

    def test_a_bare_push_from_main_is_denied(self):
        subprocess.run(['git', '-C', str(self.repo), 'checkout', '-q', 'main'], check=True)
        try:
            self.assertDenied('git push')
            self.assertDenied('git push origin')
            self.assertDenied('git push origin HEAD')
        finally:
            subprocess.run(['git', '-C', str(self.repo), 'checkout', '-q', 'claude/topic'],
                           check=True)

    def test_pushing_a_feature_branch_is_allowed(self):
        for command in ['git push -u origin claude/topic', 'git push origin HEAD',
                        'git push', 'git push origin claude/topic:claude/topic',
                        'git fetch origin main', 'git pull origin main']:
            self.assertAllowed(command)

    def test_merging_or_approving_a_pull_request_is_denied(self):
        for command in ['gh pr merge 12', 'gh pr merge --auto --squash 12',
                        'gh -R MiddleAgedBanana/Brickson pr merge 12',
                        'gh pr review 12 --approve',
                        'gh api -X PUT repos/o/r/pulls/12/merge',
                        'gh api graphql -f query="mutation { mergePullRequest(input: {}) { clientMutationId } }"',
                        'gh api graphql -f query="mutation { enablePullRequestAutoMerge(input: {}) { clientMutationId } }"',
                        'curl -X PUT https://api.github.com/repos/o/r/pulls/12/merge',
                        'curl -X PUT api.github.com/repos/o/r/pulls/12/merge']:
            self.assertDenied(command)

    def test_reading_pull_requests_is_allowed(self):
        for command in ['gh pr view 12', 'gh pr checks 12', 'gh pr create --fill',
                        'gh api repos/o/r/pulls/12', 'gh pr review 12 --comment -b ok',
                        'git merge origin/main', 'git log --merges',
                        'curl https://example.com/api.github.com/pulls/1/merge',
                        'curl https://api.github.com.example.com/repos/o/r/pulls/1/merge']:
            self.assertAllowed(command)

    def test_github_tools_that_merge_or_write_main_are_denied(self):
        for name, arguments in [
                ('mcp__github__merge_pull_request', {'pullNumber': 12}),
                ('mcp__github__enable_pr_auto_merge', {'pullNumber': 12}),
                ('mcp__github__request_copilot_review', {'pullNumber': 12}),
                ('mcp__github__assign_copilot_to_issue', {'issueNumber': 1}),
                ('mcp__github__create_pull_request_with_copilot', {}),
                ('mcp__github__push_files', {'branch': 'main'}),
                ('mcp__github__create_or_update_file', {'branch': 'refs/heads/main'}),
                ('mcp__github__delete_file', {'branch': 'main'}),
                ('mcp__github__pull_request_review_write', {'event': 'APPROVE'}),
                ('mcp__github__update_pull_request', {'reviewers': ['copilot']})]:
            self.assertEqual(decision(name, arguments, self.repo), 'deny', name)

    def test_github_tools_on_a_branch_are_allowed(self):
        for name, arguments in [
                ('mcp__github__push_files', {'branch': 'claude/topic'}),
                ('mcp__github__pull_request_review_write', {'event': 'COMMENT'}),
                ('mcp__github__update_pull_request', {'reviewers': ['MiddleAgedBanana']}),
                ('mcp__github__pull_request_read', {'pullNumber': 12})]:
            self.assertIsNone(decision(name, arguments, self.repo), name)

    def test_unreadable_input_decides_nothing(self):
        result = subprocess.run([sys.executable, str(GUARD)], input='not json',
                                capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout), (0, ''))


class SettingsTests(unittest.TestCase):
    """Unhooking the guard, or dropping a deny rule, must fail."""

    def setUp(self):
        self.settings = json.loads(SETTINGS.read_text())

    def test_the_guard_runs_before_bash_and_the_github_tools(self):
        import re
        groups = self.settings['hooks']['PreToolUse']
        for tool in ['Bash', 'mcp__github__merge_pull_request',
                     'mcp__github__enable_pr_auto_merge', 'mcp__github__push_files',
                     'mcp__github__request_copilot_review']:
            commands = [hook['command'] for group in groups
                        if re.fullmatch(group['matcher'], tool)
                        for hook in group['hooks']]
            self.assertTrue(any('.claude/hooks/guard.py' in c for c in commands), tool)

    def test_merging_and_copilot_tools_are_denied_outright(self):
        deny = set(self.settings['permissions']['deny'])
        for tool in ['merge_pull_request', 'enable_pr_auto_merge', 'request_copilot_review',
                     'assign_copilot_to_issue', 'create_pull_request_with_copilot']:
            self.assertIn(f'mcp__github__{tool}', deny)


if __name__ == '__main__':
    unittest.main()
