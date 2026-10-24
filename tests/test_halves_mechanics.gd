extends GutTest
## Contract v3 M3 mechanics, part 1: the gold crest (`kin`), HalvesFeatures with `turned` and `lucky`
## (normalize, validate, place steps 5-6 and the rng order), turned/lucky never change the rules,
## HalvesState lucky clocks, HalvesFill.with_gold_pair and HalvesConfig.LUCKY_*.
## Written from docs/HALVES.md (contract v3) alone, in a separate session from the implementation.

const H := preload("res://tests/halves_helpers.gd")
const R := HalvesState.Result
const B := HalvesGeometry.Block
const PLACE_LEVELS: Array[int] = [5, 12, 30, 45, 65]
const GOLD_LEVELS: Array[int] = [1, 2, 5, 10, 20, 35, 50, 75, 100]


func _rng(parts: Array) -> RandomNumberGenerator:
	return SeedService.make_rng(["test_halves_mechanics"] + parts, 3)


func _kin() -> int:
	return HalvesCrests.motif_index(&"kin")


## The gold pair: the kin crest with cut 0 (section 2, with_gold_pair).
func _gold_pair() -> int:
	return HalvesCrests.pair_of(_kin(), 0)


func _gold_a() -> int:
	return _gold_pair() << 1


func _gold_b() -> int:
	return (_gold_pair() << 1) | 1


func _level(n: int) -> HalvesLevelData:
	var data := HalvesLevels.get_level(n)
	if data == null:
		fail_test("level %d missing from %s" % [n, HalvesLevels.PATH])
	return data


## lucky_start as text with sorted keys, so typed and untyped dictionaries compare by content.
func _clocks(s: HalvesState) -> String:
	var out := {}
	for t: int in s.lucky_start:
		out[t] = int(s.lucky_start[t])
	return H.js(out)


# --- the gold crest and constants ---


func test_m3_constants() -> void:
	assert_eq(HalvesConfig.LUCKY_SNAPS, 3)
	assert_eq(HalvesConfig.LUCKY_COINS, 5)
	assert_eq(HalvesConfig.MEND_BUDGET, 4000, "solver nodes per mate when a mend chooses its mate")


func test_the_gold_crest_is_kin_in_family_and_group_gold() -> void:
	var kin := _kin()
	assert_true(kin >= 0, "motif kin is in the catalogue")
	if kin < 0:
		return
	var motif: Dictionary = HalvesCrests.MOTIFS[kin]
	assert_eq(motif.get("family"), &"gold")
	assert_eq(motif.get("group"), &"gold")
	var families: Array[Dictionary] = HalvesCrests.FAMILIES
	assert_eq(families[families.size() - 1].get("id"), &"gold", "the last family is gold")
	var in_gold := 0
	for m: int in HalvesCrests.motif_count():
		if HalvesCrests.MOTIFS[m].get("family") == &"gold":
			in_gold += 1
	assert_eq(in_gold, 1, "gold has one motif, kin")
	var pair := _gold_pair()
	assert_true(HalvesCrests.is_valid_pair(pair), "kin allows cut 0")
	assert_eq(HalvesCrests.family_of(pair), &"gold")
	assert_eq(HalvesCrests.group_of(pair), &"gold")
	assert_true(HalvesCrests.pairs_in_family(&"gold").has(pair))
	for p: int in HalvesCrests.pairs_in_family(&"gold"):
		assert_eq(HalvesCrests.motif_of(p), kin, "every gold pair is a kin pair")


func test_gold_faces() -> void:
	var a := _gold_a()
	var b := _gold_b()
	assert_eq(HalvesFace.from_text("kin:v:a"), a)
	assert_eq(HalvesFace.from_text("kin:v:b"), b)
	assert_true(HalvesFace.is_valid(a))
	assert_true(HalvesFace.is_crest(a))
	assert_eq(HalvesFace.family(a), &"gold")
	assert_eq(HalvesFace.family(b), &"gold")
	assert_eq(HalvesFace.group(a), &"gold")
	assert_true(HalvesFace.matches(a, b), "the gold pair matches like any pair")
	assert_true(HalvesFace.is_decoy(a, a), "two gold halves of the same side are twins")


func test_is_gold_is_the_gold_family() -> void:
	assert_true(HalvesState.is_gold(_gold_a()))
	assert_true(HalvesState.is_gold(_gold_b()))
	assert_false(HalvesState.is_gold(HalvesFace.from_text("circle:v:-:a")))
	assert_false(HalvesState.is_gold(HalvesFace.from_text("tri:v:dot:b")))
	var bad := ""
	var checked := 0
	for pair: int in HalvesCrests.FIRST_PAIR + 2 * HalvesCrests.motif_count():
		if not HalvesCrests.is_valid_pair(pair):
			continue
		for side: int in 2:
			var face := (pair << 1) | side
			checked += 1
			if HalvesState.is_gold(face) != (HalvesFace.family(face) == &"gold") and bad == "":
				bad = "face %s: is_gold %s" % [HalvesFace.to_text(face), HalvesState.is_gold(face)]
	assert_eq(bad, "")
	assert_true(checked > 64, "v2 and crest faces were checked")


