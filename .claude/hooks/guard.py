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
import glob
import importlib.util
import os
import re
import shlex
import subprocess
import sys
import stat
import unicodedata
import posixpath
import functools
try:
    import pwd
except ImportError:  # not on macOS or Linux
    pwd = None
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
            'timeout', 'xargs', 'then', 'do', 'else', 'if', 'elif', 'while', 'until', '!', '{', '(',
            # Programs that run the command after their options (and, for
            # chrt and taskset, a priority or a mask), as env does.
            'stdbuf', 'setsid', 'ionice', 'chrt', 'taskset', 'caffeinate', 'arch',
            'xcrun', 'setpriv', 'prlimit', 'unshare', 'doas',
            # expect's unbuffer runs it with a terminal (TERMINAL_WRAPPERS).
            'unbuffer'}
# Wrappers that give the command they run a terminal, where gh asks.
TERMINAL_WRAPPERS = {'unbuffer'}
WRAPPER_VALUE_OPTIONS = {
    'time': {'-o', '--output', '-f', '--format'},
    'env': {'-u', '--unset', '-C', '--chdir'},
    'nice': {'-n', '--adjustment'},
    'xargs': {'-n', '-L', '-I', '-P', '-s', '-E', '-J', '-R', '-S', '-a', '-d',
              '--max-args', '--max-procs', '--max-chars', '--arg-file', '--delimiter', '--process-slot-var'},
    'timeout': {'-k', '--kill-after', '-s', '--signal'},
    'sudo': {'-u', '--user', '-g', '--group', '-h', '--host', '-p', '--prompt',
             '-C', '--close-from', '-D', '--chdir', '-R', '--chroot', '-r', '--role',
             '-t', '--type', '-T', '--command-timeout', '-U', '--other-user'},
    # bash's exec -a NAME gives the command another name.
    'exec': {'-a'},
    'stdbuf': {'-i', '-o', '-e', '--input', '--output', '--error'},
    'ionice': {'-c', '--class', '-n', '--classdata', '-p', '--pid', '-P', '--pgid',
               '-u', '--uid'},
    'chrt': {'-T', '--sched-runtime', '-P', '--sched-period', '-D', '--sched-deadline'},
    'caffeinate': {'-t', '-w'},
    # macOS's arch: arch -arm64 cmd, arch -arch arm64 cmd, -e NAME=value.
    'arch': {'-arch', '-e', '-d'},
    'xcrun': {'--sdk', '-sdk', '--toolchain', '-toolchain'},
    'setpriv': {'--ruid', '--euid', '--reuid', '--rgid', '--egid', '--regid', '--groups',
                '--inh-caps', '--ambient-caps', '--bounding-set', '--securebits',
                '--pdeathsig', '--selinux-label', '--apparmor-profile', '--landlock-access',
                '--landlock-rule', '--ptracer', '--seccomp-filter'},
    'prlimit': {'-p', '--pid', '-o', '--output'},
    'unshare': {'--propagation', '--setgroups', '--map-user', '--map-group', '--map-users',
                '--map-groups', '-S', '--setuid', '-G', '--setgid', '-R', '--root', '-w',
                '--wd', '--monotonic', '--boottime', '--load-interp'},
    'doas': {'-C', '-u'},
}
# A program that runs another command after one more word: chrt's
# priority (optional since util-linux 2.42, so only a number), taskset's
# mask.
WRAPPER_OPERANDS = {'chrt': re.compile(r'\d+'), 'taskset': re.compile(r'.*')}
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
OTHER_REPOSITORY = ('This commit chooses its repository, work tree or index (--git-dir, '
                    '--work-tree, core.worktree, GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE and '
                    'the like), which the privacy check cannot follow to read what it would '
                    'commit. Commit in that checkout instead: cd /path/to/checkout, or git -C '
                    '/path/to/checkout commit (' + PRIVACY_DECISION + ').')
LIST_READ = ('The private list is the owner\'s and stays unread: check with python3 '
             'scripts/privacy-check.py --status, which never prints it (' + PRIVACY_DECISION + ').')
PUBLISHED_EXPANSION = ('Text this command publishes comes from a variable or another command, '
                       'which the privacy check cannot read. Write it in the command, in a '
                       "quoted here-document (\"$(cat <<'EOF' ... EOF)\", or <<'EOF' for "
                       'stdin), or in a file passed with -F, --file or --body-file.')
REUSED_COMMIT = ('This commit takes its message or author from another commit (-C, -c, '
                 '--fixup, --squash or --amend), which the privacy check cannot read here: '
                 'name one that exists before the command runs, or write the message.')
REUSED_EARLIER = ('An earlier command in this call ({command}) can change the commit this one '
                  'takes its message or author from, or leave it a merge message, and the guard '
                  'reads them before the call runs. Run that command first, then commit in '
                  'the next call (or name the commit by its full hash).')
AUTHOR_PATTERN = ('This commit\'s --author is not Name <address>: git would name the author '
                  'of the latest commit it matches, and which commit that is depends on the '
                  'locale, the log encoding and .mailmap, so the guard cannot tell whom git '
                  'would name. Give the author as Name <address>.')
SOURCE_FOLDER = ('gh repo create names the repository after its --source folder, which the '
                 'guard cannot place here: name the repository, or give the folder as a path.')
PUBLISHED_FILE = ('A file this command publishes must exist before the command runs, so the '
                  'privacy check can read it: write it in an earlier command.')
PUBLISHED_STDIN = ('Text this command reads from stdin can be checked only from a '
                   'here-document given to that command itself, not through a pipe or '
                   'another redirection; pass a file instead.')
WRITTEN_FILE = ('This command writes a file that it also publishes, sends or commits, so the '
                'privacy check would read the file before the command changes it. Write the '
                'file in one command, then publish or commit it in the next.')
RELEASE_ASSET = ('This would upload a release asset, whose contents and name the privacy check '
                 'cannot read here (an archive\'s files among them). Release assets are the '
                 "owner's to add, on the release's page on GitHub (" + PRIVACY_DECISION + ').')
REPO_PUSH = ('gh repo create --push pushes the source folder\'s commits itself, past the '
             'guard\'s push rules, whether or not that checkout runs the privacy hook. Create '
             'the repository without --push, then push with git push in the next command ('
             + PRIVACY_DECISION + ').')
REPO_ASKS = ('gh repo create with no words asks its questions, and one answer pushes the '
             'folder\'s commits past the guard\'s push rules. Name the repository and who sees '
             'it (gh repo create OWNER/NAME --private), without --push.')
REPO_BUILT = ('Write gh repo create\'s options and operands as they are: the shell builds or '
              'expands one of them (a variable, a command\'s output, braces or a pattern), so '
              'the guard cannot tell whether it is --push.')
GH_TERMINAL = ('Run gh without a terminal (not under script or unbuffer), with every text in '
               'an option or a file it names: given one, gh asks for what it is not given and '
               'reads the answers (from stdin, an editor or a recovery file), which the guard '
               'does not, and gh pr create with no --head asks where to push the branch, then '
               'pushes it past the guard\'s push rules.')
GH_RECOVER = ('Give gh the title and body with --title and --body-file instead of --recover: '
              'the guard does not read a recovery file, and gh publishes what it holds.')
GH_EDITOR = ('Give gh the text with --body or --body-file (gh gist edit: the file to put in, '
             '--add or --remove) instead of an editor: gh sends what the editor writes, even '
             'with no terminal, and the guard cannot read it first.')
GH_OPTION_FIRST = ('Write gh\'s options after the command\'s name (gh pr view 5 --web, not gh pr '
                   '--web view 5): gh reads them in either place, and the guard finds the name '
                   'only where no option comes before it. -R and --repo may come first.')
GH_NOT_ITS_OWN = ('This is not one of gh\'s own commands or an alias gh had before this call: '
                  'an extension, or an alias the call sets or writes, runs what the guard '
                  'cannot read. Run the gh command it stands for.')
GH_ALIAS_CHANGED = ('This call changes gh\'s aliases, or may write gh\'s configuration, before '
                    'it uses an alias, and the guard reads aliases as they were before the '
                    'call. Use the alias in a call of its own, or the gh command it stands for.')
SHELL_ALIAS_DEFINED = ('Run the command itself rather than defining a shell alias: the shell '
                       'expands an alias on a later line, and the guard does not read its text.')
HOOK_CHANGED = ('This command pushes after changing what the push would run (the privacy hook, '
                'core.hooksPath or another git setting, scripts/privacy-check.py, or the branch '
                'checked out), or after writing a file the guard cannot place, and the guard '
                'reads the hook before the command runs. Make the change in one command, then '
                'push in the next (' + PRIVACY_DECISION + ').')
UNREAD_VARIABLE = ('This command sets {name} to a value the guard cannot read before it runs '
                   '(for, select, read, mapfile, getopts, printf -v, ${{{name}:=...}} or a '
                   'declare -n reference). Set it with {name}=value, or use another name.')
TOO_MANY_FOLDERS = ('This command can end up in more folders than the guard follows: each cd '
                    'that may fail and is not followed by || exit, with more commands after it, '
                    'doubles them. Make each step its own subshell, (cd sub && make), or split '
                    'the command.')
# Words that start a compound command or a group, in which an exit or a
# failed command may not end the shell.
COMPOUND_WORDS = {'if', 'then', 'else', 'elif', 'fi', 'while', 'until', 'do', 'done', 'case',
                  'esac', 'for', 'select', 'function', '{', '}', '!', '[[', 'coproc'}
# How many folders (with their directory stacks and settings) the guard
# follows a command through, and how many questions it asks git on the
# way: each folder is checked, and a script of cd lines joined by ;
# doubles them at each line.
STATE_LIMIT = 1024
GIT_QUERY_LIMIT = 400
RUNTIME_WORDS = ('xargs and find -exec add words when they run (files, flags, destinations), '
                 'which the guard cannot read before. Name each one in the command itself.')
ENVIRONMENT_DUMP = ('This would print the whole environment, which may hold the private list. '
                    'Name the variables you need instead (printenv HOME); the list is the '
                    "owner's and stays unread (" + PRIVACY_DECISION + ').')
# The list's own path and name, and the globs that could reach its file.
LIST_REFERENCE = re.compile(r'\.config/[^/\s]*brick|private-words|\$\{?BRICKSON_PRIVATE_WORDS'
                            r'|printenv\s+BRICKSON_PRIVATE_WORDS|XDG_CONFIG_HOME\}?["\']?/[^/\s]*brick'
                            r'|\b(?:declare|typeset)\b[^;&|\n]*\bBRICKSON_PRIVATE_WORDS\b',
                            re.IGNORECASE)
CONFIG_FOLDER = re.compile(r'(?:\.config|XDG_CONFIG_HOME\}?)["\']?/([^/\s"\';&|()<>]*)'
                           r'(?:/([^/\s"\';&|()<>]*))?', re.IGNORECASE)
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
    # gh issue develop makes a branch on GitHub, named by --name.
    ('issue', 'develop'): ({'--name', 'n'}, set()),
    ('issue', 'reopen'): ({'--comment', 'c'}, set()),
    ('release', 'create'): ({'--title', '--notes', 't', 'n'}, {'--notes-file', 'F'}),
    ('release', 'edit'): ({'--title', '--notes', '--tag', 't', 'n'}, {'--notes-file', 'F'}),
    # A gist's files are its operands (gh gist edit's second), or stdin for -.
    ('gist', 'create'): ({'--desc', '--filename', 'd', 'f'}, set()),
    ('gist', 'edit'): ({'--desc', '--filename', 'd', 'f'}, {'--add', 'a'}),
    ('repo', 'create'): ({'--description', '--homepage', 'd', 'h'}, set()),
    ('repo', 'edit'): ({'--description', '--homepage', '--add-topic', 'd', 'h'}, set()),
    ('repo', 'fork'): ({'--fork-name'}, set()),
    # A new repository's name, and a new name, are their first operand.
    ('repo', 'rename'): (set(), set()),
    # gh gist rename <gist> <old> <new>: the new name is a gist file's.
    ('gist', 'rename'): (set(), set()),
    ('project', 'create'): ({'--title'}, set()),
    ('project', 'copy'): ({'--title'}, set()),
    ('project', 'edit'): ({'--title', '--readme', '--description', 'd'}, set()),
    ('project', 'item-create'): ({'--title', '--body'}, set()),
    ('project', 'item-edit'): ({'--title', '--body', '--text'}, set()),
    ('project', 'field-create'): ({'--name', '--single-select-options'}, set()),
    # An Actions variable's name is its operand; with no --body or
    # --env-file, gh reads its value from stdin.
    ('variable', 'set'): ({'--body', 'b'}, {'--env-file', 'f'}),
    # A label's name is its first operand.
    ('label', 'create'): ({'--description', '--color', 'd', 'c'}, set()),
    ('label', 'edit'): ({'--description', '--color', '--name', 'd', 'c', 'n'}, set()),
    ('pr', 'revert'): ({'--title', '--body', 't', 'b'}, {'--body-file', 'F'}),
    # A key is its file, or stdin with none, and the account's GPG keys
    # are public, user IDs and all (github.com/<user>.gpg).
    ('gpg-key', 'add'): ({'--title', 't'}, set()),
    ('ssh-key', 'add'): ({'--title', 't'}, set()),
    ('repo', 'deploy-key', 'add'): ({'--title', 't'}, set()),
    # An autolink's key prefix and address are its operands.
    ('repo', 'autolink', 'create'): (set(), set()),
}
# gh's commands that take --editor (-e): gh pr comment and gh issue comment
# run the editor even with no terminal (gh's commentable.go); the others
# need one, which the guard refuses already.
GH_EDITOR_COMMANDS = {('pr', 'create'), ('pr', 'comment'), ('issue', 'create'),
                      ('issue', 'comment')}
# gh's commands whose third word names the command (gh repo deploy-key add).
GH_SUBGROUPS = {('repo', 'autolink'), ('repo', 'deploy-key')}
# The commands above that send a key, from their file or stdin.
GH_KEYS = {('gpg-key', 'add'), ('ssh-key', 'add'), ('repo', 'deploy-key', 'add')}
# Options of those commands that take a value which is not published, where
# their operands matter: gh gist edit --remove names a file to drop.
GH_OTHER_VALUES = {('gist', 'edit'): {'--remove', 'r'},
                   ('issue', 'develop'): {'--base', 'b', '--branch-repo', '--repo', 'R'},
                   # A release's operands are its tag, then the assets to upload.
                   ('release', 'create'): {'--target', '--discussion-category',
                                           '--notes-start-tag'},
                   ('repo', 'create'): {'--gitignore', 'g', '--license', 'l', '--remote', 'r',
                                        '--source', 's', '--team', 't', '--template', 'p'},
                   ('repo', 'fork'): {'--remote-name', '--org'},
                   ('ssh-key', 'add'): {'--type'},
                   ('variable', 'set'): {'--env', 'e', '--org', 'o', '--visibility', 'v',
                                         '--repos', 'r'}}
