extends SceneTree
## Drafts the v3 Halves plan (tools/levelgen/halves_plan_v3.json: 300 levels in 15 places of 20,
## docs/HALVES.md 4b), the v3 pool recipes (halves_pools.json) and adds the catalogue masks it picks
## to halves_masks.json as v3_<catalogue id>. Deterministic (seeded); run mask_catalogue.gd first.
## Afterwards the JSON files are the human's to tune. The v2 plan stays as it was (its draft: git 2792f42).

const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"
const PLAN_PATH: String = "res://tools/levelgen/halves_plan_v3.json"
const POOLS_PATH: String = "res://tools/levelgen/halves_pools.json"
const CATALOGUE_PATH: String = "res://build/levelgen/mask_catalogue.json"
const LEVELS: int = 300
const PER_PLACE: int = 20
const SEED_VERSION: int = 3

## Roles by position 1-20 in a place (level 1 is the intro).
const ROLES: Array[String] = ["rest", "ramp", "ramp", "ramp", "hard", "breather", "ramp", "ramp", "ramp", "hard",
	"rest", "ramp", "ramp", "ramp", "hard", "breather", "ramp", "ramp", "hard", "finale"]
## Where each position's board sits between the place's smallest and largest size (a sawtooth).
const SIZE_AT: Array[float] = [0.1, 0.35, 0.45, 0.55, 0.78, 0.25, 0.42, 0.52, 0.62, 0.84,
	0.15, 0.48, 0.58, 0.68, 0.9, 0.3, 0.6, 0.72, 0.94, 1.0]
## Distinct pair types = pairs * ratio (at least 3), the ratio going from the first entry in place 2
## to the second in place 15 (type_ratio()). (v3 tuning) 4b drafted 0.5 / 0.55 / 0.6 / 0.65: with
## two copies a type the PERCEPTIVE bot meets a twin on most moves, rest levels fell to p3 0.3-0.6
## and mid-place ramps could not reach their targets, so every role but the intro gets fewer copies
## (more distinct types), more so in the early places.
const TYPE_RATIO: Dictionary = {"intro": [0.5, 0.5], "rest": [0.7, 0.7], "breather": [0.7, 0.7],
	"ramp": [0.85, 0.7], "hard": [0.75, 0.68], "finale": [0.75, 0.68]}
const TIPS: Dictionary = {1: "pair", 2: "layers", 3: "sides", 4: "decoy", 6: "trap", 8: "cut_h", 10: "diamond",
	21: "lookalike", 61: "mist", 101: "lock", 121: "lucky", 141: "frost", 161: "gold_pair", 162: "mend", 181: "turned"}
## The first level of each mechanic (its tip level).
const INTRO_MIST: int = 61
const INTRO_LOCK: int = 101
const INTRO_LUCKY: int = 121
const INTRO_FROST: int = 141
const INTRO_GOLD: int = 161
const INTRO_TURNED: int = 181
## Face sizes the boards keep (tests/test_halves_game.gd): the board areas at 720 x 1280 with a
## 64/32 px notch, 720 x 1280, 960 x 1280 and 720 x 1600, and the smallest face allowed in each,
## plus a pixel of margin so later HUD tweaks stay safe.
const FIT_AREAS: Array[Vector2] = [Vector2(672, 874), Vector2(672, 970), Vector2(820, 970), Vector2(672, 1290)]
const FIT_MIN: Array[float] = [85.0, 97.0, 97.0, 97.0]

var _masks: Dictionary = {}
var _info: Array[Dictionary] = []


