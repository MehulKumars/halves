extends SceneTree
## Bakes the 30 Halves levels: reads the hand-made masks and level plan, deals seeded candidates,
## rates them with the bots and writes data/levels/halves_v<GEN_VERSION>.json plus a CSV report.
## Usage: godot --headless --path . -s tools/levelgen/generate_halves.gd [-- <level> to preview one]

const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"
const PLAN_PATH: String = "res://tools/levelgen/halves_plan.json"
const OUT_PATH: String = "res://data/levels/halves_v%d.json"
const REPORT_PATH: String = "res://tools/levelgen/reports/halves_v%d.csv"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var only := int(args[0]) if args.size() > 0 else 0
	var masks: Dictionary = _read_json(MASKS_PATH).get("masks", {})
	var slots: Array = _read_json(PLAN_PATH).get("slots", [])
	var started := Time.get_ticks_msec()
	var log := PackedStringArray()
	var levels: Array[HalvesLevelData] = []
	var failed := false
	for slot: Dictionary in slots:
		if only != 0 and int(slot.level) != only:
			continue
		if not masks.has(slot.mask):
			log.append("level %d: unknown mask %s" % [int(slot.level), slot.mask])
			failed = true
			continue
		var data := HalvesGenerator.build_level(slot, masks[slot.mask].layers, log)
		print(log[log.size() - 1])
		if data == null:
			failed = true
		else:
			levels.append(data)
			if only != 0:
				_print_board(data)
	print("generated %d level(s) in %.1f s" % [levels.size(), (Time.get_ticks_msec() - started) / 1000.0])
	if failed:
		printerr("generate_halves: FAILED\n" + "\n".join(log))
		quit(1)
		return
	if only == 0:
		_write(levels, slots)
	quit()


func _write(levels: Array[HalvesLevelData], slots: Array) -> void:
	var version := HalvesConfig.GEN_VERSION
	var entries: Array = []
	for data in levels:
		entries.append(data.to_dict())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/levels"))
	var out := FileAccess.open(OUT_PATH % version, FileAccess.WRITE)
	out.store_string(JSON.stringify({"gen_version": version, "count": levels.size(), "levels": entries}, "\t", false) + "\n")
	out.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/levelgen/reports"))
	var csv := FileAccess.open(REPORT_PATH % version, FileAccess.WRITE)
	csv.store_line("level,role,mask,tiles,layers,types,candidate,random_win,target_win,careful_win,decoy_exposure,target_decoy,avg_free_pairs,start_free_pairs,difficulty")
	for i in levels.size():
		var data := levels[i]
		var slot: Dictionary = slots[data.level - 1]
		var s := data.stats
		csv.store_line("%d,%s,%s,%d,%d,%d,%d,%.3f,%.2f,%.3f,%.3f,%.2f,%.3f,%d,%.1f" % [
			data.level, data.role, data.mask, data.positions.size(), data.geometry().max_z() + 1,
			(slot.types as Array).size(), int(data.seed_parts[2]), s.random_win, float(slot.target_win),
			s.careful_win, s.decoy_exposure, float(slot.target_decoy), s.avg_free_pairs,
			int(s.start_free_pairs), s.difficulty])
	csv.close()
	print("wrote %s and %s" % [OUT_PATH % version, REPORT_PATH % version])


## Text preview of one level: each layer as a grid of face codes (C/T/S/D, lower case = side b).
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
			var letter: String = "CTSD"[HalvesFace.shape(face)]
			if HalvesFace.side(face) == HalvesFace.SIDE_B:
				letter = letter.to_lower()
			grid[p.y][p.x] = letter
		for row in grid:
			print("  " + "".join(row))


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("generate_halves: cannot read %s" % path)
		return {}
	return parsed
