# Halves: rules, data and code (contract v2)

Halves is a calm, mahjong-style stack-clearing puzzle. **Tap a free tile, then its mirror-cut other
half, and the two snap into one whole shape. Never match twins.** No lives and no fail state: a
board can always be finished, but wrong pairs and dead ends cost stars, and the clock measures speed.

Design source: `Godot Mobile Studio Plan.html` (concept card "Halves") and the v1 polish plan
(100 levels in ten places of ten levels, new mechanics, time records, three modes). This file is the
contract for the code in `game/halves/` and the generator in `tools/levelgen/`; tests are written
from it. Everything marked **(v2)** is new in contract version 2; the rest is unchanged from v1.

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
A **pair type** (pair key) is the first three parts (`"circle:v:-"`).

- **Match:** same shape, cut and mark, opposite sides. Two tiles that match are **mates**.
- **Decoy:** same shape but not a match: a twin (identical face) or a near-twin (other cut, other
  mark, or same side). Decoys are what "never match twins" is about.

### Free tiles
Positions are `(x, y, z)` in **half-tile units**: a tile covers the area `[x, x+2) × [y, y+2)` on
layer `z` (0 = bottom). Upper layers may sit half a tile offset.

- Tile **i is covered** if some remaining tile j has `z_j > z_i`, `|x_j - x_i| < 2` and `|y_j - y_i| < 2`.
- Tile **j is a left neighbour** of i if `z_j == z_i`, `x_j == x_i - 2` and `|y_j - y_i| < 2`
  (right neighbour: `x_j == x_i + 2`).
- Tile **i is free** if it is not covered **and** it has no remaining left neighbour **or** no
  remaining right neighbour, **and** (v2) no feature rule below blocks it.

### Features (v2)
A level may carry **features**: sets of tile ids with extra rules. All of them are positional
(they belong to a tile position, not to a face), so a shuffle keeps them where they are.

| Feature | Rule | Shown as |
|---|---|---|
| **Lock** group `{keys, locked}` | A tile in `locked` is not free while **any** tile of the same group's `keys` remains. | Key tiles carry a small key; locked tiles a padlock that opens when the last key is cleared. |
| **Frost** | A frosted tile is not free until at least one tile **touching** it has been removed (ever, by any pair). A tile that touches no tile at all cannot be frosted (the rule is skipped; `place` never picks one). | A frosted rim that cracks when it thaws. |
| **Mist** | No effect on the rules. The face stays hidden until the tile is free for the first time; once shown it stays shown. | A veiled face that flips over. |
| **Gold** | No effect on the rules. Clearing a gold tile earns `HalvesConfig.GOLD_COINS` coins at the end of the level. | A gold rim. |

- Tile j **touches** tile i (both on the board, `j != i`) if j covers i, j is a left or right
  neighbour of i, or `z_j == z_i`, `|x_j - x_i| < 2` and `|y_j - y_i| == 2` (directly above or
  below in the same layer). Tiles that i covers do not touch i.
- A tile may be locked by several groups (it needs every group's keys gone). No tile is both a key
  and a locked tile, in any group (so locks can never wait on each other).
- **Monotone rule.** Every rule is monotone: removing tiles can only ever unblock tiles, never block
  them. For any remaining set `R`, tile i and `R' ⊆ R` with i in `R'`: free in `R` ⇒ free in `R'`.
  The solver shortcut, the reseat proof and the generator's validity all rely on this; any future
  feature must keep it.

### A turn
- Tap a free tile: it lifts (selected). Tap it again: it drops.
- With a tile selected, tap another free tile:
  - **match:** both are removed (the snap);
  - **decoy:** a **mistake**: both shake, the selection drops;
  - **different shape:** the selection simply moves to the new tile (no penalty).
- Tapping a blocked tile only nudges it (the nudge shows why: covered, sides, locked, frosted).
- Strict mode (`HalvesConfig.STRICT_MISTAKES`, off by default): every non-matching pair is a mistake.
- On levels 1-`TUTORIAL_FORGIVE_LEVELS` the first mistake is free (`free_mistakes = 1`).

### Slips, stars and the end (v2)
The level ends when the board is clear.
- A **slip** is a mistake or a **stuck shuffle**: a shuffle applied while the board is stuck (tiles
  left, no free pair), whether it is the free shuffle of the stuck card or the Shuffle booster.
  Backing out of a dead end with Undo is not a slip.
- Stars: **3** with no slips ("flawless"), **2** with 1 to `STAR2_MAX_MISTAKES` (2) slips,
  **1** otherwise. Boosters never cost stars by themselves: a shuffle applied while stuck is a slip
  because of the dead end, whichever button applied it.

### Time, par and the Swift medal (v2)
- The clock starts at the player's **first tap** on the board (the game calls `HalvesRun.start()` on it, even
  when that tap only selects a tile) and counts only active play: it does
  not run while the game is paused, a popup is open or the app is in the background.
