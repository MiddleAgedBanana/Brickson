#!/usr/bin/env python3
"""Check scripts/privacy-check.py and .githooks/pre-push, and run the
check over the repository.

Run with python3 scripts/test-privacy.py; standard library only.
scripts/test.sh runs it before the unit tests, so CI runs it too. Each
test plants a detail the check must find, or an allowed one it must
leave alone, so loosening a pattern, widening an allowance, skipping a
place a detail can hide or printing what was found fails a test here.
The details planted are made up, and those that look like real ones are
put together from parts, so this file holds none of its own.
"""
import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
SCRIPT = Path(__file__).resolve().with_name('privacy-check.py')
spec = importlib.util.spec_from_file_location('privacy_check', SCRIPT)
privacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(privacy)

ROOT = SCRIPT.parents[1]
HOOK = ROOT / '.githooks' / 'pre-push'
# Variables a git hook or the caller's shell may set would point git, in the
# tests and in the checks they run, at another repository than the one named
# with -C: the caller's own checkout.
for _variable in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                  'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_PREFIX'):
    os.environ.pop(_variable, None)

AT = '@'
# A made-up address at a real mail domain, a made-up number outside the
# ranges kept for fiction, and a made-up home folder.
ADDRESS = 'quill.vass' + AT + 'gmail' + '.com'
PHONE = '(212) ' + '867-' + '0142'
HOME_NAME = 'qvass' + 'mere'
HOME_PATH = '/Us' + 'ers/' + HOME_NAME + '/Documents'
# Made-up names standing in for the private list.
NAME = 'Quillon Vassmere'
NICK = 'Tobble'
# Every piece of the details above: none may ever be printed.
SECRETS = ('Quillon', 'quillon', 'QUILLON', 'Vassmere', 'vassmere', 'Tobble', 'tobble',
           'quill.vass', '867', HOME_NAME)


def entries(text, source='the test list'):
    return privacy.parse_list(text, source)


def kinds(findings):
    return [finding.kind for finding in findings]


def checker(text='', support=()):
    return privacy.Checker(entries(text), support)


def git(repo, *args, env=None, check=True):
    result = subprocess.run(
        ['git', '-C', str(repo), '-c', 'user.name=t', '-c', 'user.email=t' + AT + 'example.com',
         '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', *args],
        capture_output=True, text=True, env=env)
    if check:
        assert result.returncode == 0, result.stderr
    return result.stdout


def repository(folder, name='repo'):
    repo = Path(folder, name)
    repo.mkdir()
    git(repo, 'init', '-q', '-b', 'main')
    (repo / 'README.md').write_text('A clean start.\n')
    git(repo, 'add', 'README.md')
    git(repo, 'commit', '-q', '-m', 'Start')
    return repo


def listed(*words, folder=None):
    """An environment whose only private list is these words: no file on
    this machine is read."""
    return {privacy.LIST_VARIABLE: '\n'.join(words),
            'HOME': folder or tempfile.gettempdir() + '/no-such-home',
            'XDG_CONFIG_HOME': ''}


def run(argv, environ=None, stdin=''):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        status = privacy.main(argv, environ=environ if environ is not None else listed(),
                              stdin=io.StringIO(stdin))
    return status, out.getvalue(), err.getvalue()


# ------------------------------------------------------- binary fixtures

def png_chunk(kind, data):
    return (struct.pack('>I', len(data)) + kind + data
            + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))


def png(*chunks, pixels=b'\0\0\0\0'):
    return (b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
            + b''.join(chunks) + png_chunk(b'IDAT', zlib.compress(pixels))
            + png_chunk(b'IEND', b''))


def ifd(fields, start):
    """A little-endian TIFF directory at offset start, values after it."""
    body, extra = struct.pack('<H', len(fields)), b''
    after = start + 2 + 12 * len(fields) + 4
    for tag, kind, count, value in fields:
        if len(value) <= 4:
            body += struct.pack('<HHI', tag, kind, count) + value.ljust(4, b'\0')
        else:
            body += struct.pack('<HHI', tag, kind, count) + struct.pack('<I', after + len(extra))
            extra += value
    return body + struct.pack('<I', 0) + extra


def tiff(artist=None, latitude=None):
    """An Exif block with an Artist string and a GPS latitude."""
    fields = []
    if artist:
        fields.append((0x013B, 2, len(artist) + 1, artist.encode() + b'\0'))
    if latitude is not None:
        fields.append((0x8825, 4, 1, b'\0\0\0\0'))
    first = ifd(fields, 8)
    if latitude is None:
        return b'II*\0' + struct.pack('<I', 8) + first
    fields[-1] = (0x8825, 4, 1, struct.pack('<I', 8 + len(first)))
    first = ifd(fields, 8)
    gps = ifd([(1, 2, 2, b'N\0'), (2, 5, 3, struct.pack('<6I', latitude, 1, 0, 1, 0, 1))],
              8 + len(first))
    return b'II*\0' + struct.pack('<I', 8) + first + gps


def jpeg_segment(marker, body):
    return b'\xff' + bytes([marker]) + struct.pack('>H', len(body) + 2) + body


def jpeg(*segments):
    return b'\xff\xd8' + b''.join(segments) + b'\xff\xda\x00\x02' + bytes(64) + b'\xff\xd9'


def atom(kind, body):
    return struct.pack('>I', len(body) + 8) + kind + body


# ------------------------------------------------------------------ tests

class ListTests(unittest.TestCase):
    """Reading the private list: changing its format or its sources fails."""

    def test_notes_blank_lines_and_semicolons(self):
        found = entries(f'# a note; not an entry\n\n{NAME}\n  {NICK} ; Third Thing;\n')
        self.assertEqual([entry.tokens for entry in found],
                         [('Quillon', 'Vassmere'), ('Tobble',), ('Third', 'Thing')])
        self.assertEqual([entry.number for entry in found], [1, 2, 3])

    # Reading only a whole line as a note, so that a note written after an
    # entry becomes part of it and the entry stops matching, fails this.
    def test_a_note_after_an_entry_ends_it(self):
        found = entries(f'{NAME} # a note; not an entry\n{NICK}; Third Thing#note\n')
        self.assertEqual([entry.tokens for entry in found],
                         [('Quillon', 'Vassmere'), ('Tobble',), ('Third', 'Thing')])
        self.assertEqual(len(checker(f'{NAME} # a note').text(f'Thanks {NAME}.', 'x')), 1)

    def test_an_entry_starting_with_equals_matches_its_case(self):
        exact = privacy.Checker(entries('=Tobble'))
        self.assertEqual(kinds(exact.text('Tobble came.', 'x')), [privacy.KIND_PRIVATE])
        self.assertEqual(exact.text('tobble came.', 'x'), [])
        self.assertEqual(len(checker('Tobble').text('tobble came.', 'x')), 1)

    def test_an_entry_with_nothing_to_find_stops_the_check_without_its_words(self):
        with self.assertRaises(privacy.SetupError) as raised:
            entries(f'{NAME}\n---\n')
        self.assertIn('entry 2', str(raised.exception))

    def test_the_variable_may_hold_the_list_in_base64(self):
        encoded = base64.b64encode(f'# notes\n{NAME}\n{NICK}\n'.encode()).decode()
        found, counts, _ = privacy.load_list(listed('base64:' + encoded[:10] + '\n'
                                                    + encoded[10:]))
        self.assertEqual(len(found), 2)
        self.assertEqual(counts, [(privacy.LIST_VARIABLE, 2)])
        with self.assertRaises(privacy.SetupError) as raised:
            privacy.load_list(listed('base64:' + NAME))
        self.assertNotIn('Quillon', str(raised.exception))

    def test_the_file_and_the_variable_are_both_read_and_counted(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder, '.config', 'brickson')
            config.mkdir(parents=True)
            (config / 'private-words.txt').write_text(f'{NAME}\n{NICK}\n')
            (config / 'private-words.txt').chmod(0o600)
            found, counts, warnings = privacy.load_list(listed('Third Thing', folder=folder))
            self.assertEqual(len(found), 3)
            self.assertEqual([count for _, count in counts], [1, 2])
            self.assertEqual(warnings, [])
            # The file is named from ~: no output shows the home folder.
            self.assertEqual(counts[1][0], '~/.config/brickson/private-words.txt')

    def test_the_file_lives_outside_every_checkout(self):
        self.assertEqual(privacy.default_list_file({'HOME': '/home/user'}),
                         Path('/home/user/.config/brickson/private-words.txt'))
        self.assertEqual(privacy.default_list_file({'HOME': '/h', 'XDG_CONFIG_HOME': '/x'}),
                         Path('/x/brickson/private-words.txt'))
        # A relative XDG_CONFIG_HOME would put the list in the current folder.
        self.assertEqual(privacy.default_list_file({'HOME': '/h', 'XDG_CONFIG_HOME': 'cfg'}),
                         Path('/h/.config/brickson/private-words.txt'))

    def test_a_missing_file_is_no_list(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(privacy.load_list({'HOME': folder}), ([], [], []))

    def test_a_list_a_checkout_could_commit_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            repo = repository(folder)
            list_file = repo / '.config' / 'brickson' / 'private-words.txt'
            list_file.parent.mkdir(parents=True)
            list_file.write_text(NAME + '\n')
            list_file.chmod(0o600)
            environ = {'HOME': str(repo)}
            with self.assertRaises(privacy.SetupError):
                privacy.load_list(environ)
            (repo / '.gitignore').write_text('.config/\n')
            self.assertEqual(len(privacy.load_list(environ)[0]), 1)

    def test_a_list_others_can_read_is_warned_about_and_not_utf8_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            list_file = Path(folder, '.config', 'brickson', 'private-words.txt')
            list_file.parent.mkdir(parents=True)
            list_file.write_text(NAME + '\n')
            list_file.chmod(0o644)
            warnings = privacy.load_list({'HOME': folder})[2]
            self.assertEqual(len(warnings), 1)
            self.assertIn('chmod 600', warnings[0])
            list_file.write_bytes(b'\xff\xfe\x00bad')
            with self.assertRaises(privacy.SetupError):
                privacy.load_list({'HOME': folder})


class PrivateWordTests(unittest.TestCase):
    """Matching the list: loosening a boundary or a join fails."""

    def test_a_listed_name_is_found_however_it_is_written(self):
        check = checker(f'{NAME}\n{NICK}')
        for text in [NAME, NAME.upper(), 'quillon\nvassmere', 'Quillon-Vassmere',
                     'quillon_vassmere', 'QuillonVassmere', "Quillon Vassmere's",
                     'tobbleVoice', 'TOBBLEVoice', 'TOBBLE_X', 'the Tobbles',
                     'a tobble.', '"Tobble"']:
            with self.subTest(text=text):
                self.assertEqual(kinds(check.text(text, 'x')), [privacy.KIND_PRIVATE])

    def test_a_word_inside_a_longer_word_is_not_a_match(self):
        check = checker(f'{NICK}\n4471')
        for text in ['Tobblesome', 'xtobble', 'atobbles', 'Tobbler', "tobble't", '144712',
                     '44710']:
            with self.subTest(text=text):
                self.assertEqual(check.text(text, 'x'), [])
        self.assertEqual(len(check.text('pin 4471.', 'x')), 1)

    def test_escaped_accented_and_hidden_spellings_are_found_on_their_line(self):
        check = checker(NAME)
        for text in ['&#81;uillon Vassmere', 'Qu&iacute;llon Vassmere', 'Quillon%20Vassmere',
                     'Quillon\\u0020Vassmere', '\\u0051uillon Vassmere', 'Quíllon Vassmere',
                     'Quil\u200blon Vassmere', 'Ｑｕｉｌｌｏｎ Vassmere',
                     'Quil\u00adlon Vass\u00admere']:
            with self.subTest(text=text):
                found = check.text('first line\n' + text, 'x')
                self.assertEqual([(f.line, f.kind) for f in found],
                                 [(2, privacy.KIND_PRIVATE)])

    def test_composed_and_decomposed_letters_match(self):
        check = checker('Zoë Quill')
        self.assertEqual(len(check.text('Zoe\u0308 Quill', 'x')), 1)

    def test_a_name_never_shows_in_a_report(self):
        check = checker(NICK)
        where, found = check.named('docs/tobble-notes.md', 'docs/tobble-notes.md',
                                   'tracked file 3')
        self.assertEqual(where, 'tracked file 3')
        self.assertEqual(kinds(found), [privacy.KIND_PRIVATE + privacy.IN_NAME])
        self.assertEqual(check.named('docs/notes.md', 'docs/notes.md', 'tracked file 3'),
                         ('docs/notes.md', []))

    def test_a_commit_signature_is_read(self):
        check = checker(NAME, support={'help' + AT + 'gmail.com'})
        self.assertEqual(kinds(check.identity(NAME, 'q' + AT + 'example.com', 'c')),
                         [privacy.KIND_PRIVATE])
        self.assertEqual(kinds(check.identity('Someone', ADDRESS, 'c')), [privacy.KIND_EMAIL])
        self.assertEqual(kinds(check.identity('Someone', HOME_NAME + AT + 'Their-Mac.local',
                                              'c')), [privacy.KIND_EMAIL])
        for address in ['help' + AT + 'gmail.com', 'noreply' + AT + 'anthropic.com',
                        '1+x' + AT + 'users.noreply.github.com', 'codex' + AT + 'openai.com']:
            with self.subTest(address=address):
                self.assertEqual(check.identity('Someone', address, 'c'), [])


class PatternTests(unittest.TestCase):
    """The built-in patterns: loosening one or widening an allowance fails."""

    def test_an_email_address_is_found(self):
        for text in [ADDRESS, f'<{ADDRESS}>', f'mailto:{ADDRESS}', ADDRESS.upper(),
                     'Write to quill.vass&#64;gmail' '.com']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_EMAIL])

    def test_examples_and_service_addresses_are_allowed(self):
        for address in ['someone' + AT + 'example.com', 'a' + AT + 'b.example',
                        'x' + AT + 'host.test', 'noreply' + AT + 'anthropic.com',
                        'codex' + AT + 'openai.com', 'git' + AT + 'github.com',
                        'support' + AT + 'github.com', '1+x' + AT + 'users.noreply.github.com',
                        'icon' + AT + '2x.png', 'tile' + AT + '3x.jpg']:
            with self.subTest(address=address):
                self.assertEqual(checker().text(address, 'x'), [])

    def test_the_support_address_is_allowed_only_on_the_website(self):
        check = checker(support={ADDRESS})
        self.assertEqual(check.text(ADDRESS, 'site/index.html', 'site/index.html'), [])
        self.assertEqual(check.text(ADDRESS, 'site/privacy/index.html',
                                    'site/privacy/index.html'), [])
        for where, path in [('README.md', 'README.md'), ('docs/site/x.md', 'docs/site/x.md'),
                            ('a message', None)]:
            with self.subTest(where=where):
                self.assertEqual(kinds(check.text(ADDRESS, where, path)), [privacy.KIND_EMAIL])

    def test_a_second_support_address_is_a_finding(self):
        with tempfile.TemporaryDirectory() as folder:
            page = Path(folder, 'site', 'index.html')
            page.parent.mkdir()
            page.write_text(f'<a href="mailto:{ADDRESS}">x</a>')
            self.assertEqual(privacy.support_addresses(folder), ({ADDRESS}, []))
            page.write_text(f'<a href="mailto:{ADDRESS}">x</a><a href="mailto:b{ADDRESS}">y</a>')
            addresses, problems = privacy.support_addresses(folder)
            self.assertEqual((addresses, kinds(problems)), (set(), [privacy.KIND_SUPPORT]))

    def test_a_phone_number_is_found(self):
        # Split so this file holds no number the checker finds.
        for text in [PHONE, '212-867-' '0142', '212.867.' '0142', '+1 212 867 ' '0142',
                     '+44 20 ' '7946 0142', '+33 1 23 45 ' '67 89', '(212) 555-' '1234']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(f'Call {text} today', 'x')),
                                 [privacy.KIND_PHONE])

    def test_numbers_that_are_not_phone_numbers_are_left_alone(self):
        for text in ['2128670142', 'version 1.2.867.0142', '2026-11-06', '+2026-11-06',
                     '555-0100', '(212) 555-0142', '(555) 867-0142', 'build 212 867 01425',
                     'v212-867-0142-b', 'id=212-867-0142x']:
            with self.subTest(text=text):
                self.assertEqual(checker().text(text, 'x'), [])

    def test_a_home_folder_is_found_but_a_placeholder_is_not(self):
        for text in [HOME_PATH, f'cd {HOME_PATH}', f'file://{HOME_PATH}',
                     'C:\\Users\\' + HOME_NAME, 'C:/Users/' + HOME_NAME,
                     '/home/' + HOME_NAME + '/x', 'C:\\\\Users\\\\' + HOME_NAME]:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_HOME])
        for text in ['/Users/you/code', '/Users/runner/work', '/home/user/brickson',
                     '/Users/Shared/x', '~/code', 'https://site.example/home/123',
                     'a/Users/x', '/Volumes/x']:
            with self.subTest(text=text):
                self.assertEqual(checker().text(text, 'x'), [])

    def test_no_mark_silences_a_finding(self):
        line = f'{ADDRESS} privacy-check: allow'
        self.assertEqual(kinds(checker().text(line, 'docs/x.md', 'docs/x.md')),
                         [privacy.KIND_EMAIL])

    def test_text_with_a_byte_order_mark_is_read_as_text(self):
        for data in [('\ufeff' + NAME).encode('utf-16-le'), ('\ufeff' + NAME).encode('utf-16-be'),
                     ('\ufeff' + NAME).encode('utf-8')]:
            with self.subTest(data=data[:4]):
                self.assertEqual(kinds(checker(NAME).data(data, 'x', 'x')),
                                 [privacy.KIND_PRIVATE])


