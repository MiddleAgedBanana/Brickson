#!/usr/bin/env python3
"""Check scripts/forbidden-code.py, and run it over the repository.

Run with python3 scripts/test-forbidden-code.py; standard library only.
scripts/test.sh runs it before the unit tests, so CI runs it on every pull
request. Each test plants one thing a rule forbids and expects the check
to find it, or plants something allowed (a comment that names a forbidden
API, a file the docs/DECISIONS.md table names) and expects silence. So
dropping a rule or any one of its parts, reading comments or strings as
code, or letting today's app trip a false alarm fails a test here.
"""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import unittest.mock

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
SCRIPT = Path(__file__).resolve().with_name('forbidden-code.py')
spec = importlib.util.spec_from_file_location('forbidden_code', SCRIPT)
forbidden = importlib.util.module_from_spec(spec)
spec.loader.exec_module(forbidden)

ROOT = SCRIPT.parents[1]
for _variable in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                  'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_PREFIX'):
    os.environ.pop(_variable, None)

# A small checkout with the shape of the real one: an app target, a test
# target, the decisions the check reads, and one workflow.
PROJECT = '''\
name: Fixture
options:
  deploymentTarget:
    iOS: "26.0"
settings:
  base:
    SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"
    GCC_TREAT_WARNINGS_AS_ERRORS: "YES"
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
targets:
  App:
    type: application
    platform: iOS
    sources:
      - App
      - path: site/privacy
        type: folder
    info:
      path: App/Info.plist
      properties:
        UIBackgroundModes: [audio]
    dependencies: []
  AppTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - AppTests
    dependencies:
      - target: App
'''
DECISIONS_TEXT = '''\
# Decisions

## Warnings are errors

Every target treats a warning as an error.

## Minimum iOS, iPhone and iPad

iOS and iPadOS 26.0 or later, on iPhone and iPad.

## Apple's current frameworks first

Kept, and why.

| What | Where | Why | Revisit when |
|---|---|---|---|
| `UIColor.systemBackground` | `Palette.screen` | No SwiftUI colour. | — |
| `DispatchQueue.main.async` | `Speaker` (`forward`) | Order. | — |
| `NotificationCenter.addObserver(forName:object:queue:using:)` | `Events` | No typed message. | — |
| Key-value observation of `outputVolume` | `Monitor` | No other way. | — |

Not legacy, so not listed: AVFoundation.

## A later decision

Text.
'''
WORKFLOW = '''\
name: Tests
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  unit:
    name: Unit tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
        with:
          persist-credentials: false
      - name: Run
        run: |
          echo "key: value"
          scripts/test.sh
'''
APP_FILE = '''\
import SwiftUI

struct HomeView: View {
    var body: some View {
        Button("Yes") { speak("Yes") }
    }
}
'''


def app_findings(text, path='App/Example.swift', decisions=DECISIONS_TEXT):
    source = forbidden.Swift(path, text)
    return forbidden.check_app_file(source, forbidden.allowed_files(decisions),
                                    forbidden.declared_names([source]))


def test_findings(text, path='AppTests/ExampleTests.swift'):
    return forbidden.check_test_file(forbidden.Swift(path, text))


def workflow_findings(text, path='.github/workflows/example.yml'):
    return forbidden.check_workflow(path, text)


def rules(findings):
    return [finding.rule for finding in findings]


def lines(findings):
    return [finding.line for finding in findings]


