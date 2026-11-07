#!/usr/bin/env python3
"""Keep personal and family details out of this public repository.

Everything committed here, every commit message, branch name and pull
request is public, and pushed commits stay public even after a branch is
deleted. The people Brickson is built for have families whose names,
words and medical details must never be published by accident
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
pictures and other binary files. It never prints what it found, or a
name that holds it, only where and what kind. Without a private list it
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
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import time
import unicodedata
from urllib.parse import unquote as percent_decoded
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
    between semicolons. A line starting with # is a note. An entry
    starting with = must match its case. Errors name the entry's number,
    never its words."""
    entries = []
    for raw in text.splitlines():
        line = unicodedata.normalize('NFC', raw).strip()
        if not line or line.startswith('#'):
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
    try:
        inside = subprocess.run(['git', '-C', folder, 'rev-parse', '--is-inside-work-tree'],
                                capture_output=True, text=True, timeout=10)
        if inside.returncode or inside.stdout.strip() != 'true':
            return False
        ignored = subprocess.run(['git', '-C', folder, 'check-ignore', '-q', path.name],
                                 capture_output=True, timeout=10)
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

EMAIL = re.compile(
    r'(?<![\w.%+-])[A-Za-z0-9][A-Za-z0-9._%+-]*@'
    r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}(?![\w-])')
# Inside a binary file, random bytes can look like a short mixed-case
# address; an address written into a file's metadata is lower case.
BINARY_EMAIL = re.compile(
    r'(?<![\w.%+-])[a-z0-9][a-z0-9._%+-]+@'
    r'(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?![\w-])')
EXAMPLE_DOMAINS = ('example.com', 'example.org', 'example.net')
RESERVED_SUFFIXES = ('.example', '.test', '.invalid', '.localhost')
# The agents that write here sign their commits with these service
# addresses; none of them is a person's.
SERVICE_ADDRESSES = {'noreply@anthropic.com', 'codex@openai.com'}
# GitHub's own addresses (support, noreply, git@ for remotes) and the
# private addresses it gives its users.
SERVICE_DOMAINS = ('github.com',)
# icon@2x.png names an image's scale, not an address.
IMAGE_SCALE = re.compile(r'\d+(?:\.\d+)?x\.(?:png|jpe?g|pdf|svg|gif|heic|webp)')

# North American numbers written with separators or brackets, and
# international numbers written with a leading +. Digits alone, versions,
# dates (also +2026-11-06) and build numbers are not phone numbers.
PHONE = re.compile(
    r'(?<![\w+.-])(?:\+?1[ .-]?)?(?:\(\d{3}\)[ .-]?|\d{3}[ .-])\d{3}[ .-]\d{4}(?![\w.-]|-\d)'
    r'|(?<![\w+])\+(?!\d{4}-\d\d-\d\d(?!\d))[1-9](?:[ .()-]{0,2}\d){7,14}(?![\w-])')

HOME = re.compile(
    r'(?:(?<![\w.~/-])|(?<=file://))'
    r'(?:/Users/|/home/|[A-Za-z]:[\\/]{1,2}Users[\\/]{1,2})([A-Za-z0-9][A-Za-z0-9._-]*)')
# Names that stand for "your name" or a machine's own account.
HOME_PLACEHOLDERS = {'runner', 'shared', 'user', 'username', 'you', 'yourname',
                     'your-name', 'your_name', 'name', 'me', 'example', 'guest'}

# An apostrophe that continues a word (Don't, they're), unlike a
# possessive, which ends the name before it.
CONTRACTION = re.compile(r"['’](?:t|re|ll|ve|d|m)(?![^\W\d_])", re.IGNORECASE)
# A line worth reading a second time with its escapes undone and its
# accents and invisible characters removed.
FOLDABLE = re.compile(r'[^\x00-\x7f]|[&%\\]')
UNICODE_ESCAPE = re.compile(r'\\u([0-9a-fA-F]{4})')


def email_allowed(address, path, support, identity=False):
    address = address.lower()
    domain = address.rpartition('@')[2]
    if (domain in EXAMPLE_DOMAINS or domain.endswith(RESERVED_SUFFIXES)
            or address in SERVICE_ADDRESSES or IMAGE_SCALE.fullmatch(domain)
            or any(domain == d or domain.endswith('.' + d) for d in SERVICE_DOMAINS)):
        return True
    if address in support:
        # The published support address: on the website's own pages, and as
        # the address the owner's own commits are signed with.
        return identity or (path is not None and path.startswith('site/'))
    return False


