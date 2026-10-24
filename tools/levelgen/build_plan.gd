extends SceneTree
## Drafts the 100-level Halves plan (tools/levelgen/halves_plan.json), the pool recipes
## (halves_pools.json) and the masks levels 31+ need (picked from build/levelgen/mask_catalogue.json).
## Run once to start a curve; afterwards the JSON files are the source of truth, tuned by hand.

const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"
const PLAN_PATH: String = "res://tools/levelgen/halves_plan.json"
const POOLS_PATH: String = "res://tools/levelgen/halves_pools.json"
const CATALOGUE_PATH: String = "res://build/levelgen/mask_catalogue.json"

## Tiles per level (5 chapters x 20). Levels 1-30 keep their hand-made masks.
const SIZES: Array[int] = [
	8, 12, 16, 18, 24, 16, 24, 26, 30, 32, 20, 24, 28, 32, 38, 24, 34, 38, 42, 48,
	28, 34, 38, 42, 50, 32, 46, 52, 56, 64, 32, 42, 44, 46, 52, 36, 46, 48, 50, 56,
	34, 44, 46, 48, 54, 36, 46, 48, 50, 56, 38, 48, 50, 52, 58, 40, 50, 52, 54, 60,
	38, 48, 50, 52, 58, 40, 50, 52, 54, 60, 42, 52, 54, 56, 60, 44, 54, 56, 58, 62,
	44, 52, 54, 56, 60, 46, 54, 56, 58, 62, 48, 56, 58, 60, 62, 50, 58, 60, 62, 64,
]
const FIRST_MASKS: Array[String] = [
	"p1_intro", "p1_two_layers", "p1_terrace", "p1_shelf", "p1_block",
	"p1_pyramid", "p1_steps", "p1_towers", "p1_cross", "p1_finale",
	"p2_window", "p2_hex", "p2_twin_towers", "p2_wall", "p2_keep",
	"p2_ring", "p2_hourglass", "p2_terraces", "p2_mound", "p2_finale",
	"p3_steps", "p3_bridges", "p3_lanterns", "p3_gate", "p3_ziggurat",
	"p3_pagoda", "p3_climb", "p3_dome", "p3_spire", "p3_finale",
]
## When each pair type first appears (level -> keys). All 21 keys are in play by level 52.
const INTRODUCE: Dictionary = {
	1: ["circle:v:-", "tri:v:-"], 2: ["square:v:-"], 6: ["circle:h:-"], 7: ["diamond:v:-"],
	8: ["tri:v:dot"], 9: ["square:v:line"], 12: ["square:h:-"], 14: ["circle:v:dot"],
	16: ["diamond:h:-"], 18: ["circle:h:line"], 22: ["tri:v:line"], 24: ["square:v:dot"],
	26: ["diamond:v:line"], 28: ["circle:v:line"], 32: ["square:h:dot"], 34: ["diamond:h:dot"],
	36: ["circle:h:dot"], 44: ["square:h:line"], 46: ["diamond:v:dot"], 52: ["diamond:h:line"],
}
## The board area of the game screen at 720x1280 with a notch, and the smallest face allowed there
## (tests/test_halves_game.gd demands 96 px; a pixel of margin keeps later HUD tweaks safe).
const BOARD_AREA: Vector2 = Vector2(680, 890)
const MIN_FACE: float = 97.0
const TIPS: Dictionary = {
	1: "pair", 2: "layers", 3: "sides", 4: "decoy", 5: "trap", 6: "cut_h", 7: "diamond",
	8: "dot", 9: "line", 11: "gold", 21: "mist", 41: "lock", 61: "frost",
}


func _initialize() -> void:
	var masks_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MASKS_PATH))
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE_PATH))
	var masks: Dictionary = masks_file.masks
	var picks := _pick_masks(catalogue)
	var slots: Array = []
	for level in range(1, 101):
		var mask_name := FIRST_MASKS[level - 1] if level <= FIRST_MASKS.size() else str(picks[level])
		if level > FIRST_MASKS.size():
			masks[mask_name] = {"layers": catalogue[str(picks["id_%d" % level])]}
		var tiles := HalvesMask.parse(masks[mask_name].layers).size()
		slots.append(_slot(level, mask_name, tiles))
	_write_masks(masks_file.about, masks)
	_write_plan(slots)
	_write_pools(masks)
	print("build_plan: %d slots, %d masks" % [slots.size(), masks.size()])
	quit()


