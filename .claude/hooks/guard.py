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
- a Copilot review or Copilot task asked for by a Copilot tool, gh, the
  REST API, a GitHub tool's reviewer or assignee field or a GraphQL agent
  assignment: Copilot is not part of the review process, and each one
  would spend the owner's credits (other GraphQL requests and an
  @copilot mention are held by AGENTS.md alone);
- a GitHub tool that writes a file straight onto main;
- publishing a personal detail: before a commit, and before text goes to
  GitHub through gh, the GitHub API or a GitHub tool, it runs
  scripts/privacy-check.py over what would be published (the message and
  trailers, the author and committer as git reads them, the staged changes
  and the files the command adds, the text sent) and refuses what it
  finds, naming places and kinds, never the words. What it cannot read
  before the command runs is refused too: text the shell builds from a
  variable or another command, stdin that is not a here-document given to
  that command, a file the same command writes, a change it makes to the
  index it commits (git apply --cached, am, stash pop), and a commit
  identity it sets. A push must run the privacy hook in .githooks/pre-push, which
  reads what the push carries; reading the private list, a glob that could
  reach it, and printing the whole environment, which may hold it, are
  refused.

This is a guard against mistakes, not a sandbox: a determined command can
get around it, and it covers Claude Code sessions only. Codex, Jules and the
owner are held to the same rules by review. Standard library only, so it
runs wherever python3 does. Its tests are scripts/test-hooks.py.
"""
import json
import fnmatch
import importlib.util
import os
import re
import shlex
import subprocess
import sys
import stat
import posixpath
from pathlib import Path
from urllib.parse import urlsplit, unquote

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
COPILOT = ('Copilot is not part of Brickson\'s reviews, and each Copilot review or '
           'Copilot task would spend the owner\'s AI credits, so agents never start '
           'one (AGENTS.md, "Build and test", "Reviews and updates on GitHub").')
UNKNOWN = ('The guard cannot inspect this push/sync destination or API request body. '
           'Use an explicit feature branch or a readable request file '
           '(AGENTS.md, "Guardrails for agents").')

WRAPPERS = {'command', 'builtin', 'exec', 'nohup', 'time', 'sudo', 'env', 'nice',
            'timeout', 'xargs', 'then', 'do', 'else', 'if', 'elif', 'while', 'until', '!', '{', '('}
WRAPPER_VALUE_OPTIONS = {
    'time': {'-o', '--output', '-f', '--format'},
    'env': {'-u', '--unset', '-C', '--chdir'},
    'nice': {'-n', '--adjustment'},
    'xargs': {'-n', '-L', '-I', '-P', '-s', '-E', '-J', '-R', '-S', '-a', '-d',
              '--max-args', '--max-procs', '--max-chars', '--arg-file', '--delimiter', '--process-slot-var'},
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
GRAPHQL_MERGE = re.compile(r'\b(?:mergePullRequest|enablePullRequestAutoMerge|enqueuePullRequest|mergeBranch)\s*\(')


CURL_CONFIG = ('The guard does not interpret curl configuration files. Put -q or '
               '--disable first, then use explicit command-line options so the '
               'API destination and method can be checked.')
WGET_CONFIG = ('The guard does not interpret Wget configuration or execute directives. '
               'Use --no-config and explicit command-line request options.')
SHELL_ALIAS = ('The guard does not execute Git shell aliases. Use the underlying '
               'command explicitly so its operation and repository can be checked.')
PRIVACY_DECISION = 'docs/DECISIONS.md, "Personal details stay out of the repository"'
PRIVATE = 'This would publish personal details: {places}. {advice}'  # advice cites the decision
PRIVATE_SETUP = ('The privacy check could not run, so nothing is published: {reason} ('
                 + PRIVACY_DECISION + ').')
HOOK_OFF = ('Pushes from this checkout must run the privacy hook, and this one does not. '
            'In your own clone, turn it on with git config core.hooksPath .githooks; in '
            "the owner's checkout or its worktrees, ask the owner to (" + PRIVACY_DECISION + ').')
NO_VERIFY = ('Never skip the privacy hook (--no-verify, or another core.hooksPath): it is '
             'the check that keeps personal details off GitHub (' + PRIVACY_DECISION + ').')
HOOK_MISSING = ('The branch checked out here has no .githooks/pre-push (it was made before the '
                'privacy check reached main), and git runs the hook in the checkout, whichever '
                'branch a push names, so this push would skip it without a word. Merge '
                'origin/main into the branch checked out here (git merge origin/main, a merge '
                'commit, never a rebase), then push again (' + PRIVACY_DECISION + ').')
UNKNOWN_FOLDER = ('The guard cannot tell which folder this git command runs in (a cd, -C or '
                  'chdir to a folder the shell computes, or a directory-stack entry), so it '
                  'cannot read what the command would commit or push. Use a literal path '
                  '(cd /path/to/checkout, or git -C /path/to/checkout).')
IDENTITY_SET = ('This command sets a commit identity (git config user.*, author.* or '
                'committer.*) and also commits, so the privacy check cannot read the author '
                'before the command runs. Set it in an earlier command, then commit ('
                + PRIVACY_DECISION + ').')
LIST_READ = ('The private list is the owner\'s and stays unread: check with python3 '
             'scripts/privacy-check.py --status, which never prints it (' + PRIVACY_DECISION + ').')
PUBLISHED_EXPANSION = ('Text this command publishes comes from a variable or another command, '
                       'which the privacy check cannot read. Write it in the command, in a '
                       "quoted here-document (\"$(cat <<'EOF' ... EOF)\", or <<'EOF' for "
                       'stdin), or in a file passed with -F, --file or --body-file.')
PUBLISHED_FILE = ('A file this command publishes must exist before the command runs, so the '
                  'privacy check can read it: write it in an earlier command.')
PUBLISHED_STDIN = ('Text this command reads from stdin can be checked only from a '
                   'here-document given to that command itself, not through a pipe or '
                   'another redirection; pass a file instead.')
WRITTEN_FILE = ('This command writes a file that it also publishes, sends or commits, so the '
                'privacy check would read the file before the command changes it. Write the '
                'file in one command, then publish or commit it in the next.')
ENVIRONMENT_DUMP = ('This would print the whole environment, which may hold the private list. '
                    'Name the variables you need instead (printenv HOME); the list is the '
                    "owner's and stays unread (" + PRIVACY_DECISION + ').')
# The list's own path and name, and the globs that could reach its file.
LIST_REFERENCE = re.compile(r'\.config/[^/\s]*brick|private-words|\$\{?BRICKSON_PRIVATE_WORDS'
                            r'|printenv\s+BRICKSON_PRIVATE_WORDS|XDG_CONFIG_HOME\}?["\']?/[^/\s]*brick'
                            r'|\b(?:declare|typeset)\b[^;&|\n]*\bBRICKSON_PRIVATE_WORDS\b')
CONFIG_FOLDER = re.compile(r'(?:\.config|XDG_CONFIG_HOME\}?)["\']?/([^/\s"\';&|()<>]*)'
                           r'(?:/([^/\s"\';&|()<>]*))?')
PROCESS_ENVIRONMENT = re.compile(r'/proc/\S*environ')
# The start of a here-document read with cat in a command substitution,
# $(cat <<'EOF', on a line of its own: its delimiter (quoted or not) and
# whether <<- strips the body's leading tabs.
SUBSTITUTED_HERE_DOCUMENT = re.compile(
    r"(?<!\\)\$\(\s*cat[ \t]+<<(-?)[ \t]*(?:'(\w+)'|\"(\w+)\"|(\w+))[ \t]*\r?\n")
# A $ that starts an expansion, or a backtick.
EXPANSION_START = re.compile(r'\$[A-Za-z_{(@*#?!$0-9-]|`')
PRIVACY_SECONDS = 6
# Here-documents fed to commands that are not shells: data, which the
# command they are given to may publish through stdin (git commit -F -,
# --body-file -). Each is a dict: its text as the shell passes it, whether
# the shell builds part of it, and whether it is that command's stdin. In
# the command, a marker word stands where its <<DELIMITER was, so that only
# that command reads it.
HERE_DOCUMENTS = []
HERE_MARK = ''
# An unquoted $(...) is kept whole inside its word while the command is
# split into words, as a quoted one is: split at its parentheses, it would
# leave its command an empty value and cut off the words after it.
SUBSTITUTION_MARK = ''
# Each $(cat <<'EOF' ... EOF) in a command, as written, stands as a marker
# while the command is split into words: its body is text (or, unquoted,
# text with substitutions the shell runs), never the shell's code, so a
# quote in it must not end or open one round it. The words hold it again
# once split.
DOCUMENT_MARK = '\ue002'
SUBSTITUTED_DOCUMENTS = []
# Files a request reads (curl -d @file, gh api --input): the same command
# must not write them first.
REQUEST_FILES = []
PRIVACY_SCRIPT = Path(__file__).resolve().parents[2] / 'scripts' / 'privacy-check.py'
# gh commands that put text on GitHub, with the options gh reads text from
# and those it reads a file of text from. A short option is its letter.
# Short options cluster as gh's flag parser reads them (-cb text): a
# letter not named here is a switch, and the first named one takes the
# rest of the word or the next word.
GH_PUBLISHES = {
    ('pr', 'create'): ({'--title', '--body', 't', 'b'}, {'--body-file', 'F'}),
    ('pr', 'edit'): ({'--title', '--body', 't', 'b'}, {'--body-file', 'F'}),
    ('pr', 'comment'): ({'--body', 'b'}, {'--body-file', 'F'}),
    ('pr', 'review'): ({'--body', 'b'}, {'--body-file', 'F'}),
    ('pr', 'close'): ({'--comment', 'c'}, set()),
    ('pr', 'reopen'): ({'--comment', 'c'}, set()),
    ('issue', 'create'): ({'--title', '--body', 't', 'b'}, {'--body-file', 'F'}),
    ('issue', 'edit'): ({'--title', '--body', 't', 'b'}, {'--body-file', 'F'}),
    ('issue', 'comment'): ({'--body', 'b'}, {'--body-file', 'F'}),
    ('issue', 'close'): ({'--comment', 'c'}, set()),
    ('issue', 'reopen'): ({'--comment', 'c'}, set()),
    ('release', 'create'): ({'--title', '--notes', 't', 'n'}, {'--notes-file', 'F'}),
    ('release', 'edit'): ({'--title', '--notes', 't', 'n'}, {'--notes-file', 'F'}),
    # A gist's files are its operands (gh gist edit's second), or stdin for -.
    ('gist', 'create'): ({'--desc', '--filename', 'd', 'f'}, set()),
    ('gist', 'edit'): ({'--desc', '--filename', 'd', 'f'}, {'--add', 'a'}),
    ('repo', 'create'): ({'--description', '--homepage', 'd', 'h'}, set()),
    ('repo', 'edit'): ({'--description', '--homepage', 'd', 'h'}, set()),
    # A label's name is its first operand.
    ('label', 'create'): ({'--description', '--color', 'd', 'c'}, set()),
    ('label', 'edit'): ({'--description', '--color', '--name', 'd', 'c', 'n'}, set()),
}
# Options of those commands that take a value which is not published, where
# their operands matter: gh gist edit --remove names a file to drop.
GH_OTHER_VALUES = {('gist', 'edit'): {'--remove', 'r'}}
# gh api's options that take a value.
GH_API_VALUES = {'--method', 'X', '--field', 'F', '--raw-field', 'f', '--input', '--header',
                 'H', '--jq', 'q', '--template', 't', '--preview', 'p', '--cache', '--hostname'}
# The shell's redirections; the word after each is a file or a descriptor.
REDIRECTIONS = {'>', '>>', '<', '<>', '>|', '>&', '<&', '&>', '&>>', '<<<'}
WRITE_REDIRECTIONS = {'>', '>>', '<>', '>|', '>&', '&>', '&>>'}
# Programs that write the files they are given.
FILE_WRITERS = {'tee', 'cp', 'mv', 'install', 'ln', 'rsync', 'ditto'}
INTERPRETERS = re.compile(r'(?:python[0-9.]*|node|ruby|perl|osascript)')
# The long options git commit takes, so that an abbreviation of one, which
# git accepts as the whole option, is refused (--mess is --message).
COMMIT_LONG = COMMIT_VALUE_LONG | {
    '--all', '--allow-empty', '--allow-empty-message', '--amend', '--branch', '--dry-run',
    '--edit', '--gpg-sign', '--include', '--interactive', '--long', '--no-edit',
    '--no-gpg-sign', '--no-post-rewrite', '--no-signoff', '--no-status', '--no-verify',
    '--null', '--only', '--patch', '--pathspec-file-nul', '--porcelain', '--quiet',
    '--reset-author', '--short', '--signoff', '--status', '--untracked-files', '--verbose',
    '--verify'}
# Settings and environment variables that name a commit's author or committer.
IDENTITY_SETTINGS = {'user.name', 'user.email', 'author.name', 'author.email',
                     'committer.name', 'committer.email'}
IDENTITY_VARIABLES = ('GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME',
                      'GIT_COMMITTER_EMAIL')
# GitHub tools whose text is published, and those that write files.
TOOLS_PUBLISH = {'create_pull_request', 'update_pull_request', 'issue_write', 'create_issue',
                 'update_issue', 'add_issue_comment', 'update_issue_comment',
                 'add_reply_to_pull_request_comment', 'add_comment_to_pending_review',
                 'pull_request_review_write', 'create_gist', 'update_gist',
                 'create_or_update_file', 'push_files', 'delete_file', 'create_branch'}


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


def substitution_end(text, start):
    """The index just past the ) that closes the $( before start, or None
    when it is not closed. Quotes, nested $( and ( are followed."""
    index, quote, stack = start, None, [None]
    while index < len(text) and stack:
        char = text[index]
        if char == '\\' and quote != "'":
            index += 2
            continue
        if text.startswith('$(', index) and quote != "'":
            stack.append(quote)
            quote = None
            index += 2
            continue
        if quote:
            if char == quote:
                quote = None
        elif char in ('"', "'", '`'):
            quote = char
        elif char == '(':
            stack.append(None)
        elif char == ')':
            quote = stack.pop()
        index += 1
    return None if stack else index


def substituted_documents(text):
    """(start, end, body, text, built) for each $(cat <<DELIMITER ... DELIMITER)
    in text that holds that here-document alone: its body as written (<<-'s
    leading tabs taken out), the text the shell gives for it (without the
    line breaks a substitution drops), and whether the shell builds part of
    it (an unescaped $ or backtick in a body whose delimiter is unquoted)."""
    found, index = [], 0
    while True:
        match = SUBSTITUTED_HERE_DOCUMENT.search(text, index)
        if match is None:
            return found
        index = match.end()
        delimiter, position = match[2] or match[3] or match[4], match.end()
        while position < len(text):
            stop = text.find('\n', position)
            stop = len(text) if stop < 0 else stop
            line = text[position:stop].rstrip('\r')
            if (line.lstrip('\t') if match[1] else line) == delimiter:
                closing = re.compile(r'\s*\)').match(text, stop)
                if closing:
                    body = text[match.end():position]
                    if match[1]:
                        body = ''.join(line.lstrip('\t') for line in body.splitlines(True))
                    given, built = here_document_text(body, match[4] is None)
                    found.append((match.start(), closing.end(), body, given.rstrip('\n'), built))
                    index = closing.end()
                break
            position = stop + 1


def marked_documents(command):
    """The command with a marker standing for each $(cat <<EOF ... EOF)."""
    output, last = [], 0
    for start, end, _, _, _ in substituted_documents(command):
        SUBSTITUTED_DOCUMENTS.append(command[start:end])
        output += [command[last:start],
                   f'{DOCUMENT_MARK}{len(SUBSTITUTED_DOCUMENTS) - 1}{DOCUMENT_MARK}']
        last = end
    return ''.join(output) + command[last:]


def unmarked(text):
    """text with each marker marked_documents stood in replaced by what it stands for."""
    if DOCUMENT_MARK not in text:
        return text
    return re.sub(DOCUMENT_MARK + r'(\d+)' + DOCUMENT_MARK,
                  lambda match: SUBSTITUTED_DOCUMENTS[int(match[1])], text)


def given_documents(text):
    """text with each $(cat <<EOF ... EOF) the shell gives as written
    replaced by what it gives."""
    for start, end, _, given, built in reversed(substituted_documents(text)):
        if not built:
            text = text[:start] + given + text[end:]
    return text


def without_documents(text, built=True):
    """text without each $(cat <<EOF ... EOF), or without those the shell
    gives as written (built=False)."""
    for start, end, _, _, is_built in reversed(substituted_documents(text)):
        if built or not is_built:
            text = text[:start] + text[end:]
    return text


def shell_backticks(text):
    """The commands in the backticks the shell runs in text, written as
    the command has it (quotes kept): not in single quotes, not escaped."""
    found, quote, start, index = [], None, None, 0
    while index < len(text):
        char = text[index]
        if char == '\\' and quote != "'":
            index += 2
            continue
        if start is not None:
            if char == '`':
                found.append(text[start:index])
                start = None
        elif quote == "'":
            if char == "'":
                quote = None
        elif char == '`':
            start = index + 1
        elif char == '"':
            quote = None if quote else '"'
        elif char == "'" and quote is None:
            quote = "'"
        index += 1
    return found


def protect_substitutions(command):
    """Stand a marker in for each unquoted, closed $(...), and return the
    command and what the markers stand for. The lexer would split one at
    its parentheses, leaving its command an empty value and cutting the
    words after it off from that command; kept whole, it stays in its word
    as a double-quoted one does, and nested() reads its command."""
    output, saved, index, quote = [], [], 0, None
    while index < len(command):
        char = command[index]
        if char == '\\' and quote != "'":
            output.append(command[index:index + 2])
            index += 2
            continue
        if quote:
            if char == quote:
                quote = None
        elif char in ('"', "'"):
            quote = char
        elif command.startswith('$(', index):
            end = substitution_end(command, index + 2)
            if end is not None:
                saved.append(command[index:end])
                output.append(f'{SUBSTITUTION_MARK}{len(saved) - 1}{SUBSTITUTION_MARK}')
                index = end
                continue
        output.append(char)
        index += 1
    return ''.join(output), saved


def segments(command, preserve_quotes=False):
    """Split into (words, preceding separator), keeping && and || for cd.
    Words inside $(...), `...` and sh -c '...' are split in turn."""
    text, saved = protect_substitutions(without_shell_comments(command.replace('\\\n', ' ')))
    lexer = shlex.shlex(text, posix=not preserve_quotes, punctuation_chars=';&|()<>\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    lexer.commenters = ''
    current = []
    separator = ';'
    marker = re.compile(SUBSTITUTION_MARK + r'(\d+)' + SUBSTITUTION_MARK)
    for word in lexer:
        if saved:
            word = marker.sub(lambda match: saved[int(match[1])], word)
        word = unmarked(word)
        if word in ('<(', '>('):
            if current:
                yield current, separator
            yield [word], ';'
            current, separator = [], ';'
            continue
        if word in SEPARATORS or set(word) <= set(';&|()\n'):
            if current:
                yield current, separator
            current = []
            for token in re.findall(r'&&|\|\||\|&|[;&|()\n]', word):
                if token in ('(', ')'):
                    yield [token], separator
                    separator = ';'
                else:
                    separator = token
        else:
            current.append(word)
    if current:
        yield current, separator


def ansi_c_quotes(command):
    """Normalize ANSI-C strings; refuse strings whose locale may change commands."""
    escapes = {'a': '\a', 'b': '\b', 'e': '\x1b', 'E': '\x1b', 'f': '\f',
               'n': '\n', 'r': '\r', 't': '\t', 'v': '\v',
               '\\': '\\', "'": "'", '"': '"', '?': '?'}
    def decode(match):
        value = match[1]
        if value in escapes:
            return escapes[value]
        if value.startswith('c'):
            return chr(127 if value[1] == '?' else ord(value[1].upper()) ^ 64)
        try:
            if value[0] in 'xuU' and len(value) > 1:
                number = int(value[1:], 16)
                return chr(number % 256 if value[0] == 'x' else number)
            if value[0] in '01234567':
                return chr(int(value, 8) % 256)
            return '\\' + value  # Bash retains unrecognized escapes.
        except (ValueError, OverflowError):
            deny(UNKNOWN)
    output, index, quote = [], 0, None
    while index < len(command):
        char = command[index]
        if char == '\\' and quote != "'":
            output.append(command[index:index + 2])
            index += 2
            continue
        if quote:
            output.append(char)
            if char == quote:
                quote = None
        elif command.startswith('$"', index):
            deny('Locale-translated shell strings cannot be inspected reliably. '
                 'Use ordinary quotes with explicit command text.')
        elif command.startswith("$'", index):
            stop = index + 2
            while stop < len(command):
                if command[stop] == '\\':
                    stop += 2
                elif command[stop] == "'":
                    break
                else:
                    stop += 1
            if stop >= len(command):
                deny(UNKNOWN)
            value = re.sub(r"\\(x[0-9a-fA-F]{1,2}|u[0-9a-fA-F]{1,4}|U[0-9a-fA-F]{1,8}|[0-7]{1,3}|c.|.)",
                           decode, command[index + 2:stop])
            # Bash strings end at a decoded NUL.
            output.append(shlex.quote(value.split('\0', 1)[0]))
            index = stop
        else:
            output.append(char)
            if char in ("'", '"'):
                quote = char
        index += 1
    return ''.join(output)


def nested(words, raw_words=None):
    """Read balanced command substitutions, including nested shell groups.
    A here-document read with cat is text, but for the substitutions an
    unquoted one runs. With the words as written (raw_words), backticks are
    read only where the shell runs them, not in single quotes."""
    found, plain = [], []
    for word in words:
        for start, end, body, _, built in reversed(substituted_documents(word)):
            if built:
                # Escaped dollars and backticks in it are text.
                found += nested([re.sub(r'\\([$`\\])',
                                        lambda m: '\uffff' if m[1] != '\\' else '\\', body)])
            word = word[:start] + word[end:]
        plain.append(word)
    for word in plain:
        cursor = 0
        while (start := word.find('$(', cursor)) >= 0:
            end = substitution_end(word, start + 2)
            if end is None:
                deny(UNKNOWN)
            found.append(word[start + 2:end - 1])
            cursor = end
    # Unquoted backtick commands span several whitespace-separated words.
    if raw_words is None:
        found += re.findall(r'`([^`]*)`', ' '.join(plain))
    else:
        found += shell_backticks(' '.join(without_documents(word) for word in raw_words))
    return found


def shell_script_index(words):
    if words and os.path.basename(words[0]) in SHELLS:
        # sh -c 'script', also as a cluster such as bash -lc 'script'.
        for index, word in enumerate(words[1:-1], 1):
            if re.fullmatch(r'-[a-zA-Z]*c[a-zA-Z]*', word):
                script = index + 1
                if words[script] == '--':
                    script += 1
                if script < len(words):
                    return script
    return None


def shell_reads_external_program(words):
    """Whether a shell without -c reads code from an uninspected file or stdin."""
    if not words or os.path.basename(words[0]) not in SHELLS:
        return False
    args, index, options = words[1:], 0, True
    while index < len(args):
        word = args[index]
        if word in ('<', '<>', '<&', '>', '>>', '>&'):
            index += 2
            continue
        if options and word in ('--help', '--version'):
            return False
        if options and word == '--':
            options = False
        elif options and word in ('-o', '+o', '-O', '+O', '--rcfile', '--init-file'):
            index += 1
        elif options and re.fullmatch(r'-[a-zA-Z]*s[a-zA-Z]*', word):
            return True  # -s treats remaining operands as positional parameters.
        elif options and word.startswith(('-', '+')) and word != '-':
            pass
        else:
            return True  # ordinary script files can also contain guarded actions
        index += 1
    return True


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


def context_variable(key):
    return key.startswith('GIT_') or key in ('HOME', 'GH_CONFIG_DIR', 'XDG_CONFIG_HOME', 'CDPATH')


def strip_wrappers(words, inherited=None, runtime_inputs=None):
    """Drop VAR=value assignments and wrappers such as env, sudo, command."""
    environment = dict(inherited or {})
    directories = []
    while words:
        # A shell may put file redirections before the executable or wrapper.
        redirect = 1 if words[0].isdigit() and len(words) > 1 else 0
        if words[redirect] in {'>', '>>', '<', '<>', '>|', '>&', '<&', '&>', '&>>'}:
            if len(words) <= redirect + 1:
                deny(UNKNOWN)
            words = words[redirect + 2:]
            continue
        first = words[0]
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', first):
            key, _, value = first.partition('=')
            if context_variable(key):
                environment[key] = value
            words = words[1:]
        elif os.path.basename(first) in WRAPPERS:
            wrapper = os.path.basename(first)
            if wrapper == 'xargs' and runtime_inputs is not None:
                runtime_inputs.append(True)
            words = words[1:]
            directory = None
            while words and words[0].startswith('-'):
                option = words[0]
                # Expand short clusters up to the first value-taking option.
                # Its remaining characters are an operand, never more flags.
                if len(option) > 2 and not option.startswith('--'):
                    value_flags = {flag[1] for flag in WRAPPER_VALUE_OPTIONS.get(wrapper, set())
                                   if len(flag) == 2 and flag.startswith('-')}
                    if wrapper == 'env':
                        value_flags.add('S')
                    expanded = []
                    for offset, letter in enumerate(option[1:], 1):
                        expanded.append('-' + letter)
                        if letter in value_flags:
                            if option[offset + 1:]:
                                expanded.append(option[offset + 1:])
                            break
                    words = expanded + words[1:]
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
                                       if context_variable(key)}
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
    if cwd is None:
        return None  # an inherited directory-stack destination is unknown
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
    if path.startswith(':('):
        magic, close, pattern = path[2:].partition(')')
        if not close or {'literal', 'exclude'} & set(magic.split(',')):
            return False
        path = pattern
    elif path.startswith(':/'):
        path = path[2:]
    while path.startswith('./'):
        path = path[2:]
    return path in ('', '.', ':') or bool(re.fullmatch(r'(?:\*\*/)*\*{1,2}', path))


def exclusion_pathspec(path):
    if path.startswith(':('):
        magic, close, _ = path[2:].partition(')')
        return bool(close) and 'exclude' in magic.split(',')
    return bool(re.match(r'^:[/!^]*[!^]', path))


def check_paths(paths):
    if any(path.startswith('~') or any(char in path for char in '$`{}') for path in paths):
        deny('Use literal staging paths; shell-expanded pathspecs may select the whole worktree.')
    if any(all_tree_pathspec(p) for p in paths) or (paths and all(
            exclusion_pathspec(p) for p in paths)):
        deny(STAGE_ALL)


def check_add(args):
    for arg in args:
        if arg == '--':
            break
        option = arg.split('=', 1)[0]
        if option.startswith('--') and '--pathspec-from-file'.startswith(option):
            deny(PATHSPEC_FILE)
        if option.startswith('--') and any(full.startswith(option) for full in
                ('--all', '--update', '--no-ignore-removal')):
            deny(STAGE_ALL)
        if arg in ('-A', '-u'):
            deny(STAGE_ALL)
        if re.fullmatch(r'-[a-zA-Z]+', arg) and set(arg[1:]) & set('Au'):
            deny(STAGE_ALL)
    paths = [a for a in args if not a.startswith('-')]
    check_paths(paths)


def add_forces(args):
    """Whether a git add is forced (-f, --force, or -f in a cluster), so
    it stages ignored files too."""
    for arg in args:
        if arg == '--':
            break
        if arg.startswith('--'):
            option = arg.partition('=')[0]
            if len(option) > 2 and '--force'.startswith(option):
                return True
        elif arg.startswith('-') and 'f' in arg[1:]:
            return True
    return False


def check_commit(args):
    paths = []
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            paths.extend(args[index + 1:])
            break
        # git takes a long option's unique beginning for the whole option.
        require_full_options(arg, COMMIT_LONG)
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
    return paths


def require_full_options(word, options):
    """Do not guess abbreviated spellings of options that affect policy."""
    option = word.partition('=')[0]
    if (option.startswith('--') and option != '--' and option not in options
            and any(full.startswith(option) for full in options)):
        deny('Spell out command options in full so the guard can inspect their effect.')


def check_push(args, context, branch_changed=False):
    refspecs = []
    options = []
    remote = None
    index = 0
    while index < len(args):
        arg = args[index]
        require_full_options(arg, {
            '--force', '--force-with-lease', '--force-if-includes', '--mirror',
            '--all', '--branches', '--delete', '--dry-run', '--no-dry-run',
            '--no-force', '--no-force-with-lease', '--no-force-if-includes',
            '--no-mirror', '--no-all', '--no-branches', '--no-delete',
            '--repo', '--push-option', '--receive-pack', '--exec', '--recurse-submodules',
            '--no-verify', '--verify',
        })
        if arg.startswith('--repo='):
            remote = arg.partition('=')[2]
        elif arg in ('-o', '--push-option', '--repo', '--receive-pack', '--exec', '--recurse-submodules'):
            if arg == '--repo' and index + 1 < len(args):
                remote = args[index + 1]
            index += 1
        elif arg.startswith('-') and not arg.startswith('--'):
            flags = []
            for offset, letter in enumerate(arg[1:], 1):
                if letter == 'o':
                    if offset == len(arg) - 1:
                        index += 1  # -o consumes the following word too
                    break
                flags.append(letter)
            if flags:
                options.append('-' + ''.join(flags))
        elif arg.startswith('-'):
            options.append(arg)
        else:
            refspecs.append(arg)
        index += 1
    dry_run = False
    for option in options:
        if option == '--no-dry-run':
            dry_run = False
        elif option == '--dry-run' or (re.fullmatch(r'-[a-zA-Z46]+', option) and 'n' in option):
            dry_run = True
    if any(value.startswith('~') or any(char in value for char in '$`{}')
           for value in [*refspecs, remote] if value):
        deny('Use literal push remotes and destinations; shell expansions are not inspected.')
    if dry_run:
        return  # Only the final setting determines whether Git sends updates.
    check_push_hook(options, context)
    for option in options:
        if (option == '--force' or option.startswith(('--force-with-lease', '--force-if-includes'))
                or (re.fullmatch(r'-[a-zA-Z46]+', option) and 'f' in option)):
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
        if branch_changed:
            deny(UNKNOWN)
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
            if branch_changed:
                deny(UNKNOWN)
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


def request_file(filename, cwd, git_state=None):
    """Read a bounded regular file, never devices or a pipe, and stdin only
    from the command's own here-document."""
    if filename == '-':
        number = (git_state or {}).get('stdin')
        if number is None:
            deny(UNKNOWN)
        if HERE_DOCUMENTS[number]['built']:
            deny(PUBLISHED_EXPANSION)
        text = HERE_DOCUMENTS[number]['text']
        try:
            return json.dumps(json.loads(text))
        except ValueError:
            return text
    REQUEST_FILES.append((cwd, filename))  # the same command must not write it first
    if cwd is None:
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


def api_arguments(words, cwd, program='gh', git_state=None):
    """Include the API clients' file-backed payloads in the same checks."""
    parts = [' '.join(words)]
    if program == 'gh':
        for filename in option_values(words, {'--input'}):
            parts.append(request_file(filename, cwd, git_state))
        for field in option_values(words, {'--field'}, {'-F'}):
            key, equals, value = field.partition('=')
            if equals and value.startswith('@'):
                parts.append('--raw-field ' + key + '=' + json.dumps(request_file(value[1:], cwd)))
    elif program == 'curl':
        for filename in option_values(words, {'--upload-file'}, {'-T'}):
            if (re.search(r'[{}\[\]]', filename)
                    and not curl_flag(words, {'--globoff', '-g'}, '--no-globoff')):
                deny(UNKNOWN)
            parts.append(request_file(filename, cwd))
        for options, shorts, files in [({'--form'}, {'-F'}, True),
                                       ({'--form-string'}, set(), False)]:
            for field in option_values(words, options, shorts):
                key, equal, value = field.partition('=')
                if equal:
                    if files and value.startswith(('@', '<')):
                        value = request_file(value[1:].split(';', 1)[0], cwd)
                    parts.append('--raw-field ' + key + '=' + json.dumps(value))
        for data in option_values(words, {'--data', '--data-ascii', '--data-binary', '--json'}, {'-d'}):
            if data.startswith('@'):
                parts.append(request_file(data[1:], cwd))
    elif program in ('http', 'https'):
        parts.append(httpie_body(words, cwd))
    elif program == 'wget':
        for filename in option_values(words, {'--post-file', '--body-file'}):
            parts.append(request_file(filename, cwd))
    return ' '.join(parts)


def expand_git_alias(subcommand, args, context):
    """Read plain aliases in the same Git context; never execute shell aliases."""
    seen = set()
    while subcommand:
        aliases = {value for key in ('alias.' + subcommand, 'alias.' + subcommand + '.command')
                   if (value := git(context, 'config', '--get', key))}
        if not aliases:
            return subcommand, args, context
        # Git ignores aliases that shadow its built-in commands.
        builtins = git(context, '--list-cmds=builtins')
        if builtins is None:
            deny(UNKNOWN)
        if subcommand in builtins.split():
            return subcommand, args, context
        if len(aliases) != 1:
            deny(UNKNOWN)  # conflicting spellings are not guessed
        alias = aliases.pop()
        if subcommand in seen or len(seen) >= 8:
            deny(UNKNOWN)
        seen.add(subcommand)
        if alias.startswith('!'):
            deny(SHELL_ALIAS)
        try:
            expanded = shlex.split(alias)
        except ValueError:
            deny(UNKNOWN)
        if not expanded:
            deny(UNKNOWN)
        cwd, options, environment = context
        subcommand, args, context = git_parts(
            ['git', *options, *expanded, *args], cwd, environment)
    return subcommand, args, context


def expand_gh_alias(words, cwd, inherited):
    """Read gh's selected aliases without executing an expansion.

    Shell or parameterized aliases require an explicit underlying command;
    interpreting their separate expansion language here would be a guess.
    """
    environment = os.environ.copy()
    for key, value in inherited.items():
        if value is None:
            environment.pop(key, None)
        else:
            environment[key] = value
    try:
        result = subprocess.run(['gh', 'alias', 'list'], cwd=cwd, env=environment,
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        deny(UNKNOWN)
    if result.returncode:
        if result.stderr.strip() == 'no aliases configured':
            return words
        deny(UNKNOWN)
    def scalar(value):
        # gh alias list emits YAML. Decode its ordinary single-line strings;
        # multiline or unsupported scalars require an explicit command.
        if value.startswith("'") and value.endswith("'"):
            return value[1:-1].replace("''", "'")
        if value.startswith('"'):
            try:
                decoded = json.loads(value)
                if isinstance(decoded, str):
                    return decoded
            except ValueError:
                pass
            deny(UNKNOWN)
        if value.startswith(('|', '>')):
            deny(UNKNOWN)
        return value
    aliases = {}
    for line in result.stdout.splitlines():
        key, colon, value = line.partition(': ')
        if not colon:
            deny(UNKNOWN)
        aliases[tuple(scalar(key).split())] = scalar(value)
    for _ in range(8):
        matches = [key for key in aliases if tuple(words[:len(key)]) == key]
        if not matches:
            return words
        key = max(matches, key=len)
        value = aliases[key]
        if value.startswith('!') or '$' in value or '`' in value:
            deny('Use the underlying gh command explicitly; the guard does not '
                 'interpret shell or parameterized gh aliases.')
        try:
            expansion = shlex.split(value)
        except ValueError:
            deny(UNKNOWN)
        if not expansion:
            deny(UNKNOWN)
        words = gh_command_words(expansion + words[len(key):])
    deny(UNKNOWN)


def gh_command_words(words):
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
    return plain


def check_gh(words, cwd, environment, git_state=None):
    plain = expand_gh_alias(gh_command_words(words[1:]), cwd, environment)
    # gh's own aliases: gh pr new is gh pr create, and so on.
    if len(plain) >= 2 and plain[0] in ('issue', 'pr', 'release', 'gist', 'repo') \
            and plain[1] == 'new':
        plain[1] = 'create'
    if git_state is not None:
        note_gh_text(plain, cwd, git_state)
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
        args, index = plain[2:], 0
        while index < len(args):
            word = args[index]
            if word == '--':
                break
            option, equal, value = word.partition('=')
            if option in ('-a', '--approve'):
                if not equal or value.lower() not in ('false', 'f', '0'):
                    deny(MERGE)
            elif option in ('--body', '--body-file'):
                if not equal:
                    index += 1
            elif word.startswith('-') and not word.startswith('--'):
                for offset, letter in enumerate(word[1:], 1):
                    if letter == 'a':
                        deny(MERGE)
                    if letter in ('b', 'F'):
                        if offset == len(word) - 1:
                            index += 1
                        break  # remaining characters are the body/file operand
            index += 1
    if plain[:1] == ['api']:
        arguments = api_arguments(plain, cwd, git_state=git_state)
        methods = list(option_values(plain, {'--method'}, {'-X'}))
        method = methods[-1].upper() if methods else (
            'POST' if list(option_values(plain, {'--field', '--raw-field', '--input'},
                                        {'-f', '-F'})) else 'GET')
        if protected_api_write(plain, arguments, method):
            deny(TO_MAIN)
        if merge_api_request(plain, arguments, method):
            deny(MERGE)
        if copilot_request(arguments, plain, method):
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


def without_redirections(words):
    """The words a program is given: the shell's redirections, and the file
    or descriptor each names, taken out."""
    kept, index = [], 0
    while index < len(words):
        if words[index] in REDIRECTIONS:
            index += 2
        elif (words[index].isdigit() and index + 1 < len(words)
              and words[index + 1] in REDIRECTIONS):
            index += 1  # 2>/dev/null: the 2 names a descriptor
        else:
            kept.append(words[index])
            index += 1
    return kept


def gh_arguments(args, value_options):
    """Read a gh command's words as gh's flag parser does: (option, value)
    for each option in value_options, and the operands. A short option is
    its letter, and short options cluster: a letter not in value_options is
    a switch, and the first one in it takes the rest of the word (after an
    optional =) or the next word, so -cb text gives b the text."""
    pairs, operands, index, options = [], [], 0, True
    args = without_redirections(args)
    while index < len(args):
        word = args[index]
        if not options or word == '-' or not word.startswith('-'):
            operands.append(word)
        elif word == '--':
            options = False
        elif word.startswith('--'):
            option, equal, value = word.partition('=')
            if option in value_options:
                if equal:
                    pairs.append((option, value))
                elif index + 1 < len(args):
                    index += 1
                    pairs.append((option, args[index]))
        else:
            for offset, letter in enumerate(word[1:], 1):
                if letter in value_options:
                    rest = word[offset + 1:]
                    if rest:
                        pairs.append((letter, rest[1:] if rest.startswith('=') else rest))
                    elif index + 1 < len(args):
                        index += 1
                        pairs.append((letter, args[index]))
                    break
        index += 1
    return pairs, operands


def note_gh_text(plain, cwd, git_state):
    """The text a gh command puts on GitHub: titles, bodies, comments,
    notes, descriptions and names, the files they come from, a gist's files
    and an API write's fields and input."""
    command = tuple(plain[:2])
    if command in GH_PUBLISHES:
        texts, files = GH_PUBLISHES[command]
        pairs, operands = gh_arguments(plain[2:], texts | files | GH_OTHER_VALUES.get(command, set()))
        values = [value for option, value in pairs if option in texts]
        names = [value for option, value in pairs if option in files]
        gist_files = []
        if command == ('gist', 'create'):
            # With no file named, gh reads the gist from stdin (gh gist
            # create --help: cat cool.txt | gh gist create).
            names += operands or ['-']
            gist_files = operands
        elif command == ('gist', 'edit'):
            names += operands[1:2]  # the first is the gist
            gist_files = [value for option, value in pairs if option in files]
        elif command[0] == 'label':
            values += operands[:1]
        note_published(git_state, 'gh ' + ' '.join(command), values, names, cwd)
        # A gist shows each file it is given under that file's name.
        note_published(git_state, 'gh ' + ' '.join(command) + ' file name',
                       texts=[posixpath.basename(name) for name in gist_files if name != '-'])
    elif command[:1] == ('api',):
        pairs, operands = gh_arguments(plain[1:], GH_API_VALUES)
        methods = [value for option, value in pairs if option in ('--method', 'X')]
        raw = [value for option, value in pairs if option in ('--raw-field', 'f')]
        typed = [value for option, value in pairs if option in ('--field', 'F')]
        inputs = [value for option, value in pairs if option == '--input']
        method = methods[-1].upper() if methods else ('POST' if raw or typed or inputs else 'GET')
        if method in ('GET', 'HEAD'):
            return
        # A raw field is always text; a typed field's @ names a file (gh api
        # --help), as --input does.
        values = [field.partition('=')[2] for field in raw]
        values += [field.partition('=')[2] for field in typed
                   if not field.partition('=')[2].startswith('@')]
        files = [field.partition('=')[2][1:] for field in typed
                 if field.partition('=')[2].startswith('@')] + inputs
        # A GraphQL request writes only through its query (a field, a file
        # or the input); its other fields are variables, which cannot make
        # a read a write.
        fields = [(field.partition('=')[0], field.partition('=')[2], kind)
                  for kind, group in (('raw', raw), ('typed', typed)) for field in group]
        query_texts = [value for key, value, kind in fields if key == 'query'
                       and not (kind == 'typed' and value.startswith('@'))]
        query_files = [value[1:] for key, value, kind in fields if key == 'query'
                       and kind == 'typed' and value.startswith('@')] + inputs
        if 'graphql' in api_paths(operands) and (query_texts or query_files) and graphql_read(
                [literal_text(value, git_state) for value in query_texts]
                + [text for name in query_files for text in published_files(name, cwd, git_state)]):
            return
        note_published(git_state, 'gh api', values, files, cwd)


def graphql_read(texts):
    """Whether a GraphQL request only reads: it writes only through a
    mutation, which needs the word, and none of its text (texts) holds it.
    A text the shell builds (None) could hold anything."""
    return None not in texts and not any(re.search(r'mutation', text, re.IGNORECASE)
                                         for text in texts)


def parsed_url(word):
    try:
        url = urlsplit(word if '://' in word else 'https://' + word)
        # API clients normally remove literal dot segments before sending.
        url = url._replace(path=posixpath.normpath(url.path))
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


def httpie_request(words):
    """Read method and request items after ordinary leading CLI options."""
    value_options = {'--auth', '-a', '--auth-type', '-A', '--session',
        '--session-read-only', '--verify', '--cert', '--cert-key', '--proxy',
        '--timeout', '--max-redirects', '--pretty', '--style', '--print', '-p',
        '--format-options', '--output', '-o', '--ssl', '--ciphers', '--raw',
        '--response-charset', '--response-mime', '--default-scheme'}
    index, method, raw = 1, None, None
    while index < len(words):
        word = words[index]
        if github_api_host(word):
            items = words[index + 1:]
            has_data = raw is not None or any(re.search(r'(?<![:=])(?::=|=)(?!=)', item)
                                               for item in items)
            return method or ('POST' if has_data else 'GET'), items, raw
        option, equal, value = word.partition('=')
        if option in value_options:
            if not equal:
                index += 1
                if index >= len(words):
                    deny(UNKNOWN)
                value = words[index]
            if option == '--raw':
                raw = value
        elif word.startswith('-'):
            pass  # flags or attached option values are not HTTP methods
        elif word.upper() in {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'}:
            method = word.upper()
        else:
            deny(UNKNOWN)  # do not guess a method after an unknown operand
        index += 1
    deny(UNKNOWN)


def httpie_body(words, cwd):
    _, items, raw = httpie_request(words)
    payload = {}
    if raw is not None:
        try:
            return json.dumps(json.loads(raw))
        except ValueError:
            deny(UNKNOWN)
    for item in items:
        match = re.fullmatch(r'([^:=@]+)(:=@|=@|:=|==|=|:|@)(.*)', item, re.S)
        if not match or match[2] in (':', '=='):
            continue  # headers and URL query parameters are not JSON fields
        key, operator, value = match.groups()
        if operator == '@':
            deny(UNKNOWN)  # file uploads need an explicit inspectable body
        if operator.endswith('@'):
            value = request_file(value, cwd)
        if operator.startswith(':='):
            try:
                value = json.loads(value)
            except ValueError:
                deny(UNKNOWN)
        if '[' in key:
            array = re.fullmatch(r'(\w+)\[(?:\d*)\]', key)
            if not array:
                deny(UNKNOWN)
            payload.setdefault(array[1], []).append(value)
        else:
            payload[key] = value
    return json.dumps(payload)


# curl short options stop clustering at the first option that takes a value.
# Keep that value opaque, even when it resembles another option.
CURL_VALUE_SHORT = set('EKCbcdDFPHhmoxUQreXYytzTuAw')
CURL_VALUE_OPTIONS = {'-' + flag for flag in CURL_VALUE_SHORT} | {
    '--request', '--header', '--data', '--data-ascii', '--data-binary',
    '--data-raw', '--data-urlencode', '--json', '--form', '--form-string',
    '--upload-file', '--url', '--output', '--user', '--proxy', '--proxy-user',
    '--connect-timeout', '--max-time', '--user-agent', '--referer', '--cookie',
    '--cookie-jar', '--config', '--cert', '--continue-at', '--dump-header',
    '--ftp-port', '--help', '--quote', '--range', '--speed-limit', '--speed-time',
    '--telnet-option', '--time-cond', '--write-out'}


def curl_words(words):
    normalized, operand = [words[0]], False
    for index, word in enumerate(words[1:], 1):
        if operand:
            if normalized[-1] == '--url':
                normalized.append(word)
            else:
                normalized[-1] += ('=' if normalized[-1].startswith('--') else '') + word
            operand = False
        elif word == '--':
            normalized.extend(words[index:])
            break
        elif word.startswith('--') or not word.startswith('-') or word == '-':
            normalized.append(word)
            operand = word in CURL_VALUE_OPTIONS
        else:
            for offset, flag in enumerate(word[1:], 1):
                normalized.append('-' + flag)
                if flag in CURL_VALUE_SHORT:
                    if word[offset + 1:]:
                        normalized[-1] += word[offset + 1:]
                    else:
                        operand = True
                    break
    return normalized


def http_operations(words):
    """curl --next resets request-local options; check each operation."""
    if os.path.basename(words[0]) != 'curl':
        return [words]
    operations, current, operand = [], [words[0]], False
    for word in words[1:]:
        if not operand and word in ('--next', '-:'):
            operations.append(current)
            current = [words[0]]
        else:
            current.append(word)
        operand = False if operand else word in CURL_VALUE_OPTIONS
    operations.append(current)
    return operations


def curl_flag(words, enabled, disabled):
    value = False
    for word in words:
        if word in enabled:
            value = True
        elif word == disabled:
            value = False
    return value


def httpie_stdin(words, original, separator, cwd):
    if '--ignore-stdin' in words:
        return words
    if separator in ('|', '|&') or any(word in ('<&', '<>', '<<<') for word in original):
        deny('Use HTTPie --raw or a bounded regular input file; pipe input is not inspectable.')
    sources = [original[index + 1] for index, word in enumerate(original[:-1])
               if word == '<' and (index == 0 or not original[index - 1].isdigit()
                                   or original[index - 1] == '0')]
    if sources:
        return [words[0], '--raw', request_file(sources[-1], cwd), *words[1:]]
    return words


def request_method(words, program):
    """The common API-client method forms; an explicit method wins."""
    methods = list(option_values(words, {'--request', '--method'}, {'-X'}))
    if methods:
        return methods[-1].upper()
    if program == 'curl':
        if list(option_values(words, {'--upload-file'}, {'-T'})):
            return 'PUT'
        if curl_flag(words, {'--head', '-I'}, '--no-head'):
            return 'HEAD'
        if curl_flag(words, {'--get', '-G'}, '--no-get'):
            return 'GET'
        data = list(option_values(words, {'--data', '--data-ascii', '--data-binary',
                                         '--data-raw', '--data-urlencode', '--json', '--form', '--form-string'}, {'-d', '-F'}))
        return 'POST' if data else 'GET'
    if program in ('http', 'https'):
        return httpie_request(words)[0]
    return 'POST' if any(w.startswith(('--post-', '--body-')) for w in words) else 'GET'


def graphql_variables(arguments, words):
    variables = {}
    for value in api_field_values(arguments, 'variables'):
        if isinstance(value, dict):
            variables.update(value)
    for field in option_values(words, {'--field', '--raw-field'}, {'-f', '-F'}):
        key, equal, value = field.partition('=')
        if equal and key != 'query' and not value.startswith('@'):
            try:
                variables[key] = json.loads(value)
            except ValueError:
                variables[key] = value
    return variables


def graphql_agent_assignment(query, arguments, words):
    mutations = r'(?:createIssue|updateIssue|addAssigneesToAssignable|replaceActorsForAssignable)'
    if not re.search(r'\b' + mutations + r'\s*\(', query):
        return False
    if re.search(r'\bagentAssignment\s*:(?!\s*null\b)', query):
        return True
    variables = graphql_variables(arguments, words)
    def contains_assignment(value):
        if isinstance(value, dict):
            return any((key == 'agentAssignment' and child is not None) or contains_assignment(child)
                       for key, child in value.items())
        return isinstance(value, list) and any(contains_assignment(child) for child in value)
    for match in re.finditer(r'\b' + mutations + r'\s*\(\s*input\s*:\s*\$(\w+)', query):
        if match[1] not in variables:
            deny(UNKNOWN)
        if contains_assignment(variables[match[1]]):
            return True
    return False


def graphql_review_approval(query, arguments, words):
    """Check the event of the two review mutations, including JSON variables."""
    variables = graphql_variables(arguments, words)
    for match in re.finditer(r'\b(?:addPullRequestReview|submitPullRequestReview)\s*\(', query):
        start = match.end()
        end, depth = start, 1
        while end < len(query) and depth:
            depth += (query[end] == '(') - (query[end] == ')')
            end += 1
        body = query[start:end - 1]
        input_variable = re.search(r'\binput\s*:\s*\$(\w+)', body)
        if input_variable:
            value = variables.get(input_variable[1])
            if not isinstance(value, dict):
                deny(UNKNOWN)
            event = value.get('event')
        else:
            event_match = re.search(r'\bevent\s*:\s*(\$?\w+)', body)
            event = event_match[1] if event_match else None
            if event and event.startswith('$'):
                if event[1:] not in variables:
                    deny(UNKNOWN)
                event = variables[event[1:]]
        if event == 'APPROVE':
            return True
    return False


def api_paths(words):
    paths = []
    for word in words:
        if github_api_host(word):
            paths.append(parsed_url(word)[0].path.lstrip('/'))
        elif word == 'graphql' or word.startswith(('repos/', '/repos/', 'agents/', '/agents/')):
            paths.append(urlsplit(word).path.lstrip('/'))
    return [unquote(path) for path in paths]


def protected_api_write(words, arguments, method):
    if method in ('GET', 'HEAD'):
        return False
    for path in api_paths(words):
        if re.fullmatch(r'repos/[^/]+/[^/]+/contents/.+', path):
            branches = list(api_field_values(arguments, 'branch'))
            if not branches or any(not isinstance(branch, str) or not branch.strip()
                                   for branch in branches):
                deny(UNKNOWN)  # Missing/null branch writes the unknown remote default.
            if any(branch_name(str(branch)) in PROTECTED for branch in branches):
                return True
        match = re.fullmatch(r'repos/[^/]+/[^/]+/git/refs(?:/(.+))?', path)
        if match:
            refs = [match[1]] if match[1] else list(api_field_values(arguments, 'ref'))
            if not refs:
                deny(UNKNOWN)
            if any(str(ref).removeprefix('refs/').removeprefix('heads/') in PROTECTED for ref in refs):
                return True
    return False


def merge_api_request(words, arguments, method):
    """Match actual endpoint arguments and request fields, not prose words."""
    paths = api_paths(words)
    if method == 'PUT' and any(re.fullmatch(r'repos/[^/]+/[^/]+/pulls/[^/]+/merge(?:-async)?', p) for p in paths):
        return True
    if method not in ('GET', 'HEAD'):
        if any(re.fullmatch(r'repos/[^/]+/[^/]+/pulls/[^/]+/reviews(?:/[^/]+/events)?', p) for p in paths):
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
            query = re.sub(r'#[^\n]*', '', query)
            if re.search(r'\b(?:createRef|updateRef|updateRefs|deleteRef|createCommitOnBranch)\s*\(', query):
                deny('Use explicit Git commands for ref or commit writes; the guard '
                     'does not resolve GraphQL ref IDs or variable targets.')
            if graphql_agent_assignment(query, arguments, words):
                deny(COPILOT)
            if GRAPHQL_MERGE.search(query) or graphql_review_approval(query, arguments, words):
                return True
    return False


def copilot_request(text, words=(), method='GET'):
    """Whether API arguments request Copilot review or issue assignment."""
    paths = api_paths(words)
    if method == 'POST' and any(re.fullmatch(r'agents/repos/[^/]+/[^/]+/tasks', path)
                                for path in paths):
        return True
    if any(path.endswith(('/requested_reviewers', '/assignees')) for path in paths) and 'copilot' in text.lower():
        return True
    # Issue create/update endpoints also accept assignees. Inspect that field
    # specifically: a body mentioning Copilot is not an assignment.
    endpoint = r'repos/[^/\s]+/[^/\s]+/issues(?:/\d+)?'
    return any(re.fullmatch(endpoint, path) for path in paths) and any(
        'copilot' in str(value).lower()
        for field in ('assignee', 'assignees') for value in api_field_values(text, field))


def trap_action(words):
    """Inspect literal trap actions; their eventual working directory is unknown."""
    args = words[1:]
    if args[:1] == ['--']:
        args = args[1:]
    if not args or args[0] in ('-p', '-l', '-lp', '-pl'):
        return None  # display registered actions or signal names
    if len(args) < 2 or args[0] in ('', '-'):
        return None  # reset or ignore, without registering command text
    if args[0].startswith('-') or any(char in args[0] for char in '$`'):
        deny('Use a literal trap action; dynamically supplied command text is not inspected.')
    return args[0]


def inspectable_here_documents(command):
    """Remove ordinary here-doc data; retain commands that really execute.

    This covers literal delimiters and direct shell receivers. Complex shell
    pipelines should use an explicit shell script rather than guessing context.
    """
    pattern = re.compile(r"""(?<!<)<<(?!<)(-?)[ \t]*((?:'[^']*'|"(?:\\.|[^"\\])*"|\\.|[^\s;&|()<>"'\\])+)""")
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
            delimiter = shlex.split(ansi_c_quotes(raw))[0]
            quoted = any(char in raw for char in "'\"\\")
            # 3<<EOF feeds descriptor 3, not stdin.
            descriptor = re.search(r'(?<![\w$])(\d+)$', line[:match.start()])
            body = []
            while index < len(lines):
                candidate = lines[index]
                index += 1
                if match[1]:
                    candidate = candidate.lstrip('\t')
                if candidate.rstrip('\r\n') == delimiter:
                    break
                body.append(candidate)
            bodies.append((unmarked(''.join(body)), quoted,
                           descriptor is None or int(descriptor[1]) == 0))
        parts = list(segments(header))
        shell_parts = [words for words, _ in parts
                       if (unwrapped := strip_wrappers(words)[0])
                       and os.path.basename(unwrapped[0]) in SHELLS]
        for receiver, _ in parts:
            unwrapped = strip_wrappers(receiver)[0]
            if (unwrapped and os.path.basename(unwrapped[0]) in ('http', 'https')
                    and '--ignore-stdin' not in unwrapped
                    and any(github_api_host(word) for word in unwrapped[1:])):
                deny('Use HTTPie --raw or a bounded regular input file instead of a here-document.')
        if shell_parts:
            if len(parts) != 1 or len(bodies) != 1:
                deny(UNKNOWN)
            body, quoted, _ = bodies[0]
            if not quoted:
                expanded = re.sub(r'\\([$`\\])', lambda m: '\uffff' if m[1] != '\\' else '\\', body)
                for inner in nested([expanded]):
                    # Here-doc substitutions happen before the receiver's
                    # env/sudo directory change, in the surrounding shell.
                    output.append(inner + '\n')
                    body = body.replace('$(' + inner + ')', '').replace('`' + inner + '`', '')
            output.append(header.rstrip() + ' -c ' + shlex.quote(body) + '\n')
        else:
            # A marker stands where each <<DELIMITER was, so that only the
            # command it is given to can read it as stdin.
            marked = line
            for number, match in reversed(list(enumerate(matches))):
                marked = (marked[:match.start()] + f' {HERE_MARK}{len(HERE_DOCUMENTS) + number} '
                          + marked[match.end():])
            output.append(marked.rstrip() + '\n')
            for body, quoted, stdin in bodies:
                text, built = here_document_text(body, quoted)
                HERE_DOCUMENTS.append({'text': text, 'built': built, 'stdin': stdin})
                if not quoted:
                    # Escaped dollars/backticks in an unquoted here-doc are
                    # literal text, while unescaped substitutions execute.
                    body = re.sub(r'\\([$`\\])', lambda m: '\uffff' if m[1] != '\\' else '\\', body)
                    for inner in nested([body]):
                        output.append(inner + '\n')
    return ''.join(output)


def changed_directory(cwd, destination):
    """The folder a cd, -C or chdir to destination reaches from cwd, or None
    when the guard cannot tell: the shell builds destination, or cwd is
    unknown."""
    if '$' in destination or '`' in destination:
        return None
    destination = os.path.expanduser(destination)
    if os.path.isabs(destination):
        return destination
    return os.path.join(cwd, destination) if cwd is not None else None


def here_document_text(body, quoted):
    """The text a here-document gives, and whether the shell builds part of
    it. With its delimiter quoted, the body is the text. Without, the shell
    runs its unescaped $ and backticks first, and drops the backslash of
    \\$, \\`, \\\\ and a line's end."""
    if quoted:
        return body, False
    text, built, index = [], False, 0
    while index < len(body):
        char = body[index]
        if char == '\\' and body[index + 1:index + 2] in ('$', '`', '\\', '\n'):
            if body[index + 1] != '\n':
                text.append(body[index + 1])
            index += 2
            continue
        built = built or bool(EXPANSION_START.match(body, index))
        text.append(char)
        index += 1
    return ''.join(text), built


def without_here_marks(parts):
    """Take the here-document markers out of each part's words, and say
    which here-documents each part was given."""
    words, given = [], []
    for part, separator in parts:
        words.append(([word for word in part if not word.startswith(HERE_MARK)], separator))
        given.append([int(word[1:]) for word in part if word.startswith(HERE_MARK)])
    return words, given


def stdin_document(parts, given, index):
    """The here-document the command parts[index] reads as stdin: the last
    one given to it for descriptor 0, or the one a bare cat before it pipes
    in (cat <<'EOF' | gh pr comment 12 -F -). None when it reads another
    pipe or redirection, or was given none: the guard cannot read those
    before the command runs."""
    words, separator = parts[index]
    if any(word in ('<', '<>', '<&', '<<<') for word in words):
        return None
    if separator in ('|', '|&'):
        if separator == '|' and index > 0 and parts[index - 1][0] == ['cat']:
            return stdin_document(parts, given, index - 1)
        return None
    documents = [number for number in given[index] if HERE_DOCUMENTS[number]['stdin']]
    return documents[-1] if documents else None


def published_files(filename, cwd, git_state=None):
    """The text of a file a command publishes (a commit message, a body):
    from the here-document given to that command for stdin, otherwise a
    bounded regular file that exists before the command runs."""
    if filename == '-':
        number = (git_state or {}).get('stdin')
        if number is None:
            deny(PUBLISHED_STDIN)
        if HERE_DOCUMENTS[number]['built']:
            deny(PUBLISHED_EXPANSION)
        return [HERE_DOCUMENTS[number]['text']]
    if git_state is not None:
        git_state.setdefault('read_files', []).append((cwd, filename))
    if cwd is None:
        deny(PUBLISHED_FILE)
    path = os.path.join(cwd, os.path.expanduser(filename))
    try:
        metadata = os.stat(path)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > 1024 * 1024:
            deny(PUBLISHED_FILE)
        with open(path, encoding='utf-8', errors='replace') as file:
            return [file.read()]
    except OSError:
        deny(PUBLISHED_FILE)


def literal_words(command):
    """The words of a command, as the shell will pass them, in which every
    $ and backtick is text: single-quoted or escaped. A word the shell
    would build from a variable or another command is left out, and so is
    anything this simple reading gets wrong, which then counts as built."""
    words, word, built, quote = set(), [], False, None
    index = 0

    def end():
        # A here-document read with cat stands as a marker: one whose text
        # the shell builds builds the word.
        text = unmarked(''.join(word))
        if word and not built and not any(document[4] for document in substituted_documents(text)):
            words.add(text)

    while index < len(command):
        char = command[index]
        if quote == "'":
            if char == "'":
                quote = None
            else:
                word.append(char)
        elif char == '\\' and index + 1 < len(command):
            following = command[index + 1]
            if quote == '"' and following not in '$`"\\\n':
                word.append(char)
            elif following != '\n':
                word.append(following)
            index += 1
        elif quote == '"':
            if char == '"':
                quote = None
            else:
                built = built or bool(EXPANSION_START.match(command, index))
                word.append(char)
        elif char in "'\"":
            quote = char
        elif char.isspace() or char in ';&|()<>':
            end()
            word, built = [], False
        else:
            built = built or bool(EXPANSION_START.match(command, index))
            word.append(char)
        index += 1
    if quote is None:
        end()
    return words


def literal_text(value, git_state):
    """The text the shell passes for value, or None when it builds value
    from a variable or another command: value holds a $ or backtick outside
    a here-document read with cat that the shell gives as written
    (substituted_documents), and is not, or does not end, a
    word in which they are text. Inside double quotes the shell drops the
    backslash of \\$ and \\`, which the guard's word splitting keeps."""
    if not EXPANSION_START.search(without_documents(value, built=False)):
        return value
    for candidate in dict.fromkeys([value, re.sub(r'\\([$`])', r'\1', value)]):
        for word in git_state.get('literal_words', ()):
            if not word.endswith(candidate):
                continue
            # The whole word, an option's or a field's value after =, or a
            # short option's attached value, after any switches (-cbtext).
            prefix = word[:len(word) - len(candidate)]
            if not prefix or prefix.endswith('=') or re.fullmatch(r'-[A-Za-z]+=?', prefix):
                return candidate
    return None


def note_published(git_state, label, values=(), files=(), cwd=None, texts=()):
    """Remember text a command would publish, for check_privacy: values are
    the shell's words, files name files (or - for stdin) the command reads
    its text from, and texts are data already read, such as a request
    file's content, in which a $ or a backtick is only text. A word the
    shell would build from a variable or another command is refused: what
    it becomes cannot be read here."""
    published = git_state.setdefault('published', [])
    for value in values:
        text = literal_text(str(value), git_state)
        if text is None:
            deny(PUBLISHED_EXPANSION)
        # A here-document read with cat publishes its body.
        published.append((label, given_documents(text)))
    for filename in files:
        filename = str(filename)
        # A process substitution, or a name the shell builds, names nothing
        # the guard can read before the command runs.
        if filename.startswith(('<(', '>(')) or literal_text(filename, git_state) is None:
            deny(PUBLISHED_EXPANSION)
        published.extend((label + ' file', text)
                         for text in published_files(filename, cwd, git_state))
    published.extend((label, str(text)) for text in texts)
    git_state['publishes'] = True


def effective_directory(context):
    """The directory a git command runs in, after its -C options."""
    cwd, options, _ = context
    for index, option in enumerate(options[:-1]):
        if option == '-C' and cwd is not None:
            cwd = changed_directory(cwd, options[index + 1])
    return cwd


def commit_options(args):
    """(option, value) for each git commit option that takes a value, read
    as git reads them: --long=value or --long value, and short clusters in
    which the first letter that takes a value takes the rest of the word or
    the next word (-sm text)."""
    pairs, index = [], 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            break
        if arg.startswith('--'):
            option, equal, value = arg.partition('=')
            if option in COMMIT_VALUE_LONG:
                if equal:
                    pairs.append((option, value))
                elif index + 1 < len(args):
                    index += 1
                    pairs.append((option, args[index]))
        elif arg.startswith('-'):
            for offset, letter in enumerate(arg[1:], 1):
                if letter in COMMIT_VALUE_SHORT:
                    # -S's optional key must be attached.
                    if arg[offset + 1:]:
                        pairs.append(('-' + letter, arg[offset + 1:]))
                    elif letter != 'S' and index + 1 < len(args):
                        index += 1
                        pairs.append(('-' + letter, args[index]))
                    break
        index += 1
    return pairs


def note_commit(git_state, args, context, paths):
    """Remember a commit: what it records (its message and trailers, the
    files it reads a message from, an author or committer it is given), and
    the repository whose staged changes and added paths it would take."""
    directory = effective_directory(context)
    _, options, environment = context
    pairs = commit_options(args)
    note_published(git_state, 'the commit message',
                   [value for option, value in pairs if option in ('-m', '--message', '--trailer')],
                   [value for option, value in pairs if option in ('-F', '--file', '-t', '--template')],
                   directory)
    adds = git_state.get('adds', [])
    if directory is None or any(folder is None for folder, _, _ in adds):
        deny(UNKNOWN_FOLDER)
    # The author and committer: as given (--author, -c, GIT_AUTHOR_* and
    # the like), which must be the command's own text, and as git reads
    # them where the commit runs, configured ones included. They are
    # checked as a commit's are, so the published support address and
    # GitHub's own addresses pass. Where git cannot tell who commits, the
    # commit fails.
    given = [setting.partition('=')[2] for option, setting in zip(options, options[1:])
             if option == '-c' and setting.partition('=')[0].lower() in IDENTITY_SETTINGS]
    given += [environment[key] for key in IDENTITY_VARIABLES if environment.get(key)]
    # GIT_CONFIG_COUNT, _KEY_n and _VALUE_n can set them too.
    if any(literal_text(value, git_state) is None for value in given + [
            value for key, value in environment.items() if key.startswith('GIT_CONFIG') and value]):
        deny(PUBLISHED_EXPANSION)
    identities = git_state.setdefault('identities', [])
    read = 0
    for variable, where in (('GIT_AUTHOR_IDENT', 'the commit author'),
                            ('GIT_COMMITTER_IDENT', 'the commit committer')):
        signed = re.fullmatch(r'(.*) <(.*)> \d+ [+-]\d{4}', git(context, 'var', variable) or '')
        if signed:
            identities.append((directory, signed[1], signed[2], where))
            read += 1
    if not read:
        note_published(git_state, 'the commit author', given)
    for author in (value for option, value in pairs if option == '--author'):
        signed = re.fullmatch(r'(.*?)\s*<(.*)>', author.strip())
        if signed and literal_text(author, git_state) is not None:
            identities.append((directory, signed[1], signed[2], 'the commit author'))
        else:
            # Not Name <address>: git looks for an author it has seen.
            note_published(git_state, 'the commit author', [author])
    git_state.setdefault('commits', []).append(
        (directory, [*adds, *((directory, path, False) for path in paths)]))


def check_push_hook(options, context):
    """A push must run .githooks/pre-push, which checks what it carries."""
    if '--no-verify' in options:
        deny(NO_VERIFY)
    if context[0] is None:
        deny(UNKNOWN_FOLDER)
    top = git(context, 'rev-parse', '--show-toplevel')
    setting = git(context, 'config', '--get', 'core.hooksPath')
    if top is None or not setting:
        deny(HOOK_OFF)
    folder = os.path.expanduser(setting)
    folder = folder if os.path.isabs(folder) else os.path.join(top, folder)
    hook = os.path.join(top, '.githooks', 'pre-push')
    try:
        same = os.path.realpath(folder) == os.path.realpath(os.path.join(top, '.githooks'))
    except (OSError, ValueError):
        same = False
    if not same:
        deny(NO_VERIFY)
    if not os.path.lexists(hook):
        # Set the right way, on a branch made before the hook reached main.
        deny(HOOK_MISSING)
    try:
        with open(hook, encoding='utf-8') as file:
            runs_check = 'scripts/privacy-check.py --pre-push' in file.read()
    except (OSError, UnicodeError):
        runs_check = False
    if not runs_check or not os.access(hook, os.X_OK):
        deny(HOOK_OFF)


def inline_code(args, cwd=None):
    """Whether an interpreter is given its code on the command line (-c,
    -e) or on stdin, rather than a script file. The options end at the
    script: what follows it is the script's own (privacy-check.py --text -).
    An operand that is neither a script's name nor a file may be an
    option's value (python3 -X dev -c ...), so reading goes on past it."""
    for arg in args:
        if arg in ('-', '--eval', '--print') or re.fullmatch(r'-[a-zA-Z]*[ceEp]', arg):
            return True
        if arg == '--' or (not arg.startswith('-') and (
                re.search(r'\.(?:py|js|mjs|cjs|ts|rb|pl|pm|scpt|applescript)$', arg)
                or (cwd is not None and os.path.isfile(os.path.join(cwd, arg))))):
            return False
    return not [arg for arg in args if not arg.startswith('-')]


def note_writes(git_state, words, raw_words, unwrapped, shell_cwd, cwd):
    """Remember the files a command writes, as (directory, path), with None
    for a path the guard cannot name: the shell's > and >> targets, the
    files tee, cp, mv and the like are given, sed -i and perl -i, dd of=,
    curl and wget downloads, and a patch or an interpreter's inline code,
    which may write anything."""
    writes = git_state.setdefault('writes', [])
    aligned = len(raw_words) == len(words)
    for index, word in enumerate(words[:-1]):
        # A quoted '>' is a word, not a redirection.
        if word in WRITE_REDIRECTIONS and (not aligned or raw_words[index] == word):
            target = words[index + 1]
            if word == '>&' and re.fullmatch(r'\d*-?', target):
                continue  # 2>&1 copies a descriptor
            if not target.startswith('/dev/'):
                writes.append((shell_cwd, target))
    if not unwrapped:
        return
    program = os.path.basename(unwrapped[0])
    args = without_redirections(unwrapped[1:])
    operands = [arg for arg in args if not arg.startswith(('-', '<(', '>('))]
    paths = []
    if program in ('tee', 'mv'):
        # tee writes every file it is given; mv takes its sources away.
        paths = operands + [arg.partition('=')[2] for arg in args
                            if arg.startswith('--target-directory=')]
    elif program in FILE_WRITERS:
        # cp, install, ln, rsync and ditto write only their destination:
        # the last operand, or the folder -t names (rsync's -t keeps times).
        targets = list(option_values(args, {'--target-directory'},
                                     set() if program == 'rsync' else {'-t'}))
        if targets:
            paths = targets
        elif program == 'install' and any(arg == '--directory' or re.fullmatch(
                r'-[a-zA-Z]*d[a-zA-Z]*', arg) for arg in args):
            paths = operands  # install -d makes each folder it names
        else:
            paths = operands[-1:]
    elif program in ('sed', 'perl') and any(re.match(r'-[a-zA-Z]*i', arg)
                                           or arg.startswith('--in-place') for arg in args):
        paths = operands
    elif program == 'dd':
        paths = [arg[3:] for arg in args if arg.startswith('of=')]
    elif program == 'curl':
        request = curl_words(unwrapped)[1:]
        paths = list(option_values(request, {'--output'}, {'-o'}))
        if any(arg in ('-O', '--remote-name', '--remote-name-all') for arg in request):
            paths.append(None)  # named after the address
    elif program == 'wget':
        documents = list(option_values(args, {'--output-document'}, {'-O'}))
        if documents:
            paths = [document for document in documents if document != '-']
        elif any(arg.startswith(('-P', '--directory-prefix')) for arg in args):
            paths = [None]
        else:
            # It saves what it fetches under the last part of the address.
            paths = [posixpath.basename(parsed_url(arg)[0].path) or 'index.html'
                     for arg in operands if parsed_url(arg)[1] and '.' in parsed_url(arg)[1]]
    elif program == 'patch' or (INTERPRETERS.fullmatch(program) and inline_code(args, cwd)):
        paths = [None]
    writes.extend((cwd, path) for path in paths)


def resolved(cwd, path):
    """A path as an absolute one, or None when the guard cannot tell where
    it is: the shell builds it, or its directory is unknown."""
    if path is None or '$' in path or '`' in path:
        return None
    path = os.path.expanduser(path)
    if not os.path.isabs(path) and cwd is None:
        return None
    return os.path.realpath(os.path.join(cwd or os.sep, path))


def overlaps(written, read):
    """Whether a path written may be, hold or lie inside a path read (or
    match it as a pathspec). A path that cannot be resolved may be any."""
    one, other = resolved(*written), resolved(*read)
    if one is None or other is None:
        return True
    return (one == other or other.startswith(one.rstrip(os.sep) + os.sep)
            or one.startswith(other.rstrip(os.sep) + os.sep) or fnmatch.fnmatchcase(one, other))


def changes_index(subcommand, args):
    """Whether git apply, am or stash changes the index, which a commit
    takes: apply with --cached, --index or --3way, am, stash pop and apply."""
    if subcommand == 'am':
        return True
    if subcommand == 'stash':
        return [arg for arg in args if not arg.startswith('-')][:1] in (['pop'], ['apply'])
    for arg in args:
        if arg == '--':
            break
        option = arg.partition('=')[0]
        # git takes an option's unique beginning for the whole option.
        if (len(option) > 3 and option.startswith('--')
                and any(full.startswith(option) for full in ('--cached', '--index', '--3way'))):
            return True
        if re.fullmatch(r'-[a-zA-Z0-9]*3[a-zA-Z0-9]*', arg):
            return True
    return False


def sets_identity(args):
    """Whether git config changes a commit's author or committer (user.*,
    author.*, committer.*): sets, adds, replaces or unsets one, or removes
    or renames their section. A read changes nothing."""
    operands, index, options = [], 0, set()
    while index < len(args):
        arg = args[index]
        if arg in ('-f', '--file', '--blob', '--type', '--default', '--comment', '--value'):
            index += 1
        elif arg.startswith('-'):
            options.add(arg.partition('=')[0])
        else:
            operands.append(arg)
        index += 1
    action = ''
    if operands[:1] in (['set'], ['unset'], ['get'], ['list'], ['remove-section'],
                        ['rename-section']):
        action, operands = operands[0], operands[1:]
    key = operands[0].lower() if operands else ''
    if (action in ('remove-section', 'rename-section')
            or options & {'--remove-section', '--rename-section'}):
        return key in ('user', 'author', 'committer')
    if key not in IDENTITY_SETTINGS or action in ('get', 'list') or any(
            option.startswith(('--get', '--list')) or option == '-l' for option in options):
        return False
    return action in ('set', 'unset') or len(operands) >= 2 or any(
        option.startswith(('--unset', '--replace-all', '--add')) for option in options)


def check_written(git_state):
    """Deny when a command writes a file it also publishes, sends or
    commits: the guard read that file before the command runs, so what goes
    out would be what the command wrote, unread. A change to the index
    (git apply --cached, am, stash pop) in the repository a commit in the
    same command takes it from counts too. So does a commit identity the
    same command sets."""
    if git_state.get('identity_set') and git_state.get('commits'):
        deny(IDENTITY_SET)
    changes = git_state.get('index_changes', [])
    if changes and git_state.get('commits'):
        tops = {git(context, 'rev-parse', '--show-toplevel') for context in changes}
        for directory, _ in git_state['commits']:
            if None in tops or git((directory, [], {}), 'rev-parse', '--show-toplevel') in tops:
                deny(WRITTEN_FILE)
    reads = [*git_state.get('read_files', []), *REQUEST_FILES,
             *((folder, path) for _, specs in git_state.get('commits', ())
               for folder, path, _ in specs)]
    if any(overlaps(written, read) for written in git_state.get('writes', []) for read in reads):
        deny(WRITTEN_FILE)


def declared(args, inherited):
    """The environment after declare, typeset, local or readonly: an
    assignment changes it as a bare one does, -x exports, and +x takes the
    export away. Other attributes (-n, -a, -i, -l, -u) change what a value
    means, so a repository variable given one is unknown."""
    updates = dict(inherited)
    options = [arg for arg in args if arg.startswith(('-', '+')) and '=' not in arg]
    letters = ''.join(option.lstrip('-+') for option in options)
    if set(letters) & set('fF'):
        return updates  # functions, not variables
    for arg in args:
        if arg in options:
            continue
        key, equal, value = arg.partition('=')
        if not context_variable(key):
            continue
        if set(letters) - set('xgr'):
            deny(UNKNOWN)
        if any(option.startswith('+') for option in options):
            updates[key] = None
        elif equal:
            if '$' in value or '`' in value:
                deny(UNKNOWN)
            updates[key] = value
        elif 'x' in letters:
            deny(UNKNOWN)  # exports a value set before, which is not known here
    return updates


def prints_environment(words, unwrapped):
    """Whether a command prints every environment variable, which may hold
    the private list: env or printenv with no command or name, export with
    none or -p, declare or typeset with no names, and set with nothing."""
    if not unwrapped:
        return any(os.path.basename(word) == 'env' for word in words)
    program = os.path.basename(unwrapped[0])
    args = without_redirections(unwrapped[1:])
    names = [arg for arg in args if not arg.startswith(('-', '+'))]
    if program == 'printenv':
        return not names
    if program == 'export':
        return not names or '-p' in args
    if program in ('declare', 'typeset'):
        letters = ''.join(arg.lstrip('-+') for arg in args if arg.startswith(('-', '+')))
        return not names and not set(letters) & set('fF')
    return program == 'set' and not args


def names_list_glob(command):
    """Whether a glob could name the private list's file: a pattern for a
    folder in a config folder that brickson matches, followed by nothing or
    by a name that private-words.txt matches."""
    for match in CONFIG_FOLDER.finditer(command):
        folder, name = match[1], match[2]
        if (any(char in folder for char in '*?[') and fnmatch.fnmatchcase('brickson', folder)
                and (not name or fnmatch.fnmatchcase('private-words.txt', name))):
            return True
    return False


def names_config_folder(command):
    """Whether a word names a config folder itself, which a recursive or
    wildcard read would reach the list's file through without naming it
    (grep -r . ~/.config), or is a glob that could name the list's folder
    or file through one (~/.c*/b*/*). Read deny rules do not cover such a
    read, so the guard refuses it."""
    for word in re.findall(r'[^\s;&|()<>`]+', command):
        word = re.sub(r'\$\{?XDG_CONFIG_HOME\}?', '/.config', word.replace('"', '').replace("'", ''))
        parts = [part for part in word.split('/') if part not in ('', '.')]
        for index, part in enumerate(parts):
            # A shell glob matches a leading dot only when it writes one.
            if not (part.startswith('.') and fnmatch.fnmatchcase('.config', part)):
                continue
            rest = parts[index + 1:]
            if not rest or (len(rest) <= 2 and fnmatch.fnmatchcase('brickson', rest[0])
                            and (len(rest) == 1
                                 or fnmatch.fnmatchcase('private-words.txt', rest[1]))):
                return True
    return False


def check_command(command, cwd, depth=0, environment=None, git_state=None):
    # Branch changes persist even across subshells. Later implicit pushes
    # cannot be resolved using the repository's state before this command.
    if git_state is None:
        git_state = {'branch_changed': False}
    if depth > 3:
        deny('Shell nesting exceeds the inspection limit. Use the underlying command explicitly.')
    command = ansi_c_quotes(without_shell_comments(
        inspectable_here_documents(marked_documents(command))))
    literal = literal_words(command)
    try:
        parts = list(segments(command))
    except ValueError:
        # Unbalanced quotes: the shell would refuse it too. Look at the words.
        parts = [([unmarked(word) for word in command.split()], ';')]
    try:
        raw_parts = list(segments(command, preserve_quotes=True))
    except ValueError:
        # The quote-keeping reading fails on a quote that opens a word inside
        # another (--body='a <b>'); the shell's reading above still holds.
        raw_parts = []
    parts, given = without_here_marks(parts)
    raw_parts = without_here_marks(raw_parts)[0]
    # A process substitution is its command's word too (-F <(cat x)): the
    # option before it gets a value that names nothing readable.
    for index in range(len(parts) - 1):
        following = parts[index + 1][0]
        if following in (['<('], ['>(']) and parts[index][0] not in ([], ['('], [')'], ['<('], ['>(']):
            for group in (parts, raw_parts) if len(raw_parts) == len(parts) else (parts,):
                words, separator = group[index]
                # --body-file=<(...) is one word.
                if words[-1].endswith('='):
                    words = words[:-1] + [words[-1] + following[0]]
                else:
                    words = words + following
                group[index] = (words, separator)
    # The shell can continue after a failed cd. Keep both outcomes until a
    # connector selects success (&&) or failure (||), instead of assuming cd
    # succeeded because its target looked like a directory during this check.
    states = {(cwd, True, (), tuple(sorted((environment or {}).items())))}
    scopes = []
    for part_index, (words, separator) in enumerate(parts):
        runnable = {(where, success, stack, env) for where, success, stack, env in states
                    if separator not in ('&&', '||')
                    or (separator == '&&' and success)
                    or (separator == '||' and not success)}
        next_states = states - runnable
        if words in (['('], ['<('], ['>(']):
            scopes.append((runnable, next_states, words != ['(']))
            states = runnable
            continue
        if words == [')']:
            if scopes:
                outer, skipped, asynchronous = scopes.pop()
                outcomes = {True, False} if asynchronous else {success for _, success, _, _ in states}
                states = skipped | {(where, success, stack, env)
                    for where, _, stack, env in outer for success in outcomes}
            continue
        runtime_inputs = []
        unwrapped, command_environment, directories = strip_wrappers(words, environment, runtime_inputs)
        if prints_environment(words, unwrapped):
            deny(ENVIRONMENT_DUMP)
        if not unwrapped:
            # Redirections alone, after a subshell or a group ( ... ) > file,
            # still write their targets.
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            for where in {path for path, _, _, _ in runnable}:
                note_writes(git_state, words, raw_words, unwrapped, where, where)
            if words and all(re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', word) for word in words):
                # Assignment-only shell commands persist, including unexported CDPATH.
                for where, _, stack, shell_env in runnable:
                    _, updates, _ = strip_wrappers(words, dict(shell_env))
                    next_states.add((where, True, stack, tuple(sorted(updates.items()))))
                states = next_states
            continue
        program = os.path.basename(unwrapped[0])
        if runtime_inputs and program in SHELLS | {'eval', 'gh', 'curl', 'wget', 'http', 'https'}:
            deny('Use explicit command arguments; xargs adds uninspected input at execution time.')
        script_index = shell_script_index(unwrapped)
        if script_index is None and program in SHELLS and '<<<' in unwrapped:
            redirect = unwrapped.index('<<<')
            absolute_redirect = len(words) - len(unwrapped) + redirect
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            if (len(raw_words) == len(words) and raw_words[absolute_redirect] == '<<<'
                    and redirect + 1 < len(unwrapped)):
                # With a script operand, stdin is data instead of shell code.
                if all(word.startswith('-') or word in ('/dev/stdin', '/dev/fd/0')
                       for word in unwrapped[1:redirect]):
                    script_index = redirect + 1
        if script_index is None and shell_reads_external_program(unwrapped):
            deny('The guard cannot inspect shell code from a pipe or input file. '
                 'Use an explicit -c script or an inspectable here-document/string.')
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
                # Escaped ones (\$( and \`) are the child's: this shell only
                # drops their backslash.
                for inner in nested([re.sub(r'\\[$`]', '\uffff', script)]):
                    script = script.replace('$(' + inner + ')', '').replace('`' + inner + '`', '')
            # Unknown/mixed quoting is checked in both contexts conservatively.
            if quote != "'":
                script = re.sub(r'\\([$`])', r'\1', script)
        for where, stack, shell_env in {(path, stack, env) for path, _, stack, env in runnable}:
            inherited = dict(shell_env)
            _, command_environment, directories = strip_wrappers(words, inherited)
            command_cwd = where
            for directory in directories:
                command_cwd = changed_directory(command_cwd, directory)
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            raw_outer = None
            if len(raw_words) == len(words):
                raw_outer = (raw_words[:absolute_index] + raw_words[absolute_index + 1:]
                             if outer_words is not words else raw_words)
            for inner in dict.fromkeys(nested(outer_words, raw_outer)):
                check_command(inner, where, depth + 1, inherited, git_state)
            if script_index is not None:
                check_command(script, command_cwd, depth + 1,
                              command_environment, git_state)
            elif program == 'eval':
                check_command(' '.join(unwrapped[1:]), command_cwd, depth + 1,
                              command_environment, git_state)
            elif program == 'trap':
                action = trap_action(unwrapped)
                if action is not None:
                    check_command(action, None, depth + 1, command_environment, git_state)
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            note_writes(git_state, words, raw_words, unwrapped, where, command_cwd)
            if program in ('declare', 'typeset', 'local', 'readonly'):
                next_states.add((where, True, stack, tuple(sorted(
                    declared(unwrapped[1:], inherited).items()))))
                continue
            if program in ('export', 'unset'):
                updates = dict(inherited)
                operands = unwrapped[1:]
                flags = [word for word in operands if word.startswith('-')]
                if program == 'unset' and '-f' in flags:
                    pass  # Function names do not change exported variables.
                else:
                    for word in operands:
                        key, equal, value = word.partition('=')
                        if not context_variable(key):
                            continue
                        if flags and flags not in (['--'], ['-v']):
                            deny(UNKNOWN)
                        if program == 'unset':
                            updates[key] = None
                        elif equal:
                            if '$' in value or '`' in value:
                                deny(UNKNOWN)
                            updates[key] = value
                        else:
                            deny(UNKNOWN)  # A prior unexported shell value is unknown.
                next_states.add((where, True, stack, tuple(sorted(updates.items()))))
                continue
            if program in ('cd', 'pushd', 'popd'):
                if program == 'popd' or (program == 'pushd' and len(unwrapped) == 1):
                    target = stack[0] if stack else None
                    rest = stack[1:] if stack else ()
                    new_stack = ((where,) + rest) if program == 'pushd' else rest
                    next_states.update({(target, True, new_stack, shell_env), (where, False, stack, shell_env)})
                    continue
                if program == 'pushd' and unwrapped[1].startswith(('-', '+')):
                    deny(UNKNOWN)  # indexed/stack-only forms are not guessed
                destination = unwrapped[1] if len(unwrapped) > 1 else (
                    command_environment.get('HOME', os.environ.get('HOME')))
                if destination is None:
                    next_states.add((where, False, stack, shell_env))
                    continue  # HOME unset: operandless cd fails.
                cdpath = command_environment.get('CDPATH', os.environ.get('CDPATH'))
                if (cdpath and not os.path.isabs(destination)
                        and destination.split('/', 1)[0] not in ('.', '..')):
                    # Earlier commands may change which CDPATH entry exists. Keep
                    # the target unknown rather than querying the wrong repository.
                    target = None
                else:
                    target = changed_directory(where, destination)
                # Earlier shell commands may create the target, so inspect
                # both outcomes even when it does not exist at hook time.
                new_stack = (where,) + stack if program == 'pushd' else stack
                next_states.add((target, True, new_stack, shell_env))
                next_states.add((where, False, stack, shell_env))
                continue
            git_state['literal_words'] = literal  # this command's, not a nested one's
            git_state['stdin'] = stdin_document(parts, given, part_index)
            if program == 'git':
                # 2>/dev/null and the like are the shell's, never git's arguments.
                subcommand, args, context = git_parts(without_redirections(unwrapped),
                                                      command_cwd, command_environment)
                subcommand, args, context = expand_git_alias(subcommand, args, context)
                args = without_redirections(args)
                if runtime_inputs and subcommand not in {
                        'status', 'diff', 'log', 'show', 'rev-parse', 'ls-files'}:
                    deny('Use explicit Git arguments; xargs may append protected flags or destinations.')
                if subcommand in ('apply', 'am', 'stash'):
                    # A patch or a stash changes files, or the index, that
                    # the guard cannot name.
                    git_state.setdefault('writes', []).append((command_cwd, None))
                    if changes_index(subcommand, args):
                        git_state.setdefault('index_changes', []).append(context)
                if subcommand == 'config' and sets_identity(args):
                    git_state['identity_set'] = True
                if (subcommand in ('checkout', 'switch')
                        or (subcommand == 'branch' and any(
                            (arg.startswith('--') and arg != '--' and '--move'.startswith(arg))
                            or re.fullmatch(r'-[a-zA-Z]*[mM][a-zA-Z]*', arg) for arg in args))
                        or (subcommand == 'symbolic-ref'
                            and len([arg for arg in args if not arg.startswith('-')]) >= 2)):
                    git_state['branch_changed'] = True
                elif subcommand in ('add', 'stage'):
                    check_add(args)
                    # Each path is read from the folder this add runs in,
                    # and a forced add also takes ignored files.
                    directory, force = effective_directory(context), add_forces(args)
                    git_state.setdefault('adds', []).extend(
                        (directory, arg, force) for arg in args if not arg.startswith('-'))
                elif subcommand == 'commit':
                    note_commit(git_state, args, context, check_commit(args))
                elif subcommand == 'push':
                    check_push(args, context, git_state['branch_changed'])
                elif subcommand == 'send-pack':
                    deny('Use git push with an explicit feature branch; send-pack '
                         'can update remote refs outside the inspected push path.')
            elif program == 'gh':
                check_gh(unwrapped, command_cwd, command_environment, git_state)
            elif program in ('curl', 'wget', 'http', 'https'):
                request_words = curl_words(unwrapped) if program == 'curl' else unwrapped
                if program == 'curl' and any(word.startswith('--expand-') for word in request_words[1:]):
                    deny('Use explicit curl option values; variable expansion is not inspected.')
                if program == 'curl' and list(option_values(request_words[1:], {'--config'}, {'-K'})):
                    deny(CURL_CONFIG)
                if program == 'wget':
                    for word in unwrapped[1:]:
                        require_full_options(word, {
                            '--method', '--post-data', '--post-file', '--body-data', '--body-file',
                        })
                        option = word.split('=', 1)[0]
                        if ((option.startswith('--') and option != '--' and '--input-file'.startswith(option))
                                or re.match(r'^-[^-]*i', word)):
                            deny('Use explicit Wget URLs; input-file URL lists are not inspected.')
                        if ((option.startswith('--') and option != '--' and any(
                                full.startswith(option) for full in ('--execute', '--config')))
                                or re.match(r'^-[^-]*e', word)):
                            deny(WGET_CONFIG)
                for operation in http_operations(request_words):
                    if any(github_api_host(word) for word in operation[1:]):
                        # curl reads its default file before any later options;
                        # --next does not require a second leading disable.
                        if program == 'curl' and unwrapped[1:2] not in (['-q'], ['--disable']):
                            deny(CURL_CONFIG)
                        if program == 'wget' and '--no-config' not in unwrapped[1:]:
                            deny(WGET_CONFIG)
                        if program == 'curl' and not curl_flag(operation, {'--globoff', '-g'}, '--no-globoff'):
                            if any(github_api_host(word) and re.search(r'[{}\[\]]', word)
                                   for word in operation[1:]):
                                deny('Use explicit GitHub API URLs or --globoff; URL globs are not inspected.')
                        inline = []
                        if program in ('http', 'https'):
                            # HTTPie's body items and --raw body are the
                            # shell's words; a body it reads from stdin is data.
                            _, items, raw = httpie_request(operation)
                            inline = [item for item in items
                                      if re.fullmatch(r'[^:=@]+(?::=@|=@|:=|=(?!=))(.*)', item, re.S)]
                            inline += [] if raw is None else [raw]
                            operation = httpie_stdin(operation, words, separator, command_cwd)
                        arguments = api_arguments(operation, command_cwd, program)
                        method = request_method(operation, program)
                        if method not in ('GET', 'HEAD'):
                            # The request's body: its inline data, which are
                            # the shell's words, and the files and items
                            # api_arguments read after the words, which are data.
                            inline += option_values(operation, {
                                '--data', '--data-ascii', '--data-binary', '--data-raw',
                                '--data-urlencode', '--json', '--form', '--form-string',
                                '--post-data', '--body-data'}, {'-d', '-F'})
                            data = arguments[len(' '.join(operation)):]
                            if not ('graphql' in api_paths(operation) and graphql_read(
                                    [literal_text(value, git_state) for value in inline] + [data])):
                                note_published(git_state, program, inline, texts=[data])
                        if protected_api_write(operation, arguments, method):
                            deny(TO_MAIN)
                        if merge_api_request(operation, arguments, method):
                            deny(MERGE)
                        if copilot_request(arguments, operation, method):
                            deny(COPILOT)
            next_states.update({(where, True, stack, shell_env), (where, False, stack, shell_env)})
        states = next_states


def check_github_tool(name, arguments):
    tool = name.rsplit('__', 1)[-1]
    if tool in ('merge_pull_request', 'enable_pr_auto_merge'):
        deny(MERGE)
    if tool in ('request_copilot_review', 'assign_copilot_to_issue',
                'create_pull_request_with_copilot'):
        deny(COPILOT)
    if tool == 'assign_copilot_to_issue_with_intent' and arguments.get('is_suggestion') is not True:
        deny(COPILOT)
    if tool in ('push_files', 'create_or_update_file', 'delete_file') and \
            branch_name(str(arguments.get('branch', ''))) in PROTECTED:
        deny(TO_MAIN)
    if tool == 'pull_request_review_write' and \
            str(arguments.get('event', '')).upper() == 'APPROVE':
        deny(MERGE)
    if tool in ('issue_write', 'create_issue', 'update_issue') and any(
            'copilot' in str(a).lower() for a in arguments.get('assignees') or []):
        deny(COPILOT)
    reviewers = arguments.get('reviewers')
    if tool in ('update_pull_request', 'create_pull_request') and any(
            'copilot' in str(r).lower()
            for r in (reviewers if isinstance(reviewers, list) else [reviewers])):
        deny(COPILOT)


def privacy_module():
    spec = importlib.util.spec_from_file_location('privacy_check', PRIVACY_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    return module


def check_privacy(texts=(), files=(), commits=(), directory=None, identities=()):
    """Deny when what would be published holds a personal detail, naming
    places and kinds only. If the check cannot run, nothing is published.
    identities are (folder, name, address, where) for a commit's author
    and committer, checked as the checker checks a commit's."""
    try:
        privacy = privacy_module()
    except Exception as error:  # noqa: BLE001 - any failure publishes nothing
        deny(PRIVATE_SETUP.format(reason=f'scripts/privacy-check.py could not be loaded '
                                         f'({type(error).__name__}).'))
    try:
        findings = privacy.guard_findings(texts, files, commits, directory,
                                          seconds=PRIVACY_SECONDS)
        if identities:
            entries = privacy.load_list()[0]
            for folder, name, address, where in identities:
                try:
                    support = privacy.support_addresses(privacy.top_level(folder))[0]
                except privacy.SetupError:
                    support = set()  # not a checkout: the support address is not allowed
                findings += privacy.Checker(entries, support).identity(name, address, where)
    except privacy.SetupError as error:
        deny(PRIVATE_SETUP.format(reason=str(error)))
    except Exception as error:  # noqa: BLE001
        deny(PRIVATE_SETUP.format(reason=f'it failed ({type(error).__name__}).'))
    if findings:
        places = '; '.join(str(finding) for finding in findings[:10])
        if len(findings) > 10:
            places += f'; and {len(findings) - 10} more'
        deny(PRIVATE.format(places=places, advice=privacy.advice(findings)))


def tool_texts(value, label):
    """Every string in a tool's arguments, with where it came from."""
    if isinstance(value, str):
        yield label, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from tool_texts(child, f'{label}.{key}')
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from tool_texts(child, f'{label}[{index}]')


def check_tool_privacy(name, arguments, cwd):
    tool = name.rsplit('__', 1)[-1]
    if tool not in TOOLS_PUBLISH:
        return
    files, rest = [], dict(arguments)
    if tool == 'create_or_update_file' and isinstance(rest.get('content'), str):
        files.append((str(rest.pop('path', '')), rest.pop('content')))
    if tool == 'push_files' and isinstance(rest.get('files'), list):
        for entry in rest.pop('files'):
            if isinstance(entry, dict) and isinstance(entry.get('content'), str):
                files.append((str(entry.get('path', '')), entry['content']))
            else:
                rest.setdefault('other_files', []).append(entry)
    check_privacy(list(tool_texts(rest, tool)), files, directory=cwd)


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
    if not isinstance(arguments, dict):
        arguments = {}
    cwd = call.get('cwd') or os.getcwd()
    if name == 'Bash':
        command = str(arguments.get('command', ''))
        if (LIST_REFERENCE.search(command) or names_list_glob(command)
                or names_config_folder(command)):
            deny(LIST_READ)
        if PROCESS_ENVIRONMENT.search(command):
            deny(ENVIRONMENT_DUMP)
        state = {'branch_changed': False}
        check_command(command, cwd, git_state=state)
        check_written(state)
        if state.get('publishes'):
            check_privacy(state.get('published', []), commits=state.get('commits', ()),
                          directory=cwd, identities=state.get('identities', ()))
    elif name.startswith('mcp__'):
        check_github_tool(name, arguments)
        check_tool_privacy(name, arguments, cwd)


if __name__ == '__main__':
    main()