class HiddenTextTests(unittest.TestCase):
    """What pictures and other binary files hide: dropping a place it can
    hide, or reading a picture's pixels as text, fails."""

    def found(self, data, words=NAME):
        return sorted(set(kinds(checker(words).data(data, 'x', 'x'))))

    def test_a_png_s_text_chunks_are_read(self):
        compressed = b'Comment\0\0' + zlib.compress(HOME_PATH.encode())
        international = (b'XML:com.adobe.xmp\0\x01\0\0\0'
                         + zlib.compress(f'<dc:creator>{NAME}</dc:creator>'.encode()))
        self.assertEqual(self.found(png(png_chunk(b'tEXt', b'Author\0' + ADDRESS.encode())),
                                    words=NICK), [privacy.KIND_EMAIL])
        self.assertEqual(self.found(png(png_chunk(b'zTXt', compressed))), [privacy.KIND_HOME])
        self.assertEqual(self.found(png(png_chunk(b'iTXt', international))),
                         [privacy.KIND_PRIVATE])

    def test_exif_strings_and_the_place_a_photo_was_taken_are_read(self):
        self.assertEqual(self.found(png(png_chunk(b'eXIf', tiff(artist=NAME)))),
                         [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(png(png_chunk(b'eXIf', tiff(latitude=40)))),
                         [privacy.KIND_PLACE])
        self.assertEqual(self.found(png(png_chunk(b'eXIf', tiff(latitude=0)))), [])
        photo = jpeg(jpeg_segment(0xE1, b'Exif\0\0' + tiff(artist=NAME, latitude=40)),
                     jpeg_segment(0xFE, ADDRESS.encode()))
        self.assertEqual(self.found(photo), sorted([privacy.KIND_EMAIL, privacy.KIND_PLACE,
                                                    privacy.KIND_PRIVATE]))

    def test_a_heic_or_video_is_read_beside_its_media(self):
        heic = (atom(b'ftyp', b'heic\0\0\0\0mif1heic') + atom(b'meta', b'\0' * 12)
                + atom(b'mdat', b'\0\0\0\x06Exif\0\0' + tiff(artist=NAME)))
        self.assertEqual(self.found(heic), [privacy.KIND_PRIVATE])
        video = (atom(b'ftyp', b'qt  \0\0\0\0qt  ')
                 + atom(b'moov', atom(b'udta', atom(b'\xa9xyz', b'\0\x11\0\0+40.7-074.0/')
                                      + atom(b'\xa9nam', f'Clip by {NAME}'.encode())))
                 + atom(b'mdat', NAME.encode()))
        self.assertEqual(self.found(video), sorted([privacy.KIND_PLACE, privacy.KIND_PRIVATE]))
        self.assertEqual(self.found(atom(b'ftyp', b'qt  ') + atom(b'mdat', NAME.encode())), [])

    def test_a_pdf_s_compressed_text_and_a_wav_s_tags_are_read(self):
        pdf = (b'%PDF-1.4\n1 0 obj\n<< /Filter /FlateDecode >>\nstream\n'
               + zlib.compress(f'BT ({NAME}) Tj ET'.encode()) + b'\nendstream\nendobj\n')
        self.assertEqual(self.found(pdf), [privacy.KIND_PRIVATE])
        info = b'INFO' + b'IART' + struct.pack('<I', 17) + NAME.encode() + b'\0\0'
        wav = (b'RIFF\0\0\0\0WAVE' + b'fmt ' + struct.pack('<I', 2) + b'\0\0'
               + b'LIST' + struct.pack('<I', len(info)) + info
               + b'data' + struct.pack('<I', 16) + NAME.encode())
        self.assertEqual(self.found(wav), [privacy.KIND_PRIVATE])

    def test_pixels_and_markup_are_not_words(self):
        noise = bytes(random.Random(7).getrandbits(8) for _ in range(200_000))
        words = 'Li\nAnn\nKai\nEli\nMax\nSam\nBen\nTom\nJoe\nKim'
        self.assertEqual(self.found(png(pixels=noise + NAME.encode()), words=words), [])
        xmp = (b'iTXt', b'XML:com.adobe.xmp\0\0\0\0\0<x:xmpmeta><rdf:Alt><rdf:li xml:lang='
               b'"x-default">Screenshot</rdf:li></rdf:Alt></x:xmpmeta>')
        self.assertEqual(self.found(png(png_chunk(*xmp)), words=words), [])

    def test_other_binary_files_are_read_for_readable_runs(self):
        data = b'\0\x01\x02' + f'owner {ADDRESS} at {HOME_PATH}'.encode() + b'\0\x03'
        self.assertEqual(self.found(data, words=NICK),
                         sorted([privacy.KIND_EMAIL, privacy.KIND_HOME]))
        utf16 = b'\0\x01' + f'by {NAME} ok'.encode('utf-16-le') + b'\0\0'
        self.assertEqual(self.found(utf16), [privacy.KIND_PRIVATE])


class GitTests(unittest.TestCase):
    """What each mode reads in a repository."""

    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.repo = repository(self.folder)
        self.remote = self.folder / 'remote.git'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(self.remote)], check=True)
        git(self.repo, 'remote', 'add', 'origin', str(self.remote))
        git(self.repo, 'push', '-q', 'origin', 'main')
        git(self.repo, 'checkout', '-q', '-b', 'feature')
        self.environ = listed(NAME, NICK)

    def run_here(self, *argv, environ=None, stdin=''):
        return run([*argv, str(self.repo)], environ or self.environ, stdin)

    def commit(self, path, text, message='Change'):
        file = self.repo / path
        file.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, bytes):
            file.write_bytes(text)
        else:
            file.write_text(text)
        git(self.repo, 'add', path)
        git(self.repo, 'commit', '-q', '-m', message)
        return git(self.repo, 'rev-parse', 'HEAD').strip()

    def assertSilent(self, out, err=''):
        # Commit and tag ids are random hex, which may hold the made-up
        # number's digits by chance: they are left out, as nothing else in
        # a report is twelve or more hex digits long.
        words = (out + '\n' + err).replace('(', ' ').replace(')', ' ').split()
        text = ' '.join(word for word in words
                        if len(word) < 12 or set(word) - set('0123456789abcdef'))
        for secret in SECRETS:
            self.assertNotIn(secret, text)

    def test_without_a_list_nothing_passes_unless_asked(self):
        status, _, err = self.run_here('--outgoing', environ=listed())
        self.assertEqual(status, 2)
        self.assertIn('NOT checked', err)
        status, out, _ = self.run_here('--outgoing', '--no-list', environ=listed())
        self.assertEqual(status, 0)
        self.assertIn('no private list', out)

    def test_every_tracked_file_and_its_name_is_read(self):
        self.commit('docs/notes.md', f'one\ntwo {NICK}\n')
        self.commit(f'docs/{NICK.lower()}.md', 'nothing\n')
        status, out, _ = self.run_here()
        self.assertEqual(status, 1)
        self.assertIn('docs/notes.md:2:5: ' + privacy.KIND_PRIVATE, out)
        self.assertIn('of git ls-files: ' + privacy.KIND_PRIVATE + privacy.IN_NAME, out)
        self.assertSilent(out)

    def test_outgoing_reads_unpushed_commits_and_uncommitted_work(self):
        self.commit('a.md', f'{NAME}\n', message='Add a')
        self.commit('a.md', 'clean\n', message=f'Thanks {NICK}')
        (self.repo / 'README.md').write_text(f'A clean start.\n{ADDRESS}\n')
        (self.repo / 'new.md').write_text(f'{PHONE}\n')
        status, out, _ = self.run_here('--outgoing')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'a\.md \(commit [0-9a-f]{12}\):1:1: ' + privacy.KIND_PRIVATE)
        self.assertRegex(out, r'commit [0-9a-f]{12} message:1:8: ' + privacy.KIND_PRIVATE)
        self.assertIn('README.md (not committed):2:1: ' + privacy.KIND_EMAIL, out)
        self.assertIn('new.md:1:1: ' + privacy.KIND_PHONE, out)
        self.assertIn('git reset --soft', out)
        self.assertSilent(out)
        git(self.repo, 'push', '-q', 'origin', 'feature')
        git(self.repo, 'checkout', '-q', 'README.md')
        (self.repo / 'new.md').unlink()
        status, out, _ = self.run_here('--outgoing')
        self.assertEqual((status, 'No personal details' in out), (0, True))

    def test_a_branch_name_and_a_signature_are_read(self):
        git(self.repo, 'checkout', '-q', '-b', f'claude/{NICK.lower()}-notes')
        self.commit('b.md', 'fine\n')
        status, out, _ = self.run_here('--outgoing')
        self.assertIn('the current branch: ' + privacy.KIND_PRIVATE + privacy.IN_NAME, out)
        self.assertSilent(out)
        git(self.repo, 'checkout', '-q', 'feature')
        (self.repo / 'c.md').write_text('fine\n')
        git(self.repo, 'add', 'c.md')
        subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=Someone',
                        '-c', 'user.email=' + ADDRESS, '-c', 'commit.gpgsign=false',
                        'commit', '-q', '-m', 'c'], check=True)
        status, out, _ = self.run_here('--outgoing')
        self.assertRegex(out, r'commit [0-9a-f]{12} author: ' + privacy.KIND_EMAIL)
        self.assertRegex(out, r'commit [0-9a-f]{12} committer: ' + privacy.KIND_EMAIL)

    def test_an_empty_file_s_name_and_a_binary_file_in_a_commit_are_read(self):
        self.commit(f'{NICK}.txt', '')
        self.commit('pic.png', png(png_chunk(b'tEXt', b'Author\0' + ADDRESS.encode())))
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'changed file 1 \(commit [0-9a-f]{12}\): '
                         + privacy.KIND_PRIVATE + privacy.IN_NAME)
        self.assertRegex(out, r'pic\.png \(commit [0-9a-f]{12}\): ' + privacy.KIND_EMAIL)
        self.assertSilent(out)

    def test_a_change_made_while_merging_is_read(self):
        self.commit('f.md', 'feature\n')
        git(self.repo, 'checkout', '-q', 'main')
        self.commit('g.md', 'main\n')
        git(self.repo, 'checkout', '-q', 'feature')
        git(self.repo, 'merge', '-q', '--no-edit', 'main')
        (self.repo / 'g.md').write_text(f'main\n{NAME}\n')
        git(self.repo, 'add', 'g.md')
        git(self.repo, 'commit', '-q', '--amend', '--no-edit')
        status, out, _ = self.run_here('--commits', 'origin/main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'g\.md \(commit [0-9a-f]{12}\):2:1: ' + privacy.KIND_PRIVATE)

    def test_pre_push_reads_what_each_pushed_ref_carries(self):
        zero = '0' * 40
        base = git(self.repo, 'rev-parse', 'HEAD').strip()
        dirty = self.commit('d.md', f'{NICK}\n')
        clean = self.commit('d.md', 'clean\n')
        line = f'refs/heads/feature {clean} refs/heads/feature {zero}\n'
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=line)
        self.assertEqual(status, 1)
        self.assertIn(dirty[:12], out)
        # The remote already has the dirty commit: only what is new is read.
        line = f'refs/heads/feature {clean} refs/heads/feature {dirty}\n'
        git(self.repo, 'push', '-q', 'origin', f'{dirty}:refs/heads/feature')
        self.assertEqual(self.run_here('--pre-push', 'origin', stdin=line)[0], 0)
        # A deletion publishes nothing; a new remote name is read.
        self.assertEqual(self.run_here('--pre-push', 'origin', stdin=(
            f'(delete) {zero} refs/heads/{NICK} {base}\n'))[0], 0)
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/heads/feature {clean} refs/heads/{NICK.lower()} {zero}\n'))
        self.assertIn('the names in pushed line 1: ' + privacy.KIND_PRIVATE, out)
        self.assertSilent(out)

    def test_pre_push_reads_an_annotated_tag(self):
        git(self.repo, 'tag', '-a', 'v1', '-m', f'For {NAME}')
        tag = git(self.repo, 'rev-parse', 'v1').strip()
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/tags/v1 {tag} refs/tags/v1 {"0" * 40}\n'))
        self.assertEqual(status, 1)
        self.assertRegex(out, r'tag object [0-9a-f]{12} message:1:5: ' + privacy.KIND_PRIVATE)

    def test_the_hook_stops_a_push_and_lets_a_clean_one_through(self):
        # A clone with the real hook and checker, as the owner's would be.
        (self.repo / '.githooks').mkdir()
        (self.repo / 'scripts').mkdir()
        shutil.copy2(HOOK, self.repo / '.githooks' / 'pre-push')
        shutil.copy2(SCRIPT, self.repo / 'scripts' / 'privacy-check.py')
        git(self.repo, 'add', '.githooks', 'scripts')
        git(self.repo, 'commit', '-q', '-m', 'Add the check')
        environ = dict(os.environ, **self.environ)
        environ.pop('GIT_DIR', None)

        def push(*args):
            return subprocess.run(['git', '-C', str(self.repo), '-c',
                                   'core.hooksPath=.githooks', 'push', '-q', 'origin', *args],
                                  capture_output=True, text=True, env=environ)

        self.assertEqual(push('feature').returncode, 0, 'a clean push goes through')
        self.commit('e.md', f'{NAME}\n')
        result = push('feature')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(privacy.KIND_PRIVATE, result.stdout + result.stderr)
        self.assertSilent(result.stdout, result.stderr)
        environ[privacy.LIST_VARIABLE] = ''
        self.commit('e.md', 'clean\n')
        result = push('feature')
        self.assertNotEqual(result.returncode, 0, 'no list: nothing is pushed')
        self.assertIn('NOT checked', result.stderr)

    def test_ci_reads_what_is_not_yet_on_main_and_refuses_a_shallow_clone(self):
        self.commit('h.md', f'{NICK}\n')
        self.commit('h.md', 'clean\n')
        git(self.repo, 'fetch', '-q', 'origin')
        self.assertEqual(privacy.ci_revisions(self.repo), ['refs/remotes/origin/main..HEAD'])
        # A tag named origin/main, which git reads before the remote's
        # branch, does not stand in for main.
        git(self.repo, 'tag', 'origin/main', 'HEAD')
        self.assertEqual(privacy.ci_revisions(self.repo), ['refs/remotes/origin/main..HEAD'])
        git(self.repo, 'tag', '-d', 'origin/main')
        git(self.repo, 'checkout', '-q', 'main')
        git(self.repo, 'merge', '-q', '--no-ff', '--no-edit', 'feature')
        git(self.repo, 'push', '-q', 'origin', 'main')
        git(self.repo, 'fetch', '-q', 'origin')
        self.assertEqual(privacy.ci_revisions(self.repo), ['HEAD^1..HEAD'])
        shallow = self.folder / 'shallow'
        subprocess.run(['git', 'clone', '-q', '--depth', '1', f'file://{self.remote}',
                        str(shallow)], check=True, capture_output=True)
        with self.assertRaises(privacy.SetupError) as raised:
            privacy.ci_revisions(shallow)
        self.assertIn('fetch-depth: 0', str(raised.exception))

    def test_a_draft_is_read_from_stdin(self):
        status, out, _ = run(['--text', '-', str(self.repo)], self.environ,
                             stdin=f'Body\n\nThanks {NICK}\n')
        self.assertEqual(status, 1)
        self.assertIn('the draft:3:8: ' + privacy.KIND_PRIVATE, out)

    def test_a_draft_s_file_name_is_checked_and_never_shown(self):
        draft = self.folder / f'{NICK} reply.md'
        draft.write_text(f'Thanks {NAME}\n')
        status, out, _ = self.run_here('--text', str(draft))
        self.assertEqual(status, 1)
        self.assertIn('draft 1:1:8: ' + privacy.KIND_PRIVATE + '\n', out)
        self.assertIn('draft 1: ' + privacy.KIND_PRIVATE + privacy.IN_NAME, out)
        self.assertSilent(out)
        # A clean name is shown, as before.
        clean = self.folder / 'reply.md'
        clean.write_text(f'Thanks {NAME}\n')
        self.assertIn(f'draft {clean}:1:8: ', self.run_here('--text', str(clean))[1])

    def test_status_names_entries_by_number_and_says_whether_the_hook_runs(self):
        self.commit('i.md', f'{NICK} and {NICK}\n')
        status, out, _ = self.run_here('--status')
        self.assertEqual(status, 0)
        self.assertIn('2 entries from BRICKSON_PRIVATE_WORDS.', out)
        self.assertIn('Entry 2 of BRICKSON_PRIVATE_WORDS matches 2 places', out)
        self.assertNotIn('Entry 1 ', out)
        self.assertIn('do NOT run the privacy hook', out)
        self.assertSilent(out)
        (self.repo / '.githooks').mkdir()
        shutil.copy2(HOOK, self.repo / '.githooks' / 'pre-push')
        git(self.repo, 'config', 'core.hooksPath', '.githooks')
        self.assertIn('Pushes from this checkout run the privacy hook.',
                      self.run_here('--status')[1])

    def test_status_names_a_checkout_whose_branch_has_no_hook(self):
        # Git runs .githooks from the checkout, not from the branch a push
        # names: set the right way on a branch made before the hook reached
        # main, pushes run nothing, and turning the setting on again would
        # not help.
        git(self.repo, 'config', 'core.hooksPath', '.githooks')
        status, out, _ = self.run_here('--status')
        self.assertEqual(status, 0)
        self.assertIn('do NOT run the privacy hook', out)
        self.assertIn('merge origin/main', out)
        self.assertNotIn('Turn it on', out)

    def test_a_change_in_windows_latin_is_read_with_its_accents(self):
        # A file that is not UTF-8 is read as UTF-8 where it is and as
        # Windows' Latin (file_texts); what a commit, a push or the next
        # commit adds to one is read both ways too.
        environ = listed('Jos\u00e9 Quillon')
        self.commit('notes.txt', 'Thanks to Jos\u00e9 Quillon\n'.encode('cp1252'))
        for argv in (['--commits', 'main..HEAD'], ['--history']):
            status, out, _ = self.run_here(*argv, environ=environ)
            self.assertEqual(status, 1, argv)
            self.assertRegex(out, r'notes\.txt \(commit [0-9a-f]{12}\):1:11: '
                             + privacy.KIND_PRIVATE)
            self.assertSilent(out)
        (self.repo / 'more.txt').write_bytes('ok \xff\nJos\u00e9 Quillon wrote\n'.encode('latin-1'))
        git(self.repo, 'add', 'more.txt')
        status, out, _ = self.run_here('--outgoing', environ=environ)
        self.assertEqual(status, 1)
        self.assertRegex(out, r'more\.txt \(staged\):2:1: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)
        # Read both ways, a name is still reported once.
        self.assertEqual(out.count('(staged)'), 1)

    # --status passing, or ending on the hook's line, when it read no list
    # fails this: success is a list read and the hook on.
    def test_status_without_a_list_fails_and_says_so_last(self):
        (self.repo / '.githooks').mkdir()
        shutil.copy2(HOOK, self.repo / '.githooks' / 'pre-push')
        git(self.repo, 'config', 'core.hooksPath', '.githooks')
        status, out, _ = self.run_here('--status', environ=listed())
        self.assertEqual(status, 2)
        self.assertIn('No private list', out.strip().splitlines()[-1])
        status, out, _ = self.run_here('--status', '--no-list', environ=listed())
        self.assertEqual(status, 0)
        self.assertIn('run the privacy hook', out.strip().splitlines()[-1])


class GitOutputTests(unittest.TestCase):
    """Reading what git writes: names it quotes, patches whose files hold
    any byte, its own error messages. Misreading a name, or printing what
    git said, fails here."""

    setUp = GitTests.setUp
    run_here = GitTests.run_here
    commit = GitTests.commit
    assertSilent = GitTests.assertSilent

    def test_a_name_with_a_space_is_never_shown_beside_what_it_holds(self):
        # Git ends a +++ line with a tab when the name has a space.
        self.commit(f'{NAME}.md', f'{NAME} wrote this\n')
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'changed file 1 \(commit [0-9a-f]{12}\):1:1: '
                         + privacy.KIND_PRIVATE + '\n')
        self.assertSilent(out)
        (self.repo / f'{NICK} notes.md').write_text(f'{NICK}\n')
        git(self.repo, 'add', f'{NICK} notes.md')
        status, out, _ = self.run_here('--outgoing')
        self.assertRegex(out, r'changed file 1 \(staged\):1:1: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)

    def test_every_name_a_patch_gives_is_checked_before_it_is_shown(self):
        # Whichever line of a patch names a file, its name is checked
        # before anything is reported under it.
        patch = (f'diff --git a/x b/y\n--- /dev/null\n+++ b/{NAME}.md\t\n'
                 f'@@ -0,0 +1 @@\n+{NAME}\n')
        findings = privacy.read_patch(checker(NAME), patch, ' (x)', lambda path: b'',
                                      privacy.Tally())
        self.assertEqual([str(finding) for finding in findings],
                         ['changed file 1 (x): ' + privacy.KIND_PRIVATE + privacy.IN_NAME,
                          'changed file 1 (x):1:1: ' + privacy.KIND_PRIVATE])

    def test_what_a_file_with_a_quoted_name_holds_is_read(self):
        # A name with a quote and a space: git writes "b/..." and a tab.
        self.commit('my "notes" file.md', f'mail me at {ADDRESS}\n')
        self.commit('a "pic" here.png', png(png_chunk(b'tEXt', b'Author\0' + ADDRESS.encode())))
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'my "notes" file\.md \(commit [0-9a-f]{12}\):1:12: '
                         + privacy.KIND_EMAIL)
        self.assertRegex(out, r'a "pic" here\.png \(commit [0-9a-f]{12}\): '
                         + privacy.KIND_EMAIL)

    def test_a_binary_file_whose_name_holds_and_b_is_read(self):
        # "Binary files a/<name> and b/<name> differ" cannot be split
        # where a name holds " and b/"; the header names it once.
        self.commit('x and b/y.png', png(png_chunk(b'tEXt', b'Note\0clean')))
        self.commit('x and b/y.png', png(png_chunk(b'tEXt', b'Author\0' + ADDRESS.encode())))
        status, out, err = self.run_here('--commits', 'HEAD~1..HEAD')
        self.assertEqual((status, err), (1, ''))
        self.assertRegex(out, r'x and b/y\.png \(commit [0-9a-f]{12}\): ' + privacy.KIND_EMAIL)

    def test_names_in_any_script_are_unquoted_as_utf8(self):
        # Octal escapes are the bytes of the name's UTF-8.
        self.assertEqual(privacy.unquote('"b/Caf\\303\\251 \\"x\\".png"'), 'b/Café "x".png')
        self.assertEqual(privacy.unquote('"b/Zo\\303\\253\\342\\200\\231s.md"'), 'b/Zoë’s.md')
        # With core.quotePath off, git leaves letters as they are.
        self.assertEqual(privacy.unquote('"b/Zoë’s \\"plan\\".md"'), 'b/Zoë’s "plan".md')
        self.assertEqual(privacy.unquote('"b/a\\tb\\\\c\\nd"'), 'b/a\tb\\c\nd')
        self.assertEqual(privacy.unquote('b/plain name.md'), 'b/plain name.md')
        self.commit('Zoë’s "plan".md', f'{ADDRESS}\n')
        self.commit('中"x.md', 'fine\n')
        status, out, err = self.run_here('--commits', 'main..HEAD')
        self.assertEqual((status, err), (1, ''))
        self.assertRegex(out, r'Zoë’s "plan"\.md \(commit [0-9a-f]{12}\):1:1: '
                         + privacy.KIND_EMAIL)
        # An accented spelling in a quoted name is still the listed name.
        before = git(self.repo, 'rev-parse', 'HEAD').strip()
        after = self.commit('Quillon Vassmère "notes".md', 'fine\n')
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/heads/feature {after} refs/heads/feature {before}\n'))
        self.assertEqual(status, 1)
        self.assertIn(privacy.KIND_PRIVATE + privacy.IN_NAME, out)
        self.assertNotIn('Vassm', out)

    def test_a_control_byte_in_a_file_never_splits_its_commit(self):
        self.commit('a.txt', f'hello\n\x01{NAME}\n')
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'a\.txt \(commit [0-9a-f]{12}\):2:2: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)
        # Lines that look like commit headers are a file's lines, too.
        sha = git(self.repo, 'rev-parse', 'HEAD').strip()
        self.commit('b.txt', f'\x01{sha}\n{ADDRESS}\n')
        status, out, _ = self.run_here('--commits', 'HEAD~1..HEAD')
        self.assertRegex(out, r'b\.txt \(commit [0-9a-f]{12}\):2:1: ' + privacy.KIND_EMAIL)
        self.assertNotIn(f'(commit {sha[:12]})', out)

    def test_git_s_own_messages_are_never_shown(self):
        # They can name a file, a revision or a line of one.
        with self.assertRaises(privacy.SetupError) as raised:
            privacy.git(self.repo, 'cat-file', 'blob', f'HEAD:{NAME}.png')
        self.assertIn('git cat-file failed', str(raised.exception))
        self.assertNotIn('Quillon', str(raised.exception))
        status, out, err = self.run_here('--commits', f'{NICK}..HEAD')
        self.assertEqual(status, 2)
        self.assertIn('git log failed', err)
        self.assertSilent(out, err)
        status, out, err = self.run_here('--ci', '--commits', f'{NICK}..HEAD')
        self.assertEqual(status, 2)
        self.assertSilent(out, err)

    def test_a_list_is_read_from_a_hook_that_names_its_repository(self):
        # git gives a hook GIT_DIR; the list's own folder is no checkout.
        config = self.folder / 'config'
        listing = config / 'brickson' / 'private-words.txt'
        listing.parent.mkdir(parents=True)
        listing.write_text(f'{NICK}\n')
        listing.chmod(0o600)
        environ = {'HOME': str(self.folder), 'XDG_CONFIG_HOME': str(config)}
        with mock.patch.dict(os.environ, {'GIT_DIR': str(self.repo / '.git')}):
            self.assertFalse(privacy.committable(listing))
            found, counts, _ = privacy.load_list(environ)
        self.assertEqual((len(found), len(counts)), (1, 1))

    def test_a_push_from_a_worktree_reads_the_list(self):
        # As the owner's would be: the list in its file, pushed from a
        # linked worktree, whose hook git runs with GIT_DIR set.
        (self.repo / '.githooks').mkdir()
        (self.repo / 'scripts').mkdir()
        shutil.copy2(HOOK, self.repo / '.githooks' / 'pre-push')
        shutil.copy2(SCRIPT, self.repo / 'scripts' / 'privacy-check.py')
        git(self.repo, 'add', '.githooks', 'scripts')
        git(self.repo, 'commit', '-q', '-m', 'Add the check')
        git(self.repo, 'config', 'core.hooksPath', '.githooks')
        config = self.folder / 'config'
        listing = config / 'brickson' / 'private-words.txt'
        listing.parent.mkdir(parents=True)
        listing.write_text(f'{NICK}\n')
        listing.chmod(0o600)
        worktree = self.folder / 'worktree'
        git(self.repo, 'worktree', 'add', '-q', '-b', 'topic', str(worktree))
        environ = {key: value for key, value in os.environ.items()
                   if not key.startswith('GIT_')}
        environ.update(XDG_CONFIG_HOME=str(config), HOME=str(self.folder))
        environ.pop(privacy.LIST_VARIABLE, None)

        def push():
            return subprocess.run(['git', '-C', str(worktree), 'push', '-q', 'origin', 'topic'],
                                  capture_output=True, text=True, env=environ)

        result = push()
        self.assertEqual(result.returncode, 0, 'a clean push from a worktree goes through')
        (worktree / 'w.md').write_text(f'{NICK}\n')
        git(worktree, 'add', 'w.md')
        git(worktree, 'commit', '-q', '-m', 'w')
        result = push()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(privacy.KIND_PRIVATE, result.stdout + result.stderr)
        self.assertSilent(result.stdout, result.stderr)


