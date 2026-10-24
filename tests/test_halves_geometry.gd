extends GutTest
## HalvesGeometry: which tiles are free (covering, left/right neighbours, half-unit offsets),
## masks, bounds and the 128-tile edge (v3; bit 127 makes word 1 negative). Hand-built boards only.
## Written from docs/HALVES.md alone; positions are given in (z, y, x) order unless a test says otherwise.

const H := preload("res://tests/halves_helpers.gd")


func _row_of_four() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(6, 0, 0)])


func test_row_of_four_only_the_ends_are_free() -> void:
	var g := _row_of_four()
	assert_eq(g.size(), 4)
	assert_eq(g.full_mask(), H.from_int(0b1111))
	assert_true(g.is_free(0, H.from_int(0b1111)), "left end")
	assert_false(g.is_free(1, H.from_int(0b1111)), "neighbours on both sides")
	assert_false(g.is_free(2, H.from_int(0b1111)), "neighbours on both sides")
	assert_true(g.is_free(3, H.from_int(0b1111)), "right end")
	assert_eq(g.free_mask(H.from_int(0b1111)), H.from_int(0b1001))
	assert_eq(g.free_tiles(H.from_int(0b1111)), PackedInt32Array([0, 3]))


func test_removing_an_end_frees_the_next_tile() -> void:
	var g := _row_of_four()
	assert_eq(g.free_mask(H.from_int(0b1110)), H.from_int(0b1010), "tile 0 gone: tile 1 has no left neighbour")
	assert_eq(g.free_tiles(H.from_int(0b1110)), PackedInt32Array([1, 3]))
	assert_eq(g.free_mask(H.from_int(0b0110)), H.from_int(0b0110), "both ends gone: the middle two are free")
	assert_eq(g.free_mask(H.from_int(0b0100)), H.from_int(0b0100))
	assert_eq(g.free_mask(H.from_int(0b0101)), H.from_int(0b0101), "tile 2 with tile 1 gone has no left neighbour")
	assert_eq(g.free_mask(HalvesBits.empty()), HalvesBits.empty())
	assert_eq(g.free_tiles(HalvesBits.empty()), PackedInt32Array())


func test_neighbours_must_be_exactly_one_tile_away() -> void:
	# x = 2 and x = 6 are 4 half-units apart: a gap, so nobody is blocked on both sides.
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(6, 0, 0), Vector3i(8, 0, 0)])
	assert_eq(g.free_mask(H.from_int(0b1111)), H.from_int(0b1111))


func test_half_row_offset_still_blocks() -> void:
	# Tile 2 sits half a row lower (|dy| == 1) between tiles 0 and 1, which still count as neighbours.
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(2, 1, 0)])
	assert_true(g.is_free(0, H.from_int(0b111)))
	assert_true(g.is_free(1, H.from_int(0b111)))
	assert_false(g.is_free(2, H.from_int(0b111)), "|dy| == 1 neighbours on both sides")
	assert_eq(g.free_mask(H.from_int(0b111)), H.from_int(0b011))
	assert_eq(g.free_mask(H.from_int(0b110)), H.from_int(0b110), "left neighbour gone")
	assert_eq(g.free_mask(H.from_int(0b101)), H.from_int(0b101), "right neighbour gone")


func test_rows_two_apart_do_not_block() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(2, 2, 0)])
	assert_eq(g.free_mask(H.from_int(0b111)), H.from_int(0b111), "|dy| == 2 is not a neighbour")


func test_neighbours_on_other_layers_do_not_block() -> void:
	# Tile 3 at (0,0,1) is not a left neighbour of tile 1 at (2,0,0) (other layer); it covers tile 0 only.
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 0, 1)])
	assert_false(g.is_free(0, H.from_int(0b1111)), "covered")
	assert_false(g.is_free(1, H.from_int(0b1111)), "same-layer neighbours on both sides")
	assert_true(g.is_free(2, H.from_int(0b1111)))
	assert_true(g.is_free(3, H.from_int(0b1111)))
	assert_eq(g.free_mask(H.from_int(0b1111)), H.from_int(0b1100))
	assert_eq(g.free_mask(H.from_int(0b1110)), H.from_int(0b1110), "tile 0 gone: tile 1 is free though tile 3 is still up")


