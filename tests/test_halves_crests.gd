extends GutTest
## Contract v3 crests: pair numbering and crest faces in HalvesFace (parts, decoys, text forms), the
## HalvesCrests catalogue (invariants, pair helpers, families, groups, similarity) and HalvesCrest
## polygons (halves inside their half-plane, halves adding up to the whole, cached). No pixels.
## Written from docs/HALVES.md (contract v3) alone, in a separate session from the implementation;
## expected values are re-derived from the catalogue data (MOTIFS, FAMILIES), never from the code.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result
const CUT_TEXT: Array[String] = ["v", "h"]
const SIDE_TEXT: Array[String] = ["a", "b"]
const SHAPE_GROUPS: Array[StringName] = [&"circle", &"tri", &"square", &"diamond"]
const EPS := 1e-4


# --- helpers re-deriving the contract from the catalogue data ---


func _motif(m: int) -> Dictionary:
	return HalvesCrests.MOTIFS[m]


func _count() -> int:
	return HalvesCrests.MOTIFS.size()


func _allows(m: int, cut: int) -> bool:
	var cuts: Array = _motif(m).get("cuts", [])
	return cut in cuts


## The first pair id after the catalogue (an unknown motif).
func _end_pair() -> int:
	return 32 + _count() * 2


## v2 rule: shape << 3 | cut << 2 | mark; marks 0..2; triangles only vertical.
func _v2_pair_valid(p: int) -> bool:
	if p < 0 or p >= 32:
		return false
	var shape := p >> 3
	var cut := (p >> 2) & 1
	var mark := p & 3
	return mark <= 2 and not (shape == 1 and cut == 1)


func _v2_pairs() -> Array[int]:
	var out: Array[int] = []
	for p: int in 32:
		if _v2_pair_valid(p):
			out.append(p)
	return out


func _crest_pairs() -> Array[int]:
	var out: Array[int] = []
	for m: int in _count():
		for c: int in 2:
			if _allows(m, c):
				out.append(32 + m * 2 + c)
	return out


func _crest_faces() -> Array[int]:
	var out: Array[int] = []
	for p: int in _crest_pairs():
		out.append(p << 1)
		out.append((p << 1) | 1)
	return out


func _v2_faces() -> Array[int]:
	var out: Array[int] = []
	for p: int in _v2_pairs():
		out.append(p << 1)
		out.append((p << 1) | 1)
	return out


## The look-alike group of a valid pair: the shape name for v2, the catalogue's group for crests.
func _group_of(p: int) -> StringName:
	if p < 32:
		return SHAPE_GROUPS[p >> 3]
	return _motif((p - 32) >> 1).get("group", &"")


func _family_of(p: int) -> StringName:
	if p < 32:
		return &"shapes"
	return _motif((p - 32) >> 1).get("family", &"")


func _family_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f: Dictionary in HalvesCrests.FAMILIES:
		out.append(f.get("id", &""))
	return out


