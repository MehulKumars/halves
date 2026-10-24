class_name HalvesGenerator
extends RefCounted
## Pure steps of the Halves level generator (contract v2): pair keys for a plan slot or pool recipe,
## seeded trap-seeded candidate deals with features, rating, picking the winner, and par time.
## Driven by generate_halves.gd; lives in tools/ so it never ships. Seeds: seed prefix + [candidate].

const CANDIDATES: int = 120
const QUICK_RUNS: int = 12
const FINAL_RUNS: int = 50
const SHORTLIST: int = 6


## `pair_count` pair keys spread over `types` round-robin, in the listed order.
static func pair_keys_for(types: Array, pair_count: int) -> PackedInt32Array:
	var keys := PackedInt32Array()
	for k in pair_count:
		keys.append(HalvesFace.pair_from_text(str(types[k % types.size()])))
	return keys


static func seed_parts(level: int, candidate: int) -> Array:
	return ["halves", level, candidate]


## Every valid pair type in text form ("circle:v:-", ...), in face order.
static func all_pair_types() -> Array:
	var types: Array = []
	for shape in 4:
		for cut in 2:
			for mark in 3:
				var face := HalvesFace.make(shape, cut, mark, HalvesFace.SIDE_A)
				if HalvesFace.is_valid(face):
					types.append(HalvesFace.pair_to_text(HalvesFace.pair_key(face)))
	return types


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


## Lower is better: the win target counts four times as much as the decoy target.
static func score(stats: Dictionary, target_win: float, target_decoy: float) -> float:
	return 2.0 * absf(float(stats.random_win) - target_win) + 0.5 * absf(float(stats.decoy_exposure) - target_decoy)


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


## Builds one level from its plan slot and mask layers; null if no candidate was acceptable.
static func build_level(slot: Dictionary, layers: Array, log: PackedStringArray, candidates: int = CANDIDATES) -> HalvesLevelData:
	var level := int(slot.level)
	var data := build_board(slot, layers, ["halves", level], level == 1, candidates, log, false)
	if data == null:
		return null
	data.level = level
	data.role = str(slot.role)
	data.mask = str(slot.mask)
	data.tip = str(slot.get("tip", ""))
	var s := data.stats
	log.append("level %3d %-7s %-24s tiles %2d cand %3d trap %.2f  win %.2f (%.2f)  wary %.2f  careful %.2f  decoy %.2f  traps %d  par %ds  diff %5.1f" % [
		level, data.role, data.mask, data.positions.size(), int(data.seed_parts[2]), s.trap_rate, s.random_win,
		float(slot.target_win), s.wary_win, s.careful_win, s.decoy_exposure, int(s.traps), int(s.par_ms) / 1000, s.difficulty])
	return data


## The candidate search shared by levels and pool boards. `spec` has types, target_win,
## target_decoy and the optional trap / features / min_careful / min_wary and (v3) gold_pair (0/1),
## turned and lucky (counts). With `relax_if_needed`
## the floors are halved when no candidate passes, then dropped (pools must never come up short).
static func build_board(spec: Dictionary, layers: Array, seed_prefix: Array, first_level: bool,
		candidates: int, log: PackedStringArray, relax_if_needed: bool) -> HalvesLevelData:
	var positions := HalvesMask.parse(layers)
	var problems := HalvesMask.validate(positions)
	if not problems.is_empty():
		log.append("%s: mask invalid: %s" % [str(seed_prefix), "; ".join(problems)])
		return null
	var geometry := HalvesGeometry.from_positions(positions)
	var keys := pair_keys_for(spec.types, positions.size() / 2)
	var target_win := float(spec.target_win)
	var target_decoy := float(spec.target_decoy)
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
		var stats := HalvesBot.rate(rules, dealt.faces, seed_prefix + [k], QUICK_RUNS)
		dealt_all.append({"k": k, "deal": dealt, "rate": rate, "stats": stats,
				"free": start_free_pairs(rules, dealt.faces), "score": score(stats, target_win, target_decoy)})
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
		log.append("%s: no acceptable candidate out of %d (target win %.2f)" % [str(seed_prefix), candidates, target_win])
		return null
	quick.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score < b.score or (a.score == b.score and a.k < b.k))
	# The final rating must pass the floors too (a 12-run screen is noisy); failing ones only win
	# when nothing in the shortlist passes.
	var best: Dictionary = {}
	for entry in quick.slice(0, SHORTLIST):
		var dealt: Dictionary = entry.deal
		var rules := geometry.with_features(dealt.features)
		var stats := HalvesBot.rate(rules, dealt.faces, seed_prefix + [entry.k], FINAL_RUNS)
		var s := score(stats, target_win, target_decoy)
		var passes := accept(stats, spec, first_level, entry.free, relax_used)
		var better: bool = best.is_empty() or (passes and not best.passes) or (passes == best.passes \
				and (s < best.score or (s == best.score and int(entry.k) < int(best.k))))
		if better:
			best = {"k": entry.k, "deal": dealt, "stats": stats, "score": s, "rate": entry.rate, "passes": passes}
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
	for key: String in ["random_win", "careful_win", "wary_win", "avg_free_pairs", "decoy_exposure", "difficulty"]:
		stats[key] = snappedf(float(stats[key]), 0.001)
	stats["trap_rate"] = snappedf(float(best.rate), 0.001)
	stats["par_ms"] = par_ms(geometry, data.faces, data.features, float(stats.difficulty))
	data.stats = stats
	return data
