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

### Pairs, crests and look-alike groups (v3)
v3 adds **crests**: Japanese family-crest motifs (blossoms, leaves, waves, ...) drawn in code. The
rule players read: *tap a half, then the other half of the same crest; never two of the same half.*
- A face is `pair << 1 | side`: `pair_key = face >> 1` and `mate = face ^ 1`, as in v2.
- **Pair ids 0-31 are the v2 shapes**, numbered exactly as before (`shape << 3 | cut << 2 | mark`,
  valid where v2 says so), so v2 levels, seeds, shuffles and saved runs are unchanged.
- **Pair ids from 32 are crests:** `pair = 32 + motif * 2 + cut`, where `motif` indexes
  `HalvesCrests.MOTIFS` and `cut` is 0 (vertical: left/right halves) or 1 (horizontal: top/bottom).
  A motif lists the cuts it allows; a pair with a cut its motif does not allow is invalid.
- Every pair has a **family** (its ink colour, sound and Crest Book page; v2 shapes are family
  `shapes`) and a **look-alike group** (v2 shapes: the shape name; crests: from the catalogue).
- **Match:** same pair, opposite sides (unchanged).
- **Decoy (v3):** same look-alike group, not a match (twins included). For v2 shapes this is exactly
  the v2 rule. Two crests of different groups only move the selection (SWITCH), never a mistake.
- Text: v2 faces keep `"circle:v:dot:a"`; a crest face is `"<motif>:<cut>:<side>"` (e.g.
  `"sakura:v:a"`), its pair `"sakura:v"`.

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

### Mechanics (v3)
Each is introduced on a rest level of its own place, at most one new idea per place, and is meant
to be read from one picture.

| Mechanic | Rule | Shown as |
|---|---|---|
| **Gold pair** (faces, not a feature) | A pair whose faces are the gold crest (`HalvesCrests` motif `kin`, family `gold`, group `gold`). It matches like any pair. Clearing it gives one **mend** for this board. At most one gold pair per board. | Tiles with a gold face and a dark crest. A Mend button with a count appears on the booster bar while mends > 0. |
| **Mend** (earned) | With a mend, tap Mend, then a free tile `a`: `a` and `b` = a remaining tile with the mate face of `a` (covered, side-blocked, locked or frosted alike; chosen by `HalvesState.mend_mate`, below) are removed as a pair. Not a slip, costs no coins, never suggested by the hint. If `a` has no remaining mate, nothing happens. | The mate lifts out of the stack and flies to `a`; a gold-seam snap. |
| **Turned** (feature `turned`) | No effect on the rules. The tile's half is drawn turned 90° clockwise. Positional (stays with the position on a shuffle). | The turned half; nothing else marks it. |
| **Lucky** (feature `lucky`) | No effect on solvability. A lucky tile's clock starts the first time it is free (after `_init`, a pair, a mend, an undo or a deal; `pairs_done` = pairs + mends made so far). Removing it while `pairs_done - start < LUCKY_SNAPS` (3) wins `LUCKY_COINS` (5) coins at the end of the board. Positional. | A soft gold glow with three dots that empty by pairs, not seconds; "+5" when won. |

Gold (v2 coin tiles) stays readable in v2 data; v3 data uses lucky instead.

**Which mate a mend takes, and why the board stays solvable.** In any solution of the current board,
`a` is paired with some mate `b*`. Removing `a` and `b*` drops one step of that solution and leaves
every other step valid (fewer tiles only unblock), so the rest is still solvable. Another mate is not
safe: with twins, pulling out the wrong one can strand a half on its only mate (tiles `circle a` at
(0,0,0), `circle b` at (4,0,0), `circle a` at (6,0,0), `circle b` at (5,0,1) bridging the two: mending
the first with the lowest-id `circle b` leaves the top `circle b` lying on its only mate). So
`mend_mate` takes the lowest-id mate whose removal with `a` leaves the board solvable, as the solver
proves within `HalvesConfig.MEND_BUDGET` nodes per mate; if none is proven, the lowest-id mate not
proven unsolvable; else the lowest-id mate. With one remaining mate it takes that one without asking
the solver. On a solvable board within the budget, a mend therefore never makes it unsolvable.

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
- Stars (v2, replaced by v3 below): **3** with no slips ("flawless"), **2** with 1 to
  `STAR2_MAX_MISTAKES` (2) slips, **1** otherwise. Boosters never cost stars by themselves: a
  shuffle applied while stuck is a slip because of the dead end, whichever button applied it.
- **Stars (v3): a slip allowance.** No researched mahjong game takes a star for one wrong tap.
  - The **allowance** `A` comes from `HalvesConfig.star_allowance(mode, level, pairs)`:
    unlimited (`-1`) in the LEVELS mode on levels `1..STAR_FREE_LEVELS` (10), otherwise
    `max(1, pairs / STAR_ALLOWANCE_PAIRS)` with integer division (`STAR_ALLOWANCE_PAIRS` = 15).
    `pairs` is the board's tile count / 2. Rush and zen have no stars (the allowance is unused).
  - `stars(A)`: **3** if `A < 0` or `slips <= A`; **2** if `slips <= A + STAR2_EXTRA_SLIPS` (3);
    else **1**. Clearing the board always gives at least 1.
  - Undoing a mistake still takes it back (as v2). Boosters still never cost stars by themselves.
  - The results screen says "Flawless" for 0 slips, otherwise "N slips (A free)" ("N slips" when
    the allowance is unlimited).

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
| Levels | (v3) the 300 baked levels, in 15 places of 20 (one sawtooth pack each; v2: 100 in 10 of 10) | stars, time, par | The main journey. |
| Daily | one board of the daily pool per calendar day (local date) | stars, time | Same board for everyone on that date. Finishing it extends the daily streak. No interstitials. |
| Zen | the zen pool, endless, in a seeded order | none | No timer, no stars, no ads. Unlocks after level `ZEN_UNLOCK_LEVEL`. |
| Rush | the rush pool, in a seeded order | score | `RUSH_SECONDS` on the clock; each cleared board adds `RUSH_BOARD_BONUS_S`, each mistake takes `RUSH_MISTAKE_PENALTY_S`; a stuck board shuffles itself. Score = pairs cleared + `RUSH_BOARD_POINTS` per cleared board. Unlocks after level `RUSH_UNLOCK_LEVEL`. |

