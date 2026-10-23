#!/usr/bin/env python3
"""Check that the documents' cross-references resolve.

Run with python3 scripts/test-docs.py; standard library only. scripts/test.sh
runs it before the unit tests, so CI runs it too.

Two kinds of reference are checked:

- A section cited by title, such as docs/DECISIONS.md, "Orientations" or
  AGENTS.md, *Gotchas*, must be a heading or a bold lead-in
  (**Title.** at the start of a line or list item) in the cited file. A
  title after a comma or an arrow, as in docs/DECISIONS.md, "iPhone Duo",
  *The fold*, must name a part of a title before it or a section beside
  one; a title after "and" is checked as the title before it was, so
  ASO.md, *Screenshots* and *Subtitle* names two sections. Words in
  quote marks after a file name are a title, whatever letter they start
  with, unless QUOTATIONS lists them as a quotation. In the files
  reviewers read as instructions, a bare *Title* must also name a section
  somewhere in the repository.
- A relative Markdown link, such as [handoff](docs/HANDOFF.md#verification),
  must point to a file that exists, and its #anchor to a heading in it.
  Reference-link definitions are checked too, covering full, collapsed and
  shortcut references without requiring their labels to be repeated inline.

Renaming a section or moving a file without updating what cites it fails
here, which is how reviewers were twice sent to sections that did not exist.
"""
from functools import cache
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re
import unittest
import tempfile
import string
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

# Dated research and old snapshots are kept as written; what they cite may
# have moved since (docs/archive/README.md, docs/recon/README.md).
EXCLUDED = ('docs/archive/', 'docs/recon/', '.claude/worktrees/',
            # This file's own tests cite sections that must not exist.
            'scripts/test-docs.py')

# Files whose bare *Title* names a section: the reviewers' instructions
# (AGENTS.md, "Code Review Rules") and the agent definitions.
INSTRUCTION_FILES = ('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md')
INSTRUCTION_DIRS = ('.github/skills/', '.claude/agents/')

# Cited sections that are deliberately not in this repository. Each entry
# says why; anything else that does not resolve is a failure.
EXTERNAL = {
    # PORTING.md sends porters to sections of the reference app's HANDOFF.
    ('docs/PORTING.md', 'docs/HANDOFF.md', 'Decided but NOT built'),
    ('docs/PORTING.md', 'docs/HANDOFF.md', 'Known limits and issues'),
}

# Words in quote marks after a file name that quote it rather than name a
# section. Each must still appear, word for word, in the cited file.
QUOTATIONS = {
    ('BricksonTests/Layout/WordFitTests.swift', 'AGENTS.md',
     'drop a decorative icon before shrinking words'),
    ('BricksonTests/Layout/WordFitTests.swift', 'AGENTS.md',
     'never render below their default size'),
    # Known gaps items have no titles; this one is cited by its first words.
    ('docs/DECISIONS.md', 'docs/HANDOFF.md',
     "Chains of activations through Settings' screens"),
}

SOURCE_SUFFIXES = {'.md', '.swift', '.yml', '.yaml', '.sh', '.py', '.json'}

CITATION = re.compile(
    r'`?(?P<path>(?:[\w.-]+/)*[\w.-]+\.md)`?'   # a Markdown file name
    r'\s*(?:,|→|->)?\s*'                      # a comma or an arrow, or nothing
    r'(?:"(?P<quoted>[^"\n]{2,120})"'          # "Title"
    r'|(?<![*\w])\*(?P<italic>[^*\n]{2,120})\*(?![*\w]))')  # or *Title*
# A further title after a cited one: , *The fold* or and "Home".
FOLLOWING = re.compile(
    r'(?=\s*(?:,|→|->|and\s))\s*(?:,|→|->)?\s*(?P<and>and\s+)?'
    r'(?:"(?P<quoted>[^"\n]{2,120})"'
    r'|(?<![*\w])\*(?P<italic>[^*\n]{2,120})\*(?![*\w]))')
BARE_ITALIC = re.compile(r'(?<![*\w`])\*(?P<title>[A-Z][^*\n]{1,120}?)\*(?![*\w])')
REFERENCE_LINK = re.compile(
    r'^ {0,3}\[(?!\^)(?:\\.|[^\[\]\\\n])+\]:[ \t]*(?:\n[ \t]*)?'
    r'(?P<target><[^>\n]*>|[^\s<>]+)'
    r'(?:[ \t]+(?:"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|\((?:\\.|[^)\\\n])*\)))?[ \t]*$', re.M)
HEADING = re.compile(r'^ {0,3}(?P<marks>#{1,6})\s+(?P<title>.+?)\s*#*\s*$', re.M)
LEAD_IN = re.compile(r'^\s*(?:[-*]\s+|\d+\.\s+)?\*\*(?P<title>[^*\n]+?)\*\*', re.M)
def without_fenced_code(text):
    output, fence = [], None
    for line in text.splitlines(keepends=True):
        if fence:
            if re.fullmatch(r' {0,3}' + re.escape(fence[0]) + '{' + str(len(fence)) + r',}[ \t]*[\r\n]*', line):
                fence = None
            output.append('\n')
            continue
        opening = re.match(r' {0,3}(`{3,}|~{3,})(.*)', line)
        if opening and not (opening[1][0] == '`' and '`' in opening[2]):
            fence = opening[1]
            output.append('\n')
        else:
            output.append(line)
    return ''.join(output)


