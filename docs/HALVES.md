# Halves: rules, data and code

Halves is a calm, mahjong-style stack-clearing puzzle. **Tap a free tile, then its mirror-cut other
half, and the two snap into one whole shape. Never match twins.** No timer, no lives, no fail state.

Design source: `Godot Mobile Studio Plan.html` (concept card "Halves"). This file is the contract
for the code in `game/halves/` and the generator in `tools/levelgen/`; tests are written from it.

## 1. Rules

### Faces
Every tile shows one half of a shape. A face has four parts:

| Part | Values | Notes |
|---|---|---|
| shape | `circle`, `tri` (triangle), `square`, `diamond` | Each shape has one colour: circle cobalt, triangle terracotta, square and diamond teal. Colour is never the only cue. |
| cut | `v` (vertical: left/right halves), `h` (horizontal: top/bottom halves) | Triangles are only cut vertically (a horizontal cut would not give mirror halves). |
| mark | `-` (none), `dot`, `line` | A small ivory mark inside the half; it mirrors with the half. |
| side | `a` (left or top half), `b` (right or bottom half) | |

Text form: `"<shape>:<cut>:<mark>:<side>"`, e.g. `"circle:v:-:a"`, `"tri:v:dot:b"`.
A **pair type** is the first three parts (`"circle:v:-"`).

- **Match:** same shape, cut and mark, opposite sides.
- **Decoy:** same shape but not a match: a twin (identical face) or a near-twin (other cut, other
  mark, or same side). Decoys are what "never match twins" is about.

### Free tiles
Positions are `(x, y, z)` in **half-tile units**: a tile covers the area `[x, x+2) × [y, y+2)` on
layer `z` (0 = bottom). Upper layers may sit half a tile offset.

- Tile **i is covered** if some remaining tile j has `z_j > z_i`, `|x_j - x_i| < 2` and `|y_j - y_i| < 2`.
- Tile **j is a left neighbour** of i if `z_j == z_i`, `x_j == x_i - 2` and `|y_j - y_i| < 2`
  (right neighbour: `x_j == x_i + 2`).
- Tile **i is free** if it is not covered **and** it has no remaining left neighbour **or** no
  remaining right neighbour.

### A turn
- Tap a free tile: it lifts (selected). Tap it again: it drops.
- With a tile selected, tap another free tile:
  - **match:** both are removed (the snap);
  - **decoy:** a **mistake**: both shake, the selection drops;
  - **different shape:** the selection simply moves to the new tile (no penalty).
- Tapping a blocked tile only nudges it.
- Strict mode (`HalvesConfig.STRICT_MISTAKES`, off by default): every non-matching pair is a mistake.
- On levels 1-`TUTORIAL_FORGIVE_LEVELS` the first mistake is free (`free_mistakes = 1`).

### Stars and the end
The level ends when the board is clear. Stars: **3** with no mistakes ("flawless"), **2** with 1 to
`STAR2_MAX_MISTAKES` (2) mistakes, **1** otherwise. Boosters never cost stars.

### Boosters and being stuck
- **Hint** highlights a free pair that keeps the board solvable (solver), or the most freeing pair
  if the solver runs out of budget.
- **Undo** takes back the last action: the last pair (tiles return) or the last mistake (its star
  returns). Shuffles clear the undo history.
- **Shuffle** re-deals the remaining tiles into a solvable board.
- Each booster is free `FREE_USES` (1) time per level; after that the player pays coins
  (`PRICE_*`) or watches a rewarded video for one more use.
- **Stuck** (tiles left, no free pair): within a second a card offers a **free** shuffle.
- A shuffle first re-deals faces on the same positions. If no removal order exists for those
  positions, it **reseats** the tiles into the positions the baked solution has left after the same
  number of pairs (always solvable, because the rest of the baked solution proves it).

## 2. Code (`game/halves/`, shipped)
All logic is pure (static functions or `RefCounted`), statically typed and deterministic: random
choices use a seeded `RandomNumberGenerator` passed in, never `randi()`, `Array.shuffle()` or
`pick_random()`. Tile ids are indices into the level's tile list, which is sorted by `(z, y, x)`;
a set of tiles is an `int` bitmask (bit i = tile i, at most 64 tiles; bit 63 makes the int
negative, so test bits with `!= 0`).

