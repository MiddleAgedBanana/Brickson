#!/usr/bin/env python3
"""Stop an agent from doing what AGENTS.md says only the owner does.

Claude Code runs this before every Bash command and before the GitHub tools
named in .claude/settings.json (AGENTS.md, "Guardrails for agents"). It reads
the tool call as JSON on standard input and, for a forbidden call, prints a
"deny" decision with the rule it breaks. Anything else passes through to the
normal permission flow untouched.

It denies:
- staging everything at once (git add -A, --all, -u, "." and all-tree commits),
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
import fnmatch
import os
import re
import shlex
import subprocess
import sys
import stat
from urllib.parse import urlsplit

PROTECTED = {'main', 'master'}

STAGE_ALL = ('Stage only your own changes: name each path (git add <paths>). '
             'git add -A, --all, -u, "." and all-tree git commits would also take '
             "another agent's or the owner's uncommitted work "
             '(AGENTS.md, "Stage only your own changes").')
PATHSPEC_FILE = ('Name each add or commit path on the command line. The guard does not '
                 'interpret Git pathspec files, which can select every changed '
                 'file (AGENTS.md, "Stage only your own changes").')
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
UNKNOWN = ('The guard cannot inspect this push/sync destination or API request body. '
           'Use an explicit feature branch or a readable request file '
           '(AGENTS.md, "Guardrails for agents").')

WRAPPERS = {'command', 'builtin', 'exec', 'nohup', 'time', 'sudo', 'env', 'nice',
            'timeout', 'xargs', 'then', 'do', 'else', 'if', 'elif', 'while', 'until', '!', '{', '('}
WRAPPER_VALUE_OPTIONS = {
    'env': {'-u', '--unset', '-C', '--chdir'},
    'nice': {'-n', '--adjustment'},
    'xargs': {'-n', '-L', '-I', '-P', '-s', '-E', '-J', '-R', '-S', '-a', '-d',
              '--max-args', '--max-procs', '--max-chars', '--arg-file', '--delimiter'},
    'timeout': {'-k', '--kill-after', '-s', '--signal'},
    'sudo': {'-u', '--user', '-g', '--group', '-h', '--host', '-p', '--prompt',
             '-C', '--close-from', '-D', '--chdir', '-R', '--chroot'},
}
SHELLS = {'sh', 'bash', 'zsh', 'dash'}
SEPARATORS = {';', '&&', '||', '|', '&', '|&', '(', ')', '\n'}
# git options that take a separate value: git -C <path>, git -c <name=value>.
GIT_VALUE_OPTIONS = {'-C', '-c', '--git-dir', '--work-tree', '--namespace',
                     '--exec-path', '--config-env'}
# Short commit options that take a value, so a letter after them in the same
# cluster is that value, not an option (git commit -mall is a message).
COMMIT_VALUE_SHORT = set('mcCFtS')
COMMIT_VALUE_LONG = {'--message', '--file', '--reuse-message', '--reedit-message',
                     '--template', '--author', '--date', '--cleanup', '--fixup',
                     '--squash', '--trailer', '--pathspec-from-file'}
# Inspect GraphQL operation names only inside a query, never issue prose.
GRAPHQL_MERGE = re.compile(r'\b(?:mergePullRequest|enablePullRequestAutoMerge|mergeBranch)\s*\(')


def deny(reason):
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason,
    }}))
    sys.exit(0)


def without_shell_comments(command):
    """Remove comments only at word starts; hashes inside words are data."""
    result = []
    quote = None
    escaped = False
    word_start = True
    index = 0
    while index < len(command):
        char = command[index]
        if escaped:
            result.append(char)
            escaped = False
        elif char == '\\' and quote != "'":
            result.append(char)
            escaped = True
            word_start = False
        elif quote:
            result.append(char)
            if char == quote:
                quote = None
        elif char in ('"', "'"):
            result.append(char)
            quote = char
            word_start = False
        elif char == '#' and word_start:
            newline = command.find('\n', index)
            if newline < 0:
                break
            index = newline - 1
        else:
            result.append(char)
            word_start = char.isspace() or char in ';&|()'
        index += 1
    return ''.join(result)


def segments(command, preserve_quotes=False):
    """Split into (words, preceding separator), keeping && and || for cd.
    Words inside $(...), `...` and sh -c '...' are split in turn."""
    lexer = shlex.shlex(without_shell_comments(command.replace('\\\n', ' ')), posix=not preserve_quotes,
                        punctuation_chars=';&|()\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    lexer.commenters = ''
    current = []
    separator = ';'
    for word in lexer:
        if word in SEPARATORS or set(word) <= set(';&|()\n'):
            if current:
                yield current, separator
            current = []
            separator = word
        else:
            current.append(word)
    if current:
        yield current, separator


def nested(words):
    """Command substitutions evaluated by the surrounding shell."""
    found = []
    for word in words:
        found += re.findall(r'\$\(([^()]*(?:\([^()]*\)[^()]*)*)\)', word)
    # Unquoted backtick commands span several whitespace-separated words.
    found += re.findall(r'`([^`]*)`', ' '.join(words))
    return found


def shell_script_index(words):
    if words and os.path.basename(words[0]) in SHELLS:
        # sh -c 'script', also as a cluster such as bash -lc 'script'.
        for index, word in enumerate(words[1:-1], 1):
            if re.fullmatch(r'-[a-zA-Z]*c[a-zA-Z]*', word):
                return index + 1
    return None


def script_quote(raw_words, words, index):
    """Recognize a wholly quoted script; mixed shell quoting stays unknown."""
    if len(raw_words) != len(words):
        return None
    raw = raw_words[index]
    if raw.startswith('\"') and re.search(r'\\[$`]', raw):
        return None  # escaped substitutions need conservative child checks too
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ('\"', "'"):
        try:
            if shlex.split(raw) == [words[index]]:
                return raw[0]
        except ValueError:
            pass
    return None


def strip_wrappers(words, inherited=None):
    """Drop VAR=value assignments and wrappers such as env, sudo, command."""
    environment = dict(inherited or {})
    directories = []
    while words:
        first = words[0]
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', first):
            key, _, value = first.partition('=')
            if key.startswith('GIT_') or key == 'HOME':
                environment[key] = value
            words = words[1:]
        elif os.path.basename(first) in WRAPPERS:
            wrapper = os.path.basename(first)
            words = words[1:]
            directory = None
            while words and words[0].startswith('-'):
                option = words[0]
                if option == '--':
                    words = words[1:]
                    break
                if wrapper == 'env' and (option in ('-S', '--split-string')
                        or option.startswith(('-S', '--split-string='))):
                    separate = option in ('-S', '--split-string')
                    if separate and len(words) < 2:
                        deny(UNKNOWN)
                    value = words[1] if separate else (
                        option[2:] if option.startswith('-S') else option.partition('=')[2])
                    try:
                        words = shlex.split(value) + words[2 if separate else 1:]
                    except ValueError:
                        deny(UNKNOWN)
                    continue
                if wrapper == 'sudo':
                    if option in ('-D', '--chdir') and len(words) > 1:
                        directory = words[1]
                    elif option.startswith('--chdir='):
                        directory = option.partition('=')[2]
                    elif option.startswith('-D'):
                        directory = option[2:]
                if wrapper == 'env':
                    if option in ('-i', '--ignore-environment'):
                        environment = {key: None for key in set(os.environ) | set(environment)
                                       if key.startswith('GIT_') or key == 'HOME'}
                    elif option in ('-u', '--unset') and len(words) > 1:
                        environment[words[1]] = None
                    elif option.startswith('--unset='):
                        environment[option.partition('=')[2]] = None
                    elif option.startswith('-u'):
                        environment[option[2:]] = None
                    elif option in ('-C', '--chdir') and len(words) > 1:
                        directory = words[1]
                    elif option.startswith('--chdir='):
                        directory = option.partition('=')[2]
                    elif option.startswith('-C'):
                        directory = option[2:]
                count = 2 if option in WRAPPER_VALUE_OPTIONS.get(wrapper, set()) else 1
                words = words[count:]
            # One env uses its last -C; nested env commands change again.
            if directory is not None:
                directories.append(directory)
            # timeout's mandatory duration can be fractional and carry a unit.
            if wrapper == 'timeout' and words and re.fullmatch(r'(?:\d+(?:\.\d*)?|\.\d+)[smhd]?', words[0]):
                words = words[1:]
        else:
            break
    return words, environment, directories


def git_parts(words, cwd, environment):
    """Keep Git's global options for every read-only repository query."""
    index = 1
    while index < len(words):
        word = words[index]
        if word in GIT_VALUE_OPTIONS and index + 1 < len(words):
            index += 2
        elif word.startswith('-'):
            index += 1
        else:
            return word, words[index + 1:], (cwd, words[1:index], environment)
    return None, [], (cwd, words[1:], environment)


