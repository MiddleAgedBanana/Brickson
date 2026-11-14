#!/usr/bin/env python3
"""Run with python3 scripts/test-site.py; standard library only."""
from html.parser import HTMLParser
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WebsitePaletteTests(unittest.TestCase):
    """Changing any CSS ink/fill pair below to low contrast must fail."""

    def test_website_palette_in_both_appearances(self):
        css = (ROOT / 'site/style.css').read_text()
        palettes = re.findall(r':root\s*\{([^}]+)\}', css)
        self.assertEqual(len(palettes), 2, 'Light and dark palettes are required')
        def luminance(color):
            channels = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
            linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
            return sum(c * w for c, w in zip(linear, (.2126, .7152, .0722)))
        for palette in palettes:
            colors = dict(re.findall(r'--([\w-]+):\s*(#[0-9a-fA-F]{6})', palette))
            for ink, background, minimum in [
                ('text', 'bg', 4.5), ('muted', 'bg', 4.5), ('link', 'bg', 4.5),
                ('text', 'surface', 4.5), ('muted', 'surface', 4.5), ('link', 'surface', 4.5),
                ('button-text', 'button', 4.5), ('button', 'bg', 3),
                ('border', 'bg', 3), ('border', 'surface', 3),
                # The home page's alternate bands, and the contact band's
                # button.
                ('text', 'panel', 4.5), ('muted', 'panel', 4.5), ('link', 'panel', 4.5),
                ('border', 'panel', 3), ('button', 'panel', 3), ('button', 'surface', 3),
                # The thin edge around each screenshot of the app.
                ('screen-edge', 'bg', 3), ('screen-edge', 'panel', 3),
            ]:
                with self.subTest(ink=ink, background=background, palette=colors):
                    values = sorted([luminance(colors[ink]), luminance(colors[background])])
                    self.assertGreaterEqual((values[1] + .05) / (values[0] + .05), minimum)


