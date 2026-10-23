#!/usr/bin/env python3
"""Check that the documents' cross-references resolve.

Run with python3 scripts/test-docs.py; standard library only. scripts/test.sh
runs it before the unit tests, so CI runs it too.

Two kinds of reference are checked:

- A section cited by title, such as docs/DECISIONS.md, "Orientations" or
  AGENTS.md, *Gotchas*, must be a heading or a bold lead-in
  (**Title.** at the start of a line or list item) in the cited file. In the
  files reviewers read as instructions, a bare *Title* must also name a
  section somewhere in the repository.
- A relative Markdown link, such as [handoff](docs/HANDOFF.md#verification),
  must point to a file that exists, and its #anchor to a heading in it.
  Reference-link definitions are checked too, covering full, collapsed and
  shortcut references without requiring their labels to be repeated inline.

Renaming a section or moving a file without updating what cites it fails
here, which is how reviewers were twice sent to sections that did not exist.
"""
from pathlib import Path
import re
import unittest

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

SOURCE_SUFFIXES = {'.md', '.swift', '.yml', '.yaml', '.sh', '.py', '.json'}

CITATION = re.compile(
    r'`?(?P<path>(?:[\w.-]+/)*[\w.-]+\.md)`?'   # a Markdown file name
    r'\s*(?:,|→|->)?\s*'                      # a comma or an arrow, or nothing
    r'(?:"(?P<quoted>[^"\n]{2,120})"'          # "Title"
    r'|(?<![*\w])\*(?P<italic>[^*\n]{2,120})\*(?![*\w]))')  # or *Title*
BARE_ITALIC = re.compile(r'(?<![*\w`])\*(?P<title>[A-Z][^*\n]{1,120}?)\*(?![*\w])')
LINK = re.compile(r'(?<!!)\[[^\]\n]*\]\((?P<target><[^>\n]*>|[^)\s]+)(?:\s+(?:"[^"]*"|\'[^\']*\'))?\s*\)')
REFERENCE_LINK = re.compile(
    r'^ {0,3}\[(?!\^)[^\]\n]+\]:[ \t]*(?:\n[ \t]*)?'
    r'(?P<target><[^>\n]*>|[^\s<>]+)'
    r'(?:[ \t]+(?:"[^"\n]*"|\'[^\'\n]*\'|\([^\)\n]*\)))?[ \t]*$', re.M)
HEADING = re.compile(r'^#{1,6}\s+(?P<title>.+?)\s*#*\s*$', re.M)
LEAD_IN = re.compile(r'^\s*(?:[-*]\s+|\d+\.\s+)?\*\*(?P<title>[^*\n]+?)\*\*', re.M)
FENCE = re.compile(r'^\s*```.*?^\s*```', re.M | re.S)


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
        text = FENCE.sub('', text)
        return re.sub(r'\s*\n\s*(?:>\s*)?', ' ', text)
    return re.sub(r'\s*\n\s*(?:///?|#|\*)?\s*', ' ', text)


def normalize(title):
    """Compare titles without case, emphasis, code marks or end punctuation."""
    title = re.sub(r'[`*_]', '', title)
    title = re.sub(r'\s+', ' ', title).strip()
    return title.rstrip('.:;,').strip().lower()


def sections(text):
    """The titles a file offers: its headings and its bold lead-ins."""
    text = FENCE.sub('', text)
    titles = {normalize(m['title']) for m in HEADING.finditer(text)}
    titles |= {normalize(m['title']) for m in LEAD_IN.finditer(text)}
    # A heading such as "GitHub reviews and updates (2026-10-10)" is cited
    # without its date.
    titles |= {re.sub(r'\s*\([^)]*\)$', '', t) for t in titles}
    # A numbered heading such as "3. Build" is cited as "Build".
    titles |= {re.sub(r'^\d+\.\s+', '', t) for t in titles}
    return titles


def slug(title):
    """GitHub's anchor for a heading."""
    title = re.sub(r'[`*_]', '', title).strip().lower()
    return re.sub(r'[^\w\- ]', '', title).replace(' ', '-')


def resolve(citing, cited):
    """The file a citation names: from the repository root, else beside the
    citing file, else in docs/ (a bare DECISIONS.md means docs/DECISIONS.md)."""
    for candidate in (ROOT / cited, citing.parent / cited, ROOT / 'docs' / cited):
        if candidate.is_file():
            return candidate
    return None


def is_instruction_file(relative):
    return relative in INSTRUCTION_FILES or relative.startswith(INSTRUCTION_DIRS)


def broken_citations(path, text, all_sections):
    """Each cited section that does not exist, as a readable message."""
    relative = path.relative_to(ROOT).as_posix()
    flat = joined(text, path.suffix)
    problems = []
    cited_spans = []
    for match in CITATION.finditer(flat):
        title = match['quoted'] or match['italic']
        cited_spans.append(match.span())
        if match['italic'] is None and not title[:1].isupper():
            continue  # a quoted phrase after a file name, not a title
        target = resolve(path, match['path'])
        key = (relative, match['path'], title)
        if key in EXTERNAL:
            continue
        if target is None:
            problems.append(f'{relative}: cites {match["path"]}, which does not exist')
        elif normalize(title) not in sections(target.read_text()):
            problems.append(f'{relative}: {match["path"]} has no section "{title}"')
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


def broken_links(path, text):
    """Each relative Markdown link whose file or heading does not exist."""
    relative = path.relative_to(ROOT).as_posix()
    problems = []
    # Blockquoted definitions apply to the whole document (CommonMark 218).
    # Strip each quote marker, but leave code indentation after it intact.
    text = re.sub(r'^(?: {0,3}>[ \t]?)+', '', text, flags=re.M)
    text = without_indented_code(FENCE.sub('', text))
    # Check destinations at their definitions once, regardless of which
    # reference-link form uses them (or how many times the label is reused).
    links = list(LINK.finditer(text)) + list(REFERENCE_LINK.finditer(text))
    for match in links:
        link = match['target'].strip('<>')
        if re.match(r'[a-z][a-z0-9+.-]*:', link):
            continue  # https:, mailto: and other absolute links
        target, _, anchor = link.partition('#')
        resolved = (path.parent / target).resolve() if target else path
        if target.startswith('/'):
            problems.append(f'{relative}: link {link} is absolute; make it relative')
            continue
        if not resolved.exists():
            problems.append(f'{relative}: link {link} points to a missing file')
            continue
        if anchor and resolved.suffix == '.md':
            anchors = {slug(m['title']) for m in HEADING.finditer(FENCE.sub('', resolved.read_text()))}
            if anchor.lower() not in anchors:
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
        problems = []
        for path in files:
            text = path.read_text()
            problems += broken_citations(path, text, titles)
            if path.suffix == '.md':
                problems += broken_links(path, text)
        self.assertEqual(problems, [], '\n' + '\n'.join(problems))


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
