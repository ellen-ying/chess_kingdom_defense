# Chess Kingdom Defense — AI Agent Implementation Plan

## 0. Establish the project contract first

Before changing any code, the agent should inspect the existing project and produce a short architecture report.

### Inspect

Identify:

- `scenes/main.tscn`
- `scripts/wave_manager.gd`
- `scripts/currency_manager.gd`
- all player-piece scripts/scenes
- all shadow-enemy scripts/scenes
- current board/grid implementation
- current King/lives/game-over implementation
- current shop/inventory/placement implementation
- current UI structure
- project autoloads
- existing save system, if any

The known structure currently includes `main.tscn`, `wave_manager.gd`, `currency_manager.gd`, player pieces such as `pawn.tscn`/`pawn.gd`, and shadow pieces such as `shadow_pawn.tscn`/`shadow_pawn.gd`; persistence was not yet implemented in the original brief. 

### Critical rule

The agent must **not refactor or rewrite existing gameplay systems merely to make the new architecture prettier**.

Before modifying:

- combat
- enemy movement
- wave spawning
- placement
- projectile behavior
- existing currency behavior

the agent should identify the exact integration point and ask for permission if the modification is more than a minimal hook.

This is particularly important because the expansion is intended to be implemented as separable systems/scenes. 

### Deliverable

Create:

```text
ARCHITECTURE_NOTES.md
```

containing:

```text
Existing systems
Existing autoloads
Existing scene hierarchy
Relevant interfaces/signals
Proposed integration points
Potential conflicts
Questions requiring user confirmation
```

Then **stop and report to the user**.

---

# 1. Build the persistent currency architecture

This should be the first actual implementation phase because several later systems depend on it. Your brief explicitly prioritizes currency first. 

## 1.1 Keep Run Material separate

Do **not** turn the existing `CurrencyManager` into the persistent currency.

Maintain:

```text
CurrencyManager
    ↓
Run Material
    ↓
exists only during a run
```

and introduce:

```text
OfficeMaterialManager
    ↓
Office Material
    ↓
persists between runs/sessions
```

The two pools intentionally use the same denomination, "Material", but have different scopes. 

---

## 1.2 Create `OfficeMaterialManager`

Create:

```text
scripts/office_material_manager.gd
```

Autoload it as:

```text
OfficeMaterialManager
```

Required interface:

```gdscript
var current_amount: int

signal office_material_changed(new_amount: int)

func add_office_material(amount: int) -> void
func spend_office_material(amount: int) -> bool
```

It must:

- reject invalid spending
- never allow negative balance
- emit the signal whenever the balance changes
- load automatically when the game starts
- save whenever the balance changes

---

## 1.3 Create persistence infrastructure

Before allowing each manager to invent its own save format, establish one central persistence location.

Recommended:

```text
user://save.cfg
```

using `ConfigFile`.

Conceptually:

```text
SaveData
│
├── office_material
├── skills
├── bestiary
├── level_progress
└── final_stand_high_score
```

Even if you initially implement the sections separately, reserve namespaces for them.

This prevents five independent save files from appearing later.

---

## 1.4 Implement Run → Office conversion

At level end:

```text
Run ends
   ↓
calculate Run Material earned during attempt
   ↓
floor(earned × conversion_rate)
   ↓
OfficeMaterialManager.add_office_material(...)
```

Use:

```gdscript
const RUN_TO_OFFICE_RATE := 0.20
```

or preferably make it an exported/configurable value.

The brief specifies this conversion applies on **both win and loss**. 

### Important

Do not make `OfficeMaterialManager` depend on `WaveManager`.

Instead, expose something like:

```gdscript
func process_run_end(run_material_earned: int) -> void
```

in an appropriate run-reward coordinator.

That keeps the persistent economy independent of gameplay implementation.

---

## 1.5 Test

The agent must verify:

- starting amount loads correctly
- adding Material persists
- spending Material persists
- insufficient funds don't deduct
- restarting the game preserves Office Material
- Run Material still resets between runs
- run-end conversion works on victory
- run-end conversion works on defeat

### Checkpoint

**Stop and ask the user to test this phase.**

---

# 2. Build the entry-flow scaffolding

The target flow is:

```text
Title
  ↓
Home Office
  ↓
Level Select
  ↓
Gameplay
  ↓
Home Office
```

This flow is explicitly specified in the brief. 

Create:

```text
scenes/
├── title_screen.tscn
├── home_office.tscn
├── level_select.tscn
└── ...
```

and corresponding scripts.

---

## 2.1 Title Screen

Minimal:

```text
Chess Kingdom Defense

[background]

(auto transition)
```

