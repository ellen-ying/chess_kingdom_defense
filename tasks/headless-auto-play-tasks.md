# Chess Kingdom Defense — Headless Auto-Play: AI Agent Implementation Plan

_Source brief: `tasks/headless-auto-play-brief.md`. Current architecture: `tasks/ARCHITECTURE_NOTES.md`._
_Written 2026-09-27. All integration points below were verified against the actual source code on this date; the implementing agent should re-verify anything marked ⚠️ VERIFY in Phase 0._

---

## 0. Non-negotiable contract

This work is **purely additive**. The bot must drive the game through the same functions a human's UI interaction reaches. Do **not**:

- mutate `CurrencyManager.current_amount`, piece positions, wave state, or any gameplay state directly;
- rebalance, refactor, or "clean up" existing gameplay code while in there (including the known pawn-promotion hack and the dormant `EnemyManager` path — see §5, Q1);
- change existing `GameLogger` event semantics or columns.

The only existing-file edits permitted are the **minimal, explicitly-flagged hooks** in Phase 5 (`game_logger.gd` bot-event helper) and Phase 7 (`main.gd` forced-run-end). Each must be reported to the user when made.

---

## 1. Verified integration points (do not re-guess these)

These were read from the current code. The implementing agent should confirm they still match before coding (Phase 0 checklist).

### The human purchase → placement path

```text
ShopSlot._gui_input (mouse press)
  → ShopUI.begin_tray_pointer(piece_type)              # scripts/shop_ui.gd
      - affordability check: CurrencyManager.current_amount >= CATALOG[type]["cost"]
      - otherwise silently returns (no selection started)
  → PlacementController.begin_piece_selection(type, scene)   # mode = PENDING_DRAG, creates ghost
  → (human drags ≥ 8 px, releases mouse)
  → PlacementController._handle_drag_drop()
  → PlacementController.place_piece(cell)              # THE actual purchase
      - is_valid_placement_cell(cell)
      - re-checks affordability, then CurrencyManager.spend_currency(cost)
      - GameLogger.log_piece_purchased(...) + log_piece_placed(...)
      - instantiates the piece scene, piece.setup(game, cell)
      - InventoryManager.add_piece(type)
      - clear_placement()
```

Key signatures (all public, callable without touching scenes):

```gdscript
# scripts/shop_ui.gd (panel in UILayer of main.tscn, exposed as Main.shop_ui)
const CATALOG: Dictionary  # Pawn=1, Knight=3, Bishop=3, Rook=5, Queen=9 (incl. preloaded scenes)
func begin_tray_pointer(piece_type: String) -> void

# scripts/placement_controller.gd (exposed as Main.placement_controller)
func is_valid_placement_cell(cell: Vector2i) -> bool   # valid cell, not King cell, no piece there
func place_piece(cell: Vector2i) -> void               # spends currency, logs, spawns the piece
func clear_placement() -> void
```

**The bot's action primitive is therefore:**

```gdscript
game.shop_ui.begin_tray_pointer(piece_type)       # same affordability gate the UI applies
game.placement_controller.place_piece(cell)       # same purchase function a drag-drop reaches
```

`place_piece` works from the `PENDING_DRAG` state without any mouse events: it re-validates, re-checks affordability (currency may have changed since selection), spends, logs, spawns, and clears. **Important, and worth stating in the final report:** a literal replay of mouse `InputEvent`s is impossible in `--headless` (no mouse / DisplayServer input), so the bot calls the functions one layer *below* the input plumbing. Everything game-logic-relevant (affordability, validity, spending, logging, inventory) is still exercised. This is the closest headless equivalent of a human click-and-drop.

### Cost note ⚠️

`ShopUI.CATALOG["cost"]` uses the same values as `CurrencyManager.PIECE_VALUES`, and `place_piece` actually charges `CurrencyManager.get_piece_value(type)`. The bot treats **`CurrencyManager.get_piece_value(type)` as the price of record** (it is what the game really deducts). They currently match; if they ever diverge that is a real bug the bot will surface — do not "fix" it silently.

### Run lifecycle (for the runner loop)