# gh's repository option, which a command takes after its name too, and
# which takes the next word even at the end of a cluster (-yR o/r).
GH_REPOSITORY = {'--repo', 'R', '--hostname'}
# gh's own commands (gh --help, gh 2.89), with their aliases: those that take
# a subcommand, and those that do not, help topics among them. Any other
# first word is an alias, read from gh alias list, or an extension.
GH_GROUPS = {'agent-task', 'agent-tasks', 'agent', 'agents', 'alias', 'attestation', 'at',
             'auth', 'cache', 'codespace', 'cs', 'config', 'extension', 'extensions', 'ext',
             'gist', 'gpg-key', 'issue', 'label', 'org', 'pr', 'preview', 'project', 'release',
             'repo', 'ruleset', 'rs', 'run', 'search', 'secret', 'ssh-key', 'variable',
             'workflow'}
GH_LEAVES = {'api', 'browse', 'completion', 'copilot', 'help', 'licenses', 'status', 'version',
             'accessibility', 'actions', 'environment', 'exit-codes', 'formatting', 'mintty',
             'reference'}
# gh's options that a command written after them still sees as its own.
GH_HELP = ('--help', '-h', '--version')
# Words the shell may change before gh reads them: a variable, a command's
# output, braces and patterns.
SHELL_BUILT = re.compile(r'[$`{}*?\[]')
# gh pr create's and gh issue create's options that take a value (their
# --help), which may take a word that looks like --recover.
GH_CREATE_VALUES = {
    ('pr', 'create'): {'--assignee', 'a', '--base', 'B', '--body', 'b', '--body-file', 'F',
                       '--head', 'H', '--label', 'l', '--milestone', 'm', '--project', 'p',
                       '--recover', '--reviewer', 'r', '--template', 'T', '--title', 't'},
    ('issue', 'create'): {'--assignee', 'a', '--body', 'b', '--body-file', 'F', '--label', 'l',
                          '--milestone', 'm', '--project', 'p', '--recover', '--template', 'T',
                          '--title', 't'}}
# GitHub takes release assets at this host (gh release upload uses it).
UPLOADS_HOST = 'uploads.github.com'
# Programs that change a file's mode or remove it, which can turn a hook off
# without writing to it.
FILE_CHANGERS = {'chmod', 'chown', 'chgrp', 'chflags', 'chattr', 'setfacl', 'xattr', 'rm',
                 'rmdir', 'unlink', 'truncate', 'shred'}
# Git commands that change files in the work tree, at the paths they name.
GIT_FILE_CHANGERS = {'rm', 'mv', 'restore', 'checkout', 'switch', 'reset', 'clean',
                     'checkout-index', 'read-tree', 'sparse-checkout'}
# The file tools, and the arguments that name the file or folder each opens,
# changes or searches.
FILE_TOOLS = {'Read': ('file_path',), 'Edit': ('file_path',), 'MultiEdit': ('file_path',),
              'Write': ('file_path',), 'NotebookEdit': ('notebook_path',), 'Grep': ('path',),
              'Glob': ('path',)}
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
    '--reset-author', '--no-reset-author', '--short', '--signoff', '--status',
    '--untracked-files', '--verbose', '--verify', '--no-author', '--no-file',
    '--no-reuse-message', '--no-reedit-message', '--no-fixup', '--no-squash',
    '--no-template', '--no-amend', '--no-message', '--no-trailer', '--no-date',
    '--no-cleanup'}
# A git commit option's --no- form undoes it where it was given before
# (git's parse-options: the last one given wins).
COMMIT_NEGATIONS = {'--no-author': {'--author'}, '--no-file': {'-F', '--file'},
                    '--no-reuse-message': {'-C', '--reuse-message'},
                    '--no-reedit-message': {'-c', '--reedit-message'},
                    '--no-fixup': {'--fixup'}, '--no-squash': {'--squash'},
                    '--no-template': {'-t', '--template'}, '--no-amend': {'--amend'},
                    '--no-message': {'-m', '--message'}, '--no-trailer': {'--trailer'},
                    '--no-date': {'--date'}, '--no-cleanup': {'--cleanup'}}
# Git commands that can move HEAD, or leave a merge message or a picked
# commit's author for the next commit, whatever they are given.
HEAD_MOVERS = {'merge', 'pull', 'rebase', 'cherry-pick', 'revert', 'commit', 'am',
               'update-ref', 'bisect', 'filter-branch', 'fast-import', 'subtree'}
# Git commands that move another ref (a remote branch, a tag, a stash, a
# note, a reflog entry) unless they are given only a reading word first
# (git remote's -v comes before its subcommand).
REF_READS = {'fetch': None, 'push': None, 'gc': None, 'maintenance': None,
             'stash': {'list', 'show'}, 'notes': {'list', 'show', 'get-ref'},
             'remote': {'show', 'get-url'},
             'worktree': {'list', 'lock', 'unlock'}, 'replace': {'-l', '--list'}}
# The options that make git branch or git tag list rather than make, move
# or delete (builtin/branch.c, builtin/tag.c): --sort, --format, --column,
# branch's -v and tag's -a do not.
LISTS = {'branch': {'-l', '--list', '--show-current', '--contains', '--no-contains',
                    '--merged', '--no-merged', '--points-at'},
         'tag': {'-l', '--list', '--contains', '--no-contains', '--merged', '--no-merged',
                 '--points-at', '-v', '--verify'}}
# A revision whose commit a command can change without moving a branch:
# a reflog entry or an upstream (@{2}, @{u}, @{-1}) and the refs git
# writes as it works (ORIG_HEAD, FETCH_HEAD).
VOLATILE_REVISION = re.compile(r'@\{|(?:ORIG|FETCH|MERGE|CHERRY_PICK|REVERT|REBASE)_HEAD|AUTO_MERGE')
FULL_HASH = re.compile(r'[0-9a-f]{40}|[0-9a-f]{64}')
# Settings and environment variables that name a commit's author or committer.
IDENTITY_SETTINGS = {'user.name', 'user.email', 'author.name', 'author.email',
                     'committer.name', 'committer.email'}
IDENTITY_VARIABLES = ('GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME',
                      'GIT_COMMITTER_EMAIL')
# What makes a commit take another repository, work tree or index than its
# folder's, where the privacy check reads the staged changes.
REPOSITORY_OPTIONS = ('--git-dir', '--work-tree')
REPOSITORY_SETTINGS = {'core.worktree', 'core.bare'}
REPOSITORY_VARIABLES = ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                        'GIT_OBJECT_DIRECTORY')
# The Contents API names the file it writes in its address
# (PUT /repos/{owner}/{repo}/contents/{path}), and GitHub shows the file
# under that name.
CONTENTS_PATH = re.compile(r'repos/[^/]+/[^/]+/contents/(.+)')
# GitHub tools whose text is published, and those that write files.
TOOLS_PUBLISH = {'create_pull_request', 'update_pull_request', 'issue_write', 'create_issue',
                 'update_issue', 'add_issue_comment', 'update_issue_comment',
                 'add_reply_to_pull_request_comment', 'add_comment_to_pending_review',
                 'pull_request_review_write', 'create_gist', 'update_gist',
                 'create_or_update_file', 'push_files', 'delete_file', 'create_branch',
                 'create_repository', 'fork_repository'}


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


def raw_tokens(text):
    """The words the shell's reading in segments makes of text (posix shlex
    with whitespace ' \\t\\r' and ;&|()<>\\n grouped as punctuation),
    each as written: quotes and escapes kept, so a quote that opens inside
    a word (--body="a b") stays in that word. ValueError as shlex raises it."""
    punctuation, whitespace = set(';&|()<>\n'), set(' \t\r')
    stops = punctuation | whitespace
    index, length = 0, len(text)
    while index < length:
        if text[index] in whitespace:
            index += 1
            continue
        start = index
        if text[index] in punctuation:
            while index < length and text[index] in punctuation:
                index += 1
            yield text[start:index]
            continue
        while index < length and text[index] not in stops:
            char = text[index]
            if char == '\\':
                if index + 1 >= length:
                    raise ValueError('No escaped character')
                index += 2
            elif char in '\'"':
                index += 1
                while index < length and text[index] != char:
                    index += 2 if char == '"' and text[index] == '\\' else 1
                if index >= length:
                    raise ValueError('No closing quotation')
                index += 1
            else:
                index += 1
        yield text[start:index]


def segments(command, preserve_quotes=False):
    """Split into (words, preceding separator), keeping && and || for cd.
    Words inside $(...), `...` and sh -c '...' are split in turn. With
    preserve_quotes, each word is as written (raw_tokens)."""
    text, saved = protect_substitutions(without_shell_comments(command.replace('\\\n', ' ')))
    if preserve_quotes:
        lexer = raw_tokens(text)
    else:
        lexer = shlex.shlex(text, posix=True, punctuation_chars=';&|()<>\n')
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


# A shell assignment: NAME=value, or NAME+=value, which appends.
ASSIGNMENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\+?=')


def assignment(word, environment=None, here=None):
    """The variable an assignment word sets and the value it gets, as the
    shell gives it: HOME's and XDG_CONFIG_HOME's expanded (assigned_value),
    and NAME+=value appended to the value before (the one environment
    holds, else the hook's), unknown where that was unknown."""
    environment = environment if environment is not None else {}
    key, _, value = word.partition('=')
    if key in ('HOME+', 'XDG_CONFIG_HOME+', 'HOME', 'XDG_CONFIG_HOME'):
        value = assigned_value(value, environment, here)
    if key.endswith('+'):
        key = key[:-1]
        before = environment[key] if key in environment else os.environ.get(key)
        value = (before or '') + value
    return key, value


def strip_wrappers(words, inherited=None, runtime_inputs=None, here=None):
    """Drop VAR=value assignments and wrappers such as env, sudo, command.
    HOME and XDG_CONFIG_HOME take their values as the shell assigns them
    in the folder here (assigned_value)."""
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
        if ASSIGNMENT.match(first):
            key, value = assignment(first, environment, here)
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
                # arch's and xcrun's options are whole words (-arm64, -sdk).
                if len(option) > 2 and not option.startswith('--') and wrapper not in ('arch', 'xcrun'):
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
                if option.startswith('--') and wrapper != 'xcrun':
                    # getopt_long takes a unique beginning of a long option
                    # for the whole option (setpriv --pdeath for --pdeathsig).
                    name, equal, value = option.partition('=')
                    values = WRAPPER_VALUE_OPTIONS.get(wrapper, set())
                    matches = [full for full in values if full.startswith(name)
                               and full.startswith('--')]
                    if name not in values and len(matches) == 1:
                        option = matches[0] + equal + value
                        words = [option] + words[1:]
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
                if wrapper == 'unshare':
                    if option in ('-w', '--wd') and len(words) > 1:
                        directory = words[1]
                    elif option.startswith('--wd='):
                        directory = option.partition('=')[2]
                count = 2 if option in WRAPPER_VALUE_OPTIONS.get(wrapper, set()) else 1
                words = words[count:]
            # One env uses its last -C; nested env commands change again.
            if directory is not None:
                directories.append(directory)
            # timeout's mandatory duration can be fractional and carry a unit.
            if wrapper == 'timeout' and words and re.fullmatch(r'(?:\d+(?:\.\d*)?|\.\d+)[smhd]?', words[0]):
                words = words[1:]
            operand = WRAPPER_OPERANDS.get(wrapper)
            if operand and words and operand.fullmatch(words[0]):
                words = words[1:]
        else:
            break
    return words, environment, directories


# The options of programs that run a command they are given, as their
# help lists them (util-linux's flock and script, procps-ng's watch, and
# macOS's script): '' is a switch, 'value' takes the rest of the word or
# the next word, 'optional' only the rest of the word or a value after =.
# Each long option names its short letter. script's -t takes the next
# word on macOS and only an attached one in util-linux, so script is read
# both ways (SCRIPT_LINUX).
RUNNER_OPTIONS = {
    'flock': ({'s': '', 'x': '', 'e': '', 'u': '', 'n': '', 'o': '', 'F': '', 'h': '', 'V': '',
               'w': 'value', 'E': 'value'},
              {'--shared': 's', '--exclusive': 'x', '--unlock': 'u', '--nonblock': 'n',
               '--nonblocking': 'n', '--nb': 'n', '--close': 'o', '--no-fork': 'F',
               '--verbose': 'verbose', '--help': 'h', '--version': 'V', '--timeout': 'w',
               '--wait': 'w', '--conflict-exit-code': 'E'}),
    'watch': ({'b': '', 'c': '', 'C': '', 'e': '', 'g': '', 'p': '', 'r': '', 't': '', 'w': '',
               'x': '', 'h': '', 'v': '', 'd': 'optional', 'n': 'value', 'q': 'value',
               's': 'value'},
              {'--beep': 'b', '--color': 'c', '--no-color': 'C', '--errexit': 'e',
               '--chgexit': 'g', '--precise': 'p', '--no-rerun': 'r', '--no-title': 't',
               '--no-wrap': 'w', '--no-linewrap': 'w', '--exec': 'x', '--help': 'h',
               '--version': 'v', '--differences': 'd', '--interval': 'n', '--equexit': 'q',
               '--shotsdir': 's'}),
    'script': ({'a': '', 'e': '', 'f': '', 'F': '', 'k': '', 'q': '', 'r': '', 'p': '', 'd': '',
                'h': '', 'V': '', 'c': 'value', 'E': 'value', 'I': 'value', 'O': 'value',
                'B': 'value', 'T': 'value', 'm': 'value', 'o': 'value', 't': 'value'},
               {'--append': 'a', '--return': 'e', '--flush': 'f', '--force': 'force',
                '--quiet': 'q', '--help': 'h', '--version': 'V', '--command': 'c',
                '--echo': 'E', '--log-in': 'I', '--log-out': 'O', '--log-io': 'B',
                '--log-timing': 'T', '--logging-format': 'm', '--output-limit': 'o',
                '--timing': 'timing'}),
}
RUNNER_OPTIONS['script-linux'] = ({**RUNNER_OPTIONS['script'][0], 't': 'optional'},
                                  RUNNER_OPTIONS['script'][1])
