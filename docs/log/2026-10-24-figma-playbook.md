# What Figma can do for Brickson's design work, measured

*2026-10-24. Pull request from `claude/project-thread-yjzkvg`. The
"Explore Figma modes for design threads" thread, a cloud session that
cannot build or run anything.*

## What changed and why

The owner moved the team's Figma account to the Professional plan with a
Full seat on 2026-10-23 and asked agents to explore every Figma mode and
find what helps Brickson. This thread read Figma's current documentation
and tried the Figma connector against the design file, so the next design
thread starts with a method instead of guessing.

`docs/DESIGN.md`, *Where the drawings are*, said the Starter plan's limits
applied (three pages, one variable mode, a small monthly read budget). That
is no longer true, and its stand-in note gave no reason SF Pro "does not
render". It now says what the plan allows, why the labels stay in Inter,
and how agents work in the file, pointing here for the detail. Nothing in
the app changes.

### What each mode is good for

Checked against Figma's help centre, developer docs and release notes on
2026-10-24 (sources below). "Connector" means Figma's remote MCP server,
the only way agents reach Figma.

| Mode | Connector | For Brickson |
|---|---|---|
| Design | Reads and writes | **High.** Every screen is drawn here from Apple's iOS and iPadOS 27 kit. |
| Dev Mode | Not needed; the connector reads the same data | For people reviewing a design. Its SwiftUI snippets are absolute styling, never the layout. |
| FigJam | `generate_diagram` (Mermaid flowchart, state, sequence, gantt, ER), `get_figjam`, `use_figma` | **High as an explainer**: states and activation chains as diagrams, review boards agents can read. A diagram is never proof; `ChainEngine` and the UI tests are. |
| Specs | `use_figma` with Figma's `figma-spec` skill | A review copy beside the frames at most. `docs/work/` stays the spec. |
| Slides | `use_figma`, screenshots | Rarely needed: an occasional review deck. |
| Make | Can read and import code; cannot be prompted | No: it builds React web apps, not SwiftUI. |
| Sites (beta) | None | No: the hand-written GitHub Pages site stays in the repository. |
| Buzz (beta) | None | Only by hand, for App Store screenshot sets. |
| Weave | Tools exist, but it is a separate paid product, not linked | No: AI imagery does not fit an honest accessibility app. |
| Motion, Draw, shaders, code layers | Partly | No use for the app: web code or decoration. Motion cannot make App Store previews (Guideline 2.3.4). |
| Generative plugins | Yes | Later, perhaps: a private plugin that flags low contrast or small targets in drawings, as an early warning only. |
| Code Connect | Yes, empty today | Not now. Its SwiftUI parser would add a package (invariant 9). |

### The method, from a ROADMAP item to SwiftUI

1. The item's work file in `docs/work/` comes first (`docs/SDLC.md`,
   *2. Design*): every state, where each control sits, each input path.
2. Read Figma's own skills through the connector (`get_figma_skill`):
   `figma-use` before any write, `figma-generate-design` for screens,
   `figma-swiftui` and `figma-design-to-code` before reading a frame for
   code. Where one disagrees with `AGENTS.md`, `AGENTS.md` wins.
3. Search Apple's kit only (`search_design_system` with
   `includeLibraryKeys`), because Material 3 and another non-Apple kit are
   attached to the file.
4. Draw every state, light and dark, the largest text size and each
   window, with an overlay showing positions never move. Labels in Inter,
   each label layer named with its SwiftUI text style; Accessibility
   annotations carry each control's label.
5. Link the frames from the work file's spec and the pull request before
   the first code commit.
6. Build from the layout engine with standard `Button`s and `Palette`.
   From `get_design_context` (asked for Swift and SwiftUI) take names,
   words, SF Symbol names and colour roles, never positions or sizes.
7. When the app and the frames differ, redraw the frames from the app.

## Commits

- Correct DESIGN.md's Figma account notes and record what each Figma mode
  is good for.

## Verified

Run through the Figma connector on 2026-10-24, from this cloud session:

- The account is Professional with a Full seat; Specs are turned on for it.
- In a scratch file: five pages were made (no three-page cap); a local
  variable collection took 10 modes and refused an eleventh ("Limited to
  10 modes only").
- Text written in SF Pro through `use_figma` reported a missing font,
  measured zero wide and did not appear in screenshots, although SF Pro is
  in the font list. SF Symbol glyphs from Figma's helper vanished the same
  way, yet `get_design_context` still returned their names as
  `Image(systemName:)`. Inter rendered. A button imported from Apple's kit
  drew its label.
- An Apple kit component imported by key; the kit's colour variables bound
  and switched to Dark; Figma's glass effect, Accessibility annotations, an
  embedded Spec and a Slides slide could all be written.
- `get_design_context` on Home's iPhone 17 frame returned web code with
  absolute positions, hex colours and Inter, with the kit's status bar and
  home indicator marked as Apple components.
- The design file's local colour collection is empty, and two non-Apple
  kits are attached to it.
- Figma's rate-limit page (200 read calls a day, 10 a minute, writing
  tools exempt) and its AI settings page were read on the day.

GitHub CI is this pull request's build check; nothing in the app changed.

## Not verified

- How the frames look when the owner opens the file in the Figma app on a
  Mac with SF Pro installed.
- Whether `use_figma` counts toward the read limit, and whether
  `get_design_context` returns annotations: Figma's docs do not say.
- Make, Sites, Buzz and Figma's in-app agent were not driven: the connector
  cannot reach Sites, Buzz or the agent, or prompt Make.

## Follow-ups

- The first design thread that touches colour fills the design file's
  empty colour collection with `Palette`'s five fills, each with its Swift
  name as the iOS code syntax (the next design thread).
- The owner decides whether to turn off Figma's AI content training for
  the team, which Figma turns on by default for Professional teams, and
  deletes the two scratch files this exploration left (the connector has
  no delete tool).

## Sources

- Figma MCP server: https://developers.figma.com/docs/figma-mcp-server/ ,
  its tools page https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/
  and rate limits https://developers.figma.com/docs/figma-mcp-server/rate-limits-access/
- Plans: https://help.figma.com/hc/en-us/articles/360040328273-Compare-Figma-plans-and-features
- Specs and code layers (Config India 2026):
  https://help.figma.com/hc/en-us/articles/43663368947863-What-s-new-from-Config-India-2026
- AI settings and content training:
  https://help.figma.com/hc/en-us/articles/17725942479127
- App Store screenshots and previews:
  https://developer.apple.com/app-store/review/guidelines/