class GitHistoryTests(unittest.TestCase):
    """What a push carries beyond each commit's own added lines: names
    joined by a change, replaced objects, octopus merges, tags inside
    tags, commits another remote has and the index."""

    setUp = GitTests.setUp
    run_here = GitTests.run_here
    commit = GitTests.commit
    assertSilent = GitTests.assertSilent

    def on_main(self, path, text):
        """A file already on main and its remote, as if published before."""
        git(self.repo, 'checkout', '-q', 'main')
        self.commit(path, text)
        git(self.repo, 'push', '-q', 'origin', 'main')
        git(self.repo, 'checkout', '-q', 'feature')
        git(self.repo, 'merge', '-q', '--ff-only', 'main')

    def test_a_name_joined_by_a_change_on_a_neighbouring_line_is_read(self):
        first, last = NAME.split()
        self.on_main('doc.md', f'We thank {first}\nfor the idea.\n')
        self.commit('doc.md', f'We thank {first}\n{last} for the idea.\n')
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'doc\.md \(commit [0-9a-f]{12}\):1:10: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)

    def test_a_name_joined_by_removing_the_lines_between_is_read(self):
        first, last = NAME.split()
        self.on_main('doc.md', f'We thank {first}\n(draft note)\n{last} for the idea.\n')
        self.commit('doc.md', f'We thank {first}\n{last} for the idea.\n')
        status, out, _ = self.run_here('--commits', 'main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'doc\.md \(commit [0-9a-f]{12}\):1:10: ' + privacy.KIND_PRIVATE)

    def test_what_unchanged_lines_already_held_is_not_new(self):
        first, last = NAME.split()
        self.on_main('doc.md', f'Intro\n{first}\n{last}\n{ADDRESS}\nold\nend\n')
        new = self.commit('doc.md', f'Intro\n{first}\n{last}\n{ADDRESS}\nnew\nend\n')
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/heads/feature {new} refs/heads/feature {"0" * 40}\n'))
        self.assertEqual((status, 'No personal details' in out), (0, True), out)

    def test_the_guard_reads_a_name_a_staged_change_joins(self):
        first, last = NAME.split()
        self.on_main('doc.md', f'We thank {first}\nfor the idea.\n')
        (self.repo / 'doc.md').write_text(f'We thank {first}\n{last} for the idea.\n')
        git(self.repo, 'add', 'doc.md')
        findings = privacy.guard_findings(commits_from=[(self.repo, ())],
                                          environ=listed(NAME))
        self.assertEqual([str(finding) for finding in findings],
                         ['doc.md (staged):1:10: ' + privacy.KIND_PRIVATE])

    def test_a_pdf_git_takes_for_text_is_read_as_a_pdf(self):
        # Its patch shows only compressed bytes, so the file is read whole.
        data = pdf_without_a_zero_byte()
        self.assertNotIn(NAME.encode(), data)
        self.commit('docs/thanks.pdf', data)
        status, out, _ = self.run_here('--commits', 'HEAD~1..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'docs/thanks\.pdf \(commit [0-9a-f]{12}\): ' + privacy.KIND_PRIVATE)
        # Staged and not yet committed, the same.
        git(self.repo, 'reset', '-q', '--soft', 'HEAD~1')
        status, out, _ = self.run_here('--outgoing')
        self.assertEqual(status, 1)
        self.assertIn('docs/thanks.pdf (staged): ' + privacy.KIND_PRIVATE, out)

    def test_a_replaced_commit_is_read_as_it_is_pushed(self):
        # git replace changes what git log shows, not what a push sends.
        dirty = self.commit('a.txt', f'Thanks {NAME}\n', message=f'Notes from {NAME}')
        tree = git(self.repo, 'rev-parse', 'main^{tree}').strip()
        clean = git(self.repo, 'commit-tree', tree, '-p', 'main', '-m', 'Notes').strip()
        git(self.repo, 'replace', dirty, clean)
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/heads/feature {dirty} refs/heads/feature {"0" * 40}\n'))
        self.assertEqual(status, 1)
        self.assertRegex(out, r'a\.txt \(commit [0-9a-f]{12}\):1:8: ' + privacy.KIND_PRIVATE)
        self.assertRegex(out, r'commit [0-9a-f]{12} message:1:12: ' + privacy.KIND_PRIVATE)

    def test_a_change_made_while_committing_an_octopus_merge_is_read(self):
        for branch in ('b1', 'b2'):
            git(self.repo, 'checkout', '-q', '-b', branch, 'main')
            self.commit(f'{branch}.md', f'{branch}\n')
        git(self.repo, 'checkout', '-q', 'feature')
        self.commit('f.md', 'feature\n')
        git(self.repo, 'merge', '-q', '--no-commit', 'b1', 'b2')
        (self.repo / 'evil.txt').write_text(f'Thanks {NAME}\n')
        git(self.repo, 'add', 'evil.txt')
        git(self.repo, 'commit', '-q', '-m', 'Merge b1 and b2')
        self.assertEqual(len(git(self.repo, 'rev-list', '--parents', '-n', '1',
                                 'HEAD').split()), 4)
        status, out, _ = self.run_here('--commits', 'origin/main..HEAD')
        self.assertEqual(status, 1)
        self.assertRegex(out, r'evil\.txt \(commit [0-9a-f]{12}\):1:8: '
                         + privacy.KIND_PRIVATE)

    def test_a_tag_inside_a_pushed_tag_is_read(self):
        git(self.repo, 'tag', '-a', 'inner', '-m', f'Release for {NAME}')
        git(self.repo, 'tag', '-a', 'outer', '-m', 'Release', 'inner')
        git(self.repo, 'tag', '-d', 'inner')
        outer = git(self.repo, 'rev-parse', 'outer').strip()
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/tags/outer {outer} refs/tags/outer {"0" * 40}\n'))
        self.assertEqual(status, 1)
        self.assertRegex(out, r'tag object [0-9a-f]{12} message:1:13: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)

    def test_the_name_a_tag_object_was_made_with_is_read(self):
        # Renaming a tag keeps the old name inside its object.
        git(self.repo, 'tag', '-a', f'{NICK}-visit', '-m', 'Visit')
        git(self.repo, 'tag', 'visit', f'{NICK}-visit')
        git(self.repo, 'tag', '-d', f'{NICK}-visit')
        tag = git(self.repo, 'rev-parse', 'visit').strip()
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=(
            f'refs/tags/visit {tag} refs/tags/visit {"0" * 40}\n'))
        self.assertEqual(status, 1)
        self.assertRegex(out, r'tag object [0-9a-f]{12} name: ' + privacy.KIND_PRIVATE
                         + privacy.IN_NAME)
        self.assertSilent(out)


    def test_a_push_to_a_url_reads_what_another_remote_has(self):
        private = self.folder / 'private.git'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(private)], check=True)
        git(self.repo, 'remote', 'add', 'private', str(private))
        git(self.repo, 'checkout', '-q', '-b', 'notes', 'main')
        notes = self.commit('n.txt', f'Thanks {NAME}\n')
        git(self.repo, 'push', '-q', 'private', 'notes')
        line = f'refs/heads/notes {notes} refs/heads/notes {"0" * 40}\n'
        # Pushed by its name, origin has never had the private commit.
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=line)
        self.assertEqual(status, 1)
        # Pushed to origin's URL rather than its name: the same.
        status, out, _ = self.run_here('--pre-push', str(self.remote), stdin=line)
        self.assertEqual(status, 1)
        self.assertRegex(out, r'n\.txt \(commit [0-9a-f]{12}\):1:8: ' + privacy.KIND_PRIVATE)
        # A URL names the remotes that push there: what they have is not new.
        self.assertEqual(privacy.remote_exclusion(self.repo, str(self.remote)),
                         ['--remotes=origin'])
        self.assertEqual(privacy.remote_exclusion(self.repo, str(private)),
                         ['--remotes=private'])
        self.assertEqual(self.run_here('--pre-push', str(private), stdin=line)[0], 0)
        # A URL no remote names may have none of it.
        elsewhere = str(self.folder / 'elsewhere.git')
        self.assertEqual(privacy.remote_exclusion(self.repo, elsewhere), [])
        self.assertEqual(self.run_here('--pre-push', elsewhere, stdin=line)[0], 1)

    def test_outgoing_reads_the_index_and_untracked_links(self):
        (self.repo / 'a.txt').write_text(f'Thanks {NAME}\n')
        git(self.repo, 'add', 'a.txt')
        (self.repo / 'a.txt').write_text('Thanks someone\n')
        status, out, _ = self.run_here('--outgoing')
        self.assertEqual(status, 1)
        self.assertIn('a.txt (staged):1:8: ' + privacy.KIND_PRIVATE, out)
        (self.repo / 'a.txt').unlink()
        self.assertEqual(self.run_here('--outgoing')[0], 1)
        git(self.repo, 'rm', '-q', '--cached', 'a.txt')
        # A link git would commit as its target's path, which may not exist.
        os.symlink(HOME_PATH + '/notes.txt', self.repo / 'link')
        os.symlink(str(self.folder), self.repo / 'folder-link')
        status, out, _ = self.run_here('--outgoing')
        self.assertEqual(status, 1)
        self.assertIn('link:1:1: ' + privacy.KIND_HOME, out)
        self.assertSilent(out)
        findings = privacy.pending(privacy.Checker(entries(NAME)), self.repo, self.repo,
                                   ['link'], privacy.Tally())
        self.assertEqual([str(finding) for finding in findings],
                         ['link:1:1: ' + privacy.KIND_HOME])

    def test_a_hook_without_a_list_says_how_to_set_one_up(self):
        status, _, err = self.run_here('--pre-push', 'origin', environ=listed(),
                                       stdin='')
        self.assertEqual(status, 2)
        self.assertIn('NOT checked', err)
        self.assertNotIn('--no-list', err)
        self.assertIn(privacy.LIST_VARIABLE, err)
        self.assertIn('Never skip', err)