def git(context, *args):
    cwd, options, overrides = context
    environment = os.environ.copy()
    for key, value in overrides.items():
        if value is None:
            environment.pop(key, None)
        else:
            environment[key] = value
    try:
        result = subprocess.run(['git', '-C', cwd, *options, *args], capture_output=True,
                                text=True, timeout=5, env=environment)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def branch_name(ref):
    ref = ref.lstrip('+')
    for prefix in ('refs/heads/', 'refs/remotes/origin/', 'origin/'):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return ref


def all_tree_pathspec(path):
    return path in ('.', './', ':/', ':', '*', ':/*', './*', ':(top)',
                    ':(top)*', ':(glob)**', ':(top,glob)**')


def exclusion_pathspec(path):
    if path.startswith(':('):
        magic, close, _ = path[2:].partition(')')
        return bool(close) and 'exclude' in magic.split(',')
    return bool(re.match(r'^:[/!^]*[!^]', path))


def check_paths(paths):
    if any(all_tree_pathspec(p) for p in paths) or (paths and all(
            exclusion_pathspec(p) for p in paths)):
        deny(STAGE_ALL)


def check_add(args):
    for arg in args:
        if arg == '--':
            break
        if arg == '--pathspec-from-file' or arg.startswith('--pathspec-from-file='):
            deny(PATHSPEC_FILE)
        if arg in ('-A', '--all', '-u', '--update', '--no-ignore-removal'):
            deny(STAGE_ALL)
        if re.fullmatch(r'-[a-zA-Z]+', arg) and set(arg[1:]) & set('Au'):
            deny(STAGE_ALL)
    paths = [a for a in args if not a.startswith('-')]
    check_paths(paths)


