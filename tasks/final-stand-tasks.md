# Final Stand (Infinite Level) — Implementation Plan

- **Source brief:** `tasks/final-stand-brief.md`
- **Plan written:** 2026-10-23, against commit `4c701c6` ("Simplied .gitignore", branch `main`)
- **Status:** PLAN ONLY — no code has been changed. The implementing agent must re-verify every claim below against the live commit before editing (Stage 0), and must send the user the code summary the brief demands **before any edit**.

---

## 0. How to use this plan

The brief has two hard process requirements the implementing agent must honor:

1. **"Before changing anything, send me a brief summary of what you found"** → Section 1 below IS that summary, pre-verified against the code. Stage 0 sends it to the user (plus answers/open questions) and waits for confirmation.
2. **"Tell me before changing existing behavior to resolve a conflict"** → Section 3 lists every conflict found. **Q1 is blocking**: the brief's own extrapolation rule produces *flat* difficulty (see D2), which contradicts the brief's "difficulty keeps growing". No wave-generation code may be written until the user picks Option A/B/C.

Stages 1→2 and 3→4 also end in 🛑 STOP gates, because each changes behavior the player can feel.

---

## 1. Verified current state (the summary to send the user)

### 1.1 Level config system (`scripts/level_config.gd`, `resources/levels/*.tres`)

- `LevelConfig` is an editor-authored **data-only** Resource: `level_id`, `display_name`, `allowed_enemy_pieces`, `wave_count`, `wave_resources: Array[WaveConfig]`, plus a difficulty curve: `base_wave_duration` (default 20), `wave_duration_increment` (default 10), `maximum_wave_duration` (default 100), `base_spawn_interval` (default 8), `spawn_interval_reduction` (default 1), `minimum_spawn_interval` (default 1).
- `wave_count == -1` **already means infinite** (`is_infinite()`), which is the convention the brief asks for. `final_stand.tres` already uses it.
- **Important:** the curve is *stateful*. `WaveManager.configure_level()` calls `level_config.setup()` (reset to base values), then for each wave resource calls `wave.configure_wave(current duration, current interval)` followed by `increase_wave_duration()` / `decrease_spawn_interval()`. This **overwrites the `duration`/`spawn_interval` values stored in every `wave_*.tres`** — the authored numbers in the wave files are dead data; only the roster booleans (`shadow_*`) are honored. Any Final Stand work must respect this or it will "restore" values that were never in effect.
- `duplicate_with_waves()` deep-copies the config + wave resources at run start, so levels share read-only `.tres` safely (Level 5 and Final Stand can reference the *same* `wave_*.tres` files without cross-contamination).

### 1.2 Wave system / spawner (`scripts/wave_manager.gd`, `scripts/wave_config.gd`)

