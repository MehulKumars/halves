class_name HalvesCrests
extends RefCounted
## The crest catalogue: families, motifs and their look-alike groups (docs/HALVES.md, v3). A crest
## pair is FIRST_PAIR + motif * 2 + cut; pairs below FIRST_PAIR are the v2 shapes. Used by
## HalvesFace, HalvesCrest (drawing), the generator and the bots. Only append motifs: never reorder.

const FIRST_PAIR: int = 32

## Crest Book order. The ink colour of each family is in HalvesPalette.
const FAMILIES: Array[Dictionary] = [
	{"id": &"blossoms", "name": "Blossoms"},
	{"id": &"tomoe", "name": "Tomoe"},
	{"id": &"sky", "name": "Moon and stars"},
	{"id": &"waves", "name": "Waves"},
	{"id": &"lattice", "name": "Lattice"},
	{"id": &"leaves", "name": "Leaves"},
	{"id": &"things", "name": "Things"},
	{"id": &"wings", "name": "Wings"},
]

## spec: what HalvesCrest draws. Top-level entries are also what similarity() compares, so a
## look-alike differs from its neighbours in one or two entries.
const MOTIFS: Array[Dictionary] = [
	# Blossoms: five petals (notched, round, pointed), the same in a ring, and many petals.
	{"id": &"sakura", "name": "Cherry blossom", "family": &"blossoms", "group": &"blossom5", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"notched", "center": &"hole", "ring": false}},
	{"id": &"ume", "name": "Plum blossom", "family": &"blossoms", "group": &"blossom5", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"round", "center": &"hole", "ring": false}},
	{"id": &"kikyo", "name": "Bellflower", "family": &"blossoms", "group": &"blossom5", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"pointed", "center": &"dot", "ring": false}},
	{"id": &"sakura_maru", "name": "Cherry blossom in a ring", "family": &"blossoms", "group": &"blossom_ring", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"notched", "center": &"hole", "ring": true}},
	{"id": &"ume_maru", "name": "Plum blossom in a ring", "family": &"blossoms", "group": &"blossom_ring", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"round", "center": &"hole", "ring": true}},
	{"id": &"kikyo_maru", "name": "Bellflower in a ring", "family": &"blossoms", "group": &"blossom_ring", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 5, "petal": &"pointed", "center": &"dot", "ring": true}},
	{"id": &"mutsu_ume", "name": "Six-petal plum", "family": &"blossoms", "group": &"blossom_many", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 6, "petal": &"round", "center": &"hole", "ring": false}},
	{"id": &"mutsu_sakura", "name": "Six-petal cherry", "family": &"blossoms", "group": &"blossom_many", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 6, "petal": &"notched", "center": &"hole", "ring": false}},
	{"id": &"yae", "name": "Eight-petal flower", "family": &"blossoms", "group": &"blossom_many", "cuts": [0, 1],
		"spec": {"kind": &"flower", "petals": 8, "petal": &"pointed", "center": &"dot", "ring": false}},
	# Tomoe: commas swirling around the centre.
	{"id": &"hitotsu_tomoe", "name": "One tomoe", "family": &"tomoe", "group": &"tomoe_few", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 1, "turn": &"left", "ring": false}},
	{"id": &"futatsu_tomoe", "name": "Two tomoe", "family": &"tomoe", "group": &"tomoe_few", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 2, "turn": &"left", "ring": false}},
	{"id": &"futatsu_tomoe_maru", "name": "Two tomoe in a ring", "family": &"tomoe", "group": &"tomoe_few", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 2, "turn": &"left", "ring": true}},
	{"id": &"mitsu_tomoe", "name": "Three tomoe", "family": &"tomoe", "group": &"tomoe3", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 3, "turn": &"left", "ring": false}},
	{"id": &"mitsu_tomoe_r", "name": "Three tomoe, turning right", "family": &"tomoe", "group": &"tomoe3", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 3, "turn": &"right", "ring": false}},
	{"id": &"mitsu_tomoe_maru", "name": "Three tomoe in a ring", "family": &"tomoe", "group": &"tomoe3", "cuts": [0, 1],
		"spec": {"kind": &"tomoe", "count": 3, "turn": &"left", "ring": true}},
	# Moon and stars.
	{"id": &"mikazuki", "name": "Crescent moon", "family": &"sky", "group": &"moon", "cuts": [0, 1],
		"spec": {"kind": &"moon", "phase": &"thin", "star": false, "ring": false}},
	{"id": &"hangetsu", "name": "Half moon", "family": &"sky", "group": &"moon", "cuts": [0, 1],
		"spec": {"kind": &"moon", "phase": &"thick", "star": false, "ring": false}},
	{"id": &"tsuki_hoshi", "name": "Moon and star", "family": &"sky", "group": &"moon", "cuts": [0, 1],
		"spec": {"kind": &"moon", "phase": &"thin", "star": true, "ring": false}},
	{"id": &"mangetsu", "name": "Full moon", "family": &"sky", "group": &"moon", "cuts": [0, 1],
		"spec": {"kind": &"moon", "phase": &"full", "star": false, "ring": true}},
	{"id": &"hoshi5", "name": "Five-point star", "family": &"sky", "group": &"star", "cuts": [0, 1],
		"spec": {"kind": &"star", "points": 5, "ring": false}},
	{"id": &"hoshi6", "name": "Six-point star", "family": &"sky", "group": &"star", "cuts": [0, 1],
		"spec": {"kind": &"star", "points": 6, "ring": false}},
	{"id": &"hoshi8", "name": "Eight-point star", "family": &"sky", "group": &"star", "cuts": [0, 1],
		"spec": {"kind": &"star", "points": 8, "ring": false}},
	{"id": &"hoshi5_maru", "name": "Star in a ring", "family": &"sky", "group": &"star", "cuts": [0, 1],
		"spec": {"kind": &"star", "points": 5, "ring": true}},
	# Waves: ripples and whirlpools.
	{"id": &"hamon2", "name": "Two ripples", "family": &"waves", "group": &"ripple", "cuts": [0, 1],
		"spec": {"kind": &"ripple", "rings": 2, "dot": true}},
	{"id": &"hamon3", "name": "Three ripples", "family": &"waves", "group": &"ripple", "cuts": [0, 1],
		"spec": {"kind": &"ripple", "rings": 3, "dot": false}},
	{"id": &"hamon3_dot", "name": "Ripples round a drop", "family": &"waves", "group": &"ripple", "cuts": [0, 1],
		"spec": {"kind": &"ripple", "rings": 3, "dot": true}},
	{"id": &"uzu", "name": "Whirlpool", "family": &"waves", "group": &"whirl", "cuts": [0, 1],
		"spec": {"kind": &"whirl", "turn": &"left", "arms": 1}},
	{"id": &"uzu_r", "name": "Whirlpool, turning right", "family": &"waves", "group": &"whirl", "cuts": [0, 1],
		"spec": {"kind": &"whirl", "turn": &"right", "arms": 1}},
	{"id": &"uzu2", "name": "Double whirlpool", "family": &"waves", "group": &"whirl", "cuts": [0, 1],
		"spec": {"kind": &"whirl", "turn": &"left", "arms": 2}},
	# Lattice: diamonds, tortoise-shell hexagons and well frames.
	{"id": &"hishi", "name": "Diamond", "family": &"lattice", "group": &"lozenge", "cuts": [0, 1],
		"spec": {"kind": &"diamond", "count": 1, "ring": false}},
	{"id": &"yotsu_bishi", "name": "Four diamonds", "family": &"lattice", "group": &"lozenge", "cuts": [0, 1],
		"spec": {"kind": &"diamond", "count": 4, "ring": false}},
	{"id": &"hishi_maru", "name": "Diamond in a ring", "family": &"lattice", "group": &"lozenge", "cuts": [0, 1],
		"spec": {"kind": &"diamond", "count": 1, "ring": true}},
	{"id": &"kikko", "name": "Tortoise shell", "family": &"lattice", "group": &"hex", "cuts": [0, 1],
		"spec": {"kind": &"hexagon", "inner": &"none", "ring": false}},
	{"id": &"kikko_dot", "name": "Tortoise shell with a drop", "family": &"lattice", "group": &"hex", "cuts": [0, 1],
		"spec": {"kind": &"hexagon", "inner": &"dot", "ring": false}},
	{"id": &"kikko_hishi", "name": "Tortoise shell with a diamond", "family": &"lattice", "group": &"hex", "cuts": [0, 1],
		"spec": {"kind": &"hexagon", "inner": &"diamond", "ring": false}},
	{"id": &"igeta", "name": "Well frame", "family": &"lattice", "group": &"frame", "cuts": [0, 1],
		"spec": {"kind": &"frame", "ring": false}},
	{"id": &"igeta_maru", "name": "Well frame in a ring", "family": &"lattice", "group": &"frame", "cuts": [0, 1],
		"spec": {"kind": &"frame", "ring": true}},
	# Leaves: ginkgo fans, bamboo blades, and lobed leaves.
	{"id": &"icho", "name": "Ginkgo leaf", "family": &"leaves", "group": &"ginkgo", "cuts": [0, 1],
		"spec": {"kind": &"ginkgo", "count": 1, "ring": false}},
	{"id": &"futatsu_icho", "name": "Two ginkgo leaves", "family": &"leaves", "group": &"ginkgo", "cuts": [0, 1],
		"spec": {"kind": &"ginkgo", "count": 2, "ring": false}},
	{"id": &"icho_maru", "name": "Ginkgo leaf in a ring", "family": &"leaves", "group": &"ginkgo", "cuts": [0, 1],
		"spec": {"kind": &"ginkgo", "count": 1, "ring": true}},
	{"id": &"sasa", "name": "Bamboo leaves", "family": &"leaves", "group": &"sasa", "cuts": [0, 1],
		"spec": {"kind": &"sasa", "leaves": 3, "ring": false}},
	{"id": &"sasa5", "name": "Five bamboo leaves", "family": &"leaves", "group": &"sasa", "cuts": [0, 1],
		"spec": {"kind": &"sasa", "leaves": 5, "ring": false}},
	{"id": &"sasa_maru", "name": "Bamboo leaves in a ring", "family": &"leaves", "group": &"sasa", "cuts": [0, 1],
		"spec": {"kind": &"sasa", "leaves": 3, "ring": true}},
	{"id": &"kaede", "name": "Maple leaf", "family": &"leaves", "group": &"lobed", "cuts": [0, 1],
		"spec": {"kind": &"maple", "ring": false}},
	{"id": &"katabami", "name": "Wood sorrel", "family": &"leaves", "group": &"lobed", "cuts": [0, 1],
		"spec": {"kind": &"katabami", "ring": false}},
	{"id": &"kashiwa", "name": "Oak leaves", "family": &"leaves", "group": &"lobed", "cuts": [0, 1],
		"spec": {"kind": &"kashiwa", "ring": false}},
	# Things: fans, round things and tall things.
	{"id": &"ogi", "name": "Folding fan", "family": &"things", "group": &"fan", "cuts": [0, 1],
		"spec": {"kind": &"fan", "ring": false}},
	{"id": &"ogi_maru", "name": "Folding fan in a ring", "family": &"things", "group": &"fan", "cuts": [0, 1],
		"spec": {"kind": &"fan", "ring": true}},
	{"id": &"kasa", "name": "Umbrella", "family": &"things", "group": &"round_thing", "cuts": [0, 1],
		"spec": {"kind": &"umbrella", "ring": false}},
	{"id": &"suzu", "name": "Bell", "family": &"things", "group": &"round_thing", "cuts": [0, 1],
		"spec": {"kind": &"bell", "ring": false}},
	{"id": &"kasa_maru", "name": "Umbrella in a ring", "family": &"things", "group": &"round_thing", "cuts": [0, 1],
		"spec": {"kind": &"umbrella", "ring": true}},
	{"id": &"chochin", "name": "Lantern", "family": &"things", "group": &"tall_thing", "cuts": [0, 1],
		"spec": {"kind": &"lantern", "ring": false}},
	{"id": &"tsuzumi", "name": "Hand drum", "family": &"things", "group": &"tall_thing", "cuts": [0, 1],
		"spec": {"kind": &"drum", "ring": false}},
	# Wings: butterflies, dragonflies and geese.
	{"id": &"cho", "name": "Butterfly", "family": &"wings", "group": &"butterfly", "cuts": [0, 1],
		"spec": {"kind": &"butterfly", "ring": false}},
	{"id": &"cho_maru", "name": "Butterfly in a ring", "family": &"wings", "group": &"butterfly", "cuts": [0, 1],
		"spec": {"kind": &"butterfly", "ring": true}},
	{"id": &"tombo", "name": "Dragonfly", "family": &"wings", "group": &"dragonfly", "cuts": [0, 1],
		"spec": {"kind": &"dragonfly", "ring": false}},
	{"id": &"tombo_maru", "name": "Dragonfly in a ring", "family": &"wings", "group": &"dragonfly", "cuts": [0, 1],
		"spec": {"kind": &"dragonfly", "ring": true}},
	{"id": &"kari", "name": "Wild goose", "family": &"wings", "group": &"goose", "cuts": [0, 1],
		"spec": {"kind": &"goose", "crest": false, "ring": false}},
	{"id": &"kari_maru", "name": "Wild goose in a ring", "family": &"wings", "group": &"goose", "cuts": [0, 1],
		"spec": {"kind": &"goose", "crest": false, "ring": true}},
]

