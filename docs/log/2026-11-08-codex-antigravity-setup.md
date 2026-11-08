# Codex and Antigravity set up on the owner's Mac, with Brickson's guard

*2026-11-08. Pull request #89 (`claude/codex-antigravity-setup`). The
bridge thread, a Claude Code session on the owner's Mac through Remote
Control, from the owner's approved plan for handing work to Codex and
Antigravity (approved 2026-11-08).*

## What changed and why

Nothing in the app changes, and nothing else in the repository. This
records a set-up on the owner's Mac that lives outside the repository
(git-ignored files, and Codex's own folder), so the next agent can find
it, check it and rebuild it.

The owner wants threads to hand some work to OpenAI's Codex and Google's
Antigravity, which draw on the owner's ChatGPT and Google plans rather
than Claude's. Both act as the owner on the Mac (the owner's git and
`gh` sign-ins), so GitHub cannot tell their push or merge from the
owner's, and until now only review held them to AGENTS.md's rules
(AGENTS.md, *Guardrails for agents*). The approved plan: Antigravity
works on Brickson only in a folder of its own, with Google's data
collection off, no AI credit overages, the Default permission preset
and no GitHub connection; and before either agent edits files, each
gets a hook that refuses what `.claude/hooks/guard.py` refuses, tested
the way `scripts/test-hooks.py` tests the guard.

No Antigravity or Codex job has run on Brickson's code in this thread.
The probes below ran in empty scratch folders (one command, below,
ran in `~/code/brickson` by accident, and was undone).

### The tools, as found

| | Codex | Antigravity |
|---|---|---|
| Command-line tool | `codex-cli 0.167.0` (Homebrew), current per `codex doctor` | `agy 1.5.3` |
| App | "ChatGPT" (`com.openai.codex`, 26.1103.41825), running | "Gemini" (`com.google.GeminiMacOS`, 1.141.3.1394), which runs the agent manager with its own `agy` 1.4.11 |
| Signed in | `codex login status`: "Logged in using ChatGPT", exit 0 | Yes (Google account; `agy models` answered) |
| Plan | Not read: needs the app's Settings, and computer use was declined | Paid Pro or Ultra: `agy models` lists Gemini 4 Argon and Claude Opus and Sonnet 5.5, which only paid plans get; which of the two was not read |
| Reads AGENTS.md | All of it on this Mac (`project_doc_max_bytes = 131072`) | Only its first 24,000 bytes; see the pointer file below |

### Antigravity's own folder

- `~/code/brickson-antigravity`, a worktree on branch `antigravity/setup`
  from `origin/main` at `af698ad`, with its upstream removed so a bare
  `git push` cannot name `main`. Later jobs:
  `git -C ~/code/brickson-antigravity fetch origin main && git -C ~/code/brickson-antigravity switch -c antigravity/<topic> origin/main`.
- `.agents/rules/read-agents-md.md` there, always on, tells Antigravity
  to read all of AGENTS.md with `cat AGENTS.md` before changing
  anything, because it truncates rule files at 24,000 bytes and
  AGENTS.md is about 80,000. `git check-ignore -v` names `.gitignore:37`
  (`.agents/`), so it is never committed.

### Settings, as found and as left

Computer use for the two apps was declined, so no app setting was
changed; the owner was given the clicks. Read from the apps' settings
files:

| Setting | Found | Approved | Left |
|---|---|---|---|
| Antigravity permission preset | Auto | Default | Auto, until the owner changes it |
| Antigravity AI credit overages | On (`useAiCredits: true`) | Never | On, until the owner changes it |
| Antigravity telemetry | Not in a local file (saved with the account) | Off | Not checked |
| Antigravity project for Brickson | One project, "Brickson", whose folder is `~/code/brickson` | One whose only folder is `~/code/brickson-antigravity` | Unchanged; the new one is the owner's to add |
| Antigravity CLI mode | `agentMode: auto`, `toolPermission: proceed-in-sandbox`; trusts `~/code` and `~/code/brickson` | Not in the plan | Unchanged; a decision for the owner |
| Antigravity CLI credits | `useG1Credits` absent (default, off) | Off | Off |
| Codex | `sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`, hooks on | Never `danger-full-access` | Unchanged |

What the files also showed, each against the approved plan:

