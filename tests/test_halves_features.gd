extends GutTest
## HalvesGeometry v2 (touch, with_features, locks, frost, blocked_reason, the monotone rule) and
## HalvesFeatures (normalize, validate, tile_count, mask, and place's invariants on dealt plan boards).
## Written from docs/HALVES.md alone; feature dictionaries are compared as JSON text so 3 and 3.0 differ.

const H := preload("res://tests/halves_helpers.gd")
const B := HalvesGeometry.Block

## place specs for the invariant checks: one per feature, a mix, and far more than any board has.
const SPECS: Array[Dictionary] = [
	{"key_pairs": 2, "locked": 3},
	{"frost": 4},
	{"mist": 4},
	{"gold": 3},
	{"key_pairs": 1, "locked": 2, "frost": 2, "mist": 2, "gold": 2},
	{"key_pairs": 40, "locked": 40, "frost": 40, "mist": 40, "gold": 40},
]
const PLACE_LEVELS: Array[int] = [3, 6, 9, 13]


func _rng(parts: Array) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_features"] + parts, 2)


# --- an independent reference of the section 1 rules, straight from the positions ---


func _covers(p: Array[Vector3i], j: int, i: int) -> bool:
	return p[j].z > p[i].z and absi(p[j].x - p[i].x) < 2 and absi(p[j].y - p[i].y) < 2


func _side(p: Array[Vector3i], j: int, i: int, dx: int) -> bool:
	return p[j].z == p[i].z and p[j].x == p[i].x + dx and absi(p[j].y - p[i].y) < 2


## Section 1: j touches i if j covers i, j is a left or right neighbour, or j is directly above or
## below in the same layer (|dx| < 2, |dy| == 2). Tiles that i covers do not touch i.
func _touch_ref(p: Array[Vector3i], i: int) -> PackedInt64Array:
	var m := HalvesBits.empty()
	for j: int in p.size():
		if j == i:
			continue
		var same_layer_vertical := p[j].z == p[i].z and absi(p[j].x - p[i].x) < 2 and absi(p[j].y - p[i].y) == 2
		if _covers(p, j, i) or _side(p, j, i, -2) or _side(p, j, i, 2) or same_layer_vertical:
			HalvesBits.set_bit(m, j)
	return m


## The first blocking reason by the rules of section 1 for features in normalised form.
func _reason_ref(p: Array[Vector3i], features: Dictionary, i: int, rem: PackedInt64Array) -> int:
	var covered := false
	var has_left := false
	var has_right := false
	for j: int in p.size():
		if j == i or not HalvesBits.has(rem, j):
			continue
		covered = covered or _covers(p, j, i)
		has_left = has_left or _side(p, j, i, -2)
		has_right = has_right or _side(p, j, i, 2)
	if covered:
		return B.COVERED
	if has_left and has_right:
		return B.SIDES
	var locks: Array = features.get("locks", [])
	for group: Dictionary in locks:
		var locked: Array = group.get("locked", [])
		if locked.has(i) and HalvesBits.intersects(rem, HalvesFeatures.mask(group.get("keys", []))):
			return B.LOCKED
	var frost: Array = features.get("frost", [])
	if frost.has(i):
		var need := _touch_ref(p, i)
		if not HalvesBits.is_empty(need) and HalvesBits.is_empty(HalvesBits.minus(need, rem)):
			return B.FROSTED
	return B.FREE


# --- boards ---


## Eight tiles, ids in (z, y, x) order (touch[i] by hand in test_touch_by_hand):
##   layer 0: 0 (0,0,0)  1 (2,0,0)  2 (6,0,0)  3 (4,1,0)  4 (1,2,0)  5 (3,4,0)
##   layer 1: 6 (1,0,1), a bridge on 0 and 1;   layer 2: 7 (0,0,2), on 0 and 6
func _touch_board() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(6, 0, 0), Vector3i(4, 1, 0),
			Vector3i(1, 2, 0), Vector3i(3, 4, 0), Vector3i(1, 0, 1), Vector3i(0, 0, 2)])


## Five tiles: a row 0 (0,0,0), 1 (2,0,0), 2 (4,0,0); a lone key 3 (0,4,0); 4 (2,0,1) on tile 1.
## Key 3 locks the whole row, and the whole row is frosted. touch: 0 {1}, 1 {0, 2, 4}, 2 {1}.
func _order_features() -> Dictionary:
	return {"locks": [{"keys": [3], "locked": [0, 1, 2]}], "frost": [0, 1, 2]}


func _order_board() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 4, 0),
			Vector3i(2, 0, 1)])