### `HalvesFace` (`halves_face.gd`, static; a face is an `int`)
```
enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }    # text: circle, tri, square, diamond
enum Cut { VERTICAL, HORIZONTAL }                   # text: v, h
enum Mark { NONE, DOT, LINE }                       # text: -, dot, line
const SIDE_A := 0, SIDE_B := 1                      # text: a, b
static func make(shape: int, cut: int, mark: int, side: int) -> int   # shape << 4 | cut << 3 | mark << 1 | side
static func shape(face: int) -> int
static func cut(face: int) -> int
static func mark(face: int) -> int
static func side(face: int) -> int
static func pair_key(face: int) -> int              # face >> 1
static func mate(face: int) -> int                  # face ^ 1
static func is_valid(face: int) -> bool             # known values; triangles only VERTICAL
static func matches(a: int, b: int) -> bool         # same pair_key, different side
static func is_decoy(a: int, b: int) -> bool        # same shape and not matches (twins included)
static func to_text(face: int) -> String            # "circle:v:-:a"
static func from_text(text: String) -> int          # -1 if invalid
static func pair_to_text(key: int) -> String        # "circle:v:-"
static func pair_from_text(text: String) -> int     # -1 if invalid
```

### `HalvesGeometry` (`halves_geometry.gd`, RefCounted)
```
const MAX_TILES := 64
var positions: Array[Vector3i]
static func from_positions(positions: Array[Vector3i]) -> HalvesGeometry   # keeps the given order
func size() -> int
func full_mask() -> int                              # every tile present
func is_free(i: int, remaining: int) -> bool         # rules of section 1, against the tiles in `remaining`
func free_mask(remaining: int) -> int                # free tiles among `remaining`
func free_tiles(remaining: int) -> PackedInt32Array  # ascending ids
func bounds() -> Rect2i                              # x/y extent in half-units (from 0,0 to max x+2, y+2)
func max_z() -> int
static func popcount(mask: int) -> int
```

### `HalvesMask` (`halves_mask.gd`, static)
Masks are hand-made ASCII (see section 3).
```
const MAX_WIDTH := 13, MAX_HEIGHT := 14, MAX_LAYERS := 4
static func parse(layers: Array) -> Array[Vector3i]          # sorted by (z, y, x)
static func validate(positions: Array[Vector3i]) -> PackedStringArray   # empty = valid
```
`validate` reports, in readable sentences: an odd tile count or more than 64 tiles; more than
`MAX_LAYERS` layers (max z + 1); width (max x + 2) over `MAX_WIDTH` or height (max y + 2) over `MAX_HEIGHT`;
two tiles on one layer that overlap; a tile on layer z > 0 with any of its four half-cells not
resting on a tile of layer z - 1; two tiles on one layer whose rows overlap (`|dy| < 2`) with
`|dx| == 3` (a gap that looks touching but does not block).

