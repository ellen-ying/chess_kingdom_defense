# Chess Kingdom Defense — Architecture Notes

_Last updated: 2026-09-27. The full-game expansion described in the earlier version of this document (a pre-expansion audit report) is now implemented. These notes describe the current architecture._

## Current game loop

Title screen → **Home Office** hub → Level Select / Skill Shop / Bestiary / Learning Openings. Level Select starts a run in the gameplay scene; on win or loss the run's earned Run Material is converted to Office Material and the player returns to the Home Office.

- Godot 4.7, mobile renderer (`project.godot`). The main scene is now `res://scenes/title_screen.tscn` (previously `main.tscn` directly).
- All menu navigation goes through the `SceneRouter` autoload; gameplay never references menu scene paths. `SceneRouter.selected_level_id` is how a level is handed to `main.tscn`.

## Autoloads

| Autoload | Script | Persistence | Scope |
| --- | --- | --- | --- |
| `SaveData` | `scripts/save_data.gd` | owns it | Sole save boundary: sectioned `ConfigFile` at `user://save.cfg`, `get_value`/`set_value` only |
| `CurrencyManager` | `scripts/currency_manager.gd` | — | Run Material (per-run) + chess-piece kill values |
| `InventoryManager` | `scripts/inventory_manager.gd` | — | Per-run placed-piece counts |
| `OfficeMaterialManager` | `scripts/office_material_manager.gd` | `office_material` | Persistent Home Office currency |
| `RunRewardManager` | `scripts/run_reward_manager.gd` | — | Converts **earned** Run Material → Office Material at run end |
| `SceneRouter` | `scripts/scene_router.gd` | — | Scene navigation + selected level identity |
| `LevelProgressManager` | `scripts/level_progress_manager.gd` | `level_progress` | Level unlock/completion state, Final Stand high score |
| `BestiaryManager` | `scripts/bestiary_manager.gd` | `bestiary` | Encountered enemy types |
| `SkillManager` | `scripts/skill_manager.gd` | `skills` | Permanent skill ownership + effect queries |
| `DailyRewardManager` | `scripts/daily_reward_manager.gd` | `daily_rewards` | 5/day Office Material claims (rewarded-ad stub) |
| `GameLogger` | `scripts/game_logger.gd` | writes own files | Pure-observer gameplay telemetry, CSV + JSONL |

## Persistence

`SaveData` is the only save file. Feature managers each own a section so migrations stay localized. Runtime gameplay state (Run Material balance, placed pieces, lives, wave progress) is deliberately **not** persisted.

| Section | Owner | Keys |
| --- | --- | --- |
| `office_material` | OfficeMaterialManager | `current_amount` |
| `level_progress` | LevelProgressManager | `unlocked_level_ids`, `completed_level_ids`, `final_stand_high_score` |
| `bestiary` | BestiaryManager | `encountered_enemy_types` |
| `skills` | SkillManager | `owned_skill_ids` |
| `daily_rewards` | DailyRewardManager | `last_reset_date`, `uses_today` |

## Two material economies (kept separate)

- **Run Material** — `CurrencyManager`, starts at 5 per run, never persists. Concrete enemy scripts still grant their own kill rewards via `add_currency(value)` using standard chess-piece values (`PIECE_VALUES`). New since the audit: a `currency_earned(amount)` signal, a `currency_spent` counter, and an optional Material Ledger multiplier applied inside `add_currency` (with a fractional remainder so no material is lost).
- **Office Material** — `OfficeMaterialManager`, persistent, spent only in the Skill Shop. Earned two ways:
  1. `RunRewardManager.finish_run()` converts `RUN_TO_OFFICE_RATE = 0.20` × Run Material **earned** this run (it tracks the `currency_earned` signal, so mid-run spending cannot reduce the payout).
  2. `DailyRewardManager.claim_reward()` (Learning Openings screen): +1 Material, 5 uses/day, date-based reset. A future rewarded-ad callback just calls `claim_reward()`.

## Run lifecycle (`scripts/main.gd`)

