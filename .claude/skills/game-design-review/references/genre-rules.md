# Design rules by game type

Synthesised from the studio's October 2026 research (design-craft and genre notes, fact-checked).
Session lengths are design estimates per level or run. "Ads" gives the market norm, then this
studio's choice. Benchmarks are GameAnalytics 2025 data, iOS and Android combined.

## Comparison table

| Type | Session | Difficulty shape | Juice | Level generation | Fail state | Ads: market / ours | Main trap |
|---|---|---|---|---|---|---|---|
| Tile / mahjong match | 1-4 min per level | Sawtooth packs, rest levels, marked hard levels | Calm, tactile; on matches only | Built backwards (always solvable), bot-rated, baked | Dead board; cheap retry | Every 1-2 levels / none in session 1, then at most 1 per 2 won levels at results | Dead boards found late; tiny tiles |
| Sort / organise | 1-4 min per level | "Roller-coaster": hard and super-hard spikes, then breathers | Calm ASMR; crescendo when a container closes | Generate, then verify with a solver; baked | Buffer overflow, often late | Every level + paid continue / every 2 won levels, free rewarded continue | Reskin with no new decision |
| Word / category | 1-3 min; ~3 min daily | Slow sawtooth; abstraction rises | Calm; solve flourish | Human-written content, solvable deal, baked | None or soft | Between levels / never in the daily | Ambiguous content; paywalled hints |
| Block / grid endless | 2-8 min per run | Smooth in-run ramp as the board fills | Quiet placement, loud clears | Seeded weighted dealer with a fit check | No piece fits; one continue | Between runs / at results, never on "Play again" | Dealer dead boards; pure clone |
| Daily logic | ~3 min a day | Fixed daily bands; weekly shape | Calm, minimal | Generate-then-solve; 365 days baked | None (par only) | — / never in the ritual | Streak anxiety; date bugs |
| One-tap arcade | 0.5-2 min per run | In-run ramp with rest ledges | Loud but readable: hit-stop, shake, trails | Seeded chunk tables | Instant death; restart under 1 s | Every N deaths / run results only, never on Retry | Ad per death; unfair hitboxes |
| Physics toy / stacker | 2-4 min per run | In-run ramp; soft fail; zen mode | Physical, calm impacts | Seeded weighted shapes | Soft; instant retry | Light / never in zen | Physics randomness feels unfair |
| Idle / cozy | 1-3 min check-ins, many a day | Unlocks + exponential costs; no fail | Soft; on milestones and numbers | Per-player procedural; stored masks | None | Rewarded x2 offline / no interstitials | Waiting walls; art load |
| Survivor / roguelite-lite | 5-15 min runs | Time ramp + boss spikes; meta lowers difficulty | Loud but readable; capped | Seeded wave and draft tables | Death keeps meta currency | 1 rewarded per run / + results interstitial | Per-enemy nodes; clutter |
| Match-3, merge, rhythm | — | — | — | — | — | — | Avoid solo: thousands of handmade levels, huge item-chain art, and 165-500 ms Android audio lag in Godot |

## First 60 seconds by type
- **Puzzle (tile, sort, word, block):** first ten levels near-certain wins, each adding one element.
  The "98% completion" figure is for unmonetised hypercasual prototypes only.
- **Arcade:** dying within 20-30 s is fine if restart is instant.
- **Idle:** show growth and the first upgrade within the first minute; introduce offline earnings
  on the second session.
- **Roguelite:** a short first run that always pays a meta reward, even on death.
- Log the funnel: `tutorial_step_1`, `first_win`, `level_3_start`; fix the biggest drop first.

## Difficulty notes
- Stars in calm tile games: no researched mahjong or tile-match game (Microsoft Mahjong, Vita,
  Tile Busters, Zen Match) takes a star for a single wrong tap. Give an allowance that scales with
  the board (Halves: none lost on levels 1-10, then about one free slip per 15 pairs) and let undo
  take a slip back. Losing a star on the first slip read as harsh in Halves' playtests.
- Fully hidden pieces (face-down tiles) feel like blind guessing (Deconstructor of Fun on Zen
  Match): keep them rare and reveal them when they become playable.
- "New tile" variety must change what the player reads or decides, not add a dot: Halves v1's
  dot/line marks read as filler; families of look-alike motifs (5- vs 6-petal flowers) did not.
- Sawtooth evidence: ELIMINATION (nearly 1,000 players) raised difficulty over five levels and
  dropped it on the sixth; Where's My Water? uses the same pack shape.
- Introduce each new mechanic in a low-stakes level, never on a peak.
- "Easy to pass, hard to master" (low bar to pass, high bar for 3 stars) rests on one Cut the Rope
  interview; treat it as a useful pattern, not proven law.
- Skill games: prefer visible, opt-in assists (Celeste's Assist Mode). Hidden difficulty
  adjustment in casual puzzles is not confirmed as common practice; Deconstructor of Fun instead
  recommends letting players advance after several failed attempts.
- Near-miss evidence is mixed. "12 points from your best" is a harmless retry prompt; an engineered
  near-miss beside "buy 5 more moves" is manipulation.
- Idle pacing is maths: next cost = base x growth^owned (AdVenture Capitalist's first business: 1.07).

## Good and bad decisions (named)
- Good: Crossy Road (opt-in video ads, no energy timers), Monument Valley (no text tutorial, one or
  two new elements per level), Celeste (hidden forgiveness + opt-in assists), Wordle (one puzzle a
  day, spoiler-free share grid), Alto's Odyssey (zen mode), AdVenture Capitalist (offline progress).
- Bad: Dungeon Keeper mobile (advertised "free" while timers choked non-payers; UK ASA ruling),
  Homescapes/Gardenscapes (ads showing puzzles barely in the game; ASA ban), Fortnite (button
  layout caused one-press purchases; FTC $245M refunds), Genshin Impact (alleged misleading
  loot-box odds; FTC proposed $20M settlement). Common thread: what the player was led to expect
  did not match what they got.

## Keep/kill lines (level puzzles; adapt per type)
| Metric | Kill | Iterate | Keep | Scale |
|---|---|---|---|---|
| Day-1 retention | < 22% | 22-29% | >= 30% | >= 38% |
| Day-7 retention | < 4% | 4-7.9% | >= 8% | >= 12% |
| Average session | < 3 min | 3-3.9 min | >= 4 min | >= 5.2 min |
| Blended ad revenue per daily player | < $0.006 | $0.006-0.011 | >= $0.012 | >= $0.02 |

Benchmarks behind them: median D1 about 22%, top quartile just above 30%, top decile about 40%;
median D7 just under 4%; median session about 3.1-3.5 min. Rules: wait for 500+ installs from
strangers; under ~300 organic installs in two weeks means fix the store page first; read Tier-1
and India/SEA cohorts separately; discount Oct-Dec ad revenue by about 25% (Q4 eCPMs run high);
Kill = below the line on D1 or D7 after two improved builds; Scale (small paid tests) only above
D1 35%, D7 10% with some IAP revenue.
