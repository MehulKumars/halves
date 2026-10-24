extends GutTest
## HalvesBits (v3): tile sets as two 64-bit words. Every function, the out-of-range rule, "never
## changes its arguments" (set_bit / clear_bit change in place), the 63/64/127 edges, use as a
## Dictionary key, and boards of more than 64 tiles (free tiles and HalvesState with ids >= 64).
## Written from docs/HALVES.md (contract v3) alone, in a separate session from the implementation.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result
const TOP := 1 << 63                      # bit 63 of a word: the word is negative
const LOW63 := 0x7FFFFFFFFFFFFFFF         # bits 0..62


func _words(a: int, b: int) -> PackedInt64Array:
	return PackedInt64Array([a, b])


# --- layout and constructors ---


func test_constants() -> void:
	assert_eq(HalvesBits.WORDS, 2)
	assert_eq(HalvesBits.MAX, 128)
	assert_eq(HalvesGeometry.MAX_TILES, 128, "(v3; v2: 64)")


func test_empty_is_two_zero_words() -> void:
	var e := HalvesBits.empty()
	assert_eq(e.size(), 2)
	assert_eq(e, _words(0, 0))
	assert_true(HalvesBits.is_empty(e))
	assert_eq(HalvesBits.count(e), 0)
	assert_eq(HalvesBits.first(e), -1)
	assert_eq(HalvesBits.ids(e), PackedInt32Array())


func test_empty_returns_a_new_array_each_time() -> void:
	var a := HalvesBits.empty()
	HalvesBits.set_bit(a, 3)
	assert_eq(HalvesBits.empty(), _words(0, 0), "changing one empty set does not change the next")


func test_tile_i_is_bit_i_and_63_of_word_i_shr_6() -> void:
	assert_eq(HalvesBits.of([0]), _words(1, 0))
	assert_eq(HalvesBits.of([5]), _words(32, 0))
	assert_eq(HalvesBits.of([62]), _words(1 << 62, 0))
	assert_eq(HalvesBits.of([63]), _words(TOP, 0), "bit 63 makes word 0 negative")
	assert_eq(HalvesBits.of([64]), _words(0, 1))
	assert_eq(HalvesBits.of([65]), _words(0, 2))
	assert_eq(HalvesBits.of([127]), _words(0, TOP), "bit 127 makes word 1 negative")
	assert_eq(HalvesBits.of([0, 63, 64, 127]), _words(1 | TOP, 1 | TOP))
	assert_true(HalvesBits.of([63])[0] < 0)
	assert_true(HalvesBits.of([127])[1] < 0)


func test_full() -> void:
	assert_eq(HalvesBits.full(0), HalvesBits.empty(), "full(0) is empty")
	assert_eq(HalvesBits.full(1), _words(1, 0))
	assert_eq(HalvesBits.full(3), _words(7, 0))
	assert_eq(HalvesBits.full(63), _words(LOW63, 0))
	assert_eq(HalvesBits.full(64), _words(-1, 0), "tiles 0..63: word 0 all ones")
	assert_eq(HalvesBits.full(65), _words(-1, 1))
	assert_eq(HalvesBits.full(100), _words(-1, (1 << 36) - 1))
	assert_eq(HalvesBits.full(127), _words(-1, LOW63))
	assert_eq(HalvesBits.full(128), _words(-1, -1), "every tile")


func test_full_counts_and_ids_for_every_size() -> void:
	for n: int in range(0, 129):
		var s := HalvesBits.full(n)
		assert_eq(s.size(), 2, "full(%d) has two words" % n)
		assert_eq(HalvesBits.count(s), n, "count(full(%d))" % n)
		var want := PackedInt32Array()
		for i: int in n:
			want.append(i)
		assert_eq(HalvesBits.ids(s), want, "ids(full(%d))" % n)
		assert_eq(HalvesBits.has(s, n), false, "full(%d) stops before tile %d" % [n, n])
		if n > 0:
			assert_true(HalvesBits.has(s, n - 1), "full(%d) has tile %d" % [n, n - 1])


func test_of_takes_ints_and_whole_floats() -> void:
	assert_eq(HalvesBits.of([]), HalvesBits.empty())
	assert_eq(HalvesBits.of([3, 1, 3]), _words(10, 0), "duplicates are fine")
	assert_eq(HalvesBits.of([3.0, 64.0, 127.0]), HalvesBits.of([3, 64, 127]), "JSON numbers are floats")
	var parsed: Variant = JSON.parse_string("[0, 63, 64, 127]")
	assert_eq(HalvesBits.of(parsed as Array), _words(1 | TOP, 1 | TOP), "a list straight from JSON")