```text
SceneRouter.start_level(level_id)                     # sets selected_level_id, loads main.tscn
  → main.gd _ready(): full per-run reset
      (CurrencyManager.reset_for_new_run, InventoryManager.reset_for_new_run,
       RunRewardManager.begin_run, GameLogger.start_run → NEW run_id + NEW log files per run)
  → run plays out
  → Win: WaveManager.level_completed → main._on_level_completed → _finish_run()
  → Loss: lives hit 0 → main.end_game() → _finish_run()
  → _finish_run(): records Final Stand score, RunRewardManager.finish_run() (20% conversion),
     SceneRouter.go_home_office()   ← the scene change = the runner's "run finished" signal
     GameLogger.end_run(outcome, waves_survived, earned, spent)
```

Because `main._ready()` resets everything per run and `GameLogger.start_run()` opens a fresh `run_id`/files each time, **re-entering the gameplay scene is a complete, clean reset** — no extra reset code is needed for `--runs=N`.

Useful public state on `Main` (all accessible): `game_over`, `outcome`, `waves_survived`, `lives`, `king`, `enemies` (container), `piece_parent`, `wave_manager` (`get_wave_number()`, `current_wave_index`), `shop_ui`, `placement_controller`, `board`.

### Board and enemies (for the placement heuristic)

- Board: 17 × 9 (`board.COLUMNS`/`ROWS`), `TILE_SIZE 64`, King starts at `board.get_center_cell()` = (8, 4). Helpers: `board.is_valid_cell(cell)`, `cell_to_world`, `world_to_cell`, `edge_cells` (precomputed edge-cell list).
- Every enemy (`BaseEnemy`) exposes `current_cell`, `type` (e.g. `"ShadowPawn"`), `hp`; all enemies move in sign-step fashion toward the King's cell (`Vector2i(sign(dx), sign(dy))` steps; the Pawn randomizes one axis; the Bishop is diagonal-only, which is why it spawns on edge cells of the King's tile color).
- Every defender script implements `get_attack_tiles_for_cell(origin_cell, board) -> Array[Vector2i]` **as a pure geometric query** (occupancy ignored) — exactly what the bot needs for line-aware placement. It can be called on a bare script instance (`preload("res://scripts/rook.gd").new()`, no scene needed; free it after use).

### Logger

`GameLogger` (autoload) writes CSV + JSONL to `user://logs/`, buffers, flushes every 3 s / 100 events and on exit, and only logs between `start_run` and `end_run`. Existing helpers (⚠️ VERIFY exact parameter lists before use): `log_piece_purchased(type, cost, material_remaining)`, `log_piece_placed(type, col, row, wave_number)`, `log_enemy_killed`, `log_enemy_spawned`, `log_wave_start/end`, `log_king_life_lost`, `log_enemy_reached_king`, `log_material_earned`, `start_run(level_id)`, `end_run(outcome, waves_survived, earned, spent)`. The generic `_log_event(event_type, fields)` is **private** — Phase 5 adds a tiny public wrapper.

---

## 2. Design decisions (brief items 1 and 5)

### 2.1 Where the bot lives: **autoload**, dormant unless invoked

Create **one autoload**, `AutoplayBot` → `scripts/autoplay_bot.gd`, registered in `project.godot` `[autoload]` (additive config change; no scene files touched).

Rationale:

- The runner must **survive scene switches** (gameplay → home office → gameplay …) to implement `--runs=N` in one process. A node inside any scene is destroyed by `change_scene_to_file`, which `_finish_run()` triggers at every run end. An alternative "headless harness scene" was rejected for exactly that reason; injecting a bot node into `main.tscn` was rejected because it would touch the gameplay scene for no benefit.
- It is **completely dormant in normal play**: if no recognized auto-play arguments are present it does nothing — zero cost to the shipped game (optionally also gate on `DisplayServer.get_name() == "headless"`; see Q6).
- Activation gate: parse `OS.get_cmdline_user_args()` (the args after `--`); if no auto-play keys are present, `return` from `_ready()` before connecting anything.

### 2.2 Placement heuristic choice

The brief allows either an edge/threat-density heuristic or the simpler "nearest empty tile to the busiest enemy cluster" fallback. **Implement the full line-aware heuristic (Phase 4)**: threat corridors toward the King *plus* per-candidate attack-line coverage using the pieces' own `get_attack_tiles_for_cell`. It is genuinely feasible (pure, public geometry query; enumerable board state) and captures exactly the positional data the exercise exists to produce (diagonal-only Bishop coverage, Rook lines, radial spawn pressure). The simpler proximity fallback is documented in Phase 4.4 in case the full version misbehaves, and the bot logs which heuristic placed each piece so the data is self-describing.