def check_commit(args):
    paths = []
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            paths.extend(args[index + 1:])
            break
        if arg in ('--all', '-a'):
            deny(STAGE_ALL)
        if arg == '--pathspec-from-file' or arg.startswith('--pathspec-from-file='):
            deny(PATHSPEC_FILE)
        if arg in COMMIT_VALUE_LONG:
            index += 2
            continue
        if arg.startswith('-') and not arg.startswith('--'):
            for offset, letter in enumerate(arg[1:], 1):
                if letter == 'a':
                    deny(STAGE_ALL)
                if letter in COMMIT_VALUE_SHORT:
                    # -S's optional key must be attached; other values may
                    # follow separately. Message text is never a pathspec.
                    if offset == len(arg) - 1 and letter != 'S':
                        index += 1
                    break
        elif not arg.startswith('-'):
            paths.append(arg)
        index += 1
    check_paths(paths)


def check_push(args, context):
    refspecs = []
    options = []
    remote = None
    index = 0
    while index < len(args):
        arg = args[index]
        if arg.startswith('--repo='):
            remote = arg.partition('=')[2]
        elif arg in ('-o', '--push-option', '--repo', '--receive-pack', '--exec', '--recurse-submodules'):
            if arg == '--repo' and index + 1 < len(args):
                remote = args[index + 1]
            index += 1
        elif arg.startswith('-'):
            options.append(arg)
        else:
            refspecs.append(arg)
        index += 1
    if any(option == '--dry-run' or
           (re.fullmatch(r'-[a-zA-Z]+', option) and 'n' in option) for option in options):
        return  # Git computes the update but does not send it.
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
    if remote is None and refspecs:
        remote = refspecs.pop(0)
    if not refspecs:
        if git(context, 'rev-parse', '--git-dir') is None:
            deny(UNKNOWN)
        current = git(context, 'symbolic-ref', '--short', 'HEAD')
        if remote is None:
            remote = ((git(context, 'config', '--get', f'branch.{current}.pushRemote') if current else None)
                      or git(context, 'config', '--get', 'remote.pushDefault')
                      or (git(context, 'config', '--get', f'branch.{current}.remote') if current else None)
                      or 'origin')
        if git(context, 'config', '--bool', '--get', f'remote.{remote}.mirror') == 'true':
            deny(TO_MAIN)
        configured = git(context, 'config', '--get-all', f'remote.{remote}.push')
        if configured:
            refspecs = configured.splitlines()
        else:
            mode = git(context, 'config', '--get', 'push.default') or 'simple'
            if mode == 'matching':
                deny(TO_MAIN)
            if mode == 'nothing':
                return  # Git refuses this push itself.
            if current is None:
                deny(UNKNOWN)
            destinations = [current]
            # upstream/simple may target the configured upstream branch.
            if mode in ('simple', 'upstream', 'tracking'):
                destinations += (git(context, 'config', '--get-all',
                                     f'branch.{current}.merge') or '').splitlines()
            if any(branch_name(ref) in PROTECTED for ref in destinations):
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
            destination = git(context, 'symbolic-ref', '--short', 'HEAD')
            if destination is None:
                deny(UNKNOWN)
        if any(fnmatch.fnmatchcase(protected, branch_name(destination))
               or fnmatch.fnmatchcase('refs/heads/' + protected, destination)
               for protected in PROTECTED):
            deny(TO_MAIN)