# --- HalvesFeatures.normalize / validate / tile_count with turned and lucky ---


func test_normalize_turned_and_lucky() -> void:
	var raw := {"lucky": [9.0, 2.0, 2.0], "turned": [5.0, 1.0, 5.0], "gold": [7.0], "mist": [],
			"frost": [4.0, 3.0], "locks": [{"keys": [0.0], "locked": [6.0]}]}
	var got := HalvesFeatures.normalize(raw)
	assert_eq(got.keys(), ["locks", "frost", "gold", "turned", "lucky"], "key order locks, frost, mist, gold, turned, lucky")
	assert_eq(H.js(got), H.js({"locks": [{"keys": [0], "locked": [6]}], "frost": [3, 4], "gold": [7],
			"turned": [1, 5], "lucky": [2, 9]}))
	assert_eq(H.js(HalvesFeatures.normalize(got)), H.js(got), "idempotent")
	assert_eq(HalvesFeatures.normalize(got).keys(), got.keys(), "idempotent key order")


func test_normalize_turned_and_lucky_from_json() -> void:
	var parsed: Variant = JSON.parse_string('{"lucky": [8, 3, 8], "mist": [6], "turned": [2, 0], "frost": [1]}')
	var got := HalvesFeatures.normalize(parsed as Dictionary)
	assert_eq(got.keys(), ["frost", "mist", "turned", "lucky"])
	assert_eq(H.js(got), H.js({"frost": [1], "mist": [6], "turned": [0, 2], "lucky": [3, 8]}), "ints, sorted, no duplicates")
	assert_eq(H.js(HalvesFeatures.normalize(HalvesFeatures.normalize(got))), H.js(got))
	var only := HalvesFeatures.normalize({"turned": [4.0], "lucky": [4.0]})
	assert_eq(only.keys(), ["turned", "lucky"])
	assert_eq(H.js(only), H.js({"turned": [4], "lucky": [4]}), "one tile may be turned and lucky")


func test_normalize_drops_empty_turned_and_lucky() -> void:
	assert_eq(HalvesFeatures.normalize({"turned": [], "lucky": []}), {})
	var got := HalvesFeatures.normalize({"turned": [], "lucky": [1.0], "gold": []})
	assert_eq(H.js(got), H.js({"lucky": [1]}))


func test_validate_accepts_turned_and_lucky_in_range() -> void:
	var g := H.geometry(H.column(6))
	var good := {"locks": [{"keys": [0], "locked": [5]}], "frost": [2], "mist": [3], "turned": [0, 5, 3], "lucky": [5, 0, 2]}
	var errors := HalvesFeatures.validate(g, good)
	assert_true(errors.is_empty(), ", ".join(errors))
	var with_order := HalvesFeatures.validate(g, {"turned": [0, 1, 2, 3, 4, 5], "lucky": [0, 1, 2, 3, 4, 5]},
			H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]))
	assert_true(with_order.is_empty(), "turned and lucky never block: " + ", ".join(with_order))


func _assert_rejected(errors: PackedStringArray, why: String) -> void:
	assert_false(errors.is_empty(), "should be rejected: %s" % why)
	for e: String in errors:
		assert_ne(e.strip_edges(), "", "%s: every report is a readable sentence" % why)


func test_validate_rejects_turned_and_lucky_out_of_range() -> void:
	var g := H.geometry(H.column(6))
	_assert_rejected(HalvesFeatures.validate(g, {"turned": [6]}), "turned id == size")
	_assert_rejected(HalvesFeatures.validate(g, {"turned": [-1]}), "negative turned id")
	_assert_rejected(HalvesFeatures.validate(g, {"turned": [1, 200]}), "turned id far out")
	_assert_rejected(HalvesFeatures.validate(g, {"lucky": [6]}), "lucky id == size")
	_assert_rejected(HalvesFeatures.validate(g, {"lucky": [-3]}), "negative lucky id")
	_assert_rejected(HalvesFeatures.validate(g, {"lucky": [2, 64]}), "lucky id far out")


func test_tile_count_does_not_count_turned_or_lucky() -> void:
	# tile_count: distinct tiles that are key, locked, frost or mist (unchanged in v3).
	assert_eq(HalvesFeatures.tile_count({"turned": [1, 2, 3], "lucky": [4, 5]}), 0)
	assert_eq(HalvesFeatures.tile_count({"frost": [1], "mist": [2], "turned": [1, 7], "lucky": [2, 8]}), 2)


# --- turned and lucky never change the rules ---