RUNNER_LONG_KINDS = {'verbose': '', 'force': '', 'timing': 'optional'}
RUNNER_OPTION = ('The guard reads {program}\'s options as {program} reads them, and does not '
                 'know {option}. Spell each option as {program} --help lists it, or run the '
                 'command on its own.')
# Git commands that only read, which may take words xargs or find adds
# (git grep is not one: its -O runs a program).
RUNTIME_READS = {'status', 'diff', 'log', 'show', 'rev-parse', 'ls-files', 'blame',
                 'check-ignore', 'check-attr', 'cat-file', 'ls-tree', 'shortlog'}
# find's actions that run a command, which ends at ; or at a + after {}.
FIND_ACTIONS = {'-exec', '-execdir', '-ok', '-okdir'}
# find's options before its start points; -D and -O take a value.
FIND_LEADING = re.compile(r'-[HLP]|-D|-O\d*')


def runner_options(program, words, reading=None):
    """The options at the start of words, read as getopt_long reads them
    for flock, watch or script (with a +: the first operand ends them):
    short options cluster, and a long option may be any beginning of its
    name that names one kind of option. As (letter, value) pairs, and the
    words after them. An option the guard does not know is refused: it
    may take the next word, which would hide the command. reading names
    another table for the same program (script-linux)."""
    short, long = RUNNER_OPTIONS[reading or program]
    options, index = [], 0
    while index < len(words):
        word = words[index]
        if word == '--':
            index += 1
            break
        if not word.startswith('-') or word == '-':
            break
        if word.startswith('--'):
            name, equal, value = word.partition('=')
            matches = [name] if name in long else [full for full in long if full.startswith(name)]
            letters = {long[full] for full in matches}
            kinds = {short.get(letter, RUNNER_LONG_KINDS.get(letter)) for letter in letters}
            if not matches or len(kinds) != 1:
                deny(RUNNER_OPTION.format(program=program, option=name))
            letter, kind = sorted(letters)[0], kinds.pop()
            if kind == 'value' and not equal:
                index += 1
                value = words[index] if index < len(words) else None
            options.append((letter, value if equal or kind == 'value' else None))
        else:
            for offset, letter in enumerate(word[1:], 1):
                kind = short.get(letter)
                if kind is None:
                    deny(RUNNER_OPTION.format(program=program, option='-' + letter))
                rest = word[offset + 1:]
                if kind == 'value':
                    if not rest:
                        index += 1
                        rest = words[index] if index < len(words) else None
                    options.append((letter, rest))
                    break
                if kind == 'optional':
                    options.append((letter, rest or None))
                    break
                options.append((letter, None))
        index += 1
    return options, words[index:]


def find_commands(words, cwd):
    """The commands find runs (-exec, -ok, -execdir, -okdir), as
    (folder, words): from every action word, so a test's operand that
    spells one (-name -exec) does not hide the next. -exec and -ok run
    where find runs; -execdir and -okdir in each found file's folder,
    which for a start point is its parent. A part of a find that the
    shell's ( ) split off (find . \\( -exec ... \\)) starts with an
    option; its start points are unknown."""
    starts = []
    if os.path.basename(words[0]) == 'find':
        index = 1
        while index < len(words) and FIND_LEADING.fullmatch(words[index]):
            index += 2 if words[index] == '-D' else 1
        while index < len(words) and not words[index].startswith('-') and words[index] not in (
                '(', ')', '!', ','):
            starts.append(words[index])
            index += 1
        starts = starts or ['.']
    here = []
    for start in starts:
        folder = changed_directory(cwd, start) if cwd is not None else None
        here += [os.path.dirname(folder.rstrip(os.sep)) or os.sep, folder] if folder else [None]
    here = list(dict.fromkeys(here or [None]))
    commands = []
    for index, action in enumerate(words):
        if action not in FIND_ACTIONS:
            continue
        end = index + 1
        while end < len(words) and not (words[end] == ';' or (
                words[end] == '+' and words[end - 1] == '{}')):
            end += 1
        command = words[index + 1:end]
        if not command:
            continue
        # find fills in each {} when it runs, as xargs adds its input. In
        # sh -c 'script' name {}, find's words are the script's $1, $2,
        # which it reads as any words given there.
        unwrapped = strip_wrappers(command)[0]
        script = shell_script_index(unwrapped)
        before = command[:len(command) - len(unwrapped) + script + 1] if script else command
        runtime = any('{}' in word for word in before)
        text = ('xargs ' if runtime else '') + shlex.join(command)
        for folder in ([cwd] if action in ('-exec', '-ok') else here):
            commands.append((folder, text))
    return commands


def runner_commands(words, cwd):
    """The commands a program runs that are not its own words, as (cwd,
    command text): find's (find_commands), flock's command or -c script,
    watch's, which it runs with sh -c unless -x, and script's -c command
    or, as macOS's script runs it, the command after its file."""
    program = os.path.basename(words[0])
    if program == 'find' or program.startswith('-'):
        return find_commands(words, cwd)
    if program not in RUNNER_OPTIONS or program == 'script-linux':
        return []
    commands = []
    if program == 'script':
        # macOS's reading, then util-linux's: each command either finds.
        for reading in ('script', 'script-linux'):
            options, rest = runner_options(program, words[1:], reading)
            commands += [(cwd, value) for letter, value in options if letter == 'c' and value]
            if len(rest) > 1:
                commands.append((cwd, shlex.join(rest[1:])))
        return list(dict.fromkeys(commands))
    options, rest = runner_options(program, words[1:])
    letters = [letter for letter, _ in options]
    if program == 'flock':
        rest = rest[1:]  # the lock file or descriptor
        if rest[:1] in (['-c'], ['--command']):
            commands += [(cwd, script) for script in rest[1:2]]
        elif rest:
            commands.append((cwd, shlex.join(rest)))
    elif program == 'watch':
        if rest:
            commands.append((cwd, shlex.join(rest) if 'x' in letters else ' '.join(rest)))
    return commands


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


def git(context, *args, raw=False):
    """git's answer to a read-only query, run where the command would run
    it, or None when git cannot answer: as text, or as its bytes when raw.
    The guard asks before the whole command runs, so the same question has
    the same answer each time it is asked: a script checked in many
    folders asks each one once."""
    cwd, options, overrides = context
    if cwd is None:
        return None  # an inherited directory-stack destination is unknown
    return git_answer(cwd, tuple(options), tuple(sorted(overrides.items(), key=str)), args,
                      raw)


# How many questions the guard has asked git (git_answer's cache misses).
GIT_QUERIES = [0]


@functools.lru_cache(maxsize=4096)
def git_answer(cwd, options, overrides, args, raw=False):
    GIT_QUERIES[0] += 1
    environment = os.environ.copy()
    for key, value in overrides:
        if value is None:
            environment.pop(key, None)
        else:
            environment[key] = value
    try:
        result = subprocess.run(['git', '-C', cwd, *options, *args], capture_output=True,
                                timeout=5, env=environment,
                                **({} if raw else {'encoding': 'utf-8', 'errors': 'replace'}))
    except (OSError, ValueError, subprocess.SubprocessError):
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


def check_push(args, context, branch_changed=False, git_state=None):
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
    if git_state is not None:
        check_hook_unchanged(git_state, context)
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
    """gh's command names (a group's two, or three under GH_SUBGROUPS),
    then its other words. Cobra finds a command by
    its names past options written among them (gh pr --squash=true merge 5
    merges), and the guard reads the names, so an option before the last
    one is refused, but for --help, -h and --version, which only show
    help, and -R, --repo and --hostname, which are dropped with their
    value. After the names those stay for the parsers, which take them as
    an option's value where gh does (gh pr create --title -R)."""
    plain, skip, names = [], False, []
    for index, word in enumerate(words):
        wanted = (1 if not names[:1] or names[0] not in GH_GROUPS
                  else 3 if tuple(names[:2]) in GH_SUBGROUPS else 2)
        if (names and len(names) >= wanted) or word == '--':
            plain.extend(words[index:])
            break
        if skip:
            skip = False
        elif word in ('-R', '--repo', '--hostname'):
            skip = True
        elif word.startswith(('--repo=', '--hostname=', '-R')):
            continue  # the attached forms, --repo=OWNER/REPO and -ROWNER/REPO
        elif word in GH_HELP:
            plain.append(word)
        elif word.startswith('-') and word != '-':
            deny(GH_OPTION_FIRST)
        else:
            plain.append(word)
            names.append(word)
    return plain


def check_gh(words, cwd, environment, git_state=None):
    written = gh_command_words(words[1:])
    if written[:1] and written[0] not in GH_GROUPS | GH_LEAVES and written[0] not in GH_HELP \
            and git_state is not None and gh_aliases_may_change(git_state, cwd, environment):
        deny(GH_ALIAS_CHANGED)
    plain = expand_gh_alias(written, cwd, environment)
    if plain[:1] and plain[0] not in GH_GROUPS | GH_LEAVES and plain[0] not in GH_HELP:
        deny(GH_NOT_ITS_OWN)
    if plain[:1] and plain[0] in ('extension', 'extensions', 'ext') and plain[1:2] == ['exec']:
        deny(GH_NOT_ITS_OWN)  # runs an extension
    if git_state is not None and git_state.get('terminal'):
        deny(GH_TERMINAL)
    # gh's own aliases: gh pr new is gh pr create, and so on.
    if len(plain) >= 2 and plain[0] in ('issue', 'pr', 'release', 'gist', 'repo') \
            and plain[1] == 'new':
        plain[1] = 'create'
    if tuple(plain[:2]) == ('repo', 'autolink') and plain[2:3] == ['new']:
        plain[2] = 'create'
    if plain[:2] == ['release', 'upload'] or release_assets(plain) \
            or gh_uploads(words[1:], plain, environment):
        deny(RELEASE_ASSET)
    if plain[:1] == ['copilot']:
        deny(COPILOT)  # the Copilot CLI agent, which can push by itself
    if plain[:2] == ['repo', 'create']:
        texts, files = GH_PUBLISHES[('repo', 'create')]
        values = texts | files | GH_OTHER_VALUES[('repo', 'create')] | GH_REPOSITORY
        if not [word for word in without_redirections(plain[2:]) if word != '--']:
            deny(REPO_ASKS)
        if gh_unread_word(plain[2:], values, texts) is not None:
            deny(REPO_BUILT)
        if gh_switch(plain[2:], values, '--push'):
            deny(REPO_PUSH)
    if tuple(plain[:2]) in GH_CREATE_VALUES:
        pairs, _ = gh_arguments(plain[2:], GH_CREATE_VALUES[tuple(plain[:2])] | GH_REPOSITORY)
        if any(option == '--recover' for option, _ in pairs):
            deny(GH_RECOVER)
    if tuple(plain[:2]) in GH_EDITOR_COMMANDS:
        texts, files = GH_PUBLISHES[tuple(plain[:2])]
        values = (texts | files | GH_CREATE_VALUES.get(tuple(plain[:2]), set())
                  | GH_REPOSITORY)
        if gh_switch(plain[2:], values, '--editor', 'e'):
            deny(GH_EDITOR)
    if plain[:2] == ['gist', 'edit']:
        # With no file to put in, to add or to remove, gh opens an editor
        # on the gist's file (its --desc too), and sends what it writes.
        texts, files = GH_PUBLISHES[('gist', 'edit')]
        pairs, operands = gh_arguments(plain[2:], texts | files | GH_OTHER_VALUES[('gist', 'edit')]
                                       | GH_REPOSITORY)
        source = operands[1] if len(operands) > 1 else ''
        if not source and not any(value for option, value in pairs
                                  if option in ('--add', 'a', '--remove', 'r')):
            deny(GH_EDITOR)
    if git_state is not None:
        note_gh_text(plain, cwd, git_state)
        if plain[:1] == ['alias'] and plain[1:2] in (['set'], ['import'], ['delete']):
            git_state['gh_aliases_changed'] = True
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
            elif option in ('--body', '--body-file', '--repo', '--hostname'):
                if not equal:
                    index += 1
            elif word.startswith('-') and not word.startswith('--'):
                for offset, letter in enumerate(word[1:], 1):
                    if letter == 'a':
                        deny(MERGE)
                    if letter in ('b', 'F', 'R'):
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


def gh_unread_word(args, value_options, texts):
    """A word of a gh command, after its names, that the shell may change
    before gh reads it (SHELL_BUILT), or None. The text an option in texts
    publishes is left out: note_gh_text reads it, and refuses a $ in it."""
    index = 0
    args = without_redirections(args)
    while index < len(args):
        word = checked = args[index]
        value = None
        if word.startswith('--'):
            option, equal, _ = word.partition('=')
            if option in value_options:
                checked = option if option in texts else word
                if not equal:
                    value = option
        elif word.startswith('-') and word != '-':
            for offset, letter in enumerate(word[1:], 1):
                if letter in value_options:
                    checked = word[:offset + 1] if letter in texts else word
                    if not word[offset + 1:]:
                        value = letter
                    break
        if SHELL_BUILT.search(checked):
            return word
        if value is not None:
            index += 1
            if value not in texts and index < len(args) and SHELL_BUILT.search(args[index]):
                return args[index]
        index += 1
    return None


def gh_aliases_may_change(git_state, cwd, environment):
    """Whether an earlier command in the call changes gh's aliases (gh alias
    set, import or delete) or may write in gh's configuration folder, which
    gh alias list, read before the call, does not see."""
    if git_state.get('gh_aliases_changed'):
        return True
    settings = {**os.environ, **(environment or {})}
    if settings.get('GH_CONFIG_DIR'):
        folder = settings['GH_CONFIG_DIR']
    elif settings.get('XDG_CONFIG_HOME'):
        folder = os.path.join(settings['XDG_CONFIG_HOME'], 'gh')
    else:
        folder = os.path.join(settings.get('HOME') or '~', '.config', 'gh')
    return any(overlaps(write, (cwd, folder)) for write in git_state.get('writes', ()))


def gh_switch(args, value_options, name, letter=None):
    """Whether gh's boolean option name (--push), or its letter (-e), ends
    up on, read as gh's flag parser reads it: the last --name or
    --name=VALUE before --, where VALUE is on unless Go reads it as false,
    the letter anywhere in a cluster before a letter that takes a value
    (-we), or as -e=VALUE, and a value option takes the next word whatever
    it is (--description --push describes, -b -e has a body)."""
    on, index = False, 0
    args = without_redirections(args)
    while index < len(args):
        word = args[index]
        if word == '--':
            break
        if word.startswith('--'):
            option, equal, value = word.partition('=')
            if option == name:
                on = not equal or value not in ('0', 'f', 'F', 'false', 'FALSE', 'False')
            elif option in value_options and not equal:
                index += 1
        elif word.startswith('-') and word != '-':
            for offset, short in enumerate(word[1:], 1):
                if short == letter:
                    rest = word[offset + 1:]
                    if rest.startswith('='):
                        on = rest[1:] not in ('0', 'f', 'F', 'false', 'FALSE', 'False')
                        break
                    on = True
                elif short in value_options:
                    if not word[offset + 1:]:
                        index += 1
                    break
        index += 1
    return on