def phone_allowed(number):
    digits = re.sub(r'\D', '', number)
    if len(digits) == 11 and digits.startswith('1'):
        digits = digits[1:]
    # Numbers kept for fiction and examples: area code 555, and 555-01xx.
    return len(digits) == 10 and (digits[:3] == '555'
                                  or (digits[3:6] == '555' and digits[6:8] == '01'))


def same_class(a, b):
    return (a.isalpha() and b.isalpha()) or (a.isdigit() and b.isdigit())


def starts_word(text, index):
    if index == 0 or not same_class(text[index - 1], text[index]):
        return True
    return text[index - 1].islower() and text[index].isupper()  # camelCase


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


def folded(text):
    """Text with HTML entities, percent escapes, \\/ and \\uXXXX undone,
    compatibility forms (full-width letters) made plain, and accents and
    invisible characters (zero-width spaces, soft hyphens) removed."""
    text = percent_decoded(html.unescape(text), errors='replace').replace('\\/', '/')
    text = UNICODE_ESCAPE.sub(lambda match: chr(int(match[1], 16)), text)
    text = unicodedata.normalize('NFKD', text)
    return ''.join(char for char in text
                   if unicodedata.category(char) not in ('Mn', 'Cf', 'Cs'))


def entry_pattern(tokens, exact):
    # Words may be joined by spaces, line breaks, punctuation or nothing
    # (camelCase); a plural s or es may follow.
    body = r'[\W_]*'.join(re.escape(token) for token in tokens) + r'(?:es|s)?'
    return re.compile(body, 0 if exact else re.IGNORECASE)


def line_starts(lines):
    starts = [0]
    for line in lines[:-1]:
        starts.append(starts[-1] + len(line) + 1)
    return starts


class Checker:
    """Finds personal details in text. Holds the private list and the
    website's support address; reports places and kinds, never words."""

    def __init__(self, entries=(), support=frozenset()):
        self.entries = list(entries)
        self.support = {address.lower() for address in support}
        self.patterns = [(entry, entry_pattern(entry.tokens, entry.exact))
                         for entry in self.entries]
        self.folded_patterns = [
            (entry, entry_pattern(tuple(folded(token) for token in entry.tokens), entry.exact))
            for entry in self.entries]

    @staticmethod
    def matches(text, patterns):
        """(offset, entry) for each whole-word match of a list entry."""
        for entry, pattern in patterns:
            position = 0
            while True:
                match = pattern.search(text, position)
                if match is None:
                    break
                if starts_word(text, match.start()) and ends_word(text, match.end()):
                    yield match.start(), entry
                    position = match.end()
                else:
                    position = match.start() + 1

    def scan(self, text, path, binary, patterns, phones=True):
        """(offset, kind) for everything found in text."""
        for offset, _ in self.matches(text, patterns):
            yield offset, KIND_PRIVATE
        for match in (BINARY_EMAIL if binary else EMAIL).finditer(text):
            if not email_allowed(match.group(), path, self.support):
                yield match.start(), KIND_EMAIL
        for match in HOME.finditer(text):
            if match.group(1).lower() not in HOME_PLACEHOLDERS:
                yield match.start(), KIND_HOME
        if phones and not binary:
            for match in PHONE.finditer(text):
                if not phone_allowed(match.group()):
                    yield match.start(), KIND_PHONE

    def text(self, text, where, path=None, start_line=1, binary=False, flat=False):
        """Findings in one text. path, relative to the repository, is where
        the text will live; text without one (a message, a draft, a name)
        has no allowances. Text with no lines of its own (a binary file's
        hidden text, a name) is flat: each kind is reported once, at line 0."""
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

        for offset, kind in self.scan(text, path, binary, self.patterns):
            add(offset, kind)
        if FOLDABLE.search(text):
            # The same lines with escapes undone; each keeps its line, so a
            # finding here is reported on the line it was written on.
            plain = [folded(line).replace('\n', ' ').replace('\r', ' ')
                     if FOLDABLE.search(line) else line for line in lines]
            if plain != lines:
                plain_starts = line_starts(plain)
                for offset, kind in self.scan('\n'.join(plain), path, binary,
                                              self.folded_patterns, phones=False):
                    number = bisect.bisect_right(plain_starts, offset) - 1
                    column = min(offset - plain_starts[number], len(lines[number]))
                    add(starts[number] + column, kind, refound=True)
        return sorted(found.values(), key=lambda f: (f.line, f.column, f.kind))

    def name_kinds(self, name, path=None):
        """The kinds found in a name: a file's, a branch's or a tag's."""
        return [finding.kind + IN_NAME for finding in self.text(name, '', path, flat=True)]

    def identity(self, name, address, where):
        """A commit's author, committer or tagger: the name and the address."""
        findings = []
        if any(True for _ in self.matches(name + '\n' + address, self.patterns)):
            findings.append(Finding(where, 0, 0, KIND_PRIVATE))
        if EMAIL.fullmatch(address or '') and not email_allowed(address, None, self.support,
                                                                 identity=True):
            findings.append(Finding(where, 0, 0, KIND_EMAIL))
        if HOME.search(address or ''):
            findings.append(Finding(where, 0, 0, KIND_HOME))
        return findings

    def data(self, data, where, path=None):
        """A file's bytes: text if it reads as text; otherwise the text
        hidden in it (a picture's metadata, readable runs) and whether it
        records where it was taken."""
        for bom, codec in ((b'\xef\xbb\xbf', 'utf-8-sig'), (b'\xff\xfe', 'utf-16'),
                           (b'\xfe\xff', 'utf-16')):
            if data.startswith(bom):
                return self.text(data.decode(codec, errors='replace'), where, path)
        if b'\0' not in data[:8000]:
            return self.text(data.decode('utf-8', errors='replace'), where, path)
        texts, located = binary_texts(data)
        findings = self.text('\n'.join(texts), where, path, binary=True)
        if located:
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


