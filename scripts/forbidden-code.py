#!/usr/bin/env python3
"""Fail when the code holds something AGENTS.md forbids.

AGENTS.md's rules are words. Every agent, reviewer and person reads them,
but until now nothing stopped a slip before a reviewer saw it. This script
checks the rules a script can decide with no judgment, so a slip fails CI
before it merges, whoever made it (docs/DECISIONS.md, "A check for code
the app must never contain"). It only reads files: it changes nothing,
uses no outside service and needs no Mac. Every rule keeps its line in
AGENTS.md; this backs some of them, and judges none.

What it checks:

- The app's Swift files (the sources of every target in project.yml that
  is not a test: the app, and any extension or framework it ships), read
  with comments and the words inside strings left out:
  - no network code, cloud sync, Keychain, accounts, ads or tracking, and
    no frameworks for them (invariant 9; AGENTS.md, *The privacy policy
    is a promise*);
  - no system sounds and no setting of the system volume (invariant 4);
  - no choice made by device, screen or orientation (AGENTS.md, *Layout
    on every device and window*);
  - no gestures, pointer hovering or tracking code of the app's own
    (invariants 1 and 9);
  - no ModelContext.rollback() (invariant 5), no ViewThatFits and no
    hidden Back button or swipe (AGENTS.md, *Gotchas* and *Design rules
    for dwell, switch and pointer input*);
  - only the frameworks on the list below; UIKit, SafariServices,
    Dispatch, notification observers, key-value observation, Combine,
    Core Data, SiriKit and XCTest only in files that docs/DECISIONS.md,
    "Apple's current frameworks first", names in its table;
  - SwiftData opened with cloudKitDatabase: .none, however the
    configuration is made (by name, through .init( whose type the code
    around it says, Self( in an extension, or none at all), and
    notification observers on the main queue inside
    MainActor.assumeIsolated (never with a selector).
- project.yml and the files beside it (every .xcconfig, .plist and
  .entitlements file): no third-party packages, SDKs or git submodules;
  no iCloud, push, Sign in with Apple or network capability or Info.plist
  key; warnings stay errors, in every build and every source's own
  compiler flags (docs/DECISIONS.md, "Warnings are errors"); the oldest
  iOS matches docs/DECISIONS.md, "Minimum iOS, iPhone and iPad", for
  every iOS target. YAML's block and one-line forms, anchors and tags
  read alike.
- The workflows and every action in the repository: no
  pull_request_target or workflow_run trigger, read-only permissions in
  every workflow a pull request runs, no event text inside a shell
  command, only actions GitHub publishes, and no path filter on the
  workflow that runs the required checks.
- The tests: every known issue is strict and cites its decision, and
  every skip says why.
- CLAUDE.md holds only @AGENTS.md.

  python3 scripts/forbidden-code.py          check this checkout
  python3 scripts/forbidden-code.py <path>   check another checkout

It reads the files git tracks, and new files git does not ignore. Exit
status: 0 nothing found, 1 something found, 2 the check could not run (a
file it reads is missing, or no longer reads the way the check expects:
project.yml including other specs or building targets from templates, a
target with no type, a source outside the checkout, an app target whose
sources hold no Swift file git lists, permissions given through a YAML
alias).
It prints where and what it found, never a line of the code. On GitHub
Actions it also marks each place on the pull request.

Standard library only; Python 3.9, the Mac's /usr/bin/python3. Its tests
are scripts/test-forbidden-code.py, which also runs it over this
checkout; scripts/test.sh runs them before the unit tests, so CI runs them
on every pull request.

What it cannot catch: a forbidden API reached by a name built at run time
(a string given to NSClassFromString, a selector), a web address the app
loads with Data(contentsOf:) or AVPlayer, a value whose type Swift works
out from somewhere this does not look (a parameter, a generic, a
typealias, a variable holding .hidden, a name declared with both of
SwiftData's types and used where neither declaration's scope reaches), a
Combine operator or a UIKit- or
SiriKit-style name used in one app file when another app file declares
the same name, Swift or YAML written in a form its small readers have
never seen, code written to get past it, and every rule that needs a
person's judgment.
"""
import argparse
import bisect
from dataclasses import dataclass
import os
from pathlib import Path
import posixpath
import re
import subprocess
import sys

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts

ROOT = Path(__file__).resolve().parents[1]
DECISIONS = 'docs/DECISIONS.md'
FRAMEWORKS_SECTION = "Apple's current frameworks first"
MINIMUM_SECTION = 'Minimum iOS, iPhone and iPad'
WARNINGS_SECTION = 'Warnings are errors'
HOW_TO_ALLOW = ('If this is not a hard stop and no current framework does the job with no loss, '
                'add the file to that row of the table, or a row of its own, with why')


class SetupError(Exception):
    """The check could not run: say why, and stop with status 2."""


@dataclass(frozen=True)
class Finding:
    """One thing found: where, which rule, and what to do."""
    path: str
    line: int
    rule: str
    message: str

    def __str__(self):
        place = f'{self.path}:{self.line}' if self.line else self.path
        return f'{place}: {self.rule}: {self.message}'


# ── Reading Swift ────────────────────────────────────────────────────────────

class Swift:
    """A Swift file, with its code: the text with every comment, string
    literal and regex literal blanked to spaces (line breaks kept, so
    every place keeps its line and column), except the code inside a
    string's interpolation, which stays. A rule that reads `code` never
    trips on a comment that explains why an API is not used, or on a
    phrase."""

    def __init__(self, path, text):
        self.path = path
        self.text = text
        self._out = list(text)
        # Each string literal's (start, end) offsets, delimiters included.
        self.strings = []
        self._code(0, interpolation=False)
        self.code = ''.join(self._out)
        del self._out
        self._lines = [index for index, char in enumerate(text) if char == '\n']
        self._pairs = None

    def line(self, offset):
        """The 1-based line of an offset."""
        return bisect.bisect_left(self._lines, offset) + 1

    def _blank(self, start, end):
        for index in range(start, min(end, len(self.text))):
            if self.text[index] != '\n':
                self._out[index] = ' '

    def _code(self, index, interpolation):
        """Read code from index. Inside an interpolation, stop at the
        parenthesis that closes it and return its offset."""
        text = self.text
        depth = 0
        while index < len(text):
            char = text[index]
            if text.startswith('//', index):
                end = text.find('\n', index)
                end = len(text) if end < 0 else end
                self._blank(index, end)
                index = end
            elif text.startswith('/*', index):
                index = self._block_comment(index)
            elif char in '#"':
                hashes = 0
                while text.startswith('#', index + hashes):
                    hashes += 1
                after = index + hashes
                if text.startswith('"', after):
                    index = self._string(index, hashes)
                elif hashes and text.startswith('/', after):
                    index = self._extended_regex(index, hashes)
                else:
                    index = after
            elif char == '/':
                end = self._bare_regex(index)
                if end is None:
                    index += 1
                else:
                    self._blank(index, end)
                    index = end
            elif interpolation and char == '(':
                depth += 1
                index += 1
            elif interpolation and char == ')':
                if depth == 0:
                    return index
                depth -= 1
                index += 1
            else:
                index += 1
        return index

    def _block_comment(self, start):
        # Swift's block comments nest.
        text = self.text
        depth = 0
        index = start
        while index < len(text):
            if text.startswith('/*', index):
                depth += 1
                index += 2
            elif text.startswith('*/', index):
                depth -= 1
                index += 2
                if depth == 0:
                    break
            else:
                index += 1
        self._blank(start, index)
        return index

    def _string(self, start, hashes):
        """A string literal: "…", \"\"\"…\"\"\" or a raw #"…"#. Returns
        the offset after it."""
        text = self.text
        quote = start + hashes
        # A multi-line string's opening delimiter ends its line, so #"""#
        # is a one-line raw string holding a quote mark.
        multiline = re.match(r'"""[ \t]*(?:\r?\n|$)', text[quote:quote + 64]) is not None
        opener = '"""' if multiline else '"'
        closer = opener + '#' * hashes
        escape = '\\' + '#' * hashes
        index = quote + len(opener)
        segment = start
        while index < len(text):
            if text.startswith(closer, index):
                end = index + len(closer)
                self._blank(segment, end)
                self.strings.append((start, end))
                return end
            if not multiline and text[index] == '\n':
                break  # an unclosed one-line string ends with its line
            if text.startswith(escape, index):
                after = index + len(escape)
                if text.startswith('(', after):
                    self._blank(segment, after + 1)
                    close = self._code(after + 1, interpolation=True)
                    segment = close
                    index = close + 1
                    continue
                index = after + 1
                continue
            index += 1
        self._blank(segment, index)
        self.strings.append((start, index))
        return index

    def _extended_regex(self, start, hashes):
        closer = '/' + '#' * hashes
        end = self.text.find(closer, start + hashes + 1)
        if end < 0:
            return start + hashes
        end += len(closer)
        self._blank(start, end)
        return end

    OPERATOR_CHARACTERS = set('<>=+-*%&|^~?!.')
    OPERAND_END = re.compile(r'[A-Za-z0-9_)\]}"\'`]$')
    # Words an operand follows ("else" never does: a brace or `if` follows it).
    REGEX_AFTER = {'return', 'case', 'in', 'where', 'try', 'await', 'throw', 'if', 'guard',
                   'while', 'switch'}

    def _bare_regex(self, start):
        """The end of a bare /regex/ literal starting here, or None when
        the slash is an operator. A regex comes where an operand would,
        and never starts with a space."""
        text = self.text
        following = text[start + 1:start + 2]
        if following in ('', ' ', '\t', '\n', '/', '*', '=', ')', ',', ']'):
            return None
        if start and text[start - 1] in self.OPERATOR_CHARACTERS:
            return None  # part of an operator, like </>
        before = ''.join(self._out[max(0, start - 40):start]).rstrip()
        if self.OPERAND_END.search(before):
            word = re.search(r'[A-Za-z_]\w*$', before)
            if not (word and word.group() in self.REGEX_AFTER):
                return None
        index = start + 1
        in_class = False
        groups = 0
        while index < len(text) and text[index] != '\n':
            char = text[index]
            if char == '\\':
                index += 2
                continue
            if in_class:
                if char == ']':
                    in_class = False
            elif char == '[':
                in_class = True
            elif char == '(':
                groups += 1
            elif char == ')':
                if not groups:
                    return None  # Swift never reads an unbalanced ) as a regex
                groups -= 1
            elif char == '/':
                return index + 1
            index += 1
        return None

    def closing(self, opening):
        """The offset of the bracket that closes the one at `opening` in
        the code, or the end of the file."""
        depth = 0
        for index in range(opening, len(self.code)):
            char = self.code[index]
            if char in '([{':
                depth += 1
            elif char in ')]}':
                depth -= 1
                if depth == 0:
                    return index
        return len(self.code)

    def pairs(self):
        """Each bracket of the code with its partner, both ways."""
        if self._pairs is None:
            self._pairs, stack = {}, []
            for index, char in enumerate(self.code):
                if char in '([{':
                    stack.append(index)
                elif char in ')]}' and stack:
                    opening = stack.pop()
                    self._pairs[opening], self._pairs[index] = index, opening
        return self._pairs

    def top_level_strings(self, opening, closing):
        """The string literals directly inside the brackets at `opening`
        and `closing`, not inside a nested call."""
        found = []
        for start, end in sorted(self.strings):
            if any(outer_start < start and end <= outer_end and (outer_start, outer_end) != (
                    start, end) for outer_start, outer_end in self.strings):
                continue  # inside another string's interpolation
            if opening < start < closing:
                between = self.code[opening + 1:start]
                depth = sum(between.count(char) for char in '([{') - sum(
                    between.count(char) for char in ')]}')
                if depth == 0:
                    found.append(self.text[start:end])
        return found