- Finite levels: waves pre-populated from `wave_resources` (auto-generated from the curve only if the list is empty).
- Infinite levels (Final Stand): `configure_level()` skips pre-population; `start_new_wave()` **appends one generated wave on demand** when `current_wave_index >= waves.size()` — the "generate as you go" pattern the brief wants already exists in skeleton form.
- **But the generated wave is wrong in two ways** (see D1): its roster is `allowed_enemy_pieces` (all 5 types, uniform random pick at spawn — includes Pawn, unlike Level 5's late waves), and its timing comes from the *mutated running state*, not from a formula of the wave number.
- Waves are back-to-back with **no pause and no lull/trough timing anywhere in the code**: a wave ends when its duration has expired **and** all enemies are cleared (`_try_end_cleared_wave`, plus a `_process` safety poll), then the next wave starts the same frame.
- **There is no special "Check!" King event** in the codebase (grep-verified: no such event; no `shadow_king` in any level roster — the King enemy scene exists but is unused by Level 5 and Final Stand). The brief's "keep any special events (such as the enemy King 'Check!' event)" has nothing to preserve — flagged as Q3.
- Debug tooling: exported `debug_mode` + `debug_start_wave` (scene property, editor-set only, `@export_range(1, 100, 1)`, Z/X/C keys). **Starting an infinite level at a high wave does not fast-forward the curve** — the first generated wave gets wave-1 parameters, so starting at wave 100 today plays a 60s / 8s-interval wave. This blocks the brief's verification item 4.
- `get_total_wave_number()` returns `waves.size()`, which **grows** for Final Stand as waves are appended.


### 1.3 HUD wave banner (`scenes/main.tscn`, `scripts/main.gd`)

- HUD label (`%WaveLabel`, Cinzel-Medium 24): `"Wave  %d / %d"` (two spaces, spaces around `/`), filled by `update_hud()` from `wave_manager.get_current_wave_number()` and `max_waves = get_total_wave_number()`.
- **Bug today:** for Final Stand the denominator grows with play, so it shows nonsense like `Wave 6 / 6` → `Wave 7 / 7`.
- Big center banner (`WaveBanner`, Cinzel-SemiBold): `"WAVE %d"` — wave number only, no total, no change needed.
- **∞ glyph verified:** direct cmap parsing of all shipped fonts confirms **U+221E is present in Cinzel-Medium, Cinzel-SemiBold, Lora-Regular, and Lora-Medium** — the exact fonts the HUD and Level Select use. Level Select already renders a literal `"∞"` (Lora-Regular, `%WaveNum`) for Final Stand today. No fallback font or texture is needed; the plan keeps one cheap runtime `has_character()` assertion as a guard (Stage 3).

### 1.4 Run end, score, rewards (`scripts/main.gd`, `scripts/run_reward_manager.gd`)

- **No win condition for infinite levels exists today** — `start_new_wave()` only emits `level_completed` when the wave list runs out, which never happens for Final Stand. The only natural end is lives → 0: `outcome = "LOSE"`, `waves_survived = wave_manager.current_wave_index`, then `end_game()`.
- `end_run_with_result()` ends runs early for the AutoplayBot (cap/timeout) and the pause menu ("ABANDONED") — all paths funnel into one `_finish_run()`.
- `_finish_run()` already: records the Final Stand score (`LevelProgressManager.record_final_stand_score(wave_manager.get_waves_survived())` when `is_infinite()`), runs the material conversion (`RunRewardManager.finish_run()` — **reused, exactly as the brief demands; no new currency logic needed**), logs (`GameLogger.end_run`), and opens the result overlay exactly once.
- **Score semantics (D3):** `get_waves_survived()` returns `max(0, current_wave_index)` = the 0-based index = **completed-waves count**, i.e. *started − 1*. The brief defines best score as "highest wave number that **started**". These differ by 1 (dying during wave 3 records 2 today; the brief wants 3).

### 1.5 Save / unlock (`scripts/level_progress_manager.gd`)

- `final_stand_high_score` persists in `SaveData` section `level_progress`, loaded in `_ready()`, written by `record_final_stand_score()` (only if greater). The save plumbing the brief asks for **already exists**.
- **Unlock logic is already correct** (D6): `complete_level("level_5")` unlocks the next entry in `LEVEL_ORDER`, which is `final_stand`; `complete_level` deliberately ignores `"final_stand"` itself. Nothing to fix — only verify.

### 1.6 Level Select (`scripts/level_select.gd`)

- `_config_level_details()` shows title, wave count (`"∞"` for Final Stand — already implemented), enemy list, and a status label `Complete`/`Incomplete`. For Final Stand the status is **always "Incomplete"** — the best score is never shown, despite commented-out code at lines 190–198 showing the intended `"Best: %d waves"` format.
- Adjacent latent bug (fix opportunity while touching this function — ask user first): `start_button.pressed.connect(...)` is called on **every** level selection without disconnecting, so listeners accumulate and the Start button eventually fires multiple times per press.

### 1.7 Result overlay (`scripts/result_overlay.gd`)

- Shows `"YOU " + outcome` and `"Materials earned: %d points"`. **No waves-reached line exists** — the brief's "show waves reached on the run-end screen" is new work (Stage 4).

### 1.8 Logger (`scripts/game_logger.gd`)

- `start_run` (per-run CSV+JSONL under `user://logs/`), `log_wave_start`, `log_wave_end`, `end_run(outcome, waves_survived, earned, spent)` all fire for **every** level including Final Stand today, via `WaveManager`/`main.gd` code paths that are level-agnostic. Final Stand needs no new logging — only the semantics decision in D3.

### 1.9 Autoplay bot (`scripts/autoplay_bot.gd`)

- **The brief's optional wave cap already exists** (D5): `--final-stand-cap N` (default 30) ends Final Stand bot runs via `end_run_with_result("WIN")` + a `bot_run_capped` event (distinguished from natural wins). Applies to bot runs only, never normal play. Nothing to build — verify and document only.

---

## 2. Level 5's exact wave table (evidence for the reproduction + extrapolation)

Reconstructed from `resources/levels/level_5.tres` (`wave_resources = [w1, w1, w2, w3, w4, w4, w5, w5]`, curve: base 60 / +10 / cap 100; base interval 8 / −3 / floor 1.0) and the stepping in `configure_level()` (§1.1). Roster abbreviations: P=Pawn, B=Bishop, K=Knight, R=Rook, Q=Queen. "~Enemies/wave" ≈ duration ÷ interval (one random-roster spawn per interval).

| Wave | Roster | Duration (s) | Spawn interval (s) | ~Enemies/wave |
|---|---|---|---|---|
| 1 | P | 60 | 8.0 | 8 |
| 2 | P | 70 | 5.0 | 14 |
| 3 | P+B | 80 | 2.0 | 40 |
| 4 | P+B+K | 90 | 1.0 | 90 |
| 5 | K+B+R | 100 | 1.0 | 100 |
| 6 | K+B+R | 100 | 1.0 | 100 |
| 7 | K+B+R+Q | 100 | 1.0 | 100 |
| 8 | K+B+R+Q | 100 | 1.0 | 100 |

**Read the saturation clearly (this drives D2):** duration hits its 100s cap at wave 5, spawn interval hits its 1.0s floor at wave 4, and the roster reaches its final mix at wave 7. Over Level 5's last three waves the per-wave delta is **0 on every axis**.

Final Stand's *current* behavior for comparison (what must be replaced): every wave has roster P+B+K+R+Q and interval 60/8 → 70/5 → 80/2 → 90/**0.5** → 100/0.5 forever — it diverges from Level 5 at wave 4 (interval floor 0.5 vs 1.0) and never matches the roster table at any wave.

---

## 3. Conflicts with the brief & decisions needed

### D1 — Final Stand does not reproduce Level 5 (brief item 1) — CONFIRMED GAP

Roster and wave-4 interval both diverge (§2). Fix direction is settled: Final Stand must use Level 5's authored wave table for waves 1–8 by **referencing the same `wave_*.tres` resources** in `final_stand.tres` (safe: runtime deep-copies, §1.1) and copying Level 5's curve parameters so the stepping reproduces identical timing. Not a question — part of the design.

### D2 — "Continue the growth trend" vs. a curve that has already saturated — BLOCKING (Q1)

The brief's two requirements conflict with each other given the code:

- Extrapolation rule ("continue the same formula" / "average change over its last few waves") → the last waves change by **0 on every axis** → waves 9+ would be **identical to wave 8 forever**.
- "After Level 5's last wave, difficulty keeps growing" → impossible without either extending an existing axis below Level 5's floor, or adding a new axis (forbidden: "do not invent a new scaling system").

Options (decision needed before Stage 2):

- **Option A — strict extrapolation.** Waves 9+ = wave 8 forever (100s, 1.0s interval, K+B+R+Q). Mathematically faithful to "the same formula"; difficulty plateaus immediately. Risk: boring; the brief's "growing" intent is unmet.
- **Option B — extend the interval axis to Final Stand's own floor (RECOMMENDED).** The project already contains the hook: `final_stand.tres` was authored with `minimum_spawn_interval = 0.5` (vs Level 5's 1.0), i.e. the original author's evident intent was that Final Stand keeps ramping spawn rate past Level 5's floor. Waves 1–8 stay pinned to Level 5's exact values (floor 1.0 through wave 8); from wave 9 the interval continues the same −3.0/wave slope down to the 0.5 floor: wave 9 → 0.5, waves 10+ → 0.5 (~200 enemies/wave vs 100). One extra difficulty step, then a plateau at the floor. Note: the 1.0 → 0.5 step at the handoff is the same magnitude of jump the formula already makes between waves 2→3 (5.0 → 2.0); the brief's "no sudden jumps at the handoff point" is satisfied in the sense that no *new* rule appears at the handoff — the same slope simply continues — but the user should sign off on the visible step.