func test_of_skips_ids_outside_0_127() -> void:
	assert_eq(HalvesBits.of([-1]), HalvesBits.empty())
	assert_eq(HalvesBits.of([128]), HalvesBits.empty())
	assert_eq(HalvesBits.of([-64, 192, 1000]), HalvesBits.empty(), "no wrap into another word or bit")
	assert_eq(HalvesBits.of([-1, 2, 128, 70, 256]), HalvesBits.of([2, 70]))


func test_of_does_not_change_its_list() -> void:
	var list: Array = [5, 1, 70]
	HalvesBits.of(list)
	assert_eq(list, [5, 1, 70])


# --- has, added, removed ---


func test_has() -> void:
	var s := HalvesBits.of([0, 63, 64, 127])
	for i: int in 128:
		assert_eq(HalvesBits.has(s, i), i in [0, 63, 64, 127], "has(%d)" % i)


func test_has_is_false_outside_0_127() -> void:
	var all := HalvesBits.full(128)
	for i: int in [-1, -64, -128, 128, 129, 191, 192, 256, 1 << 40]:
		assert_false(HalvesBits.has(all, i), "has(full(128), %d)" % i)


func test_added_returns_a_new_set_and_keeps_the_argument() -> void:
	var s := HalvesBits.of([1])
	var keep := s.duplicate()
	var t := HalvesBits.added(s, 64)
	assert_eq(t, HalvesBits.of([1, 64]))
	assert_eq(s, keep, "the argument is unchanged")
	HalvesBits.set_bit(t, 100)
	assert_eq(s, keep, "the result is not the argument")
	assert_eq(HalvesBits.added(s, 1), s, "adding a tile already there")
	var u := HalvesBits.added(s, 1)
	HalvesBits.set_bit(u, 7)
	assert_eq(s, keep, "even when nothing was added, the result is a new array")


func test_removed_returns_a_new_set_and_keeps_the_argument() -> void:
	var s := HalvesBits.of([1, 63, 64, 127])
	var keep := s.duplicate()
	assert_eq(HalvesBits.removed(s, 63), HalvesBits.of([1, 64, 127]))
	assert_eq(HalvesBits.removed(s, 127), HalvesBits.of([1, 63, 64]))
	assert_eq(HalvesBits.removed(s, 5), s, "removing a missing tile")
	assert_eq(s, keep, "the argument is unchanged")
	var t := HalvesBits.removed(s, 5)
	HalvesBits.clear_bit(t, 1)
	assert_eq(s, keep, "the result is not the argument")


func test_added_and_removed_ignore_ids_outside_0_127() -> void:
	var s := HalvesBits.of([0, 127])
	var keep := s.duplicate()
	for i: int in [-1, 128, 192, -65]:
		assert_eq(HalvesBits.added(s, i), keep, "added(%d) leaves the set as it is" % i)
		assert_eq(HalvesBits.removed(s, i), keep, "removed(%d) leaves the set as it is" % i)
	assert_eq(HalvesBits.removed(HalvesBits.full(128), 128), HalvesBits.full(128))
	assert_eq(s, keep)


# --- in place ---


func test_set_bit_and_clear_bit_change_the_set_in_place() -> void:
	var s := HalvesBits.empty()
	HalvesBits.set_bit(s, 63)
	assert_eq(s, _words(TOP, 0))
	HalvesBits.set_bit(s, 64)
	HalvesBits.set_bit(s, 127)
	assert_eq(s, _words(TOP, 1 | TOP))
	HalvesBits.set_bit(s, 127)
	assert_eq(s, _words(TOP, 1 | TOP), "setting twice")
	HalvesBits.clear_bit(s, 63)
	assert_eq(s, _words(0, 1 | TOP))
	HalvesBits.clear_bit(s, 63)
	assert_eq(s, _words(0, 1 | TOP), "clearing a missing tile")
	HalvesBits.clear_bit(s, 127)
	HalvesBits.clear_bit(s, 64)
	assert_true(HalvesBits.is_empty(s))