static var _index: Dictionary[StringName, int] = {}


static func motif_count() -> int:
	return MOTIFS.size()


static func motif_index(id: StringName) -> int:
	if _index.is_empty():
		for i in MOTIFS.size():
			_index[MOTIFS[i].id] = i
	return _index.get(id, -1)


static func pair_of(motif: int, cut: int) -> int:
	return FIRST_PAIR + motif * 2 + cut


static func motif_of(pair: int) -> int:
	if pair < FIRST_PAIR:
		return -1
	var motif := (pair - FIRST_PAIR) >> 1
	return motif if motif < MOTIFS.size() else -1


static func cut_of(pair: int) -> int:
	return (pair - FIRST_PAIR) & 1 if pair >= FIRST_PAIR else (pair >> 2) & 1


static func is_valid_pair(pair: int) -> bool:
	if pair < 0:
		return false
	if pair < FIRST_PAIR:
		return HalvesFace.is_valid(pair << 1)
	var motif := motif_of(pair)
	return motif >= 0 and (MOTIFS[motif].cuts as Array).has(cut_of(pair))


static func family_of(pair: int) -> StringName:
	if not is_valid_pair(pair):
		return &""
	if pair < FIRST_PAIR:
		return &"shapes"
	return MOTIFS[motif_of(pair)].family