class SiteTests(unittest.TestCase):
    """Removing a target or adding a remote asset/script must fail."""

    def test_links_and_assets_remain_local_and_resolve(self):
        class Document(HTMLParser):
            def __init__(self):
                super().__init__()
                self.ids, self.links, self.assets = set(), [], []
                self.scripts = 0
            def handle_starttag(self, tag, attrs):
                attrs = dict(attrs)
                if 'id' in attrs:
                    self.ids.add(attrs['id'])
                if tag == 'a':
                    self.links.append(attrs.get('href', ''))
                if tag in ('img', 'script', 'link'):
                    self.assets.append(attrs.get('src', attrs.get('href', '')))
                # Pictures, recordings, their posters and captions load too.
                if tag in ('source', 'video', 'audio', 'track') and attrs.get('src'):
                    self.assets.append(attrs['src'])
                # An embedded player is a third-party asset like any other.
                if tag in ('iframe', 'embed') and attrs.get('src'):
                    self.assets.append(attrs['src'])
                if tag == 'object' and attrs.get('data'):
                    self.assets.append(attrs['data'])
                if tag == 'video' and attrs.get('poster'):
                    self.assets.append(attrs['poster'])
                for candidate in (attrs.get('srcset') or '').split(','):
                    if candidate.strip():
                        self.assets.append(candidate.split()[0])
                self.scripts += tag == 'script'
        css = (ROOT / 'site/style.css').read_text()
        self.assertNotRegex(css, r'@import|url\(')
        for path in (ROOT / 'site').rglob('*.html'):
            doc = Document()
            doc.feed(path.read_text())
            self.assertEqual(doc.scripts, 0)
            for link in doc.assets + doc.links:
                if link.startswith(('https:', 'mailto:')):
                    self.assertNotIn(link, doc.assets, 'No third-party assets')
                    continue
                target, _, anchor = link.partition('#')
                resolved = path.parent / target if target else path
                if resolved.is_dir():
                    resolved /= 'index.html'
                self.assertTrue(resolved.is_file(), link)
                if anchor:
                    other = Document()
                    other.feed(resolved.read_text())
                    self.assertIn(anchor, other.ids)

    def test_hero_download_stays_below_400_kib(self):
        """Every picture in the home page's hero, at the largest of its
        files, adds up to under 400 KiB. Replacing one with the original
        large PNG, or adding a heavy second picture, fails."""
        page = _Page()
        page.feed((ROOT / 'site/index.html').read_text())
        largest = {}
        for tag, attrs, inside in page.media:
            if not any(t == 'section' and 'hero' in (a.get('class') or '').split()
                       for t, a in inside):
                continue
            pictures = [a for t, a in inside if t == 'picture']
            key = id(pictures[-1]) if pictures else id(attrs)
            files = [attrs.get('src')] + [c.split()[0] for c in (attrs.get('srcset') or '').split(',') if c.strip()]
            for file in filter(None, files):
                size = (ROOT / 'site' / file).stat().st_size
                largest[key] = max(largest.get(key, 0), size)
        self.assertTrue(largest, 'the hero shows the app')
        self.assertLess(sum(largest.values()), 400 * 1024)

    def test_development_status_and_support_are_visible(self):
        html = (ROOT / 'site/index.html').read_text()
        self.assertIn('In development for iPhone and iPad.', html)
        self.assertRegex(html, r'href="mailto:[^"]+"')
        self.assertIn('This address is not for emergencies.', html)
        self.assertNotRegex(html.lower(), r'\b(free|paid)\b')

    def test_no_page_states_a_price(self):
        """docs/DECISIONS.md, "Price not decided": "free", "paid" or an
        amount such as $4.99 on any page fails."""
        for path in (ROOT / 'site').rglob('*.html'):
            with self.subTest(page=path.relative_to(ROOT)):
                self.assertNotRegex(path.read_text().lower(),
                                    r'\b(free|paid)\b|[$\u20ac\u00a3\u00a5]\s*\d|\b\d+([.,]\d+)?\s*(usd|eur|gbp)\b')

    def test_every_page_links_to_the_accessibility_page(self):
        """The App Store's Accessibility URL; dropping a page's link, or
        moving it out of a real href (data-href), fails."""
        class Links(HTMLParser):
            def __init__(self):
                super().__init__()
                self.hrefs = []
            def handle_starttag(self, tag, attrs):
                href = dict(attrs).get('href')
                if tag == 'a' and href is not None:
                    self.hrefs.append(href)
        target = ROOT / 'site/accessibility/index.html'
        self.assertTrue(target.is_file(), 'site/accessibility/index.html is missing')
        for path in (ROOT / 'site').rglob('*.html'):
            doc = Links()
            doc.feed(path.read_text())
            resolved = set()
            for link in doc.hrefs:
                # A link within the page is not a way to reach it.
                if link.startswith(('#', 'https:', 'mailto:')) or not link:
                    continue
                page = (path.parent / link.partition('#')[0]).resolve()
                resolved.add(page / 'index.html' if page.is_dir() else page)
            with self.subTest(page=path.relative_to(ROOT)):
                self.assertIn(target.resolve(), resolved)

    def test_every_page_is_one_titled_document_with_a_way_past_the_header(self):
        """A page without a language, a title, one h1, a main or a skip link
        fails, and so does one whose only skip link is inside a comment."""
        class Outline(HTMLParser):
            def __init__(self):
                super().__init__()
                self.tags, self.title, self.in_title = [], '', False
            def handle_starttag(self, tag, attrs):
                self.tags.append((tag, dict(attrs)))
                self.in_title = tag == 'title'
            def handle_endtag(self, tag):
                self.in_title = False
            def handle_data(self, data):
                if self.in_title:
                    self.title += data
        for path in (ROOT / 'site').rglob('*.html'):
            doc = Outline()
            doc.feed(path.read_text())
            def named(name):
                return [attrs for tag, attrs in doc.tags if tag == name]
            skips = [a['href'][1:] for a in named('a')
                     if 'skip' in (a.get('class') or '').split()
                     and (a.get('href') or '').startswith('#')]
            with self.subTest(page=path.relative_to(ROOT)):
                self.assertEqual([a.get('lang') for a in named('html')], ['en'])
                self.assertTrue(doc.title.strip(), 'no title')
                self.assertIn('viewport', [a.get('name') for a in named('meta')])
                self.assertEqual(len(named('h1')), 1)
                self.assertEqual(len(named('main')), 1)
                self.assertEqual(len(skips), 1, 'no skip link')
                self.assertEqual(named('main')[0].get('id'), skips[0])


_VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link',
         'meta', 'source', 'track', 'wbr'}


