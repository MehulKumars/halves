extends SceneTree
## Drafts candidate stack masks from classic mahjong families (half-offset pyramids, bricks, rhombi,
## rings, towers, twin peaks, (v3) staggered walls and tall 4-5 layer stacks up to ~110 tiles), keeps
## only valid ones and writes build/levelgen/mask_catalogue.json plus a text preview. A human (or
## build_plan.gd) picks from it: chosen masks are copied into halves_masks.json.
## Usage: godot --headless --path . -s tools/levelgen/mask_catalogue.gd [-- --pick id=name ...]

const OUT_DIR: String = "res://build/levelgen"
const MASKS_PATH: String = "res://tools/levelgen/halves_masks.json"
## (v3) HalvesMask's width and nearly its height; the plan builder's face-size filter decides which
## boards keep 96 px faces (84 px on a notched 720 x 1280 screen).
const WIDTH: int = 13
const HEIGHT: int = 15
## Layer plans on top of each base: h = half a tile in, f = one tile in from every edge, c = a core
## tower, (v3) w = one tile in from the left and right, t = one tile in from the top and bottom.
const PLANS: Array[String] = ["", "h", "hh", "hhh", "f", "ff", "hf", "fh", "c", "cc", "ccc", "hc", "fc",
	"hhhh", "hhhf", "hhhc", "hhff", "hfhf", "fhfh", "hhfh", "hhcc", "hfhc",
	"w", "t", "wh", "th", "hw", "ht", "wt", "tw", "whh", "thh", "hwh", "hth", "whhh", "thhh", "wthh", "hhwh",
	"hhth", "hhhw", "hhht", "whwh", "thth", "wwh", "tth", "wwhh", "tthh", "wtwh"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var catalogue := _build()
	if args.size() > 0 and args[0] == "--pick":
		_pick(catalogue, args.slice(1))
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ids: Array = catalogue.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _count(catalogue[a]) < _count(catalogue[b]) or (_count(catalogue[a]) == _count(catalogue[b]) and a < b))
	var text := PackedStringArray()
	for id: String in ids:
		var layers: Array = catalogue[id]
		var sizes := PackedStringArray()
		for layer: Array in layers:
			sizes.append(str(_tiles_in(layer)))
		text.append("%s  tiles %d  layers [%s]" % [id, _count(layers), ", ".join(sizes)])
		text.append(_preview(layers))
	var out := FileAccess.open(OUT_DIR + "/mask_catalogue.txt", FileAccess.WRITE)
	out.store_string("\n".join(text))
	out.close()
	var json := FileAccess.open(OUT_DIR + "/mask_catalogue.json", FileAccess.WRITE)
	json.store_string(JSON.stringify(catalogue, "\t"))
	json.close()
	print("mask_catalogue: %d valid masks -> %s/mask_catalogue.txt" % [catalogue.size(), OUT_DIR])
	quit()


