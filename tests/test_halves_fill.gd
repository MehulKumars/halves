extends GutTest
## HalvesFill: reverse-removal orders, face assignment, deals and shuffles (including reseating),
## checked by replaying with HalvesGeometry and an independent brute-force solvability check.
## Written from docs/HALVES.md alone. Random outputs are only checked for properties, never exact values.

const H := preload("res://tests/halves_helpers.gd")


func _rng(parts: Array) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_fill"] + parts, 1)


func _row_of_four() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)])


## Three two-tile stacks in a row with gaps: bottoms 0-2, tops 3-5 (tile 3 on 0, 4 on 1, 5 on 2).
func _three_stacks() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0),
			Vector3i(0, 0, 1), Vector3i(4, 0, 1), Vector3i(8, 0, 1)])


func test_the_order_checker_catches_bad_orders() -> void:
	# Guards the helper the other tests trust: each of these breaks one rule.
	var g := _row_of_four()
	assert_eq(H.order_error(g, H.from_int(0b1111), [Vector2i(0, 3), Vector2i(1, 2)]), "")
	assert_ne(H.order_error(g, H.from_int(0b1111), [Vector2i(1, 2), Vector2i(0, 3)]), "", "blocked at its step")
	assert_ne(H.order_error(g, H.from_int(0b1111), [Vector2i(0, 3)]), "", "tiles left over")
	assert_ne(H.order_error(g, H.from_int(0b1111), [Vector2i(0, 3), Vector2i(0, 3)]), "", "a tile used twice")
	assert_ne(H.order_error(g, H.from_int(0b1111), [Vector2i(0, 0), Vector2i(3, 3)]), "", "a tile paired with itself")
	assert_false(H.solvable(g, H.faces(["circle:v:-:a", "circle:v:-:b", "circle:v:-:b", "circle:v:-:a"]), H.from_int(0b1111)),
			"free ends are twins")
	assert_true(H.solvable(g, H.faces(["circle:v:-:a", "tri:v:-:b", "tri:v:-:a", "circle:v:-:b"]), H.from_int(0b1111)))


func test_removal_order_on_a_row_is_forced() -> void:
	var g := _row_of_four()
	var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["row"]))
	assert_eq(H.order_error(g, g.full_mask(), order), "")
	assert_eq(order.size(), 2)
	if order.size() == 2:
		assert_eq(H.norm(order[0]), Vector2i(0, 3), "only the two ends are free at first")
		assert_eq(H.norm(order[1]), Vector2i(1, 2))


func test_removal_order_respects_the_mask() -> void:
	var g := _row_of_four()
	var middle := HalvesFill.removal_order(g, H.from_int(0b0110), _rng(["middle"]))
	assert_eq(middle.size(), 1)
	if middle.size() == 1:
		assert_eq(H.norm(middle[0]), Vector2i(1, 2))
	var ends := HalvesFill.removal_order(g, H.from_int(0b1001), _rng(["ends"]))
	assert_eq(H.order_error(g, H.from_int(0b1001), ends), "")
	assert_eq(ends.size(), 1)


func test_removal_order_on_stacks() -> void:
	var g := _three_stacks()
	for seed_n: int in 5:
		var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["stacks", seed_n]))
		assert_eq(order.size(), 3)
		assert_eq(H.order_error(g, g.full_mask(), order), "", "seed %d" % seed_n)


func test_removal_order_on_real_masks() -> void:
	# Masks of a few plan levels, from 8 tiles up to the 64-tile finale (bit 63).
	for level: int in [1, 6, 12, 20, 30]:
		var g := H.plan_geometry(level)
		assert_gt(g.size(), 0, "level %d mask parsed" % level)
		var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["level", level]))
		assert_eq(order.size(), int(g.size() / 2.0), "level %d: one pair per two tiles" % level)
		assert_eq(H.order_error(g, g.full_mask(), order), "", "level %d" % level)


