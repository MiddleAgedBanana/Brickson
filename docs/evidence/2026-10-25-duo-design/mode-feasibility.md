# Joint Phrases/Type occupancy feasibility

**Conclusion:** narrowing both occupied mode rectangles is geometrically
plausible for the recorded AX5 wide case and retains centred Back over
Phrases. There is **no validated all-font/pose proposal** from this study.
Existing one-line Back minima131/142pt do not remove the whole native
Back-button hazard; a substantially narrower two-line Back needs native
SF/SwiftUI fitting proof, which was not performed or assumed.

No repository, Figma, API or simulator mutations were made. The numerical receipt is retained beside this report; complete host
build products remain private temporary evidence.

## Existing constraints

- `DECISIONS.md:2817–2823`: Phrases/Type at their physical/word floors;
  where Back needs two category-font lines, their height is at least56pt.
- `DECISIONS.md:2824–2841`: Back remains centred inside Phrases, as tall,
  at most one regular column wide; every Back point must close onto
  Phrases alone. One or two category-font lines are permitted.
- `HomeLayout.MinimumWidths`: Phrases86/94, Type58/63 and one-line
  Back131/142pt, regular/Bold. Only touch exists, with44pt target floor.
- `ModeButton` actually uses6pt horizontal insets on both sides, while
  the existing new-control font-floor test subtracts4pt per side. Reusing
  those test bounds conservatively with the rendered inset needs an
  extra4pt total:90/98pt for Phrases. This is a conservative translation
  of the recorded bound, not a fresh native measurement of the minimum.
- Back uses4pt horizontal insets and6pt vertical insets. Its widest
  default-size word and two-line fit at the new width remain unmeasured.
  No94pt Back floor was adopted.
- Status stays below message; allocation cells, C/B, all heights and
  state-invariant mode frames remain unchanged in each hypothesis.

Current actual Again is `(496,224,122,79)`; it is not at x396.

## Bounded geometry and chain evidence

The host compiles unchanged `ChainEngine` and `SettingsRowPlace`, with
only a CoreGraphics import added for host compilation. A minimal
HomeLayout adapter reads source frames without changing the allocator.
The20available exported default/AX5/intermediate/Bold geometries were
checked with conservative one-line widths131/142, keeping Back centred
and capped at its existing width. Across45 Back points under both rules,
none ceased to be nearest Phrases. All heights still meet44pt. This is
not a rendered-label or complete Home/Settings chain proof.

For the actual native wide AX5 Back `(884,144,38,38)`, the original mode
width355 retains the recorded Family Back→Back to Talking→Get Attention
hazard. Joint131/142pt hypotheses remove that exact centre-start chain
without the earlier Back-only direct-Again hazard. But Back's top-edge
starts still reach the same alarm chain, including `(884.5,144.5)`,
`(903,144.5)` and `(921.5,144.5)`. The unchanged wide Settings solver
keeps its model row at y337; its policy was not modified.

Hypotheses at the existing Phrases word bounds86/94pt show no hazard in
the bounded root/Family map, including45 direct Back-return points. These
numbers are **not validated Back word floors**. The Family guide beyond
its first navigation is absent, and no full-chain safety claim follows.

Bisection of the existing nearest routines over45 points across native
Back gives these necessary sampled width bounds for leading mode
occupancy and Back centred within it:

| Row input | Unique Family Setup by unchanged ChainEngine | Existing8pt row-vs-Back margin |
|---|---:|---:|
| Actual native root row | below114.0473pt | below98.5507pt |
| Existing illustrative row model | below109.5575pt | below94.0674pt |

These are sampled geometric limits for this one recorded Back rectangle,
not hardcoded design constants or native font proofs. The small interval
between a conservative98pt Bold Phrases bound and the actual-row98.55pt
limit is not evidence that a robust layout exists; it already disagrees
with the illustrative model's94.07pt limit. Actual Bold row/navigation
frames and native two-line Back measurements are needed before choosing
a width or claiming an all-font solution.

Shrinking mode occupancy everywhere also changes outputs of the unchanged
SettingsRowPlace on tall/pane inputs. The JSON records those modeled
changes. A selective rule tied to available-space constraints, final
row recomputation, independent full Home/Settings chains and native
SF-label validation would need its own Spec/drawings review before any
patch. No such rule is selected here.

[mode-feasibility-results.json](mode-feasibility-results.json) retains the20 geometry receipts, ten bounded current-window
chain cases, counterexample starts and sampled width constraints.