class _Page(HTMLParser):
    """Each link with the elements it sits in (tag and attributes), its
    address and the words it offers; each media element; each id's text."""
    def __init__(self):
        super().__init__()
        self.stack, self.links, self.media, self.all_tags = [], [], [], []
        self.link = None
        self.texts = {}
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        inside = tuple(self.stack)
        self.all_tags.append((tag, attrs, inside))
        if tag in ('img', 'video', 'audio', 'source', 'track'):
            self.media.append((tag, attrs, inside))
        if tag == 'a':
            self.link = {'href': attrs.get('href') or '', 'attrs': attrs,
                         'inside': inside, 'words': []}
            self.links.append(self.link)
        elif tag == 'img' and self.link is not None:
            # A picture inside a link names the link by its alt.
            self.link['words'].append(f" {attrs.get('alt') or ''} ")
        if tag not in _VOID:
            self.stack.append((tag, attrs))
    def handle_endtag(self, tag):
        if tag == 'a':
            self.link = None
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break
    def handle_data(self, data):
        if self.link is not None:
            self.link['words'].append(data)
        for _, attrs in self.stack:
            if attrs.get('id'):
                self.texts.setdefault(attrs['id'], []).append(data)


def _pages():
    for path in sorted((ROOT / 'site').rglob('*.html')):
        page = _Page()
        page.feed(path.read_text())
        yield path, page


def _tags(inside):
    return [tag for tag, _ in inside]


def _words(link):
    """What a link is called: its aria-label, or its words and pictures."""
    label = link['attrs'].get('aria-label')
    return ' '.join((label if label else ''.join(link['words'])).split())


def _in_banner(inside):
    """In the page's own header, not a header inside its content."""
    tags = _tags(inside)
    return 'header' in tags and not {'main', 'article', 'section', 'aside'} & set(tags)


def _in_section_list(inside):
    """In a long page's "On this page" list of its own sections."""
    return any(tag == 'nav' and 'policy-nav' in (attrs.get('class') or '').split()
               for tag, attrs in inside)


def _destination(page_path, href):
    """Where a link goes, as a path inside site/, or the mail address."""
    if href.startswith(('mailto:', 'https:')):
        return href
    target = href.partition('#')[0]
    resolved = (page_path.parent / target).resolve() if target else page_path
    if resolved.is_dir():
        resolved /= 'index.html'
    return str(resolved.relative_to((ROOT / 'site').resolve()))


class NavigationTests(unittest.TestCase):
    """The owner, 2026-11-13: links that only jump down a short page are
    not navigation, and Contact opens the visitor's mail app."""

    def test_header_navigation_goes_to_real_pages(self):
        """Any link in a page's own header that goes to a place on a page
        (`#approach`, `../#support`) fails; pages and mail links pass."""
        for path, page in _pages():
            header = [(link['href'], _words(link)) for link in page.links
                      if _in_banner(link['inside'])]
            with self.subTest(page=path.relative_to(ROOT)):
                self.assertTrue(header, 'no header links')
                for href, words in header:
                    self.assertNotIn('#', href, f'{words!r} jumps within a page')

    def test_no_button_only_scrolls_the_page(self):
        """A link drawn as a button that only jumps within the page (the
        old hero's "Our approach", `#approach`) fails."""
        for path, page in _pages():
            for link in page.links:
                if 'button' in (link['attrs'].get('class') or '').split():
                    with self.subTest(page=path.relative_to(ROOT), button=_words(link)):
                        self.assertFalse(link['href'].startswith('#'))

    def test_every_page_offers_the_same_header_navigation(self):
        """Dropping Privacy from one page's header, renaming a link on one
        page only, or pointing one page's Accessibility link elsewhere
        fails."""
        menus = {}
        for path, page in _pages():
            menus[path.relative_to(ROOT)] = tuple(
                (_words(link), _destination(path, link['href'])) for link in page.links
                if _in_banner(link['inside']) and 'nav' in _tags(link['inside']))
        self.assertEqual(len(set(menus.values())), 1, menus)

    def test_contact_links_open_the_mail_app_to_one_address(self):
        """A link that offers contact (Contact, Get in touch, Email, Write
        to us, an address, or Support pointing at a place on a page) is a
        mailto link, and every mailto link on the site writes to the same
        published address. Pointing Contact at `#support`, Support at
        `../#support`, or adding a second address, fails. Only a long
        page's "On this page" list may name its Contact section."""
        addresses = set()
        for path, page in _pages():
            for link in page.links:
                href, words = link['href'], _words(link).lower()
                if href.startswith('mailto:'):
                    addresses.add(href[len('mailto:'):].partition('?')[0].lower())
                    continue
                if href.startswith('https:') or _in_section_list(link['inside']):
                    continue
                with self.subTest(page=path.relative_to(ROOT), link=words):
                    self.assertNotRegex(words, r'contact|get in touch|\be-?mail\b|write to us|@')
                    if '#' in href:
                        self.assertNotRegex(words, r'support')
        self.assertEqual(len(addresses), 1, 'one published contact address')

    def test_header_offers_contact_on_every_page(self):
        """A page whose header has no mail link, or whose Contact points
        at `#support`, fails."""
        for path, page in _pages():
            header = [link['href'] for link in page.links if _in_banner(link['inside'])]
            with self.subTest(page=path.relative_to(ROOT)):
                self.assertTrue(any(h.startswith('mailto:') for h in header))