## Eight tiles with side neighbours, a bridge and a stack (same board as test_halves_features).
func _touch_board() -> HalvesGeometry:
	return H.geometry([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(6, 0, 0), Vector3i(4, 1, 0),
			Vector3i(1, 2, 0), Vector3i(3, 4, 0), Vector3i(1, 0, 1), Vector3i(0, 0, 2)])


func test_turned_and_lucky_do_not_change_the_rules() -> void:
	var plain := _touch_board()
	var all: Array = [0, 1, 2, 3, 4, 5, 6, 7]
	var g := plain.with_features({"turned": all, "lucky": all})
	assert_true(g.has_features())
	assert_eq(H.js(g.features), H.js({"turned": all, "lucky": all}))
	var none := HalvesBits.empty()
	for i: int in g.size():
		if g.lock_need.size() == g.size():
			assert_eq(g.lock_need[i], none, "lock_need[%d]" % i)
		if g.frost_need.size() == g.size():
			assert_eq(g.frost_need[i], none, "frost_need[%d]" % i)
	var bad := ""
	for r: int in 1 << g.size():
		var rem := H.from_int(r)
		if g.free_mask(rem) != plain.free_mask(rem) and bad == "":
			bad = "free_mask(%s) differs" % [H.ids(rem)]
		for i: int in g.size():
			if HalvesBits.has(rem, i) and g.blocked_reason(i, rem) != plain.blocked_reason(i, rem) and bad == "":
				bad = "blocked_reason(%d, %s) differs" % [i, H.ids(rem)]
	assert_eq(bad, "", "turned and lucky have no effect on the rules")


func test_lucky_and_turned_stay_with_their_positions_on_a_shuffle() -> void:
	var data := _level(12)
	if data == null:
		return
	var plain := HalvesGeometry.from_positions(data.positions)
	var features := {"turned": [0, 3, 7], "lucky": [1, 5, 9, 20]}
	var s := HalvesState.new(plain.with_features(features), data.faces)
	for k: int in 3:
		assert_eq(s.try_pair(data.solution[k].x, data.solution[k].y), R.MATCH)
	var lucky_before := s.lucky.duplicate()
	var result := HalvesFill.shuffle(s, data.solution, _rng(["positional"]))
	assert_false(result.is_empty())
	if result.is_empty():
		return
	s.apply_deal(result["remaining"], result["faces"])
	assert_eq(s.lucky, lucky_before, "lucky is positional")
	assert_eq(s.lucky, H.mask_of([1, 5, 9, 20]))
	assert_eq(H.js(s.geometry.features), H.js(features), "turned and lucky stay on the geometry")


# --- HalvesFeatures.place steps 5 and 6 ---


## Shuffle each group with HalvesFill.shuffle_ints (preferred first), then take the first `count`.
func _take(preferred: PackedInt32Array, rest: PackedInt32Array, count: int, rng: RandomNumberGenerator) -> Array:
	var first := preferred.duplicate()
	HalvesFill.shuffle_ints(first, rng)
	var second := rest.duplicate()
	HalvesFill.shuffle_ints(second, rng)
	var out: Array = []
	for t: int in first:
		if out.size() < count:
			out.append(t)
	for t: int in second:
		if out.size() < count:
			out.append(t)
	return out


func _has_look_alike(faces: PackedInt32Array, t: int) -> bool:
	for j: int in faces.size():
		if j != t and faces[j] >= 0 and HalvesFace.group(faces[j]) == HalvesFace.group(faces[t]) \
				and HalvesFace.pair_key(faces[j]) != HalvesFace.pair_key(faces[t]):
			return true
	return false


func _live_trap_y(g: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array) -> PackedInt64Array:
	var live_y := HalvesBits.empty()
	for link: Vector4i in HalvesFill.trap_links(g, order):
		var other_q := order[link.x].x + order[link.x].y - link.z
		var other_p := order[link.y].x + order[link.y].y - link.w
		if HalvesFace.matches(faces[link.z], faces[link.w]) and HalvesFace.matches(faces[other_q], faces[other_p]):
			HalvesBits.set_bit(live_y, link.w)
	return live_y


