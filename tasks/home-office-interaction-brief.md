# Design Brief: Home Office Hotspot Interactions + Staged Tutorial

Copy everything below into your AI coding agent. Reference `tasks/ARCHITECTURE_NOTES.md` for current project structure (scene names, existing UI patterns, save/progress tracking) — this brief assumes you'll check there for implementation specifics rather than guessing at them.

---

## Context

The Home Office hub background is a single hand-illustrated scene (desk with chessboard, trophy shelf, glass display case, ledger with coins) representing four menu sections: **Play** (chessboard), **Skills** (trophy shelf), **Bestiary** (glass case), **Earn Materials** (ledger/coins). There is no visible button UI drawn over the art — interactivity comes from invisible tap-zones over each area plus subtle feedback animation, not icon/text buttons.

This brief covers two things: (1) a staged, two-part tutorial that introduces these zones progressively rather than all at once, and (2) a popup-window system for displaying each section's content without leaving the Home Office scene.

## Part 0: The four hotspot zones (no visible button UI)

The four menu sections are NOT represented by drawn buttons, icons, or text labels layered on top of the background art. The illustration itself is detailed and specific enough (a chessboard, a trophy shelf, a glass display case, a ledger with coins) that the interactive zones should be invisible by default, with interactivity communicated entirely through feedback animation, not button chrome.

**Defining the zones:**
- Four tap-target regions positioned over the corresponding art elements in the background image: the chessboard on the desk (**Play**), the trophy shelf (**Skills**), the glass display case (**Bestiary**), and the ledger/coins area (**Earn Materials**).
- Since this is one static background image, define each zone's tappable area as a rectangle or polygon in the image's coordinate space (whichever your existing input-handling patterns favor per `tasks/ARCHITECTURE_NOTES.md`), scaled/positioned correctly whatever the final screen-fitting approach is (reference the full-bleed/adaptive-sizing brief already implemented, if this background uses a similar adaptive scaling system).
- These regions should NOT be visually outlined or bordered in the normal (idle, non-tutorial) state — no debug-looking rectangles, no button-shaped backgrounds.

**Idle-state ambient cues (optional but recommended):**
To help players discover that the scene is interactive without resorting to visible buttons, add subtle looping ambient animation to one or more zones — small enough to read as "this scene is alive" rather than "this is a button":
- A faint shimmer or sparkle looping gently on the coins/gems (Earn Materials)
- A soft periodic glint on the trophy medals (Skills)
- A barely-perceptible pulse in the display case's interior lighting (Bestiary)
- The chessboard likely doesn't need one, since it's the Stage-1-tutorial-highlighted zone anyway and is already the most visually obvious "this is the main action" element in the scene
These should be subtle enough to not be distracting during normal viewing — propose specific animation parameters (duration, intensity) that read as ambient rather than attention-grabbing, and feel free to only implement one or two of these rather than all three if that reads better once in motion.

**Press/tap feedback (required, this is the primary interactivity signal):**
- On tap-down: the zone's art region responds directly — a soft outward glow around just that element, and/or a gentle scale-pulse (~105%, short duration, ease-out) centered on that element specifically, not the whole screen.
- This feedback should fire immediately on touch (not wait for touch-release) so it reads as responsive, then proceed to open the corresponding popup (per Part 2) shortly after or on release, whichever your existing input-handling conventions use elsewhere in the project.
- Keep the feedback scoped tightly to the tapped element's visual bounds — e.g. the glow around the trophy shelf shouldn't bleed into the chessboard area — so it's clear which zone was actually activated.

## Part 0.5: Title screen → Home Office transition

Simple crossfade, with one small enhancement worth the minimal extra effort:

- **Base transition:** the title screen fades out (alpha 1→0) while the Home Office background fades in (alpha 0→1) underneath it, simultaneously, over roughly 0.5-0.6 seconds total. Standard crossfade, no camera movement or scene-complexity required.
- **Enhancement — light flare synced to the midpoint:** the Home Office art already has a bright arched window as a light source. Add a brief brightness pulse to that window's light/glow (a quick ramp up and back down, timed so its peak roughly coincides with the crossfade's midpoint) so the transition reads as "warm light spilling into view" rather than a generic UI fade. This is a single additional tween on an existing element in the art — it should not require new art assets or a new animation system, just an extra brightness/opacity tween on the window region (or a simple overlaid light-bloom sprite if the background art is a flat static image with no separable window layer — flag which approach fits better given how the background asset is actually structured).
- This transition should only need to play once per session (title screen only appears at launch) — no special handling needed for repeat visits to the Home Office, since those happen via popup-close or returning from gameplay, not via this transition.

## Part 1: Staged tutorial