- **Every `agy` run uses the "Brickson" project.** It is the command
  line's default project, so `~/code/brickson` is added to every `agy`
  session's folders, first, whatever folder it starts in, and its
  shell commands run there. A probe started in an empty scratch folder
  ran `touch` in `~/code/brickson` (the empty file was deleted at once,
  and `git status` there was clean after).
- **That project carries 33 standing permission grants**, among them
  `git merge`, `git add`, `git commit`, `git cherry-pick`, pushes of
  four `codex/` branches, and GitHub tool calls that create, update and
  review pull requests. They apply to every `agy` run (the CLI log says
  "stored 33 allow ... grants from project Brickson").
- **Antigravity has a GitHub connection**: an MCP server named `github`
  with a stored header, through which those grants created and
  reviewed pull requests. The plan says no GitHub connection.
- **Antigravity has already worked on Brickson.** The project holds a
  worktree environment, `docs_audits_and_tests`, and grants for the
  branches of pull requests #61 to #64 (`codex/website-review`,
  `codex/app-store-listing-drafts`, `codex/accessibility-reference-audit`,
  `codex/pure-swift-unit-tests`). Their records did not name the agent;
  it was Antigravity, on `codex/` branches.

### The hooks

One adapter, `brickson_guard_adapter.py`, translates a hook call from
Antigravity or Codex into Claude Code's shape, gives it to
`.claude/hooks/guard.py`, and translates the answer back. It decides
nothing itself, so the two agents are refused what Claude Code is,
including later changes to the guard. It refuses whenever it cannot
read the call, find or run the guard (20-second limit), or read the
guard's answer. Its text is at the end of this record.

- **Antigravity:** `~/code/brickson-antigravity/.agents/hooks.json`
  (git-ignored) runs it before every tool (matcher `*`), with the guard
  of that worktree:
  `python3 '<worktree>/.agents/hooks/brickson_guard_adapter.py' --format antigravity`,
  timeout 30. It checks `run_command` and `send_command_input` text as
  shell commands; `call_mcp_tool` as `mcp__<server>__<tool>`, so the
  GitHub tool rules apply; and every file or folder argument as the
  guard's file tools, by name (both the names hook calls carry,
  `read_file`, `write_file`, `edit_file`, and the documented ones,
  `view_file`, `write_to_file`, `replace_file_content`) and, for any
  other tool, by argument name. A `run_command` call carries no `Cwd`
  (seen on 2026-11-08), so a command is checked in every workspace
  folder the call lists and refused if any refuses.
- **Codex:** `~/.codex/hooks.json` gained one `PreToolUse` entry
  (matcher `*`, timeout 30) running a copy at
  `~/.codex/hooks/brickson_guard_adapter.py --format codex`; the file's
  two `SessionStart` hooks are unchanged and it was backed up first
  (`~/.codex/hooks.json.bak-2026-11-08`). The hook is global, so the
  adapter acts only when the session's folder is inside a Brickson
  checkout (one with `.claude/hooks/guard.py` and
  `scripts/privacy-check.py`), using that checkout's guard, and says
  nothing elsewhere; a call it cannot read is refused only when Codex
  runs the hook in a Brickson checkout. It checks `Bash`, the paths an `apply_patch` adds,
  updates, deletes or moves to, and `mcp__` tools. Codex runs a new or
  changed hook only after the owner trusts it (`/hooks` in the `codex`
  command, or the app's Settings > Hooks), so **until then it does not
  run**.
- Both copies are the same file: SHA-256
  `22c0dc062b02bd08f6dea058f25d0624c1caf8322044ebee18d4a35044521e2b`.

### What each tool does when its hook fails

Measured for Antigravity (`agy 1.5.3`, `agy -p` in an empty scratch
folder, Gemini 3.8 Flash), by a hook that failed in a different way for
each of eight `touch` commands, then looking for the files: the tool
call did **not** run, and the agent was told why, when the hook exited
1 or 2, printed something that is not JSON, crashed, or ran past its
timeout (killed). A hook that printed `{}`, with no decision, was read
as a refusal. A `deny` refused with the hook's reason; an `allow` let
the command run. The run still exited 0 with status `SUCCESS`, as
refused steps in headless mode do, so a run's exit is no evidence of
what ran.

Codex, from its documentation (learn.chatgpt.com/docs/hooks, read
2026-11-08), not measured: a `PreToolUse` hook that returns a field
Codex does not support "is marked failed" and Codex "continues the tool
call"; the section on hooks run by Codex's cloud orchestration adds that
an error, a timeout or a malformed response "can let the tool run". It
does not say what a local hook's other failures (an exit other than 2,
a crash, a timeout) do. A refusal is a `deny` in `hookSpecificOutput`,
or exit 2 with the reason on stderr. So the adapter answers every
failure inside a Brickson checkout with exit 2, and keeps the guard's
own limit (20 s) under the hook's (30 s), counting on as little as
possible from Codex. The
measurement needs a test hook to run without the owner trusting it
first, through Codex's `--dangerously-bypass-hook-trust`; the session's
safety check refused that flag, so it was not run.