## Steps 2-6 of `place` exactly as section 2 writes them, for a spec without locks (no key_pairs)
## whose other five counts are all > 0, so every step builds its candidate list (ascending ids,
## preferred group then the rest, each shuffled with shuffle_ints and the one rng, in step order).
func _ref_place(g: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array, spec: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var n := order.size()
	var size := g.size()
	var step := H.steps_of(order, size)
	var free0 := g.free_mask(g.full_mask())
	# 2. Frost: a touching tile with a strictly smaller step; free at the start first.
	var pref := PackedInt32Array()
	var rest := PackedInt32Array()
	for t: int in size:
		var early := false
		for j: int in HalvesBits.ids(g.touch[t]):
			early = early or step[j] < step[t]
		if early:
			if HalvesBits.has(free0, t):
				pref.append(t)
			else:
				rest.append(t)
	var frost := HalvesFeatures.mask(_take(pref, rest, int(spec["frost"]), rng))
	# 3. Mist: not free at the start, not frost, not a live trap's covered tile; one group.
	var live_y := _live_trap_y(g, order, faces)
	var mist_cand := PackedInt32Array()
	for t: int in size:
		if not HalvesBits.has(free0, t) and not HalvesBits.has(frost, t) and not HalvesBits.has(live_y, t):
			mist_cand.append(t)
	var mist := HalvesFeatures.mask(_take(PackedInt32Array(), mist_cand, int(spec["mist"]), rng))
	# 4. Gold: unused tiles on z >= 1 first, then layer 0.
	var used := HalvesBits.union(frost, mist)
	pref = PackedInt32Array()
	rest = PackedInt32Array()
	for t: int in size:
		if HalvesBits.has(used, t):
			continue
		if g.positions[t].z >= 1:
			pref.append(t)
		else:
			rest.append(t)
	var gold := HalvesFeatures.mask(_take(pref, rest, int(spec["gold"]), rng))
	# 5. Turned: not mist; faces with a look-alike elsewhere first.
	pref = PackedInt32Array()
	rest = PackedInt32Array()
	for t: int in size:
		if HalvesBits.has(mist, t):
			continue
		if _has_look_alike(faces, t):
			pref.append(t)
		else:
			rest.append(t)
	var turned := HalvesFeatures.mask(_take(pref, rest, int(spec["turned"]), rng))
	# 6. Lucky: not free at the start, not mist; steps in [n/3, 2n/3) first.
	var lo := floori(n / 3.0)
	var hi := floori(2 * n / 3.0)
	pref = PackedInt32Array()
	rest = PackedInt32Array()
	for t: int in size:
		if HalvesBits.has(free0, t) or HalvesBits.has(mist, t):
			continue
		if step[t] >= lo and step[t] < hi:
			pref.append(t)
		else:
			rest.append(t)
	var lucky := HalvesFeatures.mask(_take(pref, rest, int(spec["lucky"]), rng))
	return HalvesFeatures.normalize({"frost": H.ids(frost), "mist": H.ids(mist), "gold": H.ids(gold),
			"turned": H.ids(turned), "lucky": H.ids(lucky)})


func test_place_steps_2_to_6_follow_the_contract_exactly() -> void:
	var spec := {"frost": 3, "mist": 2, "gold": 2, "turned": 3, "lucky": 2}
	for level: int in PLACE_LEVELS:
		var data := _level(level)
		if data == null:
			continue
		var g := HalvesGeometry.from_positions(data.positions)
		for seed_n: int in 3:
			var got := HalvesFeatures.place(g, data.solution, data.faces, spec.duplicate(true), _rng(["exact", level, seed_n]))
			var want := _ref_place(g, data.solution, data.faces, spec, _rng(["exact", level, seed_n]))
			assert_eq(H.js(got), H.js(want), "level %d seed %d" % [level, seed_n])


func test_place_adds_turned_and_lucky_after_the_v2_steps() -> void:
	# The rng is used in the order 1, 2, 3, 4, 5, 6: adding turned and lucky to a spec leaves the
	# locks, frost, mist and gold of the same seed exactly as they were.
	var v2 := {"key_pairs": 1, "locked": 2, "frost": 2, "mist": 2, "gold": 2}
	var v3 := v2.duplicate(true)
	v3["turned"] = 3
	v3["lucky"] = 2
	for level: int in PLACE_LEVELS:
		var data := _level(level)
		if data == null:
			continue
		var g := HalvesGeometry.from_positions(data.positions)
		for seed_n: int in 3:
			var old := HalvesFeatures.place(g, data.solution, data.faces, v2.duplicate(true), _rng(["order", level, seed_n]))
			var got := HalvesFeatures.place(g, data.solution, data.faces, v3.duplicate(true), _rng(["order", level, seed_n]))
			assert_false(old.has("turned") or old.has("lucky"), "no turned or lucky without them in the spec")
			var trimmed := got.duplicate(true)
			trimmed.erase("turned")
			trimmed.erase("lucky")
			assert_eq(H.js(trimmed), H.js(old), "level %d seed %d: steps 1-4 unchanged" % [level, seed_n])
			assert_true(got.has("turned"), "level %d: turned placed" % level)


func test_place_turned_and_lucky_invariants() -> void:
	var specs: Array[Dictionary] = [
		{"turned": 4},
		{"lucky": 3},
		{"key_pairs": 1, "locked": 2, "frost": 2, "mist": 3, "gold": 2, "turned": 4, "lucky": 3},
		{"mist": 40, "turned": 200, "lucky": 200},
	]
	for level: int in PLACE_LEVELS:
		var data := _level(level)
		if data == null:
			continue
		var g := HalvesGeometry.from_positions(data.positions)
		for s: int in specs.size():
			for seed_n: int in 2:
				var label := "level %d spec %d seed %d" % [level, s, seed_n]
				var f := HalvesFeatures.place(g, data.solution, data.faces, specs[s].duplicate(true), _rng(["inv", level, s, seed_n]))
				_check_turned_lucky(g, data.solution, data.faces, specs[s], f, label)


func _assert_preferred(chosen: PackedInt64Array, preferred: PackedInt64Array, label: String) -> void:
	if HalvesBits.count(chosen) <= HalvesBits.count(preferred):
		assert_eq(HalvesBits.minus(chosen, preferred), HalvesBits.empty(), label)
	else:
		assert_eq(HalvesBits.minus(preferred, chosen), HalvesBits.empty(), label)


func _check_turned_lucky(g: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array, spec: Dictionary,
		f: Dictionary, label: String) -> void:
	var n := order.size()
	var size := g.size()
	var step := H.steps_of(order, size)
	var free0 := g.free_mask(g.full_mask())
	var all := g.full_mask()
	var none := HalvesBits.empty()
	assert_eq(H.js(f), H.js(HalvesFeatures.normalize(f)), label + ": normalised")
	var errors := HalvesFeatures.validate(g, f, order)
	assert_true(errors.is_empty(), label + ": the order stays a solution: " + ", ".join(errors))
	var mist := HalvesFeatures.mask(f.get("mist", []))
	# 5. Turned.
	var turned := HalvesFeatures.mask(f.get("turned", []))
	var turned_cand := HalvesBits.minus(all, mist)
	var look := HalvesBits.empty()
	for t: int in size:
		if _has_look_alike(faces, t):
			HalvesBits.set_bit(look, t)
	assert_eq(HalvesBits.minus(turned, turned_cand), none, label + ": turned tiles are not mist")
	assert_eq(HalvesBits.count(turned), mini(int(spec.get("turned", 0)), HalvesBits.count(turned_cand)), label + ": turned count")
	_assert_preferred(turned, HalvesBits.intersection(turned_cand, look), label + ": turned on look-alikes first")
	# 6. Lucky.
	var lucky := HalvesFeatures.mask(f.get("lucky", []))
	var lucky_cand := HalvesBits.minus(HalvesBits.minus(all, free0), mist)
	var middle := HalvesBits.empty()
	var lo := floori(n / 3.0)
	var hi := floori(2 * n / 3.0)
	for t: int in size:
		if step[t] >= lo and step[t] < hi:
			HalvesBits.set_bit(middle, t)
	assert_eq(HalvesBits.intersection(lucky, free0), none, label + ": lucky tiles are not free at the start")
	assert_eq(HalvesBits.minus(lucky, lucky_cand), none, label + ": lucky tiles are not mist")
	assert_eq(HalvesBits.count(lucky), mini(int(spec.get("lucky", 0)), HalvesBits.count(lucky_cand)), label + ": lucky count")
	_assert_preferred(lucky, HalvesBits.intersection(lucky_cand, middle), label + ": lucky in the middle third first")


func test_place_same_seed_same_turned_and_lucky() -> void:
	var data := _level(30)
	if data == null:
		return
	var g := HalvesGeometry.from_positions(data.positions)
	var spec := {"mist": 2, "turned": 4, "lucky": 3}
	var a := HalvesFeatures.place(g, data.solution, data.faces, spec.duplicate(true), _rng(["same"]))
	var b := HalvesFeatures.place(g, data.solution, data.faces, spec.duplicate(true), _rng(["same"]))
	assert_eq(H.js(a), H.js(b))
	assert_true(a.has("turned") and a.has("lucky"))


# --- HalvesState: lucky clocks ---


## Ten tiles, ids in (z, y, x) order. Layer 0 stands four half-units apart (no side neighbours):
##   0 (0,0,0) circle a  [lucky, under 9]   1 (4,0,0) circle b   2 (8,0,0) tri a [lucky]   3 (12,0,0) tri b
##   4 (16,0,0) diamond a   5 (20,0,0) diamond b   6 (24,0,0) square:h a   7 (28,0,0) square:h b
##   8 (32,0,0) circle dot a;   layer 1: 9 (0,0,1) circle dot b, on tile 0.
func _lucky_state(lucky: Array = [0, 2]) -> HalvesState:
	var g := H.geometry([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(8, 0, 0), Vector3i(12, 0, 0),
			Vector3i(16, 0, 0), Vector3i(20, 0, 0), Vector3i(24, 0, 0), Vector3i(28, 0, 0), Vector3i(32, 0, 0),
			Vector3i(0, 0, 1)])
	return HalvesState.new(g.with_features({"lucky": lucky}), H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:a",
			"tri:v:-:b", "diamond:v:-:a", "diamond:v:-:b", "square:h:-:a", "square:h:-:b", "circle:v:dot:a",
			"circle:v:dot:b"]))