def release_assets(plain):
    """The files gh release create uploads as assets: its operands after
    the tag (gh release create --help)."""
    if plain[:2] != ['release', 'create']:
        return []
    texts, files = GH_PUBLISHES[('release', 'create')]
    _, operands = gh_arguments(plain[2:], texts | files | GH_OTHER_VALUES[('release', 'create')]
                               | GH_REPOSITORY)
    return operands[1:]


def names_uploads(words):
    """Whether a request names the host that takes release assets, as a
    word or an option's value after =."""
    return any(parsed_url(text)[1] == UPLOADS_HOST
               for word in words for text in (word, word.partition('=')[2]) if text)


def gh_uploads(words, plain, environment):
    """Whether gh sends a request to the host that takes release assets:
    its --hostname or GH_HOST, or gh api given that host's address."""
    hosts = list(option_values(words, {'--hostname'}))
    hosts.append((environment or {}).get('GH_HOST', ''))
    if plain[:1] == ['api']:
        hosts += gh_arguments(plain[1:], GH_API_VALUES)[1]
    return any(host and parsed_url(host)[1] == UPLOADS_HOST for host in hosts)


def note_gh_text(plain, cwd, git_state):
    """The text a gh command puts on GitHub: titles, bodies, comments,
    notes, descriptions and names, the files they come from, a gist's files
    and an API write's fields and input."""
    command = tuple(plain[:3] if tuple(plain[:2]) in GH_SUBGROUPS else plain[:2])
    if command in GH_PUBLISHES:
        texts, files = GH_PUBLISHES[command]
        pairs, operands = gh_arguments(plain[len(command):], texts | files
                                       | GH_OTHER_VALUES.get(command, set()) | GH_REPOSITORY)
        values = [value for option, value in pairs if option in texts]
        names = [value for option, value in pairs if option in files]
        gist_files, unpublished = [], []
        if command in GH_KEYS:
            # The key's file is read, not its name, which stays here.
            names += operands[:1] or ['-']
            unpublished = operands[:1]
        elif command == ('gist', 'create'):
            # With no file named, gh reads the gist from stdin (gh gist
            # create --help: cat cool.txt | gh gist create).
            names += operands or ['-']
            gist_files = operands
        elif command == ('gist', 'edit'):
            names += operands[1:2]  # the first is the gist
            gist_files = [value for option, value in pairs if option in files]
        elif command == ('gist', 'rename'):
            gist_files = operands[2:3]
        elif command == ('variable', 'set'):
            values += operands[:1]
            if not any(option in texts | files for option, _ in pairs):
                names.append('-')
        elif command[0] == 'label':
            values += operands[:1]
        elif command in (('release', 'create'), ('repo', 'create'), ('repo', 'rename')):
            # A release's tag, and a repository's name, are public too.
            values += operands[:1]
            sources = [value for option, value in pairs if option in ('--source', 's')]
            if command == ('repo', 'create') and not operands and sources:
                # With no name, gh names it after the source folder (gh repo
                # create --help): its path as written (filepath.Abs), and,
                # where a link leads elsewhere, where it leads too.
                source = os.path.expanduser(sources[-1])
                if literal_text(sources[-1], git_state) is None:
                    deny(PUBLISHED_EXPANSION)
                if cwd is None and not os.path.isabs(source):
                    deny(SOURCE_FOLDER)
                try:
                    path = os.path.join(cwd or '', source)
                    for folder in (os.path.normpath(path), os.path.realpath(path)):
                        values.append(os.fsencode(os.path.basename(folder)).decode())
                except (ValueError, UnicodeError):
                    deny(SOURCE_FOLDER)  # no folder can have that name
        # A value option gh takes but the guard reads as a switch (--jq,
        # --template) would leave the text it hides an operand, so every
        # operand the shell gives as written is read too, but a gist's
        # files, which gh shows under their base names only.
        values += [operand for operand in operands if operand not in gist_files + unpublished
                   and literal_text(operand, git_state) is not None]
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
        if contents_paths(operands):
            note_published(git_state, 'gh api file name', contents_paths(operands))


def graphql_read(texts):
    """Whether a GraphQL request only reads: it writes only through a
    mutation, which needs the word, and none of its text (texts) holds it.
    A text the shell builds (None) could hold anything."""
    return None not in texts and not any(re.search(r'mutation', text, re.IGNORECASE)
                                         for text in texts)


def parsed_url(word):
    # curl takes one, two or three slashes after the scheme's colon
    # (https:/api.github.com), as one address.
    scheme = re.match(r'(https?):/+', word, re.IGNORECASE)
    if scheme:
        word = scheme[1] + '://' + word[scheme.end():]
    try:
        url = urlsplit(word if '://' in word else 'https://' + word)
        # API clients normally remove literal dot segments before sending.
        url = url._replace(path=posixpath.normpath(url.path))
        # curl decodes %-escapes in the host (api%2egithub.com), and a
        # trailing dot names the same host. With IDN support (libidn2,
        # UTS #46) it also maps fullwidth, squared and subscript letters
        # and other full stops (U+3002, U+FF0E) to the ASCII host: NFKC and
        # case folding as the current Unicode has them, then the idna codec.
        host = unquote(url.hostname or '')
        if not host.isascii():
            host = unicodedata.normalize('NFKC', unicodedata.normalize('NFKC', host).casefold())
            try:
                host = host.encode('idna').decode('ascii')
            except UnicodeError:
                pass  # not a name IDNA can map (an empty label): read as written
        return url, host.lower().rstrip('.')
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


HTTPIE_VALUES = {'--auth', '-a', '--auth-type', '-A', '--session', '--session-read-only',
                 '--verify', '--cert', '--cert-key', '--proxy', '--timeout', '--max-redirects',
                 '--pretty', '--style', '--print', '-p', '--format-options', '--output', '-o',
                 '--ssl', '--ciphers', '--raw', '--response-charset', '--response-mime',
                 '--default-scheme'}


def httpie_option(words, index, raw):
    """Read the option at words[index] as HTTPie's parser does: (the index
    after it and its value, the --raw body so far). The last --raw wins."""
    option, equal, value = words[index].partition('=')
    if option in HTTPIE_VALUES:
        if not equal:
            index += 1
            if index >= len(words):
                deny(UNKNOWN)
            value = words[index]
        if option == '--raw':
            raw = value
    return index + 1, raw


