# Earlier Duo gap summary

Affected technical section of `docs/HANDOFF.md` at `87ddb14`, before
item 6's reserved-region implementation. Other sections are excluded.

- iPhone Duo: the owner's Mac checked app code `8316743`, before PR #56,
  closed (466×678),
  open in wide (951×669) and tall (669×951) orientations, and partially
  open at 130°, on 2026-10-25. Closed AX5 cannot show a complete phrase
  tile; wide AX5 shows four complete tiles and scrolls 10pt; tall fits
  all eight at default, AX4 and AX5. The 19 existing Home tests had one
  closed audit failure, and nine open failures plus two landscape skips;
  the pre-PR #56 open failures include portrait/window-API assumptions
  and a distinct AX5 nearest-control finding, not yet rescored after it. All five default typing tests passed open.
  Device Hub rotation worked; the tested XCTest rotation request did not.
  XCTest's inner captures were black inactive-outer images, so active
  RocketSim images and coherent accessibility snapshots preserve the
  evidence. The wide rendered fold crosses No, Conversation and phrase
  tiles. The later item 6 design record measures the fold/camera queries
  and native Split View panes; fold/camera clearance, second-window
  behaviour and physical input remain unverified. CI still has no Duo
  family; screenshots are required from
  April 2027 (docs/DECISIONS.md, "iPhone Duo";
  [Mac record](log/2026-10-25-mac-keyboard-checks.md)).
  *(R0 item 13: Wave 3 item 6; PR #56 has cleared the owner's merge gate)*