func test_set_bit_and_clear_bit_ignore_ids_outside_0_127() -> void:
	var s := HalvesBits.of([3])
	for i: int in [-1, 128, 191, 192, -64]:
		HalvesBits.set_bit(s, i)
		assert_eq(s, HalvesBits.of([3]), "set_bit(%d)" % i)
	var all := HalvesBits.full(128)
	for i: int in [-1, 128, 191, 192, -64]:
		HalvesBits.clear_bit(all, i)
		assert_eq(all, HalvesBits.full(128), "clear_bit(%d)" % i)


# --- set algebra ---


func test_union_intersection_minus() -> void:
	var a := HalvesBits.of([0, 5, 63, 64, 100])
	var b := HalvesBits.of([5, 63, 70, 127])
	var keep_a := a.duplicate()
	var keep_b := b.duplicate()
	assert_eq(HalvesBits.union(a, b), HalvesBits.of([0, 5, 63, 64, 70, 100, 127]))
	assert_eq(HalvesBits.intersection(a, b), HalvesBits.of([5, 63]))
	assert_eq(HalvesBits.minus(a, b), HalvesBits.of([0, 64, 100]), "a and not b")
	assert_eq(HalvesBits.minus(b, a), HalvesBits.of([70, 127]))
	assert_eq(a, keep_a, "arguments unchanged")
	assert_eq(b, keep_b, "arguments unchanged")


func test_set_algebra_results_are_new_arrays() -> void:
	var a := HalvesBits.of([1, 70])
	var e := HalvesBits.empty()
	var keep := a.duplicate()
	for r: PackedInt64Array in [HalvesBits.union(a, e), HalvesBits.union(e, a), HalvesBits.intersection(a, a),
			HalvesBits.minus(a, e)]:
		assert_eq(r, keep)
		HalvesBits.set_bit(r, 99)
		HalvesBits.clear_bit(r, 70)
		assert_eq(a, keep, "a result never shares its array with an argument")


func test_set_algebra_with_empty_and_full() -> void:
	var a := HalvesBits.of([2, 64, 127])
	var e := HalvesBits.empty()
	var f := HalvesBits.full(128)
	assert_eq(HalvesBits.union(a, e), a)
	assert_eq(HalvesBits.union(a, f), f)
	assert_eq(HalvesBits.intersection(a, e), e)
	assert_eq(HalvesBits.intersection(a, f), a)
	assert_eq(HalvesBits.minus(a, e), a)
	assert_eq(HalvesBits.minus(a, f), e)
	assert_eq(HalvesBits.minus(f, a), HalvesBits.of(_range_without(128, [2, 64, 127])))
	assert_eq(HalvesBits.count(HalvesBits.minus(f, a)), 125)


func _range_without(n: int, skip: Array) -> Array:
	var out: Array = []
	for i: int in n:
		if not (i in skip):
			out.append(i)
	return out


func test_is_empty() -> void:
	assert_true(HalvesBits.is_empty(HalvesBits.empty()))
	assert_true(HalvesBits.is_empty(HalvesBits.full(0)))
	assert_false(HalvesBits.is_empty(HalvesBits.of([0])))
	assert_false(HalvesBits.is_empty(HalvesBits.of([63])), "a negative word 0")
	assert_false(HalvesBits.is_empty(HalvesBits.of([64])), "only word 1")
	assert_false(HalvesBits.is_empty(HalvesBits.of([127])), "only bit 127")


func test_intersects() -> void:
	var a := HalvesBits.of([1, 64])
	assert_true(HalvesBits.intersects(a, HalvesBits.of([64, 90])), "shared tile in word 1 only")
	assert_true(HalvesBits.intersects(a, HalvesBits.of([1])), "shared tile in word 0 only")
	assert_true(HalvesBits.intersects(HalvesBits.of([63]), HalvesBits.of([63, 127])), "bit 63")
	assert_true(HalvesBits.intersects(HalvesBits.of([127]), HalvesBits.full(128)), "bit 127")
	assert_false(HalvesBits.intersects(a, HalvesBits.of([0, 63, 65, 127])))
	assert_false(HalvesBits.intersects(a, HalvesBits.empty()))
	assert_false(HalvesBits.intersects(HalvesBits.empty(), HalvesBits.empty()))


