# Chess Kingdom Defense — Home Office Hotspots + Staged Tutorial: AI Agent Implementation Plan

_Source brief: `tasks/home-office-interaction-brief.md`. Current architecture: `tasks/ARCHITECTURE_NOTES.md` (read as instructed)._
_Written 2026-10-01 against commit `a6f6a07` ("Change the piece sprites"). Everything below was verified against the live codebase and assets before planning._

> **Process rule (per the user): after every stage with a 🛑 **STOP AND CONFIRM**, the implementing agent must STOP and confirm with the user before proceeding to the next stage. Do not batch stages.

---

## 0. Verified context and findings (brief item 1)

What the agent will actually be building on, confirmed in current source and assets:

### The Home Office scene today (`scenes/home_office.tscn` + `scripts/home_office.gd`)

- Full-rect `Control` root with: `FallbackBackground` (ColorRect), `Background` (`TextureRect` with `assets/home_office.jpg`), and a `Margin/Layout` VBox containing a **"THE HOME OFFICE" title label**, an `OfficeMaterialLabel`, and an `OfficeCard` with **four visible text Buttons** — `PlayButton`, `SkillsButton`, `BestiaryButton`, `EarnMaterialButton` — wired in `home_office.gd` to `SceneRouter.go_level_select()` / `go_skill_shop()` / `go_bestiary()` / `go_learning_openings()`.
- So the brief's target state ("no visible button UI — invisible tap zones over the art") is a **replacement** of the current button/card UI, not merely an addition. The zone system takes over all four navigation duties; the card and its buttons go away (labels: pending Q1 below). `home_office.gd` also manages the Office Material label via `OfficeMaterialManager.office_material_changed` (connect in `_ready`, disconnect in `_exit_tree`) — that pattern must survive.

### The background asset (`assets/home_office.jpg`)

- **1376 × 768 px, aspect ≈ 1.792 (~16:9), one flat static image** — no separable layers for the window, trophies, coins, or case. This decides two things the brief asked to be flagged:
  1. **The Part 0.5 flare must use the "overlaid light-bloom sprite" approach** — a soft additive glow placed over the window's image region and tweened. The "brightness tween on an existing window layer" approach is impossible with flat art.
  2. **Press-feedback cannot literally scale only the tapped art element** (no separable layer). The glow overlay *can* be scoped tightly to the element; the optional scale-pulse must be faked (Stage 1). The brief allows glow "and/or" scale-pulse, so glow-only is compliant.
- The `Background` TextureRect uses `expand_mode=1` + `stretch_mode=6` (**STRETCH_KEEP_ASPECT_COVERED**): on any aspect other than ~16:9 the image is **center-cropped**, not letterboxed. **Hotspot zones defined in image-pixel coordinates must therefore be mapped through the actually-drawn texture rect** (cover-fit math), not the control's rect — the single most error-prone detail in this task; it gets a dedicated helper (Stage 1). With the project's `expand` stretch (full-bleed brief, already implemented), this mapping must recompute on resize.

### Input-handling patterns (for tap zones)

