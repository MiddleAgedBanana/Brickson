# Design screens: Figma, Claude Design and docs/DESIGN.md — 2026-10-21

**Thread:** Figma and Claude Design screens. **Branch:**
`claude/project-thread-ho952i`.

## What changed

- New `docs/DESIGN.md`: colour tokens with measured contrast, the Dynamic
  Type ladder the layout follows, the Home slot plan with stable slot
  identifiers, slot sizes per window, the family screens, the Liquid
  Glass review, where the drawings live and what came from where.
- `docs/DECISIONS.md`: two new sections, "Home's slot plan" and "Solid
  fills on Home, system glass elsewhere", both marked as defaults adopted
  2026-10-21 that the owner left to the project.
- Outside the repository: the Brickson Figma file (three pages:
  Foundations, Home, Settings and Library) and a private Claude Design
  prototype of the same screens. Links are in docs/DESIGN.md, *Where the
  drawings are*; the prototype is private until the owner shares it.

## Why

The project's design gate (the roadmap thread's SDLC.md) asks for screens
drawn from Apple's kit and linked in the pull request before Home is
rebuilt. The Phone layout, Typing and Settings threads needed one slot
plan and one set of tokens to build against; this records the plan they
agreed on and the measured numbers.

## Verified

Nothing ran on a device or simulator: this change is documentation, and
the thread cannot build Swift. The contrast ratios were computed from the
hex values with a WCAG 2 script and must be pinned by `PaletteTests` when
the tokens enter the code. The slot sizes come from one layout source
(Python and a JavaScript port, compared) that also drew every frame in
Figma and the prototype; the app's layout engine must reproduce them and
its tests pin them. Keyboard tops are the kit's keyboards placed in the
frame, not device measurements.

## Not done, and who owns it

- Apple's kit renders in Inter in this account (SF Pro listed, not
  rendering) and SF Symbols are not drawn; label fits are estimates.
- No Apple accessibility kit was found in the owner's Figma account.
- `ROADMAP.md` and `SDLC.md` are in the roadmap thread's open pull
  request and not on `main` yet, so the links from them to
  docs/DESIGN.md are theirs to add when both have merged.
- Whether the iPhone 17 grid keeps its frames or scrolls at AX4 and AX5
  is settled by the layout engine's measurements (Phone layout thread).
- The app icon remains a placeholder (App Store thread).