func test_is_subset() -> void:
	var a := HalvesBits.of([1, 63, 64, 127])
	assert_true(HalvesBits.is_subset(HalvesBits.empty(), a), "the empty set is in every set")
	assert_true(HalvesBits.is_subset(HalvesBits.empty(), HalvesBits.empty()))
	assert_true(HalvesBits.is_subset(a, a))
	assert_true(HalvesBits.is_subset(HalvesBits.of([63, 127]), a))
	assert_true(HalvesBits.is_subset(a, HalvesBits.full(128)))
	assert_false(HalvesBits.is_subset(a, HalvesBits.of([1, 63, 64])), "127 is missing")
	assert_false(HalvesBits.is_subset(a, HalvesBits.of([1, 64, 127])), "63 is missing")
	assert_false(HalvesBits.is_subset(HalvesBits.full(128), a))
	assert_false(HalvesBits.is_subset(HalvesBits.of([2]), HalvesBits.empty()))


func test_equal_compares_content() -> void:
	assert_true(HalvesBits.equal(HalvesBits.of([0, 127]), HalvesBits.of([127, 0])))
	assert_true(HalvesBits.equal(HalvesBits.empty(), HalvesBits.full(0)))
	assert_true(HalvesBits.equal(HalvesBits.full(128), _words(-1, -1)))
	assert_false(HalvesBits.equal(HalvesBits.of([0]), HalvesBits.of([64])), "same bit, other word")
	assert_false(HalvesBits.equal(HalvesBits.of([63]), HalvesBits.of([127])))
	assert_false(HalvesBits.equal(HalvesBits.of([1, 2]), HalvesBits.of([1])))


func test_queries_never_change_their_arguments() -> void:
	var a := HalvesBits.of([0, 63, 64, 127])
	var b := HalvesBits.of([63, 99])
	var keep_a := a.duplicate()
	var keep_b := b.duplicate()
	HalvesBits.has(a, 63)
	HalvesBits.is_empty(a)
	HalvesBits.intersects(a, b)
	HalvesBits.is_subset(a, b)
	HalvesBits.equal(a, b)
	HalvesBits.count(a)
	HalvesBits.first(a)
	var ids := HalvesBits.ids(a)
	ids.append(5)
	assert_eq(a, keep_a)
	assert_eq(b, keep_b)


# --- count, ids, first ---


func test_count_across_words_and_sign_bits() -> void:
	assert_eq(HalvesBits.count(HalvesBits.of([63])), 1, "a negative word 0")
	assert_eq(HalvesBits.count(HalvesBits.of([127])), 1, "a negative word 1")
	assert_eq(HalvesBits.count(HalvesBits.of([0, 63, 64, 127])), 4)
	assert_eq(HalvesBits.count(_words(-1, 0)), 64)
	assert_eq(HalvesBits.count(_words(0, -1)), 64)
	assert_eq(HalvesBits.count(_words(TOP, TOP)), 2)
	assert_eq(HalvesBits.count(HalvesBits.full(128)), 128)
	var every_third: Array = []
	for i: int in range(0, 128, 3):
		every_third.append(i)
	assert_eq(HalvesBits.count(HalvesBits.of(every_third)), every_third.size())


func test_ids_are_ascending() -> void:
	var ids := HalvesBits.ids(HalvesBits.of([127, 0, 64, 63, 5, 100]))
	assert_true(ids is PackedInt32Array)
	assert_eq(ids, PackedInt32Array([0, 5, 63, 64, 100, 127]))
	assert_eq(HalvesBits.ids(HalvesBits.of([127])), PackedInt32Array([127]))
	assert_eq(HalvesBits.ids(_words(TOP, TOP)), PackedInt32Array([63, 127]))


func test_ids_and_of_round_trip() -> void:
	var rng := SeedService.make_rng(["test_halves_bits", "round trip"], 1)
	for t: int in 30:
		var want: Array[int] = []
		for i: int in 128:
			if rng.randf() < 0.3:
				want.append(i)
		var s := HalvesBits.of(want)
		assert_eq(HalvesBits.ids(s), PackedInt32Array(want), "trial %d" % t)
		assert_eq(HalvesBits.count(s), want.size())
		assert_eq(HalvesBits.first(s), want[0] if not want.is_empty() else -1)


