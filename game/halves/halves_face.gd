class_name HalvesFace
extends RefCounted
## A tile face is an int: pair << 1 | side. Pairs 0-31 are the v2 shapes (shape << 3 | cut << 2 |
## mark, so v2 data is unchanged); pairs from 32 are crests from HalvesCrests. Used by all Halves
## logic, the view and the data. A "decoy" is the same look-alike group but not the mate.

enum Shape { CIRCLE, TRIANGLE, SQUARE, DIAMOND }
enum Cut { VERTICAL, HORIZONTAL }
enum Mark { NONE, DOT, LINE }

const SIDE_A: int = 0
const SIDE_B: int = 1

const SHAPE_NAMES: PackedStringArray = ["circle", "tri", "square", "diamond"]
const CUT_NAMES: PackedStringArray = ["v", "h"]
const MARK_NAMES: PackedStringArray = ["-", "dot", "line"]
const SIDE_NAMES: PackedStringArray = ["a", "b"]
## The shapes' look-alike groups, by Shape.
const SHAPE_GROUPS: Array[StringName] = [&"circle", &"tri", &"square", &"diamond"]


## A v2 shape face.
static func make(shape_id: int, cut_id: int, mark_id: int, side_id: int) -> int:
	return shape_id << 4 | cut_id << 3 | mark_id << 1 | side_id


## A crest face (motif index into HalvesCrests.MOTIFS).
static func make_crest(motif: int, cut_id: int, side_id: int) -> int:
	return HalvesCrests.pair_of(motif, cut_id) << 1 | side_id


static func is_crest(face: int) -> bool:
	return pair_key(face) >= HalvesCrests.FIRST_PAIR


## The v2 shape, or -1 for a crest.
static func shape(face: int) -> int:
	return -1 if is_crest(face) else face >> 4


static func cut(face: int) -> int:
	return (face >> 1) & 1 if is_crest(face) else (face >> 3) & 1


## The v2 mark, or -1 for a crest.
static func mark(face: int) -> int:
	return -1 if is_crest(face) else (face >> 1) & 3


static func side(face: int) -> int:
	return face & 1


static func pair_key(face: int) -> int:
	return face >> 1


static func mate(face: int) -> int:
	return face ^ 1


static func family(face: int) -> StringName:
	return HalvesCrests.family_of(pair_key(face))


static func group(face: int) -> StringName:
	return HalvesCrests.group_of(pair_key(face))


static func is_valid(face: int) -> bool:
	if face < 0:
		return false
	if is_crest(face):
		return HalvesCrests.is_valid_pair(pair_key(face))
	if shape(face) >= SHAPE_NAMES.size() or mark(face) >= MARK_NAMES.size():
		return false
	return not (shape(face) == Shape.TRIANGLE and cut(face) == Cut.HORIZONTAL)


static func matches(a: int, b: int) -> bool:
	return pair_key(a) == pair_key(b) and side(a) != side(b)


static func is_decoy(a: int, b: int) -> bool:
	return group(a) != &"" and group(a) == group(b) and not matches(a, b)


static func to_text(face: int) -> String:
	if not is_valid(face):
		return "?"
	return "%s:%s" % [pair_to_text(pair_key(face)), SIDE_NAMES[side(face)]]


static func from_text(text: String) -> int:
	var cut_at := text.rfind(":")
	if cut_at < 0:
		return -1
	var key := pair_from_text(text.substr(0, cut_at))
	var side_id := SIDE_NAMES.find(text.substr(cut_at + 1))
	if key < 0 or side_id < 0:
		return -1
	return key << 1 | side_id


static func pair_to_text(key: int) -> String:
	var face := key << 1
	if not is_valid(face):
		return "?"
	if is_crest(face):
		return "%s:%s" % [HalvesCrests.MOTIFS[HalvesCrests.motif_of(key)].id, CUT_NAMES[cut(face)]]
	return "%s:%s:%s" % [SHAPE_NAMES[shape(face)], CUT_NAMES[cut(face)], MARK_NAMES[mark(face)]]


static func pair_from_text(text: String) -> int:
	var parts := text.split(":")
	if parts.size() == 2:
		var motif := HalvesCrests.motif_index(StringName(parts[0]))
		var crest_cut := CUT_NAMES.find(parts[1])
		if motif < 0 or crest_cut < 0:
			return -1
		var pair := HalvesCrests.pair_of(motif, crest_cut)
		return pair if HalvesCrests.is_valid_pair(pair) else -1
	if parts.size() != 3:
		return -1
	var shape_id := SHAPE_NAMES.find(parts[0])
	var cut_id := CUT_NAMES.find(parts[1])
	var mark_id := MARK_NAMES.find(parts[2])
	if shape_id < 0 or cut_id < 0 or mark_id < 0:
		return -1
	var face := make(shape_id, cut_id, mark_id, SIDE_A)
	return pair_key(face) if is_valid(face) else -1