def word(pattern):
    """A pattern that matches whole identifiers only."""
    return re.compile(r'(?<![A-Za-z0-9_$])(?:' + pattern + r')(?![A-Za-z0-9_])')


IMPORT = re.compile(r'(?:^|;)[ \t]*(?:@\w+(?:\([^)\n]*\))?[ \t]+)*'
                    r'(?:(?:public|package|internal|fileprivate|private)[ \t]+)?import[ \t]+'
                    r'(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?'
                    r'(?P<module>[A-Za-z_]\w*)', re.M)
DECLARATION = re.compile(
    r'\b(?:struct|class|enum|protocol|typealias|actor|func)\s+(?P<name>[A-Za-z_]\w*)')


def declared_names(sources):
    """The type and function names the app's own Swift declares,
    so a rule that looks for a framework's prefix (UI…, IN…, CK…) or one
    of Combine's operator names never trips on Brickson's own."""
    names = set()
    for source in sources:
        names.update(match.group('name') for match in DECLARATION.finditer(source.code))
    return names


# ── The app's rules ──────────────────────────────────────────────────────────

NETWORK = 'no network code, servers or accounts (invariant 9)'
CLOUD = ('no cloud sync: SwiftData opens with cloudKitDatabase: .none and the app has no iCloud '
         'capability (AGENTS.md, *The privacy policy is a promise*)')
KEYCHAIN = 'store nothing in the Keychain (AGENTS.md, *The privacy policy is a promise*)'
TRACKING = 'no ads, analytics or tracking (invariant 9)'
ACCOUNTS = 'no accounts or login (invariant 9)'
SYSTEM_SOUND = ('speech and alarms use AVFoundation with the .playback session, never '
                'AudioServicesPlaySystemSound, which obeys the silent switch (invariant 4)')
VOLUME = 'observe but never set the system volume (invariant 4)'
DEVICE = ('lay out from the space available, never by device, screen size or orientation '
          '(AGENTS.md, *Layout on every device and window*)')
GESTURE = ('every control is a standard SwiftUI Button; never gesture-only controls or custom '
           'input (invariants 1 and 9)')
POINTER = ('fix hazards with placement, never with custom pointer code '
           '(AGENTS.md, *Design rules for dwell, switch and pointer input*)')
TRACKING_INPUT = 'no eye, head or switch tracking of the app\'s own (invariant 9)'
NAVIGATION = ('keep the standard Back button, Close and swipe navigation '
              '(AGENTS.md, *Design rules for dwell, switch and pointer input*)')
ROLLBACK = ('never ModelContext.rollback(): it crashed SwiftData after a cascading delete '
            '(invariant 5; docs/LESSONS.md, "Never roll back a cascade delete")')
VIEW_THAT_FITS = ('ViewThatFits failed Apple\'s accessibility audit around text here: choose '
                  'the arrangement in a plain type (AGENTS.md, *Gotchas*)')

# Frameworks the app may import, each because the app uses it today or it
# adds only language features. A framework not here is refused until a pull
# request adds it, so each new one gets a reviewer's look against the hard
# stops and the privacy policy.
APP_IMPORTS = {
    'Accessibility', 'AVFoundation', 'CoreGraphics', 'CoreTransferable', 'Foundation',
    'Observation', 'os', 'OSLog', 'RegexBuilder', 'Swift', 'SwiftData', 'SwiftUI',
    'Synchronization', 'UniformTypeIdentifiers', '_Concurrency',
}
# Frameworks the app may never import: each exists for a hard stop.
FORBIDDEN_IMPORTS = {
    'AdAttributionKit': TRACKING, 'AdServices': TRACKING, 'AdSupport': TRACKING, 'iAd': TRACKING,
    'AppTrackingTransparency': TRACKING,
    'ARKit': TRACKING_INPUT, 'GameController': TRACKING_INPUT,
    'AudioToolbox': SYSTEM_SOUND,
    'AuthenticationServices': ACCOUNTS,
    'CFNetwork': NETWORK, 'MultipeerConnectivity': NETWORK, 'Network': NETWORK, 'WebKit': NETWORK,
    'CloudKit': CLOUD,
    'Security': KEYCHAIN,
}

# Each list: the rule's name, why, and the identifiers that break it. A name
# with a framework's prefix (UI, IN, CK) that Brickson declares itself is
# left alone.
APP_WORDS = [
    ('network code', NETWORK,
     r'URLSession\w*|NSURLSession\w*|NSURLConnection\w*|(?:NS|NSMutable)?URLRequest|URLProtocol'
     r'|HTTPCookie\w*|NetService\w*|getStreamsToHost|CFStream\w*ToHost\w*|CFSocket\w*|CFHTTP\w*'
     r'|AsyncImage|WKWebView\w*|NWConnection|NWListener|NWBrowser|NWPathMonitor|MCSession\w*'),
    ('cloud sync', CLOUD, r'NSUbiquitous\w*|\w*[Uu]biquity\w*|CK[A-Z]\w*'),
    ('Keychain', KEYCHAIN, r'SecItem\w*|kSec\w+|SecAccessControl\w*|SecKeychain\w*'),
    ('ads or tracking', TRACKING,
     r'ASIdentifierManager|advertisingIdentifier|ATTrackingManager|identifierForVendor'
     r'|SKAdNetwork|MXMetricManager'),
    ('accounts', ACCOUNTS,
     r'ASAuthorization\w*|ASWebAuthenticationSession|SignInWithAppleButton|GKLocalPlayer'),
    ('system sound', SYSTEM_SOUND, r'AudioServices\w*|SystemSoundID|kSystemSoundID\w*'),
    ('system volume', VOLUME, r'MPVolumeView|MPMusicPlayerController'),
    ('device check', DEVICE,
     r'userInterfaceIdiom|UIUserInterfaceIdiom|UIDevice|UIScreen|nativeBounds|nativeScale'
     r'|UIDeviceOrientation|UIInterfaceOrientation\w*|interfaceOrientation|utsname|sysctl\w*'),
    ('gesture', GESTURE,
     r'onTapGesture|onLongPressGesture|onLongTouchGesture|SpatialTapGesture|TapGesture'
     r'|LongPressGesture|DragGesture|MagnifyGesture|MagnificationGesture|RotateGesture'
     r'|RotationGesture|simultaneousGesture|highPriorityGesture|UI\w*GestureRecognizer\w*'),
    ('pointer code', POINTER, r'onHover|onContinuousHover'),
    ('eye or head tracking', TRACKING_INPUT,
     r'ARFaceTrackingConfiguration|ARSession\w*|GCController\w*'),
    ('hidden navigation', NAVIGATION,
     r'navigationBarBackButtonHidden|navigationBarHidden|interactiveDismissDisabled'),
    ('ViewThatFits', VIEW_THAT_FITS, r'ViewThatFits'),
]
APP_WORDS = [(rule, why, word(pattern)) for rule, why, pattern in APP_WORDS]
PREFIXED = re.compile(r'^(?:UI|IN|CK)[A-Z]')
MEMBER_GESTURE = re.compile(r'\.\s*gesture\s*\(')
# The current way to hide the navigation bar, and its Back button with it:
# a visibility that can be .hidden, for the navigation bar or every bar.
TOOLBAR_CALL = re.compile(r'(?:\.\s*|(?<![\w.$]))(?P<name>toolbar|toolbarVisibility)\s*\(')
# ModelContext.rollback() takes no arguments: an enum case of Brickson's
# own called rollback is not it.
ROLLBACK_USE = re.compile(r'\.\s*rollback\s*\(\s*\)|(?<![\w.])rollback\s*\(\s*\)')
MODEL_CONTAINER_FOR = re.compile(r'\.\s*modelContainer\s*\(\s*for\s*:')


@dataclass(frozen=True)
class Family:
    """A legacy framework or API (AGENTS.md, *Apple's current frameworks
    first*): a file may use it only when a row of docs/DECISIONS.md's table
    whose What cell matches `row` names the file in its Where cell."""
    name: str
    current: str      # what to use instead
    uses: object      # pattern for a use in the code
    modules: tuple    # the imports that count as a use
    row: object       # pattern for the rows that allow it


FAMILIES = [
    # UIKeyboardType and UITextContentType are the values SwiftUI's own
    # keyboardType(_:) and textContentType(_:) take, which docs/DECISIONS.md,
    # "Apple's current frameworks first", says are not legacy.
    Family('UIKit', 'SwiftUI', word(r'(?!UIKeyboardType\b|UITextContentType\b)UI[A-Z]\w*'
                                    r'|ui(?:Color|Image)(?=\s*:)'), ('UIKit',),
           re.compile(r'(?<![A-Za-z0-9_])UI[A-Z]')),  # UIKit itself too
    Family('SafariServices', 'SwiftUI', word(r'SFSafari\w*'), ('SafariServices',),
           re.compile(r'SFSafariViewController|SafariServices')),
    Family('Dispatch', 'Swift concurrency', word(r'Dispatch[A-Z]\w*|dispatch_\w+'), ('Dispatch',),
           re.compile(r'\bDispatch|dispatch_')),
    Family('NotificationCenter observers', "Foundation's typed notification messages", None, (),
           re.compile(r'addObserver\(forName')),
    Family('key-value observation', 'Observation', None, (),
           re.compile(r'[Kk]ey-value observation')),
    # Combine's operators only as members (`.sink {`), so a value of
    # Brickson's own called sink is not one.
    Family('Combine', 'Observation', word(
        r'ObservableObject|Published|StateObject|ObservedObject|EnvironmentObject|AnyCancellable'
        r'|Cancellable|PassthroughSubject|CurrentValueSubject|AnyPublisher|Publishers|onReceive'
        r'|(?:Future|Just|Deferred|Empty|Fail|Record)(?=\s*[<({])'
        r'|(?<=\.)(?:autoconnect(?=\s*\(\s*\))'
        r'|sink(?=\s*(?:\(\s*receive(?:Value|Completion)\s*:|\{))'
        r'|assign(?=\s*\(\s*to\s*:\s*[\\&])|publisher(?=\s*(?:\(\s*for\s*:|\.\s*values\b))'
        r'|publish(?=\s*\(\s*every\s*:))'), ('Combine',),
           re.compile(r'\bCombine\b|ObservableObject')),
    Family('Core Data', 'SwiftData', word(
        r'NSManagedObject\w*|NSPersistent\w*|NSFetchRequest\w*|NSFetchedResultsController'
        r'|NSEntityDescription|FetchRequest|FetchedResults'), ('CoreData',),
           re.compile(r'Core Data|NSManagedObject|NSPersistent')),
    Family('SiriKit', 'App Intents', word(r'IN[A-Z][a-z]\w*'), ('Intents', 'IntentsUI'),
           re.compile(r'SiriKit|\bIN[A-Z][a-z]')),
    Family('XCTest', 'Swift Testing, in the unit tests', word(r'XCT\w+|XCUI\w+'),
           ('XCTest', 'XCUIAutomation'), re.compile(r'\bXCTest\b|XCUIAutomation')),
]
FAMILY_BY_MODULE = {module: family for family in FAMILIES for module in family.modules}
# UIKit's own colours through SwiftUI's Color(_: UIColor), with the type
# left to the context (`Color(.systemBackground)`, `.init(.label)`): names
# SwiftUI's Color does not have.
UIKIT_COLOR = re.compile(
    r'(?:\bColor\s*(?:\.\s*init\s*)?|(?<![\w)\]}?!>$])\.\s*init\s*)\(\s*\.\s*'
    r'(?P<name>(?:(?:secondary|tertiary|quaternary)S|s)ystem[A-Z]\w*'
    r'|(?:(?:secondary|tertiary|quaternary)L|l)abel|placeholderText|separator|opaqueSeparator'
    r'|link|lightText|darkText|tintColor|darkGray|lightGray|magenta)\b')