**Stage 1 — first-ever visit to the Home Office:**
- Only the **Play** zone (chessboard) is highlighted/called out. The other three zones should NOT be pointed out yet at this stage — they can still be tapped if the player happens to find them, but no tutorial attention is drawn there.
- Presentation: a brief overlay (your call on exact visual treatment — a soft spotlight/dimming of everything except the board, plus a short text callout like "Tap the board to begin your first defense," is a reasonable default) that dismisses when the player taps the Play zone (which should then proceed normally into Level Select).
- This stage should only ever show once — track completion in whatever save/progress system already exists per `tasks/ARCHITECTURE_NOTES.md`.

**Stage 2 — triggered specifically by winning Level 1** (not just attempting or losing it):
- On returning to the Home Office after a Level 1 **win**, show a second tutorial pass that calls out the remaining three zones: Skills, Bestiary, Earn Materials — together or in quick sequence, your call on which reads better, but all three should be covered in this single pass (don't stage it further into three separate visits).
- Same dismissal pattern: tapping a called-out zone during this stage both dismisses that callout and opens that zone's content normally.
- If the player loses Level 1, Stage 2 should NOT trigger — it waits for a win. (Flag to me if your save/progress system makes this distinction awkward to track, e.g. if only "level attempted" is currently recorded rather than "level won" — may need a small addition there.)
- Also track Stage 2 completion separately from Stage 1, so a player who wins Level 1 after an earlier session doesn't see Stage 2 re-trigger on a later visit.

**General tutorial requirements:**
- Both stages should be skippable/dismissible early (e.g. tap anywhere to dismiss immediately) for a player who doesn't want to wait out the full callout — don't force a fixed-duration animation with no skip.
- Consider whether a "replay tutorial" option belongs in the settings/menu accessed via the gameplay menu button (built in an earlier brief) — propose this if it fits cleanly with what else is already in that menu, but it's optional, not a hard requirement.

## Part 2: Popup window system for zone content

Instead of transitioning to a separate full-screen scene when a zone is tapped, each zone opens its content in a **themed popup window** layered over the (dimmed) Home Office background, which remains visible behind it.

**Visual style:** the popup frame should match the hand-illustrated art style of the background — e.g. styled like an opened book, an unrolled scroll, or an ornate window/frame consistent with the office's wood-and-gold medieval aesthetic — rather than a generic flat modal box. If a single frame design can reasonably serve all four zones (just with different interior content), that's preferable for consistency and build effort over four bespoke frame designs; propose this unless you think the content genuinely demands different frame shapes per zone (e.g. Bestiary as a book is a strong thematic fit, but if Play/Level-Select content doesn't suit a "book" shape as well, flag that and suggest an alternative that still fits the family).

**Behavior, all four zones:**
- Tapping a hotspot zone triggers the popup to appear (your call on transition — a quick scale-up-from-the-tapped-point-plus-fade-in is a reasonable default, consistent with the subtle press-feedback already planned for the hotspots themselves) with the Home Office background dimming slightly behind it (not fully obscured — should still read as "I'm still in the office, just focused on this").
- Each popup contains that section's existing UI content: Play → Level Select, Skills → Skill shop, Bestiary → Enemy guide, Earn Materials → the daily-click reward screen. Reuse the existing scenes/UI for each of these as the popup's content rather than rebuilding them — the popup is a new container/presentation layer, not a rebuild of what's inside it. Check `tasks/ARCHITECTURE_NOTES.md` for how these are currently structured so they can be adapted to render inside a popup container rather than as standalone full screens.
- Closing: a close affordance consistent with the frame's theme (e.g. a small wax-seal or clasp icon, if that fits the book/scroll motif) PLUS tapping outside the popup on the dimmed background should also close it, for a frictionless exit.
- Exception: once a popup leads somewhere with its own deeper navigation (e.g. Play → Level Select → actually starting a level), the popup frame is no longer relevant once gameplay begins — the transition from "Level Select popup" into "starting a level" should break out of the popup container into the full gameplay scene normally, not try to keep the game running inside a small framed window.

## What I want from you

1. Confirm what you find in `tasks/ARCHITECTURE_NOTES.md` relevant to existing save/progress tracking (for tutorial stage completion), existing input-handling patterns (for defining tap zones on a static background), and the existing Level Select / Skill shop / Bestiary / daily-reward scenes (for adapting them into popup content).
2. Define the four hotspot zones' tap regions and implement the press-feedback animation (Part 0), plus whichever ambient idle cues you think land well.
3. Implement the title-to-office crossfade with the synced light flare (Part 0.5), flagging which approach (layered light element vs. overlaid bloom sprite) fits the actual background asset structure.
4. Propose the tutorial overlay's exact visual treatment for Stage 1 and Stage 2.
5. Propose the popup frame design (one shared frame vs. per-zone variants, with reasoning) and its open/close transition.
6. Implement the win-specific trigger condition for Stage 2, flagging if the current progress-tracking system needs a small addition to distinguish "won" from "attempted."
7. Implement the popup container and adapt the four existing content scenes to render inside it, preserving their existing internal logic.

Ask me clarifying questions first if anything above is unclear, or if what you find in `tasks/ARCHITECTURE_NOTES.md` conflicts with an assumption in this brief.