### 2.3 What had to be inferred (flagged per the brief's request)

1. **"Buy" function**: no single `buy_piece()` exists — the purchase is embedded in `PlacementController.place_piece` behind UI affordance checks. The bot's `begin_tray_pointer` + `place_piece` pairing is the faithful equivalent (§1). No guessing required — read from source.
2. **Prices**: `CurrencyManager.PIECE_VALUES` (identical to shop `CATALOG`); see §1 cost note.
3. **`rush_strongest` "idle too long"**: the brief's "~2 enemy kills' worth" is underspecified because kill rewards vary (1–9 by type). Implemented as config `--rush-gap=N` (default **3** material): buy filler only while `Queen cost − current Material > N` (Phase 3.4).
4. **Forced run end** (Final Stand cap, timeout): no existing API ends a run on demand; a minimal `main.gd` hook is required — two options in Phase 7; **this is the one gameplay-file edit the user must approve**.
5. **Headless input**: mouse-event replay is impossible headless; the bot calls functions directly beneath the input layer (§1).
6. **Save-data pollution**: headless runs share the real `user://` profile — bot runs will earn Office Material, unlock levels, mark bestiary entries, record Final Stand scores; worse, **already-owned skills alter gameplay** and would contaminate balance data. The wrapper script backs up/restores `save.cfg` around the batch (Phase 8) — flagged as Q2.

---

## 3. Implementation phases

### Phase 0 — Pre-flight verification (read-only)

Before writing code, confirm the §1 signatures against the live files (the plan assumes the commit of 2026-09-27):

- [ ] `scripts/shop_ui.gd`: `CATALOG` costs and `begin_tray_pointer` still as described.
- [ ] `scripts/placement_controller.gd`: `is_valid_placement_cell`, `place_piece` still as described (it charges `CurrencyManager.get_piece_value`).
- [ ] `scripts/main.gd`: `_finish_run()` still calls `SceneRouter.go_home_office()` and `GameLogger.end_run(outcome, waves_survived, ...)`; `outcome`/`waves_survived` are plain public vars.
- [ ] `scripts/wave_manager.gd`: `level_completed` still emitted on wave overrun; `get_wave_number()` exists; `start_automatically` default `true`.
- [ ] `scripts/game_logger.gd`: event helper signatures; `_log_event(event_type, fields)` private; `LOGGING_ENABLED = true`.
- [ ] `scripts/base_enemy.gd`: `current_cell`, `type` public; enemy `_process` still guards on `game.game_over`.
- [ ] `project.godot` `[autoload]` list (to know where `AutoplayBot=` gets appended).
- [ ] Nothing in the game currently reads `OS.get_cmdline_user_args()`.

### Phase 1 — Autoload skeleton + argument parsing

Create `scripts/autoplay_bot.gd`, register in `project.godot` as:

```ini
AutoplayBot="*res://scripts/autoplay_bot.gd"
```

Behavior:

```gdscript
extends Node

const STRATEGIES := ["cheapest_first", "balanced", "rush_strongest", "random"]
const DEFAULTS := {
    "strategy": "balanced",
    "level": "level_1",
    "runs": 1,
    "decision-interval": 0.5,
    "timeout-seconds": 600.0,   # hard per-run timeout, real seconds
    "final-stand-cap": 30,      # wave at which Final Stand runs are force-ended
    "rush-gap": 3,              # rush_strongest filler threshold, in Material
    "seed": -1,                 # -1 = leave RNG alone; >= 0 → seed()
    "time-scale": 1.0,          # optional speed-up; runtime-only
}

var active := false
var config := {}

func _ready() -> void:
    config = _parse_args(OS.get_cmdline_user_args())
    if config.is_empty():          # no auto-play args → dormant forever
        set_process(false)
        return
    active = true
    if config["seed"] >= 0:
        seed(config["seed"])
    Engine.time_scale = config["time-scale"]
    _start_batch.call_deferred()   # let the title scene load first, then take over
```

Parsing rules: accept `--key=value` and bare `--key` tokens after `--`; unknown keys are ignored (log a warning); invalid values fall back to `DEFAULTS` with a warning printed via `push_warning` (visible in headless stdout). Strategy/level names are validated against `STRATEGIES` and `LevelProgressManager.LEVEL_CONFIGS.keys()`.

Example invocation:

```bash
godot --headless --path /path/to/chess-defense -- --strategy=cheapest_first --level=level_3 --runs=50
```