## Commits

The commits of pull request #89.

## Verified

On the owner's Mac (macOS 27.2, Python 3 from the Mac's `python3`):

- **The guard's own tests, through the adapter.** All of
  `scripts/test-hooks.py`'s `GuardTests` and `PrivacyGuardTests` (on
  `main` at `af698ad`), with Claude Code's call turned into the agent's
  and the answer turned back: Antigravity 215 of 215 passed (361 s);
  Codex 215 of 215 passed (379 s). Two are left out on purpose:
  `test_each_refusal_keeps_its_own_words` reads the guard's own source,
  and `test_unreadable_input_decides_nothing` expects the guard's
  silence where the adapter refuses (it fails closed). The Antigravity
  run gives no `Cwd` for about half the commands, so both paths ran;
  the Codex run turns file writes into `apply_patch` calls. The suite
  on its own passed 221 of 221 in 203 s.
- **The suite can fail**: the same Antigravity run with a copy of the
  adapter that ignores the guard's refusals failed 907 checks.
- **The adapter's own tests**, 10 of 10: both naming schemes, MCP calls
  (arguments as an object or as text), input sent to a running command,
  commands without `Cwd` checked in every folder, Codex acting only in
  a Brickson checkout and always with that checkout's own guard, patch
  paths including a move, and refusing on unreadable calls, a missing,
  crashing, unreadable, non-deny or slow guard, and wrong arguments.
  Each of four broken copies of the adapter (ignoring the guard's
  refusal, failing open in either format, checking only one folder)
  failed them. A fifth, without the `view_file` mapping, passed,
  because the by-argument check refuses the same call; that mapping is
  a second line, not the only one.
- **Antigravity's hook on a real run**: `agy -p` in a scratch folder
  with the installed `hooks.json` ran `echo allowed-probe` and refused
  `git add -A --dry-run -- no-such-path-xyz` with the guard's words
  ("Stage only your own changes ..."). `git status` in `~/code/brickson`
  was unchanged.
- **The hook calls Antigravity sends**, captured by a hook that logged
  and refused everything: `run_command` (`CommandLine`,
  `WaitMsBeforeAsync`, `IsDaemon`, `toolSummary`, no `Cwd`),
  `read_file` (`Path`), `write_file` (`Path`, `Content`), with
  `workspacePaths` listing `~/code/brickson` first.

## Not verified

- Codex's hook has not run: it waits for the owner to trust it. Then:
  in a scratch worktree of Brickson, `codex exec` asked to run
  `git add -A --dry-run` should be refused with the guard's words.
- What Codex does when its hook fails, measured (above).
- Antigravity's hook in the Gemini app, as opposed to `agy`; the app's
  `agy` is 1.4.11, older than the command line's 1.5.3. The hook file
  is the same one the documentation says the app reads.
- Antigravity's names for tools not captured here (its MCP calls were
  seen as `call_mcp_tool` in an October conversation; the browser tools
  pass through, with no guard rule to apply).
- Which ChatGPT and Google AI plans exactly, and every app setting:
  computer use was declined.
- Commands Codex runs from a folder outside Brickson against a Brickson
  checkout (`git -C ~/code/brickson ...`) are not checked: the Codex
  hook keys on the session's folder.
- PR #88 changes the guard and its tests. After it merges, the adapter
  suites should run again from a worktree of the new `main`.

## Follow-ups

- **The owner** (sent in the thread): Antigravity's settings (telemetry
  off, overages Never, preset Default, a project on
  `~/code/brickson-antigravity` only); trusting Codex's hook; reading
  both plans; and three decisions: retire or repoint the old "Brickson"
  Antigravity project and its 33 grants, remove Antigravity's GitHub
  connection, and narrow the CLI's trusted folders.