## 2. Code (`game/halves/`, shipped)
All logic is pure (static functions or `RefCounted`), statically typed and deterministic: random
choices use a seeded `RandomNumberGenerator` passed in, never `randi()`, `Array.shuffle()` or
`pick_random()`. Tile ids are indices into the level's tile list, which is sorted by `(z, y, x)`.
v2: a set of tiles was an `int` bitmask (at most 64 tiles). **(v3) A set of tiles is a
`HalvesBits` set** (below, at most 128 tiles): every parameter, field and return value that this
section calls a mask is such a set, with the same name and meaning.

### `HalvesBits` (`halves_bits.gd`, static) (v3)
A set of tile ids `0..127`: a `PackedInt64Array` of exactly two words; tile `i` is bit `i & 63` of
word `i >> 6` (test bits with `!= 0`, bit 63 makes a word negative). Packed arrays are passed by
reference in GDScript, so **every function returns a new array and never changes its arguments**,
except `set_bit` and `clear_bit`, which change `s` in place for hot loops.
```
const WORDS := 2
const MAX := 128
static func empty() -> PackedInt64Array
static func full(count: int) -> PackedInt64Array            # tiles 0..count-1 (0 <= count <= 128)
static func of(ids: Array) -> PackedInt64Array              # ints (or whole floats from JSON)
static func has(s: PackedInt64Array, i: int) -> bool
static func added(s: PackedInt64Array, i: int) -> PackedInt64Array
static func removed(s: PackedInt64Array, i: int) -> PackedInt64Array
static func set_bit(s: PackedInt64Array, i: int) -> void    # in place
static func clear_bit(s: PackedInt64Array, i: int) -> void  # in place
static func union(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array
static func intersection(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array
static func minus(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array   # a and not b
static func is_empty(s: PackedInt64Array) -> bool
static func intersects(a: PackedInt64Array, b: PackedInt64Array) -> bool
static func is_subset(a: PackedInt64Array, b: PackedInt64Array) -> bool          # every tile of a is in b
static func equal(a: PackedInt64Array, b: PackedInt64Array) -> bool
static func count(s: PackedInt64Array) -> int
static func ids(s: PackedInt64Array) -> PackedInt32Array    # ascending
static func first(s: PackedInt64Array) -> int               # lowest id, -1 if empty
```
Ids outside `0..127` are ignored: `of` skips them, `has` is false, `added`, `removed`, `set_bit` and
`clear_bit` leave the set as it is. A set is a valid `Dictionary` key (packed arrays compare by content), so solver memos key on it
directly. `HalvesGeometry.popcount` becomes `HalvesBits.count`; `HalvesGeometry.MAX_TILES` is 128.

### `HalvesFace` (`halves_face.gd`, static; a face is an `int`)
(v3) A face is `pair << 1 | side` (section 1, Pairs). The v2 functions below keep their meaning
for pairs 0-31; `shape` and `mark` return -1 for crest pairs, and `cut` works for both (v2: bit 3
of the face; crests: bit 1). `is_valid`, `is_decoy`, `to_text`, `from_text`, `pair_to_text` and
`pair_from_text` (v3) accept crest faces as well, through `HalvesCrests`. New in v3:
```
static func is_crest(face: int) -> bool             # pair_key(face) >= HalvesCrests.FIRST_PAIR
static func family(face: int) -> StringName          # &"shapes" for v2 pairs
static func group(face: int) -> StringName           # look-alike group (v2: the shape name)
```
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

### `HalvesCrests` (`halves_crests.gd`, static) (v3): the crest catalogue
```
const FIRST_PAIR := 32
const FAMILIES: Array[Dictionary]   # {"id": &"blossoms", "name": "Blossoms"}; order = Crest Book order
const MOTIFS: Array[Dictionary]     # {"id": &"sakura", "name": "Cherry blossom", "family": &"blossoms",
                                     #  "group": &"blossom5", "cuts": [0, 1], "spec": {...}}
static func motif_count() -> int
static func motif_index(id: StringName) -> int       # -1 if unknown
static func pair_of(motif: int, cut: int) -> int     # FIRST_PAIR + motif * 2 + cut
static func motif_of(pair: int) -> int               # -1 for v2 pairs and unknown ids
static func cut_of(pair: int) -> int                 # works for v2 pairs too
static func is_valid_pair(pair: int) -> bool         # v2 rule below FIRST_PAIR; else known motif + allowed cut
static func family_of(pair: int) -> StringName       # &"shapes" for v2 pairs; &"" if invalid
static func group_of(pair: int) -> StringName        # v2: &"circle" / &"tri" / &"square" / &"diamond"
static func pairs_in_family(family: StringName) -> PackedInt32Array   # every valid pair, ascending
static func similarity(pair_a: int, pair_b: int) -> float  # 0..1, 1 only for the same pair (see below)
```
- Motif ids are unique; every motif's family is in `FAMILIES`; every motif allows at least one
  cut. Appending motifs never renumbers existing pairs (baked levels store face text, not ints).
- `similarity`: 1.0 for the same pair; 0.0 for different groups; within a group
  `0.5 + 0.4 * shared / total` where `shared` counts the equal top-level `spec` entries and `total`
  the distinct top-level keys of both specs, minus 0.1 if the cuts differ; v2 pairs within a shape:
  0.8 for the same mark and other cut, 0.6 for another mark. Used to rate how easy a decoy is to
  mistake (generator and the perceptive bot).
- (v3) The last family is `gold` with one motif, `kin` (a radiant gold crest), group `gold`: the gold
  pair's faces (section 1, Mechanics). Gold faces are drawn dark on a gold tile.
- Never in the catalogue: the 16-petal imperial chrysanthemum, the government paulownia, the
  Tokugawa hollyhock, three diamonds in a triangle (corporate mark).

### `HalvesCrest` (`halves_crest.gd`, static) (v3): crests drawn in code
A motif's `spec` describes layers of compass-and-ruler primitives in unit space (the crest fits in
the circle of radius 1 around the origin; y points down). Each layer is `ink` (family colour) or
`paper` (the tile face colour, painted over ink to cut holes), drawn in order.
```
static func layers(motif: int) -> Array[Dictionary]                 # [{"ink": bool, "polygons": Array[PackedVector2Array]}]
static func half_layers(motif: int, cut: int, side: int) -> Array[Dictionary]  # clipped to the half-plane
static func draw(canvas: CanvasItem, pair: int, side: int, center: Vector2, extent: float,
		ink: Color, paper: Color, offset: Vector2 = Vector2.ZERO) -> void   # side -1 = whole crest
```
- A half is the crest clipped to `x <= 0` (side a, vertical), `x >= 0` (side b, vertical),
  `y <= 0` (side a, horizontal) or `y >= 0` (side b, horizontal), so drawing both halves at the same
  centre draws the whole crest, with the cut on the centre line (as v2 shapes).