- `_ready()`: `GameLogger.start_run(SceneRouter.selected_level_id)` → resolve `LevelConfig` via `LevelProgressManager.get_level_config` (falls back to Home Office if missing) → reset `CurrencyManager`/`InventoryManager` → `max_lives = 3 + Royal Reserve skill bonus` → `RunRewardManager.begin_run()` → `wave_manager.configure_level(config)` + `setup(...)`, connected to `level_completed` and `wave_started`.
- **Win**: `WaveManager.level_completed` → `outcome = "WIN"` → `LevelProgressManager.complete_level(id)` (marks completed, unlocks the next level in `LEVEL_ORDER`).
- **Loss**: `enemy_reached_king` decrements lives; at 0, `end_game()` sets `outcome = "LOSE"` and records `waves_survived`.
- `_finish_run()` (shared tail): records the Final Stand score for infinite levels, `RunRewardManager.finish_run()`, `SceneRouter.go_home_office()`, then `GameLogger.end_run(outcome, waves_survived, earned, spent)` with an integrity check that outcome/waves were set.

## Levels and waves

- `LevelConfig` (`scripts/level_config.gd`) is the editor-authored resource: `level_id`, `display_name`, `allowed_enemy_pieces`, `wave_count` (**-1 = infinite**), an optional explicit `wave_resources: Array[WaveConfig]`, plus difficulty-curve fields (`wave_duration`, `base_spawn_interval`, `spawn_interval_reduction_per_wave`, `minimum_spawn_interval`).
- Six resources in `resources/levels/`: `level_1`–`level_5` reuse the original `resources/wave_1..wave_5.tres` in their `wave_resources` lists; `final_stand` is infinite (`wave_count = -1`, all enemy types) and generates every wave.
- `WaveManager.configure_level(config)` is the only configuration boundary; the legacy `waves` inspector array is overwritten at this point. Non-infinite levels without explicit wave resources fall back to generated waves.
- Infinite mode (`start_new_wave`) appends a generated `WaveConfig` each round with the spawn interval shrinking per wave down to the level minimum.
- Public signals: `level_completed` (emitted when the wave index runs past the end) and `wave_started`. The old `wave_spawning_finished` emission is still commented out.
- `spawn_random_enemy()` instantiates the enemy, calls `enemy.setup(game, spawn_cell)`, then `GameLogger.log_enemy_spawned(...)` and `BestiaryManager.mark_encountered(type)` — the bestiary hook lives on the spawn path only.
- Debug tooling: `debug_mode` defaults to **true** (Z/X/C = previous/next/restart wave) and `debug_start_wave` can begin a run at any wave.

## Gameplay scene hierarchy (`scenes/main.tscn`)

Unchanged from the pre-expansion audit:

```text
Main (main.gd)
├── Board
├── King
├── Pieces
├── Enemies
├── Projectiles
├── PieceManager
├── EnemyManager
│   └── SpawnTimer
├── WaveManager
├── PlacementController
└── UILayer
    ├── StatusLabel
    ├── GameOverLabel
    ├── CurrencyLabel
    ├── ShopUI
    ├── FloatingRewards
    └── WaveBanner
```

Hub screens are separate `Control` scenes (`title_screen`, `home_office`, `level_select`, `skill_shop`, `bestiary`, `learning_openings`, `placeholder_screen`), each a plain script driving `%unique_name` nodes and calling `SceneRouter`; cards/entries are built in code from manager data.

## Combat hooks added for skills

- All five defender scripts (`pawn`/`knight`/`bishop`/`rook`/`queen`) now gate firing with `SkillManager.get_attack_interval(FIRE_INTERVAL, self, game)`, which combines the global interval multiplier, Knight Tempo, Pawn Phalanx (adjacent-Pawn check), and the Queen's Command aura (hard-coded 0.85 multiplier within the aura radius).
- `Main.spawn_projectile` passes the source piece; `projectile.gd` stores `source_piece` and calls `target.take_damage(damage, source_piece.type)`. On a `BaseEnemy` hit it also calls `SkillManager.apply_projectile_effects`, which implements Bishop's Bind (`apply_slow`, 40% for 1.5 s) and Rook's Rebuff (`push_away_from_king`).
- `BaseEnemy` gained the status-effect primitives: `apply_slow(multiplier, duration)`, `get_move_interval(base)`, `update_status_effects(delta)`, and `push_away_from_king(distance)`; concrete enemies call `update_status_effects` + `get_move_interval` in `_process`.
- The eight skills in `resources/skills/` are `SkillDefinition` resources keyed by `EffectType`; `SkillManager` is the single query surface (`has_skill`, `get_effect_value`, `get_attack_interval`, `apply_projectile_effects`, `purchase_skill`). Only owned IDs are persisted.
- ⚠️ Skill attribution matches piece scripts by path suffix (`script_path.ends_with("knight.gd")` etc.). Renaming a defender script silently disables its skill hooks.

## Bestiary, daily rewards, telemetry