def option_values(words, long_options, short_options=()):
    """Read separate, --long=value and -svalue option arguments."""
    for index, word in enumerate(words):
        option, equal, value = word.partition('=')
        if option in long_options or option in short_options:
            if equal:
                yield value
            elif index + 1 < len(words):
                yield words[index + 1]
        elif any(word.startswith(short) and len(word) > len(short) for short in short_options):
            yield word[2:].lstrip('=')


def request_file(filename, cwd):
    """Read a bounded regular file, never stdin, devices or a pipe."""
    if filename == '-':
        deny(UNKNOWN)
    path = os.path.join(cwd, os.path.expanduser(filename))
    try:
        metadata = os.stat(path)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > 1024 * 1024:
            deny(UNKNOWN)
        with open(path, encoding='utf-8') as payload:
            text = payload.read(1024 * 1024 + 1)
        if len(text) > 1024 * 1024:
            deny(UNKNOWN)
    except (OSError, UnicodeError):
        deny(UNKNOWN)
    try:
        # Decode JSON escapes before looking for action names or APPROVE.
        return json.dumps(json.loads(text))
    except ValueError:
        return text


def api_arguments(words, cwd, program='gh'):
    """Include the API clients' file-backed payloads in the same checks."""
    parts = [' '.join(words)]
    if program == 'gh':
        for filename in option_values(words, {'--input'}):
            parts.append(request_file(filename, cwd))
        for field in option_values(words, {'--field'}, {'-F'}):
            key, equals, value = field.partition('=')
            if equals and value.startswith('@'):
                parts.append('--raw-field ' + key + '=' + json.dumps(request_file(value[1:], cwd)))
    elif program == 'curl':
        for data in option_values(words, {'--data', '--data-ascii', '--data-binary', '--json'}, {'-d'}):
            if data.startswith('@'):
                parts.append(request_file(data[1:], cwd))
    elif program == 'wget':
        for filename in option_values(words, {'--post-file', '--body-file'}):
            parts.append(request_file(filename, cwd))
    return ' '.join(parts)


