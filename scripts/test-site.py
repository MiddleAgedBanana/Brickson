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
        """Replacing the optimized hero with the original large PNG fails."""
        html = (ROOT / "site/index.html").read_text()
        image = re.search(r'<img src="([^"]+)"', html)[1]
        self.assertLess((ROOT / "site" / image).stat().st_size, 400 * 1024)

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


if __name__ == '__main__':
    unittest.main()
