extends GutTest
## Traps (v2): HalvesFill.trap_links / assign_faces_trapped / live_traps / deal_v2, HalvesBot's
## is_trap_move, WARY play and rate with wary_win, and HalvesSolver's hint fallback. Written from
## docs/HALVES.md alone. assign_faces_trapped is re-derived exactly only where the doc leaves no choice.

const H := preload("res://tests/halves_helpers.gd")
const P := HalvesBot.Policy


func _rng(parts: Array) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_traps"] + parts, 2)


## The trap board of test_halves_solver.gd, ids in (z, y, x) order:
##   0 (0,0,0) tri a   \ both under tile 4 (a bridge at (1,0,1))
##   1 (2,0,0) tri b   /
##   2 (0,4,0) circle b  under tile 5
##   3 (0,8,0) circle b  alone
##   4 (1,0,1) circle a  bridge
##   5 (0,4,1) circle a  on tile 2
## Free matches at the start: (3,4), the trap (it leaves 5 on its only mate 2), and (3,5).
func _trap_state() -> HalvesState:
	return H.state(_trap_points(), ["tri:v:-:a", "tri:v:-:b", "circle:v:-:b", "circle:v:-:b", "circle:v:-:a", "circle:v:-:a"])


func _trap_points() -> Array:
	return [Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0), Vector3i(1, 0, 1), Vector3i(0, 4, 1)]


## Its solution: (3,5), (2,4), (0,1).
func _trap_order() -> Array[Vector2i]:
	return H.pairs([Vector2i(3, 5), Vector2i(2, 4), Vector2i(0, 1)])


## Four two-tile stacks in a row with gaps: bottoms 0-3 at x 0, 4, 8, 12; tops 4-7 straight on them.
## Order (4,5), (0,6), (2,7), (1,3) is a removal order. Links by hand (S_k = tiles left before step k):
##   q 0: 4 covers 0 (step 1), the other tile 6 is free in S_0 -> (0,1,4,0);
##        5 covers 1 (step 3), but the other tile 3 is under 7 in S_0 -> none.
##   q 1: 6 covers 2 (step 2), the other tile 7 is free in S_1 -> (1,2,6,2).
##   q 2: 7 covers 3 (step 3), the other tile 1 is free in S_2 (5 is gone) -> (2,3,7,3).
func _four_stacks() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0),
			Vector3i(0, 0, 1), Vector3i(4, 0, 1), Vector3i(8, 0, 1), Vector3i(12, 0, 1)])


func _four_stacks_order() -> Array[Vector2i]:
	return H.pairs([Vector2i(4, 5), Vector2i(0, 6), Vector2i(2, 7), Vector2i(1, 3)])


## Every free pair here is a trap move. Ids in (z, y, x) order:
##   0 (0,0,0) circle a   row left       1 (2,0,0) tri a   row middle   2 (4,0,0) square a  row right
##   3 (0,4,0) circle b   alone          4 (0,8,0) diamond a  under 5   5 (0,8,1) circle b  on 4
## Free: 0, 2, 3, 5. Free matches: (0,3) and (0,5). Both leave tiles and no free match:
## after (0,3) the free tiles are 1, 2, 5 (3 tiles); after (0,5) they are 1, 2, 3, 4 (4 tiles).
func _all_traps_state() -> HalvesState:
	return H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 4, 0), Vector3i(0, 8, 0),
			Vector3i(0, 8, 1)], ["circle:v:-:a", "tri:v:-:a", "square:v:-:a", "circle:v:-:b", "diamond:v:-:a", "circle:v:-:b"])


# --- trap_links ---


func test_trap_links_on_the_trap_board() -> void:
	# q 0 (3,5): 5 covers 2 (step 1); the other tile 4 is free at the start -> (0,1,5,2).
	# q 1 (2,4): 4 covers 0 and 1 (step 2), but each one's partner is under 4 too -> none.
	var g := _trap_state().geometry
	assert_eq(HalvesFill.trap_links(g, _trap_order()), H.links([Vector4i(0, 1, 5, 2)]))
	var flipped := H.pairs([Vector2i(5, 3), Vector2i(4, 2), Vector2i(1, 0)])
	assert_eq(HalvesFill.trap_links(g, flipped), H.links([Vector4i(0, 1, 5, 2)]), "the order inside a pair does not matter")


