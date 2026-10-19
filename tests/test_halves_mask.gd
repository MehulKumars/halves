extends GutTest
## HalvesMask: parsing half-unit ASCII masks and every validation rule, plus the hand-made data in
## tools/levelgen/ (every mask validates, every plan slot points at a mask and uses valid pair types).
## Written from docs/HALVES.md alone; each invalid board breaks exactly one rule and is otherwise valid.
## (v2) The plan's slot count comes from HalvesLevels.COUNT, and its optional v2 fields are checked.

const H := preload("res://tests/halves_helpers.gd")


func _assert_invalid(points: Array, why: String) -> void:
	var errors := HalvesMask.validate(H.positions(points))
	assert_false(errors.is_empty(), "should be rejected: %s" % why)


func _assert_valid(points: Array, why: String) -> void:
	var errors := HalvesMask.validate(H.positions(points))
	assert_true(errors.is_empty(), "should be valid (%s), got: %s" % [why, ", ".join(errors)])


func test_parse_one_layer() -> void:
	var got := HalvesMask.parse([["X.X.X.X.", "........", "X.X.X.X."]])
	var want := H.positions([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0),
			Vector3i(0, 2, 0), Vector3i(2, 2, 0), Vector3i(4, 2, 0), Vector3i(6, 2, 0)])
	assert_eq(got, want)


func test_parse_spaces_empty_rows_and_short_layers() -> void:
	# Spaces are empty, "" is an empty row, and the upper layer leaves out rows and trailing columns.
	var got := HalvesMask.parse([["X X", "", "X.X."], ["", ".X"]])
	var want := H.positions([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 2, 0), Vector3i(2, 2, 0),
			Vector3i(1, 1, 1)])
	assert_eq(got, want)


func test_parse_sorts_by_layer_then_row_then_column() -> void:
	var got := HalvesMask.parse([["..X.", "X...", "...."], ["", "", "", ".X"], [".X"]])
	# By hand: z 0 (y 0 x 2, then y 1 x 0), then z 1 (y 3 x 1), then z 2 (y 0 x 1).
	var want := H.positions([Vector3i(2, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 3, 1), Vector3i(1, 0, 2)])
	assert_eq(got, want)


func test_parse_empty() -> void:
	assert_eq(HalvesMask.parse([]), H.positions([]))
	assert_eq(HalvesMask.parse([["....", ""]]), H.positions([]))


func test_parse_matches_the_intro_mask_in_the_docs() -> void:
	var got := H.mask_positions("p1_intro")
	assert_eq(got.size(), 8)
	assert_eq(got[0], Vector3i(0, 0, 0))
	assert_eq(got[7], Vector3i(6, 2, 0))


func test_valid_boards_give_no_errors() -> void:
	_assert_valid([Vector3i(0, 0, 0), Vector3i(2, 0, 0)], "a row of two")
	# A tile half offset on four lower tiles, each quarter resting on one of them.
	_assert_valid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 2, 0),
			Vector3i(2, 2, 0), Vector3i(1, 1, 1)], "a half-offset upper tile")
	_assert_valid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(1, 0, 1)], "a bridge")


func test_odd_tile_count() -> void:
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0)], "3 tiles")


func test_overlap_on_one_layer() -> void:
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(1, 0, 0)], "|dx| == 1 on one layer")
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(1, 1, 0)], "|dx| == 1, |dy| == 1 on one layer")
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(0, 1, 0)], "|dy| == 1 on one layer")


func test_upper_tile_must_rest_on_the_layer_below() -> void:
	# (1,1,1) covers cells x 1-2, y 1-2; the row below only covers y 0-1.
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(1, 1, 1)],
			"two quarters hang over nothing")
	# (2,0,2) sits above layer 0 tiles, but layer 1 only has (0,0,1) under cells x 0-1.
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0),
			Vector3i(0, 0, 1), Vector3i(2, 0, 2)], "resting on layer z - 2 is not enough")


func test_three_half_unit_gap_in_overlapping_rows() -> void:
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(3, 0, 0)], "|dx| == 3, same row")
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(3, 1, 0)], "|dx| == 3, rows overlap by half")
	_assert_valid([Vector3i(0, 0, 0), Vector3i(3, 2, 0)], "|dx| == 3 but the rows do not overlap")
	_assert_valid([Vector3i(0, 0, 0), Vector3i(4, 0, 0)], "|dx| == 4 is a clear gap")


func test_width_limit() -> void:
	assert_eq(HalvesMask.MAX_WIDTH, 13)
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(12, 0, 0)], "width 14")
	_assert_valid([Vector3i(0, 0, 0), Vector3i(11, 0, 0)], "width 13")


func test_height_limit() -> void:
	assert_eq(HalvesMask.MAX_HEIGHT, 14)
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(0, 13, 0)], "height 15")
	_assert_valid([Vector3i(0, 0, 0), Vector3i(0, 12, 0)], "height 14")