- Polygons are cached per motif (whole) and per (motif, cut, side) (halves); `extent` only scales.
- `HalvesShapes.draw_half / draw_whole` keep their signatures and call `HalvesCrest.draw` for crest
  faces (ink: `HalvesPalette.family_color(family)`), so tile views, the snap effect and the logo
  draw crests without changes.

### `HalvesGeometry` (`halves_geometry.gd`, RefCounted)
```
const MAX_TILES := 128                                                # (v3; v2: 64)
enum Block { FREE, COVERED, SIDES, LOCKED, FROSTED }                  # (v2)
var positions: Array[Vector3i]
var cover: Array[PackedInt64Array]       # cover[i]: tiles that lie on top of tile i
var left: Array[PackedInt64Array]        # left[i]: its left neighbours (right[i] likewise)
var right: Array[PackedInt64Array]
var touch: Array[PackedInt64Array]       # (v2) touch[i]: tiles touching i (section 1, Features)
var lock_need: Array[PackedInt64Array]   # (v2) empty without features; else lock_need[i] = union of the key masks of i's lock groups
var frost_need: Array[PackedInt64Array]  # (v2) empty without features; else touch[i] for frosted tiles, the empty set for the others
var features: Dictionary           # (v2) the normalised features ({} without)
static func from_positions(positions: Array[Vector3i]) -> HalvesGeometry   # keeps the given order; no features
func with_features(features: Dictionary) -> HalvesGeometry  # (v2) a new geometry (same positions) with the rules; never mutates self
func has_features() -> bool                                  # (v2) features is not empty
func size() -> int
func full_mask() -> PackedInt64Array                                # every tile present
func is_free(i: int, remaining: PackedInt64Array) -> bool           # rules of section 1, against the tiles in `remaining`
func blocked_reason(i: int, remaining: PackedInt64Array) -> Block   # (v2) the first that applies: COVERED, SIDES, LOCKED, FROSTED; else FREE
func free_mask(remaining: PackedInt64Array) -> PackedInt64Array     # free tiles among `remaining`
func free_tiles(remaining: PackedInt64Array) -> PackedInt32Array    # ascending ids
func bounds() -> Rect2i                              # x/y extent in half-units (from 0,0 to max x+2, y+2)
func max_z() -> int
```
`is_free(i, remaining)` (v2) is: not covered, sides open (as v1), and, when the geometry has
features, `lock_need[i]` does not intersect `remaining` and (`frost_need[i]` is empty or
not a subset of `remaining`). A geometry without features behaves exactly as v1.
`with_features({})` returns a geometry equal to one without features. (v3) The per-tile sets
are read-only: `is_free`, `free_mask` and `free_tiles` read flat word copies made when the
geometry is built. `popcount` is gone (use `HalvesBits.count`).

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
static func mask(ids: Array) -> PackedInt64Array                    # (v3) HalvesBits.of(ids)
```
- `normalize`: ints everywhere (JSON floats cast), every list sorted ascending and without
  duplicates, empty lists and lock groups with no keys or no locked tiles removed; key order
  `locks, frost, mist, gold, turned, lucky` ((v3) adds `turned` and `lucky`, lists of tile ids).
  `normalize(normalize(x)) == normalize(x)`.
- `validate` reports, in readable sentences: an id outside `0..size-1`; a lock group whose keys and
  locked tiles overlap; a tile that is a key in one group and locked in another; and, when
  `solution` is given, a pair of the solution whose tiles are not both free (under the rules) at
  their step, or a solution that does not clear the board.
- `place` adds features to a dealt board **after** its removal order is known, so the order stays a
  valid solution under the new rules. `spec` keys (all optional ints, default 0):
  `key_pairs, locked, frost, mist, gold` ((v3) and `turned`, `lucky`). With `n = order.size()`, `step[t]` the step that removes
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
  5. (v3) **Turned:** candidates are tiles not mist; tiles whose face has a look-alike (same group,
     other pair) elsewhere on the board come first. Take the first `turned`.
  6. (v3) **Lucky:** candidates are tiles not free at the start and not mist; tiles whose step is in
     `[n / 3, 2n / 3)` come first. Take the first `lucky`.
  "First" means: the candidate list (preferred group, then the rest) where each group is put in a
  random order with `HalvesFill.shuffle_ints` and `rng`. The rng is used in the order 1, 2, 3, 4 (v3: 5, 6).
  The result is normalised; fewer tiles than asked is fine.

### `HalvesState` (`halves_state.gd`, RefCounted)
```
enum Result { MATCH, MISMATCH, SWITCH, BLOCKED, INVALID }
var geometry: HalvesGeometry
var faces: PackedInt32Array       # faces[i] for tile i
var remaining: PackedInt64Array   # the tiles still on the board
var mistakes: int = 0
var free_mistakes: int = 0        # mismatches that cost nothing (tutorial)
var strict: bool = false
var stuck_shuffles: int = 0       # (v2) shuffles applied while stuck
var veiled: PackedInt64Array      # (v2) mist tiles whose face is still hidden
var gold: PackedInt64Array        # (v2) the gold tiles (mask), from geometry.features
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
func stars(allowance: int = 0) -> int  # (v3) the slip allowance, section 1; -1 = unlimited
func apply_deal(remaining: PackedInt64Array, faces: PackedInt32Array, stuck: bool = false) -> void
```
(v3) The state replaces `remaining`, `veiled` and `gold` with new sets on every change and never
edits them in place, so a set a caller kept (a view's snapshot) stays as it was; `apply_deal`
keeps a copy of the set it is given.
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
`HalvesConfig.STRICT_MISTAKES`. `stars(allowance)` (v3): 3 if `allowance < 0` or
`slips() <= allowance`, 2 if `slips() <= allowance + HalvesConfig.STAR2_EXTRA_SLIPS`, else 1
(`stars(0)` is not the v2 rule: v2 gave 2 stars up to 2 slips, v3 up to 3).

(v2) Mist and gold: `_init` sets `gold` and `veiled` from `geometry.features` (`mist` and `gold`
lists; empty without features), then reveals. **Reveal** means
`veiled = HalvesBits.minus(veiled, geometry.free_mask(remaining))`
and happens after `_init`, after a `MATCH`, after an `undo()` and after `apply_deal`. Revealing never
hides a tile again. `gold_earned` goes up by the number of gold tiles in a matched pair and down by
the number of gold tiles an undone pair returns.

(v3) Mends and lucky tiles (section 1, Mechanics):
```
var mends: int = 0                       # mends earned and not used yet
var pairs_done: int = 0                  # pairs and mends made (undo takes them back)
var lucky: PackedInt64Array              # the lucky tiles, from geometry.features ("lucky")
var lucky_start: Dictionary[int, int]    # lucky tile -> pairs_done when it was first free
var lucky_won: int = 0                   # lucky tiles removed in time
func try_mend(a: int) -> Result          # MATCH, BLOCKED or INVALID (below)
static func mend_mate(board: HalvesGeometry, board_faces: PackedInt32Array, left: PackedInt64Array,
		a: int) -> int                       # the mate a mend takes (section 1); -1 if none