# ------------------------------------------------------- binary files

INFLATE_LIMIT = 4 * 1024 * 1024
# Runs of at least eight readable characters, as `strings` finds them: in
# 4 MB of random bytes, shorter runs held a three-letter name a dozen times.
READABLE = re.compile(rb'(?:[\x20-\x7e\t]|[\xc2-\xf4][\x80-\xbf]{1,3}){8,}')
READABLE_UTF16LE = re.compile(rb'(?:[\x20-\x7e]\x00){8,}')
READABLE_UTF16BE = re.compile(rb'(?:\x00[\x20-\x7e]){8,}')
EXIF_HEADER = re.compile(rb'Exif\x00\x00(?=II\*\x00|MM\x00\*)')
XMP_PACKET = re.compile(rb'<x:xmpmeta.*?</x:xmpmeta>', re.DOTALL)
GPS_IN_XMP = re.compile(r'GPS(?:Latitude|Longitude)[^0-9]{0,40}[1-9]')
EXIF_SIZES = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8}


XML_MARKUP = re.compile(r'</?[\w:.-]+|[\w:.-]+(?==")|/?>')


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


def inflate(data):
    try:
        return zlib.decompressobj().decompress(data, INFLATE_LIMIT)
    except zlib.error:
        return b''


def exif_texts(tiff, texts):
    """The strings in an Exif (TIFF) block, and whether its GPS part holds
    a latitude or longitude."""
    if len(tiff) < 8 or tiff[:2] not in (b'II', b'MM'):
        return False
    order = '<' if tiff[:2] == b'II' else '>'
    located = False
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
                located = located or any(value[i:i + 4] != b'\0\0\0\0'
                                         for i in range(0, len(value) - 3, 8))
            elif kind == 2:
                texts.append(value.replace(b'\0', b'\n').decode('utf-8', 'replace'))
            elif 0x9C9B <= tag <= 0x9C9F:  # Windows' title, comment, author
                texts.append(value.decode('utf-16-le', 'replace'))
            elif kind in (1, 7):  # comments and maker notes
                texts.extend(readable(value))
        next_offset = offset + 2 + 12 * count
        if next_offset + 4 <= len(tiff):
            following = struct.unpack(order + 'I', tiff[next_offset:next_offset + 4])[0]
            if following:
                queue.append((following, gps))
    return located


