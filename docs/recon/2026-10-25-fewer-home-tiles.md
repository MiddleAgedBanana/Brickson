# Fewer phrase tiles where Home runs out of room

*2026-10-25. Measurement-based proposal only. No Home code changes or
R1 implementation work starts here.*

## Recommendation

Show fewer **whole rows in the phrase grid**, with the remaining phrases
on pages in stored order. Keep the message, Phrases/Type, all safety
controls, Stop's well, the four category cells and Settings in their
regions. Preserve profile floors, whole words and the default-size label
minimum; do not gain room by shrinking those or removing another row.

Follow the existing
[drawn direction](../work/typing-on-home.md#fewer-tiles-to-a-screen-r1-drawn-not-built):
**More, 1 of 2** occupies the last grid slot on every page, advances to the
next page and wraps to the first. Its slot never becomes a speaking tile.
Keep columns and phrase-ordinal slots fixed across categories; nothing
is ranked by usage or time.

## Measured fit and proposed page size

Basics and Needs each contain eight phrases and have identical outcomes
below. The keyboard is hidden. Table rows use light appearance, with
restricted zoomed-phone cases also checked in dark. Supplemental dark
checks cover zoomed iPad AX5 and partially open Duo, as recorded below.
These are current
**touch-geometry** calculations, not verified R1 gaze/head/switch capacities.
Counts describe visibility of the eight-phrase starter category, not the
maximum capacity of a grown library.

| Window / Display Zoom | Orientation | Text | Columns × visible occupied rows | Whole phrases visible | Scroll | Proposal |
|---|---|---|---|---|---|---|
| 1032×1376, standard | Portrait | Default / AX4 / AX5 | 4 × 2 | 8 | 0pt | Keep 8, one page |
| 1376×1032, standard | Landscape | Default / AX4 / AX5 | 4 × 2 | 8 | 0pt | Keep 8, one page |
| 774×1032, Larger Text | Portrait | Default / AX4 / AX5 | 4 × 2 | 8 | 0pt | Keep 8, one page |
| 1032×774, Larger Text | Landscape | Default / AX4 / AX5 | 4 × 2 | 8 | 0pt | Keep 8, one page |
| 402×874, standard | Portrait | Default | 3 × 3 | 8 | 0pt | Keep 8, one page |
| 402×874, standard | Portrait | AX4 | 3 × 2 | 6 | 4pt | 5 plus More, two pages |
| 402×874, standard | Portrait | AX5 | 3 × 2 | 6 | 52pt | 5 plus More, two pages |
| 320×693, Larger Text | Portrait | Default | 2 × 2 | 4 | 169pt | 3 plus More, three pages |
| 320×693, Larger Text | Portrait | AX4, light/dark | 2 × 0 | 0 | Not established | Unresolved: no whole row fits |
| 320×693, Larger Text | Portrait | AX5, light/dark | 2 × 0 | 0 | Not established | Unresolved: grid starts outside window |
| 466×678, Duo closed | Portrait | Default | 3 × 2 | 6 | 3pt | 5 plus More, two pages |
| 466×678, Duo closed | Portrait | AX4 | 3 × 1 | 3 | 201pt | 2 plus More, four pages |
| 466×678, Duo closed | Portrait | AX5 | 3 × 0 | 0 | 249pt | Unresolved: no whole row fits |
| 951×669, Duo open | Wide, native Hub pose | Default / AX4 | 4 × 2 | 8 | 0pt | Keep 8, one page |
| 951×669, Duo open | Wide, native Hub pose | AX5 | 4 × 1 | 4 | 10pt | 3 plus More, three pages |
| 669×951, Duo open | Tall, rotated in Hub | Default / AX4 / AX5 | 3 × 3 | 8 | 0pt | Keep 8, one page |

Source: [the 70-record measurement file](https://github.com/MiddleAgedBanana/Brickson/blob/cb4c965/docs/log/ui-test-evidence/2026-10-25-home-checks/home-measurements.json).
Measurements used app code `8316743`, before PR #56 changed Settings
placement. That change is incorporated into this docs branch; it does
not replace the dated measurements with a new Home or Settings run.
The standard phone leaves 246pt of grid
height at AX4 and 198pt at AX5. Both use a 78pt tile floor and 8pt gap:
two rows fit, so six slots become five phrases plus More. The zoomed
phone's default grid is 167pt tall: four slots become three plus More.
All 28 iPad records (24 light and four dark AX5) fit eight phrases with
zero measured scroll.
Duo's closed view has a measured 350pt-wide grid: three 111.33pt tiles
use the current compact 99pt floor (the 78pt floor needs 114pt width).
Default height 310pt is 3pt short of three rows at that floor: 313pt.
Heights 310/112/64pt at default/AX4/AX5 fit two/one/zero whole rows. At
AX5, fewer rows cannot make a whole 99pt tile fit, despite its established
249pt scroll range. Passing selected Home tests does not prove fit.
Open wide has an 835pt grid: 202.67pt tiles use the 72pt regular floor.
At AX5 its 142pt viewport is 10pt short of the 152pt needed for two rows,
so one row leaves three phrases plus More. The wide pose was preserved
from Device Hub; the old JSON `portrait` key is not a rotation request.
At the Hub's reported 130° partial pose, tall 669×951 showed all eight
phrases with zero scroll at default/AX5. Wide 951×669 in dark showed
eight/zero at default and four/10pt at AX5, matching open-wide geometry.
These static visibility checks do not verify fold or camera safety.

**Paging alone cannot fix the restricted zoomed phone.** AX4 leaves only
7pt at y=651; AX5 leaves zero height at y=706, outside the 693pt window.
At AX5, Feelings and Settings also end at y=696, clipping their frames by
3pt. Required safety controls remain visible and Type is disabled. Light
and dark static captures agree and fail the whole-tile checks. No swipe
was attempted in those final captures; earlier diagnostics did not establish
scroll range. These geometry problems remain unresolved in R0 too.

Zoomed iPad landscape also disables Type at AX4/AX5 under the existing
keyboard-space rule despite all phrases fitting. Fewer phrase rows do
not by themselves resolve typing clearance, and no control moves when
the keyboard appears.

## Capacity rule and remaining gates

For usable grid height V, tile floor H, gap g and fixed columns C, choose
the largest whole row count R satisfying:

`R × H + max(0, R − 1) × g ≤ V`

There are S = R × C slots. If eight phrases fit, keep one page without
More. Otherwise, if S ≥ 2, reserve More's slot: **capacity = S − 1** and
**pages = ceiling(8 / (S − 1))**. If no row fits or S < 2, record an
unresolved arrangement rather than reducing floors or safety controls.

Before a later implementation:

- Set the page configuration from the library's largest category, not
  the selected category. Settle short/empty categories without replacing
  More in place with a speaking phrase or reflowing the final page.
- Score page changes, wraparound, category changes and typing through
  the one ChainEngine under both pointer models, including empty cells.
- A fold can split usable space. Use reserved regions and an even column
  count whether the fold is active or inactive, retaining neighbours.
  Simple rectangular fit is not proof of Duo fold/camera clearance.
- Check Figma, labels, floors and the final row in the running app.
  Existing message/Stop-well and Clear/Put Back hazards remain open;
  open-wide AX5 also had a separate Settings nearest-control test failure
  on the pre-#56 source; that result has not been rescored on new main.
  The informal handheld Eye Tracking observation does not close them.

This proposal does not change R0's scrolling implementation. R1 paging
waits until the first R0 App Review build and still needs proper device
validation with its actual physical target floors.