### `HalvesState` (`halves_state.gd`, RefCounted)
```
enum Result { MATCH, MISMATCH, SWITCH, BLOCKED, INVALID }
var geometry: HalvesGeometry
var faces: PackedInt32Array       # faces[i] for tile i
var remaining: int                # bitmask of tiles still on the board
var mistakes: int = 0
var free_mistakes: int = 0        # mismatches that cost nothing (tutorial)
var strict: bool = false
var history: Array[Dictionary]    # {"kind": "pair", "a": int, "b": int} or {"kind": "mistake"}
func _init(geometry: HalvesGeometry, faces: PackedInt32Array) -> void   # all tiles remaining
func try_pair(a: int, b: int) -> Result
func undo() -> bool               # false if nothing to undo
func free_pairs() -> Array[Vector2i]   # every free matching pair (x < y), sorted ascending
func is_cleared() -> bool
func is_stuck() -> bool           # tiles left and no free pair
func tiles_left() -> int
func stars() -> int
func apply_deal(remaining: int, faces: PackedInt32Array) -> void   # after a shuffle; clears history
```
`try_pair(a, b)`, in this order:
1. `INVALID` if `a == b`, an id is out of range, or a tile is not remaining. Nothing changes.
2. `BLOCKED` if either tile is not free. Nothing changes.
3. `MATCH`: both leave `remaining`; history gets a pair entry.
4. `MISMATCH` if the faces are a decoy (or `strict` and they don't match): if `free_mistakes > 0`
   it is decremented and nothing else changes; otherwise `mistakes += 1` and history gets a mistake
   entry.
5. `SWITCH` otherwise. Nothing changes.

`undo()` pops the last history entry: a pair returns both tiles to `remaining`; a mistake does
`mistakes -= 1`. `apply_deal` keeps `mistakes`. The game screen (not `new_state()`) sets
`free_mistakes = 1` on tutorial levels and `strict` from `HalvesConfig.STRICT_MISTAKES`. `stars()`: 3 if `mistakes == 0`, 2 if `mistakes <= HalvesConfig.STAR2_MAX_MISTAKES`,
else 1.

### `HalvesFill` (`halves_fill.gd`, static): reverse-removal fill and shuffle
```
static func removal_order(geometry: HalvesGeometry, mask: int, rng: RandomNumberGenerator,
		budget: int = 4000, restarts: int = 30) -> Array[Vector2i]
static func assign_faces(order: Array[Vector2i], pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator, tile_count: int) -> PackedInt32Array
static func deal(geometry: HalvesGeometry, pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator) -> Dictionary
static func remaining_pair_keys(state: HalvesState) -> PackedInt32Array
static func shuffle(state: HalvesState, solution: Array[Vector2i],
		rng: RandomNumberGenerator) -> Dictionary
static func shuffle_rng(level: int, count: int) -> RandomNumberGenerator
```
- `removal_order`: pairs of tiles such that, starting from `mask` and removing the pairs in order,
  both tiles of each pair are free at their step and the end is empty. Uses every tile of `mask`
  exactly once. Returns `[]` if it finds none within the budget (or `mask == 0`). Same inputs and
  rng state give the same result.
- `assign_faces`: needs `pair_keys.size() == order.size()`. Pair keys are shuffled with `rng`; pair
  k of `order` gets one key, one tile side A and the other side B (which tile is A is random).
  Tiles not in `order` get `-1`. Playing `order` forward is then a solution.
- `deal`: `removal_order` on the full mask + `assign_faces`. Returns
  `{"faces": PackedInt32Array, "solution": Array[Vector2i]}`, or `{}` if no order was found.
- `remaining_pair_keys`: for every remaining side-A face, its pair key; sorted ascending.
- `shuffle`: returns `{"remaining": int, "faces": PackedInt32Array, "reseated": bool}` (or `{}` when
  the board is clear). The remaining faces keep their multiset (same faces, new places), and the
  returned board has a removal order consistent with its faces. `reseated` is false when the tile
  positions are unchanged (`remaining` equals `state.remaining`); when true, `remaining` is exactly
  the set left by the first `k` pairs of `solution`, where `k = (geometry.size() - tiles_left) / 2`.
  Faces of tiles outside the returned `remaining` are `-1`.
- `shuffle_rng(level, count)`: `SeedService.make_rng(["halves", level, "shuffle", count], GEN_VERSION)`.

### `HalvesSolver` (`halves_solver.gd`, static)
```
enum Status { SOLVED, UNSOLVABLE, UNKNOWN }
static func solve(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int,
		budget: int = 20000) -> Dictionary        # {"status": Status, "moves": Array[Vector2i]}
static func hint(state: HalvesState, budget: int = 5000) -> Vector2i
```
- `solve`: depth-first search over free matching pairs, remembering dead states, giving up after
  `budget` expanded states (`UNKNOWN`; a budget of 0 expands nothing). When every remaining tile
  of a pair type is free, one of its pairs is taken without branching (it can never hurt). `SOLVED` moves clear `remaining` when played in order;
  `remaining == 0` is `SOLVED` with no moves. `UNSOLVABLE` only when the search is exhausted.
- `hint`: the first move of a `SOLVED` result; if `UNKNOWN`, the free pair that leaves the most
  free tiles (the CAREFUL bot's measure; ties: the first in `free_pairs()` order); `Vector2i(-1, -1)` when `UNSOLVABLE` or there is no free pair.

### `HalvesBot` (`halves_bot.gd`, static): difficulty rating
```
enum Policy { RANDOM, CAREFUL }
static func play(geometry: HalvesGeometry, faces: PackedInt32Array,
		rng: RandomNumberGenerator, policy: Policy) -> Dictionary
static func rate(geometry: HalvesGeometry, faces: PackedInt32Array, seed_parts: Array,
		runs: int = 50) -> Dictionary
static func difficulty(random_win: float, decoy_exposure: float, avg_free_pairs: float) -> float
```
- `play`: from a full board, repeatedly removes one free matching pair until clear or stuck.
  RANDOM picks a uniformly random free pair; CAREFUL picks the pair that leaves the most free tiles
  (ties random). Returns `{"cleared": bool, "steps": int, "free_pairs": float, "decoy": float}`.
  `steps` counts removed pairs. `free_pairs` and `decoy` are means over every board the bot looked
  at, **including the final stuck board** when it got stuck: `free_pairs` = free pairs on it,
  `decoy` = (unordered pairs of free tiles that are decoys) / max(1, free pairs).
- `rate`: one rng `SeedService.make_rng(seed_parts + ["rate"], GEN_VERSION)`; `runs` RANDOM games,
  then `runs` CAREFUL games. Returns `{"runs", "random_win", "careful_win", "avg_free_pairs",
  "decoy_exposure", "difficulty"}`; win rates are the share of cleared games; `avg_free_pairs` and
  `decoy_exposure` are the mean of each RANDOM game's `free_pairs` / `decoy`.
- `difficulty = 100 * (0.6 * (1 - random_win) + 0.25 * min(decoy_exposure / 1.5, 1)
  + 0.15 * (1 - min(avg_free_pairs, 6) / 6))`, from 0 (trivial) to 100.

### `HalvesLevels` (`halves_levels.gd`) and `HalvesLevelData`
```
const PATH := "res://data/levels/halves_v1.json"
const COUNT := 30
static func get_level(n: int) -> HalvesLevelData   # 1-based; null if missing
static func count() -> int                         # levels in the file
static func gen_version() -> int
```
`HalvesLevelData`: `level: int`, `role: String`, `mask: String`, `seed_parts: Array`,
`positions: Array[Vector3i]`, `faces: PackedInt32Array`, `solution: Array[Vector2i]`,
`stats: Dictionary`, `func geometry() -> HalvesGeometry`, `func new_state() -> HalvesState`.
JSON numbers are read back as ints.

### `HalvesConfig` (`halves_config.gd`): tunables
`GEN_VERSION = 1`, `FREE_USES = 1`, `PRICE_HINT = 30`, `PRICE_UNDO = 30`, `PRICE_SHUFFLE = 40`,
`STAR2_MAX_MISTAKES = 2`, `TUTORIAL_FORGIVE_LEVELS = 3`, `MATE_PULSE_LEVELS = 2`,
`STRICT_MISTAKES = false`, `STUCK_DELAY = 0.5` s.

### View (not part of the logic contract)
`HalvesBoardView` (Control) lays the tiles out to fit `%Board`, hit-tests taps top tile first, and
plays the feedback; `HalvesTileView` (Node2D) draws one tile; `HalvesSnapFx` and `HalvesShardPool`
are the match effects; `HalvesPalette` holds the art colours. The game screen (`ui/screens/game.gd`)
owns boosters, coins, the stuck card and the level flow.

## 3. Data

### Masks: `tools/levelgen/halves_masks.json` (hand-made, not exported)
```json
{"format": 1, "masks": {"p1_intro": {"layers": [["X.X.X.X.", "........", "X.X.X.X."]]}}}
```
`layers[z]` is a list of rows; each row string is one **half-unit** line and each character one
half-unit column. `X` marks a tile's top-left corner; `.` (or space) is empty. Rows and trailing
characters may be omitted. So a row of touching tiles is `X.X.X.`, and the next row of tiles is two
lines down. Masks are drafts: the human owns their shapes and order.

### Level plan: `tools/levelgen/halves_plan.json`
One slot per level: `{"level", "role" (intro/ramp/hard/rest/finale), "mask", "types" (pair types
in text form), "target_win", "target_decoy"}`. The mask's tile count / 2 pairs are spread over
`types` round-robin in the listed order (so earlier types get the extra copies).

### Baked levels: `data/levels/halves_v1.json` (exported)
```json
{"gen_version": 1, "count": 30, "levels": [
  {"level": 1, "role": "intro", "mask": "p1_intro", "seed_parts": ["halves", 1, 7],
   "tiles": [[0, 0, 0, "circle:v:-:a"], ...], "solution": [[0, 3], ...],
   "stats": {"runs": 50, "random_win": 1.0, ...}}]}
```
`tiles` are sorted by `(z, y, x)`; `solution` uses tile ids. `seed_parts` are
`["halves", level, candidate]` and rebuild the level exactly with `gen_version` (see 4).
Never edit this file by hand and never change a shipped level: bump `gen_version` and write a new
file instead.

## 4. Generating levels
```
godot --headless --path . -s tools/levelgen/generate_halves.gd            # all 30 levels
godot --headless --path . -s tools/levelgen/generate_halves.gd -- 5       # just level 5 (preview)
```
For each slot: parse and validate the mask, build the pair keys, then for candidates
`k = 0..CANDIDATES-1` deal with `SeedService.make_rng(["halves", level, k], GEN_VERSION)`
(`HalvesFill.deal`). A quick 10-run screen keeps the best 5, which are rated with 50 runs per policy.
The candidate with the lowest `2 * |random_win - target_win| + 0.5 * |decoy_exposure - target_decoy|`
wins (ties: lower k). Rejected: no deal found, `careful_win` under 0.8 (0.6 on hard and finale
levels: a careful player should rarely need the free shuffle), or (after level 1) fewer than 2
free pairs at the start. Output: `data/levels/halves_v1.json` and a report
`tools/levelgen/reports/halves_v1.csv` (one row per level with its stats).

## 5. Tuning
- Difficulty dials: mask (how many tiles are free at once, how deep the stacks are), number of
  pair types vs copies (more copies = more twins), cuts and marks (near-twins), and the targets in
  the plan.
- Sawtooth in packs of 10: level 5 hard, level 6 a rest that brings in the next idea, level 10 a
  finale. Pack 2 brings horizontal cuts (11) and diamonds (16); pack 3 brings dot marks (21) and
  line marks (26).
- Booster prices and free uses: `HalvesConfig`.
