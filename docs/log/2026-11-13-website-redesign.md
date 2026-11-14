# The website shows the real app, and its links go somewhere

*2026-11-13. Pull request #110 (`claude/project-thread-kbvd65`). A cloud
thread, at the owner's request, with a Remote Control session on the
owner's Mac for the pictures.*

## What changed and why

The owner found the home page's big "Our approach" button pointless (it
scrolled a short way down), disliked header links that only jumped
around a short page, wanted Contact to open the mail app with the
address filled in, and asked for the real app to be shown, with a calm
look for families rather than a start-up one
(docs/DECISIONS.md, "The website's pages, contact links and pictures of
the app").

- **Header.** Every page's header now has the same three links:
  Accessibility, Privacy and Contact. Contact opens the mail app,
  addressed to the published support address with the subject
  "Brickson"; so do Home's "Email a question" and contact button and the
  footer's address. "Our approach", "Why Brickson?" and "Support" are
  gone from the header; the founder note and the contact section are
  still on Home, and `#support` still works for the App Store's support
  URL and the issue template.
- **Home.** In order: what Brickson is, with an iPad and an iPhone
  picture at their real relative size; a silent recording with its steps
  written beside it; how Home works, in three parts with a picture each
  (one choice speaks, typing, Emergency and Get Attention); the same
  layout at the sizes for touch and for Eye Tracking; accessibility and
  privacy, each linking to its page; the founder note, word for word; six
  questions and answers; and the contact section.
- **Accessibility and privacy pages.** Only their header, section list
  and footer changed. The "On this page" list is now a `nav` named by its
  visible heading, not an `aside`; on the privacy page its link to the
  policy's Contact section reads "Contact details", so it is not
  confused with the header's Contact. The footer marks the page you are
  on. Neither page's `<main>` changed (checked byte for byte against
  `main`), so the privacy policy the app shows is the same, and neither
  page's date changed, since the words they date did not. The README now
  says the accessibility page's "Last updated" follows its `<main>`.
- **Pictures.** Six screenshots and one recording, all of the real app
  (below), shown bare with rounded corners and a thin edge, not in a
  drawn device. `site/assets/conversation.jpg`, the old speech-bubble
  illustration, is deleted; `social-preview.jpg` stays as the link
  preview image, and its description now names all its words.
- **Look.** The brand's ivory and navy, with a panel colour for
  alternate bands and a measured edge colour for screenshots, in light
  and dark. Reading lines stay near 40rem. Increase Contrast turns grey
  text and edges to full text colour; forced colours keep buttons and
  edges visible. No motion, no sticky header, no arrows on links, no
  JavaScript.
- **Words.** Plain and specific, checked against what the app does
  today (docs/HANDOFF.md, docs/ACCESSIBILITY.md): what is in place, what
  has not been checked on a real device, that Emergency and Get
  Attention never call anyone, that nobody has heard the tone on a
  device, and that an iPad with Family Setup unanswered starts at the
  largest sizes. No price and no "free"; "In development for iPhone and
  iPad." and "This address is not for emergencies." stay.

New checks in `scripts/test-site.py`:

- `NavigationTests`, five tests. On `main`'s pages four fail: a header
  link that jumps within a page (the old header's `../#approach`), a
  link drawn as a button that only scrolls (the old "Our approach"), a
  contact or support link that is not a `mailto:` link or a second
  address, and a header with no mail link. The fifth, the same header
  links to the same pages on every page, passes on `main` (its headers
  already matched); it fails when one page's header drops, renames or
  re-points a link. Link words include `aria-label` and a linked
  picture's `alt`.
- `MediaTests`, four tests. On `main` only the picture test fails (the
  old illustration's `alt` was empty). The other three pass there,
  because the old page had no recording, no new-window link and only
  small pictures; each fails on a copy of the new page broken on
  purpose. They check that every image has a non-empty `alt`, `width`
  and `height`; that a video or audio never autoplays or loops and has
  controls, and a video also `playsinline`, `muted`, a poster, `preload`
  of `none` or `metadata`, a `figure`, a name, and a written description
  of at least 30 words (`aria-describedby`); that no link opens a new
  window; and that pictures stay under 400 KiB, SVGs under 64 KiB and
  recordings under 4 MiB, with any other file type under
  `site/assets/` failing.
- The asset check now follows `source`, `srcset`, `poster`, `track`,
  `iframe`, `embed` and `object`, so a missing WebP or poster, or an
  outside video player, fails. The hero check adds up the largest file
  of every picture in the hero. The palette check measures the new
  panel, button and screenshot-edge pairs, and fails on `main`'s palette,
  which has no panel colour.

## How the pictures were made

On the owner's Mac, in a worktree of `main` at `8c90597`, built Debug
with Xcode 27.2 (27B52), in the iPad Pro 13-inch (M5) and iPhone 17
simulators on iOS 27.2 (24B8117), booted with no window. Status bar at
9:41 with full signal and battery. Launched with `--fresh-test-storage
--home-profile=touch --appearance=light`, Large text, English (US); the
Eye Tracking picture with `--home-profile=eye-tracking`. Taps went to
standard Buttons by their accessibility labels with AXe 2.0.4, and typed
messages went into the message field the same way. The full-size
captures stay on the Mac in the capture worktree's ignored `build/`
folder; the site's files were made there and committed on their own.

| File | Captured as | Shows |
|---|---|---|
| `ipad-home` (.jpg, .webp), 1032×1376 | `ipad-home-light.png`, iPad | Conversation, after "Give me a moment to answer." |
| `ipad-needs`, 1032×1376 | `ipad-home-light-2.png`, iPad | Needs, after "I'm thirsty." |
| `ipad-emergency`, 1032×1376 | `ipad-emergency-light.png`, iPad | Emergency chosen, nothing spoken yet, so the first-run note for the family is still in the message area |
| `ipad-eye`, 1032×1376 | `ipad-home-eye-light.png`, iPad | As `ipad-home`, launched with `--home-profile=eye-tracking` |
| `iphone-home`, 603×1311 | `iphone-home-light-2.png`, iPhone | Needs, after "I'm thirsty." |
| `iphone-typing`, 603×1311 | `iphone-typing-light-3.png`, iPhone | Needs, then Type, then "Please open the window." typed, nothing spoken, Apple's full keyboard showing |
| `ipad-demo.mp4`, 864×1152, 25.0 s | `ipad-demo-web.mp4`, iPad | Basics, Conversation, "Give me a moment to answer.", Needs, "I'm thirsty.", Type, the typed message, Speak, Phrases |
| `ipad-demo-poster.jpg`, 864×1152 | the recording at 0.5 s | Home as it opens, on Basics |

The stills were converted to sRGB with `sips` (the captures were
already sRGB, so nothing changed), halved with ImageMagick 7.1.2
(Lanczos), and written as progressive JPEG at quality 86 (4:4:4) and as
WebP with cwebp 1.6.0 at quality 90. The recording was cut to its first
25.0 seconds (the picture ends at 24.4 s), scaled to 864×1152 and
encoded with ffmpeg 9.0.2 and libx264 (High profile, CRF 26, 30 fps,
BT.709, no audio track, `+faststart`, no metadata): 280 KiB. Every file
holds no EXIF, XMP, comment or colour profile, and the Mac's account
name is in none of them. Every picture is under 120 KiB.

The simulators played no sound, and once a phrase had been chosen
"Speaking" stayed under the message: the system never reported that
speech had finished. That is the simulator behaviour docs/HANDOFF.md
already records under *Verification* (the 2026-10-25 trace, where the
system "stayed speaking/unpaused without a finish/cancel callback"), so
it is not a new finding. The recording's caption says so in plain
words, and the iPhone typing picture was taken with nothing spoken
first, so it shows no "Speaking" line.

The iPhone typing picture took three tries. The first typed "Could you
open the window a little?", which at Large text overflows the iPhone's
two-line message box, so only its end showed; the second chose "I'm
thirsty." first, so "Speaking" showed under the message; the third,
used here, chose Needs and then Type. For the same reason the iPhone
Home picture shows "I'm thirsty." rather than "Give me a moment to
answer.", which also fills more than the box's two lines there.

### The recipe

Everything below ran in zsh on the Mac, from the capture worktree. Put
the two simulators' ids in place of `<ipad-udid>` and `<iphone-udid>`.
It also made dark, landscape and Settings pictures and an iPhone
recording that the site does not use; they were taken to choose from.

```sh
# ===== Brickson website pictures and recording: how they were made =====
# Mac with Xcode 27.2, AXe 2.0.4, ImageMagick 7 (magick), cwebp, ffmpeg/ffprobe, zsh.
# Simulators: iPad Pro 13-inch (M5) and iPhone 17, plain iOS 27.2 runtime.
# Find the ids with: xcrun simctl list devices
# On this Mac the shell aliases cp, rm, grep and python3, so the lines say `command ...`.

# ---- 0. Worktree and build (once, from main at 8c90597) ----
cd ~/code/brickson && git fetch origin main
git worktree add --detach ~/code/brickson-site-shots origin/main
cd ~/code/brickson-site-shots && xcodegen generate
xcodebuild -project Brickson.xcodeproj -scheme Brickson -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build
mkdir -p build/site-shots

# ---- 1. Simulator set-up (after every boot; boot headless: never open Simulator or
#         Device Hub, because quitting Device Hub shuts the simulators down) ----
for u in <ipad-udid> <iphone-udid>; do
  xcrun simctl boot $u; xcrun simctl bootstatus $u -b
  xcrun simctl install $u build/DerivedData/Build/Products/Debug-iphonesimulator/Brickson.app
  xcrun simctl spawn $u defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false
  xcrun simctl spawn $u defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
  xcrun simctl status_bar $u override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName '' --batteryState charged --batteryLevel 100
  xcrun simctl ui $u appearance light
done

# ---- 2. Helpers (zsh scripts, verbatim) ----
# $H can be any folder; this one is under the worktree's git-ignored build/.
# axtype.py types by snapshot id + element ref: `axe type ... --label messageField` typed nothing.
H=~/code/brickson-site-shots/build/capture; O=~/code/brickson-site-shots/build/site-shots; mkdir -p $H

cat > $H/launch.sh <<'EOF'
#!/bin/zsh
# usage: launch.sh <udid> [extra args...]   (defaults: touch, light)
u=$1; shift
profile=touch; appearance=light; extra=()
for a in "$@"; do
  case $a in
    --home-profile=*) profile=${a#--home-profile=} ;;
    --appearance=*) appearance=${a#--appearance=} ;;
    *) extra+=$a ;;
  esac
done
xcrun simctl launch --terminate-running-process $u family.avery.brickson --fresh-test-storage --home-profile=$profile --appearance=$appearance $extra -UIPreferredContentSizeCategoryName UICTContentSizeCategoryL -AppleLanguages '(en)' -AppleLocale en_US
EOF

cat > $H/tap.sh <<'EOF'
#!/bin/zsh
# usage: tap.sh <udid> <label>  — taps the one Button with that exact label, prints the outcome
out=$(axe tap --agent --view navigation --udid $1 --label "$2" --element-type Button 2>&1)
print -r -- "$out" | /usr/bin/python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
except Exception as e:
  print("PARSE-ERROR"); sys.exit(1)
o=d.get("data",{}).get("action",{}).get("outcome")
print("tap", sys.argv[1], "->", o, "" if o=="enqueuedAndDrained" else d)
sys.exit(0 if o=="enqueuedAndDrained" else 1)' "$2"
EOF

cat > $H/shot.sh <<'EOF'
#!/bin/zsh
# usage: shot.sh <udid> <name>
xcrun simctl io $1 screenshot --type=png ~/code/brickson-site-shots/build/site-shots/$2 2>&1 | command grep -v '^Note:' | sed "s|$HOME|~|"
EOF

cat > $H/axtype.py <<'EOF'
import json, subprocess, sys
# usage: axtype.py <udid> <field label> <text>
udid, field, text = sys.argv[1:4]
cap = json.loads(subprocess.run(["axe","describe-ui","--agent","--view","navigation","--udid",udid],capture_output=True,text=True).stdout)["data"]["capture"]
ref = [r for r in cap["rows"] if r.split("|")[3] == field][0].split("|")
print("field row:", "|".join(ref))
args = ["axe","type",text,"--agent","--view","reading","--udid",udid,"--snapshot-id",cap["snapshotID"],"--ref",ref[0]]
if "typeText" not in ref[1]: args.append("--focus")
d = json.loads(subprocess.run(args,capture_output=True,text=True).stdout)
a = d.get("data",{}).get("action")
print("type ->", a.get("outcome") if a else json.dumps(d)[:500])
print([r for r in d.get("data",{}).get("capture",{}).get("rows",[]) if field in r or text[:8] in r])
EOF

cat > $H/demo.sh <<'EOF'
#!/bin/zsh
# usage: demo.sh <udid> <ipad|iphone> <REC 0|1> <outfile> <timings file>
zmodload zsh/datetime
U=$1; KIND=$2; REC=$3; OUT=$4; TL=$5
S=${0:A:h}
$S/launch.sh $U >/dev/null; sleep 4            # app open on Home before the clip starts
: > $TL
if [[ $REC == 1 ]]; then
  xcrun simctl io $U recordVideo --codec=h264 --force $OUT > $S/rec.log 2>&1 &
  RPID=$!
  for i in {1..100}; do command grep -q 'Recording started' $S/rec.log && break; sleep 0.1; done
fi
T0=$EPOCHREALTIME
mark() { printf '%6.2f  %s\n' $(( EPOCHREALTIME - T0 )) "$1" | tee -a $TL; }
tap() { mark "tap \"$1\" (sent)"; $S/tap.sh $U "$1" >> $S/tapdetail.log 2>&1 || { mark "CHECK tap $1"; }; }
typewords() { local words=(${(s: :)1}); local n=${#words}; local i=1
  mark "typing starts: \"$1\""
  for w in $words; do if (( i < n )); then axe type "$w " --udid $U >/dev/null 2>&1; else axe type "$w" --udid $U >/dev/null 2>&1; fi; i=$((i+1)); sleep 0.15; done
  mark "typing ends"; }
mark "clip starts on Home"
sleep 2
if [[ $KIND == ipad ]]; then
  tap "Conversation"; sleep 1.5
  tap "Give me a moment to answer."; sleep 2
  tap "Needs"; sleep 1.5
  tap "I'm thirsty."; sleep 2
  tap "Type"; sleep 1.5
  typewords "Could you open the window a little?"; sleep 1.2
  tap "Speak"; sleep 2
  tap "Phrases"; sleep 2
else
  tap "Needs"; sleep 1.5
  tap "I'm thirsty."; sleep 2
  tap "Type"; sleep 1.5
  typewords "Thank you."; sleep 1.2
  tap "Speak"; sleep 2
  tap "Phrases"; sleep 2
fi
mark "clip ends"
if [[ $REC == 1 ]]; then kill -INT $RPID; wait $RPID; cat $S/rec.log | sed "s|$HOME|~|"; fi
EOF

cat > $H/atoms.py <<'EOF'
import struct, sys
data = open(sys.argv[1], 'rb').read()
def walk(off, end, depth):
    while off + 8 <= end:
        size, typ = struct.unpack('>I4s', data[off:off+8]); typ = typ.decode('latin1'); hdr = 8
        if size == 1: size = struct.unpack('>Q', data[off+8:off+16])[0]; hdr = 16
        if size == 0: size = end - off
        body = off + hdr
        if typ in ('moov','trak','mdia','edts','minf','stbl'): walk(body, off+size, depth+1)
        elif typ in ('mvhd','mdhd'):
            v = data[body]
            if v == 0: ts, dur = struct.unpack('>II', data[body+12:body+20])
            else: ts, dur = struct.unpack('>IQ', data[body+20:body+32])
            print('  '*depth + f'{typ}: timescale={ts} duration={dur} -> {dur/ts:.3f}s')
        elif typ == 'tkhd':
            v = data[body]; dur = struct.unpack('>I', data[body+20:body+24])[0] if v == 0 else struct.unpack('>Q', data[body+28:body+36])[0]
            print('  '*depth + f'tkhd: duration={dur} (movie timescale)')
        elif typ == 'elst':
            v = data[body]; n = struct.unpack('>I', data[body+4:body+8])[0]; p = body+8
            for i in range(n):
                if v == 0: sd, mt = struct.unpack('>Ii', data[p:p+8]); p += 12
                else: sd, mt = struct.unpack('>Qq', data[p:p+16]); p += 20
                print('  '*depth + f'elst entry: segment_duration={sd} media_time={mt}')
        off += size
walk(0, len(data), 0)
EOF
chmod +x $H/launch.sh $H/tap.sh $H/shot.sh $H/demo.sh

# ---- 3. Launch lines ----
# Base (every picture and both recordings; this is what launch.sh runs):
#   xcrun simctl launch --terminate-running-process <udid> family.avery.brickson --fresh-test-storage \
#     --home-profile=touch --appearance=light -UIPreferredContentSizeCategoryName UICTContentSizeCategoryL \
#     -AppleLanguages '(en)' -AppleLocale en_US
# Differences: *-dark: --appearance=dark (plus `simctl ui <udid> appearance dark` before, light after);
#   ipad-home-eye-light: --home-profile=eye-tracking; ipad-settings / ipad-family-setup*: add --screen=settings.
#   Recordings: base (UIKit animations stay on).
# Each still was opened and checked by eye after it was taken.

# ---- 4. iPad stills (in this order) ----
U=<ipad-udid>
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U ipad-home-light.png
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Needs && sleep 2 && $H/tap.sh $U "I'm thirsty." && sleep 2.5 && $H/shot.sh $U ipad-home-light-2.png
xcrun simctl ui $U appearance dark; sleep 1
$H/launch.sh $U --appearance=dark >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U ipad-home-dark.png
xcrun simctl ui $U appearance light; sleep 1
$H/launch.sh $U --home-profile=eye-tracking >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U ipad-home-eye-light.png
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Type && sleep 2 && /usr/bin/python3 $H/axtype.py $U messageField 'Could you open the window a little?' && sleep 2 && $H/shot.sh $U ipad-typing-light.png
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Emergency && sleep 2.5 && $H/shot.sh $U ipad-emergency-light.png
$H/launch.sh $U --screen=settings >/dev/null; sleep 5
$H/shot.sh $U ipad-settings-light.png
$H/tap.sh $U 'Family Setup' && sleep 2.5 && $H/shot.sh $U ipad-family-setup-light.png
$H/tap.sh $U 'Set Up Step by Step' && sleep 2.5 && $H/shot.sh $U ipad-family-setup-question-light.png
# Landscape: NOT a shell line. `axe rotate` refuses ("works on the iPhone Duo and physical devices"),
# so the iPad was turned with the Claude Code iOS Simulator tool (control: action rotate, direction left).
sleep 3
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U ipad-home-landscape-light.png
# Then turned back with the same tool (action rotate, direction right). The PNG comes out upright, 2752x2064.

# ---- 5. iPhone stills ----
U=<iphone-udid>
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U iphone-home-light.png
xcrun simctl ui $U appearance dark; sleep 1
$H/launch.sh $U --appearance=dark >/dev/null; sleep 4
$H/tap.sh $U Conversation && sleep 2 && $H/tap.sh $U 'Give me a moment to answer.' && sleep 2.5 && $H/shot.sh $U iphone-home-dark.png
xcrun simctl ui $U appearance light; sleep 1
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Emergency && sleep 2.5 && $H/shot.sh $U iphone-emergency-light.png
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Needs && sleep 2 && $H/tap.sh $U "I'm thirsty." && sleep 2.5 && $H/shot.sh $U iphone-home-light-2.png
# The typing picture on the site: Needs, then Type, with no phrase spoken, so no "Speaking"
# line shows (the simulator's speech never reports finishing). Two earlier tries are superseded:
# iphone-typing-light.png (a long message, cut off) and -light-2.png ("I'm thirsty." tapped first).
$H/launch.sh $U >/dev/null; sleep 4
$H/tap.sh $U Needs && sleep 2 && $H/tap.sh $U Type && sleep 2 && /usr/bin/python3 $H/axtype.py $U messageField 'Please open the window.' && sleep 2.5 && $H/shot.sh $U iphone-typing-light-3.png

# ---- 6. Recordings (rehearse first with REC=0 and outfile /dev/null) ----
# demo.sh launches the app (sleep 4), starts `simctl io recordVideo --codec=h264 --force` in the
# background, waits for "Recording started" in rec.log, runs the taps with the waits in the script
# (each AXe call adds about 0.3-0.6 s), then stops the recorder with kill -INT and waits for it.
: > $H/tapdetail.log; $H/demo.sh <ipad-udid> ipad 1 $O/ipad-demo.mp4 $H/timings-ipad.txt
: > $H/tapdetail.log; $H/demo.sh <iphone-udid> iphone 1 $O/iphone-demo.mp4 $H/timings-iphone.txt

# ---- 7. -web copies (steady 30 fps; last frame held to the header's length) ----
# The recorder writes a frame only when the screen changes, so the movie header (mvhd) is longer
# than the picture (mdhd). ffprobe shows only the shorter one, so read both with atoms.py:
/usr/bin/python3 $H/atoms.py $O/ipad-demo.mp4     # mvhd 26.210 s, mdhd 24.465 s
/usr/bin/python3 $H/atoms.py $O/iphone-demo.mp4   # mvhd 18.435 s, mdhd 16.737 s
# Padding = mvhd minus mdhd: 1.75 s iPad, 1.70 s iPhone. (The last frame's start time, for
# comparison: ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 <file> | tail -1)
cd $O
ffmpeg -v error -y -i ipad-demo.mp4 -vf "fps=30,tpad=stop_mode=clone:stop_duration=1.75" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart -an ipad-demo-web.mp4
ffmpeg -v error -y -i iphone-demo.mp4 -vf "fps=30,tpad=stop_mode=clone:stop_duration=1.70" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart -an iphone-demo-web.mp4
cd ~/code/brickson-site-shots

# ---- 8. Website stills (site/assets/app): sRGB -> halve -> JPEG + WebP ----
# name <- capture: ipad-home <- ipad-home-light.png; ipad-needs <- ipad-home-light-2.png;
#   ipad-emergency <- ipad-emergency-light.png; ipad-eye <- ipad-home-eye-light.png;
#   iphone-home <- iphone-home-light-2.png; iphone-typing <- iphone-typing-light-3.png
mkdir -p build/site-assets/srgb build/site-assets/half
name=iphone-typing; src=iphone-typing-light-3.png    # repeat for each pair above
sips --matchTo '/System/Library/ColorSync/Profiles/sRGB Profile.icc' build/site-shots/$src --out build/site-assets/srgb/$name.png
magick build/site-assets/srgb/$name.png -alpha off -filter Lanczos -resize 50% -strip PNG24:build/site-assets/half/$name.png
magick build/site-assets/half/$name.png -strip -sampling-factor 4:4:4 -interlace JPEG -quality 86 site/assets/app/$name.jpg
cwebp -quiet -q 90 -m 6 -sharp_yuv -metadata none build/site-assets/half/$name.png -o site/assets/app/$name.webp
# iPad: 2064x2752 -> 1032x1376. iPhone: 1206x2622 -> 603x1311.

# ---- 9. Website recording and poster (iPad only; the iPhone recording is not on the site) ----
# The source is tagged P3 primaries + sRGB transfer but its pixels are sRGB, so retag, don't convert.
ffmpeg -v error -y -i build/site-shots/ipad-demo-web.mp4 -t 25.0 \
  -map 0:v:0 -an -sn -dn -map_metadata -1 -map_chapters -1 \
  -vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv,scale=864:1152:flags=lanczos+accurate_rnd+full_chroma_int,format=yuv420p" \
  -r 30 -fps_mode cfr \
  -c:v libx264 -profile:v high -preset slow -crf 26 -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
  -movflags +faststart -fflags +bitexact \
  site/assets/app/ipad-demo.mp4
mkdir -p build/site-assets/poster
ffmpeg -v error -y -ss 0.5 -i site/assets/app/ipad-demo.mp4 -frames:v 1 -update 1 \
  -vf "scale=in_color_matrix=bt709:in_range=tv:flags=accurate_rnd+full_chroma_int,format=rgb24" \
  build/site-assets/poster/poster-0.5.png
magick build/site-assets/poster/poster-0.5.png -strip -sampling-factor 4:4:4 -interlace JPEG -quality 86 \
  site/assets/app/ipad-demo-poster.jpg

# ---- 10. Checks, then clean-up ----
command python3 scripts/test-site.py
command python3 scripts/privacy-check.py --outgoing     # after committing, before pushing
for u in <ipad-udid> <iphone-udid>; do
  xcrun simctl status_bar $u clear; xcrun simctl ui $u appearance light
  xcrun simctl terminate $u family.avery.brickson; xcrun simctl shutdown $u
done

# Known capture artefacts: simulator audio never starts, so a "Speaking" line stays under the
# message once a phrase has been tapped (on a device it clears when speech ends); every iPhone PNG
# has a 3x3 black block at its top-left corner; the iPad status bar shows the real date.
```

## Research and skills used

- Anthropic's `frontend-design` skill and the design plugin's
  `accessibility-review`, `design-critique` and `ux-copy` skills, read
  from their public repositories and applied where they agree with
  AGENTS.md (they lost where they clashed: no fonts from outside, no
  motion). Once the design plugin was installed in this session,
  `accessibility-review` (headings, landmarks, names in the
  accessibility tree, keyboard order) and `ux-copy` (button and link
  labels) were run again on the finished pages and found nothing new.
- WCAG 2.2 and its Understanding documents (contrast, focus appearance,
  focus not obscured, target size, bypass blocks, consistent help, link
  purpose, label in name, text spacing, reflow, audio-only and
  video-only, pause stop hide).
- Apple's App Store marketing guidelines (device images only from
  Apple's artwork) and App Store Connect's help on accessibility labels
  and the support URL.
- GOV.UK's guidance on clear language, buttons and inclusive language,
  and Nielsen Norman Group's articles on in-page links, link wording,
  trustworthy design and writing for the web.
- MDN for `video`, `picture`, `prefers-contrast` and `forced-colors`.
- Mobbin, for how health and accessibility apps present their screens.
  No outside service was sent any of the repository or anything about
  the owner's family.

## Review

Before the pull request opened, an independent review in this session
read the change from five sides (accessibility, facts against the app,
the repository's rules, design, and the tests), and a second reader
checked each finding against the code and the pictures. 44 findings
held and 6 did not.

All 44 are fixed in this pull request, except two:

- The iPad pictures show iPadOS's small window-resize mark in their
  bottom-right corner. It is left for the next retake, which should
  set the simulator's iPad to full-screen apps first.
- The header's "Contact" keeps its name: it is the owner's word. The
  privacy page's second "Contact" link, in its section list, now reads
  "Contact details", so no two links share a name and differ in what
  they do.

The six that did not hold: that the iPhone's touch sizes need a rest
board exception (the page is about Family Setup's answer, where every
iPhone keeps touch sizes); that Home's privacy summary overstates the
policy (it paraphrases the policy's own summary); that the Phrases and
Categories answer needs every editing limit; that the simulator's
speech is a new gap (docs/HANDOFF.md records it); that three sentences
drift from the policy (none is untrue); and that the steps push the
recording too far down on a phone (it starts under one screen below the
heading, and the steps are its text alternative).

## Commits

- `c6ecf04` Add app screenshots and a recording for the website (on the
  Mac)
- `eef1bca` Retake the iPhone typing picture with a message that fits
  (on the Mac)
- `684effb` Retake the iPhone typing picture with nothing being spoken
  (on the Mac)
- The pages, styles, site tests and records, in one commit from the
  cloud thread.

## Verified

- In the cloud thread: `test-docs.py`, `test-hooks.py`,
  `test-privacy.py`, `test-runner.py`, `test-agent-bridge.py`,
  `test-site.py` and `test-select-xcode.py` all pass. The new site tests
  were run against `main`'s pages too (which fail and which pass is
  above), and against copies of the new pages broken on purpose.
- `privacy-check.py --outgoing --no-list`: no private list in the cloud
  thread, so it does not count as a pass; on the Mac,
  `privacy-check.py --outgoing` with the list passed for each of the
  three picture commits.
- Rendered with Playwright's Chromium, the only browser in the cloud
  thread, on all three pages at 320×700, 390×844, 640×450 (a 1280-wide
  window at 200% zoom), 768×1024, 1024×768, 1280×900 and 1600×1000, in
  light and dark: no sideways scrolling, nothing clipped, every target
  outside running text at least 44×44, and no clipping with WCAG's text
  spacing applied. Tab order on each page, a visible 3-pixel focus
  outline on every stop the page draws (inside the recording's own
  controls Chromium draws its own ring), and each skip link moving focus
  to `<main>`.
  Forced colours and Increase Contrast checked in screenshots of Home.
  The accessibility tree of each page read in full: one `h1`, no skipped
  heading level, one banner and one footer, every picture and the
  recording named.
- Every picture and the recording opened and checked by eye against its
  `alt` text and the written steps.

## Not verified

- The pages in Safari or Firefox, on a real iPhone, iPad or Mac, and
  with VoiceOver, Voice Control or Switch Control on a device. Only
  Chromium was available here.
- Playback of the recording in Safari and Firefox; its steps are written
  out for any browser that cannot play it. Python's preview server does
  not answer range requests, so Chromium stopped after reading the
  recording's start; the published site's server does answer them.
- How a real device looks: the pictures are from the simulator.

## Follow-ups

- Retake the pictures whenever Home changes how it looks (whoever
  changes it; the recipe is above), with the iPad set to full-screen
  apps so the resize mark is gone.
- The owner can remove the capture worktree on the Mac once this
  merges, which also deletes the full-size captures in its ignored
  `build/` folder (the recipe above remakes them):
  `git -C ~/code/brickson worktree remove ~/code/brickson-site-shots`.
  Success prints nothing and the folder is gone; if git refuses, ask a
  Mac thread to look rather than forcing it.