# --- HalvesGeometry v2 ---


func test_touch_by_hand() -> void:
	var g := _touch_board()
	var want: Array = [[1, 4, 6, 7], [0, 3, 4, 6], [3], [1, 2], [0, 1], [], [7], []]
	assert_eq(g.touch.size(), 8, "touch is filled without features too")
	for i: int in mini(g.touch.size(), 8):
		assert_eq(g.touch[i], H.mask_of(want[i]), "touch[%d]" % i)
		assert_eq(g.touch[i], _touch_ref(g.positions, i), "touch[%d] matches the reference" % i)
	# Tiles that i covers do not touch i, so touch is not symmetric.
	assert_eq(HalvesBits.intersection(g.touch[6], H.mask_of([0, 1])), HalvesBits.empty(),
			"the bridge does not touch the tiles under it")
	assert_ne(HalvesBits.intersection(g.touch[0], H.bit(6)), HalvesBits.empty(), "but they touch it")


func test_touch_in_a_column_is_the_tile_above_and_below() -> void:
	var g := H.geometry(H.column(4))
	assert_eq(g.touch, [H.mask_of([1]), H.mask_of([0, 2]), H.mask_of([1, 3]), H.mask_of([2])])
	assert_eq(g.free_mask(g.full_mask()), H.from_int(0b1111), "touching never blocks by itself")


func test_touch_is_not_diagonal_or_far() -> void:
	# |dx| == 2 with |dy| == 2 is a diagonal; |dy| == 3 is too far; |dx| == 1 with |dy| == 2 touches.
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 2, 0), Vector3i(4, 3, 0), Vector3i(1, 6, 0), Vector3i(0, 8, 0)])
	assert_eq(g.touch[0], HalvesBits.empty(), "diagonal neighbour")
	assert_eq(g.touch[1], H.mask_of([2]), "(4,3) is a right neighbour of (2,2): |dy| 1")
	assert_eq(g.touch[3], H.mask_of([4]), "(0,8) is below (1,6): |dx| 1, |dy| 2")
	for i: int in g.size():
		assert_eq(g.touch[i], _touch_ref(g.positions, i), "touch[%d]" % i)


func test_a_geometry_without_features() -> void:
	var g := _touch_board()
	assert_false(g.has_features())
	assert_eq(g.features, {})
	assert_eq(g.lock_need.size(), 0, "lock_need is empty without features")
	assert_eq(g.frost_need.size(), 0, "frost_need is empty without features")


func test_without_features_every_subset_follows_the_v1_rules() -> void:
	for g: HalvesGeometry in [_touch_board(), _order_board(), H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0),
			Vector3i(4, 0, 0), Vector3i(6, 0, 0)])]:
		var plain := g.with_features({})
		var bad := ""
		for r: int in 1 << g.size():
			var rem := H.from_int(r)
			var want_mask := HalvesBits.empty()
			for i: int in g.size():
				if not HalvesBits.has(rem, i):
					continue
				var want := _reason_ref(g.positions, {}, i, rem)
				if want == B.FREE:
					HalvesBits.set_bit(want_mask, i)
				if g.blocked_reason(i, rem) != want and bad == "":
					bad = "tile %d in %d: reason %d, want %d" % [i, r, g.blocked_reason(i, rem), want]
				if g.is_free(i, rem) != (want == B.FREE) and bad == "":
					bad = "tile %d in %d: is_free %s" % [i, r, g.is_free(i, rem)]
			if g.free_mask(rem) != want_mask and bad == "":
				bad = "free_mask(%d) = %s, want %s" % [r, H.ids(g.free_mask(rem)), H.ids(want_mask)]
			if plain.free_mask(rem) != want_mask and bad == "":
				bad = "with_features({}).free_mask(%d) = %s, want %s" % [r, H.ids(plain.free_mask(rem)), H.ids(want_mask)]
		assert_eq(bad, "", "%d-tile board follows the v1 rules" % g.size())


func test_with_features_empty_is_a_geometry_without_features() -> void:
	var g := _touch_board()
	for raw: Dictionary in [{}, {"frost": [], "mist": [], "locks": [{"keys": [1], "locked": []}, {"keys": [], "locked": [2]}]}]:
		var plain := g.with_features(raw)
		assert_false(plain.has_features(), "%s normalises to no features" % raw)
		assert_eq(plain.features, {})
		assert_eq(plain.lock_need.size(), 0)
		assert_eq(plain.frost_need.size(), 0)
		assert_eq(plain.positions, g.positions)
		assert_eq(plain.touch, g.touch)