func _initialize() -> void:
	var masks_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MASKS_PATH))
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE_PATH))
	if not catalogue is Dictionary:
		printerr("build_plan: run tools/levelgen/mask_catalogue.gd first (%s missing)" % CATALOGUE_PATH)
		quit(1)
		return
	_masks = masks_file.masks
	# Earlier picks are dropped and picked again from the catalogue, so a rerun gives the same plan.
	for name: String in _masks.keys():
		if name.begins_with("v3_"):
			_masks.erase(name)
	_collect(catalogue)
	var slots: Array = []
	var used: Dictionary = {}
	var base_uses: Dictionary = {}
	var picked_bases: Array[String] = []
	var last_base := ""
	var last_mask := ""
	for level in range(1, LEVELS + 1):
		var place := (level - 1) / PER_PLACE + 1
		var pos := (level - 1) % PER_PLACE + 1
		var role := "intro" if level == 1 else ROLES[pos - 1]
		var pick := _pick_mask(level, place, pos, role, used, base_uses, last_base, last_mask)
		if not used.has(pick.name):
			used[pick.name] = []
		used[pick.name].append(level)
		# Variety within a place: a base shape counts against itself for the next 20 levels.
		base_uses[pick.base] = int(base_uses.get(pick.base, 0)) + 1
		picked_bases.append(pick.base)
		if level > PER_PLACE:
			var old: String = picked_bases[level - 1 - PER_PLACE]
			base_uses[old] = int(base_uses[old]) - 1
		last_base = pick.base
		last_mask = pick.name
		if not _masks.has(pick.name):
			_masks[pick.name] = {"layers": pick.layers}
		slots.append(_slot(level, place, pos, role, pick))
	_write_masks(masks_file.about)
	_write_plan(slots)
	_write_pools(slots)
	_summary(slots)
	quit()


## Every usable mask: the hand-made ones in halves_masks.json and the catalogue's, once per shape.
func _collect(catalogue: Dictionary) -> void:
	var seen: Dictionary = {}
	var names: Array = _masks.keys()
	names.sort()
	var entries: Array = []
	for name: String in names:
		entries.append([name, _masks[name].layers, false])
	var ids: Array = catalogue.keys()
	ids.sort()
	for id: String in ids:
		entries.append(["v3_" + id, catalogue[id], true])
	for entry: Array in entries:
		var name: String = entry[0]
		var layers: Array = entry[1]
		var positions := HalvesMask.parse(layers)
		if positions.is_empty() or not HalvesMask.validate(positions).is_empty():
			continue
		var key := str(positions)
		if seen.has(key):
			continue
		seen[key] = true
		var geometry := HalvesGeometry.from_positions(positions)
		if not faces_fit(geometry):
			continue
		var from_catalogue: bool = entry[2]
		if from_catalogue and not _symmetric(positions):
			continue
		_info.append({"name": name, "layers": layers, "tiles": positions.size(), "depth": geometry.max_z() + 1,
			"free": HalvesBits.count(geometry.free_mask(geometry.full_mask())),
			"base": (name.split("_")[1] if from_catalogue else name.split("_")[0] + "_" + name.split("_")[1]),
			"picture": name.begins_with("pic_"), "tutorial": name.begins_with("p1_"), "catalogue": from_catalogue})


## True if the board keeps its faces big enough on every test screen.
static func faces_fit(geometry: HalvesGeometry) -> bool:
	for i in FIT_AREAS.size():
		var unit := HalvesBoardView.unit_for(FIT_AREAS[i], geometry.bounds(), geometry.max_z())
		if unit * HalvesBoardView.FACE_W < FIT_MIN[i]:
			return false
	return true


static func target_tiles(place: int, pos: int, level: int) -> int:
	if level == 1:
		return 12
	var t := clampf((place - 1) / 10.0, 0.0, 1.0)
	var lo := lerpf(12.0, 56.0, t)
	var hi := lerpf(32.0, 112.0, t)
	return int(roundf(lerpf(lo, hi, SIZE_AT[pos - 1]) / 2.0)) * 2


static func want_layers(place: int, role: String, level: int) -> int:
	if level == 1:
		return 1
	if place == 1:
		match role:
			"hard", "finale":
				return 3
			"ramp":
				return 2 if level < 10 else 3
		return 2
	var late := place >= 8
	match role:
		"rest":
			return 3 if late else 2
		"breather":
			return 3 if place >= 5 else 2
		"ramp":
			return 4 if late else 3
		"hard":
			return 5 if place >= 9 else (4 if place >= 4 else 3)
		"finale":
			return 5 if place >= 5 else 4
	return 2


