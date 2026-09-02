# Chess Kingdom Defense (working title)

A roguelite tower-defense game where your chess pieces defend the King from an endless tide of shadow chess pieces. Think *chess*, but every piece shoots, moves, and fights on its own — and the enemy is coming from every direction, not just one lane.

## ⚠️ This is a very early, very sketchy demo

This is a hobby project I'm building solo to test whether the core idea is fun *before* investing in real art, sound, or polish. What you're looking at is a prototype, not a game:

- Placeholder art (AI-generated or literal colored squares in places)
- Only **one enemy piece type** is active in this demo (Rook) (although the code for every piece is ready)
- No wave system, shop, or currency yet — this build exists purely to test movement and combat feel for each player piece
- Expect bugs, weirdness, and things that are obviously unfinished

## The idea

Your King sits at the center of the board. Shadow chess pieces spawn at the edges and march toward him from all sides — not in lanes, but genuinely surrounding him. You place your own chess pieces around the King to intercept them before they arrive. Each piece attacks the way you'd expect from real chess (a Bishop only threatens diagonals, a Knight jumps in an L-shape, etc.) — but reimagined as ranged, automated defenders rather than pieces you manually move.

The long-term goal is a run-based structure: survive a fixed number of waves, earn points based on standard chess piece values for each kill, and spend those points between waves to buy and place more pieces.

## Current demo scope

Right now this build only tests player-piece feel in isolation against one enemy type:

- **Enemy:** Shadow Rook only
- **King:** has **3 lives** — each time an enemy reaches him, he loses one. Lose all three and the run ends.
- **No shop, no currency, no waves yet** — this is purely a combat/movement sandbox

## Controls

Switch which piece you're currently playing with these keys:

| Key | Piece |
|-----|-------|
| `P` | Pawn |
| `N` | Knight |
| `B` | Bishop |
| `R` | Rook |
| `Q` | Queen |

Click/tap a tile to place the currently selected piece there. Drag a currently placed piece to change its location.

## Why chess?

Most tower-defense games ask you to learn a new set of rules for how each unit behaves. Chess players already know exactly how a Bishop or a Knight moves — so instead of teaching new mechanics from scratch, this reuses rules millions of people already have memorized, and asks a different question: *what happens if these pieces could act on their own?*

## What's next

- Full wave system with escalating difficulty
- Currency + shop + drag-and-drop piece inventory
- Actual art, sound, and juice (screen shake, hit effects, etc.)
- Real playtesting and balance passes

## Feedback

This is a one-person hobby project and very much a work in progress. If you have thoughts, bugs, or "I got stuck here" moments, please open an issue — that's the entire point of putting a rough demo out early.