func is_gold(face: int) -> bool          # static; HalvesFace.family(face) == &"gold"
```
- A `MATCH` of two gold faces adds 1 to `mends`.
- `try_mend(a)`: `INVALID` if `mends == 0`, `a` is out of range or not remaining, or no remaining
  tile has the mate face of `a`; `BLOCKED` if `a` is not free; otherwise `MATCH`: `b` =
  `mend_mate(geometry, faces, remaining, a)` (section 1, Mechanics), both leave `remaining`,
  `mends -= 1`, history gets `{"kind": "mend", "a": a, "b": b}`. A mend is not a slip.
- Every pair and mend adds 1 to `pairs_done`. **Lucky clocks:** after `_init`, every `MATCH`, mend,
  `undo()` and `apply_deal`, each lucky tile that is remaining, free and has no clock gets
  `lucky_start[t] = pairs_done`. When a pair or mend removes a lucky tile `t` with a clock and
  `pairs_done` (before that removal is counted) `- lucky_start[t] < HalvesConfig.LUCKY_SNAPS`,
  `lucky_won += 1`.
- `undo()` takes back exactly what the undone entry did: the tiles return, `pairs_done -= 1`, the
  mend it earned (gold pair) or spent (mend) is returned, `lucky_won` loses what that entry won,
  and clocks started by that entry are removed.
- `apply_deal` keeps `mends`, `pairs_done`, `lucky_start` and `lucky_won` (lucky is positional).
- `is_stuck()` is unchanged (a mend is not a free pair); the game offers Mend on the stuck card.

### `HalvesFill` (`halves_fill.gd`, static): reverse-removal fill, traps and shuffle
```
static func removal_order(geometry: HalvesGeometry, mask: PackedInt64Array, rng: RandomNumberGenerator,
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
static func with_gold_pair(geometry: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array,
		rng: RandomNumberGenerator) -> PackedInt32Array                                      # (v3)
static func remaining_pair_keys(state: HalvesState) -> PackedInt32Array
static func shuffle(state: HalvesState, solution: Array[Vector2i],
		rng: RandomNumberGenerator) -> Dictionary
static func shuffle_rng(level: int, count: int) -> RandomNumberGenerator
static func shuffle_ints(values: PackedInt32Array, rng: RandomNumberGenerator) -> void
```
- `removal_order`: pairs of tiles such that, starting from `mask` and removing the pairs in order,
  both tiles of each pair are free at their step (under the geometry's rules, features included)
  and the end is empty. Uses every tile of `mask` exactly once. Returns `[]` if it finds none within
  the budget (or `mask` is empty). Same inputs and rng state give the same result.
- `assign_faces`: needs `pair_keys.size() == order.size()`. Pair keys are shuffled with `rng`; pair
  k of `order` gets one key, one tile side A and the other side B (which tile is A is random).
  Tiles not in `order` get `-1`. Playing `order` forward is then a solution.
- (v2) `trap_links(geometry, order)`: with `S_0` = every tile of `order` and `S_k+1 = S_k` minus
  the tiles of `order[k]`, every `Vector4i(q, p, x, y)` with `q < p`, `x` a tile of `order[q]`, `y`
  a tile of `order[p]`, x covering y (`geometry.cover[y]` contains x), and the **other** tile of
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
- `shuffle`: returns `{"remaining": PackedInt64Array, "faces": PackedInt32Array, "reseated": bool}` (or `{}` when
  the board is clear). The remaining faces keep their multiset (same faces, new places), and the
  returned board has a removal order consistent with its faces under `state.geometry` (features
  included). `reseated` is false when the tile positions are unchanged (`remaining` equals
  `state.remaining`); when true, `remaining` is exactly the set left by the first `k` pairs of
  `solution`, where `k = (geometry.size() - tiles_left) / 2`. Faces of tiles outside the returned
  `remaining` are `-1`.
- `shuffle_rng(level, count)`: `SeedService.make_rng(["halves", level, "shuffle", count], GEN_VERSION)`.
  Pool boards (section 3) use their id as `level`.

(v3) `with_gold_pair` returns a copy of `faces` where the two tiles of one step of `order` get the
gold faces (`kin`, same cut as `HalvesCrests.pair_of(kin, 0)`; the step's side-a tile stays side
a). The step is chosen with `rng` from the steps in `[n / 3, 2n / 3)` (`n = order.size()`, at least
one step), preferring steps whose two tiles are both not free at the start; `order` stays a valid
solution. The generator calls it after dealing faces and before `HalvesFeatures.place`.

### `HalvesSolver` (`halves_solver.gd`, static)
```
enum Status { SOLVED, UNSOLVABLE, UNKNOWN }
static func solve(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: PackedInt64Array,
		budget: int = 20000) -> Dictionary        # {"status": Status, "moves": Array[Vector2i]}
static func hint(state: HalvesState, budget: int = 5000) -> Vector2i
static func most_freeing_pair(geometry: HalvesGeometry, remaining: PackedInt64Array, pairs: Array[Vector2i]) -> Vector2i
```
- `solve`: depth-first search over free matching pairs, remembering dead states (a memo keyed on
  the `remaining` set, v3), giving up after
  `budget` expanded states (`UNKNOWN`; a budget of 0 expands nothing). When every remaining tile
  of a pair type is free, one of its pairs is taken without branching (it can never hurt). `SOLVED`
  moves clear `remaining` when played in order; an empty `remaining` is `SOLVED` with no moves.
  `UNSOLVABLE` only when the search is exhausted.
- `hint`: the first move of a `SOLVED` result; `Vector2i(-1, -1)` when `UNSOLVABLE` or there is no
  free pair. If `UNKNOWN` (v2): `most_freeing_pair` over the free pairs that are **not** trap moves
  (`HalvesBot.is_trap_move`); if every free pair is a trap move, `most_freeing_pair` over all of them.
- `most_freeing_pair`: the pair that leaves the most free tiles; ties keep the earliest in `pairs`.

### `HalvesBot` (`halves_bot.gd`, static): difficulty rating
```
enum Policy { RANDOM, CAREFUL, WARY, PERCEPTIVE }                              # WARY (v2), PERCEPTIVE (v3)
static func play(geometry: HalvesGeometry, faces: PackedInt32Array,
		rng: RandomNumberGenerator, policy: Policy) -> Dictionary
static func is_trap_move(geometry: HalvesGeometry, faces: PackedInt32Array, remaining: PackedInt64Array,
		pair: Vector2i) -> bool                                                  # (v2)
static func rate(geometry: HalvesGeometry, faces: PackedInt32Array, seed_parts: Array,
		runs: int = 50, level: int = 0) -> Dictionary                           # level (v3)
static func difficulty(random_win: float, decoy_exposure: float, avg_free_pairs: float) -> float
```
- `play`: from a full board, repeatedly removes one free matching pair until clear or stuck.
  RANDOM picks a uniformly random free pair; CAREFUL picks the pair that leaves the most free tiles
  (ties random); (v2) WARY picks a uniformly random free pair among those that are not trap moves,
  or among all free pairs if every one is a trap move; (v3) PERCEPTIVE is section 4b's bot. Returns
  `{"cleared": bool, "steps": int, "free_pairs": float, "decoy": float, "slips": int}`. `steps`
  counts removed pairs. `free_pairs` and `decoy` are
  means over every board the bot looked at, **including the final stuck board** when it got stuck:
  `free_pairs` = free pairs on it, `decoy` = (unordered pairs of free tiles that are decoys) /
  max(1, free pairs). (v3) `slips` counts PERCEPTIVE's mistaps (always 0 for the other policies).
  The pairs are listed in ascending (first tile, second tile) order over the ascending free tiles,
  so the rng picks are the same as v2's.
- (v2) `is_trap_move(geometry, faces, remaining, pair)`: with `after` = `remaining` without the two
  tiles of `pair`: true if `after` is not empty and `after` has no free matching pair, or if some pair key
  has exactly two tiles left in `after` and one of them covers the other. (A half on top of its
  last mate can never be matched: the classic dead end a human learns to see.)
- `rate`: one rng `SeedService.make_rng(seed_parts + ["rate"], GEN_VERSION)`; `runs` RANDOM games,
  then `runs` CAREFUL games, then (v2) `runs` WARY games, then (v3) `runs` PERCEPTIVE games.
  Returns `{"runs", "random_win", "careful_win", "wary_win", "avg_free_pairs", "decoy_exposure",
  "difficulty"}` and (v3) `"perceptive_win", "perceptive_slips", "p3"` (section 4b; `p3` uses
  `HalvesConfig.star_allowance(LEVELS, level, tiles / 2)`, so `level` 0, the default, means "a
  level past the star-free ones"; pool boards pass their id). Win rates are the
  share of cleared games; `avg_free_pairs` and `decoy_exposure` are the mean of each RANDOM game's
  `free_pairs` / `decoy`. (The WARY and PERCEPTIVE games come last, so the other values are what
  v1 and v2 gave for the same rng.)
- `difficulty = 100 * (0.6 * (1 - random_win) + 0.25 * min(decoy_exposure / 1.5, 1)
  + 0.15 * (1 - min(avg_free_pairs, 6) / 6))`, from 0 (trivial) to 100.

(v3) Mends in play: every policy that has a mend (it cleared the gold pair) uses it when stuck, on
the free tile whose lowest-id remaining mate has the most tiles covering it (ties: lowest id),
taking the mate `HalvesState.mend_mate` picks (as in play), then carries on; a mend never counts as a slip and the hint never suggests one.

### `HalvesRun` (`halves_run.gd`, RefCounted) (v2): the clock and the move log
```
enum Event { PAIR, MISMATCH, UNDO, SHUFFLE, HINT, MEND }   # MEND (v3): [ms, MEND, a]; replay calls try_mend(a)
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
static func replay(level: HalvesLevelData, run: Dictionary, level_gen: int = -1, allowance: int = 0) -> Dictionary  # (v3) stars use the allowance
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
const PATH := "res://data/levels/halves_v3.json"   # (v3; v2: halves_v2.json, still readable)
const COUNT := 300                                  # (v3; v2: 100)
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
(v3) `place: int` (1-15; 0 when the entry has none: v2 files and pool boards), written by `to_dict`
right after `level` only when above 0.

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
Each pool file is loaded only when first asked for. (v3) The pools are `halves_daily_v3.json`,
`halves_zen_v3.json` and `halves_rush_v3.json` (section 3).

### `HalvesConfig` (`halves_config.gd`): tunables
`GEN_VERSION = 3` ((v3); v2: 2), `FREE_USES = 1`, `PRICE_HINT = 30`, `PRICE_UNDO = 30`, `PRICE_SHUFFLE = 40`,
`STAR2_MAX_MISTAKES = 2` (slips), `TUTORIAL_FORGIVE_LEVELS = 4`, `MATE_PULSE_LEVELS = 2`,
`STRICT_MISTAKES = false`, `STUCK_DELAY = 0.5` s, `COINS_PER_STAR = 10`, and (v2):
`GOLD_COINS = 5` (per gold tile), `SWIFT_COINS = 10`, `COMBO_WINDOW = 2.5` s,
`COMBO_COINS_AT = 5` and `COMBO_COINS = 5`, `ZEN_UNLOCK_LEVEL = 10`, `RUSH_UNLOCK_LEVEL = 15`,
`RUSH_SECONDS = 180`, `RUSH_BOARD_BONUS_S = 5`, `RUSH_MISTAKE_PENALTY_S = 3`,
`RUSH_BOARD_POINTS = 10`, and the par constants of section 4. (v3): `STAR_FREE_LEVELS = 10`,
`STAR_ALLOWANCE_PAIRS = 15`, `STAR2_EXTRA_SLIPS = 3` (`STAR2_MAX_MISTAKES` is no longer used),
`LUCKY_SNAPS = 3`, `LUCKY_COINS = 5` (per lucky tile won), `MEND_BUDGET = 4000`,
`PERCEPTIVE_BASE = 0.25`, `PERCEPTIVE_TURNED = 0.5` (section 4b), and
```
static func star_allowance(mode: int, level: int, pairs: int) -> int   # section 1, Stars (v3); mode is Screens.Mode as int
```

### Places, backgrounds, music and view (not part of the logic contract)
`HalvesChapters` holds the (v3) fifteen places of twenty levels (two photos each, one for levels 1-10 and one for 11-20 via
`half_for_level`; credits, ambient effect, accent, win
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

(v3) `HalvesMask` allows 13 half-units wide, 16 tall and 5 layers (at most `HalvesGeometry.MAX_TILES`;
levels stay at or under 120). The file holds three kinds of masks: the hand-made v1/v2 ones (`p1_*`,
`p2_*`, `p3_*`, and v2's catalogue picks `c<chapter>_*`, kept because the v2 plan and the logic
tests use them), (v3) the **picture masks** `pic_<name>_<s|m|l>` (Fuji, torii, pagoda, fan, koi,
crane, lantern, wave; drafted in `tools/levelgen/picture_masks.gd`, which validates them, checks
the face sizes, prints a preview and writes them here), and (v3) `v3_<catalogue id>`: the shapes
`build_plan.gd` picked from `tools/levelgen/mask_catalogue.gd`'s catalogue (which v3 extends with
staggered walls and 4-step plans up to 5 layers and ~110 tiles). A rerun of `build_plan.gd` drops
and re-picks the `v3_*` masks, so the file and the plan stay in step.

### Level plan: `tools/levelgen/halves_plan.json` (v2) and `halves_plan_v3.json` (v3)
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

(v3) `halves_plan_v3.json` (`"format": 3`, drafted by `tools/levelgen/build_plan.gd`, section 4b) has
the same slot shape with these changes: `"place"` (1-15); roles add `breather`; `"target_p3"`
replaces `"target_decoy"`; `"depth"` records the look-alike chunk size the types were drafted with
(information only); and the optional slot-level `"gold_pair"` (0/1), `"turned"` and `"lucky"`
(counts) that `HalvesGenerator.feature_spec` and `HalvesGenerator.deal` read. With `gold_pair`,
the dealt board's pair types are the round-robin ones with one pair turned into the gold pair.
The v2 plan stays as it was (the logic tests use its boards as fixtures).

### Baked levels: `data/levels/halves_v2.json` and (v3) `halves_v3.json` (exported)
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

(v3) `halves_v3.json`: `{"gen_version": 3, "count": 300, "levels": [...]}`; each level adds
`"place"` after `"level"`, and `stats` adds `perceptive_win, perceptive_slips, p3`.

### Pools (v2): `data/levels/halves_daily_v2.json`, `halves_zen_v2.json`, `halves_rush_v2.json`
`{"gen_version": 2, "kind": "daily", "count": N, "boards": [...]}`, one board per line, each board
in the level format with `"level"` = the board id: `10000 + i` (daily), `20000 + i` (zen),
`30000 + i` (rush) for board index i. Pool recipes live in `tools/levelgen/halves_pools.json`.

(v3) `halves_daily_v3.json` (400 boards), `halves_zen_v3.json` (150), `halves_rush_v3.json` (150),
same format with `"gen_version": 3`. The recipes (`halves_pools.json`, `"format": 3`) per pool, or
per weekday for daily: `masks` (names), `target_p3`, `target_win`, `trap`, `min_careful`,
`min_wary`, `depth` (look-alike chunk size), `type_ratio` (pair types = round(pairs * ratio), at
least 3), `families` (crest families a board draws from), and optional mechanics: `features`,
`turned` and `lucky` (counts), `gold_pair` (a chance 0-1).

## 4. Generating
```
godot --headless --path . -s tools/levelgen/mask_catalogue.gd                         # (v3) the shape catalogue (build/)
godot --headless --path . -s tools/levelgen/picture_masks.gd                          # (v3) picture masks -> halves_masks.json
godot --headless --path . -s tools/levelgen/build_plan.gd                             # (v3) plan, pool recipes, v3_* masks
godot --headless --path . -s tools/levelgen/generate_halves.gd                        # all levels (v3: 300)
godot --headless --path . -s tools/levelgen/generate_halves.gd -- 5                   # just level 5 (preview)
godot --headless --path . -s tools/levelgen/generate_halves.gd -- --pool daily        # a pool
godot --headless --path . -s tools/levelgen/generate_halves.gd -- --curve             # (v3) curve of the baked levels
powershell -File tools/levelgen/generate_parallel.ps1                                 # everything, 4 processes
```
(v3) `generate_parallel.ps1` queues ranges of 10 levels or boards, the last (biggest) first, on 4
processes, and merges them; the result is the same as one process. The generator only bakes the
current `GEN_VERSION` (3): v2's plan semantics and pool recipes are in git history (2792f42), and
its data files stay as they are.
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

## 4b. Generating v3 (`gen_version` 3): 300 levels in 15 places
v3 keeps the v2 pipeline (deal candidates, rate with bots, keep the best) and changes what goes in
and how candidates are judged. v2 files stay readable; the game loads the v3 files once they exist.

**Places.** 15 places of 20 levels (`HalvesChapters.LEVELS_PER_CHAPTER = 20`, `HalvesLevels.COUNT =
300`). Each place brings one crest family and at most one new idea, on a rest level:

| Place | Levels | Family (new) | New idea (tip) |
|---|---|---|---|
| 1 Fuji lake | 1-20 | shapes (plain: no dot or line marks) | pair 1, layers 2, sides 3, decoy 4, trap 6, cut_h 8, diamond 10 |
| 2 Sakura | 21-40 | blossoms | lookalike 21 |
| 3 Bamboo grove | 41-60 | leaves | (bigger boards) |
| 4 Old Kyoto | 61-80 | things | mist 61 |
| 5 Floating gate | 81-100 | waves | picture layouts, 5 layers |
| 6 Nara | 101-120 | wings | lock 101 |
| 7 City lights | 121-140 | lattice | lucky 121 |
| 8 Autumn path | 141-160 | tomoe | frost 141 |
| 9 Golden pavilion | 161-180 | gold + mixed | gold_pair 161, mend 162 |
| 10 Moon night | 181-200 | sky | turned 181 |
| 11-15 | 201-300 | mixed (two or three families a board) | combinations, biggest boards |

**Sawtooth inside a place** (roles by position 1-20): `rest, ramp, ramp, ramp, hard, breather, ramp,
ramp, ramp, hard, rest, ramp, ramp, ramp, hard, breather, ramp, ramp, hard, finale`. Level 1 is
`intro`. A place's new idea arrives on its first `rest` (position 1) and recurs from position 6 on.

**Types (pair keys) per slot**, drafted by `tools/levelgen/build_plan.gd` into the plan (the human
owns the plan afterwards): `pairs = tiles / 2`; `T` distinct pair keys = `round(pairs * r)` with `r`
= 0.5 (intro, rest, breather), 0.55 (ramp), 0.6 (hard), 0.65 (finale), at least 3; the types come
in look-alike groups of `depth` motifs (1 in place 1-2 rest levels, 2 for ramps from place 2, 3 for
hard and finale from place 4), the place's family first (about 60%), then earlier families.
Cuts: vertical, plus horizontal from level 8 on (about a third of the pairs).

**Board sizes** (tiles, by place 1-15, small for rest/breather, large for hard/finale): from
`[12, 32]` in place 1 rising to `[56, 112]` in places 11-15. Masks come from the catalogue (now up to
13 half-units wide, 16 tall, 5 layers, 120 tiles) and from hand-drawn **picture masks** (`pic_*`:
Fuji, torii, pagoda, fan, koi, crane, lantern, wave), which hard and finale levels prefer from place 5.
Faces stay at least 96 px on a 720 × 1600 and a 960 × 1280 screen, and at least 84 px on 720 × 1280
with a 64/32 px notch (old 16:9 phones).

**Mechanics per slot** (feature spec and `gold_pair`): introduced as the table says, then mixed in.
Mist stays rare (at most 2 tiles, only on ramps). From place 9 about one board in four has a gold
pair; lucky tiles appear on about half the boards from place 7 (1-3 tiles); turned tiles from place
10 (2-6 tiles, on look-alike groups).

**The PERCEPTIVE bot** (`HalvesBot.Policy.PERCEPTIVE`): a careful player who sometimes misreads.
It chooses moves as WARY does. Before each move it may slip: let `t` be the move's first tile and `D`
the free tiles in `t`'s look-alike group that are not mates of `t` (twins included). With
probability `p = min(0.9, PERCEPTIVE_BASE * max similarity(pair(t), pair(d)) for d in D *
(1 + PERCEPTIVE_TURNED if t or the chosen decoy is turned))` (`PERCEPTIVE_BASE = 0.25`,
`PERCEPTIVE_TURNED = 0.5`, twins have similarity 1) it taps the most similar decoy first: a mistake
(slip), then makes its move. If stuck it mends (if it has a mend) as section 2 says; otherwise the run
ends uncleared. `rate` adds `perceptive_win` (cleared), `perceptive_slips` (mean slips over all runs)
and `p3` (share of runs that cleared with slips within `HalvesConfig.star_allowance(LEVELS, level,
pairs)`).

**Choosing a candidate (v3).** Rejected as in v2 (`careful_win`, `wary_win` floors, fewer than 2 free
pairs at the start after level 1). The best has the lowest `2 * |p3 - target_p3| + 0.5 *
|random_win - target_win|` (ties: lower k). Role targets:

| Role | target_p3 | random | wary ≥ | trap |
|---|---|---|---|---|
| intro | 1.0 | 1.0 | 1.0 | 0 |
| rest, breather | 0.85 | 0.8 | 0.97 | ≤ 0.1 |
| ramp | 0.75 falling to 0.55 by place 15 | 0.55 falling to 0.35 | 0.9 | 0.15-0.3 |
| hard | 0.45 falling to 0.3 | 0.3 falling to 0.15 | 0.75 | 0.3-0.5 |
| finale | 0.35 falling to 0.2 | 0.15 falling to 0.05 | 0.6 | 0.4-0.6 |

Place 1 is gentler: every target_p3 at least 0.8. **No hard or finale level may keep `wary_win = 1.0`
with `p3 > 0.9`**: such a candidate is rejected when another exists.

**Files.** `data/levels/halves_v3.json` (300 levels, the v2 format plus `"place"` and the new stats),
`halves_daily_v3.json` (400), `halves_zen_v3.json` (150), `halves_rush_v3.json` (150); pool recipes
mix all crest families; seed parts as v2 with `GEN_VERSION = 3`. Report:
`tools/levelgen/reports/halves_v3.csv` (adds place, perceptive_win, perceptive_slips, p3).

**Progress.** Saved stars are per level number, so v3 resets beta progress once (`Progress` save
version bump): stars, unlocks and times start fresh; coins and settings stay; a short "A new
journey" card says so on first launch.

### As built (v3): the details the implementation fixes
- **Roles.** `breather` is a role string of its own in the plan and the level file (targets as rest).
- **Sizes** (`build_plan.gd`). Place `p` spans `lo = 12 + 44 * t`, `hi = 32 + 80 * t` tiles with
  `t = min(p - 1, 10) / 10`; position k (1-20) aims at `lerp(lo, hi, f_k)` with `f` = 0.1, 0.35,
  0.45, 0.55, 0.78, 0.25, 0.42, 0.52, 0.62, 0.84, 0.15, 0.48, 0.58, 0.68, 0.9, 0.3, 0.6, 0.72, 0.94,
  1.0 (a sawtooth that climbs within the place); level 1 is a flat 12-tile board. Layers aimed at:
  place 1: 1 (level 1), 2, 3 for hard and finale and ramps from level 10; then rest 2 (3 from place
  8), breather 2 (3 from place 5), ramp 3 (4 from place 8), hard 3 (4 from place 4, 5 from place 9),
  finale 4 (5 from place 5). A mask scores `3 * |tiles - aim| + 6 * |layers - aim|` plus variety
  penalties (8 per use of the same base shape in the last 20 levels, 20 for the previous level's
  base); pictures get -40 on hard and finale levels from place 5 (+25 elsewhere) and come back at
  most three times, 10 or more levels apart; other shapes come back once, 40 or more levels later
  (+45), since places 11-15 would otherwise run out of 80-110 tile boards. Masks must keep the face
  sizes (720 × 1280 notched ≥ 84 px, 720 × 1280, 960 × 1280 and 720 × 1600 ≥ 96 px, plus 1 px of
  margin), free at least `min(6, max(3, tiles / 5))` tiles at the start, and (catalogue shapes)
  be mirror-symmetric. Place 1 prefers the hand-made `p1_*` masks.
- **Types (tuned).** `r` = 0.5 (intro), 0.7 (rest, breather), and from place 2 to place 15
  (linearly) 0.85 to 0.7 (ramp), 0.75 to 0.68 (hard, finale): the drafted 0.5-0.65 left about two
  copies a type, the PERCEPTIVE bot met a twin on most moves, rest levels fell to p3 0.3-0.6 (under
  the ramps) and mid-place ramps could not reach their targets. Depth: 1 in place 1 (2 for its hard and finale levels
  from level 8, which then show both cuts of a shape) and on every rest and breather level (the
  drafted depth 2 from place 3 broke the sawtooth the same way), 2 for ramps, 2 for hard and finale
  in places 2-3 and 3 from place 4; level 21 (look-alikes) has 2. Families: the place's family takes
  `round(0.6 * T)`, then one or two earlier families (picked at random) split the rest; places 9 and
  11-15 mix 2 (rest, breather), 2-3 (ramp) or 3 (hard, finale) crest families equally. A family
  drafts group by group (shuffled), at most `depth` types per group, distinct motifs first, then
  second cuts; what it cannot fill passes to spare families (other crest families, shapes last),
  and only if all run out are groups drafted deeper (`HalvesGenerator.draft_types`). Place 1 uses
  plain shapes only: circle, triangle and square, diamonds from level 10, `T` capped by what the
  depth allows; level 8 (the cut tip) takes horizontal cuts wherever it can, level 21 vertical only.
  Elsewhere a type is horizontal with chance 1/3 from level 8 when its motif allows it.
- **Targets.** `t = (p - 1) / 14`; ramp `target_p3 = lerp(0.75, 0.55, t)`, `target_win =
  lerp(0.55, 0.35, t)`, minus 0.03 for the second and third ramp of a run and 0.03 in a place's
  second half; hard `lerp(0.45, 0.3, t)` / `lerp(0.3, 0.15, t)` (minus 0.03 in the second half);
  finale `lerp(0.35, 0.2, t)` / `lerp(0.15, 0.05, t)`; rest and breather 0.85 / 0.8; intro 1.0.
  Place 1: target_p3 at least 0.8; levels 2-4 target random 0.9 with no traps, WARY ≥ 1.0; other
  ramps random 0.7, trap 0.1-0.25, WARY ≥ 0.95; hard random 0.5 (level 5) or 0.45, trap 0.2-0.4,
  WARY ≥ 0.85; the finale random 0.3, WARY ≥ 0.75; level 6 (the trap tip) has trap 0.25-0.4 and,
  because it teaches decoys, WARY ≥ 0.95 instead of the breather's 0.97.
  CAREFUL floors are section 6's (rest 0.8, ramp 0.6, hard 0.4, finale 0.3) times
  `clamp((96 - tiles) / 48, 0, 1)`: CAREFUL's greedy is no human model on tall stacks (it clears
  none of the 110-tile pyramids WARY always clears), so WARY's floor and p3 judge big boards alone.
