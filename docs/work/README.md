# Work files: intent, spec and plan

One file per feature, written before it is built (docs/SDLC.md, *The
work file*). A feature that changes what a person sees or hears, or that
takes more than one pull request, gets one; a small fix does not.

The three parts are written in order, and each is committed when it is
written, so git history shows when the intent became a spec and the spec
a plan. The record of what happened goes in `docs/log/`, one file per
pull request, not here.

## Name

`<topic>.md`, named after the roadmap item, for example
`get-attention.md`. Rename nothing once a pull request links to it.

## Template

Copy this and fill it in, one part at a time. Keep the words plain: the
owner reads these to decide.

```markdown
# <Feature>

*Roadmap: <release and item number>. Owner: <thread or agent>.
Status: intent | spec | plan | building | done.*

## Intent

- **Problem:** what a person cannot do today, or does badly, on the input
  method they use.
- **Proposed outcome:** what better looks like, in their terms.
- **Who and what it affects:** people (by stage and input method),
  families, and the parts of the app.
- **Constraints:** the AGENTS.md invariants and decisions that bind it.
- **Open questions:** each one answered here or listed in
  docs/DECISIONS.md, *Proposed decisions*.

## Spec

- **States:** every state it adds or changes, and where each control sits
  in each (positions never move: invariant 8).
- **Input methods:** how each reaches it, and what a repeated activation
  meets (invariant 10).
- **Colours:** new pairs, for `PaletteTests` (invariant 6).
- **Privacy policy:** sentences it makes untrue, if any.
- **Screens:** links to the Figma frames, and whether the owner has
  accepted them.
- **Concerns:** each resolved, or a proposed decision.

## Plan

- **Files that change:** and which agent owns each.
- **Order of work:** one pull request per step where possible.
- **Risks:** and how each is checked.
- **Proof:** the tests that show it works, each with the change that would
  make it fail, and the device checks it adds.
```
