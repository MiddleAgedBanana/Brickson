#!/usr/bin/env python3
"""Check the Claude Code guard in .claude/hooks/guard.py.

Run with python3 scripts/test-hooks.py; standard library only. scripts/test.sh
runs it before the unit tests, so CI runs it too. Each test feeds the guard
a tool call the way Claude Code does and reads its decision. Removing a rule
from the guard, or loosening one, fails a test here.
"""
import ast
import base64
import json
import shlex
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import os
import pwd
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
GUARD = ROOT / '.claude' / 'hooks' / 'guard.py'
SETTINGS = ROOT / '.claude' / 'settings.json'


# The privacy check reads a private list from the environment and from a
# file under XDG_CONFIG_HOME. Tests use a made-up list and an empty folder,
# so no list on this machine is ever read.
PRIVACY_CONFIG = tempfile.TemporaryDirectory()
PRIVACY_ENVIRONMENT = {'BRICKSON_PRIVATE_WORDS': 'Quillon Vassmere',
                       'XDG_CONFIG_HOME': PRIVACY_CONFIG.name}
HOOK_TEXT = '#!/bin/sh\nexec python3 scripts/privacy-check.py --pre-push "$1"\n'

# Git's settings for the person and the machine would change what the guard
# decides: a global core.hooksPath of .githooks, the setup line a cloud
# session is given, turns the privacy hook on in every test repository. Git
# reads the tests' own file instead, in the tests and in every guard they
# run. It names a made-up person: with no name and address set, git makes
# them up from the machine's account and host name, an address the guard
# rightly refuses, so a commit's identity would depend on the machine.
GIT_CONFIG = tempfile.TemporaryDirectory()
TEST_GIT_CONFIG = Path(GIT_CONFIG.name, 'config')
TEST_GIT_CONFIG.write_text('[user]\n\tname = t\n\temail = t@example.com\n')
GIT_ENVIRONMENT = {'GIT_CONFIG_GLOBAL': str(TEST_GIT_CONFIG),
                   'GIT_CONFIG_SYSTEM': str(TEST_GIT_CONFIG), 'GIT_CONFIG_NOSYSTEM': '1'}
# Variables a git hook or the caller's shell may set would point git, in the
# tests and in the guards they run, at another repository than the one
# named with -C: the caller's own checkout. Others would make the caller,
# not that made-up person, the commits' author or committer.
IDENTITY_VARIABLES = ('GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME',
                      'GIT_COMMITTER_EMAIL', 'EMAIL')
for _variable in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                  'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_PREFIX',
                  *IDENTITY_VARIABLES):
    os.environ.pop(_variable, None)
os.environ.update(GIT_ENVIRONMENT)


def guard_environment(**overrides):
    """The environment a guard runs in: this one, with the made-up list
    and none of the machine's Git settings."""
    return {**os.environ, **PRIVACY_ENVIRONMENT, **GIT_ENVIRONMENT, **overrides}


def with_privacy_hook(repo):
    """Give a test repository the privacy hook the guard requires before
    a push, as the owner's checkout has it."""
    hook = Path(repo, '.githooks', 'pre-push')
    hook.parent.mkdir(exist_ok=True)
    hook.write_text(HOOK_TEXT)
    hook.chmod(0o755)
    subprocess.run(['git', '-C', str(repo), 'config', 'core.hooksPath', '.githooks'],
                   check=True)


def init_repository(folder, branch):
    subprocess.run(['git', 'init', '-q', '-b', branch, str(folder)], check=True)
    with_privacy_hook(folder)


def guard_output(tool_name, tool_input, cwd, env=None):
    call = {'hook_event_name': 'PreToolUse', 'tool_name': tool_name,
            'tool_input': tool_input, 'cwd': str(cwd)}
    if env is None:
        env = guard_environment()
    result = subprocess.run([sys.executable, str(GUARD)], input=json.dumps(call),
                            capture_output=True, text=True, timeout=30, env=env)
    assert result.returncode == 0, result.stderr
    if not result.stdout.strip():
        return None
    return json.loads(result.stdout)['hookSpecificOutput']