def without_code_spans(text, for_citations=False):
    """Blank out code spans. For citations, keep a span that is a file name,
    or words that cannot start or end one (no quote mark, asterisk or file
    name), so "`main` ruleset" is read as a title."""
    output, index = [], 0
    while index < len(text):
        opening = re.search(r'`+', text[index:])
        if not opening:
            output.append(text[index:])
            break
        start, end = index + opening.start(), index + opening.end()
        output.append(text[index:start])
        backslashes = len(text[:start]) - len(text[:start].rstrip('\\'))
        if backslashes % 2:
            output.append(text[start:end])
            index = end
            continue
        closing = re.search(r'(?<!`)`{' + str(end - start) + r'}(?!`)', text[end:])
        if closing:
            stop = end + closing.end()
            content = text[end:end + closing.start()]
            if for_citations and (re.fullmatch(r'(?:[\w.-]+/)*[\w.-]+\.md', content)
                                  or not re.search(r'["*]|\.md', content)):
                output.append(content)
            else:
                output.append(re.sub(r'[^\n]', ' ', text[start:stop]))
            index = stop
        else:
            output.append(text[start:end])
            index = end
    return ''.join(output)


def tracked_files():
    """Every file the checks read, under ROOT, minus the excluded folders."""
    files = []
    for path in sorted(ROOT.rglob('*')):
        relative = path.relative_to(ROOT).as_posix()
        if (path.is_file() and path.suffix in SOURCE_SUFFIXES
                and not relative.startswith(EXCLUDED)
                and not any(part.startswith('.') and part not in ('.github', '.claude')
                            for part in path.relative_to(ROOT).parts)
                and '.xcodeproj/' not in relative and 'DerivedData/' not in relative):
            files.append(path)
    return files


def joined(text, suffix):
    """Join wrapped lines (and their comment markers) so a citation split
    across two lines reads as one."""
    if suffix == '.md':
        text = re.sub(r'^(?: {0,3}>[ \t]?)+', '', text, flags=re.M)
        text = without_code_spans(without_indented_code(without_fenced_code(text)),
                                  for_citations=True)
        return re.sub(r'\s*\n\s*(?:>\s*)?', ' ', text)
    return re.sub(r'\s*\n\s*(?:///?|#|\*)?\s*', ' ', text)


def normalize(title):
    """Compare titles without case, emphasis, code marks or end punctuation."""
    title = re.sub(r'[`*_]', '', title)
    title = re.sub(r'\s+', ' ', title).strip()
    return title.rstrip('.:;,').strip().lower()


def headings(text):
    """ATX and Setext headings in document order, outside fenced code, as
    (level, title, line number)."""
    paragraph = []
    for number, line in enumerate(without_fenced_code(text).splitlines()):
        heading = HEADING.fullmatch(line)
        if heading:
            yield len(heading['marks']), heading['title'], number
            paragraph = []
        elif re.fullmatch(r' {0,3}(?:=+|-+)[ \t]*', line):
            if paragraph:
                yield 1 if '=' in line else 2, ' '.join(paragraph), number
            paragraph = []
        elif (not line.strip() or re.match(r' {0,3}(?:>|[-+*]\s|\d+[.)]\s)', line)
              or (not paragraph and line.startswith(('    ', '\t')))):
            paragraph = []
        else:
            paragraph.append(line.strip())


def heading_titles(text):
    for _, title, _ in headings(text):
        yield title


def aliases(title, lead_in):
    """A title and the shorter forms it is cited by."""
    title = normalize(title)
    titles = {title}
    # A lead-in such as "Open: fewer than three everyday categories." is
    # cited by its label or by the words after it.
    label, colon, words = title.partition(': ')
    if lead_in and colon:
        titles |= {label, words}
    # A heading such as "GitHub reviews and updates (2026-10-10)" is cited
    # without its date.
    titles |= {re.sub(r'\s*\([^)]*\)$', '', t) for t in titles}
    # A numbered heading such as "3. Build" is cited as "Build".
    titles |= {re.sub(r'^\d+\.\s+', '', t) for t in titles}
    return titles


LEAD_IN_LEVEL = 7  # below every heading


@cache  # each citation reads its file's outline; callers never change it
def outline(text):
    """Every heading and bold lead-in in document order, as (titles, level,
    parent): parent is the index of the nearest heading above it of a
    higher level, and a lead-in ranks below every heading."""
    text = without_fenced_code(text)
    found = [(number, level, title) for level, title, number in headings(text)]
    found += [(text.count('\n', 0, m.start('title')), LEAD_IN_LEVEL, m['title'])
              for m in LEAD_IN.finditer(text)]
    nodes, open_headings = [], []
    for _, level, title in sorted(found, key=lambda entry: entry[:2]):
        while open_headings and nodes[open_headings[-1]][1] >= level:
            open_headings.pop()
        parent = open_headings[-1] if open_headings else None
        nodes.append((aliases(title, level == LEAD_IN_LEVEL), level, parent))
        if level != LEAD_IN_LEVEL:
            open_headings.append(len(nodes) - 1)
    return nodes


def sections(text):
    """The titles a file offers: its headings and its bold lead-ins."""
    return set().union(*(titles for titles, _, _ in outline(text)))


def part_of_or_beside(nodes, outer, inner):
    """Whether node inner sits inside node outer, or beside it under the
    same parent."""
    parent = nodes[inner][2]
    if parent == nodes[outer][2]:
        return True
    while parent is not None:
        if parent == outer:
            return True
        parent = nodes[parent][2]
    return False


def slug(title):
    """GitHub's anchor for a heading."""
    title = re.sub(r'[`*_]', '', title).strip().lower()
    return re.sub(r'[^\w\- ]', '', title).replace(' ', '-')


