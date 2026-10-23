#!/usr/bin/env python3
"""Check the Claude Code guard in .claude/hooks/guard.py.

Run with python3 scripts/test-hooks.py; standard library only. scripts/test.sh
runs it before the unit tests, so CI runs it too. Each test feeds the guard
a tool call the way Claude Code does and reads its decision. Removing a rule
from the guard, or loosening one, fails a test here.
"""
import json
import shlex
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import os
from unittest.mock import patch

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
        for change in ['git checkout main', 'git switch main',
                       "bash -c 'git switch main'", '(git checkout main)']:
            self.assertDenied(f'{change} && git push')
            self.assertDenied(f'{change}; git push origin')
            self.assertDenied(f'{change} && git push origin HEAD')
            self.assertAllowed(f'{change} && git push origin HEAD:feature')
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
                subprocess.run(['git', 'init', '-q', '-b', branch, str(base / 'repo')], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', folder], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
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
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
            for substitution in ['$(git push origin)', '`git push origin`']:
                with self.subTest(substitution=substitution, outer='main'):
                    self.assertDenied(f'env -C {self.repo} sh -c "echo {substitution}"', cwd=other)
                with self.subTest(substitution=substitution, outer='feature'):
                    self.assertAllowed(f'env -C {other} sh -c "echo {substitution}"')
            self.assertDenied(f'env -C {other} sh -c "echo $(git status); git push origin"')

    def test_escaped_substitutions_in_child_scripts_stay_checked(self):
        with tempfile.TemporaryDirectory(dir=self.repo) as folder:
            other = Path(folder)
            subprocess.run(['git', 'init', '-q', '-b', 'main', str(other)], check=True)
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
                        'git commit -m .', 'git commit -m. -- docs/HANDOFF.md',
                        'git commit --file . -- docs/HANDOFF.md']:
            self.assertAllowed(command)

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
        for command in ['gh pr view 12', 'gh pr checks 12', 'gh pr create --fill',
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
                 'assign_copilot_to_issue', 'assign_copilot_to_issue_with_intent', 'create_pull_request_with_copilot',
                 'push_files', 'create_or_update_file', 'delete_file',
                 'pull_request_review_write', 'update_pull_request',
                 'issue_write', 'create_issue', 'update_issue']
        for tool in ['Bash'] + [f'mcp__github__{t}' for t in tools]:
            commands = [hook['command'] for group in groups
                        if re.fullmatch(group['matcher'], tool)
                        for hook in group['hooks']]
            self.assertTrue(any('.claude/hooks/guard.py' in c for c in commands), tool)

    def test_policy_hook_failures_block_the_original_action(self):
        # Removing onFailure from either entry makes errors fail open.
        hooks = [hook for group in self.settings['hooks']['PreToolUse']
                 for hook in group['hooks']
                 if '.claude/hooks/guard.py' in hook.get('command', '')]
        self.assertEqual(len(hooks), 2)
        for index, hook in enumerate(hooks):
            with self.subTest(index=index):
                self.assertEqual(hook.get('onFailure'), 'block')

    def test_merging_and_copilot_tools_are_denied_outright(self):
        deny = set(self.settings['permissions']['deny'])
        for tool in ['merge_pull_request', 'enable_pr_auto_merge', 'request_copilot_review',
                     'assign_copilot_to_issue', 'create_pull_request_with_copilot']:
            self.assertIn(f'mcp__github__{tool}', deny)


if __name__ == '__main__':
    unittest.main()