func test_with_features_returns_a_new_geometry_and_never_mutates() -> void:
	var g := _order_board()
	var full := g.full_mask()
	var free_before := g.free_mask(full)
	var g2 := g.with_features(_order_features())
	assert_false(is_same(g, g2), "a new geometry")
	assert_true(g2.has_features())
	assert_false(g.has_features(), "the original keeps no features")
	assert_eq(g.features, {})
	assert_eq(g.lock_need.size(), 0)
	assert_eq(g.frost_need.size(), 0)
	assert_eq(g.free_mask(full), free_before)
	assert_eq(g2.positions, g.positions, "same positions")
	assert_eq(g2.cover, g.cover)
	assert_eq(g2.left, g.left)
	assert_eq(g2.right, g.right)
	assert_eq(g2.touch, g.touch)
	assert_eq(g2.size(), g.size())
	assert_ne(g2.free_mask(full), free_before, "the rules apply to the new one")


func test_with_features_keeps_the_normalised_features() -> void:
	var raw := {"gold": [4.0, 2.0, 2.0], "mist": [3.0, 1.0]}
	var g := _touch_board().with_features(raw)
	assert_eq(H.js(g.features), H.js({"mist": [1, 3], "gold": [2, 4]}))
	assert_eq(H.js(g.features), H.js(HalvesFeatures.normalize(raw)))


func test_lock_need_and_frost_need() -> void:
	var g := _order_board().with_features(_order_features())
	var none := HalvesBits.empty()
	assert_eq(g.lock_need, [H.bit(3), H.bit(3), H.bit(3), none, none])
	assert_eq(g.frost_need, [H.mask_of([1]), H.mask_of([0, 2, 4]), H.mask_of([1]), none, none])


func test_a_lock_waits_for_every_key_of_its_group() -> void:
	var g := H.geometry(H.column(6)).with_features({"locks": [{"keys": [0, 1], "locked": [4]}]})
	var full := g.full_mask()
	assert_false(g.is_free(4, full))
	assert_eq(g.blocked_reason(4, full), B.LOCKED)
	assert_false(g.is_free(4, HalvesBits.minus(full, H.bit(0))), "key 1 is left")
	assert_false(g.is_free(4, HalvesBits.minus(full, H.bit(1))), "key 0 is left")
	assert_true(g.is_free(4, HalvesBits.minus(full, H.mask_of([0, 1]))), "the last key is gone")
	assert_eq(g.blocked_reason(4, HalvesBits.minus(full, H.mask_of([0, 1]))), B.FREE)
	for i: int in [0, 1, 2, 3, 5]:
		assert_true(g.is_free(i, full), "tile %d has no lock" % i)
	assert_eq(g.free_mask(full), H.mask_of([0, 1, 2, 3, 5]))
	var none := HalvesBits.empty()
	assert_eq(g.lock_need, [none, none, none, none, H.mask_of([0, 1]), none])
	assert_eq(g.frost_need, [none, none, none, none, none, none])


func test_a_tile_locked_by_two_groups_needs_both_groups_keys_gone() -> void:
	var g := H.geometry(H.column(6)).with_features(
			{"locks": [{"keys": [0], "locked": [4]}, {"keys": [1], "locked": [4, 5]}]})
	var full := g.full_mask()
	assert_eq(g.lock_need[4], H.mask_of([0, 1]), "the union of both groups' keys")
	assert_eq(g.lock_need[5], H.mask_of([1]))
	assert_false(g.is_free(4, HalvesBits.minus(full, H.bit(0))), "group 2 still waits for key 1")
	assert_false(g.is_free(4, HalvesBits.minus(full, H.bit(1))), "group 1 still waits for key 0")
	assert_true(g.is_free(4, HalvesBits.minus(full, H.mask_of([0, 1]))))
	assert_true(g.is_free(5, HalvesBits.minus(full, H.bit(1))), "tile 5 only needs key 1")
	assert_false(g.is_free(5, HalvesBits.minus(full, H.bit(0))))


func test_frost_thaws_when_a_touching_tile_is_removed() -> void:
	# Column: tile 3 touches 2 and 4 only.
	var g := H.geometry(H.column(6)).with_features({"frost": [3]})
	var full := g.full_mask()
	assert_eq(g.frost_need[3], H.mask_of([2, 4]))
	assert_eq(g.blocked_reason(3, full), B.FROSTED)
	assert_false(g.is_free(3, HalvesBits.minus(full, H.bit(0))), "tile 0 does not touch tile 3")
	assert_false(g.is_free(3, HalvesBits.minus(full, H.bit(5))))
	assert_true(g.is_free(3, HalvesBits.minus(full, H.bit(2))), "the tile above is gone")
	assert_true(g.is_free(3, HalvesBits.minus(full, H.bit(4))), "the tile below is gone")
	assert_eq(g.free_mask(full), H.mask_of([0, 1, 2, 4, 5]))