func _pick_mask(level: int, place: int, pos: int, role: String, used: Dictionary, base_uses: Dictionary,
		last_base: String, last_mask: String) -> Dictionary:
	var target := target_tiles(place, pos, level)
	var layers := want_layers(place, role, level)
	var heavy := role == "hard" or role == "finale"
	var best: Dictionary = {}
	var best_score := INF
	for m: Dictionary in _info:
		var levels: Array = used.get(m.name, [])
		var uses := levels.size()
		if m.name == last_mask:
			continue
		# Pictures come back up to three times, other shapes once more after 40 levels (the big
		# boards of places 11-15 would otherwise run out), tutorial masks never.
		if m.picture:
			if uses >= 3 or (uses > 0 and level - int(levels.back()) < 10):
				continue
		elif uses > 0 and (m.tutorial or uses >= 2 or level - int(levels.back()) < 40):
			continue
		if int(m.tiles) > HalvesGeometry.MAX_TILES - 8:
			continue
		var min_free := mini(6, maxi(3, int(m.tiles) / 5))
		if int(m.free) < min_free:
			continue
		var score := 3.0 * absi(int(m.tiles) - target) + (40.0 if level == 1 else 6.0) * absi(int(m.depth) - layers) \
				+ 8.0 * int(base_uses.get(m.base, 0)) + (20.0 if m.base == last_base else 0.0)
		if m.picture:
			score += 30.0 * uses + (-40.0 if heavy and place >= 5 else 25.0)
		else:
			score += 45.0 * uses
		if m.tutorial:
			score += -10.0 if place == 1 else 1000.0
		if score < best_score:
			best_score = score
			best = m
	return best


func _slot(level: int, place: int, pos: int, role: String, pick: Dictionary) -> Dictionary:
	var rng := SeedService.make_rng(["halves", "plan_v3", level], SEED_VERSION)
	var pairs := int(pick.tiles) / 2
	var depth := lookalike_depth(place, role, level)
	var slot := {"level": level, "place": place, "role": role, "mask": pick.name,
		"types": draft_slot_types(level, place, role, pairs, depth, rng), "depth": depth}
	slot.merge(_targets(level, place, pos, role))
	# CAREFUL's greedy (free the most tiles) is no human model on tall stacks: on big boards its
	# floor fades to 0 between 48 and 96 tiles, and WARY's floor and p3 judge fairness alone.
	slot.min_careful = snappedf(float(slot.min_careful) * clampf((96.0 - int(pick.tiles)) / 48.0, 0.0, 1.0), 0.01)
	var mechanics := _mechanics(level, place, pos, role, depth, rng)
	slot.merge(mechanics)
	if TIPS.has(level):
		slot.tip = TIPS[level]
	return slot


## Look-alike depth (4b): 1 in place 1 (2 for its later hard levels, which mix both cuts) and on
## rest levels, 2 for ramps from place 2, 3 for hard and finale from place 4. Level 21 brings
## look-alikes, so it shows a pair of them. (v3 tuning) 4b drafted depth 2 for rest levels from
## place 3; those broke the sawtooth (rest p3 under the ramps'), so rest levels stay at 1.
static func lookalike_depth(place: int, role: String, level: int) -> int:
	if place == 1:
		return 2 if (role == "hard" or role == "finale") and level >= 8 else 1
	if level == 21:
		return 2
	match role:
		"intro", "rest", "breather":
			return 1
		"ramp":
			return 2
	return 2 if place <= 3 else 3


static func type_ratio(role: String, place: int) -> float:
	var ends: Array = TYPE_RATIO[role]
	return lerpf(float(ends[0]), float(ends[1]), clampf((place - 2) / 13.0, 0.0, 1.0))