def check_gh(words, cwd):
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
                word.startswith('-R'):
            continue  # the attached forms, --repo=OWNER/REPO and -ROWNER/REPO
        else:
            plain.append(word)
    if len(plain) >= 2 and plain[0] in ('agent-task', 'agent-tasks', 'agent', 'agents') \
            and plain[1] == 'create':
        deny(COPILOT)
    if plain[:2] == ['repo', 'sync']:
        for word in plain[2:]:
            option, equal, value = word.partition('=')
            if option == '--force' and (not equal or value.lower() not in ('false', 'f', '0')):
                deny(FORCE)
        branches = list(option_values(plain[2:], {'--branch'}, {'-b'}))
        if not branches:
            deny(UNKNOWN)  # the remote source's default branch is not known
        if any(branch_name(branch) in PROTECTED for branch in branches):
            deny(TO_MAIN)
    if plain[:2] == ['pr', 'merge']:
        deny(MERGE)
    if plain[:2] == ['pr', 'review']:
        for word in plain[2:]:
            option, equal, value = word.partition('=')
            if option in ('-a', '--approve') and (not equal or value.lower() not in ('false', 'f', '0')):
                deny(MERGE)
    if plain[:1] == ['api']:
        arguments = api_arguments(plain, cwd)
        methods = list(option_values(plain, {'--method'}, {'-X'}))
        method = methods[-1].upper() if methods else (
            'POST' if list(option_values(plain, {'--field', '--raw-field', '--input'},
                                        {'-f', '-F'})) else 'GET')
        if merge_api_request(plain, arguments, method):
            deny(MERGE)
        if copilot_request(arguments):
            deny(COPILOT)
    if len(plain) >= 2 and plain[0] in ('pr', 'issue') and plain[1] in ('edit', 'create'):
        options = {'--add-assignee', '--assignee'}
        short = {'-a'} if plain[1] == 'create' else set()
        if plain[0] == 'pr':
            options |= {'--add-reviewer', '--reviewer'}
            short.add('-r')
        for value in option_values(plain[2:], options, short):
            if 'copilot' in value.lower():
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


def api_field_values(text, key):
    """Read one field from gh options and inline or file-backed JSON bodies."""
    decoder = json.JSONDecoder()
    pattern = (r'(?<!\S)(?P<option>-[fF]|--(?:raw-)?field)(?:\s+|=)?'
               + re.escape(key) + r'(?:\[\d*\])?=')
    for field in re.finditer(pattern, text):
        value = text[field.end():].lstrip()
        if value.startswith('@') and field['option'] in ('-F', '--field'):
            continue  # api_arguments appends this file's inspected contents.
        try:
            parsed, _ = decoder.raw_decode(value)
        except ValueError:
            parsed = value.split(None, 1)[0] if value else ''
        yield parsed
    for start in re.finditer(r'\{', text):
        try:
            payload, _ = decoder.raw_decode(text[start.start():])
        except ValueError:
            continue
        if isinstance(payload, dict) and key in payload:
            yield payload[key]


def has_api_endpoint(text, pattern):
    """Match endpoint paths without URL queries or fragments."""
    for word in text.split():
        if '://' in word or github_api_host(word):
            url, host = parsed_url(word)
            if host != 'api.github.com':
                continue
        elif word.startswith(('repos/', '/repos/')):
            url = urlsplit(word)
        else:
            continue
        if re.fullmatch(pattern, url.path.lstrip('/')):
            return True
    return False


def request_method(words, program):
    """The common API-client method forms; an explicit method wins."""
    methods = list(option_values(words, {'--request', '--method'}, {'-X'}))
    if methods:
        return methods[-1].upper()
    if program == 'curl':
        if '--get' in words or '-G' in words:
            return 'GET'
        if '--head' in words or '-I' in words:
            return 'HEAD'
        data = list(option_values(words, {'--data', '--data-ascii', '--data-binary',
                                         '--data-raw', '--data-urlencode', '--json', '--form'}, {'-d', '-F'}))
        return 'POST' if data else 'GET'
    if program in ('http', 'https') and len(words) > 1 and words[1].upper() in {
            'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'}:
        return words[1].upper()
    return 'POST' if any(w.startswith(('--post-', '--body-')) for w in words) else 'GET'


