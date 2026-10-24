class_name HalvesState
extends RefCounted
## One Halves board in play: which tiles remain, their faces, mistakes and the undo history.
## The board view drives it with try_pair() and try_mend(); the solver, bot, shuffle and run replay
## read it. Slips (mistakes and stuck shuffles) only cost stars; mist, gold and lucky tiles come from
## geometry features. Tile sets (remaining, veiled, gold, lucky) are HalvesBits sets, replaced on
## change, never edited in place. (v3) A gold pair earns a mend; lucky tiles have clocks counted in pairs.

enum Result { MATCH, MISMATCH, SWITCH, BLOCKED, INVALID }

var geometry: HalvesGeometry
var faces: PackedInt32Array
var remaining: PackedInt64Array = HalvesBits.empty()
var mistakes: int = 0
## Mismatches that cost nothing (the tutorial forgives the first one).
var free_mistakes: int = 0
## When true, every non-matching pair is a mistake, not only decoys.
var strict: bool = false
## Shuffles applied while the board was stuck (each one is a slip).
var stuck_shuffles: int = 0
## Mist tiles whose face is still hidden; the gold tiles; gold tiles cleared so far.
var veiled: PackedInt64Array = HalvesBits.empty()
var gold: PackedInt64Array = HalvesBits.empty()
var gold_earned: int = 0
## (v3) Mends earned (by clearing the gold pair) and not used yet.
var mends: int = 0
## (v3) Pairs and mends made so far (undo takes them back): what lucky clocks count.
var pairs_done: int = 0
## (v3) The lucky tiles; lucky tile -> pairs_done when it was first free; lucky tiles removed in time.
var lucky: PackedInt64Array = HalvesBits.empty()
var lucky_start: Dictionary[int, int] = {}
var lucky_won: int = 0
## {"kind": "pair", "a": int, "b": int}, {"kind": "mend", "a": int, "b": int} or {"kind": "mistake"},
## oldest first.
var history: Array[Dictionary] = []

## One entry per history entry: the lucky tiles it won and the clocks it started, for undo().
var _lucky_log: Array[Dictionary] = []


func _init(board: HalvesGeometry, board_faces: PackedInt32Array) -> void:
	geometry = board
	faces = board_faces.duplicate()
	remaining = board.full_mask()
	if board.has_features():
		veiled = HalvesFeatures.mask(board.features.get("mist", []))
		gold = HalvesFeatures.mask(board.features.get("gold", []))
		lucky = HalvesFeatures.mask(board.features.get("lucky", []))
	_reveal()
	_start_clocks()


func try_pair(a: int, b: int) -> Result:
	var count := geometry.size()
	if a == b or a < 0 or b < 0 or a >= count or b >= count:
		return Result.INVALID
	if not HalvesBits.has(remaining, a) or not HalvesBits.has(remaining, b):
		return Result.INVALID
	if not geometry.is_free(a, remaining) or not geometry.is_free(b, remaining):
		return Result.BLOCKED
	if HalvesFace.matches(faces[a], faces[b]):
		history.append({"kind": "pair", "a": a, "b": b})
		_remove(a, b)
		return Result.MATCH
	if strict or HalvesFace.is_decoy(faces[a], faces[b]):
		if free_mistakes > 0:
			free_mistakes -= 1
		else:
			mistakes += 1
			history.append({"kind": "mistake"})
			_lucky_log.append({})
		return Result.MISMATCH
	return Result.SWITCH


## (v3) Spends a mend on free tile `a`: it and the lowest-id remaining tile with its mate face
## (wherever that lies) leave the board as a pair. INVALID without a mend, a remaining `a` or a
## remaining mate; BLOCKED if `a` is not free. Not a slip.
func try_mend(a: int) -> Result:
	if mends <= 0 or a < 0 or a >= geometry.size() or not HalvesBits.has(remaining, a):
		return Result.INVALID
	var b := mend_mate(geometry, faces, remaining, a)
	if b < 0:
		return Result.INVALID
	if not geometry.is_free(a, remaining):
		return Result.BLOCKED
	mends -= 1
	history.append({"kind": "mend", "a": a, "b": b})
	_remove(a, b)
	return Result.MATCH


## (v3) The mate a mend takes for tile `a` (docs/HALVES.md section 1, Mend): with twins, the wrong
## one can strand a half on its only mate, so take the lowest-id mate whose removal with `a` leaves
## the board solvable (solver, HalvesConfig.MEND_BUDGET nodes each); else the lowest-id mate not
## proven unsolvable; else the lowest-id mate. -1 when `a` has no remaining mate.
static func mend_mate(board: HalvesGeometry, board_faces: PackedInt32Array, left: PackedInt64Array, a: int) -> int:
	var want := HalvesFace.mate(board_faces[a])
	var mates: Array[int] = []
	for tile in HalvesBits.ids(left):
		if board_faces[tile] == want:
			mates.append(tile)
	if mates.size() <= 1:
		return mates[0] if mates.size() == 1 else -1
	var undecided := -1
	for b in mates:
		var rest := HalvesBits.removed(HalvesBits.removed(left, a), b)
		var status: int = HalvesSolver.solve(board, board_faces, rest, HalvesConfig.MEND_BUDGET).status
		if status == HalvesSolver.Status.SOLVED:
			return b
		if status == HalvesSolver.Status.UNKNOWN and undecided < 0:
			undecided = b
	return undecided if undecided >= 0 else mates[0]