func test_removal_order_is_empty_when_impossible() -> void:
	var stacked := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	assert_eq(HalvesFill.removal_order(stacked, H.from_int(0b11), _rng(["stacked"])), H.pairs([]),
			"only the top tile is ever free")
	var tower := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2)])
	assert_eq(HalvesFill.removal_order(tower, H.from_int(0b1111), _rng(["tower"])), H.pairs([]),
			"the lone tile must go with the tower top, then the tower is stuck")
	var odd := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0)])
	assert_eq(HalvesFill.removal_order(odd, H.from_int(0b111), _rng(["odd"])), H.pairs([]), "odd tile count")


func test_removal_order_of_mask_zero_is_empty() -> void:
	assert_eq(HalvesFill.removal_order(_row_of_four(), HalvesBits.empty(), _rng(["zero"])), H.pairs([]))


func test_removal_order_same_seed_same_order() -> void:
	var g := H.plan_geometry(12)
	var a := HalvesFill.removal_order(g, g.full_mask(), _rng(["same"]))
	var b := HalvesFill.removal_order(g, g.full_mask(), _rng(["same"]))
	assert_gt(a.size(), 0)
	assert_eq(a, b)


func test_assign_faces_gives_each_pair_one_key_and_both_sides() -> void:
	var order := H.pairs([Vector2i(0, 3), Vector2i(1, 2), Vector2i(4, 5)])
	var keys := PackedInt32Array([0, 0, HalvesFace.pair_from_text("tri:v:dot")])
	var faces := HalvesFill.assign_faces(order, keys, _rng(["assign"]), 8)
	assert_eq(faces.size(), 8)
	var got_keys: Array[int] = []
	for p: Vector2i in order:
		assert_true(HalvesFace.is_valid(faces[p.x]) and HalvesFace.is_valid(faces[p.y]), "valid faces at %s" % p)
		assert_true(HalvesFace.matches(faces[p.x], faces[p.y]), "pair %s matches" % p)
		got_keys.append(HalvesFace.pair_key(faces[p.x]))
	got_keys.sort()
	assert_eq(got_keys, H.sorted_ints(keys), "the key multiset is kept")
	assert_eq(faces[6], -1, "tiles not in the order get -1")
	assert_eq(faces[7], -1)


func test_assign_faces_shuffles_keys_and_sides() -> void:
	var order := H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)])
	var dot := HalvesFace.pair_from_text("tri:v:dot")
	var keys := PackedInt32Array([0, 0, dot])
	var tile0_sides := {}
	var pair0_keys := {}
	for seed_n: int in 24:
		var faces := HalvesFill.assign_faces(order, keys, _rng(["sides", seed_n]), 6)
		tile0_sides[HalvesFace.side(faces[0])] = true
		pair0_keys[HalvesFace.pair_key(faces[0])] = true
	assert_eq(tile0_sides.size(), 2, "which tile of a pair is side A is random")
	assert_true(pair0_keys.has(dot) and pair0_keys.has(0), "pair keys are shuffled")


func test_assign_faces_same_seed_same_faces() -> void:
	var order := H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)])
	var keys := PackedInt32Array([0, 8, 20])
	assert_eq(HalvesFill.assign_faces(order, keys, _rng(["af"]), 6),
			HalvesFill.assign_faces(order, keys, _rng(["af"]), 6))


func test_deal_solution_replays_as_matches() -> void:
	for level: int in [3, 12]:
		var g := H.plan_geometry(level)
		var keys := H.plan_keys(level, g.size())
		var dealt := HalvesFill.deal(g, keys, _rng(["deal", level]))
		assert_true(dealt.has("faces") and dealt.has("solution"), "level %d dealt" % level)
		if not dealt.has("faces"):
			continue
		var faces: PackedInt32Array = dealt["faces"]
		var solution: Array = dealt["solution"]
		assert_eq(faces.size(), g.size())
		for f: int in faces:
			assert_true(HalvesFace.is_valid(f), "level %d face %d" % [level, f])
		assert_eq(solution.size(), int(g.size() / 2.0))
		assert_eq(H.order_error(g, g.full_mask(), solution), "", "level %d solution is a removal order" % level)
		assert_eq(H.side_a_keys(g.full_mask(), faces), H.sorted_ints(keys), "level %d keys" % level)
		assert_eq(H.replay_error(HalvesState.new(g, faces), solution), "", "level %d" % level)