def merge_api_request(words, arguments, method):
    """Match actual endpoint arguments and request fields, not prose words."""
    paths = []
    for word in words:
        if github_api_host(word):
            paths.append(parsed_url(word)[0].path.lstrip('/'))
        elif word == 'graphql' or word.startswith(('repos/', '/repos/')):
            paths.append(urlsplit(word).path.lstrip('/'))
    if method == 'PUT' and any(re.fullmatch(r'repos/[^/]+/[^/]+/pulls/[^/]+/merge', p) for p in paths):
        return True
    if method not in ('GET', 'HEAD'):
        if any(re.fullmatch(r'repos/[^/]+/[^/]+/pulls/[^/]+/reviews', p) for p in paths):
            if any(str(v).upper() == 'APPROVE' for v in api_field_values(arguments, 'event')):
                return True
        if any(re.fullmatch(r'repos/[^/]+/[^/]+/merges', p) for p in paths):
            if any(branch_name(str(v)) in PROTECTED for v in api_field_values(arguments, 'base')):
                return True
    if 'graphql' in paths:
        queries = list(api_field_values(arguments, 'query'))
        # Direct gh fields retain spaces here, before flattening arguments.
        for field in option_values(words, {'--field', '--raw-field'}, {'-f', '-F'}):
            key, _, value = field.partition('=')
            if key == 'query' and not value.startswith('@'):
                queries.append(value)
        for query in queries:
            # GraphQL strings are data, even when they name a mutation.
            query = re.sub(r'"(?:\\.|[^"\\])*"', '""', str(query))
            if GRAPHQL_MERGE.search(query):
                return True
    return False


def copilot_request(text):
    """Whether API arguments request Copilot review or issue assignment."""
    if ('requested_reviewers' in text or '/assignees' in text) and 'copilot' in text.lower():
        return True
    # Issue create/update endpoints also accept assignees. Inspect that field
    # specifically: a body mentioning Copilot is not an assignment.
    endpoint = r'repos/[^/\s]+/[^/\s]+/issues(?:/\d+)?'
    return has_api_endpoint(text, endpoint) and any(
        'copilot' in str(value).lower() for value in api_field_values(text, 'assignees'))


def inspectable_here_documents(command):
    """Remove ordinary here-doc data; retain commands that really execute.

    This covers literal delimiters and direct shell receivers. Complex shell
    pipelines should use an explicit shell script rather than guessing context.
    """
    pattern = re.compile(r'''(?<!<)<<(?!<)(-?)[ \t]*(('[^']*'|"[^"]*"|\\?[A-Za-z_][\w.-]*))''')
    lines = command.splitlines(keepends=True)
    output = []
    index = 0
    while index < len(lines):
        line = without_shell_comments(lines[index])
        index += 1
        matches = []
        for match in pattern.finditer(line):
            try:
                shlex.split(''.join(output) + line[:match.start()])
            except ValueError:
                continue  # the operator is inside a quoted word
            matches.append(match)
        if not matches:
            output.append(lines[index - 1])
            continue
        header = line
        for match in reversed(matches):
            header = header[:match.start()] + header[match.end():]
        bodies = []
        for match in matches:
            raw = match[2]
            delimiter = shlex.split(raw)[0]
            quoted = any(char in raw for char in "'\"\\")
            body = []
            while index < len(lines):
                candidate = lines[index]
                index += 1
                if match[1]:
                    candidate = candidate.lstrip('\t')
                if candidate.rstrip('\r\n') == delimiter:
                    break
                body.append(candidate)
            bodies.append((''.join(body), quoted))
        parts = list(segments(header))
        shell_parts = [words for words, _ in parts
                       if (unwrapped := strip_wrappers(words)[0])
                       and os.path.basename(unwrapped[0]) in SHELLS]
        if shell_parts:
            if len(parts) != 1 or len(bodies) != 1:
                deny(UNKNOWN)
            body, quoted = bodies[0]
            if not quoted:
                expanded = re.sub(r'\\([$`\\])', lambda m: '\uffff' if m[1] != '\\' else '\\', body)
                for inner in nested([expanded]):
                    # Here-doc substitutions happen before the receiver's
                    # env/sudo directory change, in the surrounding shell.
                    output.append(inner + '\n')
                    body = body.replace('$(' + inner + ')', '').replace('`' + inner + '`', '')
            output.append(header.rstrip() + ' -c ' + shlex.quote(body) + '\n')
        else:
            output.append(header.rstrip() + '\n')
            for body, quoted in bodies:
                if not quoted:
                    # Escaped dollars/backticks in an unquoted here-doc are
                    # literal text, while unescaped substitutions execute.
                    body = re.sub(r'\\([$`\\])', lambda m: '\uffff' if m[1] != '\\' else '\\', body)
                    for inner in nested([body]):
                        output.append(inner + '\n')
    return ''.join(output)