func test_trap_links_on_four_stacks() -> void:
	assert_eq(HalvesFill.trap_links(_four_stacks(), _four_stacks_order()),
			H.links([Vector4i(0, 1, 4, 0), Vector4i(1, 2, 6, 2), Vector4i(2, 3, 7, 3)]))


func test_trap_links_need_the_other_tile_free() -> void:
	# Three stacks: bottoms 0-2 at x 0, 4, 8; tops 3-5 straight on them. Order (5,4), (2,3), (0,1):
	# q 0: 5 covers 2 (step 1), the other tile 3 is free in S_0 -> (0,1,5,2);
	#      4 covers 1 (step 2), but the other tile 0 is under 3 in S_0 -> none.
	# q 1: 3 covers 0 (step 2), the other tile 1 is free in S_1 (4 is gone) -> (1,2,3,0).
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0),
			Vector3i(0, 0, 1), Vector3i(4, 0, 1), Vector3i(8, 0, 1)])
	var order := H.pairs([Vector2i(5, 4), Vector2i(2, 3), Vector2i(0, 1)])
	assert_eq(H.order_error(g, g.full_mask(), order), "", "test setup: a removal order")
	assert_eq(HalvesFill.trap_links(g, order), H.links([Vector4i(0, 1, 5, 2), Vector4i(1, 2, 3, 0)]))


func test_trap_links_sorted_with_two_covering_tiles() -> void:
	# Tile 0 (2,0,0) lies under both 2 (1,0,1) and 3 (3,0,1); tile 1 (8,0,0) is alone.
	# Order (2,3), (0,1): both 2 and 3 cover 0, and 1 is free at the start -> two links, sorted by x.
	var g := H.geometry([Vector3i(2, 0, 0), Vector3i(8, 0, 0), Vector3i(1, 0, 1), Vector3i(3, 0, 1)])
	var order := H.pairs([Vector2i(3, 2), Vector2i(0, 1)])
	assert_eq(H.order_error(g, g.full_mask(), order), "", "test setup: a removal order")
	assert_eq(HalvesFill.trap_links(g, order), H.links([Vector4i(0, 1, 2, 0), Vector4i(0, 1, 3, 0)]))


func test_no_stacking_no_links() -> void:
	var column := H.geometry(H.column(4))
	assert_eq(HalvesFill.trap_links(column, H.pairs([Vector2i(0, 1), Vector2i(2, 3)])), H.links([]))
	var row := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)])
	assert_eq(HalvesFill.trap_links(row, H.pairs([Vector2i(0, 3), Vector2i(1, 2)])), H.links([]))


func test_trap_links_on_a_dealt_board_match_the_definition() -> void:
	var g := H.plan_geometry(9)
	var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["links order"]))
	assert_gt(order.size(), 0)
	var want: Array[Vector4i] = []
	var s_k: Array[int] = []
	var rem := g.full_mask()
	for k: int in order.size():
		s_k.append(rem)
		rem &= ~((1 << order[k].x) | (1 << order[k].y))
	for q: int in order.size():
		for p: int in range(q + 1, order.size()):
			for x: int in [order[q].x, order[q].y]:
				for y: int in [order[p].x, order[p].y]:
					var other := order[p].x + order[p].y - y
					if (g.cover[y] & (1 << x)) != 0 and g.is_free(other, s_k[q]):
						want.append(Vector4i(q, p, x, y))
	want.sort()
	assert_eq(HalvesFill.trap_links(g, order), want)


# --- live_traps ---