static func draft_slot_types(level: int, place: int, role: String, pairs: int, depth: int, rng: RandomNumberGenerator,
		ratio: float = -1.0) -> Array:
	var count := maxi(3, roundi(pairs * (type_ratio(role, place) if ratio < 0.0 else ratio)))
	var horizontal := level >= 8
	var h_share := 1.0 / 3.0
	if place == 1:
		var shapes: Array = ["circle", "tri", "square"]
		if level >= 10:
			shapes.append("diamond")
		var room := 0
		for group: Variant in HalvesGenerator.family_groups(&"shapes", horizontal, shapes):
			room += mini(depth, (HalvesGenerator.family_groups(&"shapes", horizontal, shapes)[group][0] as Array).size())
		count = mini(count, room)
		if level == 8:
			h_share = 1.0
		return HalvesGenerator.draft_types([&"shapes"], [count], [], count, depth, h_share, horizontal, rng, shapes)
	var met := HalvesGenerator.families_until(place)
	var main: StringName = HalvesGenerator.PLACE_FAMILIES[place - 1]
	var families: Array = []
	var quotas: Array = []
	if main != &"":
		var main_quota := mini(count, roundi(count * 0.6))
		families.append(main)
		quotas.append(main_quota)
		var earlier: Array = met.filter(func(f: StringName) -> bool: return f != main)
		HalvesGenerator._shuffle(earlier, rng)
		var others := mini(2 if count - main_quota >= 4 else 1, earlier.size())
		for i in others:
			families.append(earlier[i])
			quotas.append((count - main_quota) / others + (1 if i < (count - main_quota) % others else 0))
	else:
		var crests: Array = met.filter(func(f: StringName) -> bool: return f != &"shapes")
		HalvesGenerator._shuffle(crests, rng)
		var n := 2 if role in ["rest", "breather", "intro"] else (3 if role in ["hard", "finale"] else 2 + rng.randi_range(0, 1))
		for i in n:
			families.append(crests[i])
			quotas.append(count / n + (1 if i < count % n else 0))
	# Spare families fill what the chosen ones cannot (depth caps each group): crests first, shapes last.
	var spare: Array = met.filter(func(f: StringName) -> bool: return not families.has(f) and f != &"shapes")
	HalvesGenerator._shuffle(spare, rng)
	if not families.has(&"shapes"):
		spare.append(&"shapes")
	if level == 21:
		h_share = 0.0
	return HalvesGenerator.draft_types(families, quotas, spare, count, depth, h_share, horizontal, rng)


## Targets by role and place (4b): falling linearly from place 1 to place 15, a little lower
## further into each run of ramps and in a place's second half; place 1 gentler.
static func _targets(level: int, place: int, pos: int, role: String) -> Dictionary:
	var t := (place - 1) / 14.0
	var run_step := 0
	if role == "ramp":
		run_step = [0, 0, 1, 2, 0, 0, 0, 1, 2, 0, 0, 0, 1, 2, 0, 0, 0, 1, 0, 0][pos - 1]
	var late := 0.03 if pos > 10 else 0.0
	var out := {}
	match role:
		"intro":
			out = {"target_p3": 1.0, "target_win": 1.0, "trap": [0.0, 0.0], "min_careful": 1.0, "min_wary": 1.0}
		"rest", "breather":
			out = {"target_p3": 0.85, "target_win": 0.8, "trap": [0.0, 0.1], "min_careful": 0.8, "min_wary": 0.97}
		"ramp":
			out = {"target_p3": lerpf(0.75, 0.55, t) - 0.03 * run_step - late,
				"target_win": lerpf(0.55, 0.35, t) - 0.03 * run_step - late,
				"trap": [0.15, 0.3], "min_careful": 0.6, "min_wary": 0.9}
		"hard":
			out = {"target_p3": lerpf(0.45, 0.3, t) - late, "target_win": lerpf(0.3, 0.15, t) - late,
				"trap": [0.3, 0.5], "min_careful": 0.4, "min_wary": 0.75}
		"finale":
			out = {"target_p3": lerpf(0.35, 0.2, t), "target_win": lerpf(0.15, 0.05, t),
				"trap": [0.4, 0.6], "min_careful": 0.3, "min_wary": 0.6}
	if place == 1:
		out.target_p3 = maxf(0.8, float(out.target_p3))
		match role:
			"ramp":
				out.target_win = 0.9 if level <= 4 else 0.7 - 0.03 * run_step
				out.trap = [0.0, 0.0] if level <= 4 else [0.1, 0.25]
				out.min_wary = 1.0 if level <= 4 else 0.95
				out.min_careful = 0.9 if level <= 4 else 0.7
			"hard":
				out.target_win = 0.5 if level == 5 else 0.45
				out.trap = [0.2, 0.4]
				out.min_wary = 0.85
				out.min_careful = 0.5
			"finale":
				out.target_win = 0.3
				out.min_wary = 0.75
		if level == 6:
			# The trap tip: a board with at least one trap to look under.
			out.trap = [0.25, 0.4]
			out.min_wary = 0.9
	for key: String in ["target_p3", "target_win", "min_careful", "min_wary"]:
		out[key] = snappedf(float(out[key]), 0.01)
	return out