### Phase 2 — Session binding and the action primitive

The autoload watches `get_tree().current_scene` (cheap identity check per frame: compare the scene's script path). When it becomes `main.tscn` (`main.gd`), bind references and start the run clock; when it stops being `main.tscn`, the run is over (see Phase 6).

```gdscript
var game: Node = null

func _process(delta: float) -> void:
    if not active:
        return
    _update_session_binding()
    _check_run_timeout()
    if game == null or game.game_over:
        return
    _decision_timer += delta
    if _decision_timer >= config["decision-interval"]:
        _decision_timer = 0.0
        _act()
```

`_update_session_binding()`: if `current_scene` has script `main.gd`, set `game = current_scene` (grab `wave_manager`, `shop_ui`, `placement_controller`, `board`, `king` lazily from it — they are all public `@onready` vars). If the previously bound scene is no longer valid (`not is_instance_valid(game)` or the scene changed), clear `game` so the batch loop's await resumes.

`_act()` = one decision tick:

1. `piece_type := _choose_piece_to_buy()` → `""` if nothing to buy.
2. If empty → `_handle_idle()` (Phase 5) and return.
3. `cell := _choose_cell(piece_type)` → `Vector2i(-999, -999)` if no legal cell.
4. If no legal cell → `_handle_idle()` and return.
5. Else: `game.shop_ui.begin_tray_pointer(piece_type)` then, **only if** `game.placement_controller.active_piece_type == piece_type` (i.e. selection actually started — affordability gate passed), call `game.placement_controller.place_piece(cell)` and log a `bot_placed` event (Phase 5) with strategy, piece type, cell, and heuristic name. Reset the idle streak.

This ordering matters: `begin_tray_pointer` silently no-ops if unaffordable; checking `active_piece_type` afterward prevents the bot from ever assuming a purchase happened. `place_piece` itself re-validates and re-checks currency, so a race (currency spent between selection and placement) degrades gracefully — exactly like a human whose pending piece became unaffordable.

### Phase 3 — Buying strategies

Shared helper:

```gdscript
const PIECE_TYPES := ["Pawn", "Knight", "Bishop", "Rook", "Queen"]

func _affordable_types() -> Array[String]:
    var result: Array[String] = []
    for t in PIECE_TYPES:
        if CurrencyManager.current_amount >= CurrencyManager.get_piece_value(t):
            result.append(t)
    return result
```

`_choose_piece_to_buy()` dispatches on `config["strategy"]`. All four return `""` when `_affordable_types()` is empty.

**3.1 `cheapest_first`** — among affordable, minimal `get_piece_value(t)`; tie-break (Knight vs Bishop, both 3) → fixed order in `PIECE_TYPES` (Knight). No randomness, so runs are comparable.

**3.2 `balanced`** — among affordable, pick the type with the lowest `InventoryManager.get_piece_count(t)` (the same counter the game already maintains and the HUD shows); tie-break by lower cost, then by `PIECE_TYPES` order. This yields an even piece distribution.

**3.3 `random`** — `_affordable_types().pick_random()`.

**3.4 `rush_strongest`** — target = Queen (cost 9, the most expensive piece):

```gdscript
const STRONGEST := "Queen"
var gap := CurrencyManager.get_piece_value(STRONGEST) - CurrencyManager.current_amount
if gap <= 0:
    return STRONGEST                  # buy the strongest
if gap <= config["rush-gap"]:
    return ""                         # close enough — hold Material for the Queen
var fillers := _affordable_types()     # else buy cheapest filler, if any
if fillers.is_empty():
    return ""
fillers.sort_custom(func(a, b): return CurrencyManager.get_piece_value(a) < CurrencyManager.get_piece_value(b))
return fillers[0]
```

Default `--rush-gap=3` ≈ "the Queen is more than ~2 typical early kills away, so keep Material working instead of hoarding" (see §2.3 item 3 — this interpretation is a flagged assumption).

### Phase 4 — Placement heuristic (line-aware)

Reads public state only; nothing is mutated until the chosen cell is passed to `place_piece`.

**4.1 Threat map (recomputed each decision tick; ≤ 17×9 = 153 cells, cheap).**

- For every alive enemy in `game.enemies.get_children()`: add weight **3** to its `current_cell` (an enemy is standing there now).
- Walk each enemy's **corridor** toward the King using the same sign-step rule the enemy movement code uses (`Vector2i(sign(dx), sign(dy))`, one cell at a time, stopping at the King's cell); add weight **1** to each corridor cell (a near-future enemy position). Pawn's axis randomization and Knight's jump are approximated by this straight-line walk — acceptable for threat estimation; note it in the final report.
- This one map encodes both brief notions: per-edge radial spawn pressure (corridors are dense where spawns press in) and the "busy enemy cluster" (weights are highest where enemies currently are).