func test_live_traps_by_hand() -> void:
	var s := _trap_state()
	assert_eq(HalvesFill.live_traps(s.geometry, _trap_order(), s.faces), 1, "5 and 2 are mates, so are 3 and 4")
	var safe := H.faces(["tri:v:-:a", "tri:v:-:b", "square:v:-:a", "circle:v:-:a", "square:v:-:b", "circle:v:-:b"])
	assert_eq(HalvesFill.live_traps(s.geometry, _trap_order(), safe), 0, "5 and 2 are not mates")
	var g := _four_stacks()
	var order := _four_stacks_order()
	# Link (0,1,4,0) needs 4~0 and 5~6; (1,2,6,2) needs 6~2 and 0~7; (2,3,7,3) needs 7~3 and 2~1.
	# With the solution's 4~5, 0~6, 2~7, 1~3, all circles: 4 a, 5 b, 0 b, 6 a, 2 b, 7 a, 3 b, 1 a.
	var all_live := H.faces(["circle:v:-:b", "circle:v:-:a", "circle:v:-:b", "circle:v:-:b",
			"circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "circle:v:-:a"])
	assert_eq(H.replay_error(HalvesState.new(g, all_live), order), "", "test setup: the order is a solution")
	assert_eq(HalvesFill.live_traps(g, order, all_live), 3)
	var one_live := H.faces(["circle:v:-:b", "tri:v:-:a", "square:v:-:a", "tri:v:-:b",
			"circle:v:-:a", "circle:v:-:b", "circle:v:-:a", "square:v:-:b"])
	assert_eq(H.replay_error(HalvesState.new(g, one_live), order), "", "test setup: the order is a solution")
	assert_eq(HalvesFill.live_traps(g, order, one_live), 1, "only (0,1,4,0)")
	var none := H.faces(["tri:v:-:b", "square:v:-:a", "diamond:v:-:a", "square:v:-:b",
			"circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "diamond:v:-:b"])
	assert_eq(HalvesFill.live_traps(g, order, none), 0)


# --- assign_faces_trapped ---


## docs/HALVES.md section 2, steps 1-3, for keys where every value has exactly two copies or
## trap_rate is 0: then "which two copies are used" and "the first such key value" leave no choice.
## The links are shuffled through an index array with shuffle_ints (the same Fisher-Yates swaps).
func _expected_trapped(g: HalvesGeometry, order: Array[Vector2i], pair_keys: PackedInt32Array,
		rng: RandomNumberGenerator, tile_count: int, trap_rate: float) -> PackedInt32Array:
	var links := HalvesFill.trap_links(g, order)
	var index := PackedInt32Array()
	for i: int in links.size():
		index.append(i)
	HalvesFill.shuffle_ints(index, rng)
	var keys := pair_keys.duplicate()
	HalvesFill.shuffle_ints(keys, rng)
	var faces := PackedInt32Array()
	faces.resize(tile_count)
	faces.fill(-1)
	var used: Array[bool] = []
	used.resize(keys.size())
	used.fill(false)
	var done: Array[bool] = []
	done.resize(order.size())
	done.fill(false)
	var wanted := roundi(trap_rate * order.size() / 2.0)
	var made := 0
	for i: int in index:
		if made >= wanted:
			break
		var link := links[i]
		if done[link.x] or done[link.y]:
			continue
		var value := -1
		for j: int in keys.size():
			if not used[j] and _unused_copies(keys, used, keys[j]) >= 2:
				value = keys[j]
				break
		if value == -1:
			continue
		var marked := 0
		for j: int in keys.size():
			if marked < 2 and not used[j] and keys[j] == value:
				used[j] = true
				marked += 1
		var s := rng.randi_range(0, 1)
		var other_q := order[link.x].x + order[link.x].y - link.z
		var other_p := order[link.y].x + order[link.y].y - link.w
		faces[link.z] = (value << 1) | s
		faces[other_q] = (value << 1) | (1 - s)
		faces[link.w] = (value << 1) | (1 - s)
		faces[other_p] = (value << 1) | s
		done[link.x] = true
		done[link.y] = true
		made += 1
	for k: int in order.size():
		if done[k]:
			continue
		var value := -1
		for j: int in keys.size():
			if not used[j]:
				used[j] = true
				value = keys[j]
				break
		var s := rng.randi_range(0, 1)
		faces[order[k].x] = (value << 1) | s
		faces[order[k].y] = (value << 1) | (1 - s)
	return faces


func _unused_copies(keys: PackedInt32Array, used: Array[bool], value: int) -> int:
	var n := 0
	for j: int in keys.size():
		if not used[j] and keys[j] == value:
			n += 1
	return n


func _check_trapped(g: HalvesGeometry, order: Array[Vector2i], keys: PackedInt32Array, faces: PackedInt32Array,
		label: String) -> void:
	assert_eq(faces.size(), g.size(), label + ": one face per tile")
	var got_keys: Array[int] = []
	for k: int in order.size():
		var p := order[k]
		assert_true(HalvesFace.is_valid(faces[p.x]) and HalvesFace.is_valid(faces[p.y]), label + ": valid faces at step %d" % k)
		assert_true(HalvesFace.matches(faces[p.x], faces[p.y]), label + ": step %d's tiles are mates" % k)
		got_keys.append(HalvesFace.pair_key(faces[p.x]))
	got_keys.sort()
	assert_eq(got_keys, H.sorted_ints(keys), label + ": every pair key used exactly as given")
	assert_eq(H.replay_error(HalvesState.new(g, faces), order), "", label + ": the order is a solution")


func test_assign_faces_trapped_keeps_keys_and_solution() -> void:
	for level: int in [5, 9, 13]:
		var g := H.plan_geometry(level)
		var keys := H.plan_keys(level, g.size())
		var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["order", level]))
		if order.is_empty():
			fail_test("level %d: no order" % level)
			continue
		for rate: float in [0.0, 0.3, 1.0]:
			var faces := HalvesFill.assign_faces_trapped(g, order, keys, _rng(["faces", level, rate]), g.size(), rate)
			_check_trapped(g, order, keys, faces, "level %d rate %.1f" % [level, rate])
			assert_eq(HalvesFill.assign_faces_trapped(g, order, keys, _rng(["faces", level, rate]), g.size(), rate), faces,
					"level %d rate %.1f: same seed, same faces" % [level, rate])


func test_trap_rate_zero_makes_no_deliberate_trap() -> void:
	# With rate 0 the links are only shuffled (rng advanced), then every step takes the next key in order.
	var cases: Array = [[_trap_state().geometry, _trap_order(), H.round_robin(["circle:v:-", "tri:v:-"], 3)]]
	var g9 := H.plan_geometry(9)
	var order9 := HalvesFill.removal_order(g9, g9.full_mask(), _rng(["order", 9]))
	cases.append([g9, order9, H.plan_keys(9, g9.size())])
	for c: Array in cases:
		var g: HalvesGeometry = c[0]
		var order: Array[Vector2i] = c[1]
		var keys: PackedInt32Array = c[2]
		for seed_n: int in 3:
			var got := HalvesFill.assign_faces_trapped(g, order, keys, _rng(["zero", seed_n]), g.size(), 0.0)
			var want := _expected_trapped(g, order, keys, _rng(["zero", seed_n]), g.size(), 0.0)
			_check_trapped(g, order, keys, got, "%d tiles, seed %d" % [g.size(), seed_n])
			assert_eq(got, want, "%d tiles, seed %d: the doc's rng order with no link used" % [g.size(), seed_n])


func test_full_trap_rate_on_four_stacks_follows_the_doc() -> void:
	# Keys A, A, B, B: every value has exactly two copies. wanted = roundi(1.0 * 4 / 2) = 2.
	var g := _four_stacks()
	var order := _four_stacks_order()
	var keys := PackedInt32Array([HalvesFace.pair_from_text("circle:v:-"), HalvesFace.pair_from_text("circle:v:-"),
			HalvesFace.pair_from_text("tri:v:-"), HalvesFace.pair_from_text("tri:v:-")])
	for seed_n: int in 12:
		var got := HalvesFill.assign_faces_trapped(g, order, keys, _rng(["four", seed_n]), g.size(), 1.0)
		var want := _expected_trapped(g, order, keys, _rng(["four", seed_n]), g.size(), 1.0)
		_check_trapped(g, order, keys, got, "seed %d" % seed_n)
		assert_eq(got, want, "seed %d: the doc's steps 1-3" % seed_n)
		assert_gte(HalvesFill.live_traps(g, order, got), 1, "seed %d: the first link is always taken" % seed_n)


func test_a_high_trap_rate_makes_live_traps_on_stacked_boards() -> void:
	# Every plan level here has more pairs than types, so some key has >= 2 copies; when a link exists,
	# the first shuffled link is always taken and is live by construction.
	for level: int in [5, 9, 13]:
		var g := H.plan_geometry(level)
		var keys := H.plan_keys(level, g.size())
		var order := HalvesFill.removal_order(g, g.full_mask(), _rng(["order", level]))
		if order.is_empty():
			fail_test("level %d: no order" % level)
			continue
		var has_copies := false
		var seen := {}
		for k: int in keys:
			has_copies = has_copies or seen.has(k)
			seen[k] = true
		if HalvesFill.trap_links(g, order).is_empty() or not has_copies:
			continue
		for seed_n: int in 4:
			var faces := HalvesFill.assign_faces_trapped(g, order, keys, _rng(["high", level, seed_n]), g.size(), 1.0)
			assert_gte(HalvesFill.live_traps(g, order, faces), 1, "level %d seed %d" % [level, seed_n])


func test_no_copies_no_trap() -> void:
	# Three different keys: no value has two copies, so no link can be used even at rate 1.
	var s := _trap_state()
	var keys := PackedInt32Array([HalvesFace.pair_from_text("circle:v:-"), HalvesFace.pair_from_text("tri:v:-"),
			HalvesFace.pair_from_text("square:v:-")])
	for seed_n: int in 4:
		var faces := HalvesFill.assign_faces_trapped(s.geometry, _trap_order(), keys, _rng(["distinct", seed_n]), 6, 1.0)
		_check_trapped(s.geometry, _trap_order(), keys, faces, "seed %d" % seed_n)
		assert_eq(HalvesFill.live_traps(s.geometry, _trap_order(), faces), 0, "seed %d" % seed_n)


func test_shuffle_ints_is_a_seeded_permutation() -> void:
	var a := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
	var b := a.duplicate()
	HalvesFill.shuffle_ints(a, _rng(["perm"]))
	HalvesFill.shuffle_ints(b, _rng(["perm"]))
	assert_eq(a, b, "same rng, same order")
	assert_eq(H.sorted_ints(a), H.sorted_ints(PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])), "a permutation")