def check_command(command, cwd, depth=0, environment=None):
    if depth > 3:
        return
    command = inspectable_here_documents(command)
    try:
        parts = list(segments(command))
        raw_parts = list(segments(command, preserve_quotes=True))
    except ValueError:
        # Unbalanced quotes: the shell would refuse it too. Look at the words.
        parts = [(command.split(), ';')]
        raw_parts = []
    # The shell can continue after a failed cd. Keep both outcomes until a
    # connector selects success (&&) or failure (||), instead of assuming cd
    # succeeded because its target looked like a directory during this check.
    states = {(cwd, True)}
    for part_index, (words, separator) in enumerate(parts):
        runnable = {(where, success) for where, success in states
                    if separator not in ('&&', '||')
                    or (separator == '&&' and success)
                    or (separator == '||' and not success)}
        next_states = states - runnable
        unwrapped, command_environment, directories = strip_wrappers(words, environment)
        if not unwrapped:
            continue
        program = os.path.basename(unwrapped[0])
        script_index = shell_script_index(unwrapped)
        outer_words = words
        script = unwrapped[script_index] if script_index is not None else None
        if script_index is not None:
            absolute_index = len(words) - len(unwrapped) + script_index
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            quote = script_quote(raw_words, words, absolute_index)
            if quote == "'":
                # Literal scripts are evaluated only by the invoked shell.
                outer_words = words[:absolute_index] + words[absolute_index + 1:]
            elif quote == '\"':
                # These substitutions run before env; inspect the remaining
                # child commands without evaluating those substitutions twice.
                for inner in nested([script]):
                    script = script.replace('$(' + inner + ')', '').replace('`' + inner + '`', '')
            # Unknown/mixed quoting is checked in both contexts conservatively.
        for where in {path for path, _ in runnable}:
            command_cwd = where
            for directory in directories:
                command_cwd = os.path.join(command_cwd, os.path.expanduser(directory))
            for inner in dict.fromkeys(nested(outer_words)):
                check_command(inner, where, depth + 1, environment)
            if script_index is not None:
                check_command(script, command_cwd, depth + 1,
                              command_environment)
            elif program == 'eval':
                check_command(' '.join(unwrapped[1:]), command_cwd, depth + 1,
                              command_environment)
            if program == 'cd':
                destination = unwrapped[1] if len(unwrapped) > 1 else (
                    command_environment.get('HOME', os.environ.get('HOME')))
                if destination is None:
                    next_states.add((where, False))
                    continue  # HOME unset: operandless cd fails.
                target = os.path.join(where, os.path.expanduser(destination))
                # Earlier shell commands may create the target, so inspect
                # both outcomes even when it does not exist at hook time.
                next_states.add((target, True))
                next_states.add((where, False))
                continue
            if program == 'git':
                subcommand, args, context = git_parts(unwrapped, command_cwd, command_environment)
                if subcommand == 'add':
                    check_add(args)
                elif subcommand == 'commit':
                    check_commit(args)
                elif subcommand == 'push':
                    check_push(args, context)
            elif program == 'gh':
                check_gh(unwrapped, command_cwd)
            elif program in ('curl', 'wget', 'http', 'https'):
                if any(github_api_host(word) for word in unwrapped[1:]):
                    arguments = api_arguments(unwrapped, command_cwd, program)
                    if merge_api_request(unwrapped, arguments, request_method(unwrapped, program)):
                        deny(MERGE)
                    if copilot_request(arguments):
                        deny(COPILOT)
            next_states.update({(where, True), (where, False)})
        states = next_states


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