## Feature spec, gold pair, turned and lucky counts (4b): each mechanic arrives on its place's first
## rest level and recurs from position 6, then mixes into later places; positions 2-5 never use the
## place's new idea; rest levels and breathers keep at most one; mist stays on ramps, at most 2 tiles.
static func _mechanics(level: int, place: int, pos: int, role: String, depth: int, rng: RandomNumberGenerator) -> Dictionary:
	var calm := role in ["rest", "breather", "intro"]
	var heavy := role in ["hard", "finale"]
	var features := {}
	var out := {}
	var kinds := 0
	# The idea's own level.
	match level:
		INTRO_MIST:
			features.mist = 2
		INTRO_LOCK:
			features.key_pairs = 1
			features.locked = 2
		INTRO_LUCKY:
			out.lucky = 2
		INTRO_FROST:
			features.frost = 2
		INTRO_GOLD, INTRO_GOLD + 1:
			out.gold_pair = 1
		INTRO_TURNED:
			out.turned = 2
	if not (features.is_empty() and out.is_empty()):
		if not features.is_empty():
			out.features = features
		return out
	# Chance of each mechanic on this board: [first level, chance in its own place (pos >= 6), later].
	var own := func(intro: int) -> bool: return (intro - 1) / PER_PLACE + 1 == place
	var chance := func(intro: int, in_place: float, later: float) -> float:
		if level < intro:
			return 0.0
		if own.call(intro):
			return in_place if pos >= 6 else 0.0
		return later
	var draws := {
		"mist": rng.randf(), "lock": rng.randf(), "frost": rng.randf(), "lucky": rng.randf(),
		"gold": rng.randf(), "turned": rng.randf(), "size": rng.randf(),
	}
	if role == "ramp" and draws.mist < chance.call(INTRO_MIST, 0.5, 0.12):
		features.mist = 1 + (1 if draws.size < 0.5 else 0)
		kinds += 1
	if not calm and draws.lock < chance.call(INTRO_LOCK, 0.6, 0.25):
		features.key_pairs = 2 if role == "finale" else 1
		features.locked = 2 + (1 if heavy else 0) + (1 if draws.size < 0.4 else 0)
		kinds += 1
	if not calm and draws.frost < chance.call(INTRO_FROST, 0.6, 0.25):
		features.frost = 2 + (2 if heavy else 0) + (1 if draws.size > 0.6 else 0)
		kinds += 1
	if not (calm and kinds > 0) and draws.lucky < chance.call(INTRO_LUCKY, 0.55, 0.45):
		out.lucky = 1 + int(draws.size * 3.0) if not calm else 1 + int(draws.size * 2.0)
		kinds += 1
	if not (calm and kinds > 0) and draws.gold < chance.call(INTRO_GOLD, 0.35, 0.25):
		out.gold_pair = 1
		kinds += 1
	if depth >= 2 and not (calm and kinds > 0) and draws.turned < chance.call(INTRO_TURNED, 0.65, 0.35):
		out.turned = (2 + int(draws.size * 2.0)) if calm else (2 + int(draws.size * 3.0) + (2 if heavy else 0))
		kinds += 1
	if not features.is_empty():
		out.features = features
	return out


func _symmetric(positions: Array[Vector3i]) -> bool:
	var far := 0
	for p in positions:
		far = maxi(far, p.x + 2)
	var cells: Dictionary = {}
	for p in positions:
		cells[p] = true
	for p in positions:
		if not cells.has(Vector3i(far - 2 - p.x, p.y, p.z)):
			return false
	return true


