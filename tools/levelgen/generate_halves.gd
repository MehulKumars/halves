extends SceneTree
## Bakes the Halves levels and pools (v3, docs/HALVES.md 4b): reads the masks, the v3 level plan and
## the pool recipes, deals seeded candidates, rates them with the bots and writes
## data/levels/halves_*_v<GEN_VERSION>.json plus CSV reports and a per-place curve summary. Ranges
## write part files to build/levelgen/ that --merge joins (see below). Only v3 is baked here: v2's
## plan semantics and pool recipes live in git history (2792f42).
##   godot --headless --path . -s tools/levelgen/generate_halves.gd                         all levels
##   ... -- 5                                     preview level 5 (prints the board, writes nothing)
##   ... -- --pool daily                          one pool (daily, zen or rush)
##   ... -- [--pool daily] --range 31-55          only those levels / board indices, to a part file
##   ... -- --merge levels|daily|zen|rush         join the part files into the data file
##   ... -- --curve                               print the curve summary of the baked levels

const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"
const PLAN_PATH: String = "res://tools/levelgen/halves_plan_v3.json"
const POOLS_PATH: String = "res://tools/levelgen/halves_pools.json"
const LEVELS_OUT: String = "res://data/levels/halves_v%d.json"
const POOL_OUT: String = "res://data/levels/halves_%s_v%d.json"
const REPORT_PATH: String = "res://tools/levelgen/reports/halves_%sv%d.csv"
const PARTS_DIR: String = "res://build/levelgen"
const WEEKDAYS: Array[String] = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
const ROLE_ORDER: Array[String] = ["intro", "rest", "breather", "ramp", "hard", "finale"]

var _masks: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_masks = _read_json(MASKS_PATH).get("masks", {})
	var kind := "levels"
	var from := 1
	var to := 1 << 30
	var preview := 0
	var i := 0
	while i < args.size():
		match args[i]:
			"--pool":
				kind = args[i + 1]
				i += 1
			"--range":
				var bounds := args[i + 1].split("-")
				from = int(bounds[0])
				to = int(bounds[1])
				i += 1
			"--merge":
				quit(0 if _merge(args[i + 1]) else 1)
				return
			"--curve":
				var baked := _read_json(LEVELS_OUT % HalvesConfig.GEN_VERSION)
				print_curve(baked.get("levels", []))
				quit()
				return
			_:
				preview = int(args[i])
				from = preview
				to = preview
		i += 1
	var started := Time.get_ticks_msec()
	var log := PackedStringArray()
	var entries: Array = []
	var failed := false
	if kind == "levels":
		for slot: Dictionary in _read_json(PLAN_PATH).get("slots", []):
			var level := int(slot.level)
			if level < from or level > to:
				continue
			if not _masks.has(slot.mask):
				log.append("level %d: unknown mask %s" % [level, slot.mask])
				failed = true
				continue
			var data := HalvesGenerator.build_level(slot, _masks[slot.mask].layers, log)
			print(log[log.size() - 1])
			if data == null:
				failed = true
				continue
			entries.append(data.to_dict())
			if preview != 0:
				_print_board(data)
	else:
		var pool: Dictionary = _read_json(POOLS_PATH).get(kind, {})
		if pool.is_empty():
			printerr("generate_halves: no pool '%s' in %s" % [kind, POOLS_PATH])
			quit(1)
			return
		for index in range(maxi(from - 1, 0), mini(to, int(pool.count))):
			var data := _build_pool_board(kind, pool, index, log)
			if data == null:
				failed = true
				print(log[log.size() - 1])
				continue
			entries.append(data.to_dict())
			if index % 10 == 0:
				print("%s %d/%d  %s  tiles %d  p3 %.2f  win %.2f  wary %.2f  traps %d" % [kind, index, int(pool.count), data.mask,
						data.positions.size(), data.stats.p3, data.stats.random_win, data.stats.wary_win, int(data.stats.traps)])
	print("generated %d board(s) in %.1f s" % [entries.size(), (Time.get_ticks_msec() - started) / 1000.0])
	if failed:
		printerr("generate_halves: FAILED\n" + "\n".join(log))
		quit(1)
		return
	if preview != 0:
		quit()
		return
	if from == 1 and to == 1 << 30:
		_write_final(kind, entries)
	else:
		_write_part(kind, from, to, entries)
	quit()