# --- deal_v2 ---


func _check_deal_v2(g: HalvesGeometry, keys: PackedInt32Array, dealt: Dictionary, label: String) -> void:
	for k: String in ["faces", "solution", "features", "traps"]:
		assert_true(dealt.has(k), label + ": has '%s'" % k)
	if not dealt.has("faces") or not dealt.has("solution") or not dealt.has("features"):
		return
	var faces: PackedInt32Array = dealt["faces"]
	var solution := H.pairs(dealt["solution"])
	var features: Dictionary = dealt["features"]
	assert_eq(faces.size(), g.size(), label)
	assert_eq(solution.size(), int(g.size() / 2.0), label)
	assert_eq(H.side_a_keys(g.full_mask(), faces), H.sorted_ints(keys), label + ": pair keys")
	var errors := HalvesFeatures.validate(g, features, solution)
	assert_true(errors.is_empty(), label + ": features validate: " + ", ".join(errors))
	var gf := g.with_features(features)
	assert_eq(H.order_error(gf, gf.full_mask(), solution), "", label + ": the solution is a removal order under the features")
	assert_eq(H.replay_error(HalvesState.new(gf, faces), solution), "", label + ": the solution replays")
	assert_eq(dealt.get("traps"), HalvesFill.live_traps(g, solution, faces), label + ": traps = live_traps")