func test_upper_tile_half_offset_covers() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(1, 1, 1)])
	assert_false(g.is_free(0, H.from_int(0b11)), "|dx| == 1 and |dy| == 1 overlaps a quarter")
	assert_true(g.is_free(1, H.from_int(0b11)))
	assert_eq(g.free_mask(H.from_int(0b11)), H.from_int(0b10))
	assert_eq(g.free_mask(H.from_int(0b01)), H.from_int(0b01), "uncovered once the upper tile is gone")


func test_upper_tile_offset_the_other_way_covers() -> void:
	var g := H.geometry([Vector3i(2, 2, 0), Vector3i(1, 1, 1)])
	assert_eq(g.free_mask(H.from_int(0b11)), H.from_int(0b10), "dx = -1, dy = -1 still overlaps")


func test_upper_tile_two_half_units_away_does_not_cover() -> void:
	assert_eq(H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 1)]).free_mask(H.from_int(0b11)), H.from_int(0b11), "|dx| == 2")
	assert_eq(H.geometry([Vector3i(0, 0, 0), Vector3i(0, 2, 1)]).free_mask(H.from_int(0b11)), H.from_int(0b11), "|dy| == 2")
	assert_eq(H.geometry([Vector3i(0, 0, 0), Vector3i(2, 2, 1)]).free_mask(H.from_int(0b11)), H.from_int(0b11), "diagonal, 2 away")


func test_any_higher_layer_covers_and_lower_layers_do_not() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 2)])
	assert_eq(g.free_mask(H.from_int(0b11)), H.from_int(0b10), "z 2 covers z 0")
	# A bridge: one upper tile resting on two lower ones covers both; the lower ones never cover it.
	var bridge := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(1, 0, 1)])
	assert_eq(bridge.free_mask(H.from_int(0b111)), H.from_int(0b100))
	assert_eq(bridge.free_mask(H.from_int(0b011)), H.from_int(0b011))


func test_both_sides_blocked_but_uncovered_is_not_free() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0)])
	assert_false(g.is_free(1, H.from_int(0b111)))


func test_one_side_open_but_covered_is_not_free() -> void:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(0, 0, 1)])
	assert_false(g.is_free(0, H.from_int(0b111)), "open on the left but covered")
	assert_true(g.is_free(1, H.from_int(0b111)), "open on the right; the upper tile is 2 half-units away")
	assert_eq(g.free_mask(H.from_int(0b111)), H.from_int(0b110))
	assert_eq(g.free_tiles(H.from_int(0b111)), PackedInt32Array([1, 2]))


func test_from_positions_keeps_the_given_order() -> void:
	var g := H.geometry([Vector3i(2, 0, 0), Vector3i(0, 0, 0), Vector3i(0, 0, 1)])
	assert_eq(g.size(), 3)
	assert_eq(g.positions[0], Vector3i(2, 0, 0))
	assert_eq(g.positions[1], Vector3i(0, 0, 0))
	assert_eq(g.positions[2], Vector3i(0, 0, 1))
	assert_eq(g.free_mask(H.from_int(0b111)), H.from_int(0b101), "tile 1 is under tile 2")


func test_free_tiles_are_ascending() -> void:
	# Five free tiles given in a scrambled spatial order: ids still come back ascending.
	var g := H.geometry([Vector3i(8, 0, 0), Vector3i(0, 4, 0), Vector3i(4, 8, 0), Vector3i(0, 0, 0), Vector3i(8, 8, 0)])
	assert_eq(g.free_tiles(H.from_int(0b11111)), PackedInt32Array([0, 1, 2, 3, 4]))
	assert_eq(g.free_tiles(H.from_int(0b10110)), PackedInt32Array([1, 2, 4]))