func _write_masks(about: String) -> void:
	var entries := PackedStringArray()
	for name: String in _masks:
		var layer_texts := PackedStringArray()
		for layer: Array in _masks[name].layers:
			var rows := PackedStringArray()
			for row: String in layer:
				rows.append(JSON.stringify(row))
			layer_texts.append("\t\t\t[" + ",\n\t\t\t ".join(rows) + "]")
		entries.append("\t\t%s: {\"layers\": [\n%s\n\t\t]}" % [JSON.stringify(name), ",\n".join(layer_texts)])
	var text := "{\n\t\"format\": 1,\n\t\"about\": %s,\n\t\"masks\": {\n%s\n\t}\n}\n" % [JSON.stringify(about), ",\n".join(entries)]
	var out := FileAccess.open(MASKS_PATH, FileAccess.WRITE)
	out.store_string(text)
	out.close()


func _write_plan(slots: Array) -> void:
	var lines := PackedStringArray()
	for slot: Dictionary in slots:
		lines.append("\t\t" + JSON.stringify(slot, "", false))
	var about := "Halves v3 level order (draft for the human to tune; drafted by tools/levelgen/build_plan.gd). 15 places of 20: rest, ramp x3, hard, breather, ramp x3, hard, rest, ramp x3, hard, breather, ramp x2, hard, finale; a place's new idea arrives on its first rest level. types = pair types round-robin over tiles/2 pairs (depth = look-alike chunk size they were drafted with); target_p3 = share of PERCEPTIVE games that clear within the slip allowance; target_win = RANDOM's win rate; trap = trap-seeding rates; min_careful / min_wary = floors; features / gold_pair / turned / lucky = the mechanics. See docs/HALVES.md sections 3, 4b and 6."
	var text := "{\n\t\"format\": 3,\n\t\"about\": %s,\n\t\"slots\": [\n%s\n\t]\n}\n" % [JSON.stringify(about), ",\n".join(lines)]
	var out := FileAccess.open(PLAN_PATH, FileAccess.WRITE)
	out.store_string(text)
	out.close()


## Pool recipes (v3): daily by weekday (Monday gentle, Sunday a finale), zen calm and mid-size, rush
## small; every recipe draws its types from 2-3 crest families a board (all families mix).
func _write_pools(slots: Array) -> void:
	var names: Array = []
	for slot: Dictionary in slots:
		if not names.has(slot.mask) and int(slot.level) > 20:
			names.append(slot.mask)
	for m: Dictionary in _info:
		if m.picture and not names.has(m.name):
			names.append(m.name)
	var pick := func(lo: int, hi: int) -> Array:
		var out: Array = []
		for name: String in names:
			var tiles := HalvesMask.parse(_masks[name].layers).size()
			if tiles >= lo and tiles <= hi:
				out.append(name)
		out.sort()
		return out
	var weekdays := ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
	var sizes := [[28, 40], [34, 48], [40, 56], [46, 64], [52, 72], [60, 84], [70, 100]]
	var p3 := [0.85, 0.75, 0.65, 0.55, 0.45, 0.38, 0.28]
	var win := [0.8, 0.6, 0.5, 0.42, 0.32, 0.22, 0.12]
	var traps := [[0.0, 0.1], [0.1, 0.25], [0.15, 0.3], [0.2, 0.35], [0.3, 0.45], [0.35, 0.5], [0.4, 0.6]]
	var careful := [0.8, 0.7, 0.6, 0.55, 0.5, 0.4, 0.3]
	var wary := [0.97, 0.93, 0.9, 0.85, 0.8, 0.72, 0.6]
	var depth := [1, 2, 2, 2, 3, 3, 3]
	var ratio := [0.7, 0.75, 0.75, 0.75, 0.7, 0.7, 0.7]
	var mechanics := [
		{"lucky": 1},
		{"lucky": 2},
		{"features": {"mist": 2}, "lucky": 1},
		{"features": {"key_pairs": 1, "locked": 3}},
		{"features": {"frost": 3}, "lucky": 2},
		{"turned": 4, "gold_pair": 0.5},
		{"features": {"key_pairs": 1, "locked": 3, "frost": 3}, "turned": 4},
	]
	var daily := {}
	for d in 7:
		var recipe := {"masks": pick.call(sizes[d][0], sizes[d][1]), "target_p3": p3[d], "target_win": win[d],
			"trap": traps[d], "min_careful": careful[d], "min_wary": wary[d], "depth": depth[d],
			"type_ratio": ratio[d], "families": 2 if d < 4 else 3}
		recipe.merge(mechanics[d])
		daily[weekdays[d]] = recipe
	var pools := {
		"format": 3,
		"about": "Recipes for the Daily, Zen and Rush pools (docs/HALVES.md sections 3, 4 and 4b, v3). Daily boards follow the weekday of their date. Each board draws its mask from masks, round(pairs * type_ratio) pair types from `families` crest families picked at random (look-alike chunks of `depth`), and its mechanics: features, turned and lucky counts, gold_pair as a chance.",
		"daily": {"count": 400, "id_base": 10000, "candidates": 30, "by_weekday": daily},
		"zen": {"count": 150, "id_base": 20000, "candidates": 24, "recipe": {
			"masks": pick.call(36, 64), "target_p3": 0.85, "target_win": 0.8, "trap": [0.0, 0.1],
			"min_careful": 0.85, "min_wary": 0.97, "depth": 1, "type_ratio": 0.7, "families": 2, "lucky": 1}},
		"rush": {"count": 150, "id_base": 30000, "candidates": 16, "recipe": {
			"masks": pick.call(12, 24), "target_p3": 0.9, "target_win": 0.95, "trap": [0.0, 0.0],
			"min_careful": 0.95, "min_wary": 1.0, "depth": 1, "type_ratio": 0.7, "families": 2}},
	}
	var out := FileAccess.open(POOLS_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(pools, "\t") + "\n")
	out.close()