## Copies catalogue entries into halves_masks.json: each arg is "<catalogue id>=<new mask name>".
func _pick(catalogue: Dictionary, picks: Array) -> void:
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MASKS_PATH))
	var masks: Dictionary = file.masks
	for pick: String in picks:
		var parts := pick.split("=")
		if parts.size() != 2 or not catalogue.has(parts[0]):
			printerr("mask_catalogue: unknown pick %s" % pick)
			continue
		masks[parts[1]] = {"layers": catalogue[parts[0]]}
	var text := "{\n\t\"format\": 1,\n\t\"about\": %s,\n\t\"masks\": {\n" % JSON.stringify(file.about)
	var entries := PackedStringArray()
	for name: String in masks:
		var layer_texts := PackedStringArray()
		for layer: Array in masks[name].layers:
			var rows := PackedStringArray()
			for row: String in layer:
				rows.append(JSON.stringify(row))
			layer_texts.append("\t\t\t[" + ",\n\t\t\t ".join(rows) + "]")
		entries.append("\t\t%s: {\"layers\": [\n%s\n\t\t]}" % [JSON.stringify(name), ",\n".join(layer_texts)])
	text += ",\n".join(entries) + "\n\t}\n}\n"
	var out := FileAccess.open(MASKS_PATH, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("mask_catalogue: %d masks in %s" % [masks.size(), MASKS_PATH])


func _build() -> Dictionary:
	var out: Dictionary = {}
	var bases: Dictionary = {}
	for w in range(3, 7):
		for h in range(2, 8):
			bases["rect%dx%d" % [w, h]] = _rect(w, h, 0, 0)
			if w >= 4:
				bases["brick%dx%d" % [w, h]] = _brick(w, h)
	for widths: Array in [[2, 4, 6, 4, 2], [3, 5, 3], [2, 4, 6, 6, 4, 2], [4, 6, 6, 4], [3, 4, 5, 4, 3],
			[6, 4, 2, 4, 6], [6, 4, 4, 6], [2, 4, 6, 6, 6, 4, 2], [4, 5, 6, 5, 4], [6, 5, 4, 5, 6],
			[2, 6, 6, 6, 2], [6, 6, 2, 6, 6], [1, 3, 5, 5, 3, 1], [5, 6, 5, 6, 5], [4, 6, 4, 6, 4],
			[3, 5, 6, 6, 5, 3], [6, 6, 4, 4, 6, 6], [2, 2, 6, 6, 2, 2], [6, 2, 2, 6], [4, 4, 6, 6, 4, 4]]:
		bases["rows" + "".join(widths.map(func(n: int) -> String: return str(n)))] = _rows(widths)
	for w in range(4, 7):
		for h in range(3, 8):
			bases["ring%dx%d" % [w, h]] = _ring(w, h)
			bases["twin%dx%d" % [w, h]] = _twin(w, h)
	# (v3) Staggered walls: every other row half a tile to the right (13 half-units wide at 6 tiles).
	for w in range(4, 7):
		for h in range(4, 8):
			bases["stagger%dx%d" % [w, h]] = _stagger(w, h)
	for base_id: String in bases:
		var base: Dictionary = bases[base_id]
		for plan: String in PLANS:
			var layers: Array[Dictionary] = [base]
			var ok := true
			for step in plan:
				var top: Dictionary = layers[layers.size() - 1]
				var next: Dictionary
				match step:
					"h":
						next = _half(top)
					"f":
						next = _full(top)
					"w":
						next = _inset(top, Vector2i(2, 0))
					"t":
						next = _inset(top, Vector2i(0, 2))
					_:
						next = _core(top)
				if next.is_empty():
					ok = false
					break
				layers.append(next)
			if not ok:
				continue
			var native := _even(_native(layers))
			if native.is_empty():
				continue
			var positions := HalvesMask.parse(native)
			if positions.size() < 8 or not HalvesMask.validate(positions).is_empty():
				continue
			var bounds := HalvesGeometry.from_positions(positions).bounds()
			if bounds.size.x > WIDTH or bounds.size.y > HEIGHT:
				continue
			out["%s_%s" % [base_id, plan if plan != "" else "flat"]] = native
	return out


## Tile sets are Dictionaries keyed by Vector2i half-unit corners (value true).
func _rect(w: int, h: int, ox: int, oy: int) -> Dictionary:
	var tiles: Dictionary = {}
	for row in h:
		for col in w:
			tiles[Vector2i(ox + 2 * col, oy + 2 * row)] = true
	return tiles


func _brick(w: int, h: int) -> Dictionary:
	var tiles: Dictionary = {}
	for row in h:
		var odd := row % 2 == 1
		for col in (w - 1 if odd else w):
			tiles[Vector2i(2 * col + (1 if odd else 0), 2 * row)] = true
	return tiles


## Rows of the given widths, centred on the widest (odd differences give half-tile offsets).
func _rows(widths: Array) -> Dictionary:
	var widest := 0
	for n: int in widths:
		widest = maxi(widest, n)
	var tiles: Dictionary = {}
	for row in widths.size():
		var n: int = widths[row]
		for col in n:
			tiles[Vector2i(widest - n + 2 * col, 2 * row)] = true
	return tiles


func _ring(w: int, h: int) -> Dictionary:
	var tiles := _rect(w, h, 0, 0)
	for row in range(1, h - 1):
		for col in range(1, w - 1):
			tiles.erase(Vector2i(2 * col, 2 * row))
	return tiles


func _twin(w: int, h: int) -> Dictionary:
	var tiles: Dictionary = {}
	var half_w := w / 2
	for row in h:
		for col in half_w:
			tiles[Vector2i(2 * col, 2 * row)] = true
			tiles[Vector2i(2 * (w - 1 - col) + 2, 2 * row)] = true
	return tiles


## (v3) Rows of w tiles, every other row half a tile to the right.
func _stagger(w: int, h: int) -> Dictionary:
	var tiles: Dictionary = {}
	for row in h:
		for col in w:
			tiles[Vector2i(2 * col + row % 2, 2 * row)] = true
	return tiles


## The next layer half a tile in: a tile half a tile right and down of a tile below, wherever all
## four of its quarters rest on tiles below (on a grid: where four tiles meet; (v3) on a staggered
## wall: on three).
func _half(below: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for p: Vector2i in below:
		for dy in 2:
			for dx in 2:
				cells[p + Vector2i(dx, dy)] = true
	var tiles: Dictionary = {}
	for p: Vector2i in below:
		var q := p + Vector2i(1, 1)
		if cells.has(q) and cells.has(q + Vector2i(1, 0)) and cells.has(q + Vector2i(0, 1)) and cells.has(q + Vector2i(1, 1)):
			tiles[q] = true
	return tiles


## (v3) The next layer straight up, one tile in on both sides along `step` (2, 0) or (0, 2).
func _inset(below: Dictionary, step: Vector2i) -> Dictionary:
	var tiles: Dictionary = {}
	for p: Vector2i in below:
		if below.has(p + step) and below.has(p - step):
			tiles[p] = true
	return tiles


## The next layer straight up, one tile in from every edge.
func _full(below: Dictionary) -> Dictionary:
	var tiles: Dictionary = {}
	for p: Vector2i in below:
		if below.has(p + Vector2i(2, 0)) and below.has(p - Vector2i(2, 0)) \
				and below.has(p + Vector2i(0, 2)) and below.has(p - Vector2i(0, 2)):
			tiles[p] = true
	return tiles


## The middle of the layer below: the tiles nearest its centre (a tower), at most 4.
func _core(below: Dictionary) -> Dictionary:
	if below.size() < 2:
		return {}
	var centre := Vector2.ZERO
	for p: Vector2i in below:
		centre += Vector2(p)
	centre /= below.size()
	var list: Array = below.keys()
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a).distance_squared_to(centre)
		var db := Vector2(b).distance_squared_to(centre)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var tiles: Dictionary = {}
	for i in mini(below.size() / 3 if below.size() >= 6 else 1, 4):
		tiles[list[i]] = true
	return tiles


func _native(layers: Array[Dictionary]) -> Array:
	var out: Array = []
	for layer in layers:
		var far := Vector2i.ZERO
		for p: Vector2i in layer:
			far = Vector2i(maxi(far.x, p.x + 1), maxi(far.y, p.y + 1))
		var rows: Array = []
		for y in far.y:
			var row := ""
			for x in far.x:
				row += "X" if layer.has(Vector2i(x, y)) else "."
			rows.append(row)
		out.append(rows)
	return out


## Makes the tile count even by dropping the last tile of the top layer (or the whole top layer).
func _even(native: Array) -> Array:
	var total := 0
	for layer: Array in native:
		total += _tiles_in(layer)
	if total % 2 == 0:
		return native
	var top: Array = native[native.size() - 1]
	if _tiles_in(top) == 1:
		return native.slice(0, native.size() - 1) if native.size() > 1 else []
	for y in range(top.size() - 1, -1, -1):
		var row: String = top[y]
		var x := row.rfind("X")
		if x != -1:
			top[y] = row.substr(0, x) + "." + row.substr(x + 1)
			break
	return native


func _tiles_in(layer: Array) -> int:
	var n := 0
	for row: String in layer:
		n += row.count("X")
	return n


func _count(layers: Array) -> int:
	var n := 0
	for layer: Array in layers:
		n += _tiles_in(layer)
	return n


func _preview(layers: Array) -> String:
	var lines := PackedStringArray()
	for z in layers.size():
		lines.append("  layer %d" % z)
		for row: String in layers[z]:
			if row.contains("X"):
				lines.append("    " + row)
	return "\n".join(lines)