class Checkout:
    """A throwaway git checkout holding the fixture, or a copy of this
    repository's files."""

    def __init__(self, files):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        for path, text in files.items():
            self.write(path, text)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)

    def write(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, bytes):
            target.write_bytes(text)
        else:
            target.write_text(text, encoding='utf-8')

    def append(self, path, text):
        target = self.root / path
        target.write_text(target.read_text(encoding='utf-8') + text, encoding='utf-8')

    def check(self):
        return forbidden.check(self.root)

    def run(self, environ=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = forbidden.main([str(self.root)], environ or {})
        return status, out.getvalue(), err.getvalue()

    def close(self):
        self.directory.cleanup()


def fixture_checkout(**changes):
    files = {'project.yml': PROJECT, 'docs/DECISIONS.md': DECISIONS_TEXT,
             'CLAUDE.md': '@AGENTS.md\n', '.github/workflows/tests.yml': WORKFLOW,
             'App/HomeView.swift': APP_FILE,
             'AppTests/HomeTests.swift': 'import Testing\n\n@Test func yes() {}\n'}
    files.update(changes)
    return Checkout({path: text for path, text in files.items() if text is not None})


class SwiftReadingTests(unittest.TestCase):
    """The check reads code, never comments or the words in strings."""

    def code(self, text):
        return forbidden.Swift('Example.swift', text).code

    def test_comments_are_blanked_and_lines_kept(self):
        code = self.code('let a = 1 // URLSession\n/* URLSession\n URLSession */ let b = 2\n')
        self.assertNotIn('URLSession', code)
        self.assertEqual(code.count('\n'), 3)
        self.assertIn('let b = 2', code)

    def test_block_comments_nest(self):
        code = self.code('/* outer /* inner */ URLSession */ let a = 1\n')
        self.assertNotIn('URLSession', code)
        self.assertIn('let a = 1', code)

    def test_strings_are_blanked_but_interpolation_is_code(self):
        code = self.code('let a = "URLSession \\(URLRequest(url: u)) \\"rollback()\\""\n')
        self.assertNotIn('URLSession', code)
        self.assertNotIn('rollback', code)
        self.assertIn('URLRequest(url: u)', code)

    def test_nested_strings_inside_interpolation(self):
        code = self.code('let a = "x \\(f("URLSession")) y" ; let b = URLRequest\n')
        self.assertNotIn('URLSession', code)
        self.assertIn('let b = URLRequest', code)

    def test_multiline_and_raw_strings(self):
        code = self.code('let a = """\n  URLSession "quoted"\n  """\nlet b = #"URLSession "x" \\(y)"#\n'
                         'let c = #"""\n URLSession \\#(URLRequest)\n"""#\nlet d = 1\n')
        self.assertNotIn('URLSession', code)
        self.assertIn('URLRequest', code)
        self.assertIn('let d = 1', code)
        self.assertEqual(code.count('\n'), 8)

    def test_an_unclosed_string_ends_with_its_line(self):
        code = self.code('let a = "unclosed\nlet b = URLSession\n')
        self.assertIn('let b = URLSession', code)

    def test_regex_literals_are_not_code_and_division_is(self):
        code = self.code('let a = s.firstMatch(of: /"URLSession[^>]*>/)\nlet b = x / 2 / y\n'
                         'let c = #/URLSession/#\n')
        self.assertNotIn('URLSession', code)
        self.assertIn('let b = x / 2 / y', code)

    def test_a_bare_regex_is_not_code(self):
        code = self.code('let a = s.firstMatch(of: /URLSession/)\nlet b = URLRequest\n')
        self.assertNotIn('URLSession', code)
        self.assertIn('let b = URLRequest', code)

    def test_a_regex_after_each_word_an_operand_follows(self):
        for text in ['func f() -> Regex<Substring> { return /URLSession/ }\n',
                     'switch s { case /URLSession/: break; default: break }\n',
                     'let f = { (_: Int) in /URLSession/ }\n',
                     'switch s { case let x where /URLSession/ ~= x: break; default: break }\n',
                     'let m = try /URLSession/.wholeMatch(in: s)\n',
                     'let m = await /URLSession/.firstMatch(in: s)\n',
                     'func f() throws { throw /URLSession/ }\n',
                     'if /URLSession/ ~= s {}\n',
                     'guard /URLSession/ ~= s else { return }\n',
                     'while /URLSession/ ~= s {}\n',
                     'switch /URLSession/ ~= s { default: break }\n']:
            with self.subTest(text=text):
                self.assertNotIn('URLSession', self.code(text))
        # After any other word, a slash divides.
        self.assertIn('URLSession', self.code('let a = total /URLSession/ 2\n'))

    def test_a_slash_inside_an_operator_is_not_a_regex(self):
        for character in '<>=+-*%&|^~?!.':  # Swift's operator characters
            name = f'{character}/+'
            text = f'infix operator {name} : AdditionPrecedence // never URLSession\n'
            with self.subTest(text=text):
                self.assertNotIn('URLSession', self.code(text))

    def test_an_operator_passed_as_a_value_is_not_a_regex(self):
        for text, word in [('factors.reduce(1, /) // never UIScreen\n', 'UIScreen'),
                           ('let ops = [(+), (/)]; let h = "a/b: never UIDevice"\n', 'UIDevice'),
                           ('infix operator </> : AdditionPrecedence // never URLSession\n',
                            'URLSession'),
                           ('let ops = [/]; let h = "a/b: never UIDevice"\n', 'UIDevice'),
                           ('let y = f(/x) // never URLSession\n', 'URLSession')]:
            with self.subTest(text=text):
                self.assertNotIn(word, self.code(text))

    def test_a_one_line_raw_string_holding_a_quote_mark(self):
        code = self.code('let quote = #"""#\nimport Network\nlet b = #"""x"#; let c = 1\n')
        self.assertIn('import Network', code)
        self.assertIn('let c = 1', code)

    def test_a_string_after_a_regex_is_still_a_string(self):
        code = self.code('let a = s.firstMatch(of: /<\\/main>/); let b = "URLSession"\n')
        self.assertNotIn('URLSession', code)

    def test_lines_are_counted_from_one(self):
        source = forbidden.Swift('Example.swift', 'a\nb\nc')
        self.assertEqual([source.line(0), source.line(2), source.line(4)], [1, 2, 3])

    def test_top_level_strings_skip_nested_calls(self):
        source = forbidden.Swift('Example.swift', 'f(g("inner"), "outer")')
        opening = source.code.index('(')
        self.assertEqual(source.top_level_strings(opening, source.closing(opening)), ['"outer"'])

    def test_top_level_strings_skip_strings_inside_an_interpolation(self):
        source = forbidden.Swift('Example.swift', 'f("a \\(b ? "c" : "d") e", "z")')
        opening = source.code.index('(')
        self.assertEqual(source.top_level_strings(opening, source.closing(opening)),
                         ['"a \\(b ? "c" : "d") e"', '"z"'])


class AppRuleTests(unittest.TestCase):
    """Each thing the app must never contain is found, wherever it is
    written as code, and nowhere else."""

    PLANTED = [
        ('network code', 'let s = URLSession.shared'),
        ('network code', 'var request = URLRequest(url: url)'),
        ('network code', 'AsyncImage(url: url)'),
        ('network code', 'let browser = NetServiceBrowser()'),
        ('cloud sync', 'let store = NSUbiquitousKeyValueStore.default'),
        ('cloud sync', 'let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)'),
        ('cloud sync', 'let container = CKContainer.default()'),
        ('Keychain', 'SecItemAdd(query as CFDictionary, nil)'),
        ('Keychain', 'let query = [kSecClass: kSecClassGenericPassword]'),
        ('ads or tracking', 'let id = ASIdentifierManager.shared().advertisingIdentifier'),
        ('ads or tracking', 'ATTrackingManager.requestTrackingAuthorization { _ in }'),
        ('accounts', 'SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }'),
        ('system sound', 'AudioServicesPlaySystemSound(1005)'),
        ('system volume', 'let slider = MPVolumeView()'),
        ('device check', 'if UIDevice.current.userInterfaceIdiom == .pad {}'),
        ('device check', 'let bounds = UIScreen.main.nativeBounds'),
        ('device check', 'let o = scene.interfaceOrientation'),
        ('gesture', 'Text("Yes").onTapGesture { speak() }'),
        ('gesture', 'Color.clear.onLongPressGesture { }'),
        ('gesture', 'view.gesture(DragGesture())'),
        ('gesture', 'Text("Yes").gesture(press)'),
        ('pointer code', 'Text("Yes").onHover { inside in }'),
        ('eye or head tracking', 'let configuration = ARFaceTrackingConfiguration()'),
        ('hidden navigation', 'Form {}.navigationBarBackButtonHidden(true)'),
        ('hidden navigation', 'Form {}.interactiveDismissDisabled()'),
        ('hidden navigation', 'Form {}.toolbar(.hidden, for: .navigationBar)'),
        ('hidden navigation', 'Form {}.toolbarVisibility(.hidden, for: .navigationBar)'),
        ('hidden navigation', 'Form {}.toolbar(.hidden)'),
        ('hidden navigation', 'Form {}.toolbar(editing ? .hidden : .visible, for: .navigationBar)'),
        # A comma inside the visibility's own expression is not the end of it.
        ('hidden navigation',
         'Form {}.toolbar(min(a, b) > 0 ? .hidden : .visible, for: .navigationBar)'),
        ('ViewThatFits', 'ViewThatFits { Text("A") }'),
        ('rollback', 'context.rollback()'),
        ('rollback', 'rollback()'),
    ]

    # One line for each name a rule looks for, each line holding only that
    # name, so dropping any one of them fails this test.
    EACH_NAME = {
        'network code': [
            'let s = URLSession.shared', 'let s = NSURLSession()', 'let c = NSURLConnection()',
            'var r = URLRequest(url: u)', 'let r = NSMutableURLRequest()', 'let r = NSURLRequest()',
            'class P: URLProtocol {}', 'let c = HTTPCookieStorage.shared',
            'let b = NetServiceBrowser()', 'Stream.getStreamsToHost(withName: h)',
            'CFStreamCreatePairWithSocketToHost(nil, h, 80, &r, &w)', 'let s = CFSocketCreate()',
            'let m = CFHTTPMessageCreateRequest()', 'AsyncImage(url: u)', 'let w = WKWebView()',
            'let c = NWConnection(host: h, port: p, using: .tcp)', 'let l = try NWListener()',
            'let b = NWBrowser()', 'let m = NWPathMonitor()', 'let s = MCSession(peer: p)'],
        'cloud sync': ['let s = NSUbiquitousKeyValueStore.default',
                       'let u = f.url(forUbiquityContainerIdentifier: nil)',
                       'let c = CKContainer.default()'],
        'Keychain': ['SecItemAdd(q, nil)', 'let k = kSecClass', 'let a = SecAccessControlCreateFlags()',
                     'let k = SecKeychainRef()'],
        'ads or tracking': ['let m = ASIdentifierManager.shared()', 'let i = m.advertisingIdentifier',
                            'ATTrackingManager.requestTrackingAuthorization { _ in }',
                            'let v = d.identifierForVendor', 'SKAdNetwork.updateConversionValue(1)',
                            'MXMetricManager.shared.add(self)'],
        'accounts': ['let p = ASAuthorizationAppleIDProvider()',
                     'let s = ASWebAuthenticationSession(url: u)',
                     'SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }',
                     'GKLocalPlayer.local.authenticateHandler = nil'],
        'system sound': ['AudioServicesPlaySystemSound(1005)', 'let i: SystemSoundID = 0',
                         'let i = kSystemSoundID_Vibrate'],
        'system volume': ['let v = MPVolumeView()', 'let p = MPMusicPlayerController.systemMusicPlayer'],
        'device check': ['if t.userInterfaceIdiom == .pad {}', 'let i: UIUserInterfaceIdiom = .pad',
                         'let d = UIDevice.current', 'let s = UIScreen.main', 'let b = s.nativeBounds',
                         'let n = s.nativeScale', 'let o: UIDeviceOrientation = .portrait',
                         'let m: UIInterfaceOrientationMask = .all', 'let o = scene.interfaceOrientation',
                         'var u = utsname()', 'sysctlbyname("hw.machine", nil, &n, nil, 0)'],
        'gesture': ['Text("Yes").onTapGesture { }', 'Color.clear.onLongPressGesture { }',
                    'Color.clear.onLongTouchGesture { }', 'let g = SpatialTapGesture()',
                    'let g = TapGesture()', 'let g = LongPressGesture()', 'let g = DragGesture()',
                    'let g = MagnifyGesture()', 'let g = MagnificationGesture()',
                    'let g = RotateGesture()', 'let g = RotationGesture()',
                    'Color.clear.simultaneousGesture(g)', 'Color.clear.highPriorityGesture(g)',
                    'let r = UITapGestureRecognizer()', 'Text("Yes").gesture(press)'],
        'pointer code': ['Text("Yes").onHover { _ in }', 'Text("Yes").onContinuousHover { _ in }'],
        'eye or head tracking': ['let c = ARFaceTrackingConfiguration()', 'let s = ARSession()',
                                 'let c = GCController.current'],
        'hidden navigation': ['Form {}.navigationBarBackButtonHidden(true)',
                              'Form {}.navigationBarHidden(true)', 'Form {}.interactiveDismissDisabled()',
                              'Form {}.toolbar(.hidden, for: .navigationBar)',
                              'Form {}.toolbarVisibility(.hidden, for: .navigationBar)',
                              'Form {}.toolbar(.hidden)',
                              'Form {}.toolbar(.hidden, for: .automatic)',
                              'Form {}.toolbar(.hidden, for: .tabBar, .navigationBar)',
                              'Form {}.toolbar(Visibility.hidden, for: .navigationBar)',
                              'Form {}.toolbar(editing ? .hidden : .visible, for: .navigationBar)',
                              'Form {}.toolbarVisibility(typing ? .hidden : .automatic, '
                              'for: .navigationBar)',
                              'toolbar(isEditing ? .hidden : .visible, for: .navigationBar)'],
        'ViewThatFits': ['ViewThatFits { Text("A") }'],
    }

    def test_every_name_of_every_rule_is_found(self):
        self.assertEqual(set(self.EACH_NAME), {rule for rule, _, _ in forbidden.APP_WORDS} | {
            'hidden navigation', 'gesture'})
        for rule, samples in self.EACH_NAME.items():
            for line in samples:
                with self.subTest(rule=rule, line=line):
                    self.assertIn(rule, rules(app_findings(f'func f() {{\n    {line}\n}}\n')))

    def test_each_forbidden_use_is_found(self):
        for rule, line in self.PLANTED:
            with self.subTest(line=line):
                findings = app_findings(f'import SwiftUI\n\nfunc f() {{\n    {line}\n}}\n')
                self.assertIn(rule, rules(findings))
                self.assertIn(4, [finding.line for finding in findings if finding.rule == rule])

    def test_the_same_names_in_comments_and_strings_are_left_alone(self):
        for _, line in self.PLANTED:
            with self.subTest(line=line):
                quoted = line.replace('\\', '\\\\').replace('"', '\\"')
                text = (f'import SwiftUI\n// {line}\n/// never `{line}`\n/* {line} */\n'
                        f'let a = "{quoted}"\nlet b = """\n{line}\n"""\n')
                self.assertEqual(app_findings(text), [])

    def test_imports(self):
        for module, rule in [('Network', 'forbidden framework'), ('CloudKit', 'forbidden framework'),
                             ('Security', 'forbidden framework'), ('WebKit', 'forbidden framework'),
                             ('AudioToolbox', 'forbidden framework'),
                             ('AppTrackingTransparency', 'forbidden framework'),
                             ('AuthenticationServices', 'forbidden framework'),
                             ('ARKit', 'forbidden framework'),
                             ('AdAttributionKit', 'forbidden framework'),
                             ('AdServices', 'forbidden framework'),
                             ('AdSupport', 'forbidden framework'), ('iAd', 'forbidden framework'),
                             ('GameController', 'forbidden framework'),
                             ('CFNetwork', 'forbidden framework'),
                             ('MultipeerConnectivity', 'forbidden framework'),
                             ('FirebaseAnalytics', 'framework not on the list'),
                             ('MediaPlayer', 'framework not on the list'),
                             ('Combine', 'legacy framework'), ('CoreData', 'legacy framework'),
                             ('Intents', 'legacy framework'), ('XCTest', 'legacy framework'),
                             ('UIKit', 'legacy framework'), ('Dispatch', 'legacy framework'),
                             ('IntentsUI', 'legacy framework'),
                             ('SafariServices', 'legacy framework'),
                             ('XCUIAutomation', 'legacy framework')]:
            for form in (f'import {module}', f'@preconcurrency import {module}',
                         f'import struct {module}.Thing', f'import class {module}.Thing',
                         f'import enum {module}.Thing', f'import protocol {module}.Thing',
                         f'import typealias {module}.Thing', f'import func {module}.thing',
                         f'import let {module}.thing', f'import var {module}.thing',
                         f'@_exported import {module}.Sub',
                         f'internal import {module}', f'private import {module}',
                         f'fileprivate import {module}', f'public import {module}',
                         f'package import {module}', f'@preconcurrency internal import {module}',
                         f'import Foundation; import {module}'):
                with self.subTest(form=form):
                    self.assertEqual(rules(app_findings(form + '\n')), [rule])

    def test_allowed_imports_pass(self):
        text = ''.join(f'import {module}\n' for module in sorted(forbidden.APP_IMPORTS))
        self.assertEqual(app_findings(text), [])
        self.assertEqual(app_findings('internal import Foundation; private import SwiftUI\n'), [])

    def test_hiding_another_bar_keeps_the_way_back(self):
        for line in ['Form {}.toolbar(.hidden, for: .tabBar)',
                     'Form {}.toolbar(.visible, for: .navigationBar)',
                     'Form {}.toolbar(editing ? .hidden : .visible, for: .tabBar)',
                     'Form {}.toolbar(pick(.hidden, .visible), for: .tabBar)',
                     'Form {}.toolbarBackground(.hidden, for: .navigationBar)',
                     'Form {}.toolbar { ToolbarItem { Button("Done") { done() } } }',
                     'Form {}.toolbar(id: "edit") { ToolbarItem(id: "done") { Text("Done") } }',
                     'Form {}.toolbar(removing: .sidebarToggle)',
                     'Form {}.toolbar()',
                     'Form {}.mytoolbar(.hidden)',
                     'Form {}.toolbar { ScrollView {}.scrollIndicators(.hidden) }',
                     'Form {}.toolbar(content: { ToolbarItem { ScrollView {}.scrollIndicators(.hidden) } })',
                     'func toolbar(_ visibility: Visibility = .hidden) -> some View { self }']:
            with self.subTest(line=line):
                self.assertEqual(app_findings(line + '\n'), [])

    def test_a_legacy_api_passes_only_in_a_file_the_table_names(self):
        for path, line in [('App/Palette.swift', 'import UIKit\nlet c = UIColor.systemBackground'),
                           ('App/Palette.swift', 'let c = Color(uiColor: .systemBackground)'),
                           ('App/Speaker.swift', 'DispatchQueue.main.async { }'),
                           ('App/Events.swift',
                            'c.addObserver(forName: n, object: nil, queue: .main) { _ in '
                            'MainActor.assumeIsolated { } }'),
                           ('App/Monitor.swift', 'o = session.observe(\\.outputVolume) { _, _ in }')]:
            with self.subTest(path=path, line=line):
                self.assertEqual(app_findings(line + '\n', path=path), [])
                elsewhere = app_findings(line + '\n', path='App/Other.swift')
                self.assertEqual(rules(elsewhere), ['legacy framework'])
                self.assertIn('App/Other.swift is not named', elsewhere[0].message)

    def test_each_legacy_family_is_found(self):
        for line in ['class M: NSManagedObject {}', 'let c = NSPersistentContainer(name: n)',
                     'let r = NSFetchRequest<Item>()', 'let f: NSFetchedResultsController<Item>',
                     'let e = NSEntityDescription()', 'let r: FetchedResults<Item>',
                     '@StateObject var m = M()', '@ObservedObject var m: M',
                     '@EnvironmentObject var m: M', 'let c: Cancellable? = nil',
                     'let s = PassthroughSubject<Int, Never>()',
                     'let s = CurrentValueSubject<Int, Never>(0)', 'let p: AnyPublisher<Int, Never>',
                     'let m = Publishers.Merge(a, b)', 'Color.clear.onReceive(p) { _ in }',
                     'let t = p.autoconnect()', 'p.assign(to: &$value)',
                     'let t = Timer.publish(every: 1, on: .main, in: .common)',
                     'dispatch_async(q) {}', 'let a = XCUIApplication()','let v: UIView? = nil', 'final class A: ObservableObject {}',
                     '@Published var x = 1', 'let c: AnyCancellable? = nil',
                     'let r = NSFetchRequest<NSManagedObject>()', '@FetchRequest var items',
                     'INInteraction(intent: i, response: nil).donate()',
                     'let q = DispatchQueue(label: "x")', 'let s = SFSafariViewController(url: u)',
                     'XCTAssertTrue(true)', 'session.addObserver(self, forKeyPath: "v", context: nil)',
                     'Text("A").background(Color(.secondarySystemBackground))',
                     'let c = Color(.systemBackground)', 'let c = Color(.label)',
                     'let c = Color(.systemRed)', 'let c = Color( . tertiaryLabel)',
                     'let c = Color(.separator)', 'let c = Color(.placeholderText)',
                     'let c = Color(.opaqueSeparator)', 'let c = Color(.link)',
                     'let c = Color(.lightText)', 'let c = Color(.darkText)',
                     'let c = Color(.tintColor)', 'let c = Color(.quaternarySystemFill)',
                     'let c = Color(.secondaryLabel)', 'let c = Color(.quaternaryLabel)',
                     'let c = Color(.tertiarySystemFill)', 'let i = Image(uiImage: picture)',
                     # However the colour is made, and UIColor's names Color lacks.
                     'let c = Color.init(.systemBackground)', 'let c: Color = .init(.systemBackground)',
                     'Text("A").tint(.init(.systemRed))', 'let c = Color(.darkGray)',
                     'let c = Color(.lightGray)', 'let c = Color(.magenta)',
                     # Combine's own publishers.
                     'let g = await Future<Bool, Never> { p in p(.success(true)) }.value',
                     'for await v in Just(1).values { print(v) }', 'let d = Deferred { load() }',
                     'let e = Empty<Int, Never>()', 'let f = Fail<Int, E>(error: e)',
                     'let r = Record<Int, Never>(output: [1], completion: .finished)',
                     'for await n in [1, 2].publisher.values { print(n) }',
                     'NotificationCenter.default.addObserver(forName: n, object: nil, queue: .main) '
                     '{ _ in MainActor.assumeIsolated { go() } }',
                     'p.assign(to: \\.value, on: model)', 'p.sink(receiveValue: { _ in })',
                     'let f = Future { promise in promise(.success(1)) }',
                     'p.sink(receiveCompletion: { _ in }, receiveValue: { _ in })',
                     'Color.clear.onReceive(NotificationCenter.default.publisher(for: n)) { _ in }',
                     'let t = Timer.publish(every: 1, on: .main, in: .common).autoconnect()',
                     'let c = subject.sink { _ in }',
                     'let v = session.publisher(for: \\.outputVolume)',
                     'override func observeValue(forKeyPath k: String?, of o: Any?, '
                     'change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}']:
            with self.subTest(line=line):
                self.assertEqual(rules(app_findings(line + '\n')), ['legacy framework'])

    def test_swiftui_values_and_colours_that_are_not_uikit(self):
        for line in ['let c = Color(.sRGB, red: 1, green: 0, blue: 0)', 'let c = Color(.accent)',
                     'let c = Color(.labelFill)', 'let c = Color(.systematic)',
                     'TextField("Name", text: $t).keyboardType(UIKeyboardType.asciiCapable)',
                     'TextField("Name", text: $t).textContentType(UITextContentType.name)',
                     'TextField("Name", text: $t).keyboardType(.asciiCapable)',
                     'let u = URL.init(.applicationSupportDirectory)', 'let f: Font = .init(.body)',
                     'let s = LinkStyle.init(.link)',
                     # Foundation's typed notification messages are the current way.
                     'let t = center.addObserver(of: session, for: .interruption) { _ in go() }']:
            with self.subTest(line=line):
                self.assertEqual(app_findings(line + '\n'), [])

    def test_methods_brickson_names_like_combines_operators_are_its_own(self):
        for text in ['struct Phrase { func assign(to category: String) {} }\n'
                     'func file(_ p: Phrase) { p.assign(to: "Needs") }\n',
                     'struct Audio { func sink(_ x: Int) {}; func go() { sink(1) } }\n',
                     'func go(_ p: Pair) { p.sink(left, right) }\n',
                     'func go(_ s: Shelf) { s.autoconnect(to: s) }\n',
                     'struct Pipe { func sink(_ body: () -> Void) {} }\n'
                     'func go(_ p: Pipe) { p.sink { } }\n',
                     'struct Box { var x = 0; func assign(to path: WritableKeyPath<Box, Int>, '
                     'on box: Box) {} }\nfunc go(_ b: Box) { b.assign(to: \\.x, on: b) }\n',
                     'func publisher(for name: String) -> Int { 0 }\nlet p = publisher(for: n)\n',
                     'func publish(every interval: Double) {}\nfunc go() { publish(every: 1) }\n',
                     'struct Wire { func autoconnect() {} }\nfunc go(_ w: Wire) { w.autoconnect() }\n']:
            with self.subTest(text=text):
                self.assertEqual(app_findings(text), [])
        # Each of Combine's names: Brickson's own when it declares it, and
        # Combine's when it does not.
        for declaration, use in [
                ('struct Center { func publisher(for name: String) -> Int { 0 } }',
                 'func go(_ c: Center) -> Int { c.publisher(for: n) }'),
                ('struct Clock { func publish(every s: Double) {} }',
                 'func go(_ c: Clock) { c.publish(every: 1) }'),
                ('struct Deferred<T> { init(_ make: () -> T) {} }', 'let d = Deferred { 1 }'),
                ('struct Empty {}', 'let e = Empty()'),
                ('struct Fail<E> { init(error: E) {} }', 'let f = Fail(error: 1)'),
                ('struct Record { init(name: String) {} }', 'let r = Record(name: n)')]:
            with self.subTest(use=use):
                self.assertEqual(app_findings(f'{declaration}\n{use}\n'), [])
                self.assertEqual(rules(app_findings(use + '\n')), ['legacy framework'])
        # Without Brickson's own declaration, the same call is Combine's.
        self.assertEqual(rules(app_findings('func go(_ p: Pipe) { p.sink { } }\n')),
                         ['legacy framework'])
        # Names, values and calls that are not Combine's operators at all.
        for text in ['if let sink { sink.write(line) }\n',
                     'switch sink {\ncase .speaker: break\ndefault: break\n}\n',
                     'let publisher = book.publisher\n', 'func share(publish: Bool) {}\n',
                     'let assign = phrase.category\n', 'p.assign(to: "Needs")\n',
                     'let n = sink(1)\n', 'let f = Future\n', 'func go(_ s: Store) { s.publish(draft) }\n',
                     'struct Just { init() {} }\nlet j = Just()\n',
                     'struct Future<Value> {}\nlet f = Future<Int>()\n']:
            with self.subTest(text=text):
                self.assertEqual(app_findings(text), [])

    def test_a_type_brickson_declares_is_not_mistaken_for_uikit(self):
        text = 'enum UITestStorage { case standard }\nlet s = UITestStorage.standard\n'
        self.assertEqual(app_findings(text), [])
        for declaration in ['struct UIState {}', 'final class UIModel {}', 'actor UIStore {}',
                            'protocol UIThing {}', 'typealias UIAlias = Int',
                            'enum INSettings {}', 'struct CKLabel {}']:
            name = declaration.split()[-2] if declaration.endswith('{}') else declaration.split()[1]
            with self.subTest(declaration=declaration):
                self.assertEqual(app_findings(f'{declaration}\nlet x: {name}? = nil\n'), [])
                self.assertNotEqual(app_findings(f'let x: {name}? = nil\n'), [])
        # Only a framework's prefix is excused: a type of Brickson's own
        # named like a forbidden API is still found.
        self.assertEqual(rules(app_findings('struct TapGesture {}\nlet g = TapGesture()\n')),
                         ['gesture', 'gesture'])
        self.assertEqual(rules(app_findings('struct Published {}\nlet p = Published()\n')),
                         ['legacy framework'])

    def test_a_method_of_its_own_called_rollback_is_only_found_where_called(self):
        self.assertEqual(app_findings('func rollback() {}\n'), [])
        self.assertEqual(app_findings('enum Step { case save, rollback(String) }\n'
                                      'func f(_ s: Step) { switch s { case .rollback: break\n'
                                      'default: break } }\nlet s = Step.rollback("why")\n'), [])
        self.assertEqual(rules(app_findings('func rollback() {}\nfunc g() { rollback() }\n')),
                         ['rollback'])

    def test_swiftdata_opens_without_icloud(self):
        good = ('let c = try ModelContainer(for: schema, configurations: [ModelConfiguration('
                'schema: schema, cloudKitDatabase: .none)])\n')
        self.assertEqual(app_findings(good), [])
        for bad in ['let c = ModelConfiguration(schema: schema)',
                    'let c = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)',
                    'let c = try ModelContainer(for: Phrase.self)',
                    'WindowGroup { Home() }.modelContainer(for: Phrase.self)',
                    # The same, with the type said only by its context.
                    'let c = try ModelContainer(for: Phrase.self, configurations: .init(url: u))',
                    'let c = try ModelContainer(for: s, configurations: [.init(schema: s)])',
                    'let c = try ModelContainer(for: s, configurations: [.init(url: u, '
                    'cloudKitDatabase: .none), .init(schema: s)])',
                    'let c: ModelConfiguration = .init(url: u)',
                    'let c: ModelContainer = try .init(for: Phrase.self)',
                    'static var c: ModelConfiguration {\n    .init(schema: s, isStoredInMemoryOnly: false)\n}',
                    'func c() -> ModelConfiguration {\n    return .init(url: u)\n}',
                    'let c = make(.init(isStoredInMemoryOnly: true))',
                    'let c = make(.init(groupContainer: .none))',
                    'let c = make(.init(allowsSave: false))',
                    'let c = make(.init(cloudKitDatabase: .automatic))',
                    'var c: ModelContainer {\n    try! .init(for: Phrase.self)\n}',
                    'let c = try ModelContainer(for: s, configurations: ModelConfiguration.init(url: u))',
                    'let c = try ModelContainer.init(for: Phrase.self)',
                    'let c: ModelContainer = try .init(for: Phrase.self, configurations: .init(url: u))',
                    'let c: [ModelConfiguration] = [.init()]',
                    'let c: [ModelConfiguration] = [.init(url: u, cloudKitDatabase: .none), '
                    '.init(url: v)]',
                    'enum Store {\n    static func open() throws -> ModelContainer {\n'
                    '        let schema = Schema([Phrase.self])\n'
                    '        return try .init(for: schema)\n    }\n}',
                    'var c: ModelConfiguration {\n    let u = URL.documentsDirectory\n'
                    '    return .init(url: u)\n}',
                    'var c: ModelContainer = {\n    let s = Schema([Phrase.self])\n'
                    '    return try! .init(for: s)\n}()',
                    'var container: ModelContainer?\n'
                    'func open() throws { container = try .init(for: Phrase.self) }',
                    'private let container: ModelContainer\n'
                    'init() throws { self.container = try .init(for: Phrase.self) }',
                    # A comment of any length between the type and the call.
                    'static var c: ModelConfiguration {\n    // In Application Support, which '
                    '`openForApp` creates first, so a new install opens without\n    // '
                    'SwiftData\'s page of alarming errors, and this comment runs on and on and on '
                    'past the end of any window of characters.\n    .init(schema: s, url: u)\n}',
                    # Closures, ternaries, if and switch expressions.
                    'let make: () throws -> ModelContainer = { try .init(for: Phrase.self) }',
                    'func open(make: () throws -> ModelContainer = { try .init(for: s) }) {}',
                    'static let c: ModelConfiguration = { .init(url: u) }()',
                    'let make: (Bool) -> ModelConfiguration = { fast in fast ? .init(url: u) : '
                    '.init(url: v, cloudKitDatabase: .none) }',
                    'let c: ModelConfiguration = testing ? .init(url: t) : '
                    'ModelConfiguration(url: u, cloudKitDatabase: .none)',
                    'let c: ModelConfiguration = storage == .standard ? '
                    'PhraseLibraryStore.persistentConfiguration : .init(schema: s, url: u)',
                    'let c: ModelContainer = try inMemory\n    ? .init(for: s, configurations: x)\n'
                    '    : .init(for: s)',
                    'var c: ModelConfiguration {\n    switch storage {\n'
                    '    case .standard: PhraseLibraryStore.persistentConfiguration\n'
                    '    case .test: .init(schema: s, url: u)\n    }\n}',
                    'var c: ModelConfiguration {\n    switch storage {\n'
                    '    case .standard: PhraseLibraryStore.persistentConfiguration\n'
                    '    default: .init(schema: s, url: u)\n    }\n}',
                    'func c() -> ModelConfiguration {\n    if testing { .init(url: u, '
                    'cloudKitDatabase: .none) } else { .init(schema: s) }\n}',
                    'let c: ModelConfiguration = if testing { ModelConfiguration(url: u, '
                    'cloudKitDatabase: .none) } else if fast { .init(url: v, cloudKitDatabase: '
                    '.none) } else { .init(schema: s) }',
                    'func c() -> ModelConfiguration {\n    guard ready else { return .init(url: u) }\n'
                    '    return ModelConfiguration(url: u, cloudKitDatabase: .none)\n}',
                    'var c: ModelConfiguration {\n    get { .init(url: u) }\n}',
                    # Optional types.
                    'let c: ModelContainer? = try? .init(for: Phrase.self)',
                    'func open() -> ModelContainer? {\n    return try? .init(for: Phrase.self)\n}',
                    'var c: ModelContainer! = try! .init(for: Phrase.self)',
                    'let configs: [ModelConfiguration]? = [.init(url: u)]',
                    'var configs: [ModelConfiguration] = []\nfunc f() { configs = [.init(url: u)] }',
                    # Self in an extension of the type.
                    'extension ModelConfiguration {\n    static var brickson: Self { Self(schema: s) }\n}',
                    'extension ModelConfiguration {\n    static var brickson: Self { .init(schema: s) }\n}',
                    'extension ModelContainer {\n    static func brickson() throws -> Self '
                    '{ try Self(for: Phrase.self) }\n}',
                    'extension ModelConfiguration {\n    init(brickson: Void) { self.init(schema: s) }\n}',
                    # The label must be the call's own, not a nested call's.
                    'let c = ModelConfiguration(schema: s, url: make(cloudKitDatabase: .none))',
                    'let c = try ModelContainer(for: s, migrationPlan: plan(configurations: c))',
                    'let c: ModelConfiguration = saved ?? .init(url: u)',
                    'let c: ModelConfiguration = saved\n    ?? .init(url: u)',
                    'let c: [ ModelConfiguration ] = [.init()]',
                    'extension ModelConfiguration {\n    static func brickson() -> Self {\n'
                    '        return .init(schema: s)\n    }\n}',
                    # A container's configurations are variadic.
                    'let c = try ModelContainer(for: s, configurations: ModelConfiguration(url: u, '
                    'cloudKitDatabase: .none), .init(url: v))',
                    # A return inside each kind of statement.
                    'func c() -> ModelConfiguration {\n    if testing { return .init(url: t) }\n'
                    '    return d\n}',
                    'func c() -> ModelConfiguration {\n    if testing { return d } else { return '
                    '.init(url: t) }\n}',
                    'func c() -> ModelConfiguration {\n    switch storage {\n'
                    '    case .test: return .init(url: t)\n    default: return d\n    }\n}',
                    'func c() -> ModelConfiguration {\n    for u in urls { return .init(url: u) }\n'
                    '    return d\n}',
                    'func c() -> ModelConfiguration {\n    while waiting { return .init(url: t) }\n'
                    '    return d\n}',
                    'func c() -> ModelConfiguration {\n    repeat { return .init(url: t) } while waiting\n}',
                    'func c() throws -> ModelConfiguration {\n'
                    '    do { return try .init(url: load()) } catch { return d }\n}',
                    'func c() -> ModelConfiguration {\n'
                    '    do { return try make() } catch { return .init(url: t) }\n}',
                    'var c: ModelConfiguration {\n    get { return .init(url: t) }\n}',
                    'struct S {\n    var c: ModelConfiguration {\n'
                    '        mutating get { return .init(url: t) }\n    }\n}',
                    'struct S {\n    var c: ModelConfiguration {\n'
                    '        nonmutating get { return .init(url: t) }\n    }\n}',
                    # A return's value starts after `return`, not in the line before.
                    'func c() -> ModelConfiguration {\n    let fast = d\n'
                    '    return testing ? .init(url: t) : fast\n}',
                    # A closure's value starts after `in`, whatever its parameters.
                    'let make: (Bool, Bool) -> ModelConfiguration = { a, b in a ? .init(url: u) : d }',
                    # A name declared with the type, assigned later.
                    'var configuration: ModelConfiguration?\n'
                    'func f() { configuration = .init(url: u) }',
                    # A function that returns an array of them.
                    'func configs() -> [ModelConfiguration] {\n    [.init(url: u)]\n}',
                    # Each initializer's labels, and its unlabelled arguments.
                    'let c: ModelConfiguration = .init("Brickson", schema: s)',
                    'let c: ModelConfiguration = .init(for: Phrase.self, isStoredInMemoryOnly: true)',
                    'let c: ModelContainer = try .init(for: Phrase.self, Category.self)',
                    'let c: ModelContainer = try .init(for: s, migrationPlan: Plan.self)',
                    # An array returned with no space after `return`, an item after
                    # one that holds `??`, and an extension's array of Self.
                    'func c() -> [ModelConfiguration] {\n    return[.init(url: u)]\n}',
                    'let c: [ModelConfiguration] = [saved ?? d, .init(url: u)]',
                    'extension ModelConfiguration {\n    static var all: [Self] { [.init(url: u)] }\n}',
                    'extension ModelConfiguration {\n    static func all() -> [Self] {\n'
                    '        return [.init(url: u)]\n    }\n}',
                    # A name declared twice with the same type keeps it.
                    'var c: ModelConfiguration?\nstruct S { var c: ModelConfiguration? }\n'
                    'func f() { c = .init(url: u) }',
                    # The nearest declaration around the use, or every one when
                    # they agree; a type made where the name is declared.
                    'var c: ModelConfiguration?\nstruct S { var c: ModelContainer? }\n'
                    'func f() { c = .init(url: u) }',
                    'struct A { var c: ModelConfiguration? }\n'
                    'extension A { func f() { c = .init(url: u) } }',
                    'func reopen() throws {\n    var container = try ModelContainer(for: s, '
                    'configurations: c)\n    container = try .init(for: s)\n}',
                    'var configuration = ModelConfiguration(schema: s, cloudKitDatabase: .none)\n'
                    'func f() { configuration = .init(schema: s, url: u) }',
                    'enum Store {\n    static var shared: ModelContainer?\n'
                    '    static func open() throws {\n'
                    '        Self.shared = try .init(for: Phrase.self)\n    }\n}',
                    # A configuration in a container on a case's line.
                    'static func make(for storage: Storage) throws -> ModelContainer {\n'
                    '    switch storage {\n'
                    '    case .standard: return try ModelContainer(for: s, configurations: c)\n'
                    '    case .memory: return try ModelContainer(for: s, configurations: '
                    '.init(isStoredInMemoryOnly: true))\n    }\n}',
                    # A label only ModelConfiguration takes wins over a context
                    # that says another type.
                    'let c: ModelContainer = .init(isStoredInMemoryOnly: true)',
                    # A closure that names its result.
                    'let all = names.map { name -> ModelConfiguration in\n'
                    '    .init(name, schema: s, url: u)\n}',
                    'let all = names.map { name -> ModelConfiguration in\n    let url = u\n'
                    '    return .init(name, schema: s, url: url)\n}',
                    'let all = names.map { [weak self] (name: String) throws -> ModelConfiguration '
                    'in\n    .init(name, schema: s, url: u)\n}',
                    # Each branch of #if is the body's one expression.
                    'static var c: ModelConfiguration {\n    #if DEBUG\n'
                    '    .init(schema: s, url: debugURL)\n    #else\n'
                    '    .init(schema: s, url: u, cloudKitDatabase: .none)\n    #endif\n}',
                    'static var c: ModelConfiguration {\n    #if DEBUG\n'
                    '    .init(schema: s, url: u, cloudKitDatabase: .none)\n    #elseif TESTING\n'
                    '    ModelConfiguration(url: t, cloudKitDatabase: .none)\n    #else\n'
                    '    .init(schema: s, url: u)\n    #endif\n}',
                    'static var c: ModelConfiguration {\n    #if DEBUG\n    #if os(iOS)\n'
                    '    ModelConfiguration(url: t, cloudKitDatabase: .none)\n    #endif\n'
                    '    #else\n    .init(schema: s, url: u)\n    #endif\n}',
                    'static var c: ModelConfiguration {\n    #if DEBUG\n'
                    '    .init(schema: s, url: u, cloudKitDatabase: .none)\n    #elseif TESTING\n'
                    '    .init(schema: s, url: t)\n    #endif\n}',
                    # An empty list of configurations is SwiftData's default.
                    'let c = try ModelContainer(for: s, migrationPlan: Plan.self, configurations: [])',
                    # The types written with their module, and a where clause.
                    'let c: SwiftData.ModelConfiguration = .init(schema: s, url: u)',
                    'func make() throws -> SwiftData.ModelContainer {\n    try .init(for: s)\n}',
                    'let c: [SwiftData.ModelConfiguration] = [.init(url: u)]',
                    'func make<M: PersistentModel>(for m: M.Type) throws -> ModelContainer '
                    'where M: Sendable {\n    try .init(for: m)\n}',
                    'extension ModelConfiguration {\n'
                    '    static func all<T>(_ t: T) -> [Self] where T: Sendable {\n'
                    '        [.init(url: u)]\n    }\n}',
                    # Arrays of configurations as a body's result.
                    'enum Store {\n    static var configurations: [ModelConfiguration] {\n'
                    '        [.init(schema: s, url: u)]\n    }\n}',
                    'static func configurations() -> [ModelConfiguration] {\n'
                    '    return [.init(schema: s, url: u)]\n}',
                    'let make: () -> [ModelConfiguration] = { [.init(url: u)] }',
                    'let all = { () -> [ModelConfiguration] in [.init(url: u)] }()',
                    # A container no initializer of SwiftData's makes still counts.
                    'let c: ModelContainer = .init()',
                    # Closures that name their result, called at once.
                    'enum Store {\n    static let shared = { () -> ModelContainer in\n'
                    '        return try! .init(for: Phrase.self)\n    }()\n}',
                    'let all = urls.map { url -> ModelConfiguration in .init(url: url) }',
                    # Self as a declaration's type, in an extension.
                    'extension ModelConfiguration {\n'
                    '    static let brickson: Self = .init(schema: s)\n}',
                    'extension ModelContainer {\n'
                    '    static let shared: Self? = try? .init(for: Phrase.self)\n}',
                    'extension ModelConfiguration {\n'
                    '    static let all: [Self] = [.init(schema: s)]\n}',
                    'extension ModelConfiguration {\n'
                    '    static let shared: Self = { .init(url: u) }()\n}',
                    'extension SwiftData.ModelConfiguration {\n'
                    '    static var brickson: Self { .init(schema: s) }\n}',
                    # Parentheses that only group.
                    'enum Store {\n    static let container: ModelContainer = (try? make(c)) ?? '
                    '(try! .init(for: s))\n}',
                    'let c: ModelContainer = inMemory ? (try .init(for: s, configurations: m)) : '
                    '(try .init(for: s))',
                    'func c() -> ModelConfiguration {\n    return (.init(url: u))\n}',
                    'let c: ModelConfiguration = flag ? d : (.init(url: u))',
                    # A class method of the extension is the type's own.
                    'extension ModelContainer {\n'
                    '    class func brickson() throws -> Self { try Self(for: Phrase.self) }\n}']:
            with self.subTest(line=bad):
                self.assertEqual(rules(app_findings(bad + '\n')), ['cloud sync'])
        for fine in ['let c = try ModelContainer(for: s, configurations: ModelConfiguration('
                     'url: .init(fileURLWithPath: p), cloudKitDatabase: .none))',
                     'let c = try ModelContainer(for: s, configurations: [.init(url: u, '
                     'cloudKitDatabase: .none)])',
                     'let c: ModelConfiguration = .init(url: u, cloudKitDatabase: .none)',
                     'let request: Request = .init(url: u)',
                     'let c = try ModelContainer(for: s, configurations: Settings.init(name: n).stored)',
                     'func open() throws -> ModelContainer {\n'
                     '    let c = ModelConfiguration(url: u, cloudKitDatabase: .none)\n'
                     '    return try .init(for: s, configurations: c)\n}',
                     'func name() -> String {\n    return .init(describing: x)\n}',
                     'var request: Request\nfunc f() { request = .init(url: u) }',
                     'let c: [ModelConfiguration] = [.init(url: u, cloudKitDatabase: .none)]',
                     'func open() throws -> ModelContainer {\n    var c: ModelConfiguration {\n'
                     '        let u = URL.documentsDirectory\n'
                     '        return .init(url: u, cloudKitDatabase: .none)\n    }\n'
                     '    return try .init(for: s, configurations: c)\n}',
                     'let names: [String] = [.init(describing: x)]',
                     'let c = ModelConfiguration(schema: s, cloudKitDatabase: '
                     'ModelConfiguration.CloudKitDatabase.none)',
                     # Another type's .init( inside a typed body: a closure, a
                     # nested function, or labels SwiftData's types never take.
                     'static func open(in folder: URL) throws -> ModelContainer {\n'
                     '    let stores = names.compactMap { name -> URL? in\n'
                     '        guard name.hasSuffix(x) else { return nil }\n'
                     '        return .init(filePath: name, relativeTo: folder)\n    }\n'
                     '    return try ModelContainer(for: s, configurations: c)\n}',
                     'func open() throws -> ModelContainer {\n'
                     '    let ids = items.map { _ in return .init() }\n'
                     '    return try ModelContainer(for: s, configurations: c)\n}',
                     'static var c: ModelConfiguration {\n    func storeURL() -> URL {\n'
                     '        return .init(filePath: p)\n    }\n'
                     '    return ModelConfiguration(schema: s, url: storeURL(), cloudKitDatabase: .none)\n}',
                     'func openInMemory() throws -> Store.Opened {\n    return .init(\n'
                     '        container: try Store.makeContainer(isStoredInMemoryOnly: true),\n'
                     '        isVolatile: true\n    )\n}',
                     'var container: ModelContainer?\nfunc f() { let container: URL\n'
                     '    container = .init(filePath: p) }',
                     'let c: ModelConfiguration = make(url: .init())',
                     'let x: [ModelConfiguration] = table[.init(url: u)]',
                     'let c = try ModelContainer(for: s, configurations: make(.init()))',
                     'let c = try ModelContainer(for: s, configurations: Defaults.init().stored)',
                     'func open() throws -> ModelContainer {\n'
                     '    guard let u = urls.first(where: { _ in return .init() }) else { throw E.x }\n'
                     '    return try ModelContainer(for: s, configurations: c)\n}',
                     'let v: Int = flag ? .init(1) : 2',
                     # A keyword ends the expression before it: these values are
                     # not the declaration's on the line above.
                     'func f() throws {\n    let c: ModelConfiguration = d\n'
                     '    throw failed ? .init(url: u) : e\n}',
                     'func f() {\n    let c: ModelConfiguration = d\n'
                     '    if saved ?? .init(url: u) == c {}\n}',
                     'func f() {\n    let c: ModelConfiguration = d\n'
                     '    guard saved ?? .init(url: u) == c else { return }\n}',
                     'func f() {\n    let c: ModelConfiguration = d\n'
                     '    while saved ?? .init(url: u) == c {}\n}',
                     'func f() {\n    let c: ModelConfiguration = d\n'
                     '    switch saved ?? .init(url: u) {\n    default: break\n    }\n}',
                     # A name is its nearest declaration's, or, with none around it,
                     # every declaration's when they agree.
                     'var c: ModelContainer?\n'
                     'struct S { var c: ModelConfiguration? }\nfunc f() { c = .init(url: u) }',
                     'struct A { var c: ModelConfiguration? }\nstruct B { var c: ModelContainer? }\n'
                     'extension A { func f() { c = .init(url: u) } }',
                     'struct LibraryStore {\n    let container: ModelContainer\n}\nstruct DraftBox {\n'
                     '    var container: [String]\n    mutating func clear() { container = .init() }\n}',
                     # A colon inside a call on a case's line is not the case's.
                     'var c: ModelConfiguration {\n    switch storage {\n'
                     '    case .standard: PhraseLibraryStore.persistentConfiguration\n'
                     '    case .test: ModelConfiguration(schema: .init([Phrase.self]), url: t, '
                     'cloudKitDatabase: .none)\n    }\n}',
                     'func c() -> ModelConfiguration {\n    switch storage {\n'
                     '    case .test: return make(url: .init())\n    default: return d\n    }\n}',
                     # A closure's return is the closure's, whatever #if lines are near.
                     'static func make() throws -> ModelContainer {\n    #if DEBUG\n'
                     '    let folder = a\n    #else\n    let folder = b\n    #endif\n'
                     '    let names = items.compactMap { file -> String? in\n'
                     '        guard ok else { return nil }\n        return .init(file.dropLast(6))\n'
                     '    }\n    return try ModelContainer(for: s, configurations: c)\n}',
                     # A closure inside a call's parentheses returns its own value,
                     # and a function's parameters are not statements.
                     'func c() -> ModelConfiguration {\n'
                     '    if names.contains(where: { n in return .init(url: n) == d }) { return d }\n'
                     '    return d\n}',
                     'var c: ModelConfiguration {\n'
                     '    func draft(for name: String) -> Draft { return .init(url: u) }\n'
                     '    return ModelConfiguration(url: u, cloudKitDatabase: .none)\n}',
                     # Parentheses of a call, or holding more than one value.
                     'let c: ModelConfiguration = make(.init(url: u))',
                     'let t: (ModelConfiguration, Int) = (.init(url: u), 1)',
                     'func c() -> ModelConfiguration {\n    return (.init(url: u), 1).0\n}',
                     'let c: ModelConfiguration = make?(.init(url: u)) ?? d',
                     'let c: ModelConfiguration = make!(.init(url: u))',
                     'let c: ModelConfiguration = Maker<Draft>(.init(url: u)).made',
                     # A type declared inside an extension is not the extended type.
                     'extension ModelContainer {\n    struct Options {\n        var resets = false\n'
                     '        static var standard: Self { .init() }\n    }\n}',
                     'extension ModelConfiguration {\n    enum Options {\n'
                     '        static var standard: Self { Self() }\n    }\n}',
                     'extension ModelContainer {\n    static var all: [Self] { [.init(url: u)] }\n}',
                     # Types whose names start like SwiftData's.
                     'var factory: ModelContainerFactory\nfunc f() { factory = .init(for: x) }',
                     'var kind: ModelConfiguration.Kind\nfunc f() { kind = .init() }']:
            with self.subTest(line=fine):
                self.assertEqual(app_findings(fine + '\n'), [])
        # Self inside a type nested in the extension is that type, not SwiftData's.
        for kind in ('struct', 'class', 'enum', 'actor'):
            nested = (f'extension ModelConfiguration {{\n    {kind} Maker {{\n'
                      '        static func make() -> Self { Self() }\n'
                      '        static var shared: Self { .init() }\n    }\n}\n')
            with self.subTest(kind=kind):
                self.assertEqual(app_findings(nested), [])

    def test_a_notification_observer_runs_on_the_main_actor(self):
        path = 'App/Events.swift'
        good = ('t = c.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in\n'
                '    MainActor.assumeIsolated { self?.refresh() }\n}\n')
        self.assertEqual(app_findings(good, path=path), [])
        for bad in [good.replace('queue: .main', 'queue: nil'),
                    good.replace('MainActor.assumeIsolated', 'Task { @MainActor in').replace(
                        '() }', '() } }'),
                    't = c.addObserver(forName: n, object: nil, queue: .main, using: handle)\n']:
            with self.subTest(text=bad):
                self.assertEqual(rules(app_findings(bad, path=path)), ['notification observer'])
        main_queue = good.replace('queue: .main', 'queue: OperationQueue.main')
        self.assertEqual(app_findings(main_queue, path=path), [])
        selector = ('NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)),\n'
                    '    name: AVAudioSession.interruptionNotification, object: nil)\n')
        self.assertEqual(rules(app_findings(selector, path=path)), ['notification observer'])
        # In a file the table does not name, it is a legacy observer too.
        self.assertEqual(set(rules(app_findings(selector, path='App/Other.swift'))),
                         {'legacy framework', 'notification observer'})
        kvo = 'session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)\n'
        self.assertEqual(app_findings(kvo, path='App/Monitor.swift'), [])

    def test_findings_name_the_place_and_never_the_code(self):
        findings = app_findings('let phrase = "Call my sister"; let s = URLSession.shared\n')
        self.assertEqual(len(findings), 1)
        self.assertEqual((findings[0].path, findings[0].line), ('App/Example.swift', 1))
        self.assertNotIn('sister', str(findings[0]))

    def test_no_list_contradicts_another(self):
        self.assertFalse(set(forbidden.FORBIDDEN_IMPORTS) & forbidden.APP_IMPORTS)
        self.assertFalse(set(forbidden.FAMILY_BY_MODULE) & forbidden.APP_IMPORTS)
        self.assertFalse(set(forbidden.FAMILY_BY_MODULE) & set(forbidden.FORBIDDEN_IMPORTS))


class TableTests(unittest.TestCase):
    """The kept legacy APIs come from docs/DECISIONS.md's table, and a
    table the check can no longer read stops it rather than passing."""

    def test_rows_allow_the_files_they_name(self):
        allowed = forbidden.allowed_files(DECISIONS_TEXT)
        self.assertEqual(allowed['UIKit'], {'Palette'})
        self.assertEqual(allowed['Dispatch'], {'Speaker', 'forward'})
        self.assertEqual(allowed['NotificationCenter observers'], {'Events'})
        self.assertEqual(allowed['key-value observation'], {'Monitor'})
        for family in ('Combine', 'SafariServices', 'Core Data', 'SiriKit', 'XCTest'):
            self.assertEqual(allowed[family], set(), family)

    def test_each_way_a_row_names_its_framework(self):
        samples = {'UIKit': ['`UIColor.systemBackground`', 'UIKit types'],
                   'SafariServices': ['`SFSafariViewController`', 'SafariServices'],
                   'Dispatch': ['`DispatchQueue.main.async`', '`dispatch_async`'],
                   'NotificationCenter observers': ['`NotificationCenter.addObserver(forName:)`'],
                   'key-value observation': ['Key-value observation', 'key-value observation'],
                   'Combine': ['Combine', '`ObservableObject`'],
                   'Core Data': ['Core Data', '`NSManagedObject`', '`NSPersistentContainer`'],
                   'SiriKit': ['SiriKit', '`INAlternativeAppNames`'],
                   'XCTest': ['XCTest', 'XCUIAutomation']}
        self.assertEqual(set(samples), {family.name for family in forbidden.FAMILIES})
        for family, whats in samples.items():
            for what in whats:
                with self.subTest(family=family, what=what):
                    text = DECISIONS_TEXT.replace('| `UIColor.systemBackground` | `Palette.screen` |',
                                                  f'| {what} | `Thing` |')
                    self.assertIn('Thing', forbidden.allowed_files(text)[family])

    def test_a_row_allows_only_its_own_framework(self):
        self.assertEqual(rules(app_findings('let q = DispatchQueue.main\n', path='App/Palette.swift')),
                         ['legacy framework'])

    def test_a_file_named_by_its_path(self):
        text = DECISIONS_TEXT.replace('`Palette.screen`', '`Brickson/App/Palette.swift`')
        self.assertEqual(forbidden.allowed_files(text)['UIKit'], {'Palette'})

    def test_a_missing_section_table_or_rows_stops_the_check(self):
        for text in [DECISIONS_TEXT.replace("## Apple's current frameworks first", '## Renamed'),
                     DECISIONS_TEXT.replace('| What | Where |', '| API | File |'),
                     DECISIONS_TEXT.split('|---')[0] + '\n## End\n']:
            with self.subTest(text=text[-60:]):
                with self.assertRaises(forbidden.SetupError):
                    forbidden.allowed_files(text)

    def test_a_heading_inside_fenced_code_does_not_end_the_section(self):
        text = DECISIONS_TEXT.replace('Kept, and why.', 'Kept.\n\n```sh\n# a comment\n```\n')
        self.assertEqual(forbidden.allowed_files(text)['UIKit'], {'Palette'})


class TestRuleTests(unittest.TestCase):
    """Known issues are strict and cite their decision; skips say why."""

    def test_a_known_issue_cites_its_decision(self):
        good = ('withKnownIssue("docs/DECISIONS.md, \\"The layout engine\\": the narrowest") '
                '{ #expect(x == 0) }\n')
        self.assertEqual(test_findings(good), [])
        interpolated = ('withKnownIssue("docs/DECISIONS.md, \\"Tests\\": the '
                        '\\(isGaze ? "gaze" : "dwell") floor") { #expect(x) }\n')
        self.assertEqual(test_findings(interpolated), [])
        for bad in ['withKnownIssue("flaky on CI") { #expect(x) }',
                    'withKnownIssue { #expect(x) }',
                    'withKnownIssue(isIntermittent: false) { #expect(x) }',
                    'XCTExpectFailure("broken")']:
            with self.subTest(line=bad):
                self.assertEqual(rules(test_findings(bad + '\n')), ['known issue'])

    def test_a_known_issue_is_strict(self):
        for bad in ['withKnownIssue("docs/DECISIONS.md, \\"Tests\\": x", isIntermittent: true) { }',
                    'options.isStrict = false',
                    'XCTExpectFailure("docs/DECISIONS.md, \\"Tests\\": x", options: .nonStrict())',
                    'XCTExpectFailure("docs/DECISIONS.md, \\"Tests\\": x", strict: false)']:
            with self.subTest(line=bad):
                self.assertEqual(rules(test_findings(bad + '\n')), ['known issue'])

    def test_a_skip_says_why(self):
        for good in ['throw XCTSkip("iPhone is portrait only")',
                     'try XCTSkipIf(isPhone, "the iPhone is portrait only")',
                     'try XCTSkipUnless(\n    Self.isEnabled,\n    "An opt-in probe"\n)',
                     '@Test(.disabled("Crashes on iOS 26.5 (issue #19)")) func a() {}',
                     '@Test(.enabled(if: f(V(major: 27)), "Exists from iOS 27")) func a() {}',
                     '@Suite(.serialized, .disabled("Needs a device")) struct S {}',
                     'try XCTSkipIf(mode == "ci", "CI has no microphone")',
                     '@Test(.disabled(if: mode == "ci", "Needs a Mac")) func a() {}',
                     'try XCTSkipIf(mode == "ci", "No microphone", file: "T.swift", line: 3)',
                     'Button("Go") {}.disabled(isBusy)']:
            with self.subTest(line=good):
                self.assertEqual(test_findings(good + '\n'), [])
        for bad in ['throw XCTSkip()', 'try XCTSkipIf(isPhone)',
                    'try XCTSkipUnless(Self.isEnabled, reason)',
                    '@Test(.disabled()) func a() {}', '@Test(.disabled(if: isCI)) func a() {}',
                    '@Test(.enabled(if: f("not the reason"))) func a() {}',
                    '@Suite(.serialized, .disabled) struct S {}',
                    # A string in the condition says nothing of why.
                    'try XCTSkipIf(mode == "ci")', 'try XCTSkipUnless(name != "")',
                    '@Test(.enabled(if: mode == "ci")) func a() {}',
                    '@Test(.disabled(if: mode == "ci")) func a() {}',
                    # Nor does a string in another labelled argument.
                    'try XCTSkipIf(mode == "ci", nil, file: "Test.swift")',
                    'throw XCTSkip(file: "Test.swift")',
                    '@Test(.disabled(if: isCI, sourceLocation: at("Test.swift"))) func a() {}']:
            with self.subTest(line=bad):
                self.assertEqual(rules(test_findings(bad + '\n')), ['unexplained skip'])


class YamlReadingTests(unittest.TestCase):
    """The small YAML reader sees the keys a rule needs, and never mistakes
    a shell line for one."""

    def test_paths_lists_and_block_scalars(self):
        entries = forbidden.yaml_entries(WORKFLOW)
        paths = [entry.path for entry in entries]
        self.assertIn(('jobs', 'unit', 'steps', '-', 'uses'), paths)
        self.assertIn(('jobs', 'unit', 'steps', '-', 'with', 'persist-credentials'), paths)
        self.assertNotIn('key', [entry.key for entry in entries])
        run = next(entry for entry in entries if entry.key == 'run')
        self.assertIn('echo "key: value"', run.block)

    def test_a_block_scalar_that_is_a_list_item_is_text(self):
        entries = forbidden.yaml_entries('args:\n  - |\n    uses: some/thing@v1\n  - b\nname: x\n')
        self.assertEqual([(entry.path, entry.key, entry.value) for entry in entries],
                         [(('args',), 'args', ''), (('args', '-'), '', ''),
                          (('args', '-'), '', 'b'), (('name',), 'name', 'x')])
        self.assertIn('uses: some/thing@v1', entries[1].block)

    def test_quoted_keys_and_keys_that_start_with_a_dash(self):
        entries = forbidden.yaml_entries("'on': push\n\"jobs\": x\n-flag: 1\n- item\n")
        self.assertEqual([(entry.path, entry.key, entry.value) for entry in entries],
                         [(('on',), 'on', 'push'), (('jobs',), 'jobs', 'x'),
                          (('-flag',), '-flag', '1'), (('-',), '', 'item')])

    def test_flow_mappings(self):
        self.assertEqual(forbidden.flow_mapping('{ a: [1, 2], "b": { c: d }, e: f }'),
                         [('a', '[1, 2]'), ('b', '{ c: d }'), ('e', 'f')])
        self.assertEqual(forbidden.flow_mapping('{ "a: b": c }'), [('a: b', 'c')])
        self.assertEqual(forbidden.flow_mapping('{ }'), [])
        self.assertIsNone(forbidden.flow_mapping('[a, b]'))

    def test_one_line_mappings_are_entries_too(self):
        entries = forbidden.yaml_entries('a: { b: 1, "c": { d: x } }\n')
        self.assertEqual([(entry.path, entry.value, entry.inline) for entry in entries],
                         [(('a',), '{ b: 1, "c": { d: x } }', False), (('a', 'b'), '1', True),
                          (('a', 'c'), '{ d: x }', True), (('a', 'c', 'd'), 'x', True)])
        entries = forbidden.yaml_entries('- { e: f }\n')
        self.assertEqual([(entry.path, entry.key, entry.value) for entry in entries],
                         [(('-',), '', '{ e: f }'), (('-', 'e'), 'e', 'f')])

    def test_a_value_carried_over_lines_is_one_value(self):
        entries = forbidden.yaml_entries('a: [x,\n  y]\nb: "one\n  # two"\nc: {d: e,\n  f: g}\n'
                                         'h: i\n')
        self.assertEqual([(entry.path, entry.value) for entry in entries],
                         [(('a',), '[x, y]'), (('b',), 'one # two'), (('c',), '{d: e, f: g}'),
                          (('c', 'd'), 'e'), (('c', 'f'), 'g'), (('h',), 'i')])
        self.assertTrue(forbidden.unclosed('"a \\" b'))
        self.assertFalse(forbidden.unclosed("'it''s'"))
        self.assertTrue(forbidden.unclosed("'it''s"))

    def test_what_a_value_holds_is_read_as_yaml_reads_it(self):
        # An apostrophe inside a word is not a quote.
        entries = forbidden.yaml_entries("- { name: Apple's release, run: x }\nb: [it's, y]\nc: d\n")
        self.assertEqual([(entry.path, entry.value) for entry in entries], [
            (('-',), "{ name: Apple's release, run: x }"), (('-', 'name'), "Apple's release"),
            (('-', 'run'), 'x'), (('b',), "[it's, y]"), (('c',), 'd')])
        self.assertEqual(forbidden.flow_list("[it's, 'a, b', \"c, d\", e]"),
                         ["it's", 'a, b', 'c, d', 'e'])
        # An anchor or a tag names a value; it is not the value.
        entries = forbidden.yaml_entries('a: &x { b: 1 }\nc: !!str d\ne: &y\n  f: g\n')
        self.assertEqual([(entry.path, entry.value) for entry in entries], [
            (('a',), '{ b: 1 }'), (('a', 'b'), '1'), (('c',), 'd'), (('e',), ''),
            (('e', 'f'), 'g')])
        # A one-line list's mappings.
        entries = forbidden.yaml_entries('a: [{ b: 1 }, c, { d: [{ e: f }] }]\n')
        self.assertEqual([(entry.path, entry.value) for entry in entries], [
            (('a',), '[{ b: 1 }, c, { d: [{ e: f }] }]'), (('a', '-', 'b'), '1'),
            (('a', '-', 'd'), '[{ e: f }]'), (('a', '-', 'd', '-', 'e'), 'f')])
        # A quoted value is a string, even one that starts like a collection.
        entries = forbidden.yaml_entries("a: { b: '[0-9]+', c: \"{x}\" }\nd: ['[e]']\n")
        self.assertEqual([(entry.path, entry.value) for entry in entries], [
            (('a',), "{ b: '[0-9]+', c: \"{x}\" }"), (('a', 'b'), '[0-9]+'), (('a', 'c'), '{x}'),
            (('d',), "['[e]']")])
        # Escaped quote marks before a # that is not a comment.
        entries = forbidden.yaml_entries('a: "x \\" #1"\nb: \'it\'\'s #2\'\nc: d\n')
        self.assertEqual([(entry.path, entry.value) for entry in entries], [
            (('a',), 'x \\" #1'), (('b',), "it''s #2"), (('c',), 'd')])

    def test_a_list_at_its_keys_indent_and_comments(self):
        entries = forbidden.yaml_entries('sources:\n- App # the app\n- path: Shared\n  type: group\n'
                                         'name: "#not a comment"\n')
        self.assertEqual([(entry.path, entry.value) for entry in entries],
                         [(('sources',), ''), (('sources', '-'), 'App'),
                          (('sources', '-', 'path'), 'Shared'), (('sources', '-', 'type'), 'group'),
                          (('name',), '#not a comment')])


class ProjectTests(unittest.TestCase):
    """project.yml and the files beside it."""

    def findings(self, project=PROJECT, files=(), texts=None, decisions=DECISIONS_TEXT):
        texts = texts or {}
        return forbidden.check_project(forbidden.yaml_entries(project), list(files),
                                       lambda path: texts.get(path, ''), decisions)

    def test_the_fixture_passes(self):
        self.assertEqual(self.findings(), [])

    def test_third_party_packages(self):
        for project in [PROJECT + 'packages:\n  Lottie:\n    url: https://example.com/x\n',
                        PROJECT + 'localPackages:\n  - ../Shared\n',
                        PROJECT + 'projectReferences:\n  Other:\n    path: ../Other.xcodeproj\n',
                        PROJECT.replace('dependencies: []', 'dependencies:\n      - bundle: X.bundle'),
                        PROJECT.replace('dependencies: []', 'dependencies:\n      - package: Lottie'),
                        PROJECT.replace('dependencies: []',
                                        'dependencies:\n      - framework: Vendor/X.xcframework'),
                        PROJECT.replace('dependencies: []', 'dependencies:\n      - carthage: X')]:
            with self.subTest(project=project[-60:]):
                self.assertEqual(rules(self.findings(project)), ['third-party package'])
        for path in ['Package.swift', 'Shared/Package.resolved', 'Podfile', 'Podfile.lock',
                     'Cartfile', 'Cartfile.resolved', 'Cartfile.private',
                     'Vendor/Analytics.xcframework/Info.plist', 'Vendor/X.framework/X',
                     'Vendor/libx.a', 'Vendor/libx.dylib', '.gitmodules']:
            with self.subTest(path=path):
                self.assertEqual(rules(self.findings(files=[path])), ['third-party package'])

    def test_apple_sdks_and_targets_are_dependencies_too(self):
        project = PROJECT.replace('dependencies: []',
                                  'dependencies:\n      - sdk: AVFAudio.framework\n      - target: X')
        self.assertEqual(self.findings(project), [])

    def test_capabilities_and_info_keys(self):
        info = PROJECT.replace('UIBackgroundModes: [audio]', '{}')
        for key in ['com.apple.developer.icloud-services', 'aps-environment',
                    'com.apple.developer.ubiquity-kvstore-identifier',
                    'com.apple.developer.applesignin', 'com.apple.developer.networking.wifi-info',
                    'NSUserTrackingUsageDescription', 'NSAppTransportSecurity', 'NSBonjourServices',
                    'NSLocalNetworkUsageDescription']:
            with self.subTest(key=key, place='project.yml'):
                project = info.replace('{}', f'\n        {key}: x')
                self.assertEqual(rules(self.findings(project)), ['capability'])
            with self.subTest(key=key, place='entitlements'):
                text = f'<plist><dict><key>{key}</key><true/></dict></plist>\n'
                found = self.findings(files=['App/App.entitlements'],
                                      texts={'App/App.entitlements': text})
                self.assertEqual([(f.path, f.rule) for f in found],
                                 [('App/App.entitlements', 'capability')])
        for key in ['NSUserTrackingUsageDescription', 'NSLocalNetworkUsageDescription']:
            with self.subTest(key=key, place='an INFOPLIST_KEY_ build setting'):
                project = PROJECT.replace('    IPHONEOS', f'    INFOPLIST_KEY_{key}: x\n    IPHONEOS')
                self.assertEqual(rules(self.findings(project)), ['capability'])
            with self.subTest(key=key, place='an .xcconfig file'):
                found = self.findings(files=['Config/App.xcconfig'],
                                      texts={'Config/App.xcconfig': f'INFOPLIST_KEY_{key} = x\n'})
                self.assertEqual(rules(found), ['capability'])
        for modes in ['[audio, remote-notification]', '\n          - audio\n          - fetch']:
            with self.subTest(modes=modes):
                project = PROJECT.replace('[audio]', modes)
                self.assertEqual(rules(self.findings(project)), ['capability'])
        for properties in ['{ UIBackgroundModes: [audio, fetch] }', '{ NSBonjourServices: [x] }',
                           '{ UIBackgroundModes: [\n          audio,\n          fetch\n        ] }']:
            with self.subTest(properties=properties):
                project = PROJECT.replace('      properties:\n        UIBackgroundModes: [audio]\n',
                                          f'      properties: {properties}\n')
                self.assertEqual(rules(self.findings(project)), ['capability'])
        plist = ('<plist><dict><key>UIBackgroundModes</key>\n<array>\n<string>audio</string>\n'
                 '<string>fetch</string>\n</array></dict></plist>\n')
        # Under any name: INFOPLIST_FILE and CODE_SIGN_ENTITLEMENTS take any.
        for path in ['App/Info.plist', 'App/App-Info.plist']:
            with self.subTest(path=path):
                self.assertEqual(rules(self.findings(files=[path], texts={path: plist})),
                                 ['capability'])
        cloud = '<plist><dict><key>com.apple.developer.icloud-services</key></dict></plist>\n'
        self.assertEqual(rules(self.findings(files=['App/Entitlements.plist'],
                                             texts={'App/Entitlements.plist': cloud})),
                         ['capability'])

    def test_a_comment_naming_a_capability_is_not_one(self):
        project = PROJECT.replace('UIBackgroundModes: [audio]',
                                  'UIBackgroundModes: [audio]  # never aps-environment')
        self.assertEqual(self.findings(project), [])

    def test_warnings_stay_errors(self):
        for project in [PROJECT.replace('SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"',
                                        'SWIFT_TREAT_WARNINGS_AS_ERRORS: "NO"'),
                        PROJECT.replace('    GCC_TREAT_WARNINGS_AS_ERRORS: "YES"\n', ''),
                        PROJECT.replace('    dependencies: []\n', '    dependencies: []\n'
                                        '    settings:\n      base:\n'
                                        '        SWIFT_TREAT_WARNINGS_AS_ERRORS: "NO"\n'),
                        PROJECT.replace('    IPHONEOS', '    SWIFT_SUPPRESS_WARNINGS: YES\n    IPHONEOS'),
                        PROJECT.replace('    IPHONEOS', '    OTHER_SWIFT_FLAGS: "-suppress-warnings"\n'
                                        '    IPHONEOS'),
                        PROJECT.replace('    IPHONEOS', '    WARNING_CFLAGS: "-w"\n    IPHONEOS')]:
            with self.subTest(project=project):
                self.assertEqual(rules(self.findings(project)), ['warnings'])
        for line in ['GCC_WARN_INHIBIT_ALL_WARNINGS: YES',
                     'OTHER_SWIFT_FLAGS: [-suppress-warnings]',
                     'OTHER_SWIFT_FLAGS: ["$(inherited)", "-suppress-warnings"]',
                     'OTHER_SWIFT_FLAGS:\n      - $(inherited)\n      - -suppress-warnings',
                     'OTHER_SWIFT_FLAGS: "-no-warnings-as-errors"',
                     'OTHER_SWIFT_FLAGS: "$(inherited) -Wwarning DeprecatedDeclaration"',
                     'SWIFT_WARNINGS_AS_WARNINGS_GROUPS: DeprecatedDeclaration',
                     'SWIFT_WARNINGS_AS_WARNINGS_GROUPS:\n      - DeprecatedDeclaration',
                     'WARNING_CFLAGS: "-Wno-deprecated-declarations"',
                     'OTHER_CFLAGS: "-Wno-error"', 'OTHER_CPLUSPLUSFLAGS: "-w"',
                     'OTHER_SWIFT_FLAGS: "-suppress-warnings -DDEBUG"',
                     # A condition after the name is the same setting.
                     '"SWIFT_TREAT_WARNINGS_AS_ERRORS[config=Debug]": "NO"',
                     'SWIFT_TREAT_WARNINGS_AS_ERRORS[sdk=iphonesimulator*]: "NO"',
                     '"SWIFT_SUPPRESS_WARNINGS[config=Debug]": YES',
                     'OTHER_SWIFT_FLAGS[sdk=iphonesimulator*]: "-suppress-warnings"',
                     '"SWIFT_WARNINGS_AS_WARNINGS_GROUPS[config=Debug]": DeprecatedDeclaration',
                     # The whole value, however YAML spreads it.
                     'OTHER_SWIFT_FLAGS:\n      - "$(inherited)"\n      - -Wwarning\n'
                     '      - DeprecatedDeclaration',
                     'OTHER_SWIFT_FLAGS: >-\n      $(inherited)\n      -suppress-warnings',
                     'OTHER_SWIFT_FLAGS: |\n      -Wwarning\n      DeprecatedDeclaration',
                     'OTHER_SWIFT_FLAGS: $(inherited)\n      -suppress-warnings',
                     'SWIFT_WARNINGS_AS_WARNINGS_GROUPS: >-\n      DeprecatedDeclaration',
                     'OTHER_SWIFT_FLAGS:\n      - $(inherited)\n      - >-\n        -suppress-warnings',
                     'OTHER_SWIFT_FLAGS: [\n      "$(inherited)",\n      -suppress-warnings\n    ]',
                     'OTHER_SWIFT_FLAGS: "$(inherited)\n      -suppress-warnings"',
                     # Xcode splits a flag setting as a shell does.
                     'OTHER_SWIFT_FLAGS: \'"-suppress-warnings"\'',
                     'WARNING_CFLAGS: \'"-Wno-deprecated-declarations"\'',
                     'OTHER_SWIFT_FLAGS: \'$(inherited) "-Wwarning" DeprecatedDeclaration\'']:
            with self.subTest(line=line):
                project = PROJECT.replace('    IPHONEOS', f'    {line}\n    IPHONEOS')
                self.assertEqual(rules(self.findings(project)), ['warnings'])
        for text in ['SWIFT_TREAT_WARNINGS_AS_ERRORS = NO', 'SWIFT_SUPPRESS_WARNINGS = YES',
                     'OTHER_SWIFT_FLAGS = $(inherited) -suppress-warnings',
                     'OTHER_SWIFT_FLAGS = $(inherited) -Wwarning deprecated',
                     'SWIFT_WARNINGS_AS_WARNINGS_GROUPS = DeprecatedDeclaration',
                     'SWIFT_TREAT_WARNINGS_AS_ERRORS[sdk=iphonesimulator*] = NO',
                     'OTHER_SWIFT_FLAGS = $(inherited) "-suppress-warnings"',
                     'OTHER_SWIFT_FLAGS = "-Wwarning" deprecated']:
            with self.subTest(xcconfig=text):
                found = self.findings(files=['Config/Base.xcconfig'],
                                      texts={'Config/Base.xcconfig': text + '\n'})
                self.assertEqual(rules(found), ['warnings'])
        # An .xcconfig comment is not part of the setting's value.
        self.assertEqual(self.findings(files=['Config/Base.xcconfig'], texts={
            'Config/Base.xcconfig': 'OTHER_SWIFT_FLAGS = $(inherited) // not -suppress-warnings\n'}),
            [])
        # A one-line mapping, and a source's own compiler flags.
        for target in ['    settings:\n      base: { SWIFT_TREAT_WARNINGS_AS_ERRORS: "NO" }\n',
                       '    settings:\n      base: { OTHER_SWIFT_FLAGS: "$(inherited) -suppress-warnings" }\n',
                       '    settings: { SWIFT_SUPPRESS_WARNINGS: "YES" }\n']:
            with self.subTest(target=target):
                project = PROJECT.replace('    dependencies: []\n', '    dependencies: []\n' + target)
                self.assertEqual(rules(self.findings(project)), ['warnings'])
        for source in ['      - path: App\n        compilerFlags: ["-w"]\n',
                       '      - path: App\n        compilerFlags:\n          - -Wno-everything\n',
                       '      - { path: App, compilerFlags: "-Wno-everything" }\n',
                       '      - path: App\n        compilerFlags: "-Wwarning DeprecatedDeclaration"\n']:
            with self.subTest(source=source):
                project = PROJECT.replace('      - App\n', source)
                self.assertEqual(rules(self.findings(project)), ['warnings'])

    def test_a_setting_that_keeps_warnings_errors_passes(self):
        for line in ['"SWIFT_TREAT_WARNINGS_AS_ERRORS[config=Release]": "YES"',
                     'OTHER_SWIFT_FLAGS:\n      - "$(inherited)"\n      - -DDEBUG',
                     'OTHER_SWIFT_FLAGS: >-\n      $(inherited)\n      -DDEBUG',
                     'SWIFT_WARNINGS_AS_WARNINGS_GROUPS: ""',
                     'EXCLUDED_ARCHS[sdk=iphonesimulator*]: ""']:
            with self.subTest(line=line):
                project = PROJECT.replace('    IPHONEOS', f'    {line}\n    IPHONEOS')
                self.assertEqual(self.findings(project), [])
        base = ('settings:\n  base:\n    SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"\n'
                '    GCC_TREAT_WARNINGS_AS_ERRORS: "YES"\n    IPHONEOS_DEPLOYMENT_TARGET: "26.0"\n')
        settings = ('SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES", GCC_TREAT_WARNINGS_AS_ERRORS: "YES", '
                    'IPHONEOS_DEPLOYMENT_TARGET: "26.0"')
        # XcodeGen reads a settings map with no base, configs or groups as
        # the base, and a one-line mapping as the same map.
        for written in ['settings:\n  SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"\n'
                        '  GCC_TREAT_WARNINGS_AS_ERRORS: "YES"\n  IPHONEOS_DEPLOYMENT_TARGET: "26.0"\n',
                        f'settings: {{ base: {{ {settings} }} }}\n', f'settings: {{ {settings} }}\n']:
            with self.subTest(settings=written):
                self.assertEqual(self.findings(PROJECT.replace(base, written)), [])
        configs = PROJECT.replace(base, 'settings:\n  configs:\n    Debug:\n      X: Y\n'
                                  '  SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"\n'
                                  '  GCC_TREAT_WARNINGS_AS_ERRORS: "YES"\n'
                                  '  IPHONEOS_DEPLOYMENT_TARGET: "26.0"\n')
        self.assertEqual(rules(self.findings(configs)), ['warnings', 'warnings'])
        flags = PROJECT.replace('      - App\n', '      - { path: App, compilerFlags: [-DDEBUG] }\n')
        self.assertEqual(self.findings(flags), [])
        # A condition never stands in for the project-wide setting.
        conditional = PROJECT.replace('SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"',
                                      '"SWIFT_TREAT_WARNINGS_AS_ERRORS[config=Debug]": "YES"')
        self.assertEqual(rules(self.findings(conditional)), ['warnings'])

    def test_the_recorded_safety_exception_turns_it_off_in_one_target(self):
        project = PROJECT.replace('    dependencies: []\n', '    dependencies: []\n'
                                  '    settings:\n      base:\n'
                                  '        SWIFT_TREAT_WARNINGS_AS_ERRORS: "NO"\n')
        decisions = DECISIONS_TEXT.replace('Every target treats a warning as an error.',
                                           'Every target treats a warning as an error. '
                                           '`App` waits for a fix (who turns it back on: x).')
        self.assertEqual(self.findings(project, decisions=decisions), [])
        for line in ['SWIFT_WARNINGS_AS_WARNINGS_GROUPS: DeprecatedDeclaration',
                     'OTHER_SWIFT_FLAGS: "$(inherited) -Wwarning DeprecatedDeclaration"']:
            narrower = project.replace('"NO"\n', f'"YES"\n        {line}\n')
            with self.subTest(line=line):
                self.assertEqual(self.findings(narrower, decisions=decisions), [])
                self.assertEqual(rules(self.findings(narrower)), ['warnings'])
        silenced = project.replace('"NO"\n', '"YES"\n        OTHER_SWIFT_FLAGS: -suppress-warnings\n')
        self.assertEqual(rules(self.findings(silenced, decisions=decisions)), ['warnings'])

    def test_no_yaml_form_hides_a_project_rule(self):
        for target, expected in [
                # An apostrophe in a one-line list, then a slip.
                ("    tags: [{ name: it's }]\n    settings:\n      base:\n"
                 '        SWIFT_SUPPRESS_WARNINGS: "YES"\n', 'warnings'),
                # An anchor before a one-line mapping.
                ('    settings: &s { base: { SWIFT_SUPPRESS_WARNINGS: "YES" } }\n', 'warnings'),
                # One-line lists of mappings.
                ('    dependencies: [{ framework: Vendor/A.framework }]\n', 'third-party package')]:
            with self.subTest(target=target):
                project = PROJECT.replace('    dependencies: []\n', target)
                self.assertEqual(rules(self.findings(project)), [expected])
        sources = PROJECT.replace('      - App\n      - path: site/privacy\n        type: folder\n',
                                  '    sources: [{ path: App, compilerFlags: "-suppress-warnings" }]\n'
                                  ).replace('    sources:\n    sources:', '    sources:')
        self.assertEqual(rules(self.findings(sources)), ['warnings'])
        # Compiler flags for a kind of file reach every such file.
        file_types = PROJECT.replace('options:\n', 'options:\n  fileTypes:\n    swift:\n'
                                     '      compilerFlags: ["-suppress-warnings"]\n')
        self.assertEqual(rules(self.findings(file_types)), ['warnings'])

    def test_the_oldest_ios_follows_its_decision(self):
        for project in [PROJECT.replace('IPHONEOS_DEPLOYMENT_TARGET: "26.0"',
                                        'IPHONEOS_DEPLOYMENT_TARGET: "27.0"'),
                        PROJECT.replace('iOS: "26.0"', 'iOS: "25.0"'),
                        PROJECT.replace('    IPHONEOS', '    IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*]: '
                                        '"25.0"\n    IPHONEOS'),
                        PROJECT.replace('    platform: iOS\n    sources:\n      - App\n',
                                        '    platform: iOS\n    deploymentTarget: "25.0"\n'
                                        '    sources:\n      - App\n')]:
            with self.subTest(project=project[:120]):
                self.assertEqual(rules(self.findings(project)), ['minimum iOS'])
        self.assertEqual(rules(self.findings(PROJECT.replace(
            'options:\n  deploymentTarget:\n    iOS: "26.0"\n',
            'options:\n  deploymentTarget: { iOS: "25.0" }\n'))), ['minimum iOS'])
        self.assertEqual(self.findings(PROJECT.replace('"26.0"', '"26"')), [])
        unset = PROJECT.replace('    IPHONEOS_DEPLOYMENT_TARGET: "26.0"\n', '').replace(
            'options:\n  deploymentTarget:\n    iOS: "26.0"\n', '')
        self.assertEqual(rules(self.findings(unset)), ['minimum iOS'])
        for line, expected in [('IPHONEOS_DEPLOYMENT_TARGET = 25.0', ['minimum iOS']),
                               ('IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*] = 25.0', ['minimum iOS']),
                               ('IPHONEOS_DEPLOYMENT_TARGET = 26.0 // the decision', [])]:
            with self.subTest(xcconfig=line):
                found = self.findings(files=['Config/App.xcconfig'],
                                      texts={'Config/App.xcconfig': line + '\n'})
                self.assertEqual([(f.path, f.rule) for f in found],
                                 [('Config/App.xcconfig', rule) for rule in expected])
        # Another platform's target keeps its own minimum.
        watch = '  Watch:\n    type: application\n    platform: watchOS\n' \
                '    deploymentTarget: "11.0"\n    sources:\n      - Watch\n  AppTests:\n'
        self.assertEqual(self.findings(PROJECT.replace('  AppTests:\n', watch)), [])
        self.assertEqual(rules(self.findings(PROJECT.replace('  AppTests:\n', watch.replace(
            'watchOS', 'auto')))), ['minimum iOS'])
        self.assertEqual(rules(self.findings(PROJECT.replace('  AppTests:\n', watch.replace(
            '    platform: watchOS\n', '')))), ['minimum iOS'])
        # A deployment target only an .xcconfig file sets is still one.
        self.assertEqual(self.findings(unset, files=['Config/App.xcconfig'], texts={
            'Config/App.xcconfig': 'IPHONEOS_DEPLOYMENT_TARGET = 26.0\n'}), [])
        with self.assertRaises(forbidden.SetupError):
            self.findings(decisions=DECISIONS_TEXT.replace('26.0 or later', 'twenty-six'))


class WorkflowTests(unittest.TestCase):
    """Workflows keep pull request code away from secrets and write tokens,
    run only GitHub's own actions, and never skip the required checks."""

    def test_the_fixture_passes(self):
        self.assertEqual(workflow_findings(WORKFLOW), [])

    def test_triggers_that_hand_a_pull_request_secrets(self):
        for on in ['on:\n  pull_request_target:\n', 'on: [push, pull_request_target]\n',
                   'on:\n  workflow_run:\n    workflows: [Tests]\n', 'on: workflow_run\n',
                   'on: { pull_request_target: { types: [opened] } }\n',
                   "'on':\n  pull_request_target:\n", '"on":\n  pull_request_target:\n',
                   'on: [\n  pull_request_target,\n  push\n]\n']:
            with self.subTest(on=on):
                text = WORKFLOW.replace('on:\n  pull_request:\n', on)
                self.assertIn('workflow trigger', rules(workflow_findings(text)))

    def test_permissions_where_a_pull_request_runs(self):
        for text in [WORKFLOW.replace('permissions:\n  contents: read\n', ''),
                     WORKFLOW.replace('contents: read', 'contents: write'),
                     WORKFLOW.replace('permissions:\n  contents: read\n', 'permissions: write-all\n'),
                     # Block scalars hold their value below the key.
                     WORKFLOW.replace('permissions:\n  contents: read\n',
                                      'permissions: >-\n  write-all\n'),
                     WORKFLOW.replace('permissions:\n  contents: read\n',
                                      'permissions: |\n  write-all\n'),
                     WORKFLOW.replace('contents: read', 'contents: >-\n    write'),
                     WORKFLOW.replace('    runs-on:', '    permissions:\n      pull-requests: write\n'
                                      '    runs-on:')]:
            with self.subTest(text=text[:200]):
                self.assertEqual(rules(workflow_findings(text)), ['workflow permissions'])
        for on in ['on:\n  pull_request_target:\n', 'on:\n  workflow_run:\n',
                   'on:\n  pull_request_review:\n    types: [submitted]\n',
                   'on:\n  pull_request_review_comment:\n', 'on:\n  merge_group:\n',
                   'on:\n  issue_comment:\n    types: [created]\n', 'on: issue_comment\n',
                   'on: { pull_request: {} }\n', 'on: [\n  pull_request,\n  push\n]\n']:
            with self.subTest(on=on):
                text = WORKFLOW.replace('on:\n  pull_request:\n  push:\n    branches: [main]\n',
                                        on).replace('permissions:\n  contents: read\n', '')
                expected = {'workflow permissions'} | (
                    {'workflow trigger'} if 'pull_request_target' in on or 'workflow_run' in on
                    else set())
                self.assertEqual(set(rules(workflow_findings(text))), expected)
        for permissions in ['permissions: { contents: read }\n', 'permissions: {contents: read, '
                            'pull-requests: none}\n', 'permissions: { }\n', 'permissions: {}\n',
                            'permissions: read-all\n', 'permissions: &read\n  contents: read\n']:
            with self.subTest(permissions=permissions):
                text = WORKFLOW.replace('permissions:\n  contents: read\n', permissions)
                self.assertEqual(workflow_findings(text), [])
        wide = WORKFLOW.replace('permissions:\n  contents: read\n',
                                'permissions: { contents: read, pull-requests: write }\n')
        self.assertEqual(rules(workflow_findings(wide)), ['workflow permissions'])
        alias = WORKFLOW.replace('    runs-on:', '    permissions: *read\n    runs-on:')
        with self.assertRaises(forbidden.SetupError):
            workflow_findings(alias)
        pages = WORKFLOW.replace('on:\n  pull_request:\n  push:\n', 'on:\n  push:\n').replace(
            'contents: read', 'contents: read\n  pages: write')
        self.assertEqual(workflow_findings(pages), [])

    def test_event_text_never_reaches_a_shell_command(self):
        for run in ['        run: echo "${{ github.event.pull_request.title }}"\n',
                    '        run: |\n          git checkout ${{ github.head_ref }}\n',
                    '        run: |\n          # ${{ github.event.issue.body }}\n',
                    '        run: echo "${{ github[\'event\'] }}"\n',
                    "        run: echo '${{ toJSON(github) }}'\n",
                    '        run: echo "${{ github }}"\n',
                    # A quoted command may go on below its key's indent.
                    '        run: "echo hello &&\n          echo again &&\n'
                    '        echo ${{ github.event.pull_request.title }}"\n',
                    "        run: 'echo ''hello'' &&\n"
                    "        echo ${{ github.head_ref }}'\n",
                    '        run: "echo \\"hello\\" &&\n'
                    '        echo ${{ github.head_ref }}"\n',
                    # An expression may go on over lines.
                    '        run: |\n          echo "${{\n            github.event.pull_request.title }}"\n']:
            with self.subTest(run=run):
                text = WORKFLOW.replace('        run: |\n          echo "key: value"\n', run)
                found = workflow_findings(text)
                self.assertEqual(rules(found), ['event text in a shell command'])
        for run in ['        run: echo "${{ github.event_name }}" "${{ github.sha }}"\n',
                    '        run: echo "${{ secrets.GITHUB_TOKEN }}" "${{ github.repository }}"\n',
                    '        run: echo "${{ runner.os }}" "${{ matrix.github }}"\n',
                    '        run: echo "done" # github\n']:
            with self.subTest(run=run):
                text = WORKFLOW.replace('        run: |\n          echo "key: value"\n', run)
                self.assertEqual(workflow_findings(text), [])
        moved = WORKFLOW.replace('        run: |\n', '        env:\n          TITLE: '
                                 '${{ github.event.pull_request.title }}\n        run: |\n')
        self.assertEqual(workflow_findings(moved), [])
        self.assertEqual(workflow_findings(moved.replace('scripts/test.sh',
                                                         'echo "$TITLE" "${{ env.OTHER }}"')), [])
        for use in ['${{ env.TITLE }}', "${{ env['TITLE'] }}", '${{\n            env.TITLE }}']:
            with self.subTest(use=use):
                text = moved.replace('scripts/test.sh', f'echo "{use}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        # However the env value is written, and at whichever level.
        title = '${{ github.event.pull_request.title }}'
        for env in [f'        env:\n          TITLE:\n            {title}\n',
                    f'        env:\n          TITLE: |\n            {title}\n',
                    f'        env:\n          TITLE: >-\n            {title}\n',
                    f'        env:\n          TITLE: "Title:\n            {title}"\n',
                    f'        env: {{ TITLE: "{title}" }}\n',
                    f'        env: {{ OTHER: x, TITLE: {title} }}\n']:
            with self.subTest(env=env):
                text = WORKFLOW.replace('        run: |\n', env + '        run: |\n').replace(
                    'scripts/test.sh', 'echo "${{ env.TITLE }}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        for level in [f'env: {{ TITLE: "{title}" }}\n', f'env:\n  TITLE: {title}\n']:
            with self.subTest(level='workflow', env=level):
                text = WORKFLOW.replace('jobs:\n', level + 'jobs:\n').replace(
                    'scripts/test.sh', 'echo "${{ env.TITLE }}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
            with self.subTest(level='job', env=level):
                job = '    ' + level.replace('\n  ', '\n      ')
                text = WORKFLOW.replace('    runs-on:', job + '    runs-on:').replace(
                    'scripts/test.sh', 'echo "${{ env.TITLE }}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        # Through other env values, inside a function, under any name, and
        # with the value continued below its key.
        step = WORKFLOW.replace('        run: |\n', '        env:\n          TITLE: ${{ env.RAW }}\n'
                                '        run: |\n')
        for chain in [step.replace('    runs-on:', f'    env:\n      RAW: {title}\n    runs-on:'),
                      step.replace('jobs:\n', f'env:\n  RAW: {title}\njobs:\n'),
                      step.replace('jobs:\n', f'env:\n  FIRST: {title}\n'
                                   '  RAW: "${{ format(\'{0}\', env.FIRST) }}"\njobs:\n')]:
            with self.subTest(chain=chain[:300]):
                text = chain.replace('scripts/test.sh', 'echo "${{ env.TITLE }}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        for use in ['${{ toJSON(env.TITLE) }}', "${{ format('{0}', env.TITLE) }}"]:
            with self.subTest(use=use):
                text = moved.replace('scripts/test.sh', f'echo "{use}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        hyphen = WORKFLOW.replace('        run: |\n', f'        env:\n          PR-TITLE: {title}\n'
                                  '        run: |\n').replace('scripts/test.sh',
                                                              'echo "${{ env.PR-TITLE }}"')
        self.assertEqual(rules(workflow_findings(hyphen)), ['event text in a shell command'])
        for env in [f'        env:\n          TITLE: {title}\n            (from the pull request)\n',
                    f'        env:\n          TITLE: "{title}\n            from the pull request"\n']:
            with self.subTest(env=env):
                text = WORKFLOW.replace('        run: |\n', env + '        run: |\n').replace(
                    'scripts/test.sh', 'echo "${{ env.TITLE }}"')
                self.assertEqual(rules(workflow_findings(text)), ['event text in a shell command'])
        # A job named `env` is a job, and its env block is still one.
        named = WORKFLOW.replace('  unit:\n', '  env:\n').replace(
            '    runs-on:', f'    env:\n      TITLE: {title}\n    runs-on:').replace(
            'scripts/test.sh', 'echo "${{ env.TITLE }}"')
        self.assertEqual(rules(workflow_findings(named)), ['event text in a shell command'])
        clean = step.replace('    runs-on:', '    env:\n      RAW: ${{ github.sha }}\n    runs-on:'
                             ).replace('scripts/test.sh', 'echo "${{ env.TITLE }}"')
        self.assertEqual(workflow_findings(clean), [])
        # A step written as a one-line mapping: its run is its own value.
        steps = WORKFLOW.replace('      - name: Run\n        run: |\n          echo "key: value"\n'
                                 '          scripts/test.sh\n', '      - { name: Run, run: "echo '
                                 '${{ github.head_ref }}" }\n')
        self.assertEqual(rules(workflow_findings(steps)), ['event text in a shell command'])
        named = steps.replace('{ name: Run, run: "echo ${{ github.head_ref }}" }',
                              '{ name: "${{ github.head_ref }}", run: echo hello }')
        self.assertEqual(workflow_findings(named), [])
        safe = WORKFLOW.replace('        run: |\n', '        env: { TITLE: "${{ github.sha }}" }\n'
                                '        run: |\n').replace('scripts/test.sh',
                                                             'echo "${{ env.TITLE }}"')
        self.assertEqual(workflow_findings(safe), [])
        plain = WORKFLOW.replace('        run: |\n          echo "key: value"\n          scripts/test.sh\n',
                                 '        run: echo "checking" &&\n'
                                 '          echo "${{ github.event.pull_request.title }}"\n')
        self.assertEqual(lines(workflow_findings(plain)), [plain.split('\n').index(
            '          echo "${{ github.event.pull_request.title }}"') + 1])

    def test_the_line_of_event_text_inside_a_block(self):
        text = WORKFLOW.replace('          scripts/test.sh\n',
                                '          scripts/test.sh\n          echo ${{ github.head_ref }}\n')
        self.assertEqual(lines(workflow_findings(text)), [text.split('\n').index(
            '          echo ${{ github.head_ref }}') + 1])

    def test_only_actions_github_publishes(self):
        for uses in ['some-person/setup-thing@v1', 'docker://alpine:3', 'actionsx/checkout@v1',
                     'octo/repo/.github/workflows/build.yml@main']:
            with self.subTest(uses=uses):
                text = WORKFLOW.replace('actions/checkout@v7.0.1', uses)
                self.assertEqual(rules(workflow_findings(text)), ['outside action'])
        flow = WORKFLOW.replace('      - uses: actions/checkout@v7.0.1\n        with:\n'
                                '          persist-credentials: false\n',
                                '      - { uses: some-person/setup-thing@v1 }\n')
        self.assertEqual(rules(workflow_findings(flow)), ['outside action'])
        for uses in ['github/codeql-action/init@v4', './.github/actions/setup']:
            with self.subTest(uses=uses):
                self.assertEqual(workflow_findings(WORKFLOW.replace('actions/checkout@v7.0.1', uses)),
                                 [])

    def test_no_yaml_form_hides_a_workflow_rule(self):
        title = '${{ github.head_ref }}'
        # A one-line step whose name holds an apostrophe, then a slip.
        apostrophe = WORKFLOW.replace('      - name: Run\n', "      - { name: Apple's newest, run: x }\n"
                                      '      - uses: someone/setup@v1\n      - name: Run\n')
        # A quoted name with an escaped quote mark before " #", then a slip.
        escaped = WORKFLOW.replace('      - name: Run\n', '      - name: "Build \\"App\\" #${{ '
                                   'github.run_number }}"\n        run: x\n'
                                   '      - uses: someone/setup@v1\n      - name: Run\n')
        for text in [apostrophe, escaped]:
            with self.subTest(text=text[:400]):
                self.assertEqual(rules(workflow_findings(text)), ['outside action'])
        # Anchors and tags before one-line mappings.
        for text, expected in [
                (WORKFLOW.replace('permissions:\n  contents: read\n',
                                  'permissions: &ci { contents: read, pull-requests: write }\n'),
                 ['workflow permissions']),
                (WORKFLOW.replace('permissions:\n  contents: read\n',
                                  'permissions: !!map { contents: write }\n'),
                 ['workflow permissions']),
                (WORKFLOW.replace('        run: |\n', f'        env: &e {{ BRANCH: "{title}" }}\n'
                                  '        run: |\n').replace('scripts/test.sh',
                                                             'echo "${{ env.BRANCH }}"'),
                 ['event text in a shell command']),
                (WORKFLOW.replace('  pull_request:\n', '  pull_request: &code { paths: [App/**] }\n'),
                 ['path filter'])]:
            with self.subTest(text=text[:400]):
                self.assertEqual(rules(workflow_findings(text)), expected)
        # Steps as a one-line list of mappings.
        listed = WORKFLOW[:WORKFLOW.index('    steps:\n')] + (
            "    steps: [{ uses: someone/setup@v1 }, { run: 'echo \"" + title + "\"' }]\n")
        self.assertEqual(set(rules(workflow_findings(listed))),
                         {'outside action', 'event text in a shell command'})

    def test_no_path_filter_where_the_required_checks_run(self):
        for key in ['paths', 'paths-ignore']:
            text = WORKFLOW.replace('  pull_request:\n', f'  pull_request:\n    {key}: [App/**]\n')
            with self.subTest(key=key):
                self.assertEqual(rules(workflow_findings(text)), ['path filter'])
            ui = text.replace('name: Unit tests', 'name: UI tests')
            with self.subTest(key=key, workflow='UI tests'):
                self.assertEqual(rules(workflow_findings(ui)), ['path filter'])
            other = text.replace('name: Unit tests', 'name: Publish')
            with self.subTest(key=key, workflow='another'):
                self.assertEqual(workflow_findings(other), [])
            for on in [f'  pull_request: {{ {key}: ["App/**"] }}\n',
                       f'  pull_request: {{ types: [opened], {key}: [docs/**] }}\n']:
                flow = WORKFLOW.replace('  pull_request:\n', on)
                with self.subTest(key=key, on=on):
                    self.assertEqual(rules(workflow_findings(flow)), ['path filter'])
            whole = WORKFLOW.replace('on:\n  pull_request:\n  push:\n    branches: [main]\n',
                                     f'on: {{ pull_request: {{ {key}: [docs/**] }}, push: {{}} }}\n')
            with self.subTest(key=key, on='one line'):
                self.assertEqual(rules(workflow_findings(whole)), ['path filter'])
        branches = WORKFLOW.replace('  pull_request:\n', '  pull_request: { branches: [main] }\n')
        self.assertEqual(workflow_findings(branches), [])
        inputs = WORKFLOW.replace('  push:\n', '  workflow_dispatch:\n    inputs:\n      paths:\n'
                                  '        description: Which folders\n        type: string\n'
                                  '  push:\n')
        self.assertEqual(workflow_findings(inputs), [])

    def test_a_block_scalar_list_item_is_not_workflow_keys(self):
        text = WORKFLOW.replace('          persist-credentials: false\n',
                                '          persist-credentials: false\n          args:\n'
                                '            - |\n              uses: some/thing@v1\n')
        self.assertEqual(workflow_findings(text), [])

    def test_comments_are_not_workflow_keys(self):
        for text in [WORKFLOW.replace('on:\n', 'on:  # never pull_request_target\n'),
                     WORKFLOW.replace('contents: read', 'contents: read  # never write'),
                     WORKFLOW.replace('  push:\n', '  push:  # pull_request_target\n'),
                     WORKFLOW.replace('actions/checkout@v7.0.1',
                                      'actions/checkout@v7.0.1  # not some/thing@v1')]:
            with self.subTest(text=text):
                self.assertEqual(workflow_findings(text), [])


class CheckoutTests(unittest.TestCase):
    """The whole check over a checkout, and what it prints."""

    def test_the_fixture_passes(self):
        checkout = fixture_checkout()
        self.addCleanup(checkout.close)
        self.assertEqual(checkout.check(), [])
        status, out, err = checkout.run()
        self.assertEqual((status, err), (0, ''))
        self.assertIn('nothing AGENTS.md forbids', out)

    def test_app_and_test_files_come_from_project_yml(self):
        checkout = fixture_checkout(**{
            'Shared/Net.swift': 'let s = URLSession.shared\n',
            'docs/evidence/Probe.swift': 'import UIKit\nlet s = URLSession.shared\n',
            'AppTests/NetTests.swift': 'import XCTest\nlet s = URLSession.shared\n'})
        self.addCleanup(checkout.close)
        self.assertEqual(checkout.check(), [])
        checkout.write('project.yml', PROJECT.replace('      - App\n', '      - App\n      - Shared\n'))
        self.assertEqual([(f.path, f.rule) for f in checkout.check()],
                         [('Shared/Net.swift', 'network code')])

    def test_every_way_of_writing_a_source_is_the_same_folder(self):
        checkout = fixture_checkout(**{'App/Net.swift': 'let s = URLSession.shared\n'})
        self.addCleanup(checkout.close)
        for sources in ['    sources:\n      - ./App\n', '    sources:\n      - App/\n',
                        '    sources:\n      - { path: App }\n',
                        '    sources:\n      - path: ./App\n        type: group\n',
                        '    sources: [App]\n', '    sources: ["./App"]\n',
                        '    sources: [{ path: App }]\n', '    sources: App\n',
                        '    sources: [{ path: App, type: group }, Other]\n',
                        '    sources:\n      - .\n',
                        # A Mac's file system ignores letter case.
                        '    sources:\n      - app\n']:
            with self.subTest(sources=sources):
                checkout.write('project.yml', PROJECT.replace(
                    '    sources:\n      - App\n      - path: site/privacy\n        type: folder\n',
                    sources))
                self.assertIn(('App/Net.swift', 'network code'),
                              [(f.path, f.rule) for f in checkout.check()])

    def test_only_the_apps_own_declarations_excuse_a_name(self):
        watcher = ('import SwiftUI\nfinal class Watcher {\n    var c: Any?\n'
                   '    func start(_ m: Model) { c = m.objectWillChange.sink { _ in } }\n}\n')
        checkout = fixture_checkout(**{
            'App/Watcher.swift': watcher,
            'AppTests/Spy.swift': 'import Testing\nstruct Spy { func sink(_ value: Int) {} }\n'})
        self.addCleanup(checkout.close)
        self.assertEqual([(f.path, f.rule) for f in checkout.check()],
                         [('App/Watcher.swift', 'legacy framework')])
        checkout.write('App/Spy.swift', 'struct Spy { func sink(_ value: Int) {} }\n')
        self.assertEqual(checkout.check(), [])

    def test_extensions_and_frameworks_the_app_ships_are_the_app(self):
        project = PROJECT.replace('  AppTests:\n', '  Alerts:\n    type: app-extension\n'
                                  '    platform: iOS\n    sources: [Alerts]\n'
                                  '  Shared:\n    type: framework\n    platform: iOS\n'
                                  '    sources:\n      - Shared\n  AppTests:\n')
        checkout = fixture_checkout(**{'project.yml': project,
                                       'Alerts/Alert.swift': 'internal import Network\n',
                                       'Shared/Cloud.swift': 'let c = CKContainer.default()\n'})
        self.addCleanup(checkout.close)
        self.assertEqual([(f.path, f.rule) for f in checkout.check()],
                         [('Alerts/Alert.swift', 'forbidden framework'),
                          ('Shared/Cloud.swift', 'cloud sync')])

    def test_a_byte_order_mark_hides_no_import(self):
        checkout = fixture_checkout()
        self.addCleanup(checkout.close)
        checkout.write('App/Net.swift', b'\xef\xbb\xbfimport Network\n')
        self.assertEqual([(f.path, f.line, f.rule) for f in checkout.check()],
                         [('App/Net.swift', 1, 'forbidden framework')])

    def test_actions_of_the_repository_are_checked_too(self):
        action = 'runs:\n  using: composite\n  steps:\n    - uses: someone/setup@v1\n'
        for path in ['.github/actions/setup/action.yaml', '.github/setup/action.yml', 'action.yml']:
            with self.subTest(path=path):
                checkout = fixture_checkout(**{path: action})
                self.addCleanup(checkout.close)
                self.assertEqual([(f.path, f.rule) for f in checkout.check()],
                                 [(path, 'outside action')])

    def test_a_planted_finding_fails_with_its_place_only(self):
        checkout = fixture_checkout()
        self.addCleanup(checkout.close)
        checkout.append('App/HomeView.swift', 'let note = "Call my sister"; let s = URLSession.shared\n')
        status, out, err = checkout.run()
        self.assertEqual(status, 1)
        self.assertIn('App/HomeView.swift:8: network code: `URLSession`', err)
        self.assertNotIn('sister', out + err)
        self.assertNotIn('::error', err)

    def test_on_github_actions_each_place_is_marked(self):
        checkout = fixture_checkout()
        self.addCleanup(checkout.close)
        checkout.append('App/HomeView.swift', 'let s = URLSession.shared\n')
        status, _, err = checkout.run({'GITHUB_ACTIONS': 'true'})
        self.assertEqual(status, 1)
        self.assertIn('::error file=App/HomeView.swift,line=8,title=network code::', err)

    def test_a_new_file_git_does_not_ignore_is_checked_and_an_ignored_one_is_not(self):
        checkout = fixture_checkout(**{'.gitignore': 'App/Generated/\n'})
        self.addCleanup(checkout.close)
        checkout.write('App/Generated/Out.swift', 'let s = URLSession.shared\n')
        self.assertEqual(checkout.check(), [])
        checkout.write('App/New.swift', 'let s = URLSession.shared\n')
        self.assertEqual([f.path for f in checkout.check()], ['App/New.swift'])

    def test_claude_md_holds_only_the_pointer(self):
        for text in ['@AGENTS.md\nAlso: never push.\n', 'Read AGENTS.md\n', None]:
            with self.subTest(text=text):
                checkout = fixture_checkout(**{'CLAUDE.md': text})
                self.addCleanup(checkout.close)
                self.assertEqual(rules(checkout.check()), ['CLAUDE.md'])

    def test_a_check_that_cannot_read_what_it_needs_stops_with_status_2(self):
        for changes, why in [
                ({'project.yml': None}, 'project.yml is missing'),
                ({'docs/DECISIONS.md': None}, 'docs/DECISIONS.md is missing'),
                ({'project.yml': PROJECT.replace('type: application', 'type: framework')},
                 'no application target'),
                ({'project.yml': PROJECT + 'include:\n  - more.yml\n',
                  'more.yml': 'packages:\n  X:\n    url: https://example.com/x\n'}, 'includes'),
                ({'project.yml': PROJECT + 'targetTemplates:\n  Ext:\n    type: app-extension\n'},
                 'templates'),
                ({'project.yml': PROJECT.replace('  AppTests:\n', '  Alerts:\n'
                                                 '    type: app-extension\n    templates: [Ext]\n'
                                                 '    sources: [Alerts]\n  AppTests:\n')},
                 'templates'),
                ({'project.yml': PROJECT.replace('  AppTests:\n', '  Alerts:\n'
                                                 '    platform: iOS\n    sources: [Alerts]\n'
                                                 '  AppTests:\n')}, 'no `type:`'),
                # Sources the check would read none of the app through.
                ({'project.yml': PROJECT.replace('      - App\n', '      - Ap\n')},
                 'hold no Swift file'),
                ({'project.yml': PROJECT.replace('      - App\n', '      - ../App\n')},
                 'outside this checkout'),
                ({'docs/DECISIONS.md': DECISIONS_TEXT.replace('## Warnings are errors',
                                                              '## Warnings')}, 'Warnings are errors')]:
            with self.subTest(changes=list(changes), why=why):
                checkout = fixture_checkout(**changes)
                self.addCleanup(checkout.close)
                status, out, err = checkout.run()
                self.assertEqual((status, out), (2, ''))
                self.assertIn('could not run', err)
                self.assertIn(why, err)

    def test_outside_a_git_checkout_it_stops_with_status_2(self):
        # The fixture's files, in a folder git does not know: the check
        # cannot tell what is ignored, so it does not guess.
        checkout = fixture_checkout()
        self.addCleanup(checkout.close)
        shutil.rmtree(checkout.root / '.git')
        with unittest.mock.patch.dict(os.environ,
                                      {'GIT_CEILING_DIRECTORIES': str(checkout.root.parent)}):
            status, out, err = checkout.run()
        self.assertEqual((status, out), (2, ''))
        self.assertIn('git could not list the files', err)


def copy_of_this_checkout():
    """A checkout holding what the check reads from this repository."""
    tracked = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-z', '--cached', '--others',
                              '--exclude-standard'], capture_output=True, check=True)
    files = {}
    for path in tracked.stdout.decode().split('\0'):
        if path and (ROOT / path).is_file() and (
                path in ('project.yml', 'CLAUDE.md', 'docs/DECISIONS.md')
                or path.startswith('.github/') or path.endswith(('.swift', '.plist'))):
            files[path] = (ROOT / path).read_bytes()
    return Checkout(files)


class RepositoryTests(unittest.TestCase):
    """This repository, as it is: it passes, and the check really reads
    its app, its table and its workflows (a check that read nothing would
    pass too)."""

    def test_the_repository_holds_nothing_agents_md_forbids(self):
        findings = forbidden.check(ROOT)
        if findings:
            print(forbidden.report(findings), file=sys.stderr)
        self.assertEqual([str(finding) for finding in findings], [],
                         'Fix each place above, or, where a rule is wrong, say so in the pull '
                         'request and let the owner decide (AGENTS.md, *Code Review Rules*).')

    def test_the_check_reads_the_real_app_table_and_workflows(self):
        entries = forbidden.yaml_entries((ROOT / 'project.yml').read_text(encoding='utf-8'))
        kinds, sources = forbidden.targets(entries)
        apps = [name for name, kind in kinds.items() if kind == 'application']
        self.assertEqual(len(apps), 1)
        app_files = [path for path in forbidden.listed_files(ROOT)
                     if path.endswith('.swift') and forbidden.under(path, sources[apps[0]])]
        self.assertGreater(len(app_files), 50)
        allowed = forbidden.allowed_files((ROOT / forbidden.DECISIONS).read_text(encoding='utf-8'))
        for family, name in [('UIKit', 'BricksonApp'), ('UIKit', 'Palette'),
                             ('SafariServices', 'PrivacyPolicyView'),
                             ('Dispatch', 'SpeechSynthesizing'),
                             ('NotificationCenter observers', 'AudioSessionEvents'),
                             ('key-value observation', 'AudioSafetyMonitor')]:
            self.assertIn(name, allowed[family])

    def test_planted_slips_in_a_copy_of_the_repository_are_found(self):
        checkout = copy_of_this_checkout()
        self.addCleanup(checkout.close)
        self.assertEqual(checkout.check(), [])
        app = sorted(path.relative_to(checkout.root).as_posix()
                     for path in (checkout.root / 'Brickson').rglob('*.swift'))
        home = next(path for path in app if path.endswith('/HomeView.swift'))
        planted = {
            home: '\nfunc slip() { _ = URLSession.shared; _ = UIDevice.current; '
                  'DispatchQueue.main.async {} }\n',
            'BricksonTests/' + 'SlipTests.swift': 'import Testing\n@Test(.disabled()) func s() {}\n',
            '.github/workflows/tests.yml': '\n',
        }
        for path, text in planted.items():
            if path.endswith('SlipTests.swift'):
                checkout.write(path, text)
            elif path.endswith('.yml'):
                checkout.write(path, (ROOT / path).read_text(encoding='utf-8').replace(
                    'permissions:\n  contents: read\n', 'permissions:\n  contents: write\n'))
            else:
                checkout.append(path, text)
        found = {(finding.path, finding.rule) for finding in checkout.check()}
        self.assertEqual(found, {(home, 'network code'), (home, 'device check'),
                                 (home, 'legacy framework'),
                                 ('BricksonTests/SlipTests.swift', 'unexplained skip'),
                                 ('.github/workflows/tests.yml', 'workflow permissions')})

    def test_the_test_script_runs_this_check(self):
        text = (ROOT / 'scripts' / 'test.sh').read_text(encoding='utf-8')
        self.assertTrue('\n    /usr/bin/python3 scripts/test-forbidden-code.py\n' in text,
                        'scripts/test.sh runs this file before the unit tests')


if __name__ == '__main__':
    unittest.main()
