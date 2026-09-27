## Context

I'm building a mobile tower-defense game in Godot 4 (GDScript) — chess-piece-themed defenders protect a King from enemy chess pieces attacking from all directions across continuous waves. Core gameplay, a full level/game-loop structure, and a logging system (`GameLogger`, writes CSV + JSON Lines to `user://logs/`, behind an on/off flag) are already implemented and working.

I want to run the game **headless** (Godot's `--headless` command-line mode, no rendering/window) many times automatically, with a **bot controlling piece purchases and placement** instead of a human, so I can generate a large volume of realistic logged gameplay data across different strategies and levels for balance analysis. This avoids the accuracy problems of a simplified external simulation — since this runs the actual game logic, actual board, and actual piece attack-pattern geometry, the resulting data reflects real positional effects (line-of-sight, diagonal-only Bishop coverage, radial spawn pressure, etc.) rather than an abstracted approximation.

**This should not change any existing gameplay/balance code. It's purely additive: a bot "brain" that drives the same input paths a human player would use (buy piece, place piece), plus a runner that launches multiple headless sessions.**

## Existing project structure

Read the file `tasks/ARCHITECTURE_NOTES.md` for the current project architecture.

## Requirements

### 1. Bot controller (`AutoplayBot` or similar)
A script that, when active, drives the game via the **same functions/signals a human input triggers** — do not bypass game logic by directly mutating state (e.g. don't set currency directly; call the same `spend_currency`/`buy_piece` functions the UI calls). This matters: the whole point is that the bot exercises real code paths, so bugs or edge cases a human might trigger get exercised too.

The bot needs two decisions each time it acts:
- **What to buy** (which piece type, if any, given current Material and prices)
- **Where to place it** (which board tile)

**Buying strategies — implement all four as swappable, selectable at launch (e.g. via command-line argument or a config value read at startup):**
1. `cheapest_first` — always buy the cheapest currently-affordable piece type
2. `balanced` — buy whichever owned piece type currently has the lowest count, among affordable options
3. `rush_strongest` — hold Material until the most expensive piece is affordable, buying only the cheapest filler piece if Material would otherwise sit completely idle for too long (define "too long" as a config value, e.g. don't buy filler if the strongest piece is affordable within the next ~2 enemy kills' worth of Material)
4. `random` — random affordable piece type each decision point

**Placement logic — since the whole reason we're doing this in real Godot is to capture positional effects, please implement a real (if simple) placement heuristic, not a random tile:**
- A reasonable default: place the piece at the empty tile that is closest to the board edge currently receiving the most incoming enemies (i.e. some notion of "threat density" per edge/direction) — this exercises the actual radial-spawn-pressure dynamic that a human would naturally respond to.
- If that's too complex given my project's structure, a simpler fallback is acceptable: place at the nearest empty tile to the busiest currently-alive enemy cluster. Use your judgment on which is more feasible given what I've described above, and tell me which you implemented.
- **Bishop/Rook/Queen-specific nuance**: since these pieces' value depends heavily on which tiles they threaten (diagonal-only for Bishop, orthogonal lines for Rook, both for Queen), the placement heuristic should prefer tiles that put the piece's attack lines through currently-active or -recent enemy paths, not just "close to the action." Flag if this is more than you can reasonably infer from my project description — a cruder heuristic that still places pieces near the threat, even without line-optimization, is an acceptable fallback for a first version.

**Decision timing**: the bot should act on the same cadence a human effectively would — e.g. check "should I buy/place something" once per short interval (configurable, e.g. every 0.5s) rather than every single frame, both for performance and because "instant reaction every frame" isn't representative of real play.

### 2. Run configuration and batching
- The bot, buying strategy, and target level should all be settable via **command-line arguments** passed to the headless Godot executable (Godot supports custom `--` arguments read via `OS.get_cmdline_args()`), e.g.:
  `godot4 --headless --path [project_path] -- --strategy=cheapest_first --level=level_3 --runs=50`
- Implement a `--runs=N` option that runs N consecutive simulated levels **within a single headless process launch** (reset game state between runs, don't require relaunching the executable each time) — this is much faster than relaunching Godot per run. Each run should get a distinct `run_id` for the logger, as already implemented.
- On completion of all N runs, the process should exit cleanly (`get_tree().quit()`) so this can be scripted in a loop from outside (e.g. a shell script that calls this once per strategy/level combination).

### 3. A wrapper shell script
Write a simple bash (or Python, your preference — bash is probably simpler here) script that loops over all 4 strategies × all levels (5 fixed + Final Stand, capping Final Stand runs at a fixed wave count like 30 instead of truly infinite, so it terminates) and invokes the headless Godot binary once per combination with the appropriate arguments, so I can kick off a full data-generation pass with one command.

### 4. Safety/sanity checks
- If the bot ever has no legal action available (e.g. can't afford anything and board is full) it should just wait, not error out or hang the process — but log a distinct event (e.g. `bot_idle`) so I can spot if a run is stuck doing nothing for suspiciously long, since that itself might indicate a balance problem (or a bot bug) worth investigating.
- Add a hard timeout per run (configurable, e.g. 10 real-world minutes) that force-ends a run and logs it as `run_timeout` if something goes wrong and it never naturally concludes — so one broken run can't hang the entire batch script.

## What I want from you

1. Propose where `AutoplayBot` lives (autoload vs. a node added only in a headless/testing context) and how it hooks into my existing purchase/placement code paths.
2. Write the bot's decision logic for all four strategies and the placement heuristic.
3. Write the command-line argument parsing and the multi-run-per-process loop.
4. Write the wrapper shell script.
5. Tell me clearly which parts you had to guess at because my project description above was incomplete, especially around the placement heuristic and the purchase function signatures — I'd rather you flag gaps than silently assume function names that don't match my actual code.

Ask me clarifying questions first if anything above is unclear before writing code.