# Combine's names that other things may have too: a method or type the
# app declares with one of these names is its own.
COMBINE_METHODS = {'sink', 'assign', 'publisher', 'publish', 'autoconnect', 'Future', 'Just',
                   'Deferred', 'Empty', 'Fail', 'Record'}
OBSERVER_CALL = re.compile(r'\baddObserver\s*\(')
KVO_USES = re.compile(r'\.\s*observe\s*\(\s*\\|\bobserveValue\s*\(\s*forKeyPath\b')


def family_uses(source, family, declared):
    """Each (offset, name) where the file's code uses the family."""
    found = []
    if family.uses is not None:
        for match in family.uses.finditer(source.code):
            name = match.group()
            if name in declared and (PREFIXED.match(name) or name in COMBINE_METHODS):
                continue
            found.append((match.start(), name))
    if family.name == 'UIKit':
        found.extend((match.start(), f'Color(.{match.group("name")})')
                     for match in UIKIT_COLOR.finditer(source.code))
    for match in OBSERVER_CALL.finditer(source.code):
        opening = source.code.index('(', match.start())
        arguments = source.code[opening:source.closing(opening)]
        if re.search(r'\bforKeyPath\s*:', arguments):
            kind = 'key-value observation'
        elif re.search(r'\bforName\s*:', arguments) or (
                re.search(r'\bselector\s*:', arguments) and re.search(r'\bname\s*:', arguments)):
            kind = 'NotificationCenter observers'
        else:
            continue  # addObserver(of:for:), the typed messages that replace them
        if family.name == kind:
            found.append((match.start(), 'addObserver'))
    if family.name == 'key-value observation':
        found.extend((match.start(), 'observe') for match in KVO_USES.finditer(source.code))
    return found


def markdown_sections(text):
    """Each heading's title and the text under it, to the next heading of
    the same or a higher level. Headings inside fenced code are text."""
    lines = text.split('\n')
    headings = []
    fence = None
    for number, line in enumerate(lines):
        stripped = line.strip()
        marker = re.match(r'(`{3,}|~{3,})', stripped)
        if marker:
            if fence is None:
                fence = marker.group(1)[0]
            elif stripped.startswith(fence * 3):
                fence = None
            continue
        if fence is None:
            heading = re.match(r'^ {0,3}(#{1,6})\s+(.*?)\s*#*\s*$', line)
            if heading:
                headings.append((number, len(heading.group(1)), heading.group(2)))
    sections = {}
    for position, (number, level, title) in enumerate(headings):
        end = len(lines)
        for later, later_level, _ in headings[position + 1:]:
            if later_level <= level:
                end = later
                break
        sections.setdefault(title, '\n'.join(lines[number + 1:end]))
    return sections


def decision_section(decisions, title):
    section = markdown_sections(decisions).get(title)
    if section is None:
        raise SetupError(f'{DECISIONS} has no section "{title}", which this check reads.')
    return section


def table_cells(line):
    return [cell.strip().replace('\\|', '|')
            for cell in re.split(r'(?<!\\)\|', line.strip().strip('|'))]


def allowed_files(decisions):
    """For each family, the file names (without .swift) that
    docs/DECISIONS.md's table of kept legacy APIs names for it."""
    section = decision_section(decisions, FRAMEWORKS_SECTION)
    lines = section.split('\n')
    header = next((number for number, line in enumerate(lines)
                   if re.match(r'^\s*\|\s*What\s*\|\s*Where\s*\|', line)), None)
    if header is None:
        raise SetupError(f'{DECISIONS}, "{FRAMEWORKS_SECTION}", has no table with What and '
                         'Where columns, which this check reads for the kept legacy APIs.')
    rows = []
    for line in lines[header + 2:]:
        if not line.strip().startswith('|'):
            break
        cells = table_cells(line)
        if len(cells) >= 2:
            rows.append(cells)
    if not rows:
        raise SetupError(f'The table in {DECISIONS}, "{FRAMEWORKS_SECTION}", has no rows.')
    allowed = {family.name: set() for family in FAMILIES}
    for cells in rows:
        what, where = cells[0], cells[1]
        names = {re.split(r'[.(\s]', name.strip().rsplit('/', 1)[-1])[0]
                 for name in re.findall(r'`([^`]+)`', where)}
        for family in FAMILIES:
            if family.row.search(what):
                allowed[family.name].update(names)
    return allowed


# ── SwiftData's configurations ───────────────────────────────────────────────

QUALIFIED = r'(?:SwiftData\s*\.\s*)?'
SWIFTDATA_TYPE = (QUALIFIED + r'(?P<type>ModelConfiguration|ModelContainer|\[\s*' + QUALIFIED
                  + r'ModelConfiguration\s*\])')
# The labels each type's initializers take ('' for an argument with none):
# a `.init(` with a label neither takes makes another type.
LABELS = {
    'ModelConfiguration': {'', 'schema', 'url', 'isStoredInMemoryOnly', 'allowsSave',
                           'groupContainer', 'cloudKitDatabase', 'for'},
    'ModelContainer': {'', 'for', 'migrationPlan', 'configurations'},
}
# Labels only ModelConfiguration's initializers take.
CONFIGURATION_ONLY = {'isStoredInMemoryOnly', 'groupContainer', 'allowsSave', 'cloudKitDatabase'}
# A body whose result has the type: a function's (`-> T {`), a computed
# property's (`: T {`) or a closure that sets one (`: T = {`).
TYPED_BODY = re.compile(r'(?:->|:)\s*' + SWIFTDATA_TYPE + r'\s*[?!]?\s*(?:=|where\b.*)?$')
SELF_BODY = re.compile(r'(?:->|:)\s*(?P<array>\[\s*)?Self\s*(?(array)\]\s*)[?!]?\s*'
                       r'(?:=|where\b.*)?$')
# A closure that names its own result: `{ name -> T in`.
CLOSURE_TYPED = re.compile(r'\s*(?:\[[^\]]*\]\s*)?(?:\([^)]*\)|[\w\s,]*?)\s*(?:async\s*)?'
                           r'(?:throws\s*(?:\([^)]*\)\s*)?)?->\s*' + SWIFTDATA_TYPE
                           + r'\s*[?!]?\s*in\b')
ANNOTATED = re.compile(r':\s*' + SWIFTDATA_TYPE + r'\s*[?!]?\s*$')   # `let c: T` before `=`
SELF_ANNOTATED = re.compile(r':\s*(?P<array>\[\s*)?Self\s*(?(array)\]\s*)[?!]?\s*$')
NAMED = re.compile(r'(?<![\w.$])(?:[sS]elf\s*\.\s*)?(?P<name>[A-Za-z_]\w*)\s*$')  # c, self.c, Self.c
# Every declaration of a name, and the type when it is one of SwiftData's:
# written after it (`let c: T`) or made right there (`var c = T(`).
BINDING = re.compile(r'(?<![\w.$])(?:var|let)\s+(?P<name>[A-Za-z_]\w*)')
DECLARED = re.compile(r'\s*:\s*' + SWIFTDATA_TYPE + r'(?![\w.\]])')
INFERRED = re.compile(r'\s*=\s*(?:try\s*[?!]?\s*)?' + QUALIFIED
                      + r'(?P<type>ModelConfiguration|ModelContainer)\s*(?:\.\s*init\s*)?\(')
# A type declared inside an extension is not the extended type. (Types
# are capitalised; `class func` and `class var` declare members.)
NESTED_TYPE = re.compile(r'(?<![\w.$])(?:struct|class|enum|actor)\s+[A-Z_]')
# A compiler directive's line (`#if DEBUG`, `#else`).
DIRECTIVE = re.compile(r'[ \t]*#(?P<kind>if|elseif|else)\b[^\n]*$')  # not #endif
IF_LINE = re.compile(r'^[ \t]*#if\b', re.M)
EXTENSION = re.compile(r'\bextension\s+(?:SwiftData\s*\.\s*)?'
                       r'(?P<type>ModelConfiguration|ModelContainer)\b[^{]*\{')
SELF_CALL = re.compile(r'(?<![\w.$])(?:Self\s*(?:\.\s*init\s*)?|self\s*\.\s*init\s*)\(')
IMPLICIT_INIT = re.compile(r'\.\s*init\s*\(')
# Statements a `return` passes through on its way to its function. A
# guard's body follows its `else`, and a defer's body cannot return.
CONTROL = re.compile(r'(?<![\w.$#])(?:if|else|switch|for|while|repeat|do|catch)\b'
                     r'|^(?:(?:mutating|nonmutating)\s+)?get\b')
# Words an expression can follow with nothing between: they end the
# expression before them. (A case's or default's colon, and an else's
# brace or `if`, always come between.)
STOP_WORDS = {'return', 'throw', 'in', 'if', 'guard', 'while', 'switch'}
NO_CLOUD = re.compile(r'\s*(?:(?:(?:SwiftData\s*\.\s*)?ModelConfiguration\s*\.\s*)?'
                      r'CloudKitDatabase\s*)?\.\s*none\s*$')


def directly_inside(between):
    """Whether code that follows `between` is the argument's own value, or
    an item of an array literal that is: not inside a call within it."""
    stack = []
    for char in between:
        if char in '([{':
            stack.append(char)
        elif char in ')]}' and stack:
            stack.pop()
    return stack in ([], ['['])


def argument_spans(code, opening, closing):
    """(start, end) of each argument of the call whose brackets are at
    `opening` and `closing`, split at its own commas."""
    spans, depth, start = [], 0, opening + 1
    for index in range(opening + 1, closing):
        char = code[index]
        if char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
        elif char == ',' and depth == 0:
            spans.append((start, index))
            start = index + 1
    if code[start:closing].strip() or spans:
        spans.append((start, closing))
    return spans


def top_level_arguments(code, opening, closing):
    """The arguments of the call whose brackets are at `opening` and
    `closing`, split at its own commas."""
    return [code[start:end] for start, end in argument_spans(code, opening, closing)]