- **Mechanics** (seeded per level): each idea's own level has it alone (mist 2, a lock of 1 key
  pair and 2 locked, lucky 2, frost 2, the gold pair on 161 and 162, turned 2). Then, with the chance
  "in its place from position 6 / in later places": mist on ramps only, 1-2 tiles (0.5 / 0.12);
  locks off rest levels, 1 key pair (2 on finales), 2-4 locked (0.6 / 0.25); frost off rest levels,
  2-5 tiles (0.6 / 0.25); lucky 1-3 tiles, 1-2 on rest levels (0.55 / 0.45); the gold pair
  (0.35 / 0.25); turned on boards with depth ≥ 2, 2-6 tiles (0.65 / 0.35). Rest levels and breathers
  keep at most one mechanic; positions 2-5 never use their place's new idea.
- **PERCEPTIVE.** `t` is the chosen pair's lower tile id; the move is chosen first (WARY's rng
  draw), then the slip is drawn (`rng.randf() < p`) only when `D` is not empty; the most similar
  decoy is the lowest id among the most similar. A mend is never preceded by a slip.
- **Choosing.** Candidates are screened with 12 runs a policy and sorted with trivial hard/finale
  ones last; the first 6 are rated with 50 runs, and up to 12 more while the best still fails a
  floor or is trivial. The winner passes the floors, then is not trivial, then has the lowest score.