Behavior:

```text
2-second timer
        OR
player click/tap
        ↓
Home Office
```

Use an exported background texture/path so replacing the placeholder doesn't require code changes.

---

## 2.2 Home Office

Create a central hub containing:

```text
Home Office
│
├── Office Material counter
│
├── Play
├── Skills
├── Bestiary
└── Earn Material
```

The Material counter must subscribe to:

```gdscript
OfficeMaterialManager.office_material_changed
```

rather than polling.

---

## 2.3 Navigation manager

I recommend a tiny:

```text
SceneRouter
```

autoload or utility responsible for scene transitions.

For example:

```text
SceneRouter.go_to_home()
SceneRouter.go_to_level_select()
SceneRouter.start_level(level_config)
```

This avoids every UI screen having its own `change_scene_to_file()` logic.

---

## 2.4 Gameplay return path

At the end of a run:

```text
Gameplay
   ↓
process rewards
   ↓
save progress
   ↓
Home Office
```

Do not hard-code "return to Level Select" unless you later want that behavior.

---

## 2.5 Test

Verify:

```text
Title → Office
Office → Level Select
Office → Skills
Office → Bestiary
Office → Earn Material
Level Select → Gameplay
Gameplay → Office
```

### Checkpoint

**Stop and ask the user to test.**

---

# 3. Introduce `LevelConfig`

This is where the existing five-wave prototype becomes a reusable level system.

Create:

```text
scripts/level_config.gd
```

as a Godot `Resource`.

The brief specifically calls for a `LevelConfig` containing fields such as `level_id`, `display_name`, `wave_count`, `allowed_enemy_pieces`, and difficulty parameters. 

Recommended:

```gdscript
class_name LevelConfig
extends Resource

@export var level_id: int
@export var display_name: String
@export var wave_count: int
@export var allowed_enemy_pieces: Array[String]
@export var difficulty_curve_params: Dictionary
@export var waves: Array[WaveConfig]
@export var is_final_stand: bool
```

---

## 3.1 Create resources

Create:

```text
resources/levels/
├── level_01.tres
├── level_02.tres
├── level_03.tres
├── level_04.tres
├── level_05.tres
└── final_stand.tres
```

The intended progression is:

| Level | Introduced enemy |
|---|---|
| 1 | Pawn |
| 2 | Knight |
| 3 | Bishop |
| 4 | Rook |
| 5 | Queen |
| Final Stand | All |

This progression is explicitly defined in the brief. 

---

# 4. Refactor wave selection, not wave mechanics

This is an important distinction.

The agent should **not rewrite the working wave system**.

Instead:

```text
LevelConfig
     ↓
selected level
     ↓
WaveManager receives configuration
     ↓
existing wave machinery
```

If the current `WaveManager` already supports wave resources, reuse that.

If it does not, add the smallest possible adapter.

The gameplay scene should therefore know:

```gdscript
var selected_level: LevelConfig
```

rather than:

```gdscript
const LEVEL = 1
```

---

# 5. Implement Level Select

Create a reusable:

```text
LevelNode.tscn
```

Each node displays:

```text
Level 1
────────
✓ Completed
```

or:

```text
Level 2
────────
🔒 Locked
```

or:

```text
Final Stand
───────────
∞
```

Unlock rule:

```text
Complete Level N
       ↓
Unlock Level N+1
```

Store:

```text
completed_levels
unlocked_levels
```

in persistent save data.

For now, **do not introduce stars, scores, medals, etc.** The brief leaves those as an open question and only requires locked/unlocked/completed state at minimum. 

---

# 6. Implement Final Stand separately

Treat Final Stand as a special `LevelConfig`:

```text
wave_count = -1
is_final_stand = true
```

Rules:

```text
All enemy types available
       ↓
Wave 1
       ↓
Wave 2
       ↓
Wave 3
       ↓
...
       ↓
never ends naturally
```

Difficulty should scale with wave number.

For example:

```gdscript
func get_wave_multiplier(wave_number: int) -> float:
	return 1.0 + wave_number * 0.08
```

But keep the formula configurable.

Possible parameters:

```text
base_multiplier
multiplier_per_wave
spawn_interval_scaling
enemy_hp_scaling
enemy_speed_scaling
```

The brief specifically suggests a wave-based difficulty formula such as `1 + wave_number * 0.08`. 

---

## Final Stand high score

Track separately:

```text
final_stand_best_wave
final_stand_best_kills
```

Only update these in Final Stand.

Do **not** mix them with normal level completion.

### Checkpoint

**Stop and ask the user to test this phase.**

---

