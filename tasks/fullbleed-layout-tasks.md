# Chess Kingdom Defense — Full-Bleed Gameplay Layout: AI Agent Implementation Plan

_Source brief: `tasks/fullbleed-layout-brief.md`. Current architecture: `tasks/ARCHITECTURE_NOTES.md` (read as instructed)._
_Written 2026-09-27 against commit `f54846e` ("Finished the design of the 5 levels"). All findings below were verified against the live codebase; discrepancies with the brief are flagged per the brief's own instruction ("trust the codebase and flag the discrepancy")._

---

## 0. Context confirmation (brief item 1 — existing structures this builds on)

Verified by reading the current source:

- **Board/grid** — `scripts/board.gd`: **17 columns × 9 rows** (`const COLUMNS := 17`, `const ROWS := 9`), `const TILE_SIZE := 64`. The board origin is **hard-coded to a 1152×648 screen**: `board_origin = ((1152.0 - COLUMNS*TILE_SIZE)/2, (648.0 - ROWS*TILE_SIZE)/2)`. Cell↔world conversion (`cell_to_world`, `world_to_cell`), `is_valid_cell`, `get_center_cell()` (= (8, 4), where the King starts), and the precomputed `edge_cells` list are all **cell-based** and independent of tile size — only `board_origin`, `TILE_SIZE`, and `_draw` care about pixels.
- **Viewport/stretch** — `project.godot` sets only `window/stretch/mode="canvas_items"`; there is **no base-size entry, no stretch aspect setting (defaults to `keep`), and no orientation setting**. Base size defaults to 1152×648. `aspect=keep` + a hard-coded board origin is exactly why the current screen letterboxes / has dead margins.
- **HUD** — not a "bar" at all: absolutely positioned `Label` nodes under `UILayer` in `scenes/main.tscn`. `StatusLabel` (top-left) shows a **combined** string `"KING  %d / %d     WAVE  %d"` written by `main.gd::update_hud()`; `CurrencyLabel` shows `"MATERIALS: %d"` (updated by `main.gd::_on_currency_changed`); `GameOverLabel` and `WaveBanner` (wave-announce tween driven by `WaveManager::show_wave_banner`) sit near screen center; `FloatingRewards` is a full-rect pass-through Control. `UILayer` itself is anchored top-left with a 40×40 size — a free-floating container, not a full-screen layer.
- **Tray/shop** — `scenes/shop_ui.tscn`: a `PanelContainer` **anchored bottom-center** (`anchor_top=1`, `offset_top=-96`) containing an **`HBoxContainer`** of `ShopSlot` instances (120×82 minimum each). `scripts/shop_ui.gd` builds slots from `CATALOG` and starts placement via `begin_tray_pointer → PlacementController.begin_piece_selection`; `scripts/shop_slot.gd` handles press/drag with affordability display. The interaction logic is fully decoupled from geometry, so repositioning the tray is a layout-only change, as the brief assumes.
- **Placement** — `scripts/placement_controller.gd::is_valid_placement_cell(cell)` is the single legality gate (valid cell, not the King cell, not occupied) and is **also used by `_draw`** to color the hover tile green/red — so adding a restriction there automatically reuses the existing red-highlight feedback, exactly as the brief wants. `scripts/piece_manager.gd` separately gates **drag-moving existing pieces** in `_process` (occupied + King-cell checks only) — a second path the restriction must also cover.
- **No pause anywhere** — the only `process_mode` reference in the project is the placement ghost. No menu button, no settings, no pause overlay exist; all must be built (Phase 7).
- **No resize handling anywhere** — nothing listens to `size_changed`; only `board.gd` hard-codes the screen size.
- **Recent additions that interact with this work** — `main.gd::end_run_with_result(result)` exists (added for the headless `AutoplayBot`, doc-commented as AutoplayBot-only) and cleanly ends a run with a custom outcome — reusable for the pause menu's "return to Home Office". `AutoplayBot` itself is cell-based and filters candidate cells via `PlacementController.is_valid_placement_cell`, so it inherits the placement restriction automatically and is unaffected by tile-size changes (verified: nothing outside `board.gd`/`placement_controller.gd` references `TILE_SIZE`).