func test_first_is_the_lowest_id() -> void:
	assert_eq(HalvesBits.first(HalvesBits.empty()), -1)
	assert_eq(HalvesBits.first(HalvesBits.of([0, 127])), 0)
	assert_eq(HalvesBits.first(HalvesBits.of([5, 3, 70])), 3)
	assert_eq(HalvesBits.first(HalvesBits.of([63])), 63, "only bit 63 (negative word)")
	assert_eq(HalvesBits.first(HalvesBits.of([63, 127])), 63)
	assert_eq(HalvesBits.first(HalvesBits.of([64])), 64, "word 0 empty")
	assert_eq(HalvesBits.first(HalvesBits.of([127])), 127, "only bit 127")
	assert_eq(HalvesBits.first(HalvesBits.of([100, 127])), 100)
	assert_eq(HalvesBits.first(HalvesBits.full(128)), 0)


# --- Dictionary keys ---


func test_a_set_is_a_dictionary_key_by_content() -> void:
	var memo := {}
	memo[HalvesBits.of([1, 70])] = "a"
	memo[HalvesBits.of([1])] = "b"
	memo[HalvesBits.full(128)] = "c"
	assert_true(memo.has(HalvesBits.of([70, 1])), "same content, other array")
	assert_eq(memo.get(HalvesBits.added(HalvesBits.of([1]), 70)), "a")
	var built := HalvesBits.empty()
	HalvesBits.set_bit(built, 70)
	HalvesBits.set_bit(built, 1)
	assert_eq(memo.get(built), "a", "built in place")
	assert_eq(memo.get(HalvesBits.removed(HalvesBits.of([1, 70]), 70)), "b")
	assert_eq(memo.get(_words(-1, -1)), "c")
	assert_false(memo.has(HalvesBits.of([70])))
	assert_false(memo.has(HalvesBits.of([1, 6])), "70 = bit 6 of word 1; tile 6 is bit 6 of word 0")
	assert_eq(memo.size(), 3)
	memo[HalvesBits.of([70, 1])] = "d"
	assert_eq(memo.size(), 3, "an equal set replaces the entry")
	assert_eq(memo.get(HalvesBits.of([1, 70])), "d")


# --- boards of more than 64 tiles ---