func test_deal_v2_on_plan_boards() -> void:
	var spec := {"key_pairs": 1, "locked": 2, "frost": 2, "mist": 2, "gold": 2}
	for level: int in [3, 9, 13]:
		var g := H.plan_geometry(level)
		var keys := H.plan_keys(level, g.size())
		for rate: float in [0.0, 0.5]:
			var dealt := HalvesFill.deal_v2(g, keys, _rng(["v2", level, rate]), rate, spec.duplicate())
			assert_false(dealt.is_empty(), "level %d dealt" % level)
			_check_deal_v2(g, keys, dealt, "level %d rate %.1f" % [level, rate])
		var plain := HalvesFill.deal_v2(g, keys, _rng(["v2 plain", level]), 0.3, {})
		_check_deal_v2(g, keys, plain, "level %d without features" % level)
		assert_eq(plain.get("features"), {}, "level %d: an empty spec places nothing" % level)


func test_deal_v2_is_order_then_trapped_faces_then_place_on_one_rng() -> void:
	var spec := {"key_pairs": 1, "locked": 2, "frost": 1, "mist": 2, "gold": 1}
	for level: int in [6, 13]:
		var g := H.plan_geometry(level)
		var keys := H.plan_keys(level, g.size())
		var rng := _rng(["compose", level])
		var order := HalvesFill.removal_order(g, g.full_mask(), rng)
		var faces := HalvesFill.assign_faces_trapped(g, order, keys, rng, g.size(), 0.4)
		var features := HalvesFeatures.place(g, order, faces, spec.duplicate(), rng)
		var dealt := HalvesFill.deal_v2(g, keys, _rng(["compose", level]), 0.4, spec.duplicate())
		assert_eq(dealt.get("solution"), order, "level %d solution" % level)
		assert_eq(dealt.get("faces"), faces, "level %d faces" % level)
		assert_eq(H.js(dealt.get("features")), H.js(features), "level %d features" % level)
		assert_eq(dealt.get("traps"), HalvesFill.live_traps(g, order, faces), "level %d traps" % level)
		# deal uses the same removal_order call first, so the same seed gives the same solution.
		var v1 := HalvesFill.deal(g, keys, _rng(["compose", level]))
		assert_eq(v1.get("solution"), order, "level %d: same order as deal" % level)


