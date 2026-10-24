extends SceneTree
## Drafts the hand-drawn picture masks (pic_*: Fuji, torii, pagoda, fan, koi, crane, lantern, wave,
## two or three sizes each), checks each with HalvesMask.validate and the face-size fit, prints a
## preview and writes them into tools/levelgen/halves_masks.json. The JSON is the source of truth after.
## Usage: godot --headless --path . -s tools/levelgen/picture_masks.gd [-- --dry]

const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"

## Each picture is a list of layers; a layer is {"oy": first half-unit row (0 or 1), "rows": the
## half-unit row strings for y = oy, oy + 2, oy + 4, ...} ("X" = a tile's top-left corner).
const PICTURES: Dictionary = {
	# Mount Fuji: a half-offset cone over a lake, the upper layers a snow cap on the peak.
	"pic_fuji_s": [
		{"oy": 0, "rows": ["...X.X", "..X.X.X", ".X.X.X.X", "X.X.X.X.X", "X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X", "...X.X", "..X.X.X", ".X.X.X.X"]},
		{"oy": 0, "rows": ["", "....X", "...X.X"]},
	],
	"pic_fuji_m": [
		{"oy": 0, "rows": ["....X.X", "...X.X.X", "..X.X.X.X", ".X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "...X.X.X", "..X.X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": ["", ".....X", "....X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", ".....X", "....X.X"]},
	],
	"pic_fuji_l": [
		{"oy": 0, "rows": ["....X.X", "...X.X.X", "..X.X.X.X", ".X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "...X.X.X", "..X.X.X.X", ".X.X.X.X.X", "X.X.X.X.X.X"]},
		{"oy": 0, "rows": ["", ".....X", "....X.X", "...X.X.X", "..X.X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": ["", "", ".....X", "....X.X", "...X.X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": ["", "", "", ".....X", "....X.X", "...X.X.X"]},
	],
	# Torii: the wide top beam, the tie beam, two posts on round feet.
	"pic_torii_s": [
		{"oy": 0, "rows": ["X.X.X.X.X.X", "..X.X.X.X", "..X.....X", "..X.....X", ".X.X...X.X"]},
		{"oy": 0, "rows": [".X.X.X.X.X", "...X.X.X", "..X.....X"]},
	],
	"pic_torii_m": [
		{"oy": 0, "rows": ["X.X.X.X.X.X", ".X.X.X.X.X", "..X.....X", "X.X.X.X.X.X", "..X.....X", "..X.....X", ".X.X...X.X"]},
		{"oy": 0, "rows": [".X.X.X.X.X", "...X.X.X", "..X.....X", ".X.X.X.X.X", "..X.....X", "..X.....X"]},
	],
	"pic_torii_l": [
		{"oy": 0, "rows": ["X.X.X.X.X.X", ".X.X.X.X.X", "..X.....X", "X.X.X.X.X.X", "..X.....X", "..X.....X", ".X.X...X.X"]},
		{"oy": 0, "rows": ["X.X.X.X.X.X", ".X.X.X.X.X", "..X.....X", "X.X.X.X.X.X", "..X.....X", "..X.....X", "..X.....X"]},
		{"oy": 0, "rows": [".X.X.X.X.X", "..X.X.X.X", "..X.....X", ".X.X.X.X.X", "..X.....X"]},
		{"oy": 0, "rows": ["..X.X.X.X", "", "", "..X.X.X.X"]},
	],
	# Pagoda: three roofs, each wider than the one above, with the storeys between.
	"pic_pagoda_s": [
		{"oy": 0, "rows": ["...X.X.X", "....X.X", "..X.X.X.X", "...X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "", "...X.X.X", "", "..X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "", "", "", "...X.X.X"]},
	],
	"pic_pagoda_m": [
		{"oy": 0, "rows": ["", "...X.X.X", "....X.X", "..X.X.X.X", "...X.X.X", ".X.X.X.X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": ["", "....X.X", "....X.X", "...X.X.X", "...X.X.X", "..X.X.X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": ["", ".....X", "", "....X.X", "", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "", ".....X", "", "....X.X"]},
	],
	"pic_pagoda_l": [
		{"oy": 0, "rows": ["....X.X", "..X.X.X.X", "...X.X.X", ".X.X.X.X.X", "..X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "...X.X.X", "...X.X.X", "..X.X.X.X", "..X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "....X.X", "...X.X.X", "...X.X.X", "..X.X.X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": ["", ".....X", "", "....X.X", "", "...X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "", ".....X", "", "....X.X", "....X.X"]},
	],
	# Folding fan: a wide arc over a narrow handle.
	"pic_fan_s": [
		{"oy": 0, "rows": [".X.X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["..X.X.X.X", ".X.X.X.X.X", "..X.X.X.X"]},
	],
	"pic_fan_m": [
		{"oy": 0, "rows": ["..X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["...X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "..X.X.X.X", "..X.X.X.X", "...X.X.X"]},
	],
	"pic_fan_l": [
		{"oy": 0, "rows": [".X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["..X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "..X.X.X.X", "..X.X.X.X", "..X.X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "...X.X.X", "...X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "....X.X", "....X.X"]},
	],
	# Koi: a round body swimming up, fins at the sides, the tail fanning out below.
	"pic_koi_s": [
		{"oy": 0, "rows": ["....X.X", "...X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "...X.X.X", "....X.X", "", "...X.X.X"]},
	],
	"pic_koi_m": [
		{"oy": 0, "rows": ["....X.X", "...X.X.X", "X.X.X.X.X.X", "..X.X.X.X", "...X.X.X", "....X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "...X.X.X", "...X.X.X", "....X.X", ".....X", "...X...X"]},
		{"oy": 0, "rows": ["", ".....X", "....X.X", "....X.X", ".....X"]},
	],
	"pic_koi_l": [
		{"oy": 0, "rows": ["...X.X.X", "..X.X.X.X", "X.X.X.X.X.X", "..X.X.X.X", "...X.X.X", "....X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "...X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X", ".....X", "..X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "....X.X", "...X.X.X", "...X.X.X", "....X.X", "", "....X.X"]},
		{"oy": 0, "rows": ["", ".....X", "....X.X", "....X.X", ".....X"]},
	],
	# Crane: wings spread wide, the long neck up, the body and tail below.
	"pic_crane_s": [
		{"oy": 0, "rows": [".....X", "....X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "", ".X.X.X.X.X", "..X.X.X.X", "....X.X"]},
	],
	"pic_crane_m": [
		{"oy": 0, "rows": [".....X", ".....X", "X...X.X...X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["", ".....X", "", ".X.X.X.X.X", "..X.X.X.X", "....X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "", "", "..X.X.X.X", "...X.X.X", ".....X"]},
	],
	"pic_crane_l": [
		{"oy": 0, "rows": ["....X.X", "X....X....X", "X.X.X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": [".....X", "", ".X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "....X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "", "..X.X.X.X", "..X.X.X.X", "...X.X.X", ".....X", ".....X"]},
		{"oy": 0, "rows": ["", "", "...X.X.X", "...X.X.X", "....X.X"]},
	],
	# Lantern: a round paper body between a cap and a foot.
	"pic_lantern_s": [
		{"oy": 0, "rows": ["...X.X", "..X.X.X", ".X.X.X.X", ".X.X.X.X", "..X.X.X", "...X.X"]},
		{"oy": 0, "rows": ["", "...X.X", "..X.X.X", "..X.X.X", "...X.X"]},
	],
	"pic_lantern_m": [
		{"oy": 0, "rows": ["....X.X", "..X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "...X.X.X", "..X.X.X.X", "..X.X.X.X", "..X.X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "...X.X.X", "...X.X.X", "...X.X.X"]},
	],
	"pic_lantern_l": [
		{"oy": 0, "rows": ["...X.X.X", ".X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", "X.X.X.X.X.X", ".X.X.X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "..X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", ".X.X.X.X.X", "..X.X.X.X", "....X.X"]},
		{"oy": 0, "rows": ["", "...X.X.X", "..X.X.X.X", "..X.X.X.X", "..X.X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "...X.X.X", "...X.X.X", "...X.X.X"]},
		{"oy": 0, "rows": ["", "", "....X.X", "....X.X", "....X.X"]},
	],
	# Wave: a crest that curls over to the left into a hook (its tip turned back in), the back of
	# the wave falling away on the right, over a rolling swell of half-offset rows.
	"pic_wave_s": [
		{"oy": 0, "rows": ["...X.X.X", ".X.X.....X", "X...X.....X", ".X.X.....X.X", "...X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "", "", "", "....X.X.X.X"]},
	],
	"pic_wave_m": [
		{"oy": 0, "rows": ["...X.X.X", ".X.X.....X", "X...X.....X", ".X.X.....X.X", "...X.X.X.X.X", ".X.X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "", "", "", "....X.X.X.X", "..X.X.X.X.X"]},
		{"oy": 0, "rows": ["", "", "", "", ".....X.X.X", "...X.X.X.X"]},
	],
	"pic_wave_l": [
		{"oy": 0, "rows": ["...X.X.X", ".X.X.....X", "X...X.....X", ".X.X.....X.X", "...X.X.X.X.X", ".X.X.X.X.X.X", "X.X.X.X.X.X"]},
		{"oy": 0, "rows": ["....X.X", "", "", "", "....X.X.X.X", "..X.X.X.X.X", ".X.X.X.X.X"]},
		{"oy": 0, "rows": [".....X", "", "", "", ".....X.X.X", "...X.X.X.X", "..X.X.X.X"]},
		{"oy": 0, "rows": ["", "", "", "", "", "....X.X.X", "...X.X.X"]},
	],
}
## The board area at 720 x 1280 with a 64/32 px notch and at 960 x 1280 (tests/test_halves_game.gd).
const NOTCH_AREA: Vector2 = Vector2(672, 874)
const WIDE_AREA: Vector2 = Vector2(820, 970)
const TALL_AREA: Vector2 = Vector2(672, 1290)


func _initialize() -> void:
	var dry := OS.get_cmdline_user_args().has("--dry")
	var made: Dictionary = {}
	var bad := 0
	for name: String in PICTURES:
		var layers := to_layers(PICTURES[name])
		var positions := HalvesMask.parse(layers)
		var problems := HalvesMask.validate(positions)
		var geometry := HalvesGeometry.from_positions(positions)
		var faces := faces_px(geometry)
		var sizes := PackedStringArray()
		for layer: Array in layers:
			var n := 0
			for row: String in layer:
				n += row.count("X")
			sizes.append(str(n))
		print("%s  tiles %d  layers [%s]  %dx%d  free %d  faces %.0f/%.0f/%.0f px%s" % [name, positions.size(),
				", ".join(sizes), geometry.bounds().size.x, geometry.bounds().size.y,
				HalvesBits.count(geometry.free_mask(geometry.full_mask())), faces.x, faces.y, faces.z,
				"" if problems.is_empty() else "  INVALID: " + "; ".join(problems)])
		print(preview(layers))
		if not problems.is_empty() or faces.x < 84.0 or faces.y < 96.0 or faces.z < 96.0:
			bad += 1
			continue
		made[name] = layers
	print("picture_masks: %d valid, %d need work" % [made.size(), bad])
	if not dry and bad == 0:
		_write(made)
	quit(0 if bad == 0 else 1)


## Face widths (notch 720 x 1280, 960 x 1280, 720 x 1600) in px, as HalvesBoardView lays them out.
static func faces_px(geometry: HalvesGeometry) -> Vector3:
	var out := Vector3.ZERO
	for i in 3:
		var area: Vector2 = [NOTCH_AREA, WIDE_AREA, TALL_AREA][i]
		out[i] = HalvesBoardView.unit_for(area, geometry.bounds(), geometry.max_z()) * HalvesBoardView.FACE_W
	return out


static func to_layers(picture: Array) -> Array:
	var layers: Array = []
	for layer: Dictionary in picture:
		var rows: Array = []
		for k in int(layer.oy):
			rows.append("")
		var list: Array = layer.rows
		for r in list.size():
			rows.append(str(list[r]))
			if r < list.size() - 1:
				rows.append("")
		while not rows.is_empty() and not str(rows[rows.size() - 1]).contains("X"):
			rows.pop_back()
		layers.append(rows)
	return layers


## Each layer as a grid where a tile fills its two by two half-units: "#" bottom layer up to "5".
static func preview(layers: Array) -> String:
	var positions := HalvesMask.parse(layers)
	var far := Vector2i.ZERO
	for p in positions:
		far = Vector2i(maxi(far.x, p.x + 2), maxi(far.y, p.y + 2))
	var grid: Array[PackedStringArray] = []
	for y in far.y:
		var row := PackedStringArray()
		row.resize(far.x)
		row.fill(" ")
		grid.append(row)
	for p in positions:
		for dy in 2:
			for dx in 2:
				grid[p.y + dy][p.x + dx] = "#" if p.z == 0 else str(p.z)
	var lines := PackedStringArray()
	for row in grid:
		lines.append("    |" + "".join(row) + "|")
	return "\n".join(lines)


func _write(made: Dictionary) -> void:
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MASKS_PATH))
	var masks: Dictionary = file.masks
	for name: String in masks.keys():
		if name.begins_with("pic_"):
			masks.erase(name)
	for name: String in made:
		masks[name] = {"layers": made[name]}
	var entries := PackedStringArray()
	for name: String in masks:
		var layer_texts := PackedStringArray()
		for layer: Array in masks[name].layers:
			var rows := PackedStringArray()
			for row: String in layer:
				rows.append(JSON.stringify(row))
			layer_texts.append("\t\t\t[" + ",\n\t\t\t ".join(rows) + "]")
		entries.append("\t\t%s: {\"layers\": [\n%s\n\t\t]}" % [JSON.stringify(name), ",\n".join(layer_texts)])
	var text := "{\n\t\"format\": 1,\n\t\"about\": %s,\n\t\"masks\": {\n%s\n\t}\n}\n" % [JSON.stringify(file.about), ",\n".join(entries)]
	var out := FileAccess.open(MASKS_PATH, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("picture_masks: wrote %d pictures into %s" % [made.size(), MASKS_PATH])