func test_full_mask() -> void:
	assert_eq(H.geometry([]).full_mask(), HalvesBits.empty())
	assert_eq(H.geometry([Vector3i(0, 0, 0)]).full_mask(), H.from_int(1))
	assert_eq(_row_of_four().full_mask(), H.from_int(15))
	assert_eq(H.geometry(H.column(10)).full_mask(), H.from_int(1023))


func test_bounds_and_max_z() -> void:
	assert_eq(_row_of_four().bounds(), Rect2i(0, 0, 8, 2))
	assert_eq(_row_of_four().max_z(), 0)
	var bridge := H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(1, 0, 1)])
	assert_eq(bridge.bounds(), Rect2i(0, 0, 4, 2))
	assert_eq(bridge.max_z(), 1)
	var tower := H.geometry([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2)])
	assert_eq(tower.max_z(), 2)
	assert_eq(tower.bounds(), Rect2i(0, 0, 2, 2))
	assert_eq(H.geometry([Vector3i(0, 0, 0), Vector3i(1, 3, 0)]).bounds(), Rect2i(0, 0, 3, 5), "half-unit offsets")
	assert_eq(H.geometry([Vector3i(4, 2, 0), Vector3i(6, 2, 0)]).bounds(), Rect2i(0, 0, 8, 4),
			"the extent always starts at 0,0")


## (v3) HalvesGeometry.popcount became HalvesBits.count.
func test_popcount() -> void:
	assert_eq(HalvesBits.count(HalvesBits.empty()), 0)
	assert_eq(HalvesBits.count(H.from_int(1)), 1)
	assert_eq(HalvesBits.count(H.from_int(0b1011)), 3)
	assert_eq(HalvesBits.count(H.from_int(255)), 8)
	assert_eq(HalvesBits.count(H.bit(127)), 1, "bit 127 alone (a negative word)")
	assert_eq(HalvesBits.count(H.mask_of([127, 0])), 2)
	assert_eq(HalvesBits.count(HalvesBits.full(128)), 128)


## (v3: the limit is 128 tiles, was 64.) 8 rows of 16.
func _grid_16x8() -> HalvesGeometry:
	var points: Array = []
	for row: int in 8:
		for col: int in 16:
			points.append(Vector3i(2 * col, 2 * row, 0))
	return H.geometry(points)


func test_128_tile_board_uses_bit_127() -> void:
	var g := _grid_16x8()
	assert_eq(g.size(), HalvesGeometry.MAX_TILES)
	var full := g.full_mask()
	assert_eq(full, HalvesBits.full(128), "all 128 bits set")
	assert_eq(HalvesBits.count(full), 128)
	# Tile i is row i / 16, column i % 16. Only the two ends of each row are free.
	var expected := HalvesBits.empty()
	var expected_ids := PackedInt32Array()
	for row: int in 8:
		HalvesBits.set_bit(expected, 16 * row)
		HalvesBits.set_bit(expected, 16 * row + 15)
		expected_ids.append(16 * row)
		expected_ids.append(16 * row + 15)
	assert_true(g.is_free(127, full), "right end of the last row")
	assert_true(g.is_free(112, full), "left end of the last row")
	assert_false(g.is_free(126, full))
	assert_eq(g.free_mask(full), expected)
	assert_true(g.free_mask(full)[1] < 0, "bit 127 is set, so word 1 is negative")
	assert_eq(g.free_tiles(full), expected_ids)


func test_128_tile_board_after_removing_tile_127() -> void:
	var g := _grid_16x8()
	var rem := HalvesBits.removed(g.full_mask(), 127)
	assert_eq(HalvesBits.count(rem), 127)
	assert_true(g.is_free(126, rem), "tile 126 lost its right neighbour")
	assert_false(HalvesBits.has(g.free_mask(rem), 127), "a removed tile is never free")
	assert_true(HalvesBits.has(g.free_mask(rem), 126))
	var ids := g.free_tiles(rem)
	assert_eq(ids[ids.size() - 1], 126)
	var only_127 := H.bit(127)
	assert_eq(g.free_mask(only_127), only_127)
	assert_eq(g.free_tiles(only_127), PackedInt32Array([127]))
