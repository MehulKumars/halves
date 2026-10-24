class_name HalvesGenerator
extends RefCounted
## Pure steps of the Halves level generator (contract v3, docs/HALVES.md 4b): pair types drafted in
## look-alike chunks, pair keys for a plan slot or pool recipe, seeded trap-seeded candidate deals
## with features and the gold pair, rating with the bots (PERCEPTIVE's p3 first), the winner, par.
## Driven by generate_halves.gd and build_plan.gd; lives in tools/ so it never ships.

const CANDIDATES: int = 120
const QUICK_RUNS: int = 12
const FINAL_RUNS: int = 50
const SHORTLIST: int = 6
## When the shortlist's best is still trivial or under a floor, up to this many more are rated.
const EXTRA_FINALS: int = 12

## (v3) The family each place brings (4b); &"" for the mixed places (9 and 11-15).
const PLACE_FAMILIES: Array[StringName] = [&"shapes", &"blossoms", &"leaves", &"things", &"waves",
	&"wings", &"lattice", &"tomoe", &"", &"sky", &"", &"", &"", &"", &""]
## (v3) Plain v2 shapes (no dot or line marks) by look-alike group: each shape is one "motif" whose
## cuts are its pair types (triangles only vertical).
const PLAIN_SHAPES: Dictionary = {
	&"circle": ["circle:v:-", "circle:h:-"],
	&"tri": ["tri:v:-"],
	&"square": ["square:v:-", "square:h:-"],
	&"diamond": ["diamond:v:-", "diamond:h:-"],
}


## `pair_count` pair keys spread over `types` round-robin, in the listed order.
static func pair_keys_for(types: Array, pair_count: int) -> PackedInt32Array:
	var keys := PackedInt32Array()
	for k in pair_count:
		keys.append(HalvesFace.pair_from_text(str(types[k % types.size()])))
	return keys


static func seed_parts(level: int, candidate: int) -> Array:
	return ["halves", level, candidate]