- **Pools.** Daily, Monday to Sunday: 28-40 up to 70-100 tiles, target_p3 0.85 to 0.28, random 0.8
  to 0.12, depth 1-3, `type_ratio` 0.7-0.75, 2 crest families (3 from Friday), mechanics growing
  from 1 lucky tile to locks, frost and turned tiles. Zen: 36-64 tiles, p3 0.85, depth 1, 1 lucky
  tile. Rush: 12-24 tiles, p3 0.9, random 0.95, no traps or mechanics.
- **Report** columns: level, place, role, mask, tiles, layers, types, depth, candidate, trap_rate,
  traps, random_win, careful_win, wary_win, perceptive_win, perceptive_slips, p3, decoy_exposure,
  avg_free_pairs, start_free_pairs, difficulty, par_s, locks, frost, mist, gold, gold_pair, turned,
  lucky, tip. The bake ends with the curve summary (`generate_halves.gd -- --curve` prints it again).
- **Progress reset.** `SaveStore.CURRENT_VERSION` = 3; the v2 → v3 step empties `levels` and drops
  the `level_*` entries of `best`, `medals` and the top level (the best-run log file) and sets
  `journey_reset` when the save had stars. `Progress.journey_reset_pending()` reads it and
  `Progress.clear_journey_reset()` clears it once the card was shown.

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
- (v3) **Look-alikes and copies** are the PERCEPTIVE dials: every twin or look-alike free next to
  the tile a player wants is a chance to slip, so fewer copies a type (`r`) and shallower groups
  (`depth`) raise p3; deeper groups, turned tiles and bigger boards lower it. The plan's targets
  pick among candidates; when a whole slot misses its target, change `r`, `depth` or the board size
  in `build_plan.gd` (section 4b, As built), not the bot.