## Section 1, Free tiles, re-derived here on plain positions: not covered, and no remaining left
## neighbour or no remaining right neighbour.
func _free_by_rules(points: Array[Vector3i], remaining: PackedInt64Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in points.size():
		if not HalvesBits.has(remaining, i):
			continue
		var p := points[i]
		var covered := false
		var has_left := false
		var has_right := false
		for j: int in points.size():
			if j == i or not HalvesBits.has(remaining, j):
				continue
			var q := points[j]
			if q.z > p.z and absi(q.x - p.x) < 2 and absi(q.y - p.y) < 2:
				covered = true
			if q.z == p.z and absi(q.y - p.y) < 2:
				if q.x == p.x - 2:
					has_left = true
				elif q.x == p.x + 2:
					has_right = true
		if not covered and (not has_left or not has_right):
			out.append(i)
	return out


## 10 x 10 on one layer: tile r * 10 + c at (2c, 2r, 0), so the ids follow (z, y, x).
func _grid_10x10() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for r: int in 10:
		for c: int in 10:
			out.append(Vector3i(2 * c, 2 * r, 0))
	return out


## 8 x 8 on layer 0 (ids 0..63) and 6 x 6 on layer 1 offset by half a tile (ids 64..99).
func _two_layers() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for r: int in 8:
		for c: int in 8:
			out.append(Vector3i(2 * c, 2 * r, 0))
	for r: int in 6:
		for c: int in 6:
			out.append(Vector3i(2 * c + 1, 2 * r + 1, 1))
	return out


func _check_free_tiles(points: Array[Vector3i], label: String, seed_name: String) -> void:
	var g := HalvesGeometry.from_positions(points)
	assert_eq(g.size(), points.size(), label)
	assert_eq(g.full_mask(), HalvesBits.full(points.size()), label + ": full mask")
	var rng := SeedService.make_rng(["test_halves_bits", seed_name], 1)
	var rem := g.full_mask()
	var rounds := 0
	while not HalvesBits.is_empty(rem) and rounds < 200:
		var want := _free_by_rules(points, rem)
		var got := g.free_tiles(rem)
		if got != want:
			fail_test("%s, %d tiles left: free tiles %s, the rules give %s" % [label, HalvesBits.count(rem), got, want])
			return
		if not HalvesBits.equal(g.free_mask(rem), HalvesBits.of(Array(want))):
			fail_test("%s: free_mask disagrees with the rules" % label)
			return
		for i: int in HalvesBits.ids(rem):   # is_free is only defined for remaining tiles
			if g.is_free(i, rem) != (i in want):
				fail_test("%s: is_free(%d) disagrees with the rules" % [label, i])
				return
		# Remove a free tile when there is one (play order), else any remaining tile.
		var pick_from: PackedInt32Array = want if not want.is_empty() else HalvesBits.ids(rem)
		rem = HalvesBits.removed(rem, pick_from[rng.randi_range(0, pick_from.size() - 1)])
		rounds += 1
	assert_true(HalvesBits.is_empty(rem), label + ": checked down to an empty board")


func test_free_tiles_on_a_100_tile_layer() -> void:
	var points := _grid_10x10()
	var g := HalvesGeometry.from_positions(points)
	var want := PackedInt32Array()
	for r: int in 10:
		want.append(r * 10)
		want.append(r * 10 + 9)
	assert_eq(g.free_tiles(g.full_mask()), want, "only the row ends")
	assert_true(g.is_free(99, g.full_mask()))
	assert_true(g.is_free(90, g.full_mask()))
	assert_false(g.is_free(95, g.full_mask()))
	_check_free_tiles(points, "10 x 10", "grid")


func test_free_tiles_on_a_100_tile_stack() -> void:
	var points := _two_layers()
	var g := HalvesGeometry.from_positions(points)
	var full := g.full_mask()
	# Top tile (2c+1, 2r+1, 1) covers bottom tiles c..c+1, r..r+1: every bottom tile but column 7
	# and row 7. Only the top row ends are free up there.
	var want := PackedInt32Array()
	for i: int in 64:
		var r := int(i / 8.0)
		var c := i % 8
		var under_top := r <= 6 and c <= 6
		# A bottom tile not under the top layer is free when it is a row end (column 0 or 7).
		if not under_top and (c == 0 or c == 7):
			want.append(i)
	for r: int in 6:
		want.append(64 + 6 * r)
		want.append(64 + 6 * r + 5)
	assert_eq(g.free_tiles(full), want)
	assert_false(g.is_free(0, full), "covered by tile 64")
	assert_true(g.is_free(64, full), "top-left of the upper layer")
	assert_eq(g.blocked_reason(0, full), HalvesGeometry.Block.COVERED)
	assert_eq(g.blocked_reason(65, full), HalvesGeometry.Block.SIDES)
	assert_eq(g.blocked_reason(64, full), HalvesGeometry.Block.FREE)
	_check_free_tiles(points, "8 x 8 + 6 x 6", "stack")


## Faces for _grid_10x10 with a known solution: in row r, step k pairs columns k and 9 - k (the row
## ends, then inwards). Keys cycle through v2 shapes and crests, so most pairs have twins elsewhere.
func _grid_board() -> Dictionary:
	var keys: Array[int] = [
		HalvesFace.pair_from_text("circle:v:-"), HalvesFace.pair_from_text("tri:v:dot"),
		HalvesFace.pair_from_text("square:h:line"), HalvesCrests.pair_of(0, 0), HalvesCrests.pair_of(0, 1),
		HalvesCrests.pair_of(1, 0), HalvesCrests.pair_of(HalvesCrests.motif_count() - 1, 1),
	]
	var faces := PackedInt32Array()
	faces.resize(100)
	var solution: Array[Vector2i] = []
	var n := 0
	for r: int in 10:
		for k: int in 5:
			var key: int = keys[n % keys.size()]
			n += 1
			var a := r * 10 + k
			var b := r * 10 + 9 - k
			faces[a] = key << 1
			faces[b] = (key << 1) | 1
			solution.append(Vector2i(a, b))
	return {"faces": faces, "solution": solution}


func test_a_state_on_a_100_tile_board() -> void:
	var board := _grid_board()
	var faces: PackedInt32Array = board["faces"]
	for f: int in faces:
		assert_true(HalvesFace.is_valid(f), "test setup: face %d is valid" % f)
	var s := HalvesState.new(HalvesGeometry.from_positions(_grid_10x10()), faces)
	assert_eq(s.remaining, HalvesBits.full(100))
	assert_eq(s.tiles_left(), 100)
	# Row 7 is ids 70..79: the ends are mates.
	assert_eq(s.try_pair(71, 78), R.BLOCKED, "inner tiles of row 7")
	assert_eq(s.try_pair(70, 75), R.BLOCKED, "75 is not free")
	assert_eq(s.try_pair(99, 100), R.INVALID, "id 100 is out of range")
	assert_eq(s.remaining, HalvesBits.full(100), "nothing changed")
	assert_eq(s.try_pair(70, 79), R.MATCH)
	assert_eq(s.remaining, HalvesBits.minus(HalvesBits.full(100), HalvesBits.of([70, 79])))
	assert_eq(s.try_pair(71, 78), R.MATCH, "the next pair inwards is free now")
	assert_eq(s.tiles_left(), 96)
	assert_true(s.undo())
	assert_true(s.undo())
	assert_eq(s.remaining, HalvesBits.full(100), "undo returns tiles with ids >= 64")
	assert_eq(s.try_pair(71, 78), R.BLOCKED, "blocked again")
	assert_false(s.undo(), "nothing left to undo")


func test_a_100_tile_board_clears_with_its_solution() -> void:
	var board := _grid_board()
	var s := HalvesState.new(HalvesGeometry.from_positions(_grid_10x10()), board["faces"])
	var solution: Array[Vector2i] = board["solution"]
	# Play the rows from the last to the first, so the high ids go first.
	var order: Array[Vector2i] = []
	for r: int in range(9, -1, -1):
		for k: int in 5:
			order.append(solution[r * 5 + k])
	assert_eq(H.replay_error(s, order), "")
	assert_true(s.is_cleared())
	assert_eq(s.remaining, HalvesBits.empty())
	assert_eq(s.mistakes, 0)
	assert_eq(s.history.size(), 50)


func test_mistakes_and_switches_on_a_100_tile_board() -> void:
	var board := _grid_board()
	var faces: PackedInt32Array = board["faces"]
	var s := HalvesState.new(HalvesGeometry.from_positions(_grid_10x10()), faces)
	# Find two free tiles with ids >= 64 that are a decoy, and two that are neither match nor decoy.
	var free := s.geometry.free_tiles(s.remaining)
	var decoy := Vector2i(-1, -1)
	var other := Vector2i(-1, -1)
	for i: int in free.size():
		for j: int in range(i + 1, free.size()):
			var a: int = free[i]
			var b: int = free[j]
			if a < 64 and b < 64:
				continue
			if HalvesFace.is_decoy(faces[a], faces[b]) and decoy.x < 0:
				decoy = Vector2i(a, b)
			elif not HalvesFace.matches(faces[a], faces[b]) and not HalvesFace.is_decoy(faces[a], faces[b]) and other.x < 0:
				other = Vector2i(a, b)
	assert_ne(decoy, Vector2i(-1, -1), "test setup: a free decoy with a tile >= 64")
	assert_ne(other, Vector2i(-1, -1), "test setup: a free unrelated pair with a tile >= 64")
	if decoy.x < 0 or other.x < 0:
		return
	assert_eq(s.try_pair(decoy.x, decoy.y), R.MISMATCH)
	assert_eq(s.mistakes, 1)
	assert_eq(s.try_pair(other.x, other.y), R.SWITCH)
	assert_eq(s.mistakes, 1)
	assert_true(s.undo())
	assert_eq(s.mistakes, 0)
	assert_eq(s.remaining, HalvesBits.full(100))


func test_a_state_on_the_100_tile_stack() -> void:
	# Pairs: the top layer row by row from its ends inwards, then the bottom layer the same way.
	var points := _two_layers()
	var faces := PackedInt32Array()
	faces.resize(points.size())
	var order: Array[Vector2i] = []
	var n := 0
	for r: int in 6:
		for k: int in 3:
			order.append(Vector2i(64 + 6 * r + k, 64 + 6 * r + 5 - k))
	for r: int in 8:
		for k: int in 4:
			order.append(Vector2i(8 * r + k, 8 * r + 7 - k))
	for p: Vector2i in order:
		var key := HalvesCrests.pair_of(n % HalvesCrests.motif_count(), 0)
		n += 1
		faces[p.x] = key << 1
		faces[p.y] = (key << 1) | 1
	var s := HalvesState.new(HalvesGeometry.from_positions(points), faces)
	assert_eq(s.try_pair(0, 7), R.BLOCKED, "mates, but tile 0 is covered by tile 64")
	assert_eq(s.try_pair(64, 69), R.MATCH, "top-left row of the upper layer")
	assert_true(s.undo())
	assert_eq(H.order_error(s.geometry, s.geometry.full_mask(), order), "", "test setup: a valid removal order")
	assert_eq(H.replay_error(s, order), "")
	assert_true(s.is_cleared())