## A pool board (v3): the recipe's mask, round(pairs * type_ratio) pair types drafted from
## `families` crest families picked at random (look-alike chunks of `depth`), and the gold pair with
## the recipe's chance; one rng seeded by the board in that order.
func _build_pool_board(kind: String, pool: Dictionary, index: int, log: PackedStringArray) -> HalvesLevelData:
	var recipe: Dictionary
	var role := kind
	if kind == "daily":
		var epoch := Time.get_unix_time_from_datetime_string(HalvesPools.DAILY_EPOCH + "T00:00:00")
		var weekday: int = Time.get_datetime_dict_from_unix_time(int(epoch) + index * 86400).weekday
		role = WEEKDAYS[weekday]
		recipe = pool.by_weekday[role]
	else:
		recipe = pool.recipe
	var pick := SeedService.make_rng(["halves", kind, index, "recipe"], HalvesConfig.GEN_VERSION)
	var masks: Array = recipe.masks
	var mask_name: String = masks[pick.randi_range(0, masks.size() - 1)]
	var layers: Array = _masks[mask_name].layers
	var pairs := HalvesMask.parse(layers).size() / 2
	var count := maxi(3, roundi(pairs * float(recipe.get("type_ratio", 0.55))))
	var crests: Array = HalvesGenerator.crest_families()
	HalvesGenerator._shuffle(crests, pick)
	var n := clampi(int(recipe.get("families", 2)), 1, crests.size())
	var families: Array = crests.slice(0, n)
	var quotas: Array = []
	for f in n:
		quotas.append(count / n + (1 if f < count % n else 0))
	var spare: Array = crests.slice(n)
	spare.append(&"shapes")
	var types := HalvesGenerator.draft_types(families, quotas, spare, count, int(recipe.get("depth", 2)), 1.0 / 3.0,
			true, pick)
	var spec := recipe.duplicate(true)
	spec.erase("masks")
	spec.types = types
	spec.role = role
	spec.gold_pair = 1 if pick.randf() < float(recipe.get("gold_pair", 0.0)) else 0
	var id := int(pool.id_base) + index
	var data := HalvesGenerator.build_board(spec, layers, ["halves", kind, index], id, false,
			int(pool.get("candidates", 24)), log, true)
	if data == null:
		return null
	data.level = id
	data.role = role
	data.mask = mask_name
	return data


func _write_final(kind: String, entries: Array) -> void:
	var version := HalvesConfig.GEN_VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/levels"))
	var path := LEVELS_OUT % version if kind == "levels" else POOL_OUT % [kind, version]
	var lines := PackedStringArray()
	for entry: Dictionary in entries:
		lines.append(JSON.stringify(entry, "", false))
	var head := "{\"gen_version\": %d, \"count\": %d, " % [version, entries.size()]
	head += "\"levels\": [\n" if kind == "levels" else "\"kind\": \"%s\", \"boards\": [\n" % kind
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(head + ",\n".join(lines) + "\n]}\n")
	out.close()
	_write_report(kind, entries)
	print("wrote %s" % path)
	if kind == "levels":
		print_curve(entries)


func _write_part(kind: String, from: int, to: int, entries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARTS_DIR))
	var path := "%s/part_%s_%04d.json" % [PARTS_DIR, kind, from]
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(entries))
	out.close()
	print("wrote %s (%d-%d)" % [path, from, to])


## Joins every part file of `kind` (sorted by start) into the final data file and report.
func _merge(kind: String) -> bool:
	var dir := DirAccess.open(PARTS_DIR)
	if dir == null:
		printerr("generate_halves: no %s" % PARTS_DIR)
		return false
	var files: Array = []
	for name in dir.get_files():
		if name.begins_with("part_%s_" % kind) and name.ends_with(".json"):
			files.append(name)
	files.sort()
	var entries: Array = []
	for name: String in files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTS_DIR + "/" + name))
		if parsed is Array:
			entries.append_array(parsed)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level) < int(b.level))
	for n in entries.size():
		var data := HalvesLevelData.from_dict(entries[n])
		data.level = int(entries[n].level)
		for key: String in ["runs", "traps", "start_free_pairs", "par_ms"]:
			data.stats[key] = int(data.stats.get(key, 0))
		entries[n] = data.to_dict()
	_write_final(kind, entries)
	for name: String in files:
		dir.remove(name)
	return true


