extends GutTest
## HalvesFace: the int encoding of a half-shape face, matching, decoys, validity and text forms.
## Written from docs/HALVES.md alone, in a separate session from the implementation.
## Expected ints are worked out by hand from make = shape << 4 | cut << 3 | mark << 1 | side.
## (v3) These are the v2 faces (pairs 0-31), unchanged; crest faces are in test_halves_crests.gd.

# Hand-encoded faces used below.
const CIRCLE_V_A := 0        # circle:v:-:a
const CIRCLE_V_B := 1        # circle:v:-:b
const CIRCLE_V_DOT_A := 2    # circle:v:dot:a
const CIRCLE_V_DOT_B := 3    # circle:v:dot:b
const CIRCLE_H_B := 9        # circle:h:-:b   = 8 | 1
const TRI_V_B := 17          # tri:v:-:b      = 16 | 1
const TRI_V_DOT_A := 18      # tri:v:dot:a    = 16 | 2
const TRI_V_DOT_B := 19      # tri:v:dot:b    = 16 | 2 | 1
const TRI_H_A := 24          # tri:h:-:a      = 16 | 8 (invalid: triangles are only cut vertically)
const SQUARE_V_A := 32       # square:v:-:a
const SQUARE_V_LINE_A := 36  # square:v:line:a = 32 | 4
const SQUARE_V_LINE_B := 37
const SQUARE_H_DOT_B := 43   # square:h:dot:b  = 32 | 8 | 2 | 1
const DIAMOND_V_B := 49      # diamond:v:-:b   = 48 | 1
const DIAMOND_H_LINE_A := 60 # diamond:h:line:a = 48 | 8 | 4
const DIAMOND_H_LINE_B := 61


func test_enum_values_follow_the_text_order() -> void:
	assert_eq(HalvesFace.Shape.CIRCLE, 0)
	assert_eq(HalvesFace.Shape.TRIANGLE, 1)
	assert_eq(HalvesFace.Shape.SQUARE, 2)
	assert_eq(HalvesFace.Shape.DIAMOND, 3)
	assert_eq(HalvesFace.Cut.VERTICAL, 0)
	assert_eq(HalvesFace.Cut.HORIZONTAL, 1)
	assert_eq(HalvesFace.Mark.NONE, 0)
	assert_eq(HalvesFace.Mark.DOT, 1)
	assert_eq(HalvesFace.Mark.LINE, 2)
	assert_eq(HalvesFace.SIDE_A, 0)
	assert_eq(HalvesFace.SIDE_B, 1)


func test_make_packs_shape_cut_mark_side() -> void:
	assert_eq(HalvesFace.make(HalvesFace.Shape.CIRCLE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.NONE, HalvesFace.SIDE_A), CIRCLE_V_A)
	assert_eq(HalvesFace.make(HalvesFace.Shape.CIRCLE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.NONE, HalvesFace.SIDE_B), CIRCLE_V_B)
	assert_eq(HalvesFace.make(HalvesFace.Shape.CIRCLE, HalvesFace.Cut.HORIZONTAL, HalvesFace.Mark.NONE, HalvesFace.SIDE_B), CIRCLE_H_B)
	assert_eq(HalvesFace.make(HalvesFace.Shape.TRIANGLE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.DOT, HalvesFace.SIDE_B), TRI_V_DOT_B)
	assert_eq(HalvesFace.make(HalvesFace.Shape.SQUARE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.LINE, HalvesFace.SIDE_A), SQUARE_V_LINE_A)
	assert_eq(HalvesFace.make(HalvesFace.Shape.SQUARE, HalvesFace.Cut.HORIZONTAL, HalvesFace.Mark.DOT, HalvesFace.SIDE_B), SQUARE_H_DOT_B)
	assert_eq(HalvesFace.make(HalvesFace.Shape.DIAMOND, HalvesFace.Cut.HORIZONTAL, HalvesFace.Mark.LINE, HalvesFace.SIDE_A), DIAMOND_H_LINE_A)