def decision(tool_name, tool_input, cwd, env=None):
    output = guard_output(tool_name, tool_input, cwd, env)
    return output and output['permissionDecision']


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
        with_privacy_hook(cls.repo)

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

    def test_push_destinations_require_literal_operands(self):
        for command in ['branch=main; git push origin "$branch"',
                        'ref=HEAD:main; git push origin "$ref"',
                        'git push origin HEAD:${branch}', 'git push origin {main,feature}',
                        'git push "$remote"', 'git push --repo="$remote"']:
            self.assertDenied(command)
        self.assertAllowed('git push origin HEAD:feature')
        self.assertDenied('git push --dry-run origin "$branch"')
        self.assertDenied('flags=--no-dry-run; git push --dry-run origin main "$flags"')
        self.assertAllowed('git push --dry-run origin main')

    def test_wget_input_urls_require_explicit_operands(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            urls = Path(folder) / 'urls.txt'
            urls.write_text('https://api.github.com/repos/o/r/pulls/12/merge\n')
            for option in [f'-i {urls}', f'-i{urls}', f'-qi{urls}',
                           f'--input-file={urls}', f'--input {urls}']:
                self.assertDenied('wget --no-config --method=PUT ' + option)
        self.assertDenied('wget --no-config --input-file=- --method=PUT')
        self.assertAllowed('wget --no-config https://example.com')

    def test_curl_expansion_options_require_explicit_values(self):
        endpoint = 'https://api.github.com/repos/o/r/pulls/12/merge'
        self.assertDenied("curl -q --variable u=" + endpoint + " --expand-url '{{u}}' -X PUT")
        self.assertDenied("curl -q --expand-url='{{u}}' -X PUT")
        self.assertDenied("curl -q --expand-request '{{method}}' " + endpoint)
        self.assertAllowed("curl -q -H '--expand-url' https://example.com")
        self.assertAllowed('curl -q --url https://example.com')

    def test_encoded_copilot_endpoints_are_checked(self):
        for endpoint in ['issues/12/%61ssignees', 'pulls/12/requested%5freviewers']:
            path = 'repos/o/r/' + endpoint
            field = 'reviewers' if endpoint.startswith('pulls/') else 'assignees'
            self.assertDenied('gh api --method POST ' + path + f" -f '{field}[]=copilot-swe-agent[bot]'")
            self.assertDenied('curl -q -X POST https://api.github.com/' + path +
                              ' --json ' + shlex.quote(json.dumps({field:['copilot-swe-agent[bot]']})))
            self.assertAllowed('curl -q -X POST https://api.github.com/' + path +
                               ' --json ' + shlex.quote(json.dumps({field:['human']})))
        self.assertAllowed('gh api repos/o/r/issues/12/%61ssignees')

    def test_trap_actions_require_inspectable_safe_commands(self):
        # A trap's push runs wherever the shell ends, so whether that
        # checkout runs the privacy hook is unknown: it is denied too.
        for command in ["trap 'git push origin main' EXIT", "trap -- 'git add -A' EXIT",
                        "trap 'gh pr merge 12' INT TERM", 'trap "$action" EXIT',
                        "trap 'git push origin' EXIT", "trap 'git push origin HEAD:feature' EXIT"]:
            self.assertDenied(command)
        for command in ["trap 'git status' EXIT",
                        "trap '' INT", 'trap - EXIT', 'trap -p', 'trap -l', 'trap -- - EXIT']:
            self.assertAllowed(command)

    def test_expanding_pathspecs_require_literal_paths(self):
        for path in ['"$PWD"', '~+', '{.,README.md}', '"${PWD}"', '"$paths"']:
            self.assertDenied(f'git add {path}')
            self.assertDenied(f'git commit -m update -- {path}')
        self.assertAllowed('git add docs/HANDOFF.md')
        self.assertAllowed("git commit -m '$PWD is mentioned' -- docs/HANDOFF.md")

    def test_branch_rename_invalidates_implicit_push_destination(self):
        self.configure('push.default', 'current')
        for command in ['git branch -M main', 'git branch -m main',
                        'git branch --move main', 'git branch --mo main',
                        'git symbolic-ref HEAD refs/heads/main']:
            self.assertDenied(command + ' && git push origin')
            self.assertDenied(command + ' && git push origin HEAD')
            self.assertAllowed(command + ' && git push origin HEAD:feature')
        self.assertAllowed('git branch --show-current && git push origin')
        self.assertAllowed('git symbolic-ref HEAD && git push origin')

    def test_xargs_runtime_arguments_are_unknown(self):
        for command in ['echo HEAD:main | xargs git push origin',
                        "printf '%s\\n' -A | xargs git add",
                        'xargs -a args.txt git push origin feature',
                        'printf main | xargs -I {} git push origin HEAD:{}',
                        'echo --approve | xargs gh pr review 12']:
            self.assertDenied(command)
        self.assertAllowed('printf README.md | xargs git status --short')
        self.assertAllowed('printf hello | xargs echo')

    def test_gh_review_short_clusters_are_inspected(self):
        for option in ['-ab looks-good', '-cab looks-good', '-ablooks-good', '-ra']:
            self.assertDenied('gh pr review 12 ' + option)
        for option in ['-cb approved', '-ba', '-b --approve',
                       '--body=-ab --comment', '--approve=false --comment']:
            self.assertAllowed('gh pr review 12 ' + option)

    def test_named_shell_scripts_require_inspectable_commands(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            script = Path(folder) / 'run.sh'
            script.write_text('git add -A\n')
            for shell in ['bash', 'sh', 'zsh', 'dash']:
                self.assertDenied(f'{shell} {script}')
                self.assertDenied(f'{shell} -- {script}')
            script.write_text('git status\n')
            self.assertDenied(f'bash {script}')  # file may change before execution
        self.assertAllowed("bash -c 'git status'")
        self.assertAllowed('bash --help')

    def test_push_abbreviations_require_full_option_names(self):
        for option in ['--mir', '--force-w', '--force-w=main:abc', '--force-i', '--al', '--bra']:
            self.assertDenied(f'git push {option} origin')
        self.assertDenied('git push --dry-run --no-dry origin main')
        self.assertAllowed('git push --dry-run --mirror origin')
        self.assertAllowed('git push origin feature')
        self.assertAllowed('git push -o --mir origin feature')  # option payload, not a flag

    def test_wget_request_options_require_full_names(self):
        endpoint = 'https://api.github.com/repos/o/r/pulls/12/merge'
        for option in ['--met=PUT', '--meth PUT', '--metho=PUT']:
            self.assertDenied(f'wget --no-config {option} {endpoint}')
        self.assertDenied('wget --no-config --post-d=' + shlex.quote('{"event":"APPROVE"}') +
                          ' https://api.github.com/repos/o/r/pulls/12/reviews')
        self.assertAllowed(f'wget --no-config --method GET {endpoint}')

    def test_singular_issue_assignment_is_checked(self):
        endpoint = 'repos/o/r/issues/12'
        self.assertDenied(f"gh api --method PATCH {endpoint} -f 'assignee=copilot-swe-agent[bot]'")
        self.assertDenied('curl -q -X PATCH https://api.github.com/' + endpoint +
                          ' --json ' + shlex.quote('{"assignee":"copilot-swe-agent[bot]"}'))
        self.assertAllowed(f'gh api --method PATCH {endpoint} -f assignee=human')
        self.assertAllowed('curl -q -X PATCH https://api.github.com/' + endpoint +
                           ' --json ' + shlex.quote('{"assignee":null,"body":"copilot is mentioned here"}'))

    def test_shell_script_follows_the_option_terminator(self):
        for options in ['-c --', '-lc --']:
            self.assertDenied(f"bash {options} 'git add -A'")
            self.assertDenied(f"bash {options} 'gh pr merge 12'")
            self.assertAllowed(f"bash {options} 'git status'")

    def test_nested_command_substitutions_are_fully_checked(self):
        for script in ['((1)); git add -A', '((1 + (2))); git add -A',
                       'echo "$(git add -A)"', "printf ')'; git add -A"]:
            self.assertDenied('echo "$( ' + script.replace('"', '\\"') + ')"')
        self.assertAllowed('echo "$( ((1 + (2))); git status )"')
        self.assertAllowed('echo "$(printf \'(\'; git status)"')

    def test_curl_upload_bodies_are_inspected(self):
        endpoint = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'upload.json'
            for event in ['APPROVE', 'COMMENT']:
                payload.write_text(json.dumps({'event':event}))
                for option in [f'-T {payload}', f'-T{payload}',
                               f'--upload-file {payload}', f'--upload-file={payload}']:
                    command = f'curl -q -X POST {option} {endpoint}'
                    (self.assertDenied if event == 'APPROVE' else self.assertAllowed)(command)
        for source in ['-', '.', 'missing.json', '{approve,comment}.json']:
            self.assertDenied(f'curl -q -X POST -T {shlex.quote(source)} {endpoint}')

    def test_branch_changes_require_explicit_push_destinations(self):
        checkouts = ['git checkout main', 'git switch main', "bash -c 'git switch main'",
                     '(git checkout main)']
        for change in checkouts + ['git branch -m renamed']:
            self.assertDenied(f'{change} && git push')
            self.assertDenied(f'{change}; git push origin')
            self.assertDenied(f'{change} && git push origin HEAD')
        # A renamed branch keeps its files, so a push that names its
        # destination is read as written. Another branch checked out may
        # bring another hook, so its push waits for a command of its own
        # (PrivacyGuardTests, test_a_push_after_a_change_to_the_hook_in_the_same_call_is_refused).
        self.assertAllowed('git branch -m renamed && git push origin HEAD:feature')
        for change in checkouts:
            output = guard_output('Bash', {'command': f'{change} && git push origin HEAD:feature'},
                                  self.repo)
            self.assertEqual(output and output['permissionDecision'], 'deny', change)
            self.assertIn('push in the next', output['permissionDecisionReason'])
        self.assertAllowed('git switch main')
        self.assertAllowed('git checkout main && git push --dry-run origin main')
        self.assertAllowed('git status && git push origin feature')

    def test_wget_execute_and_config_directives_require_explicit_options(self):
        url = 'https://api.github.com/repos/o/r/pulls/12/merge'
        for options in ['-e method=PUT', '-emethod=PUT', '-qe method=PUT',
                        '--execute=method=PUT', '--execute method=PUT',
                        '--exec=method=PUT', '--config=request.rc']:
            self.assertDenied(f'wget --no-config {options} {url}')
        self.assertDenied(f'wget {url}')
        self.assertAllowed(f'wget --no-config {url}')
        self.assertDenied(f'wget --no-config --method=PUT {url}')

    def test_curl_implicit_config_requires_a_leading_disable(self):
        url = 'https://api.github.com/repos/o/r/pulls/12/merge'
        for options in ['', '-s -q', '-s --disable', '--url']:
            self.assertDenied(f'curl {options} {url}')
        for options in ['-q', '--disable']:
            self.assertAllowed(f'curl {options} {url}')
            self.assertDenied(f'curl {options} -X PUT {url}')
            self.assertDenied(f'curl {options} --config request.rc {url}')
            self.assertAllowed(f'curl {options} https://example.com --next {url}')
        self.assertAllowed('curl https://example.com')

    def test_send_pack_requires_the_inspectable_push_command(self):
        for options in ['', '--force', '--all', '--mirror', '--dry-run']:
            self.assertDenied(f'git send-pack {options} origin refs/heads/main')
        self.assertDenied('git send-pack origin refs/heads/claude/topic')
        self.assertAllowed('git push origin HEAD:refs/heads/claude/topic')

    def test_locale_translated_shell_words_require_literal_commands(self):
        self.assertDenied('bash -c $"git add -A"')
        self.assertDenied('bash -c $"git status"')  # translation may change its text
        self.assertDenied('$"git" add -A')
        self.assertAllowed('bash -c "git status"')
        self.assertAllowed("printf '%s' '$\"git add -A\"'")

    def test_abbreviated_add_options_cannot_select_every_change(self):
        for option in ['--al', '--up', '--upd', '--no-ignore-rem', '--pathspec-from-f=paths']:
            self.assertDenied(f'git add {option}')
            self.assertDenied(f'git stage {option}')
        self.assertAllowed('git add --verbose README.md')
        self.assertAllowed('git add -- --al')

    def test_time_option_operands_keep_the_wrapped_command(self):
        for options in ['-o stats', '-f %E', '--output stats', '--format %E', '-ao stats', '-oout']:
            self.assertDenied(f'/usr/bin/time {options} git add -A')
            self.assertDenied(f'time {options} gh pr merge 12')
            self.assertAllowed(f'time {options} git status')

    def test_ansi_c_here_document_delimiters_do_not_hide_commands(self):
        for delimiter in ["$'END'", r"$'E\x4eD'", "$'E'ND"]:
            self.assertDenied(f'cat <<{delimiter}\ntext\nEND\ngit add -A')
            self.assertDenied(f'bash <<{delimiter}\ngit add -A\nEND')
            self.assertAllowed(f'cat <<{delimiter}\ngit add -A\nEND\ngit status')

    def test_curl_url_globs_require_explicit_urls_or_globoff(self):
        for suffix in ['{merge,status}', '[1-2]/merge']:
            url = 'https://api.github.com/repos/o/r/pulls/12/' + suffix
            self.assertDenied('curl -q -X PUT ' + shlex.quote(url))
            self.assertAllowed('curl -q -g -X PUT ' + shlex.quote(url))
            self.assertDenied('curl -q -g --no-globoff -X PUT ' + shlex.quote(url))
            self.assertAllowed('curl -q --no-globoff -g -X PUT ' + shlex.quote(url))
        self.assertAllowed('curl -q -X GET https://api.github.com/repos/o/r/pulls/12/merge')

    def test_curl_final_get_and_head_toggles_set_the_method(self):
        url = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        for on, off in [('--get', '--no-get'), ('--head', '--no-head')]:
            self.assertDenied(f'curl -q {on} {off} -d ' + shlex.quote('{"event":"APPROVE"}') + ' ' + url)
            self.assertAllowed(f'curl -q {off} {on} -d ' + shlex.quote('{"event":"APPROVE"}') + ' ' + url)
        self.assertDenied(f'curl -q -GI --no-head --no-get -d ' + shlex.quote('{"event":"APPROVE"}') + ' ' + url)

    def test_httpie_redirected_input_is_checked(self):
        url = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'request.json'
            payload.write_text('{"event":"APPROVE"}')
            self.assertDenied(f'http POST {url} Content-Type:application/json < {payload}')
            self.assertDenied(f'< {payload} https {url}')
            self.assertDenied(f'cat {payload} | http POST {url}')
            self.assertAllowed(f'cat {payload} | http --ignore-stdin GET {url}')
            payload.write_text('{"event":"COMMENT"}')
            self.assertAllowed(f'http POST {url} < {payload}')
            self.assertAllowed(f'< {payload} http {url}')
        self.assertDenied(f"http POST {url} <<'END'\n{{\"event\":\"APPROVE\"}}\nEND")

    def test_rest_agent_tasks_are_owner_only(self):
        endpoint = '/agents/repos/o/r/tasks'
        self.assertDenied(f'gh api --method POST {endpoint} -f prompt=work')
        self.assertDenied(f'curl -q -X POST https://api.github.com{endpoint} -d ' + shlex.quote('{"prompt":"work"}'))
        self.assertAllowed(f'gh api {endpoint}')
        self.assertAllowed(f'gh api {endpoint}/123')

    def test_graphql_agent_assignment_inputs_are_owner_only(self):
        for mutation in ['createIssue', 'updateIssue', 'addAssigneesToAssignable', 'replaceActorsForAssignable']:
            query = 'mutation { ' + mutation + '(input:{agentAssignment:{targetRepositoryId:"R",baseRef:"main"}}) { clientMutationId } }'
            self.assertDenied('gh api graphql -f ' + shlex.quote('query=' + query))
        query = 'mutation($input:CreateIssueInput!) { createIssue(input:$input) { clientMutationId } }'
        payload = json.dumps({'query':query, 'variables':{'input':{'agentAssignment':{'targetRepositoryId':'R'}}}})
        self.assertDenied('curl -q https://api.github.com/graphql --json ' + shlex.quote(payload))
        payload = json.dumps({'query':query, 'variables':{'input':{'title':'agentAssignment is discussed here'}}})
        self.assertAllowed('curl -q https://api.github.com/graphql --json ' + shlex.quote(payload))
        self.assertAllowed('gh api graphql -f ' + shlex.quote('query=mutation { createIssue(input:{title:"agentAssignment: example"}) { clientMutationId } }'))

    def test_graphql_enqueue_is_an_owner_merge_action(self):
        query = 'mutation { enqueuePullRequest(input:{pullRequestId:"ID"}) { clientMutationId } }'
        self.assertDenied('gh api graphql -f ' + shlex.quote('query=' + query))
        self.assertAllowed('gh pr comment 12 --body ' + shlex.quote(query))
        self.assertAllowed('gh api graphql -f ' + shlex.quote('query=query { viewer { login } }'))

    def test_shell_recursion_limit_requires_explicit_commands(self):
        def wrapped(command, count):
            for _ in range(count):
                command = 'bash -c ' + shlex.quote(command)
            return command
        self.assertDenied(wrapped('git add -A', 4))
        self.assertDenied(wrapped('git status', 4))
        self.assertAllowed(wrapped('git status', 3))
        self.assertAllowed('echo ' + shlex.quote(wrapped('git add -A', 4)))

    def test_curl_clusters_keep_values_as_operands(self):
        merge = 'https://api.github.com/repos/o/r/pulls/12/merge'
        review = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        for options in ['-sX PUT', '-sXPUT', '-sST payload.json']:
            self.assertDenied(f'curl -q {options} {merge}')
        for options in ['-sX GET', '-sXGET', '-sSI', '-sH -XPUT', '-so -sXPUT']:
            self.assertAllowed(f'curl -q {options} {merge}')
        self.assertDenied(f'curl -q -sd ' + shlex.quote('{"event":"APPROVE"}') + ' ' + review)
        self.assertDenied(f'curl -q -sF event=APPROVE {review}')
        self.assertAllowed(f'curl -q -sF event=COMMENT {review}')
        self.assertDenied('curl -q -sK config.txt')

    def test_cdpath_does_not_guess_a_relative_repository(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            root = Path(folder)
            local = root / 'local'; other = root / 'other'
            for base, branch in [(local, 'claude/topic'), (other, 'main')]:
                (base / 'repo').mkdir(parents=True)
                init_repository(str(base / 'repo'), branch)
            for prefix in [f'export CDPATH={other};', f'CDPATH={other};', f'CDPATH={other}']:
                self.assertDenied(f'{prefix} cd repo && git push origin', cwd=local)
                self.assertAllowed(f'{prefix} cd ./repo && git push origin', cwd=local)
                self.assertAllowed(f'{prefix} cd repo && git status', cwd=local)
            self.assertAllowed(f'export CDPATH={other}; unset CDPATH; cd repo && git push origin', cwd=local)
            with patch.dict(os.environ, CDPATH=str(other)):
                self.assertDenied('cd repo && git push origin', cwd=local)
                self.assertAllowed('env -u CDPATH bash -c "cd repo && git push origin"', cwd=local)

    def test_shell_standard_input_requires_inspectable_code(self):
        for command in ["printf 'git add -A\\n' | bash", "echo 'gh pr merge 12' | sh",
                        "printf 'git add -A\\n' | bash -s argument", 'bash < commands.sh',
                        '< commands.sh bash', 'cat commands.sh | bash /dev/stdin']:
            self.assertDenied(command)
        self.assertDenied("printf 'git status\\n' | bash")  # unknown pipe input, even when benign
        self.assertAllowed("bash -c 'git status'")
        self.assertDenied("printf 'data' | bash script.sh")  # the program file is uninspected
        self.assertAllowed('bash --version')

    def test_exhaustive_glob_pathspecs_are_all_tree_staging(self):
        for path in [':(glob)**/*', ':(top,glob)**/*', ':(glob,top,icase)**/**/*', '**/*']:
            self.assertDenied('git add ' + shlex.quote(path))
        for path in [':(glob)docs/**/*.md', ':(literal)**/*', 'Brickson/File.swift']:
            self.assertAllowed('git add ' + shlex.quote(path))

    def test_xargs_max_lines_optional_value_stays_attached(self):
        # GNU long optional arguments use =value; a following word is the command.
        for option in ['--max-lines', '--max-lines=1', '-L 1']:
            self.assertDenied('printf x | xargs ' + option + ' git add -A')
            self.assertAllowed('printf x | xargs ' + option + ' git status')

    def test_curl_long_form_fields_are_checked(self):
        endpoint = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        for option in ['--form', '--form-string']:
            self.assertDenied(f'curl -q {endpoint} {option} event=APPROVE')
            self.assertAllowed(f'curl -q {endpoint} {option} event=COMMENT')
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            field = Path(folder) / 'event'
            field.write_text('APPROVE')
            for marker in ['<', '@']:
                self.assertDenied(f'curl -q {endpoint} --form ' + shlex.quote(f'event={marker}{field}'))
            self.assertAllowed(f'curl -q {endpoint} --form-string ' + shlex.quote(f'event=@{field}'))

    def test_the_last_dry_run_option_controls_push(self):
        self.assertDenied('git push -n --no-dry-run origin main')
        self.assertDenied('git push --dry-run --no-dry-run origin main')
        self.assertAllowed('git push --no-dry-run -n origin main')
        self.assertAllowed('git push -n --no-dry-run origin feature')

    def test_process_substitutions_are_checked_in_child_context(self):
        for redirect in ['<', '>']:
            self.assertDenied(f'cat {redirect}(git add -A)')
            self.assertAllowed(f'cat {redirect}(git status)')
        self.assertAllowed("echo '<(git add -A)'")
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertAllowed(f'cat <(cd {folder} && git status); git push origin')
            self.assertDenied(f'cat <(cd {folder} && git push origin)')

    def test_graphql_ref_writes_require_explicit_git_commands(self):
        for query in [
            'mutation { updateRefs(input:{repositoryId:"R",refUpdates:[{name:"refs/heads/main",afterOid:"OID",force:true}]}) { clientMutationId } }',
            'mutation { createCommitOnBranch(input:{branch:{repositoryNameWithOwner:"o/r",branchName:"main"},expectedHeadOid:"OID",message:{headline:"x"}}) { clientMutationId } }',
            'mutation($input:UpdateRefsInput!) { updateRefs(input:$input) { clientMutationId } }']:
            self.assertDenied('gh api graphql -f ' + shlex.quote('query=' + query))
        self.assertAllowed('gh api graphql -f ' + shlex.quote('query=query { viewer { login } }'))
        self.assertAllowed('gh issue comment 12 --body "updateRefs(input: example)"')

    def test_generic_issue_writes_check_assignees(self):
        for tool in ['issue_write', 'create_issue', 'update_issue']:
            self.assertEqual(decision('mcp__github__' + tool,
                {'method': 'update', 'assignees': ['copilot-swe-agent[bot]']}, self.repo), 'deny')
            self.assertIsNone(decision('mcp__github__' + tool,
                {'method': 'update', 'assignees': ['octocat']}, self.repo))

    def test_asynchronous_merge_requests_are_guarded(self):
        endpoint = 'repos/o/r/pulls/12/merge-async'
        self.assertDenied(f'gh api --method PUT {endpoint} -f merge_action=direct_merge')
        self.assertAllowed(f'gh api {endpoint}/example-uuid')

    def test_curl_operations_keep_their_own_method(self):
        merge = 'https://api.github.com/repos/o/r/pulls/12/merge'
        for separator in ['--next', '-:']:
            self.assertDenied(f'curl -q -X PUT {merge} {separator} -X GET https://example.com')
            self.assertDenied(f'curl -q -X GET https://example.com {separator} -X PUT {merge}')
            self.assertAllowed(f'curl -q -X GET {merge} {separator} -X PUT https://example.com')
        self.assertAllowed(f'curl -q -X GET -H "--next" {merge}')

    def test_subshells_restore_the_outer_repository_context(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertAllowed(f'(cd {folder} && git status); git push origin')
            self.assertDenied(f'(cd {self.repo} && git status); git push origin', cwd=folder)
            self.assertDenied(f'(cd {folder} && git push origin); git status')
            self.assertAllowed(f'( (cd {folder} && git status) ); git push origin')
            self.assertDenied(f'(cd {folder} && git status) && git push origin', cwd=folder)
            self.assertAllowed(f'(export GIT_DIR={folder}/.git); git push origin')

    def test_rest_writes_cannot_update_protected_branches(self):
        for method in ['PUT', 'DELETE']:
            prefix = f'gh api --method {method} repos/o/r/contents/file -f message=x -f content=eA=='
            self.assertDenied(prefix + ' -f branch=main')
            self.assertDenied(prefix)
            self.assertDenied(prefix + ' -F branch=null')
            self.assertAllowed(prefix + ' -f branch=feature')
        self.assertDenied('gh api --method PATCH repos/o/r/git/refs/heads/main -f sha=123')
        self.assertDenied('gh api --method DELETE repos/o/r/git/refs/heads/master')
        self.assertDenied('gh api --method POST repos/o/r/git/refs -f ref=refs/heads/main -f sha=123')
        self.assertAllowed('gh api --method PATCH repos/o/r/git/refs/heads/feature -f sha=123')
        self.assertAllowed('gh api repos/o/r/contents/file')
        self.assertAllowed('gh api repos/o/r/git/refs/heads/main')
        self.assertDenied('curl -q -X PUT https://api.github.com/repos/o/r/contents/file -d \'{"branch":"main"}\'')

    def test_ansi_c_quoted_scripts_are_checked(self):
        self.assertDenied("bash -c $'git add -A'")
        self.assertDenied("bash <<< $'gh pr merge 12'")
        self.assertDenied(r"bash -c $'git\x20add\040-A'")
        self.assertAllowed("bash -c $'git status'")
        self.assertAllowed("printf '%s' $'git add -A'")
        self.assertAllowed('echo "bash -c $\'git add -A\'"')

    def test_complete_here_document_delimiters(self):
        for delimiter in ['END:MARK', 'END/NOTE', 'END@NOTE', 'END+NOTE']:
            self.assertDenied(f'cat <<{delimiter}\nordinary text\n{delimiter}\ngit add -A')
            self.assertAllowed(f'cat <<{delimiter}\ngit add -A\n{delimiter}\ngit status')
            self.assertDenied(f'bash <<{delimiter}\ngit add -A\n{delimiter}')

    def test_wrapper_clusters_consume_value_options(self):
        for prefix in ['timeout -vk 1 5', 'timeout -vk1 5', 'xargs -tI {}', 'xargs -tI{}']:
            self.assertDenied(prefix + ' git add -A')
            self.assertAllowed(prefix + ' git status')

    def test_pending_review_submission_checks_approval(self):
        endpoint = 'repos/o/r/pulls/12/reviews/34/events'
        self.assertDenied(f'gh api --method POST {endpoint} -f event=APPROVE')
        self.assertAllowed(f'gh api --method POST {endpoint} -f event=COMMENT')
        self.assertAllowed(f'gh api {endpoint}')

    def test_curl_upload_uses_put_unless_overridden(self):
        endpoint = 'https://api.github.com/repos/o/r/pulls/12/merge'
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            payload = Path(folder) / 'payload.json'
            payload.write_text('{}')
            for option in [f'-T {payload}', f'-T{payload}', f'--upload-file {payload}', f'--upload-file={payload}']:
                self.assertDenied(f'curl -q {option} {endpoint}')
                self.assertAllowed(f'curl -q -X GET {option} {endpoint}')
        self.assertAllowed('curl -q -T payload.json https://example.com/upload')

    def test_push_digit_options_preserve_force_and_dry_run(self):
        for version in ['4', '6']:
            self.assertDenied(f'git push -{version}f origin feature')
            self.assertDenied(f'git push -v{version}f origin feature')
            self.assertAllowed(f'git push -{version}n origin main')
            self.assertAllowed(f'git push -{version}of origin feature')

    def test_gh_aliases_use_the_selected_configuration(self):
        # gh's own read-only alias list decodes its configuration; never run
        # any expanded alias. Fixtures do not touch the user's configuration.
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            config = Path(folder)
            (config / 'config.yml').write_text(
                'aliases:\n  land: -R o/r pr merge\n  inspect: pr view\n  approve: pr review --approve\n'
                "  shell: '!gh pr merge'\n  detail: pr view $1 --json title\n")
            with patch.dict(os.environ, GH_CONFIG_DIR=folder):
                self.assertDenied('gh land 12')
                self.assertDenied('gh approve 12')
                self.assertDenied('gh shell 12')
                self.assertAllowed('gh inspect 12')
                self.assertDenied('gh detail 12')
            self.assertDenied(f'GH_CONFIG_DIR={folder} gh land 12')
            self.assertAllowed(f'env GH_CONFIG_DIR={folder} gh inspect 12')
            (config / 'config.yml').write_text('aliases: {}\n')
            self.assertAllowed(f'GH_CONFIG_DIR={folder} gh pr view 12')

    def test_shell_exports_and_unsets_preserve_repository_context(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            assignment = 'GIT_DIR=' + shlex.quote(str(Path(folder) / '.git'))
            self.assertDenied(f'export {assignment}; git push origin')
            self.assertDenied(f'export {assignment} && git push origin')
            self.assertDenied(f"sh -c 'export {assignment}; git push origin'")
            self.assertAllowed(f'export {assignment}; unset GIT_DIR; git push origin')
            self.assertAllowed(f'export {assignment}; git status')
            self.assertAllowed(f"sh -c 'export {assignment}'; git push origin")
            self.assertAllowed(f'export {assignment} || git push origin')
            with patch.dict(os.environ, GIT_DIR=str(self.repo / '.git')):
                self.assertDenied('unset GIT_DIR; git push origin', cwd=folder)

    def test_xargs_process_slot_operand(self):
        self.assertDenied("printf '' | xargs --process-slot-var SLOT git add -A")
        self.assertAllowed("printf '' | xargs --process-slot-var SLOT git status")

    def test_httpie_request_items(self):
        self.assertDenied('http POST https://api.github.com/repos/o/r/pulls/12/reviews event=APPROVE')
        self.assertDenied('https POST https://api.github.com/repos/o/r/pulls/12/reviews event:=\'"APPROVE"\'')
        self.assertDenied('http POST https://api.github.com/repos/o/r/issues assignees:=\'["copilot"]\'')
        self.assertAllowed('http POST https://api.github.com/repos/o/r/pulls/12/reviews event=COMMENT')
        self.assertAllowed('http POST https://api.github.com/repos/o/r/issues body=APPROVE')

    def test_httpie_options_after_the_url_are_read(self):
        url = 'https://api.github.com/repos/o/r/pulls/12/reviews'
        approve = shlex.quote('{"event":"APPROVE"}')
        for command in [f'http --ignore-stdin POST {url} --raw {approve}',
                        f'http --ignore-stdin POST {url} --raw={approve}',
                        f'http --ignore-stdin {url} --pretty all --raw {approve}',
                        f'http --ignore-stdin POST {url} --raw ' + shlex.quote('{"event":"COMMENT"}')
                        + f' --raw {approve}',
                        f'http --ignore-stdin POST {url} --auth user:x event=APPROVE']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in [f'http --ignore-stdin POST {url} --raw ' + shlex.quote('{"event":"COMMENT"}'),
                        f'http --ignore-stdin GET {url} --auth user:x --pretty all']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_httpie_methods_after_options(self):
        for flags in ['--auth user:example', '-a user:example', '--auth=user:example', '--verify no --pretty all']:
            self.assertDenied(f'http {flags} PUT https://api.github.com/repos/o/r/pulls/12/merge')
            self.assertAllowed(f'http {flags} GET https://api.github.com/repos/o/r/pulls/12/merge')
        self.assertDenied('http https://api.github.com/repos/o/r/pulls/12/reviews event=APPROVE')

    def test_shell_stdin_file_operands(self):
        for path in ['/dev/stdin', '/dev/fd/0']:
            self.assertDenied(f"bash {path} <<< 'git add -A'")
            self.assertAllowed(f"bash {path} <<< 'git status'")

    def test_push_option_values_are_not_dry_run_flags(self):
        for option in ['-on', '-ofn', '-von']:
            self.assertDenied(f'git push {option} origin main')
        self.assertAllowed('git push -vnoexample origin main')
        self.assertAllowed('git push -on origin feature')

    def test_gh_issue_new_inspects_assignments(self):
        self.assertDenied('gh issue new --assignee @copilot --title task --body work')
        self.assertAllowed('gh issue new --assignee octocat --title task --body work')

    def test_leading_redirections_do_not_hide_commands(self):
        for prefix in ['>/tmp/guard-test-log ', '2>/tmp/guard-test-log ', '2>&1 ', '< /tmp/guard-test-input ']:
            self.assertDenied(prefix + 'git add -A')
            self.assertDenied(prefix + 'gh pr merge 12')
            self.assertAllowed(prefix + 'git status')
        self.assertDenied('env > /tmp/guard-test-log git add -A')

    def test_copilot_intent_assignment_is_guarded(self):
        name = 'mcp__github__assign_copilot_to_issue_with_intent'
        for args in [{'is_suggestion': False}, {}]:
            self.assertEqual(decision(name, args, self.repo), 'deny')
        self.assertIsNone(decision(name, {'is_suggestion': True}, self.repo))

    def test_directory_stack_changes_are_checked(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertDenied(f'pushd {folder} && git push origin')
            self.assertDenied(f'pushd {self.repo} && popd && git push origin', cwd=folder)
            self.assertAllowed(f'pushd {folder} && popd && git push origin')
            self.assertAllowed(f'pushd {folder} && git status')
            self.assertDenied('popd && git push origin')

    def test_curl_dot_segments_cannot_hide_endpoints(self):
        endpoint = 'https://api.github.com/repos/o/r/unused/../pulls/12/./merge'
        self.assertDenied('curl -q -X PUT ' + endpoint)
        self.assertAllowed('curl -q -X GET ' + endpoint)

    def test_shell_here_strings_are_checked_as_commands(self):
        for redirect in [' <<< ', '<<<']:
            self.assertDenied(f"bash{redirect}'git add -A'")
            self.assertDenied(f"bash -s{redirect}'gh pr merge 17'")
            self.assertAllowed(f"bash{redirect}'git status'")
            self.assertAllowed(f"cat{redirect}'git add -A'")
        self.assertAllowed("echo 'bash <<< git add -A'")
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertDenied(f"env -C {folder} bash <<< 'git push origin'")
            self.assertAllowed(f"env -C {self.repo} bash <<< 'git push origin'", cwd=folder)

    def test_curl_configuration_files_require_explicit_options(self):
        config = self.repo / 'curl-config'
        config.write_text('url = "https://api.github.com/repos/o/r/pulls/12/merge"\nrequest = "PUT"\n')
        self.addCleanup(config.unlink)
        for option in ['-K ', '-K', '--config ', '--config=']:
            self.assertDenied(f'curl -q {option}{config}')
        self.assertDenied('curl -q -K -')
        self.assertAllowed('curl -q --disable https://api.github.com/repos/o/r/pulls/12/merge')

    def test_git_aliases_use_the_selected_configuration(self):
        self.assertDenied("git -c alias.ship.command='push origin main' ship")
        self.assertAllowed("git -c alias.inspect.command='status --short' inspect")
        self.assertDenied("git -c alias.ship='push origin main' ship")
        self.assertDenied("git -c alias.stagemine='add -A' stagemine")
        self.assertAllowed("git -c alias.stagemine='add docs/HANDOFF.md' stagemine")
        self.assertAllowed("git -c alias.inspect='status --short' inspect")
        self.assertDenied("git -c alias.ship='!git push origin main' ship")
        self.configure('alias.ship', 'push origin main')
        self.assertDenied('git ship')
        self.assertDenied("git -c alias.outer=ship outer")
        self.assertAllowed("git -c alias.ship='push origin feature' ship")
        self.assertDenied("git stage -A")
        self.assertAllowed("git stage docs/HANDOFF.md")
        self.assertAllowed("git -c alias.status='push origin main' status")

    def test_graphql_review_approvals_are_denied(self):
        for mutation in ['addPullRequestReview', 'submitPullRequestReview']:
            for event in ['APPROVE', 'COMMENT', 'REQUEST_CHANGES']:
                query = f'mutation {{ {mutation}(input: {{pullRequestId: "PR_id", event: {event}}}) {{ clientMutationId }} }}'
                command = 'gh api graphql -f ' + shlex.quote('query=' + query)
                if event == 'APPROVE':
                    self.assertDenied(command)
                else:
                    self.assertAllowed(command)
        query = 'mutation($input: AddPullRequestReviewInput!) { addPullRequestReview(input: $input) { clientMutationId } }'
        for event in ['APPROVE', 'COMMENT']:
            payload = json.dumps({'query': query, 'variables': {'input': {'pullRequestId': 'PR_id', 'event': event}}})
            command = 'curl -q https://api.github.com/graphql --json ' + shlex.quote(payload)
            if event == 'APPROVE':
                self.assertDenied(command)
            else:
                self.assertAllowed(command)
        self.assertAllowed("gh api repos/o/r/issues -f body='addPullRequestReview event: APPROVE'")

    def test_push_mode_operands_and_dry_runs(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertDenied('git push --recurse-submodules check origin', cwd=folder)
            self.assertDenied('git push --recurse-submodules=check origin', cwd=folder)
            self.assertAllowed('git push --recurse-submodules check origin HEAD:feature', cwd=folder)
    def test_dry_run_pushes_do_not_write_protected_branches(self):
        for options in ['--dry-run', '-n', '-nf', '--dry-run --force']:
            self.assertAllowed(f'git push {options} origin main')
        self.assertDenied('git push --force origin main')
        self.assertDenied('git push -o --dry-run origin main')

    def test_env_split_string_inspects_its_command(self):
        for option in ['-S ', '-S', '--split-string ', '--split-string=']:
            self.assertDenied(f"env {option}'git add -A'")
            self.assertDenied(f"env {option}'git push origin main'")
            self.assertAllowed(f"env {option}'git add docs/HANDOFF.md'")
        self.assertDenied("env -S 'git add' -A")

    def test_shell_conditions_are_executed_commands(self):
        for keyword in ['if', 'elif', 'while', 'until']:
            self.assertDenied(f'{keyword} git add -A; then echo ok; fi')
            self.assertDenied(f'{keyword} gh pr merge 12; then :; fi')
            self.assertAllowed(f'{keyword} git status; then echo ok; fi')

    def test_sudo_chdir_selects_the_repository(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            for option in [f'-D {folder}', f'-D{folder}', f'--chdir {folder}', f'--chdir={folder}']:
                self.assertDenied(f'sudo {option} git push origin')
                self.assertAllowed(f'sudo {option} git push origin HEAD:feature')

    def test_here_documents_distinguish_data_from_execution(self):
        self.assertAllowed("cat <<'EOF'\ngit add -A\nEOF")
        self.assertAllowed('cat <<EOF\ngit add -A\nEOF')
        self.assertAllowed("cat <<-'EOF'\n\tgit add -A\n\tEOF")
        self.assertAllowed("cat <<'EOF'\n$(git add -A)\nEOF")
        self.assertDenied('cat <<EOF\n$(git add -A)\nEOF')
        self.assertDenied("bash <<'EOF'\ngit add -A\nEOF")
        self.assertDenied("cat <<'EOF' | bash\ngit add -A\nEOF")
        self.assertDenied("cat <<'EOF'\nexample\nEOF\ngit add -A")
        self.assertAllowed("bash <<'EOF'\ngit status\nEOF")
        self.assertAllowed("echo '\n# literal text\ncat <<EOF\ngit add -A\nEOF\n'")
        self.assertDenied("echo '\n# literal text\n'; git add -A")
        self.assertAllowed("cat <<EOF\n\\$(git add -A)\nEOF")

    def test_here_document_substitutions_keep_outer_repository_context(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            init_repository(folder, 'main')
            self.assertDenied(f'env -C {self.repo} bash <<EOF\n$(git push origin)\nEOF', cwd=folder)
            self.assertAllowed(f"env -C {self.repo} bash <<'EOF'\ngit push origin\nEOF", cwd=folder)

    def test_merge_api_checks_use_endpoint_method_and_fields(self):
        endpoint='https://api.github.com/repos/o/r/pulls/12/merge'
        for option in ['', '-X GET', '-XGET', '--request=GET', '-I', '--head']:
            self.assertAllowed(f'curl -q {option} {endpoint}')
        self.assertDenied(f'curl -q -X PUT {endpoint}')
    def test_api_prose_is_not_a_merge_request(self):
        self.assertAllowed("gh api repos/o/r/issues -f title='Document automerge behavior'")
        self.assertAllowed("gh api repos/o/r/issues -f body='Discuss mergePullRequest and event=APPROVE'")
        self.assertAllowed('curl -q https://api.github.com/repos/o/r/issues --json \'{"body":"mergePullRequest automerge event=APPROVE"}\'')
        self.assertDenied('curl -q https://api.github.com/graphql --json \'{"query":"mutation { mergePullRequest(input: {}) { clientMutationId } }"}\'')

    def test_exclusion_only_pathspecs_require_positive_named_paths(self):
        # These inputs are JSON for the hook, never executed Git commands.
        for exclusion in [':(exclude)docs/HANDOFF.md', ':!docs/HANDOFF.md',
                          ':^docs/HANDOFF.md', ':(top,exclude)docs/HANDOFF.md']:
            for operation in ['add', 'commit -m note --']:
                with self.subTest(exclusion=exclusion, operation=operation):
                    self.assertDenied(f"git {operation} '{exclusion}'")
                    self.assertDenied(f"git {operation} '{exclusion}' ':!README.md'")
                    self.assertAllowed(f"git {operation} docs/DECISIONS.md '{exclusion}'")
        self.assertAllowed('git commit -m note')

    def test_xargs_operands_do_not_hide_the_command(self):
        for options in ['-n 4', '-L 2', '-I {}', '-P 2', '-s 1000',
                        '-E stop', '-J {}', '-R 2', '-S 2000',
                        '--max-args 4', '--replace={}', '--replace', '--max-lines',
                        '-n4', '--max-args=4']:
            with self.subTest(options=options):
                self.assertDenied(f'xargs {options} git add -A')
                self.assertDenied(f'xargs {options} gh pr merge 17')
                self.assertDenied(f'xargs {options} git add docs/HANDOFF.md')  # input can append -A
                self.assertAllowed(f'xargs {options} git status --short')

    def test_merge_status_get_is_allowed_but_merge_put_is_denied(self):
        endpoint = 'repos/o/r/pulls/12/merge'
        for options in ['', '-X GET', '--method=GET', '-XGET', '--method HEAD']:
            with self.subTest(options=options):
                self.assertAllowed(f'gh api {options} {endpoint}')
        for options in ['-X PUT', '--method=PUT', '-XPUT']:
            with self.subTest(options=options):
                self.assertDenied(f'gh api {options} {endpoint}')
        self.assertDenied('gh api graphql -f query="mutation { mergePullRequest(input: {}) { clientMutationId } }"')

    def test_embedded_hashes_do_not_discard_api_arguments(self):
        for client, body_option in [('curl -q -X POST', '--json'),
                                    ('wget --no-config --method POST', '--body-data')]:
            self.assertDenied(client + ' https://api.github.com/repos/o/r/merges#note '
                              + body_option + ' \'{"base":"main","head":"feature"}\'')
        self.assertDenied('gh api repos/o/r/merges#note -f base=main -f head=feature')
        self.assertDenied('echo word#suffix; git add -A')
        self.assertAllowed('git status # git add -A')
        self.assertAllowed('echo "# this is text"')
        self.assertDenied('git status # harmless comment\ngit add -A')
        self.assertAllowed('git add "docs/a#b.md"')

    def test_operandless_cd_uses_the_child_home(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for prefix in [f'HOME={other}', f'env HOME={other}']:
                for connector in [';', '&&']:
                    with self.subTest(prefix=prefix, connector=connector):
                        self.assertDenied(f'{prefix} bash -c "cd {connector} git push origin"')
                        self.assertAllowed(f'{prefix} bash -c "cd {connector} git push origin HEAD:feature"')
            self.assertAllowed(f'HOME={self.repo} bash -c "cd && git push origin"', cwd=other)
            self.assertAllowed(f'HOME={other} bash -c "git status"; git push origin')

    def test_attached_gh_repository_flags_are_inherited(self):
        for option in ['-Ro/r', '--repo=o/r', '-R o/r']:
            with self.subTest(option=option):
                self.assertDenied(f'gh pr {option} merge 12')
                self.assertDenied(f'gh pr {option} review 12 --approve')
                self.assertDenied(f'gh agent-task {option} create "work"')
                self.assertAllowed(f'gh pr {option} view 12')
                self.assertAllowed(f'gh pr {option} review 12 --comment -b ok')

    def test_unquoted_backticks_are_checked(self):
        # These are inputs to the guard, never commands executed by the test.
        for command in ['echo `git add -A`', 'echo `gh pr merge 17`',
                        'printf %s `git push origin HEAD:main`']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('echo `git status --short`')
        self.assertAllowed('echo `git add docs/HANDOFF.md`')

    def test_env_directory_options_select_the_repository(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for option in [f'-C {other}', f'-C{other}', f'--chdir {other.name}',
                           f'--chdir={other.name}']:
                with self.subTest(option=option):
                    self.assertDenied(f'env {option} git push origin')
                    self.assertDenied(f"env {option} sh -c 'git push origin'")
                    self.assertAllowed(f'env {option} git push origin HEAD:claude/topic')
            self.assertAllowed(f'env -C {other} -C . git push origin')
            self.assertDenied(f'env -C . env -C {other.name} git push origin')
            self.assertAllowed(f'env -C {other} git status; git push origin')

    def test_branch_merge_urls_use_the_parsed_path(self):
        for suffix in ['#note', '?source=cli', '?source=cli#note']:
            endpoint = f'https://api.github.com/repos/o/r/merges{suffix}'
            with self.subTest(suffix=suffix):
                self.assertDenied(f'''curl -q -X POST '{endpoint}' --json '{{"base":"main","head":"feature"}}' ''')
                self.assertDenied(f"gh api '{endpoint}' -f base=main -f head=feature")
                self.assertAllowed(f'''curl -q '{endpoint}' --json '{{"base":"feature","head":"main"}}' ''')
        self.assertAllowed('''curl -q 'https://example.com/repos/o/r/merges#note' --json '{"base":"main"}' ''')

    def test_env_directory_does_not_move_outer_shell_substitutions(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for substitution in ['`git push origin`', '"$(git push origin)"']:
                with self.subTest(substitution=substitution, outer='main'):
                    self.assertDenied(f'env -C {self.repo} echo {substitution}', cwd=other)
                with self.subTest(substitution=substitution, outer='feature'):
                    self.assertAllowed(f'env -C {other} echo {substitution}')
            self.assertDenied(f'''env -C {other} sh -c 'echo "$(git push origin)"' ''')
            self.assertAllowed(f'''env -C {self.repo} sh -c 'echo "$(git push origin)"' ''', cwd=other)

    def test_double_quoted_child_scripts_expand_in_the_outer_shell(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for substitution in ['$(git push origin)', '`git push origin`']:
                with self.subTest(substitution=substitution, outer='main'):
                    self.assertDenied(f'env -C {self.repo} sh -c "echo {substitution}"', cwd=other)
                with self.subTest(substitution=substitution, outer='feature'):
                    self.assertAllowed(f'env -C {other} sh -c "echo {substitution}"')
            self.assertDenied(f'env -C {other} sh -c "echo $(git status); git push origin"')

    def test_escaped_substitutions_in_child_scripts_stay_checked(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for substitution in [r'\$(git push origin)', r'\`git push origin\`']:
                with self.subTest(substitution=substitution):
                    self.assertDenied(f'env -C {other} sh -c "echo {substitution}"')
                    safe = substitution.replace('git push origin', 'git push origin HEAD:feature')
                    self.assertAllowed(f'env -C {other} sh -c "echo {safe}"')

    def test_commit_all_tree_pathspecs_are_denied(self):
        for path in ['.', './', ':/', ':', '*', ':/*', './*', ':(top)',
                     ':(top)*', ':(glob)**', ':(top,glob)**']:
            with self.subTest(path=path):
                self.assertDenied(f"git commit '{path}' -m update")
                self.assertDenied(f"git commit -m update -- '{path}'")
        for command in ['git commit docs/HANDOFF.md -m update',
                        'git commit --message . docs/HANDOFF.md',
                        'git commit -m .', 'git commit -m. -- docs/HANDOFF.md']:
            self.assertAllowed(command)
        # The value of --file is a message file, not a pathspec. A folder is
        # no message, so the privacy check cannot read it and denies that.
        reason = guard_output('Bash', {'command': 'git commit --file . -- docs/HANDOFF.md'},
                              self.repo)['permissionDecisionReason']
        self.assertIn('must exist before the command runs', reason)

    def test_pathspec_files_require_explicit_paths(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            paths = Path(folder) / 'paths.txt'
            paths.write_text('.\n')
            for command in ['add', 'commit']:
                suffix = ' -m update' if command == 'commit' else ''
                for option in [f'--pathspec-from-file {paths}',
                               f'--pathspec-from-file={paths}', '--pathspec-from-file=-']:
                    with self.subTest(command=command, option=option):
                        self.assertDenied(f'git {command} {option}{suffix}')
                self.assertAllowed(f'git {command} docs/HANDOFF.md{suffix}')

    def test_repo_sync_checks_protected_and_force_destinations(self):
        for options in ['--branch main', '-bmain', '--branch=refs/heads/main',
                        '--branch master', '--branch feature --force',
                        '--branch feature --force=true', '']:
            with self.subTest(options=options):
                self.assertDenied(f'gh repo sync o/r --source upstream/r {options}')
        self.assertAllowed('gh repo sync o/r --source upstream/r --branch feature')
        self.assertAllowed('gh repo sync o/r -b feature --force=false')
        self.assertAllowed('gh repo view o/r')

    def test_copilot_agent_task_creation_is_denied(self):
        for name in ['agent-task', 'agent-tasks', 'agent', 'agents']:
            with self.subTest(name=name):
                self.assertDenied(f'gh {name} create "Fix the bug"')
                self.assertDenied(f'gh --repo o/r {name} create --from-file task.md')
                self.assertAllowed(f'gh {name} list')
                self.assertAllowed(f'gh {name} view 17')

    def test_gh_copilot_is_denied(self):
        # gh copilot runs the Copilot CLI agent, which can push by itself.
        for command in ['gh copilot -p "Push the current branch"',
                        "gh copilot -- -p 'git push origin HEAD' --allow-all-tools",
                        'gh -R o/r copilot']:
            with self.subTest(command=command):
                self.assertDenied(command)

    def test_gh_options_before_a_command_s_name_are_denied(self):
        # Cobra finds a command's names past options written among them (gh
        # pr --squash=true merge 5 merges), and the guard reads the names.
        for command in ['gh pr --squash=true merge 5',
                        'gh --method=PUT api repos/o/r/pulls/5/merge',
                        'gh agent-task --follow=true create "Fix the build"',
                        'gh pr --body=ok review 5 --approve',
                        'gh repo --push=true create o/r --source=. --public',
                        'gh --push=1 repo create o/r --source=. --public',
                        'gh repo --source=. create o/r --public --push',
                        'gh release --clobber=true upload v1 notes.txt',
                        'gh --x=y copilot']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ['gh -R o/r pr view 5', 'gh --repo o/r pr list',
                        'gh pr -R o/r view 5', 'gh --repo=o/r pr checks 5',
                        'gh -Ro/r pr diff 5', 'gh pr view 5 -R o/r',
                        'gh pr --help', 'gh --help', 'gh --version', 'gh -h pr',
                        'gh api --method GET repos/o/r/pulls/5', 'gh status --org o',
                        'gh repo deploy-key list -R o/r', 'gh']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_gh_repo_create_pushes_by_no_other_spelling(self):
        # -R, --repo and --hostname after the names are an option's value
        # when the option before them takes one: -d -R --push describes the
        # repository as -R and pushes.
        for command in ['gh repo create o/r --source=. --public -d -R --push',
                        'gh repo create o/r --source=. --public --description --repo --push',
                        'gh repo create o/r --source=. --public -d -Rx --push',
                        'gh repo create o/r --source=. --public --homepage --hostname --push',
                        # The shell builds these words: the guard cannot read them.
                        'F=--push; gh repo create o/r --source=. --public $F',
                        'gh repo create o/r --source=. --public $(echo --push)',
                        'gh repo create o/r --source=. --public "$(printf -- --push)"',
                        'set -- --push; gh repo create o/r --source=. --public "$@"',
                        'gh repo create o/r --source=. --public --{push,public}',
                        'gh repo create o/r --source=. --public --pus[h]',
                        'gh repo create o/r --source=. --public --pus?',
                        'gh repo create o/r --source=. --public --p*',
                        # With no words, gh asks its questions, and one of
                        # them pushes, where a terminal can answer.
                        'gh repo create', 'gh repo new', 'gh repo create --',
                        'gh repo create < /dev/null']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ['gh repo create o/r --source=. --public',
                        "gh repo create o/r --public --description 'Tools {beta} [1]?'",
                        'gh repo create o/r --private -d --push-notes',
                        'gh repo create o/r --public -R o/other']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_gh_runs_only_without_a_terminal(self):
        # Given a terminal, gh asks for what it is not given and reads the
        # answers (from stdin, an editor or a recovery file), which the
        # guard does not: gh pr create with no --head asks where to push the
        # branch, and pushes it; gh issue create with no --body asks for one.
        # So does every command script or unbuffer runs, through a shell
        # or another runner too, but not a substitution in their words,
        # which the shell runs first.
        for command in ["script -qec 'gh pr create --title t --body b' /dev/null",
                        'script -q /dev/null gh pr create --title t --body b',
                        "printf '\\n\\n' | script -qec 'gh pr new -t t -b b' /dev/null",
                        'unbuffer gh pr create --title t --body b',
                        'unbuffer -p gh pr merge 5',
                        "script -qec 'gh pr create --title t --body b --head claude/topic' "
                        '/dev/null',
                        "script -qec 'gh issue create --title t' /dev/null < answers.txt",
                        "script -qec 'gh pr comment 5 --editor' /dev/null",
                        "script -qec 'gh pr view 5' /dev/null",
                        "unbuffer bash -c 'gh pr create --title t --body b'",
                        "unbuffer sh -c 'gh issue comment 5'",
                        "unbuffer env GH_REPO=o/r timeout 60 gh issue create --title t",
                        "unbuffer bash -c 'gh pr view 5 && gh issue create --title t'",
                        'unbuffer flock /tmp/gh.lock gh issue create --title t']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ['gh pr create --title t --body b',
                        'gh issue create --title t --body b',
                        "script -qec 'git status' /dev/null",
                        'unbuffer git status',
                        "bash -c 'gh pr view 5 && gh issue create --title t'",
                        'flock /tmp/gh.lock gh issue create --title t',
                        'unbuffer echo "$(gh pr view 5 --json title)"']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_gh_text_from_an_editor_is_denied(self):
        # gh pr comment and gh issue comment run the editor with --editor,
        # and gh gist edit with no file to put in, even without a terminal,
        # and send what it writes, which the guard cannot read first.
        (self.repo / 'notes.md').write_text('Build notes\n')
        self.addCleanup((self.repo / 'notes.md').unlink)
        for command in ['GH_EDITOR=./editor.sh gh pr comment 12 --editor --repo o/r',
                        'gh pr comment 12 -e', 'gh pr comment 12 --edit-last -e',
                        'gh pr comment 12 --editor=true', 'gh pr comment 12 -we',
                        'gh issue comment 5 --editor', 'gh issue comment 5 -e=1',
                        'gh pr create --editor --head x', 'gh issue create -e',
                        'gh pr new -e', 'gh gist edit abc123', 'gh gist edit abc123 -f notes.md',
                        'gh gist edit abc123 --desc Notes', 'gh gist edit abc123 -r=']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ['gh pr comment 12 --body ok', 'gh pr comment 12 -b -e',
                        'gh pr comment 12 --body -e', 'gh pr comment 12 --editor=false --body ok',
                        'gh pr comment 12 -e=false -b ok', 'gh issue create -t T -b B',
                        'gh pr create --title t --body b --head x --repo o/r',
                        'gh gist edit abc123 --filename notes.md notes.md',
                        'gh gist edit abc123 notes.md', 'gh gist edit abc123 --add notes.md',
                        'gh gist edit abc123 -r old.md', 'gh gist edit abc123 -r old.md -d Notes',
                        'gh pr edit 12 --body ok', 'gh gist view abc123']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_gh_recovery_files_are_denied(self):
        # gh pr create and gh issue create take a title and a body from a
        # recovery file (--recover), which the guard does not read.
        for command in ['gh issue create --recover state.json',
                        'gh issue new --recover=state.json',
                        'gh pr create --head claude/topic --recover state.json',
                        'gh pr create -t t --recover state.json -b b',
                        'gh -R o/r issue create --recover state.json']:
            with self.subTest(command=command):
                self.assertDenied(command)
        # A value that only looks like the option is a title, as gh reads it.
        for command in ['gh issue create -t --recover -b b',
                        'gh pr create --head claude/topic --title --recover --body b',
                        'gh issue create --title t --body b']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_gh_autofill_from_commits_is_denied(self):
        # gh pr create --fill writes the title and body from the branch's
        # commits, which with --head need not have been pushed, so the
        # privacy hook has not read them, and the guard reads no text gh
        # makes itself.
        for command in ['gh pr create --head claude/topic --fill',
                        'gh pr create --head claude/topic -f', 'gh pr create --fill-first',
                        'gh pr create --head claude/topic --fill-verbose', 'gh pr create -df',
                        'gh pr create --fill=true --head claude/topic', 'gh pr new --fill',
                        'gh -R o/r pr create --base main --fill --head claude/topic',
                        'gh pr create --title t --fill --head claude/topic',
                        'gh pr create --title t --body b --fill-first --head claude/topic']:
            with self.subTest(command=command):
                self.assertDenied(command)
        # A value that only looks like the option, and autofill turned off.
        for command in ['gh pr create --head claude/topic --title --fill --body b',
                        'gh pr create --head claude/topic -t -f -b b',
                        'gh pr create --head claude/topic --fill=false --title t --body b',
                        'gh pr create --head claude/topic --title t --body b']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_each_refusal_keeps_its_own_words(self):
        # Two messages once shared a name, so a Git shell alias was refused
        # with the words for a shell alias the command defines.
        tree = ast.parse(GUARD.read_text())
        names = [target.id for node in tree.body if isinstance(node, ast.Assign)
                 for target in node.targets if isinstance(target, ast.Name)]
        names += [node.name for node in tree.body
                  if isinstance(node, (ast.FunctionDef, ast.ClassDef))]
        self.assertEqual(sorted({name for name in names if names.count(name) > 1}), [])
        reason = guard_output('Bash', {'command': "git -c alias.ship='!git push origin main' "
                                       'ship'}, self.repo)['permissionDecisionReason']
        self.assertIn('Git shell aliases', reason)
        reason = guard_output('Bash', {'command': "alias ship='git push origin main'"},
                              self.repo)['permissionDecisionReason']
        self.assertIn('defining a shell alias', reason)

    def test_gh_runs_only_its_own_commands_and_aliases_known_before_the_call(self):
        # gh alias list reads aliases as they are before the call: one the
        # call sets, imports, deletes or writes into gh's configuration, and
        # an extension, are not read.
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            (Path(folder) / 'config.yml').write_text('aliases:\n  inspect: pr view\n')
            with patch.dict(os.environ, GH_CONFIG_DIR=folder):
                for command in [
                        "gh alias set mk 'repo create' && gh mk o/r --source=. --public --push",
                        "gh alias set mk 'repo create' --clobber; gh mk o/r --public",
                        'gh alias import aliases.yml && gh mk o/r --public',
                        "gh alias set inspect 'pr merge' --clobber; gh inspect 12",
                        'gh alias delete inspect; gh inspect 12',
                        "printf 'aliases:\\n  inspect: pr merge\\n' > "
                        f"{folder}/config.yml; gh inspect 12",
                        "python3 -c 'print(1)' > /dev/null; cp new.yml "
                        f"{folder}/config.yml && gh inspect 12",
                        'gh dash', 'gh some-extension --push',
                        'gh extension exec dash', 'gh ext exec dash --push',
                        'gh extensions exec dash', 'gh -R o/r ext exec dash']:
                    with self.subTest(command=command):
                        self.assertDenied(command)
                for command in ['gh inspect 12', 'gh alias list',
                                "gh alias set mk 'pr view'", 'gh status', 'gh environment',
                                'gh cs list', 'gh ext list', 'gh at verify x -R o/r',
                                'gh extension list', 'gh ext upgrade --all',
                                f'echo notes > {self.repo}/notes.txt; gh inspect 12',
                                'gh inspect 12; gh alias set mk "pr view"']:
                    with self.subTest(command=command):
                        self.assertAllowed(command)

    def test_shell_aliases_are_not_defined(self):
        # The shell expands an alias defined on an earlier line, and the
        # guard does not read an alias's text.
        for command in ["shopt -s expand_aliases\nalias g='gh repo create o/r --source=. --public "
                        "--push'\ng",
                        "shopt -s expand_aliases\nalias g='git push --no-verify origin "
                        "claude/topic'\ng",
                        "alias g='git add -A'; g", 'builtin alias g="git add -A"',
                        "alias -p g='git add -A'", "eval \"alias g='git add -A'\""]:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ['alias', 'alias g', 'alias -p', 'unalias g']:
            with self.subTest(command=command):
                self.assertAllowed(command)

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

    def test_programs_that_run_a_command_do_not_hide_it(self):
        # Each runs the git command it is given, as env and timeout do.
        for runner in ['stdbuf -o0', 'stdbuf --output=L -e 0', 'setsid', 'setsid -w',
                       'ionice -c3', 'ionice -c 2 -n 7', 'chrt 10', 'chrt -f 10',
                       'taskset 0x1', 'taskset -c 0,1', 'caffeinate -i', 'caffeinate -t 60 -s',
                       'arch -arm64', 'flock /tmp/brickson.lock', 'flock -w 5 /tmp/brickson.lock',
                       'watch', 'watch -n1', 'watch -x', 'find . -maxdepth 0 -exec',
                       'find . -maxdepth 0 -execdir', 'find . -ok']:
            with self.subTest(runner=runner):
                self.assertDenied(f'{runner} git add -A')
                self.assertDenied(f'{runner} git push --force origin claude/topic')
                self.assertAllowed(f'{runner} git add docs/HANDOFF.md')
        for command in ["flock /tmp/brickson.lock -c 'git add -A'",
                        "flock /tmp/brickson.lock --command 'git push origin main'",
                        "find . -maxdepth 0 -exec git add -A ';'",
                        'find . -maxdepth 0 -exec git push origin main {} +',
                        'find . -name x -print -exec git add -A \\;']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed("find . -name '*.py' -exec grep -l x {} +")
        self.assertAllowed('caffeinate -i scripts/test.sh')
        self.assertAllowed("flock /tmp/brickson.lock -c 'git status'")

    def test_runner_options_are_read_as_their_programs_read_them(self):
        # Short options cluster and long ones may be abbreviated (getopt),
        # find's ( ) and a test's operand do not hide an -exec, chrt's
        # priority is optional, and xcrun, script, setpriv, prlimit,
        # unshare and doas run the command they are given.
        for runner in ['flock -nw 1 ./lk', 'flock --wait 1 ./lk', 'flock -nE 3 ./lk',
                       'flock -w1 ./lk', 'flock --timeout=1 ./lk', 'watch -tn 1',
                       'watch -tn1', 'watch -n 1 -d', 'chrt -o', 'chrt --idle', 'chrt -o 0',
                       'xcrun', 'xcrun --sdk iphoneos', 'setpriv', 'setpriv --reuid 0',
                       'prlimit --nofile=256', 'prlimit -p 1', 'unshare', 'unshare -w .',
                       'doas', 'doas -u root', 'script -q /dev/null', 'script -qt 0 /dev/null']:
            with self.subTest(runner=runner):
                self.assertDenied(f'{runner} git push origin main')
                self.assertDenied(f'{runner} git add -A')
                self.assertAllowed(f'{runner} git add docs/HANDOFF.md')
        for command in ['flock --time 1 ./lk git push origin main',
                        'watch --int 1 git push origin main',
                        'watch -Q 1 git push origin main',
                        "script -qc 'git push origin main' /dev/null",
                        "script --command 'git push origin main' /dev/null",
                        'find . -maxdepth 0 \\( -exec git push origin main \\; \\)',
                        "find . -maxdepth 0 '(' -exec git push origin main ';' ')'",
                        'find . -maxdepth 0 \\( -exec gh pr merge 1 \\; \\)',
                        'find . -maxdepth 0 \\! \\( -name x \\) -exec git push origin main \\;',
                        'find . -maxdepth 0 -name -exec -o -exec git push origin main \\;',
                        'find . -maxdepth 0 -execdir git push origin main \\;']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in ["find . \\( -name '*.md' -o -name '*.txt' \\) -print",
                        "find . -name '*.md' -exec grep -l x {} \\;",
                        "script -qc 'git status' /dev/null", 'watch -n 1 git status']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_wrapper_s_option_is_read_as_its_program_reads_it(self):
        # getopt_long takes a unique beginning of a long option as the
        # whole option, value included; bash's exec -a and sudo -r take
        # a value; and bash reads NAME+=value as an assignment.
        for wrapper in ['setpriv --pdeath SIGKILL', 'unshare --w .', 'env --unse X',
                        'timeout --sig TERM 5', 'exec -a name', 'sudo -r role', 'A+=1',
                        'PATH+=:/x env']:
            with self.subTest(wrapper=wrapper):
                self.assertDenied(f'{wrapper} git push origin HEAD:main')
                self.assertDenied(f'{wrapper} gh pr merge 1')
                self.assertAllowed(f'{wrapper} git add docs/HANDOFF.md')

    def test_script_s_timing_option_is_read_both_ways(self):
        # util-linux's script -t takes only an attached value, so a -c
        # after it gives the command; macOS's takes the next word.
        for command in ["script -q -t -c 'git push origin HEAD:main' /dev/null",
                        "script -qt -c 'git push origin HEAD:main' /dev/null",
                        'script -q -t 0 /dev/null git push origin HEAD:main']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed("script -q -t -c 'git status' /dev/null")
        self.assertAllowed('script -q -t 0 /dev/null git status')

    def test_files_find_gives_a_shell_script_are_its_arguments(self):
        # find's file names after a literal sh -c script are its $1, $2,
        # as with any words there; only a {} in the script makes code of
        # them. Git commands that only read take them too.
        for command in ["find . -name '*.png' -exec sh -c 'echo \"$1\"' _ {} \\;",
                        "find . -name '*.swift' -exec sh -c 'grep -c func \"$1\"' sh {} \\;",
                        "find . -name '*.md' -exec sh -c 'for f; do wc -l \"$f\"; done' sh {} +",
                        "find . -maxdepth 1 -type d -exec sh -c 'cd \"$1\" && git status' _ {} \\;",
                        "find . -name '*.md' -exec git blame {} \\;",
                        "find . -name '*.md' -exec git check-ignore -v {} +"]:
            with self.subTest(command=command):
                self.assertAllowed(command)
        for command in ["find . -exec sh -c 'cat {}' \\;",
                        "find . -exec sh -c 'git push origin \"$1\"' _ {} \\;",
                        "find . -exec sh -c 'git add -A' _ {} \\;",
                        'find . -name x -exec bash {} \\;',
                        "find . -name x -exec git grep -O{} x \\;"]:
            with self.subTest(command=command):
                self.assertDenied(command)

    def test_files_find_passes_to_a_command_are_named_as_unknown(self):
        # find fills {} in when it runs, as xargs adds its input.
        for command in ["find docs -name '*.md' -exec git add {} +",
                        "find docs -name '*.md' -exec git add -- {} \\;"]:
            with self.subTest(command=command):
                reason = guard_output('Bash', {'command': command}, self.repo)
                self.assertEqual(reason['permissionDecision'], 'deny')
                self.assertIn('find -exec', reason['permissionDecisionReason'])
        self.assertAllowed("find docs -name '*.md' -exec git log -1 -- {} \\;")

    def test_a_cd_s_redirections_are_not_its_folder(self):
        # cd sub 2>/dev/null and pushd sub >/dev/null still go to sub.
        (self.repo / 'sub').mkdir(exist_ok=True)
        for command in ['cd sub 2>/dev/null && git push origin feature',
                        'cd sub >/dev/null && git push origin feature',
                        'cd sub &>/dev/null && git push origin feature',
                        'cd sub 2>&1 && git push origin feature',
                        'pushd sub >/dev/null && git push origin feature; popd >/dev/null',
                        'pushd sub > /dev/null && git push origin feature && popd > /dev/null']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.assertDenied('cd sub 2>/dev/null && git push origin main')

    def test_an_escaped_github_host_is_read_as_curl_sends_it(self):
        # curl decodes %-escapes in the host, and drops nothing else.
        # With IDN support it maps fullwidth, squared and subscript letters
        # and other full stops to the ASCII host (UTS #46).
        for host in ['api%2egithub.com', '%61pi.github.com', 'API.GitHub.com.',
                     'ＡＰＩ.github.com', 'api.github.com。',
                     'api．github.com', '\U0001F130pi.github.com', 'ₐpi.github.com']:
            with self.subTest(host=host):
                self.assertDenied(f'curl -q -X PUT https://{host}/repos/o/r/pulls/12/merge')
                self.assertDenied(f'curl -X GET https://{host}/repos/o/r/pulls')
        self.assertDenied('curl -q -X POST "https://uploads%2egithub.com/repos/o/r/releases/1/'
                          'assets?name=a.txt" --data-binary @README.md')
        self.assertAllowed('curl -q https://api.github.com/repos/o/r/pulls')

    def test_push_queries_use_the_selected_repository(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
            for selector in [f'--git-dir={other}/.git', f'--git-dir {other}/.git',
                             f'--git-dir={other.name}/.git --work-tree={other.name}',
                             f'-C {other.name}', f'-C{other.name}']:
                with self.subTest(selector=selector):
                    self.assertDenied(f'git {selector} push')

    def test_git_environment_selects_the_repository_for_push_checks(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            init_repository(str(other), 'main')
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
                init_repository(folder, 'claude/other')
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
            for command in [f'curl -q {endpoint} --data @{payload}',
                            f'curl -q {endpoint} --data-binary=@{payload}',
                            f'curl -q {endpoint} --json @{payload}',
                            f'wget --no-config {endpoint} --post-file={payload}']:
                with self.subTest(command=command):
                    self.assertDenied(command)
            payload.write_text('{"event":"COMMENT","body":"Looks good"}')
            self.assertAllowed(f'curl -q {endpoint} --data @{payload}')
            # A non-GitHub endpoint must not cause the guard to open files.
            self.assertAllowed('curl -q https://example.com --data @missing.json')

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
                                f'curl -q -X {method} https://api.github.com/{endpoint} --json @{payload}']:
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
                            f'curl -q -X POST https://api.github.com/{endpoint} --json @{payload}']:
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
                        'curl -q -X PUT https://api.github.com/repos/o/r/pulls/12/merge',
                        'curl -q -X PUT api.github.com/repos/o/r/pulls/12/merge']:
            self.assertDenied(command)

    def test_requesting_copilot_through_the_api_is_denied(self):
        for command in [
                "gh api --method POST repos/o/r/pulls/12/requested_reviewers "
                "-f 'reviewers[]=copilot-pull-request-reviewer[bot]'",
                'curl -q -X POST https://api.github.com/repos/o/r/pulls/12/requested_reviewers '
                '-d \'{"reviewers":["copilot-pull-request-reviewer[bot]"]}\'']:
            self.assertDenied(command)
        self.assertAllowed("gh api --method POST repos/o/r/pulls/12/requested_reviewers "
                           "-f 'reviewers[]=MiddleAgedBanana'")

    def test_reading_pull_requests_is_allowed(self):
        for command in ['gh pr view 12', 'gh pr checks 12', 'gh pr create --title t --body b',
                        'gh api repos/o/r/pulls/12', 'gh pr review 12 --comment -b ok',
                        'git merge origin/main', 'git log --merges',
                        'curl -q https://example.com/api.github.com/pulls/1/merge',
                        'curl -q https://api.github.com.example.com/repos/o/r/pulls/1/merge']:
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

    # Copilot is not part of the review process (owner, 2026-11-04: the
    # credits ran out and the subscription ends on 2026-11-09; AGENTS.md,
    # "Reviews and updates on GitHub"), so no door to its review is open:
    # its own tool, from any server, a pull request's reviewer field, gh or
    # the API. Letting any of them through fails this test.
    def test_no_agent_requests_copilots_review(self):
        review = {'owner': 'o', 'repo': 'r', 'pullNumber': 12}
        for name in ('mcp__github__request_copilot_review',
                     'mcp__plugin_github_github__request_copilot_review',
                     'mcp__other__request_copilot_review'):
            with self.subTest(name=name):
                self.assertEqual(decision(name, review, self.repo), 'deny')
        self.assertEqual(decision('mcp__github__update_pull_request',
                                  {'reviewers': ['copilot-pull-request-reviewer[bot]']}, self.repo), 'deny')
        self.assertDenied('gh pr edit 12 --add-reviewer @copilot')
        self.assertDenied("gh api -X POST repos/o/r/pulls/12/requested_reviewers"
                          " -f 'reviewers[]=copilot-pull-request-reviewer[bot]'")

    def test_a_new_pull_request_cannot_ask_for_copilot(self):
        # The reviewer field of create_pull_request is another door to a
        # Copilot review; it is refused like update_pull_request's.
        name = 'mcp__github__create_pull_request'
        for reviewers in (['copilot-pull-request-reviewer[bot]'], ['human', 'Copilot'], 'copilot'):
            with self.subTest(reviewers=reviewers):
                self.assertEqual(decision(name, {'owner': 'o', 'repo': 'r', 'head': 'claude/x',
                                                 'base': 'main', 'title': 't',
                                                 'reviewers': reviewers}, self.repo), 'deny')
        for arguments in ({'title': 't', 'reviewers': ['human']}, {'title': 't'},
                          {'title': 't', 'reviewers': 5}):
            with self.subTest(arguments=arguments):
                self.assertIsNone(decision(name, arguments, self.repo))

    def test_unreadable_input_decides_nothing(self):
        result = subprocess.run([sys.executable, str(GUARD)], input='not json',
                                capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout), (0, ''))


# Made-up details: a name standing in for the private list, and an
# address, a number and a home folder put together from parts, so this
# file holds none of its own (scripts/test-privacy.py).
PRIVATE_NAME = 'Quillon Vassmere'
PRIVATE_ADDRESS = 'quill.vass' + '@' + 'gmail' + '.com'
PRIVATE_PHONE = '(212) ' + '867-' + '0142'
PRIVATE_HOME = '/Us' + 'ers/' + 'qvassmere'


class PrivacyGuardTests(unittest.TestCase):
    """Publishing a personal detail is denied: in a commit's message and
    changes, and in text sent to GitHub by gh, the API or a GitHub tool. A
    push must run the privacy hook, which reads what the push carries.
    Dropping any of these paths, or naming what was found in the denial,
    fails here (docs/DECISIONS.md, "Personal details stay out of the
    repository")."""

    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.repo = self.folder / 'repo'
        self.remote = self.folder / 'remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(self.remote)],
                       check=True)
        self.repo.mkdir()
        init_repository(self.repo, 'main')
        self.git('commit', '-q', '--allow-empty', '-m', 'start')
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('push', '-q', 'origin', 'main')
        self.git('checkout', '-q', '-b', 'claude/topic')
        self.env = self.environment()

    def environment(self):
        # The list comes only from here: no file on this machine is read.
        return guard_environment(XDG_CONFIG_HOME=str(self.folder / 'config'),
                                 BRICKSON_PRIVATE_WORDS=PRIVATE_NAME + '\n')

    def git(self, *args):
        subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=t',
                        '-c', 'user.email=t@example.com', '-c', 'commit.gpgsign=false',
                        '-c', 'core.hooksPath=/dev/null', *args],
                       check=True, capture_output=True)

    def git_output(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], check=True,
                              capture_output=True, text=True).stdout.strip()

    def output(self, command):
        return guard_output('Bash', {'command': command}, self.repo, self.env)

    def assertDenied(self, command):
        output = self.output(command)
        self.assertEqual(output and output['permissionDecision'], 'deny', command)
        reason = output['permissionDecisionReason']
        for secret in ('Quillon', 'quillon', 'Vassmere', 'quill.vass', '867', 'qvassmere'):
            self.assertNotIn(secret, reason, 'the denial must not repeat what it found')
        return reason

    def assertAllowed(self, command):
        self.assertIsNone(self.output(command), command)

    def tool(self, name, arguments):
        return decision(name, arguments, self.repo, self.env)

    def test_a_commit_message_with_a_detail_is_denied(self):
        for message in [f'Thanks {PRIVATE_NAME}', f'Write to {PRIVATE_ADDRESS}',
                        f'Call {PRIVATE_PHONE}', f'Measured in {PRIVATE_HOME}/code']:
            with self.subTest(message=message):
                reason = self.assertDenied(f'git commit -m {shlex.quote(message)}')
                self.assertIn('the commit message:1:', reason)
        # A here-document's body is the message: line 3 is its third line.
        heredoc = ('git commit -m "$(cat <<\'EOF\'\nFix the layout.\n\n'
                   f'For {PRIVATE_NAME.lower()}.\nEOF\n)"')
        self.assertIn('the commit message:3:', self.assertDenied(heredoc))
        self.assertAllowed('git commit -m "Fix the layout"')
        self.assertAllowed('git commit -m "$(cat <<\'EOF\'\nCosts $5 and `x`.\nEOF\n)"')

    def test_a_message_the_shell_would_build_is_denied(self):
        # What a variable or a command holds cannot be read before it runs.
        for command in ['git commit -m "$MESSAGE"', 'git commit -m "Fix $(cat notes.md)"',
                        'git commit -m "Fix `cat notes.md`"', 'git commit --message="${M}"',
                        'gh pr create --title t --body "$BODY"', 'gh pr comment 1 -b"$X"',
                        'gh api -X POST repos/o/r/issues/1/comments -f body="$X"']:
            with self.subTest(command=command):
                self.assertIn('variable or another command', self.assertDenied(command))
        # Single quotes keep a $ as text, as in a GraphQL query's variables.
        self.assertAllowed("git commit -m 'Explain $PWD'")
        self.assertAllowed("gh api graphql -f query='query($id: ID!) { node(id: $id) { id } }'")

    def test_a_message_or_author_taken_from_another_commit_is_read(self):
        # -C, -c, --fixup, --squash and --amend take a message (and -C, -c
        # and --amend an author) from a commit that exists already.
        self.git('commit', '-q', '--allow-empty', '-m', f'Thanks {PRIVATE_NAME}')
        private = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'Clean',
                 f'--author={PRIVATE_NAME} <someone@example.com>')
        authored = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'Also clean')
        clean = self.git_output('rev-parse', 'HEAD')
        for command in [f'git commit --allow-empty -C {private}',
                        f'git commit --allow-empty -c {private}',
                        f'git commit --allow-empty --reuse-message={private}',
                        f'git commit --allow-empty --reedit-message {private}',
                        f'git commit --allow-empty --fixup {private}',
                        f'git commit --allow-empty --fixup=amend:{private}',
                        f'git commit --allow-empty --fixup=reword:{private}',
                        f'git commit --allow-empty --squash={private}',
                        f'git commit --allow-empty -sC {private}',
                        f'git commit --allow-empty -C {authored}',
                        'git commit --allow-empty -C "$SHA"',
                        'git commit --allow-empty -C no-such-commit']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed(f'git commit --allow-empty -C {clean}')
        self.assertAllowed(f'git commit --allow-empty --fixup {clean}')
        self.assertAllowed(f'git commit --allow-empty --fixup {authored}')
        self.assertAllowed(f'git commit --allow-empty --reset-author -C {authored}')
        # --amend keeps the last commit's message unless it is given one,
        # and its author unless --reset-author.
        self.git('reset', '-q', '--hard', private)
        self.assertDenied('git commit --amend --allow-empty --no-edit')
        self.assertAllowed('git commit --amend --allow-empty -m "Fix the message"')
        self.git('reset', '-q', '--hard', authored)
        self.assertDenied('git commit --amend --allow-empty -m "Fix"')
        self.assertAllowed('git commit --amend --allow-empty --reset-author -m "Fix"')

    def test_an_author_given_as_a_pattern_is_refused(self):
        # --author that is not Name <address> names the author of the
        # latest commit it matches (git commit --help), and which commit
        # that is depends on the locale, the log encoding and .mailmap: the
        # guard cannot tell, so it asks for the whole identity.
        self.git('commit', '-q', '--allow-empty', '-m', 'Clean',
                 f'--author={PRIVATE_NAME} <someone@example.com>')
        self.git('commit', '-q', '--allow-empty', '-m', 'Also clean',
                 '--author=Clean Person <clean@example.com>')
        for command in ['git commit --allow-empty -m Fix --author=Quill',
                        'git commit --allow-empty -m Fix --author quill',
                        'git commit --allow-empty -m Fix --author=someone@example',
                        'git commit --allow-empty -m Fix --author=no-such-author-here',
                        'git commit --allow-empty -m Fix --author=Clean',
                        'git commit --allow-empty --author=t -m x',
                        "git commit --allow-empty -m Fix --author='V..ssmere'"]:
            with self.subTest(command=command):
                self.assertIn('Name <address>', self.assertDenied(command))
        self.assertAllowed('git commit --allow-empty -m Fix --author="Clean Person <clean@example.com>"')

    def test_a_reused_author_or_message_is_read_as_git_takes_it(self):
        # The last of --reset-author and --no-reset-author wins, an option's
        # value is not an option, --author replaces a reused author, --squash
        # keeps the amended message, --fixup takes nothing from it, and the
        # reading never depends on the command's own log encoding.
        self.git('commit', '-q', '--allow-empty', '-m', 'Clean',
                 f'--author={PRIVATE_NAME} <someone@example.com>')
        authored = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'Also clean')
        clean = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'Café menu')
        cafe = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', f'Thanks {PRIVATE_NAME}')
        private = self.git_output('rev-parse', 'HEAD')
        given = '--author="Clean Name <clean@example.com>"'
        for command in [f'git commit --allow-empty --reset-author --no-reset-author -C {authored}',
                        f'git commit --allow-empty --reset-author --no-reset-a -C {authored}',
                        f'git -c i18n.logOutputEncoding=UTF-16LE commit --allow-empty -C {private}',
                        f'git -c i18n.logOutputEncoding=UTF-16LE commit --allow-empty -C {authored}',
                        'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=i18n.logOutputEncoding '
                        f'GIT_CONFIG_VALUE_0=UTF-16LE git commit --allow-empty -C {private}',
                        f'git commit --amend --allow-empty --squash={clean} --no-edit']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in [f'git commit --allow-empty -C {authored} {given}',
                        f'git commit --amend --allow-empty --fixup={clean}',
                        f'git -c i18n.logOutputEncoding=ISO-8859-1 commit --allow-empty -C {cafe}',
                        f'git commit --allow-empty --no-reset-author --reset-author -C {authored}']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.git('reset', '-q', '--hard', authored)
        for command in ['git commit --amend --allow-empty --reset-author --no-reset-author -m Fix',
                        'git commit --amend --allow-empty -m --reset-author']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed(f'git commit --amend --allow-empty --no-edit {given}')
        self.assertAllowed(f'git commit --amend --allow-empty -m Fix {given}')

    def test_a_name_git_keeps_in_another_encoding_is_read(self):
        # git commit turns bytes that are not UTF-8 into UTF-8, reading them
        # as Latin-1, so a name kept as Latin-1 bytes (in a commit git
        # hash-object or an import made, or in a configured name) is
        # published in the new commit.
        accented = PRIVATE_NAME.replace('a', 'á', 1).encode('latin-1')
        tree = self.git_output('rev-parse', 'HEAD^{tree}')

        def raw_commit(name, message):
            ident = name + b' <t@example.com> 1700000000 +0000\n'
            body = (f'tree {tree}\n'.encode() + b'author ' + ident + b'committer ' + ident
                    + b'\n' + message + b'\n')
            return subprocess.run(['git', '-C', str(self.repo), 'hash-object', '-t', 'commit',
                                   '-w', '--stdin'], input=body, check=True,
                                  capture_output=True).stdout.decode().strip()

        message = raw_commit(b'T', b'Thanks ' + accented)
        author = raw_commit(accented, b'Tidy')
        clean = raw_commit(b'T', b'Caf\xe9 menu')
        for command in [f'git commit --allow-empty -C {message}',
                        f'git commit --allow-empty -c {message}',
                        f'git commit --allow-empty -C {author}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed(f'git commit --allow-empty -C {clean}')
        subprocess.run([b'git', b'-C', bytes(self.repo), b'config', b'user.name', accented],
                       check=True, capture_output=True)
        self.git('config', 'user.email', 't@example.com')
        self.assertIn('the commit author', self.assertDenied('git commit --allow-empty -m Fix'))

    def test_a_reused_commit_is_read_as_git_stores_it(self):
        # git commit takes a reused commit's message and author converted
        # to its own i18n.commitEncoding, so where that is the encoding
        # the commit names, it copies the bytes as they are: UTF-8 typed
        # under a Latin-1 label, or plain text under a label that
        # misdescribes it, which git log shows converted into something
        # else.
        accented = PRIVATE_NAME.replace('a', 'á', 1)
        self.git('-c', 'i18n.commitEncoding=ISO-8859-1', 'commit', '-q', '--allow-empty',
                 '-m', f'Thanks {accented}')
        message = self.git_output('rev-parse', 'HEAD')
        self.git('-c', 'i18n.commitEncoding=ISO-8859-1', 'commit', '-q', '--allow-empty',
                 '-m', 'Tidy', f'--author={accented} <q@example.com>')
        author = self.git_output('rev-parse', 'HEAD')
        self.git('reset', '-q', '--hard', 'HEAD~2')
        tree = self.git_output('rev-parse', 'HEAD^{tree}')
        ident = f'{PRIVATE_NAME} <t@example.com> 1700000000 +0000\n'
        misdescribed = subprocess.run(
            ['git', '-C', str(self.repo), 'hash-object', '--literally', '-t', 'commit', '-w',
             '--stdin'], input=(f'tree {tree}\nauthor {ident}committer {ident}'
                                f'encoding UTF-16\n\nThanks {PRIVATE_NAME}\n').encode(),
            check=True, capture_output=True).stdout.decode().strip()
        latin = '-c i18n.commitEncoding=ISO-8859-1'
        for command in [f'git {latin} commit --allow-empty -C {message}',
                        f'git {latin} commit --allow-empty --fixup={message}',
                        f'git {latin} commit --allow-empty -C {author}',
                        f'git -c i18n.commitEncoding=UTF-16 commit --allow-empty -C {misdescribed}']:
            with self.subTest(command=command):
                self.assertIn('the reused commit message' if author not in command
                              else 'the commit author', self.assertDenied(command))
        self.git('config', 'i18n.commitEncoding', 'ISO-8859-1')
        self.assertDenied(f'git commit --allow-empty -C {message}')

    def test_a_signed_commit_is_reused_whatever_git_is_set_to_show(self):
        # log.showSignature puts gpg's lines before the fields the guard
        # asks git log for, and they are not the commit's.
        tree = self.git_output('rev-parse', 'HEAD^{tree}')
        ident = 'T <t@example.com> 1700000000 +0000\n'
        signed = subprocess.run(
            ['git', '-C', str(self.repo), 'hash-object', '-t', 'commit', '-w', '--stdin'],
            input=(f'tree {tree}\nauthor {ident}committer {ident}'
                   'gpgsig -----BEGIN PGP SIGNATURE-----\n \n iQEzBAABCAAdFiEE\n'
                   ' =abcd\n -----END PGP SIGNATURE-----\n\nClean\n'),
            text=True, check=True, capture_output=True).stdout.strip()
        self.git('config', 'log.showSignature', 'true')
        self.assertAllowed(f'git commit --allow-empty -C {signed}')
        self.assertAllowed(f'git commit --allow-empty --fixup={signed}')

    def test_one_place_is_reported_once_and_each_place_is_reported(self):
        # A message read in several encodings gives one finding for each
        # place, at the column its first reading gives; two places that
        # share a label (a title and a body) are each reported.
        mixed = self.folder / 'mixed.txt'
        mixed.write_bytes(b'Caf\xc3\xa9 \xff Thanks ' + PRIVATE_NAME.encode() + b'\n')
        reason = self.assertDenied(f'git commit --allow-empty -F {mixed}')
        self.assertEqual(reason.count('the commit message file:1:'), 1, reason)
        reason = self.assertDenied(f'gh pr create --title "Thanks {PRIVATE_NAME}" '
                                   f'--body "Thanks {PRIVATE_NAME}"')
        self.assertEqual(reason.count('gh pr create:1:8'), 2, reason)

    def test_a_commit_reusing_a_ref_an_earlier_command_moves_is_refused(self):
        # The guard reads a reused commit before the command runs, so a
        # reset, checkout, tag or fetch in the same call would change which
        # commit git takes; a full hash names the same commit either way.
        self.git('commit', '-q', '--allow-empty', '-m', 'Also clean')
        clean = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', f'Thanks {PRIVATE_NAME}')
        self.git('commit', '-q', '--allow-empty', '-m', 'Tidy')
        self.git('tag', 'moving', clean)
        self.git('branch', 'secret', 'HEAD~1')
        for command in ['git reset --soft HEAD~1 && git commit --amend --allow-empty --no-edit',
                        'git reset --soft HEAD~2 && git commit --allow-empty -C ORIG_HEAD',
                        'git tag -f moving HEAD~1 && git commit --allow-empty -C moving',
                        'git checkout -q HEAD~1 && git commit --allow-empty --amend -m Fix',
                        'git fetch origin && git commit --allow-empty -C origin/main',
                        'git cherry-pick -n HEAD~1 && git commit --allow-empty --no-edit',
                        # A cherry-pick that stops leaves its commit's author for the next.
                        'git cherry-pick HEAD~1; git commit --allow-empty -m Fix',
                        'git cherry-pick HEAD~1 && git commit --allow-empty -m Fix',
                        # Strategy options and --no-cleanup are not -n, and
                        # --commit undoes it.
                        'git cherry-pick -Xminimal HEAD~1; git commit --allow-empty -m Fix',
                        'git cherry-pick --no-cleanup HEAD~1; git commit --allow-empty -m Fix',
                        'git cherry-pick -n --commit HEAD~1; git commit --allow-empty -m Fix',
                        # A branch checkout with nothing after --, a fetch
                        # into the checked-out branch.
                        'git checkout secret -- && git commit --allow-empty --amend --no-edit',
                        'git fetch --update-head-ok . secret:claude/topic && '
                        'git commit --allow-empty --amend --no-edit',
                        # A new branch or a reset at HEAD still adds a reflog
                        # entry and sets ORIG_HEAD.
                        'git checkout -b x && git commit --allow-empty -C HEAD@{2}',
                        'git switch -c x && git commit --allow-empty -C HEAD@{2}',
                        'git reset --hard && git commit --allow-empty -C HEAD@{2}',
                        'git reset && git commit --allow-empty -C ORIG_HEAD',
                        # Options that do not list: tag -a annotates, and
                        # --sort, --format, --column and -v still make one.
                        'git tag -a -f -m release moving HEAD~1 && git commit --allow-empty -C moving',
                        'git branch --sort=refname -f other HEAD~1 && git commit --allow-empty -C other',
                        'git branch -v other HEAD~1 && git commit --allow-empty -C other',
                        # What @{u} names, and a remote's branches after -v.
                        'git branch --set-upstream-to=secret && git commit --allow-empty -C @{u}',
                        'git config branch.claude/topic.merge refs/heads/secret && '
                        'git commit --allow-empty -C @{u}',
                        'git remote -v update && git commit --allow-empty -C origin/main',
                        # A reflog entry moves when one goes.
                        'git reflog delete --rewrite HEAD@{1} && git commit --allow-empty -C HEAD@{1}',
                        'git stash && git commit --allow-empty -C stash@{0}']:
            with self.subTest(command=command):
                self.assertIn('earlier', self.assertDenied(command))
        self.assertAllowed('git status && git commit --allow-empty -C moving')
        self.assertAllowed(f'git tag -f moving HEAD~1 && git commit --allow-empty -C {clean}')
        self.assertAllowed('git checkout -b claude/other && git commit --allow-empty -m Fix')
        self.assertAllowed('git cherry-pick HEAD~1 && git commit --allow-empty --reset-author -m Fix')
        # -n leaves no picked commit's author, only a message, which -m replaces.
        self.assertAllowed('git cherry-pick -n HEAD~1 && git commit --allow-empty -m Port')
        self.assertAllowed('git cherry-pick --no-commit HEAD~1 && git commit --allow-empty -m Port')
        self.assertAllowed('git pull --no-rebase origin main && git commit --allow-empty -m Fix')
        # A pull or a rebase that stops leaves no picked author: the next
        # commit takes the configured one (REBASE_HEAD, not CHERRY_PICK_HEAD).
        for command in ['git pull origin main; git commit --allow-empty -m Fix',
                        'git pull && git commit --allow-empty -m x',
                        'git pull -r && git commit --allow-empty -m x',
                        'git rebase main; git commit --allow-empty -m x',
                        'git checkout main && git pull && git checkout -b claude/new && '
                        'git commit --allow-empty -m Start',
                        # A new branch at HEAD leaves HEAD's commit as it is.
                        'git checkout -b claude/other && git commit --allow-empty --amend --no-edit']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_commands_that_move_no_commit_leave_a_reused_one_alone(self):
        # Reading the branch, remotes, tags or stashes, fetching (which
        # moves no checked-out branch) and checking out paths during a
        # merge change neither HEAD nor the pending merge message.
        (self.repo / 'a').write_text('clean\n')
        for command in ['git branch --show-current && git commit --allow-empty --amend --no-edit',
                        'git fetch origin && git commit --allow-empty --amend --no-edit',
                        'git remote -v && git commit --allow-empty --amend --no-edit',
                        'git tag -l && git commit --allow-empty --amend --no-edit',
                        'git stash list && git commit --allow-empty --amend --no-edit',
                        'git log -1 && git commit --allow-empty --amend -m Fix']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        (self.repo / '.git' / 'MERGE_MSG').write_text('Merge main\n')
        for command in ['git checkout --theirs a && git add a && git commit --no-edit',
                        'git checkout --ours a && git add a && git commit --no-edit',
                        'git checkout origin/main -- a && git add a && git commit --no-edit',
                        'git branch --show-current && git add a && git commit --no-edit']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.assertIn('earlier', self.assertDenied(
            'git merge origin/main; git add a && git commit --no-edit'))

    def test_a_cancelled_author_or_message_file_takes_nothing_s_place(self):
        # --no-author and --no-file undo an earlier --author or -F, so
        # --amend keeps the last commit's author and message (git's
        # parse-options: the last of an option and its --no- form wins).
        self.git('commit', '-q', '--allow-empty', '-m', 'Clean',
                 f'--author={PRIVATE_NAME} <someone@example.com>')
        self.assertDenied("git commit --allow-empty --amend --no-edit "
                          "--author='Clean Name <clean@example.com>' --no-author")
        self.assertAllowed("git commit --allow-empty --amend --no-edit --no-author "
                           "--author='Clean Name <clean@example.com>'")
        self.git('commit', '-q', '--allow-empty', '-m', f'Thanks {PRIVATE_NAME}')
        (self.folder / 'message.txt').write_text('Clean message\n')
        message = shlex.quote(str(self.folder / 'message.txt'))
        self.assertDenied(f'git commit --allow-empty --amend -F {message} --no-file --no-edit '
                          "--author='Clean Name <clean@example.com>'")
        self.assertAllowed(f'git commit --allow-empty --amend --no-file -F {message} '
                           "--author='Clean Name <clean@example.com>'")
        self.assertDenied('git commit --allow-empty --amend --no-autho --no-edit')
        # --no-message drops an earlier -m, so --amend keeps the last message.
        self.assertDenied('git commit --allow-empty --amend --no-edit -m Clean --no-message')
        self.assertAllowed('git commit --allow-empty --amend --no-edit --no-message -m Clean')

    def test_what_an_earlier_command_writes_for_a_commit_to_take_is_refused(self):
        # A pending message written in the same call is not read.
        for name in ('MERGE_MSG', 'SQUASH_MSG'):
            with self.subTest(name=name):
                self.assertDenied(f"printf 'Thanks {PRIVATE_NAME}\\n' > .git/{name} && "
                                  'git commit --allow-empty --no-edit')
        # Code that names git may move HEAD.
        self.assertDenied("python3 -c \"import subprocess; subprocess.run(['git', 'reset', 'HEAD~1'])\""
                          ' && git commit --allow-empty --amend --no-edit')
        self.assertAllowed('git commit --allow-empty --amend --no-edit')
        # Code that never names git writes nothing a commit takes, and an
        # amend reads no pending message.
        for command in ['python3 -c "print(1)" && git commit --allow-empty --amend --no-edit',
                        "node -e 'console.log(1)' && git commit --allow-empty --amend --no-edit",
                        "python3 - <<'EOF'\nprint(1)\nEOF\ngit commit --allow-empty --amend --no-edit",
                        'git commit --allow-empty --amend --no-edit && python3 -c "print(1)"']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_pending_merge_message_or_cherry_picked_author_is_read(self):
        # git commit with no message takes MERGE_MSG or SQUASH_MSG, and
        # during a cherry-pick the picked commit's author (builtin/commit.c).
        self.git('commit', '-q', '--allow-empty', '-m', 'Clean',
                 f'--author={PRIVATE_NAME} <someone@example.com>')
        authored = self.git_output('rev-parse', 'HEAD')
        self.git('commit', '-q', '--allow-empty', '-m', 'Also clean')
        for name in ('MERGE_MSG', 'SQUASH_MSG'):
            path = self.repo / '.git' / name
            path.write_text(f'Merge the work\n\nThanks {PRIVATE_NAME}\n')
            with self.subTest(name=name):
                self.assertDenied('git commit --allow-empty --no-edit')
                self.assertDenied('git commit --allow-empty -m Fix --no-message --no-edit')
                self.assertAllowed('git commit --allow-empty -m Fix')
                # --amend takes its message from HEAD, never from these.
                self.assertAllowed('git commit --allow-empty --amend --no-edit')
            path.unlink()
        self.git('update-ref', 'CHERRY_PICK_HEAD', authored)
        self.assertDenied('git commit --allow-empty -m Fix')
        self.assertAllowed('git commit --allow-empty --reset-author -m Fix')
        self.assertAllowed('git commit --allow-empty -m Fix --author="Clean Name <clean@example.com>"')
        self.git('update-ref', '-d', 'CHERRY_PICK_HEAD')
        self.assertAllowed('git commit --allow-empty -m Fix')

    def test_a_commit_message_file_is_read(self):
        message = self.folder / 'message.txt'
        message.write_text(f'Fix it\n\nThanks {PRIVATE_NAME}\n')
        self.assertIn('the commit message file:3:', self.assertDenied(f'git commit -F {message}'))
        self.assertDenied(f'git commit --file={message}')
        # Written in Latin-1 or Windows-1252 (i18n.commitEncoding), an
        # accented name is read as git stores it.
        accented = PRIVATE_NAME.replace('i', '\u00ed', 1)
        for encoding in ('latin-1', 'cp1252'):
            with self.subTest(encoding=encoding):
                message.write_bytes(f'Fix it\n\nThanks {accented}\n'.encode(encoding))
                self.assertDenied(f'git -c i18n.commitEncoding=ISO-8859-1 commit -F {message}')
        message.write_bytes('Fix it\n\nCaf\u00e9 notes\n'.encode('latin-1'))
        self.assertAllowed(f'git commit -F {message}')
        message.write_text('Fix it\n')
        self.assertAllowed(f'git commit -F {message}')
        # A file that does not exist yet cannot be read, and neither can
        # stdin unless a here-document in the same command gives it.
        self.assertIn('must exist', self.assertDenied(f'git commit -F {self.folder}/later.txt'))
        self.assertIn('stdin', self.assertDenied('git commit -F -'))
        self.assertDenied(f"git commit -F - <<'EOF'\nFix it\n\nThanks {PRIVATE_NAME}\nEOF")
        self.assertAllowed("git commit -F - <<'EOF'\nFix it\nEOF")

    def test_what_a_commit_takes_is_read(self):
        notes = self.repo / 'notes.md'
        notes.write_text(f'one\n{PRIVATE_NAME}\n')
        # Not yet staged: an add in the same command would take it.
        self.assertIn('notes.md:2:1:', self.assertDenied(
            'git add notes.md && git commit -m "Add notes"'))
        # A commit naming the path takes it from the working tree.
        self.assertDenied('git commit -m "Add notes" -- notes.md')
        self.git('add', 'notes.md')
        reason = self.assertDenied('git commit -m "Add notes"')
        self.assertIn('notes.md (staged):2:1:', reason)
        # Fixed and staged again, the commit goes ahead, amend included.
        notes.write_text('one\n')
        self.git('add', 'notes.md')
        self.assertAllowed('git commit -m "Add notes"')
        self.git('commit', '-q', '-m', 'Add notes')
        self.assertAllowed('git commit --amend -m "Add the notes"')

    def test_an_add_is_read_from_where_it_runs_and_as_forcefully(self):
        sub = self.repo / 'sub'
        sub.mkdir()
        (sub / 'notes.md').write_text(f'one\n{PRIVATE_NAME}\n')
        # An add that runs in another folder names paths from there.
        for command in ['git -C sub add notes.md && git commit -m x',
                        'cd sub && git add notes.md && cd .. && git commit -m x',
                        'git add sub/notes.md && git -C sub commit -m x']:
            with self.subTest(command=command):
                self.assertIn('sub/notes.md:2:1:', self.assertDenied(command))
        (sub / 'notes.md').unlink()
        # An ignored file is staged only by a forced add, which must read it.
        (self.repo / '.gitignore').write_text('build/\n')
        self.git('add', '.gitignore')
        self.git('commit', '-q', '-m', 'Ignore build')
        (self.repo / 'build').mkdir()
        (self.repo / 'build' / 'evidence.md').write_text(f'{PRIVATE_NAME}\n')
        for command in ['git add -f build/evidence.md && git commit -m x',
                        'git add --force build/evidence.md && git commit -m x',
                        'git add -vf build/evidence.md && git commit -m x',
                        'git add --f build/evidence.md && git commit -m x']:
            with self.subTest(command=command):
                self.assertIn('build/evidence.md:1:1:', self.assertDenied(command))
        # Without --force git refuses to add it, so nothing is read.
        self.assertAllowed('git add build/evidence.md && git commit -m x')
        # An add in a folder the guard cannot know is never guessed.
        self.assertDenied('cd "$(mktemp -d)" && git add notes.md && cd - && git commit -m x')

    def test_a_detail_in_a_file_s_name_is_never_shown(self):
        named = self.repo / (PRIVATE_NAME.replace(' ', '-') + '.md')
        named.write_text('Nothing personal.\n')
        reason = self.assertDenied(f'git add {shlex.quote(named.name)} && git commit -m "Add"')
        self.assertIn('a word from the private list in a name', reason)

    def test_a_push_must_run_the_privacy_hook(self):
        (self.repo / 'notes.md').write_text('Nothing personal.\n')
        self.git('add', 'notes.md')
        self.git('commit', '-q', '-m', 'Add notes')
        self.assertAllowed('git push origin HEAD:claude/topic')
        self.assertAllowed('git push -u origin claude/topic')
        # Skipping the hook, or pointing git at other hooks, is denied.
        for command in ['git push --no-verify origin claude/topic',
                        'git -c core.hooksPath=/dev/null push origin claude/topic',
                        'git -c core.hooksPath= push origin claude/topic',
                        'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath '
                        'GIT_CONFIG_VALUE_0=/dev/null git push origin claude/topic']:
            with self.subTest(command=command):
                self.assertDenied(command)
        # A checkout whose pushes skip it, or whose hook does not run the
        # check, is denied until the hook is on.
        subprocess.run(['git', '-C', str(self.repo), 'config', '--unset', 'core.hooksPath'],
                       check=True)
        self.assertIn('core.hooksPath .githooks',
                      self.assertDenied('git push origin claude/topic'))
        with_privacy_hook(self.repo)
        (self.repo / '.githooks' / 'pre-push').write_text('#!/bin/sh\nexit 0\n')
        self.assertDenied('git push origin claude/topic')
        with_privacy_hook(self.repo)
        (self.repo / '.githooks' / 'pre-push').chmod(0o644)
        self.assertDenied('git push origin claude/topic')
        # A dry run sends nothing.
        self.assertAllowed('git push --dry-run --no-verify origin claude/topic')
        # gh repo create --push pushes the source's commits itself (git push
        # REMOTE HEAD, or --mirror for a bare repository), past the guard's
        # push rules, with the hook on or off.
        for command in ['gh repo create o/clean-tools --source=. --public --push',
                        'gh repo create --push --source . o/clean-tools --private',
                        'gh repo create o/clean-tools -s . --private --push=true',
                        'gh repo create o/clean-tools -s. --private --push=1',
                        'gh repo new o/clean-tools --source=. --private --push',
                        'gh repo create o/clean-tools --source=. --private --push=false --push']:
            with self.subTest(command=command):
                self.assertIn('gh repo create --push', self.assertDenied(command))
        with_privacy_hook(self.repo)
        self.assertDenied('gh repo create o/clean-tools --source=. --public --push')
        for command in ['gh repo create o/clean-tools --source=. --public',
                        'gh repo create o/clean-tools --source=. --public --push=false',
                        'gh repo create o/clean-tools --private --description --push',
                        'gh repo create o/clean-tools --private -- --push']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_unpublished_commands_are_allowed(self):
        # A home folder in a command is not published; only its text is.
        self.assertAllowed(f'cd {PRIVATE_HOME}/code && git status')
        self.assertAllowed(f'grep -rn {shlex.quote(PRIVATE_NAME)} docs')
        self.assertAllowed(f'git -C {self.repo} log --oneline')
        self.assertAllowed('python3 scripts/privacy-check.py --status')

    def test_a_body_httpie_reads_from_a_file_operand_is_read(self):
        # HTTPie sends the file a standalone @file names as the request's
        # body, as if it came from stdin; with no method, it posts it.
        url = 'https://api.github.com/repos/o/r/issues/12/comments'
        payload = self.folder / 'payload.json'
        payload.write_text(json.dumps({'body': f'Thanks {PRIVATE_NAME}'}))
        for command in [f'http --ignore-stdin POST {url} @{payload}',
                        f'http --ignore-stdin {url} @{payload}',
                        f'https --ignore-stdin POST {url} Accept:application/json @{payload}',
                        f'http --ignore-stdin POST {url} -- @{payload}',
                        f'http --ignore-stdin POST {url} @{self.folder}/missing.json']:
            with self.subTest(command=command):
                self.assertDenied(command)
        payload.write_text(json.dumps({'body': 'Thanks for the review'}))
        for command in [f'http --ignore-stdin POST {url} @{payload}',
                        f'http --ignore-stdin {url} @{payload}']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_text_sent_to_github_by_gh_or_the_api_is_read(self):
        for command in [f'gh pr create --title t --body {shlex.quote(PRIVATE_ADDRESS)}',
                        f'gh pr create -t {shlex.quote(PRIVATE_NAME)} -b ok',
                        f'gh pr comment 12 -b {shlex.quote(PRIVATE_PHONE)}',
                        f'gh issue create --title {shlex.quote(PRIVATE_NAME)} --body x',
                        f'gh pr review 12 --comment -b {shlex.quote(PRIVATE_NAME)}',
                        f'gh pr edit 12 --body {shlex.quote(PRIVATE_NAME)}',
                        f'gh release create v1 --notes {shlex.quote(PRIVATE_NAME)}',
                        "gh api -X POST repos/o/r/issues/12/comments -f "
                        + shlex.quote('body=' + PRIVATE_NAME),
                        "gh api repos/o/r/issues/12/comments -f "
                        + shlex.quote('body=' + PRIVATE_NAME),
                        'curl -q -X POST https://api.github.com/repos/o/r/issues/12/comments '
                        '-d ' + shlex.quote(json.dumps({'body': PRIVATE_ADDRESS})),
                        # curl takes one, two or three slashes after the colon.
                        'curl -q -X POST https:/api.github.com/repos/o/r/issues/12/comments '
                        '-d ' + shlex.quote(json.dumps({'body': PRIVATE_NAME})),
                        'curl -q -X POST https:///api.github.com/repos/o/r/issues/12/comments '
                        '-d ' + shlex.quote(json.dumps({'body': PRIVATE_NAME})),
                        'curl -q -X POST HTTPS:/API.GITHUB.COM/repos/o/r/issues/12/comments '
                        '-d ' + shlex.quote(json.dumps({'body': PRIVATE_NAME})),
                        # HTTPie reads an option after the address too.
                        'http --ignore-stdin POST https://api.github.com/repos/o/r/issues/12/comments'
                        ' --raw ' + shlex.quote(json.dumps({'body': PRIVATE_NAME}))]:
            with self.subTest(command=command):
                self.assertDenied(command)
        body = self.folder / 'body.md'
        body.write_text(f'Thanks {PRIVATE_NAME}\n')
        self.assertDenied(f'gh pr create --title t --body-file {body}')
        # After the command's name, -R is the value of an option before it.
        self.assertDenied(f'gh pr create --title -R --body-file {body}')
        self.assertDenied(f'gh pr create -t -R -F {body}')
        self.assertDenied(f'gh pr comment 12 -F {body}')
        self.assertDenied(f'gh api -X PATCH repos/o/r/pulls/12 -F body=@{body}')
        self.assertDenied(f"gh pr comment 12 --body-file - <<'EOF'\n{PRIVATE_NAME}\nEOF")
        # A body file that is not there yet cannot be read.
        self.assertDenied(f'gh pr comment 12 --body-file {self.folder}/missing.md')
        for command in ['gh pr create --title "Add a check" --body "Fixes the layout"',
                        'gh pr view 12 --json body', 'gh api repos/o/r/pulls/12',
                        f'gh api "search/issues?q={PRIVATE_NAME.split()[0]}"',
                        "gh pr comment 12 --body-file - <<'EOF'\n@coderabbitai review\nEOF"]:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_text_sent_by_a_github_tool_is_read(self):
        for name, arguments in [
                ('mcp__github__create_pull_request', {'title': 't', 'body': PRIVATE_NAME}),
                ('mcp__github__update_pull_request', {'pullNumber': 1, 'title': PRIVATE_NAME}),
                ('mcp__github__add_issue_comment', {'issue_number': 1, 'body': PRIVATE_ADDRESS}),
                ('mcp__github__add_reply_to_pull_request_comment', {'body': PRIVATE_PHONE}),
                ('mcp__github__pull_request_review_write', {'event': 'COMMENT',
                                                           'body': PRIVATE_NAME}),
                ('mcp__github__issue_write', {'method': 'create', 'title': 'x',
                                              'body': PRIVATE_NAME}),
                ('mcp__github__create_branch', {'branch': 'claude/' + PRIVATE_NAME.replace(' ', '-'),
                                                'from_branch': 'main'}),
                ('mcp__github__create_or_update_file', {'branch': 'claude/topic',
                                                        'path': 'a.md', 'content': PRIVATE_HOME}),
                ('mcp__github__delete_file', {'branch': 'claude/topic', 'path': 'a.md',
                                              'message': PRIVATE_NAME}),
                ('mcp__github__push_files', {'branch': 'claude/topic', 'message': 'm',
                                             'files': [{'path': 'a.md', 'content': 'ok'},
                                                       {'path': 'b.md', 'content': PRIVATE_NAME}]}),
                ('mcp__github__push_files', {'branch': 'claude/topic', 'message': PRIVATE_NAME,
                                             'files': [{'path': 'a.md', 'content': 'ok'}]}),
                ('mcp__github__create_repository', {'name': PRIVATE_NAME.replace(' ', '-')}),
                ('mcp__github__create_repository', {'name': 'tools',
                                                    'description': PRIVATE_NAME}),
                ('mcp__github__fork_repository', {'owner': 'o', 'repo': 'r',
                                                  'name': PRIVATE_NAME.replace(' ', '-')})]:
            with self.subTest(name=name, arguments=arguments):
                self.assertEqual(self.tool(name, arguments), 'deny')
        for name, arguments in [
                ('mcp__github__add_issue_comment', {'issue_number': 1,
                                                    'body': '@coderabbitai review'}),
                ('mcp__github__create_pull_request', {'title': 'Add a check',
                                                      'body': 'noreply@anthropic.com'}),
                ('mcp__github__create_repository', {'name': 'clean-tools',
                                                    'description': 'Clean tools'}),
                ('mcp__github__pull_request_read', {'pullNumber': 1, 'body': PRIVATE_NAME})]:
            with self.subTest(name=name):
                self.assertIsNone(self.tool(name, arguments))

    def test_without_a_list_nothing_is_published(self):
        self.env.pop('BRICKSON_PRIVATE_WORDS')
        self.assertIn('could not run', self.assertDenied('git commit -m "Fix it"'))
        self.assertDenied('gh pr comment 12 --body ok')
        self.assertEqual(self.tool('mcp__github__add_issue_comment', {'body': 'ok'}), 'deny')
        self.assertAllowed('git status')

    def test_file_content_sent_in_base64_is_decoded_and_checked(self):
        # The Contents API and a Git blob take a file's content in base64:
        # what goes public is the decoded bytes, which no pre-push hook sees.
        encoded = base64.b64encode(f'Notes\nThanks {PRIVATE_NAME}\n'.encode()).decode()
        wrapped = '\\n'.join(encoded[i:i + 12] for i in range(0, len(encoded), 12))
        request = self.folder / 'blob.json'
        request.write_text('{"content": "' + wrapped + '", "encoding": "base64"}')
        api = 'https://api.github.com/repos/o/r/contents/a.txt'
        for command in [
                f'gh api --method PUT repos/o/r/contents/a.txt -f branch=claude/topic '
                f'-f message=clean -f content={encoded}',
                f'gh api -X POST repos/o/r/git/blobs --input {request}',
                f"curl -q -X PUT {api} -d '{{\"branch\":\"claude/topic\",\"message\":\"x\","
                f"\"content\":\"{encoded}\"}}'"]:
            with self.subTest(command=command[:40]):
                self.assertIn('encoded', self.assertDenied(command))
        mutation = ('mutation { createCommitOnBranch(input: {fileChanges: {additions: '
                    f'[{{path: "a.txt", contents: "{encoded}"}}]}}}}) {{ commit {{ oid }} }} }}')
        # GraphQL's commit is refused already, as a ref write.
        self.assertDenied(f"gh api graphql -f query='{mutation}'")
        clean = base64.b64encode(b'Notes\nThanks to everyone\n').decode()
        self.assertAllowed(f'gh api --method PUT repos/o/r/contents/a.txt -f branch=claude/topic '
                           f'-f message=clean -f content={clean}')
        # JSON may spell every letter as a \u escape: what GitHub decodes
        # is the same base64.
        def escaped(text):
            return ('{"branch": "claude/topic", "message": "x", "content": "'
                    + ''.join(f'\\u{ord(letter):04x}' for letter in text) + '"}')
        request.write_text(escaped(encoded))
        for command in [f'gh api -X PUT repos/o/r/contents/a.txt --input {request}',
                        f'gh api -X POST repos/o/r/git/blobs --input {request}',
                        f'curl -q -X PUT {api} -d @{request}']:
            with self.subTest(command=command[:40]):
                self.assertIn('encoded', self.assertDenied(command))
        request.write_text(escaped(clean))
        self.assertAllowed(f'gh api -X PUT repos/o/r/contents/a.txt --input {request}')
        # Any line break JSON can spell may sit between two parts of the run.
        for separator in ['\\r', '\\n', '\\r\\n', '\\u000d', '\\u000a', '\\u000d\\u000a']:
            request.write_text('{"branch": "claude/topic", "message": "x", "content": "'
                               + encoded[:16] + separator + encoded[16:] + '"}')
            with self.subTest(separator=separator):
                self.assertIn('encoded', self.assertDenied(
                    f'gh api -X PUT repos/o/r/contents/a.txt --input {request}'))

    def test_a_contents_api_write_s_file_name_is_checked(self):
        # The Contents API names the file it writes in its address, and
        # GitHub shows the file under that name.
        clean = base64.b64encode(b'ok\n').decode()
        fields = f'-f branch=claude/topic -f message=clean -f content={clean}'
        named = PRIVATE_NAME.replace(' ', '-')
        api = 'https://api.github.com/repos/o/r/contents'
        for command in [
                f'gh api -X PUT repos/o/r/contents/docs/{named}.txt {fields}',
                f'gh api -X PUT /repos/o/r/contents/{PRIVATE_NAME.replace(" ", "%20")}.txt {fields}',
                f'gh api -X PUT "repos/{{owner}}/{{repo}}/contents/{named}.txt?x=1" {fields}',
                f"curl -q -X PUT {api}/{named}.txt "
                f"-d '{{\"branch\":\"claude/topic\",\"message\":\"x\",\"content\":\"{clean}\"}}'"]:
            with self.subTest(command=command[:50]):
                self.assertIn('file name', self.assertDenied(command))
        self.assertAllowed(f'gh api -X PUT repos/o/r/contents/docs/notes.txt {fields}')
        # Reading a file by its name publishes nothing.
        self.assertAllowed(f'gh api repos/o/r/contents/docs/{named}.txt')

    def test_a_name_split_by_an_escape_in_a_request_body_is_found(self):
        # JSON writes a line break or a tab as \n or \t; GitHub stores the
        # two words.
        request = self.folder / 'payload.json'
        request.write_text(json.dumps({'title': 'x', 'body': PRIVATE_NAME.replace(' ', '\n')}))
        api = 'https://api.github.com/repos/o/r/issues'
        for command in [f'gh api --method POST repos/o/r/issues --input {request}',
                        f'curl -q -X POST {api} --json @{request}']:
            with self.subTest(command=command[:30]):
                self.assertDenied(command)

    def test_a_commit_into_another_checkout_or_index_is_refused(self):
        # --git-dir, --work-tree, core.worktree and Git's variables choose
        # another repository, work tree or index than the folder's, which is
        # what the check reads before the commit.
        other = self.folder / 'other'
        other.mkdir()
        init_repository(other, 'main')
        for command in [f'git --git-dir={other}/.git --work-tree={other} commit -m x',
                        f'git --git-dir {other}/.git commit -m x',
                        f'git --work-tree={other} commit -m x',
                        f'git -c core.worktree={other} commit -m x',
                        f'GIT_DIR={other}/.git git commit -m x',
                        f'GIT_INDEX_FILE={other}/.git/index git commit -m x',
                        f'env GIT_WORK_TREE={other} git commit -m x',
                        f'export GIT_DIR={other}/.git; git commit -m x']:
            with self.subTest(command=command):
                self.assertIn('git -C', self.assertDenied(command))
        self.assertAllowed(f'git -C {other} commit -m x')
        self.assertAllowed(f'GIT_DIR={other}/.git env -u GIT_DIR git commit -m x')

    def test_a_release_asset_upload_is_refused(self):
        # A release asset's contents and name go to GitHub, and what an
        # archive holds cannot be read here, so the guard refuses the
        # upload; a release's notes are still read as text.
        (self.repo / 'notes.txt').write_text(f'Thanks {PRIVATE_NAME}\n')
        (self.repo / 'clean.txt').write_text('Nothing personal.\n')
        uploads = 'https://uploads.github.com/repos/o/r/releases/1/assets?name=clean.txt'
        for command in ['gh release create v1 notes.txt --notes clean',
                        'gh release create v1 clean.txt --notes clean',
                        "gh release create v1 'clean.txt#Label' --notes clean",
                        'gh release create --notes clean --target main v1 clean.txt',
                        'gh release new v1 clean.txt --notes clean',
                        'gh release upload v1 clean.txt',
                        'gh release upload --clobber v1 clean.txt',
                        'gh -R o/r release upload v1 clean.txt',
                        f'curl -q -X POST --data-binary @clean.txt "{uploads}"',
                        f'gh api --hostname uploads.github.com "{uploads[27:]}" --input clean.txt',
                        f'gh api "{uploads}" --input clean.txt']:
            with self.subTest(command=command):
                self.assertIn('release asset', self.assertDenied(command))
        # A release with no assets: its notes are read as before.
        self.assertAllowed('gh release create v1 --notes clean')
        self.assertAllowed('gh release create v1 --target main --notes-start-tag v0 --notes clean')
        self.assertAllowed('gh release create v1 --latest=false --notes clean')
        self.assertDenied(f'gh release create v1 --notes {shlex.quote(PRIVATE_NAME)}')
        self.assertAllowed('gh release view v1')
        # A release's tag and a repository's name are public too.
        named = PRIVATE_NAME.replace(' ', '-')
        for command in [f'gh release create {named} --notes clean',
                        f'gh release create --notes clean v1-{named}',
                        f'gh release edit v1 --tag {named}',
                        f'gh repo create {named} --public --description clean',
                        f'gh repo create o/{named} --private',
                        f'gh repo create --license mit o/{named}',
                        f'gh repo rename {named}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('gh repo create o/clean-tools --private --description clean')
        # With no name, gh names the repository after --source's folder.
        named_folder = self.folder / named
        named_folder.mkdir()
        clean_folder = self.folder / 'clean-tools'
        clean_folder.mkdir()
        for command in [f'gh repo create --source={named_folder} --public',
                        f'gh repo create -s {named_folder} --private --remote=upstream',
                        f'cd {named_folder} && gh repo create --source=. --public',
                        f'cd {named_folder}/.. && gh repo create --source {named} --public']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed(f'gh repo create --source={clean_folder} --public')
        self.assertAllowed(f'gh repo create o/clean-tools --source={named_folder} --public')
        # gh issue develop makes a branch on GitHub under --name.
        for command in [f'gh issue develop 12 --name {named}',
                        f'gh issue develop 12 -n claude/{named} --repo o/r',
                        f'gh issue develop --base main --name={named} 12']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('gh issue develop 12 --name claude/fix-layout --repo o/r')
        self.assertAllowed('gh issue develop 12 --list')
        self.assertAllowed('gh release download v1')

    def test_other_names_and_text_gh_puts_on_github_are_read(self):
        # A fork's name, a topic, a gist file's new name, a project's text
        # and an Actions variable are put on GitHub too; -R in a cluster
        # takes the next word, so the name after it is still read.
        named = PRIVATE_NAME.replace(' ', '-')
        quoted = shlex.quote(PRIVATE_NAME)
        (self.repo / 'variables.env').write_text(f'NOTE={PRIVATE_NAME}\n')
        for command in [f'gh repo fork o/r --fork-name {named}',
                        f'gh repo fork o/r --fork-name={named} --clone=false',
                        f'gh repo edit --add-topic {named.lower()}',
                        f'gh gist rename abc123 old.txt {named}.txt',
                        f'gh project create --owner @me --title {quoted}',
                        f'gh project edit 1 --owner @me --readme {quoted}',
                        f'gh project edit 1 --owner @me -d {quoted}',
                        f'gh project item-create 1 --owner @me --title x --body {quoted}',
                        f'gh project item-edit --id 1 --title {quoted}',
                        f'gh project field-create 1 --owner @me --name {quoted} --data-type TEXT',
                        f'gh variable set NOTE --body {quoted}',
                        f'gh variable set NOTE -b{quoted}',
                        'gh variable set -f variables.env',
                        'gh variable set NOTE',
                        f'gh repo rename -yR o/r {named}',
                        f'gh label create -fR o/r {named}',
                        # A value flag read as a switch (--jq, --template,
                        # --remove-topic) leaves the text an operand, which
                        # is read too.
                        f'gh project item-create 1 --owner @me --title x --format json -t --body --body {quoted}',
                        f'gh project item-create 1 --owner @me --format json -q --title --title {quoted}',
                        f'gh project item-edit --id I --project-id P --field-id F --format json --jq --text --text {quoted}',
                        f'gh project edit 1 --owner @me --format json -t --readme --readme {quoted}',
                        f'gh repo edit --remove-topic --add-topic --add-topic {named.lower()}',
                        f'gh repo edit --remove-topic --description --description {quoted}',
                        f'gh pr edit 1 --add-label --title --title {quoted}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        # gh names a repository after --source as written, not where a link leads.
        (self.folder / named).symlink_to(self.repo)
        for command in [f'gh repo create --source={named} --private',
                        f'cd {named} && gh repo create --source=. --private']:
            with self.subTest(command=command):
                output = guard_output('Bash', {'command': command}, self.folder, self.env)
                self.assertEqual(output and output['permissionDecision'], 'deny')
        for command in ['gh repo create --source=a\x00b --private',
                        'gh repo create --source=\ud800x --private']:
            with self.subTest(command=repr(command)):
                self.output(command)  # guard_output fails if the guard crashes
        self.assertAllowed('gh pr edit "$PR" --title Clean')
        for command in ['gh repo fork o/r --fork-name clean-tools --clone=false',
                        'gh repo edit --add-topic accessibility',
                        'gh gist rename abc123 old.txt new.txt',
                        'gh project create --owner @me --title Roadmap',
                        'gh variable set NOTE --body clean',
                        'gh release create -dR o/r v1.0 --notes clean',
                        'gh repo rename -yR o/r clean-tools']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_quoted_word_does_not_vouch_for_a_built_one(self):
        # Whether a $ is text is decided word by word: '$BODY' in one place
        # does not make "$BODY", which the shell fills in, text elsewhere.
        for command in ["echo '$BODY'; gh pr comment 12 --body \"$BODY\"",
                        "gh pr create --title '$BODY' --body \"$BODY\"",
                        "echo '$MSG' && git commit -m \"$MSG\"",
                        "gh issue comment 1 --body=\"$BODY\" && echo '--body=$BODY'"]:
            with self.subTest(command=command):
                self.assertIn('variable', self.assertDenied(command))
        self.assertAllowed("echo '$BODY'; gh pr comment 12 --body 'Costs $BODY'")
        self.assertAllowed("gh pr create --title '$BODY' --body 'Use $BODY'")

    def test_a_push_after_a_change_to_the_hook_in_the_same_call_is_refused(self):
        # The guard reads the hook and its setting before the whole call
        # runs; a command before the push in the same call could turn the
        # hook off or change it, so the push is refused.
        push = 'git push origin claude/topic'
        for command in [f'git config --replace-all core.hooksPath /dev/null && {push}',
                        f'git config core.hookspath /dev/null; {push}',
                        f'git config --unset core.hooksPath && {push}',
                        f'git config set --global core.hooksPath /dev/null && {push}',
                        f'git config --remove-section core && {push}',
                        f'git config include.path /tmp/other && {push}',
                        f'chmod -x .githooks/pre-push && {push}',
                        f'chmod -R a-x . && {push}',
                        f'rm .githooks/pre-push && {push}',
                        f'rm -rf .githooks; {push}',
                        f'mv .githooks/pre-push pre-push.old && {push}',
                        f'echo "exit 0" > .githooks/pre-push && {push}',
                        f'printf "[core]\\n\\thooksPath = /dev/null\\n" >> .git/config && {push}',
                        f'cp /dev/null scripts/privacy-check.py && {push}',
                        f'cd .githooks && chmod -x pre-push && cd .. && {push}',
                        f'git checkout main -- .githooks && {push}',
                        f'git restore --source=main . && {push}',
                        f'git rm -q --cached .githooks/pre-push && rm .githooks/pre-push && {push}',
                        f'git switch main && {push}',
                        'git checkout -b claude/other main && git push origin claude/other',
                        f"python3 -c 'print(1)' && {push}"]:
            with self.subTest(command=command):
                self.assertIn('hook', self.assertDenied(command))
        # A push in its own call, or after commands that leave the hook be.
        for command in [push, f'git config --get core.hooksPath && {push}',
                        'git checkout -b claude/next && git push -u origin claude/next',
                        'git switch -c claude/next && git push -u origin claude/next',
                        f'{push} && chmod -x .githooks/pre-push',
                        f'echo done > notes.txt && {push}',
                        f'python3 scripts/privacy-check.py --outgoing --no-list && {push}',
                        f'git config user.name t && {push}']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_the_list_is_closed_to_file_tools_and_commands_wherever_it_lives(self):
        # The checker reads the list from XDG_CONFIG_HOME when that is an
        # absolute path, and the Read and Edit deny rules name only the
        # default folder: the guard runs before the file tools and refuses
        # the list's folder at both places.
        config = self.folder / 'config'  # this test's XDG_CONFIG_HOME
        home = self.folder / 'home'
        environment = {**self.env, 'HOME': str(home)}
        for folder in (config / 'brickson', home / '.config' / 'brickson'):
            folder.mkdir(parents=True)
            (folder / 'private-words.txt').write_text(PRIVATE_NAME + '\n')
        words = config / 'brickson' / 'private-words.txt'
        (self.repo / 'linked.txt').symlink_to(words)
        for name, arguments in [
                ('Read', {'file_path': str(words)}),
                ('Read', {'file_path': str(home / '.config/brickson/private-words.txt')}),
                ('Read', {'file_path': 'linked.txt'}),
                ('Edit', {'file_path': str(words), 'old_string': 'a', 'new_string': 'b'}),
                ('MultiEdit', {'file_path': str(words), 'edits': []}),
                ('Write', {'file_path': str(config / 'brickson' / 'new.txt'), 'content': 'x'}),
                ('NotebookEdit', {'notebook_path': str(config / 'brickson' / 'n.ipynb'),
                                  'new_source': 'x'}),
                ('Grep', {'pattern': '.', 'path': str(config / 'brickson')}),
                ('Grep', {'pattern': '.', 'path': str(config)}),
                ('Grep', {'pattern': '.', 'path': str(self.folder)}),
                ('Glob', {'pattern': '*', 'path': str(config / 'brickson')}),
                ('Glob', {'pattern': '**/*', 'path': str(config)})]:
            with self.subTest(name=name, arguments=arguments):
                output = guard_output(name, arguments, self.repo, environment)
                self.assertEqual(output and output['permissionDecision'], 'deny')
                self.assertIn('--status', output['permissionDecisionReason'])
        for name, arguments in [('Read', {'file_path': str(self.repo / 'notes.md')}),
                                ('Edit', {'file_path': 'notes.md', 'old_string': 'a',
                                          'new_string': 'b'}),
                                ('Grep', {'pattern': 'x'}),
                                ('Grep', {'pattern': 'x', 'path': str(self.repo)}),
                                ('Glob', {'pattern': '**/*.py', 'path': str(self.folder)}),
                                ('Read', {'file_path': str(config / 'gh' / 'hosts.yml')})]:
            with self.subTest(name=name, arguments=arguments):
                self.assertIsNone(guard_output(name, arguments, self.repo, environment))
        # Commands that reach the configured folder without naming .config.
        for command in [f'grep -r . {config}', f'ls {config}/brickson', f'cat {config}/*/*',
                        f'cat {self.folder}/conf*/b*/*', f'find {config} -type f',
                        f'cd {config} && cat brickson/*', f'grep -r x {self.folder}/*']:
            with self.subTest(command=command):
                output = guard_output('Bash', {'command': command}, self.repo, environment)
                self.assertEqual(output and output['permissionDecision'], 'deny')
                self.assertIn('--status', output['permissionDecisionReason'])
        for command in [f'ls {self.folder}', f'cat {config}/gh/hosts.yml',
                        f'cat {config}/b*/x/y.txt', f'cat {self.folder}/*/notes.md']:
            with self.subTest(command=command):
                self.assertIsNone(guard_output('Bash', {'command': command}, self.repo,
                                               environment))
        # A link made in an earlier call: a program, and bash's glob, read
        # a .. after it where the link leads, though cd ~/l stays at ~/l.
        (home / '.config' / 'gh').mkdir()
        (home / 'l').symlink_to(home / '.config' / 'gh')
        for command in ['cd ~/l && cat ../b*/*', 'cat ~/l/../b*/*', 'cd ~/l && grep -r . ..']:
            with self.subTest(command=command):
                output = guard_output('Bash', {'command': command}, self.repo, environment)
                self.assertEqual(output and output['permissionDecision'], 'deny')
        for command in ['cd ~/l && cat hosts.yml', 'cd ~/l && cd .. && ls']:
            with self.subTest(command=command):
                self.assertIsNone(guard_output('Bash', {'command': command}, self.repo,
                                               environment))

    def test_the_private_list_is_never_read(self):
        for command in ['cat ~/.config/brickson/private-words.txt',
                        'cat "$HOME/.config/brickson/private-words.txt"',
                        'ls ~/.config/brickson', 'echo "$BRICKSON_PRIVATE_WORDS"',
                        'echo ${BRICKSON_PRIVATE_WORDS}', 'printenv BRICKSON_PRIVATE_WORDS',
                        'base64 -d <<< "$BRICKSON_PRIVATE_WORDS"']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))

    def test_the_folder_that_holds_the_list_is_never_read_whole(self):
        # A recursive or wildcard read of the config folder reaches the list
        # without naming it, and Read deny rules do not cover such a read.
        for command in ['grep -r . ~/.config', 'find ~/.config -type f -exec cat {} +',
                        'cd ~/.config && cat b*/*', 'grep -rn word "$XDG_CONFIG_HOME"',
                        'grep -r . "$XDG_CONFIG_HOME/"', 'grep -r . "${XDG_CONFIG_HOME}"/',
                        'rg -uu word $HOME/.config/', 'ls ~/.config/', 'cat ~/.c*/b*/*',
                        'cat ~/.*/brick*/*', 'cd ~ && grep -r x .config',
                        "tar -czf out.tgz -C ~ '.config'", 'grep -r x --include=* ~/.conf?g',
                        'cat ~/.config/./*/*', 'grep -r x ~/.config/*']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        # A relative path is read from the folder a cd reaches, .. and a glob
        # included, at the default place and where XDG_CONFIG_HOME puts it.
        config = self.folder / 'config'  # this test's XDG_CONFIG_HOME
        for command in ['cd ~/.config/gh && cat ../b*/*', 'cd ~/.config/gh/.. && cat b*/*',
                        'cd ~/.config/gh && grep -r . ..', 'cd ~/.config/gh; cd ..',
                        'cd "$HOME/.config/gh" && cat ../b*/*',
                        'cd ${HOME}/.config/gh && grep -r x ../*',
                        'pushd ~/.config/gh && cat ../b*/*', '(cd ~/.config/gh && cat ../b*/*)',
                        "bash -c 'cd ~/.config/gh && cat ../b*/*'",
                        'env -C ~/.config/gh cat ../b*/*', 'cd ~/.config/gh && find .. -type f',
                        'cd ~/.config/gh/../gh && cat ../brick?on/*',
                        f'cd {config}/gh && cat ../b*/*', f'cd {config}/gh && grep -r . ..',
                        'cd "$XDG_CONFIG_HOME/gh" && cat ../b*/*',
                        'cd "${XDG_CONFIG_HOME}"/gh && grep -r . ../.']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        # Other config folders and files, and words that only contain .config.
        for command in ['ls ~/.config/gh', 'cat ~/.config/gh/hosts.yml',
                        'cat "$XDG_CONFIG_HOME"/gh/hosts.yml', 'cat ~/.config/*/hosts.yml',
                        'cat webpack.config.js', 'git config --get core.hooksPath',
                        'cat ~/.gitconfig', 'ls ~/.cache', 'cat ~/.config/b*/x/y.txt',
                        'cd ~/.config/gh && cat hosts.yml', 'cd ~/.config/gh && ls',
                        'cd "$HOME/.config/gh" && cat ../gh/hosts.yml',
                        'cd ~/.config/gh && cat ../*/hosts.yml', 'cd ~/.config/gh && grep -r x .',
                        f'cd {config}/gh && cat hosts.yml', 'cd .. && ls']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_read_is_placed_however_the_shell_writes_its_folder(self):
        # cd's options, a folder named through $HOME, $XDG_CONFIG_HOME or
        # $PWD, ~+, a HOME the command changes, a program's own -C and a
        # CDPATH entry place a relative read as the shell would.
        config = self.folder / 'config'  # this test's XDG_CONFIG_HOME
        for command in ['cd "$HOME" && cat .config/gh/../b*/*',
                        'cd $HOME && grep -r . .config/gh/..',
                        f'cd "$XDG_CONFIG_HOME/.." && cat {config.name}/b*/*',
                        'cd -P ~/.config/gh && cat ../b*/*', 'cd -- ~/.config/gh && cat ../b*/*',
                        'cd -L ~/.config/gh && grep -r . ..', 'cd -e ~/.config/gh && cat ../b*/*',
                        'cd -LP -- ~/.config/gh && cat ../b*/*',
                        'cd ~/.config/gh && cat ~+/../b*/*',
                        'cd ~/.config/gh && cat "$PWD"/../b*/*',
                        'cd ~/.config/gh && cat ${PWD}/../b*/*',
                        'export HOME=~/.config/gh && cat ~/../b*/*',
                        'HOME=~/.config/gh; cat ~/../b*/*',
                        'export HOME=~/.config/gh && cd ~ && cat ../b*/*',
                        'git -C ~/.config/gh diff --no-index . ..',
                        'tar -C ~/.config/gh -cf - ..', 'tar -cf - -C~/.config/gh ..',
                        'make --directory=~/.config/gh -f ../b*/*',
                        f'git -C {config}/gh diff --no-index . ..',
                        'CDPATH=:~/.config/gh/.. cd brickson && cat *',
                        'CDPATH=/x:~/.config/gh/.. cd brickson && cat *',
                        # The XDG idiom, and other default forms.
                        'grep -r . "${XDG_CONFIG_HOME:-$HOME/.config}"',
                        'cat "${XDG_CONFIG_HOME:-$HOME/.config}"/b*/*',
                        'cat ${XDG_CONFIG_HOME-~/.config}/b*/*',
                        'cd "${XDG_CONFIG_HOME:-${HOME}/.config}"/gh && cat ../b*/*',
                        'cat ${XDG_CONFIG_HOME:+~/.config/gh}/../b*/*']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        unset = {key: value for key, value in self.env.items() if key != 'XDG_CONFIG_HOME'}
        for command in ['grep -r . "${XDG_CONFIG_HOME:-$HOME/.config}"',
                        'cat "${XDG_CONFIG_HOME:-${HOME}/.config}"/b*/*']:
            with self.subTest(command=command, xdg='unset'):
                output = guard_output('Bash', {'command': command}, self.repo, unset)
                self.assertEqual(output and output['permissionDecision'], 'deny')
        for command in ['cd "$HOME" && cat .config/gh/hosts.yml',
                        'cd -P ~/.config/gh && cat hosts.yml',
                        'cd ~/.config/gh && cat "$PWD"/hosts.yml',
                        'git -C ~/.config/gh status', 'tar -C ~/.config/gh -cf - hosts.yml',
                        'grep -C 3 x README.md', 'CDPATH=/x:/y cd docs && ls',
                        'cat "${XDG_CONFIG_HOME:-$HOME/.config}"/gh/hosts.yml',
                        'echo "${HOME:+x}" "${PWD:-y}"']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_braces_are_expanded_before_the_list_is_looked_for(self):
        for command in ['cat ~/.config/{,}b*/*', 'cat ~/.config/b{,}*/*',
                        'cat ~/.{config,x}/b*/*', 'cat ~/.config/{gh/..,x}/b*/*',
                        'cd ~/.config/gh && cat ../{b,x}*/*', 'cat ~/.config/{a..c}rickson/*',
                        'cd ~/.config/gh && cat ../b*/{,}*', 'grep -r . ~/.{con{f,x}ig,x}']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        self.assertAllowed('cat docs/{HANDOFF,ROADMAP}.md')
        self.assertAllowed('echo {1..3} {a,b}')
        self.assertAllowed('cat ~/.config/{gh,git}/hosts.yml')
        # A newline in one alternative, or a long one, does not hide the others.
        for command in ["cat {$'\\n',~/.config/gh/../b*}/*",
                        "CDPATH=$'\\n':~/.config/gh/.. cd brickson && cat p*",
                        "export CDPATH=$'\\n':~/.config/gh/..; cd brickson && cat p*",
                        'cat {' + 'A' * 4100 + ',~/.config/gh/../b*}/*']:
            with self.subTest(command=command[:60]):
                self.assertIn('--status', self.assertDenied(command))
        # Every number of a range, as bash makes them.
        environment = {**self.env, 'XDG_CONFIG_HOME': str(self.folder / 'cfg2')}
        output = guard_output('Bash', {'command': f'cat {self.folder}/cfg{{0..3}}/b*/*'},
                              self.repo, environment)
        self.assertEqual(output and output['permissionDecision'], 'deny')

    def test_a_long_word_or_many_folders_are_read_in_time(self):
        # A long JSON body has braces and colons in quotes, and a script
        # of many cd lines leaves the same folders many ways; the guard
        # must still answer well inside its 10 seconds.
        body = '[' + ','.join('{"path":"docs/a%d.md","line":%d,"side":"RIGHT","body":"Fix"}'
                              % (index, index) for index in range(65)) + ']'
        quoted = shlex.quote(body)
        (self.repo / 'sub').mkdir()
        lines = '\n'.join(body for _ in range(20))
        for command in [f'curl -s -X POST -d payload={quoted} https://example.com/hook',
                        f'cd sub; curl -s -X POST -d a={quoted} -d b={quoted} -d c={quoted} '
                        'https://example.com/hook',
                        f'cd sub; cd ..; cd sub; cd ..; curl -s -X POST -d a={quoted} '
                        f'-d b={quoted} https://example.com/hook',
                        f"cat > build.jsonl <<'EOF'\n{lines}\nEOF",
                        '\n'.join(['cd sub', 'ls -la', 'cd ..', 'git status --short'] * 8)]:
            with self.subTest(command=command[:60]):
                start = time.monotonic()
                self.assertAllowed(command)
                self.assertLess(time.monotonic() - start, 4)
        # Prose with braces and colons in a quote that opens inside a word
        # (body="..."), after cd lines; braces with no end; a long word of
        # many brace groups.
        note = ''.join('Note %d: checked on iPad, iOS 27: the closure { a, b in a + b } '
                       'works.\n' % index for index in range(900))
        for command in ['cd d1; cd d2; cd d3; cd d4; cd d5; cd d6; cd d7\n'
                        f'printf "%s\\n" title="Summary: {{a, b}}" body="{note}"',
                        f'gh pr comment 12 --body="{note}"',
                        'echo {1..' + '9' * 5000 + '}', 'echo {' + '0' * 30000 + '1..1025}',
                        'echo ' + '{a,b}' * 11 + 'z' * 60000,
                        'git commit --allow-empty -m ' + '{a,b}' * 11 + 'z' * 20000]:
            with self.subTest(command=command[:60]):
                start = time.monotonic()
                self.output(command)  # guard_output fails if the guard crashes
                self.assertLess(time.monotonic() - start, 4)
        # Scripts that stop when a cd fails (|| exit, set -e), that go
        # back with popd, or that make each step a subshell stay in the
        # folders they name.
        for command in ['\n'.join(f'cd d{index} || exit 1\nls' for index in range(8)),
                        'set -e\n' + '\n'.join(f'cd d{index}\nls\ncd ..' for index in range(8)),
                        '\n'.join(f'cd d{index} && make && cd ..' for index in range(8)),
                        '\n'.join(f'pushd d{index} >/dev/null\nls\npopd >/dev/null'
                                   for index in range(8)),
                        '\n'.join(f'(cd d{index} && make)' for index in range(30))]:
            with self.subTest(command=command[:60]):
                start = time.monotonic()
                self.assertAllowed(command)
                self.assertLess(time.monotonic() - start, 4)
        # Folders a script may reach double at each cd that may fail; past
        # what the guard follows, it says how to make each step its own.
        start = time.monotonic()
        self.assertIn('(cd', self.assertDenied('\n'.join(f'cd d{index}; ls; cd ..'
                                                         for index in range(30))))
        self.assertLess(time.monotonic() - start, 4)
        # An exit inside if, a function or a pipeline does not end the
        # script, so the folder before the cd is still read from.
        home = Path(os.environ['HOME'])
        for command in ['if false; then cd /tmp || exit 1; fi\ncat .config/gh/../b*/*',
                        'f() { cd /tmp || exit 1; }\ncat .config/gh/../b*/*',
                        'cd /tmp || exit 1 | cat\ncat .config/gh/../b*/*',
                        'false && set -e\ncd /tmp\ncat .config/gh/../b*/*',
                        'set -e\nif cd /tmp; then ls; fi\ncat .config/gh/../b*/*']:
            with self.subTest(command=command):
                output = guard_output('Bash', {'command': command}, home, self.env)
                self.assertEqual(output and output['permissionDecision'], 'deny')
        output = guard_output('Bash', {'command': '(cd /tmp || exit 1)\ncat .config/gh/../b*/*'},
                              home, self.env)
        self.assertEqual(output and output['permissionDecision'], 'deny')

    def test_a_folder_reached_through_a_link_counts_once(self):
        # macOS keeps temporary folders behind a link (/var is /private/var).
        # Started in a folder named through a link, a cd to a folder that
        # is not there yet names one folder two ways, by its name and by
        # where the link leads, and the scripts above must still stay within
        # what the guard follows. A link before a .. still leads elsewhere,
        # and is still followed there.
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        linked = Path(outside.name, 'var')
        linked.symlink_to(self.folder, target_is_directory=True)
        repo = linked / self.repo.name
        for command in ['\n'.join(f'pushd d{index} >/dev/null\nls\npopd >/dev/null'
                                  for index in range(8)),
                        '\n'.join(f'cd d{index} || exit 1\nls' for index in range(8)),
                        'set -e\n' + '\n'.join(f'cd d{index}\nls\ncd ..' for index in range(8)),
                        '\n'.join(f'cd d{index} && make && cd ..' for index in range(8)),
                        '\n'.join(f'(cd d{index} && make)' for index in range(30))]:
            with self.subTest(command=command[:60]):
                start = time.monotonic()
                self.assertIsNone(guard_output('Bash', {'command': command}, repo, self.env),
                                  command)
                self.assertLess(time.monotonic() - start, 4)
        output = guard_output('Bash', {'command': '\n'.join(f'cd d{index}; ls; cd ..'
                                                            for index in range(30))},
                              repo, self.env)
        self.assertIn('(cd', output and output['permissionDecisionReason'])
        home = self.folder / 'home'
        (home / '.config' / 'gh').mkdir(parents=True)
        (home / 'l').symlink_to(home / '.config' / 'gh', target_is_directory=True)
        environment = {**self.env, 'HOME': str(home)}
        for cwd in (self.repo, repo):
            with self.subTest(cwd=cwd):
                output = guard_output('Bash', {'command': 'cd ~/l/../x && cat ../brickson/*'},
                                      cwd, environment)
                self.assertEqual(output and output['permissionDecision'], 'deny')

    def test_a_read_through_a_home_the_shell_finds_is_refused(self):
        # With HOME unset, bash takes ~ from the account; a HOME set from
        # ~+ or $PWD follows the folder; for, read and printf -v set it to
        # what the guard cannot read.
        environment = {**self.env, 'HOME': pwd.getpwuid(os.getuid()).pw_dir}
        for command in ['unset HOME; cat ~/.config/gh/../b*/*',
                        "env -u HOME bash -c 'cat ~/.config/gh/../b*/*'",
                        'unset HOME; cd ~/.config/gh && cat ../b*/*',
                        'cd ~/.config/gh && HOME=~+; cat ~/../b*/*',
                        'cd ~/.config/gh && HOME=$PWD; cat ~/../b*/*',
                        'cd ~/.config/gh && export HOME=~+; cat ~/../b*/*',
                        'cd ~/.config/gh && HOME=~+ bash -c "cat ~/../b*/*"',
                        'HOME=$(pwd) cat ~/.config/gh/../b*/*',
                        'for HOME in ~/.config/gh; do cat ~/../b*/*; done',
                        'printf -v HOME %s ~/.config/gh; cat ~/../b*/*',
                        'read -r HOME < path.txt; cat ~/../b*/*',
                        'mapfile -t HOME < path.txt; cat ~/../b*/*',
                        'read -a HOME < path.txt; cat ~/../b*/*',
                        'read -r GIT_DIR < path.txt; git commit --allow-empty -m x',
                        # An append, an assigning expansion and a nameref set it too.
                        'HOME+=/.config/gh; cat ~/../b*/*',
                        'export HOME+=/.config/gh; cat ~/../b*/*',
                        "HOME+=/.config/gh bash -c 'cat ~/../b*/*'",
                        ': ${XDG_CONFIG_HOME:=~/.config/gh}; cat "$XDG_CONFIG_HOME"/../b*/*',
                        ': ${HOME=~/.config/gh}; cat ~/../b*/*',
                        'declare -n r=HOME; r=~/.config/gh; cat ~/../b*/*']:
            with self.subTest(command=command):
                output = guard_output('Bash', {'command': command}, self.repo, environment)
                self.assertEqual(output and output['permissionDecision'], 'deny')
        # Names git never reads, a prompt or format operand, and $ in a
        # default value only read are not set.
        for command in ['for name in a b; do echo $name; done', 'read -r answer < path.txt',
                        'printf -v line %s x', 'cd ~/.config/gh && HOME=~+; cat ~/hosts.yml',
                        'read -r GIT_SHA < <(git rev-parse HEAD)',
                        'for GIT_FILE in docs/*.md; do echo "$GIT_FILE"; done',
                        'printf -v GIT_TAG "v%s" 1', 'printf "%s %s\\n" -v HOME',
                        "read -p 'GIT_DIR? ' answer", 'echo "${XDG_CONFIG_HOME:-~/.config}/gh"',
                        'A+=1; echo $A',
                        # A command's own assignment is not the HOME its ~ is.
                        'HOME+=/.config/gh cat ~/../b*/*']:
            with self.subTest(command=command):
                self.assertIsNone(guard_output('Bash', {'command': command}, self.repo,
                                               environment))

    def test_a_program_s_own_folder_option_is_read_in_every_spelling(self):
        # tar's -C in a cluster, --dir for --directory, and tar's old
        # first word (cfC) all move where it reads its operands.
        for command in ['tar -cC ~/.config/gh -f - ../b*', 'tar --dir ~/.config/gh -cf - ../b*',
                        'tar --direc=~/.config/gh -cf - ../b*', 'tar cfC - ~/.config/gh ../b*',
                        'tar -xvC ~/.config/gh -f x.tar ../b*']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        for command in ['tar -cC ~/.config/gh -f - hosts.yml', 'tar cf - docs',
                        'grep -nC 3 x README.md']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_find_s_folder_commands_run_beside_what_it_finds(self):
        # -execdir runs in each found file's folder: the start point's
        # parent for the start point itself.
        self.assertIn('--status', self.assertDenied(
            "find ~/.config/gh -maxdepth 0 -execdir sh -c 'cat b*/*' \\;"))
        self.assertAllowed("find docs -maxdepth 0 -execdir sh -c 'ls' \\;")

    def test_the_list_s_folder_is_found_whatever_its_case(self):
        # The Mac's file system finds ~/.config/Brickson at ~/.config/brickson.
        home = Path(os.environ['HOME'])
        for command in ['grep -r . ~/.config/Brickson', 'ls ~/.config/BRICKSON',
                        'cat ~/.Config/brickson/x', 'cd ~/.config/gh && grep -r . ../Brickson',
                        'cat ~/.config/brickson/Private-Words.txt']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        for name, arguments in [
                ('Read', {'file_path': str(home / '.config/Brickson/private-words.txt')}),
                ('Grep', {'pattern': '.', 'path': str(home / '.Config/brickson')})]:
            with self.subTest(name=name):
                self.assertEqual(self.tool(name, arguments), 'deny')
        self.assertAllowed('cat ~/.config/gh/Hosts.yml')

    def test_a_word_no_path_can_hold_does_not_stop_the_guard(self):
        # A NUL byte or a lone surrogate names no file; the guard decides.
        for command in ['ls a\x00b', 'ls \ud800', 'ls ~a\x00b', 'cd a\x00b && cat ../x']:
            with self.subTest(command=repr(command)):
                self.output(command)  # guard_output fails if the guard crashes
        for name, arguments in [('Read', {'file_path': 'a\x00b'}),
                                ('Grep', {'pattern': '.', 'path': '\ud800'})]:
            with self.subTest(name=name):
                self.tool(name, arguments)

    def test_git_settings_outside_the_tests_do_not_change_them(self):
        # A global core.hooksPath of .githooks, the cloud setup line, turns
        # the hook on in every repository; the tests must not see it.
        hostile = self.folder / 'global-config'
        hostile.write_text('[core]\n\thooksPath = .githooks\n')
        subprocess.run(['git', '-C', str(self.repo), 'config', '--unset', 'core.hooksPath'],
                       check=True)
        with patch.dict(os.environ, GIT_CONFIG_GLOBAL=str(hostile)):
            self.env = self.environment()
            self.assertIn('core.hooksPath .githooks',
                          self.assertDenied('git push origin claude/topic'))

    def test_a_file_the_same_command_writes_is_not_published(self):
        # The guard reads a file before the command runs, so a file the same
        # command writes would go out as written, unread.
        body = self.folder / 'body.md'
        body.write_text('ok\n')
        request = self.folder / 'request.json'
        request.write_text('{"body": "ok"}\n')
        (self.repo / 'message.txt').write_text('ok\n')
        (self.repo / 'notes.md').write_text('ok\n')
        name = shlex.quote(PRIVATE_NAME)
        api = 'https://api.github.com/repos/o/r/issues/1/comments'
        for command in [
                f"cat > {body} <<'EOF'\nThanks {PRIVATE_NAME}\nEOF\ngh pr comment 12 --body-file {body}",
                f"printf '%s\\n' {name} >> {body} && gh pr comment 12 -F {body}",
                f'echo {name} | tee -a {body} && gh issue create -t t --body-file={body}',
                f'cp {self.folder}/draft.md {body}; gh pr create -t t -F {body}',
                f'sed -i s/ok/x/ {body} && gh release create v1 --notes-file {body}',
                f"printf '%s\\n' {name} > message.txt && git commit -F message.txt",
                f"cat > notes.md <<'EOF'\n{PRIVATE_NAME}\nEOF\ngit add notes.md && git commit -m Add",
                f'echo {name} > notes.md; git commit -m Add -- notes.md',
                "python3 - <<'EOF'\nopen('notes.md', 'w').write('x')\nEOF\n"
                'git add notes.md && git commit -m Add',
                f'echo {name} > {request} && gh api -X POST repos/o/r/issues/1/comments --input {request}',
                f'echo {name} > {request}; curl -q -X POST {api} -d @{request}',
                # A redirection after a subshell or a group writes its target.
                f"(printf 'Summary\\n'; cat bad.md) > {body} && gh pr create -t t --body-file {body}",
                f'(cat bad.md) >> message.txt && git add notes.md && git commit -F message.txt']:
            with self.subTest(command=command):
                self.assertIn('in the next', self.assertDenied(command))
        # Written in an earlier command, it is read; writing another file is fine.
        self.assertAllowed(f'gh pr comment 12 --body-file {body}')
        self.assertAllowed(f'date > {self.folder}/when.txt && gh pr comment 12 -F {body} 2>&1')
        self.assertAllowed(f'echo done > {self.folder}/log.txt; git add notes.md && git commit -m Add')

    def test_a_here_document_the_shell_builds_is_not_published(self):
        # Without quotes round its delimiter, a here-document's $ and
        # backticks run before it is published, and what they give is unread.
        for command in ['gh pr comment 12 --body-file - <<EOF\nBy $(git log -1 --format=%an)\nEOF',
                        'gh pr comment 12 -F - <<EOF\nThanks $NAME\nEOF',
                        'git commit -F - <<EOF\nThanks ${NAME}\nEOF',
                        'git commit -F - <<EOF\nBy `whoami`\nEOF']:
            with self.subTest(command=command):
                self.assertIn('variable or another command', self.assertDenied(command))
        # Escaped, they are text.
        self.assertAllowed('git commit -F - <<EOF\nCosts \\$5 and \\`x\\`.\nEOF')
        self.assertDenied(f'git commit -F - <<EOF\nCosts \\$5, {PRIVATE_NAME}.\nEOF')

    def test_stdin_is_only_the_command_s_own_here_document(self):
        name = shlex.quote(PRIVATE_NAME)
        draft = self.folder / 'draft.md'
        for command in [f"cat > {draft} <<'EOF'\nsafe\nEOF\necho {name} | gh pr comment 12 -F -",
                        f"cat <<'EOF' > {draft}\nsafe\nEOF\ngit diff | git commit -F -",
                        "tr a-z A-Z <<'EOF' | gh pr comment 12 --body-file -\nsafe\nEOF",
                        "gh pr comment 12 -F - 3<<'EOF'\nsafe\nEOF"]:
            with self.subTest(command=command):
                self.assertIn('stdin', self.assertDenied(command))
        self.assertAllowed(f"cat > {draft} <<'EOF'\nsafe\nEOF\n"
                           "gh pr comment 12 -F - <<'EOF'\nok\nEOF")
        # A bare cat pipes its here-document in unchanged, and it is read.
        self.assertAllowed("cat <<'EOF' | gh pr comment 12 --body-file -\nok\nEOF")
        self.assertDenied(f"cat <<'EOF' | gh pr comment 12 --body-file -\n{PRIVATE_NAME}\nEOF")

    def test_a_substitution_is_never_a_published_value(self):
        for command in ['gh pr comment 12 -F <(cat notes.md)', 'git commit -F <(cat notes.md)',
                        'gh pr comment 12 --body-file=<(cat notes.md)',
                        'gh pr comment 12 --body $(git log -1 --format=%ae)',
                        'gh pr comment 12 -b$(cat notes.md)', 'git commit -m $(printf x)',
                        'gh pr create -t $((1 + 2)) -b ok']:
            with self.subTest(command=command):
                self.assertIn('variable or another command', self.assertDenied(command))
        # The words after a substitution still belong to its command.
        self.assertIn('gh pr create:1:', self.assertDenied(
            f'gh pr create --head $(git branch --show-current) -t t -b {shlex.quote(PRIVATE_NAME)}'))
        self.assertAllowed('gh pr create --head $(git branch --show-current) -t t -b ok')

    def test_an_attached_quoted_value_is_read_whole(self):
        # A quote that opens a word inside another (--body='a <b>') once
        # sent the guard back to splitting at spaces, losing the text.
        for command in [f"git commit --message='Thanks {PRIVATE_NAME} for <x>'",
                        f"gh pr comment 12 --body='Thanks {PRIVATE_NAME} for <x>'"]:
            with self.subTest(command=command):
                self.assertDenied(command)

    def test_escaped_dollars_and_backticks_in_double_quotes_are_text(self):
        for command in ['git commit -m "Fix \\`HomeLayout\\` spacing"',
                        'git commit -m "Costs \\$5 now"', 'gh pr create --title "Fix \\`x\\`" --body ok',
                        'gh pr review 12 -cb"Costs \\$5"']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.assertDenied(f'git commit -m "Thanks \\`{PRIVATE_NAME}\\`"')
        # An escaped backslash leaves the $ that follows it to the shell.
        self.assertIn('variable or another command', self.assertDenied('git commit -m "Costs \\\\$5"'))

    def test_a_raw_api_field_is_text_never_a_file(self):
        comments = 'gh api -X POST repos/o/r/issues/12/comments'
        self.assertAllowed(f"{comments} -f body='@coderabbitai review'")
        self.assertAllowed(f"{comments} --raw-field 'body=@coderabbitai review'")
        self.assertIn('gh api:1:', self.assertDenied(
            f'{comments} -f ' + shlex.quote('body=@' + PRIVATE_NAME)))
        # A typed field's @ still names a file, which must exist.
        self.assertIn('must exist', self.assertDenied(f'{comments} -F body=@missing.md'))

    def test_everything_a_commit_records_is_read(self):
        name = shlex.quote(PRIVATE_NAME)
        author = shlex.quote(PRIVATE_NAME + ' <q@example.com>')
        trailer = shlex.quote(f'Co-authored-by: {PRIVATE_NAME} <q@example.com>')
        # git keeps an address from the first < to the first >, without
        # spaces or quotes around it, and keeps a trailing dot, a comment,
        # a second address joined on or an accent.
        addresses = [shlex.quote(f'T {address}') for address in (
            f'<{PRIVATE_ADDRESS}>>', f'< {PRIVATE_ADDRESS} >', f'<"{PRIVATE_ADDRESS}">',
            f'<{PRIVATE_ADDRESS}.>', f'<ok@example.com+{PRIVATE_ADDRESS}>')]
        for command in [f'git commit -m Fix --trailer {trailer}', f'git commit -m Fix --trailer={trailer}',
                        f'git commit -m Fix --author={author}', f'git commit -m Fix --author {author}',
                        f'git commit -sm {name}', f'git commit -qm{name}',
                        f'git -c user.name={name} commit -m Fix',
                        f'GIT_AUTHOR_NAME={name} git commit -m Fix',
                        *(f'git commit -m Fix --author={address}' for address in addresses),
                        'git -c user.email=' + shlex.quote(f'{PRIVATE_ADDRESS} (home)')
                        + ' commit -m Fix',
                        'git -c user.email=' + shlex.quote(f'ok@example.com_{PRIVATE_ADDRESS}')
                        + ' commit -m Fix',
                        'GIT_AUTHOR_EMAIL=' + shlex.quote(PRIVATE_ADDRESS.replace('gmail', 'gmáil'))
                        + ' git commit -m Fix']:
            with self.subTest(command=command):
                self.assertDenied(command)
        # git takes a long option's unique beginning for the whole option.
        for command in [f'git commit --mess {name}', 'git commit --fil message.txt',
                        'git commit -m Fix --auth x']:
            with self.subTest(command=command):
                self.assertIn('Spell out', self.assertDenied(command))
        self.assertAllowed("git commit -sm 'Fix the layout' "
                           "--trailer 'Reviewed-by: Agent <noreply@anthropic.com>'")

    def test_gh_short_option_clusters_are_read_as_gh_reads_them(self):
        name = shlex.quote(PRIVATE_NAME)
        for command in [f'gh pr review 12 -cb {name}', f'gh pr create -dt {name} -b ok',
                        f'gh pr close 12 -dc {name}', f'gh release create v1 -dn {name}',
                        f'gh pr review 12 -cb={name}', f'gh issue comment 3 -eb {name}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed("gh pr create -dt 'Add a check' -b ok")

    def test_graphql_reads_publish_nothing(self):
        read = "gh api graphql -f query='query { viewer { login } }'"
        search = 'gh api graphql -f query=' + shlex.quote(
            f'query {{ search(query: "{PRIVATE_NAME}", type: ISSUE, first: 5) {{ issueCount }} }}')
        mutation = 'gh api graphql -f query=' + shlex.quote(
            f'mutation {{ addComment(input: {{subjectId: "X", body: "{PRIVATE_NAME}"}}) {{ clientMutationId }} }}')
        self.assertAllowed(read)
        self.assertAllowed(search)
        self.assertAllowed('curl -q https://api.github.com/graphql -d '
                           + shlex.quote(json.dumps({'query': '{ viewer { login } }'})))
        self.assertDenied(mutation)
        query = self.folder / 'query.graphql'
        query.write_text(f'mutation {{ addComment(input: {{subjectId: "X", body: "{PRIVATE_NAME}"}}) {{ id }} }}')
        self.assertDenied(f'gh api graphql -F query=@{query}')
        # Without a list, a read still runs and a write still does not.
        self.env.pop('BRICKSON_PRIVATE_WORDS')
        self.assertAllowed(read)
        self.assertIn('could not run', self.assertDenied(
            "gh api graphql -f query='mutation { addStar(input: {starrableId: \"X\"}) { clientMutationId } }'"))

    def test_a_request_file_is_data_not_shell_text(self):
        request = self.folder / 'request.json'
        request.write_text(json.dumps({'body': 'Fixed in `HomeLayout` for $5'}))
        api = 'https://api.github.com/repos/o/r/issues/1/comments'
        self.assertAllowed(f'curl -q -X POST {api} -d @{request}')
        self.assertAllowed(f'wget --no-config --post-file={request} {api}')
        request.write_text(json.dumps({'body': f'Thanks {PRIVATE_NAME}'}))
        self.assertDenied(f'curl -q -X POST {api} -d @{request}')
        # Words on the command line are still the shell's.
        self.assertIn('variable or another command', self.assertDenied(f'http POST {api} body="$X"'))

    def test_declared_exports_reach_the_push_check(self):
        for declare in ['declare -x', 'typeset -x', 'declare -gx']:
            with self.subTest(declare=declare):
                self.assertDenied(f'{declare} GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath '
                                  'GIT_CONFIG_VALUE_0=/dev/null; git push origin claude/topic')
        self.assertAllowed('declare -x LANG=C; git push origin claude/topic')

    def test_the_environment_is_never_printed_whole(self):
        # It may hold the list (BRICKSON_PRIVATE_WORDS, in a cloud session).
        for command in ['printenv', 'printenv | sort', 'env', 'env | grep -i words', 'env -0',
                        'sudo env', 'printenv > env.txt', 'export -p', 'export', 'declare -p',
                        'declare -x', 'typeset -px', 'set', 'set | less', 'cat /proc/self/environ',
                        "tr '\\0' '\\n' < /proc/$$/environ"]:
            with self.subTest(command=command):
                self.assertIn('whole environment', self.assertDenied(command))
        # Nor are globs that could reach the list.
        for command in ['cat ~/.config/brick*/private-words.txt', 'cat ~/.config/*/private-words.txt',
                        'ls ~/.config/*', 'grep -r x ~/.config/b*', 'cat "$XDG_CONFIG_HOME"/brickson/x',
                        'cat $XDG_CONFIG_HOME/*/*', 'declare -p BRICKSON_PRIVATE_WORDS']:
            with self.subTest(command=command):
                self.assertIn('--status', self.assertDenied(command))
        for command in ['printenv HOME', 'env FOO=1 git status', 'env -u FOO git status',
                        'set -euo pipefail', 'export FOO=1', 'declare -f', 'ls ~/.config/gh',
                        'cat ~/.config/*/hosts.yml']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_gist_given_no_files_publishes_stdin(self):
        # gh gist create with no file reads stdin (cat cool.txt | gh gist
        # create), as an explicit - does.
        self.assertDenied(f"gh gist create --public --filename note.md <<'EOF'\n"
                          f"Thanks {PRIVATE_NAME}\nEOF")
        self.assertIn('stdin', self.assertDenied('cat notes.md | gh gist create -d Notes'))
        self.assertAllowed("gh gist create --filename note.md <<'EOF'\nThanks to everyone\nEOF")

    def test_labels_and_gists_publish_their_names_and_descriptions(self):
        body = self.folder / 'body.md'
        body.write_text('ok\n')
        name = shlex.quote(PRIVATE_NAME)
        for command in [f'gh label create {name} --description x --color 000000',
                        f'gh label edit bug --description {name}', f'gh label edit bug -n {name}',
                        f'gh gist create --desc={name} {body}', f'gh gist create -d {name} {body}',
                        f"gh gist create -f {name} - <<'EOF'\nok\nEOF", f'gh gist edit abc123 -d {name}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        for command in [f"gh gist create -d 'Notes' {body}", f"gh gist create --desc 'Notes' -p {body}",
                        'gh gist edit abc123 -r old.md -d Notes', 'gh label create bug -c 000000 -d Bugs',
                        f'gh gist create {body} 2>/dev/null']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_keys_reverts_and_autolinks_gh_puts_on_github_are_read(self):
        # gh gpg-key add puts a key's user IDs on the account's public page
        # (github.com/<user>.gpg); gh ssh-key add and gh repo deploy-key add
        # send a key and its title; gh pr revert opens a pull request; an
        # autolink's prefix and address show in links. A key comes from its
        # file, or stdin with none.
        def armored_key(user_id):
            # A made-up public key packet (version 4, then zeros), then a user ID.
            packets = b''
            for tag, body in ((6, b'\x04' + bytes(4) + b'\x16' + bytes(34)),
                              (13, user_id.encode())):
                packets += bytes([0xc0 | tag, len(body)]) + body
            encoded = base64.b64encode(packets).decode()
            return ('-----BEGIN PGP PUBLIC KEY BLOCK-----\n\n'
                    + '\n'.join(encoded[at:at + 64] for at in range(0, len(encoded), 64))
                    + '\n-----END PGP PUBLIC KEY BLOCK-----\n')
        named_gpg, clean_gpg = self.folder / 'named.asc', self.folder / 'clean.asc'
        named_gpg.write_text(armored_key(f'{PRIVATE_NAME} <build@example.com>'))
        clean_gpg.write_text(armored_key('Build Bot <build@example.com>'))
        self.assertNotIn(PRIVATE_NAME, named_gpg.read_text())  # only inside the base64
        ssh_body = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGnZqIcD7oT0xG3m6nU5Hk4V2wq9yJbE1cLrPx8sMfTa'
        named_ssh, clean_ssh = self.folder / 'named.pub', self.folder / 'clean.pub'
        named_ssh.write_text(f'{ssh_body} {PRIVATE_NAME.replace(" ", "-").lower()}\n')
        clean_ssh.write_text(f'{ssh_body} build-bot\n')
        body = self.folder / 'revert.md'
        body.write_text(f'Thanks {PRIVATE_NAME}\n')
        named, quoted = PRIVATE_NAME.replace(' ', '-'), shlex.quote(PRIVATE_NAME)
        for command in [f'gh gpg-key add {named_gpg}', f'gh gpg-key add {clean_gpg} --title {quoted}',
                        f'gh gpg-key add -t {quoted} {clean_gpg}', f'gh gpg-key add - < {clean_gpg}',
                        f"gh gpg-key add <<'EOF'\n{armored_key(PRIVATE_NAME)}EOF",
                        f'cat {clean_gpg} | gh gpg-key add',
                        f'gh ssh-key add {named_ssh}', f'gh ssh-key add {named_ssh} --type signing',
                        f'gh ssh-key add --type signing -t {quoted} {clean_ssh}',
                        f'gh ssh-key add --title={quoted} {clean_ssh}',
                        f'gh repo deploy-key add {named_ssh} -R o/r',
                        f'gh repo deploy-key add -wt {quoted} {clean_ssh}',
                        f'gh repo deploy-key --title {quoted} add {clean_ssh}',
                        f'gh pr revert 12 --title {quoted}', f'gh pr revert 12 -b {quoted}',
                        f'gh pr revert 12 -dF {body}', f'gh pr revert --body-file={body} 12',
                        f"gh repo autolink create {named}- 'https://example.com/T?q=<num>'",
                        f"gh repo autolink new T- 'https://example.com/{named}?q=<num>' -n"]:
            with self.subTest(command=command[:60]):
                self.assertDenied(command)
        # A key file's folders stay here; only the key goes to GitHub.
        windows = 'C:/Us' + 'ers/tobble'
        (self.repo / windows).mkdir(parents=True)
        (self.repo / windows / 'id.pub').write_text(clean_ssh.read_text())
        for command in [f'gh gpg-key add {clean_gpg} --title "Build key"',
                        f"gh gpg-key add <<'EOF'\n{armored_key('Build Bot')}EOF",
                        f'gh ssh-key add {clean_ssh} -t Laptop --type signing',
                        f'gh ssh-key add --type signing {clean_ssh}',
                        f'gh ssh-key add {windows}/id.pub',
                        f'gh repo deploy-key add {clean_ssh} --allow-write --title CI',
                        'gh pr revert 12 --title "Revert the layout change" --body "It broke Home."',
                        "gh repo autolink create TICKET- 'https://example.com/TICKET?query=<num>'",
                        'gh gpg-key list', 'gh ssh-key list', 'gh repo deploy-key list',
                        'gh repo autolink list', 'gh secret set BUILD_NOTE --body clean',
                        # A secret's value is stored encrypted, never shown:
                        # how the private list reaches CI.
                        f'gh secret set BUILD_NOTE --body {quoted}']:
            with self.subTest(command=command[:60]):
                self.assertAllowed(command)

    def test_a_here_document_in_a_substitution_is_text(self):
        # "$(cat <<'EOF' ... EOF)" is how commit messages and bodies are
        # written: its body is text, never shell code, whatever it holds.
        template = (ROOT / '.github' / 'pull_request_template.md').read_text()
        for body in ["Don't stage everything",
                     'Follow docs/DECISIONS.md, "Personal details stay out of the repository"',
                     'The guard refuses `env`, `printenv`, `export` and `git add -A`.',
                     '$(git push --force origin main) is only text here', template]:
            with self.subTest(body=body[:20]):
                self.assertAllowed(f'git commit -m "$(cat <<\'EOF\'\n{body}\nEOF\n)"')
                self.assertAllowed('gh pr create --title "Add the privacy check" --body '
                                   f'"$(cat <<\'EOF\'\n{body}\nEOF\n)"')
        # Unquoted, it is text while it holds no $ or backtick.
        self.assertAllowed('git commit -m "$(cat <<EOF\nDon\'t stage everything\nEOF\n)"')
        self.assertIn('variable or another command', self.assertDenied(
            'git commit -m "$(cat <<EOF\nDon\'t, $USER\nEOF\n)"'))
        # Its text is still read, and the commands round it still checked.
        self.assertIn('the commit message:2:', self.assertDenied(
            f'git commit -m "$(cat <<\'EOF\'\nDon\'t forget\n{PRIVATE_NAME}\nEOF\n)"'))
        self.assertDenied('gh pr create --title t --body '
                          f'"$(cat <<\'EOF\'\n{template}\nThanks, "{PRIVATE_NAME}".\nEOF\n)"')
        self.assertIn('force', self.assertDenied(
            'git commit -m "$(cat <<\'EOF\'\nDon\'t\nEOF\n)" && git push --force origin claude/topic'))
        self.assertIn('whole environment', self.assertDenied(
            'git commit -m "$(cat <<EOF\n`env`\nEOF\n)"'))

    def test_backticks_in_literal_text_are_not_commands(self):
        for command in ["gh pr comment 12 --body 'The guard now refuses `env` with no command.'",
                        "git commit -m 'Refuse `printenv` and `export -p` in the guard'",
                        "echo 'cost is `set`'", "git commit -m 'Refuse `git add -A` in the guard'",
                        'git commit -m "Refuse \\`env\\` in the guard"']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        # Backticks the shell runs are still commands.
        for command in ['echo "cost is `env`"', 'echo `printenv`', 'git commit -m "Fix `git add -A`"']:
            with self.subTest(command=command):
                self.assertDenied(command)

    def test_redirections_are_not_git_arguments(self):
        (self.repo / 'a.txt').write_text('ok\n')
        for command in ['git add a.txt 2>/dev/null; git commit -m "Fix"',
                        'git add a.txt && git commit -m x > /dev/null',
                        'git add a.txt &>/dev/null && git commit -q -m "Fix" 2>/dev/null',
                        'git add a.txt && git commit -m "Fix" 2>&1 | tail -3',
                        f'git add a.txt && git commit -m "Fix" > {self.folder}/commit.log',
                        'git push origin claude/topic 2>&1 | tail -3',
                        'git push -u origin claude/topic >/dev/null 2>&1']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        (self.repo / 'a.txt').write_text(f'{PRIVATE_NAME}\n')
        self.assertIn('a.txt:1:1:', self.assertDenied(
            'git add a.txt 2>/dev/null && git commit -m "Fix" >/dev/null'))
        # A bare push from main still goes to main.
        self.git('checkout', '-q', 'main')
        self.git('branch', '-q', '--set-upstream-to=origin/main')
        for command in ['git push', 'git push 2>&1 | tail -3', 'git push 2>/dev/null',
                        f'git push > {self.folder}/push.log 2>&1']:
            with self.subTest(command=command):
                self.assertIn('Never push to main', self.assertDenied(command))

    def test_a_script_s_own_dash_is_not_inline_code(self):
        body = self.folder / 'body.md'
        body.write_text('ok\n')
        # The check AGENTS.md asks for before posting, chained with the post.
        self.assertAllowed(f'python3 scripts/privacy-check.py --text - < {body} && '
                           f'gh pr create --title "Add the check" --body-file {body}')
        self.assertAllowed(f'python3 scripts/privacy-check.py --text - < {body} && git commit -F {body}')
        # Inline code still may write anything, after an option's value too.
        for command in ["python3 -X dev -c 'open(\"notes.md\", \"w\")' && git add notes.md && git commit -m x",
                        f"python3 -c 'print(1)' && gh pr comment 12 -F {body}"]:
            with self.subTest(command=command):
                self.assertIn('in the next', self.assertDenied(command))

    def test_gh_aliases_and_reopen_comments_are_read(self):
        name = shlex.quote(PRIVATE_NAME)
        named = self.folder / 'notes.md'
        named.write_text(f'{PRIVATE_NAME}\n')
        for command in [f'gh pr new --title Add --body {name}', f'gh issue new --title {name}',
                        f'gh release new v1 --notes {name}', f'gh gist new {named}',
                        f'gh repo new r --description {name}', f'gh pr reopen 12 --comment {name}',
                        f'gh issue reopen 12 -c {name}']:
            with self.subTest(command=command):
                self.assertDenied(command)
        self.assertAllowed('gh pr reopen 12 --comment "Reopened for the fix"')
        self.assertAllowed('gh pr new --title Add --body "Fixes the layout"')

    def test_graphql_variables_cannot_make_a_write(self):
        self.assertAllowed("gh api graphql -f query='query($n:Int!){ repository(owner:\"o\",name:\"r\")"
                           "{ pullRequest(number:$n){ title } } }' -F n=$PR")
        self.assertIn('variable or another command', self.assertDenied(
            "gh api graphql -f query='mutation($b:String!){ addComment(input:{subjectId:\"X\",body:$b})"
            "{ clientMutationId } }' -F b=$BODY"))
        self.assertIn('variable or another command', self.assertDenied(
            'gh api graphql -f query="$QUERY" -F n=1'))

    def test_an_api_request_on_its_own_here_document_is_read(self):
        self.assertAllowed("gh api repos/o/r/issues/1/comments --input - <<'EOF'\n"
                           '{"body": "Thanks, fixed."}\nEOF')
        self.assertAllowed("gh api graphql --input - <<'EOF'\n"
                           '{"query": "query { viewer { login } }"}\nEOF')
        self.assertDenied("gh api repos/o/r/issues/1/comments --input - <<'EOF'\n"
                          + json.dumps({'body': PRIVATE_NAME}) + '\nEOF')
        self.assertDenied("gh api repos/o/r/pulls/1/reviews --input - <<'EOF'\n"
                          '{"event": "APPROVE"}\nEOF')
        self.assertIn('stdin', self.assertDenied('gh api repos/o/r/issues/1/comments --input -'))

    def test_a_change_to_the_index_in_the_same_command_is_not_committed(self):
        patch = self.folder / 'c.patch'
        patch.write_text('diff --git a/c.txt b/c.txt\nnew file mode 100644\n--- /dev/null\n'
                         f'+++ b/c.txt\n@@ -0,0 +1 @@\n+{PRIVATE_NAME}\n')
        other = self.folder / 'other'
        init_repository(other, 'main')
        for command in [f'git apply --cached {patch} && git commit -m "Add c"',
                        f'git apply --index {patch} && git commit -m x',
                        f'git apply -3 {patch} && git commit -m x',
                        'git stash pop --index && git commit -m "Restore work"',
                        'git stash apply && git commit -m x', f'git am {patch}; git commit -m x']:
            with self.subTest(command=command):
                self.assertIn('in the next', self.assertDenied(command))
        for command in [f'git apply --check {patch}', 'git stash list && git commit -m x',
                        f'git apply {patch} && git commit -m x',
                        f'git -C {other} apply --cached {patch} && git commit -m x']:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_a_copy_writes_only_its_destination(self):
        body = self.folder / 'body.md'
        body.write_text('ok\n')
        (self.repo / 'a.txt').write_text('ok\n')
        for command in [f'git add a.txt && git commit -m "Fix" && cp a.txt {self.folder}/a.bak',
                        f'gh pr create --title "Fix" --body-file {body} && cp {body} {self.folder}/posted.md',
                        f'cp a.txt {self.folder}/a.bak && git add a.txt && git commit -m "Fix"',
                        f'rsync -a {body} {self.folder}/backup/ && gh pr comment 12 -F {body}',
                        f'ln -s {body} {self.folder}/link.md && gh pr comment 12 -F {body}',
                        f'install -m 644 {body} {self.folder}/x.md && gh pr comment 12 -F {body}']:
            with self.subTest(command=command):
                self.assertAllowed(command)
        for command in [f'cp -t {self.folder} a.txt && gh pr comment 12 -F {body}',
                        f'cp --target-directory={self.folder} a.txt && gh pr comment 12 -F {body}',
                        f'ditto a.txt {body} && gh pr comment 12 -F {body}']:
            with self.subTest(command=command):
                self.assertIn('in the next', self.assertDenied(command))

    def test_a_gist_s_file_path_is_not_published(self):
        # gh puts each file in a gist under its base name; its folders stay here.
        # Built here, so this file holds no home folder of its own.
        windows = 'C:/Us' + 'ers/tobble'
        folder = self.repo / windows
        folder.mkdir(parents=True)
        (folder / 'notes.md').write_text('Build log\n')
        self.assertAllowed(f'gh gist create {windows}/notes.md')
        self.assertAllowed(f'gh gist create --desc "Build log" {windows}/notes.md')

    def test_a_gist_s_file_names_are_published(self):
        named = self.folder / (PRIVATE_NAME.replace(' ', '-').lower() + '-notes.md')
        named.write_text('notes\n')
        for command in [f'gh gist create {named}', f'gh gist edit abc123 --add {named}']:
            with self.subTest(command=command):
                self.assertDenied(command)

    def test_the_commit_identity_is_read(self):
        (self.repo / 'a.txt').write_text('ok\n')
        name, address = shlex.quote(PRIVATE_NAME), shlex.quote(PRIVATE_ADDRESS)
        # Set in the same command, it cannot be read before the command runs.
        for command in [f'git config user.name {name} && git commit -m x',
                        'git config user.email t@example.com; git commit -m x',
                        f'git config set user.name {name} && git commit -m x']:
            with self.subTest(command=command):
                self.assertIn('earlier command', self.assertDenied(command))
        # Set before, it is read where the commit runs.
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.com')
        self.assertAllowed('git add a.txt && git commit -m x')
        self.assertAllowed('git config user.name && git commit -m x')  # a read sets nothing
        for setting, value in [('user.name', PRIVATE_NAME), ('user.email', PRIVATE_ADDRESS)]:
            with self.subTest(setting=setting):
                self.git('config', setting, value)
                self.assertIn('the commit author', self.assertDenied('git commit -m x'))
                self.git('config', setting, 'test@example.com' if 'email' in setting else 'Test')
        self.assertDenied(f'GIT_AUTHOR_EMAIL={address} git commit -m x')
        self.assertDenied('GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name '
                          f'GIT_CONFIG_VALUE_0={name} git commit -m x')
        self.assertIn('variable or another command', self.assertDenied(
            'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0="$NAME" git commit -m x'))
        # GitHub's own addresses and the published support address are fine.
        self.git('config', 'user.email', '1+someone@users.noreply.github.com')
        self.assertAllowed('git commit -m x')
        support = 'help' + '@' + 'brickson-app' + '.dev'
        site = self.repo / 'site'
        site.mkdir()
        (site / 'index.html').write_text(f'<a href="mailto:{support}">Email</a>\n')
        self.git('config', 'user.email', support)
        self.assertAllowed('git commit -m x')
        self.git('config', 'user.email', 'other' + '@' + 'brickson-app' + '.dev')
        self.assertIn('the commit author', self.assertDenied('git commit -m x'))

    def test_the_tests_commit_as_a_made_up_person(self):
        # Where nothing names who commits, git makes up an address from the
        # machine's account and host name, and the guard refuses it: on a
        # Mac, every test that commits failed. The tests and the guards
        # they run commit as the tests' own made-up person, whatever the
        # machine or the caller's variables say.
        for environment in (os.environ, self.env):
            with self.subTest(environment='tests' if environment is os.environ else 'guard'):
                ident = subprocess.run(['git', '-C', str(self.repo), 'var', 'GIT_AUTHOR_IDENT'],
                                       env=environment, check=True, capture_output=True,
                                       text=True).stdout
                self.assertRegex(ident, r'^t <t@example\.com> ')
                self.assertFalse(set(IDENTITY_VARIABLES) & set(environment))

    def test_a_folder_the_shell_computes_is_named_as_unknown(self):
        reason = self.assertDenied('cd "$(git rev-parse --show-toplevel)" && git commit -m x')
        self.assertIn('cannot tell which folder', reason)
        self.assertNotIn('could not run', reason)

    def test_a_branch_without_the_hook_file_is_told_to_merge_main(self):
        (self.repo / '.githooks' / 'pre-push').unlink()
        reason = self.assertDenied('git push origin claude/topic')
        self.assertIn('merge origin/main', reason)
        self.assertNotIn('Never skip', reason)

    def test_the_hook_comes_from_the_checkout_not_the_branch_pushed(self):
        # Git runs .githooks from the checkout: a newer branch that has the
        # hook, pushed from a checkout of an older one that has none, would
        # go out unchecked.
        self.git('add', '-f', '.githooks/pre-push')
        self.git('commit', '-q', '-m', 'Add the hook')
        self.git('checkout', '-q', '-b', 'claude/older', 'main')
        self.assertFalse((self.repo / '.githooks' / 'pre-push').exists())
        reason = self.assertDenied('git push origin claude/topic')
        self.assertIn('checked out here', reason)
        self.assertIn('merge origin/main', reason)
        self.git('checkout', '-q', 'claude/topic')
        self.assertAllowed('git push origin claude/topic')


class SettingsTests(unittest.TestCase):
    """Unhooking the guard, or dropping a deny rule, must fail."""

    def setUp(self):
        self.settings = json.loads(SETTINGS.read_text())

    def test_the_guard_runs_before_bash_and_the_github_tools(self):
        import re
        groups = self.settings['hooks']['PreToolUse']
        tools = ['merge_pull_request', 'enable_pr_auto_merge', 'request_copilot_review',
                 'assign_copilot_to_issue', 'assign_copilot_to_issue_with_intent', 'create_pull_request_with_copilot',
                 'push_files', 'create_or_update_file', 'delete_file',
                 'pull_request_review_write', 'create_pull_request', 'update_pull_request',
                 'issue_write', 'create_issue', 'update_issue',
                 # The tools that publish text, for the privacy check.
                 'add_issue_comment', 'update_issue_comment',
                 'add_reply_to_pull_request_comment', 'add_comment_to_pending_review',
                 'create_gist', 'update_gist', 'create_branch',
                 # A new repository's name and description, and a fork's name.
                 'create_repository', 'fork_repository']
        # The file tools, so the private list stays closed wherever it lives.
        files = ['Read', 'Edit', 'MultiEdit', 'Write', 'NotebookEdit', 'Grep', 'Glob']
        for tool in ['Bash'] + [f'mcp__github__{t}' for t in tools] + files:
            commands = [hook['command'] for group in groups
                        if re.fullmatch(group['matcher'], tool)
                        for hook in group['hooks']]
            self.assertTrue(any('.claude/hooks/guard.py' in c for c in commands), tool)

    def test_policy_hook_failures_block_the_original_action(self):
        # Removing onFailure from any entry makes errors fail open.
        hooks = [hook for group in self.settings['hooks']['PreToolUse']
                 for hook in group['hooks']
                 if '.claude/hooks/guard.py' in hook.get('command', '')]
        self.assertEqual(len(hooks), 3)
        for index, hook in enumerate(hooks):
            with self.subTest(index=index):
                self.assertEqual(hook.get('onFailure'), 'block')

    def test_merging_and_copilot_tools_are_denied_outright(self):
        deny = set(self.settings['permissions']['deny'])
        for tool in ['merge_pull_request', 'enable_pr_auto_merge', 'request_copilot_review',
                     'assign_copilot_to_issue', 'create_pull_request_with_copilot']:
            self.assertIn(f'mcp__github__{tool}', deny)

    def test_the_private_list_cannot_be_opened_or_changed(self):
        # The list lives outside every checkout; Read and Edit never reach it
        # (docs/DECISIONS.md, "Personal details stay out of the repository").
        deny = set(self.settings['permissions']['deny'])
        for rule in ['Read(~/.config/brickson/**)', 'Edit(~/.config/brickson/**)']:
            self.assertIn(rule, deny)


if __name__ == '__main__':
    unittest.main()