def label(argument):
    """An argument's label, or '' when it has none."""
    match = re.match(r'\s*([A-Za-z_]\w*)\s*:', argument)
    return match.group(1) if match else ''


def labelled(arguments, name):
    """The value of the argument labelled `name`, or None."""
    for argument in arguments:
        match = re.match(r'\s*' + name + r'\s*:', argument)
        if match:
            return argument[match.end():]
    return None


def normal(kind):
    return re.sub(r'\s', '', kind).replace('SwiftData.', '')


def balanced(text):
    """Whether every bracket text opens, it also closes."""
    depth = 0
    for char in text:
        if char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
    return depth == 0


def swiftdata_calls(source):
    """Each (offset, kind, opening, closing, spelled) where the code makes
    a ModelConfiguration or a ModelContainer: by name, with `Self(` in an
    extension of the type, or with an implicit `.init(` whose type the code
    says by its context. That context is a declaration's type, a name
    declared with it, the result of a typed function, property or closure
    (through `return`, a one-expression body, if and switch expressions
    and ternaries), an array of configurations, a container's
    `configurations:`, or a label only ModelConfiguration takes; and the
    call's labels are ones the type takes."""
    code = source.code
    pairs = source.pairs()
    extensions = []
    for match in EXTENSION.finditer(code):
        brace = match.end() - 1
        extensions.append((brace, pairs.get(brace, len(code)), match.group('type')))

    def extended(offset):
        """The type an extension around offset extends, unless a type
        declared inside the extension is nearer."""
        for start, end, kind in extensions:
            if start < offset < end:
                brace = enclosing(offset)
                while brace is not None and brace > start:
                    if NESTED_TYPE.search(header(brace)[0]):
                        return None
                    brace = enclosing(brace)
                return kind
        return None

    def self_type(body, brace):
        """The type a body typed `Self` or `[Self]` gives, in an extension."""
        kind = extended(brace)
        return f'[{kind}]' if kind and body.group('array') else kind

    def before_value(index):
        """Back from index past spaces, `try`, `try?`, `try!` and `await`,
        and the lines that open a branch of `#if` (the branch's value is the
        body's, as if the directives were not there)."""
        while True:
            while index > 0 and code[index - 1].isspace():
                index -= 1
            line_start = code.rfind('\n', 0, index) + 1
            directive = DIRECTIVE.match(code, line_start, index)
            if directive:
                # An #else or #elseif branch goes back to its #if.
                opening = [found.start() for found in IF_LINE.finditer(code, 0, line_start)]
                index = line_start if directive.group('kind') == 'if' else (
                    opening[-1] if opening else 0)
                continue
            effect = re.search(r'(?<![\w.$])(?:try\s*[?!]?|await)$', code[max(0, index - 12):index])
            if not effect:
                return index
            index -= len(effect.group())

    def word_before(index):
        found = re.search(r'(?<![\w.$])[A-Za-z_]\w*$', code[max(0, index - 40):index])
        return found.group() if found else ''

    def assignment(index):
        """Whether the `=` just before index assigns, rather than compares."""
        return code[index - 2:index - 1] not in ('=', '!', '<', '>') and code[index:index + 1] != '='

    def ternary(index):
        """Whether the `?` at index - 1 is a ternary's, which has space on
        both sides, rather than `try?`, `x?.y` or half of `??`."""
        return code[index - 1] == '?' and code[index - 2:index - 1].isspace() and code[
            index:index + 1].isspace()

    def expression_start(index):
        """Where the expression that ends just before index starts: just
        after the nearest delimiter at its own depth. Swift needs one
        before every expression this follows, so line breaks are only
        space here."""
        while index > 0:
            char = code[index - 1]
            if char in ')]}' and index - 1 in pairs:
                index = pairs[index - 1]
            elif char in '([{,;:' or ternary(index):
                return index
            elif char == '=' and assignment(index):
                return index
            elif char.isalnum() or char == '_':
                name = re.search(r'\w+$', code[max(0, index - 40):index]).group()
                if name in STOP_WORDS:
                    return index
                index -= len(name)
            else:
                index -= 1
        return 0

    def enclosing(index):
        """The brace the code at index is inside."""
        while index > 0:
            index -= 1
            if code[index] in ')]}' and index in pairs:
                index = pairs[index]
            elif code[index] == '{':
                return index
        return None

    def header(brace):
        """The code before a brace back to the statement before it, with the
        insides of parentheses left out (`func f() -> T`, `if x`, `else`),
        and where it starts. Square brackets keep theirs, since an array
        type is a type (`-> [T]`). A brace inside a call's parentheses is a
        closure."""
        pieces, index = [], brace
        while index > 0:
            char = code[index - 1]
            if char == ')' and index - 1 in pairs:
                pieces.append('()')
                index = pairs[index - 1]
            elif char == ']' and index - 1 in pairs:
                pieces.append(code[pairs[index - 1]:index])
                index = pairs[index - 1]
            elif char in '{};([':
                break
            else:
                pieces.append(char)
                index -= 1
        return ' '.join(''.join(reversed(pieces)).split()), index

    declarations = {}
    for match in BINDING.finditer(code):
        typed = DECLARED.match(code, match.end()) or INFERRED.match(code, match.end())
        brace = enclosing(match.start())
        scope = (-1, len(code) + 1) if brace is None else (brace, pairs.get(brace, len(code)))
        declarations.setdefault(match.group('name'), []).append(
            (scope, normal(typed.group('type')) if typed else None))

    def declared(name, offset):
        """The SwiftData type a name used at offset has: its nearest
        declaration around offset says, or, with none around it, every
        declaration of it in the file, when they agree."""
        found = declarations.get(name, [])
        around = [(scope, kind) for scope, kind in found if scope[0] < offset < scope[1]]
        if around:
            return max(around, key=lambda item: item[0][0])[1]
        kinds = {kind for _, kind in found}
        return kinds.pop() if len(kinds) == 1 else None

    def signature(brace):
        """The type a closure at the brace names for its result, if any."""
        typed = CLOSURE_TYPED.match(code, brace + 1)
        return normal(typed.group('type')) if typed else None

    def returned(brace):
        """What a `return` inside the brace returns: its function's,
        property's or closure's type, through any statements around it."""
        while brace is not None:
            if signature(brace):
                return signature(brace)
            text, _ = header(brace)
            typed = TYPED_BODY.search(text)
            if typed:
                return normal(typed.group('type'))
            self_body = SELF_BODY.search(text)
            if self_body:
                return self_type(self_body, brace)
            if not CONTROL.search(text):
                return None
            brace = enclosing(brace)
        return None

    def result(brace, depth):
        """The type of a body's one expression, or of a branch of an if or
        switch expression, at the brace."""
        if brace is None or depth > 40:
            return None
        if signature(brace):
            return signature(brace)
        text, start = header(brace)
        typed = TYPED_BODY.search(text)
        if typed:
            return normal(typed.group('type'))
        self_body = SELF_BODY.search(text)
        if self_body:
            return self_type(self_body, brace)
        if re.match(r'else\b', text) and start - 1 in pairs and code[start - 1] == '}':
            return result(pairs[start - 1], depth + 1)  # the if's first branch
        expression = re.search(r'(?<![\w.$])(?:if|switch)\b', code[start:brace])
        if expression:
            return value(start + expression.start(), depth + 1)
        if re.match(r'(?:(?:mutating|nonmutating)\s+)?get\b', text):
            return result(enclosing(brace), depth + 1)
        return None

    def value(position, depth=0):
        """The type the code expects of the value that starts at position,
        when the code before it says so."""
        if depth > 40:
            return None
        index = before_value(position)
        if index == 0:
            return None
        keyword = word_before(index)
        char = code[index - 1]
        if keyword == 'return':
            return returned(enclosing(position))
        if keyword == 'in':  # a closure's parameters end before its body
            return result(enclosing(position), depth + 1)
        if char == '{':
            return result(index - 1, depth + 1)
        if char == '=' and assignment(index):
            before = code[max(0, index - 400):index - 1]
            annotated = ANNOTATED.search(before)
            if annotated:
                return normal(annotated.group('type'))
            self_annotated = SELF_ANNOTATED.search(before)
            if self_annotated:
                return self_type(self_annotated, index)
            named = NAMED.search(before)
            return declared(named.group('name'), index) if named else None
        if ternary(index):  # a ternary's first branch
            return value(expression_start(index - 1), depth + 1)
        if code[index - 2:index] == '??':  # what stands in for nil
            return value(expression_start(index - 2), depth + 1)
        if char == ':':
            start = expression_start(index - 1)
            if start and ternary(start):  # a ternary's other branch
                return value(expression_start(start - 1), depth + 1)
            line = code[code.rfind('\n', 0, index - 1) + 1:index - 1]
            # The case's own colon, not a label inside a call on its line.
            if re.match(r'\s*(?:case\b|default\s*$)', line) and balanced(line):
                return result(enclosing(position), depth + 1)
            return None
        if char == '(' and len(argument_spans(code, index - 1, pairs.get(index - 1, len(code)))) == 1:
            # Parentheses that only group: after a word that ends an
            # expression, or an operator, not after what a call follows
            # (a name, `)`, `]`, or `?`, `!` or `>` right after one).
            outside = before_value(index - 1)
            before = code[outside - 1:outside]
            called = re.match(r'[\w)\]]', before) or (
                before in ('?', '!', '>') and re.match(r'[\w)\]]', code[outside - 2:outside - 1]))
            if word_before(outside) in STOP_WORDS or not called:
                return value(index - 1, depth + 1)
        if char in '[,':  # an item of an array literal, not of a subscript
            bracket = index - 1
            while code[bracket] == ',':
                bracket = expression_start(bracket) - 1
            if bracket < 0 or code[bracket] != '[':
                return None
            # A subscript's bracket follows its value, which says no type.
            if value(bracket, depth + 1) == '[ModelConfiguration]':
                return 'ModelConfiguration'
        return None

    calls = []

    def made(offset, opening, kind, spelled):
        """Record the call when its labels are ones the type takes."""
        closing = pairs.get(opening, len(code))
        labels = {label(argument) for argument in top_level_arguments(code, opening, closing)}
        if labels <= LABELS[kind]:
            calls.append((offset, kind, opening, closing, spelled))
            return True
        return False

    for kind in LABELS:
        for match in word(kind).finditer(code):
            rest = re.match(r'\s*(?:\.\s*init\s*)?\(', code[match.end():])
            if rest:
                calls.append((match.start(), kind, match.end() + rest.end() - 1,
                              pairs.get(match.end() + rest.end() - 1, len(code)), f'`{kind}(`'))
    for match in SELF_CALL.finditer(code):
        kind = extended(match.start())
        if kind:
            made(match.start(), match.end() - 1, kind,
                 f'a {kind} made with `{" ".join(match.group()[:-1].split())}(`')
    unknown = []
    for match in IMPLICIT_INIT.finditer(code):
        if re.match(r'[\w)\]}?!>]', code[match.start() - 1:match.start()]):
            continue  # Type.init( names its type
        kind = value(match.start())
        if not (kind in LABELS and made(match.start(), match.end() - 1, kind,
                                        f'a {kind} made with `.init(`')):
            unknown.append((match.start(), match.end() - 1))
    # A container's `configurations:` holds configurations, its own and any
    # after it (they are variadic).
    containers = []
    for _, kind, opening, closing, _ in list(calls):
        if kind == 'ModelContainer':
            spans = argument_spans(code, opening, closing)
            starts = [start for start, end in spans if label(code[start:end]) == 'configurations']
            if starts:
                containers.append((starts[0], closing))
    for offset, opening in unknown:
        arguments = top_level_arguments(code, opening, pairs.get(opening, len(code)))
        if {label(argument) for argument in arguments} & CONFIGURATION_ONLY or any(
                start <= offset < end and directly_inside(code[start:offset])
                for start, end in containers):
            made(offset, opening, 'ModelConfiguration',
                 'a ModelConfiguration made with `.init(`')
    return calls