func test_frost_thaws_when_its_cover_tile_is_removed() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 0, 1)]).with_features({"frost": [0]})
	assert_eq(g.frost_need[0], H.bit(2), "only the tile on top touches it")
	assert_eq(g.blocked_reason(0, H.from_int(0b111)), B.COVERED)
	assert_eq(g.blocked_reason(0, H.from_int(0b011)), B.FREE, "uncovered and thawed by the same removal")


func test_blocked_reason_order() -> void:
	var g := _order_board().with_features(_order_features())
	var full := g.full_mask()
	assert_eq(g.blocked_reason(1, full), B.COVERED, "covered, sides, locked and frosted")
	assert_eq(g.blocked_reason(1, HalvesBits.minus(full, H.bit(4))), B.SIDES, "sides, locked and frosted")
	assert_eq(g.blocked_reason(1, H.mask_of([0, 1, 2])), B.SIDES, "sides only (key and cover gone)")
	assert_eq(g.blocked_reason(1, H.mask_of([1, 2, 3])), B.LOCKED, "locked (frost thawed by tile 0)")
	assert_eq(g.blocked_reason(0, full), B.LOCKED, "locked and frosted")
	assert_eq(g.blocked_reason(0, HalvesBits.minus(full, H.bit(3))), B.FROSTED, "the key is gone, tile 1 still touches")
	assert_eq(g.blocked_reason(0, HalvesBits.minus(full, H.mask_of([1, 3]))), B.FREE)
	assert_eq(g.blocked_reason(2, H.mask_of([0, 1, 2, 4])), B.FROSTED)
	assert_eq(g.blocked_reason(2, H.mask_of([0, 2, 4])), B.FREE)
	assert_eq(g.blocked_reason(3, full), B.FREE, "a key has no rule of its own")
	assert_eq(g.blocked_reason(4, full), B.FREE)


func test_every_subset_matches_the_reference_rules() -> void:
	var boards: Array = [
		[_order_board(), _order_features()],
		[_touch_board(), {"locks": [{"keys": [5], "locked": [0, 6]}, {"keys": [2], "locked": [6]}], "frost": [1, 3, 4],
				"mist": [7], "gold": [2]}],
	]
	for entry: Array in boards:
		var plain: HalvesGeometry = entry[0]
		var features := HalvesFeatures.normalize(entry[1])
		var g := plain.with_features(features)
		var bad := ""
		for r: int in 1 << g.size():
			var rem := H.from_int(r)
			var want_mask := HalvesBits.empty()
			for i: int in g.size():
				if not HalvesBits.has(rem, i):
					continue
				var want := _reason_ref(g.positions, features, i, rem)
				if want == B.FREE:
					HalvesBits.set_bit(want_mask, i)
				if g.blocked_reason(i, rem) != want and bad == "":
					bad = "tile %d in %d: reason %d, want %d" % [i, r, g.blocked_reason(i, rem), want]
				if g.is_free(i, rem) != (want == B.FREE) and bad == "":
					bad = "tile %d in %d: is_free %s, reason %d" % [i, r, g.is_free(i, rem), want]
			if g.free_mask(rem) != want_mask and bad == "":
				bad = "free_mask(%d) = %s, want %s" % [r, H.ids(g.free_mask(rem)), H.ids(want_mask)]
		assert_eq(bad, "", "%d-tile board with %s" % [g.size(), H.js(features)])


func test_mist_and_gold_do_not_change_the_rules() -> void:
	var g := _touch_board()
	var all: Array = [0, 1, 2, 3, 4, 5, 6, 7]
	var g2 := g.with_features({"mist": all, "gold": all})
	assert_true(g2.has_features())
	var none := HalvesBits.empty()
	assert_eq(g2.lock_need, [none, none, none, none, none, none, none, none])
	assert_eq(g2.frost_need, [none, none, none, none, none, none, none, none])
	var same := true
	for r: int in 1 << g.size():
		var rem := H.from_int(r)
		same = same and g2.free_mask(rem) == g.free_mask(rem)
	assert_true(same, "mist and gold have no effect on the rules")