func test_a_fresh_state_has_no_mends_and_starts_free_lucky_clocks() -> void:
	var s := _lucky_state()
	assert_eq(s.mends, 0)
	assert_eq(s.pairs_done, 0)
	assert_eq(s.lucky_won, 0)
	assert_eq(s.lucky, H.mask_of([0, 2]), "from geometry.features")
	assert_eq(_clocks(s), H.js({2: 0}), "tile 2 is free at _init; tile 0 is covered")
	var plain := HalvesState.new(H.geometry(H.column(2)), H.faces(["circle:v:-:a", "circle:v:-:b"]))
	assert_eq(plain.lucky, HalvesBits.empty(), "no features, no lucky tiles")
	assert_eq(_clocks(plain), H.js({}))


func test_pairs_done_counts_pairs_not_mistakes() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.pairs_done, 1)
	assert_eq(s.try_pair(1, 8), R.MISMATCH, "circle b and circle-dot a are a decoy")
	assert_eq(s.pairs_done, 1, "a mistake is not a pair")
	assert_eq(s.try_pair(1, 2), R.SWITCH)
	assert_eq(s.try_pair(0, 1), R.BLOCKED)
	assert_eq(s.try_pair(4, 4), R.INVALID)
	assert_eq(s.pairs_done, 1)
	assert_eq(s.try_pair(6, 7), R.MATCH)
	assert_eq(s.pairs_done, 2)
	assert_true(s.undo())
	assert_eq(s.pairs_done, 1)
	assert_true(s.undo(), "the mistake")
	assert_eq(s.pairs_done, 1, "undoing a mistake leaves pairs_done")
	assert_true(s.undo())
	assert_eq(s.pairs_done, 0)


