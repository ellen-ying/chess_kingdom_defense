## Context and reference material

I'm building a mobile tower-defense game in Godot 4 (GDScript) — chess-piece-themed defenders protect a King at the center of a grid board from enemy chess pieces attacking radially from all directions. The project's architecture is documented in `tasks/ARCHITECTURE_NOTES.md` — **read that file first** for the current scene structure, node names, board/grid implementation, HUD, and tray/shop code, rather than asking me to describe it. This brief assumes you have that context; except for the the size of the board (13 * 9, which is what I actually for the modified version), where anything below conflicts with what's actually in the codebase, trust the codebase and flag the discrepancy to me.

## The problem with the current layout

The current screen has visible unused space around the edges — the board and UI sit like a contained object on the screen rather than the screen itself being fully used. I want a genuinely full-bleed landscape layout: every pixel of the screen belongs to some part of the UI (board, HUD, or tray), with no letterboxing, no background bezel, no dead margin.

## Design priority order (important — follow this order, don't design the pieces independently)

1. **Size the board first.** The grid dimensions are fixed at **13 columns × 9 rows** — do not change this to fit the screen. What adapts per device is the **tile size** (pixels per tile), not the tile count. Every individual tile must remain a perfect square (uniform width and height), never stretched into a rectangle.
2. **Fit the HUD and tray to whatever space is left** once the 13×9 board (at its adaptive tile size) is placed on screen — this is the reverse of "fixed UI, board fills the rest": here the board's footprint is derived first from the fixed grid × adaptive tile size, and the HUD/tray occupy the remaining screen area around it.
3. Every pixel of the screen still belongs to some part of the UI (board, HUD, or tray) — no letterboxing, no background bezel, no dead margin, per the full-bleed goal above.

## Sizing algorithm

The grid is fixed at 13×9. Please propose and implement an algorithm for choosing an adaptive `tile_size` (in pixels) that works across different device screen sizes/aspect ratios, then fits the HUD and tray into the remaining space around the resulting board footprint. At minimum, your proposal should address:

- How `tile_size` is derived from the available screen dimensions (e.g. constrained by whichever of width/13 or height/9 is smaller, so the full 13×9 grid always fits on screen without cropping — but propose your own approach and explain the reasoning, including how you handle very wide vs. very tall/narrow aspect ratios).
- Whether HUD height and tray width should be fixed absolute values, or derived as a proportion of screen size / remaining space — propose whichever you think fits best with the existing UI scaling patterns in `tasks/ARCHITECTURE_NOTES.md`, and explain your reasoning.
- How leftover space (screen area not exactly consumed by `13 * tile_size` and `9 * tile_size`) is distributed — e.g. absorbed into HUD/tray sizing, or split as symmetric margins — so the full-bleed goal holds without stretching tiles.
- Whether this recalculates on window/orientation resize, matching whatever responsive/viewport-aware patterns already exist in the project (check `tasks/ARCHITECTURE_NOTES.md`).

Flag any tradeoffs in your proposed approach (e.g. very extreme aspect ratios where the board might end up quite small) rather than silently picking an approach that degrades badly at the edges.

## Piece placement restriction (read carefully — this is not just visual)

Enemy spawning and movement use the full 13×9 grid — this is fine and expected, no restriction needed there.

**Player piece placement, however, is restricted to a centered square area of the grid** (a 9×9 region centered within the 13×9 board, using the existing central-placement logic/area already defined in the codebase per `tasks/ARCHITECTURE_NOTES.md` if one exists — otherwise center it based on the King's position). The 4 columns outside this central area (2 on each side, given 13 - 9 = 4) are valid tiles for enemies to traverse but are NOT valid placement targets for player pieces — reject placement attempts there the same way an already-occupied tile would be rejected (reuse existing invalid-tile handling/feedback, e.g. the red-highlight-on-drag behavior already implemented, rather than building new UI for this).

## HUD requirements

Single bar, full width, fixed height, top of screen. Contains, left to right:
- A **menu button** (hamburger icon) on the far left — opens a pause overlay with options including settings and "return to Home Office." Opening this should pause active gameplay (enemy movement, spawning, timers) — this is a distinct, player-initiated pause and is NOT in conflict with the earlier decision that waves run continuously with no automatic/system-driven pauses; that decision was about not gating shopping or spawning behind forced downtime, not about disabling player-requested pause access.
- King lives (center-left or center, match existing display format)
- Wave number (center)
- Material currency count (right), consistent with the existing currency display already in the codebase

## Tray requirements

Vertical column, right side of screen, full remaining height (below the HUD). Same content/behavior as the existing tray (owned/locked piece icons, drag-and-drop plus tap-to-place, as already implemented) — this brief only changes its position and sizing, not its interaction logic, which should be reused as-is from the current implementation.

## What I want from you

1. Confirm you've read `tasks/ARCHITECTURE_NOTES.md` and summarize (briefly) the relevant existing structures you're building on (board/grid system, HUD scene, tray scene) so I can confirm you have the right context before you proceed.
2. Propose your adaptive `tile_size` algorithm and HUD/tray sizing approach, with brief reasoning, per the Sizing algorithm section above.
3. Implement the adaptive tile-size logic for the fixed 13×9 grid, and fit the HUD/tray to the remaining space.
4. Implement the placement restriction (player pieces limited to the centered 9×9 area; enemies unaffected).
5. Move the HUD menu button and reposition the tray per this brief, reusing existing tray logic.
6. Flag anything in this brief that conflicts with what you find in the actual codebase, and ask me before proceeding if the conflict is significant enough that guessing would risk breaking existing functionality.