func test_monotone_on_hand_boards_exhaustive() -> void:
	# For every R, every R' within R and every tile i of R': free in R implies free in R'.
	var g := _touch_board().with_features({"locks": [{"keys": [5], "locked": [0, 6]}], "frost": [1, 3, 4]})
	var n := g.size()
	var bad := ""
	for rem: int in 1 << n:
		var free := g.free_mask(H.from_int(rem))
		var sub := rem
		while true:
			var sub_set := H.from_int(sub)
			var sub_free := g.free_mask(sub_set)
			# Every tile free in rem and still in sub must be free in sub.
			var lost := HalvesBits.minus(HalvesBits.intersection(free, sub_set), sub_free)
			if not HalvesBits.is_empty(lost) and bad == "":
				bad = "free in %d but not in its subset %d: %s" % [rem, sub, H.ids(lost)]
			if sub == 0:
				break
			sub = (sub - 1) & rem
	assert_eq(bad, "")


func test_monotone_on_dealt_boards_with_random_subsets() -> void:
	for level: int in PLACE_LEVELS:
		var g := H.plan_geometry(level)
		var dealt := HalvesFill.deal(g, H.plan_keys(level, g.size()), _rng(["deal", level]))
		if dealt.is_empty():
			fail_test("level %d: no deal" % level)
			continue
		var features := HalvesFeatures.place(g, H.pairs(dealt["solution"]), dealt["faces"], SPECS[4].duplicate(true),
				_rng(["mono", level]))
		var gf := g.with_features(features)
		var rng := _rng(["subsets", level])
		var full := g.full_mask()
		var bad := ""
		for trial: int in 300:
			var rem := HalvesBits.intersection(H.from_int((rng.randi() << 32) | rng.randi()), full)
			var sub := HalvesBits.intersection(rem, H.from_int((rng.randi() << 32) | rng.randi()))
			var free := gf.free_mask(rem)
			for i: int in g.size():
				if HalvesBits.has(sub, i) and HalvesBits.has(free, i) and not gf.is_free(i, sub) and bad == "":
					bad = "tile %d free in %s but not in %s" % [i, H.ids(rem), H.ids(sub)]
		assert_eq(bad, "", "level %d with %s" % [level, H.js(features)])


# --- HalvesFeatures: normalize, validate, tile_count, mask ---


func test_normalize_casts_sorts_dedups_and_drops_empties() -> void:
	var raw := {"gold": [5.0, 3.0, 3.0], "mist": [], "frost": [4.0, 1.0, 4.0],
			"locks": [{"keys": [9.0, 3.0, 3.0], "locked": [21.0, 20.0]}, {"keys": [], "locked": [1.0]},
			{"keys": [2.0], "locked": []}]}
	var got := HalvesFeatures.normalize(raw)
	assert_eq(H.js(got), H.js({"locks": [{"keys": [3, 9], "locked": [20, 21]}], "frost": [1, 4], "gold": [3, 5]}))
	assert_eq(got.keys(), ["locks", "frost", "gold"], "key order locks, frost, mist, gold")
	assert_eq(H.js(HalvesFeatures.normalize(got)), H.js(got), "idempotent")


func test_normalize_key_order_and_json_input() -> void:
	var parsed: Variant = JSON.parse_string('{"gold": [7], "mist": [6, 2], "frost": [5], "locks": [{"locked": [4], "keys": [1, 0]}]}')
	var got := HalvesFeatures.normalize(parsed as Dictionary)
	assert_eq(got.keys(), ["locks", "frost", "mist", "gold"])
	assert_eq(H.js(got), H.js({"locks": [{"keys": [0, 1], "locked": [4]}], "frost": [5], "mist": [2, 6], "gold": [7]}))
	assert_eq(H.js(HalvesFeatures.normalize(HalvesFeatures.normalize(got))), H.js(got))


func test_normalize_of_nothing_is_empty() -> void:
	assert_eq(HalvesFeatures.normalize({}), {})
	assert_eq(HalvesFeatures.normalize({"locks": [], "frost": [], "mist": [], "gold": []}), {})
	assert_eq(HalvesFeatures.normalize({"locks": [{"keys": [1], "locked": []}]}), {}, "a group without locked tiles")
	assert_eq(HalvesFeatures.normalize({"locks": [{"keys": [], "locked": [1]}]}), {}, "a group without keys")