func test_layer_limit() -> void:
	assert_eq(HalvesMask.MAX_LAYERS, 4)
	_assert_valid([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2), Vector3i(0, 0, 3)], "4 layers")
	_assert_invalid([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2),
			Vector3i(0, 0, 3), Vector3i(0, 0, 4)], "5 layers")


## Layer 0: a full 6 x 7 grid (42 tiles, width 12, height 14). Layer 1: `upper` tiles stacked
## straight on top, row by row, so every board is valid apart from its tile count.
func _big_board(upper: int) -> Array:
	var points: Array = []
	for y: int in range(0, 14, 2):
		for x: int in range(0, 12, 2):
			points.append(Vector3i(x, y, 0))
	for i: int in upper:
		points.append(Vector3i(2 * (i % 6), 2 * int(i / 6.0), 1))
	return points


func test_tile_limit() -> void:
	_assert_valid(_big_board(22), "64 tiles")
	_assert_invalid(_big_board(24), "66 tiles")


func test_every_mask_in_the_data_parses_and_validates() -> void:
	var all := H.masks()
	assert_gt(all.size(), 0, "no masks loaded from %s" % H.MASKS_PATH)
	for mask_name: String in all:
		var layers: Array = (all[mask_name] as Dictionary).get("layers", [])
		var positions := HalvesMask.parse(layers)
		assert_gt(positions.size(), 0, "%s has tiles" % mask_name)
		var errors := HalvesMask.validate(positions)
		assert_true(errors.is_empty(), "%s: %s" % [mask_name, ", ".join(errors)])


## (v2) The plan has HalvesLevels.COUNT (100) slots; v1 pinned 30.
func test_plan_has_levels_1_to_count_in_order() -> void:
	var slots := H.plan_slots()
	assert_eq(slots.size(), HalvesLevels.COUNT)
	for i: int in slots.size():
		var slot: Dictionary = slots[i]
		assert_eq(int(slot.get("level", 0)), i + 1, "slot %d" % i)
		assert_has(["intro", "ramp", "hard", "rest", "finale"], String(slot.get("role", "")), "role of level %d" % (i + 1))


func test_plan_masks_exist_and_types_are_valid() -> void:
	var all := H.masks()
	for slot: Dictionary in H.plan_slots():
		var level := int(slot.get("level", 0))
		var mask_name := String(slot.get("mask", ""))
		assert_true(all.has(mask_name), "level %d uses missing mask '%s'" % [level, mask_name])
		var types: Array = slot.get("types", [])
		assert_gt(types.size(), 0, "level %d has pair types" % level)
		for t: String in types:
			assert_ne(HalvesFace.pair_from_text(t), -1, "level %d: '%s' is not a pair type" % [level, t])
		var target_win := float(slot.get("target_win", -1.0))
		assert_between(target_win, 0.0, 1.0, "level %d target_win" % level)
		assert_true(float(slot.get("target_decoy", -1.0)) >= 0.0, "level %d target_decoy" % level)


func _is_whole_number(v: Variant) -> bool:
	return (v is int) or (v is float and is_equal_approx(v, roundf(v)))


## docs/HALVES.md section 3 (v2): the optional slot fields trap, features, min_careful, min_wary, tip.
func test_plan_v2_fields_are_valid() -> void:
	const FEATURE_SPEC_KEYS: Array[String] = ["key_pairs", "locked", "frost", "mist", "gold"]
	for slot: Dictionary in H.plan_slots():
		var level := int(slot.get("level", 0))
		if slot.has("trap"):
			var trap: Variant = slot["trap"]
			assert_true(trap is Array and (trap as Array).size() == 2, "level %d: trap is [lo, hi]" % level)
			if trap is Array and (trap as Array).size() == 2:
				var lo := float(trap[0])
				var hi := float(trap[1])
				assert_true(0.0 <= lo and lo <= hi and hi <= 1.0, "level %d: 0 <= lo <= hi <= 1, got [%s, %s]" % [level, lo, hi])
		if slot.has("features"):
			var spec: Variant = slot["features"]
			assert_true(spec is Dictionary, "level %d: features is an object" % level)
			if spec is Dictionary:
				for key: Variant in spec:
					assert_has(FEATURE_SPEC_KEYS, String(key), "level %d: feature spec key '%s'" % [level, key])
					var v: Variant = (spec as Dictionary)[key]
					assert_true(_is_whole_number(v) and float(v) >= 0.0, "level %d: %s is a non-negative int" % [level, key])
		for key: String in ["min_careful", "min_wary"]:
			if slot.has(key):
				var v: Variant = slot[key]
				assert_true(v is float or v is int, "level %d: %s is a number" % [level, key])
				assert_between(float(v), 0.0, 1.0, "level %d %s" % [level, key])
		if slot.has("tip"):
			assert_true(slot["tip"] is String, "level %d: tip is a string" % level)