def png_texts(data, texts):
    located, position = False, 8
    while position + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[position:position + 8])
        body = data[position + 8:position + 8 + length]
        position += 12 + length
        if kind == b'tEXt':
            texts.append(body.replace(b'\0', b'\n').decode('latin-1'))
        elif kind == b'zTXt':
            keyword, _, rest = body.partition(b'\0')
            texts.append(keyword.decode('latin-1') + '\n'
                         + inflate(rest[1:]).decode('latin-1'))
        elif kind == b'iTXt':
            keyword, _, rest = body.partition(b'\0')
            compressed, rest = rest[:1] == b'\x01', rest[2:]
            language, _, rest = rest.partition(b'\0')
            translated, _, text = rest.partition(b'\0')
            text = (inflate(text) if compressed else text).decode('utf-8', 'replace')
            texts.append(b'\n'.join([keyword, language, translated]).decode('utf-8', 'replace')
                         + '\n' + without_markup(text))
        elif kind == b'eXIf':
            located = exif_texts(body, texts) or located
        elif kind == b'iCCP':
            texts.extend(readable(inflate(body.partition(b'\0')[2][1:])))
        elif kind == b'IEND':
            break
        elif kind not in (b'IDAT', b'fdAT') and kind[:1].islower():
            texts.extend(readable(body))  # other ancillary chunks
    texts.extend(readable(data[position:]))  # anything after the image
    return located


def jpeg_texts(data, texts):
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
            texts.append(body.decode('utf-8', 'replace'))
        elif 0xE0 <= marker <= 0xEF and not body.startswith(b'Exif\0\0'):
            texts.extend(readable(body))  # XMP, IPTC, ICC and others
        position += 2 + length
    return False


def iso_media_texts(data, texts):
    """HEIC, AVIF, MP4 and QuickTime: every box but the media data."""
    located, position = False, 0
    while position + 8 <= len(data):
        size, kind = struct.unpack('>I4s', data[position:position + 8])
        header = 8
        if size == 1 and position + 16 <= len(data):
            size, header = struct.unpack('>Q', data[position + 8:position + 16])[0], 16
        elif size == 0:
            size = len(data) - position
        if size < header:
            break
        if kind not in (b'mdat', b'free', b'skip', b'wide'):
            body = data[position + header:position + size]
            located = located or b'\xa9xyz' in body or b'location.ISO6709' in body
            texts.extend(readable(body))
        position += size
    return located


def riff_texts(data, texts):
    """WAV, WebP and AVI: every chunk but the sound or picture itself."""
    located, position = False, 12
    while position + 8 <= len(data):
        kind, size = struct.unpack('<4sI', data[position:position + 8])
        body = data[position + 8:position + 8 + size]
        position += 8 + size + (size & 1)
        if kind == b'LIST' and body[:4] in (b'INFO', b'adtl', b'hdrl'):
            texts.extend(readable(body[4:]))
        elif kind == b'EXIF':
            located = exif_texts(body[6:] if body.startswith(b'Exif') else body,
                                 texts) or located
        elif kind not in (b'data', b'LIST', b'VP8 ', b'VP8L', b'VP8X', b'ALPH', b'ANMF',
                          b'ANIM', b'idx1', b'fmt '):
            texts.extend(readable(body))
    return located


def pdf_texts(data, texts):
    texts.extend(readable(data))
    for stream in re.finditer(rb'stream\r?\n(.*?)\r?\nendstream', data, re.DOTALL):
        texts.extend(readable(inflate(stream.group(1))))
    return False


def binary_texts(data):
    """(texts, located): the text a binary file carries where people do
    not see it, and whether it records where a photo or video was taken.
    A picture's pixels are not read: look at what a picture shows."""
    texts = []
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        located = png_texts(data, texts)
    elif data.startswith(b'\xff\xd8'):
        located = jpeg_texts(data, texts)
    elif data[:4] in (b'II*\0', b'MM\0*'):
        located = exif_texts(data, texts)
    elif data[4:8] in (b'ftyp', b'moov', b'wide', b'mdat', b'free', b'skip'):
        located = iso_media_texts(data, texts)
    elif data[:4] == b'RIFF':
        located = riff_texts(data, texts)
    elif data[:5] == b'%PDF-':
        located = pdf_texts(data, texts)
    elif data[:4] == b'GIF8' or data[:2] == b'BM':
        located = False  # nothing beyond the blocks searched below
    else:
        texts.extend(readable(data))
        located = False
    # Exif and XMP blocks wherever they are: inside a HEIC's items, a
    # JPEG's second picture or a video's metadata.
    for header in EXIF_HEADER.finditer(data):
        located = exif_texts(data[header.end():header.end() + 1024 * 1024], texts) or located
    for packet in XMP_PACKET.finditer(data):
        xmp = packet.group().decode('utf-8', 'replace')
        texts.append(without_markup(xmp))
        located = located or bool(GPS_IN_XMP.search(xmp))
    return texts, located


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