# 7. Build the Bestiary

Create:

```text
scripts/bestiary_manager.gd
scenes/bestiary.tscn
scenes/bestiary_entry.tscn
```

Autoload:

```text
BestiaryManager
```

Persistent state:

```gdscript
var encountered: Dictionary
```

Initially:

```text
Pawn = false
Knight = false
Bishop = false
Rook = false
Queen = false
King = false
```

---

## 7.1 Encounter hook

When an enemy **spawns for the first time**, call:

```gdscript
BestiaryManager.mark_encountered("Pawn")
```

Do not make BestiaryManager inspect the enemy manager every frame.

The enemy spawning system should provide the event.

---

## 7.2 Bestiary entry

Each entry contains:

```text
[image]

Pawn
Movement:
Moves one square toward King

Flavor:
[placeholder]
```

Before encounter:

```text
[?]

???
Movement:
???

Flavor:
???
```

The movement description should come from existing enemy movement data wherever possible.

Do **not** duplicate movement rules inside the Bestiary.

The brief explicitly says to reuse existing movement descriptions/data rather than reimplementing them. 

### Checkpoint

**Stop and ask the user to test this phase.**

---

# 8. Build the Skill architecture

This should be deliberately more modular than the gameplay itself.

Create:

```text
scripts/skill_definition.gd
scripts/skill_manager.gd
scenes/skill_shop.tscn
scenes/skill_entry.tscn
resources/skills/
```

---

## 8.1 SkillDefinition

```gdscript
class_name SkillDefinition
extends Resource

@export var skill_id: String
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var cost: int
@export var effect_type: EffectType
@export var effect_value: float
```

Use an enum for `EffectType`.

---

# 9. Proposed initial skill tree

I would start with **8 skills**, but only make the ones whose hooks are already available fully functional.

### Skill 1 — Material Efficiency

```text
+10% Run Material from enemy kills
```

**Fully functional** if the kill-reward hook already exists.

---

### Skill 2 — Knight's Reach

```text
Increase Knight attack range by 1 legal knight-distance layer.
```

**Stub initially** unless your Knight range system is already parameterized.

---

### Skill 3 — Bishop's Patience

```text
Bishop slow effect lasts +25%.
```

**Stub** unless the Bishop currently exposes a slow effect.

---

### Skill 4 — Rook's Force

```text
Rook pushback distance +1.
```

**Stub** unless pushback already exists.

---

### Skill 5 — Queen's Command

```text
Queen aura radius +1.
```

**Stub** unless the Queen aura already exists.

---

### Skill 6 — Pawn Formation

```text
Adjacent Pawns receive a damage bonus.
```

**Stub initially.**

This one needs a clear definition of:

- adjacency
- damage stat
- when the bonus is recalculated

The brief itself warns that cross-piece synergy may require additional hooks in your piece scripts. 

---

### Skill 7 — Promotion Memory

```text
Promoted Pawns preserve part of their bonus after promotion/death.
```

**Stub initially.**

---

### Skill 8 — Veteran's Resolve

```text
Increase the King's maximum/starting lives.
```

**Fully functional** if the King/lives system has a clean initialization hook.

---

# 10. SkillManager

Autoload:

```text
SkillManager
```

Required:

```gdscript
func has_skill(skill_id: String) -> bool
func get_skill_value(skill_id: String) -> float
```

Persistence:

```text
skills = {
    "material_efficiency": true,
    "veterans_resolve": false,
    ...
}
```

Buying:

```text
Skill Shop
   ↓
OfficeMaterialManager.spend_office_material()
   ↓
SkillManager.unlock_skill()
   ↓
save
   ↓
UI updates
```

There must be:

```text
no equip phase
no loadout
no reset
```

because skills are permanent and always active. 

---

# 11. Skill UI

Each skill entry should support:

```text
Locked
Owned
Affordable
Unaffordable
```

For example:

```text
┌──────────────────────────┐
│ ♕ Queen's Command        │
│                          │
│ Increase aura radius +1  │
│                          │
│ Cost: 10 Material        │
│                          │
│ [Purchase]               │
└──────────────────────────┘
```

Owned:

```text
✓ ACTIVE
```

No button should permit repurchasing.

---

# 12. Integrate skills into gameplay carefully

This is where the AI agent must be conservative.

Before implementing a skill, ask:

```text
What existing system owns this mechanic?
```

For example:

```text
Material skill
     ↓
enemy death reward

Queen skill
     ↓
Queen attack/aura system

Bishop skill
     ↓
Bishop projectile/status effect

Rook skill
     ↓
Rook hit/pushback system
```