def heading_anchors(text):
    anchors = set()
    for title in heading_titles(text):
        base = slug(title)
        anchor, number = base, 0
        while anchor in anchors:
            number += 1
            anchor = f'{base}-{number}'
        anchors.add(anchor)
    return anchors


def resolve(citing, cited):
    """The file a citation names: from the repository root, else beside the
    citing file, else in docs/ (a bare DECISIONS.md means docs/DECISIONS.md)."""
    for candidate in (ROOT / cited, citing.parent / cited, ROOT / 'docs' / cited):
        if candidate.is_file():
            return candidate
    return None


def is_instruction_file(relative):
    return relative in INSTRUCTION_FILES or relative.startswith(INSTRUCTION_DIRS)


def is_title(quoted):
    """Whether quoted words are a title. Between quote marks around file
    names, as in ("docs/HANDOFF.md", "README.md"), CITATION finds only
    punctuation or a space; a title starts with a letter, digit or code."""
    return re.match(r'[\w`]', quoted) is not None


def cited_titles(flat, match):
    """The titles a citation names, in order, as (title, quoted, after and),
    and where the last one ends."""
    titles = [(match['quoted'] or match['italic'], match['italic'] is None, False)]
    end = match.end()
    while (following := FOLLOWING.match(flat, end)) is not None:
        if following['italic'] is None and not is_title(following['quoted']):
            break
        titles.append((following['quoted'] or following['italic'],
                       following['italic'] is None, following['and'] is not None))
        end = following.end()
    return titles, end


def broken_titles(path, cited, titles, used):
    """Each title of one citation that the cited file does not have."""
    relative = path.relative_to(ROOT).as_posix()
    target = resolve(path, cited)
    text = target.read_text() if target else ''
    nodes = outline(text)
    problems, earlier, previous = [], [], None
    # What a title must be part of or beside: every section named before
    # it, or, after "and", what the title before it had to be.
    context, beside = [], None
    for title, quoted, after_and in titles:
        if not after_and:
            context, beside = list(earlier), previous
        key = (relative, cited, title)
        if key in EXTERNAL:
            used.add(key)
            continue
        if target is None:
            problems.append(f'{relative}: cites {cited}, which does not exist')
            break
        if quoted and key in QUOTATIONS:
            used.add(key)
            if ' '.join(title.split()) not in ' '.join(text.split()):
                problems.append(f'{relative}: {cited} does not contain the words "{title}"')
            continue
        found = [index for index, node in enumerate(nodes) if normalize(title) in node[0]]
        if not found:
            problems.append(f'{relative}: {cited} has no section "{title}"')
        elif context and not any(part_of_or_beside(nodes, outer, inner)
                                 for outer in context for inner in found):
            problems.append(f'{relative}: {cited} has a section "{title}", '
                            f'but not in or beside "{beside}"')
        if found:
            earlier += found
            previous = title
    return problems


def broken_citations(path, text, all_sections, used=None):
    """Each cited section that does not exist, as a readable message. Each
    EXTERNAL or QUOTATIONS entry the text uses is added to used."""
    relative = path.relative_to(ROOT).as_posix()
    flat = joined(text, path.suffix)
    used = set() if used is None else used
    problems = []
    cited_spans = []
    for match in CITATION.finditer(flat):
        if match['italic'] is None and not is_title(match['quoted']):
            continue  # quote marks around a file name, not a title
        titles, end = cited_titles(flat, match)
        cited_spans.append((match.start(), end))
        problems += broken_titles(path, match['path'], titles, used)
    if path.suffix == '.md' and is_instruction_file(relative):
        for match in BARE_ITALIC.finditer(flat):
            inside = any(start <= match.start() < end for start, end in cited_spans)
            if not inside and normalize(match['title']) not in all_sections:
                problems.append(f'{relative}: no file has a section "{match["title"]}"')
    return problems


def without_indented_code(text):
    """Skip four-space/tab code blocks without hiding paragraph continuations."""
    output = []
    paragraph = False
    code = False
    container_indent = 0
    for line in text.splitlines(keepends=True):
        expanded = line.expandtabs(4)
        indent = len(expanded) - len(expanded.lstrip(' '))
        item = re.match(r' {0,3}(?:[-*+] |\d+[.)] ) *', expanded)
        if item:
            container_indent = item.end()
        elif line.strip() and indent < container_indent:
            container_indent = 0
        if not line.strip():
            paragraph = False
            output.append(line)
        elif indent >= container_indent + 4 and (code or not paragraph):
            code = True
            output.append('\n')
        else:
            code = False
            output.append(line)
            paragraph = not bool(re.match(r' {0,3}#{1,6} ', line))
    return ''.join(output)


def inline_link_starts(text):
    """Find destinations after labels with balanced or escaped brackets."""
    stack, index = [], 0
    while index < len(text):
        char = text[index]
        if char == '\\' and index + 1 < len(text) and text[index + 1] in string.punctuation:
            index += 2
            continue
        if char == '[':
            stack.append(index)
        elif char == ']' and stack:
            start = stack.pop()
            if text[index + 1:index + 2] == '(' and (start == 0 or text[start - 1] != '!'):
                yield index + 2
                # A link cannot contain another link; keep the innermost one.
                stack.clear()
        index += 1


def exact_path_exists(path):
    """Check directory-entry spelling even on a case-insensitive filesystem."""
    current = ROOT
    for component in path.relative_to(ROOT).parts:
        if component == '..':
            current = current.parent
            continue
        try:
            if component not in {entry.name for entry in current.iterdir()}:
                return False
        except OSError:
            return False
        current /= component
    return current.exists()


