## Context

I have a working prototype of a 2D tower-defense game in **Godot 4 (GDScript)**: chess-piece-themed defenders (Pawn, Knight, Bishop, Rook, Queen) protect a King at the center of a grid board from enemy chess pieces spawning from all edges. Combat, a 5-wave level, an in-run currency ("Material") earned from kills, and drag-and-drop piece placement from a tray are all already implemented and working.

I now want to expand this into a full game loop: a home hub, level progression, a persistent meta-progression skill system, an enemy bestiary, and an alternate material-earning mechanic. This prompt covers all five additions. **The goal is to implement these as separable systems/scenes with clear integration points into my existing gameplay scene . Rewriting my existing combat/wave/placement logic needs explicit permission from me.** Please use this description to generate a step-by-step guide to carry out these tasks.

## Existing project structure

*(Fill in before sending)*

- Main gameplay scene: `scenes/main.tscn`
- Wave system script/scene: `scripts/wave_manager.gd`
- Currency/`CurrencyManager` (in-run Material): `scripts/currency_manager.gd`
- Piece scenes and their shared script/interface: `scenes/pawn.tscn` and `scripts/pawn.gd` (Other pieces are named similarly)
- Enemy piece scenes and their shared script/interface: `scenes/shadow_pawn.tscn` and `scripts/shadow_pawn.gd` (Other pieces are named similarly)
- Save/persistence system : Not implemented yet

---

## 1. Currency architecture (read this first — it affects everything below)

Two currency pools, same denomination/name ("Material"), different scope:

- **Run Material** — what already exists. Earned from kills during a level, spent on buying/placing pieces during that level, does **not** persist between levels (resets to a starting value each run).
- **Office Material** — a new **persistent** currency, saved across sessions, spent only on permanent skills in the Home Office (see section 3). This is intentionally scarce early on so office skills feel earned, not instantly available.

**Office Material is earned two ways:**
1. **Level-end conversion**: when a level ends (win or lose), convert a portion of the Run Material earned during that attempt into Office Material — e.g. `office_material_gained = floor(run_material_earned * 0.2)`. Make this rate a named constant/config value, not a hardcoded literal, since it'll need tuning.
2. **The material-earning button** (see section 5) — a small, rate-limited source independent of playing a level at all.