func test_a_lucky_tile_removed_within_three_pairs_is_won() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.try_pair(6, 7), R.MATCH)
	assert_eq(s.lucky_won, 0)
	assert_eq(s.try_pair(3, 2), R.MATCH, "pairs_done 2 before the removal, clock 0: 2 < 3")
	assert_eq(s.lucky_won, 1)
	assert_eq(s.pairs_done, 3)


func test_a_lucky_tile_removed_after_three_pairs_is_not_won() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.try_pair(6, 7), R.MATCH)
	assert_eq(s.try_pair(8, 9), R.MATCH, "frees tile 0")
	assert_eq(_clocks(s), H.js({2: 0, 0: 3}), "tile 0's clock starts at pairs_done after the pair that freed it")
	assert_eq(s.try_pair(2, 3), R.MATCH, "pairs_done 3 before, clock 0: 3 is not < 3")
	assert_eq(s.lucky_won, 0)
	assert_eq(s.try_pair(1, 0), R.MATCH, "pairs_done 4 before, clock 3")
	assert_eq(s.lucky_won, 1)
	assert_true(s.is_cleared())


func test_mistakes_do_not_run_the_lucky_clock() -> void:
	var s := _lucky_state()
	s.free_mistakes = 0
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.try_pair(6, 7), R.MATCH)
	for i: int in 3:
		assert_eq(s.try_pair(1, 8), R.MISMATCH)
	assert_eq(s.try_pair(2, 3), R.MATCH, "clocks count pairs, not taps")
	assert_eq(s.lucky_won, 1)


func test_undo_removes_the_clocks_its_entry_started() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(8, 9), R.MATCH)
	assert_eq(_clocks(s), H.js({2: 0, 0: 1}))
	assert_true(s.undo())
	assert_eq(_clocks(s), H.js({2: 0}), "tile 0 is covered again and its clock is gone; _init's clock stays")
	assert_eq(s.pairs_done, 0)


func test_undo_takes_back_a_lucky_win_and_keeps_the_original_clock() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(8, 9), R.MATCH)
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(s.try_pair(6, 7), R.MATCH)
	assert_eq(s.try_pair(0, 1), R.MATCH, "pairs_done 3 before, clock 1: won")
	assert_eq(s.lucky_won, 1)
	assert_true(s.undo())
	assert_eq(s.lucky_won, 0, "the undone pair's win is taken back")
	assert_eq(s.pairs_done, 3)
	assert_eq(_clocks(s), H.js({2: 0, 0: 1}), "tile 0 keeps the clock an earlier entry started")
	assert_eq(s.try_pair(2, 3), R.MATCH, "pairs_done 3 before, clock 0: not won")
	assert_eq(s.try_pair(0, 1), R.MATCH, "pairs_done 4 before, clock 1 (not restarted by the undo): not won")
	assert_eq(s.lucky_won, 0)