- **The next Mac thread**, after the owner trusts Codex's hook: the
  Codex check in *Not verified*, then one line in this record's place
  in docs/HANDOFF.md.
- **Later, a pull request of its own** if the owner wants the adapter
  kept in the repository: `scripts/agent-hooks/` with its tests run by
  `scripts/test.sh`, so CI checks it against every change to the guard.
  It changes what the guard covers, so it gets `@codex security review`.

## The adapter, as installed

<details>
<summary><code>brickson_guard_adapter.py</code></summary>

```python
#!/usr/bin/env python3
"""Hold Antigravity and Codex to the rules Brickson's guard holds Claude Code to.

Brickson's guard, .claude/hooks/guard.py, reads a tool call in Claude Code's
shape and prints a "deny" decision for what AGENTS.md says only the owner
does (pushing to main, force pushes, merging, staging everything, reading
the private list, publishing a personal detail, and the rest of its list).
This adapter translates another agent's PreToolUse hook call into that
shape, asks the guard, and translates the answer back. It decides nothing
itself, so the two agents are refused exactly what Claude Code is refused.

    python3 brickson_guard_adapter.py --format antigravity
    python3 brickson_guard_adapter.py --format codex

It fails closed: when it cannot read the call, find or run the guard, or
understand the guard's answer, it refuses. Neither agent offers Claude
Code's onFailure: block, and Codex lets a tool run when its hook fails.

Antigravity: the guard is the one in the worktree that holds this file
(<worktree>/.agents/hooks/), and every call is checked.
Codex: the hook is global, so it acts only when the session's folder is
inside a Brickson checkout (one with .claude/hooks/guard.py and
scripts/privacy-check.py), using that checkout's own guard. Elsewhere it
says nothing. BRICKSON_GUARD_FOR_ALL_FOLDERS=<guard.py> adds that guard
outside Brickson checkouts too (the tests use it); it never replaces the
guard of a Brickson checkout.

A guard against mistakes, not a sandbox, like the guard itself. Standard
library only.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

GUARD_RELATIVE = Path('.claude') / 'hooks' / 'guard.py'
TIMEOUT_CEILING = 20  # seconds; the hook's own timeout in hooks.json is 30
FILE_TOOLS = ('Read', 'Edit', 'MultiEdit', 'Write', 'NotebookEdit', 'Grep', 'Glob')

# Antigravity's tool names: the hook call uses read_file, write_file and
# edit_file (seen 2026-11-08, CLI 1.5.3); its documentation and tool list
# use view_file, write_to_file and replace_file_content. Both are mapped.
ANTIGRAVITY_FILES = {
    'read_file': 'Read', 'view_file': 'Read',
    'write_file': 'Write', 'write_to_file': 'Write',
    'edit_file': 'Edit', 'replace_file_content': 'Edit',
    'multi_replace_file_content': 'MultiEdit', 'sed_file': 'Edit',
    'notebook_edit': 'NotebookEdit', 'notebook_execution': 'Read',
    'grep_search': 'Grep', 'find_by_name': 'Glob', 'list_dir': 'Glob',
}
# Argument names that hold a file or folder, in any Antigravity tool.
PATH_KEYS = ('Path', 'AbsolutePath', 'TargetFile', 'File', 'FilePath', 'NotebookPath',
             'DirectoryPath', 'SearchPath', 'SearchDirectory')
SEARCH_KEYS = ('SearchPath', 'SearchDirectory', 'DirectoryPath')
# Tools whose text may run in a shell: a command, or input to a running one.
ANTIGRAVITY_SHELL = ('run_command', 'send_command_input')
PATCH_PATH = re.compile(r'^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*$',
                        re.MULTILINE)


class Refuse(Exception):
    """Something kept the adapter from deciding, so the call is refused."""


def timeout_seconds():
    try:
        value = float(os.environ.get('BRICKSON_GUARD_TIMEOUT', TIMEOUT_CEILING))
    except ValueError:
        return TIMEOUT_CEILING
    return max(0.1, min(value, TIMEOUT_CEILING))  # can only be lowered


def ask_guard(guard, tool_name, tool_input, cwd):
    """The guard's reason for refusing this Claude Code call, or None."""
    if not Path(guard).is_file():
        raise Refuse(f'the guard is missing: {guard}')
    call = {'hook_event_name': 'PreToolUse', 'tool_name': tool_name,
            'tool_input': tool_input, 'cwd': str(cwd)}
    try:
        result = subprocess.run([sys.executable or 'python3', str(guard)],
                                input=json.dumps(call), capture_output=True, text=True,
                                timeout=timeout_seconds(), cwd=str(cwd))
    except subprocess.TimeoutExpired:
        raise Refuse('the guard took too long to decide')
    except OSError as error:
        raise Refuse(f'the guard could not run: {error}')
    if result.returncode != 0:
        raise Refuse(f'the guard failed (exit {result.returncode})')
    if not result.stdout.strip():
        return None
    try:
        output = json.loads(result.stdout)['hookSpecificOutput']
    except (ValueError, KeyError, TypeError):
        raise Refuse('the guard gave an answer the adapter cannot read')
    if output.get('permissionDecision') != 'deny':
        raise Refuse('the guard gave an answer the adapter cannot read')
    return output.get('permissionDecisionReason') or 'Refused by the Brickson guard.'


def first_refusal(guard, checks):
    for tool_name, tool_input, cwd in checks:
        reason = ask_guard(guard, tool_name, tool_input, cwd)
        if reason:
            return reason
    return None


# Antigravity ---------------------------------------------------------------

def antigravity_checks(call, root):
    tool = call.get('toolCall')
    if not isinstance(tool, dict) or not isinstance(tool.get('name'), str):
        raise Refuse('the hook call names no tool')
    name, args = tool['name'], tool.get('args') or {}
    if not isinstance(args, dict):
        raise Refuse('the tool call has no readable arguments')
    folders = [p for p in call.get('workspacePaths') or [] if isinstance(p, str) and p]
    explicit = args.get('Cwd') if isinstance(args.get('Cwd'), str) and args.get('Cwd') else None
    # A command with no Cwd runs in a workspace folder the hook is not told
    # (on 2026-11-08 the CLI ran one in the first of two); check it against
    # every one and refuse if any refuses. With none, this worktree.
    places = [explicit] if explicit and os.path.isdir(explicit) else \
        [p for p in dict.fromkeys(folders) if os.path.isdir(p)]
    places = places or [str(root)]
    checks = []
    if name in ANTIGRAVITY_SHELL:
        texts = [args.get('CommandLine')] if name == 'run_command' else \
            [v for v in args.values() if isinstance(v, str)]
        for text in texts:
            if isinstance(text, str) and text:
                checks += [('Bash', {'command': text}, place) for place in places]
    elif name == 'call_mcp_tool':
        server, tool_name = args.get('ServerName'), args.get('ToolName')
        if not isinstance(server, str) or not isinstance(tool_name, str):
            raise Refuse('the MCP call names no server or tool')
        arguments = args.get('Arguments') or {}
        if isinstance(arguments, str):
            try:
                arguments = json.loads(arguments)
            except ValueError:
                raise Refuse('the MCP call has unreadable arguments')
        if not isinstance(arguments, dict):
            raise Refuse('the MCP call has unreadable arguments')
        checks.append((f'mcp__{server}__{tool_name}', arguments, places[0]))
    claude = ANTIGRAVITY_FILES.get(name)
    if claude == 'Grep' and not any(isinstance(args.get(k), str) and args.get(k)
                                    for k in SEARCH_KEYS):
        checks += [('Grep', {}, place) for place in places]  # searches its folder
    for key in PATH_KEYS:
        value = args.get(key)
        if isinstance(value, str) and value:
            kind = claude or 'Read'
            if kind in ('Grep', 'Glob') or key in SEARCH_KEYS:
                kind = 'Grep' if kind == 'Grep' else 'Glob'
                field = 'path'
            elif kind == 'NotebookEdit':
                field = 'notebook_path'
            else:
                field = 'file_path'
            checks.append((kind, {field: value}, places[0]))
    return checks


def run_antigravity(raw):
    root = Path(__file__).resolve().parents[2]
    try:
        call = json.loads(raw)
        if not isinstance(call, dict):
            raise Refuse('the hook call is not a JSON object')
        reason = first_refusal(root / GUARD_RELATIVE, antigravity_checks(call, root))
    except ValueError:
        reason = 'Brickson guard adapter: the hook call could not be read, so it is refused.'
    except Refuse as error:
        reason = f'Brickson guard adapter: {error}, so the call is refused.'
    if reason:
        print(json.dumps({'decision': 'deny', 'reason': reason}))
    else:
        print(json.dumps({'decision': 'allow'}))
    return 0


# Codex ---------------------------------------------------------------------

def brickson_root(cwd):
    """The Brickson checkout holding cwd, or None."""
    try:
        top = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'],
                             capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        top = None
    candidates = []
    if top is not None and top.returncode == 0 and top.stdout.strip():
        candidates.append(Path(top.stdout.strip()))
    candidates += [Path(cwd), *Path(cwd).parents]
    for folder in candidates:
        if (folder / GUARD_RELATIVE).is_file() and \
                (folder / 'scripts' / 'privacy-check.py').is_file():
            return folder
    return None


def codex_checks(call, cwd):
    name, tool_input = call.get('tool_name'), call.get('tool_input')
    if not isinstance(name, str):
        raise Refuse('the hook call names no tool')
    if name == 'Bash':
        command = tool_input.get('command') if isinstance(tool_input, dict) else None
        if not isinstance(command, str):
            raise Refuse('the shell call has no readable command')
        return [('Bash', {'command': command}, cwd)]
    if name == 'apply_patch':
        patch = tool_input.get('command') if isinstance(tool_input, dict) else None
        if not isinstance(patch, str):
            raise Refuse('the patch could not be read')
        return [('Edit', {'file_path': path}, cwd) for path in PATCH_PATH.findall(patch)]
    if name.startswith('mcp__') or name in FILE_TOOLS:
        return [(name, tool_input if isinstance(tool_input, dict) else {}, cwd)]
    return []


def run_codex(raw):
    try:
        call = json.loads(raw)
        if not isinstance(call, dict):
            raise ValueError
    except ValueError:
        # Codex runs hooks in the session's folder: refuse only there.
        if brickson_root(os.getcwd()) is None and \
                not os.environ.get('BRICKSON_GUARD_FOR_ALL_FOLDERS'):
            return 0
        print('Brickson guard adapter: the hook call could not be read, so it is refused.',
              file=sys.stderr)
        return 2
    try:
        cwd = call.get('cwd') or os.getcwd()
        root = brickson_root(cwd)
        if root is not None:
            guard = root / GUARD_RELATIVE
        elif os.environ.get('BRICKSON_GUARD_FOR_ALL_FOLDERS'):
            guard = Path(os.environ['BRICKSON_GUARD_FOR_ALL_FOLDERS'])
        else:
            return 0  # not Brickson: no opinion
        reason = first_refusal(guard, codex_checks(call, cwd))
    except Refuse as error:
        print(f'Brickson guard adapter: {error}, so the call is refused.', file=sys.stderr)
        return 2
    if reason:
        print(json.dumps({'hookSpecificOutput': {
            'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
            'permissionDecisionReason': reason}}))
    return 0


def main():
    if sys.argv[1:] == ['--format', 'antigravity']:
        run = run_antigravity
    elif sys.argv[1:] == ['--format', 'codex']:
        run = run_codex
    else:
        print('usage: brickson_guard_adapter.py --format antigravity|codex', file=sys.stderr)
        return 2
    try:
        raw = sys.stdin.read()
    except (OSError, UnicodeError):
        raw = ''
    try:
        return run(raw)
    except Exception as error:  # never fail open on a bug here
        message = f'Brickson guard adapter crashed ({type(error).__name__}), so the call is refused.'
        if run is run_antigravity:
            print(json.dumps({'decision': 'deny', 'reason': message}))
            return 0
        print(message, file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
```

</details>

Antigravity's `.agents/hooks.json`, with the worktree's full path in
place of `<worktree>`:

```json
{
  "brickson-guard": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 '<worktree>/.agents/hooks/brickson_guard_adapter.py' --format antigravity",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

Codex's entry in `~/.codex/hooks.json`, under `"hooks"`, beside
`SessionStart`, with the home folder's full path in place of `~`:

```json
"PreToolUse": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "python3 '~/.codex/hooks/brickson_guard_adapter.py' --format codex",
        "timeout": 30,
        "statusMessage": "Checking Brickson's rules"
      }
    ]
  }
]
```