func test_deal_v2_same_seed_same_board() -> void:
	var g := H.plan_geometry(9)
	var keys := H.plan_keys(9, g.size())
	var spec := {"mist": 3, "gold": 2}
	var a := HalvesFill.deal_v2(g, keys, _rng(["same"]), 0.5, spec.duplicate())
	var b := HalvesFill.deal_v2(g, keys, _rng(["same"]), 0.5, spec.duplicate())
	assert_eq(a.get("faces"), b.get("faces"))
	assert_eq(a.get("solution"), b.get("solution"))
	assert_eq(H.js(a.get("features")), H.js(b.get("features")))
	assert_eq(a.get("traps"), b.get("traps"))


func test_deal_v2_wrong_key_count_or_no_order_is_empty() -> void:
	var g := H.plan_geometry(3)
	var keys := H.plan_keys(3, g.size())
	var short := keys.slice(0, keys.size() - 1)
	var long := keys.duplicate()
	long.append(keys[0])
	assert_eq(HalvesFill.deal_v2(g, short, _rng(["short"]), 0.0, {}), {}, "one key short")
	assert_eq(HalvesFill.deal_v2(g, long, _rng(["long"]), 0.0, {}), {}, "one key too many")
	var stacked := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	assert_eq(HalvesFill.deal_v2(stacked, PackedInt32Array([0]), _rng(["stacked"]), 0.0, {}), {}, "no removal order")


# --- HalvesBot v2 ---


func test_is_trap_move_on_the_trap_board() -> void:
	var s := _trap_state()
	assert_true(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(3, 4)), "5 is left on its last mate 2")
	assert_true(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(4, 3)), "either tap order")
	assert_false(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(3, 5)))
	assert_eq(s.remaining, 0b111111, "is_trap_move does not change the board")
	# After (3,5): (2,4) leaves the tri pair side by side, free.
	assert_false(HalvesBot.is_trap_move(s.geometry, s.faces, H.mask_of([0, 1, 2, 4]), Vector2i(2, 4)))