func test_undo_of_a_win_with_an_init_clock() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(2, 3), R.MATCH)
	assert_eq(s.lucky_won, 1)
	assert_true(s.undo())
	assert_eq(s.lucky_won, 0)
	assert_eq(_clocks(s), H.js({2: 0}))
	assert_eq(s.try_pair(2, 3), R.MATCH)
	assert_eq(s.lucky_won, 1, "won again")


func test_apply_deal_keeps_mends_pairs_and_clocks_and_starts_new_clocks() -> void:
	var s := _lucky_state()
	assert_eq(s.try_pair(2, 3), R.MATCH, "won")
	assert_eq(s.try_pair(4, 5), R.MATCH)
	s.mends = 1
	assert_eq(s.lucky_won, 1)
	assert_eq(s.pairs_done, 2)
	# A re-deal of the six tiles left onto 0..5: tile 0 is no longer under tile 9, so it is free.
	var faces := H.faces(["circle:v:-:a", "circle:v:-:b", "circle:v:dot:a", "circle:v:dot:b", "square:h:-:a",
			"square:h:-:b", "", "", "", ""])
	s.apply_deal(H.mask_of([0, 1, 2, 3, 4, 5]), faces, true)
	assert_eq(s.mends, 1, "apply_deal keeps mends")
	assert_eq(s.pairs_done, 2, "apply_deal keeps pairs_done")
	assert_eq(s.lucky_won, 1, "apply_deal keeps lucky_won")
	assert_eq(_clocks(s), H.js({2: 0, 0: 2}), "kept clock for 2, new clock for 0 at pairs_done")
	assert_eq(s.lucky, H.mask_of([0, 2]), "lucky is positional")
	assert_eq(s.try_pair(0, 1), R.MATCH, "pairs_done 2 before, clock 2: won")
	assert_eq(s.lucky_won, 2)
	assert_eq(s.try_pair(2, 3), R.MATCH, "tile 2 again (a new face on the lucky position): 3 - 0 is not < 3")
	assert_eq(s.lucky_won, 2)


func test_a_lucky_tile_never_free_has_no_clock() -> void:
	var s := _lucky_state([0])
	assert_eq(_clocks(s), H.js({}))
	assert_eq(s.try_pair(2, 3), R.MATCH)
	assert_eq(s.try_pair(4, 5), R.MATCH)
	assert_eq(_clocks(s), H.js({}), "tile 0 is still under tile 9")


# --- HalvesFill.with_gold_pair ---


## Checks every rule of with_gold_pair on one result; returns the gold step (or -1).
func _check_gold(g: HalvesGeometry, order: Array[Vector2i], faces: PackedInt32Array, got: PackedInt32Array,
		label: String) -> int:
	assert_eq(got.size(), faces.size(), label + ": same size")
	var changed: Array[int] = []
	var gold_count := 0
	for i: int in mini(got.size(), faces.size()):
		if got[i] != faces[i]:
			changed.append(i)
		if got[i] >= 0 and HalvesState.is_gold(got[i]):
			gold_count += 1
	assert_eq(changed.size(), 2, label + ": exactly two tiles change")
	assert_eq(gold_count, 2, label + ": one gold pair")
	var k := -1
	for s: int in order.size():
		if changed.size() == 2 and H.norm(order[s]) == Vector2i(changed[0], changed[1]):
			k = s
	assert_true(k >= 0, label + ": the two tiles of one step of order")
	if k < 0:
		return -1
	var n := order.size()
	var lo := floori(n / 3.0)
	var hi := maxi(floori(2 * n / 3.0), lo + 1)
	assert_between(k, lo, hi - 1, label + ": the step is in [n/3, 2n/3)")
	for t: int in [order[k].x, order[k].y]:
		var want := _gold_a() if HalvesFace.side(faces[t]) == HalvesFace.SIDE_A else _gold_b()
		assert_eq(got[t], want, label + ": tile %d keeps its side" % t)
	var free0 := g.free_mask(g.full_mask())
	var preferred: Array[int] = []
	for s: int in range(lo, hi):
		if not HalvesBits.has(free0, order[s].x) and not HalvesBits.has(free0, order[s].y):
			preferred.append(s)
	if not preferred.is_empty():
		assert_has(preferred, k, label + ": a step whose tiles are both not free at the start")
	assert_eq(H.replay_error(HalvesState.new(g, got), order), "", label + ": order stays a solution")
	return k


func test_with_gold_pair_on_baked_levels() -> void:
	for level: int in GOLD_LEVELS:
		var data := _level(level)
		if data == null:
			continue
		var g := HalvesGeometry.from_positions(data.positions)
		var before := data.faces.duplicate()
		for seed_n: int in 4:
			var got := HalvesFill.with_gold_pair(g, data.solution, data.faces, _rng(["gold", level, seed_n]))
			var label := "level %d seed %d" % [level, seed_n]
			_check_gold(g, data.solution, data.faces, got, label)
			assert_eq(data.faces, before, label + ": faces is not changed (a copy is returned)")
			# The level's own features never depend on faces, so the order stays a solution with them too.
			assert_eq(H.replay_error(HalvesState.new(data.geometry(), got), data.solution), "", label + ": with features")