## (v3) The families the player has met by `place` (place order, shapes first, never gold).
static func families_until(place: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for p in mini(place, PLACE_FAMILIES.size()):
		if PLACE_FAMILIES[p] != &"":
			out.append(PLACE_FAMILIES[p])
	return out


## (v3) Every crest family but gold, in place order.
static func crest_families() -> Array[StringName]:
	var out: Array[StringName] = []
	for family in families_until(PLACE_FAMILIES.size()):
		if family != &"shapes":
			out.append(family)
	return out


## (v3) A family's look-alike groups: {group: [motif, ...]} where a motif is the list of its pair
## types in text form, vertical cut first. `horizontal` false keeps vertical cuts only; for shapes,
## `shapes` limits the groups (empty = all four).
static func family_groups(family: StringName, horizontal: bool, shapes: Array = []) -> Dictionary:
	var groups: Dictionary = {}
	if family == &"shapes":
		for group: StringName in PLAIN_SHAPES:
			if not shapes.is_empty() and not shapes.has(str(group)):
				continue
			var cuts: Array = (PLAIN_SHAPES[group] as Array).duplicate()
			if not horizontal:
				cuts = cuts.slice(0, 1)
			groups[group] = [cuts]
		return groups
	for motif in HalvesCrests.motif_count():
		var info: Dictionary = HalvesCrests.MOTIFS[motif]
		if info.family != family:
			continue
		var cuts: Array = []
		for cut: int in [0, 1]:
			if (info.cuts as Array).has(cut) and (cut == 0 or horizontal):
				cuts.append(HalvesFace.pair_to_text(HalvesCrests.pair_of(motif, cut)))
		if cuts.is_empty():
			continue
		if not groups.has(info.group):
			groups[info.group] = []
		groups[info.group].append(cuts)
	return groups


## (v3) `count` pair types (text form) for one board, drafted in look-alike chunks: family by
## family in `families` order, each taking its `quotas` entry (a family that runs out passes the
## rest on, then the `spare` families take it), group by group in a shuffled order, at most `depth`
## types per group (distinct motifs first, one cut each, horizontal with chance `h_share` where
## allowed; a group with fewer motifs than `depth` adds second cuts). Only if every family is used
## up are groups drafted deeper than `depth`. The first family's types come first (round-robin
## gives them the extra copies). `shapes` limits the shape groups (place 1 brings them one by one).
static func draft_types(families: Array, quotas: Array, spare: Array, count: int, depth: int, h_share: float,
		horizontal: bool, rng: RandomNumberGenerator, shapes: Array = []) -> Array:
	var out: Array = []
	var taken: Dictionary = {}
	var order: Array = families.duplicate()
	for family: Variant in spare:
		if not order.has(family):
			order.append(family)
	var carry := 0
	for f in order.size():
		var family: StringName = order[f]
		var quota := carry + (int(quotas[f]) if f < quotas.size() else 0)
		if f >= families.size():
			quota = count - out.size()
		if quota <= 0:
			continue
		var got := _draft_family(family, quota, depth, h_share, horizontal, rng, shapes, taken)
		out.append_array(got)
		carry = quota - got.size()
		if out.size() >= count:
			break
	# Last resort: deeper look-alike groups, from the first family on.
	var deeper := depth + 1
	while out.size() < count and deeper <= 8:
		for family: StringName in order:
			if out.size() >= count:
				break
			out.append_array(_draft_family(family, count - out.size(), deeper, h_share, horizontal, rng, shapes, taken))
		deeper += 1
	return out.slice(0, count)


static func _draft_family(family: StringName, quota: int, depth: int, h_share: float, horizontal: bool,
		rng: RandomNumberGenerator, shapes: Array, taken: Dictionary) -> Array:
	var groups := family_groups(family, horizontal, shapes)
	var names: Array = groups.keys()
	names.sort()
	_shuffle(names, rng)
	var out: Array = []
	for group: Variant in names:
		if out.size() >= quota:
			break
		var motifs: Array = (groups[group] as Array).duplicate()
		_shuffle(motifs, rng)
		var in_group := 0
		for cuts: Array in motifs:
			for t: String in cuts:
				if taken.has(t):
					in_group += 1
		var room := mini(depth - in_group, quota - out.size())
		if room <= 0:
			continue
		# Distinct motifs first: one cut each (horizontal with chance h_share).
		for cuts: Array in motifs:
			if room <= 0:
				break
			var fresh := true
			for t: String in cuts:
				fresh = fresh and not taken.has(t)
			if not fresh:
				continue
			var pick: String = cuts[1] if cuts.size() > 1 and rng.randf() < h_share else cuts[0]
			taken[pick] = true
			out.append(pick)
			room -= 1
		# Then second cuts of motifs already on the board.
		for cuts: Array in motifs:
			for t: String in cuts:
				if room <= 0:
					break
				if not taken.has(t):
					taken[t] = true
					out.append(t)
					room -= 1
	return out


## Fisher-Yates with `rng` (the HalvesFill.shuffle_ints order) on any Array.
static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = values[i]
		values[i] = values[j]
		values[j] = swap


static func trap_rate(spec: Dictionary, candidate: int) -> float:
	var trap: Array = spec.get("trap", [0.0, 0.0])
	var lo := float(trap[0])
	var hi := float(trap[1])
	return lo + (hi - lo) * (candidate % 4) / 3.0


static func min_careful(spec: Dictionary) -> float:
	var hard := str(spec.get("role", "")) in ["hard", "finale"]
	return float(spec.get("min_careful", 0.6 if hard else 0.8))


static func min_wary(spec: Dictionary) -> float:
	return float(spec.get("min_wary", 0.0))


## (v3) Lower is better: the PERCEPTIVE three-star share counts four times as much as RANDOM's win.
static func score(stats: Dictionary, spec: Dictionary) -> float:
	return 2.0 * absf(float(stats.p3) - float(spec.get("target_p3", 1.0))) \
			+ 0.5 * absf(float(stats.random_win) - float(spec.get("target_win", 1.0)))


## (v3) A hard or finale board that WARY always clears and PERCEPTIVE nearly always three-stars.
static func is_trivial(stats: Dictionary, spec: Dictionary) -> bool:
	return str(spec.get("role", "")) in ["hard", "finale"] and float(stats.wary_win) >= 1.0 and float(stats.p3) > 0.9


static func start_free_pairs(geometry: HalvesGeometry, faces: PackedInt32Array) -> int:
	return HalvesState.new(geometry, faces).free_pairs().size()


static func accept(stats: Dictionary, spec: Dictionary, first_level: bool, free_pairs_at_start: int,
		relax: float = 1.0) -> bool:
	if relax <= 0.0:
		return true
	if float(stats.careful_win) < min_careful(spec) * relax or float(stats.wary_win) < min_wary(spec) * relax:
		return false
	return first_level or free_pairs_at_start >= 2


## The HalvesFeatures.place spec of a slot or recipe: its "features", plus (v3) the slot-level
## "turned" and "lucky" counts when present and above 0 (they win over the same keys in "features").
static func feature_spec(spec: Dictionary) -> Dictionary:
	var out: Dictionary = (spec.get("features", {}) as Dictionary).duplicate()
	for key: String in ["turned", "lucky"]:
		if int(spec.get(key, 0)) > 0:
			out[key] = int(spec[key])
	return out


## One candidate deal: HalvesFill.deal_v2, or with (v3) `gold_pair` the same steps with
## HalvesFill.with_gold_pair between the faces and the features (one rng, in that order).
static func deal(geometry: HalvesGeometry, keys: PackedInt32Array, rng: RandomNumberGenerator, rate: float,
		features_spec: Dictionary, gold_pair: bool) -> Dictionary:
	if not gold_pair:
		return HalvesFill.deal_v2(geometry, keys, rng, rate, features_spec)
	if keys.size() * 2 != geometry.size():
		return {}
	var plain := geometry.with_features({}) if geometry.has_features() else geometry
	var order := HalvesFill.removal_order(plain, plain.full_mask(), rng)
	if order.is_empty():
		return {}
	var faces := HalvesFill.assign_faces_trapped(plain, order, keys, rng, plain.size(), rate)
	faces = HalvesFill.with_gold_pair(plain, order, faces, rng)
	var features := HalvesFeatures.place(plain, order, faces, features_spec, rng)
	return {"faces": faces, "solution": order, "features": features, "traps": HalvesFill.live_traps(plain, order, faces)}


## docs/HALVES.md section 4.
static func par_ms(geometry: HalvesGeometry, faces: PackedInt32Array, features: Dictionary, difficulty: float) -> int:
	var keys: Dictionary[int, bool] = {}
	for face in faces:
		if face >= 0:
			keys[HalvesFace.pair_key(face)] = true
	var seconds := HalvesConfig.PAR_BASE_S + geometry.size() / 2 * HalvesConfig.PAR_PER_PAIR_S \
			+ keys.size() * HalvesConfig.PAR_PER_TYPE_S + (geometry.max_z() + 1) * HalvesConfig.PAR_PER_LAYER_S \
			+ HalvesFeatures.tile_count(features) * HalvesConfig.PAR_PER_FEATURE_S
	seconds *= 1.0 + difficulty * HalvesConfig.PAR_DIFFICULTY_SCALE
	var step := HalvesConfig.PAR_ROUND_S
	return int(ceil(seconds / step)) * step * 1000


## (v3) Look-alike depth of a board: the most pair types sharing one look-alike group (gold aside).
static func lookalike_depth(faces: PackedInt32Array) -> int:
	var by_group: Dictionary = {}
	for face in faces:
		if face < 0 or HalvesFace.family(face) == &"gold":
			continue
		var group := HalvesFace.group(face)
		if not by_group.has(group):
			by_group[group] = {}
		by_group[group][HalvesFace.pair_key(face)] = true
	var deepest := 0
	for group: Variant in by_group:
		deepest = maxi(deepest, (by_group[group] as Dictionary).size())
	return deepest


## Distinct pair types on a board.
static func type_count(faces: PackedInt32Array) -> int:
	var keys: Dictionary = {}
	for face in faces:
		if face >= 0:
			keys[HalvesFace.pair_key(face)] = true
	return keys.size()


## Builds one level from its plan slot and mask layers; null if no candidate was acceptable.
static func build_level(slot: Dictionary, layers: Array, log: PackedStringArray, candidates: int = CANDIDATES) -> HalvesLevelData:
	var level := int(slot.level)
	var data := build_board(slot, layers, ["halves", level], level, level == 1, candidates, log, false)
	if data == null:
		return null
	data.level = level
	data.place = int(slot.get("place", 0))
	data.role = str(slot.role)
	data.mask = str(slot.mask)
	data.tip = str(slot.get("tip", ""))
	var s := data.stats
	log.append("level %3d p%-2d %-8s %-24s tiles %3d L%d types %2d d%d cand %3d trap %.2f  p3 %.2f (%.2f)  slips %.2f  win %.2f (%.2f)  wary %.2f  careful %.2f  par %ds" % [
		level, data.place, data.role, data.mask, data.positions.size(), data.geometry().max_z() + 1,
		type_count(data.faces), lookalike_depth(data.faces), int(data.seed_parts[2]), s.trap_rate, s.p3,
		float(slot.get("target_p3", 1.0)), s.perceptive_slips, s.random_win, float(slot.target_win), s.wary_win,
		s.careful_win, int(s.par_ms) / 1000])
	return data


## The candidate search shared by levels and pool boards. `spec` has types, target_p3, target_win
## and the optional role / trap / features / min_careful / min_wary / gold_pair (0/1) / turned and
## lucky (counts). `rate_level` is the level the PERCEPTIVE allowance is taken for (pool boards pass
## their id). With `relax_if_needed` the floors are halved when no candidate passes, then dropped
## (pools must never come up short). (v3) A trivial hard or finale candidate only wins when no
## other candidate passes.
static func build_board(spec: Dictionary, layers: Array, seed_prefix: Array, rate_level: int, first_level: bool,
		candidates: int, log: PackedStringArray, relax_if_needed: bool) -> HalvesLevelData:
	var positions := HalvesMask.parse(layers)
	var problems := HalvesMask.validate(positions)
	if not problems.is_empty():
		log.append("%s: mask invalid: %s" % [str(seed_prefix), "; ".join(problems)])
		return null
	var geometry := HalvesGeometry.from_positions(positions)
	var keys := pair_keys_for(spec.types, positions.size() / 2)
	var features_spec := feature_spec(spec)
	var gold_pair := int(spec.get("gold_pair", 0)) > 0
	var dealt_all: Array[Dictionary] = []
	for k in candidates:
		var rng := SeedService.make_rng(seed_prefix + [k], HalvesConfig.GEN_VERSION)
		var rate := trap_rate(spec, k)
		var dealt := deal(geometry, keys, rng, rate, features_spec, gold_pair)
		if dealt.is_empty():
			continue
		var rules := geometry.with_features(dealt.features)
		var stats := HalvesBot.rate(rules, dealt.faces, seed_prefix + [k], QUICK_RUNS, rate_level)
		dealt_all.append({"k": k, "deal": dealt, "rate": rate, "stats": stats, "free": start_free_pairs(rules, dealt.faces),
				"score": score(stats, spec), "trivial": is_trivial(stats, spec)})
	var quick: Array[Dictionary] = []
	var relax_used := 1.0
	for relax: float in ([1.0, 0.5, 0.0] if relax_if_needed else [1.0]):
		relax_used = relax
		for entry in dealt_all:
			if accept(entry.stats, spec, first_level, entry.free, relax):
				quick.append(entry)
		if not quick.is_empty():
			if relax < 1.0:
				log.append("%s: floors relaxed" % str(seed_prefix))
			break
	if quick.is_empty():
		log.append("%s: no acceptable candidate out of %d (%d dealt)" % [str(seed_prefix), candidates, dealt_all.size()])
		return null
	quick.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.trivial != b.trivial:
			return not a.trivial
		return a.score < b.score or (a.score == b.score and a.k < b.k))
	# The final rating must pass the floors and not be trivial (a 12-run screen is noisy); failing
	# ones only win when nothing rated passes. A few more are rated while the best still fails.
	var best: Dictionary = {}
	var rated := 0
	for entry in quick:
		if rated >= SHORTLIST and (rated >= SHORTLIST + EXTRA_FINALS or (best.passes and not best.trivial)):
			break
		rated += 1
		var dealt: Dictionary = entry.deal
		var rules := geometry.with_features(dealt.features)
		var stats := HalvesBot.rate(rules, dealt.faces, seed_prefix + [entry.k], FINAL_RUNS, rate_level)
		var s := score(stats, spec)
		var passes := accept(stats, spec, first_level, entry.free, relax_used)
		var trivial := is_trivial(stats, spec)
		var candidate := {"k": entry.k, "deal": dealt, "stats": stats, "score": s, "rate": entry.rate, "passes": passes, "trivial": trivial}
		if best.is_empty() or _better(candidate, best):
			best = candidate
	if not best.passes:
		log.append("%s: no candidate passed the final floors; best kept" % str(seed_prefix))
	var data := HalvesLevelData.new()
	data.seed_parts = seed_prefix + [int(best.k)]
	data.positions = positions
	data.faces = best.deal.faces
	data.solution = best.deal.solution
	data.features = best.deal.features
	var stats: Dictionary = best.stats
	var rules := geometry.with_features(data.features)
	stats["start_free_pairs"] = start_free_pairs(rules, data.faces)
	stats["traps"] = int(best.deal.traps)
	for key: String in ["random_win", "careful_win", "wary_win", "avg_free_pairs", "decoy_exposure", "difficulty",
			"perceptive_win", "perceptive_slips", "p3"]:
		stats[key] = snappedf(float(stats[key]), 0.001)
	stats["trap_rate"] = snappedf(float(best.rate), 0.001)
	stats["par_ms"] = par_ms(geometry, data.faces, data.features, float(stats.difficulty))
	data.stats = stats
	return data


## Final candidates in order: passing first, then not trivial, then the lower score, then lower k.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.passes != b.passes:
		return a.passes
	if a.trivial != b.trivial:
		return not a.trivial
	if a.score != b.score:
		return a.score < b.score
	return int(a.k) < int(b.k)
