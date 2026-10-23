# Coding Prompt: Configure the Final Stand (Infinite Level)

---

## Context

This is a Godot 4 (GDScript) mobile tower-defense game with chess-piece defenders. The project's architecture is documented in `tasks/ARCHITECTURE_NOTES.md`. **Read it first**, then read the code it points to for: the level config system, the wave system/spawner, the HUD wave banner, run-end and save/progress handling, level select and unlock logic, and the logger (if present). Before changing anything, send me a brief summary of what you found in each of those areas so I can confirm you have the right picture.

The game has five fixed levels followed by an infinite level called **Final Stand**. Final Stand is not properly configured yet. Your job is to finish it.

## What Final Stand must do

### 1. Wave structure: mimic Level 5, then extend forever

- Final Stand uses **the same enemy roster and wave-composition rules as Level 5**. For waves 1 through Level 5's last wave, Final Stand should reproduce Level 5's waves exactly.
- **After Level 5's last wave, difficulty keeps growing by continuing Level 5's own growth trend** (extrapolate the pattern). Do not invent a new scaling system with unrelated numbers.
  - If Level 5's growth is formula-based (counts, spawn interval, stat multipliers per wave), continue the same formula.
  - If Level 5 is a hand-authored table, work out the per-wave trend from its later waves (for example the average change over its last few waves, per enemy type, for spawn interval, and for any stat multiplier) and continue that trend, keeping the enemy-type mix proportions.
- Generate waves **on demand** from a function that takes any wave number (for example `get_wave(n)`). Do not precompute an unbounded list.
- Keep all existing wave behavior intact: continuous back-to-back waves with no pause, and any lull/trough timing and special events (such as the enemy King "Check!" event) that Level 5 uses, extended with the same rules.
- Put the tunables in the level config resource, not in code: whether the level is infinite (use `-1` for wave count if the config already follows that convention, otherwise add a clear equivalent), the growth parameters, and any safety floors. Don't hardcode Final Stand behavior with `if level_id == "final_stand"` checks scattered through the code.
- Add safety floors so linear growth can't break the game at very high waves, for example a minimum spawn interval and sane numeric limits (no overflow or precision problems at wave 500+). Expose them as named constants. Do not add a cap that changes the difficulty curve unless you tell me and explain why.

### 2. Wave banner

- In Final Stand, the HUD wave banner reads **`Wave N/∞`**, where N is the current wave number (for example `Wave 12/∞`).
- Other levels keep their existing `Wave N/total` format. Match the existing spacing and style for consistency.
- **Check that the HUD font actually contains the ∞ character (U+221E).** If it doesn't, the banner will show a missing-glyph box on some devices. Add a fallback font that has it, or draw a small infinity symbol as a texture, whichever fits the project better.

### 3. Run end, score, and rewards

- Final Stand has **no win condition.** The run ends only when the King runs out of lives.
- Track and persist a **best score: the highest wave reached** (the highest wave number that started). Use the existing save/progress system. If the code distinguishes "reached" from "completed", tell me what it does and pick the consistent option.
- Show the best score where the Level Select popup lists Final Stand (for example `Best: Wave 17`), and show waves reached on the run-end screen if one exists.
- The existing end-of-level conversion from Run Material to Office Material must work for Final Stand too. Reuse the existing function. Do not write new currency logic.

### 4. Unlock

- Final Stand unlocks after the player **wins Level 5**. Verify the existing unlock logic handles this; fix it if it doesn't.

### 5. Logging and test runners (only if these exist in the project)

- If the logger exists, make sure run start, run end, and wave events fire correctly for Final Stand. Final Stand always ends as a loss, so log the waves reached.
- If a headless autoplay/batch runner exists, add an optional command-line cap on the maximum number of waves for Final Stand, so batch runs terminate. This cap applies to test runs only, never to normal play.

## Do not change

- Levels 1 to 5: their behavior and balance must be exactly as they are now.
- Existing HUD styling beyond the banner text.

## Verification

Please add a debug option (command-line flag or debug-only setting) that starts Final Stand at an arbitrary wave number, and use it to check:

1. Waves 1 to N (Level 5's wave count) match Level 5 exactly.
2. The banner reads `Wave N/∞` and the ∞ renders correctly.
3. Waves past Level 5 continue Level 5's trend, with no sudden jumps in difficulty at the handoff point.
4. Starting at wave 100 and wave 500 works without errors, freezes, or runaway numbers.
5. The best score saves, persists after restarting the game, and displays in Level Select.
6. Losing returns the player to the Home Office, with Office Material converted as usual.
7. Final Stand stays locked until Level 5 is won.

## What I want back

1. Your summary of the existing code (before editing).
2. The list of files changed.
3. The extrapolation method you used, and a small table of the composition and spawn timing for waves (Level 5 last wave) through (Level 5 last wave + 10), so I can sanity-check how fast difficulty grows.
4. Any concern you have about the trend becoming too steep or too flat at high waves, and the constants I would change to adjust it.
5. Anything in this brief that conflicts with what you found in the code. Tell me before changing existing behavior to resolve a conflict.