func test_validate_accepts_good_features() -> void:
	var g := H.geometry(H.column(6))
	var good := {"locks": [{"keys": [0], "locked": [5]}], "frost": [2], "mist": [3], "gold": [4]}
	var errors := HalvesFeatures.validate(g, good)
	assert_true(errors.is_empty(), ", ".join(errors))
	assert_true(HalvesFeatures.validate(g, {}).is_empty(), "no features")
	assert_true(HalvesFeatures.validate(g, {}, H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)])).is_empty())
	# Several groups may lock one tile; a tile may be a key in two groups.
	var shared := {"locks": [{"keys": [0], "locked": [4]}, {"keys": [0, 1], "locked": [4, 5]}]}
	assert_true(HalvesFeatures.validate(g, shared).is_empty(), ", ".join(HalvesFeatures.validate(g, shared)))


func _assert_rejected(errors: PackedStringArray, why: String) -> void:
	assert_false(errors.is_empty(), "should be rejected: %s" % why)
	for e: String in errors:
		assert_ne(e.strip_edges(), "", "%s: every report is a readable sentence" % why)


func test_validate_rejects_ids_out_of_range() -> void:
	var g := H.geometry(H.column(6))
	_assert_rejected(HalvesFeatures.validate(g, {"frost": [6]}), "frost id == size")
	_assert_rejected(HalvesFeatures.validate(g, {"mist": [-1]}), "negative mist id")
	_assert_rejected(HalvesFeatures.validate(g, {"gold": [99]}), "gold id far out")
	_assert_rejected(HalvesFeatures.validate(g, {"locks": [{"keys": [7], "locked": [1]}]}), "key id out of range")
	_assert_rejected(HalvesFeatures.validate(g, {"locks": [{"keys": [1], "locked": [6]}]}), "locked id out of range")


func test_validate_rejects_bad_locks() -> void:
	var g := H.geometry(H.column(6))
	_assert_rejected(HalvesFeatures.validate(g, {"locks": [{"keys": [0, 1], "locked": [1, 2]}]}),
			"keys and locked tiles overlap")
	_assert_rejected(HalvesFeatures.validate(g, {"locks": [{"keys": [0], "locked": [2]}, {"keys": [2], "locked": [4]}]}),
			"tile 2 is locked in one group and a key in another")


func test_validate_checks_the_solution_under_the_rules() -> void:
	var g := H.geometry(H.column(6))
	var lock := {"locks": [{"keys": [0, 1], "locked": [2]}]}
	var ok := HalvesFeatures.validate(g, lock, H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]))
	assert_true(ok.is_empty(), ", ".join(ok))
	_assert_rejected(HalvesFeatures.validate(g, lock, H.pairs([Vector2i(2, 3), Vector2i(0, 1), Vector2i(4, 5)])),
			"tile 2 is still locked at step 0")
	_assert_rejected(HalvesFeatures.validate(g, lock, H.pairs([Vector2i(0, 1)])), "the solution does not clear the board")
	# Column: tile 0 touches only tile 1.
	var frost := {"frost": [0]}
	var thawed := HalvesFeatures.validate(g, frost, H.pairs([Vector2i(1, 2), Vector2i(0, 3), Vector2i(4, 5)]))
	assert_true(thawed.is_empty(), ", ".join(thawed))
	_assert_rejected(HalvesFeatures.validate(g, frost, H.pairs([Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 5)])),
			"tile 0 is frosted at step 0")
	# The plain rules count too: a row of four only frees its ends.
	var row := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)])
	_assert_rejected(HalvesFeatures.validate(row, {}, H.pairs([Vector2i(1, 2), Vector2i(0, 3)])), "blocked by its sides")


func test_tile_count() -> void:
	assert_eq(HalvesFeatures.tile_count({}), 0)
	assert_eq(HalvesFeatures.tile_count({"gold": [1, 2, 3]}), 0, "gold is not counted")
	assert_eq(HalvesFeatures.tile_count({"locks": [{"keys": [0, 1], "locked": [4]}], "frost": [4, 5], "mist": [1, 6],
			"gold": [7, 0]}), 5, "tiles 0, 1, 4, 5, 6")
	assert_eq(HalvesFeatures.tile_count({"locks": [{"keys": [0], "locked": [3]}, {"keys": [1], "locked": [3]}]}), 3)


## (v3) A mask is a HalvesBits set: tile i is bit i & 63 of word i >> 6; the edge is tile 127.
func test_mask() -> void:
	assert_eq(HalvesFeatures.mask([]), PackedInt64Array([0, 0]))
	assert_eq(HalvesFeatures.mask([0, 3]), PackedInt64Array([9, 0]))
	assert_eq(HalvesFeatures.mask([3, 0, 3]), PackedInt64Array([9, 0]))
	assert_eq(HalvesFeatures.mask([127]), PackedInt64Array([0, 1 << 63]))
	assert_eq(HalvesFeatures.mask([0, 127]), PackedInt64Array([1, 1 << 63]))