func _write_report(kind: String, entries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/levelgen/reports"))
	var csv := FileAccess.open(REPORT_PATH % ["" if kind == "levels" else kind + "_", HalvesConfig.GEN_VERSION], FileAccess.WRITE)
	csv.store_line("level,place,role,mask,tiles,layers,types,depth,candidate,trap_rate,traps,random_win,careful_win,wary_win,perceptive_win,perceptive_slips,p3,decoy_exposure,avg_free_pairs,start_free_pairs,difficulty,par_s,locks,frost,mist,gold,gold_pair,turned,lucky,tip")
	for entry: Dictionary in entries:
		var data := HalvesLevelData.from_dict(entry)
		var s := data.stats
		var f := data.features
		var locked := 0
		for group: Dictionary in f.get("locks", []):
			locked += (group.locked as Array).size()
		var gold_pair := 0
		for face in data.faces:
			gold_pair += 1 if HalvesFace.family(face) == &"gold" else 0
		csv.store_line("%d,%d,%s,%s,%d,%d,%d,%d,%d,%.2f,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.1f,%d,%d,%d,%d,%d,%d,%d,%d,%s" % [
			data.level, data.place, data.role, data.mask, data.positions.size(), data.geometry().max_z() + 1,
			HalvesGenerator.type_count(data.faces), HalvesGenerator.lookalike_depth(data.faces),
			int(data.seed_parts[data.seed_parts.size() - 1]), s.trap_rate, int(s.traps), s.random_win, s.careful_win,
			s.wary_win, float(s.get("perceptive_win", 0.0)), float(s.get("perceptive_slips", 0.0)), float(s.get("p3", 0.0)),
			s.decoy_exposure, s.avg_free_pairs, int(s.start_free_pairs), s.difficulty, int(s.par_ms) / 1000,
			locked, (f.get("frost", []) as Array).size(), (f.get("mist", []) as Array).size(),
			(f.get("gold", []) as Array).size(), gold_pair / 2, (f.get("turned", []) as Array).size(),
			(f.get("lucky", []) as Array).size(), data.tip])
	csv.close()


## The difficulty curve of baked levels: per place the means of tiles, layers, pair types, look-alike
## depth, RANDOM and WARY wins, p3 and PERCEPTIVE slips; then p3 by role per place (the sawtooth),
## and the hard/finale levels that WARY always clears with p3 above 0.9 (there should be none).
static func print_curve(entries: Array) -> void:
	var by_place: Dictionary = {}
	var trivial := PackedStringArray()
	for entry: Dictionary in entries:
		var data := HalvesLevelData.from_dict(entry)
		var place := data.place if data.place > 0 else (data.level - 1) / HalvesChapters.LEVELS_PER_CHAPTER + 1
		if not by_place.has(place):
			by_place[place] = []
		by_place[place].append(data)
		if data.role in ["hard", "finale"] and float(data.stats.wary_win) >= 1.0 and float(data.stats.get("p3", 0.0)) > 0.9:
			trivial.append(str(data.level))
	print("place  tiles  layers  types  depth  random  wary   p3    slips")
	var places: Array = by_place.keys()
	places.sort()
	for place: int in places:
		var list: Array = by_place[place]
		var sums := PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
		for data: HalvesLevelData in list:
			sums[0] += data.positions.size()
			sums[1] += data.geometry().max_z() + 1
			sums[2] += HalvesGenerator.type_count(data.faces)
			sums[3] += HalvesGenerator.lookalike_depth(data.faces)
			sums[4] += float(data.stats.random_win)
			sums[5] += float(data.stats.wary_win)
			sums[6] += float(data.stats.get("p3", 0.0))
			sums[7] += float(data.stats.get("perceptive_slips", 0.0))
		var n := float(list.size())
		print("%5d  %5.1f  %6.2f  %5.1f  %5.2f  %6.2f  %5.2f  %5.2f  %5.2f" % [place, sums[0] / n, sums[1] / n, sums[2] / n,
				sums[3] / n, sums[4] / n, sums[5] / n, sums[6] / n, sums[7] / n])
	print("p3 by role:  place  " + "  ".join(ROLE_ORDER.map(func(r: String) -> String: return "%8s" % r)))
	for place: int in places:
		var cells := PackedStringArray()
		for role in ROLE_ORDER:
			var total := 0.0
			var count := 0
			for data: HalvesLevelData in by_place[place]:
				if data.role == role:
					total += float(data.stats.get("p3", 0.0))
					count += 1
			cells.append("%8s" % ("-" if count == 0 else "%.2f" % (total / count)))
		print("             %5d  %s" % [place, "  ".join(cells)])
	print("trivial hard/finale levels (wary 1.0, p3 > 0.9): %s" % ("none" if trivial.is_empty() else ", ".join(trivial)))


## Text preview of one level: each layer as a grid of face codes (C/T/S/D for shapes, the family's
## first letter for crests; lower case = side b).
func _print_board(data: HalvesLevelData) -> void:
	var bounds := data.geometry().bounds()
	for z in data.geometry().max_z() + 1:
		print("layer %d" % z)
		var grid: Array[PackedStringArray] = []
		for y in bounds.size.y:
			var row := PackedStringArray()
			row.resize(bounds.size.x)
			row.fill(".")
			grid.append(row)
		for i in data.positions.size():
			var p := data.positions[i]
			if p.z != z:
				continue
			var face := data.faces[i]
			var letter: String = "CTSD"[HalvesFace.shape(face)] if not HalvesFace.is_crest(face) else str(HalvesFace.family(face)).substr(0, 1).to_upper()
			if HalvesFace.side(face) == HalvesFace.SIDE_B:
				letter = letter.to_lower()
			grid[p.y][p.x] = letter
		for row in grid:
			print("  " + "".join(row))
	print("features: %s" % JSON.stringify(data.features))


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("generate_halves: cannot read %s" % path)
		return {}
	return parsed