func test_with_gold_pair_same_seed_same_result_and_the_rng_chooses() -> void:
	var data := _level(30)
	if data == null:
		return
	var g := HalvesGeometry.from_positions(data.positions)
	var a := HalvesFill.with_gold_pair(g, data.solution, data.faces, _rng(["same gold"]))
	var b := HalvesFill.with_gold_pair(g, data.solution, data.faces, _rng(["same gold"]))
	assert_eq(a, b)
	var steps := {}
	for seed_n: int in 30:
		var got := HalvesFill.with_gold_pair(g, data.solution, data.faces, _rng(["spread", seed_n]))
		steps[_check_gold(g, data.solution, data.faces, got, "seed %d" % seed_n)] = true
	assert_true(steps.size() >= 2, "the rng picks among the steps (%d distinct)" % steps.size())


func test_with_gold_pair_on_one_pair() -> void:
	var g := H.geometry(H.column(2))
	var faces := H.faces(["circle:v:-:b", "circle:v:-:a"])
	var got := HalvesFill.with_gold_pair(g, H.pairs([Vector2i(0, 1)]), faces, _rng(["one"]))
	assert_eq(got, PackedInt32Array([_gold_b(), _gold_a()]), "n = 1: the only step; side a stays side a")


func test_with_gold_pair_three_steps_uses_the_middle_one() -> void:
	# n = 3: [1, 2) holds step 1 only.
	var g := H.geometry(H.column(6))
	var faces := H.faces(["circle:v:-:a", "circle:v:-:b", "tri:v:-:b", "tri:v:-:a", "square:v:-:a", "square:v:-:b"])
	var order := H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)])
	for seed_n: int in 5:
		var got := HalvesFill.with_gold_pair(g, order, faces, _rng(["three", seed_n]))
		var want := faces.duplicate()
		want[2] = _gold_b()
		want[3] = _gold_a()
		assert_eq(got, want, "seed %d" % seed_n)


func test_with_gold_pair_without_a_preferred_step_uses_the_range() -> void:
	# A column: every tile is free at the start; n = 6, so the step is 2 or 3.
	var g := H.geometry(H.column(12))
	var texts: Array = []
	for t: String in ["circle:v:-", "tri:v:-", "square:v:-", "diamond:v:-", "circle:h:-", "square:h:-"]:
		texts.append(t + ":a")
		texts.append(t + ":b")
	var faces := H.faces(texts)
	var order := H.pairs([Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7), Vector2i(8, 9), Vector2i(10, 11)])
	var seen := {}
	for seed_n: int in 20:
		var got := HalvesFill.with_gold_pair(g, order, faces, _rng(["range", seed_n]))
		seen[_check_gold(g, order, faces, got, "seed %d" % seed_n)] = true
	assert_false(seen.has(-1), "every result is one step of order")
	for k: int in seen:
		assert_between(k, 2, 3, "only steps 2 and 3")


func test_with_gold_pair_prefers_a_covered_step() -> void:
	# Ids: 0 (0,0,0) and 1 (4,0,0) lie under 10 (0,0,1) and 11 (4,0,1); 2..9 stand apart at y 4.
	# Order: (10, 11), (2, 3), (4, 5), (0, 1), (6, 7), (8, 9). n = 6, range [2, 4): step 2 is free at
	# the start, step 3 is covered, so step 3 is always chosen.
	var points: Array = [Vector3i(0, 0, 0), Vector3i(4, 0, 0)]
	for i: int in 8:
		points.append(Vector3i(4 * i, 4, 0))
	points.append(Vector3i(0, 0, 1))
	points.append(Vector3i(4, 0, 1))
	var g := H.geometry(points)
	var faces := H.faces(["tri:v:-:a", "tri:v:-:b", "square:v:-:a", "square:v:-:b", "diamond:v:-:a", "diamond:v:-:b",
			"circle:h:-:a", "circle:h:-:b", "square:h:-:a", "square:h:-:b", "circle:v:-:a", "circle:v:-:b"])
	var order := H.pairs([Vector2i(10, 11), Vector2i(2, 3), Vector2i(4, 5), Vector2i(0, 1), Vector2i(6, 7), Vector2i(8, 9)])
	assert_eq(H.order_error(g, g.full_mask(), order), "", "test setup")
	for seed_n: int in 20:
		var got := HalvesFill.with_gold_pair(g, order, faces, _rng(["covered", seed_n]))
		assert_eq(_check_gold(g, order, faces, got, "seed %d" % seed_n), 3, "seed %d: the covered step" % seed_n)