# --- HalvesFeatures.place ---


func test_place_with_an_empty_spec_places_nothing() -> void:
	var g := H.plan_geometry(3)
	var dealt := HalvesFill.deal(g, H.plan_keys(3, g.size()), _rng(["deal", 3]))
	if dealt.is_empty():
		fail_test("no deal")
		return
	var order := H.pairs(dealt["solution"])
	assert_eq(HalvesFeatures.place(g, order, dealt["faces"], {}, _rng(["empty"])), {})
	var keys_only := HalvesFeatures.place(g, order, dealt["faces"], {"key_pairs": 2}, _rng(["keys only"]))
	assert_false(keys_only.has("locks"), "no locks without locked tiles")
	var locked_only := HalvesFeatures.place(g, order, dealt["faces"], {"locked": 2}, _rng(["locked only"]))
	assert_false(locked_only.has("locks"), "no locks without key pairs")


func test_place_on_one_pair_has_no_key_range() -> void:
	# n = 1: the key range [0, 0) is empty, so there is no lock group.
	var g := H.geometry(H.column(2))
	var got := HalvesFeatures.place(g, H.pairs([Vector2i(0, 1)]), H.faces(["circle:v:-:a", "circle:v:-:b"]),
			{"key_pairs": 1, "locked": 1}, _rng(["one pair"]))
	assert_false(got.has("locks"))


func test_place_invariants_on_dealt_boards() -> void:
	for level: int in PLACE_LEVELS:
		var g := H.plan_geometry(level)
		var dealt := HalvesFill.deal(g, H.plan_keys(level, g.size()), _rng(["deal", level]))
		if dealt.is_empty():
			fail_test("level %d: no deal" % level)
			continue
		var order := H.pairs(dealt["solution"])
		var faces: PackedInt32Array = dealt["faces"]
		for s: int in SPECS.size():
			for seed_n: int in 2:
				var features := HalvesFeatures.place(g, order, faces, SPECS[s].duplicate(true),
						_rng(["place", level, s, seed_n]))
				_check_place(g, order, faces, SPECS[s], features, "level %d spec %d seed %d" % [level, s, seed_n])


func test_place_same_seed_same_features() -> void:
	var g := H.plan_geometry(9)
	var dealt := HalvesFill.deal(g, H.plan_keys(9, g.size()), _rng(["deal", 9]))
	if dealt.is_empty():
		fail_test("no deal")
		return
	var order := H.pairs(dealt["solution"])
	var a := HalvesFeatures.place(g, order, dealt["faces"], SPECS[4].duplicate(true), _rng(["same"]))
	var b := HalvesFeatures.place(g, order, dealt["faces"], SPECS[4].duplicate(true), _rng(["same"]))
	assert_eq(H.js(a), H.js(b))
	assert_ne(a, {}, "the mixed spec places something")