Add small query hooks such as:

```gdscript
SkillManager.get_skill_value("rook_pushback")
```

rather than making `SkillManager` directly manipulate pieces.

This preserves separation of concerns.

### Checkpoint

**Stop and ask the user to test this phase.**

---

# 13. Build "Learning Openings"

Create:

```text
scripts/daily_reward_manager.gd
scenes/earn_material.tscn
```

Autoload:

```text
DailyRewardManager
```

---

## 13.1 Daily reward API

Separate eligibility from reward execution:

```gdscript
func can_claim() -> bool
func get_remaining_uses() -> int
func claim_reward() -> bool
```

This is important because later:

```text
Button
   ↓
Ad system
   ↓
successful ad
   ↓
DailyRewardManager.claim_reward()
```

instead of:

```text
Button
   ↓
give reward
```

The brief explicitly asks for this separation because rewarded ads will eventually be added. 

---

# 14. Daily reset logic

Config:

```gdscript
const MAX_DAILY_USES := 5
const REWARD_AMOUNT := 1
```

Save:

```text
last_claim_date
uses_today
```

On manager initialization:

```text
current date
      ↓
compare with saved date
      ↓
different?
 ┌────┴────┐
yes        no
 ↓          ↓
reset      keep
```

Use a calendar date rather than a 24-hour timer.

So:

```text
23:59 → 00:01
```

counts as a new day.

---

# 15. Final integration testing

Once all six systems work independently, perform an end-to-end test.

## New player

```text
Launch
 ↓
Title
 ↓
Office
 ↓
Office Material = initial value
 ↓
Level Select
 ↓
Only Level 1 unlocked
```

## Complete Level 1

```text
Level 1
 ↓
earn Run Material
 ↓
finish
 ↓
Run Material converted
 ↓
Office Material increases
 ↓
Level 2 unlocks
 ↓
return Office
```

## Encounter

```text
Shadow Knight spawns
 ↓
BestiaryManager marks Knight encountered
 ↓
save
 ↓
return to Office
 ↓
Bestiary shows Knight
```

## Skill

```text
Office
 ↓
Skills
 ↓
buy skill
 ↓
Office Material decreases
 ↓
skill becomes ACTIVE
 ↓
restart game
 ↓
skill remains owned
```

## Daily reward

```text
Office
 ↓
Learning Openings
 ↓
5 uses available
 ↓
claim
 ↓
Office Material + reward
 ↓
uses = 4
 ↓
restart
 ↓
uses = 4
```

## Final Stand

```text
Level Select
 ↓
Final Stand
 ↓
all enemies
 ↓
Wave 1
 ↓
Wave 2
 ↓
...
 ↓
King dies
 ↓
save high score
 ↓
return Office
```

---

# 16. Recommended final project structure

After the expansion, I would aim for something approximately like:

```text
ChessKingdomDefense/
│
├── scenes/
│   ├── main.tscn
│   │
│   ├── title_screen.tscn
│   ├── home_office.tscn
│   ├── level_select.tscn
│   ├── gameplay.tscn
│   │
│   ├── skill_shop.tscn
│   ├── skill_entry.tscn
│   │
│   ├── bestiary.tscn
│   ├── bestiary_entry.tscn
│   │
│   └── earn_material.tscn
│
├── scripts/
│   ├── scene_router.gd
│   │
│   ├── currency_manager.gd
│   ├── office_material_manager.gd
│   │
│   ├── inventory_manager.gd
│   ├── placement_controller.gd
│   │
│   ├── wave_manager.gd
│   ├── wave_config.gd
│   ├── level_config.gd
│   │
│   ├── skill_manager.gd
│   ├── skill_definition.gd
│   │
│   ├── bestiary_manager.gd
│   ├── daily_reward_manager.gd
│   │
│   └── save_manager.gd
│
├── resources/
│   ├── levels/
│   │   ├── level_01.tres
│   │   ├── level_02.tres
│   │   ├── level_03.tres
│   │   ├── level_04.tres
│   │   ├── level_05.tres
│   │   └── final_stand.tres
│   │
│   ├── waves/
│   │   ├── wave_01.tres
│   │   └── ...
│   │
│   └── skills/
│       ├── material_efficiency.tres
│       ├── knights_reach.tres
│       ├── bishops_patience.tres
│       ├── rooks_force.tres
│       ├── queens_command.tres
│       ├── pawn_formation.tres
│       ├── promotion_memory.tres
│       └── veterans_resolve.tres
│
└── assets/
    ├── backgrounds/
    ├── pieces/
    ├── enemies/
    ├── bestiary/
    └── ui/
```