---

## 1. Discrepancies and flags (brief item 6 — read before implementing)

**D1 (major) — Grid is 17×9, not 13×9.** The brief fixes the grid at 13×9; the codebase has `COLUMNS := 17` (and `ARCHITECTURE_NOTES.md` documents 17×9). Per the brief's own rule that the new 13x9 size is desired, this plan targets the **13×9 board**. Consequences carried through the whole plan:

- The sizing constraint is `width / 13`.
- The centered 9×9 placement zone leaves **8 outer columns (4 per side)**, not 4 (2 per side): the zone is **columns 4–12 inclusive** (centered on the King's column 8), rows 0–8 (the full height, since the board is 9 rows).
- If the user actually wants a 13-wide board, that is a **gameplay/balance change** (spawn pressure, level tuning, comparability with already-collected autoplay data) and must be explicitly ordered as a separate task — the implementing agent must NOT change `COLUMNS` as part of this layout work. → Question Q1.

**D2 — No "existing central-placement logic" exists.** The brief anticipated one might; none does. The zone is therefore centered on the King's position (`board.get_center_cell()`) per the brief's fallback. The King never moves during a run, so the zone is static.

**D3 — No settings system exists.** The brief wants the pause overlay to include "settings"; there is nothing to show. Proposal: a placeholder/disabled entry. → Question Q2.

**D4 — "Return to Home Office" mid-run currently has no clean path.** Simply calling `SceneRouter.go_home_office()` from a pause menu would **skip `_finish_run()`**: no `GameLogger.end_run` (the log file stays open, corrupting run statistics), no material conversion, no Final Stand score. The plan instead reuses `game.end_run_with_result("ABANDONED")` (its "AutoplayBot only" doc comment must be updated — a one-line flagged edit). → Question Q3.

**D5 — Node-path coupling.** `shop_ui.gd::show_currency_reward` looks up `get_parent().get_node("FloatingRewards")` and `get_node("CurrencyLabel")` relative to `UILayer`. Moving `CurrencyLabel` into a HUD bar container breaks the second lookup; the plan keeps `FloatingRewards` where it is and updates that one `CurrencyLabel` path (flagged one-line edit in `shop_ui.gd`).

**D6 — Portrait orientation.** Nothing in `project.godot` locks orientation. On a portrait phone a 13×9 landscape board becomes tiny. The plan recommends locking landscape (`window/handheld/orientation="landscape"`); a true portrait layout (board centered, tray at bottom?) is a different layout than this brief describes. → Question Q4.

---

## 2. Proposed sizing algorithm (brief item 2)

### 2.1 Stretch configuration — the foundation

Set in `project.godot`:

```ini
[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- `canvas_items` (already set) keeps UI scaled with the window; adding **`aspect="expand"`** removes the letterboxing: the design coordinate space expands to match the window's aspect ratio, and `get_viewport_rect().size` inside the game returns the live design size. This builds on the project's existing responsive pattern (stretch-based), so all layout code reads one size value and everything adapts.
- Reasoning for `expand` over the alternatives: `keep` (the current effective setting) is the letterbox culprit; `ignore` would stretch tiles into non-square rectangles (violates the brief); `expand` keeps tiles square and makes every extra pixel addressable by the layout algorithm below.

### 2.2 The layout algorithm (design-space pixels; recomputed on every resize)

Inputs: `V = get_viewport_rect().size` (W×H). Constants: grid 13×9; `HUD_MIN = 48`; `TRAY_MIN = 136` (fits the existing 120-wide slot + padding); `TRAY_MAX = 200`; `HUD_MAX = 128` (≈20% of the base height — only used in the narrower-aspect degradation below).

```text
1. tile   = floor(min((W - TRAY_MIN) / 13, (H - HUD_MIN) / 9))
2. hud_h  = H - 9 * tile      # HUD bar absorbs ALL vertical leftover  → full-bleed
3. tray_w = W - 13 * tile     # tray column absorbs ALL horizontal leftover → full-bleed
4. if tray_w > TRAY_MAX:      # extreme-WIDE degradation (see 2.3)
       surplus = tray_w - TRAY_MAX ; tray_w = TRAY_MAX
       split surplus symmetrically as board margins over the Background layer
   if hud_h > HUD_MAX:        # narrower-aspect cap (see 2.3)
       surplus = hud_h - HUD_MAX ; hud_h = HUD_MAX
       split surplus symmetrically as board margins over the Background layer
5. board_origin = (0, hud_h) horizontally anchored at x=0, board fills W - tray_w
```

Why this shape:

- **The UI enters the tile computation as minimums, not fixed sizes** (`TRAY_MIN`/`HUD_MIN` are subtracted before the `min`), so `tile` is the largest square tile that fits the grid plus the minimum UI reservations. Then, because `tile` is floored, the leftovers are *by construction* `< 13 px` horizontally and `< 9 px` vertically on the binding axis — and step 2/3 hand those leftovers to the HUD/tray **exactly**, so `hud_h + 9*tile = H` and `13*tile + tray_w = W`. Every pixel is accounted for: no dead margin, no letterbox, square tiles, full grid always visible. This "derive board first, fit UI into what's left" is exactly the brief's priority order.
- **A concrete number so the user knows what to expect:** at the base 1152×648 design — `tile = 59`, board 1003×531, **HUD 117 px tall (18% of height)**, tray 149 px wide. The HUD is taller than a typical 10% bar because a 13-wide board plus a side tray is width-bound at 16:9, so the vertical leftover (≈52 px) must go somewhere; full-bleed puts it in the HUD. On aspects **narrower** than 16:9 the raw HUD would grow past sane limits (16:10 → 197 px, 25%) and gets capped — see §2.3.
- **`floor` to an integer** keeps grid lines crisp and is what makes the leftover bounded and absorbable (a float tile would fit one axis with zero leftover but draws sub-pixel grid lines; integer is the cleaner trade).

Reasoning HUD/tray as *derived* rather than fixed/proportional: the project's UI already scales via the stretch system (device pixel density handled by `canvas_items` scaling), so inside the design space the only thing that varies is aspect ratio — and the derivation above absorbs aspect-ratio variance automatically (taller screens → bigger tiles → proportionally slimmer HUD; wider screens → wider tray up to the cap). Fixed design-space values would only be correct at exactly one aspect ratio.

### 2.3 Degradation at narrower/extreme aspects — flagged, not silent

The brief's own priority order governs the fallback: board first (fixed 13×9, square tiles, always fits), HUD/tray fit the remainder second, full-bleed third. So when full-bleed (priority 3) would force a *degenerate* HUD or tray, the earlier priorities win and the surplus becomes **symmetric board margins over the full-screen `Background` layer** (game-rendered background — never black bars):

- **Narrower than 16:9** (16:10 tablets, 4:3 iPads): the width axis binds → the raw HUD absorption grows past sane limits (16:10/1280×800 → 197 px = 25%; 4:3 → ~300 px). Capped at `HUD_MAX = 128`; the surplus splits symmetrically above/below the board. E.g. 1280×800 → `tile = 67`, HUD 128, margins ≈ 34 px top/bottom over the background.
- **Extreme wide** (2560×1080 ultrawide): the height axis binds → the raw tray would be 622 px wide. Capped at `TRAY_MAX`; surplus splits symmetrically left/right.
- **Portrait phones** (720×1280): width binds hard → capped HUD *and* small tiles; the layout is honestly poor — hence recommending the landscape orientation lock (Q4).
- **Where strict full-bleed holds exactly (zero background margin):** aspects ≳ 16:9 — `16:9 → hud 117 / tray 149` (both under the caps), `19.5:9 → hud 48 / tray ≈ 175`. This covers modern phone landscape, the primary target.

This is the tradeoff the brief asks to be flagged: on narrower aspects you cannot simultaneously have a fixed 13×9 square-tile grid, a sane HUD, *and* zero non-board pixels — the plan chooses grid integrity + sane HUD, with background-rendered (not letterboxed) margins absorbing the difference. → Question Q5.


### 2.4 Resize behavior

Connect `get_viewport().size_changed` (fired by `expand` on any window/aspect change) to a single layout function (the `ScreenLayout` node, Phase 4) that recomputes everything and **repositions live entities**: the King, every placed piece, and every enemy get `global_position = board.cell_to_world(current_cell)` re-applied (all three store `current_cell` — verified). In-flight projectiles keep their world positions; a projectile mid-flight during a resize may land a few pixels off its target's visual cell — accepted, flagged. `WaveBanner` and `GameOverLabel` re-center over the play area. The placement ghost re-positions automatically on the next `_process` frame (it follows the mouse cursor through `world_to_cell`). Nothing in the project handles resizes today, so this plan introduces the project's **first** resize-aware node — deliberately exactly one, so the pattern stays centralized.

---

## 3. Implementation phases

### Phase 0 — Pre-flight verification (read-only)

- [ ] `scripts/board.gd` still: `COLUMNS=13`, `ROWS=9`, `TILE_SIZE` const, hard-coded 1152×648 origin, `edge_cells` built in `_ready`.
- [ ] `scripts/placement_controller.gd::_draw` still references `board.TILE_SIZE` (4 spots) — the only external `TILE_SIZE` consumers in the project.
- [ ] `scripts/main.gd`: `update_hud()` writes the combined `StatusLabel` text; `_on_currency_changed` writes `CurrencyLabel`; `end_run_with_result` exists; `@onready` HUD node paths match `main.tscn`.
- [ ] `scripts/shop_ui.gd`: the two `get_parent().get_node(...)` lookups ("FloatingRewards", "CurrencyLabel").
- [ ] `scenes/main.tscn`: UILayer children inventory (`StatusLabel`, `GameOverLabel`, `CurrencyLabel`, `ShopUI`, `FloatingRewards`, `WaveBanner`).
- [ ] `project.godot` `[display]`: only `window/stretch/mode="canvas_items"`.
- [ ] **Ask the user §5 Q1 (grid size) before starting Phase 1** — it changes every number in §2.

### Phase 1 — Viewport & stretch configuration (`project.godot`, additive)

Apply §2.1: base size 1152×648, `stretch/aspect="expand"`, and (pending Q4) `window/handheld/orientation="landscape"`. Run the game: at 1152×648 nothing changes; at other window sizes the design space now expands (the board still sits at the old origin until Phase 2 — expected; this phase alone is safe to smoke-test).

### Phase 2 — Dynamic board (`scripts/board.gd`)

1. `const TILE_SIZE := 64` → `var tile_size := 64` (doc comment: pixel size adapts to screen; grid stays 13×9).
2. Replace the hard-coded `board_origin` computation with a public layout function:

```gdscript
## Positions/sizes the board for the current viewport. Called by ScreenLayout on
## _ready and every viewport resize. tile_size is integer so grid lines stay crisp.
func apply_layout(play_area_origin: Vector2, play_area_size: Vector2) -> void:
    tile_size = int(min(play_area_size.x / COLUMNS, play_area_size.y / ROWS))
    board_origin = play_area_origin + (
        (play_area_size - Vector2(COLUMNS * tile_size, ROWS * tile_size)) / 2.0
    )
    queue_redraw()
```

3. `_ready` keeps building `edge_cells` (cell-based, unchanged) but no longer computes the origin — `ScreenLayout` owns it now. Keep a sensible default origin so the scene is never uninitialized before the first layout pass.
4. `_draw` and `cell_to_world`/`world_to_cell` switch from `TILE_SIZE` to `tile_size` (mechanical). **Update the 4 `board.TILE_SIZE` references in `placement_controller.gd::_draw`** to `board.tile_size` (flagged companion edit — unavoidable since the const goes away).
5. Add the placement-zone query (used by Phase 6; lives on the board so the zone definition has one home):

```gdscript
const PLACEABLE_HALF_WIDTH := 4  # 9-wide zone centered on the King's column (13-col board)

## Player pieces may only be placed in the centered 9-column band (columns 4–12).
## Enemies use the whole board. Rows are unrestricted (board is 9 rows = zone height).
func is_placeable_cell(cell: Vector2i) -> bool:
    var center_column := get_center_cell().x
    return cell.x >= center_column - PLACEABLE_HALF_WIDTH and cell.x <= center_column + PLACEABLE_HALF_WIDTH
```

### Phase 3 — HUD bar (`scenes/main.tscn` + small `main.gd` edits)

Restructure `UILayer` (make it full-rect) into:

```text
UILayer (full-rect Control)
├── Background        (full-rect ColorRect, bottom-most, mouse_filter=IGNORE)
├── HUDBar            (PanelContainer, top-left-anchored, sized by ScreenLayout)
│   └── HBox
│       ├── MenuButton     (far left; "☰"; toggles PauseOverlay — Phase 7)
│       ├── LivesLabel     ("KING 3 / 3" — existing format from StatusLabel)
│       ├── WaveLabel      ("WAVE 1" — existing format, now its own label)
│       ├── Spacer         (size_flags expand → keeps WaveLabel visually centered)
│       └── CurrencyLabel  ("MATERIALS: 5" — same node name & format as today)
├── ShopUI            (Phase 4)
├── FloatingRewards   (unchanged, full-rect)
├── WaveBanner        (kept; re-centered by ScreenLayout)
├── GameOverLabel     (kept; re-centered by ScreenLayout)
└── PauseOverlay      (Phase 7)
```

`main.gd` edits (flagged, minimal): replace the single `@onready var status_label` with `lives_label` + `wave_label` (paths under `HUDBar/HBox`); `update_hud()` writes them separately using the **same formats** as today (`"KING  %d / %d"`, `"WAVE  %d"`). `StatusLabel` itself is removed (its two facts become separate labels); `GameOverLabel` and `FloatingRewards` keep their names and behavior. One-line `shop_ui.gd` fix per D5: the `get_node("CurrencyLabel")` lookup becomes `get_node("HUDBar/HBox/CurrencyLabel")`.

### Phase 4 — Tray + `ScreenLayout` coordinator

1. **Tray scene** (`scenes/shop_ui.tscn`): re-anchor the root to the right edge (`anchor_left=1, anchor_right=1`, spanning full remaining height), change `Slots` from `HBoxContainer` to `VBoxContainer` (alignment center). Slot scene, `shop_ui.gd`, and `shop_slot.gd` interaction logic untouched — the brief requires reusing the tray as-is; only its container, anchors, and offsets change. Slot min size stays 120×82 (5 slots ≈ 450 px tall, fitting the ≈531 px board height at the base design; the stretch system scales it on devices).
2. **New `scripts/screen_layout.gd`** on a `ScreenLayout` node added to `Main` (not `UILayer` — it also drives the board, a Node2D sibling). It implements §2.2 exactly:

```gdscript
const HUD_MIN := 48 ; const HUD_MAX := 128  # HUD_MAX caps absorption on narrower aspects
const TRAY_MIN := 136 ; const TRAY_MAX := 200

func apply_layout() -> void:
    var size := get_viewport_rect().size
    # §2.2 verbatim: tile = floor(min((W - TRAY_MIN)/13, (H - HUD_MIN)/9));
    # hud_h = H - 9*tile; tray_w = W - 13*tile (exact full-bleed absorption);
    # cap tray_w at TRAY_MAX / hud_h at HUD_MAX on extreme aspects and split
    # the surplus as symmetric board margins over the Background layer.
    # Then:
    board.apply_layout(play_area_origin, play_area_size)
    hud_bar.size = Vector2(size.x, hud_h)          # full width, exact height
    shop_ui.position = Vector2(size.x - tray_w, hud_h)
    shop_ui.size = Vector2(tray_w, size.y - hud_h)
    _recenter_labels_over_play_area(wave_banner, game_over_label)
    _reposition_board_entities()   # king + pieces + enemies: cell_to_world(current_cell)

func _ready() -> void:
    get_viewport().size_changed.connect(apply_layout)
    apply_layout()   # also called again at end of main._ready (king must exist first)
```

   The only ordering constraint: the King is positioned in `main._ready`, so the first real layout pass must run after that — call `screen_layout.apply_layout()` at the end of `main._ready()` (one flagged line in `main.gd`) or defer by a frame inside `screen_layout`.

### Phase 5 — Placement restriction (brief item 4)

Two call sites, both already error-path-compatible:

1. `scripts/placement_controller.gd::is_valid_placement_cell` — add one clause after the King-cell check:

```gdscript
    # Player pieces may only be placed in the central 9×9 zone (brief).
    if not board.is_placeable_cell(cell):
        return false
```

   That single edit covers **both** new placements (tap/drag from the tray) *and* the visual feedback: `_draw` already calls `is_valid_placement_cell` to color the hover tile, so outer-column tiles show the same red highlight as occupied tiles — exactly the "reuse existing invalid-tile handling" the brief requires. No new UI.

2. `scripts/piece_manager.gd::_process` (drag-moving an existing piece) — add the same `board.is_placeable_cell(cell)` guard next to its existing occupied/King-cell checks. Without this, a player could drag a piece *out* of the zone after placing it, violating the restriction. (Flagged companion edit; the brief says "placement attempts" and a drag-move is one.)

Enemies are untouched — they spawn on and traverse all 13 columns (`WaveManager.get_spawn_cell`, enemy movement), per the brief. The headless `AutoplayBot` needs no changes: it already filters candidates through `is_valid_placement_cell`, so its candidate set automatically shrinks to the zone (note for data continuity: this makes new autoplay data non-comparable with pre-restriction data on placement patterns — worth a note in the bot's docs, not a code change).

### Phase 6 — Pause overlay + menu button (brief: HUD item)

New `scenes/pause_overlay.tscn` + `scripts/pause_overlay.gd`, instantiated as a `PauseOverlay` child of `UILayer` (hidden by default, full-rect, dim `ColorRect` background):

- **Root `process_mode = PROCESS_MODE_ALWAYS`** (children inherit → buttons work while paused). Everything else in the scene tree is default-pausable, so `get_tree().paused = true` stops WaveManager spawning/timers, enemy movement, projectiles, piece firing, and the wave-banner tween in one call. Known consequence (accepted, flag in report): `GameLogger`'s periodic flush also pauses — its buffer is retained and flushed on unpause/exit, so no log data is lost; run-duration statistics simply exclude paused time (the logger measures elapsed ticks, which pause too).
- **Buttons**: `Resume` (unpause), `Settings` (placeholder per D3 → Q2), `Return to Home Office`. The brief is explicit that this player-initiated pause does not conflict with the no-forced-pauses design decision — document that rationale in the overlay script's header comment.
- **Return to Home Office**: unpause **first**, then `game.end_run_with_result("ABANDONED")` (D4). That reuses the existing path: outcome + waves are set, `end_game → _finish_run` converts material, records Final Stand score if applicable, logs `end_run` (so the CSV/JSONL closes cleanly), and routes home. Update `end_run_with_result`'s doc comment, which currently claims AutoplayBot-only use (one flagged line in `main.gd`).
- **`MenuButton.pressed`** (HUDBar, Phase 3) → show overlay + `get_tree().paused = true`; `Resume` → hide + `get_tree().paused = false`. Also unpause defensively in `main._exit_tree` (if the scene changes while paused, the next scene would inherit a paused tree).
- Keep WaveManager's debug Z/X/C keys in mind during testing: paused nodes don't receive input, so debug keys are naturally disabled while paused — a nice side effect, no change needed.

### Phase 7 — Validation matrix (run after each phase, and fully at the end)

Manual, in-editor (window sizes via `Editor → Run Window → Custom Size` or dragging the OS window):

1. **1152×648 (base)** — layout identical in spirit to today: board centered, HUD top, tray right, zero dead margins; tiles perfectly square (measure a tile: `board.tile_size` printed).
2. **1280×800 (16:10)** — HUD capped at 128 with symmetric ≈34 px margins above/below the board rendered over the `Background` layer (expected per §2.3, **not** a failure); tiles larger than at base; no black bars anywhere. Also verify **16:9** (e.g. 1280×720): HUD 117, tray ≈ 136, zero background margin (strict full-bleed).
3. **2560×1080 / ultrawide (extreme wide)** — tray capped at `TRAY_MAX`; surplus split symmetrically over the `Background` layer; board remains centered; **no black bars anywhere**.
4. **Resize mid-run** with pieces placed and enemies walking — board re-layouts; pieces/enemies snap to their cells' new world positions; a mid-flight projectile is briefly offset (accepted); game continues normally; no orphaned pieces floating off-grid.
5. **Placement restriction** — try placing on outer columns (4 left, 4 right): red highlight + no purchase, currency untouched; place in columns 4–12: works; drag an existing piece to an outer column: refused; enemies still spawn/traverse outer columns; `AutoplayBot` headless run (`--strategy=balanced --level=level_1 --runs=1`) still completes and only places inside columns 4–12 (check `bot_placed` events in JSONL).
6. **Pause** — pause during an active wave: enemies/spawning/timers freeze; HUD still shows; Resume continues exactly where frozen (no wave skip, no double-spawn); Return to Home Office ends the run with outcome `ABANDONED` in the logs (verify `end_run` event in JSONL, material converted, no open log corruption); menu button unreachable after game over (scene switches anyway).
7. **Tray regression** — tap-to-place and drag-drop both still work from the right-side tray; affordability dimming updates; floating reward animates toward the HUD's `CurrencyLabel` (validates the D5 path fix); 5 slots fit vertically at base size.
8. **HUD regression** — lives/wave/material values match the old combined label at every state change (wave start, king hit, purchase).

### Phase 8 — Documentation

Append a section to `tasks/ARCHITECTURE_NOTES.md`: dynamic `tile_size` + `apply_layout` on the board, the `ScreenLayout` node, new HUD bar node names, right-side vertical tray, `is_placeable_cell` zone, pause overlay semantics (incl. the `ABANDONED` outcome label), and the `expand` stretch config. The README remains out of scope (already flagged stale).

---

## 4. Suggested build order

1. **Get Q1 answered first** (grid 13 vs 17 — it changes every constant).
2. Phase 1 (stretch config) → Phase 2 (dynamic board) → **validate at multiple window sizes** (board alone, old HUD floating but functional).
3. Phase 3 (HUD bar) + Phase 4 (tray + `ScreenLayout`) → **validate 7.1–7.4, 7.7, 7.8** — the full-bleed goal is met at this point.
4. Phase 5 (placement restriction) → **validate 7.5**.
5. Phase 6 (pause overlay) → **validate 7.6**.
6. Phase 7 full pass + one headless `AutoplayBot` smoke run per combination sample.
7. Phase 8 (docs), then **stop and report**, listing every flagged edit actually made.

Each of phases 2–6 is independently revertible; keep them as separate commits so a layout regression is easy to bisect.

---

## 5. Questions requiring user confirmation

**Q1 (blocking) — Grid dimensions.** The brief says 13×9; the code is 17×9 (and all waves, levels, autoplay data, and `ARCHITECTURE_NOTES.md` assume 17). This plan assumes **changes to 13**. Is this confirmed?

A: Yes. The current codebase is adopts 17 columns but I want 13 columns in the new design. 

**Q2 — Settings in the pause menu.** No settings exist yet. Should the pause overlay ship with (a) a disabled "Settings…" button labeled coming soon, (b) no settings entry for now, or (c) a real minimal settings panel (e.g. master volume) — noting the game currently has no audio/settings code, so (c) is new subsystem work beyond this layout task?

A: Make setting a silent button for now but keep the code easily adjustable to further additional of this function.

**Q3 — Abandon outcome label.** Reusing `end_run_with_result` for "Return to Home Office" logs the run with outcome `"ABANDONED"` (plus the waves survived). Any downstream analysis that knows `WIN`/`LOSE`/`TIMEOUT` should be told about the new value — is `ABANDONED` the label you want?

A: Yes this is a good label.

**Q4 — Orientation lock.** Add `window/handheld/orientation="landscape"` to `project.godot` as part of this task (recommended — the layout, like the brief, assumes landscape), or leave orientation unlocked and accept a degraded portrait layout (tiny board, margins)?

A: Lock the orientation to landscape please.

**Q5 — Aspect-ratio tradeoff confirmation.** The plan's default: aspects ≳ 16:9 get exact full-bleed (HUD/tray absorb all leftover); narrower aspects (16:10 tablets, 4:3 iPads) and extreme ultrawides cap the HUD/tray and render the surplus as symmetric margins over a game background layer — never black bars (rationale: the brief's priority order puts board first, full-bleed third). Alternative if you want literal zero-margin everywhere: remove the caps and let the HUD grow to 25%+ of the screen on tablets (a giant HUD, arguably worse), or accept non-square/clipped tiles (both violate the brief). Confirm the default, or pick an alternative.

A: Yes for extreme cases it is good to have margins for the sake of visual effects.

**Q6 — HUD format check.** Brief says "match existing display format": the plan keeps `"KING  %d / %d"`, `"WAVE  %d"`, and `"MATERIALS: %d"` verbatim, just in separate labels. OK, or do you want them restyled now (fonts/icons are not part of this task otherwise)?

A: Keep them for now. I will optimise later.

---

## 6. Deliverables checklist

```text
project.godot                    (+base size, +stretch aspect expand, +orientation — additive)
scripts/board.gd                 (tile_size var, apply_layout, is_placeable_cell)
scripts/placement_controller.gd  (+zone check; TILE_SIZE→tile_size in _draw)
scripts/piece_manager.gd         (+zone check on drag-move)
scripts/main.gd                  (HUD label split, menu hookup, layout call, doc comment)
scripts/shop_ui.gd               (1-line CurrencyLabel path fix)
scripts/screen_layout.gd         (new — the layout coordinator)
scripts/pause_overlay.gd         (new)
scenes/main.tscn                 (UILayer restructure: Background, HUDBar, labels)
scenes/shop_ui.tscn              (right-edge anchors, HBox→VBox)
scenes/pause_overlay.tscn        (new)
tasks/ARCHITECTURE_NOTES.md      (appended layout section)
```

Everything else — combat, waves, enemies, currency, logging semantics, tray interaction logic — is untouched. No tile is ever non-square; the 13×9 grid always fits; the board size derives first, HUD/tray fit the remainder.





