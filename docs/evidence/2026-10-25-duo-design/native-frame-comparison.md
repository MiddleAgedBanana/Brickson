# Native Duo frame comparison — 2026-10-25

Read-only comparison of six supplied native capture sets with the exported enclosed allocator geometry and raw API reservation rectangles. The 144 captures cover 24 configurations: default/AX5 × requested light/dark in open wide, open tall, both reverse rotations, book wide reverse, and closed. Every capture reports one coherent ancestor-window snapshot. Camera orientation comes from the operator's pose mapping, not from window dimensions.

## Checked

| Check | Result |
| --- | --- |
| Exported occupied Home button frames | PASS: 1,220 comparisons; maximum origin/size/edge delta 0.167pt |
| Exported full phrase-tile frames | PASS: 800 comparisons; maximum delta 0.25pt |
| Shared Home frames before/after transitions | PASS: 1,884 comparisons exactly equal; baseline self-comparisons excluded |
| Requested light/dark geometry | PASS: 1,236 shared frames exactly equal |
| Static Home targets within coherent window and at least 44×44pt | PASS in all 120 Home state captures; no required control missing |
| Strict intersection with raw fold/camera/status reservations | PASS for static Home controls and geometrically cropped tiles; zero overlap records |
| Default typing keyboard coverage | PASS in 12 captures: Emergency, Yes, No, Speak, Get Attention, Phrases, Clear and Put Back all wholly above the keyboard |
| Settings Back contained in final native Phrases | PASS in all 24 Settings captures; zero raw reservation overlaps |
| Open wide reverse versus book wide reverse | PASS: 412 shared button/tile frames exactly equal at externally measured 180° and 90.07416534423828° |

Frame agreement allows at most 0.5pt, checking origins, sizes and far edges. Reservation checks use strict positive-area intersection with raw API rectangles and **no tolerance**. Full AX tiles are separately intersected with fixed browsing D and the coherent window; typing also excludes the area at or below keyboardTop. These are geometric crops, not visual or physical Snap proof.

The five inner pose sets have individual pure expected frames. Closed has no individual export: the host artifact reports 400 legacy compatibility comparisons with zero mismatches, but provides no per-case frames. Closed is therefore checked here through native state/appearance invariance, raw reservations and keyboard geometry; it is not counted as a pure expected-frame comparison.

## Browsing capacity only

Light/dark geometry agrees. “Trailing extent” is the bottom of full AX tile content beyond fixed D; it does **not** establish maximum scroll distance.

| Pose | Coherent window | Default whole tiles / trailing extent | AX5 whole tiles / trailing extent |
| --- | --- | --- | --- |
| Open wide, upper camera | 951×669 | 8 / 0pt | 4 / 66pt |
| Open tall, right camera | 669×951 | 8 / 0pt | 4 / 14pt |
| Open wide reverse | 951×669 | 8 / 0pt | 4 / 82pt |
| Book wide reverse | 951×669 | 8 / 0pt | 4 / 82pt |
| Open tall reverse | 669×951 | 8 / 0pt | 4 / 14pt |
| Closed | 466×678 | 6 / 3pt | 0 / 249pt |

Typing AX containers expand: wide upper 314→356pt, wide reverse/book 298→356pt, tall 353→395pt, closed 310→352pt. Shared occupied controls and full tile frames remain unchanged. The probe's typing `wholePhraseCount` of eight describes AX-container containment, including keyboard-covered tiles; it is not visible capacity. Clear and Put Back are present and geometrically uncovered in the captured empty-draft state; this does not establish physical activation behavior.

## Limits and model discrepancies

There are 32 full AX tile/camera overlap records in AX5 wide reverse/book captures: two second-row tiles extend below D into the camera rectangle. Their geometrically cropped portions stop at D's bottom and do not intersect that rectangle. Do not claim full AX tile camera clearance, rendered clipping safety, or physical Snap behavior from the crop result.

All 20 exported Family Setup row models differ from native geometry beyond 0.5pt; the models explicitly assume a 64pt navigation bar and are not native measurements. Examples: wide default native y201 versus model y203; tall AX5 native (215.667,462,437.333,79.667) versus model (211,467,442,79). Ten AX5 Settings row/fold intersection records remain. No Settings placement policy was assessed as newly implemented or fixed by this Home comparison. The native Back subset result is independent of those illustrative row models.

Active-display rendered appearance was not reviewed from these JSON sets; XCUIScreen can capture the black inactive outer display. Physical dwell, scanning, Snap, actual audio, rendered clipping, maximum scrolling, strong chain safety and the post-review-fix full unit gate are not verified by this artifact. No repository changes, native tests or simulator operations were performed for this audit.

The companion JSON retains source artifact hashes, per-state comparison receipts, strict intersections, keyboard rectangles and these limitations. Source labels contain no local user path or simulator UUID.