func _slot(level: int, mask_name: String, tiles: int) -> Dictionary:
	var chapter := (level - 1) / 20 + 1
	var pos := (level - 1) % 10 + 1
	var second_pack := ((level - 1) / 10) % 2 == 1
	var role := "ramp"
	if level <= 4:
		role = "intro"
	elif pos == 5:
		role = "hard"
	elif pos == 10:
		role = "finale"
	elif pos == 1 or pos == 6:
		role = "rest"
	var step := float(chapter - 1) + (0.5 if second_pack else 0.0)
	var slot := {"level": level, "role": role, "mask": mask_name, "types": _types(level, tiles / 2)}
	match role:
		"intro":
			slot.target_win = 1.0 if level < 4 else 0.95
			slot.trap = [0.0, 0.0]
			slot.min_careful = 0.9
			slot.min_wary = 0.95
		"rest":
			slot.target_win = 0.85
			slot.trap = [0.0, 0.1]
			slot.min_careful = 0.8
			slot.min_wary = 0.95
		"ramp":
			var in_run := (pos - 2) % 5
			slot.target_win = snappedf(0.66 - 0.05 * step - 0.05 * in_run, 0.01)
			slot.trap = [0.15, 0.3]
			slot.min_careful = 0.6
			slot.min_wary = 0.8
		"hard":
			slot.target_win = 0.5 if level == 5 else snappedf(0.36 - 0.05 * step, 0.01)
			slot.trap = [0.3, 0.5]
			slot.min_careful = 0.4
			slot.min_wary = 0.7 if level == 5 else 0.55
		"finale":
			slot.target_win = 0.35 if level == 10 else snappedf(0.26 - 0.045 * step, 0.01)
			slot.trap = [0.4, 0.6]
			slot.min_careful = 0.3
			slot.min_wary = 0.55 if level == 10 else 0.4
	slot.target_decoy = snappedf(minf(2.5, 0.3 + 0.03 * level), 0.01)
	var features := _features(level, role, pos)
	if not features.is_empty():
		slot.features = features
	if TIPS.has(level):
		slot.tip = TIPS[level]
	return slot


## Pair types: every key introduced so far is available; the newest ones are always in, the rest
## are chosen so shapes come in near-twin families (more decoys), about 2.6 copies per type.
func _types(level: int, pairs: int) -> Array:
	var available: Array = []
	var newest: Array = []
	for at: int in INTRODUCE:
		if at <= level:
			available.append_array(INTRODUCE[at])
			if at > level - 3:
				newest.append_array(INTRODUCE[at])
	var want := clampi(roundi(pairs / 2.6), 2, available.size())
	if level <= 5:
		want = mini(available.size(), 3 if level >= 2 else 2)
	var rng := SeedService.make_rng(["halves", "plan_types", level], 2)
	var rest := available.filter(func(k: String) -> bool: return not newest.has(k))
	var order := PackedInt32Array()
	for i in rest.size():
		order.append(i)
	HalvesFill.shuffle_ints(order, rng)
	var types: Array = newest.slice(0, want)
	for i in order:
		if types.size() >= want:
			break
		types.append(rest[i])
	return types


func _features(level: int, role: String, pos: int) -> Dictionary:
	var f: Dictionary = {}
	if level >= 11 and (role == "rest" or role == "finale" or level % 2 == 1):
		f.gold = 4 if role == "rest" or role == "finale" else 2
	var chapter := (level - 1) / 20 + 1
	var heavy := role == "hard" or role == "finale"
	var mist := level >= 21 and (chapter == 2 and pos != 6 or chapter == 5 and level % 2 == 0 or chapter > 2 and level % 5 == 3)
	var lock := level >= 41 and (chapter == 3 and pos != 6 or chapter == 5 and level % 3 != 0 or chapter == 4 and level % 5 == 2)
	var frost := level >= 61 and (chapter == 4 and pos != 6 or chapter == 5 and level % 2 == 1)
	if level == 21:
		mist = true
	if level == 41:
		lock = true
	if level == 61:
		frost = true
	if mist:
		f.mist = 4 if level == 21 else (8 if heavy else 5)
	if lock:
		f.key_pairs = 2 if role == "finale" else 1
		f.locked = 2 if level == 41 else (5 if heavy else 3)
	if frost:
		f.frost = 2 if level == 61 else (6 if heavy else 4)
	return f


## Catalogue masks for levels 31-100: mirror-symmetric, near the size, layers by chapter, varied.
func _pick_masks(catalogue: Dictionary) -> Dictionary:
	var info: Array = []
	for id: String in catalogue:
		var layers: Array = catalogue[id]
		var positions := HalvesMask.parse(layers)
		if layers.size() < 2 or not _symmetric(positions):
			continue
		# A pure pyramid only frees its top tile or two: no choice at all at the start.
		var geometry := HalvesGeometry.from_positions(positions)
		if HalvesBits.count(geometry.free_mask(geometry.full_mask())) < 6:
			continue
		if not _faces_fit(geometry):
			continue
		info.append({"id": id, "tiles": positions.size(), "layers": layers.size(), "base": id.split("_")[0]})
	info.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var used: Dictionary = {}
	var base_uses: Dictionary = {}
	var picks: Dictionary = {}
	var last_base := ""
	for level in range(FIRST_MASKS.size() + 1, 101):
		var chapter := (level - 1) / 20 + 1
		var pos := (level - 1) % 10 + 1
		var want_layers := 2 if pos == 1 or pos == 6 else (4 if pos == 10 and chapter >= 3 else 3)
		var best: Dictionary = {}
		var best_score := INF
		for m: Dictionary in info:
			if used.has(m.id):
				continue
			var score := 3.0 * absi(int(m.tiles) - SIZES[level - 1]) + 5.0 * absi(int(m.layers) - want_layers) \
					+ 8.0 * int(base_uses.get(m.base, 0)) + (20.0 if m.base == last_base else 0.0)
			if score < best_score:
				best_score = score
				best = m
		used[best.id] = true
		base_uses[best.base] = int(base_uses.get(best.base, 0)) + 1
		last_base = best.base
		picks[level] = "c%d_%s" % [chapter, best.id]
		picks["id_%d" % level] = best.id
	return picks