def check_app_file(source, allowed, declared):
    """What one of the app's Swift files must not contain."""
    findings = []
    path = source.path

    def found(offset, rule, message):
        findings.append(Finding(path, source.line(offset), rule, message))

    used = {family.name: [] for family in FAMILIES}
    for match in IMPORT.finditer(source.code):
        module = match.group('module')
        offset = match.start('module')
        if module in FORBIDDEN_IMPORTS:
            found(offset, 'forbidden framework', f'`import {module}`: {FORBIDDEN_IMPORTS[module]}.')
        elif module in FAMILY_BY_MODULE:
            used[FAMILY_BY_MODULE[module].name].append((offset, module))
        elif module not in APP_IMPORTS:
            found(offset, 'framework not on the list',
                  f'`import {module}`: the app imports only the frameworks '
                  'scripts/forbidden-code.py lists in APP_IMPORTS. If it is not for a hard '
                  'stop (invariant 9) and keeps the privacy policy true, add it there in '
                  'this pull request, so a reviewer sees it.')

    for rule, why, pattern in APP_WORDS:
        for match in pattern.finditer(source.code):
            name = match.group()
            if name in declared and PREFIXED.match(name):
                continue
            found(match.start(), rule, f'`{name}`: {why}.')
    for match in MEMBER_GESTURE.finditer(source.code):
        found(match.start(), 'gesture', f'`.gesture(`: {GESTURE}.')
    for match in TOOLBAR_CALL.finditer(source.code):
        if re.search(r'\bfunc\s*$', source.code[max(0, match.start() - 12):match.start()]):
            continue
        opening = match.end() - 1
        arguments = top_level_arguments(source.code, opening, source.closing(opening))
        if not arguments or re.match(r'\s*\w+\s*:', arguments[0]):
            continue  # the content or a labelled argument, not a visibility
        bars = [argument for argument in arguments if re.match(r'\s*for\s*:', argument)]
        if re.search(r'\.\s*hidden\b', arguments[0]) and (not bars or re.search(
                r'\.\s*(?:navigationBar|automatic)\b', ','.join(
                    arguments[arguments.index(bars[0]):]))):
            found(match.start(), 'hidden navigation',
                  f'`.{match.group("name")}(` with `.hidden`: {NAVIGATION}.')
    for match in ROLLBACK_USE.finditer(source.code):
        if re.search(r'\bfunc\s*$', source.code[max(0, match.start() - 12):match.start()]):
            continue
        if not re.search(r'\(\s*\)$', source.text[match.start():match.end()]):
            continue  # a string in the parentheses, blanked: a case of Brickson's own
        found(match.start(), 'rollback', f'`rollback`: {ROLLBACK}.')

    for family in FAMILIES:
        uses = used[family.name] + family_uses(source, family, declared)
        if uses and Path(path).stem not in allowed[family.name]:
            offset, name = min(uses)
            found(offset, 'legacy framework',
                  f'`{name}` is {family.name}, and {path} is not named for it in {DECISIONS}, '
                  f'"{FRAMEWORKS_SECTION}". Use {family.current}. {HOW_TO_ALLOW}.')

    for offset, kind, opening, closing, spelled in swiftdata_calls(source):
        arguments = top_level_arguments(source.code, opening, closing)
        if kind == 'ModelConfiguration':
            database = labelled(arguments, 'cloudKitDatabase')
            if database is None or not NO_CLOUD.match(database):
                found(offset, 'cloud sync',
                      f'{spelled} without `cloudKitDatabase: .none`: SwiftData syncs with iCloud by '
                      f'default when a capability allows it; {CLOUD}.')
        elif re.fullmatch(r'\s*(?:\[\s*\]\s*)?', labelled(arguments, 'configurations') or ''):
            # No configurations, or an empty list of them: SwiftData makes
            # its default one.
            found(offset, 'cloud sync',
                  f'{spelled} without `configurations:` opens SwiftData\'s default configuration, '
                  'which syncs with iCloud when a capability allows it; pass a ModelConfiguration '
                  'with `cloudKitDatabase: .none`.')
    for match in MODEL_CONTAINER_FOR.finditer(source.code):
        found(match.start(), 'cloud sync',
              '`.modelContainer(for:` opens SwiftData\'s default configuration, which syncs with '
              'iCloud when a capability allows it; pass a container opened with '
              '`cloudKitDatabase: .none`.')

    for match in OBSERVER_CALL.finditer(source.code):
        opening = source.code.index('(', match.start())
        closing = source.closing(opening)
        arguments = source.code[opening:closing]
        if re.search(r'\bselector\s*:', arguments) and re.search(r'\bname\s*:', arguments):
            found(match.start(), 'notification observer',
                  'a notification observer with a selector cannot run on the main queue inside '
                  '`MainActor.assumeIsolated`: use `addObserver(forName:object:queue:using:)` with '
                  '`queue: .main` (AGENTS.md, *Workflow rules*).')
            continue
        if not re.search(r'\bforName\s*:', arguments):
            continue
        body = arguments
        after = source.code[closing + 1:]
        trailing = re.match(r'\s*\{', after)
        if trailing:
            brace = closing + 1 + trailing.end() - 1
            body += source.code[brace:source.closing(brace) + 1]
        if not re.search(r'\bqueue\s*:\s*(?:OperationQueue\s*)?\.\s*main\b', arguments) or not re.search(
                r'\bMainActor\s*\.\s*assumeIsolated\b', body):
            found(match.start(), 'notification observer',
                  'a notification observer uses `queue: .main` and runs its work inside '
                  '`MainActor.assumeIsolated` (AGENTS.md, *Workflow rules*).')
    return findings


# ── The tests' rules ─────────────────────────────────────────────────────────

CITES_DECISION = re.compile(r'docs/DECISIONS\.md,\s*\\?#*"')
SKIP_CALL = re.compile(r'\b(?P<name>XCTSkip|XCTSkipIf|XCTSkipUnless)\s*\(')
TRAIT_ATTRIBUTE = re.compile(r'@(?:Test|Suite)\s*\(')
TRAIT = re.compile(r'\.\s*(?P<name>disabled|enabled)\b')
KNOWN_ISSUE = re.compile(r'\b(?P<name>withKnownIssue|XCTExpectFailure)\b')
NOT_STRICT = re.compile(
    r'\bisIntermittent\s*:\s*true\b|\bisStrict\s*=\s*false\b|\.\s*nonStrict\s*\('
    r'|\bstrict\s*:\s*false\b')


def reasons(source, name, opening):
    """The strings that say why a skip happens: those in the call's
    arguments, never in its condition (XCTSkipIf's and XCTSkipUnless's
    first argument, a trait's `if:`), whose strings say nothing of why."""
    found = []
    closing = source.closing(opening)
    # A lone string argument is blank in the code, so it splits to nothing.
    spans = argument_spans(source.code, opening, closing) or [(opening + 1, closing)]
    for index, (start, end) in enumerate(spans):
        if label(source.code[start:end]) == 'if' or (
                index == 0 and name in ('XCTSkipIf', 'XCTSkipUnless')):
            continue
        found += source.top_level_strings(start - 1, end)
    return found


def check_test_file(source):
    """What a test file must not do: a known issue that is not strict or
    names no decision, or a skip that does not say why (AGENTS.md, *Code
    Review Rules*)."""
    findings = []
    path = source.path

    def found(offset, rule, message):
        findings.append(Finding(path, source.line(offset), rule, message))

    for match in KNOWN_ISSUE.finditer(source.code):
        name = match.group('name')
        rest = re.match(r'\s*\(', source.code[match.end():])
        strings = []
        if rest:
            opening = match.end() + rest.end() - 1
            strings = source.top_level_strings(opening, source.closing(opening))
        if not strings or not CITES_DECISION.search(strings[0]):
            found(match.start(), 'known issue',
                  f'`{name}` names its decision: start its comment with '
                  f'{DECISIONS}, then the section\'s title in quotes.')
    for match in NOT_STRICT.finditer(source.code):
        found(match.start(), 'known issue',
              'a known issue is strict: it fails the run once the issue is fixed, so the '
              'record is updated (AGENTS.md, *Code Review Rules*).')
    for match in SKIP_CALL.finditer(source.code):
        if not reasons(source, match.group('name'), match.end() - 1):
            found(match.start(), 'unexplained skip',
                  f'`{match.group("name")}` says why, in a string in the call.')
    for attribute in TRAIT_ATTRIBUTE.finditer(source.code):
        opening = attribute.end() - 1
        closing = source.closing(opening)
        for trait in TRAIT.finditer(source.code, opening, closing):
            # A trait is one of the attribute's own arguments, never a value
            # inside one (`arguments: [Mode.enabled]`).
            between = source.code[opening + 1:trait.start()]
            depth = sum(between.count(char) for char in '([{') - sum(
                between.count(char) for char in ')]}')
            if depth or not re.search(r'[(,]\s*$', source.code[opening:trait.start()]):
                continue
            rest = re.match(r'\s*\(', source.code[trait.end():closing])
            if not (rest and reasons(source, trait.group('name'), trait.end() + rest.end() - 1)):
                found(trait.start(), 'unexplained skip',
                      f'`.{trait.group("name")}` says why, in a string in the trait.')
    return findings


# ── project.yml, workflows and other files ───────────────────────────────────

@dataclass(frozen=True)
class Entry:
    """One line of a YAML file that holds a key or a list item."""
    line: int
    path: tuple    # the keys above it and its own; '-' for a list item
    key: str       # '' for a plain list item
    value: str     # its value on the line, unquoted; '' when it has children
    block: str     # the text of a block scalar (run: |), else ''
    inline: bool = False  # a key of a one-line mapping ({a: b}) on that line


YAML_KEY = re.compile(r'''^(?P<key>"[^"]*"|'[^']*'|[^\s"'#\-\[{][^:#]*?|-[^\s:#][^:#]*?)'''
                      r'''\s*:(?:\s+(?P<value>.*))?$''')
BLOCK_SCALAR = re.compile(r'[|>][-+0-9]*')


# What comes just before a quoted scalar in a flow collection.
SCALAR_START = ('', '[', '{', ',', ':')
# An anchor (&name) or a tag (!tag) before a value names it; it is not
# the value.
PROPERTIES = re.compile(r'^\s*(?:[&!][^\s\[\]{},]*(?:\s+|$))+')


