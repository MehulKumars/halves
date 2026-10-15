---
name: game-design-review
description: Review or shape a mobile game design before or during building: core loop, first 60 seconds, difficulty curve, fail state, juice level, ad and IAP placement, touch and accessibility, and keep/kill lines, using rules that change by game type (tile/mahjong, sort, word/daily, block, arcade, physics, idle, survivor). Use this whenever the user pitches or compares game ideas, asks whether a game will work or is fun, plans a new game or level pack, adds ads, boosters or purchases, or reviews a prototype or playtest, even if they never say "design review".
---

# Game design review

The goal is to catch design problems while they are cheap: before code, or right after a greybox.
There is no single rulebook. A short list of rules holds for every game; almost everything else
(difficulty shape, juice, session length, fail state, ad frequency) depends on the game type, so
always identify the type first and judge against that type's norms.

## Workflow

1. **Name the game type(s)** and read the matching row and notes in `references/genre-rules.md`.
   Hybrids take the stricter rule of each parent (for example a word game with a daily mode never
   shows ads in the daily).
2. **Universal rules** (every type). Flag any breach as a problem:
   - Clear feedback; responsive, forgiving input.
   - Touch targets at least 48 dp (about 96 px on the template's 720-px canvas); primary actions
     in the bottom third; pause and rare actions away from the thumb.
   - No information carried by colour or sound alone (about 1 in 12 men has red-green colour
     blindness; many players play muted). Pair colours with shapes or patterns.
   - Pause and save on interruption; Android Back opens the pause menu.
   - Honest ads and store pages: the store video must show the real game.
   - No loot boxes or paid random rewards.
   - Kill lines written before building.
3. **Core loop.** Every core loop needs Action, Reward and Progress; one missing and it "won't work"
   (Mobile Free to Play). Ask: can the designer list at least five ways the core varies? If not, the
   game will run out of content. Prefer loop-heavy formats (endless, daily, generated) over
   arc-heavy ones (thousands of handmade levels) for a solo or duo studio.
4. **First 60 seconds.** Launch straight into play with one highlighted action, first win within
   about a minute, one new idea per level, no menus, shop or consent prompt before the first win.
   Use the type-specific version from the reference file.
5. **Difficulty and failure.** Sawtooth packs with rest levels for level-based games; in-run ramps
   for endless games. Fairness comes from forgiveness (undo, stuck detectors, coyote time), not
   from making everything easy. Never put a paid offer on the fail screen of a spike level without
   a free path: it reads as manipulation.
6. **Juice register.** Check the type's register (calm, crescendo-only, physical, loud-but-readable).
   Juice belongs on player success: a pre-registered CHI 2024 study (1,699 players) found effects
   amplified for their own sake lowered players' sense of competence. Anything that hides a piece,
   an enemy or the score is a bug.
7. **Monetization.** Check against the template's `AdPolicy`: interstitials only when a results
   screen opens, never on Next / Retry / Play again, never at level start or during play, none in
   the first session, none in daily or zen modes. Rewarded ads are opt-in, clearly labelled and
   deterministic. In-app purchases only after the game passes Keep.
8. **Market check (only for trend-driven formats).** Search the latest Sensor Tower monthly
   top-10 before committing. Fads are short: arrow puzzles were #1 by downloads in May 2026 and out
   of the top 5 by September (about 4-5 months). Prefer lasting families (sort, block, mahjong,
   word) with one twist. Search Google Play for close clones of the twist.
9. **Keep/kill lines.** Use the benchmark table in the reference file; judge only on 500+ installs
   from strangers.

## Output format

```
## Verdict
Build / Fix first / Drop, in one sentence with the main reason.

## What already works
- ...

## Problems (most serious first)
1. <problem> — breaks <rule> because <why it matters for this game type>. Fix: <concrete change>.

## Keep/kill lines for this game
| Metric | Kill | Keep |

## Test in the next playtest
- <the 1-3 questions a silent playtest should answer, e.g. "do players press retry unprompted?">
```

Keep it concrete: name the screen, level or mechanic each point is about. Do not pad with generic
advice that applies to every game; the universal rules only appear when they are actually broken.