func test_is_trap_move_when_no_free_pair_is_left() -> void:
	var g := H.geometry(H.column(4))
	var twins := H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:a"])
	assert_true(HalvesBot.is_trap_move(g, twins, 0b1111, Vector2i(0, 1)), "only twins are left")
	var fine := H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b"])
	assert_false(HalvesBot.is_trap_move(g, fine, 0b1111, Vector2i(0, 1)))
	var last := H.faces(["circle:v:-:a", "circle:v:-:b"])
	assert_false(HalvesBot.is_trap_move(H.geometry(H.column(2)), last, 0b11, Vector2i(0, 1)), "clearing the board is never a trap")


func test_is_trap_move_counts_exactly_two_tiles_of_a_key() -> void:
	# 0 (0,0,0) circle b under 5 (0,0,1) circle a; 1 (4,0,0) circle a; 2 (8,0,0) circle b; 3, 4 a tri pair.
	var s := H.state([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0), Vector3i(16, 0, 0),
			Vector3i(0, 0, 1)], ["circle:v:-:b", "circle:v:-:a", "circle:v:-:b", "tri:v:-:a", "tri:v:-:b", "circle:v:-:a"])
	assert_false(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(3, 4)),
			"four circles left: a stacked mate is not a dead end yet")
	assert_true(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(1, 2)),
			"the last two circles are 5 on top of 0")
	assert_false(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, Vector2i(2, 5)), "0 and 1 are left side by side")


func test_every_pair_is_a_trap_on_the_all_traps_board() -> void:
	var s := _all_traps_state()
	assert_eq(s.free_pairs(), H.pairs([Vector2i(0, 3), Vector2i(0, 5)]), "test setup")
	for p: Vector2i in s.free_pairs():
		assert_true(HalvesBot.is_trap_move(s.geometry, s.faces, s.remaining, p), "%s" % p)


func test_wary_clears_the_trap_board() -> void:
	# WARY never takes (3,4). Boards seen: the start (2 free pairs, 1 decoy: 4 and 5 are twins),
	# after (3,5) (1 pair), after (2,4) (1 pair). free_pairs = 4 / 3, decoy = (1/2 + 0 + 0) / 3 = 1/6.
	var s := _trap_state()
	for n: int in 8:
		var r := HalvesBot.play(s.geometry, s.faces, _rng(["wary", n]), P.WARY)
		assert_eq(r.get("cleared"), true, "seed %d" % n)
		assert_eq(r.get("steps"), 3)
		assert_almost_eq(float(r.get("free_pairs", -1.0)), 4.0 / 3.0, 1e-6)
		assert_almost_eq(float(r.get("decoy", -1.0)), 1.0 / 6.0, 1e-6)


func test_wary_falls_back_to_trap_moves() -> void:
	# Both free pairs are traps: WARY takes one of them and is stuck. Boards seen: the start (2 pairs,
	# 1 decoy: 3 and 5 are twins -> 1/2) and the stuck board (0 pairs, no decoy among different shapes).
	var s := _all_traps_state()
	for n: int in 6:
		var r := HalvesBot.play(s.geometry, s.faces, _rng(["fallback", n]), P.WARY)
		assert_eq(r.get("cleared"), false, "seed %d" % n)
		assert_eq(r.get("steps"), 1)
		assert_almost_eq(float(r.get("free_pairs", -1.0)), 1.0, 1e-6)
		assert_almost_eq(float(r.get("decoy", -1.0)), 0.25, 1e-6)


func test_rate_of_the_trap_board_has_wary_win() -> void:
	var s := _trap_state()
	var r := HalvesBot.rate(s.geometry, s.faces, ["test_halves_traps", "trap"], 12)
	assert_true(r.has("wary_win"))
	assert_almost_eq(float(r.get("wary_win", -1.0)), 1.0, 1e-6, "WARY always clears it")
	assert_almost_eq(float(r.get("careful_win", -1.0)), 0.0, 1e-6, "CAREFUL always takes the trap")