def unquote(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in '"\'':
        return value[1:-1]
    return value


def without_yaml_comment(line):
    quote = None
    previous = ''
    index = 0
    while index < len(line):
        char = line[index]
        if quote:
            if quote == '"' and char == '\\':
                index += 1  # an escaped character
            elif char == quote and quote == "'" and line[index + 1:index + 2] == "'":
                index += 1  # '' is a quote mark inside single quotes
            elif char == quote:
                quote = None
        elif char in '"\'' and previous in ('', ':', '-', '[', ',', '{'):
            quote = char
        elif char == '#' and (index == 0 or line[index - 1] in ' \t'):
            return line[:index].rstrip()
        if not char.isspace():
            previous = char
        index += 1
    return line.rstrip()


def unclosed(value):
    """Whether a value opens a flow collection ([…] or {…}) or a quoted
    string that does not close on its line, so YAML carries it on."""
    value = value.strip()
    if not value or value[0] not in '[{"\'':
        return False
    depth, quote, index, previous = 0, None, 0, ''
    while index < len(value):
        char = value[index]
        if quote:
            if quote == '"' and char == '\\':
                index += 1
            elif char == quote and quote == "'" and value[index + 1:index + 2] == "'":
                index += 1
            elif char == quote:
                quote = None
                if depth == 0:
                    return False
        elif char in '"\'' and previous in SCALAR_START:  # not the ' in `it's`
            quote = char
        elif char in '[{':
            depth += 1
        elif char in ']}':
            depth -= 1
            if depth == 0:
                return False
        if not char.isspace():
            previous = char
        index += 1
    return True


def inline_entries(number, path, value):
    """The keys of a one-line mapping, and of the mappings inside it, as
    entries of their own, so every rule reads `{a: b}` as it reads a
    block."""
    entries = []
    # Each value as written: a quoted one is a string, never a collection
    # (`PATTERN: '[0-9]+'`), and a collection's items are shorter than it.
    for key, inner in flow_mapping(value, quoted=True) or []:
        entries.append(Entry(number, path + (key,), key, unquote(inner), '', True))
        entries += inline_entries(number, path + (key,), inner)
    value = value.strip()
    if value.startswith('[') and value.endswith(']'):  # a list's mappings: [{ a: b }]
        for item in flow_list(value, quoted=True):
            entries += inline_entries(number, path + ('-',), item)
    return entries


def yaml_entries(text):
    """The keys and list items of a YAML file, with the keys above each:
    the subset of YAML that project.yml and the workflows use. Lines inside
    a block scalar are text, never keys; a flow collection or a quoted
    string carried over several lines is one value; the keys of a one-line
    mapping are entries too."""
    entries = []
    stack = []  # (indent, key, has children)
    lines = text.split('\n')
    index = 0
    while index < len(lines):
        number = index + 1
        line = without_yaml_comment(lines[index])
        index += 1
        content = line.strip()
        if not content or content in ('---', '...'):
            continue
        indent = len(line) - len(line.lstrip(' '))
        item_indent = indent
        is_item = content == '-' or content.startswith('- ')
        while stack and (stack[-1][0] > indent or (stack[-1][0] == indent and not (
                is_item and stack[-1][1] != '-' and stack[-1][2]))):
            stack.pop()
        while content == '-' or content.startswith('- '):
            stack.append((indent, '-', True))
            rest = content[1:].lstrip()
            indent += len(content) - len(rest)
            content = rest
        if not content:
            continue
        if indent != item_indent and BLOCK_SCALAR.fullmatch(content):
            block_lines = []
            while index < len(lines):
                following = lines[index]
                if following.strip() and len(following) - len(following.lstrip(' ')) <= item_indent:
                    break
                block_lines.append(following)
                index += 1
            path = tuple(name for _, name, _ in stack)
            entries.append(Entry(number, path, '', '', '\n'.join(block_lines)))
            continue
        match = YAML_KEY.match(content)
        rest = PROPERTIES.sub('', (match.group('value') or '') if match else content)
        while unclosed(rest) and index < len(lines):
            following = lines[index] if rest.lstrip()[:1] in '"\'' else without_yaml_comment(
                lines[index])
            rest = rest.rstrip() + ' ' + following.strip()
            index += 1
        if match:
            key = unquote(match.group('key'))
            value = rest.strip()
            block = ''
            if BLOCK_SCALAR.fullmatch(value):
                block_lines = []
                while index < len(lines):
                    following = lines[index]
                    if following.strip() and len(following) - len(following.lstrip(' ')) <= indent:
                        break
                    block_lines.append(following)
                    index += 1
                block = '\n'.join(block_lines)
                value = ''
            path = tuple(name for _, name, _ in stack) + (key,)
            entries.append(Entry(number, path, key, unquote(value), block))
            entries += inline_entries(number, path, value)
            stack.append((indent, key, value == '' and not block))
        else:
            path = tuple(name for _, name, _ in stack)
            entries.append(Entry(number, path, '', unquote(rest), ''))
            entries += inline_entries(number, path, rest)
    return entries


def flow_list(value, quoted=False):
    """The items of a one-line YAML list ([a, b]) or a single value;
    `quoted` keeps each item's quotes."""
    read = (lambda item: item.strip()) if quoted else unquote
    value = value.strip()
    if value.startswith('[') and value.endswith(']'):
        return [read(item) for item in split_flow(value[1:-1])]
    return [read(value)] if value else []


def split_flow(inner):
    """The items of a flow collection's inside, split at its own commas."""
    items, depth, quote, current = [], 0, None, ''
    for char in inner:
        if quote:
            quote = None if char == quote else quote
        elif char in '"\'' and current.rstrip()[-1:] in SCALAR_START:  # not `it's`
            quote = char
        elif char in '[{':
            depth += 1
        elif char in ']}':
            depth -= 1
        elif char == ',' and depth == 0:
            items.append(current)
            current = ''
            continue
        current += char
    items.append(current)
    return [item.strip() for item in items if item.strip()]


def flow_mapping(value, quoted=False):
    """The (key, value) pairs of a one-line YAML mapping ({a: b}), or None
    when the value is not one; `quoted` keeps each value's quotes."""
    value = value.strip()
    if not (value.startswith('{') and value.endswith('}')):
        return None
    pairs = []
    for item in split_flow(value[1:-1]):
        key = re.match(r'''\s*("[^"]*"|'[^']*'|[^:]*)''', item).group(1)
        rest = item[len(item) - len(item.lstrip()) + len(key):].lstrip()
        rest = rest[1:] if rest.startswith(':') else ''
        pairs.append((unquote(key), rest.strip() if quoted else unquote(rest)))
    return pairs


def source_path(value):
    """A source's path as XcodeGen reads it, from the project's folder:
    `./App/` and `App` are the same folder."""
    path = posixpath.normpath(value)
    if path == '..' or path.startswith(('../', '/')):
        raise SetupError(f'project.yml compiles `{value}`, outside this checkout, which this '
                         'check cannot read: keep every source in the repository.')
    return '' if path == '.' else path


def targets(entries):
    """Each target's type and the source paths it compiles, from
    project.yml."""
    kinds = {}
    sources = {}
    for entry in entries:
        path = entry.path
        if len(path) == 3 and path[0] == 'targets' and path[2] == 'type':
            kinds[path[1]] = entry.value
        found = []
        if len(path) >= 4 and path[0] == 'targets' and path[2] == 'sources':
            # `- App` or `- path: App` (and `- { path: App }`, whose keys
            # are entries of their own).
            if path[3:] in (('-',), ('-', 'path')):
                found.append(entry.value)
        if len(path) == 3 and path[0] == 'targets' and path[2] == 'sources' and entry.value:
            # sources: [App] (a mapping's keys are entries of their own)
            found.extend(item for item in flow_list(entry.value) if flow_mapping(item) is None)
        for source in found:
            if source:
                sources.setdefault(path[1], []).append(source_path(source))
    return kinds, sources


def under(path, folders):
    """Whether path is in one of the folders, ignoring letter case as a
    Mac's file system does."""
    path = path.casefold()
    return any(folder == '' or path == folder.casefold() or path.startswith(folder.casefold() + '/')
               for folder in folders)


CAPABILITIES = [
    (re.compile(r'com\.apple\.developer\.(?:icloud|ubiquity)[\w.-]*'), CLOUD),
    (re.compile(r'\baps-environment\b'), 'no push notifications: they need a server (invariant 9)'),
    (re.compile(r'com\.apple\.developer\.applesignin'), ACCOUNTS),
    (re.compile(r'com\.apple\.developer\.networking\.[\w.-]+'), NETWORK),
    # Also as an INFOPLIST_KEY_ build setting, so no \b before the name.
    (re.compile(r'(?<![A-Za-z0-9])NSUserTrackingUsageDescription\b'), TRACKING),
    (re.compile(r'(?<![A-Za-z0-9])(?:NSAppTransportSecurity|NSLocalNetworkUsageDescription'
                r'|NSBonjourServices)\b'), NETWORK),
]
NETWORK_BACKGROUND_MODES = {'remote-notification': 'push notifications need a server',
                            'fetch': 'background fetch is network code'}
# .gitmodules: another repository's code, checked out inside this one.
PACKAGE_FILES = {'Package.swift', 'Package.resolved', 'Podfile', 'Podfile.lock', 'Cartfile',
                 'Cartfile.resolved', 'Cartfile.private', '.gitmodules'}
PACKAGE_SUFFIXES = ('.xcframework', '.framework', '.a', '.dylib')
PACKAGES = 'no third-party packages or SDKs: only Apple\'s frameworks (invariant 9)'
WARNING_SETTINGS = ('SWIFT_TREAT_WARNINGS_AS_ERRORS', 'GCC_TREAT_WARNINGS_AS_ERRORS')
SILENCING_SETTINGS = ('SWIFT_SUPPRESS_WARNINGS', 'GCC_WARN_INHIBIT_ALL_WARNINGS')
FLAG_SETTINGS = ('OTHER_SWIFT_FLAGS', 'OTHER_CFLAGS', 'OTHER_CPLUSPLUSFLAGS', 'WARNING_CFLAGS')
SILENCING_FLAG = re.compile(r'(?:^|\s)(?:-suppress-warnings|-w|-Wno-\S+|-no-warnings-as-errors)(?=\s|$)')
# Keeping one group of warnings as warnings: the narrower route that
# docs/DECISIONS.md, "Warnings are errors", allows only for its safety
# exception, in a target that section names.
GROUP_SETTING = 'SWIFT_WARNINGS_AS_WARNINGS_GROUPS'
GROUP_FLAG = re.compile(r'(?:^|\s)-Wwarning\s+\S+')
WARNINGS = (f'warnings are errors: fix the code, never silence the warning ({DECISIONS}, '
            f'"{WARNINGS_SECTION}")')


def setting_name(key):
    """A build setting's name without its conditions: XcodeGen passes
    `KEY[config=Debug]` and `KEY[sdk=…]` to Xcode as they are."""
    return re.sub(r'(?:\[[^\]]*\])+$', '', key)


def shell_words(value):
    """A flag setting's words as the compiler gets them: Xcode splits the
    value as a shell does, so `"-w"` is `-w`."""
    return re.sub(r'["\']', ' ', value).strip()


def truthy(value):
    return unquote(value).upper() in ('YES', 'TRUE', '1')


def version(value):
    numbers = [int(part) for part in re.findall(r'\d+', value)]
    while len(numbers) > 1 and numbers[-1] == 0:
        numbers.pop()
    return tuple(numbers)


def check_project(entries, files, read, decisions):
    """project.yml, and the files it builds from, against the rules."""
    findings = []
    project = 'project.yml'

    def found(path, line, rule, message):
        findings.append(Finding(path, line, rule, message))

    for entry in entries:
        if len(entry.path) == 1 and entry.key in ('packages', 'localPackages', 'projectReferences'):
            found(project, entry.line, 'third-party package', f'`{entry.key}:`: {PACKAGES}.')
        if 'dependencies' in entry.path[:-1] and entry.key in ('package', 'carthage', 'framework',
                                                               'bundle'):
            found(project, entry.line, 'third-party package',
                  f'a `{entry.key}:` dependency: {PACKAGES}; a target depends only on targets '
                  'and Apple\'s SDKs.')
    for path in files:
        parts = path.split('/')
        if parts[-1] in PACKAGE_FILES or any(part.endswith(PACKAGE_SUFFIXES[:2]) for part in parts) \
                or path.endswith(PACKAGE_SUFFIXES[2:]):
            found(path, 0, 'third-party package', f'{PACKAGES}.')

    # Capabilities and Info.plist keys, wherever they can be written.
    # A one-line mapping's text is read from its keys, entries of their own.
    places = [(project, [(entry.line, entry.key + ' ' + (
        '' if flow_mapping(entry.value) is not None else entry.value)) for entry in entries])]
    for path in files:
        if path.endswith(('.entitlements', '.xcconfig', '.plist')):
            text = read(path)
            places.append((path, list(enumerate(text.split('\n'), start=1))))
    for path, lines in places:
        for number, line in lines:
            for pattern, why in CAPABILITIES:
                for match in pattern.finditer(line):
                    found(path, number, 'capability', f'`{match.group()}`: {why}.')
    for entry in entries:
        if entry.path and 'UIBackgroundModes' in entry.path:
            values = flow_list(entry.value) if entry.key == 'UIBackgroundModes' else (
                [entry.value] if not entry.key else [])
            for mode in values:
                if mode in NETWORK_BACKGROUND_MODES:
                    found(project, entry.line, 'capability',
                          f'background mode `{mode}`: {NETWORK_BACKGROUND_MODES[mode]} '
                          '(invariant 9).')
    for path in files:
        if path.endswith('.plist'):  # Info.plist, or any name INFOPLIST_FILE gives it
            text = read(path)
            for modes in re.finditer(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', text,
                                     re.S):
                for mode in re.findall(r'<string>([^<]*)</string>', modes.group(1)):
                    if mode in NETWORK_BACKGROUND_MODES:
                        found(path, text.count('\n', 0, modes.start()) + 1, 'capability',
                              f'background mode `{mode}`: {NETWORK_BACKGROUND_MODES[mode]} '
                              '(invariant 9).')

    # Warnings are errors.
    warnings_section = decision_section(decisions, WARNINGS_SECTION)
    exception = ('Only the safety exception that section describes may do this, in one target '
                 'the section names in backticks.')

    def excepted(entry):
        target = entry.path[1] if len(entry.path) > 2 and entry.path[0] == 'targets' else None
        return target is not None and f'`{target}`' in warnings_section

    # XcodeGen reads a `settings:` map with no base, configs or groups as
    # its base settings.
    simple = not any(len(entry.path) == 2 and entry.path[0] == 'settings'
                     and entry.key in ('base', 'configs', 'groups') for entry in entries)
    seen = set()
    for position, entry in enumerate(entries):
        name = setting_name(entry.key)
        if name in WARNING_SETTINGS:
            if entry.path == ('settings', 'base', name) or (simple and entry.path == ('settings',
                                                                                      name)):
                seen.add(name)
                if not truthy(entry.value):
                    found(project, entry.line, 'warnings', f'`{name}` stays YES: {WARNINGS}.')
            elif not truthy(entry.value) and not excepted(entry):
                found(project, entry.line, 'warnings',
                      f'`{entry.key}: {entry.value}`: {WARNINGS}. {exception}')
        if name in SILENCING_SETTINGS and truthy(entry.value):
            found(project, entry.line, 'warnings', f'`{entry.key}`: {WARNINGS}.')
        # compilerFlags (a source's, or a file type's in options) reach the
        # compiler as the flag settings do.
        if name in FLAG_SETTINGS or name == GROUP_SETTING or entry.key == 'compilerFlags':
            # The whole value: a string, a one-line list, a block scalar,
            # the items of a list, or a plain value continued on more lines.
            parts = [' '.join(flow_list(entry.value)), entry.block]
            for later in entries[position + 1:]:
                if later.path[:len(entry.path)] != entry.path:
                    break
                if not later.key and later.path in (entry.path, entry.path + ('-',)):
                    parts.append(later.value or later.block)
            flags = shell_words(' '.join(parts))
            if name == GROUP_SETTING:
                if flags and not excepted(entry):
                    found(project, entry.line, 'warnings',
                          f'`{entry.key}`: {WARNINGS}. {exception}')
            elif SILENCING_FLAG.search(flags):
                found(project, entry.line, 'warnings',
                      f'`{entry.key}` silences warnings: {WARNINGS}.')
            elif GROUP_FLAG.search(flags) and not excepted(entry):
                found(project, entry.line, 'warnings',
                      f'`{entry.key}` keeps a group of warnings as warnings: {WARNINGS}. '
                      f'{exception}')
    for setting in WARNING_SETTINGS:
        if setting not in seen:
            found(project, 0, 'warnings',
                  f'`{setting}: "YES"` belongs in the project-wide `settings: base:`: {WARNINGS}.')
    for path in files:
        if path.endswith('.xcconfig'):
            for number, line in enumerate(read(path).split('\n'), start=1):
                setting = re.match(r'\s*(\w+)(?:\[[^\]]*\])*\s*=\s*(.*)$', line.split('//')[0])
                if not setting:
                    continue
                key, value = setting.groups()
                flags = shell_words(value)
                if (key in WARNING_SETTINGS and not truthy(value)) or (
                        key in SILENCING_SETTINGS and truthy(value)) or (
                        key == GROUP_SETTING and value.strip()) or (
                        key in FLAG_SETTINGS and (SILENCING_FLAG.search(flags)
                                                  or GROUP_FLAG.search(flags))):
                    found(path, number, 'warnings', f'`{key}`: {WARNINGS}.')

    # The oldest iOS.
    minimum_section = decision_section(decisions, MINIMUM_SECTION)
    decided = re.search(r'(\d+\.\d+)\s+or later', minimum_section)
    if decided is None:
        raise SetupError(f'{DECISIONS}, "{MINIMUM_SECTION}", no longer says "<version> or '
                         'later", which this check reads.')
    minimum = decided.group(1)
    targets_found = 0
    platforms = {entry.path[1]: entry.value for entry in entries
                 if len(entry.path) == 3 and entry.path[0] == 'targets' and entry.key == 'platform'}
    for entry in entries:
        if setting_name(entry.key) == 'IPHONEOS_DEPLOYMENT_TARGET' or entry.path == (
                'options', 'deploymentTarget', 'iOS') or (
                len(entry.path) == 3 and entry.path[0] == 'targets'
                and entry.key == 'deploymentTarget' and entry.value
                and platforms.get(entry.path[1], 'iOS') in ('iOS', 'auto')):
            targets_found += 1
            if version(entry.value) != version(minimum):
                found(project, entry.line, 'minimum iOS',
                      f'`{entry.key}: {entry.value}`, but {DECISIONS}, "{MINIMUM_SECTION}", '
                      f'decides {minimum}: change both together, as that section says.')
    for path in files:
        if path.endswith('.xcconfig'):
            for number, line in enumerate(read(path).split('\n'), start=1):
                setting = re.match(r'\s*IPHONEOS_DEPLOYMENT_TARGET(?:\[[^\]]*\])*\s*=\s*(.*)$',
                                   line.split('//')[0])
                if setting:
                    targets_found += 1
                    if version(setting.group(1)) != version(minimum):
                        found(path, number, 'minimum iOS',
                              f'`IPHONEOS_DEPLOYMENT_TARGET = {setting.group(1).strip()}`, but '
                              f'{DECISIONS}, "{MINIMUM_SECTION}", decides {minimum}: change both '
                              'together, as that section says.')
    if not targets_found:
        found(project, 0, 'minimum iOS',
              f'project.yml sets no deployment target; {DECISIONS}, "{MINIMUM_SECTION}", '
              f'decides {minimum}.')
    return findings


def workflow_triggers(entries):
    """Each trigger a workflow names, with its line."""
    triggers = []
    for entry in entries:
        if entry.path[:1] not in (('on',), ('true',)):
            continue
        if len(entry.path) == 1:
            # (A one-line mapping's keys are entries of their own.)
            triggers.extend((name, entry.line) for name in flow_list(entry.value))
        elif len(entry.path) == 2 and entry.key:
            triggers.append((entry.key, entry.line))
        elif len(entry.path) == 2 and not entry.key:
            triggers.append((entry.value, entry.line))
    return triggers


# An expression that reads text a pull request's author writes: the
# event, the branch name, or the whole github context (toJSON(github)).
EVENT_TEXT = re.compile(r'\$\{\{(?:(?!\}\}).)*?(?<![\w.-])(?:github\s*\.\s*(?:event\b|head_ref\b)|github\s*\['
                        r'|github\b(?!\s*[.\[]))(?:(?!\}\}).)*\}\}', re.S)
# Events that run a pull request's code (or the merge queue's).
PULL_REQUEST_EVENTS = {'pull_request', 'pull_request_target', 'workflow_run',
                       'pull_request_review', 'pull_request_review_comment', 'merge_group',
                       'issue_comment'}
# `env.NAME` or `env['NAME']` anywhere inside an expression, a function's
# argument included (`toJSON(env.NAME)`).
ENV_READ = re.compile(r'(?<![\w.-])env\s*(?:\.\s*([\w-]+)|\[\s*[\'"]([\w-]+)[\'"]\s*\])')
EXPRESSION = re.compile(r'\$\{\{(?:(?!\}\}).)*\}\}', re.S)
REQUIRED_CHECKS = ('Unit tests', 'UI tests')
SECRETS = ('pull request code never reaches secrets or a write token '
           '(AGENTS.md, *Code Review Rules*)')


def env_reads(text):
    """(offset, name) for each env value the expressions in text read."""
    return [(expression.start() + read.start(), read.group(1) or read.group(2))
            for expression in EXPRESSION.finditer(text)
            for read in ENV_READ.finditer(expression.group())]


def quoted_end(lines, index):
    """Where a quoted value that starts on lines[index] after its key ends
    (the number of the line after it), or 0 when it is not quoted. A quoted
    YAML value may go on below its key's indent."""
    start = re.match(r'^[ \t]*(?:-[ \t]+)*[^:#]+:[ \t]*(?=["\'])', lines[index])
    if not start:
        return 0
    text = '\n'.join(lines[index:])
    quote = text[start.end()]
    position = start.end() + 1
    while position < len(text):
        char = text[position]
        if quote == '"' and char == '\\':
            position += 2
            continue
        if char == quote:
            if quote == "'" and text[position + 1:position + 2] == "'":
                position += 2
                continue
            break
        position += 1
    return index + 1 + text.count('\n', 0, position)


def check_workflow(path, text):
    """One workflow (or local action) file against the rules."""
    findings = []
    entries = yaml_entries(text)

    def found(line, rule, message):
        findings.append(Finding(path, line, rule, message))

    triggers = workflow_triggers(entries)
    names = {name for name, _ in triggers}
    for name, line in triggers:
        if name in ('pull_request_target', 'workflow_run'):
            found(line, 'workflow trigger',
                  f'`{name}` runs with the repository\'s secrets and a write token on behalf of '
                  f'a pull request: {SECRETS}.')
    if names & PULL_REQUEST_EVENTS:
        if not any(entry.path == ('permissions',) for entry in entries):
            found(0, 'workflow permissions',
                  'a workflow a pull request runs sets read-only `permissions:` at its top '
                  f'(`contents: read`): {SECRETS}.')
        for entry in entries:
            inside = 'permissions' in entry.path[:-1] or entry.key == 'permissions'
            if not inside:
                continue
            # A block scalar (`permissions: >-` and `write-all` below) is
            # its text.
            value = entry.value or ' '.join(entry.block.split())
            if value.startswith('*'):
                raise SetupError(f'{path}:{entry.line} gives permissions through the YAML alias '
                                 f'`{value}`, which this check cannot read: write them out.')
            if entry.key == 'permissions' and flow_mapping(value) is not None:
                continue  # its keys are entries of their own
            if entry.key == 'permissions':
                if value and value != 'read-all':
                    found(entry.line, 'workflow permissions',
                          f'`permissions: {value}` in a workflow a pull request runs: {SECRETS}.')
            elif value not in ('read', 'none'):
                found(entry.line, 'workflow permissions',
                      f'`{entry.key}: {value}` in a workflow a pull request runs: only `read` or '
                      f'`none`; {SECRETS}.')
    # Environment variables that hold event text: `${{ env.NAME }}` in a
    # shell command puts that text into the script just the same. A value
    # may sit on the key's line, in a block, on the lines below it, or in a
    # one-line mapping (`env: { NAME: … }`).
    values = {}
    for entry in entries:
        if 'env' not in entry.path[:-1]:
            continue
        at = max(index for index, name in enumerate(entry.path[:-1]) if name == 'env')
        name = entry.path[at + 1]
        values[name] = values.get(name, '') + '\n' + (entry.value or entry.block)
    # A value that reads a tainted value is tainted too: follow them all.
    tainted = {name for name, value in values.items() if EVENT_TEXT.search(value)}
    while True:
        more = {name for name, value in values.items() if name not in tainted
                and any(read in tainted for _, read in env_reads(value))}
        if not more:
            break
        tainted |= more
    lines = text.split('\n')
    for entry in entries:
        if entry.key == 'run':
            # The command's own lines: everything indented past its key,
            # whether a block scalar, a quoted or a plain multi-line value;
            # in a one-line mapping (`- { run: … }`), its value.
            first = lines[entry.line - 1]
            column = re.match(r'^[ \t]*(?:-[ \t]+)*', first).end()
            end = entry.line
            while end < len(lines) and (not lines[end].strip() or (
                    len(lines[end]) - len(lines[end].lstrip(' ')) > column)):
                end += 1
            end = max(end, quoted_end(lines, entry.line - 1))
            body = entry.value if entry.inline else '\n'.join(lines[entry.line - 1:end])
            for match in EVENT_TEXT.finditer(body):
                found(entry.line + body.count('\n', 0, match.start()),
                      'event text in a shell command',
                      'a `${{ github.event… }}`, `github.head_ref` or whole `github` expression '
                      'inside `run:` puts text anyone can write into the shell: pass it through `env:` and '
                      'quote the variable (AGENTS.md, *Code Review Rules*).')
            for offset, name in env_reads(body):
                if name in tainted:
                    found(entry.line + body.count('\n', 0, offset),
                          'event text in a shell command',
                          f'`${{{{ env.{name} }}}}` inside `run:` holds event text, and GitHub '
                          'puts it into the script before the shell runs: read it as the '
                          f'quoted shell variable "${name}" instead '
                          '(AGENTS.md, *Code Review Rules*).')
        if entry.key == 'uses':
            action = entry.value
            if not (action.startswith(('actions/', 'github/', './'))):
                found(entry.line, 'outside action',
                      f'`uses: {action}`: only actions GitHub publishes (actions/ or github/) or '
                      'this repository\'s own (AGENTS.md, *Code Review Rules*).')
    runs_required = any(entry.key == 'name' and len(entry.path) == 3 and entry.path[0] == 'jobs'
                        and entry.value in REQUIRED_CHECKS for entry in entries)
    if runs_required:
        for entry in entries:
            if entry.path[:1] not in (('on',), ('true',)):
                continue
            # Only a filter on an event (on.<event>.paths): an input named
            # `paths` filters nothing.
            if len(entry.path) == 3 and entry.key in ('paths', 'paths-ignore'):
                found(entry.line, 'path filter',
                      f'`{entry.key}:` on the workflow that runs the required checks "Unit '
                      'tests" and "UI tests": a pull request it skips can never merge '
                      '(AGENTS.md, *Gotchas*).')
    return findings


def check_instructions(read, exists):
    if not exists('CLAUDE.md'):
        return [Finding('CLAUDE.md', 0, 'CLAUDE.md',
                        'CLAUDE.md holds only `@AGENTS.md`, so Claude Code reads AGENTS.md.')]
    if read('CLAUDE.md').strip() != '@AGENTS.md':
        return [Finding('CLAUDE.md', 0, 'CLAUDE.md',
                        'CLAUDE.md holds only `@AGENTS.md`: agent instructions go in AGENTS.md, '
                        'never in an agent-specific file.')]
    return []


# ── Running the check ────────────────────────────────────────────────────────

def listed_files(root):
    """The files git tracks in the checkout, and new ones it does not
    ignore, that exist on disk."""
    try:
        listed = subprocess.run(['git', '-C', str(root), 'ls-files', '-z', '--cached', '--others',
                                 '--exclude-standard'], capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise SetupError(f'git could not list the files in {root}: {error}') from error
    paths = sorted({path for path in listed.stdout.decode('utf-8', 'surrogateescape').split('\0')
                    if path})
    return [path for path in paths if (Path(root) / path).is_file()]


def check(root=ROOT):
    """Every finding in the checkout at root, in order of place."""
    root = Path(root)

    def exists(path):
        return (root / path).is_file()

    def read(path):
        try:
            return (root / path).read_text(encoding='utf-8-sig')  # a byte-order mark is not code
        except (OSError, UnicodeDecodeError) as error:
            raise SetupError(f'could not read {path}: {error}') from error

    files = listed_files(root)
    for needed in ('project.yml', DECISIONS):
        if not exists(needed):
            raise SetupError(f'{needed} is missing, and this check reads it.')
    decisions = read(DECISIONS)
    entries = yaml_entries(read('project.yml'))
    if any(entry.path == ('include',) for entry in entries):
        raise SetupError('project.yml includes other specs, and this check reads only '
                         'project.yml: keep the project in that one file, or teach the check '
                         'to read them.')
    if any(entry.path == ('targetTemplates',) or (
            len(entry.path) == 3 and entry.path[0] == 'targets' and entry.key == 'templates')
            for entry in entries):
        raise SetupError('project.yml builds targets from templates, which this check does not '
                         'read: write each target out, or teach the check to read them.')
    kinds, sources = targets(entries)
    untyped = sorted(set(sources) - set(kinds))
    if untyped:
        raise SetupError(f'project.yml gives the target {untyped[0]} no `type:`, so this check '
                         'cannot tell whether it ships in the app or is a test.')
    if not any(kind == 'application' and sources.get(name) for name, kind in kinds.items()):
        raise SetupError('project.yml has no application target with sources, so this check '
                         'cannot tell which Swift files are the app.')
    # Everything that ships: the app, and any extension or framework in it.
    apps = [name for name, kind in kinds.items() if 'test' not in kind]
    app_folders = [source for name in apps for source in sources.get(name, [])]
    test_folders = [source for name, kind in kinds.items() if 'test' in kind
                    for source in sources.get(name, [])]
    allowed = allowed_files(decisions)

    swift = {}
    for path in files:
        if path.endswith('.swift') and (under(path, app_folders) or under(path, test_folders)):
            swift[path] = Swift(path, read(path))
    for name, kind in sorted(kinds.items()):
        if kind == 'application' and not any(path.endswith('.swift') and under(
                path, sources.get(name, [])) for path in files):
            raise SetupError(f'project.yml\'s sources for the app target {name} hold no Swift file '
                             'git lists, so this check would read none of the app: check how '
                             'they are written.')
    # Only the app's own declarations excuse a name in the app's code.
    declared = declared_names(source for path, source in swift.items()
                              if under(path, app_folders))

    findings = check_project(entries, files, read, decisions)
    for path, source in swift.items():
        if under(path, app_folders):
            findings += check_app_file(source, allowed, declared)
        else:
            findings += check_test_file(source)
    for path in files:
        # The workflows, and every action the repository holds, wherever
        # it is (a step may use any of them as `./path`).
        if (path.startswith(('.github/workflows/', '.github/actions/')) and path.endswith(
                ('.yml', '.yaml'))) or path.split('/')[-1] in ('action.yml', 'action.yaml'):
            findings += check_workflow(path, read(path))
    findings += check_instructions(read, exists)
    return sorted(set(findings), key=lambda finding: (finding.path, finding.line, finding.rule,
                                                      finding.message))


def annotation(finding):
    """A GitHub Actions error annotation for a finding."""
    message = str(finding.message).replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    place = f'file={finding.path}' + (f',line={finding.line}' if finding.line else '')
    title = finding.rule.replace(',', ' ').replace('::', ' ')
    return f'::error {place},title={title}::{message}'


def report(findings, environ=None):
    environ = os.environ if environ is None else environ
    count = len(findings)
    lines = [f'scripts/forbidden-code.py found {count} thing{"" if count == 1 else "s"} '
             'AGENTS.md forbids:']
    lines += [f'  {finding}' for finding in findings]
    if environ.get('GITHUB_ACTIONS') == 'true':
        lines += [annotation(finding) for finding in findings]
    return '\n'.join(lines)


def main(argv=None, environ=None):
    parser = argparse.ArgumentParser(description='Fail when the code holds something AGENTS.md '
                                                 'forbids.')
    parser.add_argument('root', nargs='?', help='the checkout to check (default: this one)')
    options = parser.parse_args(argv)
    try:
        findings = check(Path(options.root) if options.root else ROOT)
    except SetupError as error:
        print(f'scripts/forbidden-code.py could not run: {error}', file=sys.stderr)
        return 2
    if findings:
        print(report(findings, environ), file=sys.stderr)
        return 1
    print('scripts/forbidden-code.py: nothing AGENTS.md forbids was found.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
