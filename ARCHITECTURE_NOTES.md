# Chess Kingdom Defense — Architecture Notes

## Existing systems

- The project is a Godot 4.7 mobile-renderer prototype. `project.godot` currently launches `res://scenes/main.tscn` directly.
- `scripts/main.gd` owns the active run: three King lives, game-over state, the enemy and projectile containers, HUD updates, and the `enemy_changed` signal used by wave completion.
- `scripts/board.gd` draws a fixed 17×9 board and provides cell/world conversion, center-cell, and edge-spawn helpers.
- `scripts/wave_manager.gd` owns the five existing `WaveConfig` resources. It spawns enemies during a timed wave, waits for the enemy container to clear, then advances. It is currently configured through the `WaveManager.waves` inspector property in `main.tscn`.
- `scripts/currency_manager.gd` is already the correct boundary for **Run Material**. It starts at 5, exposes add/spend/reset methods, and is resettable per run; it does not persist.
- `scripts/shop_ui.gd` and `scripts/placement_controller.gd` use `CurrencyManager` to buy a defender from the tray and place it after a successful drag/drop.
- Defenders derive from `BasePiece`; their concrete scripts implement their chess-specific targeting and create a standard projectile through `Main.spawn_projectile`.
- Enemies derive from `BaseEnemy`; each concrete enemy implements movement, `setup`, and `take_damage`. Enemy deaths currently award Run Material directly inside each enemy script.
- `scripts/projectile.gd` is the common combat hook. Every hit calls `target.take_damage(damage)` with a fixed damage value of 1.

## Existing autoloads

| Autoload | Script | Scope |
| --- | --- | --- |
| `CurrencyManager` | `scripts/currency_manager.gd` | Run Material and standard chess-piece values |
| `InventoryManager` | `scripts/inventory_manager.gd` | Per-run placed-piece counts |

There is no existing persistence system. Searches found no `ConfigFile`, `user://` save file, or save/load code.

## Existing scene hierarchy

`scenes/main.tscn` contains:

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

The existing five wave resources are `resources/wave_1.tres` through `resources/wave_5.tres`. Level 1 uses only Pawns; later resources progressively enable Knight, Bishop, Rook, and Queen.

## Relevant interfaces and signals

- `CurrencyManager.currency_changed(new_amount: int)` updates the in-run currency HUD.
- `CurrencyManager.add_currency`, `spend_currency`, and `reset_for_new_run` are the Run Material interface.
- `Main.enemy_changed` is emitted after an enemy is removed/reaches the King and is connected to `WaveManager.notify_enemy_count_changed`.
- `WaveManager` declares wave lifecycle signals, but the signal emissions are currently commented out. It has no level-completed or run-ended signal.
- `Main.end_game()` only sets `game_over` and shows the game-over label. It does not reset a run, return to another scene, or publish a result.
- `Main.enemy_destroyed(enemy)` removes the enemy; concrete enemy scripts grant their own Run Material before calling it.
- Enemy `setup(game_reference, cell)` is the safest minimal spawn hook for a future bestiary encounter marker. `WaveManager.spawn_random_enemy()` and `EnemyManager.spawn_enemy()` are the two current spawn paths.
- Defender scripts share `setup`, `set_cell`, `set_dragging`, and `get_attack_tiles_for_cell`; they do not currently expose damage, attack-speed, aura, adjacency, promotion, or special-effect interfaces.

## Proposed integration points

1. Introduce a single `SaveData` autoload backed by `user://save.cfg` (`ConfigFile`). It should own load/save and provide namespaced sections for office material, skills, bestiary, level progress, Final Stand score, and daily rewards. Feature managers should call that service rather than create independent files.
2. Add `OfficeMaterialManager` as a separate persistent autoload. It must never be substituted for, or wired into, `CurrencyManager`.
3. Add a small run-reward coordinator (or a narrow method on the gameplay controller) that receives a completed-run result and converts tracked **earned** Run Material at a named rate. This should be connected from an explicit run-ended signal rather than make the office manager depend on `WaveManager`.
4. Add `LevelConfig` resources and a selected-level session service. Adapt `WaveManager` only at its configuration boundary so it receives an assigned wave list/config; preserve its spawning and combat behavior.
5. Mark bestiary encounters immediately after a concrete enemy instance is created, using the spawn path. This is an additive hook, not an enemy movement rewrite.
6. Introduce Home Office, Title, Level Select, Bestiary, Skill Shop, and Learning Openings as separate `Control` scenes. Scene transitions can wrap the existing gameplay scene, leaving its board hierarchy intact.
7. Keep skill application behind query methods in a `SkillManager`; only wire effects where a minimal existing hook exists. The proposed gameplay skill concepts need dedicated hooks because projectiles have fixed damage and pieces/enemies do not currently expose buffs, slow, pushback, auras, promotion, or neighboring-piece queries.

## Potential conflicts and risks

- The README is stale relative to the source: it describes no shop/currency/waves and a Rook-only demo, while the project contains all five wave resources and a working shop/currency implementation.
- `EnemyManager` has an `auto_spawn_enemies` path alongside `WaveManager`; `main.tscn` enables `auto_spawn_enemies` by default. The scene also connects `EnemyManager/SpawnTimer.timeout` to `_on_spawn_timer_timeout`, but that method is not present in the inspected script. The expansion should not rely on this legacy/debug path without confirming intended behavior.
- Existing wave lifecycle signals are declared but commented out. Fixed-level completion and return-to-hub need an explicit completion contract, which is a minimal wave-system modification but should be approved first.
- Run Material is awarded in five individual enemy scripts. Accurate run-end conversion needs a non-invasive earned-this-run counter connected to `CurrencyManager.add_currency`, rather than inferring balance (because material is also spent during a run).
- Projectile damage is hard-coded and has no source-piece reference, so skill effects cannot currently be attributed to a defender without a gameplay change.
- Rook, Bishop, and Queen enemy scripts cache the King location on setup in parts of their movement logic. Any pushback/slow implementation must be designed carefully, and should not be assumed to work from generic skill code alone.

## Questions requiring user confirmation

1. The task plan requires a checkpoint after this report. May I proceed with phase 1 (central persistence plus persistent Office Material), including minimal additive hooks to count Run Material earned and to publish both win/loss run-end results?
2. Should level selection show only locked/unlocked/completed state for now, as the brief's default suggests, or should it include per-level stats/stars?
3. Is the current `EnemyManager` auto-spawn path intentionally still active, or should levels rely exclusively on `WaveManager`? This determines how to make bestiary encounter tracking exhaustive without altering gameplay behavior.
4. For future functional skills: do you want permission for minimal combat hooks (projectile source/damage, enemy slow/pushback, and piece-neighbor queries), or should phase 5 initially ship only economy/UI-safe skills and leave behavior skills visibly stubbed?
