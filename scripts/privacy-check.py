#!/usr/bin/env python3
"""Keep personal details out of this public repository.

Everything committed here, every commit message, branch name and pull
request is public, and pushed commits stay public even after a branch is
deleted. Real people's names, words and health details must never be
published by accident
(AGENTS.md, *Code Review Rules*, "Data, privacy and platform";
docs/DECISIONS.md, "Personal details stay out of the repository"). This
script looks for them before anything is pushed. It uses no AI and no
outside service.

It looks for two kinds of detail:

- Words from a private list that is never committed: names, phrases or
  details only the owner knows, each of which may appear nowhere here. It
  is read from ~/.config/brickson/private-words.txt and from the
  environment variable BRICKSON_PRIVATE_WORDS (the list itself, with
  entries on separate lines or between semicolons, or "base64:" and the
  list in base64); every list found is used.
- Patterns that need no list: email addresses, phone numbers, the name in
  a home folder's path (/Users/<name>) and the place a photo or video was
  taken, with narrow allowances for examples, the agents' service
  addresses and the website's support address on the website's own pages.

It reads text, file names, branch and tag names, commit messages, the
names and addresses commits are signed with, and the text hidden in
pictures, PDFs, archives (Word, Excel and PowerPoint files are ZIP
archives of XML; Pages, Keynote and Numbers files are ZIP archives of
compressed .iwa records), RTF, sound and video files and other binary
files. It never prints what it found, or a name that holds it, only
where and what kind. Without a private list it
refuses to say a check passed; --no-list runs the built-in patterns alone.

  python3 scripts/privacy-check.py --status     the list, its entries' matches, the hook
  python3 scripts/privacy-check.py --outgoing   what the next commit and push would publish
  python3 scripts/privacy-check.py --text -     a draft (pull request, comment) on stdin
  python3 scripts/privacy-check.py              every tracked file and its name
  python3 scripts/privacy-check.py --history    every commit on every branch (an audit)

Exit status: 0 nothing found, 1 something found, 2 the check could not
run (no private list, an unreadable list, a shallow clone, a bad
revision). Standard library only, and Python 3.9, the Mac's
/usr/bin/python3. Its tests are scripts/test-privacy.py; scripts/test.sh
runs them before the unit tests. .githooks/pre-push runs it before every
push (--pre-push), .claude/hooks/guard.py before every commit and GitHub
write it sees, and CI on every pull request (--ci).
"""
import argparse
import base64
import binascii
import bisect
from dataclasses import dataclass
import html
import io
import json
import os
from pathlib import Path
import re
import stat
import string
import struct
import subprocess
import sys
import time
import unicodedata
from urllib.parse import unquote as percent_decoded, urlsplit
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]

LIST_VARIABLE = 'BRICKSON_PRIVATE_WORDS'
LIST_FILE_NAME = Path('brickson', 'private-words.txt')
BASE64_PREFIX = 'base64:'
DECISION = 'docs/DECISIONS.md, "Personal details stay out of the repository"'
HOOKS = '.githooks'

SUPPORT_PAGE = 'site/index.html'

KIND_PRIVATE = 'a word from the private list'
KIND_EMAIL = 'an email address'
KIND_PHONE = 'a phone number'
KIND_HOME = "a home folder's name"
KIND_PLACE = 'the place a photo or video was taken'
KIND_SUPPORT = 'more than one mailto address on the support page'
IN_NAME = ' in a name'

FIXES = {
    KIND_PRIVATE: 'Remove the private words, and never open the private list.',
    KIND_EMAIL: 'Use an address at example.com; only the website\'s own pages may show '
                'the support address.',
    KIND_PHONE: 'Use a made-up number such as 555-0100.',
    KIND_HOME: 'Write ~/ (or /Users/you/) instead of a real home folder.',
    KIND_PLACE: 'Export the picture again without its location.',
    KIND_SUPPORT: 'Keep one support address on the support page.',
}
COMMIT_FIX = ('In a commit not yet pushed: fix it, then git commit --amend for the last '
              'commit, or git reset --soft @{upstream} (origin/main on a new branch) and '
              'commit again; unpushed commits may be rewritten. Already pushed: stop, and '
              'tell the owner the place and kind only (' + DECISION + ').')
REFUSED_COMMIT_FIX = ('The commit was refused, so nothing was committed: change its message or '
                      'author and run it again.')
# A place in a commit that exists: "commit <id> message", "a.txt (commit <id>)".
MADE_COMMIT = re.compile(r'(?:^|\()commit [0-9a-f]{12}\b')
NEVER_REPEAT = ('Never repeat, quote or describe what was found in a command, a message, '
                'a thread, a log record or a pull request.')

PICTURES = ('.png', '.jpg', '.jpeg', '.heic', '.heif', '.gif', '.tif', '.tiff', '.webp',
            '.avif', '.bmp', '.pdf', '.mov', '.mp4', '.m4v')


class SetupError(Exception):
    """The check could not run: say why, and stop with status 2. The
    message never holds a word from the list."""


@dataclass(frozen=True)
class Entry:
    """One entry of a private list: its words, whether its case must
    match, and its number in the list (all --status may name)."""
    tokens: tuple
    exact: bool
    number: int
    source: str


@dataclass(frozen=True)
class Finding:
    """Where something was found and what kind of thing it is. Line 0 is a
    name, a commit's signature or a binary file's data, which have no
    lines."""
    where: str
    line: int
    column: int
    kind: str

    def __str__(self):
        if not self.line:
            return f'{self.where}: {self.kind}'
        return f'{self.where}:{self.line}:{self.column}: {self.kind}'


# ---------------------------------------------------------------- the list

def parse_list(text, source):
    """Entries from a private list: one per line, or several on a line
    between semicolons. A # starts a note, to the end of its line. An
    entry starting with = must match its case. Errors name the entry's
    number, never its words."""
    entries = []
    for raw in text.splitlines():
        line = unicodedata.normalize('NFC', raw).partition('#')[0].strip()
        if not line:
            continue
        for words in line.split(';'):
            words = words.strip()
            if not words:
                continue
            number = len(entries) + 1
            exact = words.startswith('=')
            tokens = tuple(token for token in re.split(r'[\W_]+', words.lstrip('=')) if token)
            if not tokens:
                raise SetupError(f'entry {number} of {source} has no letters or digits '
                                 'to look for.')
            entries.append(Entry(tokens, exact, number, source))
    return entries


def default_list_file(environ):
    # The XDG rule: a relative XDG_CONFIG_HOME is ignored, so the list can
    # never land inside the current checkout.
    config = environ.get('XDG_CONFIG_HOME', '')
    if not os.path.isabs(config):
        config = os.path.join(environ.get('HOME') or os.path.expanduser('~'), '.config')
    return Path(config, LIST_FILE_NAME)


def committable(path):
    """Whether a git checkout around path would let it be committed: it is
    inside a work tree and not ignored there."""
    folder = str(path.parent)
    # git gives a hook GIT_DIR (in a linked worktree, among others), and
    # with it set, any folder answers for that repository. The question is
    # about the folder itself, so git's own variables are left out.
    environ = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    try:
        inside = subprocess.run(['git', '-C', folder, 'rev-parse', '--is-inside-work-tree'],
                                capture_output=True, text=True, timeout=10, env=environ)
        if inside.returncode or inside.stdout.strip() != 'true':
            return False
        ignored = subprocess.run(['git', '-C', folder, 'check-ignore', '-q', path.name],
                                 capture_output=True, timeout=10, env=environ)
    except (OSError, subprocess.SubprocessError):
        return False
    return ignored.returncode != 0


def list_text(environ):
    text = environ.get(LIST_VARIABLE, '')
    if not text.strip().startswith(BASE64_PREFIX):
        return text
    try:
        data = base64.b64decode(''.join(text.strip()[len(BASE64_PREFIX):].split()),
                                validate=True)
        return data.decode('utf-8')
    except (binascii.Error, ValueError, UnicodeError):
        raise SetupError(f'{LIST_VARIABLE} starts with "{BASE64_PREFIX}" but the rest '
                         'is not base64 of UTF-8 text.')


def load_list(environ=None):
    """Every private list this machine has: (entries, counts, warnings).
    The file may be missing; a file a checkout could commit is refused."""
    environ = os.environ if environ is None else environ
    entries, counts, warnings = [], [], []
    text = list_text(environ)
    if text.strip():
        found = parse_list(text, LIST_VARIABLE)
        entries += found
        counts.append((LIST_VARIABLE, len(found)))
    path = default_list_file(environ)
    # Named from ~, so no output shows the home folder's own name.
    home = (environ.get('HOME') or os.path.expanduser('~')).rstrip('/')
    label = '~' + str(path)[len(home):] if home and str(path).startswith(home + '/') \
        else str(path)
    try:
        data = path.read_bytes()
        mode = path.stat().st_mode
    except FileNotFoundError:
        return entries, counts, warnings
    except OSError as error:
        raise SetupError(f'{label} could not be read ({type(error).__name__}).')
    if committable(path.resolve()):
        raise SetupError(f'{label} is inside a git checkout that does not ignore it, so '
                         'it could be committed. Move the checkout or the list.')
    if mode & (stat.S_IRWXG | stat.S_IRWXO):
        warnings.append(f'{label} can be read by other accounts on this computer; '
                        f'make it private with: chmod 600 {label}')
    try:
        found = parse_list(data.decode('utf-8'), label)
    except UnicodeError:
        raise SetupError(f'{label} is not plain UTF-8 text; save it as plain text.')
    entries += found
    counts.append((label, len(found)))
    return entries, counts, warnings


# ------------------------------------------------------- the checks

# An address's edges are ASCII letters and digits, not \w: an underscore
# may come right before or after it, as Markdown's _emphasis_ puts it, but
# not after a word (snake_case), so a long run is not searched again from
# each of its parts. A dash may follow it (a typed -- dash), but not a
# hyphen that goes on into more of a name.
EMAIL = re.compile(
    r'(?<![A-Za-z0-9.%+-])(?<![A-Za-z0-9.%+-]_)[A-Za-z0-9][A-Za-z0-9._%+-]*@'
    r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}(?![A-Za-z0-9]|-[A-Za-z0-9])')
# Inside a binary file, random bytes can look like a short mixed-case
# address; an address written into a file's metadata is lower case.
BINARY_EMAIL = re.compile(
    r'(?<![A-Za-z0-9.%+-])(?<![A-Za-z0-9.%+-]_)[a-z0-9][a-z0-9._%+-]+@'
    r'(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?![A-Za-z0-9]|-[A-Za-z0-9])')
EXAMPLE_DOMAINS = ('example.com', 'example.org', 'example.net')
RESERVED_SUFFIXES = ('.example', '.test', '.invalid', '.localhost')
# The agents that write here sign their commits with these service
# addresses; none of them is a person's.
SERVICE_ADDRESSES = {'noreply@anthropic.com', 'codex@openai.com'}
# GitHub's own addresses (support, noreply, git@ for remotes) and the
# private addresses it gives its users, under github.com.
SERVICE_DOMAINS = ('github.com',)
# OpenSSH's names for its key types and extensions
# (sk-ssh-ed25519@openssh.com), which every signature made with a security
# key holds, are written at openssh.com itself, never under it.
NAME_DOMAINS = ('openssh.com',)
# icon@2x.png names an image's scale, not an address.
IMAGE_SCALE = re.compile(r'\d+(?:\.\d+)?x\.(?:png|jpe?g|pdf|svg|gif|heic|webp)')

# North American numbers written with separators or brackets, and
# international numbers written with a leading +. Digits alone, versions,
# dates (also +2026-11-06) and build numbers are not phone numbers. A
# number may end a sentence (a full stop, but not .5 or .txt), and its
# groups may be split by the spaces and dashes word processors write: a
# no-break or thin space, an en dash, a non-breaking hyphen. A dash right
# before or after it (a closed em dash in prose) ends it, unless the dash
# goes on into more digits (an id, a date), or is a hyphen joined to a word
# (id-212-...).
DASHES = '\\-\u2010-\u2015\u2212'
GAP = '[ .\u00a0\u2009\u202f' + DASHES + ']'
# An extension after the number (x12, ext. 12) belongs to it, but is not
# part of the number checked against the ones kept for fiction.
EXTENSION = r'(?:\s?(?i:extension|ext\.?|x)\s?\d{1,6})?'
# A link that calls or messages a number holds nothing else, so its digits
# need no separators: tel:5550100.
PHONE_LINK = (r'(?<![\w.+-])(?i:tel|sms|callto|facetime|facetime-audio):(?://)?\+?'
              rf'(?:[ .()\u00a0\u2009\u202f{DASHES}]{{0,2}}\d){{7,15}}(?![\d])')
NUMBER_START = rf'(?<![\w+.])(?<!\d[{DASHES}])(?<![^\W\d]-)'
NUMBER_END = rf'(?![\w]|[{DASHES}]\d|-[^\W\d])'
PHONE = re.compile(
    rf'{NUMBER_START}(?:\+?1{GAP}?)?(?:\(\d{{3}}\){GAP}?|\d{{3}}{GAP})\d{{3}}{GAP}\d{{4}}'
    rf'(?={EXTENSION}{NUMBER_END}(?!\.\w))'
    rf'|(?<![\w+])\+(?!\d{{4}}[{DASHES}]\d\d[{DASHES}]\d\d(?!\d))[1-9]'
    rf'(?:[ .()\u00a0\u2009\u202f{DASHES}]{{0,2}}\d){{7,14}}(?={EXTENSION}{NUMBER_END})'
    rf'|{PHONE_LINK}')

# A home folder's path, also right after a compiler flag (-I/Users/...,
# -L/home/...) and on macOS's data volume (/System/Volumes/Data/Users/...),
# as build logs write it.
HOME = re.compile(
    r'(?:(?<![\w.~/-])|(?<=file://)|(?<=/Volumes/Data)|(?<=-[A-Za-z])(?<![\w.~/-]-[A-Za-z]))'
    r'(?:/Users/|/home/|[A-Za-z]:[\\/]{1,2}Users[\\/]{1,2})([A-Za-z0-9][A-Za-z0-9._-]*)')
# Names that stand for "your name" or a machine's own account.
HOME_PLACEHOLDERS = {'runner', 'shared', 'user', 'username', 'you', 'yourname',
                     'your-name', 'your_name', 'name', 'me', 'example', 'guest'}

# An apostrophe that continues a word (Don't, so the entry Don is not
# found in it). Other endings ('s, 'll, 'd, 've) follow a name whole:
# "Name'll be here".
CONTRACTION = re.compile(r"['’]t(?![^\W\d_])", re.IGNORECASE)
# A line worth reading a second time with its escapes undone and its
# accents and invisible characters removed.
FOLDABLE = re.compile(r'[^\x00-\x7f]|[&%\\]')
# JSON's and Swift's \uXXXX, unless RTF's fallback follows it (below).
UNICODE_ESCAPE = re.compile(r"\\u([0-9a-fA-F]{4})(?!\\'[0-9a-fA-F]{2}|\?)")
# RTF's \uN, a decimal, read after JSON's: its delimiting space, and the
# fallback older readers show instead (\'hh or ?); and RTF's \'hh, a byte
# of Windows' Latin.
RTF_UNICODE = re.compile(r"\\u(-?\d{1,5}) ?(?:\\'[0-9a-fA-F]{2}|\?)?")
RTF_BYTE = re.compile(r"\\'([0-9a-fA-F]{2})")
# A line break or a tab between two words, as JSON and code write them.
ESCAPED_SPACE = re.compile(r'\\[nrt]')
# Markup that can split a name the page shows whole: an HTML, SVG or XML
# tag or comment, and a Markdown link's target ([Name](url), [Name][1]).
MARKUP = re.compile(r'<[A-Za-z/!?][^<>]*>|(?<=\])\([^()\n]*\)|(?<=\])\[[^\[\]\n]*\]')
# A file written into text: an SVG's or a page's picture as a data: URI.
# Python's XML writers keep an attribute's line breaks as &#10; or &#xA;.
LINE_BREAK_REFERENCE = re.compile(r'&#(?:1[03]|[xX]0*[aAdD]);')
DATA_URI = re.compile(r'data:[\w.+/=;-]*?;base64,((?:[A-Za-z0-9+/=\s]|&#(?:1[03]|[xX]0*[aAdD]);)+)',
                      re.IGNORECASE)
BASE64_RUN = re.compile(r'[A-Za-z0-9+/\s]*=*')
# Base64 characters decoded from one text, and how deep files written into
# text inside files written into text are read.
EMBEDDED_LIMIT = 16 * 1024 * 1024
EMBEDDED_DEPTH = 2


def email_allowed(address, path, support, identity=False):
    address = address.lower()
    domain = address.rpartition('@')[2]
    if (domain in EXAMPLE_DOMAINS or domain.endswith(RESERVED_SUFFIXES)
            or address in SERVICE_ADDRESSES or IMAGE_SCALE.fullmatch(domain)
            or domain in NAME_DOMAINS
            or any(domain == d or domain.endswith('.' + d) for d in SERVICE_DOMAINS)):
        return True
    if address in support:
        # The published support address: on the website's own pages, and as
        # the address the owner's own commits are signed with.
        return identity or (path is not None and path.startswith('site/'))
    return False


