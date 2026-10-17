class_name HalvesFace
extends RefCounted
## A tile face is an int: shape << 4 | cut << 3 | mark << 1 | side. Two faces match when they are
## the same shape, cut and mark on opposite sides. Used by all Halves logic, the view and the data.
## A "decoy" is the same shape but not the mate (twins included): tapping one is a mistake.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }
enum Cut { VERTICAL, HORIZONTAL }
enum Mark { NONE, DOT, LINE }

const SIDE_A: int = 0
const SIDE_B: int = 1

const SHAPE_NAMES: PackedStringArray = ["circle", "tri", "square", "diamond"]
const CUT_NAMES: PackedStringArray = ["v", "h"]
const MARK_NAMES: PackedStringArray = ["-", "dot", "line"]
const SIDE_NAMES: PackedStringArray = ["a", "b"]


static func make(shape_id: int, cut_id: int, mark_id: int, side_id: int) -> int:
	return shape_id << 4 | cut_id << 3 | mark_id << 1 | side_id


static func shape(face: int) -> int:
	return face >> 4


static func cut(face: int) -> int:
	return (face >> 3) & 1


static func mark(face: int) -> int:
	return (face >> 1) & 3


static func side(face: int) -> int:
	return face & 1


static func pair_key(face: int) -> int:
	return face >> 1


static func mate(face: int) -> int:
	return face ^ 1


static func is_valid(face: int) -> bool:
	if face < 0 or shape(face) >= SHAPE_NAMES.size() or mark(face) >= MARK_NAMES.size():
		return false
	return not (shape(face) == Shape.TRIANGLE and cut(face) == Cut.HORIZONTAL)


static func matches(a: int, b: int) -> bool:
	return pair_key(a) == pair_key(b) and side(a) != side(b)


static func is_decoy(a: int, b: int) -> bool:
	return shape(a) == shape(b) and not matches(a, b)


static func to_text(face: int) -> String:
	if not is_valid(face):
		return "?"
	return "%s:%s" % [pair_to_text(pair_key(face)), SIDE_NAMES[side(face)]]


static func from_text(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 4:
		return -1
	var key := pair_from_text(":".join(parts.slice(0, 3)))
	var side_id := SIDE_NAMES.find(parts[3])
	if key < 0 or side_id < 0:
		return -1
	return key << 1 | side_id


static func pair_to_text(key: int) -> String:
	var face := key << 1
	if not is_valid(face):
		return "?"
	return "%s:%s:%s" % [SHAPE_NAMES[shape(face)], CUT_NAMES[cut(face)], MARK_NAMES[mark(face)]]


static func pair_from_text(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 3:
		return -1
	var shape_id := SHAPE_NAMES.find(parts[0])
	var cut_id := CUT_NAMES.find(parts[1])
	var mark_id := MARK_NAMES.find(parts[2])
	if shape_id < 0 or cut_id < 0 or mark_id < 0:
		return -1
	var face := make(shape_id, cut_id, mark_id, SIDE_A)
	return pair_key(face) if is_valid(face) else -1