## (v3) True for the gold pair's faces (the gold crest family).
static func is_gold(face: int) -> bool:
	return HalvesFace.family(face) == &"gold"


func undo() -> bool:
	if history.is_empty():
		return false
	var last: Dictionary = history.pop_back()
	var logged: Dictionary = _lucky_log.pop_back() if not _lucky_log.is_empty() else {}
	if last.kind == "mistake":
		mistakes -= 1
	else:
		var a := int(last.a)
		var b := int(last.b)
		remaining = HalvesBits.added(HalvesBits.added(remaining, a), b)
		pairs_done -= 1
		gold_earned -= _gold_in(a, b)
		mends -= _mends_earned(a, b)
		if last.kind == "mend":
			mends += 1
		lucky_won -= int(logged.get("won", 0))
		for tile: int in logged.get("clocks", PackedInt32Array()):
			lucky_start.erase(tile)
		_reveal()
	_start_clocks()
	return true


## The last action undo() would take back, or {} when there is none.
func last_action() -> Dictionary:
	return {} if history.is_empty() else history.back()


func free_pairs() -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	var free := geometry.free_tiles(remaining)
	for i in free.size():
		for j in range(i + 1, free.size()):
			if HalvesFace.matches(faces[free[i]], faces[free[j]]):
				pairs.append(Vector2i(free[i], free[j]))
	return pairs


func is_cleared() -> bool:
	return HalvesBits.is_empty(remaining)


func is_stuck() -> bool:
	return not HalvesBits.is_empty(remaining) and free_pairs().is_empty()


func tiles_left() -> int:
	return HalvesBits.count(remaining)


## Mistakes plus shuffles out of a dead end: what the stars count.
func slips() -> int:
	return mistakes + stuck_shuffles


## Stars for this board's slips with `allowance` free slips (-1: unlimited; v3, section 1).
func stars(allowance: int = 0) -> int:
	if allowance < 0 or slips() <= allowance:
		return 3
	return 2 if slips() <= allowance + HalvesConfig.STAR2_EXTRA_SLIPS else 1


## Takes a shuffled board (HalvesFill.shuffle); the old undo history no longer applies.
## `stuck`: the board was stuck when the shuffle was asked for, which is a slip.
## Mends, pairs_done and the lucky clocks and wins are kept (lucky is positional).
func apply_deal(new_remaining: PackedInt64Array, new_faces: PackedInt32Array, stuck: bool = false) -> void:
	remaining = new_remaining.duplicate()
	faces = new_faces.duplicate()
	history.clear()
	_lucky_log.clear()
	if stuck:
		stuck_shuffles += 1
	_reveal()
	_start_clocks()


## Takes tiles a and b off as a pair (a match or a mend): counts it, earns a mend for the gold pair,
## pays lucky tiles still in time, and logs what undo() has to take back.
func _remove(a: int, b: int) -> void:
	var won := _wins(a) + _wins(b)
	remaining = HalvesBits.removed(HalvesBits.removed(remaining, a), b)
	pairs_done += 1
	gold_earned += _gold_in(a, b)
	mends += _mends_earned(a, b)
	lucky_won += won
	_reveal()
	_lucky_log.append({"won": won, "clocks": _start_clocks()})


## Mist faces show once their tile is free, and stay shown.
func _reveal() -> void:
	if not HalvesBits.is_empty(veiled):
		veiled = HalvesBits.minus(veiled, geometry.free_mask(remaining))


## Starts the clock of every lucky tile that is remaining, free and has none; returns those tiles.
func _start_clocks() -> PackedInt32Array:
	var started := PackedInt32Array()
	if HalvesBits.is_empty(lucky):
		return started
	for tile in HalvesBits.ids(HalvesBits.intersection(lucky, geometry.free_mask(remaining))):
		if not lucky_start.has(tile):
			lucky_start[tile] = pairs_done
			started.append(tile)
	return started


## 1 if removing `tile` now wins its lucky coins (a lucky tile whose clock has not run out).
func _wins(tile: int) -> int:
	if not lucky_start.has(tile) or not HalvesBits.has(lucky, tile):
		return 0
	return 1 if pairs_done - lucky_start[tile] < HalvesConfig.LUCKY_SNAPS else 0


## 1 if a and b are the gold pair (clearing it earns a mend).
func _mends_earned(a: int, b: int) -> int:
	return 1 if is_gold(faces[a]) and is_gold(faces[b]) else 0


## The lowest-id remaining tile whose face is the mate of tile a's face, -1 if none.
## How many of tiles a and b are gold.
func _gold_in(a: int, b: int) -> int:
	return (1 if HalvesBits.has(gold, a) else 0) + (1 if HalvesBits.has(gold, b) else 0)