- `EnemyBestiaryEntry` resources (`resources/bestiary/`) hold presentation-only data (movement description, flavor, optional illustration). `bestiary.gd` renders locked cards as "?" until `BestiaryManager.has_encountered(type)`.
- Learning Openings is the UI front for `DailyRewardManager`; `claim_reward()` is the intended future rewarded-ad entry point.
- `GameLogger` is observer-only (never mutates gameplay). It buffers events and writes paired CSV + JSONL files to `user://logs/`, flushing every 3 s or every 100 events, and only while a run is open (menu activity is not logged). Call sites: `main.gd` (run start/end, enemy killed with source piece + time alive, material earned, king life lost, enemy reached king), `wave_manager.gd` (wave start/end, enemy spawned), and `placement_controller.gd` (piece purchased, piece placed).

## Known gaps and risks

- **README is stale**: it still describes the Rook-only sandbox with no shop/currency/waves and P/N/B/R/Q piece-switching; the game now has levels, a hub, meta progression, and telemetry. The hub flow descriptions/screenshots there are additionally outdated since the interaction redesign (the old button-card hub is gone — see "Home Office interaction" below).
- **Debug keys off by default**: `WaveManager.debug_mode` now defaults to `false`, so Z/X/C wave jumps only work when enabled in the editor; `debug_start_wave` is still honored in `setup`. (The Z/X/C paths set `spawning`/`waiting_for_clear` to false and can leave a wave in limbo — re-enable only for debugging.)
- **Legacy `EnemyManager` auto-spawn path still exists** but is dormant: `auto_spawn_enemies` defaults to `false`, `main.tscn` no longer overrides it or connects `SpawnTimer.timeout`, and `spawn_enemy()` there does not log to GameLogger or mark bestiary encounters. Levels rely exclusively on `WaveManager`; the legacy node could be deleted after confirmation.
- `take_damage` now requires a `source_piece: String` argument on every enemy; any future enemy script must implement the new signature (status-effect tick too).
- `RunRewardManager` conversion is unconditionally 20% (`RUN_TO_OFFICE_RATE`); no upgrade path modifies it yet.
- Kill rewards are still hard-coded per enemy script (`CurrencyManager.get_piece_value(...)`), so reward balance changes touch five enemy files rather than one table.

## AutoplayBot (headless auto-play, additive)

- `AutoplayBot` (`scripts/autoplay_bot.gd`) is a **dormant autoload** for automated headless data generation. It activates only when (a) recognized auto-play arguments appear after `--` on the command line AND (b) the display server is headless. In normal play it does nothing (it disables its own `_process` at startup).
- It drives the game exclusively through the human input paths' underlying functions: `ShopUI.begin_tray_pointer()` → `PlacementController.place_piece()` (literal mouse-event replay is impossible in `--headless`). It never mutates gameplay state directly.
- CLI contract (all optional, `--key=value`): `--strategy` (`cheapest_first` | `balanced` | `rush_strongest` | `random`, default `balanced`), `--level` (any id in `LevelProgressManager.LEVEL_CONFIGS`, default `level_1`), `--runs` (default 1), `--decision-interval` (game seconds, default 0.5), `--timeout-seconds` (real seconds, default 600), `--final-stand-cap` (default 30), `--rush-gap` (default 3), `--seed` (default -1 = unseeded), `--time-scale` (default 16.0, runtime-only speed-up). After the final run the process calls `get_tree().quit()`.
- Placement uses a line-aware threat heuristic: a threat map (enemy cells weight 3, sign-step corridors toward the King weight 1) scored per candidate cell via the defender's own pure `get_attack_tiles_for_cell()` geometry (so Bishop diagonals / Rook rays / Queen lines differ per cell), with a `coverage_fallback` (King's Chebyshev 1–2 ring) between waves. The heuristic used is logged per placement.
- Bot events go through the additive `GameLogger.log_bot_event()` helper: `bot_run_config` (run start: strategy/level/seed/time-scale/...), `bot_placed`, `bot_idle`, `run_timeout`, `bot_run_capped`. **JSONL is authoritative for bot events** (CSV only fills matching columns).
- `Main.end_run_with_result(result)` (`main.gd`) is the **only** gameplay-file hook: it force-ends a run with an explicit outcome label (`"TIMEOUT"`, or `"WIN"` for wave-capped Final Stand runs, distinguished by `bot_run_capped`). It is for the bot only and must never be called from normal gameplay logic.
- `tools/run_autoplay_batch.sh` runs all 4 strategies × 6 levels sequentially (env-configurable: `GODOT_BIN`, `RUNS`, `TIME_SCALE`, `TIMEOUT_SECONDS`, `FINAL_STAND_CAP`, `DECISION_INTERVAL`, `SEED`, `CAPTURE_DIR`), backs up/restores `user://save.cfg` around the batch (the game creates a fresh `save.cfg` if none exists), and archives only each combination's new logs into `data-captures/` with `strategy_level_` prefixed filenames (`data-captures/` is gitignored).