def git_settings(**settings):
    """Git settings for every git the check runs, as a person's own
    configuration would give them."""
    environ = {'GIT_CONFIG_COUNT': str(len(settings))}
    for number, (key, value) in enumerate(settings.items()):
        environ[f'GIT_CONFIG_KEY_{number}'] = key.replace('_', '.')
        environ[f'GIT_CONFIG_VALUE_{number}'] = value
    return mock.patch.dict(os.environ, environ)


class GitSettingTests(unittest.TestCase):
    """Git reading that a person's own git settings, a merge in progress,
    an odd file name or the way a push names its remote could change."""

    setUp = GitTests.setUp
    run_here = GitTests.run_here
    commit = GitTests.commit
    assertSilent = GitTests.assertSilent
    on_main = GitHistoryTests.on_main

    def signed_commit(self, message):
        """A commit with a signature gpg cannot check, by an author whose
        address is not allowed."""
        tree = git(self.repo, 'rev-parse', 'HEAD^{tree}').strip()
        parent = git(self.repo, 'rev-parse', 'HEAD').strip()
        body = (f'tree {tree}\nparent {parent}\n'
                f'author Robin Doe <{ADDRESS}> 1700000000 +0000\n'
                f'committer Robin Doe <{ADDRESS}> 1700000000 +0000\n'
                'gpgsig -----BEGIN PGP SIGNATURE-----\n \n iQEzBAABCAAdFiEE\n'
                ' =abcd\n -----END PGP SIGNATURE-----\n\n' + message + '\n')
        sha = subprocess.run(['git', '-C', str(self.repo), 'hash-object', '-t', 'commit', '-w',
                              '--stdin'], input=body, capture_output=True, text=True,
                             check=True).stdout.strip()
        git(self.repo, 'update-ref', 'refs/heads/feature', sha)
        return sha

    def test_signature_lines_git_is_set_to_show_never_shift_a_commit(self):
        sha = self.signed_commit(f'Thanks {NAME}')
        expected = [f'commit {sha[:12]} author: ' + privacy.KIND_EMAIL,
                    f'commit {sha[:12]} committer: ' + privacy.KIND_EMAIL,
                    f'commit {sha[:12]} message:1:8: ' + privacy.KIND_PRIVATE]
        for setting in ('false', 'true'):
            with git_settings(log_showSignature=setting):
                findings = privacy.commits(privacy.Checker(entries(NAME)), self.repo,
                                           [f'{sha}^!'], privacy.Tally())
            self.assertEqual([str(finding) for finding in findings], expected, setting)

    def test_what_a_first_commit_adds_is_read_whatever_git_is_set_to_show(self):
        git(self.repo, 'checkout', '-q', '--orphan', 'pages')
        git(self.repo, 'rm', '-q', '-r', '--cached', '.')
        root = self.commit('index.txt', f'Thanks {NAME}\n')
        line = f'refs/heads/pages {root} refs/heads/pages {"0" * 40}\n'
        with git_settings(log_showRoot='false'):
            status, out, _ = self.run_here('--pre-push', 'origin', stdin=line)
        self.assertEqual(status, 1, out)
        self.assertRegex(out, r'index\.txt \(commit [0-9a-f]{12}\):1:8: ' + privacy.KIND_PRIVATE)

    def test_a_staged_file_whose_name_starts_like_a_stage_number_is_read(self):
        # 2:3 is how a Mac stores a Finder name written 2/3.
        picture = png(png_chunk(b'tEXt', b'Author\0' + NAME.encode()))
        for name in ('2:3 crop.png', '0:shot.png'):
            (self.repo / name).write_bytes(picture)
            git(self.repo, 'add', name)
        findings = privacy.guard_findings(commits_from=[(self.repo, ())],
                                          environ=listed(NAME))
        self.assertEqual(sorted(str(finding) for finding in findings),
                         ['0:shot.png (staged): ' + privacy.KIND_PRIVATE,
                          '2:3 crop.png (staged): ' + privacy.KIND_PRIVATE])

    def conflict(self):
        """feature and main change README.md differently, and main also
        brings a file holding an address it published; feature merges
        main and stops at the conflict."""
        self.commit('README.md', 'A feature start.\n')
        git(self.repo, 'checkout', '-q', 'main')
        self.commit('README.md', 'A main start.\n')
        self.commit('contact.md', f'Write to {ADDRESS}\n')
        git(self.repo, 'push', '-q', 'origin', 'main')
        git(self.repo, 'checkout', '-q', 'feature')
        git(self.repo, 'merge', '-q', 'main', check=False)
        self.assertIn('README.md', git(self.repo, 'diff', '--name-only', '--diff-filter=U'))

    def test_a_merge_commit_reads_only_what_its_resolution_adds(self):
        self.conflict()
        (self.repo / 'README.md').write_text(f'A main start.\nThanks {NAME}\n')
        git(self.repo, 'add', 'README.md')
        findings = privacy.guard_findings(commits_from=[(self.repo, ())],
                                          environ=listed(NAME))
        self.assertEqual([str(finding) for finding in findings],
                         ['README.md (staged):2:8: ' + privacy.KIND_PRIVATE])
        # A change staged while merging is read too, as for any commit.
        (self.repo / 'new.md').write_text(f'Call {PHONE}\n')
        git(self.repo, 'add', 'new.md')
        findings = privacy.guard_findings(commits_from=[(self.repo, ())],
                                          environ=listed(NAME))
        self.assertEqual(sorted(str(finding) for finding in findings),
                         ['README.md (staged):2:8: ' + privacy.KIND_PRIVATE,
                          'new.md (staged):1:6: ' + privacy.KIND_PHONE])

    def test_outgoing_reads_files_a_merge_left_in_conflict(self):
        self.conflict()
        with open(self.repo / 'README.md', 'a') as file:
            file.write(f'Thanks {NAME}\n')
        status, out, err = self.run_here('--outgoing')
        self.assertEqual(status, 1, err)
        self.assertRegex(out, r'README\.md:\d+:8: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out, err)
        (self.repo / 'README.md').write_text('A main start.\n')
        status, out, err = self.run_here('--outgoing')
        self.assertEqual(status, 0, out + err)

    def test_advice_to_rewrite_commits_is_only_for_commits_that_exist(self):
        made = privacy.advice([privacy.Finding('a.txt (commit 0123456789ab)', 1, 1,
                                               privacy.KIND_PRIVATE)])
        self.assertIn('--amend', made)
        made = privacy.advice([privacy.Finding('commit 0123456789ab message', 1, 1,
                                               privacy.KIND_PRIVATE)])
        self.assertIn('--amend', made)
        for where in ('the commit message', 'the commit author', 'a.txt (staged)'):
            refused = privacy.advice([privacy.Finding(where, 1, 1, privacy.KIND_PRIVATE)])
            self.assertNotIn('--amend', refused, where)
            self.assertNotIn('reset', refused, where)
        self.assertIn('nothing was committed',
                      privacy.advice([privacy.Finding('the commit message', 1, 1,
                                                      privacy.KIND_PRIVATE)]))

    def test_a_remote_s_tracking_refs_count_only_where_it_fetches_from(self):
        # Tracking refs record what a remote's fetch address held. A remote
        # that pushes elsewhere (a pushurl) says nothing about what that
        # other repository has, so its commits there are all new.
        mirror = self.folder / 'mirror.git'
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', str(mirror)], check=True)
        git(self.repo, 'checkout', '-q', '-b', 'notes', 'main')
        notes = self.commit('n.txt', f'Thanks {NAME}\n')
        git(self.repo, 'push', '-q', 'origin', 'notes')
        line = f'refs/heads/notes {notes} refs/heads/notes {"0" * 40}\n'
        self.assertEqual(self.run_here('--pre-push', 'origin', stdin=line)[0], 0)
        git(self.repo, 'remote', 'set-url', '--push', 'origin', str(mirror))
        self.assertEqual(privacy.remote_exclusion(self.repo, 'origin'), [])
        status, out, _ = self.run_here('--pre-push', 'origin', stdin=line)
        self.assertEqual(status, 1)
        self.assertRegex(out, r'n\.txt \(commit [0-9a-f]{12}\):1:8: ' + privacy.KIND_PRIVATE)
        self.assertSilent(out)
        # Pushed to the mirror's URL: origin only pushes there, so the same.
        self.assertEqual(privacy.remote_exclusion(self.repo, str(mirror)), [])
        self.assertEqual(self.run_here('--pre-push', str(mirror), stdin=line)[0], 1)
        # A remote that fetches from the mirror too is read for it.
        git(self.repo, 'remote', 'add', 'copy', str(mirror))
        self.assertEqual(privacy.remote_exclusion(self.repo, str(mirror)), ['--remotes=copy'])
        # origin's fetch address is still origin's.
        self.assertEqual(privacy.remote_exclusion(self.repo, str(self.remote)),
                         ['--remotes=origin'])

    def test_a_push_to_another_spelling_of_a_remote_s_address_is_that_remote(self):
        exclusion = lambda url: privacy.remote_exclusion(self.repo, url)  # noqa: E731
        self.assertEqual(exclusion('file://' + str(self.remote)), ['--remotes=origin'])
        self.assertEqual(exclusion(str(self.remote) + '/'), ['--remotes=origin'])
        git(self.repo, 'remote', 'set-url', 'origin', 'https://github.com/example-owner/app')
        for url in ('https://github.com/Example-Owner/App.git',
                    'https://github.com/example-owner/app/',
                    'git@github.com:Example-Owner/App.git',
                    'ssh://git@github.com/example-owner/app.git',
                    'https://GitHub.com/example-owner/app'):
            self.assertEqual(exclusion(url), ['--remotes=origin'], url)
        for url in ('https://github.com/example-owner/app-two',
                    'https://github.com/other-owner/app',
                    'https://gitlab.com/example-owner/app'):
            self.assertEqual(exclusion(url), [], url)


class CiTests(unittest.TestCase):
    """The CI mode: a public log, secrets that forks and Dependabot never get."""

    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.repo = repository(self.folder)

    def environ(self, event, words=(NAME,), actor='owner', name='pull_request'):
        path = self.folder / 'event.json'
        path.write_text(json.dumps(event))
        environ = listed(*words)
        environ.update(GITHUB_EVENT_NAME=name, GITHUB_EVENT_PATH=str(path),
                       GITHUB_REPOSITORY='o/r', GITHUB_ACTOR=actor)
        return environ

    def request(self, head='o/r', title='Add a check', body='Body', ref='claude/x'):
        return {'pull_request': {'title': title, 'body': body,
                                 'head': {'ref': ref, 'repo': {'full_name': head}}}}

    def test_secrets_are_expected_except_for_forks_and_dependabot(self):
        self.assertTrue(privacy.ci_gets_secrets(self.environ(self.request())))
        self.assertFalse(privacy.ci_gets_secrets(self.environ(self.request(head='f/r'))))
        self.assertFalse(privacy.ci_gets_secrets(self.environ(self.request(),
                                                              actor='dependabot[bot]')))
        # The owner's push to a Dependabot branch is the owner's run.
        self.assertTrue(privacy.ci_gets_secrets(self.environ(self.request(ref='dependabot/x'))))
        self.assertTrue(privacy.ci_gets_secrets(self.environ({'ref': 'refs/heads/main'},
                                                             name='push')))

    def test_a_missing_list_fails_where_secrets_are_given(self):
        status, _, err = run(['--ci', str(self.repo)], self.environ(self.request(), words=()))
        self.assertEqual(status, 2)
        self.assertIn('::error::', err)
        status, out, _ = run(['--ci', str(self.repo)],
                             self.environ(self.request(head='f/r'), words=()))
        self.assertEqual(status, 0)
        self.assertIn('::warning::', out)

    def test_ci_prints_counts_only_and_reads_the_pull_request(self):
        (self.repo / 'notes.md').write_text(f'{NAME}\n{ADDRESS}\n')
        git(self.repo, 'add', 'notes.md')
        git(self.repo, 'commit', '-q', '-m', 'Notes')
        event = self.request(title=f'For {NAME}', body=f'Ask {ADDRESS}',
                             ref=f'claude/{NAME.split()[0].lower()}-{NAME.split()[1].lower()}')
        status, out, err = run(['--ci', str(self.repo)], self.environ(event))
        self.assertEqual(status, 1)
        self.assertIn('::error::Found ', out)
        sha = git(self.repo, 'rev-parse', '--short', 'HEAD').strip()
        for hidden in ('notes.md', sha, ':1:', 'title'):
            self.assertNotIn(hidden, out + err)
        for secret in SECRETS:
            self.assertNotIn(secret, out + err)
        counts = out.split('::error::Found ')[1].split(' in ')[0]
        # The file, the commit's change, the title and the branch name.
        self.assertIn('4 × ' + privacy.KIND_PRIVATE, counts)

    def test_a_push_of_one_commit_reads_that_commit_alone(self):
        # An older merge made a change while merging that a later commit
        # undid; a push of that later commit does not read the merge again.
        git(self.repo, 'checkout', '-q', '-b', 'side')
        (self.repo / 'side.md').write_text('Side.\n')
        git(self.repo, 'add', 'side.md')
        git(self.repo, 'commit', '-q', '-m', 'Side')
        git(self.repo, 'checkout', '-q', 'main')
        (self.repo / 'main.md').write_text('Main.\n')
        git(self.repo, 'add', 'main.md')
        git(self.repo, 'commit', '-q', '-m', 'Main')
        git(self.repo, 'merge', '-q', '--no-commit', 'side')
        (self.repo / 'merged.md').write_text(f'{NAME}\n')
        git(self.repo, 'add', 'merged.md')
        git(self.repo, 'commit', '-q', '-m', 'Merge side')
        environ = self.environ({'ref': 'refs/heads/main'}, name='push')
        self.assertEqual(run(['--ci', str(self.repo)], environ)[0], 1)
        git(self.repo, 'rm', '-q', 'merged.md')
        git(self.repo, 'commit', '-q', '-m', 'Remove')
        status, out, _ = run(['--ci', str(self.repo)], environ)
        self.assertEqual(status, 0, out)
        self.assertIn('1 commit', out)

    def test_the_list_may_come_in_base64(self):
        encoded = 'base64:' + base64.b64encode(f'{NAME}\n'.encode()).decode()
        environ = self.environ(self.request(title=f'For {NAME}'), words=())
        environ[privacy.LIST_VARIABLE] = encoded
        self.assertEqual(run(['--ci', str(self.repo)], environ)[0], 1)

    def test_an_unexpected_failure_prints_its_type_only(self):
        with mock.patch.object(privacy, 'tracked_files',
                               side_effect=ValueError(f'could not read {NAME}')):
            status, out, err = run(['--ci', str(self.repo)], self.environ(self.request()))
        self.assertEqual(status, 2)
        self.assertIn('::error::privacy check failed (ValueError).', err)
        self.assertNotIn('Quillon', out + err)


class RepositoryTests(unittest.TestCase):
    """The repository itself, with whatever list this computer has."""

    def test_no_tracked_file_holds_a_personal_detail(self):
        words = privacy.load_list()[0]
        support, findings = privacy.support_addresses(ROOT)
        findings += privacy.tracked_files(privacy.Checker(words, support), ROOT,
                                          privacy.Tally())
        # Counts only: a log of this test may be public.
        self.assertEqual(findings, [], 'Found ' + privacy.kinds(findings) + ': run python3 '
                         'scripts/privacy-check.py to see where.')

    def test_the_support_page_has_one_address(self):
        addresses, problems = privacy.support_addresses(ROOT)
        self.assertEqual((len(addresses), problems), (1, []))

    def test_the_pre_push_hook_runs_the_check_and_cannot_be_talked_out_of_it(self):
        self.assertTrue(os.access(HOOK, os.X_OK), 'the hook must be executable')
        text = HOOK.read_text()
        self.assertIn('exec python3 scripts/privacy-check.py --pre-push "$1"', text)
        for weakened in ('|| true', '--no-list', 'exit 0'):
            self.assertNotIn(weakened, text)

    def test_nothing_in_the_repository_is_a_list_or_bytecode(self):
        tracked = subprocess.run(['git', '-C', str(ROOT), 'ls-files'], capture_output=True,
                                 text=True, check=True).stdout.split()
        self.assertFalse([path for path in tracked if path.endswith('private-words.txt')
                          or '__pycache__' in path or path.endswith('.pyc')])
        self.assertIn('__pycache__/', (ROOT / '.gitignore').read_text().split())


# ------------------------------------- what text and files hide, reviewed
#
# The classes below come from a review of what the check finds in text and
# files (2026-11-07). Each test plants a detail written the way a person or
# a program really writes it, so a check that stops reading that way fails.

import time  # noqa: E402 - only the tests below need these two
import zipfile  # noqa: E402

# A mixed-case address, as people type them; this file holds it only in parts.
MIXED_ADDRESS = 'Quill.Vass' + AT + 'gmail' + '.com'


def pdf_object(number, dictionary, stream=None):
    if stream is None:
        return b'%d 0 obj\n%s\nendobj\n' % (number, dictionary)
    return b'%d 0 obj\n%s\nstream\n%s\nendstream\nendobj\n' % (number, dictionary, stream)


def pdf_file(*objects):
    return (b'%PDF-1.7\n%\xe2\xe3\xcf\xd3\n' + b''.join(objects)
            + b'trailer\n<< /Root 1 0 R >>\n%%EOF\n')


def to_unicode(pairs, ranges=b''):
    """A ToUnicode CMap mapping two-byte codes to text one by one, plus
    any bfrange sections given."""
    chars = b''.join(b'<%04X> <%s>\n' % (code, text.encode('utf-16-be').hex().encode())
                     for code, text in pairs)
    return (b'/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n'
            b'1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n'
            + b'%d beginbfchar\n' % len(pairs) + chars + b'endbfchar\n' + ranges
            + b'endcmap\nend\nend\n')


def glyph_font(text, array=False):
    """How a subset font writes text: (encode, cmap), where encode gives the
    hex string of glyph codes a page shows and cmap is the ToUnicode CMap
    that maps them back. Small letters come through a range; capitals
    through an array range, or one by one."""
    lower = 'abcdefghijklmnopqrstuvwxyz'
    codes = {char: 0x41 + index for index, char in enumerate(lower)}
    others = sorted(set(text) - set(lower))
    capitals = [char for char in others if char.isupper()] if array else []
    singles = [char for char in others if char not in capitals]
    codes.update({char: 0x300 + index for index, char in enumerate(capitals)})
    codes.update({char: 0x100 + index for index, char in enumerate(singles)})
    ranges = b'<0041> <005A> <0061>\n'
    if capitals:
        ranges += (b'<0300> <%04X> [%s]\n' % (0x300 + len(capitals) - 1, b' '.join(
            b'<%s>' % char.encode('utf-16-be').hex().encode() for char in capitals)))
    cmap = to_unicode([(codes[char], char) for char in singles],
                      b'%d beginbfrange\n' % ranges.count(b'\n') + ranges + b'endbfrange\n')
    return (lambda shown: b'<' + ''.join('%04X' % codes[c] for c in shown).encode() + b'>'), cmap


def page_pdf(content, cmap=None, extra=()):
    """A one-page PDF whose page shows content with font F1: a subset font
    with the ToUnicode cmap when one is given, otherwise a plain one."""
    font = (b'<< /Type /Font /Subtype /Type0 /BaseFont /QXYZAB+Sans /Encoding /Identity-H '
            b'/ToUnicode 6 0 R >>' if cmap else
            b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    objects = [pdf_object(1, b'<< /Type /Catalog /Pages 2 0 R >>'),
               pdf_object(2, b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
               pdf_object(3, b'<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R '
                             b'>> >> /Contents 4 0 R >>'),
               pdf_object(4, b'<< /Filter /FlateDecode >>', zlib.compress(content)),
               pdf_object(5, font)]
    if cmap:
        objects.append(pdf_object(6, b'<< /Filter /FlateDecode >>', zlib.compress(cmap)))
    return pdf_file(*objects, *extra)


def pdf_without_a_zero_byte():
    """A PDF whose compressed page holds NAME and which has no zero byte,
    so git takes it for text. Most page streams of a few hundred bytes
    compress without one."""
    words = [b'the', b'phrase', b'speaks', b'switch', b'dwell', b'voice', b'tile', b'home']
    for seed in range(100):
        filler = b' '.join(random.Random(seed).choices(words, k=60))
        data = page_pdf(b'BT /F1 12 Tf (With thanks, %s) Tj ET %% %s' % (NAME.encode(), filler))
        if b'\0' not in data:
            return data
    raise AssertionError('no PDF without a zero byte was made')


def zip_archive(*entries, method=zipfile.ZIP_DEFLATED):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', method) as archive:
        for name, content in entries:
            archive.writestr(name, content)
    return buffer.getvalue()


def gif_blocks(data):
    return b''.join(bytes([len(data[i:i + 255])]) + data[i:i + 255]
                    for i in range(0, len(data), 255)) + b'\0'


def gif_file(*extensions):
    """A 1x1 GIF89a with a two-colour table and the extensions given."""
    return (b'GIF89a' + struct.pack('<HHBBB', 1, 1, 0x80, 0, 0) + b'\0\0\0\xff\xff\xff'
            + b''.join(extensions)
            + b',' + struct.pack('<HHHHB', 0, 0, 1, 1, 0) + b'\x02\x02\x44\x01\x00' + b';')


def syncsafe(number):
    return bytes([(number >> 21) & 0x7f, (number >> 14) & 0x7f, (number >> 7) & 0x7f,
                  number & 0x7f])


def id3_frame(kind, payload, version=3):
    if version == 2:
        return kind + len(payload).to_bytes(3, 'big') + payload
    size = syncsafe(len(payload)) if version == 4 else struct.pack('>I', len(payload))
    return kind + size + b'\0\0' + payload


def mp3_file(*frames, version=3, tail=b''):
    """An MP3: an ID3v2 tag holding frames, then padding, sound and tail."""
    body = b''.join(frames) + bytes(64)
    return (b'ID3' + bytes([version, 0, 0]) + syncsafe(len(body)) + body
            + b'\xff\xfb\x90\x00' + bytes(400) + tail)


def id3v1(artist):
    return (b'TAG' + b'Song'.ljust(30, b'\0') + artist.encode('latin-1').ljust(30, b'\0')
            + bytes(30) + b'2026' + bytes(30) + b'\x0c')


def located_jpeg():
    return jpeg(jpeg_segment(0xE1, b'Exif\0\0' + tiff(latitude=40)))


class FoldingTests(unittest.TestCase):
    """An accented name written plainly, or plainly listed and written with
    accents: dropping either direction, or a signature's, fails."""

    def test_an_accented_entry_is_found_written_without_accents(self):
        check = checker('Jos\u00e9 Quillon')
        for text in ['Thanks to Jose Quillon for testing.',
                     'Thanks to Jose Quillon \u2014 for testing.',
                     'first line\nJOSE QUILLON']:
            with self.subTest(text=text):
                found = check.text(text, 'x')
                self.assertEqual(kinds(found), [privacy.KIND_PRIVATE])
        self.assertEqual(check.text('first line\nJOSE QUILLON', 'x')[0].line, 2)
        self.assertEqual(kinds(check.data(b'Thanks Jose Quillon\n', 'x', 'x')),
                         [privacy.KIND_PRIVATE])

    def test_a_signature_is_read_with_and_without_accents(self):
        self.assertEqual(kinds(checker(NAME).identity('Quillon Vassm\u00e9re',
                                                      'q' + AT + 'example.com', 'c')),
                         [privacy.KIND_PRIVATE])
        self.assertEqual(kinds(checker('Jos\u00e9 Quillon').identity(
            'Jose Quillon', 'q' + AT + 'example.com', 'c')), [privacy.KIND_PRIVATE])
        self.assertEqual(kinds(checker(NAME).identity('Someone', 'quillon.vassm%C3%A9re'
                                                      + AT + 'example.com', 'c')),
                         [privacy.KIND_PRIVATE])
        self.assertEqual(checker(NAME).identity('Quillon Vassmerey', 'q' + AT + 'example.com',
                                                'c'), [])


class PhoneWritingTests(unittest.TestCase):
    """Phone numbers as people write them: at the end of a sentence, with
    pasted spaces and dashes, with an extension. Narrowing one of these, or
    finding a version, date or build number, fails."""

    def test_a_number_written_in_everyday_ways_is_found(self):
        # Split so this file holds no number the checker finds.
        for text in ['Call me at 212-867-' '0142.', 'Phone: 212-867-' '0142.\n',
                     'Call (212) 867-' '0142.', 'Tel 212.867.' '0142.', 'Call 212 867 ' '0142.',
                     'Call 212-867-' '0142x12', 'Call 212-867-' '0142 ext. 12',
                     'Call 212-867-' '0142 X 7', 'Call 212\u00a0867\u00a0' '0142 now',
                     'Call 212\u202f867\u202f' '0142 now', 'Call 212\u2013867\u2013' '0142',
                     'Call 212\u2011867\u2011' '0142', 'Call 212\u2010867\u2010' '0142',
                     'Call (212)\u00a0867-' '0142', 'Call +1\u00a0212\u00a0867\u00a0' '0142.',
                     'Call +44\u00a020\u00a0' '7946\u00a0' '0142.', 'Call +44 20 ' '7946 0142x9',
                     '"212-867-' '0142".', '(212-867-' '0142)',
                     'Call me at 212-867-' '0142\u2014I am usually home.',
                     'Call (212) 867-' '0142\u2014any time', 'Phone 212-867-' '0142\u2013evenings',
                     'Call +1 (212) 867-' '0142\u2014call', '\u2014212-867-' '0142',
                     'Call me\u2014212-867-' '0142', 'Call 212-867-' '0142--any time',
                     'Call +44 20 ' '7946 ' '0142\u2014evenings']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_PHONE])

    # Finding a phone link's number only when it has the separators or the
    # + that numbers in prose need fails this.
    def test_a_phone_link_s_number_is_found_however_it_is_written(self):
        # Split after the link's name, so this file holds no number the
        # checker finds.
        for text in ['<a href="tel:' '2128670142">', 'tel:' '8670142', 'TEL:' '(212)8670142',
                     'sms:' '2128670142', 'callto:' '2128670142', 'facetime:' '2128670142',
                     'facetime-audio:' '//2128670142', 'tel:' '//212.867.' '0142']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_PHONE])

    def test_versions_dates_ids_and_fiction_numbers_are_still_left_alone(self):
        for text in ['tel:5550100', 'tel:' '+15558670142', 'tel:555-0142', 'tel:911',
                     'hotel:' '2128670142', 'sms:12', '212-867-' '0142.5', 'v1.212.867.' '0142',
                     'build 212.867.' '0142.7',
                     '10.212.867.' '0142', 'id 212-867-' '0142-7', 'id 212\u2013867\u2013'
                     '0142\u20137', 'x212-867-' '0142', '2026\u201311\u201306',
                     'IP 192.168.100.1', '212-867-' '01425.', '(555) 867-' '0142 x12',
                     '(212) 555-' '0142 ext. 9', '555-0100.', 'id=212-867-' '0142x',
                     'v212\u2011867\u2011' '0142', '212-867-' '0142.txt',
                     'id-212-867-' '0142', '212-867-' '0142-id', '7-212-867-' '0142',
                     '212-867-' '0142\u20137']:
            with self.subTest(text=text):
                self.assertEqual(checker().text(text, 'x'), [])