func _faces_fit(geometry: HalvesGeometry) -> bool:
	var unit := HalvesBoardView.unit_for(BOARD_AREA, geometry.bounds(), geometry.max_z())
	return unit * HalvesBoardView.FACE_W >= MIN_FACE


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


func _write_masks(about: String, masks: Dictionary) -> void:
	var entries := PackedStringArray()
	for name: String in masks:
		var layer_texts := PackedStringArray()
		for layer: Array in masks[name].layers:
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
	var about := "Halves level order (draft for the human to tune; drafted by tools/levelgen/build_plan.gd). Sawtooth packs of 10: x1/x6 rest levels bring a new idea, x5 hard, x0 finale; 5 chapters of 20. target_win = share of random-bot games that clear without getting stuck; trap = trap-seeding rates; min_careful / min_wary = fairness floors; features = HalvesFeatures.place spec. See docs/HALVES.md sections 3-6."
	var text := "{\n\t\"format\": 2,\n\t\"about\": %s,\n\t\"slots\": [\n%s\n\t]\n}\n" % [JSON.stringify(about), ",\n".join(lines)]
	var out := FileAccess.open(PLAN_PATH, FileAccess.WRITE)
	out.store_string(text)
	out.close()


## Pool recipes: daily by weekday (Monday gentle, Sunday a finale), zen calm and mid-size, rush small.
func _write_pools(masks: Dictionary) -> void:
	var by_size: Dictionary = {}
	for name: String in masks:
		var positions := HalvesMask.parse(masks[name].layers)
		if not _faces_fit(HalvesGeometry.from_positions(positions)):
			continue
		var tiles := positions.size()
		if not by_size.has(tiles):
			by_size[tiles] = []
		by_size[tiles].append(name)
	var pick := func(lo: int, hi: int) -> Array:
		var names: Array = []
		for tiles: int in by_size:
			if tiles >= lo and tiles <= hi:
				names.append_array(by_size[tiles])
		names.sort()
		return names
	var weekdays := ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
	var daily: Dictionary = {}
	var daily_sizes := [[24, 32], [28, 38], [32, 42], [36, 46], [40, 50], [44, 56], [50, 64]]
	var daily_win := [0.85, 0.7, 0.6, 0.5, 0.4, 0.3, 0.18]
	for d in 7:
		var recipe := {
			"masks": pick.call(daily_sizes[d][0], daily_sizes[d][1]),
			"target_win": daily_win[d], "target_decoy": 0.8 + 0.2 * d,
			"trap": [0.1 + 0.05 * d, 0.2 + 0.07 * d],
			"min_careful": 0.8 - 0.07 * d, "min_wary": 0.95 - 0.07 * d,
			"type_count": [5, 6, 7, 8, 9, 10, 11][d],
			"features": {"gold": 2} if d < 4 else ({"gold": 2, "mist": 4} if d == 4 else ({"gold": 2, "key_pairs": 1, "locked": 3} if d == 5 else {"gold": 4, "frost": 4, "mist": 4})),
		}
		daily[weekdays[d]] = recipe
	var pools := {
		"format": 1,
		"about": "Recipes for the Daily, Zen and Rush pools (docs/HALVES.md sections 3-4). Daily boards follow the weekday of their date; type_count pair types are drawn from all 21 keys with seeded rng.",
		"daily": {"count": 400, "id_base": 10000, "candidates": 30, "by_weekday": daily},
		"zen": {"count": 120, "id_base": 20000, "candidates": 24, "recipe": {
			"masks": pick.call(26, 44), "target_win": 0.85, "target_decoy": 1.0, "trap": [0.0, 0.1],
			"min_careful": 0.85, "min_wary": 0.95, "type_count": 7, "features": {"gold": 2}}},
		"rush": {"count": 150, "id_base": 30000, "candidates": 16, "recipe": {
			"masks": pick.call(12, 20), "target_win": 0.95, "target_decoy": 0.6, "trap": [0.0, 0.0],
			"min_careful": 0.95, "min_wary": 1.0, "type_count": 4, "features": {}}},
	}
	var out := FileAccess.open(POOLS_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(pools, "\t") + "\n")
	out.close()