func _summary(slots: Array) -> void:
	print("place  tiles(min-max)  layers  types  depth  mist lock frost lucky gold turned  pictures")
	for place in range(1, LEVELS / PER_PLACE + 1):
		var tiles := 0
		var lo := 1000
		var hi := 0
		var layers := 0
		var types := 0
		var depth := 0
		var counts := {"mist": 0, "lock": 0, "frost": 0, "lucky": 0, "gold": 0, "turned": 0, "pic": 0}
		for slot: Dictionary in slots:
			if int(slot.place) != place:
				continue
			var positions := HalvesMask.parse(_masks[slot.mask].layers)
			tiles += positions.size()
			lo = mini(lo, positions.size())
			hi = maxi(hi, positions.size())
			layers += HalvesGeometry.from_positions(positions).max_z() + 1
			types += (slot.types as Array).size()
			depth += int(slot.depth)
			var f: Dictionary = slot.get("features", {})
			counts.mist += 1 if f.has("mist") else 0
			counts.lock += 1 if f.has("locked") else 0
			counts.frost += 1 if f.has("frost") else 0
			counts.lucky += 1 if slot.has("lucky") else 0
			counts.gold += 1 if slot.has("gold_pair") else 0
			counts.turned += 1 if slot.has("turned") else 0
			counts.pic += 1 if str(slot.mask).begins_with("pic_") else 0
		print("%5d  %5.1f (%3d-%3d)  %6.2f  %5.1f  %5.2f  %4d %4d %5d %5d %4d %6d  %8d" % [place, tiles / 20.0, lo, hi,
				layers / 20.0, types / 20.0, depth / 20.0, counts.mist, counts.lock, counts.frost, counts.lucky,
				counts.gold, counts.turned, counts.pic])
	var buckets := PackedStringArray()
	for lo in range(10, 120, 10):
		var n := 0
		for m: Dictionary in _info:
			n += 1 if int(m.tiles) >= lo and int(m.tiles) < lo + 10 else 0
		buckets.append("%d-%d: %d" % [lo, lo + 9, n])
	print("usable masks by tiles: " + ", ".join(buckets))
	print("build_plan: %d slots -> %s, %d masks in %s" % [slots.size(), PLAN_PATH, _masks.size(), MASKS_PATH])