**4.2 Candidate scoring.** For each cell where `game.placement_controller.is_valid_placement_cell(cell)` is true, for the piece type about to be bought:

```text
score(cell) = Σ over attack_tiles = prototype.get_attack_tiles_for_cell(cell, board):
                 + threat_weight[attack_tile]           # line through live enemies or corridors
             + 0.25 × threat_weight[cell]               # slight preference to stand near the threat
             − 0.05 × chebyshev_distance(cell, king_cell)  # slight preference to stay near the King
```

Get attack tiles from bare script instances created once per batch (never added to the tree, freed in `_exit_tree`): `var _prototypes := { "Pawn": preload("res://scripts/pawn.gd").new(), ... }`. Bishop/Rook/Knight/Queen geometry then automatically differs per candidate cell, which implements the brief's line-optimization nuance (diagonal-only Bishop coverage, Rook lines, etc.).

Pick the argmax; tie-break randomly among ties (so runs don't always place everything on one square).

**4.3 Empty-threat fallback** (between waves, no enemies alive): choose among legal cells by maximizing the count of `get_attack_tiles_for_cell` at Chebyshev distance 1–2 from the King (coverage-first formation), and log `heuristic=coverage_fallback`.

**4.4 Documented simpler fallback** (only if 4.1–4.3 prove buggy): nearest legal empty cell to the centroid of alive enemies, or to the King when none. If used, log `heuristic=proximity` so the data is separable.

### Phase 5 — Bot events + `bot_idle`

Add **one** public wrapper to `scripts/game_logger.gd` (additive; flagged per the contract):

```gdscript
## Generic event hook for auxiliary systems (e.g. AutoplayBot). Fields appear fully in JSONL;
## only fields matching known CSV columns are also written to CSV.
func log_bot_event(event_type: String, fields: Dictionary = {}) -> void:
    _log_event(event_type, fields)
```

Bot events (all via `GameLogger.log_bot_event`, landing in the same per-run files under the same `run_id`):

- `bot_placed` — `{strategy, piece_type, col, row, wave_number, heuristic}` after each successful placement (the game's own `piece_purchased`/`piece_placed` events still fire from `place_piece` — do not duplicate them).
- `bot_idle` — when a decision tick finds no action, `{consecutive_idle_ticks, material, pieces_on_board}`. Emit once per idle *streak* and then every further 20 ticks (≈10 s at default cadence), so a stuck run is visible without flooding the log.
- `run_timeout` — from the timeout handler (Phase 7), `{seconds, wave_number, material}`.
- `bot_run_capped` — when Final Stand hits the wave cap (Phase 7), `{wave_number}`.

Note for the analysis pipeline: bot events carry custom fields, so they are fully present in the JSONL; in the fixed-schema CSV only matching columns are populated — **JSONL is the authoritative source for bot events**.

### Phase 6 — Multi-run loop (`--runs=N`) and clean exit

`_start_batch()` (deferred from `_ready`) is the batch driver; the per-frame `_process` from Phase 2 does binding, decisions, and timeouts:

```gdscript
func _start_batch() -> void:
    await get_tree().process_frame          # let the title scene finish loading first
    for _run_number in range(config["runs"]):
        _run_started_msec = Time.get_ticks_msec()
        _scene_left_gameplay = false
        SceneRouter.start_level(config["level"])
        # Wait until the gameplay scene appears (scene may take a few frames)…
        await _wait_for(func(): game != null, 30.0)
        # …then wait until the run ends (gameplay scene replaced by home office
        # by main._finish_run → SceneRouter.go_home_office()).
        await _wait_for(func(): _scene_left_gameplay, config["timeout-seconds"] + 30.0)
    GameLogger.flush()
    get_tree().quit()
```

- `_wait_for(predicate, seconds)` = loop of `await get_tree().process_frame` with a wall-clock deadline (`Time.get_ticks_msec`); on deadline expiry it returns `false` and the driver continues (a run that never even started is skipped, logged via `log_bot_event("run_timeout", {...})` — this also covers the "scene never appeared" case).
- `_scene_left_gameplay` is set in `_update_session_binding()` when the previously bound `game` instance is no longer the current scene (or freed) — that is the additive "run finished" detector, riding on the existing `SceneRouter.go_home_office()` call in `_finish_run()`.
- Each iteration re-enters `main.tscn` via the real `SceneRouter.start_level`, so the per-run reset is the game's own (`main._ready`), and each run automatically gets a distinct `run_id` and log files from `GameLogger.start_run()` — satisfying the brief's requirement.
- After all N runs: flush and `get_tree().quit()` so shell scripts can loop on exit code.

### Phase 7 — Final Stand wave cap + per-run hard timeout (the one gameplay-file hook)

Both features need to end a run **on demand**, which no existing API does. Present these options to the user (Q3/Q4) and implement the approved one:

**Option A (preferred, tiny additive method on `scripts/main.gd`):**

```gdscript
## Ends the run early with an explicit result (used by AutoplayBot for wave caps
## and timeouts). Additive; identical to the natural loss path except the result label.
func end_run_with_result(result: String) -> void:
    if game_over:
        return
    outcome = result
    waves_survived = wave_manager.current_wave_index
    end_game()
```

This reuses `end_game()` → `_finish_run()` unchanged (record Final Stand score, convert material, return to hub, `GameLogger.end_run`), and mirrors exactly what `enemy_reached_king` does before calling `end_game()` — no new state, no new flow.

**Option B (zero gameplay-file edits):** the bot sets `game.outcome`, `game.waves_survived` itself and calls `game.end_game()` directly. Functionally identical, but reaches into `main.gd`'s result fields from outside, which is uglier for logging provenance.

Then, in `AutoplayBot._process` (checked every frame, not just on decision ticks):

- **Wave cap**: if `config["level"] == "final_stand"` and `game.wave_manager.get_wave_number() >= config["final-stand-cap"]` → `GameLogger.log_bot_event("bot_run_capped", {wave_number})` → `game.end_run_with_result("WIN")` (Option A) or the Option B equivalent. Note: with cap 30, Final Stand high score will record 29 waves survived (`current_wave_index`), and the run's `outcome` in logs will be `"WIN"` — a capped win is distinguished from a natural win by the `bot_run_capped` event. Flag this labeling to the user (Q4).
- **Timeout**: if `Time.get_ticks_msec() - _run_started_msec > config["timeout-seconds"] * 1000` and the run is still in the gameplay scene → `GameLogger.log_bot_event("run_timeout", {seconds, wave_number, material})` → force-end the same way with result `"TIMEOUT"`. If the gameplay scene never appeared at all, the `_wait_for` deadline in Phase 6 skips the run.

Both outcomes (`WIN`-capped, `TIMEOUT`) flow through `_finish_run`'s integrity check fine (`waves_survived = current_wave_index >= 0`; `outcome` non-empty).

### Phase 8 — Wrapper shell script

Create `tools/run_autoplay_batch.sh` (bash, executable). One command → full 4 strategies × 6 levels pass:

```bash
#!/usr/bin/env bash
# Full auto-play data-generation pass. Usage:
#   GODOT_BIN=/path/to/godot RUNS=10 ./tools/run_autoplay_batch.sh
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"           # e.g. /Applications/Godot.app/Contents/MacOS/Godot
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${RUNS:-10}"                        # runs per strategy × level combination
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
FINAL_STAND_CAP="${FINAL_STAND_CAP:-30}"
CAPTURE_DIR="${CAPTURE_DIR:-$PROJECT_DIR/data-captures/$(date +%Y%m%d_%H%M%S)}"

STRATEGIES=(cheapest_first balanced rush_strongest random)
LEVELS=(level_1 level_2 level_3 level_4 level_5 final_stand)

# --- Save-data hygiene (see §2.3 item 6 / Q2) --------------------------------
USER_DIR="$HOME/Library/Application Support/Godot/app_userdata/ChessDefense"
SAVE_FILE="$USER_DIR/save.cfg"
BACKUP=""
if [[ -f "$SAVE_FILE" ]]; then
    BACKUP="$SAVE_FILE.pre-autoplay.bak"
    cp "$SAVE_FILE" "$BACKUP"
    echo "Backed up save.cfg → $BACKUP (bot runs would otherwise pollute it)"
fi
trap '[[ -n "$BACKUP" ]] && mv "$BACKUP" "$SAVE_FILE" && echo "Restored original save.cfg"' EXIT

mkdir -p "$CAPTURE_DIR"
echo "Capturing logs to $CAPTURE_DIR"

for strategy in "${STRATEGIES[@]}"; do
    for level in "${LEVELS[@]}"; do
        echo "=== strategy=$strategy level=$level runs=$RUNS ==="
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- \
            --strategy="$strategy" --level="$level" --runs="$RUNS" \
            --timeout-seconds="$TIMEOUT_SECONDS" --final-stand-cap="$FINAL_STAND_CAP"
        # Archive this combination's fresh logs (files are named by run timestamp).
        cp "$USER_DIR/logs/"*.{csv,jsonl} "$CAPTURE_DIR"/ 2>/dev/null || true
    done
done

echo "Done. $RUNS runs × ${#STRATEGIES[@]} strategies × ${#LEVELS[@]} levels."
echo "Logs archived in $CAPTURE_DIR (original files remain in $USER_DIR/logs)."
```

Notes for the implementing agent:

- The `user://` path differs per OS; on this machine (macOS) it is the `USER_DIR` above — verify with `OS.get_user_data_dir()` printed once, or resolve the path by running a tiny headless one-liner if unsure. Keep the script macOS-first (the dev's platform) but structure it so `USER_DIR` is a variable.
- The save backup/restore is deliberate (§2.3 item 6): skills in the dev's own save would silently change bot-run gameplay, and bot runs would corrupt the dev's meta progression. The `trap … EXIT` guarantees restore even on Ctrl-C. Flag prominently in the report and in the script header.
- Log archiving: `GameLogger` names files per run timestamp under `user://logs/`; after each combination, copy new files into the capture dir so per-combo buckets are identifiable (either keep `cp` per-combination, or prefix copied names with the strategy/level — prefixing is nicer for analysis; implement with `cp ... "$CAPTURE_DIR/${strategy}_${level}_$(basename ...)"`).
- Sequential (not parallel) combinations keep CPU sane and logs unambiguous; parallelism is a future optimization, not in scope.

### Phase 9 — Validation plan (acceptance criteria)

Run these in order; each must pass before the next:

1. **Dormancy test** — launch normally (non-headless, no args) and headless without auto-play args: game behaves exactly as before; `AutoplayBot` logs nothing and takes no action. Confirm `project.godot` diff is only the one autoload line.
2. **Single-run smoke** — `godot --headless --path . -- --strategy=cheapest_first --level=level_1 --runs=1 --timeout-seconds=120`. Expect: pieces get bought and placed (stdout shows warnings/errors only, none fatal); process exits by itself; two fresh log files under `user://logs/` for one new `run_id`; CSV contains `piece_purchased`/`piece_placed` rows; JSONL contains `bot_placed` rows with the chosen heuristic.
3. **Strategy sanity** — repeat with each of the four strategies, `--runs=2`. In the JSONL, verify the piece-type distribution matches expectations: `cheapest_first` buys almost only Pawns (and Knights/Bishops at equal cost per tie-break); `balanced` spreads types; `rush_strongest` buys Queens once ≥9 and fillers otherwise; `random` is mixed. (⚠️ expect a `cheapest_first` anomaly on levels ≥ wave 5 — see §5 Q1, the pawn→Queen promotion hack.)
4. **Idle + timeout test** — e.g. `--strategy=rush_strongest --level=level_1 --timeout-seconds=60` (early game can't afford anything for stretches): verify `bot_idle` events appear but runs still complete naturally; separately, temporarily set an absurdly low `--final-stand-cap=2` and verify a `final_stand` run force-ends with `bot_run_capped` + a clean next-run/exit.
5. **Multi-run integrity** — `--runs=5` on one launch: exactly 5 `run_id`s, 5 pairs of log files, no bleed-over of currency/pieces between runs (check `material_remaining` at run starts ≈ 5).
6. **Batch dry run** — run the wrapper with `RUNS=1` end-to-end; verify save.cfg restored byte-identical afterwards (compare checksum before/after), capture dir populated, exit code 0.
7. **Report** — summarize: which heuristic shipped (4.2 vs 4.4), the exact two gameplay-file edits (Phase 5 + Phase 7 option chosen), any warnings observed, and the answers to §5 questions if the user supplied them.

### Phase 10 — Documentation

Append a short section to `tasks/ARCHITECTURE_NOTES.md` describing `AutoplayBot` (dormant autoload, CLI contract, its events) so future work doesn't accidentally interact with it, and note the wrapper script and capture directory convention. Do not update the stale README as part of this task (separate task).

---

## 4. Suggested build order (one PR-able unit per step)

1. Phase 1 (autoload + parsing) → 2 (binding + `_act` with a temporary "cheapest affordable, random legal cell" stand-in) → **validate Phase 9.1–9.2**.
2. Phase 3 (four strategies) — placement still stand-in → **validate 9.3**.
3. Phase 4 (placement heuristic) → **re-validate 9.3 with line-aware placements** (spot-check that Bishops end up on diagonals through spawn corridors and Rooks on files/ranks through them).
4. Phase 5 (bot events) + Phase 7 (forced-run-end hook + cap + timeout) → **validate 9.4**.
5. Phase 6 (multi-run loop) → **validate 9.5**.
6. Phase 8 (wrapper) → **validate 9.6**, then Phase 10 docs, then **stop and report** (Phase 9.7).

The implementing agent should pause for user answers to §5 Q1–Q4 **before Phase 7** and before any large data-generation pass.

---

## 5. Questions requiring user confirmation

**Q1 — Pawn promotion test hook (data-validity blocker, decide before generating data).** `pawn.gd::_process` promotes every Pawn into a Queen once `wave_manager.current_wave_index >= 4` (a leftover test scaffold). In any run reaching wave 5, "cheapest_first" will field free Queens, which will distort strategy-comparison data. Options: (a) leave it — data reflects the game as it currently is; (b) the user removes/gates the hack first (a gameplay change, done by the user or with their explicit approval, *not* silently by the agent). The bot must not work around it in code.

A: The queen promotion has been commented out for now.

**Q2 — Save pollution.** Headless runs share the real `user://` profile (skills owned by the dev alter gameplay; bot runs mutate office material / unlocks / bestiary / high scores). The wrapper backs up and restores `save.cfg` around each batch (Phase 8). Confirm this is acceptable, or say if you'd rather point auto-play at a separate profile permanently.

A: The `save.cfg` has been removed and please create a new saved data file.

**Q3 — Forced-run-end hook (Option A vs B, Phase 7).** Option A adds a 5-line additive method `end_run_with_result(result)` to `main.gd`; Option B touches no gameplay file but has the bot poke `outcome`/`waves_survived` directly. Which do you prefer? (Recommendation: A.)

A: Option A, but make sure this function is only used for the autoplay bot and NEVER used in the actual game play logic.

**Q4 — Outcome labeling.** Wave-capped Final Stand runs will be logged with outcome `WIN` plus a distinguishing `bot_run_capped` event, and timeouts as `TIMEOUT` (a value the current `end_run` schema has never produced). OK, or would you like different labels (e.g. `WAVE_CAP`)? Any downstream analysis should be told either way.

A: The current plan sounds good to me.

**Q5 — `rush-gap` default.** Default filler threshold 3 Material for `rush_strongest` (interpretation of "~2 enemy kills" per §2.3). Keep 3, or specify another number?

A: Keep 3 please.

**Q6 — Activation gate.** Auto-play activates on CLI args alone, or additionally require `DisplayServer.get_name() == "headless"` (recommended: args **and** headless, so a stray flag can never hijack a real play session)?

A: I will take the recomendded approach

**Q7 — Optional extras, include or skip?** (a) `--time-scale` speed-up (default 1.0 — data stays real-time-representative unless you opt in); (b) `--seed` for reproducible runs; (c) wrapper log-archiving prefixes. All are cheap; say which you want.

A: Please leave an option to speed up the run and set the default to 16.0. Good to record the seed. 

---

## 6. Deliverables checklist

```text
scripts/autoplay_bot.gd        (new, autoload)
project.godot                  (+1 autoload line, additive)
scripts/game_logger.gd         (+log_bot_event, additive, flagged)
scripts/main.gd                (+end_run_with_result, additive, flagged — pending Q3)
tools/run_autoplay_batch.sh    (new, executable)
data-captures/                 (gitignore-worthy output dir)
tasks/ARCHITECTURE_NOTES.md    (appended AutoplayBot section)
```

No other file is modified. No gameplay, balance, wave, enemy, placement, currency, or logging behavior changes.