static func group_of(pair: int) -> StringName:
	if not is_valid_pair(pair):
		return &""
	if pair < FIRST_PAIR:
		return HalvesFace.SHAPE_GROUPS[pair >> 3]
	return MOTIFS[motif_of(pair)].group


static func pairs_in_family(family: StringName) -> PackedInt32Array:
	var pairs := PackedInt32Array()
	if family == &"shapes":
		for pair in FIRST_PAIR:
			if is_valid_pair(pair):
				pairs.append(pair)
		return pairs
	for motif in MOTIFS.size():
		if MOTIFS[motif].family == family:
			for cut in 2:
				if is_valid_pair(pair_of(motif, cut)):
					pairs.append(pair_of(motif, cut))
	return pairs


## How easily pair_b passes for pair_a (0..1): 1 for the same pair, 0 across groups.
static func similarity(pair_a: int, pair_b: int) -> float:
	if pair_a == pair_b:
		return 1.0
	# Shapes and crests never pass for each other.
	if (pair_a < FIRST_PAIR) != (pair_b < FIRST_PAIR):
		return 0.0
	var group := group_of(pair_a)
	if group == &"" or group != group_of(pair_b):
		return 0.0
	if pair_a < FIRST_PAIR:
		return 0.8 if (pair_a & 3) == (pair_b & 3) else 0.6
	var spec_a: Dictionary = MOTIFS[motif_of(pair_a)].spec
	var spec_b: Dictionary = MOTIFS[motif_of(pair_b)].spec
	var keys := {}
	for key: Variant in spec_a:
		keys[key] = true
	for key: Variant in spec_b:
		keys[key] = true
	var shared := 0
	for key: Variant in keys:
		if spec_a.has(key) and spec_b.has(key) and spec_a[key] == spec_b[key]:
			shared += 1
	var score := 0.5 + 0.4 * float(shared) / float(keys.size())
	if cut_of(pair_a) != cut_of(pair_b):
		score -= 0.1
	return score