ADDRESS_DOMAIN = re.compile(r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}')
ADDRESS_LETTERS = frozenset(string.ascii_letters + string.digits + '._%+-')


def addresses_in(field):
    """Every address an identity's address field holds. git keeps what it
    is given between < and >, so a field may hold an address with a
    trailing dot or a comment, or two joined
    (one@example.com+two@example.org, where an address in text could not
    start after the +): each @ with the domain after it and every letter
    an address may hold before it, back to the last that is not one, so
    neither is read short."""
    for at in re.finditer('@', field):
        domain = ADDRESS_DOMAIN.match(field, at.end())
        start = at.start()
        while start and field[start - 1] in ADDRESS_LETTERS:
            start -= 1
        if domain and start < at.start():
            yield field[start:at.start()] + '@' + domain.group()


def phone_allowed(number):
    digits = re.sub(r'\D', '', number)
    if len(digits) == 11 and digits.startswith('1'):
        digits = digits[1:]
    # Numbers kept for fiction and examples: area code 555, and 555-01xx,
    # also without its area code (a link's tel:5550100).
    return (len(digits) == 10 and (digits[:3] == '555'
                                   or (digits[3:6] == '555' and digits[6:8] == '01'))
            or len(digits) == 7 and digits[:5] == '55501')


def same_class(a, b):
    return (a.isalpha() and b.isalpha()) or (a.isdigit() and b.isdigit())


def starts_word(text, index):
    if index == 0 or not same_class(text[index - 1], text[index]):
        return True
    before, first = text[index - 1], text[index]
    if before.islower() and first.isupper():
        return True  # camelCase: qzxVoice
    # An acronym before a word, as ends_word's SHOUTINGCase: AACVoice
    # starts a word at its V.
    return (before.isupper() and first.isupper() and index + 1 < len(text)
            and text[index + 1].islower())


def ends_word(text, end):
    if end >= len(text):
        return True
    last, after = text[end - 1], text[end]
    if CONTRACTION.match(text, end):
        return False
    if not same_class(last, after):
        return True
    if last.isdigit():
        return False
    if last.islower() and after.isupper():
        return True  # camelCase: qzxVoice
    # SHOUTINGCase: QZXVoice ends where the next word's capital starts.
    return (last.isupper() and after.isupper() and end + 1 < len(text)
            and text[end + 1].islower())


def rtf_unescaped(text):
    """RTF's escapes undone: \\uN (a character by number, then the
    fallback character older readers show instead) and \\'hh (a byte of
    Windows' Latin), as TextEdit, Word and LibreOffice write accents."""
    text = RTF_UNICODE.sub(lambda match: chr(int(match[1]) % 65536), text)
    return RTF_BYTE.sub(lambda match: bytes([int(match[1], 16)]).decode('cp1252', 'replace'),
                        text)


def folded(text):
    """Text with HTML entities, percent escapes, RTF's escapes, \\/ and
    \\uXXXX undone, \\n, \\r and \\t (JSON's and code's line breaks and
    tabs) read as spaces, compatibility forms (full-width letters) made
    plain, and accents and invisible characters (zero-width spaces, soft
    hyphens) removed."""
    text = percent_decoded(html.unescape(text), errors='replace').replace('\\/', '/')
    text = rtf_unescaped(UNICODE_ESCAPE.sub(lambda match: chr(int(match[1], 16)), text))
    text = ESCAPED_SPACE.sub(' ', text)
    text = unicodedata.normalize('NFKD', text)
    return ''.join(char for char in text
                   if unicodedata.category(char) not in ('Mn', 'Cf', 'Cs'))


def folded_lines(lines):
    """Each line folded where folding can change it, kept to one line."""
    return [folded(line).replace('\n', ' ').replace('\r', ' ') if FOLDABLE.search(line)
            else line for line in lines]


def entry_pattern(tokens, exact):
    # Words may be joined by spaces, line breaks, punctuation or nothing
    # (camelCase); a plural s or es may follow (Checker.matches also tries
    # the name without it, which the next word's capital S may have taken).
    body = r'[\W_]*'.join(re.escape(token) for token in tokens) + r'(?P<plural>es|s)?'
    return re.compile(body, 0 if exact else re.IGNORECASE)


def line_starts(lines):
    starts = [0]
    for line in lines[:-1]:
        starts.append(starts[-1] + len(line) + 1)
    return starts


def line_place(offset, view_starts, view_lines):
    """(line number, column) of an offset in lines, the column kept within
    its line (a folded line can be longer than the line it came from)."""
    number = bisect.bisect_right(view_starts, offset) - 1
    return number, min(offset - view_starts[number], len(view_lines[number]))