class PdfTests(unittest.TestCase):
    """What a PDF shows on its pages and keeps in its information: a PDF
    that reads as text, glyph codes, hex and UTF-16 strings, object streams.
    Dropping one of these fails."""

    def found(self, data, words=NAME):
        return sorted(set(kinds(checker(words).data(data, 'x', 'x'))))

    def test_a_pdf_without_a_zero_byte_is_still_read_as_a_pdf(self):
        data = pdf_without_a_zero_byte()
        self.assertNotIn(b'\0', data)
        self.assertEqual(self.found(data), [privacy.KIND_PRIVATE])

    def test_information_in_hex_and_utf16_strings_is_read(self):
        utf16 = b'\xfe\xff' + NAME.encode('utf-16-be')
        octal = b''.join(b'\\%03o' % byte for byte in utf16)
        for author in [b'<' + utf16.hex().upper().encode() + b'>', b'(' + octal + b')',
                       b'(Quil\\\nlon \\(Vassmere\\))', b'<' + NAME.encode().hex().encode() + b'>']:
            with self.subTest(author=author[:12]):
                data = page_pdf(b'BT ET', extra=[pdf_object(7, b'<< /Author ' + author + b' >>')])
                self.assertEqual(self.found(data), [privacy.KIND_PRIVATE])

    def test_glyph_codes_are_read_through_the_font_s_to_unicode_map(self):
        for array in (False, True):
            encode, cmap = glyph_font(f'With thanks, {NAME}', array=array)
            content = b'BT /F1 12 Tf ' + encode(f'With thanks, {NAME}') + b' Tj ET'
            with self.subTest(array=array):
                self.assertEqual(self.found(page_pdf(content, cmap)), [privacy.KIND_PRIVATE])
        # Shown a word at a time, or with kerning between letters.
        encode, cmap = glyph_font(NAME)
        content = (b'BT /F1 12 Tf ' + encode('Quil') + b' Tj ' + encode('lon') + b' Tj 5 0 Td '
                   + b'[' + encode('Vass') + b' 12 ' + encode('mere') + b'] TJ ET')
        self.assertEqual(self.found(page_pdf(content, cmap)), [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(page_pdf(b'BT /F1 12 Tf ' + encode('Quillon') + b' Tj ET',
                                             cmap)), [])

    def test_a_page_s_kerned_text_and_its_phone_and_email_are_read(self):
        data = page_pdf(b'BT /F1 12 Tf [(Quil) 20 (lon) -300 (Vass) 15 (mere)] TJ ET')
        self.assertEqual(self.found(data), [privacy.KIND_PRIVATE])
        data = page_pdf(b'BT /F1 12 Tf (Call \\(212\\) 867-' b'0142 or '
                        + MIXED_ADDRESS.encode() + b') Tj ET')
        self.assertEqual(self.found(data, words=NICK),
                         sorted([privacy.KIND_EMAIL, privacy.KIND_PHONE]))

    def test_fonts_and_pages_kept_in_an_object_stream_and_pages_sharing_a_name(self):
        first, first_map = glyph_font('Quillon')
        second, second_map = glyph_font('Vassmere, Tobble')
        inner = [(3, b'<< /Type /Page /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'),
                 (5, b'<< /Type /Font /Subtype /Type0 /ToUnicode 6 0 R >>'),
                 (13, b'<< /Type /Page /Resources << /Font 14 0 R >> /Contents 10 0 R >>'),
                 (14, b'<< /F1 15 0 R >>'),
                 (15, b'<< /Type /Font /Subtype /Type0 /ToUnicode 16 0 R >>')]
        offsets, body = [], b''
        for number, text in inner:
            offsets.append(b'%d %d' % (number, len(body)))
            body += text + b'\n'
        header = b' '.join(offsets) + b'\n'
        stream = zlib.compress(header + body)
        data = pdf_file(
            pdf_object(20, b'<< /Type /ObjStm /N 5 /First %d /Filter /FlateDecode >>'
                       % len(header), stream),
            pdf_object(4, b'<< /Filter /FlateDecode >>',
                       zlib.compress(b'BT /F1 9 Tf ' + first('Quillon') + b' Tj ET')),
            pdf_object(6, b'<< /Filter /FlateDecode >>', zlib.compress(first_map)),
            pdf_object(10, b'<< /Filter /FlateDecode >>',
                       zlib.compress(b'BT /F1 9 Tf ' + second('Tobble') + b' Tj ET')),
            pdf_object(16, b'<< /Filter /FlateDecode >>', zlib.compress(second_map)))
        self.assertEqual(self.found(data, words='Quillon'), [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(data, words=NICK), [privacy.KIND_PRIVATE])

    def test_an_attached_file_and_compressed_metadata_are_read(self):
        attached = pdf_object(8, b'<< /Type /EmbeddedFile /Filter /FlateDecode >>',
                              zlib.compress(f'notes by {NAME}\n'.encode()))
        self.assertEqual(self.found(page_pdf(b'BT ET', extra=[attached])), [privacy.KIND_PRIVATE])
        xmp = (b'<x:xmpmeta><rdf:Description exif:GPSLatitude="40,26.7N" '
               b'exif:GPSLongitude="79,58.9W"/></x:xmpmeta>')
        metadata = pdf_object(9, b'<< /Type /Metadata /Filter /FlateDecode >>',
                              zlib.compress(xmp))
        self.assertEqual(self.found(page_pdf(b'BT ET', extra=[metadata])), [privacy.KIND_PLACE])

    def test_numbers_that_place_text_on_a_page_are_not_phone_numbers(self):
        # Split so this file holds no number the checker finds.
        data = page_pdf(b'q 100 200 ' b'1000 50 re f Q BT /F1 12 Tf 212 867 Td (Hello) Tj ET '
                        b'0 0 612 792 ' b'1234 5678 cm')
        self.assertEqual(self.found(data), [])


class ArchiveTests(unittest.TestCase):
    """ZIP archives, which Word, Excel, Pages and Keynote files are: their
    entries' names and content. Not inflating them, or reading tag names
    as words, fails."""

    def found(self, data, words=NAME):
        return sorted(set(kinds(checker(words).data(data, 'x', 'x'))))

    def document(self, text, method=zipfile.ZIP_DEFLATED):
        return zip_archive(('[Content_Types].xml', '<?xml version="1.0"?><Types/>'),
                           ('word/document.xml', '<?xml version="1.0"?><w:document><w:body>'
                            f'<w:p><w:r><w:t>{text}</w:t></w:r></w:p></w:body></w:document>'),
                           method=method)

    def test_a_word_document_s_text_and_author_are_read(self):
        split = 'Thanks to Quil</w:t></w:r><w:r w:rsidR="00A1"><w:t>lon Vassmere.'
        for method in (zipfile.ZIP_DEFLATED, zipfile.ZIP_STORED):
            with self.subTest(method=method):
                self.assertEqual(self.found(self.document(split, method)),
                                 [privacy.KIND_PRIVATE])
        core = zip_archive(('docProps/core.xml', '<cp:coreProperties><dc:creator>'
                            f'{NAME}</dc:creator></cp:coreProperties>'))
        self.assertEqual(self.found(core), [privacy.KIND_PRIVATE])
        text = f'Call 212-867-' f'0142 or {MIXED_ADDRESS}'
        self.assertEqual(self.found(self.document(text), words=NICK),
                         sorted([privacy.KIND_EMAIL, privacy.KIND_PHONE]))

    def test_entry_names_nested_archives_and_pictures_are_read(self):
        self.assertEqual(self.found(zip_archive(('media/tobble.txt', 'x')), words=NICK),
                         [privacy.KIND_PRIVATE])
        inner = zip_archive(('notes.txt', f'by {NAME}'))
        self.assertEqual(self.found(zip_archive(('a.zip', zip_archive(('b.zip', inner)))))
                         , [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(zip_archive(('word/media/image1.jpg', located_jpeg()))),
                         [privacy.KIND_PLACE])

    def test_markup_is_not_a_word_and_a_damaged_archive_does_not_stop_the_check(self):
        words = 'Li\nAnn\nKai\nAlt\nLang'
        xml = ('<?xml version="1.0"?><x:xmpmeta><rdf:Alt><rdf:li xml:lang="x-default">'
               'Screenshot</rdf:li></rdf:Alt></x:xmpmeta>')
        self.assertEqual(self.found(zip_archive(('_rels/.rels', xml), ('a.xml', xml)),
                                    words=words), [])
        broken = self.document(NAME)
        self.assertEqual(self.found(broken[:len(broken) // 2]), [])
        self.assertEqual(self.found(broken[:len(broken) // 2], words=NICK), [])

    def test_an_archive_is_inflated_only_up_to_the_limit(self):
        archive = zip_archive(('a.txt', 'x' * 5000), (f'{NICK}.txt', f'by {NAME}'))
        with mock.patch.object(privacy, 'HIDDEN_LIMIT', 1000):
            self.assertEqual(self.found(archive, words=NAME), [])
            self.assertEqual(self.found(archive, words=NICK), [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(archive, words=NAME), [privacy.KIND_PRIVATE])


class ExactFieldTests(unittest.TestCase):
    """Fields a file's format defines (PNG text, GIF comments, MP3 and MP4
    tags) are read exactly, with every rule text gets, and with no
    minimum length; bytes only guessed at keep the stricter rules."""

    def found(self, data, words=NAME):
        return sorted(set(kinds(checker(words).data(data, 'x', 'x'))))

    def test_a_png_s_text_is_read_for_phones_and_mixed_case_addresses(self):
        chunk = png_chunk(b'tEXt', f'Comment\0Call 212-867-' f'0142 or {MIXED_ADDRESS}'.encode())
        self.assertEqual(self.found(png(chunk), words=NICK),
                         sorted([privacy.KIND_EMAIL, privacy.KIND_PHONE]))

    def test_guessed_runs_keep_the_binary_rules(self):
        data = b'\0\x01' + f'call 212-867-' f'0142 or {MIXED_ADDRESS} now'.encode() + b'\0'
        self.assertEqual(self.found(data, words=NICK), [])

    def test_compressed_xmp_in_a_png_is_read_for_a_location(self):
        xmp = (b'<x:xmpmeta><rdf:Description exif:GPSLatitude="40,26.7N" '
               b'exif:GPSLongitude="79,58.9W"/></x:xmpmeta>')
        chunk = png_chunk(b'iTXt', b'XML:com.adobe.xmp\0\x01\0\0\0' + zlib.compress(xmp))
        self.assertEqual(self.found(png(chunk)), [privacy.KIND_PLACE])

    def test_a_gif_s_comment_and_plain_text_are_read(self):
        self.assertEqual(self.found(gif_file(b'!\xfe' + gif_blocks(b'Photo of Tobble')),
                                    words=NICK), [privacy.KIND_PRIVATE])
        long = b'x' * 250 + b' ' + NAME.encode()  # the name crosses a sub-block
        self.assertEqual(self.found(gif_file(b'!\xfe' + gif_blocks(long))),
                         [privacy.KIND_PRIVATE])
        plain = b'!\x01\x0c' + bytes(12) + gif_blocks(b'Tobble')
        self.assertEqual(self.found(gif_file(plain), words=NICK), [privacy.KIND_PRIVATE])
        self.assertEqual(self.found(gif_file(), words=NICK), [])

    def test_an_mp3_s_tags_are_read_however_short(self):
        latin = id3_frame(b'TPE1', b'\0' + NICK.encode())
        utf8 = id3_frame(b'TIT2', b'\x03' + NICK.encode(), version=4)
        utf16 = id3_frame(b'COMM', b'\x01eng' + '\ufeff\0\ufeffBy Tobble'.encode('utf-16-le'))
        old = id3_frame(b'TP1', b'\0' + NICK.encode(), version=2)
        for data in [mp3_file(latin), mp3_file(utf8, version=4), mp3_file(utf16),
                     mp3_file(old, version=2), b'\xff\xfb\x90\x00' + bytes(400) + id3v1(NICK)]:
            with self.subTest(data=data[:4]):
                self.assertEqual(self.found(data, words=NICK), [privacy.KIND_PRIVATE])
        picture = id3_frame(b'APIC', b'\0image/jpeg\0\x03\0' + located_jpeg())
        self.assertEqual(self.found(mp3_file(picture), words=NICK), [privacy.KIND_PLACE])

    def test_an_mp4_s_tags_are_read_however_short(self):
        value = atom(b'data', struct.pack('>II', 1, 0) + NICK.encode())
        itunes = atom(b'meta', b'\0\0\0\0' + atom(b'hdlr', bytes(25))
                      + atom(b'ilst', atom(b'\xa9ART', value)))
        quicktime = atom(b'\xa9nam', struct.pack('>HH', len(NICK), 0x55c4) + NICK.encode())
        location = atom(b'data', struct.pack('>II', 1, 0) + b'+40.7128' b'-074.0060+010.000/')
        keyed = atom(b'meta', atom(b'hdlr', bytes(25))
                     + atom(b'keys', b'\0\0\0\0\0\0\0\x02'
                            + atom(b'mdta', b'com.apple.quicktime.author')
                            + atom(b'mdta', b'com.apple.quicktime.place'))
                     + atom(b'ilst', atom(b'\0\0\0\x01', value) + atom(b'\0\0\0\x02', location)))
        for moov in [atom(b'udta', itunes), atom(b'udta', quicktime), keyed]:
            data = (atom(b'ftyp', b'M4A \0\0\0\0M4A isom') + atom(b'moov', moov)
                    + atom(b'mdat', bytes(64)))
            with self.subTest(moov=moov[4:8]):
                found = self.found(data, words=NICK)
                self.assertIn(privacy.KIND_PRIVATE, found)
                self.assertNotIn(privacy.KIND_PHONE, found)
        self.assertIn(privacy.KIND_PLACE, found)


class TextEncodingTests(unittest.TestCase):
    """Text files in encodings other than UTF-8: UTF-16 without a byte order
    mark, and Windows' Latin. Reading them as binary, or as broken UTF-8,
    fails."""

    def test_utf16_without_a_byte_order_mark_is_read_as_text(self):
        text = (f'Contacts\r\nQuillon\r\nVassmere\r\nPhone (212) 867-' f'0142\r\n'
                f'Mail {MIXED_ADDRESS}\r\n')
        for codec in ('utf-16-le', 'utf-16-be'):
            with self.subTest(codec=codec):
                found = checker(NAME).data(text.encode(codec), 'x', 'x')
                self.assertEqual(sorted(set(kinds(found))), sorted(
                    [privacy.KIND_EMAIL, privacy.KIND_PHONE, privacy.KIND_PRIVATE]))
                self.assertEqual([f.line for f in found if f.kind == privacy.KIND_PRIVATE], [2])
        numbers = struct.pack('<200H', *range(1, 201))
        self.assertEqual(checker(NAME).data(numbers, 'x', 'x'), [])
        control = f'Call 212-867-' f'0142 or {MIXED_ADDRESS}\x01 end'.encode('utf-16-le')
        self.assertEqual(checker(NICK).data(control, 'x', 'x'), [])

    def test_windows_latin_text_is_read_with_its_accents(self):
        check = checker('Jos\u00e9 Quillon')
        for data in ['Thanks to Jos\u00e9 Quillon\n'.encode('latin-1'),
                     'Thanks to Jos\u00e9 Quillon \u2019\n'.encode('cp1252'),
                     b'ok \xff\n' + 'Jos\u00e9 Quillon\n'.encode('utf-8')]:
            with self.subTest(data=data[:6]):
                self.assertEqual(kinds(check.data(data, 'x', 'x')), [privacy.KIND_PRIVATE])
        self.assertEqual(len(check.data('Thanks to Jos\u00e9 Quillon\n'.encode(), 'x', 'x')), 1)


class MarkupTests(unittest.TestCase):
    """A name split by tags or a link renders whole: finding it only when
    written plainly fails, and so does reporting it on another line."""

    def test_a_name_split_by_markup_is_found_on_its_line(self):
        check = checker(NAME)
        for text in ['<p>Thanks to <b>Quillon</b> Vassmere</p>',
                     'Thanks to [Quillon](https://example.com) Vassmere',
                     'Thanks to [Quillon][1] Vassmere',
                     '<span class="given">Quillon</span> <span class="family">Vassmere</span>',
                     '<text><tspan>Quillon</tspan><tspan x="10">Vassmere</tspan></text>',
                     '<td>Quil<!-- x -->lon</td> <td>Vass<span\nclass="x">mere</span></td>']:
            with self.subTest(text=text):
                found = check.text('first line\n' + text, 'x')
                self.assertEqual([(f.line, f.kind) for f in found], [(2, privacy.KIND_PRIVATE)])
        svg = ('<svg>\n<text><tspan>Quillon</tspan><tspan x="10">Vassmere</tspan></text>\n'
               '</svg>\n').encode()
        self.assertEqual([(f.line, f.kind) for f in check.data(svg, 'x.svg', 'design/x.svg')],
                         [(2, privacy.KIND_PRIVATE)])

    def test_text_that_only_looks_like_markup_is_not_joined(self):
        check = checker(NICK)
        self.assertEqual(check.text('if a < b and tob > ble', 'x'), [])
        self.assertEqual(check.text('a <b>tob</b> ble', 'x'), [])
        self.assertEqual(check.text('Tob<5 and x>ble', 'x'), [])
        self.assertEqual(kinds(check.text('Tob<b>ble', 'x')), [privacy.KIND_PRIVATE])


class EmbeddedTests(unittest.TestCase):
    """Pictures and files written into text as base64 data: URIs. Not
    decoding them, or reporting on a line they are not on, fails."""

    def test_a_picture_in_a_data_uri_is_read(self):
        picture = base64.b64encode(png(png_chunk(b'tEXt', b'Author\0' + NAME.encode()))).decode()
        svg = f'<svg>\n<image href="data:image/png;base64,{picture}"/>\n</svg>\n'
        found = checker(NAME).data(svg.encode(), 'x.svg', 'design/x.svg')
        self.assertEqual([(f.line, f.kind) for f in found], [(2, privacy.KIND_PRIVATE)])
        photo = base64.encodebytes(located_jpeg()).decode()  # wrapped every 76 characters
        html_text = f'<p>Hi</p>\n<img src="data:image/jpeg;base64,\n{photo}">\n'
        found = checker(NAME).text(html_text, 'site/x.html', 'site/x.html', start_line=10)
        self.assertEqual([(f.line, f.kind) for f in found], [(11, privacy.KIND_PLACE)])
        self.assertEqual(checker(NAME).text('data:image/png;base64,!!!!', 'x'), [])


class PatternEdgeTests(unittest.TestCase):
    """Edges of the built-in patterns and of words: an address in Markdown
    emphasis, a home folder after a compiler flag, a word after an acronym."""

    def test_an_address_in_underscore_emphasis_is_found(self):
        for text in [f'Write to _{ADDRESS}_ please', f'__{ADDRESS}__', f'*_{MIXED_ADDRESS}_*']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_EMAIL])
        found = checker().text('snake_case_name' + AT + 'gmail' + '.com', 'x')
        self.assertEqual([(f.column, f.kind) for f in found], [(1, privacy.KIND_EMAIL)])

    def test_a_home_folder_after_a_flag_or_on_the_data_volume_is_found(self):
        for text in [f'clang -I{HOME_PATH}/include -c a.c', f'ld -F{HOME_PATH}/Frameworks',
                     f'-L/home/{HOME_NAME}/lib', f'open /System/Volumes/Data{HOME_PATH}',
                     f'CFLAGS=-I{HOME_PATH}']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_HOME])
        for text in ['a/Users/x', 'x-I/Users/x', '-I/Users/you/include',
                     '/System/Volumes/Data/Users/Shared']:
            with self.subTest(text=text):
                self.assertEqual(checker().text(text, 'x'), [])

    def test_a_listed_word_after_an_acronym_is_found(self):
        check = checker(NICK)
        for text in ['AACTobble phrases', 'PDFTobble.pdf']:
            with self.subTest(text=text):
                self.assertEqual(kinds(check.text(text, 'x')), [privacy.KIND_PRIVATE])
        self.assertEqual(check.name_kinds('docs/PDFTobble.pdf'),
                         [privacy.KIND_PRIVATE + privacy.IN_NAME])
        for text in ['XTOBBLE', 'ABCTOBBLES', 'AACTobblers']:
            with self.subTest(text=text):
                self.assertEqual(check.text(text, 'x'), [])


class CraftedFileTests(unittest.TestCase):
    """Files made to stall the check: unclosed XMP packets and PDF streams,
    long words in XML, an Exif block that repeats one long string. Each is
    read in time that grows with its size, not with its square."""

    def test_crafted_files_are_read_in_linear_time(self):
        cases = [(lambda: checker(NAME).data(b'\0' + b'<x:xmpmeta' * 50_000, 'x', 'x')),
                 (lambda: checker(NAME).data(b'%PDF-1.4\0' + b'stream\n' * 50_000, 'x', 'x')),
                 (lambda: checker(NAME).data(b'%PDF-1.4\n' + b'1 0 obj stream\n' * 50_000,
                                             'x', 'x')),
                 (lambda: checker(NAME).data(b'%PDF-1.4\n' + b'1 0 obj (' * 50_000, 'x', 'x')),
                 (lambda: privacy.without_markup('a' * 100_000)),
                 (lambda: checker().text('a_' * 150_000, 'x'))]
        for number, case in enumerate(cases):
            with self.subTest(case=number):
                start = time.monotonic()
                case()
                self.assertLess(time.monotonic() - start, 10)

    def test_an_exif_block_cannot_repeat_one_string_without_limit(self):
        value = b'x' * 100_000 + b'\0'
        count = 300
        start = 8 + 2 + 12 * count + 4
        body = struct.pack('<H', count) + b''.join(
            struct.pack('<HHII', 0x010E, 2, len(value), start) for _ in range(count))
        block = b'II*\0' + struct.pack('<I', 8) + body + struct.pack('<I', 0) + value
        hidden = privacy.binary_texts(block)
        self.assertLess(sum(len(text) for text in hidden.exact), 2 * privacy.EXIF_TEXT_LIMIT)



PHONE_TEXT = 'Call 212-867-' '0142'


def varint(number):
    out = bytearray()
    while True:
        low, number = number & 0x7f, number >> 7
        out.append(low | (0x80 if number else 0))
        if not number:
            return bytes(out)


def proto(number, value):
    """A protocol-buffer field: a whole number, or bytes."""
    if isinstance(value, int):
        return varint(number << 3) + varint(value)
    return varint(number << 3 | 2) + varint(len(value)) + value


def iwa_archive(message):
    """An iWork archive: its info, which gives the message's length, then
    the message."""
    info = proto(1, 1) + proto(2, proto(1, 2001) + proto(3, len(message)))
    return varint(len(info)) + info + message


def snappy_literal(data):
    """Snappy's form of data, written as literals only."""
    return b''.join(bytes([(len(data[i:i + 60]) - 1) << 2]) + data[i:i + 60]
                    for i in range(0, len(data), 60))


def iwa_file(*pieces, length):
    """An .iwa file of one chunk: a zero byte and a three-byte length, then
    Snappy data that inflates to length bytes."""
    data = varint(length) + b''.join(pieces)
    return b'\0' + len(data).to_bytes(3, 'little') + data


def filtered_pdf(content, filters, encode):
    """A one-page PDF whose page content is stored through filters."""
    stream = encode(content)
    return pdf_file(
        pdf_object(1, b'<< /Type /Catalog /Pages 2 0 R >>'),
        pdf_object(2, b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
        pdf_object(3, b'<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 5 0 R >> >> '
                      b'/Contents 4 0 R >>'),
        pdf_object(4, b'<< /Filter %s /Length %d >>' % (filters, len(stream)), stream),
        pdf_object(5, b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'))


def raw_profile(kind, data):
    """A profile as ImageMagick writes it into a PNG's text: its type, its
    length and its bytes in hexadecimal, 36 bytes a line."""
    lines = b'\n'.join(data[i:i + 36].hex().encode() for i in range(0, len(data), 36))
    return b'\n' + kind + b'\n' + b'%8d' % len(data) + b'\n' + lines + b'\n'


def iim(*records):
    """IPTC's records: (dataset of record 2, value)."""
    return b''.join(b'\x1c\x02' + bytes([dataset]) + struct.pack('>H', len(value)) + value
                    for dataset, value in records)


def photoshop_block(data):
    """Photoshop's resource block that carries IPTC (8BIM 0x0404)."""
    return b'8BIM\x04\x04\0\0' + struct.pack('>I', len(data)) + data + b'\0' * (len(data) % 2)


class DocumentFormatTests(unittest.TestCase):
    """Files as the tools people and agents use write them: iWork
    documents, PDFs from reportlab, PNGs from ImageMagick, videos ffmpeg
    remuxed, SVGs Python's XML writers wrapped, RTF from TextEdit, and
    long documents. Not reading what they hold fails."""

    def found(self, data, words=NAME, path='x'):
        return sorted(set(kinds(checker(words).data(data, 'x', path))))

    def test_an_iwork_document_s_text_is_read(self):
        text = f'Thanks {NAME}\n{PHONE_TEXT}'.encode()
        archive = iwa_archive(proto(1, proto(3, text)))
        document = iwa_file(snappy_literal(archive), length=len(archive))
        pages = zip_archive(('Index/Document.iwa', document), method=zipfile.ZIP_STORED)
        self.assertEqual(self.found(pages), sorted([privacy.KIND_PRIVATE, privacy.KIND_PHONE]))
        # A package's own .iwa file, committed as it is.
        self.assertEqual(self.found(document, path='notes.pages/Index/Document.iwa'),
                         sorted([privacy.KIND_PRIVATE, privacy.KIND_PHONE]))
        # Snappy copies earlier bytes: here the name's second word.
        first, last = NAME.split()
        message = proto(3, f'{last}, thanks {first} {last}'.encode())
        archive = iwa_archive(message)
        literal = archive[:-len(last)]
        copy = bytes([((len(last) - 1) << 2) | 2]) + struct.pack('<H', len(first) + len(last) + 10)
        start = -(len(first) + len(last) + 10)
        self.assertEqual(literal[start:start + len(last)].decode(), last)
        document = iwa_file(snappy_literal(literal), copy, length=len(archive))
        pages = zip_archive(('Index/Document.iwa', document), method=zipfile.ZIP_STORED)
        self.assertEqual(self.found(pages), [privacy.KIND_PRIVATE])
        # Damaged chunks stop nothing.
        for broken in (document[:20], b'\0\xff\xff\xff' + bytes(40), b'\0\x05\0\0\x80\x80\x80'):
            with self.subTest(broken=broken[:8]):
                self.found(zip_archive(('Index/Document.iwa', broken)))

    def test_a_pdf_stored_through_a_text_filter_is_read(self):
        content = (b'BT /F1 12 Tf 72 720 Td (Thanks %s) Tj 0 -14 Td (%s) Tj ET'
                   % (NAME.encode(), PHONE_TEXT.encode()))
        expected = sorted([privacy.KIND_PRIVATE, privacy.KIND_PHONE])
        for filters, encode in [
                (b'[ /ASCII85Decode /FlateDecode ]',  # reportlab's own
                 lambda data: base64.a85encode(zlib.compress(data), wrapcol=72) + b'~>'),
                (b'[/AHx /Fl]', lambda data: zlib.compress(data).hex().encode() + b'>'),
                (b'/ASCII85Decode', lambda data: base64.a85encode(data) + b'~>')]:
            with self.subTest(filters=filters):
                self.assertEqual(self.found(filtered_pdf(content, filters, encode)), expected)

    def test_profiles_imagemagick_keeps_in_a_png_are_read(self):
        xmp = ('<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF><rdf:Description>'
               f'<dc:creator>{NAME}</dc:creator><dc:description>{PHONE_TEXT}</dc:description>'
               '<exif:GPSLatitude>40,26.7N</exif:GPSLatitude></rdf:Description></rdf:RDF>'
               '</x:xmpmeta>').encode()
        zipped = png_chunk(b'zTXt', b'Raw profile type xmp\0\0'
                           + zlib.compress(raw_profile(b'xmp', xmp)))
        self.assertEqual(self.found(png(zipped)), sorted(
            [privacy.KIND_PRIVATE, privacy.KIND_PHONE, privacy.KIND_PLACE]))
        records = iim((80, NICK.encode()), (120, PHONE_TEXT.encode()))
        expected = sorted([privacy.KIND_PRIVATE, privacy.KIND_PHONE])
        for chunk in (png_chunk(b'tEXt', b'Raw profile type iptc\0' + raw_profile(b'iptc', records)),
                      png_chunk(b'zTXt', b'Raw profile type 8bim\0\0' + zlib.compress(
                          raw_profile(b'8bim', photoshop_block(records))))):
            with self.subTest(chunk=chunk[4:8]):
                self.assertEqual(self.found(png(chunk), words=NICK), expected)
        # The same IPTC in a JPEG's Photoshop block.
        photo = jpeg(jpeg_segment(0xED, b'Photoshop 3.0\0' + photoshop_block(records)))
        self.assertEqual(self.found(photo, words=NICK), expected)

    def test_a_video_s_3gpp_location_is_read(self):
        def video(longitude, latitude):
            loci = atom(b'loci', b'\0\0\0\0\x15\xc7' + b'Home\0' + b'\0'
                        + struct.pack('>iii', longitude, latitude, 0) + b'earth\0\0')
            return (atom(b'ftyp', b'mp42\0\0\0\0mp42isom') + atom(b'moov', atom(b'udta', loci))
                    + atom(b'mdat', bytes(64)))
        self.assertEqual(self.found(video(-122 * 65536, 37 * 65536)), [privacy.KIND_PLACE])
        self.assertEqual(self.found(video(0, 0)), [])

    def test_a_data_uri_wrapped_with_character_references_is_read_whole(self):
        # Python's XML writers keep a wrapped attribute's line breaks as &#10;.
        picture = jpeg(jpeg_segment(0xFE, b'x' * 120),
                       jpeg_segment(0xE1, b'Exif\0\0' + tiff(latitude=40)))
        wrapped = base64.encodebytes(picture).decode()
        for line_break in ('&#10;', '&#xA;', '&#13;&#10;'):
            href = wrapped.replace('\n', line_break)
            svg = f'<svg>\n<image xlink:href="data:image/jpeg;base64,{href}"/>\n</svg>\n'
            with self.subTest(line_break=line_break):
                found = checker(NAME).data(svg.encode(), 'x.svg', 'design/x.svg')
                self.assertEqual([(f.line, f.kind) for f in found], [(2, privacy.KIND_PLACE)])

    def test_accented_names_in_rtf_are_read(self):
        accented, plain = 'Quillon Vassm\u00e8re', NAME
        for body in (r"Thanks to Quillon Vassm\'e8re.", r"Thanks to Quillon Vassm\u232\'e8re.",
                     r"Thanks to Quillon Vassm\u232?re."):
            rtf = ('{\\rtf1\\ansi\\ansicpg1252\\cocoartf2761\n\\f0\\fs24 \\cf0 ' + body
                   + '}\n').encode()
            for words in (accented, plain):
                with self.subTest(body=body, words=words):
                    found = checker(words).data(rtf, 'x', 'notes.rtf')
                    self.assertEqual([(f.line, f.kind) for f in found], [(2, privacy.KIND_PRIVATE)])

    def test_long_entries_and_streams_are_read_to_the_file_s_limit(self):
        # A long Word document's text, or a long PDF page: no smaller limit
        # than the file's own (HIDDEN_LIMIT) cuts one entry or stream off.
        size = 5 * 1024 * 1024
        hidden = privacy.Hidden()
        self.assertEqual(len(hidden.inflate(zlib.compress(b'x' * size))), size)
        self.assertEqual(hidden.budget, privacy.HIDDEN_LIMIT - size)
        read = []
        with mock.patch.object(privacy, 'inner_texts',
                               lambda data, *rest, **named: read.append(len(data))):
            privacy.zip_texts(zip_archive(('word/document.xml', b'x' * size)), privacy.Hidden(), 0)
        self.assertEqual(read, [size])


class EverydayWritingTests(unittest.TestCase):
    """Details as people write them in prose and in hand-written HTML:
    a phone number with entities or invisible characters, a name before
    'll or 'd, an address before a typed dash."""

    def test_a_phone_number_written_with_entities_or_invisible_characters_is_found(self):
        for text in ['<p>Call us: <a href="tel:' '2128670142">(212)&nbsp;867-' '0142</a></p>',
                     '<p>Call 212&nbsp;867&nbsp;' '0142</p>', '<p>Call +1&nbsp;212&nbsp;867&nbsp;'
                     '0142</p>', '<p>Phone: 212&#8209;867&#8209;' '0142</p>',
                     '<p>Call 212&ndash;867&ndash;' '0142</p>', 'Phone: 212\u00ad-867-' '0142',
                     'Phone: 212-867\u200b-' '0142', '<a href="tel:' '%2B1%20212%20867%20' '0142">']:
            with self.subTest(text=text):
                found = checker().text('intro\n' + text, 'site/x.html', 'site/x.html')
                self.assertEqual([(f.line, f.kind) for f in found], [(2, privacy.KIND_PHONE)])
        self.assertEqual(checker().text('Version 2&#46;12&#46;867', 'x'), [])

    def test_a_name_before_a_contraction_is_found(self):
        for words, text in [(NICK, "Tobble'll be here at five"), (NICK, "Tobble'd like water"),
                            (NICK, 'Tobble\u2019ll be here'), (NICK, "TOBBLE'LL"),
                            (NICK, "Tobble've gone"), (NICK, "Tobble's here"),
                            (NAME, "Ask Quillon Vassmere'll know")]:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker(words).text(text, 'x')), [privacy.KIND_PRIVATE])
        self.assertEqual(checker('Don').text("Don't stage everything", 'x'), [])

    def test_an_address_before_a_typed_dash_is_found(self):
        for text in [f'Email {ADDRESS}--I check it daily.', f'{ADDRESS}-', f'{ADDRESS} - daily']:
            with self.subTest(text=text):
                self.assertEqual(kinds(checker().text(text, 'x')), [privacy.KIND_EMAIL])
        self.assertEqual(checker().text('name' + AT + 'gmail.com-backup', 'x'), [])


class StatusViewTests(unittest.TestCase):
    """--status names an entry wherever the check itself would find it."""

    setUp = GitTests.setUp
    run_here = GitTests.run_here
    commit = GitTests.commit
    assertSilent = GitTests.assertSilent

    def test_status_counts_what_folding_and_markup_find(self):
        self.commit('notes.md', 'Thanks to Quillon Vassmere.\n<p><b>Tob</b>ble</p>\n')
        environ = listed('Quillon Vassm\u00e8re', NICK)
        status, out, _ = self.run_here(environ=environ)
        self.assertEqual(status, 1)
        self.assertIn('notes.md:1:11: ' + privacy.KIND_PRIVATE, out)
        self.assertIn('notes.md:2:7: ' + privacy.KIND_PRIVATE, out)
        status, out, _ = self.run_here('--status', environ=environ)
        self.assertEqual(status, 0)
        self.assertIn('Entry 1 of BRICKSON_PRIVATE_WORDS matches 1 place ', out)
        self.assertIn('Entry 2 of BRICKSON_PRIVATE_WORDS matches 1 place ', out)
        self.assertSilent(out)


class ExactRuleFieldTests(unittest.TestCase):
    """Each field a reader parses is read with the exact rules: a phone
    number, which guessed runs never report, is found in it."""

    def found(self, data):
        return sorted(set(kinds(checker(NICK).data(data, 'x', 'x'))))

    def test_a_phone_number_in_each_parsed_field_is_found(self):
        phone = PHONE_TEXT.encode()
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.comment = phone
            archive.writestr('a.txt', 'nothing')
        commented = io.BytesIO()
        with zipfile.ZipFile(commented, 'w') as archive:
            entry = zipfile.ZipInfo('a.txt')
            entry.comment = phone
            archive.writestr(entry, 'nothing')
        comment = (0x9286, 7, 8 + len(phone), b'ASCII\0\0\0' + phone)
        windows = (0x9C9C, 1, 2 * len(phone), PHONE_TEXT.encode('utf-16-le'))
        exif = [jpeg(jpeg_segment(0xE1, b'Exif\0\0II*\0' + struct.pack('<I', 8)
                                  + ifd([field], 8))) for field in (comment, windows)]
        cover = atom(b'data', struct.pack('>II', 14, 0)
                     + png(png_chunk(b'tEXt', b'Comment\0' + phone)))
        mp4 = (atom(b'ftyp', b'M4A \0\0\0\0M4A isom') + atom(b'moov', atom(b'udta', atom(
            b'meta', b'\0\0\0\0' + atom(b'hdlr', bytes(25)) + atom(b'ilst', atom(b'covr', cover)))))
            + atom(b'mdat', bytes(64)))
        # ID3v2.4: an unsynchronised frame (a zero after each 0xFF), and a
        # compressed one with its length before compression; ID3v2.3's
        # compressed frame.
        utf16 = b'\x01\xff\x00\xfe' + PHONE_TEXT.encode('utf-16-le')
        raw = b'\x03' + phone
        frames = [(4, b'TIT2' + syncsafe(len(utf16)) + b'\0\x02' + utf16),
                  (4, b'TIT2' + syncsafe(4 + len(zlib.compress(raw))) + b'\0\x09'
                   + syncsafe(len(raw)) + zlib.compress(raw)),
                  (3, b'TIT2' + struct.pack('>I', 4 + len(zlib.compress(raw))) + b'\0\x80'
                   + struct.pack('>I', len(raw)) + zlib.compress(raw))]
        mp3s = [mp3_file(frame, version=version) for version, frame in frames]
        gap = page_pdf(b'BT /F1 12 Tf [(Call 212) -300 (867-' b'0142)] TJ ET')
        actual = page_pdf(b'/Span << /ActualText (%s) >> BDC BT /F1 12 Tf (x) Tj ET EMC' % phone)
        for name, data in [('zip comment', buffer.getvalue()),
                           ('entry comment', commented.getvalue()),
                           ('exif user comment', exif[0]), ('exif windows comment', exif[1]),
                           ('mp4 cover', mp4), ('id3 unsynchronised', mp3s[0]),
                           ('id3v2.4 compressed', mp3s[1]), ('id3v2.3 compressed', mp3s[2]),
                           ('gif comment', gif_file(b'!\xfe' + gif_blocks(phone))),
                           ('jpeg comment', jpeg(jpeg_segment(0xFE, phone))),
                           ('pdf gap', gap), ('pdf actual text', actual)]:
            with self.subTest(field=name):
                self.assertEqual(self.found(data), [privacy.KIND_PHONE])


if __name__ == '__main__':
    unittest.main()