def inline_link_targets(text):
    """Scan balanced destinations without ending at an inner parenthesis."""
    for start in inline_link_starts(text):
        while start < len(text) and text[start].isspace():
            start += 1
        index, depth = start, 0
        angle = index < len(text) and text[index] == '<'
        if angle:
            index += 1
        while index < len(text):
            char = text[index]
            if char == '\\' and index + 1 < len(text):
                index += 2
                continue
            if angle:
                if char == '>':
                    index += 1
                    break
                if char in '<\n':
                    break
            else:
                if char.isspace() or (char == ')' and depth == 0):
                    break
                if char == '(':
                    depth += 1
                elif char == ')':
                    depth -= 1
            index += 1
        if depth or (angle and (index == start or text[index - 1] != '>')):
            continue
        end = index
        while index < len(text) and text[index].isspace():
            index += 1
        if index > end and index < len(text) and text[index] in ('"', "'", '('):
            close = ')' if text[index] == '(' else text[index]
            index += 1
            while index < len(text) and text[index] != close:
                index += 2 if text[index] == '\\' else 1
            index += 1
            while index < len(text) and text[index].isspace():
                index += 1
        if index < len(text) and text[index] == ')':
            yield text[start:end]


def broken_links(path, text):
    """Each relative Markdown link whose file or heading does not exist."""
    relative = path.relative_to(ROOT).as_posix()
    problems = []
    # Blockquoted definitions apply to the whole document (CommonMark 218).
    # Strip each quote marker, but leave code indentation after it intact.
    text = re.sub(r'^(?: {0,3}>[ \t]?)+', '', text, flags=re.M)
    text = without_code_spans(without_indented_code(without_fenced_code(text)))
    # Check destinations at their definitions once, regardless of which
    # reference-link form uses them (or how many times the label is reused).
    links = list(inline_link_targets(text)) + [match['target'] for match in REFERENCE_LINK.finditer(text)]
    for target in links:
        link = re.sub(r'\\([' + re.escape(string.punctuation) + r'])', r'\1', target.strip('<>'))
        url = urlsplit(link)
        if url.scheme or url.netloc:
            continue  # absolute and protocol-relative external links
        target, anchor = unquote(url.path), unquote(url.fragment)
        resolved = (path.parent / target).resolve() if target else path
        if target.startswith('/'):
            problems.append(f'{relative}: link {link} is absolute; make it relative')
            continue
        if not resolved.is_relative_to(ROOT.resolve()):
            problems.append(f'{relative}: link {link} escapes the repository')
            continue
        if not exact_path_exists(path.parent / target if target else path):
            problems.append(f'{relative}: link {link} points to a missing file')
            continue
        if anchor and resolved.suffix == '.md':
            anchors = heading_anchors(resolved.read_text())
            if anchor not in anchors:
                problems.append(f'{relative}: link {link} names a heading that does not exist')
    return problems


def all_section_titles(files):
    titles = set()
    for path in files:
        if path.suffix == '.md':
            titles |= sections(path.read_text())
    return titles