def decoded_base64(chunk):
    """The bytes a base64 run holds, b'' when it holds none."""
    chunk = LINE_BREAK_REFERENCE.sub('', chunk)
    letters = re.sub(r'\s+', '', BASE64_RUN.match(chunk).group()).rstrip('=')
    letters = letters[:len(letters) // 4 * 4] if len(letters) % 4 == 1 else letters
    try:
        return base64.b64decode(letters + '=' * (-len(letters) % 4))
    except (binascii.Error, ValueError):
        return b''  # not base64 after all: the text itself was read


class Checker:
    """Finds personal details in text. Holds the private list and the
    website's support address; reports places and kinds, never words."""

    def __init__(self, entries=(), support=frozenset()):
        self.entries = list(entries)
        self.support = {address.lower() for address in support}
        self.patterns = [(entry, entry_pattern(entry.tokens, entry.exact))
                         for entry in self.entries]
        plain = [tuple(folded(token) for token in entry.tokens) for entry in self.entries]
        self.folded_patterns = [(entry, entry_pattern(tokens, entry.exact))
                                for entry, tokens in zip(self.entries, plain)]
        # An entry folding changes (José) is also looked for in every text
        # as folding writes it (Jose), not only on lines folding changes.
        self.fold_always = any(tokens != entry.tokens
                               for entry, tokens in zip(self.entries, plain))

    @staticmethod
    def matches(text, patterns):
        """(offset, entry) for each whole-word match of a list entry."""
        for entry, pattern in patterns:
            position = 0
            while True:
                match = pattern.search(text, position)
                if match is None:
                    break
                # The plural may be the start of the next word (NameStore).
                ends = [match.end()]
                if match.group('plural'):
                    ends.append(match.start('plural'))
                end = next((end for end in ends if ends_word(text, end)), None)
                if starts_word(text, match.start()) and end is not None:
                    yield match.start(), entry
                    position = end
                else:
                    position = match.start() + 1

    def scan(self, text, path, binary, patterns, identity=False):
        """(offset, kind) for everything found in text."""
        for offset, _ in self.matches(text, patterns):
            yield offset, KIND_PRIVATE
        for match in (BINARY_EMAIL if binary else EMAIL).finditer(text):
            if not email_allowed(match.group(), path, self.support, identity):
                yield match.start(), KIND_EMAIL
        for match in HOME.finditer(text):
            if match.group(1).lower() not in HOME_PLACEHOLDERS:
                yield match.start(), KIND_HOME
        if not binary:
            for match in PHONE.finditer(text):
                if not phone_allowed(match.group()):
                    yield match.start(), KIND_PHONE

    def text(self, text, where, path=None, start_line=1, binary=False, flat=False, depth=0,
             identity=False):
        """Findings in one text. path, relative to the repository, is where
        the text will live; text without one (a message, a draft, a name)
        has no allowances. Text with no lines of its own (a binary file's
        hidden text, a name) is flat: each kind is reported once, at line 0.
        Text that says who signed something (identity) may hold the
        support address, as an author's address may."""
        flat = flat or binary
        text = unicodedata.normalize('NFC', text)
        lines = text.split('\n')
        starts = line_starts(lines)
        found = {}

        def add(offset, kind, refound=False):
            if flat:
                found.setdefault((0, 0, kind), Finding(where, 0, 0, kind))
                return
            number = bisect.bisect_right(starts, offset) - 1
            line, column = start_line + number, offset - starts[number] + 1
            if refound and any(key[0] == line and key[2] == kind for key in found):
                return  # already found as written
            found.setdefault((line, column, kind), Finding(where, line, column, kind))

        for offset, kind in self.scan(text, path, binary, self.patterns, identity):
            add(offset, kind)
        if self.fold_always or FOLDABLE.search(text):
            # The same lines with escapes undone; each keeps its line, so a
            # finding here is reported on the line it was written on.
            plain = folded_lines(lines)
            if plain != lines:
                plain_starts = line_starts(plain)
                # Phone numbers too: written with entities or invisible
                # characters (&nbsp;, &#8209;, a soft hyphen) or escaped in
                # a tel: link.
                for offset, kind in self.scan('\n'.join(plain), path, binary,
                                              self.folded_patterns, identity):
                    number, column = line_place(offset, plain_starts, lines)
                    add(starts[number] + column, kind, refound=True)
            elif self.fold_always:
                for offset, _ in self.matches(text, self.folded_patterns):
                    add(offset, KIND_PRIVATE, refound=True)
        if self.patterns and MARKUP.search(text):
            for offset, _ in self.split_by_markup(text):
                add(offset, KIND_PRIVATE, refound=True)
        if not binary and depth < EMBEDDED_DEPTH and 'base64,' in text:
            for offset, kind in self.embedded(text, path, depth):
                add(offset, kind)
        return sorted(found.values(), key=lambda f: (f.line, f.column, f.kind))

    def entry_places(self, text):
        """(line, entry) for each place text holds a list entry, read the
        ways text() reads it: as written, folded, and without its markup.
        Each match as written counts; another reading adds a place only on
        a line where that entry was not already found."""
        text = unicodedata.normalize('NFC', text)
        lines = text.split('\n')
        starts = line_starts(lines)
        places = [(bisect.bisect_right(starts, offset) - 1, entry)
                  for offset, entry in self.matches(text, self.patterns)]
        others = []
        if self.fold_always or FOLDABLE.search(text):
            plain = folded_lines(lines)
            plain_starts = line_starts(plain)
            others += [(line_place(offset, plain_starts, lines)[0], entry)
                       for offset, entry in self.matches('\n'.join(plain), self.folded_patterns)]
        if self.patterns and MARKUP.search(text):
            others += [(bisect.bisect_right(starts, offset) - 1, entry)
                       for offset, entry in self.split_by_markup(text)]
        seen = set(places)
        for place in others:
            if place not in seen:
                seen.add(place)
                places.append(place)
        return places

    def split_by_markup(self, text):
        """(offset in text, entry) for list entries that markup splits but
        a page shows whole (<b>Name</b> Surname, [Name](url) Surname),
        found in the text with its tags and link targets removed."""
        kept, view_starts, text_starts, length, position = [], [], [], 0, 0
        for match in MARKUP.finditer(text):
            if match.start() > position:
                kept.append(text[position:match.start()])
                view_starts.append(length)
                text_starts.append(position)
                length += match.start() - position
            position = match.end()
        if position < len(text):
            kept.append(text[position:])
            view_starts.append(length)
            text_starts.append(position)
        view = ''.join(kept)

        def original(offset):
            index = max(bisect.bisect_right(view_starts, offset) - 1, 0)
            return text_starts[index] + offset - view_starts[index]

        for offset, entry in self.matches(view, self.patterns):
            yield original(offset), entry
        view_lines = view.split('\n')
        plain = folded_lines(view_lines)
        if plain != view_lines or self.fold_always:
            plain_starts, starts = line_starts(plain), line_starts(view_lines)
            for offset, entry in self.matches('\n'.join(plain), self.folded_patterns):
                number, column = line_place(offset, plain_starts, view_lines)
                yield original(starts[number] + column), entry

    def embedded(self, text, path, depth):
        """(offset, kind) for what files written into text as base64 data:
        URIs hold (a picture in an SVG or a page), each at its URI."""
        left = EMBEDDED_LIMIT
        for match in DATA_URI.finditer(text):
            chunk = match.group(1)[:left]
            left -= len(chunk)
            data = decoded_base64(chunk)
            if data:
                for finding in self.data(data, '', path, depth=depth + 1):
                    yield match.start(), finding.kind
            if left <= 0:
                return

    def name_kinds(self, name, path=None):
        """The kinds found in a name: a file's, a branch's or a tag's."""
        return [finding.kind + IN_NAME for finding in self.text(name, '', path, flat=True)]

    def identity(self, name, address, where, rest=''):
        """A commit's author, committer or tagger: the name and the address,
        as written and folded (accents and escapes undone), and the rest
        of its line but the date (rest), which a header's continuation
        lines or a merged tag's tagger line can hold. The name and the
        rest get every rule text gets; only the address keeps the support
        address's allowance, as the owner's own commits are signed with it."""
        findings = {}
        signed = unicodedata.normalize('NFC', name + '\n' + address)
        if (any(True for _ in self.matches(signed, self.patterns))
                or any(True for _ in self.matches(folded(signed), self.folded_patterns))):
            findings[KIND_PRIVATE] = Finding(where, 0, 0, KIND_PRIVATE)
        # With no path, text allows the support address nowhere.
        for finding in self.text((name or '') + ('\n' + rest if rest else ''), where, flat=True):
            findings.setdefault(finding.kind, finding)
        # The address field as text too: an address written with accents
        # or escapes (folded), or a phone number.
        for finding in self.text(address or '', where, flat=True, identity=True):
            findings.setdefault(finding.kind, finding)
        if any(not email_allowed(one, None, self.support, identity=True)
               for one in addresses_in(address or '')):
            findings.setdefault(KIND_EMAIL, Finding(where, 0, 0, KIND_EMAIL))
        if HOME.search(address or ''):
            findings.setdefault(KIND_HOME, Finding(where, 0, 0, KIND_HOME))
        return list(findings.values())

    def data(self, data, where, path=None, depth=0, identity=False):
        """A file's bytes: text if it reads as text (UTF-8, UTF-16 or
        Windows' Latin); otherwise the text hidden in it and whether it
        records where it was taken. Text a binary file's format defines
        (a PNG's text, an MP3's tags, a PDF's pages, a document's words)
        gets every rule text gets; runs only guessed from its bytes keep
        the binary rules, as random bytes can look like a number or a
        short address. A signature's bytes say who signed (identity)."""
        texts = file_texts(data)
        if texts is not None:
            findings = self.text(texts[0], where, path, depth=depth, identity=identity)
            seen = {(finding.line, finding.kind) for finding in findings}
            for other in texts[1:]:
                for finding in self.text(other, where, path, depth=depth, identity=identity):
                    if (finding.line, finding.kind) not in seen:
                        seen.add((finding.line, finding.kind))
                        findings.append(finding)
            return findings
        hidden = binary_texts(data, iwa=path is not None and path.lower().endswith('.iwa'))
        findings = self.text('\n'.join(hidden.exact), where, path, flat=True, depth=depth,
                             identity=identity)
        kinds_found = {finding.kind for finding in findings}
        findings += [finding for finding in
                     self.text('\n'.join(hidden.runs), where, path, binary=True,
                               identity=identity)
                     if finding.kind not in kinds_found]
        if hidden.located:
            findings.append(Finding(where, 0, 0, KIND_PLACE))
        return findings

    def named(self, name, where, hidden, path=None):
        """(where, findings) for something reported under its name: the
        name's own findings, and the where to use for everything else
        found in it, which never shows a name that holds a finding."""
        kinds = self.name_kinds(name, path)
        if kinds:
            where = hidden
        return where, [Finding(where, 0, 0, kind) for kind in kinds]


# ------------------------------------------------------- text files

BYTE_ORDER_MARKS = ((b'\xef\xbb\xbf', 'utf-8-sig'), (b'\xff\xfe', 'utf-16'),
                    (b'\xfe\xff', 'utf-16'))
# Control characters plain text does not hold (tabs, line and page breaks
# aside): UTF-16 that decodes to them is binary data, not text.
CONTROL = re.compile('[\x00-\x08\x0b\x0e-\x1f\x7f]')


def binary_signature(data):
    """Whether data starts as a binary format the check reads by its
    structure: a PDF can hold no zero byte where a file is tested for one,
    and still keep its pages in compressed streams."""
    return (data.startswith((b'%PDF-', b'\x89PNG\r\n\x1a\n', b'\xff\xd8\xff', b'GIF87a',
                             b'GIF89a', b'PK\x03\x04', b'II*\0', b'MM\0*'))
            or data[4:8] == b'ftyp'
            or (data[:4] == b'RIFF' and data[8:12] in (b'WAVE', b'WEBP', b'AVI '))
            or (data[:3] == b'ID3' and data[3:4] in (b'\x02', b'\x03', b'\x04')))


def utf16_text(data):
    """Text written as UTF-16 without a byte order mark, as some Windows
    tools write it: in Latin text every other byte is zero. None when data
    is not such text."""
    sample = data[:8000]
    if len(sample) < 4:
        return None
    for zeros, letters, codec in ((sample[1::2], sample[0::2], 'utf-16-le'),
                                  (sample[0::2], sample[1::2], 'utf-16-be')):
        if zeros.count(0) >= 0.9 * len(zeros) and not letters.count(0):
            try:
                text = data[:len(data) // 2 * 2].decode(codec)
            except UnicodeDecodeError:
                return None
            return None if CONTROL.search(text) else text
    return None


def windows_latin(data):
    """Bytes read as Windows' Latin (cp1252), as GitHub shows a text file
    that is not UTF-8."""
    return data.decode('cp1252', errors='replace')


def decoded(data):
    """Bytes a format keeps as text without naming the encoding: UTF-8 when
    they are, otherwise Windows' Latin."""
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return windows_latin(data)


def file_texts(data):
    """A file read as text: its readings (two when it is not UTF-8: as
    UTF-8 where it is, and as Windows' Latin, so an accented name in either
    is read), or None when it is binary."""
    for mark, codec in BYTE_ORDER_MARKS:
        if data.startswith(mark):
            return [data.decode(codec, errors='replace')]
    if binary_signature(data):
        return None
    text = utf16_text(data)
    if text is not None:
        return [text]
    if b'\0' in data[:8000]:
        return None
    try:
        return [data.decode('utf-8')]
    except UnicodeDecodeError:
        return [data.decode('utf-8', errors='replace'), windows_latin(data)]


# ------------------------------------------------------- binary files

# What one file may inflate in all (its streams, chunks and archive
# entries, each read up to what is left), so a small file made to inflate
# to gigabytes cannot exhaust memory; past it, the rest is read only as it
# is stored.
HIDDEN_LIMIT = 64 * 1024 * 1024
# The strings one Exif block may give: its entries can all point at one
# long string.
EXIF_TEXT_LIMIT = 1024 * 1024
# Files inside files (an archive in an archive, a picture in a song) are
# read this many deep.
NESTING_LIMIT = 4
ZIP_ENTRY_LIMIT = 10000
# Runs of at least eight readable characters, as `strings` finds them: in
# 4 MB of random bytes, shorter runs held a three-letter name a dozen times.
READABLE = re.compile(rb'(?:[\x20-\x7e\t]|[\xc2-\xf4][\x80-\xbf]{1,3}){8,}')
READABLE_UTF16LE = re.compile(rb'(?:[\x20-\x7e]\x00){8,}')
READABLE_UTF16BE = re.compile(rb'(?:\x00[\x20-\x7e]){8,}')
EXIF_HEADER = re.compile(rb'Exif\x00\x00(?=II\*\x00|MM\x00\*)')
XMP_START, XMP_END = b'<x:xmpmeta', b'</x:xmpmeta>'
GPS_IN_XMP = re.compile(r'GPS(?:Latitude|Longitude)[^0-9]{0,40}[1-9]')
EXIF_SIZES = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8}

# Tag and attribute names; an attribute's name starts where a word does,
# so a long word is not searched again from each of its letters.
XML_MARKUP = re.compile(r'</?[\w:.-]+|(?<![\w:.-])[\w:.-]+(?==")|/?>')
XML_TAG = re.compile(r'<[^<>]*>')


class Hidden:
    """What a binary file carries where people do not see it: text read
    exactly from the fields its format defines (exact, read with every
    rule text gets), readable runs guessed from bytes (runs, read with the
    binary rules), and whether it records where a photo or video was
    taken. budget is what the file may still inflate."""

    def __init__(self):
        self.exact, self.runs, self.located, self.budget = [], [], False, HIDDEN_LIMIT

    def inflate(self, data):
        found = inflate(data, max(self.budget, 0))
        self.budget -= len(found)
        return found


def without_markup(xml):
    """XML's text and attribute values, without its tag and attribute
    names (rdf:li is markup, not a word)."""
    return XML_MARKUP.sub(' ', xml)


def readable(data):
    """The readable runs in bytes: UTF-8 (ASCII included) and UTF-16."""
    texts = [run.decode('utf-8', 'replace') for run in READABLE.findall(data)]
    texts += [run.decode('utf-16-le', 'replace') for run in READABLE_UTF16LE.findall(data)]
    texts += [run.decode('utf-16-be', 'replace') for run in READABLE_UTF16BE.findall(data)]
    return texts


def inflate(data, limit):
    """zlib data inflated, up to limit bytes. What inflates before damage
    (a cut-off stream, a bad checksum) is kept."""
    inflater, pieces, size = zlib.decompressobj(), [], 0
    for start in range(0, len(data), 65536):
        if size >= limit or inflater.eof:
            break
        try:
            piece = inflater.decompress(data[start:start + 65536], limit - size)
        except zlib.error:
            break
        pieces.append(piece)
        size += len(piece)
    return b''.join(pieces)


def xmp_packets(data):
    """Each XMP packet in bytes. Searched forward only: a file of unclosed
    packets is read in time that grows with its size, not its square."""
    position = 0
    while True:
        start = data.find(XMP_START, position)
        end = -1 if start < 0 else data.find(XMP_END, start)
        if end < 0:
            return
        yield data[start:end + len(XMP_END)]
        position = end + 1


def xmp_texts(data, hidden):
    for packet in xmp_packets(data):
        xmp = packet.decode('utf-8', 'replace')
        hidden.exact.append(without_markup(xmp))
        hidden.located = hidden.located or bool(GPS_IN_XMP.search(xmp))


def inner_texts(data, hidden, depth, xml=False):
    """A file inside another (an archive's entry, a PDF's attachment, a
    song's picture): its text read exactly, XML without its tags, or what
    its own format hides, up to NESTING_LIMIT files deep."""
    if depth + 1 >= NESTING_LIMIT:
        hidden.runs.extend(readable(data))
        return
    texts = file_texts(data)
    if texts is None:
        binary_texts(data, depth + 1, hidden)
        return
    for text in texts:
        if xml or text.lstrip().startswith('<?xml'):
            # Words split across tags (a Word document splits its runs
            # anywhere) are read joined, as well as apart.
            hidden.exact += [without_markup(text), XML_TAG.sub('', text)]
            hidden.located = hidden.located or bool(GPS_IN_XMP.search(text))
        else:
            hidden.exact.append(text)


def exif_texts(tiff, hidden):
    """The strings in an Exif (TIFF) block, and whether its GPS part holds
    a latitude or longitude."""
    if len(tiff) < 8 or tiff[:2] not in (b'II', b'MM'):
        return
    order = '<' if tiff[:2] == b'II' else '>'
    left = EXIF_TEXT_LIMIT
    queue, seen = [(struct.unpack(order + 'I', tiff[4:8])[0], False)], set()
    while queue and len(seen) < 64:
        offset, gps = queue.pop()
        if offset in seen or offset + 2 > len(tiff):
            continue
        seen.add(offset)
        count = struct.unpack(order + 'H', tiff[offset:offset + 2])[0]
        for index in range(min(count, 1024)):
            entry = tiff[offset + 2 + 12 * index:offset + 14 + 12 * index]
            if len(entry) < 12:
                break
            tag, kind, number = struct.unpack(order + 'HHI', entry[:8])
            size = EXIF_SIZES.get(kind, 0) * number
            pointer = struct.unpack(order + 'I', entry[8:12])[0]
            value = entry[8:8 + size] if size <= 4 else tiff[pointer:pointer + size]
            if tag in (0x8769, 0xA005, 0x8825):  # Exif, interoperability, GPS
                queue.append((pointer, tag == 0x8825))
            elif gps and tag in (2, 4) and kind == 5:
                hidden.located = hidden.located or any(value[i:i + 4] != b'\0\0\0\0'
                                                       for i in range(0, len(value) - 3, 8))
            elif left <= 0:
                continue  # the block has given all the text it may
            elif kind == 2:
                hidden.exact.append(value.replace(b'\0', b'\n').decode('utf-8', 'replace'))
            elif 0x9C9B <= tag <= 0x9C9F:  # Windows' title, comment, author
                hidden.exact.append(value.decode('utf-16-le', 'replace'))
            elif tag == 0x9286 and value[:8] in (b'ASCII\0\0\0', b'UNICODE\0'):
                # A user comment, named by its character set.
                codec = ('utf-8' if value[:1] == b'A' else
                         'utf-16-le' if order == '<' else 'utf-16-be')
                hidden.exact.append(value[8:].decode(codec, 'replace').replace('\0', '\n'))
            elif kind in (1, 7):  # comments and maker notes
                hidden.runs.extend(readable(value))
            left -= len(value)
        next_offset = offset + 2 + 12 * count
        if next_offset + 4 <= len(tiff):
            following = struct.unpack(order + 'I', tiff[next_offset:next_offset + 4])[0]
            if following:
                queue.append((following, gps))


def iim_texts(data, hidden):
    """The values of IPTC's records (a byline, a caption, a place's
    name), alone or inside Photoshop's resource blocks."""
    position = 0
    while True:
        position = data.find(b'\x1c\x02', position)
        if position < 0 or position + 5 > len(data):
            return
        dataset, size = data[position + 2], struct.unpack('>H', data[position + 3:position + 5])[0]
        if size & 0x8000:  # an extended length, for large binary values
            position += 2
            continue
        if dataset:  # 2:00 is the record's version number
            hidden.exact.append(decoded(data[position + 5:position + 5 + size]))
        position += 5 + size


RAW_PROFILE = re.compile(r'\s*([\w-]+)\s*\n\s*(\d+)\s*\n(.*)', re.DOTALL)


def raw_profile_texts(text, hidden):
    """A profile ImageMagick kept in a PNG's text as hexadecimal ("Raw
    profile type xmp"): its type, its length, then its bytes. XMP and Exif
    are read as they are elsewhere, IPTC and Photoshop's blocks by their
    records, and others for readable runs."""
    parsed = RAW_PROFILE.match(text)
    if not parsed:
        return
    kind, size = parsed[1].lower(), min(int(parsed[2]), max(hidden.budget, 0))
    digits = re.sub(r'[^0-9A-Fa-f]', '', parsed[3])[:2 * size]
    profile = bytes.fromhex(digits[:len(digits) // 2 * 2])
    hidden.budget -= len(profile)
    if kind == 'xmp':
        inner_texts(profile, hidden, 0, xml=True)
    elif kind == 'exif':
        exif_texts(profile[6:] if profile.startswith(b'Exif\0\0') else profile, hidden)
    elif kind in ('iptc', '8bim'):
        iim_texts(profile, hidden)
        hidden.runs.extend(readable(profile))
    else:
        hidden.runs.extend(readable(profile))


def png_texts(data, hidden):
    position = 8
    while position + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[position:position + 8])
        body = data[position + 8:position + 8 + length]
        position += 12 + length
        text = None
        if kind in (b'tEXt', b'zTXt') and body.startswith(b'Raw profile type '):
            keyword, _, rest = body.partition(b'\0')
            rest = rest if kind == b'tEXt' else hidden.inflate(rest[1:])
            raw_profile_texts(rest.decode('latin-1'), hidden)
            text = keyword.decode('latin-1')
        elif kind == b'tEXt':
            text = body.replace(b'\0', b'\n').decode('latin-1')
        elif kind == b'zTXt':
            keyword, _, rest = body.partition(b'\0')
            text = keyword.decode('latin-1') + '\n' + hidden.inflate(rest[1:]).decode('latin-1')
        elif kind == b'iTXt':
            keyword, _, rest = body.partition(b'\0')
            compressed, rest = rest[:1] == b'\x01', rest[2:]
            language, _, rest = rest.partition(b'\0')
            translated, _, words = rest.partition(b'\0')
            words = (hidden.inflate(words) if compressed else words).decode('utf-8', 'replace')
            # Compressed or not, XMP here can record where a photo was taken.
            hidden.located = hidden.located or bool(GPS_IN_XMP.search(words))
            text = (b'\n'.join([keyword, language, translated]).decode('utf-8', 'replace')
                    + '\n' + without_markup(words))
        elif kind == b'eXIf':
            exif_texts(body, hidden)
        elif kind == b'iCCP':
            hidden.runs.extend(readable(hidden.inflate(body.partition(b'\0')[2][1:])))
        elif kind == b'IEND':
            break
        elif kind not in (b'IDAT', b'fdAT') and kind[:1].islower():
            hidden.runs.extend(readable(body))  # other ancillary chunks
        if text is not None:
            hidden.exact.append(text)
            hidden.located = hidden.located or bool(GPS_IN_XMP.search(text))
    hidden.runs.extend(readable(data[position:]))  # anything after the image


def jpeg_texts(data, hidden):
    position = 2
    while position + 4 <= len(data) and data[position] == 0xFF:
        marker = data[position + 1]
        if marker == 0xFF:
            position += 1
            continue
        if marker == 0x01 or 0xD0 <= marker <= 0xD8:
            position += 2
            continue
        if marker in (0xD9, 0xDA):
            break  # the end, or the image's data
        length = struct.unpack('>H', data[position + 2:position + 4])[0]
        body = data[position + 4:position + 2 + length]
        if marker == 0xFE:
            hidden.exact.append(body.decode('utf-8', 'replace'))
        elif 0xE0 <= marker <= 0xEF and not body.startswith(b'Exif\0\0'):
            hidden.runs.extend(readable(body))  # XMP, IPTC, ICC and others
            if marker == 0xED:  # Photoshop's blocks, which carry IPTC
                iim_texts(body, hidden)
        position += 2 + length


# A place as ISO 6709 writes it (signed latitude, longitude and height, then
# a slash), the value of a video's location item.
ISO6709 = re.compile(r'[+-]\d+(?:\.\d+)?[+-]\d+(?:\.\d+)?(?:[+-]\d+(?:\.\d+)?)?(?:CRS[\w:]*)?/?')


def iso_boxes(data, start, end):
    """(kind, body start, body end) for each box between start and end."""
    position = start
    while position + 8 <= end:
        size, kind = struct.unpack('>I4s', data[position:position + 8])
        header = 8
        if size == 1 and position + 16 <= end:
            size, header = struct.unpack('>Q', data[position + 8:position + 16])[0], 16
        elif size == 0:
            size = end - position
        if size < header:
            return
        yield kind, position + header, min(position + size, end)
        position += size


def iso_value(value, hidden, depth):
    """A metadata item's data atom: text by its type, or a picture."""
    kind = struct.unpack('>I', value[:4])[0] & 0xFFFFFF
    if kind in (1, 4):
        text = value[8:].decode('utf-8', 'replace')
    elif kind in (2, 5):
        text = value[8:].decode('utf-16-be', 'replace')
    else:
        if kind in (13, 14, 27):  # cover art: JPEG, PNG, BMP
            inner_texts(value[8:], hidden, depth)
        return
    if ISO6709.fullmatch(text.strip()):
        hidden.located = True  # a place, not words
    else:
        hidden.exact.append(text)


def iso_items(data, start, end, hidden, depth, level=0, items=False):
    """The text a movie's metadata defines: iTunes-style items in ilst,
    whose values are data atoms, and QuickTime's ©-named text in udta."""
    if level > 8:
        return
    for kind, body, stop in iso_boxes(data, start, end):
        if items:  # an item of ilst: its value and, for custom items, its name
            for child, inner, inner_stop in iso_boxes(data, body, stop):
                if child == b'data' and inner_stop - inner >= 8:
                    iso_value(data[inner:inner_stop], hidden, depth)
                elif child == b'name' and inner_stop - inner >= 4:
                    hidden.exact.append(data[inner + 4:inner_stop].decode('utf-8', 'replace'))
        elif kind == b'meta':
            # ISO's meta box starts with a version and flags; QuickTime's does not.
            skip = 0 if data[body + 4:body + 8] == b'hdlr' else 4
            iso_items(data, body + skip, stop, hidden, depth, level + 1)
        elif kind == b'ilst':
            iso_items(data, body, stop, hidden, depth, level + 1, items=True)
        elif kind in (b'moov', b'trak', b'udta'):
            iso_items(data, body, stop, hidden, depth, level + 1)
        elif kind == b'loci' and stop - body >= 6:
            loci_texts(data[body + 6:stop], hidden)
        elif kind[:1] == b'\xa9' and kind != b'\xa9xyz' and stop - body >= 4:
            # QuickTime text: its length, its language, then the text.
            size = struct.unpack('>H', data[body:body + 2])[0]
            hidden.exact.append(data[body + 4:min(body + 4 + size, stop)].decode('utf-8',
                                                                                  'replace'))


def loci_texts(content, hidden):
    """3GPP's location box (ffmpeg writes one when it remuxes a located
    video to MP4), after its version and language: the place's name, its
    role, its longitude, latitude and height, the planet and notes."""
    name, _, rest = content.partition(b'\0')
    hidden.exact.append(decoded(name))
    if len(rest) >= 13:
        longitude, latitude = struct.unpack('>ii', rest[1:9])
        hidden.located = hidden.located or bool(longitude or latitude)
        hidden.exact += [decoded(part) for part in rest[13:].split(b'\0')]


def iso_media_texts(data, hidden, depth):
    """HEIC, AVIF, MP4 and QuickTime: every box but the media data, and the
    text its metadata defines."""
    for kind, body, stop in iso_boxes(data, 0, len(data)):
        if kind not in (b'mdat', b'free', b'skip', b'wide'):
            content = data[body:stop]
            hidden.located = (hidden.located or b'\xa9xyz' in content
                              or b'location.ISO6709' in content)
            hidden.runs.extend(readable(content))
    iso_items(data, 0, len(data), hidden, depth)


def riff_info(body, hidden):
    """A RIFF INFO list's fields (artist, name, comment), each a string."""
    position = 0
    while position + 8 <= len(body):
        size = struct.unpack('<I', body[position + 4:position + 8])[0]
        hidden.exact.append(decoded(body[position + 8:position + 8 + size].rstrip(b'\0'))
                            .replace('\0', '\n'))
        position += 8 + size + (size & 1)


def riff_texts(data, hidden, depth):
    """WAV, WebP and AVI: every chunk but the sound or picture itself."""
    position = 12
    while position + 8 <= len(data):
        kind, size = struct.unpack('<4sI', data[position:position + 8])
        body = data[position + 8:position + 8 + size]
        position += 8 + size + (size & 1)
        if kind == b'LIST' and body[:4] == b'INFO':
            riff_info(body[4:], hidden)
        elif kind == b'LIST' and body[:4] in (b'adtl', b'hdrl'):
            hidden.runs.extend(readable(body[4:]))
        elif kind == b'EXIF':
            exif_texts(body[6:] if body.startswith(b'Exif') else body, hidden)
        elif kind in (b'id3 ', b'ID3 ') and body.startswith(b'ID3'):
            id3_texts(body, hidden, depth)
        elif kind not in (b'data', b'LIST', b'VP8 ', b'VP8L', b'VP8X', b'ALPH', b'ANMF',
                          b'ANIM', b'idx1', b'fmt '):
            hidden.runs.extend(readable(body))


def gif_sub_blocks(data, position):
    """The bytes of a GIF's sub-blocks from position, and where they end."""
    pieces = []
    while position < len(data):
        size = data[position]
        position += 1
        if not size:
            break
        pieces.append(data[position:position + size])
        position += size
    return b''.join(pieces), position


def gif_texts(data, hidden):
    """A GIF's comment and plain-text extensions; its pictures are not read."""
    if len(data) < 13:
        return
    flags = data[10]
    position = 13 + (3 << ((flags & 7) + 1) if flags & 0x80 else 0)
    while position < len(data):
        block = data[position]
        if block == 0x21 and position + 1 < len(data):  # an extension
            label = data[position + 1]
            body, position = gif_sub_blocks(data, position + 2)
            if label == 0xFE:
                hidden.exact.append(decoded(body))
            elif label == 0x01:  # plain text, after its 12 bytes of layout
                hidden.exact.append(decoded(body[12:]))
            elif label == 0xFF:
                hidden.runs.extend(readable(body))  # application data
        elif block == 0x2C and position + 10 <= len(data):  # a picture
            flags = data[position + 9]
            position += 10 + (3 << ((flags & 7) + 1) if flags & 0x80 else 0) + 1
            _, position = gif_sub_blocks(data, position)
        else:
            break  # the trailer, or not a GIF block
    hidden.runs.extend(readable(data[position:]))  # anything after the GIF


ID3_CODECS = {0: 'latin-1', 1: 'utf-16', 2: 'utf-16-be', 3: 'utf-8'}
PICTURE_STARTS = (b'\xff\xd8\xff', b'\x89PNG\r\n\x1a\n')


def syncsafe_size(data):
    """An ID3 size: four bytes of seven bits each."""
    if len(data) < 4:
        return 0
    return (data[0] & 0x7f) << 21 | (data[1] & 0x7f) << 14 | (data[2] & 0x7f) << 7 | data[3] & 0x7f


def id3_text(body):
    """A text frame's value: its first byte names the encoding, and a zero
    character separates its values."""
    codec = ID3_CODECS.get(body[0]) if body else None
    if codec is None:
        return decoded(body)
    return body[1:].decode(codec, 'replace').replace('\0', '\n')


def id3_frame(kind, body, hidden, depth):
    if kind in (b'COMM', b'USLT', b'COM', b'ULT') and len(body) >= 4:
        hidden.exact.append(id3_text(body[:1] + body[4:]))  # after its language
    elif kind in (b'APIC', b'PIC', b'GEOB'):
        starts = [index for index in (body.find(start) for start in PICTURE_STARTS)
                  if index >= 0]
        picture = min(starts) if starts else len(body)
        hidden.exact.append(id3_text(body[:picture]))  # its type and description
        if starts:
            inner_texts(body[picture:], hidden, depth)
    elif kind[:1] == b'T' or kind in (b'WXXX', b'WXX'):
        hidden.exact.append(id3_text(body))
    elif kind[:1] == b'W':
        hidden.exact.append(decoded(body))  # a link
    else:
        hidden.runs.extend(readable(body))


def id3_texts(data, hidden, depth):
    """An ID3v2 tag (an MP3's, or a WAV's id3 chunk): its text, comment,
    lyrics and link frames, and the pictures it carries."""
    if len(data) < 10 or data[3] not in (2, 3, 4):
        return
    version, flags = data[3], data[5]
    tag = data[10:10 + syncsafe_size(data[6:10])]
    if flags & 0x80 and version < 4:
        tag = tag.replace(b'\xff\x00', b'\xff')  # unsynchronised
    position = 0
    if flags & 0x40 and version == 3 and len(tag) >= 4:
        position = 4 + struct.unpack('>I', tag[:4])[0]  # an extended header
    elif flags & 0x40 and version == 4:
        position = syncsafe_size(tag[:4])
    name_size, header = (3, 6) if version == 2 else (4, 10)
    while position + header <= len(tag):
        kind = tag[position:position + name_size]
        if not kind.isalnum():
            break  # padding
        if version == 2:
            size = int.from_bytes(tag[position + 3:position + 6], 'big')
        elif version == 3:
            size = struct.unpack('>I', tag[position + 4:position + 8])[0]
        else:
            size = syncsafe_size(tag[position + 4:position + 8])
        format_flags = tag[position + 9] if version > 2 else 0
        body = tag[position + header:position + header + size]
        position += header + size
        if version == 4 and format_flags & 0x02:
            body = body.replace(b'\xff\x00', b'\xff')
        if version == 4 and format_flags & 0x01:
            body = body[4:]  # its length before compression
        if (version == 3 and format_flags & 0x80) or (version == 4 and format_flags & 0x08):
            body = hidden.inflate(body[4:] if version == 3 else body)
        id3_frame(kind, body, hidden, depth)


def id3v1_texts(data, hidden):
    """An ID3v1 tag, the last 128 bytes of an older MP3: its title, artist,
    album and comment."""
    tag = data[-128:]
    for start, end in ((3, 33), (33, 63), (63, 93), (97, 127)):
        hidden.exact.append(decoded(tag[start:end].split(b'\0')[0]))


try:
    import lzma
    LZMA_ERRORS = (lzma.LZMAError,)
except ImportError:  # a Python without lzma opens no such entry anyway
    LZMA_ERRORS = ()
ZIP_ERRORS = (zipfile.BadZipFile, zipfile.LargeZipFile, RuntimeError, NotImplementedError,
              EOFError, OSError, ValueError, KeyError, struct.error, zlib.error) + LZMA_ERRORS


# ------------------------------------------------------------- iWork

# How deep messages inside messages are read in an iWork archive.
PROTO_DEPTH = 8


def snappy(data, limit):
    """Snappy's raw form decompressed, up to limit bytes: literals, and
    copies of bytes already written. What decompresses before damage is
    kept."""
    length, position, shift = 0, 0, 0
    while position < len(data) and shift < 35:
        byte = data[position]
        position += 1
        length |= (byte & 0x7f) << shift
        shift += 7
        if byte < 0x80:
            break
    out, limit = bytearray(), min(length, limit)
    while position < len(data) and len(out) < limit:
        tag = data[position]
        position += 1
        if tag & 3 == 0:  # a literal
            size = tag >> 2
            if size >= 60:  # its length in the next one to four bytes
                extra = size - 59
                size = int.from_bytes(data[position:position + extra], 'little')
                position += extra
            out += data[position:position + size + 1]
            position += size + 1
            continue
        if tag & 3 == 1:  # a copy with an 11-bit offset
            if position >= len(data):
                break
            size, offset = ((tag >> 2) & 7) + 4, ((tag >> 5) << 8) | data[position]
            position += 1
        else:
            width = 2 if tag & 3 == 2 else 4
            size, offset = (tag >> 2) + 1, int.from_bytes(data[position:position + width], 'little')
            position += width
        if position > len(data) or not 0 < offset <= len(out):
            break
        start = len(out) - offset
        piece = bytes(out[start:start + min(offset, size)])
        out += (piece * (size // len(piece) + 1))[:size]
    return bytes(out[:limit])


def proto_varint(data, position):
    value, shift = 0, 0
    while True:
        if position >= len(data) or shift > 63:
            raise ValueError('not a protocol buffer')
        byte = data[position]
        position += 1
        value |= (byte & 0x7f) << shift
        shift += 7
        if byte < 0x80:
            return value, position


def proto_fields(data):
    """(number, wire type, value) for each field of a protocol-buffer
    message; ValueError when data is not one."""
    fields, position = [], 0
    while position < len(data):
        key, position = proto_varint(data, position)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, position = proto_varint(data, position)
        elif wire in (1, 5):
            size = 8 if wire == 1 else 4
            value, position = data[position:position + size], position + size
        elif wire == 2:
            size, position = proto_varint(data, position)
            value, position = data[position:position + size], position + size
        else:
            raise ValueError('not a protocol buffer')
        if not number or position > len(data):
            raise ValueError('not a protocol buffer')
        fields.append((number, wire, value))
    return fields


def proto_texts(data, hidden, depth=0):
    """The strings in a protocol-buffer message, and in the messages it
    holds, read exactly: a document's words are strings."""
    try:
        fields = proto_fields(data)
    except ValueError:
        return
    for _, wire, value in fields:
        if wire != 2 or not value:
            continue
        try:
            text = value.decode('utf-8')
        except UnicodeDecodeError:
            text = ''
        if text and not CONTROL.search(text) and any(char.isalnum() for char in text):
            hidden.exact.append(text)
        if depth < PROTO_DEPTH:
            proto_texts(value, hidden, depth + 1)


def iwa_texts(data, hidden):
    """An iWork archive (.iwa, inside a Pages, Keynote or Numbers file):
    chunks of Snappy data, each a zero byte and a three-byte length; inside,
    archives, each its info (which gives its messages' lengths) and then
    its messages, whose strings hold the document's words."""
    position = 0
    while position + 4 <= len(data) and data[position] == 0 and hidden.budget > 0:
        size = int.from_bytes(data[position + 1:position + 4], 'little')
        chunk = snappy(data[position + 4:position + 4 + size], hidden.budget)
        hidden.budget -= len(chunk)
        position += 4 + size
        at = 0
        try:
            while at < len(chunk):
                size_of_info, at = proto_varint(chunk, at)
                info, at = chunk[at:at + size_of_info], at + size_of_info
                length = sum(value for number, wire, message in proto_fields(info)
                             if number == 2 and wire == 2
                             for inner, kind, value in proto_fields(message)
                             if inner == 3 and kind == 0)
                proto_texts(chunk[at:at + length], hidden)
                at += length
        except ValueError:
            hidden.runs.extend(readable(chunk[at:]))  # damaged: read what is left


def zip_texts(data, hidden, depth):
    """A ZIP archive (Word, Excel, PowerPoint, Pages, Keynote and Numbers
    files are ZIP archives): each entry's name, and its content read as a
    file of its own, XML without its tags, within the file's inflate
    budget."""
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
        entries = archive.infolist()[:ZIP_ENTRY_LIMIT]
    except ZIP_ERRORS:
        return  # not readable as an archive: its readable runs were read
    hidden.exact.append(decoded(archive.comment))
    for entry in entries:
        hidden.exact += [entry.filename, decoded(entry.comment)]
        if entry.is_dir() or hidden.budget <= 0:
            continue
        try:
            with archive.open(entry) as member:
                content = member.read(hidden.budget)
        except ZIP_ERRORS:
            continue  # encrypted or damaged: its stored bytes were read as runs
        hidden.budget -= len(content)
        if entry.filename.lower().endswith('.iwa'):
            iwa_texts(content, hidden)
            hidden.runs.extend(readable(content))
        else:
            inner_texts(content, hidden, depth,
                        xml=entry.filename.lower().endswith(('.xml', '.rels')))


# ------------------------------------------------------------------ PDF

PDF_OBJECT = re.compile(rb'(?<!\d)(\d+)\s+\d+\s+obj\b')
PDF_STREAM = re.compile(rb'stream(?:\r\n|\n|\r)')
PDF_STRING = re.compile(rb'\(|<(?!<)([0-9A-Fa-f\s]*)>')
PDF_LITERAL_PART = re.compile(rb'[^()\\]+|\\(?:[0-7]{1,3}|\r\n|[\s\S])|[()]')
PDF_ESCAPES = {b'n': b'\n', b'r': b'\r', b't': b'\t', b'b': b'\b', b'f': b'\f'}
PDF_TOKEN = re.compile(rb'\(|<<|>>|<[0-9A-Fa-f\s]*>|\[|\]|/[^\s/<>\[\]()%{}]*|%[^\r\n]*'
                       rb'|[^\s/<>\[\]()%{}]+')
PDF_SHOWS = (b'Tj', b'TJ', b"'", b'"')
PDF_HEX = re.compile(rb'<([0-9A-Fa-f\s]*)>')
PDF_RANGE_TOKEN = re.compile(rb'<([0-9A-Fa-f\s]*)>|\[|\]')
PDF_FONT_ENTRY = re.compile(rb'/Font\s*(?:<<|(\d+)\s+\d+\s+R)')
PDF_NAMED_REFERENCE = re.compile(rb'/([^\s/<>\[\]()%{}]+)\s+(\d+)\s+\d+\s+R')
PDF_TO_UNICODE = re.compile(rb'/ToUnicode\s+(\d+)\s+\d+\s+R')
# Codes one ToUnicode map may hold, the bytes of one code and of the text
# a range starts from (a ligature's few letters), and fonts one name is
# read with.
CMAP_LIMIT = 65536
CODE_LIMIT = 4
TEXT_LIMIT = 32
FONT_CHOICES = 4


def pdf_hex(digits):
    digits = re.sub(rb'[^0-9A-Fa-f]', b'', digits)
    return bytes.fromhex((digits + b'0' * (len(digits) % 2)).decode('ascii'))


def pdf_literal(data, start):
    """A literal string's bytes, its ( at start, and the index after its )."""
    parts, depth = [], 0
    for part in PDF_LITERAL_PART.finditer(data, start):
        token = part.group()
        if token == b'(':
            depth += 1
            if depth == 1:
                continue
        elif token == b')':
            depth -= 1
            if depth == 0:
                return b''.join(parts), part.end()
        elif token[:1] == b'\\':
            escaped = token[1:]
            if 0x30 <= escaped[0] <= 0x37:
                token = bytes([int(escaped, 8) & 0xFF])
            elif escaped in (b'\r\n', b'\n', b'\r'):
                continue  # a line continued
            else:
                token = PDF_ESCAPES.get(escaped, escaped)
        parts.append(token)
    return b''.join(parts), len(data)


def pdf_text(raw):
    """A PDF text string: UTF-16 after its byte order mark, otherwise UTF-8
    or PDFDocEncoding (much like Latin-1)."""
    if raw.startswith(b'\xfe\xff'):
        return raw[2:].decode('utf-16-be', 'replace')
    if raw.startswith(b'\xff\xfe'):
        return raw[2:].decode('utf-16-le', 'replace')
    try:
        return raw.decode('utf-8-sig')
    except UnicodeDecodeError:
        return raw.decode('latin-1')


def pdf_strings(source):
    """The strings in a PDF object outside any stream: its information
    (author, title), bookmarks, annotations and form values."""
    texts, position = [], 0
    while True:
        match = PDF_STRING.search(source, position)
        if match is None:
            return texts
        if match.group() == b'(':
            raw, position = pdf_literal(source, match.start())
        else:
            raw, position = pdf_hex(match.group(1)), match.end()
        texts.append(pdf_text(raw))


def pdf_objects(data):
    """(number, dictionary, stream) for each object in a PDF, stream None
    when it has none. Searched forward only: an object or stream left
    open runs to the end of the file, which ends the search."""
    position = 0
    while True:
        match = PDF_OBJECT.search(data, position)
        if match is None:
            return
        start = match.end()
        end = data.find(b'endobj', start)
        end = len(data) if end < 0 else end
        found = PDF_STREAM.search(data, start, end)
        if found is None:
            yield int(match.group(1)), data[start:end], None
            position = end + 6
            continue
        finish = data.find(b'endstream', found.end())
        finish = len(data) if finish < 0 else finish
        yield int(match.group(1)), data[start:found.start()], data[found.end():finish]
        end = data.find(b'endobj', finish)
        position = len(data) if end < 0 else end + 6


PDF_FILTER = re.compile(rb'/Filter\s*(\[[^\]]*\]|/[^\s/<>\[\]()%{}]+)')
PDF_NAME = re.compile(rb'/([^\s/<>\[\]()%{}]+)')
PDF_HEX_FILTERS = (b'ASCIIHexDecode', b'AHx')
PDF_85_FILTERS = (b'ASCII85Decode', b'A85')
PDF_FLATE_FILTERS = (b'FlateDecode', b'Fl')


def ascii85(data):
    """ASCII85 text decoded, up to its ~> end; b'' when it is damaged."""
    data = re.sub(rb'\s+', b'', data.split(b'~>', 1)[0])
    data = data[2:] if data.startswith(b'<~') else data
    try:
        return base64.a85decode(data)
    except ValueError:
        return b''


def pdf_stream(dictionary, raw, hidden):
    """A stream's content, through its filters in order: written as text
    (ASCII hex or ASCII85, as reportlab writes every page) and compressed
    with Flate. A stream with no filter is read as stored, and one with any
    other filter (a picture's JPEG) is read where it is stored."""
    found = PDF_FILTER.search(dictionary)
    data = raw
    for name in PDF_NAME.findall(found.group(1)) if found else ():
        if name in PDF_HEX_FILTERS:
            data = pdf_hex(data.split(b'>', 1)[0])
        elif name in PDF_85_FILTERS:
            data = ascii85(data)
        elif name in PDF_FLATE_FILTERS:
            data = hidden.inflate(data)
        else:
            return b''
    return data


def pdf_object_stream(dictionary, stream):
    """The objects an object stream holds: (number, source)."""
    first = re.search(rb'/First\s+(\d+)', dictionary)
    if first is None:
        return []
    first = int(first.group(1))
    numbers = [int(number) for number in re.findall(rb'\d+', stream[:first])][:2 * CMAP_LIMIT]
    pairs = list(zip(numbers[0::2], numbers[1::2]))
    objects = []
    for index, (number, offset) in enumerate(pairs):
        end = pairs[index + 1][1] if index + 1 < len(pairs) else len(stream) - first
        objects.append((number, stream[first + offset:first + end]))
    return objects


def sections(data, begin, end):
    """The bytes between each begin and the end after it."""
    position = 0
    while True:
        start = data.find(begin, position)
        if start < 0:
            return
        stop = data.find(end, start)
        stop = len(data) if stop < 0 else stop
        yield data[start + len(begin):stop]
        position = stop


class PdfMap:
    """A font's ToUnicode CMap: its character codes, all of one width in
    bytes, and the text each stands for."""

    def __init__(self, width, codes):
        self.width, self.codes = width, codes

    def decode(self, raw):
        width = self.width
        return ''.join(self.codes.get(raw[i:i + width],
                                      raw[i:i + width].decode('latin-1') if width == 1 else '')
                       for i in range(0, len(raw) - width + 1, width))


def pdf_cmap(stream):
    """A ToUnicode CMap's bfchar and bfrange sections (both forms)."""
    codes, width = {}, None
    for section in sections(stream, b'begincodespacerange', b'endcodespacerange'):
        first = PDF_HEX.search(section)
        width = width or (len(pdf_hex(first.group(1))) if first else None)
    for section in sections(stream, b'beginbfchar', b'endbfchar'):
        values = [pdf_hex(value) for value in PDF_HEX.findall(section)]
        for code, text in list(zip(values[0::2], values[1::2]))[:CMAP_LIMIT]:
            codes[code] = text.decode('utf-16-be', 'replace')
    for section in sections(stream, b'beginbfrange', b'endbfrange'):
        tokens = [(match.group(), match.group(1)) for match in PDF_RANGE_TOKEN.finditer(section)]
        index = 0
        while index + 2 < len(tokens) and len(codes) < CMAP_LIMIT:
            low, high = tokens[index][1], tokens[index + 1][1]
            if not low or high is None:
                index += 1  # out of step: look for the next range
                continue
            low = pdf_hex(low)
            if len(low) > CODE_LIMIT:
                index += 3  # not a character code: no font's codes are this long
                continue
            start, stop = int.from_bytes(low, 'big'), int.from_bytes(pdf_hex(high), 'big')
            count = max(0, min(stop - start + 1, CMAP_LIMIT - len(codes)))
            if tokens[index + 2][0] == b'[':
                index += 3
                values = []
                while index < len(tokens) and tokens[index][0] != b']':
                    if tokens[index][1] is not None:
                        values.append(pdf_hex(tokens[index][1]))
                    index += 1
                index += 1
                pairs = [(start + offset, value) for offset, value in enumerate(values[:count])]
            else:
                target = pdf_hex(tokens[index + 2][1] or b'')[:TEXT_LIMIT]
                base = int.from_bytes(target, 'big')
                index += 3
                pairs = [(start + offset, (base + offset).to_bytes(len(target), 'big'))
                         for offset in range(count) if base + offset < 256 ** len(target)]
            for code, value in pairs:
                if code < 256 ** len(low):
                    codes[code.to_bytes(len(low), 'big')] = value.decode('utf-16-be', 'replace')
    width = width or (len(next(iter(codes))) if codes else 1)
    return PdfMap(max(1, min(width, CODE_LIMIT)), codes)


def pdf_fonts(sources, maps):
    """Each font resource name (/F1) and the ToUnicode maps of the fonts it
    names on any page or form, None for a font without one. Names are read
    from every resource dictionary, so a name two pages use for two fonts
    is read with both."""
    to_unicode = {}
    for number, source in sources.items():
        found = PDF_TO_UNICODE.search(source)
        to_unicode[number] = maps.get(int(found.group(1))) if found else None
    fonts = {}
    for source in sources.values():
        for entry in PDF_FONT_ENTRY.finditer(source):
            if entry.group(1):
                names = sources.get(int(entry.group(1)), b'')
            else:
                end = source.find(b'>>', entry.end())
                names = source[entry.end():len(source) if end < 0 else end]
            for name, number in PDF_NAMED_REFERENCE.findall(names):
                choices = fonts.setdefault(name, [])
                font = to_unicode.get(int(number))
                if font not in choices and len(choices) < FONT_CHOICES:
                    choices.append(font)
    return fonts


def pdf_shown(content):
    """(font name, strings and spacings) for each text a content stream
    shows, and the other strings it holds (marked content's ActualText)."""
    shows, others, operands, font, position = [], [], [], None, 0
    while True:
        match = PDF_TOKEN.search(content, position)
        if match is None:
            return shows, others
        token, position = match.group(), match.end()
        if token == b'(':
            value, position = pdf_literal(content, match.start())
            operands.append(value)
        elif token[:1] == b'<' and token != b'<<':
            operands.append(pdf_hex(token[1:-1]))
        elif token[:1] == b'/':
            operands.append((token[1:],))  # a name
        elif token in (b'[', b']', b'<<', b'>>') or token[:1] == b'%':
            continue
        else:
            try:
                operands.append(float(token))
                continue
            except ValueError:
                pass  # an operator
            if token == b'Tf':
                names = [operand[0] for operand in operands if isinstance(operand, tuple)]
                font = names[-1] if names else font
            elif token in PDF_SHOWS:
                shows.append((font, [operand for operand in operands
                                     if isinstance(operand, (bytes, float))]))
            elif token == b'ID':  # an inline picture's bytes, up to EI
                end = content.find(b'EI', position)
                position = len(content) if end < 0 else end + 2
            else:
                others += [operand for operand in operands if isinstance(operand, bytes)]
            operands = []


def pdf_page_texts(content, fonts):
    """The text a content stream shows, decoded through the fonts its Tf
    operators choose, read twice: as one run, so a word shown a letter at
    a time is whole, and one string a line, so words shown apart stay
    apart. A wide gap in a TJ array is a space."""
    shows, others = pdf_shown(content)
    texts = [pdf_text(raw) for raw in others]
    versions = max([len(fonts.get(font) or [None]) for font, _ in shows] or [1])
    for version in range(versions):
        pieces = []
        for font, items in shows:
            choices = fonts.get(font) or [None]
            cmap = choices[min(version, len(choices) - 1)]
            piece = []
            for item in items:
                if isinstance(item, bytes):
                    piece.append(cmap.decode(item) if cmap else pdf_text(item))
                elif item <= -200:
                    piece.append(' ')
            pieces.append(''.join(piece))
        texts += [''.join(pieces), '\n'.join(pieces)]
    return texts


def pdf_texts(data, hidden, depth):
    """A PDF's information and bookmarks, the text its pages show (through
    each font's ToUnicode map, as a viewer copies it), the files attached
    to it and its compressed metadata."""
    hidden.runs.extend(readable(data))
    objects = []
    for number, dictionary, raw in pdf_objects(data):
        stream = None if raw is None else pdf_stream(dictionary, raw, hidden)
        objects.append((number, dictionary, stream))
        if stream and b'/ObjStm' in dictionary:
            objects += [(inner, source, None)
                        for inner, source in pdf_object_stream(dictionary, stream)]
    sources = {number: dictionary for number, dictionary, _ in objects}
    maps = {number: pdf_cmap(stream) for number, _, stream in objects
            if stream and (b'beginbfchar' in stream or b'beginbfrange' in stream)}
    fonts = pdf_fonts(sources, maps)
    for number, dictionary, stream in objects:
        hidden.exact.extend(pdf_strings(dictionary))
        if not stream or number in maps or b'/ObjStm' in dictionary:
            continue
        if b'/EmbeddedFile' in dictionary:
            inner_texts(stream, hidden, depth)
        elif XMP_START in stream:
            xmp_texts(stream, hidden)
        elif b'/Image' not in dictionary:  # a picture's pixels are not words
            hidden.runs.extend(readable(stream))
            if b'BT' in stream or b'BDC' in stream:
                hidden.exact.extend(pdf_page_texts(stream, fonts))


def binary_texts(data, depth=0, hidden=None, iwa=False):
    """What a binary file carries where people do not see it (a Hidden),
    read by its format; iwa says the file is an iWork archive, which has no
    signature of its own. A picture's pixels are not read: look at what a
    picture shows."""
    hidden = Hidden() if hidden is None else hidden
    if iwa:
        iwa_texts(data, hidden)
        hidden.runs.extend(readable(data))
    elif data.startswith(b'\x89PNG\r\n\x1a\n'):
        png_texts(data, hidden)
    elif data.startswith(b'\xff\xd8'):
        jpeg_texts(data, hidden)
    elif data[:4] in (b'II*\0', b'MM\0*'):
        exif_texts(data, hidden)
    elif data[4:8] in (b'ftyp', b'moov', b'wide', b'mdat', b'free', b'skip'):
        iso_media_texts(data, hidden, depth)
    elif data[:4] == b'RIFF':
        riff_texts(data, hidden, depth)
    elif data[:5] == b'%PDF-':
        pdf_texts(data, hidden, depth)
    elif data[:4] == b'GIF8':
        gif_texts(data, hidden)
    elif data[:4] == b'PK\x03\x04':
        hidden.runs.extend(readable(data))
        zip_texts(data, hidden, depth)
    elif data[:3] == b'ID3':
        hidden.runs.extend(readable(data))
        id3_texts(data, hidden, depth)
    elif data[:2] != b'BM':  # a BMP holds nothing beyond the blocks below
        hidden.runs.extend(readable(data))
    if data[-128:-125] == b'TAG':
        id3v1_texts(data, hidden)
    # Exif and XMP blocks wherever they are: inside a HEIC's items, a
    # JPEG's second picture or a video's metadata.
    for header in EXIF_HEADER.finditer(data):
        exif_texts(data[header.end():header.end() + 1024 * 1024], hidden)
    xmp_texts(data, hidden)
    return hidden


def support_addresses(root):
    """The addresses of the support page's mailto links, and a finding when
    there is more than one: the published support address is the one
    personal address the website may show."""
    try:
        page = Path(root, SUPPORT_PAGE).read_text(encoding='utf-8')
    except (OSError, UnicodeError):
        return set(), []
    addresses = {address.lower() for address in
                 re.findall(r'href="mailto:([^"?]+)', page)}
    if len(addresses) > 1:
        return set(), [Finding(SUPPORT_PAGE, 1, 1, KIND_SUPPORT)]
    return addresses, []


# --------------------------------------------------------------- git

class Tally:
    """What a run read, for its summary, and when it must stop."""

    def __init__(self, deadline=None):
        self.files = self.changes = self.commits = self.pictures = 0
        self.deadline = deadline

    def tick(self):
        if self.deadline is not None and time.monotonic() > self.deadline:
            raise SetupError('The privacy check ran out of time. Run python3 '
                             'scripts/privacy-check.py --outgoing yourself, and commit '
                             'in smaller parts.')


# Replace refs (git replace) change what git log shows, never what a push
# sends, so every object is read as it is stored.
GIT = ('git', '--no-replace-objects')


def git(root, *args, binary=False, check=True, input=None):
    # No hooks, no file-system monitor and no external diff or textconv
    # program runs: the repository's own settings never run code here.
    # A blank line in a patch keeps its leading space, so every line of a
    # patch starts with its marker (patch_changes, commit_patches).
    try:
        result = subprocess.run(
            [*GIT, '-C', str(root), '-c', 'core.quotePath=false', '-c', 'core.fsmonitor=false',
             '-c', 'core.hooksPath=/dev/null', '-c', 'diff.suppressBlankEmpty=false', *args],
            capture_output=True, timeout=300, input=input)
    except (OSError, subprocess.SubprocessError) as error:
        raise SetupError(f'git could not run ({type(error).__name__}).')
    if check and result.returncode:
        # git's own message can name a file, a revision or a line of one,
        # and CI's log is public: say which command failed, never what git
        # said.
        raise SetupError(f'git {args[0]} failed (exit status {result.returncode}). What git '
                         'said is not shown, as it can name a file: check the folder and the '
                         'revisions the check was given.')
    return result.stdout if binary else result.stdout.decode('utf-8', 'replace')


def git_patch(root, *args):
    """A patch git writes, as text that keeps the bytes of a line that is
    not UTF-8 (as surrogates), so a file in Windows' Latin is read both
    ways, as file_texts reads it whole (line_readings)."""
    return git(root, *args, binary=True).decode('utf-8', 'surrogateescape')


def line_readings(text):
    """A patch line's readings: itself, or, when its bytes are not UTF-8,
    those bytes as UTF-8 where they are and as Windows' Latin."""
    if not SURROGATE.search(text):
        return [text]
    data = text.encode('utf-8', 'surrogateescape')
    return [data.decode('utf-8', errors='replace'), windows_latin(data)]


def header_text(text):
    """A name or header from a patch, with any byte that is not UTF-8
    replaced, as git() gives it."""
    return text.encode('utf-8', 'surrogateescape').decode('utf-8', 'replace')


SURROGATE = re.compile('[\udc80-\udcff]')


def git_succeeds(root, *args):
    try:
        return subprocess.run([*GIT, '-C', str(root), *args], capture_output=True,
                              timeout=60).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def top_level(directory):
    return Path(git(directory, 'rev-parse', '--show-toplevel').strip())


def has_commits(root):
    return git_succeeds(root, 'rev-parse', '--verify', '--quiet', 'HEAD^{commit}')


def read_file(checker, root, path, hidden, tally, data=None):
    """One file's name and content, from the working tree unless data is
    given."""
    if data is None:
        full = Path(root, path)
        try:
            data = os.readlink(full).encode() if full.is_symlink() else full.read_bytes()
        except (FileNotFoundError, IsADirectoryError, NotADirectoryError):
            return []  # deleted, or a submodule
        except OSError as error:
            raise SetupError(f'a file could not be read ({type(error).__name__}).')
    tally.tick()
    tally.files += 1
    where, findings = checker.named(path, path, hidden, path)
    return findings + checker.data(data, where, path)


def tracked_files(checker, root, tally):
    """Every tracked file's content and name, as it is in the working tree."""
    findings = []
    for number, path in enumerate(git(root, 'ls-files', '-z').split('\0'), 1):
        if path:
            findings += read_file(checker, root, path,
                                  f'tracked file {number} of git ls-files', tally)
    return findings


def untracked_files(checker, root, tally, pathspecs=(), directory=None):
    findings = []
    listing = git(directory or root, 'ls-files', '-z', '--full-name', '--others',
                  '--exclude-standard', '--', *pathspecs)
    for number, path in enumerate(listing.split('\0'), 1):
        # A link is committed as the path it points to, which need not
        # exist, and may name a home folder.
        if path and (Path(root, path).is_symlink() or Path(root, path).is_file()):
            tally.pictures += path.lower().endswith(PICTURES)
            findings += read_file(checker, root, path, f'untracked file {number} of git '
                                  'ls-files --others --exclude-standard', tally)
    return findings


C_ESCAPES = {b'a': b'\a', b'b': b'\b', b't': b'\t', b'n': b'\n', b'v': b'\v', b'f': b'\f',
             b'r': b'\r', b'"': b'"', b'\\': b'\\'}
C_ESCAPE = re.compile(rb'\\([0-3][0-7][0-7]|.)', re.DOTALL)


def unquote(path):
    """A path as git writes it: as it is, or between double quotes with C
    escapes, where each \\ooo is one byte of the name's UTF-8 (letters may
    also stand as they are, with core.quotePath off). The escapes are
    undone on the bytes, so a name in any script reads back whole."""
    if len(path) < 2 or not (path.startswith('"') and path.endswith('"')):
        return path
    return C_ESCAPE.sub(
        lambda match: (bytes([int(match[1], 8)]) if len(match[1]) == 3
                       else C_ESCAPES.get(match[1], match[1])),
        path[1:-1].encode('utf-8')).decode('utf-8', 'replace')


def header_path(rest):
    """The new path in a "diff --git a/<path> b/<path>" header, which git
    writes for every file, an empty one included."""
    if rest.startswith('"'):
        quoted = re.findall(r'"(?:\\.|[^"\\])*"', rest)
        target = unquote(quoted[-1]) if len(quoted) == 2 else ''
        return target[2:] if target.startswith('b/') else None
    half = (len(rest) - 5) // 2
    if rest.startswith('a/') and rest[half + 2:half + 5] == ' b/' and \
            rest[2:half + 2] == rest[half + 5:]:
        return rest[half + 5:]
    return None


HUNK = re.compile(r'^@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')
# Only the line's shape: a name in it may itself hold " and b/", so the
# path is the one the diff --git header gave.
BINARY = re.compile(r'^Binary files .* differ$')


def patch_changes(patch):
    """(hunks, binaries, names) in a patch. Each hunk is (path, first
    line, lines): the lines of the new file it shows, in order, as
    (status, text), where status is '+' for an added line, ' ' for an
    unchanged one, and '-' for an unchanged one that lines removed just
    before it now join to the line above. binaries are the paths of the
    binary files it adds or changes, and names every path it adds or
    changes. A hunk's lines are counted from its header, so no line of a
    file is ever read as part of the patch's own headers."""
    hunks, binaries, names = [], [], []
    path, header, lines, old_left, new_left, removed = None, False, [], 0, 0, False
    for raw in patch.split('\n'):
        if not (old_left > 0 or new_left > 0):
            raw = header_text(raw)  # a header: only a hunk's lines keep their bytes
        if old_left > 0 or new_left > 0:
            marker, text = raw[:1], raw[1:]
            if marker == '\\':
                continue  # "\ No newline at end of file"
            if marker == '-':
                old_left -= 1
                removed = True
                continue
            if marker == '+':
                new_left -= 1
                lines.append(('+', text))
            else:
                old_left -= 1
                new_left -= 1
                lines.append(('-' if removed else ' ', text))
            removed = False
        elif raw.startswith('diff --git '):
            header = True
            path = header_path(raw[len('diff --git '):])
            if path is not None:
                names.append(path)
        elif header and raw.startswith('deleted file mode'):
            if path in names:
                names.remove(path)
            path = None
        elif header and raw.startswith('+++ '):
            # Git ends the line with a tab when the name holds a space; a
            # tab in a name itself is always quoted.
            target = unquote(raw[4:-1] if raw.endswith('\t') else raw[4:])
            path = target[2:] if target.startswith('b/') else None
        elif header and BINARY.match(raw):
            if path is not None:
                binaries.append(path)
        elif raw.startswith('@@'):
            hunk = HUNK.match(raw)
            if not hunk:
                raise SetupError('git wrote a patch the check could not read.')
            header, removed, lines = False, False, []
            old_left, new_left = int(hunk[1] or 1), int(hunk[3] or 1)
            if path is not None:
                hunks.append((path, int(hunk[2]), lines))
    return hunks, binaries, names


# Three unchanged lines around each change (git's own default), so a name
# whose parts sit on neighbouring lines is read whole.
PATCH_OPTIONS = ('-p', '--unified=3', '--no-color', '--no-ext-diff', '--no-textconv',
                 '--no-renames', '--src-prefix=a/', '--dst-prefix=b/')
# git log as git itself is set by default, whatever a person's settings:
# log.showSignature would put gpg's lines among a commit's fields,
# log.showRoot=false would leave out what a first commit adds, and
# i18n.logOutputEncoding (or i18n.commitEncoding) would write a commit's
# text in another encoding than UTF-8.
LOG_OPTIONS = ('--no-show-signature', '--root', '--encoding=UTF-8')


def hunk_findings(checker, lines, where, path, first):
    """Findings a hunk's change makes, in each reading of its lines (two
    when one is not UTF-8: line_readings), each place once."""
    if not any(SURROGATE.search(text) for _, text in lines):
        return reading_findings(checker, lines, where, path, first)
    findings, seen = [], set()
    for reading in (0, 1):
        variant = [(status, line_readings(text)[-1 if reading else 0]) for status, text in lines]
        for finding in reading_findings(checker, variant, where, path, first):
            if (finding.line, finding.column, finding.kind) not in seen:
                seen.add((finding.line, finding.column, finding.kind))
                findings.append(finding)
    return findings


def reading_findings(checker, lines, where, path, first):
    """Findings a hunk's change makes: the hunk's new lines are read as
    one text, so a phrase wrapped over lines is found, and what lay
    wholly in unchanged lines that were already neighbours is left out,
    as it was there before. A finding that touches an added line, or
    reaches across lines that were removed, is new."""
    if all(status == ' ' for status, _ in lines):
        return []
    found = checker.text('\n'.join(text for _, text in lines), where, path, first)
    blocks, block = [], None
    for number, (status, text) in enumerate(lines):
        if status == '+':
            block = None
            continue
        if status == '-' or block is None:
            block = (first + number, [])
            blocks.append(block)
        block[1].append(text)
    old = {(finding.line, finding.column, finding.kind) for start, texts in blocks
           for finding in checker.text('\n'.join(texts), where, path, start)}
    return [finding for finding in found
            if (finding.line, finding.column, finding.kind) not in old]


# A PDF with no zero byte near its start is text to git, which then shows
# only its compressed bytes, line by line: such a file is read whole too.
TEXT_TO_GIT = ('.pdf', '.ai')


def read_patch(checker, patch, label, blob, tally):
    """Findings in a patch: its paths, what its hunks add (hunk_findings)
    and its binary files, read through blob(path). Each path's name is
    checked before anything is reported under it, whichever line of the
    patch named it, so no report shows a name that holds a finding."""
    findings, places = [], {}
    hunks, binaries, names = patch_changes(patch)

    def place(path):
        if path not in places:
            tally.tick()
            tally.changes += 1
            tally.pictures += path.lower().endswith(PICTURES)
            where, found = checker.named(path, path + label,
                                         f'changed file {len(places) + 1}{label}', path)
            places[path] = where
            findings.extend(found)
        return places[path]

    for path in names:
        place(path)
    for path, first, lines in hunks:
        where = place(path)
        findings.extend(hunk_findings(checker, lines, where, path, first))
        if path.lower().endswith(TEXT_TO_GIT) or (
                first == 1 and lines and binary_signature(lines[0][1].encode('utf-8', 'surrogateescape'))):
            binaries.append(path)
    for path in dict.fromkeys(binaries):
        where = place(path)
        tally.tick()
        findings.extend(checker.data(blob(path), where, path))
    return findings


def merge_patches(root, revisions):
    """What merge commits add beyond merging cleanly: a conflict's
    resolution, or a change made while merging. Git before 2.36 cannot
    say, so there a merge is read against its first parent; and git skips
    a merge of three or more branches (an octopus) in a remerge diff, with
    only a warning, so those are always read against their first parent."""
    if not git(root, 'rev-list', '--merges', '-n', '1', *revisions, '--').strip():
        return ''
    octopus = git_patch(root, 'log', *LOG_OPTIONS, '--min-parents=3', '--format=%x01%H',
                  '--diff-merges=first-parent', *PATCH_OPTIONS, *revisions, '--')
    for option in ('--remerge-diff', '--diff-merges=first-parent'):
        try:
            return git_patch(root, 'log', *LOG_OPTIONS, '--merges', '--max-parents=2',
                       '--format=%x01%H', option, *PATCH_OPTIONS, *revisions,
                       '--') + '\n' + octopus
        except SetupError:
            continue
    raise SetupError('git could not show what the merge commits change.')


# A commit's full id, as --format=%H writes it (SHA-1 or SHA-256).
COMMIT_ID = re.compile(r'[0-9a-f]{40}(?:[0-9a-f]{24})?')


def commit_patches(log):
    """(id, patch) for each commit in git log -p output written with
    --format=%x01%H. Every line of a patch starts with a space, +, -, \\
    or a word of its own headers, so only a line that starts with \\x01
    starts a commit: the same byte inside a file never splits one, and
    no line of a file is ever read as a commit's id."""
    for chunk in ('\n' + log).split('\n\x01')[1:]:
        sha, _, body = chunk.partition('\n')
        if not COMMIT_ID.fullmatch(sha):
            raise SetupError('git log wrote a line the check could not read.')
        yield sha, body


def git_texts(data):
    """Text git keeps as it was given (a commit's or a tag's message and
    names, which a push sends as they are), in each reading: as UTF-16
    when it starts with a byte order mark or reads as UTF-16 without one,
    as file_texts reads a file; as UTF-8, or, when it is not, as UTF-8
    where it is and as Windows' Latin, so an accented name in either is
    read; and, when it holds zero bytes, without them, so wide text no
    reading guesses (UTF-16 whose letters look like binary data, UTF-32)
    is read too, and as UTF-16 and UTF-32 in either byte order, so an
    accented letter in either is read, also after bytes that put it out
    of step (the bytes without zeros, read as Windows' Latin)."""
    texts = []
    for mark, codec in BYTE_ORDER_MARKS[1:]:
        if data.startswith(mark):
            texts.append(data.decode(codec, errors='replace'))
    unmarked = utf16_text(data) if not texts else None
    if unmarked is not None:
        texts.append(unmarked)
    try:
        texts.append(data.decode('utf-8'))
    except UnicodeDecodeError:
        texts += [data.decode('utf-8', errors='replace'), windows_latin(data)]
    if b'\0' in data:
        texts.append(data.replace(b'\0', b'').decode('utf-8', errors='replace'))
        texts.append(windows_latin(data.replace(b'\0', b'')))
        texts += [data.decode(codec, errors='replace')
                  for codec in ('utf-16-le', 'utf-16-be', 'utf-32-le', 'utf-32-be')]
    return texts


def readings_of(*fields):
    """Each reading of fields (bytes) read together, as tuples of texts:
    the first field's readings go with the second's, and so on."""
    texts = [git_texts(field) for field in fields]
    return [tuple(one[min(number, len(one) - 1)] for one in texts)
            for number in range(max(len(one) for one in texts))]


def merged(read, readings):
    """read's findings in readings of one text (tuples of texts read
    together), as Checker.data reads a file: all of the first reading's,
    and of the others' only those at a place and of a kind not found
    yet, so one name is reported once, at the column the first reading
    gives, however many readings find it."""
    findings, seen = [], set()
    for number, reading in enumerate(dict.fromkeys(readings)):
        for finding in read(*reading):
            place = (finding.where, finding.line, finding.kind)
            if not number or place not in seen:
                findings.append(finding)
            seen.add(place)
    return findings


def each_reading(read, *fields):
    """read's findings in each reading of fields (bytes) (merged)."""
    return merged(read, readings_of(*fields))


def object_parts(data):
    """A commit's or a tag's object as git keeps it, and a push sends it:
    its header lines, each with its continuation lines, and its message."""
    header, _, message = data.partition(b'\n\n')
    lines = []
    for line in header.split(b'\n'):
        if line.startswith(b' ') and lines:
            lines[-1].append(line[1:])
        else:
            lines.append([line])
    return [b'\n'.join(pieces) for pieces in lines], message


def stored_objects(root, shas):
    """(sha, bytes) for each object, as git keeps it."""
    out = git(root, 'cat-file', '--batch', binary=True,
              input=b''.join(sha.encode('ascii') + b'\n' for sha in shas))
    position = 0
    for sha in shas:
        end = out.find(b'\n', position)
        header = out[position:end].split()
        if end < 0 or len(header) != 3 or not header[2].isdigit():
            raise SetupError('git cat-file wrote a line the check could not read.')
        start = end + 1
        yield sha, out[start:start + int(header[2])]
        position = start + int(header[2]) + 1


IDENTITY_DATE = re.compile(rb' -?\d+ [+-]\d{4}')
OBJECT_ID = re.compile(rb'[0-9a-f]{40}(?:[0-9a-f]{24})?')
OBJECT_TYPES = (b'commit', b'tree', b'blob', b'tag')


def identity_parts(value):
    """An author's, committer's or tagger's header as (name, address,
    the rest), or None when it holds no address: the rest is what follows
    the address but its date, which git keeps too (a continuation line,
    or more of a merged tag's tagger line)."""
    # The last ' <' with a '>' after it, and the first '>' after that,
    # found without a pattern that would try every ' <' to the end.
    last = value.rfind(b'>')
    start = value.rfind(b' <', 0, last)
    if last < 0 or start < 0:
        return None
    end = value.index(b'>', start + 2)
    rest = value[end + 1:]
    date = IDENTITY_DATE.match(rest)
    return value[:start], value[start + 2:end], rest[date.end():] if date else rest


# A signature block's own lines: where it begins and ends, an armor
# header (Version:, Comment:), a line of its base64 (a last line may hold
# padding alone) and OpenPGP's checksum.
ARMOR_BEGIN = re.compile(r'-----BEGIN [A-Z0-9 ]+-----$')
ARMOR_END = re.compile(r'-----END [A-Z0-9 ]+-----')
ARMOR_HEADER = re.compile(r'[A-Za-z][A-Za-z0-9-]*: .*')
ARMOR_BASE64 = re.compile(r'[A-Za-z0-9+/]*={0,2}')
ARMOR_CHECKSUM = re.compile(r'=[A-Za-z0-9+/]{4}')


def armored(text):
    """text with the base64 of each signature block in it (OpenPGP's,
    SSH's, X.509's) blanked out, each line kept so every other line keeps
    its number, and the bytes each such block holds. A block begins
    again at each BEGIN line, so a clearsigned message's own text is never
    taken for its signature, and is left as text unless it is one
    (armored_body)."""
    lines, blocks, inside = text.split('\n'), [], None
    for number, line in enumerate(lines):
        line = line.strip()
        if ARMOR_BEGIN.search(line):
            inside = []
        elif inside is not None and ARMOR_END.fullmatch(line):
            body = armored_body([lines[one].strip() for one in inside])
            if body is not None:
                blocks.append(body[0])
                for one in inside[body[1]:]:
                    lines[one] = ''
            inside = None
        elif inside is not None:
            inside.append(number)
    return '\n'.join(lines), blocks


def armored_body(lines):
    """(the bytes, the index of the first line of base64) for the lines
    between a block's BEGIN and END lines, or None when they are not a
    signature's: armor headers, a blank line, then lines of base64 of
    one width (the last no wider), and OpenPGP's checksum, that decode
    to binary data (holding a zero byte, as every signature format's
    lengths do)."""
    first = 0
    while first < len(lines) and ARMOR_HEADER.fullmatch(lines[first]):
        first += 1
    if first < len(lines) and not lines[first]:
        first += 1
    body = lines[first:]
    if body and ARMOR_CHECKSUM.fullmatch(body[-1]):
        body = body[:-1]
    if (not body or not all(line and ARMOR_BASE64.fullmatch(line) for line in body)
            or any(len(line) != len(body[0]) for line in body[:-1])
            or len(body[-1]) > len(body[0])):
        return None
    try:
        data = base64.b64decode(''.join(body), validate=True)
    except (binascii.Error, ValueError):
        return None
    return (data, first) if b'\0' in data else None


# How deep packets inside packets (an OpenPGP signature in a signature)
# and DER's elements are read: a certificate in an X.509 signature sits
# about a dozen deep.
SIGNATURE_DEPTH = 32


def signature_texts(data):
    """The text a signature's bytes hold, read by their format, or None
    for a format the check does not read field by field (an SSH
    signature, whose readable runs are read as a binary file's are): an
    OpenPGP signature's (openpgp_texts) or an X.509 one's (der_texts)."""
    if data[:1] == b'\x30':
        texts = []
        return texts if der_items(data, 0, len(data), 0, texts) == len(data) else None
    if data[:1] and data[0] & 0x80:
        return openpgp_texts(data, 0)
    return None


def openpgp_packets(data):
    """(tag, body) for each OpenPGP packet in data (RFC 9580, 4.2), or None
    when data is not a whole run of them."""
    packets, position = [], 0
    while position < len(data):
        first = data[position]
        if not first & 0x80:
            return None
        if first & 0x40:
            tag, octet = first & 0x3f, data[position + 1:position + 2]
            if not octet or 223 < octet[0] < 255:
                return None  # a partial length: a stream, not a signature
            size = 1 if octet[0] < 192 else 2 if octet[0] < 224 else 5
            field = data[position + 1:position + 1 + size]
            if len(field) < size:
                return None
            length = (field[0] if size == 1
                      else ((field[0] - 192) << 8) + field[1] + 192 if size == 2
                      else int.from_bytes(field[1:], 'big'))
        else:
            tag, size = (first >> 2) & 0x0f, 1 << (first & 0x03)
            if size == 8:
                return None  # an indeterminate length
            field = data[position + 1:position + 1 + size]
            if len(field) < size:
                return None
            length = int.from_bytes(field, 'big')
        position += 1 + size
        if position + length > len(data):
            return None
        packets.append((tag, data[position:position + length]))
        position += length
    return packets


def openpgp_texts(data, depth):
    """The text OpenPGP packets hold where a signature may name someone:
    a user ID packet (an embedded key's), and in a signature its signer's
    user ID (subpacket 28), policy URI (26), preferred key server (24),
    each readable notation's value (20) and the signatures it embeds (32).
    A notation's name, written like an address (Sequoia's salt, in its
    namespace notations.sequoia-pgp.org), names the notation, not a
    person, and is not read. None when data is not OpenPGP."""
    packets = openpgp_packets(data)
    if not packets or depth > SIGNATURE_DEPTH:
        return None
    texts = []
    for tag, body in packets:
        if tag == 13:
            texts.append(decoded(body))
        elif tag == 2:
            found = signature_packet_texts(body, depth)
            if found is None:
                return None
            texts += found
    return texts


def signature_packet_texts(body, depth):
    """openpgp_texts for one signature packet's body (RFC 9580, 5.2), or
    None when it does not read as one."""
    if body[:1] == b'\x03':
        return []  # version 3 holds no subpackets
    if body[:1] not in (b'\x04', b'\x05', b'\x06'):
        return None
    width = 4 if body[0] == 6 else 2
    texts, position = [], 4
    for _ in range(2):  # the hashed subpackets, then the others
        area = body[position:position + width]
        if len(area) < width:
            return None
        length = int.from_bytes(area, 'big')
        position += width
        if position + length > len(body):
            return None
        found = subpacket_texts(body[position:position + length], depth)
        if found is None:
            return None
        texts += found
        position += length
    return texts


def subpacket_texts(area, depth):
    """The texts in one area of a signature's subpackets, or None."""
    texts, position = [], 0
    while position < len(area):
        octet = area[position]
        size = 1 if octet < 192 else 2 if octet < 255 else 5
        field = area[position:position + size]
        if len(field) < size:
            return None
        length = (octet if size == 1 else ((octet - 192) << 8) + field[1] + 192 if size == 2
                  else int.from_bytes(field[1:], 'big'))
        position += size
        if not length or position + length > len(area):
            return None
        kind, value = area[position] & 0x7f, area[position + 1:position + length]
        position += length
        if kind in (24, 26, 28):
            texts.append(decoded(value))
        elif kind == 20:
            if len(value) < 8:
                return None
            names, values = int.from_bytes(value[4:6], 'big'), int.from_bytes(value[6:8], 'big')
            if 8 + names + values != len(value):
                return None
            if value[0] & 0x80:  # human-readable
                texts.append(decoded(value[8 + names:]))
        elif kind == 32:
            found = signature_packet_texts(value, depth + 1) if depth < SIGNATURE_DEPTH else None
            if found is None:
                return None
            texts += found
    return texts


# DER's string types (UTF8String, PrintableString, T61String, IA5String,
# VisibleString, UniversalString, BMPString) and a certificate's names
# (rfc822Name, a URI), with the encoding each is written in.
DER_STRINGS = {0x0c: 'utf-8', 0x13: 'latin-1', 0x14: 'latin-1', 0x16: 'latin-1',
               0x1a: 'latin-1', 0x1c: 'utf-32-be', 0x1e: 'utf-16-be', 0x81: 'latin-1',
               0x86: 'latin-1'}


def der_items(data, position, end, depth, texts):
    """Read the DER (or BER) elements of an X.509 signature (RFC 5652's
    SignedData, with its certificates) from position to end, or to an
    end-of-contents mark when end is None, adding each string's text to
    texts; the position after them, or None when they are not DER. An
    OCTET STRING that holds a SEQUENCE is read too, as a certificate's
    extensions (its other names) are kept that way."""
    while end is None or position < end:
        if end is None and data[position:position + 2] == b'\0\0':
            return position + 2
        if position + 2 > len(data):
            return None
        tag, octet = data[position], data[position + 1]
        position += 2
        if tag & 0x1f == 0x1f:
            return None  # a high tag number: not in a signature
        if octet == 0x80:
            if not tag & 0x20 or depth >= SIGNATURE_DEPTH:
                return None
            position = der_items(data, position, None, depth + 1, texts)
            if position is None:
                return None
            continue
        if octet & 0x80:
            size = octet & 0x7f
            if not 0 < size <= 4 or position + size > len(data):
                return None
            length = int.from_bytes(data[position:position + size], 'big')
            position += size
        else:
            length = octet
        stop = position + length
        if stop > (len(data) if end is None else end):
            return None
        if tag & 0x20:
            if depth >= SIGNATURE_DEPTH or der_items(data, position, stop, depth + 1,
                                                     texts) != stop:
                return None
        elif tag in DER_STRINGS:
            texts.append(data[position:stop].decode(DER_STRINGS[tag], errors='replace'))
        elif tag == 0x04 and data[position:position + 1] == b'\x30' and depth < SIGNATURE_DEPTH:
            inner = []
            if der_items(data, position, stop, depth + 1, inner) == stop:
                texts += inner
        position = stop
    return position


def signed_text(checker, text, place, part):
    """Findings in text that may hold a signature (a commit's gpgsig
    header, a tag's message), reported as place's part: its words read
    as text, but not a signature's base64, which is full of runs that
    read as words (a word may start at a case change, a / or a +). The
    bytes the base64 holds are read by their format (signature_texts),
    or else as a binary file's are, as they can hold the signer's name
    and address, which may be the support address, as an author's may."""
    text, blocks = armored(text)
    findings = checker.text(text, f'{place} {part}')
    for data in blocks:
        texts = signature_texts(data)
        if texts is None:
            findings += checker.data(data, f'{place} signature', identity=True)
        else:
            findings += checker.text('\n'.join(texts), f'{place} signature', flat=True,
                                     identity=True)
    return findings


def tag_findings(checker, data, where):
    """A tag object's findings (a pushed tag's, or one a merge commit
    carries): its name, its tagger, every other header and its message,
    with its signature. Only the first object, type and tag lines are
    what git reads them as; any other line is read as text, and every
    tagger line as an identity."""
    findings, first = [], set()
    headers, message = object_parts(data)
    for line in headers:
        key, _, value = line.partition(b' ')
        signed = identity_parts(value) if key == b'tagger' else None
        if key not in first and (key == b'object' and OBJECT_ID.fullmatch(value)
                                 or key == b'type' and value in OBJECT_TYPES):
            first.add(key)
        elif key == b'tag' and key not in first:
            first.add(key)
            findings += each_reading(lambda name: checker.named(
                name, '', where + ' name')[1], value)
        elif key == b'tagger' and signed:
            findings += each_reading(lambda name, address, rest: checker.identity(
                name, address, where + ' tagger', rest), *signed)
        else:
            findings += each_reading(lambda text: signed_text(checker, text, where, 'header'),
                                     line)
    return findings + each_reading(lambda text: signed_text(checker, text, where, 'message'),
                                   message)


def commits(checker, root, revisions, tally):
    """The commits in a revision range: their messages, authors,
    committers and other headers, and the lines, files and names their
    changes add. Each commit is read as git shows it in UTF-8, converted
    from the encoding the commit names, and as git keeps it, which is what
    a push sends: a label can misdescribe the bytes, and git log stops a
    message at a zero byte."""
    findings, shown = [], {}
    log = git(root, 'log', *LOG_OPTIONS, '-z', '--format=%H%n%an%n%ae%n%cn%n%ce%n%B',
              *revisions, '--', binary=True)
    for record in log.split(b'\0'):
        fields = record.split(b'\n', 5)
        if len(fields) < 6 or not COMMIT_ID.fullmatch(fields[0].strip().decode('ascii', 'replace')):
            continue
        shown[fields[0].strip().decode('ascii')] = fields[1:]
    for full, stored in stored_objects(root, list(shown)) if shown else ():
        sha = full[:12]
        tally.tick()
        tally.commits += 1
        name, address, committer, committer_address, message = shown[full]
        headers, stored_message = object_parts(stored)
        people = {b'author': [(name, address, b'')],
                  b'committer': [(committer, committer_address, b'')]}
        other = []
        for line in headers:
            key, _, value = line.partition(b' ')
            signed = identity_parts(value) if key in people else None
            if key in (b'tree', b'parent') and OBJECT_ID.fullmatch(value):
                continue
            if key in people and signed:
                people[key].append(signed)
            elif key == b'mergetag':
                # A merge of a signed tag carries the whole tag.
                findings += tag_findings(checker, value, f'commit {sha} merged tag')
            else:
                # A signature too: its armor can hold a comment.
                other.append(line)
        for key, identities in people.items():
            where = f'commit {sha} {key.decode()}'
            findings += merged(
                lambda one, other, rest, where=where: checker.identity(one, other, where, rest),
                [reading for fields in identities for reading in readings_of(*fields)])
        for line in other:
            findings += each_reading(
                lambda text: signed_text(checker, text, f'commit {sha}', 'header'), line)
        findings += merged(lambda text: checker.text(text, f'commit {sha} message'),
                           readings_of(message) + readings_of(stored_message))
    patches = git_patch(root, 'log', *LOG_OPTIONS, '--no-merges', '--format=%x01%H',
                  *PATCH_OPTIONS, *revisions, '--') + '\n' + merge_patches(root, revisions)
    for sha, body in commit_patches(patches):
        findings += read_patch(
            checker, body, f' (commit {sha[:12]})',
            lambda path, sha=sha: git(root, 'cat-file', 'blob', f'{sha}:{path}', binary=True),
            tally)
    return findings


def tags(checker, root, objects):
    """Annotated tags among the objects pushed, and every tag a tag points
    to in turn, which the push sends with it: each one's name (a renamed
    tag keeps its first name inside), tagger and message."""
    findings, seen = [], set()
    for name in objects:
        while git(root, 'cat-file', '-t', name, check=False).strip() == 'tag':
            sha = git(root, 'rev-parse', name).strip()
            if sha in seen:
                break
            seen.add(sha)
            data = git(root, 'cat-file', 'tag', sha, binary=True)
            findings += tag_findings(checker, data, f'tag object {sha[:12]}')
            target = re.search(rb'^object ([0-9a-f]+)$', data.partition(b'\n\n')[0],
                               re.MULTILINE)
            if not target:
                break
            name = target.group(1).decode('ascii')
    return findings


def merge_base_tree(root):
    """While a merge waits to be committed, the tree that merging cleanly
    gives (conflicts left as git marks them), so the commit is read for
    what its resolution adds, as a push reads a merge (merge_patches);
    otherwise None, and the commit is read against HEAD. Git before 2.38
    cannot make one, and neither can a merge of several branches."""
    heads = git(root, 'rev-parse', '--verify', '--quiet', 'MERGE_HEAD', check=False).split()
    merging = Path(git(root, 'rev-parse', '--git-path', 'MERGE_HEAD').strip())
    merging = merging if merging.is_absolute() else Path(root, merging)
    try:
        if len(heads) != 1 or len(merging.read_text(encoding='utf-8').split()) != 1:
            return None
    except (OSError, UnicodeDecodeError):
        return None
    try:
        result = subprocess.run(
            [*GIT, '-C', str(root), 'merge-tree', '--write-tree', '--no-messages', 'HEAD',
             'MERGE_HEAD'], capture_output=True, timeout=300)
    except (OSError, subprocess.SubprocessError):
        return None
    tree = result.stdout.decode('ascii', 'replace').split('\n', 1)[0].strip()
    # 0: merged cleanly; 1: with conflicts, which the tree marks.
    return tree if result.returncode in (0, 1) and COMMIT_ID.fullmatch(tree) else None


def staged(checker, root, tally):
    """What the next commit would add: the index, compared with HEAD, or
    while merging, with what merging cleanly gives (merge_base_tree)."""
    # ':0:' names the index's own copy: after ':' alone, a name that
    # starts with 0: to 3: (a Mac's 2/3 is stored as 2:3) is a stage.
    blob = lambda path: git(root, 'cat-file', 'blob', ':0:' + path, binary=True)  # noqa: E731
    if not has_commits(root):
        return [finding for number, path in
                enumerate(git(root, 'ls-files', '-z').split('\0'), 1) if path
                for finding in read_file(checker, root, path, f'staged file {number}',
                                         tally, data=blob(path))]
    base = merge_base_tree(root) or 'HEAD'
    return read_patch(checker, git_patch(root, 'diff', '--cached', base, *PATCH_OPTIONS, '--'),
                      ' (staged)', blob, tally)


def pending(checker, root, directory, pathspecs, tally):
    """Files a git add in the same command would stage, read whole: changed
    tracked files and untracked ones under the paths it names, and with
    --force ignored ones too. Each pathspec is a path, named from
    directory, or (folder, path, forced) for an add that ran in another
    folder; an add in another repository does not feed this commit."""
    groups = {}
    for spec in pathspecs:
        folder, path, forced = (directory, spec, False) if isinstance(spec, str) else spec
        groups.setdefault((str(folder), bool(forced)), []).append(path)
    listings = []
    for (folder, forced), paths in groups.items():
        if top_level(folder).resolve() != Path(root).resolve():
            continue
        listings.append(('changed file {} to be added',
                         git(folder, 'ls-files', '-z', '--full-name', '--modified', '--', *paths)))
        listings.append(('untracked file {} to be added',
                         git(folder, 'ls-files', '-z', '--full-name', '--others',
                             '--exclude-standard', '--', *paths)))
        if forced:
            listings.append(('ignored file {} to be added', git(
                folder, 'ls-files', '-z', '--full-name', '--others', '--ignored',
                '--exclude-standard', '--', *paths)))
    findings, seen = [], set()
    for hidden, listing in listings:
        for number, path in enumerate(listing.split('\0'), 1):
            # A link is committed as the path it points to, which need not
            # exist, and may name a home folder.
            if not path or path in seen or not (Path(root, path).is_symlink()
                                               or Path(root, path).is_file()):
                continue
            seen.add(path)
            tally.pictures += path.lower().endswith(PICTURES)
            findings += read_file(checker, root, path, hidden.format(number), tally)
    return findings


def working_changes(checker, root, tally):
    """Changes not yet committed: what is staged, which the next commit
    takes even when the file has changed again since; what is changed but
    not staged, compared with what is staged; files a merge left in
    conflict, read whole, as git can show them only as a combined diff;
    and files git does not track yet."""
    findings = staged(checker, root, tally)
    conflicted = list(dict.fromkeys(
        entry.partition('\t')[2] for entry in git(root, 'ls-files', '-u', '-z').split('\0')
        if '\t' in entry))
    for number, path in enumerate(conflicted, 1):
        findings += read_file(checker, root, path, f'file {number} left in conflict', tally)
    findings += read_patch(checker, git_patch(root, 'diff', *PATCH_OPTIONS, '--', '.',
                                        *(':(exclude,literal)' + path for path in conflicted)),
                           ' (not committed)', lambda path: Path(root, path).read_bytes()
                           if Path(root, path).is_file() else b'', tally)
    return findings + untracked_files(checker, root, tally)


# git's scp-like address, [user@]host:path, with no slash before the colon;
# a host in brackets is kept as written.
SCP_ADDRESS = re.compile(r'(?:([^@/:]+)@)?(\[[^\]/]*\]|[^/:\[\]]+):(?!//)(.+)')
# The port a scheme uses when a URL names none, where the scheme fixes it.
# ssh is not here: with no port, ssh takes the one its own settings give.
DEFAULT_PORTS = {'https': 443, 'http': 80, 'git': 9418, 'ftp': 21, 'ftps': 990}
SSH_SCHEMES = ('ssh', 'git+ssh', 'ssh+git')


def repository_address(root, url):
    """A repository's address written one way, so that two ways git
    accepts of writing one repository compare equal and two repositories
    never do: where that is not certain, they count as two, which only
    makes a push read more. A path, relative or file://, is the folder it
    resolves to. A host's address keeps its scheme (ssh, git+ssh and the
    scp-like [user@]host:path are one), a port the scheme does not use by
    default (any port written for ssh), and its path without a trailing /
    or .git; over ssh, a path that does not start at / starts in the home
    of the user who signs in (host:path, ~/path), so it keeps that user.
    The host is compared in lower case, and an IPv6 host's port stays
    apart from it. On github.com, the scheme and user only name the way
    in, and owner and repository names are compared in lower case."""
    url = url.strip()
    if '://' in url:
        parts = urlsplit(url)
        scheme, user, path = parts.scheme.lower(), parts.username or '', parts.path
        try:
            host, port = (parts.hostname or '').lower(), parts.port
        except ValueError:  # a port that is not a number: kept as written
            host, port = parts.netloc.rpartition('@')[2].lower(), None
        port = '' if port is None or port == DEFAULT_PORTS.get(scheme) else str(port)
        if scheme == 'file':
            host = ''
        elif scheme in SSH_SCHEMES:
            # git gives ssh://host/~/path to the server as ~/path.
            scheme, path = 'ssh', path[1:] if path.startswith('/~') else path
    else:
        scp = SCP_ADDRESS.fullmatch(url)
        if scp:
            scheme, user, host, port, path = 'ssh', scp[1] or '', scp[2].lower(), '', scp[3]
        else:
            host, path = '', url
    if not host:
        try:
            return ('', str(Path(root, os.path.expanduser(path)).resolve()))
        except (OSError, RuntimeError):
            return ('', path)
    path = path.rstrip('/')
    path = path[:-4] if path.endswith('.git') else path
    path = path.rstrip('/')
    if host == 'github.com':
        return ('github.com', port, path.lstrip('/').lower())
    if scheme == 'ssh' and (path == '~' or path.startswith('~/')):
        path = path[2:]  # the home the path starts in, as path alone does
    home = scheme == 'ssh' and not path.startswith(('/', '~'))
    return (scheme, user if home else '', host, port, path)


def remote_exclusion(root, remote):
    """The remote-tracking refs whose commits the repository pushed to
    already has. Tracking refs record what a remote's fetch address held,
    so a remote counts only where it fetches from: a push by a remote's
    name goes to its push addresses (a pushurl, or its url), and a push to
    a URL to that address, however it is written (repository_address).
    Every remote that fetches from all of them is left out; with none,
    nothing is, as a remote that only pushes there, or one that fetches
    elsewhere, may never have reached it."""
    names = git(root, 'remote', check=False).split()

    def addresses(name, *push):
        found = set()
        for url in git(root, 'remote', 'get-url', *push, '--all', name,
                       check=False).splitlines():
            if url.strip():
                found.add(repository_address(root, url))
        return found

    if remote in names:
        wanted = addresses(remote, '--push')
    else:
        wanted = {repository_address(root, remote)}
    if not wanted:
        return []
    return [f'--remotes={name}' for name in names if wanted <= addresses(name)]


def outgoing(checker, root, tally):
    """What the next commit and push could publish: commits no remote has
    yet, the branch's name, changes not yet committed and files git does
    not track yet."""
    findings = []
    if has_commits(root):
        findings += commits(checker, root, ['HEAD', '--not', '--remotes'], tally)
        branch = git(root, 'symbolic-ref', '--quiet', '--short', 'HEAD', check=False).strip()
        if branch:
            findings += checker.named(branch, '', 'the current branch')[1]
    return findings + working_changes(checker, root, tally)


ZERO = re.compile(r'^0+$')


def pre_push(checker, root, remote, lines, tally):
    """git's pre-push hook: each line names a local ref and object being
    pushed, and the remote ref and object it replaces. What is published:
    the ref names, the commits the remote does not have yet, and the
    annotated tags among them."""
    sources, known, findings = [], [], []
    for number, line in enumerate(lines, 1):
        words = line.split()
        if len(words) != 4:
            continue
        local_ref, local, remote_ref, remote_sha = words
        if ZERO.match(local):
            continue  # a deletion publishes nothing
        for name in dict.fromkeys((local_ref, remote_ref)):
            findings += checker.named(name, '', f'the names in pushed line {number}')[1]
        if not git_succeeds(root, 'cat-file', '-e', local + '^{commit}'):
            # Its files would be published unread.
            raise SetupError('A push of a tree or a blob, or of a tag of one, is refused: the '
                             'check reads only commits and what they change.')
        sources.append(local)
        if not ZERO.match(remote_sha) and git_succeeds(root, 'cat-file', '-e',
                                                        remote_sha + '^{commit}'):
            known.append('^' + remote_sha)
    if sources:
        findings += commits(checker, root, [*sources, *known, '--not',
                                            *remote_exclusion(root, remote)], tally)
        findings += tags(checker, root, sources)
    return findings


def ci_revisions(root):
    """The commits a CI run brings: those not yet on main (a pull request,
    a branch), or, on main, what the newest merge brought in."""
    if git(root, 'rev-parse', '--is-shallow-repository').strip() == 'true':
        raise SetupError('This clone is shallow, so the commits being merged cannot be '
                         'read. Check out the whole history (actions/checkout with '
                         'fetch-depth: 0).')
    # The remote's branch by its full name: a tag named origin/main would
    # come first.
    main = 'refs/remotes/origin/main'
    if git_succeeds(root, 'rev-parse', '--verify', '--quiet', main + '^{commit}') and \
            not git_succeeds(root, 'merge-base', '--is-ancestor', 'HEAD', main):
        return [main + '..HEAD']
    parents = git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').split()
    # HEAD^! is HEAD alone: with -1, git log --merges would pick the newest
    # older merge instead.
    return ['HEAD^1..HEAD'] if len(parents) > 2 else ['HEAD^!']


def ci_event(environ):
    try:
        with open(environ['GITHUB_EVENT_PATH'], encoding='utf-8') as file:
            event = json.load(file)
    except (KeyError, OSError, ValueError):
        raise SetupError('The GitHub event could not be read.')
    if not isinstance(event, dict):
        raise SetupError('The GitHub event could not be read.')
    return event


def ci_gets_secrets(environ):
    """Whether GitHub gives this run the repository's secrets: not to a
    run Dependabot started, and not to a pull request from a fork."""
    if environ.get('GITHUB_ACTOR') == 'dependabot[bot]':
        return False
    if not environ.get('GITHUB_EVENT_NAME', '').startswith('pull_request'):
        return True
    try:
        head = ci_event(environ)['pull_request']['head']['repo']['full_name']
    except (KeyError, TypeError):
        raise SetupError('The GitHub event could not be read, so whether this run '
                         'has the private list is unknown.')
    return head == environ.get('GITHUB_REPOSITORY')


def ci_texts(environ):
    """A pull request's title, description and branch name, or the ref a
    push updated."""
    if not environ.get('GITHUB_EVENT_PATH'):
        return []
    event = ci_event(environ)
    request = event.get('pull_request') if isinstance(event.get('pull_request'), dict) else {}
    head = request.get('head') if isinstance(request.get('head'), dict) else {}
    texts = [('the pull request title', request.get('title')),
             ('the pull request description', request.get('body')),
             ('the pull request branch name', head.get('ref')),
             ('the pushed ref', event.get('ref'))]
    return [(label, text) for label, text in texts if isinstance(text, str) and text]


def hooks_path_set(root):
    """Whether core.hooksPath names this checkout's .githooks. Git reads
    it from the checkout, not from the branch a push names."""
    # Read the setting itself: git() turns hooks off for its own calls.
    try:
        found = subprocess.run(['git', '-C', str(root), 'config', '--get', 'core.hooksPath'],
                               capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return False
    setting = found.stdout.strip() if found.returncode == 0 else ''
    if not setting:
        return False
    folder = Path(os.path.expanduser(setting))
    folder = folder if folder.is_absolute() else Path(root, folder)
    try:
        return folder.resolve() == Path(root, HOOKS).resolve()
    except OSError:
        return False


def hook_on(root):
    """Whether this checkout's pushes run .githooks/pre-push."""
    return hooks_path_set(root) and os.access(Path(root, HOOKS, 'pre-push'), os.X_OK)


# ---------------------------------------------------------------- guard

NO_LIST = ('No private list is set up here, so private words were NOT checked and '
           'nothing may be published until the owner sets one up (' + DECISION + '). '
           'Never describe a check without the list as passing.')


# A run of base64 in text a command or a tool publishes, its line breaks
# written as JSON writes them (\\n, \\r) or as they are (a lone \\r
# among them, which \\u000d gives), and a JSON body's \\/ for /: at
# least twelve letters, so a file of eight bytes or fewer is not read.
ENCODED_RUN = re.compile(r'(?:[A-Za-z0-9+]|\\?/|\\[nr]|\r\n?|\n){12,}=*')


def encoded_findings(checker, text, where):
    """Findings in the bytes a published text carries as base64. GitHub's
    API takes a file's content that way (the Contents API's content, a
    Git blob in base64, the contents of GraphQL's createCommitOnBranch),
    so what goes public there is the decoded file, which no pre-push hook
    reads. A run that is not base64 decodes to bytes that hold nothing."""
    findings = []
    for number, run in enumerate(ENCODED_RUN.finditer(text), 1):
        letters = re.sub(r'\\[nr]|\\|\s', '', run.group()).rstrip('=')
        if len(letters) % 4 == 1:
            letters = letters[:-1]
        try:
            data = base64.b64decode(letters + '=' * (-len(letters) % 4))
        except (binascii.Error, ValueError):
            continue
        findings += checker.data(data, f'{where} (encoded text {number})')
    return findings


def guard_findings(texts=(), files=(), commits_from=(), directory=None, environ=None,
                   seconds=None):
    """For .claude/hooks/guard.py: findings in what a command or a tool
    would publish. texts are (label, text) pairs (a message, a pull
    request's body, a comment), where text may be a tuple of one text's
    readings, each place in which is reported once (merged); files are (path, text) pairs about to be
    written to GitHub, from the checkout at directory; commits_from are
    (directory, paths a git add in the same command names) for a commit,
    whose message is among texts. Pushes are left to .githooks/pre-push."""
    entries = load_list(environ)[0]
    if not entries:
        raise SetupError(NO_LIST)
    tally = Tally(None if seconds is None else time.monotonic() + seconds)
    findings = []
    plain = Checker(entries)
    for label, text in texts:
        def read(reading, label=label):
            # JSON may write any letter of the base64 as a \uXXXX escape;
            # what GitHub decodes is the run with each escape undone.
            unescaped = UNICODE_ESCAPE.sub(lambda match: chr(int(match[1], 16)), reading)
            return plain.text(reading, label) + encoded_findings(plain, unescaped, label)
        findings += merged(read, [(reading,) for reading in
                                  ((text,) if isinstance(text, str) else text)])
    if files:
        support = set()
        if directory is not None:
            try:
                support = support_addresses(top_level(directory))[0]
            except SetupError:
                pass  # not a checkout: the support address is not allowed
        checker = Checker(entries, support)
        for number, (path, text) in enumerate(files, 1):
            where, found = checker.named(path, path, f'file {number} the tool writes', path)
            findings += found + checker.text(text, where, path)
    for folder, pathspecs in commits_from:
        root = top_level(folder)
        support, problems = support_addresses(root)
        checker = Checker(entries, support)
        findings += problems + staged(checker, root, tally)
        if pathspecs:
            findings += pending(checker, root, folder, pathspecs, tally)
    return findings


def advice(findings):
    """How to fix each kind found, and the rule that comes with all of them."""
    lines = []
    for kind in dict.fromkeys(finding.kind.replace(IN_NAME, '') for finding in findings):
        if kind in FIXES:
            lines.append(FIXES[kind])
    if any(MADE_COMMIT.search(finding.where) for finding in findings):
        lines.append(COMMIT_FIX)
    elif any(finding.where.startswith('the commit ') for finding in findings):
        lines.append(REFUSED_COMMIT_FIX)
    return ' '.join(lines + [NEVER_REPEAT])


# ----------------------------------------------------------------- CLI

def kinds(findings):
    counts = {}
    for finding in findings:
        counts[finding.kind] = counts.get(finding.kind, 0) + 1
    return '; '.join(f'{count} × {kind}' for kind, count in sorted(counts.items()))


def status(root, entries, counts, no_list=False):
    """The list's sources and counts, how many places in tracked files
    each entry matches (an entry that matches many is already published
    or an ordinary word), and whether pushes run the hook. Without a list
    (unless --no-list said so), that is said last."""
    for label, count in counts:
        print(f'{counted(count, "entry", "entries")} from {label}.')
    places, checker = {}, Checker(entries)
    if entries:
        for path in git(root, 'ls-files', '-z').split('\0'):
            full = Path(root, path)
            if not path or not full.is_file() or full.is_symlink():
                continue
            data = full.read_bytes()
            texts = file_texts(data)
            if texts is None:
                hidden = binary_texts(data)
                texts = hidden.exact + hidden.runs
            else:
                texts = texts[:1]  # one reading of a text file: no place counted twice
            for _, entry in checker.entry_places(path + '\n' + '\n'.join(texts)):
                places[entry] = places.get(entry, 0) + 1
    for entry in entries:
        if places.get(entry):
            print(f'Entry {entry.number} of {entry.source} matches {counted(places[entry], "place")} in '
                  'tracked files: if they are already published or an ordinary word, make '
                  'the entry longer (a full name), or start it with = to match its case.')
    if hook_on(root):
        print('Pushes from this checkout run the privacy hook.')
    elif hooks_path_set(root):
        # Set the right way, on a branch made before the hook reached main.
        print('Pushes from this checkout do NOT run the privacy hook: the branch checked out '
              f'here has no {HOOKS}/pre-push, and git runs the one in the checkout, whichever '
              'branch a push names, so merge origin/main into this branch (a merge commit).')
    else:
        print('Pushes from this checkout do NOT run the privacy hook. Turn it on with: '
              f'git config core.hooksPath {HOOKS}')
    if not counts and not no_list:
        print('No private list was found here, so nothing can be checked or pushed: set one '
              f'up ({DECISION}).')


def run(options, environ, stdin):
    root = top_level(options.root or ROOT)
    entries, counts, warnings = ([], [], []) if options.no_list else load_list(environ)
    for warning in warnings:
        print(f'privacy check: {warning}', file=sys.stderr)
    if options.status:
        status(root, entries, counts, options.no_list)
        return [], Tally(), entries
    if options.ci and not options.no_list and not entries:
        if ci_gets_secrets(environ):
            raise SetupError('No private list was given to this run. Add the '
                             f'repository secret {LIST_VARIABLE} ({DECISION}).')
        print('::warning::GitHub gives this run no secrets (a fork or Dependabot), '
              'so only the built-in patterns ran.')
    elif not options.no_list and not entries and options.pre_push is not None:
        # A hook takes no options, and a push must never skip it: the only
        # way through is the list.
        raise SetupError(NO_LIST + ' To push, the owner sets up the list as that section '
                         'says: the file on a Mac, or the variable ' + LIST_VARIABLE + ' in a '
                         'cloud session. Never skip this hook (--no-verify).')
    elif not options.no_list and not entries:
        raise SetupError(NO_LIST + ' Pass --no-list to check the built-in patterns alone.')
    support, findings = support_addresses(root)
    checker = Checker(entries, support)
    tally = Tally()
    if options.pre_push is not None:
        findings += pre_push(checker, root, options.pre_push, stdin.read().splitlines(), tally)
    elif options.outgoing:
        findings += outgoing(checker, root, tally)
    elif not options.text or options.commits or options.history or options.ci:
        findings += tracked_files(checker, root, tally)
        tally.pictures = 0  # every tracked picture: not worth a reminder
    revisions = [[r] for r in options.commits]
    if options.ci:
        revisions.append(ci_revisions(root))
        for label, text in ci_texts(environ):
            findings += checker.text(text, label)
    if options.history:
        revisions.append(['--all'])
    for revision in revisions:
        findings += commits(checker, root, revision, tally)
    for number, name in enumerate(options.text, 1):
        if name == '-':
            findings += checker.text(stdin.read(), 'the draft')
            continue
        # A draft's file name is checked too, and never shown when it holds
        # a finding: the draft is then named by its number.
        where, found = checker.named(name, f'draft {name}', f'draft {number}')
        findings += found
        findings += checker.text(Path(name).read_text(encoding='utf-8'), where)
    return findings, tally, entries


def counted(count, one, many=None):
    return f'{count} {one if count == 1 else many or one + "s"}'


def main(argv=None, environ=None, stdin=None):
    environ = os.environ if environ is None else environ
    parser = argparse.ArgumentParser(description='Look for personal details that must '
                                     'not be published. Prints places and kinds only.')
    parser.add_argument('root', nargs='?', help='the repository (default: this one)')
    parser.add_argument('--status', action='store_true',
                        help='say where the private list came from, how many places each '
                             'entry matches, and whether pushes run the hook')
    parser.add_argument('--outgoing', action='store_true',
                        help='check what the next commit and push would publish')
    parser.add_argument('--pre-push', metavar='REMOTE',
                        help="git's pre-push hook: check the pushes named on stdin")
    parser.add_argument('--commits', action='append', default=[], metavar='RANGE',
                        help='also check the commits of a revision range')
    parser.add_argument('--history', action='store_true',
                        help='also check every commit on every branch (an audit)')
    parser.add_argument('--text', action='append', default=[], metavar='FILE',
                        help='check a draft: a file, or - for stdin')
    parser.add_argument('--ci', action='store_true',
                        help='GitHub Actions: every file, the commits being merged and the '
                             'pull request; prints counts only')
    parser.add_argument('--no-list', action='store_true',
                        help='run the built-in patterns alone, with no private list')
    options = parser.parse_args(argv)
    stdin = sys.stdin if stdin is None else stdin
    try:
        findings, tally, entries = run(options, environ, stdin)
    except SetupError as error:
        print(f'{"::error::" if options.ci else ""}privacy check: {error}', file=sys.stderr)
        return 2
    except (OSError, UnicodeError) as error:
        print(f'{"::error::" if options.ci else ""}privacy check: could not read a file '
              f'({type(error).__name__}).', file=sys.stderr)
        return 2
    except Exception as error:  # noqa: BLE001 - CI logs are public: no traceback
        if not options.ci:
            raise
        print(f'::error::privacy check failed ({type(error).__name__}).', file=sys.stderr)
        return 2
    if options.status:
        return 0 if entries or options.no_list else 2
    checked = []
    if tally.files:
        checked.append(counted(tally.files, 'file'))
    if tally.changes:
        checked.append(counted(tally.changes, 'changed file'))
    if tally.commits:
        checked.append(counted(tally.commits, 'commit'))
    if options.text:
        checked.append('the draft' if options.text == ['-'] else counted(len(options.text), 'draft'))
    what = (', '.join(checked[:-1]) + ' and ' + checked[-1] if len(checked) > 1
            else checked[0] if checked else 'nothing new')
    lists = (counted(len(entries), 'private entry', 'private entries') if entries
             else 'no private list')
    if findings and options.ci:
        # A public log: counts only, never where. Find them on a computer
        # that has the list.
        print(f'::error::Found {kinds(findings)} in {what} ({lists} and the built-in '
              'patterns). This log is public, so where is not shown: run python3 '
              'scripts/privacy-check.py --commits origin/main..HEAD on a computer that has '
              f'the private list. Do not merge ({DECISION}).')
        return 1
    if findings:
        for finding in findings:
            print(finding)
        count = len(findings)
        print(f'Found {count} personal detail{"" if count == 1 else "s"} while checking '
              f'{what} ({lists} and the built-in patterns). {advice(findings)}')
        return 1
    note = ''
    if tally.pictures:
        note = (f' {counted(tally.pictures, "picture or video", "pictures or videos")} '
                'read for hidden details only: '
                'look at what each one shows before it is pushed.')
    print(f'No personal details found in {what} ({lists} and the built-in patterns).{note}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