## Every rule of docs/HALVES.md section 2 (`place`) that can be checked from the result alone.
func _check_place(g: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array, spec: Dictionary,
		f: Dictionary, label: String) -> void:
	var n := order.size()
	var size := g.size()
	var step := H.steps_of(order, size)
	var free_before: Array[PackedInt64Array] = []
	var rem := g.full_mask()
	for k: int in n:
		free_before.append(g.free_mask(rem))
		rem = HalvesBits.minus(rem, H.mask_of([order[k].x, order[k].y]))
	var all := g.full_mask()
	var none := HalvesBits.empty()

	assert_eq(H.js(f), H.js(HalvesFeatures.normalize(f)), label + ": normalised")
	var errors := HalvesFeatures.validate(g, f, order)
	assert_true(errors.is_empty(), label + ": validates with the order: " + ", ".join(errors))

	# 1. Locks.
	var locks: Array = f.get("locks", [])
	var keys := HalvesBits.empty()
	var locked := HalvesBits.empty()
	assert_true(locks.size() <= 1, label + ": at most one group")
	if locks.size() == 1:
		keys = HalvesFeatures.mask((locks[0] as Dictionary).get("keys", []))
		locked = HalvesFeatures.mask((locks[0] as Dictionary).get("locked", []))
	var lo := floori(n / 3.0)
	var hi := floori(2 * n / 3.0)
	if int(spec.get("key_pairs", 0)) > 0 and int(spec.get("locked", 0)) > 0 and hi > lo:
		assert_eq(locks.size(), 1, label + ": one lock group")
		var key_steps := {}
		for t: int in H.ids(keys):
			assert_between(step[t], lo, hi - 1, label + ": key %d's step is in [n/3, 2n/3)" % t)
			key_steps[step[t]] = true
		var last := -1
		for k: int in key_steps:
			assert_ne(HalvesBits.intersection(keys, H.bit(order[k].x)), none, label + ": both tiles of key step %d" % k)
			assert_ne(HalvesBits.intersection(keys, H.bit(order[k].y)), none, label + ": both tiles of key step %d" % k)
			last = maxi(last, k)
		assert_eq(key_steps.size(), mini(int(spec.get("key_pairs", 0)), hi - lo), label + ": key steps")
		var cand := HalvesBits.empty()
		var pref := HalvesBits.empty()
		for t: int in size:
			if step[t] <= last:
				continue
			HalvesBits.set_bit(cand, t)
			for k: int in last + 1:
				if HalvesBits.has(free_before[k], t):
					HalvesBits.set_bit(pref, t)
		assert_eq(HalvesBits.minus(locked, cand), none, label + ": locked tiles leave after the last key")
		assert_eq(HalvesBits.count(locked), mini(int(spec.get("locked", 0)), HalvesBits.count(cand)),
				label + ": locked count")
		_assert_preferred(locked, pref, label + ": locked tiles free early come first")
	else:
		assert_eq(locks.size(), 0, label + ": no lock group")

	# 2. Frost.
	var used := HalvesBits.union(keys, locked)
	var frost := HalvesFeatures.mask(f.get("frost", []))
	var frost_cand := HalvesBits.empty()
	for t: int in size:
		if HalvesBits.has(used, t):
			continue
		var touching := _touch_ref(g.positions, t)
		for j: int in H.ids(touching):
			if step[j] < step[t]:
				HalvesBits.set_bit(frost_cand, t)
	assert_eq(HalvesBits.minus(frost, frost_cand), none, label + ": every frost tile has a touching tile removed earlier")
	assert_eq(HalvesBits.count(frost), mini(int(spec.get("frost", 0)), HalvesBits.count(frost_cand)),
			label + ": frost count")
	_assert_preferred(frost, HalvesBits.intersection(frost_cand, free_before[0]),
			label + ": frost on tiles free at the start first")

	# 3. Mist.
	used = HalvesBits.union(used, frost)
	var live_y := HalvesBits.empty()
	for link: Vector4i in HalvesFill.trap_links(g, order):
		var other_q := order[link.x].x + order[link.x].y - link.z
		var other_p := order[link.y].x + order[link.y].y - link.w
		if HalvesFace.matches(faces[link.z], faces[link.w]) and HalvesFace.matches(faces[other_q], faces[other_p]):
			HalvesBits.set_bit(live_y, link.w)
	var mist := HalvesFeatures.mask(f.get("mist", []))
	var mist_cand := HalvesBits.minus(HalvesBits.minus(HalvesBits.minus(all, free_before[0]), used), live_y)
	assert_eq(HalvesBits.intersection(mist, free_before[0]), none, label + ": mist tiles are not free at the start")
	assert_eq(HalvesBits.minus(mist, mist_cand), none, label + ": mist candidates only")
	assert_eq(HalvesBits.count(mist), mini(int(spec.get("mist", 0)), HalvesBits.count(mist_cand)),
			label + ": mist count")

	# 4. Gold.
	used = HalvesBits.union(used, mist)
	var gold := HalvesFeatures.mask(f.get("gold", []))
	var gold_cand := HalvesBits.minus(all, used)
	var upper := HalvesBits.empty()
	for t: int in size:
		if g.positions[t].z >= 1:
			HalvesBits.set_bit(upper, t)
	assert_eq(HalvesBits.minus(gold, gold_cand), none, label + ": gold only on unused tiles")
	assert_eq(HalvesBits.count(gold), mini(int(spec.get("gold", 0)), HalvesBits.count(gold_cand)),
			label + ": gold count")
	_assert_preferred(gold, HalvesBits.intersection(gold_cand, upper), label + ": gold prefers z >= 1")


## "Preferred first": with k chosen, either all k come from the preferred set or all of it was taken.
func _assert_preferred(chosen: PackedInt64Array, preferred: PackedInt64Array, label: String) -> void:
	if HalvesBits.count(chosen) <= HalvesBits.count(preferred):
		assert_eq(HalvesBits.minus(chosen, preferred), HalvesBits.empty(), label)
	else:
		assert_eq(HalvesBits.minus(preferred, chosen), HalvesBits.empty(), label)