def git(root, *args, binary=False, check=True):
    # No hooks, no file-system monitor and no external diff or textconv
    # program runs: the repository's own settings never run code here.
    try:
        result = subprocess.run(
            ['git', '-C', str(root), '-c', 'core.quotePath=false', '-c', 'core.fsmonitor=false',
             '-c', 'core.hooksPath=/dev/null', *args],
            capture_output=True, timeout=300)
    except (OSError, subprocess.SubprocessError) as error:
        raise SetupError(f'git could not run ({type(error).__name__}).')
    if check and result.returncode:
        message = result.stderr.decode('utf-8', 'replace').strip().splitlines()
        raise SetupError('git ' + args[0] + ' failed: ' + (message[-1] if message else 'no message'))
    return result.stdout if binary else result.stdout.decode('utf-8', 'replace')


def git_succeeds(root, *args):
    try:
        return subprocess.run(['git', '-C', str(root), *args], capture_output=True,
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
        if path and Path(root, path).is_file():
            tally.pictures += path.lower().endswith(PICTURES)
            findings += read_file(checker, root, path, f'untracked file {number} of git '
                                  'ls-files --others --exclude-standard', tally)
    return findings


def unquote(path):
    if path.startswith('"') and path.endswith('"'):
        return (path[1:-1].encode('latin-1', 'backslashreplace')
                .decode('unicode_escape').encode('latin-1').decode('utf-8', 'replace'))
    return path


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


HUNK = re.compile(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@')
BINARY = re.compile(r'^Binary files (?:"?a/.*?"?|/dev/null) and ("?b/.*?"?) differ$')


def patch_changes(patch):
    """(runs, binaries, names) in a patch: (path, first line, text) for
    each run of added lines, the paths of binary files it adds or changes,
    and every path it adds or changes. A run is read as one text, so a
    phrase wrapped over two lines is still found."""
    runs, binaries, names = [], [], []
    path, line, block, block_start, header = None, 0, [], 0, False

    def flush():
        if path is not None and block:
            runs.append((path, block_start, '\n'.join(block)))
        block.clear()

    for raw in patch.split('\n'):
        if raw.startswith('diff --git '):
            flush()
            header = True
            path = header_path(raw[len('diff --git '):])
            if path is not None:
                names.append(path)
        elif header and raw.startswith('deleted file mode'):
            if path in names:
                names.remove(path)
            path = None
        elif header and raw.startswith('+++ '):
            target = unquote(raw[4:])
            path = target[2:] if target.startswith('b/') else None
        elif header and BINARY.match(raw):
            binaries.append(unquote(BINARY.match(raw).group(1))[2:])
        elif raw.startswith('@@'):
            flush()
            header = False
            hunk = HUNK.match(raw)
            line = block_start = int(hunk.group(1)) if hunk else 0
        elif not header and raw.startswith('+'):
            if not block:
                block_start = line
            block.append(raw[1:])
            line += 1
        elif not header:
            flush()
    flush()
    return runs, binaries, names


PATCH_OPTIONS = ('-p', '--unified=0', '--no-color', '--no-ext-diff', '--no-textconv',
                 '--no-renames', '--src-prefix=a/', '--dst-prefix=b/')


def read_patch(checker, patch, label, blob, tally):
    """Findings in a patch's added lines, its binary files (read through
    blob(path)) and its paths."""
    findings, places = [], {}
    runs, binaries, names = patch_changes(patch)
    for number, path in enumerate(dict.fromkeys(names), 1):
        tally.tick()
        tally.changes += 1
        tally.pictures += path.lower().endswith(PICTURES)
        where, found = checker.named(path, path + label, f'changed file {number}{label}', path)
        places[path] = where
        findings += found
    for path, line, text in runs:
        findings += checker.text(text, places.get(path, path + label), path, line)
    for path in binaries:
        tally.tick()
        findings += checker.data(blob(path), places.get(path, path + label), path)
    return findings


def merge_patches(root, revisions):
    """What merge commits add beyond merging cleanly: a conflict's
    resolution, or a change made while merging. Git before 2.36 cannot
    say, so there a merge is read against its first parent."""
    if not git(root, 'rev-list', '--merges', '-n', '1', *revisions, '--').strip():
        return ''
    for option in ('--remerge-diff', '--diff-merges=first-parent'):
        try:
            return git(root, 'log', '--merges', '--format=%x01%H', option, *PATCH_OPTIONS,
                       *revisions, '--')
        except SetupError:
            continue
    raise SetupError('git could not show what the merge commits change.')


def commits(checker, root, revisions, tally):
    """The commits in a revision range: their messages, authors and
    committers, and the lines, files and names their changes add."""
    findings = []
    log = git(root, 'log', '-z', '--format=%H%n%an%n%ae%n%cn%n%ce%n%B', *revisions, '--')
    for record in log.split('\0'):
        fields = record.split('\n', 5)
        if len(fields) < 6 or not fields[0].strip():
            continue
        sha = fields[0].strip()[:12]
        tally.tick()
        tally.commits += 1
        findings += checker.identity(fields[1], fields[2], f'commit {sha} author')
        findings += checker.identity(fields[3], fields[4], f'commit {sha} committer')
        findings += checker.text(fields[5], f'commit {sha} message')
    patches = git(root, 'log', '--no-merges', '--format=%x01%H', *PATCH_OPTIONS,
                  *revisions, '--') + merge_patches(root, revisions)
    for chunk in patches.split('\x01')[1:]:
        sha, _, body = chunk.partition('\n')
        findings += read_patch(
            checker, body, f' (commit {sha[:12]})',
            lambda path, sha=sha: git(root, 'cat-file', 'blob', f'{sha}:{path}', binary=True),
            tally)
    return findings


def tags(checker, root, objects):
    """Annotated tags among the objects pushed: their tagger and message."""
    findings = []
    for name in objects:
        if git(root, 'cat-file', '-t', name, check=False).strip() != 'tag':
            continue
        header, _, message = git(root, 'cat-file', 'tag', name).partition('\n\n')
        where = f'tag object {git(root, "rev-parse", name).strip()[:12]}'
        tagger = re.search(r'^tagger (.*) <([^>]*)>', header, re.MULTILINE)
        if tagger:
            findings += checker.identity(tagger.group(1), tagger.group(2), where + ' tagger')
        findings += checker.text(message, where + ' message')
    return findings


def staged(checker, root, tally):
    """What the next commit would add: the index, compared with HEAD."""
    blob = lambda path: git(root, 'cat-file', 'blob', ':' + path, binary=True)  # noqa: E731
    if not has_commits(root):
        return [finding for number, path in
                enumerate(git(root, 'ls-files', '-z').split('\0'), 1) if path
                for finding in read_file(checker, root, path, f'staged file {number}',
                                         tally, data=blob(path))]
    return read_patch(checker, git(root, 'diff', '--cached', 'HEAD', *PATCH_OPTIONS, '--'),
                      ' (staged)', blob, tally)


def pending(checker, root, directory, pathspecs, tally):
    """Files a git add in the same command would stage: changed tracked
    files and untracked files under the paths it names, read whole."""
    findings = []
    listing = git(directory, 'ls-files', '-z', '--full-name', '--modified', '--', *pathspecs)
    for number, path in enumerate(listing.split('\0'), 1):
        if path:
            findings += read_file(checker, root, path, f'changed file {number} to be added',
                                  tally)
    return findings + untracked_files(checker, root, tally, pathspecs, directory)


def working_changes(checker, root, tally):
    """Changes not yet committed: tracked files that differ from HEAD,
    staged or not, and files git does not track yet."""
    if not has_commits(root):
        return tracked_files(checker, root, tally) + untracked_files(checker, root, tally)
    findings = read_patch(checker, git(root, 'diff', 'HEAD', *PATCH_OPTIONS, '--'),
                          ' (not committed)', lambda path: Path(root, path).read_bytes()
                          if Path(root, path).is_file() else b'', tally)
    return findings + untracked_files(checker, root, tally)


def remote_exclusion(root, remote):
    """--remotes=<remote> for a named remote; every remote for a URL."""
    names = git(root, 'remote', check=False).split()
    return [f'--remotes={remote}'] if remote in names else ['--remotes']


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
    if git_succeeds(root, 'rev-parse', '--verify', '--quiet', 'origin/main^{commit}') and \
            not git_succeeds(root, 'merge-base', '--is-ancestor', 'HEAD', 'origin/main'):
        return ['origin/main..HEAD']
    parents = git(root, 'rev-list', '--parents', '-n', '1', 'HEAD').split()
    return ['HEAD^1..HEAD'] if len(parents) > 2 else ['-1', 'HEAD']


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


def hook_on(root):
    """Whether this checkout's pushes run .githooks/pre-push."""
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
    hook = Path(root, HOOKS, 'pre-push')
    try:
        return folder.resolve() == Path(root, HOOKS).resolve() and os.access(hook, os.X_OK)
    except OSError:
        return False


# ---------------------------------------------------------------- guard

NO_LIST = ('No private list is set up here, so private words were NOT checked and '
           'nothing may be published until the owner sets one up (' + DECISION + '). '
           'Never describe a check without the list as passing.')


def guard_findings(texts=(), files=(), commits_from=(), directory=None, environ=None,
                   seconds=None):
    """For .claude/hooks/guard.py: findings in what a command or a tool
    would publish. texts are (label, text) pairs (a message, a pull
    request's body, a comment); files are (path, text) pairs about to be
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
        findings += plain.text(text, label)
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
    if any('commit ' in finding.where for finding in findings):
        lines.append(COMMIT_FIX)
    return ' '.join(lines + [NEVER_REPEAT])


# ----------------------------------------------------------------- CLI

def kinds(findings):
    counts = {}
    for finding in findings:
        counts[finding.kind] = counts.get(finding.kind, 0) + 1
    return '; '.join(f'{count} × {kind}' for kind, count in sorted(counts.items()))


def status(root, entries, counts):
    """The list's sources and counts, how many places in tracked files
    each entry matches (an entry that matches many is already published
    or an ordinary word), and whether pushes run the hook."""
    for label, count in counts:
        print(f'{counted(count, "entry", "entries")} from {label}.')
    if not counts:
        print('No private list was found here: checks refuse to run without one unless '
              '--no-list is given.')
    places, patterns = {}, Checker(entries).patterns
    if entries:
        for path in git(root, 'ls-files', '-z').split('\0'):
            full = Path(root, path)
            if not path or not full.is_file() or full.is_symlink():
                continue
            data = full.read_bytes()
            text = '\n'.join(binary_texts(data)[0]) if b'\0' in data[:8000] \
                else data.decode('utf-8', 'replace')
            text = unicodedata.normalize('NFC', path + '\n' + text)
            for _, entry in Checker.matches(text, patterns):
                places[entry] = places.get(entry, 0) + 1
    for entry in entries:
        if places.get(entry):
            print(f'Entry {entry.number} of {entry.source} matches {counted(places[entry], "place")} in '
                  'tracked files: if they are already published or an ordinary word, make '
                  'the entry longer (a full name), or start it with = to match its case.')
    print('Pushes from this checkout run the privacy hook.' if hook_on(root) else
          'Pushes from this checkout do NOT run the privacy hook. Turn it on with: '
          f'git config core.hooksPath {HOOKS}')


def run(options, environ, stdin):
    root = top_level(options.root or ROOT)
    entries, counts, warnings = ([], [], []) if options.no_list else load_list(environ)
    for warning in warnings:
        print(f'privacy check: {warning}', file=sys.stderr)
    if options.status:
        status(root, entries, counts)
        return [], Tally(), entries
    if options.ci and not options.no_list and not entries:
        if ci_gets_secrets(environ):
            raise SetupError('No private list was given to this run. Add the '
                             f'repository secret {LIST_VARIABLE} ({DECISION}).')
        print('::warning::GitHub gives this run no secrets (a fork or Dependabot), '
              'so only the built-in patterns ran.')
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
    for name in options.text:
        text = stdin.read() if name == '-' else Path(name).read_text(encoding='utf-8')
        findings += checker.text(text, 'the draft' if name == '-' else f'draft {name}')
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
        return 0
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
