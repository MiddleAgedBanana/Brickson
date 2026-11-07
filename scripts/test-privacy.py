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
        for text in ['Tobblesome', 'xtobble', 'atobbles', 'Tobbler', "Tobble'll go",
                     "tobble't", '144712', '44710']:
            with self.subTest(text=text):
                self.assertEqual(check.text(text, 'x'), [])
        self.assertEqual(len(check.text('pin 4471.', 'x')), 1)

    def test_escaped_accented_and_hidden_spellings_are_found_on_their_line(self):
        check = checker(NAME)
        for text in ['&#81;uillon Vassmere', 'Qu&iacute;llon Vassmere', 'Quillon%20Vassmere',
                     'Quillon\\u0020Vassmere', 'Quíllon Vassmere',
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
        for secret in SECRETS:
            self.assertNotIn(secret, out + err)

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
        self.assertEqual(privacy.ci_revisions(self.repo), ['origin/main..HEAD'])
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


if __name__ == '__main__':
    unittest.main()