func _same_value(a: Variant, b: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	var texts := [TYPE_STRING, TYPE_STRING_NAME]
	if typeof(a) in numbers and typeof(b) in numbers:
		return float(a) == float(b)
	if typeof(a) in texts and typeof(b) in texts:
		return String(a) == String(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


## docs/HALVES.md, HalvesCrests: the expected similarity of two valid pairs.
func _expected_similarity(a: int, b: int) -> float:
	if a == b:
		return 1.0
	if _group_of(a) != _group_of(b):
		return 0.0
	if a < 32 and b < 32:
		var same_mark := (a & 3) == (b & 3)
		return 0.8 if same_mark else 0.6
	# A v2 shape and a crest in the same group (the contract does not single this case out): the
	# literal formula, with no spec for the v2 pair, so nothing is shared.
	var spec_a: Dictionary = {} if a < 32 else _motif((a - 32) >> 1).get("spec", {})
	var spec_b: Dictionary = {} if b < 32 else _motif((b - 32) >> 1).get("spec", {})
	var keys := {}
	for k: Variant in spec_a:
		keys[k] = true
	for k: Variant in spec_b:
		keys[k] = true
	var shared := 0
	for k: Variant in keys:
		if spec_a.has(k) and spec_b.has(k) and _same_value(spec_a[k], spec_b[k]):
			shared += 1
	var value := 0.5 + 0.4 * float(shared) / float(maxi(1, keys.size()))
	if _pair_cut(a) != _pair_cut(b):
		value -= 0.1
	return value


## A pair's cut: bit 2 of a v2 pair (shape << 3 | cut << 2 | mark), bit 0 of a crest pair.
func _pair_cut(p: int) -> int:
	return (p >> 2) & 1 if p < 32 else p & 1


## The first two motifs that share a group, and a motif of another group: [m1, m2, m3].
func _look_alikes() -> Array[int]:
	var out: Array[int] = []
	for m1: int in _count():
		for m2: int in range(m1 + 1, _count()):
			if _motif(m1).get("group") == _motif(m2).get("group"):
				for m3: int in _count():
					if _motif(m3).get("group") != _motif(m1).get("group"):
						out.assign([m1, m2, m3])
						return out
	return out


func _p(text: String) -> int:
	return HalvesFace.pair_from_text(text)


func _all_pairs() -> Array[int]:
	var out: Array[int] = _v2_pairs()
	out.append_array(_crest_pairs())
	return out


# --- pair numbering and crest faces ---


func test_crest_pairs_start_at_32() -> void:
	assert_eq(HalvesCrests.FIRST_PAIR, 32)
	assert_eq(HalvesCrests.motif_count(), _count())
	assert_gt(_count(), 0, "the catalogue has motifs")
	for m: int in _count():
		for c: int in 2:
			assert_eq(HalvesCrests.pair_of(m, c), 32 + m * 2 + c, "pair_of(%d, %d)" % [m, c])


func test_make_crest_packs_pair_and_side() -> void:
	for m: int in _count():
		for c: int in 2:
			if not _allows(m, c):
				continue
			for side: int in 2:
				var f := HalvesFace.make_crest(m, c, side)
				assert_eq(f, ((32 + m * 2 + c) << 1) | side, "make_crest(%d, %d, %d)" % [m, c, side])
				assert_eq(HalvesFace.pair_key(f), 32 + m * 2 + c)
				assert_eq(HalvesFace.side(f), side)
				assert_eq(HalvesFace.mate(f), f ^ 1)
				assert_true(HalvesFace.matches(f, HalvesFace.mate(f)))


func test_face_64_is_the_first_crest() -> void:
	# v2 had no face 64 (shape value 4); v3 makes it the first motif, vertical cut, side a.
	var first: StringName = _motif(0).get("id")
	assert_true(HalvesFace.is_valid(64))
	assert_true(HalvesFace.is_crest(64))
	assert_eq(HalvesFace.to_text(64), "%s:v:a" % first)
	assert_eq(HalvesFace.from_text("%s:v:a" % first), 64)
	assert_eq(HalvesFace.make_crest(0, 0, 0), 64)


func test_crest_face_parts() -> void:
	for m: int in _count():
		for c: int in 2:
			if not _allows(m, c):
				continue
			for side: int in 2:
				var f := HalvesFace.make_crest(m, c, side)
				var label := "%s cut %d side %d" % [_motif(m).get("id"), c, side]
				assert_true(HalvesFace.is_valid(f), label + ": valid")
				assert_true(HalvesFace.is_crest(f), label + ": is_crest")
				assert_eq(HalvesFace.shape(f), -1, label + ": no shape")
				assert_eq(HalvesFace.mark(f), -1, label + ": no mark")
				assert_eq(HalvesFace.cut(f), c, label + ": cut")
				assert_eq(HalvesFace.cut(f), (f >> 1) & 1, label + ": a crest's cut is bit 1")
				assert_eq(HalvesFace.side(f), side, label + ": side")
				assert_eq(HalvesFace.family(f), _motif(m).get("family"), label + ": family")
				assert_eq(HalvesFace.group(f), _motif(m).get("group"), label + ": group")


func test_v2_faces_keep_their_numbers_and_parts() -> void:
	for f: int in _v2_faces():
		var label := HalvesFace.to_text(f)
		assert_false(HalvesFace.is_crest(f), label)
		assert_eq(HalvesFace.pair_key(f), f >> 1, label)
		assert_eq(HalvesFace.shape(f), f >> 4, label + ": shape")
		assert_eq(HalvesFace.cut(f), (f >> 3) & 1, label + ": a v2 cut is bit 3")
		assert_eq(HalvesFace.mark(f), (f >> 1) & 3, label + ": mark")
		assert_eq(HalvesFace.family(f), &"shapes", label + ": family")
		assert_eq(HalvesFace.group(f), SHAPE_GROUPS[f >> 4], label + ": group is the shape name")
	assert_eq(_v2_faces().size(), 42, "test setup")


func test_unknown_motifs_are_invalid() -> void:
	var end := _end_pair()
	for p: int in [end, end + 1, end + 2, end + 51, 1000]:
		assert_false(HalvesCrests.is_valid_pair(p), "pair %d is past the catalogue" % p)
		assert_false(HalvesFace.is_valid(p << 1), "face %d (pair %d, side a)" % [p << 1, p])
		assert_false(HalvesFace.is_valid((p << 1) | 1), "face %d (pair %d, side b)" % [(p << 1) | 1, p])
		assert_eq(HalvesCrests.motif_of(p), -1)
	assert_false(HalvesCrests.is_valid_pair(-1))
	assert_false(HalvesCrests.is_valid_pair(-32))


func test_cuts_a_motif_does_not_allow_are_invalid() -> void:
	var disallowed := 0
	for m: int in _count():
		for c: int in 2:
			var p := 32 + m * 2 + c
			assert_eq(HalvesCrests.is_valid_pair(p), _allows(m, c), "pair %d (%s, cut %d)" % [p, _motif(m).get("id"), c])
			assert_eq(HalvesFace.is_valid(p << 1), _allows(m, c))
			assert_eq(HalvesFace.is_valid((p << 1) | 1), _allows(m, c))
			if not _allows(m, c):
				disallowed += 1
				assert_eq(HalvesFace.from_text("%s:%s:a" % [_motif(m).get("id"), CUT_TEXT[c]]), -1)
				assert_eq(HalvesFace.pair_from_text("%s:%s" % [_motif(m).get("id"), CUT_TEXT[c]]), -1)
	gut.p("motif cuts not allowed in the catalogue: %d" % disallowed)


func test_valid_faces_up_to_the_end_of_the_catalogue() -> void:
	var want := 42 + 2 * _crest_pairs().size()
	var count := 0
	for f: int in range(-4, (_end_pair() + 4) << 1):
		if HalvesFace.is_valid(f):
			count += 1
	assert_eq(count, want, "42 v2 faces + two per allowed motif cut, nothing else")


# --- decoys (v3) ---


func test_decoy_between_crests_is_same_group_not_a_match() -> void:
	var faces := _crest_faces()
	var wrong: Array[String] = []
	for a: int in faces:
		for b: int in faces:
			var mates := (a >> 1) == (b >> 1) and (a & 1) != (b & 1)
			var want := _group_of(a >> 1) == _group_of(b >> 1) and not mates
			if HalvesFace.is_decoy(a, b) != want:
				wrong.append("decoy %s / %s" % [HalvesFace.to_text(a), HalvesFace.to_text(b)])
			if HalvesFace.matches(a, b) != mates:
				wrong.append("match %s / %s" % [HalvesFace.to_text(a), HalvesFace.to_text(b)])
	assert_eq(wrong.size(), 0, "matches / is_decoy disagree with the rules on %d pairs, e.g. %s" % [wrong.size(), wrong.slice(0, 5)])


func test_decoy_between_v2_shapes_is_the_v2_rule() -> void:
	var faces := _v2_faces()
	var wrong: Array[String] = []
	for a: int in faces:
		for b: int in faces:
			var want := (a >> 4) == (b >> 4) and not ((a >> 1) == (b >> 1) and (a & 1) != (b & 1))
			if HalvesFace.is_decoy(a, b) != want:
				wrong.append("%s / %s" % [HalvesFace.to_text(a), HalvesFace.to_text(b)])
	assert_eq(wrong.size(), 0, "v2 decoys changed on %d pairs, e.g. %s" % [wrong.size(), wrong.slice(0, 5)])


func test_decoy_between_a_shape_and_a_crest_follows_the_groups() -> void:
	# Literal reading of "Decoy (v3): same look-alike group, not a match": a shape and a crest are a
	# decoy only if their group names are equal (a shape and a crest never match).
	var wrong: Array[String] = []
	for a: int in _v2_faces():
		for b: int in _crest_faces():
			var want := _group_of(a >> 1) == _group_of(b >> 1)
			if HalvesFace.is_decoy(a, b) != want or HalvesFace.is_decoy(b, a) != want:
				wrong.append("%s / %s" % [HalvesFace.to_text(a), HalvesFace.to_text(b)])
			if HalvesFace.matches(a, b):
				wrong.append("%s matches %s" % [HalvesFace.to_text(a), HalvesFace.to_text(b)])
	assert_eq(wrong.size(), 0, "%d shape/crest pairs, e.g. %s" % [wrong.size(), wrong.slice(0, 5)])


func test_crest_decoy_examples() -> void:
	var la := _look_alikes()
	assert_eq(la.size(), 3, "test setup: two look-alike motifs and one of another group")
	if la.size() != 3:
		return
	var a := HalvesFace.make_crest(la[0], 0, 0)
	assert_true(HalvesFace.is_decoy(a, a), "a twin is a decoy")
	assert_false(HalvesFace.is_decoy(a, a ^ 1), "the mate is a match, not a decoy")
	assert_true(HalvesFace.is_decoy(a, HalvesFace.make_crest(la[1], 0, 1)), "a look-alike, other side")
	assert_true(HalvesFace.is_decoy(a, HalvesFace.make_crest(la[1], 0, 0)), "a look-alike, same side")
	if _allows(la[0], 1):
		assert_true(HalvesFace.is_decoy(a, HalvesFace.make_crest(la[0], 1, 1)), "same motif, other cut")
	assert_false(HalvesFace.is_decoy(a, HalvesFace.make_crest(la[2], 0, 1)), "another group is never a decoy")
	assert_false(HalvesFace.is_decoy(a, HalvesFace.make_crest(la[2], 0, 0)), "another group is never a decoy")


func test_try_pair_on_crests() -> void:
	var la := _look_alikes()
	if la.size() != 3:
		fail_test("no look-alike motifs in the catalogue")
		return
	var id1: StringName = _motif(la[0]).get("id")
	var id2: StringName = _motif(la[1]).get("id")
	var id3: StringName = _motif(la[2]).get("id")
	var s := H.state(H.column(5), ["%s:v:a" % id1, "%s:v:b" % id2, "%s:v:b" % id3, "%s:v:b" % id1, "%s:v:a" % id1])
	assert_eq(s.try_pair(0, 1), R.MISMATCH, "look-alikes are a mistake")
	assert_eq(s.mistakes, 1)
	assert_eq(s.try_pair(0, 2), R.SWITCH, "another group only moves the selection")
	assert_eq(s.try_pair(0, 4), R.MISMATCH, "twins are a mistake")
	assert_eq(s.mistakes, 2)
	assert_eq(s.try_pair(4, 3), R.MATCH, "the other half of the same crest")
	assert_eq(s.tiles_left(), 3)


# --- text forms ---


func test_crest_text_round_trips() -> void:
	for m: int in _count():
		var id: StringName = _motif(m).get("id")
		for c: int in 2:
			if not _allows(m, c):
				continue
			var pair := 32 + m * 2 + c
			assert_eq(HalvesFace.pair_to_text(pair), "%s:%s" % [id, CUT_TEXT[c]])
			assert_eq(HalvesFace.pair_from_text("%s:%s" % [id, CUT_TEXT[c]]), pair)
			for side: int in 2:
				var f := (pair << 1) | side
				var text := "%s:%s:%s" % [id, CUT_TEXT[c], SIDE_TEXT[side]]
				assert_eq(HalvesFace.to_text(f), text)
				assert_eq(HalvesFace.from_text(text), f, text)
				assert_eq(HalvesFace.from_text(HalvesFace.to_text(f)), f)
				assert_true(HalvesFace.to_text(f).begins_with(HalvesFace.pair_to_text(pair) + ":"))


func test_the_contract_example() -> void:
	var m := HalvesCrests.motif_index(&"sakura")
	if m < 0:
		pending("no 'sakura' motif in the catalogue")
		return
	assert_eq(HalvesFace.from_text("sakura:v:a"), HalvesFace.make_crest(m, 0, 0))
	assert_eq(HalvesFace.pair_from_text("sakura:v"), HalvesCrests.pair_of(m, 0))
	assert_eq(HalvesFace.pair_to_text(HalvesCrests.pair_of(m, 0)), "sakura:v")


func test_invalid_crest_texts() -> void:
	var id := String(_motif(0).get("id"))
	for text: String in [id, id + ":v", id + ":x:a", id + ":v:c", id + ":v:-:a", id + ":v:a:b", id + "::a",
			":v:a", "no_such_crest:v:a", "circle:v:a", id + ":v:dot", id + " v a"]:
		assert_eq(HalvesFace.from_text(text), -1, "'%s' is not a face" % text)
	for text: String in [id, id + ":", id + ":x", id + ":v:a", id + ":v:-", "no_such_crest:v", ":v", "circle:v"]:
		assert_eq(HalvesFace.pair_from_text(text), -1, "'%s' is not a pair" % text)


func test_v2_texts_are_unchanged() -> void:
	for f: int in _v2_faces():
		var text := HalvesFace.to_text(f)
		assert_eq(text.split(":").size(), 4, text)
		assert_eq(HalvesFace.from_text(text), f)
	assert_eq(HalvesFace.to_text(HalvesFace.make(HalvesFace.Shape.CIRCLE, HalvesFace.Cut.VERTICAL, HalvesFace.Mark.DOT, 0)), "circle:v:dot:a")


# --- HalvesCrests: the catalogue ---


func test_families_are_unique_and_named() -> void:
	var seen := {}
	for f: Dictionary in HalvesCrests.FAMILIES:
		var id: StringName = f.get("id", &"")
		assert_ne(id, &"", "a family id")
		assert_false(seen.has(id), "family %s is listed once" % id)
		seen[id] = true
		assert_ne(String(f.get("name", "")), "", "family %s has a name" % id)
	assert_false(seen.has(&"shapes"), "'shapes' is the v2 family, not a crest family")


func test_motifs_follow_the_catalogue_rules() -> void:
	var seen := {}
	var families := _family_ids()
	for m: int in _count():
		var motif := _motif(m)
		var id: StringName = motif.get("id", &"")
		assert_ne(id, &"", "motif %d has an id" % m)
		assert_false(seen.has(id), "motif id %s is unique" % id)
		seen[id] = true
		assert_ne(String(motif.get("name", "")), "", "%s has a name" % id)
		assert_has(families, motif.get("family", &""), "%s: its family is in FAMILIES" % id)
		assert_ne(motif.get("group", &""), &"", "%s has a look-alike group" % id)
		var cuts: Array = motif.get("cuts", [])
		assert_false(cuts.is_empty(), "%s allows at least one cut" % id)
		for c: Variant in cuts:
			assert_true(int(c) == 0 or int(c) == 1, "%s: cut %s is 0 or 1" % [id, c])
		var spec: Dictionary = motif.get("spec", {})
		assert_false(spec.is_empty(), "%s has a spec" % id)


func test_motif_index() -> void:
	for m: int in _count():
		assert_eq(HalvesCrests.motif_index(_motif(m).get("id")), m)
	assert_eq(HalvesCrests.motif_index(&"no_such_crest"), -1)
	assert_eq(HalvesCrests.motif_index(&""), -1)
	assert_eq(HalvesCrests.motif_index(&"circle"), -1, "v2 shapes are not motifs")


func test_never_in_the_catalogue() -> void:
	for m: int in _count():
		var motif := _motif(m)
		var id := String(motif.get("id", "")).to_lower()
		var name := String(motif.get("name", "")).to_lower()
		var spec: Dictionary = motif.get("spec", {})
		assert_false(int(spec.get("petals", 0)) == 16, "%s: no 16-petal flower (imperial chrysanthemum)" % id)
		assert_false(name.contains("chrysanthemum") or id.begins_with("kiku"), "%s: no imperial chrysanthemum" % id)
		assert_false(name.contains("paulownia") or id.contains("kiri"), "%s: no government paulownia" % id)
		assert_false(name.contains("hollyhock") or id.contains("aoi"), "%s: no Tokugawa hollyhock" % id)
		var three_diamonds := StringName(spec.get("kind", &"")) == &"diamond" and int(spec.get("count", 0)) == 3
		assert_false(three_diamonds or id.contains("mitsubishi") or id.contains("mitsu_bishi"),
				"%s: no three diamonds in a triangle" % id)


func test_pair_helpers_round_trip() -> void:
	for m: int in _count():
		for c: int in 2:
			var p := HalvesCrests.pair_of(m, c)
			assert_eq(HalvesCrests.motif_of(p), m, "motif_of(%d)" % p)
			assert_eq(HalvesCrests.cut_of(p), c, "cut_of(%d)" % p)


func test_motif_of_is_minus_one_for_v2_and_unknown_pairs() -> void:
	for p: int in 32:
		assert_eq(HalvesCrests.motif_of(p), -1, "v2 pair %d" % p)
	assert_eq(HalvesCrests.motif_of(_end_pair()), -1)
	assert_eq(HalvesCrests.motif_of(_end_pair() + 1), -1)
	assert_eq(HalvesCrests.motif_of(-1), -1)


func test_cut_of_works_for_v2_pairs() -> void:
	for p: int in _v2_pairs():
		assert_eq(HalvesCrests.cut_of(p), (p >> 2) & 1, "v2 pair %s" % HalvesFace.pair_to_text(p))
	assert_eq(HalvesCrests.cut_of(HalvesFace.pair_from_text("circle:h:-")), 1)
	assert_eq(HalvesCrests.cut_of(HalvesFace.pair_from_text("tri:v:dot")), 0)


func test_is_valid_pair() -> void:
	for p: int in 32:
		assert_eq(HalvesCrests.is_valid_pair(p), _v2_pair_valid(p), "v2 pair %d" % p)
	assert_eq(_v2_pairs().size(), 21, "test setup: 24 combinations - 3 horizontal triangles")
	for p: int in _crest_pairs():
		assert_true(HalvesCrests.is_valid_pair(p), "crest pair %d" % p)
	assert_false(HalvesCrests.is_valid_pair(-1))
	assert_false(HalvesCrests.is_valid_pair(_end_pair()))


func test_family_of_and_group_of() -> void:
	for p: int in _v2_pairs():
		assert_eq(HalvesCrests.family_of(p), &"shapes", "v2 pair %d" % p)
		assert_eq(HalvesCrests.group_of(p), SHAPE_GROUPS[p >> 3], "v2 pair %d" % p)
	assert_eq(HalvesCrests.group_of(HalvesFace.pair_from_text("circle:h:dot")), &"circle")
	assert_eq(HalvesCrests.group_of(HalvesFace.pair_from_text("tri:v:-")), &"tri")
	assert_eq(HalvesCrests.group_of(HalvesFace.pair_from_text("square:v:line")), &"square")
	assert_eq(HalvesCrests.group_of(HalvesFace.pair_from_text("diamond:h:-")), &"diamond")
	for p: int in _crest_pairs():
		assert_eq(HalvesCrests.family_of(p), _family_of(p), "crest pair %d" % p)
		assert_eq(HalvesCrests.group_of(p), _group_of(p), "crest pair %d" % p)


func test_family_of_an_invalid_pair_is_empty() -> void:
	for p: int in [-1, _end_pair(), _end_pair() + 1, 1000]:
		assert_eq(HalvesCrests.family_of(p), &"", "pair %d" % p)
	for p: int in 32:
		if not _v2_pair_valid(p):
			assert_eq(HalvesCrests.family_of(p), &"", "invalid v2 pair %d (mark 3 or a horizontal triangle)" % p)


func test_group_of_an_unknown_pair_is_empty() -> void:
	# Not spelled out for group_of; read the same way as family_of ("&\"\" if invalid").
	for p: int in [-1, _end_pair(), _end_pair() + 1, 1000]:
		assert_eq(HalvesCrests.group_of(p), &"", "pair %d" % p)


func test_pairs_in_family() -> void:
	var listed := {}
	var families := _family_ids()
	families.append(&"shapes")
	for fam: StringName in families:
		var got := HalvesCrests.pairs_in_family(fam)
		var want := PackedInt32Array()
		for p: int in range(0, _end_pair()):
			var valid := _v2_pair_valid(p) if p < 32 else _allows((p - 32) >> 1, p & 1)
			if valid and _family_of(p) == fam:
				want.append(p)
		assert_eq(got, want, "pairs_in_family(%s): every valid pair of the family, ascending" % fam)
		for p: int in got:
			assert_false(listed.has(p), "pair %d is in one family only" % p)
			listed[p] = true
			assert_true(HalvesCrests.is_valid_pair(p))
			assert_eq(HalvesCrests.family_of(p), fam)
	assert_eq(HalvesCrests.pairs_in_family(&"shapes"), PackedInt32Array(_v2_pairs()), "the v2 pairs")
	assert_eq(listed.size(), _v2_pairs().size() + _crest_pairs().size(), "every valid pair has a family")
	assert_eq(HalvesCrests.pairs_in_family(&"no_such_family"), PackedInt32Array())


# --- similarity ---


## Checks similarity against the contract on every ordered pair of `pairs_a` x `pairs_b`; returns
## the disagreements (0..1 range, 1 only for the same pair, the formula, symmetry).
func _similarity_errors(pairs_a: Array[int], pairs_b: Array[int]) -> Array[String]:
	var wrong: Array[String] = []
	for a: int in pairs_a:
		for b: int in pairs_b:
			var want := _expected_similarity(a, b)
			var got := HalvesCrests.similarity(a, b)
			var label := "(%s, %s)" % [HalvesFace.pair_to_text(a), HalvesFace.pair_to_text(b)]
			if got < 0.0 or got > 1.0:
				wrong.append("%s = %.3f is outside 0..1" % [label, got])
			if a != b and is_equal_approx(got, 1.0):
				wrong.append("%s = 1 for different pairs" % label)
			if absf(got - want) > 1e-5:
				wrong.append("%s = %.4f, want %.4f" % [label, got, want])
			if absf(got - HalvesCrests.similarity(b, a)) > 1e-6:
				wrong.append("%s = %.4f but reversed %.4f" % [label, got, HalvesCrests.similarity(b, a)])
	return wrong


func test_similarity_between_crests() -> void:
	var wrong := _similarity_errors(_crest_pairs(), _crest_pairs())
	assert_eq(wrong.size(), 0, "%d wrong, e.g. %s" % [wrong.size(), wrong.slice(0, 6)])


func test_similarity_between_v2_shapes() -> void:
	var wrong := _similarity_errors(_v2_pairs(), _v2_pairs())
	assert_eq(wrong.size(), 0, "%d wrong, e.g. %s" % [wrong.size(), wrong.slice(0, 6)])


func test_similarity_between_a_shape_and_a_crest() -> void:
	# 0 across groups. Within a group (only when a crest group has a shape's name) the contract has
	# no special case: the formula with no spec for the v2 pair (0.5, or 0.4 when the cuts differ),
	# and in any case the same value both ways round.
	var shared: Array[String] = []
	for p: int in _crest_pairs():
		if _group_of(p) in SHAPE_GROUPS and not (String(_group_of(p)) in shared):
			shared.append(String(_group_of(p)))
	if not shared.is_empty():
		gut.p("crest groups named like a v2 shape: %s" % [shared])
	var wrong := _similarity_errors(_v2_pairs(), _crest_pairs())
	wrong.append_array(_similarity_errors(_crest_pairs(), _v2_pairs()))
	assert_eq(wrong.size(), 0, "%d wrong, e.g. %s" % [wrong.size(), wrong.slice(0, 6)])


func test_similarity_examples() -> void:
	assert_almost_eq(HalvesCrests.similarity(_p("circle:v:-"), _p("circle:v:-")), 1.0, 1e-6)
	assert_almost_eq(HalvesCrests.similarity(_p("circle:v:-"), _p("circle:h:-")), 0.8, 1e-6, "same mark, other cut")
	assert_almost_eq(HalvesCrests.similarity(_p("circle:v:-"), _p("circle:v:dot")), 0.6, 1e-6, "another mark")
	assert_almost_eq(HalvesCrests.similarity(_p("circle:v:-"), _p("circle:h:line")), 0.6, 1e-6, "another mark and cut")
	assert_almost_eq(HalvesCrests.similarity(_p("square:v:-"), _p("diamond:v:-")), 0.0, 1e-6, "other shapes")
	for m: int in _count():
		assert_almost_eq(HalvesCrests.similarity(HalvesCrests.pair_of(m, 0), HalvesCrests.pair_of(m, 0)), 1.0, 1e-6)
	# The same motif cut the other way: every spec entry shared, minus 0.1 for the cut.
	for m: int in _count():
		if _allows(m, 0) and _allows(m, 1):
			assert_almost_eq(HalvesCrests.similarity(HalvesCrests.pair_of(m, 0), HalvesCrests.pair_of(m, 1)), 0.8, 1e-6,
					"%s v / h" % _motif(m).get("id"))


# --- HalvesCrest: polygons ---


func _area(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


func _layer_area(layer: Dictionary) -> float:
	var total := 0.0
	var polygons: Array = layer.get("polygons", [])
	for poly: PackedVector2Array in polygons:
		total += _area(poly)
	return total


## True when every point is on the side of the cut that `side` keeps (section 2, HalvesCrest).
func _in_half(pt: Vector2, cut: int, side: int) -> bool:
	var v := pt.x if cut == 0 else pt.y
	return v <= EPS if side == 0 else v >= -EPS


func test_whole_crests_have_ink_and_fit_the_unit_circle() -> void:
	for m: int in _count():
		var id: StringName = _motif(m).get("id")
		var layers := HalvesCrest.layers(m)
		assert_false(layers.is_empty(), "%s has layers" % id)
		var ink_area := 0.0
		var reach := 0.0
		for layer: Dictionary in layers:
			assert_true(layer.get("ink") is bool, "%s: each layer says ink or paper" % id)
			var polygons: Array = layer.get("polygons", [])
			for poly: PackedVector2Array in polygons:
				assert_gte(poly.size(), 3, "%s: a polygon has 3 points or more" % id)
				for pt: Vector2 in poly:
					reach = maxf(reach, pt.length())
			if layer.get("ink", false):
				ink_area += _layer_area(layer)
		assert_gt(ink_area, 0.01, "%s draws some ink" % id)
		assert_true(reach <= 1.0 + EPS, "%s fits the circle of radius 1 (it reaches %.3f)" % [id, reach])


func test_layers_are_stable_between_calls() -> void:
	for m: int in _count():
		var first := HalvesCrest.layers(m)
		var again := HalvesCrest.layers(m)
		assert_eq(again, first, "layers(%d) twice" % m)
		for c: int in 2:
			if not _allows(m, c):
				continue
			for side: int in 2:
				assert_eq(HalvesCrest.half_layers(m, c, side), HalvesCrest.half_layers(m, c, side),
						"half_layers(%d, %d, %d) twice" % [m, c, side])


func test_halves_lie_in_their_half_plane() -> void:
	for m: int in _count():
		var id: StringName = _motif(m).get("id")
		for c: int in 2:
			if not _allows(m, c):
				continue
			for side: int in 2:
				var halves := HalvesCrest.half_layers(m, c, side)
				var label := "%s cut %s side %s" % [id, CUT_TEXT[c], SIDE_TEXT[side]]
				var polygons_seen := 0
				var stray := 0
				for layer: Dictionary in halves:
					var polygons: Array = layer.get("polygons", [])
					for poly: PackedVector2Array in polygons:
						polygons_seen += 1
						for pt: Vector2 in poly:
							if not _in_half(pt, c, side):
								stray += 1
				assert_false(halves.is_empty(), label + ": half layers")
				assert_gt(polygons_seen, 0, label + ": some polygons")
				assert_eq(stray, 0, label + ": every point on its side of the cut")


## A large box covering the half-plane that (cut, side) keeps.
func _half_box(cut: int, side: int) -> PackedVector2Array:
	var f := 10.0
	var lo := Vector2(-f, -f)
	var hi := Vector2(f, f)
	if cut == 0:
		if side == 0:
			hi.x = 0.0
		else:
			lo.x = 0.0
	else:
		if side == 0:
			hi.y = 0.0
		else:
			lo.y = 0.0
	return PackedVector2Array([lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)])


## The area of a whole layer inside the half-plane, clipped here with Geometry2D (independent of
## HalvesCrest's own clipping).
func _clipped_area(layer: Dictionary, cut: int, side: int) -> float:
	var box := _half_box(cut, side)
	var total := 0.0
	var polygons: Array = layer.get("polygons", [])
	for poly: PackedVector2Array in polygons:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, box):
			total += _area(piece)
	return total


func _tolerance(area: float) -> float:
	return 0.002 + 0.01 * area


## Lines the half's layers up with the whole's, in order: a whole layer with ink or paper on this
## side must have a half layer (same ink flag) of the clipped area; one with (almost) nothing on
## this side may be left out. Returns the half's area per whole layer (0 when left out), and adds
## what does not line up to `errors`.
func _matched_areas(whole: Array[Dictionary], half: Array[Dictionary], cut: int, side: int, label: String,
		errors: Array[String]) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(whole.size())
	var j := 0
	for k: int in whole.size():
		var w: Dictionary = whole[k]
		var want := _clipped_area(w, cut, side)
		if j < half.size():
			var h: Dictionary = half[j]
			var got := _layer_area(h)
			if h.get("ink") == w.get("ink") and absf(got - want) <= _tolerance(want):
				out[k] = got
				j += 1
				continue
		if want > 1e-3:
			errors.append("%s: layer %d (%s) has area %.4f on this side, no half layer matches" % [
					label, k, "ink" if w.get("ink") else "paper", want])
	if j != half.size():
		errors.append("%s: %d half layers left over" % [label, half.size() - j])
	return out


func test_each_half_is_the_whole_clipped_to_its_side() -> void:
	var errors: Array[String] = []
	for m: int in _count():
		var whole := HalvesCrest.layers(m)
		for c: int in 2:
			if not _allows(m, c):
				continue
			for side: int in 2:
				var label := "%s cut %s side %s" % [_motif(m).get("id"), CUT_TEXT[c], SIDE_TEXT[side]]
				_matched_areas(whole, HalvesCrest.half_layers(m, c, side), c, side, label, errors)
	assert_eq(errors.size(), 0, "%d problems, e.g. %s" % [errors.size(), errors.slice(0, 6)])


func test_two_halves_add_up_to_the_whole() -> void:
	var errors: Array[String] = []
	for m: int in _count():
		var whole := HalvesCrest.layers(m)
		for c: int in 2:
			if not _allows(m, c):
				continue
			var label := "%s cut %s" % [_motif(m).get("id"), CUT_TEXT[c]]
			var a := _matched_areas(whole, HalvesCrest.half_layers(m, c, 0), c, 0, label + " side a", errors)
			var b := _matched_areas(whole, HalvesCrest.half_layers(m, c, 1), c, 1, label + " side b", errors)
			for k: int in whole.size():
				var want := _layer_area(whole[k])
				if absf(a[k] + b[k] - want) > _tolerance(want):
					errors.append("%s layer %d: halves %.4f + %.4f, whole %.4f" % [label, k, a[k], b[k], want])
	assert_eq(errors.size(), 0, "%d problems, e.g. %s" % [errors.size(), errors.slice(0, 6)])