func test_getters_read_back_each_part() -> void:
	assert_eq(HalvesFace.shape(SQUARE_H_DOT_B), HalvesFace.Shape.SQUARE)
	assert_eq(HalvesFace.cut(SQUARE_H_DOT_B), HalvesFace.Cut.HORIZONTAL)
	assert_eq(HalvesFace.mark(SQUARE_H_DOT_B), HalvesFace.Mark.DOT)
	assert_eq(HalvesFace.side(SQUARE_H_DOT_B), HalvesFace.SIDE_B)
	assert_eq(HalvesFace.shape(DIAMOND_H_LINE_A), HalvesFace.Shape.DIAMOND)
	assert_eq(HalvesFace.cut(DIAMOND_H_LINE_A), HalvesFace.Cut.HORIZONTAL)
	assert_eq(HalvesFace.mark(DIAMOND_H_LINE_A), HalvesFace.Mark.LINE)
	assert_eq(HalvesFace.side(DIAMOND_H_LINE_A), HalvesFace.SIDE_A)
	assert_eq(HalvesFace.shape(TRI_V_DOT_B), HalvesFace.Shape.TRIANGLE)
	assert_eq(HalvesFace.cut(TRI_V_DOT_B), HalvesFace.Cut.VERTICAL)


func test_getters_round_trip_every_valid_combination() -> void:
	for s: int in 4:
		for c: int in 2:
			if s == HalvesFace.Shape.TRIANGLE and c == HalvesFace.Cut.HORIZONTAL:
				continue
			for m: int in 3:
				for side: int in 2:
					var f := HalvesFace.make(s, c, m, side)
					assert_eq(f, (s << 4) | (c << 3) | (m << 1) | side)
					assert_eq(HalvesFace.shape(f), s)
					assert_eq(HalvesFace.cut(f), c)
					assert_eq(HalvesFace.mark(f), m)
					assert_eq(HalvesFace.side(f), side)
					assert_true(HalvesFace.is_valid(f), "face %d should be valid" % f)


func test_pair_key_drops_the_side_and_mate_flips_it() -> void:
	assert_eq(HalvesFace.pair_key(CIRCLE_V_A), 0)
	assert_eq(HalvesFace.pair_key(CIRCLE_V_B), 0)
	assert_eq(HalvesFace.pair_key(TRI_V_DOT_A), 9)
	assert_eq(HalvesFace.pair_key(TRI_V_DOT_B), 9)
	assert_eq(HalvesFace.pair_key(DIAMOND_H_LINE_A), 30)
	assert_eq(HalvesFace.mate(TRI_V_DOT_B), TRI_V_DOT_A)
	assert_eq(HalvesFace.mate(TRI_V_DOT_A), TRI_V_DOT_B)
	assert_eq(HalvesFace.mate(DIAMOND_H_LINE_A), DIAMOND_H_LINE_B)
	for f: int in 64:
		if HalvesFace.is_valid(f):
			assert_eq(HalvesFace.mate(HalvesFace.mate(f)), f)
			assert_eq(HalvesFace.pair_key(HalvesFace.mate(f)), HalvesFace.pair_key(f))
			assert_true(HalvesFace.matches(f, HalvesFace.mate(f)), "a face matches its mate (%d)" % f)


func test_matches_needs_same_pair_type_and_opposite_sides() -> void:
	assert_true(HalvesFace.matches(CIRCLE_V_A, CIRCLE_V_B))
	assert_true(HalvesFace.matches(CIRCLE_V_B, CIRCLE_V_A), "order does not matter")
	assert_true(HalvesFace.matches(SQUARE_V_LINE_A, SQUARE_V_LINE_B))
	assert_false(HalvesFace.matches(CIRCLE_V_A, CIRCLE_V_A), "twins never match")
	assert_false(HalvesFace.matches(CIRCLE_V_B, CIRCLE_V_B), "twins never match")
	assert_false(HalvesFace.matches(CIRCLE_V_A, CIRCLE_H_B), "other cut")
	assert_false(HalvesFace.matches(CIRCLE_V_A, CIRCLE_V_DOT_B), "other mark")
	assert_false(HalvesFace.matches(CIRCLE_V_A, TRI_V_B), "other shape")
	assert_false(HalvesFace.matches(SQUARE_V_A, DIAMOND_V_B), "other shape (same colour)")