func test_deal_same_seed_same_board() -> void:
	var g := H.plan_geometry(6)
	var keys := H.plan_keys(6, g.size())
	var a := HalvesFill.deal(g, keys, _rng(["same deal"]))
	var b := HalvesFill.deal(g, keys, _rng(["same deal"]))
	assert_eq(a.get("faces"), b.get("faces"))
	assert_eq(a.get("solution"), b.get("solution"))


func test_deal_on_an_impossible_board_is_empty() -> void:
	var stacked := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	assert_eq(HalvesFill.deal(stacked, PackedInt32Array([0]), _rng(["no deal"])), {})


func test_remaining_pair_keys_are_side_a_keys_sorted() -> void:
	# Keys by hand: tri:v:- = 8, circle:v:- = 0, square:h:- = 20.
	var s := H.state(H.column(6), ["tri:v:-:a", "circle:v:-:b", "circle:v:-:a", "tri:v:-:b", "square:h:-:a", "square:h:-:b"])
	assert_eq(HalvesFill.remaining_pair_keys(s), PackedInt32Array([0, 8, 20]))
	assert_eq(s.try_pair(1, 2), HalvesState.Result.MATCH)
	assert_eq(HalvesFill.remaining_pair_keys(s), PackedInt32Array([8, 20]))


func test_shuffle_of_a_clear_board_is_empty() -> void:
	var s := H.state(H.column(2), ["circle:v:-:a", "circle:v:-:b"])
	assert_eq(s.try_pair(0, 1), HalvesState.Result.MATCH)
	assert_eq(HalvesFill.shuffle(s, H.pairs([Vector2i(0, 1)]), _rng(["clear"])), {})


func _check_shuffle(s: HalvesState, result: Dictionary, label: String) -> void:
	assert_true(result.has("remaining") and result.has("faces") and result.has("reseated"), label + ": keys")
	if not result.has("faces"):
		return
	var g := s.geometry
	var rem: PackedInt64Array = result["remaining"]
	var faces: PackedInt32Array = result["faces"]
	assert_eq(faces.size(), g.size(), label + ": one face per tile")
	assert_eq(HalvesBits.count(rem), s.tiles_left(), label + ": same number of tiles")
	assert_eq(H.faces_on(rem, faces), H.faces_on(s.remaining, s.faces), label + ": same faces, new places")
	for i: int in g.size():
		if not HalvesBits.has(rem, i):
			assert_eq(faces[i], -1, label + ": tile %d is off the board" % i)
	assert_true(H.solvable(g, faces, rem), label + ": the shuffled board can be cleared")


func test_shuffle_keeps_positions_that_can_still_be_cleared() -> void:
	var g := H.plan_geometry(2)
	var dealt := HalvesFill.deal(g, H.plan_keys(2, g.size()), _rng(["shuffle deal"]))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var solution := H.pairs(dealt["solution"])
	var s := HalvesState.new(g, dealt["faces"])
	for step: int in 2:
		assert_eq(s.try_pair(solution[step].x, solution[step].y), HalvesState.Result.MATCH)
	var before_remaining := s.remaining.duplicate()
	var before_faces := s.faces.duplicate()
	var result := HalvesFill.shuffle(s, solution, _rng(["shuffle"]))
	_check_shuffle(s, result, "same positions")
	assert_eq(result.get("reseated"), false, "the rest of the solution proves these positions clear")
	assert_eq(result.get("remaining"), before_remaining)
	assert_eq(s.remaining, before_remaining, "shuffle returns a board; it does not change the state")
	assert_eq(s.faces, before_faces)


