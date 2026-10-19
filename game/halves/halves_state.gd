class_name HalvesState
extends RefCounted
## One Halves board in play: which tiles remain, their faces, mistakes and the undo history.
## The board view drives it with try_pair(); the solver, bot, shuffle and run replay read it.
## Slips (mistakes and stuck shuffles) only cost stars; mist and gold come from geometry features.

enum Result { MATCH, MISMATCH, SWITCH, BLOCKED, INVALID }

var geometry: HalvesGeometry
var faces: PackedInt32Array
var remaining: int = 0
var mistakes: int = 0
## Mismatches that cost nothing (the tutorial forgives the first one).
var free_mistakes: int = 0
## When true, every non-matching pair is a mistake, not only decoys.
var strict: bool = false
## Shuffles applied while the board was stuck (each one is a slip).
var stuck_shuffles: int = 0
## Mist tiles whose face is still hidden; the gold tiles; gold tiles cleared so far.
var veiled: int = 0
var gold: int = 0
var gold_earned: int = 0
## {"kind": "pair", "a": int, "b": int} or {"kind": "mistake"}, oldest first.
var history: Array[Dictionary] = []


func _init(board: HalvesGeometry, board_faces: PackedInt32Array) -> void:
	geometry = board
	faces = board_faces.duplicate()
	remaining = board.full_mask()
	if board.has_features():
		veiled = HalvesFeatures.mask(board.features.get("mist", []))
		gold = HalvesFeatures.mask(board.features.get("gold", []))
	_reveal()


func try_pair(a: int, b: int) -> Result:
	var count := geometry.size()
	if a == b or a < 0 or b < 0 or a >= count or b >= count:
		return Result.INVALID
	if remaining & (1 << a) == 0 or remaining & (1 << b) == 0:
		return Result.INVALID
	if not geometry.is_free(a, remaining) or not geometry.is_free(b, remaining):
		return Result.BLOCKED
	if HalvesFace.matches(faces[a], faces[b]):
		remaining &= ~(1 << a) & ~(1 << b)
		history.append({"kind": "pair", "a": a, "b": b})
		gold_earned += HalvesGeometry.popcount(gold & ((1 << a) | (1 << b)))
		_reveal()
		return Result.MATCH
	if strict or HalvesFace.is_decoy(faces[a], faces[b]):
		if free_mistakes > 0:
			free_mistakes -= 1
		else:
			mistakes += 1
			history.append({"kind": "mistake"})
		return Result.MISMATCH
	return Result.SWITCH


func undo() -> bool:
	if history.is_empty():
		return false
	var last: Dictionary = history.pop_back()
	if last.kind == "pair":
		remaining |= 1 << int(last.a) | 1 << int(last.b)
		gold_earned -= HalvesGeometry.popcount(gold & ((1 << int(last.a)) | (1 << int(last.b))))
		_reveal()
	else:
		mistakes -= 1
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
	return remaining == 0


func is_stuck() -> bool:
	return remaining != 0 and free_pairs().is_empty()


func tiles_left() -> int:
	return HalvesGeometry.popcount(remaining)


## Mistakes plus shuffles out of a dead end: what the stars count.
func slips() -> int:
	return mistakes + stuck_shuffles


func stars() -> int:
	if slips() == 0:
		return 3
	return 2 if slips() <= HalvesConfig.STAR2_MAX_MISTAKES else 1


## Takes a shuffled board (HalvesFill.shuffle); the old undo history no longer applies.
## `stuck`: the board was stuck when the shuffle was asked for, which is a slip.
func apply_deal(new_remaining: int, new_faces: PackedInt32Array, stuck: bool = false) -> void:
	remaining = new_remaining
	faces = new_faces.duplicate()
	history.clear()
	if stuck:
		stuck_shuffles += 1
	_reveal()


## Mist faces show once their tile is free, and stay shown.
func _reveal() -> void:
	if veiled != 0:
		veiled &= ~geometry.free_mask(remaining)