func test_decoys_are_same_shape_non_matches() -> void:
	assert_true(HalvesFace.is_decoy(CIRCLE_V_A, CIRCLE_V_A), "a twin is a decoy")
	assert_true(HalvesFace.is_decoy(TRI_V_DOT_B, TRI_V_DOT_B), "a twin is a decoy")
	assert_true(HalvesFace.is_decoy(CIRCLE_V_A, CIRCLE_H_B), "near-twin: other cut")
	assert_true(HalvesFace.is_decoy(CIRCLE_V_A, CIRCLE_V_DOT_B), "near-twin: other mark")
	assert_true(HalvesFace.is_decoy(CIRCLE_V_A, CIRCLE_V_DOT_A), "near-twin: other mark, same side")
	assert_true(HalvesFace.is_decoy(SQUARE_V_LINE_A, SQUARE_H_DOT_B), "same shape, everything else differs")
	assert_false(HalvesFace.is_decoy(CIRCLE_V_A, CIRCLE_V_B), "a match is not a decoy")
	assert_false(HalvesFace.is_decoy(DIAMOND_H_LINE_A, DIAMOND_H_LINE_B), "a match is not a decoy")
	assert_false(HalvesFace.is_decoy(CIRCLE_V_A, TRI_V_B), "different shapes are not decoys")
	assert_false(HalvesFace.is_decoy(SQUARE_V_A, DIAMOND_V_B), "square and diamond share a colour but not a shape")


func test_decoy_is_symmetric() -> void:
	var sample: Array[int] = [CIRCLE_V_A, CIRCLE_V_B, CIRCLE_H_B, CIRCLE_V_DOT_A, TRI_V_DOT_B, SQUARE_V_A, DIAMOND_V_B]
	for a: int in sample:
		for b: int in sample:
			assert_eq(HalvesFace.is_decoy(a, b), HalvesFace.is_decoy(b, a), "is_decoy(%d, %d)" % [a, b])
			assert_eq(HalvesFace.matches(a, b), HalvesFace.matches(b, a), "matches(%d, %d)" % [a, b])


func test_is_valid_rejects_unknown_values_and_horizontal_triangles() -> void:
	assert_false(HalvesFace.is_valid(TRI_H_A), "tri:h:-:a")
	assert_false(HalvesFace.is_valid(TRI_H_A + 1), "tri:h:-:b")
	assert_false(HalvesFace.is_valid(16 | 8 | 2 | 1), "tri:h:dot:b")
	assert_false(HalvesFace.is_valid(16 | 8 | 4), "tri:h:line:a")
	assert_false(HalvesFace.is_valid(6), "mark value 3 does not exist")
	assert_false(HalvesFace.is_valid(32 | 8 | 6 | 1), "mark value 3 does not exist")
	assert_false(HalvesFace.is_valid(-1))
	# (v3) Face 64 (v2: shape value 4) is now the first crest, pair 32; values past the crest
	# catalogue are the unknown ones.
	var past := (HalvesCrests.FIRST_PAIR + HalvesCrests.motif_count() * 2) << 1
	assert_false(HalvesFace.is_valid(past), "pair %d is past the crest catalogue" % (past >> 1))
	assert_false(HalvesFace.is_valid(past + 1), "pair %d is past the crest catalogue" % (past >> 1))
	assert_false(HalvesFace.is_valid(past + 2))