- **Option C — new growth axis (per-wave enemy stat multipliers or weighted rosters).** Genuinely unbounded growth, but it is exactly the "new scaling system with unrelated numbers" the brief forbids. Only pursue if the user explicitly overrides that clause.

Whichever option is chosen, the growth tunables and floors must live in `final_stand.tres`/`LevelConfig` (new exported fields, Stage 2), never in `if level_id == "final_stand"` code checks.

### D3 — Best-score semantics: "reached" vs "completed" (brief item 3) — Q2

The code distinguishes them (§1.4): `waves_survived` = completed waves = started − 1. The brief defines the best score as the highest wave **started**. Recommendation: follow the brief — record `wave_manager.get_current_wave_number()` (started) as the Final Stand best score, i.e. dying in wave 1 records Best: Wave 1 (today it records nothing). Keep `waves_survived` (completed) in the `run_end` log as-is to avoid breaking the existing log schema; optionally add an additive `waves_reached` field to `run_end`. Needs user confirmation because it changes the meaning of an existing saved number (a player's existing best would appear to jump by 1 on the next run).

### D4 — Non-natural run ends also record the best score — Q2 (same answer)

Pause-menu "ABANDONED" and bot TIMEOUT/cap runs all flow through `_finish_run()` and therefore record the Final Stand best score today. Reasonable for players (highest wave reached counts, however the run ended), but **bot batch runs would contaminate the player's real save** — the headless-autoplay wrapper already backs up/restores `user://` around batches; Stage 4 adds a note + optional guard so this can't surprise anyone.

### D5 — Brief item 5 (bot wave cap): already implemented

`--final-stand-cap` exists (§1.9). Stage 6 only re-verifies it with the new wave system.

### D6 — Brief item 4 (unlock): already correct

Win Level 5 → `complete_level("level_5")` → unlocks `final_stand` (§1.5). Stage 6 only re-verifies.

### D7 — HUD wave label is broken for Final Stand today

`Wave N / N` with a growing denominator (§1.3). Fixed as part of the banner work (Stage 3) — no decision needed, but it means the label's current Final Stand text *will* change (to `Wave  N / ∞`), which is exactly what the brief asks for.

### D8 — No "Check!" King event exists (brief item 1, "special events")

The brief says to preserve "any lull/trough timing and special events (such as the enemy King 'Check!' event) that Level 5 uses" — **Level 5 uses none** (§1.2). Nothing to extend; confirm with the user that this was boilerplate, not a feature request (Q3).

---

## 4. Proposed extrapolation method + preview table (brief "want back" #3)

**Method (Option B; regenerate this table if A or C is chosen):** waves are a pure function of the wave number `n` — no running state, no unbounded precompute:

- `duration(n) = min(60 + 10·(n−1), 100)` — Level 5's formula, unchanged, for all n.
- `interval(n) = max(8 − 3·(n−1), floor(n))` where `floor(n) = 1.0` for n ≤ 8 (Level 5's floor, pinning waves 1–8 exactly) and `0.5` for n ≥ 9 (Final Stand's extended floor, a new exported config field).
- `roster(n)` = the authored `wave_resources` table entry for n ≤ 8; for n ≥ 9 the last entry (K+B+R+Q) continued — the roster trend's own limit (mix already maximal).
- All parameters (`base_wave_duration`, `wave_duration_increment`, `maximum_wave_duration`, `base_spawn_interval`, `spawn_interval_reduction`, `minimum_spawn_interval`, new `extended_minimum_spawn_interval`) are exported fields on `LevelConfig`, set per level in the `.tres`.

**Waves 8 → 18 preview (the brief's sanity-check window: "Level 5 last wave + 10"):**

| Wave | Roster | Duration (s) | Spawn interval (s) | ~Enemies/wave |
|---|---|---|---|---|
| 8 | K+B+R+Q | 100 | 1.0 | 100 |
| 9 | K+B+R+Q | 100 | 0.5 | 200 |
| 10 | K+B+R+Q | 100 | 0.5 | 200 |
| 11–18 | K+B+R+Q | 100 | 0.5 | 200 |

**Steepness concerns (brief "want back" #4), stated honestly:**

- Difficulty **plateaus at wave 9** under Option B. That is not a bug in the extrapolation — it is what "continue Level 5's own formula" produces, because Level 5's formula saturates by design. Unbounded growth requires Option C (new axis).
- Safety floors that keep wave 500+ sane (brief item 1): duration capped at `maximum_wave_duration` (100s); interval floored at `extended_minimum_spawn_interval` (0.5s); both are named, config-exposed constants. All values are small floats/ints — no overflow or precision risk at wave 500 or 50,000. The only unbounded quantity is the `waves` array of past `WaveConfig`s (one tiny Resource per wave) — acceptable, but Stage 3 may optionally trim entries below `current_wave_index − 1` for infinite levels to keep memory flat; never trim for finite levels (debug Z/X/C needs the list).
- **Constants to turn the difficulty knobs** (all in `final_stand.tres`): `extended_minimum_spawn_interval` (lower → more enemies/wave), `spawn_interval_reduction` (steeper ramp), `wave_duration_increment` / `maximum_wave_duration` (longer waves), `base_spawn_interval` (starting pace).


---

## 5. Stage-by-stage implementation plan

> Convention used throughout: **edit** = change code; **verify** = run/check, no edits. Every stage ends with a 🛑 gate listing exactly what to report to the user before proceeding.

### Stage 0 — Re-verify, summarize, and get decisions (no code)

1. Read `tasks/ARCHITECTURE_NOTES.md`, `tasks/final-stand-brief.md`, then the files in §1 — confirm every claim still holds at the live commit (especially the `.tres` contents and `wave_manager.gd` line references).
2. Send the user: (a) the §1 summary in your own words, (b) the §2 Level 5 table, (c) the §3 conflict list, and (d) the questions below.
3. **Questions for the user:**
   - **Q1 (BLOCKING):** extrapolation Option A / B / C (§3 D2). A: Option B is good. 
   - **Q2:** best-score semantics + non-natural ends (§3 D3/D4) — follow the brief's "highest wave started", and do ABANDONED/bot runs count? A: Always keep track of the highest wave reached for the best score
   - **Q3:** confirm the "Check!" King event / lull timing is boilerplate (nothing exists to preserve, §3 D8). A: Yes there is no check! king event
   - **Q4 (minor):** fix the adjacent `start_button` listener-accumulation bug in `level_select.gd` while in there, or leave untouched? A: fix the bug please
   - **Q5 (minor):** exact wording of the Level Select best-score line — proposed `Best: Wave 17` (singular "Wave", per the brief's example) vs the commented-out historical `"Best: 17 waves"`. A: The former is better

🛑 **STOP 0:** No edits until the user confirms the summary and answers Q1 (and ideally Q2–Q5).

### Stage 1 — Make the difficulty curve a pure function of wave number (`level_config.gd`)

**Why first:** the brief's `get_wave(n)` requirement, the safety floors, and the "start at wave 100/500" verification are all impossible with the current stateful stepping (§1.2). This stage is behavior-neutral for Levels 1–5.

1. Add pure functions to `LevelConfig`:
   - `get_wave_duration(n: int) -> float` := `min(base_wave_duration + wave_duration_increment·(n−1), maximum_wave_duration)`
   - `get_spawn_interval(n: int) -> float` := `max(base_spawn_interval − spawn_interval_reduction·(n−1), minimum_spawn_interval)` (extended-floor variant per Q1 answer — see Stage 2 for the `n > wave_count` case)
   - `get_wave_roster(n: int) -> Array[String]` := roster of `wave_resources[n−1]` when `n ≤ wave_resources.size()`, else the extrapolated continuation (last table entry for Option A/B).
2. Prove equivalence: the existing mutation loop (`setup()` + `increase/decrease` per wave) produces exactly these values for finite levels — write a **throwaway headless check script** (e.g. `res://tests/curve_equivalence_check.gd` run via `godot --headless --script`, or a GUT test if the project adopts one; delete or keep per user preference) that builds waves for Levels 1–5 both ways and diffs every wave's duration/interval/roster.
3. Keep the old mutation path working during this stage (finite levels still use it); do not remove anything yet.

**Verify:** equivalence check passes for all 5 levels, wave by wave (3×4+... = 3+4+6+7+8 = 28 waves). Editor still loads all `.tres`.

🛑 **STOP 1:** Report the equivalence result. Proceed only with a pass.

### Stage 2 — Configure Final Stand's data (`resources/levels/final_stand.tres`, small `level_config.gd` additions)

1. Per Q1 (assume Option B; adjust if A/C):
   - Set `wave_resources` to Level 5's exact list: `[wave_1, wave_1, wave_2, wave_3, wave_4, wave_4, wave_5, wave_5]` (same shared `.tres` UIDs — safe per §1.1).
   - Copy Level 5's curve params: `base_wave_duration=60`, `wave_duration_increment=10`, `maximum_wave_duration=100`, `base_spawn_interval=8`, `spawn_interval_reduction=3`, and **`minimum_spawn_interval=1.0`** (replacing today's 0.5 — this is what pins waves 1–8 to Level 5 exactly).
   - Add one new exported field for the growth continuation, e.g. `@export var extended_minimum_spawn_interval := -1.0` (`-1.0` = "no extension", so Levels 1–5 are untouched by default) and set `0.5` in `final_stand.tres`. `get_spawn_interval(n)` uses it as the floor when `is_infinite()` and `n > wave_resources.size()` and the value is set. (Field name final call: the implementing agent may propose better; it must be config-exposed, never hard-coded.)
2. No `if level_id == "final_stand"` anywhere — behavior keys off `is_infinite()` + config fields only.
3. **Do not touch `level_1..5.tres` or any `wave_*.tres`.**

**Verify:** headless dump script printing `get_wave_duration/interval/roster(n)` for n=1..18 → waves 1–8 identical to the §2 Level 5 table; waves 9+ match the §4 preview table.

🛑 **STOP 2:** Show the user the generated waves 1–18 table (brief "want back" #3) and get sign-off on the handoff step before wiring gameplay.


### Stage 3 — On-demand generation + banner (`wave_manager.gd`, `main.gd`)

1. **Generation via the formula, not running state:** in `start_new_wave()`, for infinite levels build the appended wave from `level_config`'s pure functions: `wave.configure_wave(get_wave_duration(n), get_spawn_interval(n), get_wave_roster(n))` where `n = current_wave_index + 1` — replacing `_create_generated_wave()`'s use of the mutated running state. The finite path may keep its existing flow unchanged, or switch to the pure functions too if the Stage 1 equivalence proof makes that safe — implementing agent's choice, but Levels 1–5 must stay byte-identical in behavior.
2. `get_total_wave_number()`: return `-1` when `level_config.is_infinite()` (do not return the growing `waves.size()`).
3. **HUD banner** (`main.gd update_hud()`): when `level_config.is_infinite()`, format `"Wave  %d / ∞"` — matching the existing two-space / spaced-slash style (D7). Keep `"Wave  %d / %d"` for finite levels. Guard with a one-time `push_warning` if the label's font lacks U+221E (verified present today, §1.3 — this is only a tripwire).
4. Optional memory guard (see §4): for infinite levels, drop `waves` entries older than `current_wave_index − 1`. Never trim for finite levels (debug Z/X/C navigation needs the list).
5. Big `WaveBanner` (`"WAVE %d"`) — no change (it shows no total).

**Verify:** play Final Stand in editor: banner reads `Wave 1 / ∞`, `Wave 2 / ∞`, …; wave 1 roster is Pawn-only (matches Level 5); wave 4 interval is 1.0s not 0.5s; no errors. Play Levels 1–5: banners and behavior unchanged.

🛑 **STOP 3:** Demo/describe a short Final Stand run + a Level 5 regression run before touching score/UI.

### Stage 4 — Score, persistence, display (`main.gd`, `level_progress_manager.gd`, `level_select.gd`, `result_overlay.gd`)

1. Per Q2: `_finish_run()` records `wave_manager.get_current_wave_number()` (highest wave **started**) for infinite levels instead of `get_waves_survived()`. If the user also wants the log to carry it, add an additive `waves_reached` field to `end_run` — do not change the meaning of the existing `waves_survived` field.
2. Bot contamination guard per Q2/D4: either rely on the autoplay wrapper's save backup/restore (document it), or have `AutoplayBot` skip score recording — user's call; default to documenting the wrapper.
3. **Level Select** (`level_select.gd _config_level_details()`): for `final_stand`, the status line becomes `Best: Wave N` (wording per Q5; `Best: Wave 0` → display `—` or `Not yet attempted`). Non-final-stand levels keep `Complete`/`Incomplete`. While editing, apply (or explicitly skip, per Q4) the `start_button` reconnect fix.
4. **Result overlay** (`result_overlay.gd open()`): for Final Stand add a waves line, e.g. `"Waves reached: 12 · Best: 17"`, styled like the existing materials label (pass values in from `main.gd` — keep the overlay dumb, as its current design).
5. Conversion is untouched: `RunRewardManager.finish_run()` already runs for Final Stand (§1.4) — no new currency code.

**Verify:** die in wave 3 → Level Select shows `Best: Wave 3`; die again in wave 2 → best stays 3; quit+relaunch → best persists; result overlay shows the waves line; Office Material conversion appears as before.

🛑 **STOP 4:** Confirm score/display behavior with the user.


### Stage 5 — Debug start-wave option (`wave_manager.gd`)

1. Add a debug-only command-line user arg `--start-wave N` (parsed from `OS.get_cmdline_user_args()` inside `WaveManager.setup()`, so it applies before the first `start_new_wave()` with no race against `main._ready()`). Debug-only test affordance — never surfaced in normal UI.
2. For infinite levels it must work at any N (e.g. 500): because waves are now a pure function of n (Stage 1), simply seed `current_wave_index = N − 2` and let `start_new_wave()` generate wave N correctly — the old "curve not fast-forwarded" bug (§1.2) disappears by construction. For finite levels clamp to `waves.size()` as today.
3. Note: the existing exported `debug_start_wave` has `@export_range(1, 100, 1)` — the CLI path must not inherit that 100 cap (verification item 4 needs 500).
4. No change needed to `--final-stand-cap` (already exists, D5) — Stage 6 uses both together.

**Verify:** headless bot run with `--level final_stand --start-wave 500 --final-stand-cap 505 ...` starts at `Wave 500 / ∞` with wave-500 parameters (100s, floor interval, full roster) — not wave-1 parameters.

### Stage 6 — Full verification matrix (the brief's 7 checks)

Run every applicable check headless via the AutoplayBot runner (per `tasks/headless-auto-play-tasks.md`) plus manual editor checks. Use the bot wrapper's save backup/restore so runs don't pollute real progress — except where persistence itself is being tested (item 5), which should use a disposable/scratch `user://` or be reset afterwards.

| # | Brief check | How |
|---|---|---|
| 1 | Waves 1–8 match Level 5 exactly | Headless dump of both configs' waves 1–8 (duration, interval, roster) — must be equal; plus watch the first waves of a bot run |
| 2 | Banner `Wave N / ∞`, ∞ renders | Editor run (visual check) + font `has_character(0x221E)` tripwire passes; screenshot for the user |
| 3 | No difficulty jump at the handoff | Dump waves 7–12 side by side; per the Q1 option, show the step is the formula's own slope (or absent) |
| 4 | Start at wave 100 and 500 — no errors, freezes, runaway numbers | `--start-wave 100 --final-stand-cap 110` and `--start-wave 500 --final-stand-cap 510` bot runs; logs clean, frame time sane, enemies/wave ≈ expected (~200 at the Option B floor) |
| 5 | Best score saves, persists, displays | Die twice at different waves, relaunch, Level Select shows the max; verify `user://save.cfg` → `level_progress/final_stand_high_score` |
| 6 | Loss → Home Office + conversion as usual | Natural death (or bot timeout) → result overlay → Home Office, Office Material credited via existing `RunRewardManager` |
| 7 | Final Stand locked until Level 5 won | Fresh save: locked; win Level 5 (bot `--level level_5`): unlocked; Levels 1–5 complete/unlock flow unchanged |

Also regression: a bot batch over Levels 1–5 (1 run each) produces outcomes/logs equivalent to pre-change — proving the brief's "Do not change" holds.

### Stage 7 — Documentation & wrap-up

1. Update `tasks/ARCHITECTURE_NOTES.md`: Final Stand section (wave formula, new config fields, score semantics, `--start-wave`, banner), and remove Final Stand from the known-gaps list.
2. Update `tasks/headless-auto-play-tasks.md` wrapper docs only if `--start-wave` was added to the bot's flag list.
3. Deliver the brief's "What I want back": (1) pre-edit summary (Stage 0), (2) changed-file list, (3) extrapolation method + waves 8–18 table (Stage 2 gate), (4) steepness concerns + tuning constants (§4), (5) conflict list (§3).

---

## 6. Hard constraints (from the brief's "Do not change" + codebase rules)

- **Levels 1–5 `.tres` files and runtime behavior: untouched.** Stage 1's equivalence proof is the safety net.
- **HUD styling beyond the banner text: untouched** (no font/size/color changes; `Wave N / ∞` reuses the exact existing format).
- No new currency/conversion logic (reuse `RunRewardManager.finish_run()`).
- No `if level_id == "final_stand"` branches; all Final Stand tunables live in `final_stand.tres` / `LevelConfig` fields.
- No precomputed unbounded wave list; generation stays on demand.
- No cap that alters the difficulty curve beyond what the user approves in Q1 (the existing `maximum_wave_duration`/`minimum_spawn_interval` are Level 5's own caps and stay).
- Logger schema changes are additive only (`waves_reached`), if at all.

## 7. Expected changed files (final list reported back to the user after Stage 7)

`scripts/level_config.gd`, `scripts/wave_manager.gd`, `scripts/main.gd` (banner + score call), `scripts/level_progress_manager.gd` (only if Q2 changes semantics), `scripts/level_select.gd`, `scripts/result_overlay.gd`, `resources/levels/final_stand.tres`, plus a throwaway/kept equivalence-check script and the two task docs. **`level_1..5.tres`, `wave_*.tres`, and all Levels 1–5 gameplay scripts must show zero diffs.**

