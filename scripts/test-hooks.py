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
            '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null',
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

    def configure(self, key, value):
        subprocess.run(['git', '-C', str(self.repo), 'config', '--add', key, value],
                       check=True)
        self.addCleanup(subprocess.run,
                        ['git', '-C', str(self.repo), 'config', '--unset-all', key],
                        capture_output=True)

    def test_wildcard_pushes_cannot_include_a_protected_branch(self):
        for pattern in ['refs/heads/*:refs/heads/*', 'refs/*:refs/*', 'ma*:ma*', '*:*']:
            with self.subTest(pattern=pattern):
                self.assertDenied(f"git push origin '{pattern}'")
        self.assertAllowed("git push origin 'refs/heads/claude/*:refs/heads/claude/*'")

    def test_copilot_issue_assignments_are_denied(self):
        for command in ['gh issue edit 12 --add-assignee @copilot',
                        'gh issue edit 12 --add-assignee=@copilot',
                        'gh issue create --assignee=@copilot',
                        'gh pr edit 12 --add-assignee @copilot']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('gh issue edit 12 --remove-assignee @copilot')
        self.assertAllowed('gh issue edit 12 --add-assignee @me')

    def test_attached_copilot_reviewer_options_are_denied(self):
        for command in ['gh pr edit 12 --add-reviewer=@copilot',
                        'gh pr create --reviewer=@copilot',
                        'gh pr create -r@copilot',
                        'gh pr edit 12 --add-reviewer=human,@copilot']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('gh pr edit 12 --remove-reviewer=@copilot')
        self.assertAllowed('gh pr edit 12 --add-reviewer=human')

    def test_wrapper_operands_do_not_hide_commands(self):
        for wrapper in ['env -u HOME', 'env --unset HOME', 'env --unset=HOME',
                        'env -uHOME', 'timeout 5s', 'timeout -k 1s 5s',
                        'timeout --kill-after=1s 0.5m', 'nice -n 5']:
            with self.subTest(wrapper=wrapper):
                self.assertDenied(f'{wrapper} git add -A')
                self.assertAllowed(f'{wrapper} git add docs/HANDOFF.md')

    def test_push_queries_use_the_selected_repository(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
            for selector in [f'--git-dir={other}/.git', f'--git-dir {other}/.git',
                             f'--git-dir={other.name}/.git --work-tree={other.name}',
                             f'-C {other.name}', f'-C{other.name}']:
                with self.subTest(selector=selector):
                    self.assertDenied(f'git {selector} push')

    def test_git_environment_selects_the_repository_for_push_checks(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
            for prefix in [f'GIT_DIR={other}/.git', f'env GIT_DIR={other}/.git',
                           f'GIT_DIR={other}/.git GIT_WORK_TREE={other}']:
                with self.subTest(prefix=prefix):
                    self.assertDenied(f'{prefix} git push origin')
                    self.assertAllowed(f'{prefix} git push origin HEAD:claude/topic')
            self.assertDenied(f"env GIT_DIR={other}/.git bash -c 'git push origin'")
            self.assertAllowed(f'GIT_DIR={other}/.git env -u GIT_DIR git push origin')
            self.assertAllowed(f'GIT_DIR={other}/.git env --unset=GIT_DIR git push origin')

    def test_sudo_option_operands_do_not_hide_commands(self):
        for wrapper in ['sudo -u root', 'sudo --user root', 'sudo -g staff',
                        'sudo -u root -g staff', 'sudo --user=root']:
            with self.subTest(wrapper=wrapper):
                self.assertDenied(f'{wrapper} git add -A')
                self.assertDenied(f'{wrapper} gh pr merge 17')
                self.assertAllowed(f'{wrapper} git add docs/HANDOFF.md')

    def test_configured_push_destinations_are_checked(self):
        self.configure('remote.origin.push', 'HEAD:main')
        for command in ['git push', 'git push origin', 'git push --repo origin']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('git push origin HEAD:claude/topic')

    def test_matching_push_default_is_denied(self):
        self.configure('push.default', 'matching')
        self.assertDenied('git push origin')
        self.assertAllowed('git push origin HEAD:claude/topic')

    def test_push_remote_selection_and_command_configuration_are_preserved(self):
        self.configure('branch.claude/topic.pushRemote', 'publish')
        self.configure('remote.publish.push', 'HEAD:main')
        self.assertDenied('git push')
        self.assertAllowed('git push origin')
        self.assertDenied('git -c remote.origin.push=HEAD:main push origin')
        self.assertDenied('git -c push.default=matching push origin')
        self.assertAllowed('git -c remote.origin.push=HEAD:claude/topic push origin')

    def test_attached_boolean_approval_options_are_denied(self):
        for flag in ['--approve=true', '-a=true', '--approve=1', '-a=TRUE']:
            with self.subTest(flag=flag):
                self.assertDenied(f'gh pr review 12 {flag}')
        self.assertAllowed('gh pr review 12 --approve=false --comment -b ok')

    def test_a_failed_cd_keeps_the_previous_push_destination(self):
        subprocess.run(['git', '-C', str(self.repo), 'checkout', '-q', 'main'], check=True)
        try:
            self.assertDenied('cd missing-directory; git push')
            self.assertDenied('cd missing-directory || true; git push')
            # Even an existing directory may fail to open. With &&, the push
            # runs only after success; with ;, the old repository also matters.
            with tempfile.TemporaryDirectory(dir=self.repo) as folder:
                subprocess.run(['git', 'init', '-q', '-b', 'claude/other', folder],
                               check=True)
                self.assertAllowed(f'cd {folder} && git push')
                self.assertDenied(f'cd {folder}; git push')
        finally:
            subprocess.run(['git', '-C', str(self.repo), 'checkout', '-q', 'claude/topic'],
                           check=True)

    def test_api_bodies_loaded_from_files_are_checked(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'payload.json'
            payload.write_text('{"event":"APPROVE"}')
            for option in [f'--input {payload}', f'--input={payload}']:
                with self.subTest(option=option):
                    self.assertDenied(f'gh api --method POST repos/o/r/pulls/12/reviews {option}')
            payload.write_text('{"event":"COMMENT","body":"Looks good"}')
            self.assertAllowed(f'gh api repos/o/r/pulls/12/reviews --input {payload}')
            payload.write_text('{"query":"mutation { mergePullRequest(input: {}) { clientMutationId } }"}')
            self.assertDenied(f'gh api graphql --input {payload}')
            payload.write_text('{"reviewers":["copilot-pull-request-reviewer[bot]"]}')
            self.assertDenied(f'gh api repos/o/r/pulls/12/requested_reviewers --input {payload}')
            payload.write_text('APPROVE')
            self.assertDenied(f'gh api repos/o/r/pulls/12/reviews -F event=@{payload}')
            self.assertDenied(f'gh api repos/o/r/pulls/12/reviews --field=event=@{payload}')
        self.assertDenied('gh api repos/o/r/pulls/12/reviews --input missing-payload.json')
        self.assertDenied('gh api repos/o/r/pulls/12/reviews --input -')

    def test_other_api_clients_check_the_same_approval_payloads(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'payload.json'
            payload.write_text('{"event":"APPROVE"}')
            endpoint = 'https://api.github.com/repos/o/r/pulls/12/reviews'
            for command in [f'curl {endpoint} --data @{payload}',
                            f'curl {endpoint} --data-binary=@{payload}',
                            f'curl {endpoint} --json @{payload}',
                            f'wget {endpoint} --post-file={payload}']:
                with self.subTest(command=command):
                    self.assertDenied(command)
            payload.write_text('{"event":"COMMENT","body":"Looks good"}')
            self.assertAllowed(f'curl {endpoint} --data @{payload}')
            # A non-GitHub endpoint must not cause the guard to open files.
            self.assertAllowed('curl https://example.com --data @missing.json')

    def test_api_assignment_payloads_cannot_start_copilot(self):
        self.assertDenied("gh api repos/o/r/issues/12/assignees -f 'assignees[]=@copilot'")
        self.assertAllowed("gh api repos/o/r/issues/12/assignees -f 'assignees[]=human'")

    def test_issue_create_and_update_payloads_cannot_assign_copilot(self):
        for method, endpoint in [('POST', 'repos/o/r/issues'),
                                 ('PATCH', 'repos/o/r/issues/12')]:
            for field in ["-f 'assignees[]=copilot-swe-agent[bot]'",
                          "--raw-field=assignees[]=copilot-swe-agent[bot]",
                          "-Fassignees[]=copilot-swe-agent[bot]"]:
                with self.subTest(method=method, field=field):
                    self.assertDenied(f'gh api --method {method} {endpoint} {field}')
            with tempfile.TemporaryDirectory(dir=self.repo) as folder:
                payload = Path(folder) / 'payload.json'
                payload.write_text('{"assignees":["human","copilot-swe-agent[bot]"]}')
                for command in [f'gh api --method {method} {endpoint} --input {payload}',
                                f'curl -X {method} https://api.github.com/{endpoint} --json @{payload}']:
                    with self.subTest(command=command):
                        self.assertDenied(command)
                payload.write_text('{"assignees":["human"],"body":"Discuss Copilot and assignees[]=copilot."}')
                self.assertAllowed(f'gh api --method {method} {endpoint} --input {payload}')
            self.assertAllowed(f"gh api --method {method} {endpoint} -f 'assignees[]=human' -f 'body=Discuss Copilot'")
        self.assertAllowed("gh api repos/o/r/issues/12/comments -f 'body=Discuss Copilot assignments'")

    def test_rest_branch_merges_cannot_target_main(self):
        endpoint = 'repos/o/r/merges'
        for field in ['-f base=main', '--field=base=main', '-Fbase=refs/heads/main',
                      '-f base=master']:
            with self.subTest(field=field):
                self.assertDenied(f'gh api {endpoint} -X POST {field} -f head=claude/topic')
        self.assertAllowed(f'gh api {endpoint} -X POST -f base=claude/topic -f head=main')
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'payload.json'
            payload.write_text('{"base":"main","head":"claude/topic"}')
            for command in [f'gh api {endpoint} -X POST --input {payload}',
                            f'curl -X POST https://api.github.com/{endpoint} --json @{payload}']:
                with self.subTest(command=command):
                    self.assertDenied(command)
            payload.write_text('{"base":"claude/topic","head":"main"}')
            self.assertAllowed(f'gh api {endpoint} -X POST --input {payload}')

    def test_staging_everything_is_denied(self):
        for command in ['git add -A', 'git add --all', 'git add .', 'git add -u',
                        'git add -vA', 'git add :/', 'git -C . add -A',
                        'cd docs && git add .', 'git commit -am "x"',
                        'git commit --all -m x', 'git status; git add -A',
                        'FOO=1 command git add --all', 'bash -lc "git add -A"',
                        "env bash -lc 'git add -A'", "command bash -c 'git add .'",
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
                        'git push --mirror origin', 'git push -u origin main',
                        'git push origin :', 'git push --repo origin main',
                        'git push --repo=origin HEAD:main']:
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
                        'gh --repo=MiddleAgedBanana/Brickson pr merge 12',
                        'gh -RMiddleAgedBanana/Brickson pr review 12 --approve',
                        "command bash -lc 'gh pr merge 12'",
                        'gh pr review 12 --approve',
                        'gh api -X PUT repos/o/r/pulls/12/merge',
                        'gh api graphql -f query="mutation { mergePullRequest(input: {}) { clientMutationId } }"',
                        'gh api graphql -f query="mutation { enablePullRequestAutoMerge(input: {}) { clientMutationId } }"',
                        'curl -X PUT https://api.github.com/repos/o/r/pulls/12/merge',
                        'curl -X PUT api.github.com/repos/o/r/pulls/12/merge']:
            self.assertDenied(command)

    def test_requesting_copilot_through_the_api_is_denied(self):
        for command in [
                "gh api --method POST repos/o/r/pulls/12/requested_reviewers "
                "-f 'reviewers[]=copilot-pull-request-reviewer[bot]'",
                'curl -X POST https://api.github.com/repos/o/r/pulls/12/requested_reviewers '
                '-d \'{"reviewers":["copilot-pull-request-reviewer[bot]"]}\'']:
            self.assertDenied(command)
        self.assertAllowed("gh api --method POST repos/o/r/pulls/12/requested_reviewers "
                           "-f 'reviewers[]=MiddleAgedBanana'")

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
        tools = ['merge_pull_request', 'enable_pr_auto_merge', 'request_copilot_review',
                 'assign_copilot_to_issue', 'create_pull_request_with_copilot',
                 'push_files', 'create_or_update_file', 'delete_file',
                 'pull_request_review_write', 'update_pull_request']
        for tool in ['Bash'] + [f'mcp__github__{t}' for t in tools]:
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