func test_exactly_42_valid_faces_below_64() -> void:
	# 64 bit patterns - 16 with mark 3 - 6 horizontal triangles (3 marks x 2 sides) = 42.
	var count := 0
	for f: int in 64:
		if HalvesFace.is_valid(f):
			count += 1
	assert_eq(count, 42)


func test_to_text() -> void:
	assert_eq(HalvesFace.to_text(CIRCLE_V_A), "circle:v:-:a")
	assert_eq(HalvesFace.to_text(CIRCLE_H_B), "circle:h:-:b")
	assert_eq(HalvesFace.to_text(TRI_V_DOT_B), "tri:v:dot:b")
	assert_eq(HalvesFace.to_text(SQUARE_V_LINE_A), "square:v:line:a")
	assert_eq(HalvesFace.to_text(SQUARE_H_DOT_B), "square:h:dot:b")
	assert_eq(HalvesFace.to_text(DIAMOND_H_LINE_A), "diamond:h:line:a")


func test_from_text() -> void:
	assert_eq(HalvesFace.from_text("circle:v:-:a"), CIRCLE_V_A)
	assert_eq(HalvesFace.from_text("circle:h:-:b"), CIRCLE_H_B)
	assert_eq(HalvesFace.from_text("tri:v:dot:b"), TRI_V_DOT_B)
	assert_eq(HalvesFace.from_text("square:v:line:a"), SQUARE_V_LINE_A)
	assert_eq(HalvesFace.from_text("diamond:h:line:a"), DIAMOND_H_LINE_A)
	assert_eq(HalvesFace.from_text("diamond:v:-:b"), DIAMOND_V_B)


func test_text_round_trip_for_every_valid_face() -> void:
	for f: int in 64:
		if HalvesFace.is_valid(f):
			assert_eq(HalvesFace.from_text(HalvesFace.to_text(f)), f, HalvesFace.to_text(f))


func test_invalid_text_gives_minus_one() -> void:
	for text: String in ["", "circle", "circle:v:-", "circle:v:-:c", "hexagon:v:-:a", "tri:h:-:a",
			"tri:h:dot:b", "circle:x:-:a", "circle:v:star:a", "circle:v:-:a:b", "circle v - a"]:
		assert_eq(HalvesFace.from_text(text), -1, "'%s' is not a face" % text)


func test_pair_text_round_trip() -> void:
	assert_eq(HalvesFace.pair_to_text(0), "circle:v:-")
	assert_eq(HalvesFace.pair_to_text(9), "tri:v:dot")
	assert_eq(HalvesFace.pair_to_text(20), "square:h:-")
	assert_eq(HalvesFace.pair_to_text(30), "diamond:h:line")
	assert_eq(HalvesFace.pair_from_text("circle:v:-"), 0)
	assert_eq(HalvesFace.pair_from_text("circle:h:-"), 4)
	assert_eq(HalvesFace.pair_from_text("tri:v:dot"), 9)
	assert_eq(HalvesFace.pair_from_text("square:v:line"), 18)
	assert_eq(HalvesFace.pair_from_text("square:h:-"), 20)
	assert_eq(HalvesFace.pair_from_text("diamond:h:line"), 30)
	for f: int in 64:
		if HalvesFace.is_valid(f):
			var key := HalvesFace.pair_key(f)
			assert_eq(HalvesFace.pair_from_text(HalvesFace.pair_to_text(key)), key)
			assert_true(HalvesFace.to_text(f).begins_with(HalvesFace.pair_to_text(key) + ":"),
					"pair type is the first three parts of %s" % HalvesFace.to_text(f))


func test_invalid_pair_text_gives_minus_one() -> void:
	for text: String in ["", "circle", "circle:v", "tri:h:-", "moon:v:-", "circle:v:star", "circle:v:-:a"]:
		assert_eq(HalvesFace.pair_from_text(text), -1, "'%s' is not a pair type" % text)