## Full-bleed gameplay layout

- **Grid is now 13×9** (`board.gd`), with an **adaptive `tile_size`** (var, integer) set by `apply_layout(play_area_origin, play_area_size)` — the largest square integer tile that fits the play area; the grid never changes, only pixels-per-tile. The hard-coded 1152×648 board origin is gone (a centered default remains only until the first layout pass).
- **Viewport config**: base size 1152×648, `stretch/mode="canvas_items"` + `stretch/aspect="expand"` (kills letterboxing; design space expands to the window's aspect), `handheld/orientation="landscape"`.
- **`ScreenLayout`** (Node child of `Main`, `scripts/screen_layout.gd`) is the project's single resize-aware node: on `size_changed` (and once from `main._ready` after the King exists) it sizes the board first — `tile = floor(min((W-136)/13, (H-48)/9))` — then the HUD bar and tray absorb ALL leftover pixels (exact full-bleed), capped at HUD 128 / tray 200 on extreme aspects, with the surplus rendered as symmetric board margins over a full-screen `Background` ColorRect (first child of `Main`, under the Board — never black bars). It also explicitly sizes the full-screen `UILayer` and `Background` layers (top-level Controls under a Node2D do not resolve viewport anchors in this Godot build — do not rely on Full Rect anchors on them), repositions live King/pieces/enemies to their cells' new world positions on resize, and recenters WaveBanner/GameOverLabel over the play area.
- **HUD bar** (`UILayer/HUDBar`, sized by ScreenLayout): full-width PanelContainer at the top with `MenuButton` (☰), `LivesLabel` ("KING  %d / %d"), `WaveLabel` ("WAVE  %d"), an expanding spacer, and `CurrencyLabel` ("MATERIALS: %d", same node name/format as before — `shop_ui.gd` looks it up as `HUDBar/HBox/CurrencyLabel`). The old combined `StatusLabel` is gone; `main.gd::update_hud()` writes the two labels separately with the same formats.
- **Tray** (`ShopUI`): right-edge vertical column (root anchored top-left with ScreenLayout driving geometry; `Slots` is now a `VBoxContainer`). Slot scenes and interaction logic unchanged.
- **Placement zone**: `board.is_placeable_cell()` limits player placement (new pieces via `PlacementController.is_valid_placement_cell`, drag-moves via `PieceManager._process`) to the centered 9-column band (columns 2–10, ±4 around the King's column 6); outer columns are enemy-traversal-only and get the existing red-highlight feedback. Enemies and `AutoplayBot` are unaffected structurally — the bot inherits the zone through `is_valid_placement_cell` (note: autoplay placement data collected before the 13×9 + zone change is not comparable with data after it).
- **Pause overlay** (`UILayer/PauseOverlay`, `scenes/pause_overlay.tscn` + `scripts/pause_overlay.gd`): opened by MenuButton; root `process_mode=ALWAYS` so its buttons work while `get_tree().paused = true` stops waves/enemies/projectiles/piece firing. Buttons: Resume, Settings (silent placeholder — no settings subsystem yet), Return to Home Office → unpause then `main.end_run_with_result("ABANDONED")` (clean log closure + material conversion; `end_run_with_result` is now documented as bot- and pause-menu-use). `main._exit_tree` unpauses defensively so the next scene never inherits a paused tree. This player-initiated pause is distinct from the no-forced-pauses wave design decision.

## Home Office interaction (hotspots, crossfade, tutorials, popups)

- **The old hub UI is gone**: the "THE HOME OFFICE" title label, Office Material readout, and the four-button OfficeCard were removed. Navigation happens through invisible tap zones over the art; Office Material is shown inside the Skills and Earn Materials screens instead. The hub scene (`scenes/home_office.tscn`) is `FallbackBackground` + `Background` (TextureRect) + full-rect `Zones` + per-zone `AudioStreamPlayer`s (`HomeOfficeMusic` autoplays).
- **Zones** (`scripts/home_office_zones.gd`, the full-rect `Zones` child): four tap rectangles defined in **IMAGE-PIXEL coordinates of the 1376×768 `home_office.jpg`** (user-confirmed calibration): Play/chessboard 460,410→875,585 · Skills/trophy shelf 15,55→300,420 · Bestiary/display case 1035,140→1295,445 · Earn/ledger-coins 860,490→1330,715. **Mapping contract**: because `Background` uses `STRETCH_KEEP_ASPECT_COVERED` (center-cropped at non-16:9 aspects), zone rects MUST go through the cover-crop mapper (`_image_to_screen_rect`) — never use the control rect directly. Mapping recomputes on every `size_changed`. Input conventions: warm additive glow on press-down, action on release inside the same zone, release-outside cancels; a per-zone sound player fires on activation. `set_input_locked()` gates input (crossfade, popups); `set_cues_paused()` pauses the ambient tweens. `show_debug_zones` draws calibration outlines (zones colored, star positions as white dots, window flare cyan).
- **Ambient cues**: a field of small additive near-white twinkling stars overlaid ON the coins, the trophies, and the glass display case (star centers are image-pixel constants; shared 2.4 s twinkle period with per-star phase and peak, so several are always lit — "constantly shining"). Star positions/sizes are user-tuned constants; the tweens pause while a popup is open.
- **Title→office crossfade**: `SceneRouter.arriving_from_title` (set once by `title_screen.advance()`, consumed by the hub) runs a 0.55 s dual fade in the hub — a full-screen overlay replicating the title's final visual (dark fallback + title/prompt labels) fades out while the office art fades in — with a warm window flare over the confirmed arched-window rect (295,15→475,425) peaking at the crossfade midpoint. Zone input stays locked until the fade completes. Repeat hub visits (popups, returning from gameplay) never set the flag and skip all of it.
- **`TutorialManager`** (autoload, `scripts/tutorial_manager.gd`): one `tutorial` SaveData section with two keys (`stage_1_done`, `stage_2_done`) — **no other save-schema change was needed**; `stage_2_step` is RUNTIME-ONLY (never persisted). Stage 2 is win-gated: `should_show_stage_2()` = `not stage_2_done and LevelProgressManager.is_level_completed("level_1")` — win-only by construction, since completion is set only on the WIN path (a loss never triggers the tutorial).
- **Tutorial overlays** (`scripts/tutorial_overlay.gd`, code-built by the hub): a dim-with-hole spotlight (0.55 dim, soft additive ring, gold/outline callout above the zone). Stage 1 (fresh save): Play spotlight, any tap completes Stage 1 and proceeds normally (the Play tap opens the Level Select popup). Stage 2 (first office visit after winning Level 1): sequential spotlight over Skills → Bestiary → Earn Materials, driven by a **show counter** — every shown spotlight advances `TutorialManager.stage_2_advance()` (Stage-1 shows deliberately don't touch the counter), completing the stage on the third. Within one office visit the sequence advances two ways: a called-out zone tap opens that zone's popup (the next spotlight appears when the popup closes), and **a tap on empty space advances the spotlight sequence directly — intentional design, not a skip**. A completed stage never re-triggers. Fading overlays rename to `TutorialOverlayFading` so a new spotlight created during the 0.18 s dismiss window can't collide with the `TutorialOverlay` name.
- **Popups** (`scripts/popup_container.gd`): a themed popup built **entirely in code and parented into the hub — never a scene change**, so `HomeOfficeMusic` and the hub's sound players keep playing through. Shared "opened ledger" frame: dark-wood/gold StyleBoxFlat panel at 75% of both screen axes (centered), a wax-seal ✕ close button overlapping the top-right border, a 0.45 dim with tap-to-close, and Esc (`ui_cancel`) close — all three call one `close()`. Open: the frame scales up from the tapped zone's point (0.22 s, TRANS_BACK/EASE_OUT); close reverses over 0.15 s. While open: zone input locked, star cues paused. `layout_frame()` re-sizes/centers on viewport resize.
- **Content embedding**: the four existing content scenes are reused as popup interiors via a uniform 3-line convention each (`embedded: bool` + `close_requested` signal + `_on_back_pressed` = `if embedded: close_requested.emit() else: SceneRouter.go_home_office()`); standalone behavior is unchanged and the `SceneRouter.go_*` routes remain for standalone fallback. Level Select's level buttons still call `SceneRouter.start_level()` — starting gameplay from the popup breaks out cleanly (popup and hub die naturally with the scene change; no leaked nodes). The hub's zone action (`home_office.gd::_on_zone_activated`) fires the per-zone sound, then opens the popup.