class MediaTests(unittest.TestCase):
    """Screenshots and recordings of the app: described, sized, light to
    download, and never playing by themselves."""

    def test_every_picture_is_described_and_sized(self):
        """An img without words in its alt (`alt=""` included), or without
        a width or height, fails (a missing size makes the page jump as it
        loads)."""
        for path, page in _pages():
            for tag, attrs, inside in page.media:
                if tag != 'img':
                    continue
                with self.subTest(page=path.relative_to(ROOT), img=attrs.get('src')):
                    self.assertTrue((attrs.get('alt') or '').strip(), 'a picture of the app needs words')
                    self.assertTrue(attrs.get('width') and attrs.get('height'))

    def test_recordings_wait_for_the_visitor_and_are_described(self):
        """A video or audio that plays by itself or loops, or has no
        controls, fails; so does a video with no name, no poster, or no
        written description of what it shows of at least 30 words (WCAG
        2.2.2, and 1.2.1 for a recording without sound)."""
        for path, page in _pages():
            for tag, attrs, inside in page.media:
                if tag not in ('video', 'audio'):
                    continue
                with self.subTest(page=path.relative_to(ROOT), media=attrs.get('poster') or tag):
                    self.assertNotIn('autoplay', attrs)
                    self.assertNotIn('loop', attrs)
                    self.assertIn('controls', attrs)
                    if tag == 'audio':
                        continue
                    for needed in ('playsinline', 'muted'):
                        self.assertIn(needed, attrs)
                    self.assertTrue(attrs.get('poster'))
                    self.assertIn(attrs.get('preload'), ('none', 'metadata'))
                    self.assertIn('figure', _tags(inside))
                    self.assertTrue((attrs.get('aria-label') or attrs.get('aria-labelledby') or '').strip(),
                                    'a recording needs a name')
                    described = (attrs.get('aria-describedby') or '').split()
                    self.assertTrue(described, 'no written description')
                    for target in described:
                        words = ' '.join(page.texts.get(target, [])).split()
                        self.assertGreaterEqual(len(words), 30, f'#{target} describes too little')

    def test_no_link_opens_a_new_window(self):
        """target="_blank" fails: a new window loses Back and can strand
        someone using a screen reader or a switch."""
        for path, page in _pages():
            for tag, attrs, inside in page.all_tags:
                with self.subTest(page=path.relative_to(ROOT), tag=tag):
                    self.assertNotIn('target', attrs)

    def test_media_files_stay_light(self):
        """A picture over 400 KiB, an SVG over 64 KiB or a recording over
        4 MiB fails, whatever the case of its suffix; so does a file under
        site/assets of a kind with no limit here."""
        limits = {'.webp': 400, '.jpg': 400, '.jpeg': 400, '.png': 400, '.gif': 400,
                  '.avif': 400, '.svg': 64, '.mp4': 4096, '.webm': 4096, '.mov': 4096,
                  '.m4v': 4096}
        assets = ROOT / 'site/assets'
        for file in (ROOT / 'site').rglob('*'):
            if not file.is_file() or file.name.startswith('.'):
                continue
            suffix = file.suffix.lower()
            with self.subTest(file=file.relative_to(ROOT)):
                if assets in file.parents:
                    self.assertIn(suffix, limits, 'give this kind of file a size limit')
                if suffix in limits:
                    self.assertLess(file.stat().st_size, limits[suffix] * 1024)


if __name__ == '__main__':
    unittest.main()