Please implement `OfficeMaterialManager` as a persistent autoload (save/load to disk — use Godot's `ConfigFile` or a JSON save file, whichever fits my existing save setup if I have one) with:
- `var current_amount: int`
- `func add_office_material(amount: int) -> void`
- `func spend_office_material(amount: int) -> bool`
- `signal office_material_changed(new_amount: int)`

## 2. Entry flow

```
Title Screen → Home Office (hub) → Level Select → Gameplay → (return to Home Office on level end)
```

- **Title screen**: brief, no interaction required — logo/game name, auto-advances to Home Office after a fixed delay (e.g. 2 seconds) or on any tap/click, whichever comes first. Placeholder background image (accept an image path as a config/export var so I can swap it later).
- **Home Office (hub)**: the player's "office" — a King managing defense from behind a desk, conceptually. Placeholder background image (same pattern — export var for easy swapping). From here, navigation buttons to:
  - **Play** → Level Select
  - **Skills** → Skill shop (section 3)
  - **Bestiary** → Enemy guide (section 4)
  - **Earn Material** → the puzzle/opening button screen (section 5)
  - Office Material counter always visible here (bound to `OfficeMaterialManager.office_material_changed`)
- **Level Select**: a row/grid of level nodes — Levels 1 through 5, then a distinct "Final Stand" node for the infinite level. Locked levels (not yet unlocked) shown grayed out. Completing a level unlocks the next.

## 3. Level design

Recommendation, since you asked for my input: **5 fixed levels, then an infinite final level.** Rationale: five levels is enough to introduce all five piece types one at a time (clean difficulty ramp, clean tutorial-by-play structure) without the level-authoring workload of 8+ hand-built levels for a prototype-to-full-game expansion.

| Level | New enemy piece introduced | Notes |
|---|---|---|
| 1 | Pawn | Already-built 5-wave structure, reused/renamed as "Level 1" |
| 2 | Knight | |
| 3 | Bishop | |
| 4 | Rook | |
| 5 | Queen |  |
| Final Stand | All piece types, mixed | **Infinite waves** — no wave cap. Difficulty scales per wave indefinitely (increase spawn rate and/or enemy stat multiplier on a formula, e.g. `wave_multiplier = 1 + (wave_number * 0.08)`). Player's run ends only when the King runs out of lives. Track and save a **high score** (waves survived, and/or total kills) for this mode specifically. |

Implementation ask: build a `LevelConfig` resource (Godot `Resource` script) with fields like `level_id`, `display_name`, `wave_count` (or `-1` for infinite), `allowed_enemy_pieces: Array`, `difficulty_curve_params`. Create one `.tres` resource per level. The gameplay scene should load whichever `LevelConfig` was selected rather than hardcoding level 1's numbers — this lets you add/rebalance levels without touching gameplay code.

## 4. Skill system (Home Office)

**Design confirmed:** permanent, always-on boosts — no loadout or equip limit. Once bought with Office Material, a skill is permanently active in every future run.

Please implement:
- A `SkillDefinition` resource: `skill_id`, `display_name`, `description`, `icon`, `cost: int`, `effect_type` (enum), `effect_value`.
- A `SkillManager` autoload tracking which skills are owned (persisted alongside Office Material) and exposing `func has_skill(skill_id: String) -> bool` and `func get_skill_value(skill_id: String) -> float` for gameplay code to query.
- A Skill Shop UI scene (accessible from Home Office) listing all `SkillDefinition` resources, showing owned/locked/affordable state, with a buy button wired to `OfficeMaterialManager.spend_office_material()`.

**On skill *content* — propose your own list of 6-10 skills as part of your implementation**, but here are directions to riff on, spanning different piece-interaction types rather than flat stat boosts:

- Cross-piece synergy (e.g. "Adjacent Pawns share 10% of each other's damage bonus")
- Unlocking or upgrading the special abilities: e.g., Queen's Command Aura (add the attack strength within a certain distance to the Queen) with radius increased, Rook's pushback (Rook's attack would push back an enemy) with distance increased, Bishop's slow effect (Bishop's attack slows down an enemy's movement) with duration increased
- Global passive tied to a mechanic (e.g. "Promoted Pawns keep 50% of their bonus stats even after death, applied as a one-time board-wide buff")
- Economy skills (e.g. "+10% Run Material from kills") — fine to include a couple of these, but they shouldn't be the majority, since flat economy boosts are the least interesting version of "something cool with piece behavior"

Flag in your output which skills you implemented as fully functional vs. stubbed, since some (like the cross-piece synergy example) may need hooks into piece scripts I haven't described in enough detail above — ask me about the specifics of how pieces currently track "nearby pieces" or "damage dealt" if that data isn't already exposed.

## 5. Bestiary (illustrated enemy guide)

- A `BestiaryManager` autoload (persisted) tracking which enemy piece types the player has **encountered** (seen in a level at least once) — start all as unseen/locked.
- On an enemy piece's first-ever spawn in any level, mark it encountered and save.
- Bestiary UI (accessible from Home Office): a grid of entries, one per enemy piece type. Locked entries show a silhouette/question-mark placeholder. Unlocked entries show: an illustration (placeholder image, export var per entry for easy swapping later), the piece name, its movement pattern (reuse whatever movement description/data already exists in the enemy piece scripts — don't reimplement), and a short flavor text field (leave flavor text as an empty/placeholder string field I'll fill in later).

## 6. Material-earning button ("Learning Openings")

- A simple screen (accessible from Home Office) with a single button. Clicking it awards a fixed amount of Office Material directly (not Run Material — this feeds the meta-progression pool, consistent with everything else earned outside of active gameplay).
- **Rate-limited**, not infinitely spammable: implement as a limited number of uses per real-world day (e.g. 5 uses/day — expose as a config constant), tracked with a timestamp-based reset (store last-reset date, compare against current date on scene load, reset the counter if it's a new day). Show remaining uses and, once exhausted, a "come back tomorrow" state.
- Structure this as its own scene/manager (`DailyRewardManager` or similar) since I plan to gate this behind rewarded ads later — for now it's just a free click, but keep the "click triggers reward" and "reward eligibility check" logic separably callable, so a future ad-watched callback can call the same reward function instead of the button's direct click handler.

---

## Open questions — please ask me before implementing if any of these matter for your approach

- Whether I have any existing save/persistence system already, and if so its format (this affects how `OfficeMaterialManager`, `SkillManager`, and `BestiaryManager` should persist data)
- The exact shared interface my piece and enemy-piece scripts expose (stats, signals for "on kill," "on spawn," etc.) — needed for the skill system's cross-piece-synergy examples and the bestiary's encounter-tracking hook
- Whether Level Select should show per-level stats (best wave reached, stars, etc.) or just locked/unlocked/completed state for now
- Any UI framework/style conventions already established in my project (so new screens match)

Implement in this order: (1) currency architecture, since everything else depends on it, (2) entry flow scaffolding with placeholder screens, (3) level config system, (4) bestiary, (5) skill system, (6) material-earning button — and check in with me after each numbered section rather than building all six before I can review anything.