class CheckerTests(unittest.TestCase):
    """The checks themselves must catch what they claim to catch."""

    def setUp(self):
        self.fixture = ROOT / 'docs' / 'DECISIONS.md'

    def test_heading_fragments_are_case_sensitive(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Orientations')
            with patch.dict(globals(), ROOT=root):
                for fragment in ['ORIENTATIONS', '%4Frientations', 'Orientations']:
                    self.assertTrue(broken_links(page, f'[guide](guide.md#{fragment})'))
                for fragment in ['orientations', '%6Frientations']:
                    self.assertEqual(broken_links(page, f'[guide](guide.md#{fragment})'), [])

    def test_reference_titles_allow_escaped_delimiters(self):
        titles = [r'"a \" title"', r"'a \' title'", r'(a \) title)']
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Setup')
            with patch.dict(globals(), ROOT=root):
                for title in titles:
                    for target in ['missing.md', 'guide.md#missing']:
                        self.assertTrue(broken_links(page,
                            f'[guide][ref]\n\n[ref]: {target} {title}'))
                    self.assertEqual(broken_links(page,
                        f'[guide][ref]\n\n[ref]: guide.md#setup {title}'), [])

    def test_escaped_brackets_in_reference_definition_labels(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Setup')
            with patch.dict(globals(), ROOT=root):
                for label in [r'ref\]', r'ref\[', r'ref\\']:
                    for destination in ['missing.md', 'guide.md#missing']:
                        self.assertTrue(broken_links(page,
                            f'[guide][{label}]\n\n[{label}]: {destination}'))
                    self.assertEqual(broken_links(page,
                        f'[guide][{label}]\n\n[{label}]: guide.md#setup'), [])

    def test_balanced_and_escaped_brackets_in_link_text(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Setup')
            with patch.dict(globals(), ROOT=root):
                for label in ['see [guide]', r'see \] guide', r'see \[ guide', 'see [a [guide]]']:
                    self.assertTrue(broken_links(page, f'[{label}](missing.md)'))
                    self.assertTrue(broken_links(page, f'[{label}](guide.md#missing)'))
                    self.assertEqual(broken_links(page, f'[{label}](guide.md#setup)'), [])
                self.assertEqual(broken_links(page, r'\[guide](missing.md)'), [])

    def test_link_path_casing_is_exact_on_every_filesystem(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'Docs').mkdir()
            (root / 'Docs' / 'Guide.md').write_text('# Setup')
            with patch.dict(globals(), ROOT=root):
                for target in ['docs/Guide.md', 'Docs/guide.md', 'Docs/%67uide.md']:
                    self.assertTrue(broken_links(page, f'[guide]({target})'), target)
                for target in ['Docs/Guide.md', './Docs/Guide.md', 'Docs/../Docs/Guide.md']:
                    self.assertEqual(broken_links(page, f'[guide]({target}#setup)'), [])

    def test_balanced_parentheses_in_inline_destinations(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            with patch.dict(globals(), ROOT=root):
                for name in ['guide_(v2).md', 'guide_(v(2(x))).md']:
                    (root / name).write_text('# Setup')
                    for destination in [name, name.replace('(', r'\(').replace(')', r'\)')]:
                        self.assertEqual(broken_links(page, f'[guide]({destination}#setup)'), [])
                        self.assertEqual(broken_links(page, f'[guide]({destination}#setup "Guide title")'), [])
                        self.assertTrue(broken_links(page, f'[guide]({destination}#missing)'))
                self.assertTrue(broken_links(page, '[guide](missing_(v2).md#setup)'))

    def test_indented_atx_headings_are_real_sections(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            guide = root / 'guide.md'
            with patch.dict(globals(), ROOT=root):
                for spaces in range(4):
                    guide.write_text(' ' * spaces + '# Setup\n')
                    self.assertEqual(broken_citations(guide, 'guide.md, "Setup"', set()), [])
                    self.assertEqual(broken_links(guide, '[part](#setup)'), [])
                guide.write_text('    # Setup\n')
                self.assertTrue(broken_links(guide, '[part](#setup)'))

    def test_relative_link_queries_are_not_file_names(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            guide = root / 'guide.md'
            guide.write_text('# Setup')
            with patch.dict(globals(), ROOT=root):
                self.assertEqual(broken_links(guide, '[part](guide.md?plain=1#setup)'), [])
                self.assertTrue(broken_links(guide, '[part](guide.md?plain=1#missing)'))
                self.assertTrue(broken_links(guide, '[part](missing.md?plain=1#setup)'))

    def test_encoded_relative_links_are_resolved_inside_the_repository(self):
        with tempfile.TemporaryDirectory() as folder:
            parent = Path(folder).resolve()
            root = parent / 'repo'
            root.mkdir()
            guide = root / 'My Guide.md'
            guide.write_text('# Setup')
            (parent / 'outside.md').write_text('# Outside')
            with patch.dict(globals(), ROOT=root):
                readme = root / 'README.md'
                self.assertEqual(broken_links(readme, '[guide](My%20Guide.md#setup)'), [])
                self.assertTrue(broken_links(readme, '[guide](Missing%20Guide.md)'))
                self.assertEqual(broken_links(readme, '[outside](%2e%2e/outside.md)'),
                    ['README.md: link %2e%2e/outside.md escapes the repository'])

    def test_setext_headings_support_citations_and_anchors(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            guide = root / 'guide.md'
            guide.write_text('Setup\n=====\n\nDetails\n-------\n\n# Setup\n')
            with patch.dict(globals(), ROOT=root):
                self.assertEqual(broken_citations(guide, 'guide.md, "Setup"', set()), [])
                for anchor in ['setup', 'details', 'setup-1']:
                    self.assertEqual(broken_links(guide, f'[part](#{anchor})'), [], anchor)
                self.assertTrue(broken_links(guide, '[part](#missing)'))
                self.assertNotIn('fake', sections('```\nFake\n====\n```'))

    def test_code_examples_are_not_section_citations(self):
        missing = 'docs/NO-SUCH.md, "Example"'
        for code in [f'`{missing}`', f'``{missing}``',
                     f'> ```markdown\n> {missing}\n> ```',
                     f'    {missing}']:
            self.assertEqual(broken_citations(self.fixture, code, set()), [], code)
            self.assertTrue(broken_citations(self.fixture, missing + '\n\n' + code, set()))
        # Formatting only the file name as code is an ordinary real citation.
        self.assertTrue(broken_citations(self.fixture, '`docs/NO-SUCH.md`, "Example"', set()))
        self.assertTrue(broken_citations(self.fixture, '`docs/DECISIONS.md`, "Missing title"', set()))
        self.assertEqual(broken_citations(self.fixture, '`docs/DECISIONS.md`, "Orientations"', set()), [])

    def test_duplicate_heading_links_get_numbered_anchors(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            guide = root / 'guide.md'
            guide.write_text('# Repeat\n# Repeat\n# Repeat-1\n# Repeat\n')
            with patch.dict(globals(), ROOT=root):
                for anchor in ['repeat', 'repeat-1', 'repeat-1-1', 'repeat-2']:
                    self.assertEqual(broken_links(guide, f'[part](#{anchor})'), [], anchor)
                self.assertTrue(broken_links(guide, '[part](#repeat-3)'))

    def test_a_missing_section_is_reported(self):
        text = 'See docs/DECISIONS.md, "A section nobody wrote".'
        self.assertTrue(broken_citations(self.fixture, text, set()))

    def test_a_citation_wrapped_over_two_comment_lines_is_read(self):
        source = ROOT / 'Brickson' / 'Example.swift'
        text = '// See docs/DECISIONS.md,\n// "A section nobody wrote".'
        self.assertTrue(broken_citations(source, text, set()))

    def test_an_existing_section_is_accepted(self):
        text = 'See docs/DECISIONS.md, "Orientations", and AGENTS.md, *Gotchas*.'
        self.assertEqual(broken_citations(self.fixture, text, set()), [])

    def test_a_bold_lead_in_counts_as_a_section(self):
        self.assertIn('words never break', sections('- **Words never break.** Labels'))

    def test_a_numbered_heading_is_cited_without_its_number(self):
        self.assertIn('deploy', sections('## 5. Deploy'))

    def test_a_quoted_title_may_start_with_a_small_letter(self):
        # Skipping titles that start in lower case let every "iPhone Duo"
        # citation through unchecked.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Decisions\n## iPhone Duo\n')
            with patch.dict(globals(), ROOT=root):
                self.assertEqual(broken_citations(page, 'guide.md, "iPhone Duo"', set()), [])
                for title in ['iPhone Dou', 'iPad Duo', 'the fold']:
                    self.assertEqual(broken_citations(page, f'guide.md, "{title}"', set()),
                                     [f'index.md: guide.md has no section "{title}"'])

    def test_quote_marks_around_a_file_name_are_not_a_title(self):
        source = ROOT / 'scripts' / 'example.py'
        for text in ['allowed("git stage docs/NO-SUCH.md")\nallowed("git status")',
                     'files = ("docs/NO-SUCH.md", "docs/OTHER.md")',
                     'See "docs/NO-SUCH.md" and "README.md".']:
            self.assertEqual(broken_citations(source, text, set()), [], text)

    def test_code_inside_a_quoted_title_is_read(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Decisions\n### `main` ruleset\n')
            with patch.dict(globals(), ROOT=root):
                self.assertEqual(broken_citations(page, 'guide.md,\n"`main` ruleset"', set()), [])
                self.assertEqual(broken_citations(page, 'guide.md, "`main` rules"', set()),
                                 ['index.md: guide.md has no section "main rules"'])
                # Code that could hold a citation is still not read as one.
                self.assertEqual(broken_citations(page, '`guide.md, "Missing"`', set()), [])

    def test_a_quotation_must_be_listed_and_appear_in_the_cited_file(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Rules\n\nLabels shrink, and never\nrender below '
                                           'their default size.\n')
            listed = {('index.md', 'guide.md', 'never render below their default size'),
                      ('index.md', 'guide.md', 'never render below their old size')}
            with patch.dict(globals(), ROOT=root, QUOTATIONS=listed):
                used = set()
                self.assertEqual(broken_citations(page,
                    'guide.md, "never render below their default size"', set(), used), [])
                self.assertEqual(used, {('index.md', 'guide.md',
                                         'never render below their default size')})
                self.assertEqual(broken_citations(page,
                    'guide.md, "never render below their old size"', set()),
                    ['index.md: guide.md does not contain the words '
                     '"never render below their old size"'])
                # Words the file contains are a title unless they are listed.
                self.assertEqual(broken_citations(page, 'guide.md, "Labels shrink"', set()),
                    ['index.md: guide.md has no section "Labels shrink"'])

    def test_a_title_after_a_cited_title_must_be_part_of_it(self):
        # Reading only the first title let a wrong *The fold* pass.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text(
                '# Decisions\n\n## Orientations\n\n### The hinge\n\n'
                '- **Open: a thing nobody decided.** Text.\n\n'
                '## iPhone Duo\n\n### The fold\n\n'
                '- **Open: fewer than three categories.** Text.\n\n'
                '## Home\n\nText.\n')
            with patch.dict(globals(), ROOT=root):
                for text in ['guide.md, "iPhone Duo", *The fold*',
                             'guide.md, "iPhone Duo", "The fold"',
                             'guide.md, *iPhone Duo*, *The fold*',
                             'guide.md → "iPhone Duo" → *The fold*',
                             'guide.md, "iPhone Duo", *The fold*, *Open*',
                             'guide.md, "iPhone Duo", *Fewer than three categories*',
                             'guide.md, "iPhone Duo", "Orientations" and "Home"',
                             'guide.md, "iPhone Duo", "Orientations", and "Home"',
                             'guide.md, "Orientations", *The hinge*, "Home"',
                             'guide.md, *Home* and *The fold*',
                             'guide.md, "iPhone Duo", *The fold* and *Open*']:
                    self.assertEqual(broken_citations(page, text, set()), [], text)
                for text, title, beside in [
                        ('guide.md, "iPhone Duo", *The flod*', 'The flod', None),
                        ('guide.md, "iPhone Duo", "Orientations" and "Homes"', 'Homes', None),
                        ('guide.md, "iPhone Duo", *The hinge*', 'The hinge', 'iPhone Duo'),
                        ('guide.md, "Home", *Open*', 'Open', 'Home'),
                        ('guide.md, "iPhone Duo", *The fold*, *The hinge*',
                         'The hinge', 'The fold'),
                        ('guide.md, "iPhone Duo", *The fold* and *The hinge*',
                         'The hinge', 'iPhone Duo'),
                        ('guide.md, *Home* and *The flod*', 'The flod', None)]:
                    problem = (f'index.md: guide.md has a section "{title}", but not in or '
                               f'beside "{beside}"' if beside else
                               f'index.md: guide.md has no section "{title}"')
                    self.assertEqual(broken_citations(page, text, set()), [problem], text)
                swift = root / 'Example.swift'
                self.assertEqual(broken_citations(swift,
                    '/// See guide.md, "iPhone Duo",\n/// *The flod*.', set()),
                    ['Example.swift: guide.md has no section "The flod"'])
                # Words after a title that are not one are left alone.
                for text in ['guide.md, "iPhone Duo"; "The flod" is a typo',
                             'guide.md, "iPhone Duo", and the "flod"',
                             '(guide.md, "iPhone Duo"), *not* the hinge']:
                    self.assertEqual(broken_citations(page, text, set()), [], text)

    def test_a_wrong_title_after_a_cited_title_is_reported_once(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            agents = root / 'AGENTS.md'
            (root / 'guide.md').write_text('# Decisions\n## iPhone Duo\n### The fold\n')
            with patch.dict(globals(), ROOT=root):
                self.assertEqual(broken_citations(agents,
                    'See guide.md, "iPhone Duo", *The flod*.', set()),
                    ['AGENTS.md: guide.md has no section "The flod"'])

    def test_external_titles_after_a_cited_title_are_skipped(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            page = root / 'index.md'
            (root / 'guide.md').write_text('# Handoff\n')
            text = '`guide.md` → *Decided but NOT built* and *Known limits and issues*'
            first = ('index.md', 'guide.md', 'Decided but NOT built')
            second = ('index.md', 'guide.md', 'Known limits and issues')
            with patch.dict(globals(), ROOT=root, EXTERNAL={first, second}):
                used = set()
                self.assertEqual(broken_citations(page, text, set(), used), [])
                self.assertEqual(used, {first, second})
            with patch.dict(globals(), ROOT=root, EXTERNAL={first}):
                self.assertEqual(broken_citations(page, text, set()),
                    ['index.md: guide.md has no section "Known limits and issues"'])

    def test_a_lead_in_is_cited_by_its_label_or_its_words(self):
        titles = sections('- **Open: fewer than three everyday categories.** A cell')
        self.assertLessEqual({'open: fewer than three everyday categories', 'open',
                              'fewer than three everyday categories'}, titles)
        self.assertEqual(sections('## Phase 1: Build'), {'phase 1: build'})

    def test_a_bare_title_in_an_instruction_file_must_exist(self):
        skill = ROOT / '.github' / 'skills' / 'code-review' / 'SKILL.md'
        self.assertTrue(broken_citations(skill, 'Read *No such section*.', set()))
        self.assertEqual(broken_citations(skill, 'Read *Gotchas*.', {'gotchas'}), [])

    def test_a_missing_file_or_heading_is_reported(self):
        readme = ROOT / 'README.md'
        self.assertTrue(broken_links(readme, '[x](docs/NO-SUCH-FILE.md)'))
        self.assertTrue(broken_links(readme, '[x](docs/NO-SUCH-FILE.md "a title")'))
        self.assertTrue(broken_links(readme, '[x](docs/DECISIONS.md#no-such-heading)'))
        self.assertEqual(broken_links(readme, '[x](docs/DECISIONS.md#orientations)'), [])
        self.assertEqual(broken_links(readme, '[x](https://example.com/a.md)'), [])

    def test_markdown_code_does_not_create_links(self):
        readme = ROOT / 'README.md'
        missing = '[sample](docs/NO-SUCH.md)'
        for code in [f'`{missing}`', f'``a ` {missing}``',
                     f'~~~markdown\n{missing}\n~~~',
                     f'````markdown\n```\n{missing}\n````',
                     f'~~~markdown\n{missing}']:
            self.assertEqual(broken_links(readme, code), [], code)
            self.assertTrue(broken_links(readme, missing + '\n\n' + code))
        self.assertTrue(broken_links(readme, '`unclosed ' + missing))
        self.assertTrue(broken_links(readme, '```code``` ' + missing))

    def test_relative_links_cannot_escape_the_checkout(self):
        with tempfile.TemporaryDirectory() as folder:
            parent = Path(folder).resolve()
            root = parent / 'repo'
            root.mkdir()
            (parent / 'outside.md').write_text('# Outside')
            (root / 'inside.md').write_text('# Inside')
            (root / 'shortcut.md').symlink_to(parent / 'outside.md')
            with patch.dict(globals(), ROOT=root):
                readme = root / 'README.md'
                for target in ['../outside.md', 'shortcut.md', '../missing.md']:
                    self.assertEqual(broken_links(readme, f'[link]({target})'),
                        [f'README.md: link {target} escapes the repository'])
                self.assertEqual(broken_links(readme, '[link](inside.md#inside)'), [])

    def test_indented_code_examples_are_not_links(self):
        readme = ROOT / 'README.md'
        for text in ['    [sample](docs/NO-SUCH.md)', '\t[sample](docs/NO-SUCH.md)',
                     'Example:\n\n    [sample](docs/NO-SUCH.md)\n',
                     '>     [sample](docs/NO-SUCH.md)']:
            self.assertEqual(broken_links(readme, text), [], text)
        # Indentation cannot interrupt an existing paragraph.
        self.assertTrue(broken_links(readme, 'Paragraph\n    [sample](docs/NO-SUCH.md)'))
        self.assertTrue(broken_links(readme, '    example\n\n[sample](docs/NO-SUCH.md)'))
        self.assertTrue(broken_links(readme, '- Item\n\n    [sample](docs/NO-SUCH.md)'))

    def test_angle_bracketed_inline_destinations_keep_spaces(self):
        # Capturing only non-whitespace targets loses this valid link form.
        readme = ROOT / 'README.md'
        for title in ['', ' "a title"']:
            self.assertEqual(broken_links(readme,
                f'[guide](<docs/NO SUCH FILE.md>{title})'),
                ['README.md: link docs/NO SUCH FILE.md points to a missing file'])
        self.assertEqual(broken_links(readme,
            '[guide](<docs/DECISIONS.md#orientations>)'), [])
        self.assertEqual(broken_links(readme,
            '[guide](<https://example.com/a%20b>)'), [])

    def test_a_github_anchor_drops_punctuation(self):
        self.assertEqual(slug('Reviews, updates and GitHub settings'),
                         'reviews-updates-and-github-settings')

    def test_reference_links_report_missing_files_and_headings(self):
        # Removing definition scanning must break every reference-link form.
        readme = ROOT / 'README.md'
        for usage in ['[guide][ref]', '[ref][]', '[ref]']:
            for target, problem in [
                    ('docs/NO-SUCH-FILE.md', 'points to a missing file'),
                    ('docs/DECISIONS.md#no-such-heading',
                     'names a heading that does not exist')]:
                with self.subTest(usage=usage, target=target):
                    text = f'{usage}\n\n[ref]: {target} "Guide"\n'
                    self.assertEqual(broken_links(readme, text),
                                     [f'README.md: link {target} {problem}'])

    def test_reference_links_accept_existing_files_anchors_and_external_links(self):
        readme = ROOT / 'README.md'
        for usage in ['[guide][ref]', '[ref][]', '[ref]']:
            for target in ['docs/DECISIONS.md#orientations',
                           '<docs/DECISIONS.md#orientations>',
                           'https://example.com/a.md', 'mailto:test@example.com']:
                with self.subTest(usage=usage, target=target):
                    text = f'{usage}\n\n[ref]: {target} "Guide"\n'
                    self.assertEqual(broken_links(readme, text), [])
        self.assertEqual(broken_links(self.fixture,
                                      '[here][]\n\n[here]: #orientations'), [])

    def test_fenced_reference_definitions_are_ignored(self):
        readme = ROOT / 'README.md'
        text = '```markdown\n[ref][]\n\n[ref]: docs/NO-SUCH-FILE.md\n```'
        self.assertEqual(broken_links(readme, text), [])

    def test_blockquoted_reference_definitions_are_checked(self):
        # Removing quote-prefix normalization loses these missing destinations.
        readme = ROOT / 'README.md'
        for prefix in ['> ', '>', '   > ', '> > ']:
            for target, problem in [
                    ('docs/NO-SUCH-FILE.md', 'points to a missing file'),
                    ('docs/DECISIONS.md#no-such-heading',
                     'names a heading that does not exist')]:
                with self.subTest(prefix=prefix, target=target):
                    text = f'[guide]\n\n{prefix}[guide]: {target}\n'
                    self.assertEqual(broken_links(readme, text),
                                     [f'README.md: link {target} {problem}'])
        self.assertEqual(broken_links(readme,
            '[guide]\n\n> [guide]:\n> docs/NO-SUCH-FILE.md\n'),
            ['README.md: link docs/NO-SUCH-FILE.md points to a missing file'])
        self.assertEqual(broken_links(readme,
            '[guide]\n\n> [guide]: docs/DECISIONS.md#orientations\n'), [])

    def test_blockquoted_code_is_not_a_reference_definition(self):
        # Quote removal must retain four-space indentation and fenced code.
        readme = ROOT / 'README.md'
        for text in [
                '>     [guide]: docs/NO-SUCH-FILE.md',
                '    > [guide]: docs/NO-SUCH-FILE.md',
                '> ```markdown\n> [guide]: docs/NO-SUCH-FILE.md\n> ```']:
            with self.subTest(text=text):
                self.assertEqual(broken_links(readme, text), [])

    def test_reference_destinations_can_follow_on_the_next_line(self):
        readme = ROOT / 'README.md'
        text = '[ref][]\n\n   [ref]:\n  <docs/NO-SUCH-FILE.md>\n'
        self.assertEqual(broken_links(readme, text),
                         ['README.md: link docs/NO-SUCH-FILE.md points to a missing file'])

    def test_non_link_bracketed_text_is_not_a_reference_definition(self):
        readme = ROOT / 'README.md'
        for text in ['[example]: ordinary prose, not a link definition',
                     '[ref]: docs/NO-SUCH-FILE.md "title" trailing text',
                     '    [ref]: docs/NO-SUCH-FILE.md', '[^note]: explanation']:
            with self.subTest(text=text):
                self.assertEqual(broken_links(readme, text), [])


class DocumentTests(unittest.TestCase):
    """Renaming a cited section, or moving a linked file, must fail."""

    def test_every_cited_section_and_relative_link_resolves(self):
        files = tracked_files()
        titles = all_section_titles(files)
        problems, used = [], set()
        for path in files:
            text = path.read_text()
            problems += broken_citations(path, text, titles, used)
            if path.suffix == '.md':
                problems += broken_links(path, text)
        self.assertEqual(problems, [], '\n' + '\n'.join(problems))
        # An exception for a citation that is gone must go too.
        unused = sorted((EXTERNAL | QUOTATIONS) - used)
        self.assertEqual(unused, [], 'nothing cites these EXTERNAL or QUOTATIONS entries')


class IssueFormTests(unittest.TestCase):
    """Dropping the privacy warning, or allowing blank issues, must fail."""

    def test_the_bug_form_warns_that_issues_are_public(self):
        form = (ROOT / '.github/ISSUE_TEMPLATE/something-went-wrong.yml').read_text()
        self.assertIn('**This page is public.**', form)
        self.assertIn("don't include the words of your own phrases", form)
        for method in ['Touch', 'Voice Control', 'Switch Control', 'Full Keyboard Access',
                       'AssistiveTouch with Dwell', 'Head tracking', 'Eye Tracking']:
            self.assertIn(f'- {method}', form)

    def test_every_issue_starts_from_a_form(self):
        config = (ROOT / '.github/ISSUE_TEMPLATE/config.yml').read_text()
        self.assertRegex(config, r'(?m)^blank_issues_enabled: false$')
        self.assertIn('/security/policy', config)


if __name__ == '__main__':
    unittest.main()