- Each level has a baked **par time** (`stats.par_ms`, section 4). Clearing a level at or under par
  earns the **Swift** medal (⚡), once per level, and `SWIFT_COINS` coins the first time.
- The best time per board is kept with the run that set it (section 2, `HalvesRun`).

### Boosters and being stuck
- **Hint** highlights a free pair that keeps the board solvable (solver), or (v2) when the solver
  runs out of budget the most freeing pair that is not a trap move (see `HalvesBot.is_trap_move`),
  or the most freeing pair if every pair is a trap move.
- **Undo** takes back the last action: the last pair (tiles return) or the last mistake (its star
  returns). Shuffles clear the undo history.
- **Shuffle** re-deals the remaining tiles into a solvable board.
- Each booster is free `FREE_USES` (1) time per level; after that the player pays coins
  (`PRICE_*`) for one more use (v1 has no rewarded videos).
- **Stuck** (tiles left, no free pair): within a second a card offers Undo (as the booster) or a
  free shuffle that counts as a slip.
- A shuffle first re-deals faces on the same positions. If no removal order exists for those
  positions, it **reseats** the tiles into the positions the baked solution has left after the same
  number of pairs (always solvable, because the rest of the baked solution proves it).

### Modes (v2)
| Mode | Boards | Stars / time | Notes |
|---|---|---|---|
| Levels | the 100 baked levels, in 10 places of 10 (one sawtooth pack each) | stars, time, par | The main journey. |
| Daily | one board of the daily pool per calendar day (local date) | stars, time | Same board for everyone on that date. Finishing it extends the daily streak. No interstitials. |
| Zen | the zen pool, endless, in a seeded order | none | No timer, no stars, no ads. Unlocks after level `ZEN_UNLOCK_LEVEL`. |
| Rush | the rush pool, in a seeded order | score | `RUSH_SECONDS` on the clock; each cleared board adds `RUSH_BOARD_BONUS_S`, each mistake takes `RUSH_MISTAKE_PENALTY_S`; a stuck board shuffles itself. Score = pairs cleared + `RUSH_BOARD_POINTS` per cleared board. Unlocks after level `RUSH_UNLOCK_LEVEL`. |

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
enum Block { FREE, COVERED, SIDES, LOCKED, FROSTED }                  # (v2)
var positions: Array[Vector3i]
var cover: PackedInt64Array        # cover[i]: tiles that lie on top of tile i
var left: PackedInt64Array         # left[i]: its left neighbours (right[i] likewise)
var right: PackedInt64Array
var touch: PackedInt64Array        # (v2) touch[i]: tiles touching i (section 1, Features)
var lock_need: PackedInt64Array    # (v2) empty without features; else lock_need[i] = union of the key masks of i's lock groups
var frost_need: PackedInt64Array   # (v2) empty without features; else touch[i] for frosted tiles, 0 for the others
var features: Dictionary           # (v2) the normalised features ({} without)
static func from_positions(positions: Array[Vector3i]) -> HalvesGeometry   # keeps the given order; no features
func with_features(features: Dictionary) -> HalvesGeometry  # (v2) a new geometry (same positions) with the rules; never mutates self
func has_features() -> bool                                  # (v2) features is not empty
func size() -> int
func full_mask() -> int                              # every tile present
func is_free(i: int, remaining: int) -> bool         # rules of section 1, against the tiles in `remaining`
func blocked_reason(i: int, remaining: int) -> Block # (v2) the first that applies: COVERED, SIDES, LOCKED, FROSTED; else FREE
func free_mask(remaining: int) -> int                # free tiles among `remaining`
func free_tiles(remaining: int) -> PackedInt32Array  # ascending ids
func bounds() -> Rect2i                              # x/y extent in half-units (from 0,0 to max x+2, y+2)
func max_z() -> int
static func popcount(mask: int) -> int
```
`is_free(i, remaining)` (v2) is: not covered, sides open (as v1), and, when the geometry has
features, `remaining & lock_need[i] == 0` and (`frost_need[i] == 0` or
`frost_need[i] & ~remaining != 0`). A geometry without features behaves exactly as v1.
`with_features({})` returns a geometry equal to one without features.

### `HalvesFeatures` (`halves_features.gd`, static) (v2)
Features in a level file and in code:
```json
{"locks": [{"keys": [3, 9], "locked": [20, 21]}], "frost": [4, 17], "mist": [1, 2], "gold": [30, 31]}
```
Missing keys mean none. Ids are tile ids.
```
static func normalize(raw: Dictionary) -> Dictionary
static func validate(geometry: HalvesGeometry, features: Dictionary,
		solution: Array[Vector2i] = []) -> PackedStringArray       # empty = valid