func test_shuffle_same_seed_same_result() -> void:
	var g := H.plan_geometry(3)
	var dealt := HalvesFill.deal(g, H.plan_keys(3, g.size()), _rng(["shuffle seed deal"]))
	if dealt.is_empty():
		fail_test("no deal")
		return
	var solution := H.pairs(dealt["solution"])
	var s := HalvesState.new(g, dealt["faces"])
	s.try_pair(solution[0].x, solution[0].y)
	assert_eq(HalvesFill.shuffle(s, solution, _rng(["shuffle seed"])),
			HalvesFill.shuffle(s, solution, _rng(["shuffle seed"])))


func test_shuffle_reseats_when_the_positions_cannot_be_cleared() -> void:
	# A valid solution for _three_stacks: tops 3+4, then 5+0, then 1+2.
	var g := _three_stacks()
	var solution := H.pairs([Vector2i(3, 4), Vector2i(5, 0), Vector2i(1, 2)])
	assert_eq(H.order_error(g, g.full_mask(), solution), "", "test setup: the solution is valid")
	var s := HalvesState.new(g, H.faces(["tri:v:-:b", "square:v:-:a", "square:v:-:b", "circle:v:-:a", "circle:v:-:b", "tri:v:-:a"]))
	# Leave only tile 0 and tile 3 (the tile on top of it): no removal order exists for that.
	s.apply_deal(H.mask_of([0, 3]), H.faces(["circle:v:-:b", "", "", "circle:v:-:a", "", ""]))
	var result := HalvesFill.shuffle(s, solution, _rng(["reseat"]))
	_check_shuffle(s, result, "reseated")
	assert_eq(result.get("reseated"), true)
	# k = (6 - 2) / 2 = 2 pairs of the solution gone: 3, 4, 5, 0. Left: tiles 1 and 2.
	assert_eq(result.get("remaining"), H.mask_of([1, 2]))


func test_shuffle_reseats_a_dealt_board_down_to_one_stack() -> void:
	# A real deal, then everything gone except one tile and the tile straight on top of it.
	var level := 2
	var g := H.plan_geometry(level)
	var dealt := HalvesFill.deal(g, H.plan_keys(level, g.size()), _rng(["reseat deal"]))
	assert_false(dealt.is_empty())
	if dealt.is_empty():
		return
	var bottom := -1
	var top := -1
	for i: int in g.size():
		var j := g.positions.find(g.positions[i] + Vector3i(0, 0, 1))
		if j != -1:
			bottom = i
			top = j
			break
	if bottom == -1:
		pending("the level %d mask has no stacked tiles" % level)
		return
	var solution := H.pairs(dealt["solution"])
	var s := HalvesState.new(g, dealt["faces"])
	var faces := PackedInt32Array()
	faces.resize(g.size())
	faces.fill(-1)
	faces[bottom] = HalvesFace.from_text("square:v:-:b")
	faces[top] = HalvesFace.from_text("square:v:-:a")
	s.apply_deal(H.mask_of([bottom, top]), faces)
	var result := HalvesFill.shuffle(s, solution, _rng(["reseat dealt"]))
	_check_shuffle(s, result, "reseated deal")
	assert_eq(result.get("reseated"), true)
	# k = (size - 2) / 2: every pair of the solution but the last is gone.
	var last: Vector2i = solution[solution.size() - 1]
	assert_eq(result.get("remaining"), H.mask_of([last.x, last.y]))


func test_shuffle_rng_uses_the_documented_seed() -> void:
	for args: Array in [[1, 0], [1, 1], [17, 3]]:
		var got := HalvesFill.shuffle_rng(args[0], args[1])
		var want := SeedService.make_rng(["halves", args[0], "shuffle", args[1]], HalvesConfig.GEN_VERSION)
		assert_eq(got.seed, want.seed, "level %d, shuffle %d" % args)
		assert_eq(got.randi(), want.randi())
	assert_ne(HalvesFill.shuffle_rng(1, 0).seed, HalvesFill.shuffle_rng(1, 1).seed)