func test_rate_is_random_then_careful_then_wary_on_one_rng() -> void:
	var g := H.plan_geometry(5)
	var dealt := HalvesFill.deal_v2(g, H.plan_keys(5, g.size()), _rng(["rate deal"]), 0.5, {})
	if dealt.is_empty():
		fail_test("no deal")
		return
	var faces: PackedInt32Array = dealt["faces"]
	var parts: Array = ["test_halves_traps", "rate", 5]
	var runs := 6
	var got := HalvesBot.rate(g, faces, parts, runs)
	var rng := SeedService.make_rng(parts + ["rate"], HalvesConfig.GEN_VERSION)
	var wins := {P.RANDOM: 0, P.CAREFUL: 0, P.WARY: 0}
	var free_sum := 0.0
	var decoy_sum := 0.0
	for policy: HalvesBot.Policy in [P.RANDOM, P.CAREFUL, P.WARY]:
		for i: int in runs:
			var r := HalvesBot.play(g, faces, rng, policy)
			if r.get("cleared", false):
				wins[policy] += 1
			if policy == P.RANDOM:
				free_sum += float(r.get("free_pairs", 0.0))
				decoy_sum += float(r.get("decoy", 0.0))
	var random_win := float(wins[P.RANDOM]) / runs
	var avg_free := free_sum / runs
	var decoy := decoy_sum / runs
	assert_eq(got.get("runs"), runs)
	assert_almost_eq(float(got.get("random_win", -1.0)), random_win, 1e-9)
	assert_almost_eq(float(got.get("careful_win", -1.0)), float(wins[P.CAREFUL]) / runs, 1e-9)
	assert_almost_eq(float(got.get("wary_win", -1.0)), float(wins[P.WARY]) / runs, 1e-9)
	assert_almost_eq(float(got.get("avg_free_pairs", -1.0)), avg_free, 1e-9)
	assert_almost_eq(float(got.get("decoy_exposure", -1.0)), decoy, 1e-9)
	assert_almost_eq(float(got.get("difficulty", -1.0)), HalvesBot.difficulty(random_win, decoy, avg_free), 1e-9)
	assert_eq(HalvesBot.rate(g, faces, parts, runs), got, "same seed parts, same rating")


# --- HalvesSolver v2: the hint fallback ---


func test_most_freeing_pair() -> void:
	var s := _trap_state()
	assert_eq(HalvesSolver.most_freeing_pair(s.geometry, s.remaining, H.pairs([Vector2i(3, 4), Vector2i(3, 5)])),
			Vector2i(3, 4), "it frees 0 and 1: three free tiles against two")
	var w := _all_traps_state()
	assert_eq(HalvesSolver.most_freeing_pair(w.geometry, w.remaining, H.pairs([Vector2i(0, 3), Vector2i(0, 5)])),
			Vector2i(0, 5), "four free tiles against three")
	var column := H.geometry(H.column(4))
	assert_eq(HalvesSolver.most_freeing_pair(column, 0b1111, H.pairs([Vector2i(2, 3), Vector2i(0, 1)])),
			Vector2i(2, 3), "a tie keeps the earliest in the list")


func test_hint_without_budget_skips_trap_moves() -> void:
	var s := _trap_state()
	assert_eq(HalvesSolver.solve(s.geometry, s.faces, s.remaining, 0).get("status"), HalvesSolver.Status.UNKNOWN,
			"test setup: a budget of 0 expands nothing")
	assert_eq(H.norm(HalvesSolver.hint(s, 0)), Vector2i(3, 5), "(3,4) frees more but is a trap move")
	assert_eq(s.remaining, 0b111111, "hint does not change the board")


func test_hint_without_budget_when_every_pair_is_a_trap() -> void:
	var s := _all_traps_state()
	assert_eq(H.norm(HalvesSolver.hint(s, 0)), Vector2i(0, 5), "the most freeing pair of all")


func test_hint_without_budget_and_without_a_free_pair() -> void:
	var stuck := H.state([Vector3i(0, 0, 0), Vector3i(2, 0, 0)], ["circle:v:-:a", "circle:v:-:a"])
	assert_eq(HalvesSolver.hint(stuck, 0), Vector2i(-1, -1))
