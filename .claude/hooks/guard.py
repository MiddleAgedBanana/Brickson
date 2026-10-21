#!/usr/bin/env python3
"""Stop an agent from doing what AGENTS.md says only the owner does.

Claude Code runs this before every Bash command and before the GitHub tools
named in .claude/settings.json (AGENTS.md, "Guardrails for agents"). It reads
the tool call as JSON on standard input and, for a forbidden call, prints a
"deny" decision with the rule it breaks. Anything else passes through to the
normal permission flow untouched.

It denies:
- staging everything at once (git add -A, --all, -u, "." and git commit -a),
  because another agent's or the owner's uncommitted work would go in too;
- force pushes, and any push that would update main;
- merging a pull request or turning on auto-merge, by gh, the GitHub API or
  a GitHub tool, and approving one;
- the Copilot actions that spend the owner's credits;
- a GitHub tool that writes a file straight onto main.

This is a guard against mistakes, not a sandbox: a determined command can
get around it, and it covers Claude Code sessions only. Codex, Jules and the
owner are held to the same rules by review. Standard library only, so it
runs wherever python3 does. Its tests are scripts/test-hooks.py.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from urllib.parse import urlsplit

PROTECTED = {'main', 'master'}

STAGE_ALL = ('Stage only your own changes: name each path (git add <paths>). '
             'git add -A, --all, -u, "." and git commit -a would also take '
             "another agent's or the owner's uncommitted work "
             '(AGENTS.md, "Stage only your own changes").')
FORCE = ('Never force-push or rewrite pushed history; push a new commit instead '
         '(AGENTS.md, "Branches and pull requests").')
TO_MAIN = ('Never push to main. Push your <agent>/<topic> branch and open a pull '
           'request; the owner merges (AGENTS.md, "Branches and pull requests").')
MERGE = ('Agents never merge, approve or auto-merge a pull request: the owner '
         'merges (AGENTS.md, "Branches and pull requests"). Say in the thread '
         'that the pull request is ready, and whether its reviews are answered.')
COPILOT = ('Each Copilot review or Copilot task spends the owner\'s monthly AI '
           'credits, so only the owner starts one (AGENTS.md, "Build and test", '
           '"Reviews and updates on GitHub").')

WRAPPERS = {'command', 'builtin', 'exec', 'nohup', 'time', 'sudo', 'env', 'nice',
            'timeout', 'xargs', 'then', 'do', 'else', '!', '{', '('}
SHELLS = {'sh', 'bash', 'zsh', 'dash'}
SEPARATORS = {';', '&&', '||', '|', '&', '|&', '(', ')', '\n'}
# git options that take a separate value: git -C <path>, git -c <name=value>.
GIT_VALUE_OPTIONS = {'-C', '-c', '--git-dir', '--work-tree', '--namespace',
                     '--exec-path', '--config-env'}
# Short commit options that take a value, so a letter after them in the same
# cluster is that value, not an option (git commit -mall is a message).
COMMIT_VALUE_SHORT = set('mcCFtS')
# GitHub API paths and GraphQL mutations that merge, auto-merge or approve.
API_MERGE = re.compile(
    r'/pulls/[^/\s]+/merge\b|auto_merge|automerge|mergePullRequest|'
    r'enablePullRequestAutoMerge|mergeBranch|'
    r'event["\']?\s*[:=]\s*["\']?APPROVE', re.I)


def deny(reason):
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason,
    }}))
    sys.exit(0)


def segments(command):
    """Split a shell command into simple commands, as lists of words.
    Words inside $(...), `...` and sh -c '...' are split in turn."""
    lexer = shlex.shlex(command.replace('\\\n', ' '), posix=True,
                        punctuation_chars=';&|()\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    lexer.commenters = '#'
    current = []
    for word in lexer:
        if word in SEPARATORS or set(word) <= set(';&|()\n'):
            if current:
                yield current
            current = []
        else:
            current.append(word)
    if current:
        yield current


def nested(words):
    """Commands hidden inside words: $(...), backticks, and sh -c '...'."""
    found = []
    for word in words:
        found += re.findall(r'\$\(([^()]*(?:\([^()]*\)[^()]*)*)\)', word)
        found += re.findall(r'`([^`]*)`', word)
    if words and words[0] == 'eval':
        found.append(' '.join(words[1:]))
    elif words and os.path.basename(words[0]) in SHELLS:
        # sh -c 'script', also as a cluster such as bash -lc 'script'.
        for index, word in enumerate(words[1:-1], 1):
            if re.fullmatch(r'-[a-zA-Z]*c[a-zA-Z]*', word):
                found.append(words[index + 1])
                break
    return found


def strip_wrappers(words):
    """Drop VAR=value assignments and wrappers such as env, sudo, command."""
    while words:
        first = words[0]
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', first):
            words = words[1:]
        elif os.path.basename(first) in WRAPPERS:
            words = words[1:]
            # Options of the wrapper itself (env -i, timeout 5, nice -n 5).
            while words and (words[0].startswith('-') or words[0].isdigit()):
                words = words[1:]
        else:
            break
    return words


def git_parts(words, cwd):
    """For a git command: (subcommand, its arguments, working folder)."""
    index = 1
    while index < len(words):
        word = words[index]
        if word in GIT_VALUE_OPTIONS and index + 1 < len(words):
            if word == '-C':
                cwd = os.path.join(cwd, words[index + 1])
            index += 2
        elif word.startswith('-'):
            index += 1
        else:
            return word, words[index + 1:], cwd
    return None, [], cwd


def git(cwd, *args):
    try:
        result = subprocess.run(['git', '-C', cwd, *args], capture_output=True,
                                text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def branch_name(ref):
    ref = ref.lstrip('+')
    for prefix in ('refs/heads/', 'refs/remotes/origin/', 'origin/'):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return ref


def check_add(args):
    for arg in args:
        if arg == '--':
            break
        if arg in ('-A', '--all', '-u', '--update', '--no-ignore-removal'):
            deny(STAGE_ALL)
        if re.fullmatch(r'-[a-zA-Z]+', arg) and set(arg[1:]) & set('Au'):
            deny(STAGE_ALL)
    paths = [a for a in args if not a.startswith('-')]
    if any(p in ('.', './', ':/', ':', '*', ':/*') for p in paths):
        deny(STAGE_ALL)


def check_commit(args):
    for arg in args:
        if arg == '--':
            break
        if arg in ('--all', '-a'):
            deny(STAGE_ALL)
        if re.fullmatch(r'-[a-zA-Z]+', arg):
            for letter in arg[1:]:
                if letter == 'a':
                    deny(STAGE_ALL)
                if letter in COMMIT_VALUE_SHORT:
                    break


def check_push(args, cwd):
    refspecs = []
    options = []
    skip = False
    remote_given = False  # --repo names the remote instead of the first word
    for arg in args:
        if skip:
            skip = False
            continue
        if arg.startswith('--repo='):
            remote_given = True
        elif arg in ('-o', '--push-option', '--repo', '--receive-pack', '--exec'):
            remote_given = remote_given or arg == '--repo'
            skip = True
        elif arg.startswith('-'):
            options.append(arg)
        else:
            refspecs.append(arg)
    for option in options:
        if (option == '--force' or option.startswith(('--force-with-lease', '--force-if-includes'))
                or (re.fullmatch(r'-[a-zA-Z]+', option) and 'f' in option)):
            deny(FORCE)
        if option in ('--mirror', '--all', '--branches'):
            deny(TO_MAIN)  # these push every branch, main included
        if option in ('-d', '--delete'):
            # Deleting a branch: only refuse it for main.
            if any(branch_name(r) in PROTECTED for r in refspecs):
                deny(TO_MAIN)
    if not remote_given:
        refspecs = refspecs[1:]  # the first word is the remote
    if not refspecs:
        # A bare push goes wherever the branch pushes to.
        destination = git(cwd, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{push}')
        current = git(cwd, 'symbolic-ref', '--short', 'HEAD')
        for ref in (destination, current):
            if ref and branch_name(ref) in PROTECTED:
                deny(TO_MAIN)
        return
    for refspec in refspecs:
        if refspec.startswith('+'):
            deny(FORCE)
        if refspec == ':':
            deny(TO_MAIN)  # pushes every matching branch, main included
        source, colon, target = refspec.partition(':')
        destination = target if colon else source
        if destination in ('HEAD', '@', ''):
            destination = git(cwd, 'symbolic-ref', '--short', 'HEAD') or ''
        if branch_name(destination) in PROTECTED:
            deny(TO_MAIN)


def check_gh(words):
    words = [w for w in words[1:]]
    # gh's global option --repo/-R takes a value.
    plain = []
    skip = False
    for word in words:
        if skip:
            skip = False
        elif word in ('-R', '--repo', '--hostname'):
            skip = True
        elif word.startswith(('--repo=', '--hostname=')) or \
                (word.startswith('-R') and not plain):
            continue  # the attached forms, --repo=OWNER/REPO and -ROWNER/REPO
        else:
            plain.append(word)
    if plain[:2] == ['pr', 'merge']:
        deny(MERGE)
    if plain[:2] == ['pr', 'review'] and ({'-a', '--approve'} & set(plain)):
        deny(MERGE)
    if plain[:1] == ['api'] and API_MERGE.search(' '.join(plain)):
        deny(MERGE)
    if plain[:1] == ['api'] and copilot_review_request(' '.join(plain)):
        deny(COPILOT)
    if plain[:2] in (['pr', 'edit'], ['pr', 'create']) and any(
            'copilot' in w.lower() for w in plain if not w.startswith('-')):
        for index, word in enumerate(plain):
            if word in ('--add-reviewer', '--reviewer', '-r') and \
                    'copilot' in ' '.join(plain[index + 1:index + 2]).lower():
                deny(COPILOT)


def parsed_url(word):
    try:
        url = urlsplit(word if '://' in word else 'https://' + word)
        return url, (url.hostname or '').lower()
    except ValueError:
        return None, ''  # not an address, for example reviewers[]=name


def github_api_host(word):
    """Whether a word is a GitHub API address. The host is read from the
    parsed address, not searched for."""
    return parsed_url(word)[1] == 'api.github.com'


def github_api_merge(word):
    """Whether a word is a GitHub API address that merges, auto-merges or
    approves."""
    url, host = parsed_url(word)
    return host == 'api.github.com' and bool(API_MERGE.search(url.path))


def copilot_review_request(text):
    """Whether API arguments ask for a review from Copilot."""
    return 'requested_reviewers' in text and 'copilot' in text.lower()


def check_command(command, cwd, depth=0):
    if depth > 3:
        return
    try:
        parts = list(segments(command))
    except ValueError:
        # Unbalanced quotes: the shell would refuse it too. Look at the words.
        parts = [command.split()]
    for words in parts:
        unwrapped = strip_wrappers(words)
        # Look inside both forms: env bash -c '...' hides the shell behind env.
        for inner in dict.fromkeys(nested(words) + nested(unwrapped)):
            check_command(inner, cwd, depth + 1)
        words = unwrapped
        if not words:
            continue
        program = os.path.basename(words[0])
        if program == 'cd' and len(words) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(words[1]))
        elif program == 'git':
            subcommand, args, where = git_parts(words, cwd)
            if subcommand == 'add':
                check_add(args)
            elif subcommand == 'commit':
                check_commit(args)
            elif subcommand == 'push':
                check_push(args, where)
        elif program == 'gh':
            check_gh(words)
        elif program in ('curl', 'wget', 'http', 'https'):
            if any(github_api_merge(word) for word in words[1:]):
                deny(MERGE)
            if any(github_api_host(word) for word in words[1:]) and \
                    copilot_review_request(' '.join(words)):
                deny(COPILOT)


def check_github_tool(name, arguments):
    tool = name.rsplit('__', 1)[-1]
    if tool in ('merge_pull_request', 'enable_pr_auto_merge'):
        deny(MERGE)
    if tool in ('request_copilot_review', 'assign_copilot_to_issue',
                'create_pull_request_with_copilot'):
        deny(COPILOT)
    if tool in ('push_files', 'create_or_update_file', 'delete_file') and \
            branch_name(str(arguments.get('branch', ''))) in PROTECTED:
        deny(TO_MAIN)
    if tool == 'pull_request_review_write' and \
            str(arguments.get('event', '')).upper() == 'APPROVE':
        deny(MERGE)
    if tool == 'update_pull_request' and any(
            'copilot' in str(r).lower() for r in arguments.get('reviewers') or []):
        deny(COPILOT)


def main():
    try:
        call = json.load(sys.stdin)
    except ValueError:
        # Not a tool call this guard understands. Say so; deciding nothing
        # leaves the normal permission flow in charge.
        print('guard.py: could not read the tool call', file=sys.stderr)
        return
    if not isinstance(call, dict):
        return
    name = call.get('tool_name', '')
    arguments = call.get('tool_input') or {}
    cwd = call.get('cwd') or os.getcwd()
    if name == 'Bash':
        check_command(str(arguments.get('command', '')), cwd)
    elif name.startswith('mcp__'):
        check_github_tool(name, arguments)


if __name__ == '__main__':
    main()
