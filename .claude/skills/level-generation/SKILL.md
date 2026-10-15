---
name: level-generation
description: Design, build and test procedural level generators for this Godot 4.7 template: puzzle levels that are guaranteed solvable, solver and bot difficulty rating, seeded runs and daily puzzles, and baking levels to data files with SeedService. Use this whenever the user wants levels, puzzles, boards, waves, piece dealers, daily challenges or "infinite content" generated, asks how to make levels harder or easier in a controlled way, or hits unsolvable or repetitive levels, even if they don't say "procedural generation".
---

# Level generation

Generated levels are only useful if they are **solvable, rated and reproducible**. Reproducibility
matters more than cleverness: a bug report with a seed should replay exactly, and a level a player
has seen must never change after an update.

## 1. Choose the generation family
| Family | How it works | Use for |
|---|---|---|
| Solvable-by-construction | Start from the solved state and apply reverse moves; every forward replay is a solution | Tile/mahjong stacks (reverse removal), ball-sort and word-sort deals, Sokoban-like puzzles |
| Generate-then-solve | Generate freely, verify with a solver, rate difficulty, reject bad ones | Sort/water-sort (pours are not always reversible), logic dailies, anything where reverse moves are unclear |
| Seeded weighted tables | Weighted random picks from tables, driven by a seed | Endless block dealers (with a "fits somewhere" check), arcade chunks, enemy waves, draft picks |

Ball-sort and water-sort solvability is NP-complete, so every solver needs a node budget and must
give up cleanly.

## 2. Seeds (`core/seed_service.gd`)
- Seed from stable parts plus a generator version:
  `var rng := SeedService.make_rng(["halves", chapter, level], GEN_VERSION)`.
  SeedService hashes with SHA-256, so equal parts give the same seed on every machine.
- Godot's `RandomNumberGenerator` algorithm (PCG32) is an implementation detail that may change
  between engine versions, so a seed alone is not a guarantee across upgrades. That is why shipped
  levels are baked (step 4).
- Log the seed with analytics and crash reports; the dev console's `set_seed` replays it.
- Seed parts read back from JSON arrive as floats (`3` becomes `3.0`); SeedService treats whole
  floats as ints, so seeds rebuilt from baked `seed_parts` match. Keep seed parts to strings and
  whole numbers.

## 3. Rate difficulty with a bot
- Write a headless bot (random-greedy is enough to start) and play each candidate many times
  (50-200 runs). Record win rate, dead ends, moves, and solver branching to CSV.
- Reject levels that are unsolvable, trivial (for example a greedy bot wins more than ~95% after
  the first chapter), or solvable only by one narrow line early on.
- If a greedy bot wins almost every mid-game level, the mechanic is not creating real decisions:
  that is a design problem (see the game-design-review skill), not a tuning problem.

## 4. Bake, don't regenerate
- Generate offline in a headless batch, rate, then hand-order levels into the difficulty curve
  (sawtooth packs with rest levels).
- Save to `data/levels/<game>_v<gen_version>.json` with the `gen_version`; bake a year of dailies
  ahead so everyone gets the same puzzle and an engine update cannot change past puzzles.
- Runtime generation is allowed only for disposable content: endless runs, practice boards,
  verified shuffles.
- "Fresh every launch" without regenerating: serve a not-recently-played baked level, then remap
  its colours and shuffle container order at runtime. Both keep a sort puzzle solvable and never
  change the level's identity in saves or bug reports. Godot's 2D physics is not identical across devices, so physics games compare
  a player with their own best rather than offering replays.

## 5. Batch tool pattern
Run generators as a SceneTree script so they work headless and from CI:
```gdscript
extends SceneTree
## tools/levelgen/generate_<game>.gd — usage:
## godot --headless --path . -s tools/levelgen/generate_<game>.gd -- 200
const GEN_VERSION: int = 1

func _initialize() -> void:
	var count := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 100
	var levels: Array[Dictionary] = []
	for i in count:
		var rng := SeedService.make_rng(["<game>", i], GEN_VERSION)
		var level := _generate(rng)            # family from step 1
		var stats := _rate(level, rng)         # bot runs from step 3
		if _accept(stats):
			levels.append({"seed_parts": ["<game>", i], "level": level, "stats": stats})
	DirAccess.make_dir_recursive_absolute("res://data/levels")
	var file := FileAccess.open("res://data/levels/<game>_v%d.json" % GEN_VERSION, FileAccess.WRITE)
	file.store_string(JSON.stringify({"gen_version": GEN_VERSION, "levels": levels}, "\t"))
	quit()
```
Keep `_generate`, `_rate` and `_accept` pure functions so GUT can test them.

## 6. Tests
- Snapshot-test a handful of seeds: the same seed and `gen_version` must produce the same level.
- Every generated level in a sample must be solvable by the solver.
- The **test cases are written by the human or a separate Claude session**, not the session that
  wrote the generator: a session grading its own work tends to write tests that pass.
- Finish with `powershell -ExecutionPolicy Bypass -File tools/check.ps1`.