def httpie_request(words):
    """Read the method, the request items and the --raw body. HTTPie's
    parser (argparse) takes an option anywhere, after the address too,
    and everything after -- as an item."""
    index, method, raw = 1, None, None
    while index < len(words):
        word = words[index]
        if github_api_host(word):
            items, index = [], index + 1
            while index < len(words):
                if words[index] == '--':
                    items += words[index + 1:]
                    break
                if words[index].startswith('-') and words[index] != '-':
                    index, raw = httpie_option(words, index, raw)
                else:
                    items.append(words[index])
                    index += 1
            has_data = raw is not None or any(re.search(r'(?<![:=])(?::=|=)(?!=)', item)
                                               for item in items)
            return method or ('POST' if has_data else 'GET'), items, raw
        if word.startswith('-'):
            # flags or attached option values are not HTTP methods
            index, raw = httpie_option(words, index, raw)
            continue
        if word.upper() in {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'}:
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


def contents_paths(words):
    """The file paths a Contents API request names in its address."""
    return [match[1] for match in map(CONTENTS_PATH.fullmatch, api_paths(words)) if match]


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


def cd_options(operands):
    """cd's options (bash's -L, -P, -e and -@, zsh's -q and -s), then --:
    whether it reads a link's .. where the link leads (the last of -L and
    -P), and the words after them. cd - goes to the folder before, which
    is unknown."""
    letters = ''
    while operands and re.fullmatch(r'-[LPe@qs]+', operands[0]):
        letters += operands[0][1:]
        operands = operands[1:]
    if operands[:1] == ['--']:
        operands = operands[1:]
    return letters.rfind('P') > letters.rfind('L'), operands


def changed_directory(cwd, destination, environment=None, physical=True):
    """The folder a cd, -C or chdir to destination reaches from cwd, or None
    when the guard cannot tell: the shell builds destination otherwise than
    from ~, ~+, $HOME, $XDG_CONFIG_HOME or $PWD (expanded from the
    shell's environment, or the hook's when it has none), or cwd is
    unknown. ~- and cd - name the folder before the last cd, which the
    guard does not follow."""
    if destination == '-':
        return None
    try:
        destination = expanded_tilde(destination, environment, cwd)
        if destination is not None and ('$' in destination or '`' in destination):
            destination = with_config_variables(destination, environment, cwd)
    except (ValueError, UnicodeError):
        return None
    if destination is None:
        return None
    if not os.path.isabs(destination) and cwd is None:
        return None
    # As chdir (git -C, env -C, cd -P) reaches it, through links, or as
    # the shell's cd reaches it by default, by name (link/.. is the
    # folder link is in). Either way sub/.. is the folder itself, so the
    # folders a script's cd lines reach stay few however many ways it
    # reaches them.
    try:
        path = os.path.join(cwd or '', destination)
        return os.path.realpath(path) if physical else os.path.normpath(path)
    except (ValueError, UnicodeError, OSError):
        return None


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
        with open(path, 'rb') as file:
            data = file.read()
    except OSError:
        deny(PUBLISHED_FILE)
    return decoded_texts(data)


def git_readings(*fields):
    """Each reading of a commit's fields, as git gave their bytes
    (decoded_texts): a tuple of texts per reading, the first field's
    paired with the second's. git commit writes a name or message that is
    not UTF-8 as Latin-1 turned into UTF-8, so one kept as Latin-1 bytes
    (a commit an import made, a configured name) is published."""
    texts = [decoded_texts(field) for field in fields]
    return [tuple(one[min(number, len(one) - 1)] for one in texts)
            for number in range(max(len(one) for one in texts))]


def decoded_texts(data):
    """A file's text as each encoding it may be read in: UTF-8, or, when
    it is not, also Windows-1252 and Latin-1 (git commit -F with
    i18n.commitEncoding keeps a message's bytes as they are), and UTF-16
    when it starts with a byte order mark."""
    texts = []
    if data[:2] in (b'\xff\xfe', b'\xfe\xff'):
        texts.append(data.decode('utf-16', errors='replace'))
    try:
        return texts + [data.decode('utf-8')]
    except UnicodeDecodeError:
        return texts + [data.decode('utf-8', errors='replace'),
                        data.decode('cp1252', errors='replace'), data.decode('latin-1')]


def literal_words(command):
    """The words of a command, as the shell will pass them: those in which
    every $ and backtick is text (single-quoted or escaped), and those the
    shell builds from a variable or another command. Anything this simple
    reading gets wrong is in neither, and so counts as built."""
    words, built_words, word, built, quote = set(), set(), [], False, None
    index = 0

    def end():
        # A here-document read with cat stands as a marker: one whose text
        # the shell builds builds the word.
        text = unmarked(''.join(word))
        if not word:
            return
        if built or any(document[4] for document in substituted_documents(text)):
            built_words.add(text)
        else:
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
    return words, built_words


def ends_with_value(word, value):
    """Whether value is a word, an option's or a field's value after =, or
    a short option's attached value, after any switches (-cbtext)."""
    if not word.endswith(value):
        return False
    prefix = word[:len(word) - len(value)]
    return not prefix or prefix.endswith('=') or bool(re.fullmatch(r'-[A-Za-z]+=?', prefix))


def literal_text(value, git_state):
    """The text the shell passes for value, or None when it builds value
    from a variable or another command: value holds a $ or backtick outside
    a here-document read with cat that the shell gives as written
    (substituted_documents), and is not, or does not end, a
    word in which they are text. Inside double quotes the shell drops the
    backslash of \\$ and \\`, which the guard's word splitting keeps. The
    same text built elsewhere in the command may be the word value came
    from, so it counts as built: one word never vouches for another."""
    if not EXPANSION_START.search(without_documents(value, built=False)):
        return value
    candidates = list(dict.fromkeys([value, re.sub(r'\\([$`])', r'\1', value)]))
    if any(ends_with_value(word, candidate) for candidate in candidates
           for word in git_state.get('built_words', ())):
        return None
    for candidate in candidates:
        if any(ends_with_value(word, candidate) for word in git_state.get('literal_words', ())):
            return candidate
    return None


def note_published(git_state, label, values=(), files=(), cwd=None, texts=(), readings=()):
    """Remember text a command would publish, for check_privacy: values are
    the shell's words, files name files (or - for stdin) the command reads
    its text from, texts are data already read, such as a request file's
    content, in which a $ or a backtick is only text, and readings are one
    such text in each encoding it may be read in, whose findings are each
    reported once. A word the shell would build from a variable or another
    command is refused: what it becomes cannot be read here."""
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
        published.append((label + ' file', tuple(published_files(filename, cwd, git_state))))
    published.extend((label, str(text)) for text in texts)
    if readings:
        published.append((label, tuple(readings)))
    git_state['publishes'] = True


def effective_directory(context):
    """The directory a git command runs in, after its -C options."""
    cwd, options, environment = context
    for index, option in enumerate(options[:-1]):
        if option == '-C' and cwd is not None:
            cwd = changed_directory(cwd, options[index + 1], environment)
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
            elif option in COMMIT_NEGATIONS:
                # --no-author undoes an earlier --author, and so on.
                pairs = [pair for pair in pairs if pair[0] not in COMMIT_NEGATIONS[option]]
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


def selects_repository(context):
    """Whether git's options or variables choose another repository, work
    tree or index than the folder's (git --git-dir, -c core.worktree,
    GIT_INDEX_FILE and the like)."""
    _, options, environment = context
    for index, option in enumerate(options):
        if option.partition('=')[0] in REPOSITORY_OPTIONS:
            return True
        if option in ('-c', '--config-env') and index + 1 < len(options):
            if options[index + 1].partition('=')[0].lower() in REPOSITORY_SETTINGS:
                return True
        elif option.startswith('--config-env='):
            if option.partition('=')[2].partition('=')[0].lower() in REPOSITORY_SETTINGS:
                return True
    return any(environment.get(key) for key in REPOSITORY_VARIABLES) or any(
        key.startswith('GIT_CONFIG_KEY_') and str(value).lower() in REPOSITORY_SETTINGS
        for key, value in environment.items())


def note_commit(git_state, args, context, paths):
    """Remember a commit: what it records (its message and trailers, the
    files it reads a message from, an author or committer it is given), and
    the repository whose staged changes and added paths it would take."""
    if selects_repository(context):
        deny(OTHER_REPOSITORY)
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
    note_reused_commit(git_state, args, pairs, context, directory)
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
        signed = re.fullmatch(rb'(.*) <(.*)> \d+ [+-]\d{4}',
                              git(context, 'var', variable, raw=True) or b'')
        if signed:
            identities.append((directory, git_readings(signed[1], signed[2]), where))
            read += 1
    if not read:
        note_published(git_state, 'the commit author', given)
    for author in (value for option, value in pairs if option == '--author'):
        signed = re.fullmatch(r'(.*?)\s*<(.*)>', author.strip())
        if not signed:
            # Not Name <address>: git takes the identity of the latest
            # commit whose author matches it, ignoring case, from every ref
            # (git commit --help; builtin/commit.c, find_author_by_nickname),
            # matched in the locale and the log encoding git runs with and
            # after .mailmap, and kept in that commit's own bytes.
            deny(AUTHOR_PATTERN)
        if literal_text(author, git_state) is None:
            deny(PUBLISHED_EXPANSION)
        identities.append((directory, [(signed[1], signed[2])], 'the commit author'))
    git_state.setdefault('commits', []).append(
        (directory, [*adds, *((directory, path, False) for path in paths)]))


def git_moves(subcommand, args):
    """What a git command can change that a later commit in the same call
    takes, as (head, refs, picks): whether it can move HEAD or leave a
    merge message (MERGE_MSG, SQUASH_MSG) for the next commit; whether it
    can move another ref a commit may name (a remote branch, a tag, a
    stash, a note under --all, a reflog entry); and whether it can stop
    with a picked commit's author pending (CHERRY_PICK_HEAD). Reads (git
    branch --show-current, tag -l, stash list, remote -v) and path
    checkouts (checkout --theirs a, checkout main -- a) move nothing."""
    operands = [arg for arg in args if not arg.startswith('-')]
    before = args[:args.index('--')] if '--' in args else args
    if subcommand in HEAD_MOVERS:
        # Only a cherry-pick that stops leaves its commit's author for the
        # next commit (CHERRY_PICK_HEAD); a rebase, a pull or an am that
        # stops does not (REBASE_HEAD).
        return True, True, subcommand == 'cherry-pick' and not picks_nothing(args)
    if subcommand in ('checkout', 'switch'):
        # A checkout of paths (a path after --, or --ours, --theirs or
        # --patch) leaves HEAD and the reflog as they are. Making a branch
        # at HEAD leaves HEAD's commit, but adds a reflog entry (HEAD@{1}).
        paths = subcommand == 'checkout' and (
            ('--' in args and args[args.index('--') + 1:])
            or {'--ours', '--theirs', '--patch', '-p'} & set(args))
        if paths:
            return False, False, False
        return not leaves_files(subcommand, args), True, False
    if subcommand == 'fetch':
        # Only with -u (--update-head-ok) may it move the checked-out branch.
        return any(re.fullmatch(r'-[a-zA-Z46]*u.*', arg) or (
            len(arg) >= len('--update-h') and '--update-head-ok'.startswith(arg))
            for arg in before), True, False
    if subcommand == 'reset':
        # Any reset of the branch sets ORIG_HEAD and a reflog entry; one
        # of paths (after --, or -p) moves nothing.
        if ('--' in args and args[args.index('--') + 1:]) or {'-p', '--patch'} & set(args):
            return False, False, False
        return any(not arg.startswith('-') for arg in before), True, False
    if subcommand == 'symbolic-ref':
        moves = len(operands) >= 2 or bool({'-d', '--delete'} & set(args))
        return moves, moves, False
    if subcommand == 'replace':
        moves = bool(operands) and not REF_READS['replace'] & set(args)
        return moves, moves, False
    if subcommand == 'reflog':
        # git reflog [show] reads; delete, expire and drop take entries out.
        return False, operands[:1] in (['delete'], ['expire'], ['drop']), False
    if subcommand in ('branch', 'tag'):
        lists = any(arg.partition('=')[0] in LISTS[subcommand]
                    or (subcommand == 'tag' and re.fullmatch(r'-n\d*', arg)) for arg in args)
        # An upstream option changes what @{u} names, with no operand.
        upstream = subcommand == 'branch' and any(
            arg.partition('=')[0] in ('-u', '--set-upstream-to', '--unset-upstream', '--track')
            or re.fullmatch(r'-[a-zA-Z]*u.*', arg) for arg in args)
        return False, upstream or (bool(operands) and not lists), False
    if subcommand in REF_READS:
        reads = REF_READS[subcommand]
        if reads is None:
            return False, True, False
        if subcommand == 'remote':
            words = [arg for arg in args if arg not in ('-v', '--verbose')]
            return False, bool(words) and words[0] not in reads, False
        if subcommand == 'replace':
            return False, bool(args) and args[0] not in reads, False
        return False, not (operands[:1] and operands[0] in reads) and not (
            subcommand in ('notes', 'remote') and not args), False
    return False, False, False


def picks_nothing(args):
    """Whether a cherry-pick is given -n (--no-commit), which leaves no
    picked commit's author pending: in a cluster before a letter that takes
    a value (-Xminimal is a strategy option), or as any beginning of
    --no-commit that names it alone; the last of it and --commit wins."""
    nothing = False
    for arg in args:
        if arg == '--':
            break
        if arg.startswith('--'):
            name = arg.partition('=')[0]
            if len(name) >= len('--no-co') and '--no-commit'.startswith(name):
                nothing = True
            elif len(name) >= len('--com') and '--commit'.startswith(name):
                nothing = False
        elif arg.startswith('-'):
            for letter in arg[1:]:
                if letter in 'mXS':
                    break  # the rest of the word is its value
                if letter == 'n':
                    nothing = True
    return nothing


def commit_switches(args):
    """The long options a git commit is given that take no value
    (--amend, --reset-author), read as commit_options reads values, so
    an option's value (-m --amend) is never one."""
    switches, index = [], 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            break
        if arg.startswith('--'):
            option, equal, _ = arg.partition('=')
            if option in COMMIT_VALUE_LONG:
                index += 0 if equal else 1
            elif option == '--no-amend':
                switches = [switch for switch in switches if switch != '--amend']
            else:
                switches.append(option)
        elif arg.startswith('-') and arg != '-':
            for offset, letter in enumerate(arg[1:], 1):
                if letter in COMMIT_VALUE_SHORT:
                    if not arg[offset + 1:] and letter != 'S':
                        index += 1
                    break
        index += 1
    return switches


def note_reused_commit(git_state, args, pairs, context, directory):
    """Remember what a commit takes from another one, as git commit does
    (builtin/commit.c): -C and -c its message and author, --fixup and
    --squash its message (whose subject they quote), --amend the last
    commit's author, and its message unless it is given one (--squash
    keeps it, --fixup takes nothing from it); with no message, a pending
    MERGE_MSG or SQUASH_MSG; and during a cherry-pick, the picked
    commit's author. The last of --reset-author and --no-reset-author
    decides whether an author is reused, and --author replaces it."""
    switches = commit_switches(args)
    options = {option for option, _ in pairs}
    resets = [switch for switch in switches if switch in ('--reset-author', '--no-reset-author')]
    keeps_author = '--author' not in options and resets[-1:] != ['--reset-author']
    reuses = options & {'-C', '-c', '--reuse-message', '--reedit-message'}
    messages = reuses | (options & {'-m', '--message', '-F', '--file'})
    reused = []
    for option, value in pairs:
        if option in reuses:
            reused.append((value, keeps_author))
        elif option in ('--fixup', '--squash'):
            # --fixup=amend:<commit> and reword:<commit> take its message.
            reused.append((re.sub(r'^(?:amend|reword):', '', value), False))
    if '--amend' in switches and not reuses and '--fixup' not in options:
        if not messages:
            reused.append(('HEAD', keeps_author))
        elif keeps_author:
            reused.append(('HEAD', None))  # the author alone
    # --amend takes HEAD's message, never a pending one.
    pending = not messages and '--fixup' not in options and '--amend' not in switches
    # The guard reads them before the call runs: an earlier command in it
    # that moves HEAD, another ref, or writes in git's folder changes what
    # this commit takes, and a setting what @{u} names. A full hash names
    # the same commit either way.
    written = 'a command that writes in git\'s folder' if writes_git_folder(
        git_state, context) else None
    head = git_state.get('head_moved') or written
    refs = git_state.get('refs_moved') or written
    for revision, _ in reused:
        moved = head if revision == 'HEAD' else refs
        if VOLATILE_REVISION.search(revision):
            moved = moved or git_state.get('config_changed')
        if moved and not FULL_HASH.fullmatch(revision):
            deny(REUSED_EARLIER.format(command=moved))
    if head and (pending or (keeps_author and git_state.get('picked'))):
        deny(REUSED_EARLIER.format(command=head))
    if keeps_author and git(context, 'rev-parse', '-q', '--verify', 'CHERRY_PICK_HEAD'):
        reused.append(('CHERRY_PICK_HEAD', None))
    if pending or '--squash' in options:
        for name in ('MERGE_MSG', 'SQUASH_MSG') if pending else ('SQUASH_MSG',):
            path = git(context, 'rev-parse', '--git-path', name)
            if not path or directory is None:
                continue
            path = os.path.join(directory, path)
            # Read before the call runs, so one its commands write is refused.
            git_state.setdefault('read_files', []).append((directory, path))
            if os.path.isfile(path):
                note_published(git_state, 'the pending commit message',
                               files=[path], cwd=directory)
    for revision, author in reused:
        if literal_text(revision, git_state) is None:
            deny(PUBLISHED_EXPANSION)
        # git commit takes the commit converted to its own
        # i18n.commitEncoding: from the encoding the commit names, or its
        # bytes as they are where the two are the same (logmsg_reencode).
        # So both are read: in UTF-8, whatever log encoding the command or
        # the repository sets, and as git keeps it. log.showSignature would
        # put gpg's lines before the fields.
        found = git(context, 'log', '-1', '--no-show-signature', '--encoding=UTF-8',
                    '--format=%H%x00%an%x00%ae%x00%B', '--end-of-options', revision, '--',
                    raw=True)
        if found is None or found.count(b'\0') < 3:
            deny(REUSED_COMMIT)
        sha, name, address, message = found.split(b'\0', 3)
        stored = git(context, 'cat-file', 'commit', sha.decode('ascii', 'replace'), raw=True)
        if stored is None:
            deny(REUSED_COMMIT)
        header, _, stored_message = stored.partition(b'\n\n')
        stored_author = re.search(rb'^author (.*) <([^>]*)>', header, re.MULTILINE)
        if author is not None:
            note_published(git_state, 'the reused commit message',
                           readings=decoded_texts(message) + decoded_texts(stored_message))
        if author is not False:
            readings = git_readings(name, address)
            if stored_author:
                readings += git_readings(*stored_author.groups())
            git_state.setdefault('identities', []).append(
                (directory, readings, 'the commit author'))


def writes_git_folder(git_state, context):
    """Whether an earlier command in the call writes a file the guard
    cannot place, or one in the repository's git folder (a ref, HEAD,
    MERGE_MSG, a reflog), which changes what a commit reuses."""
    writes = [write for write in git_state.get('writes', ()) if write[1] != INLINE_CODE]
    if not writes:
        return False
    folders = git(context, 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir')
    if folders is None:
        return True
    places = {os.path.realpath(folder) for folder in folders.splitlines() if folder}
    for cwd, path in writes:
        paths = changed_paths(cwd, path)
        if paths is None or any(one == place or one.startswith(place.rstrip(os.sep) + os.sep)
                                for one in paths for place in places):
            return True
    return False


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


# Inline code that names nothing of git's (git, HEAD, refs): it may write
# any file, but not, by mistake, one in git's folder.
INLINE_CODE = '\0inline code'
CODE_NAMES_GIT = re.compile(r'(?i:git)|HEAD|refs')


def inline_code_text(args, stdin=None):
    """The code an interpreter is given on its command line (-c, -e) or
    in its own here-document, or None when the guard cannot read it."""
    for index, arg in enumerate(args):
        if arg == '-':
            break
        if arg in ('--eval', '--print') or re.fullmatch(r'-[a-zA-Z]*[ceEp]', arg):
            return args[index + 1] if index + 1 < len(args) else None
    if stdin is None or HERE_DOCUMENTS[stdin]['built']:
        return None
    return HERE_DOCUMENTS[stdin]['text']


def note_writes(git_state, words, raw_words, unwrapped, shell_cwd, cwd, stdin=None):
    """Remember the files a command writes, as (directory, path), with None
    for a path the guard cannot name: the shell's > and >> targets, the
    files tee, cp, mv and the like are given, sed -i and perl -i, dd of=,
    curl and wget downloads, and a patch or an interpreter's inline code,
    which may write anything (INLINE_CODE where it names nothing of git's).
    stdin is the here-document the command reads."""
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
    elif program == 'patch':
        paths = [None]
    elif INTERPRETERS.fullmatch(program) and inline_code(args, cwd):
        code = inline_code_text(args, stdin)
        paths = [INLINE_CODE if code is not None and not CODE_NAMES_GIT.search(code) else None]
    elif program in FILE_CHANGERS:
        # A mode or a removal changes no file's text, but can turn a hook off.
        git_state.setdefault('changes', []).extend((cwd, path) for path in operands)
    writes.extend((cwd, path) for path in paths)


def resolved(cwd, path):
    """A path as an absolute one, or None when the guard cannot tell where
    it is: the shell builds it, or its directory is unknown."""
    if path is None or path == INLINE_CODE or '$' in path or '`' in path:
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


def config_change(args):
    """What git config changes: (section, True) for a section it removes or
    renames, (key, False) for a key it sets, adds, replaces or unsets, and
    None for a read. Names are in lower case; an edit, which may change
    anything, is ('', True)."""
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
                        ['rename-section'], ['edit']):
        action, operands = operands[0], operands[1:]
    if action == 'edit' or options & {'--edit', '-e'}:
        return '', True
    key = operands[0].lower() if operands else ''
    if (action in ('remove-section', 'rename-section')
            or options & {'--remove-section', '--rename-section'}):
        return key, True
    if action in ('get', 'list') or any(
            option.startswith(('--get', '--list')) or option == '-l' for option in options):
        return None
    if action in ('set', 'unset') or len(operands) >= 2 or any(
            option.startswith(('--unset', '--replace-all', '--add')) for option in options):
        return key, False
    return None


def sets_identity(args):
    """Whether git config changes a commit's author or committer (user.*,
    author.*, committer.*): sets, adds, replaces or unsets one, or removes
    or renames their section. A read changes nothing."""
    change = config_change(args)
    if change is None:
        return False
    name, section = change
    if section:
        return name in ('', 'user', 'author', 'committer')
    return name in IDENTITY_SETTINGS


def sets_hooks(args):
    """Whether git config may change which hooks git runs: core.hooksPath,
    the core section, or a file it includes (include.path, includeIf)."""
    change = config_change(args)
    if change is None:
        return False
    name, section = change
    if section:
        return name in ('', 'core', 'include') or name.startswith('includeif')
    return name == 'core.hookspath' or name.startswith(('include.', 'includeif.'))


def leaves_files(subcommand, args):
    """Whether git checkout or switch leaves the work tree as it is: it is
    given nothing to check out, or only a new branch to make where HEAD is
    (-b, -B, -c, -C or --orphan, with no start point and no paths)."""
    creating = 'bB' if subcommand == 'checkout' else 'cC'
    named = ('--orphan', '--create', '--force-create')
    operands, index = [], 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            operands += args[index + 1:]
            break
        if arg in named:
            index += 2  # the new branch's name follows
            continue
        if re.fullmatch(r'-[a-zA-Z]+', arg):
            letters = arg[1:]
            hit = next((offset for offset, letter in enumerate(letters) if letter in creating),
                       None)
            # The new branch's name is the rest of the word, or the next one.
            if hit is not None and not letters[hit + 1:]:
                index += 1
        elif arg == '-' or not arg.startswith('-'):
            operands.append(arg)  # a branch, a commit or a path (- is the last branch)
        index += 1
    return not operands


def changed_paths(cwd, path):
    """The absolute paths a command's path names, as the shell gives them
    (a glob's matches, before the command runs), or None when the guard
    cannot tell: the shell builds it, a brace expands it, or its folder is
    unknown."""
    if path in (None, INLINE_CODE) or re.search(r'\{[^}]*(?:,|\.\.)[^}]*\}', path):
        return None
    absolute = resolved(cwd, path)
    if absolute is None:
        return None
    if re.search(r'[*?[]', path):
        matches = glob.glob(os.path.join(cwd or os.sep, os.path.expanduser(path)))
        return [os.path.realpath(match) for match in matches] or [absolute]
    return [absolute]


def check_hook_unchanged(git_state, context):
    """A push runs the hook, its setting and the check it calls as they are
    when the push starts, and the guard reads them before the whole command
    runs. Refuse a push after a change to any of them in the same command:
    a git config change to the hooks, another branch checked out, or a file
    written, removed or given another mode in .githooks, git's own folder,
    git's settings files or scripts/privacy-check.py (or anywhere the guard
    cannot place)."""
    if git_state.get('hook_changed'):
        deny(HOOK_CHANGED)
    changed = [*git_state.get('writes', ()), *git_state.get('changes', ())]
    if not changed:
        return
    top = git(context, 'rev-parse', '--show-toplevel')
    folders = git(context, 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir')
    if top is None or folders is None:
        deny(HOOK_CHANGED)
    environment = {**os.environ, **{key: value for key, value in context[2].items()
                                    if value is not None}}
    home = environment.get('HOME') or os.path.expanduser('~')
    xdg = environment.get('XDG_CONFIG_HOME', '')
    places = [os.path.join(top, '.githooks'), os.path.join(top, 'scripts', 'privacy-check.py'),
              *folders.splitlines(), os.path.join(home, '.gitconfig'),
              os.path.join(xdg if os.path.isabs(xdg) else os.path.join(home, '.config'),
                           'git', 'config'), '/etc/gitconfig']
    for name in ('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM'):
        places += (git(context, 'var', name) or '').splitlines()
    places = {os.path.realpath(place) for place in places if place}
    for cwd, path in changed:
        paths = changed_paths(cwd, path)
        if paths is None or any(
                one == place or one.startswith(place.rstrip(os.sep) + os.sep)
                or place.startswith(one.rstrip(os.sep) + os.sep)
                for one in paths for place in places):
            deny(HOOK_CHANGED)


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


def declared(args, inherited, here=None):
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
        if equal and ASSIGNMENT.match(arg):
            key, value = assignment(arg, updates, here)
        if not context_variable(key):
            continue
        if set(letters) - set('xgr'):
            deny(UNKNOWN)
        if any(option.startswith('+') for option in options):
            updates[key] = None
        elif equal:
            if '$' in value or '`' in value or '\0' in value:
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


def names_list(command):
    """Whether a command names the private list, its folder or a config
    folder that holds it, as written or with its braces expanded
    (cat ~/.config/{,}b*/*)."""
    expanded = re.sub(r'\S+', lambda match: ' '.join(
        brace_expansions(match[0]) if len(match[0]) <= 1024 else (match[0],)), command)
    return any(LIST_REFERENCE.search(text) or names_list_glob(text) or names_config_folder(text)
               for text in dict.fromkeys([command, expanded]))


def names_list_glob(command):
    """Whether a glob could name the private list's file: a pattern for a
    folder in a config folder that brickson matches, followed by nothing or
    by a name that private-words.txt matches. Case does not count: the
    Mac's file system finds ~/.config/Brickson at ~/.config/brickson."""
    for match in CONFIG_FOLDER.finditer(command):
        folder, name = match[1].casefold(), (match[2] or '').casefold()
        if (any(char in folder for char in '*?[') and fnmatch.fnmatchcase('brickson', folder)
                and (not name or fnmatch.fnmatchcase('private-words.txt', name))):
            return True
    return False


def config_folders(environment=None):
    """The config folders the private list may be in, as real paths: the
    default one, and the one the checker reads it from when
    XDG_CONFIG_HOME is an absolute path (scripts/privacy-check.py,
    default_list_file)."""
    environment = os.environ if environment is None else environment
    home = environment.get('HOME') or os.path.expanduser('~')
    folders = [os.path.join(home, '.config')]
    configured = environment.get('XDG_CONFIG_HOME', '')
    if os.path.isabs(configured):
        folders.append(configured)
    return list(dict.fromkeys(os.path.realpath(folder) for folder in folders))


def check_file_tool(name, arguments, cwd):
    """Refuse a file tool that opens, changes or searches the private list
    or its folder, wherever the checker reads the list from, in any case:
    the Read and Edit deny rules name only the default folder, and the
    Mac's file system does not tell ~/.config/Brickson from it. Grep reads
    every file under its path, so it is refused a folder that holds the
    list too. A path no file can have (a NUL byte) is left to the tool."""
    for key in FILE_TOOLS[name]:
        value = arguments.get(key)
        if not isinstance(value, str) or not value:
            if name != 'Grep':
                continue
            value = cwd  # Grep searches the folder it runs in
        try:
            path = os.path.realpath(os.path.join(cwd, os.path.expanduser(value))).casefold()
        except (ValueError, UnicodeError):
            continue
        for config in config_folders():
            config = config.casefold()
            folder = os.path.join(config, 'brickson')
            if (path in (config, folder) or path.startswith(folder + os.sep)
                    or (name == 'Grep' and folder.startswith(path.rstrip(os.sep) + os.sep))):
                deny(LIST_READ)


CONFIG_VARIABLE = re.compile(r'\$(?:\{(HOME|XDG_CONFIG_HOME|PWD)\}'
                             r'|(HOME|XDG_CONFIG_HOME|PWD)(?![A-Za-z0-9_]))')


def variable_value(name, environment=None):
    """The value the shell gives $name: as an earlier command or this one
    set it (environment), else the hook's own; None when it is unset or
    the shell built it. An assignment's own $HOME, $XDG_CONFIG_HOME and
    leading ~ were the shell's values before it (HOME=~/x), the hook's."""
    environment = environment or {}
    value = environment[name] if name in environment else os.environ.get(name)
    if not value:
        return None
    if name in environment:
        def earlier(match):
            name = match[1] or match[2]
            return '\0' if name == 'PWD' else os.environ.get(name) or '\0'
        value = CONFIG_VARIABLE.sub(earlier, value)
        if value == '~' or value.startswith('~/'):
            value = (os.environ.get('HOME') or '\0') + value[1:]
    if '\0' in value or '$' in value or '`' in value:
        return None
    return value


DEFAULT_EXPANSION = re.compile(r'\$\{(HOME|XDG_CONFIG_HOME|PWD)(:?[-+=?])')


def with_defaults(text, environment=None, here=None):
    """text with each ${NAME:-word}, ${NAME-word}, ${NAME:+word} and the
    like of HOME, XDG_CONFIG_HOME and PWD as the shell gives it: NAME's
    value where it is set, else the word, itself expanded (an unset or
    empty value counts as unset); None where the guard cannot tell (a
    value the shell builds, a ${NAME:?} on an unset one, no closing }).
    The XDG idiom "${XDG_CONFIG_HOME:-$HOME/.config}" names the folder."""
    parts, index = [], 0
    while (match := DEFAULT_EXPANSION.search(text, index)):
        depth, end = 1, match.end()
        while end < len(text) and depth:
            if text[end] == '{' and text[end - 1] == '$':
                depth += 1
            elif text[end] == '}':
                depth -= 1
            end += 1
        if depth:
            return None
        name, operation, word = match[1], match[2].lstrip(':'), text[match.end():end - 1]
        given = environment[name] if environment and name in environment else os.environ.get(name)
        value = here if name == 'PWD' else variable_value(name, environment)
        if name == 'PWD':
            given = here
        if given and value is None:
            return None  # set, to a value the shell builds
        if word.startswith('~'):
            word = expanded_tilde(word, environment, here)
        if word is not None and ('$' in word or '`' in word):
            word = with_config_variables(word, environment, here)
        if operation == '+':
            result = word if given else ''
        elif given:
            result = value
        else:
            result = None if operation == '?' else word
        if result is None:
            return None
        parts += [text[index:match.start()], result]
        index = end
    return ''.join(parts) + text[index:]


def with_config_variables(text, environment=None, here=None):
    """text with $HOME and $XDG_CONFIG_HOME as the shell would expand them
    (a variable this command sets or unsets first included, and their
    default forms, with_defaults), and $PWD as the folder the command runs
    in (here), or None when the shell builds any other part of it, or one
    of them is unset or unknown."""
    if DEFAULT_EXPANSION.search(text):
        text = with_defaults(text, environment, here)
        if text is None:
            return None
    missing = []

    def value(match):
        name = match[1] or match[2]
        found = here if name == 'PWD' else variable_value(name, environment)
        if not found:
            missing.append(name)
        return found or ''
    text = CONFIG_VARIABLE.sub(value, text)
    if missing or '$' in text or '`' in text:
        return None
    return text


def tilde_home(environment=None):
    """The folder ~ names: HOME as the shell has it, or, when HOME is
    unset, the account's home, which bash takes from the password
    database. None when the shell builds HOME."""
    environment = environment or {}
    unset = (environment['HOME'] is None) if 'HOME' in environment else (
        os.environ.get('HOME') is None)
    if not unset:
        return variable_value('HOME', environment)
    try:
        return pwd.getpwuid(os.getuid()).pw_dir if pwd else None
    except (KeyError, OSError):
        return None


def assigned_value(value, environment=None, here=None):
    """HOME's or XDG_CONFIG_HOME's value as the shell assigns it: a ~ at
    its start or after a :, ~+, $PWD, $HOME and $XDG_CONFIG_HOME expanded
    from the folder the assignment runs in (here) and the values before
    it, and a NUL in place of a part the guard cannot tell, so that
    variable_value reads the whole value as unknown."""
    parts = []
    for part in value.split(':'):
        try:
            if part.startswith('~'):
                part = expanded_tilde(part, environment, here)
            if part is not None and ('$' in part or '`' in part):
                part = with_config_variables(part, environment, here)
        except (ValueError, UnicodeError):
            part = None
        parts.append('\0' if part is None else part)
    return ':'.join(parts)


def expanded_tilde(text, environment=None, here=None):
    """text with a leading ~ expanded as the shell would: ~ and ~/ to the
    HOME it sees, ~+ to the folder the command runs in (here), ~user to
    that user's home. None when the shell's value is unknown: ~- is the
    folder before the last cd, which the guard does not follow."""
    if not text.startswith('~'):
        return text
    prefix, slash, rest = text.partition('/')
    if prefix == '~':
        home = tilde_home(environment)
    elif prefix == '~+':
        home = here
    elif prefix == '~-':
        home = None
    else:
        home = os.path.expanduser(prefix)
        if home == prefix:
            return text  # no such user: the shell keeps the word as it is
    if home is None:
        return None
    return home + slash + rest


BRACE_SEQUENCE = re.compile(r'(-?\d+)\.\.(-?\d+)(?:\.\.-?\d+)?|([A-Za-z])\.\.([A-Za-z])(?:\.\.-?\d+)?')
# How many words, how long a word and how much text in all the guard
# expands braces in. No path is longer, and a mistake makes far fewer.
BRACE_LIMIT = 1024
BRACE_LENGTH = 65536
BRACE_TEXT = 1 << 21


def unquoted_characters(word):
    """Whether each character of word is outside quotes and not escaped,
    where the shell expands braces."""
    active, quote, escaped = [], None, False
    for char in word:
        if escaped:
            escaped = False
            active.append(False)
        elif quote:
            active.append(False)
            if char == quote:
                quote = None
            elif char == '\\' and quote == '"':
                escaped = True
        elif char == '\\':
            escaped = True
            active.append(False)
        elif char in '\'"':
            quote = char
            active.append(False)
        else:
            active.append(True)
    return active


def brace_once(word):
    """word with its first brace expression ({a,b} or {a..c}) expanded, as
    the words bash makes of it, or None when it has none. Braces in quotes
    or escaped are text, and ${ starts a variable; so is one with a space
    in it, which the shell's word can only hold from a quote. A range of
    numbers too long for the shell's integers gives nothing: no digit is a
    letter of a path the guard looks for."""
    active = unquoted_characters(word)
    for start, char in enumerate(word):
        if char != '{' or not active[start] or (start and word[start - 1] == '$'):
            continue
        depth, commas = 0, []
        for index in range(start, len(word)):
            if not active[index]:
                continue
            if word[index] == '{':
                depth += 1
            elif word[index] == '}':
                depth -= 1
                if not depth:
                    break
            elif word[index] == ',' and depth == 1:
                commas.append(index)
            elif word[index] in ' \t\n':
                break  # the shell split there, or a quote held it
        else:
            continue  # no closing brace: the shell keeps the word
        if word[index] != '}':
            continue
        prefix, body, suffix = word[:start], word[start + 1:index], word[index + 1:]
        if commas:
            edges = [start] + commas + [index]
            return [prefix + word[left + 1:right] + suffix for left, right in zip(edges, edges[1:])]
        sequence = BRACE_SEQUENCE.fullmatch(body)
        if sequence and sequence[1] is not None and max(map(len, sequence.group(1, 2))) > 19:
            continue
        if sequence and sequence[1] is not None:
            low, high = int(sequence[1]), int(sequence[2])
            step = 1 if high >= low else -1
            # bash pads every number as wide as a padded end ({01..10}).
            width = max(len(sequence[1]), len(sequence[2])) if any(
                re.fullmatch(r'-?0\d+', end) for end in sequence.group(1, 2)) else 0
            # Far past the limit, the first numbers stand for the rest.
            numbers = range(low, high + step, step)[:BRACE_LIMIT + 1]
            return [prefix + str(number).zfill(width) + suffix for number in numbers]
        if sequence:
            low, high = sorted((ord(sequence[3]), ord(sequence[4])))
            return [prefix + chr(code) + suffix for code in range(low, high + 1)]
    return None


@functools.lru_cache(maxsize=4096)
def brace_expansions(word):
    """The words bash makes of word's brace expressions, nested ones
    included (cat ~/.{config,x}/b*/*): word itself when it has none. A
    word longer than any path, or one that makes more than BRACE_LIMIT
    words or BRACE_TEXT characters (a long JSON body), is read as far as
    the limit reaches, and as it is written."""
    if '{' not in word or len(word) > BRACE_LENGTH:
        return [word]
    pending, done, seen, text = [word], [], {word}, len(word)
    while pending:
        current = pending.pop()
        expanded = brace_once(current)
        if expanded is None:
            done.append(current)
            continue
        for item in reversed(expanded):
            if item not in seen:
                seen.add(item)
                pending.append(item)
                text += len(item)
        if len(seen) > BRACE_LIMIT or text > BRACE_TEXT:
            return tuple(dict.fromkeys(done + pending + [word]))
    return tuple(done)


def word_pieces(word, raw=None):
    """The words bash makes of one word by brace expansion, expanded in
    its raw spelling (raw, with its quotes) where the guard has it, so a
    brace or comma in quotes ('{"a":1,"b":2}') stays text, then unquoted
    as the shell does. Without it, the shell's word is expanded."""
    if raw is None:
        return brace_expansions(word)
    if '{' not in raw:
        return (word,)
    pieces = []
    for piece in brace_expansions(raw):
        try:
            unquoted = shlex.split(piece)
        except ValueError:
            return brace_expansions(word)
        pieces.append(unquoted[0] if len(unquoted) == 1 else piece if unquoted else '')
    return tuple(dict.fromkeys(pieces))


@functools.lru_cache(maxsize=1)
def list_places():
    """The private list's places, each as its config folder, the list's
    folder and the list's file: at the default config folder and at the
    one XDG_CONFIG_HOME sets, each as written and as its real path, in
    the case the Mac's file system ignores (casefolded)."""
    home = os.environ.get('HOME') or os.path.expanduser('~')
    configs = [os.path.join(home, '.config')]
    configured = os.environ.get('XDG_CONFIG_HOME', '')
    if os.path.isabs(configured):
        configs.append(configured)
    places = []
    for config in configs:
        for form in (os.path.normpath(config), os.path.realpath(config)):
            form = form.casefold()
            folder = os.path.join(form, 'brickson')
            place = (form, folder, os.path.join(folder, 'private-words.txt'))
            if place not in places:
                places.append(place)
    return tuple(places)


def placed(text, folder, environment=None):
    """The path a word names, read from folder as the shell expands it
    (~, ~+, $HOME, $XDG_CONFIG_HOME, $PWD), or None when the guard cannot
    tell: the shell builds it otherwise, the folder is unknown, or no path
    can hold it (a NUL byte, a lone surrogate). Its .. are left for
    path_reaches_list, which reads them by name and through links."""
    try:
        text = expanded_tilde(text, environment, folder)
        if text is not None:
            text = with_config_variables(text, environment, folder)
        if not text or (not os.path.isabs(text) and folder is None):
            return None
        path = os.path.join(folder or '', text)
        os.fsencode(path)
        return path
    except (ValueError, UnicodeError):
        return None


@functools.lru_cache(maxsize=65536)
def path_reaches_list(path, places, logical=False):
    """Whether path names a config folder the list may be in, the list's
    folder or its file, or is a glob that could name one of them, with its
    .. read by name (as cd does) and where a link before it leads (as a
    program and bash's glob do: cd ~/l && cat ../x), and where its links
    lead. For a logical cd (logical), only by name, unless no folder has
    that name or a glob finds it, where bash's cd goes physically. A glob
    deeper than the list's file names other files."""
    lexical = os.path.normpath(path)
    pattern = bool(re.search(r'[*?[]', path))
    forms = [lexical]
    try:
        forms.append(os.path.realpath(lexical))
        if not logical or pattern or not os.path.isdir(lexical):
            forms.append(os.path.realpath(path))
    except (ValueError, UnicodeError, OSError):
        pass
    for candidate in dict.fromkeys(form.casefold() for form in forms):
        if not pattern:
            if any(candidate in (config, inside) or candidate.startswith(inside + os.sep)
                   for config, inside, _ in places):
                return True
            continue
        parts = candidate.split(os.sep)
        # A shell glob matches a leading dot only when it writes one.
        if any(len(parts) == len(target.split(os.sep)) and all(
                fnmatch.fnmatchcase(goal, part)
                and (part.startswith('.') or not goal.startswith('.'))
                for goal, part in zip(target.split(os.sep), parts))
               for place in places for target in place):
            return True
    return False


def reaches_list(words, folders, environment=None, raw_words=None, logical=False):
    """Whether a word of one command names a config folder the list may be
    in, the list's folder or its file, or is a glob that could name one of
    them, read from each folder the command may read it from: after a cd,
    through .., ~, ~+, $HOME, $XDG_CONFIG_HOME and $PWD, braces expanded
    (in the raw words, with their quotes, where the guard has them), in an
    option's or an assignment's value, and in each part of an assignment's
    value that a : starts with ~, or of CDPATH's (CDPATH=:~/.config/gh/..),
    which the checks in main cannot follow (cd ~/.config/gh && cat
    ../b*/*). Where the shell builds HOME or XDG_CONFIG_HOME, the hook's
    stand in. A piece with a newline names no path the guard looks for. A
    recursive read of a folder that holds a config folder (grep -r . ~)
    is not refused. A logical cd's words are placed as path_reaches_list
    says (logical)."""
    places = list_places()
    environment = dict(environment or {})
    hooks = {key: value for key, value in environment.items()
             if key not in ('HOME', 'XDG_CONFIG_HOME')}
    if raw_words is None or len(raw_words) != len(words):
        raw_words = [None] * len(words)
    for word, raw in zip(words, raw_words):
        for text in word_texts(word, raw):
            for folder in folders:
                path = placed(text, folder, environment)
                if path is None and hooks != environment:
                    path = placed(text, folder, hooks)
                if path and path_reaches_list(path, places, logical):
                    return True
    return False


@functools.lru_cache(maxsize=4096)
def word_texts(word, raw=None):
    """The texts in one word that may name a path (reaches_list): each
    piece its braces make, an option's or an assignment's value, and the
    parts of an assignment's value that a : starts with ~, or of CDPATH's
    (NAME+= included). A text with a newline names no path the guard
    looks for; a piece with one may still hold a part without."""
    texts = []
    for piece in word_pieces(word, raw):
        texts.append(piece)
        name, equal, value = piece.partition('=')
        if equal:
            texts.append(value)
            if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*\+?', name) and (
                    name.rstrip('+') == 'CDPATH' or '~' in value):
                texts += [part for part in value.split(':')
                          if name.rstrip('+') == 'CDPATH' or part.startswith('~')]
    return tuple(text for text in dict.fromkeys(texts) if text and '\n' not in text)


def names_config_folder(command):
    """Whether a word names a config folder itself, which a recursive or
    wildcard read would reach the list's file through without naming it
    (grep -r . ~/.config), or is a glob that could name the list's folder
    or file through one (~/.c*/b*/*), in any case. Read deny rules do not
    cover such a read, so the guard refuses it."""
    for word in re.findall(r'[^\s;&|()<>`]+', command):
        word = re.sub(r'\$\{?XDG_CONFIG_HOME\}?', '/.config',
                      word.replace('"', '').replace("'", '')).casefold()
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


# The GIT_ variables git reads (git help git, "Environment Variables"),
# whole and as the beginnings of their families.
GIT_VARIABLES = {
    'GIT_DIR', 'GIT_WORK_TREE', 'GIT_NAMESPACE', 'GIT_CEILING_DIRECTORIES',
    'GIT_DISCOVERY_ACROSS_FILESYSTEM', 'GIT_COMMON_DIR', 'GIT_DEFAULT_HASH', 'GIT_EDITOR',
    'GIT_PAGER', 'GIT_ASKPASS', 'GIT_TERMINAL_PROMPT', 'GIT_FLUSH', 'GIT_NO_REPLACE_OBJECTS',
    'GIT_REPLACE_REF_BASE', 'GIT_LITERAL_PATHSPECS', 'GIT_GLOB_PATHSPECS',
    'GIT_NOGLOB_PATHSPECS', 'GIT_ICASE_PATHSPECS', 'GIT_REFLOG_ACTION', 'GIT_REF_PARANOIA',
    'GIT_COMMIT_GRAPH_PARANOIA', 'GIT_OPTIONAL_LOCKS', 'GIT_PRINT_SHA1_ELLIPSIS', 'GIT_ADVICE',
    'GIT_SHALLOW_FILE', 'GIT_QUARANTINE_PATH', 'GIT_PREFIX', 'GIT_IMPLICIT_WORK_TREE',
    'GIT_EXTERNAL_DIFF', 'GIT_PROGRESS_DELAY', 'GIT_NO_LAZY_FETCH', 'GIT_SMART_HTTP'}
GIT_FAMILIES = ('GIT_CONFIG', 'GIT_AUTHOR_', 'GIT_COMMITTER_', 'GIT_INDEX_', 'GIT_OBJECT_',
                'GIT_ALTERNATE_', 'GIT_TRACE', 'GIT_SSH', 'GIT_SSL_', 'GIT_HTTP_', 'GIT_CURL_',
                'GIT_PROXY', 'GIT_PROTOCOL', 'GIT_ALLOW_', 'GIT_REDIRECT_', 'GIT_NOTES_',
                'GIT_DIFF_', 'GIT_MERGE_', 'GIT_SEQUENCE_', 'GIT_EXEC_', 'GIT_TEMPLATE',
                'GIT_ATTR_', 'GIT_PUSH_', 'GIT_INTERNAL_', 'GIT_TEST_')


def read_variable(name):
    """Whether git, gh or the shell reads name to know where to look:
    HOME, XDG_CONFIG_HOME, CDPATH, GH_CONFIG_DIR, a GIT_ variable git reads
    or one the environment already has (exported, so git sees it)."""
    if name in ('HOME', 'XDG_CONFIG_HOME', 'CDPATH', 'GH_CONFIG_DIR'):
        return True
    return name.startswith('GIT_') and (name in GIT_VARIABLES or name.startswith(GIT_FAMILIES)
                                        or name in os.environ)


def option_operands(args, values, named=''):
    """A builtin's operands after its options, as it reads them: a cluster's
    letter in values or named takes the rest of the word or the next word,
    and named ones' values are names too (read -a NAME)."""
    names, index = [], 0
    while index < len(args):
        arg = args[index]
        if arg == '--':
            return names + args[index + 1:]
        if not arg.startswith('-') or arg == '-':
            return names + args[index:]
        for offset, letter in enumerate(arg[1:], 1):
            if letter in values or letter in named:
                value = arg[offset + 1:]
                if not value and index + 1 < len(args):
                    index += 1
                    value = args[index]
                if letter in named:
                    names.append(value)
                break
        index += 1
    return names


def unread_variable(words, everything=()):
    """The variable that tells git, gh or the shell where to look
    (read_variable) which a command sets to a value it reads when it
    runs: for and select's name, read's, mapfile's and getopts' names,
    printf -v's, a ${NAME:=word} or ${NAME=word} anywhere in the
    command's words (everything), and a declare -n reference to it (or
    one with no name yet, which a later assignment gives). None when it
    sets none."""
    for word in [*everything, *words]:
        for match in re.finditer(r'\$\{([A-Za-z_][A-Za-z0-9_]*):?=', word):
            if read_variable(match[1]):
                return match[1]
    if not words:
        return None
    program = os.path.basename(words[0])
    args = without_redirections(words[1:])
    if program in ('for', 'select'):
        names = args[:1]
    elif program == 'read':
        names = option_operands(args, 'dinNptu', 'a')
    elif program in ('mapfile', 'readarray'):
        names = option_operands(args, 'dnOsuCc')[:1]
    elif program == 'getopts':
        names = args[1:2]
    elif program == 'printf':
        names = args[1:2] if args[:1] == ['-v'] else [args[0][2:]] if args[:1] and args[
            0].startswith('-v') else []
    elif program in ('declare', 'typeset', 'local'):
        options = [arg for arg in args if arg.startswith('-') and '=' not in arg]
        if 'n' not in ''.join(option.lstrip('-') for option in options):
            return None
        for arg in args:
            if arg not in options:
                name, equal, target = arg.partition('=')
                if not equal or read_variable(target):
                    return target if equal else name
        return None
    else:
        return None
    return next((name for name in names if read_variable(name)), None)


# tar's options that take a value: in its old first word (tar cfC - dir),
# each takes the next word in turn; in a cluster (-fC), the rest of it.
TAR_VALUES = set('bfFgHKLNTVXIC')


def own_directories(words, cwd, environment=None):
    """The folders a program reads its operands from after its own -C or
    --directory (git -C, tar -C, make -C): as its own word, at the end of
    a cluster of short options (tar -cC dir) or attached (-Cdir), as any
    beginning of --directory from --dir, and in tar's old first word
    (tar cfC - dir): each value from where the one before it left off,
    and from cwd. For a program in which -C means something else (grep
    -C 3), these are folders it never reads, which only add places to
    look."""
    values, index = [], 1
    if (words and os.path.basename(words[0]) in ('tar', 'gtar', 'bsdtar') and len(words) > 1
            and re.fullmatch(r'[A-Za-z]+', words[1])):
        index = 2
        for letter in words[1]:
            if letter in TAR_VALUES and index < len(words):
                if letter == 'C':
                    values.append(words[index])
                index += 1
    while index < len(words):
        word = words[index]
        if word.startswith('--'):
            name, equal, value = word.partition('=')
            if len(name) >= 5 and '--directory'.startswith(name):
                if not equal and index + 1 < len(words):
                    index += 1
                    value = words[index]
                values.append(value)
        elif word.startswith('-') and len(word) > 1:
            for offset, letter in enumerate(word[1:], 1):
                if letter == 'C':
                    value = word[offset + 1:]
                    if not value and index + 1 < len(words):
                        index += 1
                        value = words[index]
                    values.append(value)
                    break
                if letter in TAR_VALUES:
                    break  # the rest of the word is that option's value
        index += 1
    folders, current = [], cwd
    for value in values:
        if value:
            current = changed_directory(current, value, environment)
            folders += [current, changed_directory(cwd, value, environment)]
    return folders


def check_command(command, cwd, depth=0, environment=None, git_state=None):
    # Branch changes persist even across subshells. Later implicit pushes
    # cannot be resolved using the repository's state before this command.
    if git_state is None:
        git_state = {'branch_changed': False}
    if depth > 3:
        deny('Shell nesting exceeds the inspection limit. Use the underlying command explicitly.')
    command = ansi_c_quotes(without_shell_comments(
        inspectable_here_documents(marked_documents(command))))
    literal, built = literal_words(command)
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
    # An exit, or a cd that fails under set -e, ends the shell, so the
    # folder before it is not followed: only where the guard reads the
    # order commands run in, with no if, loop, case, function or group
    # (whose exit or failure may not run, or not end the shell) and no
    # pipe or & (a subshell).
    plain = not any(words[:1] and words[0] in COMPOUND_WORDS for words, _ in parts) and not any(
        parts[index][0] == ['('] and parts[index + 1][0] == [')'] for index in range(len(parts) - 1))
    errexit = False
    for part_index, (words, separator) in enumerate(parts):
        runnable = {(where, success, stack, env) for where, success, stack, env in states
                    if separator not in ('&&', '||')
                    or (separator == '&&' and success)
                    or (separator == '||' and not success)}
        next_states = states - runnable
        following = parts[part_index + 1][1] if part_index + 1 < len(parts) else ';'
        alone = plain and separator not in ('|', '|&') and following not in ('|', '|&', '&')
        if words in (['('], ['<('], ['>(']):
            scopes.append((runnable, next_states, words != ['(']))
            states = runnable
            continue
        if words == [')']:
            if scopes:
                outer, skipped, asynchronous = scopes.pop()
                # A subshell that exits in every state ends with any status.
                outcomes = {True, False} if asynchronous else (
                    {success for _, success, _, _ in states} or {True, False})
                states = skipped | {(where, success, stack, env)
                    for where, _, stack, env in outer for success in outcomes}
            continue
        if alone and words[:1] == ['exit']:
            states = next_states
            continue
        if alone and not scopes and words[:1] == ['set'] and separator in (';', '\n'):
            for index, word in enumerate(words[1:], 1):
                named = words[index + 1:index + 2] == ['errexit'] and word in ('-o', '+o')
                if named or re.fullmatch(r'[-+][a-zA-Z]*e[a-zA-Z]*', word):
                    errexit = word.startswith('-')
        runtime_inputs = []
        unwrapped, command_environment, directories = strip_wrappers(words, environment, runtime_inputs)
        if prints_environment(words, unwrapped):
            deny(ENVIRONMENT_DUMP)
        if not unwrapped:
            # Redirections alone, after a subshell or a group ( ... ) > file,
            # still write their targets.
            unread = unread_variable([], words)
            if unread:
                deny(UNREAD_VARIABLE.format(name=unread))
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            for where, _, _, shell_env in runnable:
                if reaches_list(words, [where], dict(shell_env), raw_words):
                    deny(LIST_READ)
            for where in {path for path, _, _, _ in runnable}:
                note_writes(git_state, words, raw_words, unwrapped, where, where)
            if words and all(ASSIGNMENT.match(word) for word in words):
                # Assignment-only shell commands persist, including unexported CDPATH.
                for where, _, stack, shell_env in runnable:
                    _, updates, _ = strip_wrappers(words, dict(shell_env), here=where)
                    next_states.add((where, True, stack, tuple(sorted(updates.items()))))
                states = next_states
            continue
        program = os.path.basename(unwrapped[0])
        if runtime_inputs and program in SHELLS | {'eval', 'gh', 'curl', 'wget', 'http', 'https'}:
            deny(RUNTIME_WORDS)
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
        # The command substitutions in the words, the same in every folder.
        raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
        raw_outer = None
        if len(raw_words) == len(words):
            raw_outer = (raw_words[:absolute_index] + raw_words[absolute_index + 1:]
                         if outer_words is not words else raw_words)
        inners = list(dict.fromkeys(nested(outer_words, raw_outer)))
        for where, stack, shell_env in {(path, stack, env) for path, _, stack, env in runnable}:
            inherited = dict(shell_env)
            _, command_environment, directories = strip_wrappers(words, inherited, here=where)
            command_cwd = where
            for directory in directories:
                command_cwd = changed_directory(command_cwd, directory, inherited)
            # The shell opens redirections where it is; the program reads
            # its operands where a wrapper's -C puts it, and its own -C.
            folders = [where, command_cwd] + own_directories(unwrapped, command_cwd, inherited)
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            logical = program in ('cd', 'pushd') and not cd_options(
                without_redirections(unwrapped)[1:])[0]
            if reaches_list(words, dict.fromkeys(folders), inherited, raw_words, logical):
                deny(LIST_READ)
            unread = unread_variable(unwrapped, words)
            if unread:
                deny(UNREAD_VARIABLE.format(name=unread))
            for inner in inners:
                check_command(inner, where, depth + 1, inherited, git_state)
            # script and unbuffer give what they run a terminal, which gh
            # asks on; a substitution in their words runs before them.
            terminal = git_state.get('terminal')
            given_terminal = terminal or program == 'script' or any(
                os.path.basename(word) in TERMINAL_WRAPPERS
                for word in words[:len(words) - len(unwrapped)])
            git_state['terminal'] = given_terminal
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
            elif program == 'alias' and any('=' in word for word in unwrapped[1:]):
                deny(SHELL_ALIAS_DEFINED)
            for runner_cwd, inner in runner_commands(unwrapped, command_cwd):
                check_command(inner, runner_cwd, depth + 1, command_environment, git_state)
            git_state['terminal'] = terminal
            raw_words = raw_parts[part_index][0] if len(raw_parts) == len(parts) else []
            note_writes(git_state, words, raw_words, unwrapped, where, command_cwd,
                        stdin_document(parts, given, part_index))
            if program in ('declare', 'typeset', 'local', 'readonly'):
                next_states.add((where, True, stack, tuple(sorted(
                    declared(unwrapped[1:], inherited, where).items()))))
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
                        if equal and program == 'export' and ASSIGNMENT.match(word):
                            key, value = assignment(word, updates, where)
                        if not context_variable(key):
                            continue
                        if flags and flags not in (['--'], ['-v']):
                            deny(UNKNOWN)
                        if program == 'unset':
                            updates[key] = None
                        elif equal:
                            if key not in ('HOME', 'XDG_CONFIG_HOME') and (
                                    '$' in value or '`' in value):
                                deny(UNKNOWN)
                            updates[key] = value
                        else:
                            deny(UNKNOWN)  # A prior unexported shell value is unknown.
                next_states.add((where, True, stack, tuple(sorted(updates.items()))))
                continue
            if program in ('cd', 'pushd', 'popd'):
                # The shell takes a redirection out before cd runs
                # (cd sub 2>/dev/null, pushd sub >/dev/null).
                operands = without_redirections(unwrapped)[1:]
                if program == 'popd' or (program == 'pushd' and not operands):
                    target = stack[0] if stack else None
                    rest = stack[1:] if stack else ()
                    new_stack = ((where,) + rest) if program == 'pushd' else rest
                    next_states.update({(target, True, new_stack, shell_env), (where, False, stack, shell_env)})
                    continue
                if program == 'pushd' and operands[0].startswith(('-', '+')):
                    deny(UNKNOWN)  # indexed/stack-only forms are not guessed
                physical, operands = cd_options(operands)
                destination = operands[0] if len(operands) == 1 else None if operands else (
                    command_environment.get('HOME', os.environ.get('HOME')))
                if len(operands) > 1:
                    # zsh's cd old new replaces old in the folder's path.
                    next_states.update({(None, True, stack, shell_env),
                                        (where, False, stack, shell_env)})
                    continue
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
                    target = changed_directory(where, destination, inherited, physical)
                # Earlier shell commands may create the target, so inspect
                # both outcomes even when it does not exist at hook time,
                # unless a failure ends the shell (set -e, with nothing
                # after it in an && or || list). Where no folder has a
                # logical cd's name, bash goes where its links lead: a
                # folder of its own only when a link comes before a ..,
                # not when the folders above are named through a link
                # (macOS's /var is /private/var), or every cd would count
                # one folder twice.
                new_stack = (where,) + stack if program == 'pushd' else stack
                next_states.add((target, True, new_stack, shell_env))
                if target is not None and not physical and not os.path.isdir(target):
                    resolved = changed_directory(where, destination, inherited)
                    if resolved is None or resolved != changed_directory(target, '.', inherited):
                        next_states.add((resolved, True, new_stack, shell_env))
                if not (errexit and alone and not scopes and words[:1] in (['cd'], ['pushd'])
                        and following not in ('&&', '||')):
                    next_states.add((where, False, stack, shell_env))
                continue
            # This command's words, not a nested one's.
            git_state['literal_words'], git_state['built_words'] = literal, built
            git_state['stdin'] = stdin_document(parts, given, part_index)
            if program == 'git':
                # 2>/dev/null and the like are the shell's, never git's arguments.
                subcommand, args, context = git_parts(without_redirections(unwrapped),
                                                      command_cwd, command_environment)
                subcommand, args, context = expand_git_alias(subcommand, args, context)
                args = without_redirections(args)
                if runtime_inputs and subcommand not in RUNTIME_READS:
                    deny(RUNTIME_WORDS)
                if subcommand in ('apply', 'am', 'stash') and not (
                        subcommand == 'stash' and [arg for arg in args if not arg.startswith('-')][:1]
                        in (['list'], ['show'])):
                    # A patch or a stash changes files, or the index, that
                    # the guard cannot name (git stash list and show read).
                    git_state.setdefault('writes', []).append((command_cwd, None))
                    if changes_index(subcommand, args):
                        git_state.setdefault('index_changes', []).append(context)
                if subcommand == 'config' and sets_identity(args):
                    git_state['identity_set'] = True
                if subcommand == 'config' and sets_hooks(args):
                    git_state['hook_changed'] = True
                if subcommand in GIT_FILE_CHANGERS:
                    # What their paths name may change, the hook among them.
                    directory = effective_directory(context)
                    git_state.setdefault('changes', []).extend(
                        (directory, arg) for arg in args if not arg.startswith('-'))
                    if ((subcommand in ('checkout', 'switch') and not leaves_files(subcommand, args))
                            or (subcommand == 'reset' and any(
                                arg in ('--hard', '--keep', '--merge') for arg in args))):
                        git_state['hook_changed'] = True  # another commit's files
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
                    check_push(args, context, git_state['branch_changed'], git_state)
                elif subcommand == 'send-pack':
                    deny('Use git push with an explicit feature branch; send-pack '
                         'can update remote refs outside the inspected push path.')
                # A later commit in this call may reuse what these move,
                # or look an author up through a mailmap it sets.
                head, refs, picks = git_moves(subcommand, args)
                if head:
                    git_state['head_moved'] = 'git ' + subcommand
                if head or refs:
                    git_state['refs_moved'] = 'git ' + subcommand
                if picks:
                    git_state['picked'] = True
                if subcommand == 'config' and config_change(args) is not None:
                    git_state['config_changed'] = 'git config'
            elif program == 'gh':
                git_state['terminal'] = given_terminal
                check_gh(unwrapped, command_cwd, command_environment, git_state)
                git_state['terminal'] = terminal
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
                if names_uploads(request_words[1:]):
                    deny(RELEASE_ASSET)
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
                            if contents_paths(operation[1:]):
                                note_published(git_state, program + ' file name',
                                               contents_paths(operation[1:]))
                        if protected_api_write(operation, arguments, method):
                            deny(TO_MAIN)
                        if merge_api_request(operation, arguments, method):
                            deny(MERGE)
                        if copilot_request(arguments, operation, method):
                            deny(COPILOT)
            next_states.update({(where, True, stack, shell_env), (where, False, stack, shell_env)})
        states = next_states
        if (len({(where, stack, env) for where, _, stack, env in states}) > STATE_LIMIT
                or GIT_QUERIES[0] > GIT_QUERY_LIMIT):
            deny(TOO_MANY_FOLDERS)


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
    texts are (label, text or its readings); identities are (folder, its
    readings as (name, address), where) for a commit's author and
    committer, checked as the checker checks a commit's."""
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
            for folder, readings, where in identities:
                try:
                    support = privacy.support_addresses(privacy.top_level(folder))[0]
                except privacy.SetupError:
                    support = set()  # not a checkout: the support address is not allowed
                checker = privacy.Checker(entries, support)
                findings += privacy.merged(
                    lambda name, address, where=where: checker.identity(name, address, where),
                    readings)
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
        if names_list(command):
            deny(LIST_READ)
        if PROCESS_ENVIRONMENT.search(command):
            deny(ENVIRONMENT_DUMP)
        state = {'branch_changed': False}
        check_command(command, cwd, git_state=state)
        check_written(state)
        if state.get('publishes'):
            check_privacy(state.get('published', []), commits=state.get('commits', ()),
                          directory=cwd, identities=state.get('identities', ()))
    elif name in FILE_TOOLS:
        check_file_tool(name, arguments, cwd)
    elif name.startswith('mcp__'):
        check_github_tool(name, arguments)
        check_tool_privacy(name, arguments, cwd)


if __name__ == '__main__':
    main()