- No polygon hit-testing exists anywhere in the project; all hit-testing is rectangular (Buttons, `shop_slot._gui_input`, `is_valid_placement_cell`). **Zones as rectangles in image-pixel space is the pattern-consistent choice** (the brief's "rectangle or polygon, whichever your patterns favor" → rectangle).
- Both conventions already exist: `shop_slot` reacts on press-down; hub `Button`s act on release (the `pressed` signal). The brief wants feedback on press-down and the popup "on release, whichever your existing conventions use" — hub scenes act on release, so: **glow on press-down, popup opens on release** (release outside the zone cancels, like a button).
- Title screen (`title_screen.gd`) advances on any press or after a 2 s `AdvanceTimer`, then calls `SceneRouter.go_home_office()` — an instant, fade-less swap today. The title's `background_texture` export is **not set in the scene** (title shows only its dark `FallbackBackground` + text), which simplifies the crossfade (Stage 3).

### Save/progress tracking (for tutorial stages)

- `SaveData` is the sole persistence boundary (sectioned `user://save.cfg`); every feature manager owns one section. The tutorial needs a **new small section + manager** following this exact pattern (Stage 4).
- **"Won" vs "attempted" is already distinguishable — no save addition needed** (brief item 6 asked this to be flagged): `LevelProgressManager.complete_level()` is called **only** from `main.gd::_on_level_completed` (the WIN path); losses/timeouts never mark completion. So `is_level_completed("level_1")` is precisely "won Level 1". Stage 2's trigger: `is_level_completed("level_1") AND NOT tutorial_stage_2_done`.

### The four content scenes (popup interiors, brief item 7)

- `level_select.tscn` (`%LevelOneButton`…`%FinalStandButton`), `skill_shop.tscn` (`%OfficeMaterialLabel`, `%SkillsContainer`, `%BackButton`), `bestiary.tscn` (`%EntriesGrid`, `%BackButton`), `learning_openings.tscn` (`%OfficeMaterialLabel`, `%RemainingUsesLabel`, `%ClaimButton`, `%StatusLabel`, `%BackButton`). All are full-rect standalone `Control` scenes whose scripts build content in code and whose **back buttons call `SceneRouter.go_home_office()`** — the main thing to adapt for popup embedding (Stage 6).
- The gameplay pause menu (`pause_overlay.gd`) already exists with Resume / Settings (placeholder) / Return to Home Office — the optional "Replay Tutorial" entry has a natural home there (Stage 7, optional, pending Q4).

---

## Stage 0 — Plan review + clarifying questions (no code)

**Do:** Confirm the four zone **anchor regions in the art** (the agent can open `assets/home_office.jpg` directly to estimate coordinates — the implementing agent reads image files — but the user should confirm which art elements map to which menu, since they know the illustration's intent).

Questions to put to the user before any code:

- **Q1 — Existing labels.** With the button card removed, should the "THE HOME OFFICE" title label go away entirely (the art speaks for itself), and should the `OfficeMaterialLabel` stay as a small corner readout (it's not a button, so it doesn't violate the no-visible-button rule — and it's the only always-visible Material display in the hub), or move into one of the popups only?

Remove both. The office material should show in the skills page and the earn materials page.

- **Q2 — Zone rectangles.** Agent proposes approximate rectangles over: desk chessboard (Play), trophy shelf (Skills), glass display case (Bestiary), ledger/coins (Earn Materials) — user confirms/refines in Stage 1's calibration pass.

A: The positions are following:

Zone  x_min y_min x_max y_max Width Height
Play (chessboard) 460   410   875   585   415   175
Skills (trophy shelf)   15 55 300   420   285   365
Bestiary (display case) 1035  140   1295  445   260   305
Earn Materials (ledger/coins) 860   490   1330  715

- **Q3 — Stage 2 presentation.** All three zones highlighted together in one overlay (agent's recommendation: simplest, least friction) vs. a quick three-step spotlight sequence. User picks.

A: Highlight in a sequence please.

- **Q4 — Replay-tutorial menu entry.** Add an optional "Replay Tutorial" button to the gameplay pause menu (resets tutorial flags; takes effect on next Home Office visit), or skip it?

A: No replay tutotial menu in the game pause.

- **Q5 — Popup frame art.** The agent will build the themed frame from theme styles (wood-brown fill, gold border, rounded corners, chess-motif clasp) since no frame art asset exists. OK for now, with real frame art as a later asset-swap — or does the user want to commission/provide art first?

A: Don't put too much effort on it right now. Use a simple but good looking placeholder for illustration.

---

## Stage 1 — Hotspot zones: definition, mapping, calibration, press feedback (brief item 2 / Part 0)

**Build:**

1. New `scripts/home_office_zones.gd` + refactor of `home_office.tscn`:
   - Remove `Margin/Layout`, `OfficeCard`, and the four Buttons (their `SceneRouter` calls move into the zone handler). Retain/adjust labels per Q1.
   - Add a `Zones` full-rect `Control` (mouse_filter = STOP) as the input layer above `Background`. It owns four zone descriptors as exported data:
     `zone_id` (`play` / `skills` / `bestiary` / `earn`), `label` (for tutorial text), and `rect: Rect2` in **image-pixel coordinates** of the 1376×768 art.
2. The cover-crop mapping helper (in `home_office_zones.gd`):

```gdscript
## The Background TextureRect is STRETCH_KEEP_ASPECT_COVERED: the image is
## center-cropped at non-16:9 aspects. Zones live in image pixels, so they must
## be mapped through the portion of the texture actually drawn on screen.
func _image_to_screen_rect(image_rect: Rect2) -> Rect2:
    var control_size := background.size
    var scale := max(control_size.x / texture_width, control_size.y / texture_height)
    var drawn_size := Vector2(texture_width, texture_height) * scale
    var drawn_origin := (control_size - drawn_size) / 2.0   # cover-fit is centered
    return Rect2(drawn_origin + image_rect.position * scale, image_rect.size * scale)
```

   Recompute on `size_changed` (the project already has the resize-aware pattern from `ScreenLayout` in gameplay; mirror it here). Texture size is read from `background.texture.get_size()`, not hard-coded.
3. Input handling on the `Zones` control: `_gui_input` with `InputEventMouseButton` — on **press-down** inside a zone: fire that zone's press feedback; on **release** inside the same zone: trigger the zone's action (popup in Stage 6; until then, a `push_print`/placeholder so Stage 1 is testable standalone); release outside the zone: cancel feedback, no action. One press tracked at a time (touch).
4. **Press feedback (required)**: for the pressed zone, show a soft additive glow over exactly that zone's screen rect and fade it out on release/cancel:
   - Glow = a `TextureRect` (or `Control` + `_draw` radial) using a generated `GradientTexture2D` (radial fill, white→transparent), `self_modulate` warm gold, blended additively (`CanvasItemMaterial` BLEND_MODE_ADD), alpha tweened 0.0 → 0.35 over ~0.12 s ease-out, out over ~0.2 s. Scoped to the zone rect so the trophy glow never bleeds into the chessboard (brief requirement).
   - Optional scale-pulse: since the art is one flat image, implement as a tiny whole-background zoom (pivot at the tapped element's center, scale 1.0 → 1.015 → 1.0, ~0.25 s). Subtle enough to read as the element responding. Implement **only if** it looks good in review; glow alone satisfies the brief.
5. **Calibration mode**: `@export var show_debug_zones := false` — when true, draws the four screen-mapped rects with thin colored outlines and their ids (this is tooling for the developer, never on in normal state — the brief's "no debug-looking rectangles in normal state" refers to the idle UI, which stays clean). Use it to tune the image-space rects live. The agent bootstraps initial rect values by inspecting `home_office.jpg` directly, then the user verifies in-game.

**Verify:** zones light up on press in a 16:9 window **and** after resizing to 16:10 (mapping survives the crop); glow stays inside its element; no rectangles visible with debug off; all four zones tappable via mouse and touch emulation.

---

## Stage 2 — Ambient idle cues (Part 0, optional-but-recommended)

**Design decision (brief allows 1–3; propose implementing two):** coins shimmer (Earn Materials) + trophy glint (Skills). The display-case pulse reads worst against bright glass art and is the first to cut if any cue feels noisy; the chessboard gets none (per the brief). Concrete parameters, tuned to read "the scene is alive", not "look at me":

- **Coins shimmer (Earn Materials):** one small additive glow element (same generated radial gradient as Stage 1) over the coin cluster, looping a slow triangle-wave alpha **0.00 → 0.10 → 0.00 over 4.0 s**, plus a second offset sparkle dot (few px) with the same loop at a **+1.7 s phase offset**, so the glint appears to wander.
- **Trophy glint (Skills):** a narrow additive highlight over the medals, pulsing alpha **0 → 0.12** on a **5.5 s cycle** with a short 0.5 s attack / 0.8 s release inside it (a periodic glint, not a steady glow).
- Both are children of the same `Zones` node, driven by `Tween` loops (`set_loops()`), created in `_ready`, cheap enough to run always. No new art assets — generated gradients only. If either cue proves distracting in review, drop it at the checkpoint rather than lowering the intensity further.

**Verify:** cues loop indefinitely without visible popping; pausing/losing focus doesn't desync anything; cues are invisible in screenshots at a glance (subtlety bar).

**🛑 STOP AND CONFIRM** — demo the press glow on all four zones, with debug rects on and off, at two window aspects. Ask the user to confirm/adjust each zone rectangle against the art (calibration is explicitly a joint step) and whether the scale-pulse should stay. demo both cues in motion, ask: keep both / keep one / drop both, and whether intensities/durations feel right. (Also confirm the third cue is genuinely skipped.)

---

## Stage 3 — Title → Home Office crossfade + window flare (Part 0.5, brief item 3)

**Flagged approach (per §0): overlaid bloom sprite** — the art is one flat jpg, so the flare is a soft additive glow element placed over the window's image region (same generated-gradient technique, warm white), NOT a brightness tween on a separable layer.

**Build:**

1. `SceneRouter` gains a small, additive flag: `var arriving_from_title := false`, set `true` by `title_screen.advance()` right before `go_home_office()`, and cleared by the Home Office after it consumes it. (This keeps the transition inside the two existing scenes — no second Home Office instance, no double `_ready`, and the tutorial/zone systems initialize exactly once.)
2. In `title_screen.gd::advance()`: call `SceneRouter.go_home_office()` as today (the crossfade is executed by the Home Office, not the title).
3. In `home_office.gd::_ready()`, if `arriving_from_title`:
   - Add a full-rect `TransitionOverlay` above the background: a `ColorRect` in the title's dark fallback color (`0.07, 0.09, 0.14`) plus a centered "CHESS KINGDOM DEFENSE" label styled like the title's — replicating the title screen's final visual, since the title has no background art of its own (verified in §0).
   - Tween over **0.55 s** (overlapping, matching the brief's 0.5–0.6 s): overlay modulate alpha 1 → 0 (title fading out) while the office `Background` modulate alpha 0 → 1 (office fading in underneath).
   - **Window flare:** the bloom element over the window region ramps alpha 0 → 0.5 → 0 with its **peak at ~0.27 s** (the crossfade midpoint), a 0.15 s ramp up and 0.4 s decay — "warm light spilling into view".
   - On completion: free the overlay, clear the flag. Zone input (`Zones.mouse_filter`) stays disabled until the fade ends so taps can't mid-fire the popup during the transition (one-line guard).
   - Repeat visits (popup close, returning from gameplay) skip all of this — the flag is only set by the title screen, exactly once per session, per the brief.
4. Reuse Stage 1's `_image_to_screen_rect` to position the flare over the window's image coordinates (window rect is a fifth calibrated region, tuned with the same debug overlay).

**Verify:** launch from title (wait out the 2 s timer AND via tap-to-skip) — both paths crossfade with the flare peaking mid-fade; window rect lands on the window art at 16:9 and 16:10; returning from gameplay shows no fade; no double signal connections (Office Material label correct after transition).

**🛑 STOP AND CONFIRM** — demo the transition (both auto and tapped entry). Ask: flare intensity/positioning, fade duration, whether the title text replica in the overlay reads correctly (it's a re-implementation of the title's final frame, not a screenshot — check the fonts match).

---

## Stage 4 — Tutorial manager + Stage 1 overlay (Part 1, brief items 4 & 6)

**Build:**

1. **`scripts/tutorial_manager.gd`**, a new autoload following the existing manager pattern exactly (`BestiaryManager`/`DailyRewardManager` shape — small, one `SaveData` section, no signals needed initially):

```gdscript
extends Node

## Persistent tutorial completion. One SaveData section, one key per stage.

const SAVE_SECTION := "tutorial"
const STAGE_1_KEY := "stage_1_done"
const STAGE_2_KEY := "stage_2_done"

var stage_1_done := false
var stage_2_done := false

func _ready() -> void:
    stage_1_done = bool(SaveData.get_value(SAVE_SECTION, STAGE_1_KEY, false))
    stage_2_done = bool(SaveData.get_value(SAGE_SECTION, STAGE_2_KEY, false))

func complete_stage_1() -> void:   # and _complete_stage_2, same shape
    stage_1_done = true
    SaveData.set_value(SAVE_SECTION, STAGE_1_KEY, true)

## Stage 2 shows when Level 1 has been WON (not attempted) and Stage 2
## hasn't been shown yet. "Won" is already tracked exactly:
## LevelProgressManager.is_level_completed() is set only on the WIN path.
func should_show_stage_2() -> bool:
    return not stage_2_done and LevelProgressManager.is_level_completed("level_1")

func reset_for_replay() -> void:   # only used by the optional pause-menu entry (Q4)
    stage_1_done = false ; stage_2_done = false
    SaveData.set_value(SAVE_SECTION, STAGE_1_KEY, false)
    SaveData.set_value(SAVE_SECTION, STAGE_2_KEY, false)
```

   Register as `TutorialManager` in `project.godot` (one additive autoload line). **Note for the implementing agent: the sketch above contains a deliberate-style typo check — verify every symbol against the real manager patterns before committing (e.g. `SAGE_SECTION` must obviously become `SAVE_SECTION`); do not copy-paste blind.** (Fix the typo when writing the real file.)

2. **Stage 1 overlay — proposed visual treatment (brief item 4, user confirms):**
   - Full-rect `TutorialOverlay` Control above `Zones`: everything darkened via a `ColorRect` at **alpha ~0.55**, with a **hole cut over the Play zone** — implemented as a `Control._draw` drawing the dim quad minus the zone rect (four rects around the Play zone), so the board stays fully bright while the rest dims. A **soft spotlight edge** (one inner glow element ring, same generated-gradient trick, faint 0.15 alpha) frames the hole so it doesn't read as a debug cutout.
   - One text callout above/below the board zone: *"Tap the board to begin your first defense."* in the game's existing label style (gold, dark outline — same as title labels).
   - **Dismissal:** tapping the Play zone (which then proceeds normally — opens the Level Select popup exactly as a non-tutorial tap would) completes Stage 1. **Tap-anywhere-else skips early** (also marks Stage 1 done — the brief requires skippable; a skipped tutorial never returns). Both paths call `TutorialManager.complete_stage_1()`.
   - The other three zones remain tappable underneath during Stage 1 (brief: "can still be tapped if the player happens to find them") — the overlay's dim quad must therefore pass input through to `Zones` everywhere except its own dismissal logic (mouse_filter settings: overlay = IGNORE, dismissal handled by the `Zones` input path consulting the tutorial state — simplest is one shared input path, no competing `_gui_input`).
   - Only ever shows once: gated by `not TutorialManager.stage_1_done` in `home_office._ready()` (after the Stage 3 crossfade finishes, if transitioning from title).

**Verify:** fresh save (`user://save.cfg` deleted) → Stage 1 appears on first entry, Play tap opens Level Select and marks Stage 1; second visit shows nothing; tap-anywhere skip works and persists; other zones still open during Stage 1.

---

## Stage 5 — Stage 2 overlay, win-gated (Part 1, brief item 6)

**Trigger (in `home_office._ready()`, after Stage 1's gate):** `TutorialManager.should_show_stage_2()` — i.e. first Home Office visit **after winning Level 1** (losses never trigger it, since completion is win-only — verified in §0; no save-schema addition was needed, and say so in the final report). Mark `stage_2_done` **when the stage ends by any path** (zone tapped, or early skip), per the brief's "track separately, never re-trigger".

**Presentation (default = Q3's answer; the agent's recommendation is "together"):** same dim-and-hole technique as Stage 1, but with **three holes** (Skills, Bestiary, Earn Materials — the chessboard stays dimmed; Play is old news). One text line spanning the bottom: *"Study your skills, review your foes, and earn extra material."* Tapping any of the three called-out zones dismisses the overlay **and opens that zone's popup normally** (the brief's requirement); tapping elsewhere skips the rest of the stage (marks done). If the user chose the sequential variant at Stage 0, instead run three one-hole spotlights in order (Skills → Bestiary → Earn), advancing on each zone tap (opening its popup between steps, resuming the sequence when the popup closes), skip-anywhere exits the whole stage.

**Verify:** with a fresh save — win Level 1 → Stage 2 shows on return, all three zones covered in one pass, each zone tap dismisses + opens correctly; lose Level 1 → Stage 2 does **not** show; win after a long earlier session → shows exactly once, then never again; Stage 1 and Stage 2 never both appear.

**🛑 STOP AND CONFIRM** — demo Stage 1 on a fresh save, on an already-completed save, and the skip path. Ask: spotlight dim intensity, callout text/wording, placement of the text (above vs below the board art). demo the full lifecycle across a fresh save: Stage 1 → win Level 1 → Stage 2 → persistence. Ask: presentation choice (if not settled at Stage 0), dim/hole intensity for the three-zone case, text wording.

---

## Stage 6 — Popup system: frame, transitions, and the four embedded contents (Part 2, brief items 5 & 7)

**Frame design proposal (brief item 5 — one shared frame, recommended):** a single "opened ledger" frame — an ornate dark-wood panel with a gold border (StyleBoxFlat now: warm brown `#3B2A1A`-ish fill, `#C8A24A`-ish 3px border, large corner radius, inner shadow feel via a second darker margin layer), sized ~75% of the shorter screen axis, with a small circular **wax-seal close button** (dark-red disc + "✕") at the top-right corner, overlapping the border. One frame serves all four zones: Level Select as "campaign ledger pages", Skill Shop as "study ledger", Bestiary as "creature ledger", Earn Materials as "accounts ledger" — the book/ledger metaphor fits the office's wood-and-gold aesthetic and all four interiors are list/grid content, which suits a book-shaped panel. The brief invites flagging if a zone genuinely needs a different shape — none does, but Bestiary is the best future candidate for a bespoke "display case" frame once real art exists. Per Q5, the frame is themed styles now, texture-swappable later.

**Build:**

1. **`scenes/popup_container.tscn` + `scripts/popup_container.gd`** — a full-rect overlay instantiated by `home_office.gd` (not by the content scenes):
   - `Dimmer` ColorRect, **alpha 0.45** (office art stays readable behind — "still in the office, just focused"), tap on it = close (frictionless exit per the brief).
   - `Frame` PanelContainer (the styled frame) containing a `Content` Control (the embedded scene's parent).
   - `CloseButton` (wax seal). Both close affordances call the same `close()`; also `ui_cancel` (Esc) closes, consistent with desktop testing.
   - **Open transition:** frame starts at `scale 0.6`, `pivot` at the tapped zone's screen center, modulate alpha 0 → tween to scale 1.0 / alpha 1 over **0.22 s** (TRANS_BACK, EASE_OUT) — the scale-up-from-tapped-point default the brief suggested. Close reverses over 0.15 s.
   - `open(zone_id, source_screen_position)` instantiates the right content scene into `Content` (see 3) and plays the transition; `close()` frees it.
2. **Dimming interplay:** while a popup is open, `Zones` input is disabled (one-line guard, same flag pattern as the Stage 3 crossfade guard) — the dimmed background shows through but doesn't react; ambient cues pause (cheap `set_process(false)` on the cue tweens) so the popup owns attention.
3. **Embedding the four content scenes (brief item 7 — reuse, don't rebuild):** each existing scene is already a full-rect `Control` built in code with `%unique_name` nodes — they embed cleanly if their back-button navigation is redirected. Minimal, uniform convention (flagged as the one edit class each content script needs):
   - Each content script gains `var embedded := false` and a `close_requested` signal; its `_on_back_pressed` becomes: `if embedded: close_requested.emit()` `else: SceneRouter.go_home_office()` — preserving standalone behavior (the scenes stay reachable via `SceneRouter` for other callers, and the change is 3 lines per script).
   - `popup_container.gd` sets `content.embedded = true` and connects `close_requested → close()`.
   - **Level Select is the exception (brief):** its buttons call `SceneRouter.start_level(...)`, which changes the scene to gameplay — the popup and Home Office die with the scene change naturally. No breakout code needed; verify it doesn't need the `embedded` treatment beyond hiding nothing (its back button still gets the convention, closing the popup back to the office).
   - Sizing: embedded scenes keep their own internal layouts; `Content` sizes the scene with `anchors_preset 15`-equivalent (set `position`/`size` to the frame's content rect). The content scenes were full-screen-designed; inside a ~75%-axis frame their margins compress — acceptable per the brief (popup is a presentation layer), but **flag at the checkpoint** if any of the four looks cramped, especially Level Select's 6 buttons.
4. **Zone → popup wiring:** `home_office_zones.gd`'s release action (from Stage 1) now calls `popup.open(zone_id, screen_position)` instead of the placeholder. The old `SceneRouter.go_*` hub routes remain in `SceneRouter` (unused by the hub now, still valid for the standalone scenes' fallback and any future caller) — do not delete them.

**Verify:** every zone opens its popup with the tap-point origin animation and the dim behind; close via seal, dim-tap, and Esc; each popup's content works end-to-end: Skills buy (Office Material label in popup updates), Bestiary cards show, Earn Material claims a daily reward, Level Select launches gameplay (breakout clean, no leaked popup nodes in the gameplay scene); `embedded` fallback still works if a scene is ever opened standalone; popup content survives a window resize (re-run the cover mapping + popup anchors).

**🛑 STOP AND CONFIRM** — demo all four popups open/close/interact + the Level Select breakout into gameplay. Ask: frame proportions/position on screen, dim level, transition speed, whether any interior (esp. Level Select) is too cramped at the chosen frame size, and seal button placement.

---

## Stage 7 — Integration pass, optional replay-tutorial entry, regression, docs

**Build:**

1. **Optional (Q4): "Replay Tutorial"** in the gameplay pause overlay (`pause_overlay.gd` already has Resume / Settings / Home Office): a fourth button calling `TutorialManager.reset_for_replay()` then returning to the Home Office via the existing `end_run_with_result("ABANDONED")` path (reusing the pause menu's established exit — no new navigation code). It fits the menu's existing pattern cleanly; skip entirely if the user declines.
2. **Regression sweep:**
   - Fresh-save full journey: launch → crossfade + flare → Stage 1 → Play popup → win Level 1 → Stage 2 (three zones, popups) → persistence across relaunch.
   - Returning-from-gameplay path: no crossfade, no tutorial re-show.
   - **AutoplayBot smoke run** (`--strategy=balanced --level=level_1 --runs=2`): the bot passes *through* the Home Office between runs (`SceneRouter.go_home_office()` is the run-end destination); confirm zone input and tutorial overlays don't block programmatic navigation (`start_level` doesn't route through `Zones` input), that no tutorial popup/overlay appears mid-headless-run, and that runs still complete with clean logs. Also note: on a *fresh* save the Stage 1 overlay will technically flash between bot runs — harmless, but worth confirming visually in the log timestamps.
   - Resize mid-everything: zones remap (cover-crop), popup content re-anchors, cues keep looping.
3. **Docs:** append a Home Office section to `tasks/ARCHITECTURE_NOTES.md`: zone system + cover-crop mapping contract (image-pixel coordinates), ambient cues, crossfade/`arriving_from_title` flag, `TutorialManager` (section, keys, win-gated Stage 2 via `is_level_completed`), popup container + `embedded`/`close_requested` convention, and the removal of the old hub button UI. Note in the README-stale list that hub screenshots/flow descriptions there are now outdated too.

**🛑 STOP AND CONFIRM — FINAL:** present the full journey end-to-end, the bot regression result, the doc diff, and the complete list of every existing file touched (`home_office.gd/tscn`, `title_screen.gd`, `scene_router.gd`, the four content scripts' 3-line back-button change, `pause_overlay.gd` if Q4 yes, `project.godot` +1 autoload, `ARCHITECTURE_NOTES.md`) versus files merely added. Ask for final sign-off.

---

## Deliverables checklist

```text
scripts/home_office_zones.gd      (new — zones, cover-crop mapping, feedback, cues)
scripts/tutorial_manager.gd       (new — autoload; tutorial section, 2 keys)
scripts/popup_container.gd        (new)
scenes/popup_container.tscn        (new)
scripts/home_office.gd            (rewired: zones + popups + crossfade + tutorial gates)
scenes/home_office.tscn            (button card removed; Zones/overlay nodes added)
scripts/title_screen.gd            (sets arriving_from_title; advance flow unchanged)
scripts/scene_router.gd            (+arriving_from_title flag; routes kept)
scripts/level_select.gd            (+embedded/close_requested, 3 lines)
scripts/skill_shop.gd              (+embedded/close_requested, 3 lines)
scripts/bestiary.gd                (+embedded/close_requested, 3 lines)
scripts/learning_openings.gd       (+embedded/close_requested, 3 lines)
scripts/pause_overlay.gd           (+Replay Tutorial button — only if Q4 approved)
project.godot                      (+1 autoload line: TutorialManager)
tasks/ARCHITECTURE_NOTES.md         (appended section)
```

No gameplay, wave, combat, economy, or save-schema changes other than the new `tutorial` section. The four content scenes' internal logic is untouched beyond the 3-line back-button convention. Every stage ends with a 🛑 STOP AND CONFIRM — the agent must never proceed past one without the user's explicit go-ahead.