static func place(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array,
		spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary
static func tile_count(features: Dictionary) -> int                 # distinct tiles that are key, locked, frost or mist
static func mask(ids: Array) -> int
```
- `normalize`: ints everywhere (JSON floats cast), every list sorted ascending and without
  duplicates, empty lists and lock groups with no keys or no locked tiles removed; key order
  `locks, frost, mist, gold`. `normalize(normalize(x)) == normalize(x)`.
- `validate` reports, in readable sentences: an id outside `0..size-1`; a lock group whose keys and
  locked tiles overlap; a tile that is a key in one group and locked in another; and, when
  `solution` is given, a pair of the solution whose tiles are not both free (under the rules) at
  their step, or a solution that does not clear the board.
- `place` adds features to a dealt board **after** its removal order is known, so the order stays a
  valid solution under the new rules. `spec` keys (all optional ints, default 0):
  `key_pairs, locked, frost, mist, gold`. With `n = order.size()`, `step[t]` the step that removes
  tile t, and `free_before[k]` the free mask before step k (no features):
  1. **Locks** (only if `key_pairs > 0` and `locked > 0`): choose `min(key_pairs, size of range)`
     distinct steps from `[n / 3, 2n / 3)` (integer division) with `rng`; their tiles are the keys
     of one group. `last` = the latest key step. Candidates: tiles with `step > last`; those free in
     some `free_before[k]` with `k <= last` come first. Take the first `locked`.
  2. **Frost:** candidates are tiles that are not keys or locked and have a touching tile with a
     strictly smaller step; tiles free at the start come first. Take the first `frost`.
  3. **Mist:** candidates are tiles not free at the start, not used by 1-2, and not the covered
     tile `y` of a live trap link (`HalvesFill.trap_links` on these faces). Take the first `mist`.
  4. **Gold:** candidates are tiles not used by 1-3 on layers `z >= 1` first, then layer 0. Take
     the first `gold`.
  "First" means: the candidate list (preferred group, then the rest) where each group is put in a
  random order with `HalvesFill.shuffle_ints` and `rng`. The rng is used in the order 1, 2, 3, 4.
  The result is normalised; fewer tiles than asked is fine.

### `HalvesState` (`halves_state.gd`, RefCounted)
```
enum Result { MATCH, MISMATCH, SWITCH, BLOCKED, INVALID }
var geometry: HalvesGeometry
var faces: PackedInt32Array       # faces[i] for tile i
var remaining: int                # bitmask of tiles still on the board
var mistakes: int = 0
var free_mistakes: int = 0        # mismatches that cost nothing (tutorial)
var strict: bool = false
var stuck_shuffles: int = 0       # (v2) shuffles applied while stuck
var veiled: int = 0               # (v2) mist tiles whose face is still hidden
var gold: int = 0                 # (v2) the gold tiles (mask), from geometry.features
var gold_earned: int = 0          # (v2) gold tiles cleared so far
var history: Array[Dictionary]    # {"kind": "pair", "a": int, "b": int} or {"kind": "mistake"}
func _init(geometry: HalvesGeometry, faces: PackedInt32Array) -> void   # all tiles remaining
func try_pair(a: int, b: int) -> Result
func undo() -> bool               # false if nothing to undo
func last_action() -> Dictionary
func free_pairs() -> Array[Vector2i]   # every free matching pair (x < y), sorted ascending
func is_cleared() -> bool
func is_stuck() -> bool           # tiles left and no free pair
func tiles_left() -> int
func slips() -> int               # (v2) mistakes + stuck_shuffles
func stars() -> int
func apply_deal(remaining: int, faces: PackedInt32Array, stuck: bool = false) -> void
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
`mistakes -= 1`. `apply_deal` keeps `mistakes`, replaces `remaining` and `faces`, clears the
history, and (v2) adds 1 to `stuck_shuffles` when `stuck` is true. The game screen (not
`new_state()`) sets `free_mistakes = 1` on tutorial levels and `strict` from
`HalvesConfig.STRICT_MISTAKES`. `stars()` (v2): 3 if `slips() == 0`, 2 if
`slips() <= HalvesConfig.STAR2_MAX_MISTAKES`, else 1.

(v2) Mist and gold: `_init` sets `gold` and `veiled` from `geometry.features` (`mist` and `gold`
lists; 0 without features), then reveals. **Reveal** means `veiled &= ~geometry.free_mask(remaining)`
and happens after `_init`, after a `MATCH`, after an `undo()` and after `apply_deal`. Revealing never
hides a tile again. `gold_earned` goes up by the number of gold tiles in a matched pair and down by
the number of gold tiles an undone pair returns.

### `HalvesFill` (`halves_fill.gd`, static): reverse-removal fill, traps and shuffle
```
static func removal_order(geometry: HalvesGeometry, mask: int, rng: RandomNumberGenerator,
		budget: int = 4000, restarts: int = 30) -> Array[Vector2i]
static func assign_faces(order: Array[Vector2i], pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator, tile_count: int) -> PackedInt32Array
static func trap_links(geometry: HalvesGeometry, order: Array[Vector2i]) -> Array[Vector4i]       # (v2)
static func assign_faces_trapped(geometry: HalvesGeometry, order: Array[Vector2i],
		pair_keys: PackedInt32Array, rng: RandomNumberGenerator, tile_count: int,
		trap_rate: float) -> PackedInt32Array                                                     # (v2)
static func live_traps(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array) -> int   # (v2)
static func deal(geometry: HalvesGeometry, pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator) -> Dictionary
static func deal_v2(geometry: HalvesGeometry, pair_keys: PackedInt32Array, rng: RandomNumberGenerator,
		trap_rate: float, feature_spec: Dictionary) -> Dictionary                                  # (v2)
static func remaining_pair_keys(state: HalvesState) -> PackedInt32Array
static func shuffle(state: HalvesState, solution: Array[Vector2i],
		rng: RandomNumberGenerator) -> Dictionary
static func shuffle_rng(level: int, count: int) -> RandomNumberGenerator
static func shuffle_ints(values: PackedInt32Array, rng: RandomNumberGenerator) -> void
```
- `removal_order`: pairs of tiles such that, starting from `mask` and removing the pairs in order,
  both tiles of each pair are free at their step (under the geometry's rules, features included)
  and the end is empty. Uses every tile of `mask` exactly once. Returns `[]` if it finds none within
  the budget (or `mask == 0`). Same inputs and rng state give the same result.
- `assign_faces`: needs `pair_keys.size() == order.size()`. Pair keys are shuffled with `rng`; pair
  k of `order` gets one key, one tile side A and the other side B (which tile is A is random).
  Tiles not in `order` get `-1`. Playing `order` forward is then a solution.
- (v2) `trap_links(geometry, order)`: with `S_0` = every tile of `order` and `S_k+1 = S_k` minus
  the tiles of `order[k]`, every `Vector4i(q, p, x, y)` with `q < p`, `x` a tile of `order[q]`, `y`
  a tile of `order[p]`, x covering y (`geometry.cover[y]` has bit x), and the **other** tile of
  `order[p]` free in `S_q`. Sorted ascending by (q, p, x, y). Meaning: if x and y become mates and
  the other two tiles of their steps are mates too, then pairing those two at step q (both free)
  leaves x on top of its only mate y: a trap.
- (v2) `assign_faces_trapped`: needs `pair_keys.size() == order.size()`.
  1. `links = trap_links(geometry, order)`; shuffle a copy of `links` (Fisher-Yates with `rng`,
     same as `shuffle_ints`), then shuffle a copy of `pair_keys` with `rng`.
  2. `wanted = roundi(trap_rate * order.size() / 2.0)`. Walk the shuffled links; while fewer than
     `wanted` traps are made, take a link `(q, p, x, y)` when steps q and p are both still without
     a key **and** some key value still has at least 2 unused copies: use the first such key value
     in the shuffled key list, mark two of its copies used, and with `s = rng.randi_range(0, 1)`
     set `x` side s, the other tile of q side 1-s, `y` side 1-s, the other tile of p side s.
  3. Every step still without a key, in step order, gets the next unused key of the shuffled list,
     and its first tile (`order[k].x`) side `rng.randi_range(0, 1)`, the other tile the other side.
  With `trap_rate == 0` no link is used, but the rng is still advanced by step 1.
  Playing `order` forward is a solution.
- (v2) `live_traps(geometry, order, faces)`: the number of links `(q, p, x, y)` of `trap_links`
  where `faces[x]` and `faces[y]` are mates and the other two tiles of steps q and p are mates.
- `deal`: `removal_order` on the full mask + `assign_faces`. Returns
  `{"faces": PackedInt32Array, "solution": Array[Vector2i]}`, or `{}` if no order was found.
- (v2) `deal_v2`: on `geometry` **without** features: `removal_order` on the full mask (same
  budget as `deal`), then `assign_faces_trapped` (always, even for `trap_rate == 0`), then
  `HalvesFeatures.place(geometry, order, faces, feature_spec, rng)`, with one rng in that order.
  Returns `{"faces", "solution", "features", "traps": live_traps(...)}` or `{}` if no order was
  found or `pair_keys.size() * 2 != geometry.size()`.
- `remaining_pair_keys`: for every remaining side-A face, its pair key; sorted ascending.
- `shuffle`: returns `{"remaining": int, "faces": PackedInt32Array, "reseated": bool}` (or `{}` when
  the board is clear). The remaining faces keep their multiset (same faces, new places), and the
  returned board has a removal order consistent with its faces under `state.geometry` (features
  included). `reseated` is false when the tile positions are unchanged (`remaining` equals
  `state.remaining`); when true, `remaining` is exactly the set left by the first `k` pairs of
  `solution`, where `k = (geometry.size() - tiles_left) / 2`. Faces of tiles outside the returned
  `remaining` are `-1`.
- `shuffle_rng(level, count)`: `SeedService.make_rng(["halves", level, "shuffle", count], GEN_VERSION)`.
  Pool boards (section 3) use their id as `level`.

### `HalvesSolver` (`halves_solver.gd`, static)
```
enum Status { SOLVED, UNSOLVABLE, UNKNOWN }
static func solve(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int,
		budget: int = 20000) -> Dictionary        # {"status": Status, "moves": Array[Vector2i]}
static func hint(state: HalvesState, budget: int = 5000) -> Vector2i
static func most_freeing_pair(geometry: HalvesGeometry, remaining: int, pairs: Array[Vector2i]) -> Vector2i
```
- `solve`: depth-first search over free matching pairs, remembering dead states, giving up after
  `budget` expanded states (`UNKNOWN`; a budget of 0 expands nothing). When every remaining tile
  of a pair type is free, one of its pairs is taken without branching (it can never hurt). `SOLVED`
  moves clear `remaining` when played in order; `remaining == 0` is `SOLVED` with no moves.
  `UNSOLVABLE` only when the search is exhausted.
- `hint`: the first move of a `SOLVED` result; `Vector2i(-1, -1)` when `UNSOLVABLE` or there is no
  free pair. If `UNKNOWN` (v2): `most_freeing_pair` over the free pairs that are **not** trap moves
  (`HalvesBot.is_trap_move`); if every free pair is a trap move, `most_freeing_pair` over all of them.
- `most_freeing_pair`: the pair that leaves the most free tiles; ties keep the earliest in `pairs`.

### `HalvesBot` (`halves_bot.gd`, static): difficulty rating
```
enum Policy { RANDOM, CAREFUL, WARY }                                          # WARY (v2)
static func play(geometry: HalvesGeometry, faces: PackedInt32Array,
		rng: RandomNumberGenerator, policy: Policy) -> Dictionary
static func is_trap_move(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: int,
		pair: Vector2i) -> bool                                                  # (v2)
static func rate(geometry: HalvesGeometry, faces: PackedInt32Array, seed_parts: Array,
		runs: int = 50) -> Dictionary
static func difficulty(random_win: float, decoy_exposure: float, avg_free_pairs: float) -> float
```
- `play`: from a full board, repeatedly removes one free matching pair until clear or stuck.
  RANDOM picks a uniformly random free pair; CAREFUL picks the pair that leaves the most free tiles
  (ties random); (v2) WARY picks a uniformly random free pair among those that are not trap moves,
  or among all free pairs if every one is a trap move. Returns `{"cleared": bool, "steps": int,
  "free_pairs": float, "decoy": float}`. `steps` counts removed pairs. `free_pairs` and `decoy` are
  means over every board the bot looked at, **including the final stuck board** when it got stuck:
  `free_pairs` = free pairs on it, `decoy` = (unordered pairs of free tiles that are decoys) /
  max(1, free pairs).
- (v2) `is_trap_move(geometry, faces, remaining, pair)`: with `after` = `remaining` without the two
  tiles of `pair`: true if `after != 0` and `after` has no free matching pair, or if some pair key
  has exactly two tiles left in `after` and one of them covers the other. (A half on top of its
  last mate can never be matched: the classic dead end a human learns to see.)
- `rate`: one rng `SeedService.make_rng(seed_parts + ["rate"], GEN_VERSION)`; `runs` RANDOM games,
  then `runs` CAREFUL games, then (v2) `runs` WARY games. Returns `{"runs", "random_win",
  "careful_win", "wary_win", "avg_free_pairs", "decoy_exposure", "difficulty"}`; win rates are the
  share of cleared games; `avg_free_pairs` and `decoy_exposure` are the mean of each RANDOM game's
  `free_pairs` / `decoy`. (The WARY games come last, so the other values are what v1 gave.)
- `difficulty = 100 * (0.6 * (1 - random_win) + 0.25 * min(decoy_exposure / 1.5, 1)
  + 0.15 * (1 - min(avg_free_pairs, 6) / 6))`, from 0 (trivial) to 100.

### `HalvesRun` (`halves_run.gd`, RefCounted) (v2): the clock and the move log
```
enum Event { PAIR, MISMATCH, UNDO, SHUFFLE, HINT }
const FORMAT := 1
const MAX_STEP_MS := 250
var board: String              # "level_12", "daily_2026-10-21", "zen", "rush"
var level: int                 # the board's level or pool id (what shuffle_rng gets)
var gen_version: int
var free_mistakes: int         # what the game set on the state
var strict: bool
var active_ms: int = 0
var started: bool = false
var finished: bool = false
var events: Array              # [[t_ms, kind, a, b], ...] oldest first
func start() -> void                      # starts the clock (no-op once started)
func advance(delta_ms: int) -> void       # only while started and not finished: active_ms += clamp(delta_ms, 0, MAX_STEP_MS)
func record(kind: Event, a: int = -1, b: int = -1) -> void   # starts the clock if needed; appends [active_ms, kind, a, b]; ignored once finished
func finish() -> void
func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> HalvesRun
static func replay(level: HalvesLevelData, run: Dictionary, level_gen: int = -1) -> Dictionary
```
- Event arguments: `PAIR a b` and `MISMATCH a b` are the two tiles in tap order; `UNDO` none;
  `SHUFFLE count stuck`: `count` is the board's shuffle counter used for `shuffle_rng` and `stuck`
  is 1 or 0; `HINT a b` is the hinted pair (information only). `SWITCH`, `BLOCKED` and `INVALID`
  taps are not recorded.
- `to_dict()`: `{"format": 1, "board", "level", "gen", "free_mistakes", "strict", "active_ms",
  "events"}`. `from_dict(to_dict())` gives an equal run (ints are cast back from JSON floats).
- `replay(level, run)`: builds `level.new_state()`, sets `free_mistakes` and `strict` from the run,
  then applies the events in order: `PAIR` must give `MATCH`; `MISMATCH` must give `MISMATCH`;
  `UNDO` must return true; `SHUFFLE` needs `stuck == (1 if state.is_stuck() else 0)` and applies
  `HalvesFill.shuffle(state, level.solution, HalvesFill.shuffle_rng(run.level, count))` with
  `apply_deal(..., stuck == 1)`. Event times must never decrease and never exceed `active_ms`.
  Returns `{"ok": bool, "error": String, "cleared": bool, "stars": int, "slips": int}`; `ok` is
  false (with a readable `error`) at the first event that does not hold, and when the run's `gen`
  differs from the board's gen version: `level_gen` when given (pools pass `HalvesPools.gen_version`),
  else `HalvesLevels.gen_version()`.

### `HalvesLevels` (`halves_levels.gd`) and `HalvesLevelData`
```
const PATH := "res://data/levels/halves_v2.json"
const COUNT := 100
static func get_level(n: int) -> HalvesLevelData   # 1-based; null if missing
static func count() -> int                         # levels in the file (== COUNT)
static func gen_version() -> int
```
`HalvesLevelData`: `level: int`, `role: String`, `mask: String`, `tip: String` (v2, "" if none),
`seed_parts: Array`, `positions: Array[Vector3i]`, `faces: PackedInt32Array`,
`solution: Array[Vector2i]`, `features: Dictionary` (v2, normalised, `{}` if none),
`stats: Dictionary`, `func par_ms() -> int` (v2, `stats.par_ms` or 0),
`func geometry() -> HalvesGeometry` (v2: with the features), `func new_state() -> HalvesState`,
`func to_dict() -> Dictionary`, `static func from_dict(entry: Dictionary) -> HalvesLevelData`.
JSON numbers are read back as ints. `to_dict` writes `features` and `tip` only when not empty.

### `HalvesPools` (`halves_pools.gd`, static) (v2)
```
enum Kind { DAILY, ZEN, RUSH }
const DAILY_EPOCH := "2026-10-01"           # daily #1
static func count(kind: Kind) -> int
static func gen_version(kind: Kind) -> int
static func get_board(kind: Kind, index: int) -> HalvesLevelData   # index wraps (posmod) over count; null if the pool is empty
static func daily_number(date: String) -> int                      # 1 + days from DAILY_EPOCH to `date` ("YYYY-MM-DD"); 1 for dates before the epoch
static func daily_board(date: String) -> HalvesLevelData           # get_board(DAILY, daily_number(date) - 1)
static func run_order(kind: Kind, seed_parts: Array) -> PackedInt32Array   # a permutation of 0..count-1, shuffled with SeedService.make_rng(seed_parts, gen_version(kind))
```
Each pool file is loaded only when first asked for.

### `HalvesConfig` (`halves_config.gd`): tunables
`GEN_VERSION = 2`, `FREE_USES = 1`, `PRICE_HINT = 30`, `PRICE_UNDO = 30`, `PRICE_SHUFFLE = 40`,
`STAR2_MAX_MISTAKES = 2` (slips), `TUTORIAL_FORGIVE_LEVELS = 4`, `MATE_PULSE_LEVELS = 2`,
`STRICT_MISTAKES = false`, `STUCK_DELAY = 0.5` s, `COINS_PER_STAR = 10`, and (v2):
`GOLD_COINS = 5` (per gold tile), `SWIFT_COINS = 10`, `COMBO_WINDOW = 2.5` s,
`COMBO_COINS_AT = 5` and `COMBO_COINS = 5`, `ZEN_UNLOCK_LEVEL = 10`, `RUSH_UNLOCK_LEVEL = 15`,
`RUSH_SECONDS = 180`, `RUSH_BOARD_BONUS_S = 5`, `RUSH_MISTAKE_PENALTY_S = 3`,
`RUSH_BOARD_POINTS = 10`, and the par constants of section 4.

### Places, backgrounds, music and view (not part of the logic contract)
`HalvesChapters` holds the ten places of ten levels (photo, credit, ambient effect, accent, win
jingle) and the home screen's own (`MENU`). `ChapterBackground` shows a place's photo or, if the
player chose "Drawn" in Settings, the same place drawn in code (`HalvesScenery`). `HalvesMusic`
holds the music styles the player picks (lo-fi and calm playlists; rain, nature and focus loops).
Dev mode (`Settings.dev_mode()`, debug builds only) opens every level and adds a Skip button.
`HalvesBoardView` (Control) lays the tiles out to fit `%Board`, hit-tests taps top tile first, and
plays the feedback; `HalvesTileView` (Node2D) draws one tile with its feature overlays;
`HalvesSnapFx` and `HalvesShardPool` are the match effects; `HalvesPalette` holds the art colours.
The game screen (`ui/screens/game.gd`) owns boosters, coins, the stuck card, the run clock and the
level flow; `HalvesRecords` keeps best times, the daily streak and the best-run logs.

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
in text form), "target_win", "target_decoy"}` and (v2, all optional):
- `"trap": [lo, hi]`: trap rates for the candidates (default `[0, 0]`);
- `"features": {"key_pairs", "locked", "frost", "mist", "gold"}`: the `HalvesFeatures.place` spec (default `{}`);
- `"min_careful"`: lowest accepted CAREFUL win rate (default when missing: 0.8, or 0.6 for hard and finale);
- `"min_wary"`: lowest accepted WARY win rate (default when missing: 0). The table in section 6 is what
  the drafted plan uses; the defaults only apply to slots without the field;
- `"tip"`: the tip card shown on this level (default none).
The mask's tile count / 2 pairs are spread over `types` round-robin in the listed order (so earlier
types get the extra copies).

### Baked levels: `data/levels/halves_v2.json` (exported)
```json
{"gen_version": 2, "count": 100, "levels": [
{"level": 1, "role": "intro", "mask": "p1_intro", "seed_parts": ["halves", 1, 7],
 "tiles": [[0, 0, 0, "circle:v:-:a"], ...], "solution": [[0, 3], ...],
 "features": {...}, "tip": "pair", "stats": {"runs": 50, "random_win": 1.0, ..., "par_ms": 25000}}
]}
```
One level per line. `tiles` are sorted by `(z, y, x)`; `solution` uses tile ids. `seed_parts` are
`["halves", level, candidate]` and rebuild the level exactly with `gen_version` (section 4). `stats`
has `runs, random_win, careful_win, wary_win, avg_free_pairs, decoy_exposure, difficulty,
start_free_pairs, traps, trap_rate, par_ms`. Never edit this file by hand and never change a
shipped level: bump `gen_version` and write a new file instead.

### Pools (v2): `data/levels/halves_daily_v2.json`, `halves_zen_v2.json`, `halves_rush_v2.json`
`{"gen_version": 2, "kind": "daily", "count": N, "boards": [...]}`, one board per line, each board
in the level format with `"level"` = the board id: `10000 + i` (daily), `20000 + i` (zen),
`30000 + i` (rush) for board index i. Pool recipes live in `tools/levelgen/halves_pools.json`.

## 4. Generating
```
godot --headless --path . -s tools/levelgen/generate_halves.gd                        # all 100 levels
godot --headless --path . -s tools/levelgen/generate_halves.gd -- 5                   # just level 5 (preview)
godot --headless --path . -s tools/levelgen/generate_halves.gd -- --pool daily        # a pool
powershell -File tools/levelgen/generate_parallel.ps1                                 # everything, 4 processes
```
For each slot: parse and validate the mask, build the pair keys, then for candidates
`k = 0..CANDIDATES-1` (120): `rng = SeedService.make_rng(["halves", level, k], GEN_VERSION)`,
`trap_rate = lo + (hi - lo) * (k % 4) / 3.0`, and
`HalvesFill.deal_v2(geometry, keys, rng, trap_rate, slot.features)`. The candidate is rated on
`geometry.with_features(features)`. A quick 12-run screen keeps the best 6, which are rated with 50
runs per policy. The candidate with the lowest `2 * |random_win - target_win| +
0.5 * |decoy_exposure - target_decoy|` wins (ties: lower k). Rejected: no deal found, `careful_win`
under `min_careful`, `wary_win` under `min_wary`, or (after level 1) fewer than 2 free pairs at the
start. Output: `data/levels/halves_v2.json` and a report `tools/levelgen/reports/halves_v2.csv`.

**Par.** `par_ms = ceil(s / PAR_ROUND_S) * PAR_ROUND_S * 1000` with
`s = (PAR_BASE_S + pairs * PAR_PER_PAIR_S + types * PAR_PER_TYPE_S + layers * PAR_PER_LAYER_S
+ feature_tiles * PAR_PER_FEATURE_S) * (1 + difficulty * PAR_DIFFICULTY_SCALE)`, where `types` is
the number of distinct pair keys, `layers = max_z + 1` and `feature_tiles =
HalvesFeatures.tile_count(features)`. Constants in `HalvesConfig`: `PAR_BASE_S = 10.0`,
`PAR_PER_PAIR_S = 1.6`, `PAR_PER_TYPE_S = 1.5`, `PAR_PER_LAYER_S = 3.0`, `PAR_PER_FEATURE_S = 1.0`,
`PAR_DIFFICULTY_SCALE = 0.004`, `PAR_ROUND_S = 5`. They are for the human to tune after real plays
(the dev console's `stats` command lists times per level).

**Pools** use the same steps with fewer candidates (`POOL_CANDIDATES`), the recipe of
`halves_pools.json` for each board (daily: by the weekday of its date, easiest on Monday, hardest on
Sunday), and seed parts `["halves", kind, i, k]`.

## 5. Checking
- `tools/check.ps1`: the logic tests (`tests/test_halves_*.gd`, written from this file by a
  separate session), the baked-file checks, and `test_halves_game.gd`.
- `tools/levelgen/bench_halves.gd`: times deal, bot games, solve and hint on the biggest board.
- `tools/snapshots.ps1 -Styles halves -Only game_l1,game_selected,game_l21,game_l41,game_l61,game_l100,game_stuck,booster`.
- `godot --path . -s tools/halves_playtest.gd -- 10` plays a level in a window with real taps and
  saves the key frames to `build/playtest/`; add `still` after the level to check Reduce Motion.

## 6. Tuning
- **Difficulty dials:** the mask (how many tiles are free at once, how deep the stacks are), the trap
  rate, the number of pair types vs copies (more copies = more twins and more traps), cuts and
  marks (near-twins), features, and the targets in the plan.
- **Sawtooth in packs of 10:** a rest level brings each new idea (x1 or x6), x5 is hard and x0 is a
  finale. Core rules are all taught by level 10: layers (2), side blocking (3), decoys (4), the
  first trap (5), horizontal cuts (6), diamonds (7), dot marks (8), line marks (9); gold tiles arrive at 11. New
  features open the later difficulty bands (20 levels each in the generator): mist (21), locks (41), frost (61); band 5 (81-100) mixes all.
- **Role targets** (random / min WARY / min CAREFUL / trap rate):

  | Role | random | wary ≥ | careful ≥ | trap |
  |---|---|---|---|---|
  | intro | 1.0 | 1.0 | 1.0 | 0 |
  | rest | 0.75–0.9 | 0.97 | 0.8 | ≤ 0.1 |
  | ramp | 0.6 falling to 0.4 by band 5 | 0.9 | 0.6 | 0.15–0.3 |
  | hard | 0.15–0.3 | 0.75 | 0.4 | 0.3–0.5 |
  | finale | 0.05–0.15 | 0.6 | 0.3 | 0.4–0.6 |

- Booster prices, free uses, coins and par constants: `HalvesConfig`.