- (v3) **Sawtooth in places of 20:** rest (1, 11), three ramps, hard (5), breather (6), three ramps,
  hard (10), rest, three ramps, hard (15), breather (16), two ramps, hard (19), finale (20).
  `generate_halves.gd -- --curve` prints p3 by role per place.
- (v2) **Sawtooth in packs of 10:** a rest level brings each new idea (x1 or x6), x5 is hard and x0 is a
  finale. Core rules are all taught by level 10: layers (2), side blocking (3), decoys (4), the
  first trap (5), horizontal cuts (6), diamonds (7), dot marks (8), line marks (9); gold tiles arrive at 11. New
  features open the later difficulty bands (20 levels each in the generator): mist (21), locks (41), frost (61); band 5 (81-100) mixes all.
- **Role targets** (v2; v3's are in section 4b; v3's CAREFUL floors are these, faded on big boards)
  (random / min WARY / min CAREFUL / trap rate):

  | Role | random | wary ≥ | careful ≥ | trap |
  |---|---|---|---|---|
  | intro | 1.0 | 1.0 | 1.0 | 0 |
  | rest | 0.75–0.9 | 0.97 | 0.8 | ≤ 0.1 |
  | ramp | 0.6 falling to 0.4 by band 5 | 0.9 | 0.6 | 0.15–0.3 |
  | hard | 0.15–0.3 | 0.75 | 0.4 | 0.3–0.5 |
  | finale | 0.05–0.15 | 0.6 | 0.3 | 0.4–0.6 |

- Booster prices, free uses, coins and par constants: `HalvesConfig`.